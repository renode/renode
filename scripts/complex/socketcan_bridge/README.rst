SocketCAN Bridge demo based on Nucleo H743ZI platform
=====================================================

This demo showcases host integration for CAN.

Host requirements
-----------------

On the host side you'll need to create a virtual CAN interface.

For this, ensure that the ``vcan`` module is loaded::

    # modprobe vcan

To setup a virtual bus, named ``vcan0``,  run the following commands::

    # ip link add dev vcan0 type vcan
    # ip link set up vcan0

Running the demo
----------------

With the host prepared, running the script will generate some traffic on the ``vcan0`` interface::

    (monitor) start @scripts/complex/socketcan_bridge/nucleo_h743zi-socketcanbridge.resc

All packets from ``vcan0`` will be routed to the ``canHub`` object inside Renode,
which is a simulated CAN bus with the Nucleo's CAN controller, ``fdcan1``, connected to it.

You can see the packets using Wireshark or the ``candump`` tool.

To send a test packet from host to Renode you can use the ``cansend`` tool, e.g.::

    $ cansend vcan0 "123#00FFAA5501020304" # classic CAN frame
    $ cansend vcan0 "213##F444546474849505152535455" # FD CAN frame

Note that FD and XL CAN frame routing depends on the host supporting it.
