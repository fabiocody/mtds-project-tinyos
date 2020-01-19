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
} implementation {
    uint16_t setup_id = 0;
    int16_t threshold;
    uint16_t next_hop_to_sink;
    message_t pkt;
    DATA_msg_t data_msg_to_relay;

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
            dbg(DEBUG_ERR, "%s | NULL payload\n", sim_time_string());
            return;
        }
        setup_id++;
        setup_msg->msg_type = SETUP_MSG_TYPE;
        setup_msg->setup_id = setup_id;
        setup_msg->threshold = 2030;
        if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(SETUP_msg_t)) == SUCCESS) {
            dbg(DEBUG_OUT, "%s | Flooded SETUP message with setup_id=%d\n", sim_time_string(), setup_id);
        } else {
            dbg(DEBUG_ERR, "%s | Failed to flood SETUP message with setup_id=%d\n", sim_time_string(), setup_id);
        }
    }

    event void TemperatureSensor.readDone(error_t err, int16_t temperature) {
        dbg(DEBUG_TEMP, "%s | Temperature = %d\n", sim_time_string(), temperature);
        if (setup_id > 0 && temperature > threshold) {
            DATA_msg_t *data_msg = (DATA_msg_t *) call Packet.getPayload(&pkt, sizeof(DATA_msg_t));
            if (data_msg == NULL) {
                dbg(DEBUG_ERR, "%s | NULL payload\n", sim_time_string());
                return;
            }
            data_msg->msg_type = DATA_MSG_TYPE;
            data_msg->sender = TOS_NODE_ID;
            data_msg->temperature = temperature;
            if (call AMSend.send(next_hop_to_sink, &pkt, sizeof(DATA_msg_t)) == SUCCESS) {
                dbg(DEBUG_OUT, "%s | Sent DATA message with temperature=%d\n", sim_time_string(), temperature);
            } else {
                dbg(DEBUG_ERR, "%s | Failed to send DATA message\n", sim_time_string());
            }
        }
    }

    event void AMSend.sendDone(message_t *msg, error_t err) {}

    task void floodSetup() {
        SETUP_msg_t *setup_msg = (SETUP_msg_t *) call Packet.getPayload(&pkt, sizeof(SETUP_msg_t));
        if (setup_msg == NULL) {
            dbg(DEBUG_ERR, "%s | NULL payload\n", sim_time_string());
            return;
        }
        setup_msg->msg_type = SETUP_MSG_TYPE;
        setup_msg->setup_id = setup_id;
        setup_msg->threshold = threshold;
        if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(SETUP_msg_t)) == SUCCESS) {
            dbg(DEBUG_OUT, "%s | Flooded SETUP message with setup_id=%d\n", sim_time_string(), setup_id);
        } else {
            dbg(DEBUG_ERR, "%s | Failed to flood SETUP message with setup_id=%d\n", sim_time_string(), setup_id);
        }
    }

    task void forwardData() {
        DATA_msg_t *data_msg = (DATA_msg_t *) call Packet.getPayload(&pkt, sizeof(DATA_msg_t));
        if (data_msg == NULL) {
            dbg(DEBUG_ERR, "%s | NULL payload\n", sim_time_string());
            return;
        }
        data_msg->msg_type = DATA_MSG_TYPE;
        data_msg->sender = data_msg_to_relay.sender;
        data_msg->temperature = data_msg_to_relay.temperature;
        if (call AMSend.send(next_hop_to_sink, &pkt, sizeof(DATA_msg_t)) == SUCCESS) {
            dbg(DEBUG_OUT, "%s | Forwarded DATA message with temperature=%d to %d\n", sim_time_string(), data_msg_to_relay.temperature, next_hop_to_sink);
        } else {
            dbg(DEBUG_ERR, "%s | Failed to forward DATA message\n", sim_time_string());
        }
    }

    event message_t *Receive.receive(message_t *msg, void *payload, uint8_t len) {
        GENERIC_msg_t *generic_msg = (GENERIC_msg_t *) payload;
        if (generic_msg->msg_type == SETUP_MSG_TYPE) {
            if (TOS_NODE_ID != 0) {
                SETUP_msg_t *setup_msg = (SETUP_msg_t *) payload;
                setup_id = setup_msg->setup_id;
                threshold = setup_msg->threshold;
                next_hop_to_sink = call AMPacket.source(msg);
                dbg(DEBUG_OUT, "%s | Received SETUP message from %d (setup_id=%d)\n", sim_time_string(), next_hop_to_sink, setup_id);
                post floodSetup();
            }
        } else if (generic_msg->msg_type == DATA_MSG_TYPE) {
            DATA_msg_t *data_msg = (DATA_msg_t *) payload;
            if (TOS_NODE_ID != 0) {
                data_msg_to_relay.sender = data_msg->sender;
                data_msg_to_relay.temperature = data_msg->temperature;
                post forwardData();
            } else {
                dbg(DEBUG_OUT, "%s | Received DATA message from %d with temperature=%d\n", sim_time_string(), data_msg->sender, data_msg->temperature);
            }
        } else {
            dbg(DEBUG_ERR, "%s | Unrecognized message type %d\n", sim_time_string(), generic_msg->msg_type);
        }
        return msg;
    }
}