//
// Copyright (c) 2010-2023 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

`timescale 1ns / 1ps

import renode_pkg::renode_connection, renode_pkg::bus_connection;
import renode_pkg::message_t, renode_pkg::address_t, renode_pkg::data_t;

module renode #(
    int unsigned BusControllerTimeout = 100
) (
    input logic clk
);
  renode_connection connection = new();
  bus_connection bus_controller = new(connection);
  time renode_time = 0;

  task static receive_and_handle_message();
    message_t message;
    bit did_receive;

    // This task doesn't block elapse of a simulation time, when messages are being received and handled in an other place.
    if (connection.exclusive_receive.try_get() != 0) begin
      did_receive = connection.try_receive(message);
      connection.exclusive_receive.put();
      if (did_receive) handle_message(message);
    end
  endtask

  task static handle_message(message_t message);
    bit is_handled;

    is_handled = 1;
    case (message.action)
      renode_pkg::resetPeripheral: reset();
      renode_pkg::tickClock: sync_time(time'(message.data));
      renode_pkg::writeRequestDoubleWord: write_to_bus(message.address, message.data);
      renode_pkg::readRequestDoubleWord: read_from_bus(message.address);
      default: is_handled = 0;
    endcase

    if (!is_handled) connection.handle_message(message, is_handled);
    if (!is_handled) connection.log(renode_pkg::LogWarning, $sformatf("Trying to handle the unsupported action (%0s)", message.action.name()));
  endtask

  task static reset();
    // The reset just locks the connection without using it to avoid an unexpected behaviour.
    // It also prevents from a message handling in the receive_and_handle_message until a reset deassertion.
    connection.exclusive_receive.get();

    // The delay was added to avoid a race condition.
    // It may occure when an event is triggered before executing a wait for this event.
    // A non-blocking trigger, which is an alternative solution, isn't supported by Verilator.
    #1 fork
      bus_controller.reset_assert();
      begin
        if (BusPeripheralsCount > 0) begin
          bus_peripheral.reset_assert();
        end
      end
    join

    fork
      bus_controller.reset_deassert();
      gpio.reset_deassert();
      begin
        if (BusPeripheralsCount > 0) begin
          bus_peripheral.reset_deassert();
        end
      end
    join
    connection.exclusive_receive.put();
  endtask

  task static sync_time(time time_to_elapse);
    renode_time = renode_time + time_to_elapse;
    while ($time < renode_time) @(clk);

    connection.send_to_async_receiver(message_t'{renode_pkg::tickClock, 0, 0});
    connection.log(renode_pkg::LogDebug, $sformatf("Simulation time synced to %t", $realtime));
  endtask

  task automatic read_from_bus(address_t address);
    // This task is automatic to separate timeout handling between calls.
    data_t data = 0;
    bit is_error = 0;
    bit is_timeout = 0;

    fork
      begin
        repeat (BusControllerTimeout) @(posedge clk);
        is_timeout = 1;
      end
      begin
        bus_controller.read(address, data, is_error);
      end
    join_any

    if (is_error || is_timeout) connection.send(message_t'{renode_pkg::error, 0, 0});
    else connection.send(message_t'{renode_pkg::readRequest, address, data});
    if (is_timeout) connection.log(renode_pkg::LogDebug, "Bus read access timeout");
  endtask

  task automatic write_to_bus(address_t address, data_t data);
    // This task is automatic to separate timeout handling between calls.
    bit is_error = 0;
    bit is_timeout = 0;

    fork
      begin
        repeat (BusControllerTimeout) @(posedge clk);
        is_timeout = 1;
      end
      begin
        bus_controller.write(address, data, is_error);
      end
    join_any

    if (is_error || is_timeout) connection.send(message_t'{renode_pkg::error, 0, 0});
    else connection.send(message_t'{renode_pkg::ok, 0, 0});
    if (is_timeout) connection.log(renode_pkg::LogDebug, "Bus write access timeout");
  endtask
endmodule

