;=============================================================================
;
;   File convert.asm                           combined next generation V3.0.1
;
;   Converts register values to string
;
;   Copyright (c) 2011, Matthias Heinrichs, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;   2007-10-07 : [MH]  Creation for OSTC sources
;   2010-12-10 : [jDG] Optimize macro size
;

#include "hwos.inc"						; Mandatory header

convert	CODE

;=============================================================================

	global	output99_call
output99_call:
	clrf	ignore_digits
	incf	ignore_digits,F
	clrf	cvt_temp4
	;bra	output99


	global	output99
output99:
	movlw	d'99'
	cpfslt	lo
	movwf	lo							; limit to 99
	movff	lo,cvt_temp_lo
	clrf	cvt_temp_hi
	bcf		pre_zero_flag				; do not display leading zeros

LCD_val99_2:
	movlw	.10							; 10
	movwf	cvt_temp2
	clrf	cvt_temp3
	rcall	DEC2ASCII

	movlw	.1							; 1
	movwf	cvt_temp2
	clrf	cvt_temp3
	bsf		pre_zero_flag				; last figure, display zero (0)
	rcall	DEC2ASCII
	return

	global	output99x_call
output99x_call:
	clrf	ignore_digits
	incf	ignore_digits,F
	clrf	cvt_temp4

	movlw	d'99'
	cpfslt	lo
	movwf	lo							; limit to 99
	movff	lo,cvt_temp_lo
	clrf	cvt_temp_hi
	bsf		pre_zero_flag				; display leading zeros
	bra		LCD_val99_2


	global	output8_call
output8_call:
	clrf	ignore_digits
	incf	ignore_digits,F
	clrf	cvt_temp4

output8:
	movff	lo,cvt_temp_lo
	clrf	cvt_temp_hi
	bcf		pre_zero_flag				; do not display leading zeros
	movlw	.100						; 100
	movwf	cvt_temp2
	clrf	cvt_temp3
	rcall	DEC2ASCII
	bra		LCD_val99_2


	global	output16_4_call
output16_4_call:						; limit to 9999
	bsf		show_last4
										; 9999 = 27 0F = [39][15]
	movlw	.40
	cpfslt	hi							; hi < 40 ?
	bra		output16_4_call_2			; NO  - hi >= 40, do limit
										; YES - hi <= 39
	movlw	.39
	cpfseq	hi							; hi = 39 ?
	bra		output16_4_call_3			; NO  - hi < 39, no limit needed
										; YES - hi = 39
	movlw	.15
	cpfslt	lo							; lo < 15
	movwf	lo							; NO  - lo >= 15, set lo = 15
										; YES - lo <= 14 or lo set to =15
	bra		output16_4_call_3			;     - done

output16_4_call_2:						; set to 9999
	MOVLI	.9999,mpr
output16_4_call_3:
	bra		output16_call


	global	output16_3_call
	global	output16_call
	global	output16
output16_3_call:						; limit to 999
	bsf		show_last3
	; Limit to 3
	movlw	.4
	cpfslt	hi
	bra		output16_3_call_2
	movlw	.3
	cpfseq	hi							; = 3 ?
	bra		output16_3_call_3			; NO - done
	movlw	.231						; limit to 231(+768=999...)
	cpfslt	lo
	movwf	lo
	bra		output16_3_call_3			; done
output16_3_call_2:						; set to .999
	MOVLI	.999,mpr
output16_3_call_3:
output16_call:
	clrf	ignore_digits
	incf	ignore_digits,F
	clrf	WREG
output16:
	movwf	cvt_temp4					; passed from output16dp macro, cleared by others.
	bcf		all_zeros_flag				; do not display any zero from here unless there was at least one figure /zero
	bsf		leading_zeros
	tstfsz	cvt_temp4					; display leading zeros at all?
	bcf		leading_zeros
	bsf		DP_done2
	tstfsz	cvt_temp4
	bcf		DP_done2					; decimal point not yet set
	movff	lo,cvt_temp_lo				; copy hi:lo to cvt_temp_hi:cvt_temp_lo
	movff	hi,cvt_temp_hi				; ...
	bcf		pre_zero_flag				; do not display leading zeros
	movlw	b'00010000'					; 10000s
	movwf	cvt_temp2
	movlw	b'00100111'
	movwf	cvt_temp3
	btfsc	show_last3					; display only last three figures?
	bra		output16_sk5
	btfsc	show_last4					; display only last four figures?
	bra		output16_sk5
	rcall	DEC2ASCII					; NO - show all, here: 5th order digit

output16_sk5:
	bcf		show_last4
	movlw	b'11101000'					; 1000s
	movwf	cvt_temp2
	movlw	b'00000011'
	movwf	cvt_temp3
	btfsc	DP_done2					; is there a decimal point at all?
	bra		output16_2					; NO - use normal display mode

	btfsc	all_zeros_flag				; display any zero from here
	bra		output16_1					; there was a figure /zero already

	bsf		pre_zero_flag				; display figure if zero?
	decfsz	cvt_temp4,W
	bcf		pre_zero_flag				; NO

output16_1:
	btfsc	DP_done						; decimal point set already?
	bsf		pre_zero_flag				; YES - so display the rest
output16_2:
	btfss	show_last3					; display only last three figures?
	rcall	DEC2ASCII					; NO  - show all. Here: 4th order digit
	bcf		show_last3					; YES - so display the rest
	movlw	b'01100100'					; 100s
	movwf	cvt_temp2
	clrf	cvt_temp3
	btfsc	ignore_digit3				; ignore 3rd-5th digit?
	bra		output16_5					; YES - skip the rest
	btfsc	DP_done2					; is there a decimal point at all?
	bra		output16_3					; NO  - use normal display mode
	btfsc	all_zeros_flag				; display any zero from here
	bra		output16_2_1				; there was a figure /zero already
	bsf		pre_zero_flag				; display figure if zero?
	decfsz	cvt_temp4,W
	bcf		pre_zero_flag				; NO

output16_2_1:
	btfsc	DP_done						; decimal point set already?
	bsf		pre_zero_flag				; YES - so display the rest
	btfsc	DP_done2					; is there a decimal point at all?
	bsf		pre_zero_flag				; NO  - so display the rest
output16_3:
	rcall	DEC2ASCII					; 3th order digit...
	movlw	b'00001010'					; 10s
	movwf	cvt_temp2
	clrf	cvt_temp3
	btfsc	DP_done2
	bra		output16_4
	btfsc	all_zeros_flag				; display any zero from here
	bra		output16_3_1				; there was a figure /zero already
	bsf		pre_zero_flag
	decfsz	cvt_temp4,W
	bcf		pre_zero_flag

output16_3_1:
	btfsc	DP_done
	bsf		pre_zero_flag
	btfsc	DP_done2
	bsf		pre_zero_flag
output16_4:
	btfsc	ignore_digit4				; ignore 4-5th digit?
	bra		output16_5					; YES - skip the rest
	rcall	DEC2ASCII					; 2nd order digit

	movlw	b'00000001'					; 1s
	movwf	cvt_temp2
	clrf	cvt_temp3
	bsf		pre_zero_flag
	btfss	ignore_digit5				; ignore 5th digit?
	rcall	DEC2ASCII					; 1st order digit
	bcf		ignore_digit5				; YES - clear flag
output16_5:
	bcf		ignore_digit4				; clear flag
	bcf		ignore_digit3				; clear flag
	clrf	ignore_digits
	incf	ignore_digits,F
	bcf		DP_done
	return								; done with convert.asm...


DEC2ASCII:
	clrf	cvt_temp1					; converts into ASCII code
DEC2ASCII_2:
	movf	cvt_temp3,W
	subwf	cvt_temp_hi,W
	btfss	STATUS,C
	bra		DEC2ASCII_4
	bnz		DEC2ASCII_3
	movf	cvt_temp2,W
	subwf	cvt_temp_lo,W
	btfss	STATUS,C
	bra		DEC2ASCII_4
DEC2ASCII_3:
	movf	cvt_temp3,W
	subwf	cvt_temp_hi,F
	movf	cvt_temp2,W
	subwf	cvt_temp_lo,F
	btfss	STATUS,C
	decf	cvt_temp_hi,F
	incf	cvt_temp1,F
	bsf		pre_zero_flag
	bra		DEC2ASCII_2
DEC2ASCII_4:
	decfsz	ignore_digits,F
	return
	incf	ignore_digits,F				; so ignore_digits stays zero for the test above
	movlw	'0'							; offset for ASCII-value
	addwf	cvt_temp1,W
	btfsc	pre_zero_flag				; is this a leading zero?
	bra		DEC2ASCII_4_1				; NO
	btfsc	leftbind
	bra		DEC2ASCII_6
	movlw	' '							; instead of leading zeros a space!
	bra		DEC2ASCII_5
DEC2ASCII_4_1:
	bsf		all_zeros_flag				; display any zero from here
DEC2ASCII_5:
	movwf	POSTINC2
DEC2ASCII_6:
	decfsz	cvt_temp4,F					; set decimal point?
	RETURN								; NO
	movlw	"."							; YES
	movwf	POSTINC2
	bsf		DP_done
	return


	global	outputHEX_call
outputHEX_call:							; coverts 8 Bit integer into two hex digits
	movwf	cvt_temp1					; copy byte to process from WREG to local temp
	swapf	cvt_temp1,F					; swap nibbles to process upper nibble first
	rcall	outputHEX_nibble			; print nibble as ASCII
	swapf	cvt_temp1,F					; swap back to process lower nibble
outputHEX_nibble:
	movff	cvt_temp1,cvt_temp2			; create a working copy
	movlw	0x0F						; mask for lower nibble
	andwf	cvt_temp2,F					; isolate lower nibble
	movlw	0x30						; offset from binary 0 to ASCII code for "0"
	addwf	cvt_temp2,F					; add offset
	movlw	0x39						; ASCII code for "9"
	cpfsgt	cvt_temp2					; character code in cvt_temp2 pointing to something after "9"?
	bra		outputHEX_1					; NO  - character code represents "0"..."9", can be printed
	movlw	0x07						; YES - offset from ASCII code for character after "9" to character "A"
	addwf	cvt_temp2,F					;     - add offset, character code now represents "A"..."F", can be printed now
outputHEX_1:
	movff	cvt_temp2,POSTINC2			; copy character code to output buffer
	return


	END
