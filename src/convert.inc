;=============================================================================
;
;   File convert.inc                          combined next generation V3.04.2
;
;   Converts register values to string
;
;   Copyright (c) 2011, Matthias Heinrichs, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;   2007-10-07 : [MH]  Creation for OSTC sources
;   2010-12-10 : [jDG] Optimize macro size


	extern	output16_3_call
output_16_3	macro				; displays only last three digits from a 16 bit value (0-999)
	call	output16_3_call
	endm

	extern	output16_4_call
output_16_4	macro				; displays only last four digits from a 16 bit value (0-9999)
	call	output16_4_call
	endm

	extern	output16
output_16dp	macro dp_position	; 16 bit with decimal point
	movlw	dp_position
	call	output16
	endm

	extern	output16_call
output_16	macro				; 16 bit normal
	call	output16_call
	endm

	extern	output8_call
output_8	macro				; 8 bit normal
	call	output8_call
	endm

	extern	output99_call
output_99	macro				; displays only last two digits from a 8 bit value (0-99)
	call	output99_call
	endm

	extern	output99x_call
output_99x	macro				; displays only last two digits from a 8 bit value with leading zero (00-99)
	call	output99x_call
	endm

	extern	output99dd_call
output_99dd	macro				; displays only last two digits from a 8 bit value, prints double-dots if zero - small fonts
	call	output99dd_call
	endm

	extern	output99DD_call
output_99DD	macro				; displays only last two digits from a 8 bit value, prints double-dots if zero - big   fonts
	call	output99DD_call
	endm

	extern	outputHEX_call
output_hex	macro				; displays 8 bit integer in hex, input via WREG
	call	outputHEX_call
	endm
