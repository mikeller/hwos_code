;=============================================================================
;
;    File varargs.inc                        * combined next generation V3.0.1
;
;    Utilities to pass multiple arguments in compact code stream.
;
;   Copyright (c) 2011, JD Gascuel, heinrichs weikamp gmbh, all right reserved.
;=============================================================================
; HISTORY
;  2011-05-27 : [jDG] Creation.
;


;-----------------------------------------------------------------------------
; Prepare reading inline Data: set Table Pointer to the Beginn of the inline Data
;
VARARGS_BEGIN macro
	movff	TOSL, TBLPTRL			; copy program counter address to table pointer
	movff	TOSH, TBLPTRH			; ...
	movff	TOSU, TBLPTRU			; ...
	endm


;-----------------------------------------------------------------------------
; Read 1 Byte of inline Data
;
VARARGS_GET8 macro  register
	tblrd*+							; read 1 byte from program memory
	movff	TABLAT, register		; store to register
	endm


;-----------------------------------------------------------------------------
; Read 2 Bytes of inline Data
;
VARARGS_GET16 macro register
	tblrd*+							; read 1st byte from program memory
	movff	TABLAT, register+0		; store to register
	tblrd*+							; read 2nd byte from program memory
	movff	TABLAT, register+1		; store to register
	endm


;-----------------------------------------------------------------------------
; Read 3 Bytes of inline Data
;
VARARGS_GET24 macro register
	tblrd*+							; read 1st byte from program memory
	movff	TABLAT, register+0		; store to register
	tblrd*+							; read 2nd byte from program memory
	movff	TABLAT, register+1		; store to register
	tblrd*+							; read 3rd byte from program memory
	movff	TABLAT, register+2		; store to register
	endm


;-----------------------------------------------------------------------------
; Align Table Pointer to an even Address
;
VARARGS_ALIGN macro
	btfsc	TBLPTRL,0				; table pointer pointing to an even address?
	tblrd*+							; NO  - do a dummy read to advance to next even address
	endm


;-----------------------------------------------------------------------------
; End reading inline Data: set Return Address behind End of the inline Data
;
VARARGS_END macro
	movf	TOSL,W					; compute how may inline bytes have been read
	subwf	TBLPTRL,W				; WREG = (TBLPTRL - TOSL) modulo 256
	addwf	TOSL,F					; advance the return address by this number
	movlw	0						; ...
	addwfc	TOSH,F					; ...
	addwfc	TOSU,F					; ...
	endm
