;=============================================================================
;
;   File divemode.asm								REFACTORED VERSION V2.99e
;
;   Divemode
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;  2011-08-15 : [mH] moving from OSTC code

#include "hwos.inc"						; mandatory header
#include "shared_definitions.h"			; mailbox from/to p2_deco.c
#include "tft_outputs.inc"
#include "strings.inc"
#include "tft.inc"
#include "eeprom_rs232.inc"
#include "isr.inc"
#include "math.inc"
#include "wait.inc"
#include "customview.inc"
#include "start.inc"
#include "adc_lightsensor.inc"
#include "ghostwriter.inc"
#include "i2c.inc"
#include "calibrate.inc"
#include "convert.inc"

 IFDEF _rx_functions
#include "rx_ops.inc"
 ENDIF


	extern	TFT_dive_compass_heading
	extern	do_line_menu
	extern	do_main_divemenu
	extern	option_save_all
	extern	init_recording_params


	;---- Private local variables -------------------------------------------------

	CBLOCK	local1						; max size is 16 Byte !!!
		apnoe_timeout_counter			; timeout counter for apnoe mode
		sensor_setpoint					; sensor ppo2 in 0.01bar for deco routine
		check_gas_num					; used in search for best gas/dil: current gas/dil number (1-5)
		check_gas_depth					; used in search for best gas/dil: current gas/dil change depth
		check_gas_type					; used in search for best gas/dil: current gas/dil type
		check_gas_O2_ratio				; used in search for best gas/dil: current gas/dil O2 ratio
		best_gas_num					; used in search for best gas/dil: best    gas/dil number (1-5)  CAUTION: there is also a variable named best_gas_number !
		best_gas_depth					; used in search for best gas/dil: best    gas/dil change depth
		ppO2_min						; used in search for best gas/dil: minimum ppO2 required
		ppO2_max						; used in search for best gas/dil: maximum ppO2 allowed
	ENDC								; used: 10 byte, remaining: 6 byte

	CBLOCK	local2						; max size is 16 Byte !!!
		average_depth_hold:4			; used to calculate the resettable average depth
		average_depth_hold_total:4		; used to calculate the absolute   average depth
	ENDC								; used: 8 byte, remaining: 8 byte

dmode		CODE

;=============================================================================

	global	diveloop
diveloop:
	banksel	common
	call	speed_normal
	call	diveloop_boot				; boot tasks for all modes

	; startup tasks for all modes
	call	TFT_boot					; initialize TFT (includes clear screen)
	bsf		FLAG_TFT_divemode_mask		; request display of dive mode mask

	movff	customview_divemode,menupos3; reload last custom view
	bsf		redraw_custview_mask		; request redraw of last custom view

	btfsc	FLAG_apnoe_mode
	bsf		realdive					; set realdive flag in apnoe mode

	btfsc	FLAG_apnoe_mode				; done for apnoe or gauge mode
	bra		diveloop_loop_start
	btfsc	FLAG_gauge_mode				; done for apnoe or gauge mode
	bra		diveloop_loop_start

	; Deco modes
	bsf		FLAG_TFT_active_gas_divemode; request display of gas and setpoint
	bsf		FLAG_TFT_display_ndl_mask	; request display of "NDL"

	; +@5 init
	clrf	WREG						; WAIT marker: display "---"
	movff	WREG,char_I_sim_advance_time
	movff	WREG,int_O_alternate_ascenttime+0
	bsf		WREG,int_not_yet_computed
	bsf		WREG,int_invalid_flag
	movff	WREG,int_O_alternate_ascenttime+1

diveloop_loop_start:
	btfsc	FLAG_TFT_divemode_mask
	call	TFT_divemode_mask
	btfsc	FLAG_TFT_display_ndl_mask
	call	TFT_display_ndl_mask

diveloop_loop:							; the dive loop starts here
	btfss	quarter_second_update
	bra		diveloop_loop1

	; tasks any 1/4 second, any mode
	bcf		quarter_second_update		; clear flag

	btfsc	alternative_divelayout		; in alternative layout?
	bra		diveloop_loop1				; YES - no compass in alternative layout mode
	movlw	index_compass_dm			; NO  - index of compass view
	cpfseq	menupos3					;     - in compass view?
	bra		diveloop_loop1				;       NO  - done
	call	TFT_dive_compass_heading	;       YES - update compass heading value
	bsf		FLAG_TFT_temp_divemode		;           - redraw temperature (is slightly affected from compass heading arrow)

diveloop_loop1:
	btfss	onesecupdate				; next second begun?
	bra		diveloop_loop3				; NO

; tasks any new second...
	bcf		onesecupdate				; one seconds update, clear flag here in case it's set again in ISR before all tasks are done.

;	###-- USE FOR DEBUG ONLY - RESETS RX CIRCUITRY --###
;	bsf		LEDg
;	###----------------------------------------------###

	; compute current depth in meters
	SAFE_2BYTE_COPY rel_pressure,xA
	movlw	.100
	movwf	xB+0
	clrf	xB+1
	call	div16x16						; xC = xA / xB, xC+0 now holds depth in full meters
	movff	xC+0,curr_depth					; store result in curr_depth

	; compute ambient pressure / 10, will be needed later
	SAFE_2BYTE_COPY amb_pressure,xA
	movlw	.10
	movwf	xB+0
	clrf	xB+1
	call	div16x16						; xC = xA / xB = p_amb / 10
	movff	xC+0,amb_press_10+0				; store result for later use
	movff	xC+1,amb_press_10+1				; ...

	; display depth based on full seconds interval (nicer blinking)
	btfss	alternative_divelayout
	rcall	TFT_output4_normal
	btfsc	alternative_divelayout
	rcall	TFT_output4_alternative

	btfsc	FLAG_apnoe_mode				; in Apnoe mode?
	bra		diveloop_loop1_nonedeco		; YES - do Apnoe mode every second tasks

; tasks any new second - only for deco modes
diveloop_loop1_deco:
	bsf		FLAG_TFT_divemins			; display (new) dive time!
	btfsc	show_safety_stop			; show the safety stop?
	bsf		FLAG_TFT_show_safety_stop	; YES - show/delete if done

	btfss	alternative_divelayout
	rcall	TFT_output1_normal
	btfsc	alternative_divelayout
	rcall	TFT_output1_alternative

	call	divemode_check_for_warnings	; check for warnings

 IFDEF _rx_functions
	btfss	FLAG_tr_enabled				; TR functions enabled?
	bra		diveloop_loop1_deco1		; NO  - skip pressure readings part
	call	get_pressure_readings		; YES - get  pressure readings
	call	configure_sac_calculation	;     - set up SAC calculation
diveloop_loop1_deco1:
 ENDIF

	call	calc_deco_divemode			; calculate decompression and set resulting display flags

	btfss	alternative_divelayout
	rcall	TFT_output2_normal
	btfsc	alternative_divelayout
	rcall	TFT_output2_alternative
	bra		diveloop_loop2				; continue with common tasks

; tasks any new second - only for apnoe mode
diveloop_loop1_nonedeco:
	rcall	divemode_apnoe_tasks		; 1 sec. apnoe tasks
	call	customview_second			; do every-second tasks for the custom view area
	;bra	diveloop_loop2				; common tasks

; continue tasks any new second, any mode
diveloop_loop2:
	btfsc	redraw_custview_mask		; shall we redraw the custom view mask?
	call	customview_mask				; YES - redraw custom view mask

	rcall	timeout_divemode			; ** menu timeout? ** - this routine sets the required flags
	rcall	set_dive_modes				; tests if depth > threshold
	rcall	set_min_temp				; store min. temp if required (future hardware will need this to be checked 1/second...)

	btfsc	oneminupdate				; one minute tasks
	rcall	update_divemode60			; update clock, etc.

	btfss	FLAG_oc_mode				; are we in OC mode?
	bsf		FLAG_TFT_active_gas_divemode; NO - have the gas and setpoint redrawn on every second to update setpoint display, animate the blinking, etc.

	btfss	alternative_divelayout
	rcall	TFT_output3_normal
	btfsc	alternative_divelayout
	rcall	TFT_output3_alternative

;	###-- USE FOR DEBUG ONLY - RESETS RX CIRCUITRY --###
;	bcf		LEDg
;	###----------------------------------------------###

; tasks any round, any mode
diveloop_loop3:
	call	test_switches_divemode		; check switches in dive mode

	global	diveloop_loop4
diveloop_loop4:							; menu-exit returns here...
	btfsc	toggle_customview			; next view?
	call	customview_toggle			; YES - show next custom view (and delete this flag)

	btfsc	divemode_gaschange			; gas switch flag set?
	call	gas_switched_common			; YES

	btfsc	toggle_gf					; toggle GF/aGF?
	rcall	divemodemode_togglegf		; YES

 IFDEF _cave_mode
	btfsc	toggle_turn_dive			; toggle dive turned?
	rcall	divemodemode_toggleturn		; YES
 ENDIF

	btfsc	FLAG_set_marker				; shall set a marker?
	call	set_logbook_marker			; YES

	btfsc	store_sample				; shall store new sample?
	call	store_dive_data				; YES - store profile data

	btfss	divemode					; dive finished?
	goto	ghostwriter_end_dive		; YES - dive finished!

	btfsc	pressure_refresh			; new pressure available?
	rcall	set_max_depth				; YES - update max. depth if required
	btfsc	pressure_refresh			; new pressure available?
	bsf		FLAG_TFT_depth				; YES - update depth
	bcf		pressure_refresh			; clear flag

	btfsc	temp_changed				; temperature changed?
	bsf		FLAG_TFT_temp_divemode		; YES - display temperature

 IFDEF _screendump
	btfsc	enable_screen_dumps			; screen dump function enabled?
	call	TFT_dump_screen_check		; YES - check if requested and do it
 ENDIF

	bra		diveloop_loop				; loop the dive mode

;--------------------------------------------------------------------------------------------------------	

TFT_output1_normal:							; beginning of any new second - only for deco modes
	btfsc	FLAG_TFT_divemode_mask
	call	TFT_divemode_mask
	btfsc	FLAG_TFT_divemins
	call	TFT_divemins					; display (new) dive time!
	call	customview_second				; do every-second tasks for the custom view area (in sync with the dive time) mH
	btfsc	FLAG_TFT_show_safety_stop
	call	TFT_show_safety_stop			; show safety stop
	btfsc	FLAG_TFT_clear_safety_stop
	call	TFT_clear_safety_stop			; clear safety stop
	return

TFT_output1_alternative:					; beginning of any new second - only for deco modes
	btfsc	FLAG_TFT_divemode_mask_alt
	call	TFT_divemode_mask_alternative	; alternative mask
	btfsc	FLAG_TFT_divemins
	call	TFT_divemins_alternative		; display (new) divetime!
	call	customview_alternative_second	; do every-second tasks for the custom view area (in sync with the dive time) mH
	btfsc	FLAG_TFT_big_deco_alt
	call	TFT_big_deco_alt				; big deco, also manages alternative safety stop thus moved to first wave of outputs [rl]
	return

TFT_output2_normal:							; any new second - only for deco modes
	btfsc	FLAG_TFT_display_ndl_mask
	call	TFT_display_ndl_mask
	btfsc	FLAG_TFT_display_ndl
	call	TFT_display_ndl
	btfsc	FLAG_TFT_display_deko_mask
	call	TFT_display_deko_mask
	btfsc	FLAG_TFT_display_deko
	call	TFT_display_deko
	btfsc	FLAG_TFT_display_tts
	call	TFT_display_tts
	return

TFT_output2_alternative:					; any new second - only for deco modes
	return

TFT_output3_normal:							; tasks any new second, any mode, after deco calculations
	btfsc	FLAG_TFT_max_depth
	call	TFT_max_depth					; use normal max. depth
	btfsc	FLAG_TFT_divemode_warning
	call	TFT_divemode_warning
	btfsc	FLAG_TFT_divemode_warning_clear
	call	TFT_divemode_warning_clear
	btfsc	FLAG_TFT_dive_warning_text_clear
	call	TFT_clear_warning_text			; clear complete warnings area
	btfsc	FLAG_TFT_dive_warning_text_clr2
	call	TFT_clear_warning_text_2nd_row	; clear 2nd row of warnings
	return

TFT_output3_alternative:					; tasks any new second
	btfsc	FLAG_TFT_max_depth
	call	TFT_max_depth_alternative		; big max. depth
	btfsc	FLAG_TFT_dive_warning_text_clear
	call	TFT_clear_warning_text			; clear complete warnings area (in alt mode only 2nd row...)
	return

TFT_output4_normal:							; tasks any round, any mode, before deco calculations (stable timebase)
	btfsc	FLAG_TFT_depth
	call	TFT_depth						; display depth
	btfsc	FLAG_TFT_active_gas_divemode
	call	TFT_active_gas_divemode			; display gas/setpoint
	btfsc	FLAG_TFT_temp_divemode
	call	TFT_temp_divemode				; update temperature
	return

TFT_output4_alternative:					; tasks any round, any mode
	btfsc	FLAG_TFT_depth
	call	TFT_depth						; display new depth
	return


;--------------------------------------------------------------------------------------------------------

divemode_apnoe_tasks:					; 1 sec. apnoe tasks
	call	TFT_display_apnoe_descent	; show descent timer
	call	TFT_max_depth				; use normal max. depth

	btfsc	divemode2					; time running?
	bra		divemode_apnoe_tasks2		; YES - new descent, reset data if flag is set

	rcall	apnoe_calc_maxdepth
	call	TFT_display_apnoe_surface
	call	TFT_display_apnoe_last_max	; show last max. depth
	incf	apnoe_surface_secs,F
	movlw	d'60'
	cpfseq	apnoe_surface_secs
	bra		divemode_apnoe_tasks1
	clrf	apnoe_surface_secs
	incf	apnoe_surface_mins,F

divemode_apnoe_tasks1:
	bcf		FLAG_active_descent			; clear flag
	btfsc	divemode2					; time running?
	return								; YES - return
	bsf		FLAG_active_descent			; set flag
	return

divemode_apnoe_tasks2:
	btfss	FLAG_active_descent			; are we descending?
	return								; NO - we are at the surface
	rcall	apnoe_calc_maxdepth			; YES
	call	TFT_apnoe_clear_surface		; clear surface timer
	clrf	apnoe_timeout_counter		; delete timeout
	clrf	apnoe_surface_secs
	clrf	apnoe_surface_mins
	clrf	apnoe_secs
	clrf	apnoe_mins					; reset descent time
	movlw	.0
	movff	WREG,max_pressure+0
	movff	WREG,max_pressure+1			; reset max. depth
	bcf		FLAG_active_descent			; clear flag
	return

	global	apnoe_calc_maxdepth
apnoe_calc_maxdepth:
	movff	apnoe_max_pressure+0,sub_a+0
	movff	apnoe_max_pressure+1,sub_a+1
	movff	max_pressure+0,sub_b+0
	movff	max_pressure+1,sub_b+1
	call	subU16						; sub_c = sub_a - sub_b
										; apnoe_max_pressure <  max_pressure       -> neg_flag=1
										; max_pressure       <= apnoe_max_pressure -> neg_flag=0
	btfss	neg_flag
	return
										;apnoe_max_pressure<max_pressure
	movff	max_pressure+0,apnoe_max_pressure+0
	movff	max_pressure+1,apnoe_max_pressure+1
	return

	; --------------------------------------------------------------------------------------

calc_deco_divemode:
	btfss	FLAG_gauge_mode				; in gauge mode?
	rcall	calc_deko_engine			; NO - do deco calculations

	; Increment the time accumulators used for calculating the average depths.
	; This done here and not in the ISR to guarantee synchronism between time
	; and depth accumulator incrementing.
	infsnz	average_divesecs+0,F
	incf	average_divesecs+1,F
	infsnz	average_divesecs_total+0,F
	incf	average_divesecs_total+1,F

	btg		onesectoggle				; toggle the one-second toggle bit
	btfss	onesectoggle				; toggle bit set?
	bra		calc_deko_divemode2			; NO
	;bra	calc_deko_divemode1			; YES

calc_deko_divemode1:					; every-2-seconds tasks, 1st phase
;	call	TFT_debug_output			; optional debug output
	btfsc	FLAG_gauge_mode				; in gauge mode?
	return								; YES - done
	goto	check_gas_best			; NO  - checks if a better gas should be selected (by user) and return

calc_deko_divemode2:					; every-2-seconds tasks, 2nd phase
	call	calc_average_depth			; calculate average depth
	call	calc_velocity				; calculate vertical velocity and display if > threshold (every two seconds)
	goto	set_reset_safety_stop		; set/reset flags for safety stop and return


calc_deko_engine:
	btfsc	FLAG_ccr_mode				; in CCR mode?
	call	check_dive_autosp			; YES - check for Auto-SP

	btfsc	FLAG_ccr_mode				; in CCR mode?
	rcall	calc_deko_divemode_sensor	; YES - do sensor data acquisition if applicable by OSTC model

	btfsc	FLAG_pscr_mode				; in pSCR mode?
	rcall	calc_deko_divemode_sensor	; YES - do sensor data acquisition if applicable by OSTC model


	; check deco engine state and switch between normal and alternative plan calculations
	;
	; Remark: Any reconfigurations done here do only affect the ascent & deco calculation settings,
	;         not the settings for the calculations done on the real tissues. The later ones are only
	;         altered in case of a gas change, or in case of a real bailout or switchback to setpoint
	;         or sensor, respectively.
	;         In case of a gas change or real bailout/switchback, the settings for the deco calculations
	;         are also changed to match the settings for the real tissues. This is done on signal through
	;         'divemode_gaschange' and will also leave the deco engine status in state as if having done
	;         the alternative plan last.

	; get working copies of char_O_main_status and char_O_deco_status
	movff	char_O_main_status,hi		; get char_O_main_status into hi
	movff	char_O_deco_status,lo		; get char_O_deco_status into lo

	; check state of deco calculations
	btfsc	hi,DECO_COMPLETED_NORM		; finished calculations for normal plan?
	bra		calc_deko_engine_alt		; YES - do an alternative plan next (or a normal one with more features enabled)
	btfsc	hi,DECO_COMPLETED_ALT		; finished calculations for alternative plan?
	bra		calc_deko_engine_norm		; YES - do a normal plan next
	bra		calc_deko_engine_cont		; NO to both - continue calculations / do first invocation in INIT mode

calc_deko_engine_norm:
	; Last cycle did an alternative plan, or the deco engine has been restarted because of a gas change etc.
	; --> Reconfigure to normal plan for next computation cycle.
	bcf		lo,DECO_PLAN_FLAG			; clear flag for alternative plan to do a normal plan next
	bcf		lo,DECO_ASCENT_FLAG			; clear flag for delayed ascent calculation
	bcf		lo,DECO_VOLUME_FLAG			; clear flag for gas needs calculation
	bcf		lo,DECO_BAILOUT_FLAG		; clear flag for bailout mode
 IFDEF _cave_mode
	bcf		hi,DECO_CAVE_MODE			; clear flag for cave mode
 ENDIF

	btfsc	FLAG_ccr_mode				; in CCR mode?
	bra		calc_deko_engine_norm_loop	; YES - reload diluents and reconfigure CCR mode if not in bailout
	btfsc	FLAG_pscr_mode				; in pSCR mode?
	bra		calc_deko_engine_norm_loop	; YES - reload diluents and reconfigure pSCR mode if not in bailout
	;bra	calc_deko_engine_norm_OC	; neither in CCR nor pSCR mode, so reload OC gases and reconfigure OC mode
										; (first cycle omits gas needs calculation for faster first deco results)
calc_deko_engine_norm_OC:
	movff	active_gas,WREG				; get current OC gas
	call	deco_setup_oc_gases_pre		; set up deco calculations in OC mode with OC gases
	bra		calc_deko_engine_start		; start deco engine

calc_deko_engine_norm_loop:				; switch to loop calculation if not in a real bailout situation
	btfsc	FLAG_bailout_mode			; check if a real bailout situation is present
	bra		calc_deko_engine_norm_OC	; YES - revert to OC mode
										; NO  - switch to loop calculation:
	movff	active_dil,WREG				;     - get current diluent
	call	deco_setup_cc_diluents_pre	;     - set up deco calculations in CCR/pSCR mode with diluents
	bra		calc_deko_engine_start		;     - start deco engine

calc_deko_engine_alt:
	; A normal plan was computed in the last cycle. For the next calculation cycle the mode may be switched
	; to alternative plan, or stay in normal plan but with certain features enabled...
	bcf		lo,DECO_ASCENT_FLAG			; clear flag for delayed ascent calculation
	bcf		lo,DECO_VOLUME_FLAG			; clear flag for gas needs calculation
	bcf		lo,DECO_BAILOUT_FLAG		; clear flag for bailout mode
 IFDEF _cave_mode
	bcf		hi,DECO_CAVE_MODE			; clear flag for cave mode
 ENDIF

	btfsc	FLAG_bailout_mode			; check if a real bailout situation is present
	bra		calc_deko_engine_alt_1		; YES - stay in normal plan mode and preclude delayed ascent calculation
	TSTOSS	char_I_extra_time			; NO  - check if a delayed ascent is enabled
	bra		calc_deko_engine_alt_1		;       NO  - stay in normal plan mode and preclude delayed ascent calculation
	bsf		lo,DECO_PLAN_FLAG			;       YES - set flag for alternative plan
	bsf		lo,DECO_ASCENT_FLAG			;           - set flag for delayed ascent

calc_deko_engine_alt_1:
	TSTOSS	opt_calc_asc_gasvolume		; check if gas volume calculation is enabled
	bra		calc_deko_engine_start		; NO  - no volume calculation, no simulated bailout plan in this case
	bsf		lo,DECO_VOLUME_FLAG			; YES - set gas needs calculation flag

	btfsc	FLAG_bailout_mode			; check if a real bailout situation is present
	bra		calc_deko_engine_start		; YES - normal plan already does bailout (OC) calculation "for real"

 IFDEF _cave_mode
	bsf		hi,DECO_CAVE_MODE			; activate cave mode by default
	btfss	FLAG_cave_mode				; cave mode switched on?
	bcf		hi,DECO_CAVE_MODE			; NO  - deactivate p2deco cave mode again
	btfsc	FLAG_dive_turned			; dive turned?
	bcf		hi,DECO_CAVE_MODE			; YES - deactivate p2deco cave mode again
	btfsc	FLAG_cave_mode_shutdown		; cave mode function shut down?
	bcf		hi,DECO_CAVE_MODE			; YES - deactivate p2deco cave mode again
 ENDIF

	btfss	lo,DECO_MODE_LOOP_FLAG		; NO  - has a loop mode calculation been done during the normal plan?
	bra		calc_deko_engine_start		;       NO  - when not in loop mode, no simulated bailout to be done
	decf	best_gas_number,W			;       YES - get best gas number -1 into WREG. If not available, WREG will be 255 now. If not computed yet, WREG will be 254 now.
	btfsc	WREG,7						;           - WREG < 128 (a bailout gas is available)?
	bra		calc_deko_engine_alt_2		;             NO  - no simulated bailout possible because no bailout gas available to switch to
	bsf		lo,DECO_PLAN_FLAG			;             YES - set flag for alternative plan
	bsf		lo,DECO_BAILOUT_FLAG		;                 - set bailout mode flag (enables gas changes before 1st stop)
	movf	best_gas_number,W			;                 - put number of best gas into WREG
	call	deco_setup_oc_gases_pre		;                 - set up deco calculations in OC mode with OC gases
	bra		calc_deko_engine_start		;                 - start in alternative plan mode

calc_deko_engine_alt_2:
	bcf		lo,DECO_PLAN_FLAG			; clear flag for alternative plan
	bcf		lo,DECO_ASCENT_FLAG			; clear flag for delayed ascent calculation
	bcf		lo,DECO_VOLUME_FLAG			; clear flag for gas needs calculation
 IFDEF _cave_mode
	bcf		hi,DECO_CAVE_MODE			; clear flag for cave mode
 ENDIF
	call	inval_alternative_plan_data	; invalidate all alternative (bailout) plan data because they are not applicable any more

calc_deko_engine_start:
 IFDEF _cave_mode
	movff	hi,char_O_main_status		; write-back char_O_main_status to deco engine interface
 ENDIF
	movff	lo,char_O_deco_status		; write-back char_O_deco_status to deco engine interface

calc_deko_engine_cont:
	SAFE_2BYTE_COPY amb_pressure,int_I_pres_respiration ; transfer ambient pressure to deco engine
	clrf	TMR5L						; restart timer used to preempt stops calculation
	clrf	TMR5H						;
	call	deco_calc_hauptroutine		; invoke the deco engine (p2_deco.c)
	banksel	common

	; the displayed gas may need a different color-coding
	bsf		FLAG_TFT_active_gas_divemode; redraw gas/setpoint/diluent

	; check if display shall be updated due to deco engine restart
	btfsc	FLAG_TFT_display_ndl_or_deko; shall update immediately?
	bra		calc_deko_engine_update		; YES

	; check if new calculation results for normal plan mode are available
	movff	char_O_main_status,WREG		; get deco status of deco engine
	btfss	WREG,DECO_COMPLETED_NORM	; new calculation results for normal plan available?
	return								; NO  - done

calc_deko_engine_update:
	bcf		FLAG_TFT_display_ndl_or_deko; YES - reset flag for immediate update
	movff	char_O_deco_info,WREG		;     - get deco info vector
	btfsc	WREG,deco_ceiling			;     - ceiling depth > 0 ?
	bra		calc_deko_engine_update_deco;       YES - in deco
	;bra	calc_deko_engine_update_NDL	;       NO  - within NDL

calc_deko_engine_update_NDL:			; within NDL
	btfsc	decostop_active				; been in deco mode before?
	bsf		FLAG_TFT_display_ndl_mask	; YES - clear deco data, display NDL time
	bsf		FLAG_TFT_display_ndl		; display NDL time
	bcf		decostop_active				; clear flag for been in deco mode before
	return

calc_deko_engine_update_deco:			; in deco
	btfss	decostop_active				; already been in deco mode before?
	bsf		FLAG_TFT_display_deko_mask	; NO - clear NDL time, display deco data
	bsf		FLAG_TFT_display_deko		; display deco data
	bsf		FLAG_TFT_display_tts		; display TTS
	bsf		decostop_active				; set flag for being in deco mode
	return

	; --------------------------------------------------------------------------------------

	global	calc_deko_divemode_sensor
calc_deko_divemode_sensor:
	; sensor acquisition code
	btfss	s8_digital						 ; check if we have a digital interface to the sensors
	bra		calc_deko_divemode_sensor_analog ; NO  - check if we have an analog interface
	btfss	new_s8_data_available			 ; YES - check if a new data frame was received
	bra		calc_deko_divemode_sensor_common ; NO  - use old values
	call	compute_mvolts_for_all_sensors	 ; YES - compute mV values from digital data
	bra		calc_deko_divemode_sensor_common
calc_deko_divemode_sensor_analog:
	btfss	analog_o2_input					; do we have an analog input?
	bra		calc_deko_divemode_sensor_opt	; NO  - check if we have an optical interface
	call	get_analog_inputs				; YES - get the analog voltages and continue with the common part
	bra		calc_deko_divemode_sensor_common
calc_deko_divemode_sensor_opt:
	btfss	optical_input					; do we have an optical input?
	return									; NO  - return (we have no sensors at all: not analog, not S8 and not optical)
	btfss	sensor1_active					; YES - o2_ppo2_sensor1, o2_ppo2_sensor2 and o2_ppo2_sensor3 are already filled in ISR
	bcf		use_O2_sensor1					;       check HUD status data and eventually clear use_O2_sensorX
	btfss	sensor2_active
	bcf		use_O2_sensor2
	btfss	sensor3_active
	bcf		use_O2_sensor3
	bra		calc_deko_divemode_sensor_A		; continue with calculating sensor average

calc_deko_divemode_sensor_common:
	; Check each sensor if it is calibrated and if its mV value is within min_mv and max_mv limits.
	; If     ok: compute o2_ppo2_sensorX = o2_mv_sensorX * opt_x_sX / 1000
	; If not ok: reset   o2_ppo2_sensorX, reset use_O2_sensorX and show the customview 1 in case the sensor was ok before

	; check sensor 1
	btfss	sensor1_calibrated_ok		; check if sensor is usable at all
	bra		check_sensor_1_fail			; NO  - handle it as failed
	; check min threshold
	movff	o2_mv_sensor1+0,sub_a+0		; load sensor mV value
	movff	o2_mv_sensor1+1,sub_a+1
	rcall	check_min_threshold
	btfsc	neg_flag					; check if result is negative, i.e. sensor_mv < min_mv
	bra		check_sensor_1_fail			; YES - declare sensor as failed
	; check max_threshold
	rcall	check_max_threshold
	btfss	neg_flag					; check if result is negative, i.e. sensor_mv < max_mv
	bra		check_sensor_1_fail			; NO  - declare sensor as failed
	; check HUD data, if available
	btfss	hud_connection_ok			; check if there is a HUD connected
	bra		check_sensor_1_ok			; NO  - all checks done then and positive
	btfss	sensor1_active				; YES - HUD status ok?
	bra		check_sensor_1_fail			;       NO - HUD reports a fail
check_sensor_1_ok:
	; o2_ppo2_sensor1 = o2_mv_sensor1:2 * opt_x_s1:2 / 1000
	movff	o2_mv_sensor1+0,xA+0
	movff	o2_mv_sensor1+1,xA+1
	movff	opt_x_s1+0,xB+0
	movff	opt_x_s1+1,xB+1
	rcall	compute_ppo2_helper
	movff	xC+0,o2_ppo2_sensor1		; result in 0.01 bar
	bra		check_sensor_2				; continue with next sensor
check_sensor_1_fail:
	clrf	WREG
	movff	WREG,o2_ppo2_sensor1		; set ppO2 reading to zero
	btfss	use_O2_sensor1				; check if sensor was in use before
	bra		check_sensor_1_fail_1		; NO  - no new news then
	call	check_sensor_custview_helper; YES - show customview 1 (sensor values) on further conditions met
check_sensor_1_fail_1:
	bcf		use_O2_sensor1				; revoke sensor from usage

check_sensor_2:							; check min_mv of sensor 2
	btfss	sensor2_calibrated_ok		; check if sensor is usable at all
	bra		check_sensor_2_fail			; NO  - handle it as failed
	; check min threshold
	movff	o2_mv_sensor2+0,sub_a+0		; load sensor mV value
	movff	o2_mv_sensor2+1,sub_a+1
	rcall	check_min_threshold
	btfsc	neg_flag					; check if result is negative, i.e. sensor_mv < min_mv
	bra		check_sensor_2_fail			; YES - declare sensor as failed
	; check max_threshold
	rcall	check_max_threshold
	btfss	neg_flag					; check if result is nagative, i.e. sensor_mv < max_mv
	bra		check_sensor_2_fail			; NO  - declare sensor as failed
	; check HUD data, if available
	btfss	hud_connection_ok			; check if there is a HUD connected
	bra		check_sensor_2_ok			; NO  - all checks done then and positive
	btfss	sensor2_active				; YES - HUD status ok?
	bra		check_sensor_2_fail			;       NO - HUD reports a fail
check_sensor_2_ok:
	; o2_ppo2_sensor2 = o2_mv_sensor2:2 * opt_x_s2:2 / 1000
	movff	o2_mv_sensor2+0,xA+0
	movff	o2_mv_sensor2+1,xA+1
	movff	opt_x_s2+0,xB+0
	movff	opt_x_s2+1,xB+1
	rcall	compute_ppo2_helper
	movff	xC+0,o2_ppo2_sensor2		; result in 0.01 bar
	bra		check_sensor_3				; continue with next sensor
check_sensor_2_fail:
	clrf	WREG
	movff	WREG,o2_ppo2_sensor2		; set ppO2 reading to zero
	btfss	use_O2_sensor2				; check if sensor was in use before
	bra		check_sensor_2_fail_1		; NO  - no new news then
	call	check_sensor_custview_helper; YES - show customview 1 (sensor values) on further conditions met
check_sensor_2_fail_1:
	bcf		use_O2_sensor2				; revoke sensor from usage

check_sensor_3:							; check min_mv of sensor 2
	btfss	sensor3_calibrated_ok		; check if sensor is usable at all
	bra		check_sensor_3_fail			; NO  - handle it as failed
	; check min threshold
	movff	o2_mv_sensor3+0,sub_a+0		; load sensor mV value
	movff	o2_mv_sensor3+1,sub_a+1
	rcall	check_min_threshold
	btfsc	neg_flag					; check if result is negative, i.e. sensor_mv < min_mv
	bra		check_sensor_3_fail			; YES - declare sensor as failed
	; check max threshold
	rcall	check_max_threshold
	btfss	neg_flag					; check if result is negative, i.e. sensor_mv < max_mv
	bra		check_sensor_3_fail			; NO  - declare sensor as failed
	; check HUD data, if available
	btfss	hud_connection_ok			; check if there is a HUD connected
	bra		check_sensor_3_ok			; NO  - all checks done then and positive
	btfss	sensor3_active				; YES - HUD status ok?
	bra		check_sensor_3_fail			;       NO - HUD reports a fail
check_sensor_3_ok:
	; o2_ppo2_sensor3 = o2_mv_sensor3:2 * opt_x_s1:2 / 1000
	movff	o2_mv_sensor3+0,xA+0
	movff	o2_mv_sensor3+1,xA+1
	movff	opt_x_s3+0,xB+0
	movff	opt_x_s3+1,xB+1
	rcall	compute_ppo2_helper
	movff	xC+0,o2_ppo2_sensor3		; result in 0.01 bar
	bra		calc_deko_divemode_sensor_A	; continue with calculating sensor average
check_sensor_3_fail:
	clrf	WREG
	movff	WREG,o2_ppo2_sensor3		; set ppO2 reading to zero
	btfss	use_O2_sensor3				; check if sensor was in use before
	bra		check_sensor_3_fail_1		; NO  - no new news then
	call	check_sensor_custview_helper; YES - show custom view 1 (sensor values) on further conditions met
check_sensor_3_fail_1:
	bcf		use_O2_sensor3				; revoke sensor from usage

calc_deko_divemode_sensor_A:			; calculate sensor average
	; exit here if not in dive mode
	btfss	divemode
	return

	; compute sensor_setpoint = average of all o2_ppo2_sensorX of those sensors that have use_O2_sensorX == true
	; sum up sensor values (in xA:2) and active sensors in (xB:2)
	clrf	xB+0
	clrf	xB+1
	clrf	xA+0
	clrf	xA+1
divemode_setup_sensor_1_value:
	btfss	use_O2_sensor1					; sensor1 active?
	bra		divemode_setup_sensor_2_value	; NO
	movf	o2_ppo2_sensor1,W
	addwf	xA+0,F
	movlw	.0
	addwfc	xA+1,F							; add into xA:2
	incf	xB+0,F							; add a sensor
divemode_setup_sensor_2_value:
	btfss	use_O2_sensor2					; sensor2 active?
	bra		divemode_setup_sensor_3_value	; NO
	movf	o2_ppo2_sensor2,W
	addwf	xA+0,F
	movlw	.0
	addwfc	xA+1,F							; add into xA:2
	incf	xB+0,F							; add a sensor
divemode_setup_sensor_3_value:
	btfss	use_O2_sensor3					; sensor3 active?
	bra		divemode_setup_sensor_mean		; NO
	movf	o2_ppo2_sensor3,W
	addwf	xA+0,F
	movlw	.0
	addwfc	xA+1,F							; add into xA:2
	incf	xB+0,F							; add a sensor

	; divide sum of sensor values by number of active sensors found
divemode_setup_sensor_mean:
	clrf	xC+0							; set zero as default result
	tstfsz	xB+0							; pending div/0 ?
	call	div16x16						; NO - execute xC = xA / xB = summed ppO2 / number of sensors
	movff	xC+0,sensor_setpoint			; copy result (or its default)

	; set default value for pSCR mode: 0 => let p2_deco.c compute the ppO2 based on current dil gas and depth
	; will be overwritten later in case we are in sensor mode and have at least one usable sensor
	clrf	WREG								; preload a zero
	btfsc	FLAG_pscr_mode						; check if we are in pSCR mode
	movff	WREG,char_I_const_ppO2				; YES - write 0 to char_I_const_ppo2,
												;       it will be overwritten if we have a usable sensor reading
	btfsc	FLAG_bailout_mode					; check if we are in bailout
	bra		calc_deko_divemode_sensor_V			; YES - no sensor data transfer to char_I_const_ppO2 in this case
	movff	opt_ccr_mode,WREG					; NO  - get mode (0: Fixed SP, 1: Sensor, 2: Auto SP)
	sublw	.1									;     - in sensor mode?
	bnz		calc_deko_divemode_sensor_V			;       NO  - not in sensor mode - no transfer of sensor data to char_I_const_ppO2
	tstfsz	xB+0								;       YES - check if we have found at least one usable sensor
	bra		divemode_setup_sensor_mean1			;             YES - we have at least one usable sensor
	bsf		setpoint_fallback					;             NO  - we have NO usable sensors -> initiate fallback
	btfss	FLAG_ccr_mode						;                 - check if we are in CCR mode
	bra		calc_deko_divemode_sensor_V			;                   NO  - continue with voting logic flags
	movff	char_I_setpoint_cbar+0,char_I_const_ppO2;               YES - select fixed setpoint no. 1 for fallback
	bra		calc_deko_divemode_sensor_V			;                       - continue with voting logic flags
	; we have at least one usable sensor with a ppO2 value > 0
divemode_setup_sensor_mean1:
	bcf		setpoint_fallback					; clear fallback condition
	movff	sensor_setpoint,char_I_const_ppO2	; transfer average sensor value to p2_deco.c code
	; vote sensors
calc_deko_divemode_sensor_V:
	bsf		voting_logic_sensor1
	movff	o2_ppo2_sensor1,lo
	rcall	check_sensor_voting_helper
	tstfsz	WREG						; sensor within range (WREG = 0)?
	bcf		voting_logic_sensor1		; NO - vote out this sensor

	bsf		voting_logic_sensor2
	movff	o2_ppo2_sensor2,lo
	rcall	check_sensor_voting_helper
	tstfsz	WREG						; sensor within range (WREG = 0)?
	bcf		voting_logic_sensor2		; NO - vote out this sensor

	bsf		voting_logic_sensor3
	movff	o2_ppo2_sensor3,lo
	rcall	check_sensor_voting_helper
	tstfsz	WREG						; sensor within range (WREG = 0)?
	bcf		voting_logic_sensor3		; NO - vote out this sensor

	; check if a warning shall be issued on sensor disagreement
	btfsc	FLAG_ccr_mode				; check if we are in CCR mode
	bra		check_warn_sensor_0			; YES - continue with further checks
	btfsc	FLAG_pscr_mode				; check if we are in pSCR mode
	bra		check_warn_sensor_0			; YES - continue with further checks
	bra		check_warn_sensor_done		; not in CCR and not in pSCR, so no warning
check_warn_sensor_0:					; we are in CCR or pSCR mode
	btfsc	FLAG_bailout_mode			; check if we are in bailout
	bra		check_warn_sensor_done		; YES - no warning in this case
	movff	opt_ccr_mode,WREG			; get mode (0: Fixed SP, 1: Sensor, 2: Auto SP)
	sublw	.1							; in sensor mode?
	bnz		check_warn_sensor_done		; NO - not in sensor mode - no warning in this case
	; check sensor 1
check_warn_sensor_1:
	btfss	sensor1_calibrated_ok		; check if sensor has a valid calibration
	bra		check_warn_sensor_2			; NO  - sensor can not cause a warning then
	btfss	use_O2_sensor1				; YES - check if sensor is in use
	bra		check_warn_sensor_2			;       NO  - sensor can not cause a warning then
	btfsc	voting_logic_sensor1		;       YES - check if sensor value is within agreement range
	bra		check_warn_sensor_2			;             YES - continue with next sensor
	bcf		sensors_agree				;             NO  - issue a warning
	return
	; check sensor 2
check_warn_sensor_2:
	btfss	sensor2_calibrated_ok		; check if sensor has a valid calibration
	bra		check_warn_sensor_3			; NO  - sensor can not cause a warning then
	btfss	use_O2_sensor2				; YES - check if sensor is in use
	bra		check_warn_sensor_3			;       NO  - sensor can not cause a warning then
	btfsc	voting_logic_sensor2		;       YES - check if sensor value is within agreement range
	bra		check_warn_sensor_3			;             YES - continue with next sensor
	bcf		sensors_agree				;             NO  - issue a warning
	return
	; check sensor 3
check_warn_sensor_3:
	btfss	sensor3_calibrated_ok		; check if sensor has a valid calibration
	bra		check_warn_sensor_agree		; NO  - sensor can not cause a warning then
	btfss	use_O2_sensor3				; YES - check if sensor is in use
	bra		check_warn_sensor_agree		;       NO  - sensor can not cause a warning then
	btfsc	voting_logic_sensor3		;       YES - check if sensor value is within agreement range
	bra		check_warn_sensor_agree		;             YES - continue with next sensor
	bcf		sensors_agree				;             NO  - issue a warning
	return
	; no need for a warning
check_warn_sensor_done:
check_warn_sensor_agree:
	bsf		sensors_agree
	return


check_min_threshold:
	movlw	LOW  min_mv					; load minimum mV value
	movwf	sub_b+0
	movlw	HIGH min_mv
	movwf	sub_b+1
	goto	sub16						; sub_c = sensor_mv - min_mv (and return)

check_max_threshold:
	movlw	LOW  max_mv
	movwf	sub_b+0
	movlw	HIGH max_mv
	movwf	sub_b+1
	goto	sub16						; sub_c = sensor_mv - max_mv (and return)

compute_ppo2_helper:
	call	mult16x16					; xA:2*xB:2=xC:4
	movlw	LOW  .1000
	movwf	xB+0
	movlw	HIGH .1000
	movwf	xB+1
	call	div32x16					; xC:4 / xB:2 = xC+3:xC+2 with xC+1:xC+0 as remainder
	movlw	d'1'
	addwf	xC+0,W						; we are just interested in the carry flag
	movlw	d'0'
	addwfc	xC+1,W						; we are still just interested in the carry flag
	tstfsz	WREG						; ppO2 is higher than 2.55bar?
	setf	xC+0						; YES
	return

check_sensor_custview_helper:
	btfss	divemode					; check if we are in dive mode
	return								; NO  - not in dive mode, return
	movff	opt_ccr_mode,WREG			; YES - =0: Fixed SP, =1: Sensor, =2: Auto SP
	decfsz	WREG,W						;     - opt_ccr_mode = 1 (sensors)?
	return								;       NO  - not using the sensors in the moment
	btfsc	alternative_divelayout		;       YES - in alternative layout?
	call	switch_layout_to_normal		;             YES - switch to normal layout
	movlw	index_ppo2_sensors-1		;             custom view number one below ppO2 sensors
	movwf	menupos3					;             set custom view number
	bsf		toggle_customview			;             initiate toggle to desired custom view -> ppO2 sensors
	return

check_sensor_voting_helper:
	movf	lo,W
	cpfsgt	sensor_setpoint
	bra		check_sensor_voting_helper2		; lo < sensor_setpoint
	; lo > sensor_setpoint
	movf	lo,W
	subwf	sensor_setpoint,W
	movwf	lo
check_sensor_voting_helper1:
	movlw	sensor_voting_logic_threshold	; threshold in 0.01 bar
	cpfsgt	lo
	retlw	.0								; within range
	retlw	.1								; out of range
check_sensor_voting_helper2:
	; lo < sensor_setpoint
	movf	sensor_setpoint,W
	subwf	lo,F
	bra		check_sensor_voting_helper1

;-----------------------------------------------------------------------------

divemodemode_togglegf:								; toggle aGF/GF
	bcf		toggle_gf								; clear command flag
	btg		use_agf									; toggle status flag for GF

	btfsc	use_agf									; aGF activated?
	bra		divemodemode_togglegf_1					; YES - branch to using aGF
	movff	opt_GF_low,char_I_GF_Low_percentage		; NO  - use normal GF factors
	movff	opt_GF_high,char_I_GF_High_percentage	;     -
	bra		divemodemode_togglegf_2					;     - continue with common part
divemodemode_togglegf_1:
	movff	opt_aGF_low,char_I_GF_Low_percentage	; YES - use alternative GF factors
	movff	opt_aGF_high,char_I_GF_High_percentage	;     -
divemodemode_togglegf_2:
	call	TFT_gf_factors_mask						; update custom view mask to show which one is in use
													; the custom view itself has been called from divemenu_tree before
	goto	restart_deco_engine						; ...and return


 IFDEF _cave_mode
divemodemode_toggleturn:
	bcf		toggle_turn_dive						; clear command flag
	btg		FLAG_dive_turned						; toggle dive turned state
	btfsc	FLAG_cave_mode_shutdown					; cave mode function shut down?
	bsf		FLAG_dive_turned						; YES - allow only activating turned state
	goto	set_logbook_marker						; set a logbook marker (and return)
 ENDIF

calc_velocity:										; called every two seconds
	btfsc	display_velocity
	bra		calc_velocity1							; always update if already displayed
	btfss	divemode2
	return											; display velocity only if deeper then 1m (Not at the surface after the dive)
calc_velocity1:
	SAFE_2BYTE_COPY amb_pressure, sub_a
	movff	last_pressure_velocity+0,sub_b+0
	movff	last_pressure_velocity+1,sub_b+1
	movff	sub_a+0,last_pressure_velocity+0		; store old value for velocity
	movff	sub_a+1,last_pressure_velocity+1

	call	subU16									; sub_c = amb_pressure - last_pressure

	bcf		neg_flag_velocity
	btfsc	neg_flag
	bsf		neg_flag_velocity

	movff	sub_c+0,xA+0
	movff	sub_c+1,xA+1
	movlw	d'39'						; 77 when called every second....
	movwf	xB+0
	clrf	xB+1
	call	mult16x16					; differential pressure in mbar*77...
	movff	xC+0,divA+0
	movff	xC+1,divA+1
	movlw	d'7'
	call	div16						; divA = divA / 2^WREG, divide by 2^7 equals velocity in m/min

	movlw	d'99'
	cpfsgt	divA+0						; velocity > 99 m/min ?
	bra		calc_velocity3				; NO
	movwf	divA+0						; YES - set divA = 99

calc_velocity3:
	; Copy old speeds
	movff	old_velocity+2,old_velocity+3
	movff	old_velocity+1,old_velocity+2
	movff	old_velocity+0,old_velocity+1
	movff	divA+0,old_velocity+0

;	movff	old_velocity+3,WREG
;	addwf	divA+0,F					; add old speed
;	bcf		STATUS,C
;	rrcf	divA+0,F					; /2
;	movff	old_velocity+2,WREG
;	addwf	divA+0,F					; add old speed
;	bcf		STATUS,C
;	rrcf	divA+0,F					; /2
;	movff	old_velocity+1,WREG
;	addwf	divA+0,F					; add old speed
;	bcf		STATUS,C
;	rrcf	divA+0,F					; /2
;	movff	old_velocity+0,WREG
;	addwf	divA+0,F					; add old speed
;	bcf		STATUS,C
;	rrcf	divA+0,F					; /2
	goto	TFT_display_velocity		; with divA+0 = m/min..., and return...


;=============================================================================

set_reset_safety_stop:					; set flags for safety stop and/or reset safety stop
	TSTOSS	opt_enable_safetystop		; safety stop enabled? (=1: show safety stop)
	bra		delete_safety_stop			; NO - don't show safety stop

	btfsc	decostop_active				; is a deco stop displayed?
	bra		delete_safety_stop			; YES - don't show safety stop

	; Below "opt_safety_stop_reset"? if yes, set flag and reset count-down timer
	SAFE_2BYTE_COPY rel_pressure, lo
	call	adjust_depth_with_salinity	; computes salinity setting into lo:hi [mbar]
	movff	lo,sub_a+0
	movff	hi,sub_a+1
	movff	opt_safety_stop_reset,WREG	; [cbar]
	mullw	.10							; mbar in PRODL:H
	movff	PRODL,sub_b+0
	movff	PRODH,sub_b+1
	call	subU16						; sub_c = sub_a - sub_b
	btfss	neg_flag
	bra		reset_safety_stop			; below 10m, reset safety stop

	; Above "opt_safety_stop_end"? if yes ,clear flag
	movff	opt_safety_stop_end,WREG	; [cbar]
	mullw	.10							; mbar in PRODL:H
	movff	PRODL,sub_b+0				; sub_a is still loaded with adjusted rel_pressure
	movff	PRODH,sub_b+1
	call	subU16						; sub_c = sub_a - sub_b
	btfsc	neg_flag
	bra		delete_safety_stop			; above 3m, remove safety stop

	; Above "opt_safety_stop_start"? if yes, activate safety stop
	movff	opt_safety_stop_start,WREG	; [cbar]
	mullw	.10							; mbar in PRODL:H
	movff	PRODL,sub_b+0				; sub_a is still loaded with adjusted rel_pressure
	movff	PRODH,sub_b+1
	call	subU16						; sub_c = sub_a - sub_b
	btfsc	neg_flag
	bra		acivate_safety_stop			; above 5m, activate safety stop
	bra		reset_safety_stop2			; pause safety stop

acivate_safety_stop:
	tstfsz	safety_stop_countdown		; countdown at zero?
	bsf		show_safety_stop			; NO - set flag
	return

delete_safety_stop:
	clrf	safety_stop_countdown		; reset timer
	bra		reset_safety_stop2			; remove safety stop from display

reset_safety_stop:
	movff	opt_safety_stop_length,safety_stop_countdown ; reset timer
reset_safety_stop2:
	bcf		show_safety_stop			; clear flag
	btfss	safety_stop_active			; safety stop shown?
	return								; NO - don't delete it
	bcf		safety_stop_active			; clear flag
	bsf		FLAG_TFT_clear_safety_stop	; Clear safety stop
	return


;=============================================================================

timeout_menuview:
	decfsz	timeout_counter2,F			; timeout for menu view?
	return								; NO - done
	; Timeout, clear e.g. "Menu?"
	goto	menuview_toggle_reset		; ...and return

timeout_divemode_menu:
	decfsz	timeout_counter2,F			; timeout for divemode menu
	return

	global	timeout_divemode_menu2
timeout_divemode_menu2:					; called from divemenu_tree.asm
	bcf		divemode_menu				; timeout, clear flag
	call	TFT_clear_divemode_menu		; clear menu
	bsf		FLAG_TFT_active_gas_divemode; redraw gas/setpoint/diluent
	bcf		blinking_better_gas			; clear flag to have temperature updated once
	bcf		blinking_better_dil			; clear flag to have temperature updated once
	bsf		FLAG_TFT_temp_divemode		; display temperature
	call	TFT_draw_gassep_line		; gas separator grid in spec mode only

	btfss	decostop_active				; in deco mode ?
	bra		timeout_divemode_menu_ndl	; NO - show NDL again
	; Show deco data
	bsf		FLAG_TFT_display_deko_mask
	bsf		FLAG_TFT_display_deko
	bsf		FLAG_TFT_display_tts
	return

timeout_divemode_menu_ndl:
	; Show NDL
	bsf		FLAG_TFT_display_ndl_mask
	bsf		FLAG_TFT_display_ndl
	return

timeout_divemode:
	btfsc	divemode_menu				; divemode menu active?
	rcall	timeout_divemode_menu		; YES - check the timeout for it...

	btfsc	menuview					; is a menu view shown?
	rcall	timeout_menuview			; YES - check the timeout for it...

	btfss	realdive					; dive longer than one minute?
	return								; NO  - done

	btfsc	FLAG_apnoe_mode				; in apnoe mode?
	bra		timeout_divemode2			; YES - use apnoe_timeout [min] for timeout

 IFNDEF __DEBUG
	btfsc	simulatormode_active		; in simulator mode?
	bra		timeout_divemode3			; YES - use simulator timeout
 ENDIF

	bcf		divemode					; terminate divemode my default
	infsnz	timeout_counter1+0,F		; increment timeout counter
	incf	timeout_counter1+1,F		; timeout is 16 bit counter

	movff	opt_diveTimeout,WREG		; get timeout in minutes
	mullw	.60							; convert into seconds
	movff	PRODL,sub_a+0
	movff	PRODH,sub_a+1

	movff	timeout_counter1+0,sub_b+0
	movff	timeout_counter1+1,sub_b+1
	call	subU16						; sub_c = sub_a - sub_b
	btfss	neg_flag					; result negative, i.e. timeout?
	bsf		divemode					; NO - set divemode flag again
	return

timeout_divemode2:
	incf	timeout_counter1+0,F		; seconds...
	movlw	d'60'
	cpfseq	timeout_counter1+0			; timeout_counter1+0 = 60 ?
	return								; No
	; one minute timeout done
	clrf	timeout_counter1+0
	bcf		divemode
	incf	apnoe_timeout_counter,F
	movlw	apnoe_timeout				; apnoe timeout [min]
	cpfseq	apnoe_timeout_counter
	bsf		divemode
	return

timeout_divemode3:
	bcf		divemode
	incf	timeout_counter1+0,F
	movlw	simulator_timeout			; simulator timeout
	cpfsgt	timeout_counter1+0
	bsf		divemode
	return

update_divemode60:						; update any minute
	call	get_battery_voltage			; gets battery voltage
	rcall	set_powersafe				; check if battery low
	;call	customview_minute			; do every-minute tasks for the custom view area
	bcf		oneminupdate
 IFDEF _cave_mode
	movlw	.1							; prepare to add backtrack data for 1 minute
	btfsc	FLAG_cave_mode				; cave mode enabled?
	rcall	update_backtrack			; YES - make it so
 ENDIF
	btfss	simulatormode_active		; in simulator mode?
	return								; NO  - done
	movlw	.20							; YES - quite dive mode simulation after 21 * 256 sec = 89 min : 36 sec
	cpfsgt	total_divetime_seconds+1	; timeout?
	return								; NO  - done
 IFDEF __DEBUG
	return								; YES -  but no timeout in debug mode
 ENDIF
	bra		divemode_option1			; YES - set depth to 0 m and "return"

 IFDEF _cave_mode
update_backtrack:
	btfsc	FLAG_dive_turned			; dive turned?
	return								; YES - done
	movwf	lo							; store minutes to add in lo
	lfsr	FSR1,char_I_backtrack_depth ; load FSR1 with base address of backtrack storage
	movff	char_I_backtrack_time,FSR1L	; adjust FSR1 to last index
update_backtrack_loop:
	btfsc	FLAG_cave_mode_shutdown		; backtrack storage full?
	return								; YES - done
	movff	curr_depth,PREINC1			; NO  - increment index and write current depth to backtrack storage
	incfsz	FSR1L,W						;     - did a wrap-around of the index occur (backtrack storage full)?
	bra		update_backtrack_loop_1		;       NO  - continue loop
	bsf		FLAG_cave_mode_shutdown		;       YES - flag backtrack storage as being full
	return
update_backtrack_loop_1:
	decfsz	lo,F						; decrement loop counter, did it became zero?
	bra		update_backtrack_loop		; NO  - loop
	movff	FSR1L,char_I_backtrack_time	; YES - read-back index
	return								;     - done
 ENDIF

set_max_depth:
	movff	max_pressure+0,sub_a+0
	movff	max_pressure+1,sub_a+1
	SAFE_2BYTE_COPY rel_pressure, sub_b
	call	subU16						; sub_c = sub_a - sub_b
										; max_pressure <  rel_pressure -> neg_flag=1
										; rel_pressure <= max_pressure -> neg_flag=0
	btfss	neg_flag
	return
										; max_pressure < rel_pressure
	movff	sub_b+0,max_pressure+0
	movff	sub_b+1,max_pressure+1
	bsf		FLAG_TFT_max_depth			; set flag
	return

set_min_temp:
	movff	minimum_temperature+0,sub_a+0
	movff	minimum_temperature+1,sub_a+1
	SAFE_2BYTE_COPY temperature,sub_b
	call	sub16						; sub_c = sub_a - sub_b
										; minimum_temperature < T  -> neg_flag=1
										; T <= minimum_temperature -> neg_flag=0
	btfsc	neg_flag
	return
	; minimum_temperature >= T
	movff	sub_b+0,minimum_temperature+0
	movff	sub_b+1,minimum_temperature+1
	return

	global	set_dive_modes
set_dive_modes:
	btfsc	high_altitude_mode			; in high altitude (fly) mode?
	bra		set_dive_modes3				; YES

set_dive_modes0:
	movlw	LOW  start_dive_threshold
	movwf	sub_a+0						; dive_treshold is in cm
	movlw	HIGH start_dive_threshold
	movwf	sub_a+1						; dive_treshold is in cm

set_dive_modes1:
	SAFE_2BYTE_COPY rel_pressure, sub_b
	call	subU16						; sub_c = sub_a - sub_b

	btfss	neg_flag
	bra		set_dive_modes2				; too shallow (rel_pressure < dive_threshold)

	btfsc	realdive					; dive longer than one minute?
	clrf	timeout_counter1+0			; YES - reset timeout counter

	bsf		divemode					; (re-)set divemode flag
	bsf		divemode2					; displayed divetime is running
	return

set_dive_modes2:
	bcf		divemode2					; stop time
	btfss	realdive					; dive longer then one minute?
	bcf		divemode					; NO  - this was no real dive
	return								; YES - return

set_dive_modes3:						; high-altitude mode
	btfsc	realdive					; dive longer then one minute?
	bra		set_dive_modes0				; YES - this is a real dive -> Use start_dive_threshold or ascend

	movlw	LOW  high_altitude_dive_threshold
	movwf	sub_a+0
	movlw	HIGH high_altitude_dive_threshold
	movwf	sub_a+1
	bra		set_dive_modes1

set_powersafe:
	movlw	color_code_battery_low+1; [%]
	cpfslt	batt_percent
	return

	movlw	d'7'						; type of alarm (battery Low)
	movwf	AlarmType					; copy to alarm register
	bsf		event_occured				; set event flag
	movlw	.0
	movff	WREG,opt_brightness			; set brightness to ECO
	return								; return


reset_average:
	bcf		reset_average_depth			; clear reset-average flag
	clrf	average_depth_hold+0		; clear the depth accumulator
	clrf	average_depth_hold+1		; ...
	clrf	average_depth_hold+2		; ...
	clrf	average_depth_hold+3		; ...
	clrf	average_divesecs+0			; clear the time accumulator
	clrf	average_divesecs+1			; ...
	SAFE_2BYTE_COPY rel_pressure,avg_rel_pressure ; prime result with current rel.pressure/depth
	return


calc_average_depth:
	; 1. compute rel_pressure x 2, because this routine is called every 2nd second only
	SAFE_2BYTE_COPY rel_pressure,xB		; copy current rel pressure to xB
	bcf		STATUS,C
	rlcf	xB+0,F						; multiply rel pressure x 2 (via shift left)
	rlcf	xB+1,F						; ...

	; 2a add (rel_pressure x 2) to the resettable depth accumulator
	movf	xB+0,W
	addwf	average_depth_hold+0,F
	movf	xB+1,W
	addwfc	average_depth_hold+1,F
	movlw	.0
	addwfc	average_depth_hold+2,F
	addwfc	average_depth_hold+3,F			; will work up to 9999 mbar * 60 * 60 * 24 = 863913600 mbar (24h @ 90 m depth)

	; 2b add (rel_pressure x 2) to the total depth accumulator
	movf	xB+0,W
	addwf	average_depth_hold_total+0,F
	movf	xB+1,W
	addwfc	average_depth_hold_total+1,F
	movlw	.0
	addwfc	average_depth_hold_total+2,F
	addwfc	average_depth_hold_total+3,F	; will work up to 9999 mbar * 60 * 60 * 24 = 863913600 mbar (24h @ 90 m depth)

	; 3a compute avg_rel_pressure on base of average_divesecs:2
	movff	average_depth_hold+0,xC+0
	movff	average_depth_hold+1,xC+1
	movff	average_depth_hold+2,xC+2
	movff	average_depth_hold+3,xC+3		; copy accumulated depth
	movff	average_divesecs+0,xB+0
	movff	average_divesecs+1,xB+1			; copy accumulated time
	call	div32x16						; xC:4 / xB:2 = xC+3:xC+2 with xC+1:xC+0 as remainder
	movff	xC+0,avg_rel_pressure+0
	movff	xC+1,avg_rel_pressure+1			; store result

	btfss	divemode2						; displayed divetime is running?
	return									; NO (e.g. too shallow)

	; 3b compute avg_rel_pressure_total on base of average_divesecs_total:2
	movff	average_depth_hold_total+0,xC+0
	movff	average_depth_hold_total+1,xC+1
	movff	average_depth_hold_total+2,xC+2
	movff	average_depth_hold_total+3,xC+3	; copy accumulated depth
	movff	average_divesecs_total+0,xB+0
	movff	average_divesecs_total+1,xB+1	; copy accumulated time
	call	div32x16						; xC:4 / xB:2 = xC+3:xC+2 with xC+1:xC+0 as remainder
	movff	xC+0,avg_rel_pressure_total+0
	movff	xC+1,avg_rel_pressure_total+1	; store result

	btfsc	reset_average_depth				; reset the resettable average depth?
	rcall	reset_average					; YES - reset the resettable average depth

	TSTOSS	opt_2ndDepthDisp				; drawing avg depth instead of max depth?
	return									; NO  - done
	bsf		FLAG_TFT_max_depth				; YES - flag to update display
	return


test_switches_divemode:						; checks switches in divemode
	btfsc	divemode_menu					; divemode menu shown?
	bra		test_switches_divemode_menu		; YES - use menu processor
	btfsc	switch_left						; NO  - left button pressed?
	goto	menuview_toggle					;       YES - menu or simulator tasks; and return...
	btfss	switch_right					;       NO  - right button pressed?
	return									;             NO  - done
	tstfsz	menupos2						;             YES - any option shown?
	bra		test_switches_divemode1			;                   YES - do option tasks
	bsf		toggle_customview				;                   NO  - toggle custom view
	return									;                       - done

test_switches_divemode_menu:
	btfsc	switch_left
	bra		test_switches_divemode_menu2	; move cursor
	btfsc	switch_right					; left button pressed?
	bra		test_switches_divemode_menu3	; YES - enter submenu or do something
	return									; NO  - done

test_switches_divemode_menu1:
	clrf	menupos1
test_switches_divemode_menu2:
	incf	menupos1,F
	incf	menupos4,W						; menupos4 + 1 -> WREG
	cpfslt	menupos1						; > menupos4 (set in menu_processor.asm)?
	bra		test_switches_divemode_menu1	; YES - set to 1
	call	TFT_divemode_menu_cursor		; update the cursor
	bcf		switch_left
	movlw	divemode_menu_timeout			; reload timeout
	movwf	timeout_counter2				; timeout for divemode menu
	return

test_switches_divemode_menu3:			; enter submenu or do something
	bcf		switch_right
;	decf	menupos1,F					; menu_processor needs 0-5...
	goto	do_line_menu				; Warning! trashes STKPTR and returns to diveloop_loop4:

test_switches_divemode1:
	bcf		switch_right
	movlw	divemode_menuview_timeout
	movwf	timeout_counter2			; reload timeout
	movff	menupos2,WREG				; menupos2 holds number of customview/divemode menu function
	dcfsnz	WREG,F
	bra		divemode_option_gaschange	; switch to the the "better gas" / "better diluent"
	dcfsnz	WREG,F
	bra		divemode_option0			; start/setup Divemode menu
	dcfsnz	WREG,F
	bra		divemode_option1			; quit simulation?
	dcfsnz	WREG,F
	bra		divemode_option2			; descent 1m
	dcfsnz	WREG,F
	bra		divemode_option3			; ascend 1m
	dcfsnz	WREG,F
	bra		divemode_option4			; quit Apnoe mode
	dcfsnz	WREG,F
	bra		divemode_option5			; reset stopwatch (gauge mode only)
	dcfsnz	WREG,F
	bra		divemode_option6			; +5mins simulation
	dcfsnz	WREG,F
	bra		divemode_option7			; store heading
	dcfsnz	WREG,F
	bra		divemode_option8			; switch to alternative layout
	return

gas_switched_common:
	bcf		divemode_gaschange			; clear flag
	btfss	FLAG_back_to_loop			; check if it is a switchback from OC bailout to loop
	bra		gas_switched_common0		; NO  - continue with checking if selected gas is valid
	bcf		FLAG_back_to_loop			; YES - clear flag
	movff	active_dil,menupos1			;       reload last diluent
	bra		gas_switched_common1		;       continue with common part
gas_switched_common0:
	tstfsz	menupos1					; menupos1 = 0 ?
	bra		gas_switched_common1		; NO  - valid gas
	return								; YES - something went wrong, invalid gas, abort
gas_switched_common1:
	movf	menupos1,W					; get selected gas into WREG (1-6)
	btfsc	FLAG_oc_mode				; in OC mode?
	bra		gas_switched_common_OC		; YES
	btfsc	FLAG_bailout_mode			; in bailout?
	bra		gas_switched_common_OC		; YES
gas_switched_common_loop:				; NO to both - must be loop mode then
	rcall	setup_dil_registers			; with WREG = diluent 1-6
	rcall	deco_setup_cc_diluents		; with WREG = diluent 1-6
	bra		gas_switched_common3
gas_switched_common_OC:
	rcall	setup_gas_registers			; with WREG = Gas 1-6
	rcall	deco_setup_oc_gases			; with WREG = Gas 1-6
gas_switched_common3:
	banksel	int_O_breathed_ppO2
	bcf		int_O_breathed_ppO2+1,int_low_flag			; | clear all flags that control color-coding
	bcf		int_O_breathed_ppO2+1,int_high_flag			; | to have the new gas initially displayed in
	bcf		int_O_breathed_ppO2+1,int_attention_flag	; | memo color instead of a warning or attention
	bcf		int_O_breathed_ppO2+1,int_warning_flag		; | color that belonged to the previous gas
	banksel	common
	bsf		FLAG_TFT_active_gas_divemode				; redraw gas/setpoint/diluent
	call	restart_deco_engine_wo_ceiling				; abort any running deco calculations and restart the deco engine
	; set flags for profile recording
	bsf		event_occured				; set event flag
	btfsc	FLAG_bailout_mode			; choose OC Bailouts (OC Gases)
	bsf		bailoutgas_event			; bailout gas change
	btfss	FLAG_bailout_mode			; choose OC Bailouts (OC Gases)
	bsf		stored_gas_changed			; OC gas change
	return


; Code to pass all parameters to the C code

	global	get_first_gas_to_WREG
get_first_gas_to_WREG:					; gets first gas (1-5) into WREG
	lfsr	FSR1,opt_gas_type			; point to gas types
	clrf	lo							; start with gas 0
get_first_gas_to_WREG2:
	movf	lo,W
	movf	PLUSW1,W					; get type of gas #lo
	sublw	.1							; it is = 1 (First Gas)
	bz		get_first_gas_to_WREG3		; found the first gas!
	incf	lo,F						; ++
	movlw	NUM_GAS+1
	cpfseq	lo							; all done?
	bra		get_first_gas_to_WREG2		; NO - not yet
	; no first gas found, use #1
	movlw	.0
	movff	WREG,opt_gas_type+0			; set gas 1 to First
	incf	WREG,W						; 0 -> 1
	return
get_first_gas_to_WREG3:
	movf	lo,W						; put into WREG
	incf	WREG,W						; 0-4 -> 1-5
	return								; done

	global	get_first_dil_to_WREG
get_first_dil_to_WREG:					; gets first dil (1-5) into WREG
	lfsr	FSR1,opt_dil_type			; point to dil types
	clrf	lo							; start with dil 0
get_first_dil_to_WREG2:
	movf	lo,W
	movf	PLUSW1,W					; get type of Dil #lo
	sublw	.1							; it is = 1 (First Dil)
	bz		get_first_dil_to_WREG3		; found the first dil!
	incf	lo,F						; ++
	movlw	NUM_GAS+1
	cpfseq	lo							; all done?
	bra		get_first_dil_to_WREG2		; NO - not yet
	; no first dil found, use #1
	movlw	.0
	movff	WREG,opt_dil_type+0			; set dil 1 to First
	incf	WREG,W						; 0 -> 1
	return
get_first_dil_to_WREG3:
	movf	lo,W						; Put into WREG
	incf	WREG,W						; 0-4 -> 1-5
	return								; done


deco_setup_oc_gases:					; with currently breathed gas in WREG (1-5 or 6)
	movff	char_O_deco_status,lo		; working copy of char_O_deco_status in bank common
deco_setup_oc_gases_pre:				; entry point with lo preloaded
	movff	WREG,char_I_current_gas		; set gas to start with when doing the deco calculations
	;
	; Memory Map:
	; ---------------------------------------------------------------------------------
	; opt_gas_O2_ratio		res NUM_GAS		|	char_I_deco_O2_ratio		res NUM_GAS
	; opt_dil_O2_ratio		res NUM_GAS		|
	; opt_gas_He_ratio		res NUM_GAS		|	char_I_deco_He_ratio		res NUM_GAS
	; opt_dil_He_ratio		res NUM_GAS		|
	; opt_gas_type			res NUM_GAS		|	char_I_deco_gas_type		res NUM_GAS
	; opt_dil_type			res NUM_GAS		|
	; opt_gas_change		res NUM_GAS		|	char_I_deco_gas_change		res NUM_GAS
	; opt_dil_change		res NUM_GAS		|
	;
	lfsr	FSR2,char_I_deco_O2_ratio	; Load FSR2 with base address of char_I_deco_O2_ratio.
										; FSR2 will step through all char_I_deco_... vars.
	lfsr	FSR1,opt_gas_O2_ratio		; load FSR1 with base address of opt_gas_O2_ratio
	rcall	deco_setup_copy				; copy all OC O2 ratios
	lfsr	FSR1,opt_gas_He_ratio		; load FSR1 with base address of opt_gas_He_ratio
	rcall	deco_setup_copy				; copy all OC He ratios
	lfsr	FSR1,opt_gas_type			; load FSR1 with base address of opt_gas_type
	rcall	deco_setup_copy				; copy all gas types
	lfsr	FSR1,opt_gas_change			; load FSR1 with base address of opt_gas_change
	rcall	deco_setup_copy				; copy all gas change depths
										; switch to oc mode
	bcf		lo,DECO_MODE_PSCR_FLAG		; clear the pSCR-mode flag (may not be set, but never mind)
	bcf		lo,DECO_MODE_LOOP_FLAG		; clear the loop/CCR-mode flag
	movff	lo,char_O_deco_status		; bank safe write-back of char_O_deco_status
	return


deco_setup_cc_diluents:					; with currently breathed diluent in WREG (1-5 or 6)
	movff	char_O_deco_status,lo		; working copy of char_O_deco_status in bank common
deco_setup_cc_diluents_pre:				; entry point with lo preloaded
	btfsc	FLAG_bailout_mode			; check if in bailout condition       | --------------- FOR SAFETY ONLY --------------
	bra		deco_setup_oc_gases_pre		; YES - revert to setting up OC gases | This branch should never happen to be taken...
	movff	WREG,char_I_current_gas		; NO  - set diluent to start with when doing the deco calculations
	;
	; Memory Map:
	; ---------------------------------------------------------------------------------
	; opt_gas_O2_ratio		res NUM_GAS		|
	; opt_dil_O2_ratio		res NUM_GAS		|	char_I_deco_O2_ratio		res NUM_GAS
	; opt_gas_He_ratio		res NUM_GAS		|
	; opt_dil_He_ratio		res NUM_GAS		|	char_I_deco_He_ratio		res NUM_GAS
	; opt_gas_type			res NUM_GAS		|
	; opt_dil_type			res NUM_GAS		|	char_I_deco_gas_type		res NUM_GAS
	; opt_gas_change		res NUM_GAS		|
	; opt_dil_change		res NUM_GAS		|	char_I_deco_gas_change		res NUM_GAS
	;
	lfsr	FSR2,char_I_deco_O2_ratio	; Load FSR2 with base address of char_I_deco_O2_ratio.
										; FSR2 will step through all char_I_deco_... vars.
	lfsr	FSR1,opt_dil_O2_ratio		; load FSR1 with base address of opt_dil_O2_ratio
	rcall	deco_setup_copy				; copy all dil O2 ratios
	lfsr	FSR1,opt_dil_He_ratio		; load FSR1 with base address of opt_dil_He_ratio
	rcall	deco_setup_copy				; copy all dil He ratios
	lfsr	FSR1,opt_dil_type			; load FSR1 with base address of opt_dil_type
	rcall	deco_setup_copy				; copy all dil types
	lfsr	FSR1,opt_dil_change			; load FSR1 with base address of opt_dil_change
	rcall	deco_setup_copy				; copy all dil change depths
										; switch to CCR / pSCR mode
	bsf		lo,DECO_MODE_LOOP_FLAG		; loop flag is set in both, CCR and pSCR mode
	bcf		lo,DECO_MODE_PSCR_FLAG		; clear pSCR mode flag by default
	btfsc	FLAG_pscr_mode				; check if we are in pSCR mode
	bsf		lo,DECO_MODE_PSCR_FLAG		; YES - set additional flag for pSCR mode
	movff	lo,char_O_deco_status		; bank safe write-back of char_O_deco_status
	return

deco_setup_copy:
	movlw	NUM_GAS						; load loop counter with number of gases (5)
deco_setup_copy_loop:
	movff	POSTINC1,POSTINC2			; copy from (FSR1) to (FSR2)
	decfsz	WREG						; decrement loop counter and check if it became 0
	bra		deco_setup_copy_loop		; NO  - not yet, loop
	return								; YES - done


	global	setup_gas_registers
setup_gas_registers:					; with currently breathed gas in WREG (1-5 or 6)
	movwf	active_gas					; set as current gas
	movlw	.6
	cpfseq	active_gas					; gas = gas6 ?
	bra		setup_gas_registers_15		; NO - load gas 1-5
	movff	gas6_O2_ratio,char_I_O2_ratio ; copy gas6 O2 ratio to deco engine
	movff	gas6_He_ratio,char_I_He_ratio ; copy gas6 H2 ratio to deco engine
	movlw	.3							; declare gas6 as a deco gas
	movff	WREG,char_I_current_gas_type; copy gas type to deco engine
	movff	curr_depth,char_I_gas6_depth; set current depth as change depth
	bra		setup_gas_registers_com		; continue with common part
setup_gas_registers_15:
	decf	active_gas,W				; 1-5 -> 0-4
	lfsr	FSR1,opt_gas_O2_ratio
	movff	PLUSW1,char_I_O2_ratio		; copy gas 1-5 O2 ratio to deco engine
	lfsr	FSR1,opt_gas_He_ratio
	movff	PLUSW1,char_I_He_ratio		; copy gas 1-5 He ratio to deco engine
	lfsr	FSR1,opt_gas_type			;
	movff	PLUSW1,char_I_current_gas_type ; copy gas 1-5 type (0=Disabled, 1=First, 2=Travel, 3=Deco)
setup_gas_registers_com:
	movff	char_O_main_status,lo		; working copy of char_O_main_status in bank common
	bcf		lo,DECO_MODE_PSCR_FLAG		; clear the pSCR-mode flag (may not be set, but never mind)
	bcf		lo,DECO_MODE_LOOP_FLAG		; clear the loop/CCR-mode flag
	movff	lo,char_O_main_status		; bank safe write-back of char_O_main_status
	movf	active_gas,W				; reload WREG with gas 1-5 or 6 (important!)
	return

	global	setup_dil_registers
setup_dil_registers:					; with currently breathed gas in WREG (1-5 or 6)
	btfsc	FLAG_bailout_mode			; check if in bailout condition                      | --------------- FOR SAFETY ONLY --------------
	bra		setup_gas_registers			; revert to setting up OC gases in bailout condition | This branch should never happen to be taken...
	movwf	active_dil					; set as current diluent
	movlw	.6
	cpfseq	active_dil					; diluent = gas6 ?
	bra		setup_dil_registers_15		; NO - load diluent 1-5
	movff	gas6_O2_ratio,char_I_O2_ratio ; copy gas6 O2 ratio to deco engine
	movff	gas6_He_ratio,char_I_He_ratio ; copy gas6 H2 ratio to deco engine
	movlw	.2							; declare gas6 as a normal diluent
	movff	WREG,char_I_current_gas_type; copy gas type to deco engine
	movff	curr_depth,char_I_gas6_depth; set current depth as change depth
	bra		setup_dil_registers_com		; continue with common part
setup_dil_registers_15:
	decf	active_dil,W				; 1-5 -> 0-4
	lfsr	FSR1,opt_dil_O2_ratio
	movff	PLUSW1,char_I_O2_ratio		; copy diluent 1-5 O2 ratio to deco engine
	lfsr	FSR1,opt_dil_He_ratio
	movff	PLUSW1,char_I_He_ratio		; copy diluent 1-5 He ratio to deco engine
	lfsr	FSR1,opt_dil_type			;
	movff	PLUSW1,char_I_current_gas_type ; copy dil type (0=Disabled, 1=First, 2=Normal)
setup_dil_registers_com:
	movff	char_O_main_status,lo		; working copy of char_O_main_status in bank common
	bsf		lo,DECO_MODE_LOOP_FLAG		; loop flag is set in both, CCR and pSCR mode
	bcf		lo,DECO_MODE_PSCR_FLAG		; clear pSCR mode flag by default
	btfsc	FLAG_pscr_mode				; check if we are in pSCR mode
	bsf		lo,DECO_MODE_PSCR_FLAG		; YES - set additional flag for pSCR mode
	movff	lo,char_O_main_status		; bank safe write-back of char_O_main_status
	movf	active_dil,W				; reload WREG with diluent 1-5 or 6 (important!)
	return


divemode_option_gaschange:				; switch to the "better gas" / "better diluent"
	btfsc	FLAG_oc_mode				; in OC mode?
	bra		divemode_option_gaschange_oc; YES
	btfsc	FLAG_bailout_mode			; in bailout?
	bra		divemode_option_gaschange_oc; YES
divemode_option_gaschange_loop:			; in CCR/pSCR mode and not in bailout
	movff	best_dil_number,menupos1	; NO  - select best diluent
	bcf		better_dil_available		;     - clear flag immediately
	bra		divemode_option_gaschange3	;     - continue with common part
divemode_option_gaschange_oc:			; in OC or bailout
	movff	best_gas_number,menupos1	; select best gas
	bcf		better_gas_available		; clear flag immediately
divemode_option_gaschange3				; common part
	bsf		divemode_gaschange			; command a gas/diluent change
	call	menuview_toggle_reset		; terminate the options menu
	return

divemode_option0:						; start/setup dive mode menu
	call	TFT_clear_divemode_menu		; clear menu area
	bcf		menuview
	call	do_main_divemenu

	global	divemode_option0_return
divemode_option0_return:
;	movlw	.1
;	movwf	menupos1					; set to first option in dive mode menu
	call	TFT_divemode_menu_cursor	; show the cursor
	movlw	divemode_menu_timeout
	movwf	timeout_counter2			; timeout for dive mode menu
	bsf		divemode_menu				; set flag
	clrf	menupos2					; clear option counter
	goto	diveloop_loop4				; go back to dive loop (menu processor trashes STKPTR!)

divemode_option4:
	movlw	d'58'						; two seconds left
	movwf	timeout_counter1+0
	movlw	apnoe_timeout-1				; apnoe timeout [min]
	movwf	apnoe_timeout_counter
	btfss	simulatormode_active		; in simulator mode?
	return								; NO
	;bra	divemode_option1			; YES

divemode_option1:						; quit simulation mode
	banksel	isr_backup
	movlw	LOW  .1000
	movwf	sim_pressure+0
	movlw	HIGH .1000
	movwf	sim_pressure+1				; set to 0m -> end of dive
	banksel	common
	call	menuview_toggle_reset		; reset to zero (zero = no menu view)

	btfss	FLAG_apnoe_mode				; in apnoe mode?
	return								; NO - done
	movlw	d'58'						; two seconds left
	movwf	timeout_counter1+0
	movlw	apnoe_timeout-1				; apnoe timeout [min]
	movwf	apnoe_timeout_counter
	return

divemode_option3:						; minus 1m
	banksel	isr_backup
	movlw	d'100'
	subwf	sim_pressure+0
	movlw	.0
	subwfb	sim_pressure+1
	rcall	divemode_simulator_check_limits
	banksel	common
	return

divemode_option2:						; plus 1m
	banksel	isr_backup
	movlw	d'100'
	addwf	sim_pressure+0,F
	movlw	.0
	addwfc	sim_pressure+1,F
	rcall	divemode_simulator_check_limits
	banksel	common
	return

divemode_option5:
	call	menuview_toggle_reset		; reset to zero (zero = no menu view)
	bsf		reset_average_depth			; set flag
	return

divemode_option6:
	; advance tissues and deco by 5 minutes
	movlw	.5							; + 5 minutes
	movff	WREG,char_I_sim_advance_time; copy to mailbox
	call	restart_deco_engine

	; stop divetime incrementing in ISR
	bcf		divemode2

	; add 5 minutes to divemins
	movlw	.5
	addwf	divemins+0,F
	movlw	.0
	addwfc	divemins+1,F

	; add 5 minutes (5 * 60 seconds) to total_divetime_seconds
	movlw	LOW  (.5*.60)
	addwf	total_divetime_seconds+0,F
	movlw	HIGH (.5*.60)
	addwfc	total_divetime_seconds+1,F

	; continue dive time incrementing in ISR
	bsf		divemode2

	; add 5 minutes (5 * 60 seconds) to resettable time accumulator
	movlw	LOW  (.5*.60)
	addwf	average_divesecs+0,F
	movlw	HIGH (.5*.60)
	addwfc	average_divesecs+1,F

	; add 5 minutes (5 * 60 seconds) to total time accumulator
	movlw	LOW  (.5*.60)
	addwf	average_divesecs_total+0,F
	movlw	HIGH (.5*.60)
	addwfc	average_divesecs_total+1,F


	; calculate 300 x depth in mbar (300 = 5 min * 60 sec/min)
	SAFE_2BYTE_COPY rel_pressure, xB
	movlw	LOW  (.5*.60)
	movwf	xA+0
	movlw	HIGH (.5*.60)
	movwf	xA+1
	call	mult16x16					; xA*xB=xC

	; add to the resettable depth accumulator
	movf	xC+0,W
	addwf	average_depth_hold+0,F
	movf	xC+1,W
	addwfc	average_depth_hold+1,F
	movf	xC+2,W
	addwfc	average_depth_hold+2,F
	movf	xC+3,W
	addwfc	average_depth_hold+3,F

	; add to the total depth accumulator
	movf	xC+0,w
	addwf	average_depth_hold_total+0,F
	movf	xC+1,w
	addwfc	average_depth_hold_total+1,F
	movf	xC+2,w
	addwfc	average_depth_hold_total+2,F
	movf	xC+3,w
	addwfc	average_depth_hold_total+3,F

 IFDEF _cave_mode
	; update backtracking data
	movlw	.5							; add backtrack data for 5 minutes
	call	update_backtrack			; make it so
 ENDIF

	goto	menuview_toggle_reset		; and return...

divemode_option7:
	; Store heading for compass view
	movff	compass_heading_shown+0,compass_bearing+0
	movff	compass_heading_shown+1,compass_bearing+1
	bsf		compass_bearing_set			; set flag
	goto	menuview_toggle_reset		; and return...

divemode_option8:
	bsf		alternative_divelayout		; set flag for alternative layout mode
	call	menuview_toggle_reset		; terminate the pre-menu
	call	TFT_ClearScreen				; clear the whole screen
	bsf		FLAG_TFT_divemode_mask_alt	; set flag to draw the alternative mask
	movff	menupos3,customview_divemode; back-up the custom view shown in normal layout
	clrf	menupos3					; select the default alternative layout
	call	customview_mask_alternative ; draw   the default alternative layout
	return								; done


divemode_simulator_check_limits:
	; check limits (150m and 0m)
	movlw	LOW  d'16000'				; compare to 16 bar = 16000 mbar (150m)
	subwf	sim_pressure+0,W
	movlw	HIGH d'16000'
	subwfb	sim_pressure+1,W
	bnc		divemode_simulator_check_limits2 ; no carry = borrow = not deeper

	; too deep, limit to 150m
	movlw	LOW  d'16000'
	movwf	sim_pressure+0
	movlw	HIGH d'16000'
	movwf	sim_pressure+1
	return

divemode_simulator_check_limits2:
	movlw	LOW  d'1000'				; compare to 1 bar == 0m == 1000 mbar
	subwf	sim_pressure+0,W
	movlw	HIGH d'1000'
	subwfb	sim_pressure+1,W
	btfsc	STATUS,C					; no carry = borrow = not deeper
	return								; deeper than 0 m == ok
	; too shallow, limit to 0m
	movlw	LOW  d'1000'
	movwf	sim_pressure+0
	movlw	HIGH d'1000'
	movwf	sim_pressure+1
	return

;=============================================================================
; Find the best gas and diluent for the current depth
; and check if a gas/diluent change is to be advised.
;
; Output: best_gas_number      : number of best gas, 0= none avail, 255= not computed
;         best_dil_number      : number of best dil, 0= none avail, 255= not computed
;         better_gas_available : flag indicating if a change is advised
;         better_dil_available : flag indicating if a change is advised
;
;
; in CCR and pSCR mode: - checks both, gases and diluents for respective best gas / best diluent
;                       - if not in bailout, sets better_dil_available on diluents
;                       - if     in bailout, sets better_gas_available on OC gases
;
; in OC mode          : - checks only gases for best gas
;                       - sets better_gas_available on OC gases
;
check_gas_best:
	movff	amb_press_10+0,xA+0				; copy ambient pressure / 10 into xA:2, will be used by ppO2 min/max checks later
	movff	amb_press_10+1,xA+1				; ...
	; set maximum ppO2 allowed
	movff	char_I_ppO2_max,ppO2_max		; max ppO2 for working phase (default)
	movff	char_O_deco_info,lo				; bank-safe copy of deco info vector
	btfsc	lo,deco_flag					; is the ppo2 deco limit enabled?
	movff	char_I_ppO2_max_deco,ppO2_max	; YES - replace by max ppO2 for deco phase
	; check dive mode
	btfsc	FLAG_oc_mode					; in OC mode?
	bra		check_gas_best_gas				; YES - skip diluents, check for best gas only

check_gas_best_dil:
	; set minimum ppO2 required
	movff	char_I_ppO2_min,WREG			; min ppO2 for pure diluent in CCR mode (default)
	btfsc	FLAG_pscr_mode					; in pSCR mode?
	movff	char_I_ppO2_min_loop,ppO2_min	; YES - replace by min ppO2 for pure diluent in pSCR mode
	; preset results to nothing found
	clrf	best_gas_num					; initialize best diluent as 0 = nothing found yet
	bcf		better_dil_available			; =1: a better diluent is available and a gas change is advised in divemode
;	; current diluent = 'gas6' ?
;	movlw	.6								;
;	cpfseq	active_dil						; using 'gas6' as current diluent?
;	bra		check_gas_best_dil0				; NO  - continue
;	bra		check_gas_best_dil3				; YES - suppress better diluent search in this case
;check_gas_best_dil0:
	; check all diluents
	lfsr	FSR1,opt_dil_O2_ratio			; set base address for diluent arrays
	movff	active_dil,lo					; number of currently used diluent
	setf	best_gas_depth					; initialize change depth of best dil found so far to 255 meter
; original code
	clrf	check_gas_num
	incf	check_gas_num,F
	rcall	check_gas_best_common			; check diluent 1
	incf	check_gas_num,F
	rcall	check_gas_best_common			; check diluent 2
	incf	check_gas_num,F
	rcall	check_gas_best_common			; check diluent 3
	incf	check_gas_num,F
	rcall	check_gas_best_common			; check diluent 4
	incf	check_gas_num,F
	rcall	check_gas_best_common			; check diluent 5
; alternative code
;	movlw	.5
;	movwf	check_gas_num
;check_gas_best_dil_loop:
;	rcall	check_gas_best_common
;	decfsz	check_gas_num
;	bra		check_gas_best_dil_loop
;
	; store result
	movff	best_gas_num,best_dil_number	; store new best diluent found (1-5 or 0 of no usable diluent available)
	; check if change advices shall be given in general
	btfsc	FLAG_bailout_mode				; in bailout?
	bra		check_gas_best_gas				; YES - no better diluent advice when in bailout
check_gas_best_dil1:
	; check if a change advice shall be given right now
	movf	best_dil_number,W				; load number of best diluent into WREG (1-5)
	bz		check_gas_best_dil3				; has a best diluent been found at all?  NO - nothing to signal for
	cpfseq	active_dil						; is this the currently used diluent?
	bra		check_gas_best_dil2				; NO
	bra		check_gas_best_dil3				; YES - no need to signal a better diluent if this diluent is already in use
check_gas_best_dil2:
	btfsc	setpoint_fallback				; is a fallback warning active?
	bra		check_gas_best_dil3				; YES - suppress better diluent prompt in this case
	; not using the best gas - show better diluent hint whenever a better diluent is available
	bsf		better_dil_available			; signal that a better diluent is available
	bsf		FLAG_TFT_active_gas_divemode	; redraw gas/setpoint/diluent
check_gas_best_dil3:
	btfss	better_dil_available			; shall a better diluent be signaled for?
	bcf		blinking_better_dil				; NO  - clear blinking flag
	; continue with checking for best bailout gas

check_gas_best_gas:
	; set minimum ppO2 required
	movff	char_I_ppO2_min,ppO2_min		; min ppO2 for OC/Bailout
	; preset results to nothing found
	clrf	best_gas_num					; initialize best gas as 0 = nothing found yet
	bcf		better_gas_available			; =1: a better gas is available and a gas change is advised in divemode
;	; current gas = 'gas6' ?
;	movlw	.6								;
;	cpfseq	active_gas						; using 'gas6' as current gas?
;	bra		check_gas_best_gas0				; NO  - continue
;	bra		check_gas_best_gas3				; YES - suppress better gas search in this case
;check_gas_best_gas0:
	; check all gases
	lfsr	FSR1,opt_gas_O2_ratio			; set base address for gas arrays
	movff	active_gas,lo					; number of currently used gas
	setf	best_gas_depth					; initialize change depth of best gas found so far to 255 meter
; original code
	clrf	check_gas_num
	incf	check_gas_num,F
	rcall	check_gas_best_common			; check gas 1
	incf	check_gas_num,F
	rcall	check_gas_best_common			; check gas 2
	incf	check_gas_num,F
	rcall	check_gas_best_common			; check gas 3
	incf	check_gas_num,F
	rcall	check_gas_best_common			; check gas 4
	incf	check_gas_num,F
	rcall	check_gas_best_common			; check gas 5
; alternative code
;	movlw	.5
;	movwf	check_gas_num
;check_gas_best_gas_loop:
;	rcall	check_gas_best_common
;	decfsz	check_gas_num
;	bra		check_gas_best_gas_loop
;
	; store result
	movff	best_gas_num,best_gas_number	; store new best gas found (1-5 or 0 of no usable gas available)
	; check if change advices shall be given in general
	btfsc	FLAG_oc_mode					; in OC mode?
	bra		check_gas_best_gas1				; YES
	btfsc	FLAG_bailout_mode				; in bailout?
	bra		check_gas_best_gas1				; YES
	return									; NO  - no better (OC) gas advice when not in OC or bailout mode
check_gas_best_gas1:						; check if we are already on the best gas
	; check if a change advice shall be given right now
	movf	best_gas_number,W				; load number of best gas into WREG (1-5)
	bz		check_gas_best_gas3				; has a best gas been found at all?  NO - nothing to signal for
	cpfseq	active_gas						; is this the currently used gas?
	bra		check_gas_best_gas2				; NO
	bra		check_gas_best_gas3				; YES - no need to signal a better gas if this gas is already in use
check_gas_best_gas2:
	; not using the best gas - show better gas hint whenever a better gas is available
	bsf		better_gas_available			; YES - signal that a better gas is available
	bsf		FLAG_TFT_active_gas_divemode	; YES - redraw gas/setpoint/diluent
check_gas_best_gas3:
	btfss	better_gas_available			; shall a better gas be signaled for?
	bcf		blinking_better_gas				; NO - clear blinking flag
	return

check_gas_best_common:						; with gas to be checked in check_gas_num (1-5)
;											; and  current gas       in lo            (1-5)
	;
	; Memory Map:
	; ---------------------------------------------------------------------------------------
	; opt_gas_O2_ratio		res 5	; base address for gases
	; opt_dil_O2_ratio		res 5	; base address for diluents
	; opt_gas_He_ratio		res 5	; (not needed here)
	; opt_dil_He_ratio		res 5	; (not needed here)
	; opt_gas_type			res 5	; has offset of 20 bytes from base address for gases
	; opt_dil_type			res 5	; has offset of 20 bytes from base address for diluents
	; opt_gas_change		res 5	; has offset of 10 bytes from opt_gas_type
	; opt_dil_change		res 5	; has offset of 10 bytes from opt_dil_type

	; get gas data
	decf	check_gas_num,W					; (1-5) -> (0-4) into WREG to be used as index
	movff	PLUSW1,check_gas_O2_ratio		; load O2 ratio (%) of current gas/dil into check_gas_O2_ratio
	addlw	.20								; add offset of 20 bytes to index type in opt_gas_type/opt_dil_type
	movff	PLUSW1,check_gas_type			; load type of current gas/dil into check_gas_type (0=disabled, 1=first, 2=travel/normal, 3=deco/-)
	addlw	.10								; add offset of 10 bytes to index change depth in opt_gas_change/opt_dil_change
	movff	PLUSW1,check_gas_depth			; load change depth of current gas/dil into check_gas_depth
	; check if gas is usable (i.e. not disabled)
	tstfsz	check_gas_type					; type = disabled (0)?
	bra		check_gas_best_common0			; NO  - continue checks
	movf	check_gas_num,W					; YES - get the number of the gas to be checked (1-5)
	cpfseq	lo								;     - is this the currently used gas?
	return									;       NO  - skip disabled gases which are not the current gas
	bra		check_gas_best_common1			;       YES - a gas in use overrides it's disabled status, therefore treat it as available
check_gas_best_common0:
	; skip deco gases (type=3) if not in deco mode, but search among all enabled gases when in loop or bailout mode
	movlw	.3
	cpfseq	check_gas_type					; type = deco (3)?
	bra		check_gas_best_common1			; NO  - proceed
	btfsc	FLAG_bailout_mode				; YES - in bailout?
	bra		check_gas_best_common1			;       YES - proceed, include deco gases
	movff	char_O_main_status,WREG			;       NO  - get main deco mode
	btfsc	WREG,DECO_MODE_LOOP_FLAG		;           - in loop mode?
	bra		check_gas_best_common1			;             YES - proceed, include deco gases
	movff	char_O_deco_info,WREG			;             NO  - get deco info vector
	btfss	WREG,deco_flag					;                 - in deco mode (deco_flag set), i.e. use of deco gases allowed?
	return									;                   NO  - skip deco gas while not in deco mode
check_gas_best_common1:						;                   YES - proceed
;	; check if gas change depth is below minimum change depth
;	movlw	minimum_change_depth			; for value see definition in hwos.inc
;	cpfsgt	check_gas_depth					; change depth of checked gas > minimum_change_depth?
;	return									; NO - change depth not deep enough, skip and check next gas
	; check if gas is usable, i.e. its change depth is below or equal to the current depth
	movf	curr_depth,W					; load current depth (in m) into WREG
	cpfslt	check_gas_depth					; change depth of checked gas < (shallower than) current depth?
	bra		check_gas_best_common2			; NO  - gas is usable
	return									; YES - gas is not usable
check_gas_best_common2:
	; check if this gas is the first best gas candidate
	movf	best_gas_num,W					; get best gas found so far (1-5) or 0 if none found yet
	tstfsz	WREG							; has a best gas candidate been found yet?
	bra		check_gas_best_common3			; YES - check if the new one is better than the one we have so far
	bra		check_gas_best_common4			; NO  - no need to do the above mentioned check
check_gas_best_common3:
	; check if the change depth of the checked gas is < (shallower) than the change depth of the best gas found so far
	movf	best_gas_depth,W				; load change depth of best gas so far into WREG
	cpfslt	check_gas_depth					; change depth of checked gas < (shallower than) change depth of best gas so far?
	return									; NO - this gas is not better than the best already found
check_gas_best_common4:
	; check if the gas fits into the ppO2 limits
	movff	check_gas_O2_ratio,xB+0			; xB = O2 ratio, xA is still loaded with (p_amb / 10)
	clrf	xB+1
	call	mult16x16						; xC = O2 ratio * (p_amb / 10)
	; check for very high ppO2
	tstfsz	xC+2							; O2_ratio * p_amb / 10 > 65536, i.e. ppO2 > 6.55 bar ?
	return									; YES - gas is not usable
	btfsc	xC+1,7							; check if ppO2 > 3.30 bar
	return									; YES - gas is not usable
	; check for low ppO2
	movff	xC+0,sub_a+0
	movff	xC+1,sub_a+1
	movf	ppO2_min,W
	mullw	.100							; char_I_ppO2_min * 100
	movff	PRODL,sub_b+0
	movff	PRODH,sub_b+1
	call	subU16							; sub_c = sub_a - sub_b
	btfsc	neg_flag						; within limit?
	return									; NO - too low, gas is not usable
	; check for high ppO2
	movf	ppO2_max,W
	mullw	.100							; ppO2_max * 100
	movff	PRODL,sub_b+0
	movff	PRODH,sub_b+1
	infsnz	sub_b+0,F						; add 1 mbar to allowance to avoid exclusion on equal
	incf	sub_b+1,F
	call	subU16							; sub_c = sub_a - sub_b
	btfss	neg_flag						; within limit?
	return									; NO - too high, gas is not usable
	; we have a (new) best gas
	movff	check_gas_num,  best_gas_num	; set checked gas (1-5) as best gas
	movff	check_gas_depth,best_gas_depth	; memorize its change depth
	return


;=============================================================================
; Check for Auto-SP
;
check_dive_autosp:						; check for Auto-SP
	movff	opt_ccr_mode,WREG			; =0: Fixed SP, =1: Sensor, =2: Auto SP
	sublw	.2							; opt_ccr_mode = 2 (Auto SP)?
	bz		check_dive_autosp2			; YES - check
	return								; NO  - return for sensor or fixed mode
check_dive_autosp2:
	; Check SP2
	btfsc	sp2_switched				; SP 2 used so far?
	bra		check_dive_autosp3			; YES - continue with SP 3
	movff	char_I_setpoint_change+1,lo	; NO  - get depth in m
	tstfsz	lo							;     - SP change depth = 0 ?
	bra		check_dive_autosp2a			;       NO  - continue
	bra		check_dive_autosp3			;       YES - continue with SP 3
check_dive_autosp2a:
	decf	lo,W						; SP change depth -1 -> WREG
	cpfsgt	curr_depth					; current depth > change depth - 1 ?
	bra		check_dive_autosp3			; NO  - continue with SP 3
	; auto switch to SP2
	movff	char_I_setpoint_cbar+1,char_I_const_ppO2 ; YES - use SP
	rcall	xmit_sp_set_flag			;     - send SP to external devices
	bsf		sp2_switched				;     - set SP 2 used flag
check_dive_autosp3:
	; Check SP3
	btfsc	sp3_switched				; SP 3 used so far?
	bra		check_dive_autosp4			; YES - continue with SP 4
	movff	char_I_setpoint_change+2,lo	; NO  - get depth in m
	tstfsz	lo							;     - SP change depth = 0 ?
	bra		check_dive_autosp3a			;       NO  - continue
	bra		check_dive_autosp4			;       YES - continue with SP 4
check_dive_autosp3a:
	decf	lo,W						; SP change depth -1 -> WREG
	cpfsgt	curr_depth					; current depth > change depth - 1 ?
	bra		check_dive_autosp4			; NO  - continue with SP 4
	; auto switch to SP3
	movff	char_I_setpoint_cbar+2,char_I_const_ppO2 ; YES - use SP
	rcall	xmit_sp_set_flag			;     - send SP to external devices
	bsf		sp3_switched				;     - set SP 3 used flag
check_dive_autosp4:
	; Check SP4
	btfsc	sp4_switched				; SP 4 used so far?
	bra		check_dive_autosp5			; YES - continue with SP 5
	movff	char_I_setpoint_change+3,lo ; NO  - get depth in m
	tstfsz	lo							;     - SP change depth = 0 ?
	bra		check_dive_autosp4a			;       NO  - continue
	bra		check_dive_autosp5			;        YES - continue with SP 5
check_dive_autosp4a:
	decf	lo,W						; SP change depth -1 -> WREG
	cpfsgt	curr_depth					; current depth > change depth - 1 ?
	bra		check_dive_autosp5			; NO  - continue with SP 5
	; auto switch to SP4
	movff	char_I_setpoint_cbar+3,char_I_const_ppO2 ; YES - use SP
	rcall	xmit_sp_set_flag			;     - send SP to external devices
	bsf		sp4_switched				;     - set SP 4 used flag
check_dive_autosp5:
	; Check SP5
	btfsc	sp5_switched				; SP 5 used so far?
	bra		check_dive_autosp6			; YES - done
	movff	char_I_setpoint_change+4,lo	; NO  - get depth in m
	tstfsz	lo							;     - SP change depth = 0 ?
	bra		check_dive_autosp5a			;       NO  - continue
	bra		check_dive_autosp6			;       YES - done
check_dive_autosp5a:
	decf	lo,W						; SP change depth -1 -> WREG
	cpfsgt	curr_depth					; current depth > change depth - 1 ?
	bra		check_dive_autosp6			; NO  - done
	; auto switch to SP5
	movff	char_I_setpoint_cbar+4,char_I_const_ppO2 ; YES - use SP
	rcall	xmit_sp_set_flag			;     - send SP to external devices
	bsf		sp5_switched				;     - set SP 5 used flag
check_dive_autosp6:
	return

xmit_sp_set_flag:
	movff	char_I_const_ppO2,WREG
	call	transmit_setpoint			; transmit current setpoint from WREG (in cbar) to external electronics
	bsf		setpoint_changed			; set flag (for profile)
	bsf		event_occured				; set event flag
	return

set_logbook_marker:
	bcf		FLAG_set_marker				; clear flag
	movlw	d'6'						; set type of alarm (manual marker)
	movwf	AlarmType					; copy to alarm register
	bsf		event_occured				; set event flag
	return

;=============================================================================
; Setup everything to enter dive mode
;
	global	dive_boot_oc_bail
dive_boot_oc_bail:
	; copy opt_gas_types into backup (for "lost gas" feature)
	movff	opt_gas_type+0,opt_gas_type_backup+0		; 0=Disabled, 1=First, 2=Travel, 3=Deco
	movff	opt_gas_type+1,opt_gas_type_backup+1		; 0=Disabled, 1=First, 2=Travel, 3=Deco
	movff	opt_gas_type+2,opt_gas_type_backup+2		; 0=Disabled, 1=First, 2=Travel, 3=Deco
	movff	opt_gas_type+3,opt_gas_type_backup+3		; 0=Disabled, 1=First, 2=Travel, 3=Deco
	movff	opt_gas_type+4,opt_gas_type_backup+4		; 0=Disabled, 1=First, 2=Travel, 3=Deco
	; done
	return

	global	dive_boot_oc
dive_boot_oc:
	; set-up registers
	rcall	get_first_gas_to_WREG		; get first gas (1-5) into WREG
	rcall	setup_gas_registers			; set-up of gas parameters of currently breathed gas (with WREG = gas 1-5)
	rcall	deco_setup_oc_gases			; set-up of gas list for deco calculations (with WREG = gas 1-5)
	return

	global	dive_boot_cc
dive_boot_cc:
	; copy opt_dil_types into backup (for "lost diluent" feature)
	movff	opt_dil_type+0,opt_dil_type_backup+0		; 0=Disabled, 1=First, 2=Normal
	movff	opt_dil_type+1,opt_dil_type_backup+1		; 0=Disabled, 1=First, 2=Normal
	movff	opt_dil_type+2,opt_dil_type_backup+2		; 0=Disabled, 1=First, 2=Normal
	movff	opt_dil_type+3,opt_dil_type_backup+3		; 0=Disabled, 1=First, 2=Normal
	movff	opt_dil_type+4,opt_dil_type_backup+4		; 0=Disabled, 1=First, 2=Normal
	; clear flags
	bcf		FLAG_bailout_mode			; =1: bailout
	bcf		setpoint_fallback			; =1: fallback to SP1 due to external O2 sensor failure
	; set-up registers
	rcall	get_first_dil_to_WREG		; get first diluent (1-5) into WREG
	rcall	setup_dil_registers			; set-up of diluent parameters for currently breathed diluent (with WREG = current diluent 1-5)
	rcall	deco_setup_cc_diluents		; set-up of diluent list for deco calculations (with WREG = current diluent 1-5)
	; done
	return

dive_boot_cc_part2:
	; revoke sensors from usage if they do not have a valid calibration
	bsf		use_O2_sensor1
	bsf		use_O2_sensor2
	bsf		use_O2_sensor3
	btfss	sensor1_calibrated_ok
	bcf		use_O2_sensor1
	btfss	sensor2_calibrated_ok
	bcf		use_O2_sensor2
	btfss	sensor3_calibrated_ok
	bcf		use_O2_sensor3
	; check for external HUD/ppO2 Monitor
	btfss	optical_input				; do we have an optical input?
	bra		dive_boot_cc_part2_1		; NO
	; copy (initial) valid flags from HUD/ppO2 Monitor
	btfsc	sensor1_active
	bsf		use_O2_sensor1
	btfsc	sensor2_active
	bsf		use_O2_sensor2
	btfsc	sensor3_active
	bsf		use_O2_sensor3
dive_boot_cc_part2_1:
	; In pSCR mode, only settings 0 (calculated ppO2) and 1 (ppO2 from sensors) are defined.
	; In case we still have 3 (auto SP) selected out of previous CCR mode, we reset to 0.
	btfss	FLAG_pscr_mode
	bra		dive_boot_cc_part2_2
	movff	opt_ccr_mode,WREG			; =0: Fixed SP (CCR) / calculated SP (pSCR), =1: Sensor, =2: Auto SP
	sublw	.2							; opt_ccr_mode = 1 (Auto SP)?
	bnz		dive_boot_cc_part2_2
	movlw	.0
	movff	WREG,opt_ccr_mode
dive_boot_cc_part2_2:
	bsf		setpoint_changed			; set flag (for profile)
	bcf		sp2_switched				; =1: this setpoint has been auto-selected already
	bcf		sp3_switched				; =1: this setpoint has been auto-selected already
	bcf		sp4_switched				; =1: this setpoint has been auto-selected already
	bcf		sp5_switched				; =1: this setpoint has been auto-selected already
	; Start with SP1 (CCR) or 0 (pSCR) as default.
	; If in sensor mode, this value will be overwritten by calc_deko_divemode_sensor
	clrf	WREG						; preload WREG with setpoint value 0 for pSCR calculated
	btfsc	FLAG_ccr_mode				; are we in CCR mode?
	movff	char_I_setpoint_cbar+0,WREG	; YES - get value of setpoint 1
	movff	WREG,char_I_const_ppO2		; write setpoint to deco engine
	call	transmit_setpoint			; transmit current setpoint from WREG (in cbar) to external electronics
	goto	calc_deko_divemode_sensor	; read & process sensor data (and return)


diveloop_boot:

	; do the basic initialization
	call	restart_set_modes_and_flags

	; stop accelerometer and compass
	call	I2C_sleep_accelerometer
	call	I2C_sleep_compass

	; reset max pressure aka max depth
	clrf	WREG
	movff	WREG,max_pressure+0	
	movff	WREG,max_pressure+1

	; initialize press needs to zero and invalid (not yet computed) state
	clrf	WREG						; set WREG to 0
 IFDEF _cave_mode
	movff	WREG,char_I_backtrack_time	; clear backtracking time (index to char_I_backtrack_depth)
	movff	WREG,char_I_backtrack_depth	; prime first entry with depth 0
 ENDIF
	bsf		WREG,int_is_zero			; set zero flag
	bsf		WREG,int_invalid_flag		; set invalid flag (additionally)
	banksel	int_O_ascent_pres_need		; select bank with shared output vars
	movwf	int_O_ascent_pres_need+1	; Set flags for tank pressure needs = 0 before p2_deco.c
	movwf	int_O_ascent_pres_need+3	; can do it. If this is not done here and the gas needs
	movwf	int_O_ascent_pres_need+5	; custom view is shown before p2_deco.c completes the first
	movwf	int_O_ascent_pres_need+7	; deco calculation, some rubbish numbers from last dive or
	movwf	int_O_ascent_pres_need+9	; simulation may be shown
	banksel	common						; back to bank common

	; configure the deco engine
	clrf	hi
	bsf		hi,DECO_Z_FACTOR_FLAG		; enable Z factor mode by default
	TSTOSS	opt_ZfactorUse				; shall use Z factor mode?
	bcf		hi,DECO_Z_FACTOR_FLAG		; NO - disable again
 IFDEF _rx_functions
	bsf		hi,DECO_TR_FUNCTIONS		; enable TR mode by default
	btfss	FLAG_tr_enabled				; shall use TR mode?
	bcf		hi,DECO_TR_FUNCTIONS		; NO - disable again
 ENDIF
	movff	hi,char_O_main_status		; bank-safe copy to deco engine

	movff	char_O_deco_status,lo		; bank-safe read
	bsf		lo,DECO_STATUS_0_FLAG		; set init-  | ATTENTION: The deco engine must be started in init state! If omitted, it may
	bsf		lo,DECO_STATUS_1_FLAG		;     state, |            enter an infinite loop at some point in time and brick the OSTC!
	bcf		lo,DECO_PLAN_FLAG			; normal plan mode,
	bcf		lo,DECO_VOLUME_FLAG			; disable gas volume calculation, and
	bcf		lo,DECO_ASCENT_FLAG			; disable delayed ascent calculation
	movff	lo,char_O_deco_status		; bank-safe copy back to deco engine

	clrf	WREG
	movff	WREG,char_O_deco_warnings	; clear any deco warnings remaining from last dive
	movff	WREG,char_O_deco_info		; clear any deco infos    remaining from last dive

	movlw	deco_distance				; load distance between actual depth and depth used for deco calculation
	movff	WREG,char_I_deco_distance	; write distance to the deco engine

	movff	opt_last_stop,char_I_depth_last_deco	; write last stop depth to deco engine
	movff	opt_GF_low,char_I_GF_Low_percentage		; write GF low  to deco engine
	movff	opt_GF_high,char_I_GF_High_percentage	; write GF high to deco engine

	bcf		onesectoggle				; clear toggle bit for calculation phasing
	bcf		use_agf						; start with normal GF set
	bcf		divemode_menu				; clear dive mode menu flag
	bcf		alternative_divelayout		; start with default layout
	bcf		blinking_depth_prev			; clear flag for blinking depth
	bcf		blinking_depth_toggle		; clear flag for blinking depth
	bcf		blinking_depth_warning		; clear flag for blinking depth as warning
	bcf		blinking_depth_attention	; clear flag for blinking depth as attention
	bcf		max_depth_greater_100m		; clear flag for last max/avg depth was > 100 m

	movlw	d'1'
	movwf	apnoe_max_pressure+0
	clrf	apnoe_max_pressure+1
;	clrf	apnoe_surface_mins
;	clrf	apnoe_surface_secs

	; copy date and time for logbook
	movff	year,start_year
	movff	month,start_month
	movff	day,start_day
	movff	hours,start_hours
	movff	mins,start_mins

	movff	int_O_CNS_fraction+0,CNS_start+0 ; save CNS value at beginning of dive
	movff	int_O_CNS_fraction+1,WREG		 ; get high byte to WREG
	bcf		WREG,int_warning_flag			 ; clear warning   flag
	bcf		WREG,int_attention_flag			 ; clear attention flag
	movff	WREG,CNS_start+1				 ; move high byte on
	movff	int_O_gradient_factor+0,GF_start ; save GF value at beginning of dive (only lower byte used for value)

	bcf		no_more_divesecs			 ; =1: do no longer show seconds in dive mode
	bcf		divemode_menu_active
	clrf	menupos1
	clrf	menupos2					 ; reset to zero (Zero=no pre-menu or simulator task)
	bsf		sensors_agree				 ; init of sensors disagree warning system

	bcf		show_safety_stop			; =1: show the safety stop
	clrf	safety_stop_countdown		; clear count-down

	clrf	samplesecs					; timer for data logging
	clrf	apnoe_timeout_counter		; timeout in minutes
	clrf	timeout_counter1+0			; takes care of the timeout (low  byte)
	clrf	timeout_counter1+1			; takes care of the timeout (high byte)
	clrf	AlarmType					; Clear all alarms
	bcf		event_occured				; clear flag
	clrf	average_divesecs_total+0	; clear non-resettable time accumulator
	clrf	average_divesecs_total+1
	clrf	average_depth_hold_total+0	; clear non-resettable average depth
	clrf	average_depth_hold_total+1
	clrf	average_depth_hold_total+2
	clrf	average_depth_hold_total+3
	call	reset_average				; reset the resettable average depth

 IFDEF _rx_functions
	btfss	FLAG_tr_enabled				; TR functions enabled?
	bra		diveloop_boot_0				; NO  - skip TR function initialization
										; YES - initialize TR function variables
	banksel	int_O_sac_rate
	clrf	int_O_sac_rate+0			; clear low byte      of SAC rate
	clrf	int_O_pressure_need+0		; clear low byte      of 1st pressure need    value
	clrf	int_O_pressure_need+2		; clear low byte      of 2nd pressure need    value
	banksel	int_IO_pressure_value
	clrf	int_IO_pressure_value+0		; clear low byte      of 1st pressure reading value
	clrf	int_IO_pressure_value+2		; clear low byte      of 2nd pressure reading value
	clrf	int_I_pressure_drop+0		; clear low byte      of 1st pressure drop    value
	clrf	int_I_pressure_drop+2		; clear low byte      of 2nd pressure drop    value
	clrf	char_I_pressure_gas+0		; clear gas selection of 1st pressure reading
	clrf	char_I_pressure_gas+1		; clear gas selection of 2nd pressure reading
	clrf	char_I_pressure_age+0		; clear age           of 1st pressure reading
	clrf	char_I_pressure_age+1		; clear age           of 2nd pressure reading
	clrf	char_I_pressure_stat+0		; clear status        of 1st pressure reading
	clrf	char_I_pressure_stat+1		; clear status        of 2nd pressure reading
	clrf	WREG						; clear WREG
	bsf		WREG,int_not_avail_flag		; set   WREG to coding for integer numbers -> data not available
	banksel	int_O_sac_rate
	movwf	int_O_sac_rate+1			; copy to high byte     of SAC rate
	movwf	int_O_pressure_need+1		; copy to high byte     of 1st pressure need    value
	movwf	int_O_pressure_need+3		; copy to high byte     of 1st pressure need    value
	banksel	int_IO_pressure_value
	movwf	int_IO_pressure_value+1		; copy to high byte     of 1st pressure reading value
	movwf	int_IO_pressure_value+3		; copy to high byte     of 2nd pressure reading value
	movwf	int_I_pressure_drop+1		; copy to high byte     of 1st pressure drop    value
	movwf	int_I_pressure_drop+3		; copy to high byte     of 1st pressure drop    value
	banksel	gas__last_1st				; select bank with vars for pressure drop calculation
	setf	gas__last_1st				; invalidate last gas of 1st reading
	setf	gas__last_2nd				; invalidate last gas of  2nd reading
	banksel	common						; back to bank common
 ENDIF

diveloop_boot_0:
	bcf		decostop_active				; clear flag for being in deco
	setf	best_gas_number				; initialize best gas     as not computed yet (255)
	setf	best_dil_number				; initialize best diluent as not computed yet (255)
	bcf		better_gas_available		; =1: a better gas     is available and a gas change is advised
	bcf		better_dil_available		; =1: a better diluent is available and a gas change is advised

	rcall	dive_boot_oc_bail			; basic settings required for all modes

	btfsc	FLAG_oc_mode				; in OC mode?
	rcall	dive_boot_oc				; YES - add OC mode settings

	btfsc	FLAG_ccr_mode				; in CCR mode?
	rcall	dive_boot_cc				; YES - add CC mode settings
	btfsc	FLAG_ccr_mode				; in CCR mode?
	rcall	dive_boot_cc_part2			; YES - add CC sensor and SP settings

	btfsc	FLAG_pscr_mode				; in pSCR mode?
	rcall	dive_boot_cc				; YES - add CC mode settings
	btfsc	FLAG_pscr_mode				; in pSCR mode?
	rcall	dive_boot_cc_part2			; YES - add CC sensor and SP settings

	call	ghostwriter_short_header	; write short header with dive number into profile memory

	btfsc	simulatormode_active
	bra		diveloop_boot_1

	; normal mode = surface pressure is the pressure 30 minutes before dive
	SAFE_2BYTE_COPY last_surfpressure_30min, int_I_pres_surface	;copy surface pressure to deco routine
	SAFE_2BYTE_COPY last_surfpressure_30min, last_surfpressure	;copy surface pressure to last_surfpressure for correct depth
	bra		diveloop_boot_2

diveloop_boot_1:
	; simulator mode: set surface pressure to 1 bar because simulated depths are also based on 1 bar surface pressure
	movlw	LOW  .1000
	movff	WREG,int_I_pres_surface+0	; LOW  copy surface pressure to deco routine
	movlw	HIGH .1000
	movff	WREG,int_I_pres_surface+1	; HIGH copy surface pressure to deco routine

diveloop_boot_2:
	SAFE_2BYTE_COPY temperature,minimum_temperature ; reset minimum temperature registers

	call	init_recording_params		; set up all the divisors

	bsf		FLAG_diluent_setup			; for CCR mode (required to have better gas working)
	btfsc	FLAG_ccr_mode				; =1: CCR mode (fixed ppO2 or Sensor) active
	bra		diveloop_boot_3
	btfsc	FLAG_pscr_mode
	bra		diveloop_boot_3
	bcf		FLAG_diluent_setup			; for OC mode (required to have better gas working)

diveloop_boot_3:
	bcf		LEDg						; switch off green LED / release reset to RX circuitry
	bcf		LEDr						; switch off red   LED
	bcf		realdive
	btfss	simulatormode_active		; in simulator mode?
	call	disable_rs232				; NO - disable RS232

 IFDEF _screendump
	btfsc	enable_screen_dumps			; =1: ignore vin_usb, wait for "l" command (screen dump)
	call	enable_rs232				; also sets to speed_normal
 ENDIF

	; reset dive time seconds
;	movlw	.2							; start at 2 seconds
;	movwf	total_divetime_seconds+0
;	clrf	total_divetime_seconds+1
;	movwf	divesecs
;	movwf	apnoe_secs
;	bsf		divemode2					; displayed dive time is running (dive time starts HERE)

	; clear the timers (start dive times at zero)
	clrf	total_divetime_seconds+0
	clrf	total_divetime_seconds+1
	clrf	divesecs
	clrf	divemins+0
	clrf	divemins+1
	clrf	apnoe_secs
	clrf	apnoe_mins

	; divemode2 flag will be set by pressure & timeout evaluation in function set_dive_modes

	return								; done with dive mode boot


;=============================================================================

divemode_check_for_warnings:
	movlw	.1							; one message at a time in alternative layout
	btfss	alternative_divelayout
	movlw	.2							; two messages at a time in default layout
	cpfsgt	message_counter				; only one (or two) messages active?
	bra		divemode_check_for_warnings1; YES - update every second

	btfss	secs,0						; every two seconds...
	return
	btfss	secs,1						; every four seconds...
	return

divemode_check_for_warnings1:
	bcf		message_advice				; clear flag for messages of level advice
	bcf		message_attention			; clear flag for messages of level attention
	bcf		message_warning				; clear flag for messages of level warning
	clrf	message_counter				; clear message counter

	; messages sorted by severity: highest severity warnings first, then attentions, advices and last info

	; warnings for all modes
	call	check_warn_battery			; check if the battery level should be displayed/warned
	call	check_divetimeout			; check and show the dive mode timeout (not actually a warning)

	btfsc	FLAG_apnoe_mode				; in Apnoe mode?
	bra		divemode_check_for_warnings2; YES
	btfsc	FLAG_gauge_mode				; in gauge mode?
	bra		divemode_check_for_warnings2; YES

	; warnings applicable only in deco modes
	rcall	check_ppO2					; check ppO2 and displays warning, if required

	btfss	sensors_agree				; are the sensor values within the threshold range?
	rcall	check_warn_sensors_disagree	; NO  - further evaluate
	btfsc	sensors_agree				; are the sensor values within the threshold range?
	bcf		sensor_warning				; YES - revoke memorized sensor warning

	rcall	check_outside				; check of ZHL16 model violation

	rcall	check_IBCD					; check for IBCD attention or warning

	rcall	check_OC_gas_avail			; check if a breathable OC gas is available

	btfsc	decostop_active				; in deco mode?
	rcall	check_and_store_gf_violation; YES - sets warnings, if required

	rcall	check_mbubbles				; check for micro bubbles

	rcall	check_cns_violation			; Check CNS value and display it, if required

	rcall	check_gas_needs_ascent		; show gas needs warning if any gas need for ascent is > threshold

	rcall	check_eod_cns_violation		; check CNS values for end-of-dive and display warning, if required

	rcall	check_display_ftts			; show @+x time

 IFDEF _cave_mode
	btfsc	FLAG_cave_mode				; cave mode enabled?
	rcall	check_cavemode				; YES - check cave mode status
 ENDIF

	btfsc	use_agf						; in aGF mode?
	rcall	warn_agf					; YES - show memo

	btfsc	setpoint_fallback			; fallback to SP1 due to external O2 sensor failure?
	rcall	warn_fallback				; YES - show a warning

	btfsc	better_dil_available		; is a better diluent available?
	rcall	advice_gas_change			; YES - display an advice
	btfsc	better_gas_available		; is a better gas     available?
	rcall	advice_gas_change			; YES - display an advice

divemode_check_for_warnings2:
 IFDEF _rx_functions
	btfss	FLAG_tr_enabled					; TR functions enabled?
	bra		divemode_check_for_warnings3	; NO  - skip
	call	check_tr_functions				; YES - check transmitter functions
	call	check_tr_messages				;     - check SAC attention and switch advice
 ENDIF

divemode_check_for_warnings3:
	; Display the attention or warning icon?
	btfsc	message_advice					; any message of level advice?
	bsf		FLAG_TFT_divemode_warning		; YES
	btfsc	message_attention				; any message of level attention?
	bsf		FLAG_TFT_divemode_warning		; YES
	btfsc	message_warning					; any message of level warning?
	bsf		FLAG_TFT_divemode_warning		; YES
	btfss	FLAG_TFT_divemode_warning		; any message of above levels?
	bsf		FLAG_TFT_divemode_warning_clear ; NO - clear warning icon

	; Setup message page number
	incf	message_page,F
	movf	message_page,W
	bcf		STATUS,C
	btfss	alternative_divelayout			; in alternative layout?
	rlcf	message_page,W					; NO - *2
	cpfsgt	message_counter					; > message_counter?
	clrf	message_page					; NO - clear

	; Clear both rows of messages if there is nothing to show at all
	tstfsz	message_counter					; any messages?
	bra		divemode_check_for_warnings4	; YES - look if second row needs to be cleared
	bsf		FLAG_TFT_dive_warning_text_clear; set flag
	return

divemode_check_for_warnings4:
	; Clear 2nd row of messages if there is nothing to show (on this page)
	btfss	second_row_warning				; =1: the second row contains a warning
	bsf		FLAG_TFT_dive_warning_text_clr2	; set flag for 2nd row
	return									; done

	global	check_warn_battery
check_warn_battery:
	movff	batt_percent,lo
	movlw	battery_show_level+1
	cpfslt	lo							; battery percentage ok?
	return								; YES - no display, no warning
	; Display Battery, but warn?
	movff	batt_percent,lo
	movlw	color_code_battery_low+1
	cpfsgt	lo							; battery percent below warning threshold?
	bsf		message_warning				; YES - set warning flag
	btfsc	alternative_divelayout		; in alternative layout?
	bra		check_warn_battery2			; YES - show warning
	movlw	index_clock_batt_surfpress	; NO  - index of custom view clock, battery and surface pressure
	cpfseq	menupos3					;     - battery shown in custom view?
	bra		check_warn_battery2			;       NO  - show warning
	return								;       YES - do not show twice (in custom view and in message area)
check_warn_battery2:
	incf	message_counter,F			;       increase counter
	goto	TFT_update_batt_percent_divemode ;  show percent (and return)

check_divetimeout:
	btfsc	divemode2					; dive time running?
	return								; YES - do nothing
	incf	message_counter,F			; increase counter
	goto	TFT_divetimeout				; show timeout counter (and return)

check_ppO2:
	btfsc	FLAG_oc_mode				; are we in OC mode?
	bra		check_ppO2_1				; YES - continue with breathed gas
	btfsc	FLAG_bailout_mode			; NO  - in bailout?
	bra		check_ppO2_1				;       YES - continue with breathed gas
	; CCR / pSCR mode - checks on pure diluent
	movff	int_O_pure_ppO2+0,lo		; get value and attention/warning flags for the pure diluent
	movff	int_O_pure_ppO2+1,hi		;
	btfsc	hi,int_warning_flag			; ppO2 of the pure diluent to low or high?
	rcall	check_ppO2_dw				; YES - show warning and return on next line
	btfsc	hi,int_attention_flag		; ppO2 of the pure diluent in attention state?
	rcall	check_ppO2_da				; YES - show attention and return on next line
	; all modes - checks on breathed gas (OC or from loop)
check_ppO2_1:
	movff	int_O_breathed_ppO2+0,lo	; get value and attention/warning flags for the breathed gas
	movff	int_O_breathed_ppO2+1,hi	; get warnings for breathed gas
	btfsc	hi,int_attention_flag		; breathed ppO2 in attention state (when in loop mode, no attention will be generated)?
	bra		check_ppo2_display_a		; YES - set attention flag and show ppO2
	btfsc	hi,int_low_flag				; breathed ppO2 to low?
	bra		check_ppO2_low				; YES - record the warning and show ppO2
	btfsc	hi,int_high_flag			; breathed ppO2 to high?
	bra		check_ppO2_high				; YES - record the warning and show ppO2
	TSTOSS	opt_showppo2				; show ppO2 anyhow? (0 = no, 1 = show always)
	return								; NO  - no warnings, no show - done
	bra		check_ppO2_common_2			; YES - but only when in OC or bailout...
check_ppO2_low:
	movlw	d'4'						; set type of alarm (ppO2 low)
	bra		check_ppO2_common			; continue with common part
check_ppO2_high:
	movlw	d'5'						; set type of alarm (ppO2 high)
check_ppO2_common:
	movwf	AlarmType					; copy alarm type to alarm register
	bsf		event_occured				; set event   flag
	bsf		message_warning				; show warning sign
check_ppO2_common_2:
	btfsc	FLAG_oc_mode				; are we in OC mode?
	bra		check_ppo2_display			; YES
	btfsc	FLAG_bailout_mode			; are we in bailout mode?
	bra		check_ppo2_display			; YES
	return								; NO  - in loop mode, ppO2 is already shown via setpoint display
check_ppo2_display_a:
	bsf		message_attention			; show attention sign
check_ppo2_display:
	btfsc	alternative_divelayout		; in alternative layout?
	bra		check_ppO2_d				; YES - show warning
	movlw	index_ppo2_ead_end_cns		; NO  - index of custom view ppO2, EAD/END and CNS)
	cpfseq	menupos3					;       ppO2 shown?
	bra		check_ppO2_b				;       NO
	return								;       YES - do not show twice (in custom view and in warning area)
check_ppO2_b:
	movlw	index_pscr_info				; index of custom view with pSCR data
	cpfseq	menupos3					; ppO2 shown?
	bra		check_ppO2_d				; NO  - show warning
	return								; YES - do not show twice (in custom view and in warning area)
check_ppO2_dw:
	bsf		message_warning				; show warning sign
check_ppO2_da:
	bsf		message_attention			; show attention sign (no problem if a warning sign is set as well, as it will take priority)
check_ppO2_d:
	incf	message_counter,F			; increase counter
	goto	TFT_display_ppo2_warning	; show breathed gas or diluent ppO2 warning (and return)


check_display_ftts:
	movff	char_I_extra_time,lo		; get extra time
	tstfsz	lo							; extra time > 0 ?
	bra		check_display_ftts_1		; YES - continue checking bailout condition
	return								; NO  - done
check_display_ftts_1:
	btfsc	FLAG_bailout_mode			; in bailout mode?
	return								; YES - in bailout no fTTS will be computed, so nothing to display
	incf	message_counter,F			; NO  - increase counter
	goto	TFT_display_ftts			;     - show @+x time


	global	check_cns_violation
check_cns_violation:
	; Check if CNS should be displayed
	movff	int_O_CNS_fraction+1,WREG	; get high byte
	btfsc	WREG,int_warning_flag		; warning flag set?
	bra		check_cns_violation_1		; YES - issue warning
	btfsc	WREG,int_attention_flag		; NO  - attention flag set?
	bra		check_cns_violation_2		;       YES - issue attention
	return								;       NO  - done
check_cns_violation_1:
	bsf		message_warning				; show warning sign
check_cns_violation_2:
	bsf		message_attention			; show attention sign
	btfsc	alternative_divelayout		; in alternative layout?
	bra		check_cns_violation_4		; YES - show attention
	movlw	index_ppo2_ead_end_cns		; NO  - index of custom view ppO2, EAD/END and CNS
	cpfseq	menupos3					;     - CNS shown?
	bra		check_cns_violation_3		;       NO
	return								;       YES - do not show twice (in custom view and in warning area)
check_cns_violation_3:
	movlw	index_CNS					; index of custom view with CNS values
	cpfseq	menupos3					; CNS shown?
	bra		check_cns_violation_4		; NO
	return								; YES - do not show twice (in custom view and in warning area)
check_cns_violation_4:
	incf	message_counter,F			; increase counter
	goto	TFT_display_cns				; show CNS (and return)


	global	check_eod_cns_violation		; check end-of-dive CNS values
check_eod_cns_violation:
	movff	int_O_CNS_fraction+1,WREG	; get high-byte of current CNS value
	btfsc	WREG,int_warning_flag		; current CNS value in warning state?
	return								; YES - inhibit end-of-dive warning if current CNS is already in warning
	movff	int_O_normal_CNS_fraction+1,WREG
	btfsc	WREG,int_invalid_flag		; flag for invalid value set?
	bra		check_eod_cns_violation1	; YES - continue with checking the other CNS value
	btfsc	WREG,int_warning_flag		; NO  - flag for warning set?
	bra		check_eod_cns_violation2	;       YES - issue warning
check_eod_cns_violation1:				;       NO  - continue with checking the other CNS value
	movff	int_O_alternate_CNS_fraction+1,WREG
	btfsc	WREG,int_invalid_flag		; flag for invalid value set?
	return								; YES - done with CNS checking
	btfsc	WREG,int_warning_flag		; NO  - flag for warning set?
	bra		check_eod_cns_violation2	;       YES - issue warning
	return								;       NO  - done with CNS checking
check_eod_cns_violation2:				; issue warning (actually only on attention level)
	bsf		message_attention			; show attention sign
	btfsc	alternative_divelayout		; in alternative layout?
	bra		display_eod_cns_violation	; YES - show warning
	movlw	index_CNS					; NO  - index of custom view with CNS values
	cpfseq	menupos3					;     - CNS values shown?
	bra		display_eod_cns_violation	;       NO  - issue textual warning
	return								;       YES - do not show twice (in custom view and in warning area)
display_eod_cns_violation:
	incf	message_counter,F			; increase counter
	goto	TFT_display_eod_cns			; issue CNS at end-of-dive warning (and return)


	global	check_and_store_gf_violation
check_and_store_gf_violation:
	movff	int_O_gradient_factor+1,WREG	; get upper byte of gradient factor
	btfss	WREG,int_warning_flag			; check if the warning flag is set
	bra		check_and_store_gf_violation2	; NO  - continue with checking for attention flag
	movlw	d'2'							; YES - set type of alarm
	movwf	AlarmType						;		copy to alarm register
	bsf		event_occured					;		set event   flag
	bsf		message_warning					;		set warning flag
	bra		check_and_store_gf_violation3	;		show gf warning
check_and_store_gf_violation2:
	btfsc	WREG,int_attention_flag			; check if the attention flag is set
	bra		check_and_store_gf_violation3	; YES - show gf
	TSTOSS	opt_enable_IBCD					; NO  - IBCD warning activated?
	bra		check_and_store_gf_violation4	;		NO  - continue checking of deco info
	movff	char_O_deco_warnings,WREG		;		YES - get the deco warnings vector
	btfss	WREG,IBCD_warning				;			 is the IBCD warning flag set?
	bra		check_and_store_gf_violation4	;			 NO  - continue checking for deco info
check_and_store_gf_violation3:				;			 YES - show gf
	bsf		message_attention				; show attention sign
	incf	message_counter,F				; increase counter
	goto	TFT_warning_gf					; show GF (and return)
check_and_store_gf_violation4:				; check for deco info
	btfss	divemode						; in dive mode?
	return									; NO  - done, return
	btfsc	FLAG_bailout_mode				; YES - in bailout mode?
	return									;       YES - done, return (deco_decreasing flag is not updated when in bailout mode)
	movff	char_O_deco_info,WREG			;       NO  - get the deco info vector
	btfss	WREG,deco_decreasing			;             check if the deco_decreasing flag is set
	return									;             NO  - done, return
	incf	message_counter,F				;             YES - increase counter
	goto	TFT_info_deco					;                 - show deco info


check_outside:
	movff	char_O_deco_warnings,WREG	; bank-safe copy of deco warnings
	btfss	WREG,outside_warning_lock	; are we outside of the ZH-L16 model?
	return								; NO  - done
	incf	message_counter,F			; YES - increase counter
	bsf		message_attention			;     - show attention sign
	btfsc	WREG,outside_warning		;     - are we outside the ZH-L16 model right now (-> warning)?
	bsf		message_warning				;     - set warning flag
	goto	TFT_warning_outside			;     - show outside-ZHL-model warning/attention (and return)


	global	check_mbubbles
check_mbubbles:
	movff	char_O_deco_warnings,WREG	; bank-safe copy for deco warnings
	btfsc	WREG,mbubble_warning		; are we in micro bubbling zone right now?
	bra		check_mbubbles_warn			; YES
	btfss	WREG,mbubble_warning_lock	; were we in micro bubbling zone?
	return								; NO  - done
check_mbubble_att						; YES - attention level
	incf	message_counter,F			; increase counter
	bsf		message_attention			; show attention sign
	goto	TFT_warning_mbubbles		; show micro bubble attention (and return) - TFT_warning_mbubbles switches by itself between attention and warning
check_mbubbles_warn:					; locked micro bubbles - warning level if at issue, attention level if locked
	incf	message_counter,F			; increase counter
	bsf		message_warning				; set warning flag
	goto	TFT_warning_mbubbles		; show micro bubbles warning (and return)

 IFDEF _cave_mode
check_cavemode:
	incf	message_counter,F			; increase counter
	btfsc	FLAG_dive_turned			; dive turned?
	goto	TFT_info_dive_turned		; YES - show info that dive is turned
	btfsc	FLAG_cave_mode_shutdown		; NO  - has cave mode shut down?
	goto	TFT_warn_cave_shutdown		;       YES - show that cave mode has shut down
	goto	TFT_info_cave_mode			;       NO  - show that cave mode is active
 ENDIF

warn_agf:
	incf	message_counter,F			; increase counter
	goto	TFT_warning_agf				; show aGF warning (and return)

warn_fallback:
	incf	message_counter,F			; increase counter
	bsf		message_warning				; set warning flag
	goto	TFT_warning_fallback		; show fallback warning (and return)


 IFDEF _rx_functions

check_tr_messages:
	movff	int_O_sac_rate+1,WREG		; bank-safe copy of current SAC rate
	btfss	WREG,int_attention_flag		; attention flag set?
	bra		check_tr_messages2			; NO  - skip
	btfsc	WREG,int_not_avail_flag		; SAC rate available?
	bra		check_tr_messages2			; NO  - continue with swap advice
	bsf		message_attention			; YES - show attention sign
	btfsc	alternative_divelayout		;     - in alternative layout?
	bra		check_tr_messages1			;       YES - show attention message
	movlw	index_pressures_SAC			;       NO  - index of custom view with SAC rate
	cpfseq	menupos3					;           - SAC rate shown right now?
	bra		check_tr_messages1			;             NO  - show attention message
	bra		check_tr_messages2			;             YES - do not show twice, continue with swap advice
check_tr_messages1:
	incf	message_counter,F			; increase counter
	call	TFT_attention_sac			; show SAC attention
check_tr_messages2:
	movff	char_O_deco_info,WREG		; bank-safe copy of deco info vector
	btfss	WREG,ind_double_switch		; swap tank flag set?
	return								; NO
	incf	message_counter,F			; YES - increase counter
	bsf		message_advice				;     - show advice sign
	goto	TFT_advice_switch			;     - show swap advice


#DEFINE show_custview			ul,0		; show pressure readings custom view
#DEFINE show_transmitter		ul,1		; show transmitter attention
#DEFINE show_pres_warning		ul,2		; show transmitter pressure warning
#DEFINE show_pres_attention		ul,3		; show transmitter pressure attention

check_tr_functions:
	clrf	ul								; set all messages as not shown yet
	btfsc	alternative_divelayout			; in alternative layout?
	bra		check_tr_functions_tr1			; YES - continue with checking transmitter 1
	movlw	index_pressures_SAC				; NO  - index of custom view pressure readings
	cpfseq	menupos3						;     - pressure readings shown?
	bra		check_tr_functions_tr1			;       NO  - continue with checking transmitter 1
	bsf		show_custview					;       YES - suppress redraw by faking it has already been redrawn
check_tr_functions_tr1:
	movff	char_I_pressure_stat+0,WREG		; get status of 1st pressure reading
	rcall	check_tr_functions_helper1		; check for transmitter 1 lost
	rcall	check_tr_functions_helper2		; check for transmitter 1 low battery
	movff	int_IO_pressure_value+1,WREG	; get high byte of 1st pressure reading
	rcall	check_tr_functions_helper3		; check for transmitter 1 pressure warning
	rcall	check_tr_functions_helper4		; check for transmitter 1 pressure attention
check_tr_functions_tr2:
	movff	char_I_pressure_stat+1,WREG		; get status of 2nd pressure reading
	rcall	check_tr_functions_helper5		; check for transmitter 2 lost
	rcall	check_tr_functions_helper6		; check for transmitter 2 low battery
	movff	int_IO_pressure_value+3,WREG	; get high byte of 2nd pressure reading
	rcall	check_tr_functions_helper7		; check for transmitter 2 pressure warning
	rcall	check_tr_functions_helper8		; check for transmitter 2 pressure attention
check_tr_functions_show_xmtr:
	btfss	show_transmitter				; shall show transmitter message?
	bra		check_tr_functions_show_warn	; NO  - continue with pressure warning
	bsf		message_attention				; YES - set flag for attention
	incf	message_counter,F				;     - increase counter
	call	TFT_attention_transmitter		;     - show transmitter attention message
check_tr_functions_show_warn:
	btfss	show_pres_warning				; shall show pressure warning?
	bra		check_tr_functions_show_att		; NO  - continue with pressure attention
	bsf		message_warning					; YES - set flag for warning
	incf	message_counter,F				;     - increase counter
	goto	TFT_warning_pres_reading		;     - pressure reading warning message and done then
check_tr_functions_show_att:
	btfss	show_pres_attention				; shall show pressure attention?
	return									; NO  - done
	bsf		message_attention				; YES - set flag for attention
	incf	message_counter,F				;     - increase counter
	goto	TFT_attention_pres_reading		;     - pressure reading warning message and done then

check_tr_functions_helper1:
	btfsc	WREG,char_transmitter_lost		; transmitter 1 lost?
	bra		check_tr_functions_helper1a		; YES - show transmitter attention message
	bcf		transmitter1_lost				; NO  - clear flag for old lost attention
	return									;     - done
check_tr_functions_helper1a:
	bsf		show_transmitter				; show transmitter attention
	btfsc	transmitter1_lost				; is it a new message?
	return									; NO  - do not show the pressure readings custom view again
	bsf		transmitter1_lost				; YES - memorize it's an old message now
	bra		check_tr_functions_show_cv		;     - show custom view

check_tr_functions_helper2:
	btfsc	WREG,char_transmitter_low_bat	; transmitter 1 low battery?
	bra		check_tr_functions_helper2a		; YES - show transmitter attention message
	bcf		transmitter1_battery			; NO  - clear flag for old battery attention
	return									;     - done
check_tr_functions_helper2a:
	bsf		show_transmitter				; show transmitter attention
	btfsc	transmitter1_battery			; is it a new message?
	return									; NO  - do not show the pressure readings custom view again
	bsf		transmitter1_battery			; YES - memorize it's an old message now
	bra		check_tr_functions_show_cv		;     - show custom view

check_tr_functions_helper3:
	btfsc	WREG,int_warning_flag			; transmitter 1 pressure warning?
	bra		check_tr_functions_helper3a		; YES - show pressure reading message as warning
	bcf		transmitter1_pres_warn			; NO  - clear flag for old warning
	return									;     - done
check_tr_functions_helper3a:
	bsf		show_pres_warning				; show pressure warning
	btfsc	transmitter1_pres_warn			; is it a new message?
	return									; NO  - do not show the pressure readings custom view again
	bsf		transmitter1_pres_warn			; YES - memorize it's an old message now
	bra		check_tr_functions_show_cv		;     - show custom view

check_tr_functions_helper4:
	btfsc	WREG,int_attention_flag			; transmitter 1 pressure attention?
	bra		check_tr_functions_helper4a		; YES - show pressure reading message as attention
	bcf		transmitter1_pres_att			; NO  - clear flag for old attention
	return									;     - done
check_tr_functions_helper4a
	bsf		show_pres_attention				; show pressure attention
	btfsc	transmitter1_pres_att			; is it a new message?
	return									; NO  - do not show the pressure readings custom view again
	bsf		transmitter1_pres_att			; YES - memorize it's an old message now
	bra		check_tr_functions_show_cv		;     - show custom view

check_tr_functions_helper5:
	btfsc	WREG,char_transmitter_lost		; transmitter 2 lost?
	bra		check_tr_functions_helper5a		; YES - show transmitter attention message
	bcf		transmitter2_lost				; NO  - clear flag for old lost attention
	return									;     - done
check_tr_functions_helper5a:
	bsf		show_transmitter				; show transmitter attention
	btfsc	transmitter2_lost				; is it a new message?
	return									; NO  - do not show the pressure readings custom view again
	bsf		transmitter2_lost				; YES - memorize it's an old message now
	bra		check_tr_functions_show_cv		;     - show custom view

check_tr_functions_helper6:
	btfsc	WREG,char_transmitter_low_bat	; transmitter 2 low battery?
	bra		check_tr_functions_helper6a		; YES - show transmitter attention message
	bcf		transmitter2_battery			; NO  - clear flag for old battery attention
	return									;     - done
check_tr_functions_helper6a:
	bsf		show_transmitter				; show transmitter attention
	btfsc	transmitter2_battery			; is it a new message?
	return									; NO  - do not show the pressure readings custom view again
	bsf		transmitter2_battery			; YES - memorize it's an old message now
	bra		check_tr_functions_show_cv		;     - show custom view

check_tr_functions_helper7:
	btfsc	WREG,int_warning_flag			; transmitter 2 pressure warning?
	bra		check_tr_functions_helper7a		; YES - show pressure reading message as warning
	bcf		transmitter2_pres_warn			; NO  - clear flag for old warning
	return									;     - done
check_tr_functions_helper7a:
	bsf		show_pres_warning				; show pressure warning
	btfsc	transmitter2_pres_warn			; is it a new message?
	return									; NO  - do not show the pressure readings custom view again
	bsf		transmitter2_pres_warn			; YES - memorize it's an old message now
	bra		check_tr_functions_show_cv		;     - show custom view

check_tr_functions_helper8:
	btfsc	WREG,int_attention_flag			; transmitter 2 pressure attention?
	bra		check_tr_functions_helper8a		; YES - show pressure reading message as attention
	bcf		transmitter2_pres_att			; NO  - clear flag for old attention
	return									;     - done
check_tr_functions_helper8a
	bsf		show_pres_attention				; show pressure attention
	btfsc	transmitter2_pres_att			; is it a new message?
	return									; NO  - do not show the pressure readings custom view again
	bsf		transmitter2_pres_att			; YES - memorize it's an old message now
	;bra	check_tr_functions_show_cv		;     - show custom view

check_tr_functions_show_cv:
	btfsc	show_custview					; is the pressure readings custom view not shown yet shown?
	return									; NO  - already shown, done
	bsf		show_custview					; YES - mark as shown
	btfsc	alternative_divelayout			;     - in alternative layout?
	call	switch_layout_to_normal			;       YES - switch to normal layout
	movlw	index_pressures_SAC-1			;       custom view number one below pressure readings
	movwf	menupos3						;       set custom view number
	bsf		toggle_customview				;       initiate toggle to desired custom view ->  pressure readings view will be shown
	return									;       done

 ENDIF


check_gas_needs_ascent:
	banksel	int_O_ascent_pres_need
	movf	int_O_ascent_pres_need+1,w	; get               high byte from pres need of 1st tank
	iorwf	int_O_ascent_pres_need+3,w	; inclusive or with high byte from pres need of 2nd tank
	iorwf	int_O_ascent_pres_need+5,w	; inclusive or with high byte from pres need of 3rd tank
	iorwf	int_O_ascent_pres_need+7,w	; inclusive or with high byte from pres need of 4th tank
	iorwf	int_O_ascent_pres_need+9,w	; inclusive or with high byte from pres need of 5th tank
	banksel	common
	btfsc	WREG,int_invalid_flag		; check if invalid flag is set
	return								; YES - no further checking required
	btfsc	WREG,int_warning_flag		; check if any gas has a pres_need >= pres_fill
	bsf		message_warning				; YES - set warning flag
	btfsc	WREG,int_warning_flag		; check if any gas has a pres_need >= pres_fill
	goto	TFT_warning_gas_needs_warn	; Yes - show a warning
	btfsc	WREG,int_attention_flag		; check if any gas has a pres_need >= pres_fill * threshold
	bsf		message_attention			; YES - set attention flag
	btfsc	WREG,int_attention_flag		; check if any gas has a pres_need >= pres_fill * threshold
	goto	TFT_warning_gas_needs_att	; YES - show an attention
	bcf		gas_needs_attention			; NO  - clear flag for a new attention
	bcf		gas_needs_warning			;       clear flag for a new warning
	return


check_warn_sensors_disagree:
	incf	message_counter,F			; increase counter
	bsf		message_warning				; YES - set warning flag
	goto	TFT_warning_sensor_disagree	;       show sensor disagree warning (and return)


check_IBCD:
	TSTOSS	opt_enable_IBCD				; IBCD warning activated?
	return								; NO  - done
	movff	char_O_deco_warnings,WREG	; YES - get deco warnings vector
	btfss	WREG,IBCD_warning			;       IBCD warning flag set?
	return								;       NO  - return
	incf	message_counter,F			;       YES - increase counter
	goto	TFT_warning_IBCD			;             write warning to display


check_OC_gas_avail:
	tstfsz	best_gas_number				; is a breathable gas available?
	return								; > 0 : a breathable gas is available
	btfsc	FLAG_ccr_mode				; = 0 : problem - in CCR mode?
	bra		check_OC_gas_avail_1		; YES - real problem
	btfsc	FLAG_pscr_mode				; NO  - in PSCR mode?
	bra		check_OC_gas_avail_1		;       YES - real problem
	return								;       NO  - neither CCR nor pSCR mode, suppress warning
check_OC_gas_avail_1:
	btfsc	FLAG_bailout_mode			; in bailout?
	return								; YES - suppress warning
	incf	message_counter,F			; NO  - increase counter
	bsf		message_attention			;       set attention flag
	goto	TFT_warning_no_BO_gas		;       show message (and return)


advice_gas_change:
	bsf		message_advice				; show advice sign
	incf	message_counter,F			; increase counter
	goto	TFT_advice_gas_change


	global	restart_deco_engine
	global	restart_deco_engine_wo_ceiling
restart_deco_engine:
	; invalidate ceiling
	movff	int_O_ceiling+1,WREG
	bsf		WREG,char_invalid_flag		; int_O_ceiling has its invalid flag on a char's position!
	movff	WREG,int_O_ceiling+1

restart_deco_engine_wo_ceiling:
	; invalidate deco data (stop table data)
	movff	char_O_deco_gas+0,WREG
	bsf		WREG,char_invalid_flag
	movff	WREG,char_O_deco_gas+0

	; invalidate ascent time (normal plan)
	movff	int_O_ascenttime+1,WREG
	bsf		WREG,int_invalid_flag
	movff	WREG,int_O_ascenttime+1

	; invalidate CNS at end of dive in normal plan
	movff	int_O_normal_CNS_fraction+1,WREG
	bsf		WREG,int_invalid_flag
	movff	WREG,int_O_normal_CNS_fraction+1

	; restart deco engine
	movff	char_O_main_status,WREG		; get current main engine configuration
	bcf		WREG,DECO_COMPLETED_NORM	; eventually clear flag stating completion of normal plan
	bsf		WREG,DECO_COMPLETED_ALT		; fake we came from alternative plan to force normal plan to be done next
	movff	WREG,char_O_main_status		; write back new configuration
	movff	char_O_deco_status,WREG		; get current deco engine status
	bcf		WREG,DECO_STATUS_0_FLAG		; set status flags to...
	bcf		WREG,DECO_STATUS_1_FLAG		; ... DECO_STATUS_START
	movff	WREG,char_O_deco_status		; write back new configuration to restart deco computations

inval_alternative_plan_data:
	; invalidate ascent time (alternative plan)
	movff	int_O_alternate_ascenttime+1,WREG
	bsf		WREG,int_invalid_flag
	movff	WREG,int_O_alternate_ascenttime+1

	; invalidate CNS at end of dive in alternative plan
	movff	int_O_alternate_CNS_fraction+1,WREG
	bsf		WREG,int_invalid_flag
	movff	WREG,int_O_alternate_CNS_fraction+1

	; invalidate ascent gas needs
	movff	int_O_ascent_pres_need+1,WREG
	bsf		WREG,int_invalid_flag
	movff	WREG,int_O_ascent_pres_need+1

 IFDEF _rx_functions
	; invalidate pressure needs (TR functions)
	movff	int_O_pressure_need+1,WREG
	bsf		WREG,int_not_avail_flag
	movff	WREG,int_O_pressure_need+1
	movff	int_O_pressure_need+3,WREG
	bsf		WREG,int_not_avail_flag
	movff	WREG,int_O_pressure_need+3
 ENDIF

	; update display depended on NDL or deco mode
	bsf		FLAG_TFT_display_ndl_or_deko

	return

;=============================================================================
; Simulator Mode
;

	global	do_demo_divemode
do_demo_divemode:
	call	TFT_ClearScreen					; blank screen
	call	option_save_all					; save all settings into EEPROM before starting simulation
	call	deco_push_tissues_to_vault		; C-code: back-up status of the real tissues
	banksel	common							; bank 1

	; +++ COMMENT OUT FOR TESTING PURPOSE ONLY  !!! +++
	bsf		restore_deco_data				; restore tissue and CNS after simulator use
	; +++ DO NOT COMMENT OUT IN OPERATIONAL USE !!! +++

	bcf		pressure_refresh
	btfss	pressure_refresh				; wait for sensor
	bra		$-2

	bsf		simulatormode_active			; set flag

	banksel	char_I_bottom_depth				; compute dive ambient conditions
	movf	char_I_bottom_depth,W
	mullw	.100
	movff	PRODL,rel_pressure+0
	movff	PRODH,rel_pressure+1
	movlw	LOW  (.1000)
	addwf	PRODL,W
	movff	WREG,sim_pressure+0
	movlw	HIGH (.1000)
	addwfc	PRODH,W
	movff	WREG,sim_pressure+1
	banksel	common							; bank 1

	bsf		divemode
	goto	diveloop						; switch into dive mode

	END