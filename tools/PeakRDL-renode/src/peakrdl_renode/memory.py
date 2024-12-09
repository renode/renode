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

from systemrdl.node import RegNode, FieldNode
from types import SimpleNamespace

from .csharp import ast as ast
from .csharp.helper import TemplatedAST, TemplateHole
from .csharp import operators as op
from .util import PascalCase, camelCase

PUBLIC = ast.AccessibilityMod.PUBLIC
PROTECTED = ast.AccessibilityMod.PROTECTED
PRIVATE = ast.AccessibilityMod.PRIVATE

class RegArray:
    def __init__(self, name: str, register: RegNode, address: int):
        self.name = name
        self.register = register
        self.addr = address

    @property
    def count(self) -> int:
        return self.register.array_dimensions[0]

    @property
    def stride(self) -> int:
        return self.register.array_stride

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
            name = camelCase(field.inst_name),
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
                                lhs = get_field_value_masked((1 << width) - 1),
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
        class_name = PascalCase(self.name) + '_' + PascalCase(self.register.inst_name) + 'Wrapper'

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
        class_name = \
            PascalCase(self.name) + '_' + PascalCase(self.register.inst_name) + 'Container'

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
