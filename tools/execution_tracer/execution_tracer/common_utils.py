#
# Copyright (c) 2010-2025 Antmicro
#
# This file is licensed under the MIT License.
# Full license text is available in 'licenses/MIT.txt'.
#

import os
from typing import Iterable, Optional, IO

def extract_common_prefix(files: Iterable[IO]) -> str:
    try:
        return os.path.commonpath(code_file.name for code_file in files) + os.path.sep
    except ValueError:
        # Mixing relative and absolute paths throws ValueError
        return ''

def remove_prefix(text: str, prefix: Optional[str]):
    if not prefix:
        return text
    return text[text.startswith(prefix) and len(prefix):]
