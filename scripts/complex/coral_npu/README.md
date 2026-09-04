## Coral NPU Demo

This demo showcases how to add and utilize simulated [Google Coral NPU](https://github.com/google-coral/coralnpu/tree/main).

For guidelines how to use, check the [integration guide](https://github.com/google-coral/coralnpu/blob/main/doc/integration_guide.md#booting-coralnpu).
The guide explains the boot procedure, which is also done as part of the provided Robot script.

The provided application, is "coralnpu_v2_hello_world_add_floats" - [unmodified sample from the official repository](https://github.com/google-coral/coralnpu/blob/main/examples/hello_world_add_floats.cc).
As inputs, it expects two floats - add value from address `0x10000` and `0x10020`, respectively.
As output, it provides the sum of the two floats - at `0x10040`.
The addresses are given as a relative offset from the start of NPU address space (in this case it's `0xE00000000`)

## External Control Coral NPU Demo

The `./external_control` directory contains scripts demonstrating the same Coral NPU application with the NPU simulated in a separate Renode instance.

Start the server-side simulation by running:

`imx8mplus_linux_coral_external_control_server.resc`

Then start a second Renode instance and run:

`imx8mplus_linux_coral_external_control_client.resc`

The client simulation connects to the server instance and uses its externally simulated NPU.
