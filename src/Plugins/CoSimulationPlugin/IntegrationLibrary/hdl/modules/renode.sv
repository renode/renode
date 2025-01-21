//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

`timescale 1ns / 1ps

import renode_pkg::renode_runtime, renode_pkg::bus_connection, renode_pkg::renode_connection, renode_pkg::no_peripheral_index;
import renode_pkg::message_t, renode_pkg::address_t, renode_pkg::data_t, renode_pkg::valid_bits_e;

module renode #(
    int unsigned RenodeToCosimCount = 0,
    int unsigned CosimToRenodeCount = 0,
    int unsigned RenodeInputsCount = 1,
    int unsigned RenodeOutputsCount = 1
) (
    ref renode_runtime runtime,
    input logic clk,
    input logic [RenodeInputsCount-1:0] renode_inputs,
    output logic [RenodeOutputsCount-1:0] renode_outputs
);
  time renode_time = 0;

  event reset_assert_all;
  int reset_assert_done_count;
  event reset_assert_done;

  event reset_deassert_all;
  int reset_deassert_done_count;
  event reset_deassert_done;

  renode_inputs #(
      .InputsCount(RenodeInputsCount)
  ) gpio (
      .runtime(runtime),
      .clk(clk),
      .inputs(renode_inputs)
  );

  initial begin
    runtime.controllers = new[RenodeToCosimCount];
    foreach(runtime.controllers[i]) begin
      runtime.controllers[i] = new();
    end

    runtime.peripherals = new[CosimToRenodeCount];
    foreach(runtime.peripherals[i]) begin
      runtime.peripherals[i] = new();
    end
  end

  if(CosimToRenodeCount > 0) begin
    genvar i;
    for(i = 0; i < CosimToRenodeCount; i += 1) begin
      always @(runtime.peripherals[i].read_transaction_request) read_transaction(i);
      always @(runtime.peripherals[i].write_transaction_request) write_transaction(i);
      always @(reset_assert_all) runtime.peripherals[i].reset_assert();
      always @(runtime.peripherals[i].reset_assert_response) begin
          reset_assert_done_count++;
          if(reset_assert_done_count == (CosimToRenodeCount + RenodeToCosimCount)) begin
              ->reset_assert_done;
          end
      end
      always @(runtime.peripherals[i].reset_deassert_response) begin
          reset_deassert_done_count++;
          if(reset_deassert_done_count == (CosimToRenodeCount + RenodeToCosimCount)) begin
              ->reset_deassert_done;
          end
      end
      always @(reset_deassert_all) runtime.peripherals[i].reset_deassert();
    end
  end

  if(RenodeToCosimCount > 0) begin
    genvar i;
    for(i = 0; i < RenodeToCosimCount; i += 1) begin
      always @(reset_assert_all) runtime.controllers[i].reset_assert();
      always @(reset_deassert_all) runtime.controllers[i].reset_deassert();
      always @(runtime.controllers[i].reset_assert_response) begin
          reset_assert_done_count++;
          if(reset_assert_done_count == (CosimToRenodeCount + RenodeToCosimCount)) begin
              ->reset_assert_done;
          end
      end
      always @(runtime.controllers[i].reset_deassert_response) begin
          reset_deassert_done_count++;
          if(reset_deassert_done_count == (CosimToRenodeCount + RenodeToCosimCount)) begin
              ->reset_deassert_done;
          end
      end
    end
  end

  task static receive_and_handle_message();
    message_t message;
    bit did_receive;

    // This task doesn't block elapse of a simulation time, when messages are being received and handled in an other place.
    if (runtime.connection.exclusive_receive.try_get() != 0) begin
      did_receive = runtime.connection.try_receive(message);
      runtime.connection.exclusive_receive.put();
      if (did_receive) handle_message(message);
    end
  endtask

  task static handle_message(message_t message);
    bit is_handled;

    is_handled = 1;
    case (message.action)
      renode_pkg::resetPeripheral: reset();
      renode_pkg::tickClock: sync_time(time'(message.data));
      renode_pkg::interrupt: handle_renode_output(message.address, message.data[0]);
      renode_pkg::writeRequestQuadWord: write_to_bus(message.address, renode_pkg::QuadWord, message.data, message.peripheral_index);
      renode_pkg::writeRequestDoubleWord: write_to_bus(message.address, renode_pkg::DoubleWord, message.data, message.peripheral_index);
      renode_pkg::writeRequestWord: write_to_bus(message.address, renode_pkg::Word, message.data, message.peripheral_index);
      renode_pkg::writeRequestByte: write_to_bus(message.address, renode_pkg::Byte, message.data, message.peripheral_index);
      renode_pkg::readRequestQuadWord: read_from_bus(message.address, renode_pkg::QuadWord, message.peripheral_index);
      renode_pkg::readRequestDoubleWord: read_from_bus(message.address, renode_pkg::DoubleWord, message.peripheral_index);
      renode_pkg::readRequestWord: read_from_bus(message.address, renode_pkg::Word, message.peripheral_index);
      renode_pkg::readRequestByte: read_from_bus(message.address, renode_pkg::Byte, message.peripheral_index);
      default: is_handled = 0;
    endcase

    if (!is_handled) runtime.connection.handle_message(message, is_handled);
    if (!is_handled) runtime.connection.log(renode_pkg::LogWarning, $sformatf("Trying to handle the unsupported action (%0s)", message.action.name()));
  endtask

  task static reset();
    // Nothing to reset, return immediately.
    if(RenodeToCosimCount + CosimToRenodeCount == 0) return;

    // The reset just locks the connection without using it to avoid an unexpected behaviour.
    // It also prevents from a message handling in the receive_and_handle_message until a reset deassertion.
    runtime.connection.exclusive_receive.get();

    reset_assert_done_count = 0;
    #1 fork
        ->reset_assert_all;
        gpio.reset_assert();
    join

    @(reset_assert_done);

    // It's required to make values of all signals known (different than `x`) before a deassertion of resets.
    // The assignment to renode_outputs is an equivalent of a reset assertion.
    renode_outputs = 0;

    reset_deassert_done_count = 0;
    fork
      ->reset_deassert_all;
      gpio.reset_deassert();
    join

    @(reset_deassert_done);

    runtime.connection.exclusive_receive.put();
  endtask

  task static sync_time(time time_to_elapse);
    renode_time = renode_time + time_to_elapse;
    while ($time < renode_time) @(clk);

    runtime.connection.send_to_async_receiver(message_t'{renode_pkg::tickClock, 0, 0, renode_pkg::no_peripheral_index});
    runtime.connection.log(renode_pkg::LogNoisy, $sformatf("Simulation time synced to %t", $realtime));
  endtask

  task automatic read_from_bus(address_t address, valid_bits_e data_bits, int peripheral_index);
    data_t data = 0;
    bit is_error = 0;
    runtime.controllers[peripheral_index].read(address, data_bits, data, is_error);

    if (is_error) runtime.connection.send(message_t'{renode_pkg::error, 0, 0, peripheral_index});
    else runtime.connection.send(message_t'{renode_pkg::readRequest, address, data, peripheral_index});
  endtask

  task automatic write_to_bus(address_t address, valid_bits_e data_bits, data_t data, int peripheral_index);
    bit is_error = 0;
    runtime.controllers[peripheral_index].write(address, data_bits, data, is_error);

    if (is_error) runtime.connection.send(message_t'{renode_pkg::error, 0, 0, peripheral_index});
    else runtime.connection.send(message_t'{renode_pkg::ok, 0, 0, peripheral_index});
  endtask

  task automatic read_transaction(int peripheral_index);
    message_t message;

    case (runtime.peripherals[peripheral_index].read_transaction_data_bits)
      renode_pkg::Byte: message.action = renode_pkg::getByte;
      renode_pkg::Word: message.action = renode_pkg::getWord;
      renode_pkg::DoubleWord: message.action = renode_pkg::getDoubleWord;
      renode_pkg::QuadWord: message.action = renode_pkg::getQuadWord;
      default: begin
        runtime.connection.fatal_error($sformatf("Renode doesn't support access with the 'b%b mask from a bus controller.", runtime.peripherals[peripheral_index].read_transaction_data_bits));
        runtime.peripherals[peripheral_index].read_respond(0, 1);
        return;
      end
    endcase
    message.address = runtime.peripherals[peripheral_index].read_transaction_address;
    message.data = 0;

    runtime.connection.exclusive_receive.get();
    if(!runtime.connection.is_connected()) begin
        runtime.connection.exclusive_receive.put();
        return;
    end

    runtime.connection.send_to_async_receiver(message);

    runtime.connection.receive(message);
    while (message.action != renode_pkg::writeRequest) begin
      handle_message(message);
      if(message.action == renode_pkg::disconnect) break;
      runtime.connection.receive(message);
    end

    runtime.connection.exclusive_receive.put();
    runtime.peripherals[peripheral_index].read_respond(message.data, 0);
  endtask

  task automatic write_transaction(int peripheral_index);
    message_t message;

    case (runtime.peripherals[peripheral_index].write_transaction_data_bits)
      renode_pkg::Byte: message.action = renode_pkg::pushByte;
      renode_pkg::Word: message.action = renode_pkg::pushWord;
      renode_pkg::DoubleWord: message.action = renode_pkg::pushDoubleWord;
      renode_pkg::QuadWord: message.action = renode_pkg::pushQuadWord;
      default: begin
        runtime.connection.fatal_error($sformatf("Renode doesn't support access with the 'b%b mask from a bus controller.", runtime.peripherals[peripheral_index].read_transaction_data_bits));
        runtime.peripherals[peripheral_index].write_respond(1);
        return;
      end
    endcase
    message.address = runtime.peripherals[peripheral_index].write_transaction_address;
    message.data = runtime.peripherals[peripheral_index].write_transaction_data;

    runtime.connection.exclusive_receive.get();
    if(!runtime.connection.is_connected()) begin
        runtime.connection.exclusive_receive.put();
        return;
    end

    runtime.connection.send_to_async_receiver(message);
    runtime.connection.receive(message);
    while (message.action != renode_pkg::pushConfirmation) begin
      handle_message(message);
      if(message.action == renode_pkg::disconnect) break;
      runtime.connection.receive(message);
    end

    runtime.connection.exclusive_receive.put();

    runtime.peripherals[peripheral_index].write_respond(0);
  endtask

  // calculate number of bits needed to hold the output number
  `define max(a,b) (a > b) ? a : b
  localparam RenodeOutputsCountWidth = `max($clog2(RenodeOutputsCount), 1);

  task automatic handle_renode_output(address_t number, bit value);
    if (number >= 64'(RenodeOutputsCount)) begin
      runtime.connection.log(renode_pkg::LogWarning, $sformatf("Output %0d is out of range of [0;%0d]", number, RenodeOutputsCount - 1));
      runtime.connection.send(message_t'{renode_pkg::error, 0, 0, renode_pkg::no_peripheral_index});
    end

    @(posedge clk);
    renode_outputs[number[RenodeOutputsCountWidth-1:0]] <= value;

    runtime.connection.send(message_t'{renode_pkg::ok, 0, 0, renode_pkg::no_peripheral_index});
  endtask
endmodule
