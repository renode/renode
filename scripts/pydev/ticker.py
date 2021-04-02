INIT_VALUE = 1
STEP = 2

if request.isInit:
    lastVal = 0
    step = 1
elif request.isUser:
    if request.offset == INIT_VALUE:
        lastVal = request.value
    elif request.offset == STEP:
        step = request.value
else:
    lastVal = lastVal + step
    request.value = lastVal

self.NoisyLog("%s on TICKER at 0x%x, value 0x%x" % (str(request.type), request.offset, request.value))
