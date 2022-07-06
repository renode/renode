*** Variables ***
${X1}                                           1
${X2}                                           2
${X3}                                           3

*** Keywords ***
Create Machine                                  
    Execute Command                             using sysbus
    Execute Command                             mach create
    Execute Command                             machine LoadPlatformDescriptionFromString "cpu: CPU.RiscV32 @ sysbus { cpuType: \\"rv32imac\\"; timeProvider: empty; allowUnalignedAccesses: true }"
    Execute Command                             machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus 0x0 { size: 0x10000000 }"
  
*** Test Cases ***
Should Invalidate On Write
    Create Machine

    # li x1, 1
    Execute Command                             sysbus WriteDoubleWord 0x0 0x00100093
    # j .
    Execute Command                             sysbus WriteDoubleWord 0x4 0x0000006f

    Execute Command                             cpu PC 0x0
    Register Should Be Equal                    ${X1}  0x0
    Execute Command                             emulation RunFor "0.01"

    PC Should Be Equal                          0x4
    Register Should Be Equal                    ${X1}  0x1

    # this overwrites the `li` instruction
    # chaning the immediate value;
    # if the invalidation works fine, we should
    # observe the new value in the register
    # after running the code for the second time
    
    # li x1, 2
    Execute Command                             sysbus WriteDoubleWord 0x0 0x00200093

    Execute Command                             cpu PC 0x0
    Execute Command                             cpu SetRegisterUnsafe ${X1} 0x0
    Execute Command                             emulation RunFor "0.01"

    PC Should Be Equal                          0x4
    Register Should Be Equal                    ${X1}  0x2

Should Invalidate on Cross Page Word Write
    Create Machine

    # we use this particular PC as it's at the
    # edge of memory segments
    Execute Command                             cpu PC 0xfffffc

    # li x1, 1
    Execute Command                             sysbus WriteDoubleWord 0xfffffc 0x00100093

    # li x2, 1
    Execute Command                             sysbus WriteDoubleWord 0x1000000 0x00100113

    # j .
    Execute Command                             sysbus WriteDoubleWord 0x1000004 0x0000006f

    Execute Command                             cpu PC 0xfffffc
    Register Should Be Equal                    ${X1}  0x0
    Register Should Be Equal                    ${X2}  0x0
    Register Should Be Equal                    ${X3}  0x0
    Execute Command                             emulation RunFor "0.0001"

    PC Should Be Equal                          0x1000004
    Register Should Be Equal                    ${X1}  0x1
    Register Should Be Equal                    ${X2}  0x1
    Register Should Be Equal                    ${X3}  0x0

    # this single write modifies both `li` commands
    # so that the first one writes 0x131 instead of 0x1
    # and the second one writes to X2 instead of X1;
    # if the invalidation works fine, we should
    # observe new values in registers
    # after running the code for the second time
    Execute Command                             sysbus WriteWord 0xffffff 0x9313

    Execute Command                             cpu PC 0xfffffc
    Execute Command                             cpu SetRegisterUnsafe ${X1} 0x0
    Execute Command                             cpu SetRegisterUnsafe ${X2} 0x0
    Execute Command                             cpu SetRegisterUnsafe ${X3} 0x0
    Execute Command                             emulation RunFor "0.0001"

    PC Should Be Equal                          0x1000004
    Register Should Be Equal                    ${X1}  0x131
    Register Should Be Equal                    ${X2}  0x0
    Register Should Be Equal                    ${X3}  0x1

Should Invalidate on Cross Page DoubleWord Write
    Create Machine

    # we use this particular PC as it's at the
    # edge of memory segments
    Execute Command                             cpu PC 0xfffffc

    # li x1, 1
    Execute Command                             sysbus WriteDoubleWord 0xfffffc 0x00100093

    # li x2, 1
    Execute Command                             sysbus WriteDoubleWord 0x1000000 0x00100113

    # j .
    Execute Command                             sysbus WriteDoubleWord 0x1000004 0x0000006f

    Execute Command                             cpu PC 0xfffffc
    Register Should Be Equal                    ${X1}  0x0
    Register Should Be Equal                    ${X2}  0x0
    Register Should Be Equal                    ${X3}  0x0
    Execute Command                             emulation RunFor "0.0001"

    PC Should Be Equal                          0x1000004
    Register Should Be Equal                    ${X1}  0x1
    Register Should Be Equal                    ${X2}  0x1
    Register Should Be Equal                    ${X3}  0x0

    # this single write modifies both `li` commands
    # so that the first one writes 0x131 instead of 0x1
    # and the second one writes to X2 instead of X1;
    # if the invalidation works fine, we should
    # observe new values in registers
    # after running the code for the second time
    Execute Command                             sysbus WriteDoubleWord 0xfffffe 0x01931310

    Execute Command                             cpu PC 0xfffffc
    Execute Command                             cpu SetRegisterUnsafe ${X1} 0x0
    Execute Command                             cpu SetRegisterUnsafe ${X2} 0x0
    Execute Command                             cpu SetRegisterUnsafe ${X3} 0x0
    Execute Command                             emulation RunFor "0.0001"

    PC Should Be Equal                          0x1000004
    Register Should Be Equal                    ${X1}  0x131
    Register Should Be Equal                    ${X2}  0x0
    Register Should Be Equal                    ${X3}  0x1

