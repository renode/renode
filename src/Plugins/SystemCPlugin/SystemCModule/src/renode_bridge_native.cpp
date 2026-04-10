//
// Copyright (c) 2010-2026 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
#include "renode_bridge_native.h"
#include "renode_imports.h"
#include <stdexcept>
#include <cstring>

renode_bridge_factory_t& get_factory() {
    static renode_bridge_factory_t factory = nullptr;
    return factory;
}

IRenodeBridge*& get_model() {
    static IRenodeBridge *model = nullptr;
    return model;
}

void register_renode_bridge_factory(renode_bridge_factory_t f) {
    get_factory() = f;
}

void systemc_init() {
  auto factory = get_factory();
  if (!factory) {
    throw std::runtime_error("Factory not registered!");
  }

  auto& model = get_model();
  model = factory();
}

void systemc_reset() {
  auto *model = get_model();

  if (model) {
    model->reset();
  }
}

void systemc_start_sim(int ns) {
  sc_core::sc_start(ns, sc_core::SC_NS);
}

static void prepare_payload(tlm::tlm_generic_payload& payload,
                            tlm::tlm_command cmd, std::uint64_t address,
                            std::uint8_t *data, std::size_t size) {
  payload.set_command(cmd);
  payload.set_address(address);
  payload.set_data_ptr(data);
  payload.set_data_length(size);
  payload.set_streaming_width(size);
  payload.set_byte_enable_ptr(nullptr);
  payload.set_byte_enable_length(0);
  payload.set_dmi_allowed(false);
  payload.set_response_status(tlm::TLM_INCOMPLETE_RESPONSE);
}

void systemc_set_nonblocking_read(bool nb) {
  auto *model = get_model();
  if (!model) {
    throw std::runtime_error("Model must not be null!");
  }

  model->nb_read = nb;
}

void systemc_set_nonblocking_write(bool nb) {
  auto *model = get_model();
  if (!model) {
    throw std::runtime_error("Model must not be null!");
  }

  model->nb_write = nb;
}

std::uint64_t tlm_read(std::size_t size, std::uint64_t offset) {
  tlm::tlm_generic_payload payload;
  sc_core::sc_time delay = sc_core::SC_ZERO_TIME;
  std::vector<std::uint8_t> data(size);

  auto *model = get_model();
  if (!model) {
    throw std::runtime_error("Model must not be null!");
  }

  prepare_payload(payload, tlm::TLM_READ_COMMAND, offset, data.data(), size);
  if (model->nb_read) {
    tlm::tlm_phase phase = tlm::BEGIN_REQ;

    auto status = model->tlm_route(offset)->nb_transport_fw(payload, phase, delay);
    if (status != tlm::TLM_COMPLETED) {
      model->nb_wait();
    }
  } else {
    model->tlm_route(offset)->b_transport(payload, delay);
  }

  std::uint64_t result = 0;
  std::memcpy(&result, data.data(), size);

  return result;
}

void tlm_write(std::size_t size, std::int64_t value, std::uint64_t offset) {
  tlm::tlm_generic_payload payload;
  sc_core::sc_time delay = sc_core::SC_ZERO_TIME;
  std::vector<std::uint8_t> data(size);

  auto *model = get_model();
  if (!model) {
    throw std::runtime_error("Model must not be null!");
  }

  std::memcpy(data.data(), &value, size);
  prepare_payload(payload, tlm::TLM_WRITE_COMMAND, offset, data.data(), size);

  if (model->nb_write) {
    tlm::tlm_phase phase = tlm::BEGIN_REQ;

    auto status = model->tlm_route(offset)->nb_transport_fw(payload, phase, delay);
    if (status != tlm::TLM_COMPLETED) {
      model->nb_wait();
    }
  } else {
    model->tlm_route(offset)->b_transport(payload, delay);
  }
}

void gpio_write(int number, bool value) {
  auto *model = get_model();
  if (!model) {
    throw std::runtime_error("Model must not be null!");
  }

  model->gpio_port_write(number, value);
}

EXTERNAL_AS(void, UpdateGPIOConnections, renode_gpio_update, int32_t, int32_t);
EXTERNAL_AS(void, InvalidateTranslationBlocks, renode_invalidate_translation_blocks, uint64_t, uint64_t);
EXTERNAL_AS(void, ReadBytesFromBus, renode_read_bytes_from_bus, uint64_t, voidptr, int32_t);
EXTERNAL_AS(void, WriteBytesToBus, renode_write_bytes_to_bus, uint64_t, voidptr, int32_t);
EXTERNAL_AS(int32_t, GetDirectMemPtr, renode_get_direct_mem_ptr_raw, uint64_t, voidptr, voidptr, voidptr);

std::optional<DmiRegion> renode_get_direct_mem_ptr(uint64_t address) {
  uint64_t start_address, end_address;
  void *mapped_address;

  bool allowed = renode_get_direct_mem_ptr_raw(address, &start_address, &end_address, &mapped_address);
  if (!allowed) {
    return std::nullopt;
  }

  return DmiRegion { static_cast<std::uint8_t *>(mapped_address), start_address, end_address };
}

IRenodeBridge::IRenodeBridge() : nb_done(false), nb_read(false), nb_write(false) {
  // intentionally left empty
}

void IRenodeBridge::nb_wait() {
    while (!nb_done) {
      sc_core::sc_start(sc_core::SC_ZERO_TIME);
    }

    nb_done = false;
}
