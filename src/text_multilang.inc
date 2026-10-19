;=============================================================================
;
;    File text_multilang.inc                 * combined next generation V3.09.4j
;
;    Implementation of texts in various selectable languages
;
;   Copyright (c) 2011, JD Gascuel, heinrichs weikamp gmbh, all right reserved.
;=============================================================================
; HISTORY
;  2011-06-12 : [jDG] Creation
;
; Text definitions (text_french.asm example):
;	TCODE	tYes,	"Oui"					; Yes
;	TCODE	tNo,	"Non"					; No
;	TCODE	tLogbk,	"Carnet de plongées"	; Logbook
;
; Text usage via is done via macros, see strings.inc


;-----------------------------------------------------------------------------
; Pass 1: generate Index Table and define Labels
;-----------------------------------------------------------------------------

TCODE_1 macro label, text
tcode_idx set tcode_idx+1
	If LANG == 0
		global	label
label:
	Endif
	dw		t#v(LANG)_#v(tcode_idx)
	endm


;-----------------------------------------------------------------------------
; Pass 2: generate String Table
;-----------------------------------------------------------------------------

TCODE_2 macro label, text
tcode_idx set tcode_idx+1
t#v(LANG)_#v(tcode_idx):
	db		text, 0
	endm

;-----------------------------------------------------------------------------
