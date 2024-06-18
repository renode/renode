from cache import Cache

PRESETS = {
    'fu740.u74': {
        'l1i': Cache('l1i,u74', 15, 6, 64, 4, None),
        'l1d': Cache('l1d,u74', 15, 6, 64, 8, None),
        'flush_opcodes': {
            0xfc100073: 'i',
            0xfc000073: 'd',
        }
    },
    'fe310.e31': {
        'l1i': Cache('l1i,e31', 14, 5, 32, 2, None),
    },
}
