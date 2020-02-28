;=============================================================================
;
;   File divemode.asm                         combined next generation V3.08.8
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
		xmitter_flags_stat				; pressure transmitter flags for status
		xmitter_flags_mesg				; pressure transmitter flags for messages
		ppO2_min:2						; used in search for best gas/dil: minimum ppO2 required
		ppO2_max_default:2				; used in search for best gas/dil: default  maximum ppO2
		ppO2_max_deco:2					; used in search for best gas/dil: deco     maximum ppO2
	ENDC								; used: 16 byte, remaining: 0 byte ==> FULL


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


; Pressure Transmitter Status
#DEFINE transmitter1_lost				xmitter_flags_stat,0	; =1: transmitter 1 lost               is an old message
#DEFINE transmitter1_battery			xmitter_flags_stat,1	; =1: transmitter 1 battery low        is an old message
#DEFINE transmitter1_pres_warn			xmitter_flags_stat,2	; =1: transmitter 1 pressure warning   is an old message
#DEFINE transmitter1_pres_att			xmitter_flags_stat,3	; =1: transmitter 1 pressure attention is an old message
#DEFINE transmitter2_lost				xmitter_flags_stat,4	; =1: transmitter 2 lost               is an old message
#DEFINE transmitter2_battery			xmitter_flags_stat,5	; =1: transmitter 2 battery low        is an old message
#DEFINE transmitter2_pres_warn			xmitter_flags_stat,6	; =1: transmitter 2 pressure warning   is an old message
#DEFINE transmitter2_pres_att			xmitter_flags_stat,7	; =1: transmitter 2 pressure attention is an old message

; Pressure Transmitter Messages
#DEFINE pres_customview_shown			xmitter_flags_mesg,0	; =1: pressure readings custom view has been shown before
#DEFINE show_transmitter_attention		xmitter_flags_mesg,1	; =1: show transmitter attention
#DEFINE show_pres_warning				xmitter_flags_mesg,2	; =1: show transmitter pressure warning
#DEFINE show_pres_attention				xmitter_flags_mesg,3	; =1: show transmitter pressure attention
;										xmitter_flags_mesg,4	; --- unused
;										xmitter_flags_mesg,5	; --- unused
;										xmitter_flags_mesg,6	; --- unused
;										xmitter_flags_mesg,7	; --- unused

; various Flags
#DEFINE new_deco_data_avail				DM_flags_local,0		; =1: new NDL or deco data available
#DEFINE o2_sensors_agree				DM_flags_local,1		; =1: the ppO2 of all sensors are within the threshold range
#DEFINE update_menu						DM_flags_local,2		; =1: redraw the dive menu
#DEFINE FLAG_SP2_used					DM_flags_local,3		; =1: setpoint 2 has been auto-selected already
#DEFINE FLAG_SP3_used					DM_flags_local,4		; =1: setpoint 3 has been auto-selected already
#DEFINE FLAG_SP4_used					DM_flags_local,5		; =1: setpoint 4 has been auto-selected already
#DEFINE FLAG_SP5_used					DM_flags_local,6		; =1: setpoint 5 has been auto-selected already
;										DM_flags_local,7		; --- unused


dmode	CODE

;=============================================================================

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

	bcf		dive_main_menu				; clear dive main    menu flag
	bcf		dive_options_menu			; clear dive options menu flag

	; reset local flags
	clrf	TFT_output_flags_1			; clear all flags for TFT output phase 1
	clrf	TFT_output_flags_2			; clear all flags for TFT output phase 2
	clrf	TFT_output_flags_3			; clear all flags for TFT output phase 3
	clrf	TFT_output_flags_4			; clear all flags for TFT output phase 4
	clrf	xmitter_flags_stat			; clear all pressure transmitter status  flags
	clrf	xmitter_flags_mesg			; clear all pressure transmitter message flags
	clrf	DM_flags_local				; clear all the various other flags, too

	; configure screen layout (all flags were cleared above)
	TSTOSC	opt_layout					; alternative layout enabled?
	bsf		alt_layout_active			; YES - start with alternative layout

	; configure tissue graphics (all flags were cleared above)
	TSTOSS	opt_tissue_graphics			; shall show: 0= pres+sat, 1= N2+He
	bsf		tissue_graphic_layout		; YES - show press+sat

	TSTOSC	char_I_model				; GF factors enabled?
	bsf		tissue_graphic_gf			; YES - show GF lines


	; boot tasks for all modes
	call	diveloop_boot

	; startup tasks for all modes
;	clrf	CCP1CON						; stop PWM
;	bcf		PORTC,2						; pull PWM output to GND
;	clrf	CCPR1L						; backlight off
	call	TFT_boot					; initialize TFT (includes clear screen)
	call	TFT_show_divemode_mask		; display static dive mode mask
	call	TFT_Display_FadeIn			; dim up the display

	; reload and redraw last custom view
	movff	customview_divemode,active_customview
	bsf		FLAG_TFT_customview_callup

	bcf		divetime_longer_1min		; the dive has just begun
	btfsc	FLAG_apnoe_mode				; in apnea mode?
	bsf		divetime_longer_1min		; YES - force dive to have lasted for longer than 1 minute already
	btfsc	sensor_override_active		; in simulator mode?
	bsf		divetime_longer_1min		; YES - force dive to have lasted for longer than 1 minute already

	bsf		trigger_pres_cur_changed	; flag that the pressures have changed to have all data...
	bsf		trigger_pres_max_changed	; ... written to the display on the first output round

	bsf		trigger_temp_changed		; flag that the temperature has changed to have the temperature ...
										; ... written to the display on the first output round

	bsf		new_deco_data_avail			; flag that new deco engine results are available to have the initial data ...
										; ... written to the display on the first output round

	; clear the resettable average depth
	call	clear_resettable_average_depth

;	; initial caching of new absolute and relative pressure, ISR-safe 2 byte copies
;	SMOVII	pressure_abs,    pressure_abs_cached
;	SMOVII	pressure_rel_cur,pressure_rel_cur_cached

;	; initial transfer of absolute pressure to deco engine
;	MOVII	pressure_abs_cached,int_I_pres_respiration

	btfsc	FLAG_apnoe_mode				; in apnoe mode?
	bra		diveloop_1					; YES - done with initialization
	btfsc	FLAG_gauge_mode				; NO  - in gauge mode?
	bra		diveloop_1					;       YES - done with initialization
	bsf		FLAG_TFT_display_ndl_mask	;       NO  - in deco mode then, display NDL mask
	bsf		FLAG_TFT_active_gas_divemode;           - request initial display of gas and setpoint

diveloop_1:
	btfsc	reset_timebase				; has the ISR confirmed reset of the timebase meanwhile?
	bra		$-2							; NO - not yet, loop waiting for confirmation before entering the dive loop

diveloop_loop:
	; ### the dive loop starts here ###
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

 IFDEF _ccr_pscr
	; adjust auto-setpoint
	btfsc	FLAG_ccr_mode				; in CCR mode?
	call	check_dive_autosp			; YES - check for Auto-SP
 ENDIF

	; check for new max pressure
	btfss	trigger_pres_max_changed	; has the max pressure changed?
	bra		diveloop_loop_4				; NO  - continue with tasks every 1/1 second
	bcf		trigger_pres_max_changed	; YES - clear flag for new max pressure
	bsf		FLAG_TFT_depth_maximum		;     - set   flag for displaying new max depth
	SMOVII	pressure_rel_max,pressure_rel_max_cached ; - cache new max depth

diveloop_loop_4:
	; continue tasks every 1/1 second

 IFDEF _external_sensor
	btfsc	FLAG_ccr_mode				; in CCR mode?
	rcall	calc_deko_divemode_sensor	; YES - do sensor data acquisition if applicable
	btfsc	FLAG_pscr_mode				; in pSCR mode?
	rcall	calc_deko_divemode_sensor	; YES - do sensor data acquisition if applicable
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
	call	show_new_deco_data			; YES - update the display and update the decostop_active flag

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
	rcall	timeout_divemode			; check for timeout condition
	call	check_dive_modes			; test if depth still deeper than threshold

	btfsc	trigger_full_minute			; has next minute begun?
	rcall	update_divemode60			; YES - update clock, etc.

	btfss	FLAG_oc_mode				; are we in OC mode?
	bsf		FLAG_TFT_active_gas_divemode; NO - have the gas and setpoint redrawn on every second to update setpoint display, animate the blinking, etc.

	btfsc	dive_main_menu				; dive mode menu shown?
	bsf		update_menu					; YES - request update

	rcall	TFT_output_4				; do display updates

; tasks every round, every mode
diveloop_loop_11:
	call	test_switches_divemode		; check switches in dive mode
	bra		diveloop_loop_12

	global	diveloop_menu_exit
diveloop_menu_exit:						; jump-in from menu exit
	bsf		FLAG_TFT_temperature		; restore temperature display or resettable dive time (was overwritten by menu)

diveloop_loop_12:
	bsf		FLAG_TFT_active_gas_divemode; redraw gas and setpoint (eventually needed to restore the "Bailout" text)

	btfsc	request_next_custview		; shall show next custom view?
	call	dive_customview_toggle		; YES - show next custom view (and delete this flag)

	btfsc	request_gas_change			; shall change gas?
	call	gas_switch_common			; YES

	btfsc	request_gas_update			; shall update the gases?
	call	gas_update_common			; YES

	btfsc	request_toggle_GF			; shall toggle GF/aGF?
	rcall	divemodemode_togglegf		; YES

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

	bra		diveloop_loop				; loop in dive mode

;--------------------------------------------------------------------------------------------------------

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

;--------------------------------------------------------------------------------------------------------

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


	global	apnoe_calc_maxdepth
apnoe_calc_maxdepth:
	MOVII	apnoe_max_pressure,     sub_a				; get max depth from all dives to far
	MOVII	pressure_rel_max_cached,sub_b				; get max depth of last dive
	call	cmpU16										; sub_a - sub_b = apnoe_max_pressure - pressure_rel_max_cached
	btfss	neg_flag									; last dive deeper than all the others before?
	return												; NO  - done
	MOVII	pressure_rel_max_cached,apnoe_max_pressure	; YES - store new overall max depth
	return												;     - done

	; --------------------------------------------------------------------------------------

	; Manage and invoke the Deco Calculation Engine
	; =============================================
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
	; Schedule	Dive Mode	Bailout	fTTS	Gas Needs	Plan	Deco Mode	Planning Modes
	; ---------------------------------------------------------------------------------------------
	;
	; 1a)		OC			no		 no		(yes)		norm	OC						(gas needs)
	;													alt		--			--
	;
	; 1b)		OC			no		 YES	(yes)		norm	OC			--
	;													alt		OC			fTTS,		(gas needs)
	;
	; 2a)		Loop		no		 no		 no			norm	Loop		--
	;													alt		--			--
	;
	; 2b)		Loop		no		 yes	 no			norm	Loop		--
	;													alt		Loop		fTTS
	;
	; 2c)		Loop		no		(yes)	 YES		norm	Loop		--
	;													alt		OC			gas needs,	(fTTS*)
	;
	; 3)		Loop		YES		 n/a	(yes)		norm	OC			bailout,	(gas needs)
	;													alt		--			--
	; _____________________________________________________________________________________________
	; norm: normal plan, alt: alternative plan, -- none, (): optional, n/a: not applicable
	; * suppressed when in cave mode and dive is turned


callup_deco_engine:

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
	call	deco_calc_hauptroutine		; invoke the deco engine (C-code)
	banksel	common						; back to bank common
;	+++++++++++++++++++++++++++++++++++++

 ifdef _debug_output
	call	TFT_debug_output			; debug output of scheduling performance data
 endif

	; check if new calculation results for normal plan mode are available
	movff	char_O_deco_status,WREG		; get deco status of deco engine
	btfsc	WREG,DECO_COMPLETED_NORM	; new calculation results for normal plan available?
	bsf		new_deco_data_avail			; YES - set flag for new NDL or deco data available

	; done
	return

; -------------------------------------------------------------------------------------------------

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
	return

show_new_deco_data_deco:				; in deco
	btfss	decostop_active				; been in deco mode before?
	bsf		FLAG_TFT_clear_deco_data	; NO - clear old deco data
	btfss	decostop_active				; been in deco mode before?
	bsf		FLAG_TFT_display_deco_mask	; NO - display deco data mask
	bsf		decostop_active				; set flag for being in deco mode
	bsf		FLAG_TFT_display_tts		; display TTS time (display or stop data is managed somewhere else)
	return

;=============================================================================

 IFDEF _ccr_pscr
 IFDEF _external_sensor

	global	calc_deko_divemode_sensor
calc_deko_divemode_sensor:
	; sensor acquisition code
	btfss	s8_digital_avail				 ; do we have a digital S8 interface?
	bra		calc_deko_divemode_sensor_analog ; NO  - check if we have an analog interface
	btfss	trigger_S8_data_update			 ; YES - check if a new data frame was received
	bra		calc_deko_divemode_sensor_common ;       NO  - use old values
	bcf		trigger_S8_data_update			 ;       YES - clear update flag
	call	compute_mvolts_for_all_sensors	 ;           - compute mV values from digital data
	bra		calc_deko_divemode_sensor_common
calc_deko_divemode_sensor_analog:
	btfss	analog_o2_input					; do we have an analog input?
	bra		calc_deko_divemode_sensor_opt	; NO  - check if we have an optical interface
	call	get_analog_inputs				; YES - get the analog voltages and continue with the common part
	bra		calc_deko_divemode_sensor_common
calc_deko_divemode_sensor_opt:
	btfss	optical_input					; do we have an optical input?
	return									; NO  - return (we have no sensors at all: not analog, not S8 and not optical)
	btfss	sensor1_active					; YES - sensor1_ppO2, sensor2_ppO2 and sensor3_ppO2 are already filled in ISR
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
	SMOVII	sensor1_mv,sub_a			; load sensor mV value
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
	; sensor1_ppO2 = sensor1_mv:2 * opt_x_s1:2 / 1000
	SMOVII	sensor1_mv,xA
	MOVII	opt_x_s1,  xB
	rcall	compute_ppo2_helper
	movff	xC+0,sensor1_ppO2			; result in 0.01 bar
	bra		check_sensor_2				; continue with next sensor
check_sensor_1_fail:
	clrf	WREG
	movff	WREG,sensor1_ppO2			; set ppO2 reading to zero
	btfss	use_O2_sensor1				; check if sensor was in use before
	bra		check_sensor_1_fail_1		; NO  - no new news then
	call	check_sensor_custview_helper; YES - show sensors custom view on further conditions met
check_sensor_1_fail_1:
	bcf		use_O2_sensor1				; revoke sensor from usage

check_sensor_2:							; check min_mv of sensor 2
	btfss	sensor2_calibrated_ok		; check if sensor is usable at all
	bra		check_sensor_2_fail			; NO  - handle it as failed
	; check min threshold
	SMOVII	sensor2_mv,sub_a			; load sensor mV value
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
	; sensor2_ppO2 = sensor2_mv:2 * opt_x_s2:2 / 1000
	SMOVII	sensor2_mv,xA
	MOVII	opt_x_s2,  xB
	rcall	compute_ppo2_helper
	movff	xC+0,sensor2_ppO2			; result in 0.01 bar
	bra		check_sensor_3				; continue with next sensor
check_sensor_2_fail:
	clrf	WREG
	movff	WREG,sensor2_ppO2			; set ppO2 reading to zero
	btfss	use_O2_sensor2				; check if sensor was in use before
	bra		check_sensor_2_fail_1		; NO  - no new news then
	call	check_sensor_custview_helper; YES - show sensors custom view on further conditions met
check_sensor_2_fail_1:
	bcf		use_O2_sensor2				; revoke sensor from usage

check_sensor_3:							; check min_mv of sensor 2
	btfss	sensor3_calibrated_ok		; check if sensor is usable at all
	bra		check_sensor_3_fail			; NO  - handle it as failed
	; check min threshold
	SMOVII	sensor3_mv,sub_a			; load sensor mV value
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
	; sensor3_ppO2 = sensor3_mv:2 * opt_x_s1:2 / 1000
	SMOVII	sensor3_mv,xA
	MOVII	opt_x_s3,  xB
	rcall	compute_ppo2_helper
	movff	xC+0,sensor3_ppO2			; result in 0.01 bar
	bra		calc_deko_divemode_sensor_A	; continue with calculating sensor average
check_sensor_3_fail:
	clrf	WREG
	movff	WREG,sensor3_ppO2			; set ppO2 reading to zero
	btfss	use_O2_sensor3				; check if sensor was in use before
	bra		check_sensor_3_fail_1		; NO  - no new news then
	call	check_sensor_custview_helper; YES - show sensors custom view on further conditions met
check_sensor_3_fail_1:
	bcf		use_O2_sensor3				; revoke sensor from usage

calc_deko_divemode_sensor_A:			; calculate sensor average
	btfss	divemode					; in dive mode?
	return								; NO - done here if not in dive mode

	; compute sensor_setpoint = average of all o2_ppo2_sensorX of those sensors that have use_O2_sensorX == true
	; sum up sensor values (in xA:2) and active sensors in (xB:2)
	CLRI	xA
	CLRI	xB
divemode_setup_sensor_1_value:
	btfss	use_O2_sensor1					; sensor 1 active?
	bra		divemode_setup_sensor_2_value	; NO
	movff	sensor1_ppO2,WREG
	addwf	xA+0,F
	movlw	.0
	addwfc	xA+1,F							; add into xA:2
	incf	xB+0,F							; add a sensor
divemode_setup_sensor_2_value:
	btfss	use_O2_sensor2					; sensor 2 active?
	bra		divemode_setup_sensor_3_value	; NO
	movff	sensor2_ppO2,WREG
	addwf	xA+0,F
	movlw	.0
	addwfc	xA+1,F							; add into xA:2
	incf	xB+0,F							; add a sensor
divemode_setup_sensor_3_value:
	btfss	use_O2_sensor3					; sensor 3 active?
	bra		divemode_setup_sensor_mean		; NO
	movff	sensor3_ppO2,WREG
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
	clrf	WREG								; pre-load a zero
	btfsc	FLAG_pscr_mode						; check if we are in pSCR mode
	movff	WREG,char_I_const_ppO2				; YES - write 0 to char_I_const_ppo2,
												;       it will be overwritten if we have a usable sensor reading
	btfsc	bailout_mode						; check if we are in bailout
	bra		calc_deko_divemode_sensor_V			; YES - no sensor data transfer to char_I_const_ppO2 in this case
	movff	opt_ccr_mode,WREG					; NO  - get mode (0: Fixed SP, 1: Sensor, 2: Auto SP)
	sublw	.1									;     - in sensor mode?
	bnz		calc_deko_divemode_sensor_V			;       NO  - not in sensor mode - no transfer of sensor data to char_I_const_ppO2
	tstfsz	xB+0								;       YES - check if we have found at least one usable sensor
	bra		divemode_setup_sensor_mean1			;             YES - we have at least one usable sensor
	bsf		sp_fallback							;             NO  - we have NO usable sensors -> initiate fallback
	btfss	FLAG_ccr_mode						;                 - check if we are in CCR mode
	bra		calc_deko_divemode_sensor_V			;                   NO  - continue with voting logic flags
	movff	opt_setpoint_cbar+0,char_I_const_ppO2 ;                 YES - select fixed setpoint no. 1 for fallback
	bra		calc_deko_divemode_sensor_V			;                       - continue with voting logic flags
	; we have at least one usable sensor with a ppO2 value > 0
divemode_setup_sensor_mean1:
	bcf		sp_fallback							; clear fallback condition
	movff	sensor_setpoint,char_I_const_ppO2	; transfer average sensor value to p2_deco.c code
	; vote sensors
calc_deko_divemode_sensor_V:
	bsf		voting_logic_sensor1
	movff	sensor1_ppO2,lo
	rcall	check_sensor_voting_helper
	tstfsz	WREG						; sensor within range (WREG = 0)?
	bcf		voting_logic_sensor1		; NO - vote out this sensor

	bsf		voting_logic_sensor2
	movff	sensor2_ppO2,lo
	rcall	check_sensor_voting_helper
	tstfsz	WREG						; sensor within range (WREG = 0)?
	bcf		voting_logic_sensor2		; NO - vote out this sensor

	bsf		voting_logic_sensor3
	movff	sensor3_ppO2,lo
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
	btfsc	bailout_mode				; check if we are in bailout
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
	bcf		o2_sensors_agree			;             NO  - issue a warning
	return
	; check sensor 2
check_warn_sensor_2:
	btfss	sensor2_calibrated_ok		; check if sensor has a valid calibration
	bra		check_warn_sensor_3			; NO  - sensor can not cause a warning then
	btfss	use_O2_sensor2				; YES - check if sensor is in use
	bra		check_warn_sensor_3			;       NO  - sensor can not cause a warning then
	btfsc	voting_logic_sensor2		;       YES - check if sensor value is within agreement range
	bra		check_warn_sensor_3			;             YES - continue with next sensor
	bcf		o2_sensors_agree			;             NO  - issue a warning
	return
	; check sensor 3
check_warn_sensor_3:
	btfss	sensor3_calibrated_ok		; check if sensor has a valid calibration
	bra		check_warn_sensor_agree		; NO  - sensor can not cause a warning then
	btfss	use_O2_sensor3				; YES - check if sensor is in use
	bra		check_warn_sensor_agree		;       NO  - sensor can not cause a warning then
	btfsc	voting_logic_sensor3		;       YES - check if sensor value is within agreement range
	bra		check_warn_sensor_agree		;             YES - continue with next sensor
	bcf		o2_sensors_agree			;             NO  - issue a warning
	return
	; no need for a warning
check_warn_sensor_done:
check_warn_sensor_agree:
	bsf		o2_sensors_agree
	return

check_min_threshold:
	MOVLI	min_mv,sub_b				; load minimum mV value
	goto	sub16						; sub_c = sensor_mv - min_mv (and return)

check_max_threshold:
	MOVLI	max_mv,sub_b				; load maximum mV value
	goto	sub16						; sub_c = sensor_mv - max_mv (and return)

compute_ppo2_helper:
	call	mult16x16					; xC:4 = xA:2 * xB:2
	MOVLI	.1000,xB
	call	div32x16					; xC:4 = xC:4 / xB:2 with xA as remainder
	tstfsz	xC+1						; is the ppO2 higher than 2.55 bar?
	setf	xC+0						; YES - set result to 255 aka 2.55 bar
	return

check_sensor_custview_helper:
	btfss	divemode					; check if we are in dive mode
	return								; NO  - not in dive mode, return
	movff	opt_ccr_mode,WREG			; YES - =0: Fixed SP, =1: Sensor, =2: Auto SP
	decfsz	WREG,W						;     - opt_ccr_mode = 1 (sensors)?
	return								;       NO  - not using the sensors in the moment
show_sensors_custview:
	btfsc	custom_view_locked			;       YES - custom view locked?
	return								;             YES - done
	movlw	index_ppo2_sensors			;             NO  - get  custom view number of ppO2 sensors
	goto	dive_customview_show		;                 - draw custom view and return

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

 ENDIF	; _external_sensor
 ENDIF	; _ccr_pscr

;=============================================================================

divemodemode_togglegf:
	bcf		request_toggle_GF			; clear request flag
	goto	restart_deco_engine			; restart the deco engine and return

;=============================================================================

 IFDEF _cave_mode

cavemode_toggle_onoff:
	bcf		request_cave_toggle			; clear request flag
	btg		cave_mode					; toggle the on/off state
	return								; done

cavemode_switch_off_turned:
	bcf		request_cave_off_turned		; clear request flag
	bcf		cave_mode					; switch cave mode off
	bra		cavemode_turndive_turn_exec ; set dive as turned (and return)


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

cavemode_turndive_toggle:
	bcf		request_turn_toggle			; clear request flag
	rcall	cavemode_turndive_check		; check if command is allowed
	tstfsz	WREG						; command allowed?
	return								; NO  - abort
	btfss	dive_turned					; YES - is the dive currently turned?
	bra		cavemode_turndive_turn_exec	;       NO  - turn the dive
	bra		request_turndive_cont_exec	;       YES - continue the dive

cavemode_turndive_turn:
	bcf		request_turn_turn			; clear request flag
	btfss	cave_mode					; cave mode switched on?
	return								; NO  - abort
	btfsc	dive_turned					; YES - is the dive already turned?
	return								;       YES - nothing to do any more
	;bra	cavemode_turndive_turn_exec	;       NO  - turn the dive

cavemode_turndive_turn_exec:
	bsf		dive_turned					; set dive as turned
	call	set_logbook_marker			; set a logbook marker
	goto	write_backtrack_turnpoint	; write a turn-point waypoint (and return)

request_turndive_cont_exec:
	bcf		dive_turned					; set dive         as not turned    any more
	bcf		backtrack_shutdown			; set backtracking as not shut down any more
	call	set_logbook_marker			; set a logbook marker
	goto	resume_backtrack_recording	; append further logging after current waypoint (and return)


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

cavemode_waypoint_set:
	bcf		request_waypoint_set		; clear request flag
	rcall	cavemode_waypoint_set_check	; check if command is allowed to execute
	tstfsz	WREG						; command allowed?
	return								; NO  - no waypoint setting possible, abort
	call	set_logbook_marker			; YES - set a logbook marker
	goto	write_backtrack_waypoint	;     - execute command (and return)


	global	cavemode_waypoint_out_check
cavemode_waypoint_out_check:
	btfss	cave_mode					; cave mode switched on?
	retlw	1							; NO - command not allowed
	btfss	dive_turned					; YES - is the dive turned?
	retlw	1							;       NO  - no stepping back on way in, command not allowed
	btfsc	waypoint_reached_first		;       YES - already at first waypoint?
	retlw	1							;             YES - command not allowed
	retlw	0							;             NO  - command is  allowed

cavemode_waypoint_out:
	bcf		request_waypoint_out		; clear request flag
	rcall	cavemode_waypoint_out_check	; check if command is allowed to execute
	tstfsz	WREG						; command allowed?
	return								; NO  - no further out possible, abort
	goto	backtrack_waypoint_go_out	; YES - execute the command (and return)


	global	cavemode_waypoint_in_check
cavemode_waypoint_in_check:
	btfss	cave_mode					; cave mode switched on?
	retlw	1							; NO - command not allowed
	btfss	dive_turned					; YES - is the dive turned?
	retlw	1							;       NO  - no stepping forward on way in, command not allowed
	btfsc	waypoint_reached_last		;       YES - already at last waypoint?
	retlw	1							;             YES - command not allowed
	retlw	0							;             NO  - command is  allowed

cavemode_waypoint_in:
	bcf		request_waypoint_in			; clear request flag
	rcall	cavemode_waypoint_in_check	; check if command is allowed to execute
	tstfsz	WREG						; command allowed?
	return								; NO  - no further in possible, abort
	goto	backtrack_waypoint_go_in	; YES - execute command (and return)

 ENDIF

;=============================================================================

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


;=============================================================================

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

;=============================================================================

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
	btfss	neg_flag					; below threshold depth?
	bra		safety_stop_reset			; YES - arm safety stop and delete it from display if still shown
	;bra	safety_stop_control_1		; NO  - check if above end threshold

safety_stop_control_1:
	; above "opt_safety_stop_end"?
	movff	opt_safety_stop_end,WREG	; load safety stop end threshold [dm]
	mullw	.10							; convert threshold from [dm] to [cm]
	MOVII	PROD,sub_b					; move threshold in [cm] to sub_b
	call	cmpU16						; sub_a - sub_b
	btfsc	neg_flag					; above or at threshold depth?
	bra		safety_stop_finish			; YES - finish with safety stop
	;bra	safety_stop_control_2		; NO  - check if above start threshold

safety_stop_control_2:
	; above "opt_safety_stop_start"?
	movff	opt_safety_stop_start,WREG	; load safety stop start threshold [dm]
	mullw	.10							; convert threshold from [dm] to [cm]
	MOVII	PROD,sub_b					; move threshold in [cm] to sub_b
	call	cmpU16						; sub_a - sub_b
	btfss	neg_flag					; above or at threshold depth?
	return								; NO  - pause safety stop
	tstfsz	safety_stop_countdown		; YES - safety stop armed?
	bsf		safety_stop_enabled			;       YES - enable safety stop
	return								;       NO  - done


safety_stop_show:
	btfss	safety_stop_enabled			; safety stop enabled?
	return								; NO  - done
	dcfsnz	safety_stop_countdown,F		; YES - decrement remaining stop time, reached zero?
	bra		safety_stop_finish			;       YES - finished with safety stop
	bsf		FLAG_TFT_safety_stop_show	;       NO  - request to show safety stop
	return								;           - done

safety_stop_finish:
	clrf	safety_stop_countdown							; disarm safety stop
	bcf		safety_stop_enabled								; disable safety stop
	bsf		FLAG_TFT_safety_stop_clear						; request to clear safety stop
	return													; done

safety_stop_reset:
	movff	opt_safety_stop_length,safety_stop_countdown	; arm safety stop (load timer)
	incf	safety_stop_countdown,F							; +1 because safety_stop_show does decrement first
	bsf		FLAG_TFT_safety_stop_clear						; request to clear safety stop
	return													; done


;=============================================================================

timeout_menuview:
	btfss	trigger_timeout				; timeout occurred?
	return								; NO  - done
	goto	menuview_toggle_reset		; YES - terminate the pre-menu and return

timeout_divemode_menu:
	btfss	trigger_timeout				; timeout occurred?
	return								; NO  - done
	;bra	timeout_divemode_menu2		; YES - clean up main menu and restore dive data

	global	timeout_divemode_menu2
timeout_divemode_menu2:					; jump-in point from divemenu_tree.asm
	bcf		dive_main_menu				; clear flag for dive mode menu shown
	call	TFT_clear_divemode_menu		; clear menu area

	btfss	custom_view_locked			; was the custom view locked by the menu system?
	bra		timeout_divemode_menu3		; NO  - continue with redrawing the lower display
	bcf		custom_view_locked			; YES - clear flag for custom view locked by menu
	movf	backup_customview,W			;     - get previous custom view into WREG
	cpfseq	active_customview			;     - compare with current custom view, equal?
	call	dive_customview_recall		;       NO - redraw previous custom view

timeout_divemode_menu3:
	bsf		FLAG_TFT_active_gas_divemode; redraw gas/setpoint/diluent
	bsf		FLAG_TFT_temperature		; display temperature (or resettable dive time when in compass view)
	bcf		better_gas_blinking			; stop better gas cue
	bcf		better_dil_blinking			; stop better dil cue

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

timeout_divemode:
	btfsc	dive_main_menu				; main dive menu shown?
	rcall	timeout_divemode_menu		; YES - check the timeout for it

	btfsc	dive_options_menu			; pre-menu shown?
	rcall	timeout_menuview			; YES - check the timeout for it

	btfss	divetime_longer_1min		; does dive already last for longer than one minute?
	return								; NO  - suspend timeout

	btfsc	FLAG_apnoe_mode				; in apnoe mode?
	bra		timeout_divemode_apnoe		; YES - use apnoe timeout

 IFNDEF _DEBUG
	btfsc	sensor_override_active		; in simulator mode?
	bra		timeout_divemode_sim		; YES - use simulator timeout
	;bra	timeout_divemode_dive		; NO  - use normal dive timeout
 ENDIF

timeout_divemode_dive:
	movff	opt_diveTimeout,WREG		; get dive timeout in minutes into WREG
	;bra	timeout_divemode_com_min

timeout_divemode_com_min:
	mullw	.60							; multiply with 60 to convert minutes in WREG to seconds
	MOVII	PRODL,sub_a					; copy resulting seconds to sub_a
timeout_divemode_com_sec:
	MOVII	dive_timeout_timer,sub_b	; copy current timeout timer value to sub_b
	INCI	dive_timeout_timer			; increment timeout timer
	call	cmpU16						; check sub_a - sub_b
	btfsc	neg_flag					; result negative, i.e. timeout?
	bcf		divemode					; YES - terminate dive mode
	return								; done

timeout_divemode_apnoe:
	movlw	apnoe_timeout				; get apnoe timeout in minutes into WREG
	bra		timeout_divemode_com_min	; continue with common part for minutes

timeout_divemode_sim:
	MOVLI	simulator_timeout,sub_a		; get simulator timeout in seconds directly into sub_a
	bra		timeout_divemode_com_sec	; continue with common part for seconds


update_divemode60:						; tasks every full minute
	bcf		trigger_full_minute			; clear flag

	call	get_battery_voltage			; get battery voltage
	btfsc	battery_low_condition		; battery low condition detected?
	rcall	set_powersafe				; YES - record an alarm and reduce display brightness

	; max allowed runtime in simulator is 254 minutes in
	; order for the tissue calculation catch-up to work!

	btfss	sensor_override_active		; in simulator mode?
	return								; NO  - done
	movlw	simulator_timeout_normal	; YES - set simulation timeout
 IFDEF _cave_mode
	TSTOSC	opt_cave_mode				;     - cave mode switched on?
	movlw	simulator_timeout_cave		;       YES - update simulation timeout
 ENDIF
	cpfsgt	counted_divetime_mins+0		;     - timeout?
	return								;       NO  - done
 IFDEF _DEBUG
	return								;       YES - but we do not care in debug mode...
 ELSE
	bra		divemode_option_sim_quit	;       YES - set depth to 0 m and return
 ENDIF

;=============================================================================

 IFDEF _cave_mode

; ** jump-in functions **

write_backtrack_deltatime:
	rcall	setup_backtrack_index				; setup writing position
	bra		write_backtrack_datum_deltatime		; store the current delta time (and return)

write_backtrack_1min_depth:
	rcall	setup_backtrack_index				; setup writing position
	rcall	write_backtrack_datum_depth			; store depth
	rcall	write_backtrack_datum_zerotime		; reset the time elapsed since last depth recording and store it
	bra		write_backtrack_datum_check			; store new writing position, check remaining storage capacity ()and return)

write_backtrack_waypoint:
	rcall	setup_backtrack_index				; setup writing position
	rcall	write_backtrack_datum_deltatime		; store the time elapsed since last depth recording
	movf	POSTINC1,W							; dummy read to increment the writing position index
	rcall	write_backtrack_datum_depth			; store depth
	rcall	write_backtrack_datum_gas			; store gas availability vector
	rcall	write_backtrack_datum_waypoint		; store waypoint number
	rcall	write_backtrack_datum_zerotime		; reset the time elapsed since last depth recording and store it
	bra		write_backtrack_datum_check			; store new writing position, check remaining storage capacity (and return)

write_backtrack_turnpoint:
	rcall	write_backtrack_waypoint			; write a waypoint (see above)
	movf	POSTDEC1,W							; dummy read to decrement the position index to the waypoint number datum
	movff	FSR1L,char_I_backtrack_index		; store updated writing position
	movff	backtrack_waypoint_num,backtrack_waypoint_turn; memorize this waypoint as turn point
	return										; done

resume_backtrack_recording:
	clrf	backtrack_waypoint_turn				; clear turn point reference
	bsf		waypoint_reached_last				; declare to be at last waypoint now
	rcall	setup_backtrack_index				; setup index position
	movf	POSTINC1,W							; dummy read to increment the position index to the delta time datum
	rcall	write_backtrack_datum_zerotime		; reset the time elapsed since last depth recording and store it
	bra		write_backtrack_datum_check			; store new writing position, check remaining storage capacity (and return)

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


; ** helper functions **

setup_backtrack_index:
	lfsr	FSR1,char_I_backtrack_storage		; load   FSR1 with base address of the backtracking storage
	movff	char_I_backtrack_index,FSR1L		; adjust FSR1 to the current index position
	return

write_backtrack_datum_zerotime:
	clrf	backtrack_deltatime					; reset the time elapsed since last depth recording
write_backtrack_datum_deltatime:
	movf	backtrack_deltatime,W				; get   the time elapsed since last depth recording
	bsf		WREG,7								; add   the time marker (bit 7 set) to the time stored in WREG
	movwf	INDF1								; write the time and keep the writing position index pointing on it
	return										; done

write_backtrack_datum_depth:
	movf	depth_meter,W						; get current depth in meters into WREG
	btfsc	WREG,7								; current depth < 128 m ?
	movlw	.127								; NO - clip depth to 127 meters
	movwf	POSTINC1							; write the depth entry and increment the writing position index
	return										; done

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

write_backtrack_datum_waypoint:
	incf	backtrack_waypoint_num,F			; increment the waypoint number
	movf	backtrack_waypoint_num,W			; copy waypoint number to WREG
	iorlw	b'11100000'							; add the waypoint marker (bit 7-5 set) to the number stored in WREG
	movwf	POSTINC1							; write the waypoint datum and increment the writing position index
	movlw	.2									; load a 2 into WREG
	cpfslt	backtrack_waypoint_num				; new waypoint number >= 2 ?
	bcf		waypoint_reached_first				; YES - not at first waypoint any more
	return										; done

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

;=============================================================================

	global	set_dive_modes
set_dive_modes:
	SMOVII	pressure_rel_cur,sub_a		; ISR-safe 2 byte copy of current relative pressure to sub_a
	bra		set_dive_modes_1
check_dive_modes:
	MOVII	pressure_rel_cur_cached,sub_a; copy cached relative pressure to sub_a
set_dive_modes_1:
	btfss	high_altitude_mode			; in high altitude mode?
	bra		set_dive_modes_norm			; NO  - use normal start-dive threshold
	btfsc	divetime_longer_1min		; YES - dive lasted longer than one minute?
	bra		set_dive_modes_norm			;       YES - this is a real dive -> use normal start-dive threshold
	;bra	set_dive_modes_high			;       NO  - use hight-altitude start-dive threshold

	; high altitude start/end dive thresholds
set_dive_modes_high:
	btfss	count_divetime				; dive time counting, i.e. already in the dive?
	bra		set_dive_modes_high_start	; NO  - select start threshold
	;bra	set_dive_modes_high_end		; YES - select end   threshold

set_dive_modes_high_end:
	MOVLI	dive_threshold_high_alt_end,sub_b
	bra		set_dive_modes_comm

set_dive_modes_high_start:
	MOVLI	dive_threshold_high_alt_start,sub_b
	bra		set_dive_modes_comm

	; normal altitude start/end dive thresholds
set_dive_modes_norm:
	btfss	count_divetime				; dive time counting, i.e. already in the dive?
	bra		set_dive_modes_norm_start	; NO  - select start threshold
	;bra	set_dive_modes_norm_end		; YES - select end   threshold

set_dive_modes_norm_end:
	MOVLI	dive_threshold_norm_alt_end,sub_b
	bra		set_dive_modes_comm

set_dive_modes_norm_start
	MOVLI	dive_threshold_norm_alt_start,sub_b
	;bra	set_dive_modes_comm

set_dive_modes_comm:
	call	cmpU16						; sub_a - sub_b = pressure_rel_cur - start-dive threshold
	btfsc	neg_flag					; pressure_rel_cur > dive_threshold, i.e. deeper than threshold?
	bra		set_dive_modes_shallow		; NO  - shallower than threshold
	btfsc	divetime_longer_1min		; YES - dive lasted longer than one minute?
	CLRI	dive_timeout_timer			;       YES - reset timeout counter
	bsf		divemode					;     - set dive mode flag
	bsf		count_divetime				;     - count dive time
	return								;     - done
set_dive_modes_shallow:
	bcf		count_divetime				; NO  - stop counting dive time
	btfss	divetime_longer_1min		;     - dive lasted longer than one minute?
	bcf		divemode					;       NO  - quit dive mode as this was no real dive
	return								;       done


set_powersafe:
	movlw	d'7'						; set type of alarm = battery low
	movwf	alarm_type					; copy to alarm register
	bsf		event_occured				; set event flag
	movlw	.0							; coding of brightness level ECO
	movff	WREG,opt_brightness			; set brightness to ECO
	return								; done


clear_resettable_average_depth:
	; prime the resettable average depth with 0
	CLRI	pressure_rel_avg_trip
	bra		reset_resettable_average_depth1

reset_resettable_average_depth:
	; clear reset-average request
	bcf		request_reset_avg

	; prime the resettable average depth with the current relative pressure (depth)
	MOVII	pressure_rel_cur_cached,pressure_rel_avg_trip

reset_resettable_average_depth1:
	; clear the resettable depth accumulator
	clrf	pressure_rel_accu_trip+0
	clrf	pressure_rel_accu_trip+1
	clrf	pressure_rel_accu_trip+2
	clrf	pressure_rel_accu_trip+3

	; clear the resettable time accumulator
	CLRI	divesecs_avg_trip
	return


calc_average_depth:
	; 1. compute pressure_rel_cur_cached x 2, because this routine is called every 2nd second only

	; copy current rel pressure to xB
	MOVII	pressure_rel_cur_cached,xB

	; multiply rel pressure x 2 (via shift left)
	bcf		STATUS,C
	rlcf	xB+0,F
	rlcf	xB+1,F

	; 2a add (pressure_rel_cur_cached x 2) to the resettable depth accumulator
	;    will work up to 9999 mbar * 60 * 60 * 24 = 863913600 mbar (24h @ 90 m depth)
	movf	xB+0,W
	addwf	pressure_rel_accu_trip+0,F
	movf	xB+1,W
	addwfc	pressure_rel_accu_trip+1,F
	movlw	.0
	addwfc	pressure_rel_accu_trip+2,F
	addwfc	pressure_rel_accu_trip+3,F

	; 2b add (pressure_rel_cur_cached x 2) to the total depth accumulator
	;    will work up to 9999 mbar * 60 * 60 * 24 = 863913600 mbar (24h @ 90 m depth)
	movf	xB+0,W
	addwf	pressure_rel_accu_total+0,F
	movf	xB+1,W
	addwfc	pressure_rel_accu_total+1,F
	movlw	.0
	addwfc	pressure_rel_accu_total+2,F
	addwfc	pressure_rel_accu_total+3,F

	; 3a compute the resettable average depth

	; get the accumulated depth
	movff	pressure_rel_accu_trip+0,xC+0
	movff	pressure_rel_accu_trip+1,xC+1
	movff	pressure_rel_accu_trip+2,xC+2
	movff	pressure_rel_accu_trip+3,xC+3

	; get the accumulated time
	MOVII	divesecs_avg_trip,xB

	; divide accumulated depth by accumulated time
	call	div32x16						; xC:4 / xB:2 = xC+3:xC+2 with xC+1:xC+0 as remainder

	; store result
	MOVII	xC,pressure_rel_avg_trip		; resettable average depth
	btfss	count_divetime					; is dive time counted?
	return									; NO (e.g. too shallow)

	; 3b compute the dive total average depth

	; get accumulated depth
	movff	pressure_rel_accu_total+0,xC+0
	movff	pressure_rel_accu_total+1,xC+1
	movff	pressure_rel_accu_total+2,xC+2
	movff	pressure_rel_accu_total+3,xC+3

	; get accumulated time
	MOVII	divesecs_avg_total,xB

	; divide accumulated depth by accumulated time
	call	div32x16						; xC:4 = xC:4 / xB:2 with xA as remainder

	; store result
	MOVII	xC,pressure_rel_avg_total		; total dive average depth

	btfsc	request_reset_avg				; shall reset the resettable average depth?
	rcall	reset_resettable_average_depth	; YES - reset the resettable average depth

	TSTOSC	opt_2ndDepthDisp				; drawing average depth instead of max depth?
	bsf		FLAG_TFT_depth_maximum			; YES - flag to update display

	btfsc	FLAG_gauge_mode					; in gauge mode?
	bsf		FLAG_TFT_depth_maximum			; YES - flag to update display (needed for alternative layout)

	return									; done


test_switches_divemode:						; checks switches in dive mode, called every second
	btfsc	dive_main_menu					; dive mode menu shown?
	bra		test_switches_divemode_menu		; YES - use menu processor
	btfsc	switch_left						; NO  - left button pressed?
	goto	menuview_toggle					;       YES - menu or simulator tasks; and return...
	btfss	switch_right					;       NO  - right button pressed?
	return									;             NO  - done
	bcf		switch_right					;             YES - clear button event
	tstfsz	active_premenu					;                 - any pre-menu task selected?
	bra		test_switches_divemode1			;                   YES - do option or menu tasks
	bsf		request_next_custview			;                   NO  - request next custom view
	return									;                       - done

test_switches_divemode_menu:
	btfsc	switch_left						; left button pressed?
	bra		test_switches_divemode_menu2	; YES - move cursor
	btfsc	switch_right					; NO  - right button pressed?
	bra		test_switches_divemode_menu3	;       YES - enter sub-menu or do something
	btfss	update_menu						;       NO  - shall update the menu?
	return									;             NO  - done
	bcf		update_menu						;             YES - clear request
	goto	menu_draw_lines_divemode		;                 - redraw the menu (to update color coding) and return

test_switches_divemode_menu1:
	clrf	menu_pos_cur
test_switches_divemode_menu2:
	bcf		switch_left
	incf	menu_pos_cur,F
	incf	menu_pos_max,W					; menu_pos_max + 1 -> WREG
	cpfslt	menu_pos_cur					; > menu_pos_max ?
	bra		test_switches_divemode_menu1	; YES - set to 1
	call	TFT_show_menu_cursor_divemode	; update the cursor
	movlw	divemode_timeout_mainmenu		; get timeout for main menu
	call	reset_timeout_time				; reset timeout
	return

test_switches_divemode_menu3:				; enter sub-menu or do something
	bcf		switch_right
;	decf	menu_pos_cur,F					; menu_processor needs 0-5...
	goto	do_line_menu					; Warning! trashes STKPTR and returns to diveloop_menu_exit

test_switches_divemode1:
	movlw	divemode_timeout_premenu	; get timeout for pre-menu
	call	reset_timeout_time			; reset timeout
	movff	active_premenu,WREG			; get number of active pre-menu
	dcfsnz	WREG,F
	bra		divemode_option_gaschange	;  1: switch to the the "better gas" / "better diluent"
	dcfsnz	WREG,F
	bra		divemode_option_divemenu	;  2: enter dive mode menu
	dcfsnz	WREG,F
 IFDEF _cave_mode
	bra		divemode_option_cavemenu	;  3: enter cave mode menu
 ELSE
	return								;  3: (no cave mode compiled in)
 ENDIF
	dcfsnz	WREG,F
	bra		divemode_option_sim_quit	;  4: simulation - quit
	dcfsnz	WREG,F
	bra		divemode_option_sim_down	;  5: simulation - descent
	dcfsnz	WREG,F
	bra		divemode_option_sim_up		;  6: simulation - ascend
	dcfsnz	WREG,F
	bra		divemode_option_sim_time	;  7: simulation - +5 min
	dcfsnz	WREG,F
	bra		divemode_option_apnoe_quit	;  8: apnoe - quit
	dcfsnz	WREG,F
	bra		divemode_option_gauge_reset	;  9: gauge - reset stopwatch and avg depth
	dcfsnz	WREG,F
 IFDEF _compass
	bra		divemode_option_course		; 10: store heading
 ELSE
	return								; 10: (no compass compiled in)
 ENDIF
	dcfsnz	WREG,F
	bra		divemode_option_layout		; 11: switch layout
	return


gas_switch_common:
	bcf		request_gas_change			; clear request flag
 IFDEF _ccr_pscr
	btfss	request_back_to_loop		; is a switchback from OC bailout to loop requested?
	bra		gas_switched_common0		; NO  - continue with checking if selected gas is valid
	bcf		request_back_to_loop		; YES - clear flag
	movff	active_dil,menu_pos_cur		;     - reload last diluent
	bra		gas_switched_common1		;     - continue with common part
 ENDIF
gas_switched_common0:
	tstfsz	menu_pos_cur				; menu_pos_cur = 0 ?
	bra		gas_switched_common1		; NO  - valid gas
	return								; YES - something went wrong, invalid gas, abort
gas_switched_common1:
	movf	menu_pos_cur,W				; get selected gas into WREG (1-5)
 IFDEF _ccr_pscr
	btfsc	FLAG_oc_mode				; in OC mode?
	bra		gas_switched_common_OC		; YES
	btfsc	bailout_mode				; in bailout?
	bra		gas_switched_common_OC		; YES
gas_switched_common_loop:				; NO to both - must be loop mode then
	rcall	setup_dil_registers			; set up real tissues  with WREG = diluent 1-6
	rcall	deco_setup_cc_diluents		; set up deco planning with WREG = diluent 1-6
	bra		gas_switched_common3		; continue with common part
 ENDIF	; _ccr_pscr
gas_switched_common_OC:
	rcall	setup_gas_registers			; set up real tissues  with WREG = gas 1-6
	rcall	deco_setup_oc_gases			; set up deco planning with WREG = gas 1-6
	;bra	gas_switched_common3		; continue with common part
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

; Code to pass all parameters to the C code

	global	get_first_gas_to_WREG
get_first_gas_to_WREG:					; gets first gas (1-5) into WREG
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

;=============================================================================

 IFDEF _ccr_pscr

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

 ENDIF

;=============================================================================

	global	deco_setup_oc_gases
deco_setup_oc_gases:					; with currently breathed gas in WREG (1-5 or 6)
	movff	char_O_deco_status,lo		; working copy of char_O_deco_status in bank common
deco_setup_oc_gases_pre:				; entry point with lo preloaded
	movff	WREG,char_I_current_gas_num	; set gas to start with when doing the deco calculations
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
	lfsr	FSR2,char_I_deco_O2_ratio	; load FSR2 with base address of char_I_deco_O2_ratio
										; FSR2 will step through all char_I_deco_... vars
	lfsr	FSR1,opt_gas_O2_ratio		; load FSR1 with base address of opt_gas_O2_ratio
	rcall	deco_setup_copy				; copy all OC O2 ratios
	lfsr	FSR1,opt_gas_He_ratio		; load FSR1 with base address of opt_gas_He_ratio
	rcall	deco_setup_copy				; copy all OC He ratios
	lfsr	FSR1,opt_gas_type			; load FSR1 with base address of opt_gas_type
	rcall	deco_setup_copy				; copy all gas types
	lfsr	FSR1,opt_gas_change			; load FSR1 with base address of opt_gas_change
	rcall	deco_setup_copy				; copy all gas change depths
										; switch deco engine to oc mode:
	bcf		lo,DECO_MODE_PSCR_FLAG		; - clear the pSCR-mode flag (may not be set, but never mind)
	bcf		lo,DECO_MODE_LOOP_FLAG		; - clear the loop/CCR-mode flag
	movff	lo,char_O_deco_status		; - bank safe write-back of char_O_deco_status
	return								; done

;=============================================================================

 IFDEF _ccr_pscr

	global	deco_setup_cc_diluents
deco_setup_cc_diluents:					; with currently breathed diluent in WREG (1-5 or 6)
	movff	char_O_deco_status,lo		; working copy of char_O_deco_status in bank common
deco_setup_cc_diluents_pre:				; entry point with lo preloaded
	btfsc	bailout_mode				; check if in bailout condition       | --------------- FOR SAFETY ONLY --------------
	bra		deco_setup_oc_gases_pre		; YES - revert to setting up OC gases | This branch should never happen to be taken...
	movff	WREG,char_I_current_gas_num	; NO  - set diluent to start with when doing the deco calculations
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
	lfsr	FSR2,char_I_deco_O2_ratio	; load FSR2 with base address of char_I_deco_O2_ratio.
										; FSR2 will step through all char_I_deco_... vars.
	lfsr	FSR1,opt_dil_O2_ratio		; load FSR1 with base address of opt_dil_O2_ratio
	rcall	deco_setup_copy				; copy all dil O2 ratios
	lfsr	FSR1,opt_dil_He_ratio		; load FSR1 with base address of opt_dil_He_ratio
	rcall	deco_setup_copy				; copy all dil He ratios
	lfsr	FSR1,opt_dil_type			; load FSR1 with base address of opt_dil_type
	rcall	deco_setup_copy				; copy all dil types
	lfsr	FSR1,opt_dil_change			; load FSR1 with base address of opt_dil_change
	rcall	deco_setup_copy				; copy all dil change depths
										; switch to CCR / pSCR mode:
	bsf		lo,DECO_MODE_LOOP_FLAG		; - loop flag is set in both, CCR and pSCR mode
	bcf		lo,DECO_MODE_PSCR_FLAG		; - clear pSCR mode flag by default
	btfsc	FLAG_pscr_mode				; - check if we are in pSCR mode
	bsf		lo,DECO_MODE_PSCR_FLAG		;   YES - set additional flag for pSCR mode
	movff	lo,char_O_deco_status		; - bank safe write-back of char_O_deco_status
	return								; done

 ENDIF

;=============================================================================

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
 IFDEF _helium
	movff	gas6_He_ratio,char_I_He_ratio ; copy gas6 H2 ratio to deco engine
 ENDIF
	movlw	.3							; declare gas6 as a deco gas
	movff	WREG,char_I_current_gas_type; copy gas type to deco engine
	movff	depth_meter,char_I_gas6_depth;set current depth as change depth
	bra		setup_gas_registers_com		; continue with common part
setup_gas_registers_15:
	lfsr	FSR1,opt_gas_O2_ratio		; load base address of gas data
	decf	active_gas,W				; set index to O2 ratio of current gas (1-5 -> 0-4)
	movff	PLUSW1,char_I_O2_ratio		; copy         O2 ratio to deco engine
	addlw	.10							; advance index from O2 ratio to He ratio
 IFDEF _helium
	movff	PLUSW1,char_I_He_ratio		; copy         He ratio to deco engine
 ENDIF
	addlw	.10							; advance index from He ratio to gas type
	movff	PLUSW1,char_I_current_gas_type ; copy gas type (0=Disabled, 1=First, 2=Travel, 3=Deco)
setup_gas_registers_com:
	movff	char_O_main_status,lo		; working copy of char_O_main_status in bank common
	bcf		lo,DECO_MODE_PSCR_FLAG		; clear the pSCR-mode flag (if applicable)
	bcf		lo,DECO_MODE_LOOP_FLAG		; clear the loop/CCR-mode flag
	movff	lo,char_O_main_status		; bank safe write-back of char_O_main_status
	movf	active_gas,W				; reload WREG with gas 1-5 or 6 (important!)
	return

;=============================================================================

 IFDEF _ccr_pscr

	global	setup_dil_registers
setup_dil_registers:					; with currently breathed gas in WREG (1-5 or 6)
	btfsc	bailout_mode				; check if in bailout condition                      | --------------- FOR SAFETY ONLY --------------
	bra		setup_gas_registers			; revert to setting up OC gases in bailout condition | This branch should never happen to be taken...
	movwf	active_dil					; set as current diluent
	movlw	.6
	cpfseq	active_dil					; diluent = gas6 ?
	bra		setup_dil_registers_15		; NO - load diluent 1-5
	movff	gas6_O2_ratio,char_I_O2_ratio ; copy gas6 O2 ratio to deco engine
 IFDEF _helium
	movff	gas6_He_ratio,char_I_He_ratio ; copy gas6 H2 ratio to deco engine
 ENDIF
	movlw	.2							; declare gas6 as a normal diluent
	movff	WREG,char_I_current_gas_type; copy gas type to deco engine
	movff	depth_meter,char_I_gas6_depth;set current depth as change depth
	bra		setup_dil_registers_com		; continue with common part
setup_dil_registers_15:
	lfsr	FSR1,opt_dil_O2_ratio		; load base address of diluent data
	decf	active_dil,W				; set index to O2 ratio of current diluent (1-5 -> 0-4)
	movff	PLUSW1,char_I_O2_ratio		; copy         O2 ratio to deco engine
	addlw	.10							; advance index from O2 ratio to He ratio
 IFDEF _helium
	movff	PLUSW1,char_I_He_ratio		; copy         He ratio to deco engine
 ENDIF
	addlw	.10							; advance index from He ratio to diluent type
	movff	PLUSW1,char_I_current_gas_type ; copy diluent type (0=Disabled, 1=First, 2=Normal)
setup_dil_registers_com:
	movff	char_O_main_status,lo		; working copy of char_O_main_status in bank common
	bsf		lo,DECO_MODE_LOOP_FLAG		; loop flag is set in both, CCR and pSCR mode
	bcf		lo,DECO_MODE_PSCR_FLAG		; clear pSCR mode flag by default
	btfsc	FLAG_pscr_mode				; check if we are in pSCR mode
	bsf		lo,DECO_MODE_PSCR_FLAG		; YES - set additional flag for pSCR mode
	movff	lo,char_O_main_status		; bank safe write-back of char_O_main_status
	movf	active_dil,W				; reload WREG with diluent 1-5 or 6 (important!)
	return

 ENDIF

;=============================================================================

divemode_option_gaschange:				; switch to the "better gas" / "better diluent"
 IFDEF _ccr_pscr
	btfsc	FLAG_oc_mode				; in OC mode?
	bra		divemode_option_gaschange_oc; YES
	btfsc	bailout_mode				; in bailout?
	bra		divemode_option_gaschange_oc; YES
divemode_option_gaschange_loop:			; in CCR/pSCR mode and not in bailout
	movff	best_dil_number,menu_pos_cur; NO  - select best diluent
	bcf		better_dil_available		;     - clear flag immediately
	bra		divemode_option_gaschange3	;     - continue with common part
 ENDIF
divemode_option_gaschange_oc:			; in OC or bailout
	movff	best_gas_number,menu_pos_cur; select best gas
	bcf		better_gas_available		; clear flag immediately
divemode_option_gaschange3				; common part
	bsf		request_gas_change			; request a gas/diluent change
	goto	menuview_toggle_reset		; terminate the pre-menu (and return)

divemode_option_divemenu:				; start/setup dive mode menu
	btfss	divemode					; in dive mode?
	goto	menuview_toggle_reset		; NO  - block menu, terminate the pre-menu
	call	TFT_clear_divemode_menu		; YES - clear menu area
	bcf		dive_options_menu			;     - set dive options menu as not shown anymore
	goto	do_main_divemenu			;     - hand over to menu processor

 IFDEF _cave_mode
divemode_option_cavemenu:				; start/setup cave mode menu
	btfss	divemode					; in dive mode?
	goto	menuview_toggle_reset		; NO  - block menu, terminate the pre-menu
	call	TFT_clear_divemode_menu		; YES - clear menu area
	bcf		dive_options_menu			;     - set dive options menu as not shown anymore
	goto	do_main_cavemenu			;     - hand over to menu processor
 ENDIF

	global	divemode_option_divemenu_return
divemode_option_divemenu_return:		; return point for menu processor
	call	TFT_show_menu_cursor_divemode ; show the cursor
	clrf	active_premenu				; set pre-menu    is not shown any more
	bcf		safety_stop_active			; set safety stop is not shown any more
	bsf		dive_main_menu				; set main menu   is     shown now
	movlw	divemode_timeout_mainmenu	; get timeout for main menu
	call	reset_timeout_time			; reload timeout
	goto	diveloop_menu_exit			; go back to dive loop (menu processor resets STKPTR!)

divemode_option_sim_quit:				; quit simulation mode
	clrf	simulatormode_depth			; set target depth to zero
	bsf		quit_simulatormode			; request ISR to end simulator mode
	call	menuview_toggle_reset		; terminate the pre-menu
	btfsc	FLAG_apnoe_mode				; in apnoe mode?
	bcf		divemode					; YES - force end of dive mode
	return								; done

divemode_option_sim_down:				; plus 1 meter
	movlw	ostc_depth_max-1			; load depth limit into WREG
	cpfsgt	simulatormode_depth			; simulated depth <= limit ?
	incf	simulatormode_depth,F		; YES - increment simulated depth
	return								; done

divemode_option_sim_up:					; minus 1 meter
	tstfsz	simulatormode_depth			; simulated depth > 0 ?
	decf	simulatormode_depth,F		; YES - decrement simulated depth
	return								; done

divemode_option_sim_time:
	; check for pending +5' request on deco engine
	movff	char_I_sim_advance_time,WREG; get mailbox content
	tstfsz	WREG						; mailbox clear (=0) ?
	return								; NO - still having a pending +5' request, refuse new request

	; advance tissues pressures and deco obligation by 5 minutes
	movlw	.5							; + 5 minutes
	movff	WREG,char_I_sim_advance_time; copy to mailbox
	call	restart_deco_engine			; condition deco engine to execute the +5 minutes

	; stop dive time incrementing in ISR
	bcf		count_divetime

	; add 5 minutes to counted_divetime_mins
	ADDLI	.5,counted_divetime_mins

	; add 5 minutes (300 seconds) to total_divetime_secs
	ADDLI	.300,total_divetime_secs

	; continue dive time incrementing in ISR
	bsf		count_divetime

	; add 5 minutes (300 seconds) to resettable time accumulator
	ADDLI	.300,divesecs_avg_trip

	; add 5 minutes (300 seconds) to total time accumulator
	ADDLI	.300,divesecs_avg_total

	; calculate 300 x depth in mbar (300 = 5 min * 60 sec/min)
	MOVII	pressure_rel_cur_cached,xB
	MOVLI	.300,xA
	call	mult16x16					; xC = xA * xB

	; add to the resettable depth accumulator
	movf	xC+0,W
	addwf	pressure_rel_accu_trip+0,F
	movf	xC+1,W
	addwfc	pressure_rel_accu_trip+1,F
	movf	xC+2,W
	addwfc	pressure_rel_accu_trip+2,F
	movf	xC+3,W
	addwfc	pressure_rel_accu_trip+3,F

	; add to the total depth accumulator
	movf	xC+0,W
	addwf	pressure_rel_accu_total+0,F
	movf	xC+1,W
	addwfc	pressure_rel_accu_total+1,F
	movf	xC+2,W
	addwfc	pressure_rel_accu_total+2,F
	movf	xC+3,W
	addwfc	pressure_rel_accu_total+3,F

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
	;bra	divemode_option_sim_time_exit	; finish backtracking depth recording
 ENDIF	; _cave_mode

divemode_option_sim_time_exit:
;	goto	menuview_toggle_reset		; terminate the pre-menu and return
	return								; just return, leaving option avail for repeated selection

divemode_option_apnoe_quit:				; quit apnoe mode (available while at the surface only)
	btfsc	sensor_override_active		; in simulator mode?
	bra		divemode_option_sim_quit	; YES - use simulator quit procedure
	bcf		divemode					; NO  - force end of dive mode
	return								;     - done

divemode_option_gauge_reset:
	bsf		request_reset_avg			; request reset of average depth
	goto	menuview_toggle_reset		; terminate pre-menu and return

 IFDEF _compass
divemode_option_course:
	; store heading for compass view
	MOVII	compass_heading_shown,compass_bearing
	bsf		compass_bearing_set			; set flag to show heading
	goto	menuview_toggle_reset		; terminate the pre-menu and return
 ENDIF

divemode_option_layout:						; switch layout
	call	menuview_toggle_reset		; terminate the pre-menu
	call	TFT_ClearScreen				; clear the whole screen
	btg		alt_layout_active			; toggle layout

	bcf		depth_warn_att_last			; set warning or attention on the depth   not shown
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
	btfsc	sp_fallback						; in fallback condition?
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


;=============================================================================
; Check for Auto-SP
;
 IFDEF _ccr_pscr

check_dive_autosp:						; check for Auto-SP
	movff	opt_ccr_mode,WREG			; =0: Fixed SP, =1: Sensor, =2: Auto SP
	sublw	.2							; opt_ccr_mode = 2 (Auto SP)?
	bz		check_dive_autosp2			; YES - check
	return								; NO  - return for sensor or fixed mode
check_dive_autosp2:
	; check SP2
	btfsc	FLAG_SP2_used				; SP 2 used so far?
	bra		check_dive_autosp3			; YES - continue with SP 3
	movff	opt_setpoint_change+1,lo	; NO  - get depth in m
	tstfsz	lo							;     - SP change depth = 0 ?
	bra		check_dive_autosp2a			;       NO  - continue
	bra		check_dive_autosp3			;       YES - continue with SP 3
check_dive_autosp2a:
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
	return

xmit_sp_set_flag:
 IFDEF _external_sensor
	call	transmit_setpoint			; transmit current setpoint from WREG (in cbar) to external electronics
 ENDIF
	bsf		event_occured				; set global   event flag
	bsf		event_SP_change				; set setpoint event flag
	return

 ENDIF	; _ccr_pscr

;=============================================================================

set_logbook_marker:
	bcf		request_set_marker			; clear request flag
	movlw	d'6'						; set type of alarm: manual marker
	movwf	alarm_type					; copy to alarm register
	bsf		event_occured				; set event flag
	return

;=============================================================================
; Setup everything to enter dive mode
;
	global	dive_boot_oc
dive_boot_oc:
	; set-up registers
	rcall	get_first_gas_to_WREG		; get first gas (1-5) into WREG
	rcall	setup_gas_registers			; set-up of gas parameters of currently breathed gas (with WREG = gas 1-5)
	rcall	deco_setup_oc_gases			; set-up of gas list for deco calculations           (with WREG = gas 1-5)
	return


 IFDEF _ccr_pscr

	global	dive_boot_cc
dive_boot_cc:
	; set-up registers
	rcall	get_first_dil_to_WREG		; get first diluent (1-5) into WREG
	rcall	setup_dil_registers			; set-up of diluent parameters for currently breathed diluent (with WREG = current diluent 1-5)
	rcall	deco_setup_cc_diluents		; set-up of diluent list for deco calculations                (with WREG = current diluent 1-5)
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

 IFDEF _external_sensor
	; check for external HUD/ppO2 Monitor
	btfss	optical_input				; do we have an optical input?
	bra		dive_boot_cc_part2_1		; NO
	btfsc	sensor1_active				; YES - copy valid flags from HUD/ppO2 Monitor
	bsf		use_O2_sensor1				;     - ...
	btfsc	sensor2_active				;     - ...
	bsf		use_O2_sensor2				;     - ...
	btfsc	sensor3_active				;     - ...
	bsf		use_O2_sensor3				;     - ...
 ENDIF

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
	bsf		event_SP_change				; set setpoint event flag

	; Start with SP1 (CCR) or 0 (pSCR) as default.
	; If in sensor mode, this value will be overwritten by calc_deko_divemode_sensor
	clrf	WREG						; pre-load WREG with setpoint value 0 for pSCR calculated
	btfsc	FLAG_ccr_mode				; in CCR mode?
	movff	opt_setpoint_cbar+0,WREG	; YES - get value of setpoint 1 into WREG
	movff	WREG,char_I_const_ppO2		; write setpoint to deco engine
 IFDEF _external_sensor
	call	transmit_setpoint			; transmit current setpoint from WREG (in cbar) to external electronics
	goto	calc_deko_divemode_sensor	; read & process sensor data (and return)
 ELSE
	return								; done
 ENDIF

 ENDIF	; _ccr_pscr

;=============================================================================

diveloop_boot:
	; do the basic initialization
	call	restart_set_modes_and_flags

	; stop accelerometer and compass
	call	I2C_sleep_compass

	; do an early initialization of all deco engine output variables to
	; avoid glitches in the display outputs during deco engine start-up
	call	deco_init_output_vars;		; (C-code)
	banksel	common						; back to bank common

	; reset max relative pressure (max depth)
	bsf		reset_max_pressure			; request ISR to reset the max pressure


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
	movlw	.0
	movff	WREG,char_I_sim_advance_time

	; write last stop depth to deco engine
	movff	opt_last_stop,char_I_last_stop_depth

	; initialize max depth for apnoe mode
	CLRI	apnoe_max_pressure

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
	bsf		o2_sensors_agree			; initialize sensors disagree warning system

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
	clrf	WREG						; clear WREG
	bsf		WREG,int_not_avail_flag		; set   WREG to coding for integer numbers -> data not available
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
	rcall	dive_boot_oc				; YES - add OC mode settings

 IFDEF _ccr_pscr
	btfsc	FLAG_ccr_mode				; in CCR mode?
	rcall	dive_boot_cc				; YES - add CC mode settings
	btfsc	FLAG_ccr_mode				; in CCR mode?
	rcall	dive_boot_cc_part2			; YES - add CC sensor and SP settings

	btfsc	FLAG_pscr_mode				; in pSCR mode?
	rcall	dive_boot_cc				; YES - add CC mode settings
	btfsc	FLAG_pscr_mode				; in pSCR mode?
	rcall	dive_boot_cc_part2			; YES - add CC sensor and SP settings
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

divemode_check_warnings:
	movlw	.1							; one message at a time in alternative layout
	btfss	alt_layout_active			; in alternative layout?
	movlw	.2							; NO - two messages at a time in normal layout
	cpfsgt	message_counter				; more than one (alt layout) / 2 (normal layout) messages currently active?
	bra		divemode_check_warnings1	; NO  - update messages every second

;										; YES - update every 4 seconds:
;	btfss	timebase_1sec				;     - on second 1 or 3 ?
;	return								;       NO  - no update in this cycle
;	btfss	timebase_2sec				;       YES - on second 3 ?
;	return								;             NO  - no update in this cycle
;	;bra	divemode_check_warnings1	;             YES - update messages

										; NO  - update every 2 seconds
	btfsc	timebase_1sec				;     - on even second?
	return								;       NO  - done
	;bra	divemode_check_warnings1	;       YES - update messages

divemode_check_warnings1:
	; start a new message collection cycle
	bcf		message_advice				; clear flag for messages of level advice
	bcf		message_attention			; clear flag for messages of level attention
	bcf		message_warning				; clear flag for messages of level warning
	clrf	message_counter				; clear message counter

	; messages sorted by severity: highest severity warnings first, then attentions, advices and last info

	; warnings for all modes
	call	check_warn_battery			; check if the battery level should be displayed/warned
	rcall	check_depth_limit			; check current depth against set depth limit
	call	check_divetimeout			; check and show the dive mode timeout (not actually a warning)

	btfsc	FLAG_apnoe_mode				; in apnoe mode?
	bra		divemode_check_warnings2	; YES

	btfsc	FLAG_gauge_mode				; in gauge mode?
	bra		divemode_check_warnings2	; YES

	; warnings applicable only in deco modes

 IFDEF _cave_mode
	rcall	check_cavemode				; check cave mode status
 ENDIF

	rcall	check_display_ftts			; show @+x time (or cave mode cTTS)

	rcall	check_ppO2					; check ppO2 and displays warning, if required

 IFDEF _external_sensor
	btfss	o2_sensors_agree			; are the sensor values within the threshold range?
	rcall	check_warn_sensors_disagree	; NO  - do further evaluation
	btfsc	o2_sensors_agree			; are the sensor values within the threshold range?
	bcf		o2_sensors_warning			; YES - clear flag for a new warning
 ENDIF

	rcall	check_outside				; check of ZHL16 model violation

 IFDEF _helium
	rcall	check_IBCD					; check for IBCD attention or warning
 ENDIF

	btfsc	FLAG_ccr_mode				; in CCR mode?
	rcall	check_OC_gas_avail			; YES - check if a breathable OC (bailout) gas is available
	btfsc	FLAG_pscr_mode				; in pSCR mode?
	rcall	check_OC_gas_avail			; YES - check if a breathable OC (bailout) gas is available

	btfsc	decostop_active				; in deco mode?
	rcall	check_and_store_sat_violation; YES - sets warnings, if required

	rcall	check_mbubbles				; check for micro bubbles
	rcall	check_cns_violation			; check CNS value and display it, if required
	rcall	check_gas_needs		; show gas needs warning if any gas need for ascent is > threshold
	rcall	check_eod_cns_violation		; check CNS values for end-of-dive and display warning, if required

	btfsc	use_aGF						; using alternative GF factors?
	rcall	warn_agf					; YES - show memo

	btfsc	sp_fallback					; in fallback condition due to O2 sensor failure?
	rcall	warn_fallback				; YES - show a warning

	btfsc	better_dil_available		; is a better diluent available?
	rcall	advice_gas_change			; YES - display a gas change advice

	btfsc	better_gas_available		; is a better gas     available?
	rcall	advice_gas_change			; YES - display a gas change advice

divemode_check_warnings2:
 IFDEF _rx_functions
	btfss	tr_functions_activated		; TR functions activated?
	bra		divemode_check_warnings3	; NO  - skip
	call	check_tr_functions			; YES - check transmitter functions
	call	check_tr_messages			;     - check SAC attention and switch advice
 ENDIF

divemode_check_warnings3:
	; Display / clear the advice, attention or warning icon
	btfsc	message_advice				; any message of level advice?
	bsf		FLAG_TFT_sign_show			; YES
	btfsc	message_attention			; any message of level attention?
	bsf		FLAG_TFT_sign_show			; YES
	btfsc	message_warning				; any message of level warning?
	bsf		FLAG_TFT_sign_show			; YES
	btfss	FLAG_TFT_sign_show			; any message of above levels?
	bsf		FLAG_TFT_sign_clear 		; NO - clear sign

	; Increment message page number
	incf	message_page,F				; increment page number
	bcf		STATUS,C					; clear carry bit
	movf	message_page,W				; get page number into WREG
	btfss	alt_layout_active			; in alternative layout?
	rlcf	WREG,W						; NO - each page can take two messages
	cpfsgt	message_counter				; number of actual messages > message capacity ?
	clrf	message_page				; NO - all messages could be shown, restart from first page next time

	; Clear both rows of messages if there is nothing to show at all
	tstfsz	message_counter				; any message to show?
	bra		divemode_check_warnings4	; YES - look if second row needs to be cleared
	bsf		FLAG_TFT_message_clear_both	; NO  - request clearing of left-over messages
	return								;     - done

divemode_check_warnings4:
	; Clear 2nd row of messages if there is nothing to show (on this page)
	btfss	message_2nd_row_used		; does the 2nd row contain a message?
	bsf		FLAG_TFT_message_clear_2nd	; NO - set flag to clear the 2nd row
	return								; done

;-----------------------------------------------------------------------------

	global	check_warn_battery
check_warn_battery:
	movlw	battery_show_level+1		; get threshold for showing battery level, incremented by 1
	cpfslt	batt_percent				; battery percentage ok?
	return								; YES - no display, no warning
	; Display Battery, but warn?
	btfsc	battery_low_condition		; battery low condition detected?
	bsf		message_warning				; YES - set warning flag for battery low
	movlw	index_clock_batt_surfpress	; index of custom view clock, battery and surface pressure
	cpfseq	active_customview			; battery shown in custom view?
	bra		check_warn_battery2			; NO  - show warning
	return								; YES - do not show twice (in custom view and in message area)
check_warn_battery2:
	incf	message_counter,F			  ; increase counter
	goto	TFT_msg_batt_percent_divemode ; show warning message for battery low (battery percent) and return


check_divetimeout:
	btfsc	count_divetime				; is dive time counted?
	return								; YES - do nothing
	incf	message_counter,F			; increase counter
	goto	TFT_divetimeout				; show timeout counter (and return)


check_ppO2:
 IFDEF _ccr_pscr
	btfsc	FLAG_oc_mode				; are we in OC mode?
	bra		check_ppO2_1				; YES - continue with breathed gas
	btfsc	bailout_mode				; NO  - in bailout?
	bra		check_ppO2_1				;       YES - continue with breathed gas
	; CCR / pSCR mode - checks on pure diluent
	MOVII	int_O_pure_ppO2,mpr			; get value and attention/warning flags for the pure diluent
	btfsc	hi,int_warning_flag			; is there a ppO2 low or high warning on the pure diluent?
	rcall	check_ppO2_dw				; YES - show warning and return on next line
	btfsc	hi,int_attention_flag		; ppO2 of the pure diluent in attention state?
	rcall	check_ppO2_da				; YES - show attention and return on next line
 ENDIF
	; all modes - checks on breathed gas (OC or from loop)
check_ppO2_1:
	MOVII	int_O_breathed_ppO2,mpr		; get value and attention/warning flags for the breathed gas
	btfsc	hi,int_attention_flag		; breathed ppO2 in attention state (when in loop mode, no attention will be generated)?
	bra		check_ppo2_display_a		; YES - set attention flag and show ppO2
	btfsc	hi,int_low_flag				; breathed ppO2 too low?
	bra		check_ppO2_low				; YES - record the warning and show ppO2
	btfsc	hi,int_high_flag			; breathed ppO2 too high?
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
	movwf	alarm_type					; copy alarm type to alarm register
	bsf		event_occured				; set event   flag
	bsf		message_warning				; show warning sign for breathed ppO2
check_ppO2_common_2:
	btfsc	FLAG_oc_mode				; are we in OC mode?
	bra		check_ppo2_display			; YES - show
 IFDEF _ccr_pscr
	btfsc	bailout_mode				; are we in bailout mode?
	bra		check_ppo2_display			; YES - show
 ENDIF
	return								; NO  - in loop mode, ppO2 is already shown via setpoint display
check_ppo2_display_a:
	bsf		message_attention			; show attention sign for breathed ppO2
check_ppo2_display:
	movlw	index_ppo2_ead_end_cns		; index of custom view ppO2, EAD/END and CNS (without He) or gas density (with He)
	cpfseq	active_customview			; ppO2 shown?
	bra		check_ppO2_b				; NO
	return								; YES - do not show twice (in custom view and in warning area)
check_ppO2_b:
	movlw	index_pscr_info				; index of custom view with pSCR data
	cpfseq	active_customview			; ppO2 shown?
	bra		check_ppO2_d				; NO  - show ppO2
	return								; YES - do not show twice (in custom view and in warning area)
check_ppO2_dw:
	bsf		message_warning				; show warning   sign for diluent ppO2
check_ppO2_da:
	bsf		message_attention			; show attention sign for diluent ppO2 (no problem if a warning sign is set as well, as it will take priority)
check_ppO2_d:
	incf	message_counter,F			; increase counter
	goto	TFT_show_ppo2_warning		; show warning message for breathed gas or diluent ppO2 and return


check_display_ftts:
 IFDEF _ccr_pscr
	btfsc	bailout_mode				; in bailout mode?
	return								; YES - in bailout no fTTS is computed, done
 ENDIF
	btfss	count_divetime				; is dive time counted?
	return								; NO  - omit, done
	movff	char_I_extra_time,lo		; YES - get extra time
	tstfsz	lo							;     - extra time > 0 ?
	bra		check_display_ftts_1		;       YES - continue checking bailout condition
	return								;       NO  - no fTTS computed, done
check_display_ftts_1:
	incf	message_counter,F			; increase counter
	goto	TFT_show_ftts				; show @+x time


	global	check_cns_violation
check_cns_violation:
	; Check if CNS should be displayed
	movff	int_O_CNS_current+1,WREG	; get current CNS, high byte
	btfsc	WREG,int_warning_flag		; warning flag set?
	bra		check_cns_violation_1		; YES - issue warning
	btfsc	WREG,int_attention_flag		; NO  - attention flag set?
	bra		check_cns_violation_2		;       YES - issue attention
	return								;       NO  - done
check_cns_violation_1:
	bsf		message_warning				; show warning   sign for CNS
check_cns_violation_2:
	bsf		message_attention			; show attention sign for CNS
 IFNDEF _helium
	movlw	index_ppo2_ead_end_cns		; index of custom view ppO2, EAD/END and CNS (without He) or gas density (with He)
	cpfseq	active_customview			; CNS shown?
	bra		check_cns_violation_3		; NO
	return								; YES - do not show twice (in custom view and in warning area)
 ENDIF
check_cns_violation_3:
	movlw	index_CNS					; index of custom view with CNS values
	cpfseq	active_customview			; CNS shown?
	bra		check_cns_violation_4		; NO
	return								; YES - do not show twice (in custom view and in warning area)
check_cns_violation_4:
	incf	message_counter,F			; increase counter
	goto	TFT_show_cns				; show attention/warning message for CNS and return


	global	check_eod_cns_violation		; check end-of-dive CNS values
check_eod_cns_violation:
	movff	int_O_CNS_current+1,WREG	; get current CNS, high byte
	btfsc	WREG,int_warning_flag		; current CNS value in warning state?
	return								; YES - inhibit end-of-dive warning if current CNS is already in warning
	movff	int_O_CNS_norm+1,WREG		; get CNS at end of dive in normal plan, high byte
	btfsc	WREG,int_invalid_flag		; flag for invalid value set?
	bra		check_eod_cns_violation1	; YES - continue with checking the other CNS value
	btfsc	WREG,int_warning_flag		; NO  - flag for warning set?
	bra		check_eod_cns_violation2	;       YES - issue warning
check_eod_cns_violation1:				;       NO  - continue with checking the other CNS value
	movff	int_O_CNS_alt+1,WREG		; get CNS at end of dive in alternative plan, high byte
	btfsc	WREG,int_invalid_flag		; flag for invalid value set?
	return								; YES - done with CNS checking
	btfsc	WREG,int_warning_flag		; NO  - flag for warning set?
	bra		check_eod_cns_violation2	;       YES - issue warning
	return								;       NO  - done with CNS checking
check_eod_cns_violation2:				; issue warning (actually only on attention level)
	bsf		message_attention			; show attention sign for end-of-dive CNS
	movlw	index_CNS					; index of custom view with CNS values
	cpfseq	active_customview			; CNS values shown?
	bra		display_eod_cns_violation	; NO  - issue textual warning
	return								; YES - do not show twice (in custom view and in warning area)
display_eod_cns_violation:
	incf	message_counter,F			; increase counter
	goto	TFT_warning_eod_cns			; show warning message for end-of-dive CNS and return


	global	check_and_store_sat_violation
check_and_store_sat_violation:
	movff	int_O_lead_supersat+1,WREG		; get upper byte of leading tissue's supersaturation
	btfss	WREG,int_warning_flag			; check if the warning flag is set
	bra		check_and_store_sat_violation2	; NO  - continue with checking for attention flag
	movlw	d'2'							; YES - set type of alarm
	movwf	alarm_type						;     - copy to alarm register
	bsf		event_occured					;     - set  event   flag
	bsf		message_warning					;     - show warning sign for saturation
	bra		check_and_store_sat_violation3	;     - show saturation
check_and_store_sat_violation2:
	btfsc	WREG,int_attention_flag			; check if the attention flag is set
	bra		check_and_store_sat_violation3	; YES - show saturation
	TSTOSS	opt_enable_IBCD					; NO  - IBCD warning activated?
	bra		check_and_store_sat_violation4	;       NO  - continue checking of deco info
	movff	char_O_deco_warnings,WREG		;       YES - get the deco warnings vector
	btfss	WREG,IBCD_warning				;           - is the IBCD warning flag set?
	bra		check_and_store_sat_violation4	;             NO  - continue checking for deco info
check_and_store_sat_violation3:				;             YES - show saturation
	bsf		message_attention				; show attention sign for saturation
	incf	message_counter,F				; increase counter
	goto	TFT_warning_saturation			; show attention/warning message for saturation and return
check_and_store_sat_violation4:				; check for deco info
	btfss	divemode						; in dive mode?
	return									; NO  - done, return
 IFDEF _ccr_pscr
	btfsc	bailout_mode					; YES - in bailout mode?
	return									;       YES - done, return (deco zone flag is not updated when in bailout mode)
 ENDIF
	movff	char_O_deco_info,WREG			;       NO  - get the deco info vector
	btfss	WREG,deco_zone					;             check if the deco zone flag is set
	return									;             NO  - done, return
	btfsc	use_aGF							;             YES - using alternative GF factors?
	return									;                   YES - suppress deco zone info
	btfsc	alt_layout_active				;                   NO  - in alternative layout?
	return									;                         YES - suppress deco zone info
	incf	message_counter,F				;                         NO  - increase counter
	goto	TFT_info_deco					;                             - show deco info


check_depth_limit:
	bcf		depth_limit_exceeded		; clear warning flag by default
	movff	opt_max_depth,WREG			; get depth limit
	cpfsgt	depth_meter					; current depth > depth limit?
	return								; NO
	bsf		depth_limit_exceeded		; YES - set flag for depth limit exceeded
	incf	message_counter,F			;     - increase counter
	bsf		message_warning				;     - show warning sign    for depth
	goto	TFT_warning_depth			;     - show warning message for depth


check_outside:
	movff	char_O_deco_warnings,WREG	; bank-safe copy of deco warnings
	btfss	WREG,outside_warning_lock	; are we outside of the ZH-L16 model?
	return								; NO  - done
	incf	message_counter,F			; YES - increase counter
	bsf		message_attention			;     - show attention sign for outside
	btfsc	WREG,outside_warning		;     - are we outside the ZH-L16 model right now (-> warning)?
	bsf		message_warning				;     - show warning sign for outside
	goto	TFT_warning_outside			;     - show warning/attention message for outside and return


	global	check_mbubbles
check_mbubbles:
	movff	char_O_deco_warnings,WREG	; bank-safe copy for deco warnings
	btfsc	WREG,mbubble_warning		; are we in micro bubbling zone right now?
	bra		check_mbubbles_warn			; YES
	btfss	WREG,mbubble_warning_lock	; were we in micro bubbling zone?
	return								; NO  - done
check_mbubble_att						; YES - attention level
	incf	message_counter,F			; increase counter
	bsf		message_attention			; show attention sign for micro bubbles
	goto	TFT_warning_mbubbles		; show micro bubble attention (and return) - TFT_warning_mbubbles switches by itself between attention and warning
check_mbubbles_warn:					; locked micro bubbles - warning level if at issue, attention level if locked
	incf	message_counter,F			; increase counter
	bsf		message_warning				; show warning sign    for micro bubbles
	goto	TFT_warning_mbubbles		; show warning message for micro bubbles (and return)


 IFDEF _cave_mode

check_cavemode:
	btfsc	backtrack_entire_full		; is the backtracking storage entirely used up?
	bra		check_cavemode_full			; YES - turn dive, switch off cave mode and show warning message
	btfsc	backtrack_almost_full		; NO  - backtracking storage almost full?
	bra		check_cavemode_almost_full	;       YES - show attention message that cave mode will stop soon
	btfss	alt_layout_active			;       NO  - alternative layout active?
	bra		check_cavemode_info			;             NO  - show cave mode active info
	return								;             YES - suppress info message

check_cavemode_full:
	btfss	backtrack_shutdown			; backtracking shut down already?
	bsf		request_cave_off_turned		; NO  - request to switch cave mode off and to set the dive as turned
	bsf		backtrack_shutdown			; remember shut down as been executed (anyhow)
	incf	message_counter,F			; increase counter
	btfsc	cave_mode					; has the cave mode been switched on again meanwhile?
	goto	TFT_cave_shutdown_attention	; YES - show attention message for cave mode shutdown ands return
	bsf		message_warning				; NO  - show warning   sign    for cave mode shutdown
	goto	TFT_cave_shutdown_warning	;     - show warning   message for cave mode shutdown and return

check_cavemode_almost_full:
	btfss	cave_mode					; cave mode switched on?
	return								; NO  - suppress message
	incf	message_counter,F			; YES - increase counter
	goto	TFT_cave_shutdown_attention	;     - show attention message that cave mode will shut down soon

check_cavemode_info:
	btfss	cave_mode					; cave mode switched on?
	return								; NO  - do not show info
	incf	message_counter,F			; YES - increase counter
	goto	TFT_info_cave_mode			;     - show cave mode active info

 ENDIF	; _cave_mode


warn_agf:
	incf	message_counter,F			; increase counter
	goto	TFT_warning_agf				; show aGF reminder (and return)

warn_fallback:
	incf	message_counter,F			; increase counter
	bsf		message_warning				; show warning sign    for fallback
	goto	TFT_warning_fallback		; show warning message for fallback and return

;=============================================================================

 IFDEF _rx_functions

check_tr_messages:
	btfss	count_divetime				; is the dive time counted, i.e. deeper than dive threshold?
	return								; NO  - suppress messages
	movff	int_O_SAC_measured+1,WREG	; YES - bank-safe copy of measured SAC rate
	btfss	WREG,int_attention_flag		;     - attention flag set?
	bra		check_tr_messages2			;       NO  - skip
	btfsc	WREG,int_not_avail_flag		;       SAC rate available?
	bra		check_tr_messages2			;       NO  - continue with swap advice
	bsf		message_attention			;       YES - show attention sign for SAC rate
	movlw	index_pressures_SAC			;           - index of custom view with SAC rate
	cpfseq	active_customview			;           - SAC rate shown right now?
	bra		check_tr_messages1			;             NO  - show attention message
	bra		check_tr_messages2			;             YES - do not show twice, continue with swap advice
check_tr_messages1:
	incf	message_counter,F			; increase counter
	call	TFT_attention_sac			; show attention message for SAC rate
check_tr_messages2:
	movff	char_O_deco_info,WREG		; bank-safe copy of deco info vector
	btfss	WREG,ind_double_switch		; swap tank flag set?
	return								; NO
	incf	message_counter,F			; YES - increase counter
	bsf		message_advice				;     - show advice sign    for switching tanks
	goto	TFT_advice_switch			;     - show advice message for switching tanks and return

check_tr_functions:
	clrf	xmitter_flags_mesg				; set all messages as not shown yet
	movlw	index_pressures_SAC				; index of custom view pressure readings
	cpfseq	active_customview				; pressure readings shown?
	bra		check_tr_functions_tr1			; NO  - continue with checking transmitter 1
	bsf		pres_customview_shown			; YES - suppress redraw by faking it has already been redrawn
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
	btfss	show_transmitter_attention		; shall show transmitter attention message?
	bra		check_tr_functions_show_warn	; NO  - continue with pressure warning
	bsf		message_attention				; YES - show attention sign for transmitter
	incf	message_counter,F				;     - increase counter
	call	TFT_attention_transmitter		;     - show transmitter attention message
check_tr_functions_show_warn:
	btfss	show_pres_warning				; shall show pressure warning?
	bra		check_tr_functions_show_att		; NO  - continue with pressure attention
	bsf		message_warning					; YES - show warning sign for pressure
	incf	message_counter,F				;     - increase counter
	goto	TFT_warning_pres_reading		;     - show warning message for pressure reading and return
check_tr_functions_show_att:
	btfss	show_pres_attention				; shall show pressure attention?
	return									; NO  - done
	bsf		message_attention				; YES - show attention sign for pressure
	incf	message_counter,F				;     - increase counter
	goto	TFT_attention_pres_reading		;     - show attention message for pressure reading and return

check_tr_functions_helper1:
	btfsc	WREG,char_transmitter_lost		; transmitter 1 lost?
	bra		check_tr_functions_helper1a		; YES - show transmitter attention message
	bcf		transmitter1_lost				; NO  - clear flag for old lost attention
	return									;     - done
check_tr_functions_helper1a:
;	bsf		show_transmitter_attention		; show transmitter attention
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
	bsf		show_transmitter_attention		; show transmitter attention
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
;	bsf		show_transmitter_attention		; show transmitter attention
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
	bsf		show_transmitter_attention		; show transmitter attention
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
	btfsc	pres_customview_shown			; is the pressure readings custom view not shown yet?
	return									; NO  - already shown, done
	btfsc	custom_view_locked				; YES - custom view locked?
	return									;       YES - done
	bsf		pres_customview_shown			;       NO  - mark as shown now
	movlw	index_pressures_SAC				;           - get  custom view number of pressure readings
	goto	dive_customview_show			;           - draw custom view and return

 ENDIF

;=============================================================================

check_gas_needs:
	banksel	int_O_gas_need_pres
	movf	int_O_gas_need_pres+1,W		; get               high byte from pres need of 1st tank
	iorwf	int_O_gas_need_pres+3,W		; inclusive or with high byte from pres need of 2nd tank
	iorwf	int_O_gas_need_pres+5,W		; inclusive or with high byte from pres need of 3rd tank
	iorwf	int_O_gas_need_pres+7,W		; inclusive or with high byte from pres need of 4th tank
	iorwf	int_O_gas_need_pres+9,W		; inclusive or with high byte from pres need of 5th tank
	banksel	common
	btfsc	WREG,int_invalid_flag		; check if invalid flag is set
	return								; YES - no further checking required
	btfsc	WREG,int_warning_flag		; NO  - check if any gas has a pres_need >= pres_fill
	bra		check_gas_needs_warn		;       YES - generate a warning
	btfsc	WREG,int_attention_flag		;       NO  - check if any gas has a pres_need >= pres_fill * threshold
	bra		check_gas_needs_att	;             YES - generate an attention
	bcf		gas_needs_attention			;             NO  - clear flag for a new attention
	bcf		gas_needs_warning			;                 - clear flag for a new warning
	return								;                 - done

check_gas_needs_warn:
	bsf		message_warning				; show warning sign for gas needs
	incf	message_counter,F			; increase counter
	btfsc	gas_needs_warning			; is it a new warning?
	bra		check_gas_needs_warn_1		; NO  - do not show the gas needs custom view again
	btfsc	custom_view_locked			; YES - custom view locked?
	bra		check_gas_needs_warn_1		;       YES - done
	bsf		gas_needs_warning			;       NO  - memorize it's an old now
	movlw	index_gas_needs_ascent		;           - get  custom view number of gas needs
	call	dive_customview_show		;           - draw custom view
check_gas_needs_warn_1:
	goto	TFT_warning_gas_needs		;     - show warning message for gas needs and return

check_gas_needs_att:
	bsf		message_attention			; show attention sign for gas needs
	incf	message_counter,F			; increase counter
	btfsc	gas_needs_attention			; is it a new attention?
	bra		check_gas_needs_att_1		; NO  - do not show the gas needs custom view again
	btfsc	custom_view_locked			; YES - custom view locked?
	bra		check_gas_needs_att_1		;       YES - done
	bsf		gas_needs_attention			;       NO  - memorize it's an old now
	movlw	index_gas_needs_ascent		;           - get  custom view number of gas needs
	call	dive_customview_show		;           - draw custom view
check_gas_needs_att_1:
	goto	TFT_attention_gas_needs		;     - show attention message for gas needs and return

;=============================================================================

 IFDEF _external_sensor

check_warn_sensors_disagree:
	incf	message_counter,F			; increase counter
	bsf		message_warning				; show warning sign for sensor disagree
	btfsc	o2_sensors_warning			; is it a new warning?
	goto	TFT_warning_sensor_disagree	; NO  - don't show sensor custom view again, just show sensor disagree warning and return
	bsf		o2_sensors_warning			; YES - memorize it's an old warning now
	call	show_sensors_custview		;     - show sensors custom view
	goto	TFT_warning_sensor_disagree	;     - show warning message for sensor disagree and return

 ENDIF

;=============================================================================

 IFDEF _helium

check_IBCD:
	TSTOSS	opt_enable_IBCD				; IBCD warning activated?
	return								; NO  - done
	movff	char_O_deco_warnings,WREG	; YES - get deco warnings vector
	btfss	WREG,IBCD_warning			;       IBCD warning flag set?
	return								;       NO  - return
	incf	message_counter,F			;       YES - increase counter
	goto	TFT_warning_IBCD			;             write warning to display

 ENDIF

;=============================================================================

check_OC_gas_avail:
	tstfsz	best_gas_number				; is a breathable OC (bailout) gas available?
	return								; YES (>0) - a breathable gas is available
 IFDEF _ccr_pscr
	btfsc	bailout_mode				; in bailout?
	return								; YES - suppress warning
 ENDIF
	incf	message_counter,F			; increase counter
	bsf		message_warning				; show warning sign    for no bailout gas
	goto	TFT_warning_no_BO_gas		; show warning message for no bailout gas and return


advice_gas_change:
	bsf		message_advice				; show advice sign
	incf	message_counter,F			; increase counter
	goto	TFT_advice_gas_change		; show advice (and return)


	global	restart_deco_engine
	global	restart_deco_engine_wo_ceiling
restart_deco_engine:
	banksel	int_O_ceiling								; switch to bank where the shared "_O_" variables are stored
	bsf		int_O_ceiling+1,char_invalid_flag			; invalidate ceiling (int_O_ceiling has its invalid flag on a char's position!)

restart_deco_engine_wo_ceiling:
	banksel	char_O_deco_gas								; switch to bank where the shared "_O_" variables are stored
	bsf		char_O_deco_gas+0,char_invalid_flag			; invalidate deco data (stop table data)
	bsf		int_O_NDL_norm+1,int_invalid_flag			; invalidate NDL time (normal plan)
	bsf		int_O_TTS_norm+1,int_invalid_flag			; invalidate TTS time (normal plan)
	bsf		int_O_TST_norm+1,int_invalid_flag			; invalidate TST time (normal plan)
	bsf		int_O_CNS_norm+1,int_invalid_flag			; invalidate CNS at end of dive in normal plan

restart_deco_engine_wo_norm:
	banksel	common										; bank to bank common
	bsf		request_restart_engine						; request restart of the deco engine

inval_alternative_plan_data:
	banksel	int_O_TTS_alt								; switch to bank where the shared "_O_" variables are stored
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

	return

;=============================================================================
; Simulator Mode
;
	global	do_demo_divemode
do_demo_divemode:
	call	TFT_ClearScreen					; blank screen

	; leaving menu mode, so have option values in EEPROM up-to-date
	btfsc	options_changed					; do the options need to be stored to EEPROM ?
	call	option_check_and_store_all		; YES - check and store all option values in EEPROM
	bcf		options_changed					; clear flag

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
	goto	diveloop						; branch to dive mode code

	END
