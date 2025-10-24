*** Variables ***
${REPL_STRING}=  SEPARATOR=\n
...  """
...  using "platforms/boards/silabs/brd4402a.repl"
...
...  cpu:
...  ${SPACE*4}enableTrustZone: true
...  ${SPACE*4}IDAUEnabled: true
...
...  smu:
...  ${SPACE*4}cpu0: cpu
...  """
${UART}                             sysbus.usart0

*** Keywords ***
Create Machine
    Execute Command                 mach create "test"
    Execute Command                 machine LoadPlatformDescriptionFromString ${REPL_STRING}
    Execute Command                 sysbus LoadELF @efr32xg2_smu_nonsecure.elf
    Execute Command                 sysbus LoadELF @efr32xg2_smu_secure.elf
    Execute Command                 sysbus.cpu VectorTableOffset 0x00000000
    Execute Command                 emulation SetGlobalSerialExecution true

*** Test Cases ***
Exercise IDAU
    Create Machine
    Execute Command                 cpu AddHookAtWfiStateChange 'self.Log(LogLevel.Warning, "WFI ENTER" if isInWfi else "WFI EXIT" )'
    Create Log Tester               5
    Create Terminal Tester          ${UART}
    Start Emulation
    Wait For Line On Uart           SMU test
    Wait For Line On Uart           Configuring SAU
    Wait For Line On Uart           Configuring ESAU regions in SMU
    Wait For Line On Uart           Use TT instruction to verify SAU/IDAU programming for various regions
    Wait For Line On Uart           secure code: addr=0x91b reg(mpu:-1 sau:-1 idau::0) r=1 w=1 nsr=0 nsrw=0 sec=1
    Wait For Line On Uart           secure data: addr=0x20000000 reg(mpu:-1 sau:-1 idau::4) r=1 w=1 nsr=0 nsrw=0 sec=1
    Wait For Line On Uart           secure NSC: addr=0x3f000 reg(mpu:-1 sau:0 idau::1) r=1 w=1 nsr=0 nsrw=0 sec=1
    Wait For Line On Uart           nonsecure data: addr=0x20004800 reg(mpu:-1 sau:2 idau::6) r=1 w=1 nsr=0 nsrw=0 sec=0
    Wait For Line On Uart           nonsecure vtor: addr=0x20007f00 reg(mpu:-1 sau:2 idau::6) r=1 w=1 nsr=0 nsrw=0 sec=0
    Wait For Line On Uart           nonsecure code: addr=0x40000 reg(mpu:-1 sau:1 idau::2) r=1 w=1 nsr=0 nsrw=0 sec=0
    Wait For Line On Uart           Greetings from nonsecure code
    Wait For Line On Uart           End of test

