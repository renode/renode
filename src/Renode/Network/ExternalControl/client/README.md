# Renode API

## Server

The server's implementation can be found in this repository in `src/Renode/Network/ExternalControl/ExternalControlServer.cs`.

Besides building Renode from source, the server can be also dynamically compiled into Renode from the Monitor with `i @ExternalControlServer.cs` assuming the current directory contains the source file.

From the Monitor, the server can be started with:
```
emulation CreateExternalControlServer "<NAME>" <PORT>
```

## Client

The client's header, library and examples can be found under `renode/src/Renode/Network/ExternalControl/client` and all further paths starting with `client/` will be relative to the given directory.

### Header

The Renode API header file is `client/include/renode_api.h`.

### Library

The Renode API library sources can be found in the `client/lib` directory.

The currently implemented functions from the header file are:
* `renode_connect`
* `renode_disconnect`
* `run_for`

The proposed error handling by returning a pointer to `error_t` struct isn't currently fully implemented and `exit(EXIT_FAILURE)` is called in case of an error.

The library itself can be built with CMake using the `client/lib/CMakeLists.txt`.
`librenode_api.a` can be built in the `build` directory from the Renode repository's root directory with:
```bash
renode$ mkdir build && cmake -S src/Renode/Network/ExternalControl/client/lib -B build && cmake --build build
```

### Building

Besides building a library and linking a client to the library, a client can be built with CMake using `client/CMakeLists.txt`.
CMake variables can be used to set:
* application name (`APP_NAME`)
* path to the directory containing sources (`APP_SOURCES_DIR`)
* compile flags (optional `APP_COMPILE_FLAGS`; the default is `-Wall;-Wextra;-Werror`)

For example, `example_client` application with sources in `~/example_client/src` directory can be built in the `build` directory from the Renode repository's root directory with:
```bash
renode$ mkdir build && cmake -DAPP_NAME=example_client -DAPP_SOURCES_DIR=~/example_client/src -S src/Renode/Network/ExternalControl/client -B build && cmake --build build
```

### `run_for` example

The example application using Renode API can be found in `examples/run_for`.

It can be built in the `build` directory from the Renode repository's root directory with:
```bash
renode$ mkdir build && cmake -DAPP_NAME=run_for -DAPP_SOURCES_DIR=src/Renode/Network/ExternalControl/client/examples/run_for -S src/Renode/Network/ExternalControl/client -B build && cmake --build build
```

After starting the server in Renode, the `run_for` application can be used multiple times to progress emulation time.

The usage is:
```
Usage:
  ./test_run_for <PORT> <VALUE_WITH_UNIT>
  where:
  * <VALUE_WITH_UNIT> is an integer with a time unit, e.g.: '100ms'
  * accepted time units are 's', 'ms' and 'us' (for microseconds)
```
