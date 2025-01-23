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
from datetime import datetime

def create_coverview_archive(args, report, code_files):
    if os.path.splitext(args.coverage_output.name)[1] != '.zip':
        print('Ensure that the file will have ".zip" extension. Coverview might not handle the file properly otherwise!')
    with zipfile.ZipFile(args.coverage_output.name, 'w') as archive:
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
        archive.writestr('config.json', json.dumps(config_file))
        with tempfile.TemporaryDirectory() as tmp_dir_name:
            with open(os.path.join(tmp_dir_name, 'sources.txt'), 'w') as sources:
                for code_file in code_files:
                    # Remember to revert the pointer, as we might have read the file already before
                    code_file.seek(0)
                    # Fixup in case we don't have a dirname
                    sources.write(f'### FILE: project/{code_file.name}\n')
                    sources.write(code_file.read())
            archive.write(sources.name, arcname='sources.txt')
    
        print('Created archive:', archive.filename)
