// messages.h


#ifndef MESSAGES_H
#define MESSAGES_H


#define SETUP_MSG_TYPE 1
#define DATA_MSG_TYPE 2


typedef nxstruct GENERIC_msg {
    uint8_t msg_type;
} GENERIC_msg;


typedef nxstruct SETUP_msg {
    nxuint8_t msg_type;
    nxuint16_t setup_id;
    nxint16_t threshold;
} SETUP_msg;


typedef nxstruct DATA_msg {
    nxuint8_t msg_type;
    nxuint16_t sender;
    nxint16_t temperature;
} DATA_msg;


#endif // MESSAGES_H