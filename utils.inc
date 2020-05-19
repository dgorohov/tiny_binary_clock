timer1s:
	ldi tmp, 	0			; these are timer counters
	ldi tmp_b, 	0
	ldi r18, 	5

timer2:
	inc tmp 				; do 256 iterations - 1 clock
	brne timer2				; branch if not equal to beginning of timer2 - 1 clock * 256, then 1
	inc tmp_b 				; do 256 times - 1 clock
	brne timer2				; branch if not equal to beginning of timer2 - 1 clock * 256, then 1
	dec r18					; do 5 times - 1 clock
	brne timer2 			; branch if not equal to beginning of timer2 - 1 clock * 5, then 1
	ret 					; once there have been 256 * 256 * 5 loops, return
