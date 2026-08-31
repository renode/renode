//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#include "renode_bridge.h"

#ifdef RENODE_NATIVE_INTERFACE
// librenode.h should be included after renode_bridge.h
// to have renode_message struct already defined.
#define _RENODE_BRIDGE_H
#include "librenode.h"
#endif
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <thread>
#include <cinttypes>
#include <array>
#ifdef __linux__
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/types.h>
#endif

#include "socket-cpp/Socket/TCPClient.h"

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
  printf("[0x%" PRIX64 "][RENODE MESSAGE] Action: ", thread_id);
  switch (message->action) {
  case INIT:
    printf("INIT");
    break;
  case TEARDOWN:
    printf("TEARDOWN");
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
  printf(" | Address: 0x%" PRIX64, message->address);
  printf(" | Payload: 0x%" PRIX64, message->payload);
  printf(" | ConnIdx: %u\n", message->connection_index);
}

static void print_transaction_status(tlm::tlm_generic_payload *payload) {
  tlm::tlm_response_status status = payload->get_response_status();
  std::string response_string = payload->get_response_string();
  printf("Renode transport status: %s\n", response_string.c_str());
}

/*
enum tlm_response_status {
  TLM_OK_RESPONSE = 1,
  TLM_INCOMPLETE_RESPONSE = 0,
  TLM_GENERIC_ERROR_RESPONSE = -1,
  TLM_ADDRESS_ERROR_RESPONSE = -2,
  TLM_COMMAND_ERROR_RESPONSE = -3,
  TLM_BURST_ERROR_RESPONSE = -4,
  TLM_BYTE_ENABLE_ERROR_RESPONSE = -5
};
*/
static uint8_t tlm_resp_to_renode(tlm::tlm_response_status status) {
  // Equalize numbers to positive scale, where 0 means OK.
  return (uint8_t)(tlm::tlm_response_status::TLM_OK_RESPONSE - status);
}

// ================================================================================
//  > Renode Bridge SystemC module
// ================================================================================

static void initialize_payload(tlm::tlm_generic_payload *payload,
                               const renode_message *message, uint8_t *data) {
  tlm::tlm_command command = tlm::TLM_IGNORE_COMMAND;
  switch (message->action) {
  case WRITE:
  case WRITE_DEBUG:
  case WRITE_REGISTER:
    command = tlm::TLM_WRITE_COMMAND;
    break;
  case READ:
  case READ_DEBUG:
  case READ_REGISTER:
    command = tlm::TLM_READ_COMMAND;
    break;
  default:
    assert(!"Only WRITE and READ messages should initialize TLM payload");
  }

  unsigned int data_length = message->data_length & ((1 << 4) - 1);

  if(data_length > 8) {
    assert(!"data_length > 8 is currently not supported");
  }

  payload->set_command(command);
  // Right now the address visible to SystemC is directly the offset
  // from Renode; i. e. if we write to address 0x9000100 and the peripheral
  // address is 0x9000000, then address in SystemC will be 0x100.
  payload->set_address(message->address);
  payload->set_data_ptr(data);
  payload->set_data_length(data_length);
  payload->set_byte_enable_ptr(nullptr);
  payload->set_byte_enable_length(0);
  payload->set_streaming_width(data_length);
  payload->set_dmi_allowed(false);
  payload->set_response_status(tlm::TLM_INCOMPLETE_RESPONSE);
}

static void initialize_extension(RenodeExt *ext, const renode_message *message) {
  bool secure = message->data_length & (1 << 4);
  bool privileged = message->data_length & (1 << 5);
  ext->secure = secure;
  ext->privileged = privileged;
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

static uint64_t
perform_debug_transaction(renode_bridge::renode_bus_initiator_socket &socket,
                          tlm::tlm_generic_payload *payload) {
  unsigned int n_bytes = socket->transport_dbg(*payload);
#ifdef VERBOSE
  print_transaction_status(payload);
#endif
  return n_bytes;
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

static void register_connection_for_bridge(void* conn_opaque_ptr, void* bridge_opaque_ptr) {
  renode_connection *conn = (renode_connection *)conn_opaque_ptr;
  renode_bridge *bridge = (renode_bridge *)bridge_opaque_ptr;
  bridge->register_connection(conn);
}

static void handle_backward_response_native(void* opaque_ptr, renode_message message) {
  renode_connection *conn = (renode_connection *)opaque_ptr;
  conn->handle_backward_response_from_native(message);
}

static void handle_backward_response_dmi_native(void* opaque_ptr, dmi_message message) {
  renode_connection *conn = (renode_connection *)opaque_ptr;
  conn->handle_backward_response_dmi_from_native(message);
}

static void handle_forward_request_native(void* opaque_ptr, renode_message message) {
  renode_connection *conn = (renode_connection *)opaque_ptr;
  conn->handle_forward_request_from_native(message);
}

renode_message renode_bridge::receive_backward_response() {
  return conn->receive_backward_response();
}

dmi_message renode_bridge::receive_backward_response_dmi() {
  return conn->receive_backward_response_dmi();
}

void renode_bridge::send_backward_request(renode_message *message) {
  conn->send_backward_request(message);
}

void renode_bridge::send_forward_response(renode_message *message) {
  conn->send_forward_response(message);
}

void renode_bridge::send_forward_response_dmi(dmi_native_message *message) {
  conn->send_forward_response_dmi(message);
}

renode_bridge::renode_bridge(sc_core::sc_module_name name, const char *address,
                             const char *port, bool native, std::string mach,
                             std::string peri, uint32_t id, bool hosted, renode_connection *conn)
    : sc_module(name), initiator_socket("initiator_socket"),
      register_initiator_socket("register_initiator_socket"), id(id) {
  SC_HAS_PROCESS(renode_bridge);
  if (conn != NULL) {
    // Connection can be managed manually.
    // It can be instantiated and passed via pointer to a bridge.
    register_connection(conn);
  } else if (native || hosted) {
#ifdef RENODE_NATIVE_INTERFACE
    // Attempt to register this bridge with an existing connection if available.
    // It applies to both socket and native transport in hosted mode.
    // Call to Renode is needed to obtain a pointer to renode_connection instance
    // via register_connection_for_bridge callback.
    auto rc = renode_systemc_register_bridge(
        (void *)this, (void *)register_connection_for_bridge, mach.c_str(),
        peri.c_str());
    // Command error means there is no connection available.
    if (rc == RENODE_COMMAND_ERROR) {
      // Connection is not initialized.
      // Create it now and register directly.
      // No need to go via renode_systemc_register_bridge again.
      this->conn = new renode_connection("renode_connection", address, port, native, mach, peri, hosted);
      register_connection(this->conn);
    } else if (rc != RENODE_SUCCESS) {
      fprintf(stderr, "Failed to register bridge using native interface. Aborting.\n");
      terminate_simulation(1);
    }
#else
    fprintf(stderr, "Failed to initialize native interface. Aborting.\n");
    terminate_simulation(1);
#endif
  } else {
    // In this case renode_connection is not shared between multiple renode_bridge instances.
    // The default mode, when there is a single renode_bridge per SystemC simulation kernel.
    this->conn = new renode_connection("renode_connection", address, port, native, mach, peri);
    register_connection(this->conn);
  }

  SC_METHOD(on_port_gpio);
  for (int i = 0; i < NUM_GPIO; ++i) {
    sensitive << gpio_ports_in[i];
  }

  SC_METHOD(on_init_ns_vtor);
  sensitive << init_vtor_ns_in;
  SC_METHOD(on_init_s_vtor);
  sensitive << init_vtor_s_in;

  bus_target_fw_handler.initialize(this, 0);
  cpu_target_fw_handler.initialize(this, 0);

  target_socket.bind(bus_target_fw_handler.socket);
  for (int i = 0; i < NUM_DIRECT_CONNECTIONS; ++i) {
    dc_initiators[i].initialize(this);
    dc_targets[i].initialize(this, i + 1);
    direct_connection_targets[i].bind(dc_targets[i]);
    direct_connection_initiators[i].bind(dc_initiators[i]);
  }

  bus_initiator_bw_handler.initialize(this);
  cpu_initiator_bw_handler.initialize(this);
  initiator_socket.bind(bus_initiator_bw_handler);
  register_initiator_socket.bind(cpu_initiator_bw_handler);

  payload.reset(new tlm::tlm_generic_payload());
  ext.reset(new RenodeExt());
}

renode_bridge::~renode_bridge() {
}

void renode_bridge::register_connection(renode_connection *conn) {
  this->conn = conn;
  this->conn->register_bridge(id, this);
}

void renode_bridge::handle_forward_request(renode_message &message) {
  // Processing of requests initiated by Renode.
  uint8_t data[8] = {0};

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
  case renode_action::WRITE_DEBUG:
  case renode_action::READ_DEBUG: {
    handle_debug_access(message);
    send_forward_response(&message);
  } break;
  case renode_action::WRITE: {
    handle_write(*initiator_socket, message, data);
  } break;
  case renode_action::READ: {
    handle_read(*initiator_socket, message, data);
  } break;
  case renode_action::WRITE_REGISTER: {
    handle_write(register_initiator_socket, message, data);
  } break;
  case renode_action::READ_REGISTER: {
    handle_read(register_initiator_socket, message, data);
  } break;
  case renode_action::DMIREQ: {
    handle_get_direct_mem_ptr(*initiator_socket, message);
  } break;
  case renode_action::GPIOWRITE: {
    auto number = message.address;
    auto value = message.payload;
    sc_core::sc_interface *iface = gpio_ports_out[number].get_interface();
    if (iface != nullptr) {
      gpio_ports_out[number]->write(value == 1);
    }
    send_forward_response(&message);
  } break;
  case renode_action::RESET: {
    sc_core::sc_interface *iface = reset.get_interface();
    if (iface != nullptr) {
      reset->write(true);
    }
    send_forward_response(&message);
  } break;
  default:
    fprintf(stderr, "Malformed message received from Renode - terminating simulation.\n");
    terminate_simulation(1);
  }
}

void renode_bridge::invalidate_translation_blocks(uint64_t start_address, uint64_t end_address) {
  renode_message message = {};
  message.action = renode_action::TBSINVALID;
  message.address = start_address;
  message.payload = end_address;
  message.initiator_id = id;

  send_backward_request(&message);
  // Response is ignored.
  receive_backward_response();
}

void renode_bridge::invalidate_dmi_range(uint64_t start_address, uint64_t end_address) {
  renode_message message = {};
  message.action = renode_action::INVALIDATE_DMI_RANGE;
  message.address = start_address;
  message.payload = end_address;
  message.initiator_id = id;

  send_backward_request(&message);
  // Response is ignored.
  receive_backward_response();
}

void renode_bridge::handle_read(renode_bus_initiator_socket &socket, renode_message &message, uint8_t data[8]) {
  initialize_payload(payload.get(), &message, data);
  initialize_extension(ext.get(), &message);

  payload->set_extension(ext.get());
  uint64_t delay = perform_transaction(socket, payload.get());
  payload->clear_extension(ext.get());

  tlm::tlm_response_status status = payload->get_response_status();
  message.data_length = tlm_resp_to_renode(status);

  // NOTE: address field is re-used here to pass timing information.
  message.address = delay;
  message.payload = *((uint64_t *)data);
  message.connection_index = (uint8_t)payload->is_dmi_allowed();
  send_forward_response(&message);
  wait(sc_core::SC_ZERO_TIME);
}

void renode_bridge::handle_write(renode_bus_initiator_socket &socket, renode_message &message, uint8_t data[8]) {
  initialize_payload(payload.get(), &message, data);
  initialize_extension(ext.get(), &message);

  *((uint64_t *)data) = message.payload;

  payload->set_extension(ext.get());
  uint64_t delay = perform_transaction(socket, payload.get());
  payload->clear_extension(ext.get());

  tlm::tlm_response_status status = payload->get_response_status();
  message.data_length = tlm_resp_to_renode(status);

  // NOTE: address field is re-used here to pass timing information.
  message.address = delay;
  message.connection_index = (uint8_t)payload->is_dmi_allowed();
  send_forward_response(&message);

  wait(sc_core::SC_ZERO_TIME);
}

void renode_bridge::handle_get_direct_mem_ptr(renode_bus_initiator_socket &socket, renode_message &message) {
  unsigned int cmd_type = message.data_length & ((1 << 4) - 1);
  if (cmd_type == tlm::tlm_command::TLM_READ_COMMAND) {
    message.action = renode_action::READ;
  } else if (cmd_type == tlm::tlm_command::TLM_WRITE_COMMAND) {
    message.action = renode_action::WRITE;
  }
  initialize_payload(payload.get(), &message, NULL);
  initialize_extension(ext.get(), &message);

  tlm::tlm_dmi dmi_data = {};
  dmi_native_message dmi_message = {};

  payload->set_extension(ext.get());
  // get_direct_mem_ptr returns true if it was able to provide a DMI pointer, or false otherwise
  bool success = socket->get_direct_mem_ptr(*payload, dmi_data);
  payload->clear_extension(ext.get());

  dmi_message.action = renode_action::DMIREQ;
  dmi_message.dmi_access = success ? (uint8_t)dmi_data.get_granted_access() : 0;
  dmi_message.start_address = dmi_data.get_start_address();
  dmi_message.end_address = dmi_data.get_end_address();
  dmi_message.pointer = reinterpret_cast<uintptr_t>(dmi_data.get_dmi_ptr());

  send_forward_response_dmi(&dmi_message);
  wait(sc_core::SC_ZERO_TIME);
}

void renode_bridge::handle_debug_access(renode_message &message)
{
  uint8_t data[8] = {};
  memset(data, 0, sizeof(data));
  initialize_payload(payload.get(), &message, data);

  *((uint64_t *)data) = message.payload; // used for write only
  uint64_t n_bytes = perform_debug_transaction(this->initiator_socket, payload.get());
  message.payload = *((uint64_t *)data); // used for read only
  message.address = n_bytes; // address field is reused to store the number of written/read bytes
}

enum gpio_state {
  GPIO_LOW = 0,
  GPIO_HIGH = 1
};

void renode_bridge::sync_gpio_state(bool init) {
  for (int i = 0; i < NUM_GPIO; ++i) {
    if (gpio_ports_in[i].get_interface() == nullptr) {
      continue;
    }
    // On init send state for all gpios.
    // Later only changes are propagated.
    if (!init && !gpio_ports_in[i]->event()) {
      continue;
    }
    gpio_state current = (gpio_state)gpio_ports_in[i]->read();

    renode_message message = {};
    message.action = renode_action::GPIOWRITE;
    message.address = i;
    message.payload = current;
    message.initiator_id = id;

    send_backward_request(&message);
    // Response is ignored.
    receive_backward_response();
  }
}

void renode_bridge::on_port_gpio() {
  sync_gpio_state(false);
}

void renode_bridge::service_backward_request(tlm::tlm_generic_payload &payload,
                                             uint8_t connection_idx,
                                             sc_core::sc_time &delay) {
  unsigned int bytes_done = 0;
  unsigned int bytes_remaining = payload.get_data_length();
  renode_message message = {};
  message.initiator_id = id;
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

    send_backward_request(&message);
    message = receive_backward_response();

    if (payload.is_read()) {
      memcpy(payload.get_data_ptr() + bytes_done, &message.payload, message.data_length);
    }

    bytes_done += 8;
  }

  if (connection_idx == 0 && message.connection_index == 1) {
    payload.set_dmi_allowed(true);
  }

  payload.set_response_status(tlm::TLM_OK_RESPONSE);
}

void renode_bridge::init_vtor(renode_action action, vtor_in_port &port) {
  if (port.get_interface() == nullptr) {
    return;
  }

  renode_message msg = {};
  msg.action = action;
  msg.address = port->read();
  msg.initiator_id = id;
  send_backward_request(&msg);
  // Response is ignored.
  msg = receive_backward_response();
}

void renode_bridge::on_init_s_vtor() {
  init_vtor(INIT_SECURE_VTOR, init_vtor_s_in);
}

void renode_bridge::on_init_ns_vtor() {
  init_vtor(INIT_NON_SECURE_VTOR, init_vtor_ns_in);
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
  if (connection_idx != 0) {
    fprintf(stderr, "[ERROR] get_direct_mem_ptr not implemented for "
                    "target_fw_handler.\n");
    return false;
  } else {
    return bridge->service_backward_request_dmi(trans, dmi_data);
  }
}

bool renode_bridge::service_backward_request_dmi(tlm::tlm_generic_payload &payload, tlm::tlm_dmi &dmi_data) {

#ifdef __linux__
  renode_message message = {};
  message.address = payload.get_address();
  message.data_length = payload.get_data_length();
  message.connection_index = 0;
  message.action = renode_action::DMIREQ;
  message.initiator_id = id;

  dmi_message response;

  send_backward_request(&message);
  response = receive_backward_response_dmi();

  bool dmi_allowed = response.allowed;

  if (dmi_allowed && response.mmf_offset % sysconf(_SC_PAGESIZE)) {
      fprintf(stderr, "[ERROR] invalid page-unaligned offset 0x%" PRIx64 " for MMF %s\n",
        response.mmf_offset,
        response.mmf_path
      );
    dmi_allowed = false;
  }

  if (dmi_allowed) {
    dmi_data.allow_read_write();
    dmi_data.set_start_address(response.start_address);
    dmi_data.set_end_address(response.end_address);
    int mmf_fd = open(response.mmf_path, O_RDWR);
    if (mmf_fd != -1) {
      unsigned char* mmf_base = static_cast<unsigned char*>(mmap(
          nullptr,
        static_cast<size_t>(dmi_data.get_end_address() - dmi_data.get_start_address() + 1),
        PROT_WRITE|PROT_READ,
        MAP_SHARED,
        mmf_fd,
        response.mmf_offset
      ));
      if (mmf_base != MAP_FAILED) {
        dmi_data.set_dmi_ptr(mmf_base);
        return true;
      }
    }
  }
#else
  // at present DMI support has been implemented for linux only.
  // print a one-time warning for DMI request on another operating system
  static bool dmi_disabled_warned = false;
  if (!dmi_disabled_warned) {
    fprintf(stderr, "[WARNING] DMI support is unimplemented on this operating system\n");
  }
  dmi_disabled_warned = true;
#endif

  return false;
}

unsigned int renode_bridge::target_fw_handler::transport_dbg(
    tlm::tlm_generic_payload &trans) {
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
  bridge->invalidate_dmi_range(start_range, end_range);
}

// ================================================================================

void renode_connection::handle_backward_response_from_native(renode_message message)
{
  bw_response.add(message);
}

void renode_connection::handle_backward_response_dmi_from_native(dmi_message message)
{
  dmi_response.add(message);
}

void renode_connection::handle_forward_request_from_native(renode_message message)
{
  fw_request.add(message);
}

renode_message renode_connection::receive_backward_response()
{
  if(native) {
    return bw_response.take();
  } else {
    renode_message message;
    backward_connection->Receive((char *)&message, sizeof(renode_message));
    return message;
  }
}

dmi_message renode_connection::receive_backward_response_dmi()
{
  if(native) {
    return dmi_response.take();
  } else {
    dmi_message response;
    backward_connection->Receive((char *)&response, sizeof(dmi_message));
    return response;
  }
}

renode_message renode_connection::receive_forward_request(bool* closed)
{
  if(native) {
    *closed = false;
    return fw_request.take(true);
  } else {
    renode_message message;
    int nread =
        forward_connection->Receive((char *)&message, sizeof(renode_message));
    *closed = nread <= 0;
    return message;
  }
}

void renode_connection::send_backward_request(renode_message *message) {
  if (native) {
#ifdef RENODE_NATIVE_INTERFACE
    renode_systemc_send_backward_request(*message, mach.c_str(), peri.c_str());
#endif
  } else {
    backward_connection->Send((char *)message, sizeof(renode_message));
  }
}

void renode_connection::send_forward_response(renode_message *message) {
  if (native) {
#ifdef RENODE_NATIVE_INTERFACE
    renode_systemc_send_forward_response(*message, mach.c_str(), peri.c_str());
#endif
  } else {
    forward_connection->Send((char *)message, sizeof(renode_message));
  }
}

void renode_connection::send_forward_response_dmi(dmi_native_message *message) {
  if (native) {
#ifdef RENODE_NATIVE_INTERFACE
    renode_systemc_send_forward_response_dmi(*message, mach.c_str(), peri.c_str());
#endif
  } else {
    forward_connection->Send((char *)message, sizeof(dmi_native_message));
  }
}

renode_connection::renode_connection(sc_core::sc_module_name name,
                                     const char *address, const char *port,
                                     bool native, std::string mach,
                                     std::string peri, bool hosted)
    : sc_module(name), native(native), mach(mach), peri(peri) {
  SC_HAS_PROCESS(renode_connection);
  if (native || hosted) {
    // If (!native && hosted), passed pointer is later used to register bridges,
    // but sockets are used for communication instead of handle_* callbacks.
#ifdef RENODE_NATIVE_INTERFACE
    auto rc = renode_systemc_setup_connection(
        (void *)this, (void *)handle_backward_response_native,
        (void *)handle_backward_response_dmi_native,
        (void *)handle_forward_request_native,
        mach.c_str(), peri.c_str());
    if (rc != RENODE_SUCCESS) {
      fprintf(stderr, "Failed to initialize native interface. Aborting.\n");
      terminate_simulation(1);
    }
#else
    fprintf(stderr, "Failed to initialize native interface. Aborting.\n");
    terminate_simulation(1);
#endif
  }
  SC_THREAD(forward_loop);

  if (native) {
#ifdef RENODE_NATIVE_INTERFACE
    renode_systemc_init_native_connection(mach.c_str(), peri.c_str());
#endif
  } else {
    forward_connection.reset(new CTCPClient(NULL, ASocket::NO_FLAGS));
    connect_with_retry(forward_connection.get(), address, port);

    backward_connection.reset(new CTCPClient(NULL, ASocket::NO_FLAGS));
    connect_with_retry(backward_connection.get(), address, port);
  }

  if (!initialize_connection(&max_desync_us)) {
    fprintf(stderr, "Failed to initialize Renode connection. Aborting.\n");
    terminate_simulation(1);
    return;
  }
}

renode_connection::~renode_connection() {
  if (native) {
#ifdef RENODE_NATIVE_INTERFACE
    renode_systemc_teardown_native_connection(mach.c_str(), peri.c_str());
#endif
  } else {
    forward_connection->Disconnect();
    backward_connection->Disconnect();
  }
}

void renode_connection::register_bridge(uint32_t id, renode_bridge *bridge) {
  bridges[id] = bridge;
}

bool renode_connection::initialize_connection(int64_t *out_max_desync_us) {
  // Send INIT message to Renode and use response
  // to setup connection, e. g. set time synchronization period.
  // This is done once per lifetime of the module during elaboration.
  renode_message message = {};
  message.action = renode_action::INIT;

  send_backward_request(&message);
  message = receive_backward_response();

#ifdef VERBOSE
  print_renode_message(&message);
#endif

  if (message.action != renode_action::INIT) {
    fprintf(stderr, "Renode bridge connection error: missing INIT action.\n");
    return false;
  }
  *out_max_desync_us = static_cast<int64_t>(message.payload);

#ifdef VERBOSE
  printf("Connection to Renode initialized with timesync period %" PRId64
         " us.\n",
         *out_max_desync_us);
#endif
  return true;
}

void renode_connection::forward_loop() {
  // Processing of requests initiated by Renode.

  renode_message message;
  bool closed = false;

  while (true) {
    message = receive_forward_request(&closed);
    if (closed) {
#ifdef VERBOSE
      printf("Connection to Renode closed.\n");
#endif
      break;
    }

#ifdef VERBOSE
    print_renode_message(&message);
#endif

    switch (message.action) {
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
      // Reaching a timestamp only means this bridge thread was resumed by the
      // SystemC simulation kernel. Let other processes and signal updates
      // scheduled for the same timestamp run before reporting the timesync as
      // complete to Renode.
      while (sc_core::sc_pending_activity_at_current_time()) {
        sc_core::wait(sc_core::SC_ZERO_TIME);
      }
      message.payload = sc_time_to_us(sc_core::sc_time_stamp());
      send_forward_response(&message);
    } break;
    case renode_action::TEARDOWN: {
      if (native) {
#ifdef RENODE_NATIVE_INTERFACE
        renode_systemc_teardown_native_connection(mach.c_str(), peri.c_str());
#endif
      } else {
        forward_connection->Disconnect();
        backward_connection->Disconnect();
      }
      terminate_simulation(0);
    } break;
    default:
      renode_bridge* bridge = bridges[message.initiator_id];
      bridge->handle_forward_request(message);
      break;
    }
  }
}

// ================================================================================
