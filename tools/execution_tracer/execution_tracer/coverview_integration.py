#
# Copyright (c) 2010-2025 Antmicro
#
# This file is licensed under the MIT License.
# Full license text is available in 'licenses/MIT.txt'.
#

import os
import zipfile
import tempfile
import json
from typing import Iterable, List, TextIO, IO
from datetime import datetime

def create_coverview_archive(path: TextIO, report: Iterable[str], code_files: List[IO], coverview_dict: str) -> bool:
    merge_config = {}
    success = True
    if coverview_dict is not None:
        try:
            merge_config = json.loads(coverview_dict)
        except json.decoder.JSONDecodeError as e:
            print('Malformed config JSON, will use default one:', e)
            # Delay the failure and let the archive be generated with default contents
            # so the time isn't wasted otherwise; the user can edit the JSON manually
            success = False

    if os.path.splitext(path.name)[1] != '.zip':
        print('Ensure that the file will have ".zip" extension. Coverview might not handle the file properly otherwise!')

    with zipfile.ZipFile(path.name, 'w') as archive:
        # In case of very large coverage files it might be better to create a temporary file instead of in-memory string
        archive.writestr('coverage.info', '\n'.join(line for line in report))
        config_file = {
            "datasets": {
                "application": {
                    "line": "coverage.info",
                }
            },
            "title": "Coverage dashboard",
            "commit": "",
            "branch": "",
            "repo": "",
            "timestamp": "",
            "additional": {
                "report_timestamp": str(datetime.now()),
            }
        }
        # "merge_config" will replace values from "config_file"
        config_file = {**config_file, **merge_config}
        archive.writestr('config.json', json.dumps(config_file))

        with tempfile.TemporaryDirectory() as tmp_dir_name:
            with open(os.path.join(tmp_dir_name, 'sources.txt'), 'w') as sources:
                for code_file in code_files:
                    # Remember to revert the pointer, as we might have read the file already before
                    code_file.seek(0)
                    sources.write(f'### FILE: {code_file.name}\n')
                    sources.write(code_file.read())
            archive.write(sources.name, arcname='sources.txt')
    
        print('Created archive:', archive.filename)

        return success
