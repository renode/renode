*** Variables ***
${REFERENCE_VOLTAGE}               4.82
${RESOLUTION_BITS}                 18
${PLATFORM}                        SEPARATOR=${\n}
...  using "platforms/cpus/stm32f4.repl"  # The specific platform doesn't matter - we just need something with SPI to connect the ADC to
...  adc: Analog.AD4011_ADC @ spi1 { referenceVoltage: ${REFERENCE_VOLTAGE} }


*** Keywords ***
Measurement To Volts
    [Arguments]                    ${measurement}
    ${lsb}=                        Evaluate  ${REFERENCE_VOLTAGE} / (1 << (${RESOLUTION_BITS} - 1))

    IF  ${measurement} >= (1 << (${RESOLUTION_BITS} - 1))
        # The measurement result is negative (in 2's complement)
        ${volts}=                  Evaluate  ((~${measurement} + 1) & (1 << ${RESOLUTION_BITS}) - 1) * ${lsb} * -1
    ELSE
        # The measurement result is positive (in 2's complement)
        ${volts}=                  Evaluate  ${measurement} * ${lsb}
    END

    RETURN                         ${volts}

Read Sensor
    ${first}=                      Execute Command  spi1.adc Transmit 0x0
    ${second}=                     Execute Command  spi1.adc Transmit 0x0
    ${third}=                      Execute Command  spi1.adc Transmit 0x0
    ${measurement}=                Evaluate  int(${first.strip()}) << 16 | int(${second.strip()}) << 8 | int(${third.strip()})

    RETURN                         ${measurement}

Assert Voltage
    [Arguments]                    ${expected}
    ${measurement}=                Read Sensor
    ${volts}=                      Measurement To Volts  ${measurement}

    # Account for ADC's finite precision
    Should Be True                 abs(${volts} - (${expected} - ${REFERENCE_VOLTAGE})) < 0.00005


*** Test Cases ***
Should Read Correct Voltage
    Execute Command                mach create
    Execute Command                machine LoadPlatformDescriptionFromString """${PLATFORM}"""
    Execute Command                machine LoadPlatformDescriptionFromString "vin: Analog.ADCChannelSource @ adc 0"

    # ADC can measure voltage in range [V_ref - V_ref; V_ref + V_ref) - test the entire range in 0.5V increments
    FOR    ${input_voltage}    IN RANGE    0  ${REFERENCE_VOLTAGE} + ${REFERENCE_VOLTAGE}  0.5
        Execute Command                spi1.adc.vin Volts ${input_voltage}
        Assert Voltage                 ${input_voltage}
    END

Should Read Correct Voltage From Floating Sources
    Execute Command                mach create
    Execute Command                machine LoadPlatformDescriptionFromString """${PLATFORM}"""
    Execute Command                machine LoadPlatformDescriptionFromString "vin: Analog.AnalogWire @ adc 0"
    Execute Command                machine LoadPlatformDescriptionFromString "input0: Analog.ADCChannelSource @ vin 0"
    Execute Command                machine LoadPlatformDescriptionFromString "input1: Analog.ADCChannelSource @ vin 1"

    ${input0_v}=                   Set Variable  ${REFERENCE_VOLTAGE}
    ${input1_v}=                   Evaluate  2 * ${REFERENCE_VOLTAGE}

    Execute Command                spi1.adc.vin.input0 Volts ${input0_v}
    Execute Command                spi1.adc.vin.input1 Volts ${input1_v}

    # input0 is floating, so input1 should be active
    Execute Command                spi1.adc.vin.input0 IsFloating true
    Assert Voltage                 ${input1_v}

    # input1 is floating, so input0 should be active
    Execute Command                spi1.adc.vin.input1 IsFloating true
    Execute Command                spi1.adc.vin.input0 IsFloating false
    Assert Voltage                 ${input0_v}

    # Both inputs are floating so 0V should be read
    Execute Command                spi1.adc.vin.input1 IsFloating true
    Execute Command                spi1.adc.vin.input0 IsFloating true
    Assert Voltage                 0

    # Both inputs are active so the one with the lower registration number should drive the wire (input0)
    Execute Command                spi1.adc.vin.input1 IsFloating false
    Execute Command                spi1.adc.vin.input0 IsFloating false
    Assert Voltage                 ${input0_v}
