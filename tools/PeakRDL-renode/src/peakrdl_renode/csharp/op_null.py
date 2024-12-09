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

from .ast import *
from . import operators as op
from .helper import Visitor

class EvalNulls(Visitor):
    def __init__(self, nodes: Node, verbose: bool = False) -> None:
        super().__init__(nodes, verbose)

    def visit_OR(self, node: op.OR) -> None:
        self.iterate_children_dfs(node)

        match (node.lhs, node.rhs):
            case (IntLit() as lit, expr) | (expr, IntLit() as lit):
                if lit.value == 0:
                    node.replace(expr.detach())
            case (IntLit() as lit1, IntLit() as lit2):
                if lit1.value == 0 and lit2.value == 0:
                    node.replace(lit1.detach())

    def visit_AND(self, node: op.AND) -> None:
        self.iterate_children_dfs(node)

        match (node.lhs, node.rhs):
            case (IntLit() as lit, expr) | (expr, IntLit() as lit):
                if lit.value == 0:
                    node.replace(lit.detach())
                elif lit.value == (1 << expr.type.width) - 1:
                    node.replace(expr.detach())

    def visit_BinaryOp(self, node: BinaryOp) -> None:
        self.iterate_children_dfs(node)

        match node:
            case op.SHL() | op.SHR() | op.USHR():
                if isinstance(node.rhs, IntLit) and node.rhs.value == 0:
                    node.replace(node.lhs.detach())
            case op.Add() | op.Sub():
                match (node.lhs, node.rhs):
                    case (IntLit() as lit, other) | (other, IntLit() as lit):
                        if lit.value == 0:
                            node.replace(lit.detach())
