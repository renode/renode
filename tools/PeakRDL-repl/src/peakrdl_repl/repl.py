from typing import Any
from dataclasses import dataclass, field

INDENT = " " * 4


@dataclass
class REPLRegistrationInfo:
    addresses: list[int]
    sizes: list[int]
    parent_name: str

    def __str__(self):
        if len(self.addresses) == 1:
            return f"@ {self.parent_name} <0x{self.addresses[0]:X}, +0x{self.sizes[0]:X}>"
        else:
            raise NotImplementedError(
                "Multiple registration addresses are not supported yet"
            )


@dataclass
class REPLEntry:
    name: str
    registration_info: REPLRegistrationInfo
    type_name: str = None

    def __str__(self):
        return f"{self.name}:{' ' + self.type_name if self.type_name else ''} {self.registration_info}"


@dataclass
class REPL:
    peripheral_entries: list[REPLEntry] = field(default_factory=list)

    def resolve_conflicting_names(self):
        for entry in self.peripheral_entries:
            conflicting_entries = [
                other_entry
                for other_entry in self.peripheral_entries
                if other_entry.name == entry.name and other_entry != entry
            ]
            if conflicting_entries:
                for i, conflicting_entry in enumerate(conflicting_entries):
                    conflicting_entry.name += str(i + 1)
                entry.name += "0"

    def __str__(self):
        return "".join(f"{entry}\n" for entry in self.peripheral_entries)
