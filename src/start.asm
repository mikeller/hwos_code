;=============================================================================
;
;   File start.asm                            combined next generation V3.06.1
;
;   Startup subroutines
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;  2011-08-06 : [mH] moving from OSTC code

#include "hwos.inc"							; mandatory header
#include "ms5541.inc"
#include "shared_definitions.h"				; mailbox from/to p2_deco.c
#include "eeprom_rs232.inc"
#include "math.inc"
#include "tft.inc"
#include "surfmode.inc"
#include "wait.inc"
#include "rtc.inc"
#include "external_flash.inc"
#include "strings.inc"
#include "tft_outputs.inc"
#include "adc_lightsensor.inc"
#include "i2c.inc"
#include "divemode.inc"
#include "rx_ops.inc"


	extern	init_ostc
	extern	option_restore_all
	extern	backup_flash_page
	extern	restore_decodata_from_eeprom
	extern	oPressureAdjust
	extern	option_reset
	extern	option_save
	extern	option_save_all
	extern	option_check_all
	extern	do_new_battery_select
	extern	get_battery_data
	extern	use_old_prior_209
	extern	get_first_gas_to_WREG

 IFDEF _ccr_pscr
	extern	option_cleanup_oCCRMode_pSCR
	extern	option_cleanup_oCCRMode_CCR
	extern	get_first_dil_to_WREG
 ENDIF

 IFDEF _rx_functions
	extern	option_cleanup_oTrMode_CCR
	extern	option_cleanup_oTrMode_no_CCR
 ENDIF

 IFDEF _rx_update
	extern	rx_firmware_new_major
	extern	rx_firmware_new_minor
 ENDIF

;-----------------------------------------------------------------------------


;=============================================================================
; Reset Vector: entry point on device wake-up and hard reset
;
reset_v		CODE 0x00000
	goto	0x1FF00							; jump to bootloader

start_v		CODE 0x00004					; jump to application (cold-)start
	goto	start

;=============================================================================

boot	CODE

;=============================================================================
; Entry point after cold start
;
	global	start
start:
	; clear RAM banks 0-14
	lfsr	FSR0,0x000						; load start address into FSR0
	movlw	0x0F							; load end   address into WREG (actually its high byte)
start_clear_rambank:
	clrf	POSTINC0						; clear memory location and increment FSR0
	cpfseq	FSR0H							; has FSR0 reached begin of bank 15, i.e. banks 0-14 done?
	bra		start_clear_rambank				; NO - loop

	; initialize hardware (ports, timers, interrupts, etc.)
	call	init_ostc						; also selects bank common and sets CPU to normal speed

	; flag that later restart origins from a cold start
	bsf		cold_start

	; initialize averaging for analog buttons
	movlw	.16								; set averaging span
	movff	WREG,analog_counter				; write to counter

	; get button type from bootloader info
	bsf		analog_switches
	movlw	0x7C
	movwf	TBLPTRL
	movlw	0xF7
	movwf	TBLPTRH
	movlw	0x01
	movwf	TBLPTRU
	TBLRD*+									; read configuration byte
	movlw	0x07							; coding for analog buttons
	cpfseq	TABLAT							; equal?
	bcf		analog_switches					; NO - no analog buttons

	; get screen type (2) from bootloader info
	bsf		screen_type2
	bsf		screen_type3
	movlw	0x80
	movwf	TBLPTRL							; only low byte adjustment needed, high and upper are still at 0x01F7xx
	TBLRD*+									; read configuration byte
	movlw	0x83							; coding for screen type 2
	cpfseq	TABLAT							; equal?
	bcf		screen_type2					; NO  -  not screen type 2
	movlw	0x84							; coding for screen type 3
	cpfseq	TABLAT							; equal?
	bcf		screen_type3					; NO  -  not screen type 3

	; get button polarity from configuration data (EEPROM)
	movlw	LOW  .897
	movwf	EEADR
	movlw	HIGH .897
	movwf	EEADRH
	call	read_eeprom						; EEDATA into EEPROM @ EEADR
	clrf	EEADRH							; reset EEADRH
	movff	EEDATA,button_polarity			; 0xFF (both normal), 0x00 (both inverted), 0x01 (left inverted only), 0x02 (right inverted only)

	; initialize pressure sensor calibration
	call	get_calibration_data			; get calibration data from pressure sensor
	call	TFT_DisplayOff					; turn off display

	; wait for calibration data to take effect
	bsf		LEDr							; turn on red LED

	; first pass, will not have valid temperature yet
	call	wait_1s
	call	wait_1s
;	bcf		trigger_pres_update				; make sure ISR pressure update confirmation is not older than from now on
;	btfss	trigger_pres_update				; has the ISR confirmed a pressure update?
;	bra		$-2								; NO  - not yet, loop waiting for the ISR to kick in

	; second pass - complete sensor initialization
	call	wait_1s
	call	wait_1s
;	bcf		trigger_pres_update				; make sure ISR pressure update confirmation is not older than from now on
;	btfss	trigger_pres_update				; has the ISR confirmed a pressure update?
;	bra		$-2								; NO  - not yet, loop waiting for the ISR to kick in

	; sensor calibration completed, first valid pressure value is available
	bcf		LEDr							; turn off red LED again

	; load surface pressure into ISR
	; initially needs to be done twice in order to shift the current absolute pressure through the
	; 15 minutes sampling buffer into the reference buffer from where it is loaded by the ISR
	rcall	sample_surface_pressure			; 1st pass
	rcall	sample_surface_pressure			; 2nd pass

	; wait until initial surface pressure value has been loaded into the ISR
	btfsc	update_surface_pressure			; has the ISR confirmed loading of the surface pressure?
	bra		$-2								; NO - not yet, loop until ISR has confirmed loading

	; reset all tissue pressures to surface pressure equilibrium state by default
	call	deco_clear_tissue				; (C-code)
	banksel	common

	; restore tissue pressures from EEPROM (if available)
	movlw	HIGH .512						; =2
	movwf	EEADRH							; set EEPROM address, high byte
	read_int_eeprom	.0						; read tissue storage information flag
	clrf	EEADRH							; revert EEPROM high address pointer to default
	movlw	0xAA							; load coding for tissue pressures available
	cpfseq	EEDATA							; tissue pressures available?
	bra		start_1							; NO  - no tissue pressures available
	call	restore_decodata_from_eeprom	; YES - reload tissue pressures from EEPROM

start_1:
	bsf		reset_surface_interval			; request ISR to reset the surface interval timer

;	call	rtc_init						; initialize the real time clock (will reset to firmware creation date)

	; check for power-on reset
	btfsc	RCON,POR						; was this a power-on reset?
	call	use_old_prior_209				; NO - migrate the last battery status from firmware 2.09 or earlier

	bcf		use_old_batt_flag				; default to no reload of last battery data
	btfsc	RCON,POR						; was this a power-on reset?
	bsf		use_old_batt_flag				; NO - reload last battery data

	call	lt2942_get_status				; check for gauge IC
	btfss	battery_gauge_available			; cR or 2 hardware?
	bra		start_check_new_firmware		; NO  - skip next
	movlw	.30								; YES - load default button sensitivity
	movff	WREG,opt_cR_button_right		;     - set default for left  button
	movff	WREG,opt_cR_button_left			;     - set default for right button
	call	piezo_config					;     - configure buttons, 1st pass
	call	piezo_config					;     - configure buttons, 2nd pass

start_check_new_firmware:
	call	TFT_boot						; initialize TFT (includes clear screen & backlight switch-off)

	; show heinrichsweikamp logo
	WIN_TOP  .40
	WIN_LEFT .10
	TFT_WRITE_PROM_IMAGE_BY_ADDR hw_logo_block

	; check if a new firmware was loaded, if yes reset option oPressureAdjust
	movlw	d'1'							; set EEPROM address to 0x101
	movwf	EEADR							; = 0x001
	movwf	EEADRH							; = 0x101
	call	read_eeprom						; read current version, major
	movff	EEDATA,lo						; store major in lo
	incf	EEADR,F							; set EEPROM address to 0x102
	call	read_eeprom						; read current version, minor
	movff	EEDATA,hi						; store minor in hi
	clrf	EEADRH							; reset EEADRH

	movlw	softwareversion_x				; get current major version
	cpfseq	lo								; compare with stored version, equal?
	bra		start_check_new_firmware_new	; NO - reset some options and store new version in EEPROM

	movlw	softwareversion_y				; get current minor version
	cpfseq	hi								; compare with stored version, equal?
	bra		start_check_new_firmware_new	; NO  - reset some options and store new version in EEPROM
	bra		start_check_new_firmware_old	; YES - both equal, do not reset options

start_check_new_firmware_new:
	; new firmware version detected
	call	show_fw_mesg_update				; show firmware update message

	; place "after-update reset" here...
	lfsr	FSR0,oPressureAdjust			; memory address of option data
	call	option_reset					; reset oPressureAdjust to factory default
	lfsr	FSR0,oPressureAdjust			; memory address of option data
	call	option_save						; save reseted value of oPressureAdjust in EEPROM

	; store current version in EEPROM
	movlw	d'1'							; set EEPROM address to 0x101
	movwf	EEADR							; = 0x001
	movwf	EEADRH							; = 0x101
	movlw	softwareversion_x				; get version, major number
	movwf	EEDATA							; prepare write
	call	write_eeprom					; execute write
	incf	EEADR,F							; set EEPROM address to 0x102
	movlw	softwareversion_y				; get version, minor number
	movwf	EEDATA							; prepare write
	call	write_eeprom					; execute write
	clrf	EEADRH							; reset EEADRH
	bra		start_check_new_firmware_common	;

start_check_new_firmware_old:
	call	show_fw_mesg_kept				; show firmware is kept message

start_check_new_firmware_common:
	call	TFT_Display_FadeIn				; display resulting screen
	call	backup_flash_page				; back-up the first 128 bytes from program flash memory to EEPROM

	; pause 5 seconds
	movlw	.5								; load loop counter
start_check_new_firmware_wait:
	call	wait_1s							; wait <= 1 second
	decfsz	WREG,W							; decrement loop counter, did it became zero?
	bra		start_check_new_firmware_wait	; NO  - loop
	;bra	restart							; YES - proceed with restart


;=============================================================================
; Entry point after warm start
;
; called on leaving sleep mode, surface menu, communication mode, and
; when a start of a dive is detected in all modes except surface mode.
;
	global	restart
restart:
	banksel	common							; for safety purpose only
	clrf	STKPTR							; clear return addresses stack
	clrf	CCP1CON							; stop PWM
	bcf		PORTC,2							; pull PWM out to GND

	call	request_speed_normal			; request CPU speed change to normal speed (for safety only)

	; manage the option settings
	btfsc	surfmode_menu					; was restart entered by return from surface menu or comm mode?
	call	option_save_all					; YES - save all settings into EEPROM

	btfss	surfmode_menu					; was restart entered by return from surface menu or comm mode?
	call	option_restore_all				; NO  - load all settings from EEPROM

	call	option_check_all				; check all options and repair them if not within their min/max boundaries

	btfsc	option_repaired					; errors found & repaired during options check?
	call	option_save_all					; YES - save corrected settings into EEPROM

	; clear flag groups
	clrf	HW_descriptor					; hardware - OSTC model descriptor
	clrf	HW_flags_state1					; hardware - states
	;										; do not clear HW_flags_state2 !
	clrf	DM_flags_sensor					; hardware - O2 sensors

	clrf	OS_flags_ISR1					; operating system - ISR control 1
	clrf	OS_flags_ISR2					; operating system - ISR control 2

	clrf	eventbase						; event triggers generated by ISR

	clrf	DM_flags_deco					; dive deco modes

	clrf	MS_flags_control				; menu system - control
	clrf	MS_flags_imprint				; menu system - data imprinting

	clrf	CVT_flags1						; convert and display functions
	clrf	CVT_flags2						; convert and display functions

	; TFT will be dimming soon, ignore ambient sensor
	bsf		tft_is_dimming

	; configure the OSTC model descriptor (stored in HW_descriptor)
	bcf		tft_power						; inverted, here needed for I2C_probe_OSTC_rx, to wake-up RX circuity
	bsf		ambient_sensor					; set ambient light sensor as available by default
	bsf		optical_input					; set optical input        as available by default

	call	lt2942_get_status				; check for gauge IC
	btfss	battery_gauge_available			; OSTC 2, cR or TR?
	bra		restart2						; NO

	; OSTC 2, cR or TR
	call	lt2942_init						; initialize battery gauge IC
	bcf		optical_input					; OSTC 2, cR and TR do not have an optical input

	banksel	ANCON0							; ANCON0 is outside access RAM
	bcf		ANCON0,7						; AN7 digital input
	banksel	common							; back to bank common
	bcf		lightsen_power					; power-down ambient light sensor
	bcf		ambient_sensor					; no ambient light sensor by default
	nop
	btfss	PORTF,2							; ambient light sensor available?
	bsf		ambient_sensor					; YES
	banksel	ANCON0							; ANCON0 is outside access RAM
	bsf		ANCON0,7						; AN7 analog again
	banksel	common							; back to bank common
	bsf		lightsen_power					; power-up ambient light sensor again

restart2:
 IFNDEF _hwos_sport
	btfsc	vusb_in							; USB power detected?
	bra		restart3						; YES
	bcf		PORTE,0							; start comm
	WAITMS	d'5'							; wait 5 ms
	btfss	vusb_in							; USB power detected?
	bra		restart3						; NO
 ENDIF
	bsf		ble_available					; YES - BLE available

restart3:
	bsf		PORTE,0							; stop comm
	btfsc	ble_available					; BLE available?
	bra		restart4						; YES - can't be a cR
	btfss	battery_gauge_available			; rechargeable?
	bra		restart4						; NO  - can't be a cR
	bsf		analog_o2_input					; set flag for analog

restart4:
	bsf		lv_core							; default to low voltage core
	movlw	0x80							; point to 0x1F780
	movwf	TBLPTRL
	movlw	0xF7
	movwf	TBLPTRH
	movlw	0x01
	movwf	TBLPTRU
	TBLRD*+									; read from 0x1F780
	movlw	0x83							; coding for low voltage core, part 1
	cpfseq	TABLAT							; equal?
	bra		restart4a						; NO - no low voltage core then
	movlw	0x81							; point to  0x1F781
	movwf	TBLPTRL
	TBLRD*+									; read from 0x1F781
	movlw	0x94 							; coding for low voltage core, part 2
	cpfseq	TABLAT							; equal?
restart4a:
	bcf		lv_core							; NO - no low voltage core then


 IFDEF _rx_functions

	; set TR functions as deactivated by default
	bcf		tr_functions_activated			; clear flag

	; search for TR module
	WAITMS	.200							; wait 200 ms while RX module boots up
	call	I2C_probe_OSTC_rx				; check for RX module and set ostc_rx_present flag if found
	btfss	ostc_rx_present					; RX module detected?
	bra		restart5						; NO

 IFDEF _rx_update

	; check if TR module firmware is up to date
	movff	rx_firmware_cur_major,hi		; copy current firmware on RX module to bank common, major
	movff	rx_firmware_cur_minor,lo		; copy current firmware on RX module to bank common, minor
	call	rx_firmware_new_major			; get latest firmware version into WREG,  major
	cpfseq	hi								; equal to current firmware on RX module, major ?
	bra		restart4b						; NO  - update
	call	rx_firmware_new_minor			; YES - get latest firmware version into WREG,  minor
	cpfseq	lo								;     - equal to current firmware on RX module, minor ?
	bra		restart4b						;       NO  - update TR module
	bra		restart4e						;       YES - no need to update

restart4b:
	; print TR module update message
	call	TFT_boot						; initialize TFT (includes clear screen & backlight switch-off)
	WIN_TOP  .40							; show heinrichsweikamp logo
	WIN_LEFT .10
	TFT_WRITE_PROM_IMAGE_BY_ADDR hw_logo_block
	WIN_SMALL .10,.130
	STRCAT_PRINT "Updating TR Module..."	; print update message
	call	TFT_Display_FadeIn				; display screen
	WIN_SMALL .10,.160
	STRCAT	"TR Update "					; prepare result message

	; update firmware in RX module
	call	I2C_sleep_compass				; stop compass
	call	update_tr_module				; update TR module

	WIN_SMALL .10,.160						; set next output position
	STRCAT	"Update "						; common part of result message
	btfss	ostc_rx_present					; data transfer successful and TR module up & running again?
	bra		restart4c						; NO
	STRCAT	"to "							; YES - print success message
	call	TFT_print_firmware_rx			;     - print installed version
	STRCAT_PRINT " done"					;     - complete result message
	bra		restart4d						;     - show message for a while

restart4c:
	STRCAT_PRINT "failed"					; complete result message - failure

restart4d:
	call	wait_1s							; wait (up to)        1 second
	call	wait_1s							; wait (another full) 1 second
	call	wait_1s							; wait (another full) 1 second

 ENDIF	; _rx_update

restart4e:
	btfss	ostc_rx_present					; TR module up & running?
	bra		restart5						; NO
	movff	opt_TR_mode,WREG				; YES - get TR mode
	tstfsz	WREG							;     - TR mode <> off ?
	bsf		tr_functions_activated			;       YES - set TR functions as activated

 ENDIF	; _rx_functions


restart5:
	; manage hardware
	btfss	analog_o2_input					; OSTC with analog input?
	bsf		TRISB,3							; NO - shut down power supply for S8 bulkhead

	btfss	battery_gauge_available			; OSTC with gauge IC?
	bsf		TRISG,0							; NO

	call	ext_flash_disable_protection	; disable write protection for external flash

	btfsc	use_old_batt_flag				; shall reload last battery data?
	call	get_battery_data				; YES - get last battery data

	; set screen orientation
	bcf		flip_screen						; set default screen orientation
	TSTOSC	opt_flip_screen					; shall show screen outputs upside down? (=1: flip the screen)
	bsf		flip_screen						; YES - set upside-down orientation

	; check if high-altitude mode is applicable
	bcf		high_altitude_mode				; disable high altitude mode by default
	MOVII	pressure_abs_ref,         sub_a	; copy last surface pressure to sub_a
	MOVLI	high_altitude_threshold+1,sub_b	; copy high-altitude threshold (880 mbar) + 1 to sub_a
	call	cmpU16							; sub_a - sub_b = pressure_abs_ref - (high_altitude_threshold + 1)
	btfsc	neg_flag						; result negative (absolute pressure <= 880 mbar) ?
	bsf		high_altitude_mode				; YES - enable high altitude mode

	; check if there was a cold start, if yes do initial computation of further deco data
	btfss	cold_start						; did a cold start?
	bra		restart6						; NO
	bcf		cold_start						; YES - clear flag
	call	deco_calc_dive_interval_1min	;     - calculate tissues for 1 minute at surface conditions (C-code)
	call	deco_calc_desaturation_time		;     - calculate desaturation and no-fly/no-altitude time   (C-code)
	banksel	common							;     - back to bank common

restart6:
	; the dive mode flag can not be set right after cold start, must have been in surface mode before
	btfsc	divemode						; shall enter dive mode?
	goto	diveloop						; YES

	btfsc	RCON,POR						; was this a power-on reset?
	goto	surfloop						; NO  - enter surface mode
	bsf		RCON,POR						; YES - acknowledge detection and re-arm detector
	goto	do_new_battery_select			;     - prompt for battery selection, will proceed to surface mode


;=============================================================================
; Setup all flags and parameters for dive mode and simulator computations
;
; called from divemode.asm, menu_tree.asm and surfmode.asm
;
	global	restart_set_modes_and_flags
restart_set_modes_and_flags:
	call	option_restore_all				; restore all options settings from EEPROM
	call	disable_ir_s8					; switch off IR/S8 digital interface by default (for all compile versions!)

 IFDEF _external_sensor
	WAITMS	d'100'							; some delay to power down S8-HUD properly
 ENDIF

	; setup sampling rate
	movlw	.2								; default to 2 seconds
	movwf	sampling_rate					; write setting
	TSTOSS	opt_sampling_rate				; check option: 1= 10s, 0= 2s
	bra		restart_set_modes_and_flags1	; 0 - 2 seconds selected, done
	movlw	.10								; 1 - change to 10 seconds
	movwf	sampling_rate					;   - write setting

restart_set_modes_and_flags1:
	clrf	DM_flags_deco					; clear all deco mode flags

	; initialize active_gas and active_dil for surface mode pressure display
	call	get_first_gas_to_WREG
	movwf	active_gas

 IFDEF _ccr_pscr
	call	get_first_dil_to_WREG
	movwf	active_dil
 ENDIF

	; configure saturation / desaturation safety factors
	movff	opt_sat_multiplier_gf,  char_I_saturation_multiplier		; use factors for GF mode by default
	movff	opt_desat_multiplier_gf,char_I_desaturation_multiplier		; ...
	TSTOSC	char_I_deco_model											; get deco model ZH-L16-GF (1) selected?
	bra		restart_set_modes_and_flags2								; YES - keep them
	movff	opt_sat_multiplier_non_gf,  char_I_saturation_multiplier	; NO  - overwrite them with non-GF factors
	movff	opt_desat_multiplier_non_gf,char_I_desaturation_multiplier	;     - ...

restart_set_modes_and_flags2:
	; configure GF settings, GF high is needed for color-coding the current GF (supersaturation) factor
	movff	opt_GF_low, char_I_GF_Low_percentage
	movff	opt_GF_high,char_I_GF_High_percentage

	movff	opt_dive_mode,lo				; get dive mode: 0= OC, 1= CCR, 2= gauge, 3= apnea, 4= pSCR
	tstfsz	lo								; OC?
	bra		restart_set_modes_and_flags3	; NO
	bsf		FLAG_oc_mode					; YES - set OC flag
 IFDEF _rx_functions
	call	option_cleanup_oTrMode_no_CCR	;     - revert TR mode from 'CCR Dil+O2' to 'on'
 ENDIF
	return									;     - done

restart_set_modes_and_flags3:
	decfsz	lo,F							; CCR mode?
	bra		restart_set_modes_and_flags4	; NO
 IFDEF _ccr_pscr
	bsf		FLAG_ccr_mode					; YES - set CCR flag
	call	option_cleanup_oCCRMode_CCR		;     - revert CCR mode 'Sensor' to 'fixed SP' if no sensor interface available
 IFDEF _rx_functions
	call	option_cleanup_oTrMode_CCR		;     - revert TR mode from 'ind.double' to 'on'
 ENDIF	; _rx_functions
 IFDEF _external_sensor
	call	enable_ir_s8					;     - enable IR/S8 digital interface
 ENDIF	; _external_sensor
 ENDIF	; _ccr_pscr
	return									;     - done

restart_set_modes_and_flags4:
	decfsz	lo,F							; Gauge mode?
	bra		restart_set_modes_and_flags5	; NO
	bsf		FLAG_gauge_mode					; YES - set gauge flag
 IFDEF _rx_functions
	call	option_cleanup_oTrMode_no_CCR	;     - revert TR mode from 'CCR Dil+O2' to 'on'
 ENDIF
	return									;     - done

restart_set_modes_and_flags5:
	decfsz	lo,F							; Apnea mode?
	bra		restart_set_modes_and_flags6	; NO
	bsf		FLAG_apnoe_mode					; YES - set apnea flag
	movlw	samplingrate_apnoe				; get apnoe sampling rate
	movwf	sampling_rate					; overwrite user-selected 2/10 seconds setting with apnoe default
 IFDEF _rx_functions
	call	option_cleanup_oTrMode_no_CCR	;     - revert TR mode from 'CCR Dil+O2' to 'on'
 ENDIF
	return									;     - done

restart_set_modes_and_flags6:
											; pSCR mode then
 IFDEF _ccr_pscr
	bsf		FLAG_pscr_mode					;     - set pSCR mode flag
	call	option_cleanup_oCCRMode_pSCR	;     - revert AutoSP to calculated SP, additionally revert Sensor to fixed SP if no sensor interface available
 IFDEF _rx_functions
	call	option_cleanup_oTrMode_no_CCR	;     - revert TR mode from 'CCR Dil+O2' to 'on'
 ENDIF	; _rx_functions
 IFDEF _external_sensor
	call	enable_ir_s8					;     - enable IR/S8 digital interface
 ENDIF	; _external_sensor
 ENDIF	; _ccr_pscr
	return									;     - done


;=============================================================================
; Sample and store the current surface pressure, update ISR and deco engine
; with the surface pressure sampled on last invocation.
;
	global	sample_surface_pressure
sample_surface_pressure:
	; make sure the ISR does not read the surface pressure reference buffer while it is updated
	bcf		update_surface_pressure			; cancel any pending load request

	; propagate the surface pressure sampled on last invocation to the reference pressure buffer
	MOVII	pressure_abs_sampled,pressure_abs_ref

	; update surface pressure in the ISR
	bsf		update_surface_pressure			; request ISR to update its surface pressure

	; update surface pressure in the deco engine
	MOVII	pressure_abs_ref,int_I_pres_surface

	; sample current absolute pressure (ISR-safe 2 byte copy)
	SMOVII	pressure_abs,pressure_abs_sampled

	; limit sampled pressure to max allowed surface pressure
	MOVLI	max_surfpressure,    sub_a		; load upper limit    into sub_a
	MOVII	pressure_abs_sampled,sub_b		; copy sampled pressure to sub_b
	call	cmpU16							; sub_a - sub_b = max_surfpressure - pressure_abs_sampled
	btfss	neg_flag						; sampled pressure > max_surfpressure ?
	return									; NO  - below limit, done
	MOVII	sub_a,pressure_abs_sampled		; YES - limit to max_surfpressure (still stored in sub_a)
	return									;     - done


	END