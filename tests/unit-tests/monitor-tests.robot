*** Settings ***
Library                         DateTime

*** Variables ***
${AUTOCOMPLETION_RESC}          scripts/single-node/sam4s.resc

*** Keywords ***
Test Autocompletion
    [Arguments]               ${suggestion}
    Execute Command           include @${AUTOCOMPLETION_RESC}
    Execute Command           py "monitor.SuggestionNeeded('${suggestion}')"

*** Test Cases ***
Should Pause Renode
    # we test if pausing can interrupt the execution before the end of the quantum (hence testing against a value lower than 10)
    ${pause_limit}=           Convert Time  9
    Execute Command           i @scripts/single-node/miv.resc
    Execute Command           cpu PerformanceInMips 1
    # treat WFI as NOP because WFI might make virtual time advance too far if it has fallen behind host time
    Execute Command           cpu WfiAsNop true
    Execute Command           emulation SetGlobalQuantum "10"
    # we assume that starting/pausing of the simulation happens during the same quantum;
    # it seems to be a resonable expectation for the quantum value of 10 virtual seconds
    Execute Command           s
    Execute Command           p
    ${time_source_info}=      Execute Command  emulation GetTimeSourceInfo
    ${elapsed_matches}=       Get Regexp Matches  ${time_source_info}  Elapsed Virtual Time: ([0-9:.]+)  1
    ${elapsed}=               Convert Time  ${elapsed_matches[0]}

    Should Be True            ${elapsed} < ${pause_limit}

Should Print Last Logs
    Execute Command           i @scripts/single-node/miv.resc
    ${logs}=                  Execute Command  lastLog
    Should Contain            ${logs}  [INFO] cpu: Setting PC value to 0x80000000.

Should Overflow Buffer
    FOR  ${i}  IN RANGE  1000
        Execute Command           log "Test-${i}-Log"
    END
    ${logs}=                  Execute Command  lastLog 1000
    Should Contain            ${logs}  Test-0-Log
    Should Contain            ${logs}  Test-999-Log
    Should Not Contain        ${logs}  Test-1000-Log
    Execute Command           log "Test-1000-Log"
    ${logs}=                  Execute Command  lastLog 1000
    Should Not Contain        ${logs}  Test-0-Log
    Should Contain            ${logs}  Test-1-Log
    Should Contain            ${logs}  Test-1000-Log

Should Load Python Standard Library
    ${result}=                Execute Command  python "import SimpleHTTPServer"
    Should Not Contain        ${result}  No module named

Should Set Proper Types To Variables
    Execute Command           \$var1=1234
    Execute Command           set var2 2345

    Execute Command           emulation SetSeed $var1
    Execute Command           emulation SetSeed $var2

Should Not Call Conditional Set
    Execute Command           \$var1=1234
    Execute Command           \$var1?=5678

    ${res}=                   Execute Command  echo $\var1
    Should Be Equal           ${res.strip()}  1234

Should Call Conditional Set
    Execute Command           \$var1?=5678

    ${res}=                   Execute Command  echo $\var1
    Should Be Equal           ${res.strip()}  5678

Should Call GPIO Set
    Execute Command           i @scripts/single-node/nrf52840.resc
    ${gpioState}=             Execute Command  uart0 IRQ
    Should Contain            ${gpioState}  GPIO: unset
    Execute Command           uart0 IRQ Set true
    ${gpioState}=             Execute Command  uart0 IRQ
    Should Contain            ${gpioState}  GPIO: set

Should Not Crash On Bool Autocompletion
    Test Autocompletion       cpu IsHalted

Should Not Crash On Int Autocompletion
    Test Autocompletion       cpu MaximumBlockSize

Should Not Crash On String Autocompletion
    Test Autocompletion       cpu LogFile

Should Allow Passing An Array To A Property Setter
    Execute Command           mach create
    Execute Command           using sysbus
    Execute Command           i @platforms/boards/beaglev-fire.repl

    Execute Command           qspi.pseFlash SFDPSignature [1]
    ${sig}=                   Execute Command  qspi.pseFlash SFDPSignature
    Should Be Equal As Strings  ${sig}  [ 0x01, ]  strip_spaces=True  collapse_spaces=True

    Execute Command           qspi.pseFlash SFDPSignature [1, 2, 3]
    ${sig}=                   Execute Command  qspi.pseFlash SFDPSignature
    Should Be Equal As Strings  ${sig}  [ 0x01, 0x02, 0x03, ]  strip_spaces=True  collapse_spaces=True

    Execute Command           qspi.pseFlash SFDPSignature []
    ${sig}=                   Execute Command  qspi.pseFlash SFDPSignature
    Should Be Equal As Strings  ${sig}  [ ]  strip_spaces=True  collapse_spaces=True

    Run Keyword And Expect Error  *Could not convert [[]NumericToken: Value*1*[]] to System.Byte[[][]]*
    ...                       Execute Command  qspi.pseFlash SFDPSignature 1

Should Allow Select On Byte Array
    Execute Command           mach create
    Execute Command           using sysbus
    Execute Command           i @platforms/boards/beaglev-fire.repl

    Execute Command           qspi.pseFlash SFDPSignature [1, 2, 3]
    ${sig}=                   Execute Command  qspi.pseFlash SFDPSignature Select ToString "x4"
    Should Be Equal As Strings  ${sig}  [ 0001, 0002, 0003, ]  strip_spaces=True  collapse_spaces=True

Should Not Crash On Invalid Scalar Type
    Execute Command           mach create
    Execute Command           using sysbus
    Execute Command           i @platforms/boards/beaglev-fire.repl

    Run Keyword And Expect Error  *Cannot convert type 'string' to 'Antmicro.Renode.Peripherals.CPU.RegisterValue'*
    ...                       Execute Command  e51 STVEC a
