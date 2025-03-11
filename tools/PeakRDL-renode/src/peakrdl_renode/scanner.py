#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# Copyright (C) 2024 Antmicro
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0

from systemrdl.node import FieldNode, MemNode, RegNode, AddrmapNode
from systemrdl.walker import RDLListener, RDLWalker, WalkerAction

from .csharp import ast as ast
from .memory import RegArray


class ScannedState:
    def __init__(self, peripheral_name: str,
                 registers: list[RegNode],
                 register_arrays: list[RegArray],
                 resets: dict[RegNode, int]):
        self.top_name = peripheral_name
        self.registers = registers
        self.register_arrays = register_arrays
        self.resets = resets

class RdlDesignScanner(RDLListener):
    regs: list[RegNode]
    reg_arrs: list[RegArray]
    resets: dict[str, int]
    peripheral_name: str
    array: None | tuple[str, int]
    mem: None | tuple[str, int]

    def __init__(self, top_node: AddrmapNode) -> None:
        self.top_node = top_node
        self.regs = []
        self.reg_arrs = []
        self.mem = None
        self.array = None
        self.resets = {}
        self.peripheral_name = top_node.inst_name

    def run(self) -> ScannedState:
        RDLWalker().walk(self.top_node, self)
        return ScannedState(self.peripheral_name, self.regs, self.reg_arrs, self.resets)

    def enter_Reg(self, node: RegNode) -> WalkerAction | None:
        match self.mem:
            case None:
                self.regs.append(node)
            case (str() as mem_name, addr):
                if node.is_array:
                    if len(node.array_dimensions) != 1:
                        raise RuntimeError('Multidimensional arrays are unsupported')
                reg_array = RegArray(mem_name, node, addr)
                self.reg_arrs.append(reg_array)

        self.resets[node.inst_name] = 0
        return WalkerAction.Continue

    def enter_Field(self, node: FieldNode) -> WalkerAction | None:
        reset = node.get_property('reset')
        self.add_field_reset_value(node, reset if reset is not None else 0)
        return WalkerAction.Continue

    def enter_Mem(self, node: MemNode) -> WalkerAction | None:
        if self.mem is not None:
            raise RuntimeError('Encountered a nested memory')

        self.mem = (node.inst_name, node.absolute_address)

        return WalkerAction.Continue

    def exit_Mem(self, node: MemNode) -> WalkerAction | None:
        self.mem = None
        return WalkerAction.Continue

    def add_field_reset_value(self, node: FieldNode, reset: int) -> None:
        if reset == 0:
            return

        width = node.high - node.low + 1
        fullreset = (1 << width) - 1;

        self.resets[self.regs[-1].inst_name] |= fullreset << node.low