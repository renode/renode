//
// Copyright (c) 2010-2023 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

import renode_axi_pkg::*;

module renode_axi_subordinate (
    renode_axi_if bus,
    input renode_pkg::bus_connection connection
);
  typedef logic [bus.AddressWidth-1:0] address_t;
  typedef logic [bus.DataWidth-1:0] data_t;
  typedef logic [bus.StrobeWidth-1:0] strobe_t;
  typedef logic [bus.TransactionIdWidth-1:0] transaction_id_t;

  wire clk = bus.clk;

  always @(connection.reset_assert_request) begin
    bus.reset_assert();
    connection.reset_assert_respond();
  end

  always @(connection.reset_deassert_request) begin
    bus.reset_deassert();
    connection.reset_deassert_respond();
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

    get_read_address(transaction_id, address, burst_size, burst_length, burst_type);
    if (burst_size != 'b10) connection.fatal_error($sformatf("Unsupported burst size 'b%b", burst_size));
    else if (address % 4 != 0) connection.fatal_error($sformatf("Unaligned address isn't supported."));
    else if (burst_type != Incrementing) connection.fatal_error($sformatf("Unsupported burst type 'b%b", burst_type));
    else begin
      address_last = address + 4 * burst_length;
      for (; address <= address_last; address += 4) begin
        // The conection.read call may cause elapse of a simulation time.
        connection.read(renode_pkg::address_t'(address), data, is_error);
        if (is_error) connection.log_warning($sformatf("Unable to read data from Renode at address 'h%h, unknown value sent to bus.", address));

        @(posedge clk);
        bus.rid <= transaction_id;
        bus.rdata <= data_t'(data);
        bus.rlast <= address == address_last;
        bus.rvalid <= 1;

        // It's required to set the valid signal only for one clock cycle.
        do @(posedge clk); while (!bus.rready);
        bus.rlast  <= 0;
        bus.rvalid <= 0;
      end
    end
  endtask

  task static write_transaction();
    transaction_id_t transaction_id;
    address_t address;
    bit is_error;
    burst_size_t burst_size;
    burst_length_t burst_length;
    burst_type_e burst_type;
    address_t address_last;

    get_write_address(transaction_id, address, burst_size, burst_length, burst_type);
    if (burst_size != 'b10) connection.fatal_error($sformatf("Unsupported burst size 'b%b", burst_size));
    else if (address % 4 != 0) connection.fatal_error($sformatf("Unaligned address isn't supported."));
    else if (burst_type != Incrementing) connection.fatal_error($sformatf("Unsupported burst type 'b%b", burst_type));
    else begin
      address_last = address + 4 * burst_length;

      do @(posedge clk); while (!bus.wvalid);
      bus.wready <= 1;

      for (; address <= address_last; address += 4) begin
        do @(posedge clk); while (!bus.wvalid);
        connection.write(renode_pkg::address_t'(address), renode_pkg::data_t'(bus.wdata), is_error);
        if (is_error) connection.log_warning($sformatf("Unable to write data to Renode at address 'h%h", address));
      end

      @(posedge clk);
      bus.wready <= 0;

      set_write_response(transaction_id, Okay);
    end
  endtask

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

  task static set_write_response(transaction_id_t id, response_e response);
    bus.bid   = id;
    bus.bresp = response;

    @(posedge clk);
    bus.bvalid <= 1;

    do @(posedge clk); while (!bus.bready);
    bus.bvalid <= 0;
  endtask
endmodule

