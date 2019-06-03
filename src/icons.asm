;=============================================================================
;
;   File icons.asm                             combined next generation V3.0.1
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


	global	dive_warning2_block				; dive mode warning icon
#include "../src/Icons/dive_warning2.inc"	; 45x39 pixels

;-----------------------------------------------------------------------------

 IFDEF _ostc_logo

	global	ostc_logo_block					; OSTC logo
#include "../src/Icons/ostc_logo.inc"		; 220x61 pixels

 ENDIF

;-----------------------------------------------------------------------------

	END
