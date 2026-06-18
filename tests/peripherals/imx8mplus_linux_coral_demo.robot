*** Variables ***
@{COPY_PROGRAM_SH}
...   # Read file as hex bytes
...   # The memory needs to initially be all zero
...   od -An -v -t x8 "$FILE" | tr -s ' ' '\\n' | while read -r byte; do
...       ${SPACE}\[ -z "$byte" ] && continue
...       ${SPACE}val=$((0x$byte))
...       ${SPACE}if [ "$val" = "0" ] ; then
...       ${SPACE}${SPACE}ADDR=$(printf "0x%X" $((ADDR + 8)))
...       ${SPACE}${SPACE}continue
...       ${SPACE}fi
...       # write using devmem: devmem <phys_addr> <width> <value>
...       ${SPACE}devmem "$ADDR" 64 "$val"
...       ${SPACE}echo $ADDR writing "$val"
...       # increment address by 8 bytes
...       ${SPACE}ADDR=$(printf "0x%X" $((ADDR + 8)))
...   done

*** Keywords ***
Ensure Device In Reset
    # Follow initialization procedures as described in:
    # https://github.com/google-coral/coralnpu/blob/main/doc/integration_guide.md#booting-coralnpu

    # Write to physical memory
    Write Line To Uart              devmem 0xE00030000
    # Ensure that the device is in reset, and has gated its clock
    Wait For Line On Uart           0x00000003

Release Clock Gate And Reset
    # Release Clock Gate
    Write Line To Uart              devmem 0xE00030000 w 0x1
    Write Line To Uart              devmem 0xE00030000
    Wait For Line On Uart           0x00000001

    # Release Reset
    Write Line To Uart              devmem 0xE00030000 w 0x0
    Write Line To Uart              devmem 0xE00030000
    Wait For Line On Uart           0x00000000

Check If NPU Finished
    Write Line To Uart              devmem 0xE00030008
    Wait For Line On Uart           0x00000001

*** Test Cases ***
Should Boot Linux
    [Timeout]                       NONE
    Execute Command                 include @scripts/complex/coral_npu/imx8mplus_linux_coral.resc
    Create Terminal Tester          sysbus.uart2  timeout=120

    Wait For Line On Uart           ==== Hello World! Linux i.MX 8M Plus ====
    Wait For Prompt On Uart         \#${SPACE}
    Write Line To Uart              uname -a
    Wait For Line On Uart           Linux

    Provides                        booted_linux

Should Launch Sample Coral App
    Requires                        booted_linux
    Ensure Device In Reset

    # Copy the binary to NPU's Instruction Memory
    Execute Command                 npu LoadBinary @https://dl.antmicro.com/projects/renode/coralnpu_v2_hello_world_add_floats.bin-s_65648-0e3f5d6ae173fa2e06f6b5f91906ef721516de4c 0

    # Initialize input data in Data Memory
    Write Line To Uart              devmem 0xE00010000 w 2
    Write Line To Uart              devmem 0xE00010000
    Wait For Line On Uart           0x00000002

    Write Line To Uart              devmem 0xE00010020 w 5
    Write Line To Uart              devmem 0xE00010020
    Wait For Line On Uart           0x00000005

    Release Clock Gate And Reset

    # Check that we finished the program
    Wait Until Keyword Succeeds     30s  1s  Check If NPU Finished

    # Check the result (this is an addition A + B)
    Write Line To Uart              devmem 0xE00010040
    Wait For Line On Uart           0x00000007

Should Launch Sample Coral App But Copy From Ramdisk
    Requires                        booted_linux
    Ensure Device In Reset

    Execute Command                 showAnalyzer uart2

    # Copy the binary to NPU's Instruction Memory
    Write Line To Uart              export FILE=coralnpu_v2_hello_world_add_floats.bin
    Write Line To Uart              export ADDR=0xE00000000
    FOR  ${line}  IN  @{COPY_PROGRAM_SH}
        Write Line To Uart          ${line}
    END

    # Initialize input data in Data Memory
    Write Line To Uart              devmem 0xE00010000 w 2
    Write Line To Uart              devmem 0xE00010000
    Wait For Line On Uart           0x00000002

    Write Line To Uart              devmem 0xE00010020 w 5
    Write Line To Uart              devmem 0xE00010020
    Wait For Line On Uart           0x00000005

    Release Clock Gate And Reset

    # Check that we finished the program
    Wait Until Keyword Succeeds     30s  1s  Check If NPU Finished

    # Check the result (this is an addition A + B)
    Write Line To Uart              devmem 0xE00010040
    Wait For Line On Uart           0x00000007

Should Launch Sample Coral App With Intrinsic Ops
    Requires                        booted_linux
    Ensure Device In Reset

    # Copy the binary to NPU's Instruction Memory
    Execute Command                 npu LoadBinary @https://dl.antmicro.com/projects/renode/coralnpu_v2_rvv_add_intrinsic.bin-s_67600-f938affcbbf6bef5f4eb64c57a026103dee1a3ac 0

    Release Clock Gate And Reset

    # Check that we finished the program
    Wait Until Keyword Succeeds     30s  1s  Check If NPU Finished

    # Check the result (all the memory space is filled with 0x0007, per each 16 bit element written)
    Write Line To Uart              devmem 0xE00010040
    Wait For Line On Uart           0x00070007
