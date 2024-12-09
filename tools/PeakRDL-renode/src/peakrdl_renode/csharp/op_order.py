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
from .helper import Visitor, Hole
from itertools import chain

class Parenthesis(Expr):
    def __init__(self, expr: Expr, **kwargs):
        super().__init__(expr.type, **kwargs)
        self.expr = expr

    def children(self) -> op.Iterable[op.Node]:
        return [self.expr]

    def tokenize(self, cg: op.CodeGenerator) -> op.Iterable[str | op.CodeCC]:
        return chain('(', self.expr.tokenize(cg), ')')

class OrderOperators(Visitor):
    def __init__(self, nodes: Node, verbose: bool = False) -> None:
        super().__init__(nodes, verbose)

    @staticmethod
    def get_precedence(expr: Expr) -> int:
        match expr:
            case op.Mul() | op.Div(): return 13
            case op.Add() | op.Sub(): return 12
            case op.SHL() | op.SHR() | op.USHR(): return 11
            case op.GT() | op.LT() | op.GTE() | op.LTE(): return 10
            case op.EQ() | op.NEQ(): return 9
            case op.AND(): return 8
            case op.OR(): return 6
            case op.LAND(): return 5
            case op.LOR(): return 4
            case op.Cond(): return 2
            case BinaryOp(): return 0
        return 18

    @staticmethod
    def m_parenthesize(expr: Expr) -> None:
        hole = Hole()
        expr.replace(hole)
        parenthesis = Parenthesis(expr)
        hole.replace(parenthesis)

    @staticmethod
    def m_process_Op(node: Expr) -> None:
        for child in node.children():
            if OrderOperators.get_precedence(node) > OrderOperators.get_precedence(child):
                OrderOperators.m_parenthesize(child)

    def visit_Cast(self, node: Cast) -> None:
        if isinstance(node.expr, (BinaryOp, op.Cond)):
            OrderOperators.m_parenthesize(node.expr)

        self.iterate_children_dfs(node)

    def visit_BinaryOp(self, node: BinaryOp) -> None:
        OrderOperators.m_process_Op(node)
        self.iterate_children_dfs(node)

    def visit_Cond(self, node: op.Cond) -> None:
        OrderOperators.m_process_Op(node)
        self.iterate_children_dfs(node)
