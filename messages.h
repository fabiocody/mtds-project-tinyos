// messages.h


#ifndef MESSAGES_H
#define MESSAGES_H


#define SETUP_MSG_TYPE 1
#define DATA_MSG_TYPE 2


typedef nx_struct GENERIC_msg {
    nx_uint8_t msg_type;
} GENERIC_msg_t;


typedef nx_struct SETUP_msg {
    nx_uint8_t msg_type;
    nx_uint16_t setup_id;
    nx_int16_t threshold;
} SETUP_msg_t;


typedef nx_struct DATA_msg {
    nx_uint8_t msg_type;
    nx_uint16_t sender;
    nx_int16_t temperature;
} DATA_msg_t;


#endif // MESSAGES_H