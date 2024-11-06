//
// Copyright (c) 2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

#include "cfu.h"

void Cfu::tick(bool countEnable, uint64_t steps = 1)
{
  for(uint64_t i = 0; i < steps; i++) {
    *clk = 1;
    evaluateModel();
    *clk = 0;
    evaluateModel();
  }

  if(countEnable) {
      tickCounter += steps;
  }
}

void Cfu::timeoutTick(uint8_t* signal, uint8_t expectedValue, int timeout = DEFAULT_TIMEOUT)
{
  do
  {
    tick(true);
    timeout--;
  }
  while((*signal != expectedValue) && timeout > 0);

  if(timeout == 0) {
    throw "Operation timeout";
  }
}

uint64_t Cfu::execute(uint32_t functionID, uint32_t data0, uint32_t data1, int* error)
{
  uint64_t result;
  *req_func_id = functionID;
  *req_data0 = data0;
  *req_data1 = data1;
  *req_valid = 1;
  *resp_ready = 1;

  /* Error signal is not supported by CFU yet so set it to 0 */
  *error = 0;

  /* Apply changed signals without changing clock's edge */
  evaluateModel();

  /* Make sure that CFU is ready to execute operation */
  if(*req_ready != 1) {
    timeoutTick(req_ready, 1);
  }

  /* CFU accepted a command so check if it responded immediately */
  if(*resp_valid) {
    result = *resp_data;
    tick(true);
  } else {
    /* CFU did not finish operation so wait for it to assert a response */
    timeoutTick(resp_valid, 1);
    result = *resp_data;
  }

  /* CFU finished execution so CPU can deassert `req_valid` */
  *req_valid = 0;

  /* Apply changed signals without changing clock's edge */
  evaluateModel();

  /* Tick once to finish */
  tick(true);

  return result;
}

void Cfu::reset()
{
  *rst = 1;
  tick(true);
  *rst = 0;
  tick(true);
}
