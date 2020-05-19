.nolist
.include "tn2313Adef.inc"
.list

.def tmp 	= r16
.def tmp_b 	= r17


.equ PCIE0 	  = 5
.equ PCIE1 	  = 3
.equ PCIE2 	  = 4

.equ INT_PCMSK = PCMSK
.equ INT_PCINT = PCINT0

.dseg
.org SRAM_START

current_hour:	.byte 1
current_minute:	.byte 1
current_second:	.byte 1
current_column:	.byte 1
num_seconds: 	.byte 1


.cseg
.org 0x0000

rjmp init 	; RESET vector
reti 		; INT0  vector
reti 		; INT1 vector
reti 		; TIMER1 CAPT
reti 		; TIMER1 COMPA
reti 		; TIMER1 OVF
reti 		; TIMER0 OVF
reti 		; USART0, RX
reti 		; USART0, UDRE
reti 		; USART0, TX
reti 		; ANALOG COMP
reti 		; PCINT0
reti 		; TIMER1 COMPB
reti 		; TIMER0 COMPA
reti 		; TIMER0 COMPB
reti 		; USI START
reti 		; USI OVERFLOW
reti 		; EE READY
reti 		; WDT OVERFLOW
reti 		; PCINT1
rjmp update_current_time  		; PCINT2

init:
	ldi tmp, LOW(RAMEND)
	out SPL, tmp

	ldi tmp, 1 << 3
	sts current_column, tmp

	ldi tmp, 0x00
	sts current_second, tmp
	sts current_minute, tmp
	sts current_hour, tmp

power_reduction:
	in	tmp, PRR
	ori	tmp, (1 << PRUSI) | (1 << PRUSART) | (1 << PRTIM1)
	out	PRR, tmp

	cbi ACSR, ACIE 			; Analog Comparator Interrupt Disable
	cbi ACSR, ACIC 			; Analog Comparator Input Capture Disable
	sbi ACSR, ACD 			; Analog Comparator Disable

	ldi tmp, 0x00 			; Disable all analog inputs
	out DIDR, tmp

	ldi tmp, 0x00			; Disable USICR
	out USICR, tmp

	ldi tmp, 0b00000110 	; Disable UCSRB interrupts
	out UCSRB, tmp

; Disable watchdog
	in tmp, MCUSR
	ori tmp, (0 << WDRF)	; Disable watchdog
	out MCUSR, tmp

	in tmp, WDTCR
	ori tmp, 0x18 			; (1 << WDCE) | (1 << WDE)
	out WDTCR, tmp

	ldi tmp, (0 << WDE)
	out WDTCR, tmp

main:
	ldi tmp, (1 << PCIE0) | (1 << PCIE2)
	out GIMSK, tmp

	in	tmp, MCUCR
	ori	tmp, (0 << SM1) | (1 << SM0) 	; Power down, 01 or 11 is a power down mode
	out	MCUCR, tmp

other_init:
	rcall hc595_init
	rcall spi_init
	rcall rtc_init
.ifdef TURN_OFF_PWM
	rjmp start
.endif

pwm_setup0:
	ldi tmp, (1 << COM0A1) | (1 << WGM01) | (1 << WGM00)
	out TCCR0A, tmp

	ldi tmp, (1 << CS01)
	out TCCR0B, tmp

	ldi tmp, BRIGHTNESS 		; BRIGHTNESS: 0 - full, 255 - off
	out OCR0A, tmp

	in r24, TIMSK
	andi r24, ~(1 << OCIE0A) & ~(1 << OCIE0B)
	out TIMSK, r24

start:
	in tmp, DDRB
	ori tmp, 1 << PB0
	out DDRB, tmp

	sei

loop:
	ldi r22, 0
	sts num_seconds, r22
	rcall hc595_reset
	rcall rtc_disable_int
	rcall sleep_mode 			; sleep
	rcall rtc_read_time
	rcall rtc_enable_int

loop_continue:
	lds r22, num_seconds
	cpi r22, 20
	brge loop

update_hc595:
	clc
	lds tmp, current_column
	lsr tmp 					; current_column >> 1
	brcc compa_set_current
	ldi tmp, 1 << 3				; if so, current_column = 1 << 3
compa_set_current:
	sts current_column, tmp 	; set it with a new value

first_column:
	lds r24, current_second 	; load current_minute value

	ldi tmp_b, 1 << 3
	cpse tmp, tmp_b 			; if not first column
	rjmp second_column 			; go and check next column

	swap r24					; (current_minute >> 4) & 0x0F
	andi r24, 0x0F

	rjmp update

second_column:
	ldi tmp_b, 1 << 2
	cpse tmp, tmp_b 			; if not second column
	rjmp third_column 			; go and check next column
	
	andi r24, 0x0F

	rjmp update

third_column:
	lds r24, current_minute 		; load current_second value

	ldi tmp_b, 1 << 1
	cpse tmp, tmp_b 			; if not second column
	rjmp fourth_column 			; go and check next column

	swap r24					; (current_second >> 4) & 0x0F
	andi r24, 0x0F

	rjmp update

fourth_column:
	ldi tmp_b, 1 << 0
	cpse tmp, tmp_b 			; if not second column
	rjmp update 				; go and check next column
	
	andi r24, 0x0F

update:
	com tmp
	andi tmp, 0xF

	swap r24
	or r24, tmp

	; r24 - row
	; tmp - column
	; RRRRCCCC
	rcall hc595_send_byte

	rjmp loop_continue

; +++++++++++++++++++++++++++
sleep_mode:
	in tmp, PRR
	ori tmp, (1 << PRTIM0) 		; Disable Timer
	out PRR, tmp

	in tmp, INT_PCMSK
	ori tmp, (1 << INT_PCINT)	; PCINT enable
	out INT_PCMSK, tmp

	in tmp, PCMSK2
	andi tmp, ~(1 << PCINT12)	; PCINT12 RTC int disable
	out PCMSK2, tmp

	in tmp, MCUCR
	ori tmp, (1 << SE) 			; Sleep enable
	out MCUCR, tmp

	sleep 						; Sleep
	cli

	in tmp, PCMSK2
	ori tmp, (1 << PCINT12)		; PCINT12 RTC int enable again
	out PCMSK2, tmp

	in tmp, PRR
	andi tmp, ~(1 << PRTIM0)	; Enable Timer
	out PRR, tmp

	in tmp, INT_PCMSK
	andi tmp, ~(1 << INT_PCINT) ; PCINT disable
	out INT_PCMSK, tmp

	in tmp, MCUCR
	andi tmp, ~(1 << SE) 	; Sleep disable
	out MCUCR, tmp

	sei

	ret

update_current_time:
	push r25 				; keep r25
	push r24 				; keep r24

	cli 					; disable interrupts globally

	in r24, SREG			;
	push r24				; keep SREG

	rcall rtc_read_time

	lds r25, num_seconds
	inc r25
	sts num_seconds, r25

	pop r24					;
	out SREG, r24			; restore SREG
	pop r24					; restore r24
	pop r25					; restore r25
	reti

.include "rtc.inc"
.include "spi.inc"
.include "hc595.inc"
