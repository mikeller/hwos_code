;=============================================================================
;
;   File tft.inc                            * combined next generation V3.09.4m
;
;   Declaring interfaces to the TFT screen and its Oxxx controler
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;  2011-05-24 : [jDG] Cleanups from initial Matthias code.


;-----------------------------------------------------------------------------
; public Functions

	extern	TFT_DisplayOff			; power-off everything (needs a boot thereafter)
	extern	TFT_boot				; initialize screen hardware
	extern	TFT_Display_FadeIn		; smooth lighting  up
	extern	TFT_Display_FadeOut		; smooth darkening down
	extern	TFT_ClearScreen			; clear screen

	extern	TFT_box_write			; send TFT window address
	extern	TFT_set_color			; set output color
;	extern	pixel_write				; draw two half-pixels at position         (win_top,win_leftx2 )
	extern	pixel_write_col320		; draw two half-pixels at position         (win_top,PRODH:PRODL)
	extern	half_vertical_line		; draw a vertical   line of half-pixels at (win_top,win_leftx2,win_height)
	extern	half_horizontal_line	; draw a horizontal line of half-pixels at (win_top,win_leftx2,win_width)

 IFDEF _screendump
	extern	TFT_dump_screen			; send a screenshot via the serial interface immediately
	extern	TFT_dump_screen_check	; send a screenshot via the serial interface on command
 ENDIF


;-----------------------------------------------------------------------------
; low Level Macros (for aa_wordprocessor and color_processor)
;

Index_out	macro	low_b
	movlw	low_b
	extern	TFT_CmdWrite
	call	TFT_CmdWrite
	endm


;-----------------------------------------------------------------------------
; colored Boxes

WIN_BOX_BLACK	macro	top, bottom, left, right			; black box (erase scree area)
	extern	box_black_block
	call	box_black_block
	db		top, (bottom)-(top)+1, left, (right)-(left)+1
	endm

WIN_BOX_STD		macro	top, bottom, left, right			; white box
	extern	box_std_block
	call	box_std_block
	db		top, (bottom)-(top)+1, left, (right)-(left)+1
	endm

WIN_BOX_COLOR	macro	top, bottom, left, right			; box with color from WREG
	extern	box_color_block
	call	box_color_block
	db		top, (bottom)-(top)+1, left, (right)-(left)+1
	endm

BOX_COLOR		macro				; box with color from WREG and pre-set coordinates
	extern	box_color
	call	box_color
	endm

BOX				macro				; box with pre-set color and coordinates
	extern	TFT_box
	call	TFT_box
	endm


;-----------------------------------------------------------------------------
; colored Frames

WIN_FRAME_STD	macro	top, bottom, left, right			; white frame
	extern	box_frame_std
	call	box_frame_std
	db		top, (bottom)-(top)+1, left, (right)-(left)+1
	endm

WIN_FRAME_COLOR	macro	top, bottom, left, right			; frame with color from WREG
	extern	box_frame_color
	call	box_frame_color
	db		top, (bottom)-(top)+1, left, (right)-(left)+1
	endm


;-----------------------------------------------------------------------------
; set individual Coordinates

WIN_TOP		macro	win_top_input
	movlw	win_top_input
	movwf	win_top
	endm


WIN_HEIGHT	macro	win_hight_input
	movlw	win_hight_input
	movwf	win_height
	endm


WIN_LEFT	macro	win_leftx2_input
	movlw	win_leftx2_input
	movwf	win_leftx2
	endm


WIN_WIDTH	macro	win_width_input
	movlw	win_width_input
	movwf	win_width
	endm


;-----------------------------------------------------------------------------
; Paint an Image stored in Program Memory, Image referenced by a Label
;
TFT_WRITE_PROM_IMAGE_BY_LABEL	macro	image_label
		extern	image_label
		movlw	LOW   (image_label)
		movwf	TBLPTRL
		movlw	HIGH  (image_label)
		movwf	TBLPTRH
		movlw	UPPER (image_label)
		movwf	TBLPTRU
		extern	color_image
		call	color_image
	endm


;-----------------------------------------------------------------------------
; Paint an Image stored in Program Memory, image referenced by an address
;
TFT_WRITE_PROM_IMAGE_BY_ADDR	macro	image_address
		movlw	LOW   (image_address)
		movwf	TBLPTRL
		movlw	HIGH  (image_address & 0xFFFF)
		movwf	TBLPTRH
		movlw	UPPER (image_address)
		movwf	TBLPTRU
		extern	color_image
		call	color_image
	endm


;-----------------------------------------------------------------------------
; Load a Custom Color Palette (to be call before TFT_WRITE_PROM_IMAGE*)
;
TFT_WRITE_PROM_IMAGE_CUST_COLOR	macro	colors_label
		movlw	LOW   (colors_label)
		movwf	TBLPTRL
		movlw	HIGH  (colors_label)
		movwf	TBLPTRH
		movlw	UPPER (colors_label)
		movwf	TBLPTRU
		extern	get_colors
		call	get_colors
		bsf		use_custom_colors		; suppress the colors that come with the image
	endm



;-----------------------------------------------------------------------------
; Pixel Writing Macros
;

PIXEL_WRITE			macro	colRegister, rowRegister
	movff	colRegister,win_leftx2
	movff	rowRegister,win_top
	extern	pixel_write
	call	pixel_write
	endm


;INIT_PIXEL_WRITE	macro	colRegister
;	movff	colRegister,win_leftx2
;	extern	init_pixel_write
;	call	init_pixel_write
;	endm


HALF_PIXEL_WRITE	macro	rowRegister
	movff	rowRegister,win_top
	extern	half_pixel_write
	call	half_pixel_write
	endm

;-----------------------------------------------------------------------------
