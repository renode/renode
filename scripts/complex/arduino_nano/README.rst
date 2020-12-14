This demo shows a simple Renode-ArduinoIDE integration.

It sets up the simulation, preparing the platform and loading
samples into the sensor's buffer and waits for ArduinoIDE to
load the binary.

Currently the setup is prepared for a patched TensorFlow Lite magic_wand
sample compiled for the Arduino NANO 33 BLE platform.

The patch changes the UART output device from the default USB serial
(not currently supported in Renode) to the hardware UART0.
In order to do that, modify the `debug_log.cpp` file located in 
the `Arduino/libraries/Arduino_TensorFlowLite/src/tensorflow/lite/micro/arduino` directory
and define `DEBUG_SERIAL_OBJECT` as `Serial1` (instead of `Serial`), e.g. with the following command::

    sed -i'' '/#define DEBUG_SERIAL_OBJECT/s/(Serial)/(Serial1)/' ~/Arduino/libraries/Arduino_TensorFlowLite/src/tensorflow/lite/micro/arduino/debug_log.cpp

With this change, you should see the following output on uart0 when running the simulation::

    bytes lost due to alignment. To avoid this loss, please make sure the tensor_arena is 16 bytes aligned.
    Magic starts!
    RING:
              *
           *     *
         *         *
        *           *
         *         *
           *     *
              *
