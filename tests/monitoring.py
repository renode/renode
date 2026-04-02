import sys
import argparse
from collections import deque
from enum import Enum
import threading
from typing import Callable, Optional

import psutil

_IS_MACOS = sys.platform == "darwin"

GREEN = "\033[92m"
RED = "\033[91m"
YELLOW = "\033[93m"
CYAN = "\033[96m"
BOLD = "\033[1m"
RESET = "\033[0m"

PREFIX = "^^^^^"


def add_args(parser: argparse.ArgumentParser):
    monitoring = parser.add_argument_group("Monitoring")

    monitoring.add_argument(
        "--with-system-load-monitoring",
        dest="enable_system_load_monitoring",
        action="store_true",
        default=False,
        help="Enables monitoring of total system load (RAM+CPU utilization), warning if it maxes out.",
    )

    monitoring.add_argument(
        "--system-load-sample-interval",
        dest="system_load_sample_interval_seconds",
        default=1,
        type=int,
        help="How often (in seconds) to sample system load.",
    )

    monitoring.add_argument(
        "--system-load-spike-factor",
        dest="system_load_spike_factor",
        default=10.0,
        type=float,
        help="How big of a multiplicative change in system load has to occur for it to be logged.",
    )

    monitoring.add_argument(
        "--system-load-window-size",
        dest="system_load_window_size",
        default=10,
        type=int,
        help="How many samples to track in the rolling window.",
    )

    monitoring.add_argument(
        "--system-load-ram-warn-threshold",
        dest="ram_warn_threshold_percentage",
        default=95,
        type=int,
        help="How much RAM usage (in percent) to warn at.",
    )

    monitoring.add_argument(
        "--system-load-cpu-warn-threshold",
        dest="cpu_warn_threshold_percentage",
        default=95,
        type=int,
        help="How much CPU usage (in percent) to warn at.",
    )


class ContextSwitches(Enum):
    RISING = 0
    FALLING = 1
    STABLE = 2


class SystemLoadMonitor(threading.Thread):
    def __init__(
        self,
        interval_seconds: float,
        load_spike_factor: float,
        window_size: int,
        ram_warn_threshold_percentage: int,
        cpu_warn_threshold_percentage: int,
        on_overload_detected: Callable[[], None],
    ) -> None:
        super().__init__(daemon=True, name="SystemLoadMonitor")
        self.interval_seconds: float = interval_seconds
        self.load_spike_factor: float = load_spike_factor
        self.context_switch_window: deque[int] = deque(maxlen=window_size)
        self.window_size: int = window_size
        self.ram_warn_threshold: float = ram_warn_threshold_percentage / 100
        self.cpu_warn_threshold: float = cpu_warn_threshold_percentage / 100
        self.on_overload_detected: Callable[[], None] = on_overload_detected

        self.stop_event: threading.Event = threading.Event()

        self.total_ram: Optional[int] = None
        self.available_ram: Optional[int] = None
        self.total_cpu_utilization: Optional[float] = None
        self.previous_context_switches_count: Optional[int] = None
        self.recent_context_switch_change_factor: Optional[float] = None
        self.earlier_context_switch_average: Optional[float] = None
        self.recent_context_switch_average: Optional[float] = None
        self.is_context_switch_warning_active: bool = False

        self.ram_warning_count: int = 0
        self.cpu_warning_count: int = 0
        self.context_switch_warning_count: int = 0

        self.previous_cpu_overloaded: bool = False
        self.previous_ram_overloaded: bool = False
        self.previous_context_switches: ContextSwitches = ContextSwitches.STABLE

        # From docs: "the first time this function is called with
        #             [..] None it will return a meaningless 0.0 value
        #             which you are supposed to ignore."
        psutil.cpu_percent(interval=None)

    def run(self):
        print(f"Starting system load monitor", flush=True)

        # Take one initial sample
        self.sample()

        while not self.stop_event.is_set():
            # Wait for interval, but wake up immediately if stop_event is set.
            if self.stop_event.wait(self.interval_seconds):
                break

            self.sample()

            self.check_and_print_status()

    def stop(self):
        print(f"Stopping system load monitor", flush=True)
        self.stop_event.set()
        if self.is_alive():
            self.join()

        any_warnings_logged = (
            self.ram_warning_count > 0
            or self.cpu_warning_count > 0
            or self.context_switch_warning_count > 0
        )
        if not any_warnings_logged:
            print(f"{GREEN}No system resource warnings logged{RESET}", flush=True)
            return

        print(
            f"\n{BOLD}System resource warnings logged during execution (search for `{PREFIX}`):{RESET}",
            flush=True,
        )

        context_switch_spike_label = "Context switching spikes"  # The longest label

        def print_count(label: str, threshold: str, count: int) -> None:
            label_width = len(context_switch_spike_label)
            # Reasonable max width assumptions (fine if it goes above, just won't be aligned)
            threshold_width = len("10.00x")
            count_width = len("100")
            print(
                f"  {YELLOW}{label:>{label_width}}{RESET} "
                f"> {CYAN}{threshold:>{threshold_width}}{RESET}: "
                f"{BOLD}{RED}{count:>{count_width}}{RESET} times",
                flush=True,
            )

        if self.cpu_warning_count > 0:
            threshold_percent = self.cpu_warn_threshold * 100
            print_count(
                "CPU usage",
                f"{threshold_percent:.1f}%",
                self.cpu_warning_count,
            )

        if self.ram_warning_count > 0:
            threshold_percent = self.ram_warn_threshold * 100
            print_count(
                "RAM usage",
                f"{threshold_percent:.1f}%",
                self.ram_warning_count,
            )

        if self.context_switch_warning_count > 0:
            print_count(
                context_switch_spike_label,
                f"{self.load_spike_factor:.2f}x",
                self.context_switch_warning_count,
            )

        print("", flush=True)

    def check_and_print_status(self):
        any_warning_logged = any(
            [
                self.log_context_switches_overload(),
                self.log_ram_overload(),
                self.log_cpu_overload(),
            ]
        )

        if any_warning_logged:
            self.on_overload_detected()

    def log_context_switches_overload(self) -> bool:
        context_switches = self.check_context_switches()
        warning_logged = False

        context_switches_changed = context_switches != self.previous_context_switches

        if context_switches_changed:
            info = self.format_context_switch_info(context_switches)

            if context_switches == ContextSwitches.RISING:
                self.context_switch_warning_count += 1
                self.is_context_switch_warning_active = True
                print("", flush=True)
                self.print_warning("High CPU context switching detected.", info)
                warning_logged = True
                # Skip newline, as `on_overload_detected` may print here

            if (
                context_switches == ContextSwitches.FALLING
                and self.is_context_switch_warning_active
            ):
                self.is_context_switch_warning_active = False
                print("", flush=True)
                self.print_recovery("CPU context switching normalized.", info)
                print("", flush=True)

        self.previous_context_switches = context_switches
        return warning_logged

    def format_context_switch_info(self, context_switches: ContextSwitches) -> str:
        if self.recent_context_switch_change_factor is None:
            return ""

        if context_switches == ContextSwitches.RISING:
            trend, direction = "increased", ">"
        elif context_switches == ContextSwitches.FALLING:
            trend, direction = "decreased", "<="
        elif context_switches == ContextSwitches.STABLE:
            return ""

        # Add thousands separator.
        earlier = f"{self.earlier_context_switch_average:_.0f}".replace("_", " ")
        recent = f"{self.recent_context_switch_average:_.0f}".replace("_", " ")

        return (
            f"{CYAN}Average switch/s {trend} "
            f"from {earlier} to {BOLD}{recent}"
            f"{RESET}{CYAN} ({BOLD}{self.recent_context_switch_change_factor:.2f}x{RESET}{CYAN} "
            f"{direction} {self.load_spike_factor:.2f}x){RESET}"
        )

    def log_ram_overload(self) -> bool:
        ram_overloaded = self.is_ram_overloaded()
        info = self.format_ram_info(ram_overloaded)

        if ram_overloaded != self.previous_ram_overloaded:
            warning_logged = self.report_transition(
                is_bad=ram_overloaded,
                warning_msg="RAM usage is high.",
                recovery_msg="RAM usage is no longer high.",
                info=info,
                counter_name="ram_warning_count",
            )
        else:
            warning_logged = False

        self.previous_ram_overloaded = ram_overloaded
        return warning_logged

    def format_ram_info(self, is_overloaded: bool) -> str:
        if self.available_ram is None or self.total_ram is None:
            return ""

        used_ram = self.total_ram - self.available_ram
        used_percent = (used_ram / self.total_ram) * 100
        threshold_percent = self.ram_warn_threshold * 100
        bytes_per_gibibytes = 1024**3
        used_gib = used_ram / bytes_per_gibibytes
        total_gib = self.total_ram / bytes_per_gibibytes
        direction = ">" if is_overloaded else "<="
        return (
            f"{CYAN}{BOLD}Used: {used_gib:.2f} GiB{RESET}{CYAN} / {total_gib:.2f} GiB "
            f"({BOLD}{used_percent:.1f}%{RESET}{CYAN} {direction} {threshold_percent:.1f}%){RESET}"
        )

    def log_cpu_overload(self) -> bool:
        cpu_overloaded = self.is_cpu_overloaded()
        info = self.format_cpu_info(cpu_overloaded)

        if cpu_overloaded != self.previous_cpu_overloaded:
            warning_logged = self.report_transition(
                is_bad=cpu_overloaded,
                warning_msg="CPU usage is high.",
                recovery_msg="CPU usage is no longer high.",
                info=info,
                counter_name="cpu_warning_count",
            )
        else:
            warning_logged = False

        self.previous_cpu_overloaded = cpu_overloaded
        return warning_logged

    def format_cpu_info(self, is_overloaded: bool) -> str:
        if self.total_cpu_utilization is None:
            return ""

        threshold_percent = self.cpu_warn_threshold * 100
        utilization_percent = self.total_cpu_utilization * 100
        direction = ">" if is_overloaded else "<="
        return f"{CYAN}{BOLD}Load: {utilization_percent:.1f}%{RESET}{CYAN} {direction} {threshold_percent:.1f}%{RESET}"

    def report_transition(
        self,
        is_bad: bool,
        warning_msg: str,
        recovery_msg: str,
        info: str = "",
        counter_name: Optional[str] = None,
    ) -> bool:
        print("", flush=True)
        if is_bad:
            self.print_warning(warning_msg, info)

            if counter_name:
                counter = getattr(self, counter_name)
                setattr(self, counter_name, counter + 1)

            return True

        self.print_recovery(recovery_msg, info)
        print("", flush=True)
        return False

    def print_warning(self, message: str, extra_info: str):
        print(f"{YELLOW}{PREFIX} WARNING: {message}{RESET} {extra_info}", flush=True)

    def print_recovery(self, message: str, extra_info: str):
        print(f"{GREEN}{PREFIX} {message}{RESET} {extra_info}", flush=True)

    def is_ram_overloaded(self) -> bool:
        if self.total_ram is None or self.available_ram is None:
            return False

        used_ram = self.total_ram - self.available_ram
        used_ram_fraction = used_ram / self.total_ram

        return used_ram_fraction > self.ram_warn_threshold

    def is_cpu_overloaded(self) -> bool:
        if self.total_cpu_utilization is None:
            return False

        return self.total_cpu_utilization > self.cpu_warn_threshold

    def check_context_switches(self) -> ContextSwitches:
        """Checks if the number of context switches change sharply in a given window."""
        window = self.context_switch_window
        if len(window) < self.window_size:
            # Not enough samples
            return ContextSwitches.STABLE

        middle_index = len(window) // 2
        samples = list(window)
        old_samples = samples[:middle_index]
        recent_samples = samples[middle_index:]

        self.earlier_context_switch_average = sum(old_samples) / len(old_samples)
        self.recent_context_switch_average = sum(recent_samples) / len(recent_samples)

        # Avoid division by zero
        if (
            self.earlier_context_switch_average == 0
            or self.recent_context_switch_average == 0
        ):
            return ContextSwitches.STABLE

        self.recent_context_switch_change_factor = (
            self.recent_context_switch_average / self.earlier_context_switch_average
        )
        earlier_change_factor = (
            self.earlier_context_switch_average / self.recent_context_switch_average
        )

        if self.recent_context_switch_change_factor > self.load_spike_factor:
            return ContextSwitches.RISING

        if earlier_change_factor > self.load_spike_factor:
            return ContextSwitches.FALLING

        return ContextSwitches.STABLE

    def sample(self):
        self.sample_memory()
        self.sample_cpu()

    def sample_memory(self):
        ram = psutil.virtual_memory()
        self.total_ram = ram.total
        self.available_ram = ram.available

    def sample_cpu(self):
        self.total_cpu_utilization = psutil.cpu_percent(interval=None) / 100
        self.sample_context_switches()

    def sample_context_switches(self):

        if _IS_MACOS:
            # psutil.cpu_stats().ctx_switches is broken on macOS.
            # It reports VM page counts, not context switches.
            # Return 0 to disable the context switch detection (it'll never detect any changes).
            # See https://github.com/giampaolo/psutil/issues/847
            context_switches = 0
        else:
            context_switches = psutil.cpu_stats().ctx_switches

        if self.previous_context_switches_count:
            delta = context_switches - self.previous_context_switches_count
            self.context_switch_window.append(delta)
        self.previous_context_switches_count = context_switches
