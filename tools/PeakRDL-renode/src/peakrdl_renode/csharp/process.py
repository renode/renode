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

from . import ast, operators as op, op_null, op_order
from .helper import Visitor

class MakeAllPublic(Visitor):
    def __init__(self, nodes: ast.Node, verbose: bool = False) -> None:
        super().__init__(nodes, verbose)

    def visit_VariableDecl(self, node: ast.VariableDecl) -> None:
        node.access = ast.AccessibilityMod.PUBLIC

    def visit_InvokableDefinition(self, node: ast.InvokableDefinition) -> None:
        # Hack for ignoring interface and partial methods
        if not (isinstance(node, ast.MethodDefinition) and '.' in node.name) \
                and not node.partial:
            node.access = ast.AccessibilityMod.PUBLIC

    def visit_Class(self, node: ast.Class) -> None:
        node.access = ast.AccessibilityMod.PUBLIC

        self.iterate_children_dfs(node)

def process_ast(root: ast.Node, make_all_public: bool = False) -> ast.Node:
    op_null.EvalNulls(root)
    op_order.OrderOperators(root)

    if make_all_public:
        MakeAllPublic(root, verbose=True)

    return root
