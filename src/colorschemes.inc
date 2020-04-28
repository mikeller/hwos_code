;=============================================================================
;
;   File colorschemes.inc                   * combined next generation V3.09.5
;
;=============================================================================


;-----------------------------------------------------------------------------
; Font Color Selection - fixed Colors

FONT_COLOR_STANDARD		macro
	setf	font_color							; full white
	endm

FONT_COLOR	macro	font_color_input
	movlw	font_color_input					; 8 bit color
	movwf	font_color
	endm


;-----------------------------------------------------------------------------
; 8 Bit fixed Color Definitions
;
;										b'RRRGGGBB'
;										-----------
#DEFINE color_red						b'11100000'	; (7,0,0)
#DEFINE color_dark_red					b'10000101'	; (4,1,1)
#DEFINE color_violet					b'11101011'	; (7,2,3)
#DEFINE color_blue						b'11000111'	; (6,1,3)
#DEFINE color_green						b'00011100'	; (0,7,0)
#DEFINE color_greenish					b'00111110'	; (1,7,2)
#DEFINE color_dark_green				b'00111001'	; (1,6,1)
#DEFINE color_yellow					b'11111101'	; (7,7,1)
#DEFINE color_white						b'11111111'	; (7,7,3)
#DEFINE color_black						b'00000000'	; (0,0,0)
#DEFINE color_deepblue					b'00000010'	; (0,0,2)
#DEFINE color_grey						b'11011111'	; (6,7,3)
#DEFINE color_cyan						b'11011111'	; (6,7,3)
#DEFINE color_lightblue					b'11011011'	; (6,7,3)
#DEFINE color_orange					b'11111000'	; (7,6,0)
#DEFINE color_pink						b'11111010'	; (7,6,2)


;-----------------------------------------------------------------------------
; Font Color Selection - pallet-based Colors

; the use of pallet-based colors requires the prior call of
;
; - TFT_load_std_color_pallet   to load the standard color pallet, or
; - TFT_load_dive_color_pallet  to load the dive     color pallet
;
; Attention: the following macros must resolve to single commands!


FONT_COLOR_MASK			macro					; labels and fixed items
	movff	pallet_color_mask,font_color
	endm

FONT_COLOR_DISABLED		macro					; disabled & outdated items
	movff	pallet_color_disabled,font_color
	endm

FONT_COLOR_MEMO			macro					; information & values within normal range,
	movff	pallet_color_memo,font_color		; things without a need to react upon
	endm

FONT_COLOR_ADVICE		macro					; advices to do something, but without
	movff	pallet_color_advice,font_color		; essential need to actually do it
	endm

FONT_COLOR_ATTENTION	macro					; important things to be aware of and
	movff	pallet_color_attention,font_color	; that develop towards a warning
	endm

FONT_COLOR_WARNING		macro					; important things with immediate
	movff	pallet_color_warning,font_color		; need to react upon
	endm


;-----------------------------------------------------------------------------
; 8 Bit Pallet Color Definitions
;
; => see 'pallet_table' in tft_outputs.asm
;

;-----------------------------------------------------------------------------
