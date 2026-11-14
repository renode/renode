*** Settings ***
Library                       SYMCRYPTO_1.py
Test Setup                    Run Keywords  Renode Test Setup  AND  Create Machine

*** Test Cases ***
Should Encrypt And Decrypt AES ECB
    Aes Ecb Test

Should Encrypt And Decrypt AES CTR
    Aes Ctr Test

Should Compute AES CMAC
    Aes Cmac Test

Should Encrypt AES GCM
    Aes Gcm Encrypt Test

Should Decrypt AES GCM
    Aes Gcm Decrypt Test

Should Encrypt AES CCM In One Shot
    Aes Ccm Oneshot Encrypt Test

Should Decrypt AES CCM In One Shot
    Aes Ccm Oneshot Decrypt Test

Should Encrypt AES CCM In Parts
    Aes Ccm Multipart Encrypt Test

Should Decrypt AES CCM In Parts
    Aes Ccm Multipart Decrypt Test

Should Detect AES CCM Tag Mismatch In Parts
    Aes Ccm Multipart Decrypt Tag Mismatch Test

Should Compute SHA-256
    Sha256 Test

Should Compute HMAC SHA-256
    Hmac Sha256 Test
