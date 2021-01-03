.nolist
.include "tn2313Adef.inc"
.list

.def tmp 	= r16
.def tmp_b 	= r17

.equ PCIE0 	  = 5
.equ PCIE1 	  = 3
.equ PCIE2 	  = 4

.equ INT_PCMSK = PCMSK2
.equ INT_PCINT = PCINT11

.equ BTN_PORT  = PORTD
.equ BTN_PIN   = PIND
.equ BTN_DIR   = DDRD
.equ BTN_BIT   = PD0

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
	; ldi tmp, (1 << PCIE0) | (1 << PCIE2)
	ldi tmp, (1 << PCIE2)
	; PCIE0 - PCINT7..0
	; PCIE1 - PCINT10..8
	; PCIE2 - PCINT17..11
	out GIMSK, tmp

	in	tmp, MCUCR
	ori	tmp, (0 << SM1) | (1 << SM0) 	; Power down, 01 or 11 is a power down mode
	out	MCUCR, tmp

other_init:
	rcall hc595_init
	rcall spi_init

	in tmp, PRR
	ori tmp, (1 << PRTIM0) 		; Disable Timer
	out PRR, tmp

	ldi tmp, 0
	out TIMSK, tmp

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
	clr tmp
	sts current_column, tmp

	rcall rtc_disable_int
	rcall sleep_mode 					; sleep
	rcall rtc_enable_int

loop_continue:
	lds tmp, num_seconds
	cpi tmp, 20 						; ~10 sec or 1/64ms two interrupts every second
	brge loop 							; stop loop if 10sec passed
	rcall rtc_read_time

	;
	; Mapping for the dynamic indicaton
	; CCCC RRRR - low nibble - column indicator, high - row
	; columns: 1 - off
	; rows: 1 - on
	;			  R3
	;			  R2
	;			  R1
	;			  R0
	; C3 C2 C1 C0 (bits)
	; C3 | C2 | C1 | C0 | R0 | R1 | R2 | R3
	;

; increment column or set default if exceeds the lower nibble boundaries
	lds tmp, current_column
	lsl tmp
	andi tmp, 0x0F
	brne column_selected
	ldi tmp, 1
column_selected:
	sts current_column, tmp
	mov r24, tmp

	andi tmp, 0b1100
	brne select_right_value
select_left_value:
	lds tmp_b, current_minute
	rjmp display_value
select_right_value:
	lds tmp_b, current_hour

display_value:
	mov tmp, r24
	andi tmp, 0b1010
	brne _display_value			; if it is not 2nd or 4th column to display
	swap tmp_b 					; do swap nibbles, to show the right units of value
_display_value:
	andi tmp_b, 0xF0 			; we need to select higher nibble to show
	; input:  R3R2R1R0 C1C2C3C4
	; output: C4C3C2C1 R0R1R2R3	
	mov tmp, r24
	com tmp
	andi tmp, 0x0F
	or tmp, tmp_b
	clr r24
	rcall mirror_byte
	rcall hc595_send_byte
	rjmp loop_continue

; +++++++++++++++++++++++++++
sleep_mode:
	in tmp, INT_PCMSK
	ori tmp, (1 << INT_PCINT)	; PCINT enable
	out INT_PCMSK, tmp

	in tmp, PCMSK2
	andi tmp, ~(1 << PCINT15)	; PCINT15 RTC int disable
	out PCMSK2, tmp

	in tmp, MCUCR
	ori tmp, (1 << SE) 			; Sleep enable
	out MCUCR, tmp

	sleep 						; Sleep
	cli

	in tmp, PCMSK2
	ori tmp, (1 << PCINT15)		; PCINT15 RTC int enable again
	out PCMSK2, tmp

	in tmp, INT_PCMSK
	andi tmp, ~(1 << INT_PCINT) ; PCINT disable
	out INT_PCMSK, tmp

	in tmp, MCUCR
	andi tmp, ~(1 << SE) 		; Sleep disable
	out MCUCR, tmp

	sei
	ret

mirror_byte:
	ldi r18, 8
_mirror_byte:
	ror tmp
	rol r24
	dec r18
	brne _mirror_byte
	ret

update_current_time:
	push r25 					; keep r25
	push r24 					; keep r24

	cli 						; disable interrupts globally

	in r24, SREG				;
	push r24					; keep SREG

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
