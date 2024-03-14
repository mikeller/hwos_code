;=============================================================================
;
;   File wait.asm                           * combined next generation V3.09.4
;
;   Wait routines
;
;   Copyright (c) 2011, JD Gascuel, heinrichs weikamp gmbh, all right reserved.
;=============================================================================
; HISTORY
;   2004-01-31 : [chsw] initial version
;   2007-05-11 : updated (OSTC code)
;   2011-10-18 : [mH] timings tested with oscilloscope

#include "hwos.inc"



;=============================================================================
wait1	CODE
;=============================================================================

;-----------------------------------------------------------------------------
; Wait 1 Second
; Warning: do not use for time critical routines - can be between 0 and 1 sec!
;
	global	wait_1s
wait_1s:
	bcf		trigger_full_second	; clear any left-over trigger
	btfss	trigger_full_second	; did a new trigger occurred?
	bra		$-2					; NO  - loop
	return						; YES - done


;=============================================================================
wait2	CODE
;=============================================================================

;-----------------------------------------------------------------------------
; Wait for a Multiple of 1 Second
; Warning: do not use for time critical routines - can be up to 1 sec longer!
;
	global	WAITSX
WAITSX:
	bcf		trigger_full_second	; clear any left-over trigger
	btfss	trigger_full_second	; did a new trigger occurred?
	bra		$-2					; NO  - loop
	decfsz	WREG,W				; YES - count down loop counter, became zero?
	bra		WAITSX				;       NO  - loop
	return						;       YES - done


;=============================================================================
wait3	CODE
;=============================================================================

;-----------------------------------------------------------------------------
; Wait for a Multiple of 1 Millisecond
; Remark: not exact: 1.008 ms +/- 30.5 µs + worst case ISR latency
;
	global	WAITMSX
WAITMSX:
	movwf	wait_counter		; store number of milliseconds to wait
WAITMSX2:
	setf	TMR5H				; initialize timer 5, high byte first
	movlw	.255-.32 			; 32 x 31.5 µs = 1.008 ms
	movwf	TMR5L				; initialize timer 5, low  byte thereafter
	bcf		PIR5,TMR5IF			; clear timer 5 overrun flag
WAITMSX3:
	btfss	PIR5,TMR5IF			; did timer 5 overrun?
	bra		WAITMSX3			; NO  - repeat inner loop
	decfsz	wait_counter,F		; YES - decrement number of milliseconds to do, done?
	bra		WAITMSX2			;       NO  - repeat outer loop
	return						;       YES - done

;-----------------------------------------------------------------------------

	END