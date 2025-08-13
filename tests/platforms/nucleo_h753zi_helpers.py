def extract_int_from_bytes(bytes, start, count):
    start = int(start)
    end = start + int(count)
    return int.from_bytes(bytes[start:end], byteorder='big')
