;=============================================================================
;
;   File tft_outputs.asm                    * combined next generation V3.12.3
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
#include "ghostwriter.inc"
#include "customview.inc"
#include "i2c.inc"
#include "calibrate.inc"
#include "gaslist.inc"
#include "rx_ops.inc"
#include "logbook.inc"
#include "external_flash.inc"
#include "colorschemes.inc"


;---- external Functions -----------------------------------------------------

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


;=============================================================================
pallet_table	CODE_PACK 0x09800		; must be at 0x***00
;=============================================================================


pallet_table:
	;	mask			disabled			memo			advice			attention		warning			; pallet
	;	---------------	-------------------	---------------	---------------	---------------	---------------	  --------
	DB	color_green,	color_lightblue,	color_white,	color_green,	color_yellow,	color_red		; standard
	DB	color_red,		color_dark_red,		color_orange,	color_greenish,	color_pink,		color_red		; reddish
	DB	color_cyan,		color_dark_green,	color_green,	color_green,	color_cyan,		color_red		; greenish
	DB	color_blue,		color_deepblue,		color_lightblue,color_greenish,	color_orange,	color_red		; blueish


;=============================================================================
tft_out1	CODE
;=============================================================================


;-----------------------------------------------------------------------------
; load standard Color Pallet
;
	global	TFT_load_std_color_pallet
TFT_load_std_color_pallet:
	clrf	WREG						; select standard pallet
	bra		TFT_load_color_pallet		; load color pallet


;-----------------------------------------------------------------------------
; load Dive Mode Color Pallet
;
	global	TFT_load_dive_color_pallet
TFT_load_dive_color_pallet:
	movff	opt_dive_color_scheme,WREG	; get color scheme selection
	;bra	TFT_load_color_pallet		; load color pallet


	; Helper Function - load color pallet
TFT_load_color_pallet:
	mullw	.6							; 6 bytes per pallet, compute pallet offset

	movf	PRODL,W						; get pallet offset,  low
	movwf	TBLPTRL						; set table pointer,  low

	movlw	HIGH  (pallet_table)		; get start of table, high
	movwf	TBLPTRH						; set table pointer,  high

	movlw	UPPER (pallet_table)		; get start of table, upper
	movwf	TBLPTRU						; set table pointer,  upper

	lfsr	FSR2,pallet_color_mask		; point to first color in pallet
	movlw	.6							; initialize loop counter
TFT_load_color_pallet_loop:
	TBLRD*+								; read color
	movff	TABLAT,POSTINC2				; copy color to pallet
	decfsz	WREG						; decrement loop counter, reached zero?
	bra		TFT_load_color_pallet_loop	; NO  - loop
	return								; YES - done


;=============================================================================
tft_out2	CODE
;=============================================================================


;-----------------------------------------------------------------------------
; Color-Code a Tank Pressure or SAC Rate
;
; Input hi:lo pressure / SAC rate
;
TFT_color_code_pres_sac:
	btfss	hi,int_not_avail_flag		; is the not-available flag set?
	bra		TFT_color_code_tank_pres_1	; NO
	bcf		hi,int_not_avail_flag		; YES - clear not-available flag
TFT_color_code_tank_pres_0:				;     - entry point for outdated flag
	bcf		hi,int_outdated_flag		;     - clear outdated  flag (it may be set)
	bcf		hi,int_warning_flag			;     - clear warning   flag (it may be set)
	bcf		hi,int_attention_flag		;     - clear attention flag (it may be set)
	FONT_COLOR_DISABLED					;     - set to disabled color and return
	return								;     - done

TFT_color_code_tank_pres_1:
	btfsc	hi,int_outdated_flag		; is the outdated flag set?
	bra		TFT_color_code_tank_pres_0	; YES - handle alike with not-available flag
	btfss	hi,int_warning_flag			; NO  - is the warning flag set?
	bra		TFT_color_code_tank_pres_2	;       NO
	bcf		hi,int_attention_flag		;       YES - clear  attention flag (it may be set)
	bcf		hi,int_warning_flag			;           - clear  warning flag
	FONT_COLOR_WARNING					;           - select warning color
	return								;           - done

TFT_color_code_tank_pres_2:
	btfss	hi,int_attention_flag		; is the attention flag set?
	bra		TFT_color_code_tank_pres_3	; NO  - set memo color and return
	bcf		hi,int_attention_flag		; YES - clear attention flag
	FONT_COLOR_ATTENTION				;     - set to attention color
	return								;     - done

TFT_color_code_tank_pres_3:
	FONT_COLOR_MEMO						; set to memo color
	return								; done


;-----------------------------------------------------------------------------
; Color-Code a Gas by its ppO2
;
; Input hi                O2% of the gas
;       pressure_abs_10   current absolute pressure / 10
;
	global	TFT_color_code_gaslist
TFT_color_code_gaslist:
	; check for very high ppO2
	MOVII	pressure_abs_10,xA			; get absolute pressure / 10
	movff	hi,xB+0						; get O2%
	clrf	xB+1						; ...
	call	mult16x16					; hi * absolute pressure / 10
	; check if ppO2 > 6.55 bar
	tstfsz	xC+2						; char_I_O2_ratio * absolute pressure / 10 > 65536, i.e. ppO2 > 6.55 bar ?
	bra		TFT_color_code_gaslist_warn	; YES - set warning color and return

	; check if ppO2 > 3.30 bar
	btfsc	xC+1,7						; ppO2 > 3.30 bar ?
	bra		TFT_color_code_gaslist_warn	; YES - set warning color and return

	; check for low ppO2
	MOVII	xC,sub_a					; get ppO2 of the gas
	movff	char_I_ppO2_min,WREG		; get minimum ppO2
	mullw	d'100'						; compute (minimum ppO2) * 100
	MOVII	PRODL,sub_b					; copy result to sub_b
	call	cmpU16						; compare (sub_a - sub_b)
	btfsc	neg_flag					; lower than ppO2 min?
	bra		TFT_color_code_gaslist_warn	; YES - set warning color and return

	; check for high ppO2
	movff	char_O_deco_info,WREG		; bank-safe copy of deco info vector
	btfsc	WREG,deco_mode				; are we in deco?
	bra		TFT_color_code_gaslist_deco	; YES - check against ppO2 max deco only

	; check for ppO2 max travel/normal
	movff	char_I_ppO2_max_work,WREG	; ppo2 max during working phase
	mullw	d'100'						; char_I_ppO2_max_work*100
	ADDLI	ppO2_margin_on_max,PROD		; add ppO2 margin on max value to compensate for surface pressures > 1000 hPa
	MOVII	PRODL,sub_b					; copy result to sub_b
	call	cmpU16						; compare (sub_a - sub_b)
	btfss	neg_flag					; higher than ppO2 max travel/deco?
	FONT_COLOR_ATTENTION				; YES - set attention color
	;bra	TFT_color_code_gaslist_deco ; continue checking against max deco

	; check for ppO2 max deco
TFT_color_code_gaslist_deco:
	movff	char_I_ppO2_max_deco,WREG	; ppo2 max for deco
	mullw	d'100'						; char_I_ppO2_max_deco * 100
	ADDLI	ppO2_margin_on_max,PROD		; add ppO2 margin on max value to compensate for surface pressures > 1000 hPa
	MOVII	PRODL,sub_b					; copy result to sub_b
	call	cmpU16						; compare (sub_a - sub_b)
	btfsc	neg_flag					; higher than ppO2 max deco?
	return								; NO  - done
	;bra	TFT_color_code_gaslist_warn	; YES - set warning color and return


	; Helper Function - set waring color and return
TFT_color_code_gaslist_warn:
	FONT_COLOR_WARNING					; select warning color
	return								; done


;-----------------------------------------------------------------------------
; Color-Code the Ceiling Depth
;
; Input mpr                      ceiling depth             [mbar]
;       pressure_rel_cur_cached  current relative pressure [mbar]
;
TFT_color_code_ceiling:
	; check for invalid
	btfsc	hi,char_invalid_flag		; is the invalid flag set? (bit 7 here)
	bra		TFT_color_code_ceiling_dis	; YES - set to disabled color and return

	; check for ceiling
	MOVII	pressure_rel_cur_cached,sub_a;get current pressure to sub_a
	MOVII	mpr,sub_b					; get ceiling to sub_b
	call	cmpU16						; sub_a - sub_b = relative pressure [mbar] - int_O_ceiling [mbar]
	btfss	neg_flag					; is current depth < ceiling (too shallow) ?
	bra		TFT_color_code_ceiling_memo	; NO  - set to memo color and return

	; check for outside
	movff	char_O_deco_warnings,WREG	; bank-safe copy of deco warnings
	btfss	WREG,outside_warning		; are we currently outside of the ZH-L16 model?
	bra		TFT_color_code_ceiling_attn	; NO  - set to attention color and return
	;bra	TFT_color_code_ceiling_warn	; YES - set to warnings  color and return


	; Helper Functions - select color and return
TFT_color_code_ceiling_warn:
	FONT_COLOR_WARNING					; select color
	return								; done

TFT_color_code_ceiling_attn:
	FONT_COLOR_ATTENTION				; select color
	return								; done

TFT_color_code_ceiling_memo:
	FONT_COLOR_MEMO						; select color
	return								; done

TFT_color_code_ceiling_dis:
	bcf		hi,char_invalid_flag		; clear the invalid flag (bit 7 here)
	FONT_COLOR_DISABLED					; select disabled color
	return								; done


;-----------------------------------------------------------------------------
; Color-Code the Stop Depth
;
; memo      color if below stop depth,
; attention color if above stop but below ceiling*,
; warning   color if above stop and ceiling*
;
; Input: depth_meter       current depth
;        lo                stop    depth
;        char_O_deco_gas   deco data valid flag
;
; * the ceiling depth is calculated using current (interpolated) GF
;
TFT_color_code_stop:
	; check for invalid
	movff	char_O_deco_gas+0,WREG		; get flag for invalid deco data
	btfsc	WREG,char_invalid_flag		; is the invalid flag set?
	bra		TFT_color_code_stop_dis		; YES - set to disabled color and return

	; check for shallower than stop depth
	movf	lo,W						; get depth of first stop in meters into WREG
	subwf	depth_meter,W				; compute current depth - stop depth
	btfsc	STATUS,C					; result negative?
	bra		TFT_color_code_stop_1		; NO  - not shallower than stop depth, check for ascent advice
	MOVII	int_O_ceiling,sub_b			; YES - get ceiling depth in mbar
	btfsc	sub_b+1,char_invalid_flag	;     - is the invalid flag set? (bit 7 here)
	bra		TFT_color_code_stop_warn	;       YES - select warning color and return
	MOVII	pressure_rel_cur_cached,sub_a;      NO  - get current pressure
	call	cmpU16						;           - sub_a - sub_b = relative pressure - int_O_ceiling
	btfsc	neg_flag					;           - is ceiling > current depth?
	bra		TFT_color_code_stop_warn	;             YES - set to warning   color and return
	bra		TFT_color_code_stop_attn	;             NO  - set to attention color and return

	; check for ascent advice
TFT_color_code_stop_1:
	movf	lo,W						; get depth of first stop in meters into WREG
	incf	WREG,W						; compute stop depth + 1 meter
	subwf	depth_meter,W				; compute current depth - (first stop depth + 1 meter)
	btfss	STATUS,C					; result negative?
	bra		TFT_color_code_stop_memo	; YES - within 1 meter of stop depth, use memo color
	btfsc	deco_region					; NO  - within deco stops region?
	bra		TFT_color_code_stop_advc	;       YES - use advice color and return
	;bra	TFT_color_code_stop_memo	;       NO  - use memo   color and return


	; Helper Functions - select color and return
TFT_color_code_stop_memo:
	FONT_COLOR_MEMO						; select color
	return								; done

TFT_color_code_stop_advc:
	FONT_COLOR_ADVICE					; select color
	bsf		win_invert					; print in inverse
	return								; done

TFT_color_code_stop_attn:
	FONT_COLOR_ATTENTION				; select color
	return								; done

TFT_color_code_stop_warn:
	FONT_COLOR_WARNING					; select color
	return								; done

TFT_color_code_stop_dis:
	FONT_COLOR_DISABLED					; select color
	return								; done


;-----------------------------------------------------------------------------
; Color-Code the current Depth
;
TFT_color_code_depth:
	TSTOSS	opt_depth_warn				; depth warning switched on?
	bra		TFT_color_code_depth_no_mod	; NO
	btfsc	warn_det_depth_limit		; YES - depth limit warning active?
	bra		TFT_color_code_depth_warn	;       YES - set to warning color
	bra		TFT_color_code_depth_mod	;       NO  - check depth against MOD

TFT_color_code_depth_no_mod:
	btfsc	warn_det_depth_limit		; depth limit warning active?
	bra		TFT_color_code_depth_warn	; YES - set to warning color and return
	bra		TFT_color_code_depth_memo	; NO  - set to memo    color and return...

TFT_color_code_depth_mod:
 IFDEF _ccr_pscr
	movff	opt_dive_mode,WREG			; get deco mode: 0=OC, 1=CC, 2=Gauge, 3=Apnea, 4=PSCR
	decfsz	WREG,F						; in CCR mode?
	bra		TFT_color_code_depth_no_ccr	; NO  - continue checking for ppO2
	btfss	bailout_mode				; YES - check if in bailout
	bra		TFT_color_code_depth_outside;       NO  - continue checking for outside ZHL16 model
	;bra	TFT_color_code_depth_no_ccr ;       YES - continue checking for ppO2
 ENDIF

TFT_color_code_depth_no_ccr:
	movff	int_O_breathed_ppO2+1,WREG	; get upper byte of currently breathed ppO2
	btfsc	WREG,int_warning_flag		; is the warning flag set?
	bra		TFT_color_code_depth_warn	; YES - animate in warning design
	;bra	TFT_color_code_depth_outside; NO  - continue checking for outside ZHL16 model

TFT_color_code_depth_outside:
	movff	char_O_deco_warnings,WREG	; bank-safe copy of deco warnings
	btfsc	WREG,outside_warning		; are we currently outside of the ZH-L16 model?
	bra		TFT_color_code_depth_warn	; YES - activate  depth warning
	btfsc	WREG,outside_attention		; NO  - are we near to outside of the ZH-L16 model?
	bra		TFT_color_code_depth_att	;       YES - activate  depth attention
	;bra	TFT_color_code_depth_memo	;       NO  - select memo color and return


	; Helper Functions - set colors and attention/warning flags
TFT_color_code_depth_memo:
	bcf		depth_color_warning			; terminate depth warning
	bcf		depth_color_attention		; terminate depth attention
	FONT_COLOR_MEMO						; select color
	return								; done

TFT_color_code_depth_warn:
	bsf		depth_color_warning			; activate  depth warning
	bcf		depth_color_attention		; terminate depth attention
	FONT_COLOR_WARNING					; select warning color
	return								; done

TFT_color_code_depth_att:
	bcf		depth_color_warning			; terminate depth warning
	bsf		depth_color_attention		; activate  depth attention
	FONT_COLOR_ATTENTION				; select attention
	return								; done


;-----------------------------------------------------------------------------
; Color-Code a CNS Value
;
; Input  hi:lo  CNS value [%]
;
	global	TFT_color_code_cns
TFT_color_code_cns:
	btfss	hi,int_invalid_flag			; is the invalid flag set?
	bra		TFT_color_code_cns_1		; NO
	bcf		hi,int_invalid_flag			; YES - clear invalid flag
	bcf		hi,int_warning_flag			;     - clear warning   flag (it may be set)
	bcf		hi,int_attention_flag		;     - clear attention flag (it may be set)
	FONT_COLOR_DISABLED					;     - select disabled color
	return								;     - done

TFT_color_code_cns_1:
	btfss	hi,int_warning_flag			; is the warning flag set?
	bra		TFT_color_code_cns_2		; NO
	bcf		hi,int_warning_flag			; YES - clear warning   flag
	bcf		hi,int_attention_flag		;     - clear attention flag (it may be set)
	FONT_COLOR_WARNING					;     - select warning color
	return								;     - done

TFT_color_code_cns_2:
	btfss	hi,int_attention_flag		; is the attention flag set?
	bra		TFT_color_code_cns_3		; NO  - select memo color
	bcf		hi,int_attention_flag		; YES - clear attention flag
	FONT_COLOR_ATTENTION				;     - select attention color
	return								;     - done

TFT_color_code_cns_3:
	FONT_COLOR_MEMO						; select memo color
	return								; done


;-----------------------------------------------------------------------------
; Color-Code a Supersaturation Value
;
; Input  hi:lo  CNS value [%]
;
; with int_O_lead_supersat, the upper byte is solely used for the flags
; and not for the value, thus there is no need to clear the flags
;
TFT_color_code_supersat:
	movf	pallet_color_memo,W			; load memo color by default
	btfsc	hi,int_attention_flag		; is the attention flag set?
	movf	pallet_color_attention,W	; YES - replace by attention color
	btfsc	hi,int_warning_flag			; is the warning flag set?
	movf	pallet_color_warning,W		; YES - replace by warning   color
	btfsc	hi,int_invalid_flag			; is the invalid flag set?
	movf	pallet_color_disabled,W		; YES - replace by disabled  color
	movwf	font_color					; set font color
	return								; done


;-----------------------------------------------------------------------------
; Color-Code a ppO2 Value by its warning flags (16 bit)
;
; Input  hi:lo  ppO2 value [cbar]
;
TFT_color_code_ppo2:
	btfss	hi,int_warning_flag			; is the warning flag set?
	bra		TFT_color_code_ppo2_1		; NO
	bcf		hi,int_warning_flag			; YES - clear warning flag
	bcf		hi,int_attention_flag		;     - clear attention    flag (it may be set)
	bcf		hi,int_high_flag			;     - clear high warning flag (it may be set)
	bcf		hi,int_low_flag				;     - clear low  warning flag (it may be set)
	FONT_COLOR_WARNING					;     - select warning color
	return								;     - done

TFT_color_code_ppo2_1:
	btfss	hi,int_attention_flag		; is the attention flag set?
	bra		TFT_color_code_ppo2_2		; NO
	bcf		hi,int_attention_flag		; YES - clear attention    flag (it may be set)
	bcf		hi,int_high_flag			;     - clear high warning flag (it may be set)
	bcf		hi,int_low_flag				;     - clear low  warning flag (it may be set)
	FONT_COLOR_ATTENTION				;     - select to attention color
	return								;     - done

TFT_color_code_ppo2_2:
	bcf		hi,int_high_flag			; clear high warning flag (it may be set)
	bcf		hi,int_low_flag				; clear low  warning flag (it may be set)
	FONT_COLOR_MEMO						; select memo color
	return								; done


 IFDEF _ccr_pscr

;-----------------------------------------------------------------------------
; Color-Code a ppO2 Value by its warning flags (8 bit)
;
; Input  lo  ppO2 value [cbar]
;
TFT_color_code_ppo2_hud:
	movff	char_O_deco_info,WREG		; get the deco info vector
	btfss	WREG,deco_mode				; in deco?
	bra		TFT_color_code_ppo2_hud_a	; NO  - load normal max value as threshold
	movff	char_I_ppO2_max_deco,WREG	; YES - load deco   max value as threshold
	bra		TFT_color_code_ppo2_hud_b	; continue

TFT_color_code_ppo2_hud_a:
	movff	char_I_ppO2_max_work,WREG	; ppO2 max while in working phase
	;bra	TFT_color_code_ppo2_hud_b	; continue

TFT_color_code_ppo2_hud_b:
	cpfsgt	lo							; lo > threshold?
	bra		TFT_color_code_ppo2_hud1	; NO  - continue with checking for ppO2 low
	FONT_COLOR_WARNING					; YES - set warning color
	return								;     - done

TFT_color_code_ppo2_hud1:
	movff	opt_dive_mode,WREG			; 0=OC, 1=CC, 2=Gauge, 3=Apnea, 4=PSCR
	decfsz	WREG,F						; in CCR mode?
	bra		TFT_color_code_ppo2_hud_nocc; NO  - check with ppO2 min for OC mode
	btfsc	bailout_mode				; YES - in bailout mode?
	bra		TFT_color_code_ppo2_hud_nocc;       YES - check with ppO2 min for OC mode
	movff	char_I_ppO2_min_loop,WREG	;       NO  - check with ppO2 min for loop mode
	bra		TFT_color_code_ppo2_hud_com	;           - continue with common part

TFT_color_code_ppo2_hud_nocc:
	movff	char_I_ppO2_min,WREG		; get ppO2 min for all other modes
	;bra	TFT_color_code_ppo2_hud_com	; continue with common part

TFT_color_code_ppo2_hud_com:
	cpfslt	lo							; lo < char_I_ppO2_min?
	bra		TFT_color_code_ppo2_hud_com1; NO  - set memo    color
	FONT_COLOR_WARNING					; YES - set warning color
	return								;     - done

TFT_color_code_ppo2_hud_com1:
	FONT_COLOR_MEMO						; select memo color
	return								; done

 ENDIF	; _ccr_pscr


;-----------------------------------------------------------------------------
; Color-Code the Battery Level
;
; Input  battery_low_condition  battery status flag
;
TFT_color_code_battery:
	movf	pallet_color_memo,W			; get memo color by default
	btfsc	battery_low_condition		; battery low condition detected?
	movf	pallet_color_warning,W		; YES - switch to warning color
	movwf	font_color					; set font color
	return								; done


;-----------------------------------------------------------------------------
; Color-Code according to Gas Number
;
; Input  WREG  gas number
;
	global	TFT_color_code_gas
TFT_color_code_gas:
	movwf	up							; copy gas number (1-6) to up
	movlw	color_white					; default color
	dcfsnz	up,F						; gas 1 ?
	movlw	color_white					; YES - color for gas 1
	dcfsnz	up,F						; gas 2 ?
	movlw	color_green					; YES - color for gas 2
	dcfsnz	up,F						; gas 3 ?
	movlw	color_red					; YSE - color for gas 3
	dcfsnz	up,F						; gas 4 ?
	movlw	color_yellow				; YES - color for gas 4
	dcfsnz	up,F						; gas 5 ?
	movlw	color_cyan					; YES - color for gas 5
	dcfsnz	up,F						; gas 6 ?
	movlw	color_pink					; YES - color for gas 6
	movwf	font_color					; set color
	return								; done


;=============================================================================
tft_out3	CODE
;=============================================================================


;-----------------------------------------------------------------------------
; Surface Mode Screen - current Time
;
	global	TFT_surfmode_time
TFT_surfmode_time:
	WIN_SMALL surf_clock_column+.7,surf_clock_row
	FONT_COLOR_MEMO						; set color
	SMOVSS	rtc_year,rtc_latched_year	; ISR-safe 6 byte copy of date and time
	movff	rtc_latched_hour,lo			; get   hours
	output_99							; print hours (0-99)
	movlw	':'							; load a ":"
	movff	rtc_latched_secs,lo			; get seconds
	btfss	lo,0						; on even second?
	movlw	' '							; NO - load a space char
	movwf	POSTINC2					; print ":" or space char
	movff	rtc_latched_mins,lo			; get   minutes
	output_99x							; print minutes (00-99)
	PRINT								; dump to screen
	return								; done


;-----------------------------------------------------------------------------
; Surface Mode Screen - current Date
;
	global	TFT_surfmode_date
TFT_surfmode_date:
	WIN_SMALL	surf_date_column,surf_date_row
	FONT_COLOR_MEMO						; set color
	SMOVSS	rtc_year,rtc_latched_year	; ISR-safe 6 byte copy of date and time
	movff	rtc_latched_year, lo		; copy year  to lo
	movff	rtc_latched_month,hi		; copy month to hi
	movff	rtc_latched_day,  up		; copy day   to up
	call	output_date					; print date
	PRINT								; dump to screen
	return								; done


;-----------------------------------------------------------------------------
; Surface Mode Screen - show Pressure, on condition deltaP > threshold
;
	global	TFT_surfmode_pres_fast
TFT_surfmode_pres_fast:
	SMOVII	pressure_abs,    sub_a		; ISR-safe 2 byte copy of current absolute pressure to sub_a
	MOVII	pressure_abs_ref,sub_b		; standard 2 byte copy 10 min ago absolute pressure to sub_b
	call	subU16						; sub_c = | sub_a - sub_b | = deltaP
	tstfsz	sub_c+1						; deltaP > 255 mbar ?
	bra		TFT_pres_surfmode_fast_1	; YES - show current pressure
	movlw	pressure_noise_threshold+.1	; NO  - load noise suppression threshold
	subwf	sub_c+0,W					;     - subtract threshold from deltaP
	bc		TFT_pres_surfmode_fast_1	;     - result negative -> show current pressure
	tstfsz	pressure_update_lag_counter	;     - still in lag time?
	bra		TFT_pres_surfmode_fast_0	;       YES - continue updating the display
	return								;       NO  - no display updates any more, done

TFT_pres_surfmode_fast_0:
	decf	pressure_update_lag_counter,F	; clock down lag time counter
	bra		TFT_surfmode_pres				; update display

TFT_pres_surfmode_fast_1:
	movlw	pressure_noise_lag_time		; get    lag time
	movwf	pressure_update_lag_counter	; re-set lag time counter
	;bra	TFT_surfmode_pres			; update display


;-----------------------------------------------------------------------------
; Surface Mode Screen - show Pressure (unconditional)
;
	global	TFT_surfmode_pres
TFT_surfmode_pres:
	; value
	WIN_SMALL surf_press_column+.8,surf_press_row
	FONT_COLOR_MEMO						; set color
	SMOVII	pressure_abs,mpr			; get current pressure
	FONT_COLOR_MEMO						; print in standard color
	output_9999							; print (0-9999)
	PRINT								; dump buffer to screen
	; unit
	WIN_SMALL	surf_press_column+(4+1)*8,surf_press_row
	FONT_COLOR_MASK						; switch to mask color
	STRCPY_TEXT_PRINT tMBAR				; print unit (hPa)
	return								; done


;-----------------------------------------------------------------------------
; Surface Mode Screen - Temperature
;
	global	TFT_surfmode_temp
TFT_surfmode_temp:
	; unit
	WIN_SMALL surf_temp_column+3*8,surf_temp_row
	FONT_COLOR_MASK						; select mask color
	TSTOSS	opt_units					; 0=°C, 1=°F
	bra		TFT_temp_surfmode_metric	; 0: metric
	;bra	TFT_temp_surfmode_imperial	; 1: imperial

TFT_temp_surfmode_imperial:
	STRCAT_TEXT tLogTunitF				; print "°F"
	bra		TFT_temp_surfmode_common	; continue with common part

TFT_temp_surfmode_metric:
	STRCAT_TEXT tLogTunitC				; print "°C"
	;bra	TFT_temp_surfmode_common	; continue with common part

TFT_temp_surfmode_common:
	PRINT								; dump the unit to screen

	; value
	WIN_SMALL surf_temp_column,surf_temp_row
	bra		TFT_temp_common				; continue with common part


	; Helper Function - common output for surface and dive mode temperature
TFT_temp_common:
	FONT_COLOR_MEMO						; set color
	SMOVII	temperature_cur,mpr			; ISR-safe 2 byte copy of current temperature to hi:lo

;	DEBUG CODE  -  manual override temp
;	-----------------------------------
;	MOVLI	0xFFF6,mpr		; - 1.0 °C
;	MOVLI	0xFF9C,mpr		; -10.0 °C

	TSTOSC	opt_units					; 0=°C, 1=°F
	call	convert_celsius_to_fahrenheit;1 - convert value in lo:hi from Celsius to Fahrenheit
	call	convert_signed_16bit		; convert lo:hi into signed-short and print '-' if negative
	btfsc	neg_flag					; is the temperature negative?
	bsf		hide_digit4					; YES - do not print digit 4
	bsf		omit_digit_1				; do not print digit 1 (0.1°)
	output_9999							; print temperature (0x-999x / 0x-99x if negative)

	btfss	divemode					; in dive mode?
	bra		TFT_temp_common_no_unit		; NO  - no unit to append
	TSTOSS	opt_units					; YES - check unit type: 0=°C, 1=°F
	bra		TFT_temp_common_metric		;       0 - metric
	;bra	TFT_temp_common_imperial	;       1 - imperial

TFT_temp_common_imperial:
	STRCAT_TEXT_PRINT tLogTunitF		; append "°F" and dump to screen
	return								; done

TFT_temp_common_metric:
	STRCAT_TEXT_PRINT tLogTunitC		; append "°C" and dump to screen
	return								; done

TFT_temp_common_no_unit:
	PRINT								; dump to screen
	return								; done


;-----------------------------------------------------------------------------
; Surface Mode Screen - Battery Status
;
	global	TFT_surfmode_batt
TFT_surfmode_batt:
	FONT_COLOR_MEMO						; set default color

	; apply charging indicator and warnings
	clrf	WREG						; default to no indication/warning
	btfsc	cc_active					; charging in CC mode?
	movlw	color_yellow				; YES - set output color to yellow
	btfsc	cv_active					; charging in CV mode?
	movlw	color_green					; YES - set output color to green
	btfsc	battery_low_condition		; battery low condition detected?
	movf	pallet_color_warning,W		; YES - set output to warning color
	btfsc	battery_overtemp			; battery over-temperature detector tripped?
	movf	pallet_color_warning,W		; YES - set output to warning color
	tstfsz	WREG						; any indicator or warning active?
	bsf		win_invert					; YES - set output to inverse
	tstfsz	WREG						; any indicator or warning active (asked again)?
	movwf	font_color					; YES - change color

	WIN_SMALL batt_percent_column+.2,batt_percent_row
	movff	batt_percent,lo				; get   battery %
	output_256							; print battery % (0-255)
	STRCAT_PRINT "% "					; append unit with trailing space and dump to screen

	WIN_TINY batt_voltage_column+.15,batt_voltage_row
	FONT_COLOR_MEMO						; set color
	movff	battery_type,lo				; get battery type
	PUTC	"T"							; print "T"
	output_9							; print battery type code (0-9)
	PUTC	":"							; print ":"
	MOVII	batt_voltage,mpr			; get battery voltage
	bsf		omit_digit_2				; do not print 2nd and 1st digit
	bsf		decimal_digit3				; place a decimal point in front of digit 3
	output_9999							; print x.x--
	PUTC_PRINT 'V'						; append unit and dump to screen
	return								; done

;update_battery_debug:
;	FONT_COLOR_MEMO	
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
;	call	div32x16					; xC:4 = xC:4 / xB:2 with xA as remainder
;	MOVII	xC,mpr
;	bsf		leftbind
;	output_65535
;	STRCAT_PRINT "x.01Ah"
;	return


;-----------------------------------------------------------------------------
; Surface Mode Screen - Deco Mode  (0=OC, 1=CCR, 2=Gauge, 3=Apnoe, 4=pSCR)
;
	global	TFT_surfmode_decotype
TFT_surfmode_decotype:
	WIN_STD surf_decotype_column,surf_decotype_row
	FONT_COLOR color_lightblue			; set font color
	movff	opt_dive_mode,lo			; get deco mode 
	tstfsz	lo							; in OC mode?
	bra		TFT_decotype_surface_2		; NO
	STRCAT_TEXT_PRINT tDvOC				; YES - print OC
	return								;     - done

TFT_decotype_surface_2:
	decfsz	lo,F						; in CCR mode?
	bra		TFT_decotype_surface_3		; NO
 IFDEF _ccr_pscr
	STRCAT_TEXT_PRINT tDvCC				; YES - print CCR

	WIN_TINY surf_decotype_column+.18,surf_decotype_row+.12
	FONT_COLOR_MEMO						;     - set color
	movff	opt_ccr_mode,WREG			;     - ccr mode
	tstfsz	WREG						;     - ccr_mode = 0 (FixedSP) ?
	bra		TFT_surfmode_decotype_cc_var;       NO  - not fixed
	;bra	TFT_surfmode_decotype_cc_fix;       YES - fixed

TFT_surfmode_decotype_cc_fix:
	STRCPY_TEXT tCCRModeFixedSP			; print "fixed SP"
	bra		TFT_decotype_surface_cc_com	; continue

TFT_surfmode_decotype_cc_var:
	; Sensor or Auto SP mode
	sublw	.2							; ccr_mode = 2 (Auto SP) ?
	bz		TFT_decotype_surface_cc_auto; YES - AutoSP
 IFDEF _external_sensor
	STRCPY_TEXT tCCRModeSensor			; NO  - print "Sensor"
	bra		TFT_decotype_surface_cc_com	;     - continue
 ENDIF	; _external_sensor

TFT_decotype_surface_cc_auto:
	STRCPY_TEXT tCCRModeAutoSP			; print "Auto SP"
	;bra	TFT_decotype_surface_cc_com	; continue

TFT_decotype_surface_cc_com:
	clrf	WREG						; load string terminator
	movff	WREG,buffer+.8				; limit string length to 8
	PRINT								; dump to screen
	return								; done
 ENDIF	; _ccr_pscr

TFT_decotype_surface_3:
	decfsz	lo,F						; in gauge mode?
	bra		TFT_decotype_surface_4		; NO
	STRCAT_TEXT_PRINT tDvGauge			; YES - print "Gauge"
	return								;     - done

TFT_decotype_surface_4:
	decfsz	lo,F						; in apnea mode?
	bra		TFT_decotype_surface_5		; NO
	STRCAT_TEXT_PRINT tDvApnea			; YES - print "Apnoe"
	return								;     - done

TFT_decotype_surface_5:
	STRCAT_TEXT_PRINT tDvPSCR			; print "pSCR"
	return								; done


;-----------------------------------------------------------------------------
; Surface Mode Screen - small Gas List
;
	global	TFT_surfmode_startgas
TFT_surfmode_startgas:
	; FIRST gas
	WIN_SMALL surf_decotype_column+.1,surf_decotype_row+.30
	FONT_COLOR_MEMO						; set font color
	call	get_first_gas_to_WREG		; get first gas (1-5) into WREG
	decf	WREG,W						; 1-5 -> 0-4
	movwf	PRODL						; copy to PRODL
	call	gaslist_strcat_mix_PRODL	; print gas description
	PRINT								; dump to screen

	; show gases
	WIN_TOP  surf_decotype_row+.30+.25	; set row position

	; 1st gas
	WIN_LEFT surf_decotype_boxes_left1+.1
	movff	opt_gas_type+0,hi			; 0=Disabled, 1=First, 2=Travel, 3=Deco
	rcall	TFT_surfmode_startgas_helper; set font color
	STRCPY_PRINT "1"					; print "1"
	decfsz	hi,F						; Type = 1 (First)?
	bra		TFT_surfmode_startgas_2		; NO - skip box
	WIN_FRAME_STD surf_decotype_boxes_top, surf_decotype_boxes_bottom, surf_decotype_boxes_left1, surf_decotype_boxes_left1+.8

	; 2nd gas
TFT_surfmode_startgas_2:
	WIN_LEFT surf_decotype_boxes_left2+.1
	movff	opt_gas_type+1,hi			; 0=Disabled, 1=First, 2=Travel, 3=Deco
	rcall	TFT_surfmode_startgas_helper; set font color
	STRCPY_PRINT "2"					; print "2"
	decfsz	hi,F						; Type = 1 (First)?
	bra		TFT_surfmode_startgas_3		; NO - skip box
	WIN_FRAME_STD surf_decotype_boxes_top, surf_decotype_boxes_bottom, surf_decotype_boxes_left2, surf_decotype_boxes_left2+.8

	; 3rd gas
TFT_surfmode_startgas_3:
	WIN_LEFT surf_decotype_boxes_left3+.1
	movff	opt_gas_type+2,hi			; 0=Disabled, 1=First, 2=Travel, 3=Deco
	rcall	TFT_surfmode_startgas_helper; set font color
	STRCPY_PRINT "3"					; print "3"
	decfsz	hi,F						; Type = 1 (First)?
	bra		TFT_surfmode_startgas_4		; NO - skip box
	WIN_FRAME_STD surf_decotype_boxes_top, surf_decotype_boxes_bottom, surf_decotype_boxes_left3, surf_decotype_boxes_left3+.8

	; 4th gas
TFT_surfmode_startgas_4:
	WIN_LEFT surf_decotype_boxes_left4+.1
	movff	opt_gas_type+3,hi			; 0=Disabled, 1=First, 2=Travel, 3=Deco
	rcall	TFT_surfmode_startgas_helper; set font color
	STRCPY_PRINT "4"					; print "4"
	decfsz	hi,F						; Type = 1 (First)?
	bra		TFT_surfmode_startgas_5		; NO - skip box
	WIN_FRAME_STD surf_decotype_boxes_top, surf_decotype_boxes_bottom, surf_decotype_boxes_left4, surf_decotype_boxes_left4+.8

	; 5th gas
TFT_surfmode_startgas_5:
	WIN_LEFT surf_decotype_boxes_left5+.1
	movff	opt_gas_type+4,hi			; 0=Disabled, 1=First, 2=Travel, 3=Deco
	rcall	TFT_surfmode_startgas_helper; set font color
	STRCPY_PRINT "5"					; print "5"
	decfsz	hi,F						; type = 1 (First)?
	return								; NO - done
	WIN_FRAME_STD surf_decotype_boxes_top, surf_decotype_boxes_bottom, surf_decotype_boxes_left5, surf_decotype_boxes_left5+.8
	return								; done


	; Helper Function - set font color
TFT_surfmode_startgas_helper:
	movf	pallet_color_disabled,W		; set default color
	tstfsz	hi							; gas not disabled?
	movf	pallet_color_memo,W			; YES - change to memo color
	movwf	font_color					; set font color
	return

 IFDEF _rx_functions

;-----------------------------------------------------------------------------
; Surface Mode Screen - Tank Pressure Reading above Surface Pressure
;
	global	TFT_surfmode_tankpres
TFT_surfmode_tankpres:
	WIN_SMALL surf_decotype_column+.6,surf_decotype_row+.30+.47
	movff	int_IO_pressure_value+0,lo	; copy pressure from 1st reading to hi:lo
	movff	int_IO_pressure_value+1,hi	; ...
	btfss	hi,int_not_avail_flag		; pressure reading 1 available?
	bra		TFT_surface_tank_pres_0		; YES
	movff	int_IO_pressure_value+2,lo	; NO - copy pressure from 2nd reading to hi:lo
	movff	int_IO_pressure_value+3,hi	;    - ...
	btfsc	hi,int_not_avail_flag		;    - pressure reading 2 available?
	bra		TFT_surface_tank_pres_1		;      NO  - show not avail message

TFT_surface_tank_pres_0:
	call	TFT_color_code_pres_sac		; set output color according to flags
	bsf		omit_digit_1				; do not print 1st digit (0.1 bar)
	output_9999							; print (0x-999x)
	PRINT								; dump to screen
	bra		TFT_surface_tank_pres_2		; print unit

TFT_surface_tank_pres_1:
	FONT_COLOR_DISABLED					; select disabled color
	STRCAT_PRINT " ---"					; output for no pressure data available

TFT_surface_tank_pres_2:
	WIN_SMALL surf_decotype_column+.38,surf_decotype_row+.30+.47
	FONT_COLOR_MASK						; select mask color
	STRCAT_PRINT "bar"					; can not use tbar because it has a leading space
	return								; done

 ENDIF	; _rx_functions


;=============================================================================
tft_out4	CODE
;=============================================================================


;-----------------------------------------------------------------------------
; Imprint the Color Schemes
;
	global	TFT_imprint_color_schemes
TFT_imprint_color_schemes:
	call	TFT_load_dive_color_pallet	; load dive mode color pallet

	FONT_COLOR_MASK						; select mask color
	WIN_TINY .12,.40					; print labels
	STRCAT_TEXT_PRINT tDepth			; ...
	WIN_TINY .62,.40					; ...
	STRCAT_TEXT_PRINT tMaxDepth			; ...
	WIN_TINY .122,.40					; ...
	STRCAT_TEXT_PRINT tDivetime			; ...

	FONT_COLOR_DISABLED					; select disabled color

	; max. depth demo
	WIN_MEDIUM .64,.54					; set font and position
	movlw	.63							; load demo depth
	movwf	lo							; ...
	output_99							; print full meters (0-99)
	PRINT								; dump to screen

	WIN_SMALL .87,.66					; set font and position
	PUTC	"."							; print ":"
	movlw	.4							; load demo depth
	movwf	lo							; ...
	output_9							; print decimeters (0-9)
	PRINT								; dump to screen

	FONT_COLOR_MEMO						; select memo color

	; depth demo
	WIN_MEDIUM .3,.54					; set font and position
	movlw	.17							; load a demo depth
	movwf	lo							; ...
	output_99							; print full meters (0-99)
	PRINT								; dump to screen

	WIN_SMALL .25,.66					; set font and position
	PUTC	"."							; print ":"
	movlw	.5							; load demo depth
	movwf	lo							; ...
	output_9							; print decimeters (0-9)
	PRINT								; dump to screen

	; dive time demo
	WIN_MEDIUM .103, .54				; set font and position
	SMOVSS	rtc_year,rtc_latched_year	; ISR-safe 6 byte copy of date and time
	movff	rtc_latched_mins,lo			; get   minutes
	output_256							; print minutes (in 3 digits, 1st digit used as spacer)
	PRINT								; dump to screen

	WIN_SMALL .139, .66					; set font and position
	PUTC	':'							; print ":"
	movff	rtc_latched_secs,lo			; get   seconds
	output_99x							; print seconds (00-99)
	PRINT								; dump to screen

	; messages demo
	WIN_SMALL dm_warning1_column-.78, dm_warning1_row+.39+.12
	FONT_COLOR_ADVICE					; select advice color
	STRCPY_TEXT_PRINT tgaschange		; sample text "Change?"

	WIN_SMALL dm_warning1_column, dm_warning1_row+.39
	FONT_COLOR_ATTENTION				; select attention color
	STRCPY_TEXT_PRINT tCNSeod			; sample text "CNS final"

	WIN_SMALL dm_warning2_column, dm_warning2_row+.38
	FONT_COLOR_WARNING					; select warning color
	STRCPY_TEXT_PRINT tGasNeedsWarn		; sample text "Gas Needs"

	call	TFT_load_std_color_pallet	; re-load standard color pallet

	return								; done


;-----------------------------------------------------------------------------
; Surface Menu - Imprint Time & Date
;
	global	TFT_imprint_time_date
TFT_imprint_time_date:
	SMOVSS	rtc_year,rtc_latched_year	; ISR-safe 6 byte copy of current date & time
	;bra	TFT_imprint_time_date_fast	; continue


;-----------------------------------------------------------------------------
; Surface Menu - Imprint Time & Date - fast Updating
;
	global	TFT_imprint_time_date_fast
TFT_imprint_time_date_fast:
	WIN_SMALL .20,.40					; column, row - keep clear of the cursor area on the left!
	FONT_COLOR_MEMO						; select color
	movff	rtc_latched_hour,lo			; get   hours
	output_99							; print hours (0-99)
	PUTC	':'							; print ":"
	movff	rtc_latched_mins,lo			; get   minutes
	output_99x							; print minutes (00-99)
	PUTC	':'							; print ":"
	movff	rtc_latched_secs,lo			; get   seconds
	output_99x							; print seconds (00-99)
	STRCAT	"  "						; append two spaces
	movff	rtc_latched_year, lo		; get date
	movff	rtc_latched_month,hi		; ...
	movff	rtc_latched_day,  up		; ...
	call	output_date					; print date
	PUTC_PRINT " "						; append a space and dump to screen
	return								; done


 IFDEF _external_sensor

;-----------------------------------------------------------------------------
; Surface Mode - Imprint ppO2 from Sensors
;
	global	TFT_imprint_surf_ppO2
TFT_imprint_surf_ppO2:

TFT_imprint_surf_ppO2_1:
	WIN_SMALL surf_hud_sensor1_column,surf_hud_sensor1_row
	btfsc	sensor1_calibrated_ok		; sensor calibrated?
	bra		TFT_imprint_surf_ppO2_1a	; YES
	btfsc	sensor1_active				; NO - valid HUD data for this sensor?
	bra		TFT_imprint_surf_ppO2_1a	;      YES
	rcall	TFT_imprint_surf_ppO2_h2	;      NO  - print dashes
	bra		TFT_imprint_surf_ppO2_2		;          - continue with sensor 2
TFT_imprint_surf_ppO2_1a:
	movff	sensor1_ppO2,lo				; get ppO2
	rcall	TFT_imprint_surf_ppO2_h1	; print ppO2

TFT_imprint_surf_ppO2_2:
	WIN_SMALL surf_hud_sensor2_column,surf_hud_sensor2_row
	btfsc	sensor2_calibrated_ok		; sensor calibrated?
	bra		TFT_imprint_surf_ppO2_2a	; YES
	btfsc	sensor2_active				; NO  - valid HUD data for this sensor
	bra		TFT_imprint_surf_ppO2_2a	;       YES
	rcall	TFT_imprint_surf_ppO2_h2	;       NO  - print dashes
	bra		TFT_imprint_surf_ppO2_3		;           - continue with sensor 3
TFT_imprint_surf_ppO2_2a:
	movff	sensor2_ppO2,lo				; get ppO2
	rcall	TFT_imprint_surf_ppO2_h1	; print ppO2

TFT_imprint_surf_ppO2_3:
	WIN_SMALL surf_hud_sensor3_column,surf_hud_sensor3_row
	btfsc	sensor3_calibrated_ok		; sensor calibrated?
	bra		TFT_imprint_surf_ppO2_3a	; YES
	btfsc	sensor3_active				; NO  - valid HUD data for this sensor
	bra		TFT_imprint_surf_ppO2_3a	;       YES
	bra		TFT_imprint_surf_ppO2_h2	;       NO  - print dashes and return
	return								;           - done
TFT_imprint_surf_ppO2_3a:
	movff	sensor3_ppO2,lo				; get ppO2
	;bra	TFT_imprint_surf_ppO2_h1	; print ppO2 and return

TFT_imprint_surf_ppO2_h1:
	call	TFT_color_code_ppo2_hud		; color-code with ppO2 [cbar] in lo
	bsf		decimal_digit2				; place a decimal point in front of digit 2
	output_256							; print (0.00-2.55)
	PRINT								; dump to screen
	return								; done

TFT_imprint_surf_ppO2_h2:
	FONT_COLOR_MEMO						; select standard color
	STRCPY_PRINT "--- "					; print dashes
	return								; done


;-----------------------------------------------------------------------------
; Surface Mode - Imprint mV from Sensors
;
	global	TFT_imprint_surf_mV
TFT_imprint_surf_mV:
	FONT_COLOR_MEMO						; set font color

	; sensor 1
	WIN_SMALL surf_mV_sensor_column,surf_mV_sensor1_row
	SMOVII	sensor1_mv,mpr				; in 0.1mV steps
	STRCAT	"1: "						; print number
	rcall	TFT_sensor_mV_helper		; print mV

	; sensor 2
	WIN_SMALL surf_mV_sensor_column,surf_mV_sensor2_row
	SMOVII	sensor2_mv,mpr				; in 0.1mV steps
	STRCAT	"2: "						; print number
	rcall	TFT_sensor_mV_helper

	; sensor 3
	WIN_SMALL surf_mV_sensor_column,surf_mV_sensor3_row
	SMOVII	sensor3_mv,mpr				; in 0.1mV steps
	STRCAT	"3: "						; print number
	rcall	TFT_sensor_mV_helper		; print mV

	; print sensor connection type
	WIN_SMALL surf_mV_sensor_column,surf_mV_sensor3_row+.24
	btfsc	ext_input_optical			; optical input?
	bra		TFT_sensor_mV_optical		; YES
	TSTOSS	opt_s8_mode					; NO  - S8 input selected?
	bra		TFT_sensor_mV_analog		;       NO  - analog input
	;bra	TFT_sensor_mV_s8			;       YES - S8

TFT_sensor_mV_s8:
	STRCAT_PRINT	"Digital"			; print "Digital"
	return								; done

TFT_sensor_mV_optical:
	STRCAT_PRINT	"Optical"			; print "Optical"
	return								; done

TFT_sensor_mV_analog:
	STRCAT_PRINT	"Analog"			; print "analog"
	return								; done


	; Helper Function - print mV value
TFT_sensor_mV_helper:
	bsf		decimal_digit1				; place a decimal point in front of digit 1
	output_9999							; print (0.0-999.9)
	STRCAT_PRINT "mV "					; append unit and dump buffer to screen
	return								; done


;-----------------------------------------------------------------------------
; Surface Mode - Imprint End-of-Life from Sensors
;
; when opt_x_sx > 255 the sensor will just give 8 mV at a ppO2 of 0.21
;
	global	TFT_imprint_surf_sensor_eol
TFT_imprint_surf_sensor_eol:
	FONT_COLOR_WARNING					; set color

TFT_imprint_surf_eol_1:
	; sensor 1
	btfss	sensor1_calibrated_ok		; valid calibration?
	bra		TFT_imprint_surf_eol_2		; NO  - skip
	movff	opt_x_s1+1,WREG				; YES - get high(opt_x_s1)
	movf	WREG,W						;     - excite flags
	bz		TFT_imprint_surf_eol_2		;     - opt_x_s1 > 255 -> the sensor is not too bad yet for a warning
	WIN_SMALL surf_mV_sensor_status_column,surf_mV_sensor1_row-.5
	STRCPY_PRINT "\xb8"					; mark sensor as being at end of lifetime

TFT_imprint_surf_eol_2:
	; sensor 2
	btfss	sensor2_calibrated_ok		; valid calibration?
	bra		TFT_imprint_surf_eol_3		; NO  - skip
	movff	opt_x_s2+1,WREG				; YES - get high(opt_x_s2)
	movf	WREG,W						;     - excite flags
	bz		TFT_imprint_surf_eol_3		;     - opt_x_s2 > 255 -> the sensor is not too bad yet for a warning
	WIN_SMALL surf_mV_sensor_status_column,surf_mV_sensor2_row-.5
	STRCPY_PRINT "\xb8"					; mark sensor as being at end of lifetime

TFT_imprint_surf_eol_3:
	; sensor 3
	btfss	sensor3_calibrated_ok		; valid calibration?
	bra		TFT_imprint_surf_eol_4		; NO  - skip
	movff	opt_x_s3+1,WREG				; YES - get high(opt_x_s3)
	movf	WREG,W						;     - excite flags
	bz		TFT_imprint_surf_eol_4		;     - opt_x_s3 > 255 -> the sensor is not too bad yet for a warning
	WIN_SMALL surf_mV_sensor_status_column,surf_mV_sensor3_row-.5
	STRCPY_PRINT "\xb8"					; mark sensor as being at end of lifetime

TFT_imprint_surf_eol_4:
	return								; done


;-----------------------------------------------------------------------------
; Imprint Function for the Calibration Menu
;
	global	TFT_imprint_menu_mV
TFT_imprint_menu_mV:
	FONT_COLOR color_yellow				; show in yellow
	rcall	TFT_sensor_mv_get			; get sensor mV values

	; sensor 1
	WIN_SMALL	surf_menu_sensor1_column,surf_menu2_sensor1_row
	SMOVII	sensor1_mv,mpr				; in 0.1mV steps
	rcall	TFT_imprint_menu_mV_helper	; print mV value

	; sensor 2
	WIN_SMALL	surf_menu_sensor2_column,surf_menu2_sensor2_row
	SMOVII	sensor2_mv,mpr				; in 0.1mV steps
	rcall	TFT_imprint_menu_mV_helper	; print mV value

	; sensor 3
	WIN_SMALL	surf_menu_sensor3_column,surf_menu2_sensor3_row
	SMOVII	sensor3_mv,mpr				; in 0.1mV steps
	rcall	TFT_imprint_menu_mV_helper	; print mV value

	TSTOSS	opt_s8_mode					; =0: analog, =1: digital
	return								; analog - done

	; imprint HUD battery voltage
	WIN_TINY .20,.209					; set position
	STRCPY	"HUD Batt: "				; print label
	SMOVII	hud_battery_mv,mpr			; get HUD battery voltage
	bsf		decimal_digit3				; place a decimal point in front of digit 3
	output_9999							; print (0.000-9.999)
	PUTC_PRINT "V"						; append unit and dump buffer to screen
	return								; done

	; Helper Function - get sensor mV values
TFT_sensor_mv_get:
;	btfsc	ext_input_optical			; do we have an optical interface?
;	return								; YES - optical interface delivers ready-to-use mV data, done
	TSTOSS	opt_s8_mode					; NO  - S8 input selected?
	bra		TFT_sensor_mv_get_ana		;       NO  - read analog inputs
	;bra	TFT_sensor_mv_get_dig		;       YES - convert digitally received ppO2 into mV

TFT_sensor_mv_get_dig:
	btfss	trigger_S8_data_update		; new data frame received?
	return								; NO  - use old values
	bcf		trigger_S8_data_update		; YES - clear update flag
	call	compute_mvolts_from_rawdata	;     - compute mV values from received raw data
	return								;     - done

TFT_sensor_mv_get_ana:
	call	get_analog_inputs			; read mV values from analog inputs
	return								; done


	; Helper Function - print mV value
TFT_imprint_menu_mV_helper:
	bsf		decimal_digit1				; place a decimal point in front of digit 1 (no 0.1 mV)
	output_9999							; print (0.0-999.9)
	STRCAT_PRINT "mV"					; append unit and dump buffer to screen
	return								; done

 ENDIF	; _external_sensor


 IFDEF _rx_functions
;-----------------------------------------------------------------------------
; Imprint Function for the Tank Setup Menu
;
	global	TFT_imprint_tank_pres
TFT_imprint_tank_pres:
	FONT_COLOR_MEMO						; set color
	; get ID
	lfsr	FSR1,opt_transmitter_id_1	; load base address of opt_transmitter_id
	movf	gaslist_gas,W				; get current gas
	rlncf	WREG,W						; multiply by 2 because IDs are 2 byte in size
	movff	PLUSW1,lo					; copy opt_transmitter_id+0[gaslist_gas] to lo
	incf	WREG,W						; increment index
	movff	PLUSW1,hi					; copy opt_transmitter_id+1[gaslist_gas] to hi
	; show pressure
	WIN_SMALL .90, .61					; column, row (+/- 27 per row)
	call	get_pres_by_transmitter_id	; get pressure into hi:lo
	tstfsz	WREG						; do we have valid tank data (WREG=0) ?
	bra		TFT_menu_tank_pres_1		; NO - transmitter not found
	call	TFT_color_code_pres_sac		; set output color according to flags
	bsf		omit_digit_1				; do not print 1st digit (0.1 bar)
	output_9999							; print (0x-999x)
	bra		TFT_menu_tank_pres_2
TFT_menu_tank_pres_1:
	FONT_COLOR_DISABLED					; select color
	STRCAT	" ---"						; print dashes for no pressure data available
TFT_menu_tank_pres_2:
	STRCAT_TEXT_PRINT tbar				; print " bar"
	return								; done

 ENDIF	; _rx_functions


;=============================================================================
tft_out5	CODE
;=============================================================================


;-----------------------------------------------------------------------------
; Dive Mode - static Layout
;
	global	TFT_show_divemode_mask
TFT_show_divemode_mask:										; display mask in dive mode
	FONT_COLOR_MASK											; select color

	; current depth
	WIN_TINY dm_mask_depth_column,dm_mask_depth_row			; position for "Depth"
	btfss	alt_layout_active								; alternative layout active?
	bra		TFT_divemode_mask_depth_text					; NO
	btfsc	cur_depth_greater_100m							; YES - current depth >= 100 m?
	bra		TFT_divemode_mask_max_avg						;       YES - skip depth label as it collides with depth number
	WIN_TINY dm_mask_depth_column_alt,dm_mask_depth_row		;       NO  - set alternative position for "Depth"
TFT_divemode_mask_depth_text:
	STRCAT_TEXT_PRINT tDepth								; print "Depth"

TFT_divemode_mask_max_avg:
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
	return													; NO  - done
	WIN_TINY dm_total_apnoe_text_col,dm_total_apnoe_text_row; YES - set position
	STRCPY_TEXT_PRINT tApnoeTotal							;     - print "Total"
	return													;     - done


;-----------------------------------------------------------------------------
; Dive Mode - NDL  Layout Add-on
;
	global	TFT_show_ndl_mask
TFT_show_ndl_mask:
	btfsc	dive_main_menu				; is the dive mode menu shown?
	return								; YES - abort
	FONT_COLOR_MASK						; NO  - set color
										;     - set position
	WIN_STD dm_ndl_text_column, dm_ndl_text_row
	STRCPY_TEXT_PRINT tNDL				;     - print "NDL"
	btfss	deco_region					;     - was the dive within deco stops region?
	return								;       NO  - done
	btfsc	safety_stop_active			;       YES - safety stop shown?
	return								;             YES - done
	goto	TFT_show_slow_reminder		;             NO  - show "slow" reminder


;-----------------------------------------------------------------------------
; Dive Mode - Deco Layout Add-on
;
	global	TFT_show_deco_mask
TFT_show_deco_mask:
	bcf		safety_stop_active			; flag safety stop is not shown any more	TODO: needed?
	btfsc	dive_main_menu				; is the dive mode menu shown?
	return								; YES - abort
	btfsc	alt_layout_active			; NO  - in alternative layout?
	bra		TFT_show_deco_mask_alt		;       YES
	;bra	TFT_show_deco_mask_norm		;       NO

TFT_show_deco_mask_norm:
	WIN_STD dm_tts_text_col_norm, dm_tts_text_row_norm
	bra		TFT_show_deco_mask_common	; continue with common part

TFT_show_deco_mask_alt:
	WIN_TINY dm_tts_text_col_alt, dm_tts_text_row_alt
	STRCPY	"Stop/"						; print "Stop/"
	;bra	TFT_show_deco_mask_common	; continue with common part

TFT_show_deco_mask_common:
	FONT_COLOR_MASK						; set color
	STRCAT_TEXT_PRINT tTTS				; print "TTS"
	return								; done


;=============================================================================
tft_out6	CODE
;=============================================================================


;-----------------------------------------------------------------------------
; Dive Mode - show Dive Time
;
	global	TFT_show_divetime
TFT_show_divetime:
	FONT_COLOR_MEMO							; set color
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
	output_99								; print minutes (0-99)
	PRINT									; dump buffer to screen

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
	movff	mpr+2,lo						; copy  seconds to lo
	output_99x								; print seconds (00-99)
	bra		TFT_divemins_exit				; continue with common part

TFT_show_divetime_min_only:
	btfsc	alt_layout_active				; in alternative layout?
	bra		TFT_show_divetime_min_only_alt	; YES
	;bra	TFT_show_divetime_min_only_norm	; NO

TFT_show_divetime_min_only_norm:
	WIN_MEDIUM dm_divetime_minonly_col_medium, dm_divetime_row
	output_9999								; print minutes (0-9999)
	bra		TFT_divemins_exit				; continue with common part

TFT_show_divetime_min_only_alt:
	WIN_LARGE  dm_divetime_minonly_col_large,  dm_divetime_row
	output_999								; print minutes (0-999)
	;bra	TFT_divemins_exit				; continue with common part

TFT_divemins_exit:
	PRINT									; dump buffer to screen
	return									; done


;-----------------------------------------------------------------------------
; Dive Mode - show current Depth
;
	global	TFT_show_depth
TFT_show_depth:
	MOVII	pressure_rel_cur_cached,mpr	; copy relative pressure to MPR
	call	convert_pres_to_depth		; convert pressure in [mbar] to depth in [cm]
	call	TFT_color_code_depth		; set warning / attention flags and color-code the output
	rcall	TFT_depth_blink				; control animation (blinking)

	rcall	TFT_depth_position_m_ft		; set output position for full meters/feet
	TSTOSS	opt_units					; 0=m, 1=ft ?
	bra		TFT_depth_metric			; 0 - metric
	;bra	TFT_depth_imperial			; 1 - imperial

TFT_depth_imperial:
	MOVLI	.30,sub_a					; load depth threshold of 30 cm (for showing 0 if shallower)
	MOVII	mpr,sub_b					; get current depth
	call	cmpU16						; compute sub_a - sub_b = threshold - current depth
	btfss	neg_flag					; shallower than 30 cm ?
	bra		depth_0_feet				; YES - print a zero directly
	call	convert_cm_to_feet			; NO  - convert value in hi:lo from [cm] to [feet]
	output_999							;     - feet in large or huge font
	PRINT								;     - dump to screen
	bra		TFT_depth_exit				;     - do some cleanup and show target depth if in simulator mode

depth_0_feet:
	STRCAT_PRINT "  0"					; print a zero directly
	bra		TFT_depth_exit				; do some cleanup and show target depth if in simulator mode

TFT_depth_metric:
	bsf		omit_digit_2				; print depth in full meters, i.e. do not print 2nd and 1st digit
	output_9999							; test-print depth for range up to 99.9 meter (0xx-99xx)
	btfsc	output_overflow				; did the printing clip, i.e. deeper than 99.9 meter?
	bra		TFT_depth_metric_100m		; YES - print depth in full meters only

	; depth in meters and decimeters
	btfsc	cur_depth_greater_100m		; was the depth >= 100 meter during last call?
	rcall	TFT_depth_box_black			; YES - clear depth area

	btfsc	cur_depth_greater_100m		; was the depth >= 100 meter during last call?
	rcall	TFT_depth_position_m_ft		; re-set output position for full meters/feet

	bcf		cur_depth_greater_100m		; current depth is now < 100 meter
	PRINT								; dump full meters to screen

	btfsc	depth_inverse_last			; in inverse printing cycle?
	bsf		win_invert					; YES - print inverse
	rcall	TFT_depth_position_dm		; set output position for decimeters
	MOVLI	.30,sub_a					; 30 mbar = 0.3 meter
	MOVII	mpr,sub_b					; current depth
	call	cmpU16						; compare (sub_a - sub_b)
	btfss	neg_flag					; current depth < 0.3 meter ?
	bra		depth_0_decimeter			; YES - print a zero
	output_65535						; NO  - print full depth to buffer
	REINIT_BUFFER						;     - re-initialize the output buffer
	PUTC	"."							;     - print a decimal point
	movff	buffer+3,POSTINC2			;     - get and print the decimeters
	PRINT								;     - dump to screen
	bra		TFT_depth_exit				;     - do some cleanup and show target depth if in simulator mode
depth_0_decimeter:
	STRCAT_PRINT ".0"					; print a zero directly and dump buffer to screen
	bra		TFT_depth_exit				; do some cleanup and show target depth if in simulator mode

TFT_depth_metric_100m:
	; full meters only
	btfss	cur_depth_greater_100m		; was the depth >= 100 meter during last call?
	rcall	TFT_depth_box_black			; NO - clear depth area
	
	btfss	cur_depth_greater_100m		; was the depth >= 100 meter during last call?
	rcall	TFT_depth_position_m_ft		; re-set output position for full meters/feet
	
	bsf		cur_depth_greater_100m		; depth is >= 100 meter now
	REINIT_BUFFER						; re-initialize the output buffer
	bsf		omit_digit_2				; print depth in full meters, i.e. do not print 1st and 2nd digit
	output_65535						; print depth for range >= 100 meter (0xx-655xx)
	PRINT								; dump to screen
	;bra	TFT_depth_exit				; do some cleanup and show target depth if in simulator mode

TFT_depth_exit:
	btfss	alt_layout_active			; alternative layout active?
	bra		TFT_depth_exit_2			; NO
	btfsc	depth_inverse_last			; YES - was last output in inverse mode?
	bra		TFT_depth_exit_2			;       YES - do not restore "Depth" as it collides with depth number
	btfsc	cur_depth_greater_100m		;       NO  - current depth >= 100 m?
	bra		TFT_depth_exit_2			;             YES
	;bra	TFT_depth_exit_1			;             NO

TFT_depth_exit_1
	WIN_TINY dm_mask_depth_column_alt,dm_mask_depth_row
	FONT_COLOR_MASK						; set color
	STRCAT_TEXT_PRINT tDepth			; restore "Depth" title

TFT_depth_exit_2:
	btfss	sensor_override_active		; pressure sensor override active (simulator mode)?
	return								; NO  - done
	bra		TFT_depth_target			; YES - show simulator target depth


	; Helper Function - control animation (blinking)
TFT_depth_blink:
	TSTOSS	opt_depth_warn				; 0=standard, 1=blink
	return								; standard, done
	btfsc	depth_color_last			; was there a warning or attention on the depth in the previous cycle?
	bra		TFT_depth_blink_prev		; YES
	btfsc	depth_color_warning			; NO  - do we have a depth warning now?
	bra		TFT_depth_blink_new			;       YES - so we have a warning now but not previously
	btfsc	depth_color_attention		;       NO  - do we have a depth attention now?
	bra		TFT_depth_blink_new			;             YES - so we have attention now but not previously
	bra		TFT_depth_blink_none		;             NO  - no warning in previous cycle, no warning now, reset all flags

TFT_depth_blink_prev:
	; we had a warning or attention in previous cycle, check if we still have a warning or attention
	btfsc	depth_color_warning			; do we still have a warning?
	bra		TFT_depth_blink_prev_1		; YES
	btfsc	depth_color_attention		; NO  - do we still have an attention?
	bra		TFT_depth_blink_prev_1		;       YES
	; we had a warning or attention before, but not now any more - clear depth area from previous color
	rcall	TFT_depth_box_black			;       NO  - clear depth area
	;bra	TFT_depth_blink_none		;           - reset all flags

TFT_depth_blink_none:
	bcf		depth_inverse_last			; memorize depth was printed in normal
	bcf		depth_color_last			; memorize there was no warning or attention
	FONT_COLOR_MEMO						; select memo color
	return								; done

TFT_depth_blink_prev_1:
	; we had a warning or attention in previous cycle, and we still have a warning or attention
	btfss	depth_inverse_last			; was the depth printed in inverse last time?
	bra		TFT_depth_blink_set			; NO  - print in inverse now
	bra		TFT_depth_blink_reset		; YES - print in normal  now

TFT_depth_blink_new:
	; we had no warning or attention in previous cycle, but now
	bsf		depth_color_last			; memorize that the depth had a warning or attention
	;bra	TFT_depth_blink_set			; start with inverse display

TFT_depth_blink_set:
	; fill the area with respective color
	movf	pallet_color_attention,W	; select attention color as default
	btfsc	depth_color_warning			; do we have a warning?
	movf	pallet_color_warning,W		; YES - replace with warning color
	rcall	TFT_depth_box_color			; color depth area with color in WREG
	bsf		win_invert					; print in inverse
	bsf		depth_inverse_last			; memorize depth was printed in inverse
	return								; done

TFT_depth_blink_reset:
	; fill the area with black color
	rcall	TFT_depth_box_black			; clear depth area
	bcf		depth_inverse_last			; memorize depth was printed in normal
	return								; done


	; Helper Function - set output position for full meters/feet
TFT_depth_position_m_ft:				; output position meters / feet
	btfsc	alt_layout_active			; alternative layout active?
	bra		TFT_depth_position_m_ft_alt	; YES
	;bra	TFT_depth_position_m_ft_norm; NO

TFT_depth_position_m_ft_norm:
	WIN_LARGE dm_depth_col_large,dm_depth_row_large
	return								; done

TFT_depth_position_m_ft_alt:
	WIN_HUGE dm_depth_col_huge, dm_depth_row_huge
	return								; done


	; Helper Function - set output position for decimeters
TFT_depth_position_dm:					; output position decimeters
	btfsc	alt_layout_active			; alternative layout active?
	bra		TFT_depth_position_dm_alt	; YES
	bra		TFT_depth_position_dm_norm	; NO

TFT_depth_position_dm_norm:
	WIN_MEDIUM dm_depth_dm_col_medium, dm_depth_dm_row_medium
	return								; done
TFT_depth_position_dm_alt:
	WIN_LARGE  dm_depth_dm_col_large,  dm_depth_dm_row_large
	return								; done


	; Helper Function - clear depth area
TFT_depth_box_black:
	clrf	WREG						; select black color
	;bra	TFT_depth_box_color			; continue with colored box


	; Helper Function - color depth area with color in WREG
TFT_depth_box_color:
	btfsc	alt_layout_active			; alternative layout active?
	bra		TFT_depth_box_alt			; YES
	;bra	TFT_depth_box_norm			; NO

TFT_depth_box_norm:
	WIN_BOX_COLOR dm_depth_row_large,dm_depth_bot_large,dm_depth_col_large,dm_depth_rgt_large
	return								; done

TFT_depth_box_alt:
	WIN_BOX_COLOR dm_mask_depth_row, dm_depth_bot_huge, dm_depth_col_huge, dm_depth_rgt_huge
TFT_depth_box_exit:
	return								; done


	; Helper Function - show simulated target depth
TFT_depth_target:
	FONT_COLOR_ATTENTION					; select attention color
	movff	simulatormode_depth,lo			; copy target depth to lo
	TSTOSS	opt_units						; check unit selection (0=m or 1=ft)
	bra		TFT_depth_target_metric			; 0 - metric
	;bra	TFT_depth_target_imperial		; 1 - imperial

TFT_depth_target_imperial:
	btfsc	alt_layout_active				; alternative layout active?
	bra		TFT_depth_target_imperial_alt	; YES
	;bra	TFT_depth_target_imperial_norm	; NO

TFT_depth_target_imperial_norm:
	WIN_TINY dm_mask_depth_column+.40,dm_mask_depth_row		; position right of depth label
	bra		TFT_depth_target_imperial_com					; continue with common part

TFT_depth_target_imperial_alt:
	WIN_TINY dm_mask_depth_column+.62,dm_mask_depth_row+.20	; position within last digit
	;bra	TFT_depth_target_imperial_com					; continue with common part

TFT_depth_target_imperial_com:
	call	convert_meter_to_feet			; convert value in lo from meters to feet
	output_999								; display only last three digits from a 16 bit value (0-999)
	STRCAT_PRINT "ft"						; append unit and dump buffer to screen
	return									; done

TFT_depth_target_metric:
	btfsc	alt_layout_active				; alternative layout active?
	bra		TFT_depth_target_metric_alt		; YES
	;bra	TFT_depth_target_metric_norm	; NO

TFT_depth_target_metric_norm:
	WIN_TINY dm_mask_depth_column+.38,dm_mask_depth_row+.22		; position right of full meters, above decimal
	bra		TFT_depth_target_metric_com							; continue with common part

TFT_depth_target_metric_alt:
	WIN_TINY dm_mask_depth_column+.65,dm_mask_depth_row+.20		; position right of full meters, above decimal
	;bra	TFT_depth_target_metric_com							; continue with common part

TFT_depth_target_metric_com:
	output_256								; display target depth (0-255)
	PUTC_PRINT "m"							; append unit and dump to screen
	return									; done


;-----------------------------------------------------------------------------
; Dive Mode - show maximum Depth
;
	global	TFT_show_max_depth
TFT_show_max_depth:
	FONT_COLOR_MEMO						; select color
	btfsc	alt_layout_active			; alternative layout active?
	bra		TFT_show_max_depth_alt		; YES
	;bra	TFT_show_max_depth_norm		; NO

TFT_show_max_depth_norm:
	WIN_MEDIUM dm_max_depth_column_nvsi, dm_max_depth_row
	TSTOSS	opt_vsigraph								; graphical VSI bar enabled?
	bra		TFT_show_max_depth_norm_1					; NO  - keep position
	WIN_MEDIUM dm_max_depth_column, dm_max_depth_row	; YES - adopt output position

TFT_show_max_depth_norm_1:
	btfsc	FLAG_apnoe_mode				; in apnoe mode?
	bra		TFT_max_depth_apnoe			; YES - different handling in apnoe mode
	TSTOSS	opt_2ndDepthDisp			; NO  - show average depth instead of max depth?
	bra		TFT_max_depth_current		;       NO  - show max depth
	bra		TFT_avg_depth_current		;       YES - show avg depth

TFT_max_depth_apnoe:
	btfss	apnoe_at_surface			; apnoe mode, at the surface?
	bra		TFT_max_depth_current		; NO  - show max depth of current dive
	MOVII	apnoe_max_pressure,mpr		; YES - get max pressure of all dives so far
	bra		TFT_max_depth_common		;     - continue with common part

TFT_max_depth_current:
	MOVII	pressure_rel_max_cached,mpr	; get the "normal" max pressure
	bra		TFT_max_depth_common		; continue with common part

TFT_avg_depth_current:
	MOVII	pressure_rel_avg_total,mpr	; get total dive average pressure
	;bra	TFT_max_depth_common		; continue with common part

TFT_max_depth_common:
	call	convert_pres_to_depth		; convert pressure in [mbar] to depth in [cm]
	TSTOSS	opt_units					; 0=m or 1=ft ?
	bra		TFT_max_depth_metric		; 0 - use metric   version
	;bra	TFT_max_depth_imperial		; 1 - use imperial version

TFT_max_depth_imperial:
	bra		TFT_show_depth_helper_imperial

TFT_max_depth_metric:
	bsf		omit_digit_2				; print depth in full meters, i.e. do not print 2nd and 1st digit
	output_9999							; test-print depth for range up to 99.9 meter (0xx-99xx)
	btfsc	output_overflow				; did the printing clip, i.e. deeper than 99.9 meter?
	bra		TFT_max_depth_metric_100m	; YES - print depth in full meters only
	;bra	TFT_max_depth_metric_99m	; NO  - print depth in meters and decimeters

TFT_max_depth_metric_99m:
	; full meters
	btfsc	max_depth_greater_100m		; was the depth >= 100 meter during last call?
	rcall	TFT_max_depth_box_black		; NO - clear max depth area
	bcf		max_depth_greater_100m		; current depth is now < 100 meter
	PRINT								; dump full meters to screen
	; decimeters
	rcall	TFT_max_depth_metric_dm		; set output position for decimeters
	output_65535						; print full depth to buffer
	REINIT_BUFFER						; re-initialize the output buffer
	PUTC	"."							; print a decimal point
	movff	buffer+3,POSTINC2			; get and print the decimeters
	PRINT								; dump to screen
	return								; done

TFT_max_depth_metric_100m:
	; full meters only
	btfss	max_depth_greater_100m		; was the depth >= 100 meter during last call?
	rcall	TFT_max_depth_box_black		; NO - clear max depth area
	bsf		max_depth_greater_100m		; depth is >= 100 meter now
	REINIT_BUFFER						; re-initialize the output buffer
	bsf		omit_digit_2				; print depth in full meters, i.e. do not print 1st and 2nd digit
	output_65535						; print depth for range >= 100 meter (0xx-655xx)
	PRINT								; dump to screen
	return								; done

TFT_show_max_depth_alt:
	btfsc	FLAG_apnoe_mode				; in apnoe mode?
	bra		TFT_show_apnoe_max_depth	; YES - use apnoe surface output also in alternative dive mode screen
	btfss	FLAG_gauge_mode				; NO  - in gauge mode?
	return								;       NO  - done
	;bra	TFT_show_gauge_max_avg_depth;       YES

TFT_show_gauge_max_avg_depth:
	WIN_MEDIUM dm_gauge_max_depth_col, dm_gauge_max_depth_row	; set position for max depth
	MOVII	pressure_rel_max_cached,mpr							; get max pressure into hi:lo
	rcall	TFT_show_depth_helper								; print max depth
	WIN_MEDIUM dm_gauge_avg_depth_col, dm_gauge_avg_depth_row	; set position for avg depth
	MOVII	pressure_rel_avg_total,mpr							; get average pressure into hi:lo
	bra		TFT_show_depth_helper								; print avg depth and return


	; Helper Function - clear max depth area
TFT_max_depth_box_black:
	WIN_BOX_BLACK dm_max_depth_row, dm_max_depth_bot, dm_max_depth_column, dm_max_depth_rgt
	return									; done


	; Helper Function - set output position for decimeters
TFT_max_depth_metric_dm:
	WIN_SMALL dm_max_depth_dm_column_nvsi, dm_max_depth_dm_row	; default position
	TSTOSS	opt_vsigraph										; graphical VSI bar enabled?
	return														; NO  - keep position
	WIN_SMALL dm_max_depth_dm_column, dm_max_depth_dm_row		; YES - adopt position
	return														; done


	; Helper Function - print depth in mpr
TFT_show_depth_helper:
	call	convert_pres_to_depth			; convert pressure in [mbar] to depth in [cm]
	TSTOSS	opt_units						; 0=m, 1=ft
	bra		TFT_show_depth_helper_metric 	; 0 - metric
	;bra	TFT_show_depth_helper_imperial	; 1 - imperial

TFT_show_depth_helper_imperial:
	call	convert_cm_to_feet				; convert value in hi:lo from [cm] to [feet]
	output_999								; print depth (0-999)
	PRINT									; dump to screen
	return									; done

TFT_show_depth_helper_metric:
	bsf		omit_digit_1					; do not print 1st digit
	bsf		decimal_digit2					; place a decimal point in front of digit 2
	output_65535							; print depth (0.0x-655.3x)
	PRINT									; dump to screen
	return									; done


;-----------------------------------------------------------------------------
; Dive Mode - show maximum Depth - Apnoe Mode
;
	global	TFT_show_apnoe_max_depth
TFT_show_apnoe_max_depth:
	; title
	WIN_TINY dm_apnoe_last_max_depth_text_col, dm_apnoe_last_max_depth_text_row
	FONT_COLOR_MASK							; set color
	btfsc	alt_layout_active				; alternative layout active?
	bra		TFT_show_apnoe_max_depth_alt	; YES
	;bra	TFT_show_apnoe_max_depth_norm	; NO

TFT_show_apnoe_max_depth_norm:
	STRCPY_TEXT_PRINT tApnoeMax				; print "Last Descent"
	bra		TFT_show_apnoe_max_depth_com	; continue with common part

TFT_show_apnoe_max_depth_alt:
	STRCPY_TEXT_PRINT tMaxDepth				; print "Max.Depth"
	;bra	TFT_show_apnoe_max_depth_com	; continue with common part

TFT_show_apnoe_max_depth_com:
	; value
	WIN_MEDIUM	dm_apnoe_last_max_depth_column, dm_apnoe_last_max_depth_row
	FONT_COLOR_MEMO							; select color
	MOVII	pressure_rel_max_cached,mpr		; get max pressure into hi:lo
	bra		TFT_show_depth_helper			; print max depth and return


;-----------------------------------------------------------------------------
; Dive Mode - show Temperature
;
	global	TFT_show_temp_divemode
TFT_show_temp_divemode:
	btfsc	dive_pre_menu				; is the pre-menu shown?
	return								; YES - abort
	btfsc	dive_main_menu				; is the dive mode menu shown?
	return								; YES - abort, no update of temperature now
	btfsc	better_gas_blinking			; blinking better gas?
	return								; YES - abort, no update of temperature now
	btfsc	better_dil_blinking			; blinking better diluent?
	return								; YES - abort, no update of temperature now

	WIN_SMALL dm_temp_column,dm_temp_row; set position
	FONT_COLOR_MEMO						; set color
	movlw	index_compass_dm			; index of compass custom view
	cpfseq	active_customview			; compass shown in custom view?
	goto	TFT_temp_common				; NO  - continue with common part for temperature
	goto	TFT_update_stopwatch		; YES - show resettable dive time instead of temperature


;-----------------------------------------------------------------------------
; Dive Mode - active Gas and Setpoint
;
	global	TFT_show_active_gas_divemode
TFT_show_active_gas_divemode:
	btfsc	dive_main_menu				; is the dive mode menu shown?
	return								; YES - abort
	btfsc	FLAG_apnoe_mode				; in apnoe mode?
	return								; YES - done
	btfsc	FLAG_gauge_mode				; in gauge mode?
	return								; YES - done

 IFDEF _ccr_pscr

	btfsc	FLAG_oc_mode				; in OC mode?
	bra		TFT_active_gas				; YES - show OC gas
	btfss	bailout_mode				; NO  - in bailout?
	bra		TFT_active_sp_loop			;       NO
	;bra	TFT_active_sp_bailout		;       YES

TFT_active_sp_bailout:
	WIN_SMALL dm_active_dil_column, dm_active_dil_row
	FONT_COLOR_ATTENTION				; set color
	STRCPY_TEXT_PRINT tDiveBailout		; print "Bailout"
	bra		TFT_active_gas				; continue showing OC bailout gas

TFT_active_sp_loop:
	MOVII	int_O_breathed_ppO2,mpr		; copy ppO2 [cbar] to hi:lo
	call	TFT_color_code_ppo2			; color-code the output by the ppO2 of the loop gas mixture
	btfss	timebase_1sec				; on even second?
	bra		TFT_active_sp_print			; YES - print ppO2 with normal rendering
	btfsc	warn_det_sensors_lost		; NO  - all sensors lost?
	bra		TFT_active_sp_fallback		;       YES - process fallback case
	movff	int_O_breathed_ppO2+1,WREG	;       NO  - get flags again (have been cleared in hi:lo by TFT_color_code_ppo2 meanwhile)
	btfss	WREG,int_warning_flag		;             warning flag set?
	bra		TFT_active_sp_print			;             NO  - ppO2 is ok, print ppO2 with normal rendering
	bra		TFT_active_sp_invers		;             YES - print with inverse rendering
TFT_active_sp_fallback:					; set up fallback case
	FONT_COLOR_ATTENTION				; set color to attention
TFT_active_sp_invers:
	bsf		win_invert					; print in inverse
TFT_active_sp_print:
	WIN_MEDIUM dm_active_gas_sp_value_col, dm_active_gas_sp_value_row
	bsf		decimal_digit2				; place a decimal point in front of digit 2
	output_999							; print ppO2 (0.00-9.99)
	PRINT								; dump to screen

	btfsc	sign_shown					; advice/attention/warning sign shown?
	bra		TFT_active_diluent			; YES - do not overwrite in case of alternative layout

	btfsc	velocity_active_vsi			; graphical vertical speed indicator shown?
	bra		TFT_active_diluent			; YES - do not overwrite in case of alternative layout

TFT_active_sp_label_1:
	WIN_STD dm_active_sp_label_col, dm_active_sp_label_row
	FONT_COLOR_MEMO						; select memo color
	STRCAT	"bar"						; print "bar"

 IFDEF _external_sensor

	movf	dive_ccr_mode,W				; get setpoint mode =0: Fixed SP, =1: Sensor, =2: Auto SP
	sublw	.1							; dive_ccr_mode = 1 (Sensor) ?
	bnz		TFT_active_sp_label_2		; NO  - skip
	btfsc	alt_layout_active			; YES - in alternative layout?
	bra		TFT_active_sp_label_2		;       YES - no space available for the "*"
	PUTC	"*"							;       NO  - append "*"

 ENDIF

TFT_active_sp_label_2:
	PRINT								; dump buffer to screen

TFT_active_loop_mode:
	WIN_TINY dm_active_sp_label_col, dm_active_dil_row+.3
	FONT_COLOR_MEMO						; set memo color
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
	btfss	better_dil_blinking			;     - blink now?
	bra		TFT_active_diluent_show		;       NO  - print in normal rendering
	FONT_COLOR_ATTENTION				;       YES - print in attention color
	bsf		win_invert					;           - print in inverse

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
	FONT_COLOR_ATTENTION				;       YES - blink in attention color
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
	call	gaslist_strcat_mix			; print "Nxlo", "Txlo/hi", "Air" or "O2"
	PRINT								; dump to screen
	return								; done


;-----------------------------------------------------------------------------
; Dive Mode - NDL Time
;
	global	TFT_show_ndl
TFT_show_ndl:
	btfsc	dive_main_menu				; is the dive mode menu shown?
	return								; YES - abort
	MOVII	int_O_NDL_norm,mpr			; NO  - get NDL time in normal plan
	rcall	TFT_show_ndl_tts_set_color	;     - set color
	btfsc	deco_locked					;     - was the dive in deco?
	bra		TFT_show_ndl_norm			;       YES - use normal layout
	btfsc	alt_layout_active			;       NO  - alternative layout active?
	bra		TFT_show_ndl_alt			;             YES - use alternative layout
	;bra	TFT_show_ndl_norm			;             NO  - use normal layout

TFT_show_ndl_norm:
	WIN_MEDIUM dm_ndl_value_col_norm,dm_ndl_value_row_norm
	output_256							; print NDL (0-255)
	PUTC_PRINT "'"						; append unit and dump buffer to screen
	return								; done

TFT_show_ndl_alt:
	btfsc	safety_stop_active			; is the safety stop active?
	bra		TFT_show_ndl_alt_safety		; YES
	;bra	TFT_show_ndl_alt_no_safety	; NO

TFT_show_ndl_alt_no_safety:				; clear potential remains from NDL normal
	WIN_BOX_BLACK dm_ndl_value_row_norm, dm_3rdrow_bot, dm_ndl_value_col_norm, dm_ndl_value_col_alt ; top, bottom, left, right
	WIN_LARGE dm_ndl_value_col_alt, dm_ndl_value_row_alt
	output_99							; print NDL (0-99)
	PRINT								; dump buffer to screen
	return								; done

TFT_show_ndl_alt_safety:
	WIN_MEDIUM dm_ndl_value_col_norm,dm_ndl_value_row_norm
	output_256							; print NDL (0-255)
	PUTC_PRINT "'"						; append unit and dump buffer to screen
	return								; done


	; Helper Function - set color
TFT_show_ndl_tts_set_color:
	movf	pallet_color_memo,W			; load memo color as default
	btfsc	mpr+1,int_invalid_flag		; is the invalid flag set?
	movf	pallet_color_disabled,W		; YES - replace by disabled color
	movwf	font_color					; set font color
	return								; done


;-----------------------------------------------------------------------------
; Dive Mode - TTS Time
;
	global	TFT_show_tts
TFT_show_tts:
	btfsc	dive_main_menu				; is the dive mode menu shown?
	return								; YES - abort
	MOVII	int_O_TTS_norm,mpr			; NO  - get the TTS
	rcall	TFT_show_ndl_tts_set_color	;     - color-code
	bcf		hi,int_invalid_flag			;     - clear the invalid flag if applicable
	btfsc	alt_layout_active			;     - in alternative layout?
	bra		TFT_display_tts_alt			;       YES
	;bra	TFT_display_tts_norm		;       NO

TFT_display_tts_norm:
	WIN_MEDIUM dm_tts_value_col_999x, dm_tts_value_row
	output_999							; print (0...999)
	PUTC_PRINT "'"						; append unit and dump buffer to screen
	return								; done

TFT_display_tts_alt:
	output_99							; print TTS for range 0-99
	btfsc	output_overflow				; does TTS fit into 0-99 ?
	bra		TFT_display_tts_alt_999		; NO  - print in 999 format
	;bra	TFT_display_tts_alt_99		; YES - print in  99 format

TFT_display_tts_alt_99:
	btfsc	tts_over_99_last			; was TTS > 99 last time?
	rcall	TFT_display_tts_clear		; YES - clear remains from TTS > 99
	WIN_MEDIUM dm_tts_value_col_99, dm_tts_value_row
	output_99							; print TTS (0...99)
	PUTC_PRINT "'"						; append unit and dump buffer to screen
	return								; done

TFT_display_tts_alt_999:
	WIN_MEDIUM dm_tts_value_col_999, dm_tts_value_row
	REINIT_BUFFER						; clear the buffer
	output_999							; print (0...999), no space for unit
	PRINT								; dump to screen
	bsf		tts_over_99_last			; remember last TTS was > 99 mins
	return								; done


	; Helper Function - clear remains from TTS > 99
TFT_display_tts_clear:					; clear remains from TTS > 99
	WIN_BOX_BLACK dm_tts_value_row, dm_tts_value_row+.31, dm_tts_value_col_999, dm_tts_value_col_99 ; top, bottom, left, right
	bcf		tts_over_99_last			; remember last TTS was NOT > 99 mins
	return								; done


;-----------------------------------------------------------------------------
; Dive Mode - Deco Stop Time & Depth
;
	global	TFT_show_deco
TFT_show_deco:
	btfsc	dive_main_menu				; is the dive mode menu shown?
	return								; YES - abort

	movff	char_O_deco_depth,lo		; get depth of first stop in meters
	call	TFT_color_code_stop			; color-code output
	TSTOSC	opt_units					; get unit (0=m, 1=ft)
	bra		TFT_show_deco_norm			; 1 - ft can only be displayed in normal layout due to space required for 3 digit depth
	btfsc	alt_layout_active			; 0 - in alternative layout?
	bra		TFT_show_deco_alt			;     YES
	;bra	TFT_show_deco_norm			;     NO  - combined depth and time

TFT_show_deco_norm:
	WIN_MEDIUM dm_decostop_col_norm, dm_decostop_row_norm
	call	TFT_display_stop_depth		; print stop (depth in lo)
	PUTC	' '							; put a space char between depth and time
	bra		TFT_display_deco_common		; continue with common part

TFT_show_deco_alt:
	WIN_LARGE  dm_decostop_col_alt_depth, dm_decostop_row_alt_depth
	output_99							; print stop depth (0-99)
	PRINT								; dump buffer to screen
	WIN_MEDIUM dm_decostop_col_alt_time,  dm_decostop_row_alt_time
	FONT_COLOR_MEMO						; select memo color
	;bra	TFT_display_deco_common		; continue with common part

TFT_display_deco_common:
	movff	char_O_deco_time,lo			; get stop time of the first stop in minutes
	output_99DD							; print minutes or double dots if null
	PUTC_PRINT "'"						; append unit and dump buffer to screen
	return								; done


;=============================================================================
tft_out7	CODE
;=============================================================================

;-----------------------------------------------------------------------------
; Dive Mode - Apnoe current and overall Dive Time
;
	global	TFT_show_apnoe_times
TFT_show_apnoe_times:
	; current dive time
	FONT_COLOR_MEMO						; select color
	WIN_MEDIUM dm_divetime_apnoe_col, dm_divetime_apnoe_row
	SMOVII	apnoe_dive_mins,mpr			; ISR-safe copy of minutes to lo and seconds to hi
	output_99							; print minutes (0-99)
	PRINT								; dump to screen
	WIN_SMALL	dm_divetime_apnoe_secs_col, dm_divetime_apnoe_secs_row
	PUTC	':'							; print ":"
	movff	hi,lo						; copy  seconds to lo
	output_99x							; print seconds (00-99)
	PRINT								; dump to screen
	; overall dive time
	WIN_MEDIUM dm_apnoe_total_divetime_col, dm_apnoe_total_divetime_row
	SMOVTT	counted_divetime_mins,mpr	; ISR-safe 3 byte copy of minutes:2 and seconds
	output_256							; minutes (0-256)
	PRINT								; show minutes in large font
	WIN_SMALL dm_apnoe_total_divetime_secs_col, dm_apnoe_total_divetime_secs_row ; left position for two sec figures
	PUTC	':'							; print ":"
	movff	up,lo						; copy seconds from up to lo
	output_99x							; print seconds (00-99)
	PRINT								; dump to screen
	return								; done


;-----------------------------------------------------------------------------
; Dive Mode - show Apnoe Surface Time
;
	global	TFT_show_apnoe_surface
TFT_show_apnoe_surface:
	FONT_COLOR_MASK						; select mask color
	WIN_TINY dm_apnoe_surface_time_text_col, dm_apnoe_surface_time_text_row
	STRCPY_TEXT_PRINT tApnoeSurface		; print label
	FONT_COLOR_MEMO						; select memo color
	WIN_MEDIUM dm_apnoe_surface_time_column, dm_apnoe_surface_time_row
	SMOVII	apnoe_surface_mins,mpr		; ISR-safe copy of minutes to lo and seconds to hi
	output_256							; print minutes (0-255)
	PUTC	':'							; print ":"
	movff	hi,lo						; copy  seconds to lo
	output_99x							; print seconds (00-99)
	PRINT								; dump to screen
	return								; done


;-----------------------------------------------------------------------------
; Dive Mode - clear Apnoe Surface Time
;
	global	TFT_clear_apnoe_surface
TFT_clear_apnoe_surface:
	WIN_BOX_BLACK dm_apnoe_last_max_depth_text_row, .239, dm_apnoe_last_max_depth_column, .159
	return								; done


;=============================================================================
tft_out8	CODE
;=============================================================================


;-----------------------------------------------------------------------------
; Dive Mode - clear Deco Data (NDL / Stop & TTS )
;
	global	TFT_clear_deco_data
TFT_clear_deco_data:
	btfsc	dive_main_menu				; is the dive mode menu shown?
	return								; YES

	WIN_BOX_BLACK dm_decostop_row_alt_depth, dm_3rdrow_bot, dm_decostop_col_alt_depth, dm_3rdrow_rgt	; top, bottom, left, right
	return


;-----------------------------------------------------------------------------
; Dive Mode - clear Dive Mode Menu
;
; starts 2 pixel higher to completely wipe away the temperature display
;
	global	TFT_clear_divemode_menu
TFT_clear_divemode_menu:
	WIN_BOX_BLACK	dm_menu_row-.2, dm_menu_lower, dm_menu_left, dm_menu_right
	return


;=============================================================================
VSI_table	CODE_PACK
;=============================================================================

VSI_table:

	; use a depth-dependent ascent rate warning
	; depth(ft):     <20 >20 >40 >60 >75 >88 >101 >115 >128 >144 >164
	; speed(ft/min):  23  26  29  33  36  43   49   56   59   62   66
	; depth(m):      <=6  >6 >12 >18 >23 >27  >31  >35  >39  >44  >50
	; speed(m/min):    7   8   9  10  11  13   15   17   18   19   20 (warning)
	; speed(m/min):    5   6   7   8   8  10   12   13   14   15   15 (attention)

	; < depth (m), warning speed, attention speed
	DB    .6, .7, .5
	DB   .12, .8, .6
	DB   .18, .9, .7
	DB   .23,.10, .8
	DB   .27,.11, .8
	DB   .31,.13,.10
	DB   .35,.15,.12
	DB   .39,.17,.13
	DB   .44,.18,.14
	DB   .50,.19,.15
	DB  .255,.20,.15


;=============================================================================
tft_out9	CODE
;=============================================================================


;-----------------------------------------------------------------------------
; Dive Mode - show vertical Velocity
;
	global	TFT_velocity_show
TFT_velocity_show:
	FONT_COLOR_MEMO						; set default color
	btfsc	neg_flag_velocity			; descending?
	rcall	TFT_velocity_set_color		; NO - set color for text dependent on speed and set threshold for VSI graph
	rcall	TFT_velocity_num			; show the numerical VSI
	TSTOSS	opt_vsigraph				; graphical VSI bar enabled?
	return								; NO  - done
	btfss	neg_flag_velocity			; YES - in ascent?
	bra		TFT_velocity_clear_graph	;       NO  - clear the graph
	;bra	TFT_velocity_graph_show		;       YES - show  the graph

TFT_velocity_graph_show:
	btfsc	alt_layout_active			; in alternative layout?
	return								; YES - done (not implemented)

	btfsc	velocity_active_vsi			; was the graphical VSI shown before?
	bra		TFT_velocity_graph_1		; YES - no need to redraw the framework box
	bsf		velocity_active_vsi			; NO  - remember it is shown as of now
										;     - draw the framework box
	movf	pallet_color_mask,W			;     - color -> WREG
	WIN_FRAME_COLOR	dm_velocity_graph_top+.00, dm_velocity_graph_bot-.00, dm_velocity_graph_lft, dm_velocity_graph_rgt
	movf	pallet_color_mask,W			;     - color -> WREG
	WIN_FRAME_COLOR	dm_velocity_graph_top+.10, dm_velocity_graph_bot-.10, dm_velocity_graph_lft, dm_velocity_graph_rgt
	movf	pallet_color_mask,W			;     - color -> WREG
	WIN_FRAME_COLOR	dm_velocity_graph_top+.20, dm_velocity_graph_bot-.20, dm_velocity_graph_lft, dm_velocity_graph_rgt
	movf	pallet_color_mask,W			;     - color -> WREG
	WIN_FRAME_COLOR	dm_velocity_graph_top+.30, dm_velocity_graph_bot-.30, dm_velocity_graph_lft, dm_velocity_graph_rgt

TFT_velocity_graph_1:
	movff	divA+0,hi					; copy ascend speed (in m/min) to hi
	movff	divA+1,xA+0					; m/min for warning level (upper two blocks)
	clrf	xA+1
	MOVLI	.5,xB						; threshold for color warning (5 color normal + 2 color warning)
	call	div16x16					; xC = xA / xB with xA as remainder
	; xC+0 holds step size in m/min (e.g. =3 for 15m/min warning threshold)
	movff	hi,xA+0						; velocity in m/min
	clrf	xA+1						; ...
	movff	xC+0,xB+0					; step size
	clrf	xB+1						; ...
	call	div16x16					; xC = xA / xB with xA as remainder
	movff	xC+0,lo						; copy amount of segments to show to lo
	incf	lo,F						; lo +=1
	dcfsnz	lo,F						; lo = 1 ?
	bra		DISP_graph_vel_0_fill		; YES - fill lowest  segment
	dcfsnz	lo,F						; lo = 2 ?
	bra		DISP_graph_vel_1_fill		; YES - fill lower 2 segments
	dcfsnz	lo,F						; lo = 3 ?
	bra		DISP_graph_vel_2_fill		; YES - fill lower 3 segments
	dcfsnz	lo,F						; lo = 4 ?
	bra		DISP_graph_vel_3_fill		; YES - fill lower 4 segments
	dcfsnz	lo,F						; lo = 5 ?
	bra		DISP_graph_vel_4_fill		; YES - fill lower 5 segments
	dcfsnz	lo,F						; lo = 6 ?
	bra		DISP_graph_vel_5_fill		; YES - fill lower 6 segments
	dcfsnz	lo,F						; lo = 7 ?
	bra		DISP_graph_vel_6_fill		; YES - fill lower 7 segments
	;bra	DISP_graph_vel_7_fill		; YES - fill all     segments

DISP_graph_vel_7_fill:
	movf	pallet_color_warning,W
	WIN_BOX_COLOR dm_velocity_graph_top+.2,  dm_velocity_graph_top+.8,  dm_velocity_graph_lft+.2, dm_velocity_graph_rgt-.2 ;top, bottom, left, right
DISP_graph_vel_6_fill:
	movf	pallet_color_warning,W
	WIN_BOX_COLOR dm_velocity_graph_top+.12, dm_velocity_graph_top+.18, dm_velocity_graph_lft+.2, dm_velocity_graph_rgt-.2 ;top, bottom, left, right
DISP_graph_vel_5_fill:
	movf	pallet_color_attention,W
	WIN_BOX_COLOR dm_velocity_graph_top+.22, dm_velocity_graph_top+.28, dm_velocity_graph_lft+.2, dm_velocity_graph_rgt-.2 ;top, bottom, left, right
DISP_graph_vel_4_fill:
	movf	pallet_color_memo,W
	WIN_BOX_COLOR dm_velocity_graph_top+.32, dm_velocity_graph_top+.38, dm_velocity_graph_lft+.2, dm_velocity_graph_rgt-.2 ;top, bottom, left, right
DISP_graph_vel_3_fill:
	movf	pallet_color_memo,W
	WIN_BOX_COLOR dm_velocity_graph_top+.42, dm_velocity_graph_top+.48, dm_velocity_graph_lft+.2, dm_velocity_graph_rgt-.2 ;top, bottom, left, right
DISP_graph_vel_2_fill:
	movf	pallet_color_memo,W
	WIN_BOX_COLOR dm_velocity_graph_top+.52, dm_velocity_graph_top+.58, dm_velocity_graph_lft+.2, dm_velocity_graph_rgt-.2 ;top, bottom, left, right
DISP_graph_vel_1_fill:
	movf	pallet_color_memo,W
	WIN_BOX_COLOR dm_velocity_graph_top+.62, dm_velocity_graph_top+.68, dm_velocity_graph_lft+.2, dm_velocity_graph_rgt-.2 ;top, bottom, left, right
DISP_graph_vel_0_fill:

	movff	xC+0,lo						; copy amount of segments to show to lo
	incf	lo,F						; lo += 1
	dcfsnz	lo,F						; lo = 1 ?
	bra		DISP_graph_vel_0_clear		; YES - clear upper 7 segments
	dcfsnz	lo,F						; lo = 2 ?
	bra		DISP_graph_vel_1_clear		; YES - clear upper 6 segments
	dcfsnz	lo,F						; lo = 3 ?
	bra		DISP_graph_vel_2_clear		; YES - clear upper 5 segments
	dcfsnz	lo,F						; lo = 4 ?
	bra		DISP_graph_vel_3_clear		; YES - clear upper 4 segments
	dcfsnz	lo,F						; lo = 5 ?
	bra		DISP_graph_vel_4_clear		; YES - clear upper 3 segments
	dcfsnz	lo,F						; lo = 6 ?
	bra		DISP_graph_vel_5_clear		; YES - clear upper 2 segments
	dcfsnz	lo,F						; lo = 7 ?
	bra		DISP_graph_vel_6_clear		; YES - clear upper 1 segments
	bra		DISP_graph_vel_7_clear		; YES - clear no      segments

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
	return								; done


	; Helper Function - set color based on speed table or use static thresholds, with divA+0 = m/min
TFT_velocity_set_color:
	bsf		aux_flag						; for alternative layout: default is to show numerical VSI
	; check if old/new ascend logic is used
	TSTOSS	opt_vsitext						; 0=standard, 1=dynamic
	bra		TFT_velocity_set_color_static	; 0 - static  ascend rate limit
	;bra	TFT_velocity_set_color_dynamic	; 1 - dynamic ascend rate limit

TFT_velocity_set_color_dynamic:
	movlw	LOW   (VSI_table-.2)		; point to 2 entries ahead of the speed table
	movwf	TBLPTRL						; ...
	movlw	HIGH  (VSI_table-.2)		; ...
	movwf	TBLPTRH						; ...
	movlw	UPPER (VSI_table-.2)		; ...
	movwf	TBLPTRU						; ...
TFT_velocity_set_color_loop:
	TBLRD*+								; consume waring    speed form last round
	TBLRD*+								; consume attention speed form last round
	TBLRD*+								; get table   depth
	movf	depth_meter,W				; get current depth
	cpfsgt	TABLAT						; table depth > current depth ?
	bra		TFT_velocity_set_color_loop	; NO  - try next
	TBLRD*+								; YES - read warning speed threshold
	movf	TABLAT,W					;     - ...
	movwf	divA+1						;     - copy to graph routine
	cpfslt	divA+0						;     - actual vertical speed smaller than warning threshold?
	bra		TFT_velocity_set_color_warn	;       NO - set warning color and return
	TBLRD*+								;       YES - read attention speed threshold
	movf	TABLAT,W					;           - ...
	cpfslt	divA+0						;           - actual vertical speed smaller than attention threshold?
	bra		TFT_velocity_set_color_attn	;             NO  - set attention color and return
	bcf		aux_flag					;             YES - don't show in alternative layout
	bra		TFT_velocity_set_color_memo	;                 - set memo color and return

TFT_velocity_set_color_static:
	movlw	color_code_velocity_warn_high	; get static threshold for warning in m/min
	movwf	divA+1							; copy for graph routine
	cpfslt	divA+0							; actual vertical speed smaller than warning threshold?
	bra		TFT_velocity_set_color_warn		; NO  - set warning color and return
	movlw	color_code_velocity_attn_high	; YES - get static threshold for attention in m/min
	cpfslt	divA+0							;     - actual vertical speed smaller than attention threshold?
	bra		TFT_velocity_set_color_attn		;       NO  - set attention color and return
	bcf		aux_flag						;       YES - don't show in alternative layout
	;bra	TFT_velocity_set_color_memo		;           - set memo color and return


	; Helper Function - select color
TFT_velocity_set_color_memo:
	FONT_COLOR_MEMO						; select memo color
	return								; done

TFT_velocity_set_color_attn:
	FONT_COLOR_ATTENTION				; select attention color
	return								; done

TFT_velocity_set_color_warn:
	FONT_COLOR_WARNING					; select warning color
	return								; done


	; Helper Function - show the numerical VSI
TFT_velocity_num:
	btfsc	alt_layout_active			; in alternative layout?
	bra		TFT_velocity_num_alt		; YES
	;bra	TFT_velocity_num_norm		; NO

TFT_velocity_num_norm:
	WIN_SMALL dm_velocity_text_col_norm, dm_velocity_text_row_norm
	bra		TFT_velocity_num_com		; continue with common part

TFT_velocity_num_alt:
	btfsc	dive_main_menu				; is the dive mode menu shown?
	return								; YES - abort
	btfss	neg_flag_velocity			; NO  - in ascent?
	bcf		aux_flag					;       NO  - clear aux flag
	btfsc	aux_flag					;     - above attention or warning threshold?
	bsf		win_invert					;       YES - print inverse
	WIN_SMALL dm_velocity_text_col_alt, dm_velocity_text_row_alt
	;bra	TFT_velocity_num_com		;     - continue with common part

TFT_velocity_num_com:
	bsf		velocity_active_num			; set numerical velocity as shown
	TSTOSS	opt_units					; 0=meter, 1=feet
	bra		TFT_velocity_num_metric		; 0 - meter
	;bra	TFT_velocity_num_imperial	; 1 - feet

TFT_velocity_num_imperial:
	movff	divA+0,WREG					; divA+0 = m/min
	mullw	.100						; PROD   = mbar/min
	MOVII	PRODL,mpr					; copy to hi:lo
	call	convert_cm_to_feet			; convert value in hi:lo from [cm] to [feet]
	tstfsz	hi							; > 255 ?
	setf	lo							; YES - set lo to 255
	rcall	TFT_velocity_num_helper		; print vertical speed
	STRCAT_TEXT tVelImperial			; print unit
	bra		TFT_velocity_num_finish		; do finishing tasks

TFT_velocity_num_metric:
	movff	divA+0,lo					; divA+0 = m/min
	rcall	TFT_velocity_num_helper		; print vertical speed
	STRCAT_TEXT tVelMetric				; print unit
	;bra	TFT_velocity_num_finish		; do finishing tasks

TFT_velocity_num_finish:
	btfss	alt_layout_active			; in alternative layout?
	bra		TFT_velocity_num_finish_1	; NO
	movlw	"'"							; load encoding of minute sign
	movff	WREG,buffer+4				; put it after m (meter) / f (feet)
	clrf	WREG						; load string terminator
	movff	WREG,buffer+5				; terminate string after minute sign
TFT_velocity_num_finish_1:
	PRINT								; dump to screen
	return								; done


	; Helper Function - print vertical speed
TFT_velocity_num_helper:
	movlw	'-'							; load coding for minus sign
	btfsc	neg_flag_velocity			; ascending?
	movlw	'+'							; YES - replace with coding for plus sign
	movwf	POSTINC2					; put sign into output buffer
	output_99							; print rate (0-99)
	return								; done


;-----------------------------------------------------------------------------
; Dive Mode - clear vertical Velocity
;
	global	TFT_velocity_clear
TFT_velocity_clear:
	btfss	velocity_active_num			; was the numerical VSI shown in last cycle?
	bra		TFT_velocity_check_graph	; NO  - no need to clear it, continue with graphical VSI
	;bra	TFT_velocity_clear_num		; YES

TFT_velocity_clear_num:
	bcf		velocity_active_num			; clear flag
	btfsc	alt_layout_active			; in alternative layout?
	bra		TFT_velocity_clear_num_alt	; YES
	;bra	TFT_velocity_clear_num_norm	; NO

TFT_velocity_clear_num_norm:			; clear normal numerical area
	WIN_BOX_BLACK dm_velocity_text_row_norm, dm_velocity_text_bot_norm, dm_velocity_text_col_norm, dm_velocity_text_rgt_norm
	bra		TFT_velocity_check_graph	; continue with graphical VSI

TFT_velocity_clear_num_alt:				; clear alternative numerical area
	btfsc	dive_main_menu				; is the dive mode menu shown?
	bra		TFT_velocity_check_graph	; YES - skip
	WIN_BOX_BLACK dm_velocity_text_row_alt,  dm_velocity_text_bot_alt,  dm_velocity_text_col_alt,  dm_velocity_text_rgt_alt
	;bra	TFT_velocity_check_graph	; continue with graphical VSI

TFT_velocity_check_graph:
	btfss	velocity_active_vsi			; was the graphical VSI shown in last cycle?
	return								; NO  - no need to clear it, done
	;bra	TFT_velocity_clear_graph	; YES - clear it

TFT_velocity_clear_graph:
	bcf		velocity_active_vsi			; clear flag
	btfsc	alt_layout_active			; in alternative layout?
	return								; YES - done (not implemented)
	WIN_BOX_BLACK dm_velocity_graph_top, dm_velocity_graph_bot, dm_velocity_graph_lft, dm_velocity_graph_rgt
	return								; done


;=============================================================================
tft_out10	CODE
;=============================================================================


;-----------------------------------------------------------------------------
; Dive Mode - show Sign
;
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
	bsf		sign_shown					; flag sign is shown
	btfsc	sign_warning				; shall show warning sign?
	bra		TFT_divemode_sign_show_warn	; YES - show warning sign
	btfsc	sign_attention				; NO  - shall show attention sign?
	bra		TFT_divemode_sign_show_att	;       YES - show attention sign
	btfsc	sign_advice					;       NO  - shall show advice sign?
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


;-----------------------------------------------------------------------------
; Dive Mode - show Sign
;
	global	TFT_divemode_sign_clear
TFT_divemode_sign_clear:
	btfss	sign_shown					; is the advice/attention/warning sign shown?
	return								; NO  - done
	bcf		sign_shown					; YES - clear flag
	btfsc	alt_layout_active			;     - alternative layout active?
	bra		TFT_divemode_sign_clear_alt	;     - YES
	;bra	TFT_divemode_sign_clear_norm;     - NO

TFT_divemode_sign_clear_norm:
	WIN_BOX_BLACK dm_sign_row_norm, dm_sign_bot_norm, dm_sign_col_norm, dm_sign_rgt_norm
	return								; done

TFT_divemode_sign_clear_alt:
	WIN_BOX_BLACK dm_sign_row_alt, dm_sign_bot_alt, dm_sign_col_alt, dm_sign_rgt_alt
	return								; done


;=============================================================================
tft_out11	CODE
;=============================================================================


;-----------------------------------------------------------------------------
; Dive Mode - show Safety Stop
;
	global	TFT_safety_stop_show
TFT_safety_stop_show:
	btfsc	dive_main_menu				; is the dive mode menu shown?
	return								; YES - abort
	btfsc	safety_stop_active			; NO  - is the safety stop shown already?
	bra		TFT_safety_stop_show_time	;       YES - just update the time
										;       NO  - clear area that may be polluted by alternative NDL
	WIN_BOX_BLACK dm_safetystop_row, dm_tts_value_row, dm_ndl_value_col_alt, dm_safetystop_rgt ; top, bottom, left, right
	bsf		safety_stop_active			;           - flag safety stop is shown now
	WIN_STD dm_safetystop_text_column, dm_safetystop_text_row
	FONT_COLOR_MASK						;           - set color
	STRCPY_PRINT "Stop "				;           - print "Stop" with a trailing space to wipe away potential other remains

TFT_safety_stop_show_time:
	WIN_MEDIUM dm_safetystop_column, dm_safetystop_row
	FONT_COLOR_ATTENTION				; set color
	movff	safety_stop_countdown,lo	; get remaining time in seconds, low  byte, from safety stop timer
	clrf	hi							; set remaining time in seconds, high byte, to zero
	call	convert_time				; convert hi:lo in seconds to minutes (up:hi) and seconds (lo)
	movff	lo,up						; save seconds in up
	movff	hi,lo						; move minutes to lo
	output_9							; print minutes (0-9)
	PUTC	':'							; print ":"
	movff	up,lo						; move seconds to lo
	output_99x							; print seconds (00-99)
	PRINT								; dump buffer to screen
	return								; done


;-----------------------------------------------------------------------------
; Dive Mode - clear Safety Stop
;
	global	TFT_safety_stop_clear
TFT_safety_stop_clear:
	btfsc	dive_main_menu				; is the dive mode menu shown?
	return								; YES - abort
	btfss	safety_stop_active			; NO  - is the safety stop shown?
	return								;       NO  - done, nothing to do
										;       YES - clear safety stop area
	WIN_BOX_BLACK dm_safetystop_row, dm_safetystop_bot, dm_safetystop_text_column, dm_safetystop_rgt ; top, bottom, left, right
	bcf		safety_stop_active			;           - safety stop not shown any more
	btfss	deco_region					;           - was the dive within deco stops region?
	return								;             NO  - done
	;bra	TFT_show_slow_reminder		;             YES - show "SLOW" reminder


;-----------------------------------------------------------------------------
; Dive Mode - show "slow" Reminder
;
TFT_show_slow_reminder:
	WIN_STD dm_safetystop_text_column+.5,dm_safetystop_text_row+.5
	FONT_COLOR_ATTENTION				; set color
	STRCPY_TEXT  tSlow					; print "SLOW" reminder
	STRCAT_PRINT 0x94					; append an up-arrow
	return								; done


;=============================================================================
tft_out12	CODE
;=============================================================================


;-----------------------------------------------------------------------------
; clear complete Message Window
;
	global	TFT_clear_message_window
TFT_clear_message_window:
	btfss	divemode						; in dive mode?
	bra		TFT_clear_message_window_surf	; NO  - clear surface mode area
	;bra	TFT_clear_message_window_dive	; YES - clear dive    mode area

TFT_clear_message_window_dive:
	btfsc	alt_layout_active				; in alternative layout?
	bra		TFT_clear_message_window_dive_2	; YES - clear dive mode area, 2nd  row only

	WIN_BOX_BLACK dm_warning_row, dm_warning_bot, dm_warning_column, dm_warning_rgt
	return									; done

TFT_clear_message_window_surf:
	WIN_BOX_BLACK surf_warning1_row, surf_warning2_row+.24, surf_warning1_column, surf_warning1_column+.76	; top, bottom, left, right
	return									; done


;-----------------------------------------------------------------------------
; clear 2nd Line of Message Window
;
	global	TFT_clear_message_window_row2
TFT_clear_message_window_row2:
	bcf		message_2nd_row_used			; 2nd row is cleared
	btfss	divemode						; in dive mode?
	bra		TFT_clear_message_window_surf_2	; NO  - clear surface mode area, 2nd row only
	;bra	TFT_clear_message_window_dive_2	; YES - clear dive    mode area, 2nd row only

TFT_clear_message_window_dive_2:
	WIN_BOX_BLACK dm_warning2_row, dm_warning2_bot, dm_warning2_column, dm_warning2_rgt
	return									; done

TFT_clear_message_window_surf_2:
	WIN_BOX_BLACK surf_warning2_row, surf_warning2_row+.24, surf_warning2_column, surf_warning2_column+.76	; top, bottom, left, right
	return									; done

;-----------------------------------------------------------------------------
; Surface Mode - Message - when "I2CFail" was triggered
;
	global	TFT_message_i2c_error
TFT_message_i2c_error:	
	rcall	TFT_message_open			; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO - skip message in this cycle
	STRCPY	"I2C "						; print "I2C Error:"
	movff	i2c_error_vault+0,WREG				; last device adress
	output_hex
	PUTC	" "
	movff	i2c_error_vault+1,WREG				; last data byte 
	output_hex
	bra		TFT_message_close			; finalize message output

;-----------------------------------------------------------------------------
; Surface Mode - Message - Desaturation
;
	global	TFT_surf_mesg_desat
TFT_surf_mesg_desat:
	rcall	TFT_message_open			; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO - skip message in this cycle

	FONT_COLOR_MEMO						; select color
	STRCPY	"Desat:"					; print label
	MOVII	int_O_desaturation_time,mpr	; get desaturation time in minutes
	bra		TFT_dsat_nofly_common		; continue with common part


;-----------------------------------------------------------------------------
; Surface Mode - Message - No-Fly / NO-Altitude
;
	global	TFT_surf_mesg_nofly
TFT_surf_mesg_nofly:
	rcall	TFT_message_open			; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO - skip message in this cycle

	FONT_COLOR_MEMO						; select color
	movff	char_I_altitude_wait,WREG	; get mode
	tstfsz	WREG						; mode = altitude?
	bra		TFT_nofly_time_alt			; YES
	;bra	TFT_nofly_time_fly			; NO

TFT_nofly_time_fly:
	STRCPY	"NoFly:"					; print no-fly label
	bra		TFT_nofly_time_com			; continue

TFT_nofly_time_alt:
	STRCPY	"NoAlt:"					; print no-altitude label
	;bra	TFT_nofly_time_com			; continue

TFT_nofly_time_com:
	MOVII	int_O_nofly_time,mpr		; get no-fly time in minutes
	;bra	TFT_dsat_nofly_common		; continue with common part


	; Helper Function - common part for TFT_surf_mesg_desat and TFT_surf_mesg_nofly
TFT_dsat_nofly_common:
	call	convert_time				; convert hi:lo in minutes to hours (up:hi) and minutes (lo)
	movff	lo,up						; backup lo
	movff	hi,lo						; get   hours into lo
	output_99							; print hours (0-99)
	PUTC	':'							; print ":"
	movff	up,lo						; get   minutes into lo
	output_99x							; print minutes (00-99)
	bra		TFT_message_close			; finalize message output


;-----------------------------------------------------------------------------
; Dive Mode - Message - fTTS
;
	global	TFT_message_ftts
TFT_message_ftts:
	call	TFT_message_open			; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO  - skip message in this cycle

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
	bsf		leftbind					; print left-aligned
	output_99							; print waypoint number (0-99)
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
	output_9							; print fTTS delay time (0-9)
	PUTC	":"							; print ":"
TFT_display_ftts_5:
	MOVII	int_O_TTS_alt,mpr			; get alternative TTS
	FONT_COLOR_MEMO						; set memo color
	btfss	hi,int_invalid_flag			; is the invalid flag set?
	bra		TFT_display_ftts_6			; NO  - keep memo color
	bcf		hi,int_invalid_flag			; YES - clear flag
	FONT_COLOR_DISABLED					;     - switch to disabled color
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
	movff	char_O_deco_info,WREG		; NO  - get deco info vector
	btfsc	WREG,deco_zone				;     - fTTS <= TTS ?
	FONT_COLOR_ADVICE					;       YES - set to advice color (green)
TFT_display_ftts_7:
	bsf		leftbind					; print left-aligned
	output_999							; print ascent time (0-999)
	PUTC	"'"							; print minutes symbol
	bra		TFT_message_close			; finalize message output
TFT_display_ftts_8:
	STRCAT	"---"						; print "---" for not computed
	bra		TFT_message_close			; finalize message output
TFT_display_ftts_9:
	STRCAT_TEXT tNDL					; print "NDL"
	bra		TFT_message_close			; finalize message output


;-----------------------------------------------------------------------------
; Dive Mode - Message - ppO2
;
	global	TFT_message_ppo2
TFT_message_ppo2:
	call	TFT_message_open			; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO - skip message in this cycle

	call	TFT_color_code_ppo2			; color-code output

	btfsc	bailout_mode				; in bailout?
	bra		TFT_display_diluent_oc		; YES - bailout (OC)
	btfsc	FLAG_ccr_mode				; NO  - in CCR mode?
	bra		TFT_display_diluent_ccr		;       YES - CCR
	btfsc	FLAG_pscr_mode				;       NO  - in pSCR mode?
	bra		TFT_display_diluent_pscr	;             YES - pSCR
	;bra	TFT_display_diluent_oc		;             NO  - OC

TFT_display_diluent_oc:
	STRCPY_TEXT tppO2					; bailout or OC mode, print "ppO2:"
	bra		TFT_display_diluent_comm	; continue with ppO2 value

TFT_display_diluent_ccr:
	STRCPY_TEXT tdil					; print "Dil:"
	bra		TFT_display_diluent_comm	; continue with ppO2 value

TFT_display_diluent_pscr:
	STRCPY_TEXT tmix					; YES - print "Mix:"
	;bra	TFT_display_diluent_comm	;     - continue with ppO2 value

TFT_display_diluent_comm:
	bsf		decimal_digit2				; place a decimal point in front of digit 2
	output_999							; print ppO2 (0.00-9.99)
	bra		TFT_message_close			; finalize message output


;-----------------------------------------------------------------------------
; Dive Mode - Message - Battery
;
	global	TFT_message_battery_percent
TFT_message_battery_percent:
	rcall	TFT_message_open			; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO - skip message in this cycle

	call	TFT_color_code_battery		; color-code according to battery_low_condition flag
	STRCPY	"Batt:"						; print "Batt:"
	bsf		leftbind					; print left-aligned
	movff	batt_percent,lo				; get   battery % 
	output_256							; print battery % (0-255)
	PUTC	"%"							; print "%"
	bra		TFT_message_close			; finalize message output


;-----------------------------------------------------------------------------
; Dive Mode - Message - current CNS
;
	global	TFT_message_cns
TFT_message_cns:
	call	TFT_message_open			; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO - skip message in this cycle

	MOVII	int_O_CNS_current,mpr		; get current CNS
	call	TFT_color_code_cns			; color-code CNS output
	STRCPY_TEXT tCNS					; CNS:
	bsf		leftbind					; print left-aligned
	output_999							; print (0-999)
	PUTC	"%"							; append unit
	bra		TFT_message_close			; finalize message output


;-----------------------------------------------------------------------------
; Dive Mode - Message - End-of-Dive CNS
;
	global	TFT_message_cns_eod
TFT_message_cns_eod:
	call	TFT_message_open			; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO - skip message in this cycle

	FONT_COLOR_WARNING					; switch to warnings (red) text color
	STRCPY_TEXT tCNSeod					; end-of-dive CNS warning text
	bra		TFT_message_close			; finalize message output


;-----------------------------------------------------------------------------
; Dive Mode - Message - Saturation
;
	global	TFT_message_saturation
TFT_message_saturation
	rcall	TFT_message_open			; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO  - skip message in this cycle

	MOVII	int_O_lead_supersat,mpr		; get leading tissue's supersaturation
	call	TFT_color_code_supersat		; color-code output
	STRCPY_TEXT tSAT					; print "Sat:"
	PUTC	" "							; add a space to align the output with other warnings' outputs
	bsf		leftbind					; print left-aligned
	output_256							; print value of lo only, int_O_lead_supersat is limited to 255
	PUTC	"%"							; print "%"
	bra		TFT_message_close			; finalize message output


;-----------------------------------------------------------------------------
; Dive Mode - Message - alternative GF
;
	global	TFT_message_agf
TFT_message_agf:
	rcall	TFT_message_open			; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO  - skip message in this cycle

	FONT_COLOR_ATTENTION				; set attention color
	STRCPY_TEXT tDiveaGF_active			; print "aGF!"
	bra		TFT_message_close			; finalize message output


;-----------------------------------------------------------------------------
; Dive Mode - Message - Dive Timeout
;
	global	TFT_message_divetimeout
TFT_message_divetimeout:
	call	TFT_message_open			; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO - skip message in this cycle

	FONT_COLOR_MEMO						; select color
	STRCPY	0x94						; "End of dive" symbol (up-arrow)
	movff	opt_diveTimeout,WREG		; get timeout in minutes
	mullw	.60							; get timeout in seconds
	MOVII	PRODL,             sub_a	; calculate timeout - elapsed time = countdown
	MOVII	dive_timeout_timer,sub_b	; ...
	call	subU16						; ...
	MOVII	sub_c,mpr					; transfer to mpr
	call	convert_time				; convert hi:lo in seconds to minutes (up:hi) and seconds (lo)
	movff	lo,up						; back-up lo
	movff	hi,lo						; get   minutes
	output_99							; print minutes (0-99)
	PUTC	':'							; print ":"
	movff	up,lo						; get   seconds
	output_99x							; print seconds (00-99)
	movlw	dm_warning_length			; get dive mode string length
	rcall	TFT_buffer_trim_length		; fill / cut buffer to target length
	PRINT								; dump to screen
	return								; done


;-----------------------------------------------------------------------------
; Dive Mode - Message - Gas Needs
;
	global	TFT_message_gas_needs
TFT_message_gas_needs:
	rcall	TFT_message_open			; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO  - skip message in this cycle

	btfsc	attn_det_gas_needs			; attention?
	FONT_COLOR_ATTENTION				; YES - set attention color
	btfsc	warn_det_gas_needs			; warning?
	FONT_COLOR_WARNING					; YES - set warning color
	STRCPY_TEXT tGasNeedsWarn			; print "Gas Needs"
	bra		TFT_message_close			; finalize message output


;-----------------------------------------------------------------------------
; Dive Mode - Message - Gas Change
;
	global	TFT_message_gas_change
TFT_message_gas_change:
	rcall	TFT_message_open			; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO  - skip message in this cycle

	FONT_COLOR_ADVICE					; set advice color
	STRCPY_TEXT tgaschange				; print "Change?"
	bra		TFT_message_close			; finalize message output


;-----------------------------------------------------------------------------
; Dive Mode - Message - no Bailout Gas
;
	global	TFT_message_no_BO_gas
TFT_message_no_BO_gas:
	rcall	TFT_message_open			; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO  - skip message in this cycle

	FONT_COLOR_WARNING					; set warning color
	STRCPY_TEXT tnoBOgas				; print "-B/O-Gas-"
	bra		TFT_message_close			; finalize message output


;-----------------------------------------------------------------------------
; Message - open Message
;
; sets the row and column for the current message
;
TFT_message_open:
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
	btfsc	alt_layout_active				; in alternative layout?
	bra		TFT_set_message_window_dm_row2	; YES - alternative layout only uses 2nd row
	btfss	message_counter,0				; NO  - is the message number uneven?
	bra		TFT_set_message_window_dm_row2	;       NO  - use 2nd row
	;bra	TFT_set_message_window_dm_row1	;       YES - use 1st row

TFT_set_message_window_dm_row1:
	WIN_SMALL dm_warning1_column, dm_warning1_row
	bcf		message_2nd_row_used			; flag that the 2nd does not contain a message yet
	retlw	.0								; show in this cycle (message window is defined)

TFT_set_message_window_dm_row2:
	WIN_SMALL dm_warning2_column, dm_warning2_row
	bsf		message_2nd_row_used			; flag that the 2nd row contains a message now
	retlw	.0								; show in this cycle (message window is defined)

; Surface Mode
TFT_set_message_window_sf:
	btfss	message_counter,0				; is the message counter uneven?
	bra		TFT_set_message_window_sf_row2	; NO  - use 2nd row
	;bra	TFT_set_message_window_sf_row1	; YES - use 1st row

TFT_set_message_window_sf_row1:
	WIN_SMALL surf_warning1_column,surf_warning1_row
	bcf		message_2nd_row_used			; flag that the 2nd row does not contain a message yet
	retlw	.0								; show in this cycle (message window is defined)

TFT_set_message_window_sf_row2:
	WIN_SMALL surf_warning2_column,surf_warning2_row
	bsf		message_2nd_row_used			; flag that the 2nd row contains a message now
	retlw	.0								; show in this cycle (message window is defined)


;-----------------------------------------------------------------------------
; Message - fill to a given Length, or cut if too long
;
; Input: buffer  message
;        WREG    max length
;
	global	TFT_buffer_trim_length
TFT_buffer_trim_length:
	movwf	lo							; copy max.   string length to lo
	movf	FSR2L,W						; get current string length to WREG
	subwf	lo,F						; lo = max length - current length
	bn		TFT_fillup_with_spaces_cut	; string too long        -> cut string at max length
	bnz		TFT_fillup_with_spaces_apnd	; string too short       -> append spaces and string terminator
	bra		TFT_fillup_with_spaces_term	; string at exact length -> append            string terminator

TFT_fillup_with_spaces_apnd:
	PUTC	" "							; add one space
	decfsz	lo,F						; all spaces done?
	bra		TFT_fillup_with_spaces_apnd	; NO  - loop
	bra		TFT_fillup_with_spaces_term	; YES - append string terminator

TFT_fillup_with_spaces_cut:
	movf	lo,W						; get over-length (as negative number) into WREG
	addwf	FSR2L,F						; set back buffer pointer to end of max length
	;bra	TFT_fillup_with_spaces_term	; append string terminator

TFT_fillup_with_spaces_term:
	clrf	INDF2						; append string terminator
	return								; done


;-----------------------------------------------------------------------------
; Message - close Message
;
TFT_message_close:
	movlw	surf_warning_length			; get surface string length
	btfsc	divemode					; in dive mode?
	movlw	dm_warning_length			; YES - replace by dive mode string length
	rcall	TFT_buffer_trim_length		; fill / cut buffer to target length
	PRINT								; dump to screen
	return								; done


;-----------------------------------------------------------------------------
; Dive Mode - Message - Micro-Bubbles
;
	global	TFT_message_mbubbles
TFT_message_mbubbles:
	rcall	TFT_message_open			; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO  - skip message in this cycle

	FONT_COLOR_ATTENTION				; set attention color as default
	movff	char_O_deco_warnings,WREG	; bank-safe copy for deco warnings
	btfsc	WREG,mbubble_warning		; currently in the micro bubbles zone?
	FONT_COLOR_WARNING					; YES - reconfigure to warning color
	STRCPY_TEXT tMicroBubbles			; print message text
	bra		TFT_message_close			; finalize message output


;-----------------------------------------------------------------------------
; Dive Mode - Message - Outside Buhlmann Model
;
	global	TFT_message_outside
TFT_message_outside:
	rcall	TFT_message_open			; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO  - skip message in this cycle

	FONT_COLOR_ATTENTION				; set attention color
	movff	char_O_deco_warnings,WREG	; bank-safe copy for deco warnings
	btfsc	WREG,outside_warning		; currently outside the ZH-L16 model?
	FONT_COLOR_WARNING					; YES - reconfigure to warning color
	STRCPY	"X-ZHL16-X"					; print message text
	bra		TFT_message_close			; finalize message output


;-----------------------------------------------------------------------------
; Dive Mode - Message - Depth Limit
;
	global	TFT_message_depth_limit
TFT_message_depth_limit:
	rcall	TFT_message_open			; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO  - skip message in this cycle

	FONT_COLOR_WARNING					; set warning color
	STRCPY_TEXT tMaxDepth				; print "max.Depth"
	bra		TFT_message_close			; finalize message output


;-----------------------------------------------------------------------------
; Dive Mode - Message - Deco Info
;
	global	TFT_message_deco_info
TFT_message_deco_info
	rcall	TFT_message_open			; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO  - skip message in this cycle

	FONT_COLOR_ADVICE					; actually it is a memo, but we break the rules here and display in advice color (green)
	STRCPY_TEXT tDecoInfo				; write "Deco Zone"
	bra		TFT_message_close			; finalize message output


 IFDEF _helium

;-----------------------------------------------------------------------------
; Dive Mode - Message - IBCD
;
	global	TFT_message_IBCD
TFT_message_IBCD:
	rcall	TFT_message_open			; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO  - skip message in this cycle

	FONT_COLOR_ATTENTION				; set attention color
	STRCPY_TEXT tIBCD					; Print "IBCD N2He"
	bra		TFT_message_close			; finalize message output

 ENDIF	; _helium

 IFDEF _ccr_pscr

;-----------------------------------------------------------------------------
; Dive Mode - Message - Gas Density
;
	global	TFT_message_gas_density
TFT_message_gas_density:
	rcall	TFT_message_open			; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO  - skip message in this cycle

	btfsc	attn_det_gas_density		; on attention level?
	FONT_COLOR_ATTENTION				; YES - set attention color
	btfsc	warn_det_gas_density		; on warning level?
	FONT_COLOR_WARNING					; YES set warning color
	STRCPY_TEXT tGasDensity				; print "G.Density"
	bra		TFT_message_close			; finalize message output

 ENDIF	; _ccr_pscr

 IFDEF _external_sensor

;-----------------------------------------------------------------------------
; Dive Mode - Message - Sensor ppO2 Divergence
;
	global	TFT_message_divergence
TFT_message_divergence:
	rcall	TFT_message_open			; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO  - skip message in this cycle

	FONT_COLOR_WARNING					; set warning color
	STRCPY_TEXT tSensorDisagree			; print "Sensors<>"
	bra		TFT_message_close			; finalize message output


;-----------------------------------------------------------------------------
; Dive Mode - Message - Fallback
;
	global	TFT_message_fallback
TFT_message_fallback:
	rcall	TFT_message_open			; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO  - skip message in this cycle

	FONT_COLOR_WARNING					; set warning color
	STRCPY_TEXT tDiveFallback			; print "Fallback!"
	bra		TFT_message_close			; finalize message output

 ENDIF	; _external_sensor

 IFDEF _rx_functions

;-----------------------------------------------------------------------------
; Dive Mode - Message - TR - Transmitter
;
	global	TFT_message_transmitter
TFT_message_transmitter:
	rcall	TFT_message_open			; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO  - skip message in this cycle

	FONT_COLOR_ATTENTION				; set attention color
	STRCPY_TEXT tTransmitter			; print "P.Transm."
	bra		TFT_message_close			; finalize message output


;-----------------------------------------------------------------------------
; Dive Mode - Message - TR - Pressure
;
	global	TFT_message_pressure
TFT_message_pressure:
	rcall	TFT_message_open			; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO  - skip message in this cycle

	btfsc	attn_det_pressure1			; on attention level - pressure 1 ?
	FONT_COLOR_ATTENTION				; YES - set attention color
	btfsc	attn_det_pressure2			; on attention level - pressure 2 ?
	FONT_COLOR_ATTENTION				; YES - set attention color
	btfsc	warn_det_pressure1			; on warning   level - pressure 1 ?
	FONT_COLOR_WARNING					; YES - set warning color
	btfsc	warn_det_pressure2			; on warning   level - pressure 2 ?
	FONT_COLOR_WARNING					; YES - set warning color
	STRCPY_TEXT tPressure				; print "Tank Pres"
	bra		TFT_message_close			; finalize message output


;-----------------------------------------------------------------------------
; Dive Mode - Message - TR - SAC
;
	global	TFT_message_sac
TFT_message_sac:
	rcall	TFT_message_open			; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO  - skip message in this cycle

	MOVII	int_O_SAC_measured,mpr		; copy measured SAC rate to hi:lo
	call	TFT_color_code_pres_sac		; color-code the output
	STRCPY_TEXT tSAC					; print "SAC" (needs to be exactly 3 chars long)
	STRCAT	": "						; print ": "
	bsf		decimal_digit1				; place a decimal point in front of digit 1
	output_999							; print (0.0-99.9)
	bra		TFT_message_close			; finalize message output


;-----------------------------------------------------------------------------
; Dive Mode - Message - TR - switch Tank Advice
;
	global	TFT_message_switch_tanks
TFT_message_switch_tanks:
	rcall	TFT_message_open			; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO  - skip message in this cycle

	FONT_COLOR_ADVICE					; set advice color
	STRCPY_TEXT tswap					; print "Swap Tank"
	bra		TFT_message_close			; finalize message output

 ENDIF	; _rx_functions

 IFDEF _cave_mode
 
;-----------------------------------------------------------------------------
; Dive Mode - Message - Cave Mode
;
	global	TFT_message_cave_mode
TFT_message_cave_mode:
	rcall	TFT_message_open			; set row and column for the message
	tstfsz	WREG						; is there room for the message?
	return								; NO  - skip message in this cycle

	btfss	attn_det_cave_shut_down		; on attention level?
	bra		TFT_message_cave_mode_1		; NO
	FONT_COLOR_ATTENTION				; YES - select attention color
	bra		TFT_message_cave_mode_sd	;     - print shutdown message

TFT_message_cave_mode_1:
	btfss	warn_det_cave_shut_down		; on warning level?
	bra		TFT_message_cave_mode_info	; NO
	FONT_COLOR_WARNING					; YES - select warning color
	;bra	TFT_message_cave_mode_sd	;     - print shutdown message

TFT_message_cave_mode_sd:
	STRCPY_TEXT tCaveModeShutdown		; print "X-Cave-X"
	bra		TFT_message_close			; finalize message output

TFT_message_cave_mode_info:
	FONT_COLOR_MEMO						; set memo color
	bsf		win_invert					; print in inverse
	STRCPY_TEXT tCaveMode				; write "Cave Mode"
	bra		TFT_message_close			; finalize message output

 ENDIF	; _cave_mode


;=============================================================================
tft_out13	CODE
;=============================================================================


;-----------------------------------------------------------------------------
; Surface Custom View - Last Dive Summery
;
	global	TFT_surf_cv_lastdive
TFT_surf_cv_lastdive:
	FONT_COLOR_MEMO						; set color

	WIN_TINY surf_gaslist_column,surf_gaslist_row+.5
	STRCAT_TEXT_PRINT	tLastDive		; "Last Dive:"

	WIN_TINY surf_gaslist_column,surf_gaslist_row+(surf_gaslist_spacing*.1)+.5
	STRCAT_TEXT_PRINT	tDivetime		; "Divetime:"

	WIN_TINY surf_gaslist_column,surf_gaslist_row+(surf_gaslist_spacing*.2)+.5
	STRCAT_TEXT_PRINT	tMaxDepth		; "Max.Depth"

	WIN_TINY surf_gaslist_column,surf_gaslist_row+(surf_gaslist_spacing*.3)+.5
	STRCAT_TEXT_PRINT	tAvgDepth		; "Average"

	WIN_SMALL surf_gaslist_column+.48,surf_gaslist_row
	SMOVII	int_O_desaturation_time,mpr	; ISR-safe copy of the desaturation time
	movf	mpr+0,W						; get low byte into WREG
	iorwf	mpr+1,W						; inclusive-or with high byte, check if desaturation time is zero
	bz		TFT_surface_lastdive_2		; YES - show last dive time
	;bra	TFT_surface_lastdive_1		; NO  - show surface interval

TFT_surface_lastdive_1:
	; surface interval
	SMOVII	surface_interval_mins,mpr	; ISR-safe copy of surface interval in minutes
	call	convert_time				; convert hi:lo in minutes to hours (up:hi) and minutes (lo)
	movff	lo,up						; back-up low
	movff	hi,lo						; get    hours
	output_99							; print  hours (0-99)
	PUTC	'h'							; append hours unit
	movff	up,lo						; get    minutes
	output_99x							; print  minutes (00-99)
	PUTC_PRINT "m"						; append minutes unit and dump to screen
	bra		TFT_surface_lastdive_com	; continue

TFT_surface_lastdive_2:
	; last dive time
	SMOVQQ	surface_interval_secs,xC	; ISR-safe copy of surface_interval_secs:4 to xC:4
	call	output_secs_as_days_hours	; print seconds as days and hours
	PRINT								; dump to screen
	;bra	TFT_surface_lastdive_com	; continue

TFT_surface_lastdive_com:
	; last dive duration
	WIN_SMALL surf_gaslist_column+.48,surf_gaslist_row+(surf_gaslist_spacing*.1)
	MOVII	lastdive_duration,mpr		; get duration of last dive, minutes
	output_999							; print minutes
	PUTC	":"							; print ":"
	movff	lastdive_duration+2,lo		; get duration of last dive, seconds
	output_99x							; print seconds
	PRINT								; dump to screen

	; last dive max depth
	WIN_SMALL	surf_gaslist_column+.48,surf_gaslist_row+(surf_gaslist_spacing*.2)
	MOVII	lastdive_maxdepth,mpr		; get max depth of last dive
	rcall	TFT_surface_lastdive_depth	; print depth

	; average depth
	WIN_SMALL	surf_gaslist_column+.48,surf_gaslist_row+(surf_gaslist_spacing*.3)
	MOVII	lastdive_avgdepth,mpr		; get avg depth of last dive
	;bra	TFT_surface_lastdive_depth	; print depth and return

	; Helper Function - print depth
TFT_surface_lastdive_depth:
	TSTOSS	opt_units					; 0=Meter, 1=Feet
	bra		TFT_surface_lastdive_m		; 0 - metric
	;bra	TFT_surface_lastdive_ft		; 1 - imperial

TFT_surface_lastdive_ft:
	call	convert_cm_to_feet			; convert value in hi:lo from [cm] to [feet]
	output_999							; print (0-999)
	STRCAT_TEXT tFeets1					; "ft"
	PRINT								; dump to screen
	return								; done

TFT_surface_lastdive_m:
	bsf		omit_digit_1				; do not print 1st digit
	bsf		decimal_digit2				; place a decimal point in front of digit 2
	output_65535						; print (0.0x-655.3x)
	STRCAT_TEXT tMeters					; "m"
	PRINT								; dump to screen
	return								; done


;-----------------------------------------------------------------------------
; Surface Custom View - OC Gas List
;
	global	TFT_surf_cv_list_gas
TFT_surf_cv_list_gas:
	clrf	WREG						; do OC gases (0-4)
	;bra	TFT_surf_cv_list_gas_common ; continue with common part

	; common list for OC gases and diluents
TFT_surf_cv_list_gas_common:
	movwf	gaslist_gas					; set first gas/dil to show
	FONT_COLOR_MEMO						; set color

	bsf		short_gas_descriptions		; use short versions of gaslist_strcat_gas and gaslist_strcat_setpoint
	bcf		better_gas_hint				; do not mark the best gas/diluent (to be used in dive mode only)

	; Gas 1
	WIN_SMALL surf_gaslist_column,surf_gaslist_row
	call	gaslist_strcat_gas			; print gas description
	PRINT								; dump to screen

	; Gas 2
	WIN_SMALL surf_gaslist_column,surf_gaslist_row+(surf_gaslist_spacing*.1)
	incf	gaslist_gas,F				; select next gas/dil
	call	gaslist_strcat_gas			; print gas description
	PRINT								; dump to screen

	; Gas 3
	WIN_SMALL surf_gaslist_column,surf_gaslist_row+(surf_gaslist_spacing*.2)
	incf	gaslist_gas,F				; select next gas/dil
	call	gaslist_strcat_gas			; print gas description
	PRINT								; dump to screen

	; Gas 4
	WIN_SMALL surf_gaslist_column,surf_gaslist_row+(surf_gaslist_spacing*.3)
	incf	gaslist_gas,F				; select next gas/dil
	call	gaslist_strcat_gas			; print gas description
	PRINT								; dump to screen

	; Gas 5
	WIN_SMALL surf_gaslist_column,surf_gaslist_row+(surf_gaslist_spacing*.4)
	incf	gaslist_gas,F				; select next gas/dil
	call	gaslist_strcat_gas			; print gas description
	PRINT								; dump to screen

	return								; done


;-----------------------------------------------------------------------------
; Surface Custom View - Custom Text
;
	global	TFT_surf_cv_text
TFT_surf_cv_text:
	FONT_COLOR_MEMO						; set color

	; 1st row
	WIN_SMALL surf_customtext_column,surf_customtext_row1
	MOVRR	opt_name+ .0,buffer,.12		; copy 1st 12 chars to output buffer
	PRINT								; dump to screen

	; 2nd row
	WIN_SMALL surf_customtext_column,surf_customtext_row2
	MOVRR	opt_name+.12,buffer,.12		; copy 2nd 12 chars to output buffer
	PRINT								; dump to screen

	; 3rd row
	WIN_SMALL surf_customtext_column,surf_customtext_row3
	MOVRR	opt_name+.24,buffer,.12		; copy 3rd 12 chars to output buffer
	PRINT								; dump to screen

	; 4th row
	WIN_SMALL surf_customtext_column,surf_customtext_row4
	MOVRR	opt_name+.36,buffer,.12		; copy 4th 12 chars to output buffer
	PRINT								; dump to screen

	; 5th row
	WIN_SMALL surf_customtext_column,surf_customtext_row5
	MOVRR	opt_name+.48,buffer,.12		; copy 5th 12 chars to output buffer
	PRINT								; dump to screen

	return								; done


;-----------------------------------------------------------------------------
; Surface Custom View - Tissue Graphics
;
	global	TFT_surf_cv_tissues
TFT_surf_cv_tissues:

	; draw outer frame
	WIN_FRAME_STD surf_tissue_diagram_top, surf_tissue_diagram_bottom, surf_tissue_diagram_left, surf_tissue_diagram_right

	; draw labels
	FONT_COLOR_MEMO						; set color
	WIN_SMALL surf_tissue_N2_column,surf_tissue_N2_row
 IFDEF _helium
	btfss	tissue_graphic_layout		; shall N2 and He?
	bra		TFT_surface_tissues_1		; NO  - print "Tissues"
	STRCPY_TEXT_PRINT tN2				; YES - print "N2"
	WIN_SMALL surf_tissue_He_column,surf_tissue_He_row
	STRCPY_TEXT_PRINT tHe				;     - print "He"
	bra		TFT_surface_tissues_2		;     - continue with common part
 ENDIF

TFT_surface_tissues_1:
	STRCPY_TEXT_PRINT tDiveTissues		; print "Tissues"

TFT_surface_tissues_2:
	; draw scale

SCALELINE	macro	x
	movlw	color_deepblue
	WIN_FRAME_COLOR surf_tissue_diagram_top+.23,surf_tissue_diagram_bottom-.4,surf_tissue_diagram_left+.4+x,surf_tissue_diagram_left+.4+x
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

	; common initialization for tissue pressures and saturation
	movlw	.1
	movwf	win_height							; hight of the bargraph (0-239)
	movlw	surf_tissue_diagram_left+.4			; left start position for N2 bars
	movwf	win_leftx2							; column left (0-159)
	movlw	surf_tissue_diagram_right-surf_tissue_diagram_left-.4 ; get max width for N2 bars (78 pixel)
	movwf	win_width+0							; set width of the bar box
	clrf	win_width+1							; ...
	movlw	color_white							; color for tissues not exceeding surface max pressure
	movwf	ex									; store in ex
	movlw	color_red							; color for tissues exceeding surface max pressure
	movwf	ul									; store in ul
	bcf		aux_flag							; draw tissue pressures by default

	; draw combined or N2 tissue pressures
	lfsr	FSR2,char_O_tissue_pressure			; load base address of combined pressures by default
 IFDEF _helium
	btfsc	tissue_graphic_layout				; shall show N2+He ?
	lfsr	FSR2,char_O_tissue_pres_N2			; YES - replace with base address of N2 pressures
 ENDIF
	btfsc	tissue_graphic_mode							; in logbook mode?
	lfsr	FSR2,header_buffer+index_tissue_pres_total	; YES - replace with base address from logbook
	movlw	d'16'
	movwf	lo									; tissue counter, 16 tissues
	clrf	hi									; row    counter
TFT_surf_tissues_N2_loop:
	movlw	surf_tissue_diagram_top+.23			; surface mode top start position N2
	rcall	TFT_surf_tissues_bargraph			; show one tissue
	movlw	.2									; bargraph spacing
	addwf	hi,F								; increment row counter
	decfsz	lo,F								; decrement tissue counter, done?
	bra		TFT_surf_tissues_N2_loop			; NO - loop
 IFDEF _helium
	btfsc	tissue_graphic_layout				; shall show N2+He ?
	bra		TFT_surface_tissues_3				; YES - show He tissue pressures
 ENDIF

	; draw tissue saturations
	lfsr	FSR2,char_O_tissue_saturation				; load base address of tissue supersaturation
	btfsc	tissue_graphic_mode							; in logbook mode?
	lfsr	FSR2,header_buffer+index_tissue_supersat	; YES - replace with base address from logbook
	movlw	d'16'
	movwf	lo									; tissue counter, 16 tissues
	clrf	hi									; row    counter
	movlw	color_grey							; color for tissue saturation
	movwf	ex									; store in ex
;	movlw	color_yellow						; 2nd color is not used by tissue saturation
;	movwf	ul									; ...
	bsf		aux_flag							; draw tissue saturation
TFT_surf_tissues_sat_loop:
	movlw	surf_tissue_diagram_top+.23+.57		; surface mode top start position saturations
	rcall	TFT_surf_tissues_bargraph			; draw tissue bargraph
	movlw	.2									; bargraph spacing
	addwf	hi,F								; increment row counter
	decfsz	lo,F								; decrement tissue counter, done?
	bra		TFT_surf_tissues_sat_loop			; NO - loop

	; common part for vertical lines
	movlw	surf_tissue_diagram_top+.23+.57		; get top position
	movwf	win_top								; set top position (0-239)
	movlw	.30									; get hight
	movwf	win_height							; set height
	movlw	.1									; get width
	movwf	win_width+0							; set width, low  byte
	clrf	win_width+1							; set width, high byte

	; print 100% line
	movlw	surf_tissue_diagram_left+.4+.64		; get left position
	movwf	win_leftx2							; set left position (0-159)
	movlw	color_red							; color for 100% line
	BOX_COLOR									; draw the line

	; GF factors enabled?
	btfss	tissue_graphic_gf					; GF factors enabled?
	bra		TFT_surface_tissues_4				; NO - continue with CNS

	; print GF low line
	movlw	surf_tissue_diagram_left+.4			; get left base position
	movwf	win_leftx2							; set left base position (0-159)
	movff	opt_GF_low,WREG						; get GF low in 0.01 %
	btfsc	tissue_graphic_mode					; in logbook mode?
	movff	header_buffer+index_gf_lo_hi+0,WREG	; YES - replace by GF low from logbook
	mullw	.164								; multiply with 164
	movf	PRODH,W								; divide   by   256 -> resulting scale factor is 164/256 = 0.640625
	addwf	win_leftx2,F						; add to base position
	movlw	color_green							; color for GF low line
	BOX_COLOR									; draw the line

	; print GF high line
	movlw	surf_tissue_diagram_left+.4			; get left base position
	movwf	win_leftx2							; set left base position (0-159)
	movff	opt_GF_high,WREG					; get GF high in 0.01 %
	btfsc	tissue_graphic_mode					; in logbook mode?
	movff	header_buffer+index_gf_lo_hi+1,WREG	; YES - replace by GF high from logbook
	mullw	.164								; multiply with 164
	movf	PRODH,W								; divide   by   256 -> resulting scale factor is 164/256 = 0.640625
	addwf	win_leftx2,F						; add to base position
	movlw	color_yellow						; color for GF high line
	BOX_COLOR									; draw the line
	bra		TFT_surface_tissues_4				; continue with CNS

 IFDEF _helium
TFT_surface_tissues_3:
	; draw He tissue pressures
	movlw	surf_tissue_diagram_left+.4+.16		; start position for He bars
	movwf	win_leftx2							; column left (0-159)
	movlw	surf_tissue_diagram_right-surf_tissue_diagram_left-.4-.16 ; max width for He bars
	movwf	win_width+0							; set total width of the bar box
	clrf	win_width+1							; ...
	lfsr	FSR2,char_O_tissue_pres_He			; load base address of He pressures
	movlw	d'16'
	movwf	lo									; tissue counter, 16 tissues
	clrf	hi									; row    counter
TFT_surf_tissues_He_loop:
	movlw	surf_tissue_diagram_top+.23+.57		; surface mode top start position He
	rcall	TFT_surf_tissues_bargraph			; show one tissue
	movlw	.2									; bargraph spacing
	addwf	hi,F								; increment row counter
	decfsz	lo,F								; decrement tissue counter, done?
	bra		TFT_surf_tissues_He_loop			; NO - loop
 ENDIF

TFT_surface_tissues_4:
	btfss	tissue_graphic_cns			; shall show CNS value?
	return								; NO  - done

	; draw CNS% in-between tissue bars
	WIN_SMALL surf_tissue_He_column+.22,surf_tissue_He_row
	MOVII	int_O_CNS_current,mpr		; get current CNS
	call	TFT_color_code_cns			; color-code CNS value
	STRCPY_TEXT tCNS2					; "CNS: "
	bsf		leftbind					; print left-aligned
	output_999							; print (0-999)
	PUTC_PRINT "%"						; append unit and dump to screen
	return								; done


	; Helper Function - draw a bargraph
TFT_surf_tissues_bargraph:
	addwf	hi,W						; add row number to start position
	movwf	win_top						; set as row top (0-239)
	movff	POSTINC2,up					; get tissue value
	movf	ex,W						; default color
	btfsc	up,7						; check if flag in bit 7 is set
	movf	ul,W						; YES - switch to 2nd color
	bcf		up,7						; clear flag bit
	btfss	aux_flag					; drawing saturations?
	rlncf	up,F						; NO - multiply with 2 (previously cleared bit 7 will be rotated to bit 0)
	movff	up,win_bargraph				; set length of the bargraph
	incf	win_bargraph,F				; add 1 for a minimum visible bar (He-bars could be invisible else-wise)
	BOX_COLOR							; draw bargraph with color in WREG
	return								; done


;-----------------------------------------------------------------------------
; Surface Custom View - Tissue Graphics
;
	global	TFT_surf_cv_settings
TFT_surf_cv_settings:
	; Deco Mode
	FONT_COLOR_MEMO						; select color
	WIN_SMALL surf_gaslist_column,surf_gaslist_row
	STRCAT_PRINT "ZH-L16"				; print fix part of model
	movff	char_I_model,WREG			; get model
	iorwf	WREG						; GF enabled?
	bnz		TFT_surface_decosettings1	; YES
	;bra	TFT_surface_decosettings0	; NO

TFT_surface_decosettings0:
	; Display ZH-L16 sat/desat model
	WIN_SMALL surf_gaslist_column,surf_gaslist_row+(surf_gaslist_spacing*.1)
	STRCPY_TEXT tSD								; print label (S/D)
	movff	char_I_saturation_multiplier,  lo	; get sat   mult.
	movff	char_I_desaturation_multiplier,hi	; get desat mult.
	bra		TFT_surface_decosettings_com		; continue with common part

TFT_surface_decosettings1:
	; Display ZH-L16-GF low/high model
	WIN_SMALL surf_gaslist_column+.43,surf_gaslist_row
	STRCPY_TEXT_PRINT tZHL16GF					; print GF label behind deco model label

	WIN_SMALL surf_gaslist_column,surf_gaslist_row+(surf_gaslist_spacing*.1)
	STRCPY_TEXT tGF								; print label (GF:)
	PUTC	' '									; print a space
	movff	opt_GF_low, lo						; get GF low
	movff	opt_GF_high,hi						; get GF high
	;bra	TFT_surface_decosettings_com		; continue with common part

TFT_surface_decosettings_com:
	; percentage pair
	output_256							; print (0-255)
	STRCAT	"%/"						; print "%/"
	movff	hi,lo						; get 2nd value
	output_256							; print (0-255)
	PUTC_PRINT "%"						; append unit and dump to screen

	; fTTS
	WIN_SMALL surf_gaslist_column,surf_gaslist_row+(surf_gaslist_spacing*.2)
	STRCPY_TEXT tFTTSSurf				; print label
	movff	char_I_extra_time,lo		; get time
	output_9							; print time (0-9)
	STRCAT_TEXT_PRINT tMinutes			; append unit and dump to screen

	; Last Stop
	WIN_SMALL surf_gaslist_column,surf_gaslist_row+(surf_gaslist_spacing*.3)
	STRCPY_TEXT tLastDecostopSurf		; print label
	movff	opt_last_stop,lo			; get depth
	output_9							; print depth (0-9)
	STRCAT_TEXT_PRINT tMeters			; append unit and dump to screen

	; Salinity
	WIN_SMALL surf_gaslist_column,surf_gaslist_row+(surf_gaslist_spacing*.4)
	STRCPY_TEXT tDvSalinitySurf			; print label
	movff	opt_salinity,lo				; get salinity
	output_9							; print salinity (0-9)
	STRCAT_TEXT_PRINT tPercent			; append unit and dump to screen

	return								; done


 IFDEF _rx_functions

;-----------------------------------------------------------------------------
; Surface Custom View - TR - Tank Data
;
	global	TFT_surf_cv_tankdata
TFT_surf_cv_tankdata:
	lfsr	FSR1,rx_buffer				; load base address of RX buffer

 IFNDEF _rx_functions_debug

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

	return								; done


	; Helper Function - print transmitter data (max 12 char)
TFT_surface_tankdata_print:
	FONT_COLOR_MEMO						; set color
	movff	POSTINC1,hi					; get ID high (+0)
	movff	POSTINC1,lo					; get ID low  (+1)
	tstfsz	hi							; ID high = 0 ?
	bra		TFT_surface_tankdata_print_1; NO  - slot in use
	tstfsz	lo							; ID low  = 0?
	bra		TFT_surface_tankdata_print_1; NO  - slot in use
	STRCAT_PRINT "----        "			; YES - mark as unused and clear rest of line from previous remains
	movf	POSTINC1,W					;     - dummy read (+2) to advance index
	movf	POSTINC1,W					;     - dummy read (+3) to advance index
	movf	POSTINC1,W					;     - dummy read (+4) to advance index
	bra		TFT_surface_tankdata_print_3;     - one more dummy read and return

TFT_surface_tankdata_print_1:
	movf	hi,W						; copy ID high to WREG
	output_hex							; print as hex        2 chars
	movf	lo,W						; copy ID low  to WREG
	output_hex							; print as hex        2 chars (4 in total)
	movff	POSTINC1,hi					; get pressure high (+2)
	movff	POSTINC1,lo					; get pressure low  (+3)
	call	TFT_color_code_pres_sac		; needed to clear the status flags before output
	bsf		omit_digit_1				; do not print 1st digit (0.1 bar)
	output_65535						; print (0x-6553x)    4 chars (8 in total)
	PUTC	" "							;                     1 char  (9 in total)
	movf	POSTINC1,W					; get status (+4)
	andlw	.7							; mask out battery voltage
	bnz		TFT_surface_tankdata_2		; branch if battery is not completely drained
	FONT_COLOR_WARNING					; output in red
	STRCAT_PRINT "XXX"					; "XXX" for low
	bra		TFT_surface_tankdata_print_3; one more dummy read and return

TFT_surface_tankdata_2:
	addlw	.28							; add offset of 2.8 Volt
	movff	WREG,lo						; copy to lo
	bsf		decimal_digit1  			; put a decimal point in front of digit 1
	output_99							; print voltage       2 chars (11 in total)
	PUTC_PRINT " "						; dummy char          1 char  (12 in total)

TFT_surface_tankdata_print_3:
	movf	POSTINC1,W					; dummy read (+5) to advance index
	return								; done

 ELSE	; _rx_functions_debug

TFT_surface_tankdata_debug:				; surface custom view debug output
	FONT_COLOR_MEMO						; set color
	WIN_TINY surf_customtext_column,surf_customtext_row1+.14*0
	rcall	TFT_surface_tankdata_debug_print
	WIN_TINY surf_customtext_column,surf_customtext_row1+.14*1
	rcall	TFT_surface_tankdata_debug_print
	WIN_TINY surf_customtext_column,surf_customtext_row1+.14*2
	rcall	TFT_surface_tankdata_debug_print
	WIN_TINY surf_customtext_column,surf_customtext_row1+.14*3
	rcall	TFT_surface_tankdata_debug_print
	WIN_TINY surf_customtext_column,surf_customtext_row1+.14*4
	rcall	TFT_surface_tankdata_debug_print
	WIN_TINY surf_customtext_column,surf_customtext_row1+.14*5
	rcall	TFT_surface_tankdata_debug_print
	WIN_TINY surf_customtext_column,surf_customtext_row1+.14*6
	rcall	TFT_surface_tankdata_debug_print
	WIN_TINY surf_customtext_column,surf_customtext_row1+.14*7
	rcall	TFT_surface_tankdata_debug_print
	return								; done

TFT_surface_tankdata_debug_print:
	movff	POSTINC1,hi					; read ID high (+0)
	output_hex							; print as hex
	movff	POSTINC1,lo					; read ID low  (+1)
	output_hex							; print as hex
	PUTC	","							; print ","
	movff	POSTINC1,hi					; read pressure high (+2)
	movff	POSTINC1,lo					; read pressure low  (+3)
	call	TFT_color_code_pres_sac		; needed to clear the status flags before output
	bsf		decimal_digit1				; place a decimal point in front of digit 1 
	output_9999							; print pressure (0.0-999.9)
	PUTC	","							; print ","
	movff	POSTINC1,lo					; read status (+4)
	output_hex							; print as hex
	PUTC	","							; print ","
	movff	POSTINC1,lo					; read date   (+5)
	output_256							; print (0-255)
	PRINT								; dump to screen
	return								; done

 ENDIF	; _rx_functions_debug
 ENDIF	; _rx_functions

 IFDEF _compass

;-----------------------------------------------------------------------------
; Surface Custom View - Compass - "set Bearing Dialog"
;
	global	TFT_surf_cv_compass_bearing
TFT_surf_cv_compass_bearing:
	btfsc	compass_menu				; is the "set bearing" selection shown?
	return								; YES - done
	bsf		compass_menu				; NO  - set "set bearing" selection as shown
	WIN_BOX_BLACK surf_compass_bear_row,surf_warning1_row-1, surf_compass_bear_column, surf_decotype_column-.1 ; top, bottom, left, right
	WIN_SMALL surf_compass_bear_column,surf_compass_bear_row
	FONT_COLOR color_yellow				; set color
	bsf		win_invert					; print inverse
	STRCPY_TEXT_PRINT tSetHeading		; 7 chars
	return								; done

 ENDIF	; _compass

 IFDEF _ccr_pscr

;-----------------------------------------------------------------------------
; Surface Custom View - Diluent List
;
	global	TFT_surf_cv_list_dil
TFT_surf_cv_list_dil:
	movlw	.5							; do diluents (5-9)
	bra		TFT_surf_cv_list_gas_common ; continue with common part


;-----------------------------------------------------------------------------
; Surface Custom View - Setpoint List
;
	global	TFT_surf_cv_list_sp			; show setpoint list
TFT_surf_cv_list_sp:
	FONT_COLOR_MEMO						; set color
	bsf		short_gas_descriptions		; use short versions of gaslist_strcat_gas_PRODL and gaslist_strcat_setpoint
	bcf		better_gas_hint				; do not mark the best gas/diluent (to be used in dive mode only)

	;SP 1
	WIN_SMALL surf_gaslist_column,surf_gaslist_row
	clrf	gaslist_gas					; select SP 1
	call	gaslist_strcat_setpoint		; show setpoint data
	PRINT								; dump to screen

	;SP 2
	WIN_SMALL surf_gaslist_column,surf_gaslist_row+(surf_gaslist_spacing*.1)
	incf	gaslist_gas,F				; select next SP
	call	gaslist_strcat_setpoint		; show SP#+1 of PRODL#
	PRINT								; dump to screen

	;SP 3
	WIN_SMALL surf_gaslist_column,surf_gaslist_row+(surf_gaslist_spacing*.2)
	incf	gaslist_gas,F				; select next SP
	call	gaslist_strcat_setpoint		; show SP#+1 of PRODL#
	PRINT								; dump to screen

	;SP 4
	WIN_SMALL surf_gaslist_column,surf_gaslist_row+(surf_gaslist_spacing*.3)
	incf	gaslist_gas,F				; select next SP
	call	gaslist_strcat_setpoint		; show SP#+1 of PRODL#
	PRINT								; dump to screen

	;SP 5
	WIN_SMALL surf_gaslist_column,surf_gaslist_row+(surf_gaslist_spacing*.4)
	incf	gaslist_gas,F				; select next SP
	call	gaslist_strcat_setpoint		; show SP#+1 of PRODL#
	PRINT								; dump to screen

	return								; done

 ENDIF	; _ccr_pscr


;=============================================================================
tft_out14	CODE
;=============================================================================


;-----------------------------------------------------------------------------
; Dive Custom View - AVR / Stopwatch - Mask
;
	global	TFT_avr_stopwatch_mask
TFT_avr_stopwatch_mask:
	FONT_COLOR_MASK						; select color

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
	STRCPY_TEXT_PRINT tDiveStopwatch	; print label

	WIN_TINY dm_custom_avr_stop_column3-.8,dm_custom_avr_stop_title_row
	STRCPY_TEXT_PRINT tDiveStopAvg		; print label

	return								; done

 ELSE

	WIN_TINY dm_custom_avr_stop_column1+.2,dm_custom_avr_stop_title_row
	STRCPY_PRINT "Max.Depth"			; print label

	WIN_TINY dm_custom_avr_stop_column2+.3,dm_custom_avr_stop_title_row
	STRCPY_PRINT "Avg.Depth"			; print label

	WIN_TINY dm_custom_avr_stop_column3-.8,dm_custom_avr_stop_title_row
	STRCPY_PRINT "Min.Depth"			; print label

	return								; done

 ENDIF


;-----------------------------------------------------------------------------
; Dive Custom View - AVR / Stopwatch - Data
;
	global	TFT_avr_stopwatch
TFT_avr_stopwatch:
	FONT_COLOR_MEMO							; select color

 IFNDEF _min_depth_option

	; total average depth or max depth
	WIN_MEDIUM dm_custom_avr_stop_column1,dm_custom_avr_stop_row
	TSTOSS	opt_2ndDepthDisp				; show average depth instead of maximum depth in main screen?
	bra		TFT_avr_stopwatch_1				; NO  - draw avg depth in custom view then
	btfsc	alt_layout_active				; YES - in alternative layout?
	bra		TFT_avr_stopwatch_avg			;       YES - show avg depth
	bra		TFT_avr_stopwatch_max			;       NO  - show max depth

TFT_avr_stopwatch_1:
	btfsc	alt_layout_active				; YES - in alternative layout?
	bra		TFT_avr_stopwatch_max			;       YES - show max depth
	;bra	TFT_avr_stopwatch_avg			;       NO  - show avg depth

TFT_avr_stopwatch_avg:
	MOVII	pressure_rel_avg_total,mpr		; get total dive average pressure into hi:lo
	bra		TFT_avr_stopwatch_2				; continue

TFT_avr_stopwatch_max:
	MOVII	pressure_rel_max_cached,mpr		; get maximum pressure into hi:lo
	;bra	TFT_avr_stopwatch_2				; continue

TFT_avr_stopwatch_2:
	call	convert_pres_to_depth			; convert pressure in [mbar] to depth in [cm]
	TSTOSS	opt_units						; 0=m, 1=ft
	bra		TFT_update_avr_stopwatch1_metric; 0 - metric
	;bra	TFT_update_avr_stopwatch1_imp	; 1 - imperial

TFT_update_avr_stopwatch1_imp:
	call	convert_cm_to_feet				; convert value in hi:lo from [cm] to [feet]
	output_999								; print (0-999)
	PRINT									; dump to screen
	bra		TFT_update_avr_stopwatch2		; continue

TFT_update_avr_stopwatch1_metric:
	rcall	TFT_update_avr_stopwatch_metric	; print metric depth
	;bra	TFT_update_avr_stopwatch2		; continue

TFT_update_avr_stopwatch2:
	; stopped average depth
	WIN_MEDIUM dm_custom_avr_stop_column3,dm_custom_avr_stop_row
	MOVII	pressure_rel_avg_trip,mpr		; get the resettable average pressure
	call	convert_pres_to_depth			; convert pressure in [mbar] to depth in [cm]
	TSTOSS	opt_units						; 0=m, 1=ft
	bra		TFT_update_avr_stopwatch2_metric; 0 - metric
	;bra	TFT_update_avr_stopwatch2_imp	; 1 - imperial

TFT_update_avr_stopwatch2_imp:
	call	convert_cm_to_feet				; convert value in hi:lo from [cm] to [feet]
	output_999								; print (0-999)
	PRINT									; dump to screen
	bra		TFT_update_avr_stopwatch3		; continue

TFT_update_avr_stopwatch2_metric:
	rcall	TFT_update_avr_stopwatch_metric	; print metric depth
	bra		TFT_update_avr_stopwatch3		; continue


; Helper Function - print metric depth
TFT_update_avr_stopwatch_metric:
	bsf		leftbind					; print left-aligned
	bsf		omit_digit_1				; do not print 1st digit (no cm)
	bsf		decimal_digit2				; place a decimal point in front of digit 2
	output_65535						; print (0.0x-655.3x)
	PUTC	" "							; wipe out remains from last output
	clrf	WREG
	movff	WREG,buffer+.4				; limit string length to 4 = 3 digits + 1 half-size decimal dot
	PRINT								; dump to screen
	return								; done

 ELSE

	; resettable maximum depth - needs ISR-safe copy!
	WIN_MEDIUM dm_custom_avr_stop_column1,dm_custom_avr_stop_row
	FONT_COLOR_MEMO						; select color
	SMOVII	pressure_rel_max_trip,mpr	; get resettable maximum pressure
	rcall	TFT_avr_stopwatch_helper	; print depth

	; resettable average depth
	WIN_MEDIUM dm_custom_avr_stop_column2-.1,dm_custom_avr_stop_row
	FONT_COLOR_ATTENTION				; select color
	MOVII	pressure_rel_avg_trip,mpr	; get resettable average pressure
	rcall	TFT_avr_stopwatch_helper	; print depth

	; resettable minimum depth - needs ISR safe copy!
	WIN_MEDIUM dm_custom_avr_stop_column3-.12,dm_custom_avr_stop_row
	FONT_COLOR_MEMO						; select color
	SMOVII	pressure_rel_min_trip,mpr	; get resettable minimum pressure
	rcall	TFT_avr_stopwatch_helper	; print depth

	return								; done

TFT_avr_stopwatch_helper:
	call	convert_pres_to_depth		; convert pressure in [mbar] to depth in [cm]
	bsf		leftbind					; print left-aligned
	bsf		decimal_digit2				; place a decimal point in front of digit 2
	output_65535						; print (0.00-655.35)
	PUTC	" "							; wipe out remains from last output
	clrf	WREG						; load string terminator
	movff	WREG,buffer+.5				; limit string length to 5 = 4 digits + 1 half-size decimal dot
	PRINT								; dump to screen
	return								; done

 ENDIF

TFT_update_avr_stopwatch3:
	WIN_MEDIUM dm_custom_avr_stop_column2,dm_custom_avr_stop_row
	;bra	TFT_update_stopwatch		; continue

TFT_update_stopwatch:
	; jump-in point for stopped dive time in compass custom view
	MOVII	divesecs_avg_trip,mpr		; get the resettable dive time (stopwatch)
	call	convert_time				; convert hi:lo in seconds to minutes (up:hi) and seconds (lo)
	movlw	.100						; display layout will change if minutes become >= 100
	cpfslt	hi							; minutes < 100 ?
	bra		TFT_update_stopwatch_1		; NO  - display hours:minutes
	bcf		aux_flag					; YES - will print minutes : seconds
	bra		TFT_update_stopwatch_2		;     - continue

TFT_update_stopwatch_1:
	movff	hi,lo						; transfer minutes (low  byte) to lo
	movff	up,hi						; transfer minutes (high byte) to hi
	call	convert_time				; convert hi:lo in minutes to hours (up:hi) and minutes (lo)
	bsf		aux_flag					; will print hours : minutes

TFT_update_stopwatch_2:
	movf	hi,W						; exchange lo and hi
	movff	lo,hi						; ...
	movwf	lo							; ...
	output_99							; print minutes or hours (0 - 99)
	movlw	":"							; load standard separator
	btfsc	aux_flag					; will print hours : minutes ?
	movlw	"'"							; YES - swap to alternative separator
	movwf	POSTINC2					; print separator
	movff	hi,lo						; restore lo
	output_99x							; print seconds or minutes (00-99)
	movlw	.5							; set target length
	call	TFT_buffer_trim_length		; fill / cut buffer to target length
	PRINT								; dump to screen
	return								; done


;-----------------------------------------------------------------------------
; Dive Custom View - Gas Needs - Mask
;
	global	TFT_gas_needs_mask
TFT_gas_needs_mask:
	WIN_TINY dm_custom_gas_column_title, dm_custom_gas_mask_row
	FONT_COLOR_MASK						; select color

 IFDEF _cave_mode

	movff	char_O_deco_info,WREG		; get the deco info vector
	btfss	WREG,gas_needs_cave			; are the gas needs calculated for cave mode?
	bra		TFT_gas_needs_mask_ascent_1	; NO  - show as direct ascent needs
	;bra	TFT_gas_needs_mask_ascent_0	; YES - show as cave   return needs

TFT_gas_needs_mask_ascent_0:
	bsf		gas_needs_mode_last			; remember last results were for cave mode
	STRCPY_TEXT tGasNeedsCaveMode		; print "Gas Needs Cave Mode"
	bra		TFT_gas_needs_mask_ascent_2	; continue

TFT_gas_needs_mask_ascent_1:
	bcf		gas_needs_mode_last			; remember last results were for direct ascent
	STRCPY_TEXT tGasNeedsAscent			; "Gas Needs Ascent"
	;bra	TFT_gas_needs_mask_ascent_2	; continue

 ELSE

	STRCPY_TEXT tGasNeedsAscent			; "Gas Needs Ascent"

 ENDIF

TFT_gas_needs_mask_ascent_2:
	TSTOSS	char_I_extra_time			; fTTS enabled?
	bra		TFT_gas_needs_mask_ascent_3	; NO  - continue
	STRCAT	" fTTS"						; YES - append fTTS marking
TFT_gas_needs_mask_ascent_3:
	STRCAT_PRINT " (bar)"				; append " (bar)" and dump buffer to screen
	return								; done


;-----------------------------------------------------------------------------
; Dive Custom View - Gas Needs - Data
;
; LIMITATION: there is only space for 4 gases on the screen - if 5 gases
;             have a pres_need > 0, then only the first 4 will be shown!
;
	global	TFT_gas_needs
TFT_gas_needs:

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
	;bra	TFT_gas_needs_ascent_3		; continue

 ENDIF

TFT_gas_needs_ascent_3:
	clrf	up												; initialize gas index (0-4)
	WIN_SMALL dm_custom_gas_column1+.5,dm_custom_gas_row1	; set position
	rcall	TFT_gas_needs_helper							; print need
	WIN_SMALL dm_custom_gas_column1+.5,dm_custom_gas_row2	; set position
	rcall	TFT_gas_needs_helper							; print need
	WIN_SMALL dm_custom_gas_column2+.5,dm_custom_gas_row1	; set position
	rcall	TFT_gas_needs_helper							; print need
	WIN_SMALL dm_custom_gas_column2+.5,dm_custom_gas_row2	; set position
	rcall	TFT_gas_needs_helper							; print need
	return													; done


	; Helper Function - print need for next gas
TFT_gas_needs_helper:
	FONT_COLOR_MEMO						; select default color
	movlw	.5							; total number of gases
	cpfslt	up							; check if all gases have been processed
	bra		TFT_gas_needs_helper_1		; YES - clear display area
	movf	up,W						; NO  - get gas number and check if need of that gas is > 0
	rlncf	WREG,W						;     - multiply by 2
	incf	WREG,W						;     - add 1 to address high byte
	lfsr	FSR1,int_O_gas_need_pres	;     - load base of gas needs in pressure
	movff	PLUSW1,hi					;     - read HIGH(int_O_gas_need_pres[up])
	btfss	hi,int_is_zero				;     - check flag for pres_need == 0
	bra		TFT_gas_needs_helper_2		;       NO  - print gas type and pressure needed
	incf	up,F						;       YES - increment to next gas
	bra		TFT_gas_needs_helper		;           - loop and try the next gas

TFT_gas_needs_helper_1:	
	; no gases to show anymore, clear display area from potential remains of last invocation
	STRCAT_PRINT "  ----   "			; overwrite outdated stuff if screen position is not needed
	return								; done

TFT_gas_needs_helper_2:
	; output gas type and pressure needed
	movf	up,W						; get gas number (0-4) to WREG
	lfsr	FSR1,opt_gas_O2_ratio		; read opt_gas_O2_ratio[WREG]
	movff	PLUSW1,lo					; copy result to lo
	lfsr	FSR1,opt_gas_He_ratio		; read opt_gas_He_ratio[WREG]
	movff	PLUSW1,hi					; copy result to hi
	call	gaslist_strcat_mix			; print "Air", "O2", "21/35", etc.
	PUTC	':'							; print ":"
	movf	up,W						; get gas number (0-4) to WREG
	rlncf	WREG,W						; multiply by 2
	lfsr	FSR1,int_O_gas_need_pres	; load base of gas needs in pressure
	movff	PLUSW1,lo					; read LOW(int_O_gas_need_pres[up])
	incf	WREG,W						; add 1 to address high byte
	movff	PLUSW1,hi					; read HIGH(int_O_gas_need_pres[up])
	btfsc	hi,int_attention_flag		; check if attention flag is set (pres_need > pres_fill * threshold)
	FONT_COLOR_ATTENTION				; YES - print gas need in attention color
	btfsc	hi,int_warning_flag			; check if warning   flag is set (pres_need > pres_fill)
	FONT_COLOR_WARNING					; YES - print gas need in warning color
	movff	int_O_gas_need_pres+1,WREG	; get HIGH(int_O_gas_need_pres[0]) which holds flag for invalid data
	btfsc	WREG,int_invalid_flag		; check if invalid data flag is set
	FONT_COLOR_DISABLED					; YES - print gas need in disabled color
	bcf		hi,int_attention_flag		; clear flag for attention
	bcf		hi,int_warning_flag			; clear flag for warning
	bcf		hi,int_high_flag			; clear flag for > 999 bar
	bcf		hi,int_invalid_flag			; clear flag for invalid data (will actually only be set with 1st gas)
	output_999							; print (0-999)
	PUTC_PRINT " "						; add a space to overwrite any potential remains of earlier outputs and dump buffer to screen
	incf	up,F						; increment to next gas
	return								; done


;-----------------------------------------------------------------------------
; Dive Custom View - Deco Plan - Mask
;
	global	TFT_decoplan_mask			; mask for deco plan
TFT_decoplan_mask:
	WIN_TINY dm_custom_decoplan_title_column, dm_custom_decoplan_title_row
	FONT_COLOR_MASK						; select color
	STRCPY_TEXT_PRINT tDiveDecoplan		; print label

	return								; done


;-----------------------------------------------------------------------------
; Dive Custom View - Deco Plan - Data
;
	global	TFT_decoplan
TFT_decoplan:
	lfsr	FSR0,char_O_deco_depth		; load base address of stops table
	clrf	ex							; will be used for auxiliary flags
	FONT_COLOR_MEMO						; set default output color
	movff	char_O_deco_gas+0,lo		; get flag for invalid deco data
	btfsc	lo,char_invalid_flag		; is the invalid flag set?
	FONT_COLOR_DISABLED					; YES - set to disabled color
	; 2nd stop
	WIN_SMALL dm_cust_dstop_2nd_stop_column, dm_cust_dstop_2nd_stop_row
	rcall	TFT_decoplan_helper			; show stop data
	; 3rd stop
	WIN_SMALL dm_cust_dstop_3rd_stop_column, dm_cust_dstop_3rd_stop_row
	rcall	TFT_decoplan_helper			; show stop data
	; 4th stop
	bsf		ex,4						; flag we are on 4th screen position
	WIN_SMALL dm_cust_dstop_4th_stop_column, dm_cust_dstop_4th_stop_row
	rcall	TFT_decoplan_helper			; show stop data
	bcf		ex,4						; clear 4th position flag again
	; 5th stop
	WIN_SMALL dm_cust_dstop_5th_stop_column, dm_cust_dstop_5th_stop_row
	rcall	TFT_decoplan_helper			; show stop data
	; 6th stop
	WIN_SMALL dm_cust_dstop_6th_stop_column, dm_cust_dstop_6th_stop_row
	rcall	TFT_decoplan_helper			; show stop data
	; 7th stop
	WIN_SMALL dm_cust_dstop_7th_stop_column, dm_cust_dstop_7th_stop_row
	rcall	TFT_decoplan_helper			; show stop data
	return								; done


	; Helper Function - show stop data
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
	return								;            done

TFT_decoplan_helper_2:					; no more stop table entries, blank potential previous content
	STRCPY_PRINT "       "				; wipe screen position by printing 7 spaces
	return								; done

TFT_decoplan_helper_3:
	rcall	TFT_display_stop_depth		; print stop depth (depth in lo)
	PUTC	" "							; put a space char between depth and time
	movlw	NUM_STOPS					; offset between arrays holding depths and durations
	movff	PLUSW0,lo					; get duration of the current stop
	output_99dd							; print duration, prints double dots if duration is zero
	PUTC_PRINT "'"						; append unit and dump buffer to screen
	bsf		ex,1						; flag that a stop was shown
	return								; done


	; Helper Function - print stop depth
TFT_display_stop_depth:					; print depth (stored in lo)
	TSTOSS	opt_units					; get unit (0=m, 1=ft)
	bra		TFT_display_stop_depth_m	; 0 - meter
	;bra	TFT_display_stop_depth_ft	; 1 - feet

TFT_display_stop_depth_ft:
	call	convert_meter_to_feet		; convert value in lo from meters to feet
	output_999							; output stop depth (0-999)
	return								; done

TFT_display_stop_depth_m:
	output_99							; output stop depth (0-99)
	STRCAT_TEXT tMeters					; append unit
	return								; done


;-----------------------------------------------------------------------------
; Dive Custom View - Ceiling, Supersaturation & Tissues - Mask
;
	global	TFT_ceiling_GF_tissue_mask
TFT_ceiling_GF_tissue_mask:
	FONT_COLOR_MASK						; select color

	WIN_TINY dm_custom_ceiling_column+.2,dm_custom_ceiling_title_row
	STRCPY_TEXT_PRINT tCeiling			; print label

	WIN_TINY dm_custom_tissue_title_column, dm_custom_tissue_title_row
	STRCPY_TEXT_PRINT tDiveTissues		; print label

	WIN_TINY dm_custom_gf_column1+.5, dm_custom_gf_title_row
	STRCPY_TEXT_PRINT tGFInfo			; print label

	return								; done


;-----------------------------------------------------------------------------
; Dive Custom View - Ceiling, Supersaturation & Tissues - Data
;
	global	TFT_ceiling_GF_tissue
TFT_ceiling_GF_tissue:
	WIN_MEDIUM dm_custom_ceiling_column,dm_custom_ceiling_row
	MOVII	int_O_ceiling,mpr			; get ceiling in [mbar] relative pressure
	call	TFT_color_code_ceiling		; color-code the output (also strips off flags)
	call	convert_pres_to_depth		; convert pressure in [mbar] to depth in [cm]

	TSTOSS	opt_units						; 0=m, 1=ft
	bra		TFT_ceiling_GF_tissue_metric	; 0 - meter
	;bra	TFT_ceiling_GF_tissue_imperial	; 1 - feet

TFT_ceiling_GF_tissue_imperial:
	call	convert_cm_to_feet			; convert value in hi:lo from [cm] to [feet]
	output_999							; print (0-999)
	bra		TFT_ceiling_GF_tissue0		; continue

TFT_ceiling_GF_tissue_metric:
	bsf		omit_digit_1				; do not print 1st digit
	bsf		decimal_digit2				; place a decimal point in front of digit 2
	bsf		leftbind					; print left-aligned
	output_65535						; print (xxx.x-)
	bra		TFT_ceiling_GF_tissue0		; continue

TFT_ceiling_GF_tissue0:
	PUTC_PRINT " "						; append a space and dump to screen
	; show tissue diagram
	rcall	TFT_dive_tissues			; show tissue pressure diagram
	; show current supersaturation
	WIN_MEDIUM dm_custom_clock_column+.3, dm_custom_gf_row
	MOVII	int_O_lead_supersat,mpr		; bank-safe copy of leading tissue's supersaturation
	call	TFT_color_code_supersat		; color-code output
	output_256							; need to print lo only, int_O_lead_supersat value is limited to 255
	PRINT								; dump to screen
	WIN_STD	dm_custom_clock_column+.40, dm_custom_gf_row+.5
	PUTC_PRINT "%"						; print "%" and dump to screen
	return								; done


	;-------------------------------------------------------------------------
	; Draw saturation graph in dive mode custom view
	;
TFT_dive_tissues:
	; draw outer frame
	movf	pallet_color_memo,W					; get color into WREG
	WIN_FRAME_COLOR dm_custom_tissue_diagram_top, dm_custom_tissue_diagram_bottom, dm_custom_tissue_diagram_left, .159 ; outer frame

	; clear area showing leading tissue number as it may not be printed over
	WIN_BOX_BLACK dm_custom_tissue_diagram_top+.16, dm_custom_tissue_diagram_top+.16+.10, dm_custom_tissue_diagram_left+.32, dm_custom_tissue_diagram_left+.32+.8 ; top, bottom, left, right

TFT_dive_tissues_1:
	; common initialization for tissue pressures and saturation
	movlw	.1
	movwf	win_height							; hight of the bargraph (0-239)
	movlw	dm_custom_tissue_diagram_left+.3	; get dive mode left start position
	movwf	win_leftx2							; set column left (0-159)
	movlw	.159-dm_custom_tissue_diagram_left-.4 ; get max width
	movwf	win_width+0							; set width (low byte)
	clrf	win_width+1							; high byte of with is always zero
	movlw	color_cyan							; color for tissues with decreasing pressure
	movwf	ex									; store in ex
	movlw	color_orange						; color for tissues with increasing pressure
	movwf	ul									; store in ul

	; draw combined or N2 tissue pressures
	lfsr	FSR2,char_O_tissue_pressure			; load base address of combined pressures by default
 IFDEF _helium
	btfsc	tissue_graphic_layout				; shall show N2+He ?
	lfsr	FSR2,char_O_tissue_pres_N2			; YES - load base address of N2 pressures
 ENDIF
	movlw	d'16'
	movwf	lo									; tissue counter, 16 tissues
	clrf	hi									; row    counter
TFT_dive_tissues_N2_loop:
	movlw	dm_custom_tissue_diagram_top+.3		; dive mode top start position N2
	rcall	TFT_dive_tissues_bargraph			; draw tissue bargraph
	incf	hi,F								; increment row counter
	decfsz	lo,F								; decrement tissue counter, done?
	bra		TFT_dive_tissues_N2_loop			; NO - loop
 IFDEF _helium
	btfsc	tissue_graphic_layout				; shall show N2+He ?
	bra		TFT_dive_tissues_3					; YES - show He tissue pressures
 ENDIF

	; draw tissue saturations
	lfsr	FSR2,char_O_tissue_saturation		; load base address of tissue supersaturation
	movlw	d'16'
	movwf	lo									; tissue counter, 16 tissues
	clrf	hi									; row    counter
	movlw	color_grey							; color for tissue saturation, alternative: color_lightblue
	movwf	ex									; store in ex
;	movlw	color_yellow						; 2nd color is not used by tissue saturation
;	movwf	ul									; ...
TFT_dive_tissues_sat_loop:
	movlw	dm_custom_tissue_diagram_top+.25	; dive mode top start position saturations
	rcall	TFT_dive_tissues_bargraph			; draw tissue bargraph
	incf	hi,F								; increment row counter
	decfsz	lo,F								; decrement tissue counter, done?
	bra		TFT_dive_tissues_sat_loop			; NO - loop

	; common part for vertical lines
	movlw	dm_custom_tissue_diagram_top+.25	; get top position
	movwf	win_top								; set top position (0-239)
	movlw	.15									; get hight
	movwf	win_height							; set height
	movlw	.1									; get width
	movwf	win_width+0							; set width, low  byte
	clrf	win_width+1							; set width, high byte

	; print 100% line
	movlw	dm_custom_tissue_diagram_left+.36	; get left position
	movwf	win_leftx2							; set left position (0-159)
	movlw	color_red							; color for 100% line
	BOX_COLOR									; draw line

	; GF factors enabled?
	btfss	tissue_graphic_gf					; shall show GF lines?
	bra		TFT_dive_tissues_4					; NO - continue with number of leading tissue

	; print GF low line
	movlw	dm_custom_tissue_diagram_left+.3	; get left base position
	movwf	win_leftx2							; set left base position (0-159)
	movff	char_I_GF_Low_percentage,WREG		; get GF low in 0.01 %
	mullw	.82									; multiply with 82
	movf	PRODH,W								; divide   by   256 -> resulting scale factor is 82/256 = 0.3203125
	addwf	win_leftx2,F						; add to base position
	movlw	color_green							; color for GF low line
	BOX_COLOR									; draw line

	; print GF high line
	movlw	dm_custom_tissue_diagram_left+.3	; get left base position
	movwf	win_leftx2							; set left base position (0-159)
	movff	char_I_GF_High_percentage,WREG		; get GF high in 0.01 %
	mullw	.82									; multiply with 82
	movf	PRODH,W								; divide   by   256 -> resulting scale factor is 82/256 = 0.3203125
	addwf	win_leftx2,F						; add to base position
	movlw	color_yellow						; color for GF high line
	BOX_COLOR									; draw line
	bra		TFT_dive_tissues_4					; continue with number of leading tissue

 IFDEF _helium
TFT_dive_tissues_3:
	; draw He tissues pressures
	lfsr	FSR2,char_O_tissue_pres_He			; load base address of He pressures
	movlw	dm_custom_tissue_diagram_left+.7	; get dive mode left start position for He bars
	movwf	win_leftx2							; set column left (0-159)
	movlw	.159-dm_custom_tissue_diagram_left-.8 ; get max width for He bars
	movwf	win_width+0							; set width (low byte)
	clrf	win_width+1							; ...
	movlw	d'16'
	movwf	lo									; tissue counter, 16 tissues
	clrf	hi									; row    counter
TFT_dive_tissues_He_loop:
	movlw	dm_custom_tissue_diagram_top+.25	; dive mode top start position H2
	rcall	TFT_dive_tissues_bargraph			; draw tissue bargraph
	incf	hi,F								; increment row counter
	decfsz	lo,F								; decrement tissue counter, done?
	bra		TFT_dive_tissues_He_loop			; NO  - loop
 ENDIF

TFT_dive_tissues_4:
	; print number of leading tissue	; TODO: some flicker due to overwriting by tissue bars
	movff	int_O_lead_supersat+0,WREG	; get current leading tissue's supersaturation (only low byte used for value)
	tstfsz	WREG						; current supersaturation = 0 ?
	bra		TFT_dive_tissues_5			; NO  - print number of leading tissue
	movff	char_O_deco_info,WREG		; YES - get deco info vector
	btfss	WREG,deco_ceiling			;     - do we have a ceiling obligation?
	return								;       NO  - can ascent directly, don't print number, set standard color and return
										;       YES - print number of leading tissue
TFT_dive_tissues_5:
	movff	char_O_lead_tissue,lo		; get number of leading tissue as 0-15
	incf	lo,F						; adjust to 1-16
	movlw	.10
	cpfsgt	lo							; is it > 10 ?
	bra		TFT_dive_tissues_6			; NO - will output a single digit number
	; start position for a 2 digit number
	WIN_TINY dm_custom_tissue_diagram_left+.32,dm_custom_tissue_diagram_top+.10
	bra		TFT_dive_tissues_7
TFT_dive_tissues_6:
	; start position for a 1 digit number
	WIN_TINY dm_custom_tissue_diagram_left+.32+.4,dm_custom_tissue_diagram_top+.10
TFT_dive_tissues_7:
	FONT_COLOR_MEMO						; set output color
	bsf		leftbind					; print left-aligned
	output_99							; print tissue number (0-99)
	PRINT								; dump buffer to screen
	return								; done


	; Helper Function - draw a bargraph
TFT_dive_tissues_bargraph:
	addwf	hi,W						; add row number to start position
	movwf	win_top						; set as row top (0-239)
	movff	POSTINC2,up					; get tissue value
	movf	ex,W						; default color
	btfsc	up,7						; check if flag in bit 7 is set
	movf	ul,W						; YES - switch to 2nd color
	bcf		up,7						; clear flag  bit
	bcf		STATUS,C					; clear carry bit
	rrcf	up,F						; divide by 2
	movff	up,win_bargraph				; set bargraph length
	incf	win_bargraph,F				; add a bit for a minimum visible bar
	BOX_COLOR							; draw bargraph
	return								; done


;-----------------------------------------------------------------------------
; Dive Custom View - CNS - Mask
;
	global	TFT_CNS_mask
TFT_CNS_mask:
	FONT_COLOR_MASK						; select color

	WIN_TINY dm_custom_cns3_column1, dm_custom_cns3_title_row
	STRCPY_TEXT_PRINT tCNSsurf			; print label

	WIN_TINY dm_custom_cns3_column2, dm_custom_cns3_title_row

 IFDEF _cave_mode
	btfss	cave_mode					; cave mode switched on?
	bra		TFT_CNS_mask_col2			; NO
	STRCPY_TEXT_PRINT tCNScave			; YES - print cave TTS label
	bra		TFT_CNS_mask_col3			;     - continue with 3rd column
 ENDIF

TFT_CNS_mask_col2:
	btfsc	FLAG_oc_mode				; in OC mode?
	bra		TFT_CNS_mask_ftts			; YES - print fTTS label
	btfsc	bailout_mode				; NO  - in bailout?
	bra		TFT_CNS_mask_ftts			;       YES - print fTTS label (label will be printed, but a fTTS will actually not be calculated)
	TSTOSS	opt_calc_gasvolume			;       NO  - bailout volume calculation requested?
	bra		TFT_CNS_mask_ftts			;             NO  - print fTTS label
	;bra	TFT_CNS_mask_bo				;             YES - print bailout label

TFT_CNS_mask_bo:
	STRCPY_TEXT_PRINT tCNSBO			; print bailout label
	bra		TFT_CNS_mask_col3			; continue with 3rd column

TFT_CNS_mask_ftts:
	STRCPY_TEXT_PRINT tCNSfTTS			; print fTTS label
	;bra	TFT_CNS_mask_col3			; continue with 3rd column

TFT_CNS_mask_col3:
	WIN_TINY dm_custom_cns3_column3, dm_custom_cns3_title_row
	STRCPY_TEXT_PRINT tCNSnow			; print CNS now label
	return								; done


;-----------------------------------------------------------------------------
; Dive Custom View - CNS - Data
;
	global	TFT_CNS
TFT_CNS:
	; CNS at end of normal dive
	WIN_STD dm_custom_cns3_column1+.3,dm_custom_cns3_row
	MOVII	int_O_CNS_norm,mpr			; get CNS at end of dive in normal plan
	call	TFT_color_code_cns			; color-code the CNS value
	bsf		leftbind					; print left-aligned
	output_999							; print (0-999)
	STRCAT_PRINT "% "					; append unit and trailing space and dump to screen
	; fTTS / Bailout CNS, if enabled
	WIN_STD dm_custom_cns3_column2+.2,dm_custom_cns3_row
	btfsc	bailout_mode				; in bailout?
	bra		TFT_CNS_3					; YES - show "---"
	TSTOSS	opt_calc_gasvolume			; NO  - bailout volume calculation requested?
	bra		TFT_CNS_1					;       NO  - continue checking fTTS extra time
	btfss	FLAG_oc_mode				;       YES - in OC mode?
	bra		TFT_CNS_2					;             NO  - show CNS%
	;bra	TFT_CNS_1					;             YES - continue checking fTTS extra time

TFT_CNS_1:
	; not in bailout, no volume calculation, and/or in OC mode
	TSTOSS	char_I_extra_time			; fTTS extra time configured?
	bra		TFT_CNS_3					; NO  - show "---"
	;bra	TFT_CNS_2					; YES - show CNS%

TFT_CNS_2:
	MOVII	int_O_CNS_alt,mpr			; get CNS at end of dive in alternative plan
	call	TFT_color_code_cns			; color-code the CNS value
	bsf		leftbind					; print left-aligned
	output_999							; print (0-999)
	STRCAT_PRINT "% "					; append unit and trailing space and dump to screen
	bra		TFT_CNS_4					; continue

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
	FONT_COLOR_MEMO						; select color
	STRCPY_PRINT "---  "				; print non-avail symbol
	;bra	TFT_CNS_4					; continue

TFT_CNS_4:
	; current CNS
	WIN_STD dm_custom_cns3_column3+.3,dm_custom_cns3_row
	MOVII	int_O_CNS_current,mpr		; get current CNS
	call	TFT_color_code_cns			; color-code the CNS value
	bsf		leftbind					; print left-aligned
	output_999							; print (0-999)
	PUTC_PRINT "%"						; append unit and dump to screen
	return								; done


;-----------------------------------------------------------------------------
; Dive Custom View - ppO2, EAD/END & Gas Density - Mask
;
	global TFT_ppo2_ead_end_cns_mask
TFT_ppo2_ead_end_cns_mask:
	FONT_COLOR_MASK						; select color

	WIN_TINY dm_custom_ppo2_column-.2,dm_custom_ppo2_title_row
	STRCPY_TEXT_PRINT tppO2				; print label

	WIN_TINY dm_custom_ead_column,dm_custom_eadend_title_row
	STRCPY_TEXT_PRINT tDiveEAD_END		; print label

 IFDEF _ccr_pscr
	WIN_TINY dm_custom_cns_column-.5,dm_custom_eadend_title_row
	STRCPY_TEXT_PRINT tGasDensity		; print label
 ELSE
	WIN_TINY dm_custom_cns_column,dm_custom_cns_title_row
	STRCPY_TEXT_PRINT tCNS2				; print label
 ENDIF

	return								; done



;-----------------------------------------------------------------------------
; Dive Custom View - ppO2, EAD/END & Gas Density - Data
;
	global	TFT_ppo2_ead_end_cns
TFT_ppo2_ead_end_cns:
	; show ppO2
	WIN_MEDIUM dm_custom_ppo2_column, dm_custom_ppo2_row
	MOVII	int_O_breathed_ppO2,mpr		; copy ppO2 of the currently breathed gas to hi:lo
	call	TFT_color_code_ppo2			; color-code output
	bsf		decimal_digit2				; place a decimal point in front of digit 2
	output_999							; print ppO2 (0.00-9.99)
	PRINT								; dump to screen
	; show END/EAD
	FONT_COLOR_MEMO						; select color
	WIN_SMALL	dm_custom_ead_column, dm_custom_ead_row
	STRCPY_TEXT tEAD					; print "EAD:"
	MOVII	int_O_EAD_pres,mpr			; copy EAD in [mbar] to MPR
	rcall	TFT_end_ead_common			; convert to depth, print and limit to 8 chars
	WIN_SMALL dm_custom_end_column, dm_custom_end_row
	STRCPY_TEXT tEND					; print "END:"
	MOVII	int_O_END_pres,mpr			; copy END in [mbar] to MPR
	rcall	TFT_end_ead_common			; convert to depth, print and limit to 8 chars
 IFDEF _helium
	; show gas density
	WIN_MEDIUM	dm_custom_cns_column-.5, dm_custom_cns_row
	MOVII	int_O_gas_density,mpr		; get current gas density
	call	TFT_color_code_cns			; color-code output
	bsf		decimal_digit2				; place a decimal point in front of digit 2
	output_999							; print (0.00-9.99)
	PRINT								; dump to screen
 ELSE
	; show CNS
	WIN_STD	dm_custom_cns_column+.3, dm_custom_cns_row
	MOVII	int_O_CNS_current,mpr		; get current CNS
	call	TFT_color_code_cns			; color-code CNS output
	bsf		leftbind					; print left-aligned
	output_999							; print (0-999)
	PUTC_PRINT "%"						; append unit and dump buffer to screen
 ENDIF
	return								; done


	; Helper Function - convert to depth, print and limit to 8 chars
TFT_end_ead_common:
	call	convert_pres_to_depth		; convert pressure in [mbar] to depth in [cm]
	TSTOSS	opt_units					; 0=Meter, 1=Feet
	bra		TFT_end_ead_common_metric	; 0: meter
	;bra	TFT_end_ead_common_imperial	; 1: feet

TFT_end_ead_common_imperial:
	call	convert_cm_to_feet			; convert depth in [cm] to depth in [feet]
	output_999							; print (0-999)
	PRINT								; dump buffer to screen
	return								; done

TFT_end_ead_common_metric:
	bsf		omit_digit_2				; do not print 2nd and 1st digit
	output_65535						; print (0xx-655xx)
	PUTC_PRINT 'm'						; append unit and dump to screen
	return								; done


;-----------------------------------------------------------------------------
; Dive Custom View - GF Factors (Mask only)
;
	global	TFT_gf_factors_mask
TFT_gf_factors_mask:
	FONT_COLOR_MASK						; select color

	; show labels
	WIN_TINY dm_custom_gf_column1,dm_custom_gf_title_row
	STRCPY_TEXT_PRINT tGFactors
	WIN_TINY dm_custom_gf_column3,dm_custom_gf_title_row
	STRCPY_TEXT_PRINT taGFactors

	; show GF (static)
	WIN_STD	dm_custom_gf_column1, dm_custom_gf_row
	FONT_COLOR_DISABLED					; default to disabled color
	btfss	use_aGF						; shall use alternative GF factors?
	FONT_COLOR_MEMO						; NO - switch to memo color
	movff	opt_GF_low, lo				; get   normal GF low
	movff	opt_GF_high,hi				; get   normal GF high
	rcall	TFT_gf_factors_mask_helper	; print GFs

	; show aGF (static)
	FONT_COLOR_MEMO						; select memo color
	TSTOSS	opt_enable_aGF				; are alternative GF factors enabled?
	bra		TFT_gf_factors_mask_3		; NO  - show "---" and return
	; bra	TFT_gf_factors_mask_0		; YES - show arrow

TFT_gf_factors_mask_0:
	WIN_STD	dm_custom_gf_column2, dm_custom_gf_row
	btfss	use_aGF						; shall use aGF?
	bra		TFT_gf_factors_mask_1L		; NO   - print "<- "
	;bra	TFT_gf_factors_mask_1R		; YES  - print " ->"

TFT_gf_factors_mask_1R:
	STRCPY_PRINT " ->"					; print " ->"
	bra		TFT_gf_factors_mask_2		; continue

TFT_gf_factors_mask_1L:
	STRCPY_PRINT "<- "					; print "<- "
	;bra	TFT_gf_factors_mask_2		; continue

TFT_gf_factors_mask_2:
	WIN_STD	dm_custom_gf_column3, dm_custom_gf_row
	;FONT_COLOR_MEMO						; select memo color (still selected)
	btfss	use_aGF						; shall use aGF?
	FONT_COLOR_DISABLED					; NO - switch to disabled color
	movff	opt_aGF_low, lo				; get aGF low
	movff	opt_aGF_high,hi				; get aGF high
	rcall	TFT_gf_factors_mask_helper	; print GFs
	return								; done

TFT_gf_factors_mask_3:
	WIN_STD	dm_custom_gf_column3+.10, dm_custom_gf_row
	STRCPY_PRINT "---"					; print not-avail symbol
	return								; done

	; Helper Function - print GF pair
TFT_gf_factors_mask_helper:
	output_256							; print GF low  (0-255)
	PUTC	"/"							; print "/"
	movff	hi,lo						; get   GF high
	output_256							; print GF high (0-255)
	PRINT								; dump to screen
	return								; done


;-----------------------------------------------------------------------------
; Dive Custom View - Clock, Battery & Surface Pressure - Mask
;
	global	TFT_clock_batt_surfpress_mask
TFT_clock_batt_surfpress_mask:
	FONT_COLOR_MASK						; select color

	WIN_TINY dm_custom_clock_column, dm_custom_clock_title_row
	STRCPY_TEXT_PRINT tTime				; "Time"

	WIN_TINY dm_custom_battery_column, dm_custom_battery_title_row
	STRCPY_TEXT_PRINT tBattery			; "Battery"

	WIN_TINY dm_custom_surfpres_column+.8, dm_custom_surfpres_title_row
	STRCPY_TEXT_PRINT tSurface			; "Surface"

	; show configured surface pressure (done in mask, because it's static during the dive)
	WIN_SMALL dm_custom_surfpres_column, dm_custom_surfpres_row
	FONT_COLOR_MEMO						; select color
	MOVII	pressure_surf,mpr			; get surface pressure
	output_65535						; print (5 digits, first one used as spacer)
	PUTC	' '							; print a space
	STRCAT_TEXT_PRINT tMBAR				; append unit and dump to screen
	return								; done


;-----------------------------------------------------------------------------
; Dive Custom View - Clock, Battery & Surface Pressure - Data
;
	global	TFT_clock_batt_surfpress
TFT_clock_batt_surfpress:
	; update clock
	WIN_SMALL dm_custom_clock_column, dm_custom_clock_row
	FONT_COLOR_MEMO						; select color
	SMOVSS	rtc_year,rtc_latched_year	; ISR-safe 6 byte copy of date and time
	movff	rtc_latched_hour,lo			; get   hours
	output_99							; print hours (0-99)
	PUTC	':'							; print ":"
	movff	rtc_latched_mins,lo			; get   minutes
	output_99x							; print minutes (00-99)
	PUTC	":"							; print ":"
	movff	rtc_latched_secs,lo			; get   seconds
	output_99x							; print seconds (00-99)
	PRINT								; dump to screen

	; show battery voltage
	WIN_SMALL dm_custom_battery_column, dm_custom_battery_volt_row
	;FONT_COLOR_MEMO						; select color
	MOVII	batt_voltage,mpr			; get voltage
	bsf		decimal_digit3				; place a decimal point in front of digit 3
	bsf		omit_digit_1				; do not print 1st digit 
	output_9999							; print voltage (0.00x-9.99x)
	PUTC_PRINT 'V'						; append unit and dump to screen

	; show battery percent
	WIN_SMALL dm_custom_battery_column+.7, dm_custom_battery_percent_row
	call	TFT_color_code_battery		; color-code according to battery_low_condition flag
	movff	batt_percent,lo				; get   battery %
	output_256							; print battery % (0-999)
	PUTC_PRINT "%"						; append unit and dump to screen

	; surface pressure is shown via the mask because it is static
	return								; done


 IFDEF _ccr_pscr

;-----------------------------------------------------------------------------
; Dive Custom View - Sensor Check - Mask
;
	global	TFT_sensor_check_mask
TFT_sensor_check_mask:
	FONT_COLOR_MASK						; select color

	WIN_TINY dm_custom_s_check_title_column, dm_custom_s_check_title_row
	STRCPY_TEXT_PRINT tSensorCheck		; print label

	WIN_TINY dm_custom_ppO2_column, dm_custom_s_check_title_row
	STRCPY_TEXT_PRINT tppO2O2			; print label

	WIN_TINY dm_custom_ppDil_column, dm_custom_s_check_title_row
	STRCPY_TEXT_PRINT tppO2Dil			; print label

	return								; done


;-----------------------------------------------------------------------------
; Dive Custom View - Sensor Check - Data
;
	global	TFT_sensor_check
TFT_sensor_check:
	; show ppO2 of O2 in this depth
	WIN_MEDIUM dm_custom_ppO2_column, dm_custom_s_check_row
	MOVII	int_O_O2_ppO2,mpr			; copy ppO2 of pure O2 to hi:lo
	rcall	TFT_sensor_check_helper		; print ppO2
	; show ppO2 of the diluent in this depth
	WIN_MEDIUM	dm_custom_ppDil_column, dm_custom_s_check_row
	MOVII	int_O_pure_ppO2,mpr			; copy ppO2 of pure gas to hi:lo
	rcall	TFT_sensor_check_helper		; print ppO2
	return								; done

TFT_sensor_check_helper:
	call	TFT_color_code_ppo2			; color-code output
	bsf		decimal_digit2				; place a decimal point in front of digit 2
	output_999							; print ppO2 (0.00-9.99)
	PRINT								; dump to screen
	return								; done


;-----------------------------------------------------------------------------
; Dive Custom View - pSCR Info - Mask
;
	global	TFT_pscr_info_mask
TFT_pscr_info_mask:
	FONT_COLOR_MASK						; select color

	WIN_TINY dm_custom_pscr_drop_column, dm_custom_pscr_title_row
	STRCPY_TEXT_PRINT tPSCR_O2_drop		; print label

	WIN_TINY dm_custom_pscr_ratio_column, dm_custom_pscr_title_row
	STRCPY_TEXT_PRINT tPSCR_lungratio	; print label

	WIN_TINY dm_custom_ppo2_column-.2,dm_custom_ppo2_title_row
	btfsc	bailout_mode				; in bailout?
	bra		TFT_pscr_info_mask_2		; YES
	;bra	TFT_pscr_info_mask_1		; NO

TFT_pscr_info_mask_1:
	STRCPY_TEXT_PRINT tppO2Mix			; print "ppO2(Mix)"
	return								; done

TFT_pscr_info_mask_2:
	STRCPY_TEXT_PRINT tppO2				; print "ppO2"
	return								; done


;-----------------------------------------------------------------------------
; Dive Custom View - pSCR Info - Data
;
	global	TFT_pscr_info
TFT_pscr_info:
	;show ppO2
	WIN_MEDIUM dm_custom_ppo2_column,dm_custom_ppo2_row
	MOVII	int_O_pSCR_ppO2,mpr			; copy pSCR ppO2 to hi:lo
	call	TFT_color_code_ppo2			; color-code output
	bsf		decimal_digit2				; place a decimal point in front of digit 2
	output_999							; print ppO2 (0.00-9-99)
	PRINT								; dump to screen
	; show drop
	WIN_STD dm_custom_pscr_drop_column+.11,dm_custom_pscr_row
	FONT_COLOR_MEMO						; select color
	movff	char_I_PSCR_drop,lo			; get   drop
	output_99							; print drop (0-99)
	PUTC_PRINT "%"						; append unit and dump to screen
	; show lung ratio
	WIN_STD	dm_custom_pscr_ratio_column+.5,dm_custom_pscr_row
	;FONT_COLOR_MEMO						; select color
	movff	char_I_PSCR_lungratio,lo	; get ratio
	STRCPY	"1/"						; print "1/"
	bsf		leftbind					; print left-aligned
	output_256							; print ratio number (0-256)
	PRINT								; dump to screen
	return								; done

 ENDIF	; _ccr_psrc

 IFDEF _external_sensor

;-----------------------------------------------------------------------------
; Dive Custom View - Sensor ppO2 - Mask
;
	global	TFT_ppo2_sensors_mask
TFT_ppo2_sensors_mask:
	FONT_COLOR_MASK						; select color

	WIN_TINY dm_custom_hud_sensor1_column+.4,dm_custom_hud_title_row
	STRCPY_TEXT_PRINT tDiveHudMask1		; print label

	WIN_TINY dm_custom_hud_sensor2_column+.3,dm_custom_hud_title_row
	STRCPY_TEXT_PRINT tDiveHudMask2		; print label

	WIN_TINY dm_custom_hud_sensor3_column+.2,dm_custom_hud_title_row
	STRCPY_TEXT_PRINT tDiveHudMask3		; print label

	return								; done


;-----------------------------------------------------------------------------
; Dive Custom View - Sensor ppO2 - Data
;
; Definition of the output:
;
;  sensorX       use        voting         o2
; _calibrated    _O2       _logic        _ppo2          Output           Color
;    _ok      _sensorX    _sensorX     _sensorX
;-----------------------------------------------------------------------------------------------
;    0          -/-          -/-            -/-         "----"           memo
;    1           0           -/-            = 0         o2_ppo2_sensorX  attention
;    1           0           -/-            > 0         o2_ppo2_sensorX  disabled
;    1           1            0             -/-         o2_ppo2_sensorX  TFT_color_code_ppo2_hud + win_invert
;    1           1            1             -/-         o2_ppo2_sensorX  TFT_color_code_ppo2_hud
;
	global	TFT_ppo2_sensors
TFT_ppo2_sensors:

	; sensor 1
TFT_ppo2_sensors_1:
	btfsc	sensor1_calibrated_ok		; valid calibration?
	bra		TFT_ppo2_sensors_1b			; YES
	btfsc	sensor1_active				; NO - valid HUD data for this sensor?
	bra		TFT_ppo2_sensors_1b			;      YES
	;bra	TFT_ppo2_sensors_1a			;      NO

TFT_ppo2_sensors_1a:
	; no valid calibration
	WIN_STD dm_custom_hud_sensor1_column+.7, dm_custom_hud_row+.5
	FONT_COLOR_MEMO						; set color
	STRCPY_PRINT "---"					; print dashes
	bra		TFT_ppo2_sensors_2			; continue with sensor 2

TFT_ppo2_sensors_1b:
	; sensor has a valid calibration
	WIN_MEDIUM dm_custom_hud_sensor1_column,dm_custom_hud_row
	movff	sensor1_ppO2,lo				; load ppO2 value into transfer storage for output
	btfsc	use_O2_sensor1				; in use?
	bra		TFT_ppo2_sensors_1d			; YES
	tstfsz	lo							; NO  - sensor value = 0 ?
	bra		TFT_ppo2_sensors_1c			;       NO
	FONT_COLOR_ATTENTION				;       YES - set attention color
	bra		TFT_ppo2_sensors_1e			;           - print ppO2 value

TFT_ppo2_sensors_1c:
	; sensor has valid calibration, is not in use and has a value > 0
	FONT_COLOR_DISABLED					; set disabled color
	bra		TFT_ppo2_sensors_1e			; print ppO2 value

TFT_ppo2_sensors_1d:
	; sensor has valid calibration and is in use
	call	TFT_color_code_ppo2_hud		; color-code with ppO2 [cbar] in lo
	btfsc	voting_logic_sensor1		; sensor value agrees with values of other sensors?
	bra		TFT_ppo2_sensors_1e			; YES
	bsf		win_invert					; NO  - invert output
	;bra	TFT_ppo2_sensors_1e			; print ppO2 value

TFT_ppo2_sensors_1e:
	; all coloring is set up now, let's write the value to the display!
	bsf		decimal_digit2				; place a decimal point in front of digit 2
	output_256							; print (0.00-2.55)
	PRINT								; dump to screen

	; sensor 2
TFT_ppo2_sensors_2:
	btfsc	sensor2_calibrated_ok		; valid calibration?
	bra		TFT_ppo2_sensors_2b			; YES
	btfsc	sensor2_active				; NO  - valid HUD data for this sensor?
	bra		TFT_ppo2_sensors_2b			;       YES
	;bra	TFT_ppo2_sensors_2a			;       NO

TFT_ppo2_sensors_2a:
	; no valid calibration
	WIN_STD dm_custom_hud_sensor2_column+.7, dm_custom_hud_row+.5
	FONT_COLOR_MEMO						; set color
	STRCPY_PRINT "---"					; print dashes
	bra		TFT_ppo2_sensors_3			; continue with sensor 3

TFT_ppo2_sensors_2b:
	; sensor has a valid calibration
	WIN_MEDIUM dm_custom_hud_sensor2_column,dm_custom_hud_row
	movff	sensor2_ppO2,lo				; load ppO2 value into transfer storage for output
	btfsc	use_O2_sensor2				; in use?
	bra		TFT_ppo2_sensors_2d			; YES
	tstfsz	lo							; NO  - sensor value = 0?
	bra		TFT_ppo2_sensors_2c			;       NO
	FONT_COLOR_ATTENTION				;       YES - print in attention color
	bra		TFT_ppo2_sensors_2e			;           - print ppO2 value

TFT_ppo2_sensors_2c:
	; sensor has valid calibration, is not in use and has a value > 0
	FONT_COLOR_DISABLED					; output in light blue
	bra		TFT_ppo2_sensors_2e			; print ppO2 value

TFT_ppo2_sensors_2d:
	; sensor has valid calibration and is in use
	call	TFT_color_code_ppo2_hud		; color-code with ppO2 [cbar] in lo
	btfsc	voting_logic_sensor2		; sensor value agrees with values of other sensors?
	bra		TFT_ppo2_sensors_2e			; YES
	bsf		win_invert					; NO  - invert output
	;bra	TFT_ppo2_sensors_2e			;     - print ppO2 value

TFT_ppo2_sensors_2e:
	; all coloring is set up now, let's write the value to the display!
	bsf		decimal_digit2				; place a decimal point in front of digit 2
	output_256							; print (0.00-2.55)
	PRINT								; dump to screen

	; sensor 3
TFT_ppo2_sensors_3:
	btfsc	sensor3_calibrated_ok		; valid calibration?
	bra		TFT_ppo2_sensors_3b			; YES
	btfsc	sensor3_active				; NO - valid HUD data for this sensor?
	bra		TFT_ppo2_sensors_3b			;      YES
	;bra	TFT_ppo2_sensors_3a			;      NO

TFT_ppo2_sensors_3a:
	WIN_STD dm_custom_hud_sensor3_column+.7, dm_custom_hud_row+.5
	FONT_COLOR_MEMO						; set color
	STRCPY_PRINT "---"					; print dashes
	bra		TFT_ppo2_sensors_4			; done

TFT_ppo2_sensors_3b:
	; sensor has a valid calibration
	WIN_MEDIUM dm_custom_hud_sensor3_column,dm_custom_hud_row
	movff	sensor3_ppO2,lo				; load ppO2 value into transfer storage for output
	btfsc	use_O2_sensor3				; in use?
	bra		TFT_ppo2_sensors_3d			; YES
	tstfsz	lo							; NO  - sensor value = 0?
	bra		TFT_ppo2_sensors_3c			;       NO
	FONT_COLOR_ATTENTION				;       YES - print in attention color
	bra		TFT_ppo2_sensors_3e			;           - print ppO2 value

TFT_ppo2_sensors_3c:
	; sensor has valid calibration, is not in use and has a value > 0
	FONT_COLOR_DISABLED					; print in disabled color
	bra		TFT_ppo2_sensors_3e			; print ppO2 value

TFT_ppo2_sensors_3d:
	; sensor has valid calibration and is in use
	call	TFT_color_code_ppo2_hud		; color-code with ppO2 [cbar] in lo
	btfsc	voting_logic_sensor3		; sensor value agrees with values other sensors?
	bra		TFT_ppo2_sensors_3e			; YES
	bsf		win_invert					; NO  - invert output
	;bra	TFT_ppo2_sensors_3e			;     - print ppO2 value

TFT_ppo2_sensors_3e:
	; all coloring is set up now, let's write the value to the display!
	bsf		decimal_digit2				; place a decimal point in front of digit 2
	output_256							; print (0.00-2.55)
	PRINT								; dump to screen

TFT_ppo2_sensors_4:
	return								; done

 ENDIF	; _external_sensor

 IFDEF _rx_functions

;-----------------------------------------------------------------------------
; Dive Custom View - Pressures & SAC - Mask
;
	global	TFT_pressures_SAC_mask
TFT_pressures_SAC_mask:
	FONT_COLOR_MASK						; select color

	; pressure reading 1
	WIN_TINY dm_custom_tankdata_pres1_col, dm_custom_tankdata_mask_row
	movff	char_I_pressure_gas+0,WREG	; =0: disabled, =1..10: gases/dils
	bcf		aux_flag					; selector for disabled / need set to disabled
	rcall	TFT_pressures_SAC_mask_h1	; print gas composition or " ---" if disabled

	; pressure reading 2
	WIN_TINY dm_custom_tankdata_pres2_col, dm_custom_tankdata_mask_row
	movff	char_I_pressure_gas+1,WREG	; =0: need to reading 1, =1..10: gases/dils
	bsf		aux_flag					; selector for disabled / need set to need
	rcall	TFT_pressures_SAC_mask_h1	; print gas composition or "Need " if 0

	; SAC rate
	WIN_TINY dm_custom_tankdata_SAC_col, dm_custom_tankdata_mask_row
	STRCPY_TEXT tSAC					; "SAC
	STRCAT	" ("						;      (
	STRCAT_TEXT tLitersMinute			;       l/min
	PUTC_PRINT ")"						;            )"
	return								; done


	; Helper Function - print gas composition or " ---" if disabled
TFT_pressures_SAC_mask_h1:
	tstfsz	WREG						; pressure reading assigned?
	bra		TFT_pressures_SAC_mask_h2	; YES - print gas composition
	btfsc	aux_flag					; NO  - check auxiliary flag
	bra		TFT_pressures_SAC_mask_h3	;       1 - print "Need "
	STRCAT_PRINT "    ---"				;       0 - print "    ---"
	return								;         - done

TFT_pressures_SAC_mask_h2:
	decf	WREG,W						; (1..10) -> (0..9)
	bsf		short_gas_descriptions		; just "Air", "O2" or "xx/yy"
	call	gaslist_strcat_mix_WREG		; print composition of gas/dil in WREG (0..9)
	bra		TFT_pressures_SAC_mask_h4	; finish with adding "(bar)"

TFT_pressures_SAC_mask_h3:
	STRCPY_TEXT tNeed					; "Need"
	;bra	TFT_pressures_SAC_mask_h4 ; finish with adding "(bar)"

TFT_pressures_SAC_mask_h4:
	STRCAT_PRINT "(bar)"				; print "(bar)"
	return								; done


;-----------------------------------------------------------------------------
; Dive Custom View - Pressures & SAC - Data
;
	global	TFT_pressures_SAC
TFT_pressures_SAC:
	; check mode for second reading
	bcf		aux_flag					; clear auxiliary flag by default (reading 2 is pressure)
	movff	char_I_pressure_gas+1,WREG	; =0: need to reading 1, =1..10: gases/dils
	addlw	.0							; dummy operation to set status register flags
	btfsc	STATUS,Z					; gas selected = 0 (i.e. no 2nd pressure reading) ?
	bsf		aux_flag					; YES - set auxiliary flag (display position of reading 2 shall show need to reading 1)
	; get data of reading 1
	movff	int_IO_pressure_value+0,lo	; copy pressure 1 to hi:lo
	movff	int_IO_pressure_value+1,hi	; ...
	movff	char_I_pressure_stat+0,ex	; copy status data
	; pressure of reading 1
	WIN_STD dm_custom_tankdata_pres1_col+.4,dm_custom_tankdata_row
	rcall	TFT_pressures_SAC_helper_1	; print pressure if available, else " ---"
	; battery status of reading 1
	WIN_SMALL dm_custom_hud_sensor1_column+.4+.36,dm_custom_tankdata_row
	rcall	TFT_pressures_SAC_helper_2	; print or clear down arrow as low bat indicator
	; get data for reading 2
	btfsc	aux_flag					; shall reading 2 show need to reading 1 ?
	bra		TFT_pressures_SAC_1			; YES
	movff	int_IO_pressure_value+2,lo	; NO  - copy pressure 2 to hi:lo
	movff	int_IO_pressure_value+3,hi	;     - ...
	movff	char_I_pressure_stat+1,ex	;     - copy status data
	bra		TFT_pressures_SAC_2			;     - continue

TFT_pressures_SAC_1:
	MOVII	int_O_pressure_need,mpr		; copy need to pressure 1 to hi:lo
	clrf	ex							; set status data to 0
	bra		TFT_pressures_SAC_2			; continue

TFT_pressures_SAC_2:
	; pressure of reading 2
	WIN_STD dm_custom_tankdata_pres2_col+.2,dm_custom_tankdata_row
	rcall	TFT_pressures_SAC_helper_1	; print pressure if available, else " ---"
	; battery status of reading 2
	WIN_SMALL dm_custom_tankdata_pres2_col+.2+.36,dm_custom_tankdata_row
	rcall	TFT_pressures_SAC_helper_2	; print or clear down arrow as low bat indicator

TFT_pressures_SAC_3:
	; SAC
	WIN_STD dm_custom_tankdata_SAC_col+.6,dm_custom_tankdata_row
	MOVII	int_O_SAC_measured,mpr		; copy measured SAC rate to hi:lo
	btfsc	hi,int_not_avail_flag		; SAC rate available?
	bra		TFT_pressures_SAC_4			; NO - print " --.-"
	call	TFT_color_code_pres_sac		; color-code the output
	bsf		decimal_digit1				; place a decimal point in front of digit 1
	output_999							; print (0.0-99.9)
	PRINT								; dump to screen
	return								; done

TFT_pressures_SAC_4:
	FONT_COLOR_DISABLED					; set color
	STRCAT_PRINT "--.-"					; output for no SAC data available
	return								; done


	; Helper Function - print pressure if available, else " ---"
TFT_pressures_SAC_helper_1:
	btfss	hi,int_not_avail_flag		; pressure available?
	bra		TFT_pressures_SAC_helper_1a	; YES - print pressure
	FONT_COLOR_DISABLED					; NO  - use disabled color as default
;	btfsc	ex,char_transmitter_lost	;     - transmitter lost?
;	FONT_COLOR_ATTENTION				;       YES - use attention color
	STRCAT_PRINT " ---"					;     - print " ---"
	return

TFT_pressures_SAC_helper_1a:
	btfsc	hi,int_warning_flag			; out of range (signaled by warning flag)?
	bra		TFT_pressures_SAC_helper_1c	; YES - special treatment
	call	TFT_color_code_pres_sac		; NO  - color-code the output
	PUTC	' '							;     - add a space
	bsf		omit_digit_1				;     - do not print 1st digit (0.1 bar)
	output_999							;     - print pressure (0x-999x)
	PRINT								;     - dump buffer to screen
	return								;     - done

TFT_pressures_SAC_helper_1c:
	call	TFT_color_code_pres_sac		; color-code the output
	STRCPY_PRINT ">400"					; print ">400"
	return								; done


	; Helper Function - print or clear down arrow as low bat indicator
TFT_pressures_SAC_helper_2:
	btfss	ex,char_transmitter_low_bat	; low battery flag set?
	bra		TFT_pressures_SAC_helper_2b	; NO  - clear down arrow (low bat indicator)
	;bra	TFT_pressures_SAC_helper_2a	; YES - show  down arrow (low bat indicator)

TFT_pressures_SAC_helper_2a:
	FONT_COLOR_ATTENTION				; use attention color
	STRCPY_PRINT "\xb8"					; print down arrow as bat low indication
	return								; done

TFT_pressures_SAC_helper_2b:
	STRCPY_PRINT " "					; wipe out down arrow (low bat indicator)
	return								; done

 ENDIF _rx_functions

 IFDEF _cave_mode

;-----------------------------------------------------------------------------
; Dive Custom View - Cave Mode TTS, total Stops and Run Time - Mask
;

	global	TFT_cave_tts_mask
TFT_cave_tts_mask:
	FONT_COLOR_MASK						; select color

	WIN_TINY dm_custom_cave_title_column1,dm_custom_cave_title_row
	STRCPY_TEXT_PRINT tCaveStops		; print label

	WIN_TINY dm_custom_cave_title_column2,dm_custom_cave_title_row
	STRCPY_TEXT_PRINT tCaveTTS			; print label

	WIN_TINY dm_custom_cave_title_column3,dm_custom_cave_title_row
	STRCPY_TEXT_PRINT tCaveRuntime		; print label

	return								; done


;-----------------------------------------------------------------------------
; Dive Custom View - Cave Mode TTS, total Stops and Run Time - Data
;
	global	TFT_cave_tts
TFT_cave_tts:
	; total time of all stops
	WIN_MEDIUM dm_custom_cave_data_column1,dm_custom_cave_data_row
	FONT_COLOR_MEMO						; set default color
	btfss	cave_mode					; cave mode switched on?
	bra		TFT_cave_1b					; NO  - print dashes
	MOVII	int_O_TST_norm,mpr			; YES - get normal plan total stops time
	btfss	mpr+1,int_not_yet_computed	;     - not yet computed?
	bra		TFT_cave_1a					;       NO  - continue
	FONT_COLOR_DISABLED					;       YES - switch to disabled color
	bra		TFT_cave_1b					;           - print dashes

TFT_cave_1a:
	btfsc	mpr+1,int_invalid_flag		; stops time invalid?
	FONT_COLOR_DISABLED					; YES - switch to disabled color
	bcf		mpr+1,int_invalid_flag		; clear invalid flag if applicable
	movf	mpr+0,W						; copy     low  byte of stops time to WREG
	iorwf	mpr+1,W						; ior with high byte of stops time
	bz		TFT_cave_1b					; print dashes if stops time is zero
	output_999							; print (0-999)
	PUTC_PRINT "'"						; append unit and dump to screen
	bra		TFT_cave_2					; continue

TFT_cave_1b:
	STRCAT_PRINT ",-,-,-,"				; print 3 dashes (',' produces a half-width space)
	;bra	TFT_cave_2					; continue

TFT_cave_2:
	; cave TTS
	WIN_MEDIUM dm_custom_cave_data_column2,dm_custom_cave_data_row		; column 60
	FONT_COLOR_MEMO						; set default color
	btfsS	cave_mode					; cave mode switched on?
	bra		TFT_cave_2b					; NO  - print dashes
	MOVII	int_O_TTS_norm,mpr			; YES - get normal plan total time to surface
	btfss	mpr+1,int_not_yet_computed	;     - not yet computed?
	bra		TFT_cave_2a					;       NO  - continue
	FONT_COLOR_DISABLED					;       YES - switch to disabled color
	bra		TFT_cave_2b					;           - print dashes

TFT_cave_2a:
	btfsc	mpr+1,int_invalid_flag		; TTS invalid?
	FONT_COLOR_DISABLED					; YES - switch to disabled color
	bcf		mpr+1,int_invalid_flag		; clear invalid flag if applicable
	output_999							; print (0-999)
	PUTC_PRINT "'"						; append unit and dump to screen
	bra		TFT_cave_3					; continue

TFT_cave_2b:
	STRCAT_PRINT ",-,-,-,"				; print 3 dashes (',' produces a half-width space)
	;bra	TFT_cave_3					; continue

TFT_cave_3:
	; estimated total runtime
	WIN_MEDIUM dm_custom_cave_data_column3,dm_custom_cave_data_row
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
	output_999							;           - print (0-999)
	PUTC_PRINT "'"						;           - append unit and dump to screen
	return								;           - done

TFT_cave_3b:
	STRCAT_PRINT ",-,-,-,"				; print 3 dashes (',' produces a half-width space)
	return								; done


;-----------------------------------------------------------------------------
; Dive Custom View - Cave Mode Waypoints
;
	global	TFT_cave_waypoints
TFT_cave_waypoints:
	; arrow
	WIN_TINY .70,dm_custom_cave_title_row
	FONT_COLOR_ATTENTION				; select color
	btfss	cave_mode					; cave mode switched on?
	bra		TFT_cave_waypoints_3		; NO  - do not show any marker (any more)
	btfsc	dive_turned					; YES - dive turned?
	bra		TFT_cave_waypoints_2		;       YES - print marker in the middle
	;bra	TFT_cave_waypoints_1		;       NO  - print marker on right side

TFT_cave_waypoints_1:
	movlw	.12							; start with 12 space chars
	call	TFT_buffer_trim_length		; fill / cut buffer to target length
	;bra	TFT_cave_waypoints_2		; continue

TFT_cave_waypoints_2:
	STRCAT	"<====="					; print marker symbol
	;bra	TFT_cave_waypoints_3		; continue

TFT_cave_waypoints_3:
	movlw	.18							; set overall number of chars
	call	TFT_buffer_trim_length		; fill / cut buffer to target length
	PRINT								; dump buffer to screen
	; waypoint band
	btfsc	cave_mode					; cave mode switched on?
	bra		TFT_cave_waypoints_4		; YES - show graphics
	WIN_STD .0,dm_custom_cave_data_row	; NO  - show "Cave Mode off" text
	FONT_COLOR_ATTENTION				;     - select attention color
	PUTC	" "							;     - print 2 space chars
	PUTC	" "							;     - ...
	STRCAT_TEXT tCaveMode				;     - print "Cave Mode"
	PUTC	" "							;     - print 1 space char
	STRCAT_TEXT tOff					;     - print "off"
	movlw	.17							;     - set max number of chars
	call	TFT_buffer_trim_length		;     - fill / cut buffer to target length
	PRINT								;     - dump buffer to screen
	return								;     - done

TFT_cave_waypoints_4:
	WIN_MEDIUM .0,dm_custom_cave_data_row; start in column 0
	FONT_COLOR_MEMO						; select default color
	tstfsz	DM_flags_cavereq			; any pending cave mode requests?
	FONT_COLOR_DISABLED					; YES - switch to disabled color
	; 1st section: previous waypoint number or beginning line
	movlw	.1							; load a one into WREG
	cpfsgt	backtrack_waypoint_num		; current waypoint number > 1 ?
	bra		TFT_cave_waypoints_5		; NO  - print line segment only
	STRCAT	",-,"						; YES - print one dash
	movff	backtrack_waypoint_num,lo	;     - copy current waypoint number to lo
	decf	lo,F						;     - create previous waypoint number
	output_99							;     - print  previous waypoint number in two digit format
	STRCAT	","							;     - print a half-space
	bra		TFT_cave_waypoints_6		;     - continue with next section

TFT_cave_waypoints_5:
	STRCAT	",-,-----"					; print line segment
	;bra	TFT_cave_waypoints_6		; continue with next section

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
	STRCAT_PRINT "--|,     "			; YES - print end-of-line symbol, clear remaining output and dump buffer to screen
	return								;     - done

TFT_cave_waypoints_9:
	movff	backtrack_waypoint_num,lo	; copy  current waypoint number to lo
	output_99 							; print current waypoint number in two digit format
	STRCAT	","							; print a half-space
	;bra	TFT_cave_waypoints_10		; continue with next section

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
	PRINT								;           - dump buffer to screen
	return								;           - done

TFT_cave_waypoints_11:
	STRCAT_PRINT "---|,"				; print end-of-line symbol and dump buffer to screen
	return								; done

 ENDIF	; _cave_mode


;=============================================================================
tft_out15	CODE
;=============================================================================


;-----------------------------------------------------------------------------
; Helper Function - check if firmware is within expiry period
;
; Output:  aux_flag set if not
;
check_expiry:
	SMOVSS	rtc_year,rtc_latched_year	; ISR-safe 6 byte copy of date and time
	movff	rtc_latched_day,lo			; get current day
	movff	rtc_latched_month,hi		; get current month
	movff	rtc_latched_year,up			; get current year
	bsf		aux_flag					; set firmware as expired by default
	movlw	firmware_expire_year		; start with checking year
	cpfsgt	up							; current year > expiry year ?
	bra		check_expiry_Y				; NO  - continue checks
	return								; YES - expired

check_expiry_Y:
	cpfseq	up							; current year = expiry year ?
	bra		check_expiry_ok				; NO  - must be < then, OK whatever month & day
	movlw	firmware_expire_month		; YES - continue checking month
	cpfsgt	hi							; current month > expiry month ?
	bra		check_expiry_M				; NO  - continue checks
	return								; YES - expired

check_expiry_M:
	cpfseq	hi							; current month = expiry month ?
	bra		check_expiry_ok				; NO  - must be < then, OK whatever day
	movlw	firmware_expire_day			; YES - continue checking day
	cpfsgt	lo							; current day > expiry day ?
	bra		check_expiry_ok				; NO  - must be <= then, OK
	return								; YES - expired

check_expiry_ok:
	bcf		aux_flag					; not expired
	return								; done 


;-----------------------------------------------------------------------------
; show Firmware updated Message
;
; Attention:
; Pallet colors and language switching are not
; available yet, all text outputs are hard-coded!
;
	global	TFT_message_fw_update
TFT_message_fw_update:
	FONT_COLOR_STANDARD					; set color

	; show update message
	WIN_SMALL .20,.100					; set position
	STRCPY_PRINT "Update successful!"	; print message

	; show firmware version
	WIN_SMALL .20,.140					; set position
	STRCPY	"New Firmware: "			; print message

	bra		TFT_message_fw_common		; show firmware version


;-----------------------------------------------------------------------------
; show Firmware kept Message
;
; Attention:
; Pallet colors and language switching are not
; available yet, all text outputs are hard-coded!
;
	global	TFT_message_fw_kept
TFT_message_fw_kept:
	FONT_COLOR_STANDARD					; set color

	; show reboot message
	WIN_SMALL .60,.100					; set position
	STRCPY_PRINT "Reboot"				; print message

	; show firmware version
	WIN_SMALL .30,.140					; set position
	STRCPY	"Firmware: "				; print message

	;bra	TFT_message_fw_common		; show firmware version


	; Helper Function - show firmware version x.y and color-code + invert if outdated
TFT_message_fw_common:
	rcall	TFT_cat_firmware			; append major/minor and color-code on expiry
	PRINT								; dump to screen
	; show firmware beta status
	WIN_SMALL .60,.180
	FONT_COLOR_STANDARD					; set default color for a release version
	rcall	TFT_cat_beta_long			; show "Release" or "BETA" + issue
	PRINT								; dump to screen
	return								; done


;-----------------------------------------------------------------------------
; append Firmware Version to current String, including color-coding on expiry
;
	global	TFT_cat_firmware
TFT_cat_firmware:
	movlw	fw_version_major			; get major
	movwf	lo							; ...
	bsf		leftbind					; print left-aligned
	output_99							; print major (0-99)
	PUTC	'.'							; print a dot
	movlw	fw_version_minor			; get minor
	movwf	lo							; ...
	output_99x							; print minor in two digit format
	rcall	check_expiry				; check if firmware is expired
	btfss	aux_flag					; expired?
	return								; NO
	bsf		win_invert					; YES - print in inverse
	FONT_COLOR color_yellow				;     - print in yellow
	return								;     - done


;-----------------------------------------------------------------------------
; append Firmware BETA Status to current String, including color-coding on BETA
;
	global	TFT_cat_beta_long
TFT_cat_beta_long:
	bsf		aux_flag					; do long version
	bra		TFT_cat_beta_common			; continue with common part

	global	TFT_cat_beta_short
TFT_cat_beta_short:
	bcf		aux_flag					; do short version
	;bra	TFT_cat_beta_common			; continue with common part

TFT_cat_beta_common:

 IFDEF _DEBUG

	FONT_COLOR color_red				; set color
	btfss	aux_flag					; shall show long version?
	bra		TFT_cat_debug_short			; NO  - show short version
	;bra	TFT_cat_debug_long			; YES - show long  version

TFT_cat_debug_long:
	STRCAT	"DEBUG"						; print long  debug
	return								; done

TFT_cat_debug_short:
	STRCAT	"DBG."						; print short debug
	return								; done

 ELSE

	movlw	fw_version_beta				; =0: release, =1: beta 1, =2: beta 2, ...
	movwf	lo							; copy to lo
	tstfsz	lo							; release version?
	bra		TFT_cat_beta_com			; NO  - must be beta version then
	btfss	aux_flag					; YES - shall show long version?
	bra		TFT_cat_beta_rel_short		;       NO  - show short version
	rcall	check_expiry				;       YES - check  expiry date
	btfsc	aux_flag					;           - within expiry date?
	bra		TFT_cat_beta_update			;             NO  - give update cue
	;bra	TFT_cat_beta_rel_long		;             YES - "Release"

TFT_cat_beta_rel_long:
	STRCAT	"Release"					; print long "Release"
	return								; done

TFT_cat_beta_rel_short:
	STRCAT "Rel."						; print short "Release"
	return								; done

TFT_cat_beta_com:
	FONT_COLOR color_yellow				; set color
	btfss	aux_flag					; shall show long  version?
	bra		TFT_cat_beta_short_exec		; NO  - show short version
	;bra	TFT_cat_beta_long_exec		; YES - show long  version

TFT_cat_beta_long_exec:
	STRCAT	"Beta "						; print long "Beta"
	bra		TFT_cat_beta_version		; print version

TFT_cat_beta_short_exec:
	STRCAT "B."							; print short "Beta"
	;bra	TFT_cat_beta_version		; append beta version number

TFT_cat_beta_version:
	bsf		leftbind					; print left-aligned
	output_256							; print beta version number (0-255)
	return								; done

TFT_cat_beta_update:
	FONT_COLOR color_yellow
	STRCAT "update!"					; print update cue
	return								; done

 ENDIF


;-----------------------------------------------------------------------------
; append Serial Number to to current String
;
	global	TFT_cat_serial
TFT_cat_serial:
	call	eeprom_serial_number_read	; read OSTC serial number
	bsf		leftbind					; print left-aligned
	output_65535						; print serial number
	return								; done


;-----------------------------------------------------------------------------
; print Serial Number and Firmware Version (used by comm mode)
;
	global	TFT_print_serial_and_firmware
TFT_print_serial_and_firmware:
	STRCPY	"#"							; print "#"
	rcall	TFT_cat_serial				; print serial number
	STRCAT	" "							; print a space
	STRCAT	"v"							; print a "v" (version)
	;bra	TFT_print_firmware			; print firmware version


;-----------------------------------------------------------------------------
; print Firmware Version
;
	global	TFT_print_firmware
TFT_print_firmware:
	rcall	TFT_cat_firmware			; print firmware major/minor, will set win_invert if outdated
	STRCAT	" "							; print a space
	rcall	TFT_cat_beta_long			; print release/beta and update notification if expired
	PRINT								; dump to screen
	return								; done


;-----------------------------------------------------------------------------
; print Deco Type (OC, CCR, ...)
;
; Input: lo  deco type number:  0=OC, 1=CCR, 2=Gauge, 3=Apnea, 4=pSCR
;
	global	TFT_print_decotype
TFT_print_decotype:
	bsf		aux_flag					; default to dive with deco calculation (used by logbook)
	incf	lo,W						; WREG = lo + 1
TFT_print_decotype_1
	decfsz	WREG,W						; in OC mode?
	bra		TFT_print_decotype_2		; NO  - try next
	STRCAT_TEXT_PRINT tDvOC				; YES - print "OC"
	return								;     - done
TFT_print_decotype_2:
	decfsz	WREG,W						; in CCR mode?
	bra		TFT_print_decotype_3		; NO  - try next
	STRCAT_TEXT_PRINT tDvCC				; YES - print "CCR"
	return								;     - done
TFT_print_decotype_3:
	decfsz	WREG,W						; in gauge mode?
	bra		TFT_print_decotype_4		; NO  - try next
	bcf		aux_flag					; YES - dive without deco data
	STRCAT_TEXT_PRINT tDvGauge			;     - Print "Gauge"
	return								;     - done
TFT_print_decotype_4:
	decfsz	WREG,W						; in apnea mode?
	bra		TFT_print_decotype_5		; NO  - try next
	bcf		aux_flag					; YES - dive without deco data
	STRCAT_TEXT_PRINT tDvApnea			;     - print "Apnoe"
	return								;     - done
TFT_print_decotype_5:
	STRCAT_TEXT_PRINT tDvPSCR			; print "pSCR"
	return								; done


;=============================================================================
tft_out16	CODE
;=============================================================================

	global	TFT_debug_output
TFT_debug_output:

 IFNDEF _debug_output

	return										; do nothing

 ELSE

;	btfsc	alt_layout_active					; alternative layout active?
;	return										; YES - abort

	WIN_TINY .100,.30							; surface mode: fits under the textual logo in the upper right corner
;	WIN_TINY  .35, .0							; dive    mode: fits to the right side of the depth label
;	WIN_TINY   .0, .		0					; dive    mode: overwrites depth label
	FONT_COLOR_MEMO								; set color
	
	movff	ambient_light+0,lo
	output_256
	PUTC	","
	movff	ambient_light+0,lo
	movff	ambient_light+1,hi
	output_65535

	

;	; deco engine scheduling performance
;	MOVII	int_O_profiling_overrun,mpr			; runtime +/- versus target
;	btfss	mpr+1,7								; overrun?
;	bra		TFT_debug_output_1					; YES
;	bcf		mpr+1,7								; NO - clear flag
;	PUTC	"-"									;    - print a minus
;	bra		TFT_debug_output_2					;    - continue
;TFT_debug_output_1:
;	PUTC	" "									; print a space instead of the minus
;TFT_debug_output_2:
;	output_999									; print time (0-999)
;	PUTC	"."									; print a dot as separator
;	MOVII	int_O_profiling_overrun_max,mpr		; get max runtime so far
;	output_999									; print (0-999)
;	PUTC	"."									; print a dot as separator
;	movff	char_O_profiling_overrun_phase,WREG	; get calculation phase causing the max runtime
;	output_hex									; print a hex
;	PUTC	"."									; print a dot as separator
;	movff	char_O_profiling_runs_norm,mpr		; get runs/cycle normal plan
;	output_99									; print (0-99)
;	PUTC	"."									; print a dot as separator
;	movff	char_O_profiling_runs_alt,mpr		; get runs/cycle alternative plan
;	output_99									; print (0-99)
	PRINT										; dump to screen
	return										; done

 ENDIF	; _debug_output

;-----------------------------------------------------------------------------

	END
