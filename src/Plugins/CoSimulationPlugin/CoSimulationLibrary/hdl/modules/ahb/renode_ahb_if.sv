//
// Copyright (c) 2023 Renesas Electronics Corporation
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'LICENSE'.
//

interface renode_ahb_if #(
    int unsigned AddressWidth = 32,
    int unsigned DataWidth = 32
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

  function automatic strobe_t transfer_size_to_strobe(transfer_size_t size);
    int unsigned bytes_count = 2 ** size;
    return strobe_t'((1 << bytes_count) - 1);
  endfunction
endinterface
