//
// Copyright (c) 2010-2023 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

package renode_pkg;
  typedef longint address_t;
  typedef longint data_t;

  typedef enum int {
    // The included file contains enumerators of the action type used by the Renode protocol.
    // The values must be in sync with ActionType from Renode (defined in C#).
    `include "../src/renode_action_enumerators.txt"
  } action_e;

  typedef struct {
    action_e action;
    address_t address;
    data_t data;
  } message_t;

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

  import "DPI-C" function void renodeDPILog(
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

  class renode_connection;
    semaphore exclusive_receive = new(1);

    function new();
      $timeformat(0, 9, "s", 0);
    endfunction

    function void connect(int receiver_port, int sender_port, string address);
      renodeDPIConnect(receiver_port, sender_port, address);
      $display("Renode at %t: Connected using the socket based interface", $realtime);
    endfunction

    function bit is_connected();
      return renodeDPIIsConnected();
    endfunction

    function void fatal_error(string message);
      disconnect();
      $error("Renode at %t: Error! %s", $realtime, message);
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
      renodeDPILog(log_level, message);
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
      if (!renodeDPISend(message.action, message.address, message.data)) fatal_error("Unexpected channel disconnection");
    endfunction

    function void send_to_async_receiver(message_t message);
      if (!renodeDPISendToAsync(message.action, message.address, message.data)) fatal_error("Unexpected channel disconnection");
    endfunction

    local function void disconnect();
      renodeDPIDisconnect();
    endfunction

    local function void handle_disconnect();
      send(message_t'{ok, 0, 0});
      disconnect();
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
    bit read_transaction_is_error;

    event write_transaction_request;
    event write_transaction_response;
    address_t write_transaction_address;
    data_t write_transaction_data;
    bit write_transaction_is_error;

    renode_connection remote_connection;

    function new(renode_connection remote_connection);
      this.remote_connection = remote_connection;
    endfunction

    function void fatal_error(string message);
      remote_connection.fatal_error(message);
    endfunction

    function void log_warning(string message);
      remote_connection.log(LogWarning, message);
    endfunction

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

    task read(address_t address, output data_t data, output bit is_error);
      read_transaction_address = address;
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

    task write(address_t address, data_t data, output bit is_error);
      write_transaction_address = address;
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
endpackage

