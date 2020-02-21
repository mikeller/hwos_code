;=============================================================================
;
;   File ms5541.asm                           combined next generation V3.0.3b
;
;   Sensor subroutines
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;  2011-08-03 : [mH] moving from OSTC code

#include "hwos.inc"						; Mandatory header
#include "math.inc"						; Math routines


ms5541	CODE

;=============================================================================
; Expose internal variables to ease debug
	global	D1, D2
	global	C1, C2, C3, C4, C5, C6
	global	xdT, xdT2, OFF, SENS, pressure_abs_avg, temperature_avg

;=============================================================================

	global calculate_compensation		; called from ISR and from sleep mode, returns in bank isr_data
calculate_compensation:
	banksel	isr_backup					; select bank ISR data

	;---- pressure sensor compensation

	; xdT = D2 - C5 (s16 range -11.400 .. +12.350)
	movf	C5+0,W						; get value to be subtracted
	subwf	D2+0,W			 			; do the low  byte
	movwf	xdT+0
	movf	C5+1,W						; do the high byte
	subwfb	D2+1,W
	movwf	xdT+1

	; second order temperature calculation

	; xdT/128 is in range -89..+96, hence signed 8 bit. dT/128 = (2*dT)/256
	rlcf	xdT+0,W						; put hit bit in carry
	rlcf	xdT+1,W						; inject in high byte
	movwf	isr_xA+0					; and put result in low byte
	clrf	isr_xA+1
	btfsc	xdT+1,7						; dT < 0 ?
	setf	isr_xA+1					; YES - sign extend to -1
	MOVII	isr_xA,isr_xB				; copy A to B
	call	isr_signed_mult16x16		; dT*dT --> xC (32 bits)

	; dT >= 0: divide by 8, i.e. 3 shifts rights
	; dT <  0: divide by 2, i.e. 1 shifts rights
	movlw	.3
	btfss	xdT+1,7						 ; was dT negative ?
	movlw	.1
calc_loop_1:
	bcf		STATUS,C					; dT^2 is positive, so injected zeros
	rrcf	isr_xC+1,F
	rrcf	isr_xC+0,F
	decfsz	WREG
	bra		calc_loop_1

	movf	isr_xC+0,W					; dT2 = dT - (dT/128)*(dT/128)/(2 ...or... 8)
	subwf	xdT+0,W
	movwf	xdT2+0
	movf	isr_xC+1,W
	subwfb	xdT+1,W
	movwf	xdT2+1

	; calculate OFF = C2 + ((C4-250)*dT2)/2^12 + 10000 (range +9.246 .. +18.887)
	MOVII	C4,  isr_xA					; C4 - 250 --> A
	MOVII	xdT2,isr_xB					; dT2      --> B
	call	isr_signed_mult16x16

	movlw	.12-.8						; a 12 bit shift = 1 byte + 4 bits
	call	isr_shift_C31

	movlw	LOW(.10000)					; add 10000
	addwf	isr_xC+1,F
	movlw	HIGH(.10000)
	addwfc	isr_xC+2,F

	movf	C2+0,W						; add C2 and store result in OFF
	addwf	isr_xC+1,W
	movwf	OFF+0
	movf	C2+1,W
	addwfc	isr_xC+2,W
	movwf	OFF+1

	; calculate SENS = C1/2 + ((C3+200)*dT)/2^13 + 3000
	movlw	LOW(.200)					; C3+200 --> A
	addwf	C3+0,W
	movwf	isr_xA+0
	movlw	HIGH(.200)
	addwfc	C3+1,W
	movwf	isr_xA+1
										; B still contains dT2
	call	isr_signed_mult16x16		; A*B --> C
	movlw	.13-.8						; A 13 bit shift = 1 byte + 5 bits
	call	isr_shift_C31

	bcf		STATUS,C					; SENS = C1 / 2
	rrcf	C1+1,W
	movwf	SENS+1
	rrcf	C1+0,W
	movwf	SENS+0

	movlw	LOW(.3000)					; add 3000
	addwf	isr_xC+1,F
	movlw	HIGH(.3000)
	addwfc	isr_xC+2,F

	movf	isr_xC+1,W					; and sum into SENS
	addwf	SENS+0,F
	movf	isr_xC+2,W
	addwfc	SENS+1,F

	; calculate absolute pressure = (sens * (d1-off))/2^12 + 1000 (For MS5541C)
	; calculate absolute pressure = (sens * (d1-off))/2^11 + 1000 (For MS5541C-30)
	movf	OFF+0,W						; d1-off --> a
	subwf	D1+0,W
	movwf	isr_xA+0
	movf	OFF+1,W
	subwfb	D1+1,W
	movwf	isr_xA+1

	MOVII	SENS,isr_xB					; sens --> b
	call	isr_signed_mult16x16
	movlw	.13
	cpfslt	C1+1		; C1 > 3328 (Must be MS5541-30)
	bra	isr_shift_ms5541_30
	; MS5541
	movlw	.12-.8						; a 12 bit shift = 1 byte + 4 bits
	call	isr_shift_C31
	bra	isr_shift_ms5541_all
isr_shift_ms5541_30:
	; MS5541-30
    	movlw	.11-.8						; a 11 bit shift = 1 byte + 3 bits
	call	isr_shift_C31
isr_shift_ms5541_all:
	movlw	LOW  .1000					; add 1000
	addwf	isr_xC+1,F
	movlw	HIGH .1000
	addwfc	isr_xC+2,F

	; add opt_pressure_adjust to result (SIGNED!)
	movff	opt_pressure_adjust,isr_xC+0; get adjustment value (signed)
	movf	isr_xC+0,F					; excite flags, opt_pressure_adjust = 0 ?
	bz		calc_compensation_1			; YES - skip pressure adjustment
	btfss	isr_xC+0,7					; NO  - opt_pressure_adjust < 0 ?
	bra		pressure_extra_add			;       NO  - add offset
	;bra	pressure_extra_sub			;       YES - subtract offset

pressure_extra_sub:
	comf	isr_xC+0,F					; complement opt_pressure_adjust
	incf	isr_xC+0,F					; ...
	movlw	.22							; check for max. of 20 mbar
	cpfslt	isr_xC+0					; opt_pressure_adjust < 21 mbar ?
	clrf	isr_xC+0					; NO - reset opt_pressure_adjust to zero
	movf	isr_xC+0,W					; get opt_pressure_adjust to WREG
	subwf	isr_xC+1,F					; pressure value -= opt_pressure_adjust, low  byte
	movlw	.0							; pressure value -= opt_pressure_adjust, high byte
	subwfb	isr_xC+2,F					; ...
	bra		calc_compensation_1			; continue with checking for simulator mode

pressure_extra_add:
	movlw	.21							; check for max. of 20 mbar
	cpfslt	isr_xC+0					; opt_pressure_adjust < 21 mbar ?
	clrf	isr_xC+0					; NO - reset opt_pressure_adjust to zero
	movf	isr_xC+0,W					; get opt_pressure_adjust to WREG
	addwf	isr_xC+1,F					; pressure value += opt_pressure_adjust, low  byte
	movlw	.0							; pressure value += opt_pressure_adjust, high byte
	addwfc	isr_xC+2,F					; ...
	;bra	calc_compensation_1			; continue with checking for simulator mode

calc_compensation_1:
	bcf		sensor_override_active		; clear sensor override active flag by default
	btfss	sensor_override_request		; sensor override requested?
	bra		calc_compensation_add_avg	; NO  - keep taking absolute pressure from sensor
	btfsc	quit_simulatormode			; YES - shall quit simulator mode (the fast way)?
	bra		calc_compensation_sim_quit	;       YES - force     pressure_rel_sim to zero
	;bra	calc_compensation_sim		;       NO  - calculate pressure_rel_sim from simulated depth

calc_compensation_sim:					; check if OSTC got submerged
	movlw	.5							; coding in high byte for 1280
	cpfsgt	isr_xC+2					; absolute pressure > 1280 mbar, i.e. OSTC submerged?
	bra		calc_compensation_sim_slave	; NO  - slave pressure_rel_sim to target depth
	;bra	calc_compensation_sim_quit	; YES - force pressure_rel_sim to zero

calc_compensation_sim_quit:
	CLRI	pressure_rel_sim			; set pressure_rel_sim to zero, this paves a restart into surface/dive mode
	bra		calc_compensation_sim_com	; continue with common part

calc_compensation_sim_slave:
	movf	simulatormode_depth,W		; copy simulated depth to WREG
	mullw	.100						; multiply with 100 to turn depth from meters to relative target pressure in mbar
	; check if shall go up
	movf	pressure_rel_sim+0,W		; get relative pressure, low  byte
	subwf	PRODL,W						; WREG = relative target pressure - pressure_rel_sim (low  byte)
	movf	pressure_rel_sim+1,W		; get relative pressure, high byte
	subwfb	PRODH,W						; WREG = relative target pressure - pressure_rel_sim (high byte)
	btfsc	STATUS,N					; result < 0, i.e. pressure_rel_sim > relative target pressure ?
	bra		calc_compensation_sim_up	; YES - decrease pressure_rel_sim
	; check if shall go down
	movf	PRODL,W						; get relative target pressure, low  byte
	subwf	pressure_rel_sim+0,W		; WREG = pressure_rel_sim - relative target pressure (low  byte)
	movf	PRODH,W						; get relative target pressure, high byte
	subwfb	pressure_rel_sim+1,W		; WREG = pressure_rel_sim - relative target pressure (high byte)
	btfsc	STATUS,N					; result < 0, i.e. relative target pressure > pressure_rel_sim ?
	bra		calc_compensation_sim_down	; YES - increase pressure_rel_sim
	; both pressures are equal
	bra		calc_compensation_sim_com	; NO to both - keep pressure_rel_sim as it is

calc_compensation_sim_up:
	movf	PRODL,W									; get relative target pressure, low  byte
	subwf	pressure_rel_sim+0,W					; WREG  = pressure_rel_sim - relative target pressure (low  byte)
	movwf	PRODL									; PRODL = pressure_rel_sim - relative target pressure (low  byte)
	movf	PRODH,W									; get relative target pressure, high byte
	subwfb	pressure_rel_sim+1,W					; WREG  = pressure_rel_sim - relative target pressure (high byte)
	tstfsz	WREG									; more than 255 mbar off from target?
	bra		calc_compensation_sim_up_norm			; YES - go up with normal speed
	movlw	simulator_ascent_threshold				; NO  - get remaining difference for slowing down ascent
	cpfslt	PRODL									;     - remaining difference to target < decrement?
	bra		calc_compensation_sim_up_norm			;       NO  - go up with normal speed
	;bra	calc_compensation_sim_up_slow			;       YES - go up with slow   speed

calc_compensation_sim_up_slow:
	DECI	pressure_rel_sim						; subtract slow decrement (1 mbar) from pressure_rel_sim
	bra		calc_compensation_sim_com				; continue with common part

calc_compensation_sim_up_norm:
	SUBLI	simulator_ascent_rate,pressure_rel_sim	; subtract normal decrement from pressure_rel_sim
	bra		calc_compensation_sim_com				; continue with common part

calc_compensation_sim_down:
	movf	pressure_rel_sim+0,W					; get relative pressure, low  byte
	subwf	PRODL,F									; PRODL = relative target pressure - pressure_rel_sim (low  byte)
	movf	pressure_rel_sim+1,W					; get relative pressure, high byte
	subwfb	PRODH,W									; WREG  = relative target pressure - pressure_rel_sim (high byte)
	tstfsz	WREG									; more than 255 mbar off from target?
	bra		calc_compensation_sim_down_norm			; YES - go down with normal speed
	movlw	simulator_descent_threshold				; NO  - get remaining difference for slowing down descent
	cpfslt	PRODL									;     - remaining difference to target < increment?
	bra		calc_compensation_sim_down_norm			;       NO  - go down with normal speed
	;bra	calc_compensation_sim_down_slow			;       YES - go down with slow   speed

calc_compensation_sim_down_slow:
	INCI	pressure_rel_sim						; add slow increment (1 mbar) to pressure_rel_sim
	bra		calc_compensation_sim_com				; continue with common part

calc_compensation_sim_down_norm:
	ADDLI	simulator_descent_rate,pressure_rel_sim	; add normal increment to pressure_rel_sim
	;bra	calc_compensation_sim_com				; continue with common part

calc_compensation_sim_com:
	movf	pressure_surf+0,W			; copy surface pressure to WREG, low  byte
	addwf	pressure_rel_sim+0,W		; add  surface pressure to relative pressure to gain simulated absolute pressure, low  byte
	movwf	isr_xC+1					; override sensor pressure with simulated pressure, low  byte
	movf	pressure_surf+1,W			; copy surface pressure to WREG, high byte
	addwfc	pressure_rel_sim+1,W		; add  surface pressure to relative pressure to gain simulated absolute pressure, high byte
	movwf	isr_xC+2					; override sensor pressure with simulated pressure, high byte
	bsf		sensor_override_active		; confirm sensor override is active

calc_compensation_add_avg:
	; add current absolute pressure to averaging buffer
	movf	isr_xC+1,W					; copy current absolute pressure to WREG, low  byte
	addwf	pressure_abs_avg+0,F		; pressure_abs_avg += current pressure,   low  byte
	movf	isr_xC+2,W					; copy current absolute pressure to WREG, high byte
	addwfc	pressure_abs_avg+1,F		; pressure_abs_avg += current pressure,   high byte

	;---- temperature sensor compensation

	; calculate temp = 200 + dT*(C6+100)/2^11
	movlw	LOW(.100)					; C6 + 100 --> A
	addwf	C6+0,W
	movwf	isr_xA+0
	movlw	HIGH(.100)
	addwfc	C6+1,W
	movwf	isr_xA+1

	MOVII	xdT2,isr_xB					; dT2 --> B
	call	isr_signed_mult16x16		; A*B
	movlw	.11-.8						; a 12 bit shift = 1 byte + 3 bits
	call	isr_shift_C31

	movlw	LOW(.200)					; add 200
	addwf	isr_xC+1,F
	movlw	HIGH(.200)
	addwfc	isr_xC+2,F

	; add opt_temperature_adjust to result (SIGNED!)
	movff	opt_temperature_adjust,isr_xC+0

	btfss	isr_xC+0,7					; < 0 ?
	bra		temperature_extra_add		; NO
	comf	isr_xC+0,F					; YES
	incf	isr_xC+0,F
	movlw	.22							; check for max. of 2.0°C
	cpfslt	isr_xC+0
	clrf	isr_xC+0
	movf	isr_xC+0,W					; subtract
	subwf	isr_xC+1,F
	movlw	.0
	subwfb	isr_xC+2,F
	bra		temperature_extra_common

temperature_extra_add:
	movlw	.21							; check for max. of 2.0°C
	cpfslt	isr_xC+0
	clrf	isr_xC+0
	movf	isr_xC+0,W					; add
	addwf	isr_xC+1,F
	movlw	.0
	addwfc	isr_xC+2,F

temperature_extra_common:
	movf	isr_xC+1,W
	addwf	temperature_avg+0,F
	movf	isr_xC+2,W
	addwfc	temperature_avg+1,F

	return								; done

;=============================================================================

	global	get_pressure_start			; called from ISR and sleep mode, needs to be called bank isr_backup
get_pressure_start:
	rcall	reset_MS5541
	movlw	b'10100000'					; +3*high as start and 1+low as stop
	movwf	dbuffer
	movlw	d'12'
	rcall	send_data_MS5541
	return

	global get_pressure_value			; called from ISR and sleep mode, needs to be called bank isr_backup
get_pressure_value:
	btfsc	MS5541_miso					; conversion done?
	return								; NO - done
	rcall	get_2bytes_MS5541
	movff	dMSB,D1+1
	movff	dLSB,D1+0
	return

;=============================================================================

	global	get_temperature_start		; called from ISR and sleep mode, needs to be called in bank isr_backup
get_temperature_start:
	rcall	reset_MS5541
	movlw	b'10010000'					; +3*high as start and 1+low as stop
	movwf	dbuffer
	movlw	d'12'
	rcall	send_data_MS5541
	return


	global	get_temperature_value		; called from ISR and sleep mode, needs to be called in bank isr_backup
get_temperature_value:
	btfsc	MS5541_miso					; conversion done?
	return								; NO - done
	rcall	get_2bytes_MS5541
	movff	dMSB,D2+1
	movff	dLSB,D2+0
	return

;=============================================================================

	global	get_calibration_data		; called by start, returns in bank common
get_calibration_data:
	banksel	isr_backup					; select bank ISR data
	bsf		block_sensor_interrupt		; disable sensor interrupts

	rcall	reset_MS5541
	movlw	b'01010100'					; +3*high as start and 1+low as stop
	movwf	dbuffer
	movlw	d'13'
	rcall	send_data_MS5541
	rcall	get_2bytes_MS5541
	movff	dMSB,ir_s8_buffer+1
	movff	dLSB,ir_s8_buffer+0

	movlw	b'01011000'					; +3*high as start and 1+low as stop
	movwf	dbuffer
	movlw	d'13'
	rcall	send_data_MS5541
	rcall	get_2bytes_MS5541
	movff	dMSB,ir_s8_buffer+3
	movff	dLSB,ir_s8_buffer+2

	movlw	b'01100100'					; +3*high as start and 1+low as stop
	movwf	dbuffer
	movlw	d'13'
	rcall	send_data_MS5541
	rcall	get_2bytes_MS5541
	movff	dMSB,ir_s8_buffer+5
	movff	dLSB,ir_s8_buffer+4

	movlw	b'01101000'					; +3*high as start and 1+low as stop
	movwf	dbuffer
	movlw	d'13'
	rcall	send_data_MS5541
	rcall	get_2bytes_MS5541
	movff	dMSB,ir_s8_buffer+7
	movff	dLSB,ir_s8_buffer+6

	; calculate C1 (16Bit)
	movff	ir_s8_buffer+1, C1+1
	bcf		STATUS,C
	rrcf	C1+1
	bcf		STATUS,C
	rrcf	C1+1
	bcf		STATUS,C
	rrcf	C1+1
	movff	ir_s8_buffer+0, C1+0
	bsf		STATUS,C
	btfss	ir_s8_buffer+1,0
	bcf		STATUS,C
	rrcf	C1+0
	bsf		STATUS,C
	btfss	ir_s8_buffer+1,1
	bcf		STATUS,C
	rrcf	C1+0
	bsf		STATUS,C
	btfss	ir_s8_buffer+1,2
	bcf		STATUS,C
	rrcf	C1+0

	; calculate C2 (16Bit)
	movff	ir_s8_buffer+2, C2+0
	bsf		STATUS,C
	btfss	ir_s8_buffer+3,0
	bcf		STATUS,C
	rrcf	C2+0
	bsf		STATUS,C
	btfss	ir_s8_buffer+3,1
	bcf		STATUS,C
	rrcf	C2+0
	bsf		STATUS,C
	btfss	ir_s8_buffer+3,2
	bcf		STATUS,C
	rrcf	C2+0
	bsf		STATUS,C
	btfss	ir_s8_buffer+3,3
	bcf		STATUS,C
	rrcf	C2+0
	bsf		STATUS,C
	btfss	ir_s8_buffer+3,4
	bcf		STATUS,C
	rrcf	C2+0
	bsf		STATUS,C
	btfss	ir_s8_buffer+3,5
	bcf		STATUS,C
	rrcf	C2+0

	movff	ir_s8_buffer+3, C2+1
	bsf		STATUS,C
	btfss	ir_s8_buffer+0,0
	bcf		STATUS,C
	rrcf	C2+1
	bsf		STATUS,C
	btfss	ir_s8_buffer+0,1
	bcf		STATUS,C
	rrcf	C2+1
	bsf		STATUS,C
	btfss	ir_s8_buffer+0,2
	bcf		STATUS,C
	rrcf	C2+1
	bcf		STATUS,C
	rrcf	C2+1
	bcf		STATUS,C
	rrcf	C2+1
	bcf		STATUS,C
	rrcf	C2+1

	; calculate C3 (16Bit)
	movff	ir_s8_buffer+5,C3+0
	bsf		STATUS,C
	btfss	ir_s8_buffer+4,7
	bcf		STATUS,C
	rlcf	C3+0
	bsf		STATUS,C
	btfss	ir_s8_buffer+4,6
	bcf		STATUS,C
	rlcf	C3+0
	clrf	C3+1
	btfsc	ir_s8_buffer+5,7
	bsf		C3+1,1
	btfsc	ir_s8_buffer+5,6
	bsf		C3+1,0

	; calculate C4 (16Bit)
	movff	ir_s8_buffer+7,C4+0
	bsf		STATUS,C
	btfss	ir_s8_buffer+6,7
	bcf		STATUS,C
	rlcf	C4+0
	clrf	C4+1
	btfsc	ir_s8_buffer+7,7
	bsf		C4+1,0

	; C4=C4-250
	movlw	LOW(-.250)					; C4 - 250 --> C4
	addwf	C4+0,W
	movwf	C4+0
	movlw	-1							; HIGH(- .250) is not understood...
	addwfc	C4+1,W
	movwf	C4+1

	; calculate C5 (16Bit)
	movff	ir_s8_buffer+4,C5+0
	bcf		C5+0,6
	btfsc	ir_s8_buffer+2,0
	bsf		C5+0,6
	bcf		C5+0,7
	btfsc	ir_s8_buffer+2,1
	bsf		C5+0,7
	clrf	C5+1
	btfsc	ir_s8_buffer+2,2
	bsf		C5+1,0
	btfsc	ir_s8_buffer+2,3
	bsf		C5+1,1
	btfsc	ir_s8_buffer+2,4
	bsf		C5+1,2
	btfsc	ir_s8_buffer+2,5
	bsf		C5+1,3

	; calculate C5 = UT1
	; C5 = 8*C5 + 10000 (u16 range 10.000 .. +42.760)
	clrf	isr_xA+1
	movlw	d'8'
	movwf	isr_xA+0
	MOVII	C5,isr_xB
	call	isr_unsigned_mult16x16		; isr_xA*isr_xB=isr_xC
	MOVII	isr_xC,C5
	movlw	LOW  d'10000'
	addwf	C5+0,F
	movlw	HIGH d'10000'
	addwfc	C5+1,F						; = 8*C5 + 10000

	; calculate C6 (16Bit)
	clrf	C6+1
	movff	ir_s8_buffer+6,C6+0
	bcf		C6+0,7

	clrf	sensor_state_counter		; reset state counter
	bcf		block_sensor_interrupt		; re-enable sensor interrupts
	banksel	common						; back to bank common
	return								; done

;=============================================================================
reset_MS5541_one:
	bsf		MS5541_mosi
	bra		send_clk_pulse				; send one high-low sequence on MS5541_clk and return

reset_MS5541_zero:
	bcf		MS5541_mosi
	bra		send_clk_pulse				; send one high-low sequence on MS5541_clk and return

reset_MS5541:
	rcall	reset_MS5541_one			; 0
	rcall	reset_MS5541_zero
	rcall	reset_MS5541_one
	rcall	reset_MS5541_zero
	rcall	reset_MS5541_one
	rcall	reset_MS5541_zero
	rcall	reset_MS5541_one
	rcall	reset_MS5541_zero
	rcall	reset_MS5541_one
	rcall	reset_MS5541_zero
	rcall	reset_MS5541_one
	rcall	reset_MS5541_zero
	rcall	reset_MS5541_one
	rcall	reset_MS5541_zero
	rcall	reset_MS5541_one
	rcall	reset_MS5541_zero			; 15
	rcall	reset_MS5541_zero
	rcall	reset_MS5541_zero
	rcall	reset_MS5541_zero
	rcall	reset_MS5541_zero
	rcall	reset_MS5541_zero			; 20
	return


get_2bytes_MS5541:
	movlw	d'8'
	movwf	clock_count
	rcall	recieve_loop
	movff	dbuffer,dMSB
	movlw	d'8'
	movwf	clock_count
	rcall	recieve_loop
	movff	dbuffer,dLSB
	bra		send_clk_pulse				; send one high-low sequence on MS5541_clk and return

recieve_loop:
	rcall	send_clk_pulse				; send one high-low sequence on MS5541_clk
	btfss	MS5541_miso					; MSB first
	bcf		STATUS,C
	btfsc	MS5541_miso					; MSB first
	bsf		STATUS,C
	rlcf	dbuffer,F
	decfsz	clock_count,F
	bra		recieve_loop
	return

send_clk_pulse:
	bsf		MS5541_clk
	nop
	nop
	nop
	nop
	nop
	nop
	bcf		MS5541_clk
	nop
	nop
	nop
	nop
	return


send_data_MS5541:
	movwf	clock_count					; from WREG
	; send three start bits first
	bcf		MS5541_clk
	nop
	nop
	bsf		MS5541_mosi
	movlw	d'3'
	subwf	clock_count,F				; total bit counter
	rcall	send_clk_pulse				; send one high-low sequence on MS5541_clk
	rcall	send_clk_pulse				; send one high-low sequence on MS5541_clk
	rcall	send_clk_pulse				; send one high-low sequence on MS5541_clk
send_data_MS5541_loop:					; now send 8 bits from dbuffer and fill-up with zeros
	bcf		MS5541_clk
	nop
	nop
	btfss	dbuffer,7					; MSB first
	bcf		MS5541_mosi
	btfsc	dbuffer,7					; MSB first
	bsf		MS5541_mosi
	bsf		MS5541_clk
	bcf		STATUS,C
	rlcf	dbuffer,F
	nop
	nop
;	nop
;	nop
;	nop
;	nop
;	bcf		MS5541_clk
	decfsz	clock_count,F
	bra		send_data_MS5541_loop
	bcf		MS5541_clk
	return

	END