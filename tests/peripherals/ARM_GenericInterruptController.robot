*** Variables ***
${UART}                             sysbus.uart0
${PROMPT}                           \#${SPACE}
${URL}                              https://dl.antmicro.com/projects/renode
${TEST_TEXT}                        Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.

${MULTICORE_ZYNQ_7000}=     SEPARATOR=
...  """                                                        ${\n}
...  using "platforms/cpus/zynq-7000.repl"                      ${\n}
...                                                             ${\n}
...  cpu1: CPU.ARMv7A @ sysbus                                  ${\n}
...  ${SPACE*4}cpuType: "cortex-a9"                             ${\n}
...  ${SPACE*4}genericInterruptController: gic                  ${\n}
...  ${SPACE*4}cpuId: 1                                         ${\n}
...                                                             ${\n}
...  privateTimer1: Timers.ARM_PrivateTimer @ {                 ${\n}
...  ${SPACE*4}${SPACE*4}sysbus new Bus.BusPointRegistration {  ${\n}
...  ${SPACE*4}${SPACE*4}${SPACE*4}address: 0xF8F00600;         ${\n}
...  ${SPACE*4}${SPACE*4}${SPACE*4}cpu: cpu1                    ${\n}
...  ${SPACE*4}${SPACE*4}}                                      ${\n}
...  ${SPACE*4}}                                                ${\n}
...  ${SPACE*4}-> gic#1@29                                      ${\n}
...  ${SPACE*4}frequency: 667000000                             ${\n}
...                                                             ${\n}
...  gic:                                                       ${\n}
...  ${SPACE*4}\[4-5\] -> cpu1@\[0-1\]                          ${\n}
...                                                             ${\n}
...  slcr:                                                      ${\n}
...  ${SPACE*4}cpu1: cpu1                                       ${\n}
...  """

*** Keywords ***
Create Machine
    Execute Command                 using sysbus
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescriptionFromString ${MULTICORE_ZYNQ_7000}
    Execute Command                 sysbus Redirect 0xC0000000 0x0 0x10000000

    # Set timer frequency
    Execute Command                 ttc0 Frequency 33333333
    Execute Command                 ttc1 Frequency 33333333

    # Setup CPUs
    Execute Command                 cpu SetRegister 0 0x000
    Execute Command                 cpu SetRegister 1 0xD32 # processor variant (cortex-a9)
    Execute Command                 cpu SetRegister 2 0x100 # device tree address
    Execute Command                 cpu1 IsHalted true

    Execute Command                 sysbus LoadELF @${URL}/zynq-interface-tests-vmlinux-s_14142952-ab5cd7445f31414fcbf8c79d49d737c669034ef2
    Execute Command                 sysbus LoadFdt @${URL}/zynq-interface-tests.dtb-s_11724-984776b955e46b2d8f4426552a4c1ae91d063e4b 0x100 "console=ttyPS0,115200 root=/dev/ram0 rw initrd=0x1a000000,16M" false
    Execute Command                 sysbus ZeroRange 0x1a000000 0x800000
    Execute Command                 sysbus LoadBinary @${URL}/zynq--interface-tests-rootfs.ext2-s_16777216-191638e3b3832a81bebd21d555f67bf3a4d7882a 0x1a000000

*** Test Cases ***
Should Force Interrupt Only To Lowest Id CPU
    Execute Command                 emulation SetGlobalSerialExecution true
    Execute Command                 emulation SetAdvanceImmediately true
    Execute Command                 logLevel 3
    Create Machine
    Create Terminal Tester          ${UART}  defaultPauseEmulation=True

    # boot linux
    Wait For Line On Uart           Booting Linux on physical CPU 0x0
    Wait For Prompt On Uart         buildroot login:  timeout=25
    Write Line To Uart              root
    Wait For Prompt On Uart         ${PROMPT}

    # enable UART interrupt (0x3B) to target core 0 and 1
    Execute Command                 sysbus WriteDoubleWord 0xF8F01838 0x03010101 cpu

    Create Log Tester               1
    Execute Command                 logLevel -1 gic

    Write Line To Uart              echo ${TEST_TEXT}  waitForEcho=False
    Write Line To Uart              echo ${TEST_TEXT}  waitForEcho=False
    # # confirm cpu1 can handle UART's IRQ - 59 (SPI 27)
    Wait For Log Entry              gic: cpu1.0.0.0 reads from 0xC (InterruptAcknowledge) register of memory-mapped CPU Interface, returned 0x3B.  keep=True  pauseEmulation=True
    # # confirm cpu0 can handle UART's IRQ
    Wait For Log Entry              gic: cpu0.0.0.0 reads from 0xC (InterruptAcknowledge) register of memory-mapped CPU Interface, returned 0x3B.  keep=True  pauseEmulation=True

    Execute Command                 gic ForceLowestIdCpuAsInterruptTarget true

    # create new tester to clear log history
    Create Log Tester               1
    Execute Command                 logLevel -1 gic
    # confirm cpu1 cannot handle UART's IRQ
    Write Line To Uart              echo ${TEST_TEXT}  waitForEcho=False
    Should Not Be In Log            gic: cpu1.0.0.0 reads from 0xC (InterruptAcknowledge) register of memory-mapped CPU Interface, returned 0x3B.
    Wait For Log Entry              gic: cpu0.0.0.0 reads from 0xC (InterruptAcknowledge) register of memory-mapped CPU Interface, returned 0x3B.
