*** Test Cases ***
GPIOTE Should Capture Falling Edge When Pin Is Idle-High Before Arming
    # buttons need SynchronizedTimers to take effect on a paused simulation
    Execute Command             emulation Mode SynchronizedTimers
    Execute Command             include @scripts/single-node/nrf52840.resc

    Execute Command             machine LoadPlatformDescriptionFromString "btn: Miscellaneous.Button @ gpio0 11 { -> gpio0@11 }"

    # 1. establish idle-high BEFORE arming - this is the trigger condition
    Execute Command             gpio0.btn Press

    # 2. arm channel 0: Event / HiToLo on gpio0 pin 11 (CONFIG[0] @ 0x40006510)
    Execute Command             gpiote WriteDoubleWord 0x510 0x00020B01

    # 3. the single real high->low transition
    Execute Command             gpio0.btn Release

    # a correctly-behaving model resynchronizes the edge-detection baseline
    # when the channel is armed, so this transition must be observed
    ${e}=  Execute Command      gpiote ReadDoubleWord 0x100
    Should Be Equal As Numbers  ${e}   0x1
