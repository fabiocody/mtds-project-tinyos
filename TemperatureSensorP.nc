// TemperatureSensorP.nc

generic module TemperatureSensorP() {
    provides interface Read<int16_t>;
    uses interface Random;
} implementation {
    int16_t temperature = 2000;

    task void readTask() {
        uint8_t sign = call Random.rand16() & 0x1;
        int16_t increment = call Random.rand16() & 0xf;
        increment = sign ? -increment : increment;
        temperature += increment;
        signal Read.readDone(SUCCESS, temperature);
    }

    command error_t Read.read() {
        post readTask();
        return SUCCESS;
    }
}