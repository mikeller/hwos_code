;=============================================================================
;
;   File mcp.asm                              combined next generation V3.03.1
;
;   Basic routines for RX circuity
;
;   Copyright (c) 2012, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;  2012-08-12 : [mH] Creation


#include "hwos.inc"
#include "wait.inc"

mcp	code

;=============================================================================

 IFDEF _external_sensor

	global	mcp_sleep
mcp_sleep:
	bcf		INTCON3,INT3IE			; disable INT3
	bcf		mcp_power				; request IR receiver off
	btfsc	mcp_power				; off confirmed?
	bra		$-6						; NO  - loop waiting
	return							; YES - done

 ENDIF

;=============================================================================

	END
