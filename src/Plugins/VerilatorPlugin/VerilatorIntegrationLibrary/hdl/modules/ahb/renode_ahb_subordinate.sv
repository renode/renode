//
// Copyright (c) 2023 Renesas Electronics Corporation
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'LICENSE'.
//

module renode_ahb_subordinate (
    renode_ahb_if bus,
    input renode_pkg::bus_connection connection
);
  import renode_ahb_pkg::*;

  typedef logic [bus.AddressWidth-1:0] address_t;
  typedef logic [bus.DataWidth-1:0] data_t;
  wire clk = bus.hclk;

  always @(connection.reset_assert_request) begin
    bus.hresetn = 0;
    bus.hresp = Okay;
    bus.hreadyout = 1;
    repeat (2) @(posedge clk);
    connection.reset_assert_respond();
  end

  always @(connection.reset_deassert_request) begin
    bus.hresetn = 1;
    repeat (2) @(posedge clk);
    connection.reset_deassert_respond();
  end

  always @(posedge clk) transaction();

  task static transaction();
    renode_pkg::address_t address;
    renode_pkg::valid_bits_e valid_bits;
    renode_pkg::data_t data;
    bit is_error;
    bit is_invalid;
    transfer_direction_e direction;

    wait_for_transfer(address, valid_bits, direction, is_invalid);

    // The connection.read call may consume an unknown number of clock cycles.
    // To to make the logic simpler both read and write transactions contain at least one cycle with a deasserted ready.
    // It also ensures that address and data phases don't overlap between transactions.
    bus.hreadyout <= 0;
    @(posedge clk);

    if (!is_invalid) begin
      if (direction == Read) begin
        connection.read(address, valid_bits, data, is_error);
        bus.hrdata = data_t'(data & valid_bits);
        if (is_error) connection.log_warning($sformatf("Unable to read data from Renode at address 'h%h", address));
      end else begin
        connection.write(address, valid_bits, renode_pkg::data_t'(bus.hwdata) & valid_bits, is_error);
        if (is_error) connection.log_warning($sformatf("Unable to write data to Renode at address 'h%h", address));
      end
    end

    if (is_invalid || is_error) begin
      bus.hresp = Error;
      @(posedge clk); // An error response should last two cycles.
      bus.hreadyout <= 1;
    end
    else begin
      bus.hresp = Okay;
      bus.hreadyout <= 1;
    end
  endtask


  task static wait_for_transfer(output renode_pkg::address_t address, output renode_pkg::valid_bits_e valid_bits, output transfer_direction_e direction, output bit is_invalid);
    is_invalid = 0;
    bus.hreadyout <= 1;
    while (!bus.hready || bus.htrans == Idle || bus.htrans == Busy) @(posedge clk);

    address = bus.haddr;
    valid_bits = bus.transfer_size_to_valid_bits(bus.hsize);
    direction = transfer_direction_e'(bus.hwrite);
    if (!bus.are_valid_bits_supported(valid_bits)) begin
      connection.log_warning($sformatf("Unsupported transaction width of %d for AHB bus with width %d. No transaction will be performed.", renode_pkg::valid_bits_to_transaction_width(valid_bits), bus.DataWidth));
      is_invalid = 1;
    end
  endtask
endmodule
