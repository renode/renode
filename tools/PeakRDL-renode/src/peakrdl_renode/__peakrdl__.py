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

from typing import TYPE_CHECKING

from peakrdl.plugins.exporter import ExporterSubcommandPlugin #pylint: disable=import-error
from peakrdl.config import schema #pylint: disable=import-error

if TYPE_CHECKING:
    import argparse
    from systemrdl.node import AddrmapNode


from . import cs_exporter

class Exporter(ExporterSubcommandPlugin):
    short_desc = 'Renode C# interface exporter'

    def add_exporter_arguments(self, arg_group: 'argparse._ActionsContainer') -> None:
        arg_group.add_argument('-N', '--namespace', help='Peripheral namespace',
                               required=True)
        arg_group.add_argument('-n', '--name', help='Peripheral name')
        arg_group.add_argument('--all-public', help='Make all field public',
                               action='store_true')
        return

    def do_export(self, top_node: 'AddrmapNode', options: 'argparse.Namespace') -> None:
        cs_exporter.CSharpExporter().export(
            top_node,
            path = options.output,
            name = options.name,
            namespace = options.namespace,
            all_public=options.all_public
        )
