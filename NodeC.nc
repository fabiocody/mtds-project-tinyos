// NodeC.nc


module NodeC {
    uses interface Read<int16_t> as TemperatureSensor;
    uses interface Timer<TMilli> as Timer0;
    uses interface Boot;
} implementation {

    event void Boot.booted() {
        call Timer0.startPeriodic(1000);
    }
    
    event void Timer0.fired() {
        call TemperatureSensor.read();
    }

    event void TemperatureSensor.readDone(error_t err, int16_t t) {
        dbg("NodeC", "Temperature = %d\n", t);
    }

}