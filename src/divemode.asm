;=============================================================================
;
;   File divemode.asm								REFACTORED VERSION V2.98
;
;   Divemode
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;  2011-08-15 : [mH] moving from OSTC code

#include "hwos.inc"						; Mandatory header
#include "shared_definitions.h"			; Mailbox from/to p2_deco.c
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


	extern	TFT_dive_compass_heading
	extern	do_line_menu
	extern	do_main_divemenu
	extern	option_save_all
	extern	init_recording_params


	;---- Private local variables -------------------------------------------------

	CBLOCK	local1						; max size is 16 Byte !!!
		apnoe_timeout_counter			; timeout counter for apnoe mode
		average_depth_hold:4			; used in calculation of the average depth
		sensor_setpoint					; sensor ppo2 in 0.01bar for deco routine
		active_diluent					; backup of diluent gas for when switching back from bailout to CCR/pSCR loop
		average_depth_hold_total:4		; used to calculate the average depth
	ENDC								; used: 11 byte, remaining: 5 byte

gui		CODE

;=============================================================================

	global	diveloop
diveloop:
	banksel common
	call	speed_normal
	call	diveloop_boot				; Boot tasks for all modes

	; Startup Tasks for all modes
	call	TFT_boot					; Initialize TFT (includes clear screen)
	bsf		FLAG_TFT_divemode_mask		; Display mask
	movff	customview_divemode,menupos3; Reload last customview
	call	customview_mask				; Redraw last custom view

	btfsc	FLAG_apnoe_mode
	bsf		realdive					; Set Realdive flag in Apnoe mode

	btfsc	FLAG_apnoe_mode				; Done for Apnoe or Gauge mode
	bra		diveloop_loop_start
	btfsc	FLAG_gauge_mode				; Done for Apnoe or Gauge mode
	bra		diveloop_loop_start

	bsf		FLAG_TFT_display_ndl_mask	; display "NDL"

	; +@5 init
	clrf	WREG						; WAIT marker: display "---"
	movff	WREG,char_I_sim_advance_time
	movff	WREG,int_O_alternate_ascenttime+0
	bsf		WREG,int_not_yet_computed
	bsf		WREG,int_invalid_flag
	movff	WREG,int_O_alternate_ascenttime+1

diveloop_loop_start:
	btfsc	FLAG_TFT_display_ndl_mask
	call	TFT_display_ndl_mask


diveloop_loop:							; The diveloop starts here
	btfss	quarter_second_update
	bra		diveloop_loop1

	; tasks any 1/4 second, any mode
	bcf		quarter_second_update		; clear flag

	movlw	.6
	cpfseq	menupos3					; in compass view?
	bra		diveloop_loop1				; No, done.

	btfsc	alternative_divelayout		; In alternative layout mode?
	bra		diveloop_loop1				; Yes, done. No Compass.

; TFT Output routines
	call	TFT_dive_compass_heading	; Yes, update compass heading value
	bsf		FLAG_TFT_temp_divemode		; Redraw temperature (is slightly affected from compass heading arrow)
; TFT Output routines

diveloop_loop1:
	btfss	onesecupdate
	bra		diveloop_loop3

; tasks any new second...
	bcf		onesecupdate				; one seconds update, clear flag here in case it's set again in ISR before all tasks are done.

	;bsf	LEDg	; ### USE FOR DEBUG ONLY - RESETS RX CIRCUITRY ###

	; display depth based on full seconds interval (nicer blinking)
	btfss	alternative_divelayout
	rcall	TFT_output4_normal
	btfsc	alternative_divelayout
	rcall	TFT_output4_alternative

	btfsc	FLAG_apnoe_mode				; Only in apnoe mode
	bra		diveloop_loop1_nonedeco		; One Second Tasks in Apnoe mode

; tasks any new second - only for deco modes
diveloop_loop1_decomodes:
	bsf		FLAG_TFT_divemins			; Display (new) divetime!
	btfsc	show_safety_stop			; Show the safety stop?
	bsf		FLAG_TFT_show_safety_stop	; Yes, show/delete if done.

	btfss	alternative_divelayout
	rcall	TFT_output1_normal
	btfsc	alternative_divelayout
	rcall	TFT_output1_alternative

	btfsc	FLAG_ccr_mode				; in CCR mode...
	call	check_dive_autosp			; ...check for Auto-SP

	call	calc_deko_divemode			; calculate decompression and set resulting display flags

	btfss	alternative_divelayout
	rcall	TFT_output2_normal
	btfsc	alternative_divelayout
	rcall	TFT_output2_alternative

	call	divemode_check_for_warnings	; Check for any warnings

	bra		diveloop_loop2				; Common Tasks


; tasks any new second - only for apnoe mode
diveloop_loop1_nonedeco:
	rcall	divemode_apnoe_tasks		; 1 sec. Apnoe tasks
	call	customview_second			; Do every-second tasks for the custom view area
	;bra	diveloop_loop2				; Common Tasks

; continue tasks any new second, any mode
diveloop_loop2:
	rcall	timeout_divemode			; ** menu timeout? ** This routine sets the required flags
	rcall	set_dive_modes				; tests if depth > threshold
	rcall	set_min_temp				; store min. temp if required (Future hardware will need this to be checked 1/second...)

	btfsc	oneminupdate				; one minute tasks
	rcall	update_divemode60			; Update clock, etc.

	btfss	alternative_divelayout
	rcall	TFT_output3_normal
	btfsc	alternative_divelayout
	rcall	TFT_output3_alternative

	;bcf	LEDg	; ### USE FOR DEBUG ONLY - RESETS RX CIRCUITRY ###

; tasks any round, any mode
diveloop_loop3:
	call	test_switches_divemode		; Check switches in divemode

	global	diveloop_loop4
diveloop_loop4:							; Menu-Exit returns here...
	btfsc	divemode_menu				; in the big divemode menu?
	bra		diveloop_loop4b				; YES - no space for CCR/pSCR info
	btfsc	menuview					; NO  - in the small yellow menu?
	bra		diveloop_loop4b				;       YES - no space for CCR/pSCR info
	btfsc	alternative_divelayout		;       NO  - in the alternative layout?
	bra		diveloop_loop4b				;             YES - no space for CCR/pSCR info
	call	TFT_show_mode_divemode		;             NO  - (re)write CCR/pSCR mode info to display
diveloop_loop4b:
	btfsc	toggle_customview			; Next view?
	call	customview_toggle			; Yes, show next customview (and delete this flag)

	btfsc	divemode_gaschange			; Gas switch flag set?
	call	gas_switched_common			; YES

	btfsc	toggle_gf					; Toggle GF/aGF?
	rcall	divemodemode_togglegf		; YES

	btfsc	FLAG_set_marker				; shall a marker be set?
	call	set_logbook_marker			; YES

	btfsc	store_sample				; store new sample?
	call	store_dive_data				; Store profile data

	btfss	divemode					; Dive finished?
	goto	ghostwriter_end_dive		; Dive finished!

	btfsc	pressure_refresh			; new pressure available?
	rcall	set_max_depth				; update max. depth if required
	btfsc	pressure_refresh			; new pressure available?
	bsf		FLAG_TFT_depth				; Yes, update depth
	bcf		pressure_refresh			; clear flag

	btfsc	temp_changed
	bsf		FLAG_TFT_temp_divemode		; Displays temperature

	; display depth based on as-fast-as-possible (no nice blinking)
	;btfss	alternative_divelayout
	;rcall	TFT_output4_normal
	;btfsc	alternative_divelayout
	;rcall	TFT_output4_alternative

	btfsc	enable_screen_dumps			; =1: Ignore vin_usb, wait for "l" command (Screen dump)
	bra		diveloop_loop5
	bra		diveloop_loop6

diveloop_loop5:
	btfss	vusb_in						; USB (still) plugged in?
	bcf		enable_screen_dumps			; No, clear flag
	call	rs232_get_byte
	btfsc	rs232_receive_overflow
	bra		diveloop_loop6
	movlw	"l"
	cpfseq	RCREG1
	bra		diveloop_loop6
	call	TFT_dump_screen				; Dump the screen contents

diveloop_loop6:
	bra		diveloop_loop				; Loop the divemode

;--------------------------------------------------------------------------------------------------------	

TFT_output1_normal:						; beginning of any new second - only for deco modes
	btfsc	FLAG_TFT_divemode_mask
	call	TFT_divemode_mask
	btfsc	FLAG_TFT_divemins
	call	TFT_divemins				; Display (new) divetime!
	call	customview_second			; Do every-second tasks for the custom view area (In sync with the divetime) mH
	btfsc	FLAG_TFT_show_safety_stop
	call	TFT_show_safety_stop		; Show safety stop
	btfsc	FLAG_TFT_clear_safety_stop
	call	TFT_clear_safety_stop		; Clear safety stop
	return

TFT_output1_alternative:				; beginning of any new second - only for deco modes
	btfsc	FLAG_TFT_divemins
	call	TFT_divemins_alternative	; Display (new) divetime!
	btfsc	FLAG_TFT_divemode_mask_alt
	call	TFT_divemode_mask_alternative ; Alt. mask
	call	customview_alternative_second ; Do every-second tasks for the custom view area (In sync with the divetime) mH
	btfsc	FLAG_TFT_big_deco_alt
	call	TFT_big_deco_alt			; Big deco and safety stop
	return

TFT_output2_normal:						; any new second - only for deco modes
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

TFT_output2_alternative:				; any new second - only for deco modes
	return

TFT_output3_normal:						; tasks any new second, any mode
	btfsc	FLAG_TFT_max_depth
	call	TFT_max_depth				; use normal max. depth
	btfsc	FLAG_TFT_divemode_warning
	call	TFT_divemode_warning
	btfsc	FLAG_TFT_divemode_warning_clear
	call	TFT_divemode_warning_clear
	btfsc	FLAG_TFT_active_gas_divemode
	call	TFT_active_gas_divemode		; Display gas/Setpoint
	btfsc	FLAG_TFT_dive_warning_text_clear
	call	TFT_clear_warning_text		; clear complete warnings area
	btfsc	FLAG_TFT_dive_warning_text_clr2
	call	TFT_clear_warning_text_2nd_row; clear 2nd row of warnings
	return

TFT_output3_alternative:				; tasks any new second, any mode
	btfsc	FLAG_TFT_max_depth_alt
	call	TFT_max_depth_alternative	; big max. depth
	btfsc	FLAG_TFT_dive_warning_text_clear
	call	TFT_clear_warning_text		; clear complete warnings area (In alt mode only 2nd. row...)
	return

TFT_output4_normal:						; tasks any round, any mode
	btfsc	FLAG_TFT_depth
	call	TFT_depth					; Displays new depth
	btfsc	FLAG_TFT_temp_divemode
	call	TFT_temp_divemode			; Update temperature
	return

TFT_output4_alternative:				; tasks any round, any mode
	btfsc	FLAG_TFT_depth
	call	TFT_depth					; Displays new depth
	return


;--------------------------------------------------------------------------------------------------------

divemode_apnoe_tasks:					; 1 sec. Apnoe tasks
	call	TFT_display_apnoe_descent	; Yes, Show descent timer
	call	TFT_max_depth				; use normal max. depth

	btfsc	divemode2					; Time running?
	bra		divemode_apnoe_tasks2		; New descent, reset data if flag is set

	rcall	apnoe_calc_maxdepth
	call	TFT_display_apnoe_surface
	call	TFT_display_apnoe_last_max	; Show last max. depth
	incf	apnoe_surface_secs,F
	movlw	d'60'
	cpfseq	apnoe_surface_secs
	bra		divemode_apnoe_tasks1
	clrf	apnoe_surface_secs
	incf	apnoe_surface_mins,F

divemode_apnoe_tasks1:
	bcf		FLAG_active_descent			; Clear flag
	btfsc	divemode2					; Time running?
	return								; Yes, return
	bsf		FLAG_active_descent			; Set Flag
	return

divemode_apnoe_tasks2:
	btfss	FLAG_active_descent			; Are we descending?
	return								; No, We are at the surface
	rcall	apnoe_calc_maxdepth			; Yes!
	call	TFT_apnoe_clear_surface		; Clear Surface timer
	clrf	apnoe_timeout_counter		; Delete timeout
	clrf	apnoe_surface_secs
	clrf	apnoe_surface_mins
	clrf	apnoe_secs
	clrf	apnoe_mins					; Reset Descent time
	movlw	.0
	movff	WREG,max_pressure+0
	movff	WREG,max_pressure+1			; Reset Max. Depth
	bcf		FLAG_active_descent			; Clear flag
	return

	global	apnoe_calc_maxdepth
apnoe_calc_maxdepth:
	movff	apnoe_max_pressure+0,sub_a+0
	movff	apnoe_max_pressure+1,sub_a+1
	movff	max_pressure+0,sub_b+0
	movff	max_pressure+1,sub_b+1
	call	subU16						; sub_c = sub_a - sub_b
										; apnoe_max_pressure<max_pressure -> neg_flag=1
										; max_pressure<=apnoe_max_pressure -> neg_flag=0
	btfss	neg_flag
	return
										;apnoe_max_pressure<max_pressure
	movff	max_pressure+0,apnoe_max_pressure+0
	movff	max_pressure+1,apnoe_max_pressure+1
	return

	; --------------------------------------------------------------------------------------

calc_deko_divemode:
	rcall	calc_deko_divemode2			; all deco relevant code is now invoked every second
	btfsc	twosecupdate
	bra		calc_deko_divemode1
	bsf		twosecupdate
	return

calc_deko_divemode1:					; the following code is invoked every 2 seconds
	bcf		twosecupdate

	call	calc_average_depth			; calculate average depth
	call	calc_velocity				; calculate vertical velocity and display if > threshold (every two seconds)
	call	set_reset_safety_stop		; Set flags for safety stop and/or reset safety stop
	call	TFT_debug_output

	btfsc	FLAG_apnoe_mode				; Done for Apnoe or Gauge mode
	return
	btfsc	FLAG_gauge_mode				; Done for Apnoe or Gauge mode
	return

; Check for a gas change
	goto	check_gas_change			; Checks if a better gas should be selected (by user) and return...


calc_deko_divemode2:
	btfsc	FLAG_gauge_mode				; Done for Apnoe or Gauge mode
	return

	btfsc	FLAG_ccr_mode				; In CCR mode?
	rcall	calc_deko_divemode_sensor	; do sensor data acquisition if applicable by OSTC model

	btfsc	FLAG_pscr_mode				; In PSCR mode?
	rcall	calc_deko_divemode_sensor	; do sensor data acquisition if applicable by OSTC model

	SAFE_2BYTE_COPY amb_pressure,int_I_pres_respiration ; transfer ambient pressure to deco engine


	; check deco engine state and switch between normal and alternative plan calculations
	;
	; Remark: Any reconfigurations done here do only affect the ascent & deco calculation settings,
	;		not the settings for the calculations done on the real tissues. The later ones are only
	;		altered in case of a gas change, or in case of a real bailout or switchback to setpoint
	;		or sensor, respectively.
	;		In case of a gas change or real bailout/switchback, the settings for the deco calculations
	;		are also changed to match the settings for the real tissues. This is done on signal through
	;		'divemode_gaschange' and will also leave the deco engine status in state as if having done
	;		the alternative plan last.

	; check state of ascent/deco calculations
	movff	char_O_deco_status,lo		; get a working copy of char_O_deco_status into bank common
	movlw	DECO_STATUS_MASK			; load bit mask covering the deco status bits
	andwf	lo,W						; mask out bits showing deco engine computations state
	tstfsz	WREG						; check if the last compute cycle has finished (bits 1 and 0 cleared)
	bra		calc_deko_divemode2e		; NO  - computations still in progress, needs more computation cycles
	btfss	lo,DECO_PLAN_FLAG			; YES - computation cycle finished, so check what has been computed
	bra		calc_deko_divemode2b		; PLAN bit is cleared i.e. normal plan was done, may do alternative next

	; The PLAN bit is set, i.e. an alternative plan was computed in the last cycle, or the deco engine has
	; been restarted because of a gas change etc. --> Reconfigure to normal plan for next computation cycle.

	; reset flags for special calculations
	bcf		lo,DECO_PLAN_FLAG			; clear flag for alternative plan
	bcf		lo,DECO_ASCENT_FLAG			; clear flag for delayed ascent calculation
	bcf		lo,DECO_VOLUME_FLAG			; clear flag for gas needs calculation
	movff	lo,char_O_deco_status		; write-back char_O_deco_status to deco engine interface

	; check if a switchback from CCR or pSCR bailout calculation is to be done
	btfsc	FLAG_ccr_mode				; may a switchback from a CCR bailout calculation be needed?
	bra		calc_deko_divemode2a		; in CCR  mode, so may need to switch back from bailout calculation
	btfsc	FLAG_pscr_mode				; may a switchback from a pSCR bailout calculation be needed?
	bra		calc_deko_divemode2a		; in pSCR mode, so may need to switch back from bailout calculation
	bra		calc_deko_divemode2e		; not in CCR nor pSCR, so no switchback needed, start normal plan now
										; (first cycle omits gas needs calculation in OC without delayed ascent)

	; switch back to loop calculation if last cycle was doing a bailout calculation
calc_deko_divemode2a:					
	movff	opt_calc_asc_gasvolume,hi	; get the gas volume needs calculation setting
	movf	hi,W						; are gas volume calculations turned on?
	bz		calc_deko_divemode2e		; NO  - can't have done a bailout calculation then, start normal plan
	btfsc	is_bailout					; YES - check if a real bailout situation is present
	bra		calc_deko_divemode2e		; YES - OC gases have been set by bailout action then, start normal plan
	movff	active_gas,WREG				; NO  - switch back to loop calculation: get current (diluent) gas, ...
	call	deco_setup_cc_diluents		;     ... set up deco calculations in CCR/pSCR mode with diluents,
	bra		calc_deko_divemode2e		;     ... and start in normal plan mode

	; The PLAN bit was cleared, i.e. a normal plan was computed in the last cycle. For the next
	; computation cycle the mode may be switched to alternative plan, or stay in normal mode...

calc_deko_divemode2b:
	bcf		lo,DECO_ASCENT_FLAG			; clear flag for delayed ascent calculation (for safety only)
	btfsc	is_bailout					; check if a real bailout situation is present
	bra		calc_deko_divemode2c		; YES - stay in normal plan mode and preclude delayed ascent calculation
	movff	char_I_extra_time,hi		; NO  -	get the delayed ascent setting
	tstfsz	hi							;       check if delayed ascent calculation is enabled
	bsf		lo,DECO_ASCENT_FLAG			;       YES - set flag for delayed ascent calculation
	tstfsz	hi							;       check if delayed ascent calculation is enabled (again)
	bsf		lo,DECO_PLAN_FLAG			;       YES - set flag for alternative plan

	; check if a gas needs calculation shall be done
calc_deko_divemode2c:					
	bsf		lo,DECO_VOLUME_FLAG			; set gas needs calculation flag (may be cleared again next)
	TSTOSS	opt_calc_asc_gasvolume		; check if gas needs calculation is enabled
	bcf		lo,DECO_VOLUME_FLAG			; NO  - reset flag again
	movff	lo,char_O_deco_status		; write-back char_O_deco_status to deco engine interface
	TSTOSS	opt_calc_asc_gasvolume		; check if gas volume calculation is enabled (again)
	bra		calc_deko_divemode2e		; NO  - no volume calculation, no simulated bailout plan in no case

	; check if conditions are met to calculate a bailout plan
	btfsc	is_bailout					; check if a real bailout situation is present
	bra		calc_deko_divemode2e		; YES - normal plan already does bailout (OC) calculation "for real"
	btfss	lo,DECO_MODE_LOOP_FLAG		; NO  - have loop mode calculation been done during the normal plan?
	bra		calc_deko_divemode2e		; NO  - when not in loop mode, no simulated bailout to be done
	bsf		lo,DECO_PLAN_FLAG			; YES - set flag for alternative plan
	movff	lo,char_O_deco_status		;       write-back char_O_deco_status to deco engine interface
	call	get_first_gas_to_WREG		;       get first OC gas, ...
	call	deco_setup_oc_gases			;       ... set up deco calculations in OC mode with OC gases,
	;bra	calc_deko_divemode2e		;       ... and start in alternative plan mode


calc_deko_divemode2e:
	clrf	TMR5L
	clrf	TMR5H						; 30,51757813µs/bit in TMR5L:TMR5H
	call	deco_calc_hauptroutine		; calc_tissue
	banksel	common

	; Check if deco stops are necessary
	movff	char_O_first_deco_depth,WREG; get ceiling
	tstfsz	WREG						; ceiling < 0m (aka in deco) ?
	bra		calc_deko_divemode3			; YES
	; NO - within NDL
	btfsc	decostop_active				; already in no deco mode ?
	bsf		FLAG_TFT_display_ndl_mask	; NO - clear deco data, display NDL time
	bsf		FLAG_TFT_display_ndl		; display NDL time
	bcf		decostop_active				; clear flag (again)
	return

calc_deko_divemode3:
	; YES - in deco
	btfss	decostop_active				; already in deco mode ?
	bsf		FLAG_TFT_display_deko_mask	; NO - clear NDL time, display deco data
	bsf		FLAG_TFT_display_deko		; display deco data
	bsf		FLAG_TFT_display_tts		; display TTS
	bsf		decostop_active				; set flag (again)
	return

	; --------------------------------------------------------------------------------------

	global	calc_deko_divemode_sensor
calc_deko_divemode_sensor:
	; sensor acquisition code
	btfss	s8_digital						 ; check if we have a digital interface to the sensors
	bra		calc_deko_divemode_sensor_analog ; NO  - check if we have an analog interface
	btfss	new_s8_data_available			 ; YES - check if a new data frame was received
	bra		calc_deko_divemode_sensor_common ; NO  - use old values -- TODO: add timeout for no new data
	call	compute_mvolts_for_all_sensors	 ; YES - compute mV values from digital data
	bra		calc_deko_divemode_sensor_common

calc_deko_divemode_sensor_opt:
	btfss	optical_input				; do we have an optical input?
	return						; No, return (We have no sensors at all. Not analog, not S8 and not optical)
	;o2_ppo2_sensor1, o2_ppo2_sensor2 and o2_ppo2_sensor3 are already filled in ISR
	;clear use_O2_sensorX for timeout case
	btfss	sensor1_active
	bcf	use_O2_sensor1
    	btfss	sensor2_active
	bcf	use_O2_sensor2
	btfss	sensor3_active
	bcf	use_O2_sensor3
	bra	calc_deko_divemode_sensor1
	
calc_deko_divemode_sensor_analog:
	btfss	analog_o2_input				; do we have an analog input?
	bra	calc_deko_divemode_sensor_opt		; NO  - check if we have an optical interface
	call	get_analog_inputs			; YES - get the analog voltages and continue with the common part

calc_deko_divemode_sensor_common:
	; Check for each sensor if it is calibrated and if its mv value is within min_mv and max_mv limits.
	; If     ok: compute o2_ppo2_sensorX := o2_mv_sensorX * opt_x_sX / 1000
	; If not ok: reset   o2_ppo2_sensorX, reset use_O2_sensorX and show the customview 1 in case the sensor was ok before

	; Check min_mv of sensor 1
	btfss	sensor1_calibrated_ok		; check if sensor is usable at all
	bra		check_sensor_1_fail			; NO  - handle it as failed
	movff	o2_mv_sensor1+0, sub_a+0	; load sensor mV value
	movff	o2_mv_sensor1+1, sub_a+1
	movlw	LOW  min_mv					; load minimum mV value
	movwf	sub_b+0
	movlw	HIGH min_mv
	movwf	sub_b+1
	call	sub16						; sub_c = sensor_mv - min_mv
	btfsc	neg_flag					; check if result is negative, i.e. sensor_mv < min_mv
	bra		check_sensor_1_fail			; YES - declare sensor as failed
	; Check max_mv of sensor 1			; NO  - continue with next check
	movff	o2_mv_sensor1+0, sub_a+0
	movff	o2_mv_sensor1+1, sub_a+1
	movlw	LOW  max_mv
	movwf	sub_b+0
	movlw	HIGH max_mv
	movwf	sub_b+1
	call	sub16						; sub_c = sensor_mv - max_mv
	btfss	neg_flag					; check if result is negative, i.e. sensor_mv < max_mv
	bra		check_sensor_1_fail			; NO  - declare sensor as failed
	; Check HUD data, if available		; YES - continue with next check
	btfss	hud_connection_ok			; check if there is a HUD connected
	bra		check_sensor_1_ok			; NO  - all checks done then and positive
	btfss	sensor1_active				; YES - check HUD report on sensor
	bra		check_sensor_1_fail			; HUD reports a fail

check_sensor_1_ok:
	; o2_ppo2_sensor1 := o2_mv_sensor1:2 * opt_x_s1:2 / 1000
	movff	o2_mv_sensor1+0,xA+0
	movff	o2_mv_sensor1+1,xA+1
	movff	opt_x_s1+0,xB+0
	movff	opt_x_s1+1,xB+1
	rcall	compute_ppo2_helper
	movff	xC+0,o2_ppo2_sensor1		; result in 0.01bar
	bra		check_sensor_2				; continue with next sensor

check_sensor_1_fail:
	clrf	WREG
	movff	WREG,o2_ppo2_sensor1		; set ppO2 reading to zero
	btfss	use_O2_sensor1				; check if sensor was in use before
	bra		check_sensor_1_fail_1		; NO  - no new news then
	call	check_sensor_custview_helper; YES - show customview 1 (sensor values) on further conditions met
check_sensor_1_fail_1:
	bcf		use_O2_sensor1				; revoke sensor from usage
	;bra	check_sensor_2				; continue with next sensor

check_sensor_2:							; Check min_mv of sensor 2
	btfss	sensor2_calibrated_ok		; check if sensor is usable at all
	bra		check_sensor_2_fail			; NO  - handle it as failed
	movff	o2_mv_sensor2+0, sub_a+0	; load sensor mV value
	movff	o2_mv_sensor2+1, sub_a+1
	movlw	LOW  min_mv					; load minimum mV value
	movwf	sub_b+0
	movlw	HIGH min_mv
	movwf	sub_b+1
	call	sub16						; sub_c = sensor_mv - min_mv
	btfsc	neg_flag					; check if result is negative, i.e. sensor_mv < min_mv
	bra		check_sensor_2_fail			; YES - declare sensor as failed
	; Check max_mv of sensor 2			; NO  - continue with next check
	movff	o2_mv_sensor2+0, sub_a+0
	movff	o2_mv_sensor2+1, sub_a+1
	movlw	LOW  max_mv
	movwf	sub_b+0
	movlw	HIGH max_mv
	movwf	sub_b+1
	call	sub16						; sub_c = sensor_mv - max_mv
	btfss	neg_flag					; check if result is nagative, i.e. sensor_mv < max_mv
	bra		check_sensor_2_fail			; NO  - declare sensor as failed
	; Check HUD data, if available		; YES - continue with next check
	btfss	hud_connection_ok			; check if there is a HUD connected
	bra		check_sensor_2_ok			; NO  - all checks done then and positive
	btfss	sensor2_active				; YES - check HUD report on sensor
	bra		check_sensor_2_fail			; HUD reports a fail

check_sensor_2_ok:
	; o2_ppo2_sensor2 := o2_mv_sensor2:2 * opt_x_s2:2 / 1000
	movff	o2_mv_sensor2+0,xA+0
	movff	o2_mv_sensor2+1,xA+1
	movff	opt_x_s2+0,xB+0
	movff	opt_x_s2+1,xB+1
	rcall	compute_ppo2_helper
	movff	xC+0,o2_ppo2_sensor2		; result in 0.01bar
	bra		check_sensor_3				; continue with next sensor

check_sensor_2_fail:
	clrf	WREG
	movff	WREG,o2_ppo2_sensor2		; set ppO2 reading to zero
	btfss	use_O2_sensor2				; check if sensor was in use before
	bra		check_sensor_2_fail_1		; NO  - no new news then
	call	check_sensor_custview_helper; YES - show customview 1 (sensor values) on further conditions met
check_sensor_2_fail_1:
	bcf		use_O2_sensor2				; revoke sensor from usage
	;bra	check_sensor_3				; continue with next sensor	

check_sensor_3:							; Check min_mv of sensor 2
	btfss	sensor3_calibrated_ok		; check if sensor is usable at all
	bra		check_sensor_3_fail			; NO  - handle it as failed
	movff	o2_mv_sensor3+0, sub_a+0	; load sensor mV value
	movff	o2_mv_sensor3+1, sub_a+1
	movlw	LOW  min_mv					; load minimum mV value
	movwf	sub_b+0
	movlw	HIGH min_mv
	movwf	sub_b+1
	call	sub16						; sub_c = sensor_mv - min_mv
	btfsc	neg_flag					; check if result is negative, i.e. sensor_mv < min_mv
	bra		check_sensor_3_fail			; YES - declare sensor as failed
	; Check max_mv of sensor 2			; NO  - continue with next check
	movff	o2_mv_sensor3+0, sub_a+0
	movff	o2_mv_sensor3+1, sub_a+1
	movlw	LOW  max_mv
	movwf	sub_b+0
	movlw	HIGH max_mv
	movwf	sub_b+1
	call	sub16						; sub_c = sensor_mv - max_mv
	btfss	neg_flag					; check if result is negative, i.e. sensor_mv < max_mv
	bra		check_sensor_3_fail			; NO  - declare sensor as failed
	; Check HUD data, if available		; YES - continue with next check
	btfss	hud_connection_ok			; check if there is a HUD connected
	bra		check_sensor_3_ok			; NO  - all checks done then and positive
	btfss	sensor3_active				; YES - check HUD report on sensor
	bra		check_sensor_3_fail			; HUD reports a fail

check_sensor_3_ok:
	; o2_ppo2_sensor3 := o2_mv_sensor3:2 * opt_x_s1:2 / 1000
	movff	o2_mv_sensor3+0,xA+0
	movff	o2_mv_sensor3+1,xA+1
	movff	opt_x_s3+0,xB+0
	movff	opt_x_s3+1,xB+1
	rcall	compute_ppo2_helper
	movff	xC+0,o2_ppo2_sensor3		; result in 0.01bar
	bra		calc_deko_divemode_sensor1	; continue with calculating sensor average

check_sensor_3_fail:
	clrf	WREG
	movff	WREG,o2_ppo2_sensor3		; set ppO2 reading to zero
	btfss	use_O2_sensor3				; check if sensor was in use before
	bra		check_sensor_3_fail_1		; NO  - no new news then
	call	check_sensor_custview_helper; YES - show customview 1 (sensor values) on further conditions met
check_sensor_3_fail_1:
	bcf		use_O2_sensor3				; revoke sensor from usage
	;bra	calc_deko_divemode_sensor1	; continue with calculating sensor average

calc_deko_divemode_sensor1:				; calculate sensor average
	; exit here if not in divemode
	btfss	divemode
	return

	; compute sensor_setpoint := average of all o2_ppo2_sensorX of those sensors that have use_O2_sensorX == true
	; sum up sensor values (in xA:2) and active sensors in (xB:2)
	clrf	xB+0
	clrf	xB+1
	clrf	xA+0
	clrf	xA+1
	btfss	use_O2_sensor1				; Sensor1 active?
	bra		divemode_setup_sensor_values2 ; No
	movf	o2_ppo2_sensor1,W
	addwf	xA+0
	movlw	.0
	addwfc	xA+1						; Add into xA:2
	incf	xB+0,F						; Add a sensor
divemode_setup_sensor_values2:
	btfss	use_O2_sensor2				; Sensor2 active?
	bra		divemode_setup_sensor_values3 ; No
	movf	o2_ppo2_sensor2,W
	addwf	xA+0
	movlw	.0
	addwfc	xA+1						; Add into xA:2
	incf	xB+0,F						; Add a sensor
divemode_setup_sensor_values3:
	btfss	use_O2_sensor3				; Sensor3 active?
	bra		divemode_setup_sensor_values4 ; No
	movf	o2_ppo2_sensor3,W
	addwf	xA+0
	movlw	.0
	addwfc	xA+1						; Add into xA:2
	incf	xB+0,F						; Add a sensor

	; Divide sum of sensor values by number of active sensors found.
divemode_setup_sensor_values4:
	call	div16x16					; xA/xB=xC with xA+0 as remainder
	movff	xC+0,sensor_setpoint		; copy result

	; set default value for pSCR mode: 0 = let p2_deco.c compute the ppO2 based on current dil gas and depth
	; will be overwritten later in case we are in sensor mode and have at least one usable sensor
	clrf	WREG						; preload a zero
	btfsc	FLAG_pscr_mode				; check if we are in pSCR mode
	movff	WREG,char_I_const_ppO2		; YES - write 0 to char_I_const_ppo2,
										;		it will be overwritten if we have a usable sensor reading

	btfsc	is_bailout					; check if we are in bailout
	bra		calc_deko_divemode_sensor2	; YES - no sensor data transfer to char_I_const_ppO2 in this case
	movff	opt_ccr_mode,WREG			; =0: Fixed SP, =1: Sensor, =2: Auto SP
	sublw	.1							; opt_ccr_mode = 1 (Sensor)?
	bnz		calc_deko_divemode_sensor2	; not in sensor mode - no transfer of sensor data to char_I_const_ppO2
	tstfsz	xB+0						; check if we have found at least one usable sensor
	bra		calc_deko_divemode_sensor1a	; YES - we have at least one usable sensor
	bsf		setpoint_fallback			; NO  - we have NO usable sensors -> initiate fallback
	btfss	FLAG_ccr_mode				; check if we are in CCR mode
	bra		calc_deko_divemode_sensor2	; NO  - continue with voting logic flags
	movff	char_I_setpoint_cbar+0,char_I_const_ppO2	; YES - select fixed setpoint no. 1 for fallback
	bra		calc_deko_divemode_sensor2	; done - continue with voting logic flags
calc_deko_divemode_sensor1a:			; we have at least one usable sensor with a value > 0
	bcf		setpoint_fallback			; clear fallback condition
	movff	sensor_setpoint,char_I_const_ppO2	; transfer average sensor value to p2_deco.c code
	;bra	calc_deko_divemode_sensor2

calc_deko_divemode_sensor2:
	bsf		voting_logic_sensor1
	movff	o2_ppo2_sensor1,lo
	rcall	check_sensor_voting_helper
	incfsz	WREG						; Was WREG = 255?
	bcf		voting_logic_sensor1		; No, ignore this sensor

	bsf		voting_logic_sensor2
	movff	o2_ppo2_sensor2,lo
	rcall	check_sensor_voting_helper
	incfsz	WREG						; Was WREG=255?
	bcf		voting_logic_sensor2		; No, ignore this sensor

	bsf		voting_logic_sensor3
	movff	o2_ppo2_sensor3,lo
	rcall	check_sensor_voting_helper
	incfsz	WREG						; Was WREG=255?
	bcf		voting_logic_sensor3		; No, ignore this sensor

	; check if a warning shall be issued on sensor disagreement

	btfsc	FLAG_ccr_mode				; check if we are in CCR mode
	bra		check_warn_sensor_1			; YES - continue with further checks
	btfsc	FLAG_pscr_mode				; check if we are in pSCR mode
	bra		check_warn_sensor_1			; YES - continue with further checks
	bra		check_warn_sensor_agree		; not in CCR and not in pSCR, so no warning
check_warn_sensor_1:					; we are in CCR or pSCR mode
	btfsc	is_bailout					; check if we are in bailout
	bra		check_warn_sensor_agree		; YES - no warning in this case
	movff	opt_ccr_mode,WREG			; =0: Fixed SP, =1: Sensor, =2: Auto SP
	sublw	.1							; opt_ccr_mode = 1 (Sensor)?
	bnz		check_warn_sensor_agree		; not in sensor mode - no warning in this case
										; check sensor 1
	btfss	sensor1_calibrated_ok		; check if sensor has a valid calibration
	bra		check_warn_sensor_2			; NO  - sensor can not cause a warning then
	btfss	use_O2_sensor1				; YES - check if sensor is in use
	bra		check_warn_sensor_2			; NO  - sensor can not cause a warning then
	btfsc	voting_logic_sensor1		; YES - check if sensor value is within agreement range
	bra		check_warn_sensor_2			; YES - continue with next sensor
	bcf		sensors_agree				; NO  - issue a warning
	return

check_warn_sensor_2:					; check sensor 2
	btfss	sensor2_calibrated_ok		; check if sensor has a valid calibration
	bra		check_warn_sensor_3			; NO  - sensor can not cause a warning then
	btfss	use_O2_sensor2				; YES - check if sensor is in use
	bra		check_warn_sensor_3			; NO  - sensor can not cause a warning then
	btfsc	voting_logic_sensor2		; YES - check if sensor value is within agreement range
	bra		check_warn_sensor_3			; YES - continue with next sensor
	bcf		sensors_agree				; NO  - issue a warning
	return

check_warn_sensor_3:					; check sensor 2
	btfss	sensor3_calibrated_ok		; check if sensor has a valid calibration
	bra		check_warn_sensor_agree		; NO  - sensor can not cause a warning then
	btfss	use_O2_sensor3				; YES - check if sensor is in use
	bra		check_warn_sensor_agree		; NO  - sensor can not cause a warning then
	btfsc	voting_logic_sensor3		; YES - check if sensor value is within agreement range
	bra		check_warn_sensor_agree		; YES - continue with next sensor
	bcf		sensors_agree				; NO  - issue a warning
	return

check_warn_sensor_agree:
	bsf		sensors_agree
	return

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
	setf	xC+0						; Yes.
	return

check_sensor_custview_helper:
	btfss	divemode					; check if we are in divemode
	return								; NO  - not in dive mode, return
	movff	opt_ccr_mode,WREG			; =0: Fixed SP, =1: Sensor, =2: Auto SP
	sublw	.1							; opt_ccr_mode = 1 (Sensors)?
	bnz		check_sensor_helper_1		; NO  - not using the sensors in the moment
	clrf	menupos3					; YES - arm customview 1 (sensor values)
	bsf		toggle_customview			;       and request a customview toggle
check_sensor_helper_1:
	return


check_sensor_voting_helper:
	movf	lo,W
	cpfsgt	sensor_setpoint
	bra		check_sensor_voting_common2	; lo < sensor_setpoint
	; lo > sensor_setpoint
	movf	lo,W
	subwf	sensor_setpoint,W
	movwf	lo
check_sensor_voting_common1:
	movlw	sensor_voting_logic_threshold ; Threshold in 0.01 bar
	cpfsgt	lo
	retlw	.255						; Within range
	retlw	.0							; Out of range
check_sensor_voting_common2:
	; lo<sensor_setpoint
	movf	sensor_setpoint,W
	subwf	lo,F
	bra		check_sensor_voting_common1

;-----------------------------------------------------------------------------

divemodemode_togglegf:								; Toggle aGF/GF
	bcf		toggle_gf								; clear flag
	btg		use_agf									; toggle GF

	btfsc	use_agf									; switch to aGF?
	bra		divemodemode_togglegf_1					; YES - branch to using aGF
	movff	opt_GF_low,char_I_GF_Low_percentage		; NO  - use normal GF factors
	movff	opt_GF_high,char_I_GF_High_percentage	;
	bra		divemodemode_togglegf_2					;       continue with common part

divemodemode_togglegf_1:							; use alternative GF factors
	movff	opt_aGF_low,char_I_GF_Low_percentage
	movff	opt_aGF_high,char_I_GF_High_percentage

divemodemode_togglegf_2:
	call	TFT_gf_mask								; update customview mask to show which one is in use
													; the customview itself has been called from divemenu_tree before
	goto	restart_deco_engine						; ...and return


calc_velocity:									; called every two seconds
	btfsc	display_velocity
	bra		calc_velocity1						; Always update if already displayed
	btfss	divemode2
	return										; display velocity only if deeper then 1m (Not at the surface after the dive)
calc_velocity1:
	SAFE_2BYTE_COPY amb_pressure, sub_a
	movff	last_pressure_velocity+0,sub_b+0
	movff	last_pressure_velocity+1,sub_b+1
	movff	sub_a+0,last_pressure_velocity+0	; store old value for velocity
	movff	sub_a+1,last_pressure_velocity+1

	call	subU16								; sub_c = amb_pressure - last_pressure

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
	movwf	divB+0
	call	div16						; divided by 2^7 equals velocity in m/min

	movlw	d'99'
	cpfsgt	divA+0						; limit to 99m/min
	bra		calc_velocity3
	movwf	divA+0						; divA=99

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
	goto	TFT_display_velocity		; With divA+0 = m/min..., and return...


;=============================================================================

set_reset_safety_stop:					; Set flags for safety stop and/or reset safety stop
	TSTOSS	opt_enable_safetystop		; =1: A safety stop is shown
	bra		delete_safety_stop			; No, don't show safety stop

	btfsc	decostop_active				; Is a deco stop displayed?
	bra		delete_safety_stop			; Yes, don't show safety stop

	; Below "opt_safety_stop_reset"? Set flag and reset count-down timer
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
	bra		reset_safety_stop			; Below 10m, reset safety stop

	; Above "opt_safety_stop_end"? Clear flag.
	SAFE_2BYTE_COPY rel_pressure, lo
	call	adjust_depth_with_salinity	; computes salinity setting into lo:hi [mbar]
	movff	lo,sub_a+0
	movff	hi,sub_a+1
	movff	opt_safety_stop_end,WREG	; [cbar]
	mullw	.10							; mbar in PRODL:H
	movff	PRODL,sub_b+0
	movff	PRODH,sub_b+1
	call	subU16						; sub_c = sub_a - sub_b
	btfsc	neg_flag
	bra		delete_safety_stop			; Above 3m, remove safety stop

	; Above "opt_safety_stop_start"? Activate safety stop
	SAFE_2BYTE_COPY rel_pressure, lo
	call	adjust_depth_with_salinity	; computes salinity setting into lo:hi [mbar]
	movff	lo,sub_a+0
	movff	hi,sub_a+1
	movff	opt_safety_stop_start,WREG	; [cbar]
	mullw	.10							; mbar in PRODL:H
	movff	PRODL,sub_b+0
	movff	PRODH,sub_b+1
	call	subU16						; sub_c = sub_a - sub_b
	btfsc	neg_flag
	bra		acivate_safety_stop			; Above 5m, activate safety stop
	bra		reset_safety_stop2			; Pause safety stop

acivate_safety_stop:
	tstfsz	safety_stop_countdown		; Countdown at zero?
	bsf		show_safety_stop			; No, Set flag!
	return

delete_safety_stop:
	clrf	safety_stop_countdown		; reset timer
	bra		reset_safety_stop2			; Remove safety stop from display

reset_safety_stop:
	movff	opt_safety_stop_length,safety_stop_countdown ; reset timer
reset_safety_stop2:
	bcf		show_safety_stop			; Clear flag
	btfss	safety_stop_active			; Safety stop shown
	return								; No, don't delete it
	bcf		safety_stop_active			; Clear flag
	bsf		FLAG_TFT_clear_safety_stop	; Clear safety stop
	return


;=============================================================================

timeout_menuview:
	decfsz	timeout_counter2,F			; timeout for menuview
	return								; No timeout, return
	; Timeout, clear e.g. "Menu?"
	goto	menuview_toggle_reset		; "returns"

timeout_divemode_menu:
	decfsz	timeout_counter2,F			; timeout for divemode menu
	return

	global	timeout_divemode_menu2
timeout_divemode_menu2:					; Called from divemenu_tree.asm
	bcf		divemode_menu				; Timeout! Clear flag
	call	TFT_clear_divemode_menu		; Clear menu
	bsf		FLAG_TFT_active_gas_divemode; Redraw gas/setpoint/diluent
	bcf		blinking_better_gas			; Clear flag to have temperature updated once
	bsf		FLAG_TFT_temp_divemode		; Displays temperature
	call	TFT_draw_gassep_line		; Gas separator grid in spec mode only

	btfss	decostop_active				; In deco mode ?
	bra		timeout_divemode_menu_ndl	; No, show NDL again
	; Show deco
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
	btfsc	divemode_menu				; Divemode menu active?
	rcall	timeout_divemode_menu		; Yes, check the timeout for it...

	btfsc	menuview					; is a menuview shown?
	rcall	timeout_menuview			; Yes, check the timeout for it...

	btfss	realdive					; Dive longer then one minute
	return

	btfsc	FLAG_apnoe_mode				; In Apnoe mode?
	bra		timeout_divemode2			; Yes, use apnoe_timeout [min] for timeout

	ifndef __DEBUG
		btfsc	simulatormode_active	; In Simulator mode?
		bra		timeout_divemode3		; Yes, use simulator timeout
	endif

	bcf		divemode
	infsnz	timeout_counter1+0,F
	incf	timeout_counter1+1,F		; timeout is 16 bit counter

	movff	opt_diveTimeout,WREG		; in [min]
	mullw	.60
	movff	PRODL,sub_a+0
	movff	PRODH,sub_a+1				; in [s]

	movff	timeout_counter1+0,sub_b+0
	movff	timeout_counter1+1,sub_b+1
	call	subU16						; sub_c = sub_a - sub_b
	btfss	neg_flag					; Result negative?
	bsf		divemode					; No, set flag
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
	rcall	set_powersafe				; Battery low?
	call	customview_minute			; Do every-minute tasks for the custom view area
	bcf		oneminupdate

	btfss	simulatormode_active		; in simulator mode?
	return								; No
	; Yes, quite dive mode simulation after 21*256s=89min:36s
	movlw	.20
	cpfsgt	total_divetime_seconds+1	; Timeout?
	return								; No

	ifdef __DEBUG
		return							; No simulator timeout in debug mode
	endif

	bra		divemode_option1			; Yes, set to 0m and "return"

set_max_depth:
	movff	max_pressure+0,sub_a+0
	movff	max_pressure+1,sub_a+1
	SAFE_2BYTE_COPY rel_pressure, sub_b
	call	subU16						; sub_c = sub_a - sub_b
										; max_pressure<rel_pressure -> neg_flag=1
										; rel_pressure<=max_pressure -> neg_flag=0
	btfss	neg_flag
	return
										; max_pressure<rel_pressure
	movff	sub_b+0,max_pressure+0
	movff	sub_b+1,max_pressure+1
	bsf		FLAG_TFT_max_depth			; Set flag
	return

set_min_temp:
	movff	minimum_temperature+0,sub_a+0
	movff	minimum_temperature+1,sub_a+1
	SAFE_2BYTE_COPY temperature,sub_b
	call	sub16						; sub_c = sub_a - sub_b
										; minimum_temperature<T -> neg_flag=1
										; T<=minimum_temperature -> neg_flag=0
	btfsc	neg_flag
	return
	; minimum_temperature >= T
	movff	sub_b+0,minimum_temperature+0
	movff	sub_b+1,minimum_temperature+1
	return

	global	set_dive_modes
set_dive_modes:
	btfsc	high_altitude_mode			; In high altitude (Fly) mode?
	bra		set_dive_modes3				; Yes!

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

	btfsc	realdive					; Dive longer than one minute?
	clrf	timeout_counter1+0			; Yes, reset timeout counter +++

	bsf		divemode					; (Re-)Set divemode flag
	bsf		divemode2					; displayed divetime is running
	return

set_dive_modes2:
	bcf		divemode2					; Stop time
	btfss	realdive					; dive longer then one minute?
	bcf		divemode					; no -> this was no real dive
	return								; No, return


set_dive_modes3:						; High-altitude mode
	btfsc	realdive					; dive longer then one minute?
	bra		set_dive_modes0				; Yes -> this is a real dive -> Use start_dive_threshold or ascend

	movlw	LOW  high_altitude_dive_threshold
	movwf	sub_a+0
	movlw	HIGH high_altitude_dive_threshold
	movwf	sub_a+1
	bra		set_dive_modes1

set_powersafe:
	movlw	color_code_battery_low+1; [%]
	cpfslt	batt_percent
	return

	movlw	d'7'						; Type of Alarm (Battery Low)
	movwf	AlarmType					; Copy to Alarm Register
	bsf		event_occured				; set event flag
	movlw	.0
	movff	WREG,opt_brightness			; Set Brightness to ECO
	return								; return

calc_average_depth:
	btfsc	reset_average_depth			; Reset the Average depth?
	rcall	reset_average1				; Reset the resettable average depth

	; 1. Add new 2xdepth to the Sum of depths registers
	SAFE_2BYTE_COPY rel_pressure,xB		; Buffer...
	bcf		STATUS,C
	rlcf	xB+0,F
	rlcf	xB+1,F						; x2

	movf	xB+0,w
	addwf	average_depth_hold+0,F
	movf	xB+1,w
	addwfc	average_depth_hold+1,F
	movlw	d'0'
	addwfc	average_depth_hold+2,F
	addwfc	average_depth_hold+3,F		; Will work up to 9999mbar*60*60*24=863913600mbar

	; Do the same for the _total registers (Non-Resettable)
	movf	xB+0,w
	addwf	average_depth_hold_total+0,F
	movf	xB+1,w
	addwfc	average_depth_hold_total+1,F
	movlw	d'0'
	addwfc	average_depth_hold_total+2,F
	addwfc	average_depth_hold_total+3,F; Will work up to 9999mbar*60*60*24=863913600mbar

	; 2. Compute Average Depth on base of average_divesecs:2
	movff	average_divesecs+0,xB+0
	movff	average_divesecs+1,xB+1		; Copy
	movff	average_depth_hold+0,xC+0
	movff	average_depth_hold+1,xC+1
	movff	average_depth_hold+2,xC+2
	movff	average_depth_hold+3,xC+3

	call	div32x16					; xC:4 / xB:2 = xC+3:xC+2 with xC+1:xC+0 as remainder
	movff	xC+0,avg_rel_pressure+0
	movff	xC+1,avg_rel_pressure+1

	btfss	divemode2					; displayed divetime is running?
	return								; No (e.g. too shallow)

	; 3. Compute Total Average Depth on base of total_divetime_seconds:2
	movff	total_divetime_seconds+0,xB+0
	movff	total_divetime_seconds+1,xB+1	; Copy
	movff	average_depth_hold_total+0,xC+0
	movff	average_depth_hold_total+1,xC+1
	movff	average_depth_hold_total+2,xC+2
	movff	average_depth_hold_total+3,xC+3
	call	div32x16					; xC:4 / xB:2 = xC+3:xC+2 with xC+1:xC+0 as remainder
	movff	xC+0,avg_rel_pressure_total+0
	movff	xC+1,avg_rel_pressure_total+1
	return

reset_average1:
	clrf	average_depth_hold+0
	clrf	average_depth_hold+1
	clrf	average_depth_hold+2
	clrf	average_depth_hold+3		; Clear average depth register
	movlw	d'2'
	movwf	average_divesecs+0
	clrf	average_divesecs+1
	bcf		reset_average_depth			; Clear flag
	return

test_switches_divemode:					; checks switches in divemode
	btfsc	divemode_menu				; Divemode menu shown?
	bra		test_switches_divemode_menu	; Yes, use menu processor
	btfsc	switch_left
	;bra	test_switches_divemode2		; Enter button pressed, check if we need to do something
	goto	menuview_toggle				; Menu or Simulator tasks; and return...
	btfss	switch_right
	return								; No button press
	tstfsz	menupos2					; any option shown?
	bra		test_switches_divemode1		; Yes, do option tasks
	bsf		toggle_customview			; No, toggle custom view
	return

test_switches_divemode_menu:
	btfsc	switch_left
	bra		test_switches_divemode_menu2; Move cursor
	btfsc	switch_right
	bra		test_switches_divemode_menu3; Enter submenu or do something
	return								; No button press

test_switches_divemode_menu1:
	clrf	menupos1
test_switches_divemode_menu2:
	incf	menupos1,F
	incf	menupos4,W					; menupos4+1 -> WREG
	cpfslt	menupos1					; > menupos4 (Set in menu_processor.asm)?
	bra		test_switches_divemode_menu1; > Yes, set to 1
	call	TFT_divemode_menu_cursor	; Update the cursor
	bcf		switch_left
	movlw	divemode_menu_timeout		; Reload timeout
	movwf	timeout_counter2			; timeout for divemode menu
	return

test_switches_divemode_menu3:			; Enter submenu or do something
	bcf		switch_right
;	decf	menupos1,F					; menu_processor needs 0-5...
	goto	do_line_menu				; Warning! Trashes STKPTR and returns to diveloop_loop4:

test_switches_divemode1:
	bcf		switch_right
	movlw	divemode_menuview_timeout
	movwf	timeout_counter2			; Reload timeout
	movff	menupos2,WREG				; menupos2 holds number of customview/divemode menu function
	dcfsnz	WREG,F
	bra		divemode_option_gaschange	; Switch to the indicated "better gas"
	dcfsnz	WREG,F
	bra		divemode_option0			; Start/Setup Divemode menu
	dcfsnz	WREG,F
	bra		divemode_option1			; Quit Simulation?
	dcfsnz	WREG,F
	bra		divemode_option2			; Descent 1m
	dcfsnz	WREG,F
	bra		divemode_option3			; Ascend 1m
	dcfsnz	WREG,F
	bra		divemode_option4			; Quit Apnoe mode
	dcfsnz	WREG,F
	bra		divemode_option5			; Reset Stopwatch (In Gauge mode)
	dcfsnz	WREG,F
	bra		divemode_option6			; +5mins simulation
	dcfsnz	WREG,F
	bra		divemode_option7			; Store heading
	dcfsnz	WREG,F
	bra		divemode_option8			; Switch to alt. layout
	return

gas_switched_common:
	bcf		divemode_gaschange			; Clear flag
	btfss	FLAG_back_to_loop			; check if it is a switchback from OC bailout to loop
	bra		gas_switched_common0		; NO  - continue with checking if selected gas is valid
	bcf		FLAG_back_to_loop			; YES - clear flag
	movff	active_diluent,menupos1		;       reload last diluent
	bra		gas_switched_common1		;       continue with common part
gas_switched_common0:
	tstfsz	menupos1					; menupos1=0?
	bra		gas_switched_common1		; NO  - valid gas
	return								; YES - something went wrong, invalid gas, abort
gas_switched_common1:
	movf	menupos1,W					; get selected gas into WREG (1-6)

	btfsc	FLAG_ccr_mode				; in CCR mode?
	bra		gas_switched_common2		; YES - configure diluent or bailout
	btfsc	FLAG_pscr_mode				; in pSCR mode?
	bra		gas_switched_common2		; YES - configure diluent or bailout

	; OC
	rcall	setup_gas_registers			; With WREG = Gas 1-6
	rcall	deco_setup_oc_gases			; With WREG = Gas 1-6
	bra		gas_switched_common3

	; loop or bailout
gas_switched_common2:
	rcall	setup_dil_registers			; With WREG = diluent 1-6, in case of is_bailout reverts to OC gases
	rcall	deco_setup_cc_diluents		; With WREG = diluent 1-6, in case of is_bailout reverts to OC gases

gas_switched_common3:
	bsf		FLAG_TFT_active_gas_divemode	; Redraw gas/setpoint/diluent
	call	restart_deco_engine_wo_ceiling	; abort any running deco calculations and restart the deco engine

	; Set flags for profile recording
	bsf		event_occured				; set event flag
	btfsc	is_bailout					; Choose OC Bailouts (OC Gases)
	bsf		bailoutgas_event			; Bailout gas change
	btfss	is_bailout					; Choose OC Bailouts (OC Gases)
	bsf		stored_gas_changed			; OC gas change
	return


; Code to pass all parameters to the C code

	global	get_first_gas_to_WREG
get_first_gas_to_WREG:					; Gets first gas (1-5) into WREG
	lfsr	FSR1,opt_gas_type			; Point to gas types
	clrf	lo							; start with Gas0
get_first_gas_to_WREG2:
	movf	lo,W
	movf	PLUSW1,W					; Get Type of Gas #lo
	sublw	.1							; it is = 1 (First Gas)
	bz		get_first_gas_to_WREG3		; Found the first gas!
	incf	lo,F						; ++
	movlw	NUM_GAS+1
	cpfseq	lo							; All done?
	bra		get_first_gas_to_WREG2		; Not yet
	; No first gas found, use #1
	movlw	.0
	movff	WREG,opt_gas_type+0			; Set Gas1 to First
	incf	WREG,W						; 0 -> 1
	return
get_first_gas_to_WREG3:
	movf	lo,W						; Put into Wreg
	incf	WREG,W						; 0-4 -> 1-5
	return								; Done

	global	get_first_dil_to_WREG
get_first_dil_to_WREG:					; Gets first dil (1-5) into WREG
	lfsr	FSR1,opt_dil_type			; Point to dil types
	clrf	lo							; start with Gas0
get_first_dil_to_WREG2:
	movf	lo,W
	movf	PLUSW1,W					; Get Type of Dil #lo
	sublw	.1							; it is = 1 (First Dil)
	bz		get_first_dil_to_WREG3		; Found the first dil!
	incf	lo,F						; ++
	movlw	NUM_GAS+1
	cpfseq	lo							; All done?
	bra		get_first_dil_to_WREG2		; Not yet
	; No first dil found, use #1
	movlw	.0
	movff	WREG,opt_dil_type+0			; Set Dil1 to First
	incf	WREG,W						; 0 -> 1
	return
get_first_dil_to_WREG3:
	movf	lo,W						; Put into Wreg
	incf	WREG,W						; 0-4 -> 1-5
	return								; Done

	global	deco_setup_oc_gases
deco_setup_oc_gases:					; with currently breathed gas in WREG (1-5 or 6)
	movff	WREG,char_I_current_gas		; gas to start with when doing the deco calculations

	banksel	opt_gas_type				; opt_gas_type[] and opt_OC_bail_gas_change[] are together in bank common2

	movff	opt_gas_He_ratio+0,char_I_deco_He_ratio+0
	movff	opt_gas_O2_ratio+0,char_I_deco_O2_ratio+0

	movlw	.3							; 3=Deco
	cpfseq	opt_gas_type+0				; Gas is deco type?
	clrf	opt_OC_bail_gas_change+0	; No, clear depth for 0=Disabled, 1=First and 2=Travel

	movff	opt_gas_He_ratio+1,char_I_deco_He_ratio+1
	movff	opt_gas_O2_ratio+1,char_I_deco_O2_ratio+1
	movlw	.3							; 3=Deco
	cpfseq	opt_gas_type+1				; Gas is deco type?
	clrf	opt_OC_bail_gas_change+1	; No, clear depth for 0=Disabled, 1=First and 2=Travel

	movff	opt_gas_He_ratio+2,char_I_deco_He_ratio+2
	movff	opt_gas_O2_ratio+2,char_I_deco_O2_ratio+2
	movlw	.3							; 3=Deco
	cpfseq	opt_gas_type+2				; Gas is deco type?
	clrf	opt_OC_bail_gas_change+2	; No, clear depth for 0=Disabled, 1=First and 2=Travel

	movff	opt_gas_He_ratio+3,char_I_deco_He_ratio+3
	movff	opt_gas_O2_ratio+3,char_I_deco_O2_ratio+3
	movlw	.3							; 3=Deco
	cpfseq	opt_gas_type+3				; Gas is deco type?
	clrf	opt_OC_bail_gas_change+3	; No, clear depth for 0=Disabled, 1=First and 2=Travel

	movff	opt_gas_He_ratio+4,char_I_deco_He_ratio+4
	movff	opt_gas_O2_ratio+4,char_I_deco_O2_ratio+4
	movlw	.3							; 3=Deco
	cpfseq	opt_gas_type+4				; Gas is deco type?
	clrf	opt_OC_bail_gas_change+4	; No, clear depth for 0=Disabled, 1=First and 2=Travel

	banksel common

	; Setup char_I_deco_gas_change array
	movff	opt_OC_bail_gas_change+0, char_I_deco_gas_change+0
	movff	opt_OC_bail_gas_change+1, char_I_deco_gas_change+1
	movff	opt_OC_bail_gas_change+2, char_I_deco_gas_change+2
	movff	opt_OC_bail_gas_change+3, char_I_deco_gas_change+3
	movff	opt_OC_bail_gas_change+4, char_I_deco_gas_change+4

	; switch to oc mode
	movff	char_O_deco_status,lo		; working copy of char_O_deco_status in bank common
	bcf		lo,DECO_MODE_PSCR_FLAG		; clear the pSCR-mode flag (may not be set, but never mind)
	bcf		lo,DECO_MODE_LOOP_FLAG		; clear the loop/CCR-mode flag
	movff	lo,char_O_deco_status		; bank safe write-back of char_O_deco_status

	return


	global	deco_setup_cc_diluents
deco_setup_cc_diluents:					; with currently breathed gas in WREG (1-5 or 6)
	btfsc	is_bailout					; check if in bailout condition
	bra		deco_setup_oc_gases			; revert to setting up OC gases in bailout condition

	movff	WREG,char_I_current_gas		; gas to start with when doing the deco calculations

	movff	opt_dil_He_ratio+0,char_I_deco_He_ratio+0
	movff	opt_dil_O2_ratio+0,char_I_deco_O2_ratio+0
	movff	opt_dil_type+0,WREG			; 0=Disabled, 1=First, 2=Normal
	tstfsz	WREG						; Disabled?
	bra		$+4							; No
	movff	WREG,char_I_dil_change+0	; Yes, clear char_I_deco_gas_change (Bank safe)

	movff	opt_dil_He_ratio+1,char_I_deco_He_ratio+1
	movff	opt_dil_O2_ratio+1,char_I_deco_O2_ratio+1
	movff	opt_dil_type+1,WREG			; 0=Disabled, 1=First, 2=Normal
	tstfsz	WREG						; Disabled?
	bra		$+4							; No
	movff	WREG,char_I_dil_change+1	; Yes, clear char_I_dil_change

	movff	opt_dil_He_ratio+2,char_I_deco_He_ratio+2
	movff	opt_dil_O2_ratio+2,char_I_deco_O2_ratio+2
	movff	opt_dil_type+2,WREG			; 0=Disabled, 1=First, 2=Normal
	tstfsz	WREG						; Disabled?
	bra		$+4							; No
	movff	WREG,char_I_dil_change+2	; Yes, clear char_I_dil_change

	movff	opt_dil_He_ratio+3,char_I_deco_He_ratio+3
	movff	opt_dil_O2_ratio+3,char_I_deco_O2_ratio+3
	movff	opt_dil_type+3,WREG			; 0=Disabled, 1=First, 2=Normal
	tstfsz	WREG						; Disabled?
	bra		$+4							; No
	movff	WREG,char_I_dil_change+3	; Yes, clear char_I_dil_change

	movff	opt_dil_He_ratio+4,char_I_deco_He_ratio+4
	movff	opt_dil_O2_ratio+4,char_I_deco_O2_ratio+4
	movff	opt_dil_type+4,WREG			; 0=Disabled, 1=First, 2=Normal
	tstfsz	WREG						; Disabled?
	bra		$+4							; No
	movff	WREG,char_I_dil_change+4	; Yes, clear char_I_dil_change

	; Setup char_I_deco_gas_change array
	movff	char_I_dil_change+0, char_I_deco_gas_change+0
	movff	char_I_dil_change+1, char_I_deco_gas_change+1
	movff	char_I_dil_change+2, char_I_deco_gas_change+2
	movff	char_I_dil_change+3, char_I_deco_gas_change+3
	movff	char_I_dil_change+4, char_I_deco_gas_change+4

	; switch to CCR / pSCR mode
	movff	char_O_deco_status,lo		; working copy of char_O_deco_status in bank common
	bsf		lo,DECO_MODE_LOOP_FLAG		; loop flag is set in both, CCR and pSCR mode
	bcf		lo,DECO_MODE_PSCR_FLAG		; clear pSCR mode flag by default
	btfsc	FLAG_pscr_mode				; check if we are in pSCR mode
	bsf		lo,DECO_MODE_PSCR_FLAG		; YES - set additional flag for pSCR mode
	movff	lo,char_O_deco_status		; bank safe write-back of char_O_deco_status	

	return

	global	setup_gas_registers
setup_gas_registers:					; with currently breathed gas in WREG (1-5 or 6)
	movwf	active_gas					; set as current gas
	movlw	.6
	cpfseq	active_gas					; gas = gas6 ?
	bra		setup_gas_registers_15		; NO - load gas 1-5
	movff	gas6_O2_ratio,char_I_O2_ratio ; copy gas6 O2 ratio to deco engine
	movff	gas6_He_ratio,char_I_He_ratio ; copy gas6 H2 ratio to deco engine	
	bra		setup_gas_registers_com		; continue with common part
setup_gas_registers_15:
	decf	active_gas,W				; 1-5 -> 0-4
	lfsr	FSR1,opt_gas_O2_ratio+0
	movff	PLUSW1,char_I_O2_ratio		; copy gas 1-5 O2 ratio to deco engine
	lfsr	FSR1,opt_gas_He_ratio+0
	movff	PLUSW1,char_I_He_ratio		; copy gas 1-5 He ratio to deco engine
setup_gas_registers_com:	
	;lfsr	FSR1,opt_gas_type			; commented out - currently not used anywhere
	;movff	PLUSW1,active_gas_type		; 0=Disabled, 1=First, 2=Travel, 3=Deco
	movff	char_O_main_status,lo		; working copy of char_O_main_status in bank common
	bcf		lo,DECO_MODE_PSCR_FLAG		; clear the pSCR-mode flag (may not be set, but never mind)
	bcf		lo,DECO_MODE_LOOP_FLAG		; clear the loop/CCR-mode flag
	movff	lo,char_O_main_status		; bank safe write-back of char_O_main_status
	movf	active_gas,W				; reload WREG with diluent 1-5 or 6 (important!)
	return

	global	setup_dil_registers
setup_dil_registers:					; with currently breathed gas in WREG (1-5 or 6)
	btfsc	is_bailout					; check if in bailout condition
	bra		setup_gas_registers			; revert to setting up OC gases in bailout condition
	movwf	active_gas					; set as current gas
	movff	WREG,active_diluent			; remember for when switching back from bailout to loop
	movlw	.6
	cpfseq	active_gas					; diluent = gas6 ?
	bra		setup_dil_registers_15		; NO - load diluent 1-5
	movff	gas6_O2_ratio,char_I_O2_ratio ; copy gas6 O2 ratio to deco engine
	movff	gas6_He_ratio,char_I_He_ratio ; copy gas6 H2 ratio to deco engine
	bra		setup_dil_registers_com		; continue with common part
setup_dil_registers_15:
	decf	active_gas,W				; 1-5 -> 0-4
	lfsr	FSR1,opt_dil_O2_ratio+0
	movff	PLUSW1,char_I_O2_ratio		; copy diluent 1-5 O2 ratio to deco engine
	lfsr	FSR1,opt_dil_He_ratio+0
	movff	PLUSW1,char_I_He_ratio		; copy diluent 1-5 He ratio to deco engine
setup_dil_registers_com:
	;lfsr	FSR1,opt_dil_type			; commented out - currently not used anywhere
	;movff	PLUSW1,active_gas_type		; 0=Disabled, 1=First, 2=Normal (there is no type 3 for diluents)
	movff	char_O_main_status,lo		; working copy of char_O_main_status in bank common
	bsf		lo,DECO_MODE_LOOP_FLAG		; loop flag is set in both, CCR and pSCR mode
	bcf		lo,DECO_MODE_PSCR_FLAG		; clear pSCR mode flag by default
	btfsc	FLAG_pscr_mode				; check if we are in pSCR mode
	bsf		lo,DECO_MODE_PSCR_FLAG		; YES - set additional flag for pSCR mode
	movff	lo,char_O_main_status		; bank safe write-back of char_O_main_status
	movf	active_gas,W				; reload WREG with diluent 1-5 or 6 (important!)
	return

divemode_option_gaschange:				; Switch to the better gas
	movff	better_gas_number,menupos1	; 1-5
	bsf		divemode_gaschange			; Change the gas in the dive mode loop...
	call	menuview_toggle_reset		; Reset to zero (Zero=no menuview)
	bcf		better_gas_available		; Clear flag immediately
	return

divemode_option0:						; Start/Setup Divemode menu
	call	TFT_clear_divemode_menu		; Clear menu area
	bcf		menuview
	call	do_main_divemenu

	global	divemode_option0_return
divemode_option0_return:
;	movlw	.1
;	movwf	menupos1					; Set to first option in divemode menu
	call	TFT_divemode_menu_cursor	; Show the cursor
	movlw	divemode_menu_timeout
	movwf	timeout_counter2			; timeout for divemode menu
	bsf		divemode_menu				; Set flag
	clrf	menupos2					; Clear option counter
	goto	diveloop_loop4				; Goto back to diveloop (menu processor trashes STKPTR!)

divemode_option4:
	movlw	d'58'						; two seconds left
	movwf	timeout_counter1+0
	movlw	apnoe_timeout-1				; apnoe timeout [min]
	movwf	apnoe_timeout_counter
	btfss	simulatormode_active		; in simulator mode?
	return								; No
divemode_option1:						; Quit simulation mode
	banksel	isr_backup
	movlw	LOW  .1000
	movwf	sim_pressure+0
	movlw	HIGH .1000
	movwf	sim_pressure+1				; Set to 0m -> End of Dive
	banksel	common
	call	menuview_toggle_reset		; Reset to zero (Zero=no menuview)

	btfss	FLAG_apnoe_mode				; In Apnoe mode?
	return								; No
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
	addwf	sim_pressure+0
	movlw	.0
	addwfc	sim_pressure+1
	rcall	divemode_simulator_check_limits
	banksel	common
	return

divemode_option5:
	call	menuview_toggle_reset		; Reset to zero (Zero=no menuview)
	bsf		reset_average_depth			; Set Flag
	return

divemode_option6:
	bcf		divemode2					; Stop divetime
	movlw	.5
	addwf	divemins+0,F
	movlw	.0
	addwfc	divemins+1,F				; Add 5 mins
	movlw	LOW  (.5*.60)
	addwf	average_divesecs+0,F
	movlw	HIGH (.5*.60)
	addwfc	average_divesecs+1,F		; Add 5*60 seconds
	movlw	LOW  (.5*.60)
	addwf	total_divetime_seconds+0,F
	movlw	HIGH (.5*.60)
	addwfc	total_divetime_seconds+1,F	; Add 5*60 seconds

	; 1. Add 300xdepth to the sum of depths registers
	SAFE_2BYTE_COPY rel_pressure, xB	; Buffer...
	movlw	LOW  (.5*.60)
	movwf	xA+0
	movlw	HIGH (.5*.60)
	movwf	xA+1
	call	mult16x16					; xA*xB=xC

	movf	xC+0,w
	addwf	average_depth_hold+0,F
	movf	xC+1,w
	addwfc	average_depth_hold+1,F
	movf	xC+2,w
	addwfc	average_depth_hold+2,F
	movf	xC+3,w
	addwfc	average_depth_hold+3,F		; Will work up to 9999mbar*60*60*24=863913600mbar

	; Do the same for the _total registers (Non-Resettable)
	movf	xC+0,w
	addwf	average_depth_hold_total+0,F
	movf	xC+1,w
	addwfc	average_depth_hold_total+1,F
	movf	xC+2,w
	addwfc	average_depth_hold_total+2,F
	movf	xC+3,w
	addwfc	average_depth_hold_total+3,F; Will work up to 9999mbar*60*60*24=863913600mbar

	movlw	.5							; + 5 minutes
	movff	WREG,char_I_sim_advance_time; copy to mailbox
	bsf		divemode2					; continue divetime
	call	restart_deco_engine
	goto	menuview_toggle_reset		; and return...

divemode_option7:
	; Store heading for compass view
	movff	compass_heading_shown+0,compass_bearing+0
	movff	compass_heading_shown+1,compass_bearing+1
	bsf		compass_bearing_set			; set flag
	goto	menuview_toggle_reset		; Done and return...
	
divemode_option8:
	bsf		alternative_divelayout		; Set flag for mode
	bsf		FLAG_TFT_divemode_mask_alt	; Set flag for mask
	movlw	.1
	movwf	menupos3					; For the customviews...
	call	TFT_ClearScreen				; Clear screen
	goto	menuview_toggle_reset		; Done and return...

divemode_simulator_check_limits:
	; Check limits (150m and 0m)
	movlw	LOW  d'16000'			; Compare to 16bar=16000mbar (150m).
	subwf	sim_pressure+0,W
	movlw	HIGH d'16000'
	subwfb	sim_pressure+1,W
	bnc		divemode_simulator_check_limits2 ; No-carry = borrow = not deeper

	; Too deep, limit to 150m
	movlw	LOW  d'16000'
	movwf	sim_pressure+0
	movlw	HIGH d'16000'
	movwf	sim_pressure+1
	return
divemode_simulator_check_limits2:
	movlw	LOW  d'1000'				; Compare to 1bar == 0m == 1000 mbar.
	subwf	sim_pressure+0,W
	movlw	HIGH d'1000'
	subwfb	sim_pressure+1,W
	btfsc	STATUS,C					; No-carry = borrow = not deeper.
	return								; Deeper than 0m == Ok.
	; Too shallow, limit to 0m
	movlw	LOW  d'1000'
	movwf	sim_pressure+0
	movlw	HIGH d'1000'
	movwf	sim_pressure+1
	return

;=============================================================================
; Compare all enabled gas in list, to see if a better one is available.
;
; Output: better_gas_available, better_gas_number
;
check_gas_change:						; Checks if a better gas should be selected (by user)
	bcf		better_gas_available		; =1: A better gas is available and a gas change is advised in divemode
	clrf	WREG
	movff	WREG,better_gas_number		; clear better gas register

	SAFE_2BYTE_COPY rel_pressure,xA
	movlw	d'100'
	movwf	xB+0
	clrf	xB+1
	call	div16x16					; compute depth in full m -> result in xC+0

	btfsc	FLAG_pscr_mode				; in PSCR mode?
	bra		check_gas_change2			; YES - check for diluents
	btfss	FLAG_ccr_mode				; in CCR mode?
	bra		check_gas_change_OC_bail	; NO - check for OC
check_gas_change2:
	btfsc	is_bailout					; in bailout?
	bra		check_gas_change_OC_bail	; YES - check for OC

	; Check Diluents
	movlw	.0
	rcall	check_dil_common			; With Gas 0-4 in WREG
	movlw	.1
	rcall	check_dil_common			; With Gas 0-4 in WREG
	movlw	.2
	rcall	check_dil_common			; With Gas 0-4 in WREG
	movlw	.3
	rcall	check_dil_common			; With Gas 0-4 in WREG
	movlw	.4
	rcall	check_dil_common			; With Gas 0-4 in WREG
	bra		check_gas_change_exit

check_gas_change_OC_bail:
	movlw	.0
	rcall	check_gas_common			; With Gas 0-4 in WREG
	movlw	.1
	rcall	check_gas_common			; With Gas 0-4 in WREG
	movlw	.2
	rcall	check_gas_common			; With Gas 0-4 in WREG
	movlw	.3
	rcall	check_gas_common			; With Gas 0-4 in WREG
	movlw	.4
	rcall	check_gas_common			; With Gas 0-4 in WREG
	;bra	check_gas_change_exit

check_gas_change_exit:
	bsf		FLAG_TFT_active_gas_divemode; redraw gas/setpoint/diluent
	btfss	better_gas_available		; is a better gas available?
	bcf		blinking_better_gas			; NO - clear blinking flag
	btfsc	better_gas_available		; is a better gas available?
	return								; YES
	clrf	WREG						; NO  - clear better_gas_number (for gaslist display)
	movff	WREG,better_gas_number
	return

check_gas_common:						; With Gas 0-4 in WREG
	btfsc	better_gas_available		; Better Gas already found?
	return								; Yes, return
	lfsr	FSR1,opt_gas_type			; 0=Disabled, 1=First, 2=Travel, 3=Deco
	btfss	PLUSW1,0					; Test for Bit0 and 1 -> type=3 -> Deco
	return								; No
	btfss	PLUSW1,1					; Test for Bit0 and 1 -> type=3 -> Deco
	return								; No
	incf	WREG,W						; 1-5
	cpfseq	active_gas					; is this gas current gas?
	bra		check_gas_common2			; No
	return								; Yes, skip test for active gas
check_gas_common2:
	decf	WREG,W						; 0-4
	movwf	hi							; Save tested gas 0-4
	lfsr	FSR1,opt_OC_bail_gas_change
	movff	PLUSW1,lo					; Change depth into lo
	movlw	minimum_change_depth
	cpfsgt	lo							; Change depth>minimum_change_depth?
	return								; No, Change depth not deep enough, skip!
	movf	xC+0,W						; load depth in m into WREG
	cpfsgt	lo							; gas_change_depth < current depth?
	bra		check_gas_common3			; No, check if we are within the better_gas_window_pos window
	incf	hi,W						; 1-5
	movff	WREG,better_gas_number		; number (1-5) of the "better gas" in divemode, =0: no better gas available
	movlw	better_gas_window_neg
	subwf	lo,W						; Change depth-better_gas_window_neg
	cpfslt	xC+0						; current depth<Change depth-better_gas_window_neg?
	bra		check_gas_common4			; Ok, now check the better gas ppO2<char_I_ppO2_max
	return
check_gas_common3:
	incf	hi,W						; 1-5
	movff	WREG,better_gas_number		; number (1-5) of the "better gas" in divemode, =0: no better gas available
	movlw	better_gas_window_pos
	addwf	lo,W						; Change depth+better_gas_window_pos
	cpfsgt	xC+0						; current depth>Change depth+better_gas_window_pos?
	bra		check_gas_common4			; Ok, now check the better gas ppO2<char_I_ppO2_max
	return
check_gas_common4:
	movf	hi,W						; gas 0-4 into WREG
	lfsr	FSR1,char_I_deco_O2_ratio	; load base address char_I_deco_O2_ratio array
	movff	PLUSW1,lo					; read O2 ratio from array into lo

	SAFE_2BYTE_COPY amb_pressure, xA
	movlw	d'10'
	movwf	xB+0
	clrf	xB+1
	call	div16x16					; xC=p_amb/10
	movff	xC+0,xA+0
	movff	xC+1,xA+1
	movff	lo,xB+0						; =O2 ratio
	clrf	xB+1
	call	mult16x16					; lo * p_amb/10

	; Check very high ppO2 manually
	tstfsz	xC+2						; char_I_O2_ratio * p_amb/10 > 65536, ppO2>6,55bar?
	return								; Done.
	; Check if ppO2>3,30bar
	btfsc	xC+1,7
	return								; Done.

	; Check for low ppo2
	movff	xC+0,sub_b+0
	movff	xC+1,sub_b+1
	movff	char_I_ppO2_min,WREG
	mullw	d'100'						; char_I_ppO2_min*100
	movff	PRODL,sub_a+0
	movff	PRODH,sub_a+1
	call	subU16						; sub_c = sub_a - sub_b
	btfss	neg_flag
	return								; Done (Too low).

	;check if we are within our warning thresholds!
	movff	xC+0,sub_a+0
	movff	xC+1,sub_a+1
	movff	char_I_ppO2_max_deco,WREG	; ppO2 max for MOD calculation and color coding in divemode
	addlw	.1							; e.g. >1.60
	mullw	d'100'						; char_I_ppO2_max*100
	movff	PRODL,sub_b+0
	movff	PRODH,sub_b+1
	call	subU16						; sub_c = sub_a - sub_b
	btfsc	neg_flag
	bsf		better_gas_available		;=1: A better gas is available and a gas change is advised in divemode
	return								; Done.


check_dil_common:						; With Dil 0-4 in WREG
	btfsc	better_gas_available		; Better Diluent already found?
	return								; Yes, return
	lfsr	FSR1,opt_dil_type			; 0=Disabled, 1=First, 2=Normal
	tstfsz	PLUSW1						; =0?
	bra		check_dil_common1			; No
	return								; Yes, skip inactive diluents for test
check_dil_common1:
	incf	WREG,W						; 1-5
	cpfseq	active_gas					; is this the current diluent?
	bra		check_dil_common2			; No
	return								; Yes, skip test for active diluent
check_dil_common2:
	decf	WREG,W						; 0-4
	movwf	hi							; Save tested diluent 0-4
	lfsr	FSR1,char_I_dil_change
	movff	PLUSW1,lo					; Change depth into lo
	movlw	minimum_change_depth
	cpfsgt	lo							; Change depth>minimum_change_depth?
	return								; No, Change depth not deep enough, skip!
	movf	xC+0,W						; load depth in m into WREG
	cpfsgt	lo							; gas_change_depth < current depth?
	return								; No, check next gas
	incf	hi,W						; 1-5
	movff	WREG,better_gas_number		; number (1-5) of the "better gas" in divemode, =0: no better gas available
	movlw	better_gas_window_neg
	subwf	lo,W						; Change depth-better_gas_window_neg
	cpfslt	xC+0						; current depth<Change depth-better_gas_window_neg?
	bsf		better_gas_available		;=1: A better gas is available and a gas change is advised in divemode
	return


;=============================================================================
; Check for Auto-SP
;
check_dive_autosp:						; Check for Auto-SP
	movff	opt_ccr_mode,WREG			; =0: Fixed SP, =1: Sensor, =2: Auto SP
	sublw	.2							; opt_ccr_mode = 2 (Auto SP)?
	bz		check_dive_autosp2			; Yes, check
	return								; No, return for Sensor or Fixed mode
check_dive_autosp2:
	SAFE_2BYTE_COPY rel_pressure,xA
	movlw	d'100'
	movwf	xB+0
	clrf	xB+1
	call	div16x16					; compute depth in full m -> result in xC+0
	; Check SP2
	btfsc	sp2_switched				; =1: This setpoint has been autoselected already
	bra		check_dive_autosp3			; Skip check
	movff	char_I_setpoint_change+1,lo	; Get depth in m
	tstfsz	lo							; =0?
	bra		check_dive_autosp2a			; No, continue
	bra		check_dive_autosp3			; Skip check
check_dive_autosp2a:
	decf	lo,W						; -1 -> WREG
	cpfsgt	xC+0						; Compare with depth
	bra		check_dive_autosp3			; lower depth, do not switch
	; auto switch to SP2
	movff	char_I_setpoint_cbar+1,char_I_const_ppO2	; Use SetPoint
	rcall	xmit_sp_set_flag
	bsf		sp2_switched				; Set flag
check_dive_autosp3:
	; Check SP3
	btfsc	sp3_switched				;=1: This setpoint has been autoselected already
	bra		check_dive_autosp4			; Skip check
	movff	char_I_setpoint_change+2,lo	; Get depth in m
	tstfsz	lo							; =0?
	bra		check_dive_autosp3a			; No, continue
	bra		check_dive_autosp4			; Skip check
check_dive_autosp3a:
	decf	lo,W						; -1 -> WREG
	cpfsgt	xC+0						; Compare with depth
	bra		check_dive_autosp4			; lower depth, do not switch
	; auto switch to SP3
	movff	char_I_setpoint_cbar+2,char_I_const_ppO2	; Use SetPoint
	rcall	xmit_sp_set_flag
	bsf		sp3_switched				; Set flag
check_dive_autosp4:
	; Check SP4
	btfsc	sp4_switched				;=1: This setpoint has been autoselected already
	bra		check_dive_autosp5			; Skip check
	movff	char_I_setpoint_change+3,lo ; Get depth in m
	tstfsz	lo							; =0?
	bra		check_dive_autosp4a			; No, continue
	bra		check_dive_autosp5			; Skip check
check_dive_autosp4a:
	decf	lo,W						; -1 -> WREG
	cpfsgt	xC+0						; Compare with depth
	bra		check_dive_autosp5			; lower depth, do not switch
	; auto switch to SP4
	movff	char_I_setpoint_cbar+3,char_I_const_ppO2 ; Use SetPoint
	rcall	xmit_sp_set_flag
	bsf		sp4_switched				; Set flag
check_dive_autosp5:
	; Check SP5
	btfsc	sp5_switched				;=1: This setpoint has been autoselected already
	bra		check_dive_autosp6			; Skip check
	movff	char_I_setpoint_change+4,lo	; Get depth in m
	tstfsz	lo							; =0?
	bra		check_dive_autosp5a			; No, continue
	bra		check_dive_autosp6			; Skip check
check_dive_autosp5a:
	decf	lo,W						; -1 -> WREG
	cpfsgt	xC+0						; Compare with depth
	bra		check_dive_autosp6			; lower depth, do not switch
	; auto switch to SP5
	movff	char_I_setpoint_cbar+4,char_I_const_ppO2 ; Use SetPoint
	rcall	xmit_sp_set_flag
	bsf		sp5_switched				; Set flag
check_dive_autosp6:
	return

xmit_sp_set_flag:
	movff	char_I_const_ppO2,WREG
	call	transmit_setpoint			; Transmit current setpoint from WREG (in cbar) to external electronics
	bsf		setpoint_changed			; Set flag (for profile)
	bsf		event_occured				; Set event flag
	return

set_logbook_marker:
	bcf		FLAG_set_marker				; clear flag
	movlw	d'6'						; set type of Alarm (manual marker)
	movwf	AlarmType					; copy to Alarm Register
	bsf		event_occured				; Set event flag
	return

;=============================================================================
; Setup everything to enter divemode.
;
dive_boot_oc:
	rcall	get_first_gas_to_WREG		; Gets first gas (1-5) into WREG
	rcall	setup_gas_registers			; set-up of gas parameters of currently breathed gas (with WREG = gas 1-5)
	rcall	deco_setup_oc_gases			; set-up of gas list for deco calculations (with WREG = gas 1-5)
	return

dive_boot_cc:
	bcf		is_bailout					; =1: Bailout
	bcf		setpoint_fallback			; =1: Fallback to SP1 due to external O2 sensor failure
	bcf		blinking_setpoint			; Reset blinking SP flag

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

	btfss	optical_input				; do we have an optical input?
	bra	dive_boot_cc_0				; No
	; Copy (initial) valid flags from HUD/ppO2 Monitor
	btfsc	sensor1_active
	bsf	use_O2_sensor1
    	btfsc	sensor2_active
	bsf	use_O2_sensor2
	btfsc	sensor3_active
	bsf	use_O2_sensor3

dive_boot_cc_0:
	; In pSCR mode, only settings 0 (calculated ppO2) and 1 (ppO2 from sensors) are defined.
	; In case we still have 3 (auto SP) selected out of previous ccr mode, we reset to 0.
	btfss	FLAG_pscr_mode
	bra		dive_boot_cc_1
	movff	opt_ccr_mode,WREG			; =0: Fixed SP (CCR) / calculated SP (pSCR), =1: Sensor, =2: Auto SP
	sublw	.2							; opt_ccr_mode = 1 (Auto SP)?
	bnz		dive_boot_cc_1
	movlw	.0
	movff	WREG,opt_ccr_mode

dive_boot_cc_1:
	bsf		setpoint_changed			; set flag (for profile)
	bcf		sp2_switched				; =1: This setpoint has been auto-selected already
	bcf		sp3_switched				; =1: This setpoint has been auto-selected already
	bcf		sp4_switched				; =1: This setpoint has been auto-selected already
	bcf		sp5_switched				; =1: This setpoint has been auto-selected already

	rcall	get_first_dil_to_WREG		; get first gas (1-5) into WREG
	rcall	setup_dil_registers			; set-up of gas parameters for currently breathed gas (with WREG = current gas 1-5)
	rcall	deco_setup_cc_diluents		; set-up of gas list for deco calculations (with WREG = current gas 1-5)

	; Start with SP1 (CCR) or 0 (pSCR) as default.
	; If in sensor mode, this value will be overwritten by calc_deko_divemode_sensor
	clrf	WREG						; preload WREG with setpoint value 0 for pSCR calculated
	btfss	FLAG_ccr_mode				; are we in CCR mode?
	bra		dive_boot_cc_2				; NO  - keep preloaded value
	movff	char_I_setpoint_cbar+0,WREG	; YES - get value of setpoint 1
dive_boot_cc_2:
	movff	WREG,char_I_const_ppO2		; write setpoint to deco engine
	call	transmit_setpoint			; transmit current setpoint from WREG (in cbar) to external electronics
	goto	calc_deko_divemode_sensor	; read & process sensor data (and return)

diveloop_boot:
	call	restart_set_modes_and_flags

	call	I2C_sleep_accelerometer		; stop accelerometer
	call	I2C_sleep_compass			; stop compass

	clrf	WREG
	movff	WREG,max_pressure+0			; clear some variables
	movff	WREG,max_pressure+1

	; init in invalid data state
	clrf	WREG						; set WREG to 0
	bsf		WREG,int_invalid_flag		; set invalid flag
	bsf		WREG,int_is_zero			; set zero flag
	movff	WREG,int_O_tank_pres_need+1	; Set flags for tank pressure needs = 0 before p2_deco.c
	movff	WREG,int_O_tank_pres_need+3	; can do it. If this is not done here and the gas needs
	movff	WREG,int_O_tank_pres_need+5	; custom view is shown before p2_deco.c completes the first
	movff	WREG,int_O_tank_pres_need+7	; deco calculation, some rubbish numbers from last dive of
	movff	WREG,int_O_tank_pres_need+9	; simulation may be shown

	; configure the deco engine:
	movff	char_O_deco_status,WREG		; bank-safe copy
	bsf		WREG,DECO_STATUS_0_FLAG		; configure init ...
	bsf		WREG,DECO_STATUS_1_FLAG		; ... state,
	bcf		WREG,DECO_PLAN_FLAG			; normal plan mode,
	bsf		WREG,DECO_CNS_FLAG			; enable CNS calculation (CNS at end of dive),
	bcf		WREG,DECO_VOLUME_FLAG		; disable gas volume calculation, and
	bcf		WREG,DECO_ASCENT_FLAG		; disable delayed ascent calculation
	movff	WREG,char_O_deco_status		; bank-safe copy back

	clrf	WREG
	movff	WREG,char_O_main_status		; reset char_O_main_status

	movlw	deco_distance
	movff	WREG,char_I_deco_distance
	movff	opt_last_stop,char_I_depth_last_deco
	movff	opt_GF_low,char_I_GF_Low_percentage
	movff	opt_GF_high,char_I_GF_High_percentage

	bcf		use_agf						; Start with normal GF set
	bcf		divemode_menu				; clear divemode menu flag

	bcf		alternative_divelayout		; Start with default layout

	bcf		blinking_depth_prev			; clear flag for blinking depth
	bcf		blinking_depth_warning		; clear flag for blinking depth
	bcf		blinking_depth_toggle		; clear flag for blinking depth

	movlw	d'1'
	movwf	apnoe_max_pressure+0
	clrf	apnoe_max_pressure+1
;	clrf	apnoe_surface_mins
;	clrf	apnoe_surface_secs
	clrf	apnoe_mins
	clrf	divemins+0
	clrf	divemins+1

	; Copy date and time for logbook
	movff	year,start_year
	movff	month,start_month
	movff	day,start_day
	movff	hours,start_hours
	movff	mins,start_mins

	movff	int_O_CNS_fraction+0,CNS_start+0 ; save CNS value at beginning of dive
	movff	int_O_CNS_fraction+1,WREG		 ; get high byte to WREG
	bcf		WREG,int_warning_flag			 ; clear warning flag bit
	movff	WREG,CNS_start+1				 ; move high byte on
	movff	int_O_gradient_factor+0,GF_start ; save GF value at beginning of dive (only lower byte used for value)

	bcf		no_more_divesecs				 ; =1: do no longer show seconds in divemode
	bcf		divemode_menu_active
	clrf	menupos1
	clrf	menupos2						 ; Reset to zero (Zero=no premenu or simulator task)
	bsf		sensors_agree					 ; init of sensors disagree warning system

	btfsc	FLAG_ccr_mode
	bra		diveloop_boot_cc
	btfsc	FLAG_pscr_mode
	bra		diveloop_boot_cc
	rcall	dive_boot_oc
	bra		diveloop_boot_cont

diveloop_boot_cc:
	rcall	dive_boot_cc

diveloop_boot_cont:
	; Copy opt_dil_types into backup (For "lost gas" feature)
	movff	opt_dil_type+0,opt_dil_type_backup+0					; 0=Disabled, 1=First, 2=Normal
	movff	opt_dil_type+1,opt_dil_type_backup+1					; 0=Disabled, 1=First, 2=Normal
	movff	opt_dil_type+2,opt_dil_type_backup+2					; 0=Disabled, 1=First, 2=Normal
	movff	opt_dil_type+3,opt_dil_type_backup+3					; 0=Disabled, 1=First, 2=Normal
	movff	opt_dil_type+4,opt_dil_type_backup+4					; 0=Disabled, 1=First, 2=Normal
	; Copy opt_gas_types into backup (For "lost gas" feature)
	movff	opt_gas_type+0,opt_gas_type_backup+0					; 0=Disabled, 1=First, 2=Travel, 3=Deco
	movff	opt_gas_type+1,opt_gas_type_backup+1					; 0=Disabled, 1=First, 2=Travel, 3=Deco
	movff	opt_gas_type+2,opt_gas_type_backup+2					; 0=Disabled, 1=First, 2=Travel, 3=Deco
	movff	opt_gas_type+3,opt_gas_type_backup+3					; 0=Disabled, 1=First, 2=Travel, 3=Deco
	movff	opt_gas_type+4,opt_gas_type_backup+4						; 0=Disabled, 1=First, 2=Travel, 3=Deco
	; Also copy change depths into backup (For "lost gas" feature)
	movff	char_I_dil_change+0,opt_dil_change_backup+0				; Gas change depths Diluents
	movff	char_I_dil_change+1,opt_dil_change_backup+1				; Gas change depths Diluents
	movff	char_I_dil_change+2,opt_dil_change_backup+2				; Gas change depths Diluents
	movff	char_I_dil_change+3,opt_dil_change_backup+3				; Gas change depths Diluents
	movff	char_I_dil_change+4,opt_dil_change_backup+4				; Gas change depths Diluents
	; Also copy change depths into backup (For "lost gas" feature)
	movff	opt_OC_bail_gas_change+0,opt_OC_bail_gas_change_backup+0; Gas change depths OC/Bailout
	movff	opt_OC_bail_gas_change+1,opt_OC_bail_gas_change_backup+1; Gas change depths OC/Bailout
	movff	opt_OC_bail_gas_change+2,opt_OC_bail_gas_change_backup+2; Gas change depths OC/Bailout
	movff	opt_OC_bail_gas_change+3,opt_OC_bail_gas_change_backup+3; Gas change depths OC/Bailout
	movff	opt_OC_bail_gas_change+4,opt_OC_bail_gas_change_backup+4; Gas change depths OC/Bailout

	clrf	WREG
	movff	WREG,better_gas_number		; clear better gas register

	bcf		show_safety_stop			; =1: Show the safety stop
	clrf	safety_stop_countdown		; Clear count-down

	clrf	samplesecs
	clrf	apnoe_timeout_counter		; timeout in minutes
	clrf	timeout_counter1+0			; takes care of the timeout (low  byte)
	clrf	timeout_counter1+1			; takes care of the timeout (high byte)
	clrf	AlarmType					; Clear all alarms
	bcf		event_occured				; clear flag
	clrf	average_depth_hold_total+0
	clrf	average_depth_hold_total+1
	clrf	average_depth_hold_total+2
	clrf	average_depth_hold_total+3	; Clear Non-Resettable Average
	rcall	reset_average1				; Reset the resettable average depth
	bcf		decostop_active
	bcf		better_gas_available		; =1: A better gas is available and a gas change is advised in divemode
	call	ghostwriter_short_header	; Write short header with divenumber into profile memory

	btfsc	simulatormode_active
	bra		diveloop_boot_1
	; Normal mode = Surface pressure is the pressure 30mn before dive.
	SAFE_2BYTE_COPY last_surfpressure_30min, int_I_pres_surface	;copy surfacepressure to deco routine
	SAFE_2BYTE_COPY last_surfpressure_30min, last_surfpressure	;copy surfacepressure to last_surfpressure for correct depth
	bra		diveloop_boot_2

diveloop_boot_1:
	; Simulator mode: Surface pressure is 1bar.
	movlw	LOW .1000
	movff	WREG,int_I_pres_surface+0	; LOW copy surface pressure to deco routine
	movlw	HIGH .1000
	movff	WREG,int_I_pres_surface+1	; HIGH copy surface pressure to deco routine

diveloop_boot_2:
	SAFE_2BYTE_COPY temperature,minimum_temperature ; Reset Min-Temp registers

	call	init_recording_params		; set up all the divisors

	bsf		ccr_diluent_setup			; For CCR mode (Required to have better gas working)
	btfsc	FLAG_ccr_mode				; =1: CCR mode (Fixed ppO2 or Sensor) active
	bra		divemode_boot2
	btfsc	FLAG_pscr_mode
	bra		divemode_boot2
	bcf		ccr_diluent_setup			; For OC mode (Required to have better gas working)

divemode_boot2:
	bcf		LEDg						; switch off green LED / release reset to RX circuitry
	bcf		LEDr						; switch off red LED
	bcf		realdive
	btfss	simulatormode_active		; do not disable in simulator mode!					
	call	disable_rs232				; Disable RS232
	btfsc	enable_screen_dumps			; =1: Ignore vin_usb, wait for "l" command (Screen dump)
	call	enable_rs232				; Also sets to speed_normal ...
	; Reset divetime seconds
	movlw	.2							; Start at 2seconds
	movwf	total_divetime_seconds+0
	clrf	total_divetime_seconds+1
	movwf	divesecs
	movwf	apnoe_secs
	bsf		divemode2					; displayed divetime is running (Divetime starts HERE)
	return								; Done with divemode boot


divemode_check_for_warnings:
	movlw	.1							; One warning at a time in alt. layout mode
	btfss	alternative_divelayout
	movlw	.2							; Two warnings at a time in default layout mode
	cpfsgt	warning_counter				; only one (or two) warnings active?
	bra		divemode_check_for_warnings1 ; Yes, update every second

	btfss	secs,0						; Every two seconds...
	return
	btfss	secs,1						; Every four seconds...
	return

divemode_check_for_warnings1:
	bcf		warning_active				; Clear flag
	clrf	warning_counter				; Clear counter

	; warnings sorted by severity, highest severity first

	; Warnings for all modes
	call	check_warn_battery			; Check if the battery level should be displayed/warned
	call	check_divetimeout			; Not actually a warning. Check and show the divemode timeout

	btfsc	FLAG_apnoe_mode				; Done for Apnoe or Gauge mode
	bra		divemode_check_for_warnings2
	btfsc	FLAG_gauge_mode				; Done for Apnoe or Gauge mode
	bra		divemode_check_for_warnings2

	; Warnings only in deco modes
	rcall	check_ppO2					; check ppO2 and displays warning, if required

	btfss	sensors_agree				; are the sensor values within the threshold range?
	rcall	check_warn_sensors_disagree	; NO  - further evaluate
	btfsc	sensors_agree				; are the sensor values within the threshold range?
	bcf		sensor_warning				; YES - revoke memorized sensor warning

	movff	char_O_deco_warnings,WREG	; bank-safe copy for deco warnings
	btfsc	WREG,outside_warning_lock	; are we outside of the ZH-L16 model?
	rcall	warn_outside				; YES

	rcall	check_IBCD					; check for IBCD attention or warning

	btfsc	decostop_active				; In deco mode?
	rcall	check_and_store_gf_violation; Yes, sets warnings, if required

	movff	char_O_deco_warnings,WREG	; bank-safe copy for deco warnings
	btfsc	WREG,mbubble_warning_lock	; do we have a microbubbles warning?
	rcall	warn_mbubbles				; YES

	rcall	check_cns_violation			; Check CNS value and display it, if required

	;btfsc	decostop_active				; In deco mode?
	rcall	check_gas_needs				; show gas needs warning if any gas need is > threshold

	rcall	check_eod_cns_violation		; Check CNS values for end-of-dive and display warning, if required

	call	TFT_display_ftts			; Show @+x time

	btfsc	use_agf						; In aGF mode?
	rcall	warn_agf					; Yes, show a warning for it

	btfsc	setpoint_fallback			; =1: Fallback to SP1 due to external O2 sensor failure
	rcall	warn_fallback				; Show the warning

divemode_check_for_warnings2:
; Display the warning icon?
	btfsc	warning_active				; Any warning active?
	bsf		FLAG_TFT_divemode_warning	; Yes
	btfss	warning_active				; Any warning active?
	bsf		FLAG_TFT_divemode_warning_clear ; No, clear warning icon

; Setup warning_page number
	incf	warning_page,F
	movf	warning_page,W
	bcf		STATUS,C
	btfss	alternative_divelayout
	rlcf	warning_page,W				; *2 (But only in standard layout mode)
	cpfsgt	warning_counter				; > warning_counter
	clrf	warning_page				; No, clear

; Clear both rows of warnings if there is nothing to show at all
	tstfsz	warning_counter				; any warnings?
	bra		divemode_check_for_warnings3 ; YES - look if second row needs to be cleared
	bsf		FLAG_TFT_dive_warning_text_clear ; Set flag
	return
divemode_check_for_warnings3:


; Clear 2nd row of warnings if there is nothing to show (on this page)
	btfss	second_row_warning			; =1: The second row contains a warning
	bsf		FLAG_TFT_dive_warning_text_clr2	; Set flag for 2nd row
	return								; Done.

	global	check_warn_battery
check_warn_battery:
	movff	batt_percent,lo
	movlw	battery_show_level+1
	cpfslt	lo
	return								; No Display, no warning
	; Display Battery, but warn?
	movff	batt_percent,lo
	movlw	color_code_battery_low+1
	cpfsgt	lo
	bsf		warning_active				; Set Warning flag

	movlw	.4
	cpfseq	menupos3					; battery shown in Custom View 4?
	bra		check_warn_battery2			; No
	return								; Yes, do not show twice (in custom view and in warning area)
check_warn_battery2:
	incf	warning_counter,F			; increase counter
	goto	TFT_update_batt_percent_divemode ; Show percent (And return)

check_divetimeout:
	btfsc	divemode2
	return								; displayed divetime is not running
	incf	warning_counter,F			; increase counter
	goto	TFT_divetimeout				; Show timeout counter (and return)


check_ppO2:
	btfsc	FLAG_ccr_mode				; are we in CCR mode?
	bra		check_ppO2_loop				; YES
	btfsc	FLAG_pscr_mode				; are we in pSCR mode?
	bra		check_ppO2_loop				; YES
	bra		check_ppO2_oc_1				; NO  - neither CCR nor pSCR
check_ppO2_loop:
	btfsc	is_bailout					; in bailout?
	bra		check_ppO2_oc_1				; YES - continue with OC
	movff	int_O_pure_ppO2+1,hi		; NO  - get upper part of int_O_pure_ppO2
	btfsc	hi,int_warning_flag			;       ppO2 of the pure diluent to low or high?
	rcall	check_ppo2_display				;       YES - show warning and return on next line
	btfsc	hi,int_attention_flag		;       ppO2 of the pure diluent close to setpoint?
	rcall	check_ppo2_display				;       YES - show warning and return on next line
	bra		check_ppO2_oc_2				;             skip attention threshold test on breathed ppO2
check_ppO2_oc_1:
	movff	int_O_breathed_ppO2+1,WREG	; get upper part of int_O_breathed_ppO2
	btfsc	WREG,int_attention_flag		; breathed ppO2 just above attention threshold?
	bra		check_ppo2_display			; YES - show ppO2
check_ppO2_oc_2:
	movff	int_O_breathed_ppO2+1,WREG	; get upper part of int_O_breathed_ppO2 (perhaps again)
	btfsc	WREG,int_low_flag			; breathed ppO2 to low?
	bra		check_ppO2_low				; YES - record the warning and show ppO2
	btfsc	WREG,int_high_flag			; breathed ppO2 to high?
	bra		check_ppO2_high				; YES - record the warning and show ppO2
	TSTOSS	opt_showppo2				; show ppO2 anyhow? (0 = no, 1 = show always)
	return								; NO  - no warnings, no show
	bra		check_ppo2_display			; YES - just show ppO2
check_ppO2_low:
	movlw	d'4'						; set type of alarm (ppO2 low)
	bra		check_ppO2_common			; continue with common part
check_ppO2_high:
	movlw	d'5'						; set type of alarm (ppO2 high)
check_ppO2_common:
	movwf	AlarmType					; copy alarm type to alarm register
	bsf		event_occured				; set event flag
	bsf		warning_active				; set warning flag
	btfsc	is_bailout					; are we in bailout?
	bra		check_ppo2_display			; YES - skip CCR/pSCR checks
	btfsc	FLAG_ccr_mode				; are we in CCR mode?
	return								; YES - no extra warning required
	btfsc	FLAG_pscr_mode				; are we in pSCR mode?
	return								; YES - no extra warning required
check_ppo2_display:						; display warning if ppO2 is not already shown in custom view
	movlw	.9
	cpfseq	menupos3					; ppO2 shown in Custom View 9?
	bra		check_ppO2_a				; No
	return								; Yes, do not show twice (in custom view and in warning area)
check_ppO2_a:
	movlw	.11
	cpfseq	menupos3					; ppO2 shown in Custom View 11?
	bra		check_ppO2_b				; No
	return								; Yes, do not show twice (in custom view and in warning area)
check_ppO2_b:
	movlw	.12
	cpfseq	menupos3					; ppO2 shown in Custom View 12?
	bra		check_ppO2_c				; No
	return								; Yes, do not show twice (in custom view and in warning area)
check_ppO2_c:
	movlw	.10
	cpfseq	menupos3					; ppO2 shown in Custom View 10?
	bra		check_ppO2_d				; No
	return								; Yes, do not show twice (in custom view and in warning area)
check_ppO2_d:
	incf	warning_counter,F			; increase counter
	goto	TFT_display_ppo2			; show breathed gas or diluent ppO2 warning (and return)


	global	check_cns_violation
check_cns_violation:
	; Check if CNS should be displayed
	movff	int_O_CNS_fraction+1,WREG	; get high byte
	btfsc	WREG,int_warning_flag		; warning flag set?
	bra		check_cns_violation2		; Yes - issue warning
	btfsc	WREG,int_attention_flag		; attention flag set?
	bra		display_cns_violation		; YES - just display CNS
	return								; No  - no display, no warning
check_cns_violation2:
	bsf		warning_active				; Set Warning flag
display_cns_violation:					; Show CNS if not shown in the custom view
	movlw	.11
	cpfseq	menupos3					; CNS shown in Custom View?
	bra		display_cns_violation2		; No
	return								; Yes, do not show twice (in custom view and in warning area)
display_cns_violation2:
	movlw	.8
	cpfseq	menupos3					; CNS shown through Custom View 8 right now?
	bra		display_cns_violation3		; No
	return								; Yes, do not show twice (in custom view and in warning area)
display_cns_violation3:
	incf	warning_counter,F			; increase counter
	goto	TFT_display_cns				; Show CNS (and return)


	global	check_eod_cns_violation		; check end-of-dive CNS values
check_eod_cns_violation:
	movff	int_O_CNS_fraction+1,WREG	; get high-byte of current CNS value
	btfsc	WREG,int_warning_flag		; current CNS value in warning state?
	return								; YES - inhibit eod warning if current CNS is already in warning
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
	bra		check_eod_cns_violation2	;       Yes - issue warning
	return								;       NO  - done with CNS checking
check_eod_cns_violation2:				; YES - issue warning
	bsf		warning_active				; set Warning flag
	movlw	.8							; issue textual warning if CNS values are not shown in the custom view right now
	cpfseq	menupos3					; CNS values shown through Custom View 8 right now?
	bra		display_eod_cns_violation	; NO  - issue textual warning
	return								; YES - do not show twice (in custom view and in warning area)
display_eod_cns_violation:
	incf	warning_counter,F			; increase counter
	goto	TFT_display_eod_cns			; issue CNS at end-of-dive warning (and return)


	global	check_and_store_gf_violation
check_and_store_gf_violation:
	movff	int_O_gradient_factor+1,WREG	; get upper byte of gradient factor
	btfss	WREG,int_warning_flag			; check if the warning flag is set
	bra		check_and_store_gf_violation2	; NO  - continue with checking for attention flag
	movlw	d'2'							; YES - set type of alarm
	movwf	AlarmType						;		copy to alarm register
	bsf		event_occured					;		set event   flag
	bsf		warning_active					;		set warning flag
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
	bsf		warning_active					; set Warning flag
	incf	warning_counter,F				; increase counter
	goto	TFT_warning_gf					; show GF (and return)
check_and_store_gf_violation4:				; check for deco info
	btfss	divemode						; in divemode?
	return									; NO  - done, return
	movff	char_O_deco_warnings,WREG		; YES - get the deco warnings vector
	btfss	WREG,deco_flag					;       check if the deco flag is set
	return									;       NO  - all done, return
	incf	warning_counter,F				;       YES - increase counter
	goto	TFT_info_deco					;             show deco info


warn_outside:
	incf	warning_counter,F			; increase counter
	bsf		warning_active				; Set Warning flag
	goto	TFT_warning_outside			; show outside warning (and return)


	global	warn_mbubbles
warn_mbubbles:
	incf	warning_counter,F			; increase counter
	bsf		warning_active				; Set Warning flag
	goto	TFT_warning_mbubbles		; show microbubbles warning (and return)
	
warn_agf:
	incf	warning_counter,F			; increase counter
	goto	TFT_warning_agf				; Show aGF warning (and return)

warn_fallback:
	incf	warning_counter,F			; increase counter
	bsf		warning_active				; Set Warning flag
	goto	TFT_warning_fallback		; Show fallback warning (and return)


check_gas_needs:
	banksel	int_O_tank_pres_need
	movf	int_O_tank_pres_need+1,w	; get               HIGH(pres need of 1st tank)
	iorwf	int_O_tank_pres_need+3,w	; inclusive or with HIGH(pres need of 2nd tank)
	iorwf	int_O_tank_pres_need+5,w	; inclusive or with HIGH(pres need of 3rd tank)
	iorwf	int_O_tank_pres_need+7,w	; inclusive or with HIGH(pres need of 4th tank)
	iorwf	int_O_tank_pres_need+9,w	; inclusive or with HIGH(pres need of 5th tank)
	banksel	common
	btfsc	WREG,int_invalid_flag		; check if invalid flag is set
	return								; YES - no further checking required
	btfsc	WREG,int_warning_flag		; NO  - check if any gas has a pres_need >= pres_fill
	bsf		warning_active				; YES - set warning flag
	btfsc	WREG,int_warning_flag		; NO  - check if any gas has a pres_need >= pres_fill
	goto	TFT_warning_gas_needs_warn	; Yes - show a warning
	btfsc	WREG,int_attention_flag		; NO  - check if any gas has a pres_need >= pres_fill * threshold
	goto	TFT_warning_gas_needs_att	; YES - show an attention
	bcf		gas_needs_attention			; NO  - clear flag for a new attention
	bcf		gas_needs_warning			;       clear flag for a new warning
	return


check_warn_sensors_disagree:
	incf	warning_counter,F			; increase counter
	bsf		warning_active				; YES - set Warning flag
	goto	TFT_warning_sensor_disagree	;       show sensor disagree warning (and return)


check_IBCD:
	TSTOSS	opt_enable_IBCD				; IBCD warning activated?
	return								; NO  - done
	movff	char_O_deco_warnings,WREG	; YES - get deco warnings vector
	btfss	WREG,IBCD_warning			;       IBCD warning flag set?
	return								;       NO  - return
	incf	warning_counter,F			;       YES - increase counter
	goto	TFT_warning_IBCD			;             write warning to display


	global	restart_deco_engine
	global	restart_deco_engine_wo_ceiling
restart_deco_engine:
	; make bank save copies and set flags for invalid data
	movff	int_O_ceiling+1,WREG
	bsf		WREG,char_invalid_flag		; int_O_ceiling has its invalid flag on a char's position!
	movff	WREG,int_O_ceiling+1

restart_deco_engine_wo_ceiling:
	; make more bank save copies and set more flags for invalid data
	movff	char_O_deco_gas+0,WREG
	bsf		WREG,char_invalid_flag
	movff	WREG,char_O_deco_gas+0

	movff	int_O_ascenttime+1,WREG
	bsf		WREG,int_invalid_flag
	movff	WREG,int_O_ascenttime+1

	movff	int_O_alternate_ascenttime+1,WREG
	bsf		WREG,int_invalid_flag
	movff	WREG,int_O_alternate_ascenttime+1

	movff	int_O_normal_CNS_fraction+1,WREG
	bsf		WREG,int_invalid_flag
	movff	WREG,int_O_normal_CNS_fraction+1

	movff	int_O_alternate_CNS_fraction+1,WREG
	bsf		WREG,int_invalid_flag
	movff	WREG,int_O_alternate_CNS_fraction+1

	movff	int_O_tank_pres_need+1,WREG
	bsf		WREG,int_invalid_flag
	movff	WREG,int_O_tank_pres_need+1

	; restart deco engine
	movff	char_O_deco_status,WREG		; get current deco engine configuration
	bcf		WREG,DECO_STATUS_0_FLAG		; set status flags to...
	bcf		WREG,DECO_STATUS_1_FLAG		; ... DECO_STATUS_START
	bsf		WREG,DECO_PLAN_FLAG			; fake we came from alternative plan to force normal plan to be done next
	movff	WREG,char_O_deco_status		; write back new configuration to restart deco computations

	return

;=============================================================================
; simulator mode
;

	global	do_demo_divemode
do_demo_divemode:
	call	option_save_all					; Save all settings into EEPROM before starting simulation
	call	deco_push_tissues_to_vault		; C-code: back-up status of the real tissues
	banksel	common							; Bank1

	; +++ COMMENTED OUT FOR TESTING PURPOSE ONLY !!! +++
	; +++ DO NOT COMMENT OUT IN OPERATIONAL USE  !!! +++
	;
	bsf		restore_deco_data			; Restore tissue and CNS after simulator use

	bcf		pressure_refresh
	btfss	pressure_refresh				; Wait for sensor
	bra		$-2

	bsf		simulatormode_active			; Set Flag
	; Compute dive ambient conditions
	banksel	char_I_bottom_depth
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
	banksel common							; Bank1

	bsf		divemode
	goto	diveloop						; Switch into Divemode!

	END