;=============================================================================
;
;   File surfmode.asm                         next combined generation V3.04.3
;
;   Surface Mode
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
; 2011-08-07 : [mH] moving from OSTC code

#include "hwos.inc"					; Mandatory header
#include "shared_definitions.h"		; Mailbox from/to p2_deco.c
#include "start.inc"
#include "tft.inc"
#include "tft_outputs.inc"
#include "adc_lightsensor.inc"
#include "menu_processor.inc"
#include "strings.inc"
#include "sleepmode.inc"
#include "wait.inc"
#include "external_flash.inc"
#include "customview.inc"
#include "divemode.inc"
#include "mcp.inc"					; RX
#include "i2c.inc"
#include "comm.inc"
#include "eeprom_rs232.inc"
#include "calibrate.inc"
#include "rx_ops.inc"


	extern	do_main_menu
	extern	check_cns_violation
	extern	check_warn_battery
	extern	check_and_store_sat_violation
	extern	check_mbubbles

 IFDEF _osct_logo
	extern	ostc_logo_block
 ENDIF

 IFDEF _compass
	extern	TFT_surface_compass_heading
 ENDIF


;---- Private local variables ------------------------------------------------

	CBLOCK	local1					; max size is 16 byte !!!
									; currently not used
	ENDC							; used: 0 byte, remaining: 16 byte


#DEFINE menu_pos_row		.215
#DEFINE menu_pos_column		.1
#DEFINE view_row			.215
#DEFINE view_column			.124


sfmode	CODE

;=============================================================================
; Boot tasks for all modes
;
; called after restart via the battery selection, after compass calibration,
; and via ghostwriter at the end of a dive
;
	global	surfloop
surfloop:
	clrf	STKPTR					; clear return addresses stack
;	clrf	CCP1CON					; stop PWM
;	bcf		PORTC,2					; pull PWM output to GND
;	clrf	CCPR1L					; backlight off
	call	TFT_boot				; initialize TFT (includes clear screen)

	btfsc	restart_fast			; shall make a fast restart?
	bra		surfloop_1				; YES

	; show heinrichsweikamp logo
	WIN_TOP  .40
	WIN_LEFT .10
	TFT_WRITE_PROM_IMAGE_BY_ADDR hw_logo_block

	; show textual OSTC logo
	WIN_COLOR color_white
	WIN_STD .30,.90					; column, row
	STRCPY_PRINT "Open Source"		; show OSTC banner text, line 1
	WIN_STD .20,.130				; column, row
	STRCPY_PRINT "Tauch-Computer"	; show OSTC banner text, line 2

	WIN_COLOR color_white
	WIN_SMALL .35,.180
	PUTC	"v"						; print v
	call	TFT_cat_firmware		; print  x.y
	PUTC	" "						; print     _
	call	TFT_cat_beta_release	; print      BetaZ or Release
	STRCAT_PRINT ""					; finalize output
	bcf		win_invert				; clean up eventual color-coding
	call	TFT_standard_color		; ditto
	call	TFT_Display_FadeIn		; dim up the display

surfloop_1:
	;---- Do all useful initializations that take time -----------------------

	; set deco mode flags
	call	restart_set_modes_and_flags

	bsf		trigger_pres_cur_changed; set flag to have pressure    written to display on first round of surface loop
	bsf		trigger_temp_changed	; set flag to have temperature written to display on first round of surface loop

	call	I2C_sleep_compass		; shut down compass

	clrf	ext_flash_address+0
	clrf	ext_flash_address+1
	clrf	ext_flash_address+2

 IFDEF _ccr_pscr
	movlw	surface_sp				; load default surface setpoint (in cbar)
	movff	WREG,char_I_const_ppO2	; store it as current setpoint
 ENDIF

 IFDEF _external_sensor
	call	transmit_setpoint		; transmit current setpoint (in cbar) via S8 digital interface (currently disabled)
 ENDIF

	bcf		surfmode_menu			; not in surface menu (any more)
	bcf		compass_menu			; not in "set bearing" selection (any more)
	bcf		bailout_mode			; not in bailout menu (any more)

	bcf		switch_left				; clear intermediate button event since start/restart
	bcf		switch_right			; clear intermediate button event since start/restart

	btfsc	restart_fast			; shall make a fast restart?
	bra		surfloop_2				; YES

	call	deco_calc_desaturation_time	; calculate desaturation and no-fly/no-altitude time (C-code)
	banksel	common						; back to bank common

	call	wait_1s					; wait <= 1 second
	call	wait_1s					; wait    1 second
	call	wait_1s					; wait    1 second

	;---- Fade to standard surface view --------------------------------------

	call	TFT_Display_FadeOut		; dim down display to black screen
	call	TFT_ClearScreen			; clear screen

surfloop_2:
	WIN_TOP  .0
	WIN_LEFT .0
	WIN_FONT FT_SMALL
	bcf		win_invert				; clear flag for inverted text

	; show button functionalities
	WIN_COLOR			color_lightblue
	WIN_SMALL			menu_pos_column,menu_pos_row
	STRCPY_TEXT_PRINT	tMenu							; show "<Menu"
	WIN_SMALL			view_column,view_row
	STRCPY_TEXT_PRINT	tView							; show "View>"
	call				TFT_standard_color


	;---- Logo in upper right corner -----------------------------------------

	; show textual OSTC logo
	WIN_COLOR color_white				; set text color to white
	WIN_STD .100,.2						; set output position
	STRCPY_PRINT "OSTC"					; show "OSTC"
	WIN_COLOR color_cyan				; set text color to cyan
	WIN_TINY .138,.2					; set output position
	STRCPY_PRINT "hwOS"					; show "hwOS"
	WIN_TINY .137,.14					; set output position
 IFDEF _hwos_sport
	STRCPY_PRINT "sport"				; show "sport"
 ELSE
	STRCPY_PRINT "tech"					; show "tech"
 ENDIF
	WIN_TINY .100,.32					; set output position
	call	TFT_show_firmware			; show firmware version


	;---- fill screen --------------------------------------------------------
	call	get_battery_voltage				; get battery voltage
	call	TFT_batt_surfmode				; display battery voltage
	call	TFT_time_surfmode				; display time
	call	TFT_date_surfmode				; display date
	call	TFT_pres_surfmode				; display surface pressure
	call	TFT_temp_surfmode				; display temperature
	call	TFT_decotype_surface			; display deco mode

	TSTOSS	opt_dive_mode					; in OC? (0=OC, 1=CC, 2=Gauge, 3=Apnea, 4=pSCR)
	call	TFT_show_OC_startgas_surface	; YES - show first gas and "OSTC2-like" active gases

	movff	customview_surfmode,active_customview	; reload last custom view
	call	surf_customview_mask					; redraw last custom view

	call	TFT_Display_FadeIn				; display resulting surface screen

 IFDEF _screendump
	btfsc	screen_dump_avail				; screen dump function enabled?
	call	enable_rs232					; YES - activate RS232 (also sets CPU to normal speed)
 ENDIF

	bcf		restart_fast					; clear flag for fast restart
	bsf		imprint_surfmode_data			; start imprinting surface mode data

	bcf		switch_left						; clear pending left  button event
	bcf		switch_right					; clear pending right button event

	rcall	reset_timeout_surfmode			; reset timeout

surfloop_loop:
;	call	TFT_debug_output				; optional debug output

	call	test_switches_surfmode			; check switches

	btfsc	request_next_custview			; shall show next custom view?
	call	surf_customview_toggle			; YES - show next custom view (and clear this flag)

	btfss	surfmode_menu					; shall enter surface menu?
	bra		surfloop_loop_1					; NO
	bcf		imprint_surfmode_data			; YES - stop imprinting surface mode data
	goto	do_main_menu					;     - goto surface menu

surfloop_loop_1:
	rcall	housekeeping					; handle data imprinting, screen dump request, timeout and entering dive mode
	bra		surfloop_loop					; loop in surface mode


surfmode_check_for_warnings:
	clrf	message_counter					; clear message counter

	; warnings for all modes
	call	check_warn_battery				; check if the battery level should be displayed/warned

	btfsc	FLAG_apnoe_mode					; done for Apnoe or Gauge mode
	bra		surfmode_check_for_warnings2
	btfsc	FLAG_gauge_mode					; done for Apnoe or Gauge mode
	bra		surfmode_check_for_warnings2

	; warnings only in deco modes
	call	check_and_store_sat_violation	; check/show tissue saturation
	call	check_cns_violation				; check/show CNS value
	call	check_mbubbles					; check/show micro bubbles warning
	movff	int_O_lead_supersat+1,WREG		; get upper byte of leading tissue's supersaturation
	btfsc	WREG,int_warning_flag			; check if the warning flag is set
	bra		surfmode_check_for_warnings2	; YES - outside model
	rcall	surfmode_check_for_desat		; NO  - check/display desaturation time
	rcall	surfmode_check_for_nofly		; NO  - check/display no-fly       time

surfmode_check_for_warnings2:
	; setup message page number
	incf	message_page,F					; increment page number
	bcf		STATUS,C						; clear carry bit
	rlcf	message_page,W					; each page can take two messages
	cpfsgt	message_counter					; number of actual messages > message capacity ?
	clrf	message_page					; NO - all messages could be shown, restart from first page next time

	; clear both rows if there is nothing to show at all
	tstfsz	message_counter					; any message to show?
	bra		surfmode_check_for_warnings3	; YES - look if second row needs to be cleared
	goto	TFT_clear_message_window		; NO  - clear complete message area and return

surfmode_check_for_warnings3:
	; clear 2nd row of messages if there is nothing to show (on this page)
	btfss	message_2nd_row_used			; does the 2nd row contain a message?
	goto	TFT_clear_message_window_row2	; NO  - clear the 2nd row and return
	return									; YES - done


surfmode_check_for_desat:
	banksel	int_O_desaturation_time
	movf	int_O_desaturation_time+0,W
	iorwf	int_O_desaturation_time+1,W
	banksel	common							; back to bank common
	bnz		surfmode_check_for_desat_1		; is the desat-time > 0 ?
	return									; NO  - done
surfmode_check_for_desat_1:
	incf	message_counter,F				; YES - increase counter
	call	TFT_desaturation_time			;     - show desaturation time
	return									;     - done

surfmode_check_for_nofly:
	banksel	int_O_nofly_time
	movf	int_O_nofly_time+0,W
	iorwf	int_O_nofly_time+1,W
	banksel	common							; back to bank common
	bnz		surfmode_check_for_nofly_1		; is the nofly-time > 0 ?
	return									; NO  - done
surfmode_check_for_nofly_1:
	incf	message_counter,F				; YES - increase counter
	call	TFT_nofly_time					;     - show nofly-time
	return									;     - done


;=============================================================================

test_switches_surfmode:					; check buttons in surface mode
	btfsc	switch_right				; right button pressed?
	bra		test_switches_surfmode2		; YES
	btfsc	switch_left					; left  button pressed?
	bra		test_switches_surfmode3		; YES
	return								; NO to both - done

test_switches_surfmode2:				; right button pressed
	bcf		switch_right				; clear button event
	rcall	reset_timeout_surfmode		; reset timeout
 IFDEF _compass
	movlw	.6							; coding for surface custom compass view
	cpfseq	active_customview			; in compass view?
	bra		test_switches_surfmode2a	; NO
	btfss	compass_menu				; "set course" selection shown?
	bra		test_switches_surfmode2a	; NO
	bsf		compass_bearing_set			; YES - set new course
	MOVII	compass_heading_shown,compass_bearing
	bra		test_switches_surfmode3b	;     - clear "Course" label and return
 ENDIF
test_switches_surfmode2a:
	bsf		request_next_custview		; request next custom view
	bcf		compass_menu				; "set course" selection not shown anymore
	return

test_switches_surfmode3:				; left button pressed
	bcf		switch_left					; clear button event
	rcall	reset_timeout_surfmode		; reset timeout
 IFDEF _compass
	movlw	.6							; coding for surface custom view compass
	cpfseq	active_customview			; in compass view?
	bra		test_switches_surfmode3a	; NO
	btfsc	compass_menu				; YES - "set course" selection already shown?
	bra		test_switches_surfmode3b	;       YES - remove it
	call	TFT_surf_set_bearing		;       NO  - show it
	return								;           - done
 ENDIF
test_switches_surfmode3a:
	bcf		compass_bearing_set			; clear course on entering menu
	bsf		surfmode_menu				; flag that the surface menu shall be entered
	return

 IFDEF _compass
test_switches_surfmode3b:
	WIN_BOX_BLACK .158,.190, .15, .99	; clear "Course" label (top, bottom, left, right)
	bcf		compass_menu				; clear flag for "set course" selection
	return
 ENDIF


	; handle data imprinting, screen dump request, timeout and entering dive mode
	global	housekeeping
housekeeping:
	btfss	trigger_full_second			; new 1/1 second begun?
	bra		housekeeping_1				; NO

	; tasks any new second
	bcf		trigger_full_second			; YES - clear flag
	call	get_battery_voltage			;     - get battery voltage

	btfsc	imprint_time_date			;     - shall imprint the current time & date?
	call	TFT_show_time_date_menu		;       YES - imprint time and date on display (copies running time to latch registers)

 IFDEF _rx_functions
	btfsc	tr_functions_activated		;     - TR functions activated?
	call	I2C_get_tankdata			;       YES - get new transmitter data

	btfsc	imprint_xmitter_pres		;     - shall imprint transmitter ID and pressure?
	call	TFT_menu_tank_pres			;       YES - imprint transmitter ID and pressure
 ENDIF

	btfss	imprint_surfmode_data		;     - shall imprint all surface mode data?
	bra		housekeeping_0				;       NO
	call	TFT_time_surfmode			;       YES - update displayed time
	call	TFT_batt_surfmode			;           - update displayed battery voltage
	btfss	timebase_1sec,0				;           - on even second?
	call	surfmode_check_for_warnings ;             YES - check for warnings and display/update them

 IFDEF _rx_functions
	btfss	tr_functions_activated		;           - TR functions activated?
	bra		housekeeping_0				;             NO  - skip tank pressure part

	call	get_pressure_readings		;             YES - get pressure readings
	call	TFT_surface_tank_pres		;                 - update first gas/diluent pressure

	movf	active_customview,W			;                 - get current custom view
	xorlw	.10							;                 - coding of tank data custom view
	btfsc	STATUS,Z					;                 - equal?
	call	TFT_surface_tankdata		;                   YES - update tank data custom view
 ENDIF

housekeeping_0:
	bsf		restart_fast				; default to doing a fast restart (no logos)
	call	set_dive_modes				; check if dive mode needs to be entered, will set dive mode flag if yes
	btfsc	simulatormode				; in simulator mode?
	bra		housekeeping_1				; YES - can't restart or go to sleep without prior cleanup
	btfsc	divemode					; NO  - need to enter dive mode?
	goto	restart						;       YES - restart, will proceed to dive mode
	btfss	trigger_timeout				;       NO  - timeout?
	bra		housekeeping_1				;             NO
	btfsc	surfmode_menu				;             YES - in surface menus?
	goto	restart						;                   YES - goto restart, will proceed to surface mode
	bcf		restart_fast				;                   NO  - set next restart to be done slow, i.e. with logos
	goto	sleeploop					;                       - goto sleep mode

housekeeping_1:
	btfss	trigger_quarter_second		; new 1/4 second begun?
	bra		housekeeping_2				; NO

	; tasks any new 1/4 second
	bcf		trigger_quarter_second		; YES - clear flag
 IFDEF _external_sensor
	btfsc	imprint_sensor_mv			;     - shall imprint sensor mV data?
	call	TFT_menu_calibrate			;       YES - imprint sensor mV data
 ENDIF	; _external_sensor
	btfss	imprint_surfmode_data		;     - shall imprint all surface mode data?
	bra		housekeeping_2				;       NO
	btfsc	trigger_pres_cur_changed	;       YES - pressure changed?
	call	TFT_pres_surfmode			;             YES - display surface pressure
	bcf		trigger_pres_cur_changed	;           - clear flag (anyhow)
 IFDEF _compass
	movf	active_customview,W			;           - get current custom view
	xorlw	.6							;           - coding of compass custom view
	btfsc	STATUS,Z					;           - equal?
	call	TFT_surface_compass_heading	;             YES - update compass view
 ENDIF	; _compass
 IFDEF _external_sensor
	btfsc	FLAG_ccr_mode				;           - in CCR mode?
	bra		housekeeping_1a				;           - YES - handle sensors
	btfsc	FLAG_pscr_mode				;           - in pSCR mode?
	bra		housekeeping_1a				;             YES - handle sensors
	bra		housekeeping_2				;             NO to both
housekeeping_1a:						; handle sensors
	movff	opt_ccr_mode,WREG			; =0: fixed SP, =1: sensor, =2: autoSP
	decfsz	WREG						; opt_ccr_mode = 1 (sensor)?
	bra		housekeeping_2				; NO  - skip sensor readings
	call	calc_deko_divemode_sensor	; YES - read & calculate sensor data
	call	TFT_surface_sensor			;     - update displayed sensor data
	call	TFT_sensor_surface_warning	;     - show a down-arrow behind sensor readings when sensor is at end-of-life
	movf	active_customview,W			;     - get current custom view
	xorlw	.9							;     - coding of sensor mV readings custom view
	btfsc	STATUS,Z					;     - equal?
	call	TFT_sensor_mV				;       YES - update mV readings
 ENDIF	; _external_sensor
housekeeping_2:
	btfss	trigger_full_minute			; new 1/1 minute begun?
	bra		housekeeping_3				; NO

	; tasks any new minute
	bcf		trigger_full_minute			; YES - clear flag
	btfsc	simulatormode				;     - in simulator mode?
	bra		housekeeping_2a				;       YES - real tissues are in the vault, skip desaturation calculations
	call	deco_calc_dive_interval_1min;       NO  - calculate 1 minute at surface conditions (C-code)
	call	deco_calc_desaturation_time	;           - calculate desaturation and no-fly/no-altitude time (C-code)
	banksel	common						;           - back to bank common
housekeeping_2a:
	btfss	imprint_surfmode_data		;     - shall imprint all surface mode data?
	bra		housekeeping_3				;       NO
	call	TFT_date_surfmode			;       YES - update displayed date

	btfsc	trigger_temp_changed		;           - temperature changed?
	call	TFT_temp_surfmode			;             YES - display temperature
	bcf		trigger_temp_changed		;           - clear flag (anyhow)

	movf	active_customview,W			;           - get current custom view
	xorlw	.5							;           - coding of tissue custom view
	btfsc	STATUS,Z					;           - equal?
	call	TFT_surface_tissues			;             YES - update tissue diagram

	movf	active_customview,W			;           - get current custom view
	xorlw	.8							;           - coding of last dive info custom view
	btfsc	STATUS,Z					;           - equal?
	call	TFT_surface_lastdive		;             YES - update last dive infos

housekeeping_3:
	; tasks any round
 IFDEF _screendump
	btfsc	screen_dump_avail			; screen dump function enabled?
	call	TFT_dump_screen_check		; YES - check if requested and do it
 ELSE
	btfsc	comm_mode_disabled			; COMM mode disabled?
	return								; YES - done
 ENDIF
	btfss	surfmode_menu				; in surface menus?
	return								; NO  - done

	btfsc	simulatormode				; currently in simulator (deco calculator) mode?
	return								; YES - suppress COMM mode to not jeopardize backup/restore of tissue data

	btfss	vusb_in						; USB plugged in?
	return								; NO - done
 IFDEF _screendump
	btfsc	screen_dump_avail			; YES - screen dump enabled?
	return								;       YES - no COMM mode to be able to make screen shots of the menu and simulator mode
 ENDIF
	btfss	ble_available				; Skip "USB" check in all Bluetooth models (Required for very old OSTC sport)
	goto	comm_mode_usb				; YES / NO  - proceed to COMM mode, will also set CPU to speed normal
	return

	global	reset_timeout_surfmode
reset_timeout_surfmode:
	movlw	surfmode_timeout_default	; load default timeout value
	btfsc	imprint_sensor_mv			; currently imprinting O2 sensor mV data?
	movlw	surfmode_timeout_calibrate	; YES - replace with CCR Calibrate Menu timeout
	btfsc	simulatormode				; currently in simulator (deco calculator) mode?
	movlw	surfmode_timeout_simulator	; YES - replace with simulator timeout
 IFDEF _rx_functions
	btfsc	imprint_xmitter_ID			; currently selecting pressure transmitter?
	movlw	surfmode_timeout_xmitter	; YES - replace with transmitter selection timeout
 ENDIF	; _rx_functions
 IFDEF _external_sensor
	btfsc	surfmode_menu				; in surface menu?
	bra		reset_timeout_time			; YES - keep timeout value
	btfsc	FLAG_ccr_mode				; NO  - in CCR mode?
	bra		reset_timeout_surfmode_loop	;       YES - continue checking if in sensor mode
	btfsc	FLAG_ccr_mode				;       NO  - in pSCR mode?
	bra		reset_timeout_surfmode_loop	;             YES - continue checking if in sensor mode
	bra		reset_timeout_time			;             NO  - keep timeout value
reset_timeout_surfmode_loop:
	movff	opt_ccr_mode,lo				; get loop mode (=0: fixed/calculated SP, =1: sensor, =2: auto SP)
	decfsz	lo,f						; in sensor mode?
	bra		reset_timeout_time			; NO  - keep timeout value
	movlw	surfmode_timeout_sensor		; YES - replace with sensor mode timeout
 ENDIF	; _external_sensor
	;bra	reset_timeout_time			;     - set  timeout value


	global	reset_timeout_time
reset_timeout_time:						; entry point with timeout value in WREG
	movwf	isr_timeout_reload			; copy WREG to isr_timeout_reload
	bsf		reset_timeout				; request ISR to reset the timeout
	bcf		trigger_timeout				; clear any pending timeout trigger
	return								; done

;-----------------------------------------------------------------------------

	END
