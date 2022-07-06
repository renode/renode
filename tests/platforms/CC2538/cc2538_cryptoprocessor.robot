*** Variables ***
${UART}                       sysbus.uart0
${URI}                        @https://dl.antmicro.com/projects/renode

*** Keywords ***
Create Machine
    [Arguments]  ${elf}

    Execute Command           mach create
    Execute Command           machine LoadPlatformDescription @platforms/cpus/cc2538.repl
    Execute Command           machine PyDevFromFile @scripts/pydev/flipflop.py 0x400D2004 0x4 True
    Execute Command           machine PyDevFromFile @scripts/pydev/flipflop.py 0x400D7000 0x4 True

    Execute Command           sysbus LoadBinary @https://dl.antmicro.com/projects/renode/cc2538_rom_dump.bin-s_524288-0c196cdc21b5397f82e0ff42b206d1cc4b6d7522 0x0
    Execute Command           sysbus LoadELF ${elf}
    Execute Command           sysbus.cpu VectorTableOffset 0x200000

*** Test Cases ***
Should Handle CBC Mode
    Create Machine            ${URI}/cbc-test.elf-s_175305-302d5f0f3348815c3f02b6ba200f0dc36a8ec7c4

    Create Terminal Tester    ${UART}
    Start Emulation

    Wait For Line On Uart     Test vector #0: encrypt
    Wait For Line On Uart     cbc_crypt_start(): success
    Wait For Line On Uart     Output message OK

    Wait For Line On Uart     Test vector #1: encrypt
    Wait For Line On Uart     cbc_crypt_start(): success
    Wait For Line On Uart     Output message OK

    Wait For Line On Uart     Test vector #2: encrypt
    Wait For Line On Uart     cbc_crypt_start(): success
    Wait For Line On Uart     Output message OK

    Wait For Line On Uart     Test vector #3: encrypt
    Wait For Line On Uart     cbc_crypt_start(): success
    Wait For Line On Uart     Output message OK

    Wait For Line On Uart     Test vector #4: decrypt
    Wait For Line On Uart     cbc_crypt_start(): success
    Wait For Line On Uart     Output message OK

    Wait For Line On Uart     Test vector #5: decrypt
    Wait For Line On Uart     cbc_crypt_start(): success
    Wait For Line On Uart     Output message OK

    Wait For Line On Uart     Test vector #6: decrypt
    Wait For Line On Uart     cbc_crypt_start(): success
    Wait For Line On Uart     Output message OK

    Wait For Line On Uart     Test vector #7: decrypt
    Wait For Line On Uart     cbc_crypt_start(): success
    Wait For Line On Uart     Output message OK

    Wait For Line On Uart     Test vector #8: encrypt
    Wait For Line On Uart     cbc_crypt_start(): success
    Wait For Line On Uart     Output message OK

    Wait For Line On Uart     Test vector #9: encrypt
    Wait For Line On Uart     cbc_crypt_start(): success
    Wait For Line On Uart     Output message OK

    Wait For Line On Uart     Test vector #10: decrypt
    Wait For Line On Uart     cbc_crypt_start(): success
    Wait For Line On Uart     Output message OK

    Wait For Line On Uart     Test vector #11: decrypt
    Wait For Line On Uart     cbc_crypt_start(): success
    Wait For Line On Uart     Output message OK

    Wait For Line On Uart     Test vector #12: encrypt
    Wait For Line On Uart     cbc_crypt_start(): success
    Wait For Line On Uart     Output message OK

    Wait For Line On Uart     Test vector #13: encrypt
    Wait For Line On Uart     cbc_crypt_start(): success
    Wait For Line On Uart     Output message OK

    Wait For Line On Uart     Test vector #14: decrypt
    Wait For Line On Uart     cbc_crypt_start(): success
    Wait For Line On Uart     Output message OK

    Wait For Line On Uart     Test vector #15: decrypt
    Wait For Line On Uart     cbc_crypt_start(): success
    Wait For Line On Uart     Output message OK

Should Handle CBC MAC Mode
    Create Machine            ${URI}/cbc-mac-test.elf-s_175341-81f921163a7405a02853560527b9d09388feaacf

    Create Terminal Tester    ${UART}
    Start Emulation

    Wait For Line On Uart     Test vector #0:
    Wait For Line On Uart     cbc_mac_auth_start(): success
    Wait For Line On Uart     cbc_mac_auth_get_result(): success
    Wait For Line On Uart     MAC OK

    Wait For Line On Uart     Test vector #1:
    Wait For Line On Uart     cbc_mac_auth_start(): success
    Wait For Line On Uart     cbc_mac_auth_get_result(): success
    Wait For Line On Uart     MAC OK

    Wait For Line On Uart     Test vector #2:
    Wait For Line On Uart     cbc_mac_auth_start(): success
    Wait For Line On Uart     cbc_mac_auth_get_result(): success
    Wait For Line On Uart     MAC OK

    Wait For Line On Uart     Test vector #3:
    Wait For Line On Uart     cbc_mac_auth_start(): success
    Wait For Line On Uart     cbc_mac_auth_get_result(): success
    Wait For Line On Uart     MAC OK

    Wait For Line On Uart     Test vector #4:
    Wait For Line On Uart     cbc_mac_auth_start(): success
    Wait For Line On Uart     cbc_mac_auth_get_result(): success
    Wait For Line On Uart     MAC OK

    Wait For Line On Uart     Test vector #5:
    Wait For Line On Uart     cbc_mac_auth_start(): success
    Wait For Line On Uart     cbc_mac_auth_get_result(): success
    Wait For Line On Uart     MAC OK

    Wait For Line On Uart     Test vector #6:
    Wait For Line On Uart     cbc_mac_auth_start(): success
    Wait For Line On Uart     cbc_mac_auth_get_result(): success
    Wait For Line On Uart     MAC OK

    Wait For Line On Uart     Test vector #7:
    Wait For Line On Uart     cbc_mac_auth_start(): success
    Wait For Line On Uart     cbc_mac_auth_get_result(): success
    Wait For Line On Uart     MAC OK

    Wait For Line On Uart     Test vector #8:
    Wait For Line On Uart     cbc_mac_auth_start(): success
    Wait For Line On Uart     cbc_mac_auth_get_result(): success
    Wait For Line On Uart     MAC OK

    Wait For Line On Uart     Test vector #9:
    Wait For Line On Uart     cbc_mac_auth_start(): success
    Wait For Line On Uart     cbc_mac_auth_get_result(): success
    Wait For Line On Uart     MAC OK

    Wait For Line On Uart     Test vector #10:
    Wait For Line On Uart     cbc_mac_auth_start(): success
    Wait For Line On Uart     cbc_mac_auth_get_result(): success
    Wait For Line On Uart     MAC OK

    Wait For Line On Uart     Test vector #11:
    Wait For Line On Uart     cbc_mac_auth_start(): success
    Wait For Line On Uart     cbc_mac_auth_get_result(): success
    Wait For Line On Uart     MAC OK

    Wait For Line On Uart     Test vector #12:
    Wait For Line On Uart     cbc_mac_auth_start(): success
    Wait For Line On Uart     cbc_mac_auth_get_result(): success
    Wait For Line On Uart     MAC OK

    Wait For Line On Uart     Test vector #13:
    Wait For Line On Uart     cbc_mac_auth_start(): success
    Wait For Line On Uart     cbc_mac_auth_get_result(): success
    Wait For Line On Uart     MAC OK

    Wait For Line On Uart     Test vector #14:
    Wait For Line On Uart     cbc_mac_auth_start(): success
    Wait For Line On Uart     cbc_mac_auth_get_result(): success
    Wait For Line On Uart     MAC OK

    Wait For Line On Uart     Test vector #15:
    Wait For Line On Uart     cbc_mac_auth_start(): success
    Wait For Line On Uart     cbc_mac_auth_get_result(): success
    Wait For Line On Uart     MAC OK

Should Handle CTR Mode
    Create Machine            ${URI}/ctr-test.elf-s_175305-f32f4ec1a1d9fd1675cfe60f9c3502ceffd92aba

    Create Terminal Tester    ${UART}
    Start Emulation

    Wait For Line On Uart     Test vector #0: encrypt
    Wait For Line On Uart     ctr_crypt_start(): success
    Wait For Line On Uart     Output message OK

    Wait For Line On Uart     Test vector #1: decrypt
    Wait For Line On Uart     ctr_crypt_start(): success
    Wait For Line On Uart     Output message OK

    Wait For Line On Uart     Test vector #2: encrypt
    Wait For Line On Uart     ctr_crypt_start(): success
    Wait For Line On Uart     Output message OK

    Wait For Line On Uart     Test vector #3: decrypt
    Wait For Line On Uart     ctr_crypt_start(): success
    Wait For Line On Uart     Output message OK

    Wait For Line On Uart     Test vector #4: encrypt
    Wait For Line On Uart     ctr_crypt_start(): success
    Wait For Line On Uart     Output message OK

    Wait For Line On Uart     Test vector #5: decrypt
    Wait For Line On Uart     ctr_crypt_start(): success
    Wait For Line On Uart     Output message OK

Should Handle CCM Mode
    Create Machine            ${URI}/ccm-test.elf-s_175602-29d010d3aa0aa587e32cfded335a62da85563ab2

    Create Terminal Tester    ${UART}
    Start Emulation

    Wait For Line On Uart     Test vector #0: encrypt
    Wait For Line On Uart     ccm_auth_encrypt_start(): success
    Wait For Line On Uart     ccm_auth_encrypt_get_result(): success
    Wait For Line On Uart     Encrypted message OK
    Wait For Line On Uart     MIC OK

    Wait For Line On Uart     Test vector #1: encrypt
    Wait For Line On Uart     ccm_auth_encrypt_start(): success
    Wait For Line On Uart     ccm_auth_encrypt_get_result(): success
    Wait For Line On Uart     Encrypted message OK
    Wait For Line On Uart     MIC OK

    Wait For Line On Uart     Test vector #2: encrypt
    Wait For Line On Uart     ccm_auth_encrypt_start(): success
    Wait For Line On Uart     ccm_auth_encrypt_get_result(): success
    Wait For Line On Uart     Encrypted message OK
    Wait For Line On Uart     MIC OK

    Wait For Line On Uart     Test vector #3: decrypt
    Wait For Line On Uart     ccm_auth_decrypt_start(): success
    Wait For Line On Uart     ccm_auth_decrypt_get_result(): success
    Wait For Line On Uart     Decrypted message OK

    Wait For Line On Uart     Test vector #4: decrypt
    Wait For Line On Uart     ccm_auth_decrypt_start(): success
    Wait For Line On Uart     ccm_auth_decrypt_get_result(): success
    Wait For Line On Uart     Decrypted message OK

    Wait For Line On Uart     Test vector #5: decrypt
    Wait For Line On Uart     ccm_auth_decrypt_start(): success
    Wait For Line On Uart     ccm_auth_decrypt_get_result(): success
    Wait For Line On Uart     Decrypted message OK

    Wait For Line On Uart     Test vector #6: encrypt
    Wait For Line On Uart     ccm_auth_encrypt_start(): success
    Wait For Line On Uart     ccm_auth_encrypt_get_result(): success
    Wait For Line On Uart     Encrypted message OK
    Wait For Line On Uart     MIC OK

    Wait For Line On Uart     Test vector #7: encrypt
    Wait For Line On Uart     ccm_auth_encrypt_start(): success
    Wait For Line On Uart     ccm_auth_encrypt_get_result(): success
    Wait For Line On Uart     Encrypted message OK
    Wait For Line On Uart     MIC OK

    Wait For Line On Uart     Test vector #8: encrypt
    Wait For Line On Uart     ccm_auth_encrypt_start(): success
    Wait For Line On Uart     ccm_auth_encrypt_get_result(): success
    Wait For Line On Uart     Encrypted message OK
    Wait For Line On Uart     MIC OK

    Wait For Line On Uart     Test vector #9: encrypt
    Wait For Line On Uart     ccm_auth_encrypt_start(): success
    Wait For Line On Uart     ccm_auth_encrypt_get_result(): success
    Wait For Line On Uart     Encrypted message OK
    Wait For Line On Uart     MIC OK

    Wait For Line On Uart     Test vector #10: decrypt
    Wait For Line On Uart     ccm_auth_decrypt_start(): success
    Wait For Line On Uart     ccm_auth_decrypt_get_result(): success
    Wait For Line On Uart     Decrypted message OK

    Wait For Line On Uart     Test vector #11: decrypt
    Wait For Line On Uart     ccm_auth_decrypt_start(): success
    Wait For Line On Uart     ccm_auth_decrypt_get_result(): success
    Wait For Line On Uart     Decrypted message OK

    Wait For Line On Uart     Test vector #12: decrypt
    Wait For Line On Uart     ccm_auth_decrypt_start(): success
    Wait For Line On Uart     ccm_auth_decrypt_get_result(): success
    Wait For Line On Uart     Decrypted message OK

    Wait For Line On Uart     Test vector #13: decrypt
    Wait For Line On Uart     ccm_auth_decrypt_start(): success
    Wait For Line On Uart     ccm_auth_decrypt_get_result(): success
    Wait For Line On Uart     Decrypted message OK

    Wait For Line On Uart     Test vector #14: encrypt
    Wait For Line On Uart     ccm_auth_encrypt_start(): success
    Wait For Line On Uart     ccm_auth_encrypt_get_result(): success
    Wait For Line On Uart     Encrypted message OK
    Wait For Line On Uart     MIC OK

    Wait For Line On Uart     Test vector #15: encrypt
    Wait For Line On Uart     ccm_auth_encrypt_start(): success
    Wait For Line On Uart     ccm_auth_encrypt_get_result(): success
    Wait For Line On Uart     Encrypted message OK
    Wait For Line On Uart     MIC OK

    Wait For Line On Uart     Test vector #16: encrypt
    Wait For Line On Uart     ccm_auth_encrypt_start(): success
    Wait For Line On Uart     ccm_auth_encrypt_get_result(): success
    Wait For Line On Uart     Encrypted message OK
    Wait For Line On Uart     MIC OK

    Wait For Line On Uart     Test vector #17: encrypt
    Wait For Line On Uart     ccm_auth_encrypt_start(): success
    Wait For Line On Uart     ccm_auth_encrypt_get_result(): success
    Wait For Line On Uart     Encrypted message OK
    Wait For Line On Uart     MIC OK

    Wait For Line On Uart     Test vector #18: decrypt
    Wait For Line On Uart     ccm_auth_decrypt_start(): success
    Wait For Line On Uart     ccm_auth_decrypt_get_result(): success
    Wait For Line On Uart     Decrypted message OK

    Wait For Line On Uart     Test vector #19: decrypt
    Wait For Line On Uart     ccm_auth_decrypt_start(): success
    Wait For Line On Uart     ccm_auth_decrypt_get_result(): success
    Wait For Line On Uart     Decrypted message OK

    Wait For Line On Uart     Test vector #20: decrypt
    Wait For Line On Uart     ccm_auth_decrypt_start(): success
    Wait For Line On Uart     ccm_auth_decrypt_get_result(): success
    Wait For Line On Uart     Decrypted message OK

    Wait For Line On Uart     Test vector #21: decrypt
    Wait For Line On Uart     ccm_auth_decrypt_start(): success
    Wait For Line On Uart     ccm_auth_decrypt_get_result(): success
    Wait For Line On Uart     Decrypted message OK

