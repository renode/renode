INIT_VALUE = 1
STEP = 2

if request.IsInit:
    lastVal = 0
    step = 1
elif request.IsUser:
    if request.Offset == INIT_VALUE:
        lastVal = request.Value
    elif request.Offset == STEP:
        step = request.Value
else:
    lastVal = lastVal + step
    request.Value = lastVal

self.NoisyLog("%s on TICKER at 0x%x, value 0x%x" % (str(request.Type), request.Offset, request.Value))
