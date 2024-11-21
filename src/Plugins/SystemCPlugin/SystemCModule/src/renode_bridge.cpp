//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#include "renode_bridge.h"

#include <cstdint>
#include <cstdlib>
#include <chrono>
#include <thread>

#include "socket-cpp/Socket/TCPClient.h"

// ================================================================================
//  > Communication protocol
// ================================================================================

// Forward socket: Request from Renode, Response from SystemC
// Backward socket: Request from SystemC, Response From Renode

enum renode_action : uint8_t {
  INIT = 0,
  // Socket: forward only
  // Init message received for the second time signifies Renode terminated and
  // the process should exit. Request:
  //     data_length: ignored
  //     address: ignored
  //     connection_index: ignored
  //     payload: time synchronization granularity in us
  //       TIMESYNC messages will be sent with this period. This does NOT
  //       guarantee that the processes will never desynchronize by more than
  //       this amount.
  // Response:
  //      Identical to the request message.
  READ = 1,
  // Socket: forward, backward
  // Request:
  //     data_length: number of bytes to read [1, 8]
  //     address: address to read from, in target's address space payload: value
  //     to write connection_index: 0 for SystemBus, [1, NUM_DIRECT_CONNECTIONS]
  //     for direct connection
  // Response:
  //     address: duration of transaction in us
  //     payload: read value
  //     Otherwise identical to the request message.
  WRITE = 2,
  // Socket: forward, backward
  // Request:
  //     data_length: number of bytes to write [1, 8].
  //     address: address to write to, in target's address space
  //     connection_index: 0 for SystemBus, [1, NUM_DIRECT_CONNECTIONS] for
  //     direct connection payload: value to write
  // Response:
  //     address: duration of transaction in us
  //     Otherwise identical to the request message.
  TIMESYNC = 3,
  // Socket: forward only
  // Request:
  //     data_length: ignored
  //     address: ignored
  //     connection_index: ignored
  // Response:
  //     payload: current target virtual time in microseconds
  //     Otherwise identical to the request message.
  GPIOWRITE = 4,
  // Socket: forward, backward
  // Request:
  //     data_length: ignored
  //     address: ignored
  //     connection_index: ignored
  //     payload: state of GPIO bitfield
  // Response:
  //     Identical to the request message.
  RESET = 5,
  // Socket: forward
  // Request:
  //     data_length: ignored
  //     address: ignored
  //     connection_index: ignored
  //     payload: ignored
  // Response:
  //     Identical to the request message.
};

#pragma pack(push, 1)
struct renode_message {
  renode_action action;
  uint8_t data_length;
  uint8_t connection_index;
  uint64_t address;
  uint64_t payload;
};
#pragma pack(pop)

// ================================================================================
//  > Debug printing
// ================================================================================

static void print_renode_message(renode_message *message) {
  if (message->action == TIMESYNC)
    return;
  uint64_t thread_id = 0;
  { // Get a cross-platform thread identifier
    std::hash<std::thread::id> hasher;
    thread_id = hasher(std::this_thread::get_id());
  }
  printf("[0x%08lX][RENODE MESSAGE] Action: ", thread_id);
  switch (message->action) {
  case INIT:
    printf("INIT");
    break;
  case READ:
    printf("READ");
    break;
  case WRITE:
    printf("WRITE");
    break;
  case TIMESYNC:
    printf("TIMESYNC");
    break;
  case GPIOWRITE:
    printf("GPIOWRITE");
    break;
  case RESET:
    printf("RESET");
    break;
  default:
    printf("INVALID");
  }
  printf(" | Address: 0x%08lX", message->address);
  printf(" | Payload: 0x%08lX", message->payload);
  printf(" | ConnIdx: %u\n", message->connection_index);
}

static void print_transaction_status(tlm::tlm_generic_payload *payload) {
  tlm::tlm_response_status status = payload->get_response_status();
  std::string response_string = payload->get_response_string();
  printf("Renode transport status: %s\n", response_string.c_str());
}

// ================================================================================
//  > Renode Bridge SystemC module
// ================================================================================

static void initialize_payload(tlm::tlm_generic_payload *payload,
                               const renode_message *message, uint8_t *data) {
  tlm::tlm_command command = tlm::TLM_IGNORE_COMMAND;
  switch (message->action) {
  case WRITE:
    command = tlm::TLM_WRITE_COMMAND;
    break;
  case READ:
    command = tlm::TLM_READ_COMMAND;
    break;
  default:
    assert(!"Only WRITE and READ messages should initialize TLM payload");
  }

  payload->set_command(command);
  // Right now the address visible to SystemC is directly the offset
  // from Renode; i. e. if we write to address 0x9000100 and the peripheral
  // address is 0x9000000, then address in SystemC will be 0x100.
  payload->set_address(message->address);
  payload->set_data_ptr(data);
  payload->set_data_length(message->data_length);
  payload->set_byte_enable_ptr(nullptr);
  payload->set_byte_enable_length(0);
  payload->set_streaming_width(message->data_length);
  payload->set_dmi_allowed(false);
  payload->set_response_status(tlm::TLM_INCOMPLETE_RESPONSE);
}

static bool initialize_connection(CTCPClient *connection,
                                  renode_message *message,
                                  int64_t *out_max_desync_us) {
  // Receive INIT message from Renode and use it to setup connection, e. g.
  // time synchronization period.
  // This is done during SystemC elaboration, once per lifetime of the module.
  int nread = connection->Receive((char *)message, sizeof(renode_message));
  if (nread <= 0) {
    return false;
  }

#ifdef VERBOSE
  print_renode_message(message);
#endif

  if (message->action != renode_action::INIT) {
    fprintf(stderr, "Renode bridge connection error: missing INIT action.\n");
    return false;
  }
  *out_max_desync_us = static_cast<int64_t>(message->payload);

  // Acknowledge initialization is done.
  connection->Send((char *)message, sizeof(renode_message));
#ifdef VERBOSE
  printf("Connection to Renode initialized with timesync period %lu us.\n",
         *out_max_desync_us);
#endif
  return true;
}

static uint64_t sc_time_to_us(sc_core::sc_time time) {
  // Converts sc_time to microseconds count.
  return static_cast<int64_t>(time.to_seconds() * 1000000.0);
}

static uint64_t
perform_transaction(renode_bridge::renode_bus_initiator_socket &socket,
                    tlm::tlm_generic_payload *payload) {
  sc_core::sc_time delay = sc_core::SC_ZERO_TIME;
  socket->b_transport(*payload, delay);
#ifdef VERBOSE
  print_transaction_status(payload);
#endif
  return sc_time_to_us(delay);
}

static void terminate_simulation(int exitstatus) {
  sc_core::sc_stop();
  exit(exitstatus);
}

static void connect_with_retry(CTCPClient* socket, const char* address, const char* port) {
  constexpr uint32_t max_retry_s = 10;
  constexpr uint32_t retry_interval_s = 2;

  uint32_t retry_s = 0;
  while (!socket->Connect(address, port)) {
    fprintf(stderr, "Failed to connect to Renode, retrying in %us...\n", retry_interval_s);
    std::this_thread::sleep_for(std::chrono::seconds(retry_interval_s));
    retry_s += retry_interval_s;
    if(retry_s >= max_retry_s) {
        fprintf(stderr, "Maximum timeout reached. Failed to initialize Renode connection. Aborting.\n");
        terminate_simulation(1);
    }
  }
}

SC_HAS_PROCESS(renode_bridge);
renode_bridge::renode_bridge(sc_core::sc_module_name name, const char *address,
                             const char *port)
    : sc_module(name), initiator_socket("initiator_socket"), fw_connection_initialized(false) {
  SC_THREAD(forward_loop);
  SC_THREAD(on_port_gpio);
  for (int i = 0; i < NUM_GPIO; ++i) {
    sensitive << gpio_ports_in[i];
  }

  bus_target_fw_handler.initialize(this, 0);

  target_socket.bind(bus_target_fw_handler.socket);
  for (int i = 0; i < NUM_DIRECT_CONNECTIONS; ++i) {
    dc_initiators[i].initialize(this);
    dc_targets[i].initialize(this, i + 1);
    direct_connection_targets[i].bind(dc_targets[i]);
    direct_connection_initiators[i].bind(dc_initiators[i]);
  }

  bus_initiator_bw_handler.initialize(this);
  initiator_socket.bind(bus_initiator_bw_handler);

  payload.reset(new tlm::tlm_generic_payload());

  forward_connection.reset(new CTCPClient(NULL, ASocket::NO_FLAGS));
  connect_with_retry(forward_connection.get(), address, port);

  backward_connection.reset(new CTCPClient(NULL, ASocket::NO_FLAGS));
  connect_with_retry(backward_connection.get(), address, port);
}

renode_bridge::~renode_bridge() {
  forward_connection->Disconnect();
  backward_connection->Disconnect();
}

void renode_bridge::forward_loop() {
  // Processing of requests initiated by Renode.
  uint8_t data[8] = {};

  renode_message message;

  int64_t max_desync_us;
  if (!initialize_connection(forward_connection.get(), &message,
                             &max_desync_us)) {
    fprintf(stderr, "Failed to initialize Renode connection. Aborting.\n");
    terminate_simulation(1);
    return;
  }
  fw_connection_initialized = true;

  while (true) {
    memset(data, 0, sizeof(data));

    int nread =
        forward_connection->Receive((char *)&message, sizeof(renode_message));
    if (nread <= 0) {
#ifdef VERBOSE
      printf("Connection to Renode closed.\n");
#endif
      break;
    }

#ifdef VERBOSE
    print_renode_message(&message);
#endif

    // Choose the appropriate initiator socket to initiate the transaction with.
    renode_bus_initiator_socket *initiator_socket = nullptr;
    if (message.connection_index > NUM_DIRECT_CONNECTIONS) {
      fprintf(stderr,
              "Invalid connection_index %u, exceeds available number of direct "
              "connections (%u)\n",
              message.connection_index, NUM_DIRECT_CONNECTIONS);
      return;
    }

    if (message.connection_index == 0) {
      initiator_socket = &this->initiator_socket;
    } else {
      initiator_socket =
          &this->direct_connection_initiators[message.connection_index - 1];
    }

    switch (message.action) {
    case renode_action::WRITE: {
      initialize_payload(payload.get(), &message, data);

      *((uint64_t *)data) = message.payload;

      uint64_t delay = perform_transaction(*initiator_socket, payload.get());

      // NOTE: address field is re-used here to pass timing information.
      message.address = delay;
      forward_connection->Send((char *)&message, sizeof(renode_message));

      wait(sc_core::SC_ZERO_TIME);
    } break;
    case renode_action::READ: {
      initialize_payload(payload.get(), &message, data);

      uint64_t delay = perform_transaction(*initiator_socket, payload.get());

      // NOTE: address field is re-used here to pass timing information.
      message.address = delay;
      message.payload = *((uint64_t *)data);
      forward_connection->Send((char *)&message, sizeof(renode_message));
      wait(sc_core::SC_ZERO_TIME);
    } break;
    case renode_action::TIMESYNC: {
      // Renode drives the simulation time. This module never leaves the delta
      // cycle loop until a TIMESYNC with future time is received. It then waits
      // for the time difference between current virtual time and time from
      // TIMESYNC, allowing the SystemC simulation to progress in time. This is
      // effectively a synchronization barrier.
      int64_t systemc_time_us = sc_time_to_us(sc_core::sc_time_stamp());
      int64_t renode_time_us = (int64_t)message.payload;

      int64_t dt = renode_time_us - systemc_time_us;
      message.payload = systemc_time_us;
      if (dt > max_desync_us) {
        wait(dt, sc_core::SC_US);
      }
      message.payload = sc_time_to_us(sc_core::sc_time_stamp());
      forward_connection->Send((char *)&message, sizeof(renode_message));
    } break;
    case renode_action::GPIOWRITE: {
      for (int i = 0; i < NUM_GPIO; ++i) {
        sc_core::sc_interface *interface = gpio_ports_out[i].get_interface();
        if (interface != nullptr) {
          gpio_ports_out[i]->write((message.payload & (1 << i)) != 0);
        }
      }
      forward_connection->Send((char *)&message, sizeof(renode_message));
    } break;
    case renode_action::INIT: {
      terminate_simulation(0);
    } break;
    case renode_action::RESET: {
      sc_core::sc_interface *interface = reset.get_interface();
      if (interface != nullptr) {
        reset->write(true);
      }
      forward_connection->Send((char *)&message, sizeof(renode_message));
    } break;
    default:
      fprintf(stderr, "Malformed message received from Renode - terminating simulation.\n");
      terminate_simulation(1);
    }
  }
}

void renode_bridge::on_port_gpio() {
  while (true) {
    // Wait for a change in any of the GPIO ports.
    wait();

    uint64_t gpio_state = 0;
    for (int i = 0; i < NUM_GPIO; ++i) {
      sc_core::sc_interface *interface = gpio_ports_in[i].get_interface();
      if (interface != nullptr) {
        if (gpio_ports_in[i]->read()) {
          gpio_state |= (1ull << i);
        } else {
          gpio_state &= ~(1ull << i);
        }
      }
    }

    renode_message message = {};
    message.action = renode_action::GPIOWRITE;
    message.payload = gpio_state;

    backward_connection->Send((char *)&message, sizeof(renode_message));
    // Response is ignored.
    backward_connection->Receive((char *)&message, sizeof(renode_message));
  }
}

void renode_bridge::service_backward_request(tlm::tlm_generic_payload &payload,
                                             uint8_t connection_idx,
                                             sc_core::sc_time &delay) {
  unsigned int bytes_done = 0;
  unsigned int bytes_remaining = payload.get_data_length();
  renode_message message = {};
  if (payload.is_read()) {
    message.action = renode_action::READ;
  } else if (payload.is_write()) {
    message.action = renode_action::WRITE;
  } else {
    return;
  }

  while (bytes_remaining) {
    message.address = payload.get_address() + bytes_done;
    message.connection_index = connection_idx;
    message.data_length = bytes_remaining > 8 ? 8 : bytes_remaining;
    bytes_remaining -= message.data_length;
    if (payload.is_write()) {
      memcpy(&message.payload, payload.get_data_ptr() + bytes_done, message.data_length);
    }

    backward_connection->Send((char *)&message, sizeof(renode_message));
    backward_connection->Receive((char *)&message, sizeof(renode_message));

    if (payload.is_read()) {
      memcpy(payload.get_data_ptr() + bytes_done, &message.payload, message.data_length);
    }

    bytes_done += 8;
  }

  payload.set_response_status(tlm::TLM_OK_RESPONSE);
}

// ================================================================================
//   target_fw_handler
// ================================================================================

void renode_bridge::target_fw_handler::initialize(
    renode_bridge *renode_bridge, uint8_t conn_idx) {
  bridge = renode_bridge;
  connection_idx = conn_idx;
  socket.bind(*this);
}

void renode_bridge::target_fw_handler::b_transport(
    tlm::tlm_generic_payload &payload, sc_core::sc_time &delay) {
  bridge->service_backward_request(payload, connection_idx, delay);
}

tlm::tlm_sync_enum
renode_bridge::target_fw_handler::nb_transport_fw(
    tlm::tlm_generic_payload &trans, tlm::tlm_phase &phase,
    sc_core::sc_time &t) {
  bridge->service_backward_request(trans, connection_idx, t);
  return tlm::TLM_COMPLETED;
}

tlm::tlm_sync_enum
renode_bridge::target_fw_handler::nb_transport_bw(
    tlm::tlm_generic_payload &, tlm::tlm_phase &, sc_core::sc_time &) {
  fprintf(stderr, "[ERROR] nb_transport_bw not implemented for "
                  "target_fw_handler.\n");
  return tlm::TLM_COMPLETED;
}

void renode_bridge::target_fw_handler::invalidate_direct_mem_ptr(
    sc_dt::uint64, sc_dt::uint64) {
  fprintf(stderr, "[ERROR] invalidate_direct_mem_ptr not implemented for "
                  "target_fw_handler.\n");
}

bool renode_bridge::target_fw_handler::get_direct_mem_ptr(
    tlm::tlm_generic_payload &trans, tlm::tlm_dmi &dmi_data) {
  fprintf(stderr, "[ERROR] get_direct_mem_ptr not implemented for "
                  "target_fw_handler.\n");
  return false;
}

unsigned int renode_bridge::target_fw_handler::transport_dbg(
    tlm::tlm_generic_payload &trans) {

  // The SystemC simulation can begin before the connection with Renode is
  // initialized. Reject any transactions during this interval.
  if (!bridge->is_initialized()) return 0;

  sc_core::sc_time delay = sc_core::SC_ZERO_TIME;
  bridge->service_backward_request(trans, connection_idx, delay);
  return trans.is_response_ok() ? trans.get_data_length() : 0;
}

// ================================================================================
//  initiator_bw_handler
// ================================================================================

void renode_bridge::initiator_bw_handler::initialize(
    renode_bridge *renode_bridge) {
  bridge = renode_bridge;
}

tlm::tlm_sync_enum renode_bridge::initiator_bw_handler::nb_transport_bw(
    tlm::tlm_generic_payload &trans, tlm::tlm_phase &phase,
    sc_core::sc_time &t) {
  fprintf(stderr, "[ERROR] nb_transport_bw not implemented for "
                  "initiator_bw_handler- this should never be called, "
                  "as Renode integration only uses b_transfer.\n");
  return tlm::TLM_COMPLETED;
}

void renode_bridge::initiator_bw_handler::invalidate_direct_mem_ptr(
    sc_dt::uint64 start_range, sc_dt::uint64 end_range) {
  fprintf(stderr, "[ERROR] invalidate_direct_mem_ptr not implemented for "
                  "initiator_bw_handler - this should never be called, "
                  "as Renode integration only uses b_transfer.\n");
}

// ================================================================================
