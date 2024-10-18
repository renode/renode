//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

package renode_ahb_pkg;
  typedef logic response_t;
  typedef logic [2:0] burst_t;
  typedef logic transfer_direction_t;
  typedef logic [1:0] transfer_type_t;
  typedef logic [2:0] transfer_size_t;

  typedef enum response_t {
    Okay  = 1'b0,
    Error = 1'b1
  } response_e;

  typedef enum burst_t {
    Single = 3'b000,
    Incrementing = 3'b001,
    Wrapping4 = 3'b010,
    Incrementing4 = 3'b011,
    Wrapping8 = 3'b100,
    Incrementing8 = 3'b101,
    Wrapping16 = 3'b110,
    Incrementing16 = 3'b111
  } burst_e;

  typedef enum transfer_direction_t {
    Read  = 1'b0,
    Write = 1'b1
  } transfer_direction_e;

  typedef enum transfer_type_t {
    Idle = 2'b00,
    Busy = 2'b01,
    NonSequential = 2'b10,
    Sequential = 2'b11
  } transfer_type_e;

  // Notice that the bus uses different naming convention for sizes than Renode.
  typedef enum transfer_size_t {
    Byte8bit = 3'b000,
    Halfword16bit = 3'b001,
    Word32bit = 3'b010,
    Doubleword64bit = 3'b011
  } transfer_size_e;
endpackage
