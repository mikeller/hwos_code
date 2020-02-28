;=============================================================================
;
;   File divemenu_tree.asm                    combined next generation V3.08.8
;
;   OSTC dive mode menu
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all rights reserved.
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
	extern	diveloop_menu_exit


dmenu_tree	CODE

;=============================================================================
;
; Dive Mode Menu
;

do_return_main_divemenu:
	call	menu_processor_double_pop	; drop exit line and back to last line
	incf	selected_item,W				; item numbers start with 0, menu positions with 1
	movwf	menu_pos_cur				; position cursor where we came from
	bra		do_main_divemenu_common

	global	do_main_divemenu
do_main_divemenu:
	movff	active_customview,backup_customview	; back up current custom view
	call	menu_processor_reset				; restart from first icon
	movlw	.1									; set cursor to first menu item
	movwf	menu_pos_cur						; ...

do_main_divemenu_common:
 IFDEF _ccr_pscr
	btfsc	FLAG_ccr_mode
	bra		main_divemenu_loop			; goto CCR / pSCR Menu menu
	btfsc	FLAG_pscr_mode
	bra		main_divemenu_loop			; goto CCR / pSCR Menu menu
 ENDIF

main_divemenu_OC:
 IFDEF _ccr_pscr
	bcf		is_diluent_menu				; selecting OC gases ...
	bcf		is_bailout_menu				; ... not for bailout reason
 ENDIF

 IFDEF _cave_mode
	TSTOSS	opt_cave_mode				; cave mode switched on?
	bra		main_divemenu_OC_nocave		; NO  - use version without cave mode entry
	;bra	main_divemenu_OC_cave		; YES - use version with    cave mode entry

main_divemenu_OC_cave:
	MENU_BEGIN	tMainMenu,	.6
		MENU_CALL		tDivemenu_Gaslist,	do_divemode_gaslist
		MENU_CALL		tDivemenu_ResetAvg,	do_reset_average
		MENU_DYNAMIC	label_do_toggle_gf,	do_toggle_gf
		MENU_CALL		tDivemenu_Marker,	do_set_marker
		MENU_CALL		tCaveMode,			do_main_cavemenu
		MENU_CALL		tExit,				do_exit_divemode_menu
	MENU_END
 ENDIF

main_divemenu_OC_nocave:
	MENU_BEGIN	tMainMenu,	.5
		MENU_CALL		tDivemenu_Gaslist,	do_divemode_gaslist
		MENU_CALL		tDivemenu_ResetAvg,	do_reset_average
		MENU_DYNAMIC	label_do_toggle_gf,	do_toggle_gf
		MENU_CALL		tDivemenu_Marker,	do_set_marker
		MENU_CALL		tExit,				do_exit_divemode_menu
	MENU_END


;=============================================================================

 IFDEF _ccr_pscr

main_divemenu_loop:
	bsf		is_diluent_menu				; selecting diluents ...
	bcf		is_bailout_menu				; ... (definitely) not for bailout reason
	btfsc	FLAG_pscr_mode				; in pSCR mode?
	bra		main_divemenu_pscr			; YES - show pSCR menu

	MENU_BEGIN	tMainMenu,	.6
		MENU_CALL		tDiveBailout,		do_divemode_gaslist_bail
		MENU_CALL		tDivemenu_Setpoint,	do_divemode_splist
		MENU_CALL		tDivemenu_Diluent,	do_divemode_gaslist
		MENU_CALL		tDivemenu_Avg_Mkr,	do_reset_avg_set_mkr
		MENU_DYNAMIC	label_do_toggle_gf,	do_toggle_gf
		MENU_CALL		tExit,				do_exit_divemode_menu
	MENU_END


main_divemenu_pscr:
 IFDEF _external_sensor
	btfsc	analog_o2_input				; do we have an analog  input (OSTC cR)?
	bra		main_divemenu_pscr_sensors	; YES - do menu with calibration
	btfsc	optical_input				; do we have an optical input (OSTC 3)?
	bra		main_divemenu_pscr_sensors	; YES - do menu with calibration
 ENDIF

main_divemenu_pscr_no_sensors:
	MENU_BEGIN	tMainMenu,	.6
		MENU_CALL		tDiveBailout,		do_divemode_gaslist_bail
		MENU_CALL		tDivemenu_Premix,	do_divemode_gaslist
		MENU_CALL		tBackToLoop,		do_switch_sp_calc
		MENU_CALL		tDivemenu_Avg_Mkr,	do_reset_avg_set_mkr
		MENU_DYNAMIC	label_do_toggle_gf,	do_toggle_gf
		MENU_CALL		tExit,				do_exit_divemode_menu
	MENU_END

main_divemenu_pscr_sensors:
 IFDEF _external_sensor
	MENU_BEGIN	tMainMenu,	.6
		MENU_CALL		tDiveBailout,		do_divemode_gaslist_bail
		MENU_CALL		tCCRSensor,			do_divemode_setpoint_pscr
		MENU_CALL		tDivemenu_Premix,	do_divemode_gaslist
		MENU_CALL		tDivemenu_Avg_Mkr,	do_reset_avg_set_mkr
		MENU_DYNAMIC	label_do_toggle_gf,	do_toggle_gf
		MENU_CALL		tExit,				do_exit_divemode_menu
	MENU_END
 ENDIF	; _external_sensor

 ENDIF	; _ccr_pscr

;=============================================================================


do_return_toggle_gf:
	call	menu_processor_pop			; drop selection from menu stack
	bra		do_toggle_gf_1				; re-draw the custom view and enter the menu again

do_toggle_gf:
	TSTOSS	char_I_model				; toggle GF only in GF modes - in GF mode? (0 = ZH-L16, 1 = ZH-L16-GF)
	bra		do_main_divemenu_common		; NO - do nothing and return
	TSTOSS	opt_enable_aGF				; =1: aGF can be selected underwater
	bra		do_main_divemenu_common		; NO - do nothing and return
	bsf		custom_view_locked			; lock custom view
do_toggle_gf_1:
	movlw	index_gf_factors			; get  number of GF factors custom view
	movwf	active_customview			; set  custom view number
	call	dive_customview_callup		; draw custom view
	movlw	.1							; set to first option in dive mode menu
	movwf	menu_pos_cur				; ...

	MENU_BEGIN	tDivemenu_ToggleGF,	.2
		MENU_CALL		tDivemenu_ToggleGF,	do_toggle_gf_toggle
		MENU_CALL		tExit,				do_exit_divemode_menu
	MENU_END

do_toggle_gf_toggle:
	bsf		request_toggle_GF			; set request flag to have the deco engine restarted
	btg		use_aGF						; toggle normal / alternative GF factor selection
	btfsc	use_aGF						; alternative GF factors activated?
	bra		do_togglegf_agf				; YES - branch to using alternative GF
	;bra	do_togglegf_ngf				; NO  - branch to using normal      GF

do_togglegf_ngf:
	movff	opt_GF_low, char_I_GF_Low_percentage	; use normal GF factor low
	movff	opt_GF_high,char_I_GF_High_percentage	; use normal GF factor high
	bra		do_return_toggle_gf						; back to menu

do_togglegf_agf:
	movff	opt_aGF_low, char_I_GF_Low_percentage	; use alternative GF factor low
	movff	opt_aGF_high,char_I_GF_High_percentage	; use alternative GF factor high
	bra		do_return_toggle_gf						; back to menu


do_reset_avg_set_mkr:
	movlw	.1							; set to first option in dive mode menu
	movwf	menu_pos_cur				; ...

	MENU_BEGIN	tDivemenu_Avg_Mkr,	.3
		MENU_CALL		tDivemenu_ResetAvg,	do_reset_average
		MENU_CALL		tDivemenu_Marker,	do_set_marker
		MENU_CALL		tBack,				do_return_main_divemenu
	MENU_END


do_reset_average:
	bsf		request_reset_avg			; request reset of resettable average depth and dive time
 IFDEF _min_depth_option
	bsf		reset_trip_pressure			; request ISR to reset the min and max trip-wise pressures
 ENDIF
	bra		do_exit_divemode_menu		; continue exiting the menu


do_set_marker:
	bsf		request_set_marker			; set request flag
	bra		do_exit_divemode_menu		; continue exiting the menu

;=============================================================================

 IFDEF _ccr_pscr

do_switch_sp:							; entry point when coming from manual setpoint selection (CCR)
	decf	menu_pos_cur,W				; 1-5 -> 0-4
	lfsr	FSR1,opt_setpoint_cbar		; load base address
	movff	PLUSW1,char_I_const_ppO2	; set selected setpoint
 IFDEF _external_sensor
	call	transmit_setpoint			; transmit current setpoint from WREG (in cbar) to external electronics
 ENDIF
	bcf		sp_fallback					; clear fallback condition (stops fallback warning)
	clrf	WREG						; switch to fixed SP
	movff	WREG,opt_ccr_mode			; =0: Fixed SP (CCR) / calculated (pSCR), =1: Sensor, =2: Auto SP
	bra		do_switch_sp_com			; continue with common part


do_switch_sp_calc:						; entry point when coming from switch to calculated ppO2 (pSCR)
	bcf		sp_fallback					; clear fallback condition (stops fallback warning)
	clrf	WREG						; switch to fixed SP
	movff	WREG,opt_ccr_mode			; =0: Fixed SP (CCR) / calculated (pSCR), =1: Sensor, =2: Auto SP
	movff	WREG,char_I_const_ppO2		; set setpoint to 0, this forces deco engine to take the computed ppO2
	;bra	do_switch_sp_com			; continue with common part


do_switch_sp_com:						; common part
	bsf		event_occured				; set global   event byte
	bsf		event_SP_change				; set setpoint event flag

	; Clear some flags in case we were in bailout before...
	bcf		bailout_mode				; end bailout mode
	bcf		better_gas_available		; =1: a better gas is available and a gas change is advised in dive mode
	bcf		better_dil_available		; =1: a better diluent is available and a gas change is advised in dive mode
	bcf		better_gas_blinking			; clear blinking flag
	bcf		better_dil_blinking			; clear blinking flag
	call	dive_customview_callup		; redraw custom view mask to (if applicable) rewrite "ppO2(Dil)" to "ppO2" or SAC label

	bsf		request_back_to_loop		; indicate that it is a switchback from OC bailout to CCR/pSCR loop
	bsf		request_gas_change			; initiate reconfiguration to loop mode on last diluent

	bra		do_exit_divemode_menu		; continue exiting the menu


do_divemode_gaslist_bail:				; entry point from CCR/pSCR to bailout to OC gases
	bcf		is_diluent_menu				; select OC gases
	bsf		is_bailout_menu				; flag it is a bailout action
	;bra	do_divemode_gaslist

 ENDIF	; _ccr_pscr

;=============================================================================

do_divemode_gaslist:					; entry point for switching: OC -> gases, loop -> diluents
 IFDEF _ccr_pscr
	btfsc	bailout_mode				; in bailout mode?
	bcf		is_diluent_menu				; YES - for safety reasons, redirect to selecting OC (bailout) gases
 ENDIF
	bsf		short_gas_descriptions		; do not show "Gas x" etc.
	bsf		better_gas_hint				; mark the gas which is the best gas/diluent
	bsf		color_code_gases			; color-code the gases/diluents by their ppO2 and current depth
	movf	best_gas_number,W			; load number of best gas (1-5)into WREG
 IFDEF _ccr_pscr
	btfsc	is_diluent_menu				; in diluent selection?
	movf	best_dil_number,W			; YES - overwrite with best diluent (1-5)
 ENDIF
	bnz		do_divemode_gaslist_1		; best gas/dil number  =   0 (none available) ?
	movlw	.1							; YES - default to first gas/dil
	btfsc	WREG,7						; best gas/dil number >= 128 (not computed yet) ?
	movlw	.1							; YES - default to first gas/dil
do_divemode_gaslist_1:
	movwf	menu_pos_cur				; position cursor to best gas/dil (or first option if none avail)

	MENU_BEGIN	tGaslist,	.6
		MENU_DYNAMIC	gaslist_strcat_gas_cd,	do_switch_gas
		MENU_DYNAMIC	gaslist_strcat_gas_cd,	do_switch_gas
		MENU_DYNAMIC	gaslist_strcat_gas_cd,	do_switch_gas
		MENU_DYNAMIC	gaslist_strcat_gas_cd,	do_switch_gas
		MENU_DYNAMIC	gaslist_strcat_gas_cd,	do_switch_gas
		MENU_CALL		tDivemenu_LostGas,		do_lost_gas
	MENU_END


do_gas6_or_exit:
	btfsc	gas6_or_EXIT					; shall exit?
	bra		do_exit_divemode_menu			; YES - continue exiting menu
	movlw	.1								; NO  - select first item
	movwf	menu_pos_cur					;     - set cursor
	movff	char_I_O2_ratio,gas6_O2_ratio	;     - initialize gas6 with currently breathed gas - O2 ratio
 IFDEF _helium
	movff	char_I_He_ratio,gas6_He_ratio	;     - initialize gas6 with currently breathed gas - He ratio
 ENDIF

do_divemode_gaslist_more_common:
 IFDEF _helium
	MENU_BEGIN	tGaslist,	.6
		MENU_CALL		tO2Plus,				do_dive_pO2
		MENU_CALL		tO2Minus,				do_dive_mO2
		MENU_CALL		tHePlus,				do_dive_pHe
		MENU_CALL		tHeMinus,				do_dive_mHe
		MENU_DYNAMIC	gaslist_strcat_gas6,	do_switch_gas6
		MENU_CALL		tExit,					do_exit_divemode_menu
	MENU_END
 ELSE
	MENU_BEGIN	tGaslist,	.4
		MENU_CALL		tO2Plus,				do_dive_pO2
		MENU_CALL		tO2Minus,				do_dive_mO2
		MENU_DYNAMIC	gaslist_strcat_gas6,	do_switch_gas6
		MENU_CALL		tExit,					do_exit_divemode_menu
	MENU_END
 ENDIF


do_lost_gas:
	movlw	.1							; set to first option in dive mode menu
	movwf	menu_pos_cur				; ...
	bcf		gas6_or_EXIT				; default to presenting gas6 option
do_lost_gas_common:
	bsf		short_gas_descriptions		; do not show "Gas x" etc.
	bcf		better_gas_hint				; do not mark the best gas/diluent
	bcf		color_code_gases			; do not color-code the gases/diluents by their ppO2

	MENU_BEGIN	tDivemenu_LostGas, .6
		MENU_DYNAMIC	gaslist_strcat_gas_cd,	do_toggle_staged_lost
		MENU_DYNAMIC	gaslist_strcat_gas_cd,	do_toggle_staged_lost
		MENU_DYNAMIC	gaslist_strcat_gas_cd,	do_toggle_staged_lost
		MENU_DYNAMIC	gaslist_strcat_gas_cd,	do_toggle_staged_lost
		MENU_DYNAMIC	gaslist_strcat_gas_cd,	do_toggle_staged_lost
		MENU_DYNAMIC	label_do_gas6_or_exit,	do_gas6_or_exit
	MENU_END


do_switch_gas6:
	movlw	.6							; gas 6
	movwf	menu_pos_cur				; transfer register for selected gas towards gas_switched_common
	bsf		event_gas_change_gas6		; set flag for profile recording
	;bra	do_switch_gas				; continue with common gas-switched code


do_switch_gas:
	bsf		request_gas_change			; initiate gas change, will also trigger restart of deco_engine
 IFDEF _ccr_pscr
	btfss	is_bailout_menu				; doing a bailout?
	bra		do_switch_gas_1				; NO
	bsf		bailout_mode				; YES - begin bailout mode
 ENDIF
 IFDEF _cave_mode
	btfsc	cave_mode					;     - cave mode switched on?
	bsf		request_turn_turn			;       YES - request to turn the dive
 ENDIF
 IFDEF _ccr_pscr
do_switch_gas_1:
	bcf		sp_fallback					; terminate fallback mode and get rid of its warning if applicable
	call	dive_customview_callup		; redraw custom view mask to rewrite "ppO2(Dil)" to "ppO2" or SAC label if applicable
 ENDIF
	; revoke staged and lost state on the selected gas
	lfsr	FSR1,opt_gas_type			; load base address of gas types
	movff	menu_pos_cur,lo				; copy selected gas to lo
 IFDEF _ccr_pscr
	movlw	.5							; load WREG with diluent offset
	btfsc	is_diluent_menu				; operating on diluents?
	addwf	lo,F						; YES - add diluent offset to shift 1-5 -> 6-10
 ENDIF	; _ccr_pscr
	decf	lo,W						; 1-10 -> 0-4 for gases / 5-9 for diluents with result into WREG
	bcf		PLUSW1,gas_lost				; revoke lost   state
 IFDEF _cave_mode
	bcf		PLUSW1,gas_staged			; revoke staged state
 ENDIF
	;bra	do_exit_divemode_menu		; continue exiting the menu


; +++ Dive Mode and Cave Mode common exit point +++
do_exit_divemode_menu:
	call	timeout_divemode_menu2		; check for timeout and do some cleanup
	clrf	STKPTR						; reset the stack
	goto	diveloop_menu_exit			; back to the dive loop


do_toggle_staged_lost:
	movff	menu_pos_cur,lo				; copy selected gas/diluent to lo   (1-5)
	movf	active_gas,W				; copy currently used gas   to WREG (1-5)
 IFDEF _ccr_pscr
	btfsc	FLAG_oc_mode				; in OC mode?
	bra		do_toggle_staged_lost_check	; YES - can't be in diluent menu then, check selected gas against gas in use
	btfsc	bailout_mode				; NO  - in bailout?
	bra		do_toggle_staged_lost_check	;       YES - can't be in diluent menu then, check selected gas against bailout gas in use
	btfss	is_diluent_menu				;       NO  - breathing a diluent then, in diluent menu?
	bra		do_toggle_staged_lost_exec	;             NO  - can modify any gas, no need for a check
	movf	active_dil,W				;             YES - check selected diluent against diluent in use
 ENDIF
do_toggle_staged_lost_check:
	cpfseq	lo							; selected gas/dil = currently used gas/dil?
	bra		do_toggle_staged_lost_exec	; NO  - can set selected gas/dil to lost or staged
	bra		do_lost_gas_common			; YES - gas/dil in use, can not set to lost or staged, back to menu
do_toggle_staged_lost_exec:
	lfsr	FSR1,opt_gas_type			; load base address of gas types
	bcf		better_gas_blinking			; clear blinking flag for gases    to avoid "leftovers"
 IFDEF _ccr_pscr
	bcf		better_dil_blinking			; clear blinking flag for diluents to avoid "leftovers"
	movlw	.5							; load WREG with diluent offset
	btfsc	is_diluent_menu				; operating on diluents?
	addwf	lo,F						; YES - add diluent offset to shift 1-5 -> 6-10
 ENDIF	; _ccr_pscr
 IFDEF _cave_mode
	TSTOSS	opt_cave_mode				; cave mode switched on?
	bra		do_toggle_staged_lost_3		; NO  - just toggle lost state
	decf	lo,W						; YES - 1-10 -> 0-4 for gases / 5-9 for diluents with result into WREG
	btfsc	PLUSW1,gas_staged			;     - gas currently set as staged?
	bra		do_toggle_staged_lost_1		;       YES - set as lost now
	btfsc	PLUSW1,gas_lost				;       NO  - gas currently set as lost?
	bra		do_toggle_staged_lost_2		;             YES - set as available now
	;bra	do_toggle_staged_lost_0		;             NO  - set as staged    now
do_toggle_staged_lost_0:
	bsf		PLUSW1,gas_staged			; set    staged state
	bra		do_toggle_staged_lost_4		; continue with restarting deco engine
do_toggle_staged_lost_1:
	bcf		PLUSW1,gas_staged			; revoke staged state
	bsf		PLUSW1,gas_lost				; set    lost   state
	bra		do_toggle_staged_lost_4		; continue with restarting deco engine
do_toggle_staged_lost_2:
	bcf		PLUSW1,gas_lost				; revoke lost   state
	bra		do_toggle_staged_lost_4		; continue with restarting deco engine
 ENDIF	; _cave_mode
do_toggle_staged_lost_3:
	decf	lo,W						; 1-10 -> 0-4 for gases / 5-9 for diluents with result into WREG
	btg		PLUSW1,gas_lost				; toggle lost state
do_toggle_staged_lost_4:
	bsf		request_gas_update			; request to update the gases
	bsf		gas6_or_EXIT				; switch 6th menu item from gas6 to exit
	bra		do_lost_gas_common			; back to the menu


do_dive_pO2:
	incf	gas6_O2_ratio,F				; increment O2 %
 IFDEF _helium
	movf	gas6_He_ratio,W				; get He %
	addwf	gas6_O2_ratio,W				; add O2 %
 ELSE
	movf	gas6_O2_ratio,W				; get O2 %
 ENDIF
	movwf	lo							; copy to lo
	movlw	.101						; O2 + He < 101 
	cpfslt	lo							; ... ?
	decf	gas6_O2_ratio,F				; NO  - decrement O2 again
	bra		do_divemode_gaslist_more_common


do_dive_mO2:
	decf	gas6_O2_ratio,F				; decrement O2 %
	movlw	gaslist_min_o2				; get minimum value
	cpfslt	gas6_O2_ratio				; O2 < minimum allowed %O2 ?
	bra		do_dive_mO2_done			; NO  - value is valid
	movwf	gas6_O2_ratio				; YES - set O2 % to minimum
do_dive_mO2_done:
	bra		do_divemode_gaslist_more_common

;=============================================================================

 IFDEF _helium

do_dive_pHe:
	incf	gas6_He_ratio,F				; increment He %
	movf	gas6_He_ratio,W				; get He %
	addwf	gas6_O2_ratio,W				; add O2 %
	movwf	lo							; copy to lo
	movlw	.101						; O2 + He < 101
	cpfslt	lo							; ... ?
	decf	gas6_He_ratio,F				; YES - decrement He again
	bra		do_divemode_gaslist_more_common

do_dive_mHe:
	decf	gas6_He_ratio,F				; decrement He %
	bnn		do_dive_mHe_done			; H2 < 0 ?
	clrf	gas6_He_ratio				; YES - reset to 0
do_dive_mHe_done:
	bra		do_divemode_gaslist_more_common

 ENDIF

;=============================================================================

 IFDEF _ccr_pscr

do_divemode_splist:
	bsf		short_gas_descriptions		; do not show "SP" etc.
	movlw	.1							; default to first menu item
	movff	opt_ccr_mode,lo				; get CCR mode (0: Fixed SP, 1: Sensor, 2: Auto SP)
	dcfsnz	lo,F						; mode = sensor ?
	movlw	.6							; YES - load menu item number for 'sensor'
	btfsc	sp_fallback					; in fallback condition?
	movlw	.1							; YES - revert to first menu item
	movwf	menu_pos_cur				; set cursor position

do_divemode_splist_common:

 IFDEF _external_sensor
	btfsc	analog_o2_input				; do we have an analog or S8 digital input (OSTC cR)?
	bra		do_divemode_splist_sensor	; YES
	btfsc	optical_input				; do we have an optical input (OSTC 3)?
	bra		do_divemode_splist_sensor	; YES
 ENDIF

do_divemode_splist_no_sensor:
	MENU_BEGIN	tGaslist, .5
		MENU_DYNAMIC	gaslist_strcat_setpoint,	do_switch_sp
		MENU_DYNAMIC	gaslist_strcat_setpoint,	do_switch_sp
		MENU_DYNAMIC	gaslist_strcat_setpoint,	do_switch_sp
		MENU_DYNAMIC	gaslist_strcat_setpoint,	do_switch_sp
		MENU_DYNAMIC	gaslist_strcat_setpoint,	do_switch_sp
	MENU_END


 IFDEF _external_sensor

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
	movlw	index_ppo2_sensors			; number of ppO2 sensors custom view
	movwf	active_customview			; set     the custom view number
	call	dive_customview_callup		; call-up the custom view
	movlw	.1							; set to 1st option: use sensors
	movwf	menu_pos_cur				; ...

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
	movwf	menu_pos_cur				; set to 1st option: use calculated ppO2

	MENU_BEGIN	tGaslist,	.6
		MENU_CALL		tCalculated,			do_switch_sp_calc
		MENU_CALL		tDivemenu_UseSensor,	do_switch_sensor
		MENU_CALL		tExit,					do_exit_divemode_menu
		MENU_CALL		tDiveHudMask1,			do_toggle_sensor
		MENU_CALL		tDiveHudMask2,			do_toggle_sensor
		MENU_CALL		tDiveHudMask3,			do_toggle_sensor
	MENU_END

do_switch_sensor:						; entry point when coming from switch to sensor
	movlw	.1							; switch to sensor
	movff	WREG,opt_ccr_mode			; =0: fixed SP (CCR) / calculated (pSCR), =1: Sensor, =2: Auto SP
	bra		do_switch_sp_com			; continue with common part

do_toggle_sensor:
	movff	menu_pos_cur,lo				; backup position
	decf	menu_pos_cur,f				; 4, 5, 6 ->  3, 4, 5
	decf	menu_pos_cur,f				; 3, 4, 5 ->  2, 3, 4
	decf	menu_pos_cur,f				; 2, 3, 4 ->  1, 2, 3
	dcfsnz	menu_pos_cur				; 1, 2, 3 ->  0, 1, 2
	btg		use_O2_sensor1				;             = 
	dcfsnz	menu_pos_cur				; 0, 1, 2 -> -1, 0, 1
	btg		use_O2_sensor2				;                =
	dcfsnz	menu_pos_cur				; -1,0, 1 -> -2,-1, 0
	btg		use_O2_sensor3				;                   =
	movff	lo,menu_pos_cur				; restore position
	bra		do_return_divemode_sensor

 ENDIF	; _external_sensor
 ENDIF	; _ccr_pscr

;=============================================================================
;
; Cave Mode Menu
;

 IFDEF _cave_mode

do_return_main_cavemenu:
	call	menu_processor_pop					; drop selection from menu stack
	incf	selected_item,W						; item numbers start with 0, menu positions with 1
	movwf	menu_pos_cur						; position cursor where we came from
	bra		do_main_cavemenu_common				; continue with common part

	global	do_main_cavemenu
do_main_cavemenu:
	bsf		custom_view_locked					; lock custom view
	movff	active_customview,backup_customview	; back up current custom view
	call	menu_processor_reset				; restart from first icon
	movlw	.1									; set cursor to first menu item by default
	btfsc	dive_turned							; dive turned ?
	movlw	.4									; YES - set cursor on waypoint out item
	btfss	cave_mode							; cave mode switched off ?
	movlw	.3									; YES - set cursor on cave mode off/on menu item
	movwf	menu_pos_cur						; actually set cursor position

	; The helper functions for MENU_DYNAMIC can be found in
	; gaslist.asm as it does not work to include them here.

do_main_cavemenu_common:
	movlw	index_cave_waypoints				; get  number of cave waypoints custom view
	movwf	active_customview					; set  custom view number
	call	dive_customview_callup				; draw custom view

	MENU_BEGIN	tMainMenu,	.6
		MENU_DYNAMIC	label_do_wp_set,		do_waypoint_set			; 1
		MENU_DYNAMIC	label_do_turn_dive,		do_turndive_toggle		; 2
		MENU_CALL		tDivemenu_off_on,		do_cavemode_toggle		; 3
		MENU_DYNAMIC	label_do_wp_out,		do_waypoint_out			; 4
		MENU_DYNAMIC	label_do_wp_in,			do_waypoint_in			; 5
		MENU_CALL		tExit,					do_exit_divemode_menu	; 6
	MENU_END


do_waypoint_set:
	bsf		request_waypoint_set		; set request flag
	bra		do_return_main_cavemenu		; back to menu

do_turndive_toggle:
	bsf		request_turn_toggle			; set request flag
	bra		do_return_main_cavemenu		; back to menu

do_cavemode_toggle:
	bsf		request_cave_toggle			; set request flag
	bra		do_return_main_cavemenu		; back to menu

do_waypoint_out:
	bsf		request_waypoint_out		; set request flag
	bra		do_return_main_cavemenu		; back to menu

do_waypoint_in:
	bsf		request_waypoint_in			; set request flag
	bra		do_return_main_cavemenu		; back to menu

 ENDIF	; _cave_mode

;=============================================================================

	END
