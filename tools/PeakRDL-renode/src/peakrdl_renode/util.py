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
from functools import reduce
from itertools import chain

def split_list(it: Iterable[str], sep: str) -> Iterable[str]:
    # Splits elements of an iterable and flattens them
    return chain(*map(lambda s: s.split(sep), it))

def PascalCase(s: str):
    def pascalize_split(s: str, *separators: str) -> str:
        splitted = reduce(split_list, separators, [s])
        return reduce(lambda a, b: a + b, map(str.capitalize, splitted))

    return pascalize_split(s, '_', '-')

def camelCase(s: str):
    pascal = PascalCase(s)
    if len(pascal) == 0:
        return ''
    if len(pascal) == 1:
        return pascal[0].lower()
    return pascal[0].lower() + pascal[1:]
