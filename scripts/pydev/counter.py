if request.IsInit:
    lastVal = -1
elif request.IsRead:
    request.Value = lastVal + 1
    lastVal += 1

self.NoisyLog("%s on COUNTER at 0x%x, value 0x%x" % (str(request.Type), request.Offset, request.Value))
