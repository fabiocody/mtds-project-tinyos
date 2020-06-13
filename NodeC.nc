// NodeC.nc

#include "constants.h"
#include "messages.h"


// This is the main body of the application. It contains all the application logic except the sensing part.
module NodeC {
    uses interface Read<int16_t> as TemperatureSensor;
    uses interface Timer<TMilli> as TemperatureTimer;
    uses interface Timer<TMilli> as SetupTimer;
    uses interface Timer<TMilli> as SendTimer;
    uses interface Timer<TMilli> as AckTimer;
    uses interface Boot;
    uses interface Packet;
    uses interface AMPacket;
    uses interface AMSend;
    uses interface Receive;
    uses interface SplitControl as AMControl;
    uses interface Queue<queueable_msg_t> as MessageQueue;
} implementation {
    uint16_t setup_id = 0;
    int16_t threshold = INITIAL_THRESHOLD;
    uint16_t next_hop_to_sink = 0;
    bool radio_busy = FALSE;
    bool awaiting_ack = FALSE;
    queueable_msg_t awaiting_ack_msg;
    message_t pkt;

    // Called when the node is booted.
    // If the node is a sensor, then it starts the temperature timer.
    // In any case, it starts up the radio.
    event void Boot.booted() {
        if (TOS_NODE_ID != 0) call TemperatureTimer.startPeriodic(TEMPERATURE_TIMER_PERIOD);
        call AMControl.start();
    }

    // Called when the radio has has finished starting up.
    // If the radio has started and the node is the sink, then it starts the timer used to send SETUP messages.
    event void AMControl.startDone(error_t err) {
        if (err == SUCCESS) {
            call SendTimer.startPeriodic(SEND_TIMER_PERIOD);
            if (TOS_NODE_ID == 0) call SetupTimer.startOneShot(SETUP_TIMER_PERIOD / 2);
        } else {
            call AMControl.start();
        }
    }

    event void AMControl.stopDone(error_t err) {}
    
    // Called when the temperature timer fires, it asks the sensor for a value.
    event void TemperatureTimer.fired() {
        call TemperatureSensor.read();
    }

    // Called when the setup timer fires, it prepares and sends a SETUP message
    event void SetupTimer.fired() {
        queueable_msg_t queue_msg;
        setup_id++;
        queue_msg.dst = AM_BROADCAST_ADDR;
        queue_msg.msg.msg_type = SETUP_MSG_TYPE;
        queue_msg.msg.field1 = setup_id;
        queue_msg.msg.field2 = threshold;
        call MessageQueue.enqueue(queue_msg);
        call SetupTimer.startOneShot(SETUP_TIMER_PERIOD);
    }

    void send(queueable_msg_t queue_msg) {
        GENERIC_msg_t *msg = (GENERIC_msg_t *) call Packet.getPayload(&pkt, sizeof(GENERIC_msg_t));
        if (msg == NULL) {
            dbgerror_clear(DEBUG_ERR, "%s | %02u | +++ERROR+++ NULL payload\n", sim_time_string(), TOS_NODE_ID);
            return;
        }
        msg->msg_type = queue_msg.msg.msg_type;
        msg->field1 = queue_msg.msg.field1;
        msg->field2 = queue_msg.msg.field2;
        if (call AMSend.send(queue_msg.dst, &pkt, sizeof(GENERIC_msg_t)) == SUCCESS) {
            radio_busy = TRUE;
            switch (queue_msg.msg.msg_type) {
                case 1:
                    dbg_clear(DEBUG_SETUP, "%s | %02u | SETUP(setup_id=%u, threshold=%d) flooded\n", sim_time_string(), TOS_NODE_ID, queue_msg.msg.field1, queue_msg.msg.field2);
                    break;
                case 2:
                    dbg_clear(DEBUG_DATA, "%s | %02u | DATA(sender=%u, temperature=%d) sent to %u\n", sim_time_string(), TOS_NODE_ID, queue_msg.msg.field1, queue_msg.msg.field2, queue_msg.dst);
                    awaiting_ack_msg = queue_msg;
                    awaiting_ack = TRUE;
                    call AckTimer.startOneShot(ACK_TIMER_PERIOD);
                    break;
                case 3:
                    dbg_clear(DEBUG_ACK, "%s | %02u | ACK(sender=%u, temperature=%d) sent to %u\n", sim_time_string(), TOS_NODE_ID, queue_msg.msg.field1, queue_msg.msg.field2, queue_msg.dst);
                    break;
                default:
                    dbg_clear(DEBUG_DBG, "%s | %02u | MSG(type=%d, field1=%d, field2=%u) sent to %u\n", sim_time_string(), TOS_NODE_ID, queue_msg.msg.msg_type, queue_msg.msg.field1, queue_msg.msg.field2, queue_msg.dst);
            }
        } else {
            call MessageQueue.enqueue(queue_msg);
            dbgerror_clear(DEBUG_ERR, "%s | %02u | +++ERROR+++ failed to send MSG(type=%d, field16=%d, field8=%u)\n", sim_time_string(), TOS_NODE_ID, queue_msg.msg.msg_type, queue_msg.msg.field1, queue_msg.msg.field2);
        }
    }

    event void SendTimer.fired() {
        if (!radio_busy && !awaiting_ack && !(call MessageQueue.empty())) {
            queueable_msg_t queue_msg = call MessageQueue.dequeue();
            send(queue_msg);
        }
    }

    event void AckTimer.fired() {
        dbg_clear(DEBUG_ACK, "%s | %02u | Resending MSG(type=%d, field1=%d, field2=%u) to %u\n", sim_time_string(), TOS_NODE_ID, awaiting_ack_msg.msg.msg_type, awaiting_ack_msg.msg.field1, awaiting_ack_msg.msg.field2, awaiting_ack_msg.dst);
        send(awaiting_ack_msg);
        call AckTimer.startOneShot(ACK_TIMER_PERIOD);
    }

    // Called when the sensor has the value ready.
    // If the temperature is above the threshold, it sends a DATA message.
    event void TemperatureSensor.readDone(error_t err, int16_t temperature) {
        dbg_clear(DEBUG_TEMP, "%s | %02u | temperature = %d\n", sim_time_string(), TOS_NODE_ID, temperature);
        if (setup_id > 0 && temperature > threshold) {
            queueable_msg_t queue_msg;
            queue_msg.dst = next_hop_to_sink;
            queue_msg.msg.msg_type = DATA_MSG_TYPE;
            queue_msg.msg.field1 = TOS_NODE_ID;
            queue_msg.msg.field2 = temperature;
            call MessageQueue.enqueue(queue_msg);
        }
    }

    event void AMSend.sendDone(message_t *msg, error_t err) {
        if (&pkt == msg) radio_busy = FALSE;
    }

    // Called when a message is received.
    // If it is a SETUP message, the node is a sensor and the message has never been received before,
    // then it saves the message content and relays it.
    // If it is a DATA message and the node is a sensor, then the message is relayed to the next hop towards the sink.
    // If it is a DATA message, the node is the sink, and the temperature is above the current threshold, it updates the threshold.
    event message_t *Receive.receive(message_t *msg, void *payload, uint8_t len) {
        GENERIC_msg_t *generic_msg = (GENERIC_msg_t *) payload;
        uint16_t source = call AMPacket.source(msg);
        if (generic_msg->msg_type == SETUP_MSG_TYPE) {
            if (TOS_NODE_ID != 0) {
                SETUP_msg_t *setup_msg = (SETUP_msg_t *) payload;
                if (setup_msg->setup_id > setup_id) {
                    queueable_msg_t queue_msg;
                    setup_id = setup_msg->setup_id;
                    threshold = setup_msg->threshold;
                    next_hop_to_sink = source;
                    dbg_clear(DEBUG_SETUP, "%s | %02u | SETUP(setup_id=%u, threshold=%d) received from %u\n", sim_time_string(), TOS_NODE_ID, setup_id, threshold, next_hop_to_sink);
                    queue_msg.dst = AM_BROADCAST_ADDR;
                    queue_msg.msg.msg_type = setup_msg->msg_type;
                    queue_msg.msg.field1 = setup_msg->setup_id;
                    queue_msg.msg.field2 = setup_msg->threshold;
                    call MessageQueue.enqueue(queue_msg);
                }
            }
        } else if (generic_msg->msg_type == DATA_MSG_TYPE) {
            DATA_msg_t *data_msg = (DATA_msg_t *) payload;
            queueable_msg_t queue_msg;
            queue_msg.dst = source;
            queue_msg.msg.msg_type = ACK_MSG_TYPE;
            queue_msg.msg.field1 = data_msg->sender;
            queue_msg.msg.field2 = data_msg->temperature;
            call MessageQueue.enqueue(queue_msg);
            if (TOS_NODE_ID != 0) {
                queue_msg.dst = next_hop_to_sink;
                queue_msg.msg.msg_type = data_msg->msg_type;
                call MessageQueue.enqueue(queue_msg);
            } else {
                dbg_clear(DEBUG_DATA, "%s | %02u | DATA(sender=%u, temperature=%d) received\n", sim_time_string(), TOS_NODE_ID, data_msg->sender, data_msg->temperature);
                if (data_msg->temperature > threshold) {
                    threshold = data_msg->temperature + THRESHOLD_INCREASE;
                    dbg_clear(DEBUG_TH, "%s | %02u | threshold = %d\n", sim_time_string(), TOS_NODE_ID, threshold);
                }
            }
        } else if (generic_msg->msg_type == ACK_MSG_TYPE) {
            dbg_clear(DEBUG_ACK, "%s | %02u | ACK received\n", sim_time_string(), TOS_NODE_ID);
            call AckTimer.stop();
            awaiting_ack = FALSE;
        } else {
            dbgerror_clear(DEBUG_ERR, "%s | %02u | +++ERROR+++ UNRECOGNIZED MESSAGE TYPE %d\n", sim_time_string(), TOS_NODE_ID, generic_msg->msg_type);
        }
        return msg;
    }
}