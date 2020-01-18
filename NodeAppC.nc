configuration NodeAppC {}
implementation {
    components NodeC, MainC;
    components TemperatureSensorC;
    components new TimerMilliC();

    NodeC.TemperatureSensor -> TemperatureSensorC;
    NodeC.Timer0 -> TimerMilliC;
    NodeC.Boot -> MainC;
}