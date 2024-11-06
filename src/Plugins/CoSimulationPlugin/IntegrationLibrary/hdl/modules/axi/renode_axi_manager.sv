//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

`timescale 1ns / 1ps

import renode_pkg::renode_runtime, renode_pkg::LogWarning;

module renode_axi_manager (
    ref renode_runtime runtime,
    renode_axi_if bus
);
  import renode_axi_pkg::*;

  typedef logic [bus.AddressWidth-1:0] address_t;
  typedef logic [bus.DataWidth-1:0] data_t;
  typedef logic [bus.StrobeWidth-1:0] strobe_t;
  typedef logic [bus.TransactionIdWidth-1:0] transaction_id_t;

  wire clk = bus.aclk;

  always @(runtime.controller.reset_assert_request) begin
    bus.arvalid = 0;
    bus.awvalid = 0;
    bus.wvalid  = 0;
    bus.areset_n = 0;
    // The reset takes 2 cycles to prevent a race condition without usage of a non-blocking assigment.
    repeat (2) @(posedge clk);
    runtime.controller.reset_assert_respond();
  end

  always @(runtime.controller.reset_deassert_request) begin
    bus.areset_n = 1;
    // There is one more wait for the clock edges to be sure that all modules aren't in a reset state.
    repeat (2) @(posedge clk);
    runtime.controller.reset_deassert_respond();
  end

  always @(runtime.controller.read_transaction_request) read_transaction();
  always @(runtime.controller.write_transaction_request) write_transaction();

  task static read_transaction();
    bit is_error;
    address_t address;
    renode_pkg::valid_bits_e valid_bits;
    burst_size_t burst_size;
    data_t data;

    address = address_t'(runtime.controller.read_transaction_address);
    valid_bits = runtime.controller.read_transaction_data_bits;

    if(!is_access_valid(address, valid_bits)) begin
      runtime.controller.read_respond(0, 1);
    end else begin
      burst_size = bus.valid_bits_to_burst_size(valid_bits);

      read(0, address, burst_size, data, is_error);

      data = data >> ((address % bus.StrobeWidth) * 8);
      runtime.controller.read_respond(renode_pkg::data_t'(data) & valid_bits, is_error);
    end
  endtask

  task static write_transaction();
    bit is_error;
    address_t address;
    renode_pkg::valid_bits_e valid_bits;
    burst_size_t burst_size;
    data_t data;
    strobe_t strobe;

    address = address_t'(runtime.controller.write_transaction_address);
    valid_bits = runtime.controller.write_transaction_data_bits;

    if(!is_access_valid(address, valid_bits)) begin
      runtime.controller.write_respond(1);
    end else begin
      burst_size = bus.valid_bits_to_burst_size(valid_bits);
      data = data_t'(runtime.controller.write_transaction_data & valid_bits);
      strobe = bus.burst_size_to_strobe(burst_size) << (address % bus.StrobeWidth);
      data = data << ((address % bus.StrobeWidth) * 8);

      write(0, address, burst_size, strobe, data, is_error);

      runtime.controller.write_respond(is_error);
    end
  endtask

  function static is_access_valid(address_t address, renode_pkg::valid_bits_e valid_bits);
    if(!renode_pkg::is_access_aligned(renode_pkg::address_t'(address), valid_bits)) begin
      runtime.connection.log(LogWarning, $sformatf("Unaligned access to 0x%08X is unsupported by AXI Manager. Operation will have no effect.", address));
      return 0;
    end
    if(!bus.are_valid_bits_supported(valid_bits)) begin
      runtime.connection.log(LogWarning, $sformatf("This instance of the AXI Manager doesn't support access using the 'b%b mask.", valid_bits));
      return 0;
    end
    return 1;
  endfunction

  task static read(transaction_id_t id, address_t address, burst_size_t burst_size, output data_t data, output bit is_error);
    transaction_id_t response_id;
    response_e response;
    fork
      set_read_address(id, address, burst_size);
      get_read_response(data, response_id, response);
    join
    is_error = check_response(id, response_id, response);
  endtask

  task static write(transaction_id_t id, address_t address, burst_size_t burst_size, strobe_t strobe, data_t data, output bit is_error);
    transaction_id_t response_id;
    response_e response;
    fork
      set_write_address(id, address, burst_size);
      set_write_data(data, strobe);
      get_write_response(response_id, response);
    join
    is_error = check_response(id, response_id, response);
  endtask

  task static set_read_address(transaction_id_t transaction_id, address_t address, burst_size_t burst_size);
    bus.arid = transaction_id;
    bus.araddr = address;
    bus.arsize = burst_size;

    // Configure transaction with only one burst.
    bus.arlen = 0;
    bus.arburst = 0;
    bus.arlock = 0;
    bus.arprot = 0;

    @(posedge clk);
    bus.arvalid <= 1;

    do @(posedge clk); while (!bus.arready);
    bus.arvalid <= 0;
  endtask

  task static get_read_response(output data_t data, output transaction_id_t transaction_id, output response_e response);
    @(posedge clk);
    bus.rready <= 1;

    do @(posedge clk); while (!bus.rvalid);
    data = bus.rdata;
    transaction_id = bus.bid;
    response = response_e'(bus.bresp);
    bus.rready <= 0;
  endtask

  task static set_write_address(transaction_id_t id, address_t address, burst_size_t burst_size);
    bus.awid = id;
    bus.awaddr = address;
    bus.awsize = burst_size;

    // Configure transaction with only one burst.
    bus.awlen = 0;
    bus.awburst = 0;
    bus.awlock = 0;
    bus.awprot = 0;

    @(posedge clk);
    bus.awvalid <= 1;

    do @(posedge clk); while (!bus.awready);
    bus.awvalid <= 0;
  endtask

  task static set_write_data(data_t data, strobe_t strobe);
    bus.wdata = data;
    bus.wstrb = strobe;
    bus.wlast = 1;

    @(posedge clk);
    bus.wvalid <= 1;

    do @(posedge clk); while (!bus.wready);
    bus.wvalid <= 0;
  endtask

  task static get_write_response(output transaction_id_t transaction_id, output response_e response);
    @(posedge clk);
    bus.bready <= 1;

    do @(posedge clk); while (!bus.bvalid);
    transaction_id = bus.bid;
    response = response_e'(bus.bresp);
    bus.bready <= 0;
  endtask

  function automatic bit check_response(transaction_id_t request_id, transaction_id_t response_id, response_t response);
    response_e response_enum = response_e'(response);
    if (response_id != request_id) begin
      runtime.connection.log(LogWarning, $sformatf("Unexpected transaction id in the response ('h%h), expected 'h%h", response_id, request_id));
      return 1;
    end
    if (response_enum != Okay && response_enum != ExclusiveAccessOkay) begin
      runtime.connection.log(LogWarning, $sformatf("Response error 'h%h", response));
      return 1;
    end
    return 0;
  endfunction
endmodule

