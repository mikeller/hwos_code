;=============================================================================
;
;   File menu_processor.asm                 * combined next generation V3.12.1
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
#include "colorschemes.inc"


; NOTE: needs to be identical in .inc and .asm !
;
#define MENU_LINES_MAX			.7			; maximum number of lines per screen
#define MENU_LEFT				.20			; position of first menu item
#define MENU_HEIGHT_SURF		.27			; spacing between menu item in surface mode (pixel)
#define MENU_HEIGHT_DIVE		.24			; spacing between menu item in surface mode (pixel)
#define MENU_VCENTER			.125		; position on screen
#define MAX_LINE_LENGTH_TITLE	.17			; max menu title length                   (characters)
#define MAX_LINE_LENGTH_SURF	.20			; max menu item  length in surface   menu (characters)
#define MAX_LINE_LENGTH_DIVE	.10			; max menu item  length in dive mode menu (characters)
#define MENU_ITEM_DATA_SIZE		.4			; size of a menu item data block

; Alias for easier code reading
#define option_addr				item_funct_addr


	extern	option_adjust_group_member
	extern	option_inc
	extern	option_dec
	extern	option_draw

	extern	rtc_set_rtc
	extern	divemode_option_divemenu_return


;=============================================================================
menu_proc	CODE
;=============================================================================


;-----------------------------------------------------------------------------
; Entry Point for Menu Processor, called by MENU_BEGIN Macros
;
	global	menu_processor
menu_processor:
	; read menu header
	VARARGS_BEGIN							; load TBLPTR with start address of the menu header data
	clrf	STKPTR							; never return from here

	VARARGS_GET8	menu_item_count			; get number of items
	VARARGS_GET8	menu_vertical_start		; get vertical start position of 1st menu item

	movf	menu_vertical_start,W			; excite flags, vertical start = 0, i.e. no menu title text?
	bz		menu_processor_no_title			; YES - skip reading menu title text address

	VARARGS_GET16	menu_title_addr			; get address of menu title text

menu_processor_no_title:

	movff	TBLPTRL, menu_item_data_start+0	; store base address of menu items for menu_read_menu_item_data
	movff	TBLPTRH, menu_item_data_start+1	; ...
	movff	TBLPTRU, menu_item_data_start+2	; ...

	btfss	divemode						; in dive mode?
	bra		menu_processor_menu_title		; NO  - no frame in surface mode menu

	; required for menus with less entries than the calling menu but not so nice when setting up gas 6.... mH
	movlw	.1								; menu_pos_cur = 1 ?
	cpfsgt	menu_pos_cur					; ...
	call	TFT_clear_divemode_menu			; YES - clear the menu

	; draw a frame around the dive mode menu
	movf	pallet_color_mask,W				; get mask color into WREG
	WIN_FRAME_COLOR dm_menu_row, dm_menu_lower, dm_menu_left ,dm_menu_right	; top, bottom, left, right
	bra		menu_processor_menu_body		; the dive mode menu has no menu title and footer

menu_processor_menu_title:
	; prepare screen
	btfsc	screen_type3			; screen type 3 ?
	bra	menu_processor_menu_title1	; YES - screen type 3 has no backlight
	clrf	CCP1CON							; stop PWM
	bcf		PORTC,2							; fade out backlight
menu_processor_menu_title1:	
	call	TFT_ClearScreen					; clear screen

	; draw menu title
	WIN_BOX_BLACK   .2,.23,.0,.159			; clear menu title area
	WIN_STD .0, .2							; set menu title font and position
	FONT_COLOR color_greenish				; set menu title font color
	movff	menu_title_addr+0,FSR1L			; point to multi-lingual menu title text
	movff	menu_title_addr+1,FSR1H			; ...
	call	strcpy_text_FSR					; copy translated text into the buffer
	movf	FSR2L,W							; get title text length
	mullw	.9								; compute title length in pixels_x2
	bcf		STATUS,C						; divide by 2
	rrcf	PRODL							; ...
	movf	PRODL,W							; get result into WREG
	sublw	.80								; compute 80 (screen center position) - half title width in pixel_x2
	movwf	win_leftx2						; set result as horizontal start position
	movlw	MAX_LINE_LENGTH_TITLE			; load max allowed length of a menu title
	movwf	FSR2L							; set buffer pointer to end of max length
	clrf	INDF2							; terminate string          at max length
	PRINT									; output menu title

	; draw footer line
	FONT_COLOR_MEMO							; select default color
	WIN_TINY   .5, .224						; tiny font, left position
	STRCPY_TEXT_PRINT tNext					; print "Next"
	WIN_TINY .124, .224						; tiny font, righ position
	STRCPY_TEXT_PRINT tEnter				; print "Enter"

menu_processor_menu_body:
	FONT_SIZE FT_SMALL						; select font size
	bra		menu_vertical					; draw the menu items


;-----------------------------------------------------------------------------
; Helper Function - call Callback-Function to draw the Menu Item Title
;
menu_processor_call_title:
	movff	menu_title_addr+2,PCLATU		; execute computed goto
	movff	menu_title_addr+1,PCLATH		; ...
	movf	menu_title_addr+0,W				; ...
	movwf	PCL								; ...


;-----------------------------------------------------------------------------
; Clear all memorized Menu Item Selections and restart with Cursor on first Item
;
	global	menu_processor_reset
menu_processor_reset:
	clrf	menustack						; clear                  first stack position
	clrf	menustack_pointer				; set stack pointer   to first stack position
	clrf	selected_item					; set cursor position to first menu item
	return									; done


;-----------------------------------------------------------------------------
; Pull / Double-Pull Cursor Position from Stack
;
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
	movff	PLUSW2,selected_item			; retrieve cursor position from stack
	return									; done


;-----------------------------------------------------------------------------
; Push Cursor Position onto Stack
;
menu_processor_push:
	lfsr	FSR2,menustack					; load base  address of menu stack
	movf	menustack_pointer,W				; load stack pointer into WREG
	movff	selected_item,PLUSW2			; save cursor position to stack
	incf	menustack_pointer,W				; increment stack pointer, park result in WREG
	btfss	WREG,3							; result < 8 ?
	movwf	menustack_pointer				; YES - update stack pointer
	clrf	selected_item					; set cursor to first item in new menu
	return									; done


;-----------------------------------------------------------------------------
; Helper Function - call Menu Item Function
;
menu_call_item_function:
	bcf		switch_right					; clear button event
	movf	selected_item,W					; copy current cursor position to WREG
	rcall	menu_read_menu_item_data		; read item function address
	movff	selected_item,PRODL				; pass cursor position (menu item number) to call function
	rcall	menu_processor_push				; push current cursor position onto stack
	clrf	                  PCLATU		; execute computed goto
	movff	item_funct_addr+1,PCLATH		; ...
	movf	item_funct_addr+0,W				; ...
	movwf	                  PCL			; ...


;-----------------------------------------------------------------------------
; Read Menu Item Data
;
menu_read_menu_item_data:
	cpfsgt	menu_item_count					; selected menu item valid?				|| * Safety Check * to prevent any computed
	clrf	WREG							; NO - change selection to first item	|| goto to an illegal random target address

	mullw	MENU_ITEM_DATA_SIZE				; compute menu item data offset
	movf	PRODL,W							; add offset to base address of menu data block and set up TBLPTR
	addwf	menu_item_data_start+0,W		; ...
	movwf	TBLPTRL							; ...
	movf	PRODH,W							; ...
	addwfc	menu_item_data_start+1,W		; ...
	movwf	TBLPTRH							; ...
	movlw	0								; ...
	addwfc	menu_item_data_start+2,W		; ...
	movwf	TBLPTRU							; ...

	VARARGS_GET16	item_title_addr			; read address of item title function or title text             | with embedded
	VARARGS_GET16	item_funct_addr			; read address of item call  function or option definition data | menu item type

	movlw	.2								; probe for menu item type = OPTION
	btfsc	item_funct_addr,0				; is type OPTION?
	bra		menu_read_menu_item_data_1		; YES

	movlw	.1								; probe for menu item type = MENU_CALL
	btfsc	item_title_addr,0				; is type MENU_CALL?
	bra		menu_read_menu_item_data_1		; YES

	movlw	.0								; must be MENU_DYNAMIC

menu_read_menu_item_data_1:
	movwf	item_type						; store menu item type
	bcf		item_title_addr+0,0				; strip menu item type encoding from addresses (reset to even addresses)
	bcf		item_funct_addr+0,0				; ...

	return									; done


;-----------------------------------------------------------------------------
; Menu HMI Operation
;
	global	menu_vertical
menu_vertical:
	rcall	menu_draw_menu_items			; draw all menu items
	movlw	CCP1CON_VALUE					; load PWM setting
	btfss	divemode						; in dive mode?
	movwf	CCP1CON							; NO - power-on backlight

menu_vertical_loop:
	movf	selected_item,W					; get cursor position into WREG
	rcall	menu_read_menu_item_data		; read menu item data
	movf	item_funct_addr+0,W				; check if execute function call address is NULL
	iorwf	item_funct_addr+1,W				; ...
	bz		next_line_menu					; YES - not selectable, step cursor to next menu item
	btfsc	divemode						; NO  - in dive mode?
	bra		menu_line_loop_pre1				;       YES - skip next
	rcall	menu_draw_cursor_surf			;       NO  - draw the cursor (main menu style)
	btfss	imprint_time_date				;           - currently imprinting the current time & date?
	bra		menu_line_loop_pre1				;             NO  - skip
	btfss	switch_right					;             YES - right button pressed, i.e. time or date changed?
	bra		menu_line_loop_pre1				;                   NO  - skip
	call	TFT_imprint_time_date_fast		;                   YES - show a fast response on the screen (may momentarily show an illegal day/month combination)
	call	rtc_set_rtc						;                       - update time and date on RTC module (corrects illegal day/month combinations)

menu_line_loop_pre1:
	bcf		switch_right					; clear left-over right button event
	bcf		switch_left						; clear left-over left  button event

menu_line_loop_pre2:
	btfsc	divemode						; in dive mode?
	goto	divemode_option_divemenu_return	; YES - return to it
	call	reset_timeout_surfmode			; NO  - reset timeout
	;bra	menu_line_loop					;     - operate menu HMI

menu_line_loop:
	call	housekeeping					; handle data imprinting, screen dump request, timeout and entering dive mode
	btfsc	switch_right					; right button pressed?
	bra		do_line_menu					; YES - execute menu item function
	btfss	switch_left						; NO  - left button pressed?
	bra		menu_line_loop					;       NO  - loop
next_line_menu:								;       YES - step cursor to next menu item
	bcf		switch_left						;           - clear button event
	incf	selected_item,F					;           - increment cursor position to next item
	movf	selected_item,W					;           - copy new item number to WREG
	cpfseq	menu_item_count					;           - new item number beyond number of menu items?
	bra		menu_vertical_loop				;             NO  - redraw cursor
	clrf	selected_item					;             YES - reset cursor position to first item
	bra		menu_vertical_loop				;                 - redraw cursor


;-----------------------------------------------------------------------------
; Execute Menu Item Function
;
	global	do_line_menu
do_line_menu:
	decf	menu_pos_cur,W					; get selected menu item (0-5) into WREG
	btfsc	divemode						; in dive mode?
	movwf	selected_item					; YES - take selected menu item from dive mode
	movf	selected_item,W					; copy       selected menu item to WREG
	rcall	menu_read_menu_item_data		; read menu item data
	movf	item_type,W						; switch on menu item type
	bz		menu_do_line_call				; -> 0: call (with dynamic title)
	dcfsnz	WREG							;
	bra		menu_do_line_call				; -> 1: call (with fixed   title)
	dcfsnz	WREG							;
	bra		menu_do_line_option				; -> 2: option
	bra		menu_line_loop_pre2				; else do nothing

menu_do_line_call:
	rcall	menu_call_item_function			; push current cursor position onto stack and call menu item function
	rcall	menu_processor_pop				; get back cursor position
	bra		menu_vertical					; re-draw the menu

menu_do_line_option:
	movff	option_addr+0,FSR0L				; get address of option definition data
	movff	option_addr+1,FSR0H				; ...
	btfsc	option_addr+1,4					; shall stop at max value?
	bsf		option_stop_at_max				; YES - set flag
	btfsc	option_addr+1,6					; is the selected option an  option group member?
	call	option_adjust_group_member		; YES -  adjust address to selected group member
	btfss	option_addr+1,5					; shall increment?
	call	option_inc						; YES - increment option value
	btfsc	option_addr+1,5					; shall decrement?
	call	option_dec						; YES - decrement option value
	bcf		option_stop_at_max				; revert to default (= wrap-around after max value)
	bra		menu_vertical					; re-draw the menu


;-----------------------------------------------------------------------------
; Draw all Menu Items
;
menu_draw_menu_items:
	btfss	divemode						; in dive mode?
	bra		menu_draw_lines_surfmode		; NO
	;bra	menu_draw_lines_divemode		; YES

	global	menu_draw_lines_divemode
menu_draw_lines_divemode:
	movff	menu_item_count,menu_pos_max	; copy number of item in menu block to menu_pos_max (used by divemode instead of menu_item_count for no reason)

 IFDEF _big_divemenu

	btfss	alt_layout_active				; big menu selected?
	bra		menu_draw_lines_divemode_small	; NO
	;bra	menu_draw_lines_divemode_big	; YES

menu_draw_lines_divemode_big:
	WIN_STD dm_menu_item1_column+.16,dm_menu_item1_row+.22
	decf	menu_pos_cur,W					; get selected item as 0..5 into WREG
	movwf	menu_item_start					; set first item to draw = selected item
	bra		menu_draw_menu_items_common		; continue with common part

 ENDIF	; _big_divemenu

menu_draw_lines_divemode_small:
	WIN_SMALL dm_menu_item1_column,dm_menu_item1_row
	clrf	menu_item_start					; set first item in menu block as first item to draw
	bra		menu_draw_menu_items_common		; continue with common part

menu_draw_lines_surfmode:
	WIN_SMALL MENU_LEFT, 0					; initialize start position and font
	movff	menu_vertical_start,win_top		; set vertical output position
	clrf	menu_item_start					; set first item in menu block as first item to draw

 IFDEF scrolling_menu_enabled
	; does the menu have more than 7 item ?
	movf	menu_item_count,W				; get number of menu items
	addlw	-(MENU_LINES_MAX+1)				; more than 7 item?
	bn		menu_draw_menu_items_common		; NO  - continue with common part
	movf	selected_item,W					; YES - compute first item to be drawn as current cursor position - 6
	addlw	-(MENU_LINES_MAX-1)				;     - ...
	btfsc	STATUS,N						;     - is this < 0 ?
	clrf	WREG							;       YES - revert to starting from first item
	movwf	menu_item_start					;     - set first item to be drawn
 ENDIF	; scrolling_menu_enabled

menu_draw_menu_items_common:
	movff	menu_item_start,menu_item_curr	; initialize menu item counter

menu_draw_menu_items_loop:
	FONT_COLOR_MEMO							; set default font color (may had been changed by a dynamic title)
	REINIT_BUFFER							; initialize output buffer again
	movf	menu_item_curr,W				; get menu item to draw
	rcall	menu_read_menu_item_data		; read menu item data
	movf	item_type,W						; switch on menu item type:
	bz		menu_draw_menu_item_dynamic		; -> 0: call with dynamic title
	dcfsnz	WREG							;
	bra		menu_draw_menu_item_call		; -> 1: call with fixed   title
	dcfsnz	WREG							;
	bra		menu_draw_menu_item_option		; -> 2: option increment
	bra		menu_draw_menu_item_print		; no output in case of illegal type

menu_draw_menu_item_dynamic:
	movf	item_title_addr+0,W				; check if call address is NULL
	iorwf	item_title_addr+1,W				; ...
	btfsc	STATUS,Z						; is null?
	bra		menu_draw_menu_item_after_print	; YES - no printing on this menu line
	movff	menu_item_curr,PRODL			; NO  - pass menu item position to call function
	rcall	menu_text_call					;     - call dynamic title function
	bra		menu_draw_menu_item_print		;     - print menu item

menu_draw_menu_item_call:
	movff	item_title_addr+0,FSR1L			; point to multi-lingual text
	movff	item_title_addr+1,FSR1H			; ...
	call	strcat_text_FSR					; copy translated text to buffer
	bra		menu_draw_menu_item_print		; print menu item

menu_draw_menu_item_option:
	movff	item_title_addr+0,FSR1L			; point to multi-lingual text
	movff	item_title_addr+1,FSR1H			; ...
	call	strcat_text_FSR					; copy translated text to buffer
	movff	option_addr+0,FSR0L				; hand over address of option definition data
	movff	option_addr+1,FSR0H				; ...
	btfsc	option_addr+1,6					; is the selected option an  option group member?
	call	option_adjust_group_member		; YES -  adjust address to selected group member
	btfss	block_option_value				; displaying of option value suspended?
	call	option_draw						; NO - draw option value
	;bra	menu_draw_menu_item_print		; print menu item

menu_draw_menu_item_print:
	movlw	MAX_LINE_LENGTH_SURF			; load               maximum length for a surface   menu item
	btfsc	divemode						; in dive mode?
	movlw	MAX_LINE_LENGTH_DIVE			; YES - replace with maximum length for a dive mode menu item
	call	TFT_buffer_trim_length			; fill up or cut buffer to max length
	PRINT									; print menu item to screen
	;bra	menu_draw_menu_item_after_print	; continue with after-print actions

menu_draw_menu_item_after_print:
	btfss	divemode						; in dive mode?
	bra		menu_draw_menu_item_common		; NO
	;bra	menu_draw_menu_item_divemode	; YES

menu_draw_menu_item_divemode:
 IFDEF _big_divemenu
	btfsc	alt_layout_active				; big menu selected?
	return									; YES - done
 ENDIF

	movlw	.2								; load a 2
	cpfseq	menu_item_curr					; just done menu item 2 (last item in left column) ?
	bra		menu_draw_menu_item_common		; NO  - continue with common part
	movlw	dm_menu_item4_row				; YES - set vertical   position for 2nd column
	movff	WREG,win_top					;     - ...
	movlw	dm_menu_item4_column			;     - set horizontal position for 2nd column
	movff	WREG,win_leftx2					;     - ...
	bra		menu_draw_menu_item_common_1	;     - continue in common part

menu_draw_menu_item_common:
	movlw	MENU_HEIGHT_SURF				; get menu items     vertical spacing for surface mode
	btfsc	divemode						; in dive mode?
	movlw	MENU_HEIGHT_DIVE				; YES - replace with vertical spacing for dive    mode
	addwf	win_top,F						; adjust vertical output position

menu_draw_menu_item_common_1:
	incf	menu_item_curr,F				; increment menu item number

 IFDEF scrolling_menu_enabled
	btfsc	divemode						; in dive mode?
	bra		menu_draw_menu_item_common_2	; YES - skip
	movf	menu_item_start,W				; NO  - get the number of the menu item that menu drawing started with
	subwf	menu_item_curr,W				;     - compute how many item have been drawn already
	xorlw	MENU_LINES_MAX					;     - compare with how max item fit the screen
	btfsc	STATUS,Z						;     - screen full?
	return									;     - YES - done
	;bra	menu_draw_menu_item_common_2	;       NO  - continue
 ENDIF	; scrolling_menu_enabled

menu_draw_menu_item_common_2:
	movf	menu_item_curr,W				; get current menu item
	xorwf	menu_item_count,W				; compare with total number of menu items, more item to do?
	bnz		menu_draw_menu_items_loop		; YES - loop
	return									; NO  - done


;-----------------------------------------------------------------------------
; Helper Function - call Function for dynamic Title
;
menu_text_call:
	clrf	                  PCLATU		; execute a computed goto
	movff	item_title_addr+1,PCLATH		; ...
	movf	item_title_addr+0,W				; ...
	movwf	                  PCL			; ...


;-----------------------------------------------------------------------------
; Draw the Cursor (Main Menu Style)
;
menu_draw_cursor_surf:
	WIN_LEFT	MENU_LEFT-8					; set horizontal  start of cursor column
	WIN_WIDTH	.6							; set width             of cursor column
	WIN_HEIGHT	.223						; set preliminary hight of cursor column

	movf	menu_vertical_start,W			; get vertical    start of menu items
	movwf	win_top							; set vertical    start of cursor column
	subwf	win_height,F					; final hight = prelim.height - vertical start

	clrf	WREG							; set color to black
	BOX_COLOR								; clear cursor area

	FONT_SIZE FT_SMALL						; set font size

	movf	menu_item_start,W				; get number of menu item that is on the first line
	subwf	selected_item,W					; compute line number of current menu item

	mullw	MENU_HEIGHT_SURF				; multiply line number with vertical menu items spacing
	movf	PRODL,W							; get computed vertical offset
	addwf	menu_vertical_start,W			; add offset to vertical start position
	movwf	win_top							; set final vertical position
	bra		menu_draw_cursor_common			; print cursor


;-----------------------------------------------------------------------------
; Draw the Cursor (Dive Mode Style)
;
	global	menu_draw_cursor_dive
menu_draw_cursor_dive:
 IFDEF _big_divemenu
	btfss	alt_layout_active				; big menu selected?
	bra		menu_draw_cursor_dive_small		; NO
	;bra	menu_draw_cursor_dive_big		; YES

menu_draw_cursor_dive_big:
	WIN_STD dm_menu_item1_column,dm_menu_item1_row+.20
	bra		menu_draw_cursor_common			; print cursor
 ENDIF	; _big_divemenu

menu_draw_cursor_dive_small:
	; clear cursor areas
	WIN_BOX_BLACK dm_menu_row+.1, dm_menu_lower-.1, dm_menu_item1_column-.8, dm_menu_item1_column-.1
	WIN_BOX_BLACK dm_menu_row+.1, dm_menu_lower-.1, dm_menu_item4_column-.8, dm_menu_item4_column-.1

	FONT_SIZE FT_SMALL						; set font size

	movlw	dm_menu_item1_column-.8			; load position of left column
	btfsc	menu_pos_cur,2					; cursor at menu item 4..6 ?
	movlw	dm_menu_item4_column-.8			; YES - replace with position of right column
	movwf	win_leftx2						; set horizontal position

	decf	menu_pos_cur,W					; get cursor position as 0..5 into WREG
	btfsc	menu_pos_cur,2					; cursor at menu item 4..6 ?
	addlw	-.3								; YES - subtract 3 to get line number in right column

	mullw	MENU_HEIGHT_DIVE				; multiply line number (0..2) with vertical menu items spacing
	movf	PRODL,W							; get computed vertical offset
	addlw	dm_menu_item1_row				; add offset to vertical start position
	movwf	win_top							; set final vertical position
	;bra	menu_draw_cursor_common			; print cursor


;-----------------------------------------------------------------------------
; Helper Function - common Part of drawing the Cursor
;
menu_draw_cursor_common:
	FONT_COLOR_MEMO							; set font color (may have changed in-between)
	STRCPY_PRINT "\xb7"						; print cursor
	return									; done

;-----------------------------------------------------------------------------

	END
