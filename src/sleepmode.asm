;=============================================================================
;
;   File sleepmode.asm                      * combined next generation V3.09.4n
;
;   Sleep Mode
;
;   Copyright (c) 2011, JD Gascuel, heinrichs weikamp gmbh, all right reserved.
;==============================================================================
; HISTORY
;  2011-08-12 : [mH] moving from OSTC code

#include "hwos.inc"							; Mandatory header
#include "shared_definitions.h"				; Mailbox from/to p2_deco.c
#include "surfmode.inc"
#include "tft.inc"
#include "start.inc"
#include "adc_lightsensor.inc"
#include "math.inc"
#include "ms5541.inc"
#include "eeprom_rs232.inc"
#include "external_flash.inc"
#include "ghostwriter.inc"
#include "i2c.inc"
#include "mcp.inc"
#include "wait.inc"
#include "tft_outputs.inc"


	extern	eeprom_deco_data_write
	extern	option_check_and_store_all


;---- Private local Variables -------------------------------------------------

	CBLOCK	local1						; max size is 16 Byte !!!
		accel_reference					; acceleration reference value for detecting movement / terminating deep sleep
		sm_timer_10sec					; timer for 10 seconds tasks (pressure check)
		sm_timer_10min					; timer for 10 minutes tasks (tissue updating)
		;sm_timer_15min					; timer for 15 minutes tasks (entering deep sleep)
		sm_10min_counter				; count #of 10 minutes
		loop_counter					; loop counter, used in init_avg_switches routine
		sm_flags						; local flags
	ENDC								; used: 6 byte, remaining: 10 byte


;---- Private local Flags -----------------------------------------------------

#DEFINE deep_sleep			sm_flags,0	; =1: in deep sleep mode,                      =0: normal sleep
#DEFINE desat_on_10_mins	sm_flags,1	; =1: calculate desaturation every 10 minutes, =0: every minute
#DEFINE	charge_in_sleep		sm_flags,2	; =1: show charging screen
;							sm_flags,3	; unused
;							sm_flags,4	; unused
;							sm_flags,5	; unused
;							sm_flags,6	; unused
;							sm_flags,7	; unused


;=============================================================================
slmode	CODE
;==============================================================================


;-----------------------------------------------------------------------------
; Entry Point for Sleep Mode
;
	global	sleeploop
sleeploop:
	clrf	STKPTR							; clear return addresses stack
	call	request_speed_normal			; request CPU speed switch to normal speed

	bcf		LEDg							; turn off green LED / release reset to RX circuitry
	bcf		LEDr							; turn off red   LED

 IFDEF _screendump
	bcf		screen_dump_avail				; disable screen dump function
 ENDIF

	bsf		sleepmode						; flag being in sleep mode
	bsf		block_sensor_interrupt			; suspend ISR from executing sensor interrupts

	bcf	    i2c_error_flag			; clear any I2C errors
	
	call	disable_ir_s8_analog			; power-down IR/S8/analog interface
	call	mcp_sleep						; power-down RX power supply

	clrf	ADCON0							; power-down ADC module
	call	disable_rs232					; power-down USB
	call	I2C_sleep_compass				; power-down compass

	call	eeprom_deco_data_write			; update deco data     in EEPROM
	call	eeprom_battery_gauge_write		; update battery gauge in EEPROM

	btfsc	option_changed					; do the options need to be stored to EEPROM ?
	call	option_check_and_store_all		; YES - check and store all option values in EEPROM

	call	ext_flash_enable_protection		; enable write protection on external flash

	clrf	sm_timer_10sec					; clear 10 seconds timer
	clrf	sm_timer_10min					; clear 10 minutes timer
	clrf	sm_10min_counter				; clear 10mins counter
	clrf	sm_flags						; clear all local  flags

	call	TFT_Display_FadeOut				; power-down backlight
	call	TFT_DisplayOff					; power-down display

sleeploop_loop:
	btfsc	trigger_full_second				; one second in sleep?
	rcall	one_sec_sleep					; YES - check switches, pressure sensor, etc.

	btfss	sleepmode						; shall terminate sleep mode?
	bra		sleeploop_exit					; YES

	rcall	sleepmode_sleep					; sleep for 62.5...125 ms

	btfss	deep_sleep						; shall enter deep sleep?
	bra		sleeploop_loop					; NO  - remain in normal sleep loop
	;bra	deepsleep_pre					; YES - enter     deep   sleep loop

deepsleep_pre:
	bcf		PIE1,TMR1IE						; disable timer 1 interrupt
	bcf		PIE2,TMR3IE						; disable timer 2 interrupt
	bcf		PIE5,TMR7IE						; disable timer 7 interrupt
	bcf		PIE5,TMR4IE						; disable timer 4 interrupt
	bcf		INTCON, INT0IE					; disable INT0    interrupt
	bcf		INTCON3,INT1IE					; disable INT1    interrupt

	bcf		power_sw1						; power-down switch 1
	bcf		power_sw2						; power-down switch 2

	rcall	deepsleep_get_accel				; read accelerometer into WREG
	movwf	accel_reference					; store as reference value
	tstfsz	accel_reference					; = 0 ?
	bra		deepsleep_loop					; NO  - continue
	bra		deepsleep_loop_exit				; YES - no deep sleep (fail-safe)

deepsleep_loop:
	btfsc	trigger_full_second				; one second in deep sleep?
	rcall	check_accelerometer				; YES - check accelerometer

	btfsc	trigger_full_second				; one second in deep sleep?
	rcall	one_sec_sleep					; YES - check switches, check pressure sensor, etc.

	rcall	sleepmode_sleep					; sleep for 62.5...125 ms

	btfss	sleepmode						; shall leave sleep mode?
	bcf		deep_sleep						; YES - leave deep sleep mode then, too

	btfsc	deep_sleep						; shall leave deep sleep mode?
	bra		deepsleep_loop					; NO - loop in deep sleep loop

deepsleep_loop_exit:
	bcf		deep_sleep						; clear flag (again)
	clrf	sm_10min_counter				; clear 10mins counter
	bsf		power_sw1			; switch on power supply for switch 1
	nop
	bsf		power_sw2			; switch on power supply for switch 2
	rcall	init_avg_switches				; initialize the averaging system

	bsf		PIE1,TMR1IE						; enable timer 1 interrupt
	bsf		PIE2,TMR3IE						; enable timer 2 interrupt
	bsf		PIE5,TMR7IE						; enable timer 7 interrupt
	bsf		PIE5,TMR4IE						; enable timer 4 interrupt
	bsf		INTCON, INT0IE					; enable INT0    interrupt
	bsf		INTCON3,INT1IE					; enable INT1    interrupt

	bra		sleeploop_loop					; enter normal sleep loop

sleeploop_exit:
	bcf		switch_left						; eventually clear left  button event
	bcf		switch_right					; eventually clear right button event
	movlw	.0								; reset ISR sensor state machine
	movff	WREG,sensor_state_counter		; ...
	bcf		PIR5,TMR7IF						; clear timer 7, driving the ISR sensor interrupts
	bcf		block_sensor_interrupt			; re-enable execution of the ISR sensor interrupts
	goto	restart							; restart


;-----------------------------------------------------------------------------
; Helper Function - Tasks every Second in Sleep Mode
;
one_sec_sleep:
	bcf		trigger_full_second				; clear trigger flag
	
	btfss	button_hold_down_allowed			; mechanical push buttons?
	bra	one_sec_sleep_piezo_buttons			; No
		
	btfss	switch_left					; left switch pressed?
	bra	one_sec_sleep_buttons_done			; no, done
	btfss	switch_right					; right switch pressed?
	bra	one_sec_sleep_buttons_done			; no, done
	bcf	sleepmode					; Both pressed, wake up
	bra	one_sec_sleep_buttons_done			; Done.

one_sec_sleep_piezo_buttons:	
	btfsc	switch_left					; left switch pressed?
	bcf	sleepmode					; YES - terminate sleep mode
	btfsc	switch_right					; right switch pressed?
	bcf	sleepmode					; YES - terminate sleep mode

one_sec_sleep_buttons_done:
    	bcf		switch_right				; clear right button event
	bcf		switch_left				; clear left  button event

	incf	sm_timer_10sec,F				; increment 10 seconds timer
	movlw	.10								; load  a 10 into WREG
	cpfslt	sm_timer_10sec					; timer < 10 yet?
	rcall	ten_sec_sleep					; NO - do the every 10 second tasks

	btfsc	trigger_full_minute				; one minute in sleep?
	rcall	one_min_sleep					; YES - do the every minute tasks

	btfsc	trigger_full_hour				; one hour in sleep?
	rcall	one_hour_sleep					; YES - do the every hour tasks

	return	; done.


	
;-----------------------------------------------------------------------------
; Helper Function - Tasks every 10 Seconds in Sleep Mode
;
ten_sec_sleep:
	; tasks every 10 seconds in sleep mode
	clrf	sm_timer_10sec					; clear timer

	btfsc	battery_gauge_available			; is a battery gauge IC available?
	bra		ten_sec_sleep_1					; YES - check for charger
	btfsc	ble_available				; Skip "USB" check in all Bluetooth models (Required for very old OSTC sport)
	bra		ten_sec_sleep_2					;     - continue
	btfsc	vusb_in							; NO  - USB plugged in?
	bcf		sleepmode						;       YES - terminate sleep mode
	bra		ten_sec_sleep_2					;     - continue

ten_sec_sleep_1:
	call	get_battery_voltage				; check for charger

	; Test if charging
	btfss	cc_active						; charging?
	bra		ten_sec_sleep_1a				; NO
	btfsc	charge_in_sleep					; YES - already showing charge screen?
	bra		ten_sec_sleep_1b				;       YES - only update data

	bsf		charge_in_sleep
	bcf		deep_sleep						; wake-up from deepsleep
	call	TFT_boot						; initialize TFT (includes clear screen)
	movlw	.32
	movff	WREG,max_CCPR1L					; bank safe
	call	TFT_Display_FadeIn				; dim up the display
ten_sec_sleep_1b:
	call	TFT_surfmode_batt				; show battery type, voltage and color-coded percentage
	bra		ten_sec_sleep_2					; continue

ten_sec_sleep_1a:
	btfss	charge_in_sleep					; was showing charge screen?
	bra		ten_sec_sleep_2					; NO

	; yes, power-down screen    
	call	TFT_Display_FadeOut				; power-down backlight
	call	TFT_DisplayOff					; power-down display
	bcf		charge_in_sleep


ten_sec_sleep_2:

	rcall	pressuretest_sleep_fast			; get pressure without averaging (faster)
	MOVLI	wake_up_from_sleep,sub_a		; load wake-up pressure (1160 mbar) into sub_a
	MOVII	pressure_abs,      sub_b		; load current absolute pressure    into sub_b
	call	cmpU16							; sub_a - sub_b = wake-up pressure - current absolute pressure
	btfsc	neg_flag						; is the current absolute pressure > 1160 mbar ?
	bcf		sleepmode						; YES - terminate sleep mode
	return									; done


;-----------------------------------------------------------------------------
; Helper Function - Tasks every Minute in Sleep Mode
;
one_min_sleep:
	; tasks every minute in sleep mode
	bcf		trigger_full_minute				; clear flag

	; tick the 10 minutes timer
	incf	sm_timer_10min,F				; increment 10 minutes timer
	movlw	.10								; load  a 10 into WREG
	cpfslt	sm_timer_10min					; timer < 10 yet?
	rcall	ten_min_sleep					; NO - do the every 10 minutes tasks

one_min_sleep_1:
	; continue tasks every minute
	btfsc	desat_on_10_mins				; shall do desaturation calculation on 10 minute intervals?
	return									; YES - that's not here then, so done
	call	deco_calc_dive_interval_1min	; NO  - calculate 1 minute at surface conditions (C-code)
	banksel	common							;     - back to bank common
	return									;     - done


;-----------------------------------------------------------------------------
; Helper Function - Tasks every 10 Minutes in Sleep Mode
;
ten_min_sleep:
	; tasks every 10 minutes in sleep mode
	clrf	sm_timer_10min					; reset timer to 0

	call	sample_surface_pressure			; sample surface pressure and update ISR and deco engine

	btfss	analog_switches					; OSTC with analog switches?
	bra		ten_min_sleep_0					; NO  - no analog switches, no deep sleep required

	; check if we need to enter deep sleep
	incf	sm_10min_counter,F				; count
	movlw	deep_sleep_10mins				; threshold
	cpfseq	sm_10min_counter				; threshold reached?
	bra		ten_min_sleep_0					; NO - threshold not reached yet

	decf	sm_10min_counter,F				; -1 to re-trigger every 10mins (in case of charging)

	btfss	cc_active						; charging?
	bsf		deep_sleep						; NO - activate deep-sleep mode

ten_min_sleep_0:
	btfss	desat_on_10_mins				; shall do desaturation calculation on 10 minute intervals?
	bra		ten_min_sleep_1					; NO  - continue checking if schedule can be switched to 10 minutes
	call	deco_calc_dive_interval_10min	; YES - calculate 10 minutes at surface conditions (C-code)
	banksel	common							;     - back to bank common
	return									;     - done

ten_min_sleep_1:
	movff	int_O_lead_supersat+0,WREG		; get leading tissue's supersaturation (only the lower byte is used for the value)
	bsf		desat_on_10_mins				; switch to 10 minute intervals by default
	tstfsz	WREG							; gradient factor = 0 ?
	bcf		desat_on_10_mins				; NO - stay on 1 minute intervals
	return									; done


;-----------------------------------------------------------------------------
; Helper Function - Tasks every Hour in Sleep Mode
;
one_hour_sleep:
	; tasks every hour in sleep mode mode
	bcf		trigger_full_hour				; clear one hour flag
	call	eeprom_deco_data_write			; update deco data     into EEPROM
	call	eeprom_battery_gauge_write		; update battery gauge into EEPROM
	return									; done


;-----------------------------------------------------------------------------
; Helper Function - Initialization of the Button Event Averaging System
;
init_avg_switches:
	; pause 4 seconds using CPU sleep mode to conserve on battery
	movlw	.4								; time to pause
	movwf	loop_counter					; initialize loop counter
	bcf		trigger_full_second				; clear 'one second elapsed' flag
activate_switches_1:
	rcall	sleepmode_sleep					; sleep for 62.5...125 ms
	btfss	trigger_full_second				; did 1 second elapsed meanwhile?
	bra		activate_switches_1				; NO  - loop
	bcf		trigger_full_second				; YES - clear flag
	decfsz	loop_counter,F					;     - decrement loop counter, done?
	bra		activate_switches_1				;       NO  - loop

	; initialize the averaging system
	movlw	.32								; number of readout cycles
	movwf	loop_counter					; initialize loop counter
activate_switches_2:
	call	get_analog_switches				; do a analog switch readout
	decfsz	loop_counter,F					; decrement loop counter, done?
	bra		activate_switches_2				; NO  - loop

	; clear all button events that may have intermediately occurred
	bcf		PIR1,TMR1IF						; clear button-hold-down timer
	bcf		INTCON, INT0IF					; clear right button activity
	bcf		INTCON3,INT1IF					; clear left  button activity
	bcf		analog_sw1_pressed				; clear analog switch 1 activity
	bcf		analog_sw2_pressed				; clear analog switch 2 activity
	bcf		switch_right					; clear right button event
	bcf		switch_left						; clear left  button event

	return									; done


;-----------------------------------------------------------------------------
; Helper Function - Check for Change in Accelerometer Z-Axis
;
check_accelerometer:
	rcall	deepsleep_get_accel				; read accelerometer into WREG
	subwf	accel_reference,W				; reference value - accel_DZ+0 -> WREG
	btfsc	STATUS,N						; result negative?
	negf	WREG							; YES - negate it
	movwf	lo								; save as change of acceleration in Z-axis
	movlw	.100							; load threshold (mg)
	cpfslt	lo								; change of acceleration > threshold ?
	bcf		deep_sleep						; YES - terminate deep sleep mode
	return									; done


;-----------------------------------------------------------------------------
; Helper Function - read Accelerometer Z-Axis
;
deepsleep_get_accel:
	call	I2C_init_compass				; start compass
	btfss	compass_present
	bcf	deep_sleep				; No Compass - terminate deep sleep mode
	rcall	sleepmode_sleep					; sleep for 62.5...125 ms
	call	I2C_RX_accelerometer			; read accelerometer
	call	I2C_RX_accelerometer			; read accelerometer
	call	I2C_sleep_compass				; shut down compass
	movff	accel_DZ+0,WREG					; transfer result to WREG
	return									; done


;-----------------------------------------------------------------------------
; Helper Function - read Pressure without Averaging
;
; faster method to save some power in sleep mode
;
pressuretest_sleep_fast:
    	; sleepmode pressure sampling for new sensor is done here
	btfss	press_sensor_type				; New sensor found?
	bra	pressuretest_sleep_fast2			; No

	btfsc	ms5837_state					; =0: result of temperature is in the ADC
	bra	pressuretest_sleep_fast1			; was =1 -> Read pressure from MS5837. ms5837_state will always be zero here from now on
	call	I2C_get_temp_val_MS5837				; (Will set ms5837_state)
	rcall	sleepmode_sleep					; sleep for 62.5...125 ms
	rcall	sleepmode_sleep					; sleep for 62.5...125 ms
pressuretest_sleep_fast1:	
	call	I2C_get_press_val_MS5837			; (Will clear ms5837_state)
	rcall	sleepmode_sleep					; sleep for 62.5...125 ms
	rcall	sleepmode_sleep					; sleep for 62.5...125 ms

pressuretest_sleep_fast2:
	banksel	isr_backup						; select bank ISR data

	clrf	pressure_abs_avg+0				; clear pressure    average register
	clrf	pressure_abs_avg+1
	clrf	pressure_abs_avg+2
	
	CLRI	temperature_avg					; clear temperature average register

	call	get_temperature_start			; start temperature integration (73.5 us)

	rcall	sleepmode_sleep					; sleep for 62.5...125 ms
	rcall	sleepmode_sleep					; sleep for 62.5...125 ms

	call	get_temperature_value				; get temperature... (May return in bank common)
	banksel	isr_backup						; select bank ISR data
	call	get_pressure_start				; start pressure integration

	rcall	sleepmode_sleep					; sleep for 62.5...125 ms
	rcall	sleepmode_sleep					; sleep for 62.5...125 ms

	call	get_pressure_value				; state2: get pressure (51 us)(May return in bank common)
	banksel	isr_backup						; select bank ISR data
	call	calculate_compensation			; calculate temperature compensated pressure (27 us)

	MOVII	pressure_abs_avg,pressure_abs	; get result, bypassing the averaging
	MOVII	pressure_abs_avg,pressure_abs_last
	MOVII	temperature_avg,temperature_cur
	MOVII	temperature_avg,temperature_last
	banksel	common							; back to bank common
	return


;-----------------------------------------------------------------------------
; Helper Function - sleep for 62.5...125 ms
;
sleepmode_sleep:
	movff	BSR,BSR_backup					; backup current bank selection
	banksel	common							; switch to bank common
	btfsc	charge_in_sleep					; already showing charge screen?
	bra		sleepmode_sleepwalk				; YES - skip the actual sleep (but wait)
	sleep									; NO  - put CPU into sleep (wakes up by timer 7 IRQ)
	sleep									;     - put CPU into sleep again
sleepmode_sleep_1:
	movff	BSR_backup,BSR					; restore bank selection
	return									; done

sleepmode_sleepwalk:
	WAITMS	d'65'							; wait 65 ms
	bra		sleepmode_sleep_1				; continue with common part

;-----------------------------------------------------------------------------

 END
