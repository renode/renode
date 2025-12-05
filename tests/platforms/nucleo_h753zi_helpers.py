def extract_int_from_bytes(bytes, start, count):
    start = int(start)
    end = start + int(count)
    return int.from_bytes(bytes[start:end], byteorder='big')

def mc_setup_smmu(stream_id):
    stream_id = int(stream_id)

    def poke(addr, val):
        return self.Machine.SystemBus.WriteQuadWord(addr, val)

    def poke32(addr, val):
        return self.Machine.SystemBus.WriteDoubleWord(addr, val)

    # SMMU registers
    SMMU_BASE = 0x53000000
    SMMU_CR0 = 0x20
    SMMU_STRTAB_BASE = 0x80
    SMMU_STRTAB_BASE_CFG = 0x88
    SMMU_S_INIT = 0x803c
    STREAM_TABLE_ENTRY_SIZE = 64
    TABLE_SIZE = 5
    TABLE_ENTRIES = 1 << TABLE_SIZE

    STREAM_TAB_ADDR = 0x38000000

    for entry in range(TABLE_ENTRIES):
        ste_addr = STREAM_TAB_ADDR + entry * STREAM_TABLE_ENTRY_SIZE

        for i in range(0, STREAM_TABLE_ENTRY_SIZE / 8):
            poke(ste_addr + i * 8, 0)

        ste = 0
        ste |= 1 << 0  # V
        if entry == stream_id:
            ste |= 0b100 << 1  # Config = Bypass
        else:
            ste |= 0b000 << 1  # Config = Abort
        poke(ste_addr, ste)

    poke(SMMU_BASE + SMMU_STRTAB_BASE, STREAM_TAB_ADDR)
    poke32(SMMU_BASE + SMMU_STRTAB_BASE_CFG, TABLE_SIZE)  # log2size
    # Enable SMMU translations
    poke32(SMMU_BASE + SMMU_CR0, 1)  # SMMUEN
    # Invalidate everything to load STEs
    poke32(SMMU_BASE + SMMU_S_INIT, 1)  # INV_ALL
