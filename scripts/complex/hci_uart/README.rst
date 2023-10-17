This demo shows integration with an external BLE controller through the HCI UART protocol, for details see `the relevant chapter in the Renode docs <https://renode.readthedocs.io/en/latest/tutorials/ble-hci-integration.html>`_.

There are two pre-built samples available that you can select in the ``.resc`` file (uncomment the proper line or set the ``$bin`` variable before loading the script).

``zephyr-hci-uart-ble-peripheral_hr.elf`` is used in a tutorial presenting integration with Android Emulator.
``zephyr-hci-uart-ble-mesh.elf`` is used in a tutorial presenting BLE Mesh networking.

``$port`` variable must be set before loading ``.resc`` file, which will allow to connect Zephyr BLE host stack running in Renode to BLE controller.

You can use the following command to set it at startup:

```
renode  -e "$port=3456; $bin=@/home/user/zephyrproject/zephyr/hci_peripheral_hr/zephyr/zephyr.elf; i @scripts/complex/hci_uart/hci_uart.resc"
```
