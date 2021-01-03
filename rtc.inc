.equ CS 	= PD5
.equ INT 	= PD4

.equ CS_INT_PORT 		= PORTD
.equ CS_INT_PORT_DIR	= DDRD

.equ RTC_CMD 			= (1 << 4)
.equ READ_CMD 			= (1 << 7) | RTC_CMD	;0x90 	; 0b10010000
.equ WRITE_CMD 			= (0 << 7) | RTC_CMD	;0x10 	; 0b00010000

.equ INTERRUPT_BITS 	= (1 << 6) | (1 << 4)	; second interrupt enabled
												; interrupt pin generates a pulse

.equ PCA_C1_REG 		= 0x0 	; Control_1 register
.equ PCA_C2_REG 		= 0x1 	; Control_2 register
.equ PCA_SEC_REG 		= 0x2 	; Seconds register
.equ PCA_MIN_REG 		= 0x3 	; Minutes register

rtc_init:
	sbi CS_INT_PORT_DIR, CS
	cbi CS_INT_PORT_DIR, INT
	sbi CS_INT_PORT, INT
	cbi CS_INT_PORT, CS

rtc_setup:
	sbi CS_INT_PORT, CS
	ldi r24, WRITE_CMD | PCA_C1_REG		; write, start from control_1
	rcall spi_write_byte
	ldi r24, 0b00000000		; control_1 - Power-On Reset Override sequence reception disabled, 24hrs
	rcall spi_write_byte
	ldi r24, 0b01010000
	rcall spi_write_byte	; interrupt
	
; setup time
	ldi r24, 0x00
	rcall spi_write_byte	; seconds
	ldi r24, 0b00010101     ; 15min
	rcall spi_write_byte	; minutes
	ldi r24, 0b10 			; 2hour
	rcall spi_write_byte	; hours
	ldi r24, 0x00
	rcall spi_write_byte	; days
	rcall spi_write_byte	; weekdays
	rcall spi_write_byte	; months
	rcall spi_write_byte	; years
	cbi CS_INT_PORT, CS

	cbi SPI_PORT, MISO
	ret

rtc_read_time:
	sbi CS_INT_PORT, CS

	ldi r24, READ_CMD | PCA_SEC_REG		; read start from seconds
	rcall spi_write_byte

	rcall spi_read_byte					; seconds
	cbr r24, 1 << 7 					; removing highest bit - flag of integrity
	sts current_second, r24

	rcall spi_read_byte					; minutes
	sts current_minute, r24

	rcall spi_read_byte 				; hours
	cbr r24, (1 << 7) | (1 << 6)		; removing 6 & 7 bits
	sts current_hour, r24

	cbi CS_INT_PORT, CS
	ret

rtc_disable_int:
	sbi CS_INT_PORT, CS

	ldi r24, WRITE_CMD | PCA_C2_REG		; write to control_2
	rcall spi_write_byte
	ldi r24, 0b00010000 				; 6 bif off
	rcall spi_write_byte

	cbi CS_INT_PORT, CS
	ret

rtc_enable_int:
	sbi CS_INT_PORT, CS

	ldi r24, WRITE_CMD | PCA_C2_REG		; write to control_2
	rcall spi_write_byte
	ldi r24, 0b01010000 				; 6 bit on
	rcall spi_write_byte

	cbi CS_INT_PORT, CS
	ret
