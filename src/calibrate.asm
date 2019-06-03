;=============================================================================
;
;   File calibration.asm                      combined next generation V3.03.1
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


calibrate	CODE

;=============================================================================

 IFDEF _external_sensor

	global	transmit_setpoint				; transmit current setpoint from WREG (in cbar) to external electronics
transmit_setpoint:
	return									; !!!! FUNCTION IS CURRENTLY DISABLED !!!!
	btfss	s8_digital_avail				; do we have a digital S8 interface?
	return									; NO  - ignore
											; YES - transmit setpoint from WREG
	clrf	lo								; initialize checksum
	movff	char_I_const_ppO2,hi			; copy setpoint value to hi
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

	; ISR-safe 2 byte copy of the current pressure to xB for later use
	SMOVII	pressure_abs,xB

	; check for HUD
	btfss	s8_digital_avail				; do we have a digital S8 interface?
	bra		calibrate_mix1					; NO  - skip HUD part

	; calibrate any S8-connected HUD
	clrf	lo								; initialize checksum
	movlw	0xAA							; start byte
	rcall	tx_to_HUD						; transmit to HUD
	movlw	0x31							; calibration command
	rcall	tx_to_HUD						; transmit to HUD
	movff	opt_calibration_O2_ratio,WREG	; calibration gas %O2
	rcall	tx_to_HUD						; transmit to HUD
	movff	xB+0,WREG						; current absolute pressure low byte
	rcall	tx_to_HUD						; transmit to HUD
	movff	xB+1,WREG						; current absolute pressure high byte
	rcall	tx_to_HUD						; transmit to HUD
	movff	lo,WREG							; checksum
	rcall	tx_to_HUD_cs					; transmit to HUD
;	bra		calibrate_mix2

	; calibrate internal sensors
calibrate_mix1:								; compute %O2 * 100 * absolute pressure [mbar] / 100
	movff	opt_calibration_O2_ratio,WREG
	mullw	.100
	MOVII	PROD,xA
	call	mult16x16						; xA*xB=xC
	MOVLI	.100,xB
	call	div32x16						; xC:4 = xC:4 / xB:2 with xA as remainder

	; keep a copy of the result
	movff	xC+0,mpr+0
	movff	xC+1,mpr+1
	movff	xC+2,mpr+2
	movff	xC+3,mpr+3

	; compute factor for sensor 1
	MOVII	sensor1_mv,xB
	call	div32x16						; xC:4 = xC:4 / xB:2 with xA as remainder
	MOVII	xC,opt_x_s1						; xC = ppO2/mV as factor for sensor 1

	; restore result
	movff	mpr+0,xC+0
	movff	mpr+1,xC+1
	movff	mpr+2,xC+2
	movff	mpr+3,xC+3

	; compute factor for sensor 2
	MOVII	sensor2_mv,xB
	call	div32x16						; xC:4 = xC:4 / xB:2 with xA as remainder
	MOVII	xC,opt_x_s2						; xC = ppO2/mV as factor for sensor 2

	; restore result
	movff	mpr+0,xC+0
	movff	mpr+1,xC+1
	movff	mpr+2,xC+2
	movff	mpr+3,xC+3

	; compute factor for sensor 3
	MOVII	sensor3_mv,xB
	call	div32x16						; xC:4 = xC:4 / xB:2 with xA as remainder
	MOVII	xC,opt_x_s3						; xC = ppO2/mV as factor for sensor 3

	; check sensor 1 for min/max mV
	MOVII	sensor1_mv,sub_a				; get mV from sensor 1
	rcall	calibrate_mix_helper			; check mV for min/max thresholds, returns with WREG = 0 if ok, else WREG = 1
	TSTFSZ	WREG							; sensor mV within thresholds?
	bcf		use_O2_sensor1					; NO - clear usage flag

	; check sensor 2 for min/max mV
	MOVII	sensor2_mv,sub_a				; get mV from sensor 2
	rcall	calibrate_mix_helper			; check mV for min/max thresholds, returns with WREG = 0 if ok, else WREG = 1
	TSTFSZ	WREG							; sensor mV within thresholds?
	bcf		use_O2_sensor2					; NO - clear usage flag

	; check sensor 3 for min/max mV
	MOVII	sensor3_mv,sub_a				; get mV from sensor 3
	rcall	calibrate_mix_helper			; check mV for min/max thresholds, returns with WREG = 0 if ok, else WREG = 1
	TSTFSZ	WREG							; sensor mV within thresholds?
	bcf		use_O2_sensor3					; NO - clear usage flag

calibrate_mix2:
	; check for HUD
	btfss	hud_connection_ok				; HUD connection existing?
	bra		calibrate_mix3					; NO - skip HUD part

	; copy disable flags from HUD digital input
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

	; when no sensor is found, enable all three to show error state and clear calibration factors
	btfsc	use_O2_sensor1
	return
	btfsc	use_O2_sensor2
	return
	btfsc	use_O2_sensor3
	return

	; enable all sensors
	bsf		use_O2_sensor1
	bsf		use_O2_sensor2
	bsf		use_O2_sensor3
	; clear calibration factors
	banksel	opt_x_s1						; switch to bank options table
	CLRI	opt_x_s1
	CLRI	opt_x_s2
	CLRI	opt_x_s3
	banksel	common							; back to bank common
	return

calibrate_mix_helper:
	MOVLI	min_mv,sub_b					; load minimum threshold into sub_b
	call	sub16							; sub_c = sub_a - sub_b
	btfsc	neg_flag						; sensor mV lower than minimum threshold?
	retlw	.1								; YES - return signaling threshold violation
	MOVLI	max_mv,sub_b					; load maximum threshold into sub_b
	call	sub16							; sub_c = sub_a - sub_b
	btfss	neg_flag						; sensor mV higher than maximum threshold?
	retlw	.1								; YES - return signaling threshold violation
	retlw	.0								; NO  - return signaling min/max ok


	global	compute_mvolts_for_all_sensors
compute_mvolts_for_all_sensors:				; compute mV or all sensors (S8 mode)
	; compute AD results in 100 µV steps (16 bit/sensor)
	; 24 bit AD result is in 244.1406541 nV
	; divide 24 bit value by 409.5999512 -> 410 with only 0.01% error
	#DEFINE	ad2mv_factor .410

	MOVLI	ad2mv_factor,xB

	; Sensor 1
	SMOVTT	s8_rawdata_sensor1,xC			; ISR-safe copy of 3 bytes to xC
	clrf	xC+3							; clear MSB of xC
	call	div32x16						; xC:4 = xC:4 / xB:2 with xA as remainder
	MOVII	xC,sensor1_mv					; in 100 µV steps

	; Sensor 2
	SMOVTT	s8_rawdata_sensor2,xC			; ISR-safe copy of 3 bytes to xC
	clrf	xC+3							; clear MSB of xC
	call	div32x16						; xC:4 = xC:4 / xB:2 with xA as remainder
	MOVII	xC,sensor2_mv					; in 100 µV steps

	; Sensor 3
	SMOVTT	s8_rawdata_sensor3,xC			; ISR-safe copy of 3 bytes to xC
	clrf	xC+3							; clear MSB of xC
	call	div32x16						; xC:4 = xC:4 / xB:2 with xA as remainder
	MOVII	xC,sensor3_mv					; in 100 µV steps

	return									; done


 ENDIF	; _external_sensor

;=============================================================================

	END
