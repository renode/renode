import test_lib
from typing import List, Optional, Sequence, Tuple

################################################
# Globals
################################################

DEBUG = True

SCRATCH_SRAM_BASE = 0x20000000
SCRATCH_SRAM_SIZE = 0x10000
SEGMENT_SIZE = 0x200
MAX_SEGMENTS = SCRATCH_SRAM_SIZE // SEGMENT_SIZE
segment_index = 0

SYMCRYPTO_BASE_SIZE = 0x1000

REPL_STRING = f"""\
symcrypto: Miscellaneous.SiLabs.SiLabs_SYMCRYPTO_1 @ sysbus <0x41000000, +{SYMCRYPTO_BASE_SIZE:#x}>
scratch: Memory.MappedMemory @ sysbus {SCRATCH_SRAM_BASE:#x}
    size: {SCRATCH_SRAM_SIZE:#x}
"""

# Register offsets (Registers enum in SiLabs_SYMCRYPTO_1.cs)
REG_FETCHER_ADDRESS = 0x000
REG_PUSHER_ADDRESS = 0x010
REG_CONTROL = 0x034
REG_COMMAND = 0x038

CONTROL_FETCHER_SG = 1 << 0
CONTROL_PUSHER_SG = 1 << 1
COMMAND_START_FETCHER = 1 << 0

LENGTH_DISCARD = 1 << 30
DESC_LAST = 1

ENGINE_AES = 0x1
ENGINE_HASH = 0x3
TAG_CONFIG = 1 << 4
TAG_LAST = 1 << 5
TAG_HEADER = 1 << 6
TAG_HMAC_KEY = 2 << 6

TAG_CFG = ENGINE_AES | TAG_CONFIG | (0x00 << 8)
TAG_KEY = ENGINE_AES | TAG_CONFIG | (0x08 << 8)
TAG_IV = ENGINE_AES | TAG_CONFIG | (0x28 << 8)
TAG_AAD = ENGINE_AES | TAG_HEADER
TAG_PAYLOAD = ENGINE_AES
TAG_HASH_CFG = ENGINE_HASH | TAG_CONFIG | (0x00 << 8)
TAG_HASH_MSG = ENGINE_HASH
TAG_HASH_HMAC_KEY = ENGINE_HASH | TAG_HMAC_KEY

# BA411 mode field lives in cfg bits [16:8] (AesMode enum in SiLabs_SYMCRYPTO_1.cs)
AES_CFG_ECB = 1 << 8
AES_CFG_CTR = 1 << 10
AES_CFG_CCM = 1 << 13
AES_CFG_GCM = 1 << 14
AES_CFG_CMAC = 1 << 16
AES_CFG_DECRYPT = 1 << 0
AES_CFG_CX_LOAD = 1 << 4
AES_CFG_CX_SAVE = 1 << 5

# Hash config: Data[0]=HashMode, Data[1] bits hmac/padding/hashFinal
HASH_MODE_SHA256 = 0x08
HASH_CFG_HMAC = 1 << 0
HASH_CFG_PADDING = 1 << 1
HASH_CFG_FINAL = 1 << 2

CCM_CONTEXT_SIZE = 32

################################################
# ZigBee spec annex C vectors
################################################

ZB_KEY = "c0c1c2c3c4c5c6c7c8c9cacbcccdcecf"
ZB_NONCE = "a0a1a2a3a4a5a6a70302010006"
ZB_AAD = "0001020304050607"
ZB_PLAINTEXT = "08090a0b0c0d0e0f101112131415161718191a1b1c1d1e"
ZB_CIPHERTEXT = "1a55a36abb6c610d066b3375649cef10d4664ecad854a8"
ZB_TAG = "0a895cc1d8ff9469"

# AES-ECB / CTR / CMAC / GCM
ECB_PLAINTEXT = "00112233445566778899aabbccddeeff"
ECB_KEY_128 = "000102030405060708090a0b0c0d0e0f"
ECB_KEY_256 = "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"
ECB_CIPHERTEXT_128 = "69c4e0d86a7b0430d8cdb78070b4c55a"
ECB_CIPHERTEXT_256 = "8ea2b7ca516745bfeafc49904b496089"
CTR_CIPHERTEXT_128 = "c6b01904c3da3df5e7d62bd96d153686"
CTR_CIPHERTEXT_256 = "f28122856e1cf9a7216a30d111f3997f"
CTR_IV = "00000000000000000000000000000000"
CMAC_KEY_128 = "2b7e151628aed2a6abf7158809cf4f3c"
CMAC_PLAINTEXT = "6bc1bee22e409f96e93d7e117393172a"
CMAC_TAG_128 = "070a16b46b4d4144f79bdd9dd04a287c"
GCM_KEY = "feffe9928665731c6d6a8f9467308308"
GCM_NONCE = "cafebabefacedbaddecaf888"
GCM_AAD = "feedfacedeadbeeffeedfacedeadbeefabaddad2"
GCM_PLAINTEXT = (
    "d9313225f88406e5a55909c5aff5269a"
    "86a7a9531534f7da2e4c303d8a318a72"
    "1c3c0c95956809532fcf0e2449a6b525"
    "b16aedf5aa0de657ba637b39"
)
GCM_CIPHERTEXT = (
    "42831ec2217774244b7221b784d0d49c"
    "e3aa212f2c02a4e035c17e2329aca12e"
    "21d514b25466931c7d8f6a5aac84aa05"
    "1ba30b396a0aac973d58e091"
)
GCM_TAG = "5bc94fbc3221a5db94fae95ae7121a47"

# NIST CAVS SHA-256 ("abc") and RFC 4231 HMAC-SHA256 test case 2
SHA256_ABC = "616263"
SHA256_ABC_DIGEST = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
HMAC_SHA256_KEY = "4a656665"  # "Jefe"
HMAC_SHA256_MSG = "7768617420646f2079612077616e7420666f72206e6f7468696e673f"
HMAC_SHA256_DIGEST = "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843"

################################################
# Scratch allocator / descriptor packing
################################################

def reset_segment_index() -> None:
    global segment_index
    segment_index = 0

def get_segment(move_index: bool = True) -> int:
    global segment_index
    assert segment_index < MAX_SEGMENTS, "Out of segments"
    addr = SCRATCH_SRAM_BASE + segment_index * SEGMENT_SIZE
    if move_index:
        segment_index += 1
    return addr

def hex_to_byte_list(hex_digits: str) -> List[int]:
    assert isinstance(hex_digits, str), "hex_digits must be a str"
    s = hex_digits.strip().lower()
    assert len(s) % 2 == 0, "hex string length must be even"
    assert all(c in "0123456789abcdef" for c in s), "hex string must be hexadecimal"
    return [int(s[i : i + 2], 16) for i in range(0, len(s), 2)]

def bytes_to_hex(ptr: int, n: int) -> str:
    return "".join(f"{test_lib.read_byte(ptr + i):02x}" for i in range(n))

def write_bytes(ptr: int, data: Sequence[int]) -> None:
    for i, value in enumerate(data):
        test_lib.write_byte(ptr + i, value)

def pack_dma_descriptor(tag: int, data: Optional[Sequence[int]], data_size: int, is_last: bool, discard: bool = False) -> Tuple[int, int]:
    """
    Lay out one SYMCRYPTO scatter-gather descriptor (16 bytes):
      Word0: first data address
      Word1: next descriptor (bit 0 = last)
      Word2: length | DISCARD
      Word3: tag
    """
    descriptor_address = get_segment()
    data_pointer = get_segment()
    if is_last:
        next_descriptor_pointer = DESC_LAST
    else:
        next_descriptor_pointer = get_segment(False)
    length_word = data_size & 0x0FFFFFFF
    if discard:
        length_word |= LENGTH_DISCARD
    test_lib.write_doubleword(descriptor_address, data_pointer)
    test_lib.write_doubleword(descriptor_address + 4, next_descriptor_pointer)
    test_lib.write_doubleword(descriptor_address + 8, length_word)
    test_lib.write_doubleword(descriptor_address + 12, tag)
    if data is not None:
        assert len(data) == data_size, "data length must match data_size"
        write_bytes(data_pointer, data)
    return descriptor_address, data_pointer

def u32_le(value: int) -> List[int]:
    return [value & 0xFF, (value >> 8) & 0xFF, (value >> 16) & 0xFF, (value >> 24) & 0xFF]

def create_ccm_header(nonce: Sequence[int], tag_len: int, aad: Sequence[int], data_len: int) -> List[int]:
    """RFC 3610 B0 + 2-byte AAD length, matching sx_aead_create_ccmheader()."""
    nonce_len = len(nonce)
    l = 15 - nonce_len
    flags = (1 << 6) if len(aad) > 0 else 0
    m = ((tag_len - 2) // 2) if tag_len > 0 else 0
    flags |= (m & 0x7) << 3
    flags |= (l - 1) & 0x7
    header = [0] * 16
    header[0] = flags
    header[1:1 + nonce_len] = list(nonce)
    length_field = data_len
    for i in range(l):
        header[15 - i] = length_field & 0xFF
        length_field >>= 8
    if len(aad) > 0:
        aad_len = len(aad)
        extra = [(aad_len >> 8) & 0xFF, aad_len & 0xFF] + list(aad)
        return header + extra
    return header

def start_symcrypto(fetcher_root: int, pusher_root: int) -> None:
    test_lib.write_register("symcrypto", REG_FETCHER_ADDRESS, fetcher_root)
    test_lib.write_register("symcrypto", REG_PUSHER_ADDRESS, pusher_root)
    test_lib.write_register("symcrypto", REG_CONTROL, CONTROL_FETCHER_SG | CONTROL_PUSHER_SG)
    test_lib.write_register("symcrypto", REG_COMMAND, COMMAND_START_FETCHER)

def pack_job(fetcher_items: Sequence[Tuple[int, Sequence[int]]], pusher_sizes: Sequence[int],
             discard_first: bool = False) -> List[int]:
    """Build a fetcher/pusher descriptor chain and start SYMCRYPTO. Returns pusher data pointers."""
    fetcher_root = None
    for i, (tag, data) in enumerate(fetcher_items):
        last = i == len(fetcher_items) - 1
        data_list = list(data)
        desc, _ = pack_dma_descriptor(tag, data_list, len(data_list), last)
        if fetcher_root is None:
            fetcher_root = desc

    pusher_root = None
    pusher_ptrs: List[int] = []
    pusher_count = len(pusher_sizes) + (1 if discard_first else 0)
    pusher_index = 0
    if discard_first:
        last = pusher_index == pusher_count - 1
        desc, _ = pack_dma_descriptor(0, [0] * 16, 16, last, discard=True)
        if pusher_root is None:
            pusher_root = desc
        pusher_index += 1
    for size in pusher_sizes:
        last = pusher_index == pusher_count - 1
        desc, ptr = pack_dma_descriptor(0, [0] * size, size, last)
        if pusher_root is None:
            pusher_root = desc
        pusher_ptrs.append(ptr)
        pusher_index += 1

    start_symcrypto(fetcher_root, pusher_root)
    return pusher_ptrs

def pack_ccm_job(cfg: int, key: Sequence[int], header: Optional[Sequence[int]],
                 iv: Optional[Sequence[int]], payload: Sequence[int],
                 pusher_sizes: Sequence[int], discard_aad: bool = False) -> List[int]:
    fetcher_items: List[Tuple[int, Sequence[int]]] = [
        (TAG_CFG, u32_le(cfg)),
        (TAG_KEY, key),
    ]
    if iv is not None:
        fetcher_items.append((TAG_IV, iv))
    if header is not None:
        fetcher_items.append((TAG_AAD, header))
    if len(payload) > 0:
        fetcher_items.append((TAG_PAYLOAD, payload))
    return pack_job(fetcher_items, pusher_sizes, discard_first=discard_aad)

def gcm_len_block(aad_len: int, data_len: int) -> List[int]:
    """len(A)||len(C) in bits, matching sxsymcrypt lenAlenC_aesgcm_ba411()."""
    aad_bits = aad_len * 8
    data_bits = data_len * 8
    out = [0] * 16
    for i in range(8):
        out[7 - i] = (aad_bits >> (8 * i)) & 0xFF
        out[15 - i] = (data_bits >> (8 * i)) & 0xFF
    return out

def hash_cfg_word(mode: int, hmac: bool = False, padding: bool = True, hash_final: bool = True) -> List[int]:
    flags = 0
    if hmac:
        flags |= HASH_CFG_HMAC
    if padding:
        flags |= HASH_CFG_PADDING
    if hash_final:
        flags |= HASH_CFG_FINAL
    return [mode & 0xFF, flags & 0xFF, 0, 0]

################################################
# Tests
################################################

def aes_ccm_oneshot_encrypt_test() -> None:
    reset_segment_index()
    key = hex_to_byte_list(ZB_KEY)
    nonce = hex_to_byte_list(ZB_NONCE)
    aad = hex_to_byte_list(ZB_AAD)
    plaintext = hex_to_byte_list(ZB_PLAINTEXT)
    header = create_ccm_header(nonce, len(hex_to_byte_list(ZB_TAG)), aad, len(plaintext))
    out_cipher, out_tag = pack_ccm_job(
        AES_CFG_CCM, key, header, None, plaintext,
        [len(plaintext), len(hex_to_byte_list(ZB_TAG))],
        discard_aad=True,
    )
    actual_ct = bytes_to_hex(out_cipher, len(plaintext))
    actual_tag = bytes_to_hex(out_tag, len(hex_to_byte_list(ZB_TAG)))
    test_lib.test_assert(actual_ct == ZB_CIPHERTEXT, f"CCM oneshot encrypt ciphertext mismatch:\n  {actual_ct}\n  {ZB_CIPHERTEXT}")
    test_lib.test_assert(actual_tag == ZB_TAG, f"CCM oneshot encrypt tag mismatch:\n  {actual_tag}\n  {ZB_TAG}")
    print("  > AES-CCM oneshot encrypt OK")

def aes_ccm_oneshot_decrypt_test() -> None:
    reset_segment_index()
    key = hex_to_byte_list(ZB_KEY)
    nonce = hex_to_byte_list(ZB_NONCE)
    aad = hex_to_byte_list(ZB_AAD)
    ciphertext = hex_to_byte_list(ZB_CIPHERTEXT)
    tag = hex_to_byte_list(ZB_TAG)
    header = create_ccm_header(nonce, len(tag), aad, len(ciphertext))
    payload = ciphertext + tag
    out_pt, out_tagxor = pack_ccm_job(
        AES_CFG_CCM | AES_CFG_DECRYPT, key, header, None, payload,
        [len(ciphertext), len(tag)],
        discard_aad=True,
    )
    actual_pt = bytes_to_hex(out_pt, len(ciphertext))
    actual_xor = bytes_to_hex(out_tagxor, len(tag))
    test_lib.test_assert(actual_pt == ZB_PLAINTEXT, f"CCM oneshot decrypt plaintext mismatch:\n  {actual_pt}\n  {ZB_PLAINTEXT}")
    test_lib.test_assert(actual_xor == "00" * len(tag), f"CCM oneshot decrypt tag XOR not zero: {actual_xor}")
    print("  > AES-CCM oneshot decrypt OK")

def aes_ccm_multipart_encrypt_test() -> None:
    reset_segment_index()
    key = hex_to_byte_list(ZB_KEY)
    nonce = hex_to_byte_list(ZB_NONCE)
    aad = hex_to_byte_list(ZB_AAD)
    plaintext = hex_to_byte_list(ZB_PLAINTEXT)
    tag_len = len(hex_to_byte_list(ZB_TAG))
    header = create_ccm_header(nonce, tag_len, aad, len(plaintext))
    first, rest = plaintext[:16], plaintext[16:]

    out_ct0, out_ctx = pack_ccm_job(
        AES_CFG_CCM | AES_CFG_CX_SAVE, key, header, None, first,
        [len(first), CCM_CONTEXT_SIZE],
        discard_aad=True,
    )
    context = hex_to_byte_list(bytes_to_hex(out_ctx, CCM_CONTEXT_SIZE))
    out_ct1, out_tag = pack_ccm_job(
        AES_CFG_CCM | AES_CFG_CX_LOAD, key, None, context, rest,
        [len(rest), tag_len],
    )
    actual_ct = bytes_to_hex(out_ct0, len(first)) + bytes_to_hex(out_ct1, len(rest))
    actual_tag = bytes_to_hex(out_tag, tag_len)
    test_lib.test_assert(actual_ct == ZB_CIPHERTEXT, f"CCM multipart encrypt ciphertext mismatch:\n  {actual_ct}\n  {ZB_CIPHERTEXT}")
    test_lib.test_assert(actual_tag == ZB_TAG, f"CCM multipart encrypt tag mismatch:\n  {actual_tag}\n  {ZB_TAG}")
    print("  > AES-CCM multipart encrypt OK")

def aes_ccm_multipart_decrypt_test() -> None:
    reset_segment_index()
    key = hex_to_byte_list(ZB_KEY)
    nonce = hex_to_byte_list(ZB_NONCE)
    aad = hex_to_byte_list(ZB_AAD)
    ciphertext = hex_to_byte_list(ZB_CIPHERTEXT)
    tag = hex_to_byte_list(ZB_TAG)
    header = create_ccm_header(nonce, len(tag), aad, len(ciphertext))
    first, rest = ciphertext[:16], ciphertext[16:]

    out_pt0, out_ctx = pack_ccm_job(
        AES_CFG_CCM | AES_CFG_DECRYPT | AES_CFG_CX_SAVE, key, header, None, first,
        [len(first), CCM_CONTEXT_SIZE],
        discard_aad=True,
    )
    context = hex_to_byte_list(bytes_to_hex(out_ctx, CCM_CONTEXT_SIZE))
    out_pt1, out_tagxor = pack_ccm_job(
        AES_CFG_CCM | AES_CFG_DECRYPT | AES_CFG_CX_LOAD, key, None, context, rest + tag,
        [len(rest), len(tag)],
    )
    actual_pt = bytes_to_hex(out_pt0, len(first)) + bytes_to_hex(out_pt1, len(rest))
    actual_xor = bytes_to_hex(out_tagxor, len(tag))
    test_lib.test_assert(actual_pt == ZB_PLAINTEXT, f"CCM multipart decrypt plaintext mismatch:\n  {actual_pt}\n  {ZB_PLAINTEXT}")
    test_lib.test_assert(actual_xor == "00" * len(tag), f"CCM multipart decrypt tag XOR not zero: {actual_xor}")
    print("  > AES-CCM multipart decrypt OK")

def aes_ccm_multipart_decrypt_tag_mismatch_test() -> None:
    reset_segment_index()
    key = hex_to_byte_list(ZB_KEY)
    nonce = hex_to_byte_list(ZB_NONCE)
    aad = hex_to_byte_list(ZB_AAD)
    ciphertext = hex_to_byte_list(ZB_CIPHERTEXT)
    tag = hex_to_byte_list(ZB_TAG)
    bad_tag = list(tag)
    bad_tag[0] ^= 0xFF
    header = create_ccm_header(nonce, len(tag), aad, len(ciphertext))
    first, rest = ciphertext[:16], ciphertext[16:]

    _, out_ctx = pack_ccm_job(
        AES_CFG_CCM | AES_CFG_DECRYPT | AES_CFG_CX_SAVE, key, header, None, first,
        [len(first), CCM_CONTEXT_SIZE],
        discard_aad=True,
    )
    context = hex_to_byte_list(bytes_to_hex(out_ctx, CCM_CONTEXT_SIZE))
    _, out_tagxor = pack_ccm_job(
        AES_CFG_CCM | AES_CFG_DECRYPT | AES_CFG_CX_LOAD, key, None, context, rest + bad_tag,
        [len(rest), len(tag)],
    )
    actual_xor = bytes_to_hex(out_tagxor, len(tag))
    test_lib.test_assert(actual_xor != "00" * len(tag), f"CCM tag mismatch produced all-zero XOR: {actual_xor}")
    print("  > AES-CCM multipart decrypt tag mismatch OK")

def _aes_ecb_roundtrip(key_hex: str, plaintext_hex: str, ciphertext_hex: str, label: str) -> None:
    reset_segment_index()
    key = hex_to_byte_list(key_hex)
    plaintext = hex_to_byte_list(plaintext_hex)
    (out,) = pack_job(
        [(TAG_CFG, u32_le(AES_CFG_ECB)), (TAG_KEY, key), (TAG_PAYLOAD, plaintext)],
        [len(plaintext)],
    )
    actual = bytes_to_hex(out, len(plaintext))
    test_lib.test_assert(actual == ciphertext_hex, f"{label} encrypt mismatch:\n  {actual}\n  {ciphertext_hex}")

    reset_segment_index()
    ciphertext = hex_to_byte_list(ciphertext_hex)
    (out,) = pack_job(
        [(TAG_CFG, u32_le(AES_CFG_ECB | AES_CFG_DECRYPT)), (TAG_KEY, key), (TAG_PAYLOAD, ciphertext)],
        [len(ciphertext)],
    )
    actual = bytes_to_hex(out, len(ciphertext))
    test_lib.test_assert(actual == plaintext_hex, f"{label} decrypt mismatch:\n  {actual}\n  {plaintext_hex}")
    print(f"  > {label} OK")

def aes_ecb_test() -> None:
    _aes_ecb_roundtrip(ECB_KEY_128, ECB_PLAINTEXT, ECB_CIPHERTEXT_128, "AES-ECB-128")
    _aes_ecb_roundtrip(ECB_KEY_256, ECB_PLAINTEXT, ECB_CIPHERTEXT_256, "AES-ECB-256")

def _aes_ctr_roundtrip(key_hex: str, plaintext_hex: str, ciphertext_hex: str, label: str) -> None:
    reset_segment_index()
    key = hex_to_byte_list(key_hex)
    iv = hex_to_byte_list(CTR_IV)
    plaintext = hex_to_byte_list(plaintext_hex)
    (out,) = pack_job(
        [(TAG_CFG, u32_le(AES_CFG_CTR)), (TAG_KEY, key), (TAG_IV, iv), (TAG_PAYLOAD, plaintext)],
        [len(plaintext)],
    )
    actual = bytes_to_hex(out, len(plaintext))
    test_lib.test_assert(actual == ciphertext_hex, f"{label} encrypt mismatch:\n  {actual}\n  {ciphertext_hex}")

    reset_segment_index()
    ciphertext = hex_to_byte_list(ciphertext_hex)
    (out,) = pack_job(
        [(TAG_CFG, u32_le(AES_CFG_CTR | AES_CFG_DECRYPT)), (TAG_KEY, key), (TAG_IV, iv), (TAG_PAYLOAD, ciphertext)],
        [len(ciphertext)],
    )
    actual = bytes_to_hex(out, len(ciphertext))
    test_lib.test_assert(actual == plaintext_hex, f"{label} decrypt mismatch:\n  {actual}\n  {plaintext_hex}")
    print(f"  > {label} OK")

def aes_ctr_test() -> None:
    _aes_ctr_roundtrip(ECB_KEY_128, ECB_PLAINTEXT, CTR_CIPHERTEXT_128, "AES-CTR-128")
    _aes_ctr_roundtrip(ECB_KEY_256, ECB_PLAINTEXT, CTR_CIPHERTEXT_256, "AES-CTR-256")

def aes_cmac_test() -> None:
    reset_segment_index()
    key = hex_to_byte_list(CMAC_KEY_128)
    message = hex_to_byte_list(CMAC_PLAINTEXT)
    (out,) = pack_job(
        [(TAG_CFG, u32_le(AES_CFG_CMAC)), (TAG_KEY, key), (TAG_PAYLOAD, message)],
        [16],
    )
    actual = bytes_to_hex(out, 16)
    test_lib.test_assert(actual == CMAC_TAG_128, f"AES-CMAC mismatch:\n  {actual}\n  {CMAC_TAG_128}")
    print("  > AES-CMAC-128 OK")

def aes_gcm_encrypt_test() -> None:
    reset_segment_index()
    key = hex_to_byte_list(GCM_KEY)
    iv = hex_to_byte_list(GCM_NONCE)
    aad = hex_to_byte_list(GCM_AAD)
    plaintext = hex_to_byte_list(GCM_PLAINTEXT)
    len_block = gcm_len_block(len(aad), len(plaintext))
    out_ct, out_tag = pack_job(
        [
            (TAG_CFG, u32_le(AES_CFG_GCM)),
            (TAG_KEY, key),
            (TAG_IV, iv),
            (TAG_AAD, aad),
            (TAG_PAYLOAD, plaintext),
            (TAG_PAYLOAD, len_block),
        ],
        [len(plaintext), 16],
        discard_first=True,
    )
    actual_ct = bytes_to_hex(out_ct, len(plaintext))
    actual_tag = bytes_to_hex(out_tag, 16)
    test_lib.test_assert(actual_ct == GCM_CIPHERTEXT, f"GCM encrypt ciphertext mismatch:\n  {actual_ct}\n  {GCM_CIPHERTEXT}")
    test_lib.test_assert(actual_tag == GCM_TAG, f"GCM encrypt tag mismatch:\n  {actual_tag}\n  {GCM_TAG}")
    print("  > AES-GCM encrypt OK")

def aes_gcm_decrypt_test() -> None:
    reset_segment_index()
    key = hex_to_byte_list(GCM_KEY)
    iv = hex_to_byte_list(GCM_NONCE)
    aad = hex_to_byte_list(GCM_AAD)
    ciphertext = hex_to_byte_list(GCM_CIPHERTEXT)
    len_block = gcm_len_block(len(aad), len(ciphertext))
    out_pt, out_tag = pack_job(
        [
            (TAG_CFG, u32_le(AES_CFG_GCM | AES_CFG_DECRYPT)),
            (TAG_KEY, key),
            (TAG_IV, iv),
            (TAG_AAD, aad),
            (TAG_PAYLOAD, ciphertext),
            (TAG_PAYLOAD, len_block),
        ],
        [len(ciphertext), 16],
        discard_first=True,
    )
    actual_pt = bytes_to_hex(out_pt, len(ciphertext))
    actual_tag = bytes_to_hex(out_tag, 16)
    test_lib.test_assert(actual_pt == GCM_PLAINTEXT, f"GCM decrypt plaintext mismatch:\n  {actual_pt}\n  {GCM_PLAINTEXT}")
    test_lib.test_assert(actual_tag == GCM_TAG, f"GCM decrypt tag mismatch:\n  {actual_tag}\n  {GCM_TAG}")
    print("  > AES-GCM decrypt OK")

def sha256_test() -> None:
    reset_segment_index()
    message = hex_to_byte_list(SHA256_ABC)
    (out,) = pack_job(
        [(TAG_HASH_CFG, hash_cfg_word(HASH_MODE_SHA256)), (TAG_HASH_MSG, message)],
        [32],
    )
    actual = bytes_to_hex(out, 32)
    test_lib.test_assert(actual == SHA256_ABC_DIGEST, f"SHA-256 mismatch:\n  {actual}\n  {SHA256_ABC_DIGEST}")
    print("  > SHA-256 OK")

def hmac_sha256_test() -> None:
    reset_segment_index()
    key = hex_to_byte_list(HMAC_SHA256_KEY)
    message = hex_to_byte_list(HMAC_SHA256_MSG)
    (out,) = pack_job(
        [
            (TAG_HASH_CFG, hash_cfg_word(HASH_MODE_SHA256, hmac=True)),
            (TAG_HASH_HMAC_KEY, key),
            (TAG_HASH_MSG, message),
        ],
        [32],
    )
    actual = bytes_to_hex(out, 32)
    test_lib.test_assert(actual == HMAC_SHA256_DIGEST, f"HMAC-SHA-256 mismatch:\n  {actual}\n  {HMAC_SHA256_DIGEST}")
    print("  > HMAC-SHA-256 OK")

################################################
# Tests runner
################################################

test_lib.create_emulation(debug=DEBUG)
test_lib.create_unit_test_machine("test", REPL_STRING)

print("Running tests...")
aes_ecb_test()
aes_ctr_test()
aes_cmac_test()
aes_gcm_encrypt_test()
aes_gcm_decrypt_test()
aes_ccm_oneshot_encrypt_test()
aes_ccm_oneshot_decrypt_test()
aes_ccm_multipart_encrypt_test()
aes_ccm_multipart_decrypt_test()
aes_ccm_multipart_decrypt_tag_mismatch_test()
sha256_test()
hmac_sha256_test()
print("Tests completed")
