;=============================================================================
;
;   File tft.asm                              combined next generation V3.09.4n
;
;   low-level Display Outputs
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;  2011-05-24 : [jDG] Cleanups from initial Matthias code.

#include "hwos.inc"
#include "wait.inc"
#include "varargs.inc"
#include "tft_outputs.inc"
#include "eeprom_rs232.inc"

;-----------------------------------------------------------------------------
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

;-----------------------------------------------------------------------------
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

;=============================================================================
tft		CODE
;=============================================================================

	global	TFT_ClearScreen
TFT_ClearScreen:
	btfsc	screen_type2			; screen type 2?
	bra		TFT_ClearScreen_display2; YES
	btfsc	screen_type3			; screen type 3?
	bra		TFT_ClearScreen_display3; YES

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

TFT_ClearScreen_display2:
	movlw	0x02					; column address start
	rcall	TFT_CmdWrite
	movlw	0x00
	rcall	TFT_DataWrite
	movlw	0x03
	rcall	TFT_CmdWrite
	movlw	0x00
	rcall	TFT_DataWrite

	movlw	0x04					; column address end
	rcall	TFT_CmdWrite
	movlw	0x00
	rcall	TFT_DataWrite
	movlw	0x05
	rcall	TFT_CmdWrite
	movlw	0xEF
	rcall	TFT_DataWrite

	movlw	0x06					; row address start
	rcall	TFT_CmdWrite
	movlw	0x00
	rcall	TFT_DataWrite
	movlw	0x07
	rcall	TFT_CmdWrite
	movlw	0x00
	rcall	TFT_DataWrite

	movlw	0x08					; row address end
	rcall	TFT_CmdWrite
	movlw	0x01
	rcall	TFT_DataWrite
	movlw	0x09
	rcall	TFT_CmdWrite
	movlw	0x3F
	rcall	TFT_DataWrite

	movlw	0x22					; start writing data to GRAM
	rcall	TFT_CmdWrite

	movlw	.160					; 160 x 240 x 6 = 230400 ticks
TFT_ClearScreen_display2_loop0:	
	bsf		tft_rs					; data!
	movwf	PRODH
	clrf	PORTH
TFT_ClearScreen_display2_loop1:
	movlw	.240
	movwf	PRODL
TFT_ClearScreen_display2_loop2:
	bcf		tft_nwr
	bsf		tft_nwr					; upper
	bcf		tft_nwr
	bsf		tft_nwr					; high
	bcf		tft_nwr
	bsf		tft_nwr					; lower
	bcf		tft_nwr
	bsf		tft_nwr					; upper
	bcf		tft_nwr
	bsf		tft_nwr					; high
	bcf		tft_nwr
	bsf		tft_nwr					; lower
	decfsz	PRODL,F
	bra		TFT_ClearScreen_display2_loop2
	decfsz	PRODH,F
	bra		TFT_ClearScreen_display2_loop1
	return

TFT_ClearScreen_display3:
	movlw	0x35				; vertical start address HIGH:LOW
	rcall	TFT_CmdWrite
	mullw	0
	rcall	TFT_DataWrite_PROD

	movlw	0x36				; vertical end address HIGH:LOW
	rcall	TFT_CmdWrite
	movlw	0x01
	rcall	TFT_DataWrite
	movlw	0x3F
	rcall	TFT_DataWrite

	movlw	0x37				; horizontal address START:END
	rcall	TFT_CmdWrite
	movlw	0x00
	rcall	TFT_DataWrite
	movlw	0xEF
	rcall	TFT_DataWrite

	movlw	0x20				; start address horizontal (.0 - .239)
	rcall	TFT_CmdWrite
	rcall	TFT_DataWrite_PROD

	movlw	0x21				; start address vertical (.0 - .319)
	rcall	TFT_CmdWrite
	rcall	TFT_DataWrite_PROD

	movlw	0x22				; start writing data to GRAM
	rcall	TFT_CmdWrite

	movlw	.107				; 107 x 240 x 6 = 154080 ticks (153600 would be enough)
	bra		TFT_ClearScreen_display2_loop0


	global	TFT_DisplayOff
TFT_DisplayOff:
	bcf		lightsen_power  		; power-down light sensor
	btfsc	screen_type3			; screen type 3 ?
	bra		TFT_DisplayOff_display3	; YES - screen needs special power-down sequence
	clrf	CCP1CON					; NO  - stop PWM
	bcf		PORTC,2					;     - pull PWM out to GND
	clrf	PORTA
	clrf	PORTH
	RD_L							; LOW
	RS_L							; LOW
	WR_L
	NCS_L
	bcf		tft_nreset
	bsf		tft_power				; inverted...
	return

TFT_DisplayOff_display3:
	movlw	0x05
	rcall	TFT_CmdWrite
	movlw	0x00
	rcall	TFT_DataWrite
	movlw	0x00
	rcall	TFT_DataWrite
	WAITMS	d'32'
	clrf	CCP1CON					; stop PWM
	bcf		PORTC,2					; pull PWM out to GND
	WAITMS	d'32'
	movlw	0x10
	rcall	TFT_CmdWrite
	movlw	0x00
	rcall	TFT_DataWrite
	movlw	0x01
	rcall	TFT_DataWrite
	WAITMS	d'100'
	clrf	PORTH
	bcf		tft_nwr
	bcf		tft_cs
	bcf		tft_nreset
	WAITMS	d'10'
	bsf		tft_power				; inverted...
	return

; -----------------------------
; TFT boot
; -----------------------------

	global	TFT_boot
TFT_boot:
	; switch off backlight
	clrf	CCP1CON					; stop PWM
	bcf		PORTC,2					; pull PWM out to GND

	clrf	PORTA
	clrf	PORTH

	RD_L	; LOW
	nop
	WR_L
	nop
	NCS_L	; Not CS
	nop
	bcf		tft_nreset
	WAITMS	d'1'
	bcf		tft_power				; inverted...
	WAITMS	d'1'
	RD_H	; Keep high
	nop
	WAITMS	d'2'
	bsf		tft_nreset
	WAITMS	d'5'
	bcf		tft_nreset
	WAITMS	d'5'
	bsf		tft_nreset
	WAITMS	d'150'
	WR_H							; release bus
	bsf		lightsen_power			; supply power to light sensor

	btfsc	screen_type3			; display type 3 ?
	bra		TFT_boot_screen3		; YES

	; Data Transfer Synchronization
	Parameter_out 0x00, 0x00
	Parameter_out 0x00, 0x00

	btfsc	screen_type2			; display type 2 ?
	bra		TFT_boot_screen2		; YES

	; Get screen type from Bootloader-Info
	movlw	0x7B
	movwf	TBLPTRL
	movlw	0xF7
	movwf	TBLPTRH
	movlw	0x01
	movwf	TBLPTRU
	TBLRD*+							; reads 0x6E for cR and USB OSTC3, 0x00 for BLE (2 and 3), and 0x02 for display 1 OSTC
	movlw	0x02					; coding for display 1
	cpfseq	TABLAT					; display 1 ?
	bra		TFT_boot_0				; NO - display 0

TFT_boot_1:
	; Init through config table...
	movlw	0x74
	movwf	TBLPTRL
	movlw	0xF7
	movwf	TBLPTRH
	movlw	0x01
	movwf	TBLPTRU
	bsf		screen_type1
	bra		TFT_boot_com

TFT_boot_0:
	; Init through config table...
	movlw	LOW   display0_config_table
	movwf	TBLPTRL
	movlw	HIGH  display0_config_table
	movwf	TBLPTRH
	movlw	UPPER display0_config_table
	movwf	TBLPTRU
	bcf		screen_type1

TFT_boot_com:
	rcall	display0_init_loop

	Index_out 0x03
	btfsc	flip_screen				; 180° rotation ?
	bra		TFT_boot2				; YES

	btfss	screen_type1			; display1?
	bra		TFT_boot1a				; NO
	Parameter_out 0x10, 0x00		; display1
	bra		TFT_boot3
TFT_boot1a:
	Parameter_out 0x50, 0x20		; display0
	bra		TFT_boot3
TFT_boot2:
	btfss	screen_type1			; display1?
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
	bra		display0_config_write	; write configuration data pair to display
	; Delay ms or quit (return)
	TBLRD*+
	tstfsz	TABLAT					; end of configuration data?
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
	rcall	TFT_DataWrite			; write configuration
	bra		display0_init_loop		; loop


TFT_boot_screen2:
	rcall	display1_init			; initialization sequence

	btfss	flip_screen				; 180° rotation?
	bra		TFT_ClearScreen			; NO - done: clear screen and return
	; flip the GRAM
	Index_out 0x16
	movlw	0x48					; flip image in the GRAM (very elegant with display 2...)
	rcall	TFT_DataWrite			; Write configuration
	bra		TFT_ClearScreen			; clear screen and return

TFT_boot_screen3:
	rcall	display1_init			; init sequence
	rcall	TFT_ClearScreen
	setf	CCPR1L					; duty cycle, 255 is required for OLED
	; Set brightness
	movff	brightness,PRODL	; =0: Eco, =1:Medium, =2:Full
	incf	PRODL,F					; +1
	dcfsnz	PRODL,F
	rcall	TFT_display3_low
	dcfsnz	PRODL,F
	rcall	TFT_display3_med
	dcfsnz	PRODL,F
	rcall	TFT_display3_high
	; ToDo: Flip....
	return

display1_init:
	movlw	LOW   (0x1F8BC         )
	movwf	TBLPTRL
	movlw	HIGH  (0x1F8BC & 0xFFFF)
	movwf	TBLPTRH
	movlw	UPPER (0x1F8BC         )
	movwf	TBLPTRU
display1_init_loop:
	TBLRD*+
	movlw	0xFF					; coding for end of configuration or wait step
	cpfseq	TABLAT
	bra		display1_config_write	; write configuration pair to display
	; Delay ms or quit (return)
	TBLRD*+
	tstfsz	TABLAT					; end of configuration?
	bra		$+4						; NO  - skip return
	return							; YES - done
	movf	TABLAT,W				; read waiting time
	call	WAITMSX					; wait WREG milliseconds
	bra		display1_init_loop		; loop
display1_config_write:				; with command in WREG
	movf	TABLAT,W
	rcall	TFT_CmdWrite			; write command
	TBLRD*+							; get configuration
	movf	TABLAT,W
	rcall	TFT_DataWrite			; write configuration
	btfss	screen_type3			; screen 3 ?
	bra		display1_init_loop		; NO - loop
	; Screen 3 gets another byte from the table
	TBLRD*+							; get configuration
	movf	TABLAT,W
	rcall	TFT_DataWrite			; write configuration
	bra		display1_init_loop		; loop


	global	TFT_CmdWrite
TFT_CmdWrite:
	RS_L							; command
;	btfsc	screen_type2
;	bra		TFT_CmdWrite_screen2
	clrf	PORTA					; upper
	bcf		INTCON,GIE
	movwf	PORTH					; lower
	WR_L
	WR_H							; tick
	bsf		INTCON,GIE
	return
;TFT_CmdWrite_screen2:
;	movwf	PORTH					; lower
;	WR_L
;	WR_H							; tick
;	return;

	global	TFT_DataWrite
TFT_DataWrite:
	RS_H							; data
;	btfsc	screen_type2
;	bra		TFT_DataWrite_screen2
	bcf		INTCON,GIE
	movwf	PORTH					; lower
	WR_L
	WR_H							; tick
	bsf		INTCON,GIE
	return
;TFT_DataWrite_screen2:
;	movwf	PORTH					; lower
;	WR_L
;	WR_H							; tick
;	return


;-----------------------------------------------------------------------------
; Smooth lighting-up of the display:
;
; Trashes: WREG, PRODL
; Typical usage:
;	clrf	CCPR1L					; backlight off
;	[draw splash screen]
;	call	TFT_DisplayFadeIn
;
	global	TFT_Display_FadeIn
TFT_Display_FadeIn:
	movlw	CCP1CON_VALUE			; get configuration
	movwf	CCP1CON					; set configuration
	bsf		tft_is_dimming			; TFT is dimming, ignore ambient sensor
	btfsc	screen_type3
	bra		TFT_Display_FadeIn_1
	clrf	CCPR1L					; backlight off - to be sure
	movff	max_CCPR1L,PRODL
TFT_Display_FadeIn_0:
	incf	CCPR1L,F				; duty cycle
	WAITMS	d'2'
	decfsz	PRODL,F
	bra		TFT_Display_FadeIn_0
	bcf		tft_is_dimming			; dimming done
	return
TFT_Display_FadeIn_1:
	setf	CCPR1L
	return

;-----------------------------------------------------------------------------
; Smooth lighting-off of the display:
; Trashes: WREG, PRODL
;
	global	TFT_Display_FadeOut
TFT_Display_FadeOut:
	movff	max_CCPR1L,PRODL
	bsf		tft_is_dimming			; TFT is dimming, ignore ambient sensor
	btfsc	screen_type3
	return					; Do not fade out screen type 3
TFT_Display_FadeOut_0:
	movff	PRODL,CCPR1L			; duty cycle
	WAITMS	d'1'
	decfsz	PRODL,F
	bra		TFT_Display_FadeOut_0 
TFT_Display_FadeOut_1:
	clrf	CCPR1L
	return

;-----------------------------------------------------------------------------
; OLED brightness control
;
TFT_display3_high:					; 0x01F8F8
	movlw	LOW   (0x01F8F8         )
	movwf	TBLPTRL
	movlw	HIGH  (0x01F8F8 & 0xFFFF)
	movwf	TBLPTRH
	movlw	UPPER (0x01F8F8         )
	movwf	TBLPTRU
	bra	display1_init_loop			; and return

TFT_display3_med:					; 0x01F91C
	movlw	LOW   (0x01F91C         )
	movwf	TBLPTRL
	movlw	HIGH  (0x01F91C & 0xFFFF)
	movwf	TBLPTRH
	movlw	UPPER (0x01F91C         )
	movwf	TBLPTRU
	bra	display1_init_loop			; and return

TFT_display3_low:					; 0x01F8D4
	movlw	LOW   (0x01F8D4         )
	movwf	TBLPTRL
	movlw	HIGH  (0x01F8D4 & 0xFFFF)
	movwf	TBLPTRH
	movlw	UPPER (0x01F8D4         )
	movwf	TBLPTRU
	bra	display1_init_loop			; and return


;-----------------------------------------------------------------------------
; colored (filled) Boxes
;
	global	box_std_block, box_black_block, box_color_block, box_color

box_std_block:						; use white color
	setf	WREG
	bra		box_color_block
box_black_block:					; use black color
	clrf	WREG
box_color_block:					; use color from WREG
	rcall	TFT_set_color
	VARARGS_BEGIN
	VARARGS_GET8 win_top
	VARARGS_GET8 win_height
	VARARGS_GET8 win_leftx2
	VARARGS_GET8 win_width
	VARARGS_END
	bra		TFT_box

box_color:							; use color from WREG and pre-set coordinates
	rcall	TFT_set_color
	bra		TFT_box


;-----------------------------------------------------------------------------
; colored Frames
;
	global	box_frame_std, box_frame_color

box_frame_std:						; use white color
	setf	WREG
box_frame_color:					; use color from WREG
	rcall	TFT_set_color
	VARARGS_BEGIN
	VARARGS_GET8 win_top
	VARARGS_GET8 win_height
	VARARGS_GET8 win_leftx2
	VARARGS_GET8 win_width
	VARARGS_END
	bra		TFT_frame


; ;-----------------------------------------------------------------------------
; ; Init for half_pixel_write
; ; Set column register on TFT device, and current color.
; ; Inputs: win_leftx2
; ; Outputs: win_color_1/_2
; ; Trashed: WREG, PROD
; ;
; ;	global	init_pixel_write
; ;init_pixel_write:
; ;	movf	win_leftx2,W
; ;	mullw	2
; ;	rcall	pixel_write_col320		; start address vertical (.0 - .319)
; ;	setf	WREG
; ;	bra	TFT_set_color


;-----------------------------------------------------------------------------
; Draw two half-pixels at position (win_top,win_leftx2)
; Inputs: win_leftx2, win_top, win_color_1/_2
; Trashed: WREG, PROD
;
	global	pixel_write
pixel_write:
	movf	win_leftx2,W
	mullw	.2						; win_leftx2 x 2 -> PRODH:PRODL
	rcall	pixel_write_col320		; start address vertical (.0 - .319)
	rcall	half_pixel_write		; write this half-one

	movf	win_leftx2,W			; address of next one
	mullw	.2						; win_leftx2 x 2 -> PRODH:PRODL
	INCI	PROD					; PROD++
	rcall	pixel_write_col320
	bra		half_pixel_write		; and return... note: cmd 0x20 is mandatory, because
									; of the auto-increment going vertical

	global	pixel_write_col320
pixel_write_col320:
	btfsc	screen_type2			; display type 2 ?
	bra		pixel_write_col320_d2	; YES
	btfsc	screen_type1			; display type 1 ?
	bra		pixel_write_col320_d1	; YES
	btfsc	screen_type3			; display type 3 ?
	bra		pixel_write_col320_d3	; YES
									; NO to all - display type 0
	btfss	flip_screen				; 180° rotation?
	bra		pixel_write_noflip_H	; NO
	bra		pixel_write_flip_H		; YES
pixel_write_col320_d1:				; display type 1
	btfsc	flip_screen				; 180° rotation?
	bra		pixel_write_noflip_H	; YES
pixel_write_flip_H:					; flip d0
	movf	PRODL,W					; 16 bits 319 - PROD --> PROD
	sublw	LOW  .319				; 319-W --> W
	movwf	PRODL
	movf	PRODH,W
	btfss	STATUS,C				; borrow = /CARRY
	incf	WREG
	sublw	HIGH .319
	movwf	PRODH

pixel_write_noflip_H:
	Index_out 0x21					; frame memory vertical address
	bra		TFT_DataWrite_PROD		; and return...

pixel_write_col320_d2:
	movlw	0x06
	rcall	TFT_CmdWrite
	movf	PRODH,W
	rcall	TFT_DataWrite
	movlw	0x07
	rcall	TFT_CmdWrite
	movf	PRODL,W
	rcall	TFT_DataWrite

	incf	PRODL,F
	movlw	.0
	addwfc	PRODH,F					; +1

	movlw	0x08
	rcall	TFT_CmdWrite
	movf	PRODH,W
	rcall	TFT_DataWrite
	movlw	0x09
	rcall	TFT_CmdWrite
	movf	PRODL,W
	bra		TFT_DataWrite			; ... and return

pixel_write_col320_d3:
	movlw	0x21					; start address vertical (.0 - .319)
	rcall	TFT_CmdWrite
	bra		TFT_DataWrite_PROD		; and return...

;-----------------------------------------------------------------------------
; Write one half-pixel at position (win_top,win_leftx2).
; Inputs: win_leftx2, win_top, win_color_1/_2
; Trashed: WREG, PROD
;
	global	half_pixel_write
half_pixel_write:
	movf	win_top,W					; d'0' ... d'239'
	; Variant with Y position in WREG
half_pixel_write_1:
	btfsc	screen_type2				; display type 2 ?
	bra		half_pixel_write_1_display2	; YES
	btfsc	screen_type3				; display type 3 ?
	bra		half_pixel_write_1_display3	; YES

half_pixel_write_1_display1:
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

half_pixel_write_1_display2:
	mullw	1						; copy row to PRODL (PRODH=0)
	; Row address start
	movlw	0x02
	rcall	TFT_CmdWrite
	movlw	.0
	rcall	TFT_DataWrite
	movlw	0x03
	rcall	TFT_CmdWrite
	movf	PRODL,W
	rcall	TFT_DataWrite

	incf	PRODL,F

	movlw	0x04
	rcall	TFT_CmdWrite
	movlw	.0
	rcall	TFT_DataWrite
	movlw	0x05
	rcall	TFT_CmdWrite
	movf	PRODL,W
	rcall	TFT_DataWrite

	movff	win_color1,PRODH
	movff	win_color2,PRODL
	rcall	convert_for_display2

	movlw	0x22					; start writing data to GRAM
	rcall	TFT_CmdWrite
	RS_H							; data
	movff	win_color5, PORTH
	WR_L
	WR_H							; tick
	movff	win_color4, PORTH
	WR_L
	WR_H							; tick
	movff	win_color3, PORTH
	WR_L
	WR_H							; tick
	return

half_pixel_write_1_display3:
	mullw	1						; copy row to PRODL (PRODH=0)

	movlw	0x20					; horizontal address START:END
	rcall	TFT_CmdWrite
	rcall	TFT_DataWrite_PROD

	movlw	0x22					; start writing data to GRAM
	rcall	TFT_CmdWrite
	RS_H							; data
	movff	win_color1, PORTH
	WR_L
	WR_H							; tick
	movff	win_color2, PORTH
	WR_L
	WR_H							; tick
	return							; done

;-----------------------------------------------------------------------------
; Draw a vertical line of half-pixel at position (win_top,win_leftx2,win_height).
; Inputs: win_leftx2, win_top, win_height, win_color_1/_2
; Trashed: WREG, PROD, TABLAT, TBLPTRL
;
	global	half_vertical_line
half_vertical_line:
	clrf	TABLAT					; loop index

half_vertical_line_loop:
	movf	win_leftx2,W			; init X position
	mullw	.2						; win_leftx2 x 2 -> PRODH:PRODL
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
; Draw a horizontal line of half-pixel at position (win_top,win_leftx2,win_width).
; Inputs: win_leftx2, win_top, win_width, win_color_1/_2
; Trashed: WREG, PROD, TABLAT, TBLPTRL
;
	global	half_horizontal_line
half_horizontal_line:
	clrf	TABLAT					; loop index

half_horizontal_line_loop:
	movf	win_leftx2,W			; init X position
	mullw	.2						; win_leftx2 x 2 -> PRODH:PRODL
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
; TFT Data Command
;
TFT_DataWrite_PROD:
;	RD_H								; keep high
	RS_H								; data
	btfsc	screen_type2				; screen type 2 ?
	bra		TFT_DataWrite_PROD_display2	; YES
	btfsc	screen_type3				; screen type 3 ?
	bra		TFT_DataWrite_PROD_display2	; YES
	bcf		INTCON,GIE					; NO  -
	movff	PRODH,PORTA					;     - move high byte to PORTA
	movff	PRODL,PORTH					;     - move low byte to PORTH
	WR_L								;     - tick
	WR_H								;     - tack
	bsf		INTCON,GIE					;     -
	return								;     - done

TFT_DataWrite_PROD_display2:
	movff	PRODH,PORTH					; move high byte to PORTH (display 2 is big endian)
	WR_L								; tick
	WR_H								; tack
	movff	PRODL,PORTH					; move low  byte to PORTH
	WR_L								; tick
	WR_H								; tack
	btfsc	screen_type3				; screen type 3 ?
	return								; YES - done
	movff	win_color3,PORTH			; NO  - move low(est) byte to PORTH
	WR_L								;     - tick
	WR_H								;     - tack
	return								;     - done


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

;-----------------------------------------------------------------------------
; Output TFT Window Address commands
; Inputs : win_top, win_leftx2, win_height, win_width
; Output : PortA/PortH commands
; Trashed: PROD
;
	global	TFT_box_write
TFT_box_write:
	movf	win_leftx2,W			; compute left = 2 * leftx2 --> PROD
	mullw	.2						; win_leftx2 x 2 -> PRODH:PRODL

	btfsc	screen_type2			; screen type 2 ?
	bra		TFT_box_write_display2	; YES
	btfsc	screen_type3			; screen type 3 ?
	bra		TFT_box_write_display3	; YES
	btfsc	screen_type1			; screen type 1 ?
	bra		TFT_box_write_display1	; YES

	; screen type 0
TFT_box_write_display0:
	btfsc	flip_screen				; 180° rotation?
	bra		TFT_box_do_flip_H		; YES
	bra		TFT_box_no_flip_H		; NO

	; screen type 1
TFT_box_write_display1:
	btfss	flip_screen				; 180° rotation?
	bra		TFT_box_do_flip_H		; NO
	;bra	TFT_box_no_flip_H		; YES

	;---- Normal horizontal window ---------------------------------------
TFT_box_no_flip_H:
	Index_out 0x52					; window vertical start address
	rcall	TFT_DataWrite_PROD		; output left
	Index_out 0x21					; frame memory vertical address
	rcall	TFT_DataWrite_PROD		; output left

	movf	win_width+0,W			; right = left + width - 1
	addwf	PRODL,F
	movf	win_width+1,W
	addwfc	PRODH,F
	decf	PRODL,F					; right--
	btfss	STATUS,C
	decf	PRODH,F

	Index_out 0x53					; window vertical end address
	rcall	TFT_DataWrite_PROD
	bra		TFT_box_common_H

	;---- Flipped horizontal window --------------------------------------
TFT_box_do_flip_H:
	; calculate new coordinate
	movf	PRODL,W					; 16 bits 319 - PROD --> PROD
	sublw	LOW  .319				; 319 - WREG --> WREG
	movwf	PRODL
	movf	PRODH,W
	btfss	STATUS,C				; borrow = /CARRY
	incf	WREG
	sublw	HIGH .319
	movwf	PRODH

	Index_out 0x53					; window vertical start address
	rcall	TFT_DataWrite_PROD		; output left
	Index_out 0x21					; frame memory vertical address
	rcall	TFT_DataWrite_PROD		; output left

	; calculate new coordinate
	movf	win_width+0,W			; 16 bits PROD - width --> PROD
	subwf	PRODL,F					; PRODL - WREG --> PRODL
	movf	win_width+1,W
	subwfb	PRODH,F
	INCI	PROD					; PROD++

	Index_out 0x52					; window vertical end address
	rcall	TFT_DataWrite_PROD

TFT_box_common_H:
	btfss	flip_screen				; 180° rotation ?
	bra		TFT_box_no_flip_V		; NO
	;bra	TFT_box_do_flip_V		; YES

	;---- Flipped vertical window -----------------------------------------
TFT_box_do_flip_V:
	; calculate new coordinate
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

	;---- Normal vertical window ----------------------------------------
TFT_box_no_flip_V:
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


TFT_box_write_display2:
	; setup left border
	movlw	0x06
	rcall	TFT_CmdWrite
	movf	PRODH,W
	rcall	TFT_DataWrite
	movlw	0x07
	rcall	TFT_CmdWrite
	movf	PRODL,W
	rcall	TFT_DataWrite

	movf	win_width+0,W			; right = left + width - 1
	addwf	PRODL,F
	movf	win_width+1,W
	addwfc	PRODH,F
	decf	PRODL,F					; decrement result
	btfss	STATUS,C
	decf	PRODH,F

	; setup right border
	movlw	0x08
	rcall	TFT_CmdWrite
	movf	PRODH,W
	rcall	TFT_DataWrite
	movlw	0x09
	rcall	TFT_CmdWrite
	movf	PRODL,W
	rcall	TFT_DataWrite

	;---- Normal vertical window -----------------------------------------
	; Output (top) (bottom)
	movff	win_top,PRODH			; top --> PRODH (first byte)
	movf	win_height,W
	addwf	PRODH,W
	decf	WREG
	movwf	PRODL					; top+height-1 --> PRODL (second byte)

	movlw	0x02
	rcall	TFT_CmdWrite
	movlw	0x00
	rcall	TFT_DataWrite
	movlw	0x03
	rcall	TFT_CmdWrite
	movf	PRODH,W
	rcall	TFT_DataWrite

	movlw	0x04
	rcall	TFT_CmdWrite
	movlw	0x00
	rcall	TFT_DataWrite
	movlw	0x05
	rcall	TFT_CmdWrite
	movf	PRODL,W
	bra		TFT_DataWrite			; ... and return

TFT_box_write_display3:
	;---- Normal horizontal window ---------------------------------------
	; Output 0x35 left,
	;        0x36 right == left + width - 1.

	Index_out 0x35					; window vertical start address
	rcall	TFT_DataWrite_PROD		; output left
	Index_out 0x21					; also the horizontal first pix coordinate
	rcall	TFT_DataWrite_PROD		; output left

	movf	win_width+0,W			; right = left + width - 1
	addwf	PRODL,F
	movf	win_width+1,W
	addwfc	PRODH,F
	decf	PRODL,F					; decrement result
	btfss	STATUS,C
	decf	PRODH,F

	Index_out	0x36				; write and the right border
	rcall	TFT_DataWrite_PROD

	;---- Normal vertical window -----------------------------------------
	; Output 0x37 (top) (bottom)
	movff	win_top,PRODH			; top --> PRODH (first byte)
	movff	win_height,WREG
	addwf	PRODH,W
	decf	WREG
	movwf	PRODL					; top + height - 1 --> PRODL (second byte)

	Index_out	0x37
	rcall	TFT_DataWrite_PROD

	movff	PRODH,PRODL
	clrf	PRODH					; start pixel V coord == top.
	Index_out	0x20
	bra		TFT_DataWrite_PROD		; and return...


;-----------------------------------------------------------------------------
; TFT_frame : draw a frame around current box with current color
; Inputs:  win_top, win_leftx2, win_height, win_width, win_color1, win_color2
; Outputs: (none)
; Trashed: WREG, PROD, aa_start:2, aa_end:2
;
	global	TFT_frame
TFT_frame:
	movff	win_top,tft_save_top		; backup everything
	movff	win_height,tft_save_height
	movff	win_leftx2,tft_save_left
	movff	win_width+0,tft_save_width

	;---- TOP line -----------------------------------------------------------
	movlw	.1							; row ~ height = 1
	movwf	win_height
	rcall	TFT_box

	;---- BOTTOM line --------------------------------------------------------
	movff	tft_save_top,PRODL			; get back top
	movff	tft_save_height,WREG		; get back height
	addwf	PRODL,W						; top + height
	decf	WREG						; top + height - 1
	movwf	win_top						; top + height - 1 --> top
	rcall	TFT_box

	;---- LEFT column --------------------------------------------------------
	movff	tft_save_top,win_top		; restore top/height
	movff	tft_save_height,win_height
	movlw	.1							; column ~ width = 1
	movwf	win_width+0
	rcall	TFT_box

	;---- RIGHT column -------------------------------------------------------
	movff	tft_save_left,WREG
	movff	tft_save_width,PRODL
	addwf	PRODL,W
	decf	WREG
	movwf	win_leftx2
	rcall	TFT_box

	;---- Restore everything -------------------------------------------------
	movff	tft_save_left,win_leftx2
	movff	tft_save_width,win_width+0
	return

;-----------------------------------------------------------------------------
; TFT_box: fills current box with current color
; Inputs : win_top, win_leftx2, win_height, win_width, win_color1, win_color2
; Outputs: (none)
; Trashed: WREG, PROD
;
	global	TFT_box
TFT_box:
	;---- Define Window ------------------------------------------------------
	bcf		STATUS,C
	rlcf	win_width+0,F
	rlcf	win_width+1,F			; x2
	rcall	TFT_box_write			; setup box

	bcf		STATUS,C
	rrcf	win_width+1,F			; width /= 2
	rrcf	win_width+0,F

	;---- Fill Window --------------------------------------------------------
	Index_out 0x22					; frame memory data write start
	clrf	PRODH					; column counter
	RS_H							; data

	btfsc	screen_type2			; display type 2 ?
	bra		TFT_box_display2		; YES
	btfsc	screen_type3			; display type 3 ?
	bra		TFT_box_display3		; YES

TFT_box2:							; loop height times
	movff	win_height,PRODL

TFT_box3:							; loop width times
	bcf		INTCON,GIE
	movff	win_color1,PORTA		; upper
	movff	win_color2,PORTH		; lower
	WR_L							; tick
	WR_H							; ...
	WR_L							; tick
	WR_H							; ...
	bsf		INTCON,GIE
	decfsz	PRODL,F					; row loop finished ?
	bra		TFT_box3				; NO - continue

	incf	PRODH,F					; column count ++
	movf	win_bargraph,W			; get width of active bargraph part
	cpfseq	PRODH					; current column == end of active bargraph ?
	bra		TFT_box4				; NO  - just loop
	clrf	win_color1				; YES - switch to black
	clrf	win_color2				;     - ...
TFT_box4:
	movf	win_width+0,W			; get total bargraph width
	xorwf	PRODH,W					; all columns done?
	bnz		TFT_box2				; NO - loop

	movlw	0x00					; NOP, to stop window mode
	rcall	TFT_CmdWrite

	; reset bargraph mode...
	setf	win_bargraph
	return

TFT_box_display2:
	; Screen 2
	movff	win_color1,PRODH
	movff	win_color2,PRODL
	rcall	convert_for_display2
	clrf	PRODH					; column counter
TFT_box2_display2:					; loop height times
	movff	win_height,PRODL
TFT_box3_display2:					; loop width times
	movff	win_color5,PORTH
	bcf		tft_nwr
	bsf		tft_nwr					; upper
	movff	win_color4,PORTH
	bcf		tft_nwr
	bsf		tft_nwr					; high
	movff	win_color3,PORTH
	bcf		tft_nwr
	bsf		tft_nwr					; low

	movff	win_color5,PORTH
	bcf		tft_nwr
	bsf		tft_nwr					; upper
	movff	win_color4,PORTH
	bcf		tft_nwr
	bsf		tft_nwr					; high
	movff	win_color3,PORTH
	bcf		tft_nwr
	bsf		tft_nwr					; low
	decfsz	PRODL,F					; row loop finished?
	bra		TFT_box3_display2		; NO  - loop
	incf	PRODH,F					; YES - column count ++
	movf	win_bargraph,W			;     - get bargraph width
	cpfseq	PRODH					;     - current column = bargraph ?
	bra		TFT_box4_display2		;       NO
	clrf	win_color5				;       YES - switch to black
	clrf	win_color4				;           - ...
	clrf	win_color3				;           - ...
TFT_box4_display2:
	movf	win_width+0,W			; get width
	cpfseq	PRODH					; width loop finished ?
	bra		TFT_box2_display2		; NO  - loop
	setf	win_bargraph			; YES - reset bargraph mode
	return							;     - done

TFT_box_display3:
	; Screen 3
TFT_box2_display3:					; loop height times
	movff	win_height,PRODL
TFT_box3_display3:					; loop width times
	movff	win_color1,PORTH
	bcf		tft_nwr
	bsf		tft_nwr					; upper
	movff	win_color2,PORTH
	bcf		tft_nwr
	bsf		tft_nwr					; high
	movff	win_color1,PORTH
	bcf		tft_nwr
	bsf		tft_nwr					; low
	movff	win_color2,PORTH
	bcf		tft_nwr
	bsf		tft_nwr					; upper
	decfsz	PRODL,F					; row loop finished?
	bra		TFT_box3_display3		; NO  - loop
	incf	PRODH,F					; YES - column count ++
	movf	win_bargraph,W			;     - get bargraph width
	cpfseq	PRODH					;     - current column = bargraph ?
	bra		TFT_box4_display3		;       NO
	clrf	win_color1				;       Yes - switch to black
	clrf	win_color2				;           - ...
TFT_box4_display3:
	movf	win_width+0,W			; get width
	cpfseq	PRODH					; width loop finished ?
	bra		TFT_box2_display3		; NO  - loop
	setf	win_bargraph			; YES - reset bargraph mode
	return


;-----------------------------------------------------------------------------
; Convert 8 bit RGB b'RRRGGGBB' into 16 bit RGB    b'RRRRRGGGGGGBBBBB'
;                       WREG                       win_color1 win_color2
	global	TFT_set_color
TFT_set_color:
	movwf	tft_temp1				; get 8 bit RGB b'RRRGGGBB' into tft_temp1...
	movwf	tft_temp2				;                        ... and tft_temp2

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


	global	convert_for_display2
convert_for_display2:				; convert 16 bit RGB b'RRRRRGGG GGGBBBBB' into 24 bit RGB b'RRRRRR00 GGGGGG00 BBBBBB00'
									;                       PRODH    PRODL                   win_color5 win_color4 win_color3
	; Red
	movff	PRODH,win_color5		; = RRRRRGGG
	bcf		win_color5,2			; = RRRRR0GG
	btfsc	win_color5,7
	bsf		win_color5,2			; = RRRRR1GG  the lower two bits are ignored by the screen
	; Blue
	movff	PRODL,win_color3
	rrcf	win_color3,F			; = UGGGBBBB  and the LSB-blue into carry
	swapf	win_color3,F			; = BBBBUGGG
	bcf		win_color3,3			; = BBBB0GGG
	btfsc	STATUS,C
	bsf		win_color3,3			; = BBBB1GGG
	bcf		win_color3,2			; = BBBBB0GG
	btfsc	win_color3,7
	bsf		win_color3,2			; = BBBBB1GG
	; Green
	rrcf	PRODH,F
	rrcf	PRODL,F
	rrcf	PRODH,F
	rrcf	PRODL,F
	rrcf	PRODH,F
	rrcf	PRODL,F					; = GGGGGGBB  the lower two bits are ignored by the screen
	movff	PRODL,win_color4
	return


;-----------------------------------------------------------------------------

 IFDEF _screendump

;-----------------------------------------------------------------------------
; Dump screen contents to the UART
;
	global	TFT_dump_screen_check
TFT_dump_screen_check:
	btfss	vusb_in					; USB (still) plugged in?
	bcf		screen_dump_avail		; NO - disable screen dump function

	SERIAL_CC_RECEIVE WREG			; try to read a byte from RS232
	btfsc	rs232_rx_timeout		; anything received?
	return							; NO  - done
	xorlw	"l"						; YES - exclusive-or with coding of screen dump command
	tstfsz	WREG					;     - screen dump command received?
	return							;       NO  - return
	;bra	TFT_dump_screen			;       YES - serve screen dump request

	global	TFT_dump_screen
TFT_dump_screen:
	btfsc	screen_type2			; is this an OSTC with a screen of type 2?
	return							; YES - not supported, abort
	bsf		block_sensor_interrupt	; NO  - disable sensor interrupts
	SERIAL_LC_SEND 'l'				;     - send command acknowledge


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
	; dump even column
	movlw	.240					; 240 lines, once
	movwf	ds_line
dump_screen_2:
	Index_out	0x20				; frame memory horizontal address
	movff	ds_line,WREG			; d'0' ... d'239'
	mullw	.1						; copy row to PRODH:L
	rcall	TFT_DataWrite_PROD

	movff	ds_column,WREG			; initialize X position
	mullw	.2						; ds_column x 2 -> PRODH:PRODL
	rcall	pixel_write_col320		; start address vertical (.0 - .319)

	rcall	TFT_DataRead_PROD		; read pixel
	rcall	dump_screen_pixel

	decfsz	ds_line,F
	bra		dump_screen_2
	rcall	dump_screen_pixel_flush

	; dump odd column
	movlw	.240					; 240 lines, twice
	movwf	ds_line
dump_screen_3:
	Index_out	0x20				; frame memory horizontal address
	movff	ds_line,WREG			; d'0' ... d'239'
	mullw	.1						; copy row to PRODH:L
	rcall	TFT_DataWrite_PROD

	movff	ds_column,WREG			; initialize X position
	mullw	.2						; ds_column x 2 -> PRODH:PRODL
	INCI	PROD					; PROD++
	rcall	pixel_write_col320		; start address vertical (.0 - .319)

	rcall	TFT_DataRead_PROD		; read pixel
	rcall	dump_screen_pixel		; compress and send pixel

	decfsz	ds_line,F
	bra		dump_screen_3
	rcall	dump_screen_pixel_flush

	incf	ds_column,F
	movlw	.160
	cpfseq	ds_column
	bra		dump_screen_1

	bcf		block_sensor_interrupt	; re-enable sensor interrupts
	clrf	RCREG1					; clear receive buffer
	bcf		RCSTA1,CREN				; clear receiver status
	bsf		RCSTA1,CREN				; ...
	bsf		screen_dump_avail		; enable screen dump function
	return

;-----------------------------------------------------------------------------
; Pixel compression
;
; Input : PRODH:L = pixel
; Output: Compressed stream on output.
; Compressed format:
;       0ccccccc          : BLACK pixel,      repeated ccccccc+1 times (1..128)
;       11cccccc          : WHITE pixel,      repeated  cccccc+1 times (1.. 64)
;       10cccccc HIGH LOW : color pixel (H:L) repeated   ccccc+1 times (1.. 64)
;
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

	SERIAL_CC_SEND WREG				; send byte in WREG
	SERIAL_CC_SEND ds_pixel+1		; send bytes in ds_pixel, high byte first
	SERIAL_CC_SEND ds_pixel+0		;                         low  byte last

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
	SERIAL_CC_SEND WREG				; send byte in WREG
	bra		dump_screen_pixel_1		; more to dump ?

dump_screen_pix_white:
	movlw	.64						; max white pixel on a single byte
	cpfsgt	ds_count				; skip if count > 64
	movf	ds_count,W				; W <- min(64,count)
	subwf	ds_count,F				; ds_count <- ds_count-W
	decf	WREG					; save as 0..63
	iorlw	b'11000000'				; mark as a compressed white
	bra		dump_screen_pix_3		; send pixel

dump_screen_pixel_flush:
	clrf	PRODH
	clrf	PRODL
	rcall	dump_screen_pixel_1		; send it
dump_screen_pixel_reset:
	clrf	ds_count				; clear count
	return

 ENDIF	; _screendump

;-----------------------------------------------------------------------------

	END
