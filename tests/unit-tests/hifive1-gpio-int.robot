*** Variables ***
${URI}                          @https://dl.antmicro.com/projects/renode
${HIFIVE1}                      @platforms/cpus/sifive-fe310.repl


*** Keywords ***
Create Machine
    Execute Command             using sysbus
    Execute Command             mach create
    Execute Command             machine LoadPlatformDescription @${HIFIVE1}
    Execute Command             sysbus LoadELF @${URI}/hifive--zephyr-test_gpio_api_1pin.elf-s_642052-3e07acfbb42b60dfda51d4a66eb6f4ad714d3e34

    Create Terminal Tester      sysbus.uart0


*** Test Cases ***
Should Pass Zephyr "drivers/gpio/gpio_api_1pin" test suite on HiFive1
    Create Machine
    Wait For Line On Uart       PROJECT EXECUTION SUCCESSFUL
