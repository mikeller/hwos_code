;=============================================================================
;
;   File strings.asm                          combined next generation V3.03.1
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

strings	CODE

;=============================================================================

; Variants that call word_processor at the end
	global	strcpy_block_print
	global	strcat_block_print
strcpy_block_print:
	lfsr	FSR2,buffer
strcat_block_print:
	bsf		aa_aux_flag				; print afterwards
	bra		strings_common

; Variants that do not call word_processor at end
	global	strcpy_block
	global	strcat_block
strcpy_block:
	lfsr	FSR2,buffer
strcat_block:
	bcf		aa_aux_flag				; do not print afterwards
	;bra	strings_common

; Common part: append the string from PROM return address
strings_common:
	VARARGS_BEGIN
		rcall	strcat_prom
		VARARGS_ALIGN
	VARARGS_END

	btfss	aa_aux_flag				; shall we print?
	return							; NO  - then return straight away
	goto	aa_wordprocessor		; YES - print it...


;=============================================================================
; Copy multi-lingual text from FSR1 12 bit pointer to buffer
;
; Input:   FSR1 = 12 bit pointer to multi-lingual text
; Output:  FSR2 pointing to closing null byte in buffer
; Trashed: TBLPTR, TABLAT

	global	strcpy_text
strcpy_text:
	rcall	text_get_tblptr
	bra		strcpy_prom

; Copy and print multi-lingual text from FSR1 12 bit pointer to buffer
;
; Input:   FSR1 = 12 bit pointer to multi-lingual text
; Output:  FSR2 pointing to closing null byte in buffer
; Trashed: TBLPTR, TABLAT

	global	strcpy_text_print
strcpy_text_print:
	rcall	text_get_tblptr
	bra		strcpy_prom_print

; Append multi-lingual text from FSR1 12 bit pointers to buffer at FRS2
;
; Input:   FSR1 = 12 bit pointer to multi-lingual text
;          FSR2 = current position in buffer
; Output:  FSR2 pointing to closing null byte in buffer
; Trashed: TBLPTR, TABLAT

	global	strcat_text
strcat_text:
	rcall	text_get_tblptr
	bra		strcat_prom

; Append and print multi-lingual text from FSR1 12 bit pointers to buffer at FRS2
;
; Input:   FSR1 = 12 bit pointer to multi-lingual text
;          FSR2 = current position in buffer
; Output:  FSR2 pointing to closing null byte in buffer
; Trashed: TBLPTR, TABLAT

	global	strcat_text_print
strcat_text_print:
	rcall	text_get_tblptr
	bra		strcat_prom_print

;=============================================================================
; Get pointer to multilingual text in TBLPTR
;
; Input:   FSR1         = 12 bit text handle
;          opt_language = current language
; Output:  TBLPTR       = 24 bit PROM address

	global	text_get_tblptr
text_get_tblptr:
	extern	text_1_base
	movlw	UPPER(text_1_base)		; complete 12 bit address to 24 bit address
	movwf	TBLPTRU
	movlw	HIGH(text_1_base)
	andlw	0xF0
	iorwf	FSR1H,W
	movwf	TBLPTRH
	movff	FSR1L,TBLPTRL

 IF _language_2!=none
	movff	opt_language,WREG		; get language selection
	bz		text_get_lang1			; 0: language 1
	dcfsnz	WREG
	bra		text_get_lang2			; 1: language 2
 ENDIF

text_get_lang1:						; read 2-byte pointer to string
	tblrd*+
	movff	TABLAT,WREG
	tblrd*+
	movff	WREG,TBLPTRL
	movff	TABLAT,TBLPTRH
	return

 IF _language_2!=none
text_get_lang2:						; add offset for second language
	extern	text_2_base
	movlw	LOW(text_2_base)
	addwf	TBLPTRL
	movlw	HIGH(text_2_base)
	addwfc	TBLPTRH
	movlw	UPPER(text_2_base)
	addwfc	TBLPTRU

	movlw	LOW(text_1_base)
	subwf	TBLPTRL
	movlw	HIGH(text_1_base)
	subwfb	TBLPTRH
	movlw	UPPER(text_1_base)
	subwfb	TBLPTRU
	bra		text_get_lang1
 ENDIF

;=============================================================================
; Copy a null-terminated string from TBLPTR to buffer
;
; Input:   TBLPTR : string pointer into PROM
; Output:  string in buffer, FSR2 pointing to the closing null byte
;
	global	strcpy_prom
strcpy_prom:
	lfsr	FSR2,buffer
	;bra	strcat_prom

; Append a null-terminated string from TBLPTR to buffer
;
; Input:   TBLPTR : string pointer into PROM
;          FRS2   : current character position
; Output:  string in buffer, FSR2 pointing to the closing null byte
;
	global	strcat_prom
strcat_prom:
	tblrd*+							; read a character from PROM
	movf	TABLAT,W				; transfer character to   WREG
	movwf	POSTINC2				; transfer character from WREG to output buffer and increment buffer pointer
	bnz		strcat_prom				; last character = NULL ? NO  - loop
	movf	POSTDEC2,W				;                         YES - step back one char
	return							;                             - done

;=============================================================================
; Variant that calls word processor right-away...

	global	strcpy_prom_print
	global	strcat_prom_print
strcpy_prom_print:
	lfsr	FSR2,buffer
strcat_prom_print:
	rcall	strcat_prom
	goto	aa_wordprocessor

;=============================================================================

	global	start_tiny_block
start_tiny_block:
	clrf	WREG
	bra		start_common

	global	start_small_block
start_small_block:
	movlw	1
	bra		start_common

	global	start_std_block
start_std_block:
	movlw	2
	bra		start_common

	global	start_medium_block
start_medium_block:
	movlw	3
	bra		start_common

	global	start_large_block
start_large_block:
	movlw	4
	bra		start_common

 IFDEF _huge_font
	global	start_huge_block
start_huge_block:
	movlw	5
	;bra	start_block_common
 ENDIF

start_common:
	movff	WREG,win_font			; needs a bank-safe move here !

	VARARGS_BEGIN
		VARARGS_GET8	win_leftx2
		VARARGS_GET8	win_top
	VARARGS_END
	lfsr	FSR2,buffer				; point to buffer
	return

	END