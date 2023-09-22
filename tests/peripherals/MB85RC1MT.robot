*** Variables ***
${UART}                       sysbus.usart2
${URI}                        @https://dl.antmicro.com/projects/renode

${MB85RC1MT}=     SEPARATOR=
...  """                                         ${\n}
...  using "platforms/cpus/stm32l072.repl"       ${\n}
...                                              ${\n}
...  mb85rc1mt_base: I2C.MB85RC1MT               ${\n}
...                                              ${\n}
...  mb85rc1mt_lo: I2C.MB85RC1MTLo @ i2c1 0x50   ${\n}
...  ${SPACE*4}mb85rc1mt: mb85rc1mt_base         ${\n}
...                                              ${\n}
...  mb85rc1mt_hi: I2C.MB85RC1MTHi @ i2c1 0x51   ${\n}
...  ${SPACE*4}mb85rc1mt: mb85rc1mt_base         ${\n}
...  """

*** Keywords ***
Create Machine
    [Arguments]  ${elf}
	Execute Command          mach create
	Execute Command          machine LoadPlatformDescriptionFromString ${MB85RC1MT}
	Execute Command          sysbus LoadELF ${URI}/${elf}

*** Test Cases ***
Should Read Write Single Byte In Lower Half
	Create Machine            b_l072z_lrwan1--zephyr-mb85rc1mt_test_single_rw_lo.elf-s_600916-15dc98eb4c8dc5994e41aca035997b11ef862e15
	Create Terminal Tester    ${UART}

	Wait For Line On Uart     single rw succesful

Should Read Write Single Byte In Upper Half
	Create Machine            b_l072z_lrwan1--zephyr-mb85rc1mt_test_single_rw_hi.elf-s_600908-ca570f42e3f67a9f8b5a6a4eefe9e755ee443327
	Create Terminal Tester    ${UART}

	Wait For Line On Uart     single rw succesful

Should Read Write Multiple Bytes
	Create Machine            b_l072z_lrwan1--zephyr-mb85rc1mt_test_multiple_rw.elf-s_600964-8ed0caa4fbb6f9a9bcfc77e43c00dc57c95a5f6c
	Create Terminal Tester    ${UART}

	Wait For Line On Uart     multiple rw succesful

Should Read Write Multiple Bytes On Address Boundary
	Create Machine            b_l072z_lrwan1--zephyr-mb85rc1mt_test_multiple_rw_halves_boundary.elf-s_600972-30d5e09c8ebc57bab9472c80d49defbf79f4fbc4
	Create Terminal Tester    ${UART}

	Wait For Line On Uart     multiple rw succesful

Should Not Modify Data When Write Protection Is Active
	Create Machine            b_l072z_lrwan1--zephyr-mb85rc1mt_test_write_protection.elf-s_600892-1f9ae182df41a1e432a1c24a32cc6b3c83b4d35f
	Create Terminal Tester    ${UART}
