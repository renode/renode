#!/usr/bin/env bash

# Parses TCG opcode backtrace lines from stdin and translates them to file, function and line number.

while read time level core at location rest; do 
  # Example location string: /tmp/renode-1661630/0-Antmicro.Renode.translate-riscv64-le.so(symbol+0x11b5b2)
  lib_path=$(echo "${location}" | grep -oP "^[^(]*") # Extract until first '('
  address=$(echo "${location}" | grep -oP "\(\K.*\+0x[a-z\d]*") # Extract symbol+offset
  addr2line -psf --exe ${lib_path} ${address}
done
