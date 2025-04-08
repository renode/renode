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

from typing import Union, Optional

from systemrdl.node import RootNode, AddrmapNode
from systemrdl.rdltypes import OnReadType, OnWriteType
from itertools import chain
from functools import reduce

from .csharp import ast as ast
from .scanner import ScannedState, RdlDesignScanner
from .csharp.process import process_ast
from .memory import Reg, RegArray, Field

PUBLIC = ast.AccessibilityMod.PUBLIC
PROTECTED = ast.AccessibilityMod.PROTECTED
PRIVATE = ast.AccessibilityMod.PRIVATE


class RegisterPreprocessor:
    def __init__(self):
        pass

    def run(self, scanned: ScannedState, registers: list[Reg]) -> list[Reg]:
        offset_to_reg: dict[int, Reg] = {}
        for reg in registers:
            offset = reg.absolute_address
            if offset in offset_to_reg:
                offset_to_reg[offset] = Reg.try_merge(scanned, offset_to_reg[offset], reg)
            else:
                offset_to_reg[offset] = reg

        return list(offset_to_reg.values())


class CSharpGenerator:
    ty_IFlagRegisterField = ast.Type('IFlagRegisterField')
    ty_IValueRegisterField = ast.Type('IValueRegisterField')

    def __init__(self, scanned: ScannedState, name: str, namespace: str,
                 make_all_public: bool = False) -> None:
        self.scanned = scanned
        self.name = name if name is not None else scanned.top_name


        self.ty_register = ast.Type('DoubleWordRegister')
        self.ty_register_collection = ast.Type('DoubleWordRegisterCollection')

        self.iprovides_register_collection = ast.Class(
            name = f'IProvidesRegisterCollection<{self.ty_register_collection}>'
        )

        scanned.registers = RegisterPreprocessor().run(scanned, scanned.registers)

        self.reg_classes = {
            reg.type_name: self.generate_value_container_class(reg)
            for reg in scanned.registers
        }

        regarray_containers = {reg_arr.type_name: reg_arr.generate_csharp_container_type() \
                            for reg_arr in scanned.register_arrays}

        regarray_fields = {
            ra.variable_name: ast.VariableDecl(
                name = ra.variable_name,
                ty = regarray_containers[ra.type_name].type,
                access = PROTECTED,
                doc = f'Memory "{ra.doc_name}" at {hex(ra.addr)}'
            )
            for ra in scanned.register_arrays
        }

        def make_reg_instance_assignement(c: ast.VariableDecl):
            return ast.Assign(
                lhs = c.ref(),
                rhs = ast.New(c.type, ast.Arg(ast.This()))
            ).into_stmt()

        def make_regarray_assignement(c: ast.VariableDecl):
            return ast.Assign(
                lhs = c.ref(),
                rhs = ast.New(c.type)
            ).into_stmt()

        def generate_read_method() -> ast.MethodDefinition:
            offset_arg = ast.ArgDecl(name='offset', ty=ast.Type.long)

            return ast.MethodDefinition(
                name = 'IDoubleWordPeripheral.ReadDoubleWord',
                args = offset_arg,
                body = ast.Node.join(
                    [
                        regarray.generate_dword_read_logic(
                            regarray_fields[regarray.variable_name],
                            offset_arg
                        )
                        for regarray in scanned.register_arrays
                    ] + [
                        ast.Return(ast.Call(
                            ast.MethodDefinition(name='Read'),
                            ast.Arg(ast.HardCode('offset')),
                            object = ast.HardCode('RegistersCollection')
                        ))
                    ]
                ),
                ret_ty = ast.Type.uint
            )

        def generate_write_method() -> ast.Node:
            offset_arg = ast.ArgDecl(name='offset', ty=ast.Type.long)
            value_arg = ast.ArgDecl(name='value', ty=ast.Type.uint)

            return ast.MethodDefinition(
                name = 'IDoubleWordPeripheral.WriteDoubleWord',
                args = ast.Node.join([offset_arg, value_arg]),
                body = ast.Node.join(
                    [
                        regarray.generate_dword_write_logic(
                            regarray_fields[regarray.variable_name],
                            offset_arg,
                            value_arg
                        )
                        for regarray in scanned.register_arrays
                    ] + [
                        ast.Call(
                            'Write',
                            ast.Arg(ast.HardCode('offset')),
                            ast.Arg(ast.HardCode('value')),
                            object=ast.HardCode('RegistersCollection')
                        ).into_stmt()
                    ]
                ),
            )

        reg_instances = [
            ast.VariableDecl(
                name = reg.variable_name,
                ty = self.reg_classes[reg.type_name].type,
                access = PROTECTED,
                doc = f'Register "{reg.doc_name}" at {hex(reg.absolute_address)}'
            )
            for reg in self.scanned.registers
        ]

        init_method = ast.MethodDefinition(name='Init', partial=True)
        reset_method = ast.MethodDefinition(name='Reset', partial=True)

        self.peripheral_class = ast.Class(
            name = self.name,
            access = PUBLIC,
            fields = ast.Node.join(chain(reg_instances, regarray_fields.values())),
            properties = ast.PropertyDefintion(
                name = 'RegistersCollection',
                access = PUBLIC,
                ret_ty = self.ty_register_collection,
                get = True
            ),
            methods = ast.Node.join([
                ast.MethodDefinition(
                    name = self.name,
                    constructor = True,
                    access = PUBLIC,
                    body = ast.Node.join([
                        ast.Assign(
                            lhs = ast.HardExpr('RegistersCollection', self.ty_register_collection),
                            rhs = ast.New(self.ty_register_collection, ast.This())
                        ).into_stmt(),
                        *map(make_reg_instance_assignement, reg_instances),
                        *(make_regarray_assignement(container_member)
                          for container_member in regarray_fields.values()),
                        ast.Call(init_method, object=ast.This()).into_stmt()
                    ])
                ),
                init_method,
                reset_method,
                ast.MethodDefinition(name='IPeripheral.Reset', body = ast.Node.join([
                    ast.Call(reset_method, object=ast.This()).into_stmt(),
                    ast.Call('Reset', object=ast.HardCode('RegistersCollection')).into_stmt()
                ])),
                generate_read_method(),
                generate_write_method()
            ]),
            classes = ast.Node.join(chain(
                self.reg_classes.values(),
                regarray_containers.values()
            )),
            derives = [
                (None, self.iprovides_register_collection),
                (None, ast.Class(name = "IPeripheral")),
                (None, ast.Class(name = "IDoubleWordPeripheral"))
            ],
            partial = True
        )

        self.namespace = ast.Namespace(namespace, classes=self.peripheral_class)

        self.root = ast.Namespace('Antmicro', namespaces=[
            ast.Namespace('Renode', namespaces=[
                ast.Namespace('Peripherals', namespaces=[
                    self.namespace
                ])
            ])
        ])

        process_ast(self.root, make_all_public=make_all_public)

    def generate_code(self) -> str:
        code = \
            '// Generated by PeakRDL-renode\n\n' + \
            'using Antmicro.Renode.Core.Structure.Registers;\n' + \
            'using Antmicro.Renode.Peripherals.Bus;\n\n' + \
            ast.CodeGenerator.emit(self.namespace, docs=True)

        return '\n'.join(line.rstrip() for line in code.splitlines()) + '\n'

    def generate_field_modifier(self, field: Field) -> list[ast.Arg]:
        match field.onread:
            case OnReadType.rclr: read_flag = 'FieldMode.ReadToClear'
            case OnReadType.rset: read_flag = 'FieldMode.ReadToSet'
            case OnReadType.ruser:
                read_flag = 'FieldMode.Read'
            case _: read_flag = 'FieldMode.Read' if field.is_sw_readable else None

        match field.onwrite:
            case OnWriteType.woset: write_flag = 'FieldMode.Set'
            case OnWriteType.woclr: write_flag = 'FieldMode.WriteOneToClear'
            case OnWriteType.wot: write_flag = 'FieldMode.Toggle'
            case OnWriteType.wzs: write_flag = 'FieldMode.WriteZeroToSet'
            case OnWriteType.wzc: write_flag = 'FieldMode.WriteZeroToClear'
            case OnWriteType.wzt: write_flag = 'FieldMode.WriteZeroToToggle'
            case OnWriteType.wclr: write_flag = 'FieldMode.WriteToClear'
            case OnWriteType.wset: write_flag = 'FieldMode.WriteToSet'
            case OnWriteType.wuser:
                write_flag = 'FieldMode.Write'
            case _: write_flag = 'FieldMode.Write' if field.is_sw_writable else None

        match (read_flag, write_flag):
            case ('FieldMode.Read', 'FieldMode.Write'): return []
            case (str(f), None) | (None, str(f)): return [ast.Arg(f, name = 'mode')]
            case (str(rd), str(wr)): return [ast.Arg(rd + ' | ' + wr, name = 'mode')]
            case (None, None): raise RuntimeError('Can\'t calculate field access flags')

    def generate_field_decl(self, field: Field,
                            underlying_var: Optional[str] = None) -> ast.Call:
        field_width = field.high - field.low + 1
        field_name_arg = ast.StringLit(field.name.upper())

        match (field_width == 1, underlying_var):
            case (True, str(out_var)): return ast.Call(
                'WithFlag',
                ast.Arg(field.low),
                ast.Arg(out_var, out=True),
                *self.generate_field_modifier(field),
                ast.Arg(field_name_arg, name='name'),
                ret_ty=self.ty_register
            )
            case (True, None): return ast.Call(
                'WithTaggedFlag',
                ast.Arg(field_name_arg),
                ast.Arg(field.low),
                ret_ty=self.ty_register
            )
            case (False, out_var): return ast.Call(
                'WithValueField',
                ast.Arg(field.low),
                ast.Arg(field_width),
                *([ast.Arg(out_var, out=True)] if type(out_var) is str else []),
                *self.generate_field_modifier(field),
                ast.Arg(field_name_arg, name='name'),
                ret_ty=self.ty_register
            )
            case _: raise RuntimeError('Unhandled field configuration')

    def generate_value_container_class(
        self,
        register: Reg
    ) -> ast.Class:

        def make_var_decl(field: Field):
            field_width = field.high - field.low + 1
            return ast.VariableDecl(
                name = field.name.upper(),
                ty = self.ty_IFlagRegisterField if field_width == 1
                     else self.ty_IValueRegisterField,
                access = PUBLIC,
                doc = f'Field "{field.name}" at {hex(field.low)}, ' +
                      f'width: {field.high - field.low + 1} bits'
            )

        def add_field_impl(obj: ast.Node, field: Field):
            call = self.generate_field_decl(field, field.name.upper())
            call.object = obj
            call.breakline = True
            return call

        name = register.type_name

        methods = [
            ast.MethodDefinition(
                constructor = True,
                access = PUBLIC,
                name = name,
                args = ast.ArgDecl(
                    name = 'parent',
                    ty = self.iprovides_register_collection.type
                ),
                body = reduce(add_field_impl, register.fields,
                    ast.Call(
                        'DefineRegister',
                        ast.Arg(ast.IntLit(register.absolute_address, fmt='h')),
                        ast.Arg(ast.IntLit(self.scanned.resets[register.type_name], fmt='h')),
                        ast.Arg(ast.BoolLit(True)),
                        object = ast.HardCode('parent.RegistersCollection'),
                        ret_ty=self.ty_register
                    )
                ).into_stmt()
            )
        ]

        return ast.Class(
            name = name,
            access = PUBLIC,
            fields = ast.Node.join(map(make_var_decl, register.fields)),
            methods = ast.Node.join(methods),
            struct = True
        )

    @staticmethod
    def add_indents(text: str, base_indent: int) -> str:
        text = str(text)

        def add_indent(line):
            if line.strip() == '':
                return ''
            return '    ' * base_indent + line

        match text.splitlines():
            case [head, *tail]:
                indented = '\n'.join(add_indent(line) for line in tail)
                return head + '\n' + indented
            case _: return text

class CSharpExporter:
    def export(self, node: Union[RootNode, AddrmapNode], path: str,
               name: str, namespace: str, all_public: bool):
        top_node = node.top if isinstance(node, RootNode) else node

        scanned = RdlDesignScanner(top_node).run()
        csharp = CSharpGenerator(
            scanned = scanned,
            name = name,
            namespace = namespace,
            make_all_public = all_public
        ).generate_code()

        with open(path, 'w') as f:
            f.write(csharp)
