*** Settings ***
Suite Setup                    Setup
Suite Teardown                 Teardown
Test Setup                     Reset Emulation
Test Teardown                  Test Teardown
Resource                       ${RENODEKEYWORDS}

*** Test Cases ***
Frame Buffer Test
    [Tags]                     non_critical

    Execute Script             scripts/single-node/litex_nexys_video_vexriscv_linux.resc

    Create Terminal Tester     sysbus.uart

    Start Emulation

    Wait For Line On Uart      Press Q or ESC to abort boot completely.
    Send Key To Uart           0x51  # Q

    Wait For Prompt On Uart    litex>
    Write Line To Uart         sdcardboot

    Wait For Prompt On Uart    buildroot login: 
    Write Line To Uart         root

    Wait For Line On Uart      root login on 'console'

    Write Line To Uart         export PS1="$ "
    Wait For Prompt On Uart    $

    Execute Command            emulation CreateFrameBufferTester "fb_tester" 5

    Execute Command            fb_tester AttachTo litex_video

    Write Line To Uart         cat /etc/motd > /dev/tty0
    Execute Command            fb_tester WaitForFrame @https://dl.antmicro.com/projects/renode/screenshots/penguin_with_litex_logo.png-s_13404-8664342616adc3edda335db849dd1f5cd1805596
