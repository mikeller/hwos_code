 ;=============================================================================
;
;   File isr.asm                            * combined next generation V3.11.1
;
;   INTERUPT subroutines
;
;   Copyright (c) 2011, JD Gascuel, heinrichs weikamp gmbh, all right reserved.
;=============================================================================
; HISTORY
;  2011-05-24 : [jDG] Cleanups from initial Matthias code.

#include "hwos.inc"
#include "shared_definitions.h"			; Mailbox from/to p2_deco.c
#include "ms5541.inc"
#include "adc_lightsensor.inc"

	extern	restore_flash


;=============================================================================
; Code to be placed at a fixed Position
;
isr_high	CODE	0x00008				; high priority interrupts
	bra		HighInt						; jump to ISR

isr_low		CODE	0x00018				; low priority interrupts *** not used ***
	retfie	FAST						; do an immediate return from IRQ
;
;=============================================================================


;-----------------------------------------------------------------------------
; Interrupt Dispatcher Entry Point
;
HighInt:
	; initialize interrupt code
	banksel	isr_backup					; default bank for all ISR code is bank ISR data
	movff	PRODL,PROD_backup+0			; back-up PRODL
	movff	PRODH,PROD_backup+1			; back-up PRODH
	; serve buttons
	btfsc	PIR1,TMR1IF					; timer 1 interrupt (button hold-down timer)?
	rcall	timer1int					; YES - reset timer
	btfsc	PIR5,TMR4IF				; timer 4 interrupt (button debounce)
	rcall	timer4int				; YES, serve the interrupt
	btfsc	INTCON,INT0IF				; right button activity?
	rcall	isr_switch_right			; YES - check right switch
	btfsc	INTCON3,INT1IF				; left button activity?
	rcall	isr_switch_left				; YES - check left switch

 IFDEF _external_sensor_eccr
	; serve IR/S8 link timer
	btfsc	PIR3,RC2IF					; UART 2 interrupt?
	rcall	isr_uart2					; YES - get a byte from the IR/S8 link
	btfsc	PIR2,TMR3IF					; timer 3 interrupt?
	rcall	isr_timer3					; YES - check bytes received from IR/S8 link for being a valid telegram
 ELSE
	bcf		PIR3,RC2IF					; clear UART 2  interrupt
	bcf		PIR2,TMR3IF					; clear timer 3 interrupt
	; fill-up to keep code size identical to _external_sensor_eccr variant, see "Attention" below
	nop
	nop
 ENDIF

	; serve pressure and temperature sensor
	btfsc	PIR5,TMR7IF					; timer 7 interrupt?
	rcall	isr_tmr7					; YES - do every 62.5 ms tasks: read sensors, set CPU speed

	; serve real-time clock (RTCC)
	btfsc	PIR3,RTCCIF					; real-time-clock interrupt?
	rcall	isr_rtcc					; YES - do every 1/2 s tasks: read RTC, trigger timed tasks, adjust CPU speed, gauge battery, etc.

	; clean up and exit
	movff	PROD_backup+0,PRODL			; restore PRODL
	movff	PROD_backup+1,PRODH			; restore PRODH
	bsf		trigger_isr_updates			; signal that the ISR had kicked in
	retfie	FAST						; return from interrupt restoring BSR, STATUS and WREG


;-----------------------------------------------------------------------------
; CPU Speed Adjustment
;
isr_adjust_speed:
	movff	cpu_speed_request,cpu_speed_state	; acknowledge CPU speed request

	btfsc	speed_is_eco				; speed 'eco' requested?
	bra		isr_set_speed_to_eco		; YES - set eco speed
	btfsc	speed_is_fastest			; NO  - speed 'fastest' requested?
	bra		isr_set_speed_to_fastest	;       YES - set fastest speed
	;bra	isr_set_speed_to_normal		;       NO  - default to normal speed

isr_set_speed_to_normal:
	clrf	OSCTUNE						; switch off x4 PLL
	movlw	b'01110010'					; select 16 MHz
	movwf	OSCCON						; set prescaler
	movlw	T2CON_NORMAL				; PWM1 dimming factor for speed 'normal'
	bra		isr_adjust_speed_exit

isr_set_speed_to_eco:
	clrf	OSCTUNE						; switch off x4 PLL
	movlw	b'00110010'					; select 1 MHz
	movwf	OSCCON						; set prescaler
	movlw	T2CON_ECO					; PWM1 dimming factor for speed 'eco'
	bra		isr_adjust_speed_exit

isr_set_speed_to_fastest:
	movlw	b'01110010'					; select 16 MHz by default
	btfsc	lv_core						; on OSTC with low voltage core?
	movlw	b'01100010'					; YES - reduce to 8 MHz
	movwf	OSCCON						; set prescaler
	bsf		OSCTUNE,6					; switch on  x4 PLL -> 64 MHz on high voltage core, 32 MHz on low voltage core
	movlw	T2CON_FASTEST				; PWM1 dimming factor for speed 'fastest'
	bra	isr_adjust_speed_exit

	; Attention: fill-up the gap between the end of this section
	;            and the next section which starts at 0x00080 !!
	nop
	
block_0_code_end:						; marker to find end of code in block 0 in linker report file


;=============================================================================
; Code to be placed at a fixed Position: Jump-Vector for the Bootloader
;
restore		CODE	0x00080				; restore first flash page from EEPROM

restore_flash_0x00080:
	goto	restore_flash
;
;=============================================================================


;=============================================================================
isr_handler	CODE	0x00084
;=============================================================================

isr_adjust_speed_exit:
	movwf	T2CON						; adjust PWM1 for LED dimming
	btfss	OSCCON,HFIOFS				; PLL stabilized?
	bra		isr_adjust_speed_exit		; NO  - loop to give it some more time
	return								; YES - done
	
;-----------------------------------------------------------------------------
; Handle digitally-attached external Sensors
;
; take a byte received on IR/S8 link and slot it into the RX buffer
;
 IFDEF _external_sensor_eccr

isr_uart2:
	bcf		PIR3,RC2IF					; clear UART 2 interrupt flag
	banksel	RCREG2						; RC*2 is outside access RAM
	movff	RCREG2,isr_lo				; copy received byte to isr_lo
	bcf		RCSTA2,CREN					; clear receiver status
	bsf		RCSTA2,CREN					; ...
;	movff	RCREG2,TXREG2 ;mH
	banksel	isr_backup					; back to default ISR bank
	movlw	.64							; size of the buffer
	cpfslt	ir_s8_counter				; number of received bytes < buffer size?
	bra		isr_uart2_1					; NO  - buffer full, do not store the byte
	movf	ir_s8_counter,W				; YES - copy number of received bytes to WREG
	MOVII	FSR0L,FSR0_backup			;     - back-up FSR0
	lfsr	FSR0,ir_s8_buffer			;     - load base address of buffer
	movff	isr_lo,PLUSW0				;     - store received byte
	MOVII	FSR0_backup,FSR0L			;     - restore FSR0
	incf	ir_s8_counter,F				;     - increment number of received bytes by 1
isr_uart2_1:
	movlw	.253						; reload timer 3, high byte
	movwf	TMR3H						; ...
	clrf	TMR3L						; reload timer 3, low  byte
	bsf		T3CON,TMR3ON				; restart timer
	return								; done


;-----------------------------------------------------------------------------
; Timeout on IR/S8 Link: check the Checksum and gather the received Data
;
isr_timer3:
	bcf		T3CON,TMR3ON				; stop timer 3
	movlw	.15							; a IR telegram has 15 bytes
	cpfseq	ir_s8_counter				; got exactly 15 bytes?
	bra		isr_timer3_1				; NO  - test for 16 bytes
	bra		isr_timer3_ir				; YES - got 15 bytes, compute local checksum
isr_timer3_1:
	movlw	.16							; a IR telegram may also have 16 bytes, with last byte 0x00
	cpfseq	ir_s8_counter				; got exactly 16 bytes?
	bra		isr_timer3_2				; NO  - test for 17 bytes
	banksel	common2					; ir_s8_buffer is in common2
	tstfsz	ir_s8_buffer+.15			; YES - last byte = 0x00 ?
	bra		isr_timer3_exit				;       NO  - exit
	bra		isr_timer3_ir				;       YES - got 16 bytes, compute local checksum
isr_timer3_2:
	movlw	.17							; a S8 telegram has 17 bytes
	cpfseq	ir_s8_counter				; got exactly 17 bytes?
	bra		isr_timer3_3				; NO  - test for 57 bytes
	bra		isr_timer3_s8				; YES - S8 data
isr_timer3_3:
	movlw	.57							; an eccr telegram has 57 bytes
	cpfseq	ir_s8_counter				; got exactly 17 bytes?
	bra		isr_timer3_exit				; NO  - exit
	bra		isr_timer3_eccr				; YES - eccr data

isr_timer3_eccr:	
 ;	; process telegram received on S8 link
	banksel	isr_backup					; default bank for all ISR code is bank ISR data
	movlw	.55							; compute checksum over 1st and next 55 bytes
	rcall	compute_IR_S8_checksum		; compute checksum


;	tstfsz	ir_s8_counter				; checksum ok?
;	bra		isr_timer3_exit				; NO - discard data
	
	; copy received data to respective variables
;	movff	ir_s8_buffer+.1,hud_status_byte
	movff	ir_s8_buffer+.9,s8_rawdata_sensor1+0
	movff	ir_s8_buffer+.10,s8_rawdata_sensor1+1
	movff	ir_s8_buffer+.11,s8_rawdata_sensor1+2
	movff	ir_s8_buffer+.12,sensor1_ppO2
	movff	ir_s8_buffer+.13,s8_rawdata_sensor2+0
	movff	ir_s8_buffer+.14,s8_rawdata_sensor2+1
	movff	ir_s8_buffer+.15,s8_rawdata_sensor2+2
	movff	ir_s8_buffer+.16,sensor2_ppO2
	movff	ir_s8_buffer+.17,s8_rawdata_sensor3+0
	movff	ir_s8_buffer+.18,s8_rawdata_sensor3+1
	movff	ir_s8_buffer+.19,s8_rawdata_sensor3+2
	movff	ir_s8_buffer+.20,sensor3_ppO2
	movff	ir_s8_buffer+.27,hud_battery_mv+0
	movff	ir_s8_buffer+.28,hud_battery_mv+1	    ; External battery voltage in mV
	movff	ir_s8_buffer+.29,ccr_status_byte+0
	movff	ir_s8_buffer+.30,ccr_status_byte+1

	clrf	hud_status_byte
	
	; manually build HUD status byte for ccr testing
	btfsc	ccr_status_byte+0,0
	bsf	sensor1_active
	btfsc	ccr_status_byte+0,0
	bsf	sensor1_calibrated_ok
	
	
	
	btfsc	ccr_status_byte+0,1
	bsf	sensor2_active
	btfsc	ccr_status_byte+0,1
	bsf	sensor2_calibrated_ok
	
	btfsc	ccr_status_byte+0,2
	bsf	sensor3_active
	btfsc	ccr_status_byte+0,2
	bsf	sensor3_calibrated_ok
	
	bsf		trigger_S8_data_update		; YES - set flag for new data available
	;bsf	ext_input_optical
	bsf	ext_s8_full_digital			; Set flag for external S8 full digital mode
	bsf		hud_connection_ok			; set manually for eccr
	bra		isr_timer3_reload			; reload timer and exit
	
	; process telegram received on IR link
isr_timer3_ir:
	banksel	isr_backup					; default bank for all ISR code is bank ISR data
	movlw	.12							; compute checksum over 1st and next 12 bytes
	rcall	compute_IR_S8_checksum		; compute checksum
	tstfsz	ir_s8_counter				; checksum ok?
	bra		isr_timer3_exit				; NO - discard data

	; copy received data to respective variables
	movff	ir_s8_buffer+.1,hud_status_byte
	movff	ir_s8_buffer+.2,sensor1_mv+0
	movff	ir_s8_buffer+.3,sensor1_mv+1
	movff	ir_s8_buffer+.4,sensor2_mv+0
	movff	ir_s8_buffer+.5,sensor2_mv+1
	movff	ir_s8_buffer+.6,sensor3_mv+0
	movff	ir_s8_buffer+.7,sensor3_mv+1
	movff	ir_s8_buffer+.8,sensor1_ppO2
	movff	ir_s8_buffer+.9,sensor2_ppO2
	movff	ir_s8_buffer+.10,sensor3_ppO2
	movff	ir_s8_buffer+.11,hud_battery_mv+0
	movff	ir_s8_buffer+.12,hud_battery_mv+1

	bsf		hud_connection_ok			; set manually for hwHUD w/o the HUD module
	bra		isr_timer3_reload			; reload timer and exit

	; process telegram received on S8 link
isr_timer3_s8:
	movlw	.14							; compute checksum over 1st and next 14 bytes
	rcall	compute_IR_S8_checksum		; compute checksum
	tstfsz	ir_s8_counter				; checksum ok?
	bra		isr_timer3_exit				; NO - discard data

	; copy received data to respective variables
	movff	ir_s8_buffer+.3, hud_status_byte	; also sets hud_connection_ok flag
	movff	ir_s8_buffer+.13,hud_battery_mv+0
	movff	ir_s8_buffer+.14,hud_battery_mv+1

;	btfsc	trigger_S8_data_update		; last data already processed?
;	bra		isr_timer3_exit				; NO  - skip copying new data (and not reload the timeout)
	bsf		trigger_S8_data_update		; YES - set flag for new data available

	; copy more received data to respective variables
	movff	ir_s8_buffer+.4,s8_rawdata_sensor1+0
	movff	ir_s8_buffer+.5,s8_rawdata_sensor1+1
	movff	ir_s8_buffer+.6,s8_rawdata_sensor1+2
	movff	ir_s8_buffer+.7,s8_rawdata_sensor2+0
	movff	ir_s8_buffer+.8,s8_rawdata_sensor2+1
	movff	ir_s8_buffer+.9,s8_rawdata_sensor2+2
	movff	ir_s8_buffer+.10,s8_rawdata_sensor3+0
	movff	ir_s8_buffer+.11,s8_rawdata_sensor3+1
	movff	ir_s8_buffer+.12,s8_rawdata_sensor3+2

isr_timer3_reload:
	movlw	ir_timeout_value			; get timeout value (in multiples of 62.5 ms)
	movwf	ir_s8_timeout				; reload timeout counter
isr_timer3_exit:
	banksel	isr_backup					; default bank for all ISR code is bank ISR data
	clrf	ir_s8_counter				; clear number of received bytes
	bcf		PIR2,TMR3IF					; clear IRQ flag
	return								; done


;-----------------------------------------------------------------------------
; Helper Function - Compute Checksum on Data in RX Buffer
;
compute_IR_S8_checksum:
	movwf	ir_s8_counter				; initialize loop counter from WREG
	MOVII	FSR0L,FSR0_backup			; back-up FSR0
	lfsr	FSR0,ir_s8_buffer			; load base address of the receive buffer
	movff	POSTINC0,isr_mpr+0			; initialize low byte of the calculated checksum with first byte in buffer
	clrf	isr_mpr+1				; clear the high byte of the calculated checksum
compute_IR_S8_checksum_loop:
	movf	POSTINC0,W				; read next byte
	addwf	isr_mpr+0,F				; add it to the to checksum, low  byte
	movlw	.0					; no explicit data to add to the high byte...
	addwfc	isr_mpr+1,F				; ... besides the carry
	decfsz	ir_s8_counter,F				; decrement number of bytes yet to do, all done?
	bra	compute_IR_S8_checksum_loop		; NO  - loop
	movf	POSTINC0,W				; YES - read     low  byte of the received   checksum
	cpfseq	isr_mpr+0				;     - equal to low  byte of the calculated checksum?
	incf	ir_s8_counter,F				;       NO - mark a checksum error
	movf	POSTINC0,W				;     - read     high byte of the received   checksum
	cpfseq	isr_mpr+1				;     - equal to high byte of the calculated checksum?
	incf	ir_s8_counter,F				;       NO - mark a checksum error
	MOVII	FSR0_backup,FSR0L			;     - restore FSR0
	return						;     - done

 ENDIF	; _external_sensor_eccr

 
;-----------------------------------------------------------------------------
; Timer 4 - Button debounce (For new digital piezo circuit)
 
timer4int:
	bcf	PIR5,TMR4IF
	decfsz	debounce_counter,F
	return
	bcf 	T4CON,TMR4ON		; Stop timer 4
	clrf	TMR4			; reset
	
	movff	opt_cR_button_right,WREG		; 20-100; mH: opt_cR_button_right will also affect left button 
	bcf	STATUS,C						; clear carry bit
	rrcf	WREG							; /2 -> 10-50
	bcf	STATUS,C						; clear carry bit
	rrcf	WREG							; /2 -> 5-25
	decf	WREG,W							; -1
	decf	WREG,W							; -1
	decf	WREG,W							; -1 -> 2-22
	
;	movlw   .5			; initial delay
	movwf	debounce_counter	; multiples of 16ms 
	return

timer4_restart:
	movlw   .5			; extra delay
	movwf	debounce_counter
	clrf	TMR4			; reset
	bcf	INTCON3,INT1IF		; clear ext. int 1 request
	bcf	INTCON,INT0IF		; clear ext. int 0 request
	bsf		INTCON,INT0IE	; enable INT0 IRQ
	bsf		INTCON3,INT1IE	; enable INT1 IRQ
	return

;-----------------------------------------------------------------------------
; Tasks every 62.5 ms: Buttons, Dimming, Pressure/Temperature Sensor and CPU Speed
;
isr_tmr7:
	bcf		PIE5,TMR7IE					; disable IRQs by TMR7

	banksel	0xF16						; TMR7H/L are not part of the access RAM
	movlw	.248						; reload timer 7, high byte (8x256 ticks -> 62.5 ms)
	movwf	TMR7H						; ...                       (keep low byte running )

	banksel	isr_backup					; back to ISR default bank
	decfsz	isr_tmr7_helper,F				; decreased every 62,5ms
	bra	isr_tmr7_0
	movlw	.4						; 62,5ms * 4 = 1/4 second
	movwf	isr_tmr7_helper
	bsf	trigger_quarter_second				; set flag (In access RAM)

	
isr_tmr7_0:	
	btfss	update_surface_pressure			; shall update the surface pressure?
	bra		isr_tmr7_1						; NO  - skip
	bcf		update_surface_pressure			; YES - clear request flag
	MOVII	pressure_abs_ref,pressure_surf	;     - update surface pressure

isr_tmr7_1:
	call	get_analog_switches			; get analog readings - bank-safe, but CAUTION: returns in bank common
	banksel	isr_backup					; back to ISR default bank

	btfss	INTCON3,INT1IE				; external IRQ 1 enabled?
	bra		isr_tmr7_2					; NO  - skip next
	btfsc	analog_sw2_pressed			; YES - analog switch 2 pressed?
	rcall	isr_switch_left				;       NO - get digital readings of left switch

isr_tmr7_2:
	btfss	INTCON,INT0IE				; external IRQ 0 enabled?
	bra		isr_tmr7_3					; NO  - skip next
	btfsc	analog_sw1_pressed			; YES - analog switch 1 pressed?
	rcall	isr_switch_right			;       NO - get digital readings of right switch

isr_tmr7_3:
	btfsc	block_sensor_interrupt		; sensor interrupts disabled?
	bra		sensor_int_state_exit		; YES - goto exit
	;bra	isr_tmr7_4					; NO  - continue

isr_tmr7_4:
	movf	max_CCPR1L,W				; dim value
	cpfseq	CCPR1L						; = current PWM value?
	rcall	isr_dimm_tft				; NO - adjust until max_CCPR1L = CCPR1L

 IFDEF _external_sensor_eccr

	decfsz	ir_s8_timeout,F				; decrement IR/S8 timeout counter, became zero?
	bra		isr_sensor_state2			; NO  - continue with sensor
	movlw	ir_timeout_value			; YES - get timeout value (in multiples of 62.5 ms)
	movwf	ir_s8_timeout				;     - reload timeout timer
	btfsc	ext_input_optical			;     - optical input in use?
	bra		isr_tmr7_5					;       YES - clear data
	btfsc	ext_s8_full_digital			; are we in external S8 full digital mode? 
	bra		isr_tmr7_5					;       YES - clear data
	TSTOSS	opt_s8_mode					;       NO  - S8 input in use?
	bra		isr_sensor_state2			;             NO  - must be analog interface in use, keep data
	;bra	isr_tmr7_5					;             YES - clear data

isr_tmr7_5:
	clrf	hud_status_byte				; S8/IR timeout clears all analog input readings to zero -> fallback will be triggered when in sensor mode
	CLRI	hud_battery_mv				; clear battery voltage

	banksel	sensor1_mv					; select bank where sensor data are stored
	CLRI	sensor1_mv					; clear all sensor data
	CLRI	sensor2_mv					; ...
	CLRI	sensor3_mv					; ...
	clrf	sensor1_ppO2				; ...
	clrf	sensor2_ppO2				; ...
	clrf	sensor3_ppO2				; ...
	banksel	s8_rawdata_sensor1
	CLRI	s8_rawdata_sensor1			; clear all sensor data (raw data)
	clrf	s8_rawdata_sensor1+2
	CLRI	s8_rawdata_sensor2			; clear all sensor data (raw data)
	clrf	s8_rawdata_sensor2+2
	CLRI	s8_rawdata_sensor3			; clear all sensor data (raw data)
	clrf	s8_rawdata_sensor3+2
	banksel	isr_backup					; back to ISR default bank

	bsf		trigger_S8_data_update		; signal a data update

 ENDIF	; _external_sensor_eccr

isr_sensor_state2:
	btfss	speed_is_normal						; CPU running on normal speed?
	rcall	isr_set_speed_to_normal				; NO - set CPU speed to normal

	incf	sensor_state_counter,F				; counts to eight for state machine

; State 1: clear flags and average registers, get temperature (51 us) and start pressure integration (73.5 us)
; State 2: get pressure    (51 us), start temperature integration (73.5 us) and calculate temperature compensated pressure (233 us)
; State 3: get temperature (51 us) and start pressure integration (73.5 us)
; State 4: get pressure    (51 us), start temperature integration (73.5 us) and calculate temperature compensated pressure (233 us)
; State 5: get temperature (51 us) and start pressure integration (73.5 us)
; State 6: get pressure    (51 us), start temperature integration (73.5 us) and calculate temperature compensated pressure (233 us)
; State 7: get temperature (51 us) and start pressure integration (73.5 us)
; State 8: get pressure    (51 us), start temperature integration (73.5 us) and calculate temperature compensated pressure (233 us) and build average for half-second update of temperature and pressure

	movff	sensor_state_counter,WREG			; WREG used as temp here...
	dcfsnz	WREG,F
	bra		sensor_int_state1_plus_restart		; do state 1
	dcfsnz	WREG,F
	bra		sensor_int_state2					; do state 2
	dcfsnz	WREG,F
	bra		sensor_int_state1					; do state 3
	dcfsnz	WREG,F
	bra		sensor_int_state2					; do state 4
	dcfsnz	WREG,F
	bra		sensor_int_state1					; do state 5
	dcfsnz	WREG,F
	bra		sensor_int_state2					; do state 6
	dcfsnz	WREG,F
	bra		sensor_int_state1					; do state 7

	; first, do state 2:
	call	get_pressure_value					; state 2: get pressure (51 us)
	call	get_temperature_start				; and start temperature integration (73.5 us)
	call	calculate_compensation				; calculate temperature compensated pressure (27 us)

	; build average for pressure
	bcf		STATUS,C					; clear carry bit
	rrcf	pressure_abs_avg+2					; divide by 2
	rrcf	pressure_abs_avg+1					; ...
	rrcf	pressure_abs_avg+0					; ...
	bcf		STATUS,C					; clear carry bit
	rrcf	pressure_abs_avg+2					; divide by 2, again
	rrcf	pressure_abs_avg+1					; ...
	rrcf	pressure_abs_avg+0					; ...

	; export averaged pressure
	tstfsz	pressure_abs_avg+2					; must be zero for all depths < 262m
	bra	isr_sensor_state_sensor_error				; assume a false reading if <> 0

	; Compare with pressure_abs_last to catch any glitches
	movf	pressure_abs_last+1,W
	cpfslt	pressure_abs_avg+1
	bra	isr_sensor_press_smaller
	; pressure_abs_avg+1 is > pressure_abs_last+1
	; threshold is in 255hPa (2,55m)
	subwf	pressure_abs_avg+1,W
	sublw	.11	; 28,05m
	btfss	STATUS,N
	bra	isr_sensor_press_delta_ok				; delta us small enough
	bra	isr_sensor_press_sensor_resume				; delta too high -> Skip
	
isr_sensor_press_smaller:	
	; pressure_abs_avg+1 is < pressure_abs_last+1
	movf	pressure_abs_avg+1,W
	; threshold is in 255hPa (2,55m)
	subwf	pressure_abs_last+1,W
	sublw	.11	; 28,05m
	btfss	STATUS,N
	bra	isr_sensor_press_delta_ok				; delta us small enough
	bra	isr_sensor_press_sensor_resume				; delta too high -> Skip

isr_sensor_press_delta_ok:	
	MOVII	pressure_abs_avg,pressure_abs				; export result (Which is 16 bit for all depths < 262m)
	
isr_sensor_press_sensor_resume:
	; build average for temperature
	bcf		STATUS,C							; clear carry bit by default
	btfsc	temperature_avg+1,7					; sign bit set?
	bsf		STATUS,C							; YES - copy sign bit to carry bit
	rrcf	temperature_avg+1					; divide signed temperature by 2
	rrcf	temperature_avg+0					; ...
	bcf		STATUS,C							; clear carry bit by default
	btfsc	temperature_avg+1,7					; sign bit set?
	bsf		STATUS,C							; YES - copy sign bit to carry bit
	rrcf	temperature_avg+1					; divide signed temperature by 2 again (by 4 in total now)
	rrcf	temperature_avg+0					; ...
	
	btfsc	i2c_reinit_sensor2					; Sensor ok?
	bra	isr_sensor_state_skip_temp				; likely not, skip updating the temperature
	
	; Compare with temperature_last to catch any glitches
	movf	temperature_last+1,W
	cpfslt	temperature_avg+1
	bra	isr_sensor_temp_smaller
	; temperature_avg+1 is > temperature_last+1
	; threshold is in 25.5°C
	subwf	temperature_avg+1,W
	sublw	.3	; 76,5°C
	btfss	STATUS,N
	bra	isr_sensor_temp_delta_ok				; delta us small enough
	bra	isr_sensor_temp_sensor_resume				; delta too high -> Skip
	
isr_sensor_temp_smaller:	
	; pressure_abs_avg+1 is < pressure_abs_last+1
	movf	temperature_avg+1,W
	; threshold is in 25.5°C
	subwf	temperature_last+1,W
	sublw	.3	; 76,5°C
	btfss	STATUS,N
	bra	isr_sensor_temp_delta_ok				; delta us small enough
	bra	isr_sensor_temp_sensor_resume				; delta too high -> Skip

isr_sensor_temp_delta_ok:	
	MOVII	temperature_avg,temperature_cur		; store final result
	
isr_sensor_temp_sensor_resume:
isr_sensor_state_skip_temp:
	; check for temperature change
	movf	temperature_cur+0,W					; get current temperature, low  byte
	cpfseq	temperature_last+0					; compare with last temperature, equal?
	bra		isr_sensor_state2_2					; NO - temperature has changed
	movf	temperature_cur+1,W					; get current temperature, high byte
	cpfseq	temperature_last+1					; compare with last temperature, equal?
	bra		isr_sensor_state2_2					; NO - temperature has changed
	bra		isr_sensor_state2_3					; YES to both - no change

isr_sensor_state2_2:
	MOVII	temperature_cur,temperature_last	; store current temperature as last temperature for next round
	bsf		trigger_temp_changed				; set flag for temperature change

isr_sensor_state2_3:
	; reset state counter
	clrf	sensor_state_counter				; reset state counter
	btfss	reset_max_pressure					; shall clear the max pressure?
	bra		isr_sensor_state2_3a				; NO  - continue with checking for pressure change
	bcf		reset_max_pressure					; YES - clear request flag
	CLRI	pressure_rel_max					;     - clear max. pressure

isr_sensor_state2_3a:
	; check for pressure change
	movf	pressure_abs+0,W					; get current pressure, low  byte
	cpfseq	pressure_abs_last+0					; compare with last pressure, equal?
	bra		isr_sensor_state2_4					; NO  - pressure has changed
	movf	pressure_abs+1,W					; YES - get current pressure, high byte
	cpfseq	pressure_abs_last+1					;     - compare with last pressure, equal?
	bra		isr_sensor_state2_4					;       NO  - pressure has changed
	bra		isr_sensor_state2_5					;       YES - no change

isr_sensor_state2_4:
	MOVII	pressure_abs,pressure_abs_last		; store current pressure as last pressure for next round
	bsf		trigger_pres_cur_changed			; signal a pressure change

isr_sensor_state2_5:
	; compute relative pressure
	movf	pressure_surf+0,W					; get surface pressure, low  byte
	subwf	pressure_abs+0,W					; WREG = pressure_abs - pressure_surf (low  byte)
	movwf	pressure_rel_cur+0					; store relative pressure, low  byte
	movf	pressure_surf+1,W					; get surface pressure, high byte
	subwfb	pressure_abs+1,W					; WREG = pressure_abs - pressure_surf (high byte)
	movwf	pressure_rel_cur+1					; store relative pressure, high byte
	btfss	STATUS,N							; relative pressure < 0 ?
	bra		isr_sensor_state2_6					; NO  - OK, keep result
	CLRI	pressure_rel_cur					; YES - set relative pressure to zero

isr_sensor_state2_6:
	; check for new max relative pressure
	movf	pressure_rel_cur+0,W				; get current relative pressure, low  byte
	subwf	pressure_rel_max+0,W				; WREG = pressure_rel_max - pressure_rel_cur (low  byte)
	movf	pressure_rel_cur+1,W				; get current relative pressure, high byte
	subwfb	pressure_rel_max+1,W				; WREG = pressure_rel_max - pressure_rel_cur (high byte)
	btfss	STATUS,N							; result < 0, i.e. new max rel pressure?
	bra		isr_sensor_state2_6a				; NO
	MOVII	pressure_rel_cur,pressure_rel_max	; YES - set new max rel pressure
	bsf		trigger_pres_max_changed			;     - signal a pressure max change

isr_sensor_state2_6a:

 IFDEF _min_depth_option
	; check if min/max pressures shall be reset
	btfss	reset_trip_pressure						; shall reset the resettable min/max pressures?
	bra		isr_sensor_state2_6b					; NO
	bcf		reset_trip_pressure						; YES - clear request flag
	CLRI	pressure_rel_max_trip					;     - set max pressure to zero
	SETI	pressure_rel_min_trip					;     - set min pressure to biggest value possible
isr_sensor_state2_6b:
	; check for new resettable max relative pressure
	movf	pressure_rel_cur+0,W					; get current relative pressure, low  byte
	subwf	pressure_rel_max_trip+0,W				; WREG = pressure_rel_max - pressure_rel_cur (low  byte)
	movf	pressure_rel_cur+1,W					; get current relative pressure, high byte
	subwfb	pressure_rel_max_trip+1,W				; WREG = pressure_rel_max - pressure_rel_cur (high byte)
	btfss	STATUS,N								; result < 0, i.e. new max rel pressure?
	bra		isr_sensor_state2_6c					; NO  - continue checking for min depth
	MOVII	pressure_rel_cur,pressure_rel_max_trip	; YES - set new max rel pressure
isr_sensor_state2_6c:
	; check for new resettable min relative pressure
	movf	pressure_rel_cur+0,W					; get current relative pressure, low  byte
	subwf	pressure_rel_min_trip+0,W				; WREG = pressure_rel_min - pressure_rel_cur (low  byte)
	movf	pressure_rel_cur+1,W					; get current relative pressure, high byte
	subwfb	pressure_rel_min_trip+1,W				; WREG = pressure_rel_min - pressure_rel_cur (high byte)
	btfss	STATUS,C								; result > 0, i.e. new min rel pressure?
	bra		sensor_int_state_exit					; NO  - done
	MOVII	pressure_rel_cur,pressure_rel_min_trip	; YES - set new min rel pressure
 ENDIF	; _min_depth_option
	bra		sensor_int_state_exit					; done

sensor_int_state1_plus_restart:
    	clrf	pressure_abs_avg+0			; clear pressure    average register
	clrf	pressure_abs_avg+1
	clrf	pressure_abs_avg+2
	CLRI	temperature_avg				; clear average register for temperature

sensor_int_state1:
	call	get_temperature_value		; state 1: get temperature... 
	call	get_pressure_start			; ...and start pressure integration
	bra		sensor_int_state_exit

sensor_int_state2:
	call	get_pressure_value			; state 2: get pressure (51 us)...
	call	get_temperature_start		; ...and start temperature integration (73.5 us)
	call	calculate_compensation		; .. and calculate temperature compensated pressure (233 us)

sensor_int_state_exit:
	bcf		PIR5,TMR7IF					; clear IRQ flag
	bsf		PIE5,TMR7IE					; re-enable IRQs by TMR7
	bra		isr_adjust_speed			; set/restore CPU speed and return

isr_sensor_state_sensor_error:
	bsf	i2c_reinit_sensor2				; Do an I2C reset and reinitialize the pressure sensor type 2 
								; Done in I2C_get_press_val_MS5837 and I2C_get_temp_val_MS5837
	bra	isr_sensor_press_sensor_resume			; Ignore the reading and continue
;-----------------------------------------------------------------------------
; Helper Function for Display Dimming
;
isr_dimm_tft:							; adjust until max_CCPR1L = CCPR1L
	btfsc	screen_type3				; screen type 3 ?
	return								; YES - ignore, no dimming function with screen type 3
	btfsc	tft_is_dimming				; is the display dimming?
	return								; YES - ignore
	movf	max_CCPR1L,W				; NO  - proceed
	cpfsgt	CCPR1L						;     - CCPR1L > max_CCPR1L ?
	bra		isr_dimm_tft2				;       NO  - dim up
	decf	CCPR1L,F					;       YES - dim down
	return								;           - done
isr_dimm_tft2:
	movf	max_CCPR1L,W				;
	sublw	ambient_light_min_eco		;
	cpfsgt	CCPR1L						; CCPR1L > max_CCPR1L - ambient_light_min_eco ?
	bra		isr_dimm_tft3				; NO  - dim up slow
	movlw	.10							; YES - dim up faster (+10)
	addwf	CCPR1L,F					;     - add to dimming value
isr_dimm_tft3:
	incf	CCPR1L,F					;     - dim up (+1)
	return								;     - done


;-----------------------------------------------------------------------------
; RTC Interrupt (invoked every 0.5 Seconds)
;
isr_rtcc:
	bcf		PIR3,RTCCIF					; clear flag
	bsf		trigger_half_second			; set flag for a new 1/2 second has begun
	btfsc	reset_timebase				; shall reset the timebase?
	bra		isr_rtcc_1					; YES - warp to new full second
	btg		timebase_0sec				; NO  - toggle the 1/2 second timebase
	btfsc	timebase_0sec				;     - did it toggled 1 -> 0 ?
	return								;       NO - on half second, done

isr_rtcc_1:
	; new full second
	bsf		trigger_full_second			; set flag for a new 1/1 second has begun

	btfsc	block_rtc_access			; ISR suspended from accessing the RTC?
	bra		isr_rtcc_2					; YES

	banksel	RTCCFG						; RTC registers are outside access RAM
	bsf		RTCCFG,RTCPTR1
	bsf		RTCCFG,RTCPTR0
	banksel	isr_backup					; back to ISR default bank

	movff	RTCVALL,rtc_year			; read year    in BCD
	movff	RTCVALH,rtc_day				; dummy read
	movff	RTCVALL,rtc_day				; read day     in BCD
	movff	RTCVALH,rtc_month			; read month   in BCD
	movff	RTCVALL,rtc_hour			; read hour    in BCD
	movff	RTCVALH,rtc_secs			; dummy read
	movff	RTCVALL,rtc_secs			; read seconds in BCD
	movff	RTCVALH,rtc_mins			; read minutes in BCD

	; convert BCD to DEC and set registers
	movf	rtc_mins,W
	rcall	isr_rtcc_convert_BCD_DEC	; convert to decimal with result in WREG
	movwf	rtc_mins
	movf	rtc_secs,W
	rcall	isr_rtcc_convert_BCD_DEC	; convert to decimal with result in WREG
	movwf	rtc_secs
	movf	rtc_hour,W
	rcall	isr_rtcc_convert_BCD_DEC	; convert to decimal with result in WREG
	movwf	rtc_hour
	movf	rtc_month,W
	rcall	isr_rtcc_convert_BCD_DEC	; convert to decimal with result in WREG
	movwf	rtc_month
	movf	rtc_day,W
	rcall	isr_rtcc_convert_BCD_DEC	; convert to decimal with result in WREG
	movwf	rtc_day
	movf	rtc_year,W
	rcall	isr_rtcc_convert_BCD_DEC	; convert to decimal with result in WREG
	movwf	rtc_year

isr_rtcc_2:
	; every full second - get ambient light level and set max_CCPR1L
	call	get_ambient_level			; get ambient light level and set max_CCPR1L
	banksel	isr_backup					; back to ISR default bank (for safety only)

	rcall	isr_battery_gauge			; calculate the current charge consumption and add it to the battery gauge
	rcall	isr_update_uptime			; increment overall OSTC uptime
	rcall	isr_update_timeout			; process the timeout timer

	movff	opt_brightness_surface,brightness	; copy brightness - will be overwritten with opt_brightness_dive if in dive mdoe
	btfsc	divemode					; in dive mode?
	rcall	isr_divemode_1sec			; YES - do the every second dive mode tasks

	; increment surface interval counted in seconds
	btfsc	divemode					; in dive mode?
	btfsc	simulatormode				; YES - in simulator mode?
	rcall	inc_surface_interval_secs	; NO  - YES - increment the surface interval (seconds timer)

	; reset the surface interval timers if requested
	btfsc	reset_surface_interval		; shall reset both surface interval timers?
	rcall	rst_surface_interval		; YES

	; reset the timebase if requested
	btfss	reset_timebase				; shall reset the timebase?
	bra		isr_rtcc_3					; NO
	bcf		reset_timebase				; YES - clear request flag
	clrf	eventbase					;     - clear all pending events
	clrf	timebase					;     - clear all timebase flags
	clrf	timebase_secs				;     - clear seconds timer
	clrf	timebase_mins				;     - clear minutes timer
	clrf	simulator_time				;     - clear minutes timer of simulator runtime as well
	bsf		trigger_half_second			;     - set flag for a new 1/2 second has begun
	bsf		trigger_full_second			;     - set flag for a new 1/1 second has begun
	return								;     - done

isr_rtcc_3:
	; count-up the 2 seconds timebase timer
	btg		timebase_1sec				; toggle the 1 second timer bit
	btfss	timebase_1sec				; did it toggled 1 -> 0 ?
	btg		timebase_2sec				; YES - toggle the 2 seconds timer bit

	; count-up the seconds timer
	incf	timebase_secs,F				; increment seconds timer (may temporary become 60 here)
	movlw	.59							; max. for seconds timer
	cpfsgt	timebase_secs				; seconds timer > max.?
	return								; NO  - done

	; new full minute
	clrf	timebase_secs				; reset timer
	bsf		trigger_full_minute			; set flag for a new minute has begun

	; increment surface interval counted in minutes
	btfsc	divemode					; in dive mode?
	btfsc	simulatormode				; YES - in simulator mode?
	rcall	inc_surface_interval_mins	; NO  - YES - increment surface interval (minutes timer)

	btfss	simulatormode				; in simulator mode?
	bra		isr_rtcc_4					; NO
	infsnz	simulator_time,F			; YES - increment real runtime of the simulator, did wrap around (became zero)?
	setf	simulator_time				;       YES - disallow wrap-around, keep at 255 instead

isr_rtcc_4:
	incf	timebase_mins,F				; increment minutes timer
	movlw	.59							; max. for minutes timer
	cpfsgt	timebase_mins				; minutes timer > max.?
	return								; NO  - done

	; new full hour
	clrf	timebase_mins				; YES - reset timer
	bsf		trigger_full_hour			;     - set flag for a new hour has begun
	return								;     - done

	; increment overall OSTC uptime
isr_update_uptime:
	incf	uptime+0,F					; uptime++
	clrf	WREG						; ...
	addwfc	uptime+1,F					; ...
	addwfc	uptime+2,F					; ...
	addwfc	uptime+3,F					; ...
	return								; done

	; process the timeout timer
isr_update_timeout:
	btfsc	restart_timeout				; shall restart the timeout?
	bra		isr_update_timeout_1		; YES
	tstfsz	isr_timeout_timer			; NO  - timeout timer already at zero?
	decfsz	isr_timeout_timer,F			;       NO  - decrement timer, reached zero now?
	return								;       YES / NO  - nothing further to do
	bsf		trigger_timeout				;             YES - set timeout flag
	return								;                 - done
isr_update_timeout_1:
	bcf		restart_timeout							; clear request flag
	bcf		trigger_timeout							; clear pending timeout trigger, if any
	movff	isr_timeout_reload,isr_timeout_timer	; reload timer
	return											; done


;-----------------------------------------------------------------------------
; Calculate Charge drawn from the Battery
;
isr_battery_gauge:
	btfsc	block_battery_gauge			; access to battery gauge suspended?
	return								; YES - done
	MOVLI	current_sleepmode,isr_mpr	; NO  - default to sleep mode with 100µA/3600 -> nAs
	btfss	sleepmode					;     - in sleep mode?
	rcall	isr_battery_gauge2			;       NO - compute current consumption into isr_lo and isr_hi
	movf	isr_mpr+0,W					;     - 48 bit add of isr_mpr:2 to battery_gauge:6
	addwf	battery_gauge+0,F			;     - ...
	movf	isr_mpr+1,W					;     - ...
	addwfc	battery_gauge+1,F			;     - ...
	clrf	WREG						;     - ...
	addwfc	battery_gauge+2,F			;     - ...
	addwfc	battery_gauge+3,F			;     - ...
	addwfc	battery_gauge+4,F			;     - ...
	addwfc	battery_gauge+5,F			;     - ...
	return								;     - done


;-----------------------------------------------------------------------------
; Helper Function - compute current Consumption
;
isr_battery_gauge2:
	; Set consumption rate in nAs (nano Ampere x seconds)
	; Example:
	; MOVLI  .55556,isr_mpr    ; 0.2 Ah / 3600 seconds per hour * 1e9s = nAs
	;
	; Remark: although all the constants are named current_xxxx, in reality they mean charge!

	; Calculate current consumption for LED backlight: 47*CCPR1L+272  (according to values in hwos.inc: 115*CCPR1L+216)
	movlw	.70								; screen type 3 has a fix backlight current slope
	btfss	screen_type3					; does the OSTC have a screen type 3 ?
	movf	CCPR1L,W						; NO - for screen types 0, 1 and 2 get the slope from CCPR1L
	mullw	current_backlight_multi			; multiply with backlight factor current_backlight_multi
	ADDLI	current_backlight_offset,PRODL	; add           backlight offset current_backlight_offset
	MOVII	PRODL,isr_mpr					; copy result to isr_mpr

	; add current for CPU and GPU
	; cpu_speed_state = ECO     3.10 mA ->  861 nAs
	;                 = NORMAL  5.50 mA -> 1528 nAs
	;                 = FASTEST 8.04 mA -> 2233 nAs
	btfss	speed_is_eco					; speed = eco ?
	bra		isr_battery_gauge3				; NO
	ADDLI	current_speed_eco,isr_mpr		; YES - add current_speed_eco to isr_mpr
	bra		isr_battery_gauge5
isr_battery_gauge3:
	btfss	speed_is_normal					; speed = normal?
	bra		isr_battery_gauge4				; NO
	ADDLI	current_speed_normal,isr_mpr	; YES - add current_speed_normal to isr_mpr
	bra		isr_battery_gauge5
isr_battery_gauge4:
	ADDLI	current_speed_fastest,isr_mpr	; speed is fastest, add current_speed_fastest to isr_mpr
isr_battery_gauge5:
	btfss	ir_power						; IR enabled?
	bra		isr_battery_gauge6				; NO
	ADDLI	current_ir_receiver,isr_mpr		; YES - add current_ir_receiver to isr_mpr
isr_battery_gauge6:
	btfss	compass_enabled					; compass active?
	bra		isr_battery_gauge7				; NO
	ADDLI	current_compass,isr_mpr			; YES - add current_compass to isr_mpr
isr_battery_gauge7:
	return									; done


;-----------------------------------------------------------------------------
; Every Second Tasks while in Dive Mode
;
isr_divemode_1sec:
	movff	opt_brightness_divemode,brightness	; copy brightness for dive mode
	decfsz	sampling_timer,F			; decrement sampling timer, became zero?
	bra		isr_divemode_1sec_1			; NO
	bsf		trigger_sample_divedata		; YES - set trigger flag for sampling dive data
	movff	sampling_rate,sampling_timer;     - reload timer

isr_divemode_1sec_1:
	btfss	reset_timebase				; shall reset the timebase? (request flag will be cleared later)
	bra		isr_divemode_1sec_2			; NO
	CLRI	total_divetime_secs			; YES - reset total   dive time, seconds (2 byte)
	clrf	counted_divetime_secs		;     - reset counted dive time, seconds (1 byte)
	CLRI	counted_divetime_mins		;     - reset counted dive time, minutes (2 byte)
	clrf	apnoe_dive_secs				;     - reset apnoe   dive time, seconds (1 byte)
	clrf	apnoe_dive_mins				;     - reset apnoe   dive time, minutes (1 byte)
	bcf		apnoe_at_surface			;     - apnoe mode starts in submerged state
	return								;     - done

isr_divemode_1sec_2:
	INCI	total_divetime_secs			; increase total dive time       (regardless of start_dive_threshold)
	btfss	count_divetime				; shall the dive time be counted (regarding     start_dive_threshold)?
	bra		isr_divemode_1sec_4			; NO  - too shallow / apnoe at surface
	incf	counted_divetime_secs,F		; YES - increase dive time (displayed dive time)
	movlw	d'59'						;     - 60 seconds make a minute
	cpfsgt	counted_divetime_secs		;     - next full minute reached?
	bra		isr_divemode_1sec_3			;       NO  - continue
	clrf	counted_divetime_secs		;       YES - reset seconds to 0
	INCI	counted_divetime_mins		;           - increase dive minutes
	bsf		divetime_longer_1min		;           - set flag for dive time exceeding 1 minute
	;bra	isr_divemode_1sec_3			;           - continue

isr_divemode_1sec_3:					; submerged
	btfss	FLAG_apnoe_mode				; in apnoe mode?
	return								; NO  - done
	btfss	apnoe_at_surface			;     - been at surface before?
	bra		isr_divemode_1sec_3a		;       NO  - increment the dive time
	bcf		apnoe_at_surface			;       YES - a new dive has begun
	bsf		apnoe_new_dive				;           - signal a new dive has begun
	clrf	apnoe_surface_secs			;           - clear surface seconds
	clrf	apnoe_surface_mins			;           - clear surface minutes
	clrf	apnoe_dive_secs				;           - clear dive    seconds
	clrf	apnoe_dive_mins				;           - clear dive    minutes
	MOVII	pressure_rel_cur,pressure_rel_max ;     - reset max pressure to current pressure
	bsf		trigger_pres_max_changed	;           - signal a new maximum pressure
isr_divemode_1sec_3a:
	incf	apnoe_dive_secs,F			; increment dive time, seconds
	movlw	d'59'						; 60 seconds make a minute
	cpfsgt	apnoe_dive_secs				; next full minute reached?
	return								; NO  - done
	clrf	apnoe_dive_secs				; YES - reset seconds to 0
	incf	apnoe_dive_mins,F			;     - increment dive time, minutes
	return								;     - done

isr_divemode_1sec_4:					; at surface
    	movff	opt_brightness_surface,brightness	; copy brightness
	btfss	FLAG_apnoe_mode				; in apnoe mode?
	return								; NO  - done
	bsf		apnoe_at_surface			; YES - memorize been at the surface
	incf	apnoe_surface_secs,F		;     - increment surface time, seconds
	movlw	d'59'						;     - 60 seconds make a minute
	cpfsgt	apnoe_surface_secs			;     - next full minute reached?
	return								;       NO  - done
	clrf	apnoe_surface_secs			;       YES - reset seconds to 0
	incf	apnoe_surface_mins,F		;           - increment surface time, minutes
	return								;           - done


;-----------------------------------------------------------------------------
; Helper Function - BCD to Binary conversion
;
; Input   WREG = value in BCD
; Output  WREG = value in binary
;
isr_rtcc_convert_BCD_DEC:
	movwf	isr_lo						; copy BCD to isr_lo
	swapf	isr_lo, W					; create swapped copy in WREG
	andlw	0x0F						; keep only the tens
	rlncf	WREG, W						; WREG = 2 * tens
	subwf	isr_lo, F					; 16 * tens + ones - 2*tens
	subwf	isr_lo, F					; 14 * tens + ones - 2*tens
	subwf	isr_lo, W					; 12 * tens + ones - 2*tens
	return								; done


;-----------------------------------------------------------------------------
; Check Buttons
;
isr_switch_right:
	bcf		INTCON,INT0IE				; disable external interrupt 0
	
	btfsc	button_hold_down_allowed	; ignore for mechanical push buttons
	bra	isr_switch_right2
	btfsc	T4CON,TMR4ON					; Timer4 running?
	bra	timer4_restart					; Yes, restart
isr_switch_right2:
    
	btfss	flip_screen					; 180° flipped?
	bsf		switch_right				; NO  - set flag for right button
	btfsc	flip_screen					; 180° flipped?
	bsf		switch_left					; YES - set flag for left button
	bra		isr_switch_common			; continue with common part

isr_switch_left:
	bcf		INTCON3,INT1IE				; disable external interrupt 1

	btfsc	button_hold_down_allowed	; ignore for mechanical push buttons
	bra	isr_switch_left2
	btfsc	T4CON,TMR4ON					; Timer4 running?
	bra	timer4_restart					; Yes, restart
isr_switch_left2:
    
	btfss	flip_screen					; 180° flipped?
	bsf		switch_left					; NO  - set flag for left button
	btfsc	flip_screen					; 180° flipped?
	bsf		switch_right				; YES - set flag for right button
	;bra	isr_switch_common			; continue with common part

isr_switch_common:
	btfss	button_hold_down_allowed	; ignore for mechanical push buttons
	bsf 	T4CON,TMR4ON			; Start timer 4
    
	btfsc	tmr5_preemtion_allowed		; timer 5 preemption allowed?
	bsf		PIR5,TMR5IF					; YES - preempt timer 5
	movlw	TMR1H_VALUE_FIRST			; load timer 1 (in steps of 7.8125 ms)
	movwf	TMR1H						; ...
	clrf	TMR1L						; ...
	bsf		T1CON,TMR1ON				; start timer 1
	bcf		INTCON3,INT1IF				; clear ext. int 1 request
	bcf		INTCON,INT0IF				; clear ext. int 0 request
	btfsc	cc_active					; charging constant current?
	bra	isr_switch_common2				; Yes
	btfsc	cv_active					; charging constant voltage?
	bra	isr_switch_common2				; Yes
	return							; done
isr_switch_common2:
	btfss	adjustable_buttons				; Adjustable buttons?
	return							; NO - done
	; charging. Ignore (adjustable) buttons during charging
	btfsc	vusb_in						; USB plugged in?
	return							; YES, accept buttons during charge (For OSTC cR and nano)
	bcf	switch_left
	bcf	switch_right
	return							; done


;-----------------------------------------------------------------------------
; Button hold-down Interrupt
;
timer1int:
	bcf		PIR1,TMR1IF					; clear timer 1 IRQ request
	bcf		INTCON,INT0IF				; clear ext. int 0 request
	bcf		INTCON3,INT1IF				; clear ext. int 1 request

	; digital
	btfss	switch_left1				; left button hold-down?
	bra		timer1int_left				; YES
	btfss	switch_right2				; right button hold-down?
	bra		timer1int_right				; YES

	; analog
	btfsc	analog_sw2_pressed			; left button hold-down?
	bra		timer1int_left				; YES
	btfsc	analog_sw1_pressed			; right button hold-down?
	bra		timer1int_right				; YES

	; no button hold-down, stop timer 1
	bcf		T1CON,TMR1ON				; stop timer 1
	bsf		INTCON,INT0IE				; enable INT0 IRQ
	bsf		INTCON3,INT1IE				; enable INT1 IRQ
	return

timer1int_left:
	btfss	flip_screen					; 180° flipped?
	bsf		switch_left					; set flag for left button
	btfsc	flip_screen					; 180° flipped?
	bsf		switch_right				; set flag for right button
	bra		timer1int_common			; continue

timer1int_right:
	btfss	flip_screen					; 180° flipped?
	bsf		switch_right				; set flag for right button
	btfsc	flip_screen					; 180° flipped?
	bsf		switch_left					; set flag for left button
	;bra	timer1int_common			; continue

timer1int_common:						; load timer 1 for next button press
	movlw	TMR1H_VALUE_CONT			; default to surface mode value
	btfsc	divemode					; in dive mode?
	movlw	TMR1H_VALUE_CONT_DIVE		; YES - overwrite with dive mode value
	movwf	TMR1H						; write value to timer, high byte
	clrf	TMR1L						; write value to timer, low  byte (zero)
	return								; done (timer1 kept running)


;-----------------------------------------------------------------------------
; Increment Surface Interval (counted in minutes and in seconds)
;
; int_O_desaturation_time is only computed while in start, surface mode,
; menue_tree or ghostwriter. So the ISR may clock surface_interval_mins
; past the actual surface interval time. But TFT_surf_cv_lastdive will
; check int_O_desaturation_time and in case int_O_desaturation_time is
; zero it will not show surface_interval_mins but surface_interval_secs instead.
; Thus the glitch will remain invisible.
;
inc_surface_interval_secs:							; called every second when not in dive mode
	incf	surface_interval_secs+0,F				; increment the lowest byte
	clrf	WREG									; clear WREG
	addwfc	surface_interval_secs+1,F				; add carry from byte before, if it did wrap-around
	addwfc	surface_interval_secs+2,F				; add carry from byte before, if it did wrap-around
	addwfc	surface_interval_secs+3,F				; add carry from byte before, if it did wrap-around
	return											; done

inc_surface_interval_mins:							; called every minute when not in dive mode
	movff	int_O_desaturation_time+0,isr_lo		; get desaturation time, low  byte
	movff	int_O_desaturation_time+1,WREG			; get desaturation time, high byte
	iorwf	isr_lo,W								; inclusive-or low & high byte, desaturation time = 0 ?
	bz		clr_surface_interval_mins				; YES - reset surface interval minutes counter
	INCI	surface_interval_mins					; NO  - increment surface interval
	return											;     - done

rst_surface_interval:
	bcf		reset_surface_interval					; reset request flag
	; reset the surface interval counted in seconds
	clrf	surface_interval_secs+0					; reset surface interval (seconds), lowest  byte
	clrf	surface_interval_secs+1					; ...
	clrf	surface_interval_secs+2					; ...
	clrf	surface_interval_secs+3					; reset surface interval (seconds), highest byte
	; reset the surface interval counted in minutes
	movff	opt_diveTimeout,surface_interval_mins+0	; set   surface interval (minutes), low  byte, to dive timeout offset
	clrf	surface_interval_mins+1					; reset surface interval (minutes), high byte
	return											; done

clr_surface_interval_mins:
	clrf	surface_interval_mins+0					; reset surface interval (minutes), low byte
	clrf	surface_interval_mins+1					; reset surface interval (minutes), high byte
	return											; done

;-----------------------------------------------------------------------------

	END
