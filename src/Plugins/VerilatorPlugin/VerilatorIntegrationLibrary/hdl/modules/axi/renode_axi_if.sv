//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

interface renode_axi_if #(
    int unsigned AddressWidth = 32,
    int unsigned DataWidth = 32,
    int unsigned TransactionIdWidth = 8
) (
    input logic aclk
);
  import renode_axi_pkg::*;

  localparam int unsigned StrobeWidth = (DataWidth / 8);

  typedef logic [AddressWidth-1:0] address_t;
  typedef logic [DataWidth-1:0] data_t;
  typedef logic [StrobeWidth-1:0] strobe_t;
  typedef logic [TransactionIdWidth-1:0] transaction_id_t;

  logic                  areset_n;
  transaction_id_t       awid;
  address_t              awaddr;
  burst_length_t         awlen;
  burst_size_t           awsize;
  burst_type_t           awburst;
  logic                  awlock;
  logic            [3:0] awcache;
  logic            [2:0] awprot;
  logic                  awvalid;
  logic                  awready;
  data_t                 wdata;
  strobe_t               wstrb;
  logic                  wlast;
  logic                  wvalid;
  logic                  wready;
  transaction_id_t       bid;
  response_t             bresp;
  logic                  bvalid;
  logic                  bready;
  transaction_id_t       arid;
  address_t              araddr;
  burst_length_t         arlen;
  burst_size_t           arsize;
  burst_type_t           arburst;
  logic                  arlock;
  logic            [3:0] arcache;
  logic            [2:0] arprot;
  logic                  arvalid;
  logic                  arready;
  transaction_id_t       rid;
  data_t                 rdata;
  response_t             rresp;
  logic                  rlast;
  logic                  rvalid;
  logic                  rready;

  function static bit are_valid_bits_supported(renode_pkg::valid_bits_e valid_bits);
    case (valid_bits)
      renode_pkg::Byte: return DataWidth >= 8;
      renode_pkg::Word: return DataWidth >= 16;
      renode_pkg::DoubleWord: return DataWidth >= 32;
      renode_pkg::QuadWord: return DataWidth >= 64;
      default: return 0;
    endcase
  endfunction

  function static burst_size_t valid_bits_to_burst_size(renode_pkg::valid_bits_e valid_bits);
    case (valid_bits)
      renode_pkg::Byte: return 'b000;
      renode_pkg::Word: return 'b001;
      renode_pkg::DoubleWord: return 'b010;
      renode_pkg::QuadWord: return 'b011;
      default: return 'x;
    endcase
  endfunction

  function static renode_pkg::valid_bits_e burst_size_to_valid_bits(burst_size_t burst_size);
    case (burst_size)
      'b000: return renode_pkg::Byte;
      'b001: return renode_pkg::Word;
      'b010: return renode_pkg::DoubleWord;
      'b011: return renode_pkg::QuadWord;
      default: return renode_pkg::valid_bits_e'(0);
    endcase
  endfunction

  function automatic strobe_t burst_size_to_strobe(burst_size_t burst_size);
    int unsigned bytes_count = 2 ** burst_size;
    return strobe_t'((1 << bytes_count) - 1);
  endfunction
endinterface
