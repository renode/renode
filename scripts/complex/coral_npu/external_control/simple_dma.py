if request.IsInit:
    source = 0
    destination = 0
    sysbus = self.GetMachine().SystemBus

elif request.IsRead:
    offset = request.Offset // 8

    if offset == 0:
        request.Value = source
    elif offset == 1:
        request.Value = destination
    else:
        request.Value = 0

elif request.IsWrite:
    offset = request.Offset // 8
    value = request.Value

    if offset == 0:
        source = value

    elif offset == 1:
        destination = value

    elif offset == 2:
        data = sysbus.ReadBytes(source, value)
        sysbus.WriteBytes(data, destination)
        self.InfoLog("Copied %d, from 0x%x to 0x%x" % (value, source, destination))
