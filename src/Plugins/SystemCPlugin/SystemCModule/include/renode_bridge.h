//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#pragma once

#include <condition_variable>
#include <memory>

#include <mutex>
#include <queue>
#include <tlm>
#include <tlm_utils/simple_initiator_socket.h>
#include <tlm_utils/simple_target_socket.h>

struct CTCPClient;
struct renode_message;

#ifndef RENODE_BUSWIDTH
#define RENODE_BUSWIDTH 32
#endif

#define NUM_GPIO 1024
#define NUM_DIRECT_CONNECTIONS 4

// ================================================================================
//  > Communication protocol
// ================================================================================

// Forward socket: Request from Renode, Response from SystemC
// Backward socket: Request from SystemC, Response From Renode

enum renode_action : uint8_t {
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
  INIT = 0,

  // Socket: forward, backward
  // Request:
  //     data_length: 0-3 LSB: number of bytes to read [1, 8]. 4-7 LSB: extension bits
  //     address: address to read from, in target's address space
  //     payload: ignored
  //     connection_index: 0 for SystemBus, [1, NUM_DIRECT_CONNECTIONS]
  //     for direct connection
  // Response:
  //     address: duration of transaction in us
  //     payload: read value
  //     connection_index: 0=DMI unsupported, 1=DMI supported
  //     data_length: transaction response status
  //     Otherwise identical to the request message.
  READ = 1,

  // Socket: forward, backward
  // Request:
  //     data_length: 0-3 LSB: number of bytes to write [1, 8]. 4-7 LSB: extension bits
  //     address: address to write to, in target's address space
  //     payload: value to write
  //     connection_index: 0 for SystemBus, [1, NUM_DIRECT_CONNECTIONS] for
  //       direct connection
  // Response:
  //     address: duration of transaction in us
  //     connection_index: 0=DMI unsupported, 1=DMI supported
  //     data_length: transaction response status
  //     Otherwise identical to the request message.
  WRITE = 2,

  // Socket: forward only
  // Request:
  //     data_length: ignored
  //     address: ignored
  //     connection_index: ignored
  // Response:
  //     payload: current target virtual time in microseconds
  //     Otherwise identical to the request message.
  TIMESYNC = 3,

  // Socket: forward, backward
  // Request:
  //     data_length: ignored
  //     address: signal number
  //     connection_index: ignored
  //     payload: state of GPIO
  // Response:
  //     Identical to the request message.
  GPIOWRITE = 4,

  // Socket: forward
  // Request:
  //     data_length: ignored
  //     address: ignored
  //     connection_index: ignored
  //     payload: ignored
  // Response:
  //     Identical to the request message.
  RESET = 5,

  // Socket: backward (memory mapped file), forward (native integration)
  // Request:
  //     data_length:
  //       backward: ignored 
  //       forward: 0-3 LSB: access type (read access = 0, write access = 1). 4-7 LSB: extension bits
  //     address: address in target's address space
  //     payload: ignored
  //     to write connection_index: 0 for SystemBus
  // Response is a dmi_message for backward socket (memory mapped file).
  // Response is a dmi_native_message for forward socket (native integration).
  DMIREQ = 6,

  // Socket: backward
  // Request:
  //     data_length: ignored
  //     connection_index: ignored
  //     address: start_address
  //     payload: end_address
  // Response:
  //     Identical to the request message.
  TBSINVALID = 7,

  // Socket: forward only
  // Request:
  //     data_length: 0-3 LSB: number of bytes to read [1, 8]. 4-7 LSB: extension bits
  //     address: register to read from, in target's register space
  //     payload: value to write
  //     connection_index: 0 for SystemBus, [1, NUM_DIRECT_CONNECTIONS]
  //       for direct connection
  // Response:
  //     address: duration of transaction in us
  //     payload: read value
  //     data_length: transaction response status
  //     Otherwise identical to the request message.
  READ_REGISTER = 8,

  // Socket: forward only
  // Request:
  //     data_length: 0-3 LSB: number of bytes to write [1, 8]. 4-7 LSB: extension bits
  //     address: register to write to, in target's register space
  //     payload: value to write
  //     connection_index: 0 for SystemBus, [1, NUM_DIRECT_CONNECTIONS] for
  //       direct connection
  // Response:
  //     address: duration of transaction in us
  //     data_length: transaction response status
  //     Otherwise identical to the request message.
  WRITE_REGISTER = 9,

  // Socket: backward only
  // Request:
  //     data_length: ignored
  //     connection_index: ignored
  //     address: secure vector table offset
  //     payload: ignored
  // Response:
  //     Identical to the request message.
  INIT_SECURE_VTOR = 10,

  // Socket: backward only
  // Request:
  //     data_length: ignored
  //     connection_index: ignored
  //     address: non-secure vector table offset
  //     payload: ignored
  // Response:
  //     Identical to the request message.
  INIT_NON_SECURE_VTOR = 11,
  
  // Socket: backward
  // Request:
  //     data_length: ignored
  //     connection_index: ignored
  //     address: start_address
  //     payload: end_address
  // Response:
  //     Identical to the request message.
  INVALIDATE_DMI_RANGE = 12,
};

#pragma pack(push, 1)
// WARNING: This structure is part of a binary socket protocol between C and C#.
// Any change MUST be mirrored in struct RenodeMessage in SystemCPeripheral.cs
// or communication will not work correctly.
struct renode_message {
  renode_action action;
  uint8_t data_length;
  uint8_t connection_index;
  uint64_t address;
  uint64_t payload;
};

// WARNING: This structure is part of a binary socket protocol between C and C#.
// Any change MUST be mirrored in structs FileMappingParameters and DMIMessage in SystemCPeripheral.cs
// or communication will not work correctly.
struct dmi_message {
  renode_action action;
  uint8_t allowed;
  uint64_t start_address;
  uint64_t end_address;
  uint64_t mmf_offset;
  uint32_t mmf_path_length;
  char mmf_path[4096]; // A common value for PATH_MAX, hardcoded here for consistency if it is different on the host
  uint64_t mapped_address;
};

// WARNING: This structure is part of a binary socket protocol between C and C#.
// Any change MUST be mirrored in struct DMINativeMessage in SystemCPeripheral.cs
// or communication will not work correctly.
struct dmi_native_message {
  renode_action action;
  uint8_t dmi_access;
  uint64_t start_address;
  uint64_t end_address;
  uint64_t pointer;
};
#pragma pack(pop)

class RenodeExt : public tlm::tlm_extension<RenodeExt> {
public:
    bool secure;
    bool privileged;

    RenodeExt() : secure(0), privileged(0) {}

    virtual tlm::tlm_extension_base* clone() const override {
        return new RenodeExt(*this);
    }

    virtual void copy_from(tlm::tlm_extension_base const &ext) override {
        const RenodeExt& that = static_cast<const RenodeExt&>(ext);
        this->secure = that.secure;
        this->privileged = that.privileged;
    }
};

template <typename T>
class BlockingCollection
{
    std::queue<T> queue_;
    std::mutex mutex_;
    std::condition_variable condvar_;

    typedef std::lock_guard<std::mutex> lock;
    typedef std::unique_lock<std::mutex> ulock;

public:
    void add(T const &val) {
      lock l(mutex_);
      bool wake = queue_.empty();
      queue_.push(val);
      // wake consumer if new element has been added
      if (wake) condvar_.notify_one();
    }

    T take() {
      ulock u(mutex_);
      while (queue_.empty())
        condvar_.wait(u);
      // queue_ is non-empty and we have the lock
      T retval = queue_.front();
      queue_.pop();
      return retval;
    }
};

// ================================================================================
// renode_bridge
//
//   SystemC module that serves as an interface with Renode.
// ================================================================================

class renode_bridge : sc_core::sc_module {
public:
  renode_bridge(sc_core::sc_module_name name, const char *address,
                const char *port, bool native = false, std::string mach = "", std::string peri = "");
  ~renode_bridge();

  // Returns true if connection with Renode has been established, false otherwise.
  bool is_initialized() { return fw_connection_initialized; }

  void handle_backward_response_from_native(renode_message message);
  void handle_backward_response_dmi_from_native(dmi_message message);
  void handle_forward_request_from_native(renode_message message);
  void handle_sideband_request(renode_message &message);
public:
  using renode_bus_target_socket =
      tlm::tlm_target_socket<RENODE_BUSWIDTH, tlm::tlm_base_protocol_types, 1,
                             sc_core::SC_ZERO_OR_MORE_BOUND>;
  using renode_bus_initiator_socket =
      tlm::tlm_initiator_socket<RENODE_BUSWIDTH, tlm::tlm_base_protocol_types,
                                1, sc_core::SC_ZERO_OR_MORE_BOUND>;
  using gpio_in_port = sc_core::sc_port<sc_core::sc_signal_in_if<bool>, 1,
                                        sc_core::SC_ZERO_OR_MORE_BOUND>;
  using gpio_out_port = sc_core::sc_port<sc_core::sc_signal_out_if<bool>, 1,
                                         sc_core::SC_ZERO_OR_MORE_BOUND>;
  using reset_port = sc_core::sc_port<sc_core::sc_signal_inout_if<bool>, 1,
                                      sc_core::SC_ZERO_OR_MORE_BOUND>;
  using vtor_in_port = sc_core::sc_port<sc_core::sc_signal_in_if<uint32_t>, 1,
                                      sc_core::SC_ZERO_OR_MORE_BOUND>;


  // Socket forwarding memory transactions performed in Renode to SystemC.
  renode_bus_initiator_socket initiator_socket;

  // Socket forwarding register transactions performed in Renode to SystemC.
  renode_bus_initiator_socket register_initiator_socket;

  // Socket forwarding transactions performed in SystemC to Renode.
  renode_bus_target_socket target_socket;

  // Direct connections allow for binding peripherals directly to each other in
  // Renode (bypassing System Bus).
  renode_bus_initiator_socket
      direct_connection_initiators[NUM_DIRECT_CONNECTIONS];
  renode_bus_target_socket direct_connection_targets[NUM_DIRECT_CONNECTIONS];

  // Input GPIO ports - signal changes are driven by SystemC and propagated to
  // Renode.
  gpio_in_port gpio_ports_in[NUM_GPIO];

  // Output GPIO ports - signal changes are driven by Renode and propagated to
  // SystemC.
  gpio_out_port gpio_ports_out[NUM_GPIO];

  // Reset signal.
  // Raised when the peripheral is reset. Expected to be lowered by SystemC
  // once the reset process is complete.
  reset_port reset;

  // INITNSVTOR signal.
  // Non-secure vector table offset address out of reset
  vtor_in_port init_vtor_ns_in;

  // INITSVTOR signal.
  // Vector table offset address (secure or non-secure depending on state)
  vtor_in_port init_vtor_s_in;

  // Informs Renode CPU that memory has been modified in the given range. This
  // is necessary when using DMI (get_direct_mem_ptr) to modify memory
  // containing CPU instructions.
  void invalidate_translation_blocks(uint64_t start_address, uint64_t end_address);

  // Informs Renode that direct memory pointer is no longer valid.
  // It means there is no longer a direct path to perform memory access
  // and initiator should issue regular transactions.
  void invalidate_dmi_range(uint64_t start_address, uint64_t end_address);

private:
  struct initiator_bw_handler: tlm::tlm_bw_transport_if<> {
    initiator_bw_handler() = default;
    void initialize(renode_bridge *);

    virtual tlm::tlm_sync_enum nb_transport_bw(tlm::tlm_generic_payload &trans,
                                               tlm::tlm_phase &phase,
                                               sc_core::sc_time &t);
    virtual void invalidate_direct_mem_ptr(sc_dt::uint64 start_range,
                                           sc_dt::uint64 end_range);

  private:
    renode_bridge *bridge;
  };

  struct target_fw_handler: tlm::tlm_fw_transport_if<> {
    target_fw_handler() = default;

    renode_bus_target_socket socket;

    void initialize(renode_bridge *, uint8_t connection_idx);

    virtual void invalidate_direct_mem_ptr(sc_dt::uint64 start_range,
                                           sc_dt::uint64 end_range);
    virtual tlm::tlm_sync_enum
    nb_transport_bw(tlm::tlm_generic_payload &payload, tlm::tlm_phase &phase,
                    sc_core::sc_time &delta);
    virtual tlm::tlm_sync_enum nb_transport_fw(tlm::tlm_generic_payload &trans,
                                               tlm::tlm_phase &phase,
                                               sc_core::sc_time &t);
    virtual void b_transport(tlm::tlm_generic_payload &trans,
                             sc_core::sc_time &delay);
    virtual bool get_direct_mem_ptr(tlm::tlm_generic_payload &trans,
                                    tlm::tlm_dmi &dmi_data);
    virtual unsigned int transport_dbg(tlm::tlm_generic_payload &trans);

  private:
    renode_bridge *bridge;
    uint8_t connection_idx;
  };

  bool initialize_connection(renode_message *message, int64_t *out_max_desync_us);
  void forward_loop();
  void sideband_loop();
  renode_message receive_backward_response();
  dmi_message receive_backward_response_dmi();
  renode_message receive_forward_request(bool *closed);
  renode_message receive_sideband_request_socket(bool *closed);
  void send_backward_request(renode_message *message);
  void send_forward_response(renode_message *message);
  void send_forward_response_dmi(dmi_native_message *message);
  void send_sideband_response_socket(renode_message *message);
  void handle_get_direct_mem_ptr(renode_bus_initiator_socket &socket, renode_message &message);
  void handle_sideband_access(renode_message &message);
  void handle_sideband_gpio_write(renode_message &message);
  void handle_read(renode_bus_initiator_socket &socket, renode_message &message, uint8_t data[8]);
  void handle_write(renode_bus_initiator_socket &socket, renode_message &message, uint8_t data[8]);
  void sync_gpio_state(bool init);
  void on_port_gpio();
  void on_init_ns_vtor();
  void on_init_s_vtor();
  void init_vtor(renode_action action, vtor_in_port &port);

  void update_backward_gpio_state(uint64_t new_gpio_state);
  void service_backward_request(tlm::tlm_generic_payload &payload,
                                uint8_t connection_idx,
                                sc_core::sc_time &delay);
  bool service_backward_request_dmi(tlm::tlm_generic_payload &payload,
                                    tlm::tlm_dmi &dmi_data);
  int64_t get_systemc_time_us();

  // Connection from Renode -> SystemC.
  std::unique_ptr<CTCPClient> forward_connection;

  // Sideband connection from Renode -> SystemC.
  std::unique_ptr<CTCPClient> sideband_connection;

  // Connection from SystemC -> Renode
  std::unique_ptr<CTCPClient> backward_connection;

  // Construction/destruction of tlm_generic_payload is an expensive operation,
  // so a single tlm_generic_payload object is reused, as recommended by OSCI
  // TLM-2.0 Language Reference Manual. It also requires that the object is
  // allocated on the heap.
  std::unique_ptr<tlm::tlm_generic_payload> payload;

  std::unique_ptr<RenodeExt> ext;

  initiator_bw_handler bus_initiator_bw_handler;
  initiator_bw_handler cpu_initiator_bw_handler;
  target_fw_handler bus_target_fw_handler;
  target_fw_handler cpu_target_fw_handler;

  initiator_bw_handler dc_initiators[NUM_DIRECT_CONNECTIONS];
  target_fw_handler dc_targets[NUM_DIRECT_CONNECTIONS];

  bool fw_connection_initialized;
  bool native;
  std::string mach;
  std::string peri;

  BlockingCollection<renode_message> bw_response;
  BlockingCollection<dmi_message> dmi_response;
  BlockingCollection<renode_message> fw_request;
};

// ================================================================================
