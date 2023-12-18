class MessageGDB:
    def __init__(self, message):
        self.message = message

    def send(self, gdb):
        print(self.message)

    def is_valid(self, line):
        return line.startswith(f"~\"{self.message}")


DONT_IGNORE_LATEST_TRAP = MessageGDB("DONT_IGNORE_LATEST_TRAP")
