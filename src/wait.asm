;=============================================================================
;
;   File wait.asm														V2.98c
;
;   Wait routines
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;   2004-01-31 : [chsw] initial version
;   2007-05-11 : updated (OSTC code)
;   2011-10-18 : [mH] timings tested with oscilloscope

#include "hwos.inc"

wait		CODE


; ==========================================================
; WAIT 1 second (Warning: Do not use for time critical routines. Can be between 0 and 1 sec!)
; ==========================================================
	global	wait_1s
wait_1s:
	; Wait until "next second" flag is set
	bcf		onesecupdate
	btfss	onesecupdate
	bra		$-2
	return


; =============================================================================
; WAIT 1 MILLISECOND   (Not exact: 1,008ms +/- 30,5µs + worst case ISR latency)
; =============================================================================

	global	WAITMSX
WAITMSX:
	movwf	wait_counter
WAITMSX2:
	setf	TMR5H
	movlw	.255-.32 			; 32 x 31,5µs = 1,008ms
	movwf	TMR5L
	bcf		PIR5,TMR5IF			; clear flag
WAITMSX3:
	btfss	PIR5,TMR5IF
	bra		WAITMSX3			; wait loop
	decfsz	wait_counter,F
	bra		WAITMSX2
	return

;=============================================================================

	END