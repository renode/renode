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

  task static reset_deassert;
    interrupts_prev = 0;
  endtask

  always @(clk) begin
    for (int unsigned addr = 0; addr < InterruptsCount; addr++) begin
      if (interrupts[addr] != interrupts_prev[addr]) begin
        connection.send_to_async_receiver(renode_pkg::message_t'{
            renode_pkg::interrupt,
            renode_pkg::data_t'(addr),
            renode_pkg::address_t'(interrupts[addr])
          });
      end
    end
    interrupts_prev <= interrupts;
  end
endmodule

