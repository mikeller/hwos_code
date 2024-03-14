;=============================================================================
;
;   File rtc.asm                            * combined next generation V3.09.4k
;
;
;   Copyright (c) 2011, JD Gascuel, heinrichs weikamp gmbh, all right reserved.
;=============================================================================
; HISTORY
;  2011-08-08 : [mH] moving from OSTC code

#include "hwos.inc"
#include "math.inc"
#include "convert.inc"


;=============================================================================
rtc1	CODE
;=============================================================================


;-----------------------------------------------------------------------------
; Initialize RTC to Firmware creation Date
;
	global	rtc_init
rtc_init:
	banksel	isr_backup				; select bank ISR data
	movlw	.0						; reset time to 12:00:00
	movwf	rtc_latched_secs		; ...
	movlw	.0						; ...
	movwf	rtc_latched_mins		; ...
	movlw	.12						; ...
	movwf	rtc_latched_hour		; ...
	movlw	firmware_creation_day	; reset date to firmware creation date
	movwf	rtc_latched_day			; ...
	movlw	firmware_creation_month	; ...
	movwf	rtc_latched_month		; ...
	movlw	firmware_creation_year	; ...
	movwf	rtc_latched_year		; ...
	;bra	rtc_set_rtc				; set the real time clock


;-----------------------------------------------------------------------------
; Set new Time & Date
;
	global	rtc_set_rtc
rtc_set_rtc:
	banksel	isr_backup				; select bank ISR data
	movlw	d'24'					; safeguard hour
	cpfslt	rtc_latched_hour		; hour < 24 ?
	clrf	rtc_latched_hour		; NO - reset to 0
	movlw	d'60'					; safeguard minutes and seconds
	cpfslt	rtc_latched_mins		; minute < 60 ?
	clrf	rtc_latched_mins		; NO - reset to 0
	cpfslt	rtc_latched_secs		; seconds < 60 ?
	clrf	rtc_latched_secs		; NO - reset to 0
	movlw	d'100'					; safeguard year
	cpfslt	rtc_latched_year		; year < 100 ?
	clrf	rtc_latched_year		; NO - reset to 0
	movlw	d'12'					; safeguard month
	cpfslt	rtc_latched_month		; month < 12 ?
	movwf	rtc_latched_month		; NO - clip at 12

	rcall	rtc_check_day			; safeguard day
	bsf		block_rtc_access		; suspend the ISR from accessing the RTC

	banksel	0xF16					; addresses F16h through F5Fh are also used by SFRs, but are not part of the access RAM

	movlw	0x55					; | unlock sequence for RTCWREN, EECON2 is located in the access RAM
	movwf	EECON2					; |
	movlw	0xAA					; |
	movwf	EECON2					; |
	bsf		RTCCFG,RTCWREN			; | RTC write unlock, must follow directly after above unlock sequence!
	bsf		RTCCFG,RTCPTR1			; |
	bsf		RTCCFG,RTCPTR0			; |
	movff	rtc_latched_year,WREG	; get year
	rcall	rtc_dec2bcd				; IN: WREG in decimal, OUT: WREG in BCD, also sets to bank16h!
	movwf	RTCVALL					; write year
	movwf	RTCVALH					; dummy write
	movff	rtc_latched_day,WREG	; get day
	rcall	rtc_dec2bcd				; IN: WREG in decimal, OUT: WREG in BCD, also sets to bank16h!
	movwf	RTCVALL					; write day
	movff	rtc_latched_month,WREG	; get month
	rcall	rtc_dec2bcd				; IN: WREG in decimal, OUT: WREG in BCD, also sets to bank16h!
	movwf	RTCVALH					; write month
	movff	rtc_latched_hour,WREG	; get  hour
	rcall	rtc_dec2bcd				; IN: WREG in decimal, OUT: WREG in BCD, also sets to bank16h!
	movwf	RTCVALL					; write hour
	movlw	d'0'					; set weekday to 0 (unused)
	rcall	rtc_dec2bcd				; IN: WREG in decimal, OUT: WREG in BCD, also sets to bank16h!
	movwf	RTCVALH					; (dummy) write weekday
	movff	rtc_latched_secs,WREG	; get seconds
	rcall	rtc_dec2bcd				; IN: WREG in decimal, OUT: WREG in BCD, also sets to bank16h!
	movwf	RTCVALL					; write seconds
	movff	rtc_latched_mins,WREG	; get minutes
	rcall	rtc_dec2bcd				; IN: WREG in decimal, OUT: WREG in BCD, also sets to bank16h!
	movwf	RTCVALH					; write minutes

	movlw	0x55					; | probably not needed when clearing RTCWREN
	movwf	EECON2					; |
	movlw	0xAA					; |
	movwf	EECON2					; |
	bcf		RTCCFG,RTCWREN			; lock sequence for RTCWREN

	banksel	common					; back to bank common

	; update the "live" RTC variables to bridge the time until the ISR reads the updated data from the RTC
	movff	rtc_latched_year, rtc_year
	movff	rtc_latched_month,rtc_month
	movff	rtc_latched_day,  rtc_day
	movff	rtc_latched_hour, rtc_hour
	movff	rtc_latched_mins, rtc_mins
	movff	rtc_latched_secs, rtc_secs

	bcf		block_rtc_access		; allow the ISR to access the RTC again
	return							; done


;-----------------------------------------------------------------------------
; Helper Function - convert from decimal to BCD
;
rtc_dec2bcd:
	banksel	common					; switch to bank common
	movwf	lo						; input in decimal
	setf	hi						; 10s
rtc_dec2bcd2:
	incf	hi,F					; count 10's
	movlw	d'10'					; ...
	subwf	lo,F					; ...
	btfss	STATUS,N				; result negative?
	bra		rtc_dec2bcd2			; NO  - loop
	movlw	d'10'					; YES - 
	addwf	lo,F					;     - 1s
	swapf	hi,W					;     - swap to bit 7-4 -> WREG
	addwf	lo,W					;     - result in BCD
	banksel	0xF16					;     - switch back to bank for I/O registers
	return							;     - done


;-----------------------------------------------------------------------------
; Helper Function - check Validity of Day according to Month
;
; wrap-around the month depending on the number of days per month
;
; Attention: needs to be called in bank isr_backup!
;
rtc_check_day:
	movlw	.28						; the default February has 28 days
	btfsc	rtc_latched_year,0		; is the year an even year?
	bra		rtc_check_day_1			; NO  - keep the 28 days
	btfss	rtc_latched_year,1		; YES - is it a multiple of 4 years?
	movlw	.29						;       YES - leap year, February has 29 days
rtc_check_day_1:
	movwf	backup_hi				; store highest day in February in backup_hi
	decf	rtc_latched_month,W		; compute month - 1 and...
	movwf	backup_lo				; store result in backup_lo
	movlw	.31						; default highest day is 31
	dcfsnz	backup_lo,F				; month = February?
	movf	backup_hi,W				; YES - highest day is 28/29
	dcfsnz	backup_lo,F				; month = March?
	movlw	.31						; YES - highest day is 31
	dcfsnz	backup_lo,F				; month = April?
	movlw	.30						; YES - highest day is 30
	dcfsnz	backup_lo,F				; month = May?
	movlw	.31						; YES - highest day is 31
	dcfsnz	backup_lo,F				; month = June?
	movlw	.30						; YES - highest day is 30
	dcfsnz	backup_lo,F				; month = July?
	movlw	.31						; YES - highest day is 31
	dcfsnz	backup_lo,F				; month = August?
	movlw	.31						; YES - highest day = 31
	dcfsnz	backup_lo,F				; month = September?
	movlw	.30						; YES - highest day = 30
	dcfsnz	backup_lo,F				; month = October?
	movlw	.31						; YES - highest day = 31
	dcfsnz	backup_lo,F				; month = November?
	movlw	.30						; YES - highest day = 30
	dcfsnz	backup_lo,F				; month = December?
	movlw	.31						; YES - highest day = 31
	cpfsgt	rtc_latched_day			; current day > highest day?
	retlw	.1						; NO  - done, signal day was ok
	movlw	.1						; YES - wrap around to 1st day in month
	movwf	rtc_latched_day			;     - ...
	retlw	.0						;     - done, signal a correction was made


;=============================================================================
rtc2	CODE
;=============================================================================

;-----------------------------------------------------------------------------
; Add minutes in mpr:2 to the time/date in in rtc_latched and rounds up/down
; to next full minute
;
; Attention:
; This code works for a maximum of 1439 minutes to add (23 hours, 59 minutes)!
;
	global	rtc_add_minutes
rtc_add_minutes:
	call	convert_time			; convert minutes in hi:lo to hours (up:hi) and minutes (lo)
	banksel	isr_backup				; switch to bank isr_backup
	bcf		STATUS,C				; clear carry bit
	movlw	.30						; rounding point for seconds
	cpfslt	rtc_latched_secs		; seconds < rounding point?
	bsf		STATUS,C				; NO - set carry bit -> round up to next full minute
	clrf	rtc_latched_secs		; set the second to zero
	movff	lo,WREG					; get minutes to add
	addwfc	rtc_latched_mins,F		; add minutes to add
	movlw	.59						; limit for minute
	cpfsgt	rtc_latched_mins		; resulting minute > 59 ?
	bra		rtc_add_minutes_1		; NO  - minute is ok
	movlw	.60						; YES - subtract 60 from resulting minute
	subwf	rtc_latched_mins,F		;     - ...
	bsf		STATUS,C				;     - set carry bit
rtc_add_minutes_1:
	movff	hi,WREG					; get hours to add
	addwfc	rtc_latched_hour,F		; add hours to add plus carry bit
	movlw	.23						; limit for hour
	cpfsgt	rtc_latched_hour		; resulting hour > 23 ?
	bra		rtc_add_minutes_2		; NO  - hour is ok
	movlw	.24						; YES - subtract 24 from resulting hour
	subwf	rtc_latched_hour		;     - ...
	bsf		STATUS,C				;     - set carry bit
rtc_add_minutes_2:
	clrf	WREG					; create a zero
	addwfc	rtc_latched_day,F		; add the carry bit
	call	rtc_check_day			; check & correct the resulting day with respect to #days in month
	tstfsz	WREG					; was the day beyond the last day of the month before correction?
	bra		rtc_add_minutes_3		; NO  - done
	banksel	isr_backup				; YES - select bank isr_backup again
	incf	rtc_latched_month,F		;     - increment month
	movlw	.12						;     - limit for month
	cpfsgt	rtc_latched_month		;     - resulting month > 12 ?
	bra		rtc_add_minutes_3		;       NO  - month is ok
	subwf	rtc_latched_month,F		;       YES - subtract 12 from resulting month (actually sets back to January)
	incf	rtc_latched_year,F		;           - increment year
rtc_add_minutes_3:
	banksel	common					; back to bank common
	return							; done

;-----------------------------------------------------------------------------

	END
