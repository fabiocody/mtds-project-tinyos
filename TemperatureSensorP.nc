// TemperatureSensorP.nc

module TemperatureSensorP {
    provides interface Read<int16_t>;
    uses interface Random;
    uses interface Timer<TMilli> as Timer0;
} implementation {

    int16_t temperature = 2000;

    command error_t Read.read() {
        call Timer0.startOneShot(1);
        return SUCCESS;
    }

    event void Timer0.fired() {
        uint8_t sign = call Random.rand16() & 0x1;
        int16_t increment = call Random.rand16() & 0xf;
        increment = sign ? -increment : increment;
        temperature += increment;
        signal Read.readDone(SUCCESS, temperature);
    }

}