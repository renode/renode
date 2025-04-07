if request.IsInit:
    baseValue = 0
elif request.IsRead:
    request.Value = baseValue
else:
    x = request.Value & 0xffff
    baseValue = (x << 16) | x
