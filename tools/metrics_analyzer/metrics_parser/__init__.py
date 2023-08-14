#
# Copyright (c) 2010-2023 Antmicro
#
# This file is licensed under the MIT License.
# Full license text is available in 'licenses/MIT.txt'.
#

from struct import *


class BaseEntry(Struct):
    def __init__(self, format):
        super(BaseEntry, self).__init__(format)
        self.realTime = 0
        self.virtualTime = 0
        self.entryType = -1

class MetricsParser:
    def __init__(self, filePath):
        self.filePath = filePath

    def get_instructions_entries(self):
        with open(self.filePath, "rb") as f:
            cpus, _, _ = self._parseHeader(f)
            return cpus, self._parse(f, b'\x00', '<cQ')

    def get_memory_entries(self):
        with open(self.filePath, "rb") as f:
            _, _, _ = self._parseHeader(f)
            return self._parse(f, b'\x01', 'c')

    def get_peripheral_entries(self):
        with open(self.filePath, "rb") as f:
            _, peripherals, _ = self._parseHeader(f)
            return peripherals, self._parse(f, b'\x02', '<cQ')

    def get_exceptions_entries(self):
        with open(self.filePath, "rb") as f:
            _, _, _ = self._parseHeader(f)
            return self._parse(f, b'\x03', 'Q')

    def get_wfi_start_entries(self):
        with open(self.filePath, "rb") as f:
            _, _, _ = self._parseHeader(f)
            return self._parse(f, b'\x04', '')

    def get_wfi_end_entries(self):
        with open(self.filePath, "rb") as f:
            _, _, _ = self._parseHeader(f)
            return self._parse(f, b'\x05', '')

    def get_EOS_entries(self):
        with open(self.filePath, "rb") as f:
            _, _, _ = self._parseHeader(f)
            return self._parse(f, b'\x06', '')

    def get_bits_entries(self):
        with open(self.filePath, "rb") as f:
            _, _, bits = self._parseHeader(f)
            return bits, self._parse(f, b'\x07', '<II')

    def _parse(self, f, entryType, format):
        startTime = 0
        entries = []
        entry = BaseEntry('<qdc')
        while True:
            entryHeader = f.read(entry.size)
            if not entryHeader:
                break
            realTime, entry.virtualTime, entry.entryType = entry.unpack(entryHeader)
            if startTime == 0:
                startTime = realTime
            entry.realTime = (realTime - startTime) / 10000
            if entry.entryType == entryType:
                result = [entry.realTime, entry.virtualTime]
                d = self._read(format, f)
                for data in d:
                    result.append(data)
                entries.append(result)
            else:
                self._ignore(entry.entryType, f)
        return entries

    def _parseHeader(self, f):
        cpus = {}
        peripherals = {}
        bits = {}
        numberOfCpus = self._read('i', f)[0]
        for x in range(numberOfCpus):
            cpuId = self._read('i', f)[0]
            cpuNameLength = self._read('i', f)[0]
            cpus[cpuId] = self._read('{}s'.format(cpuNameLength), f)[0].decode()
        numberOfPeripherals = self._read('i', f)[0]
        for x in range(numberOfPeripherals):
            peripheralNameLength = self._read('i', f)[0]
            peripheralName = self._read('{}s'.format(peripheralNameLength), f)[0].decode()
            peripheralStartAddress, peripheralEndAddress = self._read('2Q', f)
            peripherals[peripheralName] = [peripheralStartAddress, peripheralEndAddress]
        numberOfBits = self._read('i',f)[0]
        for x in range(numberOfBits):
            bitNameLength = self._read('i', f)[0]
            bits[x] = self._read('{}s'.format(bitNameLength), f)[0].decode()
        return cpus, peripherals, bits

    def _ignore(self, entryType, f):
        if entryType == b'\x00':
            self._read('<cQ', f)
        if entryType == b'\x01':
            self._read('c', f)
        if entryType == b'\x02':
            self._read('<cQ', f)
        if entryType == b'\x03':
            self._read('<Q', f)
        if entryType == b'\x04':
            self._read('', f)
        if entryType == b'\x05':
            self._read('', f)
        if entryType == b'\x06':
            self._read('', f)
        if entryType == b'\x07':
            self._read('<II', f)

    def _read(self, format, file):
        return unpack(format, file.read(calcsize(format)))
