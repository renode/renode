*** Variables ***
${UART}                       sysbus.uart0
${URI}                        @https://dl.antmicro.com/projects/renode

${BMP180}=     SEPARATOR=
...  """                                         ${\n}
...  using "platforms/cpus/nrf52840.repl"        ${\n}
...                                              ${\n}
...  bmp180: Sensors.BMP180 @ twi0 0x77          ${\n}
...  """

*** Keywords ***
Create Machine
	Execute Command          mach create
	Execute Command          machine LoadPlatformDescriptionFromString ${BMP180}
	Execute Command          sysbus LoadELF ${URI}/BMP180_I2C.ino.arduino.mbed.nano33ble.elf-s_3127076-ba5f49cd34cd9549c2aa44f83af8e2011ecd1c22

*** Test Cases ***
Should Read Temperature
	Create Machine
	Create Terminal Tester    ${UART}

	Execute Command           sysbus.twi0.bmp180 Temperature 24

	Start Emulation

	Wait For Line On Uart     Temperature: 24.00 degC

Should Read Pressure
	Create Machine
	Create Terminal Tester    ${UART}

	Execute Command           sysbus.twi0.bmp180 UncompensatedPressure 1100

	Start Emulation

	Wait For Line On Uart     Pressure: 231048.00 Pa
