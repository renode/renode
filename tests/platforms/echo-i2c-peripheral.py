class EchoI2CPeripheral:
    def __init__(self, dummy):
        self.passed = True
        self.dummy = dummy
        self.last_written = '""'

        self.commands = {
            1: self.echo_write,
            2: self.echo_read,
            3: self.record_test_result,
            4: self.finalize_tests
        }

    def write(self, data):
        if len(data) < 1:
            self.dummy.Log(LogLevel.Warning, "No data received")

        cmd, payload = data[0], data[1:]
        if cmd in self.commands:
            self.commands[cmd](payload)
        else:
            self.unknown_command(cmd)

    def unknown_command(self, command):
        self.dummy.Log(LogLevel.Warning, "Unknown command: {0}", command)

    def echo_write(self, data):
        self.dummy.EnqueueResponseBytes(data)
        self.last_written = '"{}"'.format(''.join(map(chr, data)))

    def echo_read(self, data):
        pass

    def record_test_result(self, data):
        if len(data) != 1:
            self.dummy.Log(LogLevel.Warning, "Expected 1 byte of data for command 3")
            return

        passed = data[0] == 0
        self.passed = self.passed and passed

        self.dummy.Log(LogLevel.Info, "Test {0} with message {1}", self.get_result_string(), self.last_written)

    def finalize_tests(self, data):
        self.dummy.Log(LogLevel.Info, "Test suite {0}", self.get_result_string())
        self.dummy.EnqueueResponseByte(int(self.passed))
        self.passed = True

    def get_result_string(self):
        return "passed" if self.passed else "failed"

def mc_setup_echo_i2c_peripheral(path):
    dummy = monitor.Machine[path]
    dummy.DataReceived += EchoI2CPeripheral(dummy).write
