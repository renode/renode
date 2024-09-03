//
// Copyright (c) 2010-2023 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

module renode_apb3_requester (
    renode_apb3_if bus,
    input renode_pkg::bus_connection connection
);
  typedef logic [bus.AddressWidth-1:0] address_t;
  typedef logic [bus.DataWidth-1:0] data_t;

  // Renaming the bus is a style preference
  wire clk;
  assign clk = bus.pclk;

  logic rst_n;
  assign bus.presetn = rst_n;

  address_t paddr;
  logic     pselx;
  logic     penable;
  logic     pwrite;
  data_t    pwdata;
  logic     pready;
  data_t    prdata;
  logic     pslverr;

  assign bus.paddr = paddr;
  assign bus.pselx = pselx;
  assign bus.penable = penable;
  assign bus.pwrite = pwrite;
  assign bus.pwdata = pwdata;

  assign pready = bus.pready;
  assign prdata = bus.prdata;
  assign pslverr = bus.pslverr;

  int unsigned b2b_counter;
  address_t write_address;
  address_t read_address;
  data_t write_data;

  logic start_transaction;
  logic write_mode;

  // Only value of 1 is currently supported
  localparam int unsigned Back2BackNum = 1;


  always @(connection.reset_assert_request) begin
    write_address = '0;
    read_address = '0;
    write_data = '0;
    start_transaction = '0;
    write_mode = '0;
    rst_n = 0;
    // The reset takes 2 cycles to prevent a race condition without usage of a non-blocking assigment.
    repeat (2) @(posedge clk);
    connection.reset_assert_respond();
  end

  always @(connection.reset_deassert_request) begin
    rst_n = 1;
    // There is one more wait for the clock edges to be sure that all modules aren't in a reset state.
    repeat (2) @(posedge clk);
    connection.reset_deassert_respond();
  end

  // Internal state
  typedef enum {
    S_IDLE,
    S_SETUP,
    S_ACCESS
  } state_t;
  state_t state = S_IDLE;

  //
  // Waveform generation
  //

  always @(connection.read_transaction_request) begin
    integer transaction_width;

    if(!renode_pkg::is_access_aligned(connection.read_transaction_address, connection.read_transaction_data_bits)) begin
        connection.log_warning("Unaligned access on APB bus results in unpredictable behavior");
    end
    transaction_width = renode_pkg::valid_bits_to_transaction_width(connection.read_transaction_data_bits);
    if (bus.DataWidth > transaction_width) begin
      connection.log_warning(
          $sformatf("Bus bus.bus.DataWidth is (%d) > transaction width (%d), MSB will be truncated.", bus.DataWidth, transaction_width));
    end else if (bus.DataWidth < transaction_width) begin
      connection.log_warning(
          $sformatf("Bus bus.bus.DataWidth is (%d) < transaction width (%d), MSB will be zero-extended.", bus.DataWidth, transaction_width));
    end

    read_address = address_t'(connection.read_transaction_address);
    write_mode = 1'b0;
    start_transaction = 1'b1;
    @(posedge clk) start_transaction <= 1'b0;
  end

  always @(connection.write_transaction_request) begin
    integer transaction_width;

    if(!renode_pkg::is_access_aligned(connection.write_transaction_address, connection.write_transaction_data_bits)) begin
        connection.log_warning("Unaligned access on APB bus results in unpredictable behavior");
    end
    transaction_width = renode_pkg::valid_bits_to_transaction_width(connection.write_transaction_data_bits);
    if (bus.DataWidth > transaction_width) begin
      connection.log_warning(
          $sformatf("Bus bus.bus.DataWidth is (%d) > transaction width (%d), MSB will be truncated.", bus.DataWidth, transaction_width));
    end else if (bus.DataWidth < transaction_width) begin
      connection.log_warning(
          $sformatf("Bus bus.bus.DataWidth is (%d) < transaction width (%d), MSB will be zero-extended.", bus.DataWidth, transaction_width));
    end

    write_address = address_t'(connection.write_transaction_address);
    write_data = data_t'(connection.write_transaction_data);
    write_mode = 1'b1;
    start_transaction = 1'b1;
    @(posedge clk) start_transaction <= 1'b0;
  end

  state_t next_state;
  always_comb begin : proc_next_state
    case (state)
      S_IDLE: begin
        if (start_transaction) begin
          next_state = S_SETUP;
        end else begin
          next_state = S_IDLE;
        end
      end
      S_SETUP: begin
        next_state = S_ACCESS;
      end
      S_ACCESS: begin
        if (pready) begin
          if (b2b_counter == 0) begin
            next_state = S_IDLE;
          end else begin
            next_state = S_SETUP;
          end
        end else begin
          next_state = S_ACCESS;
        end
      end
      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (rst_n == '0) begin
      state <= S_IDLE;
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          b2b_counter <= Back2BackNum;
        end
        S_SETUP: begin
          b2b_counter <= b2b_counter - 1;
        end
        S_ACCESS: begin
          if (pready) begin
            if (write_mode) begin
              connection.write_respond(1'b0);  // Notify Renode that write is done
            end else begin
              connection.read_respond(renode_pkg::data_t'(prdata), 1'b0);
            end
          end
        end
        default: begin
          b2b_counter <= Back2BackNum;
        end
      endcase
    end
  end

  always_comb begin : proc_fsm_outputs
    case (state)
      S_IDLE: begin
        paddr   = '0;
        pselx   = '0;
        penable = '0;
        pwrite  = '0;
        pwdata  = '0;
      end
      S_SETUP: begin
        paddr   = write_mode ? write_address : read_address;
        pselx   = 1'b1;
        penable = 1'b0;
        pwrite  = write_mode;
        pwdata  = write_mode ? write_data : '0;
      end
      S_ACCESS: begin
        paddr   = write_mode ? write_address : read_address;
        pselx   = 1'b1;
        penable = 1'b1;
        pwrite  = write_mode;
        pwdata  = write_mode ? write_data : '0;
      end
      default: begin
        paddr   = '0;
        pselx   = '0;
        penable = '0;
        pwrite  = '0;
        pwdata  = '0;
      end
    endcase
  end
endmodule

