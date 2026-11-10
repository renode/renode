//
// Copyright (c) 2023 Renesas Electronics Corporation
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'LICENSE'.
//

interface renode_ahb_if #(
    int unsigned AddressWidth = 32,
    int unsigned DataWidth = 32,
    renode_ahb_pkg::bus_endianness_e BusEndianness = renode_ahb_pkg::LittleEndian
) (
    input logic hclk
);
  import renode_ahb_pkg::*;

  localparam int unsigned StrobeWidth = (DataWidth / 8);

  typedef logic [AddressWidth-1:0] address_t;
  typedef logic [DataWidth-1:0] data_t;
  typedef logic [StrobeWidth-1:0] strobe_t;

  logic                hresetn;
  address_t            haddr;
  data_t               hwdata;
  data_t               hrdata;
  burst_t              hburst;
  transfer_direction_t hwrite;
  transfer_type_t      htrans;
  response_t           hresp;
  transfer_size_t      hsize;
  strobe_t             hwstrb;
  logic                hsel;
  logic                hready;
  logic                hgrant;
  logic                hreadyout;

  function static bit are_valid_bits_supported(renode_pkg::valid_bits_e valid_bits);
    case (valid_bits)
      renode_pkg::Byte: return DataWidth >= 8;
      renode_pkg::Word: return DataWidth >= 16;
      renode_pkg::DoubleWord: return DataWidth >= 32;
      renode_pkg::QuadWord: return DataWidth >= 64;
      default: return 0;
    endcase
  endfunction

  function static transfer_size_e valid_bits_to_transfer_size(renode_pkg::valid_bits_e valid_bits);
    case (valid_bits)
      renode_pkg::Byte: return Byte8bit;
      renode_pkg::Word: return Halfword16bit;
      renode_pkg::DoubleWord: return Word32bit;
      renode_pkg::QuadWord: return Doubleword64bit;
      default: return transfer_size_e'('x);
    endcase
  endfunction

  function static renode_pkg::valid_bits_e transfer_size_to_valid_bits(transfer_size_t transfer_size);
    case (transfer_size)
      Byte8bit: return renode_pkg::Byte;
      Halfword16bit: return renode_pkg::Word;
      Word32bit: return renode_pkg::DoubleWord;
      Doubleword64bit: return renode_pkg::QuadWord;
      default: return renode_pkg::valid_bits_e'(0);
    endcase
  endfunction

  function automatic strobe_t transfer_size_to_strobe(renode_pkg::address_t address, transfer_size_t size);
    int unsigned bytes_count = 2 ** size;
    int unsigned offset = int'(byte_lane_offset(address, size));
    return strobe_t'(((1 << bytes_count) - 1) << offset);
  endfunction

  function static int transfer_size_to_bytes(transfer_size_t size);
    case (size)
      Byte8bit: return 1;
      Halfword16bit: return 2;
      Word32bit: return 4;
      Doubleword64bit: return 8;
      default: return 'X;
    endcase
  endfunction

  function automatic longint le_byte_lane_offset(renode_pkg::address_t address, transfer_size_t size);
    // NOTE: following section 6.2.1 AMBA AHB spec
    longint data_bus_bytes = (longint'(DataWidth) + 7) / 8;
    longint byte_lane = address - (address / data_bus_bytes) * data_bus_bytes;
    return byte_lane;
  endfunction

  function static longint be8_byte_lane_offset(renode_pkg::address_t address, transfer_size_t size);
    // NOTE: following section 6.2.2 AMBA AHB spec
    return le_byte_lane_offset(address, size);
  endfunction

  function automatic longint be32_byte_lane_offset(renode_pkg::address_t address, transfer_size_t size);
    // NOTE: following section 6.2.3 AMBA AHB spec
    longint data_bus_bytes = (longint'(DataWidth) + 7) / 8;
    longint address_offset = address - (address / data_bus_bytes) * data_bus_bytes;
    longint word_offset = (address_offset / 4) * 4;
    longint byte_offset = address_offset - word_offset;
    return word_offset + 3 - byte_offset;
  endfunction


  function static longint byte_lane_offset(renode_pkg::address_t address, transfer_size_t size);
    case (BusEndianness)
      LittleEndian: return le_byte_lane_offset(address, size);
      ByteInvariantLittleEndian: return be8_byte_lane_offset(address, size);
      WordInvariantBigEndian: return be32_byte_lane_offset(address, size);
    endcase
  endfunction

  function automatic renode_pkg::data_t encode_byte_lane(
    renode_pkg::data_t data,
    renode_pkg::address_t address,
    transfer_size_t size);
    longint offset = byte_lane_offset(address, size);
    return data << (offset * 8);
  endfunction

  function automatic renode_pkg::data_t decode_byte_lane(renode_pkg::data_t data, renode_pkg::address_t address, transfer_size_t size);
    longint offset = byte_lane_offset(address, size);
    return data >> (offset * 8);
  endfunction
endinterface
