*** Variables ***
${ACCEL}                 sysbus.i2c1.accel
${UART}                  sysbus.usart2
${ACCEL_POLLING_SAMPLE}  @https://dl.antmicro.com/projects/renode/b_l072z_lrwan1--zephyr-accel_polling.elf-s_731368-a41b79116936bdadbee51e497847273f971ed409
${ACCEL_POLLING_SAMPLE_14BIT}  @https://dl.antmicro.com/projects/renode/b_l072z_lrwan1--zephyr-accel_polling-high_performance.elf-s_731368-049f6743622eb0b8068dbc2a24742561c8fa046a
${CSV2RESD}              ${RENODETOOLS}/csv2resd/csv2resd.py

*** Keywords ***
Execute Python Script
    [Arguments]  ${path}  ${args}

    Evaluate  subprocess.run([sys.executable, "${path}", ${args}])  sys,subprocess

Create Machine
    Execute Command         using sysbus
    Execute Command         mach create
    Execute Command         machine LoadPlatformDescription @platforms/cpus/stm32l072.repl
    Execute Command         machine LoadPlatformDescriptionFromString 'accel: Sensors.LIS2DW12 @ i2c1 0x2d'
    Create Terminal Tester  ${UART}
    Create Log Tester       0
    Execute Command         logLevel -1 ${ACCEL}

Format Fixed Point Integer As Decimal
    [Arguments]  ${value}  ${places}

    ${minus}=  Set Variable  ${EMPTY}
    IF  ${value} < 0
        ${minus}=  Set Variable  -
        ${value}=  Evaluate  abs(${value})
    END

    ${divisor}=  Evaluate  10**${places}
    ${units}=  Evaluate  ${value} / ${divisor}
    ${fraction}=  Evaluate  ${value} % ${divisor}
    ${string}=  Evaluate  "${minus}%d.%0${places}d" % (${units}, ${fraction})

    RETURN  ${string}

Wait For Peripheral Reading
    [Arguments]  ${microg}  ${resolution}

    IF  ${resolution} == 12
        ${sensitivity}=  Set Variable  976
        ${shift}=  Set Variable  4
    ELSE IF  ${resolution} == 14
        ${sensitivity}=  Set Variable  244
        ${shift}=  Set Variable  2
    ELSE
        Fail               Invalid resolution ${resolution} bits
    END

    ${steps}=  Evaluate  int(${microg} / ${sensitivity})
    ${outValue}=  Evaluate  ${steps} * ${sensitivity}
    ${outStr}=  Format Fixed Point Integer As Decimal  ${outValue}  6

    ${lsbs}=  Evaluate  abs(${steps}) << ${shift}
    # Use twos-complement representation if negative
    IF  ${steps} < 0
        ${lsbs}=  Evaluate  (abs(${lsbs}) ^ 0xffff) + 1
    END
    ${lsbsStr}=  Convert To Hex  ${lsbs}  prefix=0x  length=4

    Wait For Line On Uart  lis2dw12@2d *\\[g]: *\\( *${outStr}, *${outStr}, *${outStr}\\)  treatAsRegex=true  pauseEmulation=true
    Wait For Log Entry     Conversion done with sensitivity: 0.${sensitivity}, result: ${lsbsStr}

Wait For Peripheral Reading For Set Value And Known LSBs
    [Arguments]  ${microg}  ${resolution}  ${lsbs}

    ${g}=  Format Fixed Point Integer As Decimal  ${microg}  6
    # For LIS2DW12 operating in FIFO mode, setting `DefaultAcceleration` would be enough 
    # as it would start returning default samples after RESD stream is finished.
    # For Bypass mode it needs to be set explicitly (through `Acceleration` properties),
    # because the actual sample is kept until it is overwritten by a new sample.
    Execute Command        ${ACCEL} DefaultAccelerationX ${g}
    Execute Command        ${ACCEL} DefaultAccelerationY ${g}
    Execute Command        ${ACCEL} DefaultAccelerationZ ${g}
    Execute Command        ${ACCEL} AccelerationX ${g}
    Execute Command        ${ACCEL} AccelerationY ${g}
    Execute Command        ${ACCEL} AccelerationZ ${g}
    # Wait for the expected LSBs value keeping the entry for use by the following keyword
    Wait For Log Entry     result: ${lsbs}  timeout=2  pauseEmulation=true  keep=true
    Wait For Peripheral Reading  ${microg}  ${resolution}

Create RESD File
    [Arguments]  ${resdArgs}
    ${resdPath}=  Evaluate  tempfile.mktemp()  tempfile
    ${resdArgs}=  Catenate  SEPARATOR=,  ${resdArgs}  r"${resdPath}"

    Execute Python Script  ${CSV2RESD}  ${resdArgs}

    RETURN  ${resdPath}

Test Teardown And Cleanup RESD File
    [Arguments]  ${resdPath}

    Test Teardown
    Remove File  ${resdPath}

LIS2DW12 Should Return Data From RESD
    [Arguments]  ${firmware}  ${resolution}
    ${resdArgs}=  Catenate  SEPARATOR=,
                  ...       "--input", r"${CURDIR}/LIS2DW12-samples.csv"
                  ...       "--frequency", "1"
                  ...       "--start-time", "0"
                  ...       "--map", "acceleration:x,y,z:x,y,z"

    ${resdPath}=  Create RESD File  ${resdArgs}

    Create Machine

    Execute Command        sysbus LoadELF ${firmware}
    Wait For Line On Uart  Booting Zephyr OS  pauseEmulation=true

    Execute Command        ${ACCEL} FeedAccelerationSamplesFromRESD @${resdPath}

    Wait For Peripheral Reading  100000  ${resolution}
    Wait For Peripheral Reading  200000  ${resolution}
    Wait For Peripheral Reading  300000  ${resolution}
    Wait For Peripheral Reading  400000  ${resolution}
    Wait For Peripheral Reading  500000  ${resolution}
    Wait For Peripheral Reading  600000  ${resolution}
    Wait For Peripheral Reading  700000  ${resolution}
    Wait For Peripheral Reading  -100000  ${resolution}
    Wait For Peripheral Reading  -200000  ${resolution}

    # Run for an additional second to allow RESD stream to finish before setting an actual sample to an arbitrary value.
    # Otherwise set sample will be overridden by the one fed from RESD.
    Execute Command        emulation RunFor "1"

    RETURN  ${resdPath}

Prepare Multi-Frequency Data Test
    # 3 blocks starting one after the other: low-frequency, high-frequency, low-frequency
    ${resdArgs}=  Catenate  SEPARATOR=,
                  ...       "--input", r"${CURDIR}/LIS2DW12-samples_lowfreq1.csv"
                  ...       "--frequency", "100"
                  ...       "--start-time", "0"
                  ...       "--map", "acceleration:x,y,z:x,y,z"
                  ...       "--input", r"${CURDIR}/LIS2DW12-samples_highfreq.csv"
                  ...       "--frequency", "1600"
                  ...       "--start-time", "320000000"
                  ...       "--map", "acceleration:x,y,z:x,y,z"
                  ...       "--input", r"${CURDIR}/LIS2DW12-samples_lowfreq2.csv"
                  ...       "--frequency", "100"
                  ...       "--start-time", "340000000"
                  ...       "--map", "acceleration:x,y,z:x,y,z"

    ${resdPath}=  Create RESD File  ${resdArgs}

    Execute Command        allowPrivates true
    Execute Command        using sysbus
    Execute Command        mach create
    Execute Command        machine LoadPlatformDescriptionFromString "i2c1: I2C.STM32F7_I2C @ sysbus 0x10000000"
    Execute Command        machine LoadPlatformDescriptionFromString "accel: Sensors.LIS2DW12 @ i2c1 0"
    Execute Command        logLevel -1 ${ACCEL}

    # The accelerometer starts at 100 Hz, which we'll call the "low frequency"
    Execute Command        ${ACCEL} SampleRate 100
    Execute Command        ${ACCEL} FeedAccelerationSamplesFromRESD @${resdPath} type=MultiFrequency

    RETURN  ${resdPath}

Acceleration Should Be
    [Arguments]  ${major}  ${minor}

    ${actual}=  Execute Command  ${ACCEL} AccelerationX
    ${minor}=  Evaluate  "{:03}".format(${minor})
    # Why 2 separate rstrips? To turn 0.010 into 0.01, but 0.000 into 0 and not ""
    ${expected}=  Evaluate  "${major}.${minor}".rstrip("0").rstrip(".")
    Should Be Equal  ${actual.strip()}  ${expected}

*** Test Cases ***
LIS2DW12 Should Return Data From RESD In 12-Bit Mode
    ${resdPath}=  LIS2DW12 Should Return Data From RESD  ${ACCEL_POLLING_SAMPLE}  12

    # Test Teardown must be called from a test teardown as it uses Run Keyword If Test Failed, so
    # we have to repeat this here instead of in LIS2DW12 Should Return Data From RESD
    [Teardown]             Test Teardown And Cleanup RESD File  ${resdPath}

LIS2DW12 Should Return Data From RESD In 14-Bit Mode
    ${resdPath}=  LIS2DW12 Should Return Data From RESD  ${ACCEL_POLLING_SAMPLE_14BIT}  14

    # Additionally verify the examples from ST AN5038. In the app note the calculated
    # mg values are rounded to integers, these are exact values.
    Wait For Peripheral Reading For Set Value And Known LSBs  -40992  14  0xFD60
    Wait For Peripheral Reading For Set Value And Known LSBs  7320  14  0x0078
    Wait For Peripheral Reading For Set Value And Known LSBs  1046028  14  0x42FC

    [Teardown]             Test Teardown And Cleanup RESD File  ${resdPath}

LIS2DW12 Should Return Multi-Frequency Data - Switch Late
    ${resdPath}=  Prepare Multi-Frequency Data Test

    # the full low-frequency block #1
    FOR  ${i}  IN RANGE  32
        Acceleration Should Be  0  ${i}  # the first low-frequency block has values 0, 0.001, ...
        Execute Command        emulation RunFor "0.01"  # play one low-frequency point
    END
    # 3 more HF sample periods, staying at the low frequency
    FOR  ${i}  IN RANGE  3
        Acceleration Should Be  0  31  # the last low-frequency sample repeating
        Execute Command        emulation RunFor "0.000625"  # play one high-frequency point
    END
    Execute Command        ${ACCEL} SampleRate 1600
    FOR  ${i}  IN RANGE  32
        Acceleration Should Be  1  ${i}  # the high-frequency block has values 1, 1.001, ...
        Execute Command        emulation RunFor "0.000625"  # play one high-frequency point
    END
    # 3 more HF sample periods, staying at the high frequency
    FOR  ${i}  IN RANGE  3
        Acceleration Should Be  1  31  # the last high-frequency sample repeating
        Execute Command        emulation RunFor "0.000625"  # play one high-frequency point
    END
    Execute Command        ${ACCEL} SampleRate 100
    FOR  ${i}  IN RANGE  32
        Acceleration Should Be  2  ${i}  # the second low-frequency block has values 2, 2.001, ...
        Execute Command        emulation RunFor "0.01"  # play one low-frequency point
    END

    [Teardown]             Test Teardown And Cleanup RESD File  ${resdPath}

LIS2DW12 Should Return Multi-Frequency Data - Switch Early
    ${resdPath}=  Prepare Multi-Frequency Data Test

    # the first 16 samples of low-frequency block #1
    FOR  ${i}  IN RANGE  16
        Acceleration Should Be  0  ${i}  # the first low-frequency block has values 0, 0.001, ...
        Execute Command        emulation RunFor "0.01"  # play one low-frequency point
    END
    Execute Command        ${ACCEL} SampleRate 1600
    # the first 20 samples of the high-frequency block
    FOR  ${i}  IN RANGE  20
        Acceleration Should Be  1  ${i}  # the high-frequency block has values 1, 1.001, ...
        Execute Command        emulation RunFor "0.000625"  # play one high-frequency point
    END
    Execute Command        ${ACCEL} SampleRate 100
    FOR  ${i}  IN RANGE  32
        Acceleration Should Be  2  ${i}  # the second low-frequency block has values 2, 2.001, ...
        Execute Command        emulation RunFor "0.01"  # play one low-frequency point
    END

    [Teardown]             Test Teardown And Cleanup RESD File  ${resdPath}
