//
//  Copyright 2023 Renesas Electronics Corporation
//
// This file is licensed under the MIT License.
// Full license text is available in 'LICENSE'.
//

module renode_ahb_subordinate (
    renode_ahb_if bus,
    input renode_pkg::bus_connection connection
);
    typedef logic [bus.ADDR_WIDTH-1:0] address_t;
    typedef logic [bus.DATA_WIDTH-1:0] data_t;
    typedef logic [1:0] response_t;
    wire clk = bus.HCLK;

    always @(connection.reset_assert_request) begin
        bus.HRESETn = 0;
        bus.HREADYOUT = 0;
        bus.HRESP = 0;
        bus.HRDATA = 0;
        bus.HSEL = 0;
        repeat(2) @(posedge clk);
        connection.reset_assert_respond();
    end

    always @(connection.reset_deassert_request) begin
        bus.HRESETn = 1;
        repeat (2) @(posedge clk);
        connection.reset_deassert_respond();
    end

    always @(clk) read_transaction();
    always @(clk) write_transaction();

    task static read_transaction();
        address_t address;
        renode_pkg::data_t data;
        bit is_error;
        valid_bits_e valid_data;
        valid_data = valid_bits_e'({32'b0,{32{1'b1}}});

        bus.HSEL = 1;
        bus.HREADYOUT = 1;
        do @(posedge clk); while ((!bus.HREADY) | (bus.HTRANS != 2) | bus.HWRITE == 1);
        address = bus.HADDR;
        connection.read(renode_pkg::address_t'(address), valid_data, data, is_error);
        if (is_error) connection.log_warning($sformatf("Unable to read data from Renode at address 'h%h", address));
        `ifdef RENODE_DEBUG
        $display("AHB subordinate: read transaction initiated at address %h, data = %h", address, data);
        `endif
        @(posedge clk)
        bus.HRDATA = data;
        bus.HRESP = is_error;
        bus.HREADYOUT = 1;
    endtask

    task static write_transaction();
        address_t address;
        data_t data;
        bit is_error;
        valid_bits_e valid_data;
        valid_data = valid_bits_e'({32'b0,{32{1'b1}}});

        do @(posedge clk); while ((!bus.HREADY) | (bus.HTRANS != 2) | bus.HWRITE == 0);
        address = bus.HADDR;
        @(posedge clk)
        data = bus.HWDATA;
        `ifdef RENODE_DEBUG
        $display("AHB subordinate: write transaction at addr %h, data = %h", address, data);
        `endif

        connection.write(renode_pkg::address_t'(address), valid_data,renode_pkg::data_t'(data) & valid_data, is_error);
        if (is_error) connection.log_warning($sformatf("Unable to write data to Renode at address 'h%h", address));
        bus.HRESP = is_error;
        bus.HREADYOUT = 1;
    endtask

endmodule
