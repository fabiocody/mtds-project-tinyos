// TemperatureSensorC.nc


configuration TemperatureSensorC {
    provides interface Read<int16_t>;
} implementation {
    components MainC, RandomC;
    components new TemperatureSensorP();

    Read = TemperatureSensorP;
    TemperatureSensorP.Random -> RandomC;
    //RandomC <- MainC.SoftwareInit;
}