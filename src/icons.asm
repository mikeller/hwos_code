;=============================================================================
;
;   File icons.asm														V2.99c
;
;   Tables for all OSTC icons.
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;  2011-05-24 : [jDG] Creation with icons for demo menus.

#include "hwos.inc"					; Mandatory header

icons_data	CODE

;=============================================================================

; dive mode warning icon
	global	dive_warning2_block
#include "../src/Icons/dive_warning2.inc"	; 45x39 px

; small warning icon
;	global	warning_block
;#include "../src/Icons/warning.inc"		; 25x22 px

 IFDEF _ostc_logo
	global	ostc_logo_block
; OSTC logo
#include "../src/Icons/ostc_logo.inc"		; 220x61 px
 ENDIF

	END
