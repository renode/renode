*** Settings ***
Suite Setup                                     Setup
Suite Teardown                                  Teardown
Test Setup                                      Reset Emulation
Test Teardown                                   Test Teardown
Resource                                        ${RENODEKEYWORDS}

*** Variables ***
${FILE}              /tmp/execution.trace

*** Keywords ***
Create Machine
    Execute Command                             using sysbus
    Execute Command                             include @scripts/single-node/versatile.resc
    Execute Command                             cpu ExecutionMode SingleStepBlocking

*** Test Cases ***
Should Dump PCs
    Create Machine

    Execute Command                             cpu EnableExecutionTracing @${FILE} PC
    Start Emulation
    Execute Command                             cpu Step 16

    # wait for the file to populate
    Sleep  3s

    ${content}=  Get File  ${FILE}
    @{pcs}=  Split To Lines  ${content}

    Length Should Be                            ${pcs}  16
    Should Be Equal                             ${pcs[0]}  0x8000
    Should Be Equal                             ${pcs[1]}  0x8004
    Should Be Equal                             ${pcs[2]}  0x8008
    Should Be Equal                             ${pcs[3]}  0x359C08
    Should Be Equal                             ${pcs[14]}  0x8010
    Should Be Equal                             ${pcs[15]}  0x8014

Should Dump Opcodes
    Create Machine

    Execute Command                             cpu EnableExecutionTracing @${FILE} Opcode
    Start Emulation
    Execute Command                             cpu Step 16

    # wait for the file to populate
    Sleep  3s

    ${content}=  Get File  ${FILE}
    @{pcs}=  Split To Lines  ${content}

    Length Should Be                            ${pcs}  16
    Should Be Equal                             ${pcs[0]}  0xE321F0D3
    Should Be Equal                             ${pcs[1]}  0xEE109F10
    Should Be Equal                             ${pcs[2]}  0xEB0D46FE
    Should Be Equal                             ${pcs[3]}  0xE28F3030
    Should Be Equal                             ${pcs[14]}  0x0A0D470D
    Should Be Equal                             ${pcs[15]}  0xE28F302C
