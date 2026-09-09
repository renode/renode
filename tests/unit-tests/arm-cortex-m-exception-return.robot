*** Variables ***

${RESET}                            0x20
${NMI}                              0x100
${INSECURE}                         0x80
${BASE_PLATFORM}                    SEPARATOR=\n
...  cpu: CPU.CortexM @ sysbus
...  ${SPACE*4}cpuType: "cortex-m33"
...  ${SPACE*4}nvic: nvic
...
...  mem: Memory.MappedMemory @ sysbus 0x0
...  ${SPACE*4}size: 0x1000
...
...  nvic: IRQControllers.NVIC @ sysbus 0xE000E000
...  ${SPACE*4}-> cpu@0

*** Keywords ***
Create Machine
    [Arguments]                     ${trustZone}=False
    Execute Command                 mach create
    ${platform}=  Catenate          SEPARATOR=\n  """  ${BASE_PLATFORM}
    IF  ${trustZone}
        ${platform}=  Catenate      SEPARATOR=\n
        ...  ${platform}
        ...  cpu:
        ...  ${SPACE*4}enableTrustZone: true
    END
    ${platform}=  Catenate          SEPARATOR=\n  ${platform}  """
    Execute Command                 machine LoadPlatformDescriptionFromString ${platform}
    Execute Command                 sysbus WriteDoubleWord 0x0 0x800  # Set SP to 0x800
    Execute Command                 sysbus WriteDoubleWord 0x4 ${{${RESET} | 1}}  # Set reset handler (Thumb)
    Execute Command                 cpu AssembleBlock ${RESET} "b ."
    Execute Command                 sysbus WriteDoubleWord 0x8 ${{${NMI} | 1}} # Set NMI handler (Thumb)
    Execute Command                 cpu AssembleBlock ${NMI} "b ."

Execution Of Instruction In Exception Handler Should Result In PC
    [Arguments]  ${instruction}  ${pc}  ${trustZone}=False
    Reset Emulation
    Create Machine  trustZone=${trustZone}

    ${assembly}=  Catenate          SEPARATOR=\n
...  """
...    nop
...    ${instruction}
...  """
    Execute Command                 cpu AssembleBlock ${NMI} ${assembly}

    Execute Command                 cpu Step  # Enter reset loop
    PC Should Be Equal              ${RESET}
    Execute Command                 nvic SetPendingIRQ 2  # Trigger NMI
    Execute Command                 cpu Step
    PC Should Be Equal              ${{${NMI} + 2}}
    Execute Command                 cpu Step
    PC Should Be Equal              ${pc}

Execution Of Instruction In Insecure Code Should Result In PC
    [Arguments]  ${instruction}  ${pc}
    Create Machine                  trustZone=True
    ${assembly}=  Catenate          SEPARATOR=\n
...  """
...    // Set up SAU to allow `insecure` to be accessed from insecure mode
...    ldr r1, =0xe000edd0
...    // Set region 0
...    mov r0, 0
...    str r0, [r1, #0x8]
...    // Set SAU_RBAR to 0x80
...    mov r0, 0x00000080
...    str r0, [r1, #0xc]
...    // Set SAU_RLAR to 0xfff, enabled
...    mov r0, 0x00000fe1
...    str r0, [r1, #0x10]
...    // Enable SAU
...    mov r0, 0b01
...    str r0, [r1]
...
...    mov r0, ${INSECURE}
...    blxns r0
...    nop
...  """
    Execute Command                 cpu AssembleBlock ${RESET} ${assembly}

    Execute Command                 cpu AssembleBlock ${INSECURE} "${instruction}"

    Execute Command                 cpu Step 11
    PC Should Be Equal              ${INSECURE}
    Execute Command                 cpu Step 1
    PC Should Be Equal              ${pc}

*** Test Cases ***
Should Not Return From Exception When Loading PC From Vector Table
    Create Machine
    Execute Command                 sysbus WriteDoubleWord 0xc 0xffffffb0  # Set HardFault handler address to an exception return address

    ${assembly}=  Catenate          SEPARATOR=\n
...  """
...    // Set up MPU so that exception return can fault if SP is protected memory
...    ldr r1, =0xe000ed90
...    // Set region 0
...    mov r0, 0
...    str r0, [r1, #0x8]
...    // Set RBAR to 0x0, readable by all
...    mov r0, 0x00000006
...    str r0, [r1, #0xc]
...    // Set RLAR to 0xfff, enabled
...    mov r0, 0x00000fe1
...    str r0, [r1, #0x10]
...    // Enable MPU
...    mov r0, 0b001
...    str r0, [r1, #0x4]
...    b .
...  """
    Execute Command                 cpu AssembleBlock ${RESET} ${assembly}

    ${assembly}=  Catenate          SEPARATOR=\n
...  """
...    // Trigger HardFault in exception return - stack will be read on exception return,
...    // but since SP is a protected address, this will cause a HardFault
...    mov r0, 0x2000
...    mov sp, r0
...    bx lr
...  """
    Execute Command                 cpu AssembleBlock ${NMI} ${assembly}

    Execute Command                 cpu Step 9  # Init the MPU
    Execute Command                 nvic SetPendingIRQ 2  # Trigger NMI
    Execute Command                 cpu Step 3  # Trigger HardFault
    PC Should Be Equal              0xffffffb0  # An exception return address is loaded from the vector table, it shouldn't be treated as EXC_RETURN

Should Not Return From Exception When In Thread Mode
    Create Machine

    ${assembly}=  Catenate          SEPARATOR=\n
...  """
...    mov r0, 0xffffffb8
...    bx r0
...  """
    Execute Command                 cpu AssembleBlock ${RESET} ${assembly}
    Execute Command                 cpu Step 2
    PC Should Be Equal              0xffffffb8

Should Return From Exception When Using Allowed Instruction
    Execution Of Instruction In Exception Handler Should Result In PC  bx lr  ${RESET}
    Execution Of Instruction In Exception Handler Should Result In PC  bxns lr  ${RESET}  trustZone=True

Should Not Return From Exception When Not Using Allowed Instruction
    Execution Of Instruction In Exception Handler Should Result In PC  blx lr  0xffffffb8
    # Different address since we're returning to secure mode
    Execution Of Instruction In Exception Handler Should Result In PC  blxns lr  0xfffffff8  trustZone=True

Should Not Return From Insecure Mode When Not Using TrustZone
    Create Machine

    ${assembly}=  Catenate          SEPARATOR=\n
...  """
...    mov r0, 0xfeffffff
...    bx r0
...  """
    Execute Command                 cpu AssembleBlock ${RESET} ${assembly}

    Execute Command                 cpu Step 2
    PC Should Be Equal              0xfefffffe  # Last bit is removed due to Thumb-bit stripping

Should Return From Insecure Mode When Using bx
    Execution Of Instruction In Insecure Code Should Result In PC      bx lr  ${{${RESET} + 0x20}}

Should Not Return From Insecure Mode When Using blx
    Execution Of Instruction In Insecure Code Should Result In PC      blx lr  0xfefffffe
