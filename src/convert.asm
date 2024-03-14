;=============================================================================
;
;   File convert.asm                          combined next generation V3.09.4l
;
;   Converts register values to string
;
;   Copyright (c) 2011, Matthias Heinrichs, heinrichs weikamp gmbh, all right reserved.
;=============================================================================
; HISTORY
;   2007-10-07 : [MH]  Creation for OSTC sources
;   2010-12-10 : [jDG] Optimize macro size
;

#include "hwos.inc"
#include "math.inc"
#include "strings.inc"


;=============================================================================
convert1	CODE
;=============================================================================


;-----------------------------------------------------------------------------
; Print last two Digits or double-dots if zero - big Font
;
	global	output99DD_call
output99DD_call:
	tstfsz	lo							; value = 0 ?
	bra		output99_call				; NO  - do normal output
	movlw	" "							; YES - print a space
	movwf	POSTINC2					;     - ...
	bra		print_doubledots			;     - continue printing two dots


;-----------------------------------------------------------------------------
; Print last two Digits or double-dots if zero - small Font
;
	global	output99dd_call
output99dd_call:
	tstfsz	lo							; value = 0 ?
	bra		output99_call				; NO  - do normal output
	bra		print_doubledots			; YES - continue printing two dots


;-----------------------------------------------------------------------------
; Helper Function - Print two Dots
;
print_doubledots:
	movlw	"."							; load a '.'
	movwf	POSTINC2					; print 1st dot
	movwf	POSTINC2					; print 2nd dot
	bra		output_common_finish		; clean-up and return


;-----------------------------------------------------------------------------
; Print last Digit from a 8 bit Integer (0-9)
;
	global	output9_call
output9_call:
	bsf		hide_digit2					; do not print digit 5, 4, 3 and 2
	bra		output8_common				; continue with common part


;-----------------------------------------------------------------------------
; Print only last two Digits from a 8 bit Integer, with leading zero (00-99)
;
	global	output99x_call
output99x_call:
	bsf		leading_zeros				; print leading zeros
	;bra	output99_call				; continue with output99_call


;-----------------------------------------------------------------------------
; Print last two Digits from a 8 bit Integer (0-99)
;
	global	output99_call
output99_call:
	bsf		hide_digit3					; do not print digit 5, 4 and 3
	;bra	output8_common				; continue with common part


;-----------------------------------------------------------------------------
; Print 8 bit Integer (0-255)
;
	global	output256_call
output256_call:
	;bra	output8_common				; continue with common part


;-----------------------------------------------------------------------------
; Helper Function - common Part for Printing 8 Bit Integers
;
output8_common:
	bcf		output_overflow				; clear overflow flag
	movff	lo,bin_lo					; copy value to show
	rcall	convert_bin8bcd				; compute bcd_hi (1 digit) and bcd_lo (2 digits)
	btfsc	hide_digit2					; shall hide digit 2 ?
	bsf		hide_digit3					; YES - hide digit 3 then, too
	bra		output_common_d3			; start printing with digit 3


;-----------------------------------------------------------------------------
; Print last four Digits from a 16 bit Value (0-9999)
;
	global	output9999_call
output9999_call:
	bsf		hide_digit5					; do not print digit 5
	bra		output16_common				; continue with common part


;-----------------------------------------------------------------------------
; Print last three Digits from a 16 bit Value (0-999)
;
	global	output999_call
output999_call:
	bsf		hide_digit4					; do not print digit 4 and 5
	;bra	output16_common				; continue with common part


;-----------------------------------------------------------------------------
; Print a full 16 bit Value (0-65535)
;
	global	output65535_call
output65535_call:
	;bra	output16_common				; continue with common part


;-----------------------------------------------------------------------------
; Helper Function - common Part for Printing 16 Bit Integers
;
output16_common:
	bcf		output_overflow				; clear overflow flag
	movff	lo,bin_lo					; copy value to show
	movff	hi,bin_hi					; ...
	rcall	convert_bin16bcd			; compute bcd_up (1 digit), bcd_hi (2 digits) and bcd_lo (2 digits)
	btfsc	hide_digit2					; shall hide digit 2 ?
	bsf		hide_digit3					; YES - hide digit 3 then, too
	btfsc	hide_digit3					; shall hide digit 3 ?
	bsf		hide_digit4					; YES - hide digit 4 then, too
	btfsc	hide_digit4					; shall hide digit 4 ?
	bsf		hide_digit5					; YES - hide digit 5 then, too
	;bra	output_common_d5			; start printing with digit 5


;-----------------------------------------------------------------------------
; Helper Function - common Part for Printing 8 and 16 Bit Integers
;
output_common_d5:
	; digit 5
	btfss	hide_digit5					; shall hide digit 5 ?
	bra		output_common_d5p			; NO  - print digit 5
	movf	bcd_up,W					; YES - get lower nibble (digit 5) into WREG
	andlw	0x0F						;     - is it zero?
	bnz		print_9999					;       NO  - print '9999'
	bra		output_common_d4			;       YES - continue with digit 4
output_common_d5p:
	movf	bcd_up,W					; copy 5th digit to lower nibble of WREG
	rcall	print_digit					; print the digit

output_common_d4:
	; between digit 5 and 4
	btfsc	decimal_digit3				; shall print a decimal point in front of digit 3 ?
	bsf		leading_zeros				; YES - allow printing of zeros now

	; digit 4
	btfss	hide_digit4					; shall hide digit 4 ?
	bra		output_common_d4p			; NO  - print digit 4
	swapf	bcd_hi,W					; YES - get upper nibble (digit 4) into WREG
	andlw	0x0F						;     - is it zero?
	bnz		print_999					;       NO  - print '999'
	bra		output_common_d3			;       YES - continue with digit 3
output_common_d4p:
	swapf	bcd_hi,W					; copy 4th digit to lower nibble of WREG
	rcall	print_digit					; print the digit

output_common_d3:
	; between digit 4 and 3
	btfsc	decimal_digit3				; shall print a decimal point in front of digit 3 ?
	rcall	print_decimal				; YES - print a decimal pint now
	btfsc	decimal_digit2				; shall print a decimal point in front of digit 2 ?
	bsf		leading_zeros				; YES - allow printing of zeros now
	btfsc	omit_digit_2				; shall omit digits 2 and 1 ?
	bsf		leading_zeros				; YES - allow printing of zeros now

	; digit 3
	btfss	hide_digit3					; shall hide digit 3 ?
	bra		output_common_d3p			; NO  - print digit 3
	movf	bcd_hi,W					; YES - get lower nibble (digit 3) into WREG
	andlw	0x0F						;     - is it zero?
	bnz		print_99					;       NO  - print '99'
	bra		output_common_d2			;       YES - continue with digit 2
output_common_d3p:
	movf	bcd_hi,W					; copy 3rd digit to lower nibble of WREG
	rcall	print_digit					; print the digit

output_common_d2:
	; between digit 3 and 2
	btfsc	decimal_digit2				; shall print a decimal point in front of digit 2 ?
	rcall	print_decimal				; YES - print a decimal pint now
	btfsc	decimal_digit1				; shall print a decimal point in front of digit 1 ?
	bsf		leading_zeros				; YES - allow printing of zeros now
	btfsc	omit_digit_1				; shall omit digit 1 ?
	bsf		leading_zeros				; YES - allow printing of zeros now

	; digit 2
	btfss	hide_digit2					; shall hide digit 2 ?
	bra		output_common_d2p			; NO  - print digit 2
	swapf	bcd_lo,W					; YES - get upper nibble (digit 2) into WREG
	andlw	0x0F						;     - is it zero?
	bnz		print_9						;       NO  - print '9'
	bra		output_common_d1			;       YES - continue with digit 2
output_common_d2p:
	btfsc	omit_digit_2				; shall omit digit 2 ?
	bra		output_common_finish		; YES - finish output
	swapf	bcd_lo,W					; NO  - copy 2nd digit to lower nibble of WREG
	rcall	print_digit					;     - print the digit

output_common_d1:
	; between digit 2 and 1
	btfsc	decimal_digit1				; shall print a decimal point in front of digit 1 ?
	rcall	print_decimal				; YES - print a decimal pint now
	bsf		leading_zeros				; allow printing of zeros now

	; digit 1
	btfsc	omit_digit_1				; shall omit digit 1 ?
	bra		output_common_finish		; YES - finish output
	movf	bcd_lo,W					; NO  - copy 1st digit to lower nibble of WREG
	rcall	print_digit					;     - print the digit

output_common_finish:
	clrf	INDF2						; place a terminator at the current buffer position
	clrf	CVT_flags1					; clear output format command flags
	clrf	CVT_flags2					; ...
	return								; done


;-----------------------------------------------------------------------------
; Helper Function - print a Digit or a decimal Point
;
; Input:    lower nibble of WREG  BCD code of digit
;           leading_zeros         =1: print (leading) zeros
;           leftbind              =1: do not print leading spaces
;
print_digit:
	andlw	0x0F						; keep only the lower nibble, is it zero?
	bnz		print_digit_digit			; NO  - print in any case
	btfsc	leading_zeros				; YES - printing of zeros allowed?
	bra		print_digit_digit			;       YES - print a zero
	btfsc	leftbind					;       NO  - shall print left-aligned?
	return								;             YES - done
	movlw	' '							;             NO  - load ASCII code of a space char
	bra		print_digit_print			;                 - print it
print_digit_digit:
	bsf		leading_zeros				; allow printing of zeros now
	addlw	'0'							; add ASCII code of '0' to BCD code to get final ASCII code
print_digit_print:
	movwf	POSTINC2					; print the digit or char
	return								; done

print_decimal:
	movlw	'.'							; load ASCII code of a dot
	bra		print_digit_print			; print it


;-----------------------------------------------------------------------------
; Helper Function - print '9999' or '999' or '99' or '9'
;
print_9999:
	movlw	'9'							; load a '9' digit
	movwf	POSTINC2					; print digit 4
print_999:
	movlw	'9'							; load a '9' digit (for those embarked lately)
	movwf	POSTINC2					; print digit 3
print_99:
	movlw	'9'							; load a '9' digit (for those embarked lately)
	movwf	POSTINC2					; print digit 2
print_9:
	movlw	'9'							; load a '9' digit (for those embarked lately)
	movwf	POSTINC2					; print digit 1
	clrf	INDF2						; place a terminator at the current buffer position
	clrf	CVT_flags1					; clear output format command flags
	clrf	CVT_flags2					; ...
	bsf		output_overflow				; set overflow flag
	return								; done


;-----------------------------------------------------------------------------
; Convert an 8 Bit Integer to BCD
;
; Input:  bin_lo         8 bit integer
; Output: bcd_hi,bcd_lo  3 BCD digits
;
convert_bin8bcd:
	clrf	bcd_lo						; clear result variables
	clrf	bcd_hi						; ...
	bsf		bcd_hi,0					; set loop counter to 8
convert_bin8bcd_loop:
	; get MSB bit from binary
	rlcf	bin_lo,F					; shift-out MSB  to CARRY
	; lower two BCDs
	movf	bcd_lo,W					; get lower BCDs to WREG
	addwfc	bcd_lo,W					; WREG = 2 * WREG + CARRY
	daw									; decimal-adjust BCDs in WREG
	movwf	bcd_lo						; copy back WREG to lower BCDs
	; higher one BCD
	rlcf	bcd_hi						; higher BCD = 2*(higher BCD) + CARRY (special version for 1 BCD only)
	; loop control
	bnc		convert_bin8bcd_loop		; all 8 bits done? NO  -> loop
	return								;                  YES -> done


;-----------------------------------------------------------------------------
; Convert a 16 Bit Integer to BCD
;
; Input:  bin_hi,bin_lo         16 bit integer
; Output: bcd_up,bcd_hi,bcd_lo   5 BCD digits
;
convert_bin16bcd:
	clrf	bcd_lo						; clear result variables
	clrf	bcd_hi						; ...
	clrf	bcd_up						; ...
	movlw	.16							; 16 bits to do
	movwf	math_loop					; load loop counter
convert_bin16bcd_loop:
	; get MSB bit from binary
	rlcf	bin_lo,F					; shift-out MSB  to CARRY
	rlcf	bin_hi,F					; ...
	; lower two BCDs
	movf	bcd_lo,W					; get lower BCDs to WREG
	addwfc	bcd_lo,W					; WREG = 2 * WREG + CARRY
	daw									; decimal-adjust BCDs in WREG
	movwf	bcd_lo						; copy back WREG to lower BCDs
	; higher two BCDs
	movf	bcd_hi,W					; repeat for higher BCDs
	addwfc	bcd_hi,W					; ...
	daw									; ...
	movwf	bcd_hi						; ...
	; upper one BCD
;	movf	bcd_up,W					; repeat for upper BCD
;	addwfc	bcd_up,W					; ...
;	daw									; ...
;	movwf	bcd_up						; ...
	rlcf	bcd_up						; upper BCD = 2*(upper BCD) + CARRY (special version for 1 BCD only)
	; loop control
	decfsz	math_loop					; decrement bit counter, all done?
	bra		convert_bin16bcd_loop		; NO  - loop
	return								; YES - done


;=============================================================================
convert2	CODE
;=============================================================================


;-----------------------------------------------------------------------------
; Print Value in WREG as hex Number (00-FF)
;
	global	outputHEX_call
outputHEX_call:
	movwf	bin_lo						; make a backup
	swapf	WREG,W						; swap nibbles to process upper nibble first
	rcall	outputHEX_nibble			; print nibble as ASCII
	movf	bin_lo,W					; recall backup
outputHEX_nibble:
	andlw	0x0F						; isolate lower nibble
	addlw	+0x36						; add 0x36 so that numbers >= decimal 10 will become >= 0x40
	btfss	WREG,6						; WREG >= 0x40 ?
	addlw	-0x07						; NO - number is < 10, move back by offset between ASCII codes for 'A' and '9'
	addlw	+0x01						; make final common move forward to align with ASCII code
	movwf	POSTINC2					; write ASCII code to output buffer
	clrf	INDF2						; place a terminator at the current buffer position
	return								; done


;=============================================================================
convert3	CODE
;=============================================================================


;-----------------------------------------------------------------------------
; Convert signed 16 Bit to unsigned 16 Bit and put a '-' into the buffer if negative
;
; Input / Output: mpr:2
;
	global	convert_signed_16bit
convert_signed_16bit:
	bcf		neg_flag					; clear flag for negative number by default
	btfss	hi,7						; negative number?
	return								; NO  - done
	bsf		neg_flag					; YES - set flag for negative number
	comf	hi							;     - complement hi:lo
	negf	lo							;     - ...
	btfsc	STATUS,C					;     - ...
	incf	hi							;     - ...
	movlw	'-'							;     - print a minus sign
	movwf	POSTINC2					;     - ...
	return								;     - done


;=============================================================================
convert4	CODE
;=============================================================================


;-----------------------------------------------------------------------------
; Convert Pressure in [mbar] to Depth in [cm]
;
; Input:    mpr:2 pressure [mbar]
; Output:   mpr:2 depth    [cm]
; Destroys: up
;
	global	convert_pres_to_depth
convert_pres_to_depth:
	btfsc	sensor_override_active		; in pressure sensor override (simulator) mode?
	return								; YES - convert with factor 1.0, i.e. make [mbar] = [cm]

	movff	opt_salinity,WREG			; get salinity setting (0 - 4 %, see option_table.asm)
	addlw	d'100'						; add density of fresh water (1.00 kg/l)
	movwf	up							; store salinity factor in up

	movlw	.101+salinity_max			; load (upper limit + 1)
	cpfslt	up							; current setting > upper limit?
	bra		convert_fix_salinity		; YES - fix salinity setting

	movlw	.99+salinity_min			; load (lower limit - 1)
	cpfsgt	up							; current setting > lower limit?
	bra		convert_fix_salinity		; YES - fix salinity setting

convert_pres_to_depth_1:
	MOVII	mpr, xA						; get pressure in [mbar]
	MOVLI	.102,xB						; conversion factor x 100 for fresh water (1.02 cm per each 1 mbar)
	call	mult16x16					; xC:4 = xA:2 * xB:2
	movff	up,xB+0						; get salinity in [%]
	clrf	xB+1						; ...
	call	div32x16					; xC:4 = xC:4 / xB:2 with xA as remainder
	MOVII	xC,mpr						; copy back result as depth in [cm]
	return

convert_fix_salinity:
	movlw	.100						; reset to 100%, i.e. set salinity to 0%
	movwf	up							; fix value in up
	bra		convert_pres_to_depth_1		; continue


;=============================================================================
convert5	CODE
;=============================================================================


;-----------------------------------------------------------------------------
; Convert  Depth in [cm] to Depth in [feet]
;
; Input:  mpr:2  depth in [cm]
; Output: mpr:2  depth in [ft]
;
	global	convert_cm_to_feet
convert_cm_to_feet:
	MOVII	mpr, xA						; depth in [cm]
	btfsc	sensor_override_active		; in pressure sensor override (simulator) mode?
	bra		convert_meter_to_feet_1		; YES - convert with 334feet/100m
	MOVLI	.328,xB						; NO  - convert with 328feet/100m
	bra		convert_common_to_feet		;     - continue with common part


;-----------------------------------------------------------------------------
; Convert  Depth in [m] to Depth in [feet]
;
; Input:  lo     depth in [m]
; Output: mpr:2  depth in [ft]
;
	global	convert_meter_to_feet
convert_meter_to_feet:
	movf	lo,W						; depth in [m]
	mullw	.100						; factor to convert [m] to [cm]
	MOVII	PRODL,xA					; copy depth in [cm] to xA
convert_meter_to_feet_1:
	MOVLI	.334, xB					; convert with 334feet/100m to have 10ft, 20ft, 30ft, ... for stop depths
	;bra	convert_common_to_feet		; continue with common part


;-----------------------------------------------------------------------------
; Helper Function to convert_cm_to_feet and convert_meter_to_feet
;
convert_common_to_feet:
	call	mult16x16					; xC = xA * xB = depth in [cm] * 334 feet/100 m = depth in 0.0001 feet
	MOVLI	.10000,xB					; divide by 10000 to turn into full feet
	call	div32x16					; xC = xC / xB with xA as remainder
	MOVII	xC,mpr						; store result
	return								; done


;=============================================================================
convert6	CODE
;=============================================================================


;-----------------------------------------------------------------------------
; Convert Temperature in Celsius to Fahrenheit
;
; Input:  mpr:2  temperature in [0.1 °C]
; Output: mpr:2  temperature in [0.1 °F]
;
	global	convert_celsius_to_fahrenheit
convert_celsius_to_fahrenheit:
	MOVII	mpr,xA					; temperature in 1/10 of °C
	ADDLI	.1000,xA				; add offset of 1000 to get out of any negative numbers
									; adjust scaling: 1°C = 1.8°F:
	MOVLI	.18,xB					; multiply with 18:
	call	mult16x16				; ...
	MOVLI	.10,xB					; divide by 10
	call	div32x16				; ...
	SUBLI	.1480,xC				; subtract above offset (1000 * 1.8 = 1800) and add Fahrenheit-Offset (32 * 10 = 320) => subtract 1480
	MOVII	xC,mpr					; store result in mpr:2
	return							; done


;=============================================================================
convert7	CODE
;=============================================================================


;-----------------------------------------------------------------------------
; Convert Minutes to Hours and Minutes  / Seconds to Minutes and Seconds
;
; Input:   hi:lo  minutes  /  seconds
; Output:  up:hi  hours    /  minutes 
;             lo  minutes  /  seconds
;
; trashes xA, xB, xC
;
	global	convert_time
convert_time:
	movff	lo,xA+0					; copy hi:lo to xA
	movff	hi,xA+1					; ...
	movlw	d'60'					; set divisor to 60
	movwf	xB+0					; write 60 to xB
	clrf	xB+1					; ...
	call	div16x16				; xC = xA / xB with xA as remainder
	movff	xC+1,up					; result    is hours   / minutes, copy to up (high byte)
	movff	xC+0,hi					; result    is hours   / minutes, copy to hi (low  byte)
	movff	xA+0,lo					; remainder is minutes / seconds, copy to lo
	return							; done


;=============================================================================
convert8	CODE
;=============================================================================


;-----------------------------------------------------------------------------
; Print full Date
;
; Input:     lo  year
;            hi  month
;            up  day
;
; Output format depends on value of option opt_dateformat:
;         0: MM.DD.YY
;         1: DD.MM.YY
;         2: YY.MM.DD
;
; Destroyed: hy
;
	global	output_date
output_date:
	movff	opt_dateformat,EEDATA	; get format (EEDATA used as temp here)
	tstfsz	EEDATA					; shall use format 0 ?
	bra		TFT_convert_date_1		; NO  - check for format 1 or 2
									; YES - use format 0: MM.DD.YY
	movff	lo,hy					;     - backup year  to hy
	movff	hi,lo					;     - copy   month to lo
	movff	up,hi					;     - copy   day   to hi
	movff	hy,up					;     - copy   year  to up
	bra		TFT_convert_date_common	;     - start output
TFT_convert_date_1:
	decfsz	EEDATA,F				; shall use format 1 ?
	bra		TFT_convert_date_common	; NO  - use format 2: YY.MM.DD - can print directly
									; YES - use format 1: DD.MM.YY
	movff	lo,hy					;     - backup year to hy
	movff	up,lo					;     - copy day    to lo
	movff	hy,up					;     - copy year   to up

TFT_convert_date_common:
	call	output99x_call			; print lo (00-99)
	PUTC	'.'						; print spacing dot
	movff	hi,lo					; print hi (00-99)
	call	output99x_call			; ...
	PUTC	'.'						; print spacing dot
	movff	up,lo					; print up (00-99)
	call	output99x_call			; ...
	return							; done


;=============================================================================
convert9	CODE
;=============================================================================


;-----------------------------------------------------------------------------
; Print Date by Month & Day
;
; Input:     hi  month
;            up  day
;
; Output format depends on value of option opt_dateformat:
;         0: MM.DD
;         1: DD.MM
;         2: MM.DD
;
; Destroyed: lo
;
	global	output_date_short
output_date_short:
	movff	opt_dateformat,EEDATA	; get format (EEDATA used as temp here)
	tstfsz	EEDATA					; shall use format 0 ?
	bra		TFT_convert_date_short2	; NO  - check for format 1 or 2
TFT_convert_date_short1:			; YES - use format 0: MMDD
	movff	hi,lo					;     - copy month to lo
	movff	up,hi					;     - copy day   to hi
	bra		TFT_convert_date_short3 ;     - start output
TFT_convert_date_short2:
	decfsz	EEDATA,F				; format 1 ?
	bra		TFT_convert_date_short1	; NO  - use format 2: MMDD (here its like format 0)
									; YES - use format 1: DDMM
	movff	up,lo					;     - copy day to lo,
									;     - month is already in hi
TFT_convert_date_short3:
	call	output99x_call			; print lo (00-99)
	PUTC	'.'						; print spacing dot
	movff	hi,lo					; print hi (00-99)
	call	output99x_call			; ...
	return							; done


;=============================================================================
convert10	CODE
;=============================================================================


	global	output_secs_as_days_hours
output_secs_as_days_hours:
	MOVLI	.3600,xB						; one hour = 3600s
	call	div32x16						; xC:4 = xC:4 / xB:2 with xA as remainder -> xC+1:xC+0 holds full hours
	MOVII	xC, xA							; transfer result to xA
	MOVLI	.24,xB							; one day = 24 hours
	call	div16x16						; xC:2 = xA:2 / xB:2 with xA as remainder -> xC+1:xC+0 holds full days, xA holds full hours
	MOVII	xC,mpr							; copy full days into hi:lo
	call	output99_call					; print days (0-99)
	PUTC	"d"								; append unit
	movff	xA+0,lo							; get   full hours
	call	output99x_call					; print full hours (00-99)
	PUTC	"h"								; append unit
	return									; done


;-----------------------------------------------------------------------------

	END
