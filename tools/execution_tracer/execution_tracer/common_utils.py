#
# Copyright (c) 2010-2025 Antmicro
#
# This file is licensed under the MIT License.
# Full license text is available in 'licenses/MIT.txt'.
#

import functools
import os
from typing import Iterable, Optional, IO
from dataclasses import dataclass

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

@dataclass(frozen=True)
class PathSubstitution:
    before: str
    after: str

    def apply(self, path: str) -> str:
        return path.replace(self.before, self.after)

    @classmethod
    def from_arg(cls, s: str):
        args = s.split(':')
        if len(args) != 2:
            raise ValueError('Path substitution should be in old_path:new_path format')
        return cls(*args)

def apply_path_substitutions(code_filename: str, substitute_paths: Iterable[PathSubstitution]) -> str:
    return functools.reduce(lambda p, sub: sub.apply(p), substitute_paths, code_filename)
