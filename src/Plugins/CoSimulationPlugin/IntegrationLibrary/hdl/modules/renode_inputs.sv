//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

`timescale 1ns / 1ps

import renode_pkg::renode_runtime;

module renode_inputs #(
    int unsigned InputsCount = 1
) (
    ref renode_runtime runtime,
    input logic clk,
    logic [InputsCount-1:0] inputs
);
  logic [InputsCount-1:0] inputs_prev;

  initial inputs_prev = 0;
  bit in_reset = 0;

  task static reset_assert;
    in_reset = 1;
  endtask

  task static reset_deassert;
    in_reset = 0;
  endtask

  always @(posedge clk) begin
    if (!in_reset) begin
      for (int unsigned addr = 0; addr < InputsCount; addr++) begin
        if (inputs[addr] != inputs_prev[addr]) begin
          runtime.connection.send_to_async_receiver(renode_pkg::message_t'{
              renode_pkg::interrupt,
              renode_pkg::address_t'(addr),
              renode_pkg::data_t'(inputs[addr])
            });
        end
      end
      inputs_prev <= inputs;
    end
  end
endmodule
