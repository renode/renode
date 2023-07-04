//
// Copyright (c) 2010-2023 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

import renode_axi_pkg::*;

module renode_axi_manager (
    renode_axi_if bus,
    input renode_pkg::bus_connection connection
);
  typedef logic [bus.AddressWidth-1:0] address_t;
  typedef logic [bus.DataWidth-1:0] data_t;
  typedef logic [bus.StrobeWidth-1:0] strobe_t;
  typedef logic [bus.TransactionIdWidth-1:0] transaction_id_t;

  wire clk = bus.clk;

  always @(connection.reset_assert_request) begin
    bus.arvalid = 0;
    bus.awvalid = 0;
    bus.wvalid  = 0;
    bus.reset_assert();
    connection.reset_assert_respond();
  end

  always @(connection.reset_deassert_request) begin
    bus.reset_deassert();
    connection.reset_deassert_respond();
  end

  always @(connection.read_transaction_request) read_transaction();
  always @(connection.write_transaction_request) write_transaction();

  task static read_transaction();
    bit is_error;
    data_t data;

    read(0, address_t'(connection.read_transaction_address), data, is_error);
    connection.read_respond(renode_pkg::data_t'(data), is_error);
  endtask

  task static write_transaction();
    bit is_error;

    write(0, address_t'(connection.write_transaction_address), data_t'(connection.write_transaction_data), is_error);
    connection.write_respond(is_error);
  endtask

  task static read(transaction_id_t id, address_t address, output data_t data, output bit is_error);
    transaction_id_t response_id;
    response_e response;
    fork
      set_read_address(id, address);
      get_read_response(data, response_id, response);
    join
    is_error = check_response(id, response_id, response);
  endtask

  task static write(transaction_id_t id, address_t address, data_t data, output bit is_error);
    transaction_id_t response_id;
    response_e response;
    fork
      set_write_address(id, address);
      set_write_data(data);
      get_write_response(response_id, response);
    join
    is_error = check_response(id, response_id, response);
  endtask

  task static set_read_address(transaction_id_t transaction_id, address_t address);
    bus.arid = transaction_id;
    bus.araddr = address;

    // Configure 4-byte transaction without burst.
    bus.arlen = 0;
    bus.arsize = 'b10;
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

  task static set_write_address(transaction_id_t id, address_t address);
    bus.awid = id;
    bus.awaddr = address;

    // Configure 4-byte transaction without burst.
    bus.awlen = 0;
    bus.awsize = 'b10;
    bus.awburst = 0;
    bus.awlock = 0;
    bus.awprot = 0;

    @(posedge clk);
    bus.awvalid <= 1;

    do @(posedge clk); while (!bus.awready);
    bus.awvalid <= 0;
  endtask

  task static set_write_data(data_t data);
    bus.wdata = data;
    bus.wstrb = 'b1111;
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
      connection.log_warning($sformatf("Unexpected transaction id in the response ('h%h), expected 'h%h", response_id, request_id));
      return 1;
    end
    if (response_enum != Okay && response_enum != ExclusiveAccessOkay) begin
      connection.log_warning($sformatf("Response error 'h%h", response));
      return 1;
    end
    return 0;
  endfunction
endmodule

