*** Keywords **

Prepare Platform
    Execute Command        using sysbus
    Execute Command        mach create "zynq7000"
    Execute Command        machine LoadPlatformDescription @platforms/cpus/zynq-7000.repl
    Execute Command        sysbus LoadELF @https://dl.antmicro.com/projects/renode/seL4-zynq7000--camkes_adder_image-s_2996636-7f022f0d406eb8aa97854c724222cbebdc0baa2a
    Execute Command        sysbus LoadSymbolsFrom @https://dl.antmicro.com/projects/renode/seL4-zynq7000--camkes_adder_kernel-s_955080-1b84b2deb5c9d96d50ce3cca13a1e2df8fcb027a
    Execute Command        EnsureTypeIsLoaded "Antmicro.Renode.Peripherals.CPU.Arm"
    Execute Command        EnsureTypeIsLoaded "Antmicro.Renode.Peripherals.CPU.RiscV32"
    Execute Command        include @tools/sel4_extensions/seL4Extensions.cs
    Execute Command        cpu CreateSeL4

*** Test Cases ***

Should Break On Rootserver Thread And Then Exit To Kernel
                  Prepare Platform

                  Execute Command        seL4 BreakOnNamingThread "rootserver"
                  Run Until Breakpoint   1
    ${thread}=    Execute Command        seL4 CurrentThread
                  Should Contain         ${thread}        kernel

                  Execute Command        seL4 SetTemporaryBreakpoint "rootserver"
                  Execute Command        cpu ExecutionMode Continuous
                  Run Until Breakpoint   1
    ${thread}=    Execute Command        seL4 CurrentThread
                  Should Contain         ${thread}        rootserver

                  Execute Command        seL4 BreakOnExittingUserspace Once
                  Execute Command        cpu ExecutionMode Continuous
                  Run Until Breakpoint   1
    ${thread}=    Execute Command        seL4 CurrentThread
                  Should Contain         ${thread}        kernel
