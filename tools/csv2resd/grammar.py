#!/usr/bin/env python

from construct import *

BLOCK_TYPE = Enum(Int8ul,
    RESERVED            = 0x00,
    ARBITRARY_TIMESTAMP = 0x01,
    CONSTANT_FREQUENCY  = 0x02,
)

SAMPLE_TYPE = Enum(Int16ul,
    RESERVED              = 0x0000,
    TEMPERATURE           = 0x0001,
    ACCELERATION          = 0x0002,
    ANGULAR_RATE          = 0x0003,
    VOLTAGE               = 0x0004,
    ECG                   = 0x0005,
    HUMIDITY              = 0x0006,
    PRESSURE              = 0x0007,
    MAGNETIC_FLUX_DENSITY = 0x0008,

    CUSTOM                = 0xF000,
)

resd_header = Struct(
    "magic" / Const(b"RESD"),
    "version" / Int8ul,
    "reserved" / Padding(3)
)

blob = Struct(
    "size" / Rebuild(Int32ul, len_(this.data)),
    "data" / Int8ul[this.size],
)

data_block_metadata_item = Struct(
    "key" / NullTerminated(GreedyRange(Int8ub)),
    "type" / Int8ul,
    "value" / Switch(this.type,
    {
        0x00: Int8sl,
        0x01: Int8ul,
        0x02: Int16sl,
        0x03: Int16ul,
        0x04: Int32sl,
        0x05: Int32ul,
        0x06: Int64sl,
        0x07: Int64ul,
        0x08: Float32l,
        0x09: Float64l,
        0x0A: NullTerminated(GreedyRange(Int8ul)),
        0x0B: blob,
    }),
)

data_block_metadata = Struct(
    "size" / Int64ul,
    "items" / FixedSized(this.size, GreedyRange(data_block_metadata_item)),
)

data_block_sample = lambda sample_type: Switch(sample_type, {
    "TEMPERATURE": Int32sl,
    "ACCELERATION": Struct(
        "x" / Int32sl,
        "y" / Int32sl,
        "z" / Int32sl,
    ),
    "ANGULAR_RATE": Struct(
        "x" / Int32sl,
        "y" / Int32sl,
        "z" / Int32sl,
    ),
    "VOLTAGE": Int32ul,
    "ECG": Int32sl,
    "HUMIDITY": Int32ul,
    "PRESSURE": Int64ul,
    "MAGNETIC_FLUX_DENSITY": Struct(
        "x" / Int32sl,
        "y" / Int32sl,
        "z" / Int32sl,
    ),
})

data_block_sample_arbitrary = lambda sample_type: Struct(
    "timestamp" / Int64ul,
    "sample" / data_block_sample(sample_type)
)

data_block_sample_arbitrary_subheader = Struct(
    "start_time" / Int64ul,
)

data_block_sample_frequency = lambda sample_type: Struct(
    "sample" / data_block_sample(sample_type)
)

data_block_sample_frequency_subheader = Struct(
    "start_time" / Int64ul,
    "period" / Int64ul,
)

data_block_sample_single = lambda type_, sample_type: Switch(type_, {
    "ARBITRARY_TIMESTAMP": data_block_sample_arbitrary(sample_type),
    "CONSTANT_FREQUENCY": data_block_sample_frequency(sample_type),
})

data_block_subheader = Switch(this.header.block_type, {
    "ARBITRARY_TIMESTAMP": data_block_sample_arbitrary_subheader,
    "CONSTANT_FREQUENCY": data_block_sample_frequency_subheader
})

data_block_header = Struct(
    "block_type" / BLOCK_TYPE,
    "sample_type" / SAMPLE_TYPE,
    "channel_id" / Int16ul,
    "data_size" / Int64ul,
)

data_block = Struct(
    "header" / data_block_header,
    "subheader" / data_block_subheader,
    "metadata" / data_block_metadata,
    "samples" / GreedyRange(data_block_sample_single(this.header.block_type, this._.header.sample_type))
)

resd = Struct(
    "header" / resd_header,
    "blocks" / GreedyRange(data_block)
)
