*** Variables ***
${PLATFROM}                         platforms/boards/stm32f7_discovery-bb.repl
${BIN}                              https://dl.antmicro.com/projects/renode/stm32f746g--zephyr-i2c-akm09918c.elf-s_700820-475c7207bf761d676c9e9d4380375a778448e72c
${UART}                             sysbus.usart1
${SENSOR}                           sysbus.i2c1.ak09918
${CSV2RESD}                         ${RENODETOOLS}/csv2resd/csv2resd.py
${SAMPLES_CSV}                      ${CURDIR}/ak09918-samples.csv

*** Keywords ***
Create Machine
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription @${PLATFROM}
    Execute Command                 machine LoadPlatformDescriptionFromString "ak09918: Sensors.AK09916 @ i2c1 0xC"
    Execute Command                 sysbus LoadELF @${BIN}
    Create Terminal Tester          ${UART}

Set Enviroment
    [Arguments]                     ${x}=0  ${y}=0    ${z}=0
    Execute Command                 ${SENSOR} DefaultMagneticFluxDensityX ${x}
    Execute Command                 ${SENSOR} DefaultMagneticFluxDensityY ${y}
    Execute Command                 ${SENSOR} DefaultMagneticFluxDensityZ ${z}

Check Enviroment
    [Arguments]                     ${x}=0.000000  ${y}=0.000000    ${z}=0.000000
    Wait For Line On Uart           ( x y z ) = ( ${x}${SPACE}${SPACE}${y}${SPACE}${SPACE}${z} )

Create RESD File
    [Arguments]                     ${path}
    ${resd_path}=                   Allocate Temporary File
    ${args}=                        Catenate  SEPARATOR=,
    ...                             "--input", r"${path}"
    ...                             "--map", "magnetic_flux_density:magnetic_flux_density_x,magnetic_flux_density_y,magnetic_flux_density_z:x,y,z"
    ...                             "--start-time", "0"
    ...                             "--frequency", "1"
    ...                             r"${resd_path}"
    Evaluate                        subprocess.run([sys.executable, "${CSV2RESD}", ${args}])  sys,subprocess
    RETURN                          ${resd_path}

Create Timestamped RESD File
    [Arguments]                     ${path}
    ${resd_path}=                   Allocate Temporary File
    ${args}=                        Catenate  SEPARATOR=,
    ...                             "--input", r"${path}"
    ...                             "--map", "magnetic_flux_density:magnetic_flux_density_x,magnetic_flux_density_y,magnetic_flux_density_z:x,y,z"
    ...                             "--start-time", "0"
    ...                             "--timestamp", "timestamp"
    ...                             r"${resd_path}"
    Evaluate                        subprocess.run([sys.executable, "${CSV2RESD}", ${args}])  sys,subprocess
    RETURN                          ${resd_path}

*** Test Cases ***
Should Read Magnetic Flux Density
    Create Machine

    Check Enviroment                x=0.000000  y=0.000000  z=0.000000

    # sensor input value is in nanotesla
    # SW outputs in Gauss, so expected value is `value * 0.00001`

    Set Enviroment                  x=150
    Check Enviroment                x=0.001500

    Set Enviroment                  y=300
    Check Enviroment                y=0.003000

    Set Enviroment                  z=450
    Check Enviroment                z=0.004500

    Set Enviroment                  x=150   y=300  z=450
    Check Enviroment                x=0.001500  y=0.003000  z=0.004500

Should Read Samples From RESD
    Create Machine

    ${resd_path}=                   Create RESD File  ${SAMPLES_CSV}
    Execute Command                 ${SENSOR} FeedMagneticSamplesFromRESD @${resd_path}

    # sensor input value is in nanotesla
    # SW outputs in Gauss, so expected value is `value * 0.00001`

    Set Enviroment                  x=150   y=300  z=450

    Check Enviroment                x=0.150000  y=0.300000  z=0.450000
    Check Enviroment                x=0.300000  y=0.450000  z=0.600000
    Check Enviroment                x=0.450000  y=0.600000  z=0.750000
    # Sensor shouldn't go back to the default values after the RESD file finishes
    Check Enviroment                x=0.450000  y=0.600000  z=0.750000
    Check Enviroment                x=0.450000  y=0.600000  z=0.750000

Should Read Samples From Timestamped RESD
    Create Machine

    ${resd_path}=                   Create Timestamped RESD File  ${SAMPLES_CSV}
    Execute Command                 ${SENSOR} FeedMagneticSamplesFromRESD @${resd_path}

    # sensor input value is in nanotesla
    # SW outputs in Gauss, so expected value is `value * 0.00001`

    Set Enviroment                  x=150   y=300  z=450

    Check Enviroment                x=0.150000  y=0.300000  z=0.450000
    Check Enviroment                x=0.300000  y=0.450000  z=0.600000
    Check Enviroment                x=0.450000  y=0.600000  z=0.750000
    # Sensor shouldn't go back to the default values after the RESD file finishes
    Check Enviroment                x=0.450000  y=0.600000  z=0.750000
    Check Enviroment                x=0.450000  y=0.600000  z=0.750000
