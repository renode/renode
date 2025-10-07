//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

`timescale 1ns / 1ps

import renode_pkg::renode_runtime, renode_pkg::LogWarning;

module renode_apb3_requester #(int RenodeToCosimIndex = 0) (
    ref renode_runtime runtime,
    renode_apb3_if bus
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


  always @(runtime.controllers[RenodeToCosimIndex].reset_assert_request) begin
    write_address = '0;
    read_address = '0;
    write_data = '0;
    start_transaction = '0;
    write_mode = '0;
    rst_n = 0;
    // The reset takes 2 cycles to prevent a race condition without usage of a non-blocking assigment.
    repeat (2) @(posedge clk);
    runtime.controllers[RenodeToCosimIndex].reset_assert_respond();
  end

  always @(runtime.controllers[RenodeToCosimIndex].reset_deassert_request) begin
    rst_n = 1;
    // There is one more wait for the clock edges to be sure that all modules aren't in a reset state.
    repeat (2) @(posedge clk);
    runtime.controllers[RenodeToCosimIndex].reset_deassert_respond();
  end

  // Internal state
  typedef enum {
    S_IDLE,
    S_SETUP,
    S_ACCESS
  } state_t;
  state_t state;

  //
  // Waveform generation
  //

  always @(runtime.controllers[RenodeToCosimIndex].read_transaction_request) begin
    integer transaction_width;

    if(!renode_pkg::is_access_aligned(runtime.controllers[RenodeToCosimIndex].read_transaction_address, runtime.controllers[RenodeToCosimIndex].read_transaction_data_bits)) begin
        runtime.connection.log(LogWarning, "Unaligned access on APB bus results in unpredictable behavior");
    end
    transaction_width = renode_pkg::valid_bits_to_transaction_width(runtime.controllers[RenodeToCosimIndex].read_transaction_data_bits);
    if (bus.DataWidth > transaction_width) begin
      runtime.connection.log(LogWarning,
          $sformatf("Bus bus.bus.DataWidth is (%d) > transaction width (%d), MSB will be truncated.", bus.DataWidth, transaction_width));
    end else if (bus.DataWidth < transaction_width) begin
      runtime.connection.log(LogWarning,
          $sformatf("Bus bus.bus.DataWidth is (%d) < transaction width (%d), MSB will be zero-extended.", bus.DataWidth, transaction_width));
    end

    read_address = address_t'(runtime.controllers[RenodeToCosimIndex].read_transaction_address);
    write_mode = 1'b0;
    start_transaction = 1'b1;
    @(posedge clk) start_transaction <= 1'b0;
  end

  always @(runtime.controllers[RenodeToCosimIndex].write_transaction_request) begin
    integer transaction_width;

    if(!renode_pkg::is_access_aligned(runtime.controllers[RenodeToCosimIndex].write_transaction_address, runtime.controllers[RenodeToCosimIndex].write_transaction_data_bits)) begin
        runtime.connection.log(LogWarning, "Unaligned access on APB bus results in unpredictable behavior");
    end
    transaction_width = renode_pkg::valid_bits_to_transaction_width(runtime.controllers[RenodeToCosimIndex].write_transaction_data_bits);
    if (bus.DataWidth > transaction_width) begin
      runtime.connection.log(LogWarning,
          $sformatf("Bus bus.bus.DataWidth is (%d) > transaction width (%d), MSB will be truncated.", bus.DataWidth, transaction_width));
    end else if (bus.DataWidth < transaction_width) begin
      runtime.connection.log(LogWarning,
          $sformatf("Bus bus.bus.DataWidth is (%d) < transaction width (%d), MSB will be zero-extended.", bus.DataWidth, transaction_width));
    end

    write_address = address_t'(runtime.controllers[RenodeToCosimIndex].write_transaction_address);
    write_data = data_t'(runtime.controllers[RenodeToCosimIndex].write_transaction_data);
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
              runtime.controllers[RenodeToCosimIndex].write_respond(1'b0);  // Notify Renode that write is done
            end else begin
              runtime.controllers[RenodeToCosimIndex].read_respond(renode_pkg::data_t'(prdata), 1'b0);
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

