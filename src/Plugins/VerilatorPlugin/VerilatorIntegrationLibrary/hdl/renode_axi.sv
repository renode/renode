//
// Copyright (c) 2010-2023 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

`include "renode.sv"

interface axi_if #(
    int AddressWidth = 20,
    int TransactionIdWidth = 8,
    int TimeoutCycles = 100
) (
    input bit clk
);
  localparam int DataWidth = 32;
  localparam int StrobeWidth = (DataWidth / 8);

  typedef logic [AddressWidth-1:0] address_t;
  typedef logic [DataWidth-1:0] data_t;
  typedef logic [StrobeWidth-1:0] strobe_t;
  typedef logic [TransactionIdWidth-1:0] transaction_id_t;
  typedef logic [1:0] response_t;

  typedef enum logic [1:0] {
    Okay = 2'b00,
    ExclusiveAccessOkay = 2'b01,
    SlaveError = 2'b10,
    DecodeError = 2'b11
  } response_e;

  logic                  areset_n;
  transaction_id_t       awid;
  address_t              awaddr;
  logic            [7:0] awlen;
  logic            [2:0] awsize;
  logic            [1:0] awburst;
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
  logic            [7:0] arlen;
  logic            [2:0] arsize;
  logic            [1:0] arburst;
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

  task static handle_request(renode::connection connection, renode::message_t message);
    case (message.action)
      renode::readRequest: read_requested(connection, message.address);
      renode::readRequestDoubleWord: read_requested(connection, message.address);
      renode::resetPeripheral: reset();
      renode::writeRequest: write_requested(connection, message.address, message.data);
      renode::writeRequestDoubleWord: write_requested(connection, message.address, message.data);
      default: connection.handle_message(message);
    endcase
  endtask

  task static reset();
    areset_n = 0;
    arvalid  = 0;
    awvalid  = 0;
    wvalid   = 0;

    // The reset takes 2 cycles to prevent a race condition without usage of non-blocking assigment
    repeat (2) @(posedge clk);
    areset_n = 1;
    // There is one more wait for the clock edge to be sure that all modules aren't in a reset state
    @(posedge clk);
  endtask

  task automatic read_requested(renode::connection connection, renode::address_t address);
    // This task is automatic to separate timeout handling between calls
    data_t data;
    bit is_error = 0;
    bit is_timeout = 0;
    fork
      begin
        repeat (TimeoutCycles) @(posedge clk);
        is_timeout = 1;
      end
      begin
        read(0, address_t'(address), data, is_error);
      end
    join_any

    if (is_timeout) $display("Renode at %t: Read request timeout", $time);
    if (is_error || is_timeout) connection.send(renode::message_t'{renode::error, 0, 0});
    else connection.send(renode::message_t'{renode::readRequest, address, renode::data_t'(data)});
  endtask

  task automatic write_requested(renode::connection connection, renode::address_t address,
                                 renode::data_t data);
    // This task is automatic to separate timeout handling between calls
    bit is_error = 0;
    bit is_timeout = 0;
    fork
      begin
        repeat (TimeoutCycles) @(posedge clk);
        is_timeout = 1;
      end
      begin
        write(0, address_t'(address), data_t'(data), is_error);
      end
    join_any

    if (is_timeout) $display("Renode at %t: Write request timeout", $time);
    if (is_error || is_timeout) connection.send(renode::message_t'{renode::error, 0, 0});
    else connection.send(renode::message_t'{renode::ok, 0, 0});
  endtask

  task static read(transaction_id_t id, address_t address, output data_t data, output bit is_error);
    fork
      set_read_address(id, address);
      get_read_response(id, data, is_error);
    join
  endtask

  task static write(transaction_id_t id, address_t address, data_t data, output bit is_error);
    fork
      set_write_address(id, address);
      set_write_data(data);
      get_write_response(id, is_error);
    join
  endtask

  task static set_read_address(transaction_id_t transaction_id, address_t address);
    arid = transaction_id;
    araddr = address;

    // Configure 4-byte transaction without burst
    arlen = 0;
    arsize = 'b10;
    arburst = 0;
    arlock = 0;
    arprot = 0;

    @(posedge clk) arvalid <= 1;
    wait (arready);
    @(posedge clk) arvalid <= 0;
  endtask

  task static get_read_response(transaction_id_t id, output data_t data, output bit is_error);
    @(posedge clk) rready <= 1;

    wait (rvalid && rlast);
    @(posedge clk) begin
      data = rdata;
      is_error = check_response(id, bid, bresp);
      rready <= 0;
    end
  endtask

  task static set_write_address(transaction_id_t id, address_t address);
    awid = id;
    awaddr = address;

    // Configure 4-byte transaction without burst
    awlen = 0;
    awsize = 'b10;
    awburst = 0;
    awlock = 0;
    awprot = 0;

    @(posedge clk) awvalid <= 1;
    wait (awready);
    @(posedge clk) awvalid <= 0;
  endtask

  task static set_write_data(data_t data);
    wdata = data;
    wstrb = 'b1111;
    wlast = 1;

    @(posedge clk) wvalid <= 1;
    wait (wready);
    @(posedge clk) wvalid <= 0;
  endtask

  task static get_write_response(transaction_id_t id, output bit is_error);
    @(posedge clk) bready <= 1;

    wait (bvalid);
    @(posedge clk) begin
      is_error = check_response(id, bid, bresp);
      bready <= 0;
    end
  endtask

  function automatic bit check_response(transaction_id_t request_id, transaction_id_t response_id,
                                        response_t response);
    response_e response_enum;
    response_enum = response_e'(response);
    if (response_id != request_id) begin
      $display("Renode at %t: Unexpected transaction id in the response ('h%h), expected 'h%h",
               $time, response_id, request_id);
      return 1;
    end
    if (response_enum != Okay && response_enum != ExclusiveAccessOkay) begin
      $display("Renode at %t: Response error 'h%h", $time, response);
      return 1;
    end
    return 0;
  endfunction
endinterface

