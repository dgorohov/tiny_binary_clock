; r24 - row number
show_row:
	in tmp_b, PORTB

	ldi ZH, high(row_map << 1)
	ldi ZL, low(row_map << 1)

	add ZL, r24
	lpm
	mov r24, r0

	ldi tmp, 1
	rjmp row_cnt_dec
row_cnt:
	add tmp, tmp
row_cnt_dec:
	dec r24
	brpl row_cnt

	or tmp_b, tmp
	out PORTB, tmp_b

	ret

; r24 - column number
show_column:
	in tmp_b, PORTD

	ldi ZH, high(column_map << 1)
	ldi ZL, low(column_map << 1)

	add ZL, r24
	lpm
	mov r24, r0

	ldi tmp, 1
	rjmp col_cnt_dec
col_cnt:
	add tmp, tmp
col_cnt_dec:
	dec r24
	brpl col_cnt
	com tmp
	and tmp_b, tmp
	out PORTD, tmp_b

	ret

init_table:
	in tmp, DDRB
	ori tmp, (1 << PB1) | (1 << PB2) | (1 << PB3) | (1 << PB4)
	out DDRB, tmp

	in tmp, DDRD
	ori tmp, (1 << PD3) | (1 << PD4) | (1 << PD5) | (1 << PD6)
	out DDRD, tmp

clear_led:
	in tmp, PORTB
	andi tmp, (PORTB & ~(1 << PB1)) | (PORTB & ~(1 << PB2)) | (PORTB & ~(1 << PB3)) | (PORTB & ~(1 << PB4))
	out PORTB, tmp

	in tmp, PORTD
	ori tmp, (1 << PD3) | (1 << PD4) | (1 << PD5) | (1 << PD6)	; turned off, inverted.
	out PORTD, tmp
	ret

column_map:
	.db PD6, PD5, PD4, PD3
row_map:
	.db PB1, PB2, PB3, PB4
