// TemperatureSensorC.nc


// Configuration of the temperature sensor
configuration TemperatureSensorC {
    provides interface Read<int16_t>;
} implementation {
    components RandomC;
    components new TemperatureSensorP();

    Read = TemperatureSensorP;
    TemperatureSensorP.Random -> RandomC;
}