*** Variables ***
${sdmmc}=  SEPARATOR=
...  """ \n
...  sdmmc: SD.STM32SDMMC @ sysbus \n
...  """ \n
${nonexistent_error}=                  REGEXP: (?s:.)*Could not find image file '/doesntexist'(?s:.)*
${empty_error}=                        REGEXP: (?s:.)*No image file provided(?s:.)*

*** Keywords ***
Setup Machine
    Execute Command                    mach create
    Execute Command                    machine LoadPlatformDescriptionFromString ${SDMMC}

*** Test Cases ***
Should Be Able To Load Existing File
    Setup Machine
    # The actual file contents don't matter for loading an SD card, so simply use this file
    Execute Command                    machine SdCardFromFile "${SUITE_SOURCE}" sdmmc 0x1000
Should Fail At Loading Nonexistent File
    Setup Machine
    Run Keyword And Expect Error       ${nonexistent_error}  Execute Command  machine SdCardFromFile "/doesntexist" sdmmc 0x1000
Should Fail At Loading Empty Path
    Setup Machine
    Run Keyword And Expect Error       ${empty_error}        Execute Command  machine SdCardFromFile "" sdmmc 0x1000
