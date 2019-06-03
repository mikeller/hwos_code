;=============================================================================
;
;   File strings.asm                          combined next generation V3.03.2
;
;   Implementation code various string functions
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;   2010-12-02 : [jDG] Creation
;

;=============================================================================
; Copy a short embedded string to the start of the string buffer
; Input  : string after macro name
; Output : chars are copied to the start of the string buffer
;          FSR2 points to the first unused char containing the NULL termination
; Trashed: WREG, TBLPTR, TABLAT, PRODL
; Note   : uses bank-safe calls only
;
	extern	strcpy_block
STRCPY macro string
	call	strcpy_block
	DB		string, 0
	endm

;=============================================================================
; A variant of STRCPY that appends chars in the string buffer at the current
; FSR2 pointer position
; Input/Output/Trashed: see STRCPY
;
	extern	strcat_block
STRCAT macro string
	call	strcat_block
	DB		string, 0
	endm

;=============================================================================
; A variant of STRCAT when there is just on char to output
; Input/Output/Trashed: see STRCPY
;
PUTC macro	char
	movlw	char
	movwf	POSTINC2
	endm

;=============================================================================
; A variant of STRCPY that sends the string to the word processor afterwards
; Input/Output: see STRCPY
; Trashed     : see STRCPY + word_processor. In particular, switches RAM to Bank1
;
	extern  strcpy_block_print
STRCPY_PRINT macro string
	call	strcpy_block_print
	DB		string, 0
	endm

;=============================================================================
; A variant of STRCAT that sends the string to the word processor afterwards
; Input/Output: see STRCAT
; Trashed     : see STRCPY + word_processor. In particular, switches RAM to Bank1
;
	extern	strcat_block_print
STRCAT_PRINT macro string
	call	strcat_block_print
	DB		string, 0
	endm

;=============================================================================
; Subroutines to operate on strings from PROM code
;
; Input  : TBLPTR : string pointer into PROM
; Trashed: FSR1
; Output : string in buffer, FSR2 pointer on the closing null byte

	extern	strcpy_prom,       strcat_prom
	extern	strcpy_prom_print, strcat_prom_print

;=============================================================================
; Subroutines and macros to operate on multilingual text
;
	extern	strcpy_text
STRCPY_TEXT macro txt
	extern	txt
	lfsr	FSR1, txt
	call	strcpy_text
	endm

	extern	strcpy_text_print
STRCPY_TEXT_PRINT macro txt
	extern	txt
	lfsr	FSR1, txt
	call	strcpy_text_print
	endm

	extern	strcat_text
STRCAT_TEXT macro txt
	extern	txt
	lfsr	FSR1, txt
	call	strcat_text
	endm

	extern	strcat_text_print
STRCAT_TEXT_PRINT macro txt
	extern	txt
	lfsr	FSR1, txt
	call	strcat_text_print
	endm

;=============================================================================
; A shortcut for the macros WIN_TOP + WIN_LEFT + WIN_FONT
; The idea is to replace a 4x6=24 bytes sequence by a more compact 6 bytes one.
;
; Trashed: TBLPTR, TABLAT, WREG.
; Note   : uses bank-safe calls only
;
	extern	start_tiny_block
WIN_TINY macro x, y
	call	start_tiny_block
	DB		x, y
	endm

	extern	start_small_block
WIN_SMALL macro x, y
	call	start_small_block
	DB		x, y
	endm

	extern	start_std_block
WIN_STD macro x, y
	call	start_std_block
	DB		x, y
	endm

	extern	start_medium_block
WIN_MEDIUM macro x, y
	call	start_medium_block
	DB		x, y
	endm

	extern	start_large_block
WIN_LARGE macro x, y
	call	start_large_block
	DB		x, y
	endm

 IFDEF _huge_font
	extern	start_huge_block
WIN_HUGE macro x, y
	call	start_huge_block
	DB		x, y
	endm
 ENDIF

;=============================================================================
; Shortcuts for compact display programmings
;
TEXT_TINY macro x, y, txt
	WIN_TINY x,y
	STRCPY_TEXT_PRINT txt
	endm

TEXT_SMALL macro x, y, txt
	WIN_SMALL x,y
	STRCPY_TEXT_PRINT txt
	endm

TEXT_SMALL_INVERT macro x, y, txt
	WIN_SMALL_INVERT x,y
	STRCPY_TEXT_PRINT txt
	endm

TEXT_STD macro x, y, txt
	WIN_STD x,y
	STRCPY_TEXT_PRINT txt
	endm

TEXT_MEDIUM macro x, y, txt
	WIN_MEDIUM x,y
	STRCPY_TEXT_PRINT txt
	endm

TEXT_LARGE macro x, y, txt
	WIN_LARGE x,y
	STRCPY_TEXT_PRINT txt
	endm

TEXT_HUGE macro x, y, txt
	WIN_HUGE x,y
	STRCPY_TEXT_PRINT txt
	endm


STRING_TINY macro x, y, string
	WIN_SMALL x,y
	STRCPY_PRINT string
	endm

STRING_SMALL macro x, y, string
	WIN_SMALL x,y
	STRCPY_PRINT string
	endm

STRING_MEDIUM macro x, y, string
	WIN_MEDIUM x,y
	STRCPY_PRINT string
	endm

STRING_LARGE macro x, y, string
	WIN_LARGE x,y
	STRCPY_PRINT string
	endm

STRING_HUGE macro x, y, string
	WIN_HUGE x,y
	STRCPY_PRINT string
	endm
