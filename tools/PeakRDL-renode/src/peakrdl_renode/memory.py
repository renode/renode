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

from itertools import chain

from systemrdl.node import RegNode, FieldNode, RegfileNode
import caseconverter
from types import SimpleNamespace
from typing import TYPE_CHECKING

from .csharp import ast as ast
from .csharp.helper import TemplatedAST, TemplateHole
from .csharp import operators as op

if TYPE_CHECKING:
    from .scanner import ScannedState

PUBLIC = ast.AccessibilityMod.PUBLIC
PROTECTED = ast.AccessibilityMod.PROTECTED
PRIVATE = ast.AccessibilityMod.PRIVATE

def variable_name(name: str, regfiles: list[str]) -> str:
    return '_'.join(caseconverter.pascalcase(x) for x in chain(regfiles, (name,)))

def doc_name(name: str, regfiles: list[str]) -> str:
    return '.'.join(chain(regfiles, (name,)))


class Field:
    def __init__(self, node: 'FieldNode | Field'):
        self.high = node.high
        self.low = node.low
        self.is_sw_writable = node.is_sw_writable
        self.is_sw_readable = node.is_sw_readable
        if isinstance(node, FieldNode):
            self.name = node.inst_name
            self.onread = node.get_property('onread')
            self.onwrite = node.get_property('onwrite')
        else:
            self.name = node.name
            self.onread = node.onread
            self.onwrite = node.onwrite


class Reg:
    def __init__(self, node: 'RegNode | Reg', regfiles: list[str]):
        self.regfiles = regfiles
        self.absolute_address = node.absolute_address
        if isinstance(node, RegNode):
            self.name = node.inst_name
            self.fields = [Field(x) for x in node.fields()]
        else:
            self.name = node.name
            self.fields = []

    @property
    def variable_name(self) -> str:
        return variable_name(self.name, self.regfiles)

    @property
    def doc_name(self) -> str:
        return doc_name(self.name, self.regfiles)

    @property
    def type_name(self) -> str:
        return self.variable_name + 'Type'

    @staticmethod
    def try_merge(scanned: 'ScannedState', reg1: 'Reg', reg2: 'Reg') -> 'Reg':
        # This function will attempt to merge two SystemRDL registers into one
        # register that can be created in Renode. For registers to be merged the following
        # conditions have to be met:
        # * One register has to be fully read-only and the other fully write-only
        # * Both registers have to have a single field of the same width on the same offset
        # Merging is sometimes needed as Renode generally expects a single register on a given
        # offset and the separate read/write behavior can be achieved using the appropriate
        # register access callbacks.

        error_obj = RuntimeError(f'Registers {reg1.doc_name} and {reg2.doc_name} cannot be merged')

        if len(reg1.fields) != 1 or len(reg2.fields) != 1:
            raise error_obj

        field1 = reg1.fields[0]
        field2 = reg2.fields[0]

        if field1.low != field2.low or field2.high != field2.high:
            raise error_obj

        new_reg = Reg(reg1, reg1.regfiles)
        new_reg.name = f'{reg1.name}_{reg2.name}'

        new_field = Field(field1)
        new_field.name = f'{field1.name}_{field2.name}'
        # The match statements below will create a read/write register
        new_field.is_sw_readable = True
        new_field.is_sw_writable = True

        match (field1.is_sw_readable, field1.is_sw_writable, field2.is_sw_readable, field2.is_sw_writable):
            case (True, False, False, True):
                scanned.resets[new_reg.type_name] = scanned.resets[reg1.type_name]
                new_field.onread = field1.onread
                new_field.onwrite = field2.onwrite
            case (False, True, True, False):
                scanned.resets[new_reg.type_name] = scanned.resets[reg2.type_name]
                new_field.onread = field2.onread
                new_field.onwrite = field1.onwrite
            case _:
                raise RuntimeError('Unsupported field access configuration')

        new_reg.fields.append(new_field)
        return new_reg


class RegArray:
    def __init__(self, name: str, register: RegNode, address: int, regfiles: list[str]):
        self.name = name
        self.register = register
        self.addr = address
        self.regfiles = regfiles

    @property
    def count(self) -> int:
        return self.register.array_dimensions[0]

    @property
    def stride(self) -> int:
        return self.register.array_stride

    @property
    def variable_name(self) -> str:
        return variable_name(self.name, self.regfiles)

    @property
    def type_name(self) -> str:
        return self.variable_name + 'Type'

    @property
    def doc_name(self) -> str:
        return doc_name(self.name, self.regfiles)

    @staticmethod
    def m_get_underlying_field_type(field: FieldNode) -> ast.Type:
        match field.high - field.low + 1:
            case width if width == 1: return ast.Type.bool
            case width if width in range(2, 9): return ast.Type.byte
            case width if width in range(9, 17): return ast.Type.ushort
            case width if width in range(17, 33): return ast.Type.uint
            case width if width in range(33, 65): return ast.Type.ulong
            case _: raise RuntimeError(f'The field `{field.inst_name}` is too wide')

    @staticmethod
    def m_cast_to_field_type(ty: ast.Type, expr: ast.Expr) -> ast.Expr:
        if ty == expr.type:
            return expr

        if ty == ast.Type.bool:
            return op.NEQ(expr, ast.IntLit(0, expr.type.is_unsigned, expr.type.is_long))

        return ast.Cast(ty, expr)

    @staticmethod
    def m_get_underlying_field_mask(field: FieldNode) -> ast.IntLit:
        return ast.IntLit(1 << (field.high - field.low + 1) - 1, fmt='h')

    @staticmethod
    def m_generate_underlying_field_decl(field: FieldNode) -> ast.VariableDecl:
        return ast.VariableDecl(
            name = caseconverter.camelcase(field.inst_name),
            ty = RegArray.m_get_underlying_field_type(field)
        )

    @staticmethod
    def m_generate_underlying_property(field: FieldNode) -> ast.VariableDecl:
        width = field.high - field.low + 1
        bytes_to_access = (width + 7) // 8
        first_byte = field.low // 8
        shift = field.low % 8

        field_type = RegArray.m_get_underlying_field_type(field)

        def idx_byte(offset: int) -> ast.HardExpr:
            return ast.HardExpr(f'memory[spanBegin + {first_byte + offset}]', ast.Type.byte)

        def byte_mask(byte_idx) -> int:
            return ((((1 << (width)) - 1) << shift) >> (byte_idx * 8)) & 0xff

        get_tempvar = ast.VariableDecl(
            'temp',
            field_type,
            init = ast.IntLit(0) if field_type is not ast.Type.bool else None
        )
        set_value = ast.VariableDecl('value', field_type)

        def generate_getter_assignmnets() -> ast.Stmt:
            if field_type == ast.Type.bool:
                return ast.Assign(
                    lhs = get_tempvar.ref(),
                    rhs = op.NEQ(
                        lhs = op.AND(
                            lhs = idx_byte(0),
                            rhs = ast.IntLit(byte_mask(0), fmt='h')
                        ),
                        rhs = ast.IntLit(0)
                    )
                ).into_stmt()

            return ast.Node.join(
                # for idx in range(bytes_to_access)
                ast.Assign(
                    lhs = get_tempvar.ref(),
                    rhs = ast.Cast(field_type, op.OR(
                        lhs = get_tempvar.ref(),
                        rhs = # if idx == 0
                            op.SHR(
                                lhs = ast.Cast(field_type, op.AND(
                                    lhs = idx_byte(idx),
                                    rhs = ast.IntLit(byte_mask(idx), fmt='h')
                                )),
                                rhs = ast.IntLit(shift)
                            )
                            if idx == 0 else
                            op.SHL(
                                lhs = ast.Cast(field_type, op.AND(
                                    lhs = idx_byte(idx),
                                    rhs = ast.IntLit(byte_mask(idx), fmt='h')
                                )),
                                rhs = ast.IntLit(((idx - 1) * 8) + (8 - shift))
                            )
                    )
                )).into_stmt()
                for idx in range(bytes_to_access)
            )

        def generate_setter_assignments() -> ast.Stmt:
            def get_field_value_masked(mask: int) -> ast.Expr:
                if field_type == ast.Type.bool:
                    return op.Cond(
                        cond = set_value.ref(),
                        then_ = ast.IntLit(1, unsigned=True),
                        else_ = ast.IntLit(0, unsigned=True)
                    )
                return op.AND(
                    lhs = set_value.ref(),
                    rhs = ast.IntLit(mask, unsigned = True, fmt='h')
                )

            def get_field_value_masked_upcast(mask: int) -> ast.Expr:
                if shift > 0 and field_type in [ast.Type.byte, ast.Type.ushort]:
                    return ast.Cast(ast.Type.uint, get_field_value_masked(mask))
                return get_field_value_masked(mask)

            return ast.Node.join(
                # for idx in range(bytes_to_access)
                ast.Assign(
                    lhs = idx_byte(idx),
                    rhs = ast.Cast(ast.Type.byte, op.OR(
                        lhs = op.AND(
                            lhs = idx_byte(idx),
                            rhs = ast.IntLit(0xff - byte_mask(idx), unsigned=True, fmt='h')
                        ),
                        rhs = # if idx == 0
                            op.SHL(
                                lhs = get_field_value_masked_upcast((1 << width) - 1),
                                rhs = ast.IntLit(shift)
                            )
                            if idx == 0 else
                            op.SHR(
                                lhs = get_field_value_masked((1 << width) - 1),
                                rhs = ast.IntLit(((idx - 1) * 8) + (8 - shift))
                            )
                    ))
                ).into_stmt()
                for idx in range(bytes_to_access)
            )

        return ast.PropertyDefintion(
            name = field.inst_name.upper(),
            access = PUBLIC,
            doc = f'Offset: {hex(field.low)}, Width: {width} bits',
            get = ast.Node.join([
                get_tempvar,
                generate_getter_assignmnets(),
                ast.Return(get_tempvar.ref())
            ]),
            set = generate_setter_assignments(),
            ret_ty = field_type
        )

    def generate_csharp_wrapper_type(self) -> ast.Class:
        class_name = caseconverter.pascalcase(self.name) + '_' + caseconverter.pascalcase(self.register.inst_name) + 'Wrapper'

        return ast.Class(
            name = class_name,
            struct = False,
            access = PUBLIC,
            fields = ast.Node.join([
                ast.VariableDecl('spanBegin', ast.Type.long, access=PRIVATE),
                ast.VariableDecl('memory', ast.Type.byte.array(), access=PRIVATE)
            ]),
            properties = ast.Node.join(
                RegArray.m_generate_underlying_property(field)
                for field in self.register.fields()
            ),
            methods = ast.MethodDefinition(
                name = class_name,
                constructor = True,
                access = PUBLIC,
                args = ast.ArgDecl('memory', ast.Type.byte.array())
                    .then(ast.ArgDecl('spanBegin', ast.Type.long)),
                body = ast.Node.join([
                    ast.Assign(
                        lhs = ast.HardExpr('this.memory', ty=ast.Type.byte.array()),
                        rhs = ast.HardExpr('memory', ty=ast.Type.byte.array())
                    ).into_stmt(),
                    ast.Assign(
                        lhs = ast.HardExpr('this.spanBegin', ast.Type.long),
                        rhs = ast.HardExpr('spanBegin', ast.Type.long)
                    ).into_stmt(),
                ])
            )
        )

    def generate_csharp_container_type(self) -> ast.Class:
        class_name = self.type_name

        wrapper_type = self.generate_csharp_wrapper_type()

        return ast.Class(
            name = class_name,
            access = PROTECTED,
            fields = ast.VariableDecl('memory', ast.Type.byte.array(), access=PRIVATE),
            properties = ast.Node.join([
                ast.PropertyDefintion(
                    name = 'Size',
                    access = PUBLIC,
                    ret_ty = ast.Type.long,
                    get = ast.Return(ast.IntLit(self.count * self.stride, long=True))
                ),
                ast.PropertyDefintion(
                    name = 'this[long index]',
                    access = PUBLIC,
                    ret_ty = wrapper_type.type,
                    get = ast.Node.join([
                        ast.If(
                            condition = op.LOR(
                                lhs = op.LT(
                                    lhs = ast.HardExpr('index', ty=ast.Type.long),
                                    rhs = ast.IntLit(0)
                                ),
                                rhs = op.GTE(
                                    lhs = ast.HardExpr('index', ty=ast.Type.long),
                                    rhs = ast.IntLit(self.count)
                                ),
                            ),
                            then = ast.Throw(
                                ast.New(
                                    ast.Type('System.IndexOutOfRangeException')
                                )
                            )
                        ),
                        ast.Return(ast.New(
                            wrapper_type.type,
                            ast.Arg('memory'),
                            ast.Arg(f'index * {self.stride}')
                        ))
                    ])
                )
            ]),
            methods = ast.Node.join([
                ast.MethodDefinition(
                    name = class_name,
                    access = PUBLIC,
                    constructor = True,
                    body = ast.Assign(
                        lhs = ast.HardExpr('memory', ast.Type.byte.array()),
                        rhs = ast.NewArray(ast.Type.byte, 'Size')
                    ).into_stmt()
                ),
                ast.MethodDefinition(
                    name = 'ReadDoubleWord',
                    access = PUBLIC,
                    args = ast.ArgDecl('offset', ast.Type.long),
                    body = ast.Return(ast.HardExpr(
                        f'(uint)memory[offset] + '
                        f'((uint)memory[offset + 1] << 8) + ' +
                        f'((uint)memory[offset + 2] << 16) + ' +
                        f'((uint)memory[offset + 3] << 24)',
                        ast.Type.long
                    )),
                    ret_ty = ast.Type.uint
                ),
                ast.MethodDefinition(
                    name = 'WriteDoubleWord',
                    access = PUBLIC,
                    args = ast.Node.join([
                        ast.ArgDecl('offset', ast.Type.long),
                        ast.ArgDecl('value', ast.Type.uint)
                    ]),
                    body = ast.Node.join([
                        ast.Assign(
                            lhs = ast.HardExpr('memory[offset]', ast.Type.byte),
                            rhs = ast.Cast(ast.Type.byte,
                                           ast.HardExpr('value', ast.Type.uint))
                        ).into_stmt(),
                        ast.Assign(
                            lhs = ast.HardExpr('memory[offset + 1]', ast.Type.byte),
                            rhs = ast.Cast(ast.Type.byte,
                                           ast.HardExpr('(value >> 8)', ast.Type.uint))
                        ).into_stmt(),
                        ast.Assign(
                            lhs = ast.HardExpr('memory[offset + 2]', ast.Type.byte),
                            rhs = ast.Cast(ast.Type.byte,
                                           ast.HardExpr('(value >> 16)', ast.Type.uint))
                        ).into_stmt(),
                        ast.Assign(
                            lhs = ast.HardExpr('memory[offset + 3]', ast.Type.byte),
                            rhs = ast.Cast(ast.Type.byte,
                                           ast.HardExpr('(value >> 24)', ast.Type.uint))
                        ).into_stmt()
                    ])
                )
            ]),
            classes = wrapper_type
        )

    def m_generate_conditional_access(
            self,
            me: ast.VariableDecl,
            offset_var: ast.VariableDecl
        ) -> SimpleNamespace:
        return TemplatedAST(
            ast.If(
                condition = op.LAND(
                    lhs = op.GTE(
                        lhs = offset_var.ref(),
                        rhs = ast.IntLit(self.addr)
                    ),
                    rhs = op.LT(
                        lhs = offset_var.ref(),
                        rhs = op.Add(
                            lhs = ast.IntLit(self.addr, long=True),
                            rhs = ast.HardExpr(f'{me.ref()}.Size', ty='long')
                        )
                    )
                ),
                then = TemplateHole('then')
            )
        ).template

    def generate_dword_read_logic(
        self,
        me: ast.VariableDecl,
        offset_var: ast.VariableDecl
    ) -> ast.Stmt:
        template = self.m_generate_conditional_access(me, offset_var)
        template.then.replace(ast.Return(
            ast.Call(
                'ReadDoubleWord',
                ast.Arg(f'{offset_var.ref()} - {self.addr}'),
                object = me.ref()
            )
        ))

        return template.ast

    def generate_dword_write_logic(
        self,
        me: ast.VariableDecl,
        offset_var: ast.VariableDecl,
        value_var: ast.VariableDecl
    ) -> ast.Stmt:
        template = self.m_generate_conditional_access(me, offset_var)
        template.then.replace(ast.Node.join([
            ast.Call(
                'WriteDoubleWord',
                ast.Arg(f'{offset_var.ref()} - {self.addr}'),
                ast.Arg(str(value_var.ref())),
                object=me.ref()
            ).into_stmt(),
            ast.Return()
        ]))

        return template.ast
