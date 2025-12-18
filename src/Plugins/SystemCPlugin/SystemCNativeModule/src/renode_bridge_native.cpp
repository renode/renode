#include "renode_bridge_native.h"

extern top top;

void systemc_start_sim(int ns) {
  sc_core::sc_start(ns, sc_core::SC_NS);
}

unsigned int tlm_read_double_word(long offset) {

  tlm::tlm_generic_payload payload;
  sc_core::sc_time delay = sc_core::SC_ZERO_TIME;

  uint8_t data[8];

  payload.set_command(tlm::TLM_READ_COMMAND);
  payload.set_address(offset);
  payload.set_data_ptr(data);
  payload.set_data_length(8);
  payload.set_byte_enable_ptr(nullptr);
  payload.set_byte_enable_length(0);
  payload.set_streaming_width(8);
  payload.set_dmi_allowed(false);
  payload.set_response_status(tlm::TLM_INCOMPLETE_RESPONSE);

  top.module->b_transport(payload, delay);

  return *((unsigned int *)payload.get_data_ptr());
}

top::top(sc_core::sc_module_name name, tlm::tlm_fw_transport_if<> *module) {
  this->module = module;
}
