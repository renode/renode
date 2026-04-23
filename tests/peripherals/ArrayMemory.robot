*** Variables ***
${ELF}                              @https://dl.antmicro.com/projects/renode/96b_neonkey--zephyr-hello_world.elf-s_501484-9ae96ed2a646347a7642504654956afa75923832
${UART}                             sysbus.usart1
${PLATFORM}=     SEPARATOR=
...  """                                                        ${\n}
...  cpu: CPU.CortexM @ sysbus                                  ${\n}
...  ${SPACE*4}cpuType: "cortex-m0+"                            ${\n}
...  ${SPACE*4}numberOfMPURegions: 8                            ${\n}
...  ${SPACE*4}nvic: nvic                                       ${\n}
...  ${SPACE*4}PerformanceInMips: 12                            ${\n}
...                                                             ${\n}
...  nvic: IRQControllers.NVIC @ sysbus 0xE000E000              ${\n}
...  ${SPACE*4}priorityMask: 0xE0                               ${\n}
...  ${SPACE*4}IRQ -> cpu@0                                     ${\n}
...                                                             ${\n}
...  flash0: Memory.ArrayMemory @ sysbus 0x8000000              ${\n}
...  ${SPACE*4}size: 0x80000                                    ${\n}
...                                                             ${\n}
...  sram0: Memory.ArrayMemory @ sysbus 0x20000000              ${\n}
...  ${SPACE*4}size: 0x20000                                    ${\n}
...                                                             ${\n}
...  usart1: UART.STM32_UART @ sysbus <0x40011000, +0x400>      ${\n}
...  ${SPACE*4}->nvic@37                                        ${\n}
...                                                             ${\n}
...  rcc: Miscellaneous.STM32F4_RCC @ sysbus 0x40023800         ${\n}
...  ${SPACE*4}rtcPeripheral: rtc                               ${\n}
...                                                             ${\n}
...  rtc: Timers.STM32F4_RTC @ sysbus 0x40002800                ${\n}
...  ${SPACE*4}AlarmIRQ->nvic@41                                ${\n}
...  """

*** Keywords ***
Create Machine
    Execute Command                 using sysbus
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString ${PLATFORM}
    Execute Command                 sysbus LoadELF ${ELF}
    Execute Command                 cpu VectorTableOffset `sysbus GetSymbolAddress "_vector_table"`

*** Test Cases ***
Should Load Save And Run Demo
    Create Machine
    Execute Command                Save @test.save
    Execute Command                Clear
    Execute Command                Load @test.save
    Execute Command                mach set 0
    
    Create Terminal Tester         ${UART}  defaultPauseEmulation=True
    Execute Command                start
    Wait For Line On Uart          Hello World!
