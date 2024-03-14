;=============================================================================
;
;   File ms5541.asm                          * combined next generation V3.9.4f
;
;   Sensor Subroutines
;
;   Copyright (c) 2011, JD Gascuel, heinrichs weikamp gmbh, all right reserved.
;=============================================================================
; HISTORY
;  2011-08-03 : [mH] moving from OSTC code

#include "hwos.inc"						; Mandatory header
#include "math.inc"						; Math routines
#include "i2c.inc"
#include "shared_definitions.h"				; mailbox from/to p2_deco.c

ms5541	CODE


; Expose internal variables to ease debug
	global	D1, D2
	global	C1, C2, C3, C4, C5, C6
	global	xdT, xdT2, OFF, SENS, pressure_abs_avg, temperature_avg


;-----------------------------------------------------------------------------
; Convert Temperature & Pressure raw Values to compensated Values
;
; called from ISR and from sleep mode, returns in bank isr_data
;
	global calculate_compensation
calculate_compensation:
	banksel	isr_backup					; select bank ISR data

	btfsc	press_sensor_type			; New sensor found?
	bra 	press_comp_ms5837			; Yes, use MS5837

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
	movlw	.3							; 3 shifts by default
	btfss	xdT+1,7						; was dT negative ?
	movlw	.1							; YES - replace by 1 shift
calc_loop_1:
	bcf		STATUS,C					; dT^2 is positive, so injecte zeros
	rrcf	isr_xC+1,F					; shift right high byte
	rrcf	isr_xC+0,F					; shift right low  byte
	decfsz	WREG						; decrement loop counter, all shifts done?
	bra		calc_loop_1					; NO  - loop

	movf	isr_xC+0,W					; dT2 = dT - (dT/128)*(dT/128)/(2 ...or... 8)
	subwf	xdT+0,W						; ...
	movwf	xdT2+0						; ...
	movf	isr_xC+1,W					; ...
	subwfb	xdT+1,W						; ...
	movwf	xdT2+1						; ...

	; calculate OFF = C2 + ((C4-250)*dT2)/2^12 + 10000 (range +9.246 .. +18.887)
	MOVII	C4,  isr_xA					; C4 - 250 --> A
	MOVII	xdT2,isr_xB					; dT2      --> B
	call	isr_signed_mult16x16		; C = A*B

	movlw	.12-.8						; a 12 bit shift = 1 byte + 4 bits
	call	isr_shift_C31				; special shift

	movlw	LOW(.10000)					; add 10000
	addwf	isr_xC+1,F					; ...
	movlw	HIGH(.10000)				; ...
	addwfc	isr_xC+2,F					; ...

	movf	C2+0,W						; add C2 and store result in OFF
	addwf	isr_xC+1,W					; ...
	movwf	OFF+0						; ...
	movf	C2+1,W						; ...
	addwfc	isr_xC+2,W					; ...
	movwf	OFF+1						; ...

	; calculate SENS = C1/2 + ((C3+200)*dT)/2^13 + 3000
	movlw	LOW(.200)					; C3+200 --> A
	addwf	C3+0,W						; ...
	movwf	isr_xA+0					; ...
	movlw	HIGH(.200)					; ...
	addwfc	C3+1,W						; ...
	movwf	isr_xA+1					; ...
										; B still contains dT2
	call	isr_signed_mult16x16		; C = A*B
	movlw	.13-.8						; A 13 bit shift = 1 byte + 5 bits
	call	isr_shift_C31				; special shift

	bcf		STATUS,C					; SENS = C1 / 2
	rrcf	C1+1,W						; ...
	movwf	SENS+1						; ...
	rrcf	C1+0,W						; ...
	movwf	SENS+0						; ...

	movlw	LOW(.3000)					; add 3000
	addwf	isr_xC+1,F					; ...
	movlw	HIGH(.3000)					; ...
	addwfc	isr_xC+2,F					; ...

	movf	isr_xC+1,W					; and sum into SENS
	addwf	SENS+0,F					; ...
	movf	isr_xC+2,W					; ...
	addwfc	SENS+1,F					; ...

	; calculate absolute pressure = (sens * (d1-off))/2^12 + 1000 (for MS5541C)
	; calculate absolute pressure = (sens * (d1-off))/2^11 + 1000 (for MS5541C-30)
	movf	OFF+0,W						; d1-off --> a
	subwf	D1+0,W						; ...
	movwf	isr_xA+0					; ...
	movf	OFF+1,W						; ...
	subwfb	D1+1,W						; ...
	movwf	isr_xA+1					; ...

	MOVII	SENS,isr_xB					; sens --> B
	call	isr_signed_mult16x16		; C = A*B
	movlw	.15							; 15 * 256 = 3840
	cpfslt	C1+1						; C1 > 3328 ?
	bra		isr_shift_ms5541_30			; YES - MS5541-30
	movlw	.12-.8						; NO  - MS5541: 12 bit shift = 1 byte + 4 bits
	bra		isr_shift_ms5541_common		;     - continue
isr_shift_ms5541_30:
	movlw	.11-.8						; MS5541-30:    11 bit shift = 1 byte + 3 bits
isr_shift_ms5541_common:
	call	isr_shift_C31				; special shift
	movlw	LOW  .1000					; add 1000
	addwf	isr_xC+1,F					; ...
	movlw	HIGH .1000					; ...
	addwfc	isr_xC+2,F					; ...
	bra	press_comp_done_common

press_comp_ms5837:
 	; xdT = D2 - C5*2^8
	movlw	.0		; Low
	subwf	D2+0,W
	movwf	xdT+0
	movf	C5+0,W		; High
	subwfb	D2+1,W
	movwf	xdT+1
	movf	C5+1,W		; Upper
	subwfb	D2+2,W
	movwf	xdT+2
	; xdT equals D2 - (C5*2^8)
	
	; Calculate OFF = C2*2^16+(C4*xdT)/2^7
	movff	C4+0,isr_xA+0
	movff	C4+1,isr_xA+1
	clrf	isr_xA+2
	movff	xdT+0,isr_xB+0
	movff	xdT+1,isr_xB+1
	movff	xdT+2,isr_xB+2
	call	isr_signed_mult24x24		; C = A*B
	; isr_xC:6 equals (C4*xdT)
	rlcf	isr_xC+0,F
	rlcf	isr_xC+1,F
	rlcf	isr_xC+2,F
	rlcf	isr_xC+3,F
	rlcf	isr_xC+4,F
	rlcf	isr_xC+5,F
	movff	isr_xC+1,OFF+0
	movff	isr_xC+2,OFF+1
	movff	isr_xC+3,OFF+2
	movff	isr_xC+4,OFF+3
	; OFF equals (C4*xdT)/2^7
	movf	C2+0,W
	addwf	OFF+2,F
	movf	C2+1,W
	addwfc	OFF+3,F
	; OFF equals C2*2^16+((C4*xdT)/2^7)
	
	; Calculate SENS = C1*2^15 + (C3*xdT)/2^8
	MOVII	C1,isr_xA
	movlw	LOW	(.32768)
	movwf	isr_xB+0
	movlw	HIGH	(.32768)
	movwf	isr_xB+1
	call	isr_unsigned_mult16x16		; C = A*B
	movff	isr_xC+0,SENS+0
	movff	isr_xC+1,SENS+1
	movff	isr_xC+2,SENS+2
	movff	isr_xC+3,SENS+3			; 32bit copy
	; SENS equals C1*2^15
	movff	C3+0,isr_xA+0
	movff	C3+1,isr_xA+1
	clrf	isr_xA+2
	movff	xdT+0,isr_xB+0
	movff	xdT+1,isr_xB+1
	movff	xdT+2,isr_xB+2
	call	isr_signed_mult24x24		; C = A*B
	; isr_xC:6 equals (C3*xdT)
	movf	isr_xC+1,W
	addwf	SENS+0,F
	movf	isr_xC+2,W
	addwfc	SENS+1,F
	movf	isr_xC+3,W
	addwfc	SENS+2,F
	movf	isr_xC+4,W
	addwfc	SENS+3,F
	; SENS equals C1*2^15 + (C3*xdT)/2^8

	; Calculate PRESSURE = ((D1 * SENS) / 2^21) - OFF) / 2^13
	movff	SENS+0,isr_xA+0
	movff	SENS+1,isr_xA+1
	movff	SENS+2,isr_xA+2
	movff	SENS+3,isr_xA+3
	movff	D1+0,isr_xB+0
	movff	D1+1,isr_xB+1
	movff	D1+2,isr_xB+2
	call	isr_unsigned_mult32x24		; C = A*B
	; isr_xC:7 equals D1*SENS

	; devide isr_xC:7 / 2^21 -> shift right 21 times
	movlw	.21
press_comp_ms5837_2:
	bcf	STATUS,C					; clear carry, needed for MS5837 use
	rrcf	isr_xC+6,F
	rrcf	isr_xC+5,F
	rrcf	isr_xC+4,F
	rrcf	isr_xC+3,F
	rrcf	isr_xC+2,F
	rrcf	isr_xC+1,F
	rrcf	isr_xC+0,F
	decfsz	WREG						; decrement loop counter, done?
	bra	press_comp_ms5837_2			; NO  - loop		
	; isr_xC:6 equals (D1*SENS)/2^21
	
	; Calculate isr_xC:6-OFF
	movf	OFF+0,W	    ; Low
	subwf	isr_xC+0,F
	movf	OFF+1,W	    ; High
	subwfb	isr_xC+1,F
	movf	OFF+2,W	    ; Upper
	subwfb	isr_xC+2,F
	movf	OFF+3,W	    ; Extra
	subwfb	isr_xC+3,F
	movlw	.0	    ; ultra
	subwfb	isr_xC+4,F
	movlw	.0	    ; Hyper
	subwfb	isr_xC+5,F
	; isr_xC:5 is now isr_xC:4-OFF
	
	; devide by 2^13
	; devide isr_xC:6 / 2^13 -> shift right 13 times
	movlw	.13
press_comp_ms5837_3:
	bcf	STATUS,C					; clear carry
	rrcf	isr_xC+5,F
	rrcf	isr_xC+4,F
	rrcf	isr_xC+3,F
	rrcf	isr_xC+2,F
	rrcf	isr_xC+1,F
	rrcf	isr_xC+0,F
	decfsz	WREG						; decrement loop counter, done?
	bra	press_comp_ms5837_3			; NO  - loop		
	; isr_xC:4 equals pressure in .1 mbar

	movlw	.10
	movwf	isr_xB+0
	clrf	isr_xB+1
	call	isr_div32x16				; isr_xC:4 = isr_xC:4 / isr_xB:2 with isr_xA as remainder
	; isr_xC:2 equals pressure in 1mbar

	; copy for compatibility of the next routines
	movff	isr_xC+1,isr_xC+2
	movff	isr_xC+0,isr_xC+1
	
press_comp_done_common:						; continue here even with MS5837
	; add opt_pressure_adjust to result (SIGNED!)
	clrf	isr_xC+0					; prepare high byte for adjustment
	movff	opt_pressure_adjust,WREG	; get     low  byte for adjustment (signed)
	movf	WREG,W						; excite flags
	bz		calc_compensation_1			; opt_pressure_adjust = 0 -> skip adjustment
	btfss	STATUS,N					; opt_pressure_adjust < 0 ?
	bra		calc_compensation_adjust	; NO  - positive
	negf	WREG						; YES - negate opt_pressure_adjust for limit check
	setf	isr_xC+0					;     - adopt high byte for adjustment
calc_compensation_adjust:
	addlw	-.21						; limit is 20 mbar, subtract 21
	bnn		calc_compensation_1			; result not negative -> skip adjustment
	movff	opt_pressure_adjust,WREG	; get opt_pressure_adjust,               low  byte
	addwf	isr_xC+1,F					; pressure value += opt_pressure_adjust, low  byte
	movf	isr_xC+0,W					; get adjustment,                        high byte
	addwfc	isr_xC+2,F					; pressure value += opt_pressure_adjust, high byte

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
	movlw	.0
	addwfc	pressure_abs_avg+2,F		; pressure_abs_avg += current pressure,   upper byte

	;---- temperature sensor compensation

    	btfsc	press_sensor_type			; New sensor found?
	bra	temp_comp_ms5837			; Yes, use MS5837
	
	; calculate temp = 200 + dT*(C6+100)/2^11
	movlw	LOW(.100)					; C6 + 100 --> A
	addwf	C6+0,W						; ...
	movwf	isr_xA+0					; ...
	movlw	HIGH(.100)					; ...
	addwfc	C6+1,W						; ...
	movwf	isr_xA+1					; ...

	MOVII	xdT2,isr_xB					; dT2 --> B
	call	isr_signed_mult16x16		; A*B
	movlw	.11-.8						; a 12 bit shift = 1 byte + 3 bits
	call	isr_shift_C31				; special shift

	movlw	LOW(.200)					; add 200
	addwf	isr_xC+1,F					; ...
	movlw	HIGH(.200)					; ...
	addwfc	isr_xC+2,F					; ...
	bra	temp_comp_done_common

temp_comp_ms5837:
    	; TEMP = 2000+((xdT * C6) / 2^23)
	
	; xdT * C6 -> isr_xC:6
	movff	C6+0,isr_xA+0
	movff	C6+1,isr_xA+1
	clrf	isr_xA+2
	movff	xdT+0,isr_xB+0
	movff	xdT+1,isr_xB+1
	movff	xdT+2,isr_xB+2
	call	isr_signed_mult24x24		; A*B
	
	; devide isr_xC:6 / 2^23 -> shift right 23 times
	; a special variant (again): We loose isr_xC+0 and isr_xC+1 anyway 
	; and do not care about the inserted carry since we won't use isr_xC+5 
	; and we shift less then 8 bytes
	movlw	.23-.16	    
temp_comp_ms5837_2:
	rrcf	isr_xC+5,F					; 
        rrcf	isr_xC+4,F					; 
	rrcf	isr_xC+3,F					; 
	rrcf	isr_xC+2,F					; ...
	decfsz	WREG						; decrement loop counter, done?
	bra	temp_comp_ms5837_2			; NO  - loop	

	; only use +2 and +3
	movlw	LOW(.2000)					; add 2000
	addwf	isr_xC+2,F					; ...
	movlw	HIGH(.2000)					; ...
	addwfc	isr_xC+3,F					; ...

	; devide by 10 for .1°C resolution
	movlw	.10
	movwf	isr_xB+0
	clrf	isr_xB+1
	movff	isr_xC+2,isr_xA+0
	movff	isr_xC+3,isr_xA+1

	btfss	isr_xC+3,7		    ; check sign bit
	bra	temp_comp_ms5837_3	    ; not negative...
	; negate isr_xA:2 to make it positive
	comf	isr_xA+1		    ; 16 bit sign change
	negf	isr_xA+0
	btfsc	STATUS,C		    ; - carry to propagate?
	incf	isr_xA+1,F		    ;  YES - do it

temp_comp_ms5837_3:
	call	isr_div16x16					; isr_xC:2 = isr_xA:2 / isr_xB:2

	btfss	isr_xC+3,7		    ; check sign bit again
	bra	temp_comp_ms5837_4	    ; not negative...
	; negate result isr_xC:2 to make it negative again
	comf	isr_xC+1		    ; 16 bit sign change
	negf	isr_xC+0
	btfsc	STATUS,C		    ;- carry to propagate?
	incf	isr_xC+1,F		    ; YES - do it
	
temp_comp_ms5837_4:	
	; copy for compatibility of the next routines
	movff	isr_xC+1,isr_xC+2
	movff	isr_xC+0,isr_xC+1
	
temp_comp_done_common:						; continue here even with MS5837	
	; add opt_temperature_adjust to result (SIGNED!)
	clrf	isr_xC+0					; prepare high byte for adjustment
	movff	opt_temperature_adjust,WREG	; get     low  byte for adjustment (signed)
	movf	WREG,W						; excite flags
	bz		calc_temperature_add_avg	; opt_temperature_adjust = 0 -> skip adjustment
	btfss	STATUS,N					; opt_temperature_adjust < 0 ?
	bra		calc_temperature_adjust		; NO  - positive
	negf	WREG						; YES - negate opt_temperature_adjust for limit check
	setf	isr_xC+0					;     - adopt high byte for adjustment
calc_temperature_adjust:
	addlw	-.21						; limit is 2.0°C, subtract 21 (scaling is 0.1°C)
	bnn		calc_temperature_add_avg	; result not negative -> skip adjustment
	movff	opt_temperature_adjust,WREG	; get opt_temperature_adjust,                  low  byte
	addwf	isr_xC+1,F					; temperature value += opt_temperature_adjust, low  byte
	movf	isr_xC+0,W					; get adjustment                               high byte
	addwfc	isr_xC+2,F					; temperature value += opt_temperature_adjust, high byte

calc_temperature_add_avg:
	movf	isr_xC+1,W					; copy current temperature to WREG,       low  byte
	addwf	temperature_avg+0,F			; temperature_avg += current temperature, low  byte
	movf	isr_xC+2,W					; copy current temperature to WREG,       high byte
	addwfc	temperature_avg+1,F			; temperature_avg += current temperature, high byte
	return								; done


;-----------------------------------------------------------------------------
; Start Pressure Measurement
;
; called from ISR and sleep mode, needs to be called in bank isr_backup
;
	global	get_pressure_start
get_pressure_start:
       	btfsc	press_sensor_type			; New sensor found?
	return						; Yes, ignore routine
	rcall	reset_MS5541				; reset the chip
	movlw	b'10100000'					; +3*high as start and 1+low as stop
	movwf	dbuffer						; ....
	movlw	d'12'						; send start command
	bra 	send_data_MS5541				; ... (And return)


;-----------------------------------------------------------------------------
; Read Pressure Measurement Result
;
; called from ISR and sleep mode, needs to be called in bank isr_backup
;
	global get_pressure_value
get_pressure_value:
       	btfsc	press_sensor_type			; New sensor found?
	bra	get_pressure_value2
	btfsc	MS5541_miso					; conversion done?
	return								; NO  - abort
	rcall	get_2bytes_MS5541			; YES - read result
	movff	dMSB,D1+1					; copy result to D1, high byte first
	movff	dLSB,D1+0					; ...                low  byte second
	return								; done

get_pressure_value2:	
	btfsc	i2c_busy_pressure			; currently updating pressure?
	return						; Yes, skip update...
	movff	D1_buffer+0,D1+0
	movff	D1_buffer+1,D1+1
	movff	D1_buffer+2,D1+2
	return
	

;-----------------------------------------------------------------------------
; Start Temperature Measurement
;
; called from ISR and sleep mode, needs to be called in bank isr_backup
;
	global	get_temperature_start
get_temperature_start:
       	btfsc	press_sensor_type			; New sensor found?
	return						; Yes, ignore routine
	rcall	reset_MS5541				; reset chip
	movlw	b'10010000'					; +3*high as start and 1+low as stop
	movwf	dbuffer						; ...
	movlw	d'12'						; send start command
	bra	send_data_MS5541				; ... (And return)


;-----------------------------------------------------------------------------
; Read Pressure Measurement Result
;
; called from ISR and sleep mode, needs to be called in bank isr_backup
;
	global	get_temperature_value
get_temperature_value:
	btfsc	press_sensor_type			; New sensor found?
	bra	get_temperature_value2
	btfsc	MS5541_miso					; conversion done?
	return								; NO - done
	rcall	get_2bytes_MS5541			; YES - read result
	movff	dMSB,D2+1					; copy result to D2, high byte first
	movff	dLSB,D2+0					; ...                low  byte second
	return								; done

get_temperature_value2:
	btfsc	i2c_busy_temperature			; currently updating temperature?
	return						; Yes, skip update...
	movff	D2_buffer+0,D2+0
	movff	D2_buffer+1,D2+1
	movff	D2_buffer+2,D2+2
	return
	

;-----------------------------------------------------------------------------
; Retrieve Calibration Data
;
; called by start, returns in bank common
;
	global	get_calibration_data
get_calibration_data:
	banksel	isr_backup					; select bank ISR data
	bsf	    block_sensor_interrupt		; disable sensor interrupts

	btfsc	press_sensor_type			; New sensor found?
	call	I2C_get_calib_MS5837			; Yes, read C1 to C6
	banksel	isr_backup					; select bank ISR data
	; double-check sensor type
	movlw	0xED
	cpfseq	C1+0
	bra	get_calibration_data1			; Not 0xED (I2C address false reading)
	movlw	0xED
	cpfseq	C1+1
	bra	get_calibration_data1			; Not 0xED (I2C address false reading)
	movlw	0xED
	cpfseq	C5+0
	bra	get_calibration_data1			; Not 0xED (I2C address false reading)
	movlw	0xED
	cpfseq	C5+1
	bra	get_calibration_data1			; Not 0xED (I2C address false reading)
	
	; C1 and C5 are 0xEDED -> NOT Sensor 1
	bcf	press_sensor_type
	
get_calibration_data1:	
	btfsc	press_sensor_type			; New sensor found?
	bra	get_calibration_data2			; Yes, skip to the end
	
	rcall	reset_MS5541				; reset chip

	movlw	b'01010100'					; +3*high as start and 1+low as stop
	movwf	dbuffer						; ...
	movlw	d'13'						; send command
	rcall	send_data_MS5541			; ...
	rcall	get_2bytes_MS5541			; read result
	movff	dMSB,ir_s8_buffer+1			; copy result, high byte first
	movff	dLSB,ir_s8_buffer+0			; copy result, low  byte second

	movlw	b'01011000'					; +3*high as start and 1+low as stop
	movwf	dbuffer						; ...
	movlw	d'13'						; send command
	rcall	send_data_MS5541			; ...
	rcall	get_2bytes_MS5541			; read result
	movff	dMSB,ir_s8_buffer+3			; copy result, high byte first
	movff	dLSB,ir_s8_buffer+2			; copy result, low  byte second

	movlw	b'01100100'					; +3*high as start and 1+low as stop
	movwf	dbuffer						; ...
	movlw	d'13'						; send command
	rcall	send_data_MS5541			; ...
	rcall	get_2bytes_MS5541			; read result
	movff	dMSB,ir_s8_buffer+5			; copy result, high byte first
	movff	dLSB,ir_s8_buffer+4			; copy result, low  byte second

	movlw	b'01101000'					; +3*high as start and 1+low as stop
	movwf	dbuffer						; ...
	movlw	d'13'						; send command
	rcall	send_data_MS5541			; ...
	rcall	get_2bytes_MS5541			; read result
	movff	dMSB,ir_s8_buffer+7			; copy result, high byte first
	movff	dLSB,ir_s8_buffer+6			; copy result, low  byte second

	; calculate C1 (16 Bit)
	movff	ir_s8_buffer+1,C1+1
	bcf		STATUS,C
	rrcf	C1+1
	bcf		STATUS,C
	rrcf	C1+1
	bcf		STATUS,C
	rrcf	C1+1
	movff	ir_s8_buffer+0,C1+0
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

	; calculate C2 (16 Bit)
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

	; calculate C3 (16 Bit)
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

	; calculate C4 (16 Bit)
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

	; calculate C5 (16 Bit)
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

get_calibration_data2:
	clrf	sensor_state_counter		; reset state counter
	bcf		block_sensor_interrupt		; re-enable sensor interrupts
	banksel	common						; back to bank common
	return								; done


;-----------------------------------------------------------------------------
; Helper Function - Reset Chip
;
reset_MS5541_one:
	bsf		MS5541_mosi					; set MOSI
	bra		send_clk_pulse				; send one high-low sequence on MS5541_clk and return

reset_MS5541_zero:
	bcf		MS5541_mosi					; clear MOSI
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


;-----------------------------------------------------------------------------
; Helper Function - read 2 Byte from Chip
;
get_2bytes_MS5541:
	movlw	d'8'						; load counter for 8 bit
	movwf	clock_count					; ...
	rcall	recieve_loop				; receive 8 bits
	movff	dbuffer,dMSB				; store result
	movlw	d'8'						; load counter for 8 bit
	movwf	clock_count					; ...
	rcall	recieve_loop				; receive 8 bits
	movff	dbuffer,dLSB				; store result
	bra		send_clk_pulse				; send one high-low sequence on MS5541_clk and return


;-----------------------------------------------------------------------------
; Helper Function - read 1 Bit from Chip
;
recieve_loop:
	rcall	send_clk_pulse				; send one high-low sequence on MS5541_clk
	btfss	MS5541_miso					; read bit = 1 ? (MSB first)
	bcf		STATUS,C					; NO - clear carry bit
	btfsc	MS5541_miso					; read bit = 0 ? (MSB first)
	bsf		STATUS,C					; NO - set   carry bit
	rlcf	dbuffer,F					; shift buffer
	decfsz	clock_count,F				; decrement counter, became zero?
	bra		recieve_loop				; NO  - loop
	return								; YES - done


;-----------------------------------------------------------------------------
; Helper Function - send a Clock Pulse
;
send_clk_pulse:
	bsf		MS5541_clk					; set clock
	nop
	nop
	nop
	nop
	nop
	nop
	bcf		MS5541_clk					; release clock
	nop
	nop
	nop
	nop
	return								; done


;-----------------------------------------------------------------------------
; Helper Function - send a Command
;
send_data_MS5541:
	movwf	clock_count					; from WREG
	; send three start bits first
	bcf		MS5541_clk					; revoke clock
	nop									; wait
	nop									; wait
	bsf		MS5541_mosi					; set MOSI
	movlw	d'3'						; compute total bit counter
	subwf	clock_count,F				; ...
	rcall	send_clk_pulse				; send one high-low sequence on MS5541_clk
	rcall	send_clk_pulse				; send one high-low sequence on MS5541_clk
	rcall	send_clk_pulse				; send one high-low sequence on MS5541_clk

send_data_MS5541_loop:
	; now send 8 bits from dbuffer and fill-up with zeros
	bcf		MS5541_clk					; revoke clock
	nop									; wait
	nop									; wait
	btfss	dbuffer,7					; bit = 1 ? (MSB first)
	bcf		MS5541_mosi					; NO  - clear MOSI
	btfsc	dbuffer,7					; bit = 0 ? (MSB first)
	bsf		MS5541_mosi					; NO  - set   MOSI
	bsf		MS5541_clk					; set clock
	bcf		STATUS,C					; clear carry bit
	rlcf	dbuffer,F					; shift data byte
	nop									; wait
	nop									; wait
;	nop
;	nop
;	nop
;	nop
;	bcf		MS5541_clk
	decfsz	clock_count,F				; decrement bit counter, became zero?
	bra		send_data_MS5541_loop		; NO  - loop
	bcf		MS5541_clk					; YES - revoke clock
	return								;     - done

;-----------------------------------------------------------------------------

	END
