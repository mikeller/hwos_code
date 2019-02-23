;=============================================================================
;
;   File surfmode.asm								REFACTORED VERSION	V2.99e
;
;   Surfacemode
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
#include "isr.inc"
#include "adc_lightsensor.inc"
#include "menu_processor.inc"
#include "strings.inc"
#include "sleepmode.inc"
#include "wait.inc"					; speed_*
#include "external_flash.inc"
#include "customview.inc"
#include "divemode.inc"
#include "mcp.inc"					; RX
#include "i2c.inc"
#include "comm.inc"
#include "eeprom_rs232.inc"
#include "calibrate.inc"

 IFDEF _rx_functions
#include "rx_ops.inc"
 ENDIF

	extern	do_main_menu
	extern	TFT_sensor_mV
	extern	TFT_surface_compass_heading
	extern	check_cns_violation
	extern	check_warn_battery
	extern	check_and_store_gf_violation
	extern	check_mbubbles

 IFDEF _osct_logo
	extern	ostc_logo_block
 ENDIF


	;---- Private local variables -------------------------------------------------

	CBLOCK	local1					; max size is 16 Byte !!!
									; currently not used
	ENDC							; used: 0 byte, remaining: 16 byte


#DEFINE menu_pos_row		.215
#DEFINE menu_pos_column		.1
#DEFINE view_row			.215
#DEFINE view_column			.124

sfmode		CODE

;=============================================================================
; Boot tasks for all modes

	global	surfloop
surfloop:
	call	speed_normal
	bcf		no_sensor_int			; normal pressure mode

	bcf		LEDr

	clrf	CCP1CON					; stop PWM
	bcf		PORTC,2					; pull PWM output to GND
	call	TFT_boot				; initialize TFT (includes clear screen)
	bcf		restore_deco_data

	WIN_TOP  .40
	WIN_LEFT .10
	TFT_WRITE_PROM_IMAGE_BY_ADDR hw_logo_block	; show heinrichsweikamp logo

 IFDEF _ostc_logo
	WIN_TOP  .100
	WIN_LEFT .34
	TFT_WRITE_PROM_IMAGE_BY_LABEL ostc_logo_block	; show OSTC logo
 ELSE
	WIN_COLOR color_white
	WIN_STD .30,.90					; column, row
	STRCPY_PRINT "Open Source"		; show OSTC banner text, line 1
	WIN_STD .20,.130				; column, row
	STRCPY_PRINT "Tauch-Computer"	; show OSTC banner text, line 2
 ENDIF

	WIN_COLOR color_white
	WIN_SMALL .35,.180
	PUTC	"v"						; print v
	call	TFT_cat_firmware		; print  x.y
	PUTC	" "						; print     _ 
	call	TFT_cat_beta_release	; print      BetaZ or Release
	STRCAT_PRINT ""					; finalize output
	bcf		win_invert				; clean up eventual color-coding
	call	TFT_standard_color		; ditto

	call	TFT_Display_FadeIn		; show splash

	;---- Do any useful initializes that takes time -------------------------

	call	restart_set_modes_and_flags ; sets deco mode flags
	bcf		pressure_refresh
	call	I2C_sleep_compass
	call	I2C_sleep_accelerometer
	clrf	ext_flash_address+0
	clrf	ext_flash_address+1
	clrf	ext_flash_address+2

	movlw	surface_sp				; in cbar
	call	transmit_setpoint		; transmit current setpoint from WREG (in cbar) to external electronics

	clrf	timeout_counter2
;	clrf	timeout_counter3		; not used / required [rl]
	bcf		menubit					; clear menu flag
	bcf		premenu
;	clrf	last_pressure+0
;	clrf	last_pressure+1
	bcf		FLAG_bailout_mode		; =1: Bailout
	bcf		FLAG_diluent_setup		; use OC gases for gaslist routine

	bcf		simulatormode_active	; quit simulator mode (if active)

	call	wait_1s					; wait <= 1 second
	call	wait_1s					; wait    1 second
	call	wait_1s					; wait    1 second

	;---- Fade to standard surface view --------------------------------------

	call	TFT_Display_FadeOut		; go to black screen
	call	TFT_ClearScreen			; then change everything
	WIN_TOP  .0
	WIN_LEFT .0
	WIN_FONT FT_SMALL
	bcf		win_invert				; reset invert flag

	WIN_COLOR			color_lightblue
	WIN_SMALL			menu_pos_column,menu_pos_row
	STRCPY_TEXT_PRINT	tMenu		;"<Menu"
	WIN_SMALL			view_column,view_row
	STRCPY_TEXT_PRINT	tView		;"View>"
	call				TFT_standard_color

; Logo
 IFDEF _ostc_logo
	WIN_TOP  .0
	WIN_LEFT .70
	TFT_WRITE_PROM_IMAGE_BY_LABEL ostc_logo_block ; show OSTC logo
 ELSE
	WIN_COLOR color_white
	WIN_STD .100,.0
	STRCPY_PRINT "OSTC"					; show "OSTC"
	WIN_COLOR color_cyan
	WIN_TINY .140,.0
	STRCPY_PRINT "hwOS"					; show "hwOS"
	WIN_TINY .139,.12
	STRCPY_PRINT "tech"					; show "tech"
 ENDIF

	call	TFT_clock					; display time
	call	update_surfloop60
	call	get_battery_voltage			; get battery voltage
	call	TFT_update_batt_voltage		; display battery voltage
	call	TFT_update_surf_press		; display surface pressure
	call	TFT_temp_surfmode			; display temperature
	call	TFT_display_decotype_surface
	call	calc_deko_divemode_sensor

	TSTOSS	opt_dive_mode				; in OC ? (0=OC, 1=CC, 2=Gauge, 3=Apnea, 4=PSCR)
	call	TFT_show_OC_startgas_surface; YES - show first gas and "OSTC2-like" active gases

	movff	customview_surfmode,menupos3; reload last custom view
	call	surf_customview_mask		; redraw last custom view

	call	TFT_Display_FadeIn			; display resulting surface screen

	bcf		switch_left
	bcf		switch_right

	;---- Late initializations -----------------------------------------------
	movff	last_surfpressure_30min+0,int_I_pres_respiration+0		; copy surface air pressure to deco routine
	movff	last_surfpressure_30min+1,int_I_pres_respiration+1		; 30min old values
	movff	last_surfpressure_30min+0,int_I_pres_surface+0			; copy surface air pressure to deco routine
	movff	last_surfpressure_30min+1,int_I_pres_surface+1			; 30min old values
	movff	last_surfpressure_30min+0,last_surfpressure+0			; use 30min old air pressure
	movff	last_surfpressure_30min+1,last_surfpressure+1			; use 30min old air pressure

	movff	opt_GF_low,char_I_GF_Low_percentage
	movff	opt_GF_high,char_I_GF_High_percentage

	; Startup tasks for all modes
	; Desaturation time needs:
	;   int_I_pres_surface
	;   char_I_desaturation_multiplier
	call	deco_calc_desaturation_time ; calculate desaturation time
	banksel	common

 IFDEF _screendump
	btfsc	enable_screen_dumps			; =1: ignore vin_usb, wait for "l" command (Screen dump)
	call	enable_rs232				; also sets to speed_normal
 ENDIF

surfloop_loop:
	btfss	onesecupdate				; do every second tasks?
	bra		surfloop_loop2				; NO - loop

	; one second tasks for all modes
	call	speed_normal
	;call	TFT_debug_output
	call	TFT_clock					; update clock
	call	timeout_surfmode			; check timeout
	call	get_battery_voltage			; get battery voltage
	call	TFT_update_batt_voltage		; display battery voltage
	call	set_dive_modes				; tests if depth > threshold
	btfss	secs,0						; every two seconds...
	call	TFT_temp_surfmode			; ... displays temperature
	btfss	secs,0						; every two seconds...
	call	surfmode_check_for_warnings ; ... check for warnings (and display/update) them
	bcf		onesecupdate				; every second tasks done

 IFDEF _rx_functions
	btfss	FLAG_tr_enabled				; YES - TR functions enabled?
	bra		surfloop_loop2				; NO  - skip tank pressure part
	call	get_pressure_readings		; YES - get pressure readings
	call	TFT_surface_tank_pres		;     - update first gas/diluent pressure
	movlw	.10							;     - number of tank data custom view
	cpfseq	menupos3					;     - in tank data custom view?
	bra		surfloop_loop2				;       NO  - skip
	call	TFT_surface_tankdata		;       YES - update tank data custom view
 ENDIF

surfloop_loop2:
	; tasks approx. every 50 ms for all modes
	call	test_switches_surfmode		; check switches
	;call	TFT_debug_output

	; one minute tasks for all modes
	btfsc	oneminupdate				; do every minute tasks
	call	update_surfloop60			; yes, e.g. update time and date

	; mode tasks
	btfsc	divemode					; divemode active?
	goto	diveloop					; YES - switch into divemode!

	btfsc	menubit						; shall enter menu?
	goto	do_main_menu				; YES - enter menu

	btfsc	pressure_refresh			; new pressure available?
	call	TFT_update_surf_press		; display surface pressure
	bcf		pressure_refresh			; until new pressure is available

	; updates every 1/4 second
	btfss	quarter_second_update
	bra		surfloop_loop2b

	bcf		quarter_second_update

	; update sensors
	call	calc_deko_divemode_sensor

	btfsc	FLAG_ccr_mode				; in CCR mode?
	bra		surfloop_loop2a1			; YES
	btfsc	FLAG_pscr_mode				; in pSCR mode?
	bra		surfloop_loop2a1			; YES
	bra		surfloop_loop2a				; NO  to both

surfloop_loop2a1:
	movff	opt_ccr_mode,WREG			; =0: fixed SP, =1: sensor,  =2: auto SP
	decfsz	WREG						; opt_ccr_mode = 1 (sensor)?
	bra		surfloop_loop2a				; NO - skip sensor readings

	call	TFT_surface_sensor			; ...update sensor data in surface mode
	call	TFT_sensor_surface_warning	; show a warning arrow-down behind sensor readings when sensor is end-of-life
	movlw	.9 
	cpfseq	menupos3					; in sensor mV surface custom view? 
	bra		surfloop_loop2a				; NO
	call	TFT_sensor_mV				; YES - update mV readings (Each 1/4 second and not each second as in customview.asm)

surfloop_loop2a:
	movlw	.6
	cpfseq	menupos3					; in compass view?
	bra		surfloop_loop2b				; NO
	call	TFT_surface_compass_heading	; YES - update compass heading value

surfloop_loop2b:
	btfsc	toggle_customview			; next view?
	call	surf_customview_toggle		; YES - show next customview (and delete this flag)

 IFDEF _screendump
	btfsc	enable_screen_dumps			; screendump enabled?
	call	TFT_dump_screen_check		; YES - check if requested and do it
 ENDIF

	;btfsc	vusb_in						; USB plugged in?       | commented out - do not start COMM mode when charging in surface mode
	;call	comm_mode					; YES - start COMM mode |

	btfss	sleepmode					; shall we go into sleep mode?
	bra		surfloop_loop				; NO  - loop in surface mode
	movff	menupos3,customview_surfmode; YES - save last custom view
	goto	sleeploop					;       switch into sleep mode

update_surfloop60:
	; one minute tasks for all modes
	call	TFT_date					; update date

	call	deco_calc_dive_interval_1min; calculate deco in surface mode. int_I_pres_surface gets updated by
	call	deco_calc_desaturation_time	; TFT_update_surf_press when amb_pressure has changed by >= 10 mbar
	banksel	common

	; update tissue diagram if it is on display
	movlw	.5							; number of tissue custom view
	cpfseq	menupos3					; is this the current custom view?
	bra		update_surfloop60_1			; NO
	call	TFT_standard_color			; YES - set standard color
	call	TFT_surface_tissues			;       show tissue diagram

update_surfloop60_1:
	; update last dive info if it is on display
	movlw	.8							; number of the last dive info custom view
	cpfseq	menupos3					; is this the current custom view?
	bra		update_surfloop60_2			; NO
	call	TFT_standard_color			; YES - set standard color
	call	TFT_surface_lastdive		;       show last dive infos

update_surfloop60_2:
	bcf		oneminupdate
	return

surfmode_check_for_warnings:
	bcf		message_attention			; clear flag for messages of level attention
	bcf		message_warning				; clear flag for messages of level warning
	clrf	message_counter				; clear message counter

	; warnings for all modes
	call	check_warn_battery			; check if the battery level should be displayed/warned

	btfsc	FLAG_apnoe_mode				; done for Apnoe or Gauge mode
	bra		surfmode_check_for_warnings2
	btfsc	FLAG_gauge_mode				; done for Apnoe or Gauge mode
	bra		surfmode_check_for_warnings2

	; warnings only in deco modes
	rcall	surfmode_check_for_desat	; check if desat time should be shown
	rcall	surfmode_check_for_nofly	; check if nofly time should be shown
	call	check_cns_violation			; check CNS value and display it, if required
	call	check_and_store_gf_violation; check GF value and display it, if required
	call	check_mbubbles				; check for micro bubbles

surfmode_check_for_warnings2:
	; setup message page number
	incf	message_page,F
	bcf		STATUS,C
	rlcf	message_page,W				; *2
	cpfsgt	message_counter				; > message_counter?
	clrf	message_page				; NO - clear

	; clear both rows of warnings if there is nothing to show at all
	tstfsz	message_counter				; any warnings?
	bra		surfmode_check_for_warnings3; YES - look if second row needs to be cleared
	call	TFT_clear_warning_text		; NO  - clear complete warnings area
	return

surfmode_check_for_warnings3:
	; clear 2nd row of warnings if there is nothing to show (on this page)
	btfss	second_row_warning				; =1: The second row contains a warning
	call	TFT_clear_warning_text_2nd_row	; NO - clear this row
	return									; Done.

surfmode_check_for_desat:
	banksel	int_O_desaturation_time
	movf	int_O_desaturation_time+0,W
	iorwf	int_O_desaturation_time+1,W
	banksel	common
	bnz		surfmode_check_for_desat_1	; is the desat-time > 0 ?
	return								; NO
surfmode_check_for_desat_1:				; YES
	incf	message_counter,F			; increase counter
	call	TFT_desaturation_time		; show desaturation time
	return

surfmode_check_for_nofly:
	banksel	int_O_nofly_time
	movf	int_O_nofly_time+0,W
	iorwf	int_O_nofly_time+1,W
	banksel	common
	bnz		surfmode_check_for_nofly_1	; is the nofly-time > 0 ?
	return								; NO
surfmode_check_for_nofly_1:				; YES
	incf	message_counter,F			; increase counter
	call	TFT_nofly_time				; show nofly-time
	return


;=============================================================================

test_switches_surfmode:					; check switches in surfacemode
	btfsc	switch_right
	bra		test_switches_surfmode2
	btfsc	switch_left
	bra		test_switches_surfmode3
	; no button pressed
	return

test_switches_surfmode3:
	movlw	.6
	cpfseq	menupos3					; in compass view?
	bra		test_switches_surfmode3a	; NO

	btfsc	premenu						; "Bearing" already shown?
	bra		test_switches_surfmode3b	; YES - remove it
	call	TFT_surf_set_bearing		; NO  - show it
	bcf		switch_left
	return

test_switches_surfmode3a:
	bcf		switch_left
	bcf		compass_bearing_set			; clear bearing on entering menu
	bsf		menubit						; enter the main menu
	return

test_switches_surfmode3b:
	; clear "Bearing"
	WIN_BOX_BLACK	.158,.190, .15, .99	; top, bottom, left, right
	bcf		premenu
	bcf		switch_left
	return

test_switches_surfmode2:
	movlw	.6
	cpfseq	menupos3					; in compass view?
	bra		test_switches_surfmode2a	; NO
	btfss	premenu						; "Heading?" shown?
	bra		test_switches_surfmode2a	; NO
	; set new heading
	bcf		premenu
	bsf		compass_bearing_set
	movff	compass_heading_shown+0,compass_bearing+0
	movff	compass_heading_shown+1,compass_bearing+1
	bcf		switch_right
	return

test_switches_surfmode2a:
	bcf		switch_right
	bsf		toggle_customview
	bcf		premenu
	clrf	timeout_counter2			; and reset timeout
	return

	global	timeout_surfmode
timeout_surfmode:
	movlw	timeout_surfacemode			; load default timeout
	btfsc	menu_update_sensor_mv		; in the "Calibrate" menu?
	movlw	timeout_calibrate_menu		; YES - replace with CCR Calibrate Menu timeout
 IFDEF _rx_functions
	btfsc	FLAG_pairing_mode			; in the "Setup Tank" menu?
	movlw	timeout_tanksetup_menu		; YES - replace with Tank Setup Menu timeout
 ENDIF
	btfsc	menubit						; in menu?
	bra		timeout_testmode			; NO - done
	; must be in surface mode
	btfss	FLAG_ccr_mode				; in CCR mode? (fixed ppO2 or sensor)
	bra		timeout_testmode			; NO  - not CCR
	movlw	timeout_ccr_surface			; YES - replace with CCR surface mode timeout

	global	timeout_testmode
timeout_testmode:
	incf	timeout_counter2,F			; increase timeout counter
	cpfsgt	timeout_counter2			; compare with timeout limit
	return								; return, no timeout
	bsf		sleepmode					; set flag
	return								; return

	END