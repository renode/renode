//
// Copyright (c) 2010-2023 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

module renode_interrupts #(
    int unsigned InterruptsCount = 1
) (
    input logic clk,
    logic [InterruptsCount-1:0] interrupts,
    renode_pkg::renode_connection connection
);
  logic [InterruptsCount-1:0] interrupts_prev;

  initial interrupts_prev = 0;
  bit in_reset = 0;

  task static reset_assert;
    in_reset = 1;
  endtask

  task static reset_deassert;
    in_reset = 0;
  endtask

  always @(posedge clk) begin
    if (!in_reset) begin
      for (int unsigned addr = 0; addr < InterruptsCount; addr++) begin
        if (interrupts[addr] != interrupts_prev[addr]) begin
          connection.send_to_async_receiver(renode_pkg::message_t'{
              renode_pkg::interrupt,
              renode_pkg::address_t'(addr),
              renode_pkg::data_t'(interrupts[addr])
            });
        end
      end
      interrupts_prev <= interrupts;
    end
  end
endmodule

