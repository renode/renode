//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

`timescale 1ns / 1ps

import renode_pkg::renode_runtime, renode_pkg::LogWarning;

module renode_apb3_completer #(
    parameter int unsigned OutputLatency = 0
) (
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

  assign paddr = bus.paddr;
  assign pselx = bus.pselx;
  assign penable = bus.penable;
  assign pwrite = bus.pwrite;
  assign pwdata = bus.pwdata;

  assign bus.pready = pready;
  assign bus.prdata = prdata;
  assign bus.pslverr = pslverr;

  // Connection initiated reset
  always @(runtime.peripheral.reset_assert_request) begin
    rst_n = 0;
    // The reset takes 2 cycles to prevent a race condition without usage of a non-blocking assigment.
    repeat (2) @(posedge clk);
    runtime.peripheral.reset_assert_respond();
  end

  always @(runtime.peripheral.reset_deassert_request) begin
    rst_n = 1;
    // There is one more wait for the clock edges to be sure that all modules aren't in a reset state.
    repeat (2) @(posedge clk);
    runtime.peripheral.reset_deassert_respond();
  end

  renode_pkg::valid_bits_e valid_bits;
  assign valid_bits = renode_pkg::valid_bits_e'((1 << bus.DataWidth) - 1);

  //
  // APB3 Completer
  //

  bit is_error;
  renode_pkg::data_t prdata_int;

  // Internal state
  typedef enum {
    STATE_IDLE,
    STATE_ACCESS
  } state_t;
  state_t peripheral_state;
  state_t peripheral_state_next;

  // Next state logic
  always_comb begin : proc_fsm_next_state
    case (peripheral_state)
      STATE_IDLE: begin
        if (pselx && !penable) begin
          peripheral_state_next = STATE_ACCESS;
        end
      end
      STATE_ACCESS: begin
        peripheral_state_next = STATE_IDLE;
      end
      default: begin
        peripheral_state_next = STATE_IDLE;
      end
    endcase
  end

  // FSM logic
  always_ff @(posedge clk or negedge rst_n) begin : proc_fsm
    if (rst_n == 1'b0) begin
      peripheral_state <= STATE_IDLE;
    end else begin
      peripheral_state <= peripheral_state_next;

      // Write Enable logic: write data to memory in Renode
      if (pselx && penable && pwrite) begin
        // Workaround::Bug::Verilator::Task call inside of always block requires using fork...join
        fork
          begin
            runtime.peripheral.write(renode_pkg::address_t'(paddr), valid_bits, renode_pkg::data_t'(pwdata),
                             is_error);
            if (is_error) begin
              runtime.connection.log(LogWarning, "Renode connection write transfer was unable to complete");
            end
          end
        join
      end

      // Read Enable logic: read data from memory in Renode
      if (pselx && !penable && !pwrite) begin
        // Workaround::Bug::Verilator::Task call inside of always block requires using fork...join
        fork
          begin
            // The runtime.peripheral.read call may cause elapse of a simulation time.
            runtime.peripheral.read(renode_pkg::address_t'(paddr), valid_bits, prdata_int, is_error);
            if (is_error) begin
              runtime.connection.log(LogWarning, "Renode connection read transfer was unable to complete");
            end
          end
        join
      end else begin
        prdata_int <= '0;
      end
    end
  end

  //
  // Generate artificial delay to the {PRDATA,PREADY} signals
  // Useful to validate wait states, by default is turned off.
  //
  genvar i;
  generate
    if (OutputLatency == 0) begin : gen_latency_0
      assign prdata = data_t'(prdata_int);
      assign pready = (peripheral_state == STATE_ACCESS);
    end else begin : gen_latency_gt_0
      data_t prdata_reg[OutputLatency];
      data_t pready_reg[OutputLatency];
      for (i = 0; i < OutputLatency; i++) begin : gen_output_registers
        if (i == 0) begin : gen_i_eq_0
          always_ff @(posedge clk or negedge rst_n) begin : proc_first_reg
            prdata_reg[i] <= prdata_int;
            pready_reg[i] <= (peripheral_state == STATE_ACCESS);
          end
        end else begin: gen_i_neq_0
          always_ff @(posedge clk or negedge rst_n) begin : proc_latency_ith
            prdata_reg[i] <= prdata_reg[i-1];
            pready_reg[i] <= pready_reg[i-1];
          end
        end
      end
      assign prdata = prdata_reg[OutputLatency-1];
      assign pready = pready_reg[OutputLatency-1];
    end
  endgenerate

endmodule

