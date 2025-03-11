*** Variables ***
${program}=  SEPARATOR=${\n}
...  ldr r0, =0x10000000
...  ldr r1, =10000000  @ adjust to taste when running locally
...
...  loop:
...  ldr r2, [r0]
...  subs r1, r1, #1
...  bne loop
...
...  subs r0, r0, #4
...  ldr r2, [r0]

${platform}=     SEPARATOR=${\n}
...  """
...  cpu: CPU.CortexM @ sysbus
...  ${SPACE*4}cpuType: "cortex-m4"
...  ${SPACE*4}nvic: nvic
...
...  nvic: IRQControllers.NVIC @ sysbus 0xE000E000
...
...  rom: Memory.MappedMemory @ sysbus 0x0
...  ${SPACE*4}size: 0x40000
...
...  trivial: Mocks.TrivialPeripheral @ sysbus 0x10000000
...  """

*** Keywords ***
Create Machine
    ${TEST_DIR}=                    Evaluate  r"${CURDIR}".replace(" ", "\\ ")

    Execute Command                 i @${TEST_DIR}/TrivialPeripheral.cs
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString ${platform}
    Execute Command                 using sysbus

    Create Log Tester               10

*** Test Cases ***
Should Access Trivial Peripheral
    Create Machine
    Execute Command                 cpu AssembleBlock 0 """${program}"""
    Execute Command                 cpu PC 0
    Wait For Log Entry              ReadDoubleWord from non existing peripheral at 0xFFFFFFC
