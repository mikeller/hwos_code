;=============================================================================
;
;   File customview.asm                     * combined next generation V3.09.5
;
;   Custom Views in Surface and Dive Mode
;
;   Copyright (c) 2011, JD Gascuel, heinrichs weikamp gmbh, all right reserved.
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
#include "colorschemes.inc"


	extern	gaslist_strcat_gas_PRODL
	extern	char_I_model

 IFDEF _compass
	extern	TFT_surface_compass_mask
	extern	TFT_dive_compass_mask
 ENDIF


#DEFINE num_premenu_items	.12			; overall number of pre-menu items
#DEFINE num_surface_cv		.11			; overall number of surface custom views


;=============================================================================
custview1	CODE
;=============================================================================

;-----------------------------------------------------------------------------
; Jump Table for the every-second Tasks for the Custom View Area (Dive Mode)
;
; Attention: the ordering must be in line with the init jump table and the
;            index numbers defined in hwos.inc!
;
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


;=============================================================================
custview2	CODE
;=============================================================================


;-----------------------------------------------------------------------------
; Show next Surface Custom View
;
	global	surf_customview_toggle
surf_customview_toggle:
	bcf		switch_right				; clear button event
	incf	active_customview,F			; set number of the next custom view to show

 IFDEF _compass
	movlw	.6							; load index of surface custom view compass
	cpfseq	active_customview			; will the compass be shown in custom view?
	call	I2C_sleep_compass			; NO - can stop the compass to save on energy
 ENDIF

	movlw	num_surface_cv				; load number of custom views available
	cpfsgt	active_customview			; beyond last view?
	bra		surf_customview_mask		; NO  - show view
	movlw	.1							; YES - wrap around to 1st view
	movwf	active_customview			;     - ...
	;bra	surf_customview_mask		;     - show view


;-----------------------------------------------------------------------------
; Show Surface Custom View
;
	global	surf_customview_mask
surf_customview_mask:

	; prepare output of custom view title
	WIN_BOX_BLACK .50,surf_warning1_row-1, .0, surf_decotype_column-.1	; top, bottom, left, right
	WIN_TINY   surf_customview_title_column,surf_customview_title_row	; set title position
	FONT_COLOR color_greenish											; set title color

	; jump table
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
	dcfsnz	WREG,F						; 11:
	bra		surf_customview_init_view11	; Desat, noFly, CNS screen
	bra		surf_customview_init_view4	; 0: default view after restart and loading of new firmware

surf_cv_toggle_exit:
	bcf		request_next_custview		; clear request flag
	return								; done

	; ---- view 1: OC Gas list ----
	;
surf_customview_init_view1:
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
	call	TFT_surf_cv_list_gas		; show gas list
	bra		surf_cv_toggle_exit			; done


	; ---- view 2: CCR / pSCR diluent list ----
	;
surf_customview_init_view2:
 IFDEF _ccr_pscr
	btfsc	FLAG_ccr_mode				; in CCR mode?
	bra		surf_customview_init_view2a	; YES - (1)
	btfsc	FLAG_pscr_mode				; in pSCR mode?
	bra		surf_customview_init_view2a	; YES - (1)
	bra		surf_customview_toggle		; NO  - not available if not in CCR or pSCR mode, goto next view
surf_customview_init_view2a:
	STRCPY_TEXT_PRINT tGaslistCC		; (1) - title of custom view
	call	TFT_surf_cv_list_dil		;     - show diluent list
	bra		surf_cv_toggle_exit			;     - done
 ELSE
	bra		surf_customview_toggle		; not available without CCR/pSCR mode compiled in, goto next view
 ENDIF


	; ---- view 3: CC SP list ----
	;
surf_customview_init_view3:
 IFDEF _ccr_pscr
	btfss	FLAG_ccr_mode				; in CCR mode?
	bra		surf_customview_toggle		; NO  - not available if not in CCR mode, goto next view
	STRCPY_TEXT_PRINT tFixedSetpoints	; YES - title of custom view
	call	TFT_surf_cv_list_sp			;     - show setpoint list
	bra		surf_cv_toggle_exit			;     - done
 ELSE
	bra		surf_customview_toggle		; not available without CCR/pSCR mode compiled in, goto next view
 ENDIF


	; ---- view 4: custom text
	;
surf_customview_init_view4:
	call	TFT_surf_cv_text			; show the custom text
	bra		surf_cv_toggle_exit			; done


	; ---- view 5: tissue diagram
	;
surf_customview_init_view5:
	btfsc	FLAG_gauge_mode				; in gauge mode?
	bra		surf_customview_toggle		; YES - not available in gauge mode, goto next view
	btfsc	FLAG_apnoe_mode				; in apnoe mode?
	bra		surf_customview_toggle		; YES - not available in apnoe mode, goto next view
	call	TFT_surf_cv_tissues			; show tissue diagram
	bra		surf_cv_toggle_exit			; done


	; ---- view 6: compass
	;
surf_customview_init_view6:
 IFDEF _compass
	call	I2C_init_compass			; start compass
	call	TFT_surface_compass_mask	; show compass mask
	bra		surf_cv_toggle_exit			; done
 ELSE
	bra		surf_customview_toggle		; not available without compass compiled in, goto next view
 ENDIF


	; ---- view 7: deco settings ----
	;
surf_customview_init_view7:
	btfsc	FLAG_gauge_mode				; in gauge mode?
	bra		surf_customview_toggle		; YES - not available in gauge mode, goto next view
	btfsc	FLAG_apnoe_mode				; in apnoe mode?
	bra		surf_customview_toggle		; YES - not available in apnoe mode, goto next view
	call	TFT_surf_cv_settings		; show all deco settings
	bra		surf_cv_toggle_exit			; done


	; ---- view 8: last dive info ----
	;
surf_customview_init_view8:
	call	TFT_surf_cv_lastdive		; show last dive info
	bra		surf_cv_toggle_exit			; done


	; ---- view 9: sensor mV at the surface ----
	;
surf_customview_init_view9:
 IFDEF _external_sensor
	btfsc	FLAG_ccr_mode				; in CCR mode?
	bra		surf_customview_init_view9a	; YES - show view
	btfsc	FLAG_pscr_mode				; NO  - in pSCR mode?
	bra		surf_customview_init_view9a	;       YES - show view
	bra		surf_customview_toggle		;       NO  - not available if not in CCR or pSCR mode, goto next view

surf_customview_init_view9a:
	movff	opt_ccr_mode,WREG			; get SP mode (0: fixed SP, 1: Sensor, 2: auto SP)
	decfsz	WREG,W						; opt_ccr_mode = 1 (sensor)?
	bra		surf_customview_toggle		; NO  - goto next view
	STRCPY_TEXT_PRINT tSensorMilliVolt	; YES - title of custom view
	call	TFT_imprint_surf_mV			;     - write sensor mV readings to screen 
	bra		surf_cv_toggle_exit			;     - done
 ELSE
	bra		surf_customview_toggle		; not available without CCR/pSCR mode compiled in, goto next view
 ENDIF


	; ---- view 10: transmitter data / debug ----
	;
surf_customview_init_view10:
 IFDEF _rx_functions
	btfss	tr_functions_activated		; TR functions activated?
	bra		surf_customview_toggle		; NO  - show next view in list
	STRCAT_PRINT "ID     bar  Volt"		; YES - title of custom view (none language-dependent)
	call	TFT_surf_cv_tankdata		;     - show received data
	bra		surf_cv_toggle_exit			;     - done
 ELSE
	bra		surf_customview_toggle		; not available without RX functions compiled in, goto next view
 ENDIF

	; ---- view 11: Desat, NoFly, CNS ----
	;
surf_customview_init_view11: 
    	btfsc	FLAG_gauge_mode				; in gauge mode?
	bra		surf_customview_toggle		; YES - not available in gauge mode, goto next view
	btfsc	FLAG_apnoe_mode				; in apnoe mode?
	bra		surf_customview_toggle		; YES - not available in apnoe mode, goto next view
	call	TFT_surf_desat_nofly_cns		; Desat, NoFly, CNS
	bra		surf_cv_toggle_exit			; done

;=============================================================================
custview3	CODE
;=============================================================================


;-----------------------------------------------------------------------------
; Show next Pre-Menu Item / Clear the Pre-Menu
;
	global	menuview_toggle
menuview_toggle:
	bcf		switch_left					; clear button event
	movlw	divemode_timeout_premenu	; get timeout for dive mode pre-menu
	call	restart_timeout_time		; restart the timeout
	bsf		dive_pre_menu				; flag that the pre-menu is shown
menuview_next_item:
	incf	active_premenu,F			; increment     pre-menu item number
	movlw	num_premenu_items			; get number of pre-menu items
	cpfsgt	active_premenu				; beyond last item?
	bra		menuview_mask				; NO  - show item
	;bra	menuview_toggle_reset		; YES - reset to first item

	global	menuview_toggle_reset
menuview_toggle_reset:
	clrf	active_premenu				; reset pre-menu item number
	bcf		dive_pre_menu				; flag that the pre-menu is not shown anymore
	;bra	menuview_mask				; clear last item from display

menuview_mask:
	WIN_BOX_BLACK dm_premenu_row, dm_premenu_bot, dm_premenu_col, dm_premenu_rgt ; top, bottom, left, right
	btfsc	dive_pre_menu				; shall show pre-menu?
	bra		menuview_show_item			; YES - show menu item
	;bra	menuview_exit				; NO  - done with pre-menu

menuview_exit:
	bcf		win_invert					; clear inverse printing
	btfss	dive_pre_menu				; showing pre-menu?
	goto	TFT_show_temp_divemode		; NO  - restore temperature display and return
	return								; YES - done

menuview_show_item:
	WIN_SMALL dm_premenu_col,dm_premenu_row
	FONT_COLOR_ATTENTION				; set color
	bsf		win_invert					; set inverse printing
	movf	active_premenu,W			; get active pre-menu item
	dcfsnz	WREG,F
	bra		menuview_view_gaschange		;  1: gas change	(skipped if no better gas/dil cued)
	dcfsnz	WREG,F
	bra		menuview_view_ackn			;  2: "Ackn?"		(skipped if no active advice/attention/warning sign)
	dcfsnz	WREG,F
	bra		menuview_view_divemenu		;  3: "Menu?"		(skipped in gauge and apnoe modes)
	dcfsnz	WREG,F
 IFDEF _cave_mode
	bra		menuview_view_cavemenu		;  4: "Cave?"		(skipped if not in cave mode)
 ELSE
	bra		menuview_next_item			;  4: cave mode not implemented, goto next item
 ENDIF
	dcfsnz	WREG,F
	bra		menuview_view_sim_quit		;  5: "Quit?"		(in simulation mode only)
	dcfsnz	WREG,F
	bra		menuview_view_sim_down		;  6: "Sim down"	(in simulation mode only)
	dcfsnz	WREG,F
	bra		menuview_view_sim_up		;  7: "Sim up"		(in simulation mode only)
	dcfsnz	WREG,F
	bra		menuview_view_sim_time		;  8: "Sim+5'"		(in simulation mode only)
	dcfsnz	WREG,F
	bra		menuview_view_apnoe_quit	;  9: "Quit?"		(in apnoe mode only)
	dcfsnz	WREG,F
	bra		menuview_view_gauge_reset	; 10: "Reset Avr"	(in gauge mode only)
	dcfsnz	WREG,F
 IFDEF _compass
	bra		menuview_view_course		; 11: "Course"		(only when compass is shown)
 ELSE
	bra		menuview_next_item			; 11: compass not implemented, goto next item
 ENDIF
	dcfsnz	WREG,F
	bra		menuview_view_layout		; 12: "Layout"		(offer alternative layout, aka blind mode)
	bra		menuview_exit				; catch illegal item number
	; when adding or removing items, adjust the value num_premenu_items in the #DEFINE !


	; --- item 1: gas change advice ---
	;
menuview_view_gaschange:
	btfsc	request_gas_change			; last gas change request already executed?
	bra		menuview_next_item			; YES - goto next option
 IFDEF _ccr_pscr
	btfsc	FLAG_oc_mode				; in OC mode?
	bra		menuview_view_gaschange_OC	; YES
	btfsc	bailout_mode				; in bailout?
	bra		menuview_view_gaschange_OC	; YES
menuview_view_gaschange_DIL:
	btfss	better_dil_available		; is the better diluent still available?
	bra		menuview_next_item			; NO - goto next item
	movff	best_dil_number,PRODL		; number (1-5) of the "best diluent"
	bsf		is_diluent_menu				; setting up diluents
	bra		menuview_view_gaschange_com	; continue with common part
 ENDIF	; _ccr_pscr
menuview_view_gaschange_OC:
	btfss	better_gas_available		; is the better gas still available?
	bra		menuview_next_item			; NO  - goto next item
	movff	best_gas_number,PRODL		; YES - number (1-5) of the "best gas"
	bcf		is_diluent_menu				;     - setting up OC gases
menuview_view_gaschange_com:
	decf	PRODL,F						; (1-5) -> (0-4)
	bsf		short_gas_descriptions		; use short version of gaslist_strcat_gas_PRODL and gaslist_strcat_setpoint
	bsf		better_gas_hint				; color-code as best gas/diluent
	call	gaslist_strcat_gas_PRODL	; append gas description of gas #PRODL (0-4) to current string
	movlw	.5							; point to 6th character (5 chars are used for the gas/dil description)
	movwf	FSR2L						; ...
	PUTC_PRINT "?"						; append question and dump buffer to screen
	bra		menuview_exit				; done

	; ---- item 2: acknowledge ----
	;
menuview_view_ackn:
	btfss	sign_shown					; advice, attention or warning sign shown?
	bra		menuview_next_item			; NO  - goto next item
	STRCAT_TEXT_PRINT tDiveAckn			; YES - print "Ackn?"
	bra		menuview_exit				;     - done


	; ---- item 3: dive menu ----
	;
menuview_view_divemenu:
	btfsc	FLAG_apnoe_mode				; in apnoe mode?
	bra		menuview_next_item			; YES - goto next item
	btfsc	FLAG_gauge_mode				; NO  - in gauge mode?
	bra		menuview_next_item			;       YES - goto next item
	PUTC	"\xb7"						;       NO  - print '->' symbol
	STRCAT_TEXT_PRINT tDivePreMenu		;           - print "Menu?"
	bra		menuview_exit				;           - done


	; ---- item 4: cave menu ----
	;
 IFDEF _cave_mode
menuview_view_cavemenu:
	TSTOSS	opt_cave_mode				; cave mode switched on?
	bra		menuview_next_item			; NO  - goto next item
	PUTC	"\xb7"						; YES - print '->' symbol
	STRCAT_TEXT_PRINT tDivePreCave		;     - print "Cave?"
	bra		menuview_exit				;     - done
 ENDIF	; _cave_mode


	; ---- item 5: quit simulator ---
	;
menuview_view_sim_quit:
	btfss	simulatormode				; in simulator mode?
	bra		menuview_next_item			; NO  - goto next item
	STRCPY_TEXT_PRINT tQuitSim			; YES - print "Quit Simulation?"
	bra		menuview_exit				;     - done


	; ---- item 6: simulator - go down ----
	;
menuview_view_sim_down:
	btfss	simulatormode				; in simulator mode?
	bra		menuview_next_item			; NO - goto next item
	STRCPY_PRINT "Sim\xb8"				; print down arrow for going down
	bra		menuview_exit				; done


	; ---- item 7: simulator - go up ----
	;
menuview_view_sim_up:
	btfss	simulatormode				; in simulator mode?
	bra		menuview_next_item			; NO  - goto next item
	STRCPY_PRINT "Sim\xb9"				; YES - print up arrow for going up
	bra		menuview_exit				;     - done


	; ---- item 8: simulator - advance time ----
	;
menuview_view_sim_time:
	btfss	simulatormode				; in simulator mode?
	bra		menuview_next_item			; NO  - goto next item
	btfsc	FLAG_gauge_mode				; YES - in gauge mode?
	bra		menuview_next_item			;       YES - goto next item
	btfsc	FLAG_apnoe_mode				;       NO  - in apnoe mode?
	bra		menuview_next_item			;             YES - goto next item
	STRCPY_PRINT "Sim+5'"				;             NO  - print "Sim+5'"
	bra		menuview_exit				;                 - done


	; ---- item 9: apnoe mode - quit ----
	;
menuview_view_apnoe_quit:
	btfss	FLAG_apnoe_mode				; in apnoe mode?
	bra		menuview_next_item			; NO  - goto next option
	btfss	apnoe_at_surface			; YES - at the surface?
	bra		menuview_next_item			;       NO  - goto next item
	STRCPY_TEXT_PRINT tQuitSim			;       YES - print "Quit Apnea mode?"
	bra		menuview_exit				;           - done


	; ---- item 10: gauge mode - reset average ----
	;
menuview_view_gauge_reset:
	btfss	FLAG_gauge_mode				; in gauge mode?
	bra		menuview_next_item			; NO  - goto next item
	STRCPY_TEXT_PRINT tResetAvg			; YES - print "Reset Avg."
	bra		menuview_exit				;     - done


	; ---- item 11: set bearing ----
 IFDEF _compass
menuview_view_course:
	movlw	index_compass_dm			; index of compass view
	cpfseq	active_customview			; in compass view?
	bra		menuview_next_item			; NO  - goto next item
	STRCPY_TEXT_PRINT tSetHeading		; YES - print "Heading"
	bra		menuview_exit				;     - done
 ENDIF


	; ---- item 12: switch layout ----
	;
menuview_view_layout:
	btfsc	FLAG_apnoe_mode				; in apnoe mode?
	bra		menuview_next_item			; YES - goto next item
	STRCPY_TEXT_PRINT tDiveLayout		; NO  - print "Layout"
	bra		menuview_exit				;     - done


;=============================================================================
custview4	CODE
;=============================================================================


;-----------------------------------------------------------------------------
; Show a specific Dive Mode Custom View
;
	global	dive_customview_show
dive_customview_show:
	btfss	custom_view_locked			; custom view locked?
	bra		dive_customview_show_1		; NO  - call-up the view
	movwf	backup_customview			; YES - store requested custom view for later recall
	return								;     - done
dive_customview_show_1:
	movwf	active_customview			; set the requested custom view
	bra		dive_customview_callup		; call-up the custom view


;-----------------------------------------------------------------------------
; Show again last Dive Mode Custom View
;
	global	dive_customview_recall
dive_customview_recall:
	movff	backup_customview,active_customview	; recall the saved custom view
	bra		dive_customview_callup				; call-up the custom view


;-----------------------------------------------------------------------------
; Show next Dive Mode Custom View
;
	global	dive_customview_toggle
dive_customview_toggle:
	incf	active_customview,F			; increment number of custom view to show
	movlw	index_cv_dm_max				; get highest index in use in dive mode custom view
	cpfsgt	active_customview			; beyond last view?
	bra		dive_customview_callup		; NO  - call-up the custom view
	clrf	active_customview			; YES - reset to zero (zero = blank custom view)
	;bra	dive_customview_callup		; call-up the custom view


;-----------------------------------------------------------------------------
; Show current Dive Mode Custom View
;
	global	dive_customview_callup
dive_customview_callup:
	movlw	index_compass_dm			; get index of compass custom view
	cpfseq	active_customview			; will compass be shown?
	call	I2C_sleep_compass			; NO - stop compass to save on energy

	; clear custom view area in dive mode
	WIN_BOX_BLACK dm_customview_row, dm_customview_bot-.2, dm_customview_column, dm_customview_rgt ; top, bottom, left, right

	; jump table
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
	bra		init_ppo2_ead_end_cns		; 12: ppO2, END/EAD and CNS/gas density
	dcfsnz	WREG,F						;
	bra		init_clock_batt_surfpress	; 13: clock, battery and surface pressure
	dcfsnz	WREG,F						;
	bra		init_gf_factors				; 14: GF factors
	dcfsnz	WREG,F						;
	bra		init_cave_waypoints			; 15: cave waypoints
	;bra	dive_cv_toggle_exit			;  0: no view (blank screen in custom view area)

dive_cv_toggle_exit:
	bcf		request_next_custview		; clear request flag
	return								; done


	; ---- view 1: average depth and stopwatch ----
	;
init_avr_stopwatch:
	btfsc	FLAG_apnoe_mode				; in apnoe mode?
	bra		dive_customview_toggle		; YES - goto next view
	call	TFT_avr_stopwatch_mask		; NO  - mask for average depth and stopwatch
	call	TFT_avr_stopwatch			;     - data for average depth and stopwatch
	bra		dive_cv_toggle_exit			;     - done


	; ---- view 2: compass ----
	;
init_TFT_dive_compass:
 IFDEF _compass
	call	I2C_init_compass			; start compass
	call	TFT_dive_compass_mask		; mask for compass
	bra		dive_cv_toggle_exit			; done
 ELSE
	bra		dive_customview_toggle		; not available without compass compiled in, goto next view
 ENDIF


	; ---- view 3: ppO2 sensors ---
	;
init_ppo2_sensors:
 IFDEF _external_sensor
	bsf		trigger_temp_changed		; fake a change of the temperature to have the resettable dive time overwritten which was shown with the compass view
	btfsc	FLAG_ccr_mode				; in CC mode?
	bra		init_ppo2_sensors_1			; YES
	btfsc	FLAG_pscr_mode				; in pSCR mode?
	bra		init_ppo2_sensors_1			; YES
	bra		dive_customview_toggle		; NO to both, goto next view
init_ppo2_sensors_1:
	btfsc	ext_input_s8_ana			; do we have an S8/analog input?
	bra		init_ppo2_sensors_2			; YES - show this view
	btfsc	ext_input_optical			; NO  - do we have an optical input?
	bra		init_ppo2_sensors_2			;       YES - show this view
	bra		dive_customview_toggle		;       NO  - goto next view

init_ppo2_sensors_2:
	call	TFT_ppo2_sensors_mask		; mask for ppO2 sensors
	call	TFT_ppo2_sensors			; data for ppO2 sensors
	bra		dive_cv_toggle_exit			; done
 ELSE
	bra		dive_customview_toggle		; not available without external sensors, got next view
 ENDIF

	; ---- view 4: sensor check ----
	;
init_sensor_check:
 IFDEF _ccr_pscr
	btfss	FLAG_ccr_mode				; in CCR mode?
	bra		dive_customview_toggle		; NO  - goto next view
	call	TFT_sensor_check_mask		; YES - mask for sensor check
	call	TFT_sensor_check			;     - data for sensor check
	bra		dive_cv_toggle_exit			;     - done
 ELSE
	bra		dive_customview_toggle		; not available without CCR mode compiled in, goto next view
 ENDIF


	; ---- view 5: pSCR data ----
	;
init_pscr_info:
 IFDEF _ccr_pscr
	btfss	FLAG_pscr_mode				; in pSCR mode?
	bra		dive_customview_toggle		; NO  - goto next view
	call	TFT_pscr_info_mask			; YES - mask for pSCR info
	call	TFT_pscr_info				;     - data for pSCR info
	bra		dive_cv_toggle_exit			;     - done
 ELSE
	bra		dive_customview_toggle		; not available without CCR / pSCR mode, goto next view
 ENDIF


	; view 6: tank pressure and SAC rate ----
	;
init_pressures_SAC:
 IFDEF _rx_functions
	btfss	tr_functions_activated		; TR functions activated?
	bra		dive_customview_toggle		; NO  - goto next view
	call	TFT_pressures_SAC_mask		; YES - mask for pressures and SAC
	call	TFT_pressures_SAC			;     - data for pressures and SAC
	bra		dive_cv_toggle_exit			;     - done
 ELSE
	bra		dive_customview_toggle		; not available without RX functions, got next view
 ENDIF


	; ---- view 7: gas needs ----
	;
init_gas_needs_ascent:
	btfsc	FLAG_apnoe_mode				; in apnoe mode?
	bra		dive_customview_toggle		; YES - goto next view
	btfsc	FLAG_gauge_mode				; NO  - in gauge mode?
	bra		dive_customview_toggle		;       YES - goto next view
	TSTOSS	opt_calc_gasvolume			;       NO  - check if gas volume calculation is switched on
	bra		dive_customview_toggle		;             NO  - goto next view
	call	TFT_gas_needs_mask			;             YES - mask for gas needs ascent
	call	TFT_gas_needs				;                 - data for gas needs ascent
	bra		dive_cv_toggle_exit			;                 - done


	; ---- view 8: cave mode TTS ----
init_cave_tts:
 IFDEF _cave_mode
	btfss	cave_mode					; in cave mode?
	bra		dive_customview_toggle		; NO  - goto next view
	call	TFT_cave_tts_mask			; YES - show mask
	call	TFT_cave_tts				;     - show data
	bra		dive_cv_toggle_exit			;     - done
 ELSE
	bra		dive_customview_toggle		; not available without cave mode, goto next view
 ENDIF


	; ---- view 9: deco plan ----
	;
init_decoplan:
	btfsc	FLAG_apnoe_mode				; in apnoe mode?
	bra		dive_customview_toggle		; YES - goto next view
	btfsc	FLAG_gauge_mode				; NO  - in gauge mode?
	bra		dive_customview_toggle		;       YES - goto next view
	call	TFT_decoplan_mask			;       NO  - mask for deco plan
	call	TFT_decoplan				;           - data for deco plan
	bra		dive_cv_toggle_exit			;           - done


	; ---- view 10: ceiling, tissues and current GF
	;
init_ceiling_GF_tissue:
	btfsc	FLAG_apnoe_mode				; in apnoe mode?
	bra		dive_customview_toggle		; YES - goto next view
	btfsc	FLAG_gauge_mode				; NO  - in gauge mode?
	bra		dive_customview_toggle		;       YES - call next view
	call	TFT_ceiling_GF_tissue_mask	;       NO  - mask for ceiling, current GF and tissues
	call	TFT_ceiling_GF_tissue		;           - data for ceiling, current GF and tissues
	bra		dive_cv_toggle_exit			;           - done


	; ---- view 11: CNS values ----
	;
init_CNS:								; CNS at end of dive
	btfsc	FLAG_gauge_mode				; in gauge mode?
	bra		dive_customview_toggle		; YES - call next view
	btfsc	FLAG_apnoe_mode				; NO  - in apnoe mode?
	bra		dive_customview_toggle		;       YES - call next view
	call	TFT_CNS_mask				;       NO  - mask for CNS values
	call	TFT_CNS						;           - data for CNS values
	bra		dive_cv_toggle_exit			;           - done


	; ---- view 12: ppO2, END/EAD and CNS/gas density ----
	;
init_ppo2_ead_end_cns:					; 
	btfsc	FLAG_apnoe_mode				; in apnoe mode?
	bra		dive_customview_toggle		; YES - goto next view
	btfsc	FLAG_gauge_mode				; NO  - in gauge mode?
	bra		dive_customview_toggle		;       YES - goto next view
	call	TFT_ppo2_ead_end_cns_mask	;       NO  - mask for ppO2, END/EAD and CNS
	call	TFT_ppo2_ead_end_cns		;           - data for ppO2, END/EAD and CNS
	bra		dive_cv_toggle_exit			;           - done


	; ---- view 13: clock, battery and surface pressure
	;
init_clock_batt_surfpress:
	call	TFT_clock_batt_surfpress_mask	; mask for clock, battery and surface pressure
	call	TFT_clock_batt_surfpress		; data for clock, battery and surface pressure
	bra		dive_cv_toggle_exit				; done


	; ---- view 14: GF factors
	;
init_gf_factors:
	call	TFT_gf_factors_mask			; show GF factors
	bra		dive_cv_toggle_exit			; done


	; ---- view 15: cave waypoints ----
	;
init_cave_waypoints:
 IFDEF _cave_mode
	call	TFT_cave_waypoints			; show waypoint graphics
	bra		dive_cv_toggle_exit			; done
 ELSE
	bra		dive_customview_toggle		; not available without cave mode, goto next view
 ENDIF

;-----------------------------------------------------------------------------

	END
