;=============================================================================
;
;    File text_multilang.inc                   combined next generation V3.0.1
;
;    Implementation of texts in various selectable languages
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;  2011-06-12 : [jDG] Creation
;
; Text definitions (text_french.asm example):
;	TCODE	tYes,	"Oui"					; Yes
;	TCODE	tNo,	"Non"					; No
;	TCODE	tLogbk,	"Carnet de plongées"	; Logbook
;
; Text direct usage:
;	lfsr	FSR1,tYes						; load a 12 bit text index
;	call	strcpy_text						; copy to string buffer
;	PUTC	'/'								; place a single character into the text buffer
;	lfsr	FSR1,tNo
;	call	strcat_text_print				; append next text and call word processor to output all text to the screen
;
; RATIONALS:
;  - The macro should define a label so that text files can be reordered
;    to keep consistency while adding more options (and make translator life easier).
;
;  - The text positions is keept in menu blocks for the menu processor.
;
;  - library function take text number from the FSR1 register, because a
;    lfsr instruction loads a 12 bit constant at once.
;
;=============================================================================

; Pass 1: generate a jump table and define labels
;
TCODE_1 macro label, text
tcode_idx set tcode_idx+1
	If LANG == 0
		global	label
label:
	Endif
	dw		t#v(LANG)_#v(tcode_idx)
	endm


; Pass 2: generates string table
;
TCODE_2 macro label, text
tcode_idx set tcode_idx+1
t#v(LANG)_#v(tcode_idx):
	db		text, 0
	endm


;=============================================================================
; strcpy_text : copy a multiling text into string buffer
;
; Input  : FSR1    text index
; Output : Buffer  filled with the text
;          FSR2    pointer to end of copied text (the null char)
; Trashed: WREG

	extern	strcpy_text


;=============================================================================
; strcpy_text_print : same as above, but calls word processor afterward
;
; Input  : FSR1    text index
; Output : Buffer  filled with the text.
;          FSR2    pointer to end of copied text (the null char)
; Trashed: WREG

	extern	strcpy_text_print


;=============================================================================
; strcat_text : append a multiling text to FSR2 pointer
;
; Input  : FSR1  text index
;          FSR2  current position (in buffer)
; Output : FSR2  pointer to end of copied text (the null char)
; Trashed: WREG

	extern	strcat_text


;=============================================================================
; strcat_text_print : aame as above, but calls word processor afterward
;
; Input  : FSR1  text index
;          FSR2  current position (in buffer)
; Output : FSR2  pointer to end of copied text (the null char)
; Trashed: WREG

	extern	strcat_text_print

