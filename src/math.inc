;=============================================================================
;
;   File math.inc                             combined next generation V3.08.8
;
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;  2011-08-03 : [mH] moving from OSTC code

	extern	convert_time			; convert minutes in hi:lo to hours (up:hi) and minutes (lo)
									; also usable for conversion of seconds to minutes and seconds
									; trashes xA, xB, xC

	extern	div16					; divA:2 = divA:2 / 2^WREG					SHIFT-RIGHT    with UNSIGNED values
									; trashes WREG

	extern	mult16					; divA:2 = divA:2 * 2^WREG					SHIFT-LEFT     with UNSIGNED values
									; trashes WREG

	extern	addU16					; sub_c:2 = sub_a:2 + sub_b:2				ADDITION       with UNSIGNED values
									; trashes WREG

	extern	sub16					; sub_c:2 = sub_a:2 - sub_b:2				SUBTRACTION    with SIGNED   values
									; sets neg_flag if result is < 0
									; trashes WREG

	extern	subU16					; sub_c:2 = sub_a:2 - sub_b:2				SUBTRACTION    with UNSIGNED values
									; sets neg_flag if result is < 0
									; trashes WREG

	extern	cmpU16					; trashed = sub_a:2 - sub_b:2				COMPARE        with UNSIGNED values
									; sets neg_flag if result is < 0, but does not store result itself
									; trashes WREG

	extern	mult16x16				; xC:4 = xA:2 * xB:2						MULTIPLICATION with UNSIGNED values
									; trashes PRODL, PRODH, WREG

	extern	div16x16				; xC:2 = xA:2 / xB:2 with xA as remainder	DIVISION       with UNSIGNED values
									; trashes xB, WREG

	extern	div32x16				; xC:4 = xC:4 / xB:2 with xA as remainder	DIVISION       with UNSIGNED values
									; trashes WREG

	extern	isr_shift_C31			; 24 bit shift, repeated WREG times, dedicated to a specific usage


	extern	isr_unsigned_mult16x16	; isr_xC = isr_xA * isr_xB		MULTIPLICATION with UNSIGNED values ** for ISR only **
									; trashes PRODL, PRODH, WREG

	extern	isr_signed_mult16x16	; isr_xC = isr_xA * isr_xB		MULTIPLICATION with SIGNED   values ** for ISR only **
									; trashes PRODL, PRODH, WREG
