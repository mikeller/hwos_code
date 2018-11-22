;=============================================================================
;
;   File divemenu_tree.asm							REFACTORED VERSION V2.99e
;
;   OSTC dive mode menu
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;   2013-02-02 : [mH] Made out of menu_tree.asm

#include "hwos.inc"						; Mandatory header
#include "menu_processor.inc"
#include "shared_definitions.h"			; Mailbox from/to p2_deco.c
#include "tft_outputs.inc"
#include "customview.inc"
#include "strings.inc"
#include "calibrate.inc"

	extern	timeout_divemode_menu2
	extern	restart_deco_engine_wo_ceiling
	extern	diveloop_loop4


dmenu_tree		CODE

;=============================================================================
; Main Menu

do_return_main_divemenu:
	call	menu_processor_double_pop	; drop exit line and back to last line
	incf	selected_item,W				; item numbers start with 0, menu positions with 1
	movwf	menupos1					; position cursor where we came from
	bra		do_main_divemenu_common

	global	do_main_divemenu
do_main_divemenu:
	call	menu_processor_reset		; restart from first icon
	movlw	.1
	movwf	menupos1					; set to first option in divemode menu

do_main_divemenu_common:
	btfsc	FLAG_ccr_mode
	bra		main_divemenu_loop			; goto CCR / pSCR Menu menu
	btfsc	FLAG_pscr_mode
	bra		main_divemenu_loop			; goto CCR / pSCR Menu menu

main_divemenu_OC:
	bcf		FLAG_diluent_setup			; set to operations on OC gases
	bcf		is_bailout_menu

 IFDEF _cave_mode
	btfss	FLAG_cave_mode				; in cave mode?
	bra		main_divemenu_OC_no_cave	; NO - do OC menu without turn option

	MENU_BEGIN	tMainMenu,	.6
		MENU_CALL		tDivemenu_Gaslist,	do_divemode_gaslist
		MENU_CALL		tDivemenu_ResetAvg,	do_reset_average
		MENU_DYNAMIC	do_toggle_gf_label,	do_toggle_gf
		MENU_CALL		tDivemenu_Marker,	do_set_marker
		MENU_DYNAMIC	do_turn_dive_label,	do_turn_dive
		MENU_CALL		tExit,				do_exit_divemode_menu
	MENU_END
 ENDIF

main_divemenu_OC_no_cave:
	MENU_BEGIN	tMainMenu,	.5
		MENU_CALL		tDivemenu_Gaslist,	do_divemode_gaslist
		MENU_CALL		tDivemenu_ResetAvg,	do_reset_average
		MENU_DYNAMIC	do_toggle_gf_label,	do_toggle_gf
		MENU_CALL		tDivemenu_Marker,	do_set_marker
		MENU_CALL		tExit,				do_exit_divemode_menu
	MENU_END


main_divemenu_loop:
	bsf		FLAG_diluent_setup			; set to operations on diluents
	bcf		is_bailout_menu				; flag as none-bailout menu
	btfsc	FLAG_pscr_mode
	bra		main_divemenu_pscr			; pSCR menu

	MENU_BEGIN	tMainMenu,	.6
		MENU_CALL		tDiveBailout,		do_divemode_gaslist_bail
		MENU_CALL		tDivemenu_Setpoint,	do_divemode_splist
		MENU_CALL		tDivemenu_Diluent,	do_divemode_gaslist
		MENU_CALL		tDivemenu_Avg_Mkr,	do_reset_avg_set_mkr
		MENU_DYNAMIC	do_toggle_gf_label,	do_toggle_gf
		MENU_CALL		tExit,				do_exit_divemode_menu
	MENU_END

main_divemenu_pscr:
	btfsc	analog_o2_input				; do we have an analog  input (OSTC cR)?
	bra		main_divemenu_pscr_sensors	; YES
	btfsc	optical_input				; do we have an optical input (OSTC 3)?
	bra		main_divemenu_pscr_sensors	; YES

main_divemenu_pscr_no_sensors:
	MENU_BEGIN	tMainMenu,	.6
		MENU_CALL		tDiveBailout,		do_divemode_gaslist_bail
		MENU_CALL		tDivemenu_Premix,	do_divemode_gaslist
		MENU_CALL		tBackToLoop,		do_switch_sp_calc
		MENU_CALL		tDivemenu_Avg_Mkr,	do_reset_avg_set_mkr
		MENU_DYNAMIC	do_toggle_gf_label,	do_toggle_gf
		MENU_CALL		tExit,				do_exit_divemode_menu
	MENU_END

main_divemenu_pscr_sensors:
	MENU_BEGIN	tMainMenu,	.6
		MENU_CALL		tDiveBailout,		do_divemode_gaslist_bail
		MENU_CALL		tCCRSensor,			do_divemode_setpoint_pscr
		MENU_CALL		tDivemenu_Premix,	do_divemode_gaslist
		MENU_CALL		tDivemenu_Avg_Mkr,	do_reset_avg_set_mkr
		MENU_DYNAMIC	do_toggle_gf_label,	do_toggle_gf
		MENU_CALL		tExit,				do_exit_divemode_menu
	MENU_END


do_toggle_gf:
	TSTOSS	char_I_deco_model			; toggle GF only in GF modes - in GF mode? (0 = ZH-L16, 1 = ZH-L16-GF)
	bra		do_main_divemenu_common		; NO - do nothing and return
	TSTOSS	opt_enable_aGF				; =1: aGF can be selected underwater
	bra		do_main_divemenu_common		; NO - do nothing and return
	movlw	index_gf_factors-1			; custom view number one below GF factors
	movwf	menupos3					; set custom view number
	bsf		toggle_customview			; initiate toggle to desired custom view -> GF factors
	movlw	.1
	movwf	menupos1					; set to first option in dive mode menu

	MENU_BEGIN	tDivemenu_ToggleGF,	.2
		MENU_CALL		tDivemenu_ToggleGF,	do_togglegf
		MENU_CALL		tBack,				do_return_main_divemenu
	MENU_END

do_togglegf:
	bsf		toggle_gf					; set command flag...
	bra		do_exit_divemode_menu		; continue with exiting menu code


do_reset_avg_set_mkr:
	movlw	.1
	movwf	menupos1					; set to first option in dive mode menu

 IFDEF _cave_mode
	btfss	FLAG_cave_mode				; in cave mode?
	bra		do_reset_average_no_cave	; NO - do menu without turn option

	MENU_BEGIN	tDivemenu_Avg_Mkr,	.4
		MENU_CALL		tDivemenu_ResetAvg,	do_reset_average
		MENU_CALL		tDivemenu_Marker,	do_set_marker
		MENU_DYNAMIC	do_turn_dive_label,	do_turn_dive
		MENU_CALL		tBack,				do_return_main_divemenu
	MENU_END
 ENDIF

do_reset_average_no_cave:
	MENU_BEGIN	tDivemenu_Avg_Mkr,	.3
		MENU_CALL		tDivemenu_ResetAvg,	do_reset_average
		MENU_CALL		tDivemenu_Marker,	do_set_marker
		MENU_CALL		tBack,				do_return_main_divemenu
	MENU_END


do_reset_average:
	bsf		reset_average_depth			; set flag...
	bra		do_exit_divemode_menu		; ... and exit

do_set_marker:
	bsf		FLAG_set_marker				; set flag...
	bra		do_exit_divemode_menu		; ... and exit

 IFDEF _cave_mode
do_turn_dive:
	bsf		toggle_turn_dive			; set flag...
	bra		do_exit_divemode_menu		; ... and exit
 ENDIF


do_switch_sensor:						; entry point when coming from switch to sensor
	movlw	.1							; switch to sensor
	movff	WREG,opt_ccr_mode			; =0: Fixed SP (CCR) / calculated (pSCR), =1: Sensor, =2: Auto SP
	; enable all sensors
	bsf		use_O2_sensor1
	bsf		use_O2_sensor2
	bsf		use_O2_sensor3
	bra		do_switch_sp_com			; continue with common part

do_switch_sp:							; entry point when coming from manual setpoint selection (CCR)
	decf	menupos1,W					; 1-5 -> 0-4
	lfsr	FSR1,char_I_setpoint_cbar
	movff	PLUSW1,char_I_const_ppO2	; setup fixed setpoint
	movff	char_I_const_ppO2,WREG
	call	transmit_setpoint			; transmit current setpoint from WREG (in cbar) to external electronics
	bcf		setpoint_fallback			; clear fallback condition (stops fallback warning)
	clrf	WREG						; switch to fixed SP
	movff	WREG,opt_ccr_mode			; =0: Fixed SP (CCR) / calculated (pSCR), =1: Sensor, =2: Auto SP
	bra		do_switch_sp_com

do_switch_sp_calc:						; entry point when coming from switch to calculated ppO2 (pSCR)
	bcf		setpoint_fallback			; clear fallback condition (stops fallback warning)
	clrf	WREG						; Switch to fixed SP
	movff	WREG,opt_ccr_mode			; =0: Fixed SP (CCR) / calculated (pSCR), =1: Sensor, =2: Auto SP
	movff	WREG,char_I_const_ppO2		; set setpoint to 0, this forces deco engine to take the computed ppO2

do_switch_sp_com:						; merge point to common part
	bsf		event_occured				; set global event byte
	bsf		setpoint_changed			; set flag (for profile)

	; Clear some flags in case we were in bailout before...
	bcf		FLAG_bailout_mode			; end bailout mode
	;bcf	is_bailout_menu				; not needed
	bcf		better_gas_available		; =1: a better gas is available and a gas change is advised in dive mode
	bcf		better_dil_available		; =1: a better diluent is available and a gas change is advised in dive mode
	bcf		blinking_better_gas			; clear blinking flag
	bcf		blinking_better_dil			; clear blinking flag
	bsf		redraw_custview_mask		; request update of custom view mask to (eventually) rewrite "ppO2(Dil)" to "ppO2" or SAC label

	bsf		FLAG_back_to_loop			; indicate that it is a switchback from OC bailout to CCR/pSCR loop
	bsf		divemode_gaschange			; initiate reconfiguration to loop mode on last diluent

	bra		do_exit_divemode_menu		; continue with exiting menu code


do_divemode_gaslist_bail:				; entry point from CCR/pSCR to bailout to OC gases
	bcf		FLAG_diluent_setup			; switch to OC gases
	bsf		is_bailout_menu				; flag it is a bailout action
do_divemode_gaslist:					; entry point for switching: OC -> gases, loop -> diluents
	btfsc	FLAG_bailout_mode			; in bailout mode?
	bcf		FLAG_diluent_setup			; yes - for safety reasons, redirect to OC (bailout) gases
	bsf		short_gas_decriptions		; do not show "Gas x" etc.
	bsf		better_gas_hint				; mark the gas which is the best gas/diluent
	movf	best_gas_number,W			; load number of best gas (1-5)into WREG
	btfsc	FLAG_diluent_setup			; in diluent selection?
	movf	best_dil_number,W			; YES - overwrite with best diluent (1-5)
	bnz		do_divemode_gaslist_1		; best gas/dil number  =   0 (none available) ?
	movlw	.1							; YES - default to first gas/dil
	btfsc	WREG,7						; best gas/dil number >= 128 (not computed yet) ?
	movlw	.1							; YES - default to first gas/dil
do_divemode_gaslist_1:
	movwf	menupos1					; position cursor to best gas/dil (or first option if none avail)
	MENU_BEGIN	tGaslist,	.6
		MENU_DYNAMIC	gaslist_strcat_gas_cd,	do_switch_gas
		MENU_DYNAMIC	gaslist_strcat_gas_cd,	do_switch_gas
		MENU_DYNAMIC	gaslist_strcat_gas_cd,	do_switch_gas
		MENU_DYNAMIC	gaslist_strcat_gas_cd,	do_switch_gas
		MENU_DYNAMIC	gaslist_strcat_gas_cd,	do_switch_gas
		MENU_CALL		tMore,					do_divemode_gaslist_more
	MENU_END


do_divemode_gaslist_more:
	movlw	.1
	movwf	menupos1						; set to first option in dive mode menu

	movff	char_I_O2_ratio,gas6_O2_ratio	; initialize gas6 with currently breathed gas - O2 ratio
	movff	char_I_He_ratio,gas6_He_ratio	; initialize gas6 with currently breathed gas - He ratio

do_divemode_gaslist_more_common:
	MENU_BEGIN	tGaslist,	.6
		MENU_CALL		tO2Plus,				do_dive_pO2
		MENU_CALL		tO2Minus,				do_dive_mO2
		MENU_CALL		tHePlus,				do_dive_pHe
		MENU_CALL		tHeMinus,				do_dive_mHe
		MENU_DYNAMIC	gaslist_strcat_gas6,	do_switch_gas6
		MENU_CALL		tDivemenu_LostGas,		do_lost_gas
	MENU_END


do_lost_gas:
	movlw	.1
	movwf	menupos1					; set to first option in dive mode menu
do_lost_gas_common:
	bsf		short_gas_decriptions		; do not show "Gas x" etc.
	bcf		better_gas_hint				; do not mark the best gas/diluent
	MENU_BEGIN	tDivemenu_LostGas, .6
		MENU_DYNAMIC	gaslist_strcat_gas_cd,	do_toggle_active	; toggle the gas (in)active
		MENU_DYNAMIC	gaslist_strcat_gas_cd,	do_toggle_active	; toggle the gas (in)active
		MENU_DYNAMIC	gaslist_strcat_gas_cd,	do_toggle_active	; toggle the gas (in)active
		MENU_DYNAMIC	gaslist_strcat_gas_cd,	do_toggle_active	; toggle the gas (in)active
		MENU_DYNAMIC	gaslist_strcat_gas_cd,	do_toggle_active	; toggle the gas (in)active
		MENU_CALL		tExit,					do_exit_divemode_menu
	MENU_END


do_switch_gas6:
	movlw	.6							; gas 6
	movwf	menupos1					; transfer register for selected gas towards gas_switched_common
	bsf		gas6_changed				; set flag for profile recording
	;bra	do_switch_gas				; continue with common gas-switched code

do_switch_gas:
	bsf		divemode_gaschange			; set flag, will also trigger restart of deco_engine
	btfss	is_bailout_menu				; doing a bailout?
	bra		do_switch_gas_1				; NO
	bsf		FLAG_bailout_mode			; YES - begin bailout mode
 IFDEF _cave_mode
	btfsc	FLAG_cave_mode				;     - in cave mode?
	bsf		FLAG_dive_turned			;       YES - set dive as turned
 ENDIF
do_switch_gas_1:
	bcf		setpoint_fallback			; eventually terminate fallback mode and get rid of its warning
	bsf		redraw_custview_mask		; request update of custom view mask to (eventually) rewrite "ppO2(Dil)" to "ppO2" or SAC label
	;bra	do_exit_divemode_menu		; continue with exiting menu code

do_exit_divemode_menu:
	call	timeout_divemode_menu2
	clrf	STKPTR
	goto	diveloop_loop4


do_toggle_active:
	movlw	.5
	btfsc	FLAG_diluent_setup			; operating on diluents?
	addwf	menupos1,F					; YES - add offset of 5 to shift 1-5 -> 6-10
	decf	menupos1,W					; 1-10 -> 0-4 for gases / 5-9 for diluents
	lfsr	FSR1,opt_gas_type			; load base address of gas types
	movff	PLUSW1,lo					; get gas/dil type
	tstfsz	lo							; already disabled?
	bra		do_toggle_active_disable	; NO  - disable   now
do_toggle_active_enable					; YES - re-enable now
	lfsr	FSR1,opt_gas_type_backup	; load base address of backed-up gas types
	movff	PLUSW1,lo					; get backed-up gas/dil type
	lfsr	FSR1,opt_gas_type			; load base address of gas types
	movff	lo,PLUSW1					; restore gas type
	bra		do_toggle_active_common
do_toggle_active_disable:				; disable gas / diluent
	;lfsr	FSR1,opt_gas_type			; (still set)
	clrf	PLUSW1						; set type to disabled (0=disabled, 1=first, 2=travel/normal, 3=deco/-)
do_toggle_active_common:
	movlw	.5
	btfsc	FLAG_diluent_setup			; operating on diluents?
	subwf	menupos1,F					; NO - back to 0-4 for gases 1-5
	bcf		blinking_better_gas			; clear blinking flag for gases    to avoid "leftovers"
	bcf		blinking_better_dil			; clear blinking flag for diluents to avoid "leftovers"
	call	restart_deco_engine_wo_ceiling ; invalidate deco data (but not the ceiling) and restart deco engine
	bra		do_lost_gas_common

do_dive_pO2:
	banksel	gas6_O2_ratio
	incf	gas6_O2_ratio,F				; O2++
	movf	gas6_He_ratio,W
	addwf	gas6_O2_ratio,W
	movwf	gas6_temp
	movlw	.101
	cpfslt	gas6_temp					; O2 + He < 101 ?
	decf	gas6_O2_ratio,F				; O2-- (unchanged)
	banksel	common
	bra		do_divemode_gaslist_more_common

do_dive_mO2:
	banksel	gas6_O2_ratio
	decf	gas6_O2_ratio,F				; O2--
	movlw	gaslist_min_o2
	cpfslt	gas6_O2_ratio				; O2 < minimum allowed %O2?
	bra		do_dive_mO2_done			; NO
	movlw	gaslist_min_o2				; YES - restore minimum
	movwf	gas6_O2_ratio
do_dive_mO2_done:
	banksel	common
	bra		do_divemode_gaslist_more_common

do_dive_pHe:
	banksel	gas6_O2_ratio
	incf	gas6_He_ratio,F				; He++
	movf	gas6_He_ratio,W
	addwf	gas6_O2_ratio,W
	movwf	lo
	movlw	.101
	cpfslt	lo							; O2 + He < 101 ?
	decf	gas6_He_ratio,F				; Yes, He-- (unchanged)
	banksel	common
	bra		do_divemode_gaslist_more_common

do_dive_mHe:
	banksel gas6_O2_ratio
	decf	gas6_He_ratio,F				; He--
	bnn		do_dive_mHe_done			; H2 < 0?
	clrf	gas6_He_ratio				; YES - reset to 0
do_dive_mHe_done:
	banksel	common
	bra		do_divemode_gaslist_more_common


do_divemode_splist:
	bsf		short_gas_decriptions
	movlw	.1
	movwf	menupos1					; set to first option in dive mode menu

do_divemode_splist_common:
	btfsc	analog_o2_input				; do we have an analog input (OSTC cR)?
	bra		do_divemode_splist_sensor	; YES
;	btfsc	s8_digital					; do we have a digital input?
;	bra		do_divemode_splist_sensor	; YES
	btfsc	optical_input				; do we have an optical input (OSTC 3)?
	bra		do_divemode_splist_sensor	; YES

do_divemode_splist_no_sensor:
	MENU_BEGIN	tGaslist, .5
		MENU_DYNAMIC	gaslist_strcat_setpoint,	do_switch_sp
		MENU_DYNAMIC	gaslist_strcat_setpoint,	do_switch_sp
		MENU_DYNAMIC	gaslist_strcat_setpoint,	do_switch_sp
		MENU_DYNAMIC	gaslist_strcat_setpoint,	do_switch_sp
		MENU_DYNAMIC	gaslist_strcat_setpoint,	do_switch_sp
	MENU_END

do_divemode_splist_sensor:
	MENU_BEGIN	tGaslist,	.6
		MENU_DYNAMIC	gaslist_strcat_setpoint,	do_switch_sp
		MENU_DYNAMIC	gaslist_strcat_setpoint,	do_switch_sp
		MENU_DYNAMIC	gaslist_strcat_setpoint,	do_switch_sp
		MENU_DYNAMIC	gaslist_strcat_setpoint,	do_switch_sp
		MENU_DYNAMIC	gaslist_strcat_setpoint,	do_switch_sp
		MENU_CALL		tCCRSensor,					do_divemode_sensor
	MENU_END


do_divemode_sensor:
	movlw	index_ppo2_sensors-1		; custom view number one below ppO2 sensors
	movwf	menupos3					; set custom view number
	bsf		toggle_customview			; initiate toggle to desired custom view -> ppO2 sensors
	movlw	.1
	movwf	menupos1					; set to 1st option: use sensors

do_return_divemode_sensor:
	MENU_BEGIN	tGaslist,	.6
		MENU_CALL		tDivemenu_UseSensor,	do_switch_sensor
		MENU_CALL		tBack,					do_divemode_splist
		MENU_CALL		tExit,					do_exit_divemode_menu
		MENU_CALL		tDiveHudMask1,			do_toggle_sensor
		MENU_CALL		tDiveHudMask2,			do_toggle_sensor
		MENU_CALL		tDiveHudMask3,			do_toggle_sensor
	MENU_END

do_divemode_setpoint_pscr:
	movlw	.1
	movwf	menupos1					; set to 1st option: use calculated ppO2
	MENU_BEGIN	tGaslist,	.6
		MENU_CALL		tCalculated,			do_switch_sp_calc
		MENU_CALL		tDivemenu_UseSensor,	do_switch_sensor
		MENU_CALL		tExit,					do_exit_divemode_menu
		MENU_CALL		tDiveHudMask1,			do_toggle_sensor
		MENU_CALL		tDiveHudMask2,			do_toggle_sensor
		MENU_CALL		tDiveHudMask3,			do_toggle_sensor
	MENU_END


do_toggle_sensor:
	movff	menupos1,lo					; backup position
	decf	menupos1,f					; 4, 5, 6 ->  3, 4, 5
	decf	menupos1,f					; 3, 4, 5 ->  2, 3, 4
	decf	menupos1,f					; 2, 3, 4 ->  1, 2, 3
	dcfsnz	menupos1					; 1, 2, 3 ->  0, 1, 2
	btg		use_O2_sensor1				;			  = 
	dcfsnz	menupos1					; 0, 1, 2 -> -1, 0, 1
	btg		use_O2_sensor2				;				 =
	dcfsnz	menupos1					; -1,0, 1 -> -2,-1, 0
	btg		use_O2_sensor3				;					=
	movff	lo,menupos1					; restore position
	bra		do_return_divemode_sensor

	END