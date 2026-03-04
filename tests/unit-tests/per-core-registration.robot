*** Variables ***
${UART}                                  sysbus.uart
${COMMON_MEMORY}                         0x1400000
${PER_CORE_MEMORY}                       0x3000000
${CORE1_MEM_ALIAS}                       0x2010000
${CORE2_MEM_ALIAS}                       0x2020000
${CLUSTER_A_MEM_ALIAS}                   0x2030000
${CLUSTER_B_MEM_ALIAS}                   0x2040000
${MOVE_TARGET}                           0xAAA0000
${UART_ADDR}                             0x50230000
${UART_ADDR_MOVED}                       0x60230000
${URI}                                   @https://dl.antmicro.com/projects/renode
${TEST_ELF}                              ${URI}/multibus_test.elf-s_3718712-8ec6b7305242b1bfce702459d75ea02d04f00360

${CPU1_OVERLAY_MEMORY}=     SEPARATOR=
...  """                                                                             ${\n}
...  cpu1_mem: Memory.ArrayMemory @ sysbus new Bus.BusPointRegistration {            ${\n}
...  ${SPACE*4}address: 0x0;                                                         ${\n}
...  ${SPACE*4}cpu: cpu1                                                             ${\n}
...  }                                                                               ${\n}
...  ${SPACE*4}size: 0x1000                                                          ${\n}
...  """

${CPU1_SHADOW_MEMORY}=     SEPARATOR=
...  """                                                                             ${\n}
...  cpu1_shadow_mem: Memory.ArrayMemory @ sysbus new Bus.BusPointRegistration {     ${\n}
...  ${SPACE*4}address: 0xF00;                                                       ${\n}
...  ${SPACE*4}cpu: cpu1                                                             ${\n}
...  }                                                                               ${\n}
...  ${SPACE*4}size: 0x1000                                                          ${\n}
...  """

${unregistered_error}=     REGEXP: KeywordException:(?s:.)*Attempted to move a peripheral that isn't registered within current context(?s:.)*

*** Keywords ***
Create Machine
    [Arguments]  ${elf}=none

    Execute Command                      mach create
    Execute Command                      machine LoadPlatformDescription "${CURDIR}${/}per-core-registration.repl"

    IF  "${elf}" != "none"
        Execute Command                      macro reset "sysbus LoadELF ${elf}"
        Execute Command                      runMacro $reset

        Create Terminal Tester               ${UART}  timeout=1
    END


Create Machine With Hex File
    [Arguments]  ${cpu}

    Execute Command                      mach create
    Execute Command                      machine LoadPlatformDescription "${CURDIR}${/}per-core-registration-hex.repl"

    Execute Command                      sysbus LoadHEX @https://dl.antmicro.com/projects/renode/stm32f072b_disco--zephyr-hello_world.hex-s_34851-4e97c68491cf652d0becd549526cd3df56e8ae66 ${cpu}

 Add Peripheral Move Hook
    [Arguments]                          ${cpu}  ${hook_addr}  ${peripheral_addr}  ${new_address}
    ${hook_script}=                      Catenate  SEPARATOR=\n
                                         ...  from Antmicro.Renode.Peripherals.Bus import BusRangeRegistration
                                         ...  uart_peripheral = machine.SystemBus.WhatIsAt(${peripheral_addr}, cpu).Peripheral
                                         ...  new_registration = BusRangeRegistration(${new_address}, uart_peripheral.Size, cpu=cpu)
                                         ...  machine.SystemBus.MoveRegistrationWithinContext(uart_peripheral, new_registration, cpu)
    Execute Command                      ${cpu} AddHook ${hook_addr} """${hook_script}"""


Move Peripheral
    [Arguments]                          ${peripheral}  ${new_addr}  ${cpu}
    ${move_script}=                      Catenate  SEPARATOR=\n
                                         ...  from Antmicro.Renode.Peripherals.Bus import BusRangeRegistration
                                         ...  cpu = self.Machine['sysbus.${cpu}']
                                         ...  peripheral = self.Machine['sysbus.${peripheral}']
                                         ...  new_registration = BusRangeRegistration(${new_addr}, peripheral.Size, cpu=cpu)
                                         ...  self.Machine.SystemBus.MoveRegistrationWithinContext(peripheral, new_registration, cpu)
   Execute Command                       python """${move_script}"""

*** Test Cases ***
Fail On Shadowing Other Registration
           # Create machine with `ram` at 0x0 - 0x1FFFFFF.
           Create Machine                ${TEST_ELF}

           # Adding a CPU-specific peripheral over a global one is OK, accesses from that CPU will reach it instead.
           Execute Command               machine LoadPlatformDescriptionFromString ${CPU1_OVERLAY_MEMORY}

  # Adding another CPU-specific peripheral at address space already occupied for the given CPU should fail though.
  ${out}=  Run Keyword And Expect Error  KeywordException:*
           ...                           Execute Command
           ...                           machine LoadPlatformDescriptionFromString ${CPU1_SHADOW_MEMORY}
           Should Contain                ${out}     Error E39: Exception was thrown during registration
           Should Contain                ${out}     conflicts with peripheral

  ${per}=  Execute Command               peripherals
           Should Contain                ${per}     cpu1_mem
           Should Not Contain            ${per}     cpu1_shadow_mem

Get Same Read From Common Memory
           Create Machine                ${TEST_ELF}

           Execute Command               sysbus WriteDoubleWord ${COMMON_MEMORY} 0xDEADF00D
           Start Emulation

           Wait For Line On Uart         Core 0 read from ${COMMON_MEMORY} returned: 0xDEADF00D
           Wait For Line On Uart         Core 1 read from ${COMMON_MEMORY} returned: 0xDEADF00D

Values Written By One Core Should Not Be Visible By The Other One
           Create Machine                ${TEST_ELF}

           Start Emulation

           Wait For Line On Uart         Core 0 read from ${PER_CORE_MEMORY} returned: 0x0
           Wait For Line On Uart         Core 0 writing 0xB0B0B0B0 to per-core memory
           Wait For Line On Uart         Core 0 read from ${PER_CORE_MEMORY} returned: 0xB0B0B0B0

           Wait For Line On Uart         Core 1 read from ${PER_CORE_MEMORY} returned: 0x0
           Wait For Line On Uart         Core 1 writing 0xBABABABA to per-core memory
           Wait For Line On Uart         Core 1 read from ${PER_CORE_MEMORY} returned: 0xBABABABA

           Provides                      Finished

Write Values Using Sysbus
           Create Machine                ${TEST_ELF}

           Execute Command               sysbus.core1_mem WriteDoubleWord 0x0 0xFEEDFACE
           Execute Command               sysbus.core2_mem WriteDoubleWord 0x0 0xFEE1DEAD
           Start Emulation

           Wait For Line On Uart         Core 0 read from ${PER_CORE_MEMORY} returned: 0xFEEDFACE
           Wait For Line On Uart         Core 1 read from ${PER_CORE_MEMORY} returned: 0xFEE1DEAD

Write Values Using Sysbus With Context
           Create Machine                ${TEST_ELF}

           Execute Command               sysbus WriteDoubleWord ${PER_CORE_MEMORY} 0xFEEDFACE sysbus.cpu1
           Execute Command               sysbus WriteDoubleWord ${PER_CORE_MEMORY} 0xFEE1DEAD sysbus.cpu2
           Start Emulation

           Wait For Line On Uart         Core 0 read from ${PER_CORE_MEMORY} returned: 0xFEEDFACE
           Wait For Line On Uart         Core 1 read from ${PER_CORE_MEMORY} returned: 0xFEE1DEAD

Handle Being Simultaneously Registered On The Main Bus
           Requires                      Finished

  ${out}=  Execute Command               sysbus ReadDoubleWord ${CORE1_MEM_ALIAS}
           Should Be Equal As Numbers    ${out}  0xB0B0B0B0
  ${out}=  Execute Command               sysbus ReadDoubleWord ${CORE2_MEM_ALIAS}
           Should Be Equal As Numbers    ${out}  0xBABABABA

Read Values Using Sysbus Context
           Requires                      Finished

  ${out}=  Execute Command               sysbus ReadDoubleWord ${PER_CORE_MEMORY} sysbus.cpu1
           Should Be Equal As Numbers    ${out}  0xB0B0B0B0
  ${out}=  Execute Command               sysbus ReadDoubleWord ${PER_CORE_MEMORY} sysbus.cpu2
           Should Be Equal As Numbers    ${out}  0xBABABABA

Disassemble Code From Per Core Memory
           Create Machine                ${TEST_ELF}

           Execute Command               sysbus WriteDoubleWord ${PER_CORE_MEMORY} 0x1234 sysbus.cpu1
           Execute Command               sysbus WriteDoubleWord ${PER_CORE_MEMORY} 0x5678 sysbus.cpu2

  ${out}=  Execute Command               sysbus.cpu1 DisassembleBlock ${PER_CORE_MEMORY} 2
           Should Contain                ${out}    addi

  ${out}=  Execute Command               sysbus.cpu2 DisassembleBlock ${PER_CORE_MEMORY} 2
           Should Contain                ${out}    lw
Should Move Peripheral Registered Per Core
           Create Machine                ${TEST_ELF}

           # Verify expected UART registration
  ${out}=  Execute Command               sysbus WhatIsAt ${UART_ADDR} sysbus.cpu1
           Should Not Be Empty           ${out}
  ${out}=  Execute Command               sysbus WhatIsAt ${UART_ADDR} sysbus.cpu2
           Should Not Be Empty           ${out}
  ${out}=  Execute Command               sysbus WhatIsAt ${UART_ADDR_MOVED} sysbus.cpu1
           Should Be Empty               ${out}
  ${out}=  Execute Command               sysbus WhatIsAt ${UART_ADDR_MOVED} sysbus.cpu2
           Should Be Empty               ${out}

           Add Peripheral Move Hook      sysbus.cpu2  `sysbus GetSymbolAddress "thread_entry"`  ${UART_ADDR}  ${UART_ADDR_MOVED}

           Execute Command       showAnalyzer sysbus.uart
           Execute Command               start

           Wait For Line On Uart         Core 0 read from ${PER_CORE_MEMORY} returned: 0xB0B0B0B0

           Run Keyword And Expect Error  InvalidOperationException: Terminal tester failed!*
           ...                           Wait For Line On Uart
           ...                           Core 1 read from ${PER_CORE_MEMORY} returned: 0xBABABABA

           Execute Command               pause
           Execute Command               sysbus.cpu2 RemoveHooksAt `sysbus GetSymbolAddress "thread_entry"`

           Add Peripheral Move Hook      sysbus.cpu2  `sysbus GetSymbolAddress "thread_entry"`  ${UART_ADDR_MOVED}  ${UART_ADDR}

           Clear Terminal Tester Report
           Execute Command               runMacro $reset

           # UART registration shouldn't reset
  ${out}=  Execute Command               sysbus WhatIsAt ${UART_ADDR} sysbus.cpu1
           Should Not Be Empty           ${out}
  ${out}=  Execute Command               sysbus WhatIsAt ${UART_ADDR_MOVED} sysbus.cpu2
           Should Not Be Empty           ${out}
  ${out}=  Execute Command               sysbus WhatIsAt ${UART_ADDR_MOVED} sysbus.cpu1
           Should Be Empty               ${out}
  ${out}=  Execute Command               sysbus WhatIsAt ${UART_ADDR} sysbus.cpu2
           Should Be Empty               ${out}

           Execute Command               start

           Wait For Line On Uart         Core 0 read from ${PER_CORE_MEMORY} returned: 0xB0B0B0B0
           Wait For Line On Uart         Core 1 read from ${PER_CORE_MEMORY} returned: 0xBABABABA


Should Not Load Hex To Invalid Core Specific Memory
           Create Log Tester             0    # no need for additional timeout, we're only testing synchronous operations
           Create Machine With Hex File  sysbus.cpu1
           Wait For Log Entry            Tried to access bytes at non-existing peripheral


Should Load Hex To Core Specific Memory
           Create Log Tester             0    # no need for additional timeout, we're only testing synchronous operations
           Create Machine With Hex File  sysbus.cpu2
           Should Not Be In Log          Tried to access bytes at non-existing peripheral

Cluster Memory Should Only Be Visible To Cluster
           Create Machine

           Execute Command               sysbus WriteWord ${PER_CORE_MEMORY} 0x1234 sysbus.cpu1
           Execute Command               sysbus WriteWord ${PER_CORE_MEMORY} 0x5678 clusterA.cpuA1
           Execute Command               sysbus WriteWord ${PER_CORE_MEMORY} 0x9abc clusterB.cpuB1
           # Check nothing was overwritten
  ${out}=  Execute Command               sysbus ReadWord ${PER_CORE_MEMORY} sysbus.cpu1
           Should Be Equal As Numbers    ${out}  0x1234
  ${out}=  Execute Command               sysbus ReadWord ${PER_CORE_MEMORY} clusterA.cpuA2
           Should Be Equal As Numbers    ${out}  0x5678
  ${out}=  Execute Command               sysbus ReadWord ${PER_CORE_MEMORY} clusterB.cpuB2
           Should Be Equal As Numbers    ${out}  0x9abc
           # Check aliases
  ${out}=  Execute Command               sysbus ReadWord ${CORE1_MEM_ALIAS}
           Should Be Equal As Numbers    ${out}  0x1234
  ${out}=  Execute Command               sysbus ReadWord ${CLUSTER_A_MEM_ALIAS}
           Should Be Equal As Numbers    ${out}  0x5678
  ${out}=  Execute Command               sysbus ReadWord ${CLUSTER_B_MEM_ALIAS}
           Should Be Equal As Numbers    ${out}  0x9abc

Memory Should Only Be Movable Within Single CPU
           Create Machine

           Run Keyword And Expect Error  ${unregistered_error}
           ...  Move Peripheral          ram           ${MOVE_TARGET}  cpu1
           Run Keyword And Expect Error  ${unregistered_error}
           ...  Move Peripheral          clusterA_mem  ${MOVE_TARGET}  clusterA.cpuA1
           Move Peripheral               core1_mem     ${MOVE_TARGET}  cpu1

Memory Move Should Only Affect Relevant CPU
           Create Machine

           # core1_mem has two registrations - the globally-accessible CORE1_MEM_ALIAS, and the cpu1-only PER_CORE_MEMORY
           # Moving one should not affect the other
           Execute Command               sysbus WriteWord ${CORE1_MEM_ALIAS} 0x1234

  ${out}=  Execute Command               sysbus ReadWord ${PER_CORE_MEMORY} sysbus.cpu1
           Should Be Equal As Numbers    ${out}  0x1234

           Move Peripheral               core1_mem     ${MOVE_TARGET}  cpu1

  ${out}=  Execute Command               sysbus ReadWord ${MOVE_TARGET} sysbus.cpu1
           Should Be Equal As Numbers    ${out}  0x1234

           # Old memory should be now unmapped
  ${out}=  Execute Command               sysbus ReadWord ${PER_CORE_MEMORY} sysbus.cpu1
           Should Be Equal As Numbers    ${out}  0x0000

           Execute Command               sysbus WriteWord ${MOVE_TARGET} 0x5678 sysbus.cpu1
  ${out}=  Execute Command               sysbus ReadWord ${CORE1_MEM_ALIAS}
           Should Be Equal As Numbers    ${out}  0x5678
