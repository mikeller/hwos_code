;=============================================================================
;
;   File tft_outputs.asm							REFACTORED VERSION	V2.98
;
;   Startup subroutines
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;  2011-08-07 : [mH] moving from OSTC code

#include "hwos.inc"							; Mandatory header
#include "shared_definitions.h"				; Mailbox from/to p2_deco.c
#include "tft.inc"
#include "start.inc"
#include "wait.inc"
#include "strings.inc"
#include "convert.inc"
#include "varargs.inc"
#include "math.inc"
#include "isr.inc"
#include "eeprom_rs232.inc"
#include "adc_lightsensor.inc"
#include "surfmode.inc"
#include "divemode.inc"
#include "external_flash.inc"
#include "ghostwriter.inc"
#include "customview.inc"
#include "i2c.inc"
#include "colorschemes.inc"
#include "calibrate.inc"


	extern	aa_wordprocessor

;=============================================================================

gui		CODE

;=============================================================================

	global	TFT_divemask_color
TFT_divemask_color:
	movlw	color_green
	btfsc	divemode					; in Divemode?
	rcall	TFT_divemask_color_dive
	bra		TFT_standard_color0

TFT_divemask_color_dive:
	movff	opt_dive_color_scheme,WREG	; 0-3
	incf	WREG
	dcfsnz	WREG
	retlw	color_scheme_divemode_mask1	;0
	dcfsnz	WREG
	retlw	color_scheme_divemode_mask2	;1
	dcfsnz	WREG
	retlw	color_scheme_divemode_mask3	;2
	retlw	color_scheme_divemode_mask4	;3


	global	TFT_attention_color
TFT_attention_color:
	movlw	color_yellow				; make this configurable?
	bra		TFT_standard_color0
TFT_attention_color_dive:
	retlw	color_yellow				; make this configurable?


	global	TFT_warnings_color
TFT_warnings_color:
	movlw	color_red					; make this configurable?
	bra		TFT_standard_color0
TFT_warnings_color_dive:
	retlw	color_red					; make this configurable?


	global	TFT_disabled_color
TFT_disabled_color:
	;movlw	color_grey					; Default to OSTC grey (dark blue)
	movlw	color_lightblue
	btfsc	divemode					; in Divemode?
	rcall	TFT_disabled_color_dive		; YES
	bra		TFT_standard_color0

TFT_disabled_color_dive:
	movff	opt_dive_color_scheme,WREG	; 0-3
	incf	WREG
	dcfsnz	WREG
	retlw	color_scheme_divemode_dis1	; 0
	dcfsnz	WREG
	retlw	color_scheme_divemode_dis2	; 1
	dcfsnz	WREG
	retlw	color_scheme_divemode_dis3	; 2
	retlw	color_scheme_divemode_dis4	; 3


	global	TFT_standard_color
TFT_standard_color:
	setf	WREG						; Default white
	btfsc	divemode					; in Divemode?
	rcall	TFT_standard_color_dive
	;bra	TFT_standard_color0

TFT_standard_color0:
	goto	TFT_set_color				; and return...


TFT_standard_color_dive:
	movff	opt_dive_color_scheme,WREG	; 0-3
	incf	WREG
	dcfsnz	WREG
	retlw	color_scheme_divemode_std1	;0
	dcfsnz	WREG
	retlw	color_scheme_divemode_std2	;1
	dcfsnz	WREG
	retlw	color_scheme_divemode_std3	;2
	retlw	color_scheme_divemode_std4	;3


	global	TFT_color_code_gaslist
TFT_color_code_gaslist:					; Color-code current row in Gaslist (%O2 in hi) according to current amb_pressure
; Check very high ppO2 manually
	SAFE_2BYTE_COPY amb_pressure,xA
	movlw	d'10'
	movwf	xB+0
	clrf	xB+1
	call	div16x16					; xC=p_amb/10
	movff	xC+0,xA+0
	movff	xC+1,xA+1
	movff	hi,xB+0
	clrf	xB+1
	call	mult16x16					; hi * p_amb/10
; Check if ppO2>6,55bar
	tstfsz	xC+2						; char_I_O2_ratio * p_amb/10 > 65536, ppO2>6,55bar?
	bra		TFT_warnings_color			; Yes, warn in warning color
; Check if ppO2>3,30bar
	btfsc	xC+1,7
	bra		TFT_warnings_color			; Yes, warn in warning color
; Check for low ppo2
	movff	xC+0,sub_a+0
	movff	xC+1,sub_a+1
	movff	char_I_ppO2_min,WREG
	mullw	d'100'						; char_I_ppO2_min*100
	movff	PRODL,sub_b+0
	movff	PRODH,sub_b+1
	call	subU16
	btfsc	neg_flag
	bra		TFT_warnings_color			; too low -> Warning Color!
; Check for high ppo2
	movff	char_O_deco_warnings,WREG	; bank-safe copy of deco warnings
	btfsc	WREG,deco_flag				; are we in deco?
	bra		TFT_color_code_gaslist_deco	; YES - take deco max
	movff	char_I_ppO2_max,WREG		; No  - take travel/bottom max
	bra		TFT_color_code_gaslist_com
TFT_color_code_gaslist_deco:
	movff	char_I_ppO2_max_deco,WREG	; ppo2 max for deco
TFT_color_code_gaslist_com:
	mullw	d'100'						; char_I_ppO2_max*100
	movff	PRODL,sub_b+0
	movff	PRODH,sub_b+1
	infsnz	sub_a+0,F
	incf	sub_a+1,F					; add 1mbar to avoid warning on equal
	call	subU16						; sub_c = sub_a - sub_b
	btfss	neg_flag
	bra		TFT_warnings_color			; too high -> Warning Color!
	return


TFT_color_code_ceiling:					; color-code the ceiling depth
	btfsc	hi,char_invalid_flag		; is the invalid flag set? (bit 7 here)
	bra		TFT_color_code_ceiling_1	; YES
	SAFE_2BYTE_COPY rel_pressure,sub_a	; NO
	movff	lo,sub_b+0
	movff	hi,sub_b+1
	call	subU16						; sub_c = sub_a - sub_b :  sub_c = rel_pressure [cm] - int_O_ceiling [mbar => cm]
	btfsc	neg_flag					; is ceiling > current depth?
	bra		TFT_warnings_color			; YES - set to warning  color and return
	bra		TFT_standard_color			; NO  - set to standard color and return
TFT_color_code_ceiling_1:
	bcf		hi,char_invalid_flag		; clear the invalid flag (bit 7 here)
	bra		TFT_disabled_color			; set to disabled color and return


TFT_color_code_stop:					; color-code the stop depth
	movff	char_O_deco_gas+0,WREG		; get flag for invalid deco data
	btfsc	WREG,char_invalid_flag		; is the invalid flag set?
	bra		TFT_disabled_color			; set to disabled color and return
	SAFE_2BYTE_COPY rel_pressure,xA		; get current pressure in mbar = cm
	movlw	LOW d'100'
	movwf	xB+0
	clrf	xB+1
	call	div16x16					; xA/xB=xC with xA as remainder: Divide/100 => xC+0 = current depth in meters
	movff	char_O_first_deco_depth,WREG; get stop depth in m into WREG
	subwf	xC+0,W						; compute current depth - stop depth
	btfsc	STATUS,C					; result negative?
	bra		TFT_standard_color			; NO  - set to standard color and return
	bra		TFT_warnings_color			; YES - set to warning  color and return


TFT_color_code_depth:					; with actual depth as rel_pressure in [mbar] in hi:lo and threshold depth_warn_mbar [mbar], 16Bit
	movff	lo,sub_a+0
	movff	hi,sub_a+1
	movlw	LOW  depth_warn_mbar
	movwf	sub_b+0
	movlw	HIGH depth_warn_mbar
	movwf	sub_b+1
	call	subU16						; sub_c = sub_a - sub_b
	TSTOSS	opt_modwarning				; 0=standard, 1=blink
	bra		TFT_color_code_depth_std
	btfss	neg_flag
	bra		TFT_color_code_depth_warn	; set to warning color
	bra		TFT_color_code_depth_ppO2	; check depth against MOD and return...
TFT_color_code_depth_std:
	btfss	neg_flag
	bra		TFT_warnings_color			; set to warning  color and return
	bra		TFT_standard_color			; set to standard color and return...
TFT_color_code_depth_ppO2:
	movff	opt_dive_mode,WREG			; 0=OC, 1=CC, 2=Gauge, 3=Apnea, 4=PSCR
	decfsz	WREG,F						; are we in CCR mode?
	bra		TFT_color_code_depth_no_ccr	; NO  - continue checking for ppO2
	btfsc	is_bailout					; YES - check if in bailout
	bra		TFT_color_code_depth_no_ccr	;       YES - continue checking for ppO2
	bcf		blinking_depth_warning		; reset warning
	bra		TFT_standard_color			; no color coding, return.
TFT_color_code_depth_no_ccr:
	movff	int_O_breathed_ppO2+1,WREG	; get upper byte of currently breathed ppO2
	btfsc	WREG,int_warning_flag		; is the warning flag set?
	bra		TFT_color_code_depth_warn	; YES - animate in warning design
	bcf		blinking_depth_warning		; NO  - reset warning
	bra		TFT_standard_color			;       set standard color and return
TFT_color_code_depth_warn:
	bsf		blinking_depth_warning		; set warning
	bra		TFT_warnings_color			; set to warning color and return...


	global	TFT_color_code_cns
TFT_color_code_cns:						; color-code CNS values (CNS in hi:lo [%])
	btfss	hi,int_invalid_flag			; is the invalid flag set?
	bra		TFT_color_code_cns_1		; NO
	bcf		hi,int_invalid_flag			; YES - clear invalid flag
	bcf		hi,int_warning_flag			;       clear warning	flag (it may be set)
	bcf		hi,int_attention_flag		;       clear attention flag (it may be set)
	bra		TFT_disabled_color			;       set to disabled color and return
TFT_color_code_cns_1
	btfss	hi,int_warning_flag			; is the warning flag set?
	bra		TFT_color_code_cns_2		; NO
	bcf		hi,int_warning_flag			; YES - clear warning	flag
	bcf		hi,int_attention_flag		;		clear attention flag (it may be set)
	bra		TFT_warnings_color			;		set to warning color and return
TFT_color_code_cns_2:
	btfss	hi,int_attention_flag		; is the attention flag set?
	bra		TFT_standard_color			; NO  - set to standard color and return
	bcf		hi,int_attention_flag		; YES - clear attention flag
	bra		TFT_attention_color			;		set to attention color and return


TFT_color_code_gf:
	; with int_O_gradient_factor, the upper byte is solely used for the flags
	; and not for the value, thus there is no need to clear the flags
	btfsc	hi,int_invalid_flag			; is the invalid flag set?
	bra		TFT_disabled_color			; YES - set to disabled color and return
	btfsc	hi,int_warning_flag			; NO  - is the warning flag set?
	bra		TFT_warnings_color			;       YES - set to warning color and return
	btfsc	hi,int_attention_flag		;       NO  - is the attention flag set?
	bra		TFT_attention_color			;             YES - set to attention color and return
	bra		TFT_standard_color			;             NO  - set to normal    color and return


TFT_color_code_ppo2:					; color-code ppO2 values (ppO2 in hi:lo [cbar]) by its warning flags
	btfss	hi,int_warning_flag			; is the warning flag set?
	bra		TFT_color_code_ppo2_1		; NO
	bcf		hi,int_warning_flag			; YES - clear warning flag
	bcf		hi,int_attention_flag		;       clear attention    flag (it may be set)
	bcf		hi,int_high_flag			;       clear high warning flag (it may be set)
	bcf		hi,int_low_flag				;       clear low  warning flag (it may be set)
	bra		TFT_warnings_color			;       warn in warning color
TFT_color_code_ppo2_1:
	btfss	hi,int_attention_flag		; is the attention flag set?
	bra		TFT_color_code_ppo2_2		; NO
	bcf		hi,int_attention_flag		; YES - clear attention    flag (it may be set)
	bcf		hi,int_high_flag			;       clear high warning flag (it may be set)
	bcf		hi,int_low_flag				;       clear low  warning flag (it may be set)
	bra		TFT_attention_color			;       set to standard color and return
TFT_color_code_ppo2_2:
	bcf		hi,int_high_flag			; clear high warning flag (it may be set)
	bcf		hi,int_low_flag				; clear low  warning flag (it may be set)
	bra		TFT_standard_color			; set to standard color and return


TFT_color_code_ppo2_hud:				; color-code ppO2 values (ppO2 in --:lo [cbar]) by its value
	movff	char_O_deco_warnings,WREG	; get the deco warnings vector
	btfss	WREG,deco_flag				; are we in deco?
	bra		TFT_color_code_ppo2_hud_a	; NO  - load normal max value as threshold
	movff	char_I_ppO2_max_deco,WREG	; YES - load deco value as threshold
	bra		TFT_color_code_ppo2_hud_b
TFT_color_code_ppo2_hud_a:
	movff	char_I_ppO2_max,WREG		; ppO2 max while not in deco
TFT_color_code_ppo2_hud_b:
	cpfsgt	lo							; lo > threshold?
	bra		TFT_color_code_ppo2_hud1	; NO  - continue with checking for ppO2 low
	bra		TFT_warnings_color			; YES - set warning color and return
TFT_color_code_ppo2_hud1:
	movff	opt_dive_mode,WREG			; 0=OC, 1=CC, 2=Gauge, 3=Apnea, 4=PSCR
	decfsz	WREG,F						; now:  0=CC, 1=Gauge, 2=Apnea, 3=PSCR
	bra		TFT_color_code_ppo2_hud_nocc; not CCR...
	btfsc	is_bailout
	bra		TFT_color_code_ppo2_hud_nocc; is bailout, hence not loop mode...
	movff	char_I_ppO2_min_loop,WREG	; ppO2 min loop mode color coding
	bra		TFT_color_code_ppo2_hud_cont
TFT_color_code_ppo2_hud_nocc:
	movff	char_I_ppO2_min,WREG		; PPO2 min for all other modes
TFT_color_code_ppo2_hud_cont:
	cpfslt	lo							; lo < char_I_ppO2_min?
	bra		TFT_standard_color			; NO  - set standard color and return...
	bra		TFT_warnings_color			; Yes - set warning  color and return


TFT_color_code_battery:					; color-code the battery display, with battery percent in lo
	movlw	color_code_battery_low		; get warning threshold
	cpfsgt	lo							; is battery percent < threshold?
	bra		TFT_warnings_color			; YES - set to warning  color and return
	bra		TFT_standard_color			; NO  - set to standard color and return


	global	TFT_color_code_gas
TFT_color_code_gas:						; color-code the output according to gas number (1-6) in WREG
	movwf	up							; copy gas number (1-6) to up
	movlw	color_white					; Default color
	dcfsnz	up,F
	movlw	color_white					; Color for Gas 1
	dcfsnz	up,F
	movlw	color_green					; Color for Gas 2
	dcfsnz	up,F
	movlw	color_red					; Color for Gas 3
	dcfsnz	up,F
	movlw	color_yellow				; Color for Gas 4
	dcfsnz	up,F
	movlw	color_cyan					; Color for Gas 5
	dcfsnz	up,F
	movlw	color_pink					; Color for Gas 6
	goto	TFT_set_color				; Set Color...


; ****************************************************************************

	global	TFT_show_OC_startgas_surface
TFT_show_OC_startgas_surface:			; Show first gas and "OSTC2-like" active gases
	; Show first gas
	WIN_SMALL surf_decotype_column+.1,surf_decotype_row+.30
	extern	get_first_gas_to_WREG,gaslist_strcat_gas
	call	get_first_gas_to_WREG		; Gets first gas (1-5) into WREG
	decf	WREG,W						; 1-5 -> 0-4
	movwf	PRODL
	call	gaslist_strcat_gas			; Input: PRODL : gas number (0..4), Output: Text appended into buffer pointed by FSR2.
	STRCAT_PRINT ""
	; Show boxes
	WIN_TOP	 surf_decotype_row+.30+.25
	WIN_LEFT surf_decotype_boxes_left1+.1
	rcall	TFT_disabled_color
	movff	opt_gas_type+0,hi			; 0=Disabled, 1=First, 2=Travel, 3=Deco
	tstfsz	hi
	rcall	TFT_standard_color
	STRCPY_PRINT "1"
	decfsz	hi,F						; Type = 1 (First)?
	bra		DISP_active_gas_surfmode3	; No, skip box
	WIN_FRAME_STD surf_decotype_boxes_top, surf_decotype_boxes_bottom, surf_decotype_boxes_left1, surf_decotype_boxes_left1+.8	;top, bottom, left, right
DISP_active_gas_surfmode3:
	rcall	TFT_disabled_color
	movff	opt_gas_type+1,hi			; 0=Disabled, 1=First, 2=Travel, 3=Deco
	tstfsz	hi
	rcall	TFT_standard_color
	WIN_LEFT surf_decotype_boxes_left2+.1
	STRCPY_PRINT "2"
	decfsz	hi,F						; Type = 1 (First)?
	bra		DISP_active_gas_surfmode4	; No, skip box
	WIN_FRAME_STD surf_decotype_boxes_top, surf_decotype_boxes_bottom, surf_decotype_boxes_left2, surf_decotype_boxes_left2+.8	;top, bottom, left, right
DISP_active_gas_surfmode4:
	rcall	TFT_disabled_color
	movff	opt_gas_type+2,hi			; 0=Disabled, 1=First, 2=Travel, 3=Deco
	tstfsz	hi
	rcall	TFT_standard_color
	WIN_LEFT surf_decotype_boxes_left3+.1
	STRCPY_PRINT "3"
	decfsz	hi,F						; Type = 1 (First)?
	bra		DISP_active_gas_surfmode5	; No, skip box
	WIN_FRAME_STD surf_decotype_boxes_top, surf_decotype_boxes_bottom, surf_decotype_boxes_left3, surf_decotype_boxes_left3+.8	;top, bottom, left, right
DISP_active_gas_surfmode5:
	rcall	TFT_disabled_color
	movff	opt_gas_type+3,hi			; 0=Disabled, 1=First, 2=Travel, 3=Deco
	tstfsz	hi
	rcall	TFT_standard_color
	WIN_LEFT surf_decotype_boxes_left4+.1
	STRCPY_PRINT "4"
	decfsz	hi,F						; Type = 1 (First)?
	bra		DISP_active_gas_surfmode6	; No, skip box
	WIN_FRAME_STD surf_decotype_boxes_top, surf_decotype_boxes_bottom, surf_decotype_boxes_left4, surf_decotype_boxes_left4+.8	;top, bottom, left, right
DISP_active_gas_surfmode6:
	rcall	TFT_disabled_color
	movff	opt_gas_type+4,hi			; 0=Disabled, 1=First, 2=Travel, 3=Deco
	tstfsz	hi
	rcall	TFT_standard_color
	WIN_LEFT surf_decotype_boxes_left5+.1
	STRCPY_PRINT "5"
	rcall	TFT_standard_color			; Reset color
	decfsz	hi,F						; Type = 1 (First)?
	return								; no, Done.
	WIN_FRAME_STD surf_decotype_boxes_top, surf_decotype_boxes_bottom, surf_decotype_boxes_left5, surf_decotype_boxes_left5+.8	;top, bottom, left, right
	return								; Done.


	global	TFT_show_color_schemes
TFT_show_color_schemes:					; update the color schemes
	bsf		divemode					; put in divemode
	call	TFT_divemask_color
	WIN_TINY .12,.40
	STRCAT_TEXT_PRINT tDepth
	WIN_TINY .62,.40
	STRCAT_TEXT_PRINT tMaxDepth
	WIN_TINY .122,.40
	STRCAT_TEXT_PRINT tDivetime

	; Show some demo screen

	; Depth demo
	call	TFT_standard_color
	WIN_MEDIUM	.3,.54
	movlw	LOW  .5172
	movwf	lo
	movlw	HIGH .5172
	movwf	hi
	bsf		leftbind
	bsf		ignore_digit4
	output_16							; Full meters in Big font
	bcf		leftbind
	STRCAT_PRINT ""						; Display full meters
	WIN_SMALL	.25,.66
	movlw	LOW	 .5172
	movwf	lo
	movlw	HIGH	.5172
	movwf	hi
	PUTC	"."
	movlw	d'4'
	movwf	ignore_digits
	bsf		ignore_digit5
	output_16dp	d'0'					; .1m in SMALL font
	STRCAT_PRINT ""						; Display decimeters
	WIN_FONT FT_SMALL

	; Max. Depth demo
	WIN_MEDIUM	.64,.54
	bsf		ignore_digit4				; no 0.1m
	bsf		leftbind
	movlw	LOW	 .6349
	movwf	lo
	movlw	HIGH	.6349
	movwf	hi
	output_16
	STRCAT_PRINT ""						; Display full meters
	bcf		leftbind
	; .1m in SMALL font
	WIN_SMALL .87,.66
	PUTC	"."
	movlw	d'4'
	movwf	ignore_digits
	bsf		ignore_digit5
	bsf		leftbind
	movlw	LOW	 .6349
	movwf	lo
	movlw	HIGH	.6349
	movwf	hi
	output_16dp	d'0'
	STRCAT_PRINT ""						; Display decimeters
	bcf		leftbind

	; Divetime demo
	movff	mins,lo
	clrf	hi
	WIN_MEDIUM .103, .54
	output_16_3							; limit to 999 and display only (0-999)
	STRCAT_PRINT ""						; Show minutes in large font
	WIN_SMALL .139, .66					; left position for two sec figures
	PUTC	':'
	bsf		leftbind
	movff	secs,lo
	output_99x
	bcf		leftbind
	STRCAT_PRINT ""						; Show seconds in small font

	bcf		divemode					; don't stay in divemode
	return

	global	TFT_divemode_mask
TFT_divemode_mask:						; Displays mask in divemode
	bcf		FLAG_TFT_divemode_mask
	call	TFT_divemask_color
	WIN_TINY dm_mask_depth_column,dm_mask_depth_row
	STRCAT_TEXT_PRINT tDepth
	WIN_TINY dm_mask_maxdepth_column,dm_mask_maxdepth_row
	TSTOSS	opt_vsigraph				; 0=skip, 1=draw
	WIN_TINY dm_mask_maxdepth_column_nvsi,dm_mask_maxdepth_row
	STRCAT_TEXT_PRINT tMaxDepth
	WIN_TINY dm_mask_divetime_column,dm_mask_divetime_row
	STRCAT_TEXT_PRINT tDivetime
	bra		TFT_standard_color			; and return...

	global	TFT_divemode_mask_alternative
TFT_divemode_mask_alternative:			; Alt. mask for divemode
	bcf		FLAG_TFT_divemode_mask_alt
	call	TFT_divemask_color
	WIN_TINY dm_mask_depth_column,dm_mask_depth_row
	STRCAT_TEXT_PRINT tDepth
	WIN_TINY dm_mask_divetime_column-.30,dm_mask_divetime_row
	STRCAT_TEXT_PRINT tDivetime
	bra		TFT_standard_color			; and return...

	global	TFT_draw_gassep_line
TFT_draw_gassep_line:
	btfsc	FLAG_apnoe_mode				; Ignore in Apnoe mode
	return
	btfsc	divemode_menu				; Is the dive mode menu shown?
	return								; Yes, return
	bra		TFT_standard_color			; and return...

;=========================================================================

	global	TFT_display_velocity
TFT_display_velocity:					; With divA+0 = m/min, neg_flag_velocity: ascend=1, descend=0
	bcf		STATUS,C
	movlw	velocity_display_threshold_1; lowest threshold for display vertical velocity
	subwf	divA+0,W
	btfss	STATUS,C
	bra		TFT_velocity_clear			; lower then threshold. Clear text and graph (If active)

	; We have something to display
	bsf		display_velocity			; Set flag
	; check if descending: no warning color if descending
	rcall	TFT_standard_color
	btfsc	neg_flag_velocity			; Ignore for descent!
	rcall	TFT_velocity_set_color		; Set color for text and set threshold for graph

	rcall	TFT_velocity_disp			; Show the text

	TSTOSS	opt_vsigraph				; =1: draw the graphical VSI bar
	bra		TFT_display_velocity_done	; No graph

	btfsc	alternative_divelayout		; Alternative layout?
	bra		TFT_display_velocity_done	; Yes, no graph! (no room when divetime minutes is three figures)

	btfsc	neg_flag_velocity			; Ignore for descent!
	rcall	TFT_velocity_graph			; Show the graph
	btfss	neg_flag_velocity			; Ignore for descent!
	rcall	TFT_velocity_clear_graph	; Clear the graph for descent

TFT_display_velocity_done:
	bra		TFT_standard_color			; and return!

TFT_speed_table:
	; use a depth-dependent ascent rate warning
	; depth(ft):     <20 >20 >40 >60 >75 >88 >101 >115 >128 >144 >164
	; speed(ft/min):  23  26  29  33  36  43   49   56   59   62   66
	; depth(m):      <=6  >6 >12 >18 >23 >27  >31  >35  >39  >44  >50
	; speed(m/min):    7   8   9  10  11  13   15   17   18   19   20 (warning)
	; speed(m/min):    5   6   7   8   8  10   12   13   14   15   15 (attention)

	; <xx m, warning speed, attention speed, unused
	DB  .6,.7,.5,.0
	DB  .12,.8,.6,.0
	DB  .18,.9,.7,.0
	DB  .23,.10,.8,.0
	DB  .27,.11,.8,.0
	DB  .31,.13,.10,.0
	DB  .35,.15,.12,.0
	DB  .39,.17,.13,.0
	DB  .44,.18,.14,.0
	DB  .50,.19,.15,.0
	DB  .200,.20,.15,.0

TFT_velocity_set_color:						; Set color based on speed table or use static thresholds, with divA+0 = m/min
	; check if old/new ascend logic is used
	TSTOSS	opt_vsitextv2					; 0=standard, 1=dynamic
	bra		TFT_velocity_set_color_static	; static ascend rate limit

	; get the actual depth in m
	SAFE_2BYTE_COPY rel_pressure, lo
	call	adjust_depth_with_salinity		; computes salinity setting into lo:hi [mbar]
	movff	hi,xA+1
	movff	lo,xA+0
	movlw	LOW		d'100'
	movwf	xB+0
	clrf	xB+1							; Devide/100 -> xC+0 = Depth in m
	call	div16x16						; xA/xB=xC with xA as remainder
	;movf	xC+0,W							; Depth in m

	; point to speed table
	movlw	LOW   (TFT_speed_table-.3)
	movwf	TBLPTRL
	movlw	HIGH  (TFT_speed_table-.3)
	movwf	TBLPTRH
	movlw	UPPER (TFT_speed_table-.3)
	movwf	TBLPTRU

TFT_velocity_set_color_skip:
	TBLRD*+									; 3 dummy reads
	TBLRD*+
	TBLRD*+

	TBLRD*+									; Get speed threshold
	movf	xC+0,W							; Depth in m
	cpfsgt	TABLAT							; Threshold > current depth ?
	bra		TFT_velocity_set_color_skip		; No

	TBLRD*+									; Get warning speed threshold
	movf	TABLAT,W
	movwf	divA+1							; Copy for graph routine
	cpfslt	divA+0							; smaller then actual value (in m/min)?
	bra	 TFT_warnings_color					; Set Warning color (And return)
	TBLRD*+									; Get attention speed threshold
	movf	TABLAT,W
	cpfslt	divA+0							; smaller then actual value (in m/min)?
	bra		TFT_attention_color				; set attention color (and return)
	bra		TFT_standard_color				; ...and return

TFT_velocity_set_color_static:
	movlw	color_code_velocity_warn_high	; in m/min
	movwf	divA+1							; Copy for graph routine
	cpfslt	divA+0							; smaller then actual value (in m/min)?
	bra		TFT_warnings_color				; Set Warning color (And return)
	movlw	color_code_velocity_attn_high	; in m/min
	cpfslt	divA+0							; smaller then actual value (in m/min)?
	bra		TFT_attention_color				; set attention color (and return)
	bra		TFT_standard_color				; ...and return

TFT_velocity_disp:
	WIN_SMALL	dm_velocity_text_column, dm_velocity_text_row
	TSTOSS	opt_units						; 0=Meters, 1=Feets
	bra		TFT_velocity_metric
;TFT_velocity_imperial:
	movff	divA+0,WREG						; divA+0 = m/min
	mullw	.100							; PRODL:PRODH = mbar/min
	movff	PRODL,lo
	movff	PRODH,hi
	call	convert_mbar_to_feet			; convert value in lo:hi from mbar to feet
	movlw	'-'
	btfsc	neg_flag_velocity
	movlw	'+'
	movwf	POSTINC2
	bsf		leftbind
	output_16
	bcf		leftbind
	STRCAT_TEXT_PRINT tVelImperial			; Unit switch
	return

TFT_velocity_metric:
	movff	divA+0,lo						; divA+0 = m/min
	movlw	'-'
	btfsc	neg_flag_velocity
	movlw	'+'
	movwf	POSTINC2
	output_99
	STRCAT_TEXT_PRINT tVelMetric			; Unit switch
	return

TFT_velocity_graph:							; divA+0 = m/min
	; divA+0 holding the ascend speed in m/min
	movff	divA+0,hi						; Copy
	WIN_BOX_BLACK	dm_velobar_top, dm_velobar_bot, dm_velobar_lft, dm_velobar_rgt ;top, bottom, left, right -> outer frame
	rcall	TFT_divemask_color_dive			; Color -> WREG
	WIN_FRAME_COLOR	dm_velobar_top, dm_velobar_bot, dm_velobar_lft, dm_velobar_rgt ;inner frame
	rcall	TFT_divemask_color_dive			; Color -> WREG
	WIN_FRAME_COLOR	dm_velobar_top+.10, dm_velobar_bot-.10, dm_velobar_lft, dm_velobar_rgt ;inner frame
	rcall	TFT_divemask_color_dive			; Color -> WREG
	WIN_FRAME_COLOR	dm_velobar_top+.20, dm_velobar_bot-.20, dm_velobar_lft, dm_velobar_rgt ;inner frame
	rcall	TFT_divemask_color_dive			; Color -> WREG
	WIN_FRAME_COLOR	dm_velobar_top+.30, dm_velobar_bot-.30, dm_velobar_lft, dm_velobar_rgt ;inner frame
	
	movff	divA+1,xA+0						; m/min for warning level (upper two blocks)
	clrf	xA+1
	movlw	.5
	movwf	xB+0							; Threshold for color warning (5 color normal + 2 color warning)
	clrf	xB+1
	call	div16x16						;xA/xB=xC with xA as remainder
	; xC+0 holds step size in m/min (e.g. =3 for 15m/min warning threshold)
	movff	hi,xA+0							; Velocity in m/min
	clrf	xA+1
	movff	xC+0,xB+0						; Step size
	clrf	xB+1
	call	div16x16						;xA/xB=xC with xA as remainder
	; xC+0 now holds amount of segments to show

	movff	hi,divA+0						; Copy back for numeric output
	movlw	d'7'
	cpfslt	xC+0
	bra		DISP_graph_vel_7
	movlw	d'6'
	cpfslt	xC+0
	bra		DISP_graph_vel_6
	movlw	d'5'
	cpfslt	xC+0
	bra		DISP_graph_vel_5
	movlw	d'4'
	cpfslt	xC+0
	bra		DISP_graph_vel_4
	movlw	d'3'
	cpfslt	xC+0
	bra		DISP_graph_vel_3
	movlw	d'2'
	cpfslt	xC+0
	bra		DISP_graph_vel_2
	movlw	d'1'
	cpfslt	xC+0
	bra		DISP_graph_vel_1
	bra		DISP_graph_vel_0				; Should not happen...

DISP_graph_vel_7:
	rcall	TFT_warnings_color_dive		; Color -> WREG
	WIN_BOX_COLOR dm_velobar_top+.2, dm_velobar_top+.8, dm_velobar_lft+.2, dm_velobar_rgt-.2 ;top, bottom, left, right
DISP_graph_vel_6:
	rcall	TFT_warnings_color_dive		; Color -> WREG
	WIN_BOX_COLOR dm_velobar_top+.12, dm_velobar_top+.18, dm_velobar_lft+.2, dm_velobar_rgt-.2 ;top, bottom, left, right
DISP_graph_vel_5:
	rcall	TFT_attention_color_dive	; Color -> WREG
	WIN_BOX_COLOR dm_velobar_top+.22, dm_velobar_top+.28, dm_velobar_lft+.2, dm_velobar_rgt-.2 ;top, bottom, left, right
DISP_graph_vel_4:
	rcall	TFT_standard_color_dive		; Color -> WREG
	WIN_BOX_COLOR dm_velobar_top+.32, dm_velobar_top+.38, dm_velobar_lft+.2, dm_velobar_rgt-.2 ;top, bottom, left, right
DISP_graph_vel_3:
	rcall	TFT_standard_color_dive		; Color -> WREG
	WIN_BOX_COLOR dm_velobar_top+.42, dm_velobar_top+.48, dm_velobar_lft+.2, dm_velobar_rgt-.2 ;top, bottom, left, right
DISP_graph_vel_2:
	rcall	TFT_standard_color_dive		; Color -> WREG
	WIN_BOX_COLOR dm_velobar_top+.52, dm_velobar_top+.58, dm_velobar_lft+.2, dm_velobar_rgt-.2 ;top, bottom, left, right
DISP_graph_vel_1:
	rcall	TFT_standard_color_dive		; Color -> WREG
	WIN_BOX_COLOR dm_velobar_top+.62, dm_velobar_top+.68, dm_velobar_lft+.2, dm_velobar_rgt-.2 ;top, bottom, left, right
DISP_graph_vel_0:
	return								; Done.

	global	TFT_velocity_clear
TFT_velocity_clear:
	btfss	display_velocity			; Velocity was not displayed, do not delete
	return
	bcf		display_velocity			; Velocity was displayed, delete velocity now
	; Clear Text
	WIN_BOX_BLACK	dm_velocity_text_row, dm_velocity_text_bot, dm_velocity_text_column, dm_velocity_text_rgt ; top, bottom, left, right

	TSTOSS	opt_vsigraph				; =1: draw the graphical VSI bar
	return								; No graph to clear
TFT_velocity_clear_graph:
	; Clear Graph
	WIN_BOX_BLACK dm_velobar_top, dm_velobar_bot, dm_velobar_lft, dm_velobar_rgt ;top, bottom, left, right
	return

;=========================================================================

	global	TFT_clear_decoarea
TFT_clear_decoarea:
	WIN_BOX_BLACK	dm_decostop_1st_stop_row, .239, dm_decostop_1st_stop_column, .159 ; top, bottom, left, right
	return


	global	TFT_clear_divemode_menu
TFT_clear_divemode_menu:
	WIN_BOX_BLACK	dm_menu_row, dm_menu_lower, dm_menu_left, dm_menu_right	; top, bottom, left, right
	return


	global	TFT_display_ndl_mask
TFT_display_ndl_mask:
	bcf		FLAG_TFT_display_ndl_mask
	btfsc	divemode_menu				; Is the dive mode menu shown?
	return								; Yes, return
	call	TFT_clear_decoarea			; Clear Dekostop and Dekosum
	call	TFT_divemask_color
	WIN_STD dm_ndl_text_column, dm_ndl_text_row
	STRCPY_TEXT_PRINT tNDL				; NDL
	bra		TFT_standard_color			; and return...


	global	TFT_display_tts
TFT_display_tts:
	bcf		FLAG_TFT_display_tts
	btfsc	divemode_menu				; Is the dive mode menu shown?
	return								; Yes, return
	call	TFT_standard_color
	movff	int_O_ascenttime+0,lo		; TTS
	movff	int_O_ascenttime+1,hi		; on 16bits
	btfss	hi,int_invalid_flag			; is the invalid flag set?
	bra		TFT_display_tts_1			; NO
	bcf		hi,int_invalid_flag			; YES - clear flag
	call	TFT_disabled_color			;       switch to disabled color
TFT_display_tts_1:
	WIN_MEDIUM dm_tts_value_column, dm_tts_value_row
	output_16_3							; Displays only 0...999
	STRCAT_PRINT "'"
	return


	global	TFT_display_ndl
TFT_display_ndl:
	bcf		FLAG_TFT_display_ndl
	btfsc	divemode_menu				; Is the dive mode menu shown?
	return								; Yes, return
	WIN_MEDIUM	dm_ndl_value_column, dm_ndl_value_row
	call	TFT_standard_color
	movff	char_O_nullzeit,lo			; Get NDL from C-code
	output_8
	STRCAT_PRINT "'"
	return


	global	TFT_big_deco_alt			; The big deco
TFT_big_deco_alt:
	bcf		FLAG_TFT_big_deco_alt

	btfss	decostop_active				; deco?
	bra		TFT_big_deco_ndl_alt		; NDL

	; Deco
	bcf		FLAG_TFT_display_deko
	call	TFT_divemask_color
	WIN_STD .70,.165
	STRCPY_TEXT_PRINT tTTS				; TTS
	rcall	TFT_standard_color

	; TTS
	WIN_LARGE	.97,.170
	movff	int_O_ascenttime+0,lo		; TTS
	movff	int_O_ascenttime+1,hi		; on 16bits
	btfss	hi,int_invalid_flag			; is the invalid flag set?
	bra		TFT_display_tts_alt_1		; NO
	bcf		hi,int_invalid_flag			; YES - clear flag
	call	TFT_disabled_color			;       switch to disabled color
TFT_display_tts_alt_1:
	output_16_3							; Displays only 0...999
	STRCAT_PRINT ""

	; 1st Stop
	call	TFT_divemask_color
	WIN_STD .25,dm_customview_row
	STRCPY_TEXT_PRINT tDiveSafetyStop	; "Stop"

	WIN_LARGE .60,.95
	call	TFT_color_code_stop			; Color-code Output
	movff	char_O_first_deco_depth,lo	; stop depth in m
	rcall	TFT_display_deko_output_depth ; Outputs depth (stored in lo) to POSTINC2 with "m" or w/o (For ft)
	STRCAT_PRINT ""

	; m or ft after the stop depth
	WIN_MEDIUM .100,.118
	TSTOSS	opt_units					; 0=m, 1=ft
	bra		TFT_display_tts_alt_1_metric
	STRCAT_TEXT_PRINT tFeets1
	bra		TFT_display_tts_alt_1_com
TFT_display_tts_alt_1_metric:
	STRCAT_TEXT_PRINT tMeters
TFT_display_tts_alt_1_com:
	WIN_LARGE .117,.95
	movff	char_O_first_deco_time,lo	; length of first stop in min
	bcf		leftbind
	output_99
	STRCAT_PRINT ""
	goto	TFT_standard_color			; and return...
	
TFT_big_deco_ndl_alt:
	; NDL
	bcf		FLAG_TFT_display_ndl
	bcf		decostop_active				; clear flag (again)
	call	TFT_divemask_color
	WIN_STD .70,.165
	STRCPY_TEXT_PRINT tNDL				; NDL
	call	TFT_standard_color
	WIN_LARGE .97,.170
	call	TFT_standard_color
	movff	char_O_nullzeit,lo			; Get NDL from C-code
	output_8
	STRCAT_PRINT ""

	btfsc	FLAG_TFT_show_safety_stop
	bra		TFT_show_safety_stop_alt	; Show safety stop (And return)
	; Clear any safety stop or Decostop
TFT_no_more_safety_stop_alt:
	WIN_BOX_BLACK	dm_customview_row, .150, .0, .159	; top, bottom, left, right
	WIN_BOX_BLACK	dm_customview_row, .164, .60, .159	; top, bottom, left, right
	return

TFT_show_safety_stop_alt:
	bcf		FLAG_TFT_show_safety_stop
	tstfsz	safety_stop_countdown		; Countdown at zero?
	bra		TFT_show_safety_stop_alt2	; No, show stop
	bcf		show_safety_stop			; Clear flag
	btfss	safety_stop_active			; Displayed?
	return								; No
	bcf		safety_stop_active			; Clear flag
	bra		TFT_no_more_safety_stop_alt	; Yes, Clear stop ; and return...

TFT_show_safety_stop_alt2:
	bsf		safety_stop_active			; Set flag
	decf	safety_stop_countdown,F		; Reduce countdown

	call	TFT_divemask_color
	WIN_STD	.50,dm_customview_row
	STRCPY_TEXT_PRINT tDiveSafetyStop
	call	TFT_attention_color			; show in yellow
	WIN_LARGE	.90,.95
	movff	safety_stop_countdown,lo
	clrf	hi
	call	convert_time				; converts hi:lo in seconds to mins (hi) and seconds (lo)
	movf	hi,W
	movff	lo,hi
	movwf	lo							; exchange lo and hi
	bsf		leftbind
	output_8
	STRCAT_PRINT ""
	WIN_MEDIUM .112,.120
	STRCAT_PRINT ":"
	WIN_LARGE  .117,.95
	bcf		leftbind
	movff	hi,lo
	output_99x
	STRCAT_PRINT ""
	WIN_FONT FT_SMALL
	goto	TFT_standard_color			; and return...


	global	TFT_divemode_warning
TFT_divemode_warning:
	bcf		FLAG_TFT_divemode_warning
	bsf		dive_warning_displayed				; =1: The warning sign is shown
	WIN_TOP  dm_warning_icon_row
	WIN_LEFT dm_warning_icon_column
	TFT_WRITE_PROM_IMAGE dive_warning2_block	; Show Warning icon
	return

	global	TFT_divemode_warning_clear
TFT_divemode_warning_clear:
	bcf		FLAG_TFT_divemode_warning_clear
	btfss	dive_warning_displayed				; =1: The warning sign is shown
	return
	bcf		dive_warning_displayed				; clear only once
	WIN_BOX_BLACK dm_warning_icon_row, dm_warning_icon_bot, dm_warning_icon_column, dm_warning_icon_rgt ; top, bottom, left, right
	return

	global	TFT_display_deko_mask
TFT_display_deko_mask:
	bcf		FLAG_TFT_display_deko_mask
	btfsc	divemode_menu			; Is the dive mode menu shown? 
	return							; Yes, return
	rcall	TFT_clear_decoarea		; Clear Dekostop and Dekosum (and NDL in this case)
	WIN_STD dm_tts_text_column, dm_tts_text_row
	call	TFT_divemask_color
	STRCPY_TEXT_PRINT tTTS			; TTS
	call	TFT_standard_color
	bcf		show_safety_stop		; Clear safety stop flag
	return


TFT_display_deko_output_depth:		; Outputs depth (stored in lo) to POSTINC2 with "m" or w/o (for ft)
	TSTOSS	opt_units				; 0=m, 1=ft
	bra	TFT_display_deko_output_metric
;TFT_display_deko_output_imperial:
	movf	lo,W					; lo = m
	mullw	.100					; PRODL:PRODH = mbar
	movff	PRODL,lo
	movff	PRODH,hi
; Convert with 334feet/100m to have 10ft, 20ft, 30ft stops...
	movff	lo,xA+0
	movff	hi,xA+1
	movlw	LOW  d'334'				; 334feet/100m
	movwf	xB+0
	movlw	HIGH d'334'
	movwf	xB+1
	call	mult16x16				; xA*xB=xC (lo:hi * 328)
	movlw	d'50'					; round up
	addwf	xC+0,F
	movlw	0
	addwfc	xC+1,F
	addwfc	xC+2,F
	addwfc	xC+3,F
	movlw	d'100'
	movwf	xB+0
	clrf	xB+1
	call	div32x16				; xC:4 / xB:2 = xC+3:xC+2 with xC+1:xC+0 as remainder
	movff	xC+0,lo
	movff	xC+1,hi					; restore lo and hi with updated value
	bcf		leftbind
	btfsc	alternative_divelayout
	bsf		leftbind				; left for alternative layout mode
	bsf		ignore_digit4			; Only full feet
	output_16
	btfsc	alternative_divelayout
	return							; Not for alternative layout mode
	STRCAT_TEXT	tFeets1
	return

TFT_display_deko_output_metric:
	output_99
	btfsc	alternative_divelayout
	return							; Not for alternative layout mode
	STRCAT_TEXT	tMeters
	PUTC	' '
	return


	global	TFT_display_deko
TFT_display_deko:
	bcf		FLAG_TFT_display_deko
	btfsc	divemode_menu				; Is the dive mode menu shown?
	return								; Yes, return
	WIN_MEDIUM dm_decostop_1st_stop_column, dm_decostop_1st_stop_row
	call	TFT_color_code_stop			; Color-code Output
	movff	char_O_first_deco_depth,lo	; stop depth in m
	rcall	TFT_display_deko_output_depth ; Outputs depth (stored in lo) to POSTINC2 with "m" or w/o (For ft)
	movff	char_O_first_deco_time,lo	; length of first stop in min
	output_99
	STRCAT_PRINT "'"
	goto	TFT_standard_color			; and return...


	global	TFT_decoplan
TFT_decoplan:
	call	TFT_divemask_color
	WIN_TINY	dm_custom_decoplan_title_column, dm_custom_decoplan_title_row
	STRCPY_TEXT_PRINT tDiveDecoplan
	call	TFT_standard_color
	movff	char_O_deco_depth+1,lo
	tstfsz	lo							; Show another stop?
	bra		TFT_display_deko2			; Yes
	; No, clear output and return
	call	TFT_standard_color
	WIN_SMALL	dm_cust_dstop_4th_stop_column,dm_cust_dstop_4th_stop_row
	STRCPY_PRINT "  ---  "
	WIN_BOX_BLACK dm_cust_dstop_2nd_stop_row, dm_customview_bot-.2, dm_cust_dstop_2nd_stop_column, dm_cust_dstop_4th_stop_column	; top, bottom, left, right
	WIN_BOX_BLACK dm_cust_dstop_5th_stop_row, dm_customview_bot, dm_cust_dstop_5th_stop_column, dm_cust_dstop_6th_stop_column	; top, bottom, left, right
	WIN_BOX_BLACK dm_cust_dstop_6th_stop_row, dm_customview_bot, dm_cust_dstop_6th_stop_column, .159	; top, bottom, left, right
	goto	TFT_standard_color			; and return...

TFT_display_deko2:
	movff	char_O_deco_gas+0,lo		; get flag for invalid deco data
	btfsc	lo,char_invalid_flag		; is the invalid flag set?
	call	TFT_disabled_color			; YES - set to disabled color
	WIN_SMALL	dm_cust_dstop_2nd_stop_column, dm_cust_dstop_2nd_stop_row
	movff	char_O_deco_depth+1,lo		; stop in m
	bcf		lo,7						; Clear GAS_SWITCH bit
	rcall	TFT_display_deko_output_depth ; Outputs depth (stored in lo) to POSTINC2 with "m" or w/o (For ft)
	movff	char_O_deco_time+1,lo		; length of stop in min
	output_99
	STRCAT_PRINT "'"
	movff	char_O_deco_depth+2,lo
	tstfsz	lo							; Show another stop?
	bra		TFT_display_deko3			; Yes
	; No, clear output and return
	WIN_BOX_BLACK	dm_cust_dstop_3rd_stop_row, dm_customview_bot-.2, dm_cust_dstop_2nd_stop_column, dm_cust_dstop_4th_stop_column	; top, bottom, left, right
	WIN_BOX_BLACK	dm_cust_dstop_4th_stop_row, dm_customview_bot, dm_cust_dstop_4th_stop_column, .159	; top, bottom, left, right
	goto	TFT_standard_color			; and return...

TFT_display_deko3:
	WIN_SMALL	dm_cust_dstop_3rd_stop_column, dm_cust_dstop_3rd_stop_row
	movff	char_O_deco_depth+2,lo		; stop in m
	bcf		lo,7						; Clear GAS_SWITCH bit
	rcall	TFT_display_deko_output_depth ; Outputs depth (stored in lo) to POSTINC2 with "m" or w/o (For ft)
	movff	char_O_deco_time+2,lo		; length of stop in min
	output_99
	STRCAT_PRINT "'"
	movff	char_O_deco_depth+3,lo
	tstfsz	lo							; Show another stop?
	bra		TFT_display_deko4			; Yes
	; No, clear output and return
	WIN_BOX_BLACK dm_cust_dstop_4th_stop_row, dm_customview_bot, dm_cust_dstop_4th_stop_column, .159 ; top, bottom, left, right
	goto	TFT_standard_color			; and return...

TFT_display_deko4:
	WIN_SMALL	dm_cust_dstop_4th_stop_column, dm_cust_dstop_4th_stop_row
	movff	char_O_deco_depth+3,lo		; stop in m
	bcf		lo,7						; Clear GAS_SWITCH bit
	rcall	TFT_display_deko_output_depth ; Outputs depth (stored in lo) to POSTINC2 with "m" or w/o (For ft)
	movff	char_O_deco_time+3,lo		; length of stop in min
	output_99
	STRCAT_PRINT "'"

	movff	char_O_deco_depth+4,lo
	tstfsz	lo							; Show another stop?
	bra		TFT_display_deko5			; Yes
	; No, clear output and return
	WIN_BOX_BLACK	dm_cust_dstop_5th_stop_row, dm_customview_bot, dm_cust_dstop_5th_stop_column, dm_cust_dstop_6th_stop_column	; top, bottom, left, right
	WIN_BOX_BLACK	dm_cust_dstop_6th_stop_row, dm_customview_bot, dm_cust_dstop_6th_stop_column, .159					 ; top, bottom, left, right
	goto	TFT_standard_color			; and return...

TFT_display_deko5:
	WIN_SMALL	dm_cust_dstop_5th_stop_column, dm_cust_dstop_5th_stop_row
	movff	char_O_deco_depth+4,lo		; stop in m
	bcf		lo,7						; Clear GAS_SWITCH bit
	rcall	TFT_display_deko_output_depth ; Outputs depth (stored in lo) to POSTINC2 with "m" or w/o (For ft)
	movff	char_O_deco_time+4,lo		; length of stop in min
	output_99
	STRCAT_PRINT "'"
	movff	char_O_deco_depth+5,lo
	tstfsz	lo							; Show another stop?
	bra		TFT_display_deko6			; Yes
	; No, clear output and return
	WIN_BOX_BLACK	dm_cust_dstop_6th_stop_row, dm_customview_bot, dm_cust_dstop_6th_stop_column, .159		; top, bottom, left, right
	goto	TFT_standard_color			; and return...

TFT_display_deko6:
	WIN_SMALL	dm_cust_dstop_6th_stop_column, dm_cust_dstop_6th_stop_row
	movff	char_O_deco_depth+5,lo		; stop in m
	bcf		lo,7						; Clear GAS_SWITCH bit
	rcall	TFT_display_deko_output_depth ; Outputs depth (stored in lo) to POSTINC2 with "m" or w/o (For ft)
	movff	char_O_deco_time+5,lo		; length of stop in min
	output_99
	STRCAT_PRINT "'"
	movff	char_O_deco_depth+6,lo
	tstfsz	lo							; Show another stop?
	bra		TFT_display_deko7			; Yes
	; No, clear output and return
	WIN_BOX_BLACK	dm_cust_dstop_7th_stop_row, dm_customview_bot, dm_cust_dstop_7th_stop_column, .159	 ; top, bottom, left, right
	goto	TFT_standard_color			; and return...

TFT_display_deko7:
	WIN_SMALL	dm_cust_dstop_7th_stop_column, dm_cust_dstop_7th_stop_row
	movff	char_O_deco_depth+6,lo		; stop in m
	bcf		lo,7						; Clear GAS_SWITCH bit
	rcall	TFT_display_deko_output_depth ; Outputs depth (stored in lo) to POSTINC2 with "m" or w/o (For ft)
	movff	char_O_deco_time+6,lo		; length of stop in min
	output_99
	STRCAT_PRINT "'"
	goto	TFT_standard_color			; and return...


	global	TFT_clear_safety_stop
TFT_clear_safety_stop:
	bcf		FLAG_TFT_clear_safety_stop		; clear flag
	WIN_BOX_BLACK	dm_safetystop_row, dm_safetystop_bot, dm_safetystop_text_column, .159	; top, bottom, left, right
	return

	global	TFT_show_safety_stop
TFT_show_safety_stop:
	bcf		FLAG_TFT_show_safety_stop
	tstfsz	safety_stop_countdown			; Countdown at zero?
	bra		TFT_show_safety_stop2			; No, show stop
	bcf		show_safety_stop				; Clear flag
	btfss	safety_stop_active				; Displayed?
	return									; No
	bcf		safety_stop_active				; Clear flag
	btfsc	divemode_menu					; Is the dive mode menu shown?
	return									; Yes, return
	bra		TFT_clear_safety_stop			; Yes, Clear stop ; and return...
TFT_show_safety_stop2:
	bsf		safety_stop_active				; Set flag
	decf	safety_stop_countdown,F			; Reduce countdown
	btfsc	divemode_menu					; Is the dive mode menu shown?
	return									; Yes, return
	;btfsc	menuview
	;bra	 TFT_show_safety_stop3			; No room when menuview=1...
	call	TFT_divemask_color
	WIN_STD	 dm_safetystop_text_column, dm_safetystop_text_row
	STRCPY_TEXT_PRINT tDiveSafetyStop
TFT_show_safety_stop3:
	call	TFT_attention_color			 ; show in yellow
	WIN_MEDIUM	dm_safetystop_column, dm_safetystop_row
	movff	safety_stop_countdown,lo
	clrf	hi
	call	convert_time					; converts hi:lo in seconds to mins (hi) and seconds (lo)
	movf	hi,W
	movff	lo,hi
	movwf	lo								; exchange lo and hi
	bsf		leftbind
	output_8
	bcf		leftbind
	PUTC	':'
	movff	hi,lo
	output_99x
	STRCAT_PRINT ""
	WIN_FONT FT_SMALL
	goto	TFT_standard_color				; and return...


	global	TFT_mask_avr_stopwatch			; Show mask for average depth and stopwatch
TFT_mask_avr_stopwatch:
	; The mask
	call	TFT_divemask_color
	WIN_TINY dm_custom_avr_stop_title_column1,dm_custom_avr_stop_title_row
	STRCPY_TEXT_PRINT tDiveTotalAvg
	WIN_TINY dm_custom_avr_stop_title_column2,dm_custom_avr_stop_title_row
	STRCPY_TEXT_PRINT tDiveStopwatch
	WIN_TINY dm_custom_avr_stop_title_column3,dm_custom_avr_stop_title_row
	STRCPY_TEXT_PRINT tDiveStopAvg
	goto	TFT_standard_color				; and return...

	global	TFT_update_avr_stopwatch		; Update average depth and stopwatch
TFT_update_avr_stopwatch:
	call	TFT_standard_color
	SAFE_2BYTE_COPY	average_divesecs,lo
	call	convert_time				; lo=secs, hi=mins
	WIN_MEDIUM dm_custom_avr_stop_column2,dm_custom_avr_stop_row
	bsf		leftbind
	movf	hi,W
	movff	lo,hi
	movwf	lo							; exchange lo and hi
	output_8
	PUTC	':'
	movff	hi,lo
	output_99x
	movlw	.5
	call	TFT_fillup_with_spaces		; Fillup FSR2 with spaces (Total string length in #WREG)
	clrf	WREG
	movff	WREG,buffer+.5				; limit to 5 chars
	STRCAT_PRINT ""
	TSTOSS	opt_units					; 0=m, 1=ft
	bra		TFT_update_avr_stopwatch_metric
	;TFT_update_avr_stopwatch_imperial
	movff	avg_rel_pressure_total+0,lo
	movff	avg_rel_pressure_total+1,hi
	call	adjust_depth_with_salinity	; computes salinity setting into lo:hi [mbar]
	call	convert_mbar_to_feet		; convert value in lo:hi from mbar to feet
	WIN_MEDIUM dm_custom_avr_stop_column1,dm_custom_avr_stop_row
	bsf		leftbind
	output_16							; yxz
	STRCAT_PRINT " "
	; Stopped average depth
	movff	avg_rel_pressure+0,lo
	movff	avg_rel_pressure+1,hi
	call	adjust_depth_with_salinity	; computes salinity setting into lo:hi [mbar]
	call	convert_mbar_to_feet		; convert value in lo:hi from mbar to feet
	WIN_MEDIUM dm_custom_avr_stop_column3,dm_custom_avr_stop_row
	output_16							; yxz
	bcf		leftbind
	PUTC	" "
	clrf	WREG
	movff	WREG,buffer+.3				; limit string length to 3
	STRCAT_PRINT ""
	return

TFT_update_avr_stopwatch_metric:
	; Non-resettable average depth
	movff	avg_rel_pressure_total+0,lo
	movff	avg_rel_pressure_total+1,hi
	call	adjust_depth_with_salinity	; computes salinity setting into lo:hi [mbar]
	WIN_MEDIUM dm_custom_avr_stop_column1,dm_custom_avr_stop_row
	bsf		ignore_digit5				; no cm
	output_16dp .3						; yxz.a
	STRCAT_PRINT " "
	; Stopped average depth
	movff	avg_rel_pressure+0,lo
	movff	avg_rel_pressure+1,hi
	call	adjust_depth_with_salinity	; computes salinity setting into lo:hi [mbar]
	WIN_MEDIUM dm_custom_avr_stop_column3,dm_custom_avr_stop_row
	bsf		ignore_digit5				; no cm
	output_16dp .3						; yxz.a
	bcf		leftbind
	bcf		ignore_digit5
	clrf	WREG
	movff	WREG,buffer+.4				; limit string length to 4
	STRCAT_PRINT ""
	return


	global	TFT_ceiling_mask			; The ceiling mask
TFT_ceiling_mask:
	call	TFT_divemask_color
	WIN_TINY	dm_custom_ceiling_text_column,dm_custom_ceiling_text_row
	STRCPY_TEXT_PRINT tCeiling
	goto	TFT_standard_color			; and return...

	global	TFT_ceiling					; Ceiling
TFT_ceiling:
	WIN_MEDIUM dm_custom_ceiling_value_column,dm_custom_ceiling_value_row
	movff	int_O_ceiling+0,lo
	movff	int_O_ceiling+1,hi
	call	TFT_color_code_ceiling		; color-code the output
	call	adjust_depth_with_salinity	; computes salinity setting into lo:hi [mbar]
	bsf		leftbind
	TSTOSS	opt_units					; 0=m, 1=ft
	bra		TFT_ceiling_metric
;TFT_ceiling_imperial
	call	convert_mbar_to_feet		; convert value in lo:hi from mbar to feet
	output_16							; yxz
	bcf		leftbind
	STRCAT_PRINT " "
	goto	TFT_standard_color

TFT_ceiling_metric:
	bsf	 ignore_digit5					; no cm
	output_16dp .3						; yxz.a
	bcf		leftbind
	bcf		ignore_digit5
	STRCAT_PRINT " "
	goto	TFT_standard_color


	global	TFT_CNS_mask
TFT_CNS_mask:
	call	TFT_divemask_color
	WIN_TINY dm_custom_gf_title_col1, dm_custom_gf_title_row
	STRCPY_TEXT_PRINT tCNSsurf
	WIN_TINY dm_custom_gf_title_col2, dm_custom_gf_title_row
	btfsc	FLAG_ccr_mode						; in CCR mode?
	bra		TFT_CNS_mask_1						; YES - proceed with checking for bailout
	btfsc	FLAG_pscr_mode						; NO  -	in pSCR mode?
	bra		TFT_CNS_mask_1						;       YES - proceed with checking for bailout
	bra		TFT_CNS_mask_2						;       NO  - must be OC then
TFT_CNS_mask_1:									; in CCR or pSCR mode
	btfsc	is_bailout							; in bailout?
	bra		TFT_CNS_mask_2						; YES - print fTTS label (label will be printed, but a fTTS will actually not be calculated)
	TSTOSS	opt_calc_asc_gasvolume				; NO  - bailout volume calculation requested?
	bra		TFT_CNS_mask_2						;       NO  - print fTTS label
	STRCPY_TEXT_PRINT tCNSBO					;       YES - print bailout label
	bra		TFT_CNS_mask_3
TFT_CNS_mask_2:									; OC or bailout
	STRCPY_TEXT_PRINT tCNSfTTS					; print fTTS label
TFT_CNS_mask_3:
	WIN_TINY dm_custom_gf_title_col3, dm_custom_gf_title_row
	STRCPY_TEXT_PRINT tCNSnow
	goto	TFT_standard_color					; and return...

	global	TFT_CNS
TFT_CNS:
	; CNS at end of normal dive
	WIN_STD dm_custom_hud_sensor1_column+.5,dm_custom_hud_data_row
	movff	int_O_normal_CNS_fraction+0,lo
	movff	int_O_normal_CNS_fraction+1,hi
	call	TFT_color_code_cns
	bsf		leftbind
	output_16_3									; output as xxx
	bcf		leftbind
	STRCAT_PRINT "% "
	; fTTS / Bailout CNS, if enabled
	WIN_STD dm_custom_hud_sensor2_column+.2,dm_custom_hud_data_row
	btfsc	is_bailout							; in bailout?
	bra		TFT_CNS_3							; YES - show "---"
	TSTOSS	opt_calc_asc_gasvolume				; NO  - bailout volume calculation requested?
	bra		TFT_CNS_1							;       NO  - continue checking fTTS extra time
	btfsc	FLAG_ccr_mode						;       YES - in CCR mode?
	bra		TFT_CNS_2							;             YES - skip test for fTTS extra time and show CNS%
	btfsc	FLAG_pscr_mode						;             in pSCR mode?
	bra		TFT_CNS_2							;             YES - skip test for fTTS extra time and show CNS%
TFT_CNS_1:										; not in bailout, no volume calculation
	TSTOSS	char_I_extra_time					; fTTS extra time fTTS configured?
	bra		TFT_CNS_3							; NO  - show "---"
TFT_CNS_2:
	movff	int_O_alternate_CNS_fraction+0,lo	; YES - show CNS%
	movff	int_O_alternate_CNS_fraction+1,hi
	call	TFT_color_code_cns
	bsf		leftbind
	output_16_3									; output as xxx
	bcf		leftbind
	STRCAT_PRINT "% "
	bra		TFT_CNS_4
TFT_CNS_3:
	call	TFT_standard_color
	STRCPY_PRINT "---  "
TFT_CNS_4:
	; current CNS
	WIN_STD dm_custom_hud_sensor3_column,dm_custom_hud_data_row
	movff	int_O_CNS_fraction+0,lo
	movff	int_O_CNS_fraction+1,hi
	call	TFT_color_code_cns
	bsf		leftbind
	output_16_3									; output as xxx
	bcf		leftbind
	STRCAT_PRINT "%"
	goto	TFT_standard_color					; and return...


	global	TFT_hud_mask						; The HUD mask
TFT_hud_mask:
	call	TFT_divemask_color
	WIN_TINY dm_custom_hud_column1,dm_custom_hud_row
	STRCPY_TEXT_PRINT tDiveHudMask1
	WIN_TINY dm_custom_hud_column2,dm_custom_hud_row
	STRCPY_TEXT_PRINT tDiveHudMask2
	WIN_TINY dm_custom_hud_column3,dm_custom_hud_row
	STRCPY_TEXT_PRINT tDiveHudMask3
	goto	TFT_standard_color					; and return...


	global	TFT_update_ppo2_sensors				; Update Sensor data
TFT_update_ppo2_sensors:
;
; Definition of the output:
;
;  sensorX       use        voting         o2
; _calibrated    _O2       _logic        _ppo2          Output           Color
;    _ok      _sensorX    _sensorX     _sensorX
;-----------------------------------------------------------------------------------------------
;    0          -/-          -/-            -/-         "----"           TFT_standard_color
;    1           0           -/-            = 0         o2_ppo2_sensorX  TFT_attention_color
;    1           0           -/-            > 0         o2_ppo2_sensorX  TFT_disabled_color
;    1           1            0             -/-         o2_ppo2_sensorX  TFT_color_code_ppo2_hud + win_invert
;    1           1            1             -/-         o2_ppo2_sensorX  TFT_color_code_ppo2_hud
;
	bsf		leftbind
	; sensor 1
	btfsc	sensor1_calibrated_ok		; valid calibration?
	bra	TFT_update_hud1b				; yes
	; no valid calibration
	WIN_STD dm_custom_hud_sensor1_column+.7, dm_custom_hud_data_row+.5
	call	TFT_standard_color
	STRCPY_PRINT "---"
	bra		TFT_update_hud2a			; continue with sensor 2
TFT_update_hud1b:
	; sensor has a valid calibration
	WIN_MEDIUM dm_custom_hud_sensor1_column,dm_custom_hud_data_row
	movff	o2_ppo2_sensor1,lo			; load ppO2 value into transfer storage for output
	clrf	hi							; 
	btfsc	use_O2_sensor1				; in use?
	bra		TFT_update_hud1d			; yes
	; valid calibration, but not in use
	tstfsz	o2_ppo2_sensor1				; sensor value = 0?
	bra		TFT_update_hud1c			; no
	; valid calibration, not in use and value = 0
	call	TFT_attention_color			; output in yellow
	bra		TFT_update_hud1e
TFT_update_hud1c:
	; sensor has valid calibration, is not in use and has a value > 0
	call	TFT_disabled_color			; output in light blue
	bra		TFT_update_hud1e
TFT_update_hud1d:
	; sensor has valid calibration and is in use
	call	TFT_color_code_ppo2_hud		; With ppO2 [cbar] in lo
	btfsc	voting_logic_sensor1		; sensor value agrees with other sensor's values?
	bra		TFT_update_hud1e			; yes
	; valid calibration, in use, but value does not agree with other sensors
	bsf		win_invert					; invert output
TFT_update_hud1e:
	; all coloring is set up now, let's write the value to the display!
	bsf		leftbind
	output_16dp .3						; x.xx bar
	bcf		leftbind
	STRCAT_PRINT ""
	bcf		win_invert

TFT_update_hud2a:						; sensor 2
	btfsc	sensor2_calibrated_ok		; valid calibration?
	bra		TFT_update_hud2b			; yes
	; no valid calibration
	WIN_STD dm_custom_hud_sensor2_column+.7, dm_custom_hud_data_row+.5
	call	TFT_standard_color
	STRCPY_PRINT "---"
	bra		TFT_update_hud3a			; continue with sensor 3
TFT_update_hud2b:
	; sensor has a valid calibration
	WIN_MEDIUM dm_custom_hud_sensor2_column,dm_custom_hud_data_row
	movff	o2_ppo2_sensor2,lo			; load ppO2 value into transfer storage for output
	clrf	hi							; 
	btfsc	use_O2_sensor2				; in use?
	bra		TFT_update_hud2d			; yes
	; valid calibration, but not in use
	tstfsz	o2_ppo2_sensor2				; sensor value = 0?
	bra		TFT_update_hud2c			; no
	; valid calibration, not in use and value = 0
	call	TFT_attention_color			; output in yellow
	bra		TFT_update_hud2e
TFT_update_hud2c:
	; sensor has valid calibration, is not in use and has a value > 0
	call	TFT_disabled_color			; output in light blue
	bra		TFT_update_hud2e
TFT_update_hud2d:
	; sensor has valid calibration and is in use
	call	TFT_color_code_ppo2_hud		; With ppO2 [cbar] in lo
	btfsc	voting_logic_sensor2		; sensor value agrees with other sensor's vlaues?
	bra		TFT_update_hud2e			; yes
	; valid calibration, in use, but value does not agree with other sensors
	bsf		win_invert					; invert output
TFT_update_hud2e:
	; all coloring is set up now, let's write the value to the display!
	bsf		leftbind
	output_16dp .3						; x.xx bar
	bcf		leftbind
	STRCAT_PRINT ""
	bcf		win_invert

TFT_update_hud3a:						; sensor 3
	btfsc	sensor3_calibrated_ok		; valid calibration?
	bra		TFT_update_hud3b			; yes
	; no valid calibration
	WIN_STD dm_custom_hud_sensor3_column+.7, dm_custom_hud_data_row+.5
	call	TFT_standard_color
	STRCPY_PRINT "---"
	bra		TFT_update_hud4				; done
TFT_update_hud3b:
	; sensor has a valid calibration
	WIN_MEDIUM dm_custom_hud_sensor3_column,dm_custom_hud_data_row
	movff	o2_ppo2_sensor3,lo			; load ppO2 value into transfer storage for output
	clrf	hi							; 
	btfsc	use_O2_sensor3				; in use?
	bra		TFT_update_hud3d			; yes
	; valid calibration, but not in use
	tstfsz	o2_ppo2_sensor3				; sensor value = 0?
	bra		TFT_update_hud3c			; no
	; valid calibration, not in use and value = 0
	call	TFT_attention_color			; output in yellow
	bra		TFT_update_hud3e
TFT_update_hud3c:
	; sensor has valid calibration, is not in use and has a value > 0
	call	TFT_disabled_color			; output in light blue
	bra		TFT_update_hud3e
TFT_update_hud3d:
	; sensor has valid calibration and is in use
	call	TFT_color_code_ppo2_hud		; With ppO2 [cbar] in lo
	btfsc	voting_logic_sensor3		; sensor value agrees with other sensor's vlaues?
	bra		TFT_update_hud3e			; yes
	; valid calibration, in use, but value does not agree with other sensors
	bsf		win_invert					; invert output
TFT_update_hud3e:
	; all coloring is set up now, let's write the value to the display!
	bsf		leftbind
	output_16dp .3						; x.xx bar
	bcf		leftbind
	STRCAT_PRINT ""
	bcf		win_invert

TFT_update_hud4:						; closure
	bcf		leftbind
	goto	TFT_standard_color			; and return...


	global	TFT_surface_sensor			; Update Sensor data in surface mode
TFT_surface_sensor:
	movf	hardware_flag,W
	sublw	0x11						; 2 with BLE
	btfsc	STATUS,Z
	return								; Ignore for 0x11
	; show three sensors
	bsf		leftbind
	WIN_SMALL surf_hud_sensor1_column,surf_hud_sensor1_row
	btfsc	sensor1_calibrated_ok
	bra		TFT_surface_sensor1			; Yes
	call	TFT_standard_color
	STRCPY_PRINT "--- "
	bra		TFT_surface_sensor2			; Skip Sensor 1
TFT_surface_sensor1:
	movff	o2_ppo2_sensor1,lo
	call	TFT_color_code_ppo2_hud		; With ppO2 [cbar] in lo
	clrf	hi
	bsf		leftbind
	output_16dp .3						; x.xx bar
	bcf		leftbind
	STRCAT_PRINT ""
TFT_surface_sensor2:
	WIN_SMALL surf_hud_sensor2_column,surf_hud_sensor2_row
	btfsc	sensor2_calibrated_ok
	bra		TFT_surface_sensor3			; Yes
	call	TFT_standard_color
	STRCPY_PRINT "--- "
	bra		TFT_surface_sensor4			; Skip Sensor 2
TFT_surface_sensor3:
	movff	o2_ppo2_sensor2,lo
	call	TFT_color_code_ppo2_hud		; With ppO2 [cbar] in lo
	clrf	hi
	bsf		leftbind
	output_16dp .3						; x.xx bar
	bcf		leftbind
	STRCAT_PRINT ""
TFT_surface_sensor4:
	WIN_SMALL surf_hud_sensor3_column,surf_hud_sensor3_row
	btfsc	sensor3_calibrated_ok
	bra	TFT_surface_sensor5				; Yes
	call	TFT_standard_color
	STRCPY_PRINT "--- "
	bra		TFT_surface_sensor6			; Skip Sensor 3
TFT_surface_sensor5:
	movff	o2_ppo2_sensor3,lo
	call	TFT_color_code_ppo2_hud		; With ppO2 [cbar] in lo
	clrf	hi
	bsf		leftbind
	output_16dp .3						; x.xx bar
	bcf		leftbind
	STRCAT_PRINT ""
TFT_surface_sensor6:
	bcf		leftbind
	goto	TFT_standard_color			; and return...


	global	TFT_sensor_mV 
TFT_sensor_mV: 
	call	TFT_standard_color 
	bsf		leftbind
	WIN_SMALL surf_mV_sensor_column,surf_mV_sensor1_row
	movff	o2_mv_sensor1+0,lo			; in 0.1mV steps
	movff	o2_mv_sensor1+1,hi			; in 0.1mV steps
	STRCAT	"1: "
	output_16dp .4						; xxx.y mV 
	STRCAT_PRINT "mV "
	
	WIN_SMALL surf_mV_sensor_column,surf_mV_sensor2_row
	movff	o2_mv_sensor2+0,lo			; in 0.1mV steps
	movff	o2_mv_sensor2+1,hi			; in 0.1mV steps
	STRCAT	"2: "
	output_16dp .4						; xxx.y mV 
	STRCAT_PRINT "mV "

	WIN_SMALL surf_mV_sensor_column,surf_mV_sensor3_row
	movff	o2_mv_sensor3+0,lo			; in 0.1mV steps
	movff	o2_mv_sensor3+1,hi			; in 0.1mV steps
	STRCAT	"3: "
	output_16dp .4						; xxx.y mV
	STRCAT_PRINT "mV "
	bcf		leftbind 
	goto	TFT_standard_color			; and return...


	global	TFT_sensor_surface_warning
TFT_sensor_surface_warning: 
	call	TFT_warnings_color
	btfss	sensor1_calibrated_ok		; do not show end of lifetime arrow if sensor failed calibration at all
	bra		TFT_sensor_mV2
	movff	opt_x_s1+1,lo				; into bank1
	movf	lo,W						; when opt_x_s1 > 255 the sensor will just give 8 mV at a ppO2 of 0,21 any more 
	bz		TFT_sensor_mV2				; the sensor is not too bad yet for a warning 
	WIN_SMALL surf_mV_sensor_status_column,surf_mV_sensor1_row-.5 
	STRCPY_PRINT "\xb8"					; mark sensor as being at end of lifetime
TFT_sensor_mV2:
	btfss	sensor2_calibrated_ok		; do not show end of lifetime arrow if sensor failed calibration at all
	bra		TFT_sensor_mV3
	movff	opt_x_s2+1,lo				; into bank1
	movf	lo,W						; when opt_x_s2 > 255 the sensor will just give 8 mV at a ppO2 of 0,21 any more 
	bz		TFT_sensor_mV3				; the sensor is not too bad yet for a warning 
	WIN_SMALL surf_mV_sensor_status_column,surf_mV_sensor2_row-.5 
	STRCPY_PRINT "\xb8"					; mark sensor as being at end of lifetime 
TFT_sensor_mV3:
	btfss	sensor3_calibrated_ok		; do not show end of lifetime arrow if sensor failed calibration at all
	bra		TFT_sensor_mV4
	movff	opt_x_s3+1,lo				; into bank1
	movf	lo,W						; when opt_x_s3 > 255 the sensor will just give 8 mV at a ppO2 of 0,21 any more 
	bz		TFT_sensor_mV4				; the sensor is not too bad yet for a warning 
	WIN_SMALL surf_mV_sensor_status_column,surf_mV_sensor3_row-.5
	STRCPY_PRINT "\xb8"					; mark sensor as being at end of lifetime 
TFT_sensor_mV4:
	goto	TFT_standard_color			; ...and return


	global	TFT_menu_calibrate
TFT_menu_calibrate:						; update mV data in calibration menu
	btfss	s8_digital					; =1: Digital I/O
	bra		TFT_menu_calibrate_analog	; use analog
	btfss	new_s8_data_available		; new data frame received?
	bra		TFT_menu_calibrate_common	; NO - use old values...
	; YES - update the values
	call	compute_mvolts_for_all_sensors
	bra		TFT_menu_calibrate_common
TFT_menu_calibrate_analog:
	call	get_analog_inputs
TFT_menu_calibrate_common:
	call	TFT_attention_color			; show in yellow
	bsf		leftbind
	WIN_SMALL	surf_menu_sensor1_column,surf_menu2_sensor1_row
	movff	o2_mv_sensor1+0,lo			; in 0.1mV steps
	movff	o2_mv_sensor1+1,hi			; in 0.1mV steps
	output_16dp .4						; xxx.y mV
	STRCAT_PRINT "mV  "
	WIN_SMALL	surf_menu_sensor2_column,surf_menu2_sensor2_row
	movff	o2_mv_sensor2+0,lo			; in 0.1mV steps
	movff	o2_mv_sensor2+1,hi			; in 0.1mV steps
	output_16dp .4						; xxx.y mV
	STRCAT_PRINT "mV  "
	WIN_SMALL	surf_menu_sensor3_column,surf_menu2_sensor3_row
	movff	o2_mv_sensor3+0,lo			; in 0.1mV steps
	movff	o2_mv_sensor3+1,hi			; in 0.1mV steps
	output_16dp .4						; xxx.y mV
	STRCAT_PRINT "mV  "
	bcf		leftbind
	goto	TFT_standard_color			; ...and return


	global	TFT_clock
TFT_clock:
	WIN_SMALL surf_clock_column,surf_clock_row
TFT_clock2:								; called from divemode clock
	call	TFT_standard_color
	movff	hours,lo
	output_99
	movlw	':'
	btfss	secs,0						; blinking every second
	movlw	' '
	movwf	POSTINC2
	movff	mins,lo
	output_99x
	STRCAT_PRINT ""
	return

	global	TFT_show_time_date_menu
TFT_show_time_date_menu:
	call	speed_fastest
	WIN_SMALL .15,.30
	call	TFT_standard_color
	movff	hours,lo
	output_99
	PUTC	':'
	movff	mins,lo
	output_99x
	PUTC	':'
	movff	secs,lo
	output_99x
	STRCAT	" - "
	movff	day,lo
	movff	month,hi
	movff	year,up
	call	TFT_convert_date			; converts into "DD/MM/YY" or "MM/DD/YY" or "YY/MM/DD" in postinc2
	STRCAT_PRINT " "
	return

;=============================================================================

	global	TFT_surface_decosettings	; Show all deco settings
TFT_surface_decosettings:
	; Deco Mode
	call	TFT_standard_color
	WIN_SMALL surf_gaslist_column,surf_gaslist_row
	STRCAT_PRINT "ZH-L16"
	movff	char_I_deco_model,WREG
	iorwf	WREG
	bnz		TFT_surface_decosettings1
	; Display ZH-L16 sat/desat model
	WIN_SMALL surf_gaslist_column,surf_gaslist_row+(surf_gaslist_spacing*.1)
	lfsr	FSR2,buffer
	movff	char_I_desaturation_multiplier,lo
	bsf		leftbind
	output_8
	STRCAT	"%/"
	movff	char_I_saturation_multiplier,lo
	output_8
	STRCAT_PRINT "%"
	bra		TFT_surface_decosettings2
	; Display ZH-L16-GF low/high model
TFT_surface_decosettings1:
	TEXT_SMALL surf_gaslist_column+.43,surf_gaslist_row,tZHL16GF
	WIN_SMALL  surf_gaslist_column,surf_gaslist_row+(surf_gaslist_spacing*.1)
	STRCPY_TEXT	tGF						; GF:
	movff	opt_GF_low,lo
	output_99x
	STRCAT	"/"
	movff	opt_GF_high,lo
	output_99x
	STRCAT_PRINT ""
TFT_surface_decosettings2:				; fTTS
	WIN_SMALL surf_gaslist_column,surf_gaslist_row+(surf_gaslist_spacing*.2)
	STRCPY_TEXT tFTTSMenu
	movff	char_I_extra_time,lo
	bsf		leftbind
	output_8
	STRCAT_TEXT_PRINT tMinutes
	; Last Stop
	WIN_SMALL surf_gaslist_column,surf_gaslist_row+(surf_gaslist_spacing*.3)
	STRCPY_TEXT tLastDecostop
	movff	opt_last_stop,lo
	output_8
	STRCAT_TEXT_PRINT tMeters
	; Salinity
	WIN_SMALL surf_gaslist_column,surf_gaslist_row+(surf_gaslist_spacing*.4)
	STRCPY_TEXT tDvSalinity
	movff	opt_salinity,lo
	output_8
	bcf		leftbind
	STRCAT_TEXT_PRINT tPercent
	return

	global	TFT_debug_output
TFT_debug_output:
	return
	WIN_TINY .80,.0
	call	TFT_standard_color
	lfsr	FSR2,buffer
	movff	analog_sw1,lo
	output_8
	PUTC	","
	movff	analog_sw2,lo
	output_8
	STRCAT_PRINT ""
	return

	global	TFT_divetimeout				; Show timeout counter
TFT_divetimeout:
	call	TFT_warning_set_window		; Sets the row and column for the current warning
	tstfsz	WREG						; Is there room for the warning?
	return								; No
	call	TFT_standard_color
	STRCPY	0x94						; "End of dive" icon
	movff	opt_diveTimeout,WREG		; in [min]
	mullw	.60
	movff	PRODL,sub_a+0
	movff	PRODH,sub_a+1				; in [s]
	movff	timeout_counter1+0,sub_b+0
	movff	timeout_counter1+1,sub_b+1
	call	subU16						; sub_c = sub_a - sub_b (with UNSIGNED values)
	movff	sub_c+0,lo
	movff	sub_c+1,hi
	call	convert_time				; converts hi:lo in minutes to hours (hi) and minutes (lo)
	movf	hi,W
	movff	lo,hi
	movwf	lo							; exchange lo and hi
	output_99x
	PUTC	':'
	movff	hi,lo
	output_99x
	movlw	dm_warning_length			; Divemode string length
	call	TFT_fillup_with_spaces		; Fillup FSR2 with spaces (Total string length in #WREG)
	STRCAT_PRINT ""
	bcf		win_invert
	return

	global	TFT_display_ftts
TFT_display_ftts:
	movff	char_I_extra_time,lo
	tstfsz	lo
	bra		TFT_display_ftts_a
	return								; char_I_extra_time=0, return.
TFT_display_ftts_a:
	movff	int_O_alternate_ascenttime+0,WREG
	movff	int_O_alternate_ascenttime+1,hi
	iorwf	hi,W						; int_O_alternate_ascenttime:2 == 0 ?
	bnz		TFT_display_ftts_b
	return								; No deco, do nothing
TFT_display_ftts_b:
	btfsc	is_bailout					; check if we are in bailout mode
	return								; YES - in bailout no fTTS will be computed, so nothing to display
	incf	warning_counter,F			; increase counter
	call	TFT_warning_set_window		; sets the row and column for the current warning
	tstfsz	WREG						; is there room for the warning?
	return								; NO
	btfsc	FLAG_ccr_mode				; in CCR mode?
	bra		TFT_display_ftts_1			; YES - print fTTS label
	btfsc	FLAG_pscr_mode				; NO  - in pSCR mode?
	bra		TFT_display_ftts_1			;       YES - print fTTS label
	bra		TFT_display_ftts_2			;       NO  - must be OC then
TFT_display_ftts_1:						; in CCR or pSCR mode
	btfsc	is_bailout					; in bailout?
	bra		TFT_display_ftts_2			; YES - print fTTS label
	TSTOSS	opt_calc_asc_gasvolume		; NO  - bailout volume calculation requested?
	bra		TFT_display_ftts_2			;       NO  - print fTTS label
	STRCPY	"B/O"						;       YES - print bailout label
	bra		TFT_display_ftts_3
TFT_display_ftts_2:						; OC or bailout
	STRCPY	"@+"						; print fTTS label
TFT_display_ftts_3:
	movff	char_I_extra_time,lo
	bsf		leftbind
	output_8
	PUTC	":"
	movff	int_O_alternate_ascenttime+0,lo
	movff	int_O_alternate_ascenttime+1,hi
	btfss	hi,int_invalid_flag				; is the invalid flag set?
	bra		TFT_display_ftts1				; NO
	bcf		hi,int_invalid_flag				; YES - clear flag
	call	TFT_disabled_color				;       switch to disabled color
TFT_display_ftts1:
	movf	lo,W
	iorwf	hi,W							; extra_ascenttime == 0 ?
	bz		TFT_display_ftts2				; YES - show dashes
	btfsc	hi,int_not_yet_computed			; is the not-computed-yet flag set?
	bra		TFT_display_ftts2				; YES
	output_16								; NO
	bcf		leftbind
	PUTC	"'"
	movlw	dm_warning_length				; Divemode string length
	call	TFT_fillup_with_spaces			; Fillup FSR2 with spaces (Total string length in #WREG)
	STRCAT_PRINT ""
	bcf		win_invert
	goto	TFT_standard_color				; ...and return
TFT_display_ftts2:
	STRCAT	"---"
	bcf		leftbind
	movlw	dm_warning_length				; Divemode string length
	call	TFT_fillup_with_spaces			; Fillup FSR2 with spaces (Total string length in #WREG)
	STRCAT_PRINT ""
	bcf		win_invert
	goto	TFT_standard_color				; ...and return


;=============================================================================

	global	TFT_temp_surfmode
TFT_temp_surfmode:
	call	TFT_divemask_color
	WIN_SMALL surf_temp_column+3*8,surf_temp_row
	TSTOSS	opt_units						; 0=°C, 1=°F
	bra		TFT_temp_surfmode_metric
	STRCAT_TEXT tLogTunitF					; °F
	bra		TFT_temp_surfmode_common
TFT_temp_surfmode_metric:
	STRCAT_TEXT tLogTunitC					; °C
TFT_temp_surfmode_common:
	STRCAT_PRINT ""
	WIN_SMALL surf_temp_column,surf_temp_row
	bra		TFT_temp_common


	global	TFT_temp_divemode
TFT_temp_divemode:
	bcf		FLAG_TFT_temp_divemode
	btfsc	divemode_menu					; Is the dive mode menu shown?
	return									; Yes, no update of temperature now
	btfsc	blinking_better_gas				; blinking better Gas?
	return									; Yes, no update of temperature now
	WIN_SMALL	dm_temp_column,dm_temp_row
TFT_temp_common:
	call	TFT_standard_color
	SAFE_2BYTE_COPY temperature,lo			; get current temperature
	TSTOSS	opt_units						; 0=°C, 1=°F
	bra		TFT_temp_common_1
	call	convert_celsius_to_fahrenheit	; convert value in lo:hi from celsius to fahrenheit
TFT_temp_common_1:
	rcall	TFT_convert_signed_16bit		; converts lo:hi into signed-short and adds '-' to POSTINC2 if required
	btfsc	neg_flag						; is the temperature negative?
	bra		TFT_temp_common_2				; YES - the minus sign has already been written
	; temp is positive, is it less then 10°C? 
	tstfsz	hi
	bra		TFT_temp_common_1a				; >25.5°C, skip here
	movlw	.100
	cpfslt	lo
	bra		TFT_temp_common_1a				; >10.0°C, skip here
	bsf		leftbind
	output_16dp	d'4'						; x.y°C
	bcf		leftbind
	bra		TFT_temp_common_3				; Done.
TFT_temp_common_1a:
	PUTC	" "								; NO  - write a space instead of the minus sign
TFT_temp_common_2:
	bsf		ignore_digit5					; ignore decimal
	output_16_3								; output 0-999 without decimal -> writes ' ' - 99
	bcf		ignore_digit5
	movff	buffer+2,lo						; get output from unit position
	movlw	" "								; load code of the space character
	cpfseq	lo								; is there a space sign on the unit position? (happens between +1 and -1)
	bra		TFT_temp_common_3				; NO
	movff	WREG,buffer+0					; YES - replace potential minus sign with a space (temps from -0.9° to -0.1° else would appear as '- 0')
	movlw	"0"								; load code of the zero character
	movff	WREG,buffer+2					; replace space with a zero
TFT_temp_common_3:
	btfss	divemode						; are we in dive mode?
	bra		TFT_temp_common_5				; NO  - no unit to append
	TSTOSS	opt_units						; YES - check unit type: 0=°C, 1=°F
	bra		TFT_temp_common_4				; go metric
	STRCAT_TEXT tLogTunitF					; append °F
	bra		TFT_temp_common_5
TFT_temp_common_4:
	STRCAT_TEXT tLogTunitC					; append °C
TFT_temp_common_5:
	STRCAT_PRINT ""							; output to screen
	return

;=============================================================================

	global	TFT_divemode_menu_cursor
TFT_divemode_menu_cursor:
	WIN_BOX_BLACK dm_menu_row+.1, dm_menu_lower-.1, dm_menu_item1_column-.8, dm_menu_item1_column-.1
	WIN_BOX_BLACK dm_menu_row+.1, dm_menu_lower-.1, dm_menu_item4_column-.8, dm_menu_item4_column-.1
	call	TFT_standard_color

	movlw	dm_menu_item1_column-.8
	btfsc	menupos1,2					; >3?
	movlw	dm_menu_item4_column-.8		; Yes
	movff	WREG,win_leftx2

	movff	menupos1,lo					; Copy menu position
	movlw	dm_menu_item6_row
	dcfsnz	lo,F
	movlw	dm_menu_item1_row
	dcfsnz	lo,F
	movlw	dm_menu_item2_row
	dcfsnz	lo,F
	movlw	dm_menu_item3_row
	dcfsnz	lo,F
	movlw	dm_menu_item4_row
	dcfsnz	lo,F
	movlw	dm_menu_item5_row
	movff	WREG,win_top
	movlw	FT_SMALL
	movff	WREG,win_font
	STRCPY_PRINT "\xb7"					; print cursor
	return

	global	TFT_active_gas_divemode
TFT_active_gas_divemode:				; Display gas/Setpoint
	bcf		FLAG_TFT_active_gas_divemode
	btfsc	divemode_menu				; Is the dive mode menu shown?
	return								; Yes, return
	btfsc	FLAG_apnoe_mode				; Ignore in Apnoe mode
	return
	btfsc	FLAG_ccr_mode				; in CCR mode?
	bra		TFT_active_setpoint			; Yes, show setpoint and gas mix
	btfsc	FLAG_pscr_mode				; in PSCR mode?
	bra		TFT_active_setpoint			; Yes, show setpoint and gas mix
	call	TFT_standard_color
	btfss	better_gas_available		; check if a better gas is available and a gas change is advised in divemode
	bra		TFT_active_gas_divemode2	; NO  - print in normal rendering
	btg		blinking_better_gas			; YES - toggle blink bit
	btfss	blinking_better_gas			;       blink now?
	bra		TFT_active_gas_divemode2	;       NO  - print in normal rendering
	call	TFT_attention_color			;       YES - blink in yellow
	bsf		win_invert					;             set invert flag
TFT_active_gas_divemode2:
	WIN_STD dm_active_gas_column, dm_active_gas_row
	movff	char_I_O2_ratio,lo			; lo now stores O2 in %
	movff	char_I_He_ratio,hi			; hi now stores He in %
	call	customview_show_mix			; put "Nxlo", "Txlo/hi", "Air" or "O2" into Postinc2
	STRCAT_PRINT ""
	bcf		win_invert					; reset invert flag
	goto	TFT_standard_color			; ...and return

TFT_active_setpoint:					; Show setpoint
	btfsc	is_bailout					; are we in bailout?
	bra		TFT_active_setpoint_bail	; YES - show "Bailout" instead of setpoint
	movff	int_O_breathed_ppO2+0,lo
	movff	int_O_breathed_ppO2+1,hi
	call	TFT_color_code_ppo2			; with ppO2 [cbar] in hi:lo
	btg		blinking_setpoint			; toggle blink bit...
	btfss	blinking_setpoint			; blink now?
	bra		TFT_active_setpoint_print	; NO  - print ppO2 with normal rendering
	btfsc	setpoint_fallback			; YES - check if we are in fallback condition
	bra		TFT_active_setpoint_fallb	;       YES - process fallback case
	movff	int_O_breathed_ppO2+1,WREG	;       NO  - get flags again (have been cleared in hi:lo by TFT_color_code_ppo2 meanwhile)
	btfss	WREG,int_warning_flag		;             warning flag set?
	bra		TFT_active_setpoint_print	;             NO  - ppO2 is ok, print ppO2 with normal rendering
	bra		TFT_active_setpoint_com		;             YES - continue with blinking common part
TFT_active_setpoint_fallb:				; set up fallback case 
	movlw	color_yellow				; text in yellow 
	call	TFT_set_color				; overwrite setting done by TFT_color_code_ppo2 
TFT_active_setpoint_com:				; blinking common part
	bsf		win_invert					; set invert flag
TFT_active_setpoint_print:
	WIN_STD dm_active_gas_column, dm_active_gas_row
	bsf		leftbind
	output_16dp .3						; x.xx bar
	bcf		leftbind
	STRCAT_TEXT tbar
	movff	opt_ccr_mode,WREG			; =0: Fixed SP, =1: Sensor,  =2: Auto SP
	sublw	.1							; opt_ccr_mode = 1 (Sensor)?
	bnz		TFT_active_setpoint2_a		; NO  - skip
	PUTC	"*"							; YES - add an astrix
TFT_active_setpoint2_a:
	STRCAT_PRINT ""
	bcf		win_invert					; reset invert flag
	call	TFT_standard_color			; revert to standard color
	bra		TFT_active_setpoint_diluent ; continue with showing diluent
TFT_active_setpoint_bail:
	WIN_SMALL dm_active_gas_column, dm_active_gas_row+.3	; collides with diluent in FT_MEDIUM
	call	TFT_standard_color
	STRCPY_TEXT_PRINT tDiveBailout		; Bailout
TFT_active_setpoint_diluent:
	btfss	better_gas_available		; check if a better gas is available and a gas change is advised in divemode
	bra		TFT_active_setpoint_diluent_show	; NO  - print in normal rendering
	btg		blinking_better_gas					; YES - toggle blink bit...
	btfss	blinking_better_gas					; blink now?
	bra		TFT_active_setpoint_diluent_show	; NO  - print in normal rendering
	movlw	color_yellow						; YES - blink in yellow
	call	TFT_set_color						;       set text color
	bsf		win_invert							;       set invert flag
TFT_active_setpoint_diluent_show:
	WIN_SMALL dm_active_dil_column, dm_active_dil_row
	movff	char_I_O2_ratio,lo			; lo now stores O2 in %
	movff	char_I_He_ratio,hi			; hi now stores He in %
	call	customview_show_mix			; put "Nxlo", "Txlo/hi", "Air" or "O2" into Postinc2
	STRCAT_PRINT ""
	bcf		win_invert					; reset invert flag
	goto	TFT_standard_color			; ...and return


	global	TFT_show_mode_divemode
TFT_show_mode_divemode:
	WIN_TINY dm_active_dil_column+.45, dm_active_dil_row+.3
	btfsc	is_bailout					; in bailout?
	return								; YES
	btfsc	FLAG_ccr_mode				; NO  - in CCR mode?
	bra		TFT_show_mode_divemode_ccr	;		YES	- write CCR label
	btfsc	FLAG_pscr_mode				;		NO  - in pSCR mode?
	bra		TFT_show_mode_divemode_pscr	;			  YES - write pSCR label
	return								;			  NO  - done
TFT_show_mode_divemode_ccr:
	call	TFT_standard_color			; set standard color
	STRCPY_TEXT_PRINT tDvCCR			; print "CCR"
	return								; done
TFT_show_mode_divemode_pscr:
	call	TFT_standard_color			; set standard color
	STRCPY_TEXT_PRINT tDvPSCR			; print "PSCR"
	return


	global	TFT_display_decotype_surface
TFT_display_decotype_surface:
	WIN_STD	surf_decotype_column,surf_decotype_row
	WIN_COLOR color_lightblue
	movff	opt_dive_mode,lo			; 0=OC, 1=CC, 2=Gauge, 3=Apnea, 4=PSCR
	tstfsz	lo
	bra		TFT_display_decotype_surface2
TFT_display_decotype_surface0:
	STRCAT_TEXT_PRINT tDvOC				; OC
	bra		TFT_display_decotype_exit
TFT_display_decotype_surface2:
	decfsz	lo,F
	bra		TFT_display_decotype_surface3
	STRCAT_TEXT_PRINT tDvCC				; CC
	call	TFT_standard_color
	WIN_TINY surf_decotype_column+.18,surf_decotype_row+.12
	TSTOSS	opt_ccr_mode				; =0: Fixed SP, =1: Sensor, =2: Auto SP
	bra	 TFT_display_decotype_cc_fixed
	; Sensor mode or Auto
	movff	opt_ccr_mode,WREG
	sublw	.2
	bz		TFT_display_decotype_cc_auto
	STRCPY_TEXT tCCRModeSensor				; Sensor
	bra		TFT_display_decotype_cc_common
TFT_display_decotype_cc_auto:
	STRCPY_TEXT tCCRModeAutoSP				; Auto SP
	bra		TFT_display_decotype_cc_common
TFT_display_decotype_cc_fixed:
	STRCPY_TEXT tCCRModeFixedSP				; Fixed SP
TFT_display_decotype_cc_common:
	clrf	WREG
	movff	WREG,buffer+.8					; limit string length to 8
	STRCAT_PRINT ""
	bra		TFT_display_decotype_exit
TFT_display_decotype_surface3:
	decfsz	lo,F
	bra		TFT_display_decotype_surface4
TFT_display_decotype_surface3_1:
	STRCAT_TEXT_PRINT tDvGauge				; Gauge
	bra		TFT_display_decotype_exit
TFT_display_decotype_surface4:
	decfsz	lo,F
	bra		TFT_display_decotype_surface5
TFT_display_decotype_surface4_1:
	STRCAT_TEXT_PRINT tDvApnea				; Apnea
	bra		TFT_display_decotype_exit
TFT_display_decotype_surface5:
	STRCAT_TEXT_PRINT tDvPSCR				; PSCR
TFT_display_decotype_exit:
	goto	TFT_standard_color				; and return...


	global	TFT_display_decotype_surface1	; Used from logbook!
TFT_display_decotype_surface1:				; Used from logbook!
	tstfsz	lo
	bra		TFT_display_decotype_surface1_2
	bra		TFT_display_decotype_surface0	;OC
TFT_display_decotype_surface1_2:
	decfsz	lo,F
	bra		TFT_display_decotype_surface1_3
	STRCAT_TEXT_PRINT	tDvCC				; CC (w/o Sensor/Fixed Display)
TFT_display_decotype_surface1_3:
	decfsz	lo,F
	bra		TFT_display_decotype_surface1_4
	bra		TFT_display_decotype_surface3_1 ; Gauge
TFT_display_decotype_surface1_4:
	decfsz	lo,F
	bra		TFT_display_decotype_surface4_1 ; Apnea
	bra		TFT_display_decotype_surface5	; PSCR

;=============================================================================

	global	TFT_splist_surfmode			; Show Setpoint list
	extern	gaslist_strcat_setpoint
TFT_splist_surfmode:
	bsf		short_gas_decriptions		; =1: Use short versions of gaslist_strcat_gas_mod and gaslist_strcat_setpoint
	;SP 1
	WIN_SMALL surf_gaslist_column,surf_gaslist_row
	clrf	PRODL
	call	gaslist_strcat_setpoint		; Show SP#+1 of PRODL#
	STRCAT_PRINT ""
	;SP 2
	WIN_SMALL surf_gaslist_column,surf_gaslist_row+(surf_gaslist_spacing*.1)
	movlw	.1
	movwf	PRODL
	call	gaslist_strcat_setpoint		; Show SP#+1 of PRODL#
	STRCAT_PRINT ""
	;SP 3
	WIN_SMALL surf_gaslist_column,surf_gaslist_row+(surf_gaslist_spacing*.2)
	movlw	.2
	movwf	PRODL
	call	gaslist_strcat_setpoint		; Show SP#+1 of PRODL#
	STRCAT_PRINT ""
	;SP 4
	WIN_SMALL surf_gaslist_column,surf_gaslist_row+(surf_gaslist_spacing*.3)
	movlw	.3
	movwf	PRODL
	call	gaslist_strcat_setpoint		; Show SP#+1 of PRODL#
	STRCAT_PRINT ""
	;SP 5
	WIN_SMALL surf_gaslist_column,surf_gaslist_row+(surf_gaslist_spacing*.4)
	movlw	.4
	movwf	PRODL
	call	gaslist_strcat_setpoint		; Show SP#+1 of PRODL#
	STRCAT_PRINT ""
	bcf		leftbind
	return

	global	TFT_gaslist_surfmode
TFT_gaslist_surfmode:					; Displays Gas List
	bsf		short_gas_decriptions		; =1: Use short versions of gaslist_strcat_gas_mod and gaslist_strcat_setpoint
	extern	gaslist_strcat_gas_mod
	;Gas 1
	WIN_SMALL surf_gaslist_column,surf_gaslist_row
	clrf	PRODL
	call	gaslist_strcat_gas_mod		;Append gas description of gas #PRODL (0-4) to current string
	STRCAT_PRINT ""
	;Gas 2
	WIN_SMALL surf_gaslist_column,surf_gaslist_row+(surf_gaslist_spacing*.1)
	movlw	.1
	movwf	PRODL
	call	gaslist_strcat_gas_mod		;Append gas description of gas #PRODL (0-4) to current string
	STRCAT_PRINT ""
	;Gas 3
	WIN_SMALL surf_gaslist_column,surf_gaslist_row+(surf_gaslist_spacing*.2)
	movlw	.2
	movwf	PRODL
	call	gaslist_strcat_gas_mod		;Append gas description of gas #PRODL (0-4) to current string
	STRCAT_PRINT ""
	;Gas 4
	WIN_SMALL surf_gaslist_column,surf_gaslist_row+(surf_gaslist_spacing*.3)
	movlw	.3
	movwf	PRODL
	call	gaslist_strcat_gas_mod		;Append gas description of gas #PRODL (0-4) to current string
	STRCAT_PRINT ""
	;Gas 5
	WIN_SMALL surf_gaslist_column,surf_gaslist_row+(surf_gaslist_spacing*.4)
	movlw	.4
	movwf	PRODL
	call	gaslist_strcat_gas_mod		;Append gas description of gas #PRODL (0-4) to current string
	STRCAT_PRINT ""
	bcf		leftbind
	return

	global	TFT_dillist_surfmode
TFT_dillist_surfmode:					; Displays Diluent List
	bsf		short_gas_decriptions		; =1: Use short versions of gaslist_strcat_gas_mod and gaslist_strcat_setpoint
	bsf		ccr_diluent_setup			; Use CCR Diluents...
	rcall	TFT_gaslist_surfmode		; Use OC/BAIL routine
	bcf		ccr_diluent_setup			; Clear flag
	return

;==================================================================

	global	TFT_depth
TFT_depth:
	bcf		FLAG_TFT_depth
	SAFE_2BYTE_COPY rel_pressure, lo
	call	adjust_depth_with_salinity	; computes salinity setting into lo:hi [mbar]
	call	TFT_color_code_depth		; Color-code the output
	rcall	TFT_depth_blink
	WIN_LARGE dm_depth_column, dm_depth_row

	TSTOSS	opt_units					; 0=m, 1=ft
	bra		TFT_depth_metric
;TFT_depth_imperial
	clrf	sub_a+1						; Display 0ft if lower then 30cm
	movlw	d'30'
	movwf	sub_a+0
	movff	hi,sub_b+1
	movff	lo,sub_b+0
	call	subU16						; sub_c = sub_a - sub_b
	btfss	neg_flag					; Depth lower then 0.4m?
	bra		depth_less_0.3mtr_feet		; Yes, Show 0ft manually

	call	convert_mbar_to_feet		; convert value in lo:hi from mbar to feet
	bsf		leftbind
	output_16							; feet in Big font
	bcf		leftbind
	movlw	.3							; limit to three chars
	call	TFT_fillup_with_spaces		; Fillup FSR2 with spaces (Total string length in #WREG)
	STRCAT_PRINT ""						; Display feet
	bcf		win_invert					; Reset invert flag
	return

depth_less_0.3mtr_feet:
	STRCAT_PRINT "0  "					; manual zero
	bcf		win_invert					; Reset invert flag
	return

TFT_depth_metric:
	movlw	.039
	cpfslt	hi
	bra		depth_greater_99_84mtr

	btfsc	depth_greater_100m			; Was depth>100m during last call
	rcall	TFT_clear_depth				; Yes, clear depth area
	bcf		depth_greater_100m			; Do this once only...

	movlw	.039
	cpfslt	hi
	bra		depth_greater_99_84mtr

	movlw	HIGH	d'1000'
	movwf	sub_a+1
	movlw	LOW		d'1000'
	movwf	sub_a+0
	movff	hi,sub_b+1
	movff	lo,sub_b+0
	incf	sub_b+0,F
	movlw	d'0'
	addwfc	sub_b+1,F				; Add 1mbar offset
	call	sub16					; sub_c = sub_a - sub_b
	movlw	' '
	btfss	neg_flag				; Depth lower then 10m?
	movwf	POSTINC2				; Yes, add extra space

	clrf	sub_a+1
	movlw	d'99'
	movwf	sub_a+0
	movff	hi,sub_b+1
	movff	lo,sub_b+0
	call	subU16					; sub_c = sub_a - sub_b
	btfss	neg_flag				; Depth lower then 1m?
	bra		tft_depth2				; Yes, display manual Zero

	bsf		leftbind
	bsf		ignore_digit4
	output_16						; Full meters in Big font
	bcf		leftbind
	bra		tft_depth3

tft_depth2:
	STRCAT	"0"						; manual zero

tft_depth3:
	STRCAT_PRINT ""					; Display full meters

	; .1m in MEDIUM font
	WIN_MEDIUM	dm_depth_dm_column, dm_depth_dm_row

	; TODO - check if needed, depth should still be in hi:lo
	SAFE_2BYTE_COPY rel_pressure, lo
	call	adjust_depth_with_salinity	; computes salinity setting into lo:hi [mbar]
	call	TFT_color_code_depth	; Color-code the output

	PUTC	"."
	movlw	HIGH d'30'				; Display 0.0m if lower then 30cm
	movwf	sub_a+1
	movlw	LOW  d'30'
	movwf	sub_a+0
	movff	hi,sub_b+1
	movff	lo,sub_b+0
	call	subU16					; sub_c = sub_a - sub_b
	btfss	neg_flag				; Depth lower then 0.3m?
	bra		depth_less_0.3mtr		; Yes, Show ".0" manually

	movlw	d'4'
	movwf	ignore_digits
	bsf		ignore_digit5
	output_16dp	d'0'
	STRCAT_PRINT ""					; Display decimeters
	bcf		win_invert				; Reset invert flag
	WIN_FONT FT_SMALL
	return

depth_less_0.3mtr:
	STRCAT_PRINT "0"				; Display 0.0m manually
	bcf		win_invert				; Reset invert flag
	WIN_FONT FT_SMALL
	return

depth_greater_99_84mtr:				; Display only in full meters
	btfss	depth_greater_100m		; Is depth>100m already?
	rcall	TFT_clear_depth			; No, clear depth area and set flag
	call	TFT_color_code_depth
	; Depth is already in hi:lo
	; Show depth in Full meters
	; That means ignore digit 4 and 5
	lfsr	FSR2,buffer
	bsf		ignore_digit4
	bsf		leftbind
	output_16
	bcf		leftbind
	STRCAT_PRINT ""					; Display full meters only
	bcf		win_invert				; Reset invert flag
	WIN_FONT FT_SMALL
	return

TFT_clear_depth:					; No, clear depth area and set flag
	WIN_BOX_BLACK dm_depth_row, dm_depth_bot, dm_depth_column, dm_depth_rgt	;top, bottom, left, right
	bsf		depth_greater_100m		; Set Flag
	return

TFT_depth_blink:
	TSTOSS	opt_modwarning			; 0=standard, 1=blink
	return

	; check if previous cycle had the blinking warning or not
	btfsc	blinking_depth_prev		; did we have warning prev?
	bra		TFT_depth_blink_prevwarn; Yes

	; No; check if it's set now
	btfsc	blinking_depth_warning	; do we have warning set now?
	bra		TFT_depth_blink_warn	; Yes  - so we have warning now but not prev

	; no warning in previous cycle, no warning now, reset all flags
	bcf		blinking_depth_prev		; reset prev flag
	bcf		blinking_depth_toggle	; reset toggle
	bcf		win_invert
	; all done
	return

TFT_depth_blink_prevwarn:
	; ...we had warning in previous cycle, check if we still have the warning set
	btfss	blinking_depth_warning			; do we still have the warning?
	bra		TFT_depth_blink_prevwarn_nowarn	; No, clear the depth area

	; we still have the warning, set previous flag for next cycle...
	bsf		blinking_depth_prev				; set prev flag
	; and set toggle and invert if required
	btfss	blinking_depth_toggle			; do we have the toggle set?
	bra		TFT_depth_blink_set				; No:  set inverse,	do color_box, set flag
	bra		TFT_depth_blink_reset			; Yes: clear inverse, do black box, reset flag

TFT_depth_blink_prevwarn_nowarn:
	; we had warning, but not now... (e.g. ascended or switched to better gas)
	; reset the previous cycle flag for the next cycle...
	bcf		blinking_depth_prev				; reset prev flag
	; clear it - just in case if we had a blinked before
	bra		TFT_depth_blink_reset			; Yes: clear inverse, do black box, reset flag

TFT_depth_blink_warn:
	; new blinking warning activated (had no warning in previous cycle)
	bsf		blinking_depth_prev				; set prev flag
	; set toggle and invert
	bra		TFT_depth_blink_set

TFT_depth_blink_set:
	; clear the area with color
	movlw	color_red						; that should not be hardcoded...
	WIN_BOX_COLOR dm_depth_row, dm_depth_bot, dm_depth_column, dm_depth_rgt	;top, bottom, left, right
	;set the invert color
	bsf		win_invert
	; set the toggle
	bsf		blinking_depth_toggle
	; all done
	return

TFT_depth_blink_reset:
	; clear the area with black
	WIN_BOX_BLACK dm_depth_row, dm_depth_bot, dm_depth_column, dm_depth_rgt	;top, bottom, left, right
	;reset the invert color
	bcf		win_invert
	; reset the toggle
	bcf		blinking_depth_toggle
	; if it's still warning...
	btfsc	blinking_depth_warning
	call	TFT_warnings_color
	; all done
	return

;=============================================================================

	global	TFT_custom_text
TFT_custom_text:					; Show the custom text
	lfsr	FSR0, opt_name			; Source
	WIN_SMALL surf_customtext_column,surf_customtext_row1 ; First row
	rcall	TFT_custom_text_2		; Show up to 12 chars and print
	incfsz	lo,F					; Was lo=255?
	return							; No, all done.
	lfsr	FSR0, opt_name+.12		; Source
	WIN_SMALL surf_customtext_column,surf_customtext_row2 ; Second row
	rcall	TFT_custom_text_2		; Show up to 12 chars and print
	incfsz	lo,F					; Was lo=255?
	return							; No, all done.
	lfsr	FSR0, opt_name+.24		; Source
	WIN_SMALL surf_customtext_column,surf_customtext_row3 ; Third row
	rcall	TFT_custom_text_2		; Show up to 12 chars and print
	incfsz	lo,F					; Was lo=255?
	return							; No, all done.
	lfsr	FSR0, opt_name+.36		; Source
	WIN_SMALL surf_customtext_column,surf_customtext_row4 ; Forth row
	rcall	TFT_custom_text_2		; Show up to 12 chars and print
	incfsz	lo,F					; Was lo=255?
	return							; No, all done.
	lfsr	FSR0, opt_name+.48		; Source
	WIN_SMALL surf_customtext_column,surf_customtext_row5 ; Fifth row
	bra		TFT_custom_text_2		; Show up to 12 chars and print ; and return...


TFT_custom_text_2:
	lfsr	FSR2, buffer			; destination
	movlw	.12
	movwf	lo						; length/line
TFT_custom_text_3:
	movf	POSTINC0,W				; Get byte
	bz		TFT_custom_text_4		; End if NULL
	movwf	POSTINC2				; NO: copy
	decfsz	lo,F					; Max length reached ?
	bra		TFT_custom_text_3		; NO: loop
	setf	lo						; lo=255 -> more to come
TFT_custom_text_4:
	clrf	POSTINC2				; Mark end of string
	goto	aa_wordprocessor		; print and return


;=============================================================================

	global	TFT_update_surf_press
TFT_update_surf_press:
	WIN_SMALL	surf_press_column,surf_press_row
	call	TFT_standard_color
	SAFE_2BYTE_COPY amb_pressure, lo
	movff	lo,sub_a+0
	movff	hi,sub_a+1
	movff	last_surfpressure_30min+0,sub_b+0
	movff	last_surfpressure_30min+1,sub_b+1
	call	subU16								; sub_c = sub_a - sub_b
	btfsc	neg_flag							; Pressure lower?
	rcall	update_surf_press2					; Yes, test threshold
	tstfsz	sub_c+1								; >255mbar difference?
	bra		update_surf_press_common			; Yes, display!
	movlw	d'11'								; 10mbar noise suppression
	subwf	sub_c+0,W
	btfsc	STATUS,C
	bra		update_surf_press_common			; Yes, display!
	SAFE_2BYTE_COPY last_surfpressure_30min, lo	; Overwrite with stable value...
update_surf_press_common:
	movff	lo,int_I_pres_surface+0				; copy displayed value to C code to have pressure displayed
	movff	hi,int_I_pres_surface+1				; and pressure used for desaturation & no-fly time in sync
	output_16
	; Show only 4 digits
	movff	buffer+1,buffer+0
	movff	buffer+2,buffer+1
	movff	buffer+3,buffer+2
	movff	buffer+4,buffer+3
	movlw	0x00
	movff	WREG,buffer+4
	STRCAT_PRINT ""
	call	TFT_divemask_color
	WIN_SMALL	surf_press_column+4*8,surf_press_row
	STRCPY_TEXT_PRINT tMBAR						; mbar
	return

update_surf_press2:
	movff	lo,sub_b+0
	movff	hi,sub_b+1
	movff	last_surfpressure_30min+0,sub_a+0
	movff	last_surfpressure_30min+1,sub_a+1
	goto	subU16								; sub_c = sub_a - sub_b	; and return...

;=============================================================================

	global	TFT_update_batt_voltage
TFT_update_batt_voltage:
	movff	batt_percent,lo			; Get battery percent
	call	TFT_color_code_battery	; Color-code battery percent
	; Setup charge indicator
	btfsc	cc_active
	bsf		win_invert
	btfsc	cc_active
	movlw	color_yellow
	btfsc	cv_active
	movlw	color_green
	btfsc	cc_active
	call	TFT_set_color
	WIN_TINY batt_percent_column,batt_percent_row
	bsf		leftbind
	output_8
	bcf		leftbind
	STRCAT	"% "
	movlw	0x00
	movff	WREG,buffer+4			; Only "xxx%"
	STRCAT_PRINT ""
	bcf		win_invert
	call	TFT_standard_color
	WIN_TINY batt_voltage_column,batt_voltage_row
	movff	battery_type,lo			; =0:1.5V, =1:3,6V Saft, =2:LiIon 3,7V/0.8Ah, =3:LiIon 3,7V/3.1Ah, =4: LiIon 3,7V/2.3Ah
	PUTC	"T"
	bsf		leftbind
	output_8
	PUTC	":"
	movff	batt_voltage+0,lo
	movff	batt_voltage+1,hi
	output_16dp .2
	bcf		leftbind
	PUTC	'V'
	movff	buffer+8,buffer+6
	movlw	0x00
	movff	WREG,buffer+7			; Only "x.yV"
	STRCAT_PRINT ""
	return

;update_battery_debug:
;	call	TFT_standard_color
;	WIN_TINY .70,.0
;	movff	battery_gauge+5,xC+3
;	movff	battery_gauge+4,xC+2
;	movff	battery_gauge+3,xC+1
;	movff	battery_gauge+2,xC+0
;	; battery_gauge:6 is nAs
;	; devide through 65536
;	; devide through 152
;	; Result is 0.01Ah in xC+1:xC+0
;	movlw	LOW		.152
;	movwf	xB+0
;	movlw	HIGH	.152
;	movwf	xB+1
;	call	div32x16		; xC:4 / xB:2 = xC+3:xC+2 with xC+1:xC+0 as remainder
;	bsf		leftbind
;	movff	xC+0,lo
;	movff	xC+1,hi
;	output_16
;	STRCAT_PRINT	"x.01Ah"
;	WIN_FONT	FT_SMALL
;	bcf		leftbind
;	return

;=============================================================================

	global	TFT_convert_signed_16bit
TFT_convert_signed_16bit:
	bcf		neg_flag				; Positive temperature
	btfss	hi,7					; Negative temperature ?
	return							; No, return
; Yes, negative temperature!
	bsf		neg_flag				; Negative temperature
	PUTC	'-'						; Display "-"
	comf	hi						; Then, 16bit sign changes.
	negf	lo
	btfsc	STATUS,C
	incf	hi
	return							; and return

;=============================================================================

	global	TFT_convert_date
TFT_convert_date:						; converts into "DD/MM/YY" or "MM/DD/YY" or "YY/MM/DD" in postinc2
	movff	opt_dateformat,WREG			; =0:MMDDYY, =1:DDMMYY, =2:YYMMDD
	movwf	EEDATA						; used as temp here
	tstfsz	EEDATA
	bra		TFT_convert_date_1			; opt_dateformat is 1 or 2
	; opt_dateformat is 0
	; use MMDDYY
	movff	lo,lo_temp					; incoming: lo = day,   hi = month
	movff	hi,lo						; swap
	movff	lo_temp,hi					; now:      lo = month, hi = day
	bra		TFT_convert_date_common

TFT_convert_date_1:
	decfsz	EEDATA,F
	bra		TFT_convert_date_2			; opt_dateformat is 2
	; opt_dateformat is 1
	; use DDMMYY
TFT_convert_date_common:
	bsf		leftbind
	output_99x							; with lo = month or day   or year
	PUTC	'.'
	movff	hi,lo						; now  lo = day   or month or month
	output_99x
	PUTC	'.'
	movff	up,lo						; now  lo = year  or year  or day
	output_99x
	bcf		leftbind
	return

TFT_convert_date_2:
	; opt_dateformat is 2
	; use YYMMDD
	movff	lo,lo_temp					; incoming: lo = day,  up = year
	movff	up,lo						; swap
	movff	lo_temp,up					; now     : lo = year, up = day
	bra		TFT_convert_date_common

;=============================================================================

	global	TFT_convert_date_short
TFT_convert_date_short:					; converts into "DD/MM" or "MM/DD" or "MM/DD" in postinc2
	movff	opt_dateformat,WREG			; =0:MMDDYY, =1:DDMMYY, =2:YYMMDD
	movwf	EEDATA						; used as temp here
	tstfsz	EEDATA
	bra		TFT_convert_date_short_1
	; opt_dateformat is 0
	; Use MMDD(YY)
TFT_convert_date_short_0:
	movff	lo,lo_temp					; incoming: lo = day,   hi = month
	movff	hi,lo						; swap
	movff	lo_temp,hi					; now:      lo = month, hi = day
	bra		TFT_convert_date_short_common

TFT_convert_date_short_1:
	decfsz	EEDATA,F
	bra		TFT_convert_date_short_0	; opt_dateformat is 2 -> use (YY)MMDD
	; opt_dateformat is 1
	; use DDMM(YY)
TFT_convert_date_short_common:
	bsf		leftbind
	output_99x							; with lo = month or day
	PUTC	'.'
	movff	hi,lo						; now  lo = day   or month
	output_99x
	bcf		leftbind
	return

;=============================================================================

	global	TFT_date
TFT_date:
	WIN_SMALL	surf_date_column,surf_date_row	; Init new Wordprocessor
	call	TFT_standard_color
	movff	day,lo
	movff	month,hi
	movff	year,up
	call	TFT_convert_date					; converts into "DD/MM/YY" or "MM/DD/YY" or "YY/MM/DD" in postinc2	
	STRCAT_PRINT ""
	return

;=============================================================================

	global	TFT_max_depth_alternative
TFT_max_depth_alternative:
	bcf		FLAG_TFT_max_depth_alt
	; The "mask"
	call	TFT_divemask_color
	WIN_TINY dm_mask_depth_column, dm_max_alt_row-.14
	STRCPY_TEXT_PRINT tMaxDepth

	; The max. depth
	SAFE_2BYTE_COPY max_pressure, lo
	call	adjust_depth_with_salinity	; computes salinity setting into lo:hi [mbar]
	call	TFT_standard_color
	TSTOSS	opt_units					; 0=m, 1=ft
	bra		TFT_max_depth_alt_metric
;TFT_max_depth_alt_imperial:
TFT_max_depth_alt_metric:
	WIN_LARGE dm_max_alt_column,dm_max_alt_row
	bsf		ignore_digit4				; no 0.1m
	output_16
	STRCAT_PRINT ""

	WIN_MEDIUM	dm_max_dm_alt_column,dm_max_alt_row+.25
	SAFE_2BYTE_COPY max_pressure, lo
	call	adjust_depth_with_salinity	; computes salinity setting into lo:hi [mbar]
	PUTC	"."
	movlw	d'4'
	movwf	ignore_digits
	bsf		ignore_digit5
	bsf		leftbind
	output_16dp	d'0'
	STRCAT_PRINT ""						; Display decimeters
	bcf		leftbind
	return


	global	TFT_max_depth
TFT_max_depth:
	bcf	FLAG_TFT_max_depth
	btfsc	FLAG_apnoe_mode				; different display in apnoe mode
	bra		TFT_max_depth_apnoe
TFT_max_depth2:
	SAFE_2BYTE_COPY max_pressure, lo
TFT_max_depth3:
	call	adjust_depth_with_salinity	; computes salinity setting into lo:hi [mbar]
	TSTOSS	opt_units					; 0=m, 1=ft
	bra		TFT_max_depth2_metric
;TFT_max_depth2_imperial:
	call	convert_mbar_to_feet		; convert value in lo:hi from mbar to feet
	WIN_MEDIUM	dm_max_depth_column, dm_max_depth_row
	TSTOSS	opt_vsigraph				; 0=skip, 1=draw
	WIN_MEDIUM	dm_max_depth_column_nvsi, dm_max_depth_row
	call	TFT_standard_color
	output_16_3
	STRCAT_PRINT ""
	return

TFT_max_depth2_metric:
	WIN_MEDIUM dm_max_depth_column, dm_max_depth_row
	TSTOSS	opt_vsigraph				; 0=skip, 1=draw
	WIN_MEDIUM dm_max_depth_column_nvsi, dm_max_depth_row
	call	TFT_standard_color

	movlw	.039
	cpfslt	hi
	bra		max_depth_greater_99_84mtr

	btfsc	max_depth_greater_100m		; Was depth>100m during last call
	rcall	TFT_clear_max_depth			; Yes, clear depth area
	bcf		max_depth_greater_100m		; Do this once only...

	movlw	.039
	cpfslt	hi
	bra		max_depth_greater_99_84mtr

	movlw	HIGH	d'1000'
	movwf	sub_a+1
	movlw	LOW		d'1000'
	movwf	sub_a+0
	movff	hi,sub_b+1
	movff	lo,sub_b+0
	incf	sub_b+0,F
	movlw	d'0'
	addwfc	sub_b+1,F				; Add 1mbar offset
	call	sub16					; sub_c = sub_a - sub_b
	movlw	' '
	btfss	neg_flag				; Depth lower then 10m?
	movwf	POSTINC2				; Yes, add extra space

	clrf	sub_a+1
	movlw	d'99'
	movwf	sub_a+0
	movff	hi,sub_b+1
	movff	lo,sub_b+0
	call	subU16					; sub_c = sub_a - sub_b
	btfss	neg_flag				; Depth lower then 1m?
	bra		tft_max_depth2			; Yes, display manual Zero

	bsf		ignore_digit4			; no 0.1m
	bsf		leftbind
	output_16
	bra		tft_max_depth3

tft_max_depth2:
	WIN_MEDIUM dm_max_depth_column, dm_max_depth_row
	TSTOSS	opt_vsigraph			; 0=skip, 1=draw
	WIN_MEDIUM dm_max_depth_column_nvsi, dm_max_depth_row
	STRCAT	"0"

tft_max_depth3:
	call	TFT_standard_color
	STRCAT_PRINT ""					; Display full meters
	bcf	 leftbind

	; .1m in SMALL font
	WIN_SMALL	dm_max_depth_dm_column, dm_max_depth_dm_row
	TSTOSS	opt_vsigraph			; 0=skip, 1=draw
	WIN_SMALL	dm_max_depth_dm_column_nvsi, dm_max_depth_dm_row

	SAFE_2BYTE_COPY max_pressure, lo
	call	adjust_depth_with_salinity	; computes salinity setting into lo:hi [mbar]

	PUTC	"."

	movlw	d'4'
	movwf	ignore_digits
	bsf		ignore_digit5
	bsf		leftbind
	output_16dp	d'0'
	STRCAT_PRINT ""						; Display decimeters
	bcf		leftbind
	return

max_depth_greater_99_84mtr:				; Display only in full meters
	btfss	max_depth_greater_100m		; Is max depth>100m already?
	rcall	TFT_clear_max_depth			; No, clear max depth area and set flag
	; Max. Depth is already in hi:lo
	; Show max. depth in Full meters
	; That means ignore figure 4 and 5
	lfsr	FSR2,buffer
	bsf		ignore_digit4
	bsf		leftbind
	output_16
	bcf		leftbind
	STRCAT_PRINT ""						; Display full meters only
	WIN_FONT FT_SMALL
	return

TFT_clear_max_depth:					; No, clear max. depth area and set flag
	WIN_BOX_BLACK	dm_max_depth_row, dm_max_depth_bot, dm_max_depth_column, dm_max_depth_rgt	;top, bottom, left, right
	bsf		max_depth_greater_100m		; Set Flag
	return


TFT_max_depth_apnoe:
	btfss	FLAG_active_descent			; Are we descending?
	bra		TFT_max_depth2				; Yes, show normal max.
	SAFE_2BYTE_COPY apnoe_max_pressure, lo
	bra		TFT_max_depth3				; Show apnoe_max_pressure as max. depth

	global	TFT_display_apnoe_last_max
TFT_display_apnoe_last_max:
	call	TFT_divemask_color
	WIN_TINY dm_apnoe_last_max_depth_text_col, dm_apnoe_last_max_depth_text_row
	STRCPY_TEXT_PRINT	tApnoeMax

	call	TFT_standard_color
	SAFE_2BYTE_COPY max_pressure, lo
	call	adjust_depth_with_salinity	; computes salinity setting into lo:hi [mbar]
	TSTOSS	opt_units					; 0=m, 1=ft
	bra		TFT_display_apnoe_last_m_metric
;TFT_display_apnoe_last_max_imperial
	call	convert_mbar_to_feet		; convert value in lo:hi from mbar to feet
	WIN_MEDIUM	dm_apnoe_last_max_depth_column, dm_apnoe_last_max_depth_row
	output_16
	STRCAT_PRINT ""
	return

TFT_display_apnoe_last_m_metric:
	WIN_MEDIUM dm_apnoe_last_max_depth_column, dm_apnoe_last_max_depth_row
	bsf		ignore_digit5				; do not display 1cm depth
	output_16dp d'3'
	STRCAT_PRINT ""
	return

;=============================================================================

	global	TFT_divemins
TFT_divemins:
	bcf	FLAG_TFT_divemins			; Clear flag
	movff	divemins+0,lo
	movff	divemins+1,hi

	; Already showing divemins > 99min
	btfsc	no_more_divesecs		; Ignore seconds?
	bra		TFT_divemins2			; Show minutes only

	tstfsz	hi						; hi = 0?
	bra	TFT_divemins_clr			; No, show mins only

	movlw	.99
	cpfsgt	lo						; bigger than 99?
	bra		TFT_divemins1			; No show mins:secs

TFT_divemins_clr:
	; Yes, remove second display for the rest of the dive and clear seconds
	bsf		no_more_divesecs		; Set flag
	; Clear rest of seconds
	WIN_BOX_BLACK dm_divetime_row, dm_divetime_bot, dm_divetime_column, dm_divetime_rgt ;top, bottom, left, right
	bra		TFT_divemins2			; Show minutes only

TFT_divemins1:
	; Print out the minutes, up to 99min, only 2chars !
	call	TFT_standard_color
	WIN_MEDIUM dm_divetime_column, dm_divetime_row
	output_99						; displays only last two figures from a 8Bit value (0-99)
	STRCAT_PRINT ""					; Show minutes in large font

	; Print out the seconds
	WIN_SMALL dm_divetime_secs_column, dm_divetime_secs_row			; left position for two sec figures
	PUTC	':'
	bsf	leftbind
	movff	divesecs,lo
	output_99x						; displays only last two figures from a 8Bit value with leading zero (00-99) 
	bcf	 leftbind
	STRCAT_PRINT ""					; Show seconds in small font
	return

TFT_divemins2:
	; Full minutes only
	call	TFT_standard_color
	WIN_MEDIUM	dm_divetime_minsonly_column, dm_divetime_row
	bcf		leftbind
	output_16_4
	STRCAT_PRINT ""					; Show minutes in large font
	return

	global	TFT_divemins_alternative
TFT_divemins_alternative:
	bcf		FLAG_TFT_divemins		; Clear flag
	call	TFT_standard_color
	; Print out the minutes (0-999) in large
	WIN_LARGE dm_divetime_alt_column, dm_divetime_alt_row
	movff	divemins+0,lo
	movff	divemins+1,hi
	output_16_3						; limit to 999 and display only (0-999)
	STRCAT_PRINT ""					; Show minutes
	; Print out the seconds in medium
	WIN_MEDIUM	dm_divetime_alt_column+.60, dm_divetime_alt_row+.25
	PUTC	":"
	bsf		leftbind
	movff	divesecs,lo
	output_99x						; displays only last two figures from a 8Bit value with leading zero (00-99) 
	bcf		leftbind
	STRCAT_PRINT ""					; Show seconds in small font
	return

;=============================================================================

	global	TFT_display_apnoe_surface
TFT_display_apnoe_surface:
	call	TFT_divemask_color
	WIN_TINY dm_apnoe_surface_time_text_col, dm_apnoe_surface_time_text_row
	STRCPY_TEXT_PRINT tApnoeSurface

	call	TFT_standard_color
	WIN_MEDIUM dm_apnoe_surface_time_column, dm_apnoe_surface_time_row
	movff	apnoe_surface_mins,lo
	output_8
	PUTC	':'
	movff	apnoe_surface_secs,lo
	output_99x
	STRCAT_PRINT ""
	return

	global	TFT_apnoe_clear_surface
TFT_apnoe_clear_surface:
	; Clear Surface timer....
	WIN_BOX_BLACK dm_apnoe_surface_time_text_row, .239, dm_apnoe_surface_time_text_col, .159	;top, bottom, left, right
	return

	global	TFT_display_apnoe_descent
TFT_display_apnoe_descent:			; Descent divetime
	movff	apnoe_mins,lo
	clrf	hi
	WIN_MEDIUM	dm_divetime_apnoe_column, dm_divetime_apnoe_row
	output_16_3						; displays only last three figures from a 16Bit value (0-999)
	call	TFT_standard_color
	STRCAT_PRINT ""					; Show minutes in large font
	WIN_SMALL	dm_divetime_apnoe_secs_column, dm_divetime_apnoe_secs_row	; left position for two sec figures
	PUTC	':'
	bsf		leftbind
	movff	apnoe_secs,lo
	output_99x
	bcf		leftbind
	STRCAT_PRINT ""					; Show seconds in small font

	call	TFT_divemask_color
	WIN_TINY dm_total_apnoe_text_column,dm_total_apnoe_text_row
	STRCPY_TEXT_PRINT tApnoeTotal
	call	TFT_standard_color
	movff	divemins,lo
	clrf	hi
	WIN_MEDIUM dm_apnoe_total_divetime_column, dm_apnoe_total_divetime_row
	output_16_3						; displays only last three figures from a 16Bit value (0-999)
	call	TFT_standard_color
	STRCAT_PRINT ""					; Show minutes in large font
	WIN_SMALL	dm_apnoe_total_divetime_secs_col, dm_apnoe_total_divetime_secs_row	; left position for two sec figures
	PUTC	':'
	bsf		leftbind
	movff	divesecs,lo
	output_99x
	bcf		leftbind
	STRCAT_PRINT ""					; Show seconds in small font
	return

;=============================================================================
; Writes ostc #Serial and Firmware version in splash screen

	global	TFT_serial
TFT_serial:		
	WIN_TINY	.5,.225
	STRCPY	"OSTC"					; Won't translate that...

	movlw	0x0A
	cpfseq	hardware_flag
	bra		TFT_serial2
	STRCAT	"3 #"
	bra		TFT_serial_common
TFT_serial2:
	movlw	0x05
	cpfseq	hardware_flag
	bra		TFT_serial3
	STRCAT	" cR #"
	bra	 TFT_serial_common
TFT_serial3:
	movlw	0x11
	cpfseq	hardware_flag
	bra		TFT_serial4
	STRCAT	"2 #"
	bra		TFT_serial_common
TFT_serial4:
	movlw	0x1A
	cpfseq	hardware_flag
	bra		TFT_serial5
	STRCAT	"3 #"
;	bra		TFT_serial_common
TFT_serial5:
TFT_serial_common:
	rcall	TFT_cat_serial
	STRCAT	" v"
	WIN_COLOR color_greenish
	rcall	TFT_cat_firmware

	ifdef __DEBUG
		movlw	color_grey				; Write header in blue when
		call	TFT_set_color			; compiled in DEBUG mode...
		STRCAT_PRINT "DEBUG"
	else
		STRCAT_PRINT ""
		bcf		win_invert				; Reset invert flag
		call	TFT_standard_color

		movlw	softwareversion_beta	; =1: Beta, =0: Release
		decfsz	WREG,F
		return							; Release version -> Return

		call	TFT_warnings_color
		WIN_LEFT .160-4*9/2				; Right pad.
		STRCPY_TEXT_PRINT tBeta
	endif
	call	TFT_standard_color
	bcf		win_invert
	return


;=============================================================================
; For the Information menu: append firmware x.yy version.

	global	info_menu_firmware
	extern	tFirmware
info_menu_firmware:
	lfsr	FSR1,tFirmware
	call	strcat_text
	rcall	TFT_cat_firmware
	; Show language version
	IFNDEF		french_italian
	STRCAT	"_en+de"
	ELSE
	STRCAT	"_fr+it"
	ENDIF
	bcf		win_invert				; Reset invert flag
	return

	global	TFT_cat_firmware
TFT_cat_firmware:
	movlw	softwareversion_x
	movwf	lo
	bsf		leftbind
	output_8
	PUTC	'.'
	movlw	softwareversion_y
	movwf	lo
	output_99x
	bcf		leftbind
	; Check firmware date
	movlw	firmware_expire_year-.1
	cpfsgt	year					; > threshold?
	return
	movlw	firmware_expire_month-.1
	cpfsgt	month					; > threshold?
	return
	movlw	firmware_expire_day-.1
	cpfsgt	day					 ; > threshold?
	return

	; Show in "change firmware" style
	movlw	color_yellow
	bcf	win_invert
	goto	TFT_set_color	; and return...

;-----------------------------------------------------------------------------
; For the Information menu: append serial number 

	global	info_menu_serial
	extern	tSerial
info_menu_serial:
	lfsr	FSR1,tSerial
	call	strcat_text
	global	TFT_cat_serial
TFT_cat_serial:
	clrf	EEADRH
	clrf	EEADR					; Get Serial number LOW
	call	read_eeprom				; read byte
	movff	EEDATA,lo
	incf	EEADR,F					; Get Serial number HIGH
	call	read_eeprom				; read byte
	movff	EEDATA,hi

	bsf		leftbind
	output_16
	bcf		leftbind
	return

;-----------------------------------------------------------------------------
; For the Information menu: Append total dives

	global	info_menu_total_dives
	extern	tTotalDives
info_menu_total_dives:
	lfsr	FSR1,tTotalDives
	call	strcat_text
TFT_cat_total_dives:
	read_int_eeprom	.2
	movff	EEDATA,lo
	read_int_eeprom	.3
	movff	EEDATA,hi
	bsf		leftbind
	output_16
	bcf		leftbind
	return

; For the Information menu: Append battery voltage
	global	info_menu_battery_volts
	extern	tBatteryV
info_menu_battery_volts:
	lfsr	FSR1,tBatteryV
	call	strcat_text
	movff	batt_voltage+1,hi
	movff	batt_voltage+0,lo
	bsf		leftbind
	output_16dp .2				; x.xxx
	STRCAT	"V(T"
	movff	battery_type,lo		; =0:1.5V, =1:3,6V Saft, =2:LiIon 3,7V/0.8Ah, =3:LiIon 3,7V/3.1Ah, =4: LiIon 3,7V/2.3Ah
	output_8
	bcf		leftbind
	PUTC	")"
	return

	; For the Information menu: Append Uptime
	global	info_menu_uptime
	extern	tUptime
info_menu_uptime:
	lfsr	FSR1,tUptime
	call	strcat_text
	movff	uptime+0,xC+0
	movff	uptime+1,xC+1
	movff	uptime+2,xC+2
	movff	uptime+3,xC+3
	movlw	LOW		.3600
	movwf	xB+0
	movlw	HIGH	.3600
	movwf	xB+1			; One day = 3600s
	call	div32x16		; xC:4 / xB:2 = xC+3:xC+2 with xC+1:xC+0 as remainder
	;xC+0:xC+1 -> Full hours
	movff	xC+1,xA+1
	movff	xC+0,xA+0
	clrf	xB+1
	movlw	.24
	movwf	xB+0
	call	div16x16		; xA/xB=xC with xA+0 as remainder
	movff	xC+0,lo
	movff	xC+1,hi			; Full days
	bsf		leftbind
	output_16
	PUTC	"d"
	movff	xA+0,lo			; Full hours
	output_8
	PUTC	"h"
	bcf		leftbind
	return					; Done.
	
	extern	tCalX,tCalY,tCalZ
	global	menu_cal_x
menu_cal_x:
	lfsr	FSR1,tCalX
	call	strcat_text
	movff	compass_CX_f+0,lo
	movff	compass_CX_f+1,hi
	call	TFT_convert_signed_16bit	; converts lo:hi into signed-short and adds '-' to POSTINC2 if required
	bsf		leftbind
	output_16
	bcf		leftbind
	return

	global	menu_cal_y
menu_cal_y:
	lfsr	FSR1,tCalY
	call	strcat_text
	movff	compass_CY_f+0,lo
	movff	compass_CY_f+1,hi
	call	TFT_convert_signed_16bit	; converts lo:hi into signed-short and adds '-' to POSTINC2 if required
	bsf		leftbind
	output_16
	bcf		leftbind
	return
	
	global	menu_cal_z
menu_cal_z:
	lfsr	FSR1,tCalZ
	call	strcat_text
	movff	compass_CZ_f+0,lo
	movff	compass_CZ_f+1,hi
	call	TFT_convert_signed_16bit	; converts lo:hi into signed-short and adds '-' to POSTINC2 if required
	bsf		leftbind
	output_16
	bcf		leftbind
	return


;-----------------------------------------------------------------------------
; ppO2 menu

	global	divesets_ppo2_min
	extern	tPPO2MIN
divesets_ppo2_min:
	lfsr	FSR1,tPPO2MIN
	call	strcat_text
	movff	char_I_ppO2_min,lo
	movlw	ppo2_warning_low_default
	bra		divesets_ppo2_common

	global	divesets_ppo2_min_cc
	extern	tPPO2MINCC
divesets_ppo2_min_cc:
	lfsr	FSR1,tPPO2MINCC
	call	strcat_text
	movff	char_I_ppO2_min_loop,lo
	movlw	ppo2_warning_loop_default
	bra		divesets_ppo2_common

	global	divesets_ppo2_max
	extern	tPPO2Max
	extern	tbar
divesets_ppo2_max:
	lfsr	FSR1,tPPO2Max
	call	strcat_text
	movff	char_I_ppO2_max,lo
	movlw	ppo2_warning_high_default
	bra		divesets_ppo2_common

	global	divesets_ppo2_max_deco
	extern	tPPO2DECO
divesets_ppo2_max_deco:
	lfsr	FSR1,tPPO2DECO
	call	strcat_text
	movff	char_I_ppO2_max_deco,lo
	movlw	ppo2_warning_deco_default
	;bra	divesets_ppo2_common

divesets_ppo2_common:
	movwf	up						; Save default value
	clrf	hi
	bsf		leftbind
	output_16dp d'3'
	bcf		leftbind
	lfsr	FSR1,tbar
	call	strcat_text
	movf	up,W					; Default value
	cpfseq	lo						; Current value
	bra		divesets_ppo2_common2	; Not default, add *
	return							; Default, Done.
divesets_ppo2_common2:
	PUTC	"*"
	return							; Done.

;=============================================================================

	global	TFT_clear_warning_text
TFT_clear_warning_text:
	btfss	divemode							; in divemode?
	bra		TFT_clear_warning_text2				; No, setup for surface mode
	bcf		FLAG_TFT_dive_warning_text_clear	; Clear flag
	btfsc	alternative_divelayout
	bra		TFT_clear_warning_text_2nd_row		; In Alt mode, clear only row 2
	WIN_BOX_BLACK dm_warning_row, dm_warning_bot, dm_warning_column, dm_warning_rgt		; top, bottom, left, right
	return
TFT_clear_warning_text2:
	WIN_BOX_BLACK surf_warning1_row, surf_warning2_row+.24, surf_warning1_column, surf_warning1_column+.76	; top, bottom, left, right
	return

	global	TFT_clear_warning_text_2nd_row
TFT_clear_warning_text_2nd_row:
	btfss	divemode							; in divemode?
	bra		TFT_clear_warning_text_2nd_2		; No, setup for surface mode
	bcf		FLAG_TFT_dive_warning_text_clr2		; Clear flag
	WIN_BOX_BLACK dm_warning2_row, dm_warning2_bot, dm_warning2_column, dm_warning2_rgt	; top, bottom, left, right
	return
TFT_clear_warning_text_2nd_2:
	WIN_BOX_BLACK surf_warning2_row, surf_warning2_row+.24, surf_warning2_column, surf_warning2_column+.76	; top, bottom, left, right
	return

	global	TFT_fillup_with_spaces
TFT_fillup_with_spaces:					; Fillup FSR2 with spaces (Total string length in #WREG)
	movwf	lo							; save max. string length into lo
	movf	FSR2L,W						; Get current string length
	subwf	lo,F						; lo-WREG
	btfsc	STATUS,N					; longer then #lo already?
	return								; Yes, done.
	tstfsz	lo							; Zero?
	bra		TFT_fillup_with_spaces2		; No.
	return								; Yes, done.
TFT_fillup_with_spaces2:
	PUTC	" "							; Add one space
	decfsz	lo,F						; All done?
	bra		TFT_fillup_with_spaces2		; No, loop
	return								; Done.

;=============================================================================

	global	TFT_desaturation_time
TFT_desaturation_time:
	rcall	TFT_warning_set_window		; Sets the row and column for the current warning
	tstfsz	WREG						; Is there room for the warning?
	return								; No
	STRCPY	"Desat:"
	movff	int_O_desaturation_time+0,lo
	movff	int_O_desaturation_time+1,hi
	call	convert_time				; converts hi:lo in minutes to hours (hi) and minutes (lo)
	bsf		leftbind
	movf	lo,W
	movff	hi,lo
	movwf	hi							; exchange lo and hi...
	output_8							; Hours
	PUTC	':'
	movff	hi,lo						; Minutes
	output_99x
	bcf		leftbind
	movlw	surf_warning_length			; Only use surface string length
	rcall	TFT_fillup_with_spaces		; Fillup FSR2 with spaces (Total string length in #WREG)
	movlw	.0							; TODO - needed?
	movff	WREG,buffer+11				; TODO - needed?
	STRCAT_PRINT ""
	bcf		win_invert
	return


	global	TFT_nofly_time
TFT_nofly_time:
	rcall	TFT_warning_set_window		; Sets the row and column for the current warning
	tstfsz	WREG						; Is there room for the warning?
	return								; No
	movff	char_I_altitude_wait,WREG
	tstfsz	WREG
	bra		TFT_nofly_time_1
	STRCPY	"NoFly:"
	bra		TFT_nofly_time_2
TFT_nofly_time_1:
	STRCPY	"NoAlt:"
TFT_nofly_time_2:
	movff	int_O_nofly_time+0,lo
	movff	int_O_nofly_time+1,hi
	call	convert_time				; converts hi:lo in minutes to hours (hi) and minutes (lo)
	bsf		leftbind
	movf	lo,W
	movff	hi,lo
	movwf	hi							; exchange lo and hi...
	output_8							; Hours
	PUTC	':'
	movff	hi,lo						; Minutes
	output_99x
	bcf		leftbind
	movlw	surf_warning_length			; Only use surface string length
	rcall	TFT_fillup_with_spaces		; Fillup FSR2 with spaces (Total string length in #WREG)
	movlw	.0							; TODO - needed?
	movff	WREG,buffer+11				; TODO - needed?
	STRCAT_PRINT ""
	bcf		win_invert
	return

;=============================================================================

	global	TFT_warning_agf
TFT_warning_agf:
	rcall	TFT_warning_set_window		; Sets the row and column for the current warning
	tstfsz	WREG						; Is there room for the warning?
	return								; No
	call	TFT_attention_color
	STRCPY_TEXT tDiveaGF_active			; "aGF!"
	movlw	dm_warning_length			; Divemode string length
	rcall	TFT_fillup_with_spaces		; Fillup FSR2 with spaces (Total string length in #WREG)
	STRCAT_PRINT ""
	;bcf	 win_invert
	;return
	goto	TFT_standard_color

	global	TFT_warning_fallback
TFT_warning_fallback:					; Show fallback warning
	rcall	TFT_warning_set_window		; Sets the row and column for the current warning
	tstfsz	WREG						; Is there room for the warning?
	return								; No
	call	TFT_warnings_color
	STRCPY_TEXT tDiveFallback			; "Fallback!"
	movlw	dm_warning_length			; Divemode string length
	rcall	TFT_fillup_with_spaces		; Fillup FSR2 with spaces (Total string length in #WREG)
	STRCAT_PRINT ""
	goto	TFT_standard_color			; and return...


	global	TFT_info_deco
TFT_info_deco:							; show info when in decompression
	rcall	TFT_warning_set_window		; Sets the row and column for the current warning
	tstfsz	WREG						; Is there room for the warning?
	return								; NO  - return
	movlw	color_green					; YES - select green text color
	call	TFT_set_color				;       set color
	STRCPY_TEXT tDecoInfo				;       write "Deco Zone"
	movlw	dm_warning_length			;       select Divemode string length
	rcall	TFT_fillup_with_spaces		;       Fillup FSR2 with spaces (Total string length in #WREG)
	STRCAT_PRINT ""						;       print buffer
	goto	TFT_standard_color			;       and return...


	global	TFT_warning_gf
TFT_warning_gf:							; GF
	rcall	TFT_warning_set_window		; Sets the row and column for the current warning
	tstfsz	WREG						; Is there room for the warning?
	return								; No
	movff	int_O_gradient_factor+0,lo	; bank-safe copy gradient factor
	movff	int_O_gradient_factor+1,hi	;
	call	TFT_color_code_gf			; Color-code Output
	STRCPY	"GF:  "						; the two spaces are on purpose to align the output with other warnings' outputs
	bsf		leftbind
	output_8							; print value of lo only, int_O_gradient_factor is limited to 255
	PUTC	"%"
	movlw	dm_warning_length			; Divemode string length
	btfss	divemode					; In Divemode?
	movlw	surf_warning_length			; No, use surface string length
	rcall	TFT_fillup_with_spaces		; Fillup FSR2 with spaces (Total string length in #WREG)
	STRCAT_PRINT ""
	bcf		leftbind
	bcf		win_invert
	goto	TFT_standard_color			; and return...


	global	TFT_warning_mbubbles
TFT_warning_mbubbles:
	rcall	TFT_warning_set_window		; sets the row and column for the current warning
	tstfsz	WREG						; Is there room for the warning?
	return								; NO
	call	TFT_attention_color			; set attention color as default
	movff	char_O_deco_warnings,WREG	; bank-safe copy for deco warnings
	btfsc	WREG,mbubble_warning		; are we in the microbubbles zone right now?
	call	TFT_warnings_color			; YES - reconfigure to warning color
	STRCPY_TEXT tMicroBubbles
	movlw	dm_warning_length			; divemode string length
	btfss	divemode					; in Divemode?
	movlw	surf_warning_length			; NO  - use surface string length
	rcall	TFT_fillup_with_spaces		; fillup FSR2 with spaces (total string length in #WREG)
	STRCAT_PRINT ""
	goto	TFT_standard_color			; and return...


	global	TFT_warning_outside
TFT_warning_outside:
	rcall	TFT_warning_set_window		; sets the row and column for the current warning
	tstfsz	WREG						; is there room for the warning?
	return								; NO
	call	TFT_attention_color
	movff	char_O_deco_warnings,WREG	; bank-safe copy for deco warnings
	btfsc	WREG,outside_warning		; are we outside the ZH-L16 model right now?
	call	TFT_warnings_color			; YES - reconfigure to warning color
	STRCPY	"X-ZHL16-X"
	movlw	dm_warning_length			; divemode string length
	btfss	divemode					; in Divemode?
	movlw	surf_warning_length			; NO  - use surface string length
	rcall	TFT_fillup_with_spaces		; fillup FSR2 with spaces (total string length in #WREG)
	STRCAT_PRINT ""
	goto	TFT_standard_color			; and return...


	global	TFT_warning_gas_needs_warn
	global	TFT_warning_gas_needs_att
TFT_warning_gas_needs_warn:
	rcall	TFT_warning_gas_needs_war_helper
	rcall	TFT_warning_set_window		; Sets the row and column for the current warning
	tstfsz	WREG						; Is there room for the warning?
	return								; No
	call	TFT_warnings_color
	bra		TFT_warning_gas_needs_com
TFT_warning_gas_needs_att:
	rcall	TFT_warning_gas_needs_att_helper
	rcall	TFT_warning_set_window		; Sets the row and column for the current warning
	tstfsz	WREG						; Is there room for the warning?
	return								; No
	call	TFT_attention_color
TFT_warning_gas_needs_com:
	STRCPY_TEXT tGasNeedsWarn			; "Gas Needs"
	movlw	dm_warning_length			; Divemode string length
	rcall	TFT_fillup_with_spaces		; Fillup FSR2 with spaces (Total string length in #WREG)
	STRCAT_PRINT ""
	goto	TFT_standard_color			; and return...

TFT_warning_gas_needs_war_helper:
	incf	warning_counter,F			; increase counter
	btfsc	gas_needs_warning			; is it a new warning?
	return								; NO  - do not show the gas needs custom view again
	bsf		gas_needs_warning			; YES - memorise it's an old now
	bra		TFT_warning_gas_needs_helper_com
TFT_warning_gas_needs_att_helper:
	incf	warning_counter,F			; increase counter
	btfsc	gas_needs_attention			; is it a new attention?
	return								; NO  - do not show the gas needs custom view again
	bsf		gas_needs_attention			; YES - memorise it's an old now
TFT_warning_gas_needs_helper_com:
	movlw	.12							; customview number one below gas needs view
	movwf	menupos3					; set fake current view number
	bsf		toggle_customview			; initiate toggle of customview -> gas needs view will be shown
	return


	global	TFT_warning_IBCD
TFT_warning_IBCD:
	rcall	TFT_warning_set_window		; Sets the row and column for the current warning
	tstfsz	WREG						; Is there room for the warning?
	return								; No
	call	TFT_attention_color			; select attention color as default
	STRCPY_TEXT tIBCD					; "IBCD N2He"
	movlw	dm_warning_length			; Divemode string length
	rcall	TFT_fillup_with_spaces		; Fillup FSR2 with spaces (Total string length in #WREG)
	STRCAT_PRINT ""
	goto	TFT_standard_color			; and return...


	global	TFT_warning_sensor_disagree
TFT_warning_sensor_disagree:			; Show sensor disagree warning
	rcall	TFT_warning_sensor_dis_helper
	rcall	TFT_warning_set_window		; Sets the row and column for the current warning
	tstfsz	WREG						; Is there room for the warning?
	return								; No
	call	TFT_warnings_color
	STRCPY_TEXT tSensorDisagree			; "Sensors<>"
	movlw	dm_warning_length			; Divemode string length
	rcall	TFT_fillup_with_spaces		; Fillup FSR2 with spaces (Total string length in #WREG)
	STRCAT_PRINT ""
	goto	TFT_standard_color			; and return...

TFT_warning_sensor_dis_helper:
	btfsc	sensor_warning				; is it a new warning?
	return								; NO  - do not show the gas needs custom view again
	bsf		sensor_warning				; YES - memories it's an old warning now
	clrf	menupos3					; set fake current view number
	bsf		toggle_customview			; initiate toggle of customview -> sensor view will be shown
	return

;=============================================================================

TFT_warning_set_window:					; Sets the row and column for the current warning
	; ignore warning (now)?
	decf	warning_counter,W			; -1
	bcf		STATUS,C
	btfss	alternative_divelayout		; In alt mode, do not divide...
	rrcf	WREG,W						; (warning_counter-1)/2
	cpfseq	warning_page
	retlw	.255						; WREG <> 0 -> Warning window not defined
	call	TFT_standard_color
	btfss	divemode					; in divemode?
	bra		TFT_warning_set_window3		; No, setup for surface mode
	btfss	alternative_divelayout
	bra		TFT_warning_set_window3a	; standard layout
	bra		TFT_warning_set_window2a	; alternative layout (Only lower row used)
TFT_warning_set_window3a:	
	btfss	warning_counter,0			; Toggle with each warning
	bra		TFT_warning_set_window2
	WIN_SMALL dm_warning1_column, dm_warning1_row
	bcf		second_row_warning			; =1: The second row contains a warning
	retlw	.0							; WREG=0 -> Warning window defined
TFT_warning_set_window2:
	bsf		second_row_warning			; =1: The second row contains a warning
TFT_warning_set_window2a:	
	WIN_SMALL dm_warning2_column, dm_warning2_row
	retlw	.0							; WREG=0 -> Warning window defined
TFT_warning_set_window3:
	btfss	warning_counter,0			; Toggle with each warning
	bra		TFT_warning_set_window4
	WIN_SMALL surf_warning1_column,surf_warning1_row
	bcf		second_row_warning			; =1: The second row contains a warning
	retlw	.0							; WREG=0 -> Warning window defined
TFT_warning_set_window4:
	WIN_SMALL surf_warning2_column,surf_warning2_row
	bsf		second_row_warning			; =1: The second row contains a warning
	retlw	.0							; WREG=0 -> Warning window defined


	global	TFT_update_batt_percent_divemode
TFT_update_batt_percent_divemode:
	rcall	TFT_warning_set_window		; Sets the row and column for the current warning
	tstfsz	WREG						; Is there room for the warning?
	return								; No
	movff	batt_percent,lo				; Get battery percent
	call	TFT_color_code_battery		; Color-code battery percent
	STRCPY	"Batt:"
	bsf		leftbind
	output_8
	bcf		leftbind
	PUTC	"%"
	movlw	dm_warning_length			; Divemode string length
	btfss	divemode					; In Divemode?
	movlw	surf_warning_length			; No, use surface string length
	rcall	TFT_fillup_with_spaces		; Fillup FSR2 with spaces (Total string length in #WREG)
	STRCAT_PRINT ""
	bcf		win_invert
	goto	TFT_standard_color			; and return...


	global	TFT_gf_mask					; Setup Mask
TFT_gf_mask:
	; The mask
	call	TFT_divemask_color
	WIN_TINY dm_custom_gf_title_col1, dm_custom_gf_title_row
	STRCPY_TEXT_PRINT tGFactors
	WIN_TINY dm_custom_gf_title_col2, dm_custom_gf_title_row
	STRCPY_TEXT_PRINT taGFactors
	WIN_TINY dm_custom_gf_title_col3, dm_custom_gf_title_row
	STRCPY_TEXT_PRINT tGFInfo
	; Show GF (Static)
	call	TFT_disabled_color
	btfss	use_agf
	call	TFT_standard_color
	WIN_STD	dm_custom_gf_column, dm_custom_gf_row
	bsf		leftbind
	movff	opt_GF_low,lo
	output_8
	PUTC	"/"
	movff	opt_GF_high,lo
	output_8
	STRCAT_PRINT ""
	; Show aGF (Static)
	call	TFT_standard_color
	TSTOSS	opt_enable_aGF				; =1: aGF can be selected underwater
	bra	 TFT_gf_mask2					; Show "---" instead
	btfss	use_agf
	call	TFT_disabled_color
	WIN_STD	dm_custom_agf_column, dm_custom_agf_row
	movff	opt_aGF_low,lo
	output_8
	PUTC	"/"
	movff	opt_aGF_high,lo
	output_8
	STRCAT_PRINT ""
	bcf		leftbind
	goto	TFT_standard_color			; and return...

TFT_gf_mask2:
	WIN_STD	dm_custom_agf_column+.10, dm_custom_agf_row
	STRCPY_PRINT "---"
	bcf		leftbind
	return


	global	TFT_gf_mask_cGF				; Setup Mask
TFT_gf_mask_cGF:
	; The mask
	call	TFT_divemask_color
	WIN_TINY dm_custom_gf_title_col3, dm_custom_gf_title_row
	STRCPY_TEXT_PRINT tGFInfo
	goto	TFT_standard_color			; and return...

	global	TFT_gf_info					; Show GF informations
TFT_gf_info:
	WIN_STD	dm_custom_currentgf_column, dm_custom_currentgf_row
	movff	int_O_gradient_factor+0,lo	; gradient factor absolute (Non-GF model)
	movff	int_O_gradient_factor+1,hi
	call	TFT_color_code_gf			; Color-code Output
	output_8							; print lo only, int_O_gradient_factor is limited to 255
	STRCAT_PRINT "%"
	return


	global	TFT_battinfo_tissues_clock_mask		; Setup Mask
TFT_battinfo_tissues_clock_mask:
	; The mask
	; Put three columns at HUD positions
	call	TFT_divemask_color
	btfsc	FLAG_apnoe_mode						; In Apnoe mode?
	bra		TFT_battinfo_tissues_clock_mask2	; Yes
	btfsc	FLAG_gauge_mode						; In Gauge mode?
	bra		TFT_battinfo_tissues_clock_mask2	; Yes
	WIN_TINY dm_custom_tissue_title_column, dm_custom_tissue_title_row
	STRCPY_TEXT_PRINT tDiveTissues
TFT_battinfo_tissues_clock_mask2:				; Show only clock
	WIN_TINY dm_custom_ead_column, dm_custom_eadend_title_row
	STRCPY_TEXT_PRINT tBatteryV					; "Battery: "
	WIN_TINY dm_custom_clock_column, dm_custom_clock_title_row
	STRCPY_TEXT_PRINT tDiveClock
	goto	TFT_standard_color					; and return...

	global	TFT_battinfo_tissues_clock	; Show EAD/END, Tissues and clock
TFT_battinfo_tissues_clock:
	; Update clock and date
	WIN_SMALL dm_custom_clock_column, dm_custom_clock_row
	call	TFT_clock2					; print clock

	; Show Battery info
	WIN_SMALL	dm_custom_ead_column, dm_custom_ead_row
	movff	batt_percent,lo				; Get battery percent
	call	TFT_color_code_battery		; Color-code battery percent
	bsf		leftbind
	output_8
	bcf		leftbind
	STRCAT	"% "
	movlw	0x00
	movff	WREG,buffer+4				; Only "xxx%"
	STRCAT_PRINT ""
	bcf		win_invert
	call	TFT_standard_color
	WIN_SMALL dm_custom_end_column, dm_custom_end_row
	movff	batt_voltage+0,lo
	movff	batt_voltage+1,hi
	bsf		leftbind
	output_16dp	.2
	bcf		leftbind
	PUTC	'V'
	movff	buffer+5,buffer+4
	movlw	0x00
	movff	WREG,buffer+5				; Only "x.yzV"
	STRCAT_PRINT ""

	btfsc	FLAG_apnoe_mode				; In Apnoe mode?
	return								; Yes, done.
	btfsc	FLAG_gauge_mode				; In Gauge mode?
	return								; Yes, done.

	; Show tissue diagram
	call	TFT_divemask_color
	WIN_TINY dm_custom_tissue_N2_column, dm_custom_tissue_N2_row
	STRCPY_TEXT_PRINT tN2
	WIN_TINY dm_custom_tissue_He_column, dm_custom_tissue_He_row
	STRCPY_TEXT_PRINT tHe
	bra	DISP_tissue_saturation_graph	; Show char_O_tissue_N2_saturation and char_O_tissue_He_saturation and return...


	global	TFT_pscr_info_mask
TFT_pscr_info_mask:						; Show pSCR-ppO2, drop and lung ratio mask	
	rcall	TFT_mask_ppo2
	call	TFT_divemask_color
	WIN_TINY dm_custom_pscr_text_drop_column, dm_custom_pscr_text_row
	STRCPY_TEXT_PRINT tPSCR_O2_drop
	WIN_TINY dm_custom_pscr_text_ratio_column, dm_custom_pscr_text_row
	STRCPY_TEXT_PRINT tPSCR_lungratio
	goto	TFT_standard_color			; and return...

	global	TFT_pscr_info				; Show pSCR-ppO2, drop and lung ratio
TFT_pscr_info:
	;show ppO2
	WIN_MEDIUM dm_custom_ceiling_ppo2_val_col, dm_custom_ceiling_value_row
	movff	int_O_pSCR_ppO2+0,lo			; copy pSCR ppO2 to hi:lo
	movff	int_O_pSCR_ppO2+1,hi
	call	TFT_color_code_ppo2				; color-code output
	bsf		leftbind
	output_16dp .3							; x.xx bar
	bcf		leftbind
	STRCAT_PRINT ""
	; Show Drop
	WIN_STD dm_custom_pscr_drop_column,dm_custom_pscr_drop_row
	call	TFT_standard_color
	movff	char_I_PSCR_drop,lo
	bsf		leftbind
	output_8
	STRCAT_PRINT "%"
	; Show lung ratio
	WIN_STD dm_custom_pscr_ratio_column,dm_custom_pscr_ratio_row
	movff	char_I_PSCR_lungratio,lo
	bsf		leftbind
	STRCPY	"1/"
	output_8
	STRCAT_PRINT ""
	bcf		leftbind
	return


	global	TFT_gas_needs_mask
TFT_gas_needs_mask:
	call	TFT_divemask_color
	WIN_TINY dm_custom_dyn_gas_mask_column-.10,dm_custom_dyn_gas_mask_row
	STRCPY_TEXT_PRINT	tGasNeedsBar	; "Gas Needs (bar)"
	goto	TFT_standard_color			; and return...

	global	TFT_gas_needs
TFT_gas_needs:							; LIMITATION: there is only space for 4 gases on the screen - if 5 gases
	bsf		leftbind					;             have a pres_need > 0, then only the first 4 will be shown!
	clrf	up
	WIN_SMALL dm_custom_dyn_gas_column1+.5,dm_custom_dyn_gas_row1
	call	TFT_gas_needs_helper
	WIN_SMALL dm_custom_dyn_gas_column1+.5,dm_custom_dyn_gas_row2
	call	TFT_gas_needs_helper
	WIN_SMALL dm_custom_dyn_gas_column2+.5,dm_custom_dyn_gas_row1
	call	TFT_gas_needs_helper
	WIN_SMALL dm_custom_dyn_gas_column2+.5,dm_custom_dyn_gas_row2
	call	TFT_gas_needs_helper
	bcf		leftbind
	return

TFT_gas_needs_helper:
	call	TFT_standard_color
	movlw	.5							; number of gases
	cpfslt	up							; check if all gases have been processed
	bra		TFT_gas_needs_helper_1		; yes -> clear display area
	movf	up,W						; no  -> get gas number	and check if need of that gas is > 0
	rlncf	WREG,W						; multipy by 2
	lfsr	FSR1,int_O_tank_pres_need+1 ; read HIGH(int_O_tank_pres_need[up])
	movff	PLUSW1,hi					; copy to temp storage hi
	btfss	hi,int_is_zero				; check flag for pres_need == 0
	bra		TFT_gas_needs_helper_2		; no  -> print gas type and pressure needed
	incf	up,F						; yes -> increment to next gas...
	bra		TFT_gas_needs_helper		; ...and try the next gas
TFT_gas_needs_helper_1:					; no gases to show anymore, clear display area from potential remains of last invocation
	STRCAT_PRINT "  ----   "			; overwrite outdated stuff if screen position is not needed
	return
TFT_gas_needs_helper_2:					; output gas type and pressure needed
	movf	up,W						; get gas number (0-4) to WREG
	lfsr	FSR1,opt_gas_O2_ratio		; read opt_gas_O2_ratio[WREG]
	movff	PLUSW1,lo					; copy result to lo
	movf	up,W						; get gas number (0-4) to WREG ; SHOULD NOT BE NEEDED AS movff SHOULD NOT ALTER wreg
	lfsr	FSR1,opt_gas_He_ratio		; read opt_gas_He_ratio[WREG]
	movff	PLUSW1,hi					; copy result to hi
	call	customview_show_mix			; print "Air", "O2", "21/35", etc.
	STRCAT	":"
	movf	up,W						; get gas number (0-4) to WREG
	rlncf	WREG,W						; multipy by 2
	lfsr	FSR1,int_O_tank_pres_need+0	; read lower part of integer
	movff	PLUSW1,lo
	movf	up,W						; get gas number (0-4) to WREG ; SHOULD NOT BE NEEDED AS movff SHOULD NOT ALTER wreg
	rlncf	WREG,W						; multipy by 2
	lfsr	FSR1,int_O_tank_pres_need+1 ; read upper part of integer
	movff	PLUSW1,hi
	btfsc	hi,int_attention_flag		; check if attention flag is set (pres_need > pres_fill * threshold)
	call	TFT_attention_color			; yes, print gas need in yellow
	btfsc	hi,int_warning_flag			; check if warning flag is set	(pres_need > pres_fill)
	call	TFT_warnings_color			; yes, print gas need in red
	movff	int_O_tank_pres_need+1,WREG	; get HIGH(int_O_tank_pres_need[0]) which hold flag for invalid data
	btfsc	WREG,int_invalid_flag		; check if invalid data flag is set
	call	TFT_disabled_color			; yes, print gas need in disabled color
	bcf		hi,int_attention_flag		; clear attention flag for attention color
	bcf		hi,int_warning_flag			; clear warning	flag for warning	color
	bcf		hi,int_invalid_flag			; clear flag for invalid data (will actually only be set with 1st gas)	
	output_16_3							; limit to 999 and display only (0-999)
	STRCAT_PRINT " "					; adds a space to overwrite any potential remains of earlier outputs
	incf	up,F						; increment to next gas
	goto	TFT_standard_color			; and return...


	global	TFT_mask_ppo2				; helper function for several custom views
TFT_mask_ppo2:
	call	TFT_divemask_color
	btfss	FLAG_ccr_mode				; in CCR mode?
	bra		TFT_mask_ppo2a				; NO  - continue checking for pSCR and OC
	btfsc	is_bailout					; in bailout?
	bra		TFT_mask_ppo2b				; YES
	WIN_TINY dm_custom_ceiling_ppo2_col_dil,dm_custom_ceiling_text_row	; tuned position for longer text
	STRCPY_TEXT_PRINT tppO2Dil			; print "ppO2(Dil)"
	goto	TFT_standard_color			; and return...
TFT_mask_ppo2a:
	btfss	FLAG_pscr_mode				; in pSCR mode?
	bra		TFT_mask_ppo2b				; NO  - continue with OC mode (or bailout)
	btfsc	is_bailout					; in bailout?
	bra		TFT_mask_ppo2b				; YES
	WIN_TINY dm_custom_ceiling_ppo2_col_dil,dm_custom_ceiling_text_row	; tuned position for longer text
	STRCPY_TEXT_PRINT tppO2Mix			; print "ppO2(Mix)"
	goto	TFT_standard_color			; and return... 
TFT_mask_ppo2b:							; OC mode or bailout
	WIN_TINY dm_custom_ceiling_ppo2_column, dm_custom_ceiling_text_row	; normal position
	STRCPY_TEXT_PRINT tppO2				; in all other modes
	goto	TFT_standard_color			; and return...


	global	TFT_display_pure_ppo2		; show ppO2 of the pure gas - helper function for several custom views
TFT_display_pure_ppo2:
	WIN_MEDIUM dm_custom_ceiling_ppo2_val_col, dm_custom_ceiling_value_row
	movff	int_O_pure_ppO2+0,lo		; copy ppO2 of the pure gas to hi:lo
	movff	int_O_pure_ppO2+1,hi
	call	TFT_color_code_ppo2			; color-code output
	bsf		leftbind
	output_16dp .3						; x.xx bar
	bcf		leftbind
	STRCAT_PRINT ""
	goto	TFT_standard_color			; and return...


	global TFT_ppo2_ead_end_cns_mask	; Show ppO2, END/EAD and CNS mask
TFT_ppo2_ead_end_cns_mask:
	rcall	TFT_mask_ppo2
	call	TFT_divemask_color
	WIN_TINY dm_custom_ead_column, dm_custom_eadend_title_row
	STRCPY_TEXT_PRINT tDiveEAD_END
	WIN_TINY dm_custom_gf_title_col3, dm_custom_gf_title_row
	STRCPY_TEXT_PRINT tCNS2
	goto	TFT_standard_color			; and return...


	global	TFT_ppo2_ead_end_cns		; Show ppO2, END/EAD and CNS
TFT_ppo2_ead_end_cns:
	;show ppO2
	rcall	TFT_display_pure_ppo2		; show ppO2 of the pure gas
	; Show END/EAD
	WIN_SMALL	dm_custom_ead_column, dm_custom_ead_row
	STRCPY_TEXT tEAD					; EAD:
	movff	char_O_EAD,lo
	rcall	TFT_end_ead_common			; print "lo m" (or ft) and limit to 8 chars
	WIN_SMALL dm_custom_end_column, dm_custom_end_row
	STRCPY_TEXT tEND					; END:
	movff	char_O_END,lo
	rcall	TFT_end_ead_common			; print "lo m" (or ft) and limit to 8 chars
	; Show CNS
	WIN_STD	dm_custom_currentgf_column, dm_custom_currentgf_row
	movff	int_O_CNS_fraction+0,lo
	movff	int_O_CNS_fraction+1,hi
	call	TFT_color_code_cns			; Color-code CNS output
	bsf		leftbind
	output_16_3							; Displays only 0...999
	bcf		leftbind
	STRCAT_PRINT "%"
	goto	TFT_standard_color			; and return...

TFT_end_ead_common:						; print "lo m" (or ft) and limit to 8 chars
	bsf		leftbind
	TSTOSS	opt_units					; 0=Meters, 1=Feets
	bra		TFT_end_ead_common_metric
;TFT_end_ead_common_imperial:
	movf	lo,W						; With lo in m
	mullw	.100						; PRODL:PRODH = mbar/min
	movff	PRODL,lo
	movff	PRODH,hi
	call	convert_mbar_to_feet		; convert value in lo:hi from mbar to feet
	output_16_3
	STRCAT_TEXT tFeets
	clrf	WREG
	movff	WREG,buffer+.8				; limit string length to 8
	bra	 TFT_end_ead_common_exit
TFT_end_ead_common_metric:
	output_8
	STRCAT_TEXT tMeters
TFT_end_ead_common_exit:
	bcf		leftbind
	movlw	.8
	rcall	TFT_fillup_with_spaces		; Fillup FSR2 with spaces (Total string length in #WREG)
	STRCAT_PRINT ""
	return


	global	TFT_sensor_check_mask		; show ppO2 of O2 and Diluent mask
TFT_sensor_check_mask:
	call	TFT_divemask_color
	WIN_TINY dm_custom_s_check_text_column, dm_custom_s_check_text_row
	STRCPY_TEXT_PRINT tSensorCheck
	WIN_TINY dm_custom_ppO2_text_column, dm_custom_s_check_text_row
	STRCPY_TEXT_PRINT tppO2O2
	WIN_TINY dm_custom_ppDil_text_column, dm_custom_s_check_text_row
	STRCPY_TEXT_PRINT tppO2Dil
	goto	TFT_standard_color			; and return...

	global	TFT_sensor_check			; show ppO2 of O2 and Diluent
TFT_sensor_check:
	; Show ppO2 of O2 in this depth
	WIN_MEDIUM dm_custom_s_check_ppo2_o2_column, dm_custom_s_check_value_row
	movff	int_O_O2_ppO2+0,lo			; copy ppO2 of pure O2 to hi:lo
	movff	int_O_O2_ppO2+1,hi
	call	TFT_color_code_ppo2			; color-code output
	bsf		leftbind
	output_16dp .3						; x.xx bar
	bcf		leftbind
	STRCAT_PRINT ""
	; Show ppO2 of the diluent in this depth
	WIN_MEDIUM	dm_custom_s_check_ppo2_dil_col, dm_custom_s_check_value_row
	movff	int_O_pure_ppO2+0,lo		; copy ppO2 of pure gas to hi:lo
	movff	int_O_pure_ppO2+1,hi
	call	TFT_color_code_ppo2			; color-code output
	bsf		leftbind
	output_16dp .3						; x.xx bar
	bcf		leftbind
	STRCAT_PRINT ""
	goto	TFT_standard_color			; and return...

;=============================================================================

	global	TFT_surface_lastdive
TFT_surface_lastdive:
	call	TFT_divemask_color
	WIN_TINY surf_gaslist_column,surf_gaslist_row+.5
	STRCAT_TEXT_PRINT	tLastDive			; Last Dive:
	WIN_TINY surf_gaslist_column,surf_gaslist_row+(surf_gaslist_spacing*.1)+.5
	STRCAT_TEXT_PRINT	tDivetime			; Divetime
	WIN_TINY surf_gaslist_column,surf_gaslist_row+(surf_gaslist_spacing*.2)+.5
	STRCAT_TEXT_PRINT	tMaxDepth			; Max. Depth
	call	TFT_standard_color
	WIN_SMALL surf_gaslist_column+.48,surf_gaslist_row

	movff	int_O_desaturation_time+0,lo	; bank-safe copies
	movff	int_O_desaturation_time+1,WREG
	iorwf	lo,W							; check if desaturation time is zero
	bz		TFT_surface_lastdive_1			; YES - show last dive time
	movff	surface_interval+0,lo			; NO  - show dive interval
	movff	surface_interval+1,hi
	call	convert_time					; lo=mins, hi=hours
	movf	hi,W
	movff	lo,hi
	movwf	lo								; exchange lo and hi
	bsf		leftbind
	output_99x
	PUTC	'h'
	movff	hi,lo
	output_99x
	STRCAT_PRINT "m "
	bra		TFT_surface_lastdive_2
TFT_surface_lastdive_1:
	movff	lastdive_time+0,xC+0
	movff	lastdive_time+1,xC+1
	movff	lastdive_time+2,xC+2
	movff	lastdive_time+3,xC+3
	movlw	LOW  .3600
	movwf	xB+0
	movlw	HIGH .3600
	movwf	xB+1							; One day = 3600s
	call	div32x16						; xC:4 / xB:2 = xC+3:xC+2 with xC+1:xC+0 as remainder
	;xC+0:xC+1 -> Full hours
	movff	xC+1,xA+1
	movff	xC+0,xA+0
	clrf	xB+1
	movlw	.24
	movwf	xB+0
	call	div16x16						;xA/xB=xC with xA+0 as remainder
	movff	xC+0,lo
	movff	xC+1,hi							; Full days
	bsf		leftbind
	output_16
	PUTC	"d"
	movff	xA+0,lo							; Full hours
	output_8
	STRCAT_PRINT "h "
TFT_surface_lastdive_2:
	WIN_SMALL surf_gaslist_column+.48,surf_gaslist_row+(surf_gaslist_spacing*.1)
	movff	lastdive_duration+0,lo
	movff	lastdive_duration+1,hi
	output_16								; divetime minutes
	PUTC	":"
	movff	lastdive_duration+2,lo
	output_99x								; divetime seconds
	STRCAT_PRINT ""
	WIN_SMALL	surf_gaslist_column+.48,surf_gaslist_row+(surf_gaslist_spacing*.2)
	movff	lastdive_maxdepth+0,lo
	movff	lastdive_maxdepth+1,hi
	TSTOSS	opt_units						; 0=Meters, 1=Feets
	bra		TFT_surface_lastdive_metric
	;imperial
	rcall	convert_mbar_to_feet			; convert value in lo:hi from mbar to feet
	output_16_3								; limit to 999 and display only (0-999)
	STRCAT_TEXT tFeets1
	bra		TFT_surface_lastdive2

TFT_surface_lastdive_metric:
	bsf		ignore_digit5					; no cm...
	movlw	d'1'							; +1
	movff	WREG,ignore_digits				; no 1000m
	output_16dp .3							; xxx.y
	STRCAT_TEXT tMeters
TFT_surface_lastdive2:
	STRCAT_PRINT ""
	bcf		leftbind
	return									; Done.

;=============================================================================

	global	TFT_surface_tissues
TFT_surface_tissues:						; Show Tissue diagram in surface mode
	WIN_SMALL surf_tissue_N2_column,surf_tissue_N2_row
	STRCPY_TEXT_PRINT tN2
	WIN_SMALL surf_tissue_He_column,surf_tissue_He_row
	STRCPY_TEXT_PRINT tHe

	movlw	color_deepblue
	call	TFT_set_color					; Make this configurable?
	WIN_FRAME_COLOR16 surf_tissue_diagram_top+.23,surf_tissue_diagram_bottom-.4,.29,.29
	WIN_FRAME_COLOR16 surf_tissue_diagram_top+.23,surf_tissue_diagram_bottom-.4,.37,.37
	WIN_FRAME_COLOR16 surf_tissue_diagram_top+.23,surf_tissue_diagram_bottom-.4,.45,.45
	WIN_FRAME_COLOR16 surf_tissue_diagram_top+.23,surf_tissue_diagram_bottom-.4,.53,.53
	WIN_FRAME_COLOR16 surf_tissue_diagram_top+.23,surf_tissue_diagram_bottom-.4,.61,.61
	WIN_FRAME_COLOR16 surf_tissue_diagram_top+.23,surf_tissue_diagram_bottom-.4,.69,.69
	WIN_FRAME_COLOR16 surf_tissue_diagram_top+.23,surf_tissue_diagram_bottom-.4,.77,.77
	WIN_FRAME_COLOR16 surf_tissue_diagram_top+.23,surf_tissue_diagram_bottom-.4,.85,.85
	WIN_FRAME_STD     surf_tissue_diagram_top, surf_tissue_diagram_bottom, surf_tissue_diagram_left, surf_tissue_diagram_right	; outer frame

	movlw	.1
	movff	WREG,win_height												; row bottom (0-239)

	;---- Draw N2 Tissues ----------------------------------------------------

	movlw	surf_tissue_diagram_left+.4									; start position for N2 bars
	movff	WREG,win_leftx2												; column left (0-159)
	movlw	surf_tissue_diagram_right - surf_tissue_diagram_left - .4	; max width for N2 bars
	movff	WREG,win_width

	lfsr	FSR2, char_O_tissue_N2_saturation
	movlw	d'16'
	movwf	lo															; 16 tissues
	clrf	hi															; row offset
surf_tissue_saturation_graph_N2:
	movlw	surf_tissue_diagram_top+.23									; surface mode
	addwf	hi,W
	movff	WREG,win_top												; row top (0-239)
	rcall	surf_tissue_saturation_loop									; show one tissue
	decfsz	lo,F
	bra		surf_tissue_saturation_graph_N2

	;---- Draw He Tissues ----------------------------------------------------

	movlw	surf_tissue_diagram_left + .24								; start position for He bars (.15 without x2)
	movff	WREG,win_leftx2												; column left (0-159)
	movlw	surf_tissue_diagram_right - surf_tissue_diagram_left - .24	; max width for He bars
	movff	WREG,win_width

	lfsr	FSR2, char_O_tissue_He_saturation
	movlw	d'16'
	movwf	lo															; 16 tissues
	clrf	hi													; row offset
surf_tissue_saturation_graph_He:
	movlw	surf_tissue_diagram_top+.23+.57								; surface mode
	addwf	hi,W
	movff	WREG,win_top												; row top (0-239)
	rcall	surf_tissue_saturation_loop									; show one tissue
	decfsz	lo,F
	bra		surf_tissue_saturation_graph_He

	WIN_SMALL surf_tissue_He_column+.22,surf_tissue_He_row				; position in-between tissue bars
	movff	int_O_CNS_fraction+0,lo
	movff	int_O_CNS_fraction+1,hi
	call	TFT_color_code_cns
	STRCPY_TEXT tCNS2													; CNS:
	bsf		leftbind
	output_16_3															; Displays only 0...999
	bcf		leftbind
	STRCAT_PRINT "%"
	goto	TFT_standard_color											; and return...

surf_tissue_saturation_loop:
	call	TFT_standard_color
	movlw	.2							; row spacing
	addwf	hi,F
	movf	POSTINC2,W					; get tissue load
	bcf		WREG,7						; clear flag bit for sat/desat info (not used in surface mode)
	rlncf	WREG,W						; multiply with 2 (previously cleared bit 7 will be rotated to bit 0)
	incf	WREG,W						; add 1 for a minimum visible bar (He-bars could be invisible else-wise)
	movwf	up
	movff	win_width+0,WREG			; get max window width (win_width)
	cpfslt	up							; skip if WREG < win_width
	movwf	up							; crop length to win_width
										; no need to be able to draw longer bars –
										; we are at the surface and if bars would
										; even touch the max length possible here,
										; the diver would be in severe decompression
										; issues if not dead already...
	movff	up,win_bargraph
	clrf	win_width+1
	goto	TFT_box						; and return...

;=============================================================================
; Draw saturation graph in dive mode.

DISP_tissue_saturation_graph:
	;---- Draw Frame
	call	TFT_standard_color
	WIN_FRAME_COLOR16 dm_custom_tissue_diagram_top, dm_custom_tissue_diagram_bottom, dm_custom_tissue_diagram_left, .159	; outer frame

	movlw	.1
	movff	WREG,win_height							; row bottom (0-239)

	;---- Draw N2 Tissues ----------------------------------------------------

	movlw	dm_custom_tissue_diagram_left+.3		; divemode
	movff	WREG,win_leftx2							; column left (0-159)
	movlw	.159-dm_custom_tissue_diagram_left-.4	; width
	movff	WREG,win_width

	lfsr	FSR2, char_O_tissue_N2_saturation
	movlw	d'16'
	movwf	lo											; 16 tissues
	clrf	hi											; row offset
tissue_saturation_graph_N2:
	movlw	dm_custom_tissue_diagram_top+.3				; divemode
	rcall	tissue_saturation_graph_loop				; show one tissue
	decfsz	lo,F
	bra		tissue_saturation_graph_N2

	;---- Draw He Tissues ----------------------------------------------------

	movlw	dm_custom_tissue_diagram_left + .8			; divemode
	movff	WREG,win_leftx2								; column left (0-159)
	movlw	.159 - dm_custom_tissue_diagram_left - .14	; width
	movff	WREG,win_width

	lfsr	FSR2, char_O_tissue_He_saturation
	movlw	d'16'
	movwf	lo											; 16 tissues
	clrf	hi											; row offset
tissue_saturation_graph_He:
	movlw	dm_custom_tissue_diagram_top+.3+.22			; divemode
	rcall	tissue_saturation_graph_loop				; show one tissue
	decfsz	lo,F
	bra		tissue_saturation_graph_He
	goto	TFT_standard_color							; and return...

tissue_saturation_graph_loop:
	addwf	hi,W
	movff	WREG,win_top								; row top (0-239)
	movlw	color_cyan									; preset color for tissues with decreasing pressure
	call	TFT_set_color
	incf	hi,F
	movf	POSTINC2,W
	btfss	WREG,7										; check fs flag for increasing tissue pressure set
	bra		tissue_saturation_graph_loop_1				; NO  - keep color
	movwf	up											; YES - buffer WREG
	movlw	color_orange								;       select color for tissues with increasing pressure
	call	TFT_set_color								;       change color
	movf	up,W										;       restore WREG
tissue_saturation_graph_loop_1:
	bcf		WREG,7										; clear flag bit
	bcf		STATUS,C
	rrcf	WREG										; divide by 2
	incf	WREG,W										; add a bit for a minimum visible bar
	movwf	up
	movf	win_width,W									; get max window width (win_width)
	cpfslt	up											; skip if WREG < win_width
	movwf	up
	movff	up,win_bargraph
	clrf	win_width+1
	goto	TFT_box										; and return...

;=============================================================================

	global	TFT_display_cns
TFT_display_cns:
	call	TFT_warning_set_window		; Sets the row and column for the current warning
	tstfsz	WREG						; Is there room for the warning?
	return								; No
	STRCPY_TEXT tCNS					; CNS:
	movff	int_O_CNS_fraction+0,lo
	movff	int_O_CNS_fraction+1,hi
	call	TFT_color_code_cns			; Color-code CNS output
	bsf		leftbind
	output_16_3							; Displays only 0...999
	bcf		leftbind
	PUTC	"%"
	movlw	dm_warning_length			; Divemode string length
	btfss	divemode					; In Divemode?
	movlw	surf_warning_length			; No, use surface string length
	call	TFT_fillup_with_spaces		; Fillup FSR2 with spaces (Total string length in #WREG)
	STRCAT_PRINT ""
	bcf		win_invert
	goto	TFT_standard_color			; and return...


	global	TFT_display_eod_cns
TFT_display_eod_cns:
	call	TFT_warning_set_window		; Sets the row and column for the current warning
	tstfsz	WREG						; Is there room for the warning?
	return								; No
	call	TFT_warnings_color			; switch to warnings (red) text color
	STRCPY_TEXT tCNSeod					; end-of-dive CNS warning text
	movlw	dm_warning_length			; Divemode string length
	call	TFT_fillup_with_spaces		; Fillup FSR2 with spaces (Total string length in #WREG)
	STRCAT_PRINT ""
	goto	TFT_standard_color			; and return...


	global	TFT_display_ppo2
TFT_display_ppo2:
	call	TFT_warning_set_window		; Sets the row and column for the current warning
	tstfsz	WREG						; Is there room for the warning?
	return								; No
	movff	int_O_pure_ppO2+0,lo		; copy ppO2 of the pure gas (OC: = breathed gas, loop: = diluent/premix) to hi:lo
	movff	int_O_pure_ppO2+1,hi
	call	TFT_color_code_ppo2			; Color-code output
	btfss	FLAG_ccr_mode				; in CCR mode?
	bra		TFT_display_diluent_1		; NO  - continue with pSCR or OC 
	btfsc	is_bailout					; YES - in bailout?
	bra		TFT_display_diluent_2		;       YES - continue with OC 
	STRCPY_TEXT tdil					;       NO  - print "Dil:"
	bra		TFT_display_diluent_3
TFT_display_diluent_1:
	btfss	FLAG_pscr_mode				; in pSCR mode?
	bra		TFT_display_diluent_2		; NO  - continue with pSCR or OC 
	btfsc	is_bailout					; YES - in bailout?
	bra		TFT_display_diluent_2		;       YES - continue with OC 
	STRCPY_TEXT tmix					;       NO  - print "Mix:"
	bra		TFT_display_diluent_3
TFT_display_diluent_2:
	STRCPY_TEXT tppO2					; OC mode or bailout, print "ppO2:"
TFT_display_diluent_3:
	bsf		leftbind
	output_16dp .3						; x.xx bar
	bcf		leftbind
	movlw	dm_warning_length			; Divemode string length
	call	TFT_fillup_with_spaces		; Fillup FSR2 with spaces (Total string length in #WREG)
	STRCAT_PRINT ""
	goto	TFT_standard_color			; and return...

;=============================================================================

	global	TFT_LogOffset_Logtitle
TFT_LogOffset_Logtitle:
	STRCPY_TEXT tLogOffset
	PUTC	":"
	call	do_logoffset_common_read	; Offset into lo:hi
	bsf		leftbind
	output_16_4
	bcf		leftbind
	PUTC	" "
	return								; No "_PRINT" here...

;=============================================================================

	global	adjust_depth_with_salinity
	global	adjust_depth_with_salinity_log
adjust_depth_with_salinity:			; computes salinity setting into lo:hi [mbar]
	btfsc	simulatormode_active	; Do not apply salinity in simulator mode
	return
	movff	opt_salinity,WREG		; 0-5%
adjust_depth_with_salinity_log:		; computes salinity setting (FROM WREG!) into lo:hi [mbar]
	addlw	d'100'					; 1.00kg/l
	movwf	up

	movlw	d'105'					; 105% ?
	cpfslt	up						; Salinity higher limit
	return							; Out of limit, do not adjust lo:hi
	movlw	d'99'					; 99% ?
	cpfsgt	up						; Salinity lower limit
	return							; Out of limit, do not adjust lo:hi

	movff	lo,xA+0
	movff	hi,xA+1

	movlw	d'102'					; 0,98bar/10m
	movwf	xB+0
	clrf	xB+1
	call	mult16x16				; xA*xB=xC (lo:hi * 100)
	movff	up,xB+0					; Salinity
	clrf	xB+1
	call	div32x16				; xC:4 / xB:2 = xC+3:xC+2 with xC+1:xC+0 as remainder
	movff	xC+0,lo
	movff	xC+1,hi					; restore lo and hi with updated value
	return

;=============================================================================

	global	convert_mbar_to_feet	; convert value in lo:hi from mbar to feet
convert_mbar_to_feet:				; convert value in lo:hi from mbar to feet
	movff	lo,xA+0
	movff	hi,xA+1

	movlw	LOW  d'328'				; 328feet/100m
	movwf	xB+0
	movlw	HIGH d'328'
	movwf	xB+1

	call	mult16x16				; xA*xB=xC (lo:hi * 328)

	movlw	d'50'					; round up
	addwf	xC+0,F
	movlw	0
	addwfc	xC+1,F
	addwfc	xC+2,F
	addwfc	xC+3,F

	movlw	LOW  .10000
	movwf	xB+0
	movlw	HIGH .10000
	movwf	xB+1

	call	div32x16				; xC:4 / xB:2 = xC+3:xC+2 with xC+1:xC+0 as remainder

	movff	xC+0,lo
	movff	xC+1,hi					; restore lo and hi with updated value
	return

;=============================================================================	

	global	convert_celsius_to_fahrenheit	; convert value in lo:hi from celsius to fahrenheit
convert_celsius_to_fahrenheit:		; convert value in lo:hi from celsius to fahrenheit
	movff	lo,xA+0					; temperature in 1/10 of °C
	movff	hi,xA+1
	
	movlw	LOW  d'1000'			; offset °C value by 1000 to get out of any negative numbers
	addwf	xA+0,F
	movlw	HIGH d'1000'
	addwfc	xA+1,F

	movlw	d'18'					; adjust scaling: 1°C = 1.8°F
	movwf	xB+0
	clrf	xB+1

	call	mult16x16				; xA*xB=xC (lo:hi * 18)

	movlw	d'10'
	movwf	xB+0
	clrf	xB+1

	call	div32x16				; xC:4 / xB:2 = xC+3:xC+2 with xC+1:xC+0 as remainder

	movlw	LOW  d'1480'			; adjust offset: subtract above offset of 1000 * 1.8 = 1800 now and add 320 => subtract 1480
	subwf	xC+0,F
	movlw	HIGH d'1480'
	subwfb	xC+1,F

	movff	xC+0,lo
	movff	xC+1,hi					; restore lo and hi with updated value
	return

;=============================================================================

	END