*** Variables ***
${UART}                       sysbus.usart2
${URI}                        @https://dl.antmicro.com/projects/renode

${MB85RC1MT}=     SEPARATOR=
...  """                                         ${\n}
...  using "platforms/cpus/stm32l072.repl"       ${\n}
...  bme280: I2C.BME280@ i2c1 0x76               ${\n}
...  """

*** Keywords ***
Create Machine
    Execute Command          using sysbus
    Execute Command          mach create
    Execute Command          machine LoadPlatformDescriptionFromString ${MB85RC1MT}
    Execute Command          sysbus LoadELF ${URI}/b_l072z_lrwan1--zephyr-bme280_test.elf-s_649120-15b7607a51b50245f4500257c871cd754cfeca5a

*** Test Cases ***
Should Read Measurements
    Create Machine
    Create Terminal Tester    ${UART}

    Execute Command           i2c1.bme280 Temperature 25
    Execute Command           i2c1.bme280 Humidity 60
    Execute Command           i2c1.bme280 Pressure 1000

    Wait For Line On Uart     temperature: 25.0
    Wait For Line On Uart     humidity: 60.231445
    Wait For Line On Uart     pressure: 999.84414
