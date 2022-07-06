*** Variables ***
${UART}                      sysbus.uart
${MC3635}                    sysbus.ffe.i2cMaster0.mc3635
${URI}                       @https://dl.antmicro.com/projects/renode

*** Keywords ***
Create Machine
    [Arguments]  ${elf}

    Execute Command          mach create
    Execute Command          machine LoadPlatformDescription @platforms/boards/eos-s3-quickfeather.repl

    Execute Command          sysbus LoadELF ${URI}/${elf}

Assert Flag
    [Arguments]              ${register}  ${position}  ${value}
    ${flag}                  Evaluate    str((${register} >> ${position}) & 0x1)
    Should Be Equal          ${flag}   ${value}

Feed Test Data
    [Arguments]              ${peripheral}

    # The test binary sets mode to the continuous sampling on the beggining of configuration,
    # and some samples are fed before we enter the main loop. Hence we start with a few empty ones.
    Execute Command          ${peripheral} FeedAccelerationSample 0.0 0.0 0.0 5

    # One sample short from 0.5s worth of data
    FOR  ${index}  IN RANGE  27
         ${x}=  Evaluate     -1.0 + ${index} * (2/26)        # Linear sweep from -1 to 1 over 27 samples 
         ${y}=  Evaluate     -2.0 + ${index} * (2/26)        # Linear sweep from -2 to 0 over 27 samples 
         ${z}=  Evaluate     2.0 - ${index} * (2/26)         # Linear sweep from +2 to 0 over 27 samples
         Execute Command     ${peripheral} FeedAccelerationSample ${x} ${y} ${z}
    END

*** Test Cases *** 
Should Output Data
    Create Machine            quick_feather--mc3635_ssi_ai_app.elf-s_947900-114d2e13b2ceffb6144135e61d1b3c2a499e35c3
    Create Terminal Tester    ${UART}
    Provides                  Ready Machine

    Start Emulation

    Wait For Line On Uart     X 0,Y 0,Z 0

Should Work With FeedAccelerationSample
    Requires                  Ready Machine
    
    Feed Test Data            ${MC3635}
    Start Emulation
    
    Wait For Line On Uart     X -8191,Y -16383,Z 16383
    Wait For Line On Uart     X 0,Y -8191,Z 8191
    Wait For Line On Uart     X 8191,Y 0,Z 0
    
Should Be Able To Disable Axis
    Requires                  Ready Machine

    Execute Command           ${MC3635} DefaultAccelerationX 1.0
    Execute Command           ${MC3635} DefaultAccelerationY 1.0
    Execute Command           ${MC3635} DefaultAccelerationZ 1.0
    Start Emulation

    Wait For Line On Uart     X 8191,Y 8191,Z 8191
    Execute Command           ${MC3635} RegisterWrite 0x10 0x45 # Mode CWAKE, Z disabled
    Wait For Line On Uart     X 8191,Y 8191,Z 0
    Execute Command           ${MC3635} RegisterWrite 0x10 0x25 # Mode CWAKE, Y disabled
    Wait For Line On Uart     X 8191,Y 0,Z 8191
    Execute Command           ${MC3635} RegisterWrite 0x10 0x15 # Mode CWAKE, X disabled
    Wait For Line On Uart     X 0,Y 8191,Z 8191

Should Log Error If Some Of Reserved Bits Have Wrong Value
    Requires                  Ready Machine
    Create Log Tester         1
    Start Emulation

    Execute Command           ${MC3635} RegisterWrite 0x20 0x00
    Wait For Log Entry        Invalid value written to offset 0x20 reserved bits. Allowed values = 0b0000xx01
    Execute Command           ${MC3635} RegisterWrite 0x21 0x00
    Wait For Log Entry        Invalid value written to offset 0x21 reserved bits. Allowed values = 0b1000xx00
    Execute Command           ${MC3635} RegisterWrite 0x22 0x01
    Wait For Log Entry        Invalid value written to offset 0x22 reserved bits. Allowed values = 0b0000xx00

Should Log Error On Selecting Unimplemented Modes
    Requires                  Ready Machine
    Create Log Tester         1
    Start Emulation

    Execute Command           ${MC3635} RegisterWrite 0x10 0x02 # Mode SNIFF 
    Wait For Log Entry        Sniff mode unimplemented. Switching to Standby
    Execute Command           ${MC3635} RegisterWrite 0x10 0x06 # Mode SWAKE
    Wait For Log Entry        Swake mode unimplemented. Switching to Standby

Should Set Flags
    # This test relies on the configuration of the emulation and the binary itself.
    # Any changes require adjusting the `emulation RunFor` arguments

    ${NEW_DATA_REG}=          Evaluate  0x08
    ${OVR_DATA_REG}=          Evaluate  0x01
    ${NEW_DATA_POSITION}=     Evaluate  3
    ${OVR_DATA_POSITION}=     Evaluate  0

    Requires                  Ready Machine
    
    # Run until the peripheral is set to `continuous sampling` but the configuration is not yet completed and no samples are read 
    Execute Command           emulation RunFor '0.007'
    ${OVR_DATA}=              Execute Command  ${MC3635} RegisterRead ${OVR_DATA_REG}
    ${NEW_DATA}=              Execute Command  ${MC3635} RegisterRead ${NEW_DATA_REG}
    
    # Assert the flags indicate that samples are being overwritten
    Assert Flag               ${NEW_DATA}  ${NEW_DATA_POSITION}  1
    Assert Flag               ${OVR_DATA}  ${OVR_DATA_POSITION}  1

    # Read sample and check if flags are adjusted
    Execute Command           ${MC3635} RegisterRead 0x2
    ${OVR_DATA}=              Execute Command  ${MC3635} RegisterRead ${OVR_DATA_REG}
    ${NEW_DATA}=              Execute Command  ${MC3635} RegisterRead ${NEW_DATA_REG}
    Assert Flag               ${NEW_DATA}  ${NEW_DATA_POSITION}  0
    Assert Flag               ${OVR_DATA}  ${OVR_DATA_POSITION}  1

    # Wait for the configuration to end, and then for a few more samples. Then assert that samples are not being overwritten
    Execute Command           emulation RunFor '0.05'
    ${OVR_DATA}=              Execute Command  ${MC3635} RegisterRead ${OVR_DATA_REG}
    Assert Flag               ${OVR_DATA}  ${OVR_DATA_POSITION}  0

