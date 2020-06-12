// NodeAppC.nc

#include "constants.h"


// This is the starting point of the application. It states how the components are wired together.
configuration NodeAppC {}
implementation {
    components NodeC as App;
    components MainC;
    components TemperatureSensorC;
    components new TimerMilliC() as TemperatureTimer;
    components new TimerMilliC() as SetupTimer;
    components new TimerMilliC() as SendTimer;
    components new AMSenderC(AM_CHANNEL);
    components new AMReceiverC(AM_CHANNEL);
    components ActiveMessageC;
    components new QueueC(uint16_t, 16) as InAckQueue;
    components new QueueC(uint16_t, 16) as OutAckQueue;
    components new QueueC(queueable_msg_t, 16) as MessageQueue;

    App.TemperatureSensor -> TemperatureSensorC;
    App.TemperatureTimer -> TemperatureTimer;
    App.SetupTimer -> SetupTimer;
    App.SendTimer -> SendTimer;
    App.Boot -> MainC;
    App.Packet -> AMSenderC;
    App.AMPacket -> AMSenderC;
    App.AMSend -> AMSenderC;
    App.Receive -> AMReceiverC;
    App.AMControl -> ActiveMessageC;
    App.InAckQueue -> InAckQueue;
    App.OutAckQueue -> OutAckQueue;
    App.MessageQueue -> MessageQueue;
}