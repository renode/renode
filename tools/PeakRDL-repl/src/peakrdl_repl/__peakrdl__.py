from typing import TYPE_CHECKING

from peakrdl.plugins.exporter import ExporterSubcommandPlugin

from . import repl_exporter

if TYPE_CHECKING:
    import argparse
    from systemrdl.node import AddrmapNode


class ReplExporterDescriptor(ExporterSubcommandPlugin):
    short_desc = (
        "Generate a Renode REPL file with platform description of the address map"
    )

    def do_export(self, top_node: "AddrmapNode", options: "argparse.Namespace") -> None:
        x = repl_exporter.REPLExporter()
        x.export(
            top_node,
            options.output,
        )
