;=============================================================================
;
;   File calibration.asm							REFACTORED VERSION V2.98
;
;   o2 sensor calibration subroutines
;
;   Copyright (c) 2014, Heinrichs Weikamp, all right reserved.
;=============================================================================

#include "hwos.inc"
#include "shared_definitions.h"				; Mailbox between c and asm
#include "math.inc"
#include "adc_lightsensor.inc"
#include "eeprom_rs232.inc"


calibrate	CODE

	global	check_sensors					; Check O2 sensor thresholds for fallback and voting logic
check_sensors:
	; Check min_mv
	movff	o2_mv_sensor1+0, sub_a+0
	movff	o2_mv_sensor1+1, sub_a+1
	movlw	LOW  min_mv
	movwf	sub_b+0
	movlw	HIGH min_mv
	movwf	sub_b+1
	call	sub16							; sub_c = sub_a - sub_b
	bsf		use_O2_sensor1					;=1: Use this sensor for deco
	btfsc	neg_flag
	bcf		use_O2_sensor1					;=1: Use this sensor for deco

	movff	o2_mv_sensor2+0, sub_a+0
	movff	o2_mv_sensor2+1, sub_a+1
	movlw	LOW  min_mv
	movwf	sub_b+0
	movlw	HIGH min_mv
	movwf	sub_b+1
	call	sub16							; sub_c = sub_a - sub_b
	bsf		use_O2_sensor2					;=1: Use this sensor for deco
	btfsc	neg_flag
	bcf		use_O2_sensor2					;=1: Use this sensor for deco

	movff	o2_mv_sensor3+0, sub_a+0
	movff	o2_mv_sensor3+1, sub_a+1
	movlw	LOW  min_mv
	movwf	sub_b+0
	movlw	HIGH min_mv
	movwf	sub_b+1
	call	sub16							; sub_c = sub_a - sub_b
	bsf		use_O2_sensor3					;=1: Use this sensor for deco
	btfsc	neg_flag
	bcf		use_O2_sensor3					;=1: Use this sensor for deco

	; Check max_mv
	movff	o2_mv_sensor1+0, sub_a+0
	movff	o2_mv_sensor1+1, sub_a+1
	movlw	LOW  max_mv
	movwf	sub_b+0
	movlw	HIGH max_mv
	movwf	sub_b+1
	call	sub16							; sub_c = sub_a - sub_b
	btfss	neg_flag
	bcf		use_O2_sensor1					;=1: Use this sensor for deco

	movff	o2_mv_sensor2+0, sub_a+0
	movff	o2_mv_sensor2+1, sub_a+1
	movlw	LOW  max_mv
	movwf	sub_b+0
	movlw	HIGH max_mv
	movwf	sub_b+1
	call	sub16							; sub_c = sub_a - sub_b
	btfss	neg_flag
	bcf		use_O2_sensor2					;=1: Use this sensor for deco

	movff	o2_mv_sensor3+0, sub_a+0
	movff	o2_mv_sensor3+1, sub_a+1
	movlw	LOW  max_mv
	movwf	sub_b+0
	movlw	HIGH max_mv
	movwf	sub_b+1
	call	sub16							; sub_c = sub_a - sub_b
	btfss	neg_flag
	bcf		use_O2_sensor3					;=1: Use this sensor for deco

	btfss	hud_connection_ok				;=1: HUD connection ok
	bra		check_sensor2					; No HUD/Digital data

	; Copy disable flags from digital input
	btfss	sensor1_active
	bcf		use_O2_sensor1
	btfss	sensor2_active
	bcf		use_O2_sensor2
	btfss	sensor3_active
	bcf		use_O2_sensor3
	return

check_sensor2:
	; Copy disable flags from internal calibration routine
	btfss	sensor1_calibrated_ok
	bcf		use_O2_sensor1
	btfss	sensor2_calibrated_ok
	bcf		use_O2_sensor2
	btfss	sensor3_calibrated_ok
	bcf		use_O2_sensor3
	return


	global	calibrate_mix
calibrate_mix:
	; calibrate S8 HUD
	btfss	s8_digital						; S8 Digital?
	bra		calibrate_mix2					; No

	; Yes, calibrate any S8-connected HUD
	clrf	lo								; Checksum
	movlw	0xAA							; Start Byte
	addwf	lo,F
	movff	WREG,TXREG2
	call	rs232_wait_tx2

	movlw	0x31							; Calibrate
	addwf	lo,F
	movff	WREG,TXREG2
	call	rs232_wait_tx2

	movff	opt_calibration_O2_ratio,WREG	; Calibration gas %O2
	addwf	lo,F
	movff	WREG,TXREG2
	call	rs232_wait_tx2

	movff	amb_pressure+0,WREG				; Ambient pressure
	addwf	lo,F
	movff	WREG,TXREG2
	call	rs232_wait_tx2
	movff	amb_pressure+1,WREG
	addwf	lo,F
	movff	WREG,TXREG2
	call	rs232_wait_tx2

	movff	lo,TXREG2						; Checksum
	call	rs232_wait_tx2

calibrate_mix2:
	movff	opt_calibration_O2_ratio,WREG	; Calibration gas %O2
	mullw	.100
	movff	PRODL,xA+0
	movff	PRODH,xA+1
	; (%O2*100)*[ambient,mbar]/100 -> xC
	movff	amb_pressure+0,xB+0
	movff	amb_pressure+1,xB+1
	rcall	calibrate_mix2_helper
	movff	o2_mv_sensor1+0,xB+0
	movff	o2_mv_sensor1+1,xB+1
	call	div32x16						; xC:4 / xB:2 = xC+3:xC+2 with xC+1:xC+0 as remainder
	; xC= ppO2/mV
	movff	xC+0,opt_x_s1+0
	movff	xC+1,opt_x_s1+1					; Factor for Sensor1

	movff	opt_calibration_O2_ratio,WREG	; Calibration gas %O2
	mullw	.100
	movff	PRODL,xA+0
	movff	PRODH,xA+1
	; (%O2*100)*[ambient,mbar]/100 -> xC
	movff	amb_pressure+0,xB+0
	movff	amb_pressure+1,xB+1
	rcall	calibrate_mix2_helper
	movff	o2_mv_sensor2+0,xB+0
	movff	o2_mv_sensor2+1,xB+1
	call	div32x16						; xC:4 / xB:2 = xC+3:xC+2 with xC+1:xC+0 as remainder
	; xC= ppO2/mV
	movff	xC+0,opt_x_s2+0
	movff	xC+1,opt_x_s2+1					; Factor for Sensor2

	movff	opt_calibration_O2_ratio,WREG	; Calibration gas %O2
	mullw	.100
	movff	PRODL,xA+0
	movff	PRODH,xA+1
	; (%O2*100)*[ambient,mbar]/100 -> xC
	movff	amb_pressure+0,xB+0
	movff	amb_pressure+1,xB+1
	rcall	calibrate_mix2_helper
	movff	o2_mv_sensor3+0,xB+0
	movff	o2_mv_sensor3+1,xB+1
	call	div32x16						; xC:4 / xB:2 = xC+3:xC+2 with xC+1:xC+0 as remainder
	; xC= ppO2/mV
	movff	xC+0,opt_x_s3+0
	movff	xC+1,opt_x_s3+1					; Factor for Sensor3

	bsf		sensor1_calibrated_ok
	bsf		sensor2_calibrated_ok
	bsf		sensor3_calibrated_ok			; Set flags prior check

	rcall	check_sensors					; Check O2 sensor thresholds min_mv and max_mv and set use_02_sensorX flags
	; initialize internal calibration flags
	btfss	use_O2_sensor1					; Sensor out of range?
	bcf		sensor1_calibrated_ok			; Yes, disable this sensor
	btfss	use_O2_sensor2					; Sensor out of range?
	bcf		sensor2_calibrated_ok			; Yes, disable this sensor
	btfss	use_O2_sensor3					; Sensor out of range?
	bcf		sensor3_calibrated_ok			; Yes, disable this sensor

	; When no sensor is found, enable all three to show error state
	btfsc	use_O2_sensor1
	return
	btfsc	use_O2_sensor2
	return
	btfsc	use_O2_sensor3
	return
	bsf		use_O2_sensor1
	bsf		use_O2_sensor2
	bsf		use_O2_sensor3
	; Clear factors
	banksel opt_x_s1+0
	clrf	opt_x_s1+0
	clrf	opt_x_s1+1
	clrf	opt_x_s2+0
	clrf	opt_x_s2+1
	clrf	opt_x_s3+0
	clrf	opt_x_s3+1
	banksel	common
	return


calibrate_mix2_helper:
	call	mult16x16						; xA*xB=xC
	movlw	LOW  .100
	movwf	xB+0
	movlw	HIGH .100
	movwf	xB+1
	goto	div32x16						; xC:4 / xB:2 = xC+3:xC+2 with xC+1:xC+0 as remainder (And return)


	global	compute_mvolts_for_all_sensors
compute_mvolts_for_all_sensors:				; Compute mV or all sensors (S8 Mode)
; compute AD results in 100µV steps (16bit/sensor)
; 24bit AD result is in 244,1406541nV
; Divide 24bit value through 409,5999512 -> 410 (0,01% error)
	#DEFINE	ad2mv_factor .410
	; Sensor 1
	clrf	xC+3
	movff	s8_rawdata_sensor1+2,xC+2
	movff	s8_rawdata_sensor1+1,xC+1
	movff	s8_rawdata_sensor1+0,xC+0
	movlw	LOW  ad2mv_factor
	movwf	xB+0
	movlw	HIGH ad2mv_factor
	movwf	xB+1
	call	div32x16						; xC:4 / xB:2 = xC+3:xC+2 with xC+1:xC+0 as remainder
	movff	xC+1,o2_mv_sensor1+1
	movff	xC+0,o2_mv_sensor1+0			; in 100uV steps
	; Sensor 2
	clrf	xC+3
	movff	s8_rawdata_sensor2+2,xC+2
	movff	s8_rawdata_sensor2+1,xC+1
	movff	s8_rawdata_sensor2+0,xC+0
	movlw	LOW  ad2mv_factor
	movwf	xB+0
	movlw	HIGH ad2mv_factor
	movwf	xB+1
	call	div32x16						; xC:4 / xB:2 = xC+3:xC+2 with xC+1:xC+0 as remainder
	movff	xC+1,o2_mv_sensor2+1
	movff	xC+0,o2_mv_sensor2+0			; in 100uV steps
	; Sensor 3
	clrf	xC+3
	movff	s8_rawdata_sensor3+2,xC+2
	movff	s8_rawdata_sensor3+1,xC+1
	movff	s8_rawdata_sensor3+0,xC+0
	movlw	LOW  ad2mv_factor
	movwf	xB+0
	movlw	HIGH ad2mv_factor
	movwf	xB+1
	call	div32x16						; xC:4 / xB:2 = xC+3:xC+2 with xC+1:xC+0 as remainder
	movff	xC+1,o2_mv_sensor3+1
	movff	xC+0,o2_mv_sensor3+0			; in 100uV steps

	bcf		new_s8_data_available			; Clear flag
	return									; Done.


	global	transmit_setpoint				; Transmit current setpoint from WREG (in cbar) to external electronics
transmit_setpoint:
	return									; 					!!!! FUNCTION IS CURRENTLY DISABLED !!!!
	btfss	s8_digital						; S8 Digital?
	return									; No, ignore

	; Yes, transmit setpoint from WREG
	movwf	hi								; Store setpoint
	clrf	lo								; Checksum
	movlw	0xAA							; Start Byte
	addwf	lo,F
	movff	WREG,TXREG2
	call	rs232_wait_tx2

	movlw	0x60							; New SP
	addwf	lo,F
	movff	WREG,TXREG2
	call	rs232_wait_tx2

	movff	hi,WREG							; SP in cbar
	addwf	lo,F
	movff	WREG,TXREG2
	call	rs232_wait_tx2

	movff	lo,TXREG2						; Checksum
	call	rs232_wait_tx2
	return


	END