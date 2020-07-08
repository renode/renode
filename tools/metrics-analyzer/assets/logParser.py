from struct import *

class BaseEntry(Struct):
    def __init__(self, format):
        super(BaseEntry, self).__init__(format)
        self.realTime = 0
        self.virtualTime = 0
        self.entryType = -1


def parseInstructions(filePath):
    with open(filePath, "rb") as f:
        cpus, _ = _parseHeader(f)
        return cpus, _parse(f, b'\x00', '<cQ')


def parseMemory(filePath):
    with open(filePath, "rb") as f:
        _, _ = _parseHeader(f)
        return _parse(f, b'\x01', 'c')


def parsePeripherals(filePath):
    with open(filePath, "rb") as f:
        _, peripherals = _parseHeader(f)
        return peripherals, _parse(f, b'\x02', '<cQ')


def parseExceptions(filePath):
    with open(filePath, "rb") as f:
        _, _ = _parseHeader(f)
        return _parse(f, b'\x03', 'Q')


def _parse(f, entryType, format):
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
            for data in _read(format, f):
                result.append(data)
            entries.append(result)
        else:
            _ignore(entry.entryType, f)
    return entries
    
                
def _parseHeader(f):
    cpus = {}
    peripherals = {}
    numberOfCpus = _read('i', f)[0]
    for x in range(numberOfCpus):
        cpuNameLength = _read('i', f)[0]
        cpus[x] = _read('{}s'.format(cpuNameLength), f)[0].decode()
    numberOfPeripherals = _read('i', f)[0]
    for x in range(numberOfPeripherals):
        peripheralNameLength = _read('i', f)[0]
        peripheralName = _read('{}s'.format(peripheralNameLength), f)[0].decode()
        peripheralStartAddress, peripheralEndAddress = _read('2Q', f)
        peripherals[peripheralName] = [peripheralStartAddress, peripheralEndAddress]
    return cpus, peripherals


def _ignore(entryType, f):
    if entryType == b'\x00':
        _read('<cQ', f)
    if entryType == b'\x01':
        _read('c', f)
    if entryType == b'\x02':
        _read('<cQ', f)
    if entryType == b'\x03':
        _read('<Q', f)


def _read(format, file):
    return unpack(format, file.read(calcsize(format)))
