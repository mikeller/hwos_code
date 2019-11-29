;=============================================================================
;
;   File compass_ops.asm                      combined next generation V3.06.1
;
;   Compass Operations
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================

#include	"hwos.inc"
#include	"i2c.inc"
#include	"tft_outputs.inc"
#include	"tft.inc"
#include	"strings.inc"
#include	"wait.inc"
#include	"surfmode.inc"
#include	"divemode.inc"
#include	"math.inc"
#include	"convert.inc"


 IFDEF _compass


; local flags
#DEFINE compass_show_cardinal	compass_flags,0		; =1: show the cardinal (N, NE, E, ...)
#DEFINE compass_bearing_eq		compass_flags,1		; =1: bearing is in direction, do not show << or >> 
#DEFINE compass_bearing_lft		compass_flags,2		; =1: bearing is to the left/<<, =0: to the right/>>
#DEFINE compass_bearing_vis		compass_flags,3		; =1: bearing is visible (either ahead or behind/-180°)
#DEFINE compass_bearing_ahd		compass_flags,4		; =1: bearing is ahead, =0: behind
;								compass_flags,5		; --- unused
;								compass_flags,6		; --- unused
;								compass_flags,7		; --- unused


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

	extern	option_save_all


compass_ops	code

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

;-----------------------------------------------------------------------------

compass_filter_init:
	MOVII	compass_DX,compass_DX_f
	MOVII	compass_DY,compass_DY_f
	MOVII	compass_DZ,compass_DZ_f

	MOVII	accel_DX,accel_DX_f
	MOVII	accel_DY,accel_DY_f
	MOVII	accel_DZ,accel_DZ_f
	return

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

;-----------------------------------------------------------------------------

	global	compass_calibration_loop
compass_calibration_loop:				; compass calibration
	bsf		block_sensor_interrupt		; disable sensor interrupts
	call	I2C_sleep_compass			; stop compass
	call	TFT_ClearScreen
	; Mask
	WIN_COLOR color_greenish
	WIN_SMALL .16,.0
	STRCPY_TEXT_PRINT tCompassMenu
	btfss	switch_right2				; wait until button is released
	bra		$-2

	call	TFT_standard_color
;	WIN_SMALL .0,.215
;	STRCPY_TEXT_PRINT tExit
	WAITMS	d'255'
	WAITMS	d'255'

	call	request_speed_fastest		; request CPU speed change to fastest speed

	movlw	.7							; initialize gain
	movff	WREG,opt_compass_gain

	movlw	.60							; initialize timeout to 60 seconds
	movwf	isr_timeout_reload			; copy WREG to isr_timeout_reload
	bsf		reset_timeout				; request ISR to reset the timeout
	bcf		trigger_timeout				; clear any pending timeout trigger
compass_calibration_gainset:			; reduce the gain, set bank here!
	banksel	opt_compass_gain			; select bank options table
	decf	opt_compass_gain,F			; reduce by one
	btfsc	STATUS,N					; < 0 ?
	clrf	opt_compass_gain			; YES - keep at zero
	btfsc	STATUS,N					; < 0 ?
	bra	compass_calibration_loop1		; YES - skip gain stuff (Would hang here in case of compass failure)
	banksel	common						; bank to bank common

	call	I2C_init_compass

	btfsc	compass_type3				; compass type 3 ?
	bra		compass_calibration_loop1	; YES - skip gain stuff
	btfsc	compass_type2				; compass type 2 ?
	bra		compass_calibration_loop1	; YES - skip gain stuff

	rcall	TFT_compass_show_gain		; show the current compass gain

	WAITMS	d'250'
	WAITMS	d'250'						; wait for first reading...

	movlw	.60							; calibration shall run for 60 seconds
	call	reset_timeout_time			; set timeout

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
	rcall	compass_filter				; filter compass raw data

	; Twice
	call	I2C_RX_compass				; read compass
	call	I2C_RX_accelerometer		; test accelerometer
	rcall	compass_filter				; filter compass raw data

;	btfsc	compass_type1				; compass1?
;	bra		compass_calibration_loop3	; YES -  skip gain stuff

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
	banksel	common						; back to bank common
;
;	; Three
;	call	I2C_RX_compass				; read compass
;	call	I2C_RX_accelerometer		; test accelerometer
;	call	compass_filter				; filter compass raw data
;
;	; Four times to get cleaner values
;	call	I2C_RX_compass				; read compass
;	call	I2C_RX_accelerometer		; test accelerometer
;	call	compass_filter				; filter compass raw data

compass_calibration_loop3:
	; and register only one value out of four:
	call	compass_add_calibration		; check and store new max/min values (C-code)
	banksel	common						; back to bank common

	rcall	TFT_compass_fast			; show values
	btfsc	trigger_timeout				; timeout (calibration done)?
	bra		compass_calibration_exit	; YES - done
	btfss	trigger_full_second			; NO  - new second begun?
	bra		compass_calibration_loop2	;       NO - loop
	bcf		trigger_full_second			;       YES - clear flag
	rcall	TFT_show_timeout_testmode	;           - show remaining time
	bra		compass_calibration_loop2	;           - loop

compass_calibration_exit:
	bcf		block_sensor_interrupt		; re-enable sensor interrupts

	call	compass_solve_calibration	; calculate calibration factors (C-code)
	banksel	common						; back to bank common

	call	request_speed_normal		; request CPU speed change to normal speed

	call	option_save_all				; save all settings into EEPROM
	movlw	.6
	movff	WREG,customview_surfmode	; set to compass view...
	goto	surfloop					; ...and exit

;-----------------------------------------------------------------------------

TFT_compass_fast:
	WIN_TINY .0,.50
	STRCPY	"Cx:"
	MOVII	compass_DX,mpr
	call	TFT_convert_signed_16bit	; convert lo:hi into signed-short and add '-' to POSTINC2 if required
	output_16
	STRCAT	" Cy:"
	MOVII	compass_DY,mpr
	call	TFT_convert_signed_16bit	; convert lo:hi into signed-short and add '-' to POSTINC2 if required
	output_16
	STRCAT	" Cz:"
	MOVII	compass_DZ,mpr
	call	TFT_convert_signed_16bit	; convert lo:hi into signed-short and add '-' to POSTINC2 if required
	output_16
	STRCAT_PRINT "  "

	WIN_TINY .0,.104
	STRCPY	"Ax:"
	MOVII	accel_DX,mpr
	call	TFT_convert_signed_16bit	; convert lo:hi into signed-short and add '-' to POSTINC2 if required
	output_16
	STRCAT	" Ay:"
	MOVII	accel_DY,mpr
	call	TFT_convert_signed_16bit	; convert lo:hi into signed-short and add '-' to POSTINC2 if required
	output_16
	STRCAT	" Az:"
	MOVII	accel_DZ,mpr
	call	TFT_convert_signed_16bit	; convert lo:hi into signed-short and add '-' to POSTINC2 if required
	output_16
	STRCAT_PRINT "  "
	return

TFT_show_timeout_testmode:
	WIN_TINY .0,.68
	STRCPY	"T:"
	movff	isr_timeout_timer,lo
	bsf		leftbind
	output_8							; display remaining time
	bcf		leftbind
	STRCAT_PRINT "s "
	return

TFT_compass_show_gain:					; show the current compass gain
;	movff	opt_compass_gain,lo			; 0-7 (230 LSB/Gauss to 1370 LSB/Gauss)
;	tstfsz	lo
;	return								; do not show unless gain=0
	WIN_TINY .0,.86
	STRCPY_TEXT tCompassGain
	movff	opt_compass_gain,lo			; 0-7 (230 LSB/Gauss to 1370 LSB/Gauss)
	bsf		leftbind
	output_8
	bcf		leftbind
	STRCAT_PRINT ""
	return

;-----------------------------------------------------------------------------

	global	TFT_surface_compass_mask
TFT_surface_compass_mask:
	WIN_SMALL surf_compass_mask_column,surf_compass_mask_row
	call	TFT_standard_color
	STRCPY_TEXT_PRINT tHeading			; print "Heading:"
	return


	global	TFT_dive_compass_mask		; draws the white box around the heading tape
TFT_dive_compass_mask:
	WIN_FRAME_STD dm_custom_compass_graph_row, dm_custom_compass_graph_row+dm_custom_compass_graph_height, .0, .159
	return


	global	TFT_surface_compass_heading
TFT_surface_compass_heading:
	rcall	compass_heading_common
	WIN_STD	surf_compass_head_column,surf_compass_head_row
	call	TFT_standard_color
TFT_surface_compass_heading_com:		; show "000° N"
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
	call	TFT_attention_color
	MOVII	compass_bearing,mpr			; get bearing
	;bra	TFT_compass_helper			; show number and cardinal and return

TFT_compass_helper:
	bsf		leftbind
	output_16dp .2						; result is "0.000" in buffer
	bcf		leftbind
	; rearrange figures to "000"
	movff	buffer+2,buffer+0
	movff	buffer+3,buffer+1
	movff	buffer+4,buffer+2
	lfsr	FSR2,buffer+3
	STRCAT	"° "
	rcall	tft_compass_cardinal		; add cardinal to POSTINC2
	STRCAT_PRINT ""						; finalize output
	return								; done

TFT_compass_uncalibrated:
	STRCAT_PRINT "---°"					; print "---°"
	return								; done


	global	TFT_dive_compass_heading
TFT_dive_compass_heading:
	rcall	compass_heading_common
	WIN_FONT FT_SMALL					; set font size

;	; ### for development only, hard-coding the bearing ###
;	; 244° : SW - W
;	MOVLI	.244,xA						; xA used as temp
;	MOVII	xA,compass_bearing			; compass_bearing is stored in bank isr_backup

	MOVII	compass_heading_shown,xA
	; 160° viewing angle: add +360 offset if xA <= 292 for non-negative scale
	MOVLI	.292,sub_a
	MOVII	xA,  sub_b
	call	subU16						; sub_c = sub_a - sub_b
	btfsc	neg_flag					; xA > 292 ?
	bra		TFT_dive_compass_heading_1	; YES
	ADDLI	.360,xA						; NO  - add offset
TFT_dive_compass_heading_1:
	SUBLI	.80,xA						; subtract 80 (left pixel offset from the center)
	MOVII	xA,xRD						; save result to xRD
	ADDLI	.160,xA						; add 160 (display with in pixels)
	MOVII	xA,xRDr						; save result to xRDr

	btfss	compass_bearing_set			; is a bearing set?
	bra		TFT_dive_compass_ruler		; NO  - skip next calculations
	MOVII	xRDr,sub_a					; YES - calculate xRD180 = xRDr - 180
	MOVLI	.180,sub_b
	call	subU16						; sub_c = sub_a - sub_b
	MOVII	sub_c,xRD180

TFT_dive_compass_bearing_1:
	; calculate bearing position and visibility (ahead or behind)
	bcf		compass_bearing_vis			; default is not-visible
	bcf		compass_bearing_ahd			; default is behind
	MOVII	compass_bearing,xA
	ADDLI	.360,xA						; calculate the bearing virtual display offset
	MOVII	xA,divA						; save it for reuse for upper/lower turns and ahead/behind checks

	; check if bearing is ahead
	MOVII	divA,sub_a					; load the bearing offset into sub_a
	MOVII	xRD, sub_b					; load the display offset back to sub_b
	rcall	TFT_dive_compass_bearing_ap
	btfsc	compass_bearing_vis			; bearing visible?
	bra		TFT_dive_compass_bearing_dir; YES

	; check if it is ahead with an upper turn
	MOVII	divA,sub_a					; load the bearing offset into sub_a
	MOVII	xRD, sub_b					; load the display offset back to sub_b
	ADDLI	.360,sub_b
	rcall	TFT_dive_compass_bearing_ap
	btfsc	compass_bearing_vis			; bearing visible?
	bra		TFT_dive_compass_bearing_dir; YES

	; check if it is ahead with a lower turn
	MOVII	divA,sub_a					; load the bearing offset into sub_a
	ADDLI	.360,sub_a
	MOVII	xRD, sub_b					; load the display offset back to sub_b
	rcall	TFT_dive_compass_bearing_ap
	btfsc	compass_bearing_vis			; bearing visible?
	bra		TFT_dive_compass_bearing_dir; YES

	; marker is not ahead of us, check if it is behind of us
	; use the (160 - (xRD180 - xCM)) formula to see if it's on the display
	MOVII	xRD180,sub_a				; load the display offset back to sub_a
	MOVII	divA,  sub_b				; load the marker's offset into sub_b
	rcall	TFT_dive_compass_bearing_bp
	btfsc	compass_bearing_vis			; bearing behind of us?
	bra		TFT_dive_compass_bearing_dir; YES

	; check if it is behind with the upper turn
	MOVII	xRD180,sub_a
	MOVII	divA,  sub_b
	ADDLI	.360,  sub_b
	rcall	TFT_dive_compass_bearing_bp
	btfsc	compass_bearing_vis			; bearing behind of us?
	bra		TFT_dive_compass_bearing_dir; YES

	; check if it is behind with the lower turn
	MOVII	xRD180,sub_a
	ADDLI	.360,  sub_a
	MOVII	divA,  sub_b				; load the marker's offset into sub_b
	rcall	TFT_dive_compass_bearing_bp
	bra		TFT_dive_compass_bearing_dir

TFT_dive_compass_bearing_ap:
	; xCM received in sub_a
	; xRD received in sub_b
	; 1/a. check if it's viewable from the left side
	call	subU16						; sub_c = sub_a - sub_b
	btfsc	neg_flag					; xRD > divA ?
	return								; NO  - done
	MOVII	sub_c,xC					; YES - store the RO=RP-RD for drawing
	; 1/b. check if it's viewable from the right side
	ADDLI	  .2,sub_a					; avoid thin mess on the side of the display
	ADDLI	.158,sub_b					; load the display offset right side into sub_b
	call	subU16						; sub_c = sub_a - sub_b
	btfss	neg_flag					; xRDr > xA(+2) ?
	return								; NO  - done
										; YES - print the bearing lines on the screen
	movff	xC+0,xCM
	bsf		compass_bearing_vis			; set visible
	bsf		compass_bearing_ahd			; set ahead
	return								; done

TFT_dive_compass_bearing_bp:
	; use the (160 - (xRD180 - xCM)) formula to see if it's on the display
	; the marker's offset received in sub_b
	; the xRD180 display offset received in sub_a
	; xRD180 - xCM
	call	subU16						; sub_c = sub_a - sub_b
	btfsc	neg_flag					; CM > xRD180 ?
	return								; NO -  not on screen, done
										; YES - check 160 - (X)
	MOVLI	.158, sub_a					; 158 to avoid thin mess on the side of the display
	MOVII	sub_c,sub_b
	call	subU16						; sub_c = sub_a - sub_b
	btfsc	neg_flag					; X > 160 ?
	return								; NO - not on screen, done
	; check if not overflow - this sounds like a double check...
	tstfsz	sub_c+1						; high byte = 0 ?
	return								; NO - sub_c must be > 160 then, done
	movlw	d'158'						; YES - load a 158
	cpfslt	sub_c+0						;     - low byte < 158 ?
	return								;       NO  - done
	movff	sub_c+0,xCM					;       YES - print the bearing lines on the screen
	bsf		compass_bearing_vis			;           - flag to show bearing lines
	return								;           - done

TFT_dive_compass_bearing_dir:
	; check if bearing to heading, and calculate the direction
	bcf		compass_bearing_eq
	btfss	compass_bearing_vis
	bra		TFT_dive_compass_bearing_lr
	btfss	compass_bearing_ahd
	bra		TFT_dive_compass_bearing_lr
	movff	xCM,xA+0
	movlw	d'80'
	cpfseq	xA+0
	bra		TFT_dive_compass_bearing_lr
	bsf		compass_bearing_eq
	bra		TFT_dive_compass_ruler		; bearing points to heading, no signs are required, go to the ruler

TFT_dive_compass_bearing_lr:
	; get the bearing virtual display offset
	MOVII	compass_bearing,xA
	; xA = xA > 292 ? xA : xA+360
	MOVLI	.292,sub_a
	MOVII	xA,  sub_b
	call	subU16						; sub_c = sub_a - sub_b
	btfsc	neg_flag					; xA > 292 ?
	bra		TFT_dive_compass_bearing_lr_1; YES
	ADDLI	.360,xA						; NO  - add 360

TFT_dive_compass_bearing_lr_1:
	; 1. calculate whether bearing is to left or to right
	bsf		compass_bearing_lft			; to the left by default
	; xC: save center value to compare the direction to front value
	MOVII	xA,xC
	; xB: we need the left side for comparison... left = -180
	MOVII	xA,  sub_a
	MOVLI	.180,sub_b
	call	subU16						; sub_c = sub_a - sub_b
	MOVII	sub_c,xB					; xB has the left side of the 180° distance center
	; xA = xRD > (xC+100) ? RD-280 : xRD+80
	MOVII	xC,  sub_a
	ADDLI	.100,sub_a
	MOVII	xRD, sub_b
	call	subU16						; sub_c = sub_a - sub_b
	btfsc	neg_flag					; xRD > xC + 100 ?
	bra		TFT_dive_compass_bearing_lr_2; YES - xA = xRD - 280
										; NO  - xA = xRD + 80
	MOVII	xRD,xA
	ADDLI	.80,xA
	bra		TFT_dive_compass_bearing_lr_c

TFT_dive_compass_bearing_lr_2:
	MOVII	xRD,sub_a
	MOVLI	.280,sub_b
	call	subU16						; sub_c = sub_a - sub_b
	MOVII	sub_c,xA
	;bra	TFT_dive_compass_bearing_lr_c

TFT_dive_compass_bearing_lr_c:
	; xB < xA < xC => right, otherwise left (default)
	MOVII	xA,sub_b
	MOVII	xB,sub_a
	call	subU16						; sub_c = sub_a - sub_b
	btfss	neg_flag					; xA > xB ?
	bra		TFT_dive_compass_ruler		; NO - xB >= xA, keep default left
	MOVII	xA,sub_a
	MOVII	xC,sub_b
	call	subU16						; sub_c = sub_a - sub_b
	btfss	neg_flag					; xC > xA ?
	bra		TFT_dive_compass_ruler		; NO - xA >= xC, keep default left
	bcf		compass_bearing_lft

TFT_dive_compass_ruler:
	; calculate mod15 for the ticks
	MOVII	xRD,xA
	MOVLI	.15,xB
	call	div16x16					; xA/xB=xC with xA+0 as remainder
	; check the remainder
	movlw	d'0'
	cpfsgt	xA+0						; mod15 > 0 ?
	bra		TFT_dive_compass_ruler_1	; NO  - RM = 0
										; YES - RM = 15 - RDmod15
	movlw	d'15'
	subfwb	xA+0,F
TFT_dive_compass_ruler_1:
	movff	xA+0,lo						; xA+0 holds the RM, store it to 'lo'
	clrf	hi							; initialize DD to zero, store it to 'hi'

TFT_dive_compass_ruler_loop:
	; 1. check if we run out of the display
	movlw	d'159'						; looks like 159 works because TFT_box limits the display
	cpfslt	lo,1
	bra		TFT_dive_compass_ruler_lend	; xRM >= W
	; 2. Clear the tick area from DD to RM - in segments to avoid blinking
	;    don't do a clear if we are at 0 (zero) otherwise it will blink
	;    because of the width underflow
	movlw	d'0'
	cpfsgt	lo,1
	bra		TFT_dive_compass_ruler_loop_zz
	rcall	TFT_dive_compass_clr_ruler
TFT_dive_compass_ruler_loop_zz:
	; 3. Draw the markers @ RM
	;    we receive RM in lo and DD in hi
	movlw	d'2'
	movwf	win_bargraph				; set with of  ticks
	movwf	win_width+0
	clrf	win_width+1
	movff	lo,win_leftx2				; 0..159
	movlw	dm_custom_compass_tick_top_top
	movwf	win_top						; set position for upper ticks
	movlw	dm_custom_compass_tick_height
	movwf	win_height					; set hight of ticks
	call	TFT_standard_color			; set color
	call	TFT_box						; draw tick
	movlw	dm_custom_compass_tick_bot_top
	movwf	win_top						; set position for lower ticks
	movlw	dm_custom_compass_tick_height
	movwf	win_height					; set hight of ticks
	call	TFT_standard_color			; color in WREG is trashed, must be set again!
	call	TFT_box						; draw tick
	; 4. If D < 82 and RM > 79: means we put something over the center line,
	;							so redraw the center line
	movlw	d'82'
	cpfslt	hi,1
	bra		TFT_dive_compass_ruler_loop_zz2
	movlw	d'79'
	cpfsgt	lo,1
	bra		TFT_dive_compass_ruler_loop_zz2
	; enough to print center line as bearing marker is not in the ticker area
	rcall	TFT_dive_compass_c			; draw center line in yellow
TFT_dive_compass_ruler_loop_zz2:
	; 5. set D = RM + 2 : position after the 2px tick
	movff	lo,hi
	movlw	d'2'
	addwf	hi,F
	; 6. set RM = RM + 15 : position to the next tick
	movlw	d'15'
	addwf	lo,F
	; 7. loop
	bra		TFT_dive_compass_ruler_loop

TFT_dive_compass_ruler_lend:			; loop end
	; 8. clear the rest of the tick area if D < 160
	movlw	d'160'
	cpfslt	hi
	bra		TFT_dive_compass_labels		 ; D >= W
	; 9. position left to end of display to clear the remaining area
	movlw	d'159'
	movwf	lo
	; 10. clear it
	rcall	TFT_dive_compass_clr_ruler

TFT_dive_compass_labels:
	; done with the compass ruler, put the labels on the screen
	clrf	hi							; hi stores the display position
	movff	hi,xHI						; bank-safe clear of xHI
	clrf	lo							; lo stores the last item's display position
	movff	lo,xLO						; bank-safe clear of xLO
	MOVLI	.219,sub_a					; position of the cardinal
	MOVII	xRD, sub_b					; get the RD back to sub_b
	rcall	TFT_dive_compass_label_proc	; check if the cardinal shall be on screen
	btfss	compass_show_cardinal		; shall show cardinal?
	bra		dcr_1						; NO
	STRCPY_TEXT_PRINT tSW				; YES - print it
dcr_1:
	rcall	TFT_dive_compass_c_mk		; check if cardinal is on the center line or the marker
	MOVLI	.267,sub_a					; position of the cardinal
	rcall	TFT_dive_compass_label_proc	; check if the cardinal shall be on screen
	btfss	compass_show_cardinal		; shall show cardinal?
	bra		dcr_2						; NO
	STRCPY_TEXT_PRINT tW				; YES - print it
dcr_2:
	rcall	TFT_dive_compass_c_mk		; check if cardinal is on the center line or the marker
	MOVLI	.309,sub_a					; position of the cardinal
	rcall	TFT_dive_compass_label_proc	; check if the cardinal shall be on screen
	btfss	compass_show_cardinal		; shall show cardinal?
	bra		dcr_3						; NO
	STRCPY_TEXT_PRINT tNW				; YES - print it
dcr_3:
	rcall	TFT_dive_compass_c_mk		; check if cardinal is on the center line or the marker
	MOVLI	.358,sub_a					; position of the cardinal
	rcall	TFT_dive_compass_label_proc	; check if the cardinal shall be on screen
	btfss	compass_show_cardinal		; shall show cardinal?
	bra		dcr_4						; NO
	STRCPY_TEXT_PRINT tN				; YES - print it
dcr_4:
	rcall	TFT_dive_compass_c_mk		; check if cardinal is on the center line or the marker
	MOVLI	.399,sub_a					; position of the cardinal
	rcall	TFT_dive_compass_label_proc	; check if the cardinal shall be on screen
	btfss	compass_show_cardinal		; shall show cardinal?
	bra		dcr_5						; NO
	STRCPY_TEXT_PRINT tNE				; YES - print it
dcr_5:
	rcall	TFT_dive_compass_c_mk		; check if cardinal is on the center line or the marker
	MOVLI	.448,sub_a					; position of the cardinal
	rcall	TFT_dive_compass_label_proc	; check if the cardinal shall be on screen
	btfss	compass_show_cardinal		; shall show cardinal?
	bra		dcr_6						; NO
	STRCPY_TEXT_PRINT	tE				; YES - print it
dcr_6:
	rcall	TFT_dive_compass_c_mk		; check if cardinal is on the center line or the marker
	MOVLI	.489,sub_a					; position of the cardinal
	rcall	TFT_dive_compass_label_proc	; check if the cardinal shall be on screen
	btfss	compass_show_cardinal		; shall show cardinal?
	bra		dcr_7						; NO
	STRCPY_TEXT_PRINT	tSE				; YES - print it
dcr_7:
	rcall	TFT_dive_compass_c_mk		; check if cardinal is on the center line or the marker
	MOVLI	.538,sub_a					; position of the cardinal
	rcall	TFT_dive_compass_label_proc	; check if the cardinal shall be on screen
	btfss	compass_show_cardinal		; shall show cardinal?
	bra		dcr_8						; NO
	STRCPY_TEXT_PRINT tS				; YES - print it
dcr_8:
	rcall	TFT_dive_compass_c_mk		; check if cardinal is on the center line or the marker
	MOVLI	.579,sub_a					; position of the cardinal
	rcall	TFT_dive_compass_label_proc	; check if the cardinal shall be on screen
	btfss	compass_show_cardinal		; shall show cardinal?
	bra		dcr_9						; NO
	STRCPY_TEXT_PRINT tSW				; YES - print it
dcr_9:
	rcall	TFT_dive_compass_c_mk		; check if cardinal is on the center line or the marker
	MOVLI	.627,sub_a					; position of the cardinal
	rcall	TFT_dive_compass_label_proc	; check if the cardinal shall be on screen
	btfss	compass_show_cardinal		; shall show cardinal?
	bra		dcr_10						; NO
	STRCPY_TEXT_PRINT tW				; YES - print it
dcr_10:
	rcall	TFT_dive_compass_c_mk		; check if cardinal is on the center line or the marker
	MOVLI	.669,sub_a					; position of the cardinal
	rcall	TFT_dive_compass_label_proc	; check if the cardinal shall be on screen
	btfss	compass_show_cardinal		; shall show cardinal?
	bra		dcr_11						; NO
	STRCPY_TEXT_PRINT tNW				; YES - print it
dcr_11:
	rcall	TFT_dive_compass_c_mk		; check if cardinal is on the center line or the marker
	MOVLI	.718,sub_a					; position of the cardinal
	rcall	TFT_dive_compass_label_proc	; check if the cardinal shall be on screen
	btfss	compass_show_cardinal		; shall show?
	bra		dcr_12						; NO
	STRCPY_TEXT_PRINT tN				; YES - print it
dcr_12:
	rcall	TFT_dive_compass_c_mk		; check if cardinal is on the center line or the marker

TFT_dive_compass_label_end:
	rcall	TFT_dive_compass_c_mk		; check if cardinal is on the center line or the marker
	; restore lo and hi for the final cleanup
	movff	xLO,lo						; xLO and xHI are stored in bank isr_backup
	movff	xHI,hi
	; clear the rest of the SQ area if there is more space
	movlw	d'159'
	cpfslt	hi
	bra		TFT_dive_compass_label_end2	; D >= 160, no more space
	; position left to end of display to clear the remaining area
	movlw	d'158'
	movwf	lo
	; clear it
	rcall	TFT_dive_compass_clr_label
TFT_dive_compass_label_end2:
	rcall	TFT_dive_compass_c_mk		; check if cardinal is on the center line or the marker
	; do we have bearing set?
	btfsc	compass_bearing_set			; bearing set?
	bra		TFT_dive_compass_dir_text	; YES - print the direction (<< or >>)
	rcall	TFT_dive_compass_dir_lclr	; NO  - clear the area (e.g. we had but removed)
	rcall	TFT_dive_compass_dir_rclr
	bra		TFT_dive_compass_text

TFT_dive_compass_dir_text:
	; bearing set, but does it point to heading?
	btfss	compass_bearing_eq
	bra		TFT_dive_compass_dir_text_2	; bearing != heading - go and print the direction
	rcall	TFT_dive_compass_dir_lclr	; bearing == heading - no need for direction markers
	rcall	TFT_dive_compass_dir_rclr
	bra		TFT_dive_compass_text

TFT_dive_compass_dir_text_2:
	movlw	color_green
	call	TFT_set_color
	btfsc	compass_bearing_lft
	bra		TFT_dive_compass_dir_ldir	; bearing_lft=1, print the left marker
;TFT_dive_compass_text_rdir:
	WIN_SMALL dm_custom_compass_rdir_column, dm_custom_compass_head_row-.2
	STRCPY_PRINT ">>"
	rcall	TFT_dive_compass_dir_lclr	; do not forget to clear the left
	bra		TFT_dive_compass_text

TFT_dive_compass_dir_ldir:
	WIN_SMALL dm_custom_compass_ldir_column, dm_custom_compass_head_row-.2
	STRCPY_PRINT "<<"
	rcall	TFT_dive_compass_dir_rclr	; do not forget to clear the right
	;bra	TFT_dive_compass_text

TFT_dive_compass_text:
	; Clear some unused space on the right mH
	WIN_BOX_BLACK dm_custom_compass_tick_top_bot+.1,dm_custom_compass_tick_bot_top-.1,.158,.159	; top, bottom, left, right

	; Text output
	call	TFT_standard_color
	WIN_SMALL dm_custom_compass_head_column, dm_custom_compass_head_row
	rcall	TFT_surface_compass_heading_com	; show "xxx° N"
	return

TFT_dive_compass_dir_lclr:
	WIN_SMALL dm_custom_compass_ldir_column, dm_custom_compass_head_row-.2
	STRCPY_PRINT "  "
	return

TFT_dive_compass_dir_rclr:
	WIN_SMALL dm_custom_compass_rdir_column, dm_custom_compass_head_row-.2
	STRCPY_PRINT "  "
	return

TFT_dive_compass_label_proc:
	movlw	d'14'
	movwf	up							; cardinal width in px
	bcf		compass_show_cardinal
	; 1/a. check if it's viewable ? sub_a(RP) >= sub_b(RD) ?
	;      set the carry flag if sub_b(xRD) is equal to or greater than sub_a(xRP):
	MOVII	xRD,sub_b
	call	subU16						; sub_c = sub_a - sub_b
	btfsc	neg_flag					; >= 0 ?
	return								; NO
	; store the RO=RP-RD for drawing
	MOVII	sub_c,xC

	; 1/b. check if it's viewable ? sub_a(RP)+up(width) < sub_b(RD)+160
	;      if already above, no need to process the rest of the labels
	movff	up,WREG						; take care about the width
	addwf	sub_a+0,1
	btfsc	STATUS, C
	incf	sub_a+1

	MOVII	xRDr,sub_b
	call	subU16	 					; sub_c = sub_a - sub_b
	btfss	neg_flag					; < 0 ?
	bra		TFT_dive_compass_label_end	; NO

	; 2. restore RO=RP-RD from 1/a.
	movff	xC+0,lo

	; 3. Clear the segment from DD(hi) to lo
	;    don't do a clear if we are at 0 (zero) otherwise it will blink
	;   ?because of the width underflow?
	movlw	d'1'
	cpfsgt	lo
	bra		TFT_dive_compass_label_proc_p
	rcall	TFT_dive_compass_clr_label
TFT_dive_compass_label_proc_p:
	; 4. print the SQ on the screen
	call	TFT_standard_color
	bsf		compass_show_cardinal
;TFT_dive_compass_label_print:
	movlw	dm_custom_compass_label_row
	movff	WREG,win_top
	movff	lo,win_leftx2
	WIN_FONT FT_SMALL
	; 6. retain the new display positions
	movff	lo,hi
	movff	up,WREG
	addwf	hi,F
	movff	lo,xLO
	movff	hi,xHI
	return

TFT_dive_compass_c_mk:
	; Common task to draw center line and marker
	; until a proper implementation make it simple:
	rcall	TFT_dive_compass_mk
TFT_dive_compass_c:
	movlw	color_yellow
	WIN_BOX_COLOR dm_custom_compass_tick_top_top, dm_custom_compass_tick_bot_bot,.80,.81 ; center line in yellow
	return

TFT_dive_compass_mk:
	; draw the bearing on the screen if visible and if we just put something over it
	btfss	compass_bearing_set			; bearing set?
	return								; NO  - done
	btfss	compass_bearing_vis			; YES - bearing visible?
	return								;       NO  - bearing set but not visible, done

	; save lo/hi from trashing
	MOVII	mpr,xA

	; did we just update the marker's position?
	; DD.......DD
	; CM+2>=DD(old) or CM-2<=DD
	; ToDo

	btfss	compass_bearing_ahd
	bra		TFT_dive_compass_mk_rear
;TFT_dive_compass_mk_front:
	clrf	lo
	movff	xCM,lo
	bsf		compass_show_cardinal		; set=green marker
	rcall	TFT_dive_compass_mk_print
	bcf		compass_show_cardinal
	bra		TFT_dive_compass_mk_end

TFT_dive_compass_mk_rear:
	clrf	lo
	movff	xCM,lo
	bcf		compass_show_cardinal		; set=red marker
	rcall	TFT_dive_compass_mk_print

TFT_dive_compass_mk_end:
	MOVII	xA,mpr
	return

TFT_dive_compass_mk_print:
	movlw	d'1'
	cpfsgt	lo
	bra		TFT_dive_compass_mk_print_2	; lo <= 1, skip the first line
	movlw	d'2'
	subwf	lo,0
;	movff	WREG,win_leftx2
	rcall	TFT_dive_compass_mk_print_3
TFT_dive_compass_mk_print_2:
	; save hi/lo
	MOVII	mpr,divA
	; clear the middle of the bearing marker
	movff	lo,hi
	movlw	d'2'
	addwf	lo,1
	rcall	TFT_dive_compass_clr_label
	; restore hi/lo
	MOVII	divA,mpr
	; print a dot on the middle
	movf	lo,W
	rcall	TFT_dive_compass_mk_print_dot
	; finally print the right marker line
	movlw	d'2'
	addwf	lo,0
;	rcall	TFT_dive_compass_mk_print_3
;	return
TFT_dive_compass_mk_print_3:
	movwf	win_leftx2
	movlw	dm_custom_compass_label_row
	movwf	win_top
	movlw	dm_custom_compass_label_height-.2
	movwf	win_height
	bra		TFT_dive_compass_mk_print_4
TFT_dive_compass_mk_print_dot:
	movwf	win_leftx2
	movlw	dm_custom_compass_label_row + .9
	movwf	win_top
	movlw	d'4'
	movwf	win_height
TFT_dive_compass_mk_print_4:
	movlw	.158
	cpfslt	win_leftx2
	bra		TFT_dive_compass_mk_print_5
	movlw	d'2'
	movwf	win_bargraph
	movwf	win_width+0
	clrf	win_width+1
	movlw	color_green
	btfss	compass_show_cardinal
	movlw	color_red
	call	TFT_set_color
	call	TFT_box
TFT_dive_compass_mk_print_5:
	return

TFT_dive_compass_clr_label:
	movlw	dm_custom_compass_label_row-.2	; set top & height
	movwf	win_top
	movlw	dm_custom_compass_label_height+.2
	movwf	win_height
	rcall	TFT_dive_compass_clear
	return

TFT_dive_compass_clr_ruler:
	; top tick
	movlw	dm_custom_compass_tick_top_top	; set top & height
	movwf	win_top
	movlw	dm_custom_compass_tick_height
	movwf	win_height
	rcall	TFT_dive_compass_clear
	;bottom tick
	movlw	dm_custom_compass_tick_bot_top	; set top & height
	movwf	win_top
	movlw	dm_custom_compass_tick_height
	movwf	win_height
;	rcall	TFT_dive_compass_clear
;	return
TFT_dive_compass_clear:
	; we receive RM in lo and DD in hi
	; calculate width = RM-D
	movf	hi,W
	subwf	lo,W
	bz		TFT_dive_compass_clear3		; do nothing if there is nothing to do
	movwf	win_width+0					; RM-DD
	movwf	win_bargraph
	clrf	win_width+1
	movlw	.1
	cpfsgt	win_width+0
	bra		TFT_dive_compass_clear3		; do not clear a single pixel (or less)
	movff	hi,win_leftx2
	movlw	color_black
	call	TFT_set_color
	call	TFT_box
TFT_dive_compass_clear3:
	return

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

;-----------------------------------------------------------------------------

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

	END
