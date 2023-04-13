*** Test Cases ***
Should Respect PullUp Configuration
    # this is necessary to handle buttons on a paused simulation
    Execute Command             emulation Mode SynchronizedTimers
    Execute Command             include @scripts/single-node/nrf52840.resc

    # read IN, by default it should return 0
    ${x}=  Execute Command      gpio0 ReadDoubleWord 0x10
    Should Be Equal As Numbers  ${x}   0x0

    # setting pin#5 as pull-up
    Execute Command             gpio0 WriteDoubleWord 0x214 0xC

    # read IN, now expecting pull-up for pin#5
    ${x}=  Execute Command      gpio0 ReadDoubleWord 0x10
    Should Be Equal As Numbers  ${x}   0x20

    # attaching a button, now pull-up should not matter anymore
    Execute Command             machine LoadPlatformDescriptionFromString "button: Miscellaneous.Button @ gpio0 5 { -> gpio0@5 }"

    # read IN, now expect to read the button state - false
    ${x}=  Execute Command      gpio0 ReadDoubleWord 0x10
    Should Be Equal As Numbers  ${x}   0x0

    # press the button
    Execute Command             gpio0.button Press

    # read IN, expect to read the button state - true
    ${x}=  Execute Command      gpio0 ReadDoubleWord 0x10
    Should Be Equal As Numbers  ${x}   0x20

    # release the button
    Execute Command             gpio0.button Release

    # read IN, now expect to read the button state - false
    ${x}=  Execute Command      gpio0 ReadDoubleWord 0x10
    Should Be Equal As Numbers  ${x}   0x0
