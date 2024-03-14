;=============================================================================
;
;   File math.inc                           * combined next generation V3.09.4k
;
;
;   Copyright (c) 2011, JD Gascuel, heinrichs weikamp gmbh, all right reserved.
;=============================================================================
; HISTORY
;  2011-08-03 : [mH] moving from OSTC code


;-----------------------------------------------------------------------------
; SHIFT-RIGHT    with UNSIGNED values
;
	extern	div16					; divA:2 = divA:2 / 2^WREG
									; trashes WREG


;-----------------------------------------------------------------------------
; SHIFT-LEFT     with UNSIGNED values
;
	extern	mult16					; divA:2 = divA:2 * 2^WREG
									; trashes WREG


;-----------------------------------------------------------------------------
; ADDITION       with UNSIGNED values
;
	extern	addU16					; sub_c:2 = sub_a:2 + sub_b:2
									; trashes WREG


;-----------------------------------------------------------------------------
; SUBTRACTION    with SIGNED   values
;
	extern	sub16					; sub_c:2 = sub_a:2 - sub_b:2
									; sets neg_flag if result is < 0
									; trashes WREG


;-----------------------------------------------------------------------------
; SUBTRACTION    with UNSIGNED values
;
	extern	subU16					; sub_c:2 = sub_a:2 - sub_b:2
									; sets neg_flag if result is < 0
									; trashes WREG


;-----------------------------------------------------------------------------
; COMPARE        with UNSIGNED values
;
	extern	cmpU16					; trashed = sub_a:2 - sub_b:2
									; sets neg_flag if result is < 0, but does not store result itself
									; trashes WREG


;-----------------------------------------------------------------------------
; MULTIPLICATION with UNSIGNED values
;
	extern	mult16x16				; xC:4 = xA:2 * xB:2
									; trashes PRODL, PRODH, WREG


;-----------------------------------------------------------------------------
; DIVISION       with UNSIGNED values
;
	extern	div16x16				; xC:2 = xA:2 / xB:2 with xA as remainder
									; trashes xB, WREG


;-----------------------------------------------------------------------------
; DIVISION       with UNSIGNED values
;
	extern	div32x16				; xC:4 = xC:4 / xB:2 with xA as remainder	
									; trashes WREG


;-----------------------------------------------------------------------------
; Math Functions specific for Use by ISR
;-----------------------------------------------------------------------------

;-----------------------------------------------------------------------------
; 24 bit shift, repeated WREG times, dedicated to a specific usage
;
	extern	isr_shift_C31


;-----------------------------------------------------------------------------
; MULTIPLICATION with UNSIGNED values
;
	extern	isr_unsigned_mult16x16	; isr_xC = isr_xA * isr_xB
									; trashes PRODL, PRODH, WREG
;-----------------------------------------------------------------------------
; MULTIPLICATION with UNSIGNED values
;
	extern	isr_unsigned_mult24x24	; isr_xC = isr_xA * isr_xB
									; trashes PRODL, PRODH, WREG
	extern	isr_unsigned_mult32x24	; isr_xC = isr_xA * isr_xB
									; trashes PRODL, PRODH, WREG
									
;-----------------------------------------------------------------------------
; MULTIPLICATION with SIGNED   values
;
	extern	isr_signed_mult16x16	; isr_xC = isr_xA * isr_xB
									; trashes PRODL, PRODH, WREG
										
	extern	isr_signed_mult24x24

;-----------------------------------------------------------------------------
									
; DIVISION       with UNSIGNED values
;
	extern	isr_div16x16				; isr_xC:2 = isr_xA:2 / isr_xB:2 with isr_xA as remainder
									; trashes xB, WREG

;-----------------------------------------------------------------------------
; DIVISION       with UNSIGNED values
;

	extern	isr_div32x16				; isr_xC:4 = isr_xC:4 / isr_xB:2 with isr_xA as remainder
