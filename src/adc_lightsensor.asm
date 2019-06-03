;=============================================================================
;
;   File adc_lightsensor.asm                  combined next generation V3.03.2
;
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;  2011-08-08 : [mH] moving from OSTC code

#include "hwos.inc"
#include "math.inc"
#include "wait.inc"
#include "eeprom_rs232.inc"
#include "i2c.inc"


adc_light	CODE

;=============================================================================

wait_adc:									; bank-safe
	movwf	ADCON0
	nop
	bsf		ADCON0,1						; start ADC
wait_adc2:
	btfsc	ADCON0,1						; wait...
	bra		wait_adc2
	return

	global	get_battery_voltage
get_battery_voltage:						; start ADC and wait until finished
	btfss	battery_gauge_available			; battery gauge IC available?
	bra		get_battery_voltage_2			; NO  - OSTC hardware without gauge IC
	call	lt2942_get_accumulated_charge	; YES - read coulomb counter
	call	lt2942_get_voltage				;     - read battery voltage
	call	lt2942_get_temperature			;     - read battery temperature
	tstfsz	batt_voltage+1					;     - read voltage < 256 mV ?
	bra		get_battery_voltage_1			;       NO  - proceed
	call	lt2942_get_accumulated_charge	;       YES - re-read coulomb counter
	call	lt2942_get_voltage				;           - re-read battery voltage
	call	lt2942_get_temperature			;           - re-read battery temperature
	;bra	get_battery_voltage_1			;           - proceed

get_battery_voltage_1:
	btfsc	divemode						; in dive mode?
	return									; YES - done

	bcf		cv_active						; clear CV charing status by default
	bcf		cc_active						; clear CC charing status ny default
	bcf		LEDr							; switch off red LED
	bcf		TRISJ,2							; activate Chrg-Out output
	bsf		CHRG_OUT						; start charger
	btfss	CHRG_IN							; charging?
	bra		charge_cc_active				; YES - charging in CC mode
	bcf		CHRG_OUT						; NO  - stop charger
	bsf		TRISJ,2							;     - set Chrg-Out output to high impedance
	WAITMS	d'1'							;     - wait 1 ms
	btfsc	CHRG_IN							;     - still charging?
	return									;       NO  - done
	;bra	charge_cv_active				;       YES - charging in CV mode

charge_cv_active:
	decfsz	get_bat_volt_counter,F
	return
	movlw	.15
	cpfsgt	batt_voltage+1					; battery voltage >= 16*256mV (4.096V) ?
	bra		charge_cc_active				; NO
	bsf		cc_active
	bsf		cv_active
	bsf		LEDr							; indicate charging
	call	lt2942_charge_done				; reset accumulating registers to 0xFFFF
	WAITMS	d'10'
	bcf		LEDr							; indicate charging
	bsf		get_bat_volt_counter,0			; =1
	return

charge_cc_active:
	bsf		cc_active
	bsf		LEDr							; indicate charging
	bcf		CHRG_OUT
	bsf		TRISJ,2							; set chrg-Out output to high impedance
	movlw	.15
	cpfsgt	batt_voltage+1					; battery voltage >= 16*256mV (4.096 V)?
	bra		charge_cc_active2				; NO
	movlw	.81
	cpfslt	batt_voltage+0					; battery voltage >= 80mV (+4096mV from batt_voltage+1)?
	bra		charge_cv_active				; YES
charge_cc_active2:
	movlw	.10
	movwf	get_bat_volt_counter
	return

get_battery_voltage_2:						; no gauge IC available, use ADC to measure battery voltage
	; additional charging disable in software
	bsf		charge_disable					; set      charging-inhibit signal
	bcf		charge_enable					; activate charging-inhibit signal

	bsf		adc_is_running					; =1: the ADC is in use
	movlw	b'00100000'						; 2.048 Volt Vref+ -> 1 LSB = 500 µV
	movwf	ADCON1
	movlw	b'00011001'						; power on ADC, select AN6
	rcall	wait_adc

	MOVII	ADRESL,batt_voltage				; store value
	bcf		ADCON0,0						; power off ADC

; Multiply with 2.006 to be exact here...
;	bcf		STATUS,C
;	rlcf	xA+0,F
;	rlcf	xA+1,F							; x2
;	MOVII	xA,batt_voltage					; store value

	bcf		battery_is_36v					; by default assume it is a 1.5 battery
	MOVII	batt_voltage,sub_b				; load measured battery voltage

	; Check if the battery is a 3.6V lithium
	MOVLI	lithium_36v_low,sub_a			; load threshold for 3.6 Volt lithium battery
	call	cmpU16							; sub_a - sub_b
	btfss	neg_flag						; battery voltage > 3.6 V lithium threshold ?
	bra		get_battery_voltage_9			; NO  - keep assumption of 1.5V battery
	bsf		battery_is_36v					; YES - set flag

	; Check if the battery is near-dead already
	MOVLI	lithium_36v_empty,sub_a			; load threshold for near-dead lithium battery
	call	cmpU16							; sub_a - sub_b
	btfsc	neg_flag						; battery voltage > dead-battery threshold ?
	bra		get_battery_voltage_3			; YES - battery is still ok
	movlw	.128							; NO  - battery is probably dead very soon, set ">=24Ah used"
	movff	WREG,battery_gauge+5			;     - into battery gauge registers

get_battery_voltage_3:						; 3.6V battery gauge mode
	; SMOVFF "by hand" as the macro does not work with arguments that have a '+something' with them
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
	return

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


	global	get_ambient_level				; called from ISR only, in context bank isr_backup
get_ambient_level:							; starts ADC and waits until finished
	btfsc	sleepmode						; in sleep mode?
	return									; YES - done
	btfsc	adc_is_running					; NO  - ADC in use?
	return									;       YES - return
	banksel	HW_descriptor					;       NO  - select bank where hardware descriptor is stored
	btfsc	ambient_sensor					;           - ambient sensor available?
	bra		get_ambient_level1				;             YES - use sensor
	banksel	isr_backup						;             NO  - back to ISR default bank
	movff	opt_brightness,isr_lo			;                 - get brightness selection
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
	movlw	b'00000000'						; Vref+ = Vdd
	movwf	ADCON1
	movlw	b'00011101'						; power on ADC, select AN7
	rcall	wait_adc
	MOVII	ADRESL,ambient_light
	bcf		ADCON0,0						; power off ADC

	; ambient_light:2 is between 4096 (direct sunlight) and about 200 (darkness)
	; first: divide by 16
	bcf		STATUS,C
	rrcf	ambient_light+1
	rrcf	ambient_light+0
	bcf		STATUS,C
	rrcf	ambient_light+1
	rrcf	ambient_light+0
	bcf		STATUS,C
	rrcf	ambient_light+1
	rrcf	ambient_light+0
	bcf		STATUS,C
	rrcf	ambient_light+1
	rrcf	ambient_light+0
	; result: ambient_light:2/16
	; now make sure to have value between ambient_light_low and ambient_light_max

	movlw	.254
	tstfsz	ambient_light+1					; > 255 ?
	movwf	ambient_light+0					; YES - avoid ADC clipping

	incfsz	ambient_light+0,W				; = 255 ?
	bra		get_ambient_level2				; NO - continue

	movlw	.254
	movwf	ambient_light+0					; avoid ADC clipping

get_ambient_level2:
;	movlw	.10
;	subwf	ambient_light+0,F				; subtract 10 (ADC Offset)
;	btfsc	STATUS,N
;	movwf	ambient_light+0					; avoid clipping

	movff	opt_brightness,isr_lo			; get brightness setting

	btfsc	RCSTA1,7						; UART module on?
	clrf	isr_lo							; YES - set temporary to eco mode
	incf	isr_lo,F						; adjust 0-2 to 1-3

	movlw	ambient_light_max_high_cr		; cR and 2 hardware brightest setting

	banksel	HW_descriptor					; select bank where hardware descriptor and model variant is stored
	btfss	battery_gauge_available
	movlw	ambient_light_max_high_15V		; 1.5V battery brightest setting
	btfsc	battery_is_36v					; 3.6V battery in use?
	movlw	ambient_light_max_high_36V		; YES - 3.6V battery brightest setting
	banksel	isr_backup						; back to ISR default bank

	dcfsnz	isr_lo,F
	movlw	ambient_light_max_eco			; eco setting
	dcfsnz	isr_lo,F
	movlw	ambient_light_max_medium		; brightest setting

	incf	ambient_light+0,F				; +1
	cpfslt	ambient_light+0					; smaller than WREG?
	movwf	ambient_light+0					; NO - set to max.

	movff	opt_brightness,isr_lo
	incf	isr_lo,F						; adjust 0-2 to 1-3
	movlw	ambient_light_min_high			; darkest setting
	dcfsnz	isr_lo,F
	movlw	ambient_light_min_eco			; darkest setting
	dcfsnz	isr_lo,F
	movlw	ambient_light_min_medium		; darkest setting
	dcfsnz	isr_lo,F
	movlw	ambient_light_min_high			; darkest setting

	cpfsgt	ambient_light+0					; bigger than WREG?
	movwf	ambient_light+0					; NO - set to min

	movff	ambient_light+0,max_CCPR1L		; store value for dimming in TMR7 interrupt
	return


;=============================================================================
; routines for reading analog-attached external sensors
;
 IFDEF _external_sensor

	global	get_analog_inputs				; called from outside ISR only
get_analog_inputs:							; start ADC and wait until finished
	bsf		adc_is_running					; =1: the ADC is in use
	btfsc	TFT_PWM
	bra		get_analog_inputs				; wait for PWM low
	movlw	b'00100000'						; 2.048V Vref+ -> 1 LSB = 500 µV
	movwf	ADCON1
	banksel	sensor1_mv						; select bank where sensor1_mv is stored
	; Sensor 1
	movlw	b'00100001'						; power on ADC, select AN8
	rcall	wait_adc
	bcf		STATUS,C
	rrcf	ADRESH,F						; /2
	rrcf	ADRESL,W
	addwf	sensor1_mv+0,F					; add to sensor1_mv:2
	movf	ADRESH,W
	addwfc	sensor1_mv+1,F
	bcf		STATUS,C
	rrcf	sensor1_mv+1,F					; divide /2
	rrcf	sensor1_mv+0,F
	movlw	HIGH ignore_mv
	cpfsgt	sensor1_mv+1					; > ignore_mv ?
	bra		get_analog_inputs1a				; NO
	CLRI	sensor1_mv						; YES - ignore this reading
get_analog_inputs1a:						; ignore 1.9 mV noise for not-connected inputs
	tstfsz	sensor1_mv+1					; > 25.5 mV ?
	bra		get_analog_inputs2				; YES - skip here
	movlw	.19
	cpfsgt	sensor1_mv+0					; > 1.9 mV ?
	clrf	sensor1_mv+0					; NO - clear result

get_analog_inputs2:
	; Sensor 2
	movlw	b'00100101'						; power on ADC, select AN9
	rcall	wait_adc
	bcf		STATUS,C
	rrcf	ADRESH,F						; /2
	rrcf	ADRESL,W
	addwf	sensor2_mv+0,F					; add to sensor2_mv:2
	movf	ADRESH,W
	addwfc	sensor2_mv+1,F
	bcf		STATUS,C
	rrcf	sensor2_mv+1,F					; divide /2
	rrcf	sensor2_mv+0,F
	movlw	HIGH ignore_mv
	cpfsgt	sensor2_mv+1					; > ignore_mv ?
	bra		get_analog_inputs2a				; NO
	CLRI	sensor2_mv						; YES - ignore this reading
get_analog_inputs2a:						; ignore 1.9 mV noise for not-connected inputs
	tstfsz	sensor2_mv+1					; > 25.5 mV ?
	bra		get_analog_inputs3				; YES - skip here
	movlw	.19
	cpfsgt	sensor2_mv+0					; > 1.9 mV ?
	clrf	sensor2_mv+0					; NO - clear result

get_analog_inputs3:
	; Sensor 3
	movlw	b'00101001'						; power on ADC, select AN10
	rcall	wait_adc
	bcf		STATUS,C
	rrcf	ADRESH,F						; /2
	rrcf	ADRESL,W
	addwf	sensor3_mv+0,F					; add to sensor3_mv:2
	movf	ADRESH,W
	addwfc	sensor3_mv+1,F
	bcf		STATUS,C
	rrcf	sensor3_mv+1,F					; divide /2
	rrcf	sensor3_mv+0,F
	movlw	HIGH ignore_mv
	cpfsgt	sensor3_mv+1					; > ignore_mv ?
	bra		get_analog_inputs3a				; NO
	CLRI	sensor3_mv						; YES - ignore this reading
get_analog_inputs3a:						; ignore 1.9 mV noise for not-connected inputs
	tstfsz	sensor3_mv+1					; > 25.5 mV ?
	bra		get_analog_inputs4				; YES - skip here
	movlw	.19
	cpfsgt	sensor3_mv+0					; > 1.9 mV ?
	clrf	sensor3_mv+0					; NO - clear result
get_analog_inputs4:
	banksel	common							; back to bank common
	bcf		ADCON0,0						; power off ADC
	bcf		adc_is_running					; done with ADC
	return

 ENDIF	; _external_sensor

;=============================================================================

	global	piezo_config					; called from outside ISR only
piezo_config:								; set up sensitivity of heinrichsweikamp piezo buttons (~30ms)
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

	bcf		INTCON,GIE

	movff	opt_cR_button_right,WREG		; right button
	btfsc	flip_screen						; 180° rotation ?
	movff	opt_cR_button_left,WREG			; YES - left button
	rcall	piezo_config_tx

	movff	opt_cR_button_left,WREG			; left button
	btfsc	flip_screen						; 180° rotation ?
	movff	opt_cR_button_right,WREG		; YES - right button
	rcall	piezo_config_tx

	movlw	.20								; reserved
	rcall	piezo_config_tx
	movlw	.20								; reserved
	rcall	piezo_config_tx

	bsf		INTCON,GIE
	return

piezo_config_tx:							; send one byte
	movwf	lo								; store byte
	movlw	.8
	movwf	hi								; bit counter
	bcf		TX3_PIEZO_CFG					; start bit
	rcall	piezo_config_wait_bit
piezo_config_tx_loop:
	btfss	lo,0							; LSB first
	bcf		TX3_PIEZO_CFG
	btfsc	lo,0							; LSB first
	bsf		TX3_PIEZO_CFG
	rcall	piezo_config_wait_bit
	rrncf	lo,F
	decfsz	hi,F
	bra		piezo_config_tx_loop
	bsf		TX3_PIEZO_CFG					; stop bit
	rcall	piezo_config_wait_bit
	return

piezo_config_wait_bit:
	setf	TMR5H							; set TMR5H first (to 255)
	movlw	.255-.26 						; 26 x 31.5 µs = 819 us
	movwf	TMR5L							; set TMR5L thereafter
	bcf		PIR5,TMR5IF						; clear timer 5 overrun flag
piezo_config_wait_bit3:
	btfss	PIR5,TMR5IF						; timeout?
	bra		piezo_config_wait_bit3			; NO  - loop
	return									; YES - done


	global	get_analog_switches				; called from ISR and from sleep mode, returns in bank common
get_analog_switches:						; start ADC and wait until finished
	banksel	HW_variants						; switch to bank where OSTC model variant is stored
	btfsc	analog_switches					; does the OSTC have analog switches?
	bra		get_analog_switches_1			; YES
	banksel	common							; NO  - back to bank common
	bcf		analog_sw1_pressed				;     - clear flag for analog switch 1
	bcf		analog_sw2_pressed				;     - clear flag for analog switch 2
	return									;     - done

get_analog_switches_1:
	banksel	common							; back to bank common
	btfsc	adc_is_running					; ADC in use?
	return									; YES - abort
	;bra	get_analog_switches_2			; NO  - read switches

get_analog_switches_2:
	movlw	b'00001001'						; left justified
	movwf	ADCON2
;	movlw	b'00000000'						; Vref+ = Vdd
	clrf	ADCON1
	movlw	b'00100101'						; power on ADC, select AN9
	rcall	wait_adc

	banksel	isr_backup						; select bank ISR data
	movff	ADRESH,WREG
	addwf	analog_sw2_raw+0
	movlw	.0
	addwfc	analog_sw2_raw+1
	decfsz	analog_counter,F				; continue averaging?
	bra		get_analog_switches_2a			; YES
	bcf		STATUS,C						; NO  - done, compute average
	rrcf	analog_sw2_raw+1
	rrcf	analog_sw2_raw+0				; /2
	bcf		STATUS,C
	rrcf	analog_sw2_raw+1
	rrcf	analog_sw2_raw+0				; /4
	bcf		STATUS,C
	rrcf	analog_sw2_raw+1
	rrcf	analog_sw2_raw+0				; /8
	bcf		STATUS,C
	rrcf	analog_sw2_raw+1
	rrcf	analog_sw2_raw+0				; /16
	movff	analog_sw2_raw+0,analog_sw2
	clrf	analog_sw2_raw+1
	clrf	analog_sw2_raw+0				; reset average registers
;	movlw	.16
;	movwf	analog_counter					; only once...

get_analog_switches_2a:
	bcf		analog_sw2_pressed				; default to not pressed
	movff	opt_cR_button_left,WREG			; 20-100
	bcf		STATUS,C
	rrcf	WREG							; /2 -> 10-50
	bcf		STATUS,C
	rrcf	WREG							; /2 -> 5-25
	decf	WREG,W							; -1
	decf	WREG,W							; -1
	decf	WREG,W							; -1 -> 2-22
	btfss	button_polarity,1				; (1= normal, 0=inverted)
	bra		get_analog_switches_sw2_inv
	addwf	analog_sw2,W					; average (~128)
	cpfsgt	ADRESH							; pressed?
	bra		get_analog_switches_3			; NO
	bra		get_analog_switches_sw2_pressed	; YES (left button normal)

get_analog_switches_sw2_inv:
	subwf	analog_sw2,W					; average (~128)
	cpfslt	ADRESH							; pressed?
	bra		get_analog_switches_3			; NO
	;bra	get_analog_switches_sw2_pressed	; YES (left button inverted)

get_analog_switches_sw2_pressed:
	bsf		analog_sw2_pressed				; set left button as pressed

get_analog_switches_3:
	movlw	b'00101001'						; power on ADC, select AN10
	rcall	wait_adc
	movff	ADRESH,WREG
	addwf	analog_sw1_raw+0
	movlw	.0
	addwfc	analog_sw1_raw+1
	tstfsz	analog_counter					; continue averaging?
	bra		get_analog_switches_3a			; YES
	bcf		STATUS,C						; NO - done, compute average
	rrcf	analog_sw1_raw+1
	rrcf	analog_sw1_raw+0				; /2
	bcf		STATUS,C
	rrcf	analog_sw1_raw+1
	rrcf	analog_sw1_raw+0				; /4
	bcf		STATUS,C
	rrcf	analog_sw1_raw+1
	rrcf	analog_sw1_raw+0				; /8
	bcf		STATUS,C
	rrcf	analog_sw1_raw+1
	rrcf	analog_sw1_raw+0				; /16
	movff	analog_sw1_raw+0,analog_sw1
	clrf	analog_sw1_raw+1
	clrf	analog_sw1_raw+0				; reset average registers
	movlw	.16
	movwf	analog_counter					; only once...

get_analog_switches_3a:
	bcf		analog_sw1_pressed				; default to not pressed
	movff	opt_cR_button_right,WREG		; 20-100
	bcf		STATUS,C
	rrcf	WREG							; /2 -> 10-50
	bcf		STATUS,C
	rrcf	WREG							; /2 -> 5-25
	decf	WREG,W							; -1
	decf	WREG,W							; -1
	decf	WREG,W							; -1 -> 2-22
	btfss	button_polarity,0				; (1= normal, 0=inverted)
	bra		get_analog_switches_sw1_inv
	addwf	analog_sw1,W					; average (~128)
	cpfsgt	ADRESH							; pressed?
	bra		get_analog_switches_4			; NO
	bra		get_analog_switches_sw1_pressed	; YES (right button normal)

get_analog_switches_sw1_inv:
	subwf	analog_sw1,W					; average (~128)
	cpfslt	ADRESH							; pressed?
	bra		get_analog_switches_4			; NO
	;bra	get_analog_switches_sw1_pressed	; YES (right button inverted)

get_analog_switches_sw1_pressed:
	bsf		analog_sw1_pressed				; set right button as pressed

get_analog_switches_4:
	movlw	b'10001101'						; restore to right justified
	movwf	ADCON2

	banksel	common							; back to bank common
	btfsc	analog_sw1_pressed				; right button pressed?
	return									; YES - done
	btfsc	analog_sw2_pressed				; left button pressed?
	return									; YES - done
	setf	TMR1H							; NO to both - no button pressed, set timer1 to overflow quickly
	return

	END