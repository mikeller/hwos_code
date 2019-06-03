;=============================================================================
;
;   File aa_wordprocessor.asm                 combined next generation V3.03.1
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
;
; BUGS :
;  * If the three fonts are not in the same half of the PROM memory, TBLPTRU
;    will be badly set, and font48 or font90 will display gibberish...
;=============================================================================
;
; MEMORY FOOTPRINT:
;------------------
;
; wp_wordprocessor : 8   KB, including fonts
; aa_wordprocessor : 0.5 KB code
;                  + 3.5 KB aa_font28 (reduced to 99 chars)
;                  + 1.6 KB aa_font48
;                  + 2.2 KB aa_font90
;                  = 7.9 KB including fonts
;
; Input registers:
;  buffer:26            String to print
;  win_font             Font size (0=tiny, 1=small, 2=std, 3=medium, 4=large, 5=XL)
;  win_color1:2         16bits unpacked color
;  win_top, win_leftx2  Position on screen
;  win_inverse          Inverse video mode
;
; Available general purpose registers:
;  PRODH, PRODL         needed for array indexing
;  FSRx                 12bits, used for indirect addressing
;=============================================================================

#include "hwos.inc"
#include "tft.inc"

	extern	aa_font16_block
	extern	aa_font28_block
	extern	aa_font34_block
	extern	aa_font48_block
	extern	aa_font90_block

 IFDEF _huge_font
	extern	aa_font92_block
 ENDIF

	extern	convert_for_display2


aa_word		CODE

;=============================================================================

;------------------------------------------------------------------------------
; Setup pointers for a char:
; Inputs   WREG = char to draw, win_font
; Output   aa_start, aa_end, win_height, AA_flags
; Trashed  PRODH, PRODL, TBLPTR, TABLAT
;
aa_char_setup:
	movwf	PRODL					; save char into PROD for now
	movf	win_font,W				; get font number (updates Z flag)
	bnz		aa_char_1				; requested tiny font? (bra of no)

	; 0: TINY font -------------------------------------------------------
	; Font TINY character folding...
aa_char_0:
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
 IFDEF _huge_font
	decfsz	WREG				 	; requested large font?
	bra		aa_char_5				; NO
 ENDIF
	movlw	LOW   aa_font90_block
	movwf	TBLPTRL
	movlw	HIGH  aa_font90_block
	movwf	TBLPTRH
	movlw	UPPER aa_font90_block
	movwf	TBLPTRU
	bra		aa_char_99

 IFDEF _huge_font
	; 5: XTRA LARGE font -------------------------------------------------
aa_char_5:
	movlw	LOW   aa_font92_block
	movwf	TBLPTRL
	movlw	HIGH  aa_font92_block
	movwf	TBLPTRH
	movlw	UPPER aa_font92_block
	movwf	TBLPTRU
 ENDIF

	; Execute font block -------------------------------------------------
aa_char_99:
	; This is safe if all fonts are in the same code segment
	; (and that segment does not span the 64K edge...)
	movlw	UPPER aa_font16_block
	movwf	TBLPTRU

	; Proceed to character substitutions
aa_char_30:
	tblrd*+							; read FROM char
	movf	TABLAT,W				; get it, and set Z,N
	bz		aa_char_32				; branch if end of translation table reached

	tblrd*+							; read TO char
	cpfseq	PRODL					; FROM == current char ?
	bra		aa_char_30				; different -> loop
	movff	TABLAT, PRODL			; make substitution
	bra		aa_char_30				; loop

	; Make sure char is in the available range
aa_char_32:
	tblrd*+							; read first char
	movf	TABLAT,W				; get it
	subwf	PRODL,F					; (char - first) --> PRODL
	tblrd*+							; read nb chars
	movf	TABLAT,W				; nbchars --> WREG
	tblrd*+							; read default char
	cpfslt	PRODL					; char > WREG ?
	movff	TABLAT,PRODL			; replace PRODL

	; Decode font height and anti-aliasing mode
	bcf		aa_antialias			; default to no AA
	tblrd*+							; read font height + AA flag
	movf	TABLAT,W				; into WREG
	bnn		aa_char_34				; high bit set ?
	bsf		aa_antialias			; YES - then the font is AA
aa_char_34:
	andlw	0x7F					; keep just font height,
	movwf	win_height				; then save it (its a register)

	; Set PROM pointer to the char index
	movf	PRODL,W					; read back char
	mullw	2						; PROD = 2*(char - base), TBLPTR=idx
	movf	PRODL,W
	addwf	TBLPTRL,F				; add into TBLPTR (low byte)
	movf	PRODH,W
	addwfc	TBLPTRH,F				; and high byte

	; Read start and stop pointers
	tblrd*+							; aa_start = PROM16(*tblptr++)
	movff	TABLAT,aa_start+0		; read low byte
	tblrd*+
	movff	TABLAT,aa_start+1		; and high byte

	tblrd*+							; aa_end = PROM16(*tblptr++)
	movff	TABLAT,aa_end+0			; read low byte
	tblrd*+
	movff	TABLAT,aa_end+1			; and high byte

	return


;------------------------------------------------------------------------------
; Character width
; Input    aa_start, aa_end, win_width, win_height, AA_flags
; Output   width added to win_width
; Trashed  aa_bitlen, TBLPTR, TABLAT
;
aa_char_width:
	movff	aa_start+0, TBLPTRL		; TBLPTR = aa_start
	movff	aa_start+1, TBLPTRH
	clrf	aa_bitlen				; clear reminders...

	; Read bitmap byte, and decode length:
aa_char_width_1:

	ifdef AA_BYTE_SWAP
		btg		TBLPTRL				; toggle low ptr bit
		tblrd*
		movf	TABLAT,W			; store to WREG
		btg		TBLPTRL				; get is back
		tblrd*+						; then increment (but trash TABLAT)
		movwf	TABLAT				; then restore copy to TABLAT
	else
		tblrd*+						; normal read...
		movf	TABLAT,W			; store copy to WREG
	endif

	btfss	aa_antialias			; anti-aliased font ?
	bra		aa_char_width_10		; NO - always 7 bit count

	bn		aa_char_width_10		; none-white pixels?
	andlw	0x1F					; YES - 5 bit count
aa_char_width_10:
	andlw	0x7F					; NO  - 7 bit count
	incf	WREG 					; WREG = repetition count
	addwf	aa_bitlen,F				; add remaining pixels from last code

	movf	win_height,W			; WREG -= height
	negf	WREG

	; This is a hand-made division by successive subtraction of height
aa_char_width_2:
	addwf	aa_bitlen,F				; try to subtract win_height
	bn		aa_char_width_3			; if neg it was a bad idea...

	infsnz	win_width+0,F			; succeeded: do a 16 bit increment
	incf	win_width+1,F			; on the win_width counter
	bra		aa_char_width_2			; and loop

aa_char_width_3:
	negf	WREG					; WREG = +height
	addwf	aa_bitlen,F				; restore true reminder

	; Are we done ?
	movf	TBLPTRL,W				; compare TBLPTR to aa_end
	cpfseq	aa_end+0  
	bra		aa_char_width_1			; loop if LOW is different
	movf	TBLPTRH,W
	cpfseq	aa_end+1				; loop to if HIGH is different
	bra		aa_char_width_1
	return


;------------------------------------------------------------------------------
; String width
; Input    buffer (SHOULD BE NULL TERMINATED)
; Output   win_width, win_height
; Trashed  PROD, TBLPTR, FSR2, aa_bitlen, aa_start, aa_end, AA_flags
;
aa_string_width:
	lfsr	FSR2, buffer			; FSR2 pointer to start of string
	clrf	win_width+0				; clear width sum
	clrf	win_width+1				; (16 bit counter)

aa_string_width_1:
	movf	POSTINC2,W  			; WREG = *FSR2++
	bz		aa_string_width99		; exit if null byte encountered

	rcall	aa_char_setup			; setup aa_start / aa_end
	rcall	aa_char_width			; sum-up width into win_width
	bra		aa_string_width_1		; and loop

aa_string_width99:
	return


;------------------------------------------------------------------------------
; Decode a compressed char
; Input    aa_start, aa_end, win_height, win_invert, win_color1, win_color2
; Output   none
; Trashed  TBLPTR, TABLAT, PROD, aa_bitlen, AA_flags, aa_colorDir:2
;
aa_decode_char:
	movff	aa_start+0, TBLPTRL		; TBLPTR = aa_start
	movff	aa_start+1, TBLPTRH

	; Read bitmap byte, and decode color & length
aa_decode_1:

	ifdef AA_BYTE_SWAP
		btg		TBLPTRL				; toggle low ptr bit
		tblrd*
		movf	TABLAT,W			; store to WREG
		btg		TBLPTRL				; get is back
		tblrd*+						; then increment (but trash TABLAT)
		movwf	TABLAT				; then restore copy to TABLAT
	else
		tblrd*+						; normal read...
		movf	TABLAT,W			; store copy to WREG
	endif

	btfss	aa_antialias			; anti-aliased font?
	bra		aa_decode_10			; NO - always 7 bit count
	bn		aa_decode_10			; none-white pixels?
	andlw	0x1F					; Yes - 5 bit count
aa_decode_10:
	andlw	0x7F					; NO  - 7 bit count
	incf	WREG
	movwf	aa_bitlen				; repetition count --> aa_bitlen

	;---- COLOR DECODING -------------------------------------------------
	;
	;   Code    Normal    Inverse
	;   1xx        0%      100% : Managed by aa_decode_13
	;   011       25%       75%
	;   010       50%       50%
	;   001       75%       25%
	;   000      100%        0% : Managed by aa_decode_13, too
	;
	movf	TABLAT,W				; get back code
	btfss	aa_antialias			; anti-aliased font?
	bra		aa_decode_13			; NO - 1 bit case

	; Asymmetry test: 1xx code is another case for 1bit color.
	; This have to be done before inverse video, because
	; of the asymmetric processing!
	bn		aa_decode_13			; decode as none-aa

	; Manage 000 special case too:
	andlw	0xE0					; select color bits, is it a 000 ?
	bz		aa_decode_13			; YES

	; Apply reverse video, in a reversed way
	btfss	win_invert				; inverse video mode?
	sublw	0x80					; NO

	; Extract color quarter and color half information
	bsf		aa_antialias			; set AA mode
	bcf		aa_color_quarter		; default to no color quarter
	btfsc	WREG,5					; color quarter encoded?
	bsf		aa_color_quarter		; YES - set flag
	bcf		aa_color_half			; default to no color half
	btfsc	WREG,6					; color half encoded?
	bsf		aa_color_half			; YES - set flag

	;---- 2 bit x RGB(16bits) computation --------------------------------
	clrf	PRODL					; we will accumulate result here...
	clrf	PRODH

	; Take color div 2 into aa_temp. Max red = 15/31
	rrcf	win_color1,W			; xRRRRxGG
	andlw	b'01111011'				; 0RRRR0GG (don't change C)
	movwf	aa_temp+0
	rrcf	win_color2,W			; GGGxBBBB
	andlw	b'11101111'				; GGG0BBBB
	movwf	aa_temp+1

	btfss	aa_color_half
	bra		aa_decode_12

	movff	aa_temp+0,PRODH			; add color/2 if bit set
	movff	aa_temp+1,PRODL			; TFT is big endian, so swap here
aa_decode_12:
	btfss	aa_color_quarter
	bra		aa_decode_3

	; Divide it once again by 2. Max red = 7/31.
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
	btfss	screen_type2			; display 2?
	bra		aa_decode_3				; NO - done

	call	convert_for_display2	; convert 16 bit RGB b'RRRRRGGG GGGBBBBB' into 24 bit RGB b'RRRRRR00 GGGGGG00 BBBBBB00'

	bra		aa_decode_3				; done

	; ---- Simple BLACK and WHITE cases ------------------------------
aa_decode_13:						; got a 1xx or a 000 code...
	btfsc	win_invert				; inverse video mode ?
	xorlw	0x80					; YES - invert levels
	bn		aa_decode_2				; then test high bit

	; WHITE pixel (i.e. full color)
	movff	win_color1,PRODH		; current draw color
	movff	win_color2,PRODL		; remark: DISPLAY is big endian
	bra		aa_decode_12b

aa_decode_2:
	clrf	PRODH					; BLACK pixel
	clrf	PRODL
	clrf	win_color5
	clrf	win_color4
	clrf	win_color3

aa_decode_3:
	;---- PIXEL WRITE LOOP -----------------------------------------------
	bsf		tft_rs					; Data!

	btfsc	screen_type2			; display 2 ?
	bra		aa_decode_3_display2	; YES

	movff	PRODH,PORTA				; move high byte to PORTA
	movff	PRODL,PORTH				; move low  byte to PORTH
aa_decode_3_display0and1:
	bcf		tft_nwr
	bsf		tft_nwr					; tick
	decf	aa_bitlen,F
	bnz		aa_decode_3_display0and1
	bra		aa_decode_3_done

aa_decode_3_display2:
	movff	win_color5,PORTH		; move high byte to PORTH (DISPLAY is big endian)
	bcf		tft_nwr
	bsf		tft_nwr					; tick
	movff   win_color4,PORTH		; move low byte to PORTH
	bcf		tft_nwr
	bsf		tft_nwr					; tick
	movff   win_color3,PORTH		; move low(est) byte to PORTH
	bcf		tft_nwr
	bsf		tft_nwr					; tick
	decf	aa_bitlen,F
	bnz		aa_decode_3_display2

aa_decode_3_done:
	;---- BYTE-CODE LOOP -------------------------------------------------
	; are we done ?
	movf	TBLPTRL,W				; compare TBLPTR with aa_end
	cpfseq	aa_end+0
	bra		aa_decode_1				; loop if LOW is different
	movf	TBLPTRH,W
	cpfseq	aa_end+1				; loop to if HIGH is different
	bra		aa_decode_1
	return


;------------------------------------------------------------------------------
; Setup pointers for a char:
; Inputs : buffer : string to print (NULL TERMINATED)
; Output : TFT commands on port D + clocks
;
	global	aa_wordprocessor		; callable from C-code
aa_wordprocessor:
	rcall	aa_string_width			; set win_height, compute win_width:2
	call	TFT_box_write			; use that for the box

	; Restart the loop for each char to print
	lfsr	FSR2, buffer			; FSR2 points to the start of the string

	; DATA block command
	Index_out	0x22				; index_out is a macro defined in tft.inc

aa_wordprocessor_1:
	movf	POSTINC2,W				; WREG = *FSR2++
	bz		aa_wordprocessor_99		; exit if null byte encountered

	rcall	aa_char_setup			; setup aa_start / aa_end
	rcall	aa_decode_char			; write pixels to screen
	bra		aa_wordprocessor_1		; and loop

aa_wordprocessor_99:
	; END of bloc command
	Index_out	0x00
	return

	END
