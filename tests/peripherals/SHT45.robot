*** Variables ***
${UART}                       sysbus.usart2
${URI}                        @https://dl.antmicro.com/projects/renode

${MB85RC1MT}=     SEPARATOR=
...  """                                         ${\n}
...  using "platforms/cpus/stm32l072.repl"       ${\n}
...  sht45: I2C.SHT45 @ i2c1 0x44                ${\n}
...  """

*** Keywords ***
Create Machine
    Execute Command          mach create
    Execute Command          machine LoadPlatformDescriptionFromString ${MB85RC1MT}
    Execute Command          sysbus LoadELF ${URI}/b_l072z_lrwan1--zephyr-sht45_test.elf-s_638824-bf5a9a77e45b638ca49d5fc51fa0bc6f19435b35

*** Test Cases ***
Should Read Measurements And Serial Number
    Create Machine
    Create Terminal Tester    ${UART}
    Execute Command           showAnalyzer ${UART}

    Execute Command           sysbus.i2c1.sht45 Temperature 25
    Execute Command           sysbus.i2c1.sht45 Humidity 60
    Execute Command           sysbus.i2c1.sht45 SerialNumber 0xf0e0d0c0

    Wait For Line On Uart     temperature: 25.0
    Wait For Line On Uart     humidity: 59.999069
    Wait For Line On Uart     serial number: f0e0d0c0
