if request.IsInit:
    lastVal = 0
elif request.IsRead:
    request.Value = lastVal
elif request.IsWrite:
    lastVal = request.Value

self.NoisyLog("%s on REPEATER at 0x%x, value 0x%x" % (str(request.Type), request.Offset, request.Value))
