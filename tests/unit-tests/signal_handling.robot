*** Settings ***
Test Teardown                       Custom Teardown
Library                             OperatingSystem

*** Variables ***
${MESSAGE}                          Received signal, exiting.

*** Keywords ***
Get Log File
    [Arguments]                     ${suffix}
    ${log_path}=                    Set Variable  ${RESULTS_DIRECTORY}/logs/${SUITE_NAME}.renode_${suffix}.log
    RETURN                          ${log_path}

Custom Teardown
    RETURN

*** Test Cases ***
Should Quit On Sigint
    Execute Command                 mach create

    ${pid}=                         Execute Command  python "import os; print(os.getpid())"

# In this test we leverage the fact that Externals are disposed first in the disposal chain
    ${handler_script}=              Catenate  SEPARATOR=\n
    ...                             import Antmicro.Renode.Logging
    ...                             from Antmicro.Renode.Core import EmulationManager, IExternal
    ...                             from System import IDisposable
    ...
    ...                             class SignalHandler(IExternal, IDisposable):
    ...                             ${SPACE*4}def Dispose(self):
    ...                             ${SPACE*8}Antmicro.Renode.Logging.Logger.Log(LogLevel.Info, "${MESSAGE}")
    ...                             ${SPACE*8}Antmicro.Renode.Logging.Logger.Flush()
    ...
    ...                             emulation = EmulationManager.Instance.CurrentEmulation
    ...                             emulation.ExternalsManager.AddExternal(SignalHandler(), "signal_handler_test_callback")
    Execute Command                 python """${handler_script}"""

    Evaluate                        os.kill(int($pid), signal.CTRL_BREAK_EVENT if sys.platform == "win32" else signal.SIGINT)    modules=os,signal,sys

    # Let Renode flush logs and gracefully quit
    Evaluate                        psutil.Process(int($pid)).wait()    modules=psutil

    ${log_filename}=                Get Log File  stdout
    ${log_output}=                  Get File  ${log_filename}
    Should Contain                  ${log_output}  ${MESSAGE}
