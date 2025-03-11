if request.isInit:
    baseValue = 0
elif request.isRead:
    request.value = baseValue
else:
    x = request.value & 0xffff
    baseValue = (x << 16) | x
