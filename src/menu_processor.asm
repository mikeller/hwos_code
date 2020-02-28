;=============================================================================
;
;   File menu_processor.asm                   combined next generation V3.08.6
;
;   Routines to handle all hwOS graphic/text menus.
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;   2012-11-02 : [jDG] Cleanup for hwOS: removed icons. Added scrolling.
;                But need a font with lower/upper alpha chars...

#include "hwos.inc"
#include "convert.inc"
#include "strings.inc"
#include "tft.inc"
#include "varargs.inc"
#include "start.inc"
#include "surfmode.inc"
#include "divemode.inc"
#include "tft_outputs.inc"
#include "eeprom_rs232.inc"
#include "adc_lightsensor.inc"
#include "i2c.inc"
#include "rtc.inc"
#include "wait.inc"


; NOTE: needs to be identical in .inc and .asm !
#define MENU_LINES_MAX			.7			; maximum number of lines per screen
#define MENU_TITLE_FONT			WIN_STD		; font needs to contain lower and UPPER chars
#define MENU_LINE_FONT			WIN_SMALL	; font needs to contain lower and UPPER chars
#define MENU_LEFT				.20			; position of first menu item
#define MENU_HEIGHT				.27			; spacing between menu lines
#define MENU_VCENTER			.125		; position on screen
#define MENU_LINE_MAX_LENGTH	.20			; length in characters
#define option_item				proc_item


	extern	aa_wordprocessor
	extern	option_inc
	extern	option_draw
	extern	TFT_clear_divemode_menu
	extern	TFT_divemask_color
	extern	rtc_set_rtc
	extern	divemode_option_divemenu_return
	extern	TFT_fillup_with_spaces


menu_proc	CODE

;=============================================================================
; menu handler
;
; Input:    TBLPTR = addr of menu block

	global	menu_processor
menu_processor:
;	btfss	divemode						; in dive mode?
;	call	request_speed_fastest			; NO  - request CPU speed change to fastest speed
	;---- Read menu block ------------------------------------------------
	VARARGS_BEGIN							; read inline PROM data
	clrf	STKPTR							; never return from here
	VARARGS_GET8	item_max				; get number of items
	VARARGS_GET8	menu_flags				; get flags
	VARARGS_GET24	menu_title				; get pointer to menu title
	VARARGS_GET8	menu_center				; vertical position
	movff	TBLPTRL, menu_block+0			; save base address for menu_read_item
	movff	TBLPTRH, menu_block+1			; ...
	movff	TBLPTRU, menu_block+2			; ...
	btfss	divemode						; in dive mode?
	bra		menu_processor0					; NO

	; Required for menus with less entries than the calling menu but not so nice when setting up gas 6.... mH
	movlw	.1
	cpfsgt	menu_pos_cur					; only if menu_pos_cur = 1...
	call	TFT_clear_divemode_menu			; ... clear the menu!
	; Draw one frame around the dive mode menu
	call	TFT_divemask_color
	WIN_FRAME_COLOR16 dm_menu_row, dm_menu_lower, dm_menu_left ,dm_menu_right	; top, bottom, left, right
	call	TFT_standard_color

	bra		menu_processor1					; skip next code segment in dive mode

menu_processor0:
	;---- draw menu title ------------------------------------------------
	clrf	CCP1CON							; stop PWM
	bcf		PORTC,2							; pull PWM out to GND
	call	TFT_ClearScreen
	rcall	menu_processor_title
	rcall	menu_processor_bottom_line

menu_processor1:
	WIN_FONT FT_SMALL

	;---- Select menu type -----------------------------------------------
	bra		menu_vertical


;=============================================================================
; draw menu bottom line
;
menu_processor_bottom_line:
	;---- Draw bottom line -----------------------------------------------
	TEXT_TINY .5,         .240-.16, tNext
	TEXT_TINY .160-.6*.6, .240-.16, tEnter
	goto	TFT_standard_color				; ...and return

;=============================================================================
; (re-)draw menu title
;
menu_processor_title:
	WIN_BOX_BLACK   .2,.23,.0,.159			; clear menu title
	MENU_TITLE_FONT .0, .2					; menu title positioning
	btfss	menu_flags,0					; static or dynamic title?
	bra		menu_processor_static_title		; static  title
	rcall	menu_processor_call_title		; dynamic title - add gas, detail and color
	bra		menu_processor_title_1

menu_processor_static_title:
	movff	menu_title+0,FSR1L				; just copy string
	movff	menu_title+1,FSR1H
	call	strcpy_text

menu_processor_title_1:
	WIN_COLOR color_greenish
	movf	FSR2L,W							; get title length
	mullw	.9								; convert to half pixels
	bcf		STATUS,C						; clear carry
	rrcf	PRODL							; /2
	movf	PRODL,W							; back to WREG
	sublw	.80								; 80 - width
	movwf	win_leftx2						; aligned to center
	movlw	.0								; string termination code
	movff	WREG,buffer+.17					; limit to 17 chars (std font max.)
	call	aa_wordprocessor
	call	TFT_standard_color
	return

;=============================================================================
; Call dynamic proc for menu title:

menu_processor_call_title:
	movff	menu_title+2,PCLATU				; execute computed goto
	movff	menu_title+1,PCLATH
	movf	menu_title+0,W
	movwf	PCL

;=============================================================================
; Restart with first icon/line selected
;
	global	menu_processor_reset
menu_processor_reset:
	clrf	menustack						; clear                 first stack position
	clrf	menustack_pointer				; set stack pointer  to first stack position
	clrf	selected_item					; set last menu item to first item
	return


	global	menu_processor_double_pop
	global	menu_processor_pop
menu_processor_double_pop:
	decf	menustack_pointer,F				; decrement stack pointer
menu_processor_pop:
	decf	menustack_pointer,F				; decrement stack pointer
	btfsc	menustack_pointer,7				; did the stack pointer under-run?
	clrf	menustack_pointer				; YES - reset stack pointer to first stack position
	movf	menustack_pointer,W				; load stack pointer into WREG
	lfsr	FSR2,menustack					; load base  address of menu stack
	movff	PLUSW2,selected_item			; retrieve menu item from stack
	return									; done


menu_processor_push:
	lfsr	FSR2,menustack					; load base  address of menu stack
	movf	menustack_pointer,W				; load stack pointer into WREG
	movff	selected_item,PLUSW2			; save menu item to stack
	incf	menustack_pointer,W				; increment stack pointer, park result in WREG
	btfss	WREG,3							; result < 8 ?
	movwf	menustack_pointer				; YES - update stack pointer
	clrf	selected_item					; set to first item in new menu
	return									; done


;---- Execute menu selection -------------------------------------------------
do_menu_item:
	bcf		switch_right					; clear left-over button event
	movf	selected_item,W					; reread proc address from table
	rcall	menu_read_item					; (destroys PROD)
	movff	selected_item,PRODL				; pass along selected line
	rcall	menu_processor_push				; remember where we got from (clears selected_item)
	movff	proc_item+2,PCLATU				; then execute computed goto
	movff	proc_item+1,PCLATH
	movf	proc_item+0,W
	movwf	PCL

;=============================================================================
; Get current item from table.
;
; Input  : Item number in WREG, menu_block.
; Output : icon_large, text_item, proc_item 16bits pointers.
; Trashed: PROD, WREG
;
menu_read_item:
	mullw	.10								; 10 bytes per item
	movf	PRODL,W							; then do a 24 bits add
	addwf	menu_block+0,W					; with menu_block, and
	movwf	TBLPTRL							; setup TBLPTR
	movf	PRODH,W
	addwfc	menu_block+1,W
	movwf	TBLPTRH
	movlw	0
	addwfc	menu_block+2,W
	movwf	TBLPTRU
	VARARGS_GET8	value_type				; read 10 bytes of item data
	VARARGS_GET24	dynamic_item
	VARARGS_GET24	proc_item
	VARARGS_GET8	WREG					; skip dummy byte
	VARARGS_GET16	text_item

	return

;=============================================================================
; Vertical menu - set of line/value to choose from,
;                 entry point to update lines already shown
;
	global	menu_vertical
menu_vertical:
	rcall	menu_draw_lines					; always re-draw whole menu
	movlw	CCP1CON_VALUE					; see hwos.inc
	btfss	divemode						; in dive mode?
	movwf	CCP1CON							; NO - power-on backlight

menu_vertical_1:
	movf	selected_item,W					; copy current menu item selection to WREG
	rcall	menu_read_item					; get current menu item data
	movf	proc_item+0,W					; check if proc address is NULL
	iorwf	proc_item+1,W
	bz		next_line_menu					; YES - not selectable
	btfss	divemode						; in dive mode?
	rcall	menu_draw_selected_line			; NO
	btfss	imprint_time_date				; currently imprinting the current time & date?
	bra		menu_line_loop_pre1				; NO
	btfss	switch_right					; YES - right button pressed, i.e. time or date changed?
	bra		menu_line_loop_pre1				;       NO
	call	TFT_show_time_date_menu_fast	;       YES - show a fast response on the screen (may momentarily show an illegal day/month combination)
	call	rtc_set_rtc						;           - update time and date on RTC module (corrects illegal day/month combinations)

menu_line_loop_pre1:
	btfsc	imprint_color_schemes			; in the color scheme menu?
	call	TFT_show_color_schemes			; YES - update the color schemes

menu_line_loop_pre2:
	bcf		switch_right					; clear left-over right button event
	bcf		switch_left						; clear left-over left  button event

menu_line_loop_pre3:
	btfsc	divemode						; in dive mode?
	goto	divemode_option_divemenu_return	; YES - return to it
	;bra	menu_line_loop_surface			; NO  - proceed to surface mode dispatcher

; dispatcher for surface mode menus
menu_line_loop_surface:
	call	reset_timeout_surfmode			; reset timeout
menu_line_loop:
	call	housekeeping					; handle data imprinting, screen dump request, timeout and entering dive mode
	btfsc	switch_right					; right button pressed?
	bra		do_line_menu					; YES - type dependent
	btfsc	switch_left						; left button pressed?
	bra		next_line_menu					; YES - goto next item
	bra		menu_line_loop					; NO to both - loop


;---- Move to menu's next line
next_line_menu:
	bcf		switch_left						; clear button event
	incf	selected_item,F					; select next item
	movf	selected_item,W					; copy item number to WREG
	cpfseq	item_max						; item number == max ?
	bra		menu_vertical_1					; NO  - redraw cursor
	clrf	selected_item					; YES - wrap-around to first item
	bra		menu_vertical_1					; then redraw cursor

	global	do_line_menu
do_line_menu:
	decf	menu_pos_cur,W					; menu_processor needs 0-5
	btfsc	divemode						; in dive mode?
	movwf	selected_item					; YES - set selected item from WREG
	movf	selected_item,W					; read selected descriptor
	rcall	menu_read_item
	movf	value_type,W					; switch on data type
	bz		menu_do_line_call				; CALL
	dcfsnz	WREG
	bra		menu_do_line_call				; STRING: do as call
	dcfsnz	WREG
	bra		menu_do_line_option				; OPTION
	dcfsnz	WREG
	bra		menu_do_line_call				; DYNAMIC: do as call
	bra		menu_line_loop_pre3				; else do nothing

;---- CALL
menu_do_line_call:
	rcall	do_menu_item					; same as icon menu: calculated goto
	rcall	menu_processor_pop				; back to same line,
	bra		menu_vertical					; then continue into menu...

;---- Call option specific increment subroutine
menu_do_line_option:
	movff	option_item+0,FSR0L				; get option handle
	movff	option_item+1,FSR0H
	call	option_inc						; increment
	movff	selected_item,PRODL				; pass selection to callback
	rcall	menu_text_call
	bra		menu_vertical					; redraw all lines

;-----------------------------------------------------------------------------

	global	menu_draw_lines_divemode		; entry point for re-drawing of the menu to update color-coding of gases
menu_draw_lines_divemode:
	movlw	dm_menu_item1_row
	movff	WREG,win_top
	movlw	dm_menu_item1_column
	movff	WREG,win_leftx2
	clrf	start_item
	movff	item_max,menu_pos_max			; copy item_max for dive mode cursor routine
	bra		menu_draw_lines_2

menu_draw_lines:
	btfsc	divemode						; in dive mode?
	bra		menu_draw_lines_divemode		; YES
	btfsc	menu_flags,0					; dynamic title?
	rcall	menu_processor_title			; YES - redraw it then
	MENU_LINE_FONT MENU_LEFT, 0				; initialize start position/font
	movff	menu_center,win_top				; computed in menu block

	; Does the menu have more than 6 lines ?
	movf	item_max,W
	addlw	-(MENU_LINES_MAX+1)				;
	bnn		menu_draw_long_menu				; bra if >= 7
	clrf	start_item
	bra		menu_draw_lines_2

menu_draw_long_menu:
	movf	selected_item,W					; start at selected-6
	addlw	-(MENU_LINES_MAX-1)
	btfsc	STATUS,N						; is this < 0 ?
	clrf	WREG							; YES - start from top instead
	movwf	start_item

menu_draw_lines_2:
	movff	start_item, menu_item
	WIN_FONT FT_SMALL						; set font size

menu_draw_lines_1:
	call	TFT_standard_color				; set default text color
	movf	menu_item,W
	rcall	menu_read_item
	movf	value_type,W					; switch on data type
	bz		menu_draw_line_call
	dcfsnz	WREG
	bra		menu_draw_line_string
	dcfsnz	WREG
	bra		menu_draw_line_option
	dcfsnz	WREG
	bra		menu_draw_line_dynamic
	bra		menu_draw_line_none

menu_draw_line_string:
	movff	text_item+0,TBLPTRL				; read not-translated string from PROM
	movff	text_item+1,TBLPTRH
	call	strcpy_prom						; copy in buffer
	bra		menu_draw_line_none

menu_draw_line_call:
	movff	text_item+0,FSR1L				; read string from PROM
	movff	text_item+1,FSR1H
	call	strcpy_text						; copy in buffer
	bra		menu_draw_line_none

menu_draw_line_option:
	movff	text_item+0,FSR1L				; read string from PROM
	movff	text_item+1,FSR1H
	call	strcpy_text						; copy in buffer
	movff	option_item+0,FSR0L				; retrieve option handle
	movff	option_item+1,FSR0H
	btfss	block_option_value				; display of option value suspended?
	call	option_draw						; NO - draw option (do not do it when setting time or date)
	bra		menu_draw_line_none

menu_draw_line_dynamic:
	lfsr	FSR2,buffer
	movff	menu_item,PRODL					; pass item to callback
	rcall	menu_text_call					; push return address
	bra		menu_draw_line_none

; Computed goto to pointer inside dynamic_item:
menu_text_call:
	movf	dynamic_item+0,W				; check if callback is NULL
	iorwf	dynamic_item+1,W
	iorwf	dynamic_item+2,W
	btfsc	STATUS,Z
	return									; YES - don't call it
	movff	dynamic_item+2,PCLATU			; prepare...
	movff	dynamic_item+1,PCLATH
	movf	dynamic_item+0,W
	movwf	PCL								; ...and jump

menu_draw_line_none:
	btfsc	divemode						; in dive mode?
	bra		menu_draw_line_none_divemode	; YES
	movlw	MENU_LINE_MAX_LENGTH
	call	TFT_fillup_with_spaces			; fill up FSR2 with spaces (total string length in #WREG)
	clrf	WREG
	movff	WREG,buffer+MENU_LINE_MAX_LENGTH ; NO - make sure won't be longer than MENU_LINE_MAX_LENGTH ch
	call	aa_wordprocessor
	bcf		win_invert						; clear flag for inverted output by default
	movlw	MENU_HEIGHT						; NO - move to next line
	addwf	win_top,F
	incf	menu_item,F						; inc loop counter
	movf	start_item,W					; first line (scrolled)
	subwf	menu_item,W						; current - first
	xorlw	MENU_LINES_MAX					; get max number of lines
	btfsc	STATUS,Z						; already done max number of lines?
	return									; YES
menu_draw_line_none2:
	movf	menu_item,W						; done item_max lines?
	xorwf	item_max,W
	btfss	STATUS,Z
	bra		menu_draw_lines_1				; NO - loop...
	return

menu_draw_line_none_divemode:
	movlw	.10
	call	TFT_fillup_with_spaces			; fill up FSR2 with spaces (total string length in #WREG)
	clrf	WREG
	movff	WREG,buffer+.10
	call	aa_wordprocessor				; draw the line
	bcf		win_invert						; reset invert flag
	movlw	.24								; dive mode menu spacing
	addwf	win_top,F
	incf	menu_item,F						; inc loop counter
	movlw	.3
	cpfseq	menu_item						; at position 4?
	bra		menu_draw_line_none2			; NO
	movlw	dm_menu_item4_row
	movff	WREG,win_top					; reset row
	movlw	dm_menu_item4_column
	movff	WREG,win_leftx2					; new column
	bra		menu_draw_line_none2			; done

;-----------------------------------------------------------------------------
; draw cursor
menu_draw_selected_line:
	WIN_BOX_BLACK .34,.221,MENU_LEFT-8,MENU_LEFT-2 ; clear left column
	call	TFT_standard_color
	WIN_SMALL MENU_LEFT-8, 0				; arrow symbol only in small font
	movf	start_item,W					; first line (scrolled)
	subwf	selected_item,W					; selected - first
	mullw	MENU_HEIGHT						; 30 pixel by line
	movf	PRODL,W							; result
	addwf	menu_center,W					; added to first line
	movwf	win_top							; and stored to position
	STRCPY_PRINT "\xb7"						; print cursor
	return

	END