*** Variables ***
${ACCEL}                 sysbus.i2c1.accel
${UART}                  sysbus.usart2
${ACCEL_POLLING_SAMPLE}  @https://dl.antmicro.com/projects/renode/zephyr-accel_polling-stm32l072-lisdw21.elf-s_738332-c432d7435430798f9e03b3a65ce8a023119f8cc6
${CSV2RESD}              ${CURDIR}/../../tools/csv2resd/csv2resd.py

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

Wait For Peripheral Reading
    [Arguments]  ${number}

    Wait For Line On Uart  lis2dw12@2d \\[m/s\\^2\\]: {4}\\( {4}${number}......., {5}${number}......., {5}${number}.......\\)  treatAsRegex=true

*** Test Cases ***
Should Create RESD File
    ${tmpDir}=    Evaluate  tempfile.mkdtemp()  tempfile
    ${resdPath}=  Set Variable  ${tmpDir}/samples.resd
    ${resdArgs}=  Catenate  SEPARATOR=,
                  ...       "--input", "${CURDIR}/LIS2DW12-samples.csv"
                  ...       "--frequency", "1"
                  ...       "--start-time", "0"
                  ...       "--map", "acceleration:x,y,z:x,y,z"
                  ...       "${resdPath}"

    Execute Python Script  ${CSV2RESD}  ${resdArgs}

    Create Machine

    Execute Command        sysbus LoadELF ${ACCEL_POLLING_SAMPLE}
    Wait For Line On Uart  Booting Zephyr OS  pauseEmulation=true

    Execute Command        ${ACCEL} FeedAccelerationSamplesFromRESD @${resdPath}

    Wait For Peripheral Reading  0
    Wait For Peripheral Reading  1
    Wait For Peripheral Reading  2
    Wait For Peripheral Reading  3
    Wait For Peripheral Reading  4
    Wait For Peripheral Reading  5
    Wait For Peripheral Reading  6
