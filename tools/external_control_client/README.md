# Renode API

## Server

The server's implementation can be found in this repository in `src/Renode/Network/ExternalControl/ExternalControlServer.cs`.

Besides building Renode from source, the server can be also dynamically compiled into Renode from the Monitor with `i @ExternalControlServer.cs` assuming the current directory contains the source file.

From the Monitor, the server can be started with:
```
emulation CreateExternalControlServer "<NAME>" <PORT>
```

## Client

The client's header, library and examples can be found under `tools/external_control_client` and all further paths starting with `./` will be relative to this directory.

### Header

The Renode API header file is `./include/renode_api.h`.

### Library

The Renode API library sources can be found in the `./lib` directory.

The currently implemented functions from the header file are:
* `renode_connect`
* `renode_disconnect`
* `renode_run_for`
* `renode_get_current_time`
* `renode_error_free`

The library itself can be built with CMake using the `./lib/CMakeLists.txt`.
`librenode_api.a` can be built in the `build` directory from the Renode repository's root directory with:
```bash
renode$ mkdir build && cmake -S tools/external_control_client/lib -B build && cmake --build build
```

### Building

Besides building a library and linking a client to the library, a client can be built with CMake using `./CMakeLists.txt`.
CMake variables can be used to set:
* application name (`APP_NAME`)
* path to the directory containing sources (`APP_SOURCES_DIR`)
* compile flags (optional `APP_COMPILE_FLAGS`; the default is `-Wall;-Wextra;-Werror`)

For example, `example_client` application with sources in `~/example_client/src` directory can be built in the `build` directory from the Renode repository's root directory with:
```bash
renode$ mkdir build && cmake -DAPP_NAME=example_client -DAPP_SOURCES_DIR=~/example_client/src -S tools/external_control_client -B build && cmake --build build
```

### `run_for` example

The example application using Renode API can be found in `examples/run_for`.

It can be built in the `build` directory from the Renode repository's root directory with:
```bash
renode$ mkdir build && cmake -DAPP_NAME=run_for -DAPP_SOURCES_DIR=tools/external_control_client/examples/run_for -S tools/external_control_client -B build && cmake --build build
```

After starting the server in Renode, the `run_for` application can be used to progress emulation time multiple times with an ability to run it again and connect to the same server.

Following every executed set it will ask whether to continue with the current configuration, defaults to `No`.
This prompt also has an option (`c` for change) to provide a new time value, using the same format as the CLI argument, with an optional new number of times to run, defaults to 1. 

The usage is:
```
Usage:
  ./test_run_for <PORT> <VALUE_WITH_UNIT> [<REPEAT>]
  where:
  * <VALUE_WITH_UNIT> is an integer with a time unit, e.g.: '100ms'
  * accepted time units are 's', 'ms' and 'us' (for microseconds)
  * <REPEAT> is an optional number of times (default: 1) to run
  * the simulation for
```

### `adc` example

The example application using Renode API can be found in `examples/adc`.

It can be built in the `build` directory from the Renode repository's root directory with:
```bash
renode$ mkdir build && cmake -DAPP_NAME=adc -DAPP_SOURCES_DIR=tools/external_control_client/examples/adc -S tools/external_control_client -B build && cmake --build build
```

After starting the server in Renode, the `adc` application can be used multiple times to set ADC channel 0 value.

The usage is:
```
Usage:
  ./adc <PORT> <MACHINE_NAME> <ADC_NAME> <VALUE_WITH_UNIT>
  where:
  * <VALUE_WITH_UNIT> is an unsigned integer with a voltage unit, e.g.: '100mV'
  * accepted voltage units are 'V', 'mV' and 'uV' (for microvolts)
```

### `gpio` example

The example application using Renode API can be found in `examples/gpio`.

It can be built in the `build` directory from the Renode repository's root directory with:
```bash
renode$ mkdir build && cmake -DAPP_NAME=gpio -DAPP_SOURCES_DIR=tools/external_control_client/examples/gpio -S tools/external_control_client -B build && cmake --build build
```


After starting the server in Renode, the `gpio` application can be used in three different modes.

In the first mode, it returns the current state of a pin. This happens when only the required arguments are provided.

In the second mode, the application can be used to set the state of a pin. This happens when the last argument is either `true` or `false`.

Finally, the application can show GPIO state changes as the simulation is running by subscribing to GPIO state change events. This happens when the last argument is set to `event`.

The usage is:
```
Usage:
  ./gpio <PORT> <MACHINE_NAME> <GPIO_NAME> <NUMBER> [true|false|event]
```

### `sysbus` example

The example application using Renode API can be found in `examples/sysbus`.

It can be built in the `build` directory from the Renode repository's root directory with:
```bash
renode$ mkdir build && cmake -DAPP_NAME=sysbus -DAPP_SOURCES_DIR=tools/external_control_client/examples/sysbus -S tools/external_control_client -B build && cmake --build build
```

After starting the server in Renode, the `sysbus` application can be used to write a value to Renode's system bus at a specified address and read it back using various access widths.
The same operation is then repeated using a peripheral context, which enables the bus access to see the bus as the specified peripheral does.

The usage is:
```
Usage:
  ./sysbus <PORT> <MACHINE_NAME> <PERIPHERAL_NAME> <ADDRESS>
```
