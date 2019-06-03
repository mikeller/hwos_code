;=============================================================================
;
;   File rtc.asm                              combined next generation V3.02.1
;
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;  2011-08-08 : [mH] moving from OSTC code

#include "hwos.inc"
#include "math.inc"

rtc		CODE

;=============================================================================

	global	rtc_init
	global	rtc_set_rtc
rtc_init:
	banksel	isr_backup			; select bank ISR data
	movlw	.0
	movwf	rtc_latched_secs
	movlw	.0
	movwf	rtc_latched_mins
	movlw	.12
	movwf	rtc_latched_hour
	movlw	firmware_creation_day
	movwf	rtc_latched_day
	movlw	firmware_creation_month
	movwf	rtc_latched_month
	movlw	firmware_creation_year
	movwf	rtc_latched_year
rtc_set_rtc:
	banksel	isr_backup
	movlw	d'24'				; safeguard hour
	cpfslt	rtc_latched_hour
	clrf	rtc_latched_hour
	movlw	d'60'				; safeguard minutes
	cpfslt	rtc_latched_mins
	clrf	rtc_latched_mins
	movlw	d'60'				; safeguard seconds
	cpfslt	rtc_latched_secs
	clrf	rtc_latched_secs
	movlw	d'99'				; safeguard year
	cpfslt	rtc_latched_year
	movwf	rtc_latched_year
	movlw	d'12'				; safeguard month
	cpfslt	rtc_latched_month
	movwf	rtc_latched_month

	banksel	common				; select bank common
	rcall	rtc_check_day		; safeguard day
	bsf		block_rtc_access	; suspend the ISR from accessing the RTC


	banksel	0xF16				; addresses F16h through F5Fh are also used by SFRs, but are not part of the access RAM

	movlw	0x55				; | unlock sequence for RTCWREN, EECON2 is located in the access RAM
	movwf	EECON2				; |
	movlw	0xAA				; |
	movwf	EECON2				; |
	bsf		RTCCFG,RTCWREN		; RTC write unlock, must follow directly after above unlock sequence!
	bsf		RTCCFG,RTCPTR1
	bsf		RTCCFG,RTCPTR0
	movff	rtc_latched_year,WREG
	rcall	rtc_dec2bcd			; IN: WREG in decimal, OUT: WREG in BCD, also sets to bank16h!
	movwf	RTCVALL				; year
	movwf	RTCVALH				; dummy write
	movff	rtc_latched_day,WREG
	rcall	rtc_dec2bcd			; IN: WREG in decimal, OUT: WREG in BCD, also sets to bank16h!
	movwf	RTCVALL				; day
	movff	rtc_latched_month,WREG
	rcall	rtc_dec2bcd			; IN: WREG in decimal, OUT: WREG in BCD, also sets to bank16h!
	movwf	RTCVALH				; month
	movff	rtc_latched_hour,WREG
	rcall	rtc_dec2bcd			; IN: WREG in decimal, OUT: WREG in BCD, also sets to bank16h!
	movwf	RTCVALL				; hour
	movlw	d'0'
	rcall	rtc_dec2bcd			; IN: WREG in decimal, OUT: WREG in BCD, also sets to bank16h!
	movwf	RTCVALH				; weekday
	movff	rtc_latched_secs,WREG
	rcall	rtc_dec2bcd			; IN: WREG in decimal, OUT: WREG in BCD, also sets to bank16h!
	movwf	RTCVALL				; seconds
	movff	rtc_latched_mins,WREG
	rcall	rtc_dec2bcd			; IN: WREG in decimal, OUT: WREG in BCD, also sets to bank16h!
	movwf	RTCVALH				; minutes

	movlw	0x55				; | probably not needed when clearing RTCWREN
	movwf	EECON2				; |
	movlw	0xAA				; |
	movwf	EECON2				; |
	bcf		RTCCFG,RTCWREN		; lock sequence for RTCWREN

	banksel	common

	; update the "live" RTC variables to bridge the time until the ISR reads the updated data from the RTC
	movff	rtc_latched_year, rtc_year
	movff	rtc_latched_month,rtc_month
	movff	rtc_latched_day,  rtc_day
	movff	rtc_latched_hour, rtc_hour
	movff	rtc_latched_mins, rtc_mins
	movff	rtc_latched_secs, rtc_secs

	bcf		block_rtc_access	; allow the ISR to access the RTC again
	return


rtc_dec2bcd:
	banksel	common				; switch to bank common
	movwf	lo					; input in decimal
	setf	hi					; 10s
rtc_dec2bcd2:
	incf	hi,F				; count 10's
	movlw	d'10'
	subwf	lo,F
	btfss	STATUS,N
	bra		rtc_dec2bcd2
	movlw	d'10'
	addwf	lo,F				; 1s
	swapf	hi,W				; swap to bit 7-4 -> WREG
	addwf	lo,W				; result in BCD
	banksel	0xF16				; switch back to bank for I/O registers
	return

rtc_check_day:
	movlw	.28					; the default February has 28 days
	movff	rtc_latched_year,lo	; bank-safe get of the current year
	btfsc	lo,0				; is the current year an even year?
	bra		rtc_check_day_1		; NO
	btfss	lo,1				; YES - is it a multiple of 4 years?
	movlw	.29					;       YES - leap year, February has 29 days
rtc_check_day_1:				;       NO  - keep the 28 days
	movwf	hi					; store highest day in February in hi
	movff	rtc_latched_month,lo; bank-safe get of the current month
	dcfsnz	lo,F				; current month = January?
	movlw	.31					; YES - highest day is 31
	dcfsnz	lo,F				; current month = February?
	movf	hi,W				; YES - highest day is 28/29
	dcfsnz	lo,F				; current month = March?
	movlw	.31					; YES - highest day is 31
	dcfsnz	lo,F				; current month = April?
	movlw	.30					; YES - highest day is 30
	dcfsnz	lo,F				; current month = May?
	movlw	.31					; YES - highest day is 31
	dcfsnz	lo,F				; current month = June?
	movlw	.30					; YES - highest day is 30
	dcfsnz	lo,F				; current month = July?
	movlw	.31					; YES - highest day is 31
	dcfsnz	lo,F				; current month = August?
	movlw	.31					; YES - highest day = 31
	dcfsnz	lo,F				; current month = September?
	movlw	.30					; YES - highest day = 30
	dcfsnz	lo,F				; current month = October?
	movlw	.31					; YES - highest day = 31
	dcfsnz	lo,F				; current month = November?
	movlw	.30					; YES - highest day = 30
	dcfsnz	lo,F				; current month = December?
	movlw	.31					; YES - highest day = 31
	movff	rtc_latched_day,hi	; bank-safe get of the current day
	cpfsgt	hi					; current day > highest day?
	return						; NO  - day is ok
	movlw	.1					; YES - wrap around to 1st day in month
	movff	WREG,rtc_latched_day;     - bank-safe write-back of corrected day
	return						;     - done

	END
