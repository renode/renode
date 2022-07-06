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
    Provides                   first_test_pass

Frame Buffer with ROI Test
    [Tags]                     non_critical

    Requires                   first_test_pass
    Execute Command            fb_tester WaitForFrameROI @https://dl.antmicro.com/projects/renode/penguin_logo.png-s_14782-2e0fc81dbcd56b3ed9c86790fe8d390a935395c5 0 0 75 80
