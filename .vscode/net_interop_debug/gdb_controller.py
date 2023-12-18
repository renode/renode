import gdb
from gdb_common import *


class StopController:
    is_first_trap = True

    def __init__(self, renode_sources_only=True):
        self.renode_sources_only = renode_sources_only
        gdb.events.stop.connect(self.on_stop)
        gdb.events.new_objfile.connect(self.on_new_object_file)

    def on_stop(self, event):
        is_breakpoint = hasattr(event, "breakpoints")
        stop_signal = getattr(event, "stop_signal", None)

        if (
            self.is_first_trap
            or is_breakpoint
            or stop_signal == "SIGINT"
            or self.is_any_frame_debuggable()
        ):
            self.pass_signal_to_net(False)
            DONT_IGNORE_LATEST_TRAP.send(gdb)
        else:
            self.pass_signal_to_net(True)
            gdb.post_event(lambda: gdb.execute("continue"))

        self.is_first_trap = False

    def on_new_object_file(self, event):
        self.pass_signal_to_net(False)

    def pass_signal_to_net(self, pass_enable):
        if pass_enable:
            print("Enable passing SIGTRAP")
            gdb.execute("handle SIGTRAP pass")
        else:
            print("Disable passing SIGTRAP")
            gdb.execute("handle SIGTRAP nopass")

    def is_any_frame_debuggable(self):
        frame = gdb.newest_frame()
        while frame is not None:
            if self.is_frame_debuggable(frame):
                return True
            frame = frame.newer()
        return False

    def is_frame_debuggable(self, frame):
        if not frame.is_valid():
            return False

        symbol = frame.find_sal()
        if symbol is None or not symbol.is_valid():
            return False

        symbol_table = symbol.symtab
        if symbol_table is None or not symbol_table.is_valid():
            return False

        if self.renode_sources_only:
            return "Antmicro.Renode" in symbol_table.objfile.filename
        else:
            return True


def initialize():
    gdb.set_parameter("confirm", False)
    gdb.execute("handle all pass nostop noprint")
    # For an unknown reason disable printing (noprint) for SIGTRAP causes a segmentation fault.
    gdb.execute("handle SIGTRAP nopass stop print")

    stop_controller = StopController()

if __name__ == "__main__":
    initialize()
