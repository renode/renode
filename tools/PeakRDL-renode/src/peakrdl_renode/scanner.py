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

from systemrdl.node import FieldNode, MemNode, RegNode, AddrmapNode, RegfileNode
from systemrdl.walker import RDLListener, RDLWalker, WalkerAction

from .csharp import ast as ast
from .memory import RegArray, Reg


class ScannedState:
    def __init__(self, peripheral_name: str,
                 registers: list[Reg],
                 register_arrays: list[RegArray],
                 resets: dict[RegNode, int]):
        self.top_name = peripheral_name
        self.registers = registers
        self.register_arrays = register_arrays
        self.resets = resets

class RdlDesignScanner(RDLListener):
    regs: list[Reg]
    reg_arrs: list[RegArray]
    resets: dict[str, int]
    peripheral_name: str
    array: None | tuple[str, int]
    mem: None | tuple[str, int]
    regfile_stack: list[RegfileNode]

    def __init__(self, top_node: AddrmapNode) -> None:
        self.top_node = top_node
        self.regfile_stack = []
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
                reg = Reg(node, self.prefix_from_regfiles())
                # If a field does not have a reset value it will be reset to 0
                self.resets[reg.type_name] = 0
                self.regs.append(reg)
            case (str() as mem_name, addr):
                if node.is_array:
                    if len(node.array_dimensions) != 1:
                        raise RuntimeError('Multidimensional arrays are unsupported')
                reg_arr = RegArray(mem_name, node, addr, self.prefix_from_regfiles())
                # If a field does not have a reset value it will be reset to 0
                self.resets[reg_arr.type_name] = 0
                self.reg_arrs.append(reg_arr)

        return WalkerAction.Continue

    def enter_Regfile(self, node: RegfileNode):
        self.regfile_stack.append(node)
        return WalkerAction.Continue

    def exit_Regfile(self, node: RegfileNode):
        assert self.regfile_stack[-1] == node
        self.regfile_stack.pop()
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
        self.resets[self.regs[-1].type_name] |= reset << node.low

    def prefix_from_regfiles(self) -> list[str]:
        return list(x.inst_name for x in self.regfile_stack)
