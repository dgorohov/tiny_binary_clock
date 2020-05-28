.nolist
.include "tn2313Adef.inc"
.list

.def tmp 	= r16
.def tmp_b 	= r17
.def inp 	= r24

.equ PCIE0 	  = 5
.equ PCIE1 	  = 3
.equ PCIE2 	  = 4

.equ INT_PCMSK = PCMSK
.equ INT_PCINT = PCINT0

.equ BTN_PORT  = PORTB
.equ BTN_PIN   = PINB
.equ BTN_DIR   = DDRB
.equ BTN_BIT   = PB0

.dseg
.org SRAM_START

current_hour:	.byte 1
current_minute:	.byte 1
current_second:	.byte 1
current_column:	.byte 1
num_seconds: 	.byte 1
current_mode:	.byte 2

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
	ldi zl, 30 	; clear registers
	clr zh
	dec zl
	st z, zh
	brne PC-2
ramflush:
	ldi zl, low(SRAM_START)
	ldi zh, high(SRAM_START)
	clr tmp
loop_ramflush:
	st z+, tmp
	cpi zl, low(RAMEND + 1)
	brne loop_ramflush
	cpi zh, high(RAMEND + 1)
	brne loop_ramflush
init_stack:
	ldi tmp, low(RAMEND)
	out SPL, tmp

power_reduction:
	in	tmp, PRR
	ori	tmp, (1 << PRUSI) | (1 << PRUSART) | (1 << PRTIM1)
	out	PRR, tmp
; Analog Comparator Disable
	cbi ACSR, ACIE
	cbi ACSR, ACIC
	sbi ACSR, ACD
; Disable all analog inputs
	sbi DIDR, AIN0D
	sbi DIDR, AIN1D
; Disable USICR
	ldi tmp, 0x00
	out USICR, tmp
; Disable UCSRB interrupts
	ldi tmp, 0b00000110
	out UCSRB, tmp

; Disable watchdog
	wdr
	ldi	tmp, (0 << WDRF)	; Clear WDRF in MCUSR
	out	MCUSR, tmp

	in tmp, WDTCR
	ori tmp, (1 << WDCE) | (1 << WDE)
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
.ifdef TURN_OFF_PWM
	in tmp, PRR
	ori tmp, (1 << PRTIM0) 		; Disable Timer
	out PRR, tmp
	rjmp start
.endif

pwm_setup0:
	ldi tmp, (1 << COM0A1) | (1 << WGM01) | (1 << WGM00)
	out TCCR0A, tmp

	ldi tmp, (1 << CS01)
	out TCCR0B, tmp

	ldi tmp, BRIGHTNESS 		; BRIGHTNESS: 0 - full, 255 - off
	out OCR0A, tmp

	in tmp, TIMSK
	cbr tmp, (1 << OCIE0A) | (1 << OCIE0B)
	out TIMSK, tmp

start:
	in tmp, BTN_DIR
	ori tmp, (1 << BTN_BIT)
	out BTN_DIR, tmp

	rcall timer1s
	rcall rtc_init
	sei

loop:
	rcall hc595_reset
	clr tmp
	sts num_seconds, tmp
	sts current_mode, tmp
	sts current_mode + 1, tmp
	ldi tmp, 1
	sts current_column, tmp

	rcall rtc_disable_int
	rcall sleep_mode 					; sleep
	rcall rtc_read_time
	rcall rtc_enable_int

loop_continue:
	lds tmp, num_seconds
	cpi tmp, 20 						; ~10 sec or 1/64ms two interrupts every second
	brge loop 							; stop loop if 10sec passed
update_hc595:
	lds tmp, current_column
	lsl tmp 							; current_column << 1
	andi tmp, 0x0F 						; check if bit have left low nibble's boundaries
	brne PC+2 							; if not skip next
	ldi tmp, 1 							; if so, current_column = 1
	sts current_column, tmp 			; set it with a new value

	mov tmp_b, tmp
	andi tmp_b, (1 << 3) | (1 << 2) 	; isolate 3 and 2 bits
	brne PC+4							; PC+4 if not set (neq. 0)
	lds r24, current_minute
	rjmp PC+2
	lds r24, current_second

	mov tmp_b, tmp
	andi tmp_b, (1 << 3) | (1 << 1) 	; check if 3 and 1 bits are set, e.g. high bits
	brne PC+2 							;
	swap r24
	andi r24, 0x0F

	com tmp
	andi tmp, 0xF 						; invert column. 1 - means off, 0 - on

	swap r24
	or r24, tmp
	; RRRRCCCC
	rcall hc595_send_byte
	rjmp loop_continue

; +++++++++++++++++++++++++++
sleep_mode:
.ifndef TURN_OFF_PWM
	sbi PRR, PRTIM0 			; Disable Timer
.endif
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

.ifndef TURN_OFF_PWM
	cbi PRR, PRTIM0				; Enable Timer
.endif

	in tmp, INT_PCMSK
	andi tmp, ~(1 << INT_PCINT) ; PCINT disable
	out INT_PCMSK, tmp

	in tmp, MCUCR
	andi tmp, ~(1 << SE) 		; Sleep disable
	out MCUCR, tmp

	sei
	ret

update_current_time:
	push r25 					; keep r25
	push r24 					; keep r24

	cli 						; disable interrupts globally

	in r24, SREG				;
	push r24					; keep SREG

	rcall rtc_read_time

	lds r25, num_seconds		; go here
	inc r25
	sts num_seconds, r25

	pop r24						;
	out SREG, r24				; restore SREG
	pop r24						; restore r24
	pop r25						; restore r25
	reti

.include "rtc.inc"
.include "spi.inc"
.include "hc595.inc"
.include "utils.inc"
