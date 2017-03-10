CC=sdcc
CFLAGS=-mstm8 -Iinclude -DSTM8S105=1 --opt-code-size
LD=sdld
CHIP=stm8s105c6
#STLINK=stlink
STLINK=stlinkv2

LIBSRC=lib/util.c lib/gpio.c lib/uart.c lib/printfl.c lib/adc.c lib/spi.c lib/cypress.c lib/timer.c lib/eeprom.c lib/buzzer.c

RELOBJ = $(LIBSRC:%.c=%.rel)

txtest: txtest.ihx

pintest: pintest.ihx

.PHONY: all clean

.PRECIOUS: lib/%.rel

%.rel: %.c
	@echo Building $^
	@$(CC) -c $(CFLAGS) $^ -o $*.rel

lib/%.rel: lib/%.c
	@echo Building lib source $^
	@$(CC) -c $(CFLAGS) $^ -o lib/$*.rel

%.ihx: %/main.c $(RELOBJ)
	@echo Building binary $*
	@$(CC) $(CFLAGS) -o $*.ihx --out-fmt-ihx $^

all: txtest pintest

clean:
	@echo Cleaning
	@rm -f $(OBJ) $(HEX) *.map *.asm *.lst *.rst *.sym *.lk *.cdb *.ihx *.rel */*.rel

txtest.flash: txtest.ihx
	@echo Flashing $^ to $(STLINK)
	@stm8flash -c$(STLINK) -p$(CHIP) -w $^

pintest.flash: pintest.ihx
	@echo Flashing $^ to $(STLINK)
	@stm8flash -c$(STLINK) -p$(CHIP) -w $^
