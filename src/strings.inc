;=============================================================================
;
;   File strings.inc                        * combined next generation V3.08.5
;
;   Implementation code various string functions
;
;   Copyright (c) 2011, JD Gascuel, heinrichs weikamp gmbh, all right reserved.
;=============================================================================
; HISTORY
;   2010-12-02 : [jDG] Creation
;


;-----------------------------------------------------------------------------
; Initialize the Buffer
;
INIT_BUFFER	macro
	lfsr	FSR2,buffer				; load FSR2 with base address of the buffer
	endm


;-----------------------------------------------------------------------------
; Re-Initialize the Buffer 
;
REINIT_BUFFER macro
	clrf	FSR2L					; reset the buffer pointer
	endm


;-----------------------------------------------------------------------------
; Font Size Selection
;
FONT_SIZE	macro	font_size_input
	movlw	font_size_input
	movwf	font_size
	endm


;-----------------------------------------------------------------------------
; Dump the Buffer to Screen
;
PRINT		macro
	extern	print
	call	print					; append terminator to buffer and print buffer
	endm


;-----------------------------------------------------------------------------
; Macros to print embedded (untranslated) Texts
;-----------------------------------------------------------------------------

;-----------------------------------------------------------------------------
; Copy an embedded (untranslated) Text to the Buffer
;
STRCPY		macro string
	extern	strcpy_block
	call	strcpy_block			; copy text to buffer
	DB		string, 0				; inline text with terminator
	endm


;-----------------------------------------------------------------------------
; Append an embedded (untranslated) Text to the Buffer
;
STRCAT		macro string
	extern	strcat_block
	call	strcat_block			; append text to buffer
	DB		string, 0				; inline text with terminator
	endm


;-----------------------------------------------------------------------------
; Append a single Character to the Buffer
;
PUTC		macro	char
	movlw	char					; get character into WREG
	movwf	POSTINC2				; append character to buffer
	endm


;-----------------------------------------------------------------------------
; Append a single Character to the Buffer and dump the Buffer to Screen
;
PUTC_PRINT	macro	char
	extern	putc_print
	movlw	char					; get character into WREG
	call	putc_print				; append charcator to buffer and print whole buffer
	endm


;-----------------------------------------------------------------------------
; Copy an embedded Text to the Start of the Buffer and dump the Buffer to Screen
;
STRCPY_PRINT macro string
	extern  strcpy_block_print
	call	strcpy_block_print		; copy text to buffer and print whole buffer
	DB		string, 0				; inline text with terminator
	endm


;-----------------------------------------------------------------------------
; Append an embedded Text to the Content of the Buffer and dump the Buffer to Screen
;
STRCAT_PRINT macro string
	extern	strcat_block_print
	call	strcat_block_print		; append text to buffer and print whole buffer
	DB		string, 0				; inline text with terminator
	endm


;-----------------------------------------------------------------------------
; Functions for direct printing of multi-lingual Texts pointed to by FSR1
;-----------------------------------------------------------------------------

	extern	strcpy_text_FSR			; translate and copy   text to buffer
	extern	strcat_text_FSR			; translate and append text to buffer


;-----------------------------------------------------------------------------
; Macros to print multi-lingual (translated) Texts
;-----------------------------------------------------------------------------

;-----------------------------------------------------------------------------
; Copy a multi-lingual Text to the Start of the Buffer
;
STRCPY_TEXT	macro txt
	extern	strcpy_text
	extern	txt
	call	strcpy_text				; translate and copy text to buffer
	DB		LOW(txt), HIGH(txt)
	endm


;-----------------------------------------------------------------------------
; Append a multi-lingual Text to the Content of the Buffer
;
STRCAT_TEXT	macro txt
	extern	strcat_text
	extern	txt
	call	strcat_text				; translate and append text to buffer
	DB		LOW(txt), HIGH(txt)
	endm


;-----------------------------------------------------------------------------
; Copy a multi-lingual Text to the Start of the Buffer and dump the Buffer to Screen
;
STRCPY_TEXT_PRINT macro txt
	extern	strcpy_text_print
	extern	txt
	call	strcpy_text_print		; translate and copy text to buffer, then dump buffer to screen
	DB		LOW(txt), HIGH(txt)
	endm


;-----------------------------------------------------------------------------
; Append a multi-lingual Text to the Content of the Buffer and dump the Buffer to Screen
;
STRCAT_TEXT_PRINT macro txt
	extern	strcat_text_print
	extern	txt
	call	strcat_text_print		; translate and copy text to buffer, then dump buffer to screen
	DB		LOW(txt), HIGH(txt)
	endm


;-----------------------------------------------------------------------------
; Macros to set Font Size and Output Position in one Batch
;-----------------------------------------------------------------------------

WIN_TINY	macro x, y
	extern	start_tiny_block
	call	start_tiny_block
	DB		x, y
	endm

WIN_SMALL	macro x, y
	extern	start_small_block
	call	start_small_block
	DB		x, y
	endm

WIN_STD		macro x, y
	extern	start_std_block
	call	start_std_block
	DB		x, y
	endm

WIN_MEDIUM	macro x, y
	extern	start_medium_block
	call	start_medium_block
	DB		x, y
	endm

WIN_LARGE	macro x, y
	extern	start_large_block
	call	start_large_block
	DB		x, y
	endm

WIN_HUGE	macro x, y
	extern	start_huge_block
	call	start_huge_block
	DB		x, y
	endm

;-----------------------------------------------------------------------------

