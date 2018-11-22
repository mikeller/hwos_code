;=============================================================================
;
;   File isr.inc
;
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;  2011-08-06 : [mH] moving from OSTC code

SAFE_2BYTE_COPY MACRO from,to
	local	retry
retry:
	movff	from+1,WREG				; high byte in WREG, ...
	movff	WREG,to+1				; ... and destination
	movff	from+0,to+0				; copy low byte
	movff	from+1,TABLAT			; another bank-safe read
	xorwf	TABLAT,W				; did the high byte changed?
	bnz		retry					; YES - retry
	ENDM
