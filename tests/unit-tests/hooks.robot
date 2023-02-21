*** Test Cases ***
Should Parse Monitor in CPU Hook
    Execute Command          include @scripts/single-node/miv.resc
    Execute Command          cpu AddHook `cpu PC` "monitor.Parse('log \\"message from the cpu hook\\"')"

    Create Log Tester        1
    Start Emulation

    Wait For Log Entry       message from the cpu hook

