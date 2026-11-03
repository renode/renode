*** Variables ***
${NPU_BASE}                         0x40000000
${ID}                               ${{ ${NPU_BASE} + 0x00 }}
${STATUS}                           ${{ ${NPU_BASE} + 0x04 }}
${CMD}                              ${{ ${NPU_BASE} + 0x08 }}
${RESET}                            ${{ ${NPU_BASE} + 0x0C }}
${QBASE}                            ${{ ${NPU_BASE} + 0x10 }}
${QREAD}                            ${{ ${NPU_BASE} + 0x18 }}
${QSIZE}                            ${{ ${NPU_BASE} + 0x20 }}
${PROT}                             ${{ ${NPU_BASE} + 0x24 }}
${CONFIG}                           ${{ ${NPU_BASE} + 0x28 }}
${COND_STATUS}                      ${{ ${NPU_BASE} + 0x30 }}  # U85 only
${STREAM}                           0x1000

${CMD_RUN}                          0x1
${CMD_CLEAR_IRQ}                    0x2

# STATUS bits: 9 branch_fault (U85 only), 5 cmd_end_reached, 4 cmd_parse_error,
# 1 irq_raised, [31:16] IRQ history.
# IRQ history 0xFFFF, CMD_END_REACHED, IRQ_RAISED.
${NPU_STATUS_DONE}                  0xFFFF0022
${STATUS_END_IRQ}                   0x00000022
${STATUS_BRANCH_FAULT}              0x00000202

# Per-model values. The U55 TRM doesn't say that a parse error raises the IRQ
# (the U85 TRM does), so the U55 expects only cmd_parse_error.
&{U55}                              platform=ARM_Ethos.ARM_EthosU55  id=0x10104201  product=0  status_parse_error=0x00000010
&{U85}                              platform=ARM_Ethos.ARM_EthosU85  id=0x20007001  product=2  status_parse_error=0x00000012

*** Keywords ***
Create NPU Machine
    [Arguments]                     ${npu}
    ${cfg}=                         Set Variable  ${${npu}}
    Reset Emulation
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString "ram: Memory.MappedMemory @ sysbus 0 { size: 0x10000 }"
    Execute Command                 machine LoadPlatformDescriptionFromString "npu: ${cfg}[platform] @ sysbus ${NPU_BASE} { macsPerCycle: 256 }"
    RETURN                          ${cfg}

Write Stream
    [Arguments]                     @{words}
    FOR  ${index}  ${word}  IN ENUMERATE  @{words}
        Execute Command                 sysbus WriteDoubleWord ${{ ${STREAM} + 4 * ${index} }} ${word}
    END

Start Command Stream
    [Arguments]                     ${size}  ${base}=${STREAM}
    Execute Command                 sysbus WriteDoubleWord ${QBASE} ${base}
    Execute Command                 sysbus WriteDoubleWord ${QSIZE} ${size}
    Execute Command                 sysbus WriteDoubleWord ${CMD} ${CMD_RUN}

Register Should Be
    [Arguments]                     ${address}  ${expected}
    ${value}=                       Execute Command  sysbus ReadDoubleWord ${address}
    Should Be Equal As Integers     ${value}  ${expected}

# Checks shared by both models

NPU Should Identify Itself
    [Arguments]                     ${npu}
    ${cfg}=                         Create NPU Machine  ${npu}
    Register Should Be              ${ID}  ${cfg}[id]
    ${config}=                      Execute Command  sysbus ReadDoubleWord ${CONFIG}
    ${config}=                      Convert To Integer  ${config}
    Should Be Equal As Integers     ${{ $config >> 28 }}  ${cfg}[product]  # CONFIG.product
    Should Be Equal As Integers     ${{ $config & 0xF }}  8  # log2(256 MACs/cc)

Stop-Only Stream Should Complete
    [Arguments]                     ${npu}
    Create NPU Machine              ${npu}
    Write Stream                    0xFFFF0000  # NPU_OP_STOP, mask 0xFFFF
    Start Command Stream            4
    Register Should Be              ${STATUS}  ${NPU_STATUS_DONE}

IRQ Command Should Not Stop The Stream
    [Arguments]                     ${npu}
    Create NPU Machine              ${npu}
    Write Stream                    0x00040001  0x00010000  # OP_IRQ mask 0x4, STOP mask 0x1
    Start Command Stream            8
    Register Should Be              ${STATUS}  0x00050022  # both masks, STOP was the last command

Misaligned QBASE Should Be A Parse Error
    [Arguments]                     ${npu}
    ${cfg}=                         Create NPU Machine  ${npu}
    Write Stream                    0x00010000
    Start Command Stream            4  base=0x1002
    Register Should Be              ${STATUS}  ${cfg}[status_parse_error]

Parse Error Should Block Submissions Until Reset
    [Arguments]                     ${npu}
    ${cfg}=                         Create NPU Machine  ${npu}
    Write Stream                    0x00010000
    Start Command Stream            4  base=0x1002
    Start Command Stream            4  # aligned now, but still ignored
    Register Should Be              ${STATUS}  ${cfg}[status_parse_error]
    Execute Command                 sysbus WriteDoubleWord ${RESET} 0
    Register Should Be              ${STATUS}  0
    Start Command Stream            4
    Register Should Be              ${STATUS}  0x00010022

Invalid Command Encoding Should Be A Parse Error
    [Arguments]                     ${npu}
    ${cfg}=                         Create NPU Machine  ${npu}
    Write Stream                    0x00008000  # bits 15:10 = 0b100000 (reserved)
    Start Command Stream            4
    Register Should Be              ${STATUS}  ${cfg}[status_parse_error]
    Register Should Be              ${QREAD}  0

Truncated CMD1 Should Be A Parse Error
    [Arguments]                     ${npu}
    ${cfg}=                         Create NPU Machine  ${npu}
    Write Stream                    0x00004000  # SET_IFM_BASE0 header without its payload
    Start Command Stream            4
    Register Should Be              ${STATUS}  ${cfg}[status_parse_error]

Soft Reset Should Apply The Pending Protection Level
    [Arguments]                     ${npu}
    Create NPU Machine              ${npu}
    Execute Command                 sysbus WriteDoubleWord ${RESET} 0x3  # pending_CSL = Non-secure, pending_CPL = Privileged
    Register Should Be              ${PROT}  0x3
    Register Should Be              ${RESET}  0x3

# U85-only checks: the U55 TRM doesn't define these behaviours

Empty Stream Should End Immediately
    [Arguments]                     ${npu}
    Create NPU Machine              ${npu}
    Start Command Stream            0
    Register Should Be              ${STATUS}  ${STATUS_END_IRQ}
    Register Should Be              ${QREAD}  0

Stop In The Middle Should Not Reach The End
    [Arguments]                     ${npu}
    Create NPU Machine              ${npu}
    Write Stream                    0x00010000  0x00020000  # STOP mask 0x1, STOP mask 0x2
    Start Command Stream            8
    Register Should Be              ${STATUS}  0x00010002  # history 0x1, IRQ, end not reached
    Register Should Be              ${QREAD}  4  # points after the first STOP

Run After Stop Should Resume At QREAD
    [Arguments]                     ${npu}
    Create NPU Machine              ${npu}
    Write Stream                    0x00010000  0x00020000
    Start Command Stream            8
    Execute Command                 sysbus WriteDoubleWord ${CMD} ${CMD_CLEAR_IRQ}
    Execute Command                 sysbus WriteDoubleWord ${CMD} ${CMD_RUN}
    Register Should Be              ${STATUS}  0x00030022  # second STOP ran and was the last command
    Register Should Be              ${QREAD}  8

Writing QSIZE Should Restart From QBASE
    [Arguments]                     ${npu}
    Create NPU Machine              ${npu}
    Write Stream                    0x00010000  0x00020000
    Start Command Stream            8
    Execute Command                 sysbus WriteDoubleWord ${CMD} ${CMD_CLEAR_IRQ}
    Execute Command                 sysbus WriteDoubleWord ${QSIZE} 8
    Execute Command                 sysbus WriteDoubleWord ${CMD} ${CMD_RUN}
    Register Should Be              ${STATUS}  0x00010002  # the first STOP ran again
    Register Should Be              ${QREAD}  4

# U85-only branch checks: the U55 has no NPU_OP_BRANCH or COND_STATUS

Unconditional Branch Should Be Taken
    [Arguments]                     ${npu}
    Create NPU Machine              ${npu}
    Write Stream                    0x00004100  0x0000000C  0x00010000  0x00020000  # BRANCH always to 0xC, STOP 0x1, STOP 0x2
    Start Command Stream            16
    Register Should Be              ${STATUS}  0x00020022  # skipped the first STOP
    Register Should Be              ${QREAD}  16

Conditional Branch Should Fall Through While Result Flag Is Clear
    [Arguments]                     ${npu}
    Create NPU Machine              ${npu}
    Register Should Be              ${COND_STATUS}  0  # result_flag resets to 0
    Write Stream                    0x00014100  0x0000000C  0x00010000  0x00020000  # BRANCH if result_flag to 0xC
    Start Command Stream            16
    Register Should Be              ${STATUS}  0x00010002  # fell through to the first STOP
    Register Should Be              ${QREAD}  12

Branch Outside QSIZE Should Be A Branch Fault
    [Arguments]                     ${npu}
    Create NPU Machine              ${npu}
    Write Stream                    0x00004100  0x00000020  0x00010000  0x00020000  # target 0x20 is not below QSIZE
    Start Command Stream            16
    Register Should Be              ${STATUS}  ${STATUS_BRANCH_FAULT}

*** Test Cases ***
NPU Identifies Itself
    [Template]                      NPU Should Identify Itself
    U55
    U85

Stop-Only Command Stream Completes
    [Template]                      Stop-Only Stream Should Complete
    U55
    U85

IRQ Command Does Not Stop The Stream
    [Template]                      IRQ Command Should Not Stop The Stream
    U55
    U85

Misaligned QBASE Is A Parse Error
    [Template]                      Misaligned QBASE Should Be A Parse Error
    U55
    U85

Parse Error Blocks Submissions Until Reset
    [Template]                      Parse Error Should Block Submissions Until Reset
    U55
    U85

Invalid Command Encoding Is A Parse Error
    [Template]                      Invalid Command Encoding Should Be A Parse Error
    U55
    U85

Truncated CMD1 Is A Parse Error
    [Template]                      Truncated CMD1 Should Be A Parse Error
    U55
    U85

Soft Reset Applies The Pending Protection Level
    [Template]                      Soft Reset Should Apply The Pending Protection Level
    U55
    U85

Empty Command Stream Ends Immediately
    # U85 TRM 3.5.2: running out of commands is a normal stop. The U55 TRM leaves it open.
    [Template]                      Empty Stream Should End Immediately
    U85

Stop In The Middle Does Not Reach The End
    # U85 defines cmd_end_reached as QREAD == QSIZE, and QREAD after a STOP.
    [Template]                      Stop In The Middle Should Not Reach The End
    U85

Run After Stop Resumes At QREAD
    # U85 TRM 3.3.1.3 only: the U55 TRM doesn't describe resuming.
    [Template]                      Run After Stop Should Resume At QREAD
    U85

Writing QSIZE Restarts From QBASE
    # U85 TRM 3.3.1.3 only.
    [Template]                      Writing QSIZE Should Restart From QBASE
    U85

Unconditional Branch Is Taken
    # NPU_OP_BRANCH exists on the U85 only.
    [Template]                      Unconditional Branch Should Be Taken
    U85

Conditional Branch Falls Through While Result Flag Is Clear
    # Nothing in the model sets COND_STATUS.result_flag yet, so it keeps its reset value
    # of 0 and a conditional branch is never taken. This only checks the not-taken path.
    [Template]                      Conditional Branch Should Fall Through While Result Flag Is Clear
    U85

Branch Outside QSIZE Is A Branch Fault
    [Template]                      Branch Outside QSIZE Should Be A Branch Fault
    U85
