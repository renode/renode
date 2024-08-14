*** Variables ***
${UART0}                            sysbus.uart0

${DTC_ADDR}                         0xfe00000

${URL_BASE}                         @https://dl.antmicro.com/projects/renode
${XEN_DTC}                          ${URL_BASE}/xen_zephyr_cortex-r52.dtc-s_1961-4e8eefe98742e2860ca28cf82e75ae8d8c6c2a5d
${XEN_BIN}                          ${URL_BASE}/xen_cortex-r52.bin-s_950280-5abcd07806d4f8d33b370020342470c15bf499b5
${ZEPHYR_PHILOSOPHERS}              ${URL_BASE}/zephyr_philosophers_xen_cortex-r52.bin-s_42884-05ca319e43ca33a124c51f84319229815acc654f
${ZEPHYR_HELLO_WORLD}               ${URL_BASE}/zephyr_hello_world_xen_cortex-r52.bin-s_26052-d55e84265d9a51fe5522abc959ce7f31b68510a6

*** Keywords ***
Create Machine
    [Arguments]                     @{}  ${zephyr_bin}

    ${python_script}=               Catenate  SEPARATOR=\n
    ...                             python
    ...                             """
    ...                             from System.Runtime.CompilerServices import RuntimeHelpers
    ...                             from Antmicro.Renode.Peripherals.CPU import RegisterValue
    ...                             ZEPHYR_IMAGE_BASE = 0xd00080
    ...                             ZEPHYR_BASE = 0xb00000
    ...                             def mc_load_zephyr(zephyr_bin):
    ...                             ${SPACE*4}sysbus = self.Machine["sysbus"]
    ...                             ${SPACE*4}image_len = System.IO.FileInfo(zephyr_bin).Length
    ...                             ${SPACE*4}sysbus.LoadBinary(zephyr_bin, ZEPHYR_BASE)
    ...                             ${SPACE*4}# Patch the Zephyr header
    ...                             ${SPACE*4}sysbus.WriteDoubleWord(ZEPHYR_BASE + 0x2c, ZEPHYR_IMAGE_BASE + image_len)
    ...                             """

    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription @platforms/cpus/cortex-r52.repl
    Execute Command                 ${python_script}

    Execute Command                 sysbus LoadBinary ${XEN_BIN} 0x0
    Execute Command                 sysbus LoadBinary ${XEN_DTC} ${DTC_ADDR}

    Execute Command                 load_zephyr ${zephyr_bin}
    Execute Command                 sysbus.cpu SetRegister 102 ${DTC_ADDR}
    Create Terminal Tester          ${UART0}  defaultPauseEmulation=True

*** Test Cases ***
Run Zephyr Hello World Sample
    [Tags]                          Demos

    Create Machine                  zephyr_bin=${ZEPHYR_HELLO_WORLD}

    Wait For Line On Uart           (XEN) DOM1: *** Booting Zephyr OS build  includeUnfinishedLine=True
    Wait For Line On Uart           (XEN) DOM1: Hello World! fvp_baser_aemv8r_aarch32

Run Zephyr Philosophers Sample
    [Tags]                          Demos

    Create Machine                  zephyr_bin=${ZEPHYR_PHILOSOPHERS}

    Wait For Line On Uart           (XEN) Xen dom0less mode detected

    Wait For Line On Uart           Philosopher 0.*THINKING  treatAsRegex=true
    Wait For Line On Uart           Philosopher 0.*HOLDING  treatAsRegex=true
    Wait For Line On Uart           Philosopher 0.*EATING  treatAsRegex=true
    Wait For Line On Uart           Philosopher 1.*THINKING  treatAsRegex=true
    Wait For Line On Uart           Philosopher 1.*HOLDING  treatAsRegex=true
    Wait For Line On Uart           Philosopher 1.*EATING  treatAsRegex=true
    Wait For Line On Uart           Philosopher 2.*THINKING  treatAsRegex=true
    Wait For Line On Uart           Philosopher 2.*HOLDING  treatAsRegex=true
    Wait For Line On Uart           Philosopher 2.*EATING  treatAsRegex=true
    Wait For Line On Uart           Philosopher 3.*THINKING  treatAsRegex=true
    Wait For Line On Uart           Philosopher 3.*HOLDING  treatAsRegex=true
    Wait For Line On Uart           Philosopher 3.*EATING  treatAsRegex=true
    Wait For Line On Uart           Philosopher 4.*THINKING  treatAsRegex=true
    Wait For Line On Uart           Philosopher 4.*HOLDING  treatAsRegex=true
    Wait For Line On Uart           Philosopher 4.*EATING  treatAsRegex=true
    Wait For Line On Uart           Philosopher 5.*THINKING  treatAsRegex=true
    Wait For Line On Uart           Philosopher 5.*HOLDING  treatAsRegex=true
    Wait For Line On Uart           Philosopher 5.*EATING  treatAsRegex=true
