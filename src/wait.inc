;=============================================================================
;
;   File wait.asm                              combined next generation V3.0.1
;
;   Wait routines
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;   2004-01-31 : [chsw] Initial version
;   2007-05-11 : Updated (OSTC code)
;   2011-06-24 : [MH]  Added clock speeds

;=============================================================================

WAITMS	macro	ms_to_wait
	movlw	ms_to_wait
	extern	WAITMSX
	call	WAITMSX
	endm

	extern	wait_1s

; asm routines in hwos.asm
	extern	request_speed_eco			; SPEED_ECO:      1 MHz
	extern	request_speed_normal		; SPEED_NORMAL:  16 MHz
	extern	request_speed_fastest		; SPEED_FASTEST: 64 MHz on high voltage cores
										;                32 MHz on low  voltage core

