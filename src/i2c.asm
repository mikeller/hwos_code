;=============================================================================
;
;   File i2c.asm                              combined next generation V3.03.2
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
;   LSM303C's Compass read address	    (8-Bit): 0x3D
;   LSM303C's Compass write address	    (8-Bit): 0x3C
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
#include "external_flash.inc"


i2c	CODE

;=============================================================================

I2C_TX:
	movwf	SSP1BUF
	rcall	WaitMSSP
	bra		I2C_WaitforACK				; returns...

I2C_TwoBytesRX_div16:					; get two bytes and divide lo:hi/16 (signed)
	rcall	I2C_OneByteRX				; get one byte
	movff	SSP1BUF,hi					; data byte
	rcall	I2C_OneByteRX				; get one byte
	movff	SSP1BUF,lo					; data byte
I2C_TwoBytesRX_div16_2:					; divide lo:hi/16 (signed) only
	bcf		STATUS,C
	btfsc	hi,7						; copy sign bit to carry
	bsf		STATUS,C
	rrcf	hi							; /2
	rrcf	lo
I2C_TwoBytesRX_div8_2:					; divide lo:hi/8 (signed) only
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
	return

	global	I2C_RX_accelerometer
I2C_RX_accelerometer:
        btfsc   compass_type3	    ; compass3
	bra	    I2C_RX_accelerometer_compass3    ; yes
	btfsc	compass_type2					; compass2 ?
	bra		I2C_RX_accelerometer_compass2	; YES
	btfsc	compass_type					; compass1 ?
	bra		I2C_RX_accelerometer_compass1	; YES
I2C_RX_accelerometer_compass0:
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP
	movlw	0x38						; address
	rcall	I2C_TX
	movlw	0x00
	rcall	I2C_TX
	bsf		SSP1CON2,RSEN				; repeated start condition
	rcall	WaitMSSP
	movlw	0x39						; address
	rcall	I2C_TX

	rcall	I2C_OneByteRX				; get status byte
	movf	SSP1BUF,W

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
	comf	hi							; 16 bit sign change
	negf	lo
	btfsc	STATUS,C					; carry to propagate?
	incf	hi,F						; YES - do it
I2C_RX_accelerometer2:
	MOVII	mpr,accel_DX				; copy result
	rcall	I2C_TwoBytesRX_div16		; get two bytes and divide /16 (signed)
	btfsc	flip_screen					; 180° rotation?
	bra		I2C_RX_accelerometer3		; YES
	comf	hi							; 16 bit sign change
	negf	lo
	btfsc	STATUS,C					; carry to propagate?
	incf	hi,F						; YES - do it
I2C_RX_accelerometer3:
	MOVII	mpr,accel_DY				; copy result
	rcall	I2C_OneByteRX				; get one byte
	movff	SSP1BUF,hi					; data byte
	bsf		SSP1CON2, RCEN				; Enable receive mode
	rcall	WaitMSSP
; According to data sheet there should be no master Acknowledge for the last byte (accel_DZ+0)...
	movff	SSP1BUF,lo					; data byte

	rcall	I2C_TwoBytesRX_div16_2		; divide lo:hi/16 (signed) only
	comf	hi							; 16 bit sign change
	negf	lo
	btfsc	STATUS,C					; carry to propagate?
	incf	hi,F						; YES - do it
	MOVII	mpr,accel_DZ				; copy result
	bsf		SSP1CON2,PEN				; stop condition
	bra		WaitMSSP					; ... and return

I2C_RX_accelerometer_compass1:
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP
	movlw	0x3C						; address
	rcall	I2C_TX
	movlw	b'10101000'					; 0x28 with auto-increment (MSB=1)
	rcall	I2C_TX
	bsf		SSP1CON2,RSEN				; repeated start condition (!)
	rcall	WaitMSSP
	movlw	0x3D						; address
I2C_RX_accelerometer_compass1_xx:		;  compass2 and 3 continue here... 
	rcall	I2C_TX

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
	rcall	I2C_OneByteRX
	movff	SSP1BUF,lo					; accel_DX+0
	rcall	I2C_OneByteRX
	movff	SSP1BUF,hi					; accel_DX+1
	rcall	I2C_TwoBytesRX_div16_2		; divide lo:hi/16 (signed) only
	btfss	compass_type2				; compass 2?
	bra		I2C_RX_accelerometer1_c1	; NO  - compass 1
	; compass 2
	btfss	flip_screen					; 180° rotation?
	bra		I2C_RX_accelerometer2_c1	; NO  - continue with normal compass1 routines for Y and Z
	; flipped compass 2, negate x
	comf	hi							; 16 bit sign change
	negf	lo
	btfsc	STATUS,C					; carry to propagate?
	incf	hi,F						; YES - do it
	bra		I2C_RX_accelerometer2_c1	; continue with normal compass1 routines for Y and Z

I2C_RX_accelerometer1_c1:
	btfsc	flip_screen					; 180° rotation?
	bra		I2C_RX_accelerometer2_c1	; YES
	; non-flipped compass 1, negate x
	comf	hi							; 16 bit sign change
	negf	lo
	btfsc	STATUS,C					; carry to propagate?
	incf	hi,F						; YES - do it
I2C_RX_accelerometer2_c1:
	; flipped compass 1, non-flipped compass 2
	MOVII	mpr,accel_DX				; copy result
	rcall	I2C_OneByteRX
	movff	SSP1BUF,lo					; accel_DY+0
	rcall	I2C_OneByteRX
	movff	SSP1BUF,hi					; accel_DY+1

	rcall	I2C_TwoBytesRX_div16_2		; divide lo:hi/16 (signed) only
	btfsc	flip_screen					; 180° rotation?
	bra		I2C_RX_accelerometer3_c1	; YES
	comf	hi							; 16 bit sign change
	negf	lo
	btfsc	STATUS,C					; carry to propagate?
	incf	hi,F						; YES - do it
I2C_RX_accelerometer3_c1:
	MOVII	mpr,accel_DY				; copy result
	rcall	I2C_OneByteRX
	movff	SSP1BUF,lo					; accel_DZ+0
	bsf		SSP1CON2, RCEN				; Enable receive mode
	rcall	WaitMSSP
; According to data sheet there should be no master Acknowledge for the last byte (accel_DZ+1)...
	movff	SSP1BUF,hi					; accel_DZ+1
	bsf		SSP1CON2,PEN				; stop condition
	rcall	WaitMSSP
	rcall	I2C_TwoBytesRX_div16_2		; divide lo:hi/16 (signed) only
	comf	hi							; 16 bit sign change for Z
	negf	lo
	btfsc	STATUS,C					; carry to propagate?
	incf	hi,F						; YES - do it
	MOVII	mpr,accel_DZ				; copy result
	return

I2C_RX_accelerometer_compass2:
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP
	movlw	0x32						; address
	rcall	I2C_TX
	movlw	b'10101000'					; 0x28 with auto-increment (MSB=1)
	rcall	I2C_TX
	bsf		SSP1CON2,RSEN				; repeated start condition (!)
	rcall	WaitMSSP
	movlw	0x33						; address
	bra	I2C_RX_accelerometer_compass1_xx

I2C_RX_accelerometer_compass3:
	bsf	SSP1CON2,SEN	    ; Start condition
	rcall	WaitMSSP
	movlw	0x3A                ; address
	rcall   I2C_TX
	movlw	0x28		    ; 0x28 (OUT_X_L_A)
	rcall   I2C_TX
	bsf	SSP1CON2,RSEN	    ; Repeated start condition (!)
	rcall	WaitMSSP
	movlw	0x3B                ; address
	bra	I2C_RX_accelerometer_compass1_xx

I2C_OneByteRX:
	bsf		SSP1CON2,RCEN				; enable receive mode
	rcall	WaitMSSP
	bsf		SSP1CON2,ACKEN				; master acknowledge
	bra		WaitMSSP					; ... and return


;-----------------------------------------------------------------------------
 IFDEF _compass

	global	I2C_RX_compass
I2C_RX_compass:
        btfsc   compass_type3				; compass3
        bra	    I2C_RX_compass3				; YES
	btfsc	compass_type2				; compass2 ?
	bra		I2C_RX_compass2				; YES
	btfsc	compass_type				; compass1 ?
	bra		I2C_RX_compass1				; YES
I2C_RX_compass0:
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP
	movlw	0x3C						; address
	rcall	I2C_TX
	movlw	0x03
	rcall	I2C_TX
	bsf		SSP1CON2,PEN				; stop condition
	rcall	WaitMSSP

	bcf		PIR1,SSP1IF
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP
	movlw	0x3D						; address
	rcall	I2C_TX

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

	rcall	I2C_OneByteRX				; get one byte
	movff	SSP1BUF,compass_DY+1		; data byte
	rcall	I2C_OneByteRX				; get one byte
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
	rcall	I2C_OneByteRX				; get one byte
	movff	SSP1BUF,compass_DZ+1		; data byte
	rcall	I2C_OneByteRX				; get one byte
	movff	SSP1BUF,compass_DZ+0		; data byte
	rcall	I2C_OneByteRX				; get one byte
	movff	SSP1BUF,compass_DX+1		; data byte
	bsf		SSP1CON2, RCEN				; Enable receive mode
	rcall	WaitMSSP
	movff	SSP1BUF,compass_DX+0		; data byte
	bsf		SSP1CON2,PEN				; stop condition
	rcall	WaitMSSP
	btfss	flip_screen					; 180° rotation?
	return								; NO  - done
	banksel	compass_DX					; YES - flip X
	comf	compass_DX+1				;     - 16 bit sign change
	negf	compass_DX+0
	btfsc	STATUS,C					;     - carry to propagate?
	incf	compass_DX+1,F				;       YES - do it
	banksel	common
	return

I2C_RX_compass1:						; new compass
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP
	movlw	0x3C						; address
	rcall	I2C_TX
	movlw	b'10001000'					; 0x08 with auto-increment (MSB=1)
	rcall	I2C_TX
	bsf		SSP1CON2,RSEN				; repeated start condition (!)
	rcall	WaitMSSP
	movlw	0x3D						; address
	rcall	I2C_TX
	;rcall	WaitMSSP					; TODO needed? (mH)
	rcall	I2C_OneByteRX				; get one byte
	movff	SSP1BUF,lo					; data byte
	rcall	I2C_OneByteRX				; get one byte
	movff	SSP1BUF,hi					; data byte
	rcall	I2C_TwoBytesRX_div8_2
	MOVII	mpr,compass_DX
	btfss	flip_screen					; 180° rotation?
	bra		I2C_RX_compass1_1			; NO
	banksel	compass_DX					; YES - flip X
	comf	compass_DX+1				;     - 16 bit sign change
	negf	compass_DX+0
	btfsc	STATUS,C					;     - carry to propagate?
	incf	compass_DX+1,F				;       YES - do it
	banksel	common
I2C_RX_compass1_1:
	rcall	I2C_OneByteRX				; get one byte
	movff	SSP1BUF,lo					; data byte
	rcall	I2C_OneByteRX				; get one byte
	movff	SSP1BUF,hi					; data byte
	rcall	I2C_TwoBytesRX_div8_2
	MOVII	mpr,compass_DY
	btfss	flip_screen					; 180° rotation?
	bra		I2C_RX_compass1_2			; NO
	banksel	compass_DY					; YES - flip Y
	comf	compass_DY+1				;     - 16 bit sign change
	negf	compass_DY+0
	btfsc	STATUS,C					;     - carry to propagate?
	incf	compass_DY+1,F				;       YES - do it
	banksel	common
I2C_RX_compass1_2:
	rcall	I2C_OneByteRX				; get one byte
	movff	SSP1BUF,lo					; data byte
	bsf		SSP1CON2, RCEN				; Enable receive mode
	rcall	WaitMSSP
	movff	SSP1BUF,hi					; data byte
	rcall	I2C_TwoBytesRX_div8_2
	MOVII	mpr,compass_DZ
	bsf		SSP1CON2,PEN				; stop condition
	bra		WaitMSSP					; ... and return

I2C_RX_compass2:						; newest compass
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP
	movlw	0x3C						; address
	rcall	I2C_TX
	movlw	0xE8						; 0x68 with auto-increment (MSB=1)
	rcall	I2C_TX
	bsf		SSP1CON2,RSEN				; repeated start condition (!)
	rcall	WaitMSSP
	movlw	0x3D						; address
	rcall	I2C_TX
I2C_RX_compass2_xx:    ; compass 3 enters here	
;	rcall	WaitMSSP
	rcall	I2C_OneByteRX				; get one byte
	movff	SSP1BUF,lo					; data byte
	rcall	I2C_OneByteRX				; get one byte
	movff	SSP1BUF,hi					; data byte
;	rcall	I2C_TwoBytesRX_div8_2
	btfsc	flip_screen					; 180° rotation?
	bra		I2C_RX_compass2_1			; YES - do nothing with X
										; NO  - flip X
	comf	hi							;     - 16 bit sign change
	negf	lo
	btfsc	STATUS,C					;     - carry to propagate?
	incf	hi,F						;       YES - do it
I2C_RX_compass2_1:
	MOVII	mpr,compass_DX
	rcall	I2C_OneByteRX				; get one byte
	movff	SSP1BUF,lo					; data byte
	rcall	I2C_OneByteRX				; get one byte
	movff	SSP1BUF,hi					; data byte
;	rcall	I2C_TwoBytesRX_div8_2
	btfss	flip_screen					; 180° rotation?
	bra		I2C_RX_compass2_2			; NO  - do nothing with Y
										; YES - flip Y
	comf	hi							;     - 16 bit sign change
	negf	lo
	btfsc	STATUS,C					;     - carry to propagate?
	incf	hi,F						;       YES - do it
I2C_RX_compass2_2:
	MOVII	mpr,compass_DY
	rcall	I2C_OneByteRX				; get one byte
	movff	SSP1BUF,lo					; data byte
	rcall	I2C_OneByteRX				; get one byte
	movff	SSP1BUF,hi					; data byte
;	rcall	I2C_TwoBytesRX_div8_2
	MOVII	mpr,compass_DZ
	bsf		SSP1CON2,PEN				; stop condition
	bra		WaitMSSP ;(And return)

I2C_RX_compass3:
	bsf		SSP1CON2,SEN	    ; Start condition
	rcall	WaitMSSP
	movlw	0x3C                ; address
	rcall   I2C_TX
	movlw	0xA8		    ; 0x28 with auto-increment (MSB=1)
	rcall   I2C_TX
	bsf	SSP1CON2,RSEN	    ; Repeated start condition (!)
	rcall	WaitMSSP
	movlw	0x3D                ; address
	rcall   I2C_TX
	bra	I2C_RX_compass2_xx

 ENDIF	; _compass

;-----------------------------------------------------------------------------

	global	I2C_init_compass
I2C_init_compass:
	bsf		compass_enabled
	bcf		compass_type2
        bcf		compass_type3
    
    ; probe compass 3
        bsf	SSP1CON2,SEN		; Start condition
        rcall	WaitMSSP
        movlw	0x3A			; Address byte + Write bit
        movwf	SSP1BUF			; control byte
        rcall	WaitMSSP
        btfss	SSP1CON2,ACKSTAT	; ACK?
        bsf	compass_type3		; ACK send. compass2 present
        bsf	SSP1CON2,PEN		; Stop condition
        rcall	WaitMSSP
    
	btfsc   compass_type3
        bra	I2C_init_compass3		; Compass3

	; check for compass2
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP
	movlw	0x32						; address byte + Write bit
	movwf	SSP1BUF						; control byte
	rcall	WaitMSSP
	btfss	SSP1CON2,ACKSTAT			; ACK?
	bsf		compass_type2				; YES - ACK send, compass2 present
	bsf		SSP1CON2,PEN				; NO  - stop condition
	rcall	WaitMSSP
	btfsc	compass_type2
	bra		I2C_init_compass2			; compass2

	; check for compass0 or compass1...
	bsf		compass_type				; set flag
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP
	movlw	0x3C						; address
	rcall	I2C_TX
	movlw	0x0F
	rcall	I2C_TX
	bsf		SSP1CON2,PEN				; stop condition
	rcall	WaitMSSP
	bcf		PIR1,SSP1IF
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP
	movlw	0x3D						; address
	rcall	I2C_TX
	rcall	I2C_OneByteRX				; get one byte
	movlw	0x49						; 0x49 = Compass1
	cpfseq	SSP1BUF
	bcf		compass_type				; clear flag
	bsf		SSP1CON2,PEN				; stop condition
	rcall	WaitMSSP
	btfsc	compass_type				; compass1 ?
	bra		I2C_init_compass1			; YES

	; init compass0
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP
	movlw	0x3C						; address
	rcall	I2C_TX
	movlw	0x00
	rcall	I2C_TX
;	movlw	b'01101001'					; ConfigA: 3 Hz, 8 samples averaged, test mode (positive bias)
	movlw	b'01101000'					; ConfigA: 3 Hz, 8 samples averaged
	rcall	I2C_TX
I2C_init_compass_common:
	movff	opt_compass_gain,i2c_temp1	; 0-7 (230 LSB/Gauss to 1370 LSB/Gauss)
	swapf	i2c_temp1,F
	comf	i2c_temp1,F
	bcf		STATUS,C
	rlcf	i2c_temp1
	movf	i2c_temp1,W
	clrf	i2c_temp1
	rcall	I2C_TX
	movlw	b'00000000'					; continuous mode
	rcall	I2C_TX
	bsf		SSP1CON2,PEN				; stop condition
	bra		WaitMSSP					; ... and return

I2C_init_compass1:
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP
	movlw	0x3C						; address
	rcall	I2C_TX
	movlw	0x9F						; 1F with auto-increment (MSB=1)
	rcall	I2C_TX
	movlw	b'00000000'					; CTRL0
	rcall	I2C_TX
	movlw	b'00101111'					; CTRL1 (6.25 Hz, BDU=0, x,y,z = ON)
	rcall	I2C_TX
	movlw	b'11000000'					; CTRL2 (50 Hz, +/- 2g)
	rcall	I2C_TX
	movlw	b'00000000'					; CTRL3
	rcall	I2C_TX
	movlw	b'00000000'					; CTRL4
	rcall	I2C_TX
	movlw	b'01100100'					; CTRL5 HIGH res, 6.25 Hz
	rcall	I2C_TX
init_compass1_common:
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
	rcall	I2C_TX
	movlw	b'00000000'					; CTRL7 Continuous Mode
	rcall	I2C_TX
	bsf		SSP1CON2,PEN				; stop condition
	bra		WaitMSSP					; ... and return

I2C_init_compass2:
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP
	movlw	0x3C						; address
	rcall	I2C_TX
	movlw	0xE0						; 0x60 with auto-increment (MSB=1)
	rcall	I2C_TX
	movlw	b'00000000'					; CFG_REG_A_M        0x60 (10 Hz, continuous)
	rcall	I2C_TX
	movlw	b'00000000'					; CFG_REG_B_M        0x61 (low-pass filter off, set pulse is released every 63 ODR)
	rcall	I2C_TX
	movlw	b'00000000'					; CFG_REG_C_M BDU=0  0x62
	rcall	I2C_TX
	bsf		SSP1CON2,PEN				; stop condition
	bra		WaitMSSP					; ... and return

I2C_init_compass3:
	bsf	SSP1CON2,SEN	; Start condition
	rcall	WaitMSSP
	movlw	0x3C            ; address
	rcall   I2C_TX
	movlw	0xA0		; 0x20 with auto-increment (MSB=1)
	rcall   I2C_TX
	movlw	b'00010000'	; CTRL_REG1_M (10Hz) 0x20
	rcall   I2C_TX
	movlw	b'01100000'	; CTRL_REG2_M (Full-scale: +/- 16gauss) 0x21
	rcall   I2C_TX
	movlw	b'01000000'	; CTRL_REG3_M (Continuous) 0x22
	rcall   I2C_TX
	movlw	b'00000000'	; CTRL_REG4_M (Z in Low-power mode) 0x23
	rcall   I2C_TX
	movlw	b'00000000'	; CTRL_REG5_M 0x24
	rcall   I2C_TX
	movlw	b'00000000'	; CTRL_REG5_M 0x24
	rcall   I2C_TX
	bsf	SSP1CON2,PEN	; Stop condition
	bra	WaitMSSP	;(And return)
	

	global	I2C_sleep_compass
I2C_sleep_compass:
	bcf		compass_enabled
        btfsc	compass_type3				; compass3?
	bra		I2C_sleep_compass3			; YES
	btfsc	compass_type2				; compass2 ?
	bra		I2C_sleep_compass2			; YES
	btfsc	compass_type				; compass1 ?
	bra		I2C_sleep_compass1			; YES
I2C_sleep_compass0:
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP
	movlw	0x3C						; address
	rcall	I2C_TX
	movlw	0x00
	rcall	I2C_TX
	movlw	b'01101000'					; ConfigA
	rcall	I2C_TX
	movlw	b'00100000'					; ConfigB
	rcall	I2C_TX
	movlw	b'00000010'					; idle mode
	rcall	I2C_TX
	bsf		SSP1CON2,PEN				; stop condition
	bra		WaitMSSP					; ... and return

I2C_sleep_compass1:
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP
	movlw	0x3C						; address
	rcall	I2C_TX
	movlw	0x20						; CTRL_REG1
	rcall	I2C_TX
	movlw	b'00000000'					; data for CTRL_REG1: acceleration sensor power-down mode
	rcall	I2C_TX
	bsf		SSP1CON2,PEN				; stop condition
	rcall	WaitMSSP
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP
	movlw	0x3C						; address
	rcall	I2C_TX
	movlw	0x26						; CTRL_REG7
	rcall	I2C_TX
	movlw	b'00000010'					; data for CTRL_REG7: magnetic sensor power-down mode
	rcall	I2C_TX
	bsf		SSP1CON2,PEN				; stop condition
	bra		WaitMSSP					;    and return

I2C_sleep_compass2:
	; magnetic
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP
	movlw	0x3C						; address
	rcall	I2C_TX
	movlw	0xE0						; 0x60 with auto-increment (MSB=1)
	rcall	I2C_TX
	movlw	b'00000011'					; CFG_REG_A_M    0x60 (idle mode))
	rcall	I2C_TX
	movlw	b'00000100'					; CFG_REG_B_M    0x61 (set pulse is released only at power-on after PD condition)
	rcall	I2C_TX
	movlw	b'01010001'					; CFG_REG_C_M    0x62
	rcall	I2C_TX
	movlw	b'00000000'					; INT_CTRL_REG_M 0x63
	rcall	I2C_TX
	bsf		SSP1CON2,PEN				; stop condition
	bra		WaitMSSP					; ... and return

I2C_sleep_compass3:
    ; magnetic
        bsf	SSP1CON2,SEN	; Start condition
        rcall	WaitMSSP
        movlw	0x3C            ; address
        rcall   I2C_TX
	movlw	0xA2		; 0x22 with auto-increment (MSB=1)
	movlw	b'01000010'	; CTRL_REG3_M (Power-down) 0x22
	rcall   I2C_TX
	bsf	SSP1CON2,PEN	; Stop condition
	bra	WaitMSSP	;(And return)

I2C_sleep_accelerometer2:
	; accelerometer
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP
	movlw	0x32						; address
	rcall	I2C_TX
	movlw	0x9F						; 1F with auto-increment (MSB=1)
	rcall	I2C_TX
	movlw	b'00000000'					; TEMP_CFG_REG_A  0x1F (temp sensor off)
	rcall	I2C_TX
	movlw	b'00000000'					; CTRL_REG1_A     0x20 (all off)
	rcall	I2C_TX
	bsf		SSP1CON2,PEN				; stop condition
	bra		WaitMSSP					; ... and return

I2C_sleep_accelerometer3:
    ; accelerometer
	bsf	SSP1CON2,SEN		; Start condition
	rcall	WaitMSSP
	movlw	0x3A            ; address
	rcall   I2C_TX
	movlw	0x20
	rcall   I2C_TX
	movlw	b'00000000'	; CTRL_REG1_A (100Hz, x,y,z = ON) 0x20
	rcall   I2C_TX
	bsf	SSP1CON2,PEN		; Stop condition
	bra	WaitMSSP	; (And return)


WaitMSSP:
	decfsz	i2c_temp1,F					; check for timeout during I2C action
	bra		WaitMSSP2
	bra		I2CFail						; timeout occurred
WaitMSSP2:
	btfss	PIR1,SSP1IF
	bra		WaitMSSP
	clrf	i2c_temp1
	bcf		PIR1,SSP1IF
	return

I2C_WaitforACK:
	btfss	SSP1CON2,ACKSTAT			; checks for ACK bit from slave
	return
I2CFail:
	bsf		active_reset_ostc_rx		; RESET RX circuitry (Which may be the cause for the hang up)
	rcall	I2CReset					; I2C Reset
	bcf		PIR1,SSP1IF
	clrf	i2c_temp1
	bsf		i2c_error_flag				; set error flag
	bcf		active_reset_ostc_rx		; release RESET from RX circuitry
	return

I2CReset:								; something went wrong (slave holds SDA low?)
	clrf	SSP1CON1					; wake-up slave and reset entire module
	clrf	SSP1CON2
	clrf	SSP1STAT
	bcf		TRISC,3						; SCL OUTPUT
	bsf		TRISC,4						; SDA input
	bcf		PORTC,3
	movlw	d'9'
	movwf	i2c_temp1					; clock-out 9 clock cycles manually
I2CReset_1:
	bsf		PORTC,3						; SCL = 1
	nop
	nop
	nop
	nop
	btfsc	PORTC,4						; SDA = 1 ?
	bra		I2CReset_2					; YES - =1, SDA has been released from slave
	bcf		PORTC,3						; NO  - set SCL = 0
	nop
	nop
	bcf		PORTC,3
	nop
	nop
	decfsz	i2c_temp1,F
	bra		I2CReset_1					; check for nine clock cycles
I2CReset_2:
	bsf		TRISC,3						; SCL Input
	clrf	SSP1CON1					; setup I²C mode
	WAITMS	d'10'						; reset-timeout for I2C devices
	movlw	b'00000000'					; with slew rate control
	movwf	SSP1STAT
	movlw	b'00101000'
	movwf	SSP1CON1
	movlw	b'00000000'
	movwf	SSP1CON2
	movlw	0x27
	movwf	SSP1ADD
	return


	global	I2C_init_accelerometer
I2C_init_accelerometer:
        btfsc   compass_type3				; compass3?
	bra	    I2C_init_accelerometer3		; YES

	btfsc	compass_type2				; compass2 ?
	bra		I2C_init_accelerometer2		; YES

	btfsc	compass_type				; compass1 ?
	return								; YES - ignore

	rcall	I2C_sleep_accelerometer		; registers can only be changed in standby mode

	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP
	movlw	0x38						; address
	rcall	I2C_TX
	movlw	0x0E						; XYZ_DATA_CFG
	rcall	I2C_TX
	movlw	b'00000000'					; high pass filter = 0, +/- 2g range
	rcall	I2C_TX
	bsf		SSP1CON2,PEN				; stop condition
	rcall	WaitMSSP

	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP
	movlw	0x38						; address
	rcall	I2C_TX
	movlw	0x2A						; CTRL_REG1
	rcall	I2C_TX
;	movlw	b'00110000'					; CTRL_REG1: 160 ms data rate, standby mode
	movlw	b'00110100'					; CTRL_REG1: 160 ms data rate, standby mode, reduced noise mode
	rcall	I2C_TX
	movlw	b'00000010'					; CTRL_REG2: high-res in active mode
	rcall	I2C_TX
	bsf		SSP1CON2,PEN				; stop condition
	rcall	WaitMSSP

	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP
	movlw	0x38						; address
	rcall	I2C_TX
	movlw	0x2A						; CTRL_REG1
	rcall	I2C_TX
;	movlw	b'00110001'					; CTRL_REG1: 160 ms data rate, active  mode
	movlw	b'00110101'					; CTRL_REG1: 160 ms data rate, standby mode, reduced noise mode, active Mode
	rcall	I2C_TX
	bsf		SSP1CON2,PEN				; stop condition
	bra		WaitMSSP					; ... and return

I2C_init_accelerometer2:
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP
	movlw	0x32						; address
	rcall	I2C_TX
	movlw	0x9F						; 1F with auto-increment (MSB=1)
	rcall	I2C_TX
	movlw	b'00000000'					; TEMP_CFG_REG_A (Temp sensor off)
	rcall	I2C_TX
	movlw	b'01010111'					; CTRL_REG1_A (100Hz, x,y,z = ON)
	rcall	I2C_TX
	movlw	b'00000000'					; CTRL_REG2_A
	rcall	I2C_TX
;	movlw	b'00000000'					; CTRL_REG3_A
;	rcall	I2C_TX
;	movlw	b'00000000'					; CTRL_REG4_A (BDU=0, +/-2g,
;	rcall	I2C_TX
;	movlw	b'00000000'					; CTRL_REG5_A
;	rcall	I2C_TX
	bsf		SSP1CON2,PEN				; stop condition
	bra		WaitMSSP					; ... and return

I2C_init_accelerometer3:
	bsf	SSP1CON2,SEN		; Start condition
        rcall	WaitMSSP
	movlw	0x3A            ; address
	rcall	I2C_TX
	movlw	0x20
	rcall   I2C_TX
	movlw	b'00110111'	; CTRL_REG1_A (100Hz, x,y,z = ON) 0x20
	rcall   I2C_TX
	movlw	b'00000000'	; CTRL_REG2_A 0x21
	rcall   I2C_TX
	movlw	b'00000000'	; CTRL_REG3_A 0x22
	rcall   I2C_TX
	bsf	SSP1CON2,PEN		; Stop condition
	bra	WaitMSSP	; (And return)
	

	global	I2C_sleep_accelerometer
I2C_sleep_accelerometer:
        btfsc   compass_type3				; Compass3
        bra	    I2C_sleep_accelerometer3		; YES
	btfsc	compass_type2				; Compass2
	bra		I2C_sleep_accelerometer2	; YES
	btfsc	compass_type				; compass1?
	return								; YES - ignore

	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP
	movlw	0x38						; address
	rcall	I2C_TX
	movlw	0x2A						; CTRL_REG1
	rcall	I2C_TX
	movlw	b'00000000'					; standby mode
	rcall	I2C_TX
	bsf		SSP1CON2,PEN				; stop condition
	bra		WaitMSSP					; ... and return

lt2942_init_again:
	clrf	i2c_temp1
	movlw	0x02									; point to accumulated charge registers
	rcall	I2C_TX_GAUGE
	movff	battery_accumulated_charge+1,SSP1BUF	; data byte
	rcall	WaitMSSP
	rcall	I2C_WaitforACK
	movff	battery_accumulated_charge+0,SSP1BUF	; data byte
	rcall	WaitMSSP
	rcall	I2C_WaitforACK
	bsf		SSP1CON2,PEN							; stop condition
	rcall	WaitMSSP
	MOVII	battery_accumulated_charge,sub_a
	; and init again...

	global	lt2942_init
lt2942_init:							; setup control register B
	clrf	i2c_temp1
	movlw	0x01						; point to control reg B
	rcall	I2C_TX_GAUGE
	movlw	b'11111000'					; automatic conversion every two seconds
	movff	WREG, SSP1BUF				; data byte
	rcall	WaitMSSP
	rcall	I2C_WaitforACK
	bsf		SSP1CON2,PEN				; stop condition
	bra		WaitMSSP					; ... and return

	global	lt2942_get_status
lt2942_get_status:						; read status register
	bcf		battery_gauge_available		; clear flag
	clrf	i2c_temp1
	movlw	0x00						; point to status register
	rcall	I2C_TX_GAUGE
	rcall	I2C_RX_GAUGE
	movff	SSP1BUF,WREG
	btfss	WREG,7						; 2942 found?
	bsf		battery_gauge_available		; YES - set flag
	bsf		SSP1CON2,PEN				; stop condition
	bra		WaitMSSP					; ... and return


	global	lt2942_get_voltage
lt2942_get_voltage:						; read battery voltage registers
	clrf	i2c_temp1
	movlw	0x08						; point to voltage registers
	rcall	I2C_TX_GAUGE
	rcall	I2C_RX_GAUGE
	bsf		SSP1CON2,ACKEN				; master acknowledge
	rcall	WaitMSSP
	movff	SSP1BUF,xA+1
	bsf		SSP1CON2, RCEN				; enable receive mode
	rcall	WaitMSSP
	movff	SSP1BUF,xA+0
	bsf		SSP1CON2,PEN				; stop condition
	rcall	WaitMSSP

	; convert voltage from raw value to Volt
	MOVLI	.6000,xB					; load conversion multiplicand into xB
	call	mult16x16					; xC = xA * xB -> multiply raw value in xA with conversion multiplicand
										; divide by 65536 instead of 65535, introducing an error of 65536/65535 = 0.002 %
	movff	xC+2,batt_voltage+0			; divide by 65536 can easily be done by just taking the 3rd and 4th byte of the multiplication result
	movff	xC+3,batt_voltage+1			; ...

	tstfsz	batt_voltage+1				; < 256 mV ?
	return								; NO  - done
	bra		lt2942_init					; YES - ... and return


	global	lt2942_get_temperature
lt2942_get_temperature:					; read battery temperature
	clrf	i2c_temp1
	movlw	0x0C						; point to temperature register
	call	I2C_TX_GAUGE
	call	I2C_RX_GAUGE
	bsf		SSP1CON2,ACKEN				; master acknowledge
	rcall	WaitMSSP
	movff	SSP1BUF,xA+1				; store raw temperature, high byte
	bsf		SSP1CON2, RCEN				; enable receive mode
	rcall	WaitMSSP
	movff	SSP1BUF,xA+0				; store raw temperature, low byte
	bsf		SSP1CON2,PEN				; stop condition
	rcall	WaitMSSP

	; convert temperature from raw value to Kelvin
	MOVLI	.6000,xB					; load conversion multiplicand into xB
	call	mult16x16					; xC = xA * xB -> multiply raw value in xA with conversion multiplicand
										; divide by 65536 instead of 65535, introducing an error of 65536/65535 = 0.002 %
	movff	xC+2,battery_temperature+0	; divide by 65536 can easily be done by just taking the 3rd and 4th byte of the multiplication result
	movff	xC+3,battery_temperature+1	; ...

	; check if battery is charged right now
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
	return


	global	lt2942_get_accumulated_charge
lt2942_get_accumulated_charge:			; read accumulated charge and compute percent
	clrf	i2c_temp1
	movlw	0x00						; point to status register
	rcall	I2C_TX_GAUGE
	rcall	I2C_RX_GAUGE
	bsf		SSP1CON2,ACKEN				; master acknowledge
	rcall	WaitMSSP
	movff	SSP1BUF,gauge_status_byte

	bsf		SSP1CON2, RCEN				; enable receive mode
	rcall	WaitMSSP					; dummy read (control byte)
	movf	SSP1BUF,W
	bsf		SSP1CON2,ACKEN				; master acknowledge
	rcall	WaitMSSP

	bsf		SSP1CON2, RCEN				; enable receive mode
	rcall	WaitMSSP
	movff	SSP1BUF,sub_a+1
	bsf		SSP1CON2,ACKEN				; master acknowledge
	rcall	WaitMSSP

	bsf		SSP1CON2, RCEN				; enable receive mode
	rcall	WaitMSSP
	movff	SSP1BUF,sub_a+0
	bsf		SSP1CON2,PEN				; stop condition
	rcall	WaitMSSP

	btfsc	gauge_status_byte,0			; UVLO event ?
	rcall	lt2942_init_again			; YES

	MOVII	sub_a,battery_accumulated_charge	; save raw value

	; Compute batt_percent
	; (charge-battery_offset)/365
	MOVII	battery_offset,sub_b
	call	subU16						; sub_c = sub_a - sub_b (with signed values)
	clrf	batt_percent				; set to zero
	btfsc	neg_flag					; result negative?
	bra		lt2942_set_to_zero_percent	; YES - keep LT2942 at zero percent and return

	; > zero, set batt_percent properly
	MOVII	sub_c,xA
	MOVII	battery_capacity,xB
	call	div16x16					; xC = xA / xB with xA as remainder
	movff	xC+0,batt_percent
	return

lt2942_set_to_zero_percent:
	clrf	i2c_temp1
	movlw	0x02						; point to accumulated charge registers
	rcall	I2C_TX_GAUGE
	movff	battery_offset+1,SSP1BUF
	rcall	WaitMSSP
	rcall	I2C_WaitforACK
	movff	battery_offset+0,SSP1BUF
	rcall	WaitMSSP
	rcall	I2C_WaitforACK
	bsf		SSP1CON2,PEN				; stop condition
	bra		WaitMSSP					; ... and return

	global	lt2942_charge_done
lt2942_charge_done:						; reset accumulating registers to 0xFFFF
	clrf	i2c_temp1
	movlw	0x02						; point to accumulated charge registers
	rcall	I2C_TX_GAUGE
	setf	SSP1BUF						; data byte
	rcall	WaitMSSP
	rcall	I2C_WaitforACK
	setf	SSP1BUF						; data byte
	rcall	WaitMSSP
	rcall	I2C_WaitforACK
	bsf		SSP1CON2,PEN				; stop condition
	bra		WaitMSSP					; ... and return

I2C_TX_GAUGE:							; send a byte to the LT2942 gauge IC
	movwf	i2c_temp2					; data byte
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP
	movlw	b'11001000'					; address byte + Write bit
	movwf	SSP1BUF						; control byte
	rcall	WaitMSSP
	rcall	I2C_WaitforACK
	movf	i2c_temp2,W
	bra		I2C_TX						; ... and return

I2C_RX_GAUGE:
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP
	movlw	b'11001001'					; address byte + Read bit
	movwf	SSP1BUF						; control byte
	rcall	WaitMSSP
	rcall	I2C_WaitforACK
	bsf		SSP1CON2, RCEN				; enable receive mode
	bra		WaitMSSP					; ... and return


;=============================================================================
; Transmitter Functions
;
 IFDEF _rx_functions

	global	I2C_probe_OSTC_rx
I2C_probe_OSTC_rx:
	bcf		ostc_rx_present				; no TR module by default
	clrf	WREG						; bank-safe set to zero of ...
	movff	WREG,rx_firmware_cur_major	; ... current TR module firmware, major
	movff	WREG,rx_firmware_cur_minor	; ... current TR module firmware, minor
	movlw	.5							; max number of tries for detecting a TR module
	movwf	hy							; initialize counter for tries
I2C_probe_OSTC_rx_1:
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP
	movlw	0x50						; address byte + write bit
	movwf	SSP1BUF						; control byte
	rcall	WaitMSSP
	btfss	SSP1CON2,ACKSTAT			; ACK received?
	bsf		ostc_rx_present				; YES - TR module detected
	bsf		SSP1CON2,PEN				; stop condition
	rcall	WaitMSSP
	btfss	ostc_rx_present				; was a TR module detected?
	return								; NO  - done
	WAITMS	.1
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP
	movlw	0x50						; address byte + write bit
	movwf	SSP1BUF						; control byte
	rcall	WaitMSSP
	rcall	I2C_WaitforACK
	movlw	0x1B
	movwf	SSP1BUF						; data byte (get firmware)
	rcall	WaitMSSP
	rcall	I2C_WaitforACK
	bsf		SSP1CON2,PEN				; stop condition
	rcall	WaitMSSP
	WAITMS	.1
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP
	movlw	0x51						; address byte + Read bit
	movwf	SSP1BUF						; control byte
	rcall	WaitMSSP
	bsf		SSP1CON2,RCEN				; enable receive mode
	rcall	WaitMSSP
	movff	SSP1BUF,rx_firmware_cur_major ; store as firmware version, major
	bsf		SSP1CON2,ACKEN				  ; master acknowledge
	rcall	WaitMSSP

	; last byte in read from RX circuity always with a NACK!
	bsf		SSP1CON2,RCEN				; enable receive mode
	rcall	WaitMSSP
	movff	SSP1BUF,rx_firmware_cur_minor ; store as firmware version, minor
	bsf		SSP1CON2,ACKDT
	bsf		SSP1CON2,ACKEN				; master NOT acknowledge
	rcall	WaitMSSP
	bcf		SSP1CON2,ACKDT				; reset ACKDT flag
	bsf		SSP1CON2,PEN				; stop condition
	rcall	WaitMSSP

	; wait for TR module becoming ready
	movff	rx_firmware_cur_minor,i2c_temp1	; copy firmware version to bank common, minor
	movlw	.147							; code for not ready, minor
	cpfseq	i2c_temp1						; equal?
	bra		I2C_probe_OSTC_rx_2				; NO  - TR module ready
	movff	rx_firmware_cur_major,i2c_temp1 ; YES - copy firmware version to bank common, major
	movlw	.27								;     - code for not ready, major
	cpfseq	i2c_temp1						;     - equal?
	bra		I2C_probe_OSTC_rx_2				;       NO  - TR module ready
	bsf		active_reset_ostc_rx			;       YES - apply reset to TR module
	WAITMS	.5								;           - wait 5 ms
	bcf		active_reset_ostc_rx			;           - release reset
	WAITMS	.250							;           - wait for     250 ms
	WAITMS	.250							;           - wait another 250 ms
	clrf	i2c_temp1						;           - clean-up i2c_temp1
	decfsz	hy,F							;           - decrement counter for number of tries, became zero?
	bra		I2C_probe_OSTC_rx_1				;           - NO  - try again
	bcf		ostc_rx_present					;           - YES - something is wrong, flag TR module as not available
I2C_probe_OSTC_rx_2:
	clrf	i2c_temp1						; clean-up i2c_temp1
	return									; done


	global	I2C_get_tankdata
I2C_get_tankdata:
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP
	movlw	0x50						; address byte + write bit
	movwf	SSP1BUF						; control byte
	rcall	WaitMSSP
	rcall	I2C_WaitforACK
	movlw	0x1E						; read buffer2 (48 bytes)
	movwf	SSP1BUF						; data byte
	rcall	WaitMSSP
	rcall	I2C_WaitforACK
	bsf		SSP1CON2,PEN				; stop condition
	rcall	WaitMSSP
	WAITMS	.1
	; read 48 bytes
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP
	movlw	0x51						; address byte + read bit
	movwf	SSP1BUF						; control byte
	rcall	WaitMSSP
	rcall	I2C_WaitforACK
	movlw	.47							; 47 with ACK + 1 w/o ACK
	movwf	i2c_temp2
	lfsr	FSR2,rx_buffer
I2C_get_tankdata_loop_read:
	bsf		SSP1CON2, RCEN				; enable receive mode
	rcall	WaitMSSP
	movff	SSP1BUF,POSTINC2
	bcf		SSP1CON2,ACKDT
	bsf		SSP1CON2,ACKEN				; master acknowledge
	rcall	WaitMSSP
	decfsz	i2c_temp2,F
	bra		I2C_get_tankdata_loop_read
	; 1 w/o ACK
	bsf		SSP1CON2, RCEN				; enable receive mode
	rcall	WaitMSSP
	movff	SSP1BUF,POSTINC2
	bsf		SSP1CON2,ACKDT
	bsf		SSP1CON2,ACKEN				; master NOT acknowledge
	rcall	WaitMSSP
	bcf		SSP1CON2,ACKDT				; reset ACKDT flag
	bsf		SSP1CON2,PEN				; stop condition
	bra		WaitMSSP					; ... and return


	global	I2C_update_OSTC_rx
I2C_update_OSTC_rx:						; transfer 64 byte to RX co-processor
	; setup for write
	bcf		i2c_error_flag				; clear error flag
	lfsr	FSR2,buffer					; initialize pointer to send buffer used for verify
	movlw	.64							; initialize loop counter: 64 byte with ACK
	movwf	i2c_temp2					; ...
	; address write
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP
	movlw	0x50						; address byte + write bit
	movwf	SSP1BUF						; control byte
	rcall	WaitMSSP
	rcall	I2C_WaitforACK
	; write 64 bytes
I2C_update_OSTC_loop:
	TBLRD*+								; read a byte from program memory
	movff	TABLAT,POSTINC2				; copy to send buffer
	movff	TABLAT,SSP1BUF				; copy to I2C data buffer
	rcall	WaitMSSP
	rcall	I2C_WaitforACK
	decfsz	i2c_temp2,F					;decrement loop counter, became zero?
	bra		I2C_update_OSTC_loop		; NO  - loop
	bsf		SSP1CON2,PEN				; YES - stop condition
	rcall	WaitMSSP					;     - wait for stop condition done
	WAITMS	.1							;     - wait another 1 ms
	; setup for read-back
	lfsr	FSR2,buffer					; reset pointer to begin of send buffer
	movlw	.63							; initialize loop counter: 63 byte with ACK + 1 w/o ACK
	movwf	i2c_temp2
	; address read-back
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP
	movlw	0x51						; address byte + read bit
	movwf	SSP1BUF						; control byte
	rcall	WaitMSSP
	rcall	I2C_WaitforACK
	; read-back 64 bytes
I2C_update_OSTC_loop_read:
	bsf		SSP1CON2,RCEN				; enable receive mode
	rcall	WaitMSSP
	movf	SSP1BUF,W
	cpfseq	POSTINC2					; compare read-back byte with sent byte, equal?
	bsf		i2c_error_flag				; NO  - not equal, set error flag
	bcf		SSP1CON2,ACKDT
	bsf		SSP1CON2,ACKEN				; master acknowledge
	rcall	WaitMSSP
	decfsz	i2c_temp2,F					; decrement loop counter, became zero?
	bra		I2C_update_OSTC_loop_read	; NO  - loop
	; 1 w/o ACK
	bsf		SSP1CON2, RCEN				; YES - enable receive mode
	rcall	WaitMSSP					;     -
	movf	SSP1BUF,W					;     - get 64th byte
	cpfseq	POSTINC2					;     - compare read-back byte with sent byte, equal?
	bsf		i2c_error_flag				;       NO  - not equal, set error flag
	bsf		SSP1CON2,ACKDT				;     -
	bsf		SSP1CON2,ACKEN				;     - master NOT acknowledge
	rcall	WaitMSSP					;     -
	bcf		SSP1CON2,ACKDT				;     - reset ACKDT flag
	; stop
	bsf		SSP1CON2,PEN				; stop condition
	rcall	WaitMSSP
	WAITMS	.1
	; address commit
	bsf		SSP1CON2,SEN				; start condition
	rcall	WaitMSSP
	movlw	0x50						; address byte + write bit
	movwf	SSP1BUF						; control byte
	rcall	WaitMSSP
	rcall	I2C_WaitforACK
	movlw	0x1F						; write command
	movwf	SSP1BUF						; data byte
	rcall	WaitMSSP
	rcall	I2C_WaitforACK
	bsf		SSP1CON2,PEN				; stop condition
	rcall	WaitMSSP
	WAITMS	.5							; required waiting time
	; error check
	btfss	i2c_error_flag				; did an error occur?
	retlw	.0							; NO  - data transfered successfully
	retlw	.255						; YES - error in data transfer occurred

 ENDIF

;=============================================================================

	END
