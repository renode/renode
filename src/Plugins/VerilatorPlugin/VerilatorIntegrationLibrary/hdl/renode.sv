//
// Copyright (c) 2010-2023 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

`ifndef RENODE_PKG_VH_
`define RENODE_PKG_VH_

package renode;
  typedef longint address_t;
  typedef longint data_t;

  typedef enum int {
`include "../src/renode_action_enumerators.txt"
  } action_e;

  typedef struct {
    action_e action;
    address_t address;
    data_t data;
  } message_t;

  import "DPI-C" function void renodeDPIConnect(
    int receiverPort,
    int senderPort,
    string address
  );

  import "DPI-C" function void renodeDPIDisconnect();

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

  class connection;
    function void connect(int receiver_port, int sender_port, string address);
      renodeDPIConnect(receiver_port, sender_port, address);
      $display("Renode at %t: Connected to using the socket based interface", $time);
    endfunction

    function void handle_message(message_t message);
      case (message.action)
        renode::invalidAction: ;  // Intentionally left blank
        renode::disconnect: disconnect();
        default:
        $display(
            "Renode at %t: Trying to handle the unsupported action (%0s)",
            $time,
            message.action.name()
        );
      endcase
    endfunction

    function void log(int log_level, string message);
      renodeDPILog(log_level, message);
    endfunction

    function bit receive(output message_t message);
      return renodeDPIReceive(message.action, message.address, message.data);
    endfunction

    function void send(message_t message);
      if (!renodeDPISend(message.action, message.address, message.data))
        $display("Renode at %t: Error! Unexpected channel disconnection", $time);
    endfunction

    function void sendToAsyncReceiver(message_t message);
      if (!renodeDPISendToAsync(message.action, message.address, message.data))
        $display("Renode at %t: Error! Unexpected channel disconnection", $time);
    endfunction

    local function void disconnect();
      send(message_t'{ok, 0, 0});
      renodeDPIDisconnect();
    endfunction
  endclass
endpackage

`endif
