;=============================================================================
;
;   File customview.asm                       combined next generation V3.08.8
;
;   Custom Views in Surface and Dive Mode
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;  2011-08-10 : [mH] moving from OSTC code

;=============================================================================

#include "hwos.inc"						; mandatory header
#include "tft_outputs.inc"
#include "strings.inc"
#include "tft.inc"
#include "wait.inc"
#include "surfmode.inc"
#include "convert.inc"
#include "divemode.inc"
#include "i2c.inc"
#include "start.inc"


	extern	gaslist_strcat_gas_cd
	extern	char_I_model

 IFDEF _compass
	extern	TFT_surface_compass_mask
	extern	TFT_dive_compass_mask
 ENDIF

#DEFINE num_premenu_items	.11		; overall number of pre-menu items

custview	CODE

;-----------------------------------------------------------------------------


;=============================================================================
; Jump table for the every-second tasks for the custom view area (dive mode)
;
; Attention: the ordering must be in line with the init jump table and the
;            index numbers defined in hwos.inc!

	global	dive_customview_second
dive_customview_second:
	movf	active_customview,W			; get current view
	dcfsnz	WREG,F						;
	goto	TFT_avr_stopwatch			;  1: average depth and stopwatch
	dcfsnz	WREG,F						;
 IFDEF _compass
	return								;  2: compass - will be updated separately (faster) in dive mode
 ELSE
	return								;  2: not available without compass
 ENDIF
	dcfsnz	WREG,F						;
 IFDEF _external_sensor
	goto	TFT_ppo2_sensors			;  3: ppO2 sensors
 ELSE
	return								;  3: not available without external sensors
 ENDIF
	dcfsnz	WREG,F						;
 IFDEF _ccr_pscr
	goto	TFT_sensor_check			;  4: sensor check
 ELSE
	return								;  4: not available without CCR / pSCR mode
 ENDIF
	dcfsnz	WREG,F						;
 IFDEF _ccr_pscr
	goto	TFT_pscr_info				;  5: pSCR data
 ELSE
	return								;  5: not available without CCR / pSCR mode
 ENDIF
	dcfsnz	WREG,F						;
 IFDEF _rx_functions
	goto	TFT_pressures_SAC			;  6: tank pressure and SAC rate
 ELSE
	return								;  6: not available without RX functions
 ENDIF
	dcfsnz	WREG,F						;
	goto	TFT_gas_needs				;  7: gas needs for ascent / cave return
	dcfsnz	WREG,F						;
 IFDEF _cave_mode
	goto	TFT_cave_tts				;  8: cave mode TTS
 ELSE
	return								;  8: not available without cave mode functions
 ENDIF
	dcfsnz	WREG,F						;
	goto	TFT_decoplan				;  9: deco plan
	dcfsnz	WREG,F						;
	goto	TFT_ceiling_GF_tissue		; 10: ceiling, current GF and tissues
	dcfsnz	WREG,F						;
	goto	TFT_CNS						; 11: CNS values
	dcfsnz	WREG,F						;
	goto	TFT_ppo2_ead_end_cns		; 12: ppO2, END/EAD and CNS / gas density
	dcfsnz	WREG,F						;
	goto	TFT_clock_batt_surfpress	; 13: clock, battery and surface pressure
	dcfsnz	WREG,F						;
	return								; 14: GF factors - static only
	dcfsnz	WREG,F						;
 IFDEF _cave_mode
	goto	TFT_cave_waypoints			; 15: cave waypoints
 ELSE
	return								; 15: not available without cave mode functions
 ENDIF
	return								;  0: do nothing

;-----------------------------------------------------------------------------

	global	surf_customview_toggle
surf_customview_toggle:
	bcf		switch_right				; clear button event
	incf	active_customview,F			; number of custom view to show

 IFDEF _compass
	movlw	.6							; index of surface custom view compass
	cpfseq	active_customview			; will compass be shown in custom view?
	call	I2C_sleep_compass			; NO - stop compass
 ENDIF

	movlw	d'10'						; max number of custom views in surface mode
	cpfsgt	active_customview			; max reached?
	bra		surf_customview_mask		; NO  - show
	movlw	.1							; YES - wrap around to 1st view
	movwf	active_customview			;     - ...
	;bra	surf_customview_mask		;     - show


	global	surf_customview_mask
surf_customview_mask:
	WIN_BOX_BLACK .50,surf_warning1_row-1, .0, surf_decotype_column-.1	; top, bottom, left, right
	WIN_TINY  surf_customview_title_column,surf_customview_title_row	; set title position
	WIN_COLOR color_greenish											; set title color

	movf	active_customview,W			; get custom view to show
	movff	WREG,customview_surfmode	; save number for later recall
	dcfsnz	WREG,F						; 1:
	bra		surf_customview_init_view1	; OC gas list
	dcfsnz	WREG,F						; 2:
	bra		surf_customview_init_view2	; CC dil list
	dcfsnz	WREG,F						; 3:
	bra		surf_customview_init_view3	; CC SP list
	dcfsnz	WREG,F						; 4:
	bra		surf_customview_init_view4	; custom text
	dcfsnz	WREG,F						; 5:
	bra		surf_customview_init_view5	; tissue diagram
	dcfsnz	WREG,F						; 6:
	bra		surf_customview_init_view6	; compass
	dcfsnz	WREG,F						; 7:
	bra		surf_customview_init_view7	; deco settings
	dcfsnz	WREG,F						; 8:
	bra		surf_customview_init_view8	; last dive info
	dcfsnz	WREG,F						; 9:
	bra		surf_customview_init_view9	; sensor mV readings
	dcfsnz	WREG,F						; 10:
	bra		surf_customview_init_view10	; tank data
	bra		surf_customview_init_view4	; default view after restart and loading of new firmware


surf_customview_init_view1:				; view 1: OC Gas list
	btfsc	FLAG_gauge_mode				; in gauge mode?
	bra		surf_customview_toggle		; YES - not available in gauge mode, goto next view
	btfsc	FLAG_apnoe_mode				; in apnoe mode?
	bra		surf_customview_toggle		; YES - not available in apnoe mode, goto next view
 IFDEF _ccr_pscr
	btfss	FLAG_oc_mode				; in OC mode?
	bra		surf_customview_init_view1a	; NO  - (1)
 ENDIF
	STRCPY_TEXT_PRINT tGaslist			; YES - title of custom view / OC mode
 IFDEF _ccr_pscr
	bra		surf_customview_init_view1b	;     - continue with common part
surf_customview_init_view1a:
	STRCPY_TEXT_PRINT tDiveBailout		; (1) - title of custom view / CCR & pSCR mode
 ENDIF
surf_customview_init_view1b:
	call	TFT_standard_color			; set color
	call	TFT_gaslist_surfmode		; show gas list
	bra		customview_toggle_exit		; done


surf_customview_init_view2:				; view 2: CCR / pSCR diluent list
 IFDEF _ccr_pscr
	btfsc	FLAG_ccr_mode				; in CCR mode?
	bra		surf_customview_init_view2a	; YES - (1)
	btfsc	FLAG_pscr_mode				; in pSCR mode?
	bra		surf_customview_init_view2a	; YES - (1)
	bra		surf_customview_toggle		; NO  - not available if not in CCR or pSCR mode, goto next view
surf_customview_init_view2a:
	STRCPY_TEXT_PRINT tGaslistCC		; (1) - title of custom view
	call	TFT_standard_color			;     - set color
	call	TFT_dillist_surfmode		;     - show diluent list
	bra		customview_toggle_exit		;     - done
 ELSE
	bra		surf_customview_toggle		; not available without CCR/pSCR mode compiled in, goto next view
 ENDIF


surf_customview_init_view3:				; view 3: CC SP list
 IFDEF _ccr_pscr
	btfss	FLAG_ccr_mode				; in CCR mode?
	bra		surf_customview_toggle		; NO  - not available if not in CCR mode, goto next view
	STRCPY_TEXT_PRINT tFixedSetpoints	; YES - title of custom view
	call	TFT_standard_color			;     - set color
	call	TFT_splist_surfmode			;     - show setpoint list
	bra		customview_toggle_exit		;     - done
 ELSE
	bra		surf_customview_toggle		; not available without CCR/pSCR mode compiled in, goto next view
 ENDIF


surf_customview_init_view9:				; view 9: sensor mV at the surface
 IFDEF _external_sensor
	btfsc	FLAG_ccr_mode				; in CCR mode?
	bra		surf_customview_init_view9a	; YES - (1)
	btfsc	FLAG_pscr_mode				; in pSCR mode?
	bra		surf_customview_init_view9a	; YES - (1) 
	bra		surf_customview_toggle		; NO  - not available if not in CCR or pSCR mode, goto next view
surf_customview_init_view9a:
	movff	opt_ccr_mode,WREG			; (1) - get SP mode (0: fixed SP, 1: Sensor, 2: auto SP)
	sublw	.1							;     - opt_ccr_mode = 1 (sensor)?
	bnz		surf_customview_toggle		;       NO  - goto next view
	STRCPY_TEXT_PRINT tSensorMilliVolt	;       YES - title of custom view
	call	TFT_standard_color			;           - set color
	call	TFT_sensor_mV				;           - write sensor mV readings to screen 
	bra		customview_toggle_exit		;           - done
 ELSE
	bra		surf_customview_toggle		; not available without CCR/pSCR mode compiled in, goto next view
 ENDIF


surf_customview_init_view4:				; view 4: custom text
	call	TFT_standard_color			; set color
	call	TFT_custom_text				; show the custom text
	bra		customview_toggle_exit		; done


surf_customview_init_view5:				; view 5: tissue diagram
	btfsc	FLAG_gauge_mode				; in gauge mode?
	bra		surf_customview_toggle		; YES - not available in gauge mode, goto next view
	btfsc	FLAG_apnoe_mode				; in apnoe mode?
	bra		surf_customview_toggle		; YES - not available in apnoe mode, goto next view
	call	TFT_standard_color			; set color
	call	TFT_surface_tissues			; show tissue diagram
	bra		customview_toggle_exit		; done


surf_customview_init_view6:				; view 6: compass
 IFDEF _compass
	call	I2C_init_compass			; start compass
	call	TFT_surface_compass_mask	; show compass mask
	bra		customview_toggle_exit		; done
 ELSE
	bra		surf_customview_toggle		; not available without compass compiled in, goto next view
 ENDIF


surf_customview_init_view7:				; view 7: deco settings
	btfsc	FLAG_gauge_mode				; in gauge mode?
	bra		surf_customview_toggle		; YES - not available in gauge mode, goto next view
	btfsc	FLAG_apnoe_mode				; in apnoe mode?
	bra		surf_customview_toggle		; YES - not available in apnoe mode, goto next view
	call	TFT_surface_decosettings	; show all deco settings
	bra		customview_toggle_exit		; done


surf_customview_init_view8:				; view 8: last dive info
	call	TFT_standard_color			; set color
	call	TFT_surface_lastdive		; show last dive info
	bra		customview_toggle_exit		; done


surf_customview_init_view10:			; view 10: transmitter data / debug
 IFDEF _rx_functions
	btfss	tr_functions_activated		; TR functions activated?
	bra		surf_customview_toggle		; NO  - show next view in list
	STRCAT_PRINT "ID     bar  Volt"		; YES - title of custom view (none language-dependent)
	call	TFT_surface_tankdata		;     - show received data
	bra		customview_toggle_exit		;     - done
 ELSE
	bra		surf_customview_toggle		; not available without RX functions compiled in, goto next view
 ENDIF

;-----------------------------------------------------------------------------

	global	menuview_toggle
	global	menuview_toggle_reset
menuview_toggle:						; show main menu or the pre-menu
	bcf		switch_left					; clear button event
	movlw	divemode_timeout_premenu	; get timeout for dive mode pre-menu
	call	reset_timeout_time			; reset timeout
	bsf		dive_options_menu			; flag that the dive options menu is shown
	incf	active_premenu,F			; increment pre-menu item number
	movlw	num_premenu_items			; get count of pre-menu items
	cpfsgt	active_premenu				; max reached?
	bra		menuview_mask				; NO  - show item
	;bra	menuview_toggle_reset		; YES - reset selector
menuview_toggle_reset:					; timeout occurred, beyond max number of options, or item executed
	clrf	active_premenu				; reset pre-menu selector
	bcf		dive_options_menu			; the dive options menu is not shown anymore
menuview_mask:
	WIN_BOX_BLACK dm_premenu_row, dm_premenu_bot, dm_premenu_col, dm_premenu_rgt ; top, bottom, left, right
	tstfsz	active_premenu				; any pre-menu selected?
	bra		menuview_items				; YES - display menu item
	bcf		win_invert					; NO  - end inverse printing
	btfss	FLAG_apnoe_mode				;     - in apnoe mode?
	goto	TFT_show_temp_divemode		;       YES - restore temperature and done
	goto	TFT_standard_color			;       NO  - done

menuview_items:
	call	TFT_attention_color			; set color
	bsf		win_invert					; set inverse printing
	WIN_SMALL dm_premenu_col,dm_premenu_row
	movf	active_premenu,W			; get active pre-menu item
	dcfsnz	WREG,F
	bra		menuview_view_gaschange		;  1: gas change	(skipped if no better gas/dil cued)
	dcfsnz	WREG,F
	bra		menuview_view_divemenu		;  2: "Menu?"		(skipped in gauge and apnoe modes)
	dcfsnz	WREG,F
 IFDEF _cave_mode
	bra		menuview_view_cavemenu		;  3: "Cave?"		(skipped if not in cave mode)
 ELSE
	bra		menuview_toggle				;  3: cave mode not implemented, go to next menu item
 ENDIF
	dcfsnz	WREG,F
	bra		menuview_view_sim_quit		;  4: "Quit?"		(in simulation mode only)
	dcfsnz	WREG,F
	bra		menuview_view_sim_down		;  5: "Sim down"	(in simulation mode only)
	dcfsnz	WREG,F
	bra		menuview_view_sim_up		;  6: "Sim up"		(in simulation mode only)
	dcfsnz	WREG,F
	bra		menuview_view_sim_time		;  7: "Sim+5'"		(in simulation mode only)
	dcfsnz	WREG,F
	bra		menuview_view_apnoe_quit	;  8: "Quit?"		(in apnoe mode only)
	dcfsnz	WREG,F
	bra		menuview_view_gauge_reset	;  9: "Reset Avr"	(in gauge mode only)
	dcfsnz	WREG,F
	bra		menuview_view_course		; 10: "Course"		(only when compass is shown)
	dcfsnz	WREG,F
	bra		menuview_view_layout		; 11: "Layout"		(offer alternative layout, aka blind mode)

	; when adding or removing pre-menu items, adjust the value num_premenu_items in the #DEFINE !

menuview_exit:
	call	TFT_standard_color
	bcf		win_invert					; reset invert flag
	return								; active pre-menu = 0, i.e. show nothing


menuview_view_gaschange:
	btfsc	request_gas_change			; last gas change request executed yet?
	bra		menuview_toggle				; YES - call next option
 IFDEF _ccr_pscr
	btfsc	FLAG_oc_mode				; in OC mode?
	bra		menuview_view_gaschange_OC	; YES
	btfsc	bailout_mode				; in bailout?
	bra		menuview_view_gaschange_OC	; YES
menuview_view_gaschange_DIL:
	btfss	better_dil_available		; is the better diluent still available?
	bra		menuview_toggle				; NO - call next option
	movff	best_dil_number,PRODL		; number (1-5) of the "best diluent"
	bsf		is_diluent_menu				; setting up diluents
	bra		menuview_view_gaschange_com
 ENDIF
menuview_view_gaschange_OC:
	btfss	better_gas_available		; is the better gas still available?
	bra		menuview_toggle				; NO - call next option
	movff	best_gas_number,PRODL		; number (1-5) of the "best gas"
	bcf		is_diluent_menu				; setting up OC gases
menuview_view_gaschange_com:
	decf	PRODL,F						; (1-5) -> (0-4)
	bsf		short_gas_descriptions		; use short version of gaslist_strcat_gas_cd and gaslist_strcat_setpoint
	bsf		better_gas_hint				; color-code as best gas/diluent
	call	gaslist_strcat_gas_cd		; append gas description of gas #PRODL (0-4) to current string
	movlw	.5							; point to 6th character (5 chars are used for the gas/dil description)
	movwf	FSR2L						; ...
	STRCAT_PRINT "?"					; print question mark
	bra		menuview_exit				; done

menuview_view_divemenu:
	btfsc	FLAG_apnoe_mode				; in apnoe mode?
	bra		menuview_toggle				; YES - goto next option
	btfsc	FLAG_gauge_mode				; NO  - in gauge mode?
	bra		menuview_toggle				;       YES - goto next option
	PUTC	"\xb7"						;       NO  - print '->' symbol
	STRCAT_TEXT_PRINT tDivePreMenu		;           - print "Menu?"
	bra		menuview_exit				;           - done

 IFDEF _cave_mode
menuview_view_cavemenu:
	TSTOSS	opt_cave_mode				; cave mode switched on?
	bra		menuview_toggle				; NO  - goto next option
	PUTC	"\xb7"						; YES - print '->' symbol
	STRCAT_TEXT_PRINT tDivePreCave		;     - print "Cave?"
	bra		menuview_exit				;     - done
 ENDIF

menuview_view_sim_quit:
	btfss	simulatormode				; in simulator mode?
	bra		menuview_toggle				; NO  - goto next option
	STRCPY_TEXT_PRINT tQuitSim			; YES - print "Quit Simulation?"
	bra		menuview_exit				;     - done

menuview_view_sim_down:
	btfss	simulatormode				; in simulator mode?
	bra		menuview_toggle				; NO - goto next option
	STRCPY_PRINT "Sim\xb8"				; print down arrow for going down
	bra		menuview_exit				; done

menuview_view_sim_up:
	btfss	simulatormode				; in simulator mode?
	bra		menuview_toggle				; NO  - goto next option
	STRCPY_PRINT "Sim\xb9"				; YES - print up arrow for going up
	bra		menuview_exit				;     - done

menuview_view_sim_time:
	btfss	simulatormode				; in simulator mode?
	bra		menuview_toggle				; NO  - goto next option
	btfsc	FLAG_gauge_mode				; YES - in gauge mode?
	bra		menuview_toggle				;       YES - goto next option
	btfsc	FLAG_apnoe_mode				;       NO  - in apnoe mode?
	bra		menuview_toggle				;             YES - goto next option
	STRCPY_PRINT "Sim+5'"				;             NO  - print "Sim+5'"
	bra		menuview_exit				;                 - done

menuview_view_apnoe_quit:
	btfss	FLAG_apnoe_mode				; in apnoe mode?
	bra		menuview_toggle				; NO  - goto next option
	btfss	apnoe_at_surface			; YES - at the surface?
	bra		menuview_toggle				;       NO  - goto next option
	STRCPY_TEXT_PRINT tQuitSim			;       YES - print "Quit Apnea mode?"
	bra		menuview_exit				;           - done

menuview_view_gauge_reset:
	btfss	FLAG_gauge_mode				; in gauge mode?
	bra		menuview_toggle				; NO  - goto next option
	STRCPY_TEXT_PRINT tResetAvg			; YES - print "Reset Avg."
	bra		menuview_exit				;     - done

menuview_view_course:
 IFDEF _compass
	movlw	index_compass_dm			; index of compass view
	cpfseq	active_customview			; in compass view?
	bra		menuview_toggle				; NO  - goto next option
	STRCPY_TEXT_PRINT tSetHeading		; YES - print "Heading"
	bra		menuview_exit				;     - done
 ELSE
	bra		menuview_toggle				; not available without compass compiled in, goto next option
 ENDIF

menuview_view_layout:
	btfsc	FLAG_apnoe_mode				; in apnoe mode?
	bra		menuview_toggle				; YES - goto next option
	STRCPY_TEXT_PRINT tDiveLayout		; NO  - print "Layout"
	bra		menuview_exit				;     - done

;-----------------------------------------------------------------------------

; Initialize dive mode custom view

	global	dive_customview_show
dive_customview_show:
	btfss	custom_view_locked			; custom view locked?
	bra		dive_customview_show_1		; NO  - call-up the view
	movwf	backup_customview			; YES - store requested custom view for later recall
	return								;     - done
dive_customview_show_1:
	movwf	active_customview			; set the requested custom view
	bra		dive_customview_callup		; call-up the custom view

	global	dive_customview_recall
dive_customview_recall:
	movff	backup_customview,active_customview	; recall the saved custom view
	bra		dive_customview_callup				; call-up the custom view

	global	dive_customview_toggle
dive_customview_toggle:
	incf	active_customview,F			; increment number of custom view to show
	movlw	index_cv_dm_max				; highest index in use in dive mode custom view
	cpfsgt	active_customview			; max reached?
	bra		dive_customview_callup		; NO  - call-up the custom view
	clrf	active_customview			; YES - reset to zero (zero = blank custom view)
	;bra	dive_customview_callup		; call-up the custom view

	global	dive_customview_callup
dive_customview_callup:
	movlw	index_compass_dm			; get index of compass custom view
	cpfseq	active_customview			; will compass be shown?
	call	I2C_sleep_compass			; NO - stop compass
	;bra	dive_customview_init		; continue with initializing selected custom view

;----------------------------------------------------------------------------------
; Jump table for initialization of the every-second tasks in custom view area (dive mode)
;
; Attention: the ordering must be in line with the every-second update jump table
;            and the index numbers defined in hwos.inc!
;
dive_customview_init:
	; clear custom view area in dive mode
	WIN_BOX_BLACK dm_customview_row, dm_customview_bot-.2, dm_customview_column, dm_customview_rgt ; top, bottom, left, right
	movf	active_customview,W			; get custom view to show
	dcfsnz	WREG,F						;
	bra		init_avr_stopwatch			;  1: average depth and stopwatch
	dcfsnz	WREG,F						;
	bra		init_TFT_dive_compass		;  2: compass
	dcfsnz	WREG,F						;
	bra		init_ppo2_sensors			;  3: ppO2 sensors
	dcfsnz	WREG,F						;
	bra		init_sensor_check			;  4: sensor check
	dcfsnz	WREG,F						;
	bra		init_pscr_info				;  5: pSCR data
	dcfsnz	WREG,F						;
	bra		init_pressures_SAC			;  6: tank pressure and SAC rate
	dcfsnz	WREG,F						;
	bra		init_gas_needs_ascent		;  7: gas needs for ascent / cave return
	dcfsnz	WREG,F						;
	bra		init_cave_tts				;  8: cave mode TTS
	dcfsnz	WREG,F						;
	bra		init_decoplan				;  9: deco plan (next stops)
	dcfsnz	WREG,F						;
	bra		init_ceiling_GF_tissue		; 10: ceiling, current GF and tissues
	dcfsnz	WREG,F						;
	bra		init_CNS					; 11: CNS values
	dcfsnz	WREG,F						;
	bra		init_ppo2_ead_end_cns		; 12: ppO2, END/EAD and CNS
	dcfsnz	WREG,F						;
	bra		init_clock_batt_surfpress	; 13: clock, battery and surface pressure
	dcfsnz	WREG,F						;
	bra		init_gf_factors				; 14: GF factors
	dcfsnz	WREG,F						;
	bra		init_cave_waypoints			; 15: cave waypoints
	bra		customview_toggle_exit		;  0: no view (blank screen in custom view area)


init_ppo2_sensors:
 IFDEF _external_sensor
	bsf		trigger_temp_changed		; fake a change of the temperature to have the resettable dive time overwritten which was shown with the compass view
	btfsc	FLAG_ccr_mode				; in CC mode?
	bra		customview_init_view1a		; YES - (1)
	btfsc	FLAG_pscr_mode				; in pSCR mode?
	bra		customview_init_view1a		; YES - (1)
	bra		dive_customview_toggle		; NO to both, goto next view
customview_init_view1a:
	btfsc	analog_o2_input				; (1) - do we have an analog input?
	bra		customview_init_view1b		;       YES - (2)
	btfsc	s8_digital_avail			;       NO  - do we have a digital S8 interface?
	bra		customview_init_view1b		;             YES - (2)
	btfss	optical_input				;             NO  - do we have an optical input?
	bra		dive_customview_toggle		;                   NO  - goto next view
										;                   YES - (2)
customview_init_view1b:
	call	TFT_ppo2_sensors_mask		; (2) - mask for ppO2 sensors
	call	TFT_ppo2_sensors			;     - data for ppO2 sensors
	bra		customview_toggle_exit		;     - done
 ELSE
	bra		dive_customview_toggle		; not available without external sensors, got next view
 ENDIF

init_avr_stopwatch:
	btfsc	FLAG_apnoe_mode				; in apnoe mode?
	bra		dive_customview_toggle		; YES - goto next view
	call	TFT_avr_stopwatch_mask		; NO  - mask for average depth and stopwatch
	call	TFT_avr_stopwatch			;     - data for average depth and stopwatch
	bra		customview_toggle_exit		;     - done

init_decoplan:
	btfsc	FLAG_apnoe_mode				; in apnoe mode?
	bra		dive_customview_toggle		; YES - goto next view
	btfsc	FLAG_gauge_mode				; NO  - in gauge mode?
	bra		dive_customview_toggle		;       YES - goto next view
	call	TFT_decoplan_mask			;       NO  - mask for deco plan
	call	TFT_decoplan				;           - data for deco plan
	bra		customview_toggle_exit		;           - done

init_clock_batt_surfpress:
	call	TFT_clock_batt_surfpress_mask	; mask for clock, battery and surface pressure
	call	TFT_clock_batt_surfpress		; data for clock, battery and surface pressure
	bra		customview_toggle_exit			; done

init_TFT_dive_compass:					; compass
 IFDEF _compass
	call	I2C_init_compass			; start compass
	call	TFT_dive_compass_mask		; show compass mask
	bra		customview_toggle_exit		; done
 ELSE
	bra		dive_customview_toggle		; not available without compass compiled in, goto next view
 ENDIF

init_pressures_SAC:						; tank pressure and SAC rate
 IFDEF _rx_functions
	btfss	tr_functions_activated		; TR functions activated?
	bra		dive_customview_toggle		; NO  - goto next view
	call	TFT_pressures_SAC_mask		; YES - mask for pressures and SAC
	call	TFT_pressures_SAC			;     - data for pressures and SAC
	bra		customview_toggle_exit		;     - done
 ELSE
	bra		dive_customview_toggle		; not available without RX functions, got next view
 ENDIF

init_CNS:								; CNS at end of dive
	btfsc	FLAG_gauge_mode				; in gauge mode?
	bra		dive_customview_toggle		; YES - call next view
	btfsc	FLAG_apnoe_mode				; NO  - in apnoe mode?
	bra		dive_customview_toggle		;       YES - call next view
	call	TFT_CNS_mask				;       NO  - mask for CNS values
	call	TFT_CNS						;           - data for CNS values
	bra		customview_toggle_exit		;           - done

init_ceiling_GF_tissue:					; ceiling, tissues and current GF
	btfsc	FLAG_apnoe_mode				; in apnoe mode?
	bra		dive_customview_toggle		; YES - goto next view
	btfsc	FLAG_gauge_mode				; NO  - in gauge mode?
	bra		dive_customview_toggle		;       YES - call next view
	call	TFT_ceiling_GF_tissue_mask	;       NO  - mask for ceiling, current GF and tissues
	call	TFT_ceiling_GF_tissue		;           - data for ceiling, current GF and tissues
	bra		customview_toggle_exit		;           - done

init_sensor_check:						; sensor check
 IFDEF _ccr_pscr
	btfss	FLAG_ccr_mode				; in CCR mode?
	bra		dive_customview_toggle		; NO  - goto next view
	call	TFT_sensor_check_mask		; YES - mask for sensor check
	call	TFT_sensor_check			;     - data for sensor check
	bra		customview_toggle_exit		;     - done
 ELSE
	bra		dive_customview_toggle		; not available without CCR mode compiled in, goto next view
 ENDIF

init_ppo2_ead_end_cns:					; ppO2, END/EAD and CNS
	btfsc	FLAG_apnoe_mode				; in apnoe mode?
	bra		dive_customview_toggle		; YES - goto next view
	btfsc	FLAG_gauge_mode				; NO  - in gauge mode?
	bra		dive_customview_toggle		;       YES - goto next view
	call	TFT_ppo2_ead_end_cns_mask	;       NO  - mask for ppO2, END/EAD and CNS
	call	TFT_ppo2_ead_end_cns		;           - data for ppO2, END/EAD and CNS
	bra		customview_toggle_exit		;           - done

init_pscr_info:							; pSCR information
 IFDEF _ccr_pscr
	btfss	FLAG_pscr_mode				; in pSCR mode?
	bra		dive_customview_toggle		; NO  - goto next view
	call	TFT_pscr_info_mask			; YES - mask for pSCR info
	call	TFT_pscr_info				;     - data for pSCR info
	bra		customview_toggle_exit		;     - done
 ELSE
	bra		dive_customview_toggle		; not available without CCR / pSCR mode, goto next view
 ENDIF

init_gas_needs_ascent:					; gas needs for ascent
	btfsc	FLAG_apnoe_mode				; in apnoe mode?
	bra		dive_customview_toggle		; YES - goto next view
	btfsc	FLAG_gauge_mode				; NO  - in gauge mode?
	bra		dive_customview_toggle		;       YES - goto next view
	TSTOSS	opt_calc_gasvolume			;       NO  - check if gas volume calculation is switched on
	bra		dive_customview_toggle		;             NO  - goto next view
	call	TFT_gas_needs_mask			;             YES - mask for gas needs ascent
	call	TFT_gas_needs				;                 - data for gas needs ascent
	bra		customview_toggle_exit		;                 - done

init_cave_tts:							; cave mode data
 IFDEF _cave_mode
	btfss	cave_mode					; in cave mode?
	bra		dive_customview_toggle		; NO  - goto next view
	call	TFT_cave_tts_mask			; YES - show mask
	call	TFT_cave_tts				;     - show data
	bra		customview_toggle_exit		;     - done
 ELSE
	bra		dive_customview_toggle		; not available without cave mode, goto next view
 ENDIF

init_gf_factors:
	call	TFT_gf_factors_mask			; mask for GF factors (static only)
	bra		customview_toggle_exit		; done

init_cave_waypoints:
 IFDEF _cave_mode
	call	TFT_cave_waypoints			; show waypoint graphics
	bra		customview_toggle_exit		; done
 ELSE
	bra		dive_customview_toggle		; not available without cave mode, goto next view
 ENDIF


customview_toggle_exit:
	bcf		request_next_custview		; clear request flag
	return								; done

;-----------------------------------------------------------------------------

	END
