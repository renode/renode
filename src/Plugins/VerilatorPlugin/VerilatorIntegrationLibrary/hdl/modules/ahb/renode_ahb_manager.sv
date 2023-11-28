//
//  Copyright 2023 Renesas Electronics Corporation
//
// This file is licensed under the MIT License.
// Full license text is available in 'LICENSE'.
//

module renode_ahb_manager (
    renode_ahb_if bus,
    input renode_pkg::bus_connection connection
);
    typedef logic [bus.ADDR_WIDTH-1:0] address_t;
    typedef logic [bus.DATA_WIDTH-1:0] data_t;
    wire clk = bus.HCLK;
    logic ready_gen;

    assign bus.HREADY = ready_gen;

    //reset procedure
    always @(connection.reset_assert_request) begin
        bus.HTRANS = '0;
        bus.HADDR = '0;
        bus.HWRITE = '0;
        bus.HBURST = '0;
        bus.HSIZE = '0;
        bus.HTRANS = '0;
        ready_gen = 0;
        bus.HRESETn = '0;
        repeat (2) @(posedge clk);
        connection.reset_assert_respond();
    end

    always @(connection.reset_deassert_request) begin
        bus.HRESETn = 1;
        // Wait for one or more clock edges to be sure that all modules aren't in a reset state.
        repeat (2) @(posedge clk);
        connection.reset_deassert_respond();
    end

    // Copy the readyout signal from the subordinate to the manager
    always @(posedge clk) begin
        if (bus.HREADYOUT) begin
            ready_gen <= 1;
        end
        else begin
            ready_gen <= 0;
        end
    end

    always @(connection.read_transaction_request) read_transaction();
    always @(connection.write_transaction_request) write_transaction();

    function automatic bit check_response(logic response);
        if (response) begin
            connection.log_warning($sformatf("AHB manager: error response from subordinate"));
            return 1;
        end
        else begin
            connection.log_warning($sformatf("AHB manager: no error response"));
            return 0;
        end
    endfunction

    task static write_transaction();
        address_t address;
        data_t data;
        bit is_error;
        data = data_t'(connection.write_transaction_data);
        address = address_t'(connection.write_transaction_address);
        `ifdef RENODE_DEBUG
        $display("AHB manager: write transaction started, at address %h, data %h", address, data);
        `endif
        @(posedge clk);
        bus.HADDR = address;
        bus.HWRITE = 1;
        bus.HTRANS = 2;  // NONSEQ
        bus.HBURST = '0; //configure for single burst
        bus.HSIZE = 2;   //configure for 4 bytes
        do @(posedge clk); while (!bus.HREADY);
        bus.HWDATA = data;
        bus.HTRANS = 0;
        bus.HWRITE = 0;
        bus.HSIZE = 0;
        is_error = check_response(bus.HRESP);
        connection.write_respond(is_error);
    endtask

    task static read_transaction();
        bit is_error;
        address_t address;
        renode_pkg::valid_bits_e valid_bits;
        data_t data;

        address = address_t'(connection.read_transaction_address);
        `ifdef RENODE_DEBUG
        $display("AHB manager: read transaction from address %h", address);
        `endif

        @(posedge clk);
        bus.HADDR = address;
        bus.HWRITE = '0;
        bus.HBURST = '0;
        bus.HTRANS = 2;
        bus.HSIZE = 2;
        do @(posedge clk); while (!bus.HREADY);
        data = bus.HRDATA;
        bus.HTRANS = '0;
        is_error = check_response(bus.HRESP);

        `ifdef RENODE_DEBUG
        $display("AHB manager: read data = %h", data);
        `endif
        connection.read_respond({32'b0,data}, is_error);
    endtask

endmodule
