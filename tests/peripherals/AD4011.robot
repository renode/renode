*** Variables ***
${REFERENCE_VOLTAGE}               4.82
${RESOLUTION_BITS}                 18
${PLATFORM}                        SEPARATOR=${\n}
...  using "platforms/cpus/stm32f4.repl"  # The specific platform doesn't matter - we just need something with SPI to connect the ADC to
...  adc: Analog.AD4011_ADC @ spi1 { referenceVoltage: ${REFERENCE_VOLTAGE} }
...  vin: Analog.ADCChannelSource @ adc 0


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


*** Test Cases ***
Should Read Correct Voltage
    Execute Command                mach create
    Execute Command                machine LoadPlatformDescriptionFromString """${PLATFORM}"""

    # ADC can measure voltage in range [V_ref - V_ref; V_ref + V_ref) - test the entire range in 0.5V increments
    FOR    ${input_voltage}    IN RANGE    0  ${REFERENCE_VOLTAGE} + ${REFERENCE_VOLTAGE}  0.5
        Execute Command                spi1.adc.vin Volts ${input_voltage}

        ${measurement_raw}=            Read Sensor
        ${volts}=                      Measurement To Volts  ${measurement_raw}

        # Account for ADC's finite precision
        Should Be True                 abs(${volts} - (${input_voltage} - ${REFERENCE_VOLTAGE})) < 0.00005
    END
