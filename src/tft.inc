;=============================================================================
;
;   File tft.inc                              combined next generation V3.03.7
;
;   Declaring interfaces to the TFT screen and its Oxxx controler
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;  2011-05-24 : [jDG] Cleanups from initial Matthias code.

;=============================================================================
; TFT public subroutines
;=============================================================================

;-----------------------------------------------------------------------------
; Write two half-pixels at position (win_top,win_leftx2)
;
; Inputs : win_leftx2, win_top, win_color:2
; Outputs: (none)
; Trashed: WREG, PROD

	extern	pixel_write


;-----------------------------------------------------------------------------
; Write one half-pixel at position (win_top,win_leftx2)
;
; Inputs : win_leftx2, win_top, win_color:2
; Outputs: (none)
; Trashed: WREG, PROD

	extern	half_pixel_write


;-----------------------------------------------------------------------------
; Draw a frame around current box with current color
; Inputs :  win_top, win_leftx2, win_height, win_width, win_color1, win_color2
; Outputs: (none)
; Trashed: WREG, PROD, aa_start:2, aa_end:2, win_leftx2, win_width:1

	extern	TFT_frame


;-----------------------------------------------------------------------------
	extern	TFT_DisplayOff					; power-off everything (needs a boot thereafter)
	extern	TFT_boot						; initialize screen hardware
	extern	TFT_Display_FadeIn				; smooth lighting  up
	extern	TFT_Display_FadeOut				; smooth darkening down
	extern	TFT_ClearScreen
	extern	TFT_box_write
	extern	TFT_box_write_16bit_win_left	; with column in PRODL:PRODH
	extern	TFT_box
	extern	TFT_DataWrite_PROD
	extern	TFT_set_color
;	extern	init_pixel_write
	extern	pixel_write
	extern	pixel_write_col320
	extern	half_vertical_line
	extern	half_horizontal_line

 IFDEF _screendump
	extern	TFT_dump_screen
	extern	TFT_dump_screen_check
 ENDIF


;=============================================================================
; Low level macros (for aa_wordprocessor and color_processor)
;
	extern	TFT_CmdWrite
Index_out		macro	low_b
					movlw	low_b
					call	TFT_CmdWrite
				endm


;=============================================================================
; shortcuts for TFT_box and TFT_frame call sequences
;
	extern	box_frame_std, box_frame_common, box_frame_color, box_frame_color16
	extern	box_std_block, box_black_block,  box_color_block

; Erase a given screen area
;
WIN_BOX_BLACK	macro	top, bottom, left, right
					call	box_black_block
					db		top, (bottom)-(top)+1, left, (right)-(left)+1
				endm


; Fill a given screen area with standard color (white)
;
WIN_BOX_STD		macro	top, bottom, left, right
					call	box_std_block
					db		top, (bottom)-(top)+1, left, (right)-(left)+1
				endm


; Fill a given screen area with color from WREG (8 bits rrrgggbb)
;
WIN_BOX_COLOR	macro	top, bottom, left, right
					call	box_color_block
					db		top, (bottom)-(top)+1, left, (right)-(left)+1
				endm

; Draw a frame in standard color (white)
;
WIN_FRAME_STD	macro	top, bottom, left, right
					call	box_frame_std
					db		top, (bottom)-(top)+1, left, (right)-(left)+1
				endm


; Draw a frame with color from WREG (8 bits rrrgggbb)
;
WIN_FRAME_COLOR	macro	top, bottom, left, right
					call	box_frame_color
					db		top, (bottom)-(top)+1, left, (right)-(left)+1
				endm


; Draw a frame with color from win_color (16 bits in TFT format)
;
WIN_FRAME_COLOR16 macro	top, bottom, left, right
					call	box_frame_color16
					db		top, (bottom)-(top)+1, left, (right)-(left)+1
				endm


WIN_FONT		macro	win_font_input
					movlw	win_font_input
					movff	WREG,win_font
				endm


WIN_TOP			macro	win_top_input
					movlw	win_top_input
					movff	WREG,win_top
				endm


WIN_HEIGHT		macro	win_hight_input
					movlw	win_hight_input
					movff	WREG,win_height
				endm


WIN_LEFT		macro	win_left_input
					movlw	win_left_input
					movff	WREG,win_leftx2
				endm


WIN_WIDTH		macro	win_width_input
					movlw	win_width_input
					movff	WREG,win_width
				endm


WIN_COLOR		macro	win_color_input
					movlw	win_color_input
					call	TFT_set_color
				endm

;=============================================================================
; TFT_write_prom_image
;

; image referenced by a label
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

; image referenced by an address
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

; custom colors referenced by label
TFT_WRITE_PROM_IMAGE_CUST_COLOR	macro	colors_label
		movlw	LOW   (colors_label)
		movwf	TBLPTRL
		movlw	HIGH  (colors_label)
		movwf	TBLPTRH
		movlw	UPPER (colors_label)
		movwf	TBLPTRU
		extern	get_colors
		call	get_colors
		bsf		use_custom_colors		; will suppress reading the colors that come with the image
	endm


;=============================================================================
; Macros to provide our own interface code
;

PIXEL_WRITE			macro	colRegister,	rowRegister
						movff	colRegister,win_leftx2
						movff	rowRegister,win_top
						call	pixel_write
					endm


;INIT_PIXEL_WRITE	macro	colRegister
;						movff	colRegister,win_leftx2
;						call	init_pixel_write
;					endm


HALF_PIXEL_WRITE	macro	rowRegister
						movff	rowRegister,win_top
						call	half_pixel_write
					endm
