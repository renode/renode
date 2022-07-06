*** Variables ***
${UART}                       sysbus.uart0
${URI}                        @https://dl.antmicro.com/projects/renode

${LSM303DLHC}=     SEPARATOR=
...  """                                                        ${\n}
...  using "platforms/cpus/nrf52840.repl"                       ${\n}
...                                                             ${\n}
...  lsm303dlhc_a: Sensors.LSM303DLHC_Accelerometer @ twi1 0x19 ${\n}
...  ${SPACE*4}\[IRQ0,IRQ1\] -> gpio0@\[26,27\]                 ${\n}
...                                                             ${\n}
...  lsm303dlhc_g: Sensors.LSM303DLHC_Gyroscope @ twi1 0x1e     ${\n}
...  """

${MAGNETICFIELD}=    SEPARATOR=
... """                                            ${\n}
... Magnetometer data:                             ${\n}
... ( x y z ) = ( 20.000000  5.000000  -5.000000 ) ${\n}
... """

${ACCELERATION}=    SEPARATOR=
... """                                            ${\n}
... Accelerometer data:                            ${\n}
... ( x y z ) = ( 11.998728  3.993192  -2.001384 ) ${\n}
... """


*** Keywords ***
Create Machine
	Execute Command          mach create
	Execute Command          machine LoadPlatformDescriptionFromString ${LSM303DLHC}
	Execute Command          sysbus LoadELF ${URI}/nrf52840--zephyr_lsm303dlhc.elf-s_740272-51b2a14ca50e54790a80d65ed347f04d7d36c373

*** Test Cases ***
Should Read MagneticField
	Create Machine
	Create Terminal Tester    ${UART}

	Execute Command           sysbus.twi1.lsm303dlhc_g MagneticFieldX 20
	Execute Command           sysbus.twi1.lsm303dlhc_g MagneticFieldY 5
	Execute Command           sysbus.twi1.lsm303dlhc_g MagneticFieldZ -5

	Start Emulation
	Wait For Line On Uart     ${MAGNETICFIELD}

Should Read Acceleration
	Create Machine
	Create Terminal Tester    ${UART}

	Execute Command           sysbus.twi1.lsm303dlhc_a AccelerationX 12
	Execute Command           sysbus.twi1.lsm303dlhc_a AccelerationY 4
	Execute Command           sysbus.twi1.lsm303dlhc_a AccelerationZ -2

	Start Emulation
	Wait For Line On Uart     ${ACCELERATION}
