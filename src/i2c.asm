;=============================================================================
;
;   File i2c.asm                            * combined next generation V3.09.4b
;
;   I2C Interface
;
;   Copyright (c) 2012, JD Gascuel, HeinrichsWeikamp, all right reserved.
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
; Helper Function - send 1 Byte, wait for end of transmission and check ackn
;
I2C_TX:
	movwf	SSP1BUF						; put byte to be sent into TX buffer
	rcall	WaitMSSP					; wait for TX to complete
	bra		I2C_Check_ACK				; check for acknowledge by receiver and return


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

I2C_RX_accelerometer_compass0:
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP					; wait for TX to complete
	movlw	0x38						; address
	rcall	I2C_TX						; send byte
	movlw	0x00						; ??
	rcall	I2C_TX						; send byte
	bsf		SSP1CON2,RSEN				; repeated start condition
	rcall	WaitMSSP					; wait for TX to complete
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
	btfsc	flip_screen					; 180° rotation?
	bra		I2C_RX_accelerometer2		; YES
	comf	hi							; NO  - 16 bit sign change
	negf	lo							;     - ....
	btfsc	STATUS,C					;     - carry to propagate?
	incf	hi,F						;     - YES - do it
I2C_RX_accelerometer2:
	MOVII	mpr,accel_DX				; copy result to accel_DX

	rcall	I2C_TwoBytesRX_div16		; get two bytes and divide /16 (signed)
	btfsc	flip_screen					; 180° rotation?
	bra		I2C_RX_accelerometer3		; YES
	comf	hi							; NO  - 16 bit sign change
	negf	lo							;     - ...
	btfsc	STATUS,C					;     - carry to propagate?
	incf	hi,F						;       YES - do it
I2C_RX_accelerometer3:
	MOVII	mpr,accel_DY				; copy result to accel_DY

	rcall	I2C_OneByteRX				; receive 1 byte with acknowledge
	movff	SSP1BUF,hi					; copy data byte to hi
	bsf		SSP1CON2,RCEN				; enable receive mode
	rcall	WaitMSSP					; wait for TX to complete
	; according to data sheet there should be no master acknowledge for the last byte (accel_DZ+0)...
	movff	SSP1BUF,lo					; copy data byte to lo
	rcall	I2C_TwoBytesRX_div16_2		; divide hi:lo/16 (signed)
	comf	hi							; 16 bit sign change
	negf	lo							; ...
	btfsc	STATUS,C					; carry to propagate?
	incf	hi,F						; YES - do it
	MOVII	mpr,accel_DZ				; copy result to accel_DZ
	bsf		SSP1CON2,PEN				; stop condition
	bra		WaitMSSP					; wait for TX to complete and return


I2C_RX_accelerometer_compass1:
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP					; wait for TX to complete
	movlw	0x3C						; address
	rcall	I2C_TX						; send byte
	movlw	b'10101000'					; 0x28 with auto-increment (MSB=1)
	rcall	I2C_TX						; send byte
	bsf		SSP1CON2,RSEN				; repeated start condition (!)
	rcall	WaitMSSP					; wait for TX to complete
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
	btfss	flip_screen					; 180° rotation?
	bra		I2C_RX_accelerometer2_c1	; NO  - continue with normal compass1 routines for Y and Z
	; flipped compass 2, negate x
	comf	hi							; YES - 16 bit sign change
	negf	lo							;     - ...
	btfsc	STATUS,C					;     - carry to propagate?
	incf	hi,F						;       YES - do it
	bra		I2C_RX_accelerometer2_c1	;     - continue with normal compass1 routines for Y and Z

I2C_RX_accelerometer1_c1:
	btfsc	flip_screen					; 180° rotation?
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
	btfsc	flip_screen					; 180° rotation?
	bra		I2C_RX_accelerometer3_c1	; YES
	comf	hi							; NO  - 16 bit sign change
	negf	lo							;     - ...
	btfsc	STATUS,C					;     - carry to propagate?
	incf	hi,F						;       YES - do it
I2C_RX_accelerometer3_c1:
	MOVII	mpr,accel_DY				; copy result
	rcall	I2C_OneByteRX				; receive 1 byte with acknowledge
	movff	SSP1BUF,lo					; accel_DZ+0
	bsf		SSP1CON2,RCEN				; enable receive mode
	rcall	WaitMSSP					; wait for TX to complete
	; according to data sheet there should be no master Acknowledge for the last byte (accel_DZ+1)...
	movff	SSP1BUF,hi					; accel_DZ+1
	bsf		SSP1CON2,PEN				; stop condition
	rcall	WaitMSSP					; wait for TX to complete
	rcall	I2C_TwoBytesRX_div16_2		; divide lo:hi/16 (signed) only
	comf	hi							; 16 bit sign change for Z
	negf	lo							; ...
	btfsc	STATUS,C					; carry to propagate?
	incf	hi,F						; YES - do it
	MOVII	mpr,accel_DZ				; copy result
	return								; done


I2C_RX_accelerometer_compass2:
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP					; wait for TX to complete
	movlw	0x32						; address
	rcall	I2C_TX						; send byte
	movlw	b'10101000'					; 0x28 with auto-increment (MSB=1)
	rcall	I2C_TX						; send byte
	bsf		SSP1CON2,RSEN				; repeated start condition (!)
	rcall	WaitMSSP					; wait for TX to complete
	movlw	0x33						; address
	bra		I2C_RX_accelerometer_common	; continue with common part

I2C_RX_accelerometer_compass3:
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP					; wait for TX to complete
	movlw	0x3A						; address
	rcall	I2C_TX						; send byte
	movlw	0x28						; 0x28 (OUT_X_L_A)
	rcall	I2C_TX						; send byte
	bsf		SSP1CON2,RSEN				; repeated start condition (!)
	rcall	WaitMSSP					; wait for TX to complete
	movlw	0x3B						; address
	bra		I2C_RX_accelerometer_common	; continue with common part


;-----------------------------------------------------------------------------
; Helper Function - receive 1 Byte with Acknowledge
;
I2C_OneByteRX:
	bsf		SSP1CON2,RCEN				; enable receive mode
	rcall	WaitMSSP					; wait for TX to complete
	bsf		SSP1CON2,ACKEN				; send master acknowledge
	bra		WaitMSSP					; wait for TX to complete and return


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

I2C_RX_compass0:
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP					; wait for TX to complete
	movlw	0x3C						; address
	rcall	I2C_TX						; send byte
	movlw	0x03						; ??
	rcall	I2C_TX						; send byte
	bsf		SSP1CON2,PEN				; stop condition
	rcall	WaitMSSP					; wait for TX to complete
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP					; wait for TX to complete
	movlw	0x3D						; address
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
	btfsc	flip_screen					; 180° rotation?
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
	bsf		SSP1CON2,RCEN				; enable receive mode
	rcall	WaitMSSP					; wait for TX to complete
	movff	SSP1BUF,compass_DX+0		; data byte
	bsf		SSP1CON2,PEN				; stop condition
	rcall	WaitMSSP					; wait for TX to complete
	btfss	flip_screen					; 180° rotation?
	return								; NO  - done
	banksel	compass_DX					; YES - flip X
	comf	compass_DX+1				;     - 16 bit sign change
	negf	compass_DX+0
	btfsc	STATUS,C					;     - carry to propagate?
	incf	compass_DX+1,F				;       YES - do it
	banksel	common						; back to bank common
	return								; done


I2C_RX_compass1:						; compass type 1
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP					; wait for TX to complete
	movlw	0x3C						; address
	rcall	I2C_TX						; send byte
	movlw	b'10001000'					; 0x08 with auto-increment (MSB=1)
	rcall	I2C_TX						; send byte
	bsf		SSP1CON2,RSEN				; repeated start condition (!)
	rcall	WaitMSSP					; wait for TX to complete
	movlw	0x3D						; address
	rcall	I2C_TX						; send byte
	;rcall	WaitMSSP					; TODO needed? (mH)
	rcall	I2C_OneByteRX				; receive 1 byte with acknowledge
	movff	SSP1BUF,lo					; data byte
	rcall	I2C_OneByteRX				; receive 1 byte with acknowledge
	movff	SSP1BUF,hi					; data byte
	rcall	I2C_TwoBytesRX_div8			; divide hi,lo by 8 (signed)
	MOVII	mpr,compass_DX				; copy result
	btfss	flip_screen					; 180° rotation?
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
	btfss	flip_screen					; 180° rotation?
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
	bsf		SSP1CON2, RCEN				; Enable receive mode
	rcall	WaitMSSP					; wait for TX to complete
	movff	SSP1BUF,hi					; data byte
	rcall	I2C_TwoBytesRX_div8			; divide hi, lo by 8 (signed)
	MOVII	mpr,compass_DZ				; copy result
	bsf		SSP1CON2,PEN				; stop condition
	bra		WaitMSSP					; ... and return


I2C_RX_compass2:						; compass type 2
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP					; wait for TX to complete
	movlw	0x3C						; address
	rcall	I2C_TX						; send byte
	movlw	0xE8						; 0x68 with auto-increment (MSB=1)
	rcall	I2C_TX						; send byte
	bsf		SSP1CON2,RSEN				; repeated start condition (!)
	rcall	WaitMSSP					; wait for TX to complete
	movlw	0x3D						; address
	rcall	I2C_TX						; send byte
I2C_RX_compass2_xx:						; compass 3 joins in here
;	rcall	WaitMSSP					; wait for TX to complete (not needed, as included in I2C_TX)
	rcall	I2C_OneByteRX				; receive 1 byte with acknowledge
	movff	SSP1BUF,lo					; data byte
	rcall	I2C_OneByteRX				; receive 1 byte with acknowledge
	movff	SSP1BUF,hi					; data byte
;	rcall	I2C_TwoBytesRX_div8			; divide hi, lo by 8 (signed)
	btfsc	flip_screen					; 180° rotation?
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
	btfss	flip_screen					; 180° rotation?
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
	rcall	I2C_OneByteRX				; receive 1 byte with acknowledge
	movff	SSP1BUF,hi					; data byte
;	rcall	I2C_TwoBytesRX_div8			; divide hi, lo by 8 (signed)
	MOVII	mpr,compass_DZ				; copy result
	bsf		SSP1CON2,PEN				; stop condition
	bra		WaitMSSP					; ...and return


I2C_RX_compass3:						; compass type 3
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP					; wait for TX to complete
	movlw	0x3C						; address
	rcall	I2C_TX						; send byte
	movlw	0xA8						; 0x28 with auto-increment (MSB=1)
	rcall	I2C_TX						; send byte
	bsf		SSP1CON2,RSEN				; repeated start condition (!)
	rcall	WaitMSSP					; wait for TX to complete
	movlw	0x3D						; address
	rcall	I2C_TX						; send byte
	bra		I2C_RX_compass2_xx			; join with compass 2 code

 ENDIF	; _compass


;-----------------------------------------------------------------------------
; Initialize Compass / Accelerometer Chip
;
	global	I2C_init_compass
I2C_init_compass:
	bsf		compass_enabled				; flag compass will be enabled
	bcf		compass_type2				; clear in preparation of chip detection
	bcf		compass_type3				; ...

	; probe for compass 3
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP					; wait for TX to complete
	movlw	0x3A						; address byte + write bit
	movwf	SSP1BUF						; control byte
	rcall	WaitMSSP					; wait for TX to complete
	btfss	SSP1CON2,ACKSTAT			; ACK received?
	bsf		compass_type3				; YES - ACK was send, compass 3 found
	bsf		SSP1CON2,PEN				; stop condition
	rcall	WaitMSSP					; wait for TX to complete

	btfsc	compass_type3				; compass 3 found?
	bra		I2C_init_compass3			; YES - initialize compass 3

	; probe for compass 2
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP					; wait for TX to complete
	movlw	0x32						; address byte + write bit
	movwf	SSP1BUF						; control byte
	rcall	WaitMSSP					; wait for TX to complete
	btfss	SSP1CON2,ACKSTAT			; ACK received?
	bsf		compass_type2				; YES - ACK send, compass 2 found
	bsf		SSP1CON2,PEN				; stop condition
	rcall	WaitMSSP					; wait for TX to complete

	btfsc	compass_type2				; compass 2 found?
	bra		I2C_init_compass2			; YES - initialize compass 2

	; probe for compass 0 or 1
	bsf		compass_type1				; assume compass 1 by default
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP					; wait for TX to complete
	movlw	0x3C						; address
	rcall	I2C_TX						; send byte
	movlw	0x0F						; ??
	rcall	I2C_TX						; send byte
	bsf		SSP1CON2,PEN				; stop condition
	rcall	WaitMSSP					; wait for TX to complete
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP					; wait for TX to complete
	movlw	0x3D						; address
	rcall	I2C_TX						; send byte
	rcall	I2C_OneByteRX				; receive 1 byte with acknowledge
	movlw	0x49						; 0x49 = compass 1
	cpfseq	SSP1BUF						; 0x49 received?
	bcf		compass_type1				; NO - clear flag for compass 1
	bsf		SSP1CON2,PEN				; stop condition
	rcall	WaitMSSP					; wait for TX to complete

	btfsc	compass_type1				; compass 1 found?
	bra		I2C_init_compass1			; YES - initialize compass 1
	;bra	I2C_init_compass0			; NO  - must be compass 0 then


I2C_init_compass0:
	; magnetic
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP					; wait for TX to complete
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
	bsf		SSP1CON2,PEN				; stop condition
	rcall	WaitMSSP					; wait for TX to complete

	; accelerometer
	rcall	I2C_sleep_accelerometer0	; registers can only be changed in standby mode

	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP					; wait for TX to complete
	movlw	0x38						; address
	rcall	I2C_TX						; send byte
	movlw	0x0E						; XYZ_DATA_CFG
	rcall	I2C_TX						; send byte
	movlw	b'00000000'					; high pass filter = 0, +/- 2 g range
	rcall	I2C_TX						; send byte
	bsf		SSP1CON2,PEN				; stop condition
	rcall	WaitMSSP					; wait for TX to complete
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP					; wait for TX to complete
	movlw	0x38						; address
	rcall	I2C_TX						; send byte
	movlw	0x2A						; CTRL_REG1
	rcall	I2C_TX						; send byte
;	movlw	b'00110000'					; CTRL_REG1: 160 ms data rate, standby mode
	movlw	b'00110100'					; CTRL_REG1: 160 ms data rate, standby mode, reduced noise mode
	rcall	I2C_TX						; send byte
	movlw	b'00000010'					; CTRL_REG2: high-res in active mode
	rcall	I2C_TX						; send byte
	bsf		SSP1CON2,PEN				; stop condition
	rcall	WaitMSSP					; wait for TX to complete

	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP					; wait for TX to complete
	movlw	0x38						; address
	rcall	I2C_TX						; send byte
	movlw	0x2A						; CTRL_REG1
	rcall	I2C_TX						; send byte
;	movlw	b'00110001'					; CTRL_REG1: 160 ms data rate, active  mode
	movlw	b'00110101'					; CTRL_REG1: 160 ms data rate, standby mode, reduced noise mode, active Mode
	rcall	I2C_TX						; send byte
	bsf		SSP1CON2,PEN				; stop condition
	bra		WaitMSSP					; wait for TX to complete and return


I2C_init_compass1:
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP					; wait for TX to complete
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
	bsf		SSP1CON2,PEN				; stop condition
	bra		WaitMSSP					; wait for TX to complete and return

	; accelerometer initializes along with magnetic sensor


I2C_init_compass2:
	; magnetic
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP					; wait for TX to complete
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
	bsf		SSP1CON2,PEN				; stop condition
	rcall	WaitMSSP					; wait for TX to complete

	; accelerometer
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP					; wait for TX to complete
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
	bsf		SSP1CON2,PEN				; stop condition
	bra		WaitMSSP					; wait for TX to complete and return


I2C_init_compass3:
	; magnetic
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP					; wait for TX to complete
	movlw	0x3C						; address
	rcall	I2C_TX						; send byte
	movlw	0xA0						; 0x20 with auto-increment (MSB=1)
	rcall	I2C_TX						; send byte
	movlw	b'01110000'					; CTRL_REG1_M (10Hz) 0x20
	rcall	I2C_TX						; send byte
	movlw	b'01100000'					; CTRL_REG2_M (Full-scale: +/- 16gauss) 0x21
	rcall	I2C_TX						; send byte
	movlw	b'01000000'					; CTRL_REG3_M (Continuous) 0x22
	rcall	I2C_TX						; send byte
	movlw	b'00000000'					; CTRL_REG4_M (Z in Low-power mode) 0x23
	rcall	I2C_TX						; send byte
	movlw	b'00000000'					; CTRL_REG5_M 0x24
	rcall	I2C_TX						; send byte
	movlw	b'00000000'					; CTRL_REG5_M 0x24
	rcall	I2C_TX						; send byte
	bsf		SSP1CON2,PEN				; Stop condition
	rcall	WaitMSSP					; wait for TX to complete

	;accelerometer
	bsf	SSP1CON2,SEN					; start condition
	rcall	WaitMSSP					; wait for TX to complete
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
	bsf		SSP1CON2,PEN				; stop condition
	bra		WaitMSSP					; wait for TX to complete and return


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
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP					; wait for TX to complete
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
	bsf		SSP1CON2,PEN				; stop condition
	rcall	WaitMSSP					; wait for TX to complete

I2C_sleep_accelerometer0:
	; accelerometer
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP					; wait for TX to complete
	movlw	0x38						; address
	rcall	I2C_TX						; send byte
	movlw	0x2A						; CTRL_REG1
	rcall	I2C_TX						; send byte
	movlw	b'00000000'					; standby mode
	rcall	I2C_TX						; send byte
	bsf		SSP1CON2,PEN				; stop condition
	bra		WaitMSSP					; wait for TX to complete and return


I2C_sleep_compass1:
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP					; wait for TX to complete
	movlw	0x3C						; address
	rcall	I2C_TX						; send byte
	movlw	0x20						; CTRL_REG1
	rcall	I2C_TX						; send byte
	movlw	b'00000000'					; data for CTRL_REG1: acceleration sensor power-down mode
	rcall	I2C_TX						; send byte
	bsf		SSP1CON2,PEN				; stop condition
	rcall	WaitMSSP					; wait for TX to complete
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP					; wait for TX to complete
	movlw	0x3C						; address
	rcall	I2C_TX						; send byte
	movlw	0x26						; CTRL_REG7
	rcall	I2C_TX						; send byte
	movlw	b'00000010'					; data for CTRL_REG7: magnetic sensor power-down mode
	rcall	I2C_TX						; send byte
	bsf		SSP1CON2,PEN				; stop condition
	bra		WaitMSSP					; wait for TX to complete and return

	; accelerometer sleeps with magnetic sensor


I2C_sleep_compass2:
	; magnetic
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP					; wait for TX to complete
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
	bsf		SSP1CON2,PEN				; stop condition
	rcall	WaitMSSP					; wait for TX to complete

	; accelerometer
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP					; wait for TX to complete
	movlw	0x32						; address
	rcall	I2C_TX						; send byte
	movlw	0x9F						; 1F with auto-increment (MSB=1)
	rcall	I2C_TX						; send byte
	movlw	b'00000000'					; TEMP_CFG_REG_A  0x1F (temp sensor off)
	rcall	I2C_TX						; send byte
	movlw	b'00000000'					; CTRL_REG1_A     0x20 (all off)
	rcall	I2C_TX						; send byte
	bsf		SSP1CON2,PEN				; stop condition
	bra		WaitMSSP					; wait for TX to complete and return


I2C_sleep_compass3:
	; magnetic
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP					; wait for TX to complete
	movlw	0x3C						; address
	rcall	I2C_TX						; send byte
	movlw	0xA2						; 0x22 with auto-increment (MSB=1)
	rcall	I2C_TX						; send byte
	movlw	b'01000010'					; CTRL_REG3_M (power-down) 0x22
	rcall	I2C_TX						; send byte
	bsf		SSP1CON2,PEN				; stop condition
	rcall	WaitMSSP					; wait for TX to complete

	; accelerometer
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP					; wait for TX to complete
	movlw	0x3A						; address
	rcall	I2C_TX						; send byte
	movlw	0x20
	rcall	I2C_TX						; send byte
	movlw	b'00000000'					; CTRL_REG1_A (100Hz, x,y,z = OFF) 0x20
	rcall	I2C_TX						; send byte
	bsf		SSP1CON2,PEN				; stop condition
	bra		WaitMSSP					; wait for TX to complete and return


;-----------------------------------------------------------------------------
; Helper Function - wait for TX to complete
;
WaitMSSP:
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
	bcf		active_reset_ostc_rx		; release reset from RX circuitry
	return								; done


;-----------------------------------------------------------------------------
; Helper Function - Reset I2C Module
;
; recover in case something went wrong, i.g. slave holds SDA low
;
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
	WAITMS	d'10'						; wait 10 ms (reset-timeout for I2C devices)
	movlw	b'00000000'					; enable slew rate control
	movwf	SSP1STAT					; ...
	movlw	b'00101000'					; configure I2C module
	movwf	SSP1CON1					; ...
	movlw	b'00000000'					; ...
	movwf	SSP1CON2					; ...
	movlw	0x9C						; ...
	movwf	SSP1ADD						; ...
	return								; done


;-----------------------------------------------------------------------------
; Helper Function - Initialize Gauge IC again after an UVLO Event
;
lt2942_init_again:
	movlw	0x02									; point to accumulated charge registers
	rcall	I2C_TX_GAUGE							; send byte to the LT2942 gauge IC
	movff	battery_accumulated_charge+1,SSP1BUF	; data byte
	rcall	WaitMSSP								; wait for TX to complete
	rcall	I2C_Check_ACK							; check for acknowledge by receiver
	movff	battery_accumulated_charge+0,SSP1BUF	; data byte
	rcall	WaitMSSP								; wait for TX to complete
	rcall	I2C_Check_ACK							; check for acknowledge by receiver
	bsf		SSP1CON2,PEN							; stop condition
	rcall	WaitMSSP								; wait for TX to complete
	MOVII	battery_accumulated_charge,sub_a		; copy result to sub_a
	;bra	lt2942_init								; and initialize again...


;-----------------------------------------------------------------------------
; Initialize Gauge IC
;
	global	lt2942_init
lt2942_init:
	movlw	0x01						; point to control reg B
	rcall	I2C_TX_GAUGE				; send byte to the LT2942 gauge IC
	movlw	b'11111000'					; automatic conversion every two seconds
	movff	WREG,SSP1BUF				; data byte										TODO: movwf ??
	rcall	WaitMSSP					; wait for TX to complete
	rcall	I2C_Check_ACK				; check for acknowledge by receiver
	bsf		SSP1CON2,PEN				; stop condition
	bra		WaitMSSP					; wait for TX to complete and return


;-----------------------------------------------------------------------------
; Read Gauge IC - Status Register
;
	global	lt2942_get_status
lt2942_get_status:
	bcf		battery_gauge_available		; clear flag
	movlw	0x00						; point to status register
	rcall	I2C_TX_GAUGE				; send    byte to   the LT2942 gauge IC
	rcall	I2C_RX_GAUGE				; receive byte from the LT2942 Gauge IC
	movff	SSP1BUF,WREG				; copy received byte to WREG
	btfss	WREG,7						; 2942 found?
	bsf		battery_gauge_available		; YES - set flag
	bsf		SSP1CON2,PEN				; stop condition
	bra		WaitMSSP					; wait for TX to complete and return


;-----------------------------------------------------------------------------
; Read Gauge IC - Voltage
;
	global	lt2942_get_voltage
lt2942_get_voltage:
	movlw	0x08						; point to voltage registers
	rcall	I2C_TX_GAUGE				; send    byte to   the LT2942 gauge IC
	rcall	I2C_RX_GAUGE				; receive byte from the LT2942 Gauge IC
	bsf		SSP1CON2,ACKEN				; master acknowledge
	rcall	WaitMSSP					; wait for TX to complete
	movff	SSP1BUF,xA+1				; copy received byte to xA+1
	bsf		SSP1CON2,RCEN				; enable receive mode
	rcall	WaitMSSP					; wait for TX to complete
	movff	SSP1BUF,xA+0				; copy received byte to xA+0
	bsf		SSP1CON2,PEN				; stop condition
	rcall	WaitMSSP					; wait for TX to complete

	; convert voltage from raw value to Volt
	MOVLI	.6000,xB					; load conversion multiplicand into xB
	call	mult16x16					; xC = xA * xB -> multiply raw value in xA with conversion multiplicand
										; divide by 65536 instead of 65535, introducing an error of 65536/65535 = 0.002 %
	movff	xC+2,batt_voltage+0			; divide by 65536 can easily be done by just taking the 3rd and 4th byte of the multiplication result
	movff	xC+3,batt_voltage+1			; ...

	tstfsz	batt_voltage+1				; < 256 mV ?
	return								; NO  - done
	bra		lt2942_init					; YES - initialize gauge and return


;-----------------------------------------------------------------------------
; Read Gauge IC - Temperature
;
	global	lt2942_get_temperature
lt2942_get_temperature:					; read battery temperature
	movlw	0x0C						; point to temperature register
	call	I2C_TX_GAUGE				; send    byte to   the LT2942 gauge IC
	call	I2C_RX_GAUGE				; receive byte from the LT2942 Gauge IC
	bsf		SSP1CON2,ACKEN				; master acknowledge
	rcall	WaitMSSP					; wait for TX to complete
	movff	SSP1BUF,xA+1				; store raw temperature, high byte
	bsf		SSP1CON2,RCEN				; enable receive mode
	rcall	WaitMSSP					; wait for TX to complete
	movff	SSP1BUF,xA+0				; store raw temperature, low byte
	bsf		SSP1CON2,PEN				; stop condition
	rcall	WaitMSSP					; wait for TX to complete

	; convert temperature from raw value to Kelvin
	MOVLI	.6000,xB					; load conversion multiplicand into xB
	call	mult16x16					; xC = xA * xB -> multiply raw value in xA with conversion multiplicand
										; divide by 65536 instead of 65535, introducing an error of 65536/65535 = 0.002 %
	movff	xC+2,battery_temperature+0	; divide by 65536 can easily be done by just taking the 3rd and 4th byte of the multiplication result
	movff	xC+3,battery_temperature+1	; ...

	; check if battery is being charged right now
	btfss	cc_active					; in CC charging mode?
	return								; NO  - not charging, done

	; check for over-temperature while charging
	MOVLI	max_battery_charge_temp,sub_a
	MOVII	battery_temperature,    sub_b
	call	cmpU16						; sub_a - sub_b (with UNSIGNED values)
	btfss	neg_flag					; result negative?
	return								; NO  - temperature <= threshold, ok, done
										; YES - too hot, disable charging circuitry
	bsf		charge_disable				;     - set      charging-inhibit signal
	bcf		charge_enable				;     - activate charging-inhibit signal
	bsf		battery_overtemp			;     - flag that the battery charging over-temperature protection has tripped
	return								;     - done


;-----------------------------------------------------------------------------
; Read Gauge IC - Read State of Charge
;
	global	lt2942_get_accumulated_charge
lt2942_get_accumulated_charge:			; read accumulated charge and compute percent
	movlw	0x00						; point to status register
	rcall	I2C_TX_GAUGE				; send    byte to   the LT2942 gauge IC
	rcall	I2C_RX_GAUGE				; receive byte from the LT2942 Gauge IC
	bsf		SSP1CON2,ACKEN				; master acknowledge
	rcall	WaitMSSP					; wait for TX to complete
	movff	SSP1BUF,gauge_status_byte	; copy received byte to gauge_status_byte

	bsf		SSP1CON2,RCEN				; enable receive mode
	rcall	WaitMSSP					; wait for TX to complete					; dummy read (control byte)
	movf	SSP1BUF,W					; dump to WREG
	bsf		SSP1CON2,ACKEN				; master acknowledge
	rcall	WaitMSSP					; wait for TX to complete

	bsf		SSP1CON2,RCEN				; enable receive mode
	rcall	WaitMSSP					; wait for TX to complete
	movff	SSP1BUF,sub_a+1				; copy received byte to sub_a+1
	bsf		SSP1CON2,ACKEN				; master acknowledge
	rcall	WaitMSSP					; wait for TX to complete

	bsf		SSP1CON2,RCEN				; enable receive mode
	rcall	WaitMSSP					; wait for TX to complete
	movff	SSP1BUF,sub_a+0				; copy received byte to sub_a+0
	bsf		SSP1CON2,PEN				; stop condition
	rcall	WaitMSSP					; wait for TX to complete

	btfsc	gauge_status_byte,0			; UVLO event ?
	rcall	lt2942_init_again			; YES - do an re-initialization

	MOVII	sub_a,battery_accumulated_charge	; save raw value

	; Compute batt_percent = (charge - battery_offset) / 365
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
	return								; done

lt2942_set_to_zero_percent:
	movlw	0x02						; point to accumulated charge registers
	rcall	I2C_TX_GAUGE				; send byte to the LT2942 gauge IC
	movff	battery_offset+1,SSP1BUF	; send battery offset, high byte
	rcall	WaitMSSP					; wait for TX to complete
	rcall	I2C_Check_ACK				; check for acknowledge by receiver
	movff	battery_offset+0,SSP1BUF	; send battery offset, low  byte
	rcall	WaitMSSP					; wait for TX to complete
	rcall	I2C_Check_ACK				; check for acknowledge by receiver
	bsf		SSP1CON2,PEN				; stop condition
	bra		WaitMSSP					; wait for TX to complete and return


;-----------------------------------------------------------------------------
; Read Gauge IC - Reset Accumulating Register to 0xFFFF
;
	global	lt2942_charge_done
lt2942_charge_done:
	movlw	0x02						; point to accumulated charge registers
	rcall	I2C_TX_GAUGE				; send byte to the LT2942 gauge IC
	setf	SSP1BUF						; data byte
	rcall	WaitMSSP					; wait for TX to complete
	rcall	I2C_Check_ACK				; check for acknowledge by receiver
	setf	SSP1BUF						; data byte
	rcall	WaitMSSP					; wait for TX to complete
	rcall	I2C_Check_ACK				; check for acknowledge by receiver
	bsf		SSP1CON2,PEN				; stop condition
	bra		WaitMSSP					; wait for TX to complete and return


;-----------------------------------------------------------------------------
; Helper Function - send 1 Byte to the LT2942 Gauge IC
;
I2C_TX_GAUGE:
	movwf	i2c_temp2					; save data byte to be sent
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP					; wait for TX to complete
	movlw	b'11001000'					; address byte + Write bit
	movwf	SSP1BUF						; control byte
	rcall	WaitMSSP					; wait for TX to complete
	rcall	I2C_Check_ACK				; check for acknowledge by receiver
	movf	i2c_temp2,W					; restore data byte to be sent
	bra		I2C_TX						; send byte and return


;-----------------------------------------------------------------------------
; Helper Function - receive 1 Byte from the LT2942 Gauge IC
;
I2C_RX_GAUGE:
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP					; wait for TX to complete
	movlw	b'11001001'					; address byte + Read bit
	movwf	SSP1BUF						; control byte
	rcall	WaitMSSP					; wait for TX to complete
	rcall	I2C_Check_ACK				; check for acknowledge by receiver
	bsf		SSP1CON2,RCEN				; enable receive mode
	bra		WaitMSSP					; wait for reception and return


;-----------------------------------------------------------------------------
; Reset Hardware and Software Battery Gauge
;
; called from comm.asm and menu_tree.asm
;
	global	reset_battery_gauge_and_lt2942
reset_battery_gauge_and_lt2942:
	btfsc	battery_gauge_available		; battery gauge chip available?
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
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP					; wait for TX to complete
	movlw	0x50						; address byte + write bit
	movwf	SSP1BUF						; control byte
	rcall	WaitMSSP					; wait for TX to complete
	btfss	SSP1CON2,ACKSTAT			; ACK received?
	bsf		ostc_rx_present				; YES - TR module detected
	bsf		SSP1CON2,PEN				; stop condition
	rcall	WaitMSSP					; wait for TX to complete
	btfss	ostc_rx_present				; was a TR module detected?
	return								; NO  - done

	WAITMS	.1							; wait 1 ms

	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP					; wait for TX to complete
	movlw	0x50						; address byte + write bit
	movwf	SSP1BUF						; control byte
	rcall	WaitMSSP					; wait for TX to complete
	rcall	I2C_Check_ACK				; check for acknowledge by receiver
	movlw	0x1B						; command: get firmware
	movwf	SSP1BUF						; send command
	rcall	WaitMSSP					; wait for TX to complete
	rcall	I2C_Check_ACK				; check for acknowledge by receiver
	bsf		SSP1CON2,PEN				; stop condition
	rcall	WaitMSSP					; wait for TX to complete

	WAITMS	.1							; wait 1 ms

	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP					; wait for TX to complete
	movlw	0x51						; address byte + Read bit
	movwf	SSP1BUF						; control byte
	rcall	WaitMSSP					; wait for TX to complete
	bsf		SSP1CON2,RCEN				; enable receive mode
	rcall	WaitMSSP					; wait for TX to complete
	movff	SSP1BUF,rx_firmware_cur_major ; store as firmware version, major
	bsf		SSP1CON2,ACKEN				  ; master acknowledge
	rcall	WaitMSSP					; wait for TX to complete

	; last byte in read from RX circuity always with a NACK!
	bsf		SSP1CON2,RCEN				; enable receive mode
	rcall	WaitMSSP					; wait for TX to complete
	movff	SSP1BUF,rx_firmware_cur_minor ; store as firmware version, minor
	bsf		SSP1CON2,ACKDT				; set ACKDT flag
	bsf		SSP1CON2,ACKEN				; master NOT acknowledge
	rcall	WaitMSSP					; wait for TX to complete
	bcf		SSP1CON2,ACKDT				; reset ACKDT flag
	bsf		SSP1CON2,PEN				; stop condition
	rcall	WaitMSSP					; wait for TX to complete

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
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP					; wait for TX to complete
	movlw	0x50						; address byte + write bit
	movwf	SSP1BUF						; control byte
	rcall	WaitMSSP					; wait for TX to complete
	rcall	I2C_Check_ACK				; check for acknowledge by receiver
	movlw	0x1E						; read buffer2 (48 bytes)
	movwf	SSP1BUF						; data byte
	rcall	WaitMSSP					; wait for TX to complete
	rcall	I2C_Check_ACK				; check for acknowledge by receiver
	bsf		SSP1CON2,PEN				; stop condition
	rcall	WaitMSSP					; wait for TX to complete

	WAITMS	.1							; wait 1 ms

	; read 48 bytes
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP					; wait for TX to complete
	movlw	0x51						; address byte + read bit
	movwf	SSP1BUF						; control byte
	rcall	WaitMSSP					; wait for TX to complete
	rcall	I2C_Check_ACK				; check for acknowledge by receiver
	movlw	.47							; 47 with ACK + 1 w/o ACK
	movwf	i2c_temp2					; initialize loop counter
	lfsr	FSR2,rx_buffer				; point to start of rx data buffer 
I2C_get_tankdata_loop_read:
	bsf		SSP1CON2,RCEN				; enable receive mode
	rcall	WaitMSSP					; wait for TX to complete
	movff	SSP1BUF,POSTINC2			; copy received byte to the rx buffer
	bcf		SSP1CON2,ACKDT				; reset ACKDT flag
	bsf		SSP1CON2,ACKEN				; master acknowledge
	rcall	WaitMSSP					; wait for TX to complete
	decfsz	i2c_temp2,F					; decrement loop counter, done?
	bra		I2C_get_tankdata_loop_read	; NO  - loop
	; read last byte without ACK
	bsf		SSP1CON2,RCEN				; enable receive mode
	rcall	WaitMSSP					; wait for TX to complete
	movff	SSP1BUF,POSTINC2			; copy received byte to the rx buffer
	bsf		SSP1CON2,ACKDT				; set ACKDT flag
	bsf		SSP1CON2,ACKEN				; master NOT acknowledge
	rcall	WaitMSSP					; wait for TX to complete
	bcf		SSP1CON2,ACKDT				; reset ACKDT flag
	bsf		SSP1CON2,PEN				; stop condition
	bra		WaitMSSP					; wait for TX to complete and return


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
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP					; wait for TX to complete
	movlw	0x50						; address byte + write bit
	movwf	SSP1BUF						; control byte
	rcall	WaitMSSP					; wait for TX to complete
	rcall	I2C_Check_ACK				; check for acknowledge by receiver
	; write 64 bytes
I2C_update_OSTC_loop:
	TBLRD*+								; read a byte from program memory
	movff	TABLAT,POSTINC2				; copy to send buffer
	movff	TABLAT,SSP1BUF				; copy to I2C data buffer
	rcall	WaitMSSP					; wait for TX to complete
	rcall	I2C_Check_ACK				; check for acknowledge by receiver
	decfsz	i2c_temp2,F					;decrement loop counter, became zero?
	bra		I2C_update_OSTC_loop		; NO  - loop
	bsf		SSP1CON2,PEN				; YES - stop condition
	rcall	WaitMSSP					;     - wait for TX to complete
	WAITMS	.1							;     - wait another 1 ms
	; setup for read-back
	lfsr	FSR2,buffer					; reset pointer to begin of send buffer
	movlw	.63							; initialize loop counter: 63 byte with ACK + 1 w/o ACK
	movwf	i2c_temp2					; ...
	; address read-back
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP					; wait for TX to complete
	movlw	0x51						; address byte + read bit
	movwf	SSP1BUF						; control byte
	rcall	WaitMSSP					; wait for TX to complete
	rcall	I2C_Check_ACK				; check for acknowledge by receiver
	; read-back 64 bytes
I2C_update_OSTC_loop_read:
	bsf		SSP1CON2,RCEN				; enable receive mode
	rcall	WaitMSSP					; wait for TX to complete
	movf	SSP1BUF,W					; copy received byte to WREG
	cpfseq	POSTINC2					; compare read-back byte with sent byte, equal?
	bsf		i2c_error_flag				; NO  - not equal, set error flag
	bcf		SSP1CON2,ACKDT				; reset ACKDT flag
	bsf		SSP1CON2,ACKEN				; master acknowledge
	rcall	WaitMSSP					; wait for TX to complete
	decfsz	i2c_temp2,F					; decrement loop counter, became zero?
	bra		I2C_update_OSTC_loop_read	; NO  - loop
	; 1 w/o ACK
	bsf		SSP1CON2, RCEN				; YES - enable receive mode
	rcall	WaitMSSP					;     - wait for TX to complete
	movf	SSP1BUF,W					;     - get 64th byte
	cpfseq	POSTINC2					;     - compare read-back byte with sent byte, equal?
	bsf		i2c_error_flag				;       NO  - not equal, set error flag
	bsf		SSP1CON2,ACKDT				;     - set ACKDT flag
	bsf		SSP1CON2,ACKEN				;     - master NOT acknowledge
	rcall	WaitMSSP					;     - wait for TX to complete
	bcf		SSP1CON2,ACKDT				;     - reset ACKDT flag
	; stop
	bsf		SSP1CON2,PEN				; stop condition
	rcall	WaitMSSP					; wait for TX to complete
	WAITMS	.1
	; address commit
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP					; wait for TX to complete
	movlw	0x50						; address byte + write bit
	movwf	SSP1BUF						; control byte
	rcall	WaitMSSP					; wait for TX to complete
	rcall	I2C_Check_ACK				; check for acknowledge by receiver
	movlw	0x1F						; write command
	movwf	SSP1BUF						; data byte
	rcall	WaitMSSP					; wait for TX to complete
	rcall	I2C_Check_ACK				; check for acknowledge by receiver
	bsf		SSP1CON2,PEN				; stop condition
	rcall	WaitMSSP					; wait for TX to complete
	WAITMS	.5							; required waiting time
	; error check
	btfss	i2c_error_flag				; did an error occur?
	retlw	.0							; NO  - data transfered successfully
	retlw	.255						; YES - error in data transfer occurred

 ENDIF	; _rx_update

 ENDIF	; _rx_functions

;-----------------------------------------------------------------------------

	END
