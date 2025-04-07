if request.IsInit:
    lastVal = 0
else:
    lastVal = 1 - lastVal
    request.Value = lastVal * 0xFFFFFFFF

self.NoisyLog("%s on FLIPFLOP at 0x%x, value 0x%x" % (str(request.Type), request.Offset, request.Value))
