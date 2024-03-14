;=============================================================================
;
;   File File color_processor.asm           * combined next generation V3.09.4l
;
;   Decompress and draw an image
;
;   Copyright (c) 2011, JD Gascuel, heinrichs weikamp gmbh, all right reserved.
;=============================================================================
; HISTORY
;  2010-12-13 : [jDG] Creation.
;  2010-12-30 : [jDG] Revised to put temp into ACCESSRAM0
;
; RATIONALS: The OSTC has a nice color screen, and a std geek attitude impose
;            to show off ... ;-)
;
; Inputs   TBLPTR points to the image description block.
;          win_top, win_leftx2 the Top/Leftx2 corner here to put the image.
; Outputs  None
; Trashed  TBLPTR, TABLAT, FSR2, PROD, win_width, win_height
;
; ImageBloc:
;       db  widthx2,  height
;       db  nbColors, encoding version
;       dw  color0, color1, color2, color3, ...
;       db  packed pixels...
;
; Limitations:
; * nbColors <= 126
; * image width is even
; * image left border is on even column, too
;
;
; Compressed format in encoding version 0 and 1:
; ----------------------------------------------
; - 1-3 bytes pixel repetition count, followed by 1 byte pixel color
; - bit 7 = 1: byte holds pixel count in bits 6-0
; - bit 7 = 0: byte holds pixel color in bits 6-0
; - all pixel count bytes accumulate:
;   - 1 byte  pixel count: 1xxxxxxx                   ->  7 bit pixel count
;   - 2 bytes pixel count: 1yyyyyyy 1xxxxxxx          -> 14 bit pixel count
;   - 3 bytes pixel count: 1zzzzzzz 1yyyyyyy 1xxxxxxx -> 21 bit pixel count
;
; A pixel repetition count of 0 means one single pixel will be drawn,
; a repetition count of 1 means two pixels will be drawn, and so on.
; The image is done when all pixels as of width x high parameters have been printed.
;
;
; Compressed format in encoding version 1:
; ----------------------------------------
; As above, but the image is done when a color index equaling 127 is encountered.
;
;
; Pixels are written column by column from left to right, with columns down first.
;
;-----------------------------------------------------------------------------

#include	"hwos.inc"
#include	"tft.inc"

	extern	convert_for_display2

;=============================================================================
color_proc	CODE
;=============================================================================

;-----------------------------------------------------------------------------
; Print a colored Bitmap Image
;
	global	color_image
color_image:
	tblrd*+							; read image width (in true width / 2)
	movff	TABLAT,win_width+0		; store in win_width, low  byte
	clrf	win_width+1				; clear    win_width, high byte
	tblrd*+							; read image height
	movff	TABLAT,win_height		; store in win_height
	rcall	get_colors				; read the colors
	tstfsz	encoding_format			; image encoded in version 0 format?
	bra		color_image_1			; NO

	; image encoding version 0 format: compute overall number of pixels - 1
	movf	win_width,W				; get           image width (/2) into WREG
	mulwf	win_height				; multiply with image hight
	movff	PRODL,overall_pixels+0	; store product, low  byte
	movff	PRODH,overall_pixels+1	; ...            high byte
	clrf	overall_pixels+2		; clear product, upper byte
	bcf		STATUS,C				; clear carry flag
	rlcf	overall_pixels+0		; multiply by 2 via shift left, low   byte
	rlcf	overall_pixels+1		; ...                           high  byte
	rlcf	overall_pixels+2		; ...                           upper byte
	clrf	WREG					; decrement by 1 to ease all pixel done detection
	decf	overall_pixels+0,F		; ...
	subwfb	overall_pixels+1,F		; ...
	subwfb	overall_pixels+2,F		; ...

color_image_1:
	bcf		STATUS,C				; clear carry flag
	rlcf	win_width+0				; multiply width x 2 to get the true box width
	rlcf	win_width+1				; ...
	call	TFT_box_write			; set output box
	movlw	0x22				; frame memory data write start
	btfsc	screen_type4
	movlw	0x2C				; Start Writing Data to GRAM (Display 4)
	call	TFT_CmdWrite
color_image_loop_xy:
	; prepare to read next pixel count and color
	clrf	pixel_count+0			; clear number of pixels
	clrf	pixel_count+1			; ...

color_image_read_byte:
	tblrd*+							; get next image data byte
	btfss	TABLAT,7				; high bit cleared ?
	bra		color_image_decode_color; YES - this is color data
	;bra	color_image_decode_count; NO  - this is pixel count data

color_image_decode_count:
	; decode pixel repetition count
	rlcf	TABLAT,F				; drop high bit
	movlw	.7						; move 7 bits
color_image_decode_count_loop:
	rlcf	TABLAT,F						; get upper bit into carry
	rlcf	pixel_count+0,F					; push bit into pixel count (16 bit operation)
	rlcf	pixel_count+1,F					; ...
	decfsz	WREG							; decrement loop counter, all bits done?
	bra		color_image_decode_count_loop	; NO  - loop
	bra		color_image_read_byte			; YES - decode next byte

color_image_decode_color:
	; check for end-of-image tag (color index = 0x7F)  --  it is assumed that no version 0 image contains 127 colors...
	movlw	0x7f					; encoding for end-of-image
	cpfslt	TABLAT					; color index < end-of-image tag?
	return							; NO - done

	; translate color index into pixel color
	lfsr	FSR2,buffer				; set FSR2 pointer to base address of color table
	rlncf	TABLAT,W				; get color index * 2 into WREG
	movwf	FSR2L					; adjust pointer to selected color
	movff	POSTINC2,PRODL			; read color, low  byte
	movff	POSTINC2,PRODH			; read color, high byte

	tstfsz	encoding_format			; image encoded in version 0 format?
	bra		color_image_pixel		; NO

	; image encoding version 0 format: subtract pixel count from the overall number of pixels to do
	movf	pixel_count+0,W			; YES - 24 bit subtraction, low   byte
	subwf	overall_pixels+0,F		; ...
	movf	pixel_count+1,W			; ...                       high  byte
	subwfb	overall_pixels+1,F		; ...
	movlw	.0						; ...                      upper byte
	subwfb	overall_pixels+2,F		; ...

color_image_pixel:
	; prepare sending the pixels to display
	infsnz	pixel_count+0			; increment pixel repetition count by 1
	incf	pixel_count+1			; ...
	incf	pixel_count+1			; because decrement is done first, increment high byte once more
	bsf		tft_rs,0				; RS_H data
	bcf		INTCON,GIE				; disable all interrupts

	btfsc	screen_type2			; display type 2 ?
	bra		color_image_display2	; YES
	btfsc	screen_type3			; display type 3 ?
	bra		color_image_display3	; YES
	
	; Screen 0 or 1 or 4
	btfsc	less_io_cpu			; less I/O CPU?
	bra	color_image_pixel1_loop_less_io ; YES
	    
	movff	PRODH,PORTA				; NO  - move color high byte to PORTA
	movff	PRODL,PORTH				;     - move color low  byte to PORTH

color_image_pixel1_loop:
	bcf		tft_nwr					; toggle write signal
	bsf		tft_nwr					; ...
	decfsz	pixel_count+0			; decrement pixel counter, low  byte
	bra		color_image_pixel1_loop	; loop if not zero
	decfsz	pixel_count+1			; decrement pixel counter, high byte
	bra		color_image_pixel1_loop	; loop if not zero
	bra		color_image_pixel_com	; all pixels transmitted

color_image_pixel1_loop_less_io:	
    	movff	PRODH,PORTA				; NO  - move color high byte to PORTA
	bcf		tft_nwr					; toggle write signal
	bsf		tft_nwr					; ...
	movff	PRODL,PORTA				;     - move color low  byte to PORTH
	bcf		tft_nwr					; toggle write signal
	bsf		tft_nwr					; ...
	decfsz	pixel_count+0			; decrement pixel counter, low  byte
	bra		color_image_pixel1_loop_less_io	; loop if not zero
	decfsz	pixel_count+1			; decrement pixel counter, high byte
	bra		color_image_pixel1_loop_less_io	; loop if not zero
	bra		color_image_pixel_com	; all pixels transmitted
	
color_image_display2:
	call	convert_for_display2	; convert 16 bit RGB b'RRRRRGGG GGGBBBBB'
									; into    24 bit RGB b'RRRRRR00 GGGGGG00 BBBBBB00'
color_image_pixel2_loop:
	movff	win_color5,PORTH		; move upper byte to PORTH (DISPLAY is big endian)
	bcf		tft_nwr					; toggle write signal
	bsf		tft_nwr					; ...
	movff	win_color4,PORTH		; move high  byte to PORTH
	bcf		tft_nwr					; toggle write signal
	bsf		tft_nwr					; ...
	movff	win_color3,PORTH		; move low   byte to PORTH
	bcf		tft_nwr					; toggle write signal
	bsf		tft_nwr					; ...
	decfsz	pixel_count+0			; decrement pixel counter, low  byte
	bra		color_image_pixel2_loop	; loop if not zero
	decfsz	pixel_count+1			; decrement pixel counter, high byte
	bra		color_image_pixel2_loop	; loop if not zero
	bra		color_image_pixel_com	; all pixels transmitted

color_image_display3:
	movff	PRODH,PORTH				; move color high byte to PORTH
	bcf		tft_nwr					; toggle write signal
	bsf		tft_nwr					; ...
	movff	PRODL,PORTH				; move color high byte to PORTH
	bcf		tft_nwr					; toggle write signal
	bsf		tft_nwr					; ...
	decfsz	pixel_count+0			; decrement pixel counter, low  byte
	bra		color_image_display3	; loop if not zero
	decfsz	pixel_count+1			; decrement pixel counter, high byte
	bra		color_image_display3	; loop if not zero
;	bra		color_image_pixel_com	; all pixels transmitted

color_image_pixel_com:
	bsf		INTCON,GIE				; re-enable all interrupts

	tstfsz	encoding_format			; image encoded in version 0 format?
	bra		color_image_loop_xy		; NO - loop to process next byte from image data

	; image encoding version 0 format: step counter
	clrf	WREG					; make a 24 bit decrement
	decf	overall_pixels+0		; ...
	subwfb	overall_pixels+1,F		; ...
	subwfb	overall_pixels+2,F		; ...
	bnn		color_image_loop_xy		; all pixels done? NO  - loop
	return							;                  YES - done


;-----------------------------------------------------------------------------
; Helper Function - set up Pixel-Color Look-Up Table
;
	global	get_colors
get_colors:
	tblrd*+							; read number of color indexes
	movf	TABLAT,W				; store in lo
	tblrd*+							; read image encoding format
	movff	TABLAT,encoding_format	; store encoding format
	lfsr	FSR2,buffer				; load base address of the look-up table
get_colors_loop:
	tblrd*+							; read color from stored image, low  byte
	btfss	use_custom_colors		; shall use custom colors?
	movff	TABLAT,POSTINC2			; NO - copy color read to buffer
	tblrd*+							; read color from stored image, high byte
	btfss	use_custom_colors		; shall use custom colors?
	movff	TABLAT,POSTINC2			; NO - copy color read to buffer
	decfsz	WREG					; decrement loop counter, done?
	bra		get_colors_loop			; NO  - loop
	bcf		use_custom_colors		; YES - clear custom colors request
	return							;     - done

;-----------------------------------------------------------------------------

	END
