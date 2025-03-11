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

from typing import Iterable
from peakrdl_renode.csharp.ast import CodeCC, CodeGenerator, Expr, Node, Type
from itertools import chain
from .ast import *

class GT(BinaryOp):
    def __init__(self, lhs: Expr, rhs: Expr, **kwargs):
        super().__init__('>', lhs, rhs, Type.bool, **kwargs)

class LT(BinaryOp):
    def __init__(self, lhs: Expr, rhs: Expr, **kwargs):
        super().__init__('<', lhs, rhs, Type.bool, **kwargs)

class GTE(BinaryOp):
    def __init__(self, lhs: Expr, rhs: Expr, **kwargs):
        super().__init__('>=', lhs, rhs, Type.bool, **kwargs)

class LTE(BinaryOp):
    def __init__(self, lhs: Expr, rhs: Expr, **kwargs):
        super().__init__('<=', lhs, rhs, Type.bool, **kwargs)

class EQ(BinaryOp):
    def __init__(self, lhs: Expr, rhs: Expr, **kwargs):
        super().__init__('==', lhs, rhs, Type.bool, **kwargs)

class NEQ(BinaryOp):
    def __init__(self, lhs: Expr, rhs: Expr, **kwargs):
        super().__init__('!=', lhs, rhs, Type.bool, **kwargs)

class Add(BinaryOp):
    def __init__(self, lhs: Expr, rhs: Expr, **kwargs):
        super().__init__('+', lhs, rhs, lhs.type, **kwargs)

class Sub(BinaryOp):
    def __init__(self, lhs: Expr, rhs: Expr, **kwargs):
        super().__init__('-', lhs, rhs, lhs.type, **kwargs)

class Mul(BinaryOp):
    def __init__(self, lhs: Expr, rhs: Expr, **kwargs):
        super().__init__('*', lhs, rhs, lhs.type, **kwargs)

class Div(BinaryOp):
    def __init__(self, lhs: Expr, rhs: Expr, **kwargs):
        super().__init__('/', lhs, rhs, lhs.type, **kwargs)

class SHL(BinaryOp):
    def __init__(self, lhs: Expr, rhs: Expr, **kwargs):
        if lhs.type.width is None: raise RuntimeError('Invalid operand for bitshift')
        ty_ = lhs.type if lhs.type.width >= 32 else Type.int
        super().__init__('<<', lhs, rhs, ty_, **kwargs)

class SHR(BinaryOp):
    def __init__(self, lhs: Expr, rhs: Expr, **kwargs):
        if lhs.type.width is None: raise RuntimeError('Invalid operand for bitshift')
        ty_ = lhs.type if lhs.type.width >= 32 else Type.int
        super().__init__('>>', lhs, rhs, ty_, **kwargs)

class USHR(BinaryOp):
    def __init__(self, lhs: Expr, rhs: Expr, **kwargs):
        if lhs.type.width is None: raise RuntimeError('Invalid operand for bitshift')
        ty_ = lhs.type if lhs.type.width >= 32 else Type.int
        super().__init__('>>>', lhs, rhs, ty_, **kwargs)

class AND(BinaryOp):
    def __init__(self, lhs: Expr, rhs: Expr, **kwargs):
        super().__init__('&', lhs, rhs, lhs.type, **kwargs)

class OR(BinaryOp):
    def __init__(self, lhs: Expr, rhs: Expr, **kwargs):
        super().__init__('|', lhs, rhs, lhs.type, **kwargs)

class LAND(BinaryOp):
    def __init__(self, lhs: Expr, rhs: Expr, **kwargs):
        super().__init__('&&', lhs, rhs, Type.bool, **kwargs)

class LOR(BinaryOp):
    def __init__(self, lhs: Expr, rhs: Expr, **kwargs):
        super().__init__('||', lhs, rhs, Type.bool, **kwargs)

class Cond(Expr):
    def __init__(self, cond: Expr, then_: Expr, else_: Expr, **kwargs):
        super().__init__(then_.type, **kwargs)

        self.cond = cond
        self.then_ = then_
        self.else_ = else_

        cond.parent = (self, 'cond')
        then_.parent = (self, 'then_')
        else_.parent = (self, 'else_')

    def children(self) -> Iterable[Node]:
        return [self.cond, self.then_, self.else_]

    def tokenize(self, cg: CodeGenerator) -> Iterable[str | CodeCC]:
        return chain(
            self.emit_comment_tokens(inline=True),
            self.cond.tokenize(cg),
            [' ? '],
            self.then_.tokenize(cg),
            [' : '],
            self.else_.tokenize(cg)
        )
