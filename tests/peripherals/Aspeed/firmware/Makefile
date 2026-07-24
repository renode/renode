# Build minimal AST2600 SPL stub for Renode testing
CROSS  ?= arm-linux-gnueabi-
AS      = $(CROSS)as
LD      = $(CROSS)ld
OBJCOPY = $(CROSS)objcopy

all: ast2600_spl_stub.bin

ast2600_spl_stub.bin: ast2600_spl_stub.elf
	$(OBJCOPY) -O binary $< $@

ast2600_spl_stub.elf: ast2600_spl_stub.o
	$(LD) -Ttext=0 -o $@ $<

ast2600_spl_stub.o: ast2600_spl_stub.S
	$(AS) -march=armv7-a -o $@ $<

clean:
	rm -f *.o *.elf *.bin

.PHONY: all clean
