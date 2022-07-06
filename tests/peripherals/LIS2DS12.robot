*** Variables ***
${UART}                       sysbus.uart0
${URI}                        @https://dl.antmicro.com/projects/renode

${LIS2DS12}=     SEPARATOR=
...  """                                                 ${\n}
...  using "platforms/cpus/nrf52840.repl"                ${\n}
...                                                      ${\n}
...  lis2ds12: Sensors.LIS2DS12 @ twi1 0x1c              ${\n}
...  ${SPACE*4}IRQ -> gpio0@28                           ${\n}
...  """

*** Keywords ***
Create Machine
	Execute Command          mach create
	Execute Command          machine LoadPlatformDescriptionFromString ${LIS2DS12}
	Execute Command          sysbus LoadELF ${URI}/nrf52840--zephyr_lis2dh.elf-s_747800-163b7e7cc986d4b1115f06b5f3df44ed0defc1fa

*** Test Cases ***
Should Read Acceleration
	Create Machine
	Create Terminal Tester    ${UART}

	Execute Command           sysbus.twi1.lis2ds12 AccelerationX 10
	Execute Command           sysbus.twi1.lis2ds12 AccelerationY 5
	Execute Command           sysbus.twi1.lis2ds12 AccelerationZ -5

	Start Emulation

	Wait For Line On Uart     x 9.997213 , y 4.997410 , z -4.999803
