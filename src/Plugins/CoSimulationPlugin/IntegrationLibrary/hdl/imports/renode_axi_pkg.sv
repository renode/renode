//
// Copyright (c) 2010-2024 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//

package renode_axi_pkg;
  typedef logic [1:0] response_t;
  typedef logic [7:0] burst_length_t;
  typedef logic [2:0] burst_size_t;
  typedef logic [1:0] burst_type_t;

  typedef enum response_t {
    Okay = 2'b00,
    ExclusiveAccessOkay = 2'b01,
    SlaveError = 2'b10,
    DecodeError = 2'b11
  } response_e;

  typedef enum burst_type_t {
    Fixed = 2'b00,
    Incrementing = 2'b01,
    Wrapping = 2'b10,
    Reserved = 2'b11
  } burst_type_e;
endpackage

