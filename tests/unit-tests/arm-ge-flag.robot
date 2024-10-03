*** Variables ***
${REPL}=            SEPARATOR=
...  """                                                                           ${\n}
...  nvic: IRQControllers.NVIC @ {                                                 ${\n}
...      sysbus new Bus.BusPointRegistration { address: 0xe000e000; cpu: cpu }     ${\n}
...  }                                                                             ${\n}
...  ${SPACE*4}-> cpu@0                                                            ${\n}
...                                                                                ${\n}
...  cpu: CPU.CortexM @ sysbus                                                     ${\n}
...  ${SPACE*4}cpuType: "cortex-m7"                                                ${\n}
...  ${SPACE*4}nvic: nvic                                                          ${\n}
...  """

*** Keywords ***
Create Machine
    Execute Command        using sysbus
    Execute Command        mach create
    Execute Command        machine LoadPlatformDescriptionFromString ${REPL}
    Execute Command        cpu ExecutionMode SingleStep
    Execute Command        cpu PC 0x0
    Execute Command        machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus 0x0 { size: 0x8000000 }"

*** Test Cases ***
Signed Byte Addition Should Set GE Flag If And Only If The Result Is Greater Or Equal To Zero (sadd8)
    ${prog}=               Catenate  SEPARATOR=\n
    ...                    movw r0, #0x0000
    ...                    movt r0, #0x0000
    ...                    movw r1, #0xFFFF
    ...                    movt r1, #0xFFFF
    ...                    movw r2, #0x0C0A
    ...                    movt r2, #0x0C0A
    ...                    movw r3, #0xF5F5
    ...                    movt r3, #0xF5F5
    ...                    sadd8 r2, r2, r3
    ...                    sel r4, r1, r0

    Create Machine

    Execute Command        sysbus.cpu AssembleBlock 0 "${prog}"

    Execute Command        cpu Step 10

    ${ret}=                Execute Command  sysbus.cpu GetRegister "R4"

    Should Be Equal As Numbers  ${ret}  0xFF00FF00

Signed Word Addition Should Set GE Flag If And Only If The Result Is Greater Or Equal To Zero (sadd16)
    ${prog}=               Catenate  SEPARATOR=\n
    ...                    movw r0, #0x0000
    ...                    movt r0, #0x0000
    ...                    movw r1, #0xFFFF
    ...                    movt r1, #0xFFFF
    ...                    movw r2, #0x0A23
    ...                    movt r2, #0x0A25
    ...                    movw r3, #0xF123
    ...                    movt r3, #0xFAA2
    ...                    sadd16 r2, r2, r3
    ...                    sel r4, r1, r0

    Create Machine

    Execute Command        sysbus.cpu AssembleBlock 0 "${prog}"

    Execute Command        cpu Step 10

    ${ret}=                Execute Command  sysbus.cpu GetRegister "R4"

    Should Be Equal As Numbers  ${ret}  0xFFFF0000

Signed Byte Subtraction Should Set GE Flag If And Only If The Result Is Greater Or Equal To Zero (ssub8)
    ${prog}=               Catenate  SEPARATOR=\n
    ...                    movw r0, #0x0000
    ...                    movt r0, #0x0000
    ...                    movw r1, #0xFFFF
    ...                    movt r1, #0xFFFF
    ...                    movw r2, #0x0A0C
    ...                    movt r2, #0x0A0C
    ...                    movw r3, #0x0B0B
    ...                    movt r3, #0x0B0B
    ...                    ssub8 r2, r2, r3
    ...                    sel r4, r1, r0

    Create Machine

    Execute Command        sysbus.cpu AssembleBlock 0 "${prog}"

    Execute Command        cpu Step 10

    ${ret}=                Execute Command  sysbus.cpu GetRegister "R4"

    Should Be Equal As Numbers  ${ret}  0x00FF00FF

Signed Word Subtraction Should Set GE Flag If And Only If The Result Is Greater Or Equal To Zero (ssub16)
    ${prog}=               Catenate  SEPARATOR=\n
    ...                    movw r0, #0x0000
    ...                    movt r0, #0x0000
    ...                    movw r1, #0xFFFF
    ...                    movt r1, #0xFFFF
    ...                    movw r2, #0x0A25
    ...                    movt r2, #0x0A23
    ...                    movw r3, #0x0A24
    ...                    movt r3, #0x0A24
    ...                    ssub16 r2, r2, r3
    ...                    sel r4, r1, r0

    Create Machine

    Execute Command        sysbus.cpu AssembleBlock 0 "${prog}"

    Execute Command        cpu Step 10

    ${ret}=                Execute Command  sysbus.cpu GetRegister "R4"

    Should Be Equal As Numbers  ${ret}  0x0000FFFF

Unsigned Byte Subtraction Should Set GE Flag If And Only If The Result Is Greater Or Equal To Zero (usub8)
    ${prog}=               Catenate  SEPARATOR=\n
    ...                    movw r0, #0x0000
    ...                    movt r0, #0x0000
    ...                    movw r1, #0xFFFF
    ...                    movt r1, #0xFFFF
    ...                    movw r2, #0x0A0C
    ...                    movt r2, #0x0C0A
    ...                    movw r3, #0x0B0B
    ...                    movt r3, #0x0B0B
    ...                    ssub8 r2, r2, r3
    ...                    sel r4, r1, r0

    Create Machine

    Execute Command        sysbus.cpu AssembleBlock 0 "${prog}"

    Execute Command        cpu Step 10

    ${ret}=                Execute Command  sysbus.cpu GetRegister "R4"

    Should Be Equal As Numbers  ${ret}  0xFF0000FF

Unsigned Word Subtraction Should Set GE Flag If And Only If The Result Is Greater Or Equal To Zero (usub16)
    ${prog}=               Catenate  SEPARATOR=\n
    ...                    movw r0, #0x0000
    ...                    movt r0, #0x0000
    ...                    movw r1, #0xFFFF
    ...                    movt r1, #0xFFFF
    ...                    movw r2, #0x0A25
    ...                    movt r2, #0x0A23
    ...                    movw r3, #0x0A24
    ...                    movt r3, #0x0A24
    ...                    usub16 r2, r2, r3
    ...                    sel r4, r1, r0

    Create Machine

    Execute Command        sysbus.cpu AssembleBlock 0 "${prog}"

    Execute Command        cpu Step 10

    ${ret}=                Execute Command  sysbus.cpu GetRegister "R4"

    Should Be Equal As Numbers  ${ret}  0x0000FFFF
