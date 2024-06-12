//
// Copyright (c) 2010-2023 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

`timescale 1ns / 1ps

import renode_pkg::renode_connection, renode_pkg::bus_connection;
import renode_pkg::message_t, renode_pkg::address_t, renode_pkg::data_t, renode_pkg::valid_bits_e;

module renode #(
    int unsigned BusControllersCount = 0,
    int unsigned BusPeripheralsCount = 0,
    int unsigned InterruptsCount = 1
) (
    input logic clk,
    input logic [InterruptsCount-1:0] interrupts
);
  renode_connection connection = new();
  bus_connection bus_controller = new(connection);
  bus_connection bus_peripheral = new(connection);
  time renode_time = 0;

  renode_interrupts #(
      .InterruptsCount(InterruptsCount)
  ) gpio (
      .clk(clk),
      .interrupts(interrupts),
      .connection(connection)
  );

  always @(bus_peripheral.read_transaction_request) read_transaction();
  always @(bus_peripheral.write_transaction_request) write_transaction();

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
      renode_pkg::writeRequestQuadWord: write_to_bus(message.address, renode_pkg::QuadWord, message.data);
      renode_pkg::writeRequestDoubleWord: write_to_bus(message.address, renode_pkg::DoubleWord, message.data);
      renode_pkg::writeRequestWord: write_to_bus(message.address, renode_pkg::Word, message.data);
      renode_pkg::writeRequestByte: write_to_bus(message.address, renode_pkg::Byte, message.data);
      renode_pkg::readRequestQuadWord: read_from_bus(message.address, renode_pkg::QuadWord);
      renode_pkg::readRequestDoubleWord: read_from_bus(message.address, renode_pkg::DoubleWord);
      renode_pkg::readRequestWord: read_from_bus(message.address, renode_pkg::Word);
      renode_pkg::readRequestByte: read_from_bus(message.address, renode_pkg::Byte);
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
      begin
        if (BusPeripheralsCount > 0)
          bus_peripheral.reset_assert();
      end
      begin
        if (BusControllersCount > 0)
          bus_controller.reset_assert();
      end
      gpio.reset_assert();
    join

    fork
      begin
        if (BusPeripheralsCount > 0)
          bus_peripheral.reset_deassert();
      end
      begin
        if (BusControllersCount > 0)
          bus_controller.reset_deassert();
      end
      gpio.reset_deassert();
    join

    connection.exclusive_receive.put();
  endtask

  task static sync_time(time time_to_elapse);
    renode_time = renode_time + time_to_elapse;
    while ($time < renode_time) @(clk);

    connection.send_to_async_receiver(message_t'{renode_pkg::tickClock, 0, 0});
    connection.log(renode_pkg::LogNoisy, $sformatf("Simulation time synced to %t", $realtime));
  endtask

  task automatic read_from_bus(address_t address, valid_bits_e data_bits);
    data_t data = 0;
    bit is_error = 0;
    bus_controller.read(address, data_bits, data, is_error);

    if (is_error) connection.send(message_t'{renode_pkg::error, 0, 0});
    else connection.send(message_t'{renode_pkg::readRequest, address, data});
  endtask

  task automatic write_to_bus(address_t address, valid_bits_e data_bits, data_t data);
    bit is_error = 0;
    bus_controller.write(address, data_bits, data, is_error);

    if (is_error) connection.send(message_t'{renode_pkg::error, 0, 0});
    else connection.send(message_t'{renode_pkg::ok, 0, 0});
  endtask

  task static read_transaction();
    message_t message;

    case (bus_peripheral.read_transaction_data_bits)
      renode_pkg::Byte: message.action = renode_pkg::getByte;
      renode_pkg::Word: message.action = renode_pkg::getWord;
      renode_pkg::DoubleWord: message.action = renode_pkg::getDoubleWord;
      renode_pkg::QuadWord: message.action = renode_pkg::getQuadWord;
      default: begin
        connection.fatal_error($sformatf("Renode doesn't support access with the 'b%b mask from a bus controller.", bus_peripheral.read_transaction_data_bits));
        bus_peripheral.read_respond(0, 1);
        return;
      end
    endcase
    message.address = bus_peripheral.read_transaction_address;
    message.data = 0;

    connection.exclusive_receive.get();

    connection.send_to_async_receiver(message);

    connection.receive(message);
    while (message.action != renode_pkg::writeRequest) begin
      handle_message(message);
      connection.receive(message);
    end

    connection.exclusive_receive.put();
    bus_peripheral.read_respond(message.data, 0);
  endtask

  task static write_transaction();
    message_t message;

    case (bus_peripheral.write_transaction_data_bits)
      renode_pkg::Byte: message.action = renode_pkg::pushByte;
      renode_pkg::Word: message.action = renode_pkg::pushWord;
      renode_pkg::DoubleWord: message.action = renode_pkg::pushDoubleWord;
      renode_pkg::QuadWord: message.action = renode_pkg::pushQuadWord;
      default: begin
        connection.fatal_error($sformatf("Renode doesn't support access with the 'b%b mask from a bus controller.", bus_peripheral.read_transaction_data_bits));
        bus_peripheral.write_respond(1);
        return;
      end
    endcase
    message.address = bus_peripheral.write_transaction_address;
    message.data = bus_peripheral.write_transaction_data;

    connection.exclusive_receive.get();

    connection.send_to_async_receiver(message);
    connection.receive(message);
    while (message.action != renode_pkg::pushConfirmation) begin
      handle_message(message);
      connection.receive(message);
    end

    connection.exclusive_receive.put();

    bus_peripheral.write_respond(0);
  endtask
endmodule
