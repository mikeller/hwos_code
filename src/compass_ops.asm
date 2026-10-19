;=============================================================================
;
;   File compass_ops.asm                      combined next generation V3.09.5
;
;   Compass Operations
;
;   Copyright (c) 2011, JD Gascuel, heinrichs weikamp gmbh, all right reserved.
;=============================================================================

#include "hwos.inc"
#include "i2c.inc"
#include "tft_outputs.inc"
#include "tft.inc"
#include "strings.inc"
#include "wait.inc"
#include "surfmode.inc"
#include "divemode.inc"
#include "math.inc"
#include "convert.inc"
#include "start.inc"
#include "colorschemes.inc"


 IFDEF _compass


; local flags
;#DEFINE compass_show_cardinal	compass_flags,0		; =1: show the cardinal (N, NE, E, ...)
;#DEFINE compass_bearing_eq		compass_flags,1		; =1: bearing is in direction, do not show << or >> 
;#DEFINE compass_bearing_lft		compass_flags,2		; =1: bearing is to the left/<<, =0: to the right/>>
;#DEFINE compass_bearing_vis		compass_flags,3		; =1: bearing is visible (either ahead or behind/-180°)
;#DEFINE compass_bearing_ahd		compass_flags,4		; =1: bearing is ahead, =0: behind
;;								compass_flags,5		; --- unused
;;								compass_flags,6		; --- unused
;;								compass_flags,7		; --- unused


; Make sure symbols from the .inc are available to the C code:

	; filtered data - Compass
	global	compass_DX_f
	global	compass_DY_f
	global	compass_DZ_f

	; filtered Data - Accelerometer
	global	accel_DX_f
	global	accel_DY_f
	global	accel_DZ_f

	; Calibration Data
	global	compass_CX_f
	global	compass_CY_f
	global	compass_CZ_f

	; Temporary Values to pass Q15 Arithmetics around
	global	compass_a
	global	compass_b

	; Result
	global	compass_heading_new


	extern	compass
	extern	compass_reset_calibration
	extern	compass_add_calibration
	extern	compass_solve_calibration

	extern	option_check_and_store_all


;=============================================================================
compass_ops1	CODE
;=============================================================================


;-----------------------------------------------------------------------------
; Filter compass values
;
; Apply linear filtering to input parameters.

; Apply filtering formula: reg_f += (reg - reg_f) / 4
FILTER16	MACRO	reg, reg_f
	movf	reg_f+0,W
	subwf	reg+0,W
	movwf	PRODL
	movf	reg_f+1,W
	subwfb	reg+1,W
	rcall	filter_16_common
	addwf	reg_f+0,F
	movf	PRODH,W
	addwfc	reg_f+1,F
	ENDM

filter_16_common:
	movwf	PRODH
	bcf		STATUS,C					; copy sign bit into carry
	btfsc	PRODH,7
	bsf		STATUS,C
	rrcf	PRODH,F						; 16 bit shift right
	rrcf	PRODL,F
	bcf		STATUS,C					; copy sign bit into carry
	btfsc	PRODH,7
	bsf		STATUS,C
	rrcf	PRODH,F						; 16 bit shift right
	rrcf	PRODL,W
	return


	global	compass_filter
compass_filter:
	banksel	compass_DX					; select bank common2
	FILTER16 compass_DX, compass_DX_f
	FILTER16 compass_DY, compass_DY_f
	FILTER16 compass_DZ, compass_DZ_f
	FILTER16 accel_DX,   accel_DX_f
	FILTER16 accel_DY,   accel_DY_f
	FILTER16 accel_DZ,   accel_DZ_f
	banksel	common						; back to bank common
	return


;=============================================================================
compass_ops2	CODE
;=============================================================================

;-----------------------------------------------------------------------------
; Q15 fractional numbers: a * b / 2**16 (UNSIGNED)
;
; Uses 16x16->16 multiply, for positive integers, keeping only the most
; relevant bits.
;
; Used to multiply two Q15 numbers, in the range 0..1,
; represented as 0..32767, that is a / 2**15.
;
; (a/2**15) * (b/2**15) = a*b / 2**30 = (a*b/2**16) / 2**14.
; So to get back a Q15 number, we need a shift-left...

	global	compass_umul				; called from compass.c
compass_umul:
	banksel	compass_a					; select bank common2
	rcall	compass_mul_16

; The 2x time, by left-shifting inserting the missing bit:
compass_mul_2:
	rlcf	compass_r+2,F				; missing bit into carry
	rlcf	compass_r+0,F
	rlcf	compass_r+1,F
	MOVII	compass_r,PROD				; return value into PROD
	return

; The 16x16-> multiply:
compass_mul_16:
	movf	compass_a+1,W				; block ah*bh
	mulwf	compass_b+1
	movff	PRODL,compass_r+0			; and copy
	movff	PRODH,compass_r+1

	movf	compass_a+0,W				; block al*bl
	mulwf	compass_b+0
	movff	PRODH,compass_r+2			; into fraction byte

	movf	compass_a+1,W				; block ah*bl
	mulwf	compass_b+0
	movf	PRODL,W
	addwf	compass_r+2,F				; fraction part to carry
	movf	PRODH,W						; and add16
	addwfc	compass_r+0,F
	movlw	0
	addwfc	compass_r+1,F

	movf	compass_a+0,W				; block al*bh
	mulwf	compass_b+1
	movf	PRODL,W
	addwf	compass_r+2,F				; fraction part to carry
	movf	PRODH,W						; and add16
	addwfc	compass_r+0,F
	movlw	0
	addwfc	compass_r+1,F

	return

;-----------------------------------------------------------------------------
; Q15 fractional numbers: a * b / 2**16 (SIGNED)

	global	compass_imul				; called from compass.c
compass_imul:
	banksel	compass_a					; select bank common2
	rcall	compass_mul_16

	btfss	compass_b+1,7
	bra		compass_mul_3

	movf	compass_a+0,W
	subwf	compass_r+0,F
	movf	compass_a+1,W
	subwfb	compass_r+1,F

compass_mul_3:
	btfss	compass_a+1,7
	bra		compass_mul_4

	movf	compass_b+0,W
	subwf	compass_r+0,F
	movf	compass_b+1,W
	subwfb	compass_r+1,F

compass_mul_4:
	bcf		compass_r+1,6				; copy bit 7 to 6, so keep it after 2x
	btfsc	compass_r+1,7
	bsf		compass_r+1,6
	bra		compass_mul_2


;=============================================================================
compass_ops3	CODE
;=============================================================================

	global	compass_calibration
compass_calibration:					; compass calibration
	bsf		block_sensor_interrupt		; disable sensor interrupts
	call	I2C_sleep_compass			; stop compass
	call	TFT_ClearScreen				; clear the screen
	; Mask
	WIN_STD .16,.0						; set position
	FONT_COLOR color_green			; set font color
	STRCPY_TEXT_PRINT tCompassCalibration
	btfss	switch_right2				; wait until button (with a moving magnet in some OSTC!) is released
	bra		$-2

;	WIN_SMALL .0,.215
;	FONT_COLOR	color_standard
;	STRCPY_TEXT_PRINT tExit
	WAITMS	d'255'
	WAITMS	d'255'

	call	request_speed_fastest		; request CPU speed change to fastest speed

	movlw	.5							; initialize gain
	movff	WREG,opt_compass_gain		; ...

	movlw	.60							; initialize timeout to 60 seconds
	movwf	isr_timeout_reload			; copy WREG to isr_timeout_reload
	bsf		restart_timeout				; request ISR to restart the timeout
	bcf		trigger_timeout				; clear any pending timeout trigger
compass_calibration_gainset:			; reduce the gain, set bank here!
	banksel	opt_compass_gain			; select bank options table
	decf	opt_compass_gain,F			; reduce by one
	btfsc	STATUS,N					; < 0 ?
	clrf	opt_compass_gain			; YES - keep at zero
	btfsc	STATUS,N					; < 0 ?
	bra		compass_calibration_loop1	; YES - skip gain stuff (Would hang here in case of compass failure)
	banksel	common						; bank to bank common

	call	I2C_init_compass			; initialize compass chip

	btfsc	compass_type3				; compass type 3 ?
	bra		compass_calibration_loop1	; YES - skip gain stuff
	btfsc	compass_type2				; compass type 2 ?
	bra		compass_calibration_loop1	; YES - skip gain stuff

	rcall	TFT_compass_show_gain		; show the current compass gain

	WAITMS	d'250'
	WAITMS	d'250'						; wait for first reading...

	movlw	.60							; calibration shall run for 60 seconds
	call	restart_timeout_time		; restart the timeout

	call	I2C_RX_compass				; read compass
	call	I2C_RX_accelerometer		; read accelerometer

	; Test all axes for +4096 (Hi byte=16)
	banksel	compass_DX					; select bank common2
	movlw	.16
	cpfseq	compass_DX+1
	bra		$+4
	bra		compass_calibration_gainset
	cpfseq	compass_DY+1
	bra		$+4
	bra		compass_calibration_gainset
	cpfseq	compass_DZ+1
	bra		$+4
	bra		compass_calibration_gainset

	; Test all axes for -4096 (Hi byte=240)
	movlw	.240
	cpfseq	compass_DX+1
	bra		$+4
	bra		compass_calibration_gainset
	cpfseq	compass_DY+1
	bra		$+4
	bra		compass_calibration_gainset
	cpfseq	compass_DZ+1
	bra		$+4
	bra		compass_calibration_gainset

compass_calibration_loop1:				; done with gain
	banksel	common						; bank to bank common
	rcall	compass_filter_init			; set DX_f values
	call	compass_reset_calibration	; reset CX_f values (C-code)
	banksel	common						; back to bank common

compass_calibration_loop2:
	call	I2C_RX_compass				; read compass
	call	I2C_RX_accelerometer		; test accelerometer
	call	compass_filter				; filter compass raw data

	; Twice
	call	I2C_RX_compass				; read compass
	call	I2C_RX_accelerometer		; test accelerometer
	call	compass_filter				; filter compass raw data

;	btfsc	compass_type1				; compass1?
;	bra		compass_calibration_loop3	; YES -  skip gain stuff

	banksel	opt_compass_gain			; select bank options table
	tstfsz	opt_compass_gain			; =0?
	bra		$+4				; No
	bra	compass_calibration_loop3		; YES -  skip gain stuff 
	; Test all axes for +4096 (Hi byte=16)
	banksel	compass_DX					; select bank common2
	movlw	.16
	cpfseq	compass_DX+1
	bra		$+4
	bra		compass_calibration_gainset
	cpfseq	compass_DY+1
	bra		$+4
	bra		compass_calibration_gainset
	cpfseq	compass_DZ+1
	bra		$+4
	bra		compass_calibration_gainset

	; Test all axes for -4096 (Hi byte=240)
	movlw	.240
	cpfseq	compass_DX+1
	bra		$+4
	bra		compass_calibration_gainset
	cpfseq	compass_DY+1
	bra		$+4
	bra		compass_calibration_gainset
	cpfseq	compass_DZ+1
	bra		$+4
	bra		compass_calibration_gainset

compass_calibration_loop3:
	banksel	common						; back to bank common
	; and register only one value out of four:
	call	compass_add_calibration		; check and store new max/min values (C-code)
	banksel	common						; back to bank common

	rcall	TFT_compass_fast			; show values
	btfsc	trigger_timeout				; timeout (calibration done)?
	bra		compass_calibration_exit	; YES - done
	btfss	trigger_full_second			; NO  - new second begun?
	bra		compass_calibration_loop2	;       NO  - loop
	bcf		trigger_full_second			;       YES - clear flag
	rcall	TFT_show_timeout_testmode	;           - show remaining time
	bra		compass_calibration_loop2	;           - loop

compass_calibration_exit:
	bcf		block_sensor_interrupt		; re-enable sensor interrupts

	call	compass_solve_calibration	; calculate calibration factors (C-code)
	banksel	common						; back to bank common

	call	request_speed_normal		; request CPU speed change to normal speed

	bsf		option_changed				; flag that option values have changed
	bsf		restart_fast				; request to skip logos and waits on restart

	movlw	.6							; coding for surface compass view
	movff	WREG,customview_surfmode	; set to compass view to show

	goto	restart						; done


;-----------------------------------------------------------------------------
; Helper Function
;
compass_filter_init:
	MOVII	compass_DX,compass_DX_f
	MOVII	compass_DY,compass_DY_f
	MOVII	compass_DZ,compass_DZ_f

	MOVII	accel_DX,accel_DX_f
	MOVII	accel_DY,accel_DY_f
	MOVII	accel_DZ,accel_DZ_f
	return

;-----------------------------------------------------------------------------
; Show Calibration Progress
;
TFT_compass_fast:
	WIN_TINY .5,.50					; set font and position
	FONT_COLOR_MEMO					; set font color

	STRCPY	"Cx:"					; print label
	MOVII	compass_DX,mpr			; get   value
	rcall	TFT_compass_fast_helper ; print value

	STRCAT	" Cy:"					; print label
	MOVII	compass_DY,mpr			; get   value
	rcall	TFT_compass_fast_helper ; print value

	STRCAT	" Cz:"					; print label
	MOVII	compass_DZ,mpr			; get   value
	rcall	TFT_compass_fast_helper ; print value

	PRINT							; dump to screen

	WIN_TINY .5,.104				; set font and position
	FONT_COLOR_MEMO					; set font color

	STRCPY	"Ax:"					; print label
	MOVII	accel_DX,mpr			; get   value
	rcall	TFT_compass_fast_helper ; print value

	STRCAT	" Ay:"					; print label
	MOVII	accel_DY,mpr			; get   value
	rcall	TFT_compass_fast_helper ; print value

	STRCAT	" Az:"					; print label
	MOVII	accel_DZ,mpr			; get   value
	rcall	TFT_compass_fast_helper ; print value

	PRINT							; dump to screen
	return							; done


TFT_compass_fast_helper:
	call	convert_signed_16bit	; convert lo:hi into unsigned-short and add '-' to POSTINC2 if required
	btfsc	neg_flag				; is value negative?
	bra		TFT_compass_fast_helper1; YES - print value
	PUTC	'+'						; NO  - print a plus sign first
TFT_compass_fast_helper1:
	output_65535					; print value (0-65535)
	return



;-----------------------------------------------------------------------------
; Show remaining Calibration Time
;
TFT_show_timeout_testmode:
	WIN_TINY .0,.68						; set font and position
	FONT_COLOR_MEMO						; set font color
	STRCPY	"T:"						; print label
	movff	isr_timeout_timer,lo		; get remaining time
	output_256							; print remaining time (xxx)
	PUTC_PRINT "s"						; append unit and dump to screen
	return								; done


;-----------------------------------------------------------------------------
; Show current Compass Gain
;
TFT_compass_show_gain:					; show the current compass gain
;	movff	opt_compass_gain,lo			; 0-7 (230 LSB/Gauss to 1370 LSB/Gauss)
;	tstfsz	lo
;	return								; do not show unless gain > 0
	WIN_TINY .0,.86						; set font and position
	FONT_COLOR_MEMO						; set font color
	STRCPY_TEXT tCompassGain			; print label
	movff	opt_compass_gain,lo			; get value: 0-7 (230 LSB/Gauss to 1370 LSB/Gauss)
	output_99							; print value (xx)
	PRINT								; dump to screen
	return								; done


;=============================================================================
compass_ops4	CODE
;=============================================================================

;-----------------------------------------------------------------------------
; Mask for Compass in Surface Mode
;
	global	TFT_surface_compass_mask
TFT_surface_compass_mask:
	WIN_SMALL surf_compass_mask_column,surf_compass_mask_row
	FONT_COLOR color_green				; set font color
	STRCPY_TEXT_PRINT tHeading			; print "Heading:"
	return								; done


;-----------------------------------------------------------------------------
; Compass Display in Surface Mode
;
	global	TFT_surface_compass_heading
TFT_surface_compass_heading:
	call	compass_heading_common		; compute heading
	WIN_STD	surf_compass_head_column,surf_compass_head_row

TFT_surface_compass_heading_com:		; show "000° N"
	FONT_COLOR_MEMO						; set default / dive-mode standard color
	movff	compass_heading_new+1,WREG	; get upper byte of actual heading
	btfsc	WREG,7						; compass calibrated?
	bra		TFT_compass_uncalibrated	; NO
	MOVII	compass_heading_shown,mpr	; get heading to be shown
	rcall	TFT_compass_helper			; show heading and its cardinal
	btfsc	divemode					; in dive mode?
	return								; YES - done for dive mode
	; in surface mode - shall show bearing?
	btfss	compass_bearing_set			; is a bearing set?
	return								; NO - done
	btfsc	compass_menu				; is the "set bearing" selection shown?
	return								; YES - done
	; show bearing
	WIN_SMALL surf_compass_bear_column,surf_compass_bear_row
	FONT_COLOR	color_yellow			; set font color
	MOVII	compass_bearing,mpr			; get bearing
	;bra	TFT_compass_helper			; show number and cardinal and return

TFT_compass_helper:
	output_999							; print bearing
	STRCAT	"° "						; append unit and a space
	call	tft_compass_cardinal		; append cardinal buffer
	PRINT								; dump to screen
	return								; done

TFT_compass_uncalibrated:
	STRCAT_PRINT "---°"					; print "---°"
	return								; done


;=============================================================================
compass_ops5	CODE
;=============================================================================


;-----------------------------------------------------------------------------
; Mask for Compass in Dive Mode
;
	global	TFT_dive_compass_mask
TFT_dive_compass_mask:
	FONT_COLOR_MASK						; select color
    	WIN_TINY dm_custom_compass_mask_column,dm_custom_compass_mask_row
	STRCPY_TEXT_PRINT tCompassMenu				; print label
	return


;-----------------------------------------------------------------------------
; Compass Display in Dive Mode
;
	global	TFT_dive_compass_heading
TFT_dive_compass_heading:
	call	compass_heading_common		; compute heading
	; Text output
	FONT_COLOR_MEMO						; set default / dive-mode standard color
	WIN_MEDIUM dm_custom_compass_head_column, dm_custom_compass_head_row
	MOVII	compass_heading_shown,mpr	; get heading to be shown
	bsf	leading_zeros
	output_999							; print bearing
	bcf	leading_zeros
	PRINT								; dump to screen
	WIN_STD dm_custom_compass_unit_column, dm_custom_compass_unit_row
	STRCAT	"°"
	call	tft_compass_cardinal		; append cardinal buffer
	PRINT
	; shall show bearing?
	btfss	compass_bearing_set			; is a bearing set?
	return								; NO - done
	; show bearing
	WIN_SMALL dm_compass_bear_column,dm_compass_bear_row
	FONT_COLOR	color_yellow			; set font color
	MOVII	compass_bearing,mpr			; get bearing
	goto	TFT_compass_helper			; show number and cardinal and return

tft_compass_cardinal:
	btfsc	hi,0						; heading > 255° ?
	bra		tft_compass_cardinal2		; YES - must be W, NW or N
										; NO  - must be W, SW, S, SE, E, NE or N
	movlw	.23
	subwf	lo,W
	btfss	STATUS,C
	bra		tft_compass_cardinal_N
	movlw	.68
	subwf	lo,W
	btfss	STATUS,C
	bra		tft_compass_cardinal_NE
	movlw	.113
	subwf	lo,W
	btfss	STATUS,C
	bra		tft_compass_cardinal_E
	movlw	.158
	subwf	lo,W
	btfss	STATUS,C
	bra		tft_compass_cardinal_SE
	movlw	.203
	subwf	lo,W
	btfss	STATUS,C
	bra		tft_compass_cardinal_S
	movlw	.248
	subwf	lo,W
	btfss	STATUS,C
	bra		tft_compass_cardinal_SW
	bra		tft_compass_cardinal_W

tft_compass_cardinal2:
	movlw	.37
	subwf	lo,W
	btfss	STATUS,C
	bra		tft_compass_cardinal_W
	movlw	.82
	subwf	lo,W
	btfss	STATUS,C
	bra		tft_compass_cardinal_NW
;	bra		tft_compass_cardinal_N

tft_compass_cardinal_N:
	STRCAT_TEXT	tN
	return
tft_compass_cardinal_NE:
	STRCAT_TEXT	tNE
	return
tft_compass_cardinal_E:
	STRCAT_TEXT	tE
	return
tft_compass_cardinal_SE:
	STRCAT_TEXT	tSE
	return
tft_compass_cardinal_S:
	STRCAT_TEXT	tS
	return
tft_compass_cardinal_SW:
	STRCAT_TEXT	tSW
	return
tft_compass_cardinal_W:
	STRCAT_TEXT	tW
	return
tft_compass_cardinal_NW:
	STRCAT_TEXT	tNW
	return

;=============================================================================
compass_ops6	CODE
;=============================================================================

;-----------------------------------------------------------------------------
; get and process heading
;
compass_heading_common:
	btfss	compass_enabled				; compass enabled?
	bra		compass_heading_common_zero	; NO

	; Get an averaged new heading
	movlw	compass_averaging			; number of averaging cycles
	movwf	up							; initialize loop counter
compass_heading_common_1:
	call	I2C_RX_compass				; test compass
	call	I2C_RX_accelerometer		; test accelerometer
	call	compass_filter				; filter raw compass + accelerometer readings
	decfsz	up,F						; decrement loop counter, done?
	bra		compass_heading_common_1	; NO  - loop

	call	compass						; do compass correction (C-code)
	banksel	common						; back to bank common

	; Check for calibration and change
	MOVII	compass_heading_shown,sub_a	; transfer shown heading to sub_a
	MOVII	compass_heading_new,  sub_b	; transfer new   heading to sub_b

	btfsc	sub_b+1,7					; valid compass calibration?
	bra		compass_heading_common_zero	; NO

	movf	sub_a+0,W					; get          shown heading, low  byte
	cpfseq	sub_b+0						; compare with new   heading, low  byte, equal?
	bra		compass_heading_common_2	; NO  - not equal
	movf	sub_a+1,W					; get          shown heading, high byte
	cpfseq	sub_b+1						; compare with new   heading, high byte, equal?
	bra		compass_heading_common_2	; NO  - not equal
	return								; YES - done

compass_heading_common_2:
	; turn both headings such that compass_heading_new points to 0°
	call	subU16						; sub_c = compass_heading_shown - compass_heading_new
	btfss	neg_flag					; was compass_heading_new in 1st halve?
	bra		compass_heading_common_3	; YES - check where compass_heading_shown is now
	MOVLI	.360, sub_a					; NO  - overturned, need to turn back to match 360°
	MOVII	sub_c,sub_b					;     - move overturned compass_heading_new to sub_b
	call	subU16						;     - sub_c = angle between overturned compass_heading_shown and 360°
compass_heading_common_3:
	; check if turned compass_heading_shown is in 1st or 2nd halve
	MOVII	sub_c,sub_a					; sub_a = turned compass_heading_shown
	MOVLI	.180, sub_b					; sub_b = begin of 2nd halve
	call	cmpU16						; check (turned compass_heading_shown) - 180°
	btfss	neg_flag					; result negative?
	bra		compass_heading_common_5	; NO  - in 2nd halve, increment towards compass_heading_new
	;bra	compass_heading_common_4	; YES - in 1st halve, decrement towards compass_heading_new

compass_heading_common_4:
	; decrement compass_heading_shown towards compass_heading_new
	rcall	compass_heading_stepsize_2	; calculate step size and put it into sub_b
	MOVII	compass_heading_shown,sub_a	; transfer unturned shown heading to  sub_a
	call	subU16						; decrement heading: sub_c = compass_heading_shown - step size
	btfss	neg_flag					; did an under-run occur?
	bra		compass_heading_common_6	; NO  - store result
	MOVLI	.360, sub_a					; YES - wrap around 360°
	MOVII	sub_c,sub_b					;     - transfer decrement result to sub_b
	call	subU16						;     - wrap decrement result around
	bra		compass_heading_common_6	;     - store wrapped result

compass_heading_common_5:
	; increment compass_heading_shown towards compass_heading_new
	rcall	compass_heading_stepsize_1	; calculate step size and put it into sub_b
	MOVII	compass_heading_shown,sub_a	; transfer unturned shown heading to  sub_a
	call	addU16						; increment heading: sub_c = compass_heading_shown + step size
	MOVII	sub_c,sub_a					; transfer increment result to sub_a
	MOVLI	.360, sub_b					; load wrap-around threshold
	call	subU16						; calculate if over-run occurred
	btfss	neg_flag					; did an over-run occur?
	bra		compass_heading_common_6	; YES - store already wrapped-around result
	MOVII	sub_a,sub_c					; NO  - retrieve former straight increment result
	bra		compass_heading_common_6	;     - store wrapped result

compass_heading_common_zero:
	CLRI	sub_c						; set   heading to 0°
	;bra	compass_heading_common_6	; store heading

compass_heading_common_6:
	MOVII	sub_c,compass_heading_shown	; store new shown heading
	return								; done

compass_heading_stepsize_1:
	; turn heading difference (180...359) into a step size
	MOVLI	.360, sub_a					; load 360°
	MOVII	sub_c,sub_b					; load difference
	call	subU16						; sub_c = 360 - difference (i.e. 1...180 now)
compass_heading_stepsize_2:
	; turn heading difference (1...180) into a step size
	bcf		STATUS,C					; clear carry
	rrcf	sub_c+0						; heading difference /= 2
	bcf		STATUS,C					; clear carry
	rrcf	sub_c+0						; heading difference /= 2, total /= 4 now
	incf	sub_c+0,f					; final += 1 to have one increment / decrement at least
	MOVII	sub_c,sub_b					; transfer result to sub_b
	return

 ENDIF	; _compass

;-----------------------------------------------------------------------------

	END
