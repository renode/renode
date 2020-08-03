if request.isInit:
    lastVal = 0
else:
    if request.offset != 0x8 :
        lastVal = 1 - lastVal
	request.value = lastVal * 0xFFFFFFFF
    else :
	lastVal = 1 - lastVal
	request.value = lastVal * 0xFFFFFFFA

self.NoisyLog("%s on FLIPFLOP at 0x%x, value 0x%x" % (str(request.type), request.offset, request.value))
