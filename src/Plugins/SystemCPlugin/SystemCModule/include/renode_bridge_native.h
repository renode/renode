//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#pragma once

#include <cstdint>
#include <systemc>
#include <tlm>

struct IRenodeBridge {
  virtual void reset() = 0;
  virtual tlm::tlm_fw_transport_if<> *tlm() = 0;
  virtual ~IRenodeBridge() = default;
};

using renode_bridge_factory_t = IRenodeBridge* (*)();
void register_renode_bridge_factory(renode_bridge_factory_t);

extern "C" {
  void systemc_init();
  void systemc_reset();
  void systemc_start_sim(int ns);

  std::uint64_t tlm_read(std::size_t size, std::uint64_t offset);
  void tlm_write(std::size_t size, std::int64_t value, std::uint64_t offset);
}
