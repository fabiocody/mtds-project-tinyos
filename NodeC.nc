// NodeC.nc

#include "constants.h"
#include "messages.h"


module NodeC {
    uses interface Read<int16_t> as TemperatureSensor;
    uses interface Timer<TMilli> as TemperatureTimer;
    uses interface Timer<TMilli> as SetupTimer;
    uses interface Boot;
    uses interface Packet;
    uses interface AMPacket;
    uses interface AMSend;
    uses interface Receive;
    uses interface SplitControl as AMControl;
    uses interface Queue<DATA_msg_t> as MessageQueue;
} implementation {
    uint16_t setup_id = 0;
    int16_t threshold;
    uint16_t next_hop_to_sink;
    message_t pkt;

    event void Boot.booted() {
        if (TOS_NODE_ID != 0) call TemperatureTimer.startPeriodic(TEMPERATURE_TIMER_PERIOD);
        call AMControl.start();
    }

    event void AMControl.startDone(error_t err) {
        if (err == SUCCESS) {
            if (TOS_NODE_ID == 0) call SetupTimer.startPeriodic(SETUP_TIMER_PERIOD);
        } else {
            call AMControl.start();
        }
    }

    event void AMControl.stopDone(error_t err) {}
    
    event void TemperatureTimer.fired() {
        call TemperatureSensor.read();
    }

    event void SetupTimer.fired() {
        SETUP_msg_t *setup_msg = (SETUP_msg_t *) call Packet.getPayload(&pkt, sizeof(SETUP_msg_t));
        if (setup_msg == NULL) {
            dbgerror_clear(DEBUG_ERR, "%s | %02u | +++ERROR+++ NULL payload\n", sim_time_string(), TOS_NODE_ID);
            return;
        }
        setup_id++;
        setup_msg->msg_type = SETUP_MSG_TYPE;
        setup_msg->setup_id = setup_id;
        setup_msg->threshold = INITIAL_THRESHOLD;
        if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(SETUP_msg_t)) == SUCCESS) {
            dbg_clear(DEBUG_OUT, "%s | %02u | SETUP(setup_id=%u, threshold=%d) flooded\n", sim_time_string(), TOS_NODE_ID, setup_id, threshold);
        } else {
            dbgerror_clear(DEBUG_ERR, "%s | %02u | +++ERROR+++ SETUP(setup_id=%u, threshold=%d) failed to flood\n", sim_time_string(), TOS_NODE_ID, setup_id, threshold);
        }
    }

    event void TemperatureSensor.readDone(error_t err, int16_t temperature) {
        dbg_clear(DEBUG_TEMP, "%s | %02u | temperature = %d\n", sim_time_string(), TOS_NODE_ID, temperature);
        if (setup_id > 0 && temperature > threshold) {
            DATA_msg_t *data_msg = (DATA_msg_t *) call Packet.getPayload(&pkt, sizeof(DATA_msg_t));
            if (data_msg == NULL) {
                dbgerror_clear(DEBUG_ERR, "%s | %02u | +++ERROR+++ NULL payload\n", sim_time_string(), TOS_NODE_ID);
                return;
            }
            data_msg->msg_type = DATA_MSG_TYPE;
            data_msg->sender = TOS_NODE_ID;
            data_msg->temperature = temperature;
            if (call AMSend.send(next_hop_to_sink, &pkt, sizeof(DATA_msg_t)) == SUCCESS) {
                dbg_clear(DEBUG_OUT, "%s | %02u | DATA(temperature=%d) sent to %u\n", sim_time_string(), TOS_NODE_ID, temperature, next_hop_to_sink);
            } else {
                dbgerror_clear(DEBUG_ERR, "%s | %02u | +++ERROR+++ DATA(temperature=%d) failed to send\n", sim_time_string(), TOS_NODE_ID, temperature);
            }
        }
    }

    event void AMSend.sendDone(message_t *msg, error_t err) {}

    task void floodSetup() {
        SETUP_msg_t *setup_msg = (SETUP_msg_t *) call Packet.getPayload(&pkt, sizeof(SETUP_msg_t));
        if (setup_msg == NULL) {
            dbgerror_clear(DEBUG_ERR, "%s | %02u | +++ERROR+++ NULL payload\n", sim_time_string(), TOS_NODE_ID);
            return;
        }
        setup_msg->msg_type = SETUP_MSG_TYPE;
        setup_msg->setup_id = setup_id;
        setup_msg->threshold = threshold;
        if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(SETUP_msg_t)) == SUCCESS) {
            dbg_clear(DEBUG_DBG, "%s | %02u | SETUP(setup_id=%u, threshold=%d) flooded\n", sim_time_string(), TOS_NODE_ID, setup_id, threshold);
        } else {
            dbgerror_clear(DEBUG_ERR, "%s | %02u | +++ERROR+++ SETUP(setup_id=%u, threshold=%d) failed to flood\n", sim_time_string(), TOS_NODE_ID, setup_id, threshold);
        }
    }

    task void forwardData() {
        DATA_msg_t saved_data_msg;
        DATA_msg_t *data_msg;
        if (call MessageQueue.empty()) return;
        data_msg = (DATA_msg_t *) call Packet.getPayload(&pkt, sizeof(DATA_msg_t));
        if (data_msg == NULL) {
            dbgerror_clear(DEBUG_ERR, "%s | %02u | +++ERROR+++ NULL payload\n", sim_time_string(), TOS_NODE_ID);
            return;
        }
        saved_data_msg = (DATA_msg_t) call MessageQueue.dequeue();
        data_msg->msg_type = saved_data_msg.msg_type;
        data_msg->sender = saved_data_msg.sender;
        data_msg->temperature = saved_data_msg.temperature;
        if (call AMSend.send(next_hop_to_sink, &pkt, sizeof(DATA_msg_t)) == SUCCESS) {
            dbg_clear(DEBUG_OUT, "%s | %02u | DATA(temperature=%d, sender=%u) forwarded to %u\n", sim_time_string(), TOS_NODE_ID, saved_data_msg.temperature, saved_data_msg.sender, next_hop_to_sink);
        } else {
            dbgerror_clear(DEBUG_ERR, "%s | %02u | +++ERROR+++ DATA(temperature=%d, sender=%u) failed to forward\n", sim_time_string(), TOS_NODE_ID, saved_data_msg.temperature, saved_data_msg.sender);
        }
    }

    event message_t *Receive.receive(message_t *msg, void *payload, uint8_t len) {
        GENERIC_msg_t *generic_msg = (GENERIC_msg_t *) payload;
        if (generic_msg->msg_type == SETUP_MSG_TYPE) {
            if (TOS_NODE_ID != 0) {
                SETUP_msg_t *setup_msg = (SETUP_msg_t *) payload;
                if (setup_msg->setup_id > setup_id) {
                    setup_id = setup_msg->setup_id;
                    threshold = setup_msg->threshold;
                    next_hop_to_sink = call AMPacket.source(msg);
                    dbg_clear(DEBUG_OUT, "%s | %02u | SETUP(setup_id=%u, threshold=%d) received from %u\n", sim_time_string(), TOS_NODE_ID, setup_id, threshold, next_hop_to_sink);
                    post floodSetup();
                }
            }
        } else if (generic_msg->msg_type == DATA_MSG_TYPE) {
            DATA_msg_t *data_msg = (DATA_msg_t *) payload;
            if (TOS_NODE_ID != 0) {
                call MessageQueue.enqueue(*data_msg);
                post forwardData();
            } else {
                threshold = data_msg->temperature > threshold ? data_msg->temperature : threshold;
                dbg_clear(DEBUG_OUT, "%s | %02u | DATA(temperature=%d, sender=%u) received\n", sim_time_string(), TOS_NODE_ID, data_msg->temperature, data_msg->sender);
            }
        } else {
            dbgerror_clear(DEBUG_ERR, "%s | %02u | UNRECOGNIZED MESSAGE TYPE %d\n", sim_time_string(), TOS_NODE_ID, generic_msg->msg_type);
        }
        return msg;
    }
}