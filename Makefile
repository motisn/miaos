# target: dependencies
#	system commands to make the target
# %		; Wild card
# $@	; Target
# $<	; 1st dependency
# $^	; All dependency

### Project name (also used for output file name)
PROJECT	= miaos

all: $(PROJECT).vfd

# Create VFD file from BIN file
%.vfd: ipl.bin miaos.bin
	cp $< $@
	dd if=miaos.bin of=$@ oflag=append conv=notrunc
	dd if=/dev/null of=$@ bs=1 seek=1474560

# Assemble: create BIN file from ASM file
%.bin: %.asm #$(IPLSRC)
	nasm $< -f bin -o $@

# Target: clean project
clean:
	rm -f -r *.bin $(PROJECT).vfd
