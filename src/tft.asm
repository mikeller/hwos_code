;=============================================================================
;
;   File tft.asm													## V2.99c
;
;   Managing the TFT screen
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;  2011-05-24 : [jDG] Cleanups from initial Matthias code.

#include "hwos.inc"
#include "wait.inc"
#include "varargs.inc"
#include "external_flash.inc"
#include "tft_outputs.inc"
#include "eeprom_rs232.inc"

;=============================================================================
; Basic bit-level macros

RD_H	macro
		bsf tft_rd,0
		endm

RD_L	macro
		bcf tft_rd,0
		endm

RS_H	macro
		bsf tft_rs,0
		endm

RS_L	macro
		bcf tft_rs,0
		endm

NCS_H	macro
		bsf tft_cs,0
		endm

NCS_L	macro
		bcf tft_cs,0
		endm

WR_H	macro
		bsf tft_nwr,0
		endm

WR_L	macro
		bcf tft_nwr,0
		endm

;=============================================================================
; Byte-level macros

Index_out		macro low_b
				movlw low_b
				rcall TFT_CmdWrite
				endm

Parameter_out	macro high_b, low_b
				movlw high_b
				movwf PORTA			; upper
				movlw low_b
				rcall TFT_DataWrite
				endm


tft		CODE

;;=============================================================================
;; TFT_write_flash_image
;;
;; Inputs:  FSR2 = EEPROM address / 256
;;          win_left, win_top : image CENTER position
;; Outputs: win_height, win_width.
;;          image copied on screen.
;; Trashed: PROD, hi, lo
;;
;	global	TFT_write_flash_image
;TFT_write_flash_image:
;	; Get back the full 24bit EEPROM address
;	clrf	ext_flash_address+0
;	movff	FSR2L,ext_flash_address+1
;	movf	FSR2H,W
;	iorlw	0x30
;	movwf	ext_flash_address+2
;
;	; Read header: width and height
;	global	TFT_write_flash_image_addr
;TFT_write_flash_image_addr:
;	call	ext_flash_read_block_start
;	movff	SSP2BUF,win_width+0
;	movwf	SSP2BUF					; write to buffer to initiate new read
;	btfss	SSP2STAT, BF			; next byte ready ?
;	bra		$-2						; NO - wait...
;	movff	SSP2BUF,win_width+1
;	movwf	SSP2BUF					; write to buffer to initiate new read
;	btfss	SSP2STAT, BF			; next byte ready ?
;	bra		$-2						; NO - wait...
;	movff	SSP2BUF,win_height
;	movwf	SSP2BUF					; write to buffer to initiate new read
;	btfss	SSP2STAT, BF			; next byte ready ?
;	bra		$-2						; NO - wait...
;	movff   SSP2BUF,WREG			; drop 4th byte
;	movwf	SSP2BUF					; write to buffer to initiate new read
;	btfss	SSP2STAT, BF			; next byte ready ?
;	bra		$-2						; NO - wait...
;
;	; Sanity check on header to avoid badly uploaded images.
;	iorwf	WREG					; check height < 256
;	bnz		TFT_write_flash_image_failed
;	movf	win_width+1,W			; check width < 512
;	andlw	0xFE
;	bnz		TFT_write_flash_image_failed
;
;	; Center image on win_top, win_left values
;	bcf		STATUS,C				; clear carry
;	rrcf	win_height,W			; and get height/2
;	subwf	win_top,F				; top -= height/2
;	rrcf	win_width+1,W			; get 9th bit into carry
;	rrcf	win_width+0,W			; get width/2 (in 0..320 range)
;	bcf		STATUS,C
;	rrcf	WREG,W					; get width/2 in 0..160 range
;	subwf	win_leftx2,F			; left -= width/2
;
;	rcall	TFT_box_write			; inputs : win_top, win_leftx2, win_height, win_width (in 1..320 range)
;
;	; Compute number of pixels to move (result on 17 bits !)
;	clrf	TBLPTRU
;	movf	win_width+0,W
;	mulwf	win_height				; result in PRODL:H
;	movf	win_width+1,W
;	bz		TFT_write_flash_image_1	; width > 8bits ?
;	movf	win_height,W			; YES - add extra
;	addwf	PRODH,F
;	rlcf	TBLPTRU					; and carry into upper register
;TFT_write_flash_image_1:
;	incf	PRODH,F					; pre-condition nested loops
;	incf	TBLPTRU,F
;
;	; Write pixels
;	Index_out 0x22					; frame memory data write start
;	RS_H							; data
;
;TFT_write_flash_image_loop:
;	btfss	SSP2STAT, BF			; buffer full?
;	bra		$-2						; NO - wait...
;	movff	SSP2BUF,PORTH			; read lo
;	movwf	SSP2BUF					; write to buffer to initiate new read
;
;	btfss	SSP2STAT, BF			; buffer full?
;	bra		$-2						; NO - wait...
;	movff	SSP2BUF,PORTA			; and read hi
;	movwf	SSP2BUF					; write to buffer to initiate new read
;	WR_L
;	WR_H							; write 1 pixel
;
;	decfsz	PRODL,F
;	bra		TFT_write_flash_image_loop
;	decfsz	PRODH,F
;	bra		TFT_write_flash_image_loop
;	decfsz	TBLPTRU,F
;	bra		TFT_write_flash_image_loop
;
;	btfss	SSP2STAT, BF			; buffer full?
;	bra		$-2						; NO - wait
;	movf	SSP2BUF,W				; read dummy byte
;
;	bsf		flash_ncs				; CS=1
;	movlw	0x00					; NOP, to stop window mode
;	bra		TFT_CmdWrite			; this routine "returns"
;
;	;---- Draw a 4x4 red square in place of missing images...
;TFT_write_flash_image_failed:
;	movlw	-1
;	addwf	win_leftx2,F
;	movlw	-2
;	addwf	win_top,F
;	movlw	2
;	movwf	win_width+0
;	clrf	win_width+1
;	movlw	4
;	movwf	win_height
;	movlw	color_red
;	rcall	TFT_set_color
;	goto	TFT_box
;
;;=============================================================================

	global	TFT_CmdWrite
TFT_CmdWrite:
	RS_L							; command
	clrf	PORTA					; upper
	bcf		INTCON,GIE
	movwf	PORTH					; lower
	WR_L
	WR_H							; tick
	bsf		INTCON,GIE
	return

	global	TFT_DataWrite
TFT_DataWrite:
	RS_H							; data
	bcf		INTCON,GIE
	movwf 	PORTH					; lower
	WR_L
	WR_H							; tick
	bsf		INTCON,GIE
	return

;=============================================================================

	global	TFT_ClearScreen
TFT_ClearScreen:
	Index_out 0x50					; window horizontal start address
	Parameter_out 0x00, 0x00		; 0-239
	Index_out 0x51					; window horizontal end   address
	Parameter_out 0x00, 0xEF		; 0-239
	Index_out 0x52					; window vertical   start address
	Parameter_out 0x00, 0x00		; 0-319
	Index_out 0x53					; window vertical   end   address
	Parameter_out 0x01, 0x3F		; 0-319
	Index_out 0x20					; frame memory horizontal address
	Parameter_out 0x00, 0x00		; 0-239
	Index_out 0x21					; frame memory vertical   address
	Parameter_out 0x01, 0x3F		; 0-319

	Index_out 0x22					; frame memory data write start

	RD_H							; not read
	RS_H							; data
	NCS_L							; not CS
	clrf	PORTH					; data lower

	movlw	d'10'
	movwf	tft_temp3
TFT_ClearScreen2:
	movlw	d'30'
	movwf	tft_temp2
TFT_ClearScreen3:
	clrf	tft_temp1				; 30*10*256=76800 pixels -> clear complete 240*320
	bcf		INTCON,GIE
TFT_ClearScreen4:
	WR_L
	WR_H							; tick
	decfsz	tft_temp1,F
	bra		TFT_ClearScreen4
	bsf		INTCON,GIE
	decfsz	tft_temp2,F
	bra		TFT_ClearScreen3
	decfsz	tft_temp3,F
	bra		TFT_ClearScreen2

	movlw	0x00					; NOP, to stop window mode
	bra		TFT_CmdWrite			; and return


;=============================================================================

	global	TFT_DisplayOff
TFT_DisplayOff:
	clrf	CCPR1L					; PWM OFF
	clrf	PORTA
	clrf	PORTH
	RD_L							; LOW
	nop
	RS_L							; LOW
	bcf		tft_nwr
	nop
	bcf		tft_cs
	nop
	bcf		tft_nreset
	WAITMS	d'1'
	bsf		tft_power				; inverted...
	bcf		lightsen_power  		; power-down light sensor
	return

; -----------------------------
; TFT boot
; -----------------------------

	global	TFT_boot
TFT_boot:
	clrf	PORTA
	clrf	PORTH
	RD_L	; LOW
	bcf		tft_nwr
	nop
	bcf		tft_cs
	nop
	bcf		tft_nreset
	WAITMS	d'1'
	bcf		tft_power				; inverted...
	WAITMS	d'1'

	RD_H	; Keep high
	WR_H	;
	NCS_L	; Not CS

	WAITMS	d'2'
	bsf		tft_nreset
	WAITMS	d'5'
	bcf		tft_nreset
	WAITMS	d'5'
	bsf		tft_nreset
	WAITMS	d'150'
	bsf		lightsen_power			; supply power to light sensor

	; Data Transfer Synchronization
	Parameter_out 0x00, 0x00
	Parameter_out 0x00, 0x00

	; Get screentype from Bootloader-Info
	movlw	0x7B
	movwf	TBLPTRL
	movlw	0xF7
	movwf	TBLPTRH
	movlw	0x01
	movwf	TBLPTRU
	TBLRD*+							; reads .110 for cR and USB OSTC3, .0 for BLE (2 and 3), and .2 for display1 OSTC
	movlw	0x02
	cpfseq	TABLAT
	bra		TFT_boot_0				; display0

TFT_boot_1:
	; Init through config table...
	movlw	0x74
	movwf	TBLPTRL
	movlw	0xF7
	movwf	TBLPTRH
	movlw	0x01
	movwf	TBLPTRU
	bsf		screen_type
	bra		TFT_boot_com

TFT_boot_0:
	; Init through config table...
	movlw	LOW   display0_config_table
	movwf	TBLPTRL
	movlw	HIGH  display0_config_table
	movwf	TBLPTRH
	movlw	UPPER display0_config_table
	movwf	TBLPTRU
	bcf		screen_type

TFT_boot_com:
	rcall	display0_init_loop

	Index_out 0x03
	btfsc	flip_screen				; 180° rotation ?
	bra		TFT_boot2				; YES

	btfss	screen_type				; display1?
	bra		TFT_boot1a				; NO
	Parameter_out 0x10, 0x00		; display1
	bra		TFT_boot3
TFT_boot1a:
	Parameter_out 0x50, 0x20		; display0
	bra		TFT_boot3
TFT_boot2:
	btfss	screen_type				; display1?
	bra		TFT_boot2a				; NO
	Parameter_out 0x10, 0x30		; display1
	bra		TFT_boot3
TFT_boot2a:
	Parameter_out 0x50, 0x10		; display0
TFT_boot3:
	Index_out 0x22
	rcall	TFT_ClearScreen
	Index_out 0x07
	Parameter_out 0x01, 0x33
	return

display0_config_table:
	; Reg, Dat0, Dat1 or 0xFF,0x00,0x00 for end
	db  0xA4,0x00,0x01,0xFF,.002,0x00
	db  0x09,0x00,0x01,0x92,0x04,0x00
	db  0x93,0x04,0x02,0x94,0x00,0x02
	db  0x07,0x00,0x00,0x10,0x04,0x30
	db  0x11,0x02,0x37,0x12,0x11,0x8D
	db  0x13,0x11,0x00,0x01,0x01,0x00
	db  0x02,0x02,0x00,0x03,0x50,0x20
	db  0x0A,0x00,0x08,0x0D,0x00,0x00
	db  0x0E,0x00,0x30,0xFF,.151,0x00
	db  0x12,0x11,0xBD,0x20,0x00,0x00
	db  0x21,0x00,0x00,0x30,0x06,0x02
	db  0x31,0x56,0x0D,0x32,0x05,0x07
	db  0x33,0x06,0x09,0x34,0x00,0x00
	db  0x35,0x09,0x06,0x36,0x57,0x05
	db  0x37,0x0D,0x06,0x38,0x02,0x06
	db  0x39,0x00,0x00,0xFF,0x00,0x00

display0_init_loop:
	TBLRD*+
	movlw	0xFF
	cpfseq	TABLAT
	bra		display0_config_write	; write config pair to display
	; Delay ms or quit (return)
	TBLRD*+
	tstfsz	TABLAT					; end of config?
	bra		$+4						; NO
	return							; YES - done
	movf	TABLAT,W
	call	WAITMSX					; wait WREG milliseconds
	TBLRD*+							; dummy read (Third byte of delay command)
	bra		display0_init_loop		; loop

display0_config_write:				; with command in WREG
	movf	TABLAT,W
	rcall	TFT_CmdWrite			; write command
	TBLRD*+							; get config0
	movff	TABLAT,PORTA
	TBLRD*+							; get config1
	movf	TABLAT,W
	rcall	TFT_DataWrite			; write config
	bra		display0_init_loop		; loop


;=============================================================================
; Smooth lighting-up of the display:
;
; Trashes: WREG, PRODL
; Typical usage:
;	clrf	CCPR1L					; backlight off
;	[draw splash screen]
;	call	TFT_DisplayFadeIn

	global	TFT_Display_FadeIn
TFT_Display_FadeIn:
	movlw	CCP1CON_VALUE			; see hwos.inc
	movwf	CCP1CON
	bsf		tft_is_dimming			; TFT is dimming, ignore ambient sensor
	clrf	CCPR1L					; backlight off - to be sure
	movff	max_CCPR1L,PRODL
TFT_Display_FadeIn_0:
	incf	CCPR1L,F				; duty cycle
	WAITMS	d'2'
	decfsz	PRODL,F
	bra		TFT_Display_FadeIn_0 
	bcf		tft_is_dimming			; dimming done
	return

;=============================================================================
; Smooth lighting-off of the display:
; Trashes: WREG, PRODL

	global	TFT_Display_FadeOut
TFT_Display_FadeOut:
	movff	max_CCPR1L,PRODL
	bsf		tft_is_dimming			; TFT is dimming, ignore ambient sensor
TFT_Display_FadeOut_0:
	movff	PRODL,CCPR1L			; duty cycle
	WAITMS	d'1'
	decfsz	PRODL,F
	bra		TFT_Display_FadeOut_0 
	clrf	CCPR1L
	return

;=============================================================================

	global	box_std_block, box_black_block, box_color_block

box_std_block:						; use white color
	setf	WREG
	bra	box_common
box_black_block:					; use black color
	clrf	WREG
box_common:
box_color_block:
	rcall	TFT_set_color
	VARARGS_BEGIN
	VARARGS_GET8 win_top
	VARARGS_GET8 win_height
	VARARGS_GET8 win_leftx2
	VARARGS_GET8 win_width
	VARARGS_END
	bra		TFT_box

;-----------------------------------------------------------------------------

	global	box_frame_std, box_frame_common, box_frame_color, box_frame_color16

box_frame_std:
	setf	WREG
	rcall	TFT_set_color
box_frame_common:
	VARARGS_BEGIN
	VARARGS_GET8 win_top
	VARARGS_GET8 win_height
	VARARGS_GET8 win_leftx2
	VARARGS_GET8 win_width
	VARARGS_END
	bra		TFT_frame
box_frame_color:
	rcall	TFT_set_color
box_frame_color16:
	bra		box_frame_common

;;=============================================================================
;; Init for half_pixel_write
;; Set column register on TFT device, and current color.
;; Inputs: win_leftx2
;; Outputs: win_color:2
;; Trashed: WREG, PROD
;
;	global	init_pixel_write
;init_pixel_write:
;	movf	win_leftx2,W
;	mullw	2
;	rcall	pixel_write_col320		; start address vertical (.0 - .319)
;	setf	WREG
;	bra	TFT_set_color

;-----------------------------------------------------------------------------
; Writes two half-pixels at position (win_top,win_leftx2)
; Inputs: win_leftx2, win_top, win_color:2
; Trashed: WREG, PROD

	global	pixel_write
pixel_write:
	movf	win_leftx2,W
	mullw	2						; win_leftx2 x 2 -> PRODH:PRODL
	rcall	pixel_write_col320		; start address vertical (.0 - .319)
	rcall	half_pixel_write		; write this half-one
	movf	win_leftx2,W			; address of next one
	mullw	2
	infsnz	PRODL					; +1
	incf	PRODH
	rcall	pixel_write_col320
	bra		half_pixel_write		; note: Cmd 0x20 is mandatory, because
									; of the auto-increment going vertical

	global	pixel_write_col320
pixel_write_col320:
	btfsc	screen_type				; display1?
	bra		pixel_write_col320_d1	; YES
	; Display0
	btfss	flip_screen				; 180° rotation?
	bra		pixel_write_noflip_H	; NO
	bra		pixel_write_flip_H		; YES
pixel_write_col320_d1:				; Display1
	btfsc	flip_screen				; 180° rotation?
	bra	pixel_write_noflip_H		; YES for d1
pixel_write_flip_H:					; flip d0
	movf	PRODL,W					; 16 bits 319 - PROD --> PROD
	sublw	LOW(.319)				; 319-W --> W
	movwf	PRODL
	movf	PRODH,W
	btfss	STATUS,C				; borrow = /CARRY
	incf	WREG
	sublw	HIGH(.319)
	movwf	PRODH

pixel_write_noflip_H:
	Index_out 0x21					; frame memory vertical address
	bra		TFT_DataWrite_PROD		; and return...

;-----------------------------------------------------------------------------
; Writes one half-pixel at position (win_top,win_leftx2).
; Inputs: win_leftx2, win_top, win_color:2
; Trashed: WREG, PROD

	global	half_pixel_write
half_pixel_write:
	movf	win_top,W				; d'0' ... d'239'
	; Variant with Y position in WREG.
half_pixel_write_1:
	btfss	flip_screen				; 180° rotation?
	sublw	.239					; 239-Y --> Y
	mullw	.1						; copy row to PRODL (PRODH=0)
	Index_out 0x20					; frame memory horizontal address
	rcall	TFT_DataWrite_PROD

	Index_out 0x22					; frame memory data write start
	RS_H							; data
	bcf		INTCON,GIE
	movff	win_color1,PORTA		; upper
	movff	win_color2,PORTH		; lower
	WR_L
	WR_H							; tick
	bsf		INTCON,GIE
	return

;-----------------------------------------------------------------------------
; Writes a vertical line of half-pixel at position (win_top,win_leftx2,win_height).
; Inputs: win_leftx2, win_top, win_height, win_color:2
; Trashed: WREG, PROD, TABLAT, TBLPTRL

	global	half_vertical_line
half_vertical_line:
	clrf	TABLAT					; loop index

half_vertical_line_loop:
	movf	win_leftx2,W			; init X position
	mullw	.2
	movf	TABLAT,W				; get loop index
	andlw	.1						; just low bit
	xorwf	PRODL,F					; and use it to jitter current X position
	rcall	pixel_write_col320		; start address vertical (.0 - .319)

	movf	win_height,W			; index reached height (bank0 read) ?
	xorwf	TABLAT,W
	btfsc	STATUS,Z				; Equal ?
	return							; YES - done
	movf	win_top,W				; Y = top + index (bank0 read)
	addwf	TABLAT,W
	rcall	half_pixel_write_1
	incf	TABLAT,F				; index++
	bra		half_vertical_line_loop

;-----------------------------------------------------------------------------
; Writes a horizontal line of half-pixel at position (win_top,win_leftx2,win_width).
; Inputs: win_leftx2, win_top, win_width, win_color:2
; Trashed: WREG, PROD, TABLAT, TBLPTRL

	global	half_horizontal_line
half_horizontal_line:
	clrf	TABLAT					; loop index

half_horizontal_line_loop:
	movf	win_leftx2,W			; init X position
	mullw	.2
	rcall	pixel_write_col320		; start address vertical (.0 - .319)
	movf	win_width,W				; index reached height (bank0 read) ?
	xorwf	TABLAT,W
	btfsc	STATUS,Z				; equal ?
	return							; YES - done
	movf	win_top,W				; Y = top + index (bank0 read)
	addwf	TABLAT,W
	rcall	half_pixel_write_1
	incf	TABLAT,F				; index++
	bra		half_horizontal_line_loop


;-----------------------------------------------------------------------------
; TFT Data Cmd via W

	global	TFT_DataWrite_PROD
TFT_DataWrite_PROD:
;	RD_H							; keep high
	RS_H							; data
	bcf		INTCON,GIE
	movff	PRODH,PORTA				; move high byte to PORTA
	movff	PRODL,PORTH				; move low byte to PORTH
	WR_L
	WR_H							; tick
	bsf		INTCON,GIE
	return

TFT_DataRead_PROD:
	Index_out 0x22					; frame memory data read start
TFT_CmdRead_PROD:
	setf	TRISA					; port A as input
	setf	TRISH					; port H as input
	RS_H							; data
	WR_H							; not write
	RD_L							; read
	nop
	nop
	nop
	RD_H							; tick
	nop
	nop
	nop
	RD_L							; read
	nop
	;nop
	;nop
	movff	PORTA,PRODH
	movff	PORTH,PRODL
	RD_H							; tick
	nop
	clrf	TRISA					; port A as output
	clrf	TRISH					; port H as output
	return

;=============================================================================
; Output TFT Window Address commands
; Inputs : win_top, win_leftx2, win_height, win_width
; Output : PortA/PortH commands
; Trashed: PROD

	global	TFT_box_write
TFT_box_write:
	movf	win_leftx2,W			; compute left = 2 * leftx2 --> PROD
	mullw	2

	global	TFT_box_write_16bit_win_left
TFT_box_write_16bit_win_left:					; Wwth column in PRODL:PRODH
	btfsc	screen_type							; display1?
	bra		TFT_box_write_16bit_win_left_d1		; YES
	; Display0
	btfsc	flip_screen							; 180° rotation?
	bra		DISP_box_flip_H						; YES
	bra		TFT_box_write_16bit_win_left_com	; NO
TFT_box_write_16bit_win_left_d1:				; Display1
	btfss	flip_screen							; 180° rotation?
	bra		DISP_box_flip_H						; NO for d1
	; Yes for d1
TFT_box_write_16bit_win_left_com:
	;---- Normal horizontal window ---------------------------------------
	Index_out 0x52					; window vertical start address
	rcall	TFT_DataWrite_PROD		; output left
	Index_out 0x21					; frame memory vertical address
	rcall	TFT_DataWrite_PROD		; output left

	movf	win_width+0,W			; right = left + width - 1
	addwf	PRODL,F
	movf	win_width+1,W
	addwfc	PRODH,F
	decf	PRODL,F					; decrement result
	btfss	STATUS,C
	decf	PRODH,F

	Index_out 0x53					; window vertical end address
	rcall	TFT_DataWrite_PROD
	bra		DISP_box_noflip_H

	;---- Flipped horizontal window --------------------------------------
DISP_box_flip_H:
	movf	PRODL,W					; 16 bits 319 - PROD --> PROD
	sublw	LOW(.319)				; 319 - WREG --> WREG
	movwf	PRODL
	movf	PRODH,W
	btfss	STATUS,C				; borrow = /CARRY
	incf	WREG
	sublw	HIGH(.319)
	movwf	PRODH

	Index_out 0x53					; window vertical start address
	rcall	TFT_DataWrite_PROD		; output left
	Index_out 0x21					; frame memory vertical address
	rcall	TFT_DataWrite_PROD		; output left

	movf	win_width+0,W			; 16 bits PROD - width --> PROD
	subwf	PRODL,F					; PRODL - WREG --> PRODL
	movf	win_width+1,W
	subwfb	PRODH,F
	infsnz	PRODL					; PROD + 1 --> PROD
	incf	PRODH

	Index_out 0x52					; window vertical end address
	rcall	TFT_DataWrite_PROD

DISP_box_noflip_H:
	btfss	flip_screen				; 180° rotation ?
	bra		TFT_box_noflip_V		; NO

	;---- Flipped vertical window -----------------------------------------
	movff	win_top,PRODH			; top --> PRODH (first byte)
	movf	win_height,W
	addwf	PRODH,W
	decf	WREG
	movwf	PRODL					; top + height - 1 --> PRODL (second byte)

	Index_out 0x50					; window horizontal start address
	movf	PRODH,W
	rcall	TFT_DataWrite			; lower (and tick)

	Index_out 0x51					; window horizontal end address
	movf	PRODL,W
	rcall	TFT_DataWrite			; lower (and tick)

	Index_out 0x20					; frame memory horizontal address
	movf	PRODH,W
	bra		TFT_DataWrite			; lower (and tick) and return

TFT_box_noflip_V:
	;---- Normal vertical window ----------------------------------------
	movff	win_top,PRODL
	movf	win_height,W
	addwf	PRODL,W
	sublw	.240					; 240 - top - height
	movwf	PRODH					; first byte

	movf	PRODL,W
	sublw	.239					; 239 - top
	movwf	PRODL					; --> second byte

	Index_out 0x50					; window horizontal start address
	movf	PRODH,W
	rcall	TFT_DataWrite			; lower (and tick)

	Index_out 0x51					; window horizontal end address
	movf	PRODL,W
	rcall	TFT_DataWrite			; lower (and tick)

	Index_out 0x20					; frame memory horizontal address
	movf	PRODL,W
	bra		TFT_DataWrite			; lower (and tick) and return


;=============================================================================
; TFT_frame : draw a frame around current box with current color
; Inputs:  win_top, win_leftx2, win_height, win_width, win_color1, win_color2
; Outputs: (none)
; Trashed: WREG, PROD, aa_start:2, aa_end:2

	global	TFT_frame
TFT_frame:
	movff	win_top,save_top		; backup everything
	movff	win_height,save_height
	movff	win_leftx2,save_left
	movff	win_width,save_width

	;---- TOP line -----------------------------------------------------------
	movlw	.1						; row ~ height = 1
	movwf	win_height
	rcall	TFT_box

	;---- BOTTOM line --------------------------------------------------------
	movff	save_top,PRODL			; get back top
	movff	save_height,WREG		; get back height
	addwf	PRODL,W					; top + height
	decf	WREG					; top + height - 1
	movwf	win_top					; top + height - 1 --> top
	rcall	TFT_box

	;---- LEFT column --------------------------------------------------------
	movff	save_top,win_top		; restore top/height
	movff	save_height,win_height
	movlw	.1						; column ~ width = 1
	movwf	win_width+0
	rcall	TFT_box

	;---- RIGHT column -------------------------------------------------------
	movff	save_left,WREG
	movff	save_width,PRODL
	addwf	PRODL,W
	decf	WREG
	movwf	win_leftx2
	rcall	TFT_box

	;---- Restore everything -------------------------------------------------
	movff	save_left,win_leftx2
	movff	save_width,win_width
	return

;=============================================================================
; TFT_box: fills current box with current color
; Inputs : win_top, win_leftx2, win_height, win_width, win_color1, win_color2
; Outputs: (none)
; Trashed: WREG, PROD

	global	TFT_box
TFT_box:
	;---- Define Window ------------------------------------------------------
	bcf		STATUS,C
	rlcf	win_width+0,F
	rlcf	win_width+1,F			; x2
	rcall	TFT_box_write			; setup box

	global	TFT_box_16bit_win_left
TFT_box_16bit_win_left:
	bcf		STATUS,C
	rrcf	win_width+1,F			; width /= 2
	rrcf	win_width+0,F

	;---- Fill Window --------------------------------------------------------
	Index_out 0x22					; frame memory data write start

	clrf	PRODH					; column counter
	RS_H							; data

TFT_box2:							; loop height times
	movff	win_height,PRODL

TFT_box3:							; loop width times
	bcf	INTCON,GIE
	movff	win_color1,PORTA		; upper
	movff	win_color2,PORTH		; lower
	WR_L
	WR_H							; tick

;	movff	win_color1,PORTA		; upper
;	movff	win_color2,PORTH		; lower
	WR_L
	WR_H							; tick
	bsf		INTCON,GIE
	decfsz	PRODL,F					; row loop finished ?
	bra		TFT_box3				; NO - continue

	incf	PRODH,F					; column count ++

	movf	win_bargraph,W			; current column == bargraph ?
	cpfseq	PRODH
	bra		TFT_box4				; NO  - just loop
	clrf	win_color1				; Yes - switch to black
	clrf	win_color2				;     - ...
TFT_box4:
	movf	win_width+0,W			; compare ?
	xorwf	PRODH,W
	bnz		TFT_box2				; Loop not finished

	movlw	0x00					; NOP, to stop window mode
	rcall	TFT_CmdWrite

	; reset bargraph mode...
	setf	win_bargraph
	return

;=============================================================================
; Converts 8 bit RGB b'RRRGGGBB' into 16 bit RGB b'RRRRRGGGGGGBBBBB'

	global	TFT_set_color
TFT_set_color:
	movwf	tft_temp1				; get 8 Bit RGB b'RRRGGGBB'
	movwf	tft_temp2				; copy

	; mask bit 7,6,5,4,3,2
	movlw	b'00000011'
	andwf	tft_temp2,F

	movlw	b'00000000'
	dcfsnz	tft_temp2,F
	movlw	b'01010000'
	dcfsnz	tft_temp2,F
	movlw	b'10100000'
	dcfsnz	tft_temp2,F
	movlw	b'11111000'
	movwf	tft_temp3				; blue done

	movff	tft_temp1,tft_temp2		; copy
	; mask bit 7,6,5,1,0
	movlw	b'00011100'
	andwf	tft_temp2,F
	rrncf	tft_temp2,F
	rrncf	tft_temp2,F

	movlw	b'00000000'
	dcfsnz	tft_temp2,F
	movlw	b'00000100'
	dcfsnz	tft_temp2,F
	movlw	b'00001000'
	dcfsnz	tft_temp2,F
	movlw	b'00001100'
	dcfsnz	tft_temp2,F
	movlw	b'00010000'
	dcfsnz	tft_temp2,F
	movlw	b'00010100'
	dcfsnz	tft_temp2,F
	movlw	b'00100000'
	dcfsnz	tft_temp2,F
	movlw	b'00111111'
	movwf	tft_temp4

	rrcf	tft_temp4,F
	rrcf	tft_temp3,F

	rrcf	tft_temp4,F
	rrcf	tft_temp3,F

	rrcf	tft_temp4,F
	rrcf	tft_temp3,W				; tft_temp3 (b'GGGBBBBB') done
	movwf	win_color2				; set color registers...

	movff	tft_temp1,tft_temp2		; copy
	clrf	tft_temp1

	rrcf	tft_temp4,F
	rrcf	tft_temp1,F

	rrcf	tft_temp4,F
	rrcf	tft_temp1,F

	rrcf	tft_temp4,F
	rrcf	tft_temp1,F				; green done

	; mask bit 4,3,2,1,0
	movlw	b'11100000'
	andwf	tft_temp2,F

	rrncf	tft_temp2,F
	rrncf	tft_temp2,F
	rrncf	tft_temp2,F
	rrncf	tft_temp2,F
	rrncf	tft_temp2,F

	movlw	b'00000000'
	dcfsnz	tft_temp2,F
	movlw	b'00000100'
	dcfsnz	tft_temp2,F
	movlw	b'00001000'
	dcfsnz	tft_temp2,F
	movlw	b'00001100'
	dcfsnz	tft_temp2,F
	movlw	b'00010000'
	dcfsnz	tft_temp2,F
	movlw	b'00010100'
	dcfsnz	tft_temp2,F
	movlw	b'00100000'
	dcfsnz	tft_temp2,F
	movlw	b'00111111'
	movwf	tft_temp4

	rrcf	tft_temp4,F
	rrcf	tft_temp1,F

	rrcf	tft_temp4,F
	rrcf	tft_temp1,F

	rrcf	tft_temp4,F
	rrcf	tft_temp1,F

	rrcf	tft_temp4,F
	rrcf	tft_temp1,F

	rrcf	tft_temp4,F
	rrcf	tft_temp1,W				; red done
	movwf	win_color1				; set color registers
	return

;=============================================================================
; Dump screen contents to the UART

 IFDEF _screendump

	global	TFT_dump_screen_check
	global	TFT_dump_screen
TFT_dump_screen_check:
	btfss	vusb_in					; USB (still) plugged in?
	bcf		enable_screen_dumps		; NO - clear flag
	call	rs232_get_byte			; try to read data from RS232
	btfsc	rs232_receive_overflow	; anything received?
	return							; NO  - return
	movlw	"l"						; YES - load coding for screendump command
	cpfseq	RCREG1					;       screendump command received?
	return							;       NO  - return
TFT_dump_screen:					;       YES
	bsf		no_sensor_int
	movlw	'l'
	movwf	TXREG					; send command echo
	call	rs232_wait_tx			; wait for UART

	;---- Send DISPLAY box command for the full screen window -------------------
	Index_out 0x50					; window horizontal start address
	Parameter_out 0x00, 0x00		; 0-239
	Index_out 0x51					; window horizontal end   address
	Parameter_out 0x00, 0xEF		; 0-239
	Index_out 0x52					; window vertical   start address
	Parameter_out 0x00, 0x00		; 0-319
	Index_out 0x53					; window vertical   end   address
	Parameter_out 0x01, 0x3F		; 0-319

	clrf	ds_column
	rcall	dump_screen_pixel_reset
dump_screen_1:
	btg		LEDr					; LED activity toggle
	; Dump even column
	movlw	.240					; 240 lines, once
	movwf	ds_line
dump_screen_2:
	Index_out	0x20				; frame memory horizontal address
	movff	ds_line,WREG			; d'0' ... d'239'
	mullw	.1						; copy row to PRODH:L
	rcall	TFT_DataWrite_PROD

	movff	ds_column,WREG			; Init X position
	mullw	2
	rcall	pixel_write_col320		; start address vertical (.0 - .319)

	rcall	TFT_DataRead_PROD		; read pixel
	rcall	dump_screen_pixel

	decfsz	ds_line,F
	bra		dump_screen_2
	rcall	dump_screen_pixel_flush

	; Dump odd column
	movlw	.240					; 240 lines, twice
	movwf	ds_line
dump_screen_3:
	Index_out	0x20				; frame memory horizontal address
	movff	ds_line,WREG			; d'0' ... d'239'
	mullw	1						; copy row to PRODH:L
	rcall	TFT_DataWrite_PROD

	movff	ds_column,WREG			; init X position
	mullw	2
	movlw	.1
	addwf	PRODL,F
	movlw	0
	addwfc	PRODH,F					; +1
	rcall	pixel_write_col320		; start address vertical (.0 - .319)

	rcall	TFT_DataRead_PROD		; read pixel
	rcall	dump_screen_pixel

	decfsz	ds_line,F
	bra		dump_screen_3
	rcall	dump_screen_pixel_flush

	incf	ds_column,F
	movlw	.160
	cpfseq	ds_column
	bra		dump_screen_1

	bcf		no_sensor_int
	clrf	RCREG1					; clear receive buffer
	bcf		RCSTA1,CREN				; clear receiver status
	bsf		RCSTA1,CREN
	bsf		enable_screen_dumps		; =1: Ignore vin_usb, wait for "l" command (screen dump)
	return

 ENDIF


;=============================================================================
; Pixel compression
;
; Input : PRODH:L = pixel
; Output: Compressed stream on output.
; Compressed format:
;       0ccccccc          : BLACK pixel,      repeated ccccccc+1 times (1..128)
;       11cccccc          : WHITE pixel,      repeated  cccccc+1 times (1.. 64)
;       10cccccc HIGH LOW : color pixel (H:L) repeated   ccccc+1 times (1.. 64)

 IFDEF _screendump

dump_screen_pixel:
	movf	PRODH,W					; compare pixel-high
	xorwf	ds_pixel+1,W
	bnz		dump_screen_pixel_1		; different -> dump

	movf	PRODL,W					; compare pixel-low
	xorwf	ds_pixel+0,W
	bnz		dump_screen_pixel_1		; different -> dump

	incf	ds_count,F				; same color: just increment
	return

dump_screen_pixel_1:				; send (pixel,count) tuple
	movf	ds_count,W				; is count zero ?
	bz		dump_screen_pixel_2		; YES - skip sending

	movf	ds_pixel+1,W			; is this a BLACK pixel ?
	iorwf	ds_pixel+0,W
	bz		dump_screen_pix_black	; YES

	movf	ds_pixel+1,W			; is this a white pixel ?
	andwf	ds_pixel+0,W
	incf	WREG
	bz		dump_screen_pix_white	; YES

	; No: write the pixel itself...
	movlw	.64						; max color pixel on a single byte
	cpfsgt	ds_count				; skip if count > 64
	movf	ds_count,W				; W <- min(64,count)
	subwf	ds_count,F				; ds_count <- ds_count-W
	decf	WREG					; save as 0..63
	iorlw	b'10000000'				; mark as a color pixel

	movwf	TXREG
	call	rs232_wait_tx			; wait for UART
	movff	ds_pixel+1,TXREG
	call	rs232_wait_tx			; wait for UART
	movff	ds_pixel+0,TXREG
	call	rs232_wait_tx			; wait for UART
	bra		dump_screen_pixel_1

dump_screen_pixel_2:
	movff	PRODH,ds_pixel+1		; save new pixel color
	movff	PRODL,ds_pixel+0
	movlw	1
	movwf	ds_count				; and set count=1
	return

dump_screen_pix_black:
	movlw	.128					; max black pixel on a single byte
	cpfsgt	ds_count				; skip if count > 128
	movf	ds_count,W				; W <- min(128,count)
	subwf	ds_count,F				; ds_count <- ds_count-W
	decf	WREG					; save as 0..127
dump_screen_pix_3:
	movwf	TXREG
	call	rs232_wait_tx
	bra		dump_screen_pixel_1		; more to dump ?

dump_screen_pix_white:
	movlw	.64						; max white pixel on a single byte
	cpfsgt	ds_count				; skip if count > 64
	movf	ds_count,W				; W <- min(64,count)
	subwf	ds_count,F				; ds_count <- ds_count-W
	decf	WREG					; Save as 0..63
	iorlw	b'11000000'				; mark as a compressed white
	bra		dump_screen_pix_3

dump_screen_pixel_flush:
	clrf	PRODH
	clrf	PRODL
	rcall	dump_screen_pixel_1		; send it
dump_screen_pixel_reset:
	clrf	ds_count				; clear count
	return

 ENDIF

	END
