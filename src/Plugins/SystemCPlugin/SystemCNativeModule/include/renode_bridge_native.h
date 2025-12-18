#pragma once

#include <systemc>
#include <tlm>

extern "C" {
  void systemc_start_sim(int ns);
  unsigned int tlm_read_double_word(long offset);
}

struct top : sc_core::sc_module {
  top(sc_core::sc_module_name name, tlm::tlm_fw_transport_if<> *module);

  tlm::tlm_fw_transport_if<> *module;
};
