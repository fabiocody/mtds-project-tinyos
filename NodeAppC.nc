// NodeAppC.nc

#include "constants.h"


configuration NodeAppC {}
implementation {
    components NodeC as App;
    components MainC;
    components TemperatureSensorC;
    components new TimerMilliC() as TemperatureTimer;
    components new TimerMilliC() as SetupTimer;
    components new AMSenderC(AM_CHANNEL);
    components new AMReceiverC(AM_CHANNEL);
    components ActiveMessageC;
    components new QueueC(DATA_msg_t, 16);

    App.TemperatureSensor -> TemperatureSensorC;
    App.TemperatureTimer -> TemperatureTimer;
    App.SetupTimer -> SetupTimer;
    App.Boot -> MainC;
    App.Packet -> AMSenderC;
    App.AMPacket -> AMSenderC;
    App.AMSend -> AMSenderC;
    App.Receive -> AMReceiverC;
    App.AMControl -> ActiveMessageC;
    App.MessageQueue -> QueueC;
}