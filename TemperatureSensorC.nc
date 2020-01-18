// TemperatureSensorC.nc


configuration TemperatureSensorC {
    provides interface Read<int16_t>;
} implementation {

    components MainC, RandomC;
    components TemperatureSensorP;
    components new TimerMilliC();

    Read = TemperatureSensorP;
    TemperatureSensorP.Timer0 -> TimerMilliC;
    TemperatureSensorP.Random -> RandomC;
    RandomC <- MainC.SoftwareInit;

}