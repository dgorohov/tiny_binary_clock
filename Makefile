MCU		= attiny2313a
FORMAT 	= ihex
TARGET	= binaryclock

SOURCE	= binaryclock.asm

BUILD_DIR = build

ELF 	= $(BUILD_DIR)/$(TARGET).elf
HEX 	= $(BUILD_DIR)/$(SOURCE).hex
EEP 	= $(BUILD_DIR)/$(TARGET).eep.hex

.PHONY: build avrdude

$(BUILD_DIR)/%.asm.hex: %.asm
	@mkdir -p $(BUILD_DIR)
	@avra -I . \
		-O e \
		-D BRIGHTNESS=230 -D TURN_OFF_PWM \
		-e $(EEP) \
		$< -o $@

$(ELF): $(HEX)
	@avr-objcopy -I ihex -O elf32-avr $< $@

build: clean $(ELF)
	@echo Done


avrdude: build
	@echo "------------------------ ACHTUNG ------------------------"
	@echo "Please switch off SPI interface from the logic analyzer first!!!"
	@echo "                It's ridiculously important"
	@echo "---------------------------------------------------------"
	@read
	
	# 0x62 - internal 4 Mhz / 8 = 500kHz
	# 0x64 - internal 8 Mhz / 8 = 500kHz
	# 0xe6 - internal 128 khz = 128kHz
	# 0x66 - internal 128 khz / 8 = 16kHz

	@avrdude -p t2313 -c usbtiny \
		-U flash:w:$(HEX) \
		-U eeprom:w:$(EEP) \
		-U lfuse:w:0x62:m \
		-U hfuse:w:0xDF:m \
		-U efuse:w:0xFF:m

# 	slow flash
#	avrdude -p t2313 -B 1024 -c usbtiny -U flash:w:$(TARGET).S.hex \
#		-U lfuse:w:0xE6:m -U hfuse:w:0xDF:m -U efuse:w:0xFF:m


clean:
	@rm -rf $(BUILD_DIR)

simulavr: $(ELF)
	@simavr -f 500000 -m attiny2313 --gdb 4242  $<

