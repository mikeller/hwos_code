;=============================================================================
;
;   File tft_outputs.asm							REFACTORED VERSION V2.99e
;
;   Startup subroutines
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;  2011-08-07 : [mH] moving from OSTC code

#include "hwos.inc"							; mandatory header
#include "shared_definitions.h"				; mailbox from/to p2_deco.c
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
#include "gaslist.inc"

 IFDEF _rx_functions
#include "rx_ops.inc"
 ENDIF

	extern	aa_wordprocessor
	extern	get_first_gas_to_WREG
	extern	get_first_dil_to_WREG

	extern	tFirmware
	extern	tSerial
	extern	tTotalDives
	extern	tBatteryV
	extern	tUptime
	extern	tCalX,tCalY,tCalZ
	extern	tPPO2MIN
	extern	tPPO2MINCC
	extern	tPPO2Max
	extern	tPPO2DECO

 IFDEF _rx_functions
	extern	tFirmware_rx
 ENDIF

;=============================================================================

tft_out		CODE

;=============================================================================

	global	TFT_divemask_color
TFT_divemask_color:
	movlw	color_green
	btfsc	divemode					; in divemode?
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

	global	TFT_warnings_color			; important things with immediate need to react upon
TFT_warnings_color:
	movlw	color_red
	bra		TFT_standard_color0
TFT_warnings_color_dive:
	retlw	color_red


	global	TFT_disabled_color
TFT_disabled_color:
	movlw	color_lightblue
	btfsc	divemode					; in divemode?
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
	btfsc	divemode					; in divemode?
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
	bra		TFT_warnings_color			;     - set to warning color and return
TFT_color_code_tank_pres_3:
	btfss	hi,int_attention_flag		; is the attention flag set?
	bra		TFT_memo_color				; NO  - set to memo color and return
	bcf		hi,int_attention_flag		; YES - clear attention flag
	bra		TFT_attention_color			;     - set to attention color and return


	global	TFT_color_code_gaslist
TFT_color_code_gaslist:					; color-code current row in gaslist (%O2 in hi) according to current amb_pressure
; Check very high ppO2 manually
	movff	amb_press_10+0,xA+0
	movff	amb_press_10+1,xA+1
	movff	hi,xB+0
	clrf	xB+1
	call	mult16x16					; hi * p_amb/10
; Check if ppO2 > 6.55 bar
	tstfsz	xC+2						; char_I_O2_ratio * p_amb/10 > 65536, ppO2 > 6.55 bar ?
	bra		TFT_warnings_color			; YES - warn in warning color
; Check if ppO2 > 3.30 bar
	btfsc	xC+1,7
	bra		TFT_warnings_color			; YES - warn in warning color
; Check for low ppO2
	movff	xC+0,sub_a+0
	movff	xC+1,sub_a+1
	movff	char_I_ppO2_min,WREG
	mullw	d'100'						; char_I_ppO2_min*100
	movff	PRODL,sub_b+0
	movff	PRODH,sub_b+1
	call	subU16
	btfsc	neg_flag					; lower than ppO2 min?
	bra		TFT_warnings_color			; YES - set warning color and return
; Check for high ppO2
	movff	char_O_deco_info,WREG		; bank-safe copy of deco info vector
	btfsc	WREG,deco_flag				; are we in deco?
	bra		TFT_color_code_gaslist_deco	; YES - check against ppO2 max deco only
										; NO  - check against ppO2 max travel/normal and deco
; Check for ppO2 max travel/normal
	movff	char_I_ppO2_max,WREG		; ppo2 max for travel/normal
	mullw	d'100'						; char_I_ppO2_max*100
	movff	PRODL,sub_b+0
	movff	PRODH,sub_b+1
	infsnz	sub_b+0,F					; add 1 mbar to avoid warning on equal
	incf	sub_b+1,F
	call	subU16						; sub_c = sub_a - sub_b
	btfss	neg_flag					; higher than ppO2 max travel/deco?
	rcall	TFT_attention_color			; YES - set attention color
; Check for ppO2 max deco
TFT_color_code_gaslist_deco:
	movff	char_I_ppO2_max_deco,WREG	; ppo2 max for deco
	mullw	d'100'						; char_I_ppO2_max_deco*100
	movff	PRODL,sub_b+0
	movff	PRODH,sub_b+1
	infsnz	sub_b+0,F					; add 1 mbar to avoid warning on equal
	incf	sub_b+1,F
	call	subU16						; sub_c = sub_a - sub_b
	btfss	neg_flag					; higher than ppO2 max deco?
	bra		TFT_warnings_color			; YES - set warning color and return
	return								; NO  - keep current color


TFT_color_code_ceiling:					; color-code the ceiling depth
	btfsc	hi,char_invalid_flag		; is the invalid flag set? (bit 7 here)
	bra		TFT_color_code_ceiling_1	; YES
	SAFE_2BYTE_COPY rel_pressure,sub_a	; NO
	movff	lo,sub_b+0
	movff	hi,sub_b+1
	call	subU16						; sub_c = sub_a - sub_b :  sub_c = rel_pressure [mbar] - int_O_ceiling [mbar]
	btfsc	neg_flag					; is ceiling > current depth?
	bra		TFT_warnings_color			; YES - set to warning color and return
	bra		TFT_memo_color				; NO  - set to memo    color and return
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
	movff	char_O_first_deco_depth,WREG; NO  - get stop depth in m into WREG
	subwf	curr_depth,W				;     - compute current depth - stop depth
	btfsc	STATUS,C					;     - result negative?
	bra		TFT_memo_color				;       NO  - set to memo color and return
	movff	int_O_ceiling+0,sub_b+0		;       YES - get ceiling depth in mbar
	movff	int_O_ceiling+1,sub_b+1		;           - ...
	btfsc	sub_b+1,char_invalid_flag	;           - is the invalid flag set? (bit 7 here)
	bra		TFT_warnings_color			;             YES - set to warning color and return
	SAFE_2BYTE_COPY rel_pressure,sub_a	;             NO  - get current depth in mbar
	call	subU16						;                 - sub_c = sub_a - sub_b :  sub_c = rel_pressure [cm] - int_O_ceiling [mbar => cm]
	btfsc	neg_flag					;                 - is ceiling > current depth?
	bra		TFT_warnings_color			;                   YES - set to warning   color and return
	bra		TFT_attention_color			;                   NO  - set to attention color and return


TFT_color_code_depth:					; with actual depth as rel_pressure in [mbar] in hi:lo and threshold depth_warn_mbar [mbar]
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
	bra		TFT_warnings_color			; set to warning color and return
	bra		TFT_memo_color				; set to memo    color and return...
TFT_color_code_depth_ppO2:
	movff	opt_dive_mode,WREG			; 0=OC, 1=CC, 2=Gauge, 3=Apnea, 4=PSCR
	decfsz	WREG,F						; are we in CCR mode?
	bra		TFT_color_code_depth_no_ccr	; NO  - continue checking for ppO2
	btfss	FLAG_bailout_mode			; YES - check if in bailout
	bra		TFT_color_code_depth_outside;       NO  - continue checking for outside ZHL16 model
TFT_color_code_depth_no_ccr:
	movff	int_O_breathed_ppO2+1,WREG	; get upper byte of currently breathed ppO2
	btfsc	WREG,int_warning_flag		; is the warning flag set?
	bra		TFT_color_code_depth_warn	; YES - animate in warning design
TFT_color_code_depth_outside:
	movff	char_O_deco_warnings,WREG	; bank-safe copy of deco warnings
	btfsc	WREG,outside_warning		; are we currently outside of the ZH-L16 model?
	bra		TFT_color_code_depth_warn	; YES
	btfsc	WREG,outside_attention		; are we near to outside of the ZH-L16 model?
	bra		TFT_color_code_depth_att	; YES
	bcf		blinking_depth_warning		; NO  - terminate warning   blinking
	bcf		blinking_depth_attention	;     - terminate attention blinking
	bra		TFT_memo_color				;     - set memo  color and return
TFT_color_code_depth_warn:
	bsf		blinking_depth_warning		; activate warning blinking
	bra		TFT_warnings_color			; set to warning color and return...
TFT_color_code_depth_att:
	bsf		blinking_depth_attention	; activate attention blinking
	bra		TFT_attention_color			; set to attention color and return...


	global	TFT_color_code_cns
TFT_color_code_cns:						; color-code CNS values (CNS in hi:lo [%])
	btfss	hi,int_invalid_flag			; is the invalid flag set?
	bra		TFT_color_code_cns_1		; NO
	bcf		hi,int_invalid_flag			; YES - clear invalid flag
	bcf		hi,int_warning_flag			;       clear warning   flag (it may be set)
	bcf		hi,int_attention_flag		;       clear attention flag (it may be set)
	bra		TFT_disabled_color			;       set to disabled color and return
TFT_color_code_cns_1
	btfss	hi,int_warning_flag			; is the warning flag set?
	bra		TFT_color_code_cns_2		; NO
	bcf		hi,int_warning_flag			; YES - clear warning   flag
	bcf		hi,int_attention_flag		;     - clear attention flag (it may be set)
	bra		TFT_warnings_color			;     - set to warning color and return
TFT_color_code_cns_2:
	btfss	hi,int_attention_flag		; is the attention flag set?
	bra		TFT_memo_color				; NO  - set to memo color and return
	bcf		hi,int_attention_flag		; YES - clear attention flag
	bra		TFT_attention_color			;     - set to attention color and return


TFT_color_code_gf:
	; with int_O_gradient_factor, the upper byte is solely used for the flags
	; and not for the value, thus there is no need to clear the flags
	btfsc	hi,int_invalid_flag			; is the invalid flag set?
	bra		TFT_disabled_color			; YES - set to disabled color and return
	btfsc	hi,int_warning_flag			; NO  - is the warning flag set?
	bra		TFT_warnings_color			;       YES - set to warning color and return
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
	bra		TFT_memo_color				; set to memo color and return


TFT_color_code_ppo2_hud:				; color-code ppO2 values (ppO2 in --:lo [cbar]) by its value
	movff	char_O_deco_info,WREG		; get the deco info vector
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
	btfsc	FLAG_bailout_mode
	bra		TFT_color_code_ppo2_hud_nocc; is bailout, hence not loop mode...
	movff	char_I_ppO2_min_loop,WREG	; ppO2 min loop mode color coding
	bra		TFT_color_code_ppo2_hud_cont
TFT_color_code_ppo2_hud_nocc:
	movff	char_I_ppO2_min,WREG		; PPO2 min for all other modes
TFT_color_code_ppo2_hud_cont:
	cpfslt	lo							; lo < char_I_ppO2_min?
	bra		TFT_memo_color				; NO  - set memo    color and return...
	bra		TFT_warnings_color			; Yes - set warning color and return


TFT_color_code_battery:					; color-code the battery display, with battery percent in lo
	movlw	color_code_battery_low		; get warning threshold
	cpfsgt	lo							; is battery percent < threshold?
	bra		TFT_warnings_color			; YES - set to warning color and return
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
	call	TFT_memo_color
	WIN_MEDIUM .3,.54
	movlw	LOW  .5172
	movwf	lo
	movlw	HIGH .5172
	movwf	hi
	bsf		leftbind
	bsf		ignore_digit4
	output_16							; full meters in big font
	bcf		leftbind
	STRCAT_PRINT ""						; display full meters
	WIN_SMALL .25,.66
	movlw	LOW  .5172
	movwf	lo
	movlw	HIGH .5172
	movwf	hi
	PUTC	"."
	movlw	d'4'
	movwf	ignore_digits
	bsf		ignore_digit5				; (flag will be cleared by output_16)
	output_16dp	d'0'					; .1m in SMALL font
	STRCAT_PRINT ""						; display decimeters
	WIN_FONT FT_SMALL

	; Max. Depth demo
	WIN_MEDIUM .64,.54
	bsf		ignore_digit4				; no 0.1m
	bsf		leftbind
	movlw	LOW  .6349
	movwf	lo
	movlw	HIGH .6349
	movwf	hi
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
	movlw	LOW  .6349
	movwf	lo
	movlw	HIGH .6349
	movwf	hi
	output_16dp	d'0'
	STRCAT_PRINT ""						; display decimeters
	bcf		leftbind

	; Divetime demo
	movff	mins,lo
	clrf	hi
	WIN_MEDIUM .103, .54
	output_16_3							; limit to 999 and display only (0-999)
	STRCAT_PRINT ""						; show minutes in large font
	WIN_SMALL .139, .66					; left position for two sec figures
	PUTC	':'
	bsf		leftbind
	movff	secs,lo
	output_99x
	bcf		leftbind
	STRCAT_PRINT ""						; show seconds in small font

	bcf		divemode					; don't stay in divemode
	return


	global	TFT_divemode_mask
TFT_divemode_mask:						; displays mask in divemode
	bcf		FLAG_TFT_divemode_mask
	call	TFT_divemask_color
	WIN_TINY dm_mask_depth_column,dm_mask_depth_row
	STRCAT_TEXT_PRINT tDepth
	WIN_TINY dm_mask_maxdepth_column_nvsi,dm_mask_maxdepth_row
	TSTOSS	opt_vsigraph				; graphical VSI bar enabled?
	bra		TFT_divemode_mask_1			; NO
	WIN_TINY dm_mask_maxdepth_column,dm_mask_maxdepth_row ; YES - adopt position
TFT_divemode_mask_1:
	btfsc	FLAG_apnoe_mode				; in Apnea mode?
	bra		TFT_divemode_mask_2			; YES - draw max depth
	TSTOSS	opt_2ndDepthDisp			; draw avg depth?
	bra		TFT_divemode_mask_2			; NO  - draw max depth
	STRCAT_TEXT_PRINT tAvgDepth			; YES
	bra		TFT_divemode_mask_3
TFT_divemode_mask_2:
	STRCAT_TEXT_PRINT tMaxDepth
TFT_divemode_mask_3:
	WIN_TINY dm_mask_divetime_column,dm_mask_divetime_row
	STRCAT_TEXT_PRINT tDivetime
	bra		TFT_standard_color			; and return...

	global	TFT_divemode_mask_alternative
TFT_divemode_mask_alternative:			; alt. mask for divemode
	bcf		FLAG_TFT_divemode_mask_alt
	call	TFT_divemask_color
	WIN_TINY dm_mask_depth_column,dm_mask_depth_row
	STRCAT_TEXT_PRINT tDepth
	WIN_TINY dm_mask_divetime_column-.30,dm_mask_divetime_row
	STRCAT_TEXT_PRINT tDivetime
	bra		TFT_standard_color			; and return...

	global	TFT_draw_gassep_line
TFT_draw_gassep_line:
	btfsc	FLAG_apnoe_mode				; ignore in Apnoe mode
	return
	btfsc	divemode_menu				; is the dive mode menu shown?
	return								; YES - return
	bra		TFT_standard_color			; NO  - set standard color and return

;=========================================================================

	global	TFT_display_velocity
TFT_display_velocity:					; with divA+0 = m/min, neg_flag_velocity: ascend=1, descend=0
	bcf		STATUS,C
	movlw	velocity_display_threshold_1; lowest threshold for display vertical velocity
	subwf	divA+0,W
	btfss	STATUS,C
	bra		TFT_velocity_clear			; lower then threshold. Clear text and graph (If active)

	; We have something to display
	bsf		display_velocity			; set flag
	; check if descending: no warning color if descending
	rcall	TFT_memo_color
	btfsc	neg_flag_velocity			; ignore for descent
	rcall	TFT_velocity_set_color		; set color for text and set threshold for graph

	rcall	TFT_velocity_disp			; show the text

	TSTOSS	opt_vsigraph				; graphical VSI bar enabled?
	bra		TFT_display_velocity_done	; NO

	btfsc	alternative_divelayout		; alternative layout?
	bra		TFT_display_velocity_done	; YES - no graph! (no room when divetime minutes is three digits)

	btfsc	neg_flag_velocity			; ignore for descent
	rcall	TFT_velocity_graph			; show the graph
	btfss	neg_flag_velocity			; ignore for descent
	rcall	TFT_velocity_clear_graph	; clear the graph for descent

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
	TBLRD*+									; get speed threshold
	movf	curr_depth,W					; current depth in m
	cpfsgt	TABLAT							; threshold > current depth ?
	bra		TFT_velocity_set_color_skip		; NO - loop

	TBLRD*+									; get warning speed threshold
	movf	TABLAT,W
	movwf	divA+1							; copy for graph routine
	cpfslt	divA+0							; smaller then actual value (in m/min)?
	bra		TFT_warnings_color					; set Warning color (And return)
	TBLRD*+									; get attention speed threshold
	movf	TABLAT,W
	cpfslt	divA+0							; smaller then actual value (in m/min)?
	bra		TFT_attention_color				; NO  - set attention color and return
	bra		TFT_memo_color					; YES - set memo      color and return

TFT_velocity_set_color_static:
	movlw	color_code_velocity_warn_high	; in m/min
	movwf	divA+1							; copy for graph routine
	cpfslt	divA+0							; smaller then actual value (in m/min)?
	bra		TFT_warnings_color				; set Warning color (And return)
	movlw	color_code_velocity_attn_high	; in m/min
	cpfslt	divA+0							; smaller then actual value (in m/min)?
	bra		TFT_attention_color				; NO  - set attention color and return
	bra		TFT_memo_color					; YES - set memo      color and return

TFT_velocity_disp:
	WIN_SMALL dm_velocity_text_column, dm_velocity_text_row
	TSTOSS	opt_units						; 0=Meters, 1=Feets
	bra		TFT_velocity_metric
;TFT_velocity_imperial:
	movff	divA+0,WREG						; divA+0 = m/min
	mullw	.100							; PRODL:PRODH = mbar/min
	movff	PRODL,lo
	movff	PRODH,hi
	call	convert_mbar_to_feet			; convert value in hi:lo from mbar to feet
	movlw	'-'
	btfsc	neg_flag_velocity
	movlw	'+'
	movwf	POSTINC2
	bsf		leftbind
	output_16
	bcf		leftbind
	STRCAT_TEXT_PRINT tVelImperial			; unit switch
	return

TFT_velocity_metric:
	movff	divA+0,lo						; divA+0 = m/min
	movlw	'-'
	btfsc	neg_flag_velocity
	movlw	'+'
	movwf	POSTINC2
	output_99
	STRCAT_TEXT_PRINT tVelMetric			; unit switch
	return

TFT_velocity_graph:							; divA+0 = m/min
	; divA+0 holding the ascend speed in m/min
	movff	divA+0,hi						; copy
	WIN_BOX_BLACK	dm_velobar_top, dm_velobar_bot, dm_velobar_lft, dm_velobar_rgt ;top, bottom, left, right -> outer frame
	rcall	TFT_divemask_color_dive			; color -> WREG
	WIN_FRAME_COLOR	dm_velobar_top, dm_velobar_bot, dm_velobar_lft, dm_velobar_rgt ;inner frame
	rcall	TFT_divemask_color_dive			; color -> WREG
	WIN_FRAME_COLOR	dm_velobar_top+.10, dm_velobar_bot-.10, dm_velobar_lft, dm_velobar_rgt ;inner frame
	rcall	TFT_divemask_color_dive			; color -> WREG
	WIN_FRAME_COLOR	dm_velobar_top+.20, dm_velobar_bot-.20, dm_velobar_lft, dm_velobar_rgt ;inner frame
	rcall	TFT_divemask_color_dive			; color -> WREG
	WIN_FRAME_COLOR	dm_velobar_top+.30, dm_velobar_bot-.30, dm_velobar_lft, dm_velobar_rgt ;inner frame
	
	movff	divA+1,xA+0						; m/min for warning level (upper two blocks)
	clrf	xA+1
	movlw	.5
	movwf	xB+0							; threshold for color warning (5 color normal + 2 color warning)
	clrf	xB+1
	call	div16x16						; xC = xA / xB with xA as remainder
	; xC+0 holds step size in m/min (e.g. =3 for 15m/min warning threshold)
	movff	hi,xA+0							; velocity in m/min
	clrf	xA+1
	movff	xC+0,xB+0						; step size
	clrf	xB+1
	call	div16x16						; xC = xA / xB with xA as remainder
											; xC+0 now holds amount of segments to show
	movff	hi,divA+0						; copy back for numeric output
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
	bra		DISP_graph_vel_0			; should not happen...

DISP_graph_vel_7:
	rcall	TFT_warnings_color_dive		; color -> WREG
	WIN_BOX_COLOR dm_velobar_top+.2, dm_velobar_top+.8, dm_velobar_lft+.2, dm_velobar_rgt-.2 ;top, bottom, left, right
DISP_graph_vel_6:
	rcall	TFT_warnings_color_dive		; color -> WREG
	WIN_BOX_COLOR dm_velobar_top+.12, dm_velobar_top+.18, dm_velobar_lft+.2, dm_velobar_rgt-.2 ;top, bottom, left, right
DISP_graph_vel_5:
	rcall	TFT_attention_color_dive	; color -> WREG
	WIN_BOX_COLOR dm_velobar_top+.22, dm_velobar_top+.28, dm_velobar_lft+.2, dm_velobar_rgt-.2 ;top, bottom, left, right
DISP_graph_vel_4:
	rcall	TFT_standard_color_dive		; color -> WREG
	WIN_BOX_COLOR dm_velobar_top+.32, dm_velobar_top+.38, dm_velobar_lft+.2, dm_velobar_rgt-.2 ;top, bottom, left, right
DISP_graph_vel_3:
	rcall	TFT_standard_color_dive		; color -> WREG
	WIN_BOX_COLOR dm_velobar_top+.42, dm_velobar_top+.48, dm_velobar_lft+.2, dm_velobar_rgt-.2 ;top, bottom, left, right
DISP_graph_vel_2:
	rcall	TFT_standard_color_dive		; color -> WREG
	WIN_BOX_COLOR dm_velobar_top+.52, dm_velobar_top+.58, dm_velobar_lft+.2, dm_velobar_rgt-.2 ;top, bottom, left, right
DISP_graph_vel_1:
	rcall	TFT_standard_color_dive		; color -> WREG
	WIN_BOX_COLOR dm_velobar_top+.62, dm_velobar_top+.68, dm_velobar_lft+.2, dm_velobar_rgt-.2 ;top, bottom, left, right
DISP_graph_vel_0:
	return								; done


	global	TFT_velocity_clear
TFT_velocity_clear:
	btfss	display_velocity			; velocity was not displayed, do not delete
	return
	bcf		display_velocity			; velocity was displayed, delete velocity now
	; Clear Text
	WIN_BOX_BLACK	dm_velocity_text_row, dm_velocity_text_bot, dm_velocity_text_column, dm_velocity_text_rgt ; top, bottom, left, right

	TSTOSS	opt_vsigraph				; graphical VSI bar enabled?
	return								; NO - no graph to clear
TFT_velocity_clear_graph:
	; Clear Graph
	WIN_BOX_BLACK dm_velobar_top, dm_velobar_bot, dm_velobar_lft, dm_velobar_rgt		; top, bottom, left, right
	return

;=========================================================================

	global	TFT_clear_decoarea
TFT_clear_decoarea:
	WIN_BOX_BLACK	dm_decostop_1st_stop_row, .239, dm_decostop_1st_stop_column, .159	; top, bottom, left, right
	return


	global	TFT_clear_divemode_menu
TFT_clear_divemode_menu:
	WIN_BOX_BLACK	dm_menu_row-.2, dm_menu_lower, dm_menu_left, dm_menu_right			; top, bottom, left, right - starts 2 pixel higher to completely wipe away the temperature display
	return


	global	TFT_display_ndl_mask
TFT_display_ndl_mask:
	bcf		FLAG_TFT_display_ndl_mask
	btfsc	divemode_menu				; is the dive mode menu shown?
	return								; YES - return
	btfsc	FLAG_gauge_mode				; in gauge mode?
	return								; YES - return
	call	TFT_clear_decoarea			; NO  - clear stop depth and TTS
	call	TFT_divemask_color
	WIN_STD dm_ndl_text_column, dm_ndl_text_row
	STRCPY_TEXT_PRINT tNDL				; NDL
	bra		TFT_standard_color			; and return...


	global	TFT_display_tts
TFT_display_tts:
	bcf		FLAG_TFT_display_tts
	btfsc	divemode_menu				; is the dive mode menu shown?
	return								; YES - return
	call	TFT_memo_color				; NO  - set memo color
	movff	int_O_ascenttime+0,lo		;     - TTS
	movff	int_O_ascenttime+1,hi		;     - on 16 bits
	btfss	hi,int_invalid_flag			;     - is the invalid flag set?
	bra		TFT_display_tts_1			;     - NO
	bcf		hi,int_invalid_flag			;     - YES - clear flag
	call	TFT_disabled_color			;           - switch to disabled color
TFT_display_tts_1:
	WIN_MEDIUM dm_tts_value_column, dm_tts_value_row
	output_16_3							; display only 0...999
	STRCAT_PRINT "'"
	return


	global	TFT_display_ndl
TFT_display_ndl:
	bcf		FLAG_TFT_display_ndl
	btfsc	divemode_menu				; is the dive mode menu shown?
	return								; YES - return
	WIN_MEDIUM	dm_ndl_value_column, dm_ndl_value_row
	call	TFT_memo_color
	movff	char_O_nullzeit,lo			; get NDL from C-code
	output_8
	STRCAT_PRINT "'"
	return


	global	TFT_big_deco_alt			; the big deco
TFT_big_deco_alt:
	bcf		FLAG_TFT_big_deco_alt

	btfss	decostop_active				; deco stop shown?
	bra		TFT_big_deco_ndl_alt		; NO - show NDL

	; Deco
	bcf		FLAG_TFT_display_deko
	call	TFT_divemask_color
	WIN_STD .70,.165
	STRCPY_TEXT_PRINT tTTS				; TTS
	rcall	TFT_memo_color

	; TTS
	WIN_LARGE	.97,.170
	movff	int_O_ascenttime+0,lo		; get the TTS
	movff	int_O_ascenttime+1,hi		;
	btfss	hi,int_invalid_flag			; is the invalid flag set?
	bra		TFT_display_tts_alt_1		; NO
	bcf		hi,int_invalid_flag			; YES - clear flag
	call	TFT_disabled_color			;     - switch to disabled color
TFT_display_tts_alt_1:
	output_16_3							; display only 0...999
	STRCAT_PRINT ""

	; 1st Stop
	call	TFT_divemask_color
	WIN_STD .25,dm_customview_row
	STRCPY_TEXT_PRINT tDiveSafetyStop	; "Stop"

	WIN_LARGE .60,.95
	call	TFT_color_code_stop				; color-code output
	movff	char_O_first_deco_depth,lo		; stop depth in m
	rcall	TFT_display_deko_output_depth	; output depth (stored in lo) to POSTINC2 with "m" or w/o (for ft)
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
	movff	char_O_first_deco_time,lo	; get stop time in minutes
	tstfsz	lo							; stop time = 0 ?
	bra		TFT_display_tts_alt_2		; NO  - print time
	STRCAT_PRINT ".."					; YES - special treatment
	bra		TFT_display_tts_alt_exit
TFT_display_tts_alt_2:
	bcf		leftbind
	output_99
	STRCAT_PRINT ""
TFT_display_tts_alt_exit:
	goto	TFT_standard_color			; and return...


TFT_big_deco_ndl_alt:
	; NDL
	bcf		FLAG_TFT_display_ndl
	bcf		decostop_active				; clear flag (again)
	btfsc	FLAG_gauge_mode				; in gauge mode?
	bra		TFT_big_deco_ndl_alt_1		; YES - skip NDL
	call	TFT_divemask_color
	WIN_STD .70,.165
	STRCPY_TEXT_PRINT tNDL				; NDL
	call	TFT_memo_color
	WIN_LARGE .97,.170
	movff	char_O_nullzeit,lo			; get NDL from C-code
	output_8
	STRCAT_PRINT ""
TFT_big_deco_ndl_alt_1:
	btfsc	FLAG_TFT_show_safety_stop
	bra		TFT_show_safety_stop_alt	; show safety stop (and return)
	; Clear any safety stop or Decostop
TFT_no_more_safety_stop_alt:
	WIN_BOX_BLACK	dm_customview_row, .150, .0, .159	; top, bottom, left, right
	WIN_BOX_BLACK	dm_customview_row, .164, .60, .159	; top, bottom, left, right
	return

TFT_show_safety_stop_alt:
	bcf		FLAG_TFT_show_safety_stop
	tstfsz	safety_stop_countdown		; countdown at zero?
	bra		TFT_show_safety_stop_alt2	; NO - show stop
	bcf		show_safety_stop			; clear flag
	btfss	safety_stop_active			; displayed?
	return								; NO
	bcf		safety_stop_active			; YES - clear flag
	bra		TFT_no_more_safety_stop_alt	;     - clear stop and return

TFT_show_safety_stop_alt2:
	bsf		safety_stop_active			; set flag
	decf	safety_stop_countdown,F		; reduce countdown

	call	TFT_divemask_color
	WIN_STD	.50,dm_customview_row
	STRCPY_TEXT_PRINT tDiveSafetyStop
	call	TFT_attention_color			; show in yellow
	WIN_LARGE	.90,.95
	movff	safety_stop_countdown,lo
	clrf	hi
	call	convert_time				; converts hi:lo in seconds to mins (up:hi) and seconds (lo)
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
	bra		TFT_display_exit_1


	global	TFT_divemode_warning
TFT_divemode_warning:
	bcf		FLAG_TFT_divemode_warning	; clear job flag
	bsf		dive_warning_displayed		; set advice/attention/warning sign is shown flag
	WIN_TOP  dm_warning_icon_row
	WIN_LEFT dm_warning_icon_column
	btfsc	message_warning				; do we have a warning?
	bra		TFT_divemode_warning_1		; YES - show warning   sign
	btfsc	message_attention			; NO  - do we have an attention?
	bra		TFT_divemode_warning_2		;       YES        - show attention sign
	bra		TFT_divemode_warning_3		;       NO to both - must be an advice then

dive_warning2_warning_colors:			; custom colors table for dive_warning2 icon - warning
	db	.4, 0							; #colors, spare
	dw	0x0000							; color 0x00: outside	black
	dw	0xff80							; color 0x01: triangle	yellow
	dw	0xff80							; color 0x02: excl.mark	yellow
	dw	0xf800							; color 0x03: inside	red

dive_warning2_advice_colors:			; custom colors table for dive_warning2 icon - advice
	db	.4, 0							; #colors, spare
	dw	0x0000							; color 0x00: outside	black
	dw	0xffff							; color 0x01: triangle	white
	dw	0xffff							; color 0x02: excl.mark	white
	dw	0x0780							; color 0x03: inside	green

TFT_divemode_warning_1:
	TFT_WRITE_PROM_IMAGE_CUST_COLOR dive_warning2_warning_colors
	TFT_WRITE_PROM_IMAGE_BY_LABEL   dive_warning2_block	; output warning   sign (with custom  colors)
	return
TFT_divemode_warning_2:
	TFT_WRITE_PROM_IMAGE_BY_LABEL   dive_warning2_block	; output attention sign (with default colors)
	return
TFT_divemode_warning_3:
	TFT_WRITE_PROM_IMAGE_CUST_COLOR dive_warning2_advice_colors
	TFT_WRITE_PROM_IMAGE_BY_LABEL   dive_warning2_block	; output advice    sign (with custom  colors)
	return


	global	TFT_divemode_warning_clear
TFT_divemode_warning_clear:
	bcf		FLAG_TFT_divemode_warning_clear	; clear job flag
	btfss	dive_warning_displayed			; advice/attention/warning sign is shown?
	return									; NO
	bcf		dive_warning_displayed			; YES - clear advice/attention/warning sign and its flag
	WIN_BOX_BLACK dm_warning_icon_row, dm_warning_icon_bot, dm_warning_icon_column, dm_warning_icon_rgt ; top, bottom, left, right
	return


	global	TFT_display_deko_mask
TFT_display_deko_mask:
	bcf		FLAG_TFT_display_deko_mask
	btfsc	divemode_menu			; is the dive mode menu shown? 
	return							; YES - return
	rcall	TFT_clear_decoarea		; clear decostop and decosum (and NDL in this case)
	WIN_STD dm_tts_text_column, dm_tts_text_row
	call	TFT_divemask_color
	STRCPY_TEXT_PRINT tTTS			; TTS
	bcf		show_safety_stop		; clear safety stop flag
	bra		TFT_display_exit_1


TFT_display_deko_output_depth:		; output depth (stored in lo) to POSTINC2 with "m" or w/o (for ft)
	TSTOSS	opt_units				; 0=m, 1=ft
	bra		TFT_display_deko_output_metric
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
	bsf		ignore_digit4			; only full feet
	output_16
	btfsc	alternative_divelayout
	return							; not for alternative layout mode
	STRCAT_TEXT tFeets1
	return

TFT_display_deko_output_metric:
	output_99
	btfsc	alternative_divelayout
	return							; not for alternative layout mode
	STRCAT_TEXT tMeters
	PUTC	' '
	return


	global	TFT_display_deko
TFT_display_deko:
	bcf		FLAG_TFT_display_deko
	btfsc	divemode_menu					; is the dive mode menu shown?
	return									; YES - return
	WIN_MEDIUM dm_decostop_1st_stop_column, dm_decostop_1st_stop_row
	call	TFT_color_code_stop				; color-code output
	movff	char_O_first_deco_depth,lo		; stop depth in m
	rcall	TFT_display_deko_output_depth	; output depth (stored in lo) to POSTINC2 with "m" or w/o (for ft)
	movff	char_O_first_deco_time,lo		; get stop time in minutes
	tstfsz	lo								; stop time = 0 ?
	bra		TFT_display_deko_1				; NO  - print minutes
	STRCAT_PRINT " ..'"						; YES - special treatment
	bra		TFT_display_exit_1
TFT_display_deko_1:
	output_99								; output lo
	STRCAT_PRINT "'"
TFT_display_exit_1
	goto	TFT_standard_color				; and return...


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
	rcall	TFT_display_deko_output_depth ; output depth (stored in lo) to POSTINC2 with "m" or w/o (for ft)
	movlw	NUM_STOPS					; offset between arrays holding depths and durations
	movff	PLUSW0,lo					; get duration of the current stop
	output_99							; output duration to POSTINC2
	STRCAT_PRINT "'"					; append symbol for minutes and print to screen
	bsf		ex,1						; flag that a stop was shown
	return


	global	TFT_clear_safety_stop
TFT_clear_safety_stop:
	bcf		FLAG_TFT_clear_safety_stop	; clear flag
	WIN_BOX_BLACK	dm_safetystop_row, dm_safetystop_bot, dm_safetystop_text_column, .159	; top, bottom, left, right
	return

	global	TFT_show_safety_stop
TFT_show_safety_stop:
	bcf		FLAG_TFT_show_safety_stop
	tstfsz	safety_stop_countdown		; countdown at zero?
	bra		TFT_show_safety_stop2		; NO - show stop
	bcf		show_safety_stop			; clear flag
	btfss	safety_stop_active			; displayed?
	return								; NO
	bcf		safety_stop_active			; clear flag
	btfsc	divemode_menu				; is the dive mode menu shown?
	return								; YES - return
	bra		TFT_clear_safety_stop		; NO  - clear stop and return...
TFT_show_safety_stop2:
	bsf		safety_stop_active			; set flag
	decf	safety_stop_countdown,F		; reduce countdown
	btfsc	divemode_menu				; is the dive mode menu shown?
	return								; YES - return
	;btfsc	menuview
	;bra	TFT_show_safety_stop3		; no room when menuview=1...
	call	TFT_divemask_color
	WIN_STD dm_safetystop_text_column, dm_safetystop_text_row
	STRCPY_TEXT_PRINT tDiveSafetyStop
TFT_show_safety_stop3:
	call	TFT_attention_color			; show in yellow
	WIN_MEDIUM	dm_safetystop_column, dm_safetystop_row
	movff	safety_stop_countdown,lo
	clrf	hi
	call	convert_time				; converts hi:lo in seconds to mins (up:hi) and seconds (lo)
	movf	hi,W
	movff	lo,hi
	movwf	lo							; exchange lo and hi
	bsf		leftbind
	output_8
	bcf		leftbind
	PUTC	':'
	movff	hi,lo
	output_99x
	STRCAT_PRINT ""
	WIN_FONT FT_SMALL
	bra		TFT_display_exit_1


	global	TFT_avr_stopwatch_mask		; mask for average depth and stopwatch
TFT_avr_stopwatch_mask:
	call	TFT_divemask_color
	WIN_TINY dm_custom_avr_stop_column1+.2,dm_custom_avr_stop_title_row
	TSTOSS	opt_2ndDepthDisp			; draw avg depth instead of max depth in main screen?
	bra		TFT_avr_stopwatch_mask_1	; NO  - draw avg depth in custom view then
	STRCAT_TEXT_PRINT tMaxDepth			; YES - draw max depth in custom view then
	bra		TFT_avr_stopwatch_mask_2
TFT_avr_stopwatch_mask_1:
	STRCPY_TEXT_PRINT tDiveTotalAvg
TFT_avr_stopwatch_mask_2:
	WIN_TINY dm_custom_avr_stop_column2+.3,dm_custom_avr_stop_title_row
	STRCPY_TEXT_PRINT tDiveStopwatch
	WIN_TINY dm_custom_avr_stop_column3-.8,dm_custom_avr_stop_title_row
	STRCPY_TEXT_PRINT tDiveStopAvg
	bra		TFT_display_exit_1


	global	TFT_avr_stopwatch			; data for average depth and stopwatch
TFT_avr_stopwatch:
	call	TFT_memo_color
	bsf		leftbind

	; total average depth or max depth
	WIN_MEDIUM dm_custom_avr_stop_column1,dm_custom_avr_stop_row
	TSTOSS	opt_2ndDepthDisp			; draw avg depth instead of max depth in main screen?
	bra		TFT_avr_stopwatch_01		; NO  - draw avg depth in custom view then
	SAFE_2BYTE_COPY max_pressure,lo		; YES - draw max depth in custom view then
	bra		TFT_avr_stopwatch_02
TFT_avr_stopwatch_01:
	movff	avg_rel_pressure_total+0,lo
	movff	avg_rel_pressure_total+1,hi
TFT_avr_stopwatch_02:
	call	adjust_depth_with_salinity	; computes salinity setting into lo:hi [mbar]
	TSTOSS	opt_units						 ; 0=m, 1=ft
	bra		TFT_update_avr_stopwatch1_metric ; 0 - metric
	;bra	TFT_update_avr_stopwatch1_imp	 ; 1 - imperial
TFT_update_avr_stopwatch1_imp:
	call	convert_mbar_to_feet		; convert value in hi:lo from mbar to feet
	output_16							; yxz
	STRCAT	"  "						; wipe out remains from last output
	clrf	WREG
	movff	WREG,buffer+.3				; limit string length to 3 digits
	bra		TFT_update_avr_stopwatch2
TFT_update_avr_stopwatch1_metric:
	bsf		ignore_digit5				; no cm (flag will be cleared by output_16)
	output_16dp .3						; yxz.a
	PUTC	" "							; wipe out remains from last output
	clrf	WREG
	movff	WREG,buffer+.4				; limit string length to 4 = 3 digits + 1 half-size decimal dot
TFT_update_avr_stopwatch2:
	STRCAT_PRINT ""

	; stopped average depth
	WIN_MEDIUM dm_custom_avr_stop_column3,dm_custom_avr_stop_row
	movff	avg_rel_pressure+0,lo
	movff	avg_rel_pressure+1,hi
	call	adjust_depth_with_salinity	; computes salinity setting into lo:hi [mbar]
	TSTOSS	opt_units						 ; 0=m, 1=ft
	bra		TFT_update_avr_stopwatch2_metric ; 0 - metric
	;bra	TFT_update_avr_stopwatch2_imp	 ; 1 - imperial
TFT_update_avr_stopwatch2_imp:
	call	convert_mbar_to_feet		; convert value in hi:lo from mbar to feet
	output_16							; yxz
	STRCAT	"  "						; wipe out remains from last output
	clrf	WREG
	movff	WREG,buffer+.3				; limit string length to 3 digits/characters
	bra		TFT_update_avr_stopwatch3
TFT_update_avr_stopwatch2_metric:
	bsf		ignore_digit5				; no cm (flag will be cleared by output_16)
	output_16dp .3						; yxz.a
	PUTC	" "							; wipe out remains from last output
	clrf	WREG
	movff	WREG,buffer+.4				; limit string length to 4 = 3 digits + 1 half-size decimal dot
TFT_update_avr_stopwatch3:
	STRCAT_PRINT ""

	; stopped dive time
	WIN_MEDIUM dm_custom_avr_stop_column2,dm_custom_avr_stop_row
TFT_update_stopwatch:					; jump-in point for stopped dive time in compass custom view
	movff	average_divesecs+0,lo		; average_divesecs is incremented outside ISR
	movff	average_divesecs+1,hi
	call	convert_time				; converts hi:lo in seconds to minutes (up:hi) and seconds (lo)
	movlw	.100						; display layout will change if minutes become >= 100
	cpfslt	hi							; minutes < 100 ?
	bra		TFT_update_stopwatch_2		; NO  - display hours:minutes
	;bra	TFT_update_stopwatch_1		; YES - display minutes:seconds
TFT_update_stopwatch_1:
	movf	hi,W						; exchange lo and hi
	movff	lo,hi						; ...
	movwf	lo							; ...
	output_8							; output minutes or hours
	PUTC	':'
	movff	hi,lo						; restore lo
	output_99x							; output seconds or minutes
	movlw	.5
	call	TFT_fillup_with_spaces		; fill up FSR2 with spaces (total string length in #WREG)
	clrf	WREG
	movff	WREG,buffer+.5				; limit to 5 chars
	STRCAT_PRINT ""
	bra		TFT_display_exit_2
TFT_update_stopwatch_2:
	movff	hi,lo						; transfer minutes (low  byte) to lo
	movff	up,hi						; transfer minutes (high byte) to hi
	call	convert_time				; converts hi:lo in minutes to hours (up:hi) and minutes (lo)
	bra		TFT_update_stopwatch_1


	global	TFT_CNS_mask
TFT_CNS_mask:
	call	TFT_divemask_color
	WIN_TINY dm_custom_cns3_column1, dm_custom_cns3_title_row
	STRCPY_TEXT_PRINT tCNSsurf
	WIN_TINY dm_custom_cns3_column2, dm_custom_cns3_title_row
	btfsc	FLAG_oc_mode				; in OC mode?
	bra		TFT_CNS_mask_1				; YES - print fTTS label
	btfsc	FLAG_bailout_mode			; in bailout?
	bra		TFT_CNS_mask_1				; YES - print fTTS label (label will be printed, but a fTTS will actually not be calculated)
	TSTOSS	opt_calc_asc_gasvolume		; bailout volume calculation requested?
	bra		TFT_CNS_mask_1				; NO  - print fTTS label
	STRCPY_TEXT_PRINT tCNSBO			; YES - print bailout label
	bra		TFT_CNS_mask_2
TFT_CNS_mask_1:							; OC or bailout
	STRCPY_TEXT_PRINT tCNSfTTS			; print fTTS label
TFT_CNS_mask_2:
	WIN_TINY dm_custom_cns3_column3, dm_custom_cns3_title_row
	STRCPY_TEXT_PRINT tCNSnow
	bra		TFT_display_exit_2


	global	TFT_CNS
TFT_CNS:
	bsf		leftbind
	; CNS at end of normal dive
	WIN_STD dm_custom_cns3_column1+.3,dm_custom_cns3_row
	movff	int_O_normal_CNS_fraction+0,lo
	movff	int_O_normal_CNS_fraction+1,hi
	call	TFT_color_code_cns
	output_16_3							; output as xxx
	STRCAT_PRINT "% "
	; fTTS / Bailout CNS, if enabled
	WIN_STD dm_custom_cns3_column2+.2,dm_custom_cns3_row
	btfsc	FLAG_bailout_mode			; in bailout?
	bra		TFT_CNS_3					; YES - show "---"
	TSTOSS	opt_calc_asc_gasvolume		; NO  - bailout volume calculation requested?
	bra		TFT_CNS_1					;       NO  - continue checking fTTS extra time
	btfss	FLAG_oc_mode				;       YES - in OC mode?
	bra		TFT_CNS_2					;             NO - show CNS%
TFT_CNS_1:								; not in bailout, no volume calculation, and/or in OC mode
	TSTOSS	char_I_extra_time			; fTTS extra time configured?
	bra		TFT_CNS_3					; NO  - show "---"
TFT_CNS_2:
	movff	int_O_alternate_CNS_fraction+0,lo	; YES - show CNS%
	movff	int_O_alternate_CNS_fraction+1,hi
	call	TFT_color_code_cns
	output_16_3							; output as xxx
	STRCAT_PRINT "% "
	bra		TFT_CNS_4
TFT_CNS_3:
	call	TFT_memo_color
	STRCPY_PRINT "---  "
TFT_CNS_4:
	; current CNS
	WIN_STD dm_custom_cns3_column3+.3,dm_custom_cns3_row
	movff	int_O_CNS_fraction+0,lo
	movff	int_O_CNS_fraction+1,hi
	call	TFT_color_code_cns
	output_16_3							; output as xxx
	STRCAT_PRINT "%"
TFT_display_exit_2:
	bcf		leftbind
	goto	TFT_standard_color			; and return...


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
	movff	o2_ppo2_sensor1,lo			; load ppO2 value into transfer storage for output
	clrf	hi							; 
	btfsc	use_O2_sensor1				; in use?
	bra		TFT_update_hud1d			; YES
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
	movff	o2_ppo2_sensor2,lo			; load ppO2 value into transfer storage for output
	clrf	hi							; 
	btfsc	use_O2_sensor2				; in use?
	bra		TFT_update_hud2d			; YES
	; valid calibration, but not in use
	tstfsz	o2_ppo2_sensor2				; sensor value = 0?
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
	btfsc	voting_logic_sensor2		; sensor value agrees with other sensor's vlaues?
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
	movff	o2_ppo2_sensor3,lo			; load ppO2 value into transfer storage for output
	clrf	hi							; 
	btfsc	use_O2_sensor3				; in use?
	bra		TFT_update_hud3d			; YES
	; valid calibration, but not in use
	tstfsz	o2_ppo2_sensor3				; sensor value = 0?
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
	btfsc	voting_logic_sensor3		; sensor value agrees with other sensor's values?
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


	global	TFT_surface_sensor			; update sensor data in surface mode
TFT_surface_sensor:
	movf	hardware_flag1,W
	sublw	0x11						; 2 with BLE
	btfsc	STATUS,Z
	return								; ignore for 0x11
	; show three sensors
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
	movff	o2_ppo2_sensor1,lo
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
	movff	o2_ppo2_sensor2,lo
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
	movff	o2_ppo2_sensor3,lo
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
	call	TFT_standard_color
	bsf		leftbind

	WIN_SMALL surf_mV_sensor_column,surf_mV_sensor1_row
	movff	o2_mv_sensor1+0,lo			; in 0.1mV steps
	movff	o2_mv_sensor1+1,hi			; in 0.1mV steps
	STRCAT	"1: "
	rcall	TFT_sensor_mV_helper

	WIN_SMALL surf_mV_sensor_column,surf_mV_sensor2_row
	movff	o2_mv_sensor2+0,lo			; in 0.1mV steps
	movff	o2_mv_sensor2+1,hi			; in 0.1mV steps
	STRCAT	"2: "
	rcall	TFT_sensor_mV_helper

	WIN_SMALL surf_mV_sensor_column,surf_mV_sensor3_row
	movff	o2_mv_sensor3+0,lo			; in 0.1mV steps
	movff	o2_mv_sensor3+1,hi			; in 0.1mV steps
	STRCAT	"3: "
	rcall	TFT_sensor_mV_helper
	bra		TFT_display_exit_3

TFT_sensor_mV_helper:
	output_16dp .4						; xxx.y mV
	STRCAT_PRINT "mV "
	return


	global	TFT_sensor_surface_warning
TFT_sensor_surface_warning: 
	call	TFT_warnings_color
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
	bra		TFT_display_exit_3


	global	TFT_clock
TFT_clock:
 IFDEF _ostc_logo
	WIN_SMALL surf_clock_column,surf_clock_row
 ELSE
	WIN_SMALL surf_clock_column+.7,surf_clock_row
 ENDIF
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

	global	TFT_surface_decosettings	; show all deco settings
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
	STRCPY_TEXT tLastDecostopSurf
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

	global	TFT_divetimeout				; show timeout counter
TFT_divetimeout:
	call	TFT_warning_set_window		; set the row and column for the current message
	tstfsz	WREG						; is there room for the message?
	return								; NO
	call	TFT_memo_color
	STRCPY	0x94						; "End of dive" symbol
	movff	opt_diveTimeout,WREG		; in [min]
	mullw	.60
	movff	PRODL,sub_a+0
	movff	PRODH,sub_a+1				; in [s]
	movff	timeout_counter1+0,sub_b+0
	movff	timeout_counter1+1,sub_b+1
	call	subU16						; sub_c = sub_a - sub_b (with UNSIGNED values)
	movff	sub_c+0,lo
	movff	sub_c+1,hi
	call	convert_time				; converts hi:lo in minutes to hours (up:hi) and minutes (lo)
	movf	hi,W
	movff	lo,hi
	movwf	lo							; exchange lo and hi
	output_99x
	PUTC	':'
	movff	hi,lo
	output_99x
	movlw	dm_warning_length			; divemode string length
	call	TFT_fillup_with_spaces		; fill up FSR2 with spaces (total string length in #WREG)
	STRCAT_PRINT ""
	bcf		win_invert
	return

	global	TFT_display_ftts
TFT_display_ftts:
	call	TFT_warning_set_window		; sets the row and column for the current warning
	tstfsz	WREG						; is there room for the message?
	return								; NO  - done
	btfsc	FLAG_oc_mode				; YES - in OC mode?
	bra		TFT_display_ftts_1			;       YES - print fTTS label
	TSTOSS	opt_calc_asc_gasvolume		;       NO  - bailout volume calculation requested?
	bra		TFT_display_ftts_1			;             NO  - print fTTS label
	STRCPY	"B/O"						;             YES - print bailout label
	bra		TFT_display_ftts_2
TFT_display_ftts_1:						; OC or CCR/pSCR but no bailout volume calculation
	STRCPY	"@+"						; print fTTS label
TFT_display_ftts_2:
	movff	char_I_extra_time,lo		; get fTTS delay time
	bsf		leftbind					; print with alignment to the left
	output_8							; print fTTS delay time
	PUTC	":"							; ":"
	movff	int_O_alternate_ascenttime+0,lo
	movff	int_O_alternate_ascenttime+1,hi
	call	TFT_memo_color				; set memo color
	btfss	hi,int_invalid_flag			; is the invalid flag set?
	bra		TFT_display_ftts_3			; NO  - keep memo color
	bcf		hi,int_invalid_flag			; YES - clear flag
	call	TFT_disabled_color			;     - switch to disabled color
TFT_display_ftts_3:
	btfsc	hi,int_not_yet_computed		; is the not-computed-yet flag set?
	bra		TFT_display_ftts_4			; YES - show dashes
	movf	lo,W
	iorwf	hi,W						; extra_ascenttime = 0 ?
	bz		TFT_display_ftts_5			; YES - show "NDL"
	movff	char_O_deco_info,up			; get deco info vector
	btfsc	up,deco_steady				; fTTS = TTS ?
	call	TFT_advice_color			; YES - set to advice color (green)
	btfsc	up,deco_decreasing			; fTTS < TTS ?
	call	TFT_advice_color			; YES - set to advice color (green)
	output_16							; NO  - show ascent time
	PUTC	"'"							;     - minutes symbol
	bra		TFT_display_ftts_6
TFT_display_ftts_4:
	STRCAT	"---"						; "---" for not computed
	bra		TFT_display_ftts_6
TFT_display_ftts_5:
	STRCAT_TEXT tNDL					; "NDL"
TFT_display_ftts_6:
	movlw	dm_warning_length			; dive mode string length
	call	TFT_fillup_with_spaces		; fill up FSR2 with spaces (total string length in #WREG)
	STRCAT_PRINT ""
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


	global	TFT_temp_divemode
TFT_temp_divemode:
	bcf		FLAG_TFT_temp_divemode
	btfsc	divemode_menu					; is the dive mode menu shown?
	return									; YES - no update of temperature now
	btfsc	blinking_better_gas				; blinking better gas?
	return									; YES - no update of temperature now
	btfsc	blinking_better_dil				; blinking better diluent?
	return									; YES - no update of temperature now
	WIN_SMALL dm_temp_column,dm_temp_row
	call	TFT_memo_color
	btfsc	alternative_divelayout			; in alternative layout?
	bra		TFT_temp_common					; YES - proceed with temperature
	movlw	index_compass_dm				; NO  - index of compass custom view
	cpfseq	menupos3						;     - compass shown in custom view?
	bra		TFT_temp_common					;       NO  - proceed with temperature
	bra		TFT_update_stopwatch			;       YES - show resettable dive time instead of temperature
TFT_temp_common:
	SAFE_2BYTE_COPY temperature,lo			; get current temperature
	TSTOSS	opt_units						; 0=°C, 1=°F
	bra		TFT_temp_common_1
	call	convert_celsius_to_fahrenheit	; convert value in lo:hi from celsius to fahrenheit
TFT_temp_common_1:
	rcall	TFT_convert_signed_16bit		; converts lo:hi into signed-short and adds '-' to POSTINC2 if required
	btfsc	neg_flag						; is the temperature negative?
	bra		TFT_temp_common_2				; YES - the minus sign has already been written
	; temp is positive, is it less than 10°C ?
	tstfsz	hi
	bra		TFT_temp_common_1a				; >25.5°C, skip here
	movlw	.100
	cpfslt	lo
	bra		TFT_temp_common_1a				; >10.0°C, skip here
	bsf		leftbind
	output_16dp	d'4'						; x.y°C
	bcf		leftbind
	bra		TFT_temp_common_3				; done
TFT_temp_common_1a:
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
	return

;=============================================================================

	global	TFT_divemode_menu_cursor
TFT_divemode_menu_cursor:
	WIN_BOX_BLACK dm_menu_row+.1, dm_menu_lower-.1, dm_menu_item1_column-.8, dm_menu_item1_column-.1
	WIN_BOX_BLACK dm_menu_row+.1, dm_menu_lower-.1, dm_menu_item4_column-.8, dm_menu_item4_column-.1
	call	TFT_standard_color

	movlw	dm_menu_item1_column-.8
	btfsc	menupos1,2					; > 3 ?
	movlw	dm_menu_item4_column-.8		; YES
	movwf	win_leftx2

	movff	menupos1,lo					; copy menu position
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


	global	TFT_active_gas_divemode
TFT_active_gas_divemode:				; display gas/setpoint
	bcf		FLAG_TFT_active_gas_divemode
	btfsc	divemode_menu				; is the dive mode menu shown?
	return								; YES - return
	btfsc	FLAG_apnoe_mode				; in apnoe mode?
	return								; YES - return
	btfsc	FLAG_gauge_mode				; in gauge mode?
	return								; YES - return
	btfss	FLAG_oc_mode				; in OC mode?
	bra		TFT_active_setpoint			; NO  - show setpoint and gas mix
	bra		TFT_active_gas_divemode_oc	; YES - show OC gas

TFT_active_setpoint_bail:				; bailout case
	tstfsz	menupos2					; any option shown?
	bra		TFT_active_gas_divemode_oc	; YES - do not overwrite with bailout text
	WIN_SMALL dm_active_dil_column, dm_active_dil_row
	call	TFT_attention_color			; print in yellow
	STRCPY_TEXT_PRINT tDiveBailout		; "Bailout"
TFT_active_gas_divemode_oc:				; common part for OC and bailout
	movff	int_O_breathed_ppO2+0,lo	; color-code the output of the gas by the ppO2 it yields
	movff	int_O_breathed_ppO2+1,hi	;
	call	TFT_color_code_ppo2			; with ppO2 [cbar] in hi:lo
	btfss	better_gas_available		; check if a better gas is available and a gas change shall be advised
	bra		TFT_active_gas_print		; NO  - print in normal rendering
	btg		blinking_better_gas			; YES - toggle blink bit
	btfss	blinking_better_gas			;       blink now?
	bra		TFT_active_gas_print		;       NO  - print in normal rendering
	call	TFT_attention_color			;       YES - blink in yellow
	bsf		win_invert					;             set invert flag
TFT_active_gas_print:
	WIN_STD	dm_active_gas_column, dm_active_gas_row
	movff	char_I_O2_ratio,lo			; lo now stores O2 in %
	movff	char_I_He_ratio,hi			; hi now stores He in %
	call	customview_show_mix			; put "Nxlo", "Txlo/hi", "Air" or "O2" into Postinc2
	STRCAT_PRINT ""
	bcf		win_invert					; reset invert flag
	goto	TFT_standard_color			; ...and return

	; in CCR / pSCR mode - and maybe in bailout
TFT_active_setpoint:					;
	btfsc	FLAG_bailout_mode			; in bailout?
	bra		TFT_active_setpoint_bail	; YES - show "Bailout" instead of setpoint

	; on the loop
	movff	int_O_breathed_ppO2+0,lo	; color-code the output by the ppO2 of the loop gas mixture
	movff	int_O_breathed_ppO2+1,hi
	call	TFT_color_code_ppo2			; with ppO2 [cbar] in hi:lo
	btfss	secs,0						; timebase for blinking effect: on even second?
	bra		TFT_active_setpoint_print	; YES - print ppO2 with normal rendering
	btfsc	setpoint_fallback			; NO  - check if we are in fallback condition
	bra		TFT_active_setpoint_fallb	;       YES - process fallback case
	movff	int_O_breathed_ppO2+1,WREG	;       NO  - get flags again (have been cleared in hi:lo by TFT_color_code_ppo2 meanwhile)
	btfss	WREG,int_warning_flag		;             warning flag set?
	bra		TFT_active_setpoint_print	;             NO  - ppO2 is ok, print ppO2 with normal rendering
	bra		TFT_active_setpoint_com		;             YES - continue with blinking common part
TFT_active_setpoint_fallb:				; set up fallback case 
	call	TFT_attention_color			; text in yellow 
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
	call	TFT_memo_color				; revert to memo color
TFT_active_setpoint_diluent:			; diluent gas
	movff	int_O_pure_ppO2+0,lo		; color-code the output
	movff	int_O_pure_ppO2+1,hi
	call	TFT_color_code_ppo2					; with ppO2 [cbar] in hi:lo
	btfss	better_dil_available				; check if a better diluent is available and a diluent change shall be advised
	bra		TFT_active_setpoint_diluent_show	; NO  - print in normal rendering
	btg		blinking_better_dil					; YES - toggle blink bit...
	btfss	blinking_better_dil					; blink now?
	bra		TFT_active_setpoint_diluent_show	; NO  - print in normal rendering
	call	TFT_attention_color					; YES - print in yellow color
	bsf		win_invert							;     - set invert flag
TFT_active_setpoint_diluent_show:
	WIN_SMALL dm_active_dil_column, dm_active_dil_row
	movff	char_I_O2_ratio,lo			; lo now stores O2 in %
	movff	char_I_He_ratio,hi			; hi now stores He in %
	call	customview_show_mix			; put "Nxlo", "Txlo/hi", "Air" or "O2" into Postinc2
	STRCAT_PRINT ""
	bcf		win_invert					; reset invert flag
	call	TFT_memo_color				; set memo color
	btfsc	menuview					; is the dive options menu shown?
	return								; YES - do not overwrite it
	WIN_TINY dm_active_dil_column+.45, dm_active_dil_row+.3
	btfsc	FLAG_ccr_mode				; in CCR mode?
	bra		TFT_active_setpoint_ccr		; YES - write CCR label
	btfsc	FLAG_pscr_mode				; in pSCR mode?
	bra		TFT_active_setpoint_pscr	; YES - write pSCR label
	return								; NO  to both - should not happen, anyhow: done
TFT_active_setpoint_ccr:
	STRCPY_TEXT_PRINT tDvCCR			; print "CCR"
	return								; done
TFT_active_setpoint_pscr:
	STRCPY_TEXT_PRINT tDvPSCR			; print "PSCR"
	return								; done


	global	TFT_display_decotype_surface
TFT_display_decotype_surface:
	WIN_STD	surf_decotype_column,surf_decotype_row
	WIN_COLOR color_lightblue
	movff	opt_dive_mode,lo				; 0=OC, 1=CC, 2=Gauge, 3=Apnoe, 4=PSCR
	tstfsz	lo
	bra		TFT_display_decotype_surface2
TFT_display_decotype_surface0:
	STRCAT_TEXT_PRINT tDvOC					; OC
	bra		TFT_display_decotype_exit
TFT_display_decotype_surface2:
	decfsz	lo,F
	bra		TFT_display_decotype_surface3
	STRCAT_TEXT_PRINT tDvCC					; CC
	call	TFT_standard_color
	WIN_TINY surf_decotype_column+.18,surf_decotype_row+.12
	TSTOSS	opt_ccr_mode					; =0: Fixed SP, =1: Sensor, =2: Auto SP
	bra		TFT_display_decotype_cc_fixed
	; Sensor mode or Auto
	movff	opt_ccr_mode,WREG
	sublw	.2
	bz		TFT_display_decotype_cc_auto
	STRCPY_TEXT tCCRModeSensor				; sensor
	bra		TFT_display_decotype_cc_common
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
	STRCAT_TEXT_PRINT tDvPSCR				; pSCR
TFT_display_decotype_exit:
	goto	TFT_standard_color				; and return...


	global	TFT_display_decotype_surface1
TFT_display_decotype_surface1:				; used from logbook and from deco calculator (simulator.asm)
	tstfsz	lo								; lo holds 0=OC, 1=CC, 2=Gauge, 3=Apnea, 4=pSCR
	bra		TFT_display_decotype_surface1_2
	bra		TFT_display_decotype_surface0	; OC
TFT_display_decotype_surface1_2:
	decfsz	lo,F
	bra		TFT_display_decotype_surface1_3
	STRCAT_TEXT_PRINT	tDvCC				; CC
	bra		TFT_display_decotype_exit
TFT_display_decotype_surface1_3:
	decfsz	lo,F
	bra		TFT_display_decotype_surface1_4
	bra		TFT_display_decotype_surface3_1	; Gauge
TFT_display_decotype_surface1_4:
	decfsz	lo,F
	bra		TFT_display_decotype_surface5	; pSCR
	bra		TFT_display_decotype_surface4_1	; Apnea

;=============================================================================

	global	TFT_splist_surfmode			; show setpoint list
TFT_splist_surfmode:
	bsf		short_gas_decriptions		; =1: Use short versions of gaslist_strcat_gas_cd and gaslist_strcat_setpoint
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

	global	TFT_gaslist_surfmode
TFT_gaslist_surfmode:					; displays gas list
	bsf		short_gas_decriptions		; =1: Use short versions of gaslist_strcat_gas_cd and gaslist_strcat_setpoint
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

	global	TFT_dillist_surfmode
TFT_dillist_surfmode:					; displays diluent list
	bsf		FLAG_diluent_setup			; use CCR diluents...
	rcall	TFT_gaslist_surfmode		; use OC/BAIL routine
	bcf		FLAG_diluent_setup			; clear flag
	return

;==================================================================

	global	TFT_depth
TFT_depth:
	bcf		FLAG_TFT_depth
	SAFE_2BYTE_COPY rel_pressure, lo
	call	adjust_depth_with_salinity	; computes salinity setting into lo:hi [mbar]
	call	TFT_color_code_depth		; color-code the output
	rcall	TFT_depth_blink
	WIN_LARGE dm_depth_column, dm_depth_row
	TSTOSS	opt_units					; 0=m, 1=ft
	bra		TFT_depth_metric
;TFT_depth_imperial
	clrf	sub_a+1						; display 0ft if lower then 30cm
	movlw	d'30'
	movwf	sub_a+0
	movff	hi,sub_b+1
	movff	lo,sub_b+0
	call	subU16						; sub_c = sub_a - sub_b
	btfss	neg_flag					; depth lower then 0.4m?
	bra		depth_less_0.3mtr_feet		; YES - show 0ft manually
	call	convert_mbar_to_feet		; convert value in hi:lo from mbar to feet
	bsf		leftbind
	output_16							; feet in Big font
	bcf		leftbind
	movlw	.3							; limit to three chars
	call	TFT_fillup_with_spaces		; fill up FSR2 with spaces (total string length in #WREG)
	STRCAT_PRINT ""						; display feet
	bcf		win_invert					; reset invert flag
	return

depth_less_0.3mtr_feet:
	STRCAT_PRINT "0  "					; manual zero
	bcf		win_invert					; reset invert flag
	return

TFT_depth_metric:
	movlw	.039
	cpfslt	hi
	bra		depth_greater_99_84mtr

	btfsc	depth_greater_100m			; was depth > 100m during last call?
	rcall	TFT_clear_depth				; YES - clear depth area
	bcf		depth_greater_100m			; do this once only...

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
	addwfc	sub_b+1,F				; add 1mbar offset
	call	sub16					; sub_c = sub_a - sub_b
	movlw	' '
	btfss	neg_flag				; depth lower then 10m?
	movwf	POSTINC2				; YES - add extra space

	clrf	sub_a+1
	movlw	d'99'
	movwf	sub_a+0
	movff	hi,sub_b+1
	movff	lo,sub_b+0
	call	subU16					; sub_c = sub_a - sub_b
	btfss	neg_flag				; depth lower then 1m?
	bra		tft_depth2				; YES - display manual Zero

	bsf		leftbind
	bsf		ignore_digit4
	output_16						; full meters in big font
	bcf		leftbind
	bra		tft_depth3

tft_depth2:
	STRCAT	"0"						; manual zero

tft_depth3:
	STRCAT_PRINT ""					; display full meters

	; .1m in MEDIUM font
	WIN_MEDIUM	dm_depth_dm_column, dm_depth_dm_row

	SAFE_2BYTE_COPY rel_pressure, lo
	call	adjust_depth_with_salinity	; computes salinity setting into lo:hi [mbar]
	;call	TFT_color_code_depth	; color-code the output - not needed, furthermore: seems to cause problems if not commented out...

	PUTC	"."
	movlw	HIGH d'30'				; display 0.0m if lower then 30cm
	movwf	sub_a+1
	movlw	LOW  d'30'
	movwf	sub_a+0
	movff	hi,sub_b+1
	movff	lo,sub_b+0
	call	subU16					; sub_c = sub_a - sub_b
	btfss	neg_flag				; depth lower then 0.3m?
	bra		depth_less_0.3mtr		; YES - show ".0" manually

	movlw	d'4'
	movwf	ignore_digits
	bsf		ignore_digit5			; (flag will be cleared by output_16)
	output_16dp d'0'
	STRCAT_PRINT ""					; display decimeters
	bcf		win_invert				; reset invert flag
	WIN_FONT FT_SMALL
	return

depth_less_0.3mtr:
	STRCAT_PRINT "0"				; display 0.0m manually
	bcf		win_invert				; reset invert flag
	WIN_FONT FT_SMALL
	return

depth_greater_99_84mtr:				; display only in full meters
	btfss	depth_greater_100m		; is depth > 100m already?
	rcall	TFT_clear_depth			; NO - clear depth area and set flag
	call	TFT_color_code_depth
	; Depth is already in hi:lo
	; Show depth in Full meters
	; That means ignore digit 4 and 5
	lfsr	FSR2,buffer
	bsf		ignore_digit4
	bsf		leftbind
	output_16
	bcf		leftbind
	STRCAT_PRINT ""					; display full meters only
	bcf		win_invert				; reset invert flag
	WIN_FONT FT_SMALL
	return

TFT_clear_depth:					; NO - clear depth area and set flag
	WIN_BOX_BLACK dm_depth_row, dm_depth_bot, dm_depth_column, dm_depth_rgt	;top, bottom, left, right
	bsf		depth_greater_100m		; set flag
	return

TFT_depth_blink:
	TSTOSS	opt_modwarning			; 0=standard, 1=blink
	return

	; check if previous cycle had the blinking warning or not
	btfsc	blinking_depth_prev		; did we have warning previously?
	bra		TFT_depth_blink_prevwarn; YES

	; NO - check if it's set now
	btfsc	blinking_depth_warning	; do we have warning set now?
	bra		TFT_depth_blink_warn	; Yes  - so we have warning now but not previously
	btfsc	blinking_depth_attention; do we have attention set now?
	bra		TFT_depth_blink_warn	; Yes  - so we have attention now but not previously

	; no warning in previous cycle, no warning now, reset all flags
	bcf		blinking_depth_prev		; reset previous flag
	bcf		blinking_depth_toggle	; reset toggle
	bcf		win_invert
	return							; all done

TFT_depth_blink_prevwarn:
	; ...we had warning in previous cycle, check if we still have the warning set
	btfsc	blinking_depth_warning			; do we still have the warning?
	bra		TFT_depth_blink_prevwarn_1		; YES
	btfss	blinking_depth_attention		; do we still have the attention?
	bra		TFT_depth_blink_prevwarn_nowarn	; NO - clear the depth area
TFT_depth_blink_prevwarn_1:
	; we still have the warning, set previous flag for next cycle...
	bsf		blinking_depth_prev				; set prev flag
	; and set toggle and invert if required
	btfss	blinking_depth_toggle			; do we have the toggle set?
	bra		TFT_depth_blink_set				; NO  - set inverse,   do color_box, set   flag
	bra		TFT_depth_blink_reset			; Yes - clear inverse, do black box, reset flag

TFT_depth_blink_prevwarn_nowarn:
	; we had warning, but not now... (e.g. ascended or switched to better gas)
	; reset the previous cycle flag for the next cycle...
	bcf		blinking_depth_prev				; reset prev flag
	; clear it - just in case if we had a blinked before
	bra		TFT_depth_blink_reset			; clear inverse, do black box, reset flag

TFT_depth_blink_warn:
	; new blinking warning activated (had no warning in previous cycle)
	bsf		blinking_depth_prev				; set prev flag
	; set toggle and invert
	;bra	TFT_depth_blink_set

TFT_depth_blink_set:
	; clear the area with color
	call	TFT_attention_color_dive		; default to attention color
	btfsc	blinking_depth_warning			; in warning mode?
	call	TFT_warnings_color_dive			; overwrite with warning color
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
	btfsc	blinking_depth_attention
	call	TFT_attention_color
	; all done
	return

;=============================================================================

	global	TFT_custom_text
TFT_custom_text:					; show the custom text
	call	TFT_standard_color
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
	bra		TFT_custom_text_2		; show up to 12 chars, print and return...


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

	global	TFT_update_surf_press
TFT_update_surf_press:
	WIN_SMALL surf_press_column+.8,surf_press_row
	call	TFT_standard_color
	SAFE_2BYTE_COPY amb_pressure, lo
	movff	lo,sub_a+0
	movff	hi,sub_a+1
	movff	last_surfpressure_30min+0,sub_b+0
	movff	last_surfpressure_30min+1,sub_b+1
	call	subU16								; sub_c = sub_a - sub_b
	btfsc	neg_flag							; pressure lower?
	rcall	update_surf_press2					; YES - test threshold
	tstfsz	sub_c+1								; >255 mbar difference?
	bra		update_surf_press_common			; YES -  display
	movlw	d'11'								; 10mbar noise suppression
	subwf	sub_c+0,W
	btfsc	STATUS,C
	bra		update_surf_press_common			; YES - display
	SAFE_2BYTE_COPY last_surfpressure_30min, lo	; overwrite with stable value...
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
	WIN_SMALL	surf_press_column+(4+1)*8,surf_press_row
	STRCPY_TEXT_PRINT tMBAR						; mbar (hPa)
	return

update_surf_press2:
	movff	lo,sub_b+0
	movff	hi,sub_b+1
	movff	last_surfpressure_30min+0,sub_a+0
	movff	last_surfpressure_30min+1,sub_a+1
	goto	subU16								; sub_c = sub_a - sub_b and return...

;=============================================================================

	global	TFT_update_batt_voltage
TFT_update_batt_voltage:
	movff	batt_percent,lo			; get battery percent
	clrf	hi
	call	TFT_color_code_battery	; color-code battery percent
	; Setup charge indicator
	btfsc	cc_active
	bsf		win_invert
	btfsc	cc_active
	movlw	color_yellow
	btfsc	cv_active
	movlw	color_green
	btfsc	cc_active
	call	TFT_set_color

 IFDEF _ostc_logo
	WIN_TINY  batt_percent_column,batt_percent_row
 ELSE
	WIN_SMALL batt_percent_column+.2,batt_percent_row
 ENDIF

	output_16_3						; display only last three digits from a 16 bit value (0-999)
	STRCAT_PRINT "% "
	bcf		win_invert
	call	TFT_standard_color

 IFDEF _ostc_logo
	WIN_TINY batt_voltage_column,batt_voltage_row
 ELSE
	WIN_TINY batt_voltage_column+.15,batt_voltage_row
 ENDIF

	movff	battery_type,lo			; =0: 1.5V, =1: 3.6V Saft, =2: LiIon 3.7V/0.8Ah, =3: LiIon 3.7V/3.1Ah, =4: LiIon 3.7V/2.3Ah
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
;	movlw	LOW		.152
;	movwf	xB+0
;	movlw	HIGH	.152
;	movwf	xB+1
;	call	div32x16				; xC:4 / xB:2 = xC+3:xC+2 with xC+1:xC+0 as remainder
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
	bcf		neg_flag				; positive temperature
	btfss	hi,7					; negative temperature ?
	return							; NO  - return
									; YES - negative temperature
	bsf		neg_flag				; negative temperature
	PUTC	'-'						; display "-"
	comf	hi						; 16 bit sign change
	negf	lo
	btfsc	STATUS,C
	incf	hi
	return							; done

;=============================================================================

	global	TFT_convert_date
TFT_convert_date:					; converts into "DD/MM/YY" or "MM/DD/YY" or "YY/MM/DD" in postinc2
	movff	opt_dateformat,WREG		; =0:MMDDYY, =1:DDMMYY, =2:YYMMDD
	movwf	EEDATA					; used as temp here
	tstfsz	EEDATA
	bra		TFT_convert_date_1		; opt_dateformat is 1 or 2
									; opt_dateformat is 0
									; use MMDDYY
	movff	lo,lo_temp				; incoming: lo = day,   hi = month
	movff	hi,lo					; swap
	movff	lo_temp,hi				; now:      lo = month, hi = day
	bra		TFT_convert_date_common

TFT_convert_date_1:
	decfsz	EEDATA,F
	bra		TFT_convert_date_2		; opt_dateformat is 2
									; opt_dateformat is 1
									; use DDMMYY
TFT_convert_date_common:
	bsf		leftbind
	output_99x						; with lo = month or day   or year
	PUTC	'.'
	movff	hi,lo					; now  lo = day   or month or month
	output_99x
	PUTC	'.'
	movff	up,lo					; now  lo = year  or year  or day
	output_99x
	bcf		leftbind
	return

TFT_convert_date_2:
									; opt_dateformat is 2
									; use YYMMDD
	movff	lo,lo_temp				; incoming: lo = day,  up = year
	movff	up,lo					; swap
	movff	lo_temp,up				; now     : lo = year, up = day
	bra		TFT_convert_date_common

;=============================================================================

	global	TFT_convert_date_short
TFT_convert_date_short:				; converts into "DD/MM" or "MM/DD" or "MM/DD" in postinc2
	movff	opt_dateformat,WREG		; =0:MMDDYY, =1:DDMMYY, =2:YYMMDD
	movwf	EEDATA					; used as temp here
	tstfsz	EEDATA
	bra		TFT_convert_date_short_1
									; opt_dateformat is 0
									; use MMDD(YY)
TFT_convert_date_short_0:
	movff	lo,lo_temp				; incoming: lo = day,   hi = month
	movff	hi,lo					; swap
	movff	lo_temp,hi				; now:      lo = month, hi = day
	bra		TFT_convert_date_short_common

TFT_convert_date_short_1:
	decfsz	EEDATA,F
	bra		TFT_convert_date_short_0 ; opt_dateformat is 2 -> use (YY)MMDD
									; opt_dateformat is 1
									; use DDMM(YY)
TFT_convert_date_short_common:
	bsf		leftbind
	output_99x						; with lo = month or day
	PUTC	'.'
	movff	hi,lo					; now  lo = day   or month
	output_99x
	bcf		leftbind
	return

;=============================================================================

	global	TFT_date
TFT_date:
	WIN_SMALL	surf_date_column,surf_date_row	; init new wordprocessor
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
	bcf		FLAG_TFT_max_depth
	; The "mask"
	call	TFT_divemask_color
	WIN_TINY dm_mask_depth_column, dm_max_alt_row-.14
	btfsc	FLAG_apnoe_mode				; in Apnea mode?
	bra		TFT_max_depth_alternative2	; YES - always draw max depth
	TSTOSS	opt_2ndDepthDisp			; draw avg depth instead of max depth?
	bra		TFT_max_depth_alternative2	; NO  - draw max depth
	STRCAT_TEXT_PRINT tAvgDepth			; YES - print avg depth mask
	movff	avg_rel_pressure_total+0,lo	;     - get avg depth, low  byte
	movff	avg_rel_pressure_total+1,hi	;     -                high byte
	bra		TFT_max_depth_alternative3
TFT_max_depth_alternative2:
	STRCAT_TEXT_PRINT tMaxDepth			; print max depth mask
	SAFE_2BYTE_COPY max_pressure, lo	; get max depth into hi:lo
TFT_max_depth_alternative3:
	call	adjust_depth_with_salinity	; compute salinity setting into lo:hi [mbar]
	call	TFT_memo_color
	WIN_LARGE dm_max_alt_column,dm_max_alt_row
	TSTOSS	opt_units					; 0=m or 1=ft?
	bra		TFT_max_depth_alt_metric	; 0 - use alternative metric   version
	bra		TFT_max_depth_imperial		; 1 - use common      imperial version
TFT_max_depth_alt_metric:
	movff	hi,sub_b+1					; backup hi in sub_b+1
	movff	lo,sub_b+0					; backup lo in sub_b+0
	bsf		ignore_digit4				; no 0.1 m
	output_16
	STRCAT_PRINT ""
	WIN_MEDIUM dm_max_dm_alt_column,dm_max_alt_row+.25
	bra		TFT_max_depth_metric3		; continue with normal metric version for decimal


	global	TFT_max_depth
TFT_max_depth:
	bcf		FLAG_TFT_max_depth
	btfsc	FLAG_apnoe_mode				; in Apnoe mode?
	bra		TFT_max_depth1				; YES - different handling in Apnoe mode
	TSTOSS	opt_2ndDepthDisp			; draw avg depth instead of max depth?
	bra		TFT_max_depth2				; NO  - show max depth
	movff	avg_rel_pressure_total+0,lo	; YES - get avg depth, low  byte
	movff	avg_rel_pressure_total+1,hi	;     -                high byte
	bra		TFT_max_depth3
TFT_max_depth1:
	btfss	FLAG_active_descent			  ; are we descending?
	bra		TFT_max_depth2				  ; NO  - show normal max
	SAFE_2BYTE_COPY apnoe_max_pressure,lo ; YES - get apnoe_max_pressure
	bra		TFT_max_depth3
TFT_max_depth2:
	SAFE_2BYTE_COPY max_pressure,lo		; get the "normal" max depth
TFT_max_depth3:
	call	adjust_depth_with_salinity	; computes salinity setting into lo:hi [mbar]
	movlw	.039						; load encoding for  99.84 m
	cpfslt	hi							; is depth to show > 99.84 m ?
	bra		TFT_max_depth3a				; YES
	btfss	max_depth_greater_100m		; NO  - was depth > 100 m during last call?
	bra		TFT_max_depth3c				;       NO
	bcf		max_depth_greater_100m		;       YES - clear flag, last depth shown now not > 100 m anymore
	bra		TFT_max_depth3b				;           - clear depth area
TFT_max_depth3a:
	btfsc	max_depth_greater_100m		; YES - was depth > 100 m during last call?
	bra		TFT_max_depth3c				;       YES
	bsf		max_depth_greater_100m		;       NO  - set flag, last depth shown now > 100 m
	;bra	TFT_max_depth3b				;           - clear depth area
TFT_max_depth3b:
	WIN_BOX_BLACK dm_max_depth_row, dm_max_depth_bot, dm_max_depth_column, dm_max_depth_rgt	; top, bottom, left, right
TFT_max_depth3c:
	call	TFT_memo_color				; set output color
	WIN_MEDIUM dm_max_depth_column_nvsi, dm_max_depth_row
	TSTOSS	opt_vsigraph				; graphical VSI bar enabled?
	bra		TFT_max_depth4				; NO
	WIN_MEDIUM dm_max_depth_column, dm_max_depth_row ; YES - adopt output position
TFT_max_depth4:
	TSTOSS	opt_units					; 0=m or 1=ft ?
	bra		TFT_max_depth_metric		; 0 - use metric   version
TFT_max_depth_imperial:					; 1 - use imperial version
	call	convert_mbar_to_feet		; convert value in hi:lo from mbar to feet
	output_16_3
	bra		TFT_max_depth_exit
TFT_max_depth_metric:
	btfss	max_depth_greater_100m		; depth to show > 100 m ?
	bra		TFT_max_depth_metric0		; NO  - show meters and decimeters
	bsf		ignore_digit4				; YES - show full meters only, i.e. ignore digits 4 and 5
	bsf		leftbind
	output_16
	bra		TFT_max_depth_exit
TFT_max_depth_metric0:
	movff	hi,sub_b+1					; copy hi to sub_b+1, will also be used to back-up hi
	movff	lo,sub_b+0					; copy lo to sub_b+0, will also be used to back-up lo

	movlw	HIGH d'999'
	movwf	sub_a+1
	movlw	LOW  d'999'
	movwf	sub_a+0
	call	sub16						; sub_c = sub_a - sub_b
	movlw	' '
	btfss	neg_flag					; depth lower than 10m ?
	movwf	POSTINC2					; YES - add extra space

	clrf	sub_a+1
	movlw	d'99'
	movwf	sub_a+0
	call	subU16						; sub_c = sub_a - sub_b
	btfss	neg_flag					; depth lower than 1m ?
	bra		TFT_max_depth_metric1		; YES - manually display a zero
	bsf		ignore_digit4				; NO  - no 0.1 m
	bsf		leftbind					;     - align left
	output_16							;     - display full meters
	bra		TFT_max_depth_metric2
TFT_max_depth_metric1:
	STRCAT	"0"							; display a zero
TFT_max_depth_metric2:
	STRCAT_PRINT ""
	; .1 m in SMALL font
	WIN_SMALL dm_max_depth_dm_column_nvsi, dm_max_depth_dm_row
	TSTOSS	opt_vsigraph				; graphical VSI bar enabled?
	bra		TFT_max_depth_metric3		; NO
	WIN_SMALL dm_max_depth_dm_column, dm_max_depth_dm_row ; YES - adopt position
TFT_max_depth_metric3:
	movff	sub_b+1,hi					; restore hi
	movff	sub_b+0,lo					; restore lo
	PUTC	"."							; print decimal point
	movlw	d'4'
	movwf	ignore_digits
	bsf		ignore_digit5				; no 0.01 m, flag will be cleared by output_16
	bsf		leftbind
	output_16dp d'0'
TFT_max_depth_exit:
	STRCAT_PRINT ""
	bcf		leftbind
	goto	TFT_standard_color			; and return...

;=============================================================================

	global	TFT_divemins
TFT_divemins:
	bcf		FLAG_TFT_divemins		; clear flag
	movff	divemins+0,lo
	movff	divemins+1,hi

	; Already showing divemins > 99min
	btfsc	no_more_divesecs		; ignore seconds?
	bra		TFT_divemins2			; show minutes only

	tstfsz	hi						; hi = 0?
	bra		TFT_divemins_clr		; NO - show mins only

	movlw	.99
	cpfsgt	lo						; bigger than 99?
	bra		TFT_divemins1			; NO - show mins:secs

TFT_divemins_clr:
									; YES - remove second display for the rest of the dive and clear seconds
	bsf		no_more_divesecs		;     - set flag
									;     - clear rest of seconds
	WIN_BOX_BLACK dm_divetime_row, dm_divetime_bot, dm_divetime_column, dm_divetime_rgt ;top, bottom, left, right
	bra		TFT_divemins2			;     - show minutes only

TFT_divemins1:
	; Print out the minutes, up to 99 minutes, only 2 chars!
	call	TFT_memo_color
	WIN_MEDIUM dm_divetime_column, dm_divetime_row
	output_99						; displays only last two figures from a 8 bit value (0-99)
	STRCAT_PRINT ""					; show minutes in large font

	; Print out the seconds
	WIN_SMALL dm_divetime_secs_column, dm_divetime_secs_row ; left position for two sec figures
	PUTC	':'
	movff	divesecs,lo
	bsf		leftbind
	output_99x						; displays only last two figures from a 8 bit value with leading zero (00-99) 
	bra		TFT_divemins_exit		; and return...

TFT_divemins2:
	; Full minutes only
	call	TFT_memo_color
	WIN_MEDIUM	dm_divetime_minsonly_column, dm_divetime_row
	bcf		leftbind
	output_16_4
	bra		TFT_divemins_exit		; and return...


	global	TFT_divemins_alternative
TFT_divemins_alternative:
	bcf		FLAG_TFT_divemins		; clear flag
	call	TFT_memo_color
	; Print out the minutes (0-999) in large
	WIN_LARGE dm_divetime_alt_column, dm_divetime_alt_row
	movff	divemins+0,lo
	movff	divemins+1,hi
	output_16_3						; limit to 999 and display only (0-999)
	STRCAT_PRINT ""					; show minutes
	; Print out the seconds in medium
	WIN_MEDIUM	dm_divetime_alt_column+.60, dm_divetime_alt_row+.25
	PUTC	":"
	movff	divesecs,lo
	bsf		leftbind
	output_99x						; displays only last two figures from a 8Bit value with leading zero (00-99) 
TFT_divemins_exit:
	STRCAT_PRINT ""
	bcf		leftbind
	goto	TFT_standard_color		; and return...

;=============================================================================

	global	TFT_display_apnoe_surface
TFT_display_apnoe_surface:
	btfsc	menuview					; is the options menu shown?
	bra		TFT_display_apnoe_surface_1	; YES - skip title
	call	TFT_divemask_color
	WIN_TINY dm_apnoe_surface_time_text_col, dm_apnoe_surface_time_text_row
	STRCPY_TEXT_PRINT tApnoeSurface
TFT_display_apnoe_surface_1:
	call	TFT_memo_color
	WIN_MEDIUM dm_apnoe_surface_time_column, dm_apnoe_surface_time_row
	movff	apnoe_surface_mins,lo
	output_8
	PUTC	':'
	movff	apnoe_surface_secs,lo
	output_99x
	bra		TFT_display_apnoe_exit	; and return...


	global	TFT_display_apnoe_last_max
TFT_display_apnoe_last_max:
	call	TFT_divemask_color
	WIN_TINY dm_apnoe_last_max_depth_text_col, dm_apnoe_last_max_depth_text_row
	STRCPY_TEXT_PRINT tApnoeMax
	call	TFT_memo_color
	SAFE_2BYTE_COPY max_pressure, lo
	call	adjust_depth_with_salinity	; computes salinity setting into lo:hi [mbar]
	TSTOSS	opt_units					; 0=m, 1=ft
	bra		TFT_display_apnoe_last_m_metric
TFT_display_apnoe_last_max_imp:
	call	convert_mbar_to_feet		; convert value in hi:lo from mbar to feet
	WIN_MEDIUM	dm_apnoe_last_max_depth_column, dm_apnoe_last_max_depth_row
	output_16
	bra		TFT_max_depth_exit
TFT_display_apnoe_last_m_metric:
	WIN_MEDIUM dm_apnoe_last_max_depth_column, dm_apnoe_last_max_depth_row
	bsf		ignore_digit5				; do not display 1cm depth (flag will be cleared by output_16)
	output_16dp d'3'
	bra		TFT_max_depth_exit


	global	TFT_display_apnoe_descent
TFT_display_apnoe_descent:			; descent divetime
	movff	apnoe_mins,lo
	clrf	hi
	WIN_MEDIUM	dm_divetime_apnoe_column, dm_divetime_apnoe_row
	output_16_3						; displays only last three figures from a 16Bit value (0-999)
	call	TFT_memo_color
	STRCAT_PRINT ""					; show minutes in large font
	WIN_SMALL	dm_divetime_apnoe_secs_column, dm_divetime_apnoe_secs_row ; left position for two sec figures
	PUTC	':'
	bsf		leftbind
	movff	apnoe_secs,lo
	output_99x
	STRCAT_PRINT ""					; show seconds in small font
	call	TFT_divemask_color
	WIN_TINY dm_total_apnoe_text_column,dm_total_apnoe_text_row
	STRCPY_TEXT_PRINT tApnoeTotal
	call	TFT_memo_color
	movff	divemins,lo
	clrf	hi
	WIN_MEDIUM dm_apnoe_total_divetime_column, dm_apnoe_total_divetime_row
	bcf		leftbind
	output_16_3						; displays only last three figures from a 16Bit value (0-999)
	call	TFT_memo_color
	STRCAT_PRINT ""					; show minutes in large font
	WIN_SMALL	dm_apnoe_total_divetime_secs_col, dm_apnoe_total_divetime_secs_row ; left position for two sec figures
	PUTC	':'
	bsf		leftbind
	movff	divesecs,lo
	output_99x
TFT_display_apnoe_exit:
	STRCAT_PRINT ""
	bcf		leftbind
	goto	TFT_standard_color		; and return...


	global	TFT_apnoe_clear_surface
TFT_apnoe_clear_surface:
	; clear surface timer (TODO: partly wipes out options menu, too)
	WIN_BOX_BLACK dm_apnoe_surface_time_text_row, .239, dm_apnoe_surface_time_text_col, .159 ; top, bottom, left, right
	return


;=============================================================================
; append firmware version to current string, including color-coding

	global	TFT_cat_firmware
TFT_cat_firmware:
	movlw	softwareversion_x
	movwf	lo
	bsf		leftbind
	output_8
	PUTC	'.'
	movlw	softwareversion_y
	movwf	lo
	output_8
	bcf		leftbind
	rcall	check_expiry
	btfss	aux_flag
	return
	bsf		win_invert
	goto	TFT_attention_color

;=============================================================================
; check if firmware is within expiry period, will return aux_flag set if not

check_expiry:						; check if it is time for a firmware update
	bsf		aux_flag				; set firmware as expired by default
	movlw	firmware_expire_year	; start with checking year
	cpfsgt	year					; current year > expiry year ?
	bra		check_expiry_Y			; NO  - continue checks
	return							; YES - expired
check_expiry_Y:
	cpfseq	year					; current year = expiry year ?
	bra		check_expiry_ok			; NO  - must be < then, OK whatever month & day
	movlw	firmware_expire_month	; YES - continue checking month
	cpfsgt	month					; current month > expiry month ?
	bra		check_expiry_M			; NO  - continue checks
	return							; YES - expired
check_expiry_M:
	cpfseq	month					; current month = expiry month ?
	bra		check_expiry_ok			; NO  - must be < then, OK whatever day
	movlw	firmware_expire_day		; YES - continue checking day
	cpfsgt	day						; current day > expiry day ?
	bra		check_expiry_ok			; NO  - must be <= then, OK
	return							; YES - expired
check_expiry_ok:
	bcf		aux_flag
	return

;=============================================================================
; append firmware BETA status to current string, including color-coding

	global	TFT_cat_beta_rel
	global	TFT_cat_beta_release
TFT_cat_beta_release:				; entry point for printing "Release" / "Beta #"
	bsf		aux_flag
	bra		TFT_cat_beta_common
TFT_cat_beta_rel:					; entry point for printing "Rel." / "B. #"
	bcf		aux_flag
TFT_cat_beta_common:
 IFDEF __DEBUG
	STRCAT	"DEBUG"
	goto	TFT_warnings_color
 ELSE
	movlw	softwareversion_beta	; =0: release, =1: beta 1, =2: beta 2, ...
	movwf	lo						; copy to lo
	tstfsz	lo						; release version?
	bra		TFT_cat_beta_1			; NO  - must be beta version then
	btfss	aux_flag				; YES - shall show long version?
	bra		TFT_cat_beta_2			;       NO  - show short version
	rcall	check_expiry			;       YES - check  expiry date
	btfsc	aux_flag				;           - within expiry date?
	bra		TFT_cat_beta_4			;             NO  - give update cue
	STRCAT "Release"				;             YES - print "Release"
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
 ENDIF

;=============================================================================
; For the Information menu: firmware version

	global	info_menu_firmware
info_menu_firmware:
	lfsr	FSR1,tFirmware
	call	strcat_text
	rcall	TFT_cat_firmware
	PUTC	" "
	rcall	TFT_cat_beta_rel
	STRCAT_PRINT ""						; print buffer to screen
	return

;=============================================================================
; For the Information menu: firmware version of the RX processor

 IFDEF _rx_functions
	global	info_menu_firmware_rx
info_menu_firmware_rx:
	lfsr	FSR1,tFirmware_rx
	call	strcat_text
;	bra		TFT_cat_firmware_rx ;(and return)
;TFT_cat_firmware_rx:
	movff	rx_firmware+0,lo
	bsf		leftbind
	output_8
	PUTC	'.'
	movff	rx_firmware+1,lo
	output_8
	bcf		leftbind
	return
 ENDIF

;-----------------------------------------------------------------------------
; For the Information menu: append serial number

	global	info_menu_serial
info_menu_serial:
	lfsr	FSR1,tSerial
	call	strcat_text
	global	TFT_cat_serial
TFT_cat_serial:
	clrf	EEADRH
	clrf	EEADR					; get serial number LOW
	call	read_eeprom				; read byte
	movff	EEDATA,lo
	incf	EEADR,F					; get serial number HIGH
	call	read_eeprom				; read byte
	movff	EEDATA,hi

	bsf		leftbind
	output_16
	bcf		leftbind
	return

;-----------------------------------------------------------------------------
; For the Information menu: append total dives

	global	info_menu_total_dives
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

; For the Information menu: append battery voltage
	global	info_menu_battery_volts
info_menu_battery_volts:
	lfsr	FSR1,tBatteryV
	call	strcat_text
	movff	batt_voltage+1,hi
	movff	batt_voltage+0,lo
	bsf		leftbind
	output_16dp .2				; x.xxx
	STRCAT	"V(T"
	movff	battery_type,lo		; =0:1.5V, =1:3.6V Saft, =2:LiIon 3.7V/0.8Ah, =3:LiIon 3.7V/3.1Ah, =4: LiIon 3.7V/2.3Ah
	output_8
	bcf		leftbind
	PUTC	")"
	return

	; For the Information menu: append uptime
	global	info_menu_uptime
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
	movwf	xB+1			; one day = 3600s
	call	div32x16		; xC:4 / xB:2 = xC+3:xC+2 with xC+1:xC+0 as remainder
	;xC+0:xC+1 -> Full hours
	movff	xC+1,xA+1
	movff	xC+0,xA+0
	clrf	xB+1
	movlw	.24
	movwf	xB+0
	call	div16x16		; xC = xA / xB with xA as remainder
	movff	xC+0,lo
	movff	xC+1,hi			; full days
	bsf		leftbind
	output_16
	PUTC	"d"
	movff	xA+0,lo			; full hours
	output_8
	PUTC	"h"
	bcf		leftbind
	return					; done


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
menu_cal_common:
	call	strcat_text
	movff	POSTINC0,lo
	movff	POSTINC0,hi
	call	TFT_convert_signed_16bit	; converts lo:hi into signed-short and adds '-' to POSTINC2 if required
	bsf		leftbind
	output_16
	bcf		leftbind
	return


;-----------------------------------------------------------------------------
; ppO2 menu

	global	divesets_ppo2_min
divesets_ppo2_min:
	lfsr	FSR1,tPPO2MIN
	call	strcat_text
	movff	char_I_ppO2_min,lo
	movlw	ppo2_warning_low_default
	bra		divesets_ppo2_common

	global	divesets_ppo2_min_cc
divesets_ppo2_min_cc:
	lfsr	FSR1,tPPO2MINCC
	call	strcat_text
	movff	char_I_ppO2_min_loop,lo
	movlw	ppo2_warning_loop_default
	bra		divesets_ppo2_common

	global	divesets_ppo2_max
divesets_ppo2_max:
	lfsr	FSR1,tPPO2Max
	call	strcat_text
	movff	char_I_ppO2_max,lo
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

	global	TFT_clear_warning_text
TFT_clear_warning_text:
	btfss	divemode							; in divemode?
	bra		TFT_clear_warning_text2				; NO - setup for surface mode
	bcf		FLAG_TFT_dive_warning_text_clear	; clear flag
	btfsc	alternative_divelayout
	bra		TFT_clear_warning_text_2nd_row		; in alt. mode, clear only row 2
	WIN_BOX_BLACK dm_warning_row, dm_warning_bot, dm_warning_column, dm_warning_rgt		; top, bottom, left, right
	return
TFT_clear_warning_text2:
	WIN_BOX_BLACK surf_warning1_row, surf_warning2_row+.24, surf_warning1_column, surf_warning1_column+.76	; top, bottom, left, right
	return

	global	TFT_clear_warning_text_2nd_row
TFT_clear_warning_text_2nd_row:
	btfss	divemode							; in divemode?
	bra		TFT_clear_warning_text_2nd_2		; NO - setup for surface mode
	bcf		FLAG_TFT_dive_warning_text_clr2		; clear flag
	WIN_BOX_BLACK dm_warning2_row, dm_warning2_bot, dm_warning2_column, dm_warning2_rgt	; top, bottom, left, right
	return
TFT_clear_warning_text_2nd_2:
	WIN_BOX_BLACK surf_warning2_row, surf_warning2_row+.24, surf_warning2_column, surf_warning2_column+.76	; top, bottom, left, right
	return

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
	rcall	TFT_warning_set_window		; set the row and column for the current message
	tstfsz	WREG						; is there room for the message?
	return								; NO
	call	TFT_memo_color
	STRCPY	"Desat:"
	movff	int_O_desaturation_time+0,lo
	movff	int_O_desaturation_time+1,hi
	call	convert_time				; converts hi:lo in minutes to hours (up:hi) and minutes (lo)
;	bsf		leftbind
	movf	lo,W
	movff	hi,lo
	movwf	hi							; exchange lo and hi...
	output_99x							; hours
	PUTC	':'
	movff	hi,lo						; minutes
	output_99x
;	bcf		leftbind
	movlw	surf_warning_length			; only use surface string length
	rcall	TFT_fillup_with_spaces		; fill up FSR2 with spaces (total string length in #WREG)
;	movlw	.0							; not needed
;	movff	WREG,buffer+11				; not needed
	STRCAT_PRINT ""
	return


	global	TFT_nofly_time
TFT_nofly_time:
	rcall	TFT_warning_set_window		; set the row and column for the current message
	tstfsz	WREG						; is there room for the message?
	return								; NO
	call	TFT_memo_color
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
	call	convert_time				; converts hi:lo in minutes to hours (up:hi) and minutes (lo)
;	bsf		leftbind
	movf	lo,W
	movff	hi,lo
	movwf	hi							; exchange lo and hi...
	output_99x							; hours
	PUTC	':'
	movff	hi,lo						; minutes
	output_99x
;	bcf		leftbind
	movlw	surf_warning_length			; only use surface string length
	rcall	TFT_fillup_with_spaces		; fill up FSR2 with spaces (total string length in #WREG)
;	movlw	.0							; not needed
;	movff	WREG,buffer+11				; not needed
	STRCAT_PRINT ""
	return

;=============================================================================

	global	TFT_warning_agf
TFT_warning_agf:
	rcall	TFT_warning_set_window		; set the row and column for the current message
	tstfsz	WREG						; is there room for the message?
	return								; NO
	call	TFT_attention_color
	STRCPY_TEXT tDiveaGF_active			; "aGF!"
	movlw	dm_warning_length			; divemode string length
	rcall	TFT_fillup_with_spaces		; fill up FSR2 with spaces (total string length in #WREG)
	STRCAT_PRINT ""
	bra		TFT_warn_att_info_exit		; and return...


	global	TFT_warning_fallback
TFT_warning_fallback:					; show fallback warning
	rcall	TFT_warning_set_window		; set the row and column for the current message
	tstfsz	WREG						; is there room for the message?
	return								; NO
	call	TFT_warnings_color
	STRCPY_TEXT tDiveFallback			; "Fallback!"
	movlw	dm_warning_length			; divemode string length
	rcall	TFT_fillup_with_spaces		; fill up FSR2 with spaces (total string length in #WREG)
	STRCAT_PRINT ""
	bra		TFT_warn_att_info_exit		; and return...


 IFDEF _rx_functions

	global	TFT_advice_switch
TFT_advice_switch:
	rcall	TFT_warning_set_window		; set the row and column for the current message
	tstfsz	WREG						; is there room for the message?
	return								; NO
	call	TFT_advice_color
	STRCPY_TEXT tswap					; "Swap Tank"
	movlw	dm_warning_length			; divemode string length
	rcall	TFT_fillup_with_spaces		; fill up FSR2 with spaces (total string length in #WREG)
	STRCAT_PRINT ""
	bra		TFT_warn_att_info_exit		; and return...

	global	TFT_attention_transmitter
TFT_attention_transmitter:
	rcall	TFT_warning_set_window		; set the row and column for the current message
	tstfsz	WREG						; is there room for the message?
	return								; NO
	call	TFT_attention_color
	STRCPY_TEXT tTransmitter			; "P.Transm."
	movlw	dm_warning_length			; divemode string length
	rcall	TFT_fillup_with_spaces		; fill up FSR2 with spaces (total string length in #WREG)
	STRCAT_PRINT ""
	bra		TFT_warn_att_info_exit		; and return...

	global	TFT_attention_pres_reading
	global	TFT_warning_pres_reading
TFT_attention_pres_reading:				; entry point for attention
	call	TFT_attention_color			; use attention color
	bra		TFT_common_pres_reading		; continue with common code
TFT_warning_pres_reading:				; entry point for warning
	call	TFT_warnings_color			; use warnings color
	;bra	TFT_common_pres_reading		; continue with common code
TFT_common_pres_reading:
	rcall	TFT_warning_set_window		; set the row and column for the current message
	tstfsz	WREG						; is there room for the message?
	return								; NO - done
	STRCPY_TEXT tPressure				; "Tank Pres"
	movlw	dm_warning_length			; divemode string length
	rcall	TFT_fillup_with_spaces		; fill up FSR2 with spaces (total string length in #WREG)
	STRCAT_PRINT ""
	bra		TFT_warn_att_info_exit		; and return...

	global	TFT_attention_sac
TFT_attention_sac:
	rcall	TFT_warning_set_window		; set the row and column for the current message
	tstfsz	WREG						; is there room for the message?
	return								; NO
	movff	int_O_sac_rate+0,lo			; copy SAC rate to hi:lo
	movff	int_O_sac_rate+1,hi			; ...
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

 ENDIF


	global	TFT_info_deco
TFT_info_deco							; show info when decompression obligation is decreasing
	rcall	TFT_warning_set_window		; sets the row and column for the current message
	tstfsz	WREG						; is there room for the message?
	return								; NO  - return
	call	TFT_advice_color			;       actually it is a memo, but we break the rules here and display in advice color (green)
	STRCPY_TEXT tDecoInfo				;       write "Deco Zone"
	movlw	dm_warning_length			;       select divemode string length
	rcall	TFT_fillup_with_spaces		;       fill up FSR2 with spaces (total string length in #WREG)
	STRCAT_PRINT ""						;       print buffer
	bra		TFT_warn_att_info_exit		; and return...


 IFDEF _cave_mode

	global	TFT_info_cave_mode
TFT_info_cave_mode:
	rcall	TFT_warning_set_window		; sets the row and column for the current warning
	tstfsz	WREG						; is there room for the message?
	return								; NO  - return
	call	TFT_memo_color				; YES - set memo color
	STRCPY_TEXT tCaveMode				;       write "Cave Mode"
	movlw	dm_warning_length			;       select divemode string length
	rcall	TFT_fillup_with_spaces		;       fill up FSR2 with spaces (total string length in #WREG)
	STRCAT_PRINT ""						;       print buffer
	bra		TFT_warn_att_info_exit		; and return...

	global	TFT_info_dive_turned
TFT_info_dive_turned:
	rcall	TFT_warning_set_window		; sets the row and column for the current warning
	tstfsz	WREG						; is there room for the message?
	return								; NO  - return
	call	TFT_attention_color			; YES - set attention color
	STRCPY_TEXT tDiveTurned				;       write "Dv.turned"
	movlw	dm_warning_length			;       select divemode string length
	rcall	TFT_fillup_with_spaces		;       fill up FSR2 with spaces (total string length in #WREG)
	STRCAT_PRINT ""						;       print buffer
	bra		TFT_warn_att_info_exit		; and return...

	global	TFT_warn_cave_shutdown
TFT_warn_cave_shutdown:
	rcall	TFT_warning_set_window		; sets the row and column for the current warning
	tstfsz	WREG						; is there room for the message?
	return								; NO  - return
	call	TFT_warnings_color			; YES - set warning color
	STRCPY_TEXT tCaveModeShutdown		;       write "X-Cave-X"
	movlw	dm_warning_length			;       select divemode string length
	rcall	TFT_fillup_with_spaces		;       fill up FSR2 with spaces (total string length in #WREG)
	STRCAT_PRINT ""						;       print buffer
	bra		TFT_warn_att_info_exit		; and return...

 ENDIF


	global	TFT_warning_gf
TFT_warning_gf:							; GF
	rcall	TFT_warning_set_window		; set the row and column for the current message
	tstfsz	WREG						; is there room for the message?
	return								; NO
	movff	int_O_gradient_factor+0,lo	; bank-safe copy gradient factor
	movff	int_O_gradient_factor+1,hi	;
	call	TFT_color_code_gf			; color-code output
	STRCPY	"GF:  "						; the two spaces are on purpose to align the output with other warnings' outputs
	bsf		leftbind
	output_8							; print value of lo only, int_O_gradient_factor is limited to 255
	PUTC	"%"
	movlw	dm_warning_length			; divemode string length
	btfss	divemode					; in divemode?
	movlw	surf_warning_length			; NO - use surface string length
	rcall	TFT_fillup_with_spaces		; fill up FSR2 with spaces (total string length in #WREG)
	STRCAT_PRINT ""
	bcf		leftbind
	bcf		win_invert
TFT_warn_att_info_exit:
	goto	TFT_standard_color			; and return...


	global	TFT_warning_mbubbles
TFT_warning_mbubbles:
	rcall	TFT_warning_set_window		; sets the row and column for the current warning
	tstfsz	WREG						; is there room for the message?
	return								; NO
	call	TFT_attention_color			; set attention color as default
	movff	char_O_deco_warnings,WREG	; bank-safe copy for deco warnings
	btfsc	WREG,mbubble_warning		; are we in the microbubbles zone right now?
	call	TFT_warnings_color			; YES - reconfigure to warning color
	STRCPY_TEXT tMicroBubbles
	movlw	dm_warning_length			; divemode string length
	btfss	divemode					; in divemode?
	movlw	surf_warning_length			; NO  - use surface string length
	rcall	TFT_fillup_with_spaces		; fill up FSR2 with spaces (total string length in #WREG)
	STRCAT_PRINT ""
	bra		TFT_warn_att_info_exit		; and return...


	global	TFT_warning_outside
TFT_warning_outside:
	rcall	TFT_warning_set_window		; sets the row and column for the current warning
	tstfsz	WREG						; is there room for the message?
	return								; NO
	call	TFT_attention_color
	movff	char_O_deco_warnings,WREG	; bank-safe copy for deco warnings
	btfsc	WREG,outside_warning		; are we outside the ZH-L16 model right now?
	call	TFT_warnings_color			; YES - reconfigure to warning color
	STRCPY	"X-ZHL16-X"
	movlw	dm_warning_length			; divemode string length
	btfss	divemode					; in divemode?
	movlw	surf_warning_length			; NO  - use surface string length
	rcall	TFT_fillup_with_spaces		; fill up FSR2 with spaces (total string length in #WREG)
	STRCAT_PRINT ""
	bra		TFT_warn_att_info_exit		; and return...


	global	TFT_warning_gas_needs_warn
	global	TFT_warning_gas_needs_att
TFT_warning_gas_needs_warn:
	rcall	TFT_warning_gas_needs_war_helper
	rcall	TFT_warning_set_window		; set the row and column for the current message
	tstfsz	WREG						; is there room for the message?
	return								; NO
	call	TFT_warnings_color
	bra		TFT_warning_gas_needs_com
TFT_warning_gas_needs_att:
	rcall	TFT_warning_gas_needs_att_helper
	rcall	TFT_warning_set_window		; set the row and column for the current message
	tstfsz	WREG						; is there room for the message?
	return								; NO
	call	TFT_attention_color
TFT_warning_gas_needs_com:
	STRCPY_TEXT tGasNeedsWarn			; "Gas Needs"
	movlw	dm_warning_length			; divemode string length
	rcall	TFT_fillup_with_spaces		; fill up FSR2 with spaces (total string length in #WREG)
	STRCAT_PRINT ""
	bra		TFT_warn_att_info_exit		; and return...

TFT_warning_gas_needs_war_helper:
	incf	message_counter,F			; increase counter
	btfsc	gas_needs_warning			; is it a new warning?
	return								; NO  - do not show the gas needs custom view again
	bsf		gas_needs_warning			; YES - memorize it's an old now
	bra		TFT_warning_gas_needs_helper_com
TFT_warning_gas_needs_att_helper:
	incf	message_counter,F			; increase counter
	btfsc	gas_needs_attention			; is it a new attention?
	return								; NO  - do not show the gas needs custom view again
	bsf		gas_needs_attention			; YES - memorize it's an old now
TFT_warning_gas_needs_helper_com:
	btfsc	alternative_divelayout		; in alternative layout?
	call	switch_layout_to_normal		; YES - switch to normal layout
	movlw	index_gas_needs_ascent-1	; custom view number one below gas needs view
	movwf	menupos3					; set custom view number
	bsf		toggle_customview			; initiate toggle to desired custom view -> gas needs view will be shown
	return


	global	TFT_warning_IBCD
TFT_warning_IBCD:
	rcall	TFT_warning_set_window		; set the row and column for the current message
	tstfsz	WREG						; is there room for the message?
	return								; NO
	call	TFT_attention_color			; select attention color as default
	STRCPY_TEXT tIBCD					; "IBCD N2He"
	movlw	dm_warning_length			; divemode string length
	rcall	TFT_fillup_with_spaces		; fill up FSR2 with spaces (total string length in #WREG)
	STRCAT_PRINT ""
	bra		TFT_warn_att_info_exit		; and return...


	global	TFT_warning_no_BO_gas
TFT_warning_no_BO_gas:
	rcall	TFT_warning_set_window		; set the row and column for the current message
	tstfsz	WREG						; is there room for the message?
	return								; NO
	call	TFT_attention_color			; select attention color as default
	STRCPY_TEXT tnoBOgas				; "B/O Gas X"
	movlw	dm_warning_length			; divemode string length
	rcall	TFT_fillup_with_spaces		; fill up FSR2 with spaces (total string length in #WREG)
	STRCAT_PRINT ""
	bra		TFT_warn_att_info_exit		; and return...


	global	TFT_advice_gas_change
TFT_advice_gas_change:
	rcall	TFT_warning_set_window		; set the row and column for the current message
	tstfsz	WREG						; is there room for the message?
	return								; NO
	call	TFT_advice_color			; set advice color
	STRCPY_TEXT tgaschange				; "Change?"
	movlw	dm_warning_length			; divemode string length
	rcall	TFT_fillup_with_spaces		; fill up FSR2 with spaces (total string length in #WREG)
	STRCAT_PRINT ""
	bra		TFT_warn_att_info_exit		; and return...


	global	TFT_warning_sensor_disagree
TFT_warning_sensor_disagree:			; show sensor disagree warning
	rcall	TFT_warning_sensor_dis_helper
	rcall	TFT_warning_set_window		; set the row and column for the current message
	tstfsz	WREG						; is there room for the message?
	return								; NO
	call	TFT_warnings_color
	STRCPY_TEXT tSensorDisagree			; "Sensors<>"
	movlw	dm_warning_length			; divemode string length
	rcall	TFT_fillup_with_spaces		; fill up FSR2 with spaces (total string length in #WREG)
	STRCAT_PRINT ""
	bra		TFT_warn_att_info_exit		; and return...

TFT_warning_sensor_dis_helper:
	btfsc	sensor_warning				; is it a new warning?
	return								; NO  - do not show the gas needs custom view again
	bsf		sensor_warning				; YES - memorize it's an old warning now
	btfsc	alternative_divelayout		; in alternative layout?
	call	switch_layout_to_normal		; YES - switch to normal layout
	movlw	index_ppo2_sensors-1		; custom view number one below ppO2 sensors
	movwf	menupos3					; set custom view number
	bsf		toggle_customview			; initiate toggle to desired custom view -> ppO2 sensors
	return

;=============================================================================

TFT_warning_set_window:					; set the row and column for the current message
	; ignore warning (now)?
	decf	message_counter,W			; -1
	bcf		STATUS,C
	btfss	alternative_divelayout		; in alternative layout, do not divide...
	rrcf	WREG,W						; (message_counter-1)/2
	cpfseq	message_page
	retlw	.255						; WREG <> 0 -> Warning window not defined
	btfss	divemode					; in divemode?
	bra		TFT_warning_set_window3		; NO - setup for surface mode
	btfss	alternative_divelayout
	bra		TFT_warning_set_window3a	; standard layout
	bra		TFT_warning_set_window2a	; alternative layout (Only lower row used)
TFT_warning_set_window3a:
	btfss	message_counter,0			; toggle with each warning
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
	btfss	message_counter,0			; toggle with each warning
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
	rcall	TFT_warning_set_window		; set the row and column for the current message
	tstfsz	WREG						; is there room for the message?
	return								; NO
	movff	batt_percent,lo				; get battery percent
	call	TFT_color_code_battery		; color-code battery percent
	STRCPY	"Batt:"
	bsf		leftbind
	output_8
	bcf		leftbind
	PUTC	"%"
	movlw	dm_warning_length			; divemode string length
	btfss	divemode					; in divemode?
	movlw	surf_warning_length			; NO - use surface string length
	rcall	TFT_fillup_with_spaces		; fill up FSR2 with spaces (total string length in #WREG)
	STRCAT_PRINT ""
	bcf		win_invert
	bra		TFT_custview_exit1			; and return...


	global	TFT_gf_factors_mask			; mask for GF factors
TFT_gf_factors_mask:
	call	TFT_divemask_color
	WIN_TINY dm_custom_gf_column1+.4, dm_custom_gf_title_row
	STRCPY_TEXT_PRINT tGFactors
	WIN_TINY dm_custom_gf_column2+.2, dm_custom_gf_title_row
	STRCPY_TEXT_PRINT taGFactors
	WIN_TINY dm_custom_gf_column3-.3, dm_custom_gf_title_row
	STRCPY_TEXT_PRINT tGFInfo
	; Show GF (Static)
	call	TFT_disabled_color
	btfss	use_agf
	call	TFT_memo_color
	WIN_STD	dm_custom_gf_column1, dm_custom_gf_row
	bsf		leftbind
	movff	opt_GF_low,lo
	output_8
	PUTC	"/"
	movff	opt_GF_high,lo
	output_8
	STRCAT_PRINT ""
	; Show aGF (Static)
	call	TFT_memo_color
	TSTOSS	opt_enable_aGF				; =1: aGF can be selected underwater
	bra		TFT_gf_mask2				; show "---" instead
	btfss	use_agf
	call	TFT_disabled_color
	WIN_STD	dm_custom_gf_column2, dm_custom_gf_row
	movff	opt_aGF_low,lo
	output_8
	PUTC	"/"
	movff	opt_aGF_high,lo
	output_8
	STRCAT_PRINT ""
	bra		TFT_custview_exit1			; and return...
TFT_gf_mask2:
	WIN_STD	dm_custom_gf_column2+.10, dm_custom_gf_row
	STRCPY_PRINT "---"
	bra		TFT_custview_exit1			; and return...


	global	TFT_ceiling_GF_tissue_mask	; mask for ceiling, current GF and tissues
TFT_ceiling_GF_tissue_mask:
	call	TFT_divemask_color
	WIN_TINY dm_custom_ceiling_column+.2,dm_custom_ceiling_title_row
	STRCPY_TEXT_PRINT tCeiling
	WIN_TINY dm_custom_tissue_title_column, dm_custom_tissue_title_row
	STRCPY_TEXT_PRINT tDiveTissues
; collides with ceiling output and not really needed, too
;	WIN_TINY dm_custom_tissue_N2_column, dm_custom_tissue_N2_row
;	STRCPY_TEXT_PRINT tN2
;	WIN_TINY dm_custom_tissue_He_column, dm_custom_tissue_He_row
;	STRCPY_TEXT_PRINT tHe
	TSTOSS	char_I_deco_model			; in GF mode (0 = ZH-L16, 1 = ZH-L16-GF)?
	bra		TFT_custview_exit1			; NO - no GF info in none-GF mode
	WIN_TINY dm_custom_gf_column1, dm_custom_gf_title_row
	STRCPY_TEXT_PRINT tGFInfo
	bra		TFT_custview_exit1			; and return...


	global	TFT_ceiling_GF_tissue		; data for ceiling, current GF and tissues
TFT_ceiling_GF_tissue:
	WIN_MEDIUM dm_custom_ceiling_column,dm_custom_ceiling_row
	movff	int_O_ceiling+0,lo
	movff	int_O_ceiling+1,hi
	call	TFT_color_code_ceiling		; color-code the output
	call	adjust_depth_with_salinity	; computes salinity setting into lo:hi [mbar]
	bsf		leftbind
	TSTOSS	opt_units					; 0=m, 1=ft
	bra		TFT_ceiling_tissue_cGF_m
	call	convert_mbar_to_feet		; convert value in hi:lo from mbar to feet
	output_16							; yxz
	bra		TFT_ceiling_tissue_cGF0
TFT_ceiling_tissue_cGF_m:
	bsf		ignore_digit5				; no cm (flag will be cleared by output_16)
	output_16dp .3						; yxz.a
TFT_ceiling_tissue_cGF0:
	bcf		leftbind
	STRCAT_PRINT " "
	; Show tissue diagram
	call	DISP_tissue_saturation_graph; show char_O_tissue_N2_saturation and char_O_tissue_He_saturation
	; Show current GF
	TSTOSS	char_I_deco_model			; 0 = ZH-L16, 1 = ZH-L16-GF
	bra		TFT_custview_exit1			; no GF info for none-GF mode
	WIN_MEDIUM dm_custom_clock_column+.3, dm_custom_gf_row
	movff	int_O_gradient_factor+0,lo	; gradient factor absolute, 100% = on M-line of straight Buhlmann
	movff	int_O_gradient_factor+1,hi	; hi byte holds flags
	call	TFT_color_code_gf			; color-code output
	output_8							; need to print lo only, int_O_gradient_factor value is limited to 255
	STRCAT_PRINT ""
	WIN_STD	dm_custom_clock_column+.40, dm_custom_gf_row+.5
	STRCAT_PRINT "%"					; % is printed in color set by TFT_color_code_gf, too
	bra		TFT_custview_exit1			; and return...


	global	TFT_gf_factors				; data for GF factors
TFT_gf_factors:
	WIN_STD	dm_custom_gf_column3, dm_custom_gf_row
	movff	int_O_gradient_factor+0,lo	; gradient factor absolute (Non-GF model)
	movff	int_O_gradient_factor+1,hi
	call	TFT_color_code_gf			; color-code output
	output_8							; print lo only, int_O_gradient_factor is limited to 255
	STRCAT_PRINT "%"
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
	; Show Surface Pressure (done in mask, because it's static during the dive)
	call	TFT_standard_color
	WIN_SMALL dm_custom_surfpres_column, dm_custom_surfpres_row
	movff	last_surfpressure_30min+0,lo
	movff	last_surfpressure_30min+1,hi
	output_16
	PUTC	' '
	STRCAT_TEXT_PRINT tMBAR				; mbar (hPa)
	bra		TFT_custview_exit1			; and return...


	global	TFT_clock_batt_surfpress	; data for clock, battery and surface pressure
TFT_clock_batt_surfpress:
	; Update Clock
	WIN_SMALL dm_custom_clock_column, dm_custom_clock_row
	call	TFT_standard_color
	movff	hours,lo
	output_99
	PUTC	':'
	movff	mins,lo
	output_99x
	PUTC	":"
	movff	secs,lo
	output_99x
	STRCAT_PRINT ""
	; Show Battery Info
	WIN_SMALL dm_custom_battery_column, dm_custom_battery_percent_row
	movff	batt_percent,lo				; get battery percent
	call	TFT_color_code_battery		; color-code battery percent
;	bsf		leftbind
	output_8
;	bcf		leftbind
	STRCAT	"% "
	movlw	0x00
	movff	WREG,buffer+4				; only "xxx%"
	STRCAT_PRINT ""
	bcf		win_invert
	call	TFT_memo_color
	WIN_SMALL dm_custom_battery_column, dm_custom_battery_volt_row
	movff	batt_voltage+0,lo
	movff	batt_voltage+1,hi
	bsf		leftbind
	output_16dp	.2
	PUTC	'V'
	movff	buffer+5,buffer+4
	movlw	0x00
	movff	WREG,buffer+5				; only "x.yzV"
	STRCAT_PRINT ""
	; Surface pressure is shown in mask because it is static
	bra		TFT_custview_exit1			; and return...


	global	TFT_pscr_info_mask			; mask for pSCR info
TFT_pscr_info_mask:
	rcall	TFT_mask_ppo2
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
	movff	int_O_pSCR_ppO2+0,lo		; copy pSCR ppO2 to hi:lo
	movff	int_O_pSCR_ppO2+1,hi
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


	global	TFT_gas_needs_ascent_mask	; mask for gas needs ascent
TFT_gas_needs_ascent_mask:
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
	STRCAT_PRINT " (bar)"				; " (bar)"
	bra		TFT_custview_exit1			; and return...


	global	TFT_gas_needs_ascent		; data for gas needs ascent
TFT_gas_needs_ascent:					; LIMITATION: there is only space for 4 gases on the screen - if 5 gases have a pres_need > 0, then only the first 4 will be shown!
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
	rcall	TFT_gas_needs_ascent_mask	; redraw mask
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
	return

TFT_gas_needs_helper:
	call	TFT_memo_color
	movlw	.5							; number of gases
	cpfslt	up							; check if all gases have been processed
	bra		TFT_gas_needs_helper_1		; YES - clear display area
	movf	up,W						; NO  - get gas number and check if need of that gas is > 0
	rlncf	WREG,W						; multiply by 2
	incf	WREG,W						; add 1 to address high byte
	lfsr	FSR1,int_O_ascent_pres_need	; load base of ascent press needs
	movff	PLUSW1,hi					; read HIGH(int_O_ascent_pres_need[up])
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
	call	customview_show_mix			; print "Air", "O2", "21/35", etc.
	PUTC	':'							; ":"
	movf	up,W						; get gas number (0-4) to WREG
	rlncf	WREG,W						; multiply by 2
	lfsr	FSR1,int_O_ascent_pres_need	; load base of ascent press needs (default)
	movff	PLUSW1,lo					; read LOW(int_O_ascent_pres_need[up])
	incf	WREG,W						; add 1 to address high byte
	movff	PLUSW1,hi					; read HIGH(int_O_ascent_pres_need[up])
	btfsc	hi,int_attention_flag		; check if attention flag is set (pres_need > pres_fill * threshold)
	call	TFT_attention_color			; YES - print gas need in yellow
	btfsc	hi,int_warning_flag			; check if warning   flag is set (pres_need > pres_fill)
	call	TFT_warnings_color			; YES - print gas need in red
	movff	int_O_ascent_pres_need+1,WREG ; get HIGH(int_O_ascent_pres_need[0]) which holds flag for invalid data
	btfsc	WREG,int_invalid_flag		; check if invalid data flag is set
	call	TFT_disabled_color			; YES - print gas need in  disabled  color
	bcf		hi,int_attention_flag		; clear attention flag for attention color
	bcf		hi,int_warning_flag			; clear warning   flag for warning   color
	bcf		hi,int_invalid_flag			; clear flag for invalid data (will actually only be set with 1st gas)
	output_16_3							; limit to 999 and display only (0-999)
	STRCAT_PRINT " "					; adds a space to overwrite any potential remains of earlier outputs
	incf	up,F						; increment to next gas
	bra		TFT_custview_exit2			; and return...


	global	TFT_mask_ppo2				; helper function for several custom views
TFT_mask_ppo2:
	call	TFT_divemask_color
	btfss	FLAG_ccr_mode				; in CCR mode?
	bra		TFT_mask_ppo2a				; NO  - continue checking for pSCR and OC
	btfsc	FLAG_bailout_mode			; in bailout?
	bra		TFT_mask_ppo2b				; YES
	WIN_TINY dm_custom_ppo2_column-.2,dm_custom_ppo2_title_row	; tuned position for longer text (-8 = on leftmost edge of display)
	STRCPY_TEXT_PRINT tppO2Dil			; print "ppO2(Dil)"
	bra		TFT_custview_exit2			; and return...
TFT_mask_ppo2a:
	btfss	FLAG_pscr_mode				; in pSCR mode?
	bra		TFT_mask_ppo2b				; NO  - continue with OC mode (or bailout)
	btfsc	FLAG_bailout_mode			; in bailout?
	bra		TFT_mask_ppo2b				; YES
	WIN_TINY dm_custom_ppo2_column-.2,dm_custom_ppo2_title_row	; tuned position for longer text (-8 = on leftmost edge of display)
	STRCPY_TEXT_PRINT tppO2Mix			; print "ppO2(Mix)"
	bra		TFT_custview_exit2			; and return...
TFT_mask_ppo2b:							; OC mode or bailout
	WIN_TINY dm_custom_ppo2_column-.2, dm_custom_ppo2_title_row	; normal position
	STRCPY_TEXT_PRINT tppO2				; in all other modes
	bra		TFT_custview_exit2			; and return...


	global	TFT_display_pure_ppo2		; show ppO2 of the pure gas - helper function for several custom views
TFT_display_pure_ppo2:
	WIN_MEDIUM dm_custom_ppo2_column, dm_custom_ppo2_row
	movff	int_O_pure_ppO2+0,lo		; copy ppO2 of the pure gas to hi:lo
	movff	int_O_pure_ppO2+1,hi
	call	TFT_color_code_ppo2			; color-code output
	bsf		leftbind
	output_16dp .3						; x.xx bar
	bcf		leftbind
	STRCAT_PRINT ""
	bra		TFT_custview_exit2			; and return...


	global TFT_ppo2_ead_end_cns_mask	; mask for ppO2, END/EAD and CNS
TFT_ppo2_ead_end_cns_mask:
	rcall	TFT_mask_ppo2
	call	TFT_divemask_color
	WIN_TINY dm_custom_ead_column, dm_custom_eadend_title_row
	STRCPY_TEXT_PRINT tDiveEAD_END
	WIN_TINY dm_custom_cns_column, dm_custom_cns_title_row
	STRCPY_TEXT_PRINT tCNS2
	bra		TFT_custview_exit2			; and return...


	global	TFT_ppo2_ead_end_cns		; data for ppO2, END/EAD and CNS
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
	WIN_STD	dm_custom_cns_column+.3, dm_custom_cns_row
	movff	int_O_CNS_fraction+0,lo
	movff	int_O_CNS_fraction+1,hi
	call	TFT_color_code_cns			; color-code CNS output
	bsf		leftbind
	output_16_3							; displays only 0...999
	bcf		leftbind
	STRCAT_PRINT "%"
TFT_custview_exit2:
	goto	TFT_standard_color			; and return...
TFT_end_ead_common:						; print "lo m" (or ft) and limit to 8 chars
	bsf		leftbind
	TSTOSS	opt_units					; 0=Meters, 1=Feets
	bra		TFT_end_ead_common_metric
TFT_end_ead_common_imperial:
	movf	lo,W						; with lo in m
	mullw	.100						; PRODL:PRODH = mbar/min
	movff	PRODL,lo
	movff	PRODH,hi
	call	convert_mbar_to_feet		; convert value in hi:lo from mbar to feet
	output_16_3
	STRCAT_TEXT tFeets
	clrf	WREG
	movff	WREG,buffer+.8				; limit string length to 8
	bra		TFT_end_ead_common_exit
TFT_end_ead_common_metric:
	output_8
	STRCAT_TEXT tMeters
TFT_end_ead_common_exit:
	bcf		leftbind
	movlw	.8
	call	TFT_fillup_with_spaces		; fill up FSR2 with spaces (total string length in #WREG)
	STRCAT_PRINT ""
	return


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
	movff	int_O_O2_ppO2+0,lo			; copy ppO2 of pure O2 to hi:lo
	movff	int_O_O2_ppO2+1,hi
	call	TFT_color_code_ppo2			; color-code output
	bsf		leftbind
	output_16dp .3						; x.xx bar
	bcf		leftbind
	STRCAT_PRINT ""
	; Show ppO2 of the diluent in this depth
	WIN_MEDIUM	dm_custom_ppDil_column, dm_custom_s_check_row
	movff	int_O_pure_ppO2+0,lo		; copy ppO2 of pure gas to hi:lo
	movff	int_O_pure_ppO2+1,hi
	call	TFT_color_code_ppo2			; color-code output
	bsf		leftbind
	output_16dp .3						; x.xx bar
	bcf		leftbind
	STRCAT_PRINT ""
TFT_sensor_check_exit:
	bra		TFT_custview_exit2			; and return...

;=============================================================================

	global	TFT_surface_lastdive
TFT_surface_lastdive:
	call	TFT_standard_color
	WIN_TINY surf_gaslist_column,surf_gaslist_row+.5
	STRCAT_TEXT_PRINT	tLastDive			; "Last Dive:"
	WIN_TINY surf_gaslist_column,surf_gaslist_row+(surf_gaslist_spacing*.1)+.5
	STRCAT_TEXT_PRINT	tDivetime			; "Divetime:"
	WIN_TINY surf_gaslist_column,surf_gaslist_row+(surf_gaslist_spacing*.2)+.5
	STRCAT_TEXT_PRINT	tMaxDepth			; "Max. Depth"

	WIN_SMALL surf_gaslist_column+.48,surf_gaslist_row
	movff	int_O_desaturation_time+0,lo	; bank-safe copies
	movff	int_O_desaturation_time+1,WREG
	iorwf	lo,W							; check if desaturation time is zero
	bz		TFT_surface_lastdive_1			; YES - show last dive time
	movff	surface_interval+0,lo			; NO  - show dive interval
	movff	surface_interval+1,hi
	call	convert_time					; converts hi:lo in minutes to hours (up:hi) and minutes (lo)
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
	movwf	xB+1							; one day = 3600s
	call	div32x16						; xC:4 / xB:2 = xC+3:xC+2 with xC+1:xC+0 as remainder
	;xC+0:xC+1 -> full hours
	movff	xC+1,xA+1
	movff	xC+0,xA+0
	clrf	xB+1
	movlw	.24
	movwf	xB+0
	call	div16x16						; xC = xA / xB with xA as remainder
	movff	xC+0,lo
	movff	xC+1,hi							; full days
	bsf		leftbind
	output_16
	PUTC	"d"
	movff	xA+0,lo							; full hours
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
	rcall	convert_mbar_to_feet			; convert value in hi:lo from mbar to feet
	output_16_3								; limit to 999 and display only (0-999)
	STRCAT_TEXT tFeets1
	bra		TFT_surface_lastdive2

TFT_surface_lastdive_metric:
	bsf		ignore_digit5					; no cm (flag will be cleared by output_16)
	movlw	d'1'							; +1
	movff	WREG,ignore_digits				; no 1000m
	output_16dp .3							; xxx.y
	STRCAT_TEXT tMeters
TFT_surface_lastdive2:
	STRCAT_PRINT ""
	bcf		leftbind
	return									; done.

;=============================================================================

	global	TFT_surface_tissues
TFT_surface_tissues:						; show Tissue diagram in surface mode
	WIN_SMALL surf_tissue_N2_column,surf_tissue_N2_row
	STRCPY_TEXT_PRINT tN2
	WIN_SMALL surf_tissue_He_column,surf_tissue_He_row
	STRCPY_TEXT_PRINT tHe

	movlw	color_deepblue
	call	TFT_set_color					; make this configurable?
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
	movwf	win_height													; row bottom (0-239)

	;---- Draw N2 Tissues ----------------------------------------------------

	movlw	surf_tissue_diagram_left+.4									; start position for N2 bars
	movwf	win_leftx2													; column left (0-159)
	movlw	surf_tissue_diagram_right-surf_tissue_diagram_left-.4		; max width for N2 bars
	movwf	win_width

	lfsr	FSR2, char_O_tissue_N2_saturation
	movlw	d'16'
	movwf	lo															; 16 tissues
	clrf	hi															; row offset
surf_tissue_saturation_graph_N2:
	movlw	surf_tissue_diagram_top+.23									; surface mode
	addwf	hi,W
	movwf	win_top														; row top (0-239)
	rcall	surf_tissue_saturation_loop									; show one tissue
	decfsz	lo,F
	bra		surf_tissue_saturation_graph_N2

	;---- Draw He Tissues ----------------------------------------------------

	movlw	surf_tissue_diagram_left+.24								; start position for He bars (.15 without x2)
	movwf	win_leftx2													; column left (0-159)
	movlw	surf_tissue_diagram_right-surf_tissue_diagram_left-.24		; max width for He bars
	movwf	win_width

	lfsr	FSR2, char_O_tissue_He_saturation
	movlw	d'16'
	movwf	lo															; 16 tissues
	clrf	hi															; row offset
surf_tissue_saturation_graph_He:
	movlw	surf_tissue_diagram_top+.23+.57								; surface mode
	addwf	hi,W
	movwf	win_top														; row top (0-239)
	rcall	surf_tissue_saturation_loop									; show one tissue
	decfsz	lo,F
	bra		surf_tissue_saturation_graph_He

	WIN_SMALL surf_tissue_He_column+.22,surf_tissue_He_row				; position in-between tissue bars
	movff	int_O_CNS_fraction+0,lo
	movff	int_O_CNS_fraction+1,hi
	call	TFT_color_code_cns
	STRCPY_TEXT tCNS2													; CNS:
	bsf		leftbind
	output_16_3															; displays only 0...999
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
	movf	win_width+0,W				; get max window width (win_width)
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
; Draw saturation graph in dive mode

DISP_tissue_saturation_graph:
	;---- Draw Frame
	call	TFT_standard_color
	WIN_FRAME_COLOR16 dm_custom_tissue_diagram_top, dm_custom_tissue_diagram_bottom, dm_custom_tissue_diagram_left, .159 ; outer frame

	;---- clear area showing leading tissue number as it may not be printed over
	WIN_BOX_BLACK dm_custom_tissue_diagram_top+.16, dm_custom_tissue_diagram_top+.16+.10, dm_custom_tissue_diagram_left+.32, dm_custom_tissue_diagram_left+.32+.8 ; top, bottom, left, right

	movlw	.1
	movwf	win_height									; row bottom (0-239)

	;---- Draw N2 Tissues ----------------------------------------------------

	movlw	dm_custom_tissue_diagram_left+.3			; divemode
	movwf	win_leftx2									; column left (0-159)
	movlw	.159-dm_custom_tissue_diagram_left-.4		; width
	movwf	win_width

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

	movlw	dm_custom_tissue_diagram_left+.8			; divemode
	movwf	win_leftx2									; column left (0-159)
	movlw	.159-dm_custom_tissue_diagram_left-.14		; width
	movwf	win_width

	lfsr	FSR2, char_O_tissue_He_saturation
	movlw	d'16'
	movwf	lo											; 16 tissues
	clrf	hi											; row offset
tissue_saturation_graph_He:
	movlw	dm_custom_tissue_diagram_top+.3+.22			; divemode
	rcall	tissue_saturation_graph_loop				; show one tissue
	decfsz	lo,F
	bra		tissue_saturation_graph_He

	;---- Print Number of leading Tissue -------------------------------------

														; TODO: some flicker due to overwriting by tissue bars

	movff	int_O_gradient_factor+0,WREG				; get current gradient factor (only low byte used for value)
	tstfsz	WREG										; current gradient factor = 0 ?
	bra		tissue_saturation_graph_0					; NO  - print number of leading tissue
	movff	char_O_deco_info,WREG						; YES - get deco info vector
	btfss	WREG,deco_ceiling							;     - do we have a ceiling obligation?
	goto	TFT_standard_color							;       NO  - can ascent directly, don't print number, set standard color and return
														;       YES - print number of leading tissue
tissue_saturation_graph_0:
	movff	char_O_lead_number,lo						; get number of leading tissue as 0-15
	incf	lo,F										; adjust to 1-16
	movlw	.10
	cpfsgt	lo											; is it > 10 ?
	bra		tissue_saturation_graph_1					; NO - will output a single digit number
	; start position for a 2 digit number
	WIN_TINY dm_custom_tissue_diagram_left+.32,dm_custom_tissue_diagram_top+.16
	bra		tissue_saturation_graph_2
tissue_saturation_graph_1:
	; start position for a 1 digit number
	WIN_TINY dm_custom_tissue_diagram_left+.32+.4,dm_custom_tissue_diagram_top+.16
tissue_saturation_graph_2:
	call	TFT_standard_color							; set output color
	bsf		leftbind
	output_8											; print number in leftbind, i.e. without leading zeros or spaces
	bcf		leftbind
	STRCAT_PRINT ""										; finalize output
	return

tissue_saturation_graph_loop:
	addwf	hi,W
	movwf	win_top										; row top (0-239)
	movlw	color_cyan									; preset color for tissues with decreasing pressure
	call	TFT_set_color
	incf	hi,F
	movf	POSTINC2,W
	btfss	WREG,7										; check if flag for increasing tissue pressure set
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
	call	TFT_warning_set_window		; set the row and column for the current message
	tstfsz	WREG						; is there room for the message?
	return								; NO
	STRCPY_TEXT tCNS					; CNS:
	movff	int_O_CNS_fraction+0,lo
	movff	int_O_CNS_fraction+1,hi
	call	TFT_color_code_cns			; color-code CNS output
	bsf		leftbind
	output_16_3							; displays only 0...999
	bcf		leftbind
	PUTC	"%"
	movlw	dm_warning_length			; divemode string length
	btfss	divemode					; In divemode?
	movlw	surf_warning_length			; NO - use surface string length
	call	TFT_fillup_with_spaces		; fill up FSR2 with spaces (total string length in #WREG)
	STRCAT_PRINT ""
	bcf		win_invert
	bra		TFT_custview_exit3			; and return...


	global	TFT_display_eod_cns
TFT_display_eod_cns:
	call	TFT_warning_set_window		; set the row and column for the current message
	tstfsz	WREG						; is there room for the message?
	return								; NO
	call	TFT_warnings_color			; switch to warnings (red) text color
	STRCPY_TEXT tCNSeod					; end-of-dive CNS warning text
	movlw	dm_warning_length			; divemode string length
	call	TFT_fillup_with_spaces		; fill up FSR2 with spaces (total string length in #WREG)
	STRCAT_PRINT ""
	bra		TFT_custview_exit3			; and return...


	global	TFT_display_ppo2_warning
TFT_display_ppo2_warning:				; with ppO2 including attention/warning flags in hi:lo
	call	TFT_warning_set_window		; set the row and column for the current message
	tstfsz	WREG						; is there room for the message?
	return								; NO
	call	TFT_color_code_ppo2			; color-code output
	btfsc	FLAG_bailout_mode			; in bailout?
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
	movlw	dm_warning_length			; divemode string length
	call	TFT_fillup_with_spaces		; fill up FSR2 with spaces (total string length in #WREG)
	STRCAT_PRINT ""
TFT_custview_exit3:
	goto	TFT_standard_color			; and return...


	global	TFT_surf_set_bearing
TFT_surf_set_bearing:
	btfsc	premenu
	return								; already shown, return
	bsf		premenu						; set flag
	WIN_BOX_BLACK surf_compass_bear_row,surf_warning1_row-1, surf_compass_bear_column, surf_decotype_column-.1 ; top, bottom, left, right
	WIN_SMALL surf_compass_bear_column,surf_compass_bear_row
	WIN_COLOR color_yellow
	bsf		win_invert
	STRCPY_TEXT_PRINT tSetHeading		; 7 chars
	bcf		win_invert
	return

;=============================================================================

	global	TFT_LogOffset_Logtitle
TFT_LogOffset_Logtitle:
	STRCPY_TEXT tLogOffset
	PUTC	":"
	call	do_logoffset_common_read	; offset into lo:hi
	bsf		leftbind
	output_16_4
	bcf		leftbind
	PUTC	" "
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
	bsf		short_gas_decriptions			; just "Air", "O2" or "xx/yy"
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
	movff	int_IO_pressure_value+3,hi		;
	movff	char_I_pressure_stat+1,ex		;     - copy status data
	bra		TFT_pressures_SAC_2
TFT_pressures_SAC_1:
	movff	int_O_pressure_need+0,lo		; YES - copy need to pressure 1 to hi:lo
	movff	int_O_pressure_need+1,hi		;
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
	movff	int_O_sac_rate+0,lo				; copy SAC rate to hi:lo
	movff	int_O_sac_rate+1,hi
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
	btfsc	ex,char_transmitter_lost		;     - transmitter lost?
	call	TFT_attention_color				;       YES - use attention color
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
	movff	int_IO_pressure_value+0,lo		; copy pressure from 1st reading, low  byte
	movff	int_IO_pressure_value+1,hi		; copy pressure from 1st reading, high byte
	btfss	hi,int_not_avail_flag			; pressure reading 1 available?
	bra		TFT_surface_tank_pres_0			; YES
	movff	int_IO_pressure_value+2,lo		; NO - copy pressure from 2nd reading, low  byte
	movff	int_IO_pressure_value+3,hi		;    - copy pressure from 2nd reading, high byte
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
	call	TFT_standard_color
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
	call	TFT_warnings_color				; output in red
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

 ENDIF

;=============================================================================    

	global	adjust_depth_with_salinity
	global	adjust_depth_with_salinity_log
adjust_depth_with_salinity:			; computes salinity setting into lo:hi [mbar]
	btfsc	simulatormode_active	; do not apply salinity in simulator mode
	return
	movff	opt_salinity,WREG		; 0-5%
adjust_depth_with_salinity_log:		; computes salinity setting (FROM WREG!) into lo:hi [mbar]
	addlw	d'100'					; 1.00kg/l
	movwf	up

	movlw	d'105'					; 105% ?
	cpfslt	up						; salinity upper limit
	return							; out of limit, do not adjust lo:hi
	movlw	d'99'					; 99% ?
	cpfsgt	up						; salinity lower limit
	return							; out of limit, do not adjust lo:hi

	movff	lo,xA+0
	movff	hi,xA+1

	movlw	d'102'					; 0.98 bar / 10 meter
	movwf	xB+0
	clrf	xB+1
	call	mult16x16				; xC:4 = xA:2 * xB:2
	movff	up,xB+0					; salinity
	clrf	xB+1
	call	div32x16				; xC:4 = xC:4 / xB:2 with xA as remainder
	movff	xC+0,lo
	movff	xC+1,hi					; copy corrected values back to lo and hi
	return

;=============================================================================

	global	convert_mbar_to_feet
convert_mbar_to_feet:				; convert value in hi:lo from mbar to feet
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

	global	convert_celsius_to_fahrenheit	; convert value in lo:hi from Celsius to Fahrenheit
convert_celsius_to_fahrenheit:		; convert value in lo:hi from Celsius to Fahrenheit
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