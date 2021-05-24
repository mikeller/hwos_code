;=============================================================================
;
;   File divemode.asm                       * combined next generation V3.12.3
;
;   Dive Mode
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
#include "math.inc"
#include "wait.inc"
#include "customview.inc"
#include "start.inc"
#include "adc_lightsensor.inc"
#include "ghostwriter.inc"
#include "i2c.inc"
#include "calibrate.inc"
#include "convert.inc"
#include "surfmode.inc"
#include "rx_ops.inc"


	extern	do_line_menu
	extern	do_main_divemenu
	extern	menu_draw_lines_divemode
	extern	menu_draw_cursor_dive
	extern	init_recording_params
	extern	option_check_and_store_all

 IFDEF _compass
	extern	TFT_dive_compass_heading
 ENDIF

 IFDEF _cave_mode
	extern	do_main_cavemenu
 ENDIF


;---- Private local Variables -------------------------------------------------

	CBLOCK	local1						; max size is 16 Byte !!!
		sensor_setpoint					; sensor ppo2 in 0.01bar for deco routine
		check_gas_num					; used in search for best gas/dil: current gas/dil number (1-5)
		check_gas_depth					; used in search for best gas/dil: current gas/dil change depth
		check_gas_type					; used in search for best gas/dil: current gas/dil type
		check_gas_O2_ratio				; used in search for best gas/dil: current gas/dil O2 ratio
		best_gas_num					; used in search for best gas/dil: best    gas/dil number (1-5)  CAUTION: there is also a variable named best_gas_number !
		best_gas_depth					; used in search for best gas/dil: best    gas/dil change depth
		last_pressure_velocity:2		; cached last absolute pressure for velocity calculation
		TFT_output_flags_1				; TFT update flags for output phase 1
		TFT_output_flags_2				; TFT update flags for output phase 2
		TFT_output_flags_3				; TFT update flags for output phase 3
		TFT_output_flags_4				; TFT update flags for output phase 4
		DM_flags_local					; various dive mode flags
	ENDC								; used: 14 byte, remaining: 2 byte

	CBLOCK	local2						; max size is 16 Byte !!!
		pressure_rel_accu_trip:4		; pressure accumulator for calculating the resettable average depth
		pressure_rel_accu_total:4		; pressure accumulator for calculating the total dive average depth
		ppO2_min:2						; used in search for best gas/dil: minimum ppO2 required
		ppO2_max_default:2				; used in search for best gas/dil: default  maximum ppO2
		ppO2_max_deco:2					; used in search for best gas/dil: deco     maximum ppO2
	ENDC								; used: 14 byte, remaining: 2 byte


;---- Private local Flags ----------------------------------------------------

; TFT_output_flags_1 - phase 1: every second - before deco calculations, all modes
#DEFINE FLAG_TFT_depth_current			TFT_output_flags_1,0	; =1: show  current depth
#DEFINE FLAG_TFT_depth_maximum			TFT_output_flags_1,1	; =1: show  maximum depth
#DEFINE FLAG_TFT_active_gas_divemode	TFT_output_flags_1,2	; =1: show  active gas and dive mode
#DEFINE FLAG_TFT_apnoe_surface_time		TFT_output_flags_1,3	; =1: show  apnoe mode surface time
#DEFINE FLAG_TFT_depth_maximum_apnoe	TFT_output_flags_1,4	; =1: show  maximum depth of last apnoe dive
#DEFINE FLAG_TFT_clear_apnoe_surface	TFT_output_flags_1,5	; =1: clear apnoe mode surface data from screen
#DEFINE FLAG_TFT_apnoe_divetime			TFT_output_flags_1,6	; =1: show  apnoe mode dive times
#DEFINE FLAG_TFT_temperature			TFT_output_flags_1,7	; =1: show  temperature (or resettable dive time when in compass view)

; TFT_output_flags_2 - phase 2: every second - before deco calculations, deco modes only
#DEFINE FLAG_TFT_divemode_mask			TFT_output_flags_2,0	; =1: show  dive mode mask
#DEFINE FLAG_TFT_divetime				TFT_output_flags_2,1	; =1: show  dive time
#DEFINE FLAG_TFT_safety_stop_show		TFT_output_flags_2,2	; =1: show  safety stop
#DEFINE FLAG_TFT_safety_stop_clear		TFT_output_flags_2,3	; =1: clear safety stop
;										TFT_output_flags_2,4	; --- unused
;										TFT_output_flags_2,5	; --- unused
;										TFT_output_flags_2,6	; --- unused
;										TFT_output_flags_2,7	; --- unused

; TFT_output_flags_3 - phase 3: every second - after deco calculations, deco modes only
#DEFINE FLAG_TFT_clear_deco_data		TFT_output_flags_3,0	; =1: clear deco data (NDL or stop & TTS)
#DEFINE FLAG_TFT_display_ndl_mask		TFT_output_flags_3,1	; =1: show  NDL  mask
#DEFINE FLAG_TFT_display_deco_mask		TFT_output_flags_3,2	; =1: show  deco mask
#DEFINE FLAG_TFT_display_ndl			TFT_output_flags_3,3	; =1: show  NDL  data
#DEFINE FLAG_TFT_display_deco			TFT_output_flags_3,4	; =1: show  deco stop data
#DEFINE FLAG_TFT_display_tts			TFT_output_flags_3,5	; =1: show  deco TTS  data
;										TFT_output_flags_3,6	; --- unused
;										TFT_output_flags_3,7	; --- unused

; TFT_output_flags_4 - phase 4: every second - after deco calculations, all modes
#DEFINE FLAG_TFT_customview_callup		TFT_output_flags_4,0	; =1: show  the custom view mask
#DEFINE FLAG_TFT_sign_show				TFT_output_flags_4,1	; =1: show  the advice / attention / warning sign
#DEFINE FLAG_TFT_sign_clear				TFT_output_flags_4,2	; =1: clear the advice / attention / warning sign
#DEFINE FLAG_TFT_message_clear_both		TFT_output_flags_4,3	; =1: clear messages, both rows
#DEFINE FLAG_TFT_message_clear_2nd		TFT_output_flags_4,4	; =1: clear messages, 2nd row only
#DEFINE FLAG_TFT_velocity_show			TFT_output_flags_4,5	; =1: show  vertical velocity
#DEFINE FLAG_TFT_velocity_clear			TFT_output_flags_4,6	; =1: clear vertical velocity
;										TFT_output_flags_4,7	; --- unused


; various Flags
#DEFINE new_deco_data_avail				DM_flags_local,0		; =1: new NDL or deco data available
#DEFINE update_menu						DM_flags_local,1		; =1: redraw the dive menu
#DEFINE FLAG_SP2_used					DM_flags_local,2		; =1: setpoint 2 has been auto-selected already
#DEFINE FLAG_SP3_used					DM_flags_local,3		; =1: setpoint 3 has been auto-selected already
#DEFINE FLAG_SP4_used					DM_flags_local,4		; =1: setpoint 4 has been auto-selected already
#DEFINE FLAG_SP5_used					DM_flags_local,5		; =1: setpoint 5 has been auto-selected already
;										DM_flags_local,6		; --- unused
;										DM_flags_local,7		; --- unused


;=============================================================================
dmode1	CODE
;=============================================================================


;-----------------------------------------------------------------------------
; Entry Point for Dive Mode
;
	global	diveloop
diveloop:
	clrf	STKPTR						; clear return addresses stack

	; start with a clean time base
	bsf		reset_timebase				; request ISR to reset the main timebase,
										; as we are in dive mode the dive timers will be reset as well

	; reset global flags
	clrf	DM_flags_state				; clear all flags for dive mode status
	clrf	DM_flags_event				; clear all flags for data recording events
	clrf	DM_flags_request			; clear all flags for user requests / general
 IFDEF _cave_mode
	clrf	DM_flags_cavereq			; clear all flags for user requests / cave mode
 ENDIF
	clrf	DM_flags_layout1			; clear all flags for display control / layout (1)
	clrf	DM_flags_layout2			; clear all flags for display control / layout (2)
	clrf	DM_flags_layout3			; clear all flags for display control / layout (3)
	clrf	DM_flags_message			; clear all flags for display control / messages
	clrf	DM_flags_gas_dil			; clear all flags for display control / gases, diluents, depth

	clrf	DM_flags_advc_det			; clear all flags for advices    detection
	clrf	DM_flags_advc_ack			; clear all flags for advices    acknowledged

	clrf	DM_flags_att1_det			; clear all flags for attentions detection
	clrf	DM_flags_att2_det			; ...
	clrf	DM_flags_att3_det			; ...

	clrf	DM_flags_att1_ack			; clear all flags for attentions acknowledged
	clrf	DM_flags_att2_ack			; ...
	clrf	DM_flags_att3_ack			; ...

	clrf	DM_flags_war1_det			; clear all flags for warnings   detection
	clrf	DM_flags_war2_det			; ...

	clrf	DM_flags_war1_ack			; clear all flags for warnings   acknowledged
	clrf	DM_flags_war2_ack			; ...

	clrf	DM_flags_shown1				; arm auto show-up of custom views
	clrf	DM_flags_shown2				; ...
	clrf	DM_flags_shown3				; ...

	bcf		dive_main_menu				; clear dive main menu flag
	bcf		dive_pre_menu				; clear dive  pre-menu flag

	; reset local flags
	clrf	TFT_output_flags_1			; clear all flags for TFT output phase 1
	clrf	TFT_output_flags_2			; clear all flags for TFT output phase 2
	clrf	TFT_output_flags_3			; clear all flags for TFT output phase 3
	clrf	TFT_output_flags_4			; clear all flags for TFT output phase 4
	clrf	DM_flags_local				; clear all the various other flags, too

	; boot tasks for all modes
	call	diveloop_boot				; initialize dive mode

	; startup tasks for all modes
	call	TFT_boot					; initialize TFT (includes clear screen)
	call	TFT_load_dive_color_pallet	; load dive color pallet
	call	TFT_show_divemode_mask		; display static dive mode mask
	call	TFT_Display_FadeIn			; dim up the display

	; arm dive start timer
	bcf		divetime_longer_1min		; the dive has just begun
	btfsc	FLAG_apnoe_mode				; in apnea mode?
	bsf		divetime_longer_1min		; YES - force dive to have lasted for longer than 1 minute already
	btfsc	sensor_override_active		; in simulator mode?
	bsf		divetime_longer_1min		; YES - force dive to have lasted for longer than 1 minute already

	; initiate initial display outputs
	bsf		trigger_pres_cur_changed	; flag that the pressures have changed to have all data...
	bsf		trigger_pres_max_changed	; ... written to the display on the first output round
	bsf		trigger_temp_changed		; flag that the temperature has changed to have the temperature ...
										; ... written to the display on the first output round
	bsf		new_deco_data_avail			; flag that new deco engine results are available to have the initial data ...
										; ... written to the display on the first output round

	; initialize the resettable average depth
	call	resettable_average_depth_init

	; reload and redraw last custom view
	movff	customview_divemode,active_customview
	bsf		FLAG_TFT_customview_callup

	btfsc	FLAG_apnoe_mode				; in apnoe mode?
	bra		diveloop_1					; YES - done with initialization
	btfsc	FLAG_gauge_mode				; NO  - in gauge mode?
	bra		diveloop_1					;       YES - done with initialization
	bsf		FLAG_TFT_display_ndl_mask	;       NO  - request initial display of NDL mask
	bsf		FLAG_TFT_active_gas_divemode;           - request initial display of gas and setpoint

diveloop_1:
	btfsc	reset_timebase				; has the ISR confirmed reset of the timebase meanwhile?
	bra		$-2							; NO  - not yet, loop waiting for confirmation before entering the dive loop
	;bra	diveloop_loop				; YES - enter the dive loop


;-----------------------------------------------------------------------------
; Dive Mode Mail Loop
;
diveloop_loop:
	btfss	trigger_quarter_second			; new 1/4 second?
	bra		diveloop_loop_0				;       No - continue

	;---- tasks any new 1/4 second -----
	bcf		trigger_quarter_second		; YES - clear flag

	movlw	.4					; 62,5ms * 4 = 1/4 second
	movff	WREG,isr_tmr7_helper			; to make sure at least 1/4 will pass before trigger_quarter_second is re-set

	btfss	press_sensor_type			; New sensor found?
	bra 	diveloop_loop_0				;       No - continue

	; Handle new pressure sensor every 1/4 second
	btfsc	ms5837_state				; =0: result of temperature is in the ADC
	bra	diveloop_loop_quarter_2
	call	I2C_get_temp_val_MS5837			; (Will set ms5837_state)
	bra	diveloop_loop_0				;  Done.
diveloop_loop_quarter_2:
	call	I2C_get_press_val_MS5837		; (Will clear ms5837_state)
	;---- tasks any new 1/4 second done -----

diveloop_loop_0:	
        btfsc	trigger_full_second			; new 1/1 second?
	bra		diveloop_loop_2				; YES - continue with tasks every 1/1 second
	btfsc	trigger_half_second			; NO  - new 1/2 second?
	bra		diveloop_loop_1				;       YES - continue with tasks every 1/2 second

	; tasks every round except every 1/1 or 1/2 second
 IFDEF _compass
	movlw	index_compass_dm			; index of compass view
	cpfseq	active_customview			; in compass view?
	bra		diveloop_loop_11			; NO  - continue with tasks every round
	call	TFT_dive_compass_heading	; YES - update compass heading value
	bsf		FLAG_TFT_temperature		;     - redraw temperature (will show resettable dive time now)
 ENDIF
	bra		diveloop_loop_11			;     - continue tasks every round

diveloop_loop_1:
	; tasks every 1/2 second
	bcf		trigger_half_second			; clear flag
	btfsc	FLAG_gauge_mode				; in gauge mode?
	bra		diveloop_loop_11			; YES - done with 1/2 second tasks
	btfsc	FLAG_apnoe_mode				; NO  - in apnoe mode?
	bra		diveloop_loop_11			; YES - done with 1/2 second tasks

	; tasks every 1/2 second in deco modes
	call	callup_deco_engine			; ##### manage and invoke the deco calculation engine #####
	bra		diveloop_loop_11			; done with 1/2 second tasks

diveloop_loop_2:
	; tasks every 1/1 second (code includes tasks every 1/2 second that fall onto the full second)
	bcf		trigger_full_second			; clear flag for new 1/1 second
	bcf		trigger_half_second			; clear flag for new 1/2 second as well

	btfss	trigger_temp_changed		; has the temperature changed?
	bra		diveloop_loop_3				; NO  - continue with tasks every 1/1 second

	bsf		FLAG_TFT_temperature		; YES - display temperature
	bcf		trigger_temp_changed		;     - clear flag

	; "future hardware will need min temperature checked every second..." (?)

	MOVII	temperature_min,sub_a		;     - copy last temperature_min to sub_a
	SMOVII	temperature_cur,sub_b		;     - ISR-safe 2 byte copy of current temperature to sub_b
	call	sub16						;     - sub_c = sub_a - sub_b = temperature_min - temperature
	btfsc	neg_flag					;     - temperature > temperature_min ?
	bra		diveloop_loop_3				;       YES - done
	MOVII	sub_b,temperature_min		;       NO  - store new minimum temperature

diveloop_loop_3:
	; tasks every 1/1 second
	btfss	trigger_pres_cur_changed	; has the pressure changed?
	bra		diveloop_loop_4				; NO  - continue with tasks every 1/1 second

	; set flags
	bcf		trigger_pres_cur_changed	; clear flag for pressure change
	bsf		FLAG_TFT_depth_current		; set flag to display updated depth

	; cache new absolute and relative pressure, ISR-safe 2 byte copies
	SMOVII	pressure_abs,    pressure_abs_cached
	SMOVII	pressure_rel_cur,pressure_rel_cur_cached

	; transfer absolute pressure to deco engine
	MOVII	pressure_abs_cached,int_I_pres_respiration

	; compute absolute pressure / 10, will be used later on a couple of times
	MOVII	pressure_abs_cached,xA
	MOVLI	.10,xB
	call	div16x16					; xC = xA / xB = absolute pressure / 10
	MOVII	xC,pressure_abs_10			; store result for later use

	; compute current depth in meters
	MOVII	pressure_rel_cur_cached,mpr	; copy current relative pressure in [mbar] to MPR
	call	convert_pres_to_depth		; convert pressure in [mbar] to depth in [cm]
	ADDLI	.50,mpr						; add 50 cm for rounding up/down around 0.5 meters
	MOVII	mpr, xA						; copy depth in [cm]   into xA
	MOVLI	.100,xB						; load factor 100 cm/m into xB
	call	div16x16					; xC = xA / xB = depth in full meters
	movff	xC+0,depth_meter			; store result as depth in [m], only low byte needed

	; check for new max pressure
	btfss	trigger_pres_max_changed	; has the max pressure changed?
	bra		diveloop_loop_4				; NO  - continue with tasks every 1/1 second
	bcf		trigger_pres_max_changed	; YES - clear flag for new max pressure
	bsf		FLAG_TFT_depth_maximum		;     - set   flag for displaying new max depth
	SMOVII	pressure_rel_max,pressure_rel_max_cached ; - cache new max depth

diveloop_loop_4:
	; continue tasks every 1/1 second

 IFDEF _ccr_pscr
	; adjust auto-setpoint
	btfsc	FLAG_ccr_mode				; in CCR mode?
	call	check_dive_autosp			; YES - check for Auto-SP
 ENDIF

 IFDEF _external_sensor
	btfsc	FLAG_ccr_mode				; in CCR mode?
	rcall	calc_deko_divemode_sensor	; YES - process sensor readings
	btfsc	FLAG_pscr_mode				; in pSCR mode?
	rcall	calc_deko_divemode_sensor	; YES - process sensor readings
 ENDIF

 IFDEF _cave_mode
	btfss	cave_mode					; cave mode switched on?
	bra		diveloop_loop_4a			; NO  - no backtracking depth recording
	btfsc	dive_turned					; dive turned?
	bra		diveloop_loop_4a			; YES - no backtracking depth recording
	btfsc	backtrack_entire_full		; backtracking storage entirely used up?
	bra		diveloop_loop_4a			; YES - no backtracking depth recording

	incf	backtrack_deltatime,F		; increment time elapsed since last depth recording
	movlw	.59							; load WREG with coding of last second of a minute
	cpfsgt	backtrack_deltatime			; time elapsed since last depth recording > 59 seconds?
	bra		diveloop_loop_4a			; NO  - no backtracking depth recording now
	rcall	write_backtrack_1min_depth	;     - store a backtracking depth data set
 ENDIF

diveloop_loop_4a:
	; continue tasks every 1/1 second

	btfsc	FLAG_apnoe_mode				; in apnoe mode?
	rcall	divemode_apnoe_tasks		; YES - do 1 sec. apnoe tasks

	; display all animated (blinking) values at the beginning of each full second to have a stable timebase
	rcall	TFT_output_1				; do display updates

	btfss	FLAG_apnoe_mode				; in apnoe mode?
	bra		diveloop_loop_5				; NO  - continue with deco mode tasks every 1/1 second

	; apnoe mode tasks every 1/1 second
	call	dive_customview_second		; do every second tasks for the custom view area
	bra		diveloop_loop_10			; continue with common tasks every 1/1 second

diveloop_loop_5:
	; deco mode tasks every 1/1 second
	bsf		FLAG_TFT_divetime			; display (new) dive time

	rcall	safety_stop_show			; serve safety stop

	rcall	TFT_output_2				; do display updates

	call	divemode_check_warnings		; check for warnings

 IFDEF _rx_functions
	btfss	tr_functions_activated		; TR functions activated?
	bra		diveloop_loop_6				; NO  - continue with deco mode tasks every 1/2 second
	call	get_pressure_readings		; YES - get  pressure readings
	call	configure_sac_calculation	;     - set up SAC calculation
 ENDIF

diveloop_loop_6:
	; deco mode tasks every 1/1 second
	INCI	divesecs_avg_trip			; increment the resettable dive time
	INCI	divesecs_avg_total			; increment the total      dive time

	btfsc	FLAG_gauge_mode				; in gauge mode?
	bra		diveloop_loop_7				; YES - skip deco calculations

	call	callup_deco_engine			; ##### manage and invoke the deco calculation engine #####

	btfsc	new_deco_data_avail			; new NDL or deco data available?
	call	show_new_deco_data			; YES - set-up display update requests

	btfsc	decostop_active				; in deco mode?
	bsf		FLAG_TFT_display_deco		; YES - update deco stop depth & time every second because of depth-dependent color-coding

	bsf		FLAG_TFT_depth_current		; set flag to display depth (in next round, needed in deco modes irrespectively of a pressure change for color-coding and blinking effects)

diveloop_loop_7:
	; deco mode tasks alternating every 2 seconds on timebase
	btfss	timebase_1sec				; on even second of timebase?
	rcall	calc_velocity				; YES - calculate velocity and display if > threshold
	btfsc	timebase_1sec				; on odd  second of timebase?
	call	check_gas_best				; YES - check if a better gas cue can be given

diveloop_loop_8:
	; deco mode tasks alternating every 2 seconds on resettable dive time
	btfss	divesecs_avg_trip+0,0		; on even second of resettable dive time?
	call	calc_average_depth			; YES - calculate average depth
	btfsc	divesecs_avg_trip+0,0		; on odd  second of resettable dive time?
	rcall	safety_stop_control			; YES - exercise safety stop control

diveloop_loop_9:
	; deco mode tasks every 1/1 second
	rcall	check_deco_states			; check and lock if in deco and in the deco stops region
	rcall	TFT_output_3				; do display updates

diveloop_loop_10:
	; common tasks every 1/1 second
	rcall	timeout_divemode			; check for timeout conditions
	call	check_dive_modes_dive		; test if depth still deeper than threshold

	btfsc	trigger_full_minute			; has next minute begun?
	rcall	update_divemode60			; YES - update clock, etc.

	btfss	FLAG_oc_mode				; are we in OC mode?
	bsf		FLAG_TFT_active_gas_divemode; NO - have the gas and setpoint redrawn on every second to update setpoint display, animate the blinking, etc.

	btfsc	dive_main_menu				; dive mode menu shown?
	bsf		update_menu					; YES - request update

	rcall	TFT_output_4				; do display updates

; tasks every round, every mode
diveloop_loop_11:
	call	test_switches_divemode		; check switches, in case branch into menu processor
	bra		diveloop_loop_12			; continue the dive loop


	; **** jump-in when returning from menu processor ****
	;
	global	divemode_option_divemenu_return
divemode_option_divemenu_return:
	clrf	STKPTR						; reset the stack
	call	menu_draw_cursor_dive		; show the cursor
	bsf		dive_main_menu				; set main menu   is     shown now
	clrf	active_premenu				; set pre-menu    is not shown any more
	bcf		safety_stop_active			; set safety stop is not shown any more
	movlw	divemode_timeout_mainmenu	; get timeout for main menu
	call	restart_timeout_time		; restart the timeout
	bra		diveloop_loop_12			; continue the dive loop


	; **** jump-in when returning from dive mode menu ****
	;
	global	diveloop_menu_exit
diveloop_menu_exit:
	clrf	STKPTR						; reset the stack
	call	divemenu_cleanup			; clean up menu area and restore dive data
	;bra	diveloop_loop_12			; continue the dive loop


diveloop_loop_12:
    	bsf		FLAG_TFT_active_gas_divemode; redraw gas and setpoint (eventually needed to restore the "Bailout" text)

	btfsc	request_next_custview		; shall show next custom view?
	call	dive_customview_toggle		; YES - show next custom view

	btfsc	request_gas_change			; shall change gas?
	call	gas_switch_common			; YES

	btfsc	request_gas_update			; shall update the gases?
	call	gas_update_common			; YES

	btfsc	request_toggle_GF			; shall toggle GF/aGF?
	call	divemodemode_togglegf		; YES

 IFDEF _cave_mode
	btfsc	request_cave_off_turned		; shall switch cave mode off and set the dive as turned?
	rcall	cavemode_switch_off_turned	; YES

	btfsc	request_cave_toggle			; shall toggle cave mode off/on?
	rcall	cavemode_toggle_onoff		; YES

	btfsc	request_turn_turn			; shall turn the dive?
	rcall	cavemode_turndive_turn		; YES

	btfsc	request_turn_toggle			; shall toggle the turn dive state?
	rcall	cavemode_turndive_toggle	; YES

	btfsc	request_waypoint_set		; shall set a waypoint?
	rcall	cavemode_waypoint_set		; YES

	btfsc	request_waypoint_out		; shall step one waypoint out of the cave?
	rcall	cavemode_waypoint_out		; YES

	btfsc	request_waypoint_in			; shall step one waypoint into the cave?
	rcall	cavemode_waypoint_in		; YES
 ENDIF

	btfsc	request_set_marker			; shall set a marker?
	call	set_logbook_marker			; YES

	btfsc	trigger_sample_divedata		; shall store new sample of dive data?
	call	store_dive_data				; YES - store profile data

	btfss	divemode					; dive finished?
	goto	ghostwriter_end_dive		; YES - dive finished

 IFDEF _screendump
	btfsc	screen_dump_avail			; screen dump function enabled?
	call	TFT_dump_screen_check		; YES - check if requested and do it
 ENDIF

	bra		diveloop_loop				; do next loop in dive mode


;-----------------------------------------------------------------------------
; Dive Mode Tasks every 1/1 Minute
;
update_divemode60:
	bcf		trigger_full_minute			; clear flag

	call	get_battery_voltage			; get battery voltage
	btfss	battery_low_condition		; battery low condition detected?
	bra		update_divemode60_1			; NO  - skip next
	movlw	d'7'						; YES - set type of alarm = battery low
	movwf	alarm_type					;     - copy to alarm register
	bsf		event_occured				;     - set event flag
	movlw	.0							;     - coding of brightness level ECO
	movff	WREG,opt_brightness			;     - set brightness to ECO

update_divemode60_1:
	; max allowed runtime in simulator is 254 minutes in
	; order for the tissue calculation catch-up to work!

	btfss	sensor_override_active		; in simulator mode?
	return								; NO  - done
	movlw	simulator_timeout_normal	; YES - set simulation timeout
 IFDEF _cave_mode
	TSTOSC	opt_cave_mode				;     - cave mode switched on?
	movlw	simulator_timeout_cave		;       YES - replace with cave mode simulation timeout
 ENDIF
	cpfsgt	counted_divetime_mins+0		;     - timeout?
	return								;       NO  - done
 IFDEF _DEBUG
	return								;       YES - but we do not care in debug mode...
 ELSE
	goto	divemode_option_sim_quit	;       YES - set depth to 0 m and return
 ENDIF


;-----------------------------------------------------------------------------
; Helper Function - set-up Display Update Requests
;
show_new_deco_data:
	bcf		new_deco_data_avail			; reset flag for new NDL or deco data available
	movff	char_O_deco_info,WREG		; get the deco info vector
	btfsc	WREG,deco_stops_norm		; deco stops found?
	bra		show_new_deco_data_deco		; YES - in deco
	;bra	show_new_deco_data_ndl		; NO  - within NDL

show_new_deco_data_ndl:					; within NDL
	btfsc	decostop_active				; been in deco mode before?
	bsf		FLAG_TFT_clear_deco_data	; YES - clear old deco data
	btfsc	decostop_active				; been in deco mode before?
	bsf		FLAG_TFT_display_ndl_mask	; YES - display NDL data mask
	bcf		decostop_active				; clear flag for been in deco mode before
	bsf		FLAG_TFT_display_ndl		; display NDL time
	return								; done

show_new_deco_data_deco:				; in deco
	btfss	decostop_active				; been in deco mode before?
	bsf		FLAG_TFT_clear_deco_data	; NO - clear old NDL data
	btfss	decostop_active				; been in deco mode before?
	bsf		FLAG_TFT_display_deco_mask	; NO - display deco data mask
	bsf		decostop_active				; set flag for being in deco mode
	bsf		FLAG_TFT_display_tts		; display TTS time (display of stop data is managed separately)
	return								; done


;-----------------------------------------------------------------------------
; Helper Function - do all Phase 1 Display Outputs
;
TFT_output_1:								; every second - before deco calculations, all mode
	btfsc	FLAG_TFT_clear_apnoe_surface	; shall clear apnoe mode surface data from screen?
	call	TFT_clear_apnoe_surface			; YES - clear apnoe mode surface data from screen

	btfsc	FLAG_TFT_depth_current			; shall show depth?
	call	TFT_show_depth					; YES - display depth
	btfsc	FLAG_TFT_depth_maximum			; shall show max depth?
	call	TFT_show_max_depth				; YES - display max depth
	btfsc	FLAG_TFT_active_gas_divemode	; shall show active gas and dive mode?
	call	TFT_show_active_gas_divemode	; YES - display gas, setpoint and mode
	btfsc	FLAG_TFT_temperature			; shall show temperature?
	call	TFT_show_temp_divemode			; YES - display temperature (or resettable dive time)

	btfsc	FLAG_TFT_apnoe_surface_time		; shall show apnoe mode surface time?
	call	TFT_show_apnoe_surface			; YES - show apnoe mode surface time
	btfsc	FLAG_TFT_depth_maximum_apnoe	; shall show max. depth of last dive?
	call	TFT_show_apnoe_max_depth		; YES - show max. depth of last dive
	btfsc	FLAG_TFT_apnoe_divetime			; shall show apnoe dive time?
	call	TFT_show_apnoe_times			; YES - show apnoe dive time?

	clrf	TFT_output_flags_1				; mark all TFT updates done
	return									; done


;-----------------------------------------------------------------------------
; Helper Function - do all Phase 2 Display Outputs
;
TFT_output_2:								; every second - before deco calculations, deco modes only
	btfsc	FLAG_TFT_divemode_mask			; shall re-draw mask?
	call	TFT_show_divemode_mask			; YES - re-draw mask
	btfsc	FLAG_TFT_divetime				; shall show dive time?
	call	TFT_show_divetime				; YES - show dive time
	btfsc	FLAG_TFT_safety_stop_show		; shall show safety stop?
	call	TFT_safety_stop_show			; YES - show safety stop
	btfsc	FLAG_TFT_safety_stop_clear		; shall clear safety stop?
	call	TFT_safety_stop_clear			; YES - clear safety stop
	clrf	TFT_output_flags_2				; mark all TFT updates done
	goto	dive_customview_second			; do every-second tasks for the custom view area (in sync with the dive time) and return


;-----------------------------------------------------------------------------
; Helper Function - do all Phase 3 Display Outputs
;
TFT_output_3:								; every second - after deco calculations, deco modes only
	btfsc	FLAG_TFT_clear_deco_data		; shall clear deco data (NDL or stop & TTS)?
	call	TFT_clear_deco_data				; YES - clear deco data (NDL or stop & TTS)
	btfsc	FLAG_TFT_display_ndl_mask		; shall show NDL mask?
	call	TFT_show_ndl_mask				; YES - show NDL mask
	btfsc	FLAG_TFT_display_ndl			; shall show NDL data?
	call	TFT_show_ndl					; YES - show NDL data
	btfsc	FLAG_TFT_display_deco_mask		; shall show deco mask?
	call	TFT_show_deco_mask				; YES - show deco mask
	btfsc	FLAG_TFT_display_deco			; shall show deco stop?
	call	TFT_show_deco					; YES - show deco stop
	btfsc	FLAG_TFT_display_tts			; shall show deco TTS?
	call	TFT_show_tts					; YES - show deco TTS
	clrf	TFT_output_flags_3				; mark all TFT updates done
	return									; done


;-----------------------------------------------------------------------------
; Helper Function - do all Phase 4 Display Outputs
;
TFT_output_4:								; every second - after deco calculations, all modes
	btfsc	FLAG_TFT_customview_callup		; shall show a custom view?
	call	dive_customview_callup			; YES - show a custom view
	btfsc	FLAG_TFT_velocity_show			; shall show  vertical velocity?
	call	TFT_velocity_show				; YES - show  vertical velocity
	btfsc	FLAG_TFT_velocity_clear			; shall clear vertical velocity?
	call	TFT_velocity_clear				; YES - clear vertical velocity
	btfsc	FLAG_TFT_sign_show				; shall show  the advice / attention / warning sign?
	call	TFT_divemode_sign_show			; YES - show sign
	btfsc	FLAG_TFT_sign_clear				; shall clear the advice / attention / warning sign?
	call	TFT_divemode_sign_clear			; YES - clear sign
	btfsc	FLAG_TFT_message_clear_both		; shall clear all messages?
	call	TFT_clear_message_window		; YES - clear complete message area
	btfsc	FLAG_TFT_message_clear_2nd		; shall clear 2nd row of message area?
	call	TFT_clear_message_window_row2	; YES - clear 2nd row of message area
	clrf	TFT_output_flags_4				; mark all TFT updates done
	return									; done


;-----------------------------------------------------------------------------
; Apnoe Mode Tasks
;
divemode_apnoe_tasks:						; 1 sec. apnoe tasks
	bsf		FLAG_TFT_apnoe_divetime			; show apnoe dive times (current/last dive and total)
	btfsc	apnoe_at_surface				; at the surface?
	bra		divemode_apnoe_tasks_surf		; YES  - at the surface
	;bra	divemode_apnoe_tasks_dive		; NO   - in dive phase

divemode_apnoe_tasks_dive:					; apnoe mode, submerged
	btfss	apnoe_new_dive					; new dive begun?
	return									; NO  - done
	bcf		apnoe_new_dive					; YES - clear flag
	bsf		FLAG_TFT_clear_apnoe_surface	;     - clear apnoe mode surface data from screen
	return									;     - done

divemode_apnoe_tasks_surf:					; apnoe mode, at the surface
	bsf		FLAG_TFT_apnoe_surface_time		; show apnoe mode surface time
	; TODO: these outputs would need to be done only once after surfacing...
	bsf		FLAG_TFT_depth_maximum_apnoe	; show max. depth of last dive
	bsf		FLAG_TFT_depth_maximum			; show max. depth of all  dives
	;bra	apnoe_calc_maxdepth				; calculate overall max. depth and return


;-----------------------------------------------------------------------------
; Helper Function - calculate Apnoe Mode overall maximum Depth
;
	global	apnoe_calc_maxdepth
apnoe_calc_maxdepth:
	MOVII	apnoe_max_pressure,     sub_a				; get max depth from all dives to far
	MOVII	pressure_rel_max_cached,sub_b				; get max depth of last dive
	call	cmpU16										; sub_a - sub_b = apnoe_max_pressure - pressure_rel_max_cached
	btfss	neg_flag									; last dive deeper than all the others before?
	return												; NO  - done
	MOVII	pressure_rel_max_cached,apnoe_max_pressure	; YES - store new overall max depth
	return												;     - done


;-----------------------------------------------------------------------------
; Manage and invoke the Deco Calculation Engine
;
callup_deco_engine:

	; Any reconfiguration done here only affects the deco calculation (prediction), not the
	; settings for the calculations done on the real tissues. The later ones are only altered
	; in case of a gas change, in case of a real bailout, or in case a switchback to setpoint
	; or sensor is done.
	; On event of a gas change, a diluent change, a real bailout, or a switchback, the settings
	; for the deco calculation are also automatically changed to match with the settings for the
	; real tissues. This is all done in the function 'gas_switch_common' which is triggered by
	; the flag 'request_gas_change'.

	; Deco Engine Calculation Schedules:
	;
	; Schedule  Dive Mode  Bailout  fTTS   Gas Needs    Plan    Deco Mode  calculated Functions
	; -----------------------------------------------------------------------------------------------------
	;
	;   1a)        OC       no       no      (yes)      norm       OC      TTS, CNS, deco plan, (gas needs)
	;                                                no alt plan
	;
	;   1b)        OC       no       YES     (yes)      norm       OC      TTS,  CNS, deco plan
	;                                                   alt        OC      fTTS, fCNS, (gas needs)
	;
	;   2a)       Loop      no       no       no        norm      Loop     TTS,  CNS, deco plan
	;                                                no alt plan
	;
	;   2b)       Loop      no       yes      no        norm      Loop     TTS,  CNS, deco plan
	;                                                   alt       Loop     fTTS, fCNS
	;
	;   2c)       Loop      no      (yes)     YES       norm      Loop     TTS,  CNS, deco plan
	;                                                   alt        OC      fTTS*, fCNS*, gas needs      <- "what if" BAILOUT
	;
	;   3)        Loop      YES      n/a     (yes)      norm       OC      TTS, deco plan, (gas needs)  <-   real    BAILOUT
	;                                                no alt plan
	; _____________________________________________________________________________________________________
	; norm: normal plan, alt: alternative plan, (): optional, n/a: not applicable
	; * the fTTS time is set to zero when in cave mode and the dive is in turned state


	; get working copies of char_O_main_status and char_O_deco_status
	movff	char_O_main_status,hi		; get char_O_main_status into hi
	movff	char_O_deco_status,lo		; get char_O_deco_status into lo

	; check state of deco calculations
	btfsc	request_restart_engine		; restart of the deco engine requested?
	bra		calc_deco_engine_restart	; YES - start a new normal plan
	btfsc	lo,DECO_COMPLETED_NORM		; NO  - finished calculations for normal plan?
	bra		calc_deco_engine_alt		;       YES - eventually do an alternative plan next
	btfsc	lo,DECO_COMPLETED_ALT		;       NO  - finished calculations for alternative plan?
	bra		calc_deco_engine_norm		;             YES - do a normal plan next
	bra		calc_deco_engine_exec		;             NO  - continue executing current calculation

calc_deco_engine_restart:
	bcf		request_restart_engine		; clear request flag
	bcf		lo,DECO_COMPLETED_NORM		; clear completion flag from normal plan if applicable
	;bra	calc_deco_engine_norm		; continue with calculating a normal plan


	; ---- normal plans ----
	;
calc_deco_engine_norm:
	bcf		lo,DECO_COMPLETED_ALT		; clear completion flag from alternative plan
 IFDEF _ccr_pscr
	btfsc	bailout_mode				; in real bailout?
	bra		calc_deco_engine_norm_3		; YES - configure real bailout schedule
	btfss	FLAG_oc_mode				; in OC dive mode?
	bra		calc_deco_engine_norm_2		; NO  - configure loop schedules
	;bra	calc_deco_engine_norm_1		; YES - configure OC   schedules
 ENDIF

calc_deco_engine_norm_1:
	; normal OC schedules
	TSTOSC	char_I_extra_time			; delay mode activated?
	bra		calc_deco_engine_norm_1b	; YES - schedule 1b in normal plan
	;bra	calc_deco_engine_norm_1a	; NO  - schedule 1a in normal plan

calc_deco_engine_norm_1a:
	; normal schedule 1a: OC with optional gas needs
;	bcf		lo,DECO_BAILOUT_FLAG		; switch off bailout mode						(will never be activated in this plan)
;	bcf		lo,DECO_DELAY_FLAG			; switch off delay mode							(will never be activated in this plan)
;	bcf		hi,DECO_VOLUME_FLAG			; switch off gas needs calculation by default	(if on, will always be on)
	TSTOSC	opt_calc_gasvolume			; shall calculate gas needs?
	bsf		hi,DECO_VOLUME_FLAG			; YES - switch on gas needs calculation
	bra		calc_deco_engine_norm_start	; start deco engine in normal plan

calc_deco_engine_norm_1b:
	; normal schedule 1b: OC without delay and gas needs
;	bcf		lo,DECO_BAILOUT_FLAG		; switch off bailout mode						(will never be activated in this plan)
	bcf		lo,DECO_DELAY_FLAG			; switch off delay mode
	bcf		hi,DECO_VOLUME_FLAG			; switch off gas needs calculation
	bra		calc_deco_engine_norm_start	; start deco engine in normal plan

 IFDEF _ccr_pscr
calc_deco_engine_norm_2:
	; normal loop schedules
	TSTOSC	opt_calc_gasvolume			; gas needs calculation activated?
	bra		calc_deco_engine_norm_2c	; YES - schedule  2c in normal plan
	;bra	calc_deco_engine_norm_2ab	; NO  - schedules 2a and 2b in normal plan are identical

calc_deco_engine_norm_2ab:
	; normal schedule 2a & 2b: loop without anything
	bcf		lo,DECO_BAILOUT_FLAG		; switch off bailout mode						(may return from real bailout)
;	bcf		hi,DECO_VOLUME_FLAG			; switch off gas needs calculation				(will never be activated in this plans)
	bcf		lo,DECO_DELAY_FLAG			; switch off delay mode							(may have been set in alt. plan 2b)
	bra		calc_deco_engine_norm_start	; start deco engine in normal plan

calc_deco_engine_norm_2c:
	; normal schedule 2c: loop with switch-back from simulated bailout
	; switch to CCR/pSCR
	movf	active_dil,W				; get current diluent
	call	deco_setup_cc_diluents_pre	; set up deco calculation in CCR/pSCR mode with diluents
calc_deco_engine_norm_2c_XX:
	bcf		lo,DECO_BAILOUT_FLAG		; switch off bailout mode						(may return from real bailout)
	bcf		hi,DECO_VOLUME_FLAG			; switch off gas needs calculation
	bcf		lo,DECO_DELAY_FLAG			; switch off delay mode
	bra		calc_deco_engine_norm_start	; start deco engine in normal plan

calc_deco_engine_norm_3:
	; real bailout schedule
	bcf		lo,DECO_DELAY_FLAG			; switch off delay mode
	bcf		hi,DECO_VOLUME_FLAG			; switch off gas needs calculation by default
	TSTOSC	opt_calc_gasvolume			; shall calculate gas needs?
	bsf		hi,DECO_VOLUME_FLAG			; YES - switch on gas needs calculation
	bsf		lo,DECO_BAILOUT_FLAG		; switch on bailout mode
	;bra	calc_deco_engine_norm_start	; start deco engine in normal plan
 ENDIF	; _ccr_pscr

calc_deco_engine_norm_start:
	bsf		lo,DECO_START_NORM			; calculate a normal plan
	bra		calc_deco_engine_start		; start deco engine


	; ---- alternative plans ----
	;
calc_deco_engine_alt:
	bcf		lo,DECO_COMPLETED_NORM		; clear completion flag from normal plan
 IFDEF _ccr_pscr
	btfsc	bailout_mode				; in real bailout?
	bra		calc_deco_engine_norm_3		; YES - schedule 3 has no alternative plan
	btfss	FLAG_oc_mode				; in OC dive mode?
	bra		calc_deco_engine_alt_2		; NO  - loop schedules
	;bra	calc_deco_engine_alt_1		; YES - OC   schedules
 ENDIF	; _ccr_pscr

calc_deco_engine_alt_1:
	; alternative OC schedules
	TSTOSS	char_I_extra_time			; delay mode activated?
	bra		calc_deco_engine_norm_1a	; NO  - schedule 1a has no alternative plan
 IFDEF _cave_mode
	btfsc	dive_turned					; YES - in cave mode and dive turned?
	bra		calc_deco_engine_norm_1a	;       YES - suppress delay mode -> do schedule 1a in normal plan
 ENDIF
	;bra	calc_deco_engine_alt_1b		;       NO  - do schedule 1b in alternative plan

calc_deco_engine_alt_1b:
	; alternative schedule 1b: OC with delay and optional gas needs
;	bcf		lo,DECO_BAILOUT_FLAG		; switch off bailout mode						(will never be activated in this plan)
;	bcf		hi,DECO_VOLUME_FLAG			; switch off gas needs calculation by default	(comes in switched off state)
	TSTOSC	opt_calc_gasvolume			; shall calculate gas needs?
	bsf		hi,DECO_VOLUME_FLAG			; YES - switch on gas needs calculation
	bsf		lo,DECO_DELAY_FLAG			; switch on delay mode
	bra		calc_deco_engine_alt_start	; start deco engine in alternative plan

 IFDEF _ccr_pscr
calc_deco_engine_alt_2:
	; alternative loop schedules
	TSTOSC	opt_calc_gasvolume			; gas needs calculation activated?
	bra		calc_deco_engine_alt_2c		; YES - 2c in alternative plan
	TSTOSS	char_I_extra_time			; NO  - delay mode activated?
	bra		calc_deco_engine_norm_2ab	;       NO  - schedule 2a has no alternative plan
	;bra	calc_deco_engine_alt_2b		;       YES - schedule 2b in alternative plan

calc_deco_engine_alt_2b:
	; alternative schedule 2b: loop with delay
;	bcf		lo,DECO_BAILOUT_FLAG		; switch off bailout mode						(will be deactivated in normal plan)
;	bcf		hi,DECO_VOLUME_FLAG			; switch off gas needs calculation				(will never be activated in this plan)
	bsf		lo,DECO_DELAY_FLAG			; switch on  delay mode
	bra		calc_deco_engine_alt_start	; start deco engine in normal plan

calc_deco_engine_alt_2c:
	; alternative schedule 2c: simulated bailout (if possible)
	decf	best_gas_number,W			; get best gas number -1 into WREG. If not available, WREG will be 255 now. If not computed yet, WREG will be 254 now.
	btfsc	WREG,7						; WREG < 128 (a bailout gas is available)?
	bra		calc_deco_engine_alt_2c_XX	; NO  - no bailout plan possible because no bailout gas available to switch to
	movf	best_gas_number,W			; YES - get number of best gas into WREG
	call	deco_setup_oc_gases_pre		;     - set up deco calculation in OC mode with OC gases
;	bcf		lo,DECO_DELAY_FLAG			;     - switch off delay mode by default		(comes in switched off state)
	TSTOSC	char_I_extra_time			;     - delay mode activated?
	bsf		lo,DECO_DELAY_FLAG			;       YES - switch on delay mode
 IFDEF _cave_mode
	btfsc	dive_turned					;       in cave mode and dive turned?
	bcf		lo,DECO_DELAY_FLAG			;       YES - suppress delay mode
 ENDIF
	bsf		lo,DECO_BAILOUT_FLAG		;     - switch on bailout mode
	bsf		hi,DECO_VOLUME_FLAG			;     - switch on gas needs calculation
	bra		calc_deco_engine_alt_start	;     - start deco engine in alternative plan
calc_deco_engine_alt_2c_XX:
	call	inval_alternative_plan_data	; invalidate all alternative (bailout) plan data because they are not applicable any more
	bra		calc_deco_engine_norm_start	; continue calculating as normal plan
 ENDIF	; _ccr_pscr

calc_deco_engine_alt_start:
	bsf		lo,DECO_START_ALT			; calculate an alternative plan
	;bra	calc_deco_engine_start		; start deco engine


	; ---- start deco engine ----
	;
calc_deco_engine_start:
 IFDEF _cave_mode
	bcf		hi,DECO_CAVE_MODE			; deactivate cave mode by default
	btfss	cave_mode					; cave mode switched on?
	bra		calc_deco_engine_start_1	; NO  - keep deactivated, no backtracking depth recording
	bsf		hi,DECO_CAVE_MODE			; YES - activate cave mode
	btfss	dive_turned					;     - dive turned?
	call	write_backtrack_deltatime	;       NO  - update current delta time
 ENDIF
calc_deco_engine_start_1:
	movff	hi,char_O_main_status		; write-back char_O_main_status to deco engine interface
	movff	lo,char_O_deco_status		; write-back char_O_deco_status to deco engine interface

calc_deco_engine_exec:
;	+++++++++++++++++++++++++++++++++++++
	bsf		tmr5_preemtion_allowed		; grant  preemption allowance for timer 5 (deco engine)
	call	deco_calc_hauptroutine		; invoke the deco engine (C-code)
	banksel	common						; back to bank common
	bcf		tmr5_preemtion_allowed		; revoke preemption allowance
;	+++++++++++++++++++++++++++++++++++++

 ifdef _debug_output
	call	TFT_debug_output			; debug output of scheduling performance data
 endif

	; check if new calculation results for normal plan mode are available
	movff	char_O_deco_status,WREG		; get deco status of deco engine
	btfsc	WREG,DECO_COMPLETED_NORM	; new calculation results for normal plan available?
	bsf		new_deco_data_avail			; YES - set flag for new NDL or deco data available

	return								; done


 IFDEF _ccr_pscr
 IFDEF _external_sensor

;-----------------------------------------------------------------------------
; Process Sensor Readings
;
	global	calc_deko_divemode_sensor
calc_deko_divemode_sensor:
	btfsc	ext_input_optical				; do we have an optical interface?
	bra		calc_deko_divemode_sensor_opt	; YES - process received data
	btfss	ext_input_s8_ana				; NO  - do we have a S8/analog interface?
	return									;       NO  - nothing to do, done
	TSTOSS	opt_s8_mode						;       YES - shall use S8 interface?
	bra		calc_deko_divemode_sensor_ana	;           - NO  - use analog interface
	;bra	calc_deko_divemode_sensor_s8	;             YES - use S8     interface

calc_deko_divemode_sensor_s8:
	btfss	trigger_S8_data_update			; new data frame available?
	bra		calc_deko_divemode_sensor_common; NO  - use old values
	bcf		trigger_S8_data_update			; YES - clear update flag
	call	compute_mvolts_from_rawdata	;     - compute mV values from digital data
	bra		calc_deko_divemode_sensor_common;     - continue with common part

calc_deko_divemode_sensor_opt:
	; sensor1_ppO2, sensor2_ppO2 and sensor3_ppO2 are already filled in ISR
	btfss	sensor1_active					; check HUD status data and eventually clear use_O2_sensorX
	bcf		use_O2_sensor1					; ...
	btfss	sensor2_active					; ...
	bcf		use_O2_sensor2					; ...
	btfss	sensor3_active					; ...
	bcf		use_O2_sensor3					; ...
	bra		check_sensor_avg				; continue with calculating sensor average

calc_deko_divemode_sensor_ana:
	call	get_analog_inputs				; get the analog voltages and continue with the common part
	;bra	calc_deko_divemode_sensor_common; continue with common part

calc_deko_divemode_sensor_common:

	; Check each sensor if it is calibrated and if its mV value is within min_mv and max_mv limits.
	; If     ok: compute o2_ppo2_sensorX = o2_mv_sensorX * opt_x_sX / 1000
	; If not ok: reset   o2_ppo2_sensorX, reset use_O2_sensorX and show the customview 1 in case the sensor was ok before

	; check sensor 1
	btfss	sensor1_calibrated_ok		; check if sensor is usable at all
	bra		check_sensor_1_fail			; NO  - handle it as failed
	SMOVII	sensor1_mv,sub_a			; YES - load sensor mV value

	; check min threshold
	rcall	check_min_threshold			; check if sensor mV is outside minimum
	btfsc	neg_flag					; check if result is negative, i.e. sensor_mv < min_mv
	bra		check_sensor_1_fail			; YES - declare sensor as failed

	; check max_threshold
	rcall	check_max_threshold			; check if sensor mV is outside maximum
	btfss	neg_flag					; check if result is negative, i.e. sensor_mv < max_mv
	bra		check_sensor_1_fail			; NO  - declare sensor as failed

	; check HUD data, if available
	btfss	hud_connection_ok			; check if there is a HUD connected
	bra		check_sensor_1_ok			; NO  - all checks done then and positive
	btfss	sensor1_active				; YES - HUD status ok?
	bra		check_sensor_1_fail			;       NO - HUD reports a fail

check_sensor_1_ok:
	; sensor1_ppO2 = sensor1_mv:2 * opt_x_s1:2 / 1000
	SMOVII	sensor1_mv,xA				; get sensor mV          into xA
	MOVII	opt_x_s1,  xB				; get calibration factor into xB
	rcall	compute_ppo2_helper			; compute ppO2
	movff	xC+0,sensor1_ppO2			; result in 0.01 bar
	bcf		attn_det_sensor1_lost		; clear attention
	bcf		shown_sensor1_fail			; re-arm custom-view show-up
	bra		check_sensor_2				; continue with next sensor

check_sensor_1_fail:
	clrf	WREG						; set ppO2 reading to zero
	movff	WREG,sensor1_ppO2			; ...
	btfsc	use_O2_sensor1				; check if sensor is in use
	bsf		attn_det_sensor1_lost		; YES - set an attention
	bcf		use_O2_sensor1				; revoke sensor from usage

check_sensor_2:
	; check sensor 2
	btfss	sensor2_calibrated_ok		; check if sensor is usable at all
	bra		check_sensor_2_fail			; NO  - handle it as failed
	SMOVII	sensor2_mv,sub_a			; YES - load sensor mV value

	; check min threshold
	rcall	check_min_threshold			; check if sensor mV is outside minimum
	btfsc	neg_flag					; check if result is negative, i.e. sensor_mv < min_mv
	bra		check_sensor_2_fail			; YES - declare sensor as failed

	; check max_threshold
	rcall	check_max_threshold			; check if sensor mV is outside maximum
	btfss	neg_flag					; check if result is nagative, i.e. sensor_mv < max_mv
	bra		check_sensor_2_fail			; NO  - declare sensor as failed

	; check HUD data, if available
	btfss	hud_connection_ok			; check if there is a HUD connected
	bra		check_sensor_2_ok			; NO  - all checks done then and positive
	btfss	sensor2_active				; YES - HUD status ok?
	bra		check_sensor_2_fail			;       NO - HUD reports a fail

check_sensor_2_ok:
	; sensor2_ppO2 = sensor2_mv:2 * opt_x_s2:2 / 1000
	SMOVII	sensor2_mv,xA				; get sensor mV          into xA
	MOVII	opt_x_s2,  xB				; get calibration factor into xB
	rcall	compute_ppo2_helper			; compute ppO2
	movff	xC+0,sensor2_ppO2			; result in 0.01 bar
	bcf		attn_det_sensor2_lost		; clear attention
	bcf		shown_sensor2_fail			; re-arm custom-view show-up
	bra		check_sensor_3				; continue with next sensor

check_sensor_2_fail:
	clrf	WREG						; set ppO2 reading to zero
	movff	WREG,sensor2_ppO2			; ...
	btfsc	use_O2_sensor2				; check if sensor is in use
	bsf		attn_det_sensor2_lost		; YES - set an attention
	bcf		use_O2_sensor2				; revoke sensor from usage

check_sensor_3:
	; check sensor 3
	btfss	sensor3_calibrated_ok		; check if sensor is usable at all
	bra		check_sensor_3_fail			; NO  - handle it as failed
	SMOVII	sensor3_mv,sub_a			; YES - load sensor mV value

	; check min threshold
	rcall	check_min_threshold			; check if sensor mV is outside minimum
	btfsc	neg_flag					; check if result is negative, i.e. sensor_mv < min_mv
	bra		check_sensor_3_fail			; YES - declare sensor as failed

	; check max threshold
	rcall	check_max_threshold			; check if sensor mV is outside maximum
	btfss	neg_flag					; check if result is negative, i.e. sensor_mv < max_mv
	bra		check_sensor_3_fail			; NO  - declare sensor as failed

	; check HUD data, if available
	btfss	hud_connection_ok			; check if there is a HUD connected
	bra		check_sensor_3_ok			; NO  - all checks done then and positive
	btfss	sensor3_active				; YES - HUD status ok?
	bra		check_sensor_3_fail			;       NO - HUD reports a fail

check_sensor_3_ok:
	; sensor3_ppO2 = sensor3_mv:2 * opt_x_s1:2 / 1000
	SMOVII	sensor3_mv,xA				; get sensor mV          into xA
	MOVII	opt_x_s3,  xB				; get calibration factor into xB
	rcall	compute_ppo2_helper			; compute ppO2
	movff	xC+0,sensor3_ppO2			; result in 0.01 bar
	bcf		attn_det_sensor3_lost		; clear attention
	bcf		shown_sensor3_fail			; re-arm custom-view show-up
	bra		check_sensor_avg			; continue with calculating sensor average

check_sensor_3_fail:
	clrf	WREG						; set ppO2 reading to zero
	movff	WREG,sensor3_ppO2			; ...
	btfsc	use_O2_sensor3				; check if sensor is in use
	bsf		attn_det_sensor3_lost		; YES - set an attention
	bcf		use_O2_sensor3				; revoke sensor from usage

check_sensor_avg:
	; calculate sensor average
	btfss	divemode					; in dive mode?
	return								; NO - done here if not in dive mode

	; compute sensor_setpoint = average of all o2_ppo2_sensorX of
	; those sensors that have use_O2_sensorX == true

	CLRI	xA							; clear sum of sensor values
	CLRI	xB							; clear number of active sensors found

check_sensor_avg_1:
	btfss	use_O2_sensor1				; sensor 1 active?
	bra		check_sensor_avg_2			; NO
	movff	sensor1_ppO2,WREG			; YES - get ppO2
	addwf	xA+0,F						;     - add into xA:2
	movlw	.0							;     - ...
	addwfc	xA+1,F						;     - ... 
	incf	xB+0,F						;     - add a sensor

check_sensor_avg_2:
	btfss	use_O2_sensor2				; sensor 2 active?
	bra		check_sensor_avg_3			; NO
	movff	sensor2_ppO2,WREG			; YES - get ppO2
	addwf	xA+0,F						;     - add into xA:2
	movlw	.0							;     - ...
	addwfc	xA+1,F						;     - ...
	incf	xB+0,F						;     - add a sensor

check_sensor_avg_3:
	btfss	use_O2_sensor3				; sensor 3 active?
	bra		check_sensor_avg_compute	; NO
	movff	sensor3_ppO2,WREG			; YES - get ppO2
	addwf	xA+0,F						;     - add into xA:2
	movlw	.0							;     - ...
	addwfc	xA+1,F						;     - ...
	incf	xB+0,F						;      add a sensor

check_sensor_avg_compute:
	; divide sum of sensor values by number of active sensors found
	clrf	xC+0						; set zero as default result
	tstfsz	xB+0						; pending div/0 ?
	call	div16x16					; NO - execute xC = xA / xB = summed ppO2 / number of sensors
	movff	xC+0,sensor_setpoint		; copy result (or its default)

	; set default value for pSCR mode: 0 => let p2_deco.c compute the ppO2 based on current dil gas and depth
	; will be overwritten later in case we are in sensor mode and have at least one usable sensor
	clrf	WREG						; pre-load a zero
	btfsc	FLAG_pscr_mode				; check if we are in pSCR mode
	movff	WREG,char_I_const_ppO2		; YES - write 0 to char_I_const_ppo2,
										;       it will be overwritten if we have a usable sensor reading
	btfsc	bailout_mode				; check if we are in bailout
	bra		check_sensor_vote			; YES - no sensor data transfer to char_I_const_ppO2 in this case
	movf	dive_ccr_mode,W				; NO  - get mode (0: Fixed SP, 1: Sensor, 2: Auto SP)
	sublw	.1							;     - in sensor mode?
	bnz		check_sensor_vote			;       NO  - not in sensor mode - no transfer of sensor data to char_I_const_ppO2
	tstfsz	xB+0						;       YES - check if we have found at least one usable sensor
	bra		check_sensor_avg_use		;             YES - we have at least one usable sensor
	bsf		warn_det_sensors_lost		;             NO  - we have NO usable sensors
	btfsc	FLAG_ccr_mode				;                 - check if we are in CCR mode
	movff	opt_setpoint_cbar+0,char_I_const_ppO2 ;         YES - select fixed setpoint no. 1 for fallback
	bra		check_sensor_vote			;                       - continue with voting logic flags

check_sensor_avg_use:
	; we have at least one usable sensor with a ppO2 value > 0
	bcf		warn_det_sensors_lost				; clear warning
	bcf		shown_sensors_lost					; re-arm custom view show-up
	movff	sensor_setpoint,char_I_const_ppO2	; transfer average sensor value to p2_deco.c code

check_sensor_vote:
	; check if individual sensors agree with their average
	bsf		voting_logic_sensor1		; default sensor to be within voting
	movff	sensor1_ppO2,WREG			; get sensor's ppO2
	rcall	check_sensor_voting_helper	; check if sensor is within +/- range around setpoint
	tstfsz	WREG						; sensor within range (WREG = 0)?
	bcf		voting_logic_sensor1		; NO - vote out this sensor

	bsf		voting_logic_sensor2		; default sensor to be within voting
	movff	sensor2_ppO2,WREG			; get sensor's ppO2
	rcall	check_sensor_voting_helper	; check if sensor is within +/- range around setpoint
	tstfsz	WREG						; sensor within range (WREG = 0)?
	bcf		voting_logic_sensor2		; NO - vote out this sensor

	bsf		voting_logic_sensor3		; default sensor to be within voting
	movff	sensor3_ppO2,WREG			; get sensor's ppO2
	rcall	check_sensor_voting_helper	; check if sensor is within +/- range around setpoint
	tstfsz	WREG						; sensor within range (WREG = 0)?
	bcf		voting_logic_sensor3		; NO - vote out this sensor

	; check if a warning shall be issued on sensor disagreement
	btfsc	FLAG_ccr_mode				; check if we are in CCR mode
	bra		check_warn_sensor_0			; YES - continue with further checks
	btfsc	FLAG_pscr_mode				; check if we are in pSCR mode
	bra		check_warn_sensor_0			; YES - continue with further checks
	bra		check_warn_sensor_done		; not in CCR and not in pSCR, so no warning

check_warn_sensor_0:					; we are in CCR or pSCR mode
	btfsc	bailout_mode				; check if we are in bailout
	bra		check_warn_sensor_done		; YES - no warning in this case
	movf	dive_ccr_mode,W				; get mode (0: Fixed SP, 1: Sensor, 2: Auto SP)
	sublw	.1							; in sensor mode?
	bnz		check_warn_sensor_done		; NO - not in sensor mode - no warning in this case

check_warn_sensor_1:
	btfss	sensor1_calibrated_ok		; check if sensor has a valid calibration
	bra		check_warn_sensor_2			; NO  - sensor can not cause a warning then
	btfss	use_O2_sensor1				; YES - check if sensor is in use
	bra		check_warn_sensor_2			;       NO  - sensor can not cause a warning then
	btfsc	voting_logic_sensor1		;       YES - check if sensor value is within agreement range
	bra		check_warn_sensor_2			;             YES - continue with next sensor
	bsf		warn_det_sensors_div		;             NO  - sensors divergence
	return								;                 - done

check_warn_sensor_2:
	btfss	sensor2_calibrated_ok		; check if sensor has a valid calibration
	bra		check_warn_sensor_3			; NO  - sensor can not cause a warning then
	btfss	use_O2_sensor2				; YES - check if sensor is in use
	bra		check_warn_sensor_3			;       NO  - sensor can not cause a warning then
	btfsc	voting_logic_sensor2		;       YES - check if sensor value is within agreement range
	bra		check_warn_sensor_3			;             YES - continue with next sensor
	bsf		warn_det_sensors_div		;             NO  - sensors divergence
	return								;                 - done

check_warn_sensor_3:
	btfss	sensor3_calibrated_ok		; check if sensor has a valid calibration
	bra		check_warn_sensor_agree		; NO  - sensor can not cause a warning then
	btfss	use_O2_sensor3				; YES - check if sensor is in use
	bra		check_warn_sensor_agree		;       NO  - sensor can not cause a warning then
	btfsc	voting_logic_sensor3		;       YES - check if sensor value is within agreement range
	bra		check_warn_sensor_agree		;             YES - continue with next sensor
	bsf		warn_det_sensors_div		;             NO  - set warning
	return								;                 - done

check_warn_sensor_done:
check_warn_sensor_agree:
	bcf		warn_det_sensors_div		; clear warning
	bcf		shown_sensors_diverg		; re-arm custom view show-up
	return								; done


;-----------------------------------------------------------------------------
; Helper Function - check if sensor mV is outside minimum
;
check_min_threshold:
	MOVLI	min_mv,sub_b				; load minimum mV value
	goto	sub16						; sub_c = sensor_mv - min_mv (and return)


;-----------------------------------------------------------------------------
; Helper Function - check if sensor mV is outside maximum
;
check_max_threshold:
	MOVLI	max_mv,sub_b				; load maximum mV value
	goto	sub16						; sub_c = sensor_mv - max_mv (and return)


;-----------------------------------------------------------------------------
; Helper Function - compute ppO2 from sensor mV and calibration factor
;
compute_ppo2_helper:
	call	mult16x16					; xC:4 = xA:2 * xB:2
	MOVLI	.1000,xB					; load scaling factor
	call	div32x16					; xC:4 = xC:4 / xB:2 with xA as remainder
	tstfsz	xC+1						; is the ppO2 higher than 2.55 bar?
	setf	xC+0						; YES - set result to 255 aka 2.55 bar
	return								; done


;-----------------------------------------------------------------------------
; Helper Function - check if sensor is within +/- range around setpoint
;
check_sensor_voting_helper:
	subwf	sensor_setpoint,W				; deviation = setpoint - sensor ppO2
	btfsc	STATUS,N						; result negative?
	negf	WREG,W							; YES - negate deviation
	sublw	sensor_voting_logic_threshold	; WREG = threshold - deviation
	btfss	STATUS,N						; result negative?
	retlw	.0								; NO  - within range
	retlw	.1								; YES - out of range

;	cpfsgt	sensor_setpoint					; sensor ppO2 > setpoint?
;	bra		check_sensor_voting_helper_2	; NO
;	;bra	check_sensor_voting_helper_1	; YES
;
;check_sensor_voting_helper_1:
;	subwf	sensor_setpoint,W				; WREG = setpoint - sensor ppO2
;	bra		check_sensor_voting_helper_com	; continue with common part
;
;check_sensor_voting_helper_2:
;	movwf	lo								; copy sensor ppO2 to lo
;	movf	sensor_setpoint,W				; copy setpoint    to WREG
;	subwf	lo,W							; WREG = sensor ppO2 - setpoint
;	;bra	check_sensor_voting_helper_com	; continue with common part
;
;check_sensor_voting_helper_com:
;	movwf	lo								; copy deviation to lo
;	movlw	sensor_voting_logic_threshold	; load threshold in 0.01 bar
;	cpfsgt	lo								; deviation > threshold ?
;	retlw	.0								; NO  - within range
;	retlw	.1								; YES - out of range

 ENDIF	; _external_sensor
 ENDIF	; _ccr_pscr


 IFDEF _cave_mode

;-----------------------------------------------------------------------------
; Cave Mode - on/off Switching
;
cavemode_toggle_onoff:
	bcf		request_cave_toggle			; clear request flag
	btg		cave_mode					; toggle the on/off state
	return								; done


;-----------------------------------------------------------------------------
; Cave Mode - switch off and set Dive as turned
;
cavemode_switch_off_turned:
	bcf		request_cave_off_turned		; clear request flag
	bcf		cave_mode					; switch cave mode off
	bra		cavemode_turndive_turn_exec ; set dive as turned (and return)


;-----------------------------------------------------------------------------
; Cave Mode - check if 'turn dive' is allowed
;
	global	cavemode_turndive_check
cavemode_turndive_check:
	btfss	cave_mode					; cave mode switched on?
	retlw	1							; NO - signal not allowed
	btfss	dive_turned					; YES - is the dive currently turned?
	retlw	0							;       NO  - command is allowed
	movf	backtrack_waypoint_turn,W	;       YES - copy turn point number to WREG
	cpfslt	backtrack_waypoint_num		;           - current waypoint number < turn point number ?
	retlw	1							;             NO  - signal not allowed
	retlw	0							;             YES - command is allowed


;-----------------------------------------------------------------------------
; Cave Mode - execute 'turn dive' toggle
;
cavemode_turndive_toggle:
	bcf		request_turn_toggle			; clear request flag
	rcall	cavemode_turndive_check		; check if command is allowed
	tstfsz	WREG						; command allowed?
	return								; NO  - abort
	btfss	dive_turned					; YES - is the dive currently turned?
	bra		cavemode_turndive_turn_exec	;       NO  - turn the dive
	bcf		dive_turned					;       YES - set dive         as not turned    any more
	bcf		backtrack_shutdown			;           - set backtracking as not shut down any more
	call	set_logbook_marker			;           - set a logbook marker
	goto	resume_backtrack_recording	;           - append further logging after current waypoint and return


;-----------------------------------------------------------------------------
; Cave Mode - set the dive as turned
;
cavemode_turndive_turn:
	bcf		request_turn_turn			; clear request flag
	btfss	cave_mode					; cave mode switched on?
	return								; NO  - abort
	btfsc	dive_turned					; YES - is the dive already turned?
	return								;       YES - nothing to do any more
cavemode_turndive_turn_exec:
	bsf		dive_turned					;       NO  - set dive as turned
	call	set_logbook_marker			;           - set a logbook marker
	goto	write_backtrack_turnpoint	;           - write a turn-point waypoint and return


;-----------------------------------------------------------------------------
; Cave Mode - check if setting a Waypoint is allowed
;
	global	cavemode_waypoint_set_check
cavemode_waypoint_set_check:
	btfss	cave_mode					; cave mode switched on?
	retlw	1							; NO - command not allowed
	btfsc	dive_turned					; YES - is the dive turned?
	retlw	1							;       YES - no setting of waypoints on way out, command not allowed
	btfsc	backtrack_entire_full		;       NO  - storage entirely used up?
	retlw	1							;             YES - out of storage capacity, command not allowed
	movlw	backtrack_waypoint_max		;             NO  - get highest allowed waypoint number
	cpfslt	backtrack_waypoint_num		;                 - current waypoint number < max allowed number?
	retlw	1							;                   NO  - command not allowed
	retlw	0							;                   YES - command is  allowed


;-----------------------------------------------------------------------------
; Cave Mode - set a Waypoint
;
cavemode_waypoint_set:
	bcf		request_waypoint_set		; clear request flag
	rcall	cavemode_waypoint_set_check	; check if command is allowed to execute
	tstfsz	WREG						; command allowed?
	return								; NO  - no waypoint setting possible, abort
	call	set_logbook_marker			; YES - set a logbook marker
	goto	write_backtrack_waypoint	;     - execute command (and return)


;-----------------------------------------------------------------------------
; Cave Mode - check if stepping one Waypoint outwards is allowed
;
	global	cavemode_waypoint_out_check
cavemode_waypoint_out_check:
	btfss	cave_mode					; cave mode switched on?
	retlw	1							; NO - command not allowed
	btfss	dive_turned					; YES - is the dive turned?
	retlw	1							;       NO  - no stepping back on way in, command not allowed
	btfsc	waypoint_reached_first		;       YES - already at first waypoint?
	retlw	1							;             YES - command not allowed
	retlw	0							;             NO  - command is  allowed


;-----------------------------------------------------------------------------
; Cave Mode - step one Waypoint outwards
;
cavemode_waypoint_out:
	bcf		request_waypoint_out		; clear request flag
	rcall	cavemode_waypoint_out_check	; check if command is allowed to execute
	tstfsz	WREG						; command allowed?
	return								; NO  - no further out possible, abort
	goto	backtrack_waypoint_go_out	; YES - execute the command (and return)


;-----------------------------------------------------------------------------
; Cave Mode - check if stepping one Waypoint inwards is allowed
;
	global	cavemode_waypoint_in_check
cavemode_waypoint_in_check:
	btfss	cave_mode					; cave mode switched on?
	retlw	1							; NO - command not allowed
	btfss	dive_turned					; YES - is the dive turned?
	retlw	1							;       NO  - no stepping forward on way in, command not allowed
	btfsc	waypoint_reached_last		;       YES - already at last waypoint?
	retlw	1							;             YES - command not allowed
	retlw	0							;             NO  - command is  allowed


;-----------------------------------------------------------------------------
; Cave Mode - step one Waypoint inwards
;
cavemode_waypoint_in:
	bcf		request_waypoint_in			; clear request flag
	rcall	cavemode_waypoint_in_check	; check if command is allowed to execute
	tstfsz	WREG						; command allowed?
	return								; NO  - no further in possible, abort
	goto	backtrack_waypoint_go_in	; YES - execute command (and return)


;-----------------------------------------------------------------------------
; Cave Mode - store current Delta Time
;
write_backtrack_deltatime:
	rcall	setup_backtrack_index				; setup writing position
	bra		write_backtrack_datum_deltatime		; store the current delta time (and return)


;-----------------------------------------------------------------------------
; Cave Mode - store a Backtracking Depth Data Set
;
write_backtrack_1min_depth:
	rcall	setup_backtrack_index				; setup writing position
	rcall	write_backtrack_datum_depth			; store depth
	rcall	write_backtrack_datum_zerotime		; reset the time elapsed since last depth recording and store it
	bra		write_backtrack_datum_check			; store new writing position, check remaining storage capacity ()and return)


;-----------------------------------------------------------------------------
; Cave Mode - store a Waypoint
;
write_backtrack_waypoint:
	rcall	setup_backtrack_index				; setup writing position
	rcall	write_backtrack_datum_deltatime		; store the time elapsed since last depth recording
	movf	POSTINC1,W							; dummy read to increment the writing position index
	rcall	write_backtrack_datum_depth			; store depth
	rcall	write_backtrack_datum_gas			; store gas availability vector
	rcall	write_backtrack_datum_waypoint		; store waypoint number
	rcall	write_backtrack_datum_zerotime		; reset the time elapsed since last depth recording and store it
	bra		write_backtrack_datum_check			; store new writing position, check remaining storage capacity (and return)


;-----------------------------------------------------------------------------
; Cave Mode - store a Turn Point
write_backtrack_turnpoint:
	rcall	write_backtrack_waypoint			; write a waypoint (see above)
	movf	POSTDEC1,W							; dummy read to decrement the position index to the waypoint number datum
	movff	FSR1L,char_I_backtrack_index		; store updated writing position
	movff	backtrack_waypoint_num,backtrack_waypoint_turn; memorize this waypoint as turn point
	return										; done


;-----------------------------------------------------------------------------
; Cave Mode - append further Logging after current Waypoint
;
resume_backtrack_recording:
	clrf	backtrack_waypoint_turn				; clear turn point reference
	bsf		waypoint_reached_last				; declare to be at last waypoint now
	rcall	setup_backtrack_index				; setup index position
	movf	POSTINC1,W							; dummy read to increment the position index to the delta time datum
	rcall	write_backtrack_datum_zerotime		; reset the time elapsed since last depth recording and store it
	bra		write_backtrack_datum_check			; store new writing position, check remaining storage capacity (and return)


;-----------------------------------------------------------------------------
; Cave Mode - execute stepping one Waypoint outwards
;
backtrack_waypoint_go_out:
	bcf		waypoint_reached_last				; not at last waypoint (or turn point) any more
	rcall	setup_backtrack_index				; setup index position
	movlw	b'11100000'-.1						; a waypoint datum has bits 5-7 set, -1 because of cpfsgt
backtrack_waypoint_go_out_loop:
	movff	POSTDEC1,lo							; dummy read current datum and go to previous datum (there is no PREDEC)
	cpfsgt	INDF1								; read datum, is it a waypoint datum?
	bra		backtrack_waypoint_go_out_loop		; NO - try next datum
	movff	FSR1L,char_I_backtrack_index		; store new index position
	movf	INDF1,W								; copy waypoint datum to WREG
	andlw	b'00011111'							; remove waypoint tag
	movwf	backtrack_waypoint_num				; store new waypoint number
	movlw	.1									; number of first waypoint
	cpfsgt	backtrack_waypoint_num				; current waypoint number > number of first waypoint ?
	bsf		waypoint_reached_first				; NO - reached first waypoint
	goto	restart_deco_engine_wo_norm			; invalidate all alternative plan data and restart deco engine


;-----------------------------------------------------------------------------
; Cave Mode - execute stepping one Waypoint inwards
;
backtrack_waypoint_go_in:
	bcf		waypoint_reached_first				; not at first waypoint any more
	rcall	setup_backtrack_index				; setup index position
	movlw	b'11100000'-.1						; a waypoint datum has bits 5-7 set, -1 because of cpfsgt
backtrack_waypoint_go_in_loop:
	cpfsgt	PREINC1								; go to next datum, read it, is it a waypoint datum?
	bra		backtrack_waypoint_go_in_loop		; NO - try next datum
	movff	FSR1L,char_I_backtrack_index		; store new index position
	movf	INDF1,W								; copy waypoint datum to WREG
	andlw	b'00011111'							; remove waypoint tag
	movwf	backtrack_waypoint_num				; store new waypoint number
	movf	backtrack_waypoint_turn,W			; load WREG with waypoint number of turn point
	cpfslt	backtrack_waypoint_num				; new waypoint number < number of turn point ?
	bsf		waypoint_reached_last				; NO - reached last waypoint
	goto	restart_deco_engine_wo_norm			; invalidate all alternative plan data and restart deco engine


;-----------------------------------------------------------------------------
; Cave Mode Helper Function - set up Index Position
;
setup_backtrack_index:
	lfsr	FSR1,char_I_backtrack_storage		; load   FSR1 with base address of the backtracking storage
	movff	char_I_backtrack_index,FSR1L		; adjust FSR1 to the current index position
	return


;-----------------------------------------------------------------------------
; Cave Mode Helper Function - reset Time since last Depth Recording and store it
;
write_backtrack_datum_zerotime:
	clrf	backtrack_deltatime					; reset the time elapsed since last depth recording
	;bra	write_backtrack_datum_deltatime		; store the time


;-----------------------------------------------------------------------------
; Cave Mode Helper Function - store Time elapsed since last Depth Recording
;
write_backtrack_datum_deltatime:
	movf	backtrack_deltatime,W				; get   the time elapsed since last depth recording
	bsf		WREG,7								; add   the time marker (bit 7 set) to the time stored in WREG
	movwf	INDF1								; write the time and keep the writing position index pointing on it
	return										; done


;-----------------------------------------------------------------------------
; Cave Mode Helper Function - store Depth
;
write_backtrack_datum_depth:
	movf	depth_meter,W						; get current depth in meters into WREG
	btfsc	WREG,7								; current depth < 128 m ?
	movlw	.127								; NO - clip depth to 127 meters (protect time marker bit)
	movwf	POSTINC1							; write the depth entry and increment the writing position index
	return										; done


;-----------------------------------------------------------------------------
; Cave Mode Helper Function - store Gas Availability Vector
;
write_backtrack_datum_gas:
	; Cave mode is currently only available with gas needs calculation enabled,
	; so deco mode is either OC anyhow or CCR/pSCR in bailout mode. Hence it is
	; always the OC (bailout) gases whose staging status needs to be stored.
	lfsr	FSR2,opt_gas_type					; load base address of the OC/bailout gas types
	movlw	NUM_GAS								; load number of gases
	movwf	lo									; initialize loop counter
	movlw	b'00000001'							; load  gas bit pattern for the first gas
	movwf	hi									; store gas bit pattern in hi
	movlw	b'11000000'							; initialize WREG with the gas staging status tag
write_backtrack_datum_gas_loop:
	movff	POSTINC2,up							; get gas type and increment index
	btfsc	up,gas_staged						; gas staged?
	iorwf	hi,W								; YES - set respective gas bit
	rlncf	hi,F								; rotate gas bit pattern to match the next gas
	decfsz	lo,F								; decrement loop counter, did it became zero?
	bra		write_backtrack_datum_gas_loop		; NO  - loop
	movwf	POSTINC1							; YES - write the gas staging status entry and increment the writing position index
	return										;     - done


;-----------------------------------------------------------------------------
; Cave Mode Helper Function - store a Waypoint Number
;
write_backtrack_datum_waypoint:
	incf	backtrack_waypoint_num,F			; increment the waypoint number
	movf	backtrack_waypoint_num,W			; copy waypoint number to WREG
	iorlw	b'11100000'							; add the waypoint marker (bit 7-5 set) to the number stored in WREG
	movwf	POSTINC1							; write the waypoint datum and increment the writing position index
	movlw	.2									; load a 2 into WREG
	cpfslt	backtrack_waypoint_num				; new waypoint number >= 2 ?
	bcf		waypoint_reached_first				; YES - not at first waypoint any more
	return										; done


;-----------------------------------------------------------------------------
; Cave Mode Helper Function - store new writing position and check remaining storage capacity
;
write_backtrack_datum_check:
	movff	FSR1L,char_I_backtrack_index		; store new index position
	movlw	backtrack_almost_full_threshold		; load threshold for backtracking storage almost full
	bcf		backtrack_almost_full				; clear almost full state
	cpfslt	FSR1L								; index < threshold ?
	bsf		backtrack_almost_full				; NO - flag backtracking storage is almost full
	movlw	backtrack_entire_full_threshold		; load threshold for backtracking storage entirely full
	bcf		backtrack_entire_full				; clear entirely full state
	cpfslt	FSR1L								; index < threshold ?
	bsf		backtrack_entire_full				; NO - flag backtracking storage is entirely full
	return										; done

 ENDIF	; _cave_mode


;-----------------------------------------------------------------------------
; Calculate vertical Velocity
;
calc_velocity:							; called every two seconds
	btfsc	velocity_active_num			; was velocity shown in last cycle?
	bra		calc_velocity_1				; YES - always update if shown before
	btfss	count_divetime				; NO  - is the dive time counted, i.e. deeper than dive threshold?
	return								;       NO - display velocity only if deeper than 1m,
										;            i.e. not at the surface after the dive
calc_velocity_1:
	; calculate pressure difference
	MOVII	pressure_abs_cached,   sub_a; current pressure
	MOVII	last_pressure_velocity,sub_b; last pressure
	call	subU16						; do an unsigned subtraction

	; decide if ascending or descending
	bcf		neg_flag_velocity			; set to ascending by default
	btfsc	neg_flag					; pressure differential negative?
	bsf		neg_flag_velocity			; YES - descending

	; store current pressure as last pressure for next round
	MOVII	pressure_abs_cached,last_pressure_velocity

	; calculate velocity in m/min
	MOVII	sub_c,xA					; copy pressure differential to xA
	MOVLI	.39,xB						; put scale coefficient into xB (use 77 when called every second)
	call	mult16x16					; compute differential pressure in mbar * scale coefficient
	MOVII	xC,divA						; copy result to divA
	ADDLI	.64,divA					; add some round-up
	movlw	.7							; divide by 2^7
	call	div16						; divA = divA / 2^WREG, yields velocity in m/min

	movlw	.99							; load a 99
	cpfslt	divA+0						; velocity < 99 m/min ?
	movwf	divA+0						; NO  - limit to 99 m/min

	bcf		STATUS,C					; clear carry flag
	movlw	velocity_display_threshold	; get threshold for displaying vertical velocity
	subwf	divA+0,W					; subtract threshold from velocity
	btfss	STATUS,C					; above threshold?
	bsf		FLAG_TFT_velocity_clear		; NO  - don't show / request to clear
	btfsc	STATUS,C					; above threshold?
	bsf		FLAG_TFT_velocity_show		; YES - request to show
	return								; done


;-----------------------------------------------------------------------------
; Check and Memorize if Dive went into Deco & Deco Region
;
check_deco_states:
	btfsc	deco_region					; been within the deco stops region before?
	return								; YES - been in deco then before too, done
	movff	char_O_deco_info,WREG		; NO  - get deco info vector
	btfss	WREG,deco_stops_norm		;       do we have a deco obligation right now?
	return								;       NO  - done
	bsf		deco_locked					;       YES - memorize dive was in deco
	movff	char_O_deco_depth+0,WREG	;           - get depth of first stop in meters into WREG
	addlw	deco_region_distance+.1		;           - add deco region start distance + 1 meter for the negative test to work
	subwf	depth_meter,W				;           - compute current depth - (first stop depth + deco region distance)
	btfss	STATUS,C					;           - result negative?
	bsf		deco_region					;             YES - memorize to have entered the deco stops region
	return								;           - done


;-----------------------------------------------------------------------------
; Exercise Safety Stop Control
;
safety_stop_control:
	TSTOSS	opt_safetystop				; safety stop enabled? (=1: show safety stop)
	return								; NO  - done

	btfsc	FLAG_gauge_mode				; in gauge mode?
	return								; YES - omit (well, else fix collision of safety stop output with avg depth label)

	; setup
	bcf		safety_stop_enabled			; disable safety stop by default

	; check for deco
	btfsc	decostop_active				; in deco mode?
	bra		safety_stop_finish			; YES - shut down safety stop

	; below "opt_safety_stop_reset"?
	MOVII	pressure_rel_cur_cached,mpr	; get current pressure into MPR
	call	convert_pres_to_depth		; convert pressure in [mbar] to depth in [cm]
	MOVII	mpr,sub_a					; move depth in [cm] to sub_a
	movff	opt_safety_stop_reset,WREG	; load safety stop reset threshold [dm]
	mullw	.10							; convert threshold from [dm] to [cm]
	MOVII	PROD,sub_b					; move threshold in [cm] to sub_b
	call	cmpU16						; sub_a - sub_b
	btfsc	neg_flag					; below threshold depth?
	bra		safety_stop_control_chk		; NO  - check if above end threshold
	;bra	safety_stop_reset			; YES - reset safety stop

safety_stop_reset:
	movff	opt_safety_stop_length,safety_stop_countdown	; rearm safety stop (load timer)
	incf	safety_stop_countdown,F							; +1 because safety_stop_show decrements first
	bsf		FLAG_TFT_safety_stop_clear						; request to clear safety stop
	return													; done

safety_stop_control_chk:
	; above "opt_safety_stop_end"?
	movff	opt_safety_stop_end,WREG	; load safety stop end threshold [dm]
	mullw	.10							; convert threshold from [dm] to [cm]
	MOVII	PROD,sub_b					; move threshold in [cm] to sub_b
	call	cmpU16						; sub_a - sub_b
	btfsc	neg_flag					; above or at threshold depth?
	bra		safety_stop_finish			; YES - finish with safety stop and return

	; above "opt_safety_stop_start"?
	movff	opt_safety_stop_start,WREG	; load safety stop start threshold [dm]
	mullw	.10							; convert threshold from [dm] to [cm]
	MOVII	PROD,sub_b					; move threshold in [cm] to sub_b
	call	cmpU16						; sub_a - sub_b
	btfss	neg_flag					; above or at threshold depth?
	return								; NO  - pause safety stop
	tstfsz	safety_stop_countdown		; YES - safety stop armed?
	bsf		safety_stop_enabled			;       YES - enable safety stop
	return								;     - done


;-----------------------------------------------------------------------------
; Show Safety Stop
;
safety_stop_show:
	btfss	safety_stop_enabled			; safety stop enabled?
	return								; NO  - done
	dcfsnz	safety_stop_countdown,F		; YES - decrement remaining stop time, reached zero?
	bra		safety_stop_finish			;       YES - finished with safety stop and return
	bsf		FLAG_TFT_safety_stop_show	;       NO  - request to show safety stop
	return								;           - done


;-----------------------------------------------------------------------------
; Finish Safety Stop
;
safety_stop_finish:
	clrf	safety_stop_countdown		; disarm  safety stop
	bcf		safety_stop_enabled			; disable safety stop
	bsf		FLAG_TFT_safety_stop_clear	; request to clear safety stop
	return								; done


;-----------------------------------------------------------------------------
; Check for Timeouts (called by tasks every 1/1 second)
;
timeout_divemode:
	btfss	dive_main_menu				; main dive menu shown?
	bra		timeout_divemode_1			; NO  - skip
	btfsc	trigger_timeout				; YES - timeout occurred?
	rcall	divemenu_cleanup			;       YES - clean up main menu and restore dive data

timeout_divemode_1:
	btfss	dive_pre_menu				; pre-menu shown?
	bra		timeout_divemode_2			; NO  - skip
	btfsc	trigger_timeout				; YES - timeout occurred?
	call	menuview_toggle_reset		;       YES - terminate the pre-menu

timeout_divemode_2:
	INCI	dive_timeout_timer			; increment timeout timer
	
	btfss	divetime_longer_1min		; does the dive already last for longer than one minute?
	bra	timeout_divemode_sub_1min	; NO  - use a short timeout to achieve some extra hysteris when starting the dive

	btfsc	FLAG_apnoe_mode				; in apnoe mode?
	bra		timeout_divemode_apnoe		; YES - use apnoe timeout

 IFNDEF _DEBUG
	btfsc	sensor_override_active		; in simulator mode?
	bra		timeout_divemode_sim		; YES - use simulator timeout
 ENDIF

	movff	opt_diveTimeout,WREG		; get dive timeout in minutes into WREG
	bra		timeout_divemode_com_min	; continue with common part for minutes

timeout_divemode_apnoe:
	movlw	apnoe_timeout				; get apnoe timeout in minutes into WREG
	bra		timeout_divemode_com_min	; continue with common part for minutes

timeout_divemode_sim:
	MOVLI	simulator_timeout,sub_a		; get simulator timeout in seconds directly into sub_a
	bra		timeout_divemode_com_sec	; continue with common part for seconds

timeout_divemode_sub_1min:
	MOVLI	divetime_less_1min_timeout,sub_a ; use a short timeout as an extra hysteresis during the descent
	bra		timeout_divemode_com_sec	; continue with common part for seconds
	
timeout_divemode_com_min:
	mullw	.60							; multiply with 60 to convert minutes in WREG to seconds
	MOVII	PRODL,sub_a					; copy resulting seconds to sub_a

timeout_divemode_com_sec:
	MOVII	dive_timeout_timer,sub_b	; copy current timeout timer value to sub_b
	call	cmpU16						; check sub_a - sub_b
	btfsc	neg_flag					; result negative, i.e. timeout?
	bcf		divemode					; YES - terminate dive mode
	return								; done


;-----------------------------------------------------------------------------
; Clean up Dive Menu Area and restore Dive Data
;
divemenu_cleanup:
	bcf		dive_main_menu				; clear flag for dive mode menu shown
	call	TFT_clear_divemode_menu		; clear menu area

	btfss	custom_view_locked			; was the custom view locked by the menu system?
	bra		divemenu_cleanup_1			; NO  - continue with redrawing the lower display
	bcf		custom_view_locked			; YES - release locked
	movf	backup_customview,W			;     - get previous custom view into WREG
	cpfseq	active_customview			;     - compare with current custom view, equal?
	call	dive_customview_recall		;       NO - redraw previous custom view

divemenu_cleanup_1:
	bsf		FLAG_TFT_active_gas_divemode; request redraw of gas/setpoint/diluent
	bsf		FLAG_TFT_temperature		; request redraw of temperature (or resettable dive)
	bcf		better_gas_blinking			; stop better gas cue
	bcf		better_dil_blinking			; stop better dil cue
	;bra	request_redraw_NDL_deco_data; request redraw of NDL/deco data and return


;-----------------------------------------------------------------------------
; Request redraw of NDL/Deco Data
;
request_redraw_NDL_deco_data:
	btfsc	FLAG_gauge_mode				; in gauge mode?
	return								; YES - done
	btfss	decostop_active				; NO  - in deco mode?
	bra		timeout_divemode_menu_ndl	;       NO  - show NDL  again
	;bra	timeout_divemode_menu_deco	;       YES - show deco again

timeout_divemode_menu_deco:
	bsf		FLAG_TFT_display_deco_mask	; show deco mask
	bsf		FLAG_TFT_display_deco		; show deco stop
	bsf		FLAG_TFT_display_tts		; show TTS time
	return								; done

timeout_divemode_menu_ndl:
	bsf		FLAG_TFT_display_ndl_mask	; show NDL mask
	bsf		FLAG_TFT_display_ndl		; show NDL time
	return								; done


;-----------------------------------------------------------------------------
; Check if Dive Mode needs to be started (called from Surface Mode)
;
	global	check_dive_modes_surf
check_dive_modes_surf:
	SMOVII	pressure_rel_cur,sub_a			; ISR-safe 2 byte copy of current relative pressure to sub_a
	bcf		divetime_longer_1min			; not diving when in surface mode
	bra		check_dive_modes				; continue with common part


;-----------------------------------------------------------------------------
; Check if Dive Mode needs to be finished (called from Dive Loop)
;
check_dive_modes_dive:
	MOVII	pressure_rel_cur_cached,sub_a	; copy cached relative pressure to sub_a
	;bra	check_dive_modes				; continue with common part


;-----------------------------------------------------------------------------
; Check for Dive Mode Start/Finish - common Part
;
check_dive_modes:
	btfss	high_altitude_mode					; in high altitude mode?
	bra		check_dive_modes_norm				; NO  - use normal start-dive threshold
	btfsc	divetime_longer_1min				; YES - diving since > one minute?
	bra		check_dive_modes_norm				;       YES - this is a real dive -> use normal start-dive threshold
	;bra	check_dive_modes_high				;       NO  - use hight-altitude start-dive threshold

check_dive_modes_high:
	; high altitude start/end dive thresholds
	btfss	count_divetime						; dive time counting, i.e. already in the dive?
	bra		check_dive_modes_high_start			; NO  - select start threshold
	;bra	check_dive_modes_high_end			; YES - select end   threshold

check_dive_modes_high_end:
	MOVLI	dive_threshold_high_alt_end,sub_b	; load high altitude end threshold
	bra		check_dive_modes_comm				; continue with common part

check_dive_modes_high_start:
	MOVLI	dive_threshold_high_alt_start,sub_b	; load high altitude start threshold
	bra		check_dive_modes_comm				; continue with common part

check_dive_modes_norm:
	; normal altitude start/end dive thresholds
	btfss	count_divetime						; dive time counting, i.e. already in the dive?
	bra		check_dive_modes_norm_start			; NO  - select start threshold
	;bra	check_dive_modes_norm_end			; YES - select end   threshold

check_dive_modes_norm_end:
	MOVLI	dive_threshold_norm_alt_end,sub_b	; load normal altitude end threshold
	bra		check_dive_modes_comm				; continue with common part

check_dive_modes_norm_start
	MOVLI	dive_threshold_norm_alt_start,sub_b	; load normal altitude start threshold
	;bra	check_dive_modes_comm				; continue with common part

check_dive_modes_comm:
	call	cmpU16								; sub_a - sub_b = pressure_rel_cur - start-dive threshold
	btfsc	neg_flag							; pressure_rel_cur > dive_threshold, i.e. deeper than threshold?
	bra		check_dive_modes_shallow			; NO  - shallower than threshold
	btfsc	divetime_longer_1min				; YES - diving > one minute?
	CLRI	dive_timeout_timer					;       YES - reset timeout counter
	bsf		divemode							;     - set dive mode flag
	bsf		count_divetime						;     - count dive time
	return										;     - done

check_dive_modes_shallow:
	bcf		count_divetime						; stop counting dive time
;	btfss	divetime_longer_1min				; diving > one minute?
;	bcf		divemode							; NO  - quit dive mode as this was no real dive
	return										; done mH


;-----------------------------------------------------------------------------
; Initialize the resettable Depth and Timer
;
resettable_average_depth_init:
	CLRI	pressure_rel_avg_trip							; prime the resettable average depth with 0
	bra		resettable_average_depth_common					; clear pressure accumulator and timer


;-----------------------------------------------------------------------------
; Reset the resettable Depth and Timer
;
resettable_average_depth_reset:
	bcf		request_reset_avg								; clear request
	MOVII	pressure_rel_cur_cached,pressure_rel_avg_trip	; prime the resettable average depth
															; with the current relative pressure (depth)
	;bra	resettable_average_depth_common					; clear pressure accumulator and timer


;-----------------------------------------------------------------------------
; Helper Function - common Part for resettable Depth and Timer init/reset
;
resettable_average_depth_common:
	clrf	pressure_rel_accu_trip+0						; clear the resettable depth accumulator
	clrf	pressure_rel_accu_trip+1						; ....
	clrf	pressure_rel_accu_trip+2						; ....
	clrf	pressure_rel_accu_trip+3						; ....
	CLRI	divesecs_avg_trip								; clear the resettable time accumulator
	return													; done


;-----------------------------------------------------------------------------
; Calculate Average Depth
;
calc_average_depth:
	; 1. compute pressure_rel_cur_cached x 2, because this routine is called every 2nd second only
	MOVII	pressure_rel_cur_cached,xB		; copy current rel pressure to xB
	bcf		STATUS,C						; multiply rel pressure x 2 (via shift left)
	rlcf	xB+0,F							; ...
	rlcf	xB+1,F							; ...

	; 2a add (pressure_rel_cur_cached x 2) to the resettable depth accumulator
	;    will work up to 9999 mbar * 60 * 60 * 24 = 863913600 mbar (24h @ 90 m depth)
	movf	xB+0,W							; pressure_rel_accu_trip += xB
	addwf	pressure_rel_accu_trip+0,F		; ...
	movf	xB+1,W							; ...
	addwfc	pressure_rel_accu_trip+1,F		; ...
	movlw	.0								; ...
	addwfc	pressure_rel_accu_trip+2,F		; ...
	addwfc	pressure_rel_accu_trip+3,F		; ...

	; 2b add (pressure_rel_cur_cached x 2) to the total depth accumulator
	;    will work up to 9999 mbar * 60 * 60 * 24 = 863913600 mbar (24h @ 90 m depth)
	movf	xB+0,W							; pressure_rel_accu_total += xB
	addwf	pressure_rel_accu_total+0,F		; ...
	movf	xB+1,W							; ...
	addwfc	pressure_rel_accu_total+1,F		; ...
	movlw	.0								; ...
	addwfc	pressure_rel_accu_total+2,F		; ...
	addwfc	pressure_rel_accu_total+3,F		; ...

	; 3a compute the resettable average depth
	movff	pressure_rel_accu_trip+0,xC+0	; get the accumulated depth
	movff	pressure_rel_accu_trip+1,xC+1	; ...
	movff	pressure_rel_accu_trip+2,xC+2	; ...
	movff	pressure_rel_accu_trip+3,xC+3	; ...
	MOVII	divesecs_avg_trip,xB			; get the accumulated time

	; divide accumulated depth by accumulated time
	call	div32x16						; xC:4 / xB:2 = xC+3:xC+2 with xC+1:xC+0 as remainder

	; store result
	MOVII	xC,pressure_rel_avg_trip		; resettable average depth
	btfss	count_divetime					; is dive time counted?
	return									; NO (e.g. too shallow)

	; 3b compute the dive total average depth
	movff	pressure_rel_accu_total+0,xC+0	; get accumulated depth
	movff	pressure_rel_accu_total+1,xC+1	; ...
	movff	pressure_rel_accu_total+2,xC+2	; ...
	movff	pressure_rel_accu_total+3,xC+3	; ...
	MOVII	divesecs_avg_total,xB			; get accumulated time

	; divide accumulated depth by accumulated time
	call	div32x16						; xC:4 = xC:4 / xB:2 with xA as remainder

	; store result
	MOVII	xC,pressure_rel_avg_total		; total dive average depth

	btfsc	request_reset_avg				; shall reset the resettable average depth?
	rcall	resettable_average_depth_reset	; YES - reset the resettable average depth

	TSTOSC	opt_2ndDepthDisp				; drawing average depth instead of max depth?
	bsf		FLAG_TFT_depth_maximum			; YES - flag to update display

	btfsc	FLAG_gauge_mode					; in gauge mode?
	bsf		FLAG_TFT_depth_maximum			; YES - flag to update display (needed for alternative layout)

	return									; done


;-----------------------------------------------------------------------------
; Check Switches, execute Pre-Menu Items  (called every second)
;
test_switches_divemode:
	btfsc	dive_main_menu					; dive mode menu shown?
	bra		test_switches_divemode_menu		; YES - use menu processor
	btfsc	switch_left						; NO  - left button pressed?
	goto	menuview_toggle					;       YES - step through pre-menu
	btfss	switch_right					;       NO  - right button pressed?
	return									;             NO  - done
	bcf		switch_right					;             YES - clear button event
	tstfsz	active_premenu					;                 - any pre-menu task selected?
	bra		test_switches_divemode1			;                   YES - execute a pre-menu item
	bsf		request_next_custview			;                   NO  - request next custom view
	return									;                       - done

test_switches_divemode_menu:
	btfsc	switch_left						; left button pressed?
	bra		test_switches_divemode_menu2	; YES - move cursor
	btfsc	switch_right					; NO  - right button pressed?
	bra		test_switches_divemode_menu3	;       YES - do a menu operation
	btfss	update_menu						;       NO  - shall update the menu?
	return									;             NO  - done
	bcf		update_menu						;             YES - clear request
	goto	menu_draw_lines_divemode		;                 - redraw the menu (to update color coding) and return

test_switches_divemode_menu1:
	clrf	menu_pos_cur					; reset menu item number to zero
test_switches_divemode_menu2:
	bcf		switch_left						; clear left button event
	incf	menu_pos_cur,F					; increment menu item number
	incf	menu_pos_max,W					; get number of items + 1 into WREG
	cpfslt	menu_pos_cur					; incremented item number > number of items ?
	bra		test_switches_divemode_menu1	; YES - restart from first item
	call	menu_draw_cursor_dive			; draw cursor at new position
	movlw	divemode_timeout_mainmenu		; get timeout for main menu
	call	restart_timeout_time			; restart the timeout
	return									; done

test_switches_divemode_menu3:
	bcf		switch_right					; clear right button event
	goto	do_line_menu					; Warning! trashes STKPTR and returns to
											;          divemode_option_divemenu_return

test_switches_divemode1:
	movlw	divemode_timeout_premenu		; get timeout for pre-menu
	call	restart_timeout_time			; restart the timeout
	movf	active_premenu,W				; get active pre-menu item
	dcfsnz	WREG,F
	bra		divemode_option_gaschange		;  1: switch to the the "better gas" / "better diluent"
	dcfsnz	WREG,F
	bra		divemode_option_ackn			;  2: acknowledge current advice, attention, or warning
	dcfsnz	WREG,F
	bra		divemode_option_divemenu		;  3: enter dive mode menu
	dcfsnz	WREG,F
 IFDEF _cave_mode
	bra		divemode_option_cavemenu		;  4: enter cave mode menu
 ELSE
	return									;  4: (no cave mode compiled in)
 ENDIF
	dcfsnz	WREG,F
	bra		divemode_option_sim_quit		;  5: quit simulator mode
	dcfsnz	WREG,F
	bra		divemode_option_sim_down		;  6: simulator mode - descent
	dcfsnz	WREG,F
	bra		divemode_option_sim_up			;  7: simulator mode - ascend
	dcfsnz	WREG,F
	bra		divemode_option_sim_time		;  8: simulator mode - +5 min
	dcfsnz	WREG,F
	bra		divemode_option_apnoe_quit		;  9: quit apnoe dive
	dcfsnz	WREG,F
	bra		divemode_option_gauge_reset		; 10: reset stopwatch and avg depth (gauge mode)
	dcfsnz	WREG,F
 IFDEF _compass
	bra		divemode_option_course			; 11: set bearing
 ELSE
	return									; 11: (no compass compiled in)
 ENDIF
	dcfsnz	WREG,F
	bra		divemode_option_layout			; 12: switch layout
	return									; catch illegal item number


	; item  1: switch to the the "better gas" / "better diluent"
	;
divemode_option_gaschange:
 IFDEF _ccr_pscr
	btfsc	FLAG_oc_mode					; in OC mode?
	bra		divemode_option_gaschange_oc	; YES
	btfsc	bailout_mode					; in bailout?
	bra		divemode_option_gaschange_oc	; YES

	; in CCR/pSCR mode and not in bailout
	movff	best_dil_number,menu_pos_cur	; select best diluent
	bcf		better_dil_available			; clear flag immediately
	bra		divemode_option_gaschange3		; continue with common part
 ENDIF
divemode_option_gaschange_oc:
	movff	best_gas_number,menu_pos_cur	; select best gas
	bcf		better_gas_available			; clear better gas cue

divemode_option_gaschange3
	bsf		request_gas_change				; request a gas/diluent change
	goto	menuview_toggle_reset			; terminate the pre-menu (and return)


	; item  2: acknowledge current advice, attention, or warning
	;
divemode_option_ackn:
	btfss	sign_warning						; any warning active?
	bra		divemode_option_ackn_attn			; NO  - check for active attentions
	movff	DM_flags_war1_det,DM_flags_war1_ack	; YES - memorize active warnings as acknowledged
	movff	DM_flags_war2_det,DM_flags_war2_ack	;     - ...
	bra		divemode_option_ackn_common			;     - update screen

divemode_option_ackn_attn:
	btfss	sign_attention						; any attention active?
	bra		divemode_option_ackn_advc			; NO  - must be active advice then
	movff	DM_flags_att1_det,DM_flags_att1_ack	; YES - memorize active attentions as acknowledged
	movff	DM_flags_att2_det,DM_flags_att2_ack	;     - ...
	movff	DM_flags_att3_det,DM_flags_att3_ack	;     - ...
	bra		divemode_option_ackn_common			;     - update screen

divemode_option_ackn_advc:
	movff	DM_flags_advc_det,DM_flags_advc_ack	; memorize active advices as acknowledged
	;bra	divemode_option_ackn_common			; update screen

divemode_option_ackn_common:
	call	menuview_toggle_reset			; terminate pre-menu
	call	divemode_check_sign				; compute if  the advice / attention / warning sign shall be shown
	btfsc	FLAG_TFT_sign_show				; shall show  the advice / attention / warning sign?
	goto	TFT_divemode_sign_show			; YES - show  sign and return
	goto	TFT_divemode_sign_clear			; NO  - clear sign and return


	; item  3: enter dive mode menu
	;
divemode_option_divemenu:
	btfss	divemode						; in dive mode?
	goto	menuview_toggle_reset			; NO  - block menu, terminate the pre-menu
	call	TFT_clear_divemode_menu			; YES - clear menu area
	bcf		dive_pre_menu					;     - set pre-menu as not shown anymore
	goto	do_main_divemenu				;     - hand over to menu processor


	; item  4: enter cave mode menu
	;
 IFDEF _cave_mode
divemode_option_cavemenu:
	btfss	divemode						; in dive mode?
	goto	menuview_toggle_reset			; NO  - block menu, terminate the pre-menu
	call	TFT_clear_divemode_menu			; YES - clear menu area
	bcf		dive_pre_menu					;     - set pre-menu as not shown anymore
	goto	do_main_cavemenu				;     - hand over to menu processor
 ENDIF


	; item  5: quit simulator mode
	;
divemode_option_sim_quit:
	clrf	simulatormode_depth				; set target depth to zero
	bsf		quit_simulatormode				; request ISR to end simulator mode
	call	menuview_toggle_reset			; terminate the pre-menu
	btfsc	FLAG_apnoe_mode					; in apnoe mode?
	bcf		divemode						; YES - force end of dive mode
	return									; done


	; item  6: simulator mode - descent 1 meter
	;
divemode_option_sim_down:
	movlw	ostc_depth_max-1				; load depth limit into WREG
	cpfsgt	simulatormode_depth				; simulated depth < limit ?
	incf	simulatormode_depth,F			; YES - increment simulated depth
	return									; done


	; item  7: simulator mode - ascent 1 meter
	;
divemode_option_sim_up:
	tstfsz	simulatormode_depth				; simulated depth > 0 ?
	decf	simulatormode_depth,F			; YES - decrement simulated depth
	return									; done


	; item  8: simulator mode - +5 min
	;
divemode_option_sim_time:
	movff	char_I_sim_advance_time,WREG	; get mailbox content
	tstfsz	WREG							; mailbox clear (=0) ?
	return									; NO  - still having a pending +5' request, refuse new request
	bra		advance_time					; YES - advance time and return


	; item  9: quit apnoe dive
	;
divemode_option_apnoe_quit:
	btfsc	sensor_override_active			; in simulator mode?
	bra		divemode_option_sim_quit		; YES - use simulator quit procedure
	bcf		divemode						; NO  - force end of dive mode
	return									;     - done


	; item 10: reset stopwatch and avg depth (gauge mode only)
	;
divemode_option_gauge_reset:
	bsf		request_reset_avg				; request reset of average depth
	goto	menuview_toggle_reset			; terminate pre-menu and return


	; item 11: set bearing
	;
 IFDEF _compass
divemode_option_course:
	MOVII	compass_heading_shown,compass_bearing
	bsf		compass_bearing_set				; set flag to show heading
	goto	menuview_toggle_reset			; terminate the pre-menu and return
 ENDIF


	; item 12: switch layout
	;
divemode_option_layout:
	call	menuview_toggle_reset		; terminate the pre-menu
	call	TFT_ClearScreen				; clear the whole screen
	btg		alt_layout_active			; toggle layout

	bcf		depth_color_last			; set warning or attention on the depth   not shown
	bcf		depth_inverse_last			; set depth displayed in inverse as       not shown
	bcf		sign_shown					; set warning/attention/advice sign       not shown
	bcf		velocity_active_num			; set numerical vertical velocity display not shown
	bcf		velocity_active_vsi			; set vertical  vertical velocity display not shown
	bcf		safety_stop_active			; set safety stop                         not shown

	bsf		FLAG_TFT_divemode_mask		; request redraw of dive screen mask
	bsf		FLAG_TFT_divetime			; request redraw of dive time
	bsf		FLAG_TFT_depth_current		; request redraw of current depth
	bsf		FLAG_TFT_depth_maximum		; request redraw of maximum depth
	bsf		FLAG_TFT_active_gas_divemode; request redraw of gas and setpoint
	bsf		FLAG_TFT_temperature		; request redraw of temperature
	bsf		FLAG_TFT_customview_callup	; request redraw of custom view

	goto	request_redraw_NDL_deco_data; request redraw of NDL/deco data and return


;-----------------------------------------------------------------------------
; Helper Function - advance Time by 5 Minutes (Simulator Mode)
;
advance_time:
	; advance tissues pressures and deco obligation by 5 minutes
	movlw	.5								; + 5 minutes
	movff	WREG,char_I_sim_advance_time	; copy to mailbox
	call	restart_deco_engine				; condition deco engine to execute the +5 minutes

	bcf		count_divetime					; stop dive time incrementing in ISR
	ADDLI	.5,counted_divetime_mins		; add 5 minutes to counted_divetime_mins
	ADDLI	.300,total_divetime_secs		; add 5 minutes (300 seconds) to total_divetime_secs
	bsf		count_divetime					; continue dive time incrementing in ISR

	ADDLI	.300,divesecs_avg_trip			; add 5 minutes (300 seconds) to resettable time accumulator
	ADDLI	.300,divesecs_avg_total			; add 5 minutes (300 seconds) to total time accumulator

	MOVII	pressure_rel_cur_cached,xB		; calculate 300 x depth in mbar (300 = 5 min * 60 sec/min)
	MOVLI	.300,xA							; ...
	call	mult16x16						; xC = xA * xB

	movf	xC+0,W							; add to the resettable depth accumulator
	addwf	pressure_rel_accu_trip+0,F		; ...
	movf	xC+1,W							; ...
	addwfc	pressure_rel_accu_trip+1,F		; ...
	movf	xC+2,W							; ...
	addwfc	pressure_rel_accu_trip+2,F		; ...
	movf	xC+3,W							; ...
	addwfc	pressure_rel_accu_trip+3,F		; ...

	movf	xC+0,W							; add to the total depth accumulator
	addwf	pressure_rel_accu_total+0,F		; ...
	movf	xC+1,W							; ...
	addwfc	pressure_rel_accu_total+1,F		; ...
	movf	xC+2,W							; ...
	addwfc	pressure_rel_accu_total+2,F		; ...
	movf	xC+3,W							; ...
	addwfc	pressure_rel_accu_total+3,F		; ...

 IFDEF _cave_mode
	; update backtracking data
	btfss	cave_mode						; cave mode switched on?
	bra		divemode_option_sim_time_exit	; NO  - skip backtracking depth recording
	btfsc	dive_turned						; YES - dive turned?
	bra		divemode_option_sim_time_exit	;       YES - skip   backtracking depth recording
	;bra	divemode_option_sim_time_exec	;       NO  - update backtracking depth recording

divemode_option_sim_time_exec:
	movff	backtrack_deltatime,hi			; backup time elapsed since last depth recording
	movlw	.5								; configure 5 minutes
	movwf	lo								; use lo as loop counter

divemode_option_sim_time_loop:
	call	write_backtrack_1min_depth		; store a backtracking depth data set
	btfsc	backtrack_entire_full			; backtracking storage entirely used up?
	bra		divemode_option_sim_time_exit	; YES - abort backtracking depth recording
	decfsz	lo,F							; NO  - decrement loop counter, did it became zero?
	bra		divemode_option_sim_time_loop	;       NO  - loop
	;bra	divemode_option_sim_time_done	;       YES - done

divemode_option_sim_time_done:
	movff	hi,backtrack_deltatime			; restore time elapsed since last depth recording
 ENDIF	; _cave_mode

divemode_option_sim_time_exit:
	return									; done (leaving option avail for repeated selection)


;-----------------------------------------------------------------------------
; Change Gas / Diluent
;
gas_switch_common:
	bcf		request_gas_change				; clear request flag
 IFDEF _ccr_pscr
	btfss	request_back_to_loop			; is a switchback from OC bailout to loop requested?
	bra		gas_switched_common0			; NO  - continue with checking if selected gas is valid
	bcf		request_back_to_loop			; YES - clear flag
	movff	active_dil,menu_pos_cur			;     - reload last diluent
	bra		gas_switched_common1			;     - continue with common part
 ENDIF
gas_switched_common0:
	tstfsz	menu_pos_cur					; menu_pos_cur = 0 ?
	bra		gas_switched_common1			; NO  - valid gas
	return									; YES - something went wrong, invalid gas, abort
gas_switched_common1:
	movf	menu_pos_cur,W					; get selected gas into WREG (1-5)
 IFDEF _ccr_pscr
	btfsc	FLAG_oc_mode					; in OC mode?
	bra		gas_switched_common_OC			; YES
	btfsc	bailout_mode					; in bailout?
	bra		gas_switched_common_OC			; YES
gas_switched_common_loop:					; NO to both - must be loop mode then
	call	setup_dil_registers				; set up real tissues  with WREG = diluent 1-6
	call	deco_setup_cc_diluents			; set up deco planning with WREG = diluent 1-6
	bra		gas_switched_common3			; continue with common part
 ENDIF	; _ccr_pscr

gas_switched_common_OC:
	call	setup_gas_registers				; set up real tissues  with WREG = gas 1-6
	call	deco_setup_oc_gases				; set up deco planning with WREG = gas 1-6
	;bra	gas_switched_common3			; continue with common part

gas_switched_common3:
	banksel	int_O_breathed_ppO2
	bcf		int_O_breathed_ppO2+1,int_low_flag			; | clear all flags that control color-coding
	bcf		int_O_breathed_ppO2+1,int_high_flag			; | to have the new gas initially displayed in
	bcf		int_O_breathed_ppO2+1,int_attention_flag	; | memo color instead of a warning or attention
	bcf		int_O_breathed_ppO2+1,int_warning_flag		; | color that belonged to the previous gas
	banksel	common
	bsf		FLAG_TFT_active_gas_divemode	; redraw gas/setpoint/diluent
	bsf		FLAG_TFT_temperature			; redraw temperature
	bsf		event_occured					; set global event flag
 IFDEF _ccr_pscr
	btfsc	bailout_mode					; in bailout mode?
	bsf		event_bailout					; YES - set bailout event
	btfss	bailout_mode					; in bailout mode?
 ENDIF
	bsf		event_gas_change				; (NO) - set gas change event (normal change)
	goto	restart_deco_engine_wo_ceiling	; abort running deco calculations and restart (and return)


;-----------------------------------------------------------------------------
; Reload the current Gas / Diluent
;
gas_update_common:
	bcf		request_gas_update			; reset the request flag
	movf	active_gas,W				; load WREG with currently used gas
 IFDEF _ccr_pscr
	btfsc	FLAG_oc_mode				; in OC mode?
	bra		gas_switched_common_OC		; YES - reload OC gases
	btfsc	bailout_mode				; NO  - in bailout?
	bra		gas_switched_common_OC		;       YES - reload OC gases
	movf	active_dil,W				;       NO  - load WREG with currently used diluent
	bra		gas_switched_common_loop	;           - set up diluent gases
 ELSE
	bra		gas_switched_common_OC		; reload OC gases
 ENDIF


;-----------------------------------------------------------------------------
; Toggle GF/aGF  (finalization)
;
divemodemode_togglegf:
	bcf		request_toggle_GF			; clear request flag
	goto	restart_deco_engine			; restart the deco engine and return


;-----------------------------------------------------------------------------
; Set a Marker in the Dive Profile
;
set_logbook_marker:
	bcf		request_set_marker			; clear request flag
	movlw	d'6'						; set type of alarm: manual marker
	movwf	alarm_type					; copy to alarm register
	bsf		event_occured				; set event flag
	return								; done


;-----------------------------------------------------------------------------
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
	global	check_gas_best
check_gas_best:
	btfsc	FLAG_gauge_mode					; in gauge mode?
	return									; YES - done

	MOVII	pressure_abs_10,xA				; copy absolute pressure / 10 into xA:2, will be used by ppO2 min/max checks later

	; compute max. allowed deco ppO2
	movff	char_I_ppO2_max_deco,WREG		; max ppO2 [cbar] for deco phase
	mullw	.100							; compute max ppO2 * 100, result is in 0.1 mbar
	ADDLI	ppO2_margin_on_max,PROD			; add ppO2 margin on max value to compensate for surface pressures > 1000 hPa
	MOVII	PROD,ppO2_max_deco				; store as deco ppO2 max

	; compute max. allowed default ppO2
	movff	char_O_deco_info,lo				; bank-safe copy of deco info vector
	btfss	lo,deco_mode					; is the ppO2 deco limit enabled?
	bra		check_gas_best_1				; NO  - compute default ppO2 max
	MOVII	ppO2_max_deco,ppO2_max_default	; YES - copy default ppO2 max from deco max.
	bra		check_gas_best_2				;     - continue with common part

check_gas_best_1:
	movff	char_I_ppO2_max_work,WREG		; max ppO2 [cbar] for working phase
	mullw	.100							; compute max ppO2 * 100, result is in 0.1 mbar
	ADDLI	ppO2_margin_on_max,PROD			; add ppO2 margin on max value to compensate for surface pressures > 1000 hPa
	MOVII	PROD,ppO2_max_default			; store as default ppO2 max

check_gas_best_2:

 IFDEF _ccr_pscr
	; check dive mode
	btfsc	FLAG_oc_mode					; in OC mode?
	bra		check_gas_best_gas				; YES - skip diluents, check for best gas only

check_gas_best_dil:
	; set minimum ppO2 required
	movff	char_I_ppO2_min,WREG			; min ppO2 for pure diluent in CCR mode (default)
	btfsc	FLAG_pscr_mode					; in pSCR mode?
	movff	char_I_ppO2_min_loop,WREG		; YES - replace by min ppO2 for pure diluent in pSCR mode
	mullw	.100							; min ppO2 * 100, result in 0.1 mbar
	MOVII	PROD,ppO2_min					; store in ppO2_min
	; check diluents
	lfsr	FSR1,opt_dil_O2_ratio			; set base address for diluent arrays
	movff	active_dil,lo					; set number of currently used diluent
	; preset result to nothing found
	clrf	best_gas_num					; initialize best diluent to   0 = none found yet
	setf	best_gas_depth					; initialize change depth to 255 = any one will be better
	; check if current diluent is usable
	movff	lo,check_gas_num				; check if the current diluent is usable
	rcall	check_gas_best_common			; if yes, the current diluent will become the best diluent found so far
	rcall	check_gas_best_all				; check if any other  diluent is better
	; store result
	movff	best_gas_num,best_dil_number	; store new best diluent found (1-5 or 0 of no usable diluent available)
	; check if change advices shall be given in general
	btfsc	bailout_mode					; in bailout?
	bra		check_gas_best_gas				; YES - no better diluent advice when in bailout
check_gas_best_dil1:
	; check if a change advice shall be given right now
	bcf		better_dil_available			; default to no better diluent found
	movf	best_dil_number,W				; load number of best diluent into WREG (1-5)
	bz		check_gas_best_dil3				; has a best diluent been found at all?  NO - nothing to signal for
	cpfseq	active_dil						; is this the currently used diluent?
	bra		check_gas_best_dil2				; NO  - a better diluent has been found
	bra		check_gas_best_dil3				; YES - no need to signal a better diluent if this diluent is already in use
check_gas_best_dil2:
	btfsc	warn_det_sensors_lost			; all sensors lost?
	bra		check_gas_best_dil3				; YES - suppress better diluent prompt in this case
	; not using the best gas - show better diluent hint whenever a better diluent is available
	bsf		better_dil_available			; signal that a better diluent is available
	bsf		FLAG_TFT_active_gas_divemode	; redraw gas/setpoint/diluent
check_gas_best_dil3:
	btfss	better_dil_available			; shall a better diluent be signaled for?
	bcf		better_dil_blinking				; NO  - clear blinking flag
	;bra	check_gas_best_gas				; ; continue with checking for best bailout gas
 ENDIF	; _ccr_pscr


check_gas_best_gas:
	; set minimum ppO2 required
	movff	char_I_ppO2_min,WREG			; min ppO2 for OC and bailout
	mullw	.100							; min ppO2 * 100, result in 0.1 mbar
	MOVII	PROD,ppO2_min					; store in ppO2_min
	; check gases
	lfsr	FSR1,opt_gas_O2_ratio			; set base address for gas arrays
	movff	active_gas,lo					; set number of currently used gas
	; preset result to nothing found
	clrf	best_gas_num					; initialize best gas to       0 = none found yet
	setf	best_gas_depth					; initialize change depth to 255 = any one will be better
	; check if current gas is usable
	movff	lo,check_gas_num				; check if the current gas is usable
	rcall	check_gas_best_common			; if yes, the current gas will become the best gas found so far
	rcall	check_gas_best_all				; check if any other  gas is better
	; store result
	movff	best_gas_num,best_gas_number	; store new best gas found (1-5 or 0 of no usable gas available)
 IFDEF _ccr_pscr
	; check if change advices shall be given in general
	btfsc	FLAG_oc_mode					; in OC mode?
	bra		check_gas_best_gas1				; YES - give advice
	btfsc	bailout_mode					; NO  - in bailout?
	bra		check_gas_best_gas1				;       YES - give advice
	return									;       NO  - no better (OC) gas advice when not in OC or bailout mode
 ENDIF	; _ccr_pscr
check_gas_best_gas1:						; check if we are already on the best gas
	; check if a change advice shall be given right now
	bcf		better_gas_available			; default to no better gas found
	movf	best_gas_number,W				; load number of best gas into WREG (1-5)
	bz		check_gas_best_gas3				; has a best gas been found at all?  NO - nothing to signal for
	cpfseq	active_gas						; is this the currently used gas?
	bra		check_gas_best_gas2				; NO  - a better gas has been found
	bra		check_gas_best_gas3				; YES - no need to signal a better gas if this gas is already in use
check_gas_best_gas2:
	; not using the best gas - show better gas hint whenever a better gas is available
	bsf		better_gas_available			; YES - signal that a better gas is available
	bsf		FLAG_TFT_active_gas_divemode	; YES - redraw gas/setpoint/diluent
check_gas_best_gas3:
	btfss	better_gas_available			; shall a better gas be signaled for?
	bcf		better_gas_blinking				; NO - clear blinking flag
	return


check_gas_best_all:
	clrf	check_gas_num					; increment comes first, so initialize with zero
check_gas_best_loop:
	incf	check_gas_num,F					; increment number of gas to check
	movf	lo,W							; copy number of currently used gas to WREG
	cpfseq	check_gas_num					; gas to be checked = currently used gas ?
	rcall	check_gas_best_common			; NO - check the gas
	movlw	NUM_GAS							; get total number of gases
	cpfseq	check_gas_num					; reached last gas?
	bra		check_gas_best_loop				; NO  - loop
	return									; YES - done


check_gas_best_common:						; with gas to be checked in check_gas_num (1-5)
											; and  current gas       in lo            (1-5)
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
	movff	PLUSW1,check_gas_O2_ratio		; copy O2 ratio (%) of current gas/dil to check_gas_O2_ratio
	addlw	.20								; add offset of 20 bytes to index type in opt_gas_type/opt_dil_type
	movff	PLUSW1,check_gas_type			; copy type of current gas/dil to check_gas_type (0=disabled, 1=first, 2=travel/normal, 3=deco/-)
	addlw	.10								; add offset of 10 bytes to index change depth in opt_gas_change/opt_dil_change
	movff	PLUSW1,check_gas_depth			; copy change depth of current gas/dil to check_gas_depth
	MOVII	ppO2_max_default,sub_b			; select default ppO2 max for first / travel / normal gas
	; check if the gas is the current gas
	movf	check_gas_num,W					; get the number of the gas to be checked (1-5)
	cpfseq	lo								; is this the currently used gas?
	bra		check_gas_best_common0			; NO  - do the disabled & deco gas checks
	bra		check_gas_best_common3			; YES - a gas in use overrides disabled and deco status
check_gas_best_common0:
	; check if gas is available (i.e. not disabled)
	btfsc	check_gas_type,gas_lost			; gas/dil lost?
	return									; YES - skip as not available any more
	btfsc	check_gas_type,gas_staged		; gas/dil staged?
	return									; YES - skip as currently not available
	tstfsz	check_gas_type					; type = disabled (0) ?
	bra		check_gas_best_common1			; NO  - continue checks
	return									; YES - skip as not available at all
check_gas_best_common1:
	; skip deco gases (type=3) if there are no stops, but include them when in bailout mode
	movlw	.3								; coding for deco gas
	cpfseq	check_gas_type					; type = deco (3) ?
	bra		check_gas_best_common3			; NO  - first or travel/normal then, ok to use
 IFDEF _ccr_pscr
	btfsc	bailout_mode					; YES - in bailout?
	bra		check_gas_best_common2			;       YES - ok to use (using deco gases is always allowed when in bailout)
 ENDIF
	TSTOSS	opt_ext_stops					;       NO  - extended stops enabled?
	bra		check_gas_best_common1b			;             NO  - only ok if in deco region
	;bra	check_gas_best_common1a			;             YES - only ok if in deco mode
check_gas_best_common1a:
	movff	char_O_deco_info,WREG			; get deco info vector
	btfss	WREG,deco_mode					; are we in deco mode?
	return									; NO  - skip deco gas while not in deco mode
	bra		check_gas_best_common2			; YES - deco gases allowed
check_gas_best_common1b:
	btfss	deco_region						; are we in the deco region?
	return									; NO  - skip deco gas while not in the deco region
	;bra	check_gas_best_common2			; YES - deco gases allowed
check_gas_best_common2:
	MOVII	ppO2_max_deco,sub_b				; replace by ppO2 max for a deco gas
check_gas_best_common3:
	; check if gas is usable, i.e. its change depth is below or equal to the current depth
	movf	depth_meter,W					; load current depth (in m) into WREG
	cpfslt	check_gas_depth					; change depth of checked gas < (shallower than) current depth?
	bra		check_gas_best_common4			; NO  - gas is usable
	return									; YES - gas is not usable
check_gas_best_common4:
	; check if this gas is the first best gas candidate
	movf	best_gas_num,W					; get best gas found so far (1-5) or 0 if none found yet
	tstfsz	WREG							; has a best gas candidate been found yet?
	bra		check_gas_best_common5			; YES - check if the new one is better than the one we have so far
	bra		check_gas_best_common6			; NO  - no need to do the above mentioned check
check_gas_best_common5:
	; check if the change depth of the checked gas is < (shallower) than the change depth of the best gas found so far
	movf	best_gas_depth,W				; load change depth of best gas so far into WREG
	cpfslt	check_gas_depth					; change depth of checked gas < (shallower than) change depth of best gas so far?
	return									; NO  - this gas is not better than the best already found
	;bra	check_gas_best_common6			; YES - this gas is better, continue
check_gas_best_common6:
	; check if the gas fits into the ppO2 limits
	movff	check_gas_O2_ratio,xB+0			; xB = O2 ratio, xA is still loaded with (absolute pressure / 10)
	clrf	xB+1
	call	mult16x16						; xC = O2 ratio * (absolute pressure / 10), result in 0.1 mbar
	; check for very high ppO2
	tstfsz	xC+2							; O2_ratio * absolute pressure / 10 > 65536, i.e. ppO2 > 6.55 bar ?
	return									; YES - gas is not usable
	btfsc	xC+1,7							; ppO2 > 3.30 bar ?
	return									; YES - gas is not usable
	MOVII	xC,sub_a						; NO  - gas may be usable
	; check for high ppO2
	call	cmpU16							; sub_a - sub_b
	btfss	neg_flag						; within limit?
	return									; NO - too high, gas is not usable
	; check for low ppO2
	MOVII	ppO2_min,sub_b					; copy minimum ppO2 to sub_b
	call	cmpU16							; sub_a - sub_b
	btfsc	neg_flag						; within limit?
	return									; NO - too low, gas is not usable
	; we have a (new) best gas
	movff	check_gas_num,  best_gas_num	; YES - set checked gas (1-5) as best gas
	movff	check_gas_depth,best_gas_depth	;     - memorize its change depth
	return									;     - done

 IFDEF _ccr_pscr


;-----------------------------------------------------------------------------
; Check for Auto-SP
;
check_dive_autosp:
	movf	dive_ccr_mode,W				; =0: Fixed SP, =1: Sensor, =2: Auto SP
	sublw	.2							; dive_ccr_mode = 2 (Auto SP)?
	bz		check_dive_autosp2			; YES - check
	return								; NO  - return for sensor or fixed mode

check_dive_autosp2:
	; check for restart request
	btfss	restart_auto_sp				; shall restart from 1st SP?
	bra		check_dive_autosp2a			; NO  - skip next
	bcf		restart_auto_sp				; YES - clear request flag
	bcf		FLAG_SP2_used				;     - flag SP 2, ...
	bcf		FLAG_SP3_used				;     - flag SP 3, ...
	bcf		FLAG_SP4_used				;     - flag SP 4, ...
	bcf		FLAG_SP5_used				;     - flag SP 5 as unused so far

check_dive_autosp2a:
	; check SP2
	btfsc	FLAG_SP2_used				; SP 2 used so far?
	bra		check_dive_autosp3			; YES - continue with SP 3
	movff	opt_setpoint_change+1,lo	; NO  - get depth in m
	tstfsz	lo							;     - SP change depth = 0 ?
	bra		check_dive_autosp2b			;       NO  - continue
	bra		check_dive_autosp3			;       YES - continue with SP 3
check_dive_autosp2b:
	decf	lo,W						; SP change depth -1 -> WREG
	cpfsgt	depth_meter					; current depth > change depth - 1 ?
	bra		check_dive_autosp3			; NO  - continue with SP 3
	; auto switch to SP2
	movff	opt_setpoint_cbar+1,char_I_const_ppO2 ; YES - use SP
	rcall	xmit_sp_set_flag			;     - send SP to external devices
	bsf		FLAG_SP2_used				;     - set SP 2 used flag

check_dive_autosp3:
	; check SP3
	btfsc	FLAG_SP3_used				; SP 3 used so far?
	bra		check_dive_autosp4			; YES - continue with SP 4
	movff	opt_setpoint_change+2,lo	; NO  - get depth in m
	tstfsz	lo							;     - SP change depth = 0 ?
	bra		check_dive_autosp3a			;       NO  - continue
	bra		check_dive_autosp4			;       YES - continue with SP 4
check_dive_autosp3a:
	decf	lo,W						; SP change depth -1 -> WREG
	cpfsgt	depth_meter					; current depth > change depth - 1 ?
	bra		check_dive_autosp4			; NO  - continue with SP 4
	; auto switch to SP3
	movff	opt_setpoint_cbar+2,char_I_const_ppO2 ; YES - use SP
	rcall	xmit_sp_set_flag			;     - send SP to external devices
	bsf		FLAG_SP3_used				;     - set SP 3 used flag

check_dive_autosp4:
	; check SP4
	btfsc	FLAG_SP4_used				; SP 4 used so far?
	bra		check_dive_autosp5			; YES - continue with SP 5
	movff	opt_setpoint_change+3,lo	; NO  - get depth in m
	tstfsz	lo							;     - SP change depth = 0 ?
	bra		check_dive_autosp4a			;       NO  - continue
	bra		check_dive_autosp5			;       YES - continue with SP 5
check_dive_autosp4a:
	decf	lo,W						; SP change depth -1 -> WREG
	cpfsgt	depth_meter					; current depth > change depth - 1 ?
	bra		check_dive_autosp5			; NO  - continue with SP 5
	; auto switch to SP4
	movff	opt_setpoint_cbar+3,char_I_const_ppO2 ; YES - use SP
	rcall	xmit_sp_set_flag			;     - send SP to external devices
	bsf		FLAG_SP4_used				;     - set SP 4 used flag

check_dive_autosp5:
	; check SP5
	btfsc	FLAG_SP5_used				; SP 5 used so far?
	bra		check_dive_autosp6			; YES - done
	movff	opt_setpoint_change+4,lo	; NO  - get depth in m
	tstfsz	lo							;     - SP change depth = 0 ?
	bra		check_dive_autosp5a			;       NO  - continue
	bra		check_dive_autosp6			;       YES - done
check_dive_autosp5a:
	decf	lo,W						; SP change depth -1 -> WREG
	cpfsgt	depth_meter					; current depth > change depth - 1 ?
	bra		check_dive_autosp6			; NO  - done
	; auto switch to SP5
	movff	opt_setpoint_cbar+4,char_I_const_ppO2 ; YES - use SP
	rcall	xmit_sp_set_flag			;     - send SP to external devices
	bsf		FLAG_SP5_used				;     - set SP 5 used flag

check_dive_autosp6:
	return								; done


;-----------------------------------------------------------------------------
; Helper Function - transmit new Setpoint to external Electronics and flag Change
;
xmit_sp_set_flag:
 IFDEF _external_sensor
	call	transmit_setpoint			; transmit current setpoint from WREG (in cbar) to external electronics
 ENDIF
	bsf		event_occured				; set global   event flag
	bsf		event_SP_change				; set setpoint event flag
	return

 ENDIF	; _ccr_pscr


;=============================================================================
dmode2	CODE
;=============================================================================


;-----------------------------------------------------------------------------
; Setup everything to enter OC Dive Mode
;
	global	dive_boot_oc
dive_boot_oc:
	rcall	get_first_gas_to_WREG		; get first gas (1-5) into WREG
	rcall	setup_gas_registers			; set-up of gas parameters of currently breathed gas (with WREG = gas 1-5)
	rcall	deco_setup_oc_gases			; set-up of gas list for deco calculations           (with WREG = gas 1-5)
	return								; done


;-----------------------------------------------------------------------------
; Helper Function - get first Gas (1-5) into WREG
;
	global	get_first_gas_to_WREG
get_first_gas_to_WREG:
	lfsr	FSR1,opt_gas_type			; load base address of the gas types
	clrf	lo							; start with gas 0
get_first_gas_to_WREG2:
	movf	lo,W						; set index
	movf	PLUSW1,W					; get type of gas (0=Disabled, 1=First, 2=Travel, 3=Deco)
	sublw	.1							; is it of type First?
	bz		get_first_gas_to_WREG3		; YES - found the First gas
	incf	lo,F						; NO  - increment index
	movlw	NUM_GAS+1					;     - get highest index+1
	cpfseq	lo							;     - all gases checked?
	bra		get_first_gas_to_WREG2		;       NO  - not yet
	movlw	.1							;       YES - default to gas 1
	movff	WREG,opt_gas_type+0			;           - force it to be of type First
	return								;           - done
get_first_gas_to_WREG3:
	movf	lo,W						; copy index of gas found to be the First to WREG
	incf	WREG,W						; turn index into gas number (0-4 -> 1-5)
	return								; done


;-----------------------------------------------------------------------------
; Helper Function - load currently breathed Gas into Deco Engine
;
	global	setup_gas_registers
setup_gas_registers:
	movwf	active_gas						; set as current gas
	movlw	.6								; gas = gas6 ?
	cpfseq	active_gas						; ...
	bra		setup_gas_registers_15			; NO - load gas 1-5

	; load gas 6
	movff	opt_gas6_O2_ratio,char_I_O2_ratio	; copy gas6 O2 ratio to deco engine
 IFDEF _helium
	movff	opt_gas6_He_ratio,char_I_He_ratio	; copy gas6 H2 ratio to deco engine
 ENDIF
	movlw	.3								; declare gas6 as a deco gas
	movff	WREG,char_I_current_gas_type	; copy gas type to deco engine
	movff	depth_meter,char_I_gas6_depth	;set current depth as change depth
	bra		setup_gas_registers_com			; continue with common part

setup_gas_registers_15:
	lfsr	FSR1,opt_gas_O2_ratio			; load base address of gas data
	decf	active_gas,W					; set index to O2 ratio of current gas (1-5 -> 0-4)
	movff	PLUSW1,char_I_O2_ratio			; copy         O2 ratio to deco engine
	addlw	.10								; advance index from O2 ratio to He ratio
 IFDEF _helium
	movff	PLUSW1,char_I_He_ratio			; copy         He ratio to deco engine
 ENDIF
	addlw	.10								; advance index from He ratio to gas type
	movff	PLUSW1,char_I_current_gas_type	; copy gas type (0=Disabled, 1=First, 2=Travel, 3=Deco)
setup_gas_registers_com:
	movff	char_O_main_status,lo			; working copy of char_O_main_status in bank common
	bcf		lo,DECO_MODE_PSCR_FLAG			; clear the pSCR-mode flag (if applicable)
	bcf		lo,DECO_MODE_LOOP_FLAG			; clear the loop/CCR-mode flag
	movff	lo,char_O_main_status			; bank safe write-back of char_O_main_status
	movf	active_gas,W					; reload WREG with gas 1-5 or 6 (important!)
	return									; done


;-----------------------------------------------------------------------------
; Helper Function - load OC Gases into Deco Engine (currently breathed gas in WREG)
;
	global	deco_setup_oc_gases
deco_setup_oc_gases:
	movff	char_O_deco_status,lo			; get working copy of char_O_deco_status in bank common
deco_setup_oc_gases_pre:					; entry point with lo preloaded
	movff	WREG,char_I_current_gas_num		; set gas to start with when doing the deco calculations
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
	lfsr	FSR2,char_I_deco_O2_ratio		; load FSR2 with base address of char_I_deco_O2_ratio
											; FSR2 will step through all char_I_deco_... vars
	lfsr	FSR1,opt_gas_O2_ratio			; load FSR1 with base address of opt_gas_O2_ratio
	rcall	deco_setup_copy					; copy all OC O2 ratios
	lfsr	FSR1,opt_gas_He_ratio			; load FSR1 with base address of opt_gas_He_ratio
	rcall	deco_setup_copy					; copy all OC He ratios
	lfsr	FSR1,opt_gas_type				; load FSR1 with base address of opt_gas_type
	rcall	deco_setup_copy					; copy all gas types
	lfsr	FSR1,opt_gas_change				; load FSR1 with base address of opt_gas_change
	rcall	deco_setup_copy					; copy all gas change depths

	; switch deco engine to oc mode
	bcf		lo,DECO_MODE_PSCR_FLAG			; clear the pSCR-mode flag (may not be set, but never mind)
	bcf		lo,DECO_MODE_LOOP_FLAG			; clear the loop/CCR-mode flag
	movff	lo,char_O_deco_status			; bank safe write-back of char_O_deco_status
	return									; done


;-----------------------------------------------------------------------------
; Helper Function - dedicated Memory Copy
deco_setup_copy:
	movlw	NUM_GAS						; load loop counter with number of gases (5)
deco_setup_copy_loop:
	movff	POSTINC1,POSTINC2			; copy from (FSR1) to (FSR2)
	decfsz	WREG						; decrement loop counter and check if it became 0
	bra		deco_setup_copy_loop		; NO  - not yet, loop
	return								; YES - done



 IFDEF _ccr_pscr

;-----------------------------------------------------------------------------
; Setup everything to enter CCR/pSCR Dive Mode - Part 1
;
	global	dive_boot_cc
dive_boot_cc:
	rcall	get_first_dil_to_WREG		; get first diluent (1-5) into WREG
	rcall	setup_dil_registers			; set-up of diluent parameters for currently breathed diluent (with WREG = current diluent 1-5)
	rcall	deco_setup_cc_diluents		; set-up of diluent list for deco calculations                (with WREG = current diluent 1-5)
	return								; done


;-----------------------------------------------------------------------------
; Helper Function - get first Diluent (1-5) into WREG
;
	global	get_first_dil_to_WREG
get_first_dil_to_WREG:					; gets first dil (1-5) into WREG
	lfsr	FSR1,opt_dil_type			; load base address of the dil types
	clrf	lo							; start with dil 0
get_first_dil_to_WREG2:
	movf	lo,W						; set index
	movf	PLUSW1,W					; get type of Dil (0=Disabled, 1=First, 2=Normal)
	sublw	.1							; is it of type First?
	bz		get_first_dil_to_WREG3		; YES - found the First dil
	incf	lo,F						; NO  - increment index
	movlw	NUM_GAS+1					;     - get highest index+1
	cpfseq	lo							;     - dils checked?
	bra		get_first_dil_to_WREG2		;       NO  - not yet
	movlw	.1							;       YES - default to dil 1
	movff	WREG,opt_dil_type+0			;           - force it to be of type First
	return								;           - done
get_first_dil_to_WREG3:
	movf	lo,W						; copy index of dil found to be the First to WREG
	incf	WREG,W						; turn index into dil number (0-4 -> 1-5)
	return								; done


;-----------------------------------------------------------------------------
; Helper Function - load currently breathed Diluent into Deco Engine
;
	global	setup_dil_registers
setup_dil_registers:
	btfsc	bailout_mode					; check if in bailout condition                      | --------------- FOR SAFETY ONLY --------------
	bra		setup_gas_registers				; revert to setting up OC gases in bailout condition | This branch should never happen to be taken...
	movwf	active_dil						; set as current diluent
	movlw	.6								; diluent = gas6 ?
	cpfseq	active_dil						; ...
	bra		setup_dil_registers_15			; NO - load diluent 1-5

	; load gas 6
	movff	opt_gas6_O2_ratio,char_I_O2_ratio	; copy gas6 O2 ratio to deco engine
 IFDEF _helium
	movff	opt_gas6_He_ratio,char_I_He_ratio	; copy gas6 He ratio to deco engine
 ENDIF
	movlw	.2								; declare gas6 as a normal diluent
	movff	WREG,char_I_current_gas_type	; copy gas type to deco engine
	movff	depth_meter,char_I_gas6_depth	;set current depth as change depth
	bra		setup_dil_registers_com			; continue with common part

setup_dil_registers_15:
	lfsr	FSR1,opt_dil_O2_ratio			; load base address of diluent data
	decf	active_dil,W					; set index to O2 ratio of current diluent (1-5 -> 0-4)
	movff	PLUSW1,char_I_O2_ratio			; copy         O2 ratio to deco engine
	addlw	.10								; advance index from O2 ratio to He ratio
 IFDEF _helium
	movff	PLUSW1,char_I_He_ratio			; copy         He ratio to deco engine
 ENDIF
	addlw	.10								; advance index from He ratio to diluent type
	movff	PLUSW1,char_I_current_gas_type	; copy diluent type (0=Disabled, 1=First, 2=Normal)
setup_dil_registers_com:
	movff	char_O_main_status,lo			; working copy of char_O_main_status in bank common
	bsf		lo,DECO_MODE_LOOP_FLAG			; loop flag is set in both, CCR and pSCR mode
	bcf		lo,DECO_MODE_PSCR_FLAG			; clear pSCR mode flag by default
	btfsc	FLAG_pscr_mode					; check if we are in pSCR mode
	bsf		lo,DECO_MODE_PSCR_FLAG			; YES - set additional flag for pSCR mode
	movff	lo,char_O_main_status			; bank safe write-back of char_O_main_status
	movf	active_dil,W					; reload WREG with diluent 1-5 or 6 (important!)
	return									; done


;-----------------------------------------------------------------------------
; Helper Function - load Diluents into Deco Engine (currently breathed dil in WREG)
;
	global	deco_setup_cc_diluents
deco_setup_cc_diluents:
	movff	char_O_deco_status,lo			; working copy of char_O_deco_status in bank common
deco_setup_cc_diluents_pre:					; entry point with lo preloaded
	btfsc	bailout_mode					; check if in bailout condition       | --------------- FOR SAFETY ONLY --------------
	bra		deco_setup_oc_gases_pre			; YES - revert to setting up OC gases | This branch should never happen to be taken...
	movff	WREG,char_I_current_gas_num		; NO  - set diluent to start with when doing the deco calculations
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
	lfsr	FSR2,char_I_deco_O2_ratio		; load FSR2 with base address of char_I_deco_O2_ratio.
											; FSR2 will step through all char_I_deco_... vars.
	lfsr	FSR1,opt_dil_O2_ratio			; load FSR1 with base address of opt_dil_O2_ratio
	rcall	deco_setup_copy					; copy all dil O2 ratios
	lfsr	FSR1,opt_dil_He_ratio			; load FSR1 with base address of opt_dil_He_ratio
	rcall	deco_setup_copy					; copy all dil He ratios
	lfsr	FSR1,opt_dil_type				; load FSR1 with base address of opt_dil_type
	rcall	deco_setup_copy					; copy all dil types
	lfsr	FSR1,opt_dil_change				; load FSR1 with base address of opt_dil_change
	rcall	deco_setup_copy					; copy all dil change depths
											; switch to CCR / pSCR mode:
	bsf		lo,DECO_MODE_LOOP_FLAG			; - loop flag is set in both, CCR and pSCR mode
	bcf		lo,DECO_MODE_PSCR_FLAG			; - clear pSCR mode flag by default
	btfsc	FLAG_pscr_mode					; - check if we are in pSCR mode
	bsf		lo,DECO_MODE_PSCR_FLAG			;   YES - set additional flag for pSCR mode
	movff	lo,char_O_deco_status			; - bank safe write-back of char_O_deco_status
	return									; done


;-----------------------------------------------------------------------------
; Setup everything to enter CCR / pSCR Dive Mode - Part 2
;
dive_boot_cc_part2:
	; revoke sensors from usage if they do not have a valid calibration
	bsf		use_O2_sensor1
	btfss	sensor1_calibrated_ok
	bcf		use_O2_sensor1

	bsf		use_O2_sensor2
	btfss	sensor2_calibrated_ok
	bcf		use_O2_sensor2

	bsf		use_O2_sensor3
	btfss	sensor3_calibrated_ok
	bcf		use_O2_sensor3

 IFDEF _external_sensor
	; check for external HUD/ppO2 Monitor
	btfss	ext_input_optical			; do we have an optical input?
	bra		dive_boot_cc_part2_1		; NO
	btfsc	sensor1_active				; YES - process flags from HUD/ppO2 Monitor
	bsf		use_O2_sensor1				;     - ...
	btfsc	sensor2_active				;     - ...
	bsf		use_O2_sensor2				;     - ...
	btfsc	sensor3_active				;     - ...
	bsf		use_O2_sensor3				;     - ...
 ENDIF

dive_boot_cc_part2_1:
	; In pSCR mode, only settings 0 (calculated ppO2) and 1 (ppO2 from sensors) are defined.
	; In case we still have 3 (auto SP) selected out of previous CCR mode, we reset to 0.
	btfss	FLAG_pscr_mode				; in pSCR mode?
	bra		dive_boot_cc_part2_2		; NO
	movf	dive_ccr_mode,W				; YES - get mode (=0: Fixed SP (CCR) / calculated SP (pSCR), =1: Sensor, =2: Auto SP)
	sublw	.2							; dive_ccr_mode = 1 (Auto SP)?
	bnz		dive_boot_cc_part2_2		; NO  - ok
	clrf	dive_ccr_mode				; YES - revert to calculated SP

dive_boot_cc_part2_2:
	bsf		event_SP_change				; set setpoint event flag

	; Start with SP1 (CCR) or 0 (pSCR) as default.
	; If in sensor mode, this value will be overwritten by calc_deko_divemode_sensor
	clrf	WREG						; pre-load WREG with setpoint value 0 for pSCR calculated
	btfsc	FLAG_ccr_mode				; in CCR mode?
	movff	opt_setpoint_cbar+0,WREG	; YES - get value of setpoint 1 into WREG
	movff	WREG,char_I_const_ppO2		; write setpoint to deco engine

 IFDEF _external_sensor
	call	transmit_setpoint			; transmit current setpoint from WREG (in cbar) to external electronics
	goto	calc_deko_divemode_sensor	; process sensor readings and return
 ELSE
	return								; done
 ENDIF

 ENDIF	; _ccr_pscr


;=============================================================================
dmode3	CODE
;=============================================================================


;-----------------------------------------------------------------------------
; Initialize Dive Mode
;
diveloop_boot:
	; do the basic initialization
	call	restart_set_modes_and_flags	; basic settings depending on deco mode

	; save on energy
	call	I2C_sleep_compass			; stop accelerometer and compass

	; do an early initialization of all deco engine output variables to
	; avoid glitches in the display outputs during deco engine start-up
	call	deco_init_output_vars;		; (C-code)
	banksel	common						; back to bank common

	; configure screen layout
	TSTOSC	opt_layout					; alternative layout enabled?
	bsf		alt_layout_active			; YES - start with alternative layout

	; configure tissue graphics
	TSTOSC	opt_tissue_graphics			; shall show: 0= pres+sat, 1= N2+He
	bsf		tissue_graphic_layout		; YES - show press+sat
	TSTOSC	char_I_model				; GF factors enabled?
	bsf		tissue_graphic_gf			; YES - show GF lines

	; reset max relative pressure (max depth)
	bsf		reset_max_pressure			; request ISR to reset the max pressure

	; make working copy of opt_ccr_mode
	movff	opt_ccr_mode,dive_ccr_mode	; copy option setting


 IFDEF _min_depth_option
	; reset the resettable min/max relative pressure (trip-wise min/max depth)
	bsf		reset_trip_pressure			; request ISR to reset the resettable min/max pressure
 ENDIF

 IFDEF _cave_mode
	; initialize the cave mode
	bcf		cave_mode					; disable cave mode by default
	TSTOSC	opt_cave_mode				; cave mode switched on?
	bsf		cave_mode					; YES - enable cave mode

	bcf		dive_turned					; dive is not turned yet
	bcf		backtrack_almost_full		; backtracking storage is not almost   full yet
	bcf		backtrack_entire_full		; backtracking storage is not entirely full yet
	bsf		waypoint_reached_first		; current waypoint is the first recorded waypoint
	bsf		waypoint_reached_last		; current waypoint is the last  recorded waypoint

	clrf	backtrack_waypoint_num		; initialize the waypoint number
	clrf	backtrack_waypoint_turn		; no turn point yet

	movlw	.0							; initialize backtracking index to first position in storage
	movff	WREG,char_I_backtrack_index	; ...

	clrf	depth_meter					; store initial depth data set with depth = surface
	call	write_backtrack_1min_depth	; ...
 ENDIF	; _cave_mode

	; base configuration of the deco engine
	clrf	hi							; start with everything disabled
	TSTOSC	opt_ext_stops				; shall make extended stops?
	bsf		hi,DECO_EXTENDED_STOPS		; YES - enable extended stops
 IFDEF _rx_functions
	btfsc	tr_functions_activated		; TR functions activated?
	bsf		hi,DECO_TR_FUNCTIONS		; YES - enable TR functions
 ENDIF
 IFDEF _gas_contingency
	; set contingency mode on/off
	TSTOSC	opt_gas_contingency_dive	; gas contingency for dive mode switched on?
	bsf		hi,DECO_GAS_CONTINGENCY		; YES - activate gas contingency mode
 ENDIF	; _gas_contingency
	movff	hi,char_O_main_status		; bank-safe copy to deco engine

	clrf	lo							; start with everything disabled
	bsf		lo,DECO_START_NORM			; set flag for doing a normal plan
	bsf		lo,DECO_INITIALIZE			; set flag for initializing the deco engine
	movff	lo,char_O_deco_status		; bank-safe copy back to deco engine

	; disable "fast forward" function
	movlw	.0							; set fast forward to zero
	movff	WREG,char_I_sim_advance_time; ...

	; write last stop depth to deco engine
	movff	opt_last_stop,char_I_last_stop_depth

	; initialize max depth for apnoe mode
	CLRI	apnoe_max_pressure			; reset to zero

	; reset minimum temperature, ISR-safe 2 byte copy
	SMOVII	temperature_cur,temperature_min

	; ISR-safe copy of start-of-dive date and time for logbook (6 bytes in total)
	SMOVSS	rtc_year,start_year

	MOVII	int_O_CNS_current,CNS_start		; save current CNS at beginning of dive, but
	bcf		CNS_start+1,int_warning_flag	; without warning   flag
	bcf		CNS_start+1,int_attention_flag	; without attention flag

	; save supersaturation at beginning of dive (only lower byte is used for value)
	movff	int_O_lead_supersat+0,supersat_start

	clrf	menu_pos_cur				; reset current menu position
	clrf	active_premenu				; no pre-menu task active

	clrf	safety_stop_countdown		; clear safety stop count-down

	CLRI	last_pressure_velocity		; initialize last pressure for velocity calculation
	CLRI	dive_timeout_timer			; initialize timeout counter

	movlw	.1							; initialize the sampling timer such that the 1st sampling ...
	movwf	sampling_timer				; ... trigger will be given as soon as possible

	clrf	message_page				; initialize message page counter
	clrf	alarm_type					; clear all alarms

	; clear the total dive average depth
	CLRI	pressure_rel_avg_total		; average depth
	CLRI	divesecs_avg_total			; time  accumulator
	clrf	pressure_rel_accu_total+0	; depth accumulator
	clrf	pressure_rel_accu_total+1	; ...
	clrf	pressure_rel_accu_total+2	; ...
	clrf	pressure_rel_accu_total+3	; ...

 IFDEF _rx_functions

	btfss	tr_functions_activated		; TR functions activated?
	bra		diveloop_boot_0				; NO  - skip TR function initialization

	banksel	int_IO_pressure_value

	clrf	WREG						; set WREG to coding for integer numbers -> data not available
	bsf		WREG,int_not_avail_flag		; ...
	clrf	int_IO_pressure_value+0		; clear   low  byte   of 1st pressure reading value
	movwf	int_IO_pressure_value+1		; copy to high byte   of 1st pressure reading value
	clrf	int_IO_pressure_value+2		; clear   low  byte   of 2nd pressure reading value
	movwf	int_IO_pressure_value+3		; copy to high byte   of 2nd pressure reading value
	clrf	int_I_pressure_drop+0		; clear   low  byte   of 1st pressure drop    value
	movwf	int_I_pressure_drop+1		; copy to high byte   of 1st pressure drop    value
	clrf	int_I_pressure_drop+2		; clear   low  byte   of 2nd pressure drop    value
	movwf	int_I_pressure_drop+3		; copy to high byte   of 1st pressure drop    value
	clrf	char_I_pressure_gas+0		; clear gas selection of 1st pressure reading
	clrf	char_I_pressure_gas+1		; clear gas selection of 2nd pressure reading
	clrf	char_I_pressure_age+0		; clear age           of 1st pressure reading
	clrf	char_I_pressure_age+1		; clear age           of 2nd pressure reading
	clrf	char_I_pressure_stat+0		; clear status        of 1st pressure reading
	clrf	char_I_pressure_stat+1		; clear status        of 2nd pressure reading

	banksel	gas__last_1st				; select bank with vars for pressure drop calculation
	setf	gas__last_1st				; invalidate last gas of 1st reading
	setf	gas__last_2nd				; invalidate last gas of 2nd reading

	banksel	common						; back to bank common

 ENDIF	; _rx_functions


diveloop_boot_0:
	setf	best_gas_number				; initialize best gas     as not computed yet (255)
 IFDEF _ccr_pscr
	setf	best_dil_number				; initialize best diluent as not computed yet (255)
 ENDIF

	btfsc	FLAG_oc_mode				; in OC mode?
	call	dive_boot_oc				; YES - add OC mode settings

 IFDEF _ccr_pscr
	btfsc	FLAG_ccr_mode				; in CCR mode?
	call	dive_boot_cc				; YES - add CC mode settings
	btfsc	FLAG_ccr_mode				; in CCR mode?
	call	dive_boot_cc_part2			; YES - add CC sensor and SP settings

	btfsc	FLAG_pscr_mode				; in pSCR mode?
	call	dive_boot_cc				; YES - add CC mode settings
	btfsc	FLAG_pscr_mode				; in pSCR mode?
	call	dive_boot_cc_part2			; YES - add CC sensor and SP settings
 ENDIF

	bcf		bailout_mode				; not in bailout mode

	call	ghostwriter_short_header	; write short header with dive number into profile memory
	call	init_recording_params		; set up all the divisors for dive data recording

	; setup gas selector flag (required to have better gas working)
	bsf		is_diluent_menu				; default to using diluents
	btfsc	FLAG_ccr_mode				; in CCR mode?
	bra		diveloop_boot_3				; YES - default was right
	btfsc	FLAG_pscr_mode				; in pSCR mode?
	bra		diveloop_boot_3				; YES - default was right
	bcf		is_diluent_menu				; NO to both - revert to using OC gases

diveloop_boot_3:
	bcf		LEDg						; switch off green LED / release reset to RX circuitry
	bcf		LEDr						; switch off red   LED

	btfss	sensor_override_active		; in simulator mode?
	call	disable_rs232				; NO - disable RS232

 IFDEF _screendump
	btfsc	screen_dump_avail			; screen dump function enabled?
	call	enable_rs232				; enable interface (also sets CPU speed to normal)
 ENDIF

	clrf	apnoe_surface_mins			; clear apnoe surface time, minutes (8 bit)
	clrf	apnoe_surface_secs			; clear apnoe surface time, seconds (8 bit)
	clrf	apnoe_dive_mins				; clear apnoe dive    time, minutes (8 bit)
	clrf	apnoe_dive_secs				; clear apnoe dive    time, seconds (8 bit)

	return								; done with dive mode boot


;=============================================================================
dmode4	CODE
;=============================================================================


;-----------------------------------------------------------------------------
; Check all Sorts of Parameters and issue Warnings and Attentions if applicable
;
divemode_check_warnings:
	movlw	.1							; one message at a time in alternative layout
	btfss	alt_layout_active			; in alternative layout?
	movlw	.2							; NO - two messages at a time in normal layout
	cpfsgt	message_counter				; had more than 1 / 2 messages in the last round?
	bra		divemode_check_warnings1	; NO  - update messages every second

;										; YES - update every 4 seconds:
;	btfss	timebase_1sec				;     - on second 1 or 3 ?
;	return								;       NO  - no update in this cycle
;	btfss	timebase_2sec				;       YES - on second 3 ?
;	return								;             NO  - no update in this cycle
;	;bra	divemode_check_warnings1	;             YES - update messages

										; YES - update every 2 seconds
	btfsc	timebase_1sec				;     - on even second?
	return								;       NO  - done
	;bra	divemode_check_warnings1	;       YES - update messages

divemode_check_warnings1:
	clrf	message_counter				; clear message counter

	; messages sorted by severity: highest severity warnings first, then attentions, advices and last info

	; warnings for all modes
	call	check_battery				; check battery status
	rcall	check_depth_limit			; check current depth
	call	check_divetimeout			; check dive timeout

	btfsc	FLAG_apnoe_mode				; in apnoe mode?
	bra		divemode_check_warnings2	; YES - skip deco mode checks

	btfsc	FLAG_gauge_mode				; in gauge mode?
	bra		divemode_check_warnings2	; YES - skip deco mode checks

	; warnings applicable only in deco modes

 IFDEF _cave_mode
	rcall	check_cavemode				; check cave mode status
 ENDIF

	rcall	check_display_ftts			; show  fTTS time (or cave mode cTTS)
	rcall	check_ppO2					; check ppO2

 IFDEF _external_sensor
	rcall	check_ext_sensors			; check external sensors
 ENDIF

	rcall	check_outside				; check of ZHL16 model violation

 IFDEF _ccr_pscr
	btfsc	FLAG_ccr_mode				; in CCR mode?
	rcall	check_OC_gas_avail			; YES - check if a breathable OC (bailout) gas is available
	btfsc	FLAG_pscr_mode				; in pSCR mode?
	rcall	check_OC_gas_avail			; YES - check if a breathable OC (bailout) gas is available
 ENDIF

	btfsc	decostop_active				; in deco mode?
	rcall	check_saturation			; YES - check tissue saturation

	rcall	check_mbubbles				; check for micro bubbles
	rcall	check_cns_violation_now		; check current     CNS value
	rcall	check_cns_violation_eod		; check end-of-dive CNS value (needs to be done after check_cns_violation_now)
	rcall	check_gas_needs				; check for gas needs
	rcall	check_gas_change			; check for diluent or gas change advice

 IFDEF _ccr_pscr
	btfsc	FLAG_ccr_mode				; in CCR mode?
	rcall	check_gas_density			; YES - check gas density
	btfsc	FLAG_pscr_mode				; in pSCR mode?
	rcall	check_gas_density			; YES - check gas density
 ENDIF

	btfsc	use_aGF						; using alternative GF factors?
	rcall	remind_agf_in_use			; YES - show reminder

divemode_check_warnings2:

 IFDEF _rx_functions
	btfss	tr_functions_activated		; TR functions activated?
	bra		divemode_check_warnings3	; NO  - skip
	call	check_tr_functions			; YES - check transmitter functions
	call	check_tr_messages			;     - check SAC attention and switch advice
 ENDIF

divemode_check_warnings3:

	; compute if an advice / attention / warning sign shall be shown
	rcall	divemode_check_sign

	; increment message page number
	incf	message_page,F				; increment page number
	bcf		STATUS,C					; clear carry bit
	movf	message_page,W				; get page number into WREG
	btfss	alt_layout_active			; in alternative layout?
	rlcf	WREG,W						; NO - each page can take two messages
	cpfsgt	message_counter				; number of actual messages > message capacity ?
	clrf	message_page				; NO - all messages could be shown, restart from first page next time

	; clear both rows of messages if there is nothing to show at all
	tstfsz	message_counter				; any message to show?
	bra		divemode_check_warnings4	; YES - look if second row needs to be cleared
	bsf		FLAG_TFT_message_clear_both	; NO  - request clearing of left-over messages
	return								;     - done

divemode_check_warnings4:
	; clear 2nd row of messages if there is nothing to show (on this page)
	btfss	message_2nd_row_used		; does the 2nd row contain a message?
	bsf		FLAG_TFT_message_clear_2nd	; NO - set flag to clear the 2nd row
	return								; done


;-----------------------------------------------------------------------------
; Helper Function - check if an Advice / Attention / Warning Sign shall be shown
;
divemode_check_sign:
	; clear sign flags
	bcf		sign_advice					; clear flag for showing advice    sign
	bcf		sign_attention				; clear flag for showing attention sign
	bcf		sign_warning				; clear flag for showing warning   sign

	; check for new advices
	movf	DM_flags_advc_det,W			; get current advices
	andwf	DM_flags_advc_ack,W			; keep only those acknowledgments that have current advices
	movwf	DM_flags_advc_ack			; store updated acknowledgments
	xorwf	DM_flags_advc_det,W			; find advices that have not been acknowledged yet
	tstfsz	WREG						; any new advice?
	bsf		sign_advice					; YES - set flag for showing advice sign

	; check for new attentions (1)
	movf	DM_flags_att1_det,W			; get current attentions
	andwf	DM_flags_att1_ack,W			; keep only those acknowledgments that have current attentions
	movwf	DM_flags_att1_ack			; store updated acknowledgments
	xorwf	DM_flags_att1_det,W			; find attentions that have not been acknowledged yet
	tstfsz	WREG						; any new attention?
	bsf		sign_attention				; YES - set flag for showing attention sign

	; check for new attentions (2)
	movf	DM_flags_att2_det,W			; get current attentions
	andwf	DM_flags_att2_ack,W			; keep only those acknowledgments that have current attentions
	movwf	DM_flags_att2_ack			; store updated acknowledgments
	xorwf	DM_flags_att2_det,W			; find attentions that have not been acknowledged yet
	tstfsz	WREG						; any new attention?
	bsf		sign_attention				; YES - set flag for showing attention sign

	; check for new attentions (3)
	movf	DM_flags_att3_det,W			; get current attentions
	andwf	DM_flags_att3_ack,W			; keep only those acknowledgments that have current attentions
	movwf	DM_flags_att3_ack			; store updated acknowledgments
	xorwf	DM_flags_att3_det,W			; find attentions that have not been acknowledged yet
	tstfsz	WREG						; any new attention?
	bsf		sign_attention				; YES - set flag for showing attention sign

	; check for new warnings (1)
	movf	DM_flags_war1_det,W			; get current warnings
	andwf	DM_flags_war1_ack,W			; keep only those acknowledgments that have current warnings
	movwf	DM_flags_war1_ack			; store updated acknowledgments
	xorwf	DM_flags_war1_det,W			; find warnings that have not been acknowledged yet
	tstfsz	WREG						; any new warning?
	bsf		sign_warning				; YES - set flag for showing warning sign

	; check for new warnings (2)
	movf	DM_flags_war2_det,W			; get current warnings
	andwf	DM_flags_war2_ack,W			; keep only those acknowledgments that have current warnings
	movwf	DM_flags_war2_ack			; store updated acknowledgments
	xorwf	DM_flags_war2_det,W			; find warnings that have not been acknowledged yet
	tstfsz	WREG						; any new warning?
	bsf		sign_warning				; YES - set flag for showing warning sign

	; show or clear the advice / attention / warning sign
	btfsc	sign_advice					; shall show advice sign?
	bsf		FLAG_TFT_sign_show			; YES - show sign
	btfsc	sign_attention				; shall show attention sign?
	bsf		FLAG_TFT_sign_show			; YES - show sign
	btfsc	sign_warning				; shall show warning sign?
	bsf		FLAG_TFT_sign_show			; YES - show sign
	btfss	FLAG_TFT_sign_show			; shall show any sign?
	bsf		FLAG_TFT_sign_clear			; NO  - then clear the sign

	return								; done


;-----------------------------------------------------------------------------
; Check Battery Power
;
	global	check_battery
check_battery:
	bcf		warn_det_batt_low			; clear warning for battery low
	movlw	battery_show_level+1		; get threshold for showing battery level, incremented by 1
	cpfslt	batt_percent				; battery percentage ok?
	return								; YES - done
	btfsc	battery_low_condition		; NO  - battery low condition detected?
	bsf		warn_det_batt_low			;       YES - set warning for battery low
	movf	active_customview,W			;     - get current custom view
	xorlw	index_clock_batt_surfpress	;     - battery shown in custom view?
	bnz		check_battery_mesg			;       NO  - show message
	return								;       YES - do not show twice, done

check_battery_mesg:
	incf	message_counter,F			; increase message counter
	goto	TFT_message_battery_percent	; show message for battery low (battery percent) and return


;-----------------------------------------------------------------------------
; Show Dive Timeout Counter if Dive Time is not counted
;
check_divetimeout:
	btfsc	count_divetime				; is dive time counted?
	return								; YES - nothing to do, done
	incf	message_counter,F			; NO  - increase message counter
	goto	TFT_message_divetimeout		;     - show timeout counter and return


;-----------------------------------------------------------------------------
; Check ppO2 of all Gases / Diluents in use
;
check_ppO2:
 IFDEF _ccr_pscr
	; check if breathing from the loop
	btfsc	FLAG_oc_mode				; in OC mode?
	bra		check_ppO2_1				; YES - continue with breathed gas
	btfsc	bailout_mode				; NO  - in bailout?
	bra		check_ppO2_1				;       YES - continue with breathed gas
	; CCR / pSCR mode - check the pure diluent
	bcf		warn_det_ppO2_diluent		; clear warning   for pure diluent ppO2
	bcf		attn_det_ppo2_diluent		; clear attention for pure diluent ppO2
	MOVII	int_O_pure_ppO2,mpr			; get value and attention/warning flags for the pure diluent
	btfsc	hi,int_warning_flag			; ppO2 of the pure diluent in warning state?
	bra		check_ppO2_dil_warn			; YES - show warning
	btfsc	hi,int_attention_flag		; ppO2 of the pure diluent in attention state?
	bra		check_ppO2_dil_attn			; YES - show attention
	bra		check_ppO2_1				; continue with checking breathed gas

check_ppO2_dil_warn:
	bsf		warn_det_ppO2_diluent		; set warning   for pure diluent ppO2
	rcall	check_ppO2_show_mesg		; show ppO2 message
	bra		check_ppO2_1				; continue with checking breathed gas

check_ppO2_dil_attn:
	bsf		attn_det_ppo2_diluent		; set attention for pure diluent ppO2
	rcall	check_ppO2_show_mesg		; show ppO2 message
	;bra	check_ppO2_1				; continue with checking breathed gas
 ENDIF	; _ccr_pscr

check_ppO2_1:
	; all modes - check breathed gas (OC or loop)
	bcf		attn_det_ppo2_breathed		; clear attention for breathed ppO2
	bcf		warn_det_ppO2_breathed		; clear warning   for breathed ppO2
	MOVII	int_O_breathed_ppO2,mpr		; get value and attention/warning flags for the breathed gas
	btfsc	hi,int_attention_flag		; breathed ppO2 in attention state (when in loop mode, no attention will be generated)?
	bra		check_ppO2_breath_attn		; YES - set attention flag and show ppO2
	btfsc	hi,int_low_flag				; NO  - breathed ppO2 too low?
	bra		check_ppO2_breath_warn_low	;       YES - record the warning and show ppO2
	btfsc	hi,int_high_flag			;       NO  - breathed ppO2 too high?
	bra		check_ppO2_breath_warn_high	;             YES - record the warning and show ppO2
	bra		check_ppO2_breath_ok		;             NO  - ppO2 is ok

check_ppO2_breath_attn:
	bsf		attn_det_ppo2_breathed		; set attention for breathed ppO2
	bra		check_ppO2_show				; show ppO2 message

check_ppO2_breath_warn_low:
	movlw	d'4'						; set type of alarm (ppO2 low)
	bra		check_ppO2_breath_common	; continue with common part

check_ppO2_breath_warn_high:
	movlw	d'5'						; set type of alarm (ppO2 high)
	;bra	check_ppO2_breath_common	; continue with common part

check_ppO2_breath_common:
	movwf	alarm_type					; copy alarm type to alarm register
	bsf		event_occured				; set event flag
	bsf		warn_det_ppO2_breathed		; set warning for breathed ppO2
	bra		check_ppO2_show				; show ppO2 message

check_ppO2_breath_ok:
	TSTOSS	opt_showppo2				; shall always show ppO2 (0 = no, 1 = yes)
	return								; NO  - done
	;bra	check_ppO2_show				; YES - show ppO2 message

check_ppO2_show:
 IFDEF _ccr_pscr
	btfsc	FLAG_oc_mode				; in OC mode?
	bra		check_ppO2_show_1			; YES - show ppO2 message
	btfsc	bailout_mode				; in bailout mode?
	bra		check_ppO2_show_1			; YES - show ppO2 message
	return								; NO  - in loop mode, ppO2 is already shown via setpoint display
 ENDIF
check_ppO2_show_1:
	movf	active_customview,W			; get current custom view
	xorlw	index_ppo2_ead_end_cns		; ppO2 shown already via custom view?
	bz		check_ppO2_done				; YES - done
	movf	active_customview,W			; get current custom view (again)
	xorlw	index_pscr_info				; ppO2 shown already via custom view?
	bz		check_ppO2_done				; YES - done
	;bra	check_ppO2_show_mesg		; NO  - show ppO2 message

check_ppO2_show_mesg:
	incf	message_counter,F			; increase message counter
	goto	TFT_message_ppo2			; show ppO2 message and return

check_ppO2_done:
	return								; done


;-----------------------------------------------------------------------------
; Show fTTS Message
;
check_display_ftts:
 IFDEF _ccr_pscr
	btfsc	bailout_mode				; in bailout mode?
	return								; YES - in bailout no fTTS is computed, done
 ENDIF
	btfss	count_divetime				; is dive time counted?
	return								; NO  - omit, done
	movff	char_I_extra_time,lo		; YES - get extra time
	tstfsz	lo							;     - extra time > 0 ?
	bra		check_display_ftts_mesg		;       YES - show fTTS
	return								;       NO  - no fTTS computed, done

check_display_ftts_mesg:
	incf	message_counter,F			; increase counter
	goto	TFT_message_ftts			; show @+x time


;-----------------------------------------------------------------------------
; check current CNS Value
;
	global	check_cns_violation_now
check_cns_violation_now:
	bcf		warn_det_cns_current		; clear warning   for CNS
	bcf		attn_det_cns_current		; clear attention for CNS
	movff	int_O_CNS_current+1,WREG	; get current CNS, high byte
	btfsc	WREG,int_warning_flag		; warning flag set?
	bra		check_cns_violation_now_warn; YES - show a warning
	btfsc	WREG,int_attention_flag		; attention flag set?
	bra		check_cns_violation_now_attn; YES - show an attention
	return								; NO  - done

check_cns_violation_now_warn:
	bsf		warn_det_cns_current		; set warning for CNS
	bra		check_cns_violation_now_mesg; show message

check_cns_violation_now_attn:
	bsf		attn_det_cns_current		; set attention for CNS
	;bra	check_cns_violation_now_mesg; show message

check_cns_violation_now_mesg:
 IFNDEF _helium
	movf	active_customview,W			; get current custom view
	xorlw	index_ppo2_ead_end_cns		; CNS shown?
	bz		check_cns_violation_now_done; YES - done
 ENDIF
	movf	active_customview,W			; get current custom view (again)
	xorlw	index_CNS					; CNS shown?
	bz		check_cns_violation_now_done; YES - done
	incf	message_counter,F			; NO  - increase counter
	goto	TFT_message_cns				;     - show message and return

check_cns_violation_now_done:
	return								; done


;-----------------------------------------------------------------------------
; check end-of-Dive CNS Value
;
	global	check_cns_violation_eod
check_cns_violation_eod:
	bcf		attn_det_cns_eod			; clear attention for end-of-dive CNS
	btfsc	warn_det_cns_current		; current CNS value in warning state?
	return								; YES - inhibit end-of-dive CNS checks if current CNS is already in warning
	;bra	check_cns_violation_eod_norm; NO  - check normal plan

check_cns_violation_eod_norm:
	movff	int_O_CNS_norm+1,WREG		; get CNS at end of dive in normal plan, high byte
	btfsc	WREG,int_invalid_flag		; flag for invalid value set?
	bra		check_cns_violation_eod_alt	; YES - continue with checking alternative plan
	btfsc	WREG,int_warning_flag		; NO  - flag for warning set?
	bra		check_cns_violation_eod_warn;       YES - show message
	;bra	check_cns_violation_eod_alt	;       NO  - check alternative plan

check_cns_violation_eod_alt:
	movff	int_O_CNS_alt+1,WREG		; get CNS at end of dive in alternative plan, high byte
	btfsc	WREG,int_invalid_flag		; flag for invalid value set?
	return								; YES - done
	btfsc	WREG,int_warning_flag		; NO  - flag for warning set?
	bra		check_cns_violation_eod_warn;       YES - show message
	return								;       NO  - done

check_cns_violation_eod_warn:
	bsf		attn_det_cns_eod			; set attention(!) for end-of-dive CNS
	movf	active_customview,W			; get current custom view
	xorlw	index_CNS					; CNS shown?
	bz		check_cns_violation_eod_done; YES - done
	incf	message_counter,F			; NO  - increase message counter
	goto	TFT_message_cns_eod			;     - show message for end-of-dive CNS and return

check_cns_violation_eod_done:
	return								; done


;-----------------------------------------------------------------------------
; Check current Tissue Supersaturation
;
	global	check_saturation
check_saturation:
	bcf		attn_det_saturation			; clear attention for saturation
	bcf		warn_det_saturation			; clear warning   for saturation
	bcf		attn_det_ibcd				; clear attention for IBCD
	movff	int_O_lead_supersat+1,WREG	; get upper byte of leading tissue's supersaturation
	btfss	WREG,int_warning_flag		; warning flag set?
	bra		check_saturation_1			; NO  - continue with checking for attention flag
	movlw	d'2'						; YES - set type of alarm
	movwf	alarm_type					;     - copy to alarm register
	bsf		event_occured				;     - set event flag
	bsf		warn_det_saturation			;     - set   warning
	bra		check_saturation_mesg		;     - show saturation message

check_saturation_1:
	btfss	WREG,int_attention_flag		; attention flag set?
	bra		check_saturation_2			; NO  - continue with checking for IBCD
	bsf		attn_det_saturation			; YES - set   attention
	bra		check_saturation_mesg		;     - show saturation message

check_saturation_2:
 IFDEF _helium
	TSTOSS	opt_enable_IBCD				; IBCD warning activated?
	bra		check_saturation_3			; NO  - continue with checking deco info
	movff	char_O_deco_warnings,WREG	; YES - get the deco warnings vector
	btfss	WREG,IBCD_warning			;     - IBCD warning flag set?
	bra		check_saturation_3			;       NO  - continue with checking deco info
	bsf		attn_det_ibcd				;       YES - set attention
	bra		check_saturation_mesg		;           - show saturation message
 ENDIF

check_saturation_3:
	btfss	divemode					; in dive mode?
	return								; NO  - done
 IFDEF _ccr_pscr
	btfsc	bailout_mode				; YES - in bailout mode?
	return								;       YES - done (deco zone flag is not updated when in bailout mode)
 ENDIF
	movff	char_O_deco_info,WREG		;       NO  - get the deco info vector
	btfss	WREG,deco_zone				;             deco zone flag set?
	return								;             NO  - done
	btfsc	use_aGF						;             YES - using alternative GF factors?
	return								;                   YES - suppress deco zone info
	btfsc	alt_layout_active			;                   NO  - in alternative layout?
	return								;                         YES - suppress deco zone info
	incf	message_counter,F			;                         NO  - increase message counter
	goto	TFT_message_deco_info		;                             - show deco info and return

check_saturation_mesg:
 IFDEF _helium
	btfss	attn_det_ibcd				; IBCD detected?
	bra		check_saturation_mesg_1		; NO  - show saturation message
	incf	message_counter,F			; YES - increase message counter
	call	TFT_message_IBCD			;     - show IBCD message
 ENDIF
check_saturation_mesg_1:
	incf	message_counter,F			; increase message counter
	goto	TFT_message_saturation		; show saturation message and return


;-----------------------------------------------------------------------------
; Check Depth Limit
;
check_depth_limit:
	bcf		warn_det_depth_limit		; clear warning by default
	movff	opt_max_depth,WREG			; get depth limit
	cpfsgt	depth_meter					; current depth > depth limit?
	return								; NO  - done
	bsf		warn_det_depth_limit		; YES - set warning
	incf	message_counter,F			;     - increase message counter
	goto	TFT_message_depth_limit		;     - show message


;-----------------------------------------------------------------------------
; Check Bühlmann Model Violation
;
check_outside:
	bcf		warn_det_outside			; clear warning
	bcf		attn_det_outside			; clear attention
	movff	char_O_deco_warnings,WREG	; bank-safe copy of deco warnings
	btfss	WREG,outside_warning		; currently outside the ZH-L16 model?
	bra		check_outside_1				; NO
	bsf		warn_det_outside			; YES - set warning
	bra		check_outside_mesg			;     - show message

check_outside_1:
	btfss	WREG,outside_warning_lock	; had been outside of the ZH-L16 model?
	return								; NO  - done
	bsf		attn_det_outside			; YES - set attention
	;bra	check_outside_mesg			;     - show message

check_outside_mesg:
	incf	message_counter,F			; increase message counter
	goto	TFT_message_outside			; show message and return


;-----------------------------------------------------------------------------
; Check raised Probability for Micro-Bubbles
;
	global	check_mbubbles
check_mbubbles:
	bcf		warn_det_microbubble		; clear warning
	bcf		attn_det_microbubble		; clear attention
	movff	char_O_deco_warnings,WREG	; bank-safe copy for deco warnings
	btfss	WREG,mbubble_warning		; currently in micro bubbling zone?
	bra		check_mbubbles_1			; NO
	bsf		warn_det_microbubble		; YES - set warning
	bra		check_mbubbles_mesg			;     - show message

check_mbubbles_1
	btfss	WREG,mbubble_warning_lock	; had been in micro bubbling zone?
	return								; NO  - done
	bsf		attn_det_microbubble		; YES - set attention
	;bra	check_mbubbles_mesg			;     - show message

check_mbubbles_mesg:
	incf	message_counter,F			; increase message counter
	goto	TFT_message_mbubbles		; show message and return


 IFDEF _ccr_pscr
;-----------------------------------------------------------------------------
; Check Gas Density
;
check_gas_density:
	TSTOSS	opt_gas_density_check		; shall check gas density?
	return								; NO - done
	bcf		warn_det_gas_density		; YES - clear attention for gas density by default
	bcf		attn_det_gas_density		;     - clear warning   for gas density by default
	movff	int_O_gas_density+1,WREG	;     - get upper byte of current gas density
	btfsc	WREG,int_warning_flag		;     - warning flag set?
	bra		check_gas_density_warn		;       YES - generate a warning
	btfsc	WREG,int_attention_flag		;       NO  - attention flag set?
	bra		check_gas_density_attn		;             YES - generate an attention
	;bra	check_gas_density_ok		;             NO  - gas density ok

check_gas_density_ok:
	bcf		shown_gas_density_attn		; re-arm custom view show-up for warning
	bcf		shown_gas_density_warn		; re-arm custom view show-up for attention
	return								; done

check_gas_density_warn:
	bsf		warn_det_gas_density		; set warning
	bcf		shown_gas_density_attn		; re-arm custom view show-up for attention
	btfsc	shown_gas_density_warn		; has the custom view been shown before on warning level?
	bra		check_gas_density_mesg		; YES - do not show the gas needs custom view again
	btfsc	custom_view_locked			; NO  - custom view locked?
	bra		check_gas_density_mesg		;       YES - do not show it now
	bsf		shown_gas_density_warn		;       NO  - set custom view as shown now
	bra		check_gas_density_cv		;           - show gas needs custom view

check_gas_density_attn:
	bsf		attn_det_gas_density		; set attention
	bcf		shown_gas_density_warn		; re-arm custom view show-up for warning
	btfsc	shown_gas_density_attn		; has the custom view been shown before on attention level?
	bra		check_gas_density_mesg		; YES - do not show the gas needs custom view again
	btfsc	custom_view_locked			; NO  - custom view locked?
	bra		check_gas_density_mesg		;       YES - do not show it now
	bsf		shown_gas_density_attn		;       NO  - set custom view as shown now
	;bra	check_gas_density_cv		;           - show gas needs custom view

check_gas_density_cv:
	movlw	index_ppo2_ead_end_cns		; get  custom view number of gas density
	call	dive_customview_show		; show custom view
	;bra	check_gas_density_mesg		; show message

check_gas_density_mesg:
	incf	message_counter,F			; increase message counter
	goto	TFT_message_gas_density		; show gas density message and return


;-----------------------------------------------------------------------------
; Check if an OC Bailout Gas is available
;
check_OC_gas_avail:
	bcf		warn_det_no_bo_gas			; clear warning by default
	tstfsz	best_gas_number				; is a breathable OC (bailout) gas available?
	return								; YES - a breathable gas is available, done
	btfsc	bailout_mode				; NO  - in bailout?
	return								;       YES - suppress warning, done
	bsf		warn_det_no_bo_gas			;       NO  - set warning for no bailout gas
	incf	message_counter,F			;           - increase message counter
	goto	TFT_message_no_BO_gas		;           - show message and return

 ENDIF	; _ccr_pscr


 IFDEF _cave_mode

;-----------------------------------------------------------------------------
; Check Cave Profile Storage Usage
;
check_cavemode:
	bcf		warn_det_cave_shut_down		; clear warning   by default
	bcf		attn_det_cave_shut_down		; clear attention by default
	btfsc	backtrack_entire_full		; is the backtracking storage entirely used up?
	bra		check_cavemode_full			; YES - turn dive, switch off cave mode and show warning message
	btfsc	backtrack_almost_full		; NO  - backtracking storage almost full?
	bra		check_cavemode_almost_full	;       YES - show attention message that cave mode will stop soon
	btfss	cave_mode					;       NO  - cave mode switched on?
	return								;             NO  - do not show info
	btfsc	alt_layout_active			;             YES - alternative layout active?
	return								;                   YES - suppress info message
	;bra	check_cavemode_mesg			;                   NO  - show cave mode active info

check_cavemode_mesg:
	incf	message_counter,F			; increase message counter
	goto	TFT_message_cave_mode		; show cave mode message

check_cavemode_full:
	btfss	backtrack_shutdown			; backtracking shut down already?
	bsf		request_cave_off_turned		; NO  - request to switch cave mode off and to set the dive as turned
	bsf		backtrack_shutdown			; remember shut down as been executed (anyhow)
	btfss	cave_mode					; has the cave mode been switched on again meanwhile?
	bsf		warn_det_cave_shut_down		; NO  - set warning level
	btfsc	cave_mode					; has the cave mode been switched on again meanwhile?
	bsf		attn_det_cave_shut_down		; YES - set attention level
	bra		check_cavemode_mesg			; show message

check_cavemode_almost_full:
	btfss	cave_mode					; cave mode switched on?
	return								; NO  - suppress message
	bsf		attn_det_cave_shut_down		; YES - set an attention
	bra		check_cavemode_mesg			;     - show message

 ENDIF	; _cave_mode


;-----------------------------------------------------------------------------
; Show aGF Reminder
;
remind_agf_in_use:
	incf	message_counter,F			; increase message counter
	goto	TFT_message_agf				; show aGF reminder and return


;-----------------------------------------------------------------------------
; Check better Gas / Diluent Advice
;
check_gas_change:
	bcf		advc_det_change_gas			; clear advice by default
 IFDEF _ccr_pscr
	btfsc	better_dil_available		; is a better diluent available?
	bra		check_gas_change_mesg		; YES - show a gas change advice
 ENDIF
	btfsc	better_gas_available		; is a better gas     available?
	bra		check_gas_change_mesg		; YES - show a gas change advice
	return								; NO  - done

check_gas_change_mesg:
	bsf		advc_det_change_gas			; set advice
	incf	message_counter,F			; increase message counter
	goto	TFT_message_gas_change		; show advice and return


 IFDEF _rx_functions

;-----------------------------------------------------------------------------
; Check SAC and Swap-Tank Advice
;
check_tr_messages:
	bcf		attn_det_sac_rate			; clear SAC attention by default
	bcf		advc_det_switch_tank		; clear switch advice by default
	btfss	count_divetime				; is the dive time counted, i.e. deeper than dive threshold?
	return								; NO  - suppress check
	movff	int_O_SAC_measured+1,WREG	; YES - bank-safe copy of measured SAC rate
	btfss	WREG,int_attention_flag		;     - attention flag set?
	bra		check_tr_messages_chk_swap	;       NO  - continue with checking for swap advice
	btfsc	WREG,int_not_avail_flag		;       SAC rate available?
	bra		check_tr_messages_chk_swap	;       NO  - continue with checking for swap advice
	bsf		attn_det_sac_rate			;       YES - set attention for SAC rate
	movf	active_customview,W			;           - get current custom view
	xorlw	index_pressures_SAC			;           - SAC rate shown?
	bz		check_tr_messages_chk_swap	;             YES - do not show twice, continue with swap advice
	;bra	check_tr_messages_mesg_sac	;             NO  - show SAC message

check_tr_messages_mesg_sac:
	incf	message_counter,F			; increase message counter
	call	TFT_message_sac				; show message for SAC rate
	;bra	check_tr_messages_chk_swap	; continue with switch advice

check_tr_messages_chk_swap:
	movff	char_O_deco_info,WREG		; bank-safe copy of deco info vector
	btfss	WREG,ind_double_switch		; swap tank flag set?
	return								; NO  - done
	;bra	check_tr_messages_mesg_swap	; YES - show swap message

check_tr_messages_mesg_swap:
	bsf		advc_det_switch_tank		; set advice
	incf	message_counter,F			; increase message counter
	goto	TFT_message_switch_tanks	; show message for switching tanks and return


;-----------------------------------------------------------------------------
; Check Transmitter States
;
check_tr_functions:
	; check transmitter 1
	movff	char_I_pressure_stat+0,WREG		; get status of 1st pressure reading
	rcall	check_tr_functions_helper1		; check for transmitter 1 lost
	rcall	check_tr_functions_helper2		; check for transmitter 1 low battery
	movff	int_IO_pressure_value+1,WREG	; get high byte of 1st pressure reading
	rcall	check_tr_functions_helper3		; check for transmitter 1 pressure warning
	rcall	check_tr_functions_helper4		; check for transmitter 1 pressure attention
	; check transmitter 2
	movff	char_I_pressure_stat+1,WREG		; get status of 2nd pressure reading
	rcall	check_tr_functions_helper5		; check for transmitter 2 lost
	rcall	check_tr_functions_helper6		; check for transmitter 2 low battery
	movff	int_IO_pressure_value+3,WREG	; get high byte of 2nd pressure reading
	rcall	check_tr_functions_helper7		; check for transmitter 2 pressure warning
	rcall	check_tr_functions_helper8		; check for transmitter 2 pressure attention

	; results for transmitter
	btfsc	attn_det_xmit1_bat				; do we have a transmitter 1 attention?
	bra		check_tr_functions_xmitter_mesg	; YES - show transmitter message
	btfsc	attn_det_xmit2_bat				; do we have a transmitter 2 attention?
	bra		check_tr_functions_xmitter_mesg	; YES - show transmitter message
check_tr_functions_1:
	btfsc	warn_det_pressure1				; do we have a pressure 1 warning?
	bra		check_tr_functions_pres_mesg	; YES - show pressure message
	btfsc	warn_det_pressure2				; do we have a pressure 2 warning?
	bra		check_tr_functions_pres_mesg	; YES - show pressure message
	btfsc	attn_det_pressure1				; do we have a pressure 1 attention?
	bra		check_tr_functions_pres_mesg	; YES - show pressure message
	btfsc	attn_det_pressure2				; do we have a pressure 2 attention?
	bra		check_tr_functions_pres_mesg	; YES - show pressure message
	return									; done

check_tr_functions_xmitter_mesg:
	incf	message_counter,F				; increase message counter
	call	TFT_message_transmitter			; show transmitter message
	bra		check_tr_functions_1			; continue with pressure messages

check_tr_functions_pres_mesg:
	incf	message_counter,F				; increase message counter
	goto	TFT_message_pressure			; show pressure message and return

check_tr_functions_helper1:
	btfsc	WREG,char_transmitter_lost		; transmitter 1 lost?
	bra		check_tr_functions_helper1a		; YES - show transmitter attention message
	bcf		shown_xmit1_lost				; NO  - clear flag for old message
	return									;     - done
check_tr_functions_helper1a:
	btfsc	shown_xmit1_lost				; is it a new message?
	return									; NO  - do not show the pressure readings custom view again
	bsf		shown_xmit1_lost				; YES - memorize it's an old message now
	rcall	check_tr_functions_show_cv		;     - show custom view

check_tr_functions_helper2:
	btfsc	WREG,char_transmitter_low_bat	; transmitter 1 low battery?
	bra		check_tr_functions_helper2a		; YES - show transmitter attention message
	bcf		shown_xmit1_battery				; NO  - clear flag for old message
	bcf		attn_det_xmit1_bat				;     - clear transmitter 1 attention
	return									;     - done
check_tr_functions_helper2a:
	bsf		attn_det_xmit1_bat				; set transmitter 1 attention
	btfsc	shown_xmit1_battery				; is it a new message?
	return									; NO  - do not show the pressure readings custom view again
	bsf		shown_xmit1_battery				; YES - memorize it's an old message now
	rcall	check_tr_functions_show_cv		;     - show custom view

check_tr_functions_helper3:
	btfsc	WREG,int_warning_flag			; transmitter 1 pressure warning?
	bra		check_tr_functions_helper3a		; YES - show pressure reading message as warning
	bcf		shown_xmit1_pres_warn			; NO  - clear flag for old message
	bcf		warn_det_pressure1				;     - clear pressure 1 warning
	return									;     - done
check_tr_functions_helper3a:
	bsf		warn_det_pressure1				; set pressure 1 warning
	btfsc	shown_xmit1_pres_warn			; is it a new message?
	return									; NO  - do not show the pressure readings custom view again
	bsf		shown_xmit1_pres_warn			; YES - memorize it's an old message now
	bra		check_tr_functions_show_cv		;     - show custom view

check_tr_functions_helper4:
	btfsc	WREG,int_attention_flag			; transmitter 1 pressure attention?
	bra		check_tr_functions_helper4a		; YES - show pressure reading message as attention
	bcf		shown_xmit1_pres_attn			; NO  - clear flag for old message
	bcf		attn_det_pressure1				;     - clear pressure 1 attention
	return									;     - done
check_tr_functions_helper4a
	bsf		attn_det_pressure1				; set pressure 1 attention
	btfsc	shown_xmit1_pres_attn			; is it a new message?
	return									; NO  - do not show the pressure readings custom view again
	bsf		shown_xmit1_pres_attn			; YES - memorize it's an old message now
	bra		check_tr_functions_show_cv		;     - show custom view

check_tr_functions_helper5:
	btfsc	WREG,char_transmitter_lost		; transmitter 2 lost?
	bra		check_tr_functions_helper5a		; YES - show transmitter attention message
	bcf		shown_xmit2_lost				; NO  - clear flag for old lost message
	return									;     - done
check_tr_functions_helper5a:
	btfsc	shown_xmit2_lost				; is it a new message?
	return									; NO  - do not show the pressure readings custom view again
	bsf		shown_xmit2_lost				; YES - memorize it's an old message now
	bra		check_tr_functions_show_cv		;     - show custom view

check_tr_functions_helper6:
	btfsc	WREG,char_transmitter_low_bat	; transmitter 2 low battery?
	bra		check_tr_functions_helper6a		; YES - show transmitter attention message
	bcf		shown_xmit2_battery				; NO  - clear flag for old battery message
	bcf		attn_det_xmit2_bat				;     - clear transmitter 2 attention
	return									;     - done
check_tr_functions_helper6a:
	bsf		attn_det_xmit2_bat				; set transmitter 2 attention
	btfsc	shown_xmit2_battery				; is it a new message?
	return									; NO  - do not show the pressure readings custom view again
	bsf		shown_xmit2_battery				; YES - memorize it's an old message now
	bra		check_tr_functions_show_cv		;     - show custom view

check_tr_functions_helper7:
	btfsc	WREG,int_warning_flag			; transmitter 2 pressure warning?
	bra		check_tr_functions_helper7a		; YES - show pressure reading message as warning
	bcf		shown_xmit2_pres_warn			; NO  - clear flag for old message
	bcf		warn_det_pressure2				;     - clear pressure 2 warning
	return									;     - done
check_tr_functions_helper7a:
	bsf		warn_det_pressure2				; set pressure 2 warning
	btfsc	shown_xmit2_pres_warn			; is it a new message?
	return									; NO  - do not show the pressure readings custom view again
	bsf		shown_xmit2_pres_warn			; YES - memorize it's an old message now
	bra		check_tr_functions_show_cv		;     - show custom view

check_tr_functions_helper8:
	btfsc	WREG,int_attention_flag			; transmitter 2 pressure attention?
	bra		check_tr_functions_helper8a		; YES - show pressure reading message as attention
	bcf		shown_xmit2_pres_attn			; NO  - clear flag for old message
	bcf		attn_det_pressure2				;     - clear pressure 2 attention
	return									;     - done
check_tr_functions_helper8a
	bsf		attn_det_pressure2				; set pressure 2 attention
	btfsc	shown_xmit2_pres_attn			; is it a new message?
	return									; NO  - do not show the pressure readings custom view again
	bsf		shown_xmit2_pres_attn			; YES - memorize it's an old message now
	;bra	check_tr_functions_show_cv		;     - show custom view

check_tr_functions_show_cv:
	btfsc	custom_view_locked				; NO  - custom view locked?
	return									;       YES - do not show now
	movlw	index_pressures_SAC				;       NO  - get  custom view number of pressure readings
	goto	dive_customview_show			;           - show custom view and return

 ENDIF	; _rx_functions


;-----------------------------------------------------------------------------
; Check Gas Needs
;
check_gas_needs:
	bcf		attn_det_gas_needs			; clear attention by default
	bcf		warn_det_gas_needs			; clear warning   by default
	banksel	int_O_gas_need_pres			; switch to bank where int_O_gas_need_pres is stored
	movf	int_O_gas_need_pres+1,W		; get               high byte from pres need of 1st tank
	iorwf	int_O_gas_need_pres+3,W		; inclusive or with high byte from pres need of 2nd tank
	iorwf	int_O_gas_need_pres+5,W		; inclusive or with high byte from pres need of 3rd tank
	iorwf	int_O_gas_need_pres+7,W		; inclusive or with high byte from pres need of 4th tank
	iorwf	int_O_gas_need_pres+9,W		; inclusive or with high byte from pres need of 5th tank
	banksel	common						; back to bank common
	btfsc	WREG,int_invalid_flag		; any invalid flag set?
	bra		check_gas_needs_ok			; YES - no further checking required
	btfsc	WREG,int_warning_flag		; NO  - any gas with pres_need >= pres_fill ?
	bra		check_gas_needs_warn		;       YES - generate a warning
	btfsc	WREG,int_attention_flag		;       NO  - any gas with pres_need >= pres_fill * threshold ?
	bra		check_gas_needs_attn		;             YES - generate an attention
	;bra	check_gas_needs_ok			;             NO  - gas needs ok

check_gas_needs_ok:
	bcf		shown_gas_needs_warn		; re-arm custom view show-up for warning
	bcf		shown_gas_needs_attn		; re-arm custom view show-up for attention
	return								; done

check_gas_needs_warn:
	bsf		warn_det_gas_needs			; set warning
	bcf		shown_gas_needs_attn		; re-arm custom view show-up for attention
	btfsc	shown_gas_needs_warn		; has the custom view been shown before on warning level?
	bra		check_gas_needs_mesg		; YES - do not show the gas needs custom view again
	btfsc	custom_view_locked			; NO  - custom view locked?
	bra		check_gas_needs_mesg		;       YES - do not show it now
	bsf		shown_gas_needs_warn		;       NO  - set custom view as shown now
	bra		check_gas_needs_cv			;           - show gas needs custom view

check_gas_needs_attn:
	bsf		attn_det_gas_needs			; set attention
	bcf		shown_gas_needs_warn		; re-arm custom view show-up for warning
	btfsc	shown_gas_needs_attn		; has the custom view been shown before on attention level?
	bra		check_gas_needs_mesg		; YES - do not show the gas needs custom view again
	btfsc	custom_view_locked			; NO  - custom view locked?
	bra		check_gas_needs_mesg		;       YES - do not show it now
	bsf		shown_gas_needs_attn		;       NO  - set custom view as shown now
	;bra	check_gas_needs_cv			;           - show gas needs custom view

check_gas_needs_cv:
	movlw	index_gas_needs_ascent		; get  custom view number of gas needs
	call	dive_customview_show		; show custom view
	;bra	check_gas_needs_mesg		; show message

check_gas_needs_mesg:
	incf	message_counter,F			; increase message counter
	goto	TFT_message_gas_needs		; show message for gas needs and return


 IFDEF _external_sensor

;-----------------------------------------------------------------------------
; Check external Sensors for Loss and Divergence
;
check_ext_sensors:
	btfsc	warn_det_sensors_lost		; all sensors lost?
	bra		check_ext_sensors_lost_all	; YES - show a warning and return

	btfsc	attn_det_sensor1_lost		; sensor 1 lost?
	rcall	check_ext_sensors_lost_1	; YES - show an attention

	btfsc	attn_det_sensor2_lost		; sensor 2 lost?
	rcall	check_ext_sensors_lost_2	; YES - show an attention

	btfsc	attn_det_sensor3_lost		; sensor 3 lost?
	rcall	check_ext_sensors_lost_3	; YES - show an attention

	btfsc	warn_det_sensors_div		; sensor values divergence?
	bra		check_ext_sensors_diverg	; YES - show a warning and return

	return								; done

check_ext_sensors_lost_all:
	btfsc	shown_sensors_lost			; has the custom view been shown before?
	bra		warn_sensors_lost_mesg		; YES - do not show the sensor custom view again
	btfsc	custom_view_locked			; NO  - custom view locked?
	bra		warn_sensors_lost_mesg		;       YES - do not show it now
	bsf		shown_sensors_lost			;       NO  - set it as shown now
	movlw	index_ppo2_sensors			;           - get  custom view number of sensors
	call	dive_customview_show		;           - show custom view
	;bra	warn_sensors_lost_mesg		;           - show message

warn_sensors_lost_mesg:
	incf	message_counter,F			; increase message counter
	goto	TFT_message_fallback		; show message and return

check_ext_sensors_lost_1:
	btfsc	shown_sensor1_fail			; has the custom view been shown before for sensor 1?
	return								; YES - do not show the sensor custom view again
	btfsc	custom_view_locked			; NO  - custom view locked?
	return								;       YES - do not show it now
	bsf		shown_sensor1_fail			;       NO  - set it as shown now
	bra		check_ext_sensors_show_cv	;           - show sensor custom view

check_ext_sensors_lost_2:
	btfsc	shown_sensor2_fail			; has the custom view been shown before for sensor 2?
	return								; YES - do not show the sensor custom view again
	btfsc	custom_view_locked			; NO  - custom view locked?
	return								;       YES - do not show it now
	bsf		shown_sensor2_fail			;       NO  - set it as shown now
	bra		check_ext_sensors_show_cv	;           - show sensor custom view

check_ext_sensors_lost_3:
	btfsc	shown_sensor3_fail			; has the custom view been shown before for sensor 3?
	return								; YES - do not show the sensor custom view again
	btfsc	custom_view_locked			; NO  - custom view locked?
	return								;       YES - do not show it now
	bsf		shown_sensor3_fail			;       NO  - set it as shown now
	;bra	check_ext_sensors_show_cv	;           - show sensor custom view

check_ext_sensors_show_cv:
	movlw	index_ppo2_sensors			; get  custom view number of sensors
	goto	dive_customview_show		; show custom view and return

check_ext_sensors_diverg:
	btfsc	shown_sensors_diverg			; has the custom view been shown before for divergence?
	bra		check_ext_sensors_diverg_mesg	; YES - do not show the sensor custom view again
	btfsc	custom_view_locked				; NO  - custom view locked?
	bra		check_ext_sensors_diverg_mesg	;       YES - do not show it now
	bsf		shown_sensors_diverg			;       NO  - set it as shown now
	movlw	index_ppo2_sensors				;           - get  custom view number of sensors
	call	dive_customview_show			;           - show custom view
	;bra	check_ext_sensors_diverg_mesg	;           - show message

check_ext_sensors_diverg_mesg:
	incf	message_counter,F			; increase message counter
	goto	TFT_message_divergence		; show message and return

 ENDIF	; _external_sensor


;=============================================================================
dmode5	CODE
;=============================================================================


;-----------------------------------------------------------------------------
; Restart the Deco Engine
;
	global	restart_deco_engine
	global	restart_deco_engine_wo_ceiling
restart_deco_engine:
	banksel	int_O_ceiling								; switch to bank where the shared "_O_" variables are stored
	bsf		int_O_ceiling+1,char_invalid_flag			; invalidate ceiling (int_O_ceiling has its invalid flag on a char's position!)

restart_deco_engine_wo_ceiling:
	banksel	char_O_deco_gas								; switch to bank where the stops table is stored
	bsf		char_O_deco_gas+0,char_invalid_flag			; invalidate deco data (stop table data)
	banksel	int_O_NDL_norm								; switch to bank where the shared "_O_" variables are stored
	bsf		int_O_NDL_norm+1,int_invalid_flag			; invalidate NDL time (normal plan)
	bsf		int_O_TTS_norm+1,int_invalid_flag			; invalidate TTS time (normal plan)
	bsf		int_O_TST_norm+1,int_invalid_flag			; invalidate TST time (normal plan)
	bsf		int_O_CNS_norm+1,int_invalid_flag			; invalidate CNS at end of dive in normal plan

restart_deco_engine_wo_norm:
	banksel	common										; bank to bank common
	bsf		request_restart_engine						; request restart of the deco engine

inval_alternative_plan_data:
	banksel	int_O_NDL_alt								; switch to bank where the shared "_O_" variables are stored
	bsf		int_O_NDL_alt+1,int_invalid_flag			; invalidate NDL time (alternative plan)
	bsf		int_O_TTS_alt+1,int_invalid_flag			; invalidate TTS time (alternative plan)
	bsf		int_O_TST_alt+1,int_invalid_flag			; invalidate TST time (alternative plan)
	bsf		int_O_CNS_alt+1,int_invalid_flag			; invalidate CNS at end of dive in alternative plan
	bsf		int_O_gas_need_pres+1,int_invalid_flag		; invalidate ascent gas needs

 IFDEF _rx_functions
	bsf		int_O_pressure_need+1,int_not_avail_flag	; invalidate pressure needs to reading 1 (TR functions)
	bsf		int_O_pressure_need+3,int_not_avail_flag	; invalidate pressure needs to reading 2 (TR functions)
 ENDIF

	banksel	common										; bank to bank common
	bsf		new_deco_data_avail							; set flag for new NDL and deco data available to have the display updated

	return												; done


;=============================================================================
dmode6	CODE
;=============================================================================


;-----------------------------------------------------------------------------
; Start-up Simulator Mode
;
	global	demo_divemode
demo_divemode:
	call	TFT_ClearScreen					; blank screen

	; leaving menu mode, so have option values in EEPROM up-to-date
	btfsc	option_changed					; do the options need to be stored to EEPROM ?
	call	option_check_and_store_all		; YES - check and store all option values in EEPROM

	; +++ COMMENT OUT FOR TESTING PURPOSE ONLY  !!! +++
	bsf		simulatormode					; restore tissue pressures and CNS value after finishing simulator use
	; +++ DO NOT COMMENT OUT IN OPERATIONAL USE !!! +++

	call	deco_push_tissues_to_vault		; back-up the tissue pressures (C-code)
	banksel	common							; back to bank common

	; set simulated target depth
	movff	char_I_bottom_depth,simulatormode_depth

	; set initial simulated depth (needed to overcome end-of-dive detection)
	banksel	pressure_rel_sim
	MOVLI	simulator_startdepth,pressure_rel_sim
	banksel	common

	; switch ISR pressure calculations to simulator mode
	bcf		quit_simulatormode				; clear flag for fast abort request
	bcf		sensor_override_active			; make sure ISR mode switch confirmation is not older than from now on
	bsf		sensor_override_request			; request ISR to switch to simulator mode
	btfss	sensor_override_active			; has the ISR confirmed switch to simulator mode?
	bra		$-2								; NO - not yet, loop waiting for the ISR to kick in

	; branch into dive mode
	bsf		divemode						; activate  dive mode (to be done after simulator mode is activated)
	goto	diveloop						; start dive mode

;-----------------------------------------------------------------------------

	END
