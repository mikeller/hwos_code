;=============================================================================
;
;   File customview.asm								REFACTORED VERSION V2.99e
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
#include "isr.inc"
#include "wait.inc"
#include "surfmode.inc"
#include "convert.inc"
#include "divemode.inc"
#include "i2c.inc"
#include "start.inc"


	extern	gaslist_strcat_gas_cd
	extern	char_I_deco_model
	extern	TFT_surface_compass_mask
	extern	TFT_dive_compass_mask

custview	CODE

;=============================================================================
; Jump table for the every-second tasks for the custom view area (dive mode)
;
; Attention: the ordering must be in line with the init jump table and the
;            index numbers defined in hwos.inc!

	global	customview_second
customview_second:
	movf	menupos3,W					; copy current view (1-...)
	dcfsnz	WREG,F						; 1:
	goto	TFT_avr_stopwatch			; average depth and stopwatch
	dcfsnz	WREG,F						; 2:
	return								; compass - will be updated separately (faster) in divemode
	dcfsnz	WREG,F						; 3:
	goto	TFT_ppo2_sensors			; ppO2 sensors
	dcfsnz	WREG,F						; 4:
	goto	TFT_sensor_check			; sensor check
	dcfsnz	WREG,F						; 5;
	goto	TFT_pscr_info				; pSCR data
	dcfsnz	WREG,F						; 6:
 IFDEF _rx_functions
	goto	TFT_pressures_SAC			; tank pressure and SAC rate
 ELSE
	return								; not available without RX functions
 ENDIF
	dcfsnz	WREG,F						; 7:
	goto	TFT_gas_needs_ascent		; gas needs for ascent / cave return
	dcfsnz	WREG,F						; 8:
	goto	TFT_decoplan				; deco plan
	dcfsnz	WREG,F						; 9:
	goto	TFT_ceiling_GF_tissue		; ceiling, current GF and tissues
	dcfsnz	WREG,F						; 10:
	goto	TFT_CNS						; CNS values
	dcfsnz	WREG,F						; 11:
	goto	TFT_ppo2_ead_end_cns		; ppO2, END/EAD and CNS
	dcfsnz	WREG,F						; 12:
	return								; GF factors - only static data
	dcfsnz	WREG,F						; 13:
	goto	TFT_clock_batt_surfpress	; clock, battery and surface pressure
	return								; menupos3 = 0 -> do nothing


	global	customview_alternative_second
customview_alternative_second:
	movf	menupos3,W					; copy current view (0-...)
	dcfsnz	WREG,F
	nop									; view 1
	dcfsnz	WREG,F
	nop									; view 2
	;bra	customview_alt_second_view0 ; default view

customview_alt_second_view0:
	bsf		FLAG_TFT_big_deco_alt
	return

;=============================================================================
; Do every-minute tasks for the custom view area

	global	customview_minute
customview_minute:						; called from dive mode, call disabled at present
	return
;	movf	menupos3,W					; copy
;	dcfsnz	WREG,F
;	bra		customview_1min_view1
;	dcfsnz	WREG,F
;	bra		customview_1min_view2
;	dcfsnz	WREG,F
;	bra		customview_1min_view3
;	dcfsnz	WREG,F
;	bra		customview_1min_view4
;	dcfsnz	WREG,F
;	bra		customview_1min_view5
;	dcfsnz	WREG,F
;	bra		customview_1min_view6
;	dcfsnz	WREG,F
;	bra		customview_1min_view7
;	dcfsnz	WREG,F
;	bra		customview_1min_view8
;	dcfsnz	WREG,F
;	bra		customview_1min_view9
;	dcfsnz	WREG,F
;	bra		customview_1min_view10
;	dcfsnz	WREG,F
;	bra		customview_1min_view11
;	; menupos3=0, do nothing
;	return
;
;customview_1min_view1:
;customview_1min_view2:
;customview_1min_view3:
;customview_1min_view4:
;customview_1min_view5:
;customview_1min_view6:
;customview_1min_view7:
;customview_1min_view8:
;customview_1min_view9:
;customview_1min_view10:
;customview_1min_view11:
;return

	global	surf_customview_toggle
surf_customview_toggle:
	bcf		switch_right
	incf	menupos3,F					; number of custom view to show

	movlw	.6							; index of surface custom view compass
	cpfseq	menupos3					; will compass be shown in custom view?
	call	I2C_sleep_accelerometer		; NO - stop accelerometer
	cpfseq	menupos3					; will compass be shown in custom view?
	call	I2C_sleep_compass			; NO - stop compass

	movlw	d'10'						; max number of custom views in surface mode
	cpfsgt	menupos3					; max reached?
	bra		surf_customview_mask		; NO - show
	movlw	.1
	movwf	menupos3					; reset to one (always one custom view visible)

	global	surf_customview_mask
surf_customview_mask:
	WIN_BOX_BLACK .50,surf_warning1_row-1, .0, surf_decotype_column-.1	; top, bottom, left, right
	; Prepare title
	WIN_TINY  surf_customview_title_column,surf_customview_title_row
	WIN_COLOR color_greenish
	movf	menupos3,W					; menupos3 holds number of custom view function
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
	bra		surf_customview_init_view4	; default view after restart and loading new firmware

surf_customview_init_view1:				; view 1: OC Gas list
	btfsc	FLAG_gauge_mode
	bra		surf_customview_toggle
	btfsc	FLAG_apnoe_mode
	bra		surf_customview_toggle
	btfss	FLAG_oc_mode
	bra		surf_customview_init_view1a	; bailout version of "OC Gas List"
	STRCPY_TEXT_PRINT tGaslist			; title of custom view / OC mode
	bra		surf_customview_init_view1b
surf_customview_init_view1a:
	STRCPY_TEXT_PRINT tDiveBailout		; title of custom view / CCR & pSCR mode
surf_customview_init_view1b:			; remaining common part
	call	TFT_standard_color
	call	TFT_gaslist_surfmode		; show gas list
	bra		customview_toggle_exit		; done

surf_customview_init_view2:				; view 2: CCR / pSCR diluent list
	btfsc	FLAG_ccr_mode
	bra		surf_customview_init_view2a
	btfsc	FLAG_pscr_mode
	bra		surf_customview_init_view2a
	bra		surf_customview_toggle
surf_customview_init_view2a:
	STRCPY_TEXT_PRINT tGaslistCC		; title of custom view
	call	TFT_standard_color
	call	TFT_dillist_surfmode		; show diluent list
	bra		customview_toggle_exit		; done

surf_customview_init_view3:				; view 3: CC SP list
	btfsc	FLAG_ccr_mode
	bra		surf_customview_init_view3a
	bra		surf_customview_toggle
surf_customview_init_view3a:
	STRCPY_TEXT_PRINT tFixedSetpoints	; title of custom view
	call	TFT_standard_color
	call	TFT_splist_surfmode			; show setpoint list
	bra		customview_toggle_exit		; done

surf_customview_init_view9:				; view 9: sensor mV at the surface
	btfsc	FLAG_ccr_mode 
	bra		surf_customview_init_view9a	; we are in CCR mode
	btfsc	FLAG_pscr_mode
	bra		surf_customview_init_view9a	; we are in PSCR mode 
	bra		surf_customview_toggle		; we are not in any rebreather mode, so skip
surf_customview_init_view9a:
	movff	opt_ccr_mode,WREG			; =0: fixed SP, =1: Sensor, =2: auto SP
	sublw	.1							; opt_ccr_mode = 1 (sensor)?
	bnz		surf_customview_toggle		; sorry, no sensors, skip again
	STRCPY_TEXT_PRINT tSensorMilliVolt	; title of custom view
	call	TFT_sensor_mV				; write sensor mV readings to screen 
	bra		customview_toggle_exit		; done

surf_customview_init_view4:				; view 4: custom text
	call	TFT_custom_text				; show the custom text
	bra		customview_toggle_exit		; done

surf_customview_init_view5:				; view 5: tissue diagram
	btfsc	FLAG_gauge_mode
	bra		surf_customview_toggle
	btfsc	FLAG_apnoe_mode
	bra		surf_customview_toggle
	call	TFT_standard_color
	call	TFT_surface_tissues			; show tissue diagram
	bra		customview_toggle_exit		; done

surf_customview_init_view6:				; view 6: compass
	call	I2C_init_compass			; start compass
	call	I2C_init_accelerometer		; start accelerometer
	call	TFT_surface_compass_mask	; show compass mask
	bra		customview_toggle_exit		; done

surf_customview_init_view7:
	btfsc	FLAG_gauge_mode				; view 7: deco settings
	bra		surf_customview_toggle
	btfsc	FLAG_apnoe_mode
	bra		surf_customview_toggle
	call	TFT_surface_decosettings	; show all deco settings
	bra		customview_toggle_exit		; done

surf_customview_init_view8:				; view 8: last dive info
	call	TFT_surface_lastdive		; show last dive interval
	bra		customview_toggle_exit		; done

surf_customview_init_view10:			; transmitter data / debug
 IFDEF _rx_functions
	btfss	FLAG_tr_enabled				; TR functions enabled?
	bra		surf_customview_toggle		; NO - show next view in list
	STRCAT_PRINT "ID     bar  Volt"		; title of custom view (none language-dependent)
	call	TFT_surface_tankdata
	bra		customview_toggle_exit		; done
 ELSE
	bra		surf_customview_toggle
 ENDIF


	global	switch_layout_to_normal
switch_layout_to_normal:				; switch back from alternative to normal layout
										; needs custom view to be selected / restored separately!
	bcf		alternative_divelayout		; clear flag
	bsf		FLAG_TFT_divemode_mask		; set flag for normal layout mask
	bsf		FLAG_TFT_max_depth			; set flag for normal layout data
	btfss	decostop_active				; deco?
	bsf		FLAG_TFT_display_ndl_mask	; NO  - set flag for normal layout NDL data
	btfsc	decostop_active				; deco?
	bsf		FLAG_TFT_display_deko_mask	; YES - set flag for normal layout deco data
	clrf	menupos3					; set to no active custom view
	call	TFT_ClearScreen				; clear the whole screen
	return


	global	menuview_toggle
menuview_toggle:						; show menu or the simulator tasks
	bcf		switch_left
	btfss	alternative_divelayout		; in alternative layout mode?
	bra		menuview_toggle2			; NO  - continue with menu or simulator tasks
	rcall	switch_layout_to_normal		; YES - switch back to normal layout
	movff	customview_divemode,menupos3;     - restore the custom view shown in normal layout
	rcall	customview_mask				;     - re-draw the custom view
	bra		menuview_toggle_reset		;     - suppress the menu when returning from alternative layout

menuview_toggle2:
	movlw	divemode_menuview_timeout
	movwf	timeout_counter2
	bsf		menuview					; flag that the options menu is shown
	incf	menupos2,F					; number of option to show
	movlw	d'10'						; max number of options in divemode
	cpfsgt	menupos2					; max reached?
	bra		menuview_mask				; NO - show option
	global	menuview_toggle_reset
menuview_toggle_reset:					; timeout occurred, beyond max number of options, or item executed
	clrf	menupos2					; reset option selector
	bcf		menuview					; revoke options menu if shown
menuview_mask:
	WIN_BOX_BLACK dm_simtext_row, dm_simtext_row+.23, dm_simtext_column, dm_simtext_column+.46		; top, bottom, left, right
	btfss	FLAG_gauge_mode				; in gauge mode?
	bra		menuview_mask2				; NO
										; YES - clear some more in gauge mode -- "Reset Avg." text is longer than all the other texts
	WIN_BOX_BLACK dm_simtext_row, dm_simtext_row+.23, dm_simtext_column+.47, dm_simtext_column+.70	; top, bottom, left, right
menuview_mask2:
	call	TFT_draw_gassep_line
	movlw	color_yellow
	call	TFT_set_color
	bsf		win_invert					; set invert flag
	WIN_SMALL dm_simtext_column,dm_simtext_row
	movf	menupos2,W					; menupos2 holds number of menu option to show
	dcfsnz	WREG,F
	bra		menuview_view_gaschange		; check if a better gas/diluent is advised and prompt for switching if yes
	dcfsnz	WREG,F
	bra		menuview_view1				; "Menu?"				(skipped in gauge and apnoe modes)
	dcfsnz	WREG,F
	bra		menuview_view2				; "Quit?"				(in simulation mode only)
	dcfsnz	WREG,F
	bra		menuview_view3				; "Sim-1m"				(in simulation mode only)
	dcfsnz	WREG,F
	bra		menuview_view4				; "Sim+1m"				(in simulation mode only)
	dcfsnz	WREG,F
	bra		menuview_view5				; "Quit?"				(in apnoe mode only)
	dcfsnz	WREG,F
	bra		menuview_view6				; "Reset Avr."			(in gauge mode only)
	dcfsnz	WREG,F
	bra		menuview_view7				; "Sim+5'"				(in simulation mode only)
	dcfsnz	WREG,F
	bra		menuview_view8				; "Heading"				(only when compass is shown)
	dcfsnz	WREG,F
	bra		menuview_view9				; "Layout"				(offer alternative layout, aka blind mode)

menuview_exit:
	call	TFT_standard_color
	bcf		win_invert					; reset invert flag
	btfss	alternative_divelayout		; in alternative layout?
	bsf		FLAG_TFT_active_gas_divemode; NO - redraw gas and setpoint (eventually needed to restore the "Bailout" text)
	return								; menupos2 = 0, show nothing


menuview_view_gaschange:
	btfsc	divemode_gaschange			; last gas change done yet?
	bra		menuview_toggle				; NO - call next option
	btfsc	FLAG_oc_mode				; in OC mode?
	bra		menuview_view_gaschange_OC	; YES
	btfsc	FLAG_bailout_mode			; in bailout?
	bra		menuview_view_gaschange_OC	; YES
menuview_view_gaschange_DIL:
	btfss	better_dil_available		; is the better diluent still available?
	bra		menuview_toggle				; NO - call next option
	movff	best_dil_number,PRODL		; number (1-5) of the "best diluent"
	bsf		FLAG_diluent_setup			; flag to use diluents
	bra		menuview_view_gaschange_com
menuview_view_gaschange_OC:
	btfss	better_gas_available		; is the better gas still available?
	bra		menuview_toggle				; NO - call next option
	movff	best_gas_number,PRODL		; number (1-5) of the "best gas"
	bcf		FLAG_diluent_setup			; flag to use oc gases
menuview_view_gaschange_com:
	decf	PRODL,F						; (1-5) -> (0-4)
	bsf		short_gas_decriptions		; =1: use short version of gaslist_strcat_gas_cd and gaslist_strcat_setpoint
	bsf		better_gas_hint				; color-code as best gas/diluent
	call	gaslist_strcat_gas_cd		; append gas description of gas #PRODL (0-4) to current string
	movlw	.5
	movwf	FSR2L						; point to 6th character (5 chars are used for the gas/dil description)
	STRCAT_PRINT "?"
	bra		menuview_exit				; done

menuview_view1:
	btfsc	FLAG_apnoe_mode				; in Apnoe mode?
	bra		menuview_toggle				; YES - goto next option
	btfsc	FLAG_gauge_mode				; in Gauge mode?
	bra		menuview_toggle				; YES - goto next option
	STRCPY_TEXT_PRINT tDivePreMenu		; print "Menu?"
	bra		menuview_exit				; done

menuview_view2:
	btfss	simulatormode_active		; in simulator mode?
	bra		menuview_toggle				; NO - goto next option
	STRCPY_TEXT_PRINT tQuitSim			; print "Quit Simulation?"
	bra		menuview_exit				; done

menuview_view3:
	btfss	simulatormode_active		; in simulator mode?
	bra		menuview_toggle				; NO - goto next option
;	STRCPY_PRINT "Sim-1m"				; print "-" for going down
	STRCPY_PRINT "Sim\xb8"				; print down arrow for going down
	bra		menuview_exit				; done

menuview_view4:
	btfss	simulatormode_active		; in simulator mode?
	bra		menuview_toggle				; NO - goto next option
;	STRCPY_PRINT "Sim+1m"				; "+" for going up
	STRCPY_PRINT "Sim\xb9"				; print up arrow for going up
	bra		menuview_exit				; done

menuview_view5:
	btfss	FLAG_apnoe_mode				; in Apnoe mode?
	bra		menuview_toggle				; NO - goto next option
	btfss	FLAG_active_descent			; descending?
	bra		menuview_toggle				; YES - goto next option
	; We are at the surface:
	STRCPY_TEXT_PRINT tQuitSim			; print "Quit Apnea mode?"
	bra		menuview_exit				; done

menuview_view6:
	btfss	FLAG_gauge_mode				; in Gauge mode?
	bra		menuview_toggle				; NO - goto next option
	STRCPY_TEXT_PRINT tDivemenu_ResetAvg; print "Reset Avg."
	bra		menuview_exit				; done

menuview_view7:
	btfss	simulatormode_active		; in simulator mode?
	bra		menuview_toggle				; NO - goto next option
	btfsc	FLAG_gauge_mode				; in Gauge mode?
	bra		menuview_toggle				; YES - goto next option
	btfsc	FLAG_apnoe_mode				; in Apnoe mode?
	bra		menuview_toggle				; YES - goto next option
	STRCPY_PRINT "Sim+5'"				; print "Sim+5'"
	bra		menuview_exit				; done

menuview_view8:
	movlw	index_compass_dm			; index of compass view
	cpfseq	menupos3					; in compass view?
	bra		menuview_toggle				; NO - goto next option
	STRCPY_TEXT_PRINT tSetHeading		; print "Heading"
	bra		menuview_exit				; done

menuview_view9:
	btfsc	FLAG_apnoe_mode				; in Apnoe mode?
	bra		menuview_toggle				; YES - goto next option
	STRCPY_PRINT "Layout"
	bra		menuview_exit				; done

;=============================================================================

	global	customview_mask_alternative
customview_toggle_alternative:
	call	I2C_sleep_accelerometer		; no compass in alternative layout - stop accelerometer
	call	I2C_sleep_compass			; no compass in alternative layout - stop compass
	movlw	d'0'						; max number of custom views in divemode, alternative layout
	cpfsgt	menupos3					; max reached?
	bra		customview_mask_alternative	; NO - show
	clrf	menupos3					; reset to zero (zero = default custom view in alternative layout)
customview_mask_alternative:
	; Clear custom view area in divemode
	WIN_BOX_BLACK dm_customview_row, .239, .0, .159 ; top, bottom, left, right
	movf	menupos3,W					; menupos3 holds number of custom view function
	dcfsnz	WREG,F
	bra		customview_alt_init_view1	; view 1: -- for test only --
	dcfsnz	WREG,F
	nop									; view 2: ...
	;bra	customview_alt_init_view0	; default view: big deco/ndl and max. depth

customview_alt_init_view0:				; default view: big deco/ndl and max. depth
	call	TFT_max_depth_alternative
	call	TFT_big_deco_alt
	bra		customview_alt_toggle_exit

customview_alt_init_view1:				; view 1 - just for test use
	call	TFT_avr_stopwatch_mask		; mask for average depth and stopwatch
	call	TFT_avr_stopwatch			; data for average depth and stopwatch
	bra		customview_alt_toggle_exit

customview_alt_toggle_exit:
	bcf		toggle_customview			; clear flag
	return


; Show next dive mode custom view (and delete this flag)
	global	customview_toggle
customview_toggle:
	bcf		switch_right
	incf	menupos3,F					; number of custom view to show

	btfsc	alternative_divelayout			; in alternative layout mode?
	bra		customview_toggle_alternative	; YES - use the big ones instead

	movlw	index_compass_dm			; index of custom view compass
	cpfseq	menupos3					; will compass be shown in custom view?
	call	I2C_sleep_accelerometer		; NO - stop accelerometer
	cpfseq	menupos3					; will compass be shown in custom view?
	call	I2C_sleep_compass			; NO - stop compass

	movlw	index_cv_dm_max				; highest index in use in dive mode custom view
	cpfsgt	menupos3					; max reached?
	bra		customview_mask				; NO - show
	clrf	menupos3					; reset to zero (zero = no custom view)

;----------------------------------------------------------------------------------
; Jump table for initialization of the every-second tasks in custom view area (dive mode)
;
; Attention: the ordering must be in line with the every-second update jump table
;            and the index numbers defined in hwos.inc!
;
	global	customview_mask
customview_mask:
	bcf		redraw_custview_mask		; clear redraw request flag
	; Clear custom view area in divemode
	WIN_BOX_BLACK dm_customview_row, dm_customview_bot-.2, dm_customview_column, dm_customview_rgt ; top, bottom, left, right
	movf	menupos3,W					; menupos3 holds number of custom view function
	dcfsnz	WREG,F						; 1:
	bra		init_avr_stopwatch			; average depth and stopwatch
	dcfsnz	WREG,F						; 2:
	bra		init_TFT_dive_compass		; compass
	dcfsnz	WREG,F						; 3:
	bra		init_ppo2_sensors			; ppO2 sensors
	dcfsnz	WREG,F						; 4:
	bra		init_sensor_check			; sensor check
	dcfsnz	WREG,F						; 5:
	bra		init_pscr_info				; pSCR data
	dcfsnz	WREG,F						; 6:
	bra		init_pressures_SAC			; tank pressure and SAC rate
	dcfsnz	WREG,F						; 7:
	bra		init_gas_needs_ascent		; gas needs for ascent / cave return
	dcfsnz	WREG,F						; 8:
	bra		init_decoplan				; deco plan
	dcfsnz	WREG,F						; 9:
	bra		init_ceiling_GF_tissue		; ceiling, current GF and tissues
	dcfsnz	WREG,F						; 10:
	bra		init_CNS					; CNS values
	dcfsnz	WREG,F						; 11:
	bra		init_ppo2_ead_end_cns		; ppO2, END/EAD and CNS
	dcfsnz	WREG,F						; 12:
	bra		init_gf_factors				; GF factors
	dcfsnz	WREG,F						; 13:
	bra		init_clock_batt_surfpress	; clock, battery and surface pressure
	bra		customview_toggle_exit		; no view (blank screen in custom view area)


init_ppo2_sensors:
	btfsc	FLAG_ccr_mode				; in CC mode?
	bra		customview_init_view1a		; YES
	btfsc	FLAG_pscr_mode				; in PSCR mode?
	bra		customview_init_view1a		; YES
	bra		customview_toggle			; NO to both, call next view
customview_init_view1a:
	btfsc	analog_o2_input				; do we have an analog input?
	bra		customview_init_view1b		; YES - show this view
	btfsc	s8_digital					; NO  - do we have a digital input?
	bra		customview_init_view1b		; YES - show this view
	btfss	optical_input				; NO  - do we have an optical input?
	bra		customview_toggle			; NO  - call next view
	;       YES - show this view
customview_init_view1b:
	call	TFT_ppo2_sensors_mask		; mask for ppO2 sensors
	call	TFT_ppo2_sensors			; data for ppO2 sensors
	bra		customview_toggle_exit

init_avr_stopwatch:
	btfsc	FLAG_apnoe_mode				; in apnoe mode?
	bra		customview_toggle			; YES - call next view
	call	TFT_avr_stopwatch_mask		; mask for average depth and stopwatch
	call	TFT_avr_stopwatch			; data for average depth and stopwatch
	bra		customview_toggle_exit

init_decoplan:
	btfsc	FLAG_apnoe_mode				; in apnoe mode?
	bra		customview_toggle			; YES - call next view
	btfsc	FLAG_gauge_mode				; in gauge mode?
	bra		customview_toggle			; YES - call next view
	call	TFT_decoplan_mask			; mask for deco plan
	call	TFT_decoplan				; data for deco plan
	bra		customview_toggle_exit

init_clock_batt_surfpress:
	call	TFT_clock_batt_surfpress_mask	; mask for clock, battery and surface pressure
	call	TFT_clock_batt_surfpress		; data for clock, battery and surface pressure
	bra		customview_toggle_exit

init_gf_factors:
	btfsc	FLAG_apnoe_mode				; in apnoe mode?
	bra		customview_toggle			; YES - call next view
	btfsc	FLAG_gauge_mode				; in gauge mode?
	bra		customview_toggle			; YES - call next view
	TSTOSS	char_I_deco_model			; in GF mode (0 = ZH-L16, 1 = ZH-L16-GF)?
	bra		customview_toggle			; NO - no GF info for non-GF modes
	call	TFT_gf_factors_mask			; mask for GF factors
	bra		customview_toggle_exit

init_TFT_dive_compass:					; compass
	call	I2C_init_compass			; start compass
	call	I2C_init_accelerometer		; start accelerometer
	call	TFT_dive_compass_mask		; show compass mask
	bra		customview_toggle_exit

init_pressures_SAC:						; tank pressure and SAC rate
 IFDEF _rx_functions
	btfss	FLAG_tr_enabled				; TR functions enabled?
	bra		customview_toggle			; NO - call next view
	call	TFT_pressures_SAC_mask		; mask for pressures and SAC
	call	TFT_pressures_SAC			; data for pressures and SAC
	bra		customview_toggle_exit
 ELSE
	bra		customview_toggle			; skip, not available without RX functions
 ENDIF

init_CNS:								; CNS at end of dive
	btfsc	FLAG_gauge_mode				; in Gauge mode?
	bra		customview_toggle			; YES - call next view
	btfsc	FLAG_apnoe_mode				; in apnoe mode?
	bra		customview_toggle			; YES - call next view
	call	TFT_CNS_mask				; mask for CNS values
	call	TFT_CNS						; data for CNS values
	bra		customview_toggle_exit

init_ceiling_GF_tissue:					; ceiling, tissues and current GF
	btfsc	FLAG_apnoe_mode				; in apnoe mode?
	bra		customview_toggle			; YES - call next view
	btfsc	FLAG_gauge_mode				; in gauge mode?
	bra		customview_toggle			; YES - call next view
	call	TFT_ceiling_GF_tissue_mask	; mask for ceiling, current GF and tissues
	call	TFT_ceiling_GF_tissue		; data for ceiling, current GF and tissues
	bra		customview_toggle_exit

init_sensor_check:						; sensor check
	btfsc	FLAG_ccr_mode				; in CCR mode?
	bra		customview_init_view10a		; YES
;	btfsc	FLAG_pscr_mode				; in pSCR mode?
;	bra		customview_init_view10a		; YES
	bra		customview_toggle			; NO to both, call next view
customview_init_view10a:
	call	TFT_sensor_check_mask		; mask for sensor check
	call	TFT_sensor_check			; data for sensor check
	bra		customview_toggle_exit

init_ppo2_ead_end_cns:					; ppO2, END/EAD and CNS
	btfsc	FLAG_apnoe_mode				; in apnoe mode?
	bra		customview_toggle			; YES - call next view
	btfsc	FLAG_gauge_mode				; in gauge mode?
	bra		customview_toggle			; YES - call next view
	call	TFT_ppo2_ead_end_cns_mask	; mask for ppO2, END/EAD and CNS
	call	TFT_ppo2_ead_end_cns		; data for ppO2, END/EAD and CNS
	bra		customview_toggle_exit

init_pscr_info:							; pSCR information
	btfss	FLAG_pscr_mode				; in pSCR mode?
	bra		customview_toggle			; NO - call next view
	call	TFT_pscr_info_mask			; mask for pSCR info
	call	TFT_pscr_info				; data for pSCR info
	bra		customview_toggle_exit

init_gas_needs_ascent:					; gas needs for ascent
	btfsc	FLAG_apnoe_mode				; in apnoe mode?
	bra		customview_toggle			; YES - call next view
	btfsc	FLAG_gauge_mode				; in gauge mode?
	bra		customview_toggle			; YES - call next view
	TSTOSS	opt_calc_asc_gasvolume		; check if gas volume calculation is switched on
	bra		customview_toggle			; NO  - call next view
	call	TFT_gas_needs_ascent_mask	; mask for gas needs ascent
	call	TFT_gas_needs_ascent		; data for gas needs ascent
	bra		customview_toggle_exit

customview_toggle_exit:
	bcf		toggle_customview			; clear flag
	btfsc	divemode					; in dive mode?
	bsf		FLAG_TFT_temp_divemode		; YES - set flag to redraw temp
	return


	global	customview_show_mix
customview_show_mix:					; put "Nxlo", "Txlo/hi", "Air" or "O2" into postinc2
	tstfsz	hi							; He=0?
	bra		customview_show_mix5		; NO - show a TX
	movlw	.21
	cpfseq	lo							; Air?
	bra		customview_show_mix2		; NO
	STRCAT_TEXT tSelectAir				; YES - show "Air"
	bra		customview_show_mix4b
customview_show_mix2:
	movlw	.100
	cpfseq	lo							; O2?
	bra		customview_show_mix3		; NO
	STRCAT_TEXT tSelectO2				; YES - show "O2"
	bra		customview_show_mix4b
customview_show_mix3:
	movlw	.21
	cpfslt	lo							; < Nx21?
	bra		customview_show_mix4		; NO
	STRCAT_TEXT tGasErr					; YES - show "Err"
	output_99							; O2 ratio is still in "lo"
	bra		customview_show_mix4c
customview_show_mix4:
	STRCAT_TEXT tSelectNx				; show "Nx"
	output_99							; O2 ratio is still in "lo"
customview_show_mix4b:
	STRCAT	" "
customview_show_mix4c:
	btfsc	divemode					; in divemode?
	return								; YES
	STRCAT	"  "
	return
customview_show_mix5:
	btfsc	divemode
	bra		customview_show_mix6
	STRCAT_TEXT tSelectTx				; show "Tx"
customview_show_mix6:
	output_99							; O2 ratio is still in "lo"
	PUTC	"/"
	movff	hi,lo
	output_99							; He ratio
	return

	END