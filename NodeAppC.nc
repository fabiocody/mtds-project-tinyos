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
    components new TimerMilliC() as AckTimer;
    components new AMSenderC(AM_CHANNEL);
    components new AMReceiverC(AM_CHANNEL);
    components ActiveMessageC;
    components new QueueC(queueable_msg_t, 16) as MessageQueue;

    App.TemperatureSensor -> TemperatureSensorC;
    App.TemperatureTimer -> TemperatureTimer;
    App.SetupTimer -> SetupTimer;
    App.SendTimer -> SendTimer;
    App.AckTimer -> AckTimer;
    App.Boot -> MainC;
    App.Packet -> AMSenderC;
    App.AMPacket -> AMSenderC;
    App.AMSend -> AMSenderC;
    App.Receive -> AMReceiverC;
    App.AMControl -> ActiveMessageC;
    App.MessageQueue -> MessageQueue;
}