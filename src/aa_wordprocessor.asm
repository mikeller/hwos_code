;=============================================================================
;
;   File aa_wordprocessor.asm               * combined next generation V3.08.4l
;
;   Anti-aliased word processor
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;  2010-11-22 : [jDG] Creation
;  2010-12-01 : [jDG] Adding 3bits anti-aliased fonts
;  2010-12-30 : [jDG] Revised to put temp into ACCESSRAM0
;  2012-08-12 : [mH]  Moved font28 into bootloader section 0x1C000


;-----------------------------------------------------------------------------
; Attention:
; If the fonts are not in the same half of the PROM memory, TBLPTRU
; will be set wrong and gibberish font output will result
;-----------------------------------------------------------------------------


;-----------------------------------------------------------------------------
; Input registers:
; ----------------
;  buffer:26            string to print
;  font_size            font size (0=tiny, 1=small, 2=std, 3=medium, 4=large, 5=XL)
;  font_color           font color (8 bit)
;  win_top, win_leftx2  output position on screen
;  win_inverse          inverse video mode selection
;
; Trashed:
; --------
;  PRODH, PRODL         needed for array indexing
;  FSRx                 12 bits, used for indirect addressing
;
;-----------------------------------------------------------------------------


#include "hwos.inc"
#include "tft.inc"

	extern	aa_font16_block
	extern	aa_font28_block
	extern	aa_font34_block
	extern	aa_font48_block
	extern	aa_font90_block
	extern	aa_font92_block

	extern	convert_for_display2


;=============================================================================
aa_word		CODE
;=============================================================================


;------------------------------------------------------------------------------
; Setup Pointers for a Char
;
; Input    WREG       char to draw
;          font_size  selected font
;
; Output   aa_start    pointer to start of character bitmap
;          aa_end      pointer to end   of character bitmap
;          win_height  font height
;          AA_flags    font attributes
;
; Trashed  PRODH
;          PRODL
;          TBLPTR
;          TABLAT
;
aa_char_setup:
	movwf	PRODL					; save char to draw in PROD for later use
	movf	font_size,W				; get font size

	; 0: TINY font -------------------------------------------------------
	; Font TINY character folding...
aa_char_0:
	tstfsz	WREG					; requested tiny font?
	bra		aa_char_1				; NO

aa_char_00:
	movlw	LOW   aa_font16_block
	movwf	TBLPTRL
	movlw	HIGH  aa_font16_block
	movwf	TBLPTRH
	movlw	UPPER aa_font16_block
	movwf	TBLPTRU
	bra		aa_char_99

	; 1: SMALL font ------------------------------------------------------
	; Font SMALL character folding...
aa_char_1:
	decfsz	WREG					; requested small font?
	bra		aa_char_2				; NO

	movlw	LOW   aa_font28_block
	movwf	TBLPTRL
	movlw	HIGH  aa_font28_block
	movwf	TBLPTRH
	movlw	UPPER aa_font28_block
	movwf	TBLPTRU
	bra		aa_char_99

	; 2: STD font --------------------------------------------------------
	; Font STANDARD character folding...
aa_char_2:
	decfsz	WREG					; requested std font?
	bra		aa_char_3				; NO

	movlw	LOW   aa_font34_block
	movwf	TBLPTRL
	movlw	HIGH  aa_font34_block
	movwf	TBLPTRH
	movlw	UPPER aa_font34_block
	movwf	TBLPTRU
	bra		aa_char_99

	; 3: MEDIUM font -----------------------------------------------------
aa_char_3:
	decfsz	WREG				 	; requested medium font?
	bra		aa_char_4				; NO

	movlw	LOW   aa_font48_block
	movwf	TBLPTRL
	movlw	HIGH  aa_font48_block
	movwf	TBLPTRH
	movlw	UPPER aa_font48_block
	movwf	TBLPTRU
	bra		aa_char_99

	; 4: LARGE font ------------------------------------------------------
aa_char_4:
	decfsz	WREG				 	; requested large font?
	bra		aa_char_5				; NO

	movlw	LOW   aa_font90_block
	movwf	TBLPTRL
	movlw	HIGH  aa_font90_block
	movwf	TBLPTRH
	movlw	UPPER aa_font90_block
	movwf	TBLPTRU
	bra		aa_char_99

	; 5: EXTRA LARGE font ------------------------------------------------
aa_char_5:
	decfsz	WREG				 	; requested extra large font?
	bra		aa_char_00				; NO - illegal font code, default to tiny font

	movlw	LOW   aa_font92_block
	movwf	TBLPTRL
	movlw	HIGH  aa_font92_block
	movwf	TBLPTRH
	movlw	UPPER aa_font92_block
	movwf	TBLPTRU
	;bra	aa_char_99


	; Execute Font Block -------------------------------------------------
aa_char_99:
	; this is safe if all fonts are in the same code segment
	; (and this segment does not cross the 64 K boundary)
	movlw	UPPER aa_font16_block
	movwf	TBLPTRU

	; execute the character substitutions
aa_char_30:
	tblrd*+							; read FROM char
	movf	TABLAT,W				; get  FROM char
	bz		aa_char_32				; break at end of translation table

	tblrd*+							; read TO char
	cpfseq	PRODL					; FROM char == current char ?
	bra		aa_char_30				; NO  - different, loop
	movff	TABLAT, PRODL			; YES - make substitution
	bra		aa_char_30				;     - loop to consume the rest of the translations

	; make sure char is within the font set
aa_char_32:
	tblrd*+							; read code of first char in font set
	movf	TABLAT,W				; get  code of first char in font set
	subwf	PRODL,F					; compute code of current char - of first char
	tblrd*+							; read number of chars in font set
	movf	TABLAT,W				; get  number of chars in font set
	tblrd*+							; read default char
	cpfslt	PRODL					; current char beyond last char in font set?
	movff	TABLAT,PRODL			; YES - current char with default char

	; decode font height and anti-aliasing mode
	bcf		aa_antialias			; default to no AA
	tblrd*+							; read font height + AA flag
	movf	TABLAT,W				; get  font height + AA flag
	btfsc	WREG,7					; AA bit set?
	bsf		aa_antialias			; YES - then the font is AA
	andlw	0x7F					; strip the AA bit
	movwf	win_height				; store the font height

	; set PROM pointer to the char index
	movf	PRODL,W					; read back char
	mullw	2						; PROD = 2*(char - base), TBLPTR=idx
	movf	PRODL,W					; add to base address of font data
	addwf	TBLPTRL,F				; ...
	movf	PRODH,W					; ...
	addwfc	TBLPTRH,F				; ...

	; read pointers to character bitmap
	tblrd*+							; aa_start = PROM16(*tblptr++)
	movff	TABLAT,aa_start+0		; read low byte
	tblrd*+
	movff	TABLAT,aa_start+1		; and high byte

	tblrd*+							; aa_end = PROM16(*tblptr++)
	movff	TABLAT,aa_end+0			; read low byte
	tblrd*+
	movff	TABLAT,aa_end+1			; and high byte

	return							; done


;------------------------------------------------------------------------------
; Compute Character Width
; Input    aa_start, aa_end, win_width, win_height, AA_flags
; Output   width added to win_width
; Trashed  aa_bitlen, TBLPTR, TABLAT
;
aa_char_width:
	movff	aa_start+0, TBLPTRL		; TBLPTR = aa_start
	movff	aa_start+1, TBLPTRH		; ...
	clrf	aa_bitlen				; clear remaining pixels counter

	; read bitmap byte and decode length
aa_char_width_1:
 ifdef AA_BYTE_SWAP
	btg		TBLPTRL					; toggle low ptr bit
	tblrd*							; read bitmap data
	movf	TABLAT,W				; store to WREG
	btg		TBLPTRL					; toggle back
	tblrd*+							; do a dummy read to increment the pointer
	movwf	TABLAT					; restore TABLAT
 else
	tblrd*+							; read bitmap data
	movf	TABLAT,W				; store to WREG
 endif
	btfss	aa_antialias			; anti-aliased font ?
	bra		aa_char_width_10		; NO  - always 7 bit count
	btfss	WREG,7					; YES - none-white pixels?
	andlw	0x1F					;       YES - 5 bit count
aa_char_width_10:
	andlw	0x7F					; mask out none-white pixel flag
	incf	WREG,W					; WREG = repetition count
	addwf	aa_bitlen,F				; add to remaining pixels

	movf	win_height,W			; WREG -= height
	negf	WREG					; ...

	; this is a hand-made division by successive subtraction of the height
aa_char_width_2:
	addwf	aa_bitlen,F				; try to subtract win_height, does it fit?
	bn		aa_char_width_3			; NO  - done
	infsnz	win_width+0,F			; YES - do a 16 bit increment of the win_width
	incf	win_width+1,F			;     - ...
	bra		aa_char_width_2			;     - loop

aa_char_width_3:
	negf	WREG					; WREG = +height
	addwf	aa_bitlen,F				; restore true reminder

	; all pixel data processed?
	movf	TBLPTRL,W				; get TBLPTR, low  byte
	cpfseq	aa_end+0				; TBLPTR, low  byte == end pointer, low  byte?
	bra		aa_char_width_1			; NO  - loop
	movf	TBLPTRH,W				; YES - get TBLPTR, high byte
	cpfseq	aa_end+1				;     - TBLPTR, high byte == end pointer, high byte?
	bra		aa_char_width_1			;       NO  - loop
	return							;       YES - done


;------------------------------------------------------------------------------
; Compute String Width
; Input    buffer (NEEDS TO BE NULL TERMINATED)
; Output   win_width, win_height
; Trashed  PROD, TBLPTR, FSR2, aa_bitlen, aa_start, aa_end, AA_flags
;
aa_string_width:
	lfsr	FSR2, buffer			; FSR2 pointer to start of string
	clrf	win_width+0				; clear 16 bit width sum
	clrf	win_width+1				; ...

aa_string_width_1:
	movf	POSTINC2,W				; get character
	bz		aa_string_width99		; exit if null byte encountered

	rcall	aa_char_setup			; setup pointers for the char
	rcall	aa_char_width			; win_width += character width
	bra		aa_string_width_1		; loop

aa_string_width99:
	return							; done


;------------------------------------------------------------------------------
; Print a Character
; Input    aa_start, aa_end, win_height, win_invert, win_color1, win_color2
; Output   none
; Trashed  TBLPTR, TABLAT, PROD, aa_bitlen, AA_flags, aa_colorDir:2
;
aa_decode_char:
	movff	aa_start+0, TBLPTRL		; set TBLPTR to start of character data
	movff	aa_start+1, TBLPTRH		; ...

	; read bitmap byte and decode color & length
aa_decode_1:
 ifdef AA_BYTE_SWAP
	btg		TBLPTRL					; toggle low ptr bit
	tblrd*							; read bitmap data
	movf	TABLAT,W				; back-up TABLAT
	btg		TBLPTRL					; toggle back
	tblrd*+							; do a dummy read to increment the pointer
	movwf	TABLAT					; restore TABLAT
 else
	tblrd*+							; normal read...
	movf	TABLAT,W				; store copy to WREG
 endif
	btfss	aa_antialias			; anti-aliased font ?
	bra		aa_decode_10			; NO  - always 7 bit count
	btfss	WREG,7					; YES - none-white pixels?
	andlw	0x1F					;       YES - 5 bit count
aa_decode_10:
	andlw	0x7F					; mask out none-white pixel flag
	incf	WREG,W					; WREG = repetition count
	movwf	aa_bitlen				; repetition count --> aa_bitlen

	;---- COLOR DECODING -------------------------------------------------
	;
	;   Code    Normal    Inverse
	;   1xx        0%      100% : Managed by aa_decode_13
	;   011       25%       75%
	;   010       50%       50%
	;   001       75%       25%
	;   000      100%        0% : Managed by aa_decode_13, too

	movf	TABLAT,W				; get back pixel data
	btfss	aa_antialias			; anti-aliased font?
	bra		aa_decode_13			; NO - 1 bit case

	; asymmetry test: 1xx code is another case for 1 bit color
	; This has to be done before inverse video, because of the asymmetric processing!
	bn		aa_decode_13			; decode as none-aa

	; manage 000 special case
	andlw	0xE0					; select color bits, is it a 000 ?
	bz		aa_decode_13			; YES

	; apply reverse video, in a reversed way
	btfss	win_invert				; inverse video mode?
	sublw	0x80					; NO

	; extract color quarter and color half information
	bsf		aa_antialias			; set AA mode
	bcf		aa_color_quarter		; default to no color quarter
	btfsc	WREG,5					; color quarter encoded?
	bsf		aa_color_quarter		; YES - set flag
	bcf		aa_color_half			; default to no color half
	btfsc	WREG,6					; color half encoded?
	bsf		aa_color_half			; YES - set flag

	;---- 2 bit x RGB(16bits) computation --------------------------------
	clrf	PRODL					; clear accumulator
	clrf	PRODH					; ...

	; take color / 2 into aa_temp (max red = 15/31)
	rrcf	win_color1,W			; xRRRRxGG
	andlw	b'01111011'				; 0RRRR0GG (don't change C)
	movwf	aa_temp+0
	rrcf	win_color2,W			; GGGxBBBB
	andlw	b'11101111'				; GGG0BBBB
	movwf	aa_temp+1

	btfss	aa_color_half			; color half encoded?
	bra		aa_decode_12			; NO
	movff	aa_temp+0,PRODH			; YES - add color/2, TFT is big endian, so swap here
	movff	aa_temp+1,PRODL			;     - ...

aa_decode_12:
	btfss	aa_color_quarter		; color quarter encoded?
	bra		aa_decode_3				; NO

	; divide once again by 2 (max red = 7/31)
	rrcf	aa_temp+0,W				; xxRRRxxG
	andlw	b'00111001'				; 00RRR00G (don't change C)
	movwf	aa_temp+0
	rrcf	aa_temp+1,W				; GGGxxBBB
	andlw	b'11100111'				; GGG00BBB
	movwf	aa_temp+1

	movf	aa_temp+1,W				; add color/4
	addwf	PRODL,F					; NOTE: 7/31+15/31=22/31,
	movf	aa_temp+0,W				; hence components won't overlap
	addwfc	PRODH,F					; in right order, to propagate carry

aa_decode_12b:
	btfsc	screen_type2			; display type 2 ?
	call	convert_for_display2	; YES - convert 16 bit RGB b'RRRRRGGG GGGBBBBB' into 24 bit RGB b'RRRRRR00 GGGGGG00 BBBBBB00'
	bra		aa_decode_3				; continue

	; ---- simple BLACK and WHITE cases ------------------------------
aa_decode_13:						; got a 1xx or a 000 code
	btfsc	win_invert				; inverse video mode?
	xorlw	0x80					; YES - invert levels
	bn		aa_decode_2				; black pixel? -> YES

	; WHITE pixel (i.e. full color)
	movff	win_color1,PRODH		; set current drawing color (display is big endian)
	movff	win_color2,PRODL		; ...
	bra		aa_decode_12b			; post-process in case of display type 2

aa_decode_2:
	clrf	PRODH					; set drawing color to black
	clrf	PRODL					; ...
	clrf	win_color5				; set drawing color to black (display type 2)
	clrf	win_color4				; ...
	clrf	win_color3				; ...

aa_decode_3:
	;---- PIXEL WRITE LOOP -----------------------------------------------
	bsf		tft_rs					; Data!

	btfsc	screen_type2			; display 2 ?
	bra		aa_decode_3_display2	; YES
	btfsc	screen_type3			; display 3 ?
	bra		aa_decode_3_display3	; YES

	; Screen 1 or 0
	btfsc	less_io_cpu				; less I/O CPU?
	bra	aa_decode_3_display0and1_less_io	; YES

	movff	PRODH,PORTA				; move high byte to PORTA
	movff	PRODL,PORTH				; move low  byte to PORTH
aa_decode_3_display0and1:
	bcf		tft_nwr					; tick
	bsf		tft_nwr					; ...
	decfsz	aa_bitlen,F				; decrement length counter, became zero?
	bra		aa_decode_3_display0and1; NO  - loop
	bra		aa_decode_3_done		; YES -  done

aa_decode_3_display0and1_less_io:
	movff	PRODH,PORTA				; move high byte to PORTA
	bcf		tft_nwr					; tick
	bsf		tft_nwr					; ...
	movff	PRODL,PORTA				; move low  byte to PORTA
	bcf		tft_nwr					; tick
	bsf		tft_nwr					; ...
	decfsz	aa_bitlen,F				; decrement length counter, became zero?
	bra		aa_decode_3_display0and1_less_io; NO  - loop
	bra		aa_decode_3_done		; YES -  done
	
aa_decode_3_display2:
	movff	win_color5,PORTH		; move high byte to PORTH (display is big endian)
	bcf		tft_nwr					; tick
	bsf		tft_nwr					; ...
	movff	win_color4,PORTH		; move low byte to PORTH
	bcf		tft_nwr					; tick
	bsf		tft_nwr					; ...
	movff	win_color3,PORTH		; move low(est) byte to PORTH
	bcf		tft_nwr					; tick
	bsf		tft_nwr					; ...
	decfsz	aa_bitlen,F				; decrement length counter, became zero?
	bra		aa_decode_3_display2	; NO  - loop
	bra		aa_decode_3_done		; YES - done

aa_decode_3_display3:
	movff	PRODH,PORTH				; move high byte to PORTH (display is big endian)
	bcf		tft_nwr					; tick
	bsf		tft_nwr					; ...
	movff	PRODL,PORTH				; move low  byte to PORTH
	bcf		tft_nwr					; tick
	bsf		tft_nwr					; ...
	decfsz	aa_bitlen,F				; decrement length counter, became zero?
	bra		aa_decode_3_display3	; NO  - loop

aa_decode_3_done:
	;---- BYTE-CODE LOOP -------------------------------------------------
	; all pixel data processed?
	movf	TBLPTRL,W				; get TBLPTR, low  byte
	cpfseq	aa_end+0				; TBLPTR, low  byte == end pointer, low  byte?
	bra		aa_decode_1				; NO  - loop
	movf	TBLPTRH,W				; YES - get TBLPTR, high byte
	cpfseq	aa_end+1				;     - TBLPTR, high byte == end pointer, high byte?
	bra		aa_decode_1				;       NO  - loop
	return							;       YES - done


;------------------------------------------------------------------------------
; Print the Output Buffer to Screen
;
; Input   buffer - string to print (NULL TERMINATED)
; Output  chars printed to screen
;
	global	aa_wordprocessor
aa_wordprocessor:
	movf	font_color,W			; get selected font color (8 bit)
	call	TFT_set_color			; compute printing color (16 bit)
	rcall	aa_string_width			; set win_height and compute win_width:2
	call	TFT_box_write			; set up output box
	lfsr	FSR2,buffer				; set FSR2 to the start of the output buffer
	Index_out	0x22				; DATA block command (macro defined in tft.inc)

aa_wordprocessor_1:
	movf	POSTINC2,W				; read character from the buffer
	bz		aa_wordprocessor_99		; done if null byte encountered

	rcall	aa_char_setup			; setup pointers for the char
	rcall	aa_decode_char			; print character to screen
	bra		aa_wordprocessor_1		; loop

aa_wordprocessor_99:
	Index_out	0x00				; send end of bloc command
	bcf		win_invert				; terminate inverse printing
	return							; done

;------------------------------------------------------------------------------

	END
