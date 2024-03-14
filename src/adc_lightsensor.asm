;=============================================================================
;
;   File adc_lightsensor.asm                * combined next generation V3.11.1
;
;
;   Copyright (c) 2011, JD Gascuel, heinrichs weikamp gmbh, all right reserved.
;=============================================================================
; HISTORY
;  2011-08-08 : [mH] moving from OSTC code

#include "hwos.inc"
#include "math.inc"
#include "wait.inc"
#include "eeprom_rs232.inc"
#include "i2c.inc"


;=============================================================================
adc_light	CODE
;=============================================================================


;-----------------------------------------------------------------------------
; Helper Function - wait on ADC to finish conversion
;
; bank safe
;
    global	wait_adc
wait_adc:
	movwf	ADCON0							; select ADC channel
	nop										; wait a short moment
	nop										; ...
	nop										; .....
	nop										; .......
	bsf		ADCON0,1						; start ADC
wait_adc2:
	btfsc	ADCON0,1						; ADC done?
	bra		wait_adc2						; NO  - wait
	return									; YES - done


;-----------------------------------------------------------------------------
; get Battery Voltage
;
	global	get_battery_voltage
get_battery_voltage:
	btfss	battery_gauge_available			; battery gauge IC available?
	bra		get_battery_voltage_2			; NO  - OSTC hardware without gauge IC
	bsf		battery_is_36v					; YES - gauge IC available, 3.6V battery
	call	lt2942_get_accumulated_charge	;     - read coulomb counter
	call	lt2942_get_voltage				;     - read battery voltage
	call	lt2942_get_temperature			;     - read battery temperature
	tstfsz	batt_voltage+1					;     - read voltage < 256 mV ?
	bra		get_battery_voltage_1			;       NO  - proceed
	call	lt2942_get_accumulated_charge	;       YES - re-read coulomb counter
	call	lt2942_get_voltage				;           - re-read battery voltage
	call	lt2942_get_temperature			;           - re-read battery temperature
	;bra	get_battery_voltage_1			;           - proceed

get_battery_voltage_1:
	rcall	get_battery_voltage_low			; check for battery low condition
	btfsc	divemode						; in dive mode?
	return									; YES - done

	bcf		cv_active						; clear CV charing status by default
	bcf		cc_active						; clear CC charing status ny default
	bcf		LEDr							; switch off red LED
	bcf		TRISJ,2							; activate Chrg-Out output
	bsf		CHRG_OUT						; start charger
	nop										; ignore some noise
	nop										; ...
	nop										; ...
	nop										; ...
	btfss	CHRG_IN							; charging?
	bra		charge_cc_active				; YES - charging in CC mode
	bcf		CHRG_OUT						; NO  - stop charger
	bsf		TRISJ,2							;     - set Chrg-Out output to high impedance
	WAITMS	d'1'							;     - wait 1 ms
	btfsc	CHRG_IN							;     - still charging?
	return									;       NO  - done
	;bra	charge_cv_active				;       YES - charging in CV mode

charge_cv_active:
    	btfss	analog_switches				; does the OSTC have analog switches?
	bra	charge_cv_active1			; NO
    	btfsc	surfmode_menu				; YES - in surface menus?
	bsf	trigger_timeout				; YES - exit to surface mode during charging
charge_cv_active1:
	decfsz	get_bat_volt_counter,F			; decrement counter, became zero?
	return									; NO  - not yet, done
	movlw	.15								; YES - battery voltage >= 16*256mV (4.096V)
	cpfsgt	batt_voltage+1					;     - ... ?
	bra		charge_cc_active				;     NO
	bsf		cc_active						;     YES - set CC charging status
	bsf		cv_active						;         - set CV charging status
	bsf		LEDr							;         - indicate charging
	call	lt2942_charge_done				;         - reset accumulating registers to 0xFFFF
	btfsc	lock_cycle_counter				; cycle counted already?
	bra	charge_cv_active2				; Yes, skip
	banksel	charge_cycles
	INCI	charge_cycles					; increase charge_cycles counter by one
	banksel	common
	bsf	lock_cycle_counter			; lock cycle counter
charge_cv_active2:
	WAITMS	d'10'							;         - wait 10 ms
	bcf		LEDr							;         - indicate charging
	bsf		get_bat_volt_counter,0			;         - set counter to 1
	return									;         - done

charge_cc_active:
    	btfss	analog_switches				; does the OSTC have analog switches?
	bra	charge_cc_active1			; NO
    	btfsc	surfmode_menu				; YES - in surface menus?
	bsf	trigger_timeout				; YES - exit to surface mode during charging
charge_cc_active1:
	bsf		cc_active						; set CC charging mode
	bsf		LEDr							; indicate charging
	bcf		CHRG_OUT						; 
	bsf		TRISJ,2							; set chrg-Out output to high impedance
	movlw	.15								; battery voltage >= 16*256mV (4.096 V)
	cpfsgt	batt_voltage+1					; ... ?
	bra		charge_cc_active2				; NO
	movlw	.81								; YES - battery voltage >= 80mV (+4096mV from batt_voltage+1)
	cpfslt	batt_voltage+0					;     - ... ?
	bra		charge_cv_active				;       YES
charge_cc_active2:
	movlw	.10								;       NO  - set counter to 10
	movwf	get_bat_volt_counter			;           - ...
	return									;           - done

get_battery_voltage_2:						; no gauge IC available, use ADC to measure battery voltage
	; additional charging disable in software
	bsf		charge_disable					; set      charging-inhibit signal
	bcf		charge_enable					; activate charging-inhibit signal

	bsf		adc_is_running					; =1: the ADC is in use
	movlw	b'00100000'						; 2.048 Volt Vref+ -> 1 LSB = 500 µV
	movwf	ADCON1							; ...
	movlw	b'00011001'						; power on ADC, select AN6
	rcall	wait_adc						; take measurement
	MOVII	ADRESL,batt_voltage				; store value
	bcf		ADCON0,0						; power off ADC

;	; multiply with 2.006 to be exact here...
;	bcf		STATUS,C
;	rlcf	xA+0,F
;	rlcf	xA+1,F							; x2
;	MOVII	xA,batt_voltage					; store value

	bcf		battery_is_36v					; by default assume it is a 1.5 battery
	MOVII	batt_voltage,sub_b				; load measured battery voltage

	; check if the battery is a 3.6V lithium
	MOVLI	lithium_36v_low,sub_a			; load threshold for 3.6 Volt lithium battery
	call	cmpU16							; sub_a - sub_b
	btfss	neg_flag						; battery voltage > 3.6 V lithium threshold ?
	bra		get_battery_voltage_9			; NO  - keep assumption of 1.5V battery
	bsf		battery_is_36v					; YES - set flag

	; check if the battery is near-dead already
	MOVLI	lithium_36v_empty,sub_a			; load threshold for near-dead lithium battery
	call	cmpU16							; sub_a - sub_b
	btfsc	neg_flag						; battery voltage > dead-battery threshold ?
	bra		get_battery_voltage_3			; YES - battery is still ok
	movlw	.128							; NO  - battery is probably dead very soon, set ">=24Ah used"
	movff	WREG,battery_gauge+5			;     - into battery gauge registers

get_battery_voltage_3:						; 3.6V battery gauge mode
	; SMOVQQ "by hand" as the macro does not work with arguments that have a '+something' with them
	bcf		trigger_isr_updates				; clear flag, it will be set by the ISR in case it had kicked in
	movff	battery_gauge+5,xC+3
	movff	battery_gauge+4,xC+2
	movff	battery_gauge+3,xC+1
	movff	battery_gauge+2,xC+0
	btfsc	trigger_isr_updates				; did the ISR kicked in since we cleared the flag?
	bra		get_battery_voltage_3			; YES - retry copy

	; battery_gauge: 6 is nAs
	; divide through 65536
	; divide through battery_capacity:2
	; result is in percent
	MOVII	battery_capacity_internal,xB
	call	div32x16						; xC:4 = xC:4 / xB:2 with xA as remainder
	movff	xC+0,lo
	; limit to 100
	movlw	.100
	cpfslt	lo
	movwf	lo
	; lo will be between 0 (full) and 100 (empty)
	movf	lo,W
	sublw	.100
	movwf	lo
get_battery_voltage_4:
	movlw	.100							; start with default of 100%
	cpfslt	lo								; > 100%
	movwf	lo								; YES - limit to 100%
	; lo will be between 100 (full) and 0 (empty)
	; use 3.6V battery sensing based on 50 mA load
	MOVLI	lithium_36v_75,sub_a			; load threshold for > 75%
	call	cmpU16							; sub_a - sub_b
	btfsc	neg_flag						; battery voltage above 75% level?
	bra		get_battery_voltage_5			; YES
	movlw	.75								; NO  - set to 75%
	movwf	lo
get_battery_voltage_5:
	; 50%
	MOVLI	lithium_36v_50,sub_a			; load threshold for > 50%
	call	cmpU16							; sub_a - sub_b
	btfsc	neg_flag						; battery voltage above 75% level?
	bra		get_battery_voltage_6			; YES
	movlw	.50								; NO  - set to 50%
	movwf	lo
get_battery_voltage_6:
	; 25%
	MOVLI	lithium_36v_25,sub_a			; load threshold for > 25%
	call	cmpU16							; sub_a - sub_b
	btfsc	neg_flag						; battery voltage above 25% level?
	bra		get_battery_voltage_7			; YES
	movlw	.25								; NO  - set to 25%
	movwf	lo
get_battery_voltage_7:
	; 10%
	MOVLI	lithium_36v_10,sub_a			; load threshold for > 10%
	call	cmpU16							; sub_a - sub_b
	btfsc	neg_flag						; battery voltage above 10% level?
	bra		get_battery_voltage_8			; YES
	movlw	.10								; NO  - set to 10%
	movwf	lo
get_battery_voltage_8:
	movlw	.100							; maximum is 100 (%)
	cpfslt	lo								; > 100% ?
	movwf	lo								; YES - limit to 100%
	movf	batt_percent,W					; get last battery percentage
	cpfsgt	lo								; current battery % < last battery % ?
	movff	lo,batt_percent					; YES - take new value (keep batt_percent on the lowest value found)
	btfsc	battery_is_36v					; using a 3.6 volt battery?
	movff	lo,batt_percent					; YES - take new value (always use computed value for 3.6V battery)
	bcf		adc_is_running					; done with ADC
	;bra	get_battery_voltage_low			; check for battery low condition (and return)

get_battery_voltage_low:
	; check for battery low condition
	movlw	battery_warn_level_36+1			; get threshold for 3.6 Volt battery warning, incremented by 1
	btfss	battery_is_36v					; actually a 3.6 Volt battery detected?
	movlw	battery_warn_level_15+1			; NO - replace with 1.5 Volt battery warning, incremented by 1
	bsf		battery_low_condition			; set battery low condition by default
	cpfslt	batt_percent					; current battery level <= warning threshold ?
	bcf		battery_low_condition			; NO  - clear battery low condition
	return									;     - done

get_battery_voltage_9:
	; use 1.5V battery voltage mode
	; use approximation (batt_voltage-aa_15v_low)/4 = lo
	MOVII	batt_voltage,sub_a				; load battery voltage
	MOVLI	aa_15v_low,  sub_b				; load offset
	call	subU16							; sub_c = sub_a - sub_b
	bcf		STATUS,C						; shift right to divide / 2
	rrcf	sub_c+1
	rrcf	sub_c+0
	bcf		STATUS,C						; another shift right to divide / 4
	rrcf	sub_c+1
	rrcf	sub_c+0
	movff	sub_c+0,lo						; store result
	bra		get_battery_voltage_8			; check limits and return


;-----------------------------------------------------------------------------
; get ambient Light Level
;
; called from ISR only, in context bank isr_backup
;
	global	get_ambient_level
get_ambient_level:
	btfsc	sleepmode						; in sleep mode?
	return									; YES - done
	btfsc	adc_is_running					; NO  - ADC in use?
	return									;       YES - abort
	TSTOSS	opt_use_AmbientSensor				; =1: Use the ambient sensor
	bra	get_ambient_level0				; NO, skip and use fixed value
	banksel	HW_descriptor					;       NO  - select bank where hardware descriptor is stored
	btfsc	ambient_sensor					;           - ambient sensor available?
	bra		get_ambient_level1				;             YES - use sensor
get_ambient_level0:	
	banksel	isr_backup						;             NO  - back to ISR default bank
	movff	brightness,isr_lo			;                 - get brightness selection
	incf	isr_lo,F						;                 - 0-2 -> 1-3
	movlw	ambient_light_max_high_cr		;                 - default selection to brightest setting
	dcfsnz	isr_lo,F						;                 - level 0 (eco) selected?
	movlw	ambient_light_max_eco			;                   YES - select eco brightness
	dcfsnz	isr_lo,F						;                 - level 1 (medium) selected?
	movlw	ambient_light_max_medium		;                   YES - select medium brightness
	movwf	ambient_light+0					;                 - store selection
	movwf	max_CCPR1L						;                 - store value for dimming in TMR7 interrupt
	return									;                 - done

get_ambient_level1:							; using ambient sensor
	banksel	isr_backup						; back to ISR default bank
	clrf	ADCON1							; Vref+ = Vdd
	movlw	b'00011101'						; power on ADC, select AN7
	rcall	wait_adc
	MOVII	ADRESL,ambient_light
	bcf	ADCON0,0						; power off ADC

	btfsc	ambient_light+1,7					; result negative?
	return								; Yes, skip this measurement
	; ambient_light:2 is between 4096 (direct sunlight) and about 200 (darkness)
	; first: divide by 16
	movlw	.4								; divide by 2^4 = 16
get_ambient_level1_loop:
	bcf		STATUS,C						; clear carry
	rrcf	ambient_light+1					; rotate right high byte, carry into MSB, LSB into carry
	rrcf	ambient_light+0					; rotate right low  byte, carry into MSB, LSB into carry
	decfsz	WREG							; decrement counter, done?
	bra		get_ambient_level1_loop			; NO  - loop

	; result: ambient_light:2/16
	; now make sure to have value between ambient_light_low and ambient_light_max

	movlw	.254
	tstfsz	ambient_light+1					; > 255 ?
	movwf	ambient_light+0					; YES - avoid ADC clipping

	incfsz	ambient_light+0,W				; = 255 ?
	bra	get_ambient_level2				; NO - continue

	movlw	.254
	movwf	ambient_light+0					; avoid ADC clipping

get_ambient_level2:
	movff	brightness,isr_lo			; get brightness setting

	btfsc	RCSTA1,7						; UART module on?
	clrf	isr_lo							; YES - set temporary to eco mode

	incf	isr_lo,F						; adjust 0-2 to 1-3

	banksel	HW_descriptor					; select bank where hardware descriptor and model variant are stored
	movlw	ambient_light_max_high_cr		; default to cR and 2 hardware brightest setting
	btfss	battery_gauge_available			; battery gauge available?
	movlw	ambient_light_max_high_15V		; NO  - change to 1.5V battery brightest setting
	btfsc	battery_is_36v					; 3.6V battery in use?
	movlw	ambient_light_max_high_36V		; YES - change to 3.6V battery brightest setting
	banksel	isr_backup						; back to ISR default bank

	dcfsnz	isr_lo,F						; eco setting?
	movlw	ambient_light_max_eco			; YES
	dcfsnz	isr_lo,F						; medium setting?
	movlw	ambient_light_max_medium		; YES

	incf	ambient_light+0,F				; +1
	cpfslt	ambient_light+0					; smaller than WREG?
	movwf	ambient_light+0					; NO - set to max.

	movff	brightness,isr_lo			; get brightness setting
	incf	isr_lo,F						; adjust 0-2 to 1-3
	movlw	ambient_light_min_high			; default to highest setting
	dcfsnz	isr_lo,F						; eco setting?
	movlw	ambient_light_min_eco			; YES
	dcfsnz	isr_lo,F						; medium setting?
	movlw	ambient_light_min_medium		; YES
	dcfsnz	isr_lo,F						; highest setting?
	movlw	ambient_light_min_high			; YES

	cpfsgt	ambient_light+0					; bigger than WREG?
	movwf	ambient_light+0					; NO - set to min

	movff	ambient_light+0,max_CCPR1L		; store value for dimming in TMR7 interrupt
	return									; done


;-----------------------------------------------------------------------------
; Read analog external Sensors
;
; called from outside ISR only
;
 IFDEF _external_sensor

	global	get_analog_inputs
get_analog_inputs:
	bsf		adc_is_running					; =1: the ADC is in use
	btfsc	screen_type3						; display 3 ?
	bra	get_analog_inputs2					; yes, skip here
	btfsc	TFT_PWM							; PWM active?
	bra		get_analog_inputs				; YES - wait for PWM low

get_analog_inputs2:
	movlw	b'00100000'						; 2.048V Vref+ -> 1 LSB = 500 µV
	movwf	ADCON1							; ...

	; Sensor 1
	movlw	b'00100001'						; power on ADC, select AN8
	MOVII	sensor1_mv,mpr					; get last sensor voltage
	rcall	get_analog_inputs_common		; update value
	MOVII	mpr,sensor1_mv					; store new value

	; Sensor 2
	movlw	b'00100101'						; power on ADC, select AN9
	MOVII	sensor2_mv,mpr					; get last sensor voltage
	rcall	get_analog_inputs_common		; update value
	MOVII	mpr,sensor2_mv					; store new value

	; Sensor 3
	movlw	b'00101001'						; power on ADC, select AN10
	MOVII	sensor3_mv,mpr					; get last sensor voltage
	rcall	get_analog_inputs_common		; update value
	MOVII	mpr,sensor3_mv					; store new value

	bcf		ADCON0,0						; power off ADC
	bcf		adc_is_running					; done with ADC
	return									; done

get_analog_inputs_common:
	rcall	wait_adc						; wait for ADC
	bcf		STATUS,C						; clear carry flag
	rrcf	ADRESH,F						; divide /2
	rrcf	ADRESL,W						; ...
	addwf	mpr+0,F							; add to sensor_mv:2
	movf	ADRESH,W						; ...
	addwfc	mpr+1,F							; ...
	bcf		STATUS,C						; clear carry flag
	rrcf	mpr+1,F							; divide /2
	rrcf	mpr+0,F							; ...
	movlw	HIGH ignore_mv_above			; get upper limit of operational range
	cpfsgt	mpr+1							; > limit ?
	bra		get_analog_inputs_common_1		; NO  - ok to use
	CLRI	mpr								; YES - ignore this reading
	return									;     - done
get_analog_inputs_common_1:
	tstfsz	mpr+1							; > 25.5 mV ?
	return									; YES - ok to use anyway
	movlw	ignore_mv_below					; NO  - get lower limit of operational range
	cpfsgt	mpr+0							;     - > limit ?
	clrf	mpr+0							;       NO - ignore this reading
	return									;     - done

 ENDIF	; _external_sensor


;-----------------------------------------------------------------------------
; Set the Sensitivity of the Piezo Buttons
; 
; called from outside ISR only, ~ 30 ms
;
	global	piezo_config
piezo_config:
	clrf	TMR5H							; clear TMR5H first
	clrf	TMR5L							; clear TMR5L thereafter
	bcf		PIR5,TMR5IF						; clear timer 5 overrun flag, will take ~ 2 seconds to overrun after reset
	bcf		switch_right					; clear left-over button events
	bcf		switch_left						; ...
piezo_config0:
	btfsc	switch_right					; user still pressing the right button?
	bra		piezo_config					; YES - loop to wait for release
	btfsc	switch_left						; user still pressing the left  button?
	bra		piezo_config					; YES - loop to wait for release

	btfss	PIR5,TMR5IF						; timeout?
	bra		piezo_config0					; NO - not yet, loop

	bcf		INTCON,GIE						; disable all interrupts

	movff	opt_cR_button_right,WREG		; right button
	btfsc	flip_screen						; 180° rotation ?
	movff	opt_cR_button_left,WREG			; YES - left button
	rcall	piezo_config_tx					; send to button

	movff	opt_cR_button_left,WREG			; left button
	btfsc	flip_screen						; 180° rotation ?
	movff	opt_cR_button_right,WREG		; YES - right button
	rcall	piezo_config_tx					; send to button

	movlw	.20								; reserved
	rcall	piezo_config_tx					; send to button
	movlw	.20								; reserved
	rcall	piezo_config_tx					; send to button

	bsf		INTCON,GIE						; re-enable all interrupts
	return									; done


;-----------------------------------------------------------------------------
; Helper Function - send 1 Byte to the Piezo Buttons
;
piezo_config_tx:
	movwf	lo								; store byte to be sent
	movlw	.8								; set up bit count
	movwf	hi								; ...
	bcf		TX3_PIEZO_CFG					; start bit
	rcall	piezo_config_wait_bit			; wait
piezo_config_tx_loop:						; LSB first
	btfss	lo,0							; bit = 0 ?
	bcf		TX3_PIEZO_CFG					; YES
	btfsc	lo,0							; bit = 1 ?
	bsf		TX3_PIEZO_CFG					; YES
	rcall	piezo_config_wait_bit			; wait
	rrncf	lo,F							; shift lo to access next bit
	decfsz	hi,F							; decrement bit counter, all done?
	bra		piezo_config_tx_loop			; NO  - loop
	bsf		TX3_PIEZO_CFG					; YES - stop bit
	rcall	piezo_config_wait_bit			;     - wait
	return									;     - done

piezo_config_wait_bit:
	setf	TMR5H							; set TMR5H first (to 255)
	movlw	.255-.26 						; 26 x 31.5 µs = 819 µs
	movwf	TMR5L							; set TMR5L thereafter
	bcf		PIR5,TMR5IF						; clear timer 5 overrun flag
piezo_config_wait_bit_loop:
	btfss	PIR5,TMR5IF						; timeout?
	bra		piezo_config_wait_bit_loop		; NO  - loop
	return									; YES - done


;-----------------------------------------------------------------------------
; get the analog Switches
;
; called from ISR and from sleep mode, returns in bank common
;
	global	get_analog_switches
get_analog_switches:
	btfsc	analog_switches					; does the OSTC have analog switches?
	bra		get_analog_switches_1			; YES

get_analog_switches0:
	bcf		analog_sw1_pressed				; clear flag for analog switch 1
	bcf		analog_sw2_pressed				; clear flag for analog switch 2
	return									; done

get_analog_switches_1:
	btfsc	adc_is_running					; ADC in use?
	return									; YES - abort
	btfsc	cc_active						; NO  - charging constant current?
	bra		get_analog_switches0			;       YES - abort (and clear both flags)
	btfsc	cv_active						; NO  - charging constant voltage?
	bra		get_analog_switches0			;       YES - abort (and clear both flags)

get_analog_switches_2:
    ; reset the latch register in case it's externally pulled down. mH This is a test
	bsf	power_sw1			; switch on power supply for switch 1
	bsf	power_sw2			; switch on power supply for switch 2
    
	bsf		adc_is_running					; flag that ADC is in use
	bcf		ADCON2,ADFM						; left justified
	clrf	ADCON1							;
	movlw	b'00100101'						; power on ADC, select AN9
	rcall	wait_adc						; wait for ADC

	banksel	isr_backup						; select bank ISR data

	movlw	.250							; set   upper limit
	cpfslt	ADRESH							; above upper limit?
	movff	analog_sw2,ADRESH				; YES - use (last) average instead

	movf	ADRESH,W						; get ADC result (high byte)
	addwf	analog_sw2_raw+0				; add to averaging register
	movlw	.0								; ...
	addwfc	analog_sw2_raw+1				; ...
	decfsz	analog_counter,F				; continue averaging?
	bra		get_analog_switches_2a			; YES

	; compute average - divide by 16
	swapf	analog_sw2_raw+1,F				; swap nibbles in high byte
	movlw	b'11110000'						; keep only upper nibble
	andwf	analog_sw2_raw+1,W				; ...
	movwf	analog_sw2						; copy ex lower nibble of high byte to upper nibble of result
	swapf	analog_sw2_raw+0,F				; swap nibble in low  byte
	movlw	b'00001111'						; keep only lower nibble
	andwf	analog_sw2_raw+0,W				; ...
	iorwf	analog_sw2,F					; copy ex upper nibble of low  byte to lower nibble of result

	clrf	analog_sw2_raw+1				; reset average registers
	clrf	analog_sw2_raw+0				; ...

get_analog_switches_2a:
	bcf		analog_sw2_pressed				; default to not pressed
	movff	opt_cR_button_left,WREG			; get button sensitivity (20-100)
	bcf		STATUS,C						; clear carry bit
	rrcf	WREG							; /2 -> 10-50
	bcf		STATUS,C						; clear carry bit
	rrcf	WREG							; /4 -> 5-25
	decf	WREG,W							; -1
	decf	WREG,W							; -1
	decf	WREG,W							; -1 -> 2-22
	btfss	button_polarity,1				; (1= normal, 0=inverted)
	bra		get_analog_switches_sw2_inv		; 0
	addwf	analog_sw2,W					; 1 - add average (~128)
	cpfsgt	ADRESH							;   - pressed?
	bra		get_analog_switches_3			;     NO  - continue with other button
	bra		get_analog_switches_sw2_pressed	;     YES - (left button normal)

get_analog_switches_sw2_inv:
	subwf	analog_sw2,W					; subtract average (~128)
	cpfslt	ADRESH							; pressed?
	bra		get_analog_switches_3			; NO  - continue with other button
	;bra	get_analog_switches_sw2_pressed	; YES - (left button inverted)

get_analog_switches_sw2_pressed:
	bsf		analog_sw2_pressed				; set left button as pressed

get_analog_switches_3:
	movlw	b'00101001'						; power on ADC, select AN10
	rcall	wait_adc						; wait on ADC

	movlw	.250							; set   upper limit
	cpfslt	ADRESH							; above upper limit?
	movff	analog_sw1,ADRESH				; YES - use (last) average instead

	movf	ADRESH,W						; get ADC result (high byte)
	addwf	analog_sw1_raw+0				; add to averaging register
	movlw	.0								; ...
	addwfc	analog_sw1_raw+1				; ...
	tstfsz	analog_counter					; continue averaging?
	bra		get_analog_switches_3a			; YES

	; compute average - divide by 16
	swapf	analog_sw1_raw+1,F				; swap nibbles in high byte
	movlw	b'11110000'						; keep only upper nibble
	andwf	analog_sw1_raw+1,W				; ...
	movwf	analog_sw1						; copy ex lower nibble of high byte to upper nibble of result
	swapf	analog_sw1_raw+0,F				; swap nibble in low  byte
	movlw	b'00001111'						; keep only lower nibble
	andwf	analog_sw1_raw+0,W				; ...
	iorwf	analog_sw1,F					; copy ex upper nibble of low  byte to lower nibble of result

	clrf	analog_sw1_raw+1				; reset average registers
	clrf	analog_sw1_raw+0				; ...

	; set up averaging counter for next call-up
	movlw	.16								; 16 averaging rounds
	movwf	analog_counter					; ...

get_analog_switches_3a:
	bcf		analog_sw1_pressed				; default to not pressed
	movff	opt_cR_button_right,WREG		; 20-100
	bcf		STATUS,C						; clear carry bit
	rrcf	WREG							; /2 -> 10-50
	bcf		STATUS,C						; clear carry bit
	rrcf	WREG							; /2 -> 5-25
	decf	WREG,W							; -1
	decf	WREG,W							; -1
	decf	WREG,W							; -1 -> 2-22
	btfss	button_polarity,0				; (1= normal, 0=inverted)
	bra		get_analog_switches_sw1_inv		; 0
	addwf	analog_sw1,W					; 1 - add to average (~128)
	cpfsgt	ADRESH							;   - pressed?
	bra		get_analog_switches_4			;     NO  - continue with clean-up
	bra		get_analog_switches_sw1_pressed	;     YES - (right button normal)

get_analog_switches_sw1_inv:
	subwf	analog_sw1,W					; subtract from average (~128)
	cpfslt	ADRESH							; pressed?
	bra		get_analog_switches_4			; NO  - continue with clean-up
	;bra	get_analog_switches_sw1_pressed	; YES - (right button inverted)

get_analog_switches_sw1_pressed:
	bsf		analog_sw1_pressed				; set right button as pressed

get_analog_switches_4:
	bsf		ADCON2,ADFM						; restore to right justified
	bcf		adc_is_running					; flag ADC not in use any more

	banksel	common							; back to bank common

	btfsc	analog_sw1_pressed				; right button pressed?
	return									; YES - done
	btfsc	analog_sw2_pressed				; left button pressed?
	return									; YES - done
	setf	TMR1H							; NO to both - no button pressed, set timer1 to overflow quickly
	setf	TMR1L							;            - ...
	return									;            - done

;-----------------------------------------------------------------------------

	END
