;=============================================================================
;
;   File text_multilang.asm												V2.99c
;
;   Implementation text in various selectable languages.
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;  2011-06-12 : [jDG] Creation

#include "hwos.inc"
#include "text_multilang.inc"

; Because text are indexed by 12 bits values in FSR register, they can't
; just be anywhere. It is safe to make them start at address 0xHHH000.
texts	code	0x009000

;=============================================================================
	global	text_1_base
text_1_base:
;---- PASS 1 : generate description block ------------------------------------
tcode_idx	set		0
LANG		set		0
#define		TCODE	TCODE_1

 IF _language_1==en
 MESSG		"1st Laguage: English"
#include	"text_english.inc"
 ELSE
 IF _language_1==de
 MESSG		"1st Laguage: German"
#include	"text_german.inc"
 ELSE
 IF _language_1==fr
 MESSG		"1st Laguage: French"
#include	"text_french.inc"
 ELSE
 IF _language_1==it
 MESSG		"1st Laguage: Italian"
#include	"text_english.inc"
 ELSE
 MESSG		"1st Laguage: Default (English)"
#include	"text_english.inc"
 ENDIF
 ENDIF
 ENDIF
 ENDIF

#undefine	TCODE

;---- PASS 2 : generate text contents ----------------------------------------
tcode_idx	set		0
#define		TCODE	TCODE_2

 IF _language_1==en
#include	"text_english.inc"
 ELSE
 IF _language_1==de
#include	"text_german.inc"
 ELSE
 IF _language_1==fr
#include	"text_french.inc"
 ELSE
 IF _language_1==it
#include	"text_english.inc"
 ELSE
#include	"text_english.inc"
 ENDIF
 ENDIF
 ENDIF
 ENDIF

#undefine	TCODE

;=============================================================================

 IF _language_2!=none

	global	text_2_base
text_2_base:
;---- PASS 1 : generate description block ------------------------------------
tcode_idx	set		0
LANG		set		1
#define		TCODE	TCODE_1

 IF _language_2==en
 MESSG		"2nd Laguage: English"
#include	"text_english.inc"
 ELSE
 IF _language_2==de
 MESSG		"2nd Laguage: German"
#include	"text_german.inc"
 ELSE
 IF _language_2==fr
 MESSG		"2nd Laguage: French"
#include	"text_french.inc"
 ELSE
 IF _language_2==it
 MESSG		"2nd Laguage: Italian"
#include	"text_english.inc"
 ELSE
 MESSG		"2nd Laguage: Default (English)"
#include	"text_english.inc"
 ENDIF
 ENDIF
 ENDIF
 ENDIF

#undefine	TCODE

;---- PASS 2 : generate text contents ----------------------------------------
tcode_idx	set		0
#define	TCODE	TCODE_2

 IF _language_2==en
#include	"text_english.inc"
 ELSE
 IF _language_2==de
#include	"text_german.inc"
 ELSE
 IF _language_2==fr
#include	"text_french.inc"
 ELSE
 IF _language_2==it
#include	"text_english.inc"
 ELSE
#include	"text_english.inc"
 ENDIF
 ENDIF
 ENDIF
 ENDIF

#undefine	TCODE

 ENDIF

;=============================================================================

	END
