;=============================================================================
;
;   File aa_fonts.asm													V2.99d
;
;   Font-data for the anti-aliased word processor
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;  2010-11-23 : [jDG] Creation for OSTC 1.72, with the original fonts repacked
;  2010-12-01 : [jDG] Adding 3 bit anti-aliased fonts
;=============================================================================

;---- TINY font description and data ----------------------------------------

; Attention: all three fonts need to be in the same 64 kByte page
fonts_data	CODE_PACK	0x11000


	global	aa_font16_block
aa_font16_block:
	DB		'°', 0x7F					; remap a few ASCII chars, to avoid
	DB		'ö', 0x80					; holes in the character table
	DB		'ä', 0x81
	DB		'ü', 0x82
	DB		'ß', 0x83
	DB		'é', 0x84					; French accents
	DB		'è', 0x85
	DB		'ê', 0x86
	DB		'ç', 0x87
	DB		'á', 0x88					; Spanish accents
	DB		'í', 0x89
	DB		'ó', 0x8A
	DB		'ú', 0x8B
	DB		'ñ', 0x8C
	DB		'¡', 0x8D
	DB		'¿', 0x8E
	DB		0							; end of translation table
	DB		aa_font16_firstChar			; to be subtracted
	DB		aa_font16_chars				; max value
	DB		'¿'-aa_font16_firstChar		; replace by ¿ when unknown
	DB		aa_font16_height + 0x80
;
#include	"../src/Fonts/aa_font16_idx.inc"
#include	"../src/Fonts/aa_font16.inc"
aa_font16_end:
; Attention: make sure this is coherent
	if aa_font16_nbbits != 3
		error TINY font should be encoded with 3 bits anti-aliasing!
	endif

;---- SMALL font description and data ----------------------------------------
	global	aa_font28_block
aa_font28_block:
	DB		'°', 0x7F					; remap a few ASCII chars, to avoid
	DB		'ö', 0x80					; holes in the character table
	DB		'ä', 0x81
	DB		'ü', 0x82
	DB		'ß', 0x83
	DB		'é', 0x84					; French accents
	DB		'è', 0x85
	DB		'ê', 0x86
	DB		'ç', 0x87
	DB		'á', 0x88					; Spanish accents
	DB		'í', 0x89
	DB		'ó', 0x8A
	DB		'ú', 0x8B
	DB		'ñ', 0x8C
	DB		'¡', 0x8D
	DB		'¿', 0x8E
	DB		'¤', 0x8F					; unused
	; 90 and 91 contain the logo
	DB		0xB7,0x92					; cursor
	DB		0xB8,0x93					; arrow down
	DB		0xB9,0x94					; arrow up
	DB		0							; end of translation table
	DB		aa_font28_firstChar			; to be subtracted
	DB		aa_font28_chars				; max value
	DB		0x83-aa_font28_firstChar	; replace by ¤ when unknown
	DB		aa_font28_height + 0x80
;
#include	"../src/Fonts/aa_font28_idx.inc"
#include	"../src/Fonts/aa_font28.inc"
aa_font28_end:
; Attention: make sure this is coherent...
	if aa_font28_nbbits != 3
		error SMALL font should be encoded with 3 bits anti-aliasing!
	endif

;---- STD font description and data ------------------------------------------
	global	aa_font36_block
aa_font36_block:
	DB		'°', 0x7F					; remap a few ASCII chars, to avoid
	DB		'ö', 0x80					; holes in the character table
	DB		'ä', 0x81
	DB		'ü', 0x82
	DB		'ß', 0x83
	DB		'é', 0x84					; French accents
	DB		'è', 0x85
	DB		'ê', 0x86
	DB		'ç', 0x87
	DB		'à', 0x88					; Spanish accents
	DB		'á', 0x89
	DB		'í', 0x8A
	DB		'ó', 0x8B
	DB		'ú', 0x8C
	DB		'ñ', 0x8D
	DB		'¡', 0x8E
	DB		'¿', 0x8F
	; 90, 91 contain the the logo
	DB	0xB7,0x92						; cursor
	; 93 is down arrow (dive start)
	; 94 is up   arrow (dive end)
	; 95 is left-right arrow (dive duration)
	DB	'¤', 0x96						; unused
	DB	0								; end of translation table
	DB	aa_font34_firstChar				; to be subtracted
	DB	aa_font34_chars					; max value
	DB	0x87-aa_font34_firstChar		; replace by ¤ when unknown.
	DB	aa_font34_height + 0x80
;
#include	"../src/Fonts/aa_font34_idx.inc"
#include	"../src/Fonts/aa_font34.inc"
aa_font36_end:
; Attention: make sure this is coherent...
	if aa_font34_nbbits != 3
		error STANDARD font should be encoded with 3 bits anti-aliasing!
	endif

;---- MEDIUM font description and data ---------------------------------------
	global	aa_font48_block
aa_font48_block:
	DB		0x27, 0x3B					; ' char
	DB		'"', 0x3C
	DB		'm', 0x3D
	DB		'f', 0x3E
	DB		' ', 0x3F
	DB		0
	DB		aa_font48_firstChar
	DB		aa_font48_chars
	DB		0x3E-aa_font48_firstChar
	DB		aa_font48_height + 0x80		; AA flag
;
#include	"../src/Fonts/aa_font48_idx.inc"
#include	"../src/Fonts/aa_font48.inc"
aa_font48_end:
; Attention: make sure this is coherent...
	if aa_font48_nbbits != 3
		error MEDIUM font should be encoded with 3 bits anti-aliasing!
	endif

;---- LARGE font description and data ----------------------------------------
	global	aa_font90_block
aa_font90_block:
	DB		' ', 0x2F
	DB		0
	DB		aa_font90_firstChar
	DB		aa_font90_chars
	DB		0x2F-aa_font90_firstChar
	DB		aa_font90_height + 0x80		; AA flag
;
#include	"../src/Fonts/aa_font90_idx.inc"
#include	"../src/Fonts/aa_font90.inc"
aa_font90_end:
; Attention: make sure this is coherent...
	if aa_font90_nbbits != 3
		error SMALL font should be encoded with 3 bits anti-aliasing!
	endif

;=============================================================================
	END