;=============================================================================
;
;   File menu_tree.asm								REFACTORED VERSION V2.99e
;
;   OSTC menus
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;   2011-07-11 : [jDG] Creation.

#include "hwos.inc"						; mandatory header
#include "gaslist.inc"
#include "menu_processor.inc"
#include "start.inc"
#include "comm.inc"
#include "logbook.inc"
#include "tft.inc"
#include "eeprom_rs232.inc"
#include "external_flash.inc"
#include "shared_definitions.h"			; mailbox from/to p2_deco.c
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
	extern	option_cleanup_oCCRMode


menu_tree	CODE

;=============================================================================
; Main Menu

do_return_main_menu:
	call	menu_processor_double_pop	; drop exit line and back to last line
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
	bcf		menu_update_sensor_mv		; stop imprinting of live sensor values
	call	option_cleanup_oCCRMode		; in pSCR mode, revert AutoSP (2) to calculated SP (0)

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
		MENU_CALL		tBack,						do_return_main_menu
	MENU_END


do_ccr_menu_cR:							; cR menu
	MENU_BEGIN	tCCRSetup, .7
		MENU_OPTION		tCCRMode,					oCCRMode,				0
		MENU_CALL		tCalibrateMenu,				do_calibrate_menu
		MENU_CALL		tDiluentSetup,				do_diluent_setup
		MENU_CALL		tFixedSetpoints,			do_fixed_setpoints
		MENU_CALL		tPSCRMenu,					do_PSCR_menu
		MENU_OPTION		tCCmaxFracO2,				oCCmaxFracO2,			0
		MENU_CALL		tBack,						do_return_main_menu
	MENU_END

; COMMENTED OUT - currently there is no difference between the OSTC 2 and 3 regarding this menu
;do_ccr_menu_ostc2:
;	MENU_BEGIN	tCCRSetup, .6			; ostc2 menu
;		MENU_OPTION		tCCRMode,					oCCRMode,				0
;		MENU_CALL		tDiluentSetup,				do_diluent_setup
;		MENU_CALL		tFixedSetpoints,			do_fixed_setpoints
;		MENU_CALL		tPSCRMenu,					do_PSCR_menu
;		MENU_OPTION		tCCmaxFracO2,				oCCmaxFracO2,			0
;		MENU_CALL		tBack,						do_return_main_menu
;	MENU_END


do_calibrate_menu:
	call	enable_ir_s8				; enable IR/S8-Port
	bsf		menu_update_sensor_mv		; start imprinting of live sensor values

do_calibrate_menu2:
	MENU_BEGIN	tCalibrateMenu, .6
		MENU_CALL		tDiveHudMask1,				0
		MENU_CALL		tDiveHudMask2,				0
		MENU_CALL		tDiveHudMask3,				0
		MENU_OPTION		tCalibrationGas,oCalGasO2,	0
		MENU_CALL		tCalibrate,					do_calibrate_mix
		MENU_CALL		tBack,						do_return_ccr_menu
	MENU_END


do_calibrate_mix:
	call	calibrate_mix				; calibrate with opt_calibration_O2_ratio, also calibrate S8 HUD if connected
	WAITMS	d'250'						; wait for HUD v3
	movlw	.9
	movff	WREG,customview_surfmode	; show sensor mV custom view after restart
	goto	restart						; restart into surface mode


do_diluent_setup:
	bsf		FLAG_diluent_setup			; setting up diluents
	bcf		short_gas_decriptions		; do not use short versions of gaslist_strcat_gas_cd and gaslist_strcat_setpoint
	bcf		better_gas_hint				; do not mark the best gas/diluent (to be used in dive mode only)
	call	gaslist_cleanup_list		; take care that only one gas can be first

	MENU_BEGIN	tDiluentSetup, .6
		MENU_DYNAMIC	gaslist_strcat_gas_cd,		do_edit_gas_menu
		MENU_DYNAMIC	gaslist_strcat_gas_cd,		do_edit_gas_menu
		MENU_DYNAMIC	gaslist_strcat_gas_cd,		do_edit_gas_menu
		MENU_DYNAMIC	gaslist_strcat_gas_cd,		do_edit_gas_menu
		MENU_DYNAMIC	gaslist_strcat_gas_cd,		do_edit_gas_menu
		MENU_CALL		tBack,						do_return_ccr_menu
	MENU_END


do_return_fixed_setpoints:
	call	menu_processor_double_pop	; drop exit line and back to last line

do_fixed_setpoints:
	bcf		short_gas_decriptions		; =1: use short versions of gaslist_strcat_gas_cd and gaslist_strcat_setpoint
	bcf		better_gas_hint				; do not mark the best gas/diluent (to be used in dive mode only)

	MENU_BEGIN	tFixedSetpoints, .6
		MENU_DYNAMIC	gaslist_strcat_setpoint,	do_edit_sp_menu
		MENU_DYNAMIC	gaslist_strcat_setpoint,	do_edit_sp_menu
		MENU_DYNAMIC	gaslist_strcat_setpoint,	do_edit_sp_menu
		MENU_DYNAMIC	gaslist_strcat_setpoint,	do_edit_sp_menu
		MENU_DYNAMIC	gaslist_strcat_setpoint,	do_edit_sp_menu
		MENU_CALL		tBack,						do_return_ccr_menu
	MENU_END


do_edit_sp_menu:
	movff	PRODL,gaslist_gas			; get menu item we came from (0-4)

	MENU_BEGIN	tFixedSetpoints, .5
		MENU_DYNAMIC	gaslist_strcat_setpoint_0,	0
		MENU_CALL		tSPPlus,					gaslist_spplus
		MENU_CALL		tDepthPlus,					gaslist_spdepthplus
		MENU_CALL		tDepthMinus,				gaslist_spdepthminus
		MENU_CALL		tBack,						do_return_fixed_setpoints
	MENU_END


do_PSCR_menu:
	MENU_BEGIN	tPSCRMenu, .3			; pSCR Menu
		MENU_OPTION		tPSCR_O2_drop,				oPSCR_drop,				0
		MENU_OPTION		tPSCR_lungratio,			oPSCR_lungratio,		0
		MENU_CALL		tBack,						do_return_ccr_menu
	MENU_END

;=============================================================================
; OC Gas Setup

do_return_gas_menu:
	call	menu_processor_double_pop	; drop exit line and back to last line

	btfsc	FLAG_diluent_setup			; return to CCR-Menu?
	bra		do_diluent_setup			; YES

do_gas_menu:
	bcf		FLAG_diluent_setup			; not setting up diluents
	bcf		short_gas_decriptions		; do not use short versions of gaslist_strcat_gas_cd and gaslist_strcat_setpoint
	bcf		better_gas_hint				; do not mark the best gas/diluent (to be used in dive mode only)
	call	gaslist_cleanup_list		; takes care that only one gas can be first

	MENU_BEGIN	tGaslist, .6
		MENU_DYNAMIC	gaslist_strcat_gas_cd,		do_edit_gas_menu
		MENU_DYNAMIC	gaslist_strcat_gas_cd,		do_edit_gas_menu
		MENU_DYNAMIC	gaslist_strcat_gas_cd,		do_edit_gas_menu
		MENU_DYNAMIC	gaslist_strcat_gas_cd,		do_edit_gas_menu
		MENU_DYNAMIC	gaslist_strcat_gas_cd,		do_edit_gas_menu
		MENU_CALL		tBack,						do_return_main_menu
	MENU_END


do_return_edit_gas_menu:
 IFDEF _rx_functions
	bcf		menu_update_tank_pres		; stop imprinting of tank pressure updates
	bcf		FLAG_pairing_mode			; not in pairing menu any more (back to normal timeout)
 ENDIF
	call	menu_processor_pop			; drop exit line and ...
do_abort_gas_depth_menu:
	call	menu_processor_pop			; back to last line
	bra		do_edit_gas_menu_common
do_edit_gas_menu:
	movff	PRODL,gaslist_gas			; get menu item we came from (0-4)
	movlw	.5							; offset between gases and diluents
	btfsc	FLAG_diluent_setup			; in CCR menu?
	addwf	gaslist_gas,F				; YES - add the offset

do_edit_gas_menu_common:
	MENU_BEGIN	tGasEdit, .7
		MENU_DYNAMIC	gaslist_gastitle,			0
		MENU_DYNAMIC	gaslist_MOD_END,			0
		MENU_DYNAMIC	gaslist_show_type,			gaslist_toggle_type
		MENU_CALL		tSetup_GasMix,				do_setup_mix_menu
		MENU_DYNAMIC	gaslist_GasDepth,			do_setup_depth_menu
		MENU_CALL		tSetup_Tank,				do_setup_tank_menu
		MENU_CALL		tBack,						do_return_gas_menu
	MENU_END


do_setup_mix_menu:
	MENU_BEGIN	tGasEdit, .7
		MENU_DYNAMIC	gaslist_gastitle,			0
		MENU_DYNAMIC	gaslist_MOD_END,			0
		MENU_CALL		tO2Plus,					gaslist_pO2
		MENU_CALL		tO2Minus,					gaslist_mO2
		MENU_CALL		tHePlus,					gaslist_pHe
		MENU_CALL		tHeMinus,					gaslist_mHe
		MENU_CALL		tBack,						do_return_edit_gas_menu
	MENU_END


do_setup_tank_menu:
 IFDEF _rx_functions
	btfsc	FLAG_tr_enabled				; TR functions enabled?
	bra		do_setup_tank_menu_rx		; YES
 ENDIF

	MENU_BEGIN	tSetup_Tank, .6
		MENU_DYNAMIC	gaslist_gastitle,			0
		MENU_DYNAMIC	gaslist_tank_size_pres,		0
		MENU_CALL		tTankSize,					gaslist_tank_size
		MENU_CALL		tTankUsablePress,			gaslist_tank_pres
		MENU_CALL		tCopyDilToOC,				gaslist_copy_dil_to_oc
		MENU_CALL		tBack,						do_return_edit_gas_menu
	MENU_END


 IFDEF _rx_functions

do_setup_tank_menu_rx:
	setf	pairing_slot				; prime slot number with 255 aka -1, used in pairing function
	bsf		FLAG_pairing_mode			; in pairing menu (longer timeout)

	MENU_BEGIN	tSetup_Tank, .7
		MENU_DYNAMIC	gaslist_gastitle,			0
		MENU_DYNAMIC	gaslist_tank_id_pres,		0					; when changing position, adopt TFT_menu_tank_pres!
		MENU_DYNAMIC	gaslist_tank_size_pres,		0
		MENU_CALL		tTankPairing,				gaslist_tank_pairing
		MENU_CALL		tTankSize,					gaslist_tank_size
		MENU_CALL		tTankUsablePress,			gaslist_tank_pres
		MENU_CALL		tBack,						do_return_edit_gas_menu
	MENU_END

 ENDIF


do_setup_depth_menu:

	MENU_BEGIN	tGasEdit, .7
		MENU_DYNAMIC	gaslist_gastitle,			0
		MENU_DYNAMIC	gaslist_MOD_END,			0
		MENU_DYNAMIC	gaslist_ppo2,				0					; ppO2 at change depth
		MENU_CALL		tDepthPlus,					gaslist_pDepth
		MENU_CALL		tDepthMinus,				gaslist_mDepth
		MENU_DYNAMIC	gaslist_reset_mod_title,	gaslist_reset_mod
		MENU_CALL		tBack,						do_return_edit_gas_menu
	MENU_END


;=============================================================================
; Simulator Menus

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
	; reset dive time/depth to default values
	lfsr	FSR0,odiveInterval
	call	option_reset
	lfsr	FSR0,obottomTime
	call	option_reset
	lfsr	FSR0,obottomDepth
	call	option_reset
	lfsr	FSR0,oSimAGF
	call	option_reset

do_planner_common:
	movff	opt_dive_mode,WREG			; get dive mode: 0=OC, 1=CCR, 2=Gauge, 3=Apnea, 4=pSCR
	dcfsnz	WREG,W						; subtract one, became zero?
	bra		do_planner_common_ccr		; YES - use CCR version

	MENU_BEGIN	tPlan, .7
		MENU_OPTION		tIntvl,						odiveInterval,			0
		MENU_OPTION		tBtDep,						obottomDepth,			0
		MENU_CALL		tInter,						do_demo_divemode
		MENU_OPTION		tBtTm,						obottomTime,			0
		MENU_OPTION		tuseAGF,					oSimAGF,				0
		MENU_CALL		tDeco,						do_demo_planner
		MENU_CALL		tBack,						do_return_main_menu
	MENU_END

do_planner_common_ccr:
	MENU_BEGIN	tPlan, .7
		MENU_OPTION		tIntvl,						odiveInterval,			0
		MENU_OPTION		tBtDep,						obottomDepth,			0
		MENU_CALL		tInter,						do_demo_divemode
		MENU_OPTION		tBtTm,						obottomTime,			0
		MENU_CALL		tDecoSetup,					do_planner_config
		MENU_CALL		tDeco,						do_demo_planner
		MENU_CALL		tBack,						do_return_main_menu
	MENU_END

do_planner_config:
	MENU_BEGIN	tPlan, .3
		MENU_OPTION		tSelectSetpoint,			oSimSetpoint,			0
		MENU_OPTION		tuseAGF,					oSimAGF,				0
		MENU_CALL		tBack,						do_return_planner_menu
	MENU_END


;=============================================================================
; Divemode Menu

do_return_divemode_menu:
	call	menu_processor_double_pop	; drop exit line and back to last line

do_divemode_menu:
	MENU_BEGIN	tDiveModeMenu, .7
		MENU_OPTION		tDvMode,					oDiveMode,				0
		MENU_OPTION		tDkMode,					oDecoMode,				0
		MENU_CALL		tppO2settings,				do_ppo2_menu
		MENU_OPTION		tsafetystopmenu,			oSafetyStop,			0
		MENU_CALL		tDecoparameters,			do_decoparameters_menu
		MENU_CALL		t2ndDecoPlanMenu,			do_2nd_deco_plan_menu
		MENU_CALL		tBack,						do_return_main_menu
	MENU_END


do_ppo2_menu:
	MENU_BEGIN	tppO2settings, .6
		MENU_DYNAMIC	divesets_ppo2_max,			do_toggle_ppo2_max
		MENU_DYNAMIC	divesets_ppo2_max_deco,		do_toggle_ppo2_max_deco
		MENU_DYNAMIC	divesets_ppo2_min,			do_toggle_ppo2_min
		MENU_DYNAMIC	divesets_ppo2_min_cc,		do_toggle_ppo2_min_cc
		MENU_OPTION		tShowppO2,					oShowppO2,				0
		MENU_CALL		tBack,						do_return_divemode_menu
	MENU_END


do_return_decoparameters_menu:
	call	menu_processor_double_pop	; drop exit line and back to last line

do_decoparameters_menu:
	movff	char_I_deco_model,lo		; 0 = ZH-L16, 1 = ZH-L16-GF
	tstfsz	lo
	bra		do_decoparameters_menu_gf	; <> 0 -> GF menu!
	; NON-GF menu
	MENU_BEGIN	tDecoparameters, .6
		MENU_OPTION		tSetBotUse,					obottom_usage,			0
		MENU_OPTION		tSetDecoUse,				odeco_usage,			0
		MENU_OPTION		tSaturationMult,			osatmult,				0
		MENU_OPTION		tDesaturationMult,			odesatmult,				0
		MENU_CALL		tMore,						do_decoparameters_menu_more
		MENU_CALL		tBack,						do_return_divemode_menu
	MENU_END

do_decoparameters_menu_gf:
	; GF menu
	MENU_BEGIN	tDecoparameters, .7
		MENU_OPTION		tSetBotUse,					obottom_usage,			0
		MENU_OPTION		tSetDecoUse,				odeco_usage,			0
		MENU_CALL		tGFMenu,					do_GF_menu
		MENU_OPTION		tSaturationMult,			osatmultgf,				0
		MENU_OPTION		tDesaturationMult,			odesatmultgf,			0
		MENU_CALL		tMore,						do_decoparameters_menu_more
		MENU_CALL		tBack,						do_return_divemode_menu
	MENU_END


do_decoparameters_menu_more:
	MENU_BEGIN	tDecoparameters, .4
		MENU_OPTION		tLastDecostop,				oLastDeco,				0
		MENU_OPTION		tAscentSpeed,				oAscentSpeed,			0
		MENU_OPTION		tGasChangeTime,				oGasChangeTime,			0
		MENU_CALL		tBack,						do_return_decoparameters_menu
	MENU_END


do_2nd_deco_plan_menu:
	MENU_BEGIN	t2ndDecoPlanMenu, .3
		MENU_OPTION		tFTTSMenu,					oExtraTime,				0
		MENU_OPTION		tCalcAscGas,				oCalcAscGas,			0
		MENU_CALL		tBack,						do_return_divemode_menu
	MENU_END


do_GF_menu:
	MENU_BEGIN	tGFMenu, .6
		MENU_OPTION		tGF_low,					oGF_low,				0
		MENU_OPTION		tGF_high,					oGF_high,				0
		MENU_OPTION		taGF_enable,				oEnable_aGF,			0
		MENU_OPTION		taGF_low,					oaGF_low,				0
		MENU_OPTION		taGF_high,					oaGF_high,				0
		MENU_CALL		tBack,						do_return_decoparameters_menu
	MENU_END


;=============================================================================
; Setup Menu

do_return_settings_deeper:				; entry point for return from set time/date sub-menu
	bcf		settime_setdate				; clear flag
	call	menu_processor_pop			; drop one more stack entry

do_return_settings:
	call	menu_processor_double_pop	; drop exit line and back to last line
 IFDEF _rx_mode
	bcf		FLAG_tr_enabled				; clear TR functions flag by default
	movff	opt_TR_mode,WREG			; get TR functions mode
	tstfsz	WREG						; TR functions enabled?
	bsf		FLAG_tr_enabled				; YES
 ENDIF

do_settings_menu:
	btfsc	ble_available				; ble available?
	bra		do_settings_menu_ble		; YES

	MENU_BEGIN	tSystSets, .5
		MENU_CALL		tInfoMenu,					do_info_menu
		MENU_CALL		tSetTimeDate,				do_date_time_menu
		MENU_CALL		tDispSets,					do_dispsets_menu
		MENU_CALL		tMore,						do_settings_menu_more
		MENU_CALL		tBack,						do_return_main_menu
	MENU_END

do_settings_menu_ble:
 IFDEF _rx_functions
	btfsc	ostc_rx_present				; RX model?
	bra		do_settings_menu_rx			; YES
 ENDIF

	MENU_BEGIN	tSystSets, .6
		MENU_CALL		tInfoMenu,					do_info_menu
		MENU_CALL		tBleTitle,					comm_mode0
		MENU_CALL		tSetTimeDate,				do_date_time_menu
		MENU_CALL		tDispSets,					do_dispsets_menu
		MENU_CALL		tMore,						do_settings_menu_more
		MENU_CALL		tBack,						do_return_main_menu
	MENU_END

 IFDEF _rx_functions
do_settings_menu_rx:
	MENU_BEGIN	tSystSets, .7
		MENU_CALL		tInfoMenu,					do_info_menu
		MENU_CALL		tBleTitle,					comm_mode0
		MENU_CALL		tTrSettings,				do_settings_menu_TR
		MENU_CALL		tSetTimeDate,				do_date_time_menu
		MENU_CALL		tDispSets,					do_dispsets_menu
		MENU_CALL		tMore,						do_settings_menu_more
		MENU_CALL		tBack,						do_return_main_menu
	MENU_END
 ENDIF


do_info_menu:
 IFDEF _rx_functions
	btfsc	ostc_rx_present				; TR model?
	bra		do_info_menu_TR				; YES
 ENDIF

	MENU_BEGIN	tInfoMenu, .6
		MENU_DYNAMIC	info_menu_serial,			0
		MENU_DYNAMIC	info_menu_firmware,			0
		MENU_DYNAMIC	info_menu_battery_volts,	0
		MENU_DYNAMIC	info_menu_uptime,			0
		MENU_DYNAMIC	info_menu_total_dives,		0
		MENU_CALL		tBack,						do_return_settings
	MENU_END

 IFDEF _rx_functions
do_info_menu_TR:
	MENU_BEGIN	tInfoMenu, .7
		MENU_DYNAMIC	info_menu_serial,			0
		MENU_DYNAMIC	info_menu_firmware,			0
		MENU_DYNAMIC	info_menu_firmware_rx,		0
		MENU_DYNAMIC	info_menu_total_dives,		0
		MENU_DYNAMIC	info_menu_battery_volts,	0
		MENU_DYNAMIC	info_menu_uptime,			0
		MENU_CALL		tBack,						do_return_settings
	MENU_END
 ENDIF


 IFDEF _rx_functions
do_settings_menu_TR:
	movff	opt_dive_mode,WREG			; get dive mode: 0=OC, 1=CCR, 2=Gauge, 3=Apnea, 4=pSCR
	incf	WREG,W						; add 1
	dcfsnz	WREG,W						; subtract one, became zero?
	bra		do_settings_menu_TR_MaxDelta; YES - OC
	dcfsnz	WREG,W						; subtract one, became zero?
	bra		do_settings_menu_TR_BailPres; YES - CCR
	dcfsnz	WREG,W						; subtract one, became zero?
	bra		do_settings_menu_TR_MaxDelta; YES - Gauge
	dcfsnz	WREG,W						; subtract one, became zero?
	bra		do_settings_menu_TR_abort	; YES - Apnea, abort
	dcfsnz	WREG,W						; subtract one, became zero?
	bra		do_settings_menu_TR_both	; YES - pSCR
do_settings_menu_TR_abort:
	call	menu_processor_pop			; drop last menu selection
	bra		do_settings_menu			; back to last menu

do_settings_menu_TR_MaxDelta:			; menu with oTrMaxDeltaPres
	MENU_BEGIN	tTrSettings, .5
		MENU_OPTION		tTrMode,					oTrMode,				0
		MENU_OPTION		tTr1stPres,					oTr1stPres,				0
		MENU_OPTION		tTr2ndPres,					oTr2ndPres,				0
		MENU_DYNAMIC	do_toggle_max_pres_diff_label,do_toggle_max_pres_diff
		MENU_CALL		tBack,						do_return_settings
	MENU_END

do_settings_menu_TR_BailPres:			; menu with oTrBailPres
	MENU_BEGIN	tTrSettings, .5
		MENU_OPTION		tTrMode,					oTrMode,				0
		MENU_OPTION		tTr1stPres,					oTr1stPres,				0
		MENU_OPTION		tTr2ndPres,					oTr2ndPres,				0
		MENU_OPTION		tTrBailPres,				oTrBailPres,			0
		MENU_CALL		tBack,						do_return_settings
	MENU_END

do_settings_menu_TR_both:				; menu with oTrBailPres and oTrMaxDeltaPres
	MENU_BEGIN	tTrSettings, .6
		MENU_OPTION		tTrMode,					oTrMode,				0
		MENU_OPTION		tTr1stPres,					oTr1stPres,				0
		MENU_OPTION		tTr2ndPres,					oTr2ndPres,				0
		MENU_OPTION		tTrBailPres,				oTrBailPres,			0
		MENU_DYNAMIC	do_toggle_max_pres_diff_label,do_toggle_max_pres_diff
		MENU_CALL		tBack,						do_return_settings
	MENU_END


do_toggle_max_pres_diff:				; add 5 bar, with hard-coded max.
	movff	char_I_max_pres_diff,lo		; get current value
	movlw	.5							; load increment
	addwf	lo,F						; add increment
	movlw	max_pres_diff_max			; load maximum value
	cpfsgt	lo							; above maximum value?
	bra		do_toggle_max_pres_diff_1	; NO  - store new value
	movlw	max_pres_diff_min			; YES - load minimum value
	movwf	lo							;     - into lo
do_toggle_max_pres_diff_1:
	movff	lo,char_I_max_pres_diff		; write back new value
	return								; done
 ENDIF


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
		MENU_OPTION		tAltMode,					oAltMode,				0	; oder to not mess up the
		MENU_OPTION		tDvSalinity,				oDiveSalinity,			0	; menu stack on doing the
		MENU_CALL		tResetMenu,					do_reset_menu				; do_return_settings !
		MENU_CALL		tBack,						do_return_settings
	MENU_END


do_return_settings_menu_more_pz:
	call	TFT_ClearScreen
	call	piezo_config				; configure buttons
	call	menu_processor_double_pop	; drop exit line and back to last line

do_settings_menu_more_piezo:
	MENU_BEGIN	tSystSets, .7
		MENU_CALL		tCompassMenu,				do_compass_menu				; see above
		MENU_CALL		tLogOffset,					do_log_offset_menu			;
		MENU_OPTION		tAltMode,					oAltMode,				0
		MENU_OPTION		tDvSalinity,				oDiveSalinity,			0
		MENU_CALL		tResetMenu,					do_reset_menu				;
		MENU_CALL		tMore,						do_settings_piezo_menu		;
		MENU_CALL		tBack,						do_return_settings
	MENU_END

do_settings_menu_more_ostc3p:			; menu with BLE feature
	MENU_BEGIN	tSystSets, .6
		MENU_CALL		tCompassMenu,				do_compass_menu				; see above
		MENU_CALL		tLogOffset,					do_log_offset_menu			;
		MENU_OPTION		tAltMode,					oAltMode,				0
		MENU_OPTION		tDvSalinity,				oDiveSalinity,			0
		MENU_CALL		tResetMenu,					do_reset_menu				;
		MENU_CALL		tBack,						do_return_settings
	MENU_END


do_settings_piezo_menu:
	; Menu with features only available in piezo button hardware
	MENU_BEGIN	tSystSets, .3
		MENU_OPTION		tButtonleft,				ocR_button_left,		0		; left  button sensitivity
		MENU_OPTION		tButtonright,				ocR_button_right,		0		; right button sensitivity
		MENU_CALL		tBack,						do_return_settings_menu_more_pz
	MENU_END


do_compass_menu:
	MENU_BEGIN	tSystSets, .5
		MENU_CALL		tCompassMenu,				compass_calibration_loop		; exits to surfloop
;		MENU_OPTION		tCompassGain,				oCompassGain,	0
		MENU_DYNAMIC	menu_cal_x,					0
		MENU_DYNAMIC	menu_cal_y,					0
		MENU_DYNAMIC	menu_cal_z,					0
		MENU_CALL		tBack,						do_return_settings_more
	MENU_END


;=============================================================================
; Reset and confirmation menu

do_reset_menu:
	MENU_BEGIN	tResetMenu, .6
		MENU_CALL		tBack,						do_return_settings_more
		MENU_CALL		tReboot,					do_reset_menu2			; confirm
		MENU_CALL		tResetDeco,					do_reset_menu3			; confirm
		MENU_CALL		tResetSettings,				do_reset_menu4			; confirm
		MENU_CALL		tResetLogbook,				do_reset_menu5			; confirm
		MENU_CALL		tResetBattery,				do_new_battery_menu		; confirm
	MENU_END

do_reset_menu2:
	MENU_BEGIN	tResetMenu2, .2
		MENU_CALL		tAbort,						do_return_settings_more_deeper
		MENU_CALL		tReboot,					do_reboot				; reboot
	MENU_END

do_reset_menu3:
	MENU_BEGIN	tResetMenu2, .2
		MENU_CALL		tAbort,						do_return_settings_more_deeper
		MENU_CALL		tResetDeco,					do_reset_deco			; reset deco
	MENU_END

do_reset_menu4:
	MENU_BEGIN	tResetMenu2, .2
		MENU_CALL		tAbort,						do_return_settings_more_deeper
		MENU_CALL		tResetSettings,				do_reset_settings		; reset all settings
	MENU_END

do_reset_menu5:
	MENU_BEGIN	tResetMenu2, .2
		MENU_CALL		tAbort,						do_return_settings_more_deeper
		MENU_CALL		tResetLogbook,				do_reset_logbook		; reset logbook
	MENU_END


do_reset_logbook:
	clrf	EEADRH						; make sure to select EEPROM bank 0
	clrf	EEDATA
	read_int_eeprom  .2
	write_int_eeprom .16
	read_int_eeprom  .3
	write_int_eeprom .17				; copy number of dives
	clrf	EEDATA
	write_int_eeprom .2
	write_int_eeprom .3					; clear total dives
	write_int_eeprom .4
	write_int_eeprom .5
	write_int_eeprom .6					; reset logbook pointers
	call	ext_flash_erase_logbook		; and complete logbook
	bra		do_return_settings_more_deeper


do_reset_deco:
	SAFE_2BYTE_COPY last_surfpressure_30min,int_I_pres_respiration	; copy surface pressure to deco routine
	SAFE_2BYTE_COPY last_surfpressure_30min,int_I_pres_surface		; copy surface pressure to deco routine

	call	deco_clear_tissue			; set all tissues to Pamb * N2_ratio (C-Code)
	call	deco_calc_dive_interval_1min; calculate deco in surface mode
	call	deco_calc_desaturation_time	; calculate desaturation and no-fly time
	banksel	common
	bra		do_return_settings_more_deeper


do_reset_settings:
	call	TFT_ClearScreen				; clear screen
	call	option_reset_all			; reset all options to factory default
	goto	restart						; restart into surfacemode

do_reboot:
	call	ext_flash_enable_protection	; enables write protection
	reset


do_date_time_menu:
	MENU_BEGIN	tSetTimeDate, .4
		MENU_CALL		tSetTime,					do_time_menu
		MENU_CALL		tSetDate,					do_date_menu
		MENU_OPTION		tDateFormat,oDateFormat,	0
		MENU_CALL		tBack,						do_return_settings
	MENU_END


do_date_menu:
	bsf		settime_setdate

	MENU_BEGIN	tSetDate, .4
		MENU_OPTION		tSetDay,					oSetDay,				0
		MENU_OPTION		tSetMonth,					oSetMonth,				0
		MENU_OPTION		tSetYear,					oSetYear,				0
		MENU_CALL		tBack,						do_return_settings_deeper
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
		MENU_CALL		tBack,						do_return_settings_deeper
	MENU_END


do_toggle_ppo2_max:						; add 0.1 bar, with hard-coded max.
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

do_toggle_ppo2_max_deco:				; add 0.1 bar, with hard-coded max.
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

do_toggle_ppo2_min:						; sub 0.1 bar, with hard-coded min.
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

do_toggle_ppo2_min_cc:					; sub 0.1 bar, with hard-coded min.
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
		MENU_CALL		tBack,						do_return_settings_more
	MENU_END


do_logoffset_minus1:
	call	do_logoffset_common_read	; read into lo:hi
	movlw	.1
	subwf	lo
	movlw	.0
	subwfb	hi
	btfss	hi,7						; < 0 ?
	bra		do_logoffset_exit			; store and return
	clrf	lo
	clrf	hi
	bra		do_logoffset_exit			; store and return

do_logoffset_minus10:
	call	do_logoffset_common_read	; read into lo:hi
	movlw	.10
	subwf	lo
	movlw	.0
	subwfb	hi
	btfss	hi,7						; < 0 ?
	bra		do_logoffset_exit			; store and return
	clrf	lo
	clrf	hi
	bra		do_logoffset_exit			; store and return

do_logoffset_plus1:
	call	do_logoffset_common_read	; read into lo:hi
	infsnz	lo,F
	incf	hi,F
	bra		do_logoffset_exit			; store and return

do_logoffset_plus10:
	call	do_logoffset_common_read	; read into lo:hi
	movlw	.10
	addwf	lo
	movlw	.0
	addwfc	hi
do_logoffset_exit:
	goto	do_logoffset_common_write	; store and return

do_return_dispsets_menu:
	bcf		in_color_menu
	call	menu_processor_double_pop	; drop exit line and back to last line

do_dispsets_menu:

 IF _language_2!=none
	MENU_BEGIN	tDispSets, .7
		MENU_OPTION		tBright,					oBrightness,			0
		MENU_OPTION		tLanguage,					oLanguage,				0
		MENU_OPTION		tUnits,						oUnits,					0
		MENU_CALL		tColorScheme,				do_color_scheme
		MENU_OPTION		tFlip,						oFlipScreen,			0
		MENU_CALL		tMore,						do_dispsets_menu_more
		MENU_CALL		tBack,						do_return_settings
	MENU_END
 ELSE
	MENU_BEGIN	tDispSets, .6
		MENU_OPTION		tBright,					oBrightness,			0
		MENU_OPTION		tUnits,						oUnits,					0
		MENU_CALL		tColorScheme,				do_color_scheme
		MENU_OPTION		tFlip,						oFlipScreen,			0
		MENU_CALL		tMore,						do_dispsets_menu_more
		MENU_CALL		tBack,						do_return_settings
	MENU_END
 ENDIF


do_dispsets_menu_more:
	MENU_BEGIN	tDispSets, .7
		MENU_OPTION		tMODwarning,				oMODwarning,			0
		MENU_OPTION		tIBCDwarning,				oEnable_IBCD,			0
		MENU_OPTION		tVSItext2,					oVSItextv2,				0
		MENU_OPTION		tVSIgraph,					oVSIgraph,				0
		MENU_OPTION		tTimeoutDive,				oDiveTimeout,			0
		MENU_OPTION		t2ndDepth,					o2ndDepthDisp,			0
		MENU_CALL		tBack,						do_return_dispsets_menu
	MENU_END


do_color_scheme:
	bsf		in_color_menu

	MENU_BEGIN	tColorScheme, .2
		MENU_OPTION		tColorSetDive,				oColorSetDive,			0
		MENU_CALL		tBack,						do_return_dispsets_menu
	MENU_END


;=============================================================================

do_new_battery_menu:
	MENU_BEGIN	tNewBattTitle, .2
		MENU_CALL		tAbort,						do_return_settings_more_deeper
		MENU_CALL		tYes,						do_new_battery_select
	MENU_END

	global	do_new_battery_select
do_new_battery_select:

 IFDEF _screendump
	bsf		enable_screen_dumps			; to prevent exiting into COMM mode immediately
 ELSE
	bsf		disable_comm_mode			; to prevent exiting into COMM mode immediately
 ENDIF

	call	TFT_boot					; initialize TFT (includes clear screen)
	call	TFT_Display_FadeIn			; show splash
	movlw	.100
	movwf	batt_percent				; make sure to reset batt_percent

	; Default (in cases of timeout or USB): use old battery
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

	call	menu_processor_reset		; restart from first item

	; hardware_flag1:
	; 3: 0x0A or 0x13 (2016)
	; cR: 0x05
	; 2 with BLE: 0x11
	; Sport: 0x12
	; 3 with BLE: 0x1A 

	movlw   0x0A
	cpfseq  hardware_flag1
	bra	    $+4
	bra	    menu_new_battery_AA
	movlw   0x13
	cpfseq  hardware_flag1
	bra	    $+4
	bra	    menu_new_battery_16650
	movlw   0x33
	cpfseq  hardware_flag1
	bra	    $+4
	bra	    menu_new_battery_AA_16650
	movlw   0x12
	cpfseq  hardware_flag1
	bra	    $+4
	bra	    menu_new_battery_AA
	movlw   0x1A
	cpfseq  hardware_flag1
	bra	    $+4
	bra	    menu_new_battery_AA
	movlw   0x11
	cpfseq  hardware_flag1
	bra	    $+4
	bra	    menu_new_battery_18650
	movlw   0x05
	cpfseq  hardware_flag1
	bra	    $+4
	bra	    menu_new_battery_18650
	bra		use_old_batteries			; any unsupported value

menu_new_battery_16650:
	MENU_BEGIN	tNewBattTitle, .1
		MENU_CALL		tNew16650,					use_16650_battery
	MENU_END
    
menu_new_battery_AA_16650:
	MENU_BEGIN	tNewBattTitle, .5
		MENU_CALL		tNewBattOld,				use_old_batteries
		MENU_CALL		tNewBattNew15,				use_new_15V_batteries
		MENU_CALL		tNewBattNew36,				use_new_36V_batteries
		MENU_CALL		tNewBattAccu,				use_36V_rechargeable
		MENU_CALL		tNew16650,					use_16650_battery
	MENU_END


menu_new_battery_AA:
	MENU_BEGIN	tNewBattTitle, .4
		MENU_CALL		tNewBattOld,				use_old_batteries
		MENU_CALL		tNewBattNew15,				use_new_15V_batteries
		MENU_CALL		tNewBattNew36,				use_new_36V_batteries
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
	incfsz	EEDATA,F					; was 0xFF?
	return								; NO - done

	call	lt2942_get_status			; check for gauge IC
	movlw	.3							; Assume a 18650
	btfss	battery_gauge_available		; cR/2 hardware?
	movlw	.1							; assume a Saft
	movwf	EEDATA
	write_int_eeprom 0x0F				; store the new battery type into EEPROM
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

	rcall	setup_new_saft				; any other value
	incf	EEDATA,F					; 1...5
	dcfsnz	EEDATA,F
	rcall	setup_new_15v				; =0
	dcfsnz	EEDATA,F
	rcall	setup_new_saft				; =1
	dcfsnz	EEDATA,F
	rcall	setup_new_panasonic			; =2
	dcfsnz	EEDATA,F
	rcall	setup_new_18650				; =3
	dcfsnz	EEDATA,F
	rcall	setup_new_16650				; =4

	bcf		use_old_batt_flag			; clear flag

 IFNDEF _screendump
	bcf	disable_comm_mode			; re-enable COMM mode again
 ENDIF

	goto	surfloop					; jump to surface loop


setup_new_15v:
	bsf		charge_disable
	bcf		TRISE,2
	movlw	.100
	movwf	batt_percent				; to have 1.5V batteries right after firmware update
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
	banksel	battery_capacity
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
	bra		use_batt_exit
use_18650_battery:
	rcall	setup_new_18650
	bra		use_batt_exit
use_new_36V_batteries:
	rcall	setup_new_saft
	bra		use_batt_exit
use_new_15V_batteries:
	rcall	setup_new_15v
use_batt_exit:
	call	reset_battery_pointer		; resets battery pointer 0x07-0x0C and battery_gauge:5
use_batt_exit1:

 IFNDEF _screendump
	bcf	disable_comm_mode			; re-enable COMM mode again
 ENDIF

	goto	surfloop					; jump to surface loop

use_36V_rechargeable:
	rcall	setup_new_panasonic
	call	reset_battery_internal_only
	bra		use_batt_exit1				; jump to surface loop

	END