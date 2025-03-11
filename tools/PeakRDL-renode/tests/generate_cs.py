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

from argparse import ArgumentParser
import json
import subprocess
import os

def main():
    parser = ArgumentParser()
    parser.add_argument('json', type=str, help='JSON file with test info')
    args = parser.parse_args()

    with open(args.json, 'r') as json_file:
        test_desc = json.loads(json_file.read())

    for test in test_desc:
        output = test["file"]
        dir = os.path.dirname(output)
        if not os.path.exists(dir):
            print(f"Creating the `{dir}` directory")
            os.makedirs(dir)
        print(f'Generating `{output}`...')
        subprocess.run(test['peakrdl'])

    print('Done!')


if __name__ == '__main__':
    main()
