;=============================================================================
;
;   File menu_processor.asm							REFACTORED VERSION V2.99d
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
#include "wait.inc"
#include "start.inc"
#include "surfmode.inc"
#include "divemode.inc"
#include "tft_outputs.inc"
#include "eeprom_rs232.inc"
#include "adc_lightsensor.inc"
#include "i2c.inc"


; NOTE: needs to be identical in .inc and .asm !
#define MENU_LINES_MAX			.7			; number of lines per screen?
#define MENU_TITLE_FONT			WIN_STD		; font needs to contain lower and UPPER chars
#define MENU_LINE_FONT			WIN_SMALL	; font needs to contain lower and UPPER chars
#define MENU_LEFT				.20			; position of first menu item
#define MENU_HEIGHT				.27			; spacing between menu lines
#define MENU_VCENTER			.125		; position on screen
#define MENU_LINE_MAX_LENGTH	.20			; length in characters
#define option_item				proc_item

; Other needed references
	extern	aa_wordprocessor
	extern	option_inc
	extern	option_draw
	extern	comm_mode
	extern	TFT_clear_divemode_menu
	extern	TFT_divemask_color
	extern	rtc_set_rtc
	extern	divemode_option0_return
	extern	TFT_fillup_with_spaces


menu_proc		CODE

;=============================================================================
; menu handler.
;
; Input:    TBLPTR = addr of menu block.
	global	menu_processor
menu_processor:
	banksel	common							; bank 1
	btfss	divemode						; in divemode?
	call	speed_fastest					; NO - make it quick
	;---- Read menu block ------------------------------------------------
	VARARGS_BEGIN							; read inline PROM data
	clrf	STKPTR							; never return from here
	VARARGS_GET8	item_max				; get number of items
	VARARGS_GET8	menu_flags				; get flags
	VARARGS_GET24	menu_title				; get pointer to menu title
	VARARGS_GET8	menu_center				; vertical position
	movff	TBLPTRL, menu_block+0			; save base address for menu_read_item
	movff	TBLPTRH, menu_block+1
	movff	TBLPTRU, menu_block+2
	btfss	divemode						; in divemode?
	bra		menu_processor0					; NO
	; Required for menus with less entries than the calling menu but not so nice when setting up gas 6.... mH
	movlw	.1
	cpfsgt	menupos1						; only if menupos1 = 1...
	call	TFT_clear_divemode_menu			; ... clear the menu!
	; Draw one frame around the divemode menu
	call	TFT_divemask_color
	WIN_FRAME_COLOR16 dm_menu_row, dm_menu_lower, dm_menu_left ,dm_menu_right	; top, bottom, left, right
	call	TFT_standard_color

	bra		menu_processor1					; skip next code segment in divemode

menu_processor0:
	;---- draw menu title ------------------------------------------------
	clrf	CCP1CON							; stop PWM
	bcf		PORTC,2							; pull PWM out to GND
	call	TFT_ClearScreen
	rcall	menu_processor_title
	rcall	menu_processor_bottom_line

menu_processor1:
	movlw	FT_SMALL
	movff	WREG, win_font

	;---- Select menu type -----------------------------------------------
	bra		menu_vertical


;=============================================================================
; draw menu bottom line
;
	global	menu_processor_bottom_line,menu_processor_bottom_line_comm
menu_processor_bottom_line:
	;---- Draw bottom line -----------------------------------------------
	TEXT_TINY .5,         .240-.16, tNext
	TEXT_TINY .160-.6*.6, .240-.16, tEnter
	WIN_COLOR color_greenish
menu_processor_bottom_line_comm:	
	; Serial Number and Firmware Version
	WIN_TINY .32,.240-.16
	STRCPY	"#"
	call	TFT_cat_serial
	STRCAT	" v"
	call	TFT_cat_firmware
	STRCAT	" "
	call	TFT_cat_beta_release
	STRCAT_PRINT ""
	call	TFT_standard_color
	bcf		win_invert
	return

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
	banksel	menustack
	lfsr	FSR2,menustack
	clrf	POSTINC2
	clrf	POSTINC2
	clrf	POSTINC2
	clrf	POSTINC2
	clrf	POSTINC2
	banksel	common
	clrf	selected_item
	return

	global	menu_processor_pop
menu_processor_pop:
	movff	menustack+0,selected_item
	movff	menustack+1,menustack+0
	movff	menustack+2,menustack+1
	movff	menustack+3,menustack+2
	movff	menustack+4,menustack+3
	return

	global	menu_processor_double_pop
menu_processor_double_pop:
	movff	menustack+1,selected_item
	movff	menustack+2,menustack+0
	movff	menustack+3,menustack+1
	movff	menustack+4,menustack+2
	return

menu_processor_push:
	movff	menustack+3,menustack+4
	movff	menustack+2,menustack+3
	movff	menustack+1,menustack+2
	movff	menustack+0,menustack+1
	movff	selected_item,menustack+0
	clrf	selected_item
	return

;---- Execute menu selection -------------------------------------------------
do_menu_item:
	bcf		switch_right					; avoid loops
	call	speed_normal					; back to normal speed
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
	btfss	divemode						; in divemode?
	clrf	timeout_counter2				; NO - reset timeout

menu_vertical_2:
	rcall	menu_draw_lines					; always re-draw whole menu
	movlw	CCP1CON_VALUE					; see hwos.inc
	btfss	divemode						; in divemode?
	movwf	CCP1CON							; NO - power-on backlight

menu_vertical_1:
	movf	selected_item,W					; get current item data
	rcall	menu_read_item
	movf	proc_item+0,W					; check if proc address is NULL
	iorwf	proc_item+1,W
	bz		next_line_menu					; YES - not selectable
	btfss	divemode						; in divemode?
	rcall	menu_draw_selected_line			; NO
	btfsc	in_color_menu					; in the color scheme menu?
	call	TFT_show_color_schemes			; YES - update the color schemes
	btfss	settime_setdate					; in the set time or set date menu?
	bra		menu_line_loop_pre2				; NO - skip all following
	movff	month,lo						; new month
	dcfsnz	lo,F
	movlw	.31
	dcfsnz	lo,F
	movlw	.28
	dcfsnz	lo,F
	movlw	.31
	dcfsnz	lo,F
	movlw	.30
	dcfsnz	lo,F
	movlw	.31
	dcfsnz	lo,F
	movlw	.30
	dcfsnz	lo,F
	movlw	.31
	dcfsnz	lo,F
	movlw	.31
	dcfsnz	lo,F
	movlw	.30
	dcfsnz	lo,F
	movlw	.31
	dcfsnz	lo,F
	movlw	.30
	dcfsnz	lo,F
	movlw	.31
	cpfsgt	day								; day ok?
	bra		menu_line_loop_pre1				; YES
	movlw	.1								; NO  - set to 1st
	movwf	day

menu_line_loop_pre1:
	btfsc	switch_right					; enter pressed?
	call	rtc_set_rtc						; YES - update mins,sec,hours,day,month and year to RTC module
	call	TFT_show_time_date_menu			; update clock

menu_line_loop_pre2:
	bcf		switch_right
	bcf		switch_left
	btfss	divemode						; in divemode?
	call	speed_normal					; NO

menu_line_loop_pre3:
	btfsc	divemode						; in divemode?
	goto	divemode_option0_return			; Yes - return to it

menu_line_loop:
	btfsc	switch_right
	bra		do_line_menu					; type dependent
	btfsc	switch_left
	bra		next_line_menu
	btfss	quarter_second_update			; 1/4 second?
	bra		menu_line_loop1					; NO - not yet...
	btfsc	menu_update_sensor_mv			; in the "Calibrate" menu?
	call	TFT_menu_calibrate				; YES - update mV data
	bcf		quarter_second_update			; clear flag

menu_line_loop1:
	btfss	onesecupdate					; new second?
	bra		menu_line_loop2					; NO - not yet...

 IFDEF _rx_functions
	btfsc	FLAG_tr_enabled					; TR functions enabled?
	call	I2C_get_tankdata				; YES - get new tank data
	btfsc	menu_update_tank_pres			; in tank setup menu?
	call	TFT_menu_tank_pres				; YES - update tank press
 ENDIF

	call	timeout_surfmode				; timeout on timeout_counter2
	call	set_dive_modes					; check if divemode must be entered
	call	get_battery_voltage				; gets battery voltage
	btfsc	settime_setdate					; in the set time or set date menu?
	call	TFT_show_time_date_menu			; YES - update clock
	bcf		onesecupdate					; one second updates done

menu_line_loop2:
	btfsc	sleepmode						; timeout?
	goto	restart							; YES - back to surfacemode
	btfsc	divemode
	goto	restart							; enter divemode if required

 IFDEF _screendump
	btfsc	enable_screen_dumps				; screendump enabled?
	call	TFT_dump_screen_check			; YES - check if requested and do it
 ELSE
	btfsc	disable_comm_mode				; COMM mode disabled (happens during new battery procedure)?
	bra	menu_line_loop					; YES - loop
 ENDIF

	btfsc	vusb_in							; USB plugged in?
	call	comm_mode						; YES - start COMM mode

	bra		menu_line_loop					; loop


;---- Move to menu's next line
next_line_menu:
	btfss	divemode						; not in divemode
	call	speed_fastest
	bcf		switch_left						; avoid looping
	incf	selected_item,F					; select next item
	movf	selected_item,W					; index == max ?
	cpfseq	item_max
	bra		menu_vertical_1					; NO  - redraw cursor
	clrf	selected_item					; YES - restart for item 0
	bra		menu_vertical_1					; then redraw cursor

	global	do_line_menu
do_line_menu:
	btfss	divemode						; in divemode?
	call	speed_fastest					; NO
;	bcf		switch_right					; avoid looping
	decf	menupos1,W						; menu_processor needs 0-5
	btfsc	divemode						; only in divemode
	movwf	selected_item
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
	movff	selected_item,PRODL				; pass selection to callback.
	rcall	menu_text_call
	bra		menu_vertical_2					; redraw all lines

;-----------------------------------------------------------------------------

menu_draw_lines_divemode:
	movlw	dm_menu_item1_row
	movff	WREG,win_top
	movlw	dm_menu_item1_column
	movff	WREG,win_leftx2
	clrf	start_item
	movff	item_max,menupos4				; copy item_max for divemode cursor routine
	bra		menu_draw_lines_2

menu_draw_lines:
	btfsc	divemode						; in divemode?
	bra		menu_draw_lines_divemode		; YES
	btfsc	menu_flags,0					; Dynamic title?
	rcall	menu_processor_title			; YES - redraw it then
	MENU_LINE_FONT MENU_LEFT, 0				; init start position/font
	movff	menu_center,win_top				; computed in menu block.

	; Does the menu have more than 6 lines ?
	movf	item_max,W
	addlw	-(MENU_LINES_MAX+1)				; (max - 7)
	bnn		menu_draw_long_menu				; bra if (max >= 7)
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

menu_draw_lines_1:
	call	TFT_standard_color				; restore color after disabled lines
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
	btfss	settime_setdate					; not in Time/Date menu
	call	option_draw
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
	btfsc	divemode						; in divemode?
	bra	menu_draw_line_none_divemode		; YES
	movlw	MENU_LINE_MAX_LENGTH
	call	TFT_fillup_with_spaces			; fill up FSR2 with spaces (Total string length in #WREG)
	clrf	WREG
	movff	WREG,buffer+MENU_LINE_MAX_LENGTH ; NO - make sure won't be longer than MENU_LINE_MAX_LENGTH ch
	call	aa_wordprocessor
	bcf		win_invert						; clear flag for inverted output by default
	movlw	MENU_HEIGHT						; NO - move to next line
	addwf	win_top,F
	incf	menu_item,F						; inc loop counter
	movf	start_item,W					; first line (scrolled)
	subwf	menu_item,W						; current - first
	xorlw	MENU_LINES_MAX					; already done 6 lines?
	btfsc	STATUS,Z
	return									; YES
menu_draw_line_none2:
	movf	menu_item,W						; done item_max lines?
	xorwf	item_max,W
	btfss	STATUS,Z
	bra	menu_draw_lines_1					; NO - loop...
	return

menu_draw_line_none_divemode:
	movlw	.10
	call	TFT_fillup_with_spaces			; fill up FSR2 with spaces (Total string length in #WREG)
	clrf	WREG
	movff	WREG,buffer+.10
	call	aa_wordprocessor				; draw the line
	banksel	common
	bcf		win_invert						; reset invert flag
	banksel	win_top
	movlw	.24								; divemode menu spacing
	addwf	win_top,F
	incf	menu_item,F						; inc loop counter
	movlw	.3
	cpfseq	menu_item						; at pos 4?
	bra		menu_draw_line_none2			; NO
	movlw	dm_menu_item4_row
	movff	WREG,win_top					; reset row
	movlw	dm_menu_item4_column
	movff	WREG,win_leftx2					; new column
	bra		menu_draw_line_none2			; done

;-----------------------------------------------------------------------------
; Put a mark in front of the current line
menu_draw_selected_line:
	clrf	timeout_counter2				; reset timeout
	WIN_BOX_BLACK .34,.221,MENU_LEFT-8,MENU_LEFT-2 ; clear left column
	call	TFT_standard_color
	WIN_SMALL MENU_LEFT-8, 0				; arrow symbol only in small font
	movf	start_item,W					; first line (scrolled)
	subwf	selected_item,W					; selected - first
	mullw	MENU_HEIGHT						; 30 pixel by line
	movf	PRODL,W							; result
	addwf	menu_center,W					; added to first line
	movwf	win_top							; and stored to pos.
	STRCPY_PRINT "\xb7"						; print cursor
	return

	END