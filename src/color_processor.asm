;=============================================================================
;
;   File File color_processor.asm									## V2.98c
;
;   Decompress and draw an image.
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;  2010-12-13 : [jDG] Creation.
;  2010-12-30 : [jDG] Revised to put temp into ACCESSRAM0
;
; RATIONALS: The OSTC have a nice color screen, and a std geek attitude impose
;            to show off ... ;-)
;
; Inputs: TBLPTR points to the image description block.
;         win_top, win_leftx2 the Top/Leftx2 corner here to put the image.
; Outputs: None.
; Trashed: TBLPTR, TABLAT, FSR2, PROD, win_width, win_height
;
; ImageBloc:
;       db  widthx2,  height
;       db  nbColors, 0     ; 0 = unused yet, should remain 0 to keep packing happy
;       dw  color0, color1, color2, color3, ...
;       db  packed pixels...
;
; Limitations:
; * nbColors <= 127
; * image width should be even
; * image left border should be on even position, too
;
; Compressed format:
; - 1-3 bytes pixel count, followed by 1 byte pixel color
; - bit 7 = 1: byte holds pixel count in bits 6-0
; - bit 7 = 0: byte holds pixel color in bits 6-0
; - all pixel count bytes accumulate:
;   - 1 byte  pixel count: 1xxxxxxx                   ->  7 bit pixel count
;   - 2 bytes pixel count: 1yyyyyyy 1xxxxxxx          -> 14 bit pixel count
;   - 3 bytes pixel count: 1zzzzzzz 1yyyyyyy 1xxxxxxx -> 21 bit pixel count
;
; Pixels are written column by column from left to right, with columns down first.
;
;-----------------------------------------------------------------------------

#include	"hwos.inc"
#include	"tft.inc"

color_proc		CODE

;-----------------------------------------------------------------------------
; Note: some variables (win_width, win_height) are in BANK 0 !

	global	color_image
color_image:
	banksel	common					; Bank 1, just to be sure...

	;---- Get image size -----------------------------------------------
	tblrd*+
	movff	TABLAT,win_width
	tblrd*+
	movff	TABLAT,win_height

	; Compute width * height * 2 : the number of pixels to write.
	clrf	img_pixels+2
	movf	win_width,W				; Compute number of pixels to draw
	mulwf	win_height				; 0 .. 160x240
	bcf		STATUS,C				; BEWARE: mulwf does not reset carry flag!
	rlcf	PRODL					; x2 --> 0 .. 320x240, might be > 0xFFFF
	rlcf	PRODH
	movff	PRODL, img_pixels+0
	movff	PRODH, img_pixels+1
	rlcf	img_pixels+2			; Get the upper bit in place

	clrf	WREG					; Decrement count to ease end detection
	decf	img_pixels+0,F
	subwfb	img_pixels+1,F
	subwfb	img_pixels+2,F

	;---- Send window command --------------------------------------------
	clrf	win_width+1				; x2 on width, for the true box size
	rlcf	win_width+0
	rlcf	win_width+1
	call	TFT_box_write
	Index_out 0x22

	;---- Read the colors ------------------------------------------------
	rcall	get_colors

	;---- Decode pixels --------------------------------------------------
color_image_loop_xy:
	; Get pixel count
	clrf	img_count+0
	clrf	img_count+1

	;---- Decode repetition count
color_image_decode_1:
	tblrd*+							; Get one byte

	btfss	TABLAT,7				; High bit cleared ?
	bra		color_image_decode_2	; YES: this is a color byte

	rlcf	TABLAT,F				; Drop high bit.
	movlw	.7						; Move 7 bits
color_image_decode_3:
	rlcf	TABLAT,F				; Get bit into carry
	rlcf	img_count+0,F			; Push into pixel count
	rlcf	img_count+1,F
	decfsz	WREG
	bra		color_image_decode_3	; and loop for each 7 bits
	bra		color_image_decode_1	; Decode next byte

color_image_decode_2:
	;---- Get pixel color into PROD
	movf	TABLAT,W				; Get color index
	addwf	WREG					; *2
	lfsr	FSR2,buffer				; Reinitialize color table
	movff	WREG,FSR2L				; LOW(buffer) == 0
	movff	POSTINC2,PRODL
	movff	POSTINC2,PRODH

	; Subtract count-1 from the number of pixel we should do.
	movf	img_count+0,W			; Make a 24bit subtraction
	subwf	img_pixels+0,F
	movf	img_count+1,W
	subwfb	img_pixels+1,F
	movlw	0
	subwfb	img_pixels+2,F

	infsnz	img_count+0				; Increment count
	incf	img_count+1

        ; Loop sending pixel color
        incf    img_count+1             ; Because we decrement first, should add one here !
        bsf     tft_rs,0    ; RS_H				; Data
	bcf	INTCON,GIE
	
color_image_loop_pixel:	
	btfsc	screen_type2		; Display 2?
	bra	color_image_display2		; Yes
	
    	movff	PRODH,PORTA	; Move high byte to PORTA
        movff	PRODL,PORTH	; Move low byte to PORTH
        bcf		tft_nwr
        bsf		tft_nwr
	decfsz  img_count+0
        bra     color_image_loop_pixel
        decfsz  img_count+1
        bra     color_image_loop_pixel
	bra	color_image_loop_pixel2
	
color_image_display2:
    extern  convert_for_display2
	call	convert_for_display2	; Convert 16Bit RGB b'RRRRRGGG GGGBBBBB' into 24Bit RGB b'RRRRRR00 GGGGGG00 BBBBBB00'
color_image_display2_loop:	
    	movff   win_color5,PORTH		; Move high byte to PORTH (DISPLAY is bigendian)
        bcf		tft_nwr
        bsf		tft_nwr
        movff   win_color4,PORTH		; Move low byte to PORTH
        bcf		tft_nwr
        bsf		tft_nwr
        movff   win_color3,PORTH        ; Move low(est) byte to PORTH
        bcf		tft_nwr
        bsf		tft_nwr
	decfsz  img_count+0
        bra     color_image_display2_loop
        decfsz  img_count+1
        bra     color_image_display2_loop

color_image_loop_pixel2:
        bsf	INTCON,GIE
        ; And count (on a 24bit counter)
        clrf    WREG                    ; Make a 24bit decrement.
        decf    img_pixels+0
        subwfb  img_pixels+1,F
        subwfb  img_pixels+2,F

        bnn     color_image_loop_xy     ; Not finished ? loop...

        ;---- Closeup --------------------------------------------------------        
;        Index_out 0x00
        return


	global	get_colors
get_colors:
	tblrd*+							; read number of image colors
	movff	TABLAT,lo				; store in lo
	tblrd*+							; skip one spare byte (future flags ?)
	movf	lo,W
	lfsr	FSR2,buffer				; set up buffer as storage for the colors
get_colors_loop:
	tblrd*+
	btfss	use_custom_colors		; shall custom colors be used?
	movff	TABLAT,POSTINC2			; NO
	tblrd*+
	btfss	use_custom_colors		; shall custom colors be used?
	movff	TABLAT,POSTINC2			; NO
	decfsz	WREG
	bra		get_colors_loop

	bcf		use_custom_colors		; clear custom colors request
	return

	END
