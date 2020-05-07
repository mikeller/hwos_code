;=============================================================================
;
;   File text_multilang.asm                 * combined next generation V3.09.4k
;
;   Implementation text in various selectable languages.
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;  2011-06-12 : [jDG] Creation

#include "hwos.inc"
#include "text_multilang.inc"


; Because multi-lingual texts are indexed using a FSR register and a FSR
; register only holds 12 bit, the texts need to be aligned to a 4 kB block
; in program memory. That is, they need to start at an address 0xXX000.



; fast hack **ONLY** for **CHANGING** languages ( en / de / fr / it )

;#undefine _language_1
;#define   _language_1 fr
;;
;#undefine _language_2
;#define   _language_2 it


;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; LANGUAGE 1
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


;=============================================================================
text_1_base	CODE 0x09000	;     ! DO NOT CHANGE !        *** Index Table ***
;=============================================================================

	global	text_1_base
text_1_base:

tcode_idx	set		0
LANG		set		0
#define		TCODE	TCODE_1

 IF _language_1==en
 MESSG		"1st Language: English"
#include	"text_english.inc"
 ELSE
 IF _language_1==de
 MESSG		"1st Language: German"
#include	"text_german.inc"
 ELSE
 IF _language_1==fr
 MESSG		"1st Language: French"
#include	"text_french.inc"
 ELSE
 IF _language_1==it
 MESSG		"1st Language: Italian"
#include	"text_italian.inc"
 ELSE
 MESSG		"1st Language: Default (English)"
#include	"text_english.inc"
 ENDIF
 ENDIF
 ENDIF
 ENDIF

#undefine	TCODE


;=============================================================================
text_1_text	CODE_PACK	;                                   *** Text Table ***
;=============================================================================

	global	text_1_text
text_1_text:

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
#include	"text_italian.inc"
 ELSE
#include	"text_english.inc"
 ENDIF
 ENDIF
 ENDIF
 ENDIF

#undefine	TCODE



;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; LANGUAGE 2
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

 IF _language_2 != none


;=============================================================================
text_2_base	CODE 0x09400	;     ! DO NOT CHANGE !        *** Index Table ***
;=============================================================================

	global	text_2_base
text_2_base:

tcode_idx	set		0
LANG		set		1
#define		TCODE	TCODE_1

 IF _language_2==en
 MESSG		"2nd Language: English"
#include	"text_english.inc"
 ELSE
 IF _language_2==de
 MESSG		"2nd Language: German"
#include	"text_german.inc"
 ELSE
 IF _language_2==fr
 MESSG		"2nd Language: French"
#include	"text_french.inc"
 ELSE
 IF _language_2==it
 MESSG		"2nd Language: Italian"
#include	"text_italian.inc"
 ELSE
 MESSG		"2nd Language: Default (English)"
#include	"text_english.inc"
 ENDIF
 ENDIF
 ENDIF
 ENDIF

#undefine	TCODE


;=============================================================================
text_2_text	CODE_PACK	;                                   *** Text Table ***
;=============================================================================

	global	text_2_text
text_2_text:

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
#include	"text_italian.inc"
 ELSE
#include	"text_english.inc"
 ENDIF
 ENDIF
 ENDIF
 ENDIF

#undefine	TCODE

 ENDIF	; _language_2

;-----------------------------------------------------------------------------

	END
