# -*- coding: utf-8 -*-
SMMU_BASE = 0xFD800000
STREAM_TABLE_ADDR = 0x40010000  # aligned to 2⁶
CONTEXT_DESCRIPTOR_ADDR = 0x40020000  # aligned to 2⁶
PAGE_TABLE_L1_ADDR = 0x40030000
PAGE_TABLE_L2_ADDR = 0x40031000
PAGE_TABLE_L3_ADDR = 0x40032000

SMMU_CR0 = 0x20
SMMU_STRTAB_BASE = 0x80
SMMU_STRTAB_BASE_CFG = 0x88
SMMU_S_INIT = 0x803c
STREAM_TABLE_ENTRY_SIZE = 64


def peek(addr):
    return self.Machine.SystemBus.ReadQuadWord(addr)


def poke(addr, val):
    return self.Machine.SystemBus.WriteQuadWord(addr, val)


def poke32(addr, val):
    return self.Machine.SystemBus.WriteDoubleWord(addr, val)


def mc_setup_smmu(stream_id):
    # Set up SMMU and map two 4KB pages
    # 0x0 -> 0x0
    # 0x1000 -> 0x00000001'00000000

    # L0 Table is not used in VMSAv8-32

    # L1 Table -> L2 Table, Valid=1, Table=1
    poke(PAGE_TABLE_L1_ADDR, PAGE_TABLE_L2_ADDR | 0b11)

    # L2 Table -> L3 Table
    poke(PAGE_TABLE_L2_ADDR, PAGE_TABLE_L3_ADDR | 0b11)

    # L3 Table -> Page entry template
    page_template = 0
    page_template |= 1 << 0  # Valid
    page_template |= 1 << 1  # Table
    page_template |= 0 << 2  # AttrIndx
    page_template |= 1 << 5  # NS
    page_template |= 0b01 << 6  # AP
    page_template |= 0b11 << 8  # SH
    page_template |= 1 << 10  # AccessFlag

    # L3 Table entry for 0x0 -> 0x0 (index 0)
    poke(PAGE_TABLE_L3_ADDR + 0 * 8, page_template | 0x0)
    # L3 Table entry for 0x1000 -> 0x100000000 (index 1)
    poke(PAGE_TABLE_L3_ADDR + 1 * 8, page_template | 0x100000000)

    # Context descriptor
    cd = 0
    cd |= 16 << 0  # T0SZ
    cd |= 0b00 << 6  # TG0
    cd |= 16 << 16  # T1SZ
    cd |= 0b10 << 22  # TG1
    cd |= 0 << 41 # AA64
    poke(CONTEXT_DESCRIPTOR_ADDR + 0, cd)
    poke(CONTEXT_DESCRIPTOR_ADDR + 8, PAGE_TABLE_L1_ADDR)
    # Rest as zeroes
    for i in range(2, 8):
        poke(CONTEXT_DESCRIPTOR_ADDR + i * 8, 0)

    # Stream table entry for the CPU
    ste_addr = STREAM_TABLE_ADDR + stream_id * STREAM_TABLE_ENTRY_SIZE
    ste = 0
    ste |= 1 << 0  # V
    ste |= 0b101 << 1  # Config = TranslateStage1
    ste |= CONTEXT_DESCRIPTOR_ADDR  # s1ContextPtr, aligned to 2⁶
    poke(ste_addr, ste)
    # Rest as zeroes
    for i in range(1, 8):
        poke(ste_addr + i * 8, 0)

    # Put that stream table into the SMMU
    poke(SMMU_BASE + SMMU_STRTAB_BASE, STREAM_TABLE_ADDR)  # aligned to 2⁶
    poke32(SMMU_BASE + SMMU_STRTAB_BASE_CFG, 5)  # log2size
    # Enable SMMU translations
    poke32(SMMU_BASE + SMMU_CR0, 1)  # SMMUEN
    # Invalidate everything to load STEs
    poke32(SMMU_BASE + SMMU_S_INIT, 1)  # INV_ALL
