;=============================================================================
;
;   File tft_outputs.asm                      next combined generation V3.09.1 fix
;
;   high-level Display Outputs
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;  2011-08-07 : [mH] moving from OSTC code

#include "hwos.inc"							; mandatory header
#include "shared_definitions.h"				; mailbox from/to p2_deco.c
#include "tft.inc"
#include "start.inc"
#include "strings.inc"
#include "convert.inc"
#include "varargs.inc"
#include "math.inc"
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
#include "gaslist.inc"
#include "rx_ops.inc"
#include "logbook.inc"


;---- external Functions -----------------------------------------------------

	extern	aa_wordprocessor
	extern	get_first_gas_to_WREG


;---- external Texts ---------------------------------------------------------

	extern	tFirmware
	extern	tFirmwareDate
	extern	tHardware
	extern	tSerial
	extern	tTotalDives
	extern	tBatteryV
	extern	tSensorC
	extern	tSensorD
	extern	tUptime
	extern	tPPO2MIN
	extern	tPPO2Max
	extern	tPPO2DECO
	extern	tbar

 IFDEF _ccr_pscr
	extern	tPPO2MINCC
 ENDIF

 IFDEF _rx_functions
	extern	tFirmware_rx
 ENDIF

 IFDEF _compass
	extern	tCalX,tCalY,tCalZ
 ENDIF


tft_out	CODE

;=============================================================================

	global	TFT_debug_output
TFT_debug_output:
 ifndef _debug_output
	return
 else
	btfsc	alt_layout_active			; alternative layout active?
	return								; YES - abort

;	WIN_TINY .100,.30					; surface mode: fits under the textual logo in the upper right corner
;	WIN_TINY  .35, .0					; dive    mode: fits to the right side of the depth label
	WIN_TINY   .0, .0					; dive    mode: overwrites depth label
	call	TFT_standard_color
	lfsr	FSR2,buffer

	; print an 16 bit integer as x.yy
	;MOVII	int_O_profiling_overrun,mpr
	;output_16dp .3
	;STRCAT_PRINT ""
	;return

	; deco engine scheduling performance
	MOVII	int_O_profiling_overrun,mpr		; runtime +/- versus target
	btfss	mpr+1,7
	bra		TFT_debug_output_1
	bcf		mpr+1,7
	PUTC	"-"
	bra		TFT_debug_output_2
TFT_debug_output_1:
	PUTC	" "
TFT_debug_output_2:
	output_16_3
	PUTC	"."
	MOVII	int_O_profiling_overrun_max,mpr		; max runtime
	output_16_3
	PUTC	"."
	movff	char_O_profiling_overrun_phase,WREG	; calculation phase causing the max runtime
	output_hex
	PUTC	"."
	movff	char_O_profiling_runs_norm,mpr		; runs/cycle normal plan
	output_99
	PUTC	"."
	movff	char_O_profiling_runs_alt,mpr		; runs/cycle alternative plan
	output_99
	STRCAT_PRINT ""
	return
 endif


;=============================================================================

	global	TFT_divemask_color
TFT_divemask_color:
	movlw	color_green
	btfsc	divemode					; in dive mode?
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


	global	TFT_memo_color
TFT_memo_color:							; information, values within normal range, things without a need to react upon
	movlw	color_white
	bra		TFT_standard_color0
TFT_memo_color_dive:
	retlw	color_white

	global	TFT_advice_color
TFT_advice_color:						; advices to do something, but without essential need to actually do it
	movlw	color_green
	bra		TFT_standard_color0
TFT_advice_color_dive:
	retlw	color_green

	global	TFT_attention_color			; important things to be aware of and things that are developing towards a warning
TFT_attention_color:
	movlw	color_yellow
	bra		TFT_standard_color0
TFT_attention_color_dive:
	retlw	color_yellow

	global	TFT_warning_color			; important things with immediate need to react upon
TFT_warning_color:
	movlw	color_red
	bra		TFT_standard_color0
TFT_warnings_color_dive:
	retlw	color_red


	global	TFT_disabled_color
TFT_disabled_color:
	movlw	color_lightblue
	btfsc	divemode					; in dive mode?
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
	setf	WREG						; default white
	btfsc	divemode					; in dive mode?
	rcall	TFT_standard_color_dive
	;bra	TFT_standard_color0
TFT_standard_color0:
	goto	TFT_set_color				; and return...


TFT_standard_color_dive:
	movff	opt_dive_color_scheme,WREG	; 0-3
	incf	WREG
	dcfsnz	WREG
	retlw	color_scheme_divemode_std1	; 0
	dcfsnz	WREG
	retlw	color_scheme_divemode_std2	; 1
	dcfsnz	WREG
	retlw	color_scheme_divemode_std3	; 2
	retlw	color_scheme_divemode_std4	; 3


	global	TFT_color_code_tank_pres_sac
TFT_color_code_tank_pres_sac:			; color-code a tank pressure or SAC rate, data in hi:lo
	btfss	hi,int_not_avail_flag		; is the not-available flag set?
	bra		TFT_color_code_tank_pres_1	; NO
	bcf		hi,int_not_avail_flag		; YES - clear not-available flag
TFT_color_code_tank_pres_0:				;       entry point for outdated flag
	bcf		hi,int_outdated_flag		;       clear outdated  flag (it may be set)
	bcf		hi,int_warning_flag			;       clear warning   flag (it may be set)
	bcf		hi,int_attention_flag		;       clear attention flag (it may be set)
	bra		TFT_disabled_color			;       set to disabled color and return
TFT_color_code_tank_pres_1:
	btfsc	hi,int_outdated_flag		; is the outdated flag set?
	bra		TFT_color_code_tank_pres_0	; YES - handle alike with not-available flag
TFT_color_code_tank_pres_2:
	btfss	hi,int_warning_flag			; is the warning flag set?
	bra		TFT_color_code_tank_pres_3	; NO
	bcf		hi,int_warning_flag			; YES - clear warning   flag
	bcf		hi,int_attention_flag		;     - clear attention flag (it may be set)
	bra		TFT_warning_color			;     - set to warning color and return
TFT_color_code_tank_pres_3:
	btfss	hi,int_attention_flag		; is the attention flag set?
	bra		TFT_memo_color				; NO  - set to memo color and return
	bcf		hi,int_attention_flag		; YES - clear attention flag
	bra		TFT_attention_color			;     - set to attention color and return


	global	TFT_color_code_gaslist
TFT_color_code_gaslist:					; color-code a gas (%O2 in hi) according to current absolute pressure
; Check very high ppO2 manually
	MOVII	pressure_abs_10,xA
	movff	hi,xB+0
	clrf	xB+1
	call	mult16x16					; hi * absolute pressure / 10
; Check if ppO2 > 6.55 bar
	tstfsz	xC+2						; char_I_O2_ratio * absolute pressure / 10 > 65536, i.e. ppO2 > 6.55 bar ?
	bra		TFT_warning_color			; YES - warn in warning color
; Check if ppO2 > 3.30 bar
	btfsc	xC+1,7
	bra		TFT_warning_color			; YES - warn in warning color
; Check for low ppO2
	MOVII	xC,sub_a
	movff	char_I_ppO2_min,WREG
	mullw	d'100'						; char_I_ppO2_min*100
	MOVII	PRODL,sub_b
	call	cmpU16						; compare (sub_a - sub_b)
	btfsc	neg_flag					; lower than ppO2 min?
	bra		TFT_warning_color			; YES - set warning color and return
; Check for high ppO2
	movff	char_O_deco_info,WREG		; bank-safe copy of deco info vector
	btfsc	WREG,deco_mode				; are we in deco?
	bra		TFT_color_code_gaslist_deco	; YES - check against ppO2 max deco only
										; NO  - check against ppO2 max travel/normal and deco
; Check for ppO2 max travel/normal
	movff	char_I_ppO2_max_work,WREG	; ppo2 max during working phase
	mullw	d'100'						; char_I_ppO2_max_work*100
	ADDLI	ppO2_margin_on_max,PROD		; add ppO2 margin on max value to compensate for surface pressures > 1000 hPa
	MOVII	PRODL,sub_b					; copy result to sub_b
	call	cmpU16						; compare (sub_a - sub_b)
	btfss	neg_flag					; higher than ppO2 max travel/deco?
	rcall	TFT_attention_color			; YES - set attention color
; Check for ppO2 max deco
TFT_color_code_gaslist_deco:
	movff	char_I_ppO2_max_deco,WREG	; ppo2 max for deco
	mullw	d'100'						; char_I_ppO2_max_deco * 100
	ADDLI	ppO2_margin_on_max,PROD		; add ppO2 margin on max value to compensate for surface pressures > 1000 hPa
	MOVII	PRODL,sub_b					; copy result to sub_b
	call	cmpU16						; compare (sub_a - sub_b)
	btfss	neg_flag					; higher than ppO2 max deco?
	bra		TFT_warning_color			; YES - set warning color and return
	return								; NO  - keep current color


TFT_color_code_ceiling:					; color-code the ceiling depth
	btfsc	hi,char_invalid_flag		; is the invalid flag set? (bit 7 here)
	bra		TFT_color_code_ceiling_1	; YES - set disabled color
	MOVII	pressure_rel_cur_cached,sub_a; NO - get current pressure to sub_a
	MOVII	mpr,sub_b					;     - get ceiling to sub_b
	call	cmpU16						;     - sub_a - sub_b = relative pressure [mbar] - int_O_ceiling [mbar]
	btfss	neg_flag					;     - is current depth < ceiling (too shallow) ?
	bra		TFT_memo_color				;       NO  - set to memo color and return
	movff	char_O_deco_warnings,WREG	;       YES - bank-safe copy of deco warnings
	btfsc	WREG,outside_warning		;           - are we currently outside of the ZH-L16 model?
	bra		TFT_warning_color			;             YES - set to warnings  color and return
	bra		TFT_attention_color			;             NO  - set to attention color and return
TFT_color_code_ceiling_1:
	bcf		hi,char_invalid_flag		; clear the invalid flag (bit 7 here)
	bra		TFT_disabled_color			; set to disabled color and return


TFT_color_code_stop:					; color-code the stop depth: memo      color if below stop depth,
										;                            attention color if above stop but below ceiling,
										;                            warning   color if above stop and ceiling
										;                            (ceiling depth is calculated using current GF)
	movff	char_O_deco_gas+0,WREG		; get flag for invalid deco data
	btfsc	WREG,char_invalid_flag		; is the invalid flag set?
	bra		TFT_disabled_color			; YES - set to disabled color and return
	movff	char_O_deco_depth+0,WREG	; NO  - get depth of first stop in meters into WREG
	subwf	depth_meter,W				;     - compute current depth - stop depth
	btfsc	STATUS,C					;     - result negative?
	bra		TFT_color_code_stop_1		;       NO  - not shallower than stop depth, check for ascent advice
	MOVII	int_O_ceiling,sub_b			;       YES - get ceiling depth in mbar
	btfsc	sub_b+1,char_invalid_flag	;           - is the invalid flag set? (bit 7 here)
	bra		TFT_warning_color			;             YES - set to warning color and return
	MOVII	pressure_rel_cur_cached,sub_a;            NO  - get current pressure
	call	cmpU16						;                 - sub_a - sub_b = relative pressure - int_O_ceiling
	btfsc	neg_flag					;                 - is ceiling > current depth?
	bra		TFT_warning_color			;                   YES - set to warning   color and return
	bra		TFT_attention_color			;                   NO  - set to attention color and return
TFT_color_code_stop_1:
	movff	char_O_deco_depth+0,WREG	; get depth of first stop in meters into WREG
	incf	WREG,W						; compute stop depth + 1 meter
	subwf	depth_meter,W				; compute current depth - (first stop depth + 1 meter)
	btfss	STATUS,C					; result negative?
	bra		TFT_memo_color				; YES - within 1 meter of stop depth, use memo color
	btfss	deco_region					; NO  - within deco stops region?
	bra		TFT_memo_color				;       NO  - use memo color
	bsf		win_invert					;       YES - give ascent advice, ...
	bra		TFT_advice_color			;           - ... and return


TFT_color_code_depth:
	TSTOSS	opt_depth_warn				; depth warning switched on?
	bra		TFT_color_code_depth_no_mod	; NO
	btfsc	depth_limit_exceeded		; YES - deeper than depth limit?
	bra		TFT_color_code_depth_warn	;       YES - set to warning color
	bra		TFT_color_code_depth_mod	;       NO  - check depth against MOD and return...
TFT_color_code_depth_no_mod:
	btfsc	depth_limit_exceeded		; NO  - deeper than depth limit?
	bra		TFT_warning_color			;       YES - set to warning color and return
	bra		TFT_memo_color				;       NO  - set to memo    color and return...
TFT_color_code_depth_mod:
 IFDEF _ccr_pscr
	movff	opt_dive_mode,WREG			; get deco mode: 0=OC, 1=CC, 2=Gauge, 3=Apnea, 4=PSCR
	decfsz	WREG,F						; in CCR mode?
	bra		TFT_color_code_depth_no_ccr	; NO  - continue checking for ppO2
	btfss	bailout_mode				; YES - check if in bailout
	bra		TFT_color_code_depth_outside;       NO  - continue checking for outside ZHL16 model
 ENDIF
TFT_color_code_depth_no_ccr:
	movff	int_O_breathed_ppO2+1,WREG	; get upper byte of currently breathed ppO2
	btfsc	WREG,int_warning_flag		; is the warning flag set?
	bra		TFT_color_code_depth_warn	; YES - animate in warning design
TFT_color_code_depth_outside:
	movff	char_O_deco_warnings,WREG	; bank-safe copy of deco warnings
	btfsc	WREG,outside_warning		; are we currently outside of the ZH-L16 model?
	bra		TFT_color_code_depth_warn	; YES - activate  depth warning
	bcf		depth_warning				; NO  - terminate depth warning
	btfsc	WREG,outside_attention		;     - are we near to outside of the ZH-L16 model?
	bra		TFT_color_code_depth_att	;       YES - activate  depth attention
	bcf		depth_attention				;       NO  - terminate depth attention
	bra		TFT_memo_color				;           - select memo color and return
TFT_color_code_depth_warn:
	bsf		depth_warning				; activate depth warning
	bra		TFT_warning_color			; select warning color and return...
TFT_color_code_depth_att:
	bsf		depth_attention				; activate depth attention
	bra		TFT_attention_color			; select attention color and return...


	global	TFT_color_code_cns
TFT_color_code_cns:						; color-code CNS values (CNS in hi:lo [%])
	btfss	hi,int_invalid_flag			; is the invalid flag set?
	bra		TFT_color_code_cns_1		; NO
	bcf		hi,int_invalid_flag			; YES - clear invalid flag
	bcf		hi,int_warning_flag			;       clear warning   flag (it may be set)
	bcf		hi,int_attention_flag		;       clear attention flag (it may be set)
	bra		TFT_disabled_color			;       set to disabled color and return
TFT_color_code_cns_1:
	btfss	hi,int_warning_flag			; is the warning flag set?
	bra		TFT_color_code_cns_2		; NO
	bcf		hi,int_warning_flag			; YES - clear warning   flag
	bcf		hi,int_attention_flag		;     - clear attention flag (it may be set)
	bra		TFT_warning_color			;     - set to warning color and return
TFT_color_code_cns_2:
	btfss	hi,int_attention_flag		; is the attention flag set?
	bra		TFT_memo_color				; NO  - set to memo color and return
	bcf		hi,int_attention_flag		; YES - clear attention flag
	bra		TFT_attention_color			;     - set to attention color and return


TFT_color_code_gf:
	; with int_O_lead_supersat, the upper byte is solely used for the flags
	; and not for the value, thus there is no need to clear the flags
	btfsc	hi,int_invalid_flag			; is the invalid flag set?
	bra		TFT_disabled_color			; YES - set to disabled color and return
	btfsc	hi,int_warning_flag			; NO  - is the warning flag set?
	bra		TFT_warning_color			;       YES - set to warning color and return
	btfsc	hi,int_attention_flag		;       NO  - is the attention flag set?
	bra		TFT_attention_color			;             YES - set to attention color and return
	bra		TFT_memo_color				;             NO  - set to memo      color and return


TFT_color_code_ppo2:					; color-code ppO2 values (ppO2 in hi:lo [cbar]) by its warning flags
	btfss	hi,int_warning_flag			; is the warning flag set?
	bra		TFT_color_code_ppo2_1		; NO
	bcf		hi,int_warning_flag			; YES - clear warning flag
	bcf		hi,int_attention_flag		;       clear attention    flag (it may be set)
	bcf		hi,int_high_flag			;       clear high warning flag (it may be set)
	bcf		hi,int_low_flag				;       clear low  warning flag (it may be set)
	bra		TFT_warning_color			;       warn in warning color
TFT_color_code_ppo2_1:
	btfss	hi,int_attention_flag		; is the attention flag set?
	bra		TFT_color_code_ppo2_2		; NO
	bcf		hi,int_attention_flag		; YES - clear attention    flag (it may be set)
	bcf		hi,int_high_flag			;       clear high warning flag (it may be set)
	bcf		hi,int_low_flag				;       clear low  warning flag (it may be set)
	bra		TFT_attention_color			;       set to attention color and return
TFT_color_code_ppo2_2:
	bcf		hi,int_high_flag			; clear high warning flag (it may be set)
	bcf		hi,int_low_flag				; clear low  warning flag (it may be set)
	bra		TFT_memo_color				; set to memo color and return

;=============================================================================

 IFDEF _ccr_pscr

TFT_color_code_ppo2_hud:				; color-code ppO2 values (ppO2 in --:lo [cbar]) by its value
	movff	char_O_deco_info,WREG		; get the deco info vector
	btfss	WREG,deco_mode				; are we in deco?
	bra		TFT_color_code_ppo2_hud_a	; NO  - load normal max value as threshold
	movff	char_I_ppO2_max_deco,WREG	; YES - load deco value as threshold
	bra		TFT_color_code_ppo2_hud_b
TFT_color_code_ppo2_hud_a:
	movff	char_I_ppO2_max_work,WREG	; ppO2 max while in working phase
TFT_color_code_ppo2_hud_b:
	cpfsgt	lo							; lo > threshold?
	bra		TFT_color_code_ppo2_hud1	; NO  - continue with checking for ppO2 low
	bra		TFT_warning_color			; YES - set warning color and return
TFT_color_code_ppo2_hud1:
	movff	opt_dive_mode,WREG			; 0=OC, 1=CC, 2=Gauge, 3=Apnea, 4=PSCR
	decfsz	WREG,F						; now:  0=CC, 1=Gauge, 2=Apnea, 3=PSCR
	bra		TFT_color_code_ppo2_hud_nocc; not CCR...
	btfsc	bailout_mode
	bra		TFT_color_code_ppo2_hud_nocc; is bailout, hence not loop mode...
	movff	char_I_ppO2_min_loop,WREG	; ppO2 min loop mode color coding
	bra		TFT_color_code_ppo2_hud_cont
TFT_color_code_ppo2_hud_nocc:
	movff	char_I_ppO2_min,WREG		; PPO2 min for all other modes
TFT_color_code_ppo2_hud_cont:
	cpfslt	lo							; lo < char_I_ppO2_min?
	bra		TFT_memo_color				; NO  - set memo    color and return...
	bra		TFT_warning_color			; Yes - set warning color and return

 ENDIF	; _ccr_pscr

;=============================================================================

TFT_color_code_battery:					; color-code the battery display, with battery percent in lo
	btfsc	battery_low_condition		; battery low condition detected?
	bra		TFT_warning_color			; YES - set to warning color and return
	bra		TFT_memo_color				; NO  - set to memo    color and return


	global	TFT_color_code_gas
TFT_color_code_gas:						; color-code the output according to gas number (1-6) in WREG
	movwf	up							; copy gas number (1-6) to up
	movlw	color_white					; Default color
	dcfsnz	up,F
	movlw	color_white					; color for gas 1
	dcfsnz	up,F
	movlw	color_green					; color for gas 2
	dcfsnz	up,F
	movlw	color_red					; color for gas 3
	dcfsnz	up,F
	movlw	color_yellow				; color for gas 4
	dcfsnz	up,F
	movlw	color_cyan					; color for gas 5
	dcfsnz	up,F
	movlw	color_pink					; color for gas 6
	goto	TFT_set_color				; set color...


; ****************************************************************************

	global	TFT_show_OC_startgas_surface
TFT_show_OC_startgas_surface:			; show first gas and "OSTC2-like" active gases
	; Show first gas
	WIN_SMALL surf_decotype_column+.1,surf_decotype_row+.30
	call	get_first_gas_to_WREG		; get first gas (1-5) into WREG
	decf	WREG,W						; 1-5 -> 0-4
	movwf	PRODL
	call	gaslist_strcat_gas			; input: PRODL : gas number (0..4), Output: Text appended into buffer pointed by FSR2.
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
	bra		DISP_active_gas_surfmode3	; NO - skip box
	WIN_FRAME_STD surf_decotype_boxes_top, surf_decotype_boxes_bottom, surf_decotype_boxes_left1, surf_decotype_boxes_left1+.8	;top, bottom, left, right
DISP_active_gas_surfmode3:
	rcall	TFT_disabled_color
	movff	opt_gas_type+1,hi			; 0=Disabled, 1=First, 2=Travel, 3=Deco
	tstfsz	hi
	rcall	TFT_standard_color
	WIN_LEFT surf_decotype_boxes_left2+.1
	STRCPY_PRINT "2"
	decfsz	hi,F						; Type = 1 (First)?
	bra		DISP_active_gas_surfmode4	; NO - skip box
	WIN_FRAME_STD surf_decotype_boxes_top, surf_decotype_boxes_bottom, surf_decotype_boxes_left2, surf_decotype_boxes_left2+.8	;top, bottom, left, right
DISP_active_gas_surfmode4:
	rcall	TFT_disabled_color
	movff	opt_gas_type+2,hi			; 0=Disabled, 1=First, 2=Travel, 3=Deco
	tstfsz	hi
	rcall	TFT_standard_color
	WIN_LEFT surf_decotype_boxes_left3+.1
	STRCPY_PRINT "3"
	decfsz	hi,F						; Type = 1 (First)?
	bra		DISP_active_gas_surfmode5	; NO - skip box
	WIN_FRAME_STD surf_decotype_boxes_top, surf_decotype_boxes_bottom, surf_decotype_boxes_left3, surf_decotype_boxes_left3+.8	;top, bottom, left, right
DISP_active_gas_surfmode5:
	rcall	TFT_disabled_color
	movff	opt_gas_type+3,hi			; 0=Disabled, 1=First, 2=Travel, 3=Deco
	tstfsz	hi
	rcall	TFT_standard_color
	WIN_LEFT surf_decotype_boxes_left4+.1
	STRCPY_PRINT "4"
	decfsz	hi,F						; Type = 1 (First)?
	bra		DISP_active_gas_surfmode6	; NO - skip box
	WIN_FRAME_STD surf_decotype_boxes_top, surf_decotype_boxes_bottom, surf_decotype_boxes_left4, surf_decotype_boxes_left4+.8	;top, bottom, left, right
DISP_active_gas_surfmode6:
	rcall	TFT_disabled_color
	movff	opt_gas_type+4,hi			; 0=Disabled, 1=First, 2=Travel, 3=Deco
	tstfsz	hi
	rcall	TFT_standard_color
	WIN_LEFT surf_decotype_boxes_left5+.1
	STRCPY_PRINT "5"
	rcall	TFT_standard_color			; reset color
	decfsz	hi,F						; type = 1 (First)?
	bra		DISP_active_gas_surfmode7	; NO - done
	WIN_FRAME_STD surf_decotype_boxes_top, surf_decotype_boxes_bottom, surf_decotype_boxes_left5, surf_decotype_boxes_left5+.8	;top, bottom, left, right
DISP_active_gas_surfmode7:
	return								; done


	global	TFT_show_color_schemes
TFT_show_color_schemes:					; update the color schemes
	bsf		divemode					; switch to dive mode
	call	TFT_divemask_color
	WIN_TINY .12,.40
	STRCAT_TEXT_PRINT tDepth
	WIN_TINY .62,.40
	STRCAT_TEXT_PRINT tMaxDepth
	WIN_TINY .122,.40
	STRCAT_TEXT_PRINT tDivetime

	; Show some demo screen

	; Depth demo
	call	TFT_memo_color
	WIN_MEDIUM .3,.54
	MOVLI	.5172,mpr
	bsf		leftbind
	bsf		ignore_digit4
	output_16							; full meters in big font
	bcf		leftbind
	STRCAT_PRINT ""						; display full meters
	WIN_SMALL .25,.66
	MOVLI	.5172,mpr
	PUTC	"."
	movlw	d'4'
	movwf	ignore_digits
	bsf		ignore_digit5				; (flag will be cleared by output_16)
	output_16dp d'0'					; .1m in SMALL font
	STRCAT_PRINT ""						; display decimeters

	; Max. Depth demo
	WIN_MEDIUM .64,.54
	bsf		ignore_digit4				; no 0.1 m
	bsf		leftbind
	MOVLI	.6349,mpr
	output_16
	STRCAT_PRINT ""						; display full meters
	bcf		leftbind
	; .1m in SMALL font
	WIN_SMALL .87,.66
	PUTC	"."
	movlw	d'4'
	movwf	ignore_digits
	bsf		ignore_digit5				; (flag will be cleared by output_16)
	bsf		leftbind
	MOVLI	.6349,mpr
	output_16dp d'0'
	STRCAT_PRINT ""						; display decimeters
	bcf		leftbind

	; Divetime demo
	SMOVSS	rtc_year,rtc_latched_year	; ISR-safe 6 byte copy of date and time
	movff	rtc_latched_mins,lo
	clrf	hi
	WIN_MEDIUM .103, .54
	output_16_3							; limit to 999 and display only (0-999)
	STRCAT_PRINT ""						; show minutes in large font
	WIN_SMALL .139, .66					; left position for two sec figures
	PUTC	':'
	bsf		leftbind
	movff	rtc_latched_secs,lo
	output_99x
	bcf		leftbind
	STRCAT_PRINT ""						; show seconds in small font

	bcf		divemode					; terminate dive mode again
	return


	global	TFT_show_divemode_mask
TFT_show_divemode_mask:										; display mask in dive mode
	call	TFT_divemask_color								; set color

	; depth
	WIN_TINY dm_mask_depth_column,dm_mask_depth_row			; position for "Depth"
	btfss	alt_layout_active								; alternative layout active?
	bra		TFT_divemode_mask_depth_text					; NO
	WIN_TINY dm_mask_depth_column_alt,dm_mask_depth_row		; YES - alternative position for "Depth"
TFT_divemode_mask_depth_text:
	STRCAT_TEXT_PRINT tDepth								; print "Depth"

	; avg or max depth
	btfsc	alt_layout_active								; alternative layout active?
	bra		TFT_divemode_mask_avg_max_alt					; YES

	WIN_TINY dm_mask_maxdepth_col_nvsi,dm_mask_maxdepth_row ; default position for "max.Depth"/"avg.Depth"
	TSTOSS	opt_vsigraph									; graphical VSI bar enabled?
	bra		TFT_divemode_mask_max_avg_pos					; NO  - keep  position
	WIN_TINY dm_mask_maxdepth_col,dm_mask_maxdepth_row		; YES - adopt position
TFT_divemode_mask_max_avg_pos:
	btfsc	FLAG_apnoe_mode									; in apnea mode?
	bra		TFT_divemode_mask_max_text						; YES - always draw max depth
	TSTOSS	opt_2ndDepthDisp								; NO  - shall draw avg depth instead of max depth?
	bra		TFT_divemode_mask_max_text						;       NO  - print "max.Depth"
	STRCAT_TEXT_PRINT tAvgDepth								;       YES - print "avg.Depth"
	bra		TFT_divemode_mask_time_pos						;           - continue with dive time
TFT_divemode_mask_max_text:
	STRCAT_TEXT_PRINT tMaxDepth								; print "max.Depth"
	bra		TFT_divemode_mask_time_pos						; continue with dive time
TFT_divemode_mask_avg_max_alt:
	btfss	FLAG_gauge_mode												; in gauge mode?
	bra		TFT_divemode_mask_time_pos									; NO  - continue with dive time
	WIN_TINY dm_gauge_max_depth_text_col,dm_gauge_max_depth_text_row	; YES - set position
	STRCAT_TEXT_PRINT tMaxDepth											;     - print "max.Depth"
	WIN_TINY dm_gauge_avg_depth_text_col,dm_gauge_avg_depth_text_row	;     - set position
	STRCAT_TEXT_PRINT tDiveTotalAvg										;     - print "Total Avg"
	;bra	TFT_divemode_mask_time_pos									;     - continue with dive time

	; dive time
TFT_divemode_mask_time_pos:
	WIN_TINY dm_mask_divetime_column,dm_mask_divetime_row	; position for "Divetime"
TFT_divemode_mask_time_text:
	STRCAT_TEXT_PRINT tDivetime								; print "Divetime"
	btfss	FLAG_apnoe_mode									; in apnea mode?
	bra		TFT_standard_color								; NO  - done
	WIN_TINY dm_total_apnoe_text_col,dm_total_apnoe_text_row; YES - set position
	STRCPY_TEXT_PRINT tApnoeTotal							;     - print "Total"
	bra		TFT_standard_color								;     - done

;=========================================================================

	global	TFT_velocity_show
TFT_velocity_show:
	rcall	TFT_memo_color				; set default color
	btfsc	neg_flag_velocity			; descending?
	rcall	TFT_velocity_set_color		; NO - set color for text dependent on speed and set threshold for VSI graph
	rcall	TFT_velocity_num			; show the numerical VSI
	TSTOSS	opt_vsigraph				; graphical VSI bar enabled?
	bra		TFT_standard_color			; NO  - done
	btfsc	neg_flag_velocity			; YES - in ascent?
	bra		TFT_velocity_graph_show		;       YES - show  the graph
	bra		TFT_velocity_graph_clear_1	;       NO  - clear the graph

TFT_speed_table:
	; use a depth-dependent ascent rate warning
	; depth(ft):     <20 >20 >40 >60 >75 >88 >101 >115 >128 >144 >164
	; speed(ft/min):  23  26  29  33  36  43   49   56   59   62   66
	; depth(m):      <=6  >6 >12 >18 >23 >27  >31  >35  >39  >44  >50
	; speed(m/min):    7   8   9  10  11  13   15   17   18   19   20 (warning)
	; speed(m/min):    5   6   7   8   8  10   12   13   14   15   15 (attention)

	; < depth (m), warning speed, attention speed, unused
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

TFT_velocity_set_color:						; set color based on speed table or use static thresholds, with divA+0 = m/min
	bsf		aux_flag						; for alternative layout: default is to show numerical VSI
	; check if old/new ascend logic is used
	TSTOSS	opt_vsitext						; 0=standard, 1=dynamic
	bra		TFT_velocity_set_color_static	; static ascend rate limit

	; point to speed table
	movlw	LOW   (TFT_speed_table-.3)
	movwf	TBLPTRL
	movlw	HIGH  (TFT_speed_table-.3)
	movwf	TBLPTRH
	movlw	UPPER (TFT_speed_table-.3)
	movwf	TBLPTRU

TFT_velocity_set_color_next:
	TBLRD*+									; 3 dummy reads
	TBLRD*+
	TBLRD*+
	TBLRD*+									; get speed threshold
	movf	depth_meter,W					; current depth in m
	cpfsgt	TABLAT							; threshold > current depth ?
	bra		TFT_velocity_set_color_next		; NO - try next

	TBLRD*+									; get warning speed threshold
	movf	TABLAT,W						; ...
	movwf	divA+1							; copy for graph routine
	cpfslt	divA+0							; actual vertical speed smaller than warning threshold?
	bra		TFT_warning_color				; NO - set warning color (and return)
	TBLRD*+									; get attention speed threshold
	movf	TABLAT,W						; ...
	cpfslt	divA+0							; actual vertical speed smaller than attention threshold?
	bra		TFT_attention_color				; NO  - set attention color and return
	bcf		aux_flag						; YES - don't show in alternative layout
	bra		TFT_memo_color					;     - set memo color and return

TFT_velocity_set_color_static:
	movlw	color_code_velocity_warn_high	; threshold for warning in m/min
	movwf	divA+1							; copy for graph routine
	cpfslt	divA+0							; actual vertical speed smaller than warning threshold?
	bra		TFT_warning_color				; NO - set warning color (and return)
	movlw	color_code_velocity_attn_high	; threshold for attention in m/min
	cpfslt	divA+0							; actual vertical speed smaller than attention threshold?
	bra		TFT_attention_color				; NO  - set attention color and return
	bcf		aux_flag						; YES - don't show in alternative layout
	bra		TFT_memo_color					;     - set memo color and return

TFT_velocity_num:
	btfsc	alt_layout_active				; in alternative layout?
	bra		TFT_velocity_num_alt			; YES
											; NO  - set position
	WIN_SMALL dm_velocity_text_col_norm, dm_velocity_text_row_norm
TFT_velocity_num_com:
	bsf		velocity_active_num				; set numerical velocity as shown
	TSTOSS	opt_units						;     - 0=meter, 1=feet
	bra		TFT_velocity_num_metric			;       0 - meter
	;bra	TFT_velocity_num_imperial		;       1 - feet

TFT_velocity_num_imperial:
	movff	divA+0,WREG						; divA+0 = m/min
	mullw	.100							; PROD   = mbar/min
	MOVII	PRODL,mpr						; copy to hi:lo
	call	convert_cm_to_feet				; convert value in hi:lo from [cm] to [feet]
	tstfsz	hi								; > 255 ?
	setf	lo								; YES - set lo to 255
	movlw	'-'								; load coding for minus sign
	btfsc	neg_flag_velocity				; ascending?
	movlw	'+'								; YES - replace with coding for plus sign
	movwf	POSTINC2						; put sign into output buffer
	output_99								; print rate
	STRCAT_TEXT tVelImperial				; print unit
	bra		TFT_velocity_num_finish			; do finishing tasks

TFT_velocity_num_metric:
	movff	divA+0,lo						; divA+0 = m/min
	movlw	'-'								; load coding for minus sign
	btfsc	neg_flag_velocity				; ascending?
	movlw	'+'								; YES - replace with coding for plus sign
	movwf	POSTINC2						; put sign into output buffer
	output_99								; print rate
	STRCAT_TEXT tVelMetric					; print unit
	;bra	TFT_velocity_num_finish			; do finishing tasks

TFT_velocity_num_finish:
	btfss	alt_layout_active				; in alternative layout?
	bra		TFT_velocity_num_finish_1		; NO
	movlw	"'"								; load encoding of minute sign
	movff	WREG,buffer+4					; put it after m (meter) / f (feet)
	clrf	WREG							; load string terminator
	movff	WREG,buffer+5					; terminate string after minute sign
TFT_velocity_num_finish_1:
	STRCAT_PRINT ""							; finalize output
	bcf		win_invert						; end inverse printing
	return									; done

TFT_velocity_num_alt:
	btfsc	dive_main_menu					; is the dive mode menu shown?
	return									; YES - abort
	btfss	neg_flag_velocity				; NO  - in ascent?
	bcf		aux_flag						;       NO  - clear aux flag
	btfsc	aux_flag						;     - above attention or warning threshold?
	bsf		win_invert						;       YES - print inverse
											;     - set position
	WIN_SMALL dm_velocity_text_col_alt, dm_velocity_text_row_alt
	bra		TFT_velocity_num_com			;     - continue with common part


TFT_velocity_graph_show:					; with speed in divA+0 (m/min)
	btfsc	alt_layout_active				; in alternative layout?
	bra		TFT_standard_color				; YES - done (not implemented)

	btfsc	velocity_active_vsi				; was the graphical VSI shown before?
	bra		TFT_velocity_graph_1			; YES - no need to redraw the framework box
	bsf		velocity_active_vsi				; NO  - remember it is shown as of now
											;     - draw the framework box
	rcall	TFT_divemask_color_dive			;     - color -> WREG
	WIN_FRAME_COLOR	dm_velocity_graph_top+.00, dm_velocity_graph_bot-.00, dm_velocity_graph_lft, dm_velocity_graph_rgt
	rcall	TFT_divemask_color_dive			;     - color -> WREG
	WIN_FRAME_COLOR	dm_velocity_graph_top+.10, dm_velocity_graph_bot-.10, dm_velocity_graph_lft, dm_velocity_graph_rgt
	rcall	TFT_divemask_color_dive			;     - color -> WREG
	WIN_FRAME_COLOR	dm_velocity_graph_top+.20, dm_velocity_graph_bot-.20, dm_velocity_graph_lft, dm_velocity_graph_rgt
	rcall	TFT_divemask_color_dive			;     - color -> WREG
	WIN_FRAME_COLOR	dm_velocity_graph_top+.30, dm_velocity_graph_bot-.30, dm_velocity_graph_lft, dm_velocity_graph_rgt

TFT_velocity_graph_1:
	movff	divA+0,hi						; copy ascend speed (in m/min) to hi
	movff	divA+1,xA+0						; m/min for warning level (upper two blocks)
	clrf	xA+1
	MOVLI	.5,xB							; threshold for color warning (5 color normal + 2 color warning)
	call	div16x16						; xC = xA / xB with xA as remainder
	; xC+0 holds step size in m/min (e.g. =3 for 15m/min warning threshold)
	movff	hi,xA+0							; velocity in m/min
	clrf	xA+1
	movff	xC+0,xB+0						; step size
	clrf	xB+1
	call	div16x16						; xC = xA / xB with xA as remainder

	movff	xC+0,lo							; copy amount of segments to show to lo
	incf	lo,F
	dcfsnz	lo,F
	bra		DISP_graph_vel_0_fill
	dcfsnz	lo,F
	bra		DISP_graph_vel_1_fill
	dcfsnz	lo,F
	bra		DISP_graph_vel_2_fill
	dcfsnz	lo,F
	bra		DISP_graph_vel_3_fill
	dcfsnz	lo,F
	bra		DISP_graph_vel_4_fill
	dcfsnz	lo,F
	bra		DISP_graph_vel_5_fill
	dcfsnz	lo,F
	bra		DISP_graph_vel_6_fill
	;bra	DISP_graph_vel_7_fill

DISP_graph_vel_7_fill:
	rcall	TFT_warnings_color_dive		; color -> WREG
	WIN_BOX_COLOR dm_velocity_graph_top+.2,  dm_velocity_graph_top+.8,  dm_velocity_graph_lft+.2, dm_velocity_graph_rgt-.2 ;top, bottom, left, right
DISP_graph_vel_6_fill:
	rcall	TFT_warnings_color_dive		; color -> WREG
	WIN_BOX_COLOR dm_velocity_graph_top+.12, dm_velocity_graph_top+.18, dm_velocity_graph_lft+.2, dm_velocity_graph_rgt-.2 ;top, bottom, left, right
DISP_graph_vel_5_fill:
	rcall	TFT_attention_color_dive	; color -> WREG
	WIN_BOX_COLOR dm_velocity_graph_top+.22, dm_velocity_graph_top+.28, dm_velocity_graph_lft+.2, dm_velocity_graph_rgt-.2 ;top, bottom, left, right
DISP_graph_vel_4_fill:
	rcall	TFT_standard_color_dive		; color -> WREG
	WIN_BOX_COLOR dm_velocity_graph_top+.32, dm_velocity_graph_top+.38, dm_velocity_graph_lft+.2, dm_velocity_graph_rgt-.2 ;top, bottom, left, right
DISP_graph_vel_3_fill:
	rcall	TFT_standard_color_dive		; color -> WREG
	WIN_BOX_COLOR dm_velocity_graph_top+.42, dm_velocity_graph_top+.48, dm_velocity_graph_lft+.2, dm_velocity_graph_rgt-.2 ;top, bottom, left, right
DISP_graph_vel_2_fill:
	rcall	TFT_standard_color_dive		; color -> WREG
	WIN_BOX_COLOR dm_velocity_graph_top+.52, dm_velocity_graph_top+.58, dm_velocity_graph_lft+.2, dm_velocity_graph_rgt-.2 ;top, bottom, left, right
DISP_graph_vel_1_fill:
	rcall	TFT_standard_color_dive		; color -> WREG
	WIN_BOX_COLOR dm_velocity_graph_top+.62, dm_velocity_graph_top+.68, dm_velocity_graph_lft+.2, dm_velocity_graph_rgt-.2 ;top, bottom, left, right
DISP_graph_vel_0_fill:

	movff	xC+0,lo							; copy amount of segments to show to lo
	incf	lo,F
	dcfsnz	lo,F
	bra		DISP_graph_vel_0_clear
	dcfsnz	lo,F
	bra		DISP_graph_vel_1_clear
	dcfsnz	lo,F
	bra		DISP_graph_vel_2_clear
	dcfsnz	lo,F
	bra		DISP_graph_vel_3_clear
	dcfsnz	lo,F
	bra		DISP_graph_vel_4_clear
	dcfsnz	lo,F
	bra		DISP_graph_vel_5_clear
	dcfsnz	lo,F
	bra		DISP_graph_vel_6_clear
	bra		DISP_graph_vel_7_clear

DISP_graph_vel_0_clear:
	WIN_BOX_BLACK dm_velocity_graph_top+.62, dm_velocity_graph_top+.68, dm_velocity_graph_lft+.2, dm_velocity_graph_rgt-.2 ;top, bottom, left, right
DISP_graph_vel_1_clear:
	WIN_BOX_BLACK dm_velocity_graph_top+.52, dm_velocity_graph_top+.58, dm_velocity_graph_lft+.2, dm_velocity_graph_rgt-.2 ;top, bottom, left, right
DISP_graph_vel_2_clear:
	WIN_BOX_BLACK dm_velocity_graph_top+.42, dm_velocity_graph_top+.48, dm_velocity_graph_lft+.2, dm_velocity_graph_rgt-.2 ;top, bottom, left, right
DISP_graph_vel_3_clear:
	WIN_BOX_BLACK dm_velocity_graph_top+.32, dm_velocity_graph_top+.38, dm_velocity_graph_lft+.2, dm_velocity_graph_rgt-.2 ;top, bottom, left, right
DISP_graph_vel_4_clear:
	WIN_BOX_BLACK dm_velocity_graph_top+.22, dm_velocity_graph_top+.28, dm_velocity_graph_lft+.2, dm_velocity_graph_rgt-.2 ;top, bottom, left, right
DISP_graph_vel_5_clear:
	WIN_BOX_BLACK dm_velocity_graph_top+.12, dm_velocity_graph_top+.18, dm_velocity_graph_lft+.2, dm_velocity_graph_rgt-.2 ;top, bottom, left, right
DISP_graph_vel_6_clear:
	WIN_BOX_BLACK dm_velocity_graph_top+.2,  dm_velocity_graph_top+.8,  dm_velocity_graph_lft+.2, dm_velocity_graph_rgt-.2 ;top, bottom, left, right
DISP_graph_vel_7_clear:
	bra		TFT_standard_color			; done


	global	TFT_velocity_clear
TFT_velocity_clear:
	btfss	velocity_active_num			; was the numerical VSI shown in last cycle?
	bra		TFT_velocity_clear_graph	; NO  - no need to clear it, continue with graphical VSI
TFT_velocity_clear_num_1:
	bcf		velocity_active_num			; YES - clear flag
	btfsc	alt_layout_active			;     - in alternative layout?
	bra		TFT_velocity_clear_num_alt	;       YES
	;bra	TFT_velocity_clear_num_norm	;       NO

TFT_velocity_clear_num_norm:			; clear normal numerical area
	WIN_BOX_BLACK dm_velocity_text_row_norm, dm_velocity_text_bot_norm, dm_velocity_text_col_norm, dm_velocity_text_rgt_norm ; top, bottom, left, right
	bra		TFT_velocity_clear_graph	; continue with graphical VSI

TFT_velocity_clear_num_alt:				; clear alternative numerical area
	btfsc	dive_main_menu				; is the dive mode menu shown?
	bra		TFT_velocity_clear_graph	; YES - skip
										; NO  - clear area
	WIN_BOX_BLACK dm_velocity_text_row_alt,  dm_velocity_text_bot_alt,  dm_velocity_text_col_alt,  dm_velocity_text_rgt_alt  ; top, bottom, left, right
	;bra	TFT_velocity_clear_graph	; continue with graphical VSI

TFT_velocity_clear_graph:
	btfss	velocity_active_vsi			; was the graphical VSI shown in last cycle?
	bra		TFT_standard_color			; NO  - no need to clear it, done
TFT_velocity_graph_clear_1:
	bcf		velocity_active_vsi			; YES - clear flag
	btfsc	alt_layout_active			;     - in alternative layout?
	bra		TFT_standard_color			;       YES - not implemented
	;bra	TFT_velocity_clear_graph_alt  ;     YES - code provision for future implementation
	;bra	TFT_velocity_clear_graph_norm ;     NO

TFT_velocity_clear_graph_norm			; clear normal graph area
	WIN_BOX_BLACK dm_velocity_graph_top, dm_velocity_graph_bot, dm_velocity_graph_lft, dm_velocity_graph_rgt ; top, bottom, left, right
	bra		TFT_standard_color			; done

;=========================================================================

	global	TFT_clear_divemode_menu
TFT_clear_divemode_menu:
	WIN_BOX_BLACK	dm_menu_row-.2, dm_menu_lower, dm_menu_left, dm_menu_right			; top, bottom, left, right - starts 2 pixel higher to completely wipe away the temperature display
	return


	global	TFT_clear_deco_data
TFT_clear_deco_data:
	btfsc	dive_main_menu				; is the dive mode menu shown?
	return								; YES - abort
										; NO  - clear deco data area (alternative stop depth makes upper-left most corner)
	WIN_BOX_BLACK dm_decostop_row_alt_depth, dm_3rdrow_bot, dm_decostop_col_alt_depth, dm_3rdrow_rgt	; top, bottom, left, right
	return								;     - done


	global	TFT_show_ndl_mask
TFT_show_ndl_mask:
	btfsc	dive_main_menu				; is the dive mode menu shown?
	return								; YES - abort
	call	TFT_divemask_color			; NO  - set text color
										;     - set position
	WIN_STD dm_ndl_text_column, dm_ndl_text_row
	STRCPY_TEXT_PRINT tNDL				;     - print "NDL"
	btfss	deco_region					;     - was the dive within deco stops region?
	bra		TFT_standard_color			;       NO  - done
	btfsc	safety_stop_active			;       YES - safety stop shown?
	bra		TFT_standard_color			;             YES - done
TFT_show_slow_reminder:
	call	TFT_attention_color			;             NO  - set color
										;                 - set position
	WIN_STD dm_safetystop_text_column+.5,dm_safetystop_text_row+.5
	STRCPY_TEXT  tSlow					;                 - print "SLOW" reminder
	STRCAT_PRINT 0x94					;                 - append an up-arrow
	bra		TFT_standard_color			;                 - done


	global	TFT_show_tts
TFT_show_tts:
	btfsc	dive_main_menu				; is the dive mode menu shown?
	return								; YES - abort
	call	TFT_memo_color				; NO  - default to memo color
	MOVII	int_O_TTS_norm,mpr			;     - get the TTS
	btfsc	hi,int_invalid_flag			;     - is the invalid flag set?
	call	TFT_disabled_color			;       YES - use disabled color
	bcf		hi,int_invalid_flag			;     - clear the invalid flag if applicable
	btfss	alt_layout_active			;     - in alternative layout?
	bra		TFT_display_tts_999x		;       NO
	MOVII	mpr, sub_a					;       YES - copy TTS to   sub_a
	MOVLI	.100,sub_b					;           - load 100 into sub_b
	call	cmpU16						;           - sub_a - sub_b = TTS - 100
	btfss	neg_flag					;           - TTS >= 100 ?
	bra		TFT_display_tts_999			;             YES
	;bra	TFT_display_tts_99			;             NO

TFT_display_tts_99:
	btfsc	tts_greater_99				; was TTS > 99 mins last time?
	rcall	TFT_display_tts_clear		; YES - clear remains from TTS > 99
										; set output position
	WIN_MEDIUM dm_tts_value_col_99, dm_tts_value_row
	output_99							; display 0...99
	STRCAT_PRINT "'"					; print "'"
	bcf		tts_greater_99				; last TTS shown was <= 99 mins
	bra		TFT_standard_color			; done

TFT_display_tts_999:					; set position
	WIN_MEDIUM dm_tts_value_col_999, dm_tts_value_row
	output_16_3							; display 0...999
	STRCAT_PRINT ""						; finalize output (no "'" here - not enough space available)
	bsf		tts_greater_99				; last TTS shown was > 99 mins
	bra		TFT_standard_color			; done

TFT_display_tts_999x:					; set position
	WIN_MEDIUM dm_tts_value_col_999x, dm_tts_value_row
	output_16_3							; display 0...999
	STRCAT_PRINT "'"					; print "'"
	bra		TFT_standard_color			; done

TFT_display_tts_clear:					; clear remains from TTS > 99
	WIN_BOX_BLACK dm_tts_value_row, dm_tts_value_row+.31, dm_tts_value_col_999, dm_tts_value_col_99 ; top, bottom, left, right
	call	TFT_memo_color				; restore default memo color
	movff	int_O_TTS_norm+1,WREG		; get the high byte of the TTS
	btfsc	WREG,int_invalid_flag		; is the invalid flag set?
	call	TFT_disabled_color			; YES - restore disabled color
	return								; done


	global	TFT_show_ndl
TFT_show_ndl:
	btfsc	dive_main_menu				; is the dive mode menu shown?
	return								; YES - abort
	movff	int_O_NDL_norm+0,lo			; NO  - get low byte of NDL time in normal plan
	btfsc	deco_locked					;     - was the dive in deco?
	bra		TFT_show_ndl_norm			;       YES - use normal layout
	btfsc	alt_layout_active			;       NO  - alternative layout active?
	bra		TFT_show_ndl_alt			;             YES - use alternative layout
	;bra	TFT_show_ndl_norm			;             NO  - use normal layout

TFT_show_ndl_norm:						; set position
	WIN_MEDIUM dm_ndl_value_col_norm,dm_ndl_value_row_norm
	rcall	TFT_show_ndl_set_color		; set color
	output_8							; display 0...240
TFT_show_ndl_exit_1:
	STRCAT_PRINT "'"					; print minutes symbol
TFT_show_ndl_exit_2:
	goto	TFT_standard_color			; done

TFT_show_ndl_alt:
	btfsc	safety_stop_active			; is the safety stop active?
	bra		TFT_show_ndl_alt_safety		; YES
										; clear potential remains from NDL normal and set position
	WIN_BOX_BLACK dm_ndl_value_row_norm, dm_3rdrow_bot, dm_ndl_value_col_norm, dm_ndl_value_col_alt ; top, bottom, left, right
	WIN_LARGE dm_ndl_value_col_alt, dm_ndl_value_row_alt
	rcall	TFT_show_ndl_set_color		; set color
	output_99							; display 0...99
	STRCAT_PRINT ""						; finalize output
	bra		TFT_show_ndl_exit_2			; done

TFT_show_ndl_alt_safety:
	WIN_MEDIUM dm_ndl_value_col_norm,dm_ndl_value_row_norm
	rcall	TFT_show_ndl_set_color		; set color
	PUTC	" "							; fill first digit position
	output_99							; display 0...99
	bra		TFT_show_ndl_exit_1			; print minutes symbol and done

TFT_show_ndl_set_color:
	movff	int_O_NDL_norm+1,lo			; get high byte of NDL time in normal plan
	btfss	lo,int_invalid_flag			; is the invalid flag set?
	goto	TFT_memo_color				; NO  - select memo     color and return
	goto	TFT_disabled_color			; YES - select disabled color and return


	global	TFT_divemode_sign_show
TFT_divemode_sign_show:
	btfsc	alt_layout_active			; alternative layout active?
	bra		TFT_divemode_sign_show_alt	; YES
	;bra	TFT_divemode_sign_show_norm	; NO

TFT_divemode_sign_show_norm:
	WIN_TOP  dm_sign_row_norm			; set row    position
	WIN_LEFT dm_sign_col_norm			; set column position
	bra		TFT_divemode_sign_show_com	; continue with common part

TFT_divemode_sign_show_alt:
	btfsc	dive_main_menu				; is the dive mode menu shown?
	return								; YES - abort
	btfsc	sign_shown					; NO  - sign already shown?
	bra		TFT_divemode_sign_show_alt_1;       YES - no need to clear area again
	btfsc	bailout_mode				;       NO  - in bailout?
	bra		TFT_divemode_sign_show_alt_1;             YES - no need to clear the area
										;             NO  - clear area from "bar" label and loop mode if applicable
	WIN_BOX_BLACK dm_active_dil_row, dm_3rdrow_bot, dm_active_sp_label_col, dm_sign_rgt_alt ; top, bottom, left, right
TFT_divemode_sign_show_alt_1:
	WIN_TOP  dm_sign_row_alt			;     - set row    position
	WIN_LEFT dm_sign_col_alt			;     - set column position
	;bra	TFT_divemode_sign_show_com	;     - continue with common part

TFT_divemode_sign_show_com:
	bsf		sign_shown					; flag that the advice/attention/warning sign is shown
	btfsc	message_warning				; do we have a warning?
	bra		TFT_divemode_sign_show_warn	; YES - show warning  sign
	btfsc	message_attention			; NO  - do we have an attention?
	bra		TFT_divemode_sign_show_att	;       YES - show attention sign
	btfsc	message_advice				;       NO  - do we have an advice message?
	bra		TFT_divemode_sign_show_adv	;             YES - show advice sign
	return								;             NO  - false alarm


TFT_divemode_sign_color_warn:			; custom colors table for dive_warning2 icon - warning
	db	.4, 0							; #colors, spare
	dw	0x0000							; color 0x00: outside           black
	dw	0xff80							; color 0x01: triangle          yellow
	dw	0xff80							; color 0x02: exclamation mark  yellow
	dw	0xf800							; color 0x03: inside            red

TFT_divemode_sign_color_adv:			; custom colors table for dive_warning2 icon - advice
	db	.4, 0							; #colors, spare
	dw	0x0000							; color 0x00: outside           black
	dw	0xffff							; color 0x01: triangle          white
	dw	0xffff							; color 0x02: exclamation mark  white
	dw	0x0780							; color 0x03: inside            green

TFT_divemode_sign_show_warn:
	TFT_WRITE_PROM_IMAGE_CUST_COLOR TFT_divemode_sign_color_warn; set custom colors for warning
	TFT_WRITE_PROM_IMAGE_BY_LABEL   dive_warning2_block			; show sign
	return														; done

TFT_divemode_sign_show_att:
	TFT_WRITE_PROM_IMAGE_BY_LABEL   dive_warning2_block			; show sign (with default colors)
	return														; done

TFT_divemode_sign_show_adv:
	TFT_WRITE_PROM_IMAGE_CUST_COLOR TFT_divemode_sign_color_adv	; set custom colors for advice
	TFT_WRITE_PROM_IMAGE_BY_LABEL   dive_warning2_block			; show sign
	return														; done


	global	TFT_divemode_sign_clear
TFT_divemode_sign_clear:
	btfss	sign_shown					; is the advice/attention/warning sign shown?
	return								; NO  - done
	bcf		sign_shown					; YES - clear advice/attention/warning sign area and its flag
	btfsc	alt_layout_active			;     - alternative layout active?
	bra		TFT_divemode_sign_clear_alt	;     - YES
	;bra	TFT_divemode_sign_clear_norm;     - NO

TFT_divemode_sign_clear_norm:
	WIN_BOX_BLACK dm_sign_row_norm, dm_sign_bot_norm, dm_sign_col_norm, dm_sign_rgt_norm ; top, bottom, left, right
	return								; done

TFT_divemode_sign_clear_alt:
	WIN_BOX_BLACK dm_sign_row_alt, dm_sign_bot_alt, dm_sign_col_alt, dm_sign_rgt_alt	 ; top, bottom, left, right
	return								; done


	global	TFT_show_deco_mask
TFT_show_deco_mask:
	bcf		safety_stop_active			; flag safety stop is not shown any more	TODO: needed?
	btfsc	dive_main_menu				; is the dive mode menu shown?
	return								; YES - abort
	btfsc	alt_layout_active			; NO  - in alternative layout?
	bra		TFT_show_deco_mask_alt		;       YES
	;bra	TFT_show_deco_mask_norm		;       NO

TFT_show_deco_mask_norm:
	WIN_STD dm_tts_text_col_norm, dm_tts_text_row_norm	; set text position
	bra		TFT_show_deco_mask_common					; continue with common part

TFT_show_deco_mask_alt:
	WIN_TINY dm_tts_text_col_alt, dm_tts_text_row_alt	; set text position
	STRCPY	"Stop/"										; print "Stop/"
	;bra	TFT_show_deco_mask_common					; continue with common part

TFT_show_deco_mask_common:
	call	TFT_divemask_color			; set text color
	STRCAT_TEXT_PRINT tTTS				; print "TTS"
	bra		TFT_display_exit_1			; done


TFT_display_deco_depth:					; output depth (stored in lo) to POSTINC2 with "m" or "ft"
	TSTOSS	opt_units					; get unit (0=m, 1=ft)
	bra		TFT_display_deco_depth_m	; 0 - meter
	;bra	TFT_display_deco_depth_ft	; 1 - feet

TFT_display_deco_depth_ft:
	call	convert_meter_to_feet		; convert value in lo from meters to feet
	output_16_3							; output stop depth (000-999)
	return								; done

TFT_display_deco_depth_m:
	output_99							; output stop depth
	STRCAT_TEXT tMeters					; print unit
	return								; done


	global	TFT_show_deco
TFT_show_deco:
	btfsc	dive_main_menu				; is the dive mode menu shown?
	return								; YES - abort

	call	TFT_color_code_stop			; color-code output
	movff	char_O_deco_depth,lo		; get depth of first stop in meters

	TSTOSC	opt_units					; get unit (0=m, 1=ft)
	bra		TFT_show_deco_norm			; 1 - ft can only be displayed in normal layout due to space required for 3 digit depth

	btfsc	alt_layout_active			; in alternative layout?
	bra		TFT_show_deco_alt			; YES
	;bra	TFT_show_deco_norm			; NO

TFT_show_deco_norm:						; set position for combined depth and time
	WIN_MEDIUM dm_decostop_col_norm, dm_decostop_row_norm
	rcall	TFT_display_deco_depth		; output depth (stored in lo) to POSTINC2 with "m" or "ft"
	PUTC	' '							; put a space char between depth and time
	bra		TFT_display_deco_common		; continue with common part

TFT_show_deco_alt:						; set position for depth
	WIN_LARGE  dm_decostop_col_alt_depth, dm_decostop_row_alt_depth
	output_99							; output stop depth (2 digits, usable for meters only)
	STRCAT_PRINT ""						; finalize output
										; set position for time
	WIN_MEDIUM dm_decostop_col_alt_time,  dm_decostop_row_alt_time
	call	TFT_memo_color				; back to memo color
	bcf		win_invert					; back to non-inverted output
	;bra	TFT_display_deco_common		; continue with common part

TFT_display_deco_common:
	movff	char_O_deco_time,lo			; get stop time of the first stop in minutes
	output_99DD							; print minutes or double dots if null
	STRCAT_PRINT "'"					; add minutes sign
	bcf		win_invert					; back to non-inverted output
TFT_display_exit_1:
	goto	TFT_standard_color			; and return...


	global	TFT_decoplan_mask			; mask for deco plan
TFT_decoplan_mask:
	call	TFT_divemask_color
	WIN_TINY dm_custom_decoplan_title_column, dm_custom_decoplan_title_row
	STRCPY_TEXT_PRINT tDiveDecoplan
	return


	global	TFT_decoplan				; data for deco plan - stops 2 - 7 (stop 1 is shown in the main screen)
TFT_decoplan:
	lfsr	FSR0,char_O_deco_depth		; load base address of stops table
	clrf	ex							; will be used for auxiliary flags
	call	TFT_memo_color				; set default output color
	movff	char_O_deco_gas+0,lo		; get flag for invalid deco data
	btfsc	lo,char_invalid_flag		; is the invalid flag set?
	call	TFT_disabled_color			; YES - set to disabled color
	; 2nd stop
	WIN_SMALL dm_cust_dstop_2nd_stop_column, dm_cust_dstop_2nd_stop_row
	rcall	TFT_decoplan_helper
	; 3rd stop
	WIN_SMALL dm_cust_dstop_3rd_stop_column, dm_cust_dstop_3rd_stop_row
	rcall	TFT_decoplan_helper
	; 4th stop
	bsf		ex,4						; flag we are on 4th screen position
	WIN_SMALL dm_cust_dstop_4th_stop_column, dm_cust_dstop_4th_stop_row
	rcall	TFT_decoplan_helper
	bcf		ex,4						; clear 4th position flag again
	; 5th stop
	WIN_SMALL dm_cust_dstop_5th_stop_column, dm_cust_dstop_5th_stop_row
	rcall	TFT_decoplan_helper
	; 6th stop
	WIN_SMALL dm_cust_dstop_6th_stop_column, dm_cust_dstop_6th_stop_row
	rcall	TFT_decoplan_helper
	; 7th stop
	WIN_SMALL dm_cust_dstop_7th_stop_column, dm_cust_dstop_7th_stop_row
	rcall	TFT_decoplan_helper
	bra		TFT_display_exit_1			; set standard color and return...

TFT_decoplan_helper:
	btfsc	ex,0						; no more stops to show?
	bra		TFT_decoplan_helper_1		; YES - skip checking next entry - it will be empty, too
	movff	PREINC0,lo					; NO  - advance pointer to get the depth of the 2nd, 3rd, 4th, ... stop
	tstfsz	lo							;       is the stop depth = 0, i.e. no stop entry?
	bra		TFT_decoplan_helper_3		;       NO  - show stop data
TFT_decoplan_helper_1:					; no more stop table entries
	bsf		ex,0						; flag that there are no more stop table entries
	btfss	ex,4						; are we on the 4th screen position?
	bra		TFT_decoplan_helper_2		; NO  - normal handling on this position
	btfsc	ex,1						; YES - special handling, has any stop been shown?
	bra		TFT_decoplan_helper_2		;       YES - print normal blanking
	STRCPY_PRINT "  ---- "				;       NO  - print a "no stops" indication (blanking potential previous content, too)
	return
TFT_decoplan_helper_2:					; no more stop table entries, blank potential previous content
	STRCPY_PRINT "       "				; wipe screen position by printing 7 spaces
	return
TFT_decoplan_helper_3:
	rcall	TFT_display_deco_depth		; output depth (stored in lo) to POSTINC2
	PUTC	" "							; put a space char between depth and time
	movlw	NUM_STOPS					; offset between arrays holding depths and durations
	movff	PLUSW0,lo					; get duration of the current stop
	output_99dd							; print duration, prints double dots if duration is zero
	STRCAT_PRINT "'"					; append symbol for minutes and print to screen
	bsf		ex,1						; flag that a stop was shown
	return


	global	TFT_safety_stop_clear
TFT_safety_stop_clear:
	btfsc	dive_main_menu				; is the dive mode menu shown?
	return								; YES - abort
	btfss	safety_stop_active			; NO  - is the safety stop shown?
	return								;       NO  - done, nothing to do
										;       YES - clear safety stop area
	WIN_BOX_BLACK dm_safetystop_row, dm_safetystop_bot, dm_safetystop_text_column, dm_safetystop_rgt ; top, bottom, left, right
	bcf		safety_stop_active			;           - safety stop not shown any more
	btfsc	deco_region					;           - was the dive within deco stops region?
	bra		TFT_show_slow_reminder		;             YES - show "SLOW" reminder
	return								;             NO  - done


	global	TFT_safety_stop_show
TFT_safety_stop_show:
	btfsc	dive_main_menu				; is the dive mode menu shown?
	return								; YES - abort
	btfsc	safety_stop_active			; NO  - is the safety stop shown already?
	bra		TFT_safety_stop_show_time	;       YES - just update the time
										;       NO  - clear area that may be polluted by alternative NDL
	WIN_BOX_BLACK dm_safetystop_row, dm_tts_value_row, dm_ndl_value_col_alt, dm_safetystop_rgt ; top, bottom, left, right
	call	TFT_divemask_color			;           - set color    for text
	bsf		safety_stop_active			;           - flag safety stop is shown now
										;           - set position for text
	WIN_STD dm_safetystop_text_column, dm_safetystop_text_row
	STRCPY_PRINT "Stop "				;           - print "Stop" with a trailing space to wipe away potential other remains
TFT_safety_stop_show_time:
	call	TFT_attention_color			; set color    for time
										; set position for time
	WIN_MEDIUM dm_safetystop_column, dm_safetystop_row
	movff	safety_stop_countdown,lo	; get remaining time in seconds, low  byte, from safety stop timer
	clrf	hi							; set remaining time in seconds, high byte, to zero
	call	convert_time				; convert hi:lo in seconds to minutes (up:hi) and seconds (lo)
	movff	lo,up						; save seconds in up
	movff	hi,lo						; move minutes to lo
	bsf		leftbind					; activate left-alignment
	output_8							; print minutes
	bcf		leftbind					; deactivate left-alignment
	PUTC	':'							; print ":"
	movff	up,lo						; move seconds to lo
	output_99x							; print seconds (2 digits with leading zero)
	STRCAT_PRINT ""						; finalize output
	bra		TFT_display_exit_1			; done


	global	TFT_avr_stopwatch_mask		; mask for average depth and stopwatch
TFT_avr_stopwatch_mask:
	call	TFT_divemask_color

 IFNDEF _min_depth_option

	WIN_TINY dm_custom_avr_stop_column1+.2,dm_custom_avr_stop_title_row
	TSTOSS	opt_2ndDepthDisp			; show avg depth instead of max depth in main screen?
	bra		TFT_avr_stopwatch_mask_1	; NO  - draw avg depth in custom view then
	btfss	alt_layout_active			; YES - in alternative layout?
	bra		TFT_avr_stopwatch_mask_max	;       NO  - show max depth
	;bra	TFT_avr_stopwatch_mask_avg	;       YES - show avg depth
TFT_avr_stopwatch_mask_avg:
	STRCPY_TEXT_PRINT tDiveTotalAvg		; mask for average depth
	bra		TFT_avr_stopwatch_mask_2	; continue
TFT_avr_stopwatch_mask_1:
	btfss	alt_layout_active			; YES - in alternative layout?
	bra		TFT_avr_stopwatch_mask_avg	;       NO  - show avg depth
	;bra	TFT_avr_stopwatch_mask_max	;       YES - show max depth
TFT_avr_stopwatch_mask_max:
	STRCPY_TEXT_PRINT tMaxDepth			; mask for maximum depth
	;bra	TFT_avr_stopwatch_mask_2	; continue
TFT_avr_stopwatch_mask_2:
	WIN_TINY dm_custom_avr_stop_column2+.3,dm_custom_avr_stop_title_row
	STRCPY_TEXT_PRINT tDiveStopwatch
	WIN_TINY dm_custom_avr_stop_column3-.8,dm_custom_avr_stop_title_row
	STRCPY_TEXT_PRINT tDiveStopAvg
	bra		TFT_display_exit_1

 ELSE

	WIN_TINY dm_custom_avr_stop_column1+.2,dm_custom_avr_stop_title_row
	STRCPY_PRINT "Max.Depth"
	WIN_TINY dm_custom_avr_stop_column2+.3,dm_custom_avr_stop_title_row
	STRCPY_PRINT "Avg.Depth"
	WIN_TINY dm_custom_avr_stop_column3-.8,dm_custom_avr_stop_title_row
	STRCPY_PRINT "Min.Depth"
	bra		TFT_display_exit_1

 ENDIF


	global	TFT_avr_stopwatch			; dive mode custom view: average depth and stopwatch
TFT_avr_stopwatch:
	call	TFT_memo_color

 IFNDEF _min_depth_option

	; total average depth or max depth
	WIN_MEDIUM dm_custom_avr_stop_column1,dm_custom_avr_stop_row
	TSTOSS	opt_2ndDepthDisp			; show average depth instead of maximum depth in main screen?

	bra		TFT_avr_stopwatch_1			; NO  - draw avg depth in custom view then
	btfss	alt_layout_active			; YES - in alternative layout?
	bra		TFT_avr_stopwatch_max		;       NO  - show max depth
	;bra	TFT_avr_stopwatch_avg		;       YES - show avg depth
TFT_avr_stopwatch_avg:
	MOVII	pressure_rel_avg_total,mpr	; get total dive average pressure into hi:lo
	bra		TFT_avr_stopwatch_2			; continue
TFT_avr_stopwatch_1:
	btfss	alt_layout_active			; YES - in alternative layout?
	bra		TFT_avr_stopwatch_avg		;       NO  - show avg depth
	;bra	TFT_avr_stopwatch_max		;       YES - show max depth
TFT_avr_stopwatch_max:
	MOVII	pressure_rel_max_cached,mpr	; get maximum pressure into hi:lo
	;bra	TFT_avr_stopwatch_2			; continue
TFT_avr_stopwatch_2:
	call	convert_pres_to_depth		; convert pressure in [mbar] to depth in [cm]
	TSTOSS	opt_units						 ; 0=m, 1=ft
	bra		TFT_update_avr_stopwatch1_metric ; 0 - metric
TFT_update_avr_stopwatch1_imp:				 ; 1 - imperial
	call	convert_cm_to_feet			; convert value in hi:lo from [cm] to [feet]
	output_16_3							; yxz
	bra		TFT_update_avr_stopwatch2
TFT_update_avr_stopwatch1_metric:
	bsf		leftbind
	bsf		ignore_digit5				; no cm (flag will be cleared by output_16)
	output_16dp .3						; yxz.a
	PUTC	" "							; wipe out remains from last output
	clrf	WREG
	movff	WREG,buffer+.4				; limit string length to 4 = 3 digits + 1 half-size decimal dot
TFT_update_avr_stopwatch2:
	STRCAT_PRINT ""

	; stopped average depth
	WIN_MEDIUM dm_custom_avr_stop_column3,dm_custom_avr_stop_row
	MOVII	pressure_rel_avg_trip,mpr	; get the resettable average pressure
	call	convert_pres_to_depth		; convert pressure in [mbar] to depth in [cm]
	TSTOSS	opt_units						 ; 0=m, 1=ft
	bra		TFT_update_avr_stopwatch2_metric ; 0 - metric
TFT_update_avr_stopwatch2_imp:				 ; 1 - imperial
	call	convert_cm_to_feet			; convert value in hi:lo from [cm] to [feet]
	output_16_3							; yxz
	bra		TFT_update_avr_stopwatch3
TFT_update_avr_stopwatch2_metric:
	bsf		leftbind
	bsf		ignore_digit5				; no cm (flag will be cleared by output_16)
	output_16dp .3						; yxz.a
	PUTC	" "							; wipe out remains from last output
	clrf	WREG
	movff	WREG,buffer+.4				; limit string length to 4 = 3 digits + 1 half-size decimal dot
TFT_update_avr_stopwatch3:
	STRCAT_PRINT ""						; finalize output

 ELSE

	; resettable maximum depth - needs ISR-safe copy!
	WIN_MEDIUM dm_custom_avr_stop_column1,dm_custom_avr_stop_row		; column   0
	call	TFT_memo_color
	SMOVII	pressure_rel_max_trip,mpr	; get resettable maximum pressure
	rcall	TFT_avr_stopwatch_helper

	; resettable average depth
	WIN_MEDIUM dm_custom_avr_stop_column2-.1,dm_custom_avr_stop_row		; column  54 -  1 =  53
	call	TFT_attention_color
	MOVII	pressure_rel_avg_trip,mpr	; get resettable average pressure
	rcall	TFT_avr_stopwatch_helper

	; resettable minimum depth - needs ISR safe copy!
	WIN_MEDIUM dm_custom_avr_stop_column3-.12,dm_custom_avr_stop_row	; column 118 - 12 = 106
	call	TFT_memo_color
	SMOVII	pressure_rel_min_trip,mpr	; get resettable minimum pressure
	rcall	TFT_avr_stopwatch_helper

	; done
	bra		TFT_display_exit_2

TFT_avr_stopwatch_helper:
	call	convert_pres_to_depth		; convert pressure in [mbar] to depth in [cm]
	output_16dp .3						; yxz.ab
	PUTC	" "							; wipe out remains from last output
	clrf	WREG
	movff	WREG,buffer+.5				; limit string length to 5 = 4 digits + 1 half-size decimal dot
	STRCAT_PRINT ""
	return

 ENDIF

	; stopped dive time  (will also be used by compass custom view)
	WIN_MEDIUM dm_custom_avr_stop_column2,dm_custom_avr_stop_row
TFT_update_stopwatch:					; jump-in point for stopped dive time in compass custom view
	MOVII	divesecs_avg_trip,mpr		; get the resettable dive time (stopwatch)
	call	convert_time				; convert hi:lo in seconds to minutes (up:hi) and seconds (lo)
	movlw	.100						; display layout will change if minutes become >= 100
	cpfslt	hi							; minutes < 100 ?
	bra		TFT_update_stopwatch_2		; NO  - display hours:minutes
	bcf		aux_flag					; will print minutes : seconds
TFT_update_stopwatch_1:
	movf	hi,W						; exchange lo and hi
	movff	lo,hi						; ...
	movwf	lo							; ...
	bcf		leftbind					; include leading spaces
	output_99							; output minutes or hours ( 0 - 99)
	movlw	":"							; load standard separator
	btfsc	aux_flag					; will print hours : minutes ?
	movlw	"'"							; YES - swap to alternative separator
	movwf	POSTINC2					; print separator
	movff	hi,lo						; restore lo
	output_99x							; output seconds or minutes
	movlw	.5
	call	TFT_fillup_with_spaces		; fill up FSR2 with spaces (total string length in #WREG)
	clrf	WREG
	movff	WREG,buffer+.5				; limit to 5 chars
	STRCAT_PRINT ""
	bra		TFT_display_exit_2			; clear leftbind and return
TFT_update_stopwatch_2:
	movff	hi,lo						; transfer minutes (low  byte) to lo
	movff	up,hi						; transfer minutes (high byte) to hi
	call	convert_time				; convert hi:lo in minutes to hours (up:hi) and minutes (lo)
	bsf		aux_flag					; will print hours : minutes
	bra		TFT_update_stopwatch_1


	global	TFT_CNS_mask
TFT_CNS_mask:
	call	TFT_divemask_color
	WIN_TINY dm_custom_cns3_column1, dm_custom_cns3_title_row
	STRCPY_TEXT_PRINT tCNSsurf
	WIN_TINY dm_custom_cns3_column2, dm_custom_cns3_title_row

 IFDEF _cave_mode
	btfss	cave_mode					; cave mode switched on?
	bra		TFT_CNS_mask_1				; NO
	STRCPY_TEXT_PRINT tCNScave			; YES - print cave TTS label
	bra		TFT_CNS_mask_3				;     - continue with 3rd column
 ENDIF

TFT_CNS_mask_1:
	btfsc	FLAG_oc_mode				; in OC mode?
	bra		TFT_CNS_mask_2				; YES - print fTTS label
	btfsc	bailout_mode				; in bailout?
	bra		TFT_CNS_mask_2				; YES - print fTTS label (label will be printed, but a fTTS will actually not be calculated)
	TSTOSS	opt_calc_gasvolume			; bailout volume calculation requested?
	bra		TFT_CNS_mask_2				; NO  - print fTTS label
	STRCPY_TEXT_PRINT tCNSBO			; YES - print bailout label
	bra		TFT_CNS_mask_3				;     - continue with 3rd column
TFT_CNS_mask_2:							; OC or bailout
	STRCPY_TEXT_PRINT tCNSfTTS			; print fTTS label
TFT_CNS_mask_3:
	WIN_TINY dm_custom_cns3_column3, dm_custom_cns3_title_row
	STRCPY_TEXT_PRINT tCNSnow			; print CNS now label
	bra		TFT_display_exit_2


	global	TFT_CNS
TFT_CNS:
	bsf		leftbind
	; CNS at end of normal dive
	WIN_STD dm_custom_cns3_column1+.3,dm_custom_cns3_row
	MOVII	int_O_CNS_norm,mpr			; get CNS at end of dive in normal plan
	call	TFT_color_code_cns
	output_16_3							; output as xxx
	STRCAT_PRINT "% "
	; fTTS / Bailout CNS, if enabled
	WIN_STD dm_custom_cns3_column2+.2,dm_custom_cns3_row
	btfsc	bailout_mode				; in bailout?
	bra		TFT_CNS_3					; YES - show "---"
	TSTOSS	opt_calc_gasvolume			; NO  - bailout volume calculation requested?
	bra		TFT_CNS_1					;       NO  - continue checking fTTS extra time
	btfss	FLAG_oc_mode				;       YES - in OC mode?
	bra		TFT_CNS_2					;             NO - show CNS%
TFT_CNS_1:								; not in bailout, no volume calculation, and/or in OC mode
	TSTOSS	char_I_extra_time			; fTTS extra time configured?
	bra		TFT_CNS_3					; NO  - show "---"
TFT_CNS_2:								; YES - show CNS%
	MOVII	int_O_CNS_alt,mpr			; get CNS at end of dive in alternative plan
	call	TFT_color_code_cns			; color-code the CNS value
	output_16_3							; output as xxx
	STRCAT_PRINT "% "
	bra		TFT_CNS_4
TFT_CNS_3:
 IFDEF _cave_mode
	btfss	cave_mode					; cave mode switched on?
	bra		TFT_CNS_3a					; NO  - show dashes
	btfsc	backtrack_entire_full		; YES - cave mode shut down due to storage fully used up?
	bra		TFT_CNS_3a					;       YES - show dashes
	btfss	dive_turned					;       NO  - dive turned?
	bra		TFT_CNS_2					;             NO  - show cave CNS
	;bra	TFT_CNS_3a					;             YES - show dashes
 ENDIF
TFT_CNS_3a:
	call	TFT_memo_color
	STRCPY_PRINT "---  "
TFT_CNS_4:
	; current CNS
	WIN_STD dm_custom_cns3_column3+.3,dm_custom_cns3_row
	MOVII	int_O_CNS_current,mpr		; get current CNS
	call	TFT_color_code_cns
	output_16_3							; output as xxx
	STRCAT_PRINT "%"
TFT_display_exit_2:
	bcf		leftbind
	goto	TFT_standard_color			; and return...

;=============================================================================

 IFDEF _cave_mode

	global	TFT_cave_tts_mask				; mask for cave mode data
TFT_cave_tts_mask:
	call	TFT_divemask_color
	WIN_TINY dm_custom_cave_title_column1,dm_custom_cave_title_row
	STRCPY_TEXT_PRINT tCaveStops
	WIN_TINY dm_custom_cave_title_column2,dm_custom_cave_title_row
	STRCPY_TEXT_PRINT tCaveTTS
	WIN_TINY dm_custom_cave_title_column3,dm_custom_cave_title_row
	STRCPY_TEXT_PRINT tCaveRuntime
	bra		TFT_display_exit_2


	global	TFT_cave_tts				; dive mode custom view: cave TTS
TFT_cave_tts:
	; total time of all stops
	WIN_MEDIUM dm_custom_cave_data_column1,dm_custom_cave_data_row		; column 8
	call	TFT_memo_color				; set default color
	btfss	cave_mode					; cave mode switched on?
	bra		TFT_cave_1b					; NO  - print dashes
	MOVII	int_O_TST_norm,mpr			; YES - get normal plan total stops time
	btfss	mpr+1,int_not_yet_computed	;     - not yet computed?
	bra		TFT_cave_1a					;       NO  - continue
	call	TFT_disabled_color			;       YES - switch to disabled color
	bra		TFT_cave_1b					;           - print dashes
TFT_cave_1a:
	btfsc	mpr+1,int_invalid_flag		; stops time invalid?
	call	TFT_disabled_color			; YES - switch to disabled color
	bcf		mpr+1,int_invalid_flag		; clear invalid flag if applicable
	movf	mpr+0,W						; copy     low  byte of stops time to WREG
	iorwf	mpr+1,W						; ior with high byte of stops time
	bz		TFT_cave_1b					; print dashes if stops time is zero
	output_16_3							; output as xxx
	STRCAT_PRINT "'"					; print minutes symbol
	bra		TFT_cave_2					; continue
TFT_cave_1b:
	STRCAT_PRINT ",-,-,-,"				; print 3 dashes (',' produces a half-width space)
TFT_cave_2:
	; cave TTS
	WIN_MEDIUM dm_custom_cave_data_column2,dm_custom_cave_data_row		; column 60
	call	TFT_memo_color				; set default color
	btfsS	cave_mode					; cave mode switched on?
	bra		TFT_cave_2b					; NO  - print dashes
	MOVII	int_O_TTS_norm,mpr			; YES - get normal plan total time to surface
	btfss	mpr+1,int_not_yet_computed	;     - not yet computed?
	bra		TFT_cave_2a					;       NO  - continue
	call	TFT_disabled_color			;       YES - switch to disabled color
	bra		TFT_cave_2b					;           - print dashes
TFT_cave_2a:
	btfsc	mpr+1,int_invalid_flag		; TTS invalid?
	call	TFT_disabled_color			; YES - switch to disabled color
	bcf		mpr+1,int_invalid_flag		; clear invalid flag if applicable
	output_16_3							; output as xxx
	STRCAT_PRINT "'"					; print minutes symbol
	bra		TFT_cave_3					; continue
TFT_cave_2b:
	STRCAT_PRINT ",-,-,-,"				; print 3 dashes (',' produces a half-width space)
TFT_cave_3:
	; estimated total runtime
	WIN_MEDIUM dm_custom_cave_data_column3,dm_custom_cave_data_row		; column 114
	;									; keep color from cave TTS
	btfss	cave_mode					; cave mode switched on?
	bra		TFT_cave_3b					; NO  - print dashes
	SMOVII	counted_divetime_mins,mpr	; YES - ISR safe copy of counted dive time to MPR
	movff	int_O_TTS_norm+0,WREG		;     - get TTS, low  byte, into WREG
	addwf	mpr+0,F						;     - add TTS, low  byte, to dive time in MPR
	movff	int_O_TTS_norm+1,WREG		;     - get TTS, high byte, into WREG
	btfsc	WREG,int_not_yet_computed	;     - not yet computed?
	bra		TFT_cave_3b					;       YES - print dashes
	bcf		WREG,int_invalid_flag		;       NO  - clear invalid flag if applicable
	addwfc	mpr+1,F						;           - add TTS, high byte, to dive time in MPR
	output_16_3							;           - output as xxx
	STRCAT_PRINT "'"					;           - print minutes symbol
	bra		TFT_display_exit_2			;           - done
TFT_cave_3b:
	STRCAT_PRINT ",-,-,-,"				; print 3 dashes (',' produces a half-width space)
	bra		TFT_display_exit_2			; done


	global	TFT_cave_waypoints
TFT_cave_waypoints:
	; title row
	WIN_TINY .70,dm_custom_cave_title_row;adjust column to display position of current waypoint
	call	TFT_divemask_color			; select color
	btfss	cave_mode					; cave mode switched on?
	bra		TFT_cave_waypoints_3		; NO  - do not show any marker (any more)
	btfss	dive_turned					; YES - dive turned?
	bra		TFT_cave_waypoints_1		;       NO  - print marker on right side
	bra		TFT_cave_waypoints_2		;       YES - print marker in the middle
TFT_cave_waypoints_1:
	movlw	.12							; start with 12 space chars
	call	TFT_fillup_with_spaces		; fill buffer with space chars
TFT_cave_waypoints_2:
	STRCAT	"<====="					; print marker symbol
TFT_cave_waypoints_3:
	movlw	.18							; set overall number of chars
	call	TFT_fillup_with_spaces		; fill buffer with space chars
	STRCAT_PRINT ""						; finalize output
	; data row
	btfsc	cave_mode					; cave mode switched on?
	bra		TFT_cave_waypoints_4		; YES - show graphics
	WIN_STD .0,dm_custom_cave_data_row	; NO  - show "Cave Mode off" text
	call	TFT_attention_color			;     - select attention color
	STRCPY	"  "						;     - print 2 space chars
	STRCAT_TEXT tCaveMode				;     - print "Cave Mode"
	PUTC	" "							;     - print a space char
	STRCAT_TEXT tOff					;     - print "off"
	movlw	.17							;     - set max number of chars
	call	TFT_fillup_with_spaces		;     - fill up FSR2 with spaces (total string length in #WREG)
	STRCAT_PRINT ""						;     - finalize output
	return								;     - done
TFT_cave_waypoints_4:
	WIN_MEDIUM .0,dm_custom_cave_data_row; start in column 0
	call	TFT_memo_color				; select default color
	tstfsz	DM_flags_cavereq			; any pending cave mode requests?
	call	TFT_disabled_color			; YES - switch to disabled color
	; 1st section: previous waypoint number or beginning line
	movlw	.1							; load a one into WREG
	cpfsgt	backtrack_waypoint_num		; current waypoint number > 1 ?
	bra		TFT_cave_waypoints_5		; NO  - print line segment only
	STRCAT	",-,"						; YES - print one dash
	movff	backtrack_waypoint_num,lo	;     - copy current waypoint number to lo
	decf	lo,F						;     - create previous waypoint number
	output_99							;     - print previous waypoint number in two digit format
	STRCAT	","							;     - print a half-space
	bra		TFT_cave_waypoints_6		;     - continue with next section
TFT_cave_waypoints_5:
	STRCAT	",-,-----"					; print line segment
TFT_cave_waypoints_6:
	; 2nd section: solid line
	STRCAT	"---"						; print a solid line
	; 3rd section: current waypoint number, turn point symbol or line segment
	tstfsz	backtrack_waypoint_num		; does a current waypoint exist?
	bra		TFT_cave_waypoints_8		; YES - print its number or the turn point symbol
	btfss	dive_turned					; NO  - dive turned?
	bra		TFT_cave_waypoints_7		;       NO  - print a separated  line segment
	STRCAT	"------"					;       YES - print a continuous line
	bra		TFT_cave_waypoints_10		;           - continue with next section
TFT_cave_waypoints_7:
	STRCAT	",----,"					; print a separated line segment
	bra		TFT_cave_waypoints_10		; continue with next section
TFT_cave_waypoints_8:
	STRCAT	","							; print a half-width space
	movff	backtrack_waypoint_num,lo	; copy current waypoint number to lo
	movf	backtrack_waypoint_turn,W	; copy turn point number to WREG
	cpfseq	lo							; current waypoint = turn point ?
	bra		TFT_cave_waypoints_9		; NO  - show waypoint number
	STRCAT_PRINT "--|,     "			; YES - print end-of-line symbol, clear remaining output and finalize output
	return								;     - done
TFT_cave_waypoints_9:
	movff	backtrack_waypoint_num,lo	; copy  current waypoint number to lo
	output_99 							; print current waypoint number in two digit format
	STRCAT	","							; print a half-space
TFT_cave_waypoints_10:
	; 4th section: solid line
	STRCAT	"---"						; print a solid line
	; 5th section: next waypoint number or end of line symbol
	incf	backtrack_waypoint_num,W	; load WREG with next waypoint number
	cpfseq	backtrack_waypoint_turn		; next waypoint number = turn point number ?
	btfsc	waypoint_reached_last		; NO  - is the current waypoint the last waypoint?
	bra		TFT_cave_waypoints_11		; YES / YES - print end-of-line symbol
	STRCAT	","							;       NO  - print a half-space
	incf	backtrack_waypoint_num,W	;           - (re)load WREG with next waypoint number
	movwf	lo							;       NO  - copy  next waypoint number to lo
	output_99 							;           - print next waypoint number in two digit format
	STRCAT_PRINT ""						;           - finalize output
	return								;           - done
TFT_cave_waypoints_11:
	STRCAT_PRINT "---|,"				; print end-of-line symbol and finalize output
	return								; done

 ENDIF

;=============================================================================

 IFDEF _external_sensor

	global	TFT_ppo2_sensors_mask		; mask for ppO2 sensors
TFT_ppo2_sensors_mask:
	call	TFT_divemask_color
	WIN_TINY dm_custom_hud_sensor1_column+.4,dm_custom_hud_title_row
	STRCPY_TEXT_PRINT tDiveHudMask1
	WIN_TINY dm_custom_hud_sensor2_column+.3,dm_custom_hud_title_row
	STRCPY_TEXT_PRINT tDiveHudMask2
	WIN_TINY dm_custom_hud_sensor3_column+.2,dm_custom_hud_title_row
	STRCPY_TEXT_PRINT tDiveHudMask3
	bra		TFT_display_exit_2


	global	TFT_ppo2_sensors			; data for ppO2 sensors
TFT_ppo2_sensors:
;
; Definition of the output:
;
;  sensorX       use        voting         o2
; _calibrated    _O2       _logic        _ppo2          Output           Color
;    _ok      _sensorX    _sensorX     _sensorX
;-----------------------------------------------------------------------------------------------
;    0          -/-          -/-            -/-         "----"           TFT_memo_color
;    1           0           -/-            = 0         o2_ppo2_sensorX  TFT_attention_color
;    1           0           -/-            > 0         o2_ppo2_sensorX  TFT_disabled_color
;    1           1            0             -/-         o2_ppo2_sensorX  TFT_color_code_ppo2_hud + win_invert
;    1           1            1             -/-         o2_ppo2_sensorX  TFT_color_code_ppo2_hud
;
	bsf		leftbind
	; sensor 1
	btfsc	sensor1_calibrated_ok		; valid calibration?
	bra		TFT_update_hud1b			; YES
	btfsc	sensor1_active				; valid HUD data for this sensor
	bra		TFT_update_hud1b			; YES

	; no valid calibration
	WIN_STD dm_custom_hud_sensor1_column+.7, dm_custom_hud_row+.5
	call	TFT_memo_color
	STRCPY_PRINT "---"
	bra		TFT_update_hud2a			; continue with sensor 2
TFT_update_hud1b:
	; sensor has a valid calibration
	WIN_MEDIUM dm_custom_hud_sensor1_column,dm_custom_hud_row
	movff	sensor1_ppO2,lo				; load ppO2 value into transfer storage for output
	clrf	hi							; 
	btfsc	use_O2_sensor1				; in use?
	bra		TFT_update_hud1d			; YES
	; valid calibration, but not in use
	tstfsz	lo							; sensor value = 0?
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
	btfsc	voting_logic_sensor1		; sensor value agrees with values of other sensors?
	bra		TFT_update_hud1e			; YES
	; valid calibration, in use, but value does not agree with other sensors
	bsf		win_invert					; invert output
TFT_update_hud1e:
	; all coloring is set up now, let's write the value to the display!
	output_16dp .3						; x.xx bar
	STRCAT_PRINT ""
	bcf		win_invert

TFT_update_hud2a:						; sensor 2
	btfsc	sensor2_calibrated_ok		; valid calibration?
	bra		TFT_update_hud2b			; YES
	btfsc	sensor2_active				; valid HUD data for this sensor
	bra		TFT_update_hud2b			; YES
	; no valid calibration
	WIN_STD dm_custom_hud_sensor2_column+.7, dm_custom_hud_row+.5
	call	TFT_memo_color
	STRCPY_PRINT "---"
	bra		TFT_update_hud3a			; continue with sensor 3
TFT_update_hud2b:
	; sensor has a valid calibration
	WIN_MEDIUM dm_custom_hud_sensor2_column,dm_custom_hud_row
	movff	sensor2_ppO2,lo				; load ppO2 value into transfer storage for output
	clrf	hi							; 
	btfsc	use_O2_sensor2				; in use?
	bra		TFT_update_hud2d			; YES
	; valid calibration, but not in use
	tstfsz	lo							; sensor value = 0?
	bra		TFT_update_hud2c			; NO
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
	btfsc	voting_logic_sensor2		; sensor value agrees with values of other sensors?
	bra		TFT_update_hud2e			; YES
	; valid calibration, in use, but value does not agree with other sensors
	bsf		win_invert					; invert output
TFT_update_hud2e:
	; all coloring is set up now, let's write the value to the display!
	output_16dp .3						; x.xx bar
	STRCAT_PRINT ""
	bcf		win_invert

TFT_update_hud3a:						; sensor 3
	btfsc	sensor3_calibrated_ok		; valid calibration?
	bra		TFT_update_hud3b			; YES
	btfsc	sensor3_active				; valid HUD data for this sensor
	bra		TFT_update_hud3b			; YES
	; no valid calibration
	WIN_STD dm_custom_hud_sensor3_column+.7, dm_custom_hud_row+.5
	call	TFT_memo_color
	STRCPY_PRINT "---"
	bra		TFT_update_hud4				; done
TFT_update_hud3b:
	; sensor has a valid calibration
	WIN_MEDIUM dm_custom_hud_sensor3_column,dm_custom_hud_row
	movff	sensor3_ppO2,lo				; load ppO2 value into transfer storage for output
	clrf	hi							; 
	btfsc	use_O2_sensor3				; in use?
	bra		TFT_update_hud3d			; YES
	; valid calibration, but not in use
	tstfsz	lo							; sensor value = 0?
	bra		TFT_update_hud3c			; NO
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
	btfsc	voting_logic_sensor3		; sensor value agrees with values other sensors?
	bra		TFT_update_hud3e			; YES
	; valid calibration, in use, but value does not agree with other sensors
	bsf		win_invert					; invert output
TFT_update_hud3e:
	; all coloring is set up now, let's write the value to the display!
	output_16dp .3						; x.xx bar
	STRCAT_PRINT ""
	bcf		win_invert

TFT_update_hud4:						; closure
	bra		TFT_display_exit_3


	global	TFT_surface_sensor			; update O2 sensor data in surface mode
TFT_surface_sensor:
	bsf		leftbind
	WIN_SMALL surf_hud_sensor1_column,surf_hud_sensor1_row
	btfsc	sensor1_calibrated_ok
	bra		TFT_surface_sensor1			; YES
	btfsc	sensor1_active				; valid HUD data for this sensor
	bra		TFT_surface_sensor1			; YES
	call	TFT_standard_color
	STRCPY_PRINT "--- "
	bra		TFT_surface_sensor2			; skip sensor 1
TFT_surface_sensor1:
	movff	sensor1_ppO2,lo
	call	TFT_color_code_ppo2_hud		; with ppO2 [cbar] in lo
	clrf	hi
	bsf		leftbind
	output_16dp .3						; x.xx bar
	bcf		leftbind
	STRCAT_PRINT ""
TFT_surface_sensor2:
	WIN_SMALL surf_hud_sensor2_column,surf_hud_sensor2_row
	btfsc	sensor2_calibrated_ok
	bra		TFT_surface_sensor3			; YES
	btfsc	sensor2_active				; valid HUD data for this sensor
	bra		TFT_surface_sensor3			; YES
	call	TFT_standard_color
	STRCPY_PRINT "--- "
	bra		TFT_surface_sensor4			; skip sensor 2
TFT_surface_sensor3:
	movff	sensor2_ppO2,lo
	call	TFT_color_code_ppo2_hud		; with ppO2 [cbar] in lo
	clrf	hi
	bsf		leftbind
	output_16dp .3						; x.xx bar
	bcf		leftbind
	STRCAT_PRINT ""
TFT_surface_sensor4:
	WIN_SMALL surf_hud_sensor3_column,surf_hud_sensor3_row
	btfsc	sensor3_calibrated_ok
	bra		TFT_surface_sensor5			; YES
	btfsc	sensor3_active				; valid HUD data for this sensor
	bra		TFT_surface_sensor5			; YES
	call	TFT_standard_color
	STRCPY_PRINT "--- "
	bra		TFT_surface_sensor6			; skip sensor 3
TFT_surface_sensor5:
	movff	sensor3_ppO2,lo
	call	TFT_color_code_ppo2_hud		; with ppO2 [cbar] in lo
	clrf	hi
	bsf		leftbind
	output_16dp .3						; x.xx bar
	bcf		leftbind
	STRCAT_PRINT ""
TFT_surface_sensor6:
TFT_display_exit_3:
	bcf		leftbind
	goto	TFT_standard_color			; and return...


	global	TFT_sensor_mV
TFT_sensor_mV:
	bsf		leftbind

	WIN_SMALL surf_mV_sensor_column,surf_mV_sensor1_row
	SMOVII	sensor1_mv,mpr				; in 0.1mV steps
	STRCAT	"1: "
	rcall	TFT_sensor_mV_helper

	WIN_SMALL surf_mV_sensor_column,surf_mV_sensor2_row
	SMOVII	sensor2_mv,mpr				; in 0.1mV steps
	STRCAT	"2: "
	rcall	TFT_sensor_mV_helper

	WIN_SMALL surf_mV_sensor_column,surf_mV_sensor3_row
	SMOVII	sensor3_mv,mpr				; in 0.1mV steps
	STRCAT	"3: "
	rcall	TFT_sensor_mV_helper
	bcf		leftbind
	
	WIN_SMALL surf_mV_sensor_column,surf_mV_sensor3_row+.24 ; 4th row
	btfss	s8_digital_avail			;  do we have a digital S8 interface?
	bra	TFT_sensor_mV_optical_analog
	STRCAT_PRINT	"Digital"
	bra		TFT_display_exit_3
TFT_sensor_mV_optical_analog:
	btfss	ir_power				;  do we have a optical digital interface?
	bra	TFT_sensor_mV_analog
	STRCAT_PRINT	"Optical"
	bra		TFT_display_exit_3
TFT_sensor_mV_analog:						; -> optical
	STRCAT_PRINT	"Analog"
	bra		TFT_display_exit_3

TFT_sensor_mV_helper:
	output_16dp .4						; xxx.y mV
	STRCAT_PRINT "mV "
	return


	global	TFT_sensor_surface_warning
TFT_sensor_surface_warning: 
	call	TFT_warning_color
	btfss	sensor1_calibrated_ok		; do not show end of lifetime arrow if sensor failed calibration at all
	bra		TFT_sensor_mV2
	movff	opt_x_s1+1,lo				; into bank1
	movf	lo,W						; when opt_x_s1 > 255 the sensor will just give 8 mV at a ppO2 of 0.21 any more 
	bz		TFT_sensor_mV2				; the sensor is not too bad yet for a warning 
	WIN_SMALL surf_mV_sensor_status_column,surf_mV_sensor1_row-.5 
	STRCPY_PRINT "\xb8"					; mark sensor as being at end of lifetime
TFT_sensor_mV2:
	btfss	sensor2_calibrated_ok		; do not show end of lifetime arrow if sensor failed calibration at all
	bra		TFT_sensor_mV3
	movff	opt_x_s2+1,lo				; into bank1
	movf	lo,W						; when opt_x_s2 > 255 the sensor will just give 8 mV at a ppO2 of 0.21 any more 
	bz		TFT_sensor_mV3				; the sensor is not too bad yet for a warning 
	WIN_SMALL surf_mV_sensor_status_column,surf_mV_sensor2_row-.5 
	STRCPY_PRINT "\xb8"					; mark sensor as being at end of lifetime 
TFT_sensor_mV3:
	btfss	sensor3_calibrated_ok		; do not show end of lifetime arrow if sensor failed calibration at all
	bra		TFT_sensor_mV4
	movff	opt_x_s3+1,lo				; into bank1
	movf	lo,W						; when opt_x_s3 > 255 the sensor will just give 8 mV at a ppO2 of 0.21 any more 
	bz		TFT_sensor_mV4				; the sensor is not too bad yet for a warning 
	WIN_SMALL surf_mV_sensor_status_column,surf_mV_sensor3_row-.5
	STRCPY_PRINT "\xb8"					; mark sensor as being at end of lifetime 
TFT_sensor_mV4:
	bra		TFT_display_exit_3


	global	TFT_menu_calibrate
TFT_menu_calibrate:						; update mV data in calibration menu
	btfss	s8_digital_avail			; do we have a digital S8 interface?
	bra		TFT_menu_calibrate_analog	; NO  - use analog
	btfss	trigger_S8_data_update		; YES - new data frame received?
	bra		TFT_menu_calibrate_common	;       NO  - use old values...
	bcf		trigger_S8_data_update		;       YES - clear update flag
	call	compute_mvolts_for_all_sensors ;        - compute mV values from received data frame
	bra		TFT_menu_calibrate_common	;           - continue with common part
TFT_menu_calibrate_analog:
	call	get_analog_inputs			; read mV values from analog inputs
TFT_menu_calibrate_common:
	call	TFT_attention_color			; show in yellow
	bsf		leftbind					; align to the left
	WIN_SMALL	surf_menu_sensor1_column,surf_menu2_sensor1_row
	SMOVII	sensor1_mv,mpr				; in 0.1mV steps
	output_16dp .4						; xxx.y mV
	STRCAT_PRINT "mV  "
	WIN_SMALL	surf_menu_sensor2_column,surf_menu2_sensor2_row
	SMOVII	sensor2_mv,mpr				; in 0.1mV steps
	output_16dp .4						; xxx.y mV
	STRCAT_PRINT "mV  "
	WIN_SMALL	surf_menu_sensor3_column,surf_menu2_sensor3_row
	SMOVII	sensor3_mv,mpr				; in 0.1mV steps
	output_16dp .4						; xxx.y mV
	STRCAT_PRINT "mV  "
	TSTOSS	opt_s8_mode					; =0: analog, =1: digital RS232
	bra		TFT_display_exit_3			; analog - done
	; also imprint HUD battery voltage
	WIN_TINY .20,.209					; digital
	STRCPY	"HUD Batt: "				; print label
	SMOVII	hud_battery_mv,mpr			; get HUD battery voltage
	output_16dp .2						; print as -x.yyy
	STRCAT_PRINT "V "					; finalize output
	bra		TFT_display_exit_3			; done

 ENDIF	; _external_sensor

;=============================================================================

	global	TFT_time_surfmode
TFT_time_surfmode:
	WIN_SMALL surf_clock_column+.7,surf_clock_row
TFT_clock2:								; called from dive mode clock
	call	TFT_standard_color
	SMOVSS	rtc_year,rtc_latched_year	; ISR-safe 6 byte copy of date and time
	movff	rtc_latched_hour,lo
	output_99
	movlw	':'
	movff	rtc_latched_secs,lo
	btfss	lo,0						; blinking every second
	movlw	' '
	movwf	POSTINC2
	movff	rtc_latched_mins,lo
	output_99x
	STRCAT_PRINT ""
	return


	global	TFT_show_time_date_menu
	global	TFT_show_time_date_menu_fast
TFT_show_time_date_menu:
	SMOVSS	rtc_year,rtc_latched_year	; ISR-safe 6 byte copy of current date & time
TFT_show_time_date_menu_fast:
	WIN_SMALL .20,.40					; column, row - keep clear of the cursor area on the left!
	call	TFT_standard_color
	movff	rtc_latched_hour,lo
	output_99
	PUTC	':'
	movff	rtc_latched_mins,lo
	output_99x
	PUTC	':'
	movff	rtc_latched_secs,lo
	output_99x
	STRCAT	"  "
	movff	rtc_latched_year, lo
	movff	rtc_latched_month,hi
	movff	rtc_latched_day,  up
	call	TFT_convert_date			; convert into "DD/MM/YY" or "MM/DD/YY" or "YY/MM/DD" in postinc2
	STRCAT_PRINT " "
	return

;=============================================================================

	global	TFT_surface_decosettings	; show all deco settings
TFT_surface_decosettings:
	; Deco Mode
	call	TFT_standard_color
	WIN_SMALL surf_gaslist_column,surf_gaslist_row
	STRCAT_PRINT "ZH-L16"
	movff	char_I_model,WREG
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
	STRCPY_TEXT tGF						; GF:
	movff	opt_GF_low,lo
	output_99x
	STRCAT	"/"
	movff	opt_GF_high,lo
	output_99x
	STRCAT_PRINT ""
TFT_surface_decosettings2:				; fTTS
	WIN_SMALL surf_gaslist_column,surf_gaslist_row+(surf_gaslist_spacing*.2)
	STRCPY_TEXT tFTTSSurf
	movff	char_I_extra_time,lo
	bsf		leftbind
	output_8
	STRCAT_TEXT_PRINT tMinutes
	; Last Stop
	WIN_SMALL surf_gaslist_column,surf_gaslist_row+(surf_gaslist_spacing*.3)
	STRCPY_TEXT tLastDecostopSurf
	movff	opt_last_stop,lo
	output_8
	STRCAT_TEXT_PRINT tMeters
	; Salinity
	WIN_SMALL surf_gaslist_column,surf_gaslist_row+(surf_gaslist_spacing*.4)
	STRCPY_TEXT tDvSalinitySurf
	movff	opt_salinity,lo
	output_8
	bcf		leftbind
	STRCAT_TEXT_PRINT tPercent
	return


	global	TFT_divetimeout
TFT_divetimeout:
	call	TFT_set_message_window		; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO - skip message in this cycle
	call	TFT_memo_color
	STRCPY	0x94						; "End of dive" symbol
	movff	opt_diveTimeout,WREG		; in [min]
	mullw	.60
	MOVII	PRODL,             sub_a	; in seconds
	MOVII	dive_timeout_timer,sub_b
	call	subU16						; sub_c = sub_a - sub_b (with UNSIGNED values)
	MOVII	sub_c,mpr
	call	convert_time				; convert hi:lo in minutes to hours (up:hi) and minutes (lo)
	movf	hi,W						; swap lo and hi
	movff	lo,hi						; ...
	movwf	lo							; ...
	output_99x
	PUTC	':'
	movff	hi,lo						; copy hi to lo
	output_99x
	movlw	dm_warning_length			; dive mode string length
	call	TFT_fillup_with_spaces		; fill up FSR2 with spaces (total string length in #WREG)
	STRCAT_PRINT ""
	bcf		win_invert
	return


	global	TFT_show_ftts
TFT_show_ftts:
	call	TFT_set_message_window		; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO  - skip message in this cycle
	bsf		leftbind					; print with alignment to the left
 IFDEF _cave_mode
	btfss	cave_mode					; cave mode switched on?
	bra		TFT_display_ftts_2			; NO  - classic open water TTS
	btfss	dive_turned					; YES - dive turned?
	bra		TFT_display_ftts_1			;       NO  - cTTS from current position
	STRCPY	"WP"						;       YES - print waypoint mark
	movf	backtrack_waypoint_num,W	;           - copy current waypoint number to WREG
	cpfseq	backtrack_waypoint_turn		;           - current waypoint = turn point ?
	bra		TFT_display_ftts_0			;             NO - print waypoint number
	STRCAT	"-| "						;             YES - print turn point symbol
	bra		TFT_display_ftts_5			;                 - continue with TTS
TFT_display_ftts_0:
	movwf	lo							; copy current waypoint number to lo
	output_99							; print waypoint number
	PUTC	" "							; append a space char
	bra		TFT_display_ftts_5			; continue with TTS
TFT_display_ftts_1:
	STRCPY	"cTTS "						; print cave TTS label followed by a space
	bra		TFT_display_ftts_5			; continue with TTS
 ENDIF	; _cave_mode
TFT_display_ftts_2:
	btfsc	FLAG_oc_mode				; in OC mode?
	bra		TFT_display_ftts_3			; YES - print fTTS label
	TSTOSS	opt_calc_gasvolume			; NO  - bailout volume calculation requested?
	bra		TFT_display_ftts_3			;       NO  - print fTTS label
	STRCPY	"B/O"						;       YES - print bailout label
	bra		TFT_display_ftts_4			;           - continue
TFT_display_ftts_3:						; OC or CCR/pSCR but no bailout volume calculation
	STRCPY	"@+"						; print fTTS label
TFT_display_ftts_4:
	movff	char_I_extra_time,lo		; get   fTTS delay time
	output_8							; print fTTS delay time
	PUTC	":"							; ":"
TFT_display_ftts_5:
	MOVII	int_O_TTS_alt,mpr			; get alternative TTS
	call	TFT_memo_color				; set memo color
	btfss	hi,int_invalid_flag			; is the invalid flag set?
	bra		TFT_display_ftts_6			; NO  - keep memo color
	bcf		hi,int_invalid_flag			; YES - clear flag
	call	TFT_disabled_color			;     - switch to disabled color
TFT_display_ftts_6:
	btfsc	hi,int_not_yet_computed		; is the not-yet-computed flag set?
	bra		TFT_display_ftts_8			; YES - show dashes
 IFDEF _cave_mode
	btfsc	cave_mode					; cave mode switched on?
	bra		TFT_display_ftts_7			; YES - take shortcut
 ENDIF
	movff	int_O_TST_alt+1,WREG		; get high byte of the alternative total stops time
	btfsc	WREG,int_is_zero			; total stops time = zero ?
	bra		TFT_display_ftts_9			; YES - show "NDL"
	btfsc	WREG,deco_zone				; NO  - fTTS <= TTS ?
	call	TFT_advice_color			;       YES - set to advice color (green)
TFT_display_ftts_7:
	output_16							; print ascent time
	PUTC	"'"							; print minutes symbol
	bra		TFT_display_ftts_10			; continue
TFT_display_ftts_8:
	STRCAT	"---"						; print "---" for not computed
	bra		TFT_display_ftts_10			; continue
TFT_display_ftts_9:
	STRCAT_TEXT tNDL					; print "NDL"
TFT_display_ftts_10:
	movlw	dm_warning_length			; dive mode string length
	call	TFT_fillup_with_spaces		; fill up FSR2 with spaces (total string length in #WREG)
	STRCAT_PRINT ""						; finalize output
	bcf		leftbind					; clear left alignment
	goto	TFT_standard_color			; ...and return


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
	call	TFT_memo_color
	bra		TFT_temp_common


	global	TFT_show_temp_divemode
TFT_show_temp_divemode:
	btfsc	dive_options_menu				; is the pre-menu shown?
	return									; YES - abort
	btfsc	dive_main_menu					; is the dive mode menu shown?
	return									; YES - abort, no update of temperature now
	btfsc	better_gas_blinking				; blinking better gas?
	return									; YES - abort, no update of temperature now
	btfsc	better_dil_blinking				; blinking better diluent?
	return									; YES - abort, no update of temperature now

	WIN_SMALL dm_temp_column,dm_temp_row	; set position
	call	TFT_memo_color					; set color
	movlw	index_compass_dm				; index of compass custom view
	cpfseq	active_customview				; compass shown in custom view?
	bra		TFT_temp_common					; NO  - proceed with temperature
	goto	TFT_update_stopwatch			; YES - show resettable dive time instead of temperature
TFT_temp_common:
	SMOVII	temperature_cur,mpr				; ISR-safe 2 byte copy of current temperature to hi:lo
	TSTOSC	opt_units						; 0=°C, 1=°F
	call	convert_celsius_to_fahrenheit	; 1 - convert value in lo:hi from Celsius to Fahrenheit
	rcall	TFT_convert_signed_16bit		; convert lo:hi into signed-short and adds '-' to POSTINC2 if required
	btfsc	neg_flag						; is the temperature negative?
	bra		TFT_temp_common_2				; YES - the minus sign has already been written
	; temp is positive, is it less than 10°C ?
	tstfsz	hi
	bra		TFT_temp_common_1				; > 25.5°C, skip here
	movlw	.100
	cpfslt	lo
	bra		TFT_temp_common_1				; > 10.0°C, skip here
	bsf		leftbind
	output_16dp d'4'						; x.y°C
	bcf		leftbind
	bra		TFT_temp_common_3				; done
TFT_temp_common_1:
	PUTC	" "								; NO  - write a space instead of the minus sign
TFT_temp_common_2:
	bsf		ignore_digit5					; ignore decimal (flag will be cleared by output_16)
	output_16_3								; output 0-999 without decimal -> writes ' ' - 99
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
TFT_temp_common_6:
	goto	TFT_standard_color				; done


;=============================================================================

	global	TFT_show_menu_cursor_divemode
TFT_show_menu_cursor_divemode:
	WIN_BOX_BLACK dm_menu_row+.1, dm_menu_lower-.1, dm_menu_item1_column-.8, dm_menu_item1_column-.1
	WIN_BOX_BLACK dm_menu_row+.1, dm_menu_lower-.1, dm_menu_item4_column-.8, dm_menu_item4_column-.1
	call	TFT_standard_color

	movlw	dm_menu_item1_column-.8
	btfsc	menu_pos_cur,2				; > 3 ?
	movlw	dm_menu_item4_column-.8		; YES
	movwf	win_leftx2

	movff	menu_pos_cur,lo				; copy menu position
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
	movwf	win_top
	movlw	FT_SMALL
	movwf	win_font
	STRCPY_PRINT "\xb7"					; print cursor
	return

;=============================================================================

	global	TFT_show_active_gas_divemode
TFT_show_active_gas_divemode:			; display gas (OC) or setpoint/ppO2 & gas (CCR, pSCR)
	btfsc	dive_main_menu				; is the dive mode menu shown?
	return								; YES - abort
	btfsc	FLAG_apnoe_mode				; in apnoe mode?
	return								; YES - done
	btfsc	FLAG_gauge_mode				; in gauge mode?
	return								; YES - done

 IFDEF _ccr_pscr
	btfsc	FLAG_oc_mode				; in OC mode?
	bra		TFT_active_gas				; YES - show OC gas
	;bra	TFT_active_sp				; NO  - show setpoint and diluent

TFT_active_sp:
	btfss	bailout_mode				; in bailout?
	bra		TFT_active_sp_loop			; NO
	;bra	TFT_active_sp_bailout		; YES

TFT_active_sp_bailout:
	WIN_SMALL dm_active_dil_column, dm_active_dil_row
	call	TFT_attention_color			;     - set color
	STRCPY_TEXT_PRINT tDiveBailout		;     - print "Bailout"
	bra		TFT_active_gas				;     - continue showing OC bailout gas

TFT_active_sp_loop:
	MOVII	int_O_breathed_ppO2,mpr		; copy ppO2 [cbar] to hi:lo
	call	TFT_color_code_ppo2			; color-code the output by the ppO2 of the loop gas mixture
	btfss	timebase_1sec				; on even second?
	bra		TFT_active_sp_print			; YES - print ppO2 with normal rendering
	btfsc	sp_fallback					; NO  - check if in fallback condition
	bra		TFT_active_sp_fallback		;       YES - process fallback case
	movff	int_O_breathed_ppO2+1,WREG	;       NO  - get flags again (have been cleared in hi:lo by TFT_color_code_ppo2 meanwhile)
	btfss	WREG,int_warning_flag		;             warning flag set?
	bra		TFT_active_sp_print			;             NO  - ppO2 is ok, print ppO2 with normal rendering
	bra		TFT_active_sp_invers		;             YES - print with inverse rendering
TFT_active_sp_fallback:					; set up fallback case
	call	TFT_attention_color			; set color to yellow
TFT_active_sp_invers:					; blinking common part
	bsf		win_invert					; print in inverse
TFT_active_sp_print:					; set position
	WIN_MEDIUM dm_active_gas_sp_value_col, dm_active_gas_sp_value_row
	bsf		leftbind					; print left-aligned
	output_16dp .3						; print ppO2 as x.xx
	bcf		leftbind					; back to right alignment
	STRCAT_PRINT ""						; finalize output
	bcf		win_invert					; end inverse printing

	btfsc	sign_shown					; advice/attention/warning sign shown?
	bra		TFT_active_diluent			; YES - skip display of "bar" and loop mode

	btfsc	velocity_active_vsi			; graphical vertical speed indicator shown?
	bra		TFT_active_diluent			; YES - skip display of "bar" and loop mode

TFT_active_sp_label:
	WIN_STD dm_active_sp_label_col, dm_active_sp_label_row
	call	TFT_memo_color				; select memo color
	STRCAT	"bar"						; print "bar"
 IFDEF _external_sensor
	movff	opt_ccr_mode,WREG			; get setpoint mode =0: Fixed SP, =1: Sensor, =2: Auto SP
	sublw	.1							; opt_ccr_mode = 1 (Sensor) ?
	bnz		TFT_active_sp_label_1		; NO  - skip
	btfsc	alt_layout_active			; YES - in alternative layout?
	bra		TFT_active_sp_label_1		;       YES - no space available for the "*"
	PUTC	"*"							;       NO  - add "*"
TFT_active_sp_label_1:
 ENDIF
	STRCAT_PRINT ""						; finalize output

TFT_active_loop_mode:
	WIN_TINY dm_active_sp_label_col, dm_active_dil_row+.3
	call	TFT_memo_color				; set memo color
	btfsc	FLAG_ccr_mode				; in CCR mode?
	bra		TFT_active_loop_mode_ccr	; YES - print CCR label
	btfsc	FLAG_pscr_mode				; in pSCR mode?
	bra		TFT_active_loop_mode_pscr	; YES - print pSCR label
	bra		TFT_active_diluent			; NO  to both - should not happen
TFT_active_loop_mode_ccr:
	STRCPY_TEXT_PRINT tDvCCR			; print "CCR"
	bra		TFT_active_diluent			; continue with diluent
TFT_active_loop_mode_pscr:
	STRCPY_TEXT_PRINT tDvPSCR			; print "pSCR"
	;bra	TFT_active_diluent			; continue with diluent

TFT_active_diluent:
	MOVII	int_O_pure_ppO2,mpr			; get ppO2 [cbar] into hi:lo
	call	TFT_color_code_ppo2			; color-code the output
	btfss	better_dil_available		; better diluent available?
	bra		TFT_active_diluent_show		; NO  - print in normal rendering
	btg		better_dil_blinking			; YES - toggle blink bit...
	btfss	better_dil_blinking			; blink now?
	bra		TFT_active_diluent_show		; NO  - print in normal rendering
	call	TFT_attention_color			; YES - print in yellow color
	bsf		win_invert					;     - print in inverse
TFT_active_diluent_show:
	WIN_SMALL dm_active_dil_column, dm_active_dil_row
	bra		TFT_active_dil_gas_common	; continue with common part
 ENDIF	; _ccr_pscr

TFT_active_gas:
	MOVII	int_O_breathed_ppO2,mpr		; copy ppO2 [cbar] into hi:lo
	call	TFT_color_code_ppo2			; color-code the output
	btfss	better_gas_available		; better gas available?
	bra		TFT_active_gas_print		; NO  - print in normal rendering
	btg		better_gas_blinking			; YES - toggle blink bit
	btfss	better_gas_blinking			;       blink now?
	bra		TFT_active_gas_print		;       NO  - print in normal rendering
	call	TFT_attention_color			;       YES - blink in yellow
	bsf		win_invert					;             print in inverse
TFT_active_gas_print:
	WIN_STD	dm_active_gas_sp_value_col, dm_active_sp_label_row
TFT_active_dil_gas_common:
	movff	char_I_O2_ratio,lo			; lo now stores O2 in %
 IFDEF _helium
	movff	char_I_He_ratio,hi			; hi now stores He in %
 ELSE
	clrf	hi							; set hi to zero (no He)
 ENDIF
	call	gaslist_show_mix			; print "Nxlo", "Txlo/hi", "Air" or "O2"
	STRCAT_PRINT ""						; finalize output
	bcf		win_invert					; end inverse printing
	goto	TFT_standard_color			; done

;=============================================================================

	global	TFT_decotype_surface
TFT_decotype_surface:
	WIN_STD	surf_decotype_column,surf_decotype_row
	WIN_COLOR color_lightblue
	movff	opt_dive_mode,lo				; 0=OC, 1=CCR, 2=Gauge, 3=Apnoe, 4=pSCR
	tstfsz	lo								; in OC mode?
	bra		TFT_decotype_surface_2			; NO
TFT_decotype_surface_1:
	STRCAT_TEXT_PRINT tDvOC					; OC
	bra		TFT_display_decotype_exit
TFT_decotype_surface_2:
	decfsz	lo,F							; in CCR mode?
	bra		TFT_decotype_surface_3			; NO
 IFDEF _ccr_pscr
	STRCAT_TEXT_PRINT tDvCC					; YES
	call	TFT_standard_color
	WIN_TINY surf_decotype_column+.18,surf_decotype_row+.12
	TSTOSS	opt_ccr_mode					; > 0, i.e. not Fixed SP ?
	bra		TFT_display_decotype_cc_fixed	; NO - fixed then
 IFDEF _external_sensor
	; Sensor or Auto SP mode
	movff	opt_ccr_mode,WREG				; =0: Fixed SP, =1: Sensor, =2: Auto SP
	sublw	.2								; mode = Auto SP ?
	bz		TFT_display_decotype_cc_auto	; YES 
	STRCPY_TEXT tCCRModeSensor				; NO  - Sensor
	bra		TFT_display_decotype_cc_common	;
 ENDIF	; _external_sensor
TFT_display_decotype_cc_auto:
	STRCPY_TEXT tCCRModeAutoSP				; Auto SP
	bra		TFT_display_decotype_cc_common
TFT_display_decotype_cc_fixed:
	STRCPY_TEXT tCCRModeFixedSP				; fixed SP
TFT_display_decotype_cc_common:
	clrf	WREG
	movff	WREG,buffer+.8					; limit string length to 8
	STRCAT_PRINT ""
	bra		TFT_display_decotype_exit
 ENDIF	; _ccr_pscr
TFT_decotype_surface_3:
	decfsz	lo,F							; in gauge mode?
	bra		TFT_decotype_surface_4			; NO
TFT_decotype_surface_3_1:					; YES
	STRCAT_TEXT_PRINT tDvGauge
	bra		TFT_display_decotype_exit
TFT_decotype_surface_4:
	decfsz	lo,F							; in apnea mode?
	bra		TFT_decotype_surface_5			; NO
TFT_decotype_surface_4_1:					; YES
	STRCAT_TEXT_PRINT tDvApnea
	bra		TFT_display_decotype_exit
TFT_decotype_surface_5:
	STRCAT_TEXT_PRINT tDvPSCR				; last but not least: must be pSCR then
TFT_display_decotype_exit:
	goto	TFT_standard_color				; and return...


	global	TFT_decotype_logbook
TFT_decotype_logbook:						; used from logbook and from deco calculator (simulator.asm)
	bsf		aux_flag						; default to dive with deco calculation
	tstfsz	lo								; lo holds 0=OC, 1=CCR, 2=Gauge, 3=Apnea, 4=pSCR, in OC mode?
	bra		TFT_decotype_logbook_1_2		; NO
	bra		TFT_decotype_surface_1			; YES - OC
TFT_decotype_logbook_1_2:
	decfsz	lo,F							; in CCR mode?
	bra		TFT_decotype_logbook_1_3		; NO
	STRCAT_TEXT_PRINT tDvCC					; YES - print "CCR"
	bra		TFT_display_decotype_exit		;     - done
TFT_decotype_logbook_1_3:
	decfsz	lo,F							; in gauge mode?
	bra		TFT_decotype_logbook_1_4		; NO
	bcf		aux_flag						; YES - dive without deco data
	bra		TFT_decotype_surface_3_1		;     - gauge
TFT_decotype_logbook_1_4:
	decfsz	lo,F							; in apnea mode?
	bra		TFT_decotype_logbook_1_5		; NO
	bcf		aux_flag						; YES - dive without deco data
	bra		TFT_decotype_surface_4_1		;     - apnea
TFT_decotype_logbook_1_5:
	bra		TFT_decotype_surface_5			; last but not least: must be pSCR then

;=============================================================================

 IFDEF _ccr_pscr

	global	TFT_splist_surfmode			; show setpoint list
TFT_splist_surfmode:
	bsf		short_gas_descriptions		; use short versions of gaslist_strcat_gas_cd and gaslist_strcat_setpoint
	bcf		better_gas_hint				; do not mark the best gas/diluent (to be used in dive mode only)
	;SP 1
	WIN_SMALL surf_gaslist_column,surf_gaslist_row
	clrf	PRODL
	call	gaslist_strcat_setpoint		; show SP#+1 of PRODL#
	STRCAT_PRINT ""
	;SP 2
	WIN_SMALL surf_gaslist_column,surf_gaslist_row+(surf_gaslist_spacing*.1)
	movlw	.1
	movwf	PRODL
	call	gaslist_strcat_setpoint		; show SP#+1 of PRODL#
	STRCAT_PRINT ""
	;SP 3
	WIN_SMALL surf_gaslist_column,surf_gaslist_row+(surf_gaslist_spacing*.2)
	movlw	.2
	movwf	PRODL
	call	gaslist_strcat_setpoint		; show SP#+1 of PRODL#
	STRCAT_PRINT ""
	;SP 4
	WIN_SMALL surf_gaslist_column,surf_gaslist_row+(surf_gaslist_spacing*.3)
	movlw	.3
	movwf	PRODL
	call	gaslist_strcat_setpoint		; show SP#+1 of PRODL#
	STRCAT_PRINT ""
	;SP 5
	WIN_SMALL surf_gaslist_column,surf_gaslist_row+(surf_gaslist_spacing*.4)
	movlw	.4
	movwf	PRODL
	call	gaslist_strcat_setpoint		; show SP#+1 of PRODL#
	STRCAT_PRINT ""
	bcf		leftbind
	return

 ENDIF

;=============================================================================

	global	TFT_gaslist_surfmode
TFT_gaslist_surfmode:					; displays gas list
	bsf		short_gas_descriptions		; use short versions of gaslist_strcat_gas_cd and gaslist_strcat_setpoint
	bcf		better_gas_hint				; do not mark the best gas/diluent (to be used in dive mode only)
	;Gas 1
	WIN_SMALL surf_gaslist_column,surf_gaslist_row
	clrf	PRODL
	call	gaslist_strcat_gas_cd		; append gas description of gas #PRODL (0-4) to current string
	STRCAT_PRINT ""
	;Gas 2
	WIN_SMALL surf_gaslist_column,surf_gaslist_row+(surf_gaslist_spacing*.1)
	movlw	.1
	movwf	PRODL
	call	gaslist_strcat_gas_cd		; append gas description of gas #PRODL (0-4) to current string
	STRCAT_PRINT ""
	;Gas 3
	WIN_SMALL surf_gaslist_column,surf_gaslist_row+(surf_gaslist_spacing*.2)
	movlw	.2
	movwf	PRODL
	call	gaslist_strcat_gas_cd		; append gas description of gas #PRODL (0-4) to current string
	STRCAT_PRINT ""
	;Gas 4
	WIN_SMALL surf_gaslist_column,surf_gaslist_row+(surf_gaslist_spacing*.3)
	movlw	.3
	movwf	PRODL
	call	gaslist_strcat_gas_cd		; append gas description of gas #PRODL (0-4) to current string
	STRCAT_PRINT ""
	;Gas 5
	WIN_SMALL surf_gaslist_column,surf_gaslist_row+(surf_gaslist_spacing*.4)
	movlw	.4
	movwf	PRODL
	call	gaslist_strcat_gas_cd		; append gas description of gas #PRODL (0-4) to current string
	STRCAT_PRINT ""
	bcf		leftbind
	bcf		win_invert					; clear flag for inverted output
	return

;=============================================================================

 IFDEF _ccr_pscr

	global	TFT_dillist_surfmode
TFT_dillist_surfmode:					; displays diluent list
	bsf		is_diluent_menu				; enable using diluents
	rcall	TFT_gaslist_surfmode		; use OC gas routine
	bcf		is_diluent_menu				; disable using diluents
	return

 ENDIF

;==================================================================

	global	TFT_show_depth
TFT_show_depth:
	MOVII	pressure_rel_cur_cached,mpr	; copy relative pressure to MPR
	call	convert_pres_to_depth		; convert pressure in [mbar] to depth in [cm]
	call	TFT_color_code_depth		; set warning / attention flags and color-code the output
	rcall	TFT_depth_blink				; control animation (blinking)
	rcall	TFT_depth_position_m_ft		; set output position

	TSTOSS	opt_units					; 0=m, 1=ft ?
	bra		TFT_depth_metric			; 0 - metric
	;bra	TFT_depth_imperial			; 1 - imperial

TFT_depth_imperial:
	MOVLI	.30,sub_a					; display 0 ft if shallower than 30 cm
	MOVII	mpr,sub_b
	call	cmpU16						; compare (sub_a - sub_b)
	btfss	neg_flag					; depth shallower than 30 cm ?
	bra		depth_0_feet				; YES - print a zero directly
	call	convert_cm_to_feet			; NO  - convert value in hi:lo from [cm] to [feet]
	output_16_3							;     - feet in large or huge font
	STRCAT_PRINT ""						;     - finalize output
TFT_depth_imperial_1:
	bcf		win_invert					;      - reset invert flag
	bra		TFT_depth_exit			;      - show target depth if in simulator mode and return

depth_0_feet:
	STRCAT_PRINT "  0"					; print a zero directly
	bra		TFT_depth_imperial_1		; continue with common part

TFT_depth_metric:
	; full meters
	MOVLI	.9999,sub_a					; 9999 mbar = 99.99 m
	MOVII	mpr,  sub_b					; current depth
	call	cmpU16						; compare (sub_a - sub_b)
	btfsc	neg_flag					; current depth < 100 meter ?
	bra		TFT_depth_metric_100m		; NO  - current depth >= 100 meter

	btfsc	cur_depth_greater_100m		; was the current depth >= 100 meter during last call?
	rcall	TFT_depth_box_black			; YES - clear depth area
	bcf		cur_depth_greater_100m		; current depth is now < 100 meter

	MOVLI	.999,sub_a					; 999 mbar = 9.99 meter
	MOVII	mpr, sub_b					; current depth
	call	cmpU16						; compare (sub_a - sub_b)
	movlw	' '							; load coding of a space char
	btfss	neg_flag					; current depth < 10 meter ?
	movwf	POSTINC2					; YES - print a leading space char

	MOVLI	.99,sub_a					; 99 mbar = 99 cm
	MOVII	mpr,sub_b					; current depth
	call	cmpU16						; compare (sub_a - sub_b)
	btfss	neg_flag					; current depth < 1 meter ?
	bra		TFT_depth_metric_0m			; YES - (1)
	bsf		ignore_digit4				; NO  - show depth in full meters, i.e. ignore digits 4 and 5
	bsf		leftbind					;     - print left-aligned
	output_16							;     - print depth
	bcf		leftbind					;     - reset alignment
	bra		TFT_depth_metric_com		;     - continue with common part
TFT_depth_metric_0m:
	STRCAT	"0"							; (1) - print a zero directly
TFT_depth_metric_com:
	STRCAT_PRINT ""						; finalize output

	; decimeters
	rcall	TFT_depth_position_dm		; set output position
	PUTC	"."							; print a decimal point
	MOVLI	.30,sub_a					; 30 mbar = 0.3 meter
	MOVII	mpr,sub_b					; current depth
	call	cmpU16						; compare (sub_a - sub_b)
	btfss	neg_flag					; current depth < 0.3 meter ?
	bra		depth_0_decimeter			; YES - (2)
	movlw	d'4'						; NO  - omit leading digits holding the meters
	movwf	ignore_digits				;     - ...
	bsf		ignore_digit5				;     - omit last digit holding the centimeters
	output_16dp d'0'					;     - print decimeters only
	STRCAT_PRINT ""						;     - finalize output
	bcf		win_invert					;     - reset invert flag
	bra		TFT_depth_exit				;     - show target depth if in simulator mode and return
depth_0_decimeter:
	STRCAT_PRINT "0"					; (2) - print a zero directly and finalize output
	bcf		win_invert					;     - reset invert flag
	bra		TFT_depth_exit				;     - show target depth if in simulator mode and return

TFT_depth_metric_100m:					; show full meters only
	btfss	cur_depth_greater_100m		; was the current depth >= 100 meter during last call?
	rcall	TFT_depth_box_black			; NO - clear depth area
	bsf		cur_depth_greater_100m		; depth is >= 100 meter now
	bsf		ignore_digit4				; show depth in full meters, i.e. ignore digits 4 and 5
	bsf		leftbind					; print left-aligned
	output_16							; print depth
	bcf		leftbind					; reset alignment
	STRCAT_PRINT ""						; finalize output
	bcf		win_invert					; reset invert flag
	bra		TFT_depth_exit				; show target depth if in simulator mode and return

TFT_depth_blink:
	TSTOSS	opt_depth_warn				; 0=standard, 1=blink
	return								; standard, done
	btfsc	depth_warn_att_last			; was there a warning or attention on the depth in the previous cycle?
	bra		TFT_depth_blink_prev		; YES
	btfsc	depth_warning				; NO  - do we have a depth warning now?
	bra		TFT_depth_blink_new			;       YES - so we have a warning now but not previously
	btfsc	depth_attention				;       NO  - do we have a depth attention now?
	bra		TFT_depth_blink_new			;             YES - so we have attention now but not previously
	bra		TFT_depth_blink_none		;             NO  - no warning in previous cycle, no warning now, reset all flags

TFT_depth_blink_prev:
	; we had a warning or attention in previous cycle, check if we still have a warning or attention
	btfsc	depth_warning				; do we still have a warning?
	bra		TFT_depth_blink_prev_1		; YES
	btfsc	depth_attention				; NO  - do we still have an attention?
	bra		TFT_depth_blink_prev_1		;       YES
	; we had a warning or attention before, but not now any more - clear depth area from previous color
	rcall	TFT_depth_box_black			;       NO  - clear depth area
	;bra	TFT_depth_blink_none		;           - reset all flags

TFT_depth_blink_none:
	bcf		win_invert					; print non-inverted
	bcf		depth_inverse_last			; memorize depth was printed in normal
	bcf		depth_warn_att_last			; memorize there was no warning or attention
	goto	TFT_memo_color				; select memo color and return

TFT_depth_blink_prev_1:
	; we had a warning or attention in previous cycle, and we still have a warning or attention
	btfss	depth_inverse_last			; was the depth printed in inverse last time?
	bra		TFT_depth_blink_set			; NO  - print in inverse now
	bra		TFT_depth_blink_reset		; YES - print in normal  now

TFT_depth_blink_new:
	; we had no warning or attention in previous cycle, but now
	bsf		depth_warn_att_last			; memorize that the depth had a warning or attention
	;bra	TFT_depth_blink_set			; start with inverse display

TFT_depth_blink_set:
	; fill the area with respective color
	call	TFT_attention_color_dive	; select attention color as default
	btfsc	depth_warning				; do we have a warning?
	call	TFT_warnings_color_dive		; YES - replace with warning color
	rcall	TFT_depth_box_color			; color depth area
	bsf		win_invert					; print in inverse
	bsf		depth_inverse_last			; memorize depth was printed in inverse
	return								; done

TFT_depth_blink_reset:
	; fill the area with black color
	rcall	TFT_depth_box_black			; clear depth area
	bcf		win_invert					; print non-inverted
	bcf		depth_inverse_last			; memorize depth was printed in normal
	return								; done


TFT_depth_position_m_ft:
	btfsc	alt_layout_active									; alternative layout active?
	bra		TFT_depth_position_m_ft_alt							; YES - (1)
	WIN_LARGE dm_depth_col_large,dm_depth_row_large				; NO  - normal layout
	return														;     - done
TFT_depth_position_m_ft_alt:
	WIN_HUGE dm_depth_col_huge, dm_depth_row_huge				; (1) - alternative layout
	return														;     - done

TFT_depth_position_dm:
	btfsc	alt_layout_active									; alternative layout active?
	bra		TFT_depth_position_dm_alt							; YES - (1)
	WIN_MEDIUM dm_depth_dm_col_medium, dm_depth_dm_row_medium	; NO  - normal layout
	return														;     - done
TFT_depth_position_dm_alt:
	WIN_LARGE  dm_depth_dm_col_large,  dm_depth_dm_row_large	; (1) - alternative layout
	return														;     - done

TFT_depth_box_black:
	clrf	WREG																				; select black color
TFT_depth_box_color:
	movff	win_color1,mpr+2																	; backup output color
	movff	win_color2,mpr+3																	; ...
	btfsc	alt_layout_active																	; alternative layout active?
	bra		TFT_depth_box_alt																	; YES - (1)
	WIN_BOX_COLOR dm_depth_row_large,dm_depth_bot_large,dm_depth_col_large,dm_depth_rgt_large	; NO  - top, bottom, left, right
	bra		TFT_depth_box_exit																	;     - continue with common part
TFT_depth_box_alt:
	WIN_BOX_COLOR dm_mask_depth_row, dm_depth_bot_huge, dm_depth_col_huge, dm_depth_rgt_huge	; (1) - full meters area
TFT_depth_box_exit:
	movff	mpr+2,win_color1																	; restore output color
	movff	mpr+3,win_color2																	; ...
	return																						; done

TFT_depth_exit:
	btfss	alt_layout_active									; alternative layout active?
	bra		TFT_depth_exit_1									; NO
	btfsc	depth_inverse_last									; YES - was last output in inverse mode?
	bra		TFT_depth_exit_1									;       YES
	call	TFT_divemask_color									;       NO  - set color
	WIN_TINY dm_mask_depth_column_alt,dm_mask_depth_row			;           - set position
	STRCAT_TEXT_PRINT tDepth									;           - restore "Depth" title
TFT_depth_exit_1:
	btfss	sensor_override_active								; pressure sensor override active (simulator mode)?
	goto	TFT_standard_color									; NO  - done
	;bra	TFT_depth_target									; YES - show target depth

TFT_depth_target:												; show simulated target depth
	call	TFT_attention_color									; select attention color
	TSTOSS	opt_units											; check unit selection (0=m or 1=ft)
	bra		TFT_depth_target_metric								; 0 - metric
	;bra	TFT_depth_target_imperial							; 1 - imperial

TFT_depth_target_imperial:
	btfsc	alt_layout_active									; alternative layout active?
	bra		TFT_depth_target_imperial_alt						; YES
	;bra	TFT_depth_target_imperial_norm						; NO

TFT_depth_target_imperial_norm:
	WIN_TINY dm_mask_depth_column+.40,dm_mask_depth_row			; position right of depth label
	bra		TFT_depth_target_imperial_com						; continue with common part

TFT_depth_target_imperial_alt:
	WIN_TINY dm_mask_depth_column+.62,dm_mask_depth_row+.20		; position within last digit
	;bra	TFT_depth_target_imperial_com						; continue with common part

TFT_depth_target_imperial_com:
	movff	simulatormode_depth,lo								; copy target depth to lo
	call	convert_meter_to_feet								; convert value in lo from meters to feet
	output_16_3													; display only last three digits from a 16 bit value (0-999)
	STRCAT_PRINT "ft"											; finalize output
	goto	TFT_standard_color									; done

TFT_depth_target_metric:
	btfsc	alt_layout_active									; alternative layout active?
	bra		TFT_depth_target_metric_alt							; YES
	;bra	TFT_depth_target_metric_norm						; NO

TFT_depth_target_metric_norm:
	WIN_TINY dm_mask_depth_column+.38,dm_mask_depth_row+.22		; position right of full meters, above decimal
	bra		TFT_depth_target_metric_com							; continue with common part

TFT_depth_target_metric_alt:
	WIN_TINY dm_mask_depth_column+.65,dm_mask_depth_row+.20		; position right of full meters, above decimal
	;bra	TFT_depth_target_metric_com							; continue with common part

TFT_depth_target_metric_com:
	movff	simulatormode_depth,lo								; copy target depth to lo
	output_8													; display number
	STRCAT_PRINT "m"											; finalize output
	goto	TFT_standard_color									; done

;=============================================================================

	global	TFT_custom_text
TFT_custom_text:					; show the custom text
	lfsr	FSR0, opt_name			; source
	WIN_SMALL surf_customtext_column,surf_customtext_row1 ; 1st row
	rcall	TFT_custom_text_2		; show up to 12 chars and print
	incfsz	lo,F					; was lo=255?
	return							; NO - all done
	lfsr	FSR0, opt_name+.12		; source
	WIN_SMALL surf_customtext_column,surf_customtext_row2 ; 2nd row
	rcall	TFT_custom_text_2		; show up to 12 chars and print
	incfsz	lo,F					; was lo=255?
	return							; NO - all done
	lfsr	FSR0, opt_name+.24		; source
	WIN_SMALL surf_customtext_column,surf_customtext_row3 ; 3rd row
	rcall	TFT_custom_text_2		; show up to 12 chars and print
	incfsz	lo,F					; was lo=255?
	return							; NO - all done
	lfsr	FSR0, opt_name+.36		; source
	WIN_SMALL surf_customtext_column,surf_customtext_row4 ; 4th row
	rcall	TFT_custom_text_2		; show up to 12 chars and print
	incfsz	lo,F					; was lo=255?
	return							; NO - all done
	lfsr	FSR0, opt_name+.48		; source
	WIN_SMALL surf_customtext_column,surf_customtext_row5 ; 5th row
	;bra	TFT_custom_text_2		; show up to 12 chars, print and return...

TFT_custom_text_2:
	lfsr	FSR2, buffer			; destination
	movlw	.12
	movwf	lo						; length/line
TFT_custom_text_3:
	movf	POSTINC0,W				; get byte
	bz		TFT_custom_text_4		; end if NULL
	movwf	POSTINC2				; NO - copy
	decfsz	lo,F					; max length reached ?
	bra		TFT_custom_text_3		; NO - loop
	setf	lo						; lo=255 -> more to come
TFT_custom_text_4:
	clrf	POSTINC2				; mark end of string
	goto	aa_wordprocessor		; print and return


;=============================================================================

	global	TFT_pres_surfmode
TFT_pres_surfmode:
	WIN_SMALL surf_press_column+.8,surf_press_row
	call	TFT_standard_color
	SMOVII	pressure_abs,    sub_a				; make ISR-safe 2 byte copy of current absolute pressure to sub_a
	MOVII	pressure_abs_ref,sub_b				; copy absolute pressure from 30 minutes ago to sub_b
	MOVII	sub_a,mpr							; store current pressure also in hi:lo for output
	call	subU16								; sub_c = sub_a - sub_b
	btfsc	neg_flag							; pressure lower?
	rcall	update_surf_press2					; YES - swap arguments
	tstfsz	sub_c+1								; > 255 mbar difference?
	bra		update_surf_press_common			; YES -  display
	movlw	.11									; 10 mbar noise suppression margin
	subwf	sub_c+0,W
	btfsc	STATUS,C
	bra		update_surf_press_common			; YES - display
	MOVII	pressure_abs_ref,mpr				; NO  - overwrite with stable value
update_surf_press_common:
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
	WIN_SMALL	surf_press_column+(4+1)*8,surf_press_row
	STRCPY_TEXT_PRINT tMBAR						; mbar (hPa)
	return

update_surf_press2:
	MOVII	sub_a,sub_b
	MOVII	pressure_abs_ref,sub_a
	goto	subU16								; sub_c = sub_a - sub_b and return...

;=============================================================================

	global	TFT_batt_surfmode
TFT_batt_surfmode:
	; color-code according to battery percent
	movff	batt_percent,lo
	clrf	hi
	call	TFT_color_code_battery

	; set up charging indicator and temperature warning
	clrf	WREG					; default to no indication/warning
	btfsc	cc_active				; charging in CC mode?
	movlw	color_yellow			; YES - set output color to yellow
	btfsc	cv_active				; charging in CV mode?
	movlw	color_green				; YES - set output color to green
	btfsc	battery_overtemp		; battery over-temperature detector tripped?
	movlw	color_red				; YES - set output color to red
	tstfsz	WREG					; any indicator or warning active?
	bsf		win_invert				; YES - set output to inverse
	tstfsz	WREG					; any indicator or warning active (asked again)?
	call	TFT_set_color			; YES - set color

	WIN_SMALL batt_percent_column+.2,batt_percent_row
	output_16_3						; display only last three digits from a 16 bit value (0-999)
	STRCAT_PRINT "% "
	bcf		win_invert
	call	TFT_standard_color
	WIN_TINY batt_voltage_column+.15,batt_voltage_row
	movff	battery_type,lo			; =0: 1.5V, =1: 3.6V Saft, =2: LiIon 3.7V/0.8Ah, =3: LiIon 3.7V/3.1Ah, =4: LiIon 3.7V/2.3Ah
	PUTC	"T"
	bsf		leftbind
	output_8
	PUTC	":"
	MOVII	batt_voltage,mpr
	output_16dp .2					; print as -x.yyy
	bcf		leftbind
	PUTC	'V'
	movff	buffer+8,buffer+6
	movlw	0x00
	movff	WREG,buffer+7			; only "x.yV"
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
;	MOVLI	.152,xB
;	call	div32x16				; xC:4 = xC:4 / xB:2 with xA as remainder
;	bsf		leftbind
;	MOVII	xC,mpr
;	output_16
;	STRCAT_PRINT "x.01Ah"
;	bcf		leftbind
;	return

;=============================================================================

	global	TFT_convert_signed_16bit
TFT_convert_signed_16bit:
	bcf		neg_flag				; clear flag for negative number by default
	btfss	hi,7					; negative number?
	return							; NO  - done
									; YES
	bsf		neg_flag				; set flag for negative number
	PUTC	'-'						; display a minus sign ("-")
	comf	hi						; complement hi:lo
	negf	lo
	btfsc	STATUS,C
	incf	hi
	return							; done

;=============================================================================
; input: lo  year
;        hi  month
;        up  day
;
; output format by option opt_dateformat:
;         0: MMDDYY
;         1: DDMMYY
;         2: YYMMDD
;
	global	TFT_convert_date
TFT_convert_date:					; convert into "DD/MM/YY" or "MM/DD/YY" or "YY/MM/DD" in output buffer
	movff	opt_dateformat,EEDATA	; get format (EEDATA used as temp here)
	tstfsz	EEDATA					; shall use format 0 ?
	bra		TFT_convert_date_1		; NO  - check for format 1 or 2
									; YES - use format 0: MMDDYY
	movff	lo,hy					;     - backup year  to hy
	movff	hi,lo					;     - copy   month to lo
	movff	up,hi					;     - copy   day   to hi
	movff	hy,up					;     - copy   year  to up
	bra		TFT_convert_date_common	;     - start output
TFT_convert_date_1:
	decfsz	EEDATA,F				; shall use format 1 ?
	bra		TFT_convert_date_common	; NO  - use format 2: YYMMDD - can print directly
									; YES - use format 1: DDMMYY
	movff	lo,hy					;     - backup year to hy
	movff	up,lo					;     - copy day    to lo
	movff	hy,up					;     - copy year   to up

TFT_convert_date_common:
	bsf		leftbind				; start left-alignment
	output_99x						; print lo
	PUTC	'.'						; print spacing dot
	movff	hi,lo					; print hi
	output_99x						; ...
	PUTC	'.'						; print spacing dot
	movff	up,lo					; print up
	output_99x						; ...
	bcf		leftbind				; end left-alignment
	return							; done


;=============================================================================
; show date by month & day
;
; input: lo  year   (not used here)
;        hi  month
;        up  day
;
; output format by option opt_dateformat:
;         0: MMDD(YY)
;         1: DDMM(YY)
;         2: (YY)MMDD
;
	global	TFT_convert_date_short
TFT_convert_date_short:				; convert into "DD/MM" or "MM/DD" or "MM/DD" into output buffer
	movff	opt_dateformat,EEDATA	; get format (EEDATA used as temp here)
	tstfsz	EEDATA					; shall use format 0 ?
	bra		TFT_convert_date_short2	; NO  - check for format 1 or 2
TFT_convert_date_short1:			; YES - use format 0: MMDD
	movff	hi,lo					;     - copy month to lo
	movff	up,hi					;     - copy day   to hi
	bra		TFT_convert_date_short3 ;     - start output
TFT_convert_date_short2:
	decfsz	EEDATA,F				; format 1 ?
	bra		TFT_convert_date_short1	; NO  - use format 2: MMDD (here its like format 0)
									; YES - use format 1: DDMM
	movff	up,lo					;     - copy day to lo,
									;     - month is already in hi
TFT_convert_date_short3:
	bsf		leftbind				; start left-alignment
	output_99x						; print lo
	PUTC	'.'						; print spacing dot
	movff	hi,lo					; print hi
	output_99x						; ...
	bcf		leftbind				; end left-alignment
	return							; done

;=============================================================================

	global	TFT_date_surfmode
TFT_date_surfmode:
	WIN_SMALL	surf_date_column,surf_date_row
	call	TFT_standard_color
	SMOVSS	rtc_year,rtc_latched_year	; ISR-safe 6 byte copy of date and time
	movff	rtc_latched_year, lo
	movff	rtc_latched_month,hi
	movff	rtc_latched_day,  up
	call	TFT_convert_date			; convert into "DD/MM/YY" or "MM/DD/YY" or "YY/MM/DD" in postinc2
	STRCAT_PRINT ""
	return

;=============================================================================

	global	TFT_show_max_depth
TFT_show_max_depth:
	btfsc	alt_layout_active			; alternative layout active?
	bra		TFT_show_max_depth_alt		; YES

	WIN_MEDIUM dm_max_depth_column_nvsi, dm_max_depth_row
	TSTOSS	opt_vsigraph				; graphical VSI bar enabled?
	bra		TFT_show_max_depth_1		; NO  - keep position
										; YES - adopt output position
	WIN_MEDIUM dm_max_depth_column, dm_max_depth_row

TFT_show_max_depth_1:
	btfsc	FLAG_apnoe_mode				; in apnoe mode?
	bra		TFT_max_depth_apnoe			; YES - different handling in apnoe mode

	TSTOSS	opt_2ndDepthDisp			; show average depth instead of max depth?
	bra		TFT_max_depth_current		; NO  - show max depth
	;bra	TFT_avg_depth_current		; YES - show avg depth

TFT_avg_depth_current:
	MOVII	pressure_rel_avg_total,mpr	; YES - get total dive average pressure
	bra		TFT_max_depth_common		;     - continue with common part

TFT_max_depth_apnoe:
	btfss	apnoe_at_surface			; apnoe mode, at the surface?
	bra		TFT_max_depth_current		; NO  - show max depth of current dive
	MOVII	apnoe_max_pressure,mpr		; YES - get max pressure of all dives so far
	bra		TFT_max_depth_common		;     - continue with common part

TFT_max_depth_current:
	MOVII	pressure_rel_max_cached,mpr	; get the "normal" max pressure
	;bra	TFT_max_depth_common		; continue with common part

TFT_max_depth_common:
	call	convert_pres_to_depth		; convert pressure in [mbar] to depth in [cm]
	TSTOSS	opt_units					; 0=m or 1=ft ?
	bra		TFT_max_depth_metric		; 0 - use metric   version
	;bra	TFT_max_depth_imperial		; 1 - use imperial version

TFT_max_depth_imperial:
	call	convert_cm_to_feet			; convert value in hi:lo from [cm] to [feet]
	call	TFT_memo_color				; set output color
	output_16_3							; print depth
	bra		TFT_max_depth_finish		; finish output

TFT_max_depth_metric:
	MOVLI	.9999,sub_a					; 9999 mbar = 99.99 m
	MOVII	mpr,  sub_b					; depth, also used to back-up hi:lo
	call	cmpU16						; sub_a - sub_b = 99.99 - depth
	btfsc	neg_flag					; depth < 100 meter ?
	bra		TFT_max_depth_greater_100m	; NO  - greater   than 100 m
	;bra	TFT_max_depth_shallower_100m; YES - shallower than 100 m

TFT_max_depth_shallower_100m:
	btfss	max_depth_greater_100m		; was depth >= 100 m during last call?
	bra		TFT_max_depth_metric_show	; NO  - show depth
	bcf		max_depth_greater_100m		; YES - clear flag, last depth shown now not > 99.84 m anymore
	bra		TFT_max_depth_clear			;     - clear depth area

TFT_max_depth_greater_100m:
	btfsc	max_depth_greater_100m		; was depth >= 100 m during last call?
	bra		TFT_max_depth_metric_show	; YES - show depth
	bsf		max_depth_greater_100m		; NO  - set flag, last depth shown now > 99.84 m
	;bra	TFT_max_depth_clear			;     - clear depth area

TFT_max_depth_clear:
	WIN_BOX_BLACK dm_max_depth_row, dm_max_depth_bot, dm_max_depth_column, dm_max_depth_rgt	; top, bottom, left, right
	;bra	TFT_max_depth_metric_show

TFT_max_depth_metric_show:
	call	TFT_memo_color				; set output color
	btfss	max_depth_greater_100m		; depth to show >= 100 m ?
	bra		TFT_max_depth_metric_m_dm	; NO  - show meters and decimeters
	bsf		ignore_digit4				; YES - crop decimeters and centimeters
	bsf		leftbind					;     - print left-aligned
	output_16							;     - print depth
	bra		TFT_max_depth_finish		;     - finish output

TFT_max_depth_metric_m_dm:
	MOVLI	.999,sub_a					; load 9.99 meter
	call	cmpU16						; sub_a - sub_b = 9.99 - depth
	movlw	' '							; load a space character
	btfss	neg_flag					; depth shallower than 10 meter ?
	movwf	POSTINC2					; YES - add the space character
	MOVLI	.99,sub_a					; load 0.99 m
	call	cmpU16						; sub_a - sub_b = 0.99 m - depth
	btfss	neg_flag					; depth shallower than  1 meter ?
	bra		TFT_max_depth_metric_zero	; YES - manually display a zero
	bsf		ignore_digit4				; NO  - crop decimeters and centimeters
	bsf		leftbind					;     - align left
	output_16							;     - display full meters
	STRCAT_PRINT ""						;     - finalize output
	bra		TFT_max_depth_metric_dm		;     - continue with decimeters

TFT_max_depth_metric_zero:
	STRCAT_PRINT "0"					; print a zero
	;bra	TFT_max_depth_metric_dm		; continue with decimeters

TFT_max_depth_metric_dm:
	WIN_SMALL dm_max_depth_dm_column_nvsi, dm_max_depth_dm_row
	TSTOSS	opt_vsigraph				; graphical VSI bar enabled?
	bra		TFT_max_depth_metric_dm_1	; NO  - keep position
										; YES - adopt position
	WIN_SMALL dm_max_depth_dm_column, dm_max_depth_dm_row
TFT_max_depth_metric_dm_1:
	PUTC	"."							; print decimal point
	MOVII	sub_b,mpr					; restore depth in hi:lo
	movlw	d'4'						; crop leading 4 digits (don't show the full meters)
	movwf	ignore_digits				; ...
	bsf		ignore_digit5				; crop last digit (no centimeters, flag will be cleared by output_16)
	bsf		leftbind					; print left-aligned
	output_16dp d'0'					; print decimal
TFT_max_depth_finish:
	STRCAT_PRINT ""						; finalize output
	bcf		leftbind					; back to default right alignment
	goto	TFT_standard_color			; done


TFT_show_max_depth_alt:
	btfsc	FLAG_apnoe_mode				; in apnoe mode?
	bra		TFT_show_apnoe_max_depth	; YES - use apnoe surface output also in alternative dive mode screen
	btfsc	FLAG_gauge_mode				; NO  - in gauge mode?
	bra		TFT_show_gauge_max_avg_depth;       YES - show both, max and avg depth
	return								;       NO  - nothing to do

TFT_show_gauge_max_avg_depth:
	call	TFT_memo_color										; set color
	WIN_MEDIUM dm_gauge_max_depth_col, dm_gauge_max_depth_row	; set position for max depth
	rcall	TFT_show_gauge_max_depth							; show max depth
	call	TFT_memo_color										; set color
	WIN_MEDIUM dm_gauge_avg_depth_col, dm_gauge_avg_depth_row	; set position for avg depth
	MOVII	pressure_rel_avg_total,mpr							; get average pressure into hi:lo
	bra		TFT_show_gauge_depth								; show avg depth and return


	global	TFT_show_apnoe_max_depth
TFT_show_apnoe_max_depth:
	; title
	WIN_TINY dm_apnoe_last_max_depth_text_col, dm_apnoe_last_max_depth_text_row
	call	TFT_divemask_color
	btfsc	alt_layout_active				; alternative layout active?
	bra		TFT_show_apnoe_max_depth_alt	; YES
	STRCPY_TEXT_PRINT tApnoeMax				; NO  - print "Last Descent"
	bra		TFT_show_apnoe_max_depth_com	;     - continue with common part
TFT_show_apnoe_max_depth_alt:
	STRCPY_TEXT_PRINT tMaxDepth				; print "Max.Depth"
TFT_show_apnoe_max_depth_com:
	; value
	WIN_MEDIUM	dm_apnoe_last_max_depth_column, dm_apnoe_last_max_depth_row
	call	TFT_memo_color
TFT_show_gauge_max_depth:
	MOVII	pressure_rel_max_cached,mpr		; get max pressure into hi:lo
	;bra	TFT_show_gauge_depth			; show max depth and return

TFT_show_gauge_depth:
	call	convert_pres_to_depth			; convert pressure in [mbar] to depth in [cm]
	TSTOSS	opt_units						; 0=m, 1=ft
	bra		TFT_display_apnoe_last_m_metric ; 0 - metric
TFT_display_apnoe_last_max_imp:				; 1 - imperial
	call	convert_cm_to_feet				; convert value in hi:lo from [cm] to [feet]
	output_16
	bra		TFT_max_depth_finish			; finish output
TFT_display_apnoe_last_m_metric:
	bsf		ignore_digit5					; do not display centimeters (flag will be cleared by output_16)
	output_16dp d'3'
	bra		TFT_max_depth_finish			; finish output

;=============================================================================

	global	TFT_show_divetime
TFT_show_divetime:
	call	TFT_memo_color					; set color
	SMOVTT	counted_divetime_mins,mpr		; ISR-safe 3 byte copy of minutes:2 (mpr+1:mpr+0) and seconds (mpr+2)
	btfsc	show_only_divemins				; shall suppress display of seconds?
	bra		TFT_show_divetime_min_only		; YES - show minutes only
	movlw	.99								; NO  - load 99
	cpfsgt	mpr+0							;     - dive time > 99 minutes ?
	bra		TFT_show_divetime_min_sec		;       NO  - show min:sec
	bsf		show_only_divemins				;       YES - set flag to suppress the display of seconds for the rest of the dive
	btfsc	alt_layout_active				;           - in alternative layout?
	bra		TFT_show_divetime_clear_alt		;             YES - clear min:sec area of alternative layout
	;bra	TFT_show_divetime_clear_norm	;             NO  - clear min:sec area of normal      layout

TFT_show_divetime_clear_norm:
	WIN_BOX_BLACK dm_divetime_row, dm_divetime_bot_medium, dm_divetime_col_medium, dm_divetime_rgt ;top, bottom, left, right
	bra		TFT_show_divetime_min_only_norm	; show minutes only

TFT_show_divetime_clear_alt:
	WIN_BOX_BLACK dm_divetime_row, dm_divetime_bot_large,  dm_divetime_col_large,  dm_divetime_rgt ;top, bottom, left, right
	bra		TFT_show_divetime_min_only_alt	; show minutes only

TFT_show_divetime_min_sec:
	; show the minutes
	btfsc	alt_layout_active				; in alternative layout?
	bra		TFT_show_divetime_min_alt		; YES
	;bra	TFT_show_divetime_min_norm		; NO

TFT_show_divetime_min_norm:
	WIN_MEDIUM dm_divetime_col_medium, dm_divetime_row
	bra		TFT_show_divetime_min_com		; continue with common part

TFT_show_divetime_min_alt:
	WIN_LARGE  dm_divetime_col_large,  dm_divetime_row
	;bra	TFT_show_divetime_min_com		; continue with common part

TFT_show_divetime_min_com:
	output_99								; displays only last two digits from a 8 bit value (0-99)
	STRCAT_PRINT ""							; finalize output

	; show the seconds
	btfsc	alt_layout_active				; in alternative layout?
	bra		TFT_show_divetime_sec_alt		; YES
	;bra	TFT_show_divetime_sec_norm		; NO

TFT_show_divetime_sec_norm:
	WIN_SMALL  dm_divetime_sec_col_small,  dm_divetime_sec_row_small
	bra		TFT_show_divetime_sec_com		; continue with common part

TFT_show_divetime_sec_alt:
	WIN_MEDIUM dm_divetime_sec_col_medium, dm_divetime_sec_row_medium
	;bra	TFT_show_divetime_sec_com		; continue with common part

TFT_show_divetime_sec_com:
	PUTC	':'								; print separator char
	movff	mpr+2,lo						; copy seconds to lo
	bsf		leftbind						; activate left-alignment
	output_99x								; displays only last two figures from a 8 bit value with leading zero (00-99) 
	bcf		leftbind						; deactivate left-alignment
	bra		TFT_divemins_exit				; continue with common part

TFT_show_divetime_min_only:
	btfsc	alt_layout_active				; in alternative layout?
	bra		TFT_show_divetime_min_only_alt	; YES
	;bra	TFT_show_divetime_min_only_norm	; NO

TFT_show_divetime_min_only_norm:
	WIN_MEDIUM dm_divetime_minonly_col_medium, dm_divetime_row
	output_16_4								; print minutes (4 digits)
	bra		TFT_divemins_exit				; continue with common part

TFT_show_divetime_min_only_alt:
	WIN_LARGE  dm_divetime_minonly_col_large,  dm_divetime_row
	output_16_3								; print minutes (3 digits)
	;bra	TFT_divemins_exit				; continue with common part

TFT_divemins_exit:
	STRCAT_PRINT ""							; finalize output
	goto	TFT_standard_color				; and return...

;=============================================================================

	global	TFT_show_apnoe_surface
TFT_show_apnoe_surface:
	call	TFT_divemask_color
	WIN_TINY dm_apnoe_surface_time_text_col, dm_apnoe_surface_time_text_row
	STRCPY_TEXT_PRINT tApnoeSurface
	call	TFT_memo_color
	WIN_MEDIUM dm_apnoe_surface_time_column, dm_apnoe_surface_time_row
	SMOVII	apnoe_surface_mins,mpr			; ISR-safe copy of minutes to lo and seconds to hi
	output_8
	PUTC	':'
	movff	hi,lo							; copy seconds to lo
	output_99x
	bra		TFT_display_apnoe_exit			; and return...


	global	TFT_show_apnoe_times
TFT_show_apnoe_times:						; descent dive time
	; current dive time
	call	TFT_memo_color
	WIN_MEDIUM dm_divetime_apnoe_col, dm_divetime_apnoe_row
	SMOVII	apnoe_dive_mins,mpr				; ISR-safe copy of minutes to lo and seconds to hi
	output_99								; display 0-99
	STRCAT_PRINT ""							; show minutes
	WIN_SMALL	dm_divetime_apnoe_secs_col, dm_divetime_apnoe_secs_row ; left position for two sec figures
	PUTC	':'
	bsf		leftbind
	movff	hi,lo							; copy seconds to lo
	output_99x
	STRCAT_PRINT ""							; show seconds
	; overall dive time
	WIN_MEDIUM dm_apnoe_total_divetime_col, dm_apnoe_total_divetime_row
	SMOVTT	counted_divetime_mins,mpr		; ISR-safe 3 byte copy of minutes:2 and seconds
	clrf	hi
	bcf		leftbind
	output_16_3								; displays only last three figures from a 16 bit value (0-999)
	STRCAT_PRINT ""							; show minutes in large font
	WIN_SMALL dm_apnoe_total_divetime_secs_col, dm_apnoe_total_divetime_secs_row ; left position for two sec figures
	PUTC	':'
	bsf		leftbind
	movff	up,lo							; copy minutes from up to lo
	output_99x
TFT_display_apnoe_exit:
	STRCAT_PRINT ""
	bcf		leftbind
	goto	TFT_standard_color				; and return...


	global	TFT_clear_apnoe_surface
TFT_clear_apnoe_surface:
	; clear surface data
	WIN_BOX_BLACK dm_apnoe_last_max_depth_text_row, .239, dm_apnoe_last_max_depth_column, .159 ; top, bottom, left, right
	goto	TFT_standard_color				; and return...


;-----------------------------------------------------------------------------
; check if firmware is within expiry period, will return aux_flag set if not

check_expiry:						; check if it is time for a firmware update
	SMOVSS	rtc_year,rtc_latched_year; ISR-safe 6 byte copy of date and time
	movff	rtc_latched_day,lo		; get current day
	movff	rtc_latched_month,hi	; get current month
	movff	rtc_latched_year,up		; get current year
	bsf		aux_flag				; set firmware as expired by default
	movlw	firmware_expire_year	; start with checking year
	cpfsgt	up						; current year > expiry year ?
	bra		check_expiry_Y			; NO  - continue checks
	return							; YES - expired
check_expiry_Y:
	cpfseq	up						; current year = expiry year ?
	bra		check_expiry_ok			; NO  - must be < then, OK whatever month & day
	movlw	firmware_expire_month	; YES - continue checking month
	cpfsgt	hi						; current month > expiry month ?
	bra		check_expiry_M			; NO  - continue checks
	return							; YES - expired
check_expiry_M:
	cpfseq	hi						; current month = expiry month ?
	bra		check_expiry_ok			; NO  - must be < then, OK whatever day
	movlw	firmware_expire_day		; YES - continue checking day
	cpfsgt	lo						; current day > expiry day ?
	bra		check_expiry_ok			; NO  - must be <= then, OK
	return							; YES - expired
check_expiry_ok:
	bcf		aux_flag
	return

;-----------------------------------------------------------------------------
; append firmware BETA status to current string, including color-coding

	global	TFT_cat_beta_release
TFT_cat_beta_release:				; entry point for printing "Release" / "Beta #"
	bsf		aux_flag
	bra		TFT_cat_beta_common
TFT_cat_beta_rel:					; entry point for printing "Rel." / "B. #"
	bcf		aux_flag
TFT_cat_beta_common:
 IFDEF _DEBUG
	btfss	aux_flag				; shall show long version?
	bra		TFT_cat_debug_short		; NO  - show short version
	STRCAT	"DEBUG"					; YES - show long version
	goto	TFT_warning_color		;     - set color
TFT_cat_debug_short:
	STRCAT	"DBG."					; show short version
	goto	TFT_warning_color		; set color
 ELSE
	movlw	fw_version_beta	; =0: release, =1: beta 1, =2: beta 2, ...
	movwf	lo						; copy to lo
	tstfsz	lo						; release version?
	bra		TFT_cat_beta_1			; NO  - must be beta version then
	btfss	aux_flag				; YES - shall show long version?
	bra		TFT_cat_beta_2			;       NO  - show short version
	rcall	check_expiry			;       YES - check  expiry date
	btfsc	aux_flag				;           - within expiry date?
	bra		TFT_cat_beta_4			;             NO  - give update cue
	STRCAT	"Release"				;             YES - print "Release"
	return							;                 - done
TFT_cat_beta_1:
	btfss	aux_flag				; shall show long  version?
	bra		TFT_cat_beta_3			; NO  - show short version
	STRCAT	"Beta "					; YES - show long  version
TFT_cat_beta_1a:
	bsf		leftbind
	output_8						; print beta version number
	bcf		leftbind
	goto	TFT_attention_color		; and return
TFT_cat_beta_2
	STRCAT "Rel."					; short version for "Release"
	return
TFT_cat_beta_3
	STRCAT "B."						; short version for "Beta"
	bra		TFT_cat_beta_1a			; append beta version number
TFT_cat_beta_4
	STRCAT "update!"				; print update cue
	goto	TFT_attention_color		; and return
 ENDIF	; ELSE / _DEBUG

;-----------------------------------------------------------------------------
; show firmware update message
;
; all text outputs are hard-coded since language switching
; has not yet been initialized when this code is executed

	global	show_fw_mesg_update
	global	show_fw_mesg_kept
show_fw_mesg_update:
	call	TFT_standard_color
	; show update message
	WIN_SMALL .20,.100
	STRCPY_PRINT "Update successful!"
	; show firmware version
	WIN_SMALL .20,.140
	STRCPY	"New Firmware: "
	bra		show_fw_mesg_common
show_fw_mesg_kept:
	call	TFT_standard_color
	; show reboot message
	WIN_SMALL .60,.100
	STRCPY_PRINT "Reboot"
	; show firmware version
	WIN_SMALL .30,.140
	STRCPY	"Firmware: "
show_fw_mesg_common:
	rcall	TFT_cat_firmware				; show firmware version x.y and color-code + invert if outdated
	STRCAT_PRINT ""							; finalize output
	bcf		win_invert						; back to normal (non inverted) output
	; show firmware beta status
	call	TFT_standard_color				; color to use if it is a release version
	WIN_SMALL .60,.180
	rcall	TFT_cat_beta_release			; show "Release" or "BETA" + issue
	STRCAT_PRINT ""							; finalize output
	goto	TFT_standard_color				; reset color and return

;-----------------------------------------------------------------------------
; show serial and firmware version for comm mode

	global	TFT_show_serial_and_firmware
	global	TFT_show_firmware
TFT_show_serial_and_firmware:
	STRCPY	"#"
	call	TFT_cat_serial
	STRCAT	" "
	STRCAT	"v"
TFT_show_firmware:
	call	TFT_cat_firmware				; will set win_invert if outdated
	STRCAT	" "
	call	TFT_cat_beta_release
	STRCAT_PRINT ""
	bcf		win_invert						; clear win_invert
	goto	TFT_standard_color				; ...and return

;-----------------------------------------------------------------------------
; For the Information menu: append total dives

	global	info_menu_total_dives
info_menu_total_dives:
	lfsr	FSR1,tTotalDives				; locate text
	call	strcat_text						; print  text
TFT_cat_total_dives:
	call	eeprom_total_dives_read			; read total number of dives
	bsf		leftbind						; print left-aligned
	output_16								; print number of total dives
	bcf		leftbind						; quit  left-aligned
	return									; done

;-----------------------------------------------------------------------------
; append firmware version to current string, including color-coding

	global	TFT_cat_firmware
TFT_cat_firmware:
	movlw	fw_version_major
	movwf	lo
	bsf		leftbind
	output_8								; print major in 1 or 2 digit format
	PUTC	'.'
	movlw	fw_version_minor
	movwf	lo
	output_99x								; print minor in two digit format
	bcf		leftbind
	rcall	check_expiry					; sets aux_flag if expired
	btfss	aux_flag						; expired?
	return									; NO
	bsf		win_invert						; YES - print in inverse
	goto	TFT_attention_color				;     - print in attention color (and return)

;-----------------------------------------------------------------------------
; For the Information menu: firmware version and creation date

	global	info_menu_firmware
info_menu_firmware:
	lfsr	FSR1,tFirmware					; select label text
	call	strcat_text						; print label
	rcall	TFT_cat_firmware				; print firmware version
	PUTC	" "								; print a dot
	rcall	TFT_cat_beta_rel				; print beta/release
	STRCAT_PRINT ""							; finalize output
	return									; done

	global	info_menu_fw_cration_date
info_menu_fw_cration_date:
	lfsr	FSR1,tFirmwareDate				; select label text
	call	strcat_text						; print label
	movlw	firmware_creation_year			; get firmware creation year
	movwf	lo								; copy to lo
	movlw	firmware_creation_month			; get firmware creation month
	movwf	hi								; copy to hi
	movlw	firmware_creation_day			; get firmware creation day
	movwf	up								; copy to up
	call	TFT_convert_date				; converts into "DD/MM/YY" or "MM/DD/YY" or "YY/MM/DD" in postinc2
	return									; done

;-----------------------------------------------------------------------------
; For the Information menu: firmware version of the RX processor

 IFDEF _rx_functions

	global	info_menu_firmware_rx
	global	TFT_print_firmware_rx
info_menu_firmware_rx:
	lfsr	FSR1,tFirmware_rx
	call	strcat_text
TFT_print_firmware_rx:
	movff	rx_firmware_cur_major,lo
	bsf		leftbind
	output_8
	PUTC	'.'
	movff	rx_firmware_cur_minor,lo
	output_8
	bcf		leftbind
	return

 ENDIF

;-----------------------------------------------------------------------------
; For the Information menu: serial number

	global	info_menu_serial
	global	TFT_cat_serial
info_menu_serial:
	lfsr	FSR1,tSerial				; locate text
	call	strcat_text					; print  text
TFT_cat_serial:
	call	eeprom_serial_number_read	; read OSTC serial number
	bsf		leftbind					; start left-alignment
	output_16							; print serial number
	bcf		leftbind					; end   left-alignment
	return								; done

;-----------------------------------------------------------------------------
; For the Information menu: hardware / software configuration

	global	info_menu_config
info_menu_config:
	lfsr	FSR1,tHardware				; locate text
	call	strcat_text					; print  text
	call	I2C_init_compass			; start compass
	movf	HW_descriptor,W				; copy hardware descriptor to WREG
	output_hex							; print as hex
	PUTC	"-"							; print a separator
	movf	HW_variants,W				; copy hardware variants   to WREG
	output_hex							; print as hex
	PUTC	"-"							; print a separator
	movlw	SW_CONF						; get software configuration
	output_hex							; print as hex
	return


;-----------------------------------------------------------------------------
; For the Information menu: battery voltage

	global	info_menu_battery_volts
info_menu_battery_volts:
	lfsr	FSR1,tBatteryV
	call	strcat_text
	MOVII	batt_voltage,mpr
	bsf		leftbind
	output_16dp .2						; print as -x.yyy
	STRCAT	"V(T"
	movff	battery_type,lo				; =0:1.5V, =1:3.6V Saft, =2:LiIon 3.7V/0.8Ah, =3:LiIon 3.7V/3.1Ah, =4: LiIon 3.7V/2.3Ah
	output_8
	bcf		leftbind
	PUTC	")"
	return


;-----------------------------------------------------------------------------
; For the Information menu: sensor C1 and C5 values

	global	info_menu_sensor_calib
info_menu_sensor_calib:
	lfsr	FSR1,tSensorC				; locate label
	call	strcat_text					; print  label
	movff	C1+1,WREG					; get   C1, high byte
	output_hex							; print C1, high byte
	movff	C1+0,WREG					; get   C1, low  byte
	output_hex							; print C1, low  byte
	PUTC	"-"							; print a separator
	movff	C5+1,WREG					; get   C5, high byte
	output_hex							; print C5, high byte
	movff	C5+0,WREG					; get   C5, low  byte
	output_hex							; print C5, low  byte
	return								; done


;-----------------------------------------------------------------------------
; For the Information menu: sensor depth correction

	global	info_menu_sensor_offset
info_menu_sensor_offset:
	lfsr	FSR1,tSensorD				; locate label
	call	strcat_text					; print  label
	movff	opt_pressure_adjust,WREG	; get pressure sensor offset
	btfsc	WREG,7						; value negative?
	bra		info_menu_sensor_offset_1	; YES
	PUTC	"+"							; NO  - print plus sign
	bra		info_menu_sensor_offset_2	;     - continue with common part
info_menu_sensor_offset_1:
	PUTC	"-"							; print a minus sign
	negf	WREG						; negate WREG
info_menu_sensor_offset_2:
	PUTC	" "							; print a space
	bsf		leftbind					; start left-bind printing
	output_8							; print value
	bcf		leftbind					; end left-bind printing
	PUTC	" "							; print a space
	lfsr	FSR1,tMBAR					; locate unit
	call	strcat_text					; print  unit
	return								; done


;-----------------------------------------------------------------------------
; For the Information menu: uptime

	global	info_menu_uptime
info_menu_uptime:
	lfsr	FSR1,tUptime
	call	strcat_text
	SMOVQQ	uptime,xC					; ISR-safe copy of uptime:4 to xC:4

info_menu_uptime_com:
	MOVLI	.3600,xB					; one hour = 3600s
	call	div32x16					; xC:4 = xC:4 / xB:2 with xA as remainder -> xC+1:xC+0 holds full hours
	MOVII	xC,xA
	MOVLI	.24,xB						; one day = 24 hours
	call	div16x16					; xC:2 = xA:2 / xB:2 with xA as remainder -> xC+1:xC+0 holds full days, xA holds full hours
	MOVII	xC,mpr						; copy full days into hi:lo
	bsf		leftbind
	output_16
	PUTC	"d"
	movff	xA+0,lo						; full hours
	output_8
	PUTC	"h"
	bcf		leftbind
	return								; done

;-----------------------------------------------------------------------------

 IFDEF _compass

	global	menu_cal_x
menu_cal_x:
	lfsr	FSR0,compass_CX_f
	lfsr	FSR1,tCalX
	bra		menu_cal_common

	global	menu_cal_y
menu_cal_y:
	lfsr	FSR0,compass_CY_f
	lfsr	FSR1,tCalY
	bra		menu_cal_common

	global	menu_cal_z
menu_cal_z:
	lfsr	FSR0,compass_CZ_f
	lfsr	FSR1,tCalZ
	;bra	menu_cal_common

menu_cal_common:
	call	strcat_text
	movff	POSTINC0,lo
	movff	POSTINC0,hi
	call	TFT_convert_signed_16bit	; convert lo:hi into signed-short and adds '-' to POSTINC2 if required
	bsf		leftbind
	output_16
	bcf		leftbind
	return

 ENDIF	; _compass


;-----------------------------------------------------------------------------
; ppO2 menu

	global	divesets_ppo2_min
divesets_ppo2_min:
	lfsr	FSR1,tPPO2MIN
	call	strcat_text
	movff	char_I_ppO2_min,lo
	movlw	ppo2_warning_low_default
	bra		divesets_ppo2_common


 IFDEF _ccr_pscr

	global	divesets_ppo2_min_cc
divesets_ppo2_min_cc:
	lfsr	FSR1,tPPO2MINCC
	call	strcat_text
	movff	char_I_ppO2_min_loop,lo
	movlw	ppo2_warning_loop_default
	bra		divesets_ppo2_common

 ENDIF

	global	divesets_ppo2_max
divesets_ppo2_max:
	lfsr	FSR1,tPPO2Max
	call	strcat_text
	movff	char_I_ppO2_max_work,lo
	movlw	ppo2_warning_high_default
	bra		divesets_ppo2_common

	global	divesets_ppo2_max_deco
divesets_ppo2_max_deco:
	lfsr	FSR1,tPPO2DECO
	call	strcat_text
	movff	char_I_ppO2_max_deco,lo
	movlw	ppo2_warning_deco_default
	;bra	divesets_ppo2_common

divesets_ppo2_common:
	movwf	up						; save default value
	clrf	hi
	bsf		leftbind
	output_16dp d'3'
	bcf		leftbind
	lfsr	FSR1,tbar
	call	strcat_text
	movf	up,W					; default value
	cpfseq	lo						; current value
	bra		divesets_ppo2_common2	; not default, add *
	return							; default, done
divesets_ppo2_common2:
	PUTC	"*"
	return							; done

;=============================================================================

	global	TFT_clear_message_window
TFT_clear_message_window:
	btfss	divemode							; in dive mode?
	bra		TFT_clear_message_window_surf		; NO  - clear surface mode area
	;bra	TFT_clear_message_window_dive		; YES - clear dive    mode area

TFT_clear_message_window_dive:
	btfsc	alt_layout_active					; in alternative layout?
	bra		TFT_clear_message_window_dive_2		; YES - clear dive mode area, 2nd  row only
												; NO  - clear dive mode area, both rows
	WIN_BOX_BLACK dm_warning_row, dm_warning_bot, dm_warning_column, dm_warning_rgt		; top, bottom, left, right
	return										;           - done

TFT_clear_message_window_surf:
	WIN_BOX_BLACK surf_warning1_row, surf_warning2_row+.24, surf_warning1_column, surf_warning1_column+.76	; top, bottom, left, right
	return										; done


	global	TFT_clear_message_window_row2
TFT_clear_message_window_row2:
	btfss	divemode							; in dive mode?
	bra		TFT_clear_message_window_surf_2		; NO  - clear surface mode area, 2nd row only
	;bra	TFT_clear_message_window_dive_2		; YES - clear dive    mode area, 2nd row only

TFT_clear_message_window_dive_2:
	WIN_BOX_BLACK dm_warning2_row, dm_warning2_bot, dm_warning2_column, dm_warning2_rgt	; top, bottom, left, right
	bcf		message_2nd_row_used				;     - 2nd row is clear now
	return										;     - done

TFT_clear_message_window_surf_2:
	WIN_BOX_BLACK surf_warning2_row, surf_warning2_row+.24, surf_warning2_column, surf_warning2_column+.76	; top, bottom, left, right
	bcf		message_2nd_row_used				; 2nd row is clear now
	return										; done


	global	TFT_fillup_with_spaces
TFT_fillup_with_spaces:					; fill up FSR2 with spaces (total string length in #WREG)
	movwf	lo							; save max. string length into lo
	movf	FSR2L,W						; get current string length
	subwf	lo,F						; lo-WREG
	btfsc	STATUS,N					; longer then #lo already?
	return								; YES - done
	tstfsz	lo							; zero?
	bra		TFT_fillup_with_spaces2		; NO
	return								; YES - done
TFT_fillup_with_spaces2:
	PUTC	" "							; add one space
	decfsz	lo,F						; all done?
	bra		TFT_fillup_with_spaces2		; NO  - loop
	return								; YES - done

;=============================================================================

	global	TFT_desaturation_time
TFT_desaturation_time:
	rcall	TFT_set_message_window		; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO - skip message in this cycle
	call	TFT_memo_color
	STRCPY	"Desat:"
	MOVII	int_O_desaturation_time,mpr
	call	convert_time				; convert hi:lo in minutes to hours (up:hi) and minutes (lo)
	movf	lo,W						; swap hi and lo
	movff	hi,lo						; ...
	movwf	hi							; ...
	output_99x							; print hours
	PUTC	':'							; print ":"
	movff	hi,lo						; print minutes...
	output_99x							; ... in two digits, leading zero
	movlw	surf_warning_length			; only use surface string length
	rcall	TFT_fillup_with_spaces		; fill up FSR2 with spaces (total string length in #WREG)
	STRCAT_PRINT ""
	return


	global	TFT_nofly_time
TFT_nofly_time:
	rcall	TFT_set_message_window		; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO - skip message in this cycle
	call	TFT_memo_color
	movff	char_I_altitude_wait,WREG
	tstfsz	WREG
	bra		TFT_nofly_time_1
	STRCPY	"NoFly:"
	bra		TFT_nofly_time_2
TFT_nofly_time_1:
	STRCPY	"NoAlt:"
TFT_nofly_time_2:
	MOVII	int_O_nofly_time,mpr
	call	convert_time				; convert hi:lo in minutes to hours (up:hi) and minutes (lo)
	movf	lo,W						; swap hi and lo
	movff	hi,lo						; ...
	movwf	hi							; ...
	output_99x							; hours
	PUTC	':'
	movff	hi,lo						; minutes
	output_99x
	movlw	surf_warning_length			; only use surface string length
	rcall	TFT_fillup_with_spaces		; fill up FSR2 with spaces (total string length in #WREG)
	STRCAT_PRINT ""
	return

;=============================================================================

	global	TFT_warning_agf
TFT_warning_agf:
	rcall	TFT_set_message_window		; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO - skip message in this cycle
	call	TFT_attention_color
	STRCPY_TEXT tDiveaGF_active			; "aGF!"
	movlw	dm_warning_length			; dive mode string length
	rcall	TFT_fillup_with_spaces		; fill up FSR2 with spaces (total string length in #WREG)
	STRCAT_PRINT ""
	bra		TFT_warn_att_info_exit		; and return...


	global	TFT_warning_fallback
TFT_warning_fallback:					; show fallback warning
	rcall	TFT_set_message_window		; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO - skip message in this cycle
	call	TFT_warning_color
	STRCPY_TEXT tDiveFallback			; "Fallback!"
	movlw	dm_warning_length			; dive mode string length
	rcall	TFT_fillup_with_spaces		; fill up FSR2 with spaces (total string length in #WREG)
	STRCAT_PRINT ""
	bra		TFT_warn_att_info_exit		; and return...

;=============================================================================

 IFDEF _rx_functions

	global	TFT_advice_switch
TFT_advice_switch:
	rcall	TFT_set_message_window		; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO - skip message in this cycle
	call	TFT_advice_color
	STRCPY_TEXT tswap					; "Swap Tank"
	movlw	dm_warning_length			; dive mode string length
	rcall	TFT_fillup_with_spaces		; fill up FSR2 with spaces (total string length in #WREG)
	STRCAT_PRINT ""
	bra		TFT_warn_att_info_exit		; and return...

	global	TFT_attention_transmitter
TFT_attention_transmitter:
	rcall	TFT_set_message_window		; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO - skip message in this cycle
	call	TFT_attention_color
	STRCPY_TEXT tTransmitter			; "P.Transm."
	movlw	dm_warning_length			; dive mode string length
	rcall	TFT_fillup_with_spaces		; fill up FSR2 with spaces (total string length in #WREG)
	STRCAT_PRINT ""
	bra		TFT_warn_att_info_exit		; and return...

	global	TFT_attention_pres_reading
	global	TFT_warning_pres_reading
TFT_attention_pres_reading:				; entry point for attention
	call	TFT_attention_color			; use attention color
	bra		TFT_common_pres_reading		; continue with common code
TFT_warning_pres_reading:				; entry point for warning
	call	TFT_warning_color			; use warnings color
	;bra	TFT_common_pres_reading		; continue with common code
TFT_common_pres_reading:
	rcall	TFT_set_message_window		; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO - skip message in this cycle
	STRCPY_TEXT tPressure				; "Tank Pres"
	movlw	dm_warning_length			; dive mode string length
	rcall	TFT_fillup_with_spaces		; fill up FSR2 with spaces (total string length in #WREG)
	STRCAT_PRINT ""
	bra		TFT_warn_att_info_exit		; and return...

	global	TFT_attention_sac
TFT_attention_sac:
	rcall	TFT_set_message_window		; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO - skip message in this cycle
	MOVII	int_O_SAC_measured,mpr		; copy measured SAC rate to hi:lo
	call	TFT_color_code_tank_pres_sac; color-code the output
	STRCPY_TEXT tSAC					; "SAC", needs to be exactly 3 chars long
	STRCAT	": "						; ": "
	output_16_3							; print as xxx
	PUTC	" "							; print a dummy char to have string termination at the correct place
	movff	buffer+.7,buffer+.8			; move decimal digit one position to the right
	movlw	"."							; load coding of a decimal point
	movff	WREG,buffer+.7				; place it before decimal digit
	STRCAT_PRINT ""						; dump buffer to screen
	bra		TFT_warn_att_info_exit		; and return...

 ENDIF	; _rx_functions

;=============================================================================

	global	TFT_info_deco
TFT_info_deco							; show info when decompression obligation is steady or decreasing
	rcall	TFT_set_message_window		; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO  - skip message in this cycle
	call	TFT_advice_color			; YES - actually it is a memo, but we break the rules here and display in advice color (green)
	STRCPY_TEXT tDecoInfo				;     - write "Deco Zone"
	movlw	dm_warning_length			;     - select dive mode string length
	rcall	TFT_fillup_with_spaces		;     - fill up FSR2 with spaces (total string length in #WREG)
	STRCAT_PRINT ""						;     - print buffer
	bra		TFT_warn_att_info_exit		;     - and return...

;=============================================================================

 IFDEF _cave_mode

	global	TFT_info_cave_mode
TFT_info_cave_mode:
	rcall	TFT_set_message_window		; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO  - skip message in this cycle
	call	TFT_memo_color				; YES - set memo color
	bsf		win_invert					;     - print in inverse
	STRCPY_TEXT tCaveMode				;     - write "Cave Mode"
	movlw	dm_warning_length			;     - select dive mode string length
	rcall	TFT_fillup_with_spaces		;     - fill up FSR2 with spaces (total string length in #WREG)
	STRCAT_PRINT ""						;     - print buffer
	bcf		win_invert					;     - end inverse printing
	bra		TFT_warn_att_info_exit		;     - and return...


	global	TFT_cave_shutdown_attention
TFT_cave_shutdown_attention:
	rcall	TFT_set_message_window		; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO  - skip message in this cycle
	call	TFT_attention_color			; YES - set warning color
	bra		TFT_cave_shutdown_common	;     - continue with common part


	global	TFT_cave_shutdown_warning
TFT_cave_shutdown_warning:
	rcall	TFT_set_message_window		; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO  - skip message in this cycle
	call	TFT_warning_color			; YES - set warning color
	;bra	TFT_cave_shutdown_common	;     - continue with common part

TFT_cave_shutdown_common:
	STRCPY_TEXT tCaveModeShutdown		; write "X-Cave-X"
	movlw	dm_warning_length			; select dive mode string length
	rcall	TFT_fillup_with_spaces		; fill up FSR2 with spaces (total string length in #WREG)
	STRCAT_PRINT ""						; print buffer
	bra		TFT_warn_att_info_exit		; and return...

 ENDIF	; _cave_mode

;=============================================================================

	global	TFT_warning_saturation
TFT_warning_saturation
	rcall	TFT_set_message_window		; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO - skip message in this cycle
	MOVII	int_O_lead_supersat,mpr		; bank-safe copy of leading tissue's supersaturation
	call	TFT_color_code_gf			; color-code output
;	STRCPY	"GF:  "						; the two spaces are on purpose to align the output with other warnings' outputs
	STRCPY_TEXT tSAT					; print "Sat:"
	PUTC	" "							; add a space to align the output with other warnings' outputs
	bsf		leftbind
	output_8							; print value of lo only, int_O_lead_supersat is limited to 255
	PUTC	"%"
	movlw	dm_warning_length			; dive mode string length
	btfss	divemode					; in dive mode?
	movlw	surf_warning_length			; NO - use surface string length
	rcall	TFT_fillup_with_spaces		; fill up FSR2 with spaces (total string length in #WREG)
	STRCAT_PRINT ""
	bcf		leftbind
	bcf		win_invert
TFT_warn_att_info_exit:
	goto	TFT_standard_color			; and return...


	global	TFT_warning_mbubbles
TFT_warning_mbubbles:
	rcall	TFT_set_message_window		; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO - skip message in this cycle
	call	TFT_attention_color			; set attention color as default
	movff	char_O_deco_warnings,WREG	; bank-safe copy for deco warnings
	btfsc	WREG,mbubble_warning		; are we in the micro bubbles zone right now?
	call	TFT_warning_color			; YES - reconfigure to warning color
	STRCPY_TEXT tMicroBubbles
	movlw	dm_warning_length			; dive mode string length
	btfss	divemode					; in dive mode?
	movlw	surf_warning_length			; NO  - use surface string length
	rcall	TFT_fillup_with_spaces		; fill up FSR2 with spaces (total string length in #WREG)
	STRCAT_PRINT ""
	bra		TFT_warn_att_info_exit		; and return...


	global	TFT_warning_outside
TFT_warning_outside:
	rcall	TFT_set_message_window		; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO - skip message in this cycle
	call	TFT_attention_color
	movff	char_O_deco_warnings,WREG	; bank-safe copy for deco warnings
	btfsc	WREG,outside_warning		; are we outside the ZH-L16 model right now?
	call	TFT_warning_color			; YES - reconfigure to warning color
	STRCPY	"X-ZHL16-X"
	movlw	dm_warning_length			; dive mode string length
	btfss	divemode					; in dive mode?
	movlw	surf_warning_length			; NO  - use surface string length
	rcall	TFT_fillup_with_spaces		; fill up FSR2 with spaces (total string length in #WREG)
	STRCAT_PRINT ""
	bra		TFT_warn_att_info_exit		; and return...


	global	TFT_warning_depth
TFT_warning_depth:
	rcall	TFT_set_message_window		; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO - skip message in this cycle
	call	TFT_warning_color
	STRCPY_TEXT tMaxDepth				; "max.Depth"
	movlw	dm_warning_length			; dive mode string length
	rcall	TFT_fillup_with_spaces		; fill up FSR2 with spaces (total string length in WREG)
	STRCAT_PRINT ""
	bra		TFT_warn_att_info_exit		; and return...


	global	TFT_warning_gas_needs
TFT_warning_gas_needs:
	rcall	TFT_set_message_window		; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO  - skip message in this cycle
	call	TFT_warning_color			; YES - set warning color
	bra		TFT_warning_gas_needs_com	;     - continue with common part

	global	TFT_attention_gas_needs
TFT_attention_gas_needs:
	rcall	TFT_set_message_window		; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO  - skip message in this cycle
	call	TFT_attention_color			; YES - set attention color
	;bra	TFT_warning_gas_needs_com	;     - continue with common part

TFT_warning_gas_needs_com:
	STRCPY_TEXT tGasNeedsWarn			; print "Gas Needs"
	movlw	dm_warning_length			; dive mode string length
	rcall	TFT_fillup_with_spaces		; fill up FSR2 with spaces (total string length in WREG)
	STRCAT_PRINT ""						; finalize output
	bra		TFT_warn_att_info_exit		; and return...

;=============================================================================

 IFDEF _helium

	global	TFT_warning_IBCD
TFT_warning_IBCD:
	rcall	TFT_set_message_window		; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO - skip message in this cycle
	call	TFT_attention_color			; select attention color as default
	STRCPY_TEXT tIBCD					; "IBCD N2He"
	movlw	dm_warning_length			; dive mode string length
	rcall	TFT_fillup_with_spaces		; fill up FSR2 with spaces (total string length in WREG)
	STRCAT_PRINT ""
	bra		TFT_warn_att_info_exit		; and return...

 ENDIF

;=============================================================================

	global	TFT_warning_no_BO_gas
TFT_warning_no_BO_gas:
	rcall	TFT_set_message_window		; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO - skip message in this cycle
	call	TFT_warning_color			; select warning color
	STRCPY_TEXT tnoBOgas				; print "-B/O-Gas-"
	movlw	dm_warning_length			; dive mode string length
	rcall	TFT_fillup_with_spaces		; fill up FSR2 with spaces (total string length in WREG)
	STRCAT_PRINT ""						; finalize output
	bra		TFT_warn_att_info_exit		; and return...


	global	TFT_advice_gas_change
TFT_advice_gas_change:
	rcall	TFT_set_message_window		; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO - skip message in this cycle
	call	TFT_advice_color			; set advice color
	STRCPY_TEXT tgaschange				; "Change?"
	movlw	dm_warning_length			; dive mode string length
	rcall	TFT_fillup_with_spaces		; fill up FSR2 with spaces (total string length in WREG)
	STRCAT_PRINT ""
	bra		TFT_warn_att_info_exit		; and return...

;=============================================================================

 IFDEF _external_sensor

	global	TFT_warning_sensor_disagree
TFT_warning_sensor_disagree:
	rcall	TFT_set_message_window		; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO - skip message in this cycle
	call	TFT_warning_color
	STRCPY_TEXT tSensorDisagree			; "Sensors<>"
	movlw	dm_warning_length			; dive mode string length
	rcall	TFT_fillup_with_spaces		; fill up FSR2 with spaces (total string length in WREG)
	STRCAT_PRINT ""
	bra		TFT_warn_att_info_exit		; and return...

 ENDIF	; _external_sensor

;=============================================================================

TFT_set_message_window:						; sets the row and column for the current message
	; ignore warning (now)?
	decf	message_counter,W				; load (message counter - 1) into WREG
	bcf		STATUS,C						; clear carry bit
	btfss	alt_layout_active				; in alternative layout?
	rrcf	WREG,W							; NO - divide (message_counter-1) by 2 to get the page of the message
	cpfseq	message_page					; page of the message = current page ?
	retlw	.255							; NO  - do not show in this cycle  (message window is not defined)
	btfss	divemode						; YES - in dive mode?
	bra		TFT_set_message_window_sf		;       NO  - setup for surface mode
	;bra	TFT_set_message_window_dm		;       YES - setup for dive mode

; Dive Mode
TFT_set_message_window_dm:
	btfsc	alt_layout_active							; in alternative layout?
	bra		TFT_set_message_window_dm_row2				; YES - alternative layout only uses 2nd row
	btfss	message_counter,0							; NO  - is the message number uneven?
	bra		TFT_set_message_window_dm_row2				;       NO  - use 2nd row
	;bra	TFT_set_message_window_dm_row1				;       YES - use 1st row

TFT_set_message_window_dm_row1:
	WIN_SMALL dm_warning1_column, dm_warning1_row		; set output position
	bcf		message_2nd_row_used						; flag that the 2nd does not contain a message yet
	retlw	.0											; show in this cycle (message window is defined)

TFT_set_message_window_dm_row2:
	WIN_SMALL dm_warning2_column, dm_warning2_row		; set output position
	bsf		message_2nd_row_used						; flag that the 2nd row contains a message now
	retlw	.0											; show in this cycle (message window is defined)

; Surface Mode
TFT_set_message_window_sf:
	btfss	message_counter,0							; is the message counter uneven?
	bra		TFT_set_message_window_sf_row2				; NO  - use 2nd row
	;bra	TFT_set_message_window_sf_row1				; YES - use 1st row

TFT_set_message_window_sf_row1:
	WIN_SMALL surf_warning1_column,surf_warning1_row	; set output position
	bcf		message_2nd_row_used						; flag that the 2nd row does not contain a message yet
	retlw	.0											; show in this cycle (message window is defined)

TFT_set_message_window_sf_row2:
	WIN_SMALL surf_warning2_column,surf_warning2_row	; set output position
	bsf		message_2nd_row_used						; flag that the 2nd row contains a message now
	retlw	.0											; show in this cycle (message window is defined)


	global	TFT_msg_batt_percent_divemode
TFT_msg_batt_percent_divemode:
	rcall	TFT_set_message_window		; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO - skip message in this cycle
	movff	batt_percent,lo				; get battery percent
	call	TFT_color_code_battery		; color-code battery percent
	STRCPY	"Batt:"
	bsf		leftbind
	output_8
	bcf		leftbind
	PUTC	"%"
	movlw	dm_warning_length			; dive mode string length
	btfss	divemode					; in dive mode?
	movlw	surf_warning_length			; NO - use surface string length
	rcall	TFT_fillup_with_spaces		; fill up FSR2 with spaces (total string length in #WREG)
	STRCAT_PRINT ""
	bcf		win_invert
	bra		TFT_custview_exit1			; and return...


	global	TFT_gf_factors_mask			; mask for GF factors
TFT_gf_factors_mask:
	call	TFT_divemask_color
	WIN_TINY dm_custom_gf_column1,dm_custom_gf_title_row
	STRCPY_TEXT_PRINT tGFactors
	WIN_TINY dm_custom_gf_column3,dm_custom_gf_title_row
	STRCPY_TEXT_PRINT taGFactors
	; Show GF (static)
	call	TFT_disabled_color			; default to disabled color
	btfss	use_aGF						; shall use alternative GF factors?
	call	TFT_memo_color				; NO - switch to memo color
	WIN_STD	dm_custom_gf_column1, dm_custom_gf_row
	bsf		leftbind
	movff	opt_GF_low,lo				; get   normal GF low
	output_8							; print normal GF low
	PUTC	"/"							; print "/"
	movff	opt_GF_high,lo				; get   normal GF high
	output_8							; print normal GF high
	STRCAT_PRINT ""						; finish output
	; Show aGF (static)
	call	TFT_memo_color				; default to memo color
	TSTOSS	opt_enable_aGF				; are alternative GF factors enabled?
	bra		TFT_gf_factors_mask_3		; NO  - show "---" and return
										; YES - show aGF and which one is active
	WIN_STD	dm_custom_gf_column2, dm_custom_gf_row
	btfss	use_aGF						; shall use aGF?
	bra		TFT_gf_factors_mask_1		; NO   - print "<- "
	STRCPY_PRINT " ->"					; YES  - print " ->"
	bra		TFT_gf_factors_mask_2		;      - continue with common part
TFT_gf_factors_mask_1:
	STRCPY_PRINT "<- "					; (NO) - print "<- "
TFT_gf_factors_mask_2:					; common part
	btfss	use_aGF						; shall use aGF?
	call	TFT_disabled_color			; NO - switch to disabled color
	WIN_STD	dm_custom_gf_column3, dm_custom_gf_row
	movff	opt_aGF_low,lo				; get aGF low
	output_8							; print 
	PUTC	"/"							; print "/"
	movff	opt_aGF_high,lo				; get aGF high
	output_8							; print
	STRCAT_PRINT ""						; finish output
	bra		TFT_custview_exit1			; done
TFT_gf_factors_mask_3:
	WIN_STD	dm_custom_gf_column3+.10, dm_custom_gf_row
	STRCPY_PRINT "---"
	bra		TFT_custview_exit1			; done


	global	TFT_ceiling_GF_tissue_mask	; mask for ceiling, current GF and tissues
TFT_ceiling_GF_tissue_mask:
	call	TFT_divemask_color
	WIN_TINY dm_custom_ceiling_column+.2,dm_custom_ceiling_title_row
	STRCPY_TEXT_PRINT tCeiling
	WIN_TINY dm_custom_tissue_title_column, dm_custom_tissue_title_row
	STRCPY_TEXT_PRINT tDiveTissues
	WIN_TINY dm_custom_gf_column1+.5, dm_custom_gf_title_row
	STRCPY_TEXT_PRINT tGFInfo
	bra		TFT_custview_exit1			; and return...


	global	TFT_ceiling_GF_tissue		; data for ceiling, current GF and tissues
TFT_ceiling_GF_tissue:
	WIN_MEDIUM dm_custom_ceiling_column,dm_custom_ceiling_row
	MOVII	int_O_ceiling,mpr			; get ceiling in [mbar] relative pressure
	call	TFT_color_code_ceiling		; color-code the output (also strips off flags)
	call	convert_pres_to_depth		; convert pressure in [mbar] to depth in [cm]
	TSTOSS	opt_units					; 0=m, 1=ft
	bra		TFT_ceiling_tissue_cGF_m
	call	convert_cm_to_feet			; convert value in hi:lo from [cm] to [feet]
	output_16_3							; yxz
	bra		TFT_ceiling_tissue_cGF0
TFT_ceiling_tissue_cGF_m:
	bsf		leftbind
	bsf		ignore_digit5				; no cm (flag will be cleared by output_16)
	output_16dp .3						; yxz.a
	bcf		leftbind
TFT_ceiling_tissue_cGF0:
	STRCAT_PRINT " "
	; Show tissue diagram
	call	TFT_dive_tissues			; show tissue pressure diagram
	; Show current supersaturation
	WIN_MEDIUM dm_custom_clock_column+.3, dm_custom_gf_row
	MOVII	int_O_lead_supersat,mpr		; bank-safe copy of leading tissue's supersaturation
	call	TFT_color_code_gf			; color-code output
	output_8							; need to print lo only, int_O_lead_supersat value is limited to 255
	STRCAT_PRINT ""
	WIN_STD	dm_custom_clock_column+.40, dm_custom_gf_row+.5
	STRCAT_PRINT "%"					; % is printed in color set by TFT_color_code_gf, too
TFT_custview_exit1:
	bcf		leftbind
	goto	TFT_standard_color			; and return...


	global	TFT_clock_batt_surfpress_mask ; mask for clock, battery and surface pressure
TFT_clock_batt_surfpress_mask:
	call	TFT_divemask_color
	WIN_TINY dm_custom_clock_column, dm_custom_clock_title_row
	STRCPY_TEXT_PRINT tTime				; "Time"
	WIN_TINY dm_custom_battery_column, dm_custom_battery_title_row
	STRCPY_TEXT_PRINT tBattery			; "Battery"
	WIN_TINY dm_custom_surfpres_column+.8, dm_custom_surfpres_title_row
	STRCPY_TEXT_PRINT tSurface			; "Surface"
	; Show configured Surface Pressure (done in mask, because it's static during the dive)
	call	TFT_standard_color
	WIN_SMALL dm_custom_surfpres_column, dm_custom_surfpres_row
	MOVII	pressure_surf,mpr
	output_16
	PUTC	' '
	STRCAT_TEXT_PRINT tMBAR				; mbar (hPa)
	bra		TFT_custview_exit1			; and return...


	global	TFT_clock_batt_surfpress	; data for clock, battery and surface pressure
TFT_clock_batt_surfpress:
	; Update Clock
	WIN_SMALL dm_custom_clock_column, dm_custom_clock_row
	call	TFT_standard_color
	SMOVSS	rtc_year,rtc_latched_year	; ISR-safe 6 byte copy of date and time
	movff	rtc_latched_hour,lo
	output_99
	PUTC	':'
	movff	rtc_latched_mins,lo
	output_99x
	PUTC	":"
	movff	rtc_latched_secs,lo
	output_99x
	STRCAT_PRINT ""
	; Show Battery Volt
	call	TFT_memo_color
	WIN_SMALL dm_custom_battery_column, dm_custom_battery_volt_row
	MOVII	batt_voltage,mpr
	bsf		leftbind
	output_16dp .2						; print as -x.yyy
	PUTC	'V'
	movff	buffer+5,buffer+4
	movlw	0x00
	movff	WREG,buffer+5				; only "x.yzV"
	STRCAT_PRINT ""
	; Show Battery Percent
	WIN_SMALL dm_custom_battery_column+.7, dm_custom_battery_percent_row
	movff	batt_percent,lo				; get battery percent
	call	TFT_color_code_battery		; color-code battery percent
	output_8
	STRCAT	"% "
	movlw	0x00
	movff	WREG,buffer+4				; only "xxx%"
	STRCAT_PRINT ""
	; Surface pressure is shown in mask because it is static
	bra		TFT_custview_exit1			; and return...

;=============================================================================

 IFDEF _ccr_pscr

	global	TFT_pscr_info_mask			; mask for pSCR info
TFT_pscr_info_mask:
	rcall	TFT_show_ppo2_mask
	call	TFT_divemask_color
	WIN_TINY dm_custom_pscr_drop_column, dm_custom_pscr_title_row
	STRCPY_TEXT_PRINT tPSCR_O2_drop
	WIN_TINY dm_custom_pscr_ratio_column, dm_custom_pscr_title_row
	STRCPY_TEXT_PRINT tPSCR_lungratio
	bra		TFT_custview_exit1			; and return...


	global	TFT_pscr_info				; data for pSCR info
TFT_pscr_info:
	;show ppO2
	WIN_MEDIUM dm_custom_ppo2_column,dm_custom_ppo2_row
	MOVII	int_O_pSCR_ppO2,mpr			; copy pSCR ppO2 to hi:lo
	call	TFT_color_code_ppo2			; color-code output
	bsf		leftbind
	output_16dp .3						; x.xx bar
	bcf		leftbind
	STRCAT_PRINT ""
	; Show drop
	WIN_STD dm_custom_pscr_drop_column+.11,dm_custom_pscr_row
	call	TFT_memo_color
	movff	char_I_PSCR_drop,lo
	bsf		leftbind
	output_8
	STRCAT_PRINT "%"
	; Show lung ratio
	WIN_STD dm_custom_pscr_ratio_column+.5,dm_custom_pscr_row
	movff	char_I_PSCR_lungratio,lo
	bsf		leftbind
	STRCPY	"1/"
	output_8
	STRCAT_PRINT ""
	bra		TFT_custview_exit1			; and return...

 ENDIF	; _ccr_psrc

;=============================================================================

	global	TFT_gas_needs_mask			; mask for gas needs ascent
TFT_gas_needs_mask:
	WIN_TINY dm_custom_gas_column_title, dm_custom_gas_mask_row
	call	TFT_divemask_color
 IFDEF _cave_mode
	movff	char_O_deco_info,WREG		; get the deco info vector
	btfss	WREG,gas_needs_cave			; are the gas needs calculated for cave mode?
	bra		TFT_gas_needs_mask_ascent_1	; NO  - show as direct ascent needs
	bsf		gas_needs_mode_last			; YES - remember last results were for cave mode
	STRCPY_TEXT tGasNeedsCaveMode		;     - "Gas Needs Cave Mode"
	bra		TFT_gas_needs_mask_ascent_2
TFT_gas_needs_mask_ascent_1:
	bcf		gas_needs_mode_last			; remember last results were for direct ascent
	STRCPY_TEXT tGasNeedsAscent			; "Gas Needs Ascent"
TFT_gas_needs_mask_ascent_2:
 ELSE
	STRCPY_TEXT tGasNeedsAscent			; "Gas Needs Ascent"
 ENDIF
	movff	char_O_deco_info,WREG		; get the deco info vector
	btfss	WREG,gas_needs_fTTS			; are the gas needs calculated for fTTS?
	bra		TFT_gas_needs_mask_ascent_3	; NO  - continue
	STRCAT	" fTTS"						; YES - append fTTS marking
TFT_gas_needs_mask_ascent_3:
	STRCAT_PRINT " (bar)"				; " (bar)"
	bra		TFT_custview_exit1			; and return...


	global	TFT_gas_needs				; data for gas needs ascent
TFT_gas_needs:							; LIMITATION: there is only space for 4 gases on the screen - if 5 gases have a pres_need > 0, then only the first 4 will be shown!
 IFDEF _cave_mode
	movff	char_O_deco_info,WREG		; get deco info vector
	btfss	WREG,gas_needs_cave			; are the gas needs calculated for cave mode?
	bra		TFT_gas_needs_ascent_1		; NO  - continue below...
	btfsc	gas_needs_mode_last			; YES - were the last results calculated for cave mode?
	bra		TFT_gas_needs_ascent_3		;       YES - mask still valid
	bra		TFT_gas_needs_ascent_2		;       NO  - redraw mask
TFT_gas_needs_ascent_1:
	btfss	gas_needs_mode_last			; NO  - were the last results calculated for direct ascent?
	bra		TFT_gas_needs_ascent_3		;       YES - mask still valid
	;bra	TFT_gas_needs_ascent_2		;       NO  - redraw mask
TFT_gas_needs_ascent_2:
	rcall	TFT_gas_needs_mask			; redraw mask
TFT_gas_needs_ascent_3:
 ENDIF
	clrf	up							; initialize gas index (0-4)
	WIN_SMALL dm_custom_gas_column1+.5,dm_custom_gas_row1
	rcall	TFT_gas_needs_helper
	WIN_SMALL dm_custom_gas_column1+.5,dm_custom_gas_row2
	rcall	TFT_gas_needs_helper
	WIN_SMALL dm_custom_gas_column2+.5,dm_custom_gas_row1
	rcall	TFT_gas_needs_helper
	WIN_SMALL dm_custom_gas_column2+.5,dm_custom_gas_row2
	rcall	TFT_gas_needs_helper
	bra		TFT_custview_exit2			; and return...

TFT_gas_needs_helper:
	call	TFT_memo_color
	movlw	.5							; number of gases
	cpfslt	up							; check if all gases have been processed
	bra		TFT_gas_needs_helper_1		; YES - clear display area
	movf	up,W						; NO  - get gas number and check if need of that gas is > 0
	rlncf	WREG,W						; multiply by 2
	incf	WREG,W						; add 1 to address high byte
	lfsr	FSR1,int_O_gas_need_pres	; load base of gas needs in pressure
	movff	PLUSW1,hi					; read HIGH(int_O_gas_need_pres[up])
	btfss	hi,int_is_zero				; check flag for pres_need == 0
	bra		TFT_gas_needs_helper_2		; NO  - print gas type and pressure needed
	incf	up,F						; YES - increment to next gas...
	bra		TFT_gas_needs_helper		; ...and try the next gas
TFT_gas_needs_helper_1:					; no gases to show anymore, clear display area from potential remains of last invocation
	STRCAT_PRINT "  ----   "			; overwrite outdated stuff if screen position is not needed
	return
TFT_gas_needs_helper_2:					; output gas type and pressure needed
	movf	up,W						; get gas number (0-4) to WREG
	lfsr	FSR1,opt_gas_O2_ratio		; read opt_gas_O2_ratio[WREG]
	movff	PLUSW1,lo					; copy result to lo
	lfsr	FSR1,opt_gas_He_ratio		; read opt_gas_He_ratio[WREG]
	movff	PLUSW1,hi					; copy result to hi
	call	gaslist_show_mix			; print "Air", "O2", "21/35", etc.
	PUTC	':'							; ":"
	movf	up,W						; get gas number (0-4) to WREG
	rlncf	WREG,W						; multiply by 2
	lfsr	FSR1,int_O_gas_need_pres	; load base of gas needs in pressure
	movff	PLUSW1,lo					; read LOW(int_O_gas_need_pres[up])
	incf	WREG,W						; add 1 to address high byte
	movff	PLUSW1,hi					; read HIGH(int_O_gas_need_pres[up])
	btfsc	hi,int_attention_flag		; check if attention flag is set (pres_need > pres_fill * threshold)
	call	TFT_attention_color			; YES - print gas need in attention color
	btfsc	hi,int_warning_flag			; check if warning   flag is set (pres_need > pres_fill)
	call	TFT_warning_color			; YES - print gas need in warning color
	movff	int_O_gas_need_pres+1,WREG	; get HIGH(int_O_gas_need_pres[0]) which holds flag for invalid data
	btfsc	WREG,int_invalid_flag		; check if invalid data flag is set
	call	TFT_disabled_color			; YES - print gas need in disabled color
	bcf		hi,int_attention_flag		; clear flag for attention
	bcf		hi,int_warning_flag			; clear flag for warning
	bcf		hi,int_high_flag			; clear flag for > 999 bar
	bcf		hi,int_invalid_flag			; clear flag for invalid data (will actually only be set with 1st gas)
	output_16_3							; limit to 999 and display only (0-999)
	STRCAT_PRINT " "					; adds a space to overwrite any potential remains of earlier outputs
	incf	up,F						; increment to next gas
	return								; done


	global	TFT_show_ppo2_mask			; helper function for several custom views
TFT_show_ppo2_mask:
	call	TFT_divemask_color
 IFDEF _ccr_pscr
	btfss	FLAG_ccr_mode				; in CCR mode?
	bra		TFT_mask_ppo2a				; NO  - continue checking for pSCR and OC
	btfsc	bailout_mode				; YES - in bailout?
	bra		TFT_mask_ppo2b				;       YES
	WIN_TINY dm_custom_ppo2_column-.2,dm_custom_ppo2_title_row	; tuned position for longer text (-8 = on leftmost edge of display)
	STRCPY_TEXT_PRINT tppO2Dil			;       NO  - print "ppO2(Dil)"
	bra		TFT_custview_exit2			;           - and return...
TFT_mask_ppo2a:
	btfss	FLAG_pscr_mode				; in pSCR mode?
	bra		TFT_mask_ppo2b				; NO  - continue with OC mode (or bailout)
	btfsc	bailout_mode				; YES - in bailout?
	bra		TFT_mask_ppo2b				;       YES
	WIN_TINY dm_custom_ppo2_column-.2,dm_custom_ppo2_title_row	; tuned position for longer text (-8 = on leftmost edge of display)
	STRCPY_TEXT_PRINT tppO2Mix			;       NO  - print "ppO2(Mix)"
	bra		TFT_custview_exit2			;           - and return...
 ENDIF
TFT_mask_ppo2b:							; OC mode or bailout
	WIN_TINY dm_custom_ppo2_column-.2, dm_custom_ppo2_title_row	; normal position
	STRCPY_TEXT_PRINT tppO2				; in all other modes
	bra		TFT_custview_exit2			; and return...


	global TFT_ppo2_ead_end_cns_mask	; mask for ppO2, END/EAD and CNS / gas density
TFT_ppo2_ead_end_cns_mask:
	call	TFT_divemask_color
	WIN_TINY dm_custom_ppo2_column-.2, dm_custom_ppo2_title_row
	STRCPY_TEXT_PRINT tppO2
	WIN_TINY dm_custom_ead_column,     dm_custom_eadend_title_row
	STRCPY_TEXT_PRINT tDiveEAD_END
 IFDEF _helium
	WIN_TINY dm_custom_cns_column-.5,  dm_custom_eadend_title_row
	STRCPY_TEXT_PRINT tGasDensity
 ELSE
	WIN_TINY dm_custom_cns_column,     dm_custom_cns_title_row
	STRCPY_TEXT_PRINT tCNS2
 ENDIF
	bra		TFT_custview_exit2			; and return...


	global	TFT_ppo2_ead_end_cns		; data for ppO2, END/EAD and CNS / gas density
TFT_ppo2_ead_end_cns:
	; Show ppO2
	WIN_MEDIUM dm_custom_ppo2_column, dm_custom_ppo2_row
	MOVII	int_O_breathed_ppO2,mpr		; copy ppO2 of the currently breathed gas to hi:lo
	call	TFT_color_code_ppo2			; color-code output
	bsf		leftbind
	output_16dp .3						; x.xx bar
	bcf		leftbind
	STRCAT_PRINT ""
	call	TFT_standard_color
	; Show END/EAD
	WIN_SMALL	dm_custom_ead_column, dm_custom_ead_row
	STRCPY_TEXT tEAD					; EAD:
	MOVII	int_O_EAD_pres,mpr			; copy EAD in [mbar] to MPR
	rcall	TFT_end_ead_common			; convert to depth, print and limit to 8 chars
	WIN_SMALL dm_custom_end_column, dm_custom_end_row
	STRCPY_TEXT tEND					; END:
	MOVII	int_O_END_pres,mpr			; copy END in [mbar] to MPR
	rcall	TFT_end_ead_common			; convert to depth, print and limit to 8 chars
 IFDEF _helium
	; Show Gas Density
	WIN_MEDIUM	dm_custom_cns_column-.5, dm_custom_cns_row
	MOVII	int_O_gas_density,mpr		; get current gas density
	call	TFT_color_code_cns_1		; color-code output
	bsf		leftbind					; print left-aligned
	movlw	.2							; suppress first and second digit
	movwf	ignore_digits				; ...
	output_16dp .2						; print as -x.yyy
	bcf		leftbind					; back to normal alignment
	STRCAT_PRINT	""					; finalize output
 ELSE
	; Show CNS
	WIN_STD	dm_custom_cns_column+.3, dm_custom_cns_row
	MOVII	int_O_CNS_current,mpr		; get current CNS
	call	TFT_color_code_cns			; color-code CNS output
	bsf		leftbind
	output_16_3							; displays only 0...999
	bcf		leftbind
	STRCAT_PRINT "%"
 ENDIF
TFT_custview_exit2:
	goto	TFT_standard_color			; and return...

TFT_end_ead_common:
	call	convert_pres_to_depth		; convert pressure in [mbar] to depth in [cm]
	TSTOSS	opt_units					; 0=Meter, 1=Feet
	bra		TFT_end_ead_common_metric	; 0: meter
	;bra	TFT_end_ead_common_imperial	; 1: feet

TFT_end_ead_common_imperial:
	call	convert_cm_to_feet			; convert depth in [cm] to depth in [feet]
	output_16_3							; print as xyz
	bra		TFT_end_ead_common_exit

TFT_end_ead_common_metric:
	bsf		ignore_digit4				; no decimals (flag will be cleared by output_16)
	output_16dp .3						; print as yxz.--
	movlw	'm'							; hard-coded unit
	movff	WREG,buffer+.7				; place the unit onto the decimal point
	;bra	TFT_end_ead_common_exit

TFT_end_ead_common_exit:
	STRCAT_PRINT ""						; finalize output
	return								; done

;=============================================================================

 IFDEF _ccr_pscr

	global	TFT_sensor_check_mask		; mask for sensor check
TFT_sensor_check_mask:
	call	TFT_divemask_color
	WIN_TINY dm_custom_s_check_title_column, dm_custom_s_check_title_row
	STRCPY_TEXT_PRINT tSensorCheck
	WIN_TINY dm_custom_ppO2_column, dm_custom_s_check_title_row
	STRCPY_TEXT_PRINT tppO2O2
	WIN_TINY dm_custom_ppDil_column, dm_custom_s_check_title_row
	STRCPY_TEXT_PRINT tppO2Dil
	bra		TFT_sensor_check_exit		; and return...


	global	TFT_sensor_check			; data for sensor check
TFT_sensor_check:
	; Show ppO2 of O2 in this depth
	WIN_MEDIUM dm_custom_ppO2_column, dm_custom_s_check_row
	MOVII	int_O_O2_ppO2,mpr			; copy ppO2 of pure O2 to hi:lo
	call	TFT_color_code_ppo2			; color-code output
	bsf		leftbind
	output_16dp .3						; x.xx bar
	bcf		leftbind
	STRCAT_PRINT ""
	; Show ppO2 of the diluent in this depth
	WIN_MEDIUM	dm_custom_ppDil_column, dm_custom_s_check_row
	MOVII	int_O_pure_ppO2,mpr			; copy ppO2 of pure gas to hi:lo
	call	TFT_color_code_ppo2			; color-code output
	bsf		leftbind
	output_16dp .3						; x.xx bar
	bcf		leftbind
	STRCAT_PRINT ""
TFT_sensor_check_exit:
	bra		TFT_custview_exit2			; and return...

 ENDIF	; _ccr_pscr

;=============================================================================

	global	TFT_surface_lastdive
TFT_surface_lastdive:
	WIN_TINY surf_gaslist_column,surf_gaslist_row+.5
	STRCAT_TEXT_PRINT	tLastDive			; "Last Dive:"
	WIN_TINY surf_gaslist_column,surf_gaslist_row+(surf_gaslist_spacing*.1)+.5
	STRCAT_TEXT_PRINT	tDivetime			; "Divetime:"
	WIN_TINY surf_gaslist_column,surf_gaslist_row+(surf_gaslist_spacing*.2)+.5
	STRCAT_TEXT_PRINT	tMaxDepth			; "Max.Depth"
	WIN_TINY surf_gaslist_column,surf_gaslist_row+(surf_gaslist_spacing*.3)+.5
	STRCAT_TEXT_PRINT	tAvgDepth			; "Average"

	WIN_SMALL surf_gaslist_column+.48,surf_gaslist_row
	SMOVII	int_O_desaturation_time,mpr		; ISR-safe copy of the desaturation time
	movf	mpr+0,W							; get low byte into WREG
	iorwf	mpr+1,W							; inclusive-or with high byte, check if desaturation time is zero
	bz		TFT_surface_lastdive_1			; YES - show last dive time
											; NO  - show surface interval
	SMOVII	surface_interval_mins,mpr		;     - ISR-safe copy of surface interval in minutes
	call	convert_time					;     - convert hi:lo in minutes to hours (up:hi) and minutes (lo)
	movf	hi,W							;     - swap hi and lo
	movff	lo,hi							;       ...
	movwf	lo								;       ...
	bsf		leftbind						;
	output_99x								;
	PUTC	'h'								;
	movff	hi,lo							;
	output_99x								;
	STRCAT_PRINT "m "						;
	bra		TFT_surface_lastdive_2			;
TFT_surface_lastdive_1:
	SMOVQQ	surface_interval_secs,xC		; ISR-safe copy of surface_interval_secs:4 to xC:4
	call	info_menu_uptime_com			; use part of info_menu_uptime to convert and display in days and hours
	STRCAT_PRINT ""							; finalize output
TFT_surface_lastdive_2:
	WIN_SMALL surf_gaslist_column+.48,surf_gaslist_row+(surf_gaslist_spacing*.1)
	MOVII	lastdive_duration,mpr			; get duration of last dive, minutes
	bsf		leftbind						; print without leading spaces
	output_16								; dive time minutes
	PUTC	":"								;
	movff	lastdive_duration+2,lo			; get duration of last dive, seconds
	output_99x								; print seconds
	rcall	TFT_surface_common				; finalize output
TFT_surface_lastdive_3:
	WIN_SMALL	surf_gaslist_column+.48,surf_gaslist_row+(surf_gaslist_spacing*.2)
	MOVII	lastdive_maxdepth,mpr			; get max depth of last dive
	bsf		leftbind						; print without leading spaces
	TSTOSS	opt_units						; 0=Meter, 1=Feet
	bra		TFT_surface_lastdive_metric		; 0 - metric
	rcall	TFT_surface_imperial			; 1 - imperial
	bra		TFT_surface_lastdive_4			;   - continue
TFT_surface_lastdive_metric:
	rcall	TFT_surface_metric				; print depth in meters
TFT_surface_lastdive_4:
	WIN_SMALL	surf_gaslist_column+.48,surf_gaslist_row+(surf_gaslist_spacing*.3)
	MOVII	lastdive_avgdepth,mpr			; get avg depth of last dive
	bsf		leftbind						; print without leading spaces
	TSTOSS	opt_units						; 0=Meter, 1=Feet
	bra		TFT_surface_metric				; 0 - metric   and return
	;bra	TFT_surface_imperial			; 1 - imperial and return

TFT_surface_imperial:
	rcall	convert_cm_to_feet				; convert value in hi:lo from [cm] to [feet]
	output_16_3								; limit to 999 and display only (0-999)
	STRCAT_TEXT tFeets1						; "ft"
	bra		TFT_surface_common				; finalize output

TFT_surface_metric:
	bsf		ignore_digit5					; no cm (flag will be cleared by output_16)
	movlw	.1								; no 1000 meters
	movwf	ignore_digits					; ...
	output_16dp .3							; xxx.y
	STRCAT_TEXT tMeters						; "m"
	;bra	TFT_surface_common				; finalize output

TFT_surface_common:
	STRCAT_PRINT ""							; finalize output
	bcf		leftbind						; clear left-alignment
	return									; done

;=============================================================================

	global	TFT_surface_tissues
TFT_surface_tissues:						; show tissue diagram in surface mode

	; draw outer frame
	WIN_FRAME_STD surf_tissue_diagram_top, surf_tissue_diagram_bottom, surf_tissue_diagram_left, surf_tissue_diagram_right

	;---- draw labels ---------------------------------	;

	call	TFT_standard_color
	WIN_SMALL surf_tissue_N2_column,surf_tissue_N2_row
 IFDEF _helium
	btfss	tissue_graphic_layout			; shall N2 and He?
	bra		TFT_surface_tissues_1			; NO  - print "Tissues"
	STRCPY_TEXT_PRINT tN2					; YES - print "N2"
	WIN_SMALL surf_tissue_He_column,surf_tissue_He_row
	STRCPY_TEXT_PRINT tHe					;     - print "He"
	bra		TFT_surface_tissues_2			;     - continue with common part
 ENDIF

TFT_surface_tissues_1:
	STRCPY_TEXT_PRINT tDiveTissues			; print "Tissues"

TFT_surface_tissues_2:
	;---- draw scale ----------------------------------	;
	movlw	color_deepblue
	call	TFT_set_color

SCALELINE	macro	x
	WIN_FRAME_COLOR16 surf_tissue_diagram_top+.23,surf_tissue_diagram_bottom-.4,surf_tissue_diagram_left+.4+x,surf_tissue_diagram_left+.4+x
	endm

	SCALELINE  .0
	SCALELINE  .8
	SCALELINE .16
	SCALELINE .24
	SCALELINE .32
	SCALELINE .40
	SCALELINE .48
	SCALELINE .56
	SCALELINE .64
	SCALELINE .72
	SCALELINE .80

	;---- common initialization for Tissue Pressures and Saturation ----------
	movlw	.1
	movwf	win_height									; hight of the bargraph (0-239)
	movlw	surf_tissue_diagram_left+.4					; left start position for N2 bars
	movwf	win_leftx2									; column left (0-159)
	movlw	surf_tissue_diagram_right-surf_tissue_diagram_left-.4	; get max width for N2 bars (78 pixel)
	movwf	win_width+0									; set width of the bar box
	clrf	win_width+1									; ...
	movlw	color_white									; color for tissues not exceeding surface max pressure
	movwf	ex											; store in ex
	movlw	color_red									; color for tissues exceeding surface max pressure
	movwf	ul											; store in ul
	bcf		aux_flag									; draw tissue pressures by default

	;---- Draw combined or N2 Tissue Pressures---------	;
	lfsr	FSR2,char_O_tissue_pressure					; load base address of combined pressures by default
 IFDEF _helium
	btfsc	tissue_graphic_layout						; shall show N2+He ?
	lfsr	FSR2,char_O_tissue_pres_N2					; YES - replace with base address of N2 pressures
 ENDIF
	btfsc	tissue_graphic_mode							; in logbook mode?
	lfsr	FSR2,header_buffer+index_tissue_pres_total	; YES - replace with base address from logbook
	movlw	d'16'
	movwf	lo											; tissue counter, 16 tissues
	clrf	hi											; row    counter
TFT_surf_tissues_N2_loop:
	movlw	surf_tissue_diagram_top+.23					; surface mode top start position N2
	rcall	TFT_surf_tissues_bargraph					; show one tissue
	movlw	.2											; bargraph spacing
	addwf	hi,F										; increment row counter
	decfsz	lo,F										; decrement tissue counter, done?
	bra		TFT_surf_tissues_N2_loop					; NO - loop
 IFDEF _helium
	btfsc	tissue_graphic_layout						; shall show N2+He ?
	bra		TFT_surface_tissues_3						; YES - show He tissue pressures
 ENDIF

	;---- Draw Tissue Saturations ---------------------	;
	lfsr	FSR2,char_O_tissue_saturation				; load base address of tissue supersaturation
	btfsc	tissue_graphic_mode							; in logbook mode?
	lfsr	FSR2,header_buffer+index_tissue_supersat	; YES - replace with base address from logbook
	movlw	d'16'
	movwf	lo											; tissue counter, 16 tissues
	clrf	hi											; row    counter
	movlw	color_grey									; color for tissue saturation
	movwf	ex											; store in ex
;	movlw	color_yellow								; 2nd color is not used by tissue saturation
;	movwf	ul											; ...
	bsf		aux_flag									; draw tissue saturation
TFT_surf_tissues_sat_loop:
	movlw	surf_tissue_diagram_top+.23+.57				; surface mode top start position saturations
	rcall	TFT_surf_tissues_bargraph					; draw tissue bargraph
	movlw	.2											; bargraph spacing
	addwf	hi,F										; increment row counter
	decfsz	lo,F										; decrement tissue counter, done?
	bra		TFT_surf_tissues_sat_loop					; NO - loop

	;---- common Part for vertical lines--------------- ;
	movlw	surf_tissue_diagram_top+.23+.57				; get top position
	movwf	win_top										; set top position (0-239)
	movlw	.30											; get hight
	movwf	win_height									; set height
	movlw	.1											; get width
	movwf	win_width+0									; set width, low  byte
	clrf	win_width+1									; set width, high byte

	;---- Print 100% Line -----------------------------	;
	movlw	surf_tissue_diagram_left+.4+.64				; get left position
	movwf	win_leftx2									; set left position (0-159)
	movlw	color_red									; color for 100% line
	call	TFT_set_color								; set color
	call	TFT_box										; draw line

	; GF factors enabled?
	btfss	tissue_graphic_gf							; GF factors enabled?
	bra		TFT_surface_tissues_4						; NO - continue with CNS

	;---- Print GF low Line --------------------------	;
	movlw	surf_tissue_diagram_left+.4					; get left base position
	movwf	win_leftx2									; set left base position (0-159)
	movff	opt_GF_low,WREG								; get GF low in 0.01 %
	btfsc	tissue_graphic_mode							; in logbook mode?
	movff	header_buffer+index_gf_lo_hi+0,WREG			; YES - replace by GF low from logbook
	mullw	.164										; multiply with 164
	movf	PRODH,W										; divide   by   256 -> resulting scale factor is 164/256 = 0.640625
	addwf	win_leftx2,F								; add to base position
	movlw	color_green									; color for 100% line
	call	TFT_set_color								; set color
	call	TFT_box										; draw line

	;---- Print GF high Line --------------------------	;
	movlw	surf_tissue_diagram_left+.4					; get left base position
	movwf	win_leftx2									; set left base position (0-159)
	movff	opt_GF_high,WREG							; get GF high in 0.01 %
	btfsc	tissue_graphic_mode							; in logbook mode?
	movff	header_buffer+index_gf_lo_hi+1,WREG			; YES - replace by GF high from logbook
	mullw	.164										; multiply with 164
	movf	PRODH,W										; divide   by   256 -> resulting scale factor is 164/256 = 0.640625
	addwf	win_leftx2,F								; add to base position
	movlw	color_yellow								; color for 100% line
	call	TFT_set_color								; set color
	call	TFT_box										; draw line
	bra		TFT_surface_tissues_4						; continue with CNS

 IFDEF _helium
TFT_surface_tissues_3:
	;---- Draw He Tissue Pressures---------------------	;
	movlw	surf_tissue_diagram_left+.4+.16				; start position for He bars
	movwf	win_leftx2									; column left (0-159)
	movlw	surf_tissue_diagram_right-surf_tissue_diagram_left-.4-.16	; max width for He bars
	movwf	win_width+0									; set total width of the bar box
	clrf	win_width+1									; ...
	lfsr	FSR2,char_O_tissue_pres_He					; load base address of He pressures
	movlw	d'16'
	movwf	lo											; tissue counter, 16 tissues
	clrf	hi											; row    counter
TFT_surf_tissues_He_loop:
	movlw	surf_tissue_diagram_top+.23+.57				; surface mode top start position He
	rcall	TFT_surf_tissues_bargraph					; show one tissue
	movlw	.2											; bargraph spacing
	addwf	hi,F										; increment row counter
	decfsz	lo,F										; decrement tissue counter, done?
	bra		TFT_surf_tissues_He_loop					; NO - loop
 ENDIF

TFT_surface_tissues_4:
	btfss	tissue_graphic_cns							; shall show CNS value?
	goto	TFT_standard_color							; NO  - done

	; ---- Draw CNS% ----------------------------------	;
	WIN_SMALL surf_tissue_He_column+.22,surf_tissue_He_row	; position in-between tissue bars
	MOVII	int_O_CNS_current,mpr						; get current CNS
	call	TFT_color_code_cns							; color-code CNS value
	STRCPY_TEXT tCNS2									; "CNS:"
	bsf		leftbind
	output_16_3											; display only 0...999
	bcf		leftbind
	STRCAT_PRINT "%"
	goto	TFT_standard_color							; and return...

TFT_surf_tissues_bargraph:
	addwf	hi,W										; add row number to start position
	movwf	win_top										; set as row top (0-239)
	movff	POSTINC2,up									; get tissue value
	movf	ex,W										; default color
	btfsc	up,7										; check if flag in bit 7 is set
	movf	ul,W										; YES - switch to 2nd color
	call	TFT_set_color								; set bargraph bar color
	bcf		up,7										; clear flag bit
	btfss	aux_flag									; drawing saturations?
	rlncf	up,F										; NO - multiply with 2 (previously cleared bit 7 will be rotated to bit 0)
	incf	up,W										; add 1 for a minimum visible bar (He-bars could be invisible else-wise)
	movwf	win_bargraph								; set length of the bargraph
	goto	TFT_box										; draw bargraph and return


;=============================================================================
; Draw saturation graph in dive mode custom view
;
TFT_dive_tissues:

	;---- draw outer frame
	call	TFT_standard_color
	WIN_FRAME_COLOR16 dm_custom_tissue_diagram_top, dm_custom_tissue_diagram_bottom, dm_custom_tissue_diagram_left, .159 ; outer frame

	;---- clear area showing leading tissue number as it may not be printed over
	WIN_BOX_BLACK dm_custom_tissue_diagram_top+.16, dm_custom_tissue_diagram_top+.16+.10, dm_custom_tissue_diagram_left+.32, dm_custom_tissue_diagram_left+.32+.8 ; top, bottom, left, right

TFT_dive_tissues_1:
	;---- common initialization for Tissue Pressures and Saturation ----------
	movlw	.1
	movwf	win_height									; hight of the bargraph (0-239)
	movlw	dm_custom_tissue_diagram_left+.3			; get dive mode left start position
	movwf	win_leftx2									; set column left (0-159)
	movlw	.159-dm_custom_tissue_diagram_left-.4		; get max width
	movwf	win_width+0									; set width (low byte)
	clrf	win_width+1									; high byte of with is always zero
	movlw	color_cyan									; color for tissues with decreasing pressure
	movwf	ex											; store in ex
	movlw	color_orange								; color for tissues with increasing pressure
	movwf	ul											; store in ul

	;---- Draw combined or N2 Tissue Pressures --------	;
	lfsr	FSR2,char_O_tissue_pressure					; load base address of combined pressures by default
 IFDEF _helium
	btfsc	tissue_graphic_layout						; shall show N2+He ?
	lfsr	FSR2,char_O_tissue_pres_N2					; YES - load base address of N2 pressures
 ENDIF
	movlw	d'16'
	movwf	lo											; tissue counter, 16 tissues
	clrf	hi											; row    counter
TFT_dive_tissues_N2_loop:
	movlw	dm_custom_tissue_diagram_top+.3				; dive mode top start position N2
	rcall	TFT_dive_tissues_bargraph					; draw tissue bargraph
	incf	hi,F										; increment row counter
	decfsz	lo,F										; decrement tissue counter, done?
	bra		TFT_dive_tissues_N2_loop					; NO - loop
 IFDEF _helium
	btfsc	tissue_graphic_layout						; shall show N2+He ?
	bra		TFT_dive_tissues_3							; YES - show He tissue pressures
 ENDIF

	;---- Draw Tissue Saturations ---------------------	;
	lfsr	FSR2,char_O_tissue_saturation				; load base address of tissue supersaturation
	movlw	d'16'
	movwf	lo											; tissue counter, 16 tissues
	clrf	hi											; row    counter
	movlw	color_grey									; color for tissue saturation, alternative: color_lightblue
	movwf	ex											; store in ex
;	movlw	color_yellow								; 2nd color is not used by tissue saturation
;	movwf	ul											; ...
TFT_dive_tissues_sat_loop:
	movlw	dm_custom_tissue_diagram_top+.3+.22			; dive mode top start position saturations
	rcall	TFT_dive_tissues_bargraph					; draw tissue bargraph
	incf	hi,F										; increment row counter
	decfsz	lo,F										; decrement tissue counter, done?
	bra		TFT_dive_tissues_sat_loop					; NO - loop

	;---- common Part for vertical lines---------------	;
	movlw	dm_custom_tissue_diagram_top+.3+.22			; get top position
	movwf	win_top										; set top position (0-239)
	movlw	.15											; get hight
	movwf	win_height									; set height
	movlw	.1											; get width
	movwf	win_width+0									; set width, low  byte
	clrf	win_width+1									; set width, high byte

	;---- Print 100% Line -----------------------------	;
	movlw	dm_custom_tissue_diagram_left+.3+.33		; get left position
	movwf	win_leftx2									; set left position (0-159)
	movlw	color_red									; color for 100% line
	call	TFT_set_color								; set color
	call	TFT_box										; draw line

	; GF factors enabled?
	btfss	tissue_graphic_gf							; shall show GF lines?
	bra		TFT_dive_tissues_4							; NO - continue with number of leading tissue

	;---- Print GF low Line --------------------------	;
	movlw	dm_custom_tissue_diagram_left+.3			; get left base position
	movwf	win_leftx2									; set left base position (0-159)
	movff	char_I_GF_Low_percentage,WREG				; get GF low in 0.01 %
	mullw	.82											; multiply with 82
	movf	PRODH,W										; divide   by   256 -> resulting scale factor is 82/256 = 0.3203125
	addwf	win_leftx2,F								; add to base position
	movlw	color_green									; color for 100% line
	call	TFT_set_color								; set color
	call	TFT_box										; draw line

	;---- Print GF high Line --------------------------	;
	movlw	dm_custom_tissue_diagram_left+.3			; get left base position
	movwf	win_leftx2									; set left base position (0-159)
	movff	char_I_GF_High_percentage,WREG				; get GF high in 0.01 %
	mullw	.82											; multiply with 82
	movf	PRODH,W										; divide   by   256 -> resulting scale factor is 82/256 = 0.3203125
	addwf	win_leftx2,F								; add to base position
	movlw	color_yellow								; color for 100% line
	call	TFT_set_color								; set color
	call	TFT_box										; draw line
	bra		TFT_dive_tissues_4							; continue with number of leading tissue

 IFDEF _helium
TFT_dive_tissues_3:
	;---- Draw He Tissues Pressures -------------------	;
	lfsr	FSR2,char_O_tissue_pres_He					; load base address of He pressures
	movlw	dm_custom_tissue_diagram_left+.3+.4			; get dive mode left start position for He bars
	movwf	win_leftx2									; set column left (0-159)
	movlw	.159-dm_custom_tissue_diagram_left-.4-.4	; get max width for He bars
	movwf	win_width+0									; set width (low byte)
	clrf	win_width+1									; ...
	movlw	d'16'
	movwf	lo											; tissue counter, 16 tissues
	clrf	hi											; row    counter
TFT_dive_tissues_He_loop:
	movlw	dm_custom_tissue_diagram_top+.3+.22			; dive mode top start position H2
	rcall	TFT_dive_tissues_bargraph					; draw tissue bargraph
	incf	hi,F										; increment row counter
	decfsz	lo,F										; decrement tissue counter, done?
	bra		TFT_dive_tissues_He_loop					; NO  - loop
 ENDIF

TFT_dive_tissues_4:
	;---- Print Number of leading Tissue --------------	; TODO: some flicker due to overwriting by tissue bars
	movff	int_O_lead_supersat+0,WREG					; get current leading tissue's supersaturation (only low byte used for value)
	tstfsz	WREG										; current supersaturation = 0 ?
	bra		TFT_dive_tissues_5							; NO  - print number of leading tissue
	movff	char_O_deco_info,WREG						; YES - get deco info vector
	btfss	WREG,deco_ceiling							;     - do we have a ceiling obligation?
	goto	TFT_standard_color							;       NO  - can ascent directly, don't print number, set standard color and return
														;       YES - print number of leading tissue
TFT_dive_tissues_5:
	movff	char_O_lead_tissue,lo						; get number of leading tissue as 0-15
	incf	lo,F										; adjust to 1-16
	movlw	.10
	cpfsgt	lo											; is it > 10 ?
	bra		TFT_dive_tissues_6							; NO - will output a single digit number
	; start position for a 2 digit number
	WIN_TINY dm_custom_tissue_diagram_left+.32,dm_custom_tissue_diagram_top+.10
	bra		TFT_dive_tissues_7
TFT_dive_tissues_6:
	; start position for a 1 digit number
	WIN_TINY dm_custom_tissue_diagram_left+.32+.4,dm_custom_tissue_diagram_top+.10
TFT_dive_tissues_7:
	call	TFT_standard_color							; set output color
	bsf		leftbind
	output_8											; print number in left aligned, i.e. without leading zeros or spaces
	bcf		leftbind
	STRCAT_PRINT ""										; finalize output
	return

TFT_dive_tissues_bargraph:
	addwf	hi,W										; add row number to start position
	movwf	win_top										; set as row top (0-239)
	movff	POSTINC2,up									; get tissue value
	movf	ex,W										; default color
	btfsc	up,7										; check if flag in bit 7 is set
	movf	ul,W										; YES - switch to 2nd color
	call	TFT_set_color								; set bargraph bar color
	bcf		up,7										; clear flag  bit
	bcf		STATUS,C									; clear carry bit
	rrcf	up,F										; divide by 2
	incf	up,W										; add a bit for a minimum visible bar
	movwf	win_bargraph								; set bargraph bar length
	goto	TFT_box										; draw bargraph and return

;=============================================================================

	global	TFT_show_cns
TFT_show_cns:
	call	TFT_set_message_window		; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO - skip message in this cycle
	STRCPY_TEXT tCNS					; CNS:
	MOVII	int_O_CNS_current,mpr		; get current CNS
	call	TFT_color_code_cns			; color-code CNS output
	bsf		leftbind
	output_16_3							; displays only 0...999
	bcf		leftbind
	PUTC	"%"
	movlw	dm_warning_length			; dive mode string length
	btfss	divemode					; In dive mode?
	movlw	surf_warning_length			; NO - use surface string length
	call	TFT_fillup_with_spaces		; fill up FSR2 with spaces (total string length in WREG)
	STRCAT_PRINT ""
	bcf		win_invert
	bra		TFT_custview_exit3			; and return...


	global	TFT_warning_eod_cns
TFT_warning_eod_cns:
	call	TFT_set_message_window		; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO - skip message in this cycle
	call	TFT_warning_color			; switch to warnings (red) text color
	STRCPY_TEXT tCNSeod					; end-of-dive CNS warning text
	movlw	dm_warning_length			; dive mode string length
	call	TFT_fillup_with_spaces		; fill up FSR2 with spaces (total string length in WREG)
	STRCAT_PRINT ""
	bra		TFT_custview_exit3			; and return...


	global	TFT_show_ppo2_warning
TFT_show_ppo2_warning:
	call	TFT_set_message_window		; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO - skip message in this cycle
	call	TFT_color_code_ppo2			; color-code output
	btfsc	bailout_mode				; in bailout?
	bra		TFT_display_diluent_2		; YES
	btfss	FLAG_ccr_mode				; in CCR mode?
	bra		TFT_display_diluent_1		; NO  - continue with pSCR or OC 
	STRCPY_TEXT tdil					; YES - print "Dil:"
	bra		TFT_display_diluent_3
TFT_display_diluent_1:
	btfss	FLAG_pscr_mode				; in pSCR mode?
	bra		TFT_display_diluent_2		; NO  - continue with OC 
	STRCPY_TEXT tmix					; YES - print "Mix:"
	bra		TFT_display_diluent_3
TFT_display_diluent_2:
	STRCPY_TEXT tppO2					; bailout or OC mode, print "ppO2:"
TFT_display_diluent_3:
	bsf		leftbind
	output_16dp .3						; x.xx bar
	bcf		leftbind
	movlw	dm_warning_length			; dive mode string length
	call	TFT_fillup_with_spaces		; fill up FSR2 with spaces (total string length in #WREG)
	STRCAT_PRINT ""
TFT_custview_exit3:
	goto	TFT_standard_color			; and return...


 IFDEF _compass

	global	TFT_surf_set_bearing
TFT_surf_set_bearing:
	btfsc	compass_menu				; is the "set bearing" selection shown?
	return								; YES - return
	bsf		compass_menu				; NO  - set "set bearing" selection as shown
	WIN_BOX_BLACK surf_compass_bear_row,surf_warning1_row-1, surf_compass_bear_column, surf_decotype_column-.1 ; top, bottom, left, right
	WIN_SMALL surf_compass_bear_column,surf_compass_bear_row
	WIN_COLOR color_yellow
	bsf		win_invert
	STRCPY_TEXT_PRINT tSetHeading		; 7 chars
	bcf		win_invert
	return

 ENDIF

;=============================================================================

	global	TFT_LogOffset
TFT_LogOffset:
	STRCPY_TEXT tLogOffsetValue			; print "Offset" in selected language
	call	eeprom_log_offset_read		; read offset into lo:hi
;	bsf		leftbind
	output_16_4							; print offset in 4 digits
;	bcf		leftbind
	return								; no "_PRINT" here...

;=============================================================================
; RX Functions

 IFDEF _rx_functions

	global	TFT_pressures_SAC_mask			; mask for pressures and SAC
TFT_pressures_SAC_mask:
	call	TFT_divemask_color
	; pressure reading 1
	WIN_TINY dm_custom_tankdata_pres1_col, dm_custom_tankdata_mask_row
	movff	char_I_pressure_gas+0,WREG		; =0: disabled, =1..10: gases/dils
	bcf		aux_flag						; selector for disabled / need set to disabled
	call	TFT_pressures_SAC_mask_helper	; print gas composition or " ---" if disabled
	; pressure reading 2
	WIN_TINY dm_custom_tankdata_pres2_col, dm_custom_tankdata_mask_row
	movff	char_I_pressure_gas+1,WREG		; =0: need to reading 1, =1..10: gases/dils
	bsf		aux_flag						; selector for disabled / need set to need
	call	TFT_pressures_SAC_mask_helper	; print gas composition or "Need " if 0
	; SAC rate
	WIN_TINY dm_custom_tankdata_SAC_col, dm_custom_tankdata_mask_row
	STRCPY_TEXT tSAC						; "SAC
	STRCAT	" ("							;      (
	STRCAT_TEXT tLitersMinute				;       l/min
	STRCAT_PRINT ")"						;            )"
	bra		TFT_custview_exit3				; and return...

TFT_pressures_SAC_mask_helper:
	tstfsz	WREG							; pressure reading assigned?
	bra		TFT_dive_tankdata_mask_helper_1	; YES - print gas composition
	btfsc	aux_flag						; NO  - check auxiliary flag
	bra		TFT_dive_tankdata_mask_helper_2	;       1 - print "Need "
	STRCAT_PRINT "    ---"					;       0 - print "    ---"
	return									;         - done
TFT_dive_tankdata_mask_helper_1:
	decf	WREG,W							; (1..10) -> (0..9)
	bsf		short_gas_descriptions			; just "Air", "O2" or "xx/yy"
	call	gaslist_strcat_gas_WREG			; print composition of gas/dil in WREG (0..9)
	bra		TFT_dive_tankdata_mask_helper_3 ; finish with adding "(bar)"
TFT_dive_tankdata_mask_helper_2:
	STRCPY_TEXT tNeed						; "Need"
TFT_dive_tankdata_mask_helper_3:
	STRCAT_PRINT "(bar)"
	return


	global	TFT_pressures_SAC				; data for pressures and SAC
TFT_pressures_SAC:
	; check mode for second reading
	bcf		aux_flag						; clear auxiliary flag by default (reading 2 is pressure)
	movff	char_I_pressure_gas+1,WREG		; =0: need to reading 1, =1..10: gases/dils
	addlw	.0								; dummy operation to set status register flags
	btfsc	STATUS,Z						; gas selected = 0 (i.e. no 2nd pressure reading) ?
	bsf		aux_flag						; YES - set auxiliary flag (display position of reading 2 shall show need to reading 1)
	; get data of reading 1
	movff	int_IO_pressure_value+0,lo		; copy pressure 1 to hi:lo
	movff	int_IO_pressure_value+1,hi
	movff	char_I_pressure_stat+0,ex		; copy status data
	; pressure of reading 1
	WIN_STD dm_custom_tankdata_pres1_col+.4,dm_custom_tankdata_row
	rcall	TFT_pressures_SAC_helper_1		; print pressure if available, else " ---"
	; battery status of reading 1
	WIN_SMALL dm_custom_hud_sensor1_column+.4+.36,dm_custom_tankdata_row
	rcall	TFT_pressures_SAC_helper_2		; print or clear down arrow as low bat indicator
	; get data for reading 2
	btfsc	aux_flag						; shall reading 2 show need to reading 1 ?
	bra		TFT_pressures_SAC_1				; YES
	movff	int_IO_pressure_value+2,lo		; NO  - copy pressure 2 to hi:lo
	movff	int_IO_pressure_value+3,hi
	movff	char_I_pressure_stat+1,ex		;     - copy status data
	bra		TFT_pressures_SAC_2
TFT_pressures_SAC_1:
	MOVII	int_O_pressure_need,mpr			; YES - copy need to pressure 1 to hi:lo
	clrf	ex								;     - set status data to 0
TFT_pressures_SAC_2:
	; pressure of reading 2
	WIN_STD dm_custom_tankdata_pres2_col+.2,dm_custom_tankdata_row
	rcall	TFT_pressures_SAC_helper_1		; print pressure if available, else " ---"
	; battery status of reading 2
	WIN_SMALL dm_custom_tankdata_pres2_col+.2+.36,dm_custom_tankdata_row
	rcall	TFT_pressures_SAC_helper_2		; print or clear down arrow as low bat indicator
	; SAC
	WIN_STD dm_custom_tankdata_SAC_col+.6,dm_custom_tankdata_row
	MOVII	int_O_SAC_measured,mpr			; copy measured SAC rate to hi:lo
	btfsc	hi,int_not_avail_flag			; SAC rate available?
	bra		TFT_pressures_SAC_4				; NO - print " --.-"
	call	TFT_color_code_tank_pres_sac	; color-code the output
	output_16_3								; print as xxx
	PUTC	" "								; print a dummy char to have the string termination at the correct place
	movff	buffer+.2,buffer+.3				; move the decimal digit one position to the right
	movlw	"."								; load coding of a decimal point
	movff	WREG,buffer+.2					; place it before decimal digit
	movlw	" "								; load coding of a space character
	movff	buffer+.1,up					; get the character in front of the decimal point
	cpfseq	up								; is it a space?
	bra		TFT_pressures_SAC_3				; NO  - continue
	movlw	"0"								; YES - load coding of a zero
	movff	WREG,buffer+.1					;     - place a zero in front of the decimal point
TFT_pressures_SAC_3:
	STRCAT_PRINT ""							; dump buffer to screen
	bra		TFT_custview_exit3				; and return...
TFT_pressures_SAC_4:
	call	TFT_disabled_color
	STRCAT_PRINT "--.-"						; output for no SAC data available
	bra		TFT_custview_exit3				; and return...

TFT_pressures_SAC_helper_1:
	btfss	hi,int_not_avail_flag			; pressure available?
	bra		TFT_pressures_SAC_helper_1a		; YES - print pressure
	call	TFT_disabled_color				; NO  - use disabled color as default
;	btfsc	ex,char_transmitter_lost		;     - transmitter lost?
;	call	TFT_attention_color				;       YES - use attention color
	STRCAT_PRINT " ---"						;     - print " ---"
	return
TFT_pressures_SAC_helper_1a:
	btfsc	hi,int_warning_flag				; out of range (signaled by warning flag)?
	bra		TFT_pressures_SAC_helper_1c		; YES - special treatment
	call	TFT_color_code_tank_pres_sac	; NO  - color-code the output
	bsf		ignore_digit5					;     - no 0.1 bar (flag will be cleared by output_16)
	movf	lo,W							;
	iorwf	hi,W							;     - pressure value = 0 ?
	bnz		TFT_pressures_SAC_helper_1b		;       NO  - print value
	STRCPY_PRINT "   0"						;       YES - print a zero manually
	return									;           - done
TFT_pressures_SAC_helper_1b:
	output_16								; print hi:lo
	STRCAT_PRINT ""							; dump buffer to screen
	return									; done
TFT_pressures_SAC_helper_1c:
	call	TFT_color_code_tank_pres_sac	; color-code the output (clears all flags)
	STRCPY_PRINT ">400"						; print ">400"
	return									; done

TFT_pressures_SAC_helper_2:
	btfss	ex,char_transmitter_low_bat		; low battery flag set?
	bra		TFT_pressures_SAC_helper_2a		; NO  - wipe out down arrow (low bat indicator)
	call	TFT_attention_color				; YES - use attention color
	STRCPY_PRINT "\xb8"						;     - print down arrow as bat low indication
	return
TFT_pressures_SAC_helper_2a:
	STRCPY_PRINT " "						; wipe out down arrow (low bat indicator)
	return


	global	TFT_menu_tank_pres
TFT_menu_tank_pres:							; imprinting function for main menu / tank setup
	call	TFT_standard_color
	; get ID
	lfsr	FSR1,opt_transmitter_id_1		; load base address of opt_transmitter_id
	movf	gaslist_gas,W					; get current gas
	rlncf	WREG,W							; multiply by 2 because IDs are 2 byte in size
	movff	PLUSW1,lo						; copy opt_transmitter_id+0[gaslist_gas] to lo
	incf	WREG,W							; increment index
	movff	PLUSW1,hi						; copy opt_transmitter_id+1[gaslist_gas] to hi
	; show pressure
	WIN_SMALL .90, .61						; column, row (+/- 27 per row)
	call	get_pres_by_transmitter_id		; get pressure into hi:lo
	tstfsz	WREG							; do we have valid tank data (WREG=0) ?
	bra		TFT_menu_tank_pres_1			; NO - transmitter not found
	call	TFT_color_code_tank_pres_sac	; set output color according to flags
	bsf		ignore_digit5					; no 0.1 bar (flag will be cleared by output_16)
	output_16
	bra		TFT_menu_tank_pres_2
TFT_menu_tank_pres_1:
	call	TFT_disabled_color
	STRCAT	" ---"							; output for no pressure data available
TFT_menu_tank_pres_2:
	STRCAT_TEXT_PRINT tbar					; " bar"
	bra		TFT_custview_exit3				; and return...


	global	TFT_surface_tank_pres
TFT_surface_tank_pres:						; show pressure reading above surface pressure
	WIN_SMALL surf_decotype_column+.6,surf_decotype_row+.30+.47
	movff	int_IO_pressure_value+0,lo		; copy pressure from 1st reading to hi:lo
	movff	int_IO_pressure_value+1,hi
	btfss	hi,int_not_avail_flag			; pressure reading 1 available?
	bra		TFT_surface_tank_pres_0			; YES
	movff	int_IO_pressure_value+2,lo		; NO - copy pressure from 2nd reading to hi:lo
	movff	int_IO_pressure_value+3,hi
	btfsc	hi,int_not_avail_flag			;    - pressure reading 2 available?
	bra		TFT_surface_tank_pres_1			;      NO  - show not avail message
TFT_surface_tank_pres_0:					;      YES - show pressure
	call	TFT_color_code_tank_pres_sac	; set output color according to flags
	bsf		ignore_digit5					; no 0.1 bar (flag will be cleared by output_16)
	output_16
	STRCAT_PRINT ""
	bra		TFT_surface_tank_pres_2
TFT_surface_tank_pres_1:
	call	TFT_disabled_color
	STRCAT_PRINT " ---"						; output for no pressure data available
TFT_surface_tank_pres_2:
	WIN_SMALL surf_decotype_column+.38,surf_decotype_row+.30+.47
	call	TFT_divemask_color
	STRCAT_PRINT "bar"						; can not use tbar because it has a leading space
	bra		TFT_custview_exit3				; and return...


	global	TFT_surface_tankdata
TFT_surface_tankdata:
	lfsr	FSR1,rx_buffer					; load base address of RX buffer
;	bra		TFT_surface_tankdata_debug		; comment in for +++ debug version +++
	WIN_SMALL surf_customtext_column,surf_customtext_row1
	rcall	TFT_surface_tankdata_print
	WIN_SMALL surf_customtext_column,surf_customtext_row2
	rcall	TFT_surface_tankdata_print
	WIN_SMALL surf_customtext_column,surf_customtext_row3
	rcall	TFT_surface_tankdata_print
	WIN_SMALL surf_customtext_column,surf_customtext_row4
	rcall	TFT_surface_tankdata_print
	WIN_SMALL surf_customtext_column,surf_customtext_row5
	rcall	TFT_surface_tankdata_print
	return

TFT_surface_tankdata_print:					; max 12 char
	call	TFT_standard_color				; set color
	movff	POSTINC1,hi						; ID high (+0)
	movff	POSTINC1,lo						; ID low  (+1)
	tstfsz	hi								; ID high = 0 ?
	bra		TFT_surface_tankdata_print_1	; NO  - slot in use
	tstfsz	lo								; ID low  = 0?
	bra		TFT_surface_tankdata_print_1	; NO  - slot in use
	STRCAT_PRINT "----        "				; YES - mark as unused and clear rest of line from previous remains
	movf	POSTINC1,W						;     - dummy read (+2) to advance index
	movf	POSTINC1,W						;     - dummy read (+3) to advance index
	movf	POSTINC1,W						;     - dummy read (+4) to advance index
	bra		TFT_surface_tankdata_print_3
TFT_surface_tankdata_print_1:
	movf	hi,W							; copy ID high to WREG
	output_hex								;                     2 chars
	movf	lo,W							; copy ID low  to WREG
	output_hex								;                     2 chars (4 in total)
	movff	POSTINC1,hi						; pressure high (+2)
	movff	POSTINC1,lo						; pressure low  (+3)
	call	TFT_color_code_tank_pres_sac	; needed to clear the status flags before output
	bsf		ignore_digit5					; no 0.1 bar (flag will be cleared by output_16)
	output_16								;                     4 chars (8 in total)
	PUTC	" "								;                     1 char  (9 in total)
	movf	POSTINC1,W						; status (+4)
	andlw	.7								; mask out battery voltage
	bnz		TFT_surface_tankdata_2			; branch if battery is not completely drained
	call	TFT_warning_color				; output in red
	STRCAT_PRINT "XXX"						; "XXX" for low
	bra		TFT_surface_tankdata_print_3
TFT_surface_tankdata_2:
	addlw	.28								; add offset of 2.8 Volt
	movff	WREG,lo							;
	output_99								;                     2 chars (11 in total)
	PUTC	" "								; dummy char          1 char  (12 in total)
	movff	buffer+.10,buffer+.11			; move decimal digit of battery voltage one position to the right
	movlw	"."								; decimal point
	movff	WREG,buffer+.10					; place it before decimal digit
	STRCAT_PRINT ""							; print buffer to screen
TFT_surface_tankdata_print_3:
	movf	POSTINC1,W						; dummy read (+5) to advance index
	return


; TFT_surface_tankdata_debug:					; surface custom view debug output
	; call	TFT_standard_color
	; WIN_TINY surf_customtext_column,surf_customtext_row1+.14*0
	; rcall	TFT_surface_tankdata_debug_print
	; WIN_TINY surf_customtext_column,surf_customtext_row1+.14*1
	; rcall	TFT_surface_tankdata_debug_print
	; WIN_TINY surf_customtext_column,surf_customtext_row1+.14*2
	; rcall	TFT_surface_tankdata_debug_print
	; WIN_TINY surf_customtext_column,surf_customtext_row1+.14*3
	; rcall	TFT_surface_tankdata_debug_print
	; WIN_TINY surf_customtext_column,surf_customtext_row1+.14*4
	; rcall	TFT_surface_tankdata_debug_print
	; WIN_TINY surf_customtext_column,surf_customtext_row1+.14*5
	; rcall	TFT_surface_tankdata_debug_print
	; WIN_TINY surf_customtext_column,surf_customtext_row1+.14*6
	; rcall	TFT_surface_tankdata_debug_print
	; WIN_TINY surf_customtext_column,surf_customtext_row1+.14*7
	; rcall	TFT_surface_tankdata_debug_print
	; return

; TFT_surface_tankdata_debug_print:
	; movff	POSTINC1,hi					; ID high (+0)
	; movff	POSTINC1,lo					; ID low  (+1)
	; output_16
	; PUTC	","
	; movff	POSTINC1,hi					; pressure high (+2)
	; movff	POSTINC1,lo					; pressure low  (+3)
	; call	TFT_color_code_tank_pres_sac; needed to clear the status flags before output
	; output_16
	; PUTC	","
	; movff	POSTINC1,lo					; status (+4)
	; output_8
	; PUTC	","
	; movff	POSTINC1,lo					; date (+5)
	; output_8
	; STRCAT_PRINT ""
	; return

 ENDIF	; _rx_functions

;=============================================================================

	global	convert_pres_to_depth
convert_pres_to_depth:				; converts pressure in [mbar] to depth in [cm]
	btfsc	sensor_override_active	; in pressure sensor override (simulator) mode?
	return							; YES - convert with factor 1.0, i.e. make [mbar] = [cm]

	movff	opt_salinity,WREG		; get salinity setting (0 - 4 %, see option_table.asm)
	addlw	d'100'					; add density of fresh water (1.00 kg/l)
	movwf	up						; store salinity factor in up

	movlw	.101+salinity_max		; load (upper limit + 1)
	cpfslt	up						; current setting > upper limit?
	bra		convert_fix_salinity	; YES - fix salinity setting

	movlw	.99+salinity_min		; load (lower limit - 1)
	cpfsgt	up						; current setting > lower limit?
	bra		convert_fix_salinity	; YES - fix salinity setting

convert_pres_to_depth_1:
	MOVII	mpr, xA					; get pressure in [mbar]
	MOVLI	.102,xB					; conversion factor x 100 for fresh water (1.02 cm per each 1 mbar)
	call	mult16x16				; xC:4 = xA:2 * xB:2
	movff	up,xB+0					; get salinity in [%]
	clrf	xB+1					; ...
	call	div32x16				; xC:4 = xC:4 / xB:2 with xA as remainder
	MOVII	xC,mpr					; copy back result as depth in [cm]
	return

convert_fix_salinity:
	movlw	.100					; reset to 100%, i.e. set salinity to 0%
	movwf	up						; fix value in up
	bra		convert_pres_to_depth_1	; continue

;=============================================================================

	global	convert_cm_to_feet
convert_cm_to_feet:					; converts depth in [cm] to depth in [feet]
	MOVII	mpr, xA					; depth in [cm]
	btfsc	sensor_override_active	; in pressure sensor override (simulator) mode?
	bra		convert_meter_to_feet_1	; YES - convert with 334feet/100m
	MOVLI	.328,xB					; NO  - convert with 328feet/100m
	bra		convert_common_to_feet	;     - continue with common part


	global	convert_meter_to_feet
convert_meter_to_feet:				; converts depth in [m] to depth in [feet]
	movf	lo,W					; depth in [m]
	mullw	.100					; factor to convert [m] to [cm]
	MOVII	PRODL,xA				; copy depth in [cm] to xA
convert_meter_to_feet_1:
	MOVLI	.334, xB				; convert with 334feet/100m to have 10ft, 20ft, 30ft, ... for stop depths
	;bra	convert_common_to_feet	; continue with common part


convert_common_to_feet:
	call	mult16x16				; xC = xA * xB = depth in [cm] * 334 feet/100 m = depth in 0.0001 feet
	MOVLI	.10000,xB				; divide by 10000 to turn into full feet
	call	div32x16				; xC = xC / xB with xA as remainder
	MOVII	xC,mpr					; store result

	return

;=============================================================================	

	global	convert_celsius_to_fahrenheit	; convert value in hi:lo from Celsius to Fahrenheit
convert_celsius_to_fahrenheit:		; convert value in lo:hi from Celsius to Fahrenheit
	MOVII	mpr,xA					; temperature in 1/10 of °C
	ADDLI	.1000,xA				; add offset of 1000 to get out of any negative numbers
									; adjust scaling: 1°C = 1.8°F:
	MOVLI	.18,xB					; multiply with 18:
	call	mult16x16				; ...
	MOVLI	.10,xB					; divide by 10
	call	div32x16				; ...
	SUBLI	.1480,xC				; remove offset: subtract above offset of 1000 * 1.8 = 1800 now and add 320 => subtract 1480
	MOVII	xC,mpr					; store result in hi:lo
	return

;=============================================================================

	END