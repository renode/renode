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

from typing import Any, Callable, Iterable
from types import SimpleNamespace
from itertools import chain

from . import ast

class Hole(ast.Node):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

    def tokenize(self, _: ast.CodeGenerator) -> ast.Iterable[str | ast.CodeCC]:
        raise RuntimeError('Incomplete AST - Hole in AST')

class TemplateHole(ast.Node):
    def __init__(self, name: str | None = None, **kwargs) -> None:
        super().__init__(name=name, **kwargs)

    def tokenize(self, _: ast.CodeGenerator) -> ast.Iterable[str | ast.CodeCC]:
        raise RuntimeError('Incomplete AST - template not processed')

class Visitor:
    def __init__(self, nodes: ast.Node, verbose: bool = False) -> None:
        self.visitor_methods: dict[type, Callable[[Any], None]] = {}

        for c in chain([ast.Node], Visitor.m_get_all_subclasses(ast.Node)):
            visitor_name = 'visit_' + c.__name__
            if hasattr(self, visitor_name):
                self.visitor_methods[c] = getattr(self, visitor_name)

        self.verbose = verbose
        self.depth = 0
        if self.verbose:
            print(f'Visitor {type(self)}:')

        self.visit(nodes)

    @staticmethod
    def m_get_all_subclasses(ty: type):
        for c in ty.__subclasses__():
            yield c
            for cc in Visitor.m_get_all_subclasses(c):
                yield cc

    @staticmethod
    def m_iterate_class_hierarchy(ty: type) -> Iterable[type]:
        q = [ty]
        while len(q) != 0:
            t = q.pop(0)
            yield t
            for b in t.__bases__:
                if issubclass(b, ast.Node):
                    q.append(b)


    def iterate_children_dfs(self, node: ast.Node) -> None:
        for child in node.children():
            self.visit(child)

    def visit_Node(self, node: ast.Node) -> None:
        self.iterate_children_dfs(node)

    def visit(self, node: ast.Node) -> None:
        if node.null: return

        if self.verbose:
            print(' ' * (self.depth * 2) + f'* VISIT {type(node)}')

        self.depth += 1

        for c in Visitor.m_iterate_class_hierarchy(type(node)):
            visitor = self.visitor_methods.get(c)
            if visitor is not None:
                visitor(node)
                self.depth -= 1
                return

        self.depth -= 1

        raise RuntimeError(f'No visitor found for type {type(node)}, '
                           f'bases found: {list(Visitor.m_iterate_class_hierarchy(type(node)))}, ',
                           f'visitor keys: {self.visitor_methods.keys()}')

class TemplatedAST(Visitor):
    def __init__(self, nodes: ast.Node, verbose: bool = False) -> None:
        self.obj = SimpleNamespace()
        super().__init__(nodes, verbose)
        setattr(self.obj, 'ast', nodes)

    @property
    def template(self) -> Any:
        return self.obj

    def visit_TemplateHole(self, node: TemplateHole):
        setattr(self.obj, node.name, node)
