;=============================================================================
;
;   File menu_tree.asm                        next combined generation V3.08.8
;
;   OSTC Surface Menus
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
#include "ghostwriter.inc"
#include "adc_lightsensor.inc"
#include "wait.inc"
#include "i2c.inc"
#include "calibrate.inc"
#include "math.inc"
#include "rtc.inc"


	extern	do_demo_divemode
	extern	restart
	extern	option_check_and_store_all
	extern	option_reset
	extern	do_demo_planner
	extern	comm_mode_ble				; will also set CPU speed to normal
	extern	piezo_config
	extern	option_reset_all
	extern	surfloop
	extern	oColorSetDive
	extern	eeprom_deco_data_write

 IFDEF _ccr_pscr
	extern	option_cleanup_oCCRMode
 ENDIF

 IFDEF _compass
	extern	compass_calibration_loop
 ENDIF


menu_tree	CODE

;-----------------------------------------------------------------------------


;=============================================================================
; Main Menu

do_return_main_menu:
	call	menu_processor_double_pop	; drop exit line and back to last line
	bra		do_main_menu_common

	global	do_main_menu
do_main_menu:
	movff	active_customview,customview_surfmode	; save last custom view
	clrf	MS_flags_imprint						; clear all flags for data imprinting

	global	do_main_menu2
do_main_menu2:										; entry point used by logbook.asm
	call	TFT_boot								; initialize display
	call	menu_processor_reset					; reset menu stack

do_main_menu_common:
 IFDEF _ccr_pscr
	MENU_BEGIN	tMainMenu, .7
		MENU_CALL		tLogbook,					logbook
		MENU_CALL		tGasSetup,					do_gas_menu
		MENU_CALL		tCCRSetup,					do_ccr_menu
		MENU_CALL		tDiveModeMenu,				do_divemode_menu
		MENU_CALL		tSimulator,					do_simulator_menu
		MENU_CALL		tSystSets,					do_settings_menu
		MENU_CALL		tExit,						do_restart
	MENU_END
 ELSE
	MENU_BEGIN	tMainMenu, .6
		MENU_CALL		tLogbook,					logbook
		MENU_CALL		tGasSetup,					do_gas_menu
		MENU_CALL		tDiveModeMenu,				do_divemode_menu
		MENU_CALL		tSimulator,					do_simulator_menu
		MENU_CALL		tSystSets,					do_settings_menu
		MENU_CALL		tExit,						do_restart
	MENU_END
 ENDIF


do_restart:
	bsf		restart_fast				; skip logos and waits an restart
	goto	restart						; restart into surface mode

;=============================================================================
; CCR Setup

 IFDEF _ccr_pscr

do_return_ccr_menu:
	call	menu_processor_double_pop	; drop exit line and back to last line

do_ccr_menu:
	call	option_cleanup_oCCRMode		; in pSCR mode, revert AutoSP (2) to calculated SP (0)

 IFDEF _external_sensor
	bcf		imprint_sensor_mv			; stop imprinting of live O2 sensor mV data
	btfsc	analog_o2_input
	bra		do_ccr_menu_cR
 ENDIF

	MENU_BEGIN	tCCRSetup, .5			; OSTC3 menu (and currently also the OSTC2 menu)
		MENU_OPTION		tCCRMode,					oCCRMode,				0
		MENU_CALL		tDiluentSetup,				do_diluent_setup
		MENU_CALL		tFixedSetpoints,			do_fixed_setpoints
		MENU_CALL		tMore,						do_ccr_menu_more
		MENU_CALL		tBack,						do_return_main_menu
	MENU_END


 IFDEF _external_sensor

do_ccr_menu_cR:							; cR menu
	MENU_BEGIN	tCCRSetup, .6
		MENU_OPTION		tCCRMode,					oCCRMode,				0
		MENU_CALL		tCalibrateMenu,				do_calibrate_menu
		MENU_CALL		tDiluentSetup,				do_diluent_setup
		MENU_CALL		tFixedSetpoints,			do_fixed_setpoints
		MENU_CALL		tMore,						do_ccr_menu_more
		MENU_CALL		tBack,						do_return_main_menu
	MENU_END


do_calibrate_menu:
	call	enable_ir_s8				; enable IR/S8-Port
	bsf		imprint_sensor_mv			; start imprinting of live O2 sensor mV data

do_calibrate_menu2:
	MENU_BEGIN	tCalibrateMenu, .6
		MENU_CALL		tDiveHudMask1,				0
		MENU_CALL		tDiveHudMask2,				0
		MENU_CALL		tDiveHudMask3,				0
		MENU_OPTION		tCalibrationGas,			oCalGasO2,				0
		MENU_CALL		tCalibrate,					do_calibrate_mix
		MENU_CALL		tBack,						do_return_ccr_menu
	MENU_END


do_calibrate_mix:
	call	calibrate_mix				; calibrate with opt_calibration_O2_ratio, also calibrate S8 HUD if connected
	WAITMS	d'250'						; wait for HUD v3
	movlw	.9
	movff	WREG,customview_surfmode	; show sensor mV custom view after restart
	bsf		restart_fast				; skip logos and waits an restart
	goto	restart						; restart into surface mode

 ENDIF	; _external_sensor


do_diluent_setup:
	bsf		is_diluent_menu				; setting up diluents
	bcf		short_gas_descriptions		; do not use short versions of gaslist_strcat_gas_cd and gaslist_strcat_setpoint
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
	bcf		short_gas_descriptions		; =1: use short versions of gaslist_strcat_gas_cd and gaslist_strcat_setpoint
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


do_ccr_menu_more:
 IFDEF _external_sensor
	MENU_BEGIN	tCCRSetup, .6			; CCR/pSCR more menu
		MENU_OPTION		tS8Mode,					oS8Mode,				0
		MENU_OPTION		tCCmaxFracO2,				oCCmaxFracO2,			0
		MENU_OPTION		tDilppO2Check,				oDilppO2Check,			0
		MENU_OPTION		tPSCR_O2_drop,				oPSCR_drop,				0
		MENU_OPTION		tPSCR_lungratio,			oPSCR_lungratio,		0
		MENU_CALL		tBack,						do_return_ccr_menu
	MENU_END
 ELSE
	MENU_BEGIN	tCCRSetup, .5			; CCR/pSCR more menu
		MENU_OPTION		tCCmaxFracO2,				oCCmaxFracO2,			0
		MENU_OPTION		tDilppO2Check,				oDilppO2Check,			0
		MENU_OPTION		tPSCR_O2_drop,				oPSCR_drop,				0
		MENU_OPTION		tPSCR_lungratio,			oPSCR_lungratio,		0
		MENU_CALL		tBack,						do_return_ccr_menu
	MENU_END
 ENDIF	; _external_sensor

 ENDIF	; _ccr_pscr

;=============================================================================
; OC Gas Setup

do_return_gas_menu:
	call	menu_processor_double_pop	; drop exit line and back to last line

 IFDEF _ccr_pscr
	btfsc	is_diluent_menu				; return from setting up diluents?
	bra		do_diluent_setup			; YES
 ENDIF

do_gas_menu:
	bcf		is_diluent_menu				; setting up OC gases
	bcf		short_gas_descriptions		; do not use short versions of gaslist_strcat_gas_cd and gaslist_strcat_setpoint
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
	bcf		imprint_xmitter_pres		; stop imprinting of transmitter pressure data
	bcf		imprint_xmitter_ID			; not in transmitter selection menu any more (back to normal timeout)
 ENDIF
	call	menu_processor_double_pop	;  drop exit line and back to last line
	bra		do_edit_gas_menu_common

do_edit_gas_menu:
	movff	PRODL,gaslist_gas			; get menu item we came from (0-4)
	movlw	.5							; offset between gases and diluents
	btfsc	is_diluent_menu				; setting up diluents?
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
 IFDEF _helium
	MENU_BEGIN	tGasEdit, .7
		MENU_DYNAMIC	gaslist_gastitle,			0
		MENU_DYNAMIC	gaslist_MOD_END,			0
		MENU_CALL		tO2Plus,					gaslist_pO2
		MENU_CALL		tO2Minus,					gaslist_mO2
		MENU_CALL		tHePlus,					gaslist_pHe
		MENU_CALL		tHeMinus,					gaslist_mHe
		MENU_CALL		tBack,						do_return_edit_gas_menu
	MENU_END
 ELSE
	MENU_BEGIN	tGasEdit, .5
		MENU_DYNAMIC	gaslist_gastitle,			0
		MENU_DYNAMIC	gaslist_MOD_END,			0
		MENU_CALL		tO2Plus,					gaslist_pO2
		MENU_CALL		tO2Minus,					gaslist_mO2
		MENU_CALL		tBack,						do_return_edit_gas_menu
	MENU_END
 ENDIF


do_setup_tank_menu:
 IFDEF _rx_functions
	TSTOSC	opt_TR_mode					; TR functions switched on?
	bra		do_setup_tank_menu_rx		; YES
 ENDIF

 IFDEF _ccr_pscr
	MENU_BEGIN	tSetup_Tank, .6
		MENU_DYNAMIC	gaslist_gastitle,			0
		MENU_DYNAMIC	gaslist_tank_size_pres,		0
		MENU_CALL		tTankSize,					gaslist_tank_size
		MENU_CALL		tTankUsablePress,			gaslist_tank_pres
		MENU_CALL		tCopyDilToOC,				gaslist_copy_dil_to_oc
		MENU_CALL		tBack,						do_return_edit_gas_menu
	MENU_END
 ELSE
	MENU_BEGIN	tSetup_Tank, .5
		MENU_DYNAMIC	gaslist_gastitle,			0
		MENU_DYNAMIC	gaslist_tank_size_pres,		0
		MENU_CALL		tTankSize,					gaslist_tank_size
		MENU_CALL		tTankUsablePress,			gaslist_tank_pres
		MENU_CALL		tBack,						do_return_edit_gas_menu
	MENU_END
 ENDIF


 IFDEF _rx_functions
do_setup_tank_menu_rx:
	setf	pairing_slot				; prime slot number with 255 aka -1, used in pairing function
	bsf		imprint_xmitter_ID			; in transmitter selection menu (longer timeout)

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
	call	menu_processor_double_pop	; drop exit line and back to last line
	bra		do_planner_common_1

	global	do_return_demo_planner
do_return_demo_planner:
	call	menu_processor_pop			; back to last line
	bra		do_planner_common

do_simulator_menu:
	; reset planning parameters to default values
	lfsr	FSR0,odiveInterval
	call	option_reset
	lfsr	FSR0,obottomTime
	call	option_reset
	lfsr	FSR0,obottomDepth
	call	option_reset
	lfsr	FSR0,oSimAGF
	call	option_reset

 IFDEF _gas_contingency
	; switch off gas contingency mode by default when entering the simulator menu
	clrf	WREG
	movff	WREG,opt_gas_contingency_sim
 ENDIF

do_planner_common:
	call	restart_set_modes_and_flags	; initialize dive mode settings
do_planner_common_1:
	movff	opt_dive_mode,WREG			; get dive mode: 0=OC, 1=CCR, 2=Gauge, 3=Apnea, 4=pSCR
	dcfsnz	WREG,W						; subtract one, became zero?
	bra		do_planner_common_ccr		; YES - use CCR version

	MENU_BEGIN	tSimulator, .7
		MENU_OPTION		tIntvl,						odiveInterval,			0
		MENU_OPTION		tBtDep,						obottomDepth,			0
		MENU_CALL		tInter,						do_demo_divemode
		MENU_OPTION		tBtTm,						obottomTime,			0
		MENU_OPTION		tuseAGF,					oSimAGF,				0
		MENU_CALL		tDeco,						do_demo_planner
		MENU_CALL		tBack,						do_return_main_menu
	MENU_END

do_planner_common_ccr:
	MENU_BEGIN	tSimulator, .7
		MENU_OPTION		tIntvl,						odiveInterval,			0
		MENU_OPTION		tBtDep,						obottomDepth,			0
		MENU_CALL		tInter,						do_demo_divemode
		MENU_OPTION		tBtTm,						obottomTime,			0
		MENU_CALL		tCalculatorSetup,			do_planner_config
		MENU_CALL		tDeco,						do_demo_planner
		MENU_CALL		tBack,						do_return_main_menu
	MENU_END

do_planner_config:
 IFDEF _gas_contingency
	MENU_BEGIN	tSimulator, .4
		MENU_OPTION		tSelectSetpoint,			oSimSetpoint,			0
		MENU_OPTION		tuseAGF,					oSimAGF,				0
		MENU_OPTION		tGasContingencySim,			oGasContingencySim,		0
		MENU_CALL		tBack,						do_return_planner_menu
	MENU_END
 ELSE
	MENU_BEGIN	tSimulator, .3
		MENU_OPTION		tSelectSetpoint,			oSimSetpoint,			0
		MENU_OPTION		tuseAGF,					oSimAGF,				0
		MENU_CALL		tBack,						do_return_planner_menu
	MENU_END
 ENDIF


;=============================================================================
; Divemode Menu

do_return_divemode_menu:
	call	menu_processor_double_pop	; drop exit line and back to last line

do_divemode_menu:
	MENU_BEGIN	tDiveModeMenu, .6
		MENU_CALL		tDiveSetup,					do_dive_menu				; dive setup
		MENU_CALL		tDecoSetup,					do_deco_menu				; deco setup
		MENU_CALL		tSACSetup,					do_SAC_menu					; SAC  setup
		MENU_CALL		tppO2Setup,					do_ppo2_menu				; ppO2 limits
		MENU_CALL		tStopsSetup,				do_stops_menu				; stops setup
		MENU_CALL		tBack,						do_return_main_menu
	MENU_END


do_dive_menu:
 IFDEF _cave_mode
	MENU_BEGIN	tDiveModeMenu, .6
		MENU_OPTION		tDvMode,					oDiveMode,				0	; dive mode
		MENU_OPTION		tCvMode,					oCaveMode,				0	; cave mode
		MENU_OPTION		tFTTSMenu,					oExtraTime,				0	; fTTS/delay
		MENU_OPTION		tTimeoutDive,				oDiveTimeout,			0	; dive timeout
		MENU_OPTION		tStoreApnoeDive,			oStoreApnoe,			0	; store apnoe
		MENU_CALL		tBack,						do_return_divemode_menu
	MENU_END
 ELSE
	MENU_BEGIN	tDiveModeMenu, .5
		MENU_OPTION		tDvMode,					oDiveMode,				0	; dive mode
		MENU_OPTION		tFTTSMenu,					oExtraTime,				0	; fTTS/delay
		MENU_OPTION		tTimeoutDive,				oDiveTimeout,			0	; dive timeout
		MENU_OPTION		tStoreApnoeDive,			oStoreApnoe,			0	; store apnoe
		MENU_CALL		tBack,						do_return_divemode_menu
	MENU_END
 ENDIF


do_return_deco_menu:
	call	menu_processor_double_pop	; drop exit line and back to last line

do_deco_menu:
	MENU_BEGIN	tDecoSetup, .6
		MENU_OPTION		tDkMode,					oDecoMode,				0	; ZH-L16 /GF
		MENU_OPTION		tSaturationMult,			osatmultgf,				0	; saturation
		MENU_OPTION		tDesaturationMult,			odesatmultgf,			0	; desaturation
		MENU_OPTION		tAltMode,					oAltMode,				0	; altitude mode
		MENU_CALL		tGFMenu,					do_GF_menu					; GF settings
		MENU_CALL		tBack,						do_return_divemode_menu
	MENU_END


do_SAC_menu:
 IFDEF _gas_contingency
	MENU_BEGIN	tSACSetup, .6
		MENU_OPTION		tCalcGasNeeds,				oCalcAscGas,			0	; calc.gas
		MENU_OPTION		tGasContingencyDive,		oGasContingencyDive,	0	; switch tank if used up
		MENU_OPTION		tGasChangeTime,				oGasChangeTime,			0	; gas change time
		MENU_OPTION		tSetWorkSAC,				oWork_SAC,				0	; work SAC
		MENU_OPTION		tSetDecoSAC,				oDeco_SAC,				0	; deco SAC
		MENU_CALL		tBack,						do_return_divemode_menu
	MENU_END
 ELSE
	MENU_BEGIN	tSACSetup, .5
		MENU_OPTION		tCalcGasNeeds,				oCalcAscGas,			0	; calc.gas
		MENU_OPTION		tGasChangeTime,				oGasChangeTime,			0	; gas change time
		MENU_OPTION		tSetWorkSAC,				oWork_SAC,				0	; work SAC
		MENU_OPTION		tSetDecoSAC,				oDeco_SAC,				0	; deco SAC
		MENU_CALL		tBack,						do_return_divemode_menu
	MENU_END
 ENDIF


do_ppo2_menu:
 IFDEF _ccr_pscr
 IFDEF _helium
	MENU_BEGIN	tppO2Setup, .6
		MENU_DYNAMIC	divesets_ppo2_max,			do_toggle_ppo2_max_work		; max work
		MENU_DYNAMIC	divesets_ppo2_max_deco,		do_toggle_ppo2_max_deco		; max deco
		MENU_DYNAMIC	divesets_ppo2_min,			do_toggle_ppo2_min			; min OC
		MENU_DYNAMIC	divesets_ppo2_min_cc,		do_toggle_ppo2_min_cc		; min loop
		MENU_OPTION		tIBCDwarning,				oEnable_IBCD,			0	; IBCD warning
		MENU_CALL		tBack,						do_return_divemode_menu
	MENU_END
 ELSE
	MENU_BEGIN	tppO2Setup, .5
		MENU_DYNAMIC	divesets_ppo2_max,			do_toggle_ppo2_max_work		; max work
		MENU_DYNAMIC	divesets_ppo2_max_deco,		do_toggle_ppo2_max_deco		; max deco
		MENU_DYNAMIC	divesets_ppo2_min,			do_toggle_ppo2_min			; min OC
		MENU_DYNAMIC	divesets_ppo2_min_cc,		do_toggle_ppo2_min_cc		; min loop
		MENU_CALL		tBack,						do_return_divemode_menu
	MENU_END
 ENDIF	; _helium
 ELSE
 IFDEF _helium
	MENU_BEGIN	tppO2Setup, .5
		MENU_DYNAMIC	divesets_ppo2_max,			do_toggle_ppo2_max_work		; max work
		MENU_DYNAMIC	divesets_ppo2_max_deco,		do_toggle_ppo2_max_deco		; max deco
		MENU_DYNAMIC	divesets_ppo2_min,			do_toggle_ppo2_min			; min OC
		MENU_OPTION		tIBCDwarning,				oEnable_IBCD,			0	; IBCD warning
		MENU_CALL		tBack,						do_return_divemode_menu
 ELSE
	MENU_BEGIN	tppO2Setup, .4
		MENU_DYNAMIC	divesets_ppo2_max,			do_toggle_ppo2_max_work		; max work
		MENU_DYNAMIC	divesets_ppo2_max_deco,		do_toggle_ppo2_max_deco		; max deco
		MENU_DYNAMIC	divesets_ppo2_min,			do_toggle_ppo2_min			; min OC
		MENU_CALL		tBack,						do_return_divemode_menu
	MENU_END
 ENDIF	; _helium
 ENDIF	; _ccr_pscr


do_stops_menu:
	MENU_BEGIN	tStopsSetup, .6
		MENU_OPTION		tSafetyStop,				oSafetyStop,			0	; safety stop
		MENU_OPTION		tExtendedStops,				oExtendedStops,			0	; extended stops
		MENU_OPTION		tLastDecostop,				oLastDeco,				0	; last deco stop
		MENU_OPTION		tDvSalinity,				oDiveSalinity,			0	; salinity
		MENU_OPTION		tDepthWarn,					oMaxDepth,				0	; depth limit
		MENU_CALL		tBack,						do_return_divemode_menu
	MENU_END


do_GF_menu:
	MENU_BEGIN	tGFMenu, .6
		MENU_OPTION		tGF_low,					oGF_low,				0	; GF  low
		MENU_OPTION		tGF_high,					oGF_high,				0	; GF  high
		MENU_OPTION		taGFenable,					oEnable_aGF,			0	; aGF selectable
		MENU_OPTION		taGF_low,					oaGF_low,				0	; aGF low
		MENU_OPTION		taGF_high,					oaGF_high,				0	; aGF high
		MENU_CALL		tBack,						do_return_deco_menu
	MENU_END


;=============================================================================
; Setup Menu
do_return_settings_deeper:				; entry point for return from info menu 2
	call	menu_processor_pop			; drop one more stack entry

do_return_settings:
	bcf		imprint_time_date			; stop imprinting of current time & date
	call	menu_processor_double_pop	; drop exit line and back to last line

 IFDEF _rx_mode
	bcf		tr_functions_activated		; set TR functions as deactivated by default
	btfss	ostc_rx_present				; TR model / TR module up & running?
	bra		do_settings_menu			; NO  - use version w/o TR
	movff	opt_TR_mode,WREG			; YES - get TR mode
	tstfsz	WREG						;     - TR mode <> off ?
	bsf		tr_functions_activated		;       YES - set TR functions as activated
 ENDIF

do_settings_menu:
 IFDEF _hwos_sport
	bsf		ble_available				; for very old OSTC sport
 ENDIF
	btfsc	ble_available				; BLE available?
	bra		do_settings_menu_ble		; YES

	MENU_BEGIN	tSystSets, .5
		MENU_CALL		tInfoMenu,					do_info_menu
		MENU_CALL		tSetTimeDate,				do_date_time_menu
		MENU_CALL		tDispSets,					do_dispsets_menu
		MENU_CALL		tSysSets,					do_syssets_menu
		MENU_CALL		tBack,						do_return_main_menu
	MENU_END


do_settings_menu_ble:
 IFDEF _rx_functions
	btfss	ostc_rx_present				; TR model and TR activated?
	bra		do_settings_menu_noRX		; NO

	MENU_BEGIN	tSystSets, .7
		MENU_CALL		tInfoMenu,					do_info_menu
		MENU_CALL		tBleTitle,					comm_mode_ble
		MENU_CALL		tTrSettings,				do_settings_menu_TR
		MENU_CALL		tSetTimeDate,				do_date_time_menu
		MENU_CALL		tDispSets,					do_dispsets_menu
		MENU_CALL		tSysSets,					do_syssets_menu
		MENU_CALL		tBack,						do_return_main_menu
	MENU_END
 ENDIF

do_settings_menu_noRX:
	MENU_BEGIN	tSystSets, .6
		MENU_CALL		tInfoMenu,					do_info_menu
		MENU_CALL		tBleTitle,					comm_mode_ble
		MENU_CALL		tSetTimeDate,				do_date_time_menu
		MENU_CALL		tDispSets,					do_dispsets_menu
		MENU_CALL		tSysSets,					do_syssets_menu
		MENU_CALL		tBack,						do_return_main_menu
	MENU_END


do_info_menu:
 IFDEF _rx_functions
	btfss	ostc_rx_present				; TR model?
	bra		do_info_menu_noRX			; NO

	MENU_BEGIN	tInfoMenu, .7
		MENU_DYNAMIC	info_menu_uptime,			0
		MENU_DYNAMIC	info_menu_serial,			0
		MENU_DYNAMIC	info_menu_firmware,			0
		MENU_DYNAMIC	info_menu_fw_cration_date,	0
		MENU_DYNAMIC	info_menu_firmware_rx,		0
		MENU_DYNAMIC	info_menu_total_dives,		0
		MENU_CALL		tMore,						do_info_menu2
	MENU_END
 ENDIF

do_info_menu_noRX:
	MENU_BEGIN	tInfoMenu, .6
		MENU_DYNAMIC	info_menu_uptime,			0
		MENU_DYNAMIC	info_menu_serial,			0
		MENU_DYNAMIC	info_menu_firmware,			0
		MENU_DYNAMIC	info_menu_fw_cration_date,	0
		MENU_DYNAMIC	info_menu_total_dives,		0
		MENU_CALL		tMore,						do_info_menu2
	MENU_END

do_info_menu2:
	MENU_BEGIN	tInfoMenu, .5
		MENU_DYNAMIC	info_menu_battery_volts,	0
		MENU_DYNAMIC	info_menu_config,			0
		MENU_DYNAMIC	info_menu_sensor_calib,		0
		MENU_DYNAMIC	info_menu_sensor_offset,	0
		MENU_CALL		tBack,						do_return_settings_deeper
	MENU_END


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

 ENDIF	; _rx_functions


do_return_settings_more_deeper:			; entry point for returns from reset sub-menu
	call	menu_processor_pop			; drop one more stack entry

do_return_settings_more:
	call	menu_processor_double_pop	; drop exit line and back to last line

do_syssets_menu:
	btfsc	battery_gauge_available		; piezo buttons available?
	bra		do_syssets_menu_piezo		; YES

 IFDEF _compass
	MENU_BEGIN	tSystSets, .4													; All MENU_CALLs in this menu
		MENU_CALL		tCompassMenu,				do_compass_menu				; need to stay together on this
		MENU_CALL		tLogOffset,					do_log_offset_menu			; menu level in order to not
		MENU_CALL		tResetMenu,					do_reset_menu				; mess up the menu stack on doing
		MENU_CALL		tBack,						do_return_settings			; the do_return_settings !
	MENU_END
 ELSE
	MENU_BEGIN	tSystSets, .3													; see above
		MENU_CALL		tLogOffset,					do_log_offset_menu			;
		MENU_CALL		tResetMenu,					do_reset_menu				;
		MENU_CALL		tBack,						do_return_settings			;
	MENU_END
 ENDIF	; _compass


do_return_syssets_menu_piezo:
	call	TFT_ClearScreen
	call	piezo_config				; configure buttons
	call	menu_processor_double_pop	; drop exit line and back to last line

do_syssets_menu_piezo:
 IFDEF _compass
	MENU_BEGIN	tSystSets, .6
		MENU_CALL		tCompassMenu,				do_compass_menu				; see above
		MENU_CALL		tLogOffset,					do_log_offset_menu			;
		MENU_DYNAMIC	info_menu_total_dives,		0
		MENU_CALL		tResetMenu,					do_reset_menu				;
		MENU_CALL		tPiezo,						do_settings_piezo_menu		;
		MENU_CALL		tBack,						do_return_settings			;
	MENU_END
 ELSE
	MENU_BEGIN	tSystSets, .5
		MENU_CALL		tLogOffset,					do_log_offset_menu			; see above
		MENU_DYNAMIC	info_menu_total_dives,		0
		MENU_CALL		tResetMenu,					do_reset_menu				;
		MENU_CALL		tPiezo,						do_settings_piezo_menu		;
		MENU_CALL		tBack,						do_return_settings			;
	MENU_END
 ENDIF


do_settings_piezo_menu:
	; Menu with features only available in piezo button hardware
	MENU_BEGIN	tPiezo, .3
		MENU_OPTION		tButtonleft,				ocR_button_left,		0		; left  button sensitivity
		MENU_OPTION		tButtonright,				ocR_button_right,		0		; right button sensitivity
		MENU_CALL		tBack,						do_return_syssets_menu_piezo
	MENU_END


 IFDEF _compass

do_compass_menu:
	MENU_BEGIN	tCompassMenu, .5
		MENU_CALL		tCompassMenu,				compass_calibration_loop	; exits to surface loop
;		MENU_OPTION		tCompassGain,				oCompassGain,	0
		MENU_DYNAMIC	menu_cal_x,					0
		MENU_DYNAMIC	menu_cal_y,					0
		MENU_DYNAMIC	menu_cal_z,					0
		MENU_CALL		tBack,						do_return_settings_more
	MENU_END

 ENDIF	; _compass


;=============================================================================
; Reset and confirmation menu

do_reset_menu:
	MENU_BEGIN	tResetMenu, .6
		MENU_CALL		tBack,						do_return_settings_more
		MENU_CALL		tReboot,					do_reset_menu_reboot	; confirm
		MENU_CALL		tResetDeco,					do_reset_menu_deco		; confirm
		MENU_CALL		tResetSettings,				do_reset_menu_settings	; confirm
		MENU_CALL		tResetLogbook,				do_reset_menu_logbook	; confirm
		MENU_CALL		tResetBattery,				do_new_battery_menu		; confirm
	MENU_END

do_reset_menu_reboot:
	MENU_BEGIN	tResetMenu2, .2
		MENU_CALL		tAbort,						do_return_settings_more_deeper
		MENU_CALL		tReboot,					do_reboot				; reboot (cold start)
	MENU_END

do_reset_menu_deco:
	MENU_BEGIN	tResetMenu2, .2
		MENU_CALL		tAbort,						do_return_settings_more_deeper
		MENU_CALL		tResetDeco,					do_reset_deco			; reset deco and return to main reset menu
	MENU_END

do_reset_menu_settings:
	MENU_BEGIN	tResetMenu2, .2
		MENU_CALL		tAbort,						do_return_settings_more_deeper
		MENU_CALL		tResetSettings,				do_reset_settings		; reset all settings and go to surface mode
	MENU_END

do_reset_menu_logbook:
	MENU_BEGIN	tResetMenu2, .2
		MENU_CALL		tAbort,						do_return_settings_more_deeper
		MENU_CALL		tResetLogbook,				do_reset_logbook		; reset logbook and return to main reset menu
	MENU_END


do_reset_logbook:
	call	erase_complete_logbook			; erase complete logbook
	bra		do_return_settings_more_deeper

do_reset_deco:
	call	deco_clear_tissue				; set all tissues to absolute pressure * N2_ratio           (C-code)
	call	deco_calc_dive_interval_1min	; update tissues by 1 minute to calculate current GF factor (C-code)
	call	deco_calc_desaturation_time		; calculate desaturation and no-fly/no-altitude time        (C-code)
	banksel	common
	call	eeprom_deco_data_write		; store updated deco data into EEPROM
	bra		do_return_settings_more_deeper


do_reset_settings:
	call	TFT_ClearScreen				; clear screen to show start of activity
	call	option_reset_all			; reset all options to factory default
	call	do_logoffset_reset			; reset log offset
	goto	restart						; restart into surface mode

do_reboot:
	call	ext_flash_enable_protection	; set write protection on external flash
	call	eeprom_deco_data_write		; update deco data     in EEPROM
	call	eeprom_battery_gauge_write	; update battery gauge in EEPROM
	btfsc	options_changed				; do the options need to be stored to EEPROM ?
	call	option_check_and_store_all	; YES - check and store all option values in EEPROM
	reset								; cold-start the processor

do_return_date_time_menu:
	call	menu_processor_double_pop	; drop exit line and back to last line

do_date_time_menu:
	bsf		imprint_time_date			; start imprinting current time & date
	bcf		block_option_value			; allow display of option values again

	MENU_BEGIN	tSetTimeDate, .4
		MENU_CALL		tSetTime,					do_time_menu
		MENU_CALL		tSetDate,					do_date_menu
		MENU_OPTION		tDateFormat,				oDateFormat,			0
		MENU_CALL		tBack,						do_return_settings
	MENU_END


do_date_menu:
	bsf		block_option_value			; suspend display of option values

	MENU_BEGIN	tSetDate, .4
		MENU_OPTION		tSetDay,					oSetDay,				0
		MENU_OPTION		tSetMonth,					oSetMonth,				0
		MENU_OPTION		tSetYear,					oSetYear,				0
		MENU_CALL		tBack,						do_return_date_time_menu
	MENU_END


do_time_menu:
	bsf		block_option_value			; suspend display of option values

	MENU_BEGIN	tSetTime, .4
		MENU_OPTION		tSetHours,					oSetHours,				0
		MENU_OPTION		tSetMinutes,				oSetMinutes,			0
		MENU_OPTION		tSetSeconds,				oClearSeconds,			0
		MENU_CALL		tBack,						do_return_date_time_menu
	MENU_END


do_toggle_ppo2_max_work:				; add 0.1 bar
	movff	char_I_ppO2_max_work,lo		; bank-safe copy
	movlw	.10
	addwf	lo,F
	movlw	ppo2_warning_high_highest
	cpfsgt	lo
	bra		do_toggle_ppo2_max2
	movlw	ppo2_warning_high_lowest
	movwf	lo
do_toggle_ppo2_max2:
	movff	lo,char_I_ppO2_max_work
	return

do_toggle_ppo2_max_deco:				; add 0.1 bar
	movff	char_I_ppO2_max_deco,lo		; bank-safe copy
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

do_toggle_ppo2_min:						; sub 0.1 bar
	movff	char_I_ppO2_min,lo			; bank-safe copy
	incf	lo,F
	movlw	ppo2_warning_low_highest
	cpfsgt	lo
	bra		do_toggle_ppo2_min2
	movlw	ppo2_warning_low_lowest
	movwf	lo
do_toggle_ppo2_min2:
	movff	lo,char_I_ppO2_min
	return

do_toggle_ppo2_min_cc:					; sub 0.1 bar
	movff	char_I_ppO2_min_loop,lo		; bank-safe copy
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

	clrf	WREG						; select an initial step size of 1
	movff	WREG,opt_logoffset_step		; bank-safe write to option variable

	MENU_BEGIN	tLogOffset, .5
		MENU_DYNAMIC	TFT_LogOffset,				0
		MENU_OPTION		tLogOffStepSize,			oLogOffsetStep,				0
		MENU_CALL		tLogOffsetplus,				do_logoffset_plus
		MENU_CALL		tLogOffsetminus,			do_logoffset_minus
		MENU_CALL		tBack,						do_return_settings_more
	MENU_END


do_logoffset_common:
	call	eeprom_log_offset_read		; read current offset into mpr+1:mpr+0
	movff	opt_logoffset_step,ul		; get step size: 0=1, 1=10, 2=100, 3=1000
	incf	ul,F						; 0...3 -> 1...4
	clrf	mpr+3						; clear   step size, high byte
	movlw	.1							; set a step size of 1
	movwf	mpr+2						; copy to step size, low  byte
	dcfsnz	ul,F						; ul--, did ul became 0, i.e. step size = 1 ?
	return								; YES - done
	movlw	.10							; NO  - set a step size of 10
	movwf	mpr+2						;     - copy to step size, low  byte
	dcfsnz	ul,F						; ul--, did ul became 0, i.e. step size = 10 ?
	return								; YES - done
	movlw	.100						; NO  - set a step size of 100
	movwf	mpr+2						;     - copy to step size, low  byte
	dcfsnz	ul,F						; ul--, did ul became 0, i.e. step size = 100 ?
	return								; YES - done
	movlw	LOW .1000					; NO  - set a step size of 1000, low byte
	movwf	mpr+2						;     - copy to step size,      low  byte
	movlw	HIGH .1000					;     - set a step size of 1000, high byte
	movwf	mpr+3						;     - copy to step size,       high byte
	return								;     - done

do_logoffset_plus:
	rcall	do_logoffset_common			; load current offset and step size
	; add step size to current offset
	movf	mpr+2,W						; get step size, low  byte
	addwf	mpr+0,F						; add to offset, low  byte
	movf	mpr+3,W						; get step size, high byte
	addwfc	mpr+1,F						; add to offset, high byte, considering carry flag
	; check if new offset is within limit
	MOVLI	.9999,sub_a					; load max limit  into sub_a
	MOVII	mpr,  sub_b					; copy new offset into sub_b
	call	cmpU16						; compute sub_a - sub_b, setting neg_flag if result becomes negative
	btfss	neg_flag					; neg_flag set, i.e. new offset > 9999 ?
	bra		do_logoffset_exit			; NO  - store offset and return
	MOVLI	.9999,mpr					; YES - limit offset to 9999
	bra		do_logoffset_exit			;     - store offset and return

do_logoffset_minus:
	rcall	do_logoffset_common			; load current offset and step size
	; subtract step size from current offset
	movf	mpr+2,W						; get step size,        low  byte
	subwf	mpr+0,F						; subtract from offset, low byte
	movf	mpr+3,W						; get step size,        high byte
	subwfb	mpr+1,F						; subtract from offset, high byte, considering borrow flag
	; check if new offset is within limit
	btfsc	STATUS,C					; borrow to propagate (B == /CARRY) ?
	bra		do_logoffset_exit			; NO  - result >= 0, store and return
do_logoffset_reset:
	CLRI	mpr							; YES - revert offset to 0
	;bra	do_logoffset_exit			;     - store offset and return

do_logoffset_exit:
	goto	eeprom_log_offset_write		; store offset and return


do_return_dispsets_menu:
	bcf		imprint_color_schemes		; not in color schemes menu any more
	call	menu_processor_double_pop	; drop exit line and back to last line

do_dispsets_menu:
 IF _language_2!=none
	MENU_BEGIN	tDispSets, .7
		MENU_OPTION		tBright,					oBrightness,			0
		MENU_OPTION		tLayout,					oLayout,				0
		MENU_OPTION		tUnits,						oUnits,					0
		MENU_OPTION		tLanguage,					oLanguage,				0
		MENU_OPTION		tFlip,						oFlipScreen,			0
		MENU_CALL		tColorScheme,				do_color_scheme
		MENU_CALL		tMore,						do_dispsets_menu_more
	MENU_END
 ELSE
	MENU_BEGIN	tDispSets, .6
		MENU_OPTION		tBright,					oBrightness,			0
		MENU_OPTION		tLayout,					oLayout,				0
		MENU_OPTION		tUnits,						oUnits,					0
		MENU_OPTION		tFlip,						oFlipScreen,			0
		MENU_CALL		tColorScheme,				do_color_scheme
		MENU_CALL		tMore,						do_dispsets_menu_more
	MENU_END
 ENDIF


do_dispsets_menu_more:
 IFDEF _helium
	MENU_BEGIN	tDispSets, .7
		MENU_OPTION		tVSIgraph,					oVSIgraph,				0
		MENU_OPTION		tVSItext2,					oVSItext,				0
		MENU_OPTION		tShowppO2,					oShowppO2,				0
		MENU_OPTION		tDepthWarning,				oDepthWarn,				0
		MENU_OPTION		t2ndDepth,					o2ndDepthDisp,			0
		MENU_OPTION		tTissueGraphics,			oTissueGraphics,		0
		MENU_CALL		tBack,						do_return_settings_deeper
	MENU_END
 ELSE
	MENU_BEGIN	tDispSets, .6
		MENU_OPTION		tVSIgraph,					oVSIgraph,				0
		MENU_OPTION		tVSItext2,					oVSItext,				0
		MENU_OPTION		tShowppO2,					oShowppO2,				0
		MENU_OPTION		tDepthWarning,				oDepthWarn,				0
		MENU_OPTION		t2ndDepth,					o2ndDepthDisp,			0
		MENU_CALL		tBack,						do_return_settings_deeper
	MENU_END
 ENDIF


do_color_scheme:
	bsf		imprint_color_schemes		; in color schemes menu

	MENU_BEGIN	tColorScheme, .2
		MENU_OPTION		tColorSetDive,				oColorSetDive,			0
		MENU_CALL		tBack,						do_return_dispsets_menu
	MENU_END


;=============================================================================

do_new_battery_menu:
	MENU_BEGIN	tNewBattTitle, .2
		MENU_CALL		tAbort,						do_return_settings_more_deeper
		MENU_CALL		tYes,						do_new_battery_select_1
	MENU_END


	global	do_new_battery_select
do_new_battery_select:
	call	TFT_boot					; initialize TFT (includes clear screen)
	call	TFT_Display_FadeIn			; dim up the display
	call	menu_processor_reset		; reset menu stack

do_new_battery_select_1:
	; make sure to reset battery percentage
	movlw	.100
	movwf	batt_percent				; set battery level to full

	; default (in cases of timeout or USB): use old battery
	call	eeprom_battery_gauge_read	; retrieve stored battery gauge value from EEPROM

 IFDEF _screendump
	bsf		screen_dump_avail			; enable screen dump function to prevent exiting into COMM mode immediately
 ELSE
	bsf		comm_mode_disabled			; disable COMM mode to prevent exiting into COMM mode immediately
 ENDIF

	; hardware descriptor:                                                      user changeable battery   charger  supported battery types
	; -------------------------------------------------------------------------------------------------------------------------------------------------------
	; 0x11: BLE                                      and battery gauge ---> OSTC 2     (old  model)  NO     YES    internal 18650
	; 0x05:         analog  input                    and battery gauge ---> OSTC 2 cR                NO     YES    internal 18650
	; 0x33: BLE and RX module     and ambient sensor and battery gauge ---> OSTC 2 TR                NO     YES    internal 16650
	; 0x13: BLE                   and ambient sensor and battery gauge -+-> OSTC 2     (new  model)  NO     YES    internal 16650
	;                                                                   +-> OSTC Plus                YES    YES    1.5V  ----- NO! -----  3.6V rechargeable
	; 0x0A:         optical input and ambient sensor                   ---> OSTC 3     (USB model)   YES    NO     1.5V  3.6V disposable  3.6V rechargeable
	; 0x1A: BLE and optical input and ambient sensor                   ---> OSTC 3     (BLE model)   YES    NO     1.5V  3.6V disposable  3.6V rechargeable
	; 0x02:                           ambient sensor                   ---> OSTC Sport (USB model)   YES    NO     1.5V  3.6V disposable  3.6V rechargeable
	; 0x52: BLE                   and ambient sensor and low volt core ---> OSTC Sport (BLE model)   YES    NO     1.5V  3.6V disposable  3.6V rechargeable


	movlw	0x11						; OSTC 2 (old model)
	cpfseq	HW_descriptor
	bra		$+4
	bra		use_18650_battery

	movlw	0x05						; OSTC 2 cR
	cpfseq	HW_descriptor
	bra		$+4
	bra		use_18650_battery

	movlw	0x33						; OSTC 2 TR
	cpfseq	HW_descriptor
	bra		$+4
	bra		use_16650_battery

;	movlw	0xXX						; OSTC 2 (new model)							TODO: define signature
;	cpfseq	HW_descriptor
;	bra		$+4
;	bra		use_16650_battery

	movlw	0x13						; OSTC Plus										TODO: and OSTC 2 new model as of now
	cpfseq	HW_descriptor
	bra		$+4
	bra		menu_new_battery_AA_charger

	; movlw	0x0A						; OSTC 3 (USB model)
	; cpfseq	HW_descriptor
	; bra		$+4
	; bra		menu_new_battery_AA_no_charger

	; movlw	0x1A						; OSTC 3 (BLE model)
	; cpfseq	HW_descriptor
	; bra		$+4
	; bra		menu_new_battery_AA_no_charger

	; movlw	0x02						; OSTC Sport (USB model)
	; cpfseq	HW_descriptor
	; bra		$+4
	; bra		menu_new_battery_AA_no_charger

	; movlw	0x52						; OSTC Sport (BLE model)
	; cpfseq	HW_descriptor
	; bra		$+4
	; bra		menu_new_battery_AA_no_charger

	bra		menu_new_battery_AA_no_charger	; any other model


do_return_menu_new_bat_AA_chrg:
	call	menu_processor_double_pop	; drop exit line and back to last line

	; OSTC Plus (charging function)																TODO: and OSTC 2 new model as of now
menu_new_battery_AA_charger:
	MENU_BEGIN	tNewBattTitle, .4
		MENU_CALL		tNewBattOld,				use_old_batteries
		MENU_CALL		tNewBattNew15,				use_new_15V_batteries	; not rechargeable
;		MENU_CALL		tNewBattNew36,				use_36V_disposable		; not rechargeable  -> not allowed any more !!!
		MENU_CALL		tNewBattAccu,				pre_36V_rechargeable	; rechargeable      -> goto safety question
		MENU_CALL		tNew16650,					use_16650_battery		; OSTC 2 new model	TODO: remove when OSTC 2 new model can be separated from Plus
	MENU_END

pre_36V_rechargeable:
	MENU_BEGIN	tNewBattTitle, .5
		MENU_CALL		tConfirmChargeable1,		0								; safety question, line 1
		MENU_CALL		tConfirmChargeable2,		0								; safety question, line 2
		MENU_CALL		tConfirmChargeable3,		0								; safety question, line 3
		MENU_CALL		tNo,						do_return_menu_new_bat_AA_chrg	; NO  - go back
		MENU_CALL		tYes,						use_37V_rechargeable			; YES - confirmed rechargeable
	MENU_END

	; OSTC 3 and Sport (no charging function)
menu_new_battery_AA_no_charger:
	MENU_BEGIN	tNewBattTitle, .4
		MENU_CALL		tNewBattOld,				use_old_batteries
		MENU_CALL		tNewBattNew15,				use_new_15V_batteries	; not rechargeable
		MENU_CALL		tNewBattNew36,				use_36V_disposable		; not rechargeable
		MENU_CALL		tNewBattAccu,				use_37V_rechargeable	; rechargeable
	MENU_END


	global	use_old_prior_209
use_old_prior_209:
	EEPROM_CC_READ eeprom_battery_type,WREG	; read battery type from EEPROM
	incfsz	WREG,W							; battery type = 0xFF (undefined) ?
	return									; NO  - done
	call	lt2942_get_status				; YES - check for gauge IC
	movlw	.3								;     - default to a 18650 (LiIon 3.7V/3.1Ah)
	btfss	battery_gauge_available			;     - OSTC 2 or cR hardware?
	movlw	.1								;     - NO - assume a Saft (disposable 3.6 V)
	EEPROM_CC_WRITE WREG,eeprom_battery_type;     - write battery type to EEPROM
	return									;     - done


use_old_batteries:
	rcall	get_battery_data			; load data of old battery
	goto	surfloop					; proceed to surface loop


	global	get_battery_data
get_battery_data:
	call	eeprom_battery_gauge_read	; retrieve stored battery gauge value from EEPROM
	movff	battery_type,lo				; copy retrieved battery type to lo
	rcall	setup_new_saft				; default battery configuration
	incf	lo,F						; (0-4) -> (1-5)
	dcfsnz	lo,F
	rcall	setup_new_15v				; =0
	dcfsnz	lo,F
	rcall	setup_new_saft				; =1
	dcfsnz	lo,F
	rcall	setup_new_panasonic			; =2
	dcfsnz	lo,F
	rcall	setup_new_18650				; =3
	dcfsnz	lo,F
	rcall	setup_new_16650				; =4
	bcf		use_old_batt_flag			; clear flag
 IFNDEF _screendump
	bcf		comm_mode_disabled			; re-enable COMM mode again
 ENDIF
	return								; done


	; disposable 1.5 Volt Alkaline
setup_new_15v:
	bsf		charge_disable				; set      charging-inhibit signal
	bcf		charge_enable				; activate charging-inhibit signal
	movlw	.100
	movwf	batt_percent				; to have 1.5V batteries right after firmware update
	movlw	.0
	movwf	battery_type
	return

	; disposable 3.6 Volt Lithium
setup_new_saft:
	bsf		charge_disable				; set      charging-inhibit signal
	bcf		charge_enable				; activate charging-inhibit signal
	MOVLI	capacity_saft_internal, battery_capacity_internal
	MOVLI	capacity_saft,          battery_capacity
	MOVLI	offset_saft,            battery_offset
	movlw	.1
	movwf	battery_type
	return

	; rechargeable user-changeable 3.7 Volt Lithium-ion
setup_new_panasonic:
	bcf		charge_disable				; release  charging-inhibit signal
	bsf		charge_enable				; tristate charging-inhibit signal
	MOVLI	capacity_panasonic_internal, battery_capacity_internal
	MOVLI	capacity_panasonic,          battery_capacity
	MOVLI	offset_panasonic,            battery_offset
	movlw	.2
	movwf	battery_type
	return

	; rechargeable internal Lithium-ion
setup_new_18650:
	bcf		charge_disable				; release  charging-inhibit signal
	bsf		charge_enable				; tristate charging-inhibit signal
	CLRI	battery_capacity_internal
	MOVLI	capacity_ncr18650, battery_capacity
	MOVLI	offset_ncr18650,   battery_offset
	movlw	.3
	movwf	battery_type
	return

	; rechargeable internal Lithium-ion
setup_new_16650:
	bcf		charge_disable				; release  charging-inhibit signal
	bsf		charge_enable				; tristate charging-inhibit signal
	CLRI	battery_capacity_internal
	MOVLI	capacity_ur16650, battery_capacity
	MOVLI	offset_ur16650,   battery_offset
	movlw	.4
	movwf	battery_type
	return


use_new_15V_batteries:
	rcall	setup_new_15v
	bra		use_batt_exit

use_36V_disposable:
	rcall	setup_new_saft
	bra		use_batt_exit

use_37V_rechargeable:
	rcall	setup_new_panasonic
	call	reset_battery_gauge
	bra		use_batt_exit_1

use_16650_battery:
	rcall	setup_new_16650
	bra		use_batt_exit

use_18650_battery:
	rcall	setup_new_18650
	;bra	use_batt_exit

use_batt_exit:
	call	reset_battery_gauge_and_lt2942		; reset battery pointer 0x07-0x0C and battery gauge
use_batt_exit_1:
 IFNDEF _screendump
	bcf		comm_mode_disabled			; re-enable COMM mode again
 ENDIF
	goto	surfloop					; jump to surface loop

;-----------------------------------------------------------------------------

	END
