;=============================================================================
;
;   File i2c.asm                            * combined next generation V3.09.4b
;
;   I2C Interface
;
;   Copyright (c) 2012, JD Gascuel, heinrichs weikamp gmbh, all right reserved.
;=============================================================================
;
;   Compass0
;   --------
;   HMC5883L's read address  (8-Bit):  0x3D
;   HMC5883L's write address (8-Bit):  0x3C
;   MMA8452Q's read address  (8-Bit):  0x39
;   MMA8452Q's write address (8-Bit):  0x38
;
;   Compass1
;   --------
;   LSM303D's read address  (8-Bit):   0x3D
;   LSM303D's write address (8-Bit):   0x3C
;
;   Compass2
;   --------
;   LSM303AGR's Compass read address       (8-Bit):  0x3D
;   LSM303AGR's Compass write address      (8-Bit):  0x3C
;   LSM303AGR's Acceleration read address  (8-Bit):  0x33
;   LSM303AGR's Acceleration write address (8-Bit):  0x32
;    
;   Compass3
;   --------
;   LSM303C's Compass read address          (8-Bit): 0x3D
;   LSM303C's Compass write address         (8-Bit): 0x3C
;   LSM303C's Acceleration read address	    (8-Bit): 0x3B
;   LSM303C's Acceleration write address    (8-Bit): 0x3A
;
;   RX Circuity
;   -----------
;   RX Circuity read address  (8-Bit):  0x51
;   RX Circuity write address (8-Bit):  0x50
;    
;   Battery gauge    
;   -------------
;   LTC2942 read address  (8-Bit): 0xC9   
;   LTC2942 write address (8-Bit): 0xC8 
;    
;   Alternative Battery gauge    
;   -------------
;   LTC2959 read address  (8-Bit): 0xC7   
;   LTC2959 write address (8-Bit): 0xC6 
;
;   Alternative pressure sensor
;   -----------
;   MS5837 read address  (8-Bit):  0xED
;   MS5837 write address (8-Bit):  0xEC
;
;

; HISTORY
;  2012-08-22 : [mH] Creation
;  2018-02-18 : [mH] Sync with hwOS Sport release


#include "hwos.inc"						; Mandatory header
#include "wait.inc"
#include "math.inc"
#include "eeprom_rs232.inc"
    

;=============================================================================
i2c		CODE
;=============================================================================



;-----------------------------------------------------------------------------
; Helper Function - get two Bytes and divide hi:lo/16 (signed)
;
I2C_TwoBytesRX_div16:
	rcall	I2C_OneByteRX				; receive 1 byte with acknowledge
	movff	SSP1BUF,hi					; copy data byte to hi
	rcall	I2C_OneByteRX				; receive 1 byte with acknowledge
	movff	SSP1BUF,lo					; copy data byte to lo
I2C_TwoBytesRX_div16_2:					; divide hi:lo/16 (signed) only
	bcf		STATUS,C
	btfsc	hi,7						; copy sign bit to carry
	bsf		STATUS,C
	rrcf	hi							; /2
	rrcf	lo
	;bra	I2C_TwoBytesRX_div8			; continue dividing hi:lo/8 (signed)


;-----------------------------------------------------------------------------
; Helper Function - divide hi:lo/8 (signed)
;
I2C_TwoBytesRX_div8:
	bcf		STATUS,C
	btfsc	hi,7						; copy sign bit to carry
	bsf		STATUS,C
	rrcf	hi							; /4
	rrcf	lo
	bcf		STATUS,C
	btfsc	hi,7						; copy sign bit to carry
	bsf		STATUS,C
	rrcf	hi							; /8
	rrcf	lo
	bcf		STATUS,C
	btfsc	hi,7						; copy sign bit to carry
	bsf		STATUS,C
	rrcf	hi							; /16
	rrcf	lo
	return								; done


;-----------------------------------------------------------------------------
; Read Accelerometer
;
	global	I2C_RX_accelerometer
I2C_RX_accelerometer:
	btfsc	compass_type3					; compass3 ?
	bra		I2C_RX_accelerometer_compass3	; YES
	btfsc	compass_type2					; compass2 ?
	bra		I2C_RX_accelerometer_compass2	; YES
	btfsc	compass_type1					; compass1 ?
	bra		I2C_RX_accelerometer_compass1	; YES
	;bra	I2C_RX_accelerometer_compass0	; NO  - compass0 then

;I2C_RX_accelerometer_compass0:
	rcall	I2C_SEN						; start condition
	movlw	0x38						; address
	rcall	I2C_TX						; send byte
	movlw	0x00						; ??
	rcall	I2C_TX						; send byte
	rcall	I2C_RSEN					; repeated start condition	
	movlw	0x39						; address
	rcall	I2C_TX						; send byte
	rcall	I2C_OneByteRX				; get  status byte
	movf	SSP1BUF,W					; copy status byte to WREG

	; Non-flipped screen:
	; Chip orientation on the PCB requires
	; Original = corrected
	; x = -x
	; y = -y
	; z = -z

	; Flipped screen:
	; Chip orientation on the PCB requires
	; Original = corrected
	; x = x
	; y = y
	; z = -z

	rcall	I2C_TwoBytesRX_div16		; get two bytes and divide /16 (signed)
	btfsc	flip_screen					; 180� rotation?
	bra		I2C_RX_accelerometer2		; YES
	comf	hi							; NO  - 16 bit sign change
	negf	lo							;     - ....
	btfsc	STATUS,C					;     - carry to propagate?
	incf	hi,F						;     - YES - do it
I2C_RX_accelerometer2:
	MOVII	mpr,accel_DX				; copy result to accel_DX

	rcall	I2C_TwoBytesRX_div16		; get two bytes and divide /16 (signed)
	btfsc	flip_screen					; 180� rotation?
	bra		I2C_RX_accelerometer3		; YES
	comf	hi							; NO  - 16 bit sign change
	negf	lo							;     - ...
	btfsc	STATUS,C					;     - carry to propagate?
	incf	hi,F						;       YES - do it
I2C_RX_accelerometer3:
	MOVII	mpr,accel_DY				; copy result to accel_DY

	rcall	I2C_OneByteRX				; receive 1 byte with acknowledge
	movff	SSP1BUF,hi					; copy data byte to hi
	rcall	I2C_OneByteRX_NACK			; receive last byte with not acknowledge
	movff	SSP1BUF,lo					; copy data byte to lo
	rcall	I2C_TwoBytesRX_div16_2		; divide hi:lo/16 (signed)
	comf	hi							; 16 bit sign change
	negf	lo							; ...
	btfsc	STATUS,C					; carry to propagate?
	incf	hi,F						; YES - do it
	MOVII	mpr,accel_DZ				; copy result to accel_DZ
	bra	I2C_PEN						; stop condition


I2C_RX_accelerometer_compass1:
	rcall	I2C_SEN						; start condition
	movlw	0x3C						; address
	rcall	I2C_TX						; send byte
	movlw	b'10101000'					; 0x28 with auto-increment (MSB=1)
	rcall	I2C_TX						; send byte
	rcall	I2C_RSEN					; repeated start condition	
	movlw	0x3D						; address

I2C_RX_accelerometer_common:			; common part for compass 1,2 and 3
	rcall	I2C_TX						; send byte

	; Non-flipped screen:
	; Chip orientation on the PCB requires
	; Original = Corrected
	; x = -x (Compass 1)
	; x = x (Compass 2)
	; y = -y
	; z = -z

	; Flipped screen:
	; Chip orientation on the PCB requires
	; Original = Corrected
	; x = x (Compass 1)
	; x = -x (Compass 2)
	; y = y
	; z = -z

	; Dump the accelerator data
	rcall	I2C_OneByteRX				; receive 1 byte with acknowledge
	movff	SSP1BUF,lo					; accel_DX+0
	rcall	I2C_OneByteRX				; receive 1 byte with acknowledge
	movff	SSP1BUF,hi					; accel_DX+1
	rcall	I2C_TwoBytesRX_div16_2		; divide lo:hi/16 (signed) only
	btfss	compass_type2				; compass 2?
	bra		I2C_RX_accelerometer1_c1	; NO  - compass 1
	; compass 2
	btfss	flip_screen					; 180� rotation?
	bra		I2C_RX_accelerometer2_c1	; NO  - continue with normal compass1 routines for Y and Z
	; flipped compass 2, negate x
	comf	hi							; YES - 16 bit sign change
	negf	lo							;     - ...
	btfsc	STATUS,C					;     - carry to propagate?
	incf	hi,F						;       YES - do it
	bra		I2C_RX_accelerometer2_c1	;     - continue with normal compass1 routines for Y and Z

I2C_RX_accelerometer1_c1:
	btfsc	flip_screen					; 180� rotation?
	bra		I2C_RX_accelerometer2_c1	; YES
	; non-flipped compass 1, negate x
	comf	hi							; NO  - 16 bit sign change
	negf	lo							;     - ...
	btfsc	STATUS,C					;     - carry to propagate?
	incf	hi,F						;       YES - do it
I2C_RX_accelerometer2_c1:
	; flipped compass 1, non-flipped compass 2
	MOVII	mpr,accel_DX				; copy result
	rcall	I2C_OneByteRX				; receive 1 byte with acknowledge
	movff	SSP1BUF,lo					; copy accel_DY+0 to lo
	rcall	I2C_OneByteRX				; receive 1 byte with acknowledge
	movff	SSP1BUF,hi					; copy accel_DY+1 to hi
	rcall	I2C_TwoBytesRX_div16_2		; divide hi:lo/16 (signed) only
	btfsc	flip_screen					; 180� rotation?
	bra		I2C_RX_accelerometer3_c1	; YES
	comf	hi							; NO  - 16 bit sign change
	negf	lo							;     - ...
	btfsc	STATUS,C					;     - carry to propagate?
	incf	hi,F						;       YES - do it
I2C_RX_accelerometer3_c1:
	MOVII	mpr,accel_DY				; copy result
	rcall	I2C_OneByteRX				; receive 1 byte with acknowledge
	movff	SSP1BUF,lo					; accel_DZ+0
	rcall	I2C_OneByteRX_NACK			; receive last byte with not acknowledge
	movff	SSP1BUF,hi					; accel_DZ+1
	rcall	I2C_PEN						; stop condition
	rcall	I2C_TwoBytesRX_div16_2		; divide lo:hi/16 (signed) only
	comf	hi							; 16 bit sign change for Z
	negf	lo							; ...
	btfsc	STATUS,C					; carry to propagate?
	incf	hi,F						; YES - do it
	MOVII	mpr,accel_DZ				; copy result
	return								; done


I2C_RX_accelerometer_compass2:
	rcall	I2C_SEN						; start condition
	movlw	0x32						; address
	rcall	I2C_TX						; send byte
	movlw	b'10101000'					; 0x28 with auto-increment (MSB=1)
	rcall	I2C_TX						; send byte
	rcall	I2C_RSEN					; repeated start condition	
	movlw	0x33						; address
	bra		I2C_RX_accelerometer_common	; continue with common part

I2C_RX_accelerometer_compass3:
	rcall	I2C_SEN						; start condition
	movlw	0x3A						; address
	rcall	I2C_TX						; send byte
	movlw	0x28						; 0x28 (OUT_X_L_A)
	rcall	I2C_TX						; send byte
	rcall	I2C_RSEN					; repeated start condition	
	movlw	0x3B						; address
	bra		I2C_RX_accelerometer_common	; continue with common part



;-----------------------------------------------------------------------------
; Read Compass
;
 IFDEF _compass

	global	I2C_RX_compass
I2C_RX_compass:
	btfsc	compass_type3				; compass 3 ?
	bra		I2C_RX_compass3				; YES
	btfsc	compass_type2				; compass 2 ?
	bra		I2C_RX_compass2				; YES
	btfsc	compass_type1				; compass 1 ?
	bra		I2C_RX_compass1				; YES
	;bra	I2C_RX_compass0				; NO  - compass 0 then

;I2C_RX_compass0:
	rcall	I2C_SEN						; start condition
	movlw	0x3C						; address + write bit
	rcall	I2C_TX						; send byte
	movlw	0x03						; Point to Data Output X MSB Register (0x03)
	rcall	I2C_TX						; send byte
	rcall	I2C_PEN						; stop condition
	rcall	I2C_SEN						; start condition
	movlw	0x3D						; address + read bit
	rcall	I2C_TX						; send byte

	; Compass IC sends data in following order:
	; x MSB
	; x LSB
	; z MSB
	; z LSB
	; y MSB
	; y LSB

	; Non-flipped screen
	; Chip orientation on the PCB requires
	; Original = Corrected
	; x = -y
	; z = z
	; y = x

	; Flipped screen
	; Chip orientation on the PCB requires
	; Original = Corrected
	; x = y
	; z = z
	; y = -x

	rcall	I2C_OneByteRX				; receive 1 byte with acknowledge
	movff	SSP1BUF,compass_DY+1		; data byte
	rcall	I2C_OneByteRX				; receive 1 byte with acknowledge
	movff	SSP1BUF,compass_DY+0		; data byte
	btfsc	flip_screen					; 180� rotation?
	bra		I2C_RX_compass0_2			; NO
	banksel	compass_DY					; YES - flip Y
	comf	compass_DY+1				;     - 16 bit sign change
	negf	compass_DY+0
	btfsc	STATUS,C					;     - carry to propagate?
	incf	compass_DY+1,F				;       YES - do it
	banksel	common
I2C_RX_compass0_2:
	rcall	I2C_OneByteRX				; receive 1 byte with acknowledge
	movff	SSP1BUF,compass_DZ+1		; data byte
	rcall	I2C_OneByteRX				; receive 1 byte with acknowledge
	movff	SSP1BUF,compass_DZ+0		; data byte
	rcall	I2C_OneByteRX				; receive 1 byte with acknowledge
	movff	SSP1BUF,compass_DX+1		; data byte
	rcall	I2C_RCEN					; enable receive mode
	movff	SSP1BUF,compass_DX+0		; data byte
	rcall	I2C_PEN						; stop condition
	btfss	flip_screen					; 180� rotation?
	return								; NO  - done
	banksel	compass_DX					; YES - flip X
	comf	compass_DX+1				;     - 16 bit sign change
	negf	compass_DX+0
	btfsc	STATUS,C					;     - carry to propagate?
	incf	compass_DX+1,F				;       YES - do it
	banksel	common						; back to bank common
	return								; done


I2C_RX_compass1:						; compass type 1
	rcall	I2C_SEN						; start condition
	movlw	0x3C						; address
	rcall	I2C_TX						; send byte
	movlw	b'10001000'					; 0x08 with auto-increment (MSB=1)
	rcall	I2C_TX						; send byte
	rcall	I2C_RSEN					; repeated start condition	
	movlw	0x3D						; address
	rcall	I2C_TX						; send byte
	;rcall	WaitMSSP					; TODO needed? (mH)
	rcall	I2C_OneByteRX				; receive 1 byte with acknowledge
	movff	SSP1BUF,lo					; data byte
	rcall	I2C_OneByteRX				; receive 1 byte with acknowledge
	movff	SSP1BUF,hi					; data byte
	rcall	I2C_TwoBytesRX_div8			; divide hi,lo by 8 (signed)
	MOVII	mpr,compass_DX				; copy result
	btfss	flip_screen					; 180� rotation?
	bra		I2C_RX_compass1_1			; NO
	banksel	compass_DX					; YES - flip X
	comf	compass_DX+1				;     - 16 bit sign change
	negf	compass_DX+0
	btfsc	STATUS,C					;     - carry to propagate?
	incf	compass_DX+1,F				;       YES - do it
	banksel	common
I2C_RX_compass1_1:
	rcall	I2C_OneByteRX				; receive 1 byte with acknowledge
	movff	SSP1BUF,lo					; data byte
	rcall	I2C_OneByteRX				; receive 1 byte with acknowledge
	movff	SSP1BUF,hi					; data byte
	rcall	I2C_TwoBytesRX_div8			; divide hi, lo by 8 (signed)
	MOVII	mpr,compass_DY
	btfss	flip_screen					; 180� rotation?
	bra		I2C_RX_compass1_2			; NO
	banksel	compass_DY					; YES - flip Y
	comf	compass_DY+1				;     - 16 bit sign change
	negf	compass_DY+0				;     - ...
	btfsc	STATUS,C					;     - carry to propagate?
	incf	compass_DY+1,F				;       YES - do it
	banksel	common
I2C_RX_compass1_2:
	rcall	I2C_OneByteRX				; receive 1 byte with acknowledge
	movff	SSP1BUF,lo					; data byte
	rcall	I2C_OneByteRX_NACK			; receive last byte with not acknowledge
	movff	SSP1BUF,hi					; data byte
	rcall	I2C_TwoBytesRX_div8			; divide hi, lo by 8 (signed)
	MOVII	mpr,compass_DZ				; copy result
	bra	I2C_PEN						; stop condition



I2C_RX_compass2:						; compass type 2
	rcall	I2C_SEN						; start condition
	movlw	0x3C						; address
	rcall	I2C_TX						; send byte
	movlw	0xE8						; 0x68 with auto-increment (MSB=1)
	rcall	I2C_TX						; send byte
	rcall	I2C_RSEN					; repeated start condition	
	movlw	0x3D						; address
	rcall	I2C_TX						; send byte
I2C_RX_compass2_xx:						; compass 3 joins in here
;	rcall	WaitMSSP					; wait for TX to complete (not needed, as included in I2C_TX)
	rcall	I2C_OneByteRX				; receive 1 byte with acknowledge
	movff	SSP1BUF,lo					; data byte
	rcall	I2C_OneByteRX				; receive 1 byte with acknowledge
	movff	SSP1BUF,hi					; data byte
;	rcall	I2C_TwoBytesRX_div8			; divide hi, lo by 8 (signed)
	btfsc	flip_screen					; 180� rotation?
	bra		I2C_RX_compass2_1			; YES - do nothing with X
										; NO  - flip X
	comf	hi							;     - 16 bit sign change
	negf	lo							;     - ...
	btfsc	STATUS,C					;     - carry to propagate?
	incf	hi,F						;       YES - do it
I2C_RX_compass2_1:
	MOVII	mpr,compass_DX
	rcall	I2C_OneByteRX				; receive 1 byte with acknowledge
	movff	SSP1BUF,lo					; data byte
	rcall	I2C_OneByteRX				; receive 1 byte with acknowledge
	movff	SSP1BUF,hi					; data byte
;	rcall	I2C_TwoBytesRX_div8			; divide hi, lo by 8 (signed)
	btfss	flip_screen					; 180� rotation?
	bra		I2C_RX_compass2_2			; NO  - do nothing with Y
										; YES - flip Y
	comf	hi							;     - 16 bit sign change
	negf	lo							;     - ...
	btfsc	STATUS,C					;     - carry to propagate?
	incf	hi,F						;       YES - do it
I2C_RX_compass2_2:
	MOVII	mpr,compass_DY
	rcall	I2C_OneByteRX				; receive 1 byte with acknowledge
	movff	SSP1BUF,lo					; data byte
	rcall	I2C_OneByteRX_NACK			; receive last byte with not acknowledge
	movff	SSP1BUF,hi					; data byte
;	rcall	I2C_TwoBytesRX_div8			; divide hi, lo by 8 (signed)
	MOVII	mpr,compass_DZ				; copy result
	bra	I2C_PEN						; stop condition



I2C_RX_compass3:						; compass type 3
	rcall	I2C_SEN						; start condition
	movlw	0x3C						; address
	rcall	I2C_TX						; send byte
	movlw	0xA8						; 0x28 with auto-increment (MSB=1)
	rcall	I2C_TX						; send byte
	rcall	I2C_RSEN					; repeated start condition	
	movlw	0x3D						; address
	rcall	I2C_TX						; send byte
	bra		I2C_RX_compass2_xx			; join with compass 2 code

 ENDIF	; _compass


;-----------------------------------------------------------------------------
; Initialize Compass / Accelerometer Chip
;
	global	I2C_init_compass
I2C_init_compass:
	bsf		compass_present				; Set global compass flag
	bsf		compass_enabled				; flag compass will be enabled
	bcf		compass_type2				; clear in preparation of chip detection
	bcf		compass_type3				; ...

	; probe for compass 3
	rcall	I2C_SEN						; start condition
	movlw	0x3A						; address byte + write bit
	movwf	SSP1BUF						; control byte
	rcall	WaitMSSP					; wait for TX to complete
	; we need the ACKSTAT bit! Do not use I2C_TX routine here which might reset this bit!
	btfss	SSP1CON2,ACKSTAT			; ACK received?
	bsf		compass_type3				; YES - ACK was send, compass 3 found
	rcall	I2C_PEN						; stop condition

	btfsc	compass_type3				; compass 3 found?
	bra		I2C_init_compass3			; YES - initialize compass 3

	; probe for compass 2
	rcall	I2C_SEN						; start condition
	movlw	0x32						; address byte + write bit
	movwf	SSP1BUF						; control byte
	rcall	WaitMSSP					; wait for TX to complete
	; we need the ACKSTAT bit! Do not use I2C_TX routine here which might reset this bit!
        btfss	SSP1CON2,ACKSTAT			; ACK received?
	bsf		compass_type2				; YES - ACK send, compass 2 found
	rcall	I2C_PEN						; stop condition

	btfsc	compass_type2				; compass 2 found?
	bra		I2C_init_compass2			; YES - initialize compass 2

	; probe for compass 1
	bsf		compass_type1				; assume compass 1 by default
	rcall	I2C_SEN						; start condition
	movlw	0x3C						; address
	rcall	I2C_TX						; send byte
	movlw	0x0F						; ??
	rcall	I2C_TX						; send byte
	rcall	I2C_PEN						; stop condition
	rcall	I2C_SEN						; start condition
	movlw	0x3D						; address
	rcall	I2C_TX						; send byte
	rcall	I2C_OneByteRX				; receive 1 byte with acknowledge
	movlw	0x49						; 0x49 = compass 1
	cpfseq	SSP1BUF						; 0x49 received?
	bcf		compass_type1				; NO - clear flag for compass 1
	rcall	I2C_PEN						; stop condition

	btfsc	compass_type1				; compass 1 found?
	bra		I2C_init_compass1			; YES - initialize compass 1
	
	; probe for compass 0
	bsf	compass_type0					; assume compass 0 by default
	rcall	I2C_SEN						; start condition
	movlw	0x3C						; address + write bit
	rcall	I2C_TX						; send byte
	movlw	0x0A						; Point to Identification Register A
	rcall	I2C_TX						; send byte
	rcall	I2C_PEN						; stop condition
	rcall	I2C_SEN						; start condition
	movlw	0x3D						; address + read bit
	rcall	I2C_TX						; send byte
	rcall	I2C_OneByteRX					; receive 1 byte with acknowledge
	movlw	b'01001000'					; Identification Register A must be "H"
	cpfseq	SSP1BUF						; Compare with received value
	bcf	compass_type0					; Not equal -> Not compass 0
	rcall	I2C_PEN						; stop condition
	
	btfsc	compass_type0				; compass 0 found?
	bra	I2C_init_compass0			; YES - initialize compass 0
;	; no compass of any type found
	bcf	compass_present				; Delete global compass flag
	return


I2C_init_compass0:
	; magnetic
	rcall	I2C_SEN						; start condition
	movlw	0x3C						; address
	rcall	I2C_TX						; send byte
	movlw	0x00						; ??
	rcall	I2C_TX						; send byte
	movlw	b'01101000'					; ConfigA: 3 Hz, 8 samples averaged
	rcall	I2C_TX						; send byte
	movff	opt_compass_gain,i2c_temp1	; 0-7 (230 LSB/Gauss to 1370 LSB/Gauss)
	swapf	i2c_temp1,F					;
	comf	i2c_temp1,F					;
	bcf		STATUS,C					;
	rlcf	i2c_temp1					;
	movf	i2c_temp1,W					;
	rcall	I2C_TX						; send byte
	movlw	b'00000000'					; select continuous mode
	rcall	I2C_TX						; send byte
	rcall	I2C_PEN						; stop condition

	; accelerometer
	rcall	I2C_sleep_accelerometer0	; registers can only be changed in standby mode

	rcall	I2C_SEN						; start condition
	movlw	0x38						; address
	rcall	I2C_TX						; send byte
	movlw	0x0E						; XYZ_DATA_CFG
	rcall	I2C_TX						; send byte
	movlw	b'00000000'					; high pass filter = 0, +/- 2 g range
	rcall	I2C_TX						; send byte
	rcall	I2C_PEN						; stop condition
	rcall	I2C_SEN						; start condition
	movlw	0x38						; address
	rcall	I2C_TX						; send byte
	movlw	0x2A						; CTRL_REG1
	rcall	I2C_TX						; send byte
;	movlw	b'00110000'					; CTRL_REG1: 160 ms data rate, standby mode
	movlw	b'00110100'					; CTRL_REG1: 160 ms data rate, standby mode, reduced noise mode
	rcall	I2C_TX						; send byte
	movlw	b'00000010'					; CTRL_REG2: high-res in active mode
	rcall	I2C_TX						; send byte
	rcall	I2C_PEN						; stop condition

	rcall	I2C_SEN						; start condition
	movlw	0x38						; address
	rcall	I2C_TX						; send byte
	movlw	0x2A						; CTRL_REG1
	rcall	I2C_TX						; send byte
;	movlw	b'00110001'					; CTRL_REG1: 160 ms data rate, active  mode
	movlw	b'00110101'					; CTRL_REG1: 160 ms data rate, standby mode, reduced noise mode, active Mode
	rcall	I2C_TX						; send byte
	bra	I2C_PEN						; stop condition



I2C_init_compass1:
	rcall	I2C_SEN						; start condition
	movlw	0x3C						; address
	rcall	I2C_TX						; send byte
	movlw	0x9F						; 1F with auto-increment (MSB=1)
	rcall	I2C_TX						; send byte
	movlw	b'00000000'					; CTRL0
	rcall	I2C_TX						; send byte
	movlw	b'00101111'					; CTRL1 (6.25 Hz, BDU=0, x,y,z = ON)
	rcall	I2C_TX						; send byte
	movlw	b'11000000'					; CTRL2 (50 Hz, +/- 2g)
	rcall	I2C_TX						; send byte
	movlw	b'00000000'					; CTRL3
	rcall	I2C_TX						; send byte
	movlw	b'00000000'					; CTRL4
	rcall	I2C_TX						; send byte
	movlw	b'01100100'					; CTRL5 HIGH res, 6.25 Hz
	rcall	I2C_TX						; send byte
	movff	opt_compass_gain,i2c_temp1	; 0-7 (230 LSB/Gauss to 1370 LSB/Gauss)
	movlw	b'01100000'					; CTRL6 Full scale (+/-12 Gauss -> 2730 LSB/Gauss)
	dcfsnz	i2c_temp1,F					; = 1?
	movlw	b'01100000'					; YES - CTRL6 Full scale (+/-12 Gauss -> 2730 LSB/Gauss)
	dcfsnz	i2c_temp1,F					; = 2?
	movlw	b'01000000'					; YES - CTRL6 (+/-8 Gauss)
	dcfsnz	i2c_temp1,F					; = 3?
	movlw	b'01000000'					; YES - CTRL6 (+/-8 Gauss)
	dcfsnz	i2c_temp1,F					; = 4?
	movlw	b'00100000'					; YES - CTRL6 (+/-4 Gauss)
	dcfsnz	i2c_temp1,F					; = 5?
	movlw	b'00100000'					; YES - CTRL6 (+/-4 Gauss)
	dcfsnz	i2c_temp1,F					; = 6?
	movlw	b'00000000'					; YES - CTRL6 (+/-2 Gauss)
	dcfsnz	i2c_temp1,F					; = 7?
	movlw	b'00000000'					; YES - CTRL6 (+/-2 Gauss)
	rcall	I2C_TX						; send byte
	movlw	b'00000000'					; CTRL7 Continuous Mode
	rcall	I2C_TX						; send byte
	bra	I2C_PEN						; stop condition

	; accelerometer initializes along with magnetic sensor


I2C_init_compass2:
	; magnetic
	rcall	I2C_SEN						; start condition
	movlw	0x3C						; address
	rcall	I2C_TX						; send byte
	movlw	0xE0						; 0x60 with auto-increment (MSB=1)
	rcall	I2C_TX						; send byte
	movlw	b'10000000'					; CFG_REG_A_M (10Hz, Continuous) 0x60 0x00
	rcall	I2C_TX						; send byte
	movlw	b'00000011'					; CFG_REG_B_M (low-pass filter enabled) 0x61 (set pulse is released every 63 ODR)
	rcall	I2C_TX						; send byte
	movlw	b'00010000'					; CFG_REG_C_M BDU=1 0x62 0x57
	rcall	I2C_TX						; send byte
	rcall	I2C_PEN						; stop condition

	; accelerometer
	rcall	I2C_SEN						; start condition
	movlw	0x32						; address
	rcall	I2C_TX						; send byte
	movlw	0x9F						; 1F with auto-increment (MSB=1)
	rcall	I2C_TX						; send byte
	movlw	b'00000000'					; TEMP_CFG_REG_A (Temp sensor off)
	rcall	I2C_TX						; send byte
	movlw	b'00100111'					; CTRL_REG1_A (10Hz, x,y,z = ON)
	rcall	I2C_TX						; send byte
	movlw	b'00000000'					; CTRL_REG2_A
	rcall	I2C_TX						; send byte
	movlw	b'00000000'					; CTRL_REG3_A
	rcall	I2C_TX						; send byte
	movlw	b'00001000'					; CTRL_REG4_A (BDU=0, +/-2g, HR=1)
	rcall	I2C_TX						; send byte
;	movlw	b'00000000'					; CTRL_REG5_A
;	rcall	I2C_TX						; send byte
	bra	I2C_PEN						; stop condition


I2C_init_compass3:
	; magnetic
	rcall	I2C_SEN						; start condition
	movlw	0x3C						; address
	rcall	I2C_TX						; send byte
	movlw	0xA0						; 0x20 with auto-increment (MSB=1)
	rcall	I2C_TX						; send byte
	movlw	b'01110000'					; CTRL_REG1_M (10Hz, X and Y in Ultra-high performance mode) 0x20
	rcall	I2C_TX						; send byte
	movlw	b'01100000'					; CTRL_REG2_M (Full-scale: +/- 16gauss) 0x21
	rcall	I2C_TX						; send byte
	movlw	b'01000000'					; CTRL_REG3_M (Continuous) 0x22
	rcall	I2C_TX						; send byte
	movlw	b'00001100'					; CTRL_REG4_M (Z in Ultra-high performance mode) 0x23
	rcall	I2C_TX						; send byte
	movlw	b'00000000'					; CTRL_REG5_M 0x24
	rcall	I2C_TX						; send byte
	movlw	b'00000000'					; CTRL_REG5_M 0x24
	rcall	I2C_TX						; send byte
	rcall	I2C_PEN						; stop condition

	;accelerometer
	rcall	I2C_SEN						; start condition
	movlw	0x3A						; address
	rcall	I2C_TX						; send byte
	movlw	0x20
	rcall	I2C_TX						; send byte
	movlw	b'10010111'					; CTRL_REG1_A (100Hz, x,y,z = ON, BDU=OFF) 0x20
	rcall	I2C_TX						; send byte
	movlw	b'00000000'					; CTRL_REG2_A 0x21
	rcall	I2C_TX						; send byte
	movlw	b'00000000'					; CTRL_REG3_A 0x22
	rcall	I2C_TX						; send byte
	movlw	b'11001100'					; CTRL_REG4_A 0x23
	rcall	I2C_TX						; send byte
	bra	I2C_PEN						; stop condition
	

	
;-----------------------------------------------------------------------------
; Deactivate Compass / Accelerometer
;
	global	I2C_sleep_compass
I2C_sleep_compass:
	btfss	compass_enabled				; compass active?
	return								; NO - done
	bcf		compass_enabled
	btfsc	compass_type3				; compass 3 ?
	bra		I2C_sleep_compass3			; YES
	btfsc	compass_type2				; compass 2 ?
	bra		I2C_sleep_compass2			; YES
	btfsc	compass_type1				; compass 1 ?
	bra		I2C_sleep_compass1			; YES
	;bra	I2C_sleep_compass0			; NO  - must be compass 0 then


I2C_sleep_compass0:
	; magnetic
	rcall	I2C_SEN						; start condition
	movlw	0x3C						; address
	rcall	I2C_TX						; send byte
	movlw	0x00						; ??
	rcall	I2C_TX						; send byte
	movlw	b'01101000'					; ConfigA
	rcall	I2C_TX						; send byte
	movlw	b'00100000'					; ConfigB
	rcall	I2C_TX						; send byte
	movlw	b'00000010'					; idle mode
	rcall	I2C_TX						; send byte
	rcall	I2C_PEN						; stop condition

I2C_sleep_accelerometer0:
	; accelerometer
	rcall	I2C_SEN						; start condition
	movlw	0x38						; address
	rcall	I2C_TX						; send byte
	movlw	0x2A						; CTRL_REG1
	rcall	I2C_TX						; send byte
	movlw	b'00000000'					; standby mode
	rcall	I2C_TX						; send byte
	bra	I2C_PEN						; stop condition


I2C_sleep_compass1:
	rcall	I2C_SEN						; start condition
	movlw	0x3C						; address
	rcall	I2C_TX						; send byte
	movlw	0x20						; CTRL_REG1
	rcall	I2C_TX						; send byte
	movlw	b'00000000'					; data for CTRL_REG1: acceleration sensor power-down mode
	rcall	I2C_TX						; send byte
	rcall	I2C_PEN						; stop condition
	rcall	I2C_SEN						; start condition
	movlw	0x3C						; address
	rcall	I2C_TX						; send byte
	movlw	0x26						; CTRL_REG7
	rcall	I2C_TX						; send byte
	movlw	b'00000010'					; data for CTRL_REG7: magnetic sensor power-down mode
	rcall	I2C_TX						; send byte
	bra	I2C_PEN						; stop condition

	; accelerometer sleeps with magnetic sensor


I2C_sleep_compass2:
	; magnetic
	rcall	I2C_SEN						; start condition
	movlw	0x3C						; address
	rcall	I2C_TX						; send byte
	movlw	0xE0						; 0x60 with auto-increment (MSB=1)
	rcall	I2C_TX						; send byte
	movlw	b'00000011'					; CFG_REG_A_M    0x60 (idle mode))
	rcall	I2C_TX						; send byte
	movlw	b'00000100'					; CFG_REG_B_M    0x61 (set pulse is released only at power-on after PD condition)
	rcall	I2C_TX						; send byte
	movlw	b'01010001'					; CFG_REG_C_M    0x62
	rcall	I2C_TX						; send byte
	movlw	b'00000000'					; INT_CTRL_REG_M 0x63
	rcall	I2C_TX						; send byte
	rcall	I2C_PEN						; stop condition

	; accelerometer
	rcall	I2C_SEN						; start condition
	movlw	0x32						; address
	rcall	I2C_TX						; send byte
	movlw	0x9F						; 1F with auto-increment (MSB=1)
	rcall	I2C_TX						; send byte
	movlw	b'00000000'					; TEMP_CFG_REG_A  0x1F (temp sensor off)
	rcall	I2C_TX						; send byte
	movlw	b'00000000'					; CTRL_REG1_A     0x20 (all off)
	rcall	I2C_TX						; send byte
	bra	I2C_PEN						; stop condition


I2C_sleep_compass3:
	; magnetic
	rcall	I2C_SEN						; start condition
	movlw	0x3C						; address
	rcall	I2C_TX						; send byte
	movlw	0xA2						; 0x22 with auto-increment (MSB=1)
	rcall	I2C_TX						; send byte
	movlw	b'01000010'					; CTRL_REG3_M (power-down) 0x22
	rcall	I2C_TX						; send byte
	rcall	I2C_PEN						; stop condition

	; accelerometer
	rcall	I2C_SEN						; start condition
	movlw	0x3A						; address
	rcall	I2C_TX						; send byte
	movlw	0x20
	rcall	I2C_TX						; send byte
	movlw	b'00000000'					; CTRL_REG1_A (100Hz, x,y,z = OFF) 0x20
	rcall	I2C_TX						; send byte
	bra	I2C_PEN						; stop condition
	
	
;-----------------------------------------------------------------------------
; Helper Function - receive 1 Byte with Not-Acknowledge
;
I2C_OneByteRX_NACK:
	rcall	I2C_RCEN					; enable receive mode
	bsf	SSP1CON2,ACKDT					; set ACKDT flag
	rcall	I2C_ACKEN					; send master acknowledge
	bcf	SSP1CON2,ACKDT					; reset ACKDT flag
	return


;-----------------------------------------------------------------------------
; Helper Function - receive 1 Byte with Acknowledge
;
I2C_OneByteRX:
	rcall	I2C_RCEN					; enable receive mode
	bra	I2C_ACKEN					; send master acknowledge
	
;-----------------------------------------------------------------------------
; Helper Function - send 1 Byte, wait for end of transmission and check ackn
; add WREG to checksum byte first
I2C_TX_CHKSUM:
	addwf	sub_a+0,F					; add to checksum
;	bra	I2C_TX
;-----------------------------------------------------------------------------
; Helper Function - send 1 Byte, wait for end of transmission and check ackn
;
I2C_TX:
	movwf	SSP1BUF						; put byte to be sent into TX buffer
	btfss	i2c_error_flag_lock				; vault in use already?
	movff	WREG,i2c_error_vault+0				; NO, Store address	
	rcall	WaitMSSP					; wait for TX to complete
	bra		I2C_Check_ACK				; check for acknowledge by receiver and return

	
;-----------------------------------------------------------------------------
; Helper Function - I2C Start Condition
;
I2C_SEN:
	bsf	SSP1CON2,SEN					; start condition
	bra	WaitMSSP					; wait for TX to complete (And return)

;-----------------------------------------------------------------------------
; Helper Function - I2C Repeated Start Condition
;
I2C_RSEN:
	bsf	SSP1CON2,RSEN					; repeated start condition
	bra	WaitMSSP					; wait for TX to complete (And return)
	

;-----------------------------------------------------------------------------
; Helper Function - I2C Stop Condition
;
I2C_PEN:
	bsf	SSP1CON2,PEN					; stop condition
	rcall	WaitMSSP					; wait for TX to complete (And return)
I2C_WAIT_100US:	
	; add ~100탎 bus free time (min. 66탎 recommended for LTC2959)
	; Remark: not exact: 122탎 +/- 30.5 탎 + worst case ISR latency
	setf	TMR5H						; initialize timer 5, high byte first
	movlw	.255-.4						; 4 x 31.5 탎 = 126탎, min: 94,5탎
	movwf	TMR5L						; initialize timer 5, low  byte thereafter
	bcf	PIR5,TMR5IF					; clear timer 5 overrun flag
I2C_PEN_Loop:
	btfss	PIR5,TMR5IF					; did timer 5 overrun?
	bra	I2C_PEN_Loop					; NO  - repeat inner loop
	return

;-----------------------------------------------------------------------------
; Helper Function - Master Acknowledge	
;
I2C_ACKEN:
	bsf	SSP1CON2,ACKEN					; master acknowledge	
	bra	WaitMSSP					; wait for TX to complete (And return)

;-----------------------------------------------------------------------------
; Helper Function - Enable reeive mode
;
I2C_RCEN:
    	bsf	SSP1CON2,RCEN					; enable receive mode
	bra	WaitMSSP					; wait for TX to complete (And return)
	
;-----------------------------------------------------------------------------
; Helper Function - wait for TX to complete
;
WaitMSSP:
        btfss	i2c_error_flag_lock				; vault in use already?
	movff	SSP1BUF,i2c_error_vault+1			; NO, store value
	btfss	i2c_error_flag_lock				; vault in use already?
	movff	SSP1CON2,i2c_error_vault+2			; NO, store value
	clrf	i2c_temp1					; wait for max 256 loops
WaitMSSP_loop:
	decfsz	i2c_temp1,F					; decrement loop counter, timeout?
	bra		WaitMSSP2					; NO
	bra		I2CFail						; YES
WaitMSSP2:
	btfss	PIR1,SSP1IF					; TX completed?
	bra		WaitMSSP_loop				; NO  - loop
	bcf		PIR1,SSP1IF					; YES - clear TX completion flag
	return								;     - done


;-----------------------------------------------------------------------------
; Helper Function - Master NOT acknowledge and Stop
;
I2C_MasterNotAckStop:
	bsf		SSP1CON2,ACKDT				; set ACKDT flag
	rcall	I2C_ACKEN					; send master NOT acknowledge
	bcf		SSP1CON2,ACKDT				; reset ACKDT flag

	bra	I2C_PEN						; stop condition
	
;-----------------------------------------------------------------------------
; Helper Function - check for Acknowledge by Receiver
;
I2C_Check_ACK:
	btfss	SSP1CON2,ACKSTAT			; ACK received from slave?
	return								; YES - done
	;bra	I2CFail						; NO  - do some clean up


;-----------------------------------------------------------------------------
; Helper Function - clean up I2C Interface after missing Acknowledge
;
I2CFail:
	bsf		active_reset_ostc_rx		; reset RX circuitry (which may be the cause for the hang up)
	rcall	I2CReset					; reset I2C
	bcf		PIR1,SSP1IF					; clear TX completion flag
	bsf		i2c_error_flag				; set error flag
	bsf		i2c_error_flag_lock			; lock the error vault
	bcf		active_reset_ostc_rx		; release reset from RX circuitry
;	bcf	i2c_busy_temperature
;	bcf	i2c_busy_pressure
	return								; done


;-----------------------------------------------------------------------------
; Helper Function - Reset I2C Module
;
; recover in case something went wrong, i.g. slave holds SDA low
;
	global	I2CReset
I2CReset:
	clrf	SSP1CON1					; reset entire module
	clrf	SSP1CON2					; ...
	clrf	SSP1STAT					; ...
	bcf		TRISC,3						; SCL as OUTPUT
	bsf		TRISC,4						; SDA as input
	bcf		PORTC,3						; SCL = 0
	movlw	d'9'						; clock-out 9 clock cycles manually
	movwf	i2c_temp1					; ...
I2CReset_1:
	bsf		PORTC,3						; SCL = 1
	nop									; pause for 4 CPU cycles
	nop									; ...
	nop									; ...
	nop									; ...
	btfsc	PORTC,4						; SDA = 1 ?
	bra		I2CReset_2					; YES - SDA has been released from slave
	bcf		PORTC,3						; NO  - set SCL = 0
	nop									;     - pause for 2 CPU cycles
	nop									;     - ...
	bcf		PORTC,3						;     - SCL = 0
	nop									;     - pause for 2 CPU cycles
	nop									;     - ...
	decfsz	i2c_temp1,F					;     - clock counter, all cycles done?
	bra		I2CReset_1					;       NO - loop
I2CReset_2:
	bsf		TRISC,3						; SCL as input
	clrf	SSP1CON1					; setup I2C mode
	rcall	I2C_WAIT_100US					; ISR-Safe 100탎 wait
	movlw	b'00000000'					; enable slew rate control
	movwf	SSP1STAT					; ...
	movlw	b'00101000'					; configure I2C module
	movwf	SSP1CON1					; ...
	movlw	b'00000000'					; ...
	movwf	SSP1CON2					; ...
	movlw	i2c_speed_value
	movwf	SSP1ADD						; ...
	rcall	I2C_WAIT_100US					; ISR-Safe 100탎 wait
	movlw	.1
	addwf	i2c_error_counter+0
	movlw	.0
	addwfc	i2c_error_counter+1				; +1 on the error counter
	btfss	press_sensor_type				; =1: pressure sensor MS5837, =0: Pressure sensor MS5541
	return							; MS5541, Done.
	; reset the sensor
	rcall	I2C_SEN						; start condition
	movlw	0xEC						; address byte + write bit
	rcall	I2C_TX						; send byte
	movlw	0x1E
	rcall	I2C_TX						; send byte
	rcall	I2C_PEN						; stop condition
	WAITMS	.5						; 2.8ms according to datasheet
	return							; done


;-----------------------------------------------------------------------------
; Helper Function - Initialize Gauge IC again after an UVLO Event
;
battery_gauge_init_again:
	btfsc	battery_gauge_type				; =1: Gauge IC LTC2959, =0: LT2942
	return
	rcall   I2CReset
	movlw	0x02									; point to accumulated charge registers
	rcall	I2C_TX_GAUGE							; send byte to the LT2942 gauge IC
	movff	battery_accumulated_charge+1,SSP1BUF	; data byte
	rcall	WaitMSSP								; wait for TX to complete
	rcall	I2C_Check_ACK							; check for acknowledge by receiver
	movff	battery_accumulated_charge+0,SSP1BUF	; data byte
	rcall	WaitMSSP								; wait for TX to complete
	rcall	I2C_Check_ACK							; check for acknowledge by receiver
	rcall	I2C_PEN						; stop condition
	MOVII	battery_accumulated_charge,sub_a		; copy result to sub_a
	;bra	battery_gauge_init								; and initialize again...


;-----------------------------------------------------------------------------
; Initialize Gauge IC
;
	global	battery_gauge_init
battery_gauge_init:
	movlw	0x01						; point to control reg B / ADC Control
	rcall	I2C_TX_GAUGE					; send byte to the gauge IC
	movlw	b'11111000'					; automatic conversion every two seconds (LT2942)
	btfsc	battery_gauge_type				; =1: Gauge IC LTC2959, =0: LT2942
	movlw	b'00111000'					; ADC Mode to "Smart Sleep" (converts V, I, T every 52 seconds (tolerance < �5%)) (LTC2959)
	rcall	I2C_TX						; send byte
	btfsc	battery_gauge_type				; =1: Gauge IC LTC2959, =0: LT2942
	movlw	b'01010000'					; 20킮 deadband
	btfsc	battery_gauge_type				; =1: Gauge IC LTC2959, =0: LT2942
	rcall	I2C_TX						; send one byte more for the LTC2959
	bra	I2C_PEN						; stop condition

;-----------------------------------------------------------------------------
; Read Gauge IC - Status Register
;
	global	lt2942_get_status
lt2942_get_status:
	bcf	battery_gauge_type				; =1: Gauge IC LTC2959, =0: LT2942
	bcf	battery_gauge_available				; clear flag on default

	; try LTC2942
	rcall	I2C_SEN						; start condition
	movlw	0xC8						; address byte + Write bit
	movwf	SSP1BUF						; put byte to be sent into TX buffer
	rcall	WaitMSSP					; wait for TX to complete
	; we need the ACKSTAT bit! Do not use I2C_TX routine here which might reset this bit!
	btfss	SSP1CON2,ACKSTAT				; ACK received from slave?
	bsf	battery_gauge_available				; YES - set flag
	rcall	I2C_MasterNotAckStop				; Master NOT acknowledge and Stop
	btfsc	battery_gauge_available				; found?
	return							; YES - done
	
	; try LTC2959
	rcall	I2C_SEN						; start condition
	movlw	0xC6						; address byte + Write bit
	movwf	SSP1BUF						; put byte to be sent into TX buffer
	rcall	WaitMSSP					; wait for TX to complete
	; we need the ACKSTAT bit! Do not use I2C_TX routine here which might reset this bit!
	btfss	SSP1CON2,ACKSTAT				; ACK received from slave?
	bsf	battery_gauge_available				; YES - set flag
	rcall	I2C_MasterNotAckStop				; Master NOT acknowledge and Stop
	btfsc	battery_gauge_available				; found?
	bsf	battery_gauge_type				; =1: Gauge IC LTC2959, =0: LT2942
	return							; NO, return

;-----------------------------------------------------------------------------
; Read Gauge IC - Voltage
;
	global	lt2942_get_voltage
lt2942_get_voltage:
  
	btfsc	battery_gauge_type			; =1: Gauge IC LTC2959, =0: LT2942
	bra	LTC2959_get_voltage			; use new IC
	
	movlw	0x08						; point to voltage registers
	rcall	I2C_TX_GAUGE				; send    byte to   the LT2942 gauge IC
	rcall	I2C_RX_GAUGE				; receive byte from the LT2942 Gauge IC
	rcall	I2C_ACKEN					; send master acknowledge
	movff	SSP1BUF,xA+1				; copy received byte to xA+1
	rcall	I2C_RCEN					; enable receive mode
	movff	SSP1BUF,xA+0				; copy received byte to xA+0
	
	rcall	I2C_MasterNotAckStop				; Master NOT acknowledge and Stop
	
	; convert voltage from raw value to Volt
	MOVLI	.6000,xB					; load conversion multiplicand into xB
	call	mult16x16					; xC = xA * xB -> multiply raw value in xA with conversion multiplicand
										; divide by 65536 instead of 65535, introducing an error of 65536/65535 = 0.002 %
	movff	xC+2,xC+0			; divide by 65536 can easily be done by just taking the 3rd and 4th byte of the multiplication result
	movff	xC+3,xC+1			; use xC+0 and xC+1 as temp

	movlw	.4					; battery voltage < 4*256mV (1.024)?
	cpfslt	xC+1					; < 1024 mV ?
	bra	lt2942_get_voltage_check_high		; NO  - Continue checking
	bra	battery_gauge_init_again			; YES - initialize gauge and return (and leave batt_voltage:2 untouched)
	
lt2942_get_voltage_check_high:
    	movlw	.17					; battery voltage >= 17*256mV (4.352V)?
	cpfslt	xC+1					;     - ... ?
	bra	battery_gauge_init_again			; YES - initialize gauge and return (and leave batt_voltage:2 untouched)
	; NO  - done
	movff	xC+0, batt_voltage+0
	movff	xC+1, batt_voltage+1
	bra	lt2942_get_accumulated_charge	;     - read coulomb counter (And return)
	
LTC2959_get_voltage:
	movlw	0x0F						; point to voltage registers
	rcall	I2C_TX_GAUGE				; send    byte to   the gauge IC
	rcall	I2C_RX_GAUGE				; receive byte from the Gauge IC
	rcall	I2C_ACKEN					; send master acknowledge
	movff	SSP1BUF,xA+1				; copy received byte to xA+1
	rcall	I2C_RCEN					; enable receive mode
	movff	SSP1BUF,xA+0				; copy received byte to xA+0
	
	rcall	I2C_MasterNotAckStop				; Master NOT acknowledge and Stop
	
	; convert voltage from raw value to mV
	MOVLI	.62600,xB					; load conversion multiplicand into xB
	call	mult16x16					; xC = xA * xB -> multiply raw value in xA with conversion multiplicand
										; divide by 65536 instead of 65535, introducing an error of 65536/65535 = 0.002 %
	;movff	xC+2,xC+0			; divide by 65536 can easily be done by just taking the 3rd and 4th byte of the multiplication result
	;movff	xC+3,xC+1			; use xC+0 and xC+1 as temp

	movff	xC+2, batt_voltage+0
	movff	xC+3, batt_voltage+1
	rcall	lt2942_get_accumulated_charge	;     - read coulomb counter (And return)

	return								; done


;-----------------------------------------------------------------------------
; Read Gauge IC - Temperature
;
	global	lt2942_get_temperature
lt2942_get_temperature:					; read battery temperature
    	btfsc	battery_gauge_type			; =1: Gauge IC LTC2959, =0: LT2942
	bra	LTC2959_get_temperature

	movlw	0x0C						; point to temperature register
	rcall	I2C_TX_GAUGE				; send    byte to   the LT2942 gauge IC
	rcall	I2C_RX_GAUGE				; receive byte from the LT2942 Gauge IC
	rcall	I2C_ACKEN					; send master acknowledge
	movff	SSP1BUF,xA+1				; store raw temperature, high byte
	rcall	I2C_RCEN					; enable receive mode
	movff	SSP1BUF,xA+0				; store raw temperature, low byte
	rcall	I2C_MasterNotAckStop				; Master NOT acknowledge and Stop

	; convert temperature from raw value to Kelvin in 0.1K
	MOVLI	.6000,xB					; load conversion multiplicand into xB
	call	mult16x16					; xC = xA * xB -> multiply raw value in xA with conversion multiplicand
										; divide by 65536 instead of 65535, introducing an error of 65536/65535 = 0.002 %
	movff	xC+2,battery_temperature+0	; divide by 65536 can easily be done by just taking the 3rd and 4th byte of the multiplication result
	movff	xC+3,battery_temperature+1	; ...

lt2942_get_temperature_common:	
	; check if battery is being charged right now
	btfss	cc_active					; in CC charging mode?
	return								; NO  - not charging, done

	; ignore false readings (>125캜)
	movlw	LOW	.3307
	movwf	sub_a+0
	movlw	HIGH	.3307
	movwf	sub_a+1
	MOVII	battery_temperature,    sub_b
	call	cmpU16						; sub_a - sub_b (with UNSIGNED values)
	btfsc	neg_flag					; result negative?
	return							; YES  - temperature > 125캜, not possible here. Skip test.
	
	; check for over-temperature while charging
	MOVLI	max_battery_charge_temp,sub_a
	MOVII	battery_temperature,    sub_b
	call	cmpU16						; sub_a - sub_b (with UNSIGNED values)
	btfss	neg_flag					; result negative?
	return								; NO  - temperature <= threshold, ok, done
	return
										; YES - too hot, disable charging circuitry
	bsf		charge_disable				;     - set      charging-inhibit signal
	bcf		charge_enable				;     - activate charging-inhibit signal
	bsf		battery_overtemp			;     - flag that the battery charging over-temperature protection has tripped
	return							;     - done

LTC2959_get_temperature:	
	return
    

;-----------------------------------------------------------------------------
; Read Gauge IC - Read State of Charge
;
lt2942_get_accumulated_charge:			; read accumulated charge and compute percent
    	btfsc	battery_gauge_type			; =1: Gauge IC LTC2959, =0: LTC2942
	bra	LTC2959_get_accumulated_charge
    
	; old LTC2942
	movlw	0x00						; point to status register
	rcall	I2C_TX_GAUGE				; send    byte to   the LT2942 gauge IC
	rcall	I2C_RX_GAUGE				; receive byte from the LT2942 Gauge IC
	rcall	I2C_ACKEN					; send master acknowledge
	movff	SSP1BUF,gauge_status_byte	; copy received byte to gauge_status_byte

	rcall	I2C_RCEN					; enable receive mode
	movf	SSP1BUF,W					; dump to WREG (Control)
	rcall	I2C_ACKEN					; send master acknowledge

	rcall	I2C_RCEN					; enable receive mode
	movff	SSP1BUF,sub_a+1				; copy received byte to sub_a+1
	rcall	I2C_ACKEN					; send master acknowledge

	rcall	I2C_RCEN					; enable receive mode
	movff	SSP1BUF,sub_a+0				; copy received byte to sub_a+0
	rcall	I2C_MasterNotAckStop				; Master NOT acknowledge and Stop

lt2942_get_accumulated_charge2:	
	btfsc	gauge_status_byte,0			; UVLO event ?
	rcall	battery_gauge_init_again			; YES - do an re-initialization
	MOVII	sub_a,battery_accumulated_charge	; save raw value
	; Compute batt_percent = (charge - battery_offset) / capacity_xxxxxx
	MOVII	battery_offset,sub_b		; get battery offset
	call	subU16						; sub_c = sub_a - sub_b (with signed values)
	clrf	batt_percent				; default batt_percent to zero
	btfsc	neg_flag					; result negative?
	bra		lt2942_set_to_zero_percent	; YES - keep LT2942 at zero percent and return

	; > zero, set batt_percent properly
	MOVII	sub_c,xA					; copy net charge to xA
	MOVII	battery_capacity,xB			; get battery capacity into xB
	call	div16x16					; xC = xA / xB with xA as remainder
	movff	xC+0,batt_percent			; result is battery percentage
	movlw	.100						; max. value is  100 %
	cpfslt	batt_percent				; batt_percent < 100 % ?
	movwf	batt_percent				; NO  - limit to 100 %
	movlw	battery_cycle_counter_unlock
	cpfsgt	batt_percent				; < threshold ?
	bcf	lock_cycle_counter			; Yes, unlock cycle counter
	return								; done

LTC2959_get_accumulated_charge:
	movlw	0x00						; point to status register
	rcall	I2C_TX_GAUGE				; send    byte to   the LT2942 gauge IC
	rcall	I2C_RX_GAUGE				; receive byte from the LT2942 Gauge IC
	rcall	I2C_ACKEN					; send master acknowledge
	movff	SSP1BUF,gauge_status_byte	; copy received byte to gauge_status_byte

	rcall	I2C_RCEN					; enable receive mode
	movf	SSP1BUF,W					; dump to WREG (ADC Control)
	rcall	I2C_ACKEN					; send master acknowledge

	rcall	I2C_RCEN					; enable receive mode
	movf	SSP1BUF,W					; dump to WREG (Coulumb Counter Control)
	rcall	I2C_ACKEN					; send master acknowledge

	rcall	I2C_RCEN					; enable receive mode
	movff	SSP1BUF,xC+3				; copy received byte to xC+3
	rcall	I2C_ACKEN					; send master acknowledge

	rcall	I2C_RCEN					; enable receive mode
	movff	SSP1BUF,xC+2				; copy received byte to xC+2
	rcall	I2C_ACKEN					; send master acknowledge
	
	rcall	I2C_RCEN					; enable receive mode
	movff	SSP1BUF,xC+1				; copy received byte to xC+1
	rcall	I2C_ACKEN					; send master acknowledge

	rcall	I2C_RCEN					; enable receive mode
	movff	SSP1BUF,xC+0				; copy received byte to xC+0
	rcall	I2C_MasterNotAckStop				; Master NOT acknowledge and Stop

	MOVLI	.159,xB					; 159,4745717 (0,085mAh/533nAh)
	call	div32x16				; xC:4 = xC:4 / xB:2 with xA as remainder

	; clamp to 100% here
	tstfsz	xC+2					; Devision result > 0xFFFF
	setf	xC+0					; Yes, make sure xC:2 is 0xFFFF
	tstfsz	xC+2					; Devision result > 0xFFFF
	setf	xC+1					; Yes, make sure xC:2 is 0xFFFF
	
	movff	xC+1,sub_a+1
	movff	xC+0,sub_a+0				; put result in sub_a:2
;	
;	movff	sub_a+1,gp_debug+1
;	movff	sub_a+0,gp_debug+0
;	
	bra	lt2942_get_accumulated_charge2		; continue as with LT2942
	
	
lt2942_set_to_zero_percent:
    	btfsc	battery_gauge_type			; =1: Gauge IC LTC2959, =0: LT2942
	bra	LTC2959_set_to_zero_percent
    
	movlw	0x02						; point to accumulated charge registers
	rcall	I2C_TX_GAUGE				; send byte to the LT2942 gauge IC
	movff	battery_offset+1,SSP1BUF	; send battery offset, high byte
	rcall	WaitMSSP					; wait for TX to complete
	rcall	I2C_Check_ACK				; check for acknowledge by receiver
	movff	battery_offset+0,SSP1BUF	; send battery offset, low  byte
	rcall	WaitMSSP					; wait for TX to complete
	rcall	I2C_Check_ACK				; check for acknowledge by receiver
	bra	I2C_PEN						; stop condition (and return)

LTC2959_set_to_zero_percent:
	; multiply battery_offset:2 with 159 and write result to LTC2959
	
	MOVII	battery_offset,xA
	MOVLI	.159,xB					; 159,4745717 (0,085mAh/533nAh)
	call	mult16x16				; xC:4 = xA:2 * xB:2
	
	movlw	0x03						; point to accumulated charge registers
	rcall	I2C_TX_GAUGE				; send byte to the LT2942 gauge IC
	movff	xC+3,SSP1BUF				; send battery offset
	rcall	WaitMSSP					; wait for TX to complete
	rcall	I2C_Check_ACK				; check for acknowledge by receiver
	movff	xC+2,SSP1BUF				; send battery offset
	rcall	WaitMSSP					; wait for TX to complete
	rcall	I2C_Check_ACK				; check for acknowledge by receiver
	movff	xC+1,SSP1BUF				; send battery offset
	rcall	WaitMSSP					; wait for TX to complete
	rcall	I2C_Check_ACK				; check for acknowledge by receiver
	movff	xC+0,SSP1BUF				; send battery offset
	rcall	WaitMSSP					; wait for TX to complete
	rcall	I2C_Check_ACK				; check for acknowledge by receiver
	bra	I2C_PEN						; stop condition (and return)
    

;-----------------------------------------------------------------------------
; Read Gauge IC - Reset Accumulating Register to 0xFFFF
;
	global	lt2942_charge_done
lt2942_charge_done:
        btfsc	battery_gauge_type			; =1: Gauge IC LTC2959, =0: LT2942
	bra	lt2959_charge_done

	movlw	0x02						; point to accumulated charge registers
	rcall	I2C_TX_GAUGE				; send byte to the LT2942 gauge IC
	setf	SSP1BUF						; data byte
	rcall	WaitMSSP					; wait for TX to complete
	rcall	I2C_Check_ACK				; check for acknowledge by receiver
	setf	SSP1BUF						; data byte
	rcall	WaitMSSP					; wait for TX to complete
	rcall	I2C_Check_ACK				; check for acknowledge by receiver
	bra	I2C_PEN						; stop condition (and return)

lt2959_charge_done:
	; Reset Accumulating Register to 0x009EFF61 (0xFFFF * .159)
	movlw	0x03						; point to accumulated charge registers
	rcall	I2C_TX_GAUGE				; send byte to the LT2942 gauge IC
	movlw	0x00
	movwf	SSP1BUF						; data byte
	rcall	WaitMSSP					; wait for TX to complete
	rcall	I2C_Check_ACK				; check for acknowledge by receiver
	movlw	0x9E
	movwf	SSP1BUF						; data byte
	rcall	WaitMSSP					; wait for TX to complete
	rcall	I2C_Check_ACK				; check for acknowledge by receiver
	movlw	0xFF
	movwf	SSP1BUF						; data byte
	rcall	WaitMSSP					; wait for TX to complete
	rcall	I2C_Check_ACK				; check for acknowledge by receiver
	movlw	0x61
	movwf	SSP1BUF						; data byte
	rcall	WaitMSSP					; wait for TX to complete
	rcall	I2C_Check_ACK				; check for acknowledge by receiver
	bra	I2C_PEN						; stop condition (and return)

	
;-----------------------------------------------------------------------------
; Helper Function - send 1 Byte to the LT2942 Gauge IC
;
I2C_TX_GAUGE:
	movwf	i2c_temp2					; save data byte to be sent
	rcall	I2C_SEN						; start condition
	movlw	0xC8						; address byte + Write bit LT2942
	btfsc	battery_gauge_type				; =1: Gauge IC LTC2959, =0: LT2942
	movlw	0xC6						; address byte + Write bit LTC2559
	rcall	I2C_TX						; send byte
	movf	i2c_temp2,W					; restore data byte to be sent
	bra	I2C_TX						; send byte and return


;-----------------------------------------------------------------------------
; Helper Function - receive 1 Byte from the LT2942 Gauge IC
;
I2C_RX_GAUGE:
	rcall	I2C_RSEN					; repeated start condition	
	movlw	0xC9	    					; address byte + Read bit LT2942
	btfsc	battery_gauge_type				; =1: Gauge IC LTC2959, =0: LT2942
	movlw	0xC7						; address byte + Read bit LTC2959
	rcall	I2C_TX						; send byte
	bra	I2C_RCEN					; enable receive mode


;-----------------------------------------------------------------------------
; Reset Hardware and Software Battery Gauge
;
; called from comm.asm and menu_tree.asm
;
	global	reset_battery_gauge_and_lt2942
reset_battery_gauge_and_lt2942:
	btfsc	battery_gauge_available			; battery gauge chip available?
	call	lt2942_charge_done			; YES - reset meter to 0xFFFF
	;bra	reset_battery_gauge			; continue resetting gauge registers


;-----------------------------------------------------------------------------
; Reset Software Battery Gauge
;
	global	reset_battery_gauge
reset_battery_gauge:
	bsf		block_battery_gauge			; suspend ISR from accessing the battery registers
	movlw	.100						; set battery level to 100%
	movwf	batt_percent				; ...
	banksel	battery_gauge				; select bank ISR data
	clrf	battery_gauge+0				; null the battery registers
	clrf	battery_gauge+1				; ...
	clrf	battery_gauge+2				; ...
	clrf	battery_gauge+3				; ...
	clrf	battery_gauge+4				; ...
	clrf	battery_gauge+5				; ...
	banksel	charge_cycles
	clrf	charge_cycles+0				; null the charge cycles
	clrf	charge_cycles+1				; ...
	banksel	common						; back to bank common
	goto	eeprom_battery_gauge_write	; update battery registers in EEPROM, unblock ISR and return



 IFDEF _rx_functions

;-----------------------------------------------------------------------------
; OSTC TR - probe if TR Module available
;
	global	I2C_probe_OSTC_rx
I2C_probe_OSTC_rx:
	bcf		ostc_rx_present				; default to no TR module available
	clrf	WREG						; bank-safe set to zero of ...
	movff	WREG,rx_firmware_cur_major	; ... current TR module firmware, major
	movff	WREG,rx_firmware_cur_minor	; ... current TR module firmware, minor
	movlw	.5							; max number of tries for detecting a TR module
	movwf	hy							; initialize loop counter for tries
I2C_probe_OSTC_rx_1:
	rcall	I2C_SEN						; start condition
	movlw	0x50						; address byte + write bit
	rcall	I2C_TX						; send byte
	bsf		ostc_rx_present				; YES - TR module detected
	rcall	I2C_PEN						; stop condition
	btfss	ostc_rx_present				; was a TR module detected?
	return								; NO  - done

	WAITMS	.1							; wait 1 ms
	rcall	I2C_SEN						; start condition
	movlw	0x50						; address byte + write bit
	rcall	I2C_TX						; send byte
	movlw	0x1B						; command: get firmware
	rcall	I2C_TX						; send byte
	rcall	I2C_PEN						; stop condition

	WAITMS	.1							; wait 1 ms

	rcall	I2C_SEN						; start condition
	movlw	0x51						; address byte + Read bit
	movwf	SSP1BUF						; control byte
	rcall	WaitMSSP					; wait for TX to complete
	rcall	I2C_RCEN					; enable receive mode
	movff	SSP1BUF,rx_firmware_cur_major ; store as firmware version, major
	rcall	I2C_ACKEN					; send master acknowledge

	; last byte in read from RX circuity always with a NACK!
	rcall	I2C_RCEN					; enable receive mode
	movff	SSP1BUF,rx_firmware_cur_minor ; store as firmware version, minor
	rcall	I2C_MasterNotAckStop				; Master NOT acknowledge and Stop
	
	; wait for TR module becoming ready
	movff	rx_firmware_cur_minor,i2c_temp1	; copy minor firmware version to bank common
	movlw	.147							; code for not ready, minor
	cpfseq	i2c_temp1						; equal?
	return									; NO  - TR module ready, done
	movff	rx_firmware_cur_major,i2c_temp1 ; YES - copy major firmware version to bank common
	movlw	.27								;     - code for not ready, major
	cpfseq	i2c_temp1						;     - equal?
	return									;       NO  - TR module ready, done
	bsf		active_reset_ostc_rx			;       YES - apply reset to TR module
	WAITMS	.5								;           - wait 5 ms
	bcf		active_reset_ostc_rx			;           - release reset
	WAITMS	.250							;           - wait for     250 ms
	WAITMS	.250							;           - wait another 250 ms
	decfsz	hy,F							;           - decrement counter for number of tries, became zero?
	bra		I2C_probe_OSTC_rx_1				;           - NO  - try again
	bcf		ostc_rx_present					;           - YES - something is wrong, flag TR module as not available
	return									;                 - done


;-----------------------------------------------------------------------------
; OSTC TR - get Tank Data
;
	global	I2C_get_tankdata
I2C_get_tankdata:
	rcall	I2C_SEN						; start condition
	movlw	0x50						; address byte + write bit
	rcall	I2C_TX						; send byte
	movlw	0x1E						; read buffer2 (48 bytes)
	rcall	I2C_TX						; send byte
	rcall	I2C_PEN						; stop condition

	WAITMS	.1							; wait 1 ms

	; read 48 bytes
	rcall	I2C_SEN						; start condition
	movlw	0x51						; address byte + read bit
	rcall	I2C_TX						; send byte
	movlw	.47							; 47 with ACK + 1 w/o ACK
	movwf	i2c_temp2					; initialize loop counter
	lfsr	FSR2,rx_buffer				; point to start of rx data buffer 
I2C_get_tankdata_loop_read:
	rcall	I2C_RCEN					; enable receive mode
	movff	SSP1BUF,POSTINC2			; copy received byte to the rx buffer
	bcf		SSP1CON2,ACKDT				; reset ACKDT flag
	rcall	I2C_ACKEN					; send master acknowledge
	decfsz	i2c_temp2,F					; decrement loop counter, done?
	bra		I2C_get_tankdata_loop_read	; NO  - loop
	; read last byte without ACK
	rcall	I2C_RCEN					; enable receive mode
	movff	SSP1BUF,POSTINC2			; copy received byte to the rx buffer
	rcall	I2C_MasterNotAckStop				; Master NOT acknowledge and Stop
	return							; done



;-----------------------------------------------------------------------------
; OSTC TR - Firmware Update
;
 IFDEF _rx_update

	global	I2C_update_OSTC_rx
I2C_update_OSTC_rx:						; transfer 64 byte to RX co-processor
	; setup for write
	bcf		i2c_error_flag				; clear error flag
	lfsr	FSR2,buffer					; initialize pointer to send buffer used for verify
	movlw	.64							; initialize loop counter: 64 byte with ACK
	movwf	i2c_temp2					; ...
	; address write
	rcall	I2C_SEN						; start condition
	movlw	0x50						; address byte + write bit
	rcall	I2C_TX						; send byte
	; write 64 bytes
I2C_update_OSTC_loop:
	TBLRD*+								; read a byte from program memory
	movff	TABLAT,POSTINC2				; copy to send buffer
	movf	TABLAT,W				; copy to W
	rcall	I2C_TX						; send byte
	decfsz	i2c_temp2,F					;decrement loop counter, became zero?
	bra		I2C_update_OSTC_loop		; NO  - loop
	rcall	I2C_PEN						; stop condition
	WAITMS	.1							;     - wait another 1 ms
	; setup for read-back
	lfsr	FSR2,buffer					; reset pointer to begin of send buffer
	movlw	.63							; initialize loop counter: 63 byte with ACK + 1 w/o ACK
	movwf	i2c_temp2					; ...
	; address read-back
	rcall	I2C_SEN						; start condition
	movlw	0x51						; address byte + read bit
	rcall	I2C_TX						; send byte
	; read-back 64 bytes
I2C_update_OSTC_loop_read:
	rcall	I2C_RCEN					; enable receive mode
	movf	SSP1BUF,W					; copy received byte to WREG
	cpfseq	POSTINC2					; compare read-back byte with sent byte, equal?
	bsf		i2c_error_flag				; NO  - not equal, set error flag
	bcf		SSP1CON2,ACKDT				; reset ACKDT flag
	rcall	I2C_ACKEN					; send master acknowledge
	decfsz	i2c_temp2,F					; decrement loop counter, became zero?
	bra		I2C_update_OSTC_loop_read	; NO  - loop
	; 1 w/o ACK
	bsf		SSP1CON2, RCEN				; YES - enable receive mode
	rcall	WaitMSSP					;     - wait for TX to complete
	movf	SSP1BUF,W					;     - get 64th byte
	cpfseq	POSTINC2					;     - compare read-back byte with sent byte, equal?
	bsf		i2c_error_flag				;       NO  - not equal, set error flag
	rcall	I2C_MasterNotAckStop				; Master NOT acknowledge and Stop
	WAITMS	.1
	; address commit
	rcall	I2C_SEN						; start condition
	movlw	0x50						; address byte + write bit
	rcall	I2C_TX						; send byte
	movlw	0x1F						; write command
	rcall	I2C_TX						; send byte
	rcall	I2C_PEN						; stop condition
	WAITMS	.5							; required waiting time
	; error check
	btfss	i2c_error_flag				; did an error occur?
	retlw	.0							; NO  - data transfered successfully
	retlw	.255						; YES - error in data transfer occurred

 ENDIF	; _rx_update

 ENDIF	; _rx_functions
 
;-----------------------------------------------------------------------------
; Probe for MS5837 sensor
;
 	global	I2C_probe_pressure_sensor	; Do not call from ISR!
I2C_probe_pressure_sensor:						; Probe the type of sensor, set/clear press_sensor_type
	bcf	press_sensor_type				; MS5541 as default
	rcall	I2C_SEN						; start condition
	movlw	0xEC						; address byte + write bit
	movwf	SSP1BUF						; control byte
	rcall	WaitMSSP					; wait for TX to complete
	; we need the ACKSTAT bit! Do not use I2C_TX routine here which might reset this bit!
	btfss	SSP1CON2,ACKSTAT				; ACK received?
	bsf	press_sensor_type				; MS5837 sensor found
	bra	I2C_PEN						; stop condition
 
;--------------------------------------------------------------------
; Helper Function - get the calibration parameter from # WREG address
; Do not call from ISR!
I2C_get_calib_parameter:
	movwf	lo						; store address
	rcall	I2C_SEN						; start condition
	movlw	0xEC						; address byte + write bit
	rcall	I2C_TX						; send byte
	movf	lo,W						; Point to calibration register
	rcall	I2C_TX						; send byte
	rcall	I2C_PEN						; stop condition
	
	rcall	I2C_SEN						; start condition
	movlw	0xED					; address byte + read bit
	rcall	I2C_TX						; send byte 
	rcall	I2C_RCEN					; enable receive mode
	movff	SSP1BUF,dMSB				; High byte
	rcall	I2C_ACKEN					; send master acknowledge

	rcall	I2C_OneByteRX_NACK			; receive last byte with not acknowledge
	movff	SSP1BUF,dLSB				; Low byte
	bra	I2C_PEN						; stop condition
    
	
	global	I2C_get_calib_MS5837 ; Do not call from ISR!
I2C_get_calib_MS5837:	
	banksel	common
	; first, send a reset
	rcall	I2C_SEN						; start condition
	movlw	0xEC						; address byte + write bit
	rcall	I2C_TX						; send byte
	movlw	0x1E
	rcall	I2C_TX						; send byte
	rcall	I2C_PEN						; stop condition
	WAITMS	.5						; 2.8ms according to datasheet
	
	movlw	0xA2						; Point to C1
	rcall	I2C_get_calib_parameter				; returns calibration value in lo and hi
    	movff	dLSB,C1+0						; store calib
	movff	dMSB,C1+1						; store calib

	movlw	0xA4						; Point to C2
	rcall	I2C_get_calib_parameter				; returns calibration value in lo and hi
    	movff	dLSB,C2+0						; store calib
	movff	dMSB,C2+1						; store calib

	movlw	0xA6						; Point to C3
	rcall	I2C_get_calib_parameter				; returns calibration value in lo and hi
    	movff	dLSB,C3+0						; store calib
	movff	dMSB,C3+1						; store calib

	movlw	0xA8						; Point to C4
	rcall	I2C_get_calib_parameter				; returns calibration value in lo and hi
    	movff	dLSB,C4+0						; store calib
	movff	dMSB,C4+1						; store calib

	movlw	0xAA						; Point to C5
	rcall	I2C_get_calib_parameter				; returns calibration value in lo and hi
    	movff	dLSB,C5+0						; store calib
	movff	dMSB,C5+1						; store calib

	movlw	0xAC						; Point to C6
	rcall	I2C_get_calib_parameter				; returns calibration value in lo and hi
    	movff	dLSB,C6+0						; store calib
	movff	dMSB,C6+1						; store calib
	
	return

	global	I2C_get_press_val_MS5837
I2C_get_press_val_MS5837:
    	btfsc	i2c_reinit_sensor2				; Sensor ok?
	rcall	I2CReset					; Try a I2C reset first
	btfsc	i2c_reinit_sensor2				; Sensor ok?
	bra	I2C_get_press_val_MS5837_skip			; We did a reset, restart conversion first
	
	rcall	I2C_SEN						; start condition
	movlw	0xEC						; address byte + write bit
	rcall	I2C_TX						; send byte
	movlw	0x00						; command byte (0x00, read ADC)
	rcall	I2C_TX						; send byte
	
	rcall	I2C_RSEN					; repeated start condition	
	movlw	0xED					; address byte + read bit
	rcall	I2C_TX						; send byte

	bsf	i2c_busy_pressure				; reading new pressure
	rcall	I2C_RCEN					; enable receive mode
	movff	SSP1BUF,D1_buffer+2					; Upper byte
	rcall	I2C_ACKEN					; send master acknowledge
	rcall	I2C_RCEN					; enable receive mode
	movff	SSP1BUF,D1_buffer+1					; high byte
	rcall	I2C_ACKEN					; send master acknowledge
	rcall	I2C_RCEN					; enable receive mode
	movff	SSP1BUF,D1_buffer+0					; Low byte

	rcall	I2C_MasterNotAckStop				; Master NOT acknowledge and Stop
	bcf	i2c_busy_pressure				; reading new pressure done.

I2C_get_press_val_MS5837_skip:	
	; Start temperature measurement
	rcall	I2C_SEN						; start condition
	movlw	0xEC						; address byte + write bit
	rcall	I2C_TX						; send byte
	movlw	0x58						; OSR=4096, type=D2
	rcall	I2C_TX						; send byte
	rcall	I2C_PEN						; stop condition
	bcf	ms5837_state					; =0: result of temperature will be in the ADC
	bcf	i2c_reinit_sensor2				; Clear error flag
    	return
	
	global	I2C_get_temp_val_MS5837	
I2C_get_temp_val_MS5837:
	btfsc	i2c_reinit_sensor2				; Sensor ok?
	rcall	I2CReset					; Try a I2C reset first
	btfsc	i2c_reinit_sensor2				; Sensor ok?
	bra	I2C_get_temp_val_MS5837_skip			; We did a reset, restart conversion first
	
	rcall	I2C_SEN						; start condition
	movlw	0xEC						; address byte + write bit
	rcall	I2C_TX						; send byte
	movlw	0x00						; command byte (0x00, read ADC)
	rcall	I2C_TX						; send byte
	
	rcall	I2C_RSEN					; repeated start condition	
	movlw	0xED					; address byte + read bit
	rcall	I2C_TX						; send byte

	bsf	i2c_busy_temperature				; reading new temperature
	rcall	I2C_RCEN					; enable receive mode
	movff	SSP1BUF,D2_buffer+2					; Upper byte
	rcall	I2C_ACKEN					; send master acknowledge
	rcall	I2C_RCEN					; enable receive mode
	movff	SSP1BUF,D2_buffer+1					; high byte
	rcall	I2C_ACKEN					; send master acknowledge
	rcall	I2C_RCEN					; enable receive mode
	movff	SSP1BUF,D2_buffer+0					; Low byte

	rcall	I2C_MasterNotAckStop				; Master NOT acknowledge and Stop
	bcf	i2c_busy_temperature				; reading new temperature done.

I2C_get_temp_val_MS5837_skip:	
	; Start pressure measurement
	rcall	I2C_SEN						; start condition
	movlw	0xEC						; address byte + write bit
	rcall	I2C_TX						; send byte
	movlw	0x48						; OSR=4096, type=D1
	rcall	I2C_TX						; send byte
	rcall	I2C_PEN						; stop condition
	bsf	ms5837_state					; =0: result of pressure will be in the ADC
	bcf	i2c_reinit_sensor2				; Clear error flag
	return
	
	
;-----------------------------------------------------------------------------
; I2C Bus error checker 
;
	global	check_i2c_error
	extern TFT_message_i2c_error
check_i2c_error:
	btfss	i2c_error_flag
	return
	bcf	i2c_error_flag_lock				; arm error vault again
	incf	message_counter,F				; increase message counter
	goto	TFT_message_i2c_error				; show message for battery low (battery percent) and return

;-----------------------------------------------------------------------------	
	END
