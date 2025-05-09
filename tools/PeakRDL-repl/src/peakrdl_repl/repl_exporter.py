from typing import Union, Any

from systemrdl import RDLListener, RDLWalker
from systemrdl.node import Node, RootNode, AddrmapNode, RegNode, FieldNode, RegfileNode, MemNode

from . import repl


def _is_topmost_node(node: Node) -> bool:
    return isinstance(node.parent, RootNode)


def _is_peripheral(node: Node) -> bool:
    return any(
        isinstance(child, RegNode)
        or isinstance(child, RegfileNode)
        or isinstance(child, FieldNode)
        or isinstance(child, MemNode)
        for child in node.children()
    )


class REPLBuilder(RDLListener):
    def __init__(self):
        self.repl = repl.REPL()

    def enter_Addrmap(self, node):
        if _is_topmost_node(node):
            return

        if not _is_peripheral(node):
            return

        regpoints = repl.REPLRegistrationInfo(
            addresses=[node.absolute_address], sizes=[node.size], parent_name="sysbus"
        )
        self.repl.peripheral_entries.append(
            repl.REPLEntry(name=node.inst_name, registration_info=regpoints)
        )


class REPLExporter:
    def export(self, node: Union[RootNode, AddrmapNode], out_path: str) -> None:
        if isinstance(node, RootNode):
            node = node.top

        builder = REPLBuilder()
        walker = RDLWalker(unroll=True).walk(node, builder)

        builder.repl.resolve_conflicting_names()

        with open(out_path, "w", encoding="utf-8") as f:
            f.write(str(builder.repl))
