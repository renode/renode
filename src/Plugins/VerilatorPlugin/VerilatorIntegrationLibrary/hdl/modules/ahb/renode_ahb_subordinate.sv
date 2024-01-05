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
    transfer_direction_e direction;

    wait_for_transfer(address, valid_bits, direction);

    // The connection.read call may consume an unknown number of clock cycles.
    // To to make the logic simpler both read and write transactions contain at least one cycle with a deasserted ready.
    // It also ensures that address and data phases don't overlap between transactions.
    bus.hreadyout <= 0;
    @(posedge clk);

    if (direction == Read) begin
      connection.read(address, valid_bits, data, is_error);
      bus.hrdata = data_t'(data & valid_bits);
      if (is_error) connection.log_warning($sformatf("Unable to read data from Renode at address 'h%h", address));
    end else begin
      connection.write(address, valid_bits, renode_pkg::data_t'(bus.hwdata) & valid_bits, is_error);
      if (is_error) connection.log_warning($sformatf("Unable to write data to Renode at address 'h%h", address));
    end
    bus.hresp = Okay;
    bus.hreadyout <= 1;
  endtask


  task static wait_for_transfer(output renode_pkg::address_t address, output renode_pkg::valid_bits_e valid_bits, output transfer_direction_e direction);
    bus.hreadyout <= 1;
    while (!bus.hready || bus.htrans == Idle || bus.htrans == Busy) @(posedge clk);

    address = bus.haddr;
    valid_bits = bus.transfer_size_to_valid_bits(bus.hsize);
    if (valid_bits != renode_pkg::DoubleWord || !bus.are_valid_bits_supported(valid_bits)) begin
      connection.fatal_error("Incorrect access, the AHB Subordinate currently supports only 32-bit access.");
    end
    direction = transfer_direction_e'(bus.hwrite);
  endtask
endmodule
