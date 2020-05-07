;=============================================================================
;
;   File menu_tree.asm                      * combined next generation V3.09.5
;
;   OSTC Surface Menus
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;   2011-07-11 : [jDG] Creation.


;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;
;                                  ATTENTION
;
; All Calls made via the Menu Macros need to go to Addresses within 0x0xxxx !
;
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


#include "hwos.inc"						; mandatory header
#include "shared_definitions.h"			; mailbox from/to p2_deco.c
#include "gaslist.inc"
#include "menu_processor.inc"
#include "start.inc"
#include "comm.inc"
#include "tft.inc"
#include "eeprom_rs232.inc"
#include "external_flash.inc"
#include "adc_lightsensor.inc"
#include "wait.inc"
#include "i2c.inc"
#include "calibrate.inc"
#include "math.inc"
#include "rtc.inc"
#include "strings.inc"
#include "tft_outputs.inc"
#include "convert.inc"
#include "colorschemes.inc"


	extern	surfloop
	extern	logbook
	extern	demo_divemode
	extern	demo_planner
	extern	piezo_config
	extern	comm_firmware_update_exec

	extern	option_check_and_store_all
	extern	option_reset
	extern	option_reset_all
	extern	option_adjust_group_member
	extern	option_inc
	extern	option_dec
	extern	option_draw

	extern	get_cpu_version
	extern	eeprom_deco_data_write


 IFDEF _ccr_pscr
	extern	option_cleanup_oCCRMode
 ENDIF

 IFDEF _compass
	extern	compass_calibration
 ENDIF

 IFDEF _rx_functions
	extern	get_transmitter_id_by_slot
 ENDIF


;=============================================================================
surf_menu	CODE 0x01000				; needs to be at 0x0xxxx
;=============================================================================


;-----------------------------------------------------------------------------
; Returning from a Menu Item
;
do_return_main_menu:
	call	menu_processor_double_pop	; drop exit line and back to last line
	bra		main_menu_common			; continue with menu


;-----------------------------------------------------------------------------
; Entry Point for Main Menu
;
	global	main_menu
main_menu:
	movff	active_customview,customview_surfmode	; save last custom view
	clrf	MS_flags_imprint						; clear all flags for data imprinting
	call	TFT_boot								; initialize display
	call	menu_processor_reset					; reset menu stack

main_menu_common:
 IFDEF _ccr_pscr
	MENU_BEGIN	tMainMenu, .7
		MENU_CALL		tLogbook,					do_logbook
		MENU_CALL		tGasSetup,					do_menu_gas
		MENU_CALL		tCCRSetup,					do_menu_ccr
		MENU_CALL		tDiveModeMenu,				do_menu_dive
		MENU_CALL		tSimulator,					do_menu_simulator
		MENU_CALL		tSystSets,					do_menu_settings
		MENU_CALL		tExit,						do_restart
	MENU_END
 ELSE
	MENU_BEGIN	tMainMenu, .6
		MENU_CALL		tLogbook,					do_logbook
		MENU_CALL		tGasSetup,					do_menu_gas
		MENU_CALL		tDiveModeMenu,				do_menu_dive
		MENU_CALL		tSimulator,					do_menu_simulator
		MENU_CALL		tSystSets,					do_menu_settings
		MENU_CALL		tExit,						do_restart
	MENU_END
 ENDIF	; _ccr_pscr


;-----------------------------------------------------------------------------
; Call Function - start Logbook
;
do_logbook:
	goto	logbook						; code is hosted in logbook.asm


;-----------------------------------------------------------------------------
; Call Function - exit Menu
;
do_restart:
	bsf		restart_fast				; skip logos and waits an restart
	goto	restart						; restart into surface mode


 IFDEF _ccr_pscr

;-----------------------------------------------------------------------------
; returning to CCR / pSCR Setup
;
do_return_menu_ccr:
	call	menu_processor_double_pop	; drop exit line and back to last line
	;bra	do_menu_ccr


;-----------------------------------------------------------------------------
; CCR / pSCR Setup - 1st Level
;
do_menu_ccr:
	call	option_cleanup_oCCRMode		; in pSCR mode, revert AutoSP (2) to calculated SP (0)

 IFDEF _external_sensor

	bcf		imprint_sensor_mv			; stop imprinting of live O2 sensor mV data
	btfss	ext_input_s8_ana			; S8/analog sensor input available?
	bra		do_menu_ccr_2				; NO  - do OSTC 2  menu
	;bra	do_menu_ccr_cR				; YES - do OSTC cR menu

do_menu_ccr_cR:							; OSTC cR menu
	MENU_BEGIN	tCCRSetup, .6
		MENU_OPT_INC	tCCRMode,					oCCRMode
		MENU_CALL		tCalibrateMenu,				do_menu_calibrate
		MENU_CALL		tDiluentSetup,				do_menu_diluent
		MENU_CALL		tFixedSetpoints,			do_menu_setpoints
		MENU_CALL		tMore,						do_menu_ccr_more
		MENU_CALL		tBack,						do_return_main_menu
	MENU_END

 ENDIF	; _external_sensor

do_menu_ccr_2:
	MENU_BEGIN	tCCRSetup, .5			; OSTC 2 menu
		MENU_OPT_INC	tCCRMode,					oCCRMode
		MENU_CALL		tDiluentSetup,				do_menu_diluent
		MENU_CALL		tFixedSetpoints,			do_menu_setpoints
		MENU_CALL		tMore,						do_menu_ccr_more
		MENU_CALL		tBack,						do_return_main_menu
	MENU_END


;-----------------------------------------------------------------------------
; CCR / pSCR Setup - 2nd Level
;
do_menu_ccr_more:
 IFDEF _external_sensor
	MENU_BEGIN	tCCRSetup, .7			; CCR/pSCR more menu
		MENU_OPT_INC	tS8Mode,					oS8Mode
		MENU_OPT_INC	tCCmaxFracO2,				oCCmaxFracO2
		MENU_OPT_INC	tDilppO2Check,				oDilppO2Check
		MENU_OPT_INC	tGasDensityCheck,			oGasDensityCheck
		MENU_OPT_INC	tPSCR_O2_drop,				oPSCR_drop
		MENU_OPT_INC	tPSCR_lungratio,			oPSCR_lungratio
		MENU_CALL		tBack,						do_return_menu_ccr
	MENU_END
 ELSE
	MENU_BEGIN	tCCRSetup, .6			; CCR/pSCR more menu
		MENU_OPT_INC	tCCmaxFracO2,				oCCmaxFracO2
		MENU_OPT_INC	tDilppO2Check,				oDilppO2Check
		MENU_OPT_INC	tGasDensityCheck,			oGasDensityCheck
		MENU_OPT_INC	tPSCR_O2_drop,				oPSCR_drop
		MENU_OPT_INC	tPSCR_lungratio,			oPSCR_lungratio
		MENU_CALL		tBack,						do_return_menu_ccr
	MENU_END
 ENDIF	; _external_sensor

 ENDIF	; _ccr_pscr


 IFDEF _external_sensor

;-----------------------------------------------------------------------------
; Calibration Menu
;
do_menu_calibrate:
	call	enable_ir_s8_analog			; enable IR/S8/analog interface
	bsf		imprint_sensor_mv			; start imprinting of live O2 sensor mV data

	MENU_BEGIN	tCalibrateMenu, .6
		MENU_CALL		tDiveHudMask1,				0					; data will be superimposed by housekeeping
		MENU_CALL		tDiveHudMask2,				0					; ...
		MENU_CALL		tDiveHudMask3,				0					; ...
		MENU_OPT_INC	tCalibrationGas,			oCalGasO2
		MENU_CALL		tCalibrate,					do_calibrate
		MENU_CALL		tBack,						do_return_menu_ccr
	MENU_END


;-----------------------------------------------------------------------------
; Call Function - start Calibration, returns to Surface Mode
;
do_calibrate:
	call	calibrate_mix				; calibrate with opt_calibration_O2_ratio, also calibrate S8 HUD if connected
	WAITMS	d'250'						; wait for HUD v3
	movlw	.9							; load index of sensor mV custom view
	movff	WREG,customview_surfmode	; show this custom view when back in surface mode
	bra		do_restart					; exit menu

 ENDIF	; _external_sensor


 IFDEF _ccr_pscr

;-----------------------------------------------------------------------------
; Diluent Setup
;
do_menu_diluent:
	bsf		is_diluent_menu				; setting up diluents
	bcf		short_gas_descriptions		; use long gas description format
	bcf		better_gas_hint				; do not mark the best gas/diluent (to be used in dive mode only)
	call	gaslist_cleanup_list		; make sure there is only one gas being first

	MENU_BEGIN	tDiluentSetup, .6
		MENU_DYNAMIC	dyn_strcat_gas_PRODL,		do_menu_edit_gas
		MENU_DYNAMIC	dyn_strcat_gas_PRODL,		do_menu_edit_gas
		MENU_DYNAMIC	dyn_strcat_gas_PRODL,		do_menu_edit_gas
		MENU_DYNAMIC	dyn_strcat_gas_PRODL,		do_menu_edit_gas
		MENU_DYNAMIC	dyn_strcat_gas_PRODL,		do_menu_edit_gas
		MENU_CALL		tBack,						do_return_menu_ccr
	MENU_END


;-----------------------------------------------------------------------------
; dynamic Title - show full Gas Description (just for info, active code is in other place)
;
;dyn_strcat_gas_PRODL:
;	goto	gaslist_strcat_gas_PRODL	; code is hosted in gaslist.asm


;-----------------------------------------------------------------------------
; returning to Setpoint Setup
;
do_return_menu_setpoints:
	call	menu_processor_double_pop	; drop exit line and back to last line
	bcf		block_option_value			; resume displaying of option values
	;bra	do_menu_setpoints			; continue


;-----------------------------------------------------------------------------
; Setpoint Setup - 1st Level
;
do_menu_setpoints:
	bcf		short_gas_descriptions		;  use long gas description format
	bcf		better_gas_hint				; do not mark the best gas/diluent (to be used in dive mode only)

	MENU_BEGIN	tFixedSetpoints, .6
		MENU_DYNAMIC	dyn_strcat_setpoint_prodl,	do_menu_edit_sp
		MENU_DYNAMIC	dyn_strcat_setpoint_prodl,	do_menu_edit_sp
		MENU_DYNAMIC	dyn_strcat_setpoint_prodl,	do_menu_edit_sp
		MENU_DYNAMIC	dyn_strcat_setpoint_prodl,	do_menu_edit_sp
		MENU_DYNAMIC	dyn_strcat_setpoint_prodl,	do_menu_edit_sp
		MENU_CALL		tBack,						do_return_menu_ccr
	MENU_END


;-----------------------------------------------------------------------------
; dynamic Title - show Setpoint Data
;
dyn_strcat_setpoint_prodl:
	goto	gaslist_strcat_setpoint_PRODL ; function is hosted in gaslist.asm


;-----------------------------------------------------------------------------
; Setpoint Setup - 2nd Level
;
do_menu_edit_sp:
	movff	PRODL,gaslist_gas			; get menu item we came from (0-4)
	bsf		block_option_value			; suspend displaying of option values

	MENU_BEGIN	tFixedSetpoints, .5
		MENU_DYNAMIC	dyn_strcat_setpoint,		0
		MENU_GRP_INC	tSPPlus,					oSP1ppO2
		MENU_GRP_INCS	tDepthPlus,					oSP1Depth
		MENU_GRP_DECS	tDepthMinus,				oSP1Depth
		MENU_CALL		tBack,						do_return_menu_setpoints
	MENU_END


;-----------------------------------------------------------------------------
; dynamic Title - show Setpoint Data
;
dyn_strcat_setpoint:
	goto	gaslist_strcat_setpoint		; function is hosted in gaslist.asm

 ENDIF	; _ccr_pscr


;-----------------------------------------------------------------------------
; returning from Gas / Diluent Setup
;
do_return_menu_gas:
	call	menu_processor_double_pop	; drop exit line and back to last line

 IFDEF _ccr_pscr
	btfsc	is_diluent_menu				; return from setting up diluents?
	bra		do_menu_diluent				; YES - continue with diluent menu
	;bra	do_menu_gas					; NO  - continue with OC gas  menu
 ENDIF


;-----------------------------------------------------------------------------
; OC Gas Setup - 1st Level
;
do_menu_gas:
	bcf		is_diluent_menu				; setting up OC gases
	bcf		short_gas_descriptions		;  use long gas description format
	bcf		better_gas_hint				; do not mark the best gas/diluent (to be used in dive mode only)
	call	gaslist_cleanup_list		; make sure there is only one gas being first

	MENU_BEGIN	tGaslist, .6
		MENU_DYNAMIC	dyn_strcat_gas_PRODL,		do_menu_edit_gas
		MENU_DYNAMIC	dyn_strcat_gas_PRODL,		do_menu_edit_gas
		MENU_DYNAMIC	dyn_strcat_gas_PRODL,		do_menu_edit_gas
		MENU_DYNAMIC	dyn_strcat_gas_PRODL,		do_menu_edit_gas
		MENU_DYNAMIC	dyn_strcat_gas_PRODL,		do_menu_edit_gas
		MENU_CALL		tBack,						do_return_main_menu
	MENU_END


;-----------------------------------------------------------------------------
; dynamic Title - show full Gas Description
;
dyn_strcat_gas_PRODL:
	goto	gaslist_strcat_gas_PRODL	; code is hosted in gaslist.asm


;-----------------------------------------------------------------------------
; return to OC Gas Setup from Sub-Menu
;
do_return_menu_edit_gas:
 IFDEF _rx_functions
	bcf		imprint_xmitter_pres		; stop imprinting of transmitter pressure data
	bcf		imprint_xmitter_ID			; not in transmitter selection menu any more (back to normal timeout)
 ENDIF
	call	menu_processor_double_pop	; drop exit line and back to last line
	bcf		block_option_value			; resume displaying of option values
	bra		do_menu_edit_gas_common		; continue with common part


;-----------------------------------------------------------------------------
; OC Gas Setup - 2nd Level
;
do_menu_edit_gas:
	movff	PRODL,gaslist_gas			; get menu item we came from (0-4)
	movlw	.5							; offset between gases and diluents
	btfsc	is_diluent_menu				; setting up diluents?
	addwf	gaslist_gas,F				; YES - add the offset

do_menu_edit_gas_common:
	MENU_BEGIN	tGasEdit, .7
		MENU_DYNAMIC	dyn_gastitle,				0
		MENU_DYNAMIC	dyn_MOD_END,				0
		MENU_GRP_INC	tType,						oGas1
		MENU_CALL		tSetup_GasMix,				do_menu_gas_mix
		MENU_DYNAMIC	dyn_show_depth,				do_menu_gas_depth
		MENU_CALL		tSetup_Tank,				do_menu_gas_tank
		MENU_CALL		tBack,						do_return_menu_gas
	MENU_END


;-----------------------------------------------------------------------------
; dynamic Title - show full Gas Description
;
dyn_gastitle:
	goto	gaslist_strcat_gas			; code is hosted in gaslist.asm


;-----------------------------------------------------------------------------
; dynamic Title - show MOD and END
;
dyn_MOD_END:
	goto	gaslist_MOD_END				; code is hosted in gaslist.asm


;-----------------------------------------------------------------------------
; dynamic Title - show Change Depth
;
dyn_show_depth:
	movf	gaslist_gas,W				; load gas/dil index into WREG (0-9)
	lfsr	FSR1,opt_gas_change			; load base address of change depths
	tstfsz	PLUSW1						; change depth = 0 ?
	bra		dyn_show_depth_1			; NO  - print in normal color
	lfsr	FSR1,opt_gas_type			; YES - load base address of opt_gas_type
	tstfsz	PLUSW1						;     - type = disabled ?
	FONT_COLOR_ATTENTION				;       NO  - print in attention color (yellow)
dyn_show_depth_1:
	STRCAT_TEXT tSetup_GasDepth			; print text
	return								; done


;-----------------------------------------------------------------------------
; OC Gas Setup - 3rd Level - Mix
;
do_menu_gas_mix:
	bsf		block_option_value			; suspend displaying of option values

 IFDEF _helium
	MENU_BEGIN	tGasEdit, .7
		MENU_DYNAMIC	dyn_gastitle,				0
		MENU_DYNAMIC	dyn_MOD_END,				0
		MENU_GRP_INCS	tO2Plus,					oGas1O2
		MENU_GRP_DECS	tO2Minus,					oGas1O2
		MENU_GRP_INCS	tHePlus,					oGas1He
		MENU_GRP_DECS	tHeMinus,					oGas1He
		MENU_CALL		tBack,						do_return_menu_edit_gas
	MENU_END
 ELSE
	MENU_BEGIN	tGasEdit, .5
		MENU_DYNAMIC	dyn_gastitle,				0
		MENU_DYNAMIC	dyn_MOD_END,				0
		MENU_GRP_INCS	tO2Plus,					oGas1O2
		MENU_GRP_DECS	tO2Minus,					oGas1O2
		MENU_CALL		tBack,						do_return_menu_edit_gas
	MENU_END
 ENDIF


;-----------------------------------------------------------------------------
; OC Gas Setup - 3rd Level - Change Depth
;
do_menu_gas_depth:
	bsf		block_option_value			; suspend displaying of option values

	MENU_BEGIN	tGasEdit, .7
		MENU_DYNAMIC	dyn_gastitle,				0
		MENU_DYNAMIC	dyn_MOD_END,				0
		MENU_DYNAMIC	dyn_ppo2,					0
		MENU_GRP_INCS	tDepthPlus,					oGas1Depth
		MENU_GRP_DECS	tDepthMinus,				oGas1Depth
		MENU_DYNAMIC	dyn_reset_mod_title,		do_gas_depth_reset
		MENU_CALL		tBack,						do_return_menu_edit_gas
	MENU_END


;-----------------------------------------------------------------------------
; dynamic Title - show Gas Description
;
;dyn_gastitle:
;	goto	gaslist_strcat_gas			; code is hosted in gaslist.asm


;-----------------------------------------------------------------------------
; dynamic Title - show MOD and END
;
;dyn_MOD_END:
;	goto	gaslist_MOD_END				; code is hosted in gaslist.asm


;-----------------------------------------------------------------------------
; dynamic Title - show ppO2 and Change Depth
;
dyn_ppo2:
	goto	gaslist_ppo2				; code is hosted in gaslist.asm


;-----------------------------------------------------------------------------
; dynamic Title - show 'Rest to MOD' Dialog
;
dyn_reset_mod_title:
	goto	gaslist_reset_mod_title		; code is hosted in gaslist.asm


;-----------------------------------------------------------------------------
; Call Function - reset Change Depth to MOD
;
do_gas_depth_reset:
	call	gaslist_calc_mod			; compute MOD, result in WREG
	movwf	lo							; copy result to lo
	lfsr	FSR1,opt_gas_change			; load base address of opt_gas_change
	movf	gaslist_gas,W				; load index
	movff	lo,PLUSW1					; update change depth
	bsf		option_changed				; flag that EEPROM needs to be updated
	return								; done


;-----------------------------------------------------------------------------
; OC Gas Setup - 3rd Level - Tank Setup
;
do_menu_gas_tank:
 IFDEF _rx_functions
	TSTOSC	opt_TR_mode					; TR functions switched on?
	bra		do_menu_gas_tank_rx			; YES
 ENDIF

 IFDEF _ccr_pscr
	MENU_BEGIN	tSetup_Tank, .5
		MENU_DYNAMIC	dyn_gastitle,				0
		MENU_GRP_INC	tTankSize,					oTankSizeOC1
		MENU_GRP_INC	tTankUsablePress,			oTankPresOC1
		MENU_CALL		tCopyDilToOC,				do_copy_dil_to_oc
		MENU_CALL		tBack,						do_return_menu_edit_gas
	MENU_END
 ELSE
	MENU_BEGIN	tSetup_Tank, .4
		MENU_DYNAMIC	dyn_gastitle,				0
		MENU_GRP_INC	tTankSize,					oTankSizeOC1
		MENU_GRP_INC	tTankUsablePress,			oTankPresOC1
		MENU_CALL		tBack,						do_return_menu_edit_gas
	MENU_END
 ENDIF	; _ccr_pscr


 IFDEF _rx_functions
do_menu_gas_tank_rx:
	setf	pairing_slot				; prime slot number with 255 aka -1, used in pairing function
	bsf		imprint_xmitter_ID			; in transmitter selection menu (longer timeout)

 IFDEF _ccr_pscr
	MENU_BEGIN	tSetup_Tank, .7
		MENU_DYNAMIC	dyn_gastitle,				0
		MENU_DYNAMIC	dyn_tank_id_pres,			0				; pressure will be superimposed by housekeeping
		MENU_CALL		tTankPairing,				do_tank_pairing
		MENU_GRP_INC	tTankSize,					oTankSizeOC1
		MENU_GRP_INC	tTankUsablePress,			oTankPresOC1
		MENU_CALL		tCopyDilToOC,				do_copy_dil_to_oc
		MENU_CALL		tBack,						do_return_menu_edit_gas
	MENU_END
 ELSE
	MENU_BEGIN	tSetup_Tank, .6
		MENU_DYNAMIC	dyn_gastitle,				0
		MENU_DYNAMIC	dyn_tank_id_pres,			0				; pressure will be superimposed by housekeeping
		MENU_CALL		tTankPairing,				do_tank_pairing
		MENU_GRP_INC	tTankSize,					oTankSizeOC1
		MENU_GRP_INC	tTankUsablePress,			oTankPresOC1
		MENU_CALL		tBack,						do_return_menu_edit_gas
	MENU_END
 ENDIF	; _ccr_pscr


;-----------------------------------------------------------------------------
; dynamic Title - show Transmitter ID
;
dyn_tank_id_pres:
	STRCAT	"  ID: "					; print header
	; get ID
	lfsr	FSR1,opt_transmitter_id_1	; load base address of opt_transmitter_id
	movf	gaslist_gas,W				; load index (0-9)
	rlncf	WREG,W						; multiply by 2 because IDs are 2 byte in size
	movff	PLUSW1,lo					; copy opt_transmitter_id+0[gaslist_gas] to lo
	incf	WREG,W						; increment index
	movff	PLUSW1,hi					; copy opt_transmitter_id+1[gaslist_gas] to hi
	; check if a transmitter is paired to this tank
	tstfsz	hi							; high byte of ID <> 0 ?
	bra		dyn_tank_id_pres_1			; YES - a transmitter is paired to the tank
	tstfsz	lo							; low  byte of ID <> 0 ?
	bra		dyn_tank_id_pres_1			; YES - a transmitter is paired to the tank
	STRCAT	"----"						; NO  - no transmitter paired
	bcf		imprint_xmitter_pres		;     - stop imprinting of transmitter pressure data
	return								;     - done
dyn_tank_id_pres_1:						; show ID
	movf	hi,W						; copy high byte of ID to WREG
	output_hex							; print it
	movf	lo,W						; copy low  byte of ID to WREG
	output_hex							; print it
	bsf		imprint_xmitter_pres		; start imprinting of transmitter pressure data
	return								; done


;-----------------------------------------------------------------------------
; Call Function - pair a Transmitter to a Tank
;
do_tank_pairing:
	incf	pairing_slot,F				; goto next RX data slot
	btfsc	pairing_slot,3				; slot = 8?
	bra		do_tank_pairing_none		; YES - offer unpairing
	movf	pairing_slot,W				; NO  - copy slot to WREG
	call	get_transmitter_id_by_slot	; WREG = slot (0-7) -> hi:lo = transmitter ID
	tstfsz	hi							; transmitter found (probe on high byte)?
	bra		do_tank_pairing_common		; YES - select this transmitter
	tstfsz	hi							; transmitter found (probe on low byte)?
	bra		do_tank_pairing_common		; YES - select this transmitter
	bra		do_tank_pairing				; NO  - try next slot
do_tank_pairing_common:
	lfsr	FSR1,opt_transmitter_id_1	; load base address of opt_transmitter_id
	movf	gaslist_gas,W				; load index into WREG (0-9)
	rlncf	WREG,W						; multiply by 2 because IDs are 2 byte in size
	movff	lo,PLUSW1					; copy lo to opt_transmitter_id+0[gaslist_gas]
	incf	WREG,W						; increment index
	movff	hi,PLUSW1					; copy hi to opt_transmitter_id+1[gaslist_gas]
	bsf		option_changed				; flag that EEPROM needs to be updated
	return								; done
do_tank_pairing_none:
	setf	pairing_slot				; prime slot number with 255 aka -1
	clrf	hi							; adjust "no transmitter" ID
	clrf	lo							; adjust "no transmitter" ID
	bra		do_tank_pairing_common		; continue with common part

 ENDIF	; _rx_functions


 IFDEF _ccr_pscr

;-----------------------------------------------------------------------------
; Call Function - copy Diluent Setup to OC Gases
;
do_copy_dil_to_oc:
	bcf		copying_dil					; default to copying a gas
	movf	gaslist_gas,W				; copy current gas or diluent number to WREG
	btfss	is_diluent_menu				; setting up diluents?
	bra		do_copy_dil_to_oc_1			; NO  - gaslist_gas is already pointing to an OC gas
	addlw	-.5							; YES - subtract offset between diluents and gases
	movwf	gaslist_gas					;     - let gaslist_gas point to the corresponding OC gas
	bsf		copying_dil					;     - we are copying a diluent
	bcf		is_diluent_menu				;     - pretend we are setting up OC gases
do_copy_dil_to_oc_1:
	lfsr	FSR0,opt_dil_O2_ratio		; load base address of diluents settings, ASM variables
	lfsr	FSR1,opt_gas_O2_ratio		; load base address of gas      settings, ASM variables
	movff	PLUSW0,PLUSW1				; copy O2 ratio
	addlw	.10							; add offset from O2 ratios to He ratios
	movff	PLUSW0,PLUSW1				; copy He ratio
	addlw	.10							; add offset from He ratios to types
	movff	PLUSW0,PLUSW1				; copy type
	addlw	.10							; add offset from type to change depth
	movff	PLUSW0,PLUSW1				; copy change depth
	addlw	-.30						; wind back to initial gas number
	lfsr	FSR0,char_I_gas_avail_size+5; load base address of diluents settings, shared variables
	lfsr	FSR1,char_I_gas_avail_size+0; load base address of gas      settings, shared variables
	movff	PLUSW0,PLUSW1				; copy tank size
	addlw	.10							; add offset from tank sizes to pressure budget
	movff	PLUSW0,PLUSW1				; copy pressure budget
	call	gaslist_cleanup_list		; make sure there is only one gas being first
	bsf		option_changed				; flag that EEPROM needs to be updated
	btfss	copying_dil					; are we copying a diluent?
	return								; NO  - done
	bsf		is_diluent_menu				; YES - restore to be setting up diluents
	movlw	.5							;     - offset between OC gases and diluents
	addwf	gaslist_gas,F				;     - let gaslist_gas point to the diluent again
	WIN_BOX_BLACK .30,.239,.0,.159		;     - create some visual effect to show activity
	WAITMS	.200						;     - pause for 200 ms
	return								;     - done

 ENDIF	; _ccr_pscr


;-----------------------------------------------------------------------------
; return to Simulator (Deco Calculator) Menu from Sub-Menu
;
do_return_menu_simulator:
	call	menu_processor_double_pop	; drop exit line and back to last line
	bra		do_menu_simulator_common_2	; continue


;-----------------------------------------------------------------------------
; return to Simulator (Deco Calculator) Menu from Deco Calculator
;
	global	do_return_menu_simulator_planner
do_return_menu_simulator_planner:
	call	menu_processor_pop			; back to last line
	bra		do_menu_simulator_common_1	; continue


;-----------------------------------------------------------------------------
; Simulator (Deco Calculator) Menu
;
do_menu_simulator:
	; reset planning parameters to default values
	lfsr	FSR0,odiveInterval			; surface interval
	call	option_reset				; reset to default
	lfsr	FSR0,obottomTime			; bottom time
	call	option_reset				; reset to default
	lfsr	FSR0,obottomDepth			; bottom depth
	call	option_reset				; reset to default
	lfsr	FSR0,oSimAGF				; GF/aGF
	call	option_reset				; reset to default

 IFDEF _gas_contingency
	lfsr	FSR0,oGasContingencySim		; gas contingency
	call	option_reset				; reset to default (volatile option)
 ENDIF	; _gas_contingency

do_menu_simulator_common_1:
	call	restart_set_modes_and_flags	; initialize dive mode settings

do_menu_simulator_common_2:

 IFDEF _ccr_pscr

	movff	opt_dive_mode,WREG			; get dive mode: 0=OC, 1=CCR, 2=Gauge, 3=Apnea, 4=pSCR
	decfsz	WREG,W						; subtract one, became zero?
	bra		do_menu_simulator_common_oc	; NO  - use OC  version
	;bra	do_menu_simulator_common_ccr; YES - use CCR version

do_menu_simulator_common_ccr:
	MENU_BEGIN	tSimulator, .7
		MENU_OPT_INC	tIntvl,						odiveInterval
		MENU_OPT_INC	tBtDep,						obottomDepth
		MENU_CALL		tInter,						do_demo_divemode
		MENU_OPT_INC	tBtTm,						obottomTime
		MENU_CALL		tCalculatorSetup,			do_menu_simulator_more
		MENU_CALL		tDeco,						do_demo_planner
		MENU_CALL		tBack,						do_return_main_menu
	MENU_END

 ENDIF	; _ccr_pscr

do_menu_simulator_common_oc:
	MENU_BEGIN	tSimulator, .7
		MENU_OPT_INC	tIntvl,						odiveInterval
		MENU_OPT_INC	tBtDep,						obottomDepth
		MENU_CALL		tInter,						do_demo_divemode
		MENU_OPT_INC	tBtTm,						obottomTime
		MENU_OPT_INC	tuseAGF,					oSimAGF
		MENU_CALL		tDeco,						do_demo_planner
		MENU_CALL		tBack,						do_return_main_menu
	MENU_END


;-----------------------------------------------------------------------------
; Call Function - start Simulator Mode
;
do_demo_divemode:
	goto	demo_divemode				; code is hosted in divemode.asm


;-----------------------------------------------------------------------------
; Call Function - start Deco Calculator
;
do_demo_planner:
	goto	demo_planner				; code is hosted in simulator.asm


;-----------------------------------------------------------------------------
; Simulator (Deco Calculator) Menu - 2nd Layer
;
do_menu_simulator_more:
 IFDEF _gas_contingency
	MENU_BEGIN	tSimulator, .4
		MENU_OPT_INC	tSelectSetpoint,			oSimSetpoint
		MENU_OPT_INC	tuseAGF,					oSimAGF
		MENU_OPT_INC	tGasContingencySim,			oGasContingencySim
		MENU_CALL		tBack,						do_return_menu_simulator
	MENU_END
 ELSE
	MENU_BEGIN	tSimulator, .3
		MENU_OPT_INC	tSelectSetpoint,			oSimSetpoint
		MENU_OPT_INC	tuseAGF,					oSimAGF
		MENU_CALL		tBack,						do_return_menu_simulator
	MENU_END
 ENDIF	; _gas_contingency


;-----------------------------------------------------------------------------
; return to Dive Settings Menu from Sub-Menu
;
do_return_menu_dive:
	call	menu_processor_double_pop	; drop exit line and back to last line
	;bra	do_menu_dive			; continue

;-----------------------------------------------------------------------------
; Dive Settings Menu - 1st Layer
;
do_menu_dive:
	MENU_BEGIN	tDiveModeMenu, .6
		MENU_CALL		tDiveSetup,					do_menu_dive_dive		; dive setup
		MENU_CALL		tDecoSetup,					do_menu_dive_deco		; deco setup
		MENU_CALL		tSACSetup,					do_menu_dive_SAC		; SAC  setup
		MENU_CALL		tppO2Setup,					do_menu_dive_ppO2		; ppO2 limits
		MENU_CALL		tStopsSetup,				do_menu_dive_stops		; stops setup
		MENU_CALL		tBack,						do_return_main_menu
	MENU_END

;-----------------------------------------------------------------------------
; Dive Settings Menu - 2nd Layer - Dive Mode
;
do_menu_dive_dive:
 IFDEF _cave_mode
	MENU_BEGIN	tDiveModeMenu, .6
		MENU_OPT_INC	tDvMode,					oDiveMode				; dive mode
		MENU_OPT_INC	tCvMode,					oCaveMode				; cave mode
		MENU_OPT_INC	tFTTSMenu,					oExtraTime				; fTTS/delay
		MENU_OPT_INC	tTimeoutDive,				oDiveTimeout			; dive timeout
		MENU_OPT_INC	tStoreApnoeDive,			oStoreApnoe				; store apnoe
		MENU_CALL		tBack,						do_return_menu_dive
	MENU_END
 ELSE
	MENU_BEGIN	tDiveModeMenu, .5
		MENU_OPT_INC	tDvMode,					oDiveMode				; dive mode
		MENU_OPT_INC	tFTTSMenu,					oExtraTime				; fTTS/delay
		MENU_OPT_INC	tTimeoutDive,				oDiveTimeout			; dive timeout
		MENU_OPT_INC	tStoreApnoeDive,			oStoreApnoe				; store apnoe
		MENU_CALL		tBack,						do_return_menu_dive
	MENU_END
 ENDIF


;-----------------------------------------------------------------------------
; return to Dive Settings Menu from Sub-Menu
;
do_return_menu_dive_deco:
	call	menu_processor_double_pop	; drop exit line and back to last line
	;bra	do_menu_dive_deco				; continue


;-----------------------------------------------------------------------------
; Dive Settings Menu - 2nd Layer - Deco Mode
;
do_menu_dive_deco:
	MENU_BEGIN	tDecoSetup, .6
		MENU_OPT_INC	tDkMode,					oDecoMode					; ZH-L16 /GF
		MENU_OPT_INC	tSaturationMult,			osatmultgf					; saturation
		MENU_OPT_INC	tDesaturationMult,			odesatmultgf				; desaturation
		MENU_OPT_INC	tAltMode,					oAltMode					; altitude mode
		MENU_CALL		tGFMenu,					do_menu_dive_deco_GF		; GF settings
		MENU_CALL		tBack,						do_return_menu_dive
	MENU_END


;-----------------------------------------------------------------------------
; Dive Settings Menu - 3nd Layer - Deco Mode - GF Settings
;
do_menu_dive_deco_GF:
	MENU_BEGIN	tGFMenu, .6
		MENU_OPT_INC	tGF_low,					oGF_low						; GF  low
		MENU_OPT_INC	tGF_high,					oGF_high					; GF  high
		MENU_OPT_INC	taGFenable,					oEnable_aGF					; aGF selectable
		MENU_OPT_INC	taGF_low,					oaGF_low					; aGF low
		MENU_OPT_INC	taGF_high,					oaGF_high					; aGF high
		MENU_CALL		tBack,						do_return_menu_dive_deco
	MENU_END


;-----------------------------------------------------------------------------
; Dive Settings Menu - 2nd Layer - SAC Setup
;
do_menu_dive_SAC:
 IFDEF _gas_contingency
	MENU_BEGIN	tSACSetup, .6
		MENU_OPT_INC	tCalcGasNeeds,				oCalcAscGas					; calc.gas
		MENU_OPT_INC	tGasContingencyDive,		oGasContingencyDive			; switch tank if used up
		MENU_OPT_INC	tGasChangeTime,				oGasChangeTime				; gas change time
		MENU_OPT_INC	tSetWorkSAC,				oWork_SAC					; work SAC
		MENU_OPT_INC	tSetDecoSAC,				oDeco_SAC					; deco SAC
		MENU_CALL		tBack,						do_return_menu_dive
	MENU_END
 ELSE
	MENU_BEGIN	tSACSetup, .5
		MENU_OPT_INC	tCalcGasNeeds,				oCalcAscGas					; calc.gas
		MENU_OPT_INC	tGasChangeTime,				oGasChangeTime				; gas change time
		MENU_OPT_INC	tSetWorkSAC,				oWork_SAC					; work SAC
		MENU_OPT_INC	tSetDecoSAC,				oDeco_SAC					; deco SAC
		MENU_CALL		tBack,						do_return_menu_dive
	MENU_END
 ENDIF


;-----------------------------------------------------------------------------
; Dive Settings Menu - 2nd Layer - ppO2 Setup
;
do_menu_dive_ppO2:
 IFDEF _ccr_pscr
 IFDEF _helium
	MENU_BEGIN	tppO2Setup, .6
		MENU_DYNAMIC	dyn_ppo2_max,				do_toggle_ppO2_max_work		; max work
		MENU_DYNAMIC	dyn_ppo2_max_deco,			do_toggle_ppO2_max_deco		; max deco
		MENU_DYNAMIC	dyn_ppo2_min,				do_toggle_ppO2_min			; min OC
		MENU_DYNAMIC	dyn_ppo2_min_cc,			do_toggle_ppO2_min_cc		; min loop
		MENU_OPT_INC	tIBCDwarning,				oEnable_IBCD				; IBCD warning
		MENU_CALL		tBack,						do_return_menu_dive
	MENU_END
 ELSE
	MENU_BEGIN	tppO2Setup, .5
		MENU_DYNAMIC	dyn_ppo2_max,				do_toggle_ppO2_max_work		; max work
		MENU_DYNAMIC	dyn_ppo2_max_deco,			do_toggle_ppO2_max_deco		; max deco
		MENU_DYNAMIC	dyn_ppo2_min,				do_toggle_ppO2_min			; min OC
		MENU_DYNAMIC	dyn_ppo2_min_cc,			do_toggle_ppO2_min_cc		; min loop
		MENU_CALL		tBack,						do_return_menu_dive
	MENU_END
 ENDIF	; _helium
 ELSE
 IFDEF _helium
	MENU_BEGIN	tppO2Setup, .5
		MENU_DYNAMIC	dyn_ppo2_max,				do_toggle_ppO2_max_work		; max work
		MENU_DYNAMIC	dyn_ppo2_max_deco,			do_toggle_ppO2_max_deco		; max deco
		MENU_DYNAMIC	dyn_ppo2_min,				do_toggle_ppO2_min			; min OC
		MENU_OPT_INC	tIBCDwarning,				oEnable_IBCD				; IBCD warning
		MENU_CALL		tBack,						do_return_menu_dive
 ELSE
	MENU_BEGIN	tppO2Setup, .4
		MENU_DYNAMIC	dyn_ppo2_max,				do_toggle_ppO2_max_work		; max work
		MENU_DYNAMIC	dyn_ppo2_max_deco,			do_toggle_ppO2_max_deco		; max deco
		MENU_DYNAMIC	dyn_ppo2_min,				do_toggle_ppO2_min			; min OC
		MENU_CALL		tBack,						do_return_menu_dive
	MENU_END
 ENDIF	; _helium
 ENDIF	; _ccr_pscr


;-----------------------------------------------------------------------------
; dynamic Title - show maximum ppO2 - Work
;
dyn_ppo2_max:
	STRCAT_TEXT tPPO2Max				; print text
	movff	char_I_ppO2_max_work,lo		; get value
	movlw	ppo2_warning_high_default	; load default
	bra		dyn_ppo2_common				; continue with common part


;-----------------------------------------------------------------------------
; dynamic Title - show maximum ppO2 - Deco
;
dyn_ppo2_max_deco:
	STRCAT_TEXT tPPO2DECO				; print text
	movff	char_I_ppO2_max_deco,lo		; get value
	movlw	ppo2_warning_deco_default	; load default
	bra		dyn_ppo2_common				; continue with common part


;-----------------------------------------------------------------------------
; dynamic Title - show minimum ppO2
;
dyn_ppo2_min:
	STRCAT_TEXT tPPO2MIN				; print text
	movff	char_I_ppO2_min,lo			; get value
	movlw	ppo2_warning_low_default	; load default
	bra		dyn_ppo2_common				; continue with common part


 IFDEF _ccr_pscr

;-----------------------------------------------------------------------------
; dynamic Title - show minimum ppO2 - Loop Modes
;
dyn_ppo2_min_cc:
	STRCAT_TEXT tPPO2MINCC				; print text
	movff	char_I_ppO2_min_loop,lo		; get value
	movlw	ppo2_warning_loop_default	; load default
	;bra	dyn_ppo2_common				; continue with common part

 ENDIF


;-----------------------------------------------------------------------------
; Helper Function to all show ppO2 dynamic Titles
;
dyn_ppo2_common:
	movwf	up							; copy default to up
	clrf	hi							; clear hi
	bsf		leftbind					; print left-aligned
	bsf		decimal_digit2				; place a decimal point in front of digit 2
	output_256							; print ppO2 as x.xx
	STRCAT_TEXT tbar					; append unit
	movf	up,W						; get default value into WREG
	cpfseq	lo							; current value = default value ?
	bra		divesets_ppo2_common2		; NO  - add an "*"
	return								; YES - done
divesets_ppo2_common2:
	PUTC	"*"							; append a star
	return								; done


;-----------------------------------------------------------------------------
; Call Function - increment maximum ppO2 - Work
;
do_toggle_ppO2_max_work:				; add 0.1 bar
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


;-----------------------------------------------------------------------------
; Call Function - increment maximum ppO2 - Deco
;
do_toggle_ppO2_max_deco:				; add 0.1 bar
	movff	char_I_ppO2_max_deco,lo		; bank-safe copy
	movlw	.10
	addwf	lo,F
	movlw	ppo2_warning_deco_highest
	cpfsgt	lo
	bra		do_toggle_ppO2_max_deco2
	movlw	ppo2_warning_deco_lowest
	movwf	lo
do_toggle_ppO2_max_deco2:
	movff	lo,char_I_ppO2_max_deco
	return


;-----------------------------------------------------------------------------
; Call Function - increment minimum ppO2
;
do_toggle_ppO2_min:						; sub 0.1 bar
	movff	char_I_ppO2_min,lo			; bank-safe copy
	incf	lo,F
	movlw	ppo2_warning_low_highest
	cpfsgt	lo
	bra		do_toggle_ppO2_min2
	movlw	ppo2_warning_low_lowest
	movwf	lo
do_toggle_ppO2_min2:
	movff	lo,char_I_ppO2_min
	return


;-----------------------------------------------------------------------------
; Call Function - increment minimum ppO2 - Loop Modes
;
do_toggle_ppO2_min_cc:					; sub 0.1 bar
	movff	char_I_ppO2_min_loop,lo		; bank-safe copy
	incf	lo,F
	movlw	ppo2_warning_loop_highest
	cpfsgt	lo
	bra		do_toggle_ppO2_min_cc2
	movlw	ppo2_warning_loop_lowest
	movwf	lo
do_toggle_ppO2_min_cc2:
	movff	lo,char_I_ppO2_min_loop
	return


;-----------------------------------------------------------------------------
; Dive Settings Menu - 2nd Layer - Stops & Depth
;
do_menu_dive_stops:
	MENU_BEGIN	tStopsSetup, .6
		MENU_OPT_INC	tSafetyStop,				oSafetyStop					; safety stop
		MENU_OPT_INC	tExtendedStops,				oExtendedStops				; extended stops
		MENU_OPT_INC	tLastDecostop,				oLastDeco					; last deco stop
		MENU_OPT_INC	tDvSalinity,				oDiveSalinity				; salinity
		MENU_OPT_INC	tDepthWarn,					oMaxDepth					; depth limit
		MENU_CALL		tBack,						do_return_menu_dive
	MENU_END


;-----------------------------------------------------------------------------
; return to Settings Menu from Sub-Sub-Menu
;
do_return_menu_settings_deeper:			; entry point for return from info menu 2
	call	menu_processor_pop			; drop one more stack entry
	;bra	do_return_menu_settings		; continue


;-----------------------------------------------------------------------------
; return to Settings Menu from Sub-Menu
;
do_return_menu_settings:
	bcf		imprint_time_date			; stop imprinting of current time & date
	call	menu_processor_double_pop	; drop exit line and back to last line

 IFDEF _rx_mode
	bcf		tr_functions_activated		; set TR functions as deactivated by default
	btfss	ostc_rx_present				; TR model / TR module up & running?
	bra		do_menu_settings			; NO  - keep deactivated
	movff	opt_TR_mode,WREG			; YES - get TR mode
	tstfsz	WREG						;     - TR mode <> off ?
	bsf		tr_functions_activated		;       YES - set TR functions as activated
 ENDIF


;-----------------------------------------------------------------------------
; Settings Menu - 1st Layer
;
do_menu_settings:
 IFDEF _hwos_sport
	bsf		ble_available				; required for very old OSTC sport
 ENDIF
	btfsc	ble_available				; BT available?
	bra		do_menu_settings_bt			; YES - do BT menu

	MENU_BEGIN	tSystSets, .5
		MENU_CALL		tInfoMenu,					do_menu_info
		MENU_CALL		tSetTimeDate,				do_menu_date_time
		MENU_CALL		tDispSets,					do_menu_dispsets
		MENU_CALL		tSysSets,					do_menu_syssets
		MENU_CALL		tBack,						do_return_main_menu
	MENU_END

do_menu_settings_bt:
 IFDEF _rx_functions
	btfss	ostc_rx_present				; TR model and TR activated?
	bra		do_menu_settings_noRX		; NO

	MENU_BEGIN	tSystSets, .7
		MENU_CALL		tInfoMenu,					do_menu_info
		MENU_CALL		tBleTitle,					do_comm_mode_bt
		MENU_CALL		tTrSettings,				do_menu_settings_TR
		MENU_CALL		tSetTimeDate,				do_menu_date_time
		MENU_CALL		tDispSets,					do_menu_dispsets
		MENU_CALL		tSysSets,					do_menu_syssets
		MENU_CALL		tBack,						do_return_main_menu
	MENU_END
 ENDIF

do_menu_settings_noRX:
	MENU_BEGIN	tSystSets, .6
		MENU_CALL		tInfoMenu,					do_menu_info
		MENU_CALL		tBleTitle,					do_comm_mode_bt
		MENU_CALL		tSetTimeDate,				do_menu_date_time
		MENU_CALL		tDispSets,					do_menu_dispsets
		MENU_CALL		tSysSets,					do_menu_syssets
		MENU_CALL		tBack,						do_return_main_menu
	MENU_END


;-----------------------------------------------------------------------------
; Call Function - start Communication Mode (BT)
;
do_comm_mode_bt:
	goto	comm_mode_bt				; code hosted in comm.asm


;-----------------------------------------------------------------------------
; Settings Menu - 2nd Layer - System Infos - Page 1
;
do_menu_info:
 IFDEF _rx_functions
	btfss	ostc_rx_present				; TR model?
	bra		do_menu_info_noRX			; NO

	MENU_BEGIN	tInfoMenu, .7
		MENU_DYNAMIC	dyn_show_uptime,			0
		MENU_DYNAMIC	dyn_show_serial,			0
		MENU_DYNAMIC	dyn_show_firmware_ostc,		0
		MENU_DYNAMIC	dyn_show_fw_creation_date,	0
		MENU_DYNAMIC	dyn_show_firmware_rx,		0
		MENU_DYNAMIC	dyn_show_total_dives,		0
		MENU_CALL		tMore,						do_menu_info2
	MENU_END
 ENDIF

do_menu_info_noRX:
	MENU_BEGIN	tInfoMenu, .6
		MENU_DYNAMIC	dyn_show_uptime,			0
		MENU_DYNAMIC	dyn_show_serial,			0
		MENU_DYNAMIC	dyn_show_firmware_ostc,		0
		MENU_DYNAMIC	dyn_show_fw_creation_date,	0
		MENU_DYNAMIC	dyn_show_total_dives,		0
		MENU_CALL		tMore,						do_menu_info2
	MENU_END


;-----------------------------------------------------------------------------
; dynamic Title - show Uptime
;
dyn_show_uptime:
	STRCAT_TEXT tUptime					; print title
	SMOVQQ	uptime,xC					; ISR-safe copy of uptime:4 to xC:4
	goto	output_secs_as_days_hours	; print seconds as days and hours and return


;-----------------------------------------------------------------------------
; dynamic Title - show Uptime
;
dyn_show_serial:
	STRCAT_TEXT tSerial					; print title
	goto	TFT_cat_serial				; print serial number and return

;-----------------------------------------------------------------------------
; dynamic Title - show Firmware Version
;
dyn_show_firmware_ostc:
	STRCAT_TEXT tFirmware				; print title
	call	TFT_cat_firmware			; print firmware version
	PUTC	" "							; print a dot
	goto	TFT_cat_beta_short			; print beta/release state and return


;-----------------------------------------------------------------------------
; dynamic Title - show Firmware creation Date
;
dyn_show_fw_creation_date:
	STRCAT_TEXT tFirmwareDate			; print title
	movlw	firmware_creation_year		; get firmware creation year
	movwf	lo							; copy to lo
	movlw	firmware_creation_month		; get firmware creation month
	movwf	hi							; copy to hi
	movlw	firmware_creation_day		; get firmware creation day
	movwf	up							; copy to up
	goto	output_date					; print date and return


 IFDEF _rx_functions

;-----------------------------------------------------------------------------
; dynamic Title - show RX Firmware Version  (also used by start.asm)
;
	global	dyn_show_firmware_rx
dyn_show_firmware_rx:
	STRCAT_TEXT tFirmware_rx			; print title
	movff	rx_firmware_cur_major,lo	; get major version
	bsf		leftbind					; print left-aligned
	output_99							; print major (0-99)
	PUTC	'.'							; print a dot
	movff	rx_firmware_cur_minor,lo	; get minor
	output_99x							; print minor (00-99)
	return								; done

 ENDIF	; _rx_functions


;-----------------------------------------------------------------------------
; dynamic Title - show total Number of Dives
;
dyn_show_total_dives:
	STRCAT_TEXT tTotalDives				; print title
	call	eeprom_total_dives_read		; read total number of dives
	bsf		leftbind					; print left-aligned
	output_65535						; print number of total dives (0-65535)
	return								; done


;-----------------------------------------------------------------------------
; Settings Menu - 2nd Layer - System Infos - Page 2
;
do_menu_info2:
 IFNDEF _comm_debug
	MENU_BEGIN	tInfoMenu, .5
		MENU_DYNAMIC	dyn_show_battery_volts,		0
		MENU_DYNAMIC	dyn_show_config,			0
		MENU_DYNAMIC	dyn_show_sensor_calib,		0
		MENU_DYNAMIC	dyn_show_sensor_offset,		0
		MENU_CALL		tBack,						do_return_menu_settings_deeper
	MENU_END
 ELSE
	MENU_BEGIN	tInfoMenu, .6
		MENU_DYNAMIC	dyn_show_battery_volts,		0
		MENU_DYNAMIC	dyn_show_config,			0
		MENU_DYNAMIC	dyn_show_sensor_calib,		0
		MENU_DYNAMIC	dyn_show_sensor_offset,		0
		MENU_OPT_INC	tCommTimeout,				oCommTimeout
		MENU_CALL		tBack,						do_return_menu_settings_deeper
	MENU_END
 ENDIF


;-----------------------------------------------------------------------------
; dynamic Title - show Battery Volts and Type
;
dyn_show_battery_volts:
	STRCAT_TEXT tBatteryV				; print text
	MOVII	batt_voltage,mpr			; get battery voltage
	bsf		decimal_digit3				; place a decimal point in front of digit 3
	bsf		omit_digit_1				; do not print 1st digit
	output_9999							; print as x.yy-
	STRCAT	" V(T"						; append fix legend
	movff	battery_type,lo				; =0:1.5V, =1:3.6V Saft, =2:LiIon 3.7V/0.8Ah, =3:LiIon 3.7V/3.1Ah, =4: LiIon 3.7V/2.3Ah
	output_9							; print battery type code (0-9)
	PUTC	")"							; append fix legend
	return								; done


;-----------------------------------------------------------------------------
; dynamic Title - show Hardware / Software Configuration
;
dyn_show_config:
	STRCAT_TEXT tHardware				; print  text
	call	I2C_init_compass			; start compass to get compass configuration
	movf	HW_descriptor,W				; copy hardware descriptor to WREG
	output_hex							; print as hex
	movf	HW_variants,W				; copy hardware variants   to WREG
	output_hex							; print as hex
	PUTC	"-"							; print a separator
	movlw	FW_CONF						; get firmware configuration
	output_hex							; print as hex
	call	get_cpu_version				; get CPU version
	output_hex							; print as hex
	return								; done


;-----------------------------------------------------------------------------
; dynamic Title - show Pressure Sensor Calibration Data C1 and C5
;
dyn_show_sensor_calib:
	STRCAT_TEXT tSensorC				; print  label
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
; dynamic Title - show Pressure Sensor Offset Setting
;
dyn_show_sensor_offset:
	STRCAT_TEXT tSensorD				; print  label
	movff	opt_pressure_adjust,lo		; get pressure sensor offset
	movf	lo,F						; excite flags
	bz		dyn_show_sensor_offset_zero	; sensor offset = 0
	bn		dyn_show_sensor_offset_neg	; sensor offset < 0
	;bnn	dyn_show_sensor_offset_pos	; sensor offset > 0
dyn_show_sensor_offset_pos:
	PUTC	"+"							; print plus sign
	bra		dyn_show_sensor_offset_com	; continue with common part
dyn_show_sensor_offset_zero:
	PUTC	" "							; print a space
	bra		dyn_show_sensor_offset_com	; continue with common part
dyn_show_sensor_offset_neg:
	PUTC	"-"							; print a minus sign
	negf	lo							; negate lo
	;bra	dyn_show_sensor_offset_com	; continue with common part
dyn_show_sensor_offset_com:
	PUTC	" "							; print a space
	bsf		leftbind					; print left-aligned
	output_99							; print value (0-99)
	PUTC	" "							; print a space
	STRCAT_TEXT tMBAR					; print unit
	return								; done


 IFDEF _rx_functions

;-----------------------------------------------------------------------------
; Settings Menu - 2nd Layer - TR Settings
;
do_menu_settings_TR:
	movff	opt_dive_mode,WREG			; get dive mode: 0=OC, 1=CCR, 2=Gauge, 3=Apnea, 4=pSCR
	incf	WREG,W						; add 1
	dcfsnz	WREG,W						; subtract one, became zero?
	bra		do_menu_settings_TR_MaxDelta; YES - OC
	dcfsnz	WREG,W						; subtract one, became zero?
	bra		do_menu_settings_TR_BailPres; YES - CCR
	dcfsnz	WREG,W						; subtract one, became zero?
	bra		do_menu_settings_TR_MaxDelta; YES - Gauge
	dcfsnz	WREG,W						; subtract one, became zero?
	bra		do_menu_settings_TR_abort	; YES - Apnea, abort
	dcfsnz	WREG,W						; subtract one, became zero?
	bra		do_menu_settings_TR_both	; YES - pSCR

do_menu_settings_TR_abort:
	call	menu_processor_pop			; drop button press
	bra		do_menu_settings			; back to same menu


;-----------------------------------------------------------------------------
; Settings Menu - 3rd Layer - TR Settings - Sidemount Mode
;
do_menu_settings_TR_MaxDelta:			; menu with oTrMaxDeltaPres
	MENU_BEGIN	tTrSettings, .5
		MENU_OPT_INC	tTrMode,					oTrMode
		MENU_OPT_INC	tTr1stPres,					oTr1stPres
		MENU_OPT_INC	tTr2ndPres,					oTr2ndPres
		MENU_DYNAMIC	dyn_toggle_max_pres_diff,	do_toggle_max_pres_diff
		MENU_CALL		tBack,						do_return_menu_settings
	MENU_END


;-----------------------------------------------------------------------------
; Settings Menu - 3rd Layer - TR Settings - CCR Mode
;
do_menu_settings_TR_BailPres:			; menu with oTrBailPres
	MENU_BEGIN	tTrSettings, .5
		MENU_OPT_INC	tTrMode,					oTrMode
		MENU_OPT_INC	tTr1stPres,					oTr1stPres
		MENU_OPT_INC	tTr2ndPres,					oTr2ndPres
		MENU_OPT_INC	tTrBailPres,				oTrBailPres
		MENU_CALL		tBack,						do_return_menu_settings
	MENU_END


;-----------------------------------------------------------------------------
; Settings Menu - 3rd Layer - TR Settings - pSCR Mode
;
do_menu_settings_TR_both:				; menu with oTrBailPres and oTrMaxDeltaPres
	MENU_BEGIN	tTrSettings, .6
		MENU_OPT_INC	tTrMode,					oTrMode
		MENU_OPT_INC	tTr1stPres,					oTr1stPres
		MENU_OPT_INC	tTr2ndPres,					oTr2ndPres
		MENU_OPT_INC	tTrBailPres,				oTrBailPres
		MENU_DYNAMIC	dyn_toggle_max_pres_diff,	do_toggle_max_pres_diff
		MENU_CALL		tBack,						do_return_menu_settings
	MENU_END


;-----------------------------------------------------------------------------
; dynamic Title - max. Delta Pressure for Swap Tanks Advice
;
dyn_toggle_max_pres_diff:
	movff	opt_TR_mode,WREG			; get TR mode
	xorlw	.2							; compare with 2 (ind.double)
	tstfsz	WREG						; equal?
	FONT_COLOR_DISABLED					; NO - print in disabled color
	STRCAT_TEXT tTrMaxDeltaP			; output label
	movff	char_I_max_pres_diff,lo		; get configured deltaP
	output_99							; print deltaP (0-99)
	STRCAT_TEXT tbar					; append " bar"
	return								; done


;-----------------------------------------------------------------------------
; Call Function - adjust max. Delta Pressure for Swap Tanks Advice
;
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


;-----------------------------------------------------------------------------
; return to Settings Menu from Sub-Menu
;
do_return_menu_date_time:
	call	menu_processor_double_pop	; drop exit line and back to last line


;-----------------------------------------------------------------------------
; Settings Menu - 2nd Layer - set Time & Date
;
do_menu_date_time:
	bsf		imprint_time_date			; start imprinting current time & date
	bcf		block_option_value			; resume displaying of option values

	MENU_BEGIN	tSetTimeDate, .4
		MENU_CALL		tSetTime,					do_menu_set_time
		MENU_CALL		tSetDate,					do_menu_set_date
		MENU_OPT_INC	tDateFormat,				oDateFormat
		MENU_CALL		tBack,						do_return_menu_settings
	MENU_END


;-----------------------------------------------------------------------------
; Settings Menu - 3rd Layer - set Time & Date - set Time
;
do_menu_set_time:
	bsf		block_option_value			; suspend displaying of option values

	MENU_BEGIN	tSetTime, .4
		MENU_OPT_INC	tSetHours,					oSetHours
		MENU_OPT_INC	tSetMinutes,				oSetMinutes
		MENU_OPT_INC	tSetSeconds,				oClearSeconds
		MENU_CALL		tBack,						do_return_menu_date_time
	MENU_END


;-----------------------------------------------------------------------------
; Settings Menu - 3rd Layer - set Time & Date - set Date
;
do_menu_set_date:
	bsf		block_option_value			; suspend displaying of option values

	MENU_BEGIN	tSetDate, .4
		MENU_OPT_INC	tSetDay,					oSetDay
		MENU_OPT_INC	tSetMonth,					oSetMonth
		MENU_OPT_INC	tSetYear,					oSetYear
		MENU_CALL		tBack,						do_return_menu_date_time
	MENU_END


;-----------------------------------------------------------------------------
; return to Display Settings from Sub-Menu
;
do_return_dispsets_menu:
	bcf		imprint_color_schemes		; deactivate color schemes demonstration
	call	menu_processor_double_pop	; drop exit line and back to last line
	;bra	do_menu_dispsets			; continue


;-----------------------------------------------------------------------------
; Settings Menu - 2nd Layer - Display Settings - Page 1
;
do_menu_dispsets:
 IF _language_2!=none
	MENU_BEGIN	tDispSets, .7
		MENU_OPT_INC	tBright,					oBrightness
		MENU_OPT_INC	tLayout,					oLayout
		MENU_OPT_INC	tUnits,						oUnits
		MENU_OPT_INC	tLanguage,					oLanguage
		MENU_OPT_INC	tFlip,						oFlipScreen
		MENU_CALL		tColorScheme,				do_menu_color_scheme
		MENU_CALL		tMore,						do_menu_dispsets_more
	MENU_END
 ELSE
	MENU_BEGIN	tDispSets, .6
		MENU_OPT_INC	tBright,					oBrightness
		MENU_OPT_INC	tLayout,					oLayout
		MENU_OPT_INC	tUnits,						oUnits
		MENU_OPT_INC	tFlip,						oFlipScreen
		MENU_CALL		tColorScheme,				do_menu_color_scheme
		MENU_CALL		tMore,						do_menu_dispsets_more
	MENU_END
 ENDIF


;-----------------------------------------------------------------------------
; Settings Menu - 3rd Layer - Display Settings - Color Schemes
;
do_menu_color_scheme:
	bsf		imprint_color_schemes		; activate color schemes demonstration

	; menu with 4 leading empty menu lines to give space for the color scheme imprinting
	MENU_BEGIN_OFFSET	tColorScheme, .2, .4
		MENU_OPT_INC	tColorSetDive,				oColorSetDive
		MENU_CALL		tBack,						do_return_dispsets_menu
	MENU_END


;-----------------------------------------------------------------------------
; Settings Menu - 2nd Layer - Display Settings - Page 2
;
do_menu_dispsets_more:
 IFDEF _helium
	MENU_BEGIN	tDispSets, .7
		MENU_OPT_INC	tVSIgraph,					oVSIgraph
		MENU_OPT_INC	tVSItext2,					oVSItext
		MENU_OPT_INC	tShowppO2,					oShowppO2
		MENU_OPT_INC	tDepthWarning,				oDepthWarn
		MENU_OPT_INC	t2ndDepth,					o2ndDepthDisp
		MENU_OPT_INC	tTissueGraphics,			oTissueGraphics
		MENU_CALL		tBack,						do_return_menu_settings_deeper
	MENU_END
 ELSE
	MENU_BEGIN	tDispSets, .6
		MENU_OPT_INC	tVSIgraph,					oVSIgraph
		MENU_OPT_INC	tVSItext2,					oVSItext
		MENU_OPT_INC	tShowppO2,					oShowppO2
		MENU_OPT_INC	tDepthWarning,				oDepthWarn
		MENU_OPT_INC	t2ndDepth,					o2ndDepthDisp
		MENU_CALL		tBack,						do_return_menu_settings_deeper
	MENU_END
 ENDIF


;-----------------------------------------------------------------------------
; return to System Settings Menu from Sub-Sub-Menu
;
do_return_menu_syssets_more_more:		; entry point for returns from reset sub-menu
	call	menu_processor_pop			; drop one more stack entry
	;bra	do_return_menu_syssets_more	; continue


;-----------------------------------------------------------------------------
; return to System Settings Menu from Sub-Menu
;
do_return_menu_syssets_more:
	call	menu_processor_double_pop	; drop exit line and back to last line
	bra		do_menu_syssets				; continue


;-----------------------------------------------------------------------------
; return to System Settings Menu from Piezo-Sub-Menu
;
do_return_menu_syssets_piezo:
	call	menu_processor_double_pop	; drop exit line and back to last line
	call	TFT_ClearScreen				; clear the screen
	call	piezo_config				; configure buttons
	;bra	do_menu_syssets				; continue


;-----------------------------------------------------------------------------
; Settings Menu - 2nd Layer - System Settings
;
do_menu_syssets:
	btfsc	battery_gauge_available		; piezo buttons available?
	bra		do_menu_syssets_piezo		; YES

 IFDEF _compass
	MENU_BEGIN	tSystSets, .4													; All MENU_CALLs in this menu
		MENU_CALL		tCompassMenu,				do_menu_compass				; need to stay together on this
		MENU_CALL		tLogOffset,					do_menu_log_offset			; menu level in order to not
		MENU_CALL		tResetMenu,					do_menu_reset				; mess up the menu stack on doing
		MENU_CALL		tBack,						do_return_menu_settings		; the do_return_menu_settings !
	MENU_END
 ELSE
	MENU_BEGIN	tSystSets, .3													; see above
		MENU_CALL		tLogOffset,					do_menu_log_offset			;
		MENU_CALL		tResetMenu,					do_menu_reset				;
		MENU_CALL		tBack,						do_return_menu_settings		;
	MENU_END
 ENDIF	; _compass

do_menu_syssets_piezo:
 IFDEF _compass
	MENU_BEGIN	tSystSets, .5
		MENU_CALL		tCompassMenu,				do_menu_compass				; see above
		MENU_CALL		tLogOffset,					do_menu_log_offset			;
		MENU_CALL		tResetMenu,					do_menu_reset				;
		MENU_CALL		tPiezo,						do_menu_piezo				;
		MENU_CALL		tBack,						do_return_menu_settings		;
	MENU_END
 ELSE
	MENU_BEGIN	tSystSets, .4
		MENU_CALL		tLogOffset,					do_menu_log_offset			; see above
		MENU_CALL		tResetMenu,					do_menu_reset				;
		MENU_CALL		tPiezo,						do_menu_piezo				;
		MENU_CALL		tBack,						do_return_menu_settings		;
	MENU_END
 ENDIF


 IFDEF _compass

;-----------------------------------------------------------------------------
; Settings Menu - 3rd Layer - System Settings - Compass
;
do_menu_compass:
	MENU_BEGIN	tCompassMenu, .5
		MENU_CALL		tCompassCalibration,		do_compass_calibration
;		MENU_OPT_INC	tCompassGain,				oCompassGain
		MENU_DYNAMIC	dyn_compass_cal_x,			0
		MENU_DYNAMIC	dyn_compass_cal_y,			0
		MENU_DYNAMIC	dyn_compass_cal_z,			0
		MENU_CALL		tBack,						do_return_menu_syssets_more
	MENU_END


;-----------------------------------------------------------------------------
; Call Function - start Compass Calibration
;
do_compass_calibration:
	goto	compass_calibration			; code hosted in compass_ops.asm


;-----------------------------------------------------------------------------
; dynamic Title - Calibration Value X
;
dyn_compass_cal_x:
	STRCAT_TEXT tCalX					; print label
	lfsr	FSR0,compass_CX_f			; address calibration value X
	bra		dyn_compass_cal_common		; continue with common part


;-----------------------------------------------------------------------------
; dynamic Title - Calibration Value Y
;
dyn_compass_cal_y:
	STRCAT_TEXT tCalY					; print label
	lfsr	FSR0,compass_CY_f			; address calibration value Y
	bra		dyn_compass_cal_common		; continue with common part


;-----------------------------------------------------------------------------
; dynamic Title - Calibration Value Z
;
dyn_compass_cal_z:
	STRCAT_TEXT tCalZ					; print label
	lfsr	FSR0,compass_CZ_f			; address calibration value Z
	;bra	dyn_compass_cal_common		; continue with common part


;-----------------------------------------------------------------------------
; Helper Function to dynamic Titles - Calibration Value
;
dyn_compass_cal_common:
	movff	POSTINC0,lo					; read calibration value, low  byte
	movff	POSTINC0,hi					; read calibration value, high byte
	PUTC	':'							; print ":"
	PUTC	' '							; print a space
	call	convert_signed_16bit		; convert lo:hi into signed-short and adds '-' to POSTINC2 if required
	btfsc	neg_flag					; value negative?
	bra		dyn_compass_cal_common_1	; YES - print value
	PUTC	'+'							; NO  - add a plus sign
dyn_compass_cal_common_1:
	output_65535						; print value
	return								; done

 ENDIF	; _compass


;-----------------------------------------------------------------------------
; Settings Menu - 3rd Layer - System Settings - Logbook Offset
;
do_menu_log_offset:

	clrf	WREG						; select an initial step size of 1
	movff	WREG,opt_logoffset_step		; bank-safe write to option variable (volatile option)

	MENU_BEGIN	tLogOffset, .5
		MENU_DYNAMIC	dyn_logoffset_show_value,	0
		MENU_OPT_INC	tLogOffStepSize,			oLogOffsetStep
		MENU_CALL		tLogOffsetplus,				do_log_offset_plus
		MENU_CALL		tLogOffsetminus,			do_log_offset_minus
		MENU_CALL		tBack,						do_return_menu_syssets_more
	MENU_END


;-----------------------------------------------------------------------------
; dynamic Title - show Logbook Offset
;
dyn_logoffset_show_value:
	STRCPY_TEXT tLogOffsetValue			; print "Offset" in selected language
	call	eeprom_log_offset_read		; read  offset into lo:hi
	output_9999							; print offset (0-9999)
	return								; no "_PRINT" here...


;-----------------------------------------------------------------------------
; Call Function - increment Logbook Offset
;
do_log_offset_plus:
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


;-----------------------------------------------------------------------------
; Call Function - decrement Logbook Offset
;
do_log_offset_minus:
	rcall	do_logoffset_common			; load current offset and step size
	; subtract step size from current offset
	movf	mpr+2,W						; get step size,        low  byte
	subwf	mpr+0,F						; subtract from offset, low byte
	movf	mpr+3,W						; get step size,        high byte
	subwfb	mpr+1,F						; subtract from offset, high byte, considering borrow flag
	; check if new offset is within limit
	btfsc	STATUS,C					; borrow to propagate (B == /CARRY) ?
	bra		do_logoffset_exit			; NO  - result >= 0, store and return
	;bra	do_logoffset_reset			; YES - revert offset to 0


;-----------------------------------------------------------------------------
; Helper Functions - Logbook Offset Reset & Write-Back
;
do_logoffset_reset:
	CLRI	mpr							; set   offset to 0
do_logoffset_exit:
	goto	eeprom_log_offset_write		; store offset and return


;-----------------------------------------------------------------------------
; Helper Function - compute Step Size
;
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
	movlw	LOW .1000					; NO  - set a step size of 1000, low  byte
	movwf	mpr+2						;     - copy to step size,       low  byte
	movlw	HIGH .1000					;     - set a step size of 1000, high byte
	movwf	mpr+3						;     - copy to step size,       high byte
	return								;     - done


;-----------------------------------------------------------------------------
; Settings Menu - 3rd Layer - System Settings - adjust Piezo Buttons
;
do_menu_piezo:
	MENU_BEGIN	tPiezo, .3
		MENU_OPT_INC	tButtonleft,				ocR_button_left				; left  button sensitivity
		MENU_OPT_INC	tButtonright,				ocR_button_right			; right button sensitivity
		MENU_CALL		tBack,						do_return_menu_syssets_piezo
	MENU_END


;-----------------------------------------------------------------------------
; Settings Menu - 3rd Layer - System Settings - Reset Menus
;
do_menu_reset:
	MENU_BEGIN	tResetMenu, .6
		MENU_CALL		tBack,						do_return_menu_syssets_more
		MENU_CALL		tReboot,					do_menu_reset_reboot	; confirm
		MENU_CALL		tResetDeco,					do_menu_reset_deco		; confirm
		MENU_CALL		tResetSettings,				do_menu_reset_settings	; confirm
		MENU_CALL		tResetLogbook,				do_menu_reset_logbook	; confirm
		MENU_CALL		tResetBattery,				do_menu_reset_battery	; confirm
	MENU_END


;-----------------------------------------------------------------------------
; Settings Menu - 4th Layer - System Settings - Reset - Reboot / FW Recovery
;
do_menu_reset_reboot:
 IFDEF _firmware_recovery
	MENU_BEGIN	tResetMenu2, .4
		MENU_CALL		tAbort,						do_return_menu_syssets_more_more
		MENU_CALL		tRebootCurFirmware,			do_reboot				; reboot  current firmware
		MENU_DYNAMIC	dyn_menu_fw_backup,			do_firmware_backup		; backup  current firmware
		MENU_DYNAMIC	dyn_menu_fw_restore,		do_firmware_restore		; restore backup  firmware
	MENU_END
 ELSE
	MENU_BEGIN	tResetMenu2, .2
		MENU_CALL		tAbort,						do_return_menu_syssets_more_more
		MENU_CALL		tReboot,					do_reboot				; reboot (cold start)
	MENU_END
 ENDIF


;-----------------------------------------------------------------------------
; Call Function - Reboot
;
do_reboot:
	call	ext_flash_enable_protection	; set write protection on external flash
	call	eeprom_deco_data_write		; update deco data     in EEPROM
	call	eeprom_battery_gauge_write	; update battery gauge in EEPROM
	btfsc	option_changed				; do the options need to be stored to EEPROM ?
	call	option_check_and_store_all	; YES - check and store all option values in EEPROM
	reset								; cold-start the processor


 IFDEF _firmware_recovery

;-----------------------------------------------------------------------------
; dynamic Title - Firmware Backup Option
;
dyn_menu_fw_backup:
	EEPROM_CC_READ eeprom_fw_chksum_current+.5,WREG		; read     stored  FW ID
	xorlw	FW_ID										; XOR with current FW ID, equal?
	bnz		dyn_menu_fw_backup_unable					; NO  - unable to make a backup
	STRCPY_TEXT tBackupFirmware							; YES - print "Backup current Firmware"
	return												;     - done
dyn_menu_fw_backup_unable:
	STRCPY	"-------"									; print dashes
	return												; done


;-----------------------------------------------------------------------------
; dynamic Title - Firmware Restore Option
;
dyn_menu_fw_restore:
	STRCPY_TEXT tRecoverFirmware		; print "Recover"
	PUTC	" "							; add a space
	PUTC	"V"							; add a V for Version
	movlw	0x3C						; address firmware version in backup storage at 0x3C000A
	movwf	ext_flash_address+2			; ...
	clrf	ext_flash_address+1			; ...
	movlw	0x0A						; ...
	movwf	ext_flash_address+0			; ...
	FLASH_RR_READ mpr,.3				; read backup firmware version (lo: major, hi: minor, up: beta)
	infsnz	lo,W						; major = 0xFF ?
	bra		dyn_menu_fw_restore_inop	; YES - no version to show
	bsf		leftbind					; NO  - print left-aligned
	output_99							;     - print major (0-99)
	PUTC	'.'							;     - add a dot
	movff	hi,lo						;     - get minor
	output_99x							;     - print minor (00-99)
	PUTC	' '							;     - add a space
	movff	up,lo						;     - get beta/release
	tstfsz	lo							;    -  release version?
	bra		dyn_menu_fw_restore_beta	;     - NO  - beta
	STRCAT	"Rel."						;     - YES - append "Rel(ease)"
	return								;           - done
dyn_menu_fw_restore_beta:
	PUTC	'B'							; append "B(eta)"
	bsf		leftbind					; print left-aligned
	output_256							; print beta version (0-255)
	return								; done
dyn_menu_fw_restore_inop:
	STRCAT	"--.--"						; no recovery firmware available
	return								; done


;-----------------------------------------------------------------------------
; Call Function - backup Firmware
;
do_firmware_backup:
	EEPROM_CC_READ eeprom_fw_chksum_current+.5,WREG		; read     stored  FW ID
	xorlw	FW_ID										; XOR with current FW ID, equal?
	bnz		do_firmware_abort							; NO  - abort
	call	TFT_ClearScreen								; YES - clear the screen
	WIN_SMALL .0, .100									;     - set position
	STRCPY_TEXT_PRINT tBackingUp						;     - print "backing up..."
	call	copy_fw_active_to_backup					;     - copy 0x3Exxxx -> 0x3Cxxxx
	EEPROM_RR_READ  eeprom_fw_chksum_current,buffer,.6	;     - retrieve checksum of current  firmware
	EEPROM_RR_WRITE buffer,eeprom_fw_chksum_recovry,.6	;     - store as checksum of recovery firmware
	bra		do_return_menu_syssets_more_more			;     - done


;-----------------------------------------------------------------------------
; Call Function - restore Firmware
;
do_firmware_restore:
	EXT_FLASH_ADDR 0x3C000A								; address firmware version in backup storage at 0x3C000A
	FLASH_CW_READ_0x40									; read backup firmware major version into WREG
	infsnz	WREG										; major = 0xFF ?
	bra		do_firmware_abort							; YES - abort, no firmware available for restoration
	call	TFT_ClearScreen								; NO  - clear the screen
	WIN_SMALL .0, .100									;     - set position
	STRCPY_TEXT_PRINT tRestoring						;     - print "restoring..."
	call	copy_fw_backup_to_active					;     - copy 0x3Cxxxx -> 0x3Exxxx
	EEPROM_RR_READ  eeprom_fw_chksum_recovry,buffer,.6	;     - retrieve checksum of recovery firmware
	EEPROM_RR_WRITE buffer,eeprom_fw_chksum_current,.6	;     - store as checksum of current  firmware (to be)
	goto	comm_firmware_update_exec					;     - initiate firmware update


;-----------------------------------------------------------------------------
; Helper Function - back to same menu
;
do_firmware_abort:
	call	menu_processor_pop							; back to last line
	bra		do_menu_reset_reboot						; back to same menu

 ENDIF


;-----------------------------------------------------------------------------
; Settings Menu - 4th Layer - System Settings - Reset - Reset Deco
;
do_menu_reset_deco:
	MENU_BEGIN	tResetMenu2, .2
		MENU_CALL		tAbort,						do_return_menu_syssets_more_more
		MENU_CALL		tResetDeco,					do_reset_deco			; reset deco and return to main reset menu
	MENU_END


;-----------------------------------------------------------------------------
; Call Function - Reset Deco
;
do_reset_deco:
	call	deco_clear_tissue			; set all tissues to absolute pressure * N2_ratio           (C-code)
	call	deco_calc_dive_interval_1min; update tissues by 1 minute to calculate current GF factor (C-code)
	call	deco_calc_desaturation_time	; calculate desaturation and no-fly/no-altitude time        (C-code)
	banksel	common
	call	eeprom_deco_data_write		; store updated deco data into EEPROM
	bra		do_return_menu_syssets_more_more


;-----------------------------------------------------------------------------
; Settings Menu - 4th Layer - System Settings - Reset - Reset Settings
;
do_menu_reset_settings:
	MENU_BEGIN	tResetMenu2, .2
		MENU_CALL		tAbort,						do_return_menu_syssets_more_more
		MENU_CALL		tResetSettings,				do_reset_settings		; reset all settings and go to surface mode
	MENU_END


;-----------------------------------------------------------------------------
; Call Function - Reset Settings
;
do_reset_settings:
	call	TFT_ClearScreen				; clear screen to show start of activity
	call	option_reset_all			; reset all options to factory default
	call	do_logoffset_reset			; reset log offset
	goto	restart						; restart into surface mode


;-----------------------------------------------------------------------------
; Settings Menu - 4th Layer - System Settings - Reset - Reset Logbook
;
do_menu_reset_logbook:
	MENU_BEGIN	tResetMenu2, .2
		MENU_CALL		tAbort,						do_return_menu_syssets_more_more
		MENU_CALL		tResetLogbook,				do_reset_logbook		; reset logbook and return to main reset menu
	MENU_END


;-----------------------------------------------------------------------------
; Call Function - Reset Logbook
;
do_reset_logbook:
	call	erase_complete_logbook		; erase complete logbook
	bra		do_return_menu_syssets_more_more


;-----------------------------------------------------------------------------
; Settings Menu - 4th Layer - System Settings - Reset - Reset Battery
;
do_menu_reset_battery:
	MENU_BEGIN	tNewBattTitle, .2
		MENU_CALL		tAbort,						do_return_menu_syssets_more_more
		MENU_CALL		tYes,						do_new_battery_select
	MENU_END


;-----------------------------------------------------------------------------
; Entry Point for Battery Selection after Power-Outage
;
	global	new_battery_select
new_battery_select:
	call	TFT_boot					; initialize TFT (includes clear screen)
	call	TFT_Display_FadeIn			; dim up the display
	call	menu_processor_reset		; reset menu stack
	;bra	do_new_battery_select		; enter menu system


;-----------------------------------------------------------------------------
; Settings Menu - 5th Layer - System Settings - Reset - Reset - Battery Selection
;
do_new_battery_select:
	movlw	.100						; set battery level to full
	movwf	batt_percent				; ...
										; default (in cases of timeout or USB) to use old battery:
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

	movlw	0x11						; OSTC 2 (2015 model)
	cpfseq	HW_descriptor
	bra		$+4
	bra		use_18650_battery

	movlw	0x91						; OSTC 2 (2015 model) with block write
	cpfseq	HW_descriptor
	bra		$+4
	bra		use_18650_battery

	movlw	0x05						; OSTC 2 cR
	cpfseq	HW_descriptor
	bra		$+4
	bra		use_18650_battery

	movlw	0x85						; OSTC 2 cR with block write
	cpfseq	HW_descriptor
	bra		$+4
	bra		use_18650_battery

	movlw	0xB3						; OSTC 2 TR
	cpfseq	HW_descriptor
	bra		$+4
	bra		do_use_16650_battery

	movlw	0x93						; OSTC 2 (2017 model)
	cpfseq	HW_descriptor
	bra		$+4
	bra		do_use_16650_battery

	movlw	0x13						; OSTC Plus						TODO: and OSTC 2 new model as of now
	cpfseq	HW_descriptor
	bra		$+4
	bra		do_menu_new_battery_AA_charger

	; movlw	0x0A						; OSTC 3 (USB model)
	; cpfseq	HW_descriptor
	; bra		$+4
	; bra		do_menu_new_battery_AA_no_charge

	; movlw	0x1A						; OSTC 3 (BLE model)
	; cpfseq	HW_descriptor
	; bra		$+4
	; bra		do_menu_new_battery_AA_no_charge

	; movlw	0x02						; OSTC Sport (USB model)
	; cpfseq	HW_descriptor
	; bra		$+4
	; bra		do_menu_new_battery_AA_no_charge

	; movlw	0x52						; OSTC Sport (BLE model)
	; cpfseq	HW_descriptor
	; bra		$+4
	; bra		do_menu_new_battery_AA_no_charge

	bra		do_menu_new_battery_AA_no_charge	; any other model


;-----------------------------------------------------------------------------
; return from confirm 3.6 V rechargeable
;
do_return_menu_new_bat_AA_chrg:
	call	menu_processor_double_pop		; drop exit line and back to last line
	;bra	do_menu_new_battery_AA_charger	; continue

;-----------------------------------------------------------------------------
; Battery Selection for OSTC Plus (charging function)								TODO: and OSTC 2 new model as of now
;
do_menu_new_battery_AA_charger:
	MENU_BEGIN	tNewBattTitle, .4
		MENU_CALL		tNewBattOld,				do_use_old_battery				; load data of old battery
		MENU_CALL		tNewBattNew15,				do_use_15V_disposable			; not rechargeable
;		MENU_CALL		tNewBattNew36,				do_use_36V_disposable			; not rechargeable  -> not allowed any more !!!
		MENU_CALL		tNewBattAccu,				do_menu_new_battery_36V_charge	; rechargeable      -> goto safety question
		MENU_CALL		tNew16650,					do_use_16650_battery			; OSTC 2 new model	TODO: remove when OSTC 2 new model can be separated from Plus
	MENU_END


;-----------------------------------------------------------------------------
; Safety Question for 3.6 V rechargeable Battery
;
do_menu_new_battery_36V_charge:
	MENU_BEGIN	tNewBattTitle, .5
		MENU_CALL		tConfirmChargeable1,		0								; safety question, line 1
		MENU_CALL		tConfirmChargeable2,		0								; safety question, line 2
		MENU_CALL		tConfirmChargeable3,		0								; safety question, line 3
		MENU_CALL		tNo,						do_return_menu_new_bat_AA_chrg	; NO  - go back
		MENU_CALL		tYes,						do_use_36V_chargeable			; YES - confirmed rechargeable
	MENU_END


;-----------------------------------------------------------------------------
; Battery Selection for OSTC 3 and Sport (no charging function)
;
do_menu_new_battery_AA_no_charge:
	MENU_BEGIN	tNewBattTitle, .4
		MENU_CALL		tNewBattOld,				do_use_old_battery				; load data of old battery
		MENU_CALL		tNewBattNew15,				do_use_15V_disposable			; not rechargeable
		MENU_CALL		tNewBattNew36,				do_use_36V_disposable			; not rechargeable
		MENU_CALL		tNewBattAccu,				do_use_36V_chargeable			; rechargeable
	MENU_END


;-----------------------------------------------------------------------------
; Call Function - keep old Battery
;
do_use_old_battery:
	rcall	get_battery_data			; load data of old battery
	goto	surfloop					; proceed to surface mode


;-----------------------------------------------------------------------------
; Call Function - new 1.5 V disposable
;
do_use_15V_disposable:
	rcall	setup_new_15v
	bra		use_batt_exit


;-----------------------------------------------------------------------------
; Call Function - new 3.6 V disposable
;
do_use_36V_disposable:
	rcall	setup_new_saft
	bra		use_batt_exit


;-----------------------------------------------------------------------------
; Call Function - new 3.6 V rechargeable
;
do_use_36V_chargeable:
	rcall	setup_new_panasonic
	call	reset_battery_gauge
	bra		use_batt_exit_1


;-----------------------------------------------------------------------------
; Call Function - build-in 16650
;
do_use_16650_battery:
	rcall	setup_new_16650
	bra		use_batt_exit


;-----------------------------------------------------------------------------
; Call Function - build-in 18650
;
use_18650_battery:
	rcall	setup_new_18650
	;bra	use_batt_exit


;-----------------------------------------------------------------------------
; Helper Function - finish Battery Selection
;
use_batt_exit:
	call	reset_battery_gauge_and_lt2942	; reset battery hard- and software gauge

use_batt_exit_1:
 IFNDEF _screendump
	bcf		comm_mode_disabled				; re-enable COMM mode again
 ENDIF
	goto	surfloop						; exit to surface mode


;-----------------------------------------------------------------------------
; Migrate Battery Selection from Firmwares prior 2.09
;
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


;-----------------------------------------------------------------------------
; Retrieve Battery Selection from EEPROM
;
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


;-----------------------------------------------------------------------------
; Helper Functions - configure Battery Types

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

;-----------------------------------------------------------------------------

	END
