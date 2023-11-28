//
//  Copyright 2023 Renesas Electronics Corporation
//
// This file is licensed under the MIT License.
// Full license text is available in 'LICENSE'.
//

interface renode_ahb_if #(
    int unsigned ADDR_WIDTH = 32,
    int unsigned DATA_WIDTH =32
)(
    input logic HCLK
);
    logic                     HRESETn;
    logic [ADDR_WIDTH-1:0]    HADDR;
    logic [DATA_WIDTH-1:0]    HWDATA;
    logic [DATA_WIDTH-1:0]    HRDATA;
    logic [3:0]               HBURST;
    logic                     HWRITE;
    logic [1:0]               HTRANS;
    logic                     HRESP;
    logic [2:0]               HSIZE;
    logic [ADDR_WIDTH/8-1:0]  HWSTRB;
    logic                     HSEL;
    logic                     HREADY;
    logic                     HGRANT;
    logic                     HREADYOUT;

    function static bit are_valid_bits_supported(renode_pkg::valid_bits_e valid_bits);
        case (valid_bits)
        renode_pkg::Byte: return DATA_WIDTH >= 8;
        renode_pkg::Word: return DATA_WIDTH >= 16;
        renode_pkg::DoubleWord: return DATA_WIDTH >= 32;
        renode_pkg::QuadWord: return DATA_WIDTH >= 64;
        default: return 0;
        endcase
    endfunction

    function int determine_burst_length(logic [3:0] HBURST);
        int burst_length;
        case (HBURST)
            4'b0000: burst_length = 1;  // SINGLE
            4'b0001: burst_length = 1;  // INCR (undefined length, but we'll represent as 1 for simplicity)
            4'b0010: burst_length = 4;  // WRAP4
            4'b0011: burst_length = 4;  // INCR4
            4'b0100: burst_length = 8;  // WRAP8
            4'b0101: burst_length = 8;  // INCR8
            4'b0110: burst_length = 16; // WRAP16
            4'b0111: burst_length = 16; // INCR16
            4'b1000: burst_length = 32; // WRAP32
            4'b1001: burst_length = 32; // INCR32
            4'b1010: burst_length = 64; // WRAP64
            4'b1011: burst_length = 64; // INCR64
            4'b1100: burst_length = 128;// WRAP128
            4'b1101: burst_length = 128;// INCR128
            4'b1110: burst_length = 256;// WRAP256
            4'b1111: burst_length = 256;// INCR256
            default: burst_length = 1;  // Default to SINGLE
        endcase
        return burst_length;
    endfunction

endinterface //ahb_if
