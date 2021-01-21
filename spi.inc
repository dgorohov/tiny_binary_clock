; --- TOP --
; RESET MISO
;   CLK MOSI
; ----------


.equ SCK 	= PD1
.equ MISO 	= PD3
.equ MOSI 	= PD2

.equ SPI_PORT 		= PORTD
.equ SPI_PIN 		= PIND
.equ SPI_PORT_DIR 	= DDRD

spi_init:
	in tmp, SPI_PORT_DIR
	cbr tmp, (1 << MISO)
	sbr tmp, (1 << SCK) | (1 << MOSI)
	out SPI_PORT_DIR, tmp

	in tmp, SPI_PORT
	cbr tmp, (1 << SCK) | (1 << MISO)
	sbr tmp, (1 << MOSI)
	out	SPI_PORT, tmp
	ret

; +++++++++++++++++++++++++++
; data - r24
; size - r25
spi_write_byte:
	push r25
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
	pop r25
	ret

; +++++++++++++++++++++++++++
; r24 - result byte
spi_read_byte:
	push r25
	clr r24
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
	pop r25
	ret
