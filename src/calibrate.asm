;=============================================================================
;
;   File calibration.asm							REFACTORED VERSION V2.98b
;
;   o2 sensor calibration subroutines
;
;   Copyright (c) 2014, Heinrichs Weikamp, all right reserved.
;=============================================================================

#include "hwos.inc"
#include "shared_definitions.h"				; mailbox between c and asm
#include "math.inc"
#include "adc_lightsensor.inc"
#include "eeprom_rs232.inc"
#include "isr.inc"	


calibrate	CODE


	global	transmit_setpoint				; transmit current setpoint from WREG (in cbar) to external electronics
transmit_setpoint:
	return									; 					!!!! FUNCTION IS CURRENTLY DISABLED !!!!
	btfss	s8_digital						; S8 Digital connection existing?
	return									; NO  - ignore
											; YES - transmit setpoint from WREG
	clrf	lo								; initialize checksum
	movwf	hi								; store setpoint
	movlw	0xAA							; start byte
	rcall	tx_to_HUD						; transmit to HUD
	movlw	0x60							; command new SP
	rcall	tx_to_HUD						; transmit to HUD
	movff	hi,WREG							; SP in cbar
	rcall	tx_to_HUD						; transmit to HUD
	movff	lo,WREG							; checksum
	rcall	tx_to_HUD_cs					; transmit checksum
	return

tx_to_HUD:									; entry point to transmit a byte to the HUD
	addwf	lo,F							; add byte to checksum
tx_to_HUD_cs:								; entry point to transmit the checksum
	movff	WREG,TXREG2						; transmit byte
	call	rs232_wait_tx2					; wait for UART
	return


	global	calibrate_mix
calibrate_mix:
	; set usage and calibration flags as per default
	bsf		use_O2_sensor1
	bsf		use_O2_sensor2
	bsf		use_O2_sensor3
	bsf		sensor1_calibrated_ok
	bsf		sensor2_calibrated_ok
	bsf		sensor3_calibrated_ok

	; check for HUD
	btfss	s8_digital						; S8 Digital connection existing?
	bra		calibrate_mix1					; NO  - skip HUD part

	; calibrate any S8-connected HUD
	clrf	lo								; initialize checksum
	movlw	0xAA							; start byte
	rcall	tx_to_HUD						; transmit to HUD
	movlw	0x31							; calibration command
	rcall	tx_to_HUD						; transmit to HUD
	movff	opt_calibration_O2_ratio,WREG	; calibration gas %O2
	rcall	tx_to_HUD						; transmit to HUD
	movff	amb_pressure+0,WREG				; ambient pressure low byte
	rcall	tx_to_HUD						; transmit to HUD
	movff	amb_pressure+1,WREG				; ambient pressure high byte
	rcall	tx_to_HUD						; transmit to HUD
	movff	lo,WREG							; checksum
	rcall	tx_to_HUD_cs					; transmit to HUD
;	bra		calibrate_mix2

	; calibrate internal sensors
calibrate_mix1:								; compute %O2 * 100 * ambient_pressure[mbar] / 100
	movff	opt_calibration_O2_ratio,WREG
	mullw	.100
	movff	PRODL,xA+0
	movff	PRODH,xA+1
	SAFE_2BYTE_COPY amb_pressure,xB 
	call	mult16x16						; xA*xB=xC
	movlw	LOW  .100
	movwf	xB+0
	movlw	HIGH .100
	movwf	xB+1
	call	div32x16						; xC:4 / xB:2 = xC+3:xC+2 with xC+1:xC+0 as remainder

	; keep a copy of the result
	movff	xC+0,lo
	movff	xC+1,hi
	movff	xC+2,up
	movff	xC+3,ex

	; compute factor for sensor 1
	movff	o2_mv_sensor1+0,xB+0
	movff	o2_mv_sensor1+1,xB+1
	call	div32x16						; xC:4 / xB:2 = xC+3:xC+2 with xC+1:xC+0 as remainder
	movff	xC+0,opt_x_s1+0					; xC= ppO2/mV as factor for sensor 1
	movff	xC+1,opt_x_s1+1

	; restore result
	movff	lo,xC+0
	movff	hi,xC+1
	movff	up,xC+2
	movff	ex,xC+3

	; compute factor for sensor 2
	movff	o2_mv_sensor2+0,xB+0
	movff	o2_mv_sensor2+1,xB+1
	call	div32x16						; xC:4 / xB:2 = xC+3:xC+2 with xC+1:xC+0 as remainder
	movff	xC+0,opt_x_s2+0					; xC= ppO2/mV as factor for sensor 2
	movff	xC+1,opt_x_s2+1

	; restore result
	movff	lo,xC+0
	movff	hi,xC+1
	movff	up,xC+2
	movff	ex,xC+3

	; compute factor for sensor 3
	movff	o2_mv_sensor3+0,xB+0
	movff	o2_mv_sensor3+1,xB+1
	call	div32x16						; xC:4 / xB:2 = xC+3:xC+2 with xC+1:xC+0 as remainder
	movff	xC+0,opt_x_s3+0					; xC= ppO2/mV as factor for sensor 3
	movff	xC+1,opt_x_s3+1

	; check sensor 1 for min/max mV
	movff	o2_mv_sensor1+0, sub_a+0		; get mV from sensor 1
	movff	o2_mv_sensor1+1, sub_a+1
	rcall	calibrate_mix_helper			; check mV for min/max thresholds, returns with WREG = 0 if ok, else WREG = 1
	TSTFSZ	WREG							; sensor mV within thresholds?
	bcf		use_O2_sensor1					; NO - clear usage flag

	; check sensor 2 for min/max mV
	movff	o2_mv_sensor2+0, sub_a+0		; get mV from sensor 2
	movff	o2_mv_sensor2+1, sub_a+1
	rcall	calibrate_mix_helper			; check mV for min/max thresholds, returns with WREG = 0 if ok, else WREG = 1
	TSTFSZ	WREG							; sensor mV within thresholds?
	bcf		use_O2_sensor2					; NO - clear usage flag

	; check sensor 3 for min/max mV
	movff	o2_mv_sensor3+0, sub_a+0		; get mV from sensor 3
	movff	o2_mv_sensor3+1, sub_a+1
	rcall	calibrate_mix_helper			; check mV for min/max thresholds, returns with WREG = 0 if ok, else WREG = 1
	TSTFSZ	WREG							; sensor mV within thresholds?
	bcf		use_O2_sensor3					; NO - clear usage flag

calibrate_mix2:
	; check for HUD
	btfss	hud_connection_ok				; HUD connection existing?
	bra		calibrate_mix3					; NO - skip HUD part

	; Copy disable flags from HUD digital input
	btfss	sensor1_active
	bcf		use_O2_sensor1
	btfss	sensor2_active
	bcf		use_O2_sensor2
	btfss	sensor3_active
	bcf		use_O2_sensor3

calibrate_mix3:
	; clear calibration flags if sensors are not found to be ok
	btfss	use_O2_sensor1					; sensor 1 out of range?
	bcf		sensor1_calibrated_ok			; YES - disable this sensor
	btfss	use_O2_sensor2					; sensor 2 out of range?
	bcf		sensor2_calibrated_ok			; YES - disable this sensor
	btfss	use_O2_sensor3					; sensor 3 out of range?
	bcf		sensor3_calibrated_ok			; YES - disable this sensor

	; When no sensor is found, enable all three to show error state and clear calibration factors
	btfsc	use_O2_sensor1
	return
	btfsc	use_O2_sensor2
	return
	btfsc	use_O2_sensor3
	return
	; Enable all sensors
	bsf		use_O2_sensor1
	bsf		use_O2_sensor2
	bsf		use_O2_sensor3
	; Clear calibration factors
	banksel opt_x_s1+0
	clrf	opt_x_s1+0
	clrf	opt_x_s1+1
	clrf	opt_x_s2+0
	clrf	opt_x_s2+1
	clrf	opt_x_s3+0
	clrf	opt_x_s3+1
	banksel	common
	return

calibrate_mix_helper:
	movlw	LOW  min_mv						; load minimum threshold...
	movwf	sub_b+0							; ...into sub_b
	movlw	HIGH min_mv
	movwf	sub_b+1
	call	sub16							; sub_c = sub_a - sub_b
	btfsc	neg_flag						; sensor mV lower than minimum threshold?
	retlw	.1								; YES - return signaling threshold violation
	movlw	LOW  max_mv						; load maximum threshold...
	movwf	sub_b+0							; ...into sub_b
	movlw	HIGH max_mv
	movwf	sub_b+1
	call	sub16							; sub_c = sub_a - sub_b
	btfss	neg_flag						; sensor mV higher than maximum threshold?
	retlw	.1								; YES - return signaling threshold violation
	retlw	.0								; NO  - return signaling min/max ok


	global	compute_mvolts_for_all_sensors
compute_mvolts_for_all_sensors:				; compute mV or all sensors (S8 mode)
; compute AD results in 100µV steps (16bit/sensor)
; 24bit AD result is in 244,1406541nV
; Divide 24bit value through 409,5999512 -> 410 (0,01% error)
	#DEFINE	ad2mv_factor .410
	movlw	LOW  ad2mv_factor
	movwf	xB+0
	movlw	HIGH ad2mv_factor
	movwf	xB+1
	; Sensor 1
	clrf	xC+3
	movff	s8_rawdata_sensor1+2,xC+2
	movff	s8_rawdata_sensor1+1,xC+1
	movff	s8_rawdata_sensor1+0,xC+0
	call	div32x16						; xC:4 / xB:2 = xC+3:xC+2 with xC+1:xC+0 as remainder
	movff	xC+1,o2_mv_sensor1+1
	movff	xC+0,o2_mv_sensor1+0			; in 100 uV steps
	; Sensor 2
	clrf	xC+3
	movff	s8_rawdata_sensor2+2,xC+2
	movff	s8_rawdata_sensor2+1,xC+1
	movff	s8_rawdata_sensor2+0,xC+0
	call	div32x16						; xC:4 / xB:2 = xC+3:xC+2 with xC+1:xC+0 as remainder
	movff	xC+1,o2_mv_sensor2+1
	movff	xC+0,o2_mv_sensor2+0			; in 100 uV steps
	; Sensor 3
	clrf	xC+3
	movff	s8_rawdata_sensor3+2,xC+2
	movff	s8_rawdata_sensor3+1,xC+1
	movff	s8_rawdata_sensor3+0,xC+0
	call	div32x16						; xC:4 / xB:2 = xC+3:xC+2 with xC+1:xC+0 as remainder
	movff	xC+1,o2_mv_sensor3+1
	movff	xC+0,o2_mv_sensor3+0			; in 100 uV steps

	bcf		new_s8_data_available			; clear flag
	return									; done

	END