;=============================================================================
;
;   File menu_tree.asm								REFACTORED VERSION V2.98
;
;   OSTC menus
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;   2011-07-11 : [jDG] Creation.

#include "hwos.inc"						; Mandatory header
#include "gaslist.inc"
#include "menu_processor.inc"
#include "start.inc"
#include "comm.inc"
#include "logbook.inc"
#include "tft.inc"
#include "eeprom_rs232.inc"
#include "external_flash.inc"
#include "shared_definitions.h"			; Mailbox from/to p2_deco.c
#include "isr.inc"
#include "ghostwriter.inc"
#include "adc_lightsensor.inc"
#include "wait.inc"
#include "i2c.inc"


	extern	do_demo_divemode
	extern	restart
	extern	option_save_all
	extern	option_reset
	extern	do_demo_planner
	extern	calibrate_mix
	extern	comm_mode0
	extern	piezo_config
	extern	compass_calibration_loop
	extern	option_reset_all
	extern	rtc_set_rtc
	extern	surfloop
	extern	oColorSetDive


gui	CODE

;=============================================================================
; Main Menu

do_return_main_menu:
	call	menu_processor_double_pop		; drop exit line and back to last line
	bra		do_main_menu_common

	global	do_main_menu
do_main_menu:
	movff	menupos3,customview_surfmode ; save last customview

	global	do_main_menu2
do_main_menu2:							; entry point used by logbook.asm
	call	TFT_boot
	bcf		sleepmode					; for timeout
	call	menu_processor_reset		; restart from first icon

do_main_menu_common:
	MENU_BEGIN	tMainMenu, .7
		MENU_CALL		tLogbook,					logbook
		MENU_CALL		tGasSetup,					do_gas_menu
		MENU_CALL		tCCRSetup,					do_ccr_menu
		MENU_CALL		tPlan,						do_planner_menu
		MENU_CALL		tDiveModeMenu,				do_divemode_menu
		MENU_CALL		tSystSets,					do_settings_menu
		MENU_CALL		tExit,						restart
	MENU_END


;=============================================================================
; CCR Setup

do_return_ccr_menu:
	call	menu_processor_double_pop	; drop exit line and back to last line

do_ccr_menu:
	bcf		menu_show_sensors2			; stop imprinting of live sensor values

	btfsc	analog_o2_input
	bra		do_ccr_menu_cR

	; COMMENTED OUT - currently there is no difference between the OSTC 2 and 3 regarding this menu
	; btfss	optical_input
	; bra	do_ccr_menu_ostc2

	MENU_BEGIN	tCCRSetup, .6			; OSTC3 menu (and currently also the OSTC2 menu)
		MENU_OPTION		tCCRMode,					oCCRMode,				0
		MENU_CALL		tDiluentSetup,				do_diluent_setup
		MENU_CALL		tFixedSetpoints,			do_fixed_setpoints
		MENU_CALL		tPSCRMenu,					do_PSCR_menu
		MENU_OPTION		tCCmaxFracO2,				oCCmaxFracO2,			0
		MENU_CALL		tExit,						do_return_main_menu
	MENU_END


do_ccr_menu_cR:							; cR menu
	MENU_BEGIN	tCCRSetup, .7
		MENU_OPTION		tCCRMode,					oCCRMode,				0
		MENU_CALL		tCalibrateMenu,				do_calibrate_menu
		MENU_CALL		tDiluentSetup,				do_diluent_setup
		MENU_CALL		tFixedSetpoints,			do_fixed_setpoints
		MENU_CALL		tPSCRMenu,					do_PSCR_menu
		MENU_OPTION		tCCmaxFracO2,				oCCmaxFracO2,			0
		MENU_CALL		tExit,						do_return_main_menu
	MENU_END

; COMMENTED OUT - currently there is no difference between the OSTC 2 and 3 regarding this menu
;do_ccr_menu_ostc2:
;	MENU_BEGIN	tCCRSetup, .6			; ostc2 menu
;		MENU_OPTION		tCCRMode,					oCCRMode,				0
;		MENU_CALL		tDiluentSetup,				do_diluent_setup
;		MENU_CALL		tFixedSetpoints,			do_fixed_setpoints
;		MENU_CALL		tPSCRMenu,					do_PSCR_menu
;		MENU_OPTION		tCCmaxFracO2,				oCCmaxFracO2,			0
;		MENU_CALL		tExit,						do_return_main_menu
;	MENU_END


do_calibrate_menu:
	call	enable_ir_s8				; Enable IR/S8-Port
	bsf		menu_show_sensors2			; start imprinting of live sensor values

do_calibrate_menu2:
	MENU_BEGIN	tCalibrateMenu, .6
		MENU_CALL		tDiveHudMask1,				0
		MENU_CALL		tDiveHudMask2,				0
		MENU_CALL		tDiveHudMask3,				0
		MENU_OPTION		tCalibrationGas,oCalGasO2,	0
		MENU_CALL		tCalibrate,					do_calibrate_mix
		MENU_CALL		tExit,						do_return_ccr_menu
	MENU_END


do_calibrate_mix:
	call	calibrate_mix				; Calibrate with opt_calibration_O2_ratio, also calibrate S8 HUD if connected
	WAITMS	d'250'						; Wait for HUD v3
	movlw	.9
	movff	WREG,customview_surfmode	; show sensor mV custom view after restart
	goto	restart						; Restart into surface mode


do_diluent_setup:
	bsf		ccr_diluent_setup			; =1: Setting up Diluents ("Gas6-10")
	bcf		short_gas_decriptions		; =1: Use short versions of gaslist_strcat_gas_mod and gaslist_strcat_setpoint
	call	gaslist_cleanup_list		; Takes care that only one gas can be first and first has 0m change depth

	MENU_BEGIN	tDiluentSetup, .6
		MENU_DYNAMIC	gaslist_strcat_gas_mod,		do_edit_gas_menu
		MENU_DYNAMIC	gaslist_strcat_gas_mod,		do_edit_gas_menu
		MENU_DYNAMIC	gaslist_strcat_gas_mod,		do_edit_gas_menu
		MENU_DYNAMIC	gaslist_strcat_gas_mod,		do_edit_gas_menu
		MENU_DYNAMIC	gaslist_strcat_gas_mod,		do_edit_gas_menu
		MENU_CALL		tExit,						do_return_ccr_menu
	MENU_END


do_return_fixed_setpoints:
	call	menu_processor_double_pop	; drop exit line and back to last line

do_fixed_setpoints:
	bcf		short_gas_decriptions		; =1: Use short versions of gaslist_strcat_gas_mod and gaslist_strcat_setpoint

	MENU_BEGIN	tFixedSetpoints, .6
		MENU_DYNAMIC	gaslist_strcat_setpoint,	do_edit_sp_menu
		MENU_DYNAMIC	gaslist_strcat_setpoint,	do_edit_sp_menu
		MENU_DYNAMIC	gaslist_strcat_setpoint,	do_edit_sp_menu
		MENU_DYNAMIC	gaslist_strcat_setpoint,	do_edit_sp_menu
		MENU_DYNAMIC	gaslist_strcat_setpoint,	do_edit_sp_menu
		MENU_CALL		tExit,						do_return_ccr_menu
	MENU_END


do_edit_sp_menu:
	call	gaslist_setSP				; Save current item.

	MENU_BEGIN	tFixedSetpoints, .5
		MENU_DYNAMIC	gaslist_strcat_setpoint_0,	0
		MENU_CALL		tSPPlus,					gaslist_spplus
		MENU_CALL		tDepthPlus,					gaslist_spdepthplus
		MENU_CALL		tDepthMinus,				gaslist_spdepthminus
		MENU_CALL		tExit,						do_return_fixed_setpoints
	MENU_END


do_PSCR_menu:
	MENU_BEGIN	tPSCRMenu, .3			; PSCR Menu
		MENU_OPTION		tPSCR_O2_drop,				oPSCR_drop,				0
		MENU_OPTION		tPSCR_lungratio,			oPSCR_lungratio,		0
		MENU_CALL		tExit,						do_return_ccr_menu
	MENU_END

;=============================================================================
; OC Gas Setup

do_return_gas_menu:
	call	menu_processor_double_pop	; drop exit line and back to last line

	btfsc	ccr_diluent_setup			; Return to CCR-Menu?
	bra		do_diluent_setup			; Yes.

do_gas_menu:
	bcf		ccr_diluent_setup			; =1: Setting up Diluents ("Gas6-10")
	bcf		short_gas_decriptions		; =1: Use short versions of gaslist_strcat_gas_mod and gaslist_strcat_setpoint
	call	gaslist_cleanup_list		; Takes care that only one gas can be first and first has 0m change depth

	MENU_BEGIN	tGaslist, .6
		MENU_DYNAMIC	gaslist_strcat_gas_mod,		do_edit_gas_menu
		MENU_DYNAMIC	gaslist_strcat_gas_mod,		do_edit_gas_menu
		MENU_DYNAMIC	gaslist_strcat_gas_mod,		do_edit_gas_menu
		MENU_DYNAMIC	gaslist_strcat_gas_mod,		do_edit_gas_menu
		MENU_DYNAMIC	gaslist_strcat_gas_mod,		do_edit_gas_menu
		MENU_CALL		tExit,						do_return_main_menu
	MENU_END


do_return_edit_gas_menu:
	call	menu_processor_pop			; drop exit line and ...
do_abort_gas_depth_menu:
	call	menu_processor_pop			; back to last line
	bra		do_edit_gas_menu_common

do_edit_gas_menu:
	call	gaslist_setgas				; set gaslist_gas

do_edit_gas_menu_common:				; keep current gas
	MENU_BEGIN	tGasEdit, .6
		MENU_DYNAMIC	gaslist_gastitle,			0
		MENU_DYNAMIC	gaslist_MOD_END,			0
		MENU_DYNAMIC	gaslist_show_type,			gaslist_toggle_type
		MENU_CALL		tSetup_mix,					do_setup_mix
		MENU_CALL		tGasDepth,					do_gas_depth_menu
		MENU_CALL		tExit,						do_return_gas_menu
	MENU_END


do_setup_mix:
	MENU_BEGIN	tGasEdit, .7
		MENU_DYNAMIC	gaslist_gastitle,			0
		MENU_DYNAMIC	gaslist_MOD_END,			0
		MENU_CALL		tO2Plus,					gaslist_pO2
		MENU_CALL		tO2Minus,					gaslist_mO2
		MENU_CALL		tHePlus,					gaslist_pHe
		MENU_CALL		tHeMinus,					gaslist_mHe
		MENU_CALL		tExit,						do_return_edit_gas_menu
	MENU_END


do_gas_depth_menu:
	movff	gaslist_gas,WREG
	lfsr	FSR1,opt_gas_type			; Read opt_gas_type[WREG]
	movff	PLUSW1,lo					; Used as temp
	movlw	.3							; 3=Deco
	btfsc	ccr_diluent_setup			; =1: Setting up Diluents ("Gas6-10")
	movlw	.2							; 2=Normal
	cpfseq	lo
	bra		do_abort_gas_depth_menu		; Non-Deco gas or "Normal" Diluent, abort!

	MENU_BEGIN	tGasEdit, .7
		MENU_DYNAMIC	gaslist_gastitle,			0
		MENU_DYNAMIC	gaslist_MOD_END,			0
		MENU_DYNAMIC	gaslist_ppo2,				0					; ppO2 at change depth
		MENU_CALL		tDepthPlus,					gaslist_pDepth
		MENU_CALL		tDepthMinus,				gaslist_mDepth
		MENU_DYNAMIC	gaslist_reset_mod_title,	gaslist_reset_mod
		MENU_CALL		tExit,						do_return_edit_gas_menu
	MENU_END


;=============================================================================
; Simulator menus

do_return_planner_menu:
	call	menu_processor_pop			; drop exit line and ...

	global	do_return_demo_planner
do_return_demo_planner:
	call	menu_processor_pop			; back to last line
	bra		do_planner_common

do_planner_menu:
	; to have correct simulator results after mode changes without prior excursion to surfacemode
	call	option_save_all
	call	restart_set_modes_and_flags
	; Reset dive time/depth to default values
	lfsr	FSR0,odiveInterval
	call	option_reset
	lfsr	FSR0,obottomTime
	call	option_reset
	lfsr	FSR0,obottomDepth
	call	option_reset

do_planner_common:
	MENU_BEGIN	tPlan, .7
		MENU_OPTION		tIntvl,						odiveInterval,			0
		MENU_OPTION		tBtDep,						obottomDepth,			0
		MENU_CALL		tInter,						do_demo_divemode
		MENU_OPTION		tBtTm,						obottomTime,			0
		MENU_CALL		tDecoSetup,					do_planner_config
		MENU_CALL		tDeco,						do_demo_planner
		MENU_CALL		tExit,						do_return_main_menu
	MENU_END


do_planner_config:
	MENU_BEGIN	tPlan, .3
		MENU_OPTION		tSelectSetpoint,			oSimSetpoint,			0
		MENU_OPTION		tuseAGF,					oSimAGF,				0
		MENU_CALL		tExit,						do_return_planner_menu
	MENU_END


;=============================================================================
; Divemode menu

do_return_divemode_menu:
	call	menu_processor_double_pop	; drop exit line and back to last line

do_divemode_menu:
	MENU_BEGIN	tDiveModeMenu, .7
		MENU_OPTION		tDvMode,					oDiveMode,				0
		MENU_OPTION		tDkMode,					oDecoMode,				0
		MENU_CALL		tppO2settings,				do_ppo2_menu
		MENU_OPTION		tsafetystopmenu,			oSafetyStop,			0
		MENU_CALL		t2ndDecoPlanMenu,			do_2nd_deco_plan_menu
		MENU_CALL		tDecoparameters,			do_decoparameters_menu
		MENU_CALL		tExit,						do_return_main_menu
	MENU_END


do_ppo2_menu:
	MENU_BEGIN	tppO2settings, .6
		MENU_DYNAMIC	divesets_ppo2_max,			do_toggle_ppo2_max
		MENU_DYNAMIC	divesets_ppo2_max_deco,		do_toggle_ppo2_max_deco
		MENU_DYNAMIC	divesets_ppo2_min,			do_toggle_ppo2_min
		MENU_DYNAMIC	divesets_ppo2_min_cc,		do_toggle_ppo2_min_cc
		MENU_OPTION		tShowppO2,					oShowppO2,				0
		MENU_CALL		tExit,						do_return_divemode_menu
	MENU_END


do_return_decoparameters_menu:
	call	menu_processor_double_pop	; drop exit line and back to last line

do_decoparameters_menu:
	movff	char_I_deco_model,lo		; 0 = ZH-L16, 1 = ZH-L16-GF
	tstfsz	lo
	bra		do_decoparameters_menugf	; <> 0 -> GF menu!
	; NON-GF menu
	MENU_BEGIN	tDecoparameters, .4
		MENU_OPTION		tSaturationMult,			osatmult,				0
		MENU_OPTION		tDesaturationMult,			odesatmult,				0
		MENU_OPTION		tLastDecostop,				oLastDeco,				0
		MENU_CALL		tExit,						do_return_divemode_menu
	MENU_END

do_decoparameters_menugf:
	; GF menu
	MENU_BEGIN	tDecoparameters, .7
		MENU_OPTION		tGF_low,					oGF_low,				0
		MENU_OPTION		tGF_high,					oGF_high,				0
		MENU_CALL		taGFMenu,					do_aGF_menu
		MENU_OPTION		tSaturationMult,			osatmultgf,				0
		MENU_OPTION		tDesaturationMult,			odesatmultgf,			0
		MENU_OPTION		tLastDecostop,				oLastDeco,				0
		MENU_CALL		tExit,						do_return_divemode_menu
	MENU_END


do_return_2nd_deco_plan_menu:
	call	menu_processor_double_pop	; drop exit line and back to last line

do_2nd_deco_plan_menu
	MENU_BEGIN	t2ndDecoPlanMenu, .7
		MENU_OPTION		tFTTSMenu,					oExtraTime,				0
		MENU_OPTION		tCalcAscGas,				oCalcAscGas,			0
		MENU_OPTION		tSetBotUse,					obottom_usage,			0
		MENU_OPTION		tSetDecoUse,				odeco_usage,			0
		MENU_CALL		tTankSizes,					do_tank_sizes_menu
		MENU_CALL		tTankFillPress,				do_tank_fill_press_menu
		MENU_CALL		tExit,						do_return_divemode_menu
	MENU_END


do_tank_sizes_menu:
	MENU_BEGIN	tTankSizes, .6
		MENU_OPTION		tGas1,						oTankSize1,				0
		MENU_OPTION		tGas2,						oTankSize2,				0
		MENU_OPTION		tGas3,						oTankSize3,				0
		MENU_OPTION		tGas4,						oTankSize4,				0
		MENU_OPTION		tGas5,						oTankSize5,				0
		MENU_CALL		tExit,						do_return_2nd_deco_plan_menu
	MENU_END


do_tank_fill_press_menu:
	MENU_BEGIN	tTankFillPress, .6
		MENU_OPTION		tGas1,						oTankFillPres1,			0
		MENU_OPTION		tGas2,						oTankFillPres2,			0
		MENU_OPTION		tGas3,						oTankFillPres3,			0
		MENU_OPTION		tGas4,						oTankFillPres4,			0
		MENU_OPTION		tGas5,						oTankFillPres5,			0
		MENU_CALL		tExit,						do_return_2nd_deco_plan_menu
	MENU_END


do_aGF_menu:
	MENU_BEGIN	taGFMenu, .4
		MENU_OPTION		taGF_enable,				oEnable_aGF,			0
		MENU_OPTION		taGF_low,					oaGF_low,				0
		MENU_OPTION		taGF_high,					oaGF_high,				0
		MENU_CALL		tExit,						do_return_decoparameters_menu
	MENU_END


;=============================================================================
; Setup Menu

do_return_settings_deeper:				; entry point for return from set time/date sub-menu
	bcf		settime_setdate				; clear flag
	call	menu_processor_pop			; drop one more stack entry

do_return_settings:
	call	menu_processor_double_pop	; drop exit line and back to last line

do_settings_menu:
	btfsc	ble_available				; ble available?
	bra		do_settings_menu_ble		; YES

	MENU_BEGIN	tSystSets, .6
		MENU_CALL		tInfoMenu,					do_info_menu
		MENU_CALL		tSetTimeDate,				do_date_time_menu
		MENU_CALL		tDispSets,					do_dispsets_menu
		MENU_OPTION		tLanguage,					oLanguage,				0
		MENU_CALL		tMore,						do_settings_menu_more
		MENU_CALL		tExit,						do_return_main_menu
	MENU_END

do_settings_menu_ble:
	MENU_BEGIN	tSystSets, .7
		MENU_CALL		tInfoMenu,					do_info_menu
		MENU_CALL		tBleTitle,					comm_mode0
		MENU_CALL		tSetTimeDate,				do_date_time_menu
		MENU_CALL		tDispSets,					do_dispsets_menu
		MENU_OPTION		tLanguage,					oLanguage,				0
		MENU_CALL		tMore,						do_settings_menu_more
		MENU_CALL		tExit,						do_return_main_menu
	MENU_END

do_info_menu:
	MENU_BEGIN	tInfoMenu, .6
		MENU_DYNAMIC	info_menu_serial,			0
		MENU_DYNAMIC	info_menu_firmware,			0
		MENU_DYNAMIC	info_menu_battery_volts,	0
		MENU_DYNAMIC	info_menu_uptime,			0
		MENU_DYNAMIC	info_menu_total_dives,		0
		MENU_CALL		tExit,						do_return_settings
	MENU_END


do_return_settings_more_deeper:			; entry point for returns from reset sub-menu
	call	menu_processor_pop			; drop one more stack entry

do_return_settings_more:
	call	menu_processor_double_pop	; drop exit line and back to last line

do_settings_menu_more:
	btfsc	battery_gauge_available		; piezo buttons available
	bra		do_settings_menu_more_piezo
	btfsc	ble_available				; ble available
	bra		do_settings_menu_more_ostc3p
																				; All MENU_CALLs that are
	MENU_BEGIN	tSystSets, .6													; in all of this 3 menus
		MENU_CALL		tCompassMenu,				do_compass_menu				; need to stay together
		MENU_CALL		tLogOffset,					do_log_offset_menu			; on this menu level in
		MENU_OPTION		tAltMode,					oAltMode,				0	; oder to not mass up the
		MENU_OPTION		tDvSalinity,				oDiveSalinity,			0	; menu stack on doing the
		MENU_CALL		tResetMenu,					do_reset_menu				; do_return_settings !
		MENU_CALL		tExit,						do_return_settings
	MENU_END


do_return_settings_menu_more_pz:
	call	TFT_ClearScreen
	call	piezo_config				; Configure buttons
	call	menu_processor_double_pop	; drop exit line and back to last line

do_settings_menu_more_piezo:
	MENU_BEGIN	tSystSets, .7
		MENU_CALL		tCompassMenu,				do_compass_menu
		MENU_CALL		tLogOffset,					do_log_offset_menu
		MENU_OPTION		tAltMode,					oAltMode,				0
		MENU_OPTION		tDvSalinity,				oDiveSalinity,			0
		MENU_CALL		tResetMenu,					do_reset_menu
		MENU_CALL		tMore,						do_settings_piezo_menu
		MENU_CALL		tExit,						do_return_settings
	MENU_END

do_settings_menu_more_ostc3p:			; Menu with BLE feature
	MENU_BEGIN	tSystSets, .6
		MENU_CALL		tCompassMenu,				do_compass_menu
		MENU_CALL		tLogOffset,					do_log_offset_menu
		MENU_OPTION		tAltMode,					oAltMode,				0
		MENU_OPTION		tDvSalinity,				oDiveSalinity,			0
		MENU_CALL		tResetMenu,					do_reset_menu
		MENU_CALL		tExit,						do_return_settings
	MENU_END


do_settings_piezo_menu:
	; Menu with features only available in piezo button hardware
	MENU_BEGIN	tSystSets, .3
		MENU_OPTION		tButtonleft,				ocR_button_left,		0		; left button sensitivity
		MENU_OPTION		tButtonright,				ocR_button_right,		0		; right button sensitivity
		MENU_CALL		tExit,						do_return_settings_menu_more_pz
	MENU_END


do_compass_menu:
	MENU_BEGIN	tSystSets, .5
		MENU_CALL		tCompassMenu,				compass_calibration_loop		; exits to surfloop
;		MENU_OPTION		tCompassGain,				oCompassGain,	0
		MENU_DYNAMIC	menu_cal_x,					0
		MENU_DYNAMIC	menu_cal_y,					0
		MENU_DYNAMIC	menu_cal_z,					0
		MENU_CALL		tExit,						do_return_settings_more
	MENU_END


;=============================================================================
; Reset and confirmation menu.

do_reset_menu:
	MENU_BEGIN	tResetMenu, .6
		MENU_CALL		tExit,						do_return_settings_more
		MENU_CALL		tReboot,					do_reset_menu2			; Confirm
		MENU_CALL		tResetDeco,					do_reset_menu3			; Confirm
		MENU_CALL		tResetSettings,				do_reset_menu4			; Confirm
		MENU_CALL		tResetLogbook,				do_reset_menu5			; Confirm
		MENU_CALL		tResetBattery,				do_new_battery_menu		; Confirm
	MENU_END

do_reset_menu2:
	MENU_BEGIN	tResetMenu2, .2
		MENU_CALL		tAbort,						do_return_settings_more_deeper
		MENU_CALL		tReboot,					do_reboot				; Reboot
	MENU_END

do_reset_menu3:
	MENU_BEGIN	tResetMenu2, .2
		MENU_CALL		tAbort,						do_return_settings_more_deeper
		MENU_CALL		tResetDeco,					do_reset_deco			; Reset Deco
	MENU_END

do_reset_menu4:
	MENU_BEGIN	tResetMenu2, .2
		MENU_CALL		tAbort,						do_return_settings_more_deeper
		MENU_CALL		tResetSettings,				do_reset_settings		; Reset all settings
	MENU_END

do_reset_menu5:
	MENU_BEGIN	tResetMenu2, .2
		MENU_CALL		tAbort,						do_return_settings_more_deeper
		MENU_CALL		tResetLogbook,				do_reset_logbook		; Reset logbook
	MENU_END


do_reset_logbook:
	clrf	EEADRH						; Make sure to select EEPROM bank 0
	clrf	EEDATA
	read_int_eeprom  .2
	write_int_eeprom .16
	read_int_eeprom  .3
	write_int_eeprom .17				; Copy number of dives
	clrf	EEDATA
	write_int_eeprom .2
	write_int_eeprom .3					; Clear total dives
	write_int_eeprom .4
	write_int_eeprom .5
	write_int_eeprom .6					; Reset logbook pointers
	call	ext_flash_erase_logbook		; And complete logbook (!)

	goto	do_return_settings_more_deeper


do_reset_deco:
	SAFE_2BYTE_COPY last_surfpressure_30min,int_I_pres_respiration	; copy surface pressure to deco routine
	SAFE_2BYTE_COPY last_surfpressure_30min,int_I_pres_surface		; copy surface pressure to deco routine

	call	deco_clear_tissue			; set all tissues to Pamb * N2_ratio (C-Code)
	call	deco_calc_dive_interval_1min; calculate deco in surface mode
	call	deco_calc_desaturation_time	; calculate desaturation and no-fly time
	banksel	common

	goto	do_return_settings_more_deeper


do_reset_settings:
	call	TFT_ClearScreen				; Clear screen
	banksel	common						; (probably not needed)
	call	option_reset_all			; Reset all options to factory default.
	goto	restart						; Restart into surfacemode

do_reboot:
	call	ext_flash_enable_protection	; Enables write protection
	reset


do_date_time_menu:
	MENU_BEGIN	tSetTimeDate, .4
		MENU_CALL		tSetTime,					do_time_menu
		MENU_CALL		tSetDate,					do_date_menu
		MENU_OPTION		tDateFormat,oDateFormat,	0
		MENU_CALL		tExit,						do_return_settings
	MENU_END


do_date_menu:
	bsf		settime_setdate

	MENU_BEGIN	tSetDate, .4
		MENU_OPTION		tSetDay,					oSetDay,				0
		MENU_OPTION		tSetMonth,					oSetMonth,				0
		MENU_OPTION		tSetYear,					oSetYear,				0
		MENU_CALL		tExit,						do_return_settings_deeper
	MENU_END


do_reset_seconds:
	clrf	secs
	call	rtc_set_rtc					; writes mins, sec, hours, day, month and year to RTC module
	call	menu_processor_pop			; clear the MENU_CALL for do_reset_seconds from the stack
	;bra	do_time_menu				; direct jump-back into the menu

do_time_menu:
	bsf		settime_setdate

	MENU_BEGIN	tSetTime, .4
		MENU_OPTION		tSetHours,					oSetHours,				0
		MENU_OPTION		tSetMinutes,				oSetMinutes,			0
		MENU_CALL		tSetSeconds,				do_reset_seconds
		MENU_CALL		tExit,						do_return_settings_deeper
	MENU_END


do_toggle_ppo2_max:						; add 0.1bar, with hard-coded max.
	movff	char_I_ppO2_max,lo			; banksafe
	movlw	.10
	addwf	lo,F
	movlw	ppo2_warning_high_highest
	cpfsgt	lo
	bra		do_toggle_ppo2_max2
	movlw	ppo2_warning_high_lowest
	movwf	lo
do_toggle_ppo2_max2:
	movff	lo,char_I_ppO2_max
	return

do_toggle_ppo2_max_deco:				; add 0.1bar, with hard-coded max.
	movff	char_I_ppO2_max_deco,lo		; banksafe
	movlw	.10
	addwf	lo,F
	movlw	ppo2_warning_deco_highest
	cpfsgt	lo
	bra		do_toggle_ppo2_max_deco2
	movlw	ppo2_warning_deco_lowest
	movwf	lo
do_toggle_ppo2_max_deco2:
	movff	lo,char_I_ppO2_max_deco
	return

do_toggle_ppo2_min:						; sub 0.1bar, with hard-coded min.
	movff	char_I_ppO2_min,lo			; banksafe
	incf	lo,F
	movlw	ppo2_warning_low_highest
	cpfsgt	lo
	bra		do_toggle_ppo2_min2
	movlw	ppo2_warning_low_lowest
	movwf	lo
do_toggle_ppo2_min2:
	movff	lo,char_I_ppO2_min
	return

do_toggle_ppo2_min_cc:					; sub 0.1bar, with hard-coded min.
	movff	char_I_ppO2_min_loop,lo		; banksafe
	incf	lo,F
	movlw	ppo2_warning_loop_highest
	cpfsgt	lo
	bra		do_toggle_ppo2_min_cc2
	movlw	ppo2_warning_loop_lowest
	movwf	lo
do_toggle_ppo2_min_cc2:
	movff	lo,char_I_ppO2_min_loop
	return


	; Logbook offset sub-menu
do_log_offset_menu:
	MENU_BEGIN	tLogOffset, .6
		MENU_DYNAMIC	TFT_LogOffset_Logtitle,		0
		MENU_CALL		tLogOffsetp1,				do_logoffset_plus1
		MENU_CALL		tLogOffsetp10,				do_logoffset_plus10
		MENU_CALL		tLogOffsetm1,				do_logoffset_minus1
		MENU_CALL		tLogOffsetm10,				do_logoffset_minus10
		MENU_CALL		tExit,						do_return_settings_more
	MENU_END


do_logoffset_minus1:
	call	do_logoffset_common_read	; Read into lo:hi
	movlw	.1
	subwf	lo
	movlw	.0
	subwfb	hi
	btfss	hi,7						; <0?
	goto	do_logoffset_common_write	; Store and return
	clrf	lo
	clrf	hi
	goto	do_logoffset_common_write	; Store and return

do_logoffset_minus10:
	call	do_logoffset_common_read	; Read into lo:hi
	movlw	.10
	subwf	lo
	movlw	.0
	subwfb	hi
	btfss	hi,7						; <0?
	goto	do_logoffset_common_write	; Store and return
	clrf	lo
	clrf	hi
	goto	do_logoffset_common_write	; Store and return

do_logoffset_plus1:
	call	do_logoffset_common_read	; Read into lo:hi
	infsnz	lo,F
	incf	hi,F
	goto	do_logoffset_common_write	; Store and return

do_logoffset_plus10:
	call	do_logoffset_common_read	; Read into lo:hi
	movlw	.10
	addwf	lo
	movlw	.0
	addwfc	hi
	goto	do_logoffset_common_write	; Store and return

do_return_dispsets_menu:
	bcf		in_color_menu
	call	menu_processor_double_pop	; drop exit line and back to last line

do_dispsets_menu:
	MENU_BEGIN	tDispSets, .5
		MENU_OPTION		tBright,					oBrightness,			0
		MENU_CALL		tColorScheme,				do_color_scheme
		MENU_OPTION		tFlip,						oFlipScreen,			0
		MENU_CALL		tMore,						do_dispsets_menu_more
		MENU_CALL		tExit,						do_return_settings
	MENU_END


do_dispsets_menu_more:
	MENU_BEGIN	tDispSets, .7
		MENU_OPTION		tMODwarning,				oMODwarning,			0
		MENU_OPTION		tIBCDwarning,				oEnable_IBCD,			0
		MENU_OPTION		tVSItext2,					oVSItextv2,				0
		MENU_OPTION		tVSIgraph,					oVSIgraph,				0
		MENU_OPTION		tTimeoutDive,				oDiveTimeout,			0
		MENU_OPTION		tUnits,						oUnits,					0
		MENU_CALL		tExit,						do_return_dispsets_menu
	MENU_END


do_color_scheme:
	bsf		in_color_menu

	MENU_BEGIN	tColorScheme, .2
		MENU_OPTION		tColorSetDive,				oColorSetDive,			0
		MENU_CALL		tExit,						do_return_dispsets_menu
	MENU_END


;=============================================================================

do_new_battery_menu:
	MENU_BEGIN	tNewBattTitle, .2
		MENU_CALL		tAbort,						do_return_settings_more_deeper
		MENU_CALL		tYes,						do_new_battery_select
	MENU_END

	global	do_new_battery_select
do_new_battery_select:
	bsf		enable_screen_dumps			; To prevent exiting into COMM mode immediately
	call	TFT_boot					; Initialize TFT (includes clear screen)
	call	TFT_Display_FadeIn			; Show splash
	movlw	.100
	movwf	batt_percent				; make sure to reset batt_percent

	; Default (In cases of timeout or USB): Use old battery
	clrf	EEADRH
	read_int_eeprom 0x07
	movff	EEDATA,battery_gauge+0
	read_int_eeprom 0x08
	movff	EEDATA,battery_gauge+1
	read_int_eeprom 0x09
	movff	EEDATA,battery_gauge+2
	read_int_eeprom 0x0A
	movff	EEDATA,battery_gauge+3
	read_int_eeprom 0x0B
	movff	EEDATA,battery_gauge+4
	read_int_eeprom 0x0C
	movff	EEDATA,battery_gauge+5

	call	menu_processor_reset		; restart from first icon.

	; hardware_flag:
	; 3: 0x0A or 0x13 (2016)
	; cR: 0x05
	; 2 with BLE: 0x11
	; Sport: 0x12
	; 3 with BLE: 0x1A 

	movlw	0x0A
	cpfseq	hardware_flag
	bra		$+4
	bra		menu_new_battery_AA
	movlw	0x13
	cpfseq	hardware_flag
	bra		$+4
	bra		menu_new_battery_AA_16650
	movlw	0x12
	cpfseq	hardware_flag
	bra		$+4
	bra		menu_new_battery_AA
	movlw	0x1A
	cpfseq	hardware_flag
	bra		$+4
	bra		menu_new_battery_AA
	movlw	0x11
	cpfseq	hardware_flag
	bra		$+4
	bra		menu_new_battery_18650
	movlw	0x05
	cpfseq	hardware_flag
	bra		$+4
	bra		menu_new_battery_18650
	bra		use_old_batteries			; any unsupported value


menu_new_battery_AA_16650:
	MENU_BEGIN	tNewBattTitle, .5
		MENU_CALL		tNewBattOld,				use_old_batteries
		MENU_CALL		tNewBattNew36,				use_new_36V_batteries
		MENU_CALL		tNewBattNew15,				use_new_15V_batteries
		MENU_CALL		tNewBattAccu,				use_36V_rechargeable
		MENU_CALL		tNew16650,					use_16650_battery
	MENU_END


menu_new_battery_AA:
	MENU_BEGIN	tNewBattTitle, .4
		MENU_CALL		tNewBattOld,				use_old_batteries
		MENU_CALL		tNewBattNew36,				use_new_36V_batteries
		MENU_CALL		tNewBattNew15,				use_new_15V_batteries
		MENU_CALL		tNewBattAccu,				use_36V_rechargeable
	MENU_END


menu_new_battery_18650:
	MENU_BEGIN	tNewBattTitle, .2
		MENU_CALL		tNewBattOld,				use_old_batteries
		MENU_CALL		tNew18650,					use_18650_battery
	MENU_END


	global	use_old_prior_209
use_old_prior_209:
	clrf	EEADRH
	read_int_eeprom 0x0F				; =0:1.5V, =1:3,6V Saft, =2:LiIon 3,7V/0.8Ah, =3:LiIon 3,7V/3.1Ah, =4: LiIon 3,7V/2.3Ah
	incfsz	EEDATA,F					; Was 0xFF?
	return								; No, done.

	call	lt2942_get_status			; Check for gauge IC
	movlw	.3							; Assume a 18650
	btfss	battery_gauge_available		; cR/2 hardware?
	movlw	.1							; Assume a Saft
	movwf	EEDATA
	write_int_eeprom 0x0F				; Store the new battery type into EEPROM
	return


	global	use_old_batteries
use_old_batteries:
	clrf	EEADRH
	read_int_eeprom 0x07
	movff	EEDATA,battery_gauge+0
	read_int_eeprom 0x08
	movff	EEDATA,battery_gauge+1
	read_int_eeprom 0x09
	movff	EEDATA,battery_gauge+2
	read_int_eeprom 0x0A
	movff	EEDATA,battery_gauge+3
	read_int_eeprom 0x0B
	movff	EEDATA,battery_gauge+4
	read_int_eeprom 0x0C
	movff	EEDATA,battery_gauge+5
	read_int_eeprom 0x0F
	movff	EEDATA,battery_type			; =0:1.5V, =1:3,6V Saft, =2:LiIon 3,7V/0.8Ah, =3:LiIon 3,7V/3.1Ah, =4: LiIon 3,7V/2.3Ah

	rcall	setup_new_saft				; Any other value
	incf	EEDATA,F					; 1 ... 5
	dcfsnz	EEDATA,F
	rcall	setup_new_15v				;=0
	dcfsnz	EEDATA,F
	rcall	setup_new_saft				;=1
	dcfsnz	EEDATA,F
	rcall	setup_new_panasonic			;=2
	dcfsnz	EEDATA,F
	rcall	setup_new_18650				;=3
	dcfsnz	EEDATA,F
	rcall	setup_new_16650				;=4

	bcf		use_old_batt_flag			; clear flag
	goto	surfloop					; Jump to Surfaceloop!


setup_new_15v:
	bsf		charge_disable
	bcf		TRISE,2
	movlw	.100
	movwf	batt_percent				; To have 1,5V batteries right after firmware update
	movlw	.0
	movff	WREG,battery_type
	return


setup_new_saft:
	banksel	battery_capacity
	movlw	LOW		internal_saft_capacity
	movwf	internal_battery_capacity+0
	movlw	HIGH	internal_saft_capacity
	movwf	internal_battery_capacity+1
	movlw	LOW		saft_capacity
	movwf	battery_capacity+0
	movlw	HIGH	saft_capacity
	movwf	battery_capacity+1
	movlw	LOW		saft_offset
	movwf	battery_offset+0
	movlw	HIGH	saft_offset
	movwf	battery_offset+1
	banksel	common
	bsf		charge_disable
	bcf		TRISE,2
	movlw	.1
	movff	WREG,battery_type
	return


setup_new_panasonic:
	banksel battery_capacity
	movlw	LOW		internal_panasonic_capacity
	movwf	internal_battery_capacity+0
	movlw	HIGH	internal_panasonic_capacity
	movwf	internal_battery_capacity+1
	movlw	LOW		panasonic_capacity
	movwf	battery_capacity+0
	movlw	HIGH	panasonic_capacity
	movwf	battery_capacity+1
	movlw	LOW		panasonic_offset
	movwf	battery_offset+0
	movlw	HIGH	panasonic_offset
	movwf	battery_offset+1
	banksel	common
	bcf		charge_disable
	bsf		TRISE,2
	movlw	.2
	movff	WREG,battery_type
	return


setup_new_18650:
	banksel	battery_capacity
	clrf	internal_battery_capacity+0
	clrf	internal_battery_capacity+1
	movlw	LOW		ncr18650_capacity
	movwf	battery_capacity+0
	movlw	HIGH	ncr18650_capacity
	movwf	battery_capacity+1
	movlw	LOW		ncr18650_offset
	movwf	battery_offset+0
	movlw	HIGH	ncr18650_offset
	movwf	battery_offset+1
	banksel	common
	bcf		charge_disable
	bsf		TRISE,2
	movlw	.3
	movff	WREG,battery_type
	return


setup_new_16650:
	banksel	battery_capacity
	clrf	internal_battery_capacity+0
	clrf	internal_battery_capacity+1
	movlw	LOW		ur16650_capacity
	movwf	battery_capacity+0
	movlw	HIGH	ur16650_capacity
	movwf	battery_capacity+1
	movlw	LOW		ur16650_offset
	movwf	battery_offset+0
	movlw	HIGH	ur16650_offset
	movwf	battery_offset+1
	banksel	common
	bcf		charge_disable
	bsf		TRISE,2
	movlw	.4
	movff	WREG,battery_type
	return


use_16650_battery:
	rcall	setup_new_16650
	bra		use_new_36V_2
use_18650_battery:
	rcall	setup_new_18650
	bra		use_new_36V_2
use_new_36V_batteries:
	rcall	setup_new_saft
	bra		use_new_36V_2
use_new_15V_batteries:
	rcall	setup_new_15v
use_new_36V_2:
	call	reset_battery_pointer		; Resets battery pointer 0x07-0x0C and battery_gauge:5
	goto	surfloop					; Jump to Surface loop!
use_36V_rechargeable:
	rcall	setup_new_panasonic
	call	reset_battery_internal_only
	goto	surfloop					; Jump to Surface loop!

	END