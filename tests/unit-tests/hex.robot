
*** Keywords ***
Create Machine
    [Arguments]              ${hex_file}
    Execute Command          mach create
    Execute Command          machine LoadPlatformDescription @platforms/boards/stm32f072b_discovery.repl
    Execute Command          sysbus LoadHEX @${hex_file}


*** Test Cases ***
Should Load HEX
    Create Machine           https://dl.antmicro.com/projects/renode/stm32f072b_disco--zephyr-hello_world.hex-s_34851-4e97c68491cf652d0becd549526cd3df56e8ae66
    Execute Command          sysbus.cpu VectorTableOffset 0x08000000

    Create Terminal Tester   sysbus.usart1
    Start Emulation

    Wait For Line On Uart    Hello World! stm32f072b_disco
	
