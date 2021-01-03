MCU 		= attiny2313a
BUILD_DIR 	= build
MAIN      	= binaryclock.asm
TARGETS	  	= $(addprefix $(BUILD_DIR)/, $(SOURCES:.asm=.hex))
SOURCES	  	= $(MAIN) $(TEST)
INCLUDES    = rtc.inc spi.inc utils.inc hc595.inc

.PHONY: build flash_main

$(BUILD_DIR)/%.hex: %.asm $(INCLUDES)
	@mkdir -p $(dir $@)
	@avra -I . -O e 				\
		-D BRIGHTNESS=230 -D TURN_OFF_PWM	\
		-e $(@:.hex=.eep.hex) 			\
		$< -o $@

build: $(TARGETS)
	@echo Done

flash_main: $(addprefix $(BUILD_DIR)/, $(MAIN:.asm=.flash))
	@echo Done

$(BUILD_DIR)/%.flash: $(BUILD_DIR)/%.hex
	@echo "------------------------ ACHTUNG ------------------------"
	@echo "Please switch off SPI interface from the logic analyzer first!!!"
	@echo "                It's ridiculously important"
	@echo "---------------------------------------------------------"
	@read
	
# 0x62 - internal 4 Mhz / 8 = 500kHz
# 0x64 - internal 8 Mhz / 8 = 500kHz
# 0xe6 - internal 128 khz = 128kHz
# 0x66 - internal 128 khz / 8 = 16kHz
# -B 1024 -- to slow down a write

	@avrdude -p t2313 -c usbtiny 			\
		-U flash:w:$(@:.flash=.hex) 		\
		-U eeprom:w:$(@:.flash=.eep.hex) 	\
		-U lfuse:w:0x62:m 					\
		-U hfuse:w:0xDF:m 					\
		-U efuse:w:0xFF:m

# 	slow flash
#	@avrdude -p t2313 -B 1024 -c usbtiny 	\
#		-U flash:w:$(@:.flash=.hex) 		\
#		-U eeprom:w:$(@:.flash=.eep.hex) 	\
#		-U lfuse:w:0xE6:m 					\
#		-U hfuse:w:0xDF:m 					\
#		-U efuse:w:0xFF:m

clean:
	@rm -rf $(BUILD_DIR)
