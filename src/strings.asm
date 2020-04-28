;=============================================================================
;
;   File strings.asm                        * combined next generation V3.09.4l
;
;   Implementation code various string functions.
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;  2010-12-02 : [jDG] Creation
;
; See strings.inc for doc and public calling macros.

#include "hwos.inc"
#include "varargs.inc"

	extern	aa_wordprocessor
	extern	text_1_base
	extern	text_1_text

 IF _language_2 != none
	extern	text_2_base
	extern	text_2_text
 ENDIF


;=============================================================================
strings		CODE
;=============================================================================

;-----------------------------------------------------------------------------
; to be used via Macro: Variants that call the Word Processor at the end
;-----------------------------------------------------------------------------

	global	strcpy_block_print
	global	strcat_block_print
strcpy_block_print:
	lfsr	FSR2,buffer				; load pointer to buffer
strcat_block_print:
	bsf		aa_aux_flag				; call Word Processor
	bra		strings_com_block_VARARG; continue with common part for VARARGS PROM texts


	global	strcpy_text_print
	global	strcat_text_print
strcpy_text_print:
	lfsr	FSR2,buffer				; load pointer to buffer
strcat_text_print:
	bsf		aa_aux_flag				; call Word Processor
	bra		strings_com_text_VARARG	; continue with common part for VARARGS multi-lingual texts


	global	putc_print
	global	print
putc_print:
	movwf	POSTINC2				; append the character to the string
print:
	bsf		aa_aux_flag				; call Word Processor
	bra		strings_common_term		; append string terminator


;-----------------------------------------------------------------------------
; to be used via Macro: Variants that do not call the Word Processor at end
;-----------------------------------------------------------------------------

	global	strcpy_block
	global	strcat_block
strcpy_block:
	lfsr	FSR2,buffer				; load pointer to buffer
strcat_block:
	bcf		aa_aux_flag				; do not call Word Processor
	bra		strings_com_block_VARARG; continue with common part for VARARGS PROM texts


	global	strcpy_text
	global	strcat_text
strcpy_text:
	lfsr	FSR2,buffer				; load pointer to buffer
strcat_text:
	bcf		aa_aux_flag				; do not call Word Processor
	bra		strings_com_text_VARARG	; continue with common part for VARARGS multi-lingual texts


	global	strcpy_text_FSR
	global	strcat_text_FSR
strcpy_text_FSR:
	lfsr	FSR2,buffer				; load pointer to buffer
strcat_text_FSR:
	bcf		aa_aux_flag				; do not call Word Processor
	bra		strings_com_text_FSR	; continue with common part for FSR multi-lingual texts


;-----------------------------------------------------------------------------
; Common Parts for all above Functions
;-----------------------------------------------------------------------------

strings_com_block_VARARG:
	VARARGS_BEGIN
		rcall	strcat_prom			; append text to buffer
		VARARGS_ALIGN				; word-align the table pointer
	VARARGS_END
	bra		strings_common_term		; continue with common part for all texts

strings_com_text_VARARG:
	VARARGS_BEGIN
		rcall	text_get_fsr		; get pointer to multi-lingual text
	VARARGS_END
	;bra	strings_com_text_FSR	; continue with common part for FSR multi-lingual texts

strings_com_text_FSR:
	rcall	text_get_tblptr			; get pointer to translated text
	rcall	strcat_prom				; append text to buffer
	;bra	strings_common_term		; continue with common part for all texts

strings_common_term:
	clrf	INDF2					; append string terminator
	btfss	aa_aux_flag				; shall call the Word Processor?
	return							; NO  - done
	goto	aa_wordprocessor		; YES - dump buffer to screen and return


;-----------------------------------------------------------------------------
; Helper Function - get Pointer to multi-lingual Text into FSR1
;
text_get_fsr:
	tblrd*+							; get pointer, low  byte
	movff	TABLAT,FSR1L			; store in FSR1L
	tblrd*+							; get pointer, low  byte
	movff	TABLAT,FSR1H			; store in FSR1H
	return							; done


;-----------------------------------------------------------------------------
; Helper Function - get Pointer to translated Text into TBLPTR
;
; Input:   FSR1         = pointer to multi-lingual text
;          opt_language = selected language
; Output:  TBLPTR       = 24 bit PROM address							0x09000  /  0x09400 -> problem
;																		0x07000  /  0x07400 -> ok
text_get_tblptr:
	; load TBLPTR with the index address of the selected text, expanded from 12 to 24 bit
	movlw	UPPER(text_1_base)		; get address, upper byte  = 0x00 of   index base
	movwf	TBLPTRU					; set TBLPTR,  upper byte to 0x00
	movlw	HIGH(text_1_base)		; get address, high  byte  = 0x90 of   index base
	iorwf	FSR1H,W					; add address, high  byte  = 0x0H from FSR1H
	movwf	TBLPTRH					; set TBLPTR,  high  byte to 0x9H
	movff	FSR1L,TBLPTRL			; set TBLPTR,  low   byte to 0xLL from FSR1L

 IF _language_2 != none
	; adjust the index address in case language 2 is selected
	movff	opt_language,WREG		; get language selection
	tstfsz	WREG					; language 2 selected ?
	bsf		TBLPTRH,2				; YES - add offset (0x00400) between the index tables
 ENDIF

	; read the address of the translated text in 16 bit format
	tblrd*+							; read   low  byte and buffer it in WREG
	movff	TABLAT,WREG				; ...
	tblrd*+							; read   high byte and keep   it in TABLAT

	; load TBLPTR with the address of the translated text expanded to 24 bit
	movff	WREG,  TBLPTRL			; set TBLPTR,  low   byte
	movlw	UPPER(text_1_text)		; get address, upper byte of text table
 IF _language_2 != none
	btfsc	TBLPTRH,2				; using language 2?
	movlw	UPPER(text_2_text)		; YES - get upper address of language 2
 ENDIF
	movwf	TBLPTRU					; set TBLPTR,  upper byte
	movff	TABLAT,TBLPTRH			; set TBLPTR,  high  byte

	return							; done


;-----------------------------------------------------------------------------
; Helper Function - append a null-terminated String from TBLPTR to Buffer
;
; Input:   TBLPTR : string pointer into PROM
;          FRS2   : current character position
; Output:  string in buffer, FSR2 pointing to the closing null byte
;
strcat_prom:
	tblrd*+							; read one character from PROM
	movf	TABLAT,W				; copy character to WREG
	movwf	POSTINC2				; copy from WREG to buffer and increment buffer pointer
									; was character = NULL ?
	bnz		strcat_prom				; NO  - loop
	movf	POSTDEC2,W				; YES - dummy read to step back buffer pointer by 1
	return							;     - done


;-----------------------------------------------------------------------------
; to by used via Macro: set Font Size and Output Position in one Batch
;
	global	start_tiny_block
start_tiny_block:
	movlw	.0						; set size encoding
	bra		start_block_common		; start block

	global	start_small_block
start_small_block:
	movlw	.1						; set size encoding
	bra		start_block_common		; start block

	global	start_std_block
start_std_block:
	movlw	.2						; set size encoding
	bra		start_block_common		; start block

	global	start_medium_block
start_medium_block:
	movlw	.3						; set size encoding
	bra		start_block_common		; start block

	global	start_large_block
start_large_block:
	movlw	.4						; set size encoding
	bra		start_block_common		; start block

	global	start_huge_block
start_huge_block:
	movlw	.5						; set size encoding
	;bra	start_block_common		; start block

start_block_common:
	movff	WREG,font_size			; needs a bank-safe move here! (TODO: why?)

	VARARGS_BEGIN
		VARARGS_GET8	win_leftx2	; get horizontal position
		VARARGS_GET8	win_top		; get vertical position
	VARARGS_END

	lfsr	FSR2,buffer				; initialize output buffer
	return							; done

;-----------------------------------------------------------------------------

	END
