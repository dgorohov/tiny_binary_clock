;
;	74hc595
;           +---+
;   QB (1) -|	|- VCC
;       QC -|	|- QA
;       QD -|	|- DATA
;       QE -|	|- OE
;       QF -|	|- LATCH
;       QG -|	|- CLOCK
;       QH -|	|- CLEAR
;      GND -|	|- QH'
;           +---+
;
; DATA - is used to feed data into the shift register a bit at a time.
; CLOCK - is the clock for the shift register
; LATCH - When driven HIGH, the contents of Shift Register are copied 
;		  into the Storage/Latch Register; which ultimately shows up at the output. 
; 		  So the latch pin can be seen as like the final step in the process to seeing 
;		  our results at the output, which in this case are LEDs.
; CLEAR - pin allows us to reset the entire Shift Register, making all its bits 0, at once. 
;		  This is a negative logic pin, so to perform this reset; 
;		  we need to set the SRCLR pin LOW. When no reset is required, this pin should be HIGH.
; OE -    is negative logic too: When the voltage on it is HIGH, the output pins are 
;		  disabled/set to high impedance state and don’t allow current to flow. 
;		  When OE gets low voltage, the output pins work normally.

.equ HC595_OE			= PB2

.equ HC595_OE_PORT 		= PORTB
.equ HC595_OE_PORT_DIR 	= DDRB
.equ HC595_OE_PIN 		= PINB

.equ HC595_PORT 		= PORTD
.equ HC595_PORT_DIR 	= DDRD

.equ HC595_DATA			= PD5
.equ HC595_LATCH		= PD4
.equ HC595_CLK			= PD3
.equ HC595_CLEAR		= PD2

.ifndef BRIGHTNESS
.equ BRIGHTNESS 		= 230
.endif

hc595_init:
	in tmp, HC595_OE_PORT_DIR
	ori tmp, 1 << HC595_OE
	out HC595_OE_PORT_DIR, tmp

	in tmp, HC595_OE_PORT
	andi tmp, ~(1 << HC595_OE)
	out HC595_OE_PORT, tmp

	in tmp, HC595_PORT_DIR
	ori tmp, (1 << HC595_DATA) | (1 << HC595_LATCH) | (1 << HC595_CLK) | (1 << HC595_CLEAR)
	out HC595_PORT_DIR, tmp

	in tmp, HC595_PORT
	sbr tmp, 1 << HC595_CLEAR
	cbr tmp, (1 << HC595_DATA) | (1 << HC595_LATCH) | (1 << HC595_CLK)
	out HC595_PORT, tmp

	rcall hc595_reset

	ret

hc595_toggle:
	sbic HC595_OE_PIN, HC595_OE
	cbi HC595_OE_PORT, HC595_OE

	sbis HC595_OE_PIN, HC595_OE
	sbi HC595_OE_PORT, HC595_OE

	ret

hc595_send_byte:
	push  r25
	ldi r25, 0x08
hc595_send_bit:
	lsl r24
	brcc hc595_bit_low
	sbi HC595_PORT, HC595_DATA
	rjmp hc595_bit_done
hc595_bit_low:
	cbi HC595_PORT, HC595_DATA
hc595_bit_done:

	sbi HC595_PORT, HC595_CLK
	nop
	cbi HC595_PORT, HC595_CLK

	dec r25
	brne hc595_send_bit

	sbi HC595_PORT, HC595_LATCH
	nop
	cbi HC595_PORT, HC595_LATCH

	pop r25
	ret

hc595_reset:
	cbi HC595_PORT, HC595_CLEAR
	nop
	sbi HC595_PORT, HC595_CLEAR
	sbi HC595_PORT, HC595_LATCH
	nop
	cbi HC595_PORT, HC595_LATCH
	ret

