*** Settings ***
Library                       secure_engine_commands.py
Test Setup                    Run Keywords  Renode Test Setup  AND  Create Machine

*** Test Cases ***
Should Generate Random Data
    Random Command Test

Should Encrypt And Decrypt AES ECB
    Aes Ecb Encrypt Decrypt Command Test

Should Accept Both Unprotected Key DMA Layouts For AES
    Aes Unprotected Key Dma Layout Test

Should Encrypt AES CBC
    Aes Cbc Encrypt Command Test

Should Encrypt AES CCM
    Aes Ccm Encrypt Command Test

Should Decrypt AES CCM
    Aes Ccm Decrypt Command Test

Should Encrypt AES CCM In Parts
    Aes Ccm Multipart Encrypt Command Test

Should Decrypt AES CCM In Parts
    Aes Ccm Multipart Decrypt Command Test

Should Encrypt Empty AES CCM Message
    Aes Ccm Empty Message Test

Should Compute HMAC
    Hmac Command Test

Should Compute Hash
    Hash Command Test

Should Compute Hash In Parts
    Hash Multipart Command Test

Should Compute Interleaved Hashes
    Hash Interleaved Test

Should Sign With ECDSA
    Ecdsa Sign Command Test

Should Verify ECDSA Signatures
    Ecdsa Verify Command Test

Should Sign With EdDSA
    Eddsa Sign Command Test

Should Verify EdDSA Signatures
    Eddsa Verify Command Test

Should Import Keys
    Import Key Command Test

Should Export Keys
    Export Key Command Test

Should Create Keys
    Create Key Command Test

Should Delete Keys
    Delete Key Command Test

Should Create, Import And Export A Key
    Key Create Import Export Test

Should Store User Data
    User Data Storage Command Test
