//
// Copyright (c) 2023 Renesas Electronics Corporation
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'LICENSE'.
//

`timescale 1ns / 1ps

import renode_pkg::renode_runtime, renode_pkg::LogWarning;

module renode_ahb_manager (
    ref renode_runtime runtime,
    renode_ahb_if bus
);
  import renode_ahb_pkg::*;

  typedef logic [bus.AddressWidth-1:0] address_t;
  typedef logic [bus.DataWidth-1:0] data_t;
  wire clk = bus.hclk;

  always @(runtime.controller.reset_assert_request) begin
    bus.hresetn = 0;
    bus.haddr   = '0;
    bus.htrans  = Idle;
    repeat (2) @(posedge clk);
    runtime.controller.reset_assert_respond();
  end

  always @(runtime.controller.reset_deassert_request) begin
    bus.hresetn = 1;
    repeat (2) @(posedge clk);
    runtime.controller.reset_deassert_respond();
  end

  always @(runtime.controller.read_transaction_request) read_transaction();
  always @(runtime.controller.write_transaction_request) write_transaction();

  task static write_transaction();
    renode_pkg::valid_bits_e valid_bits;
    data_t data;
    bit is_invalid;

    valid_bits = runtime.controller.write_transaction_data_bits;
    data = data_t'(runtime.controller.write_transaction_data & valid_bits);
    configure_transfer(runtime.controller.write_transaction_address, valid_bits, Write, is_invalid);
    if (is_invalid) begin
        runtime.controller.write_respond(is_invalid);
        return;
    end

    bus.hwstrb = bus.transfer_size_to_strobe(bus.valid_bits_to_transfer_size(valid_bits));
    bus.hwdata = data;
    bus.htrans <= Idle;

    do @(posedge clk); while (!bus.hready);
    runtime.controller.write_respond(is_response_error(bus.hresp));
  endtask

  task static read_transaction();
    renode_pkg::valid_bits_e valid_bits;
    data_t data;
    bit is_invalid;
    bit is_error;

    valid_bits = runtime.controller.read_transaction_data_bits;
    configure_transfer(runtime.controller.read_transaction_address, valid_bits, Read, is_invalid);
    if (is_invalid) begin
        runtime.controller.read_respond(renode_pkg::data_t'(0), is_invalid);
        return;
    end

    bus.htrans <= Idle;

    do @(posedge clk); while (!bus.hready);
    data = bus.hrdata;
    is_error = is_response_error(bus.hresp);
    runtime.controller.read_respond(renode_pkg::data_t'(data) & valid_bits, is_error);
  endtask

  task static configure_transfer(renode_pkg::address_t address, renode_pkg::valid_bits_e valid_bits, transfer_direction_e direction, output logic is_invalid);
    is_invalid = 0;
    if (!bus.are_valid_bits_supported(valid_bits)) begin
      is_invalid = 1;
      runtime.connection.log(LogWarning, $sformatf("Unsupported transaction width of %d for AHB bus with width %d. No transaction will be performed.", renode_pkg::valid_bits_to_transaction_width(valid_bits), bus.DataWidth));
      return;
    end
    bus.hwrite = direction;
    bus.hsize  = bus.valid_bits_to_transfer_size(valid_bits);
    bus.hburst = Single;
    bus.haddr  = address_t'(address);
    bus.htrans <= NonSequential;
    do @(posedge clk); while (!bus.hready);
  endtask

  function static bit is_response_error(response_t response);
    if (response == Okay) begin
      return 0;
    end
    runtime.connection.log(LogWarning, $sformatf("Error response from a Subordinate: 'h%h", response));
    return 1;
  endfunction
endmodule
