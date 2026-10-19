;=============================================================================
;
;   File convert.inc                          combined next generation V3.09.4l
;
;   Converts register values to string
;
;   Copyright (c) 2011, Matthias Heinrichs, heinrichs weikamp gmbh, all right reserved.
;=============================================================================
; HISTORY
;   2007-10-07 : [MH]  Creation for OSTC sources
;   2010-12-10 : [jDG] Optimize macro size


;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;
;          The output format of all 8 and 16 bit integer printing
;          functions can be controlled with the following flags.
;          After each printing, the flags are reset automatically.
;
;
;   bsf leftbind        ; print left-aligned            (no leading spaces)
;   bsf leading_zeros   ; print leading zeros
;
;   bsf hide_digit5     ; do not print digit  5      (clip output at  9999)
;   bsf hide_digit4     ; do not print digits 5 - 4  (clip output at   999)
;   bsf hide_digit3     ; do not print digits 5 - 3  (clip output at    99)
;   bsf hide_digit2     ; do not print digits 5 - 2  (clip output at     9)
;
;   In case the output gets clipped, the flag 'output_overflow' will be set
;
;   bsf omit_digit_2    ; do not print digits 2 - 1  (show output as xxx--)
;   bsf omit_digit_1    ; do not print digit      1  (show output as xxxx-)
;
;   bsf decimal_digit3  ; put a decimal point in front of digit 3  (xx.xxx)
;   bsf decimal_digit2  ; put a decimal point in front of digit 2  (xxx.xx)
;   bsf decimal_digit1  ; put a decimal point in front of digit 1  (xxxx.x)
;
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


;-----------------------------------------------------------------------------
;
; Output Functions for 8 Bit Integers
;
; output_x: x is the max number that will be shown
;
; Input: mpr:1 (lo)
;
;-----------------------------------------------------------------------------

output_9	macro				; print only last digit  (0-9)
	extern	output9_call
	call	output9_call
	endm


output_99	macro				; print only 2 digits (0-99)
	extern	output99_call
	call	output99_call
	endm

output_99x	macro				; print only 2 digits with leading zero (00-99)
	extern	output99x_call
	call	output99x_call
	endm

output_99dd	macro				; print only 2 digits or double-dots if zero - variant for small font
	extern	output99dd_call
	call	output99dd_call
	endm

output_99DD	macro				; print only 2 digits or double-dots if zero - variant for big   font
	extern	output99DD_call
	call	output99DD_call
	endm

output_256	macro				; print all 3 digits (0-255)
	extern	output256_call
	call	output256_call
	endm

output_hex	macro				; print in hex (00-FF), Attention: input is via WREG
	extern	outputHEX_call
	call	outputHEX_call
	endm


;-----------------------------------------------------------------------------
;
; Output Functions for 16 Bit Integers
;
; output_x: x is the max number that will be shown
;
; Input: mpr:2 (lo,hi)
;
;-----------------------------------------------------------------------------

output_65535 macro				; print all 5 digits       (0-65535)
	extern	output65535_call
	call	output65535_call
	endm


output_9999	macro				; print only last 4 digits (0-9999)
	extern	output9999_call
	call	output9999_call
	endm

output_999	macro				; print only last 3 digits (0-999)
	extern	output999_call
	call	output999_call
	endm


;-----------------------------------------------------------------------------
;
; Conversion Functions
;
;-----------------------------------------------------------------------------

	extern	convert_pres_to_depth			; convert pressure in [mbar] to depth in [cm]
	extern	convert_cm_to_feet				; convert depth    in [cm]   to depth in [feet]
	extern	convert_meter_to_feet			; convert depth    in [m]    to depth in [feet]
	extern	convert_celsius_to_fahrenheit	; convert temperature from celsius to fahrenheit
	extern	convert_signed_16bit			; convert signed to unsigned 16bit, print '-' if negative
	extern	convert_time					; convert minutes to hours:minutes or seconds to minutes:seconds

	extern	output_date						; print date with day, month and year
	extern	output_date_short				; print date with day and month only
	extern	output_secs_as_days_hours		; print seconds as days and hours

;-----------------------------------------------------------------------------


