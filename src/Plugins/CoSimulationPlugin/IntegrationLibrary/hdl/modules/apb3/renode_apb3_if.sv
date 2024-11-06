//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

interface renode_apb3_if #(
    int unsigned AddressWidth = 20,
    int unsigned DataWidth = 32
) (
    input logic pclk
);
  typedef logic [AddressWidth-1:0] address_t;
  typedef logic [DataWidth-1:0] data_t;

  logic     presetn;
  address_t paddr;
  logic     pselx;
  logic     penable;
  logic     pwrite;
  data_t    pwdata;
  logic     pready;  // Optional for outputs, mandatory for inputs
  data_t    prdata;
  logic     pslverr;  // Optional for outputs, mandatory for inputs

  initial begin
    assert (DataWidth == 8 || DataWidth == 16 || DataWidth == 24 || DataWidth == 32)
    else begin
      $error("APB DataWidth shall be {8,16,24,32} bits");
    end
  end

endinterface

