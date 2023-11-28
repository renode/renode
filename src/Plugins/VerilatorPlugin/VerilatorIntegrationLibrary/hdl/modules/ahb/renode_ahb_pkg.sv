//
//  Copyright 2023 Renesas Electronics Corporation
//
// This file is licensed under the MIT License.
// Full license text is available in 'LICENSE'.
//

package renode_ahb_pkg;
    parameter int ADDR_WIDTH = 32;
    parameter int DATA_WIDTH = 32;

    // AHB Burst Types
    typedef enum logic [3:0] {
        SINGLE    = 4'b0000,
        INCR      = 4'b0001,
        WRAP4     = 4'b0010,
        INCR4     = 4'b0011,
        WRAP8     = 4'b0100,
        INCR8     = 4'b0101,
        WRAP16    = 4'b0110,
        INCR16    = 4'b0111,
        WRAP32    = 4'b1000,
        INCR32    = 4'b1001,
        WRAP64    = 4'b1010,
        INCR64    = 4'b1011,
        WRAP128   = 4'b1100,
        INCR128   = 4'b1101,
        WRAP256   = 4'b1110,
        INCR256   = 4'b1111
    } ahb_burst_e;

    // AHB Transfer Types
    typedef enum logic [1:0] {
        IDLE      = 2'b00,
        BUSY      = 2'b01,
        NONSEQ    = 2'b10,
        SEQ       = 2'b11
    } ahb_trans_e;

    // AHB Response Types
    typedef enum logic {
        OKAY      = 1'b0,
        ERROR     = 1'b1
    } ahb_resp_e;

    // AHB Manager Interface
    typedef struct packed {
        logic [ADDR_WIDTH-1:0]  HADDR;
        logic [DATA_WIDTH-1:0]  HWDATA;
        logic [DATA_WIDTH-1:0]  HRDATA;
        ahb_burst_e             HBURST;
        logic                   HWRITE;
        ahb_trans_e             HTRANS;
        logic                   HREADYOUT;
        logic                   HREADY;
        ahb_resp_e              HRESP;
    } ahb_manager_t;

    // AHB Subordinate Interface
    typedef struct packed {
        logic [ADDR_WIDTH-1:0]  HADDR;
        logic [DATA_WIDTH-1:0]  HWDATA;
        logic [DATA_WIDTH-1:0]  HRDATA;
        ahb_burst_e             HBURST;
        logic                   HWRITE;
        ahb_trans_e             HTRANS;
        logic                   HREADYOUT;
        logic                   HREADY;
        logic                   HRESP;
        logic                   HSEL;
    } ahb_subordinate_t;

endpackage
