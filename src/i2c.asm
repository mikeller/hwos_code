;=============================================================================
;
;   File i2c.asm														V2.99c
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


i2c		CODE

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
	btfsc	flip_screen					; 180° rotation ?
	bra		I2C_RX_accelerometer2		; YES
	comf	hi							; 16 bit sign change
	negf	lo
	btfsc	STATUS,C					; carry to propagate ?
	incf	hi,F						; YES - do it
I2C_RX_accelerometer2:
	movff	lo,accel_DX+0
	movff	hi,accel_DX+1				; Copy result

	rcall	I2C_TwoBytesRX_div16		; Get two bytes and divide /16 (signed)
	btfsc	flip_screen					; 180° rotation ?
	bra		I2C_RX_accelerometer3		; Yes
	comf	hi							; 16bit sign change.
	negf	lo
	btfsc	STATUS,C					; Carry to propagate ?
	incf	hi,F						; YES: do it.
I2C_RX_accelerometer3:
	movff	lo,accel_DY+0
	movff	hi,accel_DY+1				; Copy result

	rcall	I2C_OneByteRX				; Get one byte
	movff	SSP1BUF,hi					; Data Byte
	bsf		SSP1CON2, RCEN				; Enable receive mode
	rcall	WaitMSSP
; According to data sheet there should be no Master Acknowledge for the last Byte (accel_DZ+0)...
	movff	SSP1BUF,lo					; Data Byte

	rcall	I2C_TwoBytesRX_div16_2		; divide lo:hi/16 (signed) only
	comf	hi							; 16bit sign change.
	negf	lo
	btfsc	STATUS,C					; Carry to propagate ?
	incf	hi,F						; YES: do it.
	movff	lo,accel_DZ+0
	movff	hi,accel_DZ+1				; Copy result

	bsf		SSP1CON2,PEN				; Stop condition
	bra		WaitMSSP					; (And return)

I2C_RX_accelerometer_compass1:
	bsf		SSP1CON2,SEN				; Start condition
	rcall	WaitMSSP
	movlw	0x3C						; address
	rcall	I2C_TX
	movlw	b'10101000'					; 0x28 with auto-increment (MSB=1)
	rcall	I2C_TX
	bsf		SSP1CON2,RSEN				; Repeated start condition (!)
	rcall	WaitMSSP
	movlw	0x3D						; address
I2C_RX_accelerometer_compass1_xx:		; compass2 continues here... 
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
	movff	SSP1BUF,hi  ;accel_DX+1
	rcall	I2C_TwoBytesRX_div16_2		; divide lo:hi/16 (signed) only
	btfss	compass_type2				; compass 2?
	bra		I2C_RX_accelerometer1_c1	; No, compass 1
	; compass 2
	btfss	flip_screen					; 180° rotation ?
	bra		I2C_RX_accelerometer2_c1	; No, continue with normal compass1 routines for Y and Z
	; flipped compass 2, negate x
	comf	hi							; 16bit sign change.
	negf	lo
	btfsc	STATUS,C					; Carry to propagate ?
	incf	hi,F						; YES: do it.
	bra		I2C_RX_accelerometer2_c1	; continue with normal compass1 routines for Y and Z

I2C_RX_accelerometer1_c1:
	btfsc	flip_screen					; 180° rotation ?
	bra		I2C_RX_accelerometer2_c1	; Yes
	; non-flipped compass 1, negate x
	comf	hi							; 16bit sign change.
	negf	lo
	btfsc	STATUS,C					; Carry to propagate ?
	incf	hi,F						; YES: do it.
I2C_RX_accelerometer2_c1:
	; flipped compass 1, non-flipped compass 2
	movff	lo,accel_DX+0
	movff	hi,accel_DX+1				; Copy result
	rcall	I2C_OneByteRX
	movff	SSP1BUF,lo					; accel_DY+0
	rcall	I2C_OneByteRX
	movff	SSP1BUF,hi					; accel_DY+1

	rcall	I2C_TwoBytesRX_div16_2		; divide lo:hi/16 (signed) only
	btfsc	flip_screen					; 180° rotation ?
	bra		I2C_RX_accelerometer3_c1	; Yes
	comf	hi							; 16bit sign change.
	negf	lo
	btfsc	STATUS,C					; Carry to propagate ?
	incf	hi,F						; YES: do it.
I2C_RX_accelerometer3_c1:
	movff	lo,accel_DY+0
	movff	hi,accel_DY+1				; Copy result

	rcall	I2C_OneByteRX
	movff	SSP1BUF,lo					;accel_DZ+0
	bsf		SSP1CON2, RCEN				; Enable receive mode
	rcall	WaitMSSP
; According to data sheet there should be no Master Acknowledge for the last Byte (accel_DZ+1)...
	movff	SSP1BUF,hi					;accel_DZ+1
	bsf		SSP1CON2,PEN				; Stop condition
	rcall	WaitMSSP
	rcall	I2C_TwoBytesRX_div16_2		; divide lo:hi/16 (signed) only
	comf	hi							; 16bit sign change for Z
	negf	lo
	btfsc	STATUS,C					; Carry to propagate ?
	incf	hi,F						; YES: do it.
	movff	lo,accel_DZ+0
	movff	hi,accel_DZ+1				; Copy result
	return

I2C_RX_accelerometer_compass2:
	bsf		SSP1CON2,SEN				; Start condition
	rcall	WaitMSSP
	movlw	0x32						; address
	rcall	I2C_TX
	movlw	b'10101000'					; 0x28 with auto-increment (MSB=1)
	rcall	I2C_TX
	bsf		SSP1CON2,RSEN				; Repeated start condition (!)
	rcall	WaitMSSP
	movlw	0x33						; address
	bra		I2C_RX_accelerometer_compass1_xx

I2C_OneByteRX:
	bsf		SSP1CON2,RCEN				; Enable receive mode
	rcall	WaitMSSP
	bsf		SSP1CON2,ACKEN				; Master acknowledge
	bra		WaitMSSP					; And return!

	global	I2C_RX_compass
I2C_RX_compass:
	btfsc	compass_type2				; compass2
	bra		I2C_RX_compass2				; yes
	btfsc	compass_type				; compass1?
	bra		I2C_RX_compass1				; yes
I2C_RX_compass0:
	bsf		SSP1CON2,SEN				; Start condition
	rcall	WaitMSSP
	movlw	0x3C						; address
	rcall	I2C_TX
	movlw	0x03
	rcall	I2C_TX
	bsf		SSP1CON2,PEN				; Stop condition
	rcall	WaitMSSP

	bcf		PIR1,SSP1IF
	bsf		SSP1CON2,SEN				; Start condition
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

	rcall	I2C_OneByteRX				; Get one byte
	movff	SSP1BUF,compass_DY+1		; Data Byte
	rcall	I2C_OneByteRX				; Get one byte
	movff	SSP1BUF,compass_DY+0		; Data Byte
	btfsc	flip_screen					; 180° rotation ?
	bra		I2C_RX_compass0_2			; Yes
	banksel	compass_DY
	comf	compass_DY+1				; 16bit sign change.
	negf	compass_DY+0
	btfsc	STATUS,C					; Carry to propagate ?
	incf	compass_DY+1,F				; YES: do it.
I2C_RX_compass0_2:
	banksel	common
	rcall	I2C_OneByteRX				; Get one byte
	movff	SSP1BUF,compass_DZ+1		; Data Byte
	rcall	I2C_OneByteRX				; Get one byte
	movff	SSP1BUF,compass_DZ+0		; Data Byte
	rcall	I2C_OneByteRX				; Get one byte
	movff	SSP1BUF,compass_DX+1		; Data Byte
	bsf		SSP1CON2, RCEN				; Enable receive mode
	rcall	WaitMSSP
	movff	SSP1BUF,compass_DX+0		; Data Byte
	bsf		SSP1CON2,PEN				; Stop condition
	rcall	WaitMSSP
	btfss	flip_screen					; 180° rotation ?
	return								; No, done.
	; Yes, flip X
	banksel	compass_DX
	comf	compass_DX+1				; 16bit sign change.
	negf	compass_DX+0
	btfsc	STATUS,C					; Carry to propagate ?
	incf	compass_DX+1,F				; YES: do it.
	banksel	common
	return

I2C_RX_compass1:						; New compass
	bsf		SSP1CON2,SEN				; Start condition
	rcall	WaitMSSP
	movlw	0x3C						; address
	rcall	I2C_TX
	movlw	b'10001000'					; 0x08 with auto-increment (MSB=1)
	rcall	I2C_TX
	bsf		SSP1CON2,RSEN				; Repeated start condition (!)
	rcall	WaitMSSP
	movlw	0x3D						; address
	rcall	I2C_TX
	;rcall	WaitMSSP					; Needed? (mH)
	rcall	I2C_OneByteRX				; Get one byte
	movff	SSP1BUF,lo					; Data Byte
	rcall	I2C_OneByteRX				; Get one byte
	movff	SSP1BUF,hi					; Data Byte
	rcall	I2C_TwoBytesRX_div8_2
	movff	lo,compass_DX+0
	movff	hi,compass_DX+1
	btfss	   flip_screen				; 180° rotation ?
	bra		I2C_RX_compass1_1			; Yes
	; Yes, flip X
	banksel compass_DX
	comf	compass_DX+1				; 16bit sign change.
	negf	compass_DX+0
	btfsc	STATUS,C					; Carry to propagate ?
	incf	compass_DX+1,F				; YES: do it.
	banksel	common
I2C_RX_compass1_1:
	rcall	I2C_OneByteRX				; Get one byte
	movff	SSP1BUF,lo					; Data Byte
	rcall	I2C_OneByteRX				; Get one byte
	movff	SSP1BUF,hi					; Data Byte
	rcall	I2C_TwoBytesRX_div8_2
	movff	lo,compass_DY+0
	movff	hi,compass_DY+1
	btfss	flip_screen					; 180° rotation ?
	bra		I2C_RX_compass1_2			; Yes
	; Yes, flip Y
	banksel compass_DY
	comf	compass_DY+1				; 16bit sign change.
	negf	compass_DY+0
	btfsc	STATUS,C					; Carry to propagate ?
	incf	compass_DY+1,F				; YES: do it.
I2C_RX_compass1_2:
	banksel	common
	rcall	I2C_OneByteRX				; Get one byte
	movff	SSP1BUF,lo					; Data Byte
	bsf		SSP1CON2, RCEN				; Enable receive mode
	rcall	WaitMSSP
	movff	SSP1BUF,hi					; Data Byte
	rcall	I2C_TwoBytesRX_div8_2
	movff	lo,compass_DZ+0
	movff	hi,compass_DZ+1
	bsf		SSP1CON2,PEN				; Stop condition
	bra		WaitMSSP					;(And return)

I2C_RX_compass2:						; newest compass
	bsf		SSP1CON2,SEN				; Start condition
	rcall	WaitMSSP
	movlw	0x3C						; address
	rcall	I2C_TX
	movlw	0xE8						; 0x68 with auto-increment (MSB=1)
	rcall	I2C_TX
	bsf		SSP1CON2,RSEN				; Repeated start condition (!)
	rcall	WaitMSSP
	movlw	0x3D						; address
	rcall	I2C_TX
;	rcall	WaitMSSP
	rcall	I2C_OneByteRX				; Get one byte
	movff	SSP1BUF,lo					; Data Byte
	rcall	I2C_OneByteRX				; Get one byte
	movff	SSP1BUF,hi					; Data Byte
;	rcall	I2C_TwoBytesRX_div8_2
	btfsc	flip_screen					; 180° rotation ?
	bra		I2C_RX_compass2_1			; Yes, do nothing with X
	; No, flip X
	comf	hi							; 16bit sign change.
	negf	lo
	btfsc	STATUS,C					; Carry to propagate ?
	incf	hi,F						; YES: do it.
I2C_RX_compass2_1:
	movff	lo,compass_DX+0
	movff	hi,compass_DX+1
	rcall	I2C_OneByteRX				; Get one byte
	movff	SSP1BUF,lo					; Data Byte
	rcall	I2C_OneByteRX				; Get one byte
	movff	SSP1BUF,hi					; Data Byte
;	rcall	I2C_TwoBytesRX_div8_2
	btfss	flip_screen					; 180° rotation ?
	bra		I2C_RX_compass2_2			; No, do nothing with Y
	; Yes, flip Y
	comf	hi							; 16bit sign change.
	negf	lo
	btfsc	STATUS,C					; Carry to propagate ?
	incf	hi,F						; YES: do it.
I2C_RX_compass2_2:   
	movff	lo,compass_DY+0
	movff	hi,compass_DY+1
	rcall	I2C_OneByteRX				; Get one byte
	movff	SSP1BUF,lo					; Data Byte
	rcall	I2C_OneByteRX				; Get one byte
	movff	SSP1BUF,hi					; Data Byte
;	rcall	I2C_TwoBytesRX_div8_2
	movff	lo,compass_DZ+0
	movff	hi,compass_DZ+1
	bsf		SSP1CON2,PEN				; Stop condition
	bra		WaitMSSP ;(And return)


	global	I2C_init_compass
I2C_init_compass:
	bsf		compass_enabled
	bcf		compass_type2
	; probe compass 2
	bsf		SSP1CON2,SEN				; Start condition
	rcall	WaitMSSP
	movlw	0x32						; Address byte + Write bit
	movwf	SSP1BUF						; control byte
	rcall	WaitMSSP
	btfss	SSP1CON2,ACKSTAT			; ACK?
	bsf		compass_type2				; ACK send. compass2 present
	bsf		SSP1CON2,PEN				; Stop condition
	rcall	WaitMSSP

	btfsc	compass_type2
	bra		I2C_init_compass2			; Compass2
	; Check for compass0 or compass1...
	bsf		compass_type				; set flag
	bsf		SSP1CON2,SEN				; Start condition
	rcall	WaitMSSP
	movlw	0x3C						; address
	rcall	I2C_TX
	movlw	0x0F
	rcall	I2C_TX
	bsf		SSP1CON2,PEN				; Stop condition
	rcall   WaitMSSP
	bcf		PIR1,SSP1IF
	bsf		SSP1CON2,SEN				; Start condition
	rcall	WaitMSSP
	movlw	0x3D						; address
	rcall	I2C_TX
	rcall	I2C_OneByteRX				; Get one byte
	movlw	0x49						; 0x49 = Compass1
	cpfseq	SSP1BUF
	bcf		compass_type				; clear flag
	bsf		SSP1CON2,PEN				; Stop condition
	rcall	WaitMSSP

	btfsc	compass_type				; compass1?
	bra		I2C_init_compass1			; yes
; init compass0
	bsf		SSP1CON2,SEN				; Start condition
	rcall	WaitMSSP
	movlw	0x3C						; address
	rcall	I2C_TX
	movlw	0x00
	rcall	I2C_TX
;	movlw	b'01101001'					; ConfigA:  3Hz, 8 Samples averaged, Test Mode (Positive Bias)
	movlw	b'01101000'					; ConfigA:  3Hz, 8 Samples averaged
	rcall	I2C_TX
I2C_init_compass_common:
	movff	opt_compass_gain,i2c_temp1	; 0-7 (230LSB/Gauss to 1370LSB/Gauss)
	swapf	i2c_temp1,F
	comf	i2c_temp1,F
	bcf		STATUS,C
	rlcf	i2c_temp1
	movf	i2c_temp1,W
	clrf	i2c_temp1
	rcall	I2C_TX
	movlw	b'00000000'					; Continuous Mode
	rcall	I2C_TX
	bsf		SSP1CON2,PEN				; Stop condition
	bra		WaitMSSP					; (And return)

I2C_init_compass1:
	bsf		SSP1CON2,SEN				; Start condition
	rcall	WaitMSSP
	movlw	0x3C						; address
	rcall	I2C_TX
	movlw	0x9F						; 1F with auto-increment (MSB=1)
	rcall	I2C_TX
	movlw	b'00000000'					; CTRL0
	rcall	I2C_TX
	movlw	b'00101111'					; CTRL1 (6,25Hz, BDU=0, x,y,z = ON)
	rcall	I2C_TX
	movlw	b'11000000'					; CTRL2 (50Hz, +/-2g, 
	rcall	I2C_TX
	movlw	b'00000000'					; CTRL3
	rcall	I2C_TX
	movlw	b'00000000'					; CTRL4
	rcall	I2C_TX
	movlw	b'01100100'					; CTRL5 HIGH res, 6,25Hz
	rcall	I2C_TX
init_compass1_common:
	movff	opt_compass_gain,i2c_temp1	; 0-7 (230LSB/Gauss to 1370LSB/Gauss) +++
	movlw	b'01100000'					; CTRL6 Full scale (+/-12 Gauss -> 2730LSB/Gauss)
	dcfsnz	i2c_temp1,F					; = 1?
	movlw	b'01100000'					; Yes, CTRL6 Full scale (+/-12 Gauss -> 2730LSB/Gauss)
	dcfsnz	i2c_temp1,F					; = 2?
	movlw	b'01000000'					; Yes, CTRL6 (+/-8 Gauss)
	dcfsnz	i2c_temp1,F					; = 3?
	movlw	b'01000000'					; Yes, CTRL6 (+/-8 Gauss)
	dcfsnz	i2c_temp1,F					; = 4?
	movlw	b'00100000'					; Yes, CTRL6 (+/-4 Gauss)
	dcfsnz	i2c_temp1,F					; = 5?
	movlw	b'00100000'					; Yes, CTRL6 (+/-4 Gauss)
	dcfsnz	i2c_temp1,F					; = 6?
	movlw	b'00000000'					; Yes, CTRL6 (+/-2 Gauss)
	dcfsnz	i2c_temp1,F					; = 7?
	movlw	b'00000000'					; Yes, CTRL6 (+/-2 Gauss)
	rcall	I2C_TX
	movlw	b'00000000'					; CTRL7 Continuous Mode
	rcall	I2C_TX
	bsf		SSP1CON2,PEN				; Stop condition
	bra		WaitMSSP					; (And return)

I2C_init_compass2:
    bsf		SSP1CON2,SEN	; Start condition
    rcall	WaitMSSP
    movlw	0x3C            ; address
    rcall       I2C_TX
    movlw	0xE0		; 0x60 with auto-increment (MSB=1)
    rcall       I2C_TX
    movlw	b'00000000'	; CFG_REG_A_M (10Hz, Continuous) 0x60
    rcall       I2C_TX
    movlw	b'00000000'	; CFG_REG_B_M (Low-Pass Filter off) 0x61 (set pulse is released every 63 ODR)
    rcall       I2C_TX
    movlw	b'00000000'	; CFG_REG_C_M BDU=0 0x62
    rcall       I2C_TX
    bsf		SSP1CON2,PEN	; Stop condition
    bra		WaitMSSP	;(And return)


	global	I2C_sleep_compass
I2C_sleep_compass:
	bcf		 compass_enabled
	btfsc	compass_type2				; compass2?
	bra		I2C_sleep_compass2			; yes
	btfsc	compass_type				; compass1?
	bra		I2C_sleep_compass1			; yes
I2C_sleep_compass0:
	bsf		SSP1CON2,SEN				; Start condition
	rcall	WaitMSSP
	movlw	0x3C						; address
	rcall	I2C_TX
	movlw	0x00
	rcall	I2C_TX
	movlw	b'01101000'					; ConfigA
	rcall	I2C_TX
	movlw	b'00100000'					; ConfigB
	rcall	I2C_TX
	movlw	b'00000010'					; Idle Mode
	rcall	I2C_TX
	bsf		SSP1CON2,PEN				; Stop condition
	bra		WaitMSSP					; (And return)

I2C_sleep_compass1:
	bsf		SSP1CON2,SEN				; Start condition
	rcall	WaitMSSP
	movlw	0x3C						; address
	rcall	I2C_TX
	movlw	0x20						; CTRL_REG1
	rcall	I2C_TX
	movlw	b'00000000'					; data for CTRL_REG1: acceleration sensor Power-down mode
	rcall	I2C_TX
	bsf		SSP1CON2,PEN				; Stop condition
	rcall	WaitMSSP
	bsf		SSP1CON2,SEN				; Start condition
	rcall	WaitMSSP
	movlw	0x3C						; address
	rcall	I2C_TX
	movlw	0x26						; CTRL_REG7
	rcall	I2C_TX
	movlw	b'00000010'					; data for CTRL_REG7: magnetic sensor Power-down mode
	rcall	I2C_TX
	bsf		SSP1CON2,PEN				; Stop condition
	bra		WaitMSSP					;(And return)

I2C_sleep_compass2:
    ; magnetic
    bsf		SSP1CON2,SEN	; Start condition
    rcall	WaitMSSP
    movlw	0x3C            ; address
    rcall       I2C_TX
    movlw	0xE0		; 0x60 with auto-increment (MSB=1)
    rcall       I2C_TX
    movlw	b'00000011'	; CFG_REG_A_M (Idle mode) 0x60
    rcall       I2C_TX
    movlw	b'00000100'	; CFG_REG_B_M 0x61  (set pulse is released only at power-on after PD condition)
    rcall       I2C_TX
    movlw	b'01010001'	; CFG_REG_C_M 0x62
    rcall       I2C_TX
    movlw	b'00000000'	; INT_CTRL_REG_M 0x63
    rcall       I2C_TX

    bsf		SSP1CON2,PEN	; Stop condition
    bra		WaitMSSP	; (And return)
    
I2C_sleep_accelerometer2:
    ; accelerometer
    bsf		SSP1CON2,SEN		; Start condition
    rcall	WaitMSSP
    movlw	0x32            ; address
    rcall       I2C_TX
    movlw	0x9F		; 1F with auto-increment (MSB=1)
    rcall       I2C_TX
    movlw	b'00000000'	; TEMP_CFG_REG_A (Temp sensor off) 0x1F
    rcall       I2C_TX
    movlw	b'00000000'	; CTRL_REG1_A (All off) 0x20
    rcall       I2C_TX
    bsf		SSP1CON2,PEN	; Stop condition
    bra		WaitMSSP	; (And return)

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
	rcall	I2CReset					; I2C Reset
	bcf		PIR1,SSP1IF
	clrf	i2c_temp1
	bsf		i2c_error_flag				; set error flag
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
	btfsc	compass_type2				; compass2?
	bra		I2C_init_accelerometer2		; Yes.

	btfsc	compass_type				; compass1?
	return								; yes, ignore

	rcall	I2C_sleep_accelerometer		; Regs can only be changed in St.By mode

	bsf		SSP1CON2,SEN				; Start condition
	rcall	WaitMSSP
	movlw	0x38						; address
	rcall	I2C_TX
	movlw	0x0E						; XYZ_DATA_CFG
	rcall	I2C_TX
	movlw	b'00000000'					; High pass Filter=0 , +/- 2g range
	rcall	I2C_TX
	bsf		SSP1CON2,PEN				; Stop condition
	rcall	WaitMSSP

	bsf		SSP1CON2,SEN				; Start condition
	rcall	WaitMSSP
	movlw	0x38						; address
	rcall	I2C_TX
	movlw	0x2A						; CTRL_REG1
	rcall	I2C_TX
;	movlw	b'00110000'					; CTRL_REG1: 160ms data rate, St.By Mode
	movlw	b'00110100'					; CTRL_REG1: 160ms data rate, St.By Mode, reduced noise mode
	rcall	I2C_TX
	movlw	b'00000010'					; CTRL_REG2: High Res in Active mode
	rcall	I2C_TX
	bsf		SSP1CON2,PEN				; Stop condition
	rcall	WaitMSSP

	bsf		SSP1CON2,SEN				; Start condition
	rcall	WaitMSSP
	movlw	0x38						; address
	rcall	I2C_TX
	movlw	0x2A						; CTRL_REG1
	rcall	I2C_TX
;	movlw	b'00110001'					; CTRL_REG1: 160ms data rate, Active Mode
	movlw	b'00110101'					; CTRL_REG1: 160ms data rate, St.By Mode, reduced noise mode, Active Mode
	rcall	I2C_TX
	bsf		SSP1CON2,PEN				; Stop condition
	bra		WaitMSSP					; (And return)

I2C_init_accelerometer2:
	bsf		SSP1CON2,SEN				; Start condition
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
	bsf		SSP1CON2,PEN				; Stop condition
	bra		WaitMSSP					; (And return)

	global	I2C_sleep_accelerometer
I2C_sleep_accelerometer:
	btfsc	compass_type2				; Compass2
	bra		I2C_sleep_accelerometer2	; Yes
	btfsc	compass_type				; compass1?
	return								; yes, ignore

	bsf		SSP1CON2,SEN				; Start condition
	rcall	WaitMSSP
	movlw	0x38						; address
	rcall	I2C_TX
	movlw	0x2A						; CTRL_REG1
	rcall	I2C_TX
	movlw	b'00000000'					; St. By Mode
	rcall	I2C_TX
	bsf		SSP1CON2,PEN				; Stop condition
	bra	WaitMSSP						; (And return)

lt2942_init_again:
	clrf	i2c_temp1
	movlw	0x02						; Point to accumulated charge registers
	rcall	I2C_TX_GAUGE
	movff	battery_acumulated_charge+1,SSP1BUF	; Data Byte
	rcall	WaitMSSP
	rcall	I2C_WaitforACK
	movff	battery_acumulated_charge+0,SSP1BUF	; Data Byte
	rcall	WaitMSSP
	rcall	I2C_WaitforACK
	bsf		SSP1CON2,PEN				; Stop condition
	rcall	WaitMSSP
	movff	battery_acumulated_charge+1,sub_a+1
	movff	battery_acumulated_charge+0,sub_a+0
	; and init again...

	global	lt2942_init
lt2942_init:							; Setup Control register B
	clrf	i2c_temp1
	movlw	0x01						; Point to control reg B
	rcall	I2C_TX_GAUGE
	movlw	b'11111000'					; Automatic conversion every two seconds
	movff	WREG, SSP1BUF				; Data Byte
	rcall	WaitMSSP
	rcall	I2C_WaitforACK
	bsf		SSP1CON2,PEN				; Stop condition
	bra		WaitMSSP					; (And return)

	global	lt2942_get_status
lt2942_get_status:						; Read status register
	bcf		battery_gauge_available		; Clear flag
	clrf	i2c_temp1
	movlw	0x00						; Point to Status reg
	rcall	I2C_TX_GAUGE
	rcall	I2C_RX_GAUGE
	movff	SSP1BUF,WREG
	btfss	WREG,7						; 2942 found?
	bsf		battery_gauge_available		; Yes, set flag
	bsf		SSP1CON2,PEN				; Stop condition
	bra		WaitMSSP					; (And return)


	global	lt2942_get_voltage
lt2942_get_voltage:						; Read battery voltage registers
	clrf	i2c_temp1
	movlw	0x08						; Point to voltage registers
	rcall	I2C_TX_GAUGE
	rcall	I2C_RX_GAUGE
	bsf		SSP1CON2,ACKEN				; Master acknowledge
	rcall	WaitMSSP
	movff	SSP1BUF,xA+1
	bsf		SSP1CON2, RCEN				; Enable receive mode
	rcall	WaitMSSP
	movff	SSP1BUF,xA+0
	bsf		SSP1CON2,PEN				; Stop condition
	rcall	WaitMSSP

;	banksel	common
	; xA:2 loaded with raw values
	movlw	LOW  .6000
	movwf	xB+0
	movlw	HIGH .6000
	movwf	xB+1
	call	mult16x16					; xA*xB=xC

	; divide xC (32bit)/65535 for result in mV (16bit)
	movlw	.16
	movwf	i2c_temp1
lt2942_get_voltage2:
	bcf		STATUS,C
	rrcf	xC+3,F
	rrcf	xC+2,F
	rrcf	xC+1,F
	rrcf	xC+0,F
	decfsz	i2c_temp1,F
	bra		lt2942_get_voltage2

	; Update battery voltage in mV
	movff	xC+1,batt_voltage+1
	movff	xC+0,batt_voltage+0

	tstfsz	batt_voltage+1				; <256mV?
	return								; No, done.
	bra		lt2942_init					;(and return)

	global	lt2942_get_temperature
lt2942_get_temperature:		; Read temperature registers
	clrf	i2c_temp1
	movlw	0x0C            ; Point to temperature registers
	call	I2C_TX_GAUGE
	call	I2C_RX_GAUGE
	bsf		SSP1CON2,ACKEN	; Master acknowlegde
	rcall	WaitMSSP
	movff	SSP1BUF,xA+1
	bsf		SSP1CON2, RCEN	; Enable recieve mode
	rcall	WaitMSSP
	movff	SSP1BUF,xA+0
	bsf		SSP1CON2,PEN	; Stop condition
	rcall	WaitMSSP

;	banksel	common
    ; xA:2 loaded with raw values
    movlw   LOW     .6000
    movwf   xB+0
    movlw   HIGH    .6000
    movwf   xB+1
    call    mult16x16		;xA*xB=xC

    ; devide xC (32bit)/65535 for result in 0.1K (16bit)
    movlw   .16
    movwf   i2c_temp1
lt2942_get_temperature2:
    bcf     STATUS,C
    rrcf    xC+3,F
    rrcf    xC+2,F
    rrcf    xC+1,F
    rrcf    xC+0,F
    decfsz  i2c_temp1,F
    bra     lt2942_get_temperature2

    movff   xC+1,sub_a+1
    movff   xC+0,sub_a+0
    movlw   LOW     .2731       ; Kelvin to Celcius offset
    movwf   sub_b+0
    movlw   HIGH    .2731       ; Kelvin to Celcius offset
    movwf   sub_b+1
    call    subU16  ;  sub_c = sub_a - sub_b (with UNSIGNED values)

    ; Update battery_temperature in 0.1°C
    movff   sub_c+1,battery_temperature+1
    movff   sub_c+0,battery_temperature+0
    
    movlw   LOW	    max_allowed_battery_temp	    ; in 0.1°C
    movwf   sub_a+0
    movlw   HIGH    max_allowed_battery_temp
    movwf   sub_a+1
    movff   battery_temperature+0,sub_b+0
    movff   battery_temperature+1,sub_b+1
    call    subU16  ;  sub_c = sub_a - sub_b (with UNSIGNED values)
    btfss   neg_flag
    return	; temp ok, return
    ; too hot, disable charge if currently charging
    btfss   cc_active
    return	; Not charging, return
    ; charging: Disable now
    bsf	    charge_disable
    bcf	    TRISE,2
    bsf	    battery_overtemp    ; =1: The battery was charged and temp was too high (Only cleared on POR)
    return

	global	lt2942_get_accumulated_charge
lt2942_get_accumulated_charge:			; Read accumulated charge and compute percent
	clrf	i2c_temp1
	movlw	0x00						; Point to status register
	rcall	I2C_TX_GAUGE
	rcall	I2C_RX_GAUGE
	bsf		SSP1CON2,ACKEN				; Master acknowledge
	rcall	WaitMSSP
	movff	SSP1BUF,gauge_status_byte

	bsf		SSP1CON2, RCEN				; Enable receive mode
	rcall	WaitMSSP					; Dummy read (Control byte)
	movf	SSP1BUF,W
	bsf		SSP1CON2,ACKEN				; Master acknowledge
	rcall	WaitMSSP

	bsf		SSP1CON2, RCEN				; Enable receive mode
	rcall	WaitMSSP
	movff	SSP1BUF,sub_a+1
	bsf		SSP1CON2,ACKEN				; Master acknowledge
	rcall	WaitMSSP

	bsf		SSP1CON2, RCEN				; Enable receive mode
	rcall	WaitMSSP
	movff	SSP1BUF,sub_a+0
	bsf		SSP1CON2,PEN				; Stop condition
	rcall	WaitMSSP

	movff	gauge_status_byte,sub_b+0	; copy into bank common
	btfsc	sub_b+0,0					; =1: UVLO Event
	rcall	lt2942_init_again

	movff	sub_a+1,battery_acumulated_charge+1	; Save raw value
	movff	sub_a+0,battery_acumulated_charge+0	; Save raw value

	; Compute batt_percent
	; (charge-battery_offset)/365
	movff	battery_offset+0,sub_b+0
	movff	battery_offset+1,sub_b+1
	call	subU16						; sub_c = sub_a - sub_b (with signed values)

	clrf	batt_percent				; Set to zero
	btfsc	neg_flag					; result negative?
	bra		lt2942_set_to_zero_percent	; Yes, keep LT2942 at zero percent and return

	; > Zero, set batt_percent properly
	movff	sub_c+0,xA+0
	movff	sub_c+1,xA+1
	movff	battery_capacity+0,xB+0
	movff	battery_capacity+1,xB+1
	call	div16x16					; xC = xA / xB with xA as remainder
	movff	xC+0,batt_percent
	return

lt2942_set_to_zero_percent:
	clrf	i2c_temp1
	movlw	0x02						; Point to accumulated charge registers
	rcall	I2C_TX_GAUGE
	movff	battery_offset+1,SSP1BUF
	rcall	WaitMSSP
	rcall	I2C_WaitforACK
	movff	battery_offset+0,SSP1BUF
	rcall	WaitMSSP
	rcall	I2C_WaitforACK
	bsf		SSP1CON2,PEN				; Stop condition
	bra		WaitMSSP					; (and return)

	global	lt2942_charge_done
lt2942_charge_done:						; Reset accumulating registers to 0xFFFF
	clrf	i2c_temp1
	movlw	0x02						; Point to accumulated charge registers
	rcall	I2C_TX_GAUGE
	setf	SSP1BUF						; Data Byte
	rcall	WaitMSSP
	rcall	I2C_WaitforACK
	setf	SSP1BUF						; Data Byte
	rcall	WaitMSSP
	rcall	I2C_WaitforACK
	bsf		SSP1CON2,PEN				; Stop condition
	bra		WaitMSSP					; (and return)

I2C_TX_GAUGE:							; Sends a byte to the LT2942 Gauge IC
	movwf	i2c_temp2					; Data byte
	bsf		SSP1CON2,SEN				; Start condition
	rcall	WaitMSSP
	movlw	b'11001000'					; Address byte + Write bit
	movwf	SSP1BUF						; control byte
	rcall	WaitMSSP
	rcall	I2C_WaitforACK
	movf	i2c_temp2,W
	bra		I2C_TX						; (and return)

I2C_RX_GAUGE:
	bsf		SSP1CON2,SEN				; Start condition
	rcall	WaitMSSP
	movlw	b'11001001'					; Address byte + Read bit
	movwf	SSP1BUF						; control byte
	rcall	WaitMSSP
	rcall	I2C_WaitforACK
	bsf		SSP1CON2, RCEN				; Enable receive mode
	bra		WaitMSSP					; (and return)


;-----------------------------------------------------------------------------
; Transmitter Functions

 IFDEF _rx_functions

	global	I2C_probe_OSTC_rx
I2C_probe_OSTC_rx:
	movlw	.5
	movwf	lo_temp
I2C_probe_OSTC_rx_1:
	bsf		SSP1CON2,SEN				; Start condition
	rcall	WaitMSSP
	movlw	0x50						; Address byte + Write bit
	movwf	SSP1BUF						; control byte
	rcall	WaitMSSP
	btfss	SSP1CON2,ACKSTAT			; ACK?
	bsf		ostc_rx_present				; ACK sent - OSTC_RX present!
	bsf		SSP1CON2,PEN				; Stop condition
	rcall	WaitMSSP
	btfss	ostc_rx_present				; Do we have the RX?
	return								; No, Done.
	WAITMS	.1
	bsf		SSP1CON2,SEN				; Start condition
	rcall	WaitMSSP
	movlw	0x50						; Address byte + Write bit
	movwf	SSP1BUF						; control byte
	rcall	WaitMSSP
	rcall	I2C_WaitforACK
	movlw	0x1B
	movwf	SSP1BUF						; Data Byte (Get firmware)
	rcall	WaitMSSP
	rcall	I2C_WaitforACK
	bsf		SSP1CON2,PEN				; Stop condition
	rcall	WaitMSSP
	WAITMS	.1
	bsf		SSP1CON2,SEN				; Start condition
	rcall	WaitMSSP
	movlw	0x51						; Address byte + Read bit
	movwf	SSP1BUF						; control byte
	rcall	WaitMSSP
	bsf		SSP1CON2, RCEN				; Enable receive mode
	rcall	WaitMSSP
	movff	SSP1BUF,rx_firmware+0
	bsf		SSP1CON2,ACKEN				; Master acknowledge
	rcall	WaitMSSP

	; last byte in read from RX circuity always with a NACK!
	bsf		SSP1CON2, RCEN				; Enable receive mode
	rcall	WaitMSSP
	movff	SSP1BUF,rx_firmware+1
	bsf		SSP1CON2,ACKDT
	bsf		SSP1CON2,ACKEN				; Master NOT acknowledge
	rcall	WaitMSSP
	bcf		SSP1CON2,ACKDT				; Reset ACKDT flag
	bsf		SSP1CON2,PEN				; Stop condition
	rcall	WaitMSSP

	; test for RX part not being ready during this read
	movff	rx_firmware+1,i2c_temp1
	movlw	.147
	cpfseq	i2c_temp1
	bra		I2C_probe_OSTC_rx_2			; not equal
	movff	rx_firmware+0,i2c_temp1
	movlw	.27
	cpfseq	i2c_temp1
	bra		I2C_probe_OSTC_rx_2			; not equal
	bsf		active_reset_ostc_rx
	WAITMS	.5
	bcf		active_reset_ostc_rx
	WAITMS	.250
	WAITMS	.250
	clrf	i2c_temp1
	decfsz	lo_temp,F					; try max. 5 times
	bra		I2C_probe_OSTC_rx_1
	bcf		ostc_rx_present				; Clear flag. Something is wrong
I2C_probe_OSTC_rx_2:
	clrf	i2c_temp1
	return


	global	I2C_get_tankdata
I2C_get_tankdata:
	bsf	SSP1CON2,SEN					; Start condition
	rcall	WaitMSSP
	movlw	0x50						; Address byte + Write bit
	movwf	SSP1BUF						; control byte
	rcall	WaitMSSP
	rcall	I2C_WaitforACK
	movlw	0x1E						; Read buffer2 (48 Bytes)
	movwf	SSP1BUF	; Data Byte
	rcall	WaitMSSP
	rcall	I2C_WaitforACK
	bsf		SSP1CON2,PEN				; Stop condition
	rcall	WaitMSSP
	WAITMS	.1

	; read 48 bytes
	bsf	SSP1CON2,SEN					; Start condition
	rcall	WaitMSSP
	movlw	0x51						; Address byte + read bit
	movwf	SSP1BUF						; control byte
	rcall	WaitMSSP
	rcall	I2C_WaitforACK
	movlw	.47							; 47 with ACK + 1 w/o ACK
	movwf	i2c_temp2
	lfsr	FSR2,rx_buffer+0
I2C_get_tankdata_loop_read:
	bsf	SSP1CON2, RCEN					; Enable receive mode
	rcall	WaitMSSP
	movff	SSP1BUF,POSTINC2
	bcf		SSP1CON2,ACKDT
	bsf		SSP1CON2,ACKEN				; Master acknowledge
	rcall	WaitMSSP
	decfsz	i2c_temp2,F
	bra		I2C_get_tankdata_loop_read

	; 1 w/o ACK
	bsf		SSP1CON2, RCEN				; Enable receive mode
	rcall	WaitMSSP
	movff	SSP1BUF,POSTINC2
	bsf		SSP1CON2,ACKDT
	bsf		SSP1CON2,ACKEN				; Master NOT acknowledge
	rcall	WaitMSSP
	bcf		SSP1CON2,ACKDT				; Reset ACKDT flag

	bsf		SSP1CON2,PEN				; Stop condition
	bra		WaitMSSP					;(and return)


	global	I2C_update_OSTC_rx
I2C_update_OSTC_rx:						; 992*64byte master loop
	bcf		i2c_error_flag				; clear error flag
	; write 64 bytes
	bsf		SSP1CON2,SEN				; Start condition
	rcall	WaitMSSP
	movlw	0x50						; Address byte + Write bit
	movwf	SSP1BUF						; control byte
	rcall	WaitMSSP
	rcall	I2C_WaitforACK
	lfsr	FSR2,buffer					; send buffer for verify
	movlw	.64
	movwf	i2c_temp2
I2C_update_OSTC_loop:					; 64byte flash page loop
	movff	up,POSTINC2					; store for verify
	movff	up,SSP1BUF
	rcall	WaitMSSP
	rcall	I2C_WaitforACK
	call	ext_flash_read_block		; Read one byte
	movwf	up							; prepare for transmit
	decfsz	i2c_temp2,F
	bra		I2C_update_OSTC_loop
	bsf		SSP1CON2,PEN				; Stop condition
	rcall	WaitMSSP
	WAITMS	.1

	; read 64 bytes
	bsf		SSP1CON2,SEN				; Start condition
	rcall	WaitMSSP
	movlw	0x51						; Address byte + read bit
	movwf	SSP1BUF						; control byte
	rcall	WaitMSSP
	rcall	I2C_WaitforACK
	lfsr	FSR2,buffer					; send buffer for verify
	movlw	.63							; 63 with ACK + 1 w/o ACK
	movwf	i2c_temp2
I2C_update_OSTC_loop_read:
	bsf		SSP1CON2, RCEN				; Enable receive mode
	rcall	WaitMSSP
	movf	SSP1BUF,W
	cpfseq	POSTINC2					; compare read-back with original
	bsf		i2c_error_flag				; Not equal, set flag
	bcf		SSP1CON2,ACKDT
	bsf		SSP1CON2,ACKEN				; Master acknowledge
	rcall	WaitMSSP
	decfsz	i2c_temp2,F
	bra		I2C_update_OSTC_loop_read

	; 1 w/o ACK
	bsf	SSP1CON2, RCEN					; Enable receive mode
	rcall	WaitMSSP
	movf	SSP1BUF,W
	cpfseq	POSTINC2					; compare read-back with original
	bsf		i2c_error_flag				; Not equal, set flag
	bsf		SSP1CON2,ACKDT
	bsf		SSP1CON2,ACKEN				; Master NOT acknowledge
	rcall	WaitMSSP
	bcf		SSP1CON2,ACKDT				; Reset ACKDT flag

	bsf		SSP1CON2,PEN				; Stop condition
	rcall	WaitMSSP
	WAITMS	.1

	bsf		SSP1CON2,SEN				; Start condition
	rcall	WaitMSSP
	movlw	0x50						; Address byte + Write bit
	movwf	SSP1BUF						; control byte
	rcall	WaitMSSP
	rcall	I2C_WaitforACK
	movlw	0x1F						; Write command!
	movwf	SSP1BUF						; Data Byte
	rcall	WaitMSSP
	rcall	I2C_WaitforACK
	bsf		SSP1CON2,PEN				; Stop condition
	rcall	WaitMSSP
	WAITMS	.5							; Required waiting time

	btfss	i2c_error_flag
	retlw	.0							; All ok
	retlw	.255						; an error occurred

 ENDIF

	END
