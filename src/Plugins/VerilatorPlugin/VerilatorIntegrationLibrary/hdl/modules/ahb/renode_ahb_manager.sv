//
// Copyright (c) 2023 Renesas Electronics Corporation
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'LICENSE'.
//

module renode_ahb_manager (
    renode_ahb_if bus,
    input renode_pkg::bus_connection connection
);
  import renode_ahb_pkg::*;

  typedef logic [bus.AddressWidth-1:0] address_t;
  typedef logic [bus.DataWidth-1:0] data_t;
  wire clk = bus.hclk;

  always @(connection.reset_assert_request) begin
    bus.hresetn = 0;
    bus.haddr   = '0;
    bus.htrans  = Idle;
    repeat (2) @(posedge clk);
    connection.reset_assert_respond();
  end

  always @(connection.reset_deassert_request) begin
    bus.hresetn = 1;
    repeat (2) @(posedge clk);
    connection.reset_deassert_respond();
  end

  always @(connection.read_transaction_request) read_transaction();
  always @(connection.write_transaction_request) write_transaction();

  task static write_transaction();
    renode_pkg::valid_bits_e valid_bits;
    data_t data;
    bit is_invalid;

    valid_bits = connection.write_transaction_data_bits;
    data = data_t'(connection.write_transaction_data & valid_bits);
    configure_transfer(connection.write_transaction_address, valid_bits, Write, is_invalid);
    if (is_invalid) begin
        connection.write_respond(is_invalid);
        return;
    end

    bus.hwstrb = bus.transfer_size_to_strobe(bus.valid_bits_to_transfer_size(valid_bits));
    bus.hwdata = data;
    bus.htrans <= Idle;

    do @(posedge clk); while (!bus.hready);
    connection.write_respond(is_response_error(bus.hresp));
  endtask

  task static read_transaction();
    renode_pkg::valid_bits_e valid_bits;
    data_t data;
    bit is_invalid;
    bit is_error;

    valid_bits = connection.read_transaction_data_bits;
    configure_transfer(connection.read_transaction_address, valid_bits, Read, is_invalid);
    if (is_invalid) begin
        connection.read_respond(renode_pkg::data_t'(0), is_invalid);
        return;
    end

    bus.htrans <= Idle;

    do @(posedge clk); while (!bus.hready);
    data = bus.hrdata;
    is_error = is_response_error(bus.hresp);
    connection.read_respond(renode_pkg::data_t'(data) & valid_bits, is_error);
  endtask

  task static configure_transfer(renode_pkg::address_t address, renode_pkg::valid_bits_e valid_bits, transfer_direction_e direction, output logic is_invalid);
    is_invalid = 0;
    if (!bus.are_valid_bits_supported(valid_bits)) begin
      is_invalid = 1;
      connection.log_warning($sformatf("Unsupported transaction width of %d for AHB bus with width %d. No transaction will be performed.", renode_pkg::valid_bits_to_transaction_width(valid_bits), bus.DataWidth));
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
    connection.log_warning($sformatf("Error response from a Subordinate: 'h%h", response));
    return 1;
  endfunction
endmodule
