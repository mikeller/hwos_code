;=============================================================================
;
;   File divemenu_tree.asm                  * combined next generation V3.12.3
;
;   OSTC dive mode menu
;
;   Copyright (c) 2011, JD Gascuel, heinrichs weikamp gmbh, all rights reserved.
;=============================================================================
; HISTORY
;   2013-02-02 : [mH] Made out of menu_tree.asm


;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;
;                                  ATTENTION
;
; All Calls made via the Menu Macros need to go to Addresses within 0x0xxxx !
;
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


#include "hwos.inc"
#include "shared_definitions.h"
#include "menu_processor.inc"
#include "tft_outputs.inc"
#include "customview.inc"
#include "strings.inc"
#include "calibrate.inc"
#include "gaslist.inc"
#include "colorschemes.inc"


	extern	diveloop_menu_exit

 IFDEF _cave_mode
	extern	cavemode_turndive_check
	extern	cavemode_waypoint_set_check
	extern	cavemode_waypoint_out_check
	extern	cavemode_waypoint_in_check
 ENDIF


;=============================================================================
dive_menu	CODE	0x02000				; needs to be at 0x0xxxx
;=============================================================================


;-----------------------------------------------------------------------------
; Return to Main Dive Mode Menu
;
do_return_main_divemenu:
	call	menu_processor_double_pop	; drop exit line and back to last line
	incf	selected_item,W				; item numbers start with 0, menu positions with 1
	movwf	menu_pos_cur				; position cursor where we came from
	bra		do_main_divemenu_common		; continue with common part


;-----------------------------------------------------------------------------
; Entry Point for Main Dive Mode Menu
;
	global	do_main_divemenu
do_main_divemenu:
	movff	active_customview,backup_customview	; back up current custom view
	call	menu_processor_reset				; restart from first icon
	movlw	.1									; set cursor to first menu item
	movwf	menu_pos_cur						; ...
	;bra	do_main_divemenu_common				; continue with common part


;-----------------------------------------------------------------------------
; Common Part for Main Dive Mode Menu, 1st Layer
;
do_main_divemenu_common:
 IFDEF _ccr_pscr
	btfsc	FLAG_ccr_mode				; in CCR mode?
	bra		main_divemenu_loop			; YES - goto CCR / pSCR Menu menu
	btfsc	FLAG_pscr_mode				; in pSCR mode?
	bra		main_divemenu_loop			; YES - goto CCR / pSCR Menu menu
 ENDIF	; _ccr_pscr

main_divemenu_OC:
 IFDEF _ccr_pscr
	bcf		is_diluent_menu				; selecting OC gases ...
	bcf		is_bailout_menu				; ... not for bailout reason
 ENDIF	; _ccr_pscr

 IFDEF _cave_mode
	TSTOSS	opt_cave_mode				; cave mode switched on?
	bra		main_divemenu_OC_nocave		; NO  - use version without cave mode entry
	;bra	main_divemenu_OC_cave		; YES - use version with    cave mode entry

main_divemenu_OC_cave:
	MENU_BEGIN_DIVE	tMainMenu,  .6
		MENU_CALL		tDivemenu_Gaslist,	do_divemode_gaslist
		MENU_CALL		tDivemenu_ResetAvg,	do_reset_average
		MENU_DYNAMIC	dyn_toggle_gf,		do_toggle_gf
		MENU_CALL		tDivemenu_Marker,	do_set_marker
		MENU_CALL		tCaveMode,			do_main_cavemenu
		MENU_CALL		tExit,				do_exit_divemode_menu
	MENU_END
 ENDIF	; _cave_mode

main_divemenu_OC_nocave:
	MENU_BEGIN_DIVE	tMainMenu,  .5
		MENU_CALL		tDivemenu_Gaslist,	do_divemode_gaslist
		MENU_CALL		tDivemenu_ResetAvg,	do_reset_average
		MENU_DYNAMIC	dyn_toggle_gf,		do_toggle_gf
		MENU_CALL		tDivemenu_Marker,	do_set_marker
		MENU_CALL		tExit,				do_exit_divemode_menu
	MENU_END

 IFDEF _ccr_pscr

main_divemenu_loop:
	bsf		is_diluent_menu				; selecting diluents ...
	bcf		is_bailout_menu				; ... (definitely) not for bailout reason
	btfsc	FLAG_pscr_mode				; in pSCR mode?
	bra		main_divemenu_pscr			; YES - show pSCR menu

	MENU_BEGIN_DIVE	tMainMenu,  .6
		MENU_CALL		tDiveBailout,		do_divemode_gaslist_bail
		MENU_CALL		tDivemenu_Setpoint,	do_divemode_splist
		MENU_CALL		tDivemenu_Diluent,	do_divemode_gaslist
		MENU_CALL		tDivemenu_Avg_Mkr,	do_reset_avg_set_mkr
		MENU_DYNAMIC	dyn_toggle_gf,		do_toggle_gf
		MENU_CALL		tExit,				do_exit_divemode_menu
	MENU_END


main_divemenu_pscr:
 IFDEF _external_sensor_eccr
	btfsc	ext_input_s8_ana			; do we have an S8/analog input (OSTC cR)?
	bra		main_divemenu_pscr_sensors	; YES - do menu with calibration
	btfsc	ext_input_optical			; do we have an optical input (OSTC 3)?
	bra		main_divemenu_pscr_sensors	; YES - do menu with calibration
	btfsc	ext_s8_full_digital			; NO - are we in external S8 full digital mode? 
	bra		main_divemenu_pscr_sensors	; YES - do menu with calibration
 ENDIF	; _external_sensor_eccr

main_divemenu_pscr_no_sensors:
	MENU_BEGIN_DIVE	tMainMenu,  .6
		MENU_CALL		tDiveBailout,		do_divemode_gaslist_bail
		MENU_CALL		tDivemenu_Premix,	do_divemode_gaslist
		MENU_CALL		tBackToLoop,		do_switch_sp_calc
		MENU_CALL		tDivemenu_Avg_Mkr,	do_reset_avg_set_mkr
		MENU_DYNAMIC	dyn_toggle_gf,		do_toggle_gf
		MENU_CALL		tExit,				do_exit_divemode_menu
	MENU_END

 IFDEF _external_sensor_eccr
main_divemenu_pscr_sensors:
	MENU_BEGIN_DIVE	tMainMenu,  .6
		MENU_CALL		tDiveBailout,		do_divemode_gaslist_bail
		MENU_CALL		tCCRModeSensor,		do_divemode_setpoint_pscr
		MENU_CALL		tDivemenu_Premix,	do_divemode_gaslist
		MENU_CALL		tDivemenu_Avg_Mkr,	do_reset_avg_set_mkr
		MENU_DYNAMIC	dyn_toggle_gf,		do_toggle_gf
		MENU_CALL		tExit,				do_exit_divemode_menu
	MENU_END
 ENDIF	; _external_sensor_eccr


;-----------------------------------------------------------------------------
; Call Function - start Bailout Condition
;
do_divemode_gaslist_bail:
	bcf		is_diluent_menu				; select OC gases
	bsf		is_bailout_menu				; flag it is a bailout action
	bra		do_divemode_gaslist			; continue with the gas menu for B/O gas selection


;-----------------------------------------------------------------------------
; Call Function - switch to calculated Setpoint (pSCR)
;
do_switch_sp_calc:
	bcf		warn_det_sensors_lost		; clear fallback condition (revoke all sensors lost warning)
	clrf	dive_ccr_mode				; switch to fixed SP
	clrf	WREG						; set setpoint to 0, this forces deco engine to take the computed ppO2
	movff	WREG,char_I_const_ppO2		; ...
	bra		do_switch_sp_com			; continue with common part

 ENDIF	; _ccr_pscr


;-----------------------------------------------------------------------------
; dynamic Title - toggle GF
;
dyn_toggle_gf:
	movff	char_I_model,WREG			; 0 = ZH-L16, 1 = ZH-L16-GF
	decfsz	WREG,W						; toggle GF only in GF modes - in GF mode?
	bra		dyn_toggle_gf_1				; NO  - print in disabled color
	TSTOSS	opt_enable_aGF				; YES - aGF enabled?
dyn_toggle_gf_1:
	FONT_COLOR_DISABLED					;       NO  - print in disabled color
	STRCAT_TEXT tDivemenu_ToggleGF		; output label
	return								; done


;-----------------------------------------------------------------------------
; Sub-Menu: Toggle GFs
;
do_return_toggle_gf:
	call	menu_processor_pop			; drop selection from menu stack
	bra		do_toggle_gf_1				; re-draw the custom view and enter the menu again

do_toggle_gf:
	TSTOSS	char_I_model				; toggle GF only in GF modes - in GF mode? (0 = ZH-L16, 1 = ZH-L16-GF)
	bra		do_abort_toggle_gf			; NO - do nothing and return
	TSTOSS	opt_enable_aGF				; aGF enabled?
	bra		do_abort_toggle_gf			; NO - do nothing and return
	bsf		custom_view_locked			; lock custom view
do_toggle_gf_1:
	movlw	index_gf_factors			; get  number of GF factors custom view
	movwf	active_customview			; set  custom view number
	call	dive_customview_callup		; draw custom view
	movlw	.1							; set to first option in dive mode menu
	movwf	menu_pos_cur				; ...

	MENU_BEGIN_DIVE	tDivemenu_ToggleGF,  .2
		MENU_CALL		tDivemenu_ToggleGF,	do_toggle_gf_toggle
		MENU_CALL		tExit,				do_exit_divemode_menu
	MENU_END


;-----------------------------------------------------------------------------
; Helper Function - abort toggle GF Sub-Menu
;
do_abort_toggle_gf:
	call	menu_processor_pop			; drop selection from menu stack
	bra		do_main_divemenu_common		; back to main menu


;-----------------------------------------------------------------------------
; Call Function - toggle GF <-> aGF
;
do_toggle_gf_toggle:
	bsf		request_toggle_GF			; request restart of the deco engine
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


;-----------------------------------------------------------------------------
; Sub-Menu: Reset average Depth & set Marker
;
do_reset_avg_set_mkr:
	movlw	.1							; set to first option in dive mode menu
	movwf	menu_pos_cur				; ...

	MENU_BEGIN_DIVE	tDivemenu_Marker,   .3
		MENU_CALL		tDivemenu_ResetAvg,	do_reset_average
		MENU_CALL		tDivemenu_Marker,	do_set_marker
		MENU_CALL		tBack,				do_return_main_divemenu		; return to main menu
	MENU_END


;-----------------------------------------------------------------------------
; Call Function - reset average Depth
;
do_reset_average:
	bsf		request_reset_avg			; request reset of resettable average depth and dive time
 IFDEF _min_depth_option
	bsf		reset_trip_pressure			; request ISR to reset the min and max trip-wise pressures
 ENDIF
	bra		do_exit_divemode_menu		; continue exiting the menu


;-----------------------------------------------------------------------------
; Call Function - set a Marker in the Dive Profile Recording
;
do_set_marker:
	bsf		request_set_marker			; set request flag
	bra		do_exit_divemode_menu		; continue exiting the menu


;-----------------------------------------------------------------------------
; Sub-Menu: Switch OC / Diluent Selection
;
do_divemode_gaslist:
 IFDEF _ccr_pscr
	btfsc	bailout_mode				; in bailout mode?
	bcf		is_diluent_menu				; YES - for safety reasons, redirect to selecting OC (bailout) gases
 ENDIF	; _ccr_pscr
	bsf		short_gas_descriptions		; do not show "Gas x" etc.
	bsf		better_gas_hint				; mark the gas which is the best gas/diluent
	bsf		color_code_gases			; color-code the gases/diluents by their ppO2 and current depth
	movf	best_gas_number,W			; load number of best gas (1-5)into WREG
 IFDEF _ccr_pscr
	btfsc	is_diluent_menu				; in diluent selection?
	movf	best_dil_number,W			; YES - overwrite with best diluent (1-5)
 ENDIF; _ccr_pscr
	bnz		do_divemode_gaslist_1		; best gas/dil number  =   0 (none available) ?
	movlw	.1							; YES - default to first gas/dil
	btfsc	WREG,7						; best gas/dil number >= 128 (not computed yet) ?
	movlw	.1							; YES - default to first gas/dil
do_divemode_gaslist_1:
	movwf	menu_pos_cur				; position cursor to best gas/dil (or first option if none avail)

	MENU_BEGIN_DIVE	tDivemenu_Gaslist,  .6
		MENU_DYNAMIC	dyn_strcat_gas_prodl,	do_switch_gas
		MENU_DYNAMIC	dyn_strcat_gas_prodl,	do_switch_gas
		MENU_DYNAMIC	dyn_strcat_gas_prodl,	do_switch_gas
		MENU_DYNAMIC	dyn_strcat_gas_prodl,	do_switch_gas
		MENU_DYNAMIC	dyn_strcat_gas_prodl,	do_switch_gas
		MENU_CALL		tDivemenu_LostGas,		do_lost_gas
	MENU_END


;-----------------------------------------------------------------------------
; dynamic Title - print full Gas Description
;
dyn_strcat_gas_prodl:
	goto	gaslist_strcat_gas_PRODL	; code is hosted in gaslist.asm


;-----------------------------------------------------------------------------
; Call Function - initiate Gas Change (will also trigger restart of deco_engine)
;
do_switch_gas:
	bsf		request_gas_change			; request dive mode to do a gas change
 IFDEF _ccr_pscr
	btfss	is_bailout_menu				; doing a bailout?
	bra		do_switch_gas_1				; NO
	bsf		bailout_mode				; YES - begin bailout mode
 ENDIF	; _ccr_pscr
 IFDEF _cave_mode
	btfsc	cave_mode					;     - cave mode switched on?
	bsf		request_turn_turn			;       YES - request to turn the dive
 ENDIF	; _cave_mode
 IFDEF _ccr_pscr
do_switch_gas_1:
	bcf		warn_det_sensors_lost		; terminate fallback mode and get rid of its warning if applicable
	call	dive_customview_callup		; redraw custom view mask to rewrite "ppO2(Dil)" to "ppO2" or SAC label if applicable
 ENDIF	; _ccr_pscr
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
 ENDIF	; _cave_mode
	bra		do_exit_divemode_menu		; continue exiting the menu


;-----------------------------------------------------------------------------
; Sub-Menu: lost / staged Gas
;
do_lost_gas:
	movlw	.1							; set to first option in dive mode menu
	movwf	menu_pos_cur				; ...
	bcf		gas6_or_EXIT				; default to presenting gas6 option
        btfsc    alt_layout_active           ; alternative layout (big font) active?
	bsf      gas6_or_EXIT                ; YES - do not present gas6 option
do_lost_gas_common:
	bsf		short_gas_descriptions		; do not show "Gas x" etc.
	bcf		better_gas_hint				; do not mark the best gas/diluent
	bcf		color_code_gases			; do not color-code the gases/diluents by their ppO2

	MENU_BEGIN_DIVE	tDivemenu_LostGas,  .6
		MENU_DYNAMIC	dyn_strcat_gas_prodl,	do_toggle_staged_lost
		MENU_DYNAMIC	dyn_strcat_gas_prodl,	do_toggle_staged_lost
		MENU_DYNAMIC	dyn_strcat_gas_prodl,	do_toggle_staged_lost
		MENU_DYNAMIC	dyn_strcat_gas_prodl,	do_toggle_staged_lost
		MENU_DYNAMIC	dyn_strcat_gas_prodl,	do_toggle_staged_lost
		MENU_DYNAMIC	dyn_gas6_or_exit,		do_gas6_or_exit
	MENU_END


;-----------------------------------------------------------------------------
; dynamic Title - print full Gas Description
;
;dyn_strcat_gas_prodl:
;	goto	gaslist_strcat_gas_PRODL	; code is hosted in gaslist.asm


;-----------------------------------------------------------------------------
; Call Function - toggle a Gas between available, lost and staged
;
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
 ENDIF	; _ccr_pscr
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


;-----------------------------------------------------------------------------
; dynamic Title - print Gas 6 Item or Exit Item
;
dyn_gas6_or_exit:
	btfsc	gas6_or_EXIT				; shall print exit?
	bra		dyn_gas6_or_exit_1			; YES - print exit  label
	STRCAT_TEXT tGas6					; NO  - print gas 6 label
	return								;     - done
dyn_gas6_or_exit_1:
	STRCAT_TEXT tExit					; print exit label
	return								; done


;-----------------------------------------------------------------------------
; Sub-Menu: Gas 6 / Menu-Exit
;
do_gas6_or_exit:
	btfsc	gas6_or_EXIT						; shall exit?
	bra		do_exit_divemode_menu				; YES - exit the menu
	movlw	.1									; NO  - select first item
	movwf	menu_pos_cur						;     - set cursor
	movff	char_I_O2_ratio,opt_gas6_O2_ratio	;     - initialize gas6 with currently breathed gas - O2 ratio
 IFDEF _helium
	movff	char_I_He_ratio,opt_gas6_He_ratio	;     - initialize gas6 with currently breathed gas - He ratio
 ELSE
	clrf	WREG								;     - set gas6 helium to zero
	movff	WREG,opt_gas6_He_ratio				;     - ...
 ENDIF	; _helium
	bsf		block_option_value					; suspend displaying of option values


 IFDEF _helium
	MENU_BEGIN_DIVE tGas6,	.6
		MENU_OPT_INCS	tO2Plus,				oGas6O2
		MENU_OPT_DECS	tO2Minus,				oGas6O2
		MENU_OPT_INCS	tHePlus,				oGas6He
		MENU_OPT_DECS	tHeMinus,				oGas6He
		MENU_DYNAMIC	dyn_show_gas6,			do_gas6_switch
		MENU_CALL		tExit,					do_exit_divemode_menu
	MENU_END
 ELSE
	MENU_BEGIN_DIVE tGas6,	.4
		MENU_OPT_INCS	tO2Plus,				oGas6O2
		MENU_OPT_DECS	tO2Minus,				oGas6O2
		MENU_DYNAMIC	dyn_show_gas6,			do_gas6_switch
		MENU_CALL		tExit,					do_exit_divemode_menu
	MENU_END
 ENDIF; _helium


;-----------------------------------------------------------------------------
; dynamic Title: show Gas 6 Mix
;
dyn_show_gas6:
	STRCAT_TEXT tTakeGas				; print "take"
	PUTC	" "							; print one space
	movff	opt_gas6_O2_ratio,hi		; TFT_color_code_gaslist needs O2 ratio in hi
	call	TFT_color_code_gaslist		; color-code according to O2 ratio and depth
	movff	opt_gas6_O2_ratio,lo		; gaslist_strcat_mix needs O2 ratio in lo
 IFDEF _helium
	movff	opt_gas6_He_ratio,hi		;                ... and He ratio in hi
 ELSE
	clrf	hi							;                ... and He ration will be zero
 ENDIF	; _helium
	goto	gaslist_strcat_mix			; print "Nxlo", "Txlo/hi", "Air" or "O2" and return


;-----------------------------------------------------------------------------
; Call Function - switch to Gas 6
;
do_gas6_switch:
	movlw	.6							; gas 6
	movwf	menu_pos_cur				; transfer register for selected gas towards gas_switched_common
	bsf		event_gas_change_gas6		; set flag for profile recording
	bra		do_switch_gas				; continue with common gas-switched code


 IFDEF _ccr_pscr

;-----------------------------------------------------------------------------
; Sub Menu - select Setpoint
;
do_divemode_splist:
	bsf		short_gas_descriptions		; do not show "SP" etc.
	movlw	.1							; default to first menu item
	movff	dive_ccr_mode,lo			; get CCR mode (0: Fixed SP, 1: Sensor, 2: Auto SP)
	dcfsnz	lo,F						; mode = sensor ?
	movlw	.6							; YES - load menu item number for 'sensor'
	btfsc	warn_det_sensors_lost		; all sensors lost?
	movlw	.1							; YES - revert to first menu item
	movwf	menu_pos_cur				; set cursor position

 IFDEF _external_sensor_eccr
	btfsc	ext_input_s8_ana			; do we have an S8/analog input (OSTC cR)?
	bra		do_divemode_splist_sensor	; YES
	btfsc	ext_input_optical			; do we have an optical input (OSTC 3)?
	bra		do_divemode_splist_sensor	; YES
	btfsc	ext_s8_full_digital			; NO - are we in external S8 full digital mode? 
	bra		main_divemenu_pscr_sensors	; YES - do menu with calibration
 ENDIF	; _external_sensor_eccr

do_divemode_splist_no_sensor:
	MENU_BEGIN_DIVE	tFixedSetpoints,    .6
		MENU_DYNAMIC	dyn_strcat_setpoint_prodl,	do_switch_sp
		MENU_DYNAMIC	dyn_strcat_setpoint_prodl,	do_switch_sp
		MENU_DYNAMIC	dyn_strcat_setpoint_prodl,	do_switch_sp
		MENU_DYNAMIC	dyn_strcat_setpoint_prodl,	do_switch_sp
		MENU_DYNAMIC	dyn_strcat_setpoint_prodl,	do_switch_sp
		MENU_CALL		tCCRModeAutoSP,				do_switch_auto
	MENU_END


 IFDEF _external_sensor_eccr

do_divemode_splist_sensor:
	MENU_BEGIN_DIVE	tFixedSetpoints,    .6
		MENU_DYNAMIC	dyn_strcat_setpoint_prodl,	do_switch_sp
		MENU_DYNAMIC	dyn_strcat_setpoint_prodl,	do_switch_sp
		MENU_DYNAMIC	dyn_strcat_setpoint_prodl,	do_switch_sp
		MENU_DYNAMIC	dyn_strcat_setpoint_prodl,	do_switch_sp
		MENU_DYNAMIC	dyn_strcat_setpoint_prodl,	do_switch_sp
		MENU_CALL		tCCRModeSensor,				do_divemode_sensor
	MENU_END

 ENDIF	; _external_sensor_eccr


;-----------------------------------------------------------------------------
; dynamic Title - print Setpoint
;
dyn_strcat_setpoint_prodl:
	goto	gaslist_strcat_setpoint_PRODL	; function is hosted in gaslist.asm


;-----------------------------------------------------------------------------
; Call Function - switch to manually selected Setpoint (CCR)
;
do_switch_sp:
	decf	menu_pos_cur,W				; 1-5 -> 0-4
	lfsr	FSR1,opt_setpoint_cbar		; load base address
	movff	PLUSW1,char_I_const_ppO2	; set selected setpoint
 IFDEF _external_sensor_eccr
	call	transmit_setpoint			; transmit current setpoint from WREG (in cbar) to external electronics
 ENDIF
	bcf		warn_det_sensors_lost		; clear fallback condition (revoke all sensors lost warning)
	clrf	dive_ccr_mode				; switch to fixed SP
	bra		do_switch_sp_com			; continue with common part


;-----------------------------------------------------------------------------
; Call Function - switch to Auto-SP (CCR)
;
do_switch_auto:
	movff	opt_setpoint_cbar+0,char_I_const_ppO2	; selected 1st setpoint
	bcf		warn_det_sensors_lost		; clear fallback condition
	movlw	.2							; switch to auto SP
	movwf	dive_ccr_mode				; =0: fixed SP (CCR) / calculated (pSCR), =1: Sensor, =2: auto SP
	bsf		restart_auto_sp				; restart auto SP selection
	;bra	do_switch_sp_com			; continue with common part


;-----------------------------------------------------------------------------
; Helper Function - common Part of Setpoint Switching
;
do_switch_sp_com:						; common part
	bsf		event_occured				; set global   event byte
	bsf		event_SP_change				; set setpoint event flag

	; clear some flags in case we were in bailout before...
	bcf		bailout_mode				; end bailout mode
	bcf		better_gas_available		; =1: a better gas is available and a gas change is advised in dive mode
	bcf		better_dil_available		; =1: a better diluent is available and a gas change is advised in dive mode
	bcf		better_gas_blinking			; clear blinking flag
	bcf		better_dil_blinking			; clear blinking flag
	call	dive_customview_callup		; redraw custom view mask to (if applicable) rewrite "ppO2(Dil)" to "ppO2" or SAC label

	bsf		request_back_to_loop		; indicate that it is a switchback from OC bailout to CCR/pSCR loop
	bsf		request_gas_change			; initiate reconfiguration to loop mode on last diluent

	bra		do_exit_divemode_menu		; continue exiting the menu


 IFDEF _external_sensor_eccr


;-----------------------------------------------------------------------------
; Return to Sub Menu toggle Sensor Usage / select Sensors from Menu Action
;
do_return_divemode_sensor:
	call	menu_processor_pop			; drop selection from menu stack
	bra		do_return_divemode_common	; back to menu

;-----------------------------------------------------------------------------
; Sub Menu - toggle Sensor Usage / select Sensors
;
do_divemode_sensor:
	movlw	index_ppo2_sensors			; number of ppO2 sensors custom view
	movwf	active_customview			; set     the custom view number
	call	dive_customview_callup		; call-up the custom view
	movlw	.1							; set to 1st option: use sensors
	movwf	menu_pos_cur				; ...

do_return_divemode_common:
	MENU_BEGIN_DIVE	tDivemenu_UseSensor,.6
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

	MENU_BEGIN_DIVE	tDivemenu_UseSensor,.6
		MENU_CALL		tCalculated,			do_switch_sp_calc
		MENU_CALL		tDivemenu_UseSensor,	do_switch_sensor
		MENU_CALL		tExit,					do_exit_divemode_menu
		MENU_CALL		tDiveHudMask1,			do_toggle_sensor
		MENU_CALL		tDiveHudMask2,			do_toggle_sensor
		MENU_CALL		tDiveHudMask3,			do_toggle_sensor
	MENU_END


;-----------------------------------------------------------------------------
; Call Function - switch to using Sensors
;
do_switch_sensor:
	movlw	.1							; switch to sensor (0: fixed/ calculated SP, 1: Sensor, 2: AutoSP)
	movwf	dive_ccr_mode				; ...

	; check for external HUD/ppO2 Monitor
	btfss	ext_input_optical			; do we have an optical input?
	bra		do_switch_sp_com			; NO  - continue with common part
	btfss	ext_s8_full_digital			; are we in external S8 full digital mode? 
	bra		do_switch_sp_com			; NO  - continue with common part
	btfsc	sensor1_active				; YES - process flags from HUD/ppO2 Monitor
	bsf		use_O2_sensor1				;     - ...
	btfsc	sensor2_active				;     - ...
	bsf		use_O2_sensor2				;     - ...
	btfsc	sensor3_active				;     - ...
	bsf		use_O2_sensor3				;     - ...
	bra		do_switch_sp_com			;     - continue with common part


;-----------------------------------------------------------------------------
; Call Function - toggle Sensor Usage
;
do_toggle_sensor:
	movf	menu_pos_cur,W				; copy position to WREG
	addlw	-.3							; skip first 3 menu items
	dcfsnz	WREG						; cursor on item sensor 1 ?
	btg		use_O2_sensor1				; YES - toggle sensor 1 state
	dcfsnz	WREG						; cursor on item sensor 2 ?
	btg		use_O2_sensor2				; YES - toggle sensor 2 state
	dcfsnz	WREG						; cursor on item sensor 3 ?
	btg		use_O2_sensor3				; YES - toggle sensor 3 state
	bra		do_return_divemode_sensor	; back to same menu

 ENDIF	; _external_sensor_eccr
 ENDIF	; _ccr_pscr


 IFDEF _cave_mode

;-----------------------------------------------------------------------------
; Return to Cave Mode Main Menu
;
do_return_main_cavemenu:
	call	menu_processor_pop					; drop selection from menu stack
	incf	selected_item,W						; item numbers start with 0, menu positions with 1
	movwf	menu_pos_cur						; position cursor where we came from
	bra		do_main_cavemenu_common				; continue with common part


;-----------------------------------------------------------------------------
; Cave Mode Main Menu
;
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
	;bra	do_main_cavemenu_common				; continue with common part

do_main_cavemenu_common:
	movlw	index_cave_waypoints				; get  number of cave waypoints custom view
	movwf	active_customview					; set  custom view number
	call	dive_customview_callup				; draw custom view

	MENU_BEGIN_DIVE	tCaveMode,  .6
		MENU_DYNAMIC	dyn_waypoint_set,		do_waypoint_set			; 1
		MENU_DYNAMIC	dyn_turndive_toggle,	do_turndive_toggle		; 2
		MENU_CALL		tDivemenu_off_on,		do_cavemode_toggle		; 3
		MENU_DYNAMIC	dyn_waypoint_out,		do_waypoint_out			; 4
		MENU_DYNAMIC	dyn_waypoint_in,		do_waypoint_in			; 5
		MENU_CALL		tExit,					do_exit_divemode_menu	; 6
	MENU_END


;-------------------------------------------------------------------
; dynamic Title - set a Waypoint
;
dyn_waypoint_set:
	call	cavemode_waypoint_set_check	; check if command is allowed to execute
	tstfsz	WREG						; command allowed?
	FONT_COLOR_DISABLED					; NO - switch to disabled color
	STRCAT_TEXT tDivemenu_wp_set		; print label
	return								; done


;-------------------------------------------------------------------
; dynamic Title - turn the Dive
;
dyn_turndive_toggle:
	call	cavemode_turndive_check		; check if command is allowed
	tstfsz	WREG						; command allowed?
	FONT_COLOR_DISABLED					; NO - switch to disabled color
	btfss	cave_mode					; cave mode switched on?
	bra		dyn_turndive_toggle_1		; NO  - print turn dive label
	btfss	dive_turned					; YES - dive turned?
	bra		dyn_turndive_toggle_1		;       NO  - print turn dive label
	STRCAT_TEXT tDivemenu_ContDive		;       YES - print continue dive label
	return								;           - done
dyn_turndive_toggle_1:
	STRCAT_TEXT tDivemenu_TurnDive		; print turn dive label
	return								; done


;-------------------------------------------------------------------
; dynamic Title - navigate one Waypoint outwards
;
dyn_waypoint_out:
	call	cavemode_waypoint_out_check	; check if command is allowed to execute
	tstfsz	WREG						; command allowed?
	FONT_COLOR_DISABLED					; NO - switch to disabled color
	STRCAT_TEXT tDivemenu_wp_out		; print label
	return								; done


;-------------------------------------------------------------------
; dynamic Title - navigate one Waypoint inwards
;
dyn_waypoint_in:
	call	cavemode_waypoint_in_check	; check if command is allowed to execute
	tstfsz	WREG						; command allowed?
	FONT_COLOR_DISABLED					; NO - switch to disabled color
	STRCAT_TEXT tDivemenu_wp_in			; print label
	return								; done


;-------------------------------------------------------------------
; Call Function - set a Waypoint
;
do_waypoint_set:
	bsf		request_waypoint_set		; set request flag
	bra		do_return_main_cavemenu		; back to menu


;-------------------------------------------------------------------
; Call Function - turn the dive
;
do_turndive_toggle:
	bsf		request_turn_toggle			; set request flag
	bra		do_return_main_cavemenu		; back to menu


;-------------------------------------------------------------------
; Call Function - turn Cave Mode on/off
;
do_cavemode_toggle:
	bsf		request_cave_toggle			; set request flag
	bra		do_return_main_cavemenu		; back to menu


;-------------------------------------------------------------------
; Call Function - navigate one Waypoint outwards
;
do_waypoint_out:
	bsf		request_waypoint_out		; set request flag
	bra		do_return_main_cavemenu		; back to menu


;-------------------------------------------------------------------
; Call Function - navigate one Waypoint inwards
;
do_waypoint_in:
	bsf		request_waypoint_in			; set request flag
	bra		do_return_main_cavemenu		; back to menu

 ENDIF	; _cave_mode


;-----------------------------------------------------------------------------
; Call Function - leave the Menu
;
do_exit_divemode_menu:
	bcf		block_option_value			; resume displaying of option values
	goto	diveloop_menu_exit			; back to the dive loop

;-----------------------------------------------------------------------------

	END
