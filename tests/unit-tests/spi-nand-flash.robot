*** Keywords ***
Create Machine
    Execute Command           mach create
    Execute Command           using sysbus
    Execute Command           machine LoadPlatformDescriptionFromString "spi: SPI.HiFive_SPI @ sysbus 0x10000000; spiNand: SPI.GenericSpiNandFlash @ spi 0 { manufacturerId: 0x52; deviceId: 0x24; blocksCount: 1024; pageSize: 2048; spareSize: 64 }"

Create Winbond Machine
    Execute Command           mach create
    Execute Command           using sysbus
    Execute Command           machine LoadPlatformDescriptionFromString "spi: SPI.HiFive_SPI @ sysbus 0x10000000; spiNand: SPI.GenericSpiNandFlash @ spi 0 { manufacturerId: 0xEF; deviceId: 0xAA21; blocksCount: 2048; pageSize: 2048; spareSize: 64 }"

*** Test Cases ***
Should Instantiate GenericSpiNandFlash From Repl
    Create Machine
    ${manId}=                 Execute Command  spi.spiNand ManufacturerId
    Should Be Equal As Strings  ${manId}  0x52  strip_spaces=True
    ${devId}=                 Execute Command  spi.spiNand DeviceId
    Should Be Equal As Strings  ${devId}  0x0024  strip_spaces=True
    ${pageSize}=              Execute Command  spi.spiNand PageSize
    Should Be Equal As Strings  ${pageSize}  0x00000800  strip_spaces=True
    ${spareSize}=             Execute Command  spi.spiNand SpareSize
    Should Be Equal As Strings  ${spareSize}  0x00000040  strip_spaces=True
    ${blocksCount}=           Execute Command  spi.spiNand BlocksCount
    Should Be Equal As Strings  ${blocksCount}  0x00000400  strip_spaces=True

Should Instantiate Winbond Flash With 16Bit DeviceId
    Create Winbond Machine
    ${manId}=                 Execute Command  spi.spiNand ManufacturerId
    Should Be Equal As Strings  ${manId}  0xEF  strip_spaces=True
    ${devId}=                 Execute Command  spi.spiNand DeviceId
    Should Be Equal As Strings  ${devId}  0xAA21  strip_spaces=True
    ${blocksCount}=           Execute Command  spi.spiNand BlocksCount
    Should Be Equal As Strings  ${blocksCount}  0x00000800  strip_spaces=True
