*** Test Cases ***
Should Pass clicdirect-01_default
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicdirect-01_default.elf-s_29412-dbbb2982937cb55298959cf2f6f7ecb56dbb9939
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicdirect-01_default.signature-s_648-0b711ebc474bc817cd8d3b422a77d164be74b84d
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicdirect-01_ecall
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicdirect-01_ecall.elf-s_29420-842d178e67c2b90021946281ed87c99ce31862d5
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicdirect-01_ecall.signature-s_648-c449a3510c1ae33b5862316cdc7f9d962aa41008
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicdirect-01_ecall_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicdirect-01_ecall_int1clear.elf-s_29420-d09a68ca7c68ff849ab25604620436aab0573f8c
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicdirect-01_ecall_int1clear.signature-s_648-c449a3510c1ae33b5862316cdc7f9d962aa41008
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicdirect-01_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicdirect-01_int1clear.elf-s_29412-d6790a264f6b8487df53a44ffe662187586e7554
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicdirect-01_int1clear.signature-s_648-0b711ebc474bc817cd8d3b422a77d164be74b84d
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass cliclevel-01_default
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/cliclevel-01_default.elf-s_29380-5ca8775cc7ca2d2fb0efacdd59ba2a58ccce3f0d
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/cliclevel-01_default.signature-s_648-d8f1cb060646aec4409d10650e7167f709459590
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass cliclevel-01_ecall
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/cliclevel-01_ecall.elf-s_29388-2729e8320faf8ebd7209b5f28450a7365ada7d46
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/cliclevel-01_ecall.signature-s_648-37b13cdcdafdf52fa63b464a161aaba06b033c03
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass cliclevel-01_ecall_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/cliclevel-01_ecall_int1clear.elf-s_29388-7067401de5f62e9abec9cad36311676f845db744
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/cliclevel-01_ecall_int1clear.signature-s_648-37b13cdcdafdf52fa63b464a161aaba06b033c03
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass cliclevel-01_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/cliclevel-01_int1clear.elf-s_29380-34a68dafe3c745c7db040f918f0b34eb497d87e1
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/cliclevel-01_int1clear.signature-s_648-d8f1cb060646aec4409d10650e7167f709459590
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass cliclevel-02_default
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/cliclevel-02_default.elf-s_29380-90baece76ac76ad3cd2a4633ff038cd80f12d64b
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/cliclevel-02_default.signature-s_648-86091644b1079d88c7fd33c65498f6a64233198c
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass cliclevel-02_ecall
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/cliclevel-02_ecall.elf-s_29388-2c4e9a968b42c00d56e35bfe00c7c8ba17ea88d8
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/cliclevel-02_ecall.signature-s_648-dcb9ffb1777012aff02120a9ce8df18a44251934
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass cliclevel-02_ecall_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/cliclevel-02_ecall_int1clear.elf-s_29388-7e7edfb8b92c15e1a87c55676fa1a58970336349
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/cliclevel-02_ecall_int1clear.signature-s_648-dcb9ffb1777012aff02120a9ce8df18a44251934
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass cliclevel-02_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/cliclevel-02_int1clear.elf-s_29380-728e8b3ade0cc9da93b4c141fcc1d9fb74f3c84f
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/cliclevel-02_int1clear.signature-s_648-86091644b1079d88c7fd33c65498f6a64233198c
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass cliclevel-03_default
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/cliclevel-03_default.elf-s_29380-d38d8dcfa7c0c238da53a421c89a09e33f2cf1ac
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/cliclevel-03_default.signature-s_648-0b711ebc474bc817cd8d3b422a77d164be74b84d
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass cliclevel-03_ecall
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/cliclevel-03_ecall.elf-s_29388-8b888ccc42f63cf94f35759889bb21723ff26b5b
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/cliclevel-03_ecall.signature-s_648-c449a3510c1ae33b5862316cdc7f9d962aa41008
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass cliclevel-03_ecall_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/cliclevel-03_ecall_int1clear.elf-s_29388-077868cf6b6b8d13179dd0388ea35597b2d62183
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/cliclevel-03_ecall_int1clear.signature-s_648-c449a3510c1ae33b5862316cdc7f9d962aa41008
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass cliclevel-03_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/cliclevel-03_int1clear.elf-s_29380-510a681fdfe3dc8d541ad66618089e1d182c30ab
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/cliclevel-03_int1clear.signature-s_648-0b711ebc474bc817cd8d3b422a77d164be74b84d
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass cliclevel-04_default
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/cliclevel-04_default.elf-s_29380-cc757cefa9be4ff14471afd3b74534f5f0de2457
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/cliclevel-04_default.signature-s_648-69a9256f2ed8c051e2bb579a44ffd05bfb5491fc
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass cliclevel-04_ecall
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/cliclevel-04_ecall.elf-s_29388-ce74b4aedcaf9687a056872e7607ede07eb9cc17
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/cliclevel-04_ecall.signature-s_648-411679a1df0074538eb094a1475f550902f04f4c
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass cliclevel-04_ecall_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/cliclevel-04_ecall_int1clear.elf-s_29388-21ea4e5d84b9645f6a2cd7a7c77b327e93fa819a
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/cliclevel-04_ecall_int1clear.signature-s_648-411679a1df0074538eb094a1475f550902f04f4c
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass cliclevel-04_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/cliclevel-04_int1clear.elf-s_29380-a1ced38c9df400f7e28eb5e23fe305329042ee64
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/cliclevel-04_int1clear.signature-s_648-69a9256f2ed8c051e2bb579a44ffd05bfb5491fc
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicnomint-01_default
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicnomint-01_default.elf-s_29388-530a9b08b6a1bc1a1d3fd953e39199d9aa039d5e
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicnomint-01_default.signature-s_648-0157f2624139eeda5927bc82ad3aedeba2a14c83
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicnomint-01_ecall
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicnomint-01_ecall.elf-s_29396-1a06611472423a50fd022ca760072a79e3b7d600
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicnomint-01_ecall.signature-s_648-0157f2624139eeda5927bc82ad3aedeba2a14c83
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicnomint-01_ecall_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicnomint-01_ecall_int1clear.elf-s_29396-046ff7c095a602a7e20d957bf6421bac745b7eed
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicnomint-01_ecall_int1clear.signature-s_648-0157f2624139eeda5927bc82ad3aedeba2a14c83
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicnomint-01_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicnomint-01_int1clear.elf-s_29388-740ab8c1b4777a95181b906cb427a3ed67f45827
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicnomint-01_int1clear.signature-s_648-0157f2624139eeda5927bc82ad3aedeba2a14c83
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicnomint-02_default
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicnomint-02_default.elf-s_29388-d694ed8a34e8c11a2e11d75493722591f84348b2
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicnomint-02_default.signature-s_648-0157f2624139eeda5927bc82ad3aedeba2a14c83
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicnomint-02_ecall
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicnomint-02_ecall.elf-s_29396-0d2a52e329e464adde35b1dbb4817d1dc9f5312b
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicnomint-02_ecall.signature-s_648-0157f2624139eeda5927bc82ad3aedeba2a14c83
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicnomint-02_ecall_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicnomint-02_ecall_int1clear.elf-s_29396-45029a67ce062e20ebc172ba9a0cab1a7920b30a
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicnomint-02_ecall_int1clear.signature-s_648-0157f2624139eeda5927bc82ad3aedeba2a14c83
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicnomint-02_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicnomint-02_int1clear.elf-s_29388-7b01e8aa463e8e499ef5087d73a77927ebebad2a
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicnomint-02_int1clear.signature-s_648-0157f2624139eeda5927bc82ad3aedeba2a14c83
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicnomint-03_default
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicnomint-03_default.elf-s_29388-4e47a1fd3e4f40e86e1f5d2e086017165ee131aa
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicnomint-03_default.signature-s_648-0157f2624139eeda5927bc82ad3aedeba2a14c83
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicnomint-03_ecall
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicnomint-03_ecall.elf-s_29396-81bf8d62c519eb21b71c2f6bdedabef2c95202b1
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicnomint-03_ecall.signature-s_648-0157f2624139eeda5927bc82ad3aedeba2a14c83
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicnomint-03_ecall_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicnomint-03_ecall_int1clear.elf-s_29396-74d9a5fb438022d091672b38a0d3da5b41d5a95d
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicnomint-03_ecall_int1clear.signature-s_648-0157f2624139eeda5927bc82ad3aedeba2a14c83
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicnomint-03_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicnomint-03_int1clear.elf-s_29388-8fceb2d565ec6a839676643490a419c8fc950294
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicnomint-03_int1clear.signature-s_648-0157f2624139eeda5927bc82ad3aedeba2a14c83
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicshvdirect-01_default
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicshvdirect-01_default.elf-s_29464-6d112a63d345d6b9fac69c5b277531bbc8c5a0a4
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicshvdirect-01_default.signature-s_648-5ea0e23f2975ab21c44cc0fec4d5d8647078b22c
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicshvdirect-01_ecall
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicshvdirect-01_ecall.elf-s_29472-f042887eeaceb10496283bdd56a33c895d5563cd
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicshvdirect-01_ecall.signature-s_648-61b8c6fae5e1385448f5b42912751beeff567957
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicshvdirect-01_ecall_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicshvdirect-01_ecall_int1clear.elf-s_29472-e4ca1f925ee88cda3d79632fc503c0e8de4ed125
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicshvdirect-01_ecall_int1clear.signature-s_648-61b8c6fae5e1385448f5b42912751beeff567957
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicshvdirect-01_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicshvdirect-01_int1clear.elf-s_29464-e82980e694e9c38a5873105ceee2fc17622bac73
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicshvdirect-01_int1clear.signature-s_648-5ea0e23f2975ab21c44cc0fec4d5d8647078b22c
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicshvinhv-01_default
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicshvinhv-01_default.elf-s_29440-7491073aeec299a1c16bc049ace7a1c3bd6716e6
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicshvinhv-01_default.signature-s_648-bcb7144d8c7f4dddea4596a059aa314438c7e93e
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicshvinhv-01_ecall
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicshvinhv-01_ecall.elf-s_29448-b52ee5f03993b3f148200c05670fddff913d6049
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicshvinhv-01_ecall.signature-s_648-bcb7144d8c7f4dddea4596a059aa314438c7e93e
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicshvinhv-01_ecall_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicshvinhv-01_ecall_int1clear.elf-s_29448-5c1bd22906621160e683621f4baf21f108837b5f
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicshvinhv-01_ecall_int1clear.signature-s_648-bcb7144d8c7f4dddea4596a059aa314438c7e93e
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicshvinhv-01_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicshvinhv-01_int1clear.elf-s_29440-5c91f22eaffe3f0aea120d1fa8052d5c8de781c2
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicshvinhv-01_int1clear.signature-s_648-bcb7144d8c7f4dddea4596a059aa314438c7e93e
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-01_default
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicshvlevel-01_default.elf-s_29432-f3f100e9be449f06be7972bc044b0fbf9f985dac
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicshvlevel-01_default.signature-s_648-48899cf93a59d3536f205ed9b18b3111af3a510a
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-01_ecall
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicshvlevel-01_ecall.elf-s_29440-4c9e71632866e89e211ebf83b9d01fa1807e1a26
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicshvlevel-01_ecall.signature-s_648-38b238efcdaefba16447708251a77fdfeca3c40d
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-01_ecall_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicshvlevel-01_ecall_int1clear.elf-s_29440-0e804f159bd5d0e861fe86422b9dcde1b4eeffd8
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicshvlevel-01_ecall_int1clear.signature-s_648-38b238efcdaefba16447708251a77fdfeca3c40d
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-01_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicshvlevel-01_int1clear.elf-s_29432-acb499fe577dd4ea4f2a2b186c4fb7fc98f121ea
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicshvlevel-01_int1clear.signature-s_648-48899cf93a59d3536f205ed9b18b3111af3a510a
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-02_default
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicshvlevel-02_default.elf-s_29432-3a58db993b4bcb7e1f67855d040ab46fea9deeeb
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicshvlevel-02_default.signature-s_648-c4d6415480ea2ecf98cad38f499712b75d6485cc
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-02_ecall
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicshvlevel-02_ecall.elf-s_29440-09e0dbf635f0f8a6e0284856a9166883824b72b7
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicshvlevel-02_ecall.signature-s_648-8a9eb4d8ade2f59a8c83b6f2956c8b3a3073bdb4
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-02_ecall_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicshvlevel-02_ecall_int1clear.elf-s_29440-01755077cca66d7f5b6e2e401098022f775f418a
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicshvlevel-02_ecall_int1clear.signature-s_648-8a9eb4d8ade2f59a8c83b6f2956c8b3a3073bdb4
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-02_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicshvlevel-02_int1clear.elf-s_29432-cc79deeb53874ccd98793e0399147cbc7918f038
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicshvlevel-02_int1clear.signature-s_648-c4d6415480ea2ecf98cad38f499712b75d6485cc
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-03_default
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicshvlevel-03_default.elf-s_29432-eff9f60f140a80b8501594c3b9d52a409e071cbf
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicshvlevel-03_default.signature-s_648-5ea0e23f2975ab21c44cc0fec4d5d8647078b22c
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-03_ecall
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicshvlevel-03_ecall.elf-s_29440-19903920835be18908d3ae4b4a9832144e1376f6
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicshvlevel-03_ecall.signature-s_648-61b8c6fae5e1385448f5b42912751beeff567957
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-03_ecall_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicshvlevel-03_ecall_int1clear.elf-s_29440-4125dff5d7ec1d7bcd7d0cc0216322fac01ef70f
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicshvlevel-03_ecall_int1clear.signature-s_648-61b8c6fae5e1385448f5b42912751beeff567957
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-03_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicshvlevel-03_int1clear.elf-s_29432-c6f88ab25beebdef994d9c31539f8e7c2f4f2470
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicshvlevel-03_int1clear.signature-s_648-5ea0e23f2975ab21c44cc0fec4d5d8647078b22c
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-04_default
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicshvlevel-04_default.elf-s_29432-d30ca51f4e2345abf57c239e7665f98ae62557c9
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicshvlevel-04_default.signature-s_648-e25e6a4565ea49a962c30c4c3009956627c06ae5
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-04_ecall
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicshvlevel-04_ecall.elf-s_29440-8ec0eb2b7e709e1e7298cb341d1c5df898a6e7db
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicshvlevel-04_ecall.signature-s_648-50ab5fc4c571a401a1cd11c3eb5e8342a4b19337
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-04_ecall_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicshvlevel-04_ecall_int1clear.elf-s_29440-a56283892c37e87b5a5bca87a9d6381ee81a07f7
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicshvlevel-04_ecall_int1clear.signature-s_648-50ab5fc4c571a401a1cd11c3eb5e8342a4b19337
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-04_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicshvlevel-04_int1clear.elf-s_29432-ab095084793f0a5bbf62a6fb436744e2c01bfb30
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicshvlevel-04_int1clear.signature-s_648-e25e6a4565ea49a962c30c4c3009956627c06ae5
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-05_default
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicshvlevel-05_default.elf-s_29432-7553ac14c4059b7a2f267d39b953f36a24dc7dc6
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicshvlevel-05_default.signature-s_648-505084bdafa77771bb9a41f239d4f4f487acfb65
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-05_ecall
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicshvlevel-05_ecall.elf-s_29440-9e7685c26490f73a39dc5e69e2748669b75130b4
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicshvlevel-05_ecall.signature-s_648-4d34491f850857712184af380462b76b5b7ae0a5
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-05_ecall_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicshvlevel-05_ecall_int1clear.elf-s_29440-1c2026535903474739f06138fd205cf3251723d3
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicshvlevel-05_ecall_int1clear.signature-s_648-4d34491f850857712184af380462b76b5b7ae0a5
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-05_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicshvlevel-05_int1clear.elf-s_29432-6ed1c0871434ee93fa7723aea7bfa4ea609ec6cb
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicshvlevel-05_int1clear.signature-s_648-505084bdafa77771bb9a41f239d4f4f487acfb65
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-06_default
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicshvlevel-06_default.elf-s_29432-63fad3e68717b04b17b94b6615f5ddf2efb5d235
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicshvlevel-06_default.signature-s_648-2a3fd9608b4d150f0ddf7816061f4f4caf4622ea
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-06_ecall
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicshvlevel-06_ecall.elf-s_29440-0cae4b41077269fcd013d555147224c5ac8bcbf6
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicshvlevel-06_ecall.signature-s_648-de1a132fa56bf1ca8f4e1efdd262c09258644c92
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-06_ecall_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicshvlevel-06_ecall_int1clear.elf-s_29440-4384c09a697ddab9153d0ae3850dd5b0b5681e48
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicshvlevel-06_ecall_int1clear.signature-s_648-de1a132fa56bf1ca8f4e1efdd262c09258644c92
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-06_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicshvlevel-06_int1clear.elf-s_29432-613cdfe59ca77a890fe48e23afcd88290161fc94
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicshvlevel-06_int1clear.signature-s_648-2a3fd9608b4d150f0ddf7816061f4f4caf4622ea
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-07_default
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicshvlevel-07_default.elf-s_29432-fa657514736d38896b7a94c099aa108b121e31b6
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicshvlevel-07_default.signature-s_648-0b711ebc474bc817cd8d3b422a77d164be74b84d
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-07_ecall
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicshvlevel-07_ecall.elf-s_29440-e88d6a093831732d0403650f61edb2ea3c30902d
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicshvlevel-07_ecall.signature-s_648-c449a3510c1ae33b5862316cdc7f9d962aa41008
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-07_ecall_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicshvlevel-07_ecall_int1clear.elf-s_29440-6e45439188fa53b78d63c25348b2c79bcac04a69
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicshvlevel-07_ecall_int1clear.signature-s_648-c449a3510c1ae33b5862316cdc7f9d962aa41008
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-07_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicshvlevel-07_int1clear.elf-s_29432-ed70c228feed1bfac07451c009d4e4b7b55b3bbc
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicshvlevel-07_int1clear.signature-s_648-0b711ebc474bc817cd8d3b422a77d164be74b84d
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-08_default
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicshvlevel-08_default.elf-s_29432-3a96d00b2ef983d69f7e6f7c562910d38a43e89e
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicshvlevel-08_default.signature-s_648-69a9256f2ed8c051e2bb579a44ffd05bfb5491fc
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-08_ecall
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicshvlevel-08_ecall.elf-s_29440-fa216883b5dadc93626f0c21735ba66816f89a3d
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicshvlevel-08_ecall.signature-s_648-411679a1df0074538eb094a1475f550902f04f4c
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-08_ecall_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicshvlevel-08_ecall_int1clear.elf-s_29440-daf079e7ab7bdf43df3792add5e7a1b83ffaf31c
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicshvlevel-08_ecall_int1clear.signature-s_648-411679a1df0074538eb094a1475f550902f04f4c
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-08_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicshvlevel-08_int1clear.elf-s_29432-82d106ef072992c0006c754bd5cab94ee3fcc085
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicshvlevel-08_int1clear.signature-s_648-69a9256f2ed8c051e2bb579a44ffd05bfb5491fc
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-09_default
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicshvlevel-09_default.elf-s_29432-360eee66d4e9f4e5c72cf430d144dfa1f4012989
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicshvlevel-09_default.signature-s_648-d1d1ca02e5c998ee94e1fe95b5a30ab6891f87a6
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-09_ecall
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicshvlevel-09_ecall.elf-s_29440-541a542c76baa4ae16838e2a9debd2569659382d
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicshvlevel-09_ecall.signature-s_648-2dbd81ddb46c8ca5173b30fc244a13ecdb232279
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-09_ecall_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicshvlevel-09_ecall_int1clear.elf-s_29440-306d2e716bf2c071ec056d5bf77005bb99dd67f9
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicshvlevel-09_ecall_int1clear.signature-s_648-2dbd81ddb46c8ca5173b30fc244a13ecdb232279
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicshvlevel-09_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicshvlevel-09_int1clear.elf-s_29432-1f0b5748551602f67a9d444887dc8317cf53d873
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicshvlevel-09_int1clear.signature-s_648-d1d1ca02e5c998ee94e1fe95b5a30ab6891f87a6
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicwfi-01_default
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicwfi-01_default.elf-s_29384-88444dd593808e5c62817b640798cf7728b0c927
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicwfi-01_default.signature-s_648-0157f2624139eeda5927bc82ad3aedeba2a14c83
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicwfi-01_ecall
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicwfi-01_ecall.elf-s_29384-1f99a7d865688e9027664b55762eeb99a7f128c7
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicwfi-01_ecall.signature-s_648-0157f2624139eeda5927bc82ad3aedeba2a14c83
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicwfi-01_ecall_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicwfi-01_ecall_int1clear.elf-s_29384-549ac379c3dffe4de26cb031119ab80fb6978fd7
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicwfi-01_ecall_int1clear.signature-s_648-0157f2624139eeda5927bc82ad3aedeba2a14c83
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass clicwfi-01_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/clicwfi-01_int1clear.elf-s_29384-9c149c2aa450536412878ed9b4a6d192da9a9672
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/clicwfi-01_int1clear.signature-s_648-0157f2624139eeda5927bc82ad3aedeba2a14c83
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicdeleg-01_default
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicdeleg-01_default.elf-s_30736-5954996b5444fffa1d5dd6f16f333060e0682677
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicdeleg-01_default.signature-s_936-14dc18bc3f8abb4012871c0a69e54a03403c2c3d
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicdeleg-01_ecall
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicdeleg-01_ecall.elf-s_30736-00da71e6976c379544af8e067bc7e94d1cb5efe0
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicdeleg-01_ecall.signature-s_936-14dc18bc3f8abb4012871c0a69e54a03403c2c3d
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicdeleg-01_ecall_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicdeleg-01_ecall_int1clear.elf-s_30736-eb1ebe2029b9f0aac39c0e11c5f8cb776539873b
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicdeleg-01_ecall_int1clear.signature-s_936-14dc18bc3f8abb4012871c0a69e54a03403c2c3d
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicdeleg-01_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicdeleg-01_int1clear.elf-s_30736-c25b15d3df01b289d3db822366eb49f3741297ef
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicdeleg-01_int1clear.signature-s_936-14dc18bc3f8abb4012871c0a69e54a03403c2c3d
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicmdisable-01_default
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicmdisable-01_default.elf-s_30732-6b8149d940822c2b173f2b92a813223d3c282b69
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicmdisable-01_default.signature-s_936-5b7d95e995a002cb0d108ec0e08d1def9fd1ca39
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicmdisable-01_ecall
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicmdisable-01_ecall.elf-s_30732-82dd443bd3a143fb38686d21a7d5144306c620cd
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicmdisable-01_ecall.signature-s_936-5b7d95e995a002cb0d108ec0e08d1def9fd1ca39
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicmdisable-01_ecall_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicmdisable-01_ecall_int1clear.elf-s_30732-8a159a59f7e7266aed8f67d62ad426268f58b26e
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicmdisable-01_ecall_int1clear.signature-s_936-5b7d95e995a002cb0d108ec0e08d1def9fd1ca39
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicmdisable-01_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicmdisable-01_int1clear.elf-s_30732-2599252333f757aef5ab155c6eaf89b6a986a447
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicmdisable-01_int1clear.signature-s_936-5b7d95e995a002cb0d108ec0e08d1def9fd1ca39
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicmdisable-02_default
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicmdisable-02_default.elf-s_30732-739952b263107eb0705954da005a59b47c167a6b
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicmdisable-02_default.signature-s_936-cd49903fab137ad4bcf96e34d942324e2f7bacdf
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicmdisable-02_ecall
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicmdisable-02_ecall.elf-s_30732-18fdc3e7efa38fca14f095a0f061193b37c9ce09
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicmdisable-02_ecall.signature-s_936-cd49903fab137ad4bcf96e34d942324e2f7bacdf
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicmdisable-02_ecall_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicmdisable-02_ecall_int1clear.elf-s_30732-644b5d789ee2ce348368b93f3abd5b6b72408820
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicmdisable-02_ecall_int1clear.signature-s_936-cd49903fab137ad4bcf96e34d942324e2f7bacdf
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicmdisable-02_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicmdisable-02_int1clear.elf-s_30732-7be54f635be05e459eeab515e837ee4afaff2075
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicmdisable-02_int1clear.signature-s_936-cd49903fab137ad4bcf96e34d942324e2f7bacdf
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicmdisable-03_default
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicmdisable-03_default.elf-s_30732-6a07eb0857ee34b6b11e258373b4b6bf18a5354c
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicmdisable-03_default.signature-s_936-cd49903fab137ad4bcf96e34d942324e2f7bacdf
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicmdisable-03_ecall
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicmdisable-03_ecall.elf-s_30732-16a1900f9b8dfe0bd82cffdc384984a3620036ea
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicmdisable-03_ecall.signature-s_936-cd49903fab137ad4bcf96e34d942324e2f7bacdf
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicmdisable-03_ecall_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicmdisable-03_ecall_int1clear.elf-s_30732-4e7a2a3279a9391c4b18beb41135996f5df63460
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicmdisable-03_ecall_int1clear.signature-s_936-cd49903fab137ad4bcf96e34d942324e2f7bacdf
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicmdisable-03_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicmdisable-03_int1clear.elf-s_30732-a5319c662d0327e75259785173c7468c2ff4e5fd
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicmdisable-03_int1clear.signature-s_936-cd49903fab137ad4bcf96e34d942324e2f7bacdf
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicnodeleg-01_default
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicnodeleg-01_default.elf-s_30736-ab373f20e18afddecac29c651cd56746aaca863b
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicnodeleg-01_default.signature-s_936-942adc948772685bfb8f6a5efcfca93dac18e0a5
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicnodeleg-01_ecall
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicnodeleg-01_ecall.elf-s_30736-fcdb2927d41c00a92ec486e8ccae917839082096
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicnodeleg-01_ecall.signature-s_936-942adc948772685bfb8f6a5efcfca93dac18e0a5
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicnodeleg-01_ecall_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicnodeleg-01_ecall_int1clear.elf-s_30736-4cce9704a226e7500ce9a729a0e12c7b81d463e7
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicnodeleg-01_ecall_int1clear.signature-s_936-942adc948772685bfb8f6a5efcfca93dac18e0a5
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicnodeleg-01_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicnodeleg-01_int1clear.elf-s_30736-7c3e355719e7f0f45413253f3e3baadf36e632ff
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicnodeleg-01_int1clear.signature-s_936-942adc948772685bfb8f6a5efcfca93dac18e0a5
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicorder-01_default
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicorder-01_default.elf-s_30744-fb775eb2d42f5c7a0c81055ba54f7de6346b6349
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicorder-01_default.signature-s_936-14dc18bc3f8abb4012871c0a69e54a03403c2c3d
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicorder-01_ecall
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicorder-01_ecall.elf-s_30744-ee5dcca7c79cba21b609268f3d77a73627e5a353
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicorder-01_ecall.signature-s_936-14dc18bc3f8abb4012871c0a69e54a03403c2c3d
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicorder-01_ecall_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicorder-01_ecall_int1clear.elf-s_30744-4cb404b5be2a1062f0d895ed4e629b5629d91ec8
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicorder-01_ecall_int1clear.signature-s_936-14dc18bc3f8abb4012871c0a69e54a03403c2c3d
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicorder-01_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicorder-01_int1clear.elf-s_30744-a9193867fce12df74c0cc3a341420d5b3da868da
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicorder-01_int1clear.signature-s_936-14dc18bc3f8abb4012871c0a69e54a03403c2c3d
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicorder-02_default
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicorder-02_default.elf-s_30736-29c79cca5ee9316bfdc3d454f1451094158eba10
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicorder-02_default.signature-s_936-17bc8b95b8bd1d6ec1e1036bdd8c9276d428e624
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicorder-02_ecall
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicorder-02_ecall.elf-s_30736-372f70e20efaac91295c324de4b6d035f534a4dd
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicorder-02_ecall.signature-s_936-17bc8b95b8bd1d6ec1e1036bdd8c9276d428e624
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicorder-02_ecall_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicorder-02_ecall_int1clear.elf-s_30736-d1142eeb7e8e44f2ab1a11b0b0d47967b8eb3c1d
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicorder-02_ecall_int1clear.signature-s_936-17bc8b95b8bd1d6ec1e1036bdd8c9276d428e624
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicorder-02_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicorder-02_int1clear.elf-s_30736-49a9a3a707d691c74169c7cf9f94d4a1116b147f
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicorder-02_int1clear.signature-s_936-17bc8b95b8bd1d6ec1e1036bdd8c9276d428e624
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicorder-03_default
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicorder-03_default.elf-s_30736-e4463d902fd5411c60ac0bccffeaa4ce0b31da9f
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicorder-03_default.signature-s_936-14dc18bc3f8abb4012871c0a69e54a03403c2c3d
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicorder-03_ecall
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicorder-03_ecall.elf-s_30736-6810385ef668cc64edb5e4c78914c06fda33408f
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicorder-03_ecall.signature-s_936-14dc18bc3f8abb4012871c0a69e54a03403c2c3d
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicorder-03_ecall_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicorder-03_ecall_int1clear.elf-s_30736-ad3b8459c26ffef9312af80da3e1da2b94f2e152
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicorder-03_ecall_int1clear.signature-s_936-14dc18bc3f8abb4012871c0a69e54a03403c2c3d
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicorder-03_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicorder-03_int1clear.elf-s_30736-db51a9606eb8b2732e46090257b778136989479d
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicorder-03_int1clear.signature-s_936-14dc18bc3f8abb4012871c0a69e54a03403c2c3d
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicorder-04_default
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicorder-04_default.elf-s_30736-4d08db5e4e948f6af2af890eb66077e164ec6778
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicorder-04_default.signature-s_936-35cd433f206b6bb0a4378d321f8e015ef34297fc
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicorder-04_ecall
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicorder-04_ecall.elf-s_30736-a165ef02f92572a2464d601848725185747f1b29
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicorder-04_ecall.signature-s_936-35cd433f206b6bb0a4378d321f8e015ef34297fc
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicorder-04_ecall_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicorder-04_ecall_int1clear.elf-s_30736-069cee7d1f5dde4d16b4c0f377e11628e9ee2688
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicorder-04_ecall_int1clear.signature-s_936-35cd433f206b6bb0a4378d321f8e015ef34297fc
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicorder-04_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicorder-04_int1clear.elf-s_30736-94dfe296b7df79ff9d44ff2346df2ddeda15423c
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicorder-04_int1clear.signature-s_936-35cd433f206b6bb0a4378d321f8e015ef34297fc
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicprivorder-01_default
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicprivorder-01_default.elf-s_30756-53114142cc4d2a56879f765a473aaf1d046503d7
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicprivorder-01_default.signature-s_936-dee062173d54315872a772331cb31dbf790570f1
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicprivorder-01_ecall
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicprivorder-01_ecall.elf-s_30756-50ca226401ca4c3a8ac38bc952e72799a74ae4e7
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicprivorder-01_ecall.signature-s_936-dee062173d54315872a772331cb31dbf790570f1
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicprivorder-01_ecall_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicprivorder-01_ecall_int1clear.elf-s_30756-9c12b968ee1487c41f79eabfd6be19e1014b6b1b
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicprivorder-01_ecall_int1clear.signature-s_936-dee062173d54315872a772331cb31dbf790570f1
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicprivorder-01_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicprivorder-01_int1clear.elf-s_30756-4f2e5a2dd4af8a6536e64029a8dfb8c1e3794d61
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicprivorder-01_int1clear.signature-s_936-dee062173d54315872a772331cb31dbf790570f1
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicprivorder-02_default
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicprivorder-02_default.elf-s_30756-2de7ad9dc3f23faeb060a95999ce35df8948a790
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicprivorder-02_default.signature-s_936-c31ff51610d169f81ba7289d6ada0e61d01ef8dc
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicprivorder-02_ecall
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicprivorder-02_ecall.elf-s_30756-f64ad0bb782fa3854a7b16f148b4103316f9d996
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicprivorder-02_ecall.signature-s_936-c31ff51610d169f81ba7289d6ada0e61d01ef8dc
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicprivorder-02_ecall_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicprivorder-02_ecall_int1clear.elf-s_30756-7fe3926ad75401ae708f83f1be24f4873751987f
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicprivorder-02_ecall_int1clear.signature-s_936-c31ff51610d169f81ba7289d6ada0e61d01ef8dc
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicprivorder-02_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicprivorder-02_int1clear.elf-s_30756-c292529f7c2d894337d794f38cc54efa6449cafa
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicprivorder-02_int1clear.signature-s_936-c31ff51610d169f81ba7289d6ada0e61d01ef8dc
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicprivorder-03_default
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicprivorder-03_default.elf-s_30756-ad4935bd0a1345353b61281b6d71b685368cb795
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicprivorder-03_default.signature-s_936-dee062173d54315872a772331cb31dbf790570f1
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicprivorder-03_ecall
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicprivorder-03_ecall.elf-s_30756-decfeba9a31c12469ab63ad6350b14bfca423498
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicprivorder-03_ecall.signature-s_936-dee062173d54315872a772331cb31dbf790570f1
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicprivorder-03_ecall_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicprivorder-03_ecall_int1clear.elf-s_30756-6b3a6fe8a7fc7986f31b48e88509f06b299dd86c
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicprivorder-03_ecall_int1clear.signature-s_936-dee062173d54315872a772331cb31dbf790570f1
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicprivorder-03_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicprivorder-03_int1clear.elf-s_30756-d0a8e708b7f228d5b28f53cc5f0293b750aa49cf
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicprivorder-03_int1clear.signature-s_936-dee062173d54315872a772331cb31dbf790570f1
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicsdisable-01_default
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicsdisable-01_default.elf-s_30740-7c7e6cfbe0fce38bf8147affd0ac038534a97ba3
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicsdisable-01_default.signature-s_936-0b5665af7b3fc9f272ca3baeee66cadefe25ba19
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicsdisable-01_ecall
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicsdisable-01_ecall.elf-s_30740-55db196d1f07ba881e97a4386266d71174cffd1e
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicsdisable-01_ecall.signature-s_936-0b5665af7b3fc9f272ca3baeee66cadefe25ba19
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicsdisable-01_ecall_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicsdisable-01_ecall_int1clear.elf-s_30740-08d26025d318fe88aa46c77122f0ca6e15240a1a
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicsdisable-01_ecall_int1clear.signature-s_936-0b5665af7b3fc9f272ca3baeee66cadefe25ba19
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicsdisable-01_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicsdisable-01_int1clear.elf-s_30740-66bd40c7ee623c495cb544fceea0a3d5a474c14d
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicsdisable-01_int1clear.signature-s_936-0b5665af7b3fc9f272ca3baeee66cadefe25ba19
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicsdisable-02_default
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicsdisable-02_default.elf-s_30740-de2b586cd7004cc2670bb5587180c9b0326c95d1
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicsdisable-02_default.signature-s_936-11eeccb34c8d1d35499a7ec049dead98e8495bfc
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicsdisable-02_ecall
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicsdisable-02_ecall.elf-s_30740-998a72da2f9b590f022794fddb6df07db32f0ba5
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicsdisable-02_ecall.signature-s_936-11eeccb34c8d1d35499a7ec049dead98e8495bfc
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicsdisable-02_ecall_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicsdisable-02_ecall_int1clear.elf-s_30740-3a5b455c8124c040fc9f87c16d0e9cbe23103ee3
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicsdisable-02_ecall_int1clear.signature-s_936-11eeccb34c8d1d35499a7ec049dead98e8495bfc
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicsdisable-02_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicsdisable-02_int1clear.elf-s_30740-10ea92838a7802648633f5fa6065c246b03cd22a
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicsdisable-02_int1clear.signature-s_936-11eeccb34c8d1d35499a7ec049dead98e8495bfc
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicsdisable-03_default
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicsdisable-03_default.elf-s_30732-a4ed85eab2e0c643c21a229d494243b5756747af
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicsdisable-03_default.signature-s_936-5b7d95e995a002cb0d108ec0e08d1def9fd1ca39
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicsdisable-03_ecall
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicsdisable-03_ecall.elf-s_30732-d4a37ce1e71028074595a2e69539951af8ec2397
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicsdisable-03_ecall.signature-s_936-5b7d95e995a002cb0d108ec0e08d1def9fd1ca39
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicsdisable-03_ecall_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicsdisable-03_ecall_int1clear.elf-s_30732-96daf2fd9286ba01b89289009cc4c8d2ab2a5ecb
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicsdisable-03_ecall_int1clear.signature-s_936-5b7d95e995a002cb0d108ec0e08d1def9fd1ca39
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicsdisable-03_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicsdisable-03_int1clear.elf-s_30732-3ee25d8425d5585c345d12457d4cac4eb12f696f
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicsdisable-03_int1clear.signature-s_936-5b7d95e995a002cb0d108ec0e08d1def9fd1ca39
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicwfi-01_default
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicwfi-01_default.elf-s_30724-cc51662ad5a4d9735ccc899f6f00194194ec9e25
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicwfi-01_default.signature-s_936-11eeccb34c8d1d35499a7ec049dead98e8495bfc
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicwfi-01_ecall
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicwfi-01_ecall.elf-s_30724-d89380f87d13185b7c82d64ccb530ca3fa99bf2b
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicwfi-01_ecall.signature-s_936-11eeccb34c8d1d35499a7ec049dead98e8495bfc
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicwfi-01_ecall_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicwfi-01_ecall_int1clear.elf-s_30724-73dd23e011a402e2801fd8208fc4d2fe350b92ca
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicwfi-01_ecall_int1clear.signature-s_936-11eeccb34c8d1d35499a7ec049dead98e8495bfc
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct

Should Pass sclicwfi-01_int1clear
    Execute Command                 set example_elf @https://dl.antmicro.com/projects/renode/clic/sclicwfi-01_int1clear.elf-s_30724-a0759dfdc4057072faf6e6d8cde05452479f77bc
    ${EXAMPLE_SIG}=                 Download File    https://dl.antmicro.com/projects/renode/clic/sclicwfi-01_int1clear.signature-s_936-11eeccb34c8d1d35499a7ec049dead98e8495bfc
    Execute Command                 set example_sig @${EXAMPLE_SIG}
    Execute Script                  tests/peripherals/CLIC/CLIC-test-setup.resc
    Create Log Tester               1

    Wait For Log Entry              All signatures correct


