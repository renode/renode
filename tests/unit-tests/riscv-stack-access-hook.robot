*** Variables ***
${initial_pc}                 0x1000
${initial_sp}                 0x3000

*** Keywords ***

Create Machine
    Execute Command           using sysbus
    Execute Command           mach create "risc-v"

    Execute Command           machine LoadPlatformDescriptionFromString "clint: IRQControllers.CoreLevelInterruptor @ sysbus 0x44000000 { frequency: 66000000 }"
    Execute Command           machine LoadPlatformDescriptionFromString "cpu: CPU.RiscV64 @ sysbus { timeProvider: clint; cpuType: \\"rv64gc_V\\" }"
    Execute Command           machine LoadPlatformDescriptionFromString "mem: Memory.MappedMemory @ sysbus 0x1000 { size: 0x40000 }"

    Execute Command           cpu PC ${initial_pc}
    Execute Command           cpu SP ${initial_sp}

    Execute Command           cpu AddPreStackAccessHook 'cpu.Log(LogLevel.Info, "StackAccess: 0x{0:X}, {1}, {2}", address, width, is_write)'
    Create Log Tester         0

Read Hook Should Have Fired At
    [Arguments]               ${address}  ${width}
    ${address}=               Convert To Hex  ${address}  prefix=0x
    Wait For Log Entry        cpu: StackAccess: ${address}, ${width}, False

Write Hook Should Have Fired At
    [Arguments]               ${address}  ${width}
    ${address}=               Convert To Hex  ${address}  prefix=0x
    Wait For Log Entry        cpu: StackAccess: ${address}, ${width}, True

Execute Instruction
    [Arguments]               ${instruction}
    Execute Command           cpu AssembleBlock ${initial_pc} "${instruction}"
    Execute Command           cpu Step


*** Test Cases ***

Should Trigger Stack Access Hook On Lb
    Create Machine
    Execute Instruction                 lb a0, 0(sp)
    Read Hook Should Have Fired At      ${initial_sp}  8

Should Trigger Stack Access Hook At Correct Offset
    Create Machine
    Execute Instruction                 lb a0, 64(sp)
    Read Hook Should Have Fired At      ${${initial_sp} + 64}  8

Should Trigger Stack Access Hook On Lh
    Create Machine
    Execute Instruction                 lh a0, 0(sp)
    Read Hook Should Have Fired At      ${initial_sp}  16

Should Trigger Stack Access Hook On Lw
    Create Machine
    Execute Instruction                 lw a0, 0(sp)
    Read Hook Should Have Fired At      ${initial_sp}  32

Should Trigger Stack Access Hook On Ld
    Create Machine
    Execute Instruction                 ld a0, 0(sp)
    Read Hook Should Have Fired At      ${initial_sp}  64

Should Trigger Stack Access Hook On Sb
    Create Machine
    Execute Instruction                 sb a0, 0(sp)
    Write Hook Should Have Fired At     ${initial_sp}  8

Should Trigger Stack Access Hook On Sh
    Create Machine
    Execute Instruction                 sh a0, 0(sp)
    Write Hook Should Have Fired At     ${initial_sp}  16

Should Trigger Stack Access Hook On Sw
    Create Machine
    Execute Instruction                 sw a0, 0(sp)
    Write Hook Should Have Fired At     ${initial_sp}  32

Should Trigger Stack Access Hook On Sd
    Create Machine
    Execute Instruction                 sd a0, 0(sp)
    Write Hook Should Have Fired At     ${initial_sp}  64

Should Trigger Stack Access Hook On Lr
    Create Machine
    Execute Instruction                 lr.w a0, 0(sp)
    Read Hook Should Have Fired At      ${initial_sp}  32

Should Trigger Stack Access Hook On Sc
    Create Machine
    Execute Instruction                 sc.w a1, a0, 0(sp)
    Write Hook Should Have Fired At     ${initial_sp}  32

Should Trigger Stack Access Hook On Fld
    Create Machine
    Execute Instruction                 fld f0, 0(sp)
    Read Hook Should Have Fired At      ${initial_sp}  64

Should Trigger Stack Access Hook On Fsd
    Create Machine
    Execute Instruction                 fsd f0, 0(sp)
    Write Hook Should Have Fired At     ${initial_sp}  64

# Unit strided
Should Trigger Stack Access Hook On Vle8
    Create Machine
    Execute Command                     cpu AssembleBlock ${initial_pc} "vsetivli t0, 8, e8,m1,ta,ma; vle8.v v0, 0(sp)"
    Execute Command                     cpu Step 2
    FOR  ${counter}  IN RANGE  0  7
        Read Hook Should Have Fired At      ${${initial_sp}+${counter}}  8
    END

Should Trigger Stack Access Hook On Vle64
    Create Machine
    Execute Command                     cpu AssembleBlock ${initial_pc} "vsetivli t0, 8, e64,m1,ta,ma; vle64.v v0, 0(sp)"
    Execute Command                     cpu Step 2
    FOR  ${counter}  IN RANGE  0  7
        Read Hook Should Have Fired At      ${${initial_sp}+(${counter}*8)}  64
    END

Should Trigger Stack Access Hook On Vse8
    Create Machine
    Execute Command                     cpu AssembleBlock ${initial_pc} "vsetivli t0, 8, e8,m1,ta,ma; vse8.v v0, 0(sp)"
    Execute Command                     cpu Step 2
    FOR  ${counter}  IN RANGE  0  7
        Write Hook Should Have Fired At      ${${initial_sp}+${counter}}  8
    END

Should Trigger Stack Access Hook On Vse64
    Create Machine
    Execute Command                     cpu AssembleBlock ${initial_pc} "vsetivli t0, 8, e64,m1,ta,ma; vse64.v v0, 0(sp)"
    Execute Command                     cpu Step 2
    FOR  ${counter}  IN RANGE  0  7
        Write Hook Should Have Fired At      ${${initial_sp}+${counter}*8}  64
    END

# strided
Should Trigger Stack Access Hook On Vlse8
    Create Machine
    Execute Command                     cpu AssembleBlock ${initial_pc} "vsetivli t0, 8, e8,m1,ta,ma; li a0, 16; vlse8.v v0, 0(sp), a0"
    Execute Command                     cpu Step 3
    FOR  ${counter}  IN RANGE  0  7
        Read Hook Should Have Fired At      ${${initial_sp}+${counter}*16}  8
    END

Should Trigger Stack Access Hook On Vlse64
    Create Machine
    Execute Command                     cpu AssembleBlock ${initial_pc} "vsetivli t0, 8, e64,m1,ta,ma; li a0, 128; vlse64.v v0, 0(sp), a0"
    Execute Command                     cpu Step 3
    FOR  ${counter}  IN RANGE  0  7
        Read Hook Should Have Fired At      ${${initial_sp}+${counter}*128}  64
    END

Should Trigger Stack Access Hook On Vsse8
    Create Machine
    Execute Command                     cpu AssembleBlock ${initial_pc} "vsetivli t0, 8, e8,m1,ta,ma; li a0, 16; vsse8.v v0, 0(sp), a0"
    Execute Command                     cpu Step 3
    FOR  ${counter}  IN RANGE  0  7
        Write Hook Should Have Fired At      ${${initial_sp}+${counter}*16}  8
    END

Should Trigger Stack Access Hook On Vsse64
    Create Machine
    Execute Command                     cpu AssembleBlock ${initial_pc} "vsetivli t0, 8, e64,m1,ta,ma; li a0, 128; vsse64.v v0, 0(sp), a0"
    Execute Command                     cpu Step 3
    FOR  ${counter}  IN RANGE  0  7
        Write Hook Should Have Fired At      ${${initial_sp}+${counter}*128}  64
    END
