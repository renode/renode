*** Variables ***
${UART}                             sysbus.usart2
${BASE_REPL}                        platforms/cpus/stm32h753.repl
${EXTRA_PLATFORM_DESC}              SEPARATOR=
...                                 """  ${\n}
...                                 iis2mdc: Sensors.IIS2MDC @ i2c1 0x1e  ${\n}
...                                 ${SPACE*4}-> gpioPortG@11  ${\n}
...                                 """
${SENSOR}                           sysbus.i2c1.iis2mdc
${CSV2RESD}                         ${RENODETOOLS}/csv2resd/csv2resd.py
${SAMPLES_CSV}                      ${CURDIR}/iis2mdc-samples.csv
${POLLING_BIN}                      https://dl.antmicro.com/projects/renode/nucleo_h753zi--zephyr-iis2mdc_magn_polling.elf-s_860716-5599c7a86f3d898bc083c2a30d12ede98f9d2fec
${TRIGGER_BIN}                      https://dl.antmicro.com/projects/renode/nucleo_h753zi--zephyr-iis2mdc_magn_trig.elf-s_862212-26f5a81694b9ea2b6c35a05a6c901d30126c303d

*** Keywords ***
Create Machine
    [Arguments]                     ${BIN}
    Execute Command                 mach create
    Execute Command                 machine LoadPlatformDescription @${BASE_REPL}
    Execute Command                 machine LoadPlatformDescriptionFromString ${EXTRA_PLATFORM_DESC}
    Execute Command                 sysbus LoadELF @${BIN}
    Create Terminal Tester          ${UART}  defaultPauseEmulation=False

Wait For Polled Sample
    [Arguments]                     ${x}=0.000000  ${y}=0.000000  ${z}=0.000000
    Wait For Line On Uart           \\( x y z \\) = \\( +${x} +${y} +${z} \\)  treatAsRegex=True

Wait For Triggered Sample
    [Arguments]                     ${x}=0.000000  ${y}=0.000000  ${z}=0.000000
    Wait For Line On Uart           ${SPACE}*iis2mdc@1e \\(x, y, z\\): *\\( *${x}, +${y}, +${z}\\)  treatAsRegex=True

Create RESD File
    [Arguments]                     ${path}
    ${resd_path}=                   Allocate Temporary File
    ${args}=                        Catenate  SEPARATOR=,
    ...                             "--input", r"${path}"
    ...                             "--start-time", "3000000000"
    ...                             "--frequency", "2"
    ...                             "--timestamp", "timestamp"
    ...                             "--map", "magnetic_flux_density:magnetic_flux_density_x,magnetic_flux_density_y,magnetic_flux_density_z:x,y,z"
    ...                             r"${resd_path}"
    Evaluate                        subprocess.run([sys.executable, "${CSV2RESD}", ${args}])  sys,subprocess
    RETURN                          ${resd_path}

*** Test Cases ***
Should Poll Magnetic Flux Density
    ${resd_path}=                   Create RESD File  ${SAMPLES_CSV}
    Create Machine                  ${POLLING_BIN}
    Execute Command                 ${SENSOR} FeedMagneticSamplesFromRESD @${resd_path}

    Wait For Polled Sample          x=0.150000  y=0.300000  z=0.001500
    Wait For Polled Sample          x=0.150000  y=0.000000  z=0.000000
    Wait For Polled Sample          x=0.000000  y=0.150000  z=0.000000
    Wait For Polled Sample          x=0.000000  y=0.000000  z=0.150000
    Wait For Polled Sample          x=-0.150000  y=-0.300000  z=-0.001500
    Wait For Polled Sample          x=-0.150000  y=0.000000  z=0.000000
    Wait For Polled Sample          x=0.000000  y=-0.150000  z=0.000000
    Wait For Polled Sample          x=0.000000  y=0.000000  z=-0.150000
    Wait For Polled Sample          x=-1.234500  y=0.678000  z=0.000000

Should Fetch Magnetic Flux Density On Trigger
    ${resd_path}=                   Create RESD File  ${SAMPLES_CSV}
    Create Machine                  ${TRIGGER_BIN}
    Execute Command                 ${SENSOR} FeedMagneticSamplesFromRESD @${resd_path}

    Wait For Triggered Sample       x=0.150000  y=0.300000  z=0.001500
    Wait For Triggered Sample       x=0.150000  y=0.000000  z=0.000000
    Wait For Triggered Sample       x=0.000000  y=0.150000  z=0.000000
    Wait For Triggered Sample       x=0.000000  y=0.000000  z=0.150000
    Wait For Triggered Sample       x=-0.150000  y=-0.300000  z=-0.001500
    Wait For Triggered Sample       x=-0.150000  y=0.000000  z=0.000000
    Wait For Triggered Sample       x=0.000000  y=-0.150000  z=0.000000
    Wait For Triggered Sample       x=0.000000  y=0.000000  z=-0.150000
    Wait For Triggered Sample       x=-1.234500  y=0.678000  z=0.000000