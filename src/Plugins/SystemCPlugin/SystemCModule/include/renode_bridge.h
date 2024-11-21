//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#pragma once

#include <memory>

#include "tlm.h"
#include "tlm_utils/simple_initiator_socket.h"
#include "tlm_utils/simple_target_socket.h"

struct CTCPClient;

#ifndef RENODE_BUSWIDTH
#define RENODE_BUSWIDTH 32
#endif

#define NUM_GPIO 64
#define NUM_DIRECT_CONNECTIONS 4

// ================================================================================
// renode_bridge
//
//   SystemC module that serves as an interface with Renode.
// ================================================================================

class renode_bridge : sc_core::sc_module {
public:
  renode_bridge(sc_core::sc_module_name name, const char *address,
                const char *port);
  ~renode_bridge();

  // Returns true if connection with Renode has been established, false otherwise.
  bool is_initialized() { return fw_connection_initialized; }

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

  // Socket forwarding transactions performed in Renode to SystemC.
  renode_bus_initiator_socket initiator_socket;

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

  void forward_loop();
  void on_port_gpio();

  void update_backward_gpio_state(uint64_t new_gpio_state);
  void service_backward_request(tlm::tlm_generic_payload &payload,
                                uint8_t connection_idx,
                                sc_core::sc_time &delay);
  int64_t get_systemc_time_us();

  // Connection from Renode -> SystemC.
  std::unique_ptr<CTCPClient> forward_connection;

  // Connection from SystemC -> Renode
  std::unique_ptr<CTCPClient> backward_connection;

  // Construction/destruction of tlm_generic_payload is an expensive operation,
  // so a single tlm_generic_payload object is reused, as recommended by OSCI
  // TLM-2.0 Language Reference Manual. It also requires that the object is
  // allocated on the heap.
  std::unique_ptr<tlm::tlm_generic_payload> payload;

  initiator_bw_handler bus_initiator_bw_handler;
  target_fw_handler bus_target_fw_handler;

  initiator_bw_handler dc_initiators[NUM_DIRECT_CONNECTIONS];
  target_fw_handler dc_targets[NUM_DIRECT_CONNECTIONS];

  bool fw_connection_initialized;
};

// ================================================================================
