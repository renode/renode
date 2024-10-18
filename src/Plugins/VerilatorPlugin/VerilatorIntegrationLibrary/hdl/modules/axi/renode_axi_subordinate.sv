//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

`timescale 1ns / 1ps

import renode_pkg::renode_runtime, renode_pkg::LogWarning;

module renode_axi_subordinate (
    ref renode_runtime runtime,
    renode_axi_if bus
);
  import renode_axi_pkg::*;

  typedef logic [bus.AddressWidth-1:0] address_t;
  typedef logic [bus.DataWidth-1:0] data_t;
  typedef logic [bus.StrobeWidth-1:0] strobe_t;
  typedef logic [bus.TransactionIdWidth-1:0] transaction_id_t;

  wire clk = bus.aclk;

  always @(runtime.peripheral.reset_assert_request) begin
    bus.rvalid = 0;
    bus.bvalid = 0;
    bus.areset_n = 0;
    // The reset takes 2 cycles to prevent a race condition without usage of a non-blocking assigment.
    repeat (2) @(posedge clk);
    runtime.peripheral.reset_assert_respond();
  end

  always @(runtime.peripheral.reset_deassert_request) begin
    bus.areset_n = 1;
    // There is one more wait for the clock edges to be sure that all modules aren't in a reset state.
    repeat (2) @(posedge clk);
    runtime.peripheral.reset_deassert_respond();
  end

  always @(clk) read_transaction();
  always @(clk) write_transaction();

  task static read_transaction();
    transaction_id_t transaction_id;
    address_t address;
    renode_pkg::data_t data;
    bit is_error;
    burst_size_t burst_size;
    burst_length_t burst_length;
    burst_type_e burst_type;
    address_t address_last;
    renode_pkg::valid_bits_e valid_bits;
    address_t transfer_bytes;

    get_read_address(transaction_id, address, burst_size, burst_length, burst_type);
    valid_bits = bus.burst_size_to_valid_bits(burst_size);
    transfer_bytes = 2**burst_size;
    address_last = address + transfer_bytes * burst_length;
    for (; address <= address_last; address += transfer_bytes) begin
      if(!is_access_valid(address, valid_bits, burst_type)) begin
          set_read_response(transaction_id, 0, SlaveError, address == address_last);
      end
      else begin
          // The conection.read call may cause simulation time to move forward
          runtime.peripheral.read(renode_pkg::address_t'(address), valid_bits, data, is_error);
          if (is_error) begin
            runtime.connection.log(LogWarning, $sformatf("Unable to read data from Renode at address 'h%h, responding with 0.", address));
            data = 0;
          end
          data = data & valid_bits;
          set_read_response(transaction_id, data_t'(data) << ((address % transfer_bytes) * 8), is_error ? SlaveError : Okay, address == address_last);
      end
    end
  endtask

  task static write_transaction();
    transaction_id_t transaction_id;
    address_t address;
    data_t data;
    bit is_error;
    bit last_transfer;
    burst_size_t burst_size;
    burst_length_t burst_length;
    burst_type_e burst_type;
    address_t address_last;
    renode_pkg::valid_bits_e valid_bits;
    address_t transfer_bytes;

    get_write_address(transaction_id, address, burst_size, burst_length, burst_type);
    valid_bits = bus.burst_size_to_valid_bits(burst_size);
    if(!is_access_valid(address, valid_bits, burst_type)) begin
      do @(posedge clk); while (!bus.wvalid);
      bus.wready <= 1;
      @(posedge clk);
      bus.wready <= 0;
      set_write_response(transaction_id, SlaveError);
    end
    else begin
      transfer_bytes = 2**burst_size;
      address_last = address + transfer_bytes * burst_length;


      for (; address <= address_last; address += transfer_bytes) begin
        do @(posedge clk); while (!bus.wvalid);
        bus.wready <= 1;
        data = bus.wdata >> ((address % transfer_bytes) * 8);

        @(posedge clk);
        bus.wready <= 0;

        if (bus.wlast != (address == address_last)) runtime.connection.log(LogWarning, "Unexpected state of the wlast signal.");
        // The conection.write call may cause simulation time to move forward
        runtime.peripheral.write(renode_pkg::address_t'(address), valid_bits, renode_pkg::data_t'(data) & valid_bits, is_error);
        if (is_error) runtime.connection.log(LogWarning, $sformatf("Unable to write data to Renode at address 'h%h", address));
      end

      set_write_response(transaction_id, Okay);
    end
  endtask

  function static is_access_valid(address_t address, renode_pkg::valid_bits_e valid_bits, burst_type_e burst_type);
    if(!renode_pkg::is_access_aligned(renode_pkg::address_t'(address), valid_bits)) begin
      runtime.connection.log(LogWarning, $sformatf("Unaligned access to 0x%08X unsupported by AXI Subordinate. This will result in bus error response.", address));
      return 0;
    end
    if(burst_type != Incrementing) begin
      runtime.connection.fatal_error($sformatf("Unsupported burst type 'b%b", burst_type));
      return 0;
    end
    return 1;
  endfunction

  task static get_read_address(output transaction_id_t transaction_id, output address_t address,
                               output burst_size_t burst_size, output burst_length_t burst_length, output burst_type_e burst_type);
    @(posedge clk);
    bus.arready <= 1;

    do @(posedge clk); while (!bus.arvalid);
    transaction_id = bus.arid;
    address = bus.araddr;
    burst_size = bus.arsize;
    burst_length = bus.arlen;
    burst_type = burst_type_e'(bus.arburst);
    bus.arready <= 0;
  endtask

  task static get_write_address(output transaction_id_t transaction_id, output address_t address,
                                output burst_size_t burst_size, output burst_length_t burst_length, output burst_type_e burst_type);
    @(posedge clk);
    bus.awready <= 1;

    do @(posedge clk); while (!bus.awvalid);
    transaction_id = bus.awid;
    address = bus.awaddr;
    burst_size = bus.awsize;
    burst_length = bus.awlen;
    burst_type = burst_type_e'(bus.awburst);
    bus.awready <= 0;
  endtask

  task static set_read_response(transaction_id_t transaction_id, data_t data, response_e response, bit last);
        @(posedge clk);
        bus.rid <= transaction_id;
        bus.rdata <= data;
        bus.rresp <= response;
        bus.rlast <= last;
        bus.rvalid <= 1;

        // It's required to assert the valid and ready signals only for one clock cycle.
        do @(posedge clk); while (!bus.rready);
        bus.rlast  <= 0;
        bus.rvalid <= 0;
  endtask

  task static set_write_response(transaction_id_t id, response_e response);
    bus.bid   = id;
    bus.bresp = response;

    @(posedge clk);
    bus.bvalid <= 1;

    do @(posedge clk); while (!bus.bready);
    bus.bvalid <= 0;
  endtask
endmodule

