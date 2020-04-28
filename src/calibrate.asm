;=============================================================================
;
;   File calibration.asm                    * combined next generation V3.09.4n
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


;=============================================================================
calibrate1	CODE
;=============================================================================


 IFDEF _external_sensor

;-----------------------------------------------------------------------------
; Transmit current Setpoint from WREG (in cbar) to external Electronics
;
	global	transmit_setpoint
transmit_setpoint:
	return									; !!!! FUNCTION IS CURRENTLY DISABLED !!!!

;	btfsc	ext_input_optical				; optical input in use?
;	return									; YES - setpoint - TX not supported
;	TSTOSS	opt_s8_mode						; NO  - S8 mode selected?
;	return									;       NO
;	clrf	lo								;       YES - initialize checksum
;	movff	char_I_const_ppO2,hi			;           - copy setpoint value to hi
;	movlw	0xAA							;           - load start byte
;	rcall	tx_to_HUD_chksum				;           - transmit to HUD
;	movlw	0x60							;           - load command 'new SP'
;	rcall	tx_to_HUD_chksum				;           - transmit to HUD
;	movf	hi,W							;           - load SP in cbar
;	rcall	tx_to_HUD_chksum				;           - transmit to HUD
;	movf	lo,W							;           - load checksum
;	rcall	tx_to_HUD						;           - transmit checksum
;	return									;           - done


;-----------------------------------------------------------------------------
; Helper Function - Transmit Byte to external Electronics
;
tx_to_HUD_chksum:
	addwf	lo,F							; add byte to checksum
tx_to_HUD:
	goto	ir_s8_tx_single					; transmit byte and return


;-----------------------------------------------------------------------------
; Compute Calibration Factors
;
	global	calibrate_mix
calibrate_mix:
	; set usage and calibration flags to default values
	bsf		use_O2_sensor1					; sensor in use
	bsf		use_O2_sensor2					; ...
	bsf		use_O2_sensor3					; ...
	bsf		sensor1_calibrated_ok			; sensor calibration ok
	bsf		sensor2_calibrated_ok			; ...
	bsf		sensor3_calibrated_ok			; ...

	; ISR-safe 2 byte copy of the current pressure to xB for later use
	SMOVII	pressure_abs,xB

	; check for HUD
	btfsc	ext_input_optical				; optical interface in use?
	bra		calibrate_mix1					; YES - skip
	TSTOSS	opt_s8_mode						; NO  - S8 interface in use?
	bra		calibrate_mix1					;       NO  - skip HUD part
	;bra	calibrate_mix0					;       YES - calibrate S8 HUD

	; calibrate S8-connected external electronics
calibrate_mix0:
	clrf	lo								; initialize checksum
	movlw	0xAA							; load start byte
	rcall	tx_to_HUD_chksum				; transmit to HUD
	movlw	0x31							; load calibration command
	rcall	tx_to_HUD_chksum				; transmit to HUD
	movff	opt_calibration_O2_ratio,WREG	; load calibration gas %O2
	rcall	tx_to_HUD_chksum				; transmit to HUD
	movf	xB+0,W							; load current absolute pressure low  byte
	rcall	tx_to_HUD_chksum				; transmit to HUD
	movf	xB+1,W							; load current absolute pressure high byte
	rcall	tx_to_HUD_chksum				; transmit to HUD
	movf	lo,W							; load checksum
	rcall	tx_to_HUD						; transmit to HUD

	; calibrate internal sensors
calibrate_mix1:								; compute C = %O2 * 100 * absolute pressure [mbar] / 100
	movff	opt_calibration_O2_ratio,WREG	; load calibration gas %O2
	mullw	.100							; multiply with 100
	MOVII	PROD,xA							; copy result to xA
	call	mult16x16						; xC = xA * xB
	MOVLI	.100,xB							; prepare division by 100
	call	div32x16						; xC:4 = xC:4 / xB:2 with xA as remainder

	; compute factor for sensor 1
	MOVRR	xC,mpr,.4						; backup calibration value C
	MOVII	sensor1_mv,xB					; get mV from sensor 1
	call	div32x16						; xC:4 = xC:4 / xB:2 with xA as remainder
	MOVII	xC,opt_x_s1						; xC = ppO2/mV as factor for sensor 1

	; compute factor for sensor 2
	MOVRR	mpr,xC,.4						; restore C
	MOVII	sensor2_mv,xB					; get mV from sensor 2
	call	div32x16						; xC:4 = xC:4 / xB:2 with xA as remainder
	MOVII	xC,opt_x_s2						; xC = ppO2/mV as factor for sensor 2

	; compute factor for sensor 3
	MOVRR	mpr,xC,.4						; restore C
	MOVII	sensor3_mv,xB					; get mV from sensor 3
	call	div32x16						; xC:4 = xC:4 / xB:2 with xA as remainder
	MOVII	xC,opt_x_s3						; xC = ppO2/mV as factor for sensor 3

	; check sensor 1 for min/max mV
	MOVII	sensor1_mv,sub_a				; get mV from sensor 1
	rcall	calibrate_mix_helper			; check mV for min/max boundary, returns with WREG = 0 if ok, else WREG = 1
	TSTFSZ	WREG							; sensor mV within boundary?
	bcf		use_O2_sensor1					; NO - revoke sensor from usage

	; check sensor 2 for min/max mV
	MOVII	sensor2_mv,sub_a				; get mV from sensor 2
	rcall	calibrate_mix_helper			; check mV for min/max boundary, returns with WREG = 0 if ok, else WREG = 1
	TSTFSZ	WREG							; sensor mV within boundary?
	bcf		use_O2_sensor2					; NO - revoke sensor from usage

	; check sensor 3 for min/max mV
	MOVII	sensor3_mv,sub_a				; get mV from sensor 3
	rcall	calibrate_mix_helper			; check mV for min/max boundary, returns with WREG = 0 if ok, else WREG = 1
	TSTFSZ	WREG							; sensor mV within boundary?
	bcf		use_O2_sensor3					; NO - revoke sensor from usage

calibrate_mix2:
	; check for HUD
	btfss	hud_connection_ok				; HUD connection existing?
	bra		calibrate_mix3					; NO - skip HUD part

	; TODO: wait for HUD to complete calibration an send updated data

	; copy disable flags from HUD digital input
	btfss	sensor1_active					; sensor 1 usable?
	bcf		use_O2_sensor1					; NO - revoke sensor from usage
	btfss	sensor2_active					; sensor 2 usable?
	bcf		use_O2_sensor2					; NO - revoke sensor from usage
	btfss	sensor3_active					; sensor 3 usable?
	bcf		use_O2_sensor3					; NO - revoke sensor from usage

calibrate_mix3:
	; clear calibration flags if sensors are not usable
	btfss	use_O2_sensor1					; sensor 1 usable?
	bcf		sensor1_calibrated_ok			; NO  - revoke calibration
	btfss	use_O2_sensor2					; sensor 2 usable?
	bcf		sensor2_calibrated_ok			; NO  - revoke calibration
	btfss	use_O2_sensor3					; sensor 3 usable?
	bcf		sensor3_calibrated_ok			; NO  - revoke calibration

	; if there is no usable sensor at all, then enable all three
	; sensors to show error state and clear calibration factors
	btfsc	use_O2_sensor1					; sensor 1 usable?
	return									; YES - done
	btfsc	use_O2_sensor2					; NO  - sensor 2 usable?
	return									;       YES - done
	btfsc	use_O2_sensor3					;       NO  - sensor 3 usable?
	return									;             YES - done
	bsf		use_O2_sensor1					;             NO  - enable all sensors
	bsf		use_O2_sensor2					;                 - ...
	bsf		use_O2_sensor3					;                 - ...
	CLRR	opt_x_s1,.6						;                 - clear calibration factors (3x 16 bit)
	return									;                 - done


;-----------------------------------------------------------------------------
; Helper Function - Check if Sensor mV Value is within Min/Max Boundary
;
calibrate_mix_helper:
	MOVLI	min_mv,sub_b					; load minimum boundary into sub_b
	call	sub16							; sub_c = sub_a - sub_b
	btfsc	neg_flag						; sensor mV lower than minimum boundary?
	retlw	.1								; YES - return signaling boundary violation

	MOVLI	max_mv,sub_b					; load maximum boundary into sub_b
	call	sub16							; sub_c = sub_a - sub_b
	btfss	neg_flag						; sensor mV higher than maximum boundary?
	retlw	.1								; YES - return signaling boundary violation

	retlw	.0								; return signaling min/max ok

 ENDIF	; _external_sensor

;=============================================================================
calibrate2	CODE
;=============================================================================

 IFDEF _external_sensor

;-----------------------------------------------------------------------------
; Compute Sensor mV from Raw Values received via S8 digital Interface
;
	global	compute_mvolts_from_rawdata
compute_mvolts_from_rawdata:

	; compute AD results in 100 µV steps (16 bit/sensor)
	; 24 bit AD result is in 244.1406541 nV
	; divide 24 bit value by 409.5999512 -> 410 with only 0.01% error
	#DEFINE	ad2mv_factor .410

	MOVLI	ad2mv_factor,xB					; load conversion factor into xB

	; Sensor 1
	SMOVTT	s8_rawdata_sensor1,xC			; ISR-safe copy of 3 bytes to xC
	clrf	xC+3							; clear MSB of xC
	call	div32x16						; xC:4 = xC:4 / xB:2 with xA as remainder
	MOVII	xC,sensor1_mv					; store result

	; Sensor 2
	SMOVTT	s8_rawdata_sensor2,xC			; ISR-safe copy of 3 bytes to xC
	clrf	xC+3							; clear MSB of xC
	call	div32x16						; xC:4 = xC:4 / xB:2 with xA as remainder
	MOVII	xC,sensor2_mv					; store result

	; Sensor 3
	SMOVTT	s8_rawdata_sensor3,xC			; ISR-safe copy of 3 bytes to xC
	clrf	xC+3							; clear MSB of xC
	call	div32x16						; xC:4 = xC:4 / xB:2 with xA as remainder
	MOVII	xC,sensor3_mv					; store result

	return									; done

 ENDIF	; _external_sensor

;-----------------------------------------------------------------------------

	END
