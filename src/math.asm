;=============================================================================
;
;   File math.asm                             combined next generation V3.04.3
;
;   Math subroutines
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;  2011-08-03 : [mH] moving from OSTC code


#include "hwos.inc"						; mandatory header

math	CODE

;=============================================================================

	global	convert_time				; converts hi:lo in minutes to hours (up:hi) and minutes (lo)
										; also usable for conversion of seconds to minutes and seconds
										; trashes xA, xB, xC
convert_time:
	movff	lo,xA+0						; copy hi:lo to xA
	movff	hi,xA+1						;
	movlw	d'60'						; set divisor to 60
	movwf	xB+0						; write 60 to xB
	clrf	xB+1						; 
	rcall	div16x16					; xC = xA / xB with xA as remainder
	movff	xC+1,up						; result    is hours   / minutes, copy to up (high byte)
	movff	xC+0,hi						; result    is hours   / minutes, copy to hi (low  byte)
	movff	xA+0,lo						; remainder is minutes / seconds, copy to lo
	return


	global	div16						; divA:2 = divA:2 / 2^WREG
										; trashes WREG
div16:
	bcf		STATUS,C					; clear carry
	rrcf	divA+1						; rotate right high byte, carry into MSB, LSB into carry
	rrcf	divA+0						; rotate right low  byte, carry into MSB, LSB into carry
	decfsz	WREG						; decrement counter, done?
	bra		div16						; NO  - loop
	return								; YES - done


	global	mult16						; xA:2 = xA:2 * 2^WREG
										; trashes WREG
mult16:
	bcf		STATUS,C					; clear carry
	rlcf	divA+0,F					; rotate left low  byte, carry into LSB, MSB into carry
	rlcf	divA+1,F					; rotate left high byte, carry into LSB, MSB into carry
	decfsz	WREG						; decrement counter, done?
	bra		mult16						; NO  - loop
	return								; YES - done


	global	addU16						; ; sub_c:2 = sub_a:2 + sub_b:2	with USIGNED values
										; trashes WREG
addU16:
	movf	sub_a+0,W					; get 1st summand (low  byte) to WREG
	addwf	sub_b+0,W					; add 2nd summand (low  byte) and store result in WREG
	movwf	sub_c+0						; copy result     (low  byte) to sub_c
	movf	sub_a+1,W					; get 1st summand (high byte) to WREG
	addwfc	sub_b+1,W					; add 2nd summand (high byte) and store result in WREG
	movwf	sub_c+1						; copy result     (high byte) to sub_c
	return								; done


	global	sub16						; sub_c:2 = sub_a:2 - sub_b:2   with SIGNED values
										; sets neg_flag if result is < 0
										; trashes WREG
sub16:
	bcf		neg_flag					; clear flag which will indicate if result is negative
	movf	sub_b+0,W					; get value to be subtracted, low byte
	subwf	sub_a+0,W					; execute subtraction on low byte
	movwf	sub_c+0						; copy result to output variable, low byte
	movf	sub_b+1,W					; get value to be subtracted, high byte
	subwfb	sub_a+1,W					; execute subtraction on high byte, considering borrow flag
	movwf	sub_c+1						; copy result to output variable, high byte
	btfss	STATUS,N					; result negative ?
	return								; NO  - result positive, done
	bsf		neg_flag					; YES - set flag
	comf	sub_c+1						;     - do a 16 bit sign change
	negf	sub_c+0						;
	btfsc	STATUS,C					;     - carry to be propagated ?
	incf	sub_c+1,F					;       YES - do it
	return								;     - done


	global	subU16						; sub_c:2 = sub_a:2 - sub_b:2   with UNSIGNED values
										; sets neg_flag if result is < 0
										; trashes WREG
subU16:
	bcf		neg_flag					; clear flag which will indicate if result is negative
	movf	sub_b+0,W					; get value to be subtracted, low byte
	subwf	sub_a+0,W					; execute subtraction on low byte
	movwf	sub_c+0						; copy result to output variable, low byte
	movf	sub_b+1,W					; get value to be subtracted, high byte
	subwfb	sub_a+1,W					; execute subtraction on high byte, considering borrow flag
	movwf	sub_c+1						; copy result to output variable, high byte
	btfsc	STATUS,C					; borrow to propagate (B == /CARRY) ?
	return								; NO  - result positive, done
	bsf		neg_flag					; YES - set flag
	comf	sub_c+1						;     - do a 16 bit sign change
	negf	sub_c+0						;     - ...
	btfsc	STATUS,C					;     - carry to be propagated ?
	incf	sub_c+1,F					;       YES - do it
	return								;     - done


	global	cmpU16						; sub_a:2 - sub_b:2	with UNSIGNED values
										; sets neg_flag if result is < 0, but does not store result itself
										; trashes WREG
cmpU16:
	bcf		neg_flag					; clear flag which will indicate if result is negative
	movf	sub_b+0,W					; get value to be subtracted, low byte
	subwf	sub_a+0,W					; execute subtraction on low byte
	movf	sub_b+1,W					; get value to be subtracted, high byte
	subwfb	sub_a+1,W					; execute subtraction on high byte, considering borrow flag
	btfss	STATUS,C					; borrow to propagate (B == /CARRY) ?
	bsf		neg_flag					; YES - result is negative, set flag
	return								; done


	global	mult16x16					; xC:4 = xA:2 * xB:2   with UNSIGNED values
										; trashes PRODL, PRODH, WREG
mult16x16:
	clrf	xC+2						; clear the high-order bits
	clrf	xC+3
	;
	movf	xA+0,W						; do the "L" multiplication
	mulwf	xB+0
	movff	PRODL,xC+0					; copy result to xC
	movff	PRODH,xC+1
	;
	movf	xA+0,W						; do the "I" multiplication
	mulwf	xB+1
	movf	PRODL,W						; get the product's low byte...
	addwf	xC+1,F						; ... and add it to xC+1
	movf	PRODH,W						; get the product's high byte...
	addwfc	xC+2,F						; ... and add it to xC+2 obeying carry bit from xC+1
	;
	movf	xA+1,W						; do the "O" multiplication
	mulwf	xB+0
	movf	PRODL,W						;  get the product's low byte...
	addwf	xC+1,F						; ... and add it to xC+1
	movf	PRODH,W						; get the product's high byte...
	addwfc	xC+2,F						; ... and add it to xC+2 obeying carry bit from xC+1
	clrf	WREG						; clear WREG...
	addwfc	xC+3,F						; ... add add it to xC+3 obeying carry bit from xC+2 (can only happen in "O" multiplication)
	;
	movf	xA+1,W						; do the "F" multiplication
	mulwf	xB+1
	movf	PRODL,W						;   get the product's low byte...
	addwf	xC+2,F						; ... and add it to xC+2
	movf	PRODH,W						; get the product's high byte...
	addwfc	xC+3,F						; ... and add it to xC+3 obeying carry bit from xC+2
	return


	global	div16x16					; xC:2 = xA:2 / xB:2 with xA as remainder
										; trashes WREG
div16x16:
	movlw		.16						; process 16 bits ...
	movwf		math_loop				; ... initialize loop counter
	movff		xA+0,xC+0				; copy xA to xC
	movff		xA+1,xC+1				; ...
	clrf		xA+0					; clear xA, will now be used to hold the remainder
	clrf		xA+1					; ...
div16x16_1:
	bcf			STATUS,C				; clear carry flag to shift in a zero bit
	rlcf		xC+0,F					; shift left xC
	rlcf		xC+1,F					; ... shifting MSB out of xC...
	rlcf		xA+0,F					; ... and into LSB of     xA
	rlcf		xA+1,F					; ...
	btfsc		STATUS,C				; did the remainder overflow (carry set)?
	bra			div16x16_2				; YES - directly generate a result bit = 1
	movf		xB+0,W					; NO  - compute remainder - divisor = xA - xB, trash result to WREG
	subwf		xA+0,W					;     - ...
	movf		xB+1,W					;     - ...
	subwfb		xA+1,W					;     - ...
	btfss		STATUS,C				;     - remainder < divisor (-> borrow flag set, equals carry flag cleared) ?
	bra			div16x16_3				;       YES - result bit = 0, keep LSB of xC+0 being 0
div16x16_2:
	bsf			xC+0,0					;       NO  - result bit = 1, set  LSB of xC+0 to 1
	movf		xB+0,W					;           - subtract divisor from remainder "for real": xA = xA - xB
	subwf		xA+0,F					;           - ...
	movf		xB+1,W					;           - ...
	subwfb		xA+1,F					;           - ...
div16x16_3:
	decfsz		math_loop,F				; decrement loop counter, all bits done?
	bra			div16x16_1				; NO  - loop
	return								; YES - done


	global	div32x16					; xC:4 = xC:4 / xB:2 with xA as remainder
										; trashes WREG
div32x16:
	movlw		.32						; process 32 bits ...
	movwf		math_loop				; ... initialize loop counter
	clrf		xA+0					; clear xA, will be used to hold the remainder
	clrf		xA+1					; ...
div32x16_1:
	bcf			STATUS,C				; clear carry flag to shift in a zero bit
	rlcf		xC+0,F					; shift left xC
	rlcf		xC+1,F					; ...
	rlcf		xC+2,F					; ...
	rlcf		xC+3,F					; ... shifting MSB out of xC...
	rlcf		xA+0,F					; ... and into LSB of     xA
	rlcf		xA+1,F					; ...
	btfsc		STATUS,C				; did the remainder overflow (carry set)?
	bra			div32x16_2				; YES - directly generate a result bit = 1
	movf		xB+0,W					; NO  - compute remainder - divisor = xA - xB, trash result to WREG
	subwf		xA+0,W					;     - ...
	movf		xB+1,W					;     - ...
	subwfb		xA+1,W					;     - ...
	btfss		STATUS,C				;     - remainder < divisor (-> borrow flag set, equals carry flag cleared) ?
	bra			div32x16_3				;       YES - result bit = 0, keep LSB of xC+0 being 0
div32x16_2:
	bsf			xC+0,0					;       NO  - result bit = 1, set  LSB of xC+0 to 1
	movf		xB+0,W					;           - subtract divisor from remainder "for real": xA = xA - xB
	subwf		xA+0,F					;           - ...
	movf		xB+1,W					;           - ...
	subwfb		xA+1,F					;           - ...
div32x16_3:
	decfsz		math_loop,F				; decrement loop counter, all bits done?
	bra			div32x16_1				; NO  - loop
	return								; YES - done


;=============================================================================

; ISR math functions

	global	isr_shift_C31				; 24 bit shift, repeated WREG times, dedicated to a specific usage:
										; Because less than 8 bits are shifted and only C[2:1] is needed,
										; we don't care what bit is inserted.
isr_shift_C31:
	rrcf	isr_xC+3,F					; shift three bytes
	rrcf	isr_xC+2,F
	rrcf	isr_xC+1,F
	decfsz	WREG						; decrement loop counter, done?
	bra		isr_shift_C31				; NO  - loop
	return								; YES - done


	global	isr_unsigned_mult16x16		; isr_xC = isr_xA * _isr_xB   with UNSIGNED values
										; trashes PRODL, PRODH, WREG
isr_unsigned_mult16x16:
	movf	isr_xA+0,W					; multiply a[0] * b[0]
	mulwf	isr_xB+0
	movff	PRODL,isr_xC+0				; store product to c[1]:c[0]
	movff	PRODH,isr_xC+1
	;
	movf	isr_xA+1,W					; multiply a[1] * b[1]
	mulwf	isr_xB+1
	movff	PRODL, isr_xC+2				; store product to  c[3]:c[2]
	movff	PRODH, isr_xC+3
	;
	movf	isr_xA+0,W					; multiply a[0] * b[1]
	mulwf	isr_xB+1
	movf	PRODL,W						; add cross product to c[3]:c[2]:c[1]
	addwf	isr_xC+1,F
	movf	PRODH,W
	addwfc	isr_xC+2,F					; propagate carry
	clrf	WREG
	addwfc	isr_xC+3,F					; propagate carry
	;
	movf	isr_xA+1,W					; multiply a[1] * b[0]
	mulwf	isr_xB+0
	movf	PRODL,W						; add cross product
	addwf	isr_xC+1,F
	movf	PRODH,W
	addwfc	isr_xC+2,F					; propagate carry
	clrf	WREG
	addwfc	isr_xC+3,F					; propagate carry
	return


	global	isr_signed_mult16x16		; isr_xC = isr_xA * isr_xB   with SIGNED values
										; trashes PRODL, PRODH, WREG
isr_signed_mult16x16:
	rcall	isr_unsigned_mult16x16		; do an unsigned multiplication first
	;									; manage sign extension of operand B
	btfss	isr_xB+1,7					; is B negative ?
	bra		isr_signed_mult_checkA		; NO  - continue checking operand A
	movf	isr_xA+0,W					; Yes - add -65536 * A
	subwf	isr_xC+2,F
	movf	isr_xA+1,W
	subwfb	isr_xC+3,F
isr_signed_mult_checkA					; manage sign extension of operand B
	btfss	isr_xA+1,7					; is A negative ?
	return								; NO  - done
	movf	isr_xB+0,W					; Yes - add -65536 * B
	subwf	isr_xC+2,F
	movf	isr_xB+1,W
	subwfb	isr_xC+3,F
	return

	END