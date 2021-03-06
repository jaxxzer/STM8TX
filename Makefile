BUILD_DATE_YEAR=$(shell date +%Y)
BUILD_DATE_MONTH=$(shell date +%m | sed 's/^0//g')
BUILD_DATE_DAY=$(shell date +%d | sed 's/^0//g')

BL_VERSION=2

CC=sdcc
CODELOC=0x8700
CFLAGS=-mstm8 -Iinclude -DSTM8S105=1 --opt-code-size -DCODELOC=$(CODELOC) -DBLBASE=$(BLBASE) -DBL_VERSION=$(BL_VERSION)
CFLAGS+= -DBUILD_DATE_YEAR=$(BUILD_DATE_YEAR) -DBUILD_DATE_MONTH=$(BUILD_DATE_MONTH) -DBUILD_DATE_DAY=$(BUILD_DATE_DAY)
BLBASE=0x8100
LD=sdld
CHIP=stm8s105c6
#STLINK=stlink
STLINK=stlinkv2

LIBSRC=lib/util.c lib/gpio.c lib/uart.c lib/printfl.c lib/adc.c lib/spi.c lib/cypress.c
LIBSRC += lib/timer.c lib/eeprom.c lib/buzzer.c lib/crc.c lib/channels.c
BL_LIBSRC=lib/gpio.c lib/crc.c lib/eeprom.c

RELOBJ = $(LIBSRC:%.c=%.rel)
BL_RELOBJ = $(BL_LIBSRC:%.c=%.rel)

all: combined.ihx txmain.img

txmain: txmain.ihx

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
	@echo Building binary $* at $(CODELOC)
	@$(CC) $(CFLAGS) --code-loc $(CODELOC) -o $*.ihx --out-fmt-ihx $^

bootloader.ihx: bootloader/main.c $(BL_RELOBJ)
	@echo Building bootloader binary $* at $(BLBASE)
	@$(CC) $(CFLAGS) -o bootloader.ihx --code-loc $(BLBASE) --out-fmt-ihx $^

blimage: bootloader/blimage.c lib/crc.c
	@echo Building blimage
	gcc -Wall -o blimage -Iinclude bootloader/blimage.c lib/crc.c

clean:
	@echo Cleaning
	@rm -f $(OBJ) $(HEX) *.map *.asm *.lst *.rst *.sym *.lk *.cdb *.ihx *.rel */*.rel *.img *.bin

txmain.flash: txmain.ihx
	@echo Flashing $^ to $(STLINK)
	@stm8flash -c$(STLINK) -p$(CHIP) -s $(CODELOC) -w $^

txmain.img: txmain.ihx blimage
	@echo Creating txmain.bin
	@hex2bin.py --size=14592 txmain.ihx txmain.bin
	@echo Creating txmain.img
	@./blimage

txmain.flash2: txmain.img
	@echo Flashing copy of $^ to $(STLINK) at 0xC000
	@stm8flash -c$(STLINK) -p$(CHIP) -s 0xC000 -w txmain.img -b 16384

zero.flash2: txmain.img
	@echo Flashing zeros to $(STLINK) at 0xC000
	@stm8flash -c$(STLINK) -p$(CHIP) -s 0xC000 -w /dev/zero -b 16384

pintest.flash: pintest.ihx
	@echo Flashing $^ to $(STLINK)
	@stm8flash -c$(STLINK) -p$(CHIP) -s $(CODELOC) -w $^

bootloader.flash: bootloader.ihx
	@echo Flashing bootloader to $(STLINK)
	@stm8flash -c$(STLINK) -p$(CHIP) -w $^

combined.ihx: txmain.ihx bootloader.ihx
	@echo Building combined.ihx
	@hex2bin.py bootloader.ihx bootloader.bin1
	@hex2bin.py --size=1792 bootloader.ihx bootloader.bin
	@hex2bin.py --size=14592 txmain.ihx txmain.bin
	@cat bootloader.bin txmain.bin txmain.bin > combined.bin
	@bin2hex.py --offset 0x8000 combined.bin combined.ihx

combined.flash: combined.ihx
	@echo Flashing combined to $(STLINK)
	@stm8flash -c$(STLINK) -p$(CHIP) -w $^

get.flash:
	@echo Reading flash from $(STLINK) at $(CODELOC)
	@stm8flash -c$(STLINK) -p$(CHIP) -s $(CODELOC) -r flash.img -b 16384

get.flash2:
	@echo Reading flash from $(STLINK) at 0xC000
	@stm8flash -c$(STLINK) -p$(CHIP) -s 0xC000 -r flash2hdr.img -b 6
	@echo Reading flash from $(STLINK) at 0xC006
	@stm8flash -c$(STLINK) -p$(CHIP) -s 0xC006 -r flash2.bin -b 16384
	@echo Reading flash from $(STLINK) at 0xC000
	@stm8flash -c$(STLINK) -p$(CHIP) -s 0xC000 -r flash2.img -b 16384

get.eeprom:
	@echo Reading eeprom from $(STLINK) at 0x4000
	@stm8flash -c$(STLINK) -p$(CHIP) -s 0x4000 -r eeprom.img -b 1024

