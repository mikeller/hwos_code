;=============================================================================
;
;   File mcp.asm                            * combined next generation V3.06.1
;
;   Basic routines for RX circuity
;
;   Copyright (c) 2012, JD Gascuel, heinrichs weikamp gmbh, all right reserved.
;=============================================================================
; HISTORY
;  2012-08-12 : [mH] Creation


#include "hwos.inc"
#include "wait.inc"


;=============================================================================
mcp		code
;=============================================================================


;-----------------------------------------------------------------------------
; Disable IR Receiver
;
	global	mcp_sleep
mcp_sleep:
	bcf		INTCON3,INT3IE			; disable INT3
	bcf		mcp_power				; power down IR receiver
;	btfsc	mcp_power				; power drained down?
;	bra		$-6						; NO  - loop waiting
	return							; YES - done

;-----------------------------------------------------------------------------

	END
