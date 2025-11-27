layout asm
target remote :3333

# Break on the beginning of the program
break *0x80000000

# Break on the `beq t3, t4, ok` test
break *0x80000014

# Break on infinite loop
break *0x8000003a
