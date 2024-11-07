//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

`timescale 1ns / 1ps

package renode_pkg;
  typedef longint address_t;
  typedef longint data_t;

  typedef enum int {
    // The included file contains enumerators of the action type used by the Renode protocol.
    // The values must be in sync with ActionType from Renode (defined in C#).
    `include "renode_action_enumerators.svh"
  } action_e;

  typedef struct {
    action_e action;
    address_t address;
    data_t data;
  } message_t;

  typedef enum data_t {
    QuadWord = {64{1'b1}},
    DoubleWord = {32'b0, {32{1'b1}}},
    Word = {48'b0, {16{1'b1}}},
    Byte = {56'b0, {8{1'b1}}}
  } valid_bits_e;

  typedef enum int {
    LogNoisy = -1,
    LogDebug = 0,
    LogInfo = 1,
    LogWarning = 2,
    LogError = 3
  } log_level_e;

  import "DPI-C" function void renodeDPIConnect(
    int receiverPort,
    int senderPort,
    string address
  );

  import "DPI-C" function void renodeDPIDisconnect();

  import "DPI-C" function bit renodeDPIIsConnected();

  import "DPI-C" function bit renodeDPILog(
    int logLevel,
    string data
  );

  import "DPI-C" function bit renodeDPIReceive(
    output action_e action,
    output address_t address,
    output data_t data
  );

  import "DPI-C" function bit renodeDPISend(
    action_e action,
    address_t address,
    data_t data
  );

  import "DPI-C" function bit renodeDPISendToAsync(
    action_e action,
    address_t address,
    data_t data
  );

  function static bit is_access_aligned(address_t address, valid_bits_e valid_bits);
    case(valid_bits)
      Byte: return 1;
      Word: return address % 2 == 0;
      DoubleWord: return address % 4 == 0;
      QuadWord: return address % 8 == 0;
      default: return 0;
    endcase
  endfunction

  function static integer valid_bits_to_transaction_width(valid_bits_e valid_bits);
    case (valid_bits)
      QuadWord: return 64;
      DoubleWord: return 32;
      Word: return 16;
      Byte: return 8;
      default: begin
          $error($sformatf("Cannot determine transaction width for valid_bits %d", valid_bits));
          return 0;
      end
    endcase
  endfunction

  class renode_connection;
    semaphore exclusive_receive = new(1);

    function new();
      $timeformat(0, 9, "s", 0);
    endfunction

    function void connect(int receiver_port, int sender_port, string address);
      renodeDPIConnect(receiver_port, sender_port, address);
      if(is_connected())
        $display("Renode at %t: Connected using the socket based interface", $realtime);
      else
        $error("Renode at %t: Connection error", $realtime);
    endfunction

    function bit is_connected();
      return renodeDPIIsConnected();
    endfunction

    function void fatal_error(string message);
      string error_msg;
      error_msg = $sformatf("Renode at %t: Error! %s", $realtime, message);
      log(LogError, error_msg);
      disconnect();
      $error(error_msg);
      $finish;
    endfunction

    function void handle_message(message_t message, output bit is_handled);
      is_handled = 1;
      case (message.action)
        renode_pkg::invalidAction: ;  // Intentionally left blank
        renode_pkg::disconnect: handle_disconnect();
        default: is_handled = 0;
      endcase
    endfunction

    function void log(log_level_e log_level, string message);
`ifdef RENODE_DEBUG
      $display("Renode at %t logs: %s", $realtime, message);
`endif
      if(!renodeDPILog(log_level, message)) begin
        $display("Renode at %t: Unable to send the log: %s", $realtime, message);
      end
    endfunction

    function void receive(output message_t message);
      bit is_received = try_receive(message);
      if (!is_received) fatal_error("Unable to receive a message.");
    endfunction

    function bit try_receive(output message_t message);
      bit is_received = renodeDPIReceive(message.action, message.address, message.data);
      if(is_received) begin
`ifdef RENODE_DEBUG
      $display("Renode at %t: Received action %0s, address = 'h%h, data = 'h%h", $realtime, message.action.name(), message.address, message.data);
`endif
      end
      return is_received;
    endfunction

    function void send(message_t message);
`ifdef RENODE_DEBUG
      $display("Renode at %t: Sent action %0s, address = 'h%h, data = 'h%h", $realtime, message.action.name(), message.address, message.data);
`endif
      if (!renodeDPISend(message.action, message.address, message.data)) fatal_error("Unexpected channel disconnection");
    endfunction

    function void send_to_async_receiver(message_t message);
`ifdef RENODE_DEBUG
      $display("Renode at %t: Sent async action %0s, address = 'h%h, data = 'h%h", $realtime, message.action.name(), message.address, message.data);
`endif
      if (!renodeDPISendToAsync(message.action, message.address, message.data)) fatal_error("Unexpected channel disconnection");
    endfunction

    local function void disconnect();
      renodeDPIDisconnect();
    endfunction

    local function void handle_disconnect();
      send(message_t'{ok, 0, 0});
      disconnect();
`ifdef RENODE_DEBUG
      $display("Renode at %t: disconnected", $realtime);
`endif
    endfunction
  endclass

  class bus_connection;
    event reset_assert_request;
    event reset_assert_response;
    event reset_deassert_request;
    event reset_deassert_response;

    event read_transaction_request;
    event read_transaction_response;
    address_t read_transaction_address;
    data_t read_transaction_data;
    valid_bits_e read_transaction_data_bits;
    bit read_transaction_is_error;

    event write_transaction_request;
    event write_transaction_response;
    address_t write_transaction_address;
    data_t write_transaction_data;
    valid_bits_e write_transaction_data_bits;
    bit write_transaction_is_error;

    // Passing a class by a reference isn't supported by Verilator.
    // Events are indirectly triggered by tasks.
    task reset_assert();
      ->reset_assert_request;
      @(reset_assert_response);
    endtask

    task reset_assert_respond();
      ->reset_assert_response;
    endtask

    task reset_deassert();
      ->reset_deassert_request;
      @(reset_deassert_response);
    endtask

    task reset_deassert_respond();
      ->reset_deassert_response;
    endtask

    task read(address_t address, valid_bits_e data_bits, output data_t data, output bit is_error);
      read_transaction_address = address;
      read_transaction_data_bits = data_bits;
      ->read_transaction_request;
      @(read_transaction_response) begin
        data = read_transaction_data;
        is_error = read_transaction_is_error;
      end
    endtask

    task read_respond(data_t data, bit is_error);
      read_transaction_data = data;
      read_transaction_is_error = is_error;
      ->read_transaction_response;
    endtask

    task write(address_t address, valid_bits_e data_bits, data_t data, output bit is_error);
      write_transaction_address = address;
      write_transaction_data_bits = data_bits;
      write_transaction_data = data;
      ->write_transaction_request;
      @(write_transaction_response) begin
        is_error = write_transaction_is_error;
      end
    endtask

    task write_respond(bit is_error);
      write_transaction_is_error = is_error;
      ->write_transaction_response;
    endtask
  endclass

  // It's required to pass the whole instance to modules.
  // Passing single property triggers a null pointer dereference in Verilator.
  class renode_runtime;
    const string ReceiverPortArgName = "RENODE_RECEIVER_PORT";
    const string SenderPortArgName = "RENODE_SENDER_PORT";
    const string AddressArgName = "RENODE_ADDRESS";

    renode_connection connection = new();
    bus_connection controller = new();
    bus_connection peripheral = new();

    function void connect_plus_args();
      int receiver_port, sender_port;
      string address;
      if(!$value$plusargs({ReceiverPortArgName, "=%d"}, receiver_port)
        || !$value$plusargs({SenderPortArgName, "=%d"}, sender_port)
        || !$value$plusargs({AddressArgName, "=%s"}, address))
      begin
          $error("Please specify the +%s, +%s and +%s arguments in the command that invokes the simulation", ReceiverPortArgName, SenderPortArgName, AddressArgName);
      end
      else begin
        connection.connect(receiver_port, sender_port, address);
      end
    endfunction

    function bit is_connected();
      return connection.is_connected();
    endfunction
  endclass
endpackage
