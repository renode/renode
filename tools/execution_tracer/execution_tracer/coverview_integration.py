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
from typing import TextIO
from datetime import datetime
from execution_tracer.common_utils import extract_common_prefix, remove_prefix
from execution_tracer.dwarf import Coverage

def create_coverview_archive(path: TextIO, coverage_config: Coverage, coverview_dict: str, *, tests_as_total: bool, warning_threshold: str, remove_common_path_prefix: bool = False) -> bool:
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
        info_filename = 'coverage.info'
        desc_filename = 'coverage.desc'
        archive.writestr(
            info_filename,
            '\n'.join(line for line in coverage_config.get_lcov_printed_report(remove_common_path_prefix=remove_common_path_prefix))
        )
        archive.writestr(
            desc_filename,
            '\n'.join(line for line in coverage_config.get_desc_printed_report(remove_common_path_prefix=remove_common_path_prefix))
        )

        config_file = {
            "datasets": {
                "application": {
                    "line": [info_filename, desc_filename]
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
        if tests_as_total:
            config_file["tests_as_total"] = "true"
        if warning_threshold:
            config_file["warning_threshold"] = warning_threshold
        archive.writestr('config.json', json.dumps(config_file))

        with tempfile.TemporaryDirectory() as tmp_dir_name:
            with open(os.path.join(tmp_dir_name, 'sources.txt'), 'w') as sources:
                code_files = coverage_config._code_files
                common_prefix = extract_common_prefix(code_files) if remove_common_path_prefix else None
                for code_file in code_files:
                    # Remember to revert the pointer, as we might have read the file already before
                    code_file.seek(0)
                    sources.write(f'\n### FILE: {remove_prefix(code_file.name, common_prefix)}\n')
                    sources.write(code_file.read())
            archive.write(sources.name, arcname='sources.txt')

        print('Created archive:', archive.filename)

        return success
