.equ SCK 	= PB7
.equ MISO 	= PB6
.equ MOSI 	= PB5

.equ SPI_PORT 		= PORTB
.equ SPI_PIN 		= PINB
.equ SPI_PORT_DIR 	= DDRB

spi_init:
	in tmp, SPI_PORT_DIR
	in tmp_b, SPI_PORT_DIR
	andi tmp_b, ~(1 << MISO)
	ori tmp, (1 << SCK) | (1 << MOSI)
	or tmp, tmp_b
	out SPI_PORT_DIR, tmp

	in tmp, SPI_PORT
	in tmp_b, SPI_PORT
	andi tmp_b, ~(1 << SCK) & ~(1 << MISO)
	ori tmp, (1 << MOSI)
	or tmp, tmp_b
	out	SPI_PORT, tmp
	ret

; +++++++++++++++++++++++++++
; data - r24
; size - r25
spi_write_byte:
	ldi r25, 0x8
spi_write:
	lsl r24
	brcc mosi_low
	sbi SPI_PORT, MOSI
	rjmp mosi_done
mosi_low:
	cbi SPI_PORT, MOSI
mosi_done:
	; input data is sampled on the rising edge of SCL
	sbi SPI_PORT, SCK
	nop
	cbi SPI_PORT, SCK
	dec r25
	brne spi_write
	ret

; +++++++++++++++++++++++++++
; r24 - result byte
spi_read_byte:
	ldi r24, 0x0
	ldi r25, 0x8
spi_read:
	; output data is changed on the falling edge of SCL
	sbi SPI_PORT, SCK

	clc 					; clear carry flag
	sbic SPI_PIN, MISO 	; skip next if miso is low
	sec 					; miso is high, set carry flag
	rol	r24 				; shift left through carry, set bit0 before shift
	dec r25

	cbi SPI_PORT, SCK
	brne spi_read
	
	cbi SPI_PORT, MISO
	ret
