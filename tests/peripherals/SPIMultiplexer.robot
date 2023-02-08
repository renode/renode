*** Variables ***
${UART}                       sysbus.uart0
${URI}                        @https://dl.antmicro.com/projects/renode

*** Keywords ***
Create Machine
    Execute Command          $bin=${URI}/nrf52840--zephyr-custom_spi_sensors_cs.elf-s_1125736-5cf7322357c0434481335500e9eb38ebe44948c3
    Execute Command          include @scripts/single-node/nrf52840.resc

    Execute Command          machine LoadPlatformDescriptionFromString "spi_mux: SPI.SPIMultiplexer @ spi2 { init: { SetActiveLow 0; SetActiveLow 1 } }"
    Execute Command          machine LoadPlatformDescriptionFromString "dummy0spi: Mocks.DummySPISlave @ spi_mux 0x0"
    Execute Command          machine LoadPlatformDescriptionFromString "dummy1spi: Mocks.DummySPISlave @ spi_mux 0x1"
    Execute Command          machine LoadPlatformDescriptionFromString "gpio0: { 22 -> spi_mux@0; 23 -> spi_mux@1 }"

*** Test Cases ***
Should Talk to Two SPI Devices
    Create Machine
    Create Terminal Tester   ${UART}
    Execute Command          logLevel -1 sysbus.spi2.spi_mux.dummy0spi
    Execute Command          logLevel -1 sysbus.spi2.spi_mux.dummy1spi
    Execute Command          logLevel 3 sysbus.nvic

    # 0x2B0 -> 21.5 C
    Execute Command          sysbus.spi2.spi_mux.dummy0spi EnqueueValue 0x02
    Execute Command          sysbus.spi2.spi_mux.dummy0spi EnqueueValue 0xB0

    # x 0.008750 , y 0.017500 , z 0.008750
    Execute Command          sysbus.spi2.spi_mux.dummy1spi EnqueueValue 0xFF
    Execute Command          sysbus.spi2.spi_mux.dummy1spi EnqueueValue 0xFF
    Execute Command          sysbus.spi2.spi_mux.dummy1spi EnqueueValue 0xFF
    Execute Command          sysbus.spi2.spi_mux.dummy1spi EnqueueValue 0xFF
    Execute Command          sysbus.spi2.spi_mux.dummy1spi EnqueueValue 0xFF
    Execute Command          sysbus.spi2.spi_mux.dummy1spi EnqueueValue 0x01
    Execute Command          sysbus.spi2.spi_mux.dummy1spi EnqueueValue 0x00
    Execute Command          sysbus.spi2.spi_mux.dummy1spi EnqueueValue 0x02
    Execute Command          sysbus.spi2.spi_mux.dummy1spi EnqueueValue 0x00
    Execute Command          sysbus.spi2.spi_mux.dummy1spi EnqueueValue 0x01
    Execute Command          sysbus.spi2.spi_mux.dummy1spi EnqueueValue 0x00

    Start Emulation

    Wait For Line On Uart    Booting Zephyr
    Wait For Line On Uart    Temperature: 21.50 C
    Wait For Line On Uart    x 0.008750 , y 0.017500 , z 0.008750
