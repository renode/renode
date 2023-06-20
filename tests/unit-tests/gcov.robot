*** Settings ***
Suite Setup                   Setup
Suite Teardown                Teardown
Test Setup                    Reset Emulation
Test Teardown                 Test Teardown
Resource                      ${RENODEKEYWORDS}

*** Keywords ***
Prepare Machine
    [Arguments]               ${binary}

    Execute Command           using sysbus
    Execute Command           mach create
    Execute Command           machine LoadPlatformDescription @platforms/cpus/kendryte_k210.repl

    Execute Command           machine SetSerialExecution True

    Execute Command           sysbus Tag <0x50440000 0x10000> "SYSCTL"
    Execute Command           sysbus Tag <0x50440018 0x4> "pll_lock" 0xFFFFFFFF
    Execute Command           sysbus Tag <0x5044000C 0x4> "pll1"
    Execute Command           sysbus Tag <0x50440008 0x4> "pll0"
    Execute Command           sysbus Tag <0x50440020 0x4> "clk_sel0"
    Execute Command           sysbus Tag <0x50440028 0x4> "clk_en_cent"
    Execute Command           sysbus Tag <0x5044002c 0x4> "clk_en_peri"

    Execute Command           cpu1 MaximumBlockSize 1
    Execute Command           cpu2 MaximumBlockSize 1

    Execute Command           sysbus LoadELF ${binary}

Should Match Mapping
    [Arguments]        ${address}   ${file}
    ${x}=  Execute Command     gcov addr2line @${file} ${address}
    ${y}=  Run Process         addr2line  -e  ${file}  ${address}
    Should Contain             ${x}  ${y.stdout.split('/')[-1].split('(')[0].strip()}

Line Should Be Executed
    [Arguments]        ${input}   ${line_no}   ${count}
    ${ls}=  Get Lines Matching Regexp    ${input}     \\s*${count}:\\s*${line_no}:.+
    Should Not Be Empty  ${ls}     msg=Line ${line_no} execution count ${count} not found

*** Test Cases ***
Should Run Test1 Application
    ${elf_location}=          Set Variable  ${CURDIR}/gcov/test1
    ${elf_name}=              Set Variable  addr2line-test1.elf
    Prepare Machine           @${elf_location}/${elf_name}

    Execute Command           gcov start @${elf_location}/${elf_name}
    Execute Command           gcov add-source-prefix "/builds/git/renode-demo-sources/repositories/kendryte-standalone-sdk/src/test1/"

    Execute Command           emulation RunFor "0.007"

    Execute Command           gcov stop

    ${g}=  Run Process        gcov-10  ${elf_name}.gc  -t  cwd=${elf_location}
    Log To Console            ${g.stdout}

    # buf_increment_all
    Line Should Be Executed   ${g.stdout}       7     1
    Line Should Be Executed   ${g.stdout}       8   101
    Line Should Be Executed   ${g.stdout}       9   100

    # main
    Line Should Be Executed   ${g.stdout}      13     1
    Line Should Be Executed   ${g.stdout}      14     1
    Line Should Be Executed   ${g.stdout}      15     1
    Line Should Be Executed   ${g.stdout}      16     1
    Line Should Be Executed   ${g.stdout}      17    11
    Line Should Be Executed   ${g.stdout}      18    10
    Line Should Be Executed   ${g.stdout}      19    10
    Line Should Be Executed   ${g.stdout}      22     1
    Line Should Be Executed   ${g.stdout}      24    11
    Line Should Be Executed   ${g.stdout}      25    10

Should Run Test2 Application
    ${elf_location}=          Set Variable  ${CURDIR}/gcov/test2
    ${elf_name}=              Set Variable  addr2line-test2.elf
    Prepare Machine           @${elf_location}/${elf_name}

    Execute Command           gcov start @${elf_location}/${elf_name}
    Execute Command           gcov add-source-prefix "/builds/git/renode-demo-sources/repositories/kendryte-standalone-sdk/src/test2/"
    Execute Command           emulation RunFor "0.017"

    Execute Command           gcov stop

    ${g}=  Run Process        gcov-10  ${elf_name}.gc  -t  cwd=${elf_location}
    Log To Console            ${g.stdout}

    # # funB
    # Line Should Be Executed   ${g.stdout}      12     1
    # Line Should Be Executed   ${g.stdout}      13   101
    # Line Should Be Executed   ${g.stdout}      14   100

    # # funA
    # Line Should Be Executed   ${g.stdout}      12     1
    # Line Should Be Executed   ${g.stdout}      13   101
    # Line Should Be Executed   ${g.stdout}      14   100

    # buf_increment_all
    # Line Should Be Executed   ${g.stdout}      18     1
    # Line Should Be Executed   ${g.stdout}      19   101
    # Line Should Be Executed   ${g.stdout}      20   100

    # main
    Line Should Be Executed   ${g.stdout}      25     1
    Line Should Be Executed   ${g.stdout}      26   101
    Line Should Be Executed   ${g.stdout}      27   100
    Line Should Be Executed   ${g.stdout}      30     1
    # Line Should Be Executed   ${g.stdout}      32   101
    # Line Should Be Executed   ${g.stdout}      33    XX
    # Line Should Be Executed   ${g.stdout}      34    XX
    # Line Should Be Executed   ${g.stdout}      36    XX
    # Line Should Be Executed   ${g.stdout}      37    XX
    # Line Should Be Executed   ${g.stdout}      41     1
    # Line Should Be Executed   ${g.stdout}      43     1

Should Map Lines
    Prepare Machine           @${CURDIR}/gcov/test1/addr2line-test1.elf

    ${x}=  Execute Command     gcov func2lines @${CURDIR}/gcov/test1/addr2line-test1.elf "main"
    Should Contain             ${x}  main.c:13|12

    ${x}=  Execute Command     gcov func2lines @${CURDIR}/gcov/test1/addr2line-test1.elf "buf_increment_all"
    Should Contain             ${x}  main.c:7|34

Should Map Addresses
    Prepare Machine           @${CURDIR}/gcov/test1/addr2line-test1.elf

    # check mappings for all PCs covering functions
    # * main
    # * buf_increment_all
    Should Match Mapping       0x80000bb6        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000bb8        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000bba        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000bbc        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000bc0        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000bc4        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000bc6        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000bca        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000bcc        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000bd0        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000bd2        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000bd4        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000bd8        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000bda        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000bde        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000be0        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000be2        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000be4        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000be6        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000bea        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000bec        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000bf0        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000bf4        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000bf8        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000bfa        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000bfe        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c00        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c02        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c04        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c06        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c08        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c0a        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c0c        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c0e        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c12        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c14        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c18        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c1c        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c1e        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c20        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c24        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c28        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c2a        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c2e        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c32        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c34        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c36        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c3a        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c3e        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c42        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c46        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c4a        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c4c        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c4e        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c50        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c52        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c56        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c58        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c5a        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c5c        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c5e        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c62        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c66        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c68        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c6c        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c70        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c72        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c76        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c7a        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c7c        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c80        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c84        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c88        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c8a        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c8c        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c90        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c92        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c96        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c98        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c9c        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000c9e        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000ca2        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000ca4        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000ca8        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000cac        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000cb0        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000cb2        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000cb6        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000cba        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000cbc        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000cc0        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000cc4        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000cc8        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000cca        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000cce        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000cd2        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000cd4        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000cd6        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000cd8        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000cdc        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000cde        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000ce2        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000ce6        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000cea        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000cee        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000cf0        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000cf4        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000cf6        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000cfa        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000cfc        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000d00        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000d04        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000d08        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000d0a        ${CURDIR}/gcov/test1/addr2line-test1.elf
    Should Match Mapping       0x80000d0e        ${CURDIR}/gcov/test1/addr2line-test1.elf

Should Map Addresses 2
    Prepare Machine           @${CURDIR}/gcov/test2/addr2line-test2.elf

    # check mappings for all PCs covering functions
    # * main
    # * buf_increment_all
    # * funA
    # * funB
    Should Match Mapping       0x80000cbc	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000cbe	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000cc0	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000cc2	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000cc4	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000cc6	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000cc8	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000cca	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000cce	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000cd0	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000cd4	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000cd8	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000cda	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000cdc	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000ce0	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000ce4	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000ce6	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000cea	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000cee	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000cf0	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000cf2	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000cf6	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000cfa	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000cfe	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d02	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d06	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d08	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d0a	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d0c	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d0e	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d12	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d14	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d16	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d18	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d1a	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d1e	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d22	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d24	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d28	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d2c	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d2e	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d30	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d34	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d36	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d3a	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d3c	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d40	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d44	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d48	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d4a	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d4e	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d52	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d54	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d58	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d5c	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d60	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d62	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d66	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d6a	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d6c	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d6e	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d70	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d72	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d74	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d78	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d7a	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d7c	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d80	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d84	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d86	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d88	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d8c	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d90	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d94	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d98	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d9a	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d9c	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000d9e	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000da0	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000da2	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000da6	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000da8	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000daa	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000dae	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000db2	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000db4	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000db6	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000dba	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000dbe	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000dc2	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000dc4	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000dc8	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000dcc	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000dd0	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000dd2	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000dd6	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000dda	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000ddc	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000de0	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000de4	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000de6	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000de8	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000dea	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000dee	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000df0	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000df2	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000df4	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000df6	 ${CURDIR}/gcov/test2/addr2line-test2.elf

    Should Match Mapping       0x80000c6c        ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c6e        ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c70        ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c72        ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c76        ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c7a        ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c7c        ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c80        ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c82        ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c86        ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c88        ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c8a        ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c8e        ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c90        ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c94        ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c96        ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c98        ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c9a        ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c9c        ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000ca0        ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000ca2        ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000ca6        ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000caa        ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000cae        ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000cb0        ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000cb4        ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000cb6        ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000cb8        ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000cba        ${CURDIR}/gcov/test2/addr2line-test2.elf

    Should Match Mapping       0x80000c12	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c14	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c16	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c18	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c1c	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c1e	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c22	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c26	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c28	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c2c	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c2e	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c32	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c34	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c36	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c3a	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c3c	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c40	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c42	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c46	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c48	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c4a	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c4c	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c50	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c52	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c56	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c5a	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c5e	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c60	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c64	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c66	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c68	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c6a	 ${CURDIR}/gcov/test2/addr2line-test2.elf

    Should Match Mapping       0x80000bb6	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000bb8	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000bba	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000bbc	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000bc0	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000bc2	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000bc6	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000bca	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000bcc	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000bd0	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000bd2	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000bd6	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000bd8	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000bda	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000bde	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000be0	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000be4	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000be6	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000bea	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000bee	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000bf0	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000bf2	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000bf6	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000bf8	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000bfc	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c00	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c04	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c06	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c0a	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c0c	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c0e	 ${CURDIR}/gcov/test2/addr2line-test2.elf
    Should Match Mapping       0x80000c10	 ${CURDIR}/gcov/test2/addr2line-test2.elf
