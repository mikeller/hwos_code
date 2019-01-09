;=============================================================================
;
;   File start.asm									REFACTORED VERSION	V2.99e
;
;   Startup subroutines
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;  2011-08-06 : [mH] moving from OSTC code

#include "hwos.inc"							; mandatory header
#include "ms5541.inc"
#include "isr.inc"
#include "shared_definitions.h"				; mailbox from/to p2_deco.c
#include "eeprom_rs232.inc"
#include "math.inc"
#include "tft.inc"
#include "surfmode.inc"
#include "wait.inc"
#include "rtc.inc"
#include "external_flash.inc"
#include "convert.inc"
#include "strings.inc"
#include "tft_outputs.inc"
#include "adc_lightsensor.inc"
#include "i2c.inc"

	extern	init_ostc
	extern	option_restore_all
	extern	restore_decodata_from_eeprom
	extern	oPressureAdjust
	extern	option_reset
	extern	option_save
	extern	option_save_all
	extern	option_check_all
	extern	do_new_battery_select
	extern	use_old_batteries
	extern	use_old_prior_209
	extern	get_first_gas_to_WREG
	extern	get_first_dil_to_WREG
	extern	option_cleanup_oCCRMode_pSCR
	extern	option_cleanup_oCCRMode_CCR

 IFDEF _rx_functions
	extern	option_cleanup_oTrMode_CCR
	extern	option_cleanup_oTrMode_no_CCR
 ENDIF


;=============================================================================
; Reset Vector: entry point on device wake-up and hard reset
;
reset_v code 0x00000

;	goto	start
	goto	0x1FF00							; bootloader

	ORG		0x00004							; needed for second-level bootloader
	goto	start

;=============================================================================

boot		CODE

;=============================================================================

	global	start
start:
	lfsr	FSR0,0x000						; clear ram-banks 0-14
clear_rambank:
	clrf	POSTINC0
	movlw	0x0F
	cpfseq	FSR0H							; bank 14 done?
	bra		clear_rambank					; NO - loop

	call	init_ostc						; initialize hardware (ports, timers, etc.)

	; get button type from Bootloader-Info
	movlw	.16
	movff	WREG,analog_counter				; initialize averaging
	bsf		analog_switches
	movlw	0x7C
	movwf	TBLPTRL
	movlw	0xF7
	movwf	TBLPTRH
	movlw	0x01
	movwf	TBLPTRU
	TBLRD*+									; reads 0x07 for analog buttons
	movlw	0x07
	cpfseq	TABLAT
	bcf		analog_switches

	; get screen type (2) from Bootloader-Info
	bsf	screen_type2
	movlw   0x80
	movwf   TBLPTRL		; Only adjust low byte. High and Upper are still 0x01F7...
	TBLRD*+			; Reads 0x83 for screen 2
	movlw	0x83
	cpfseq	TABLAT
	bcf	screen_type2

	; read button polarity
	movlw	LOW  .897
	movwf	EEADR
	movlw	HIGH .897
	movwf	EEADRH
	call	read_eeprom						; EEDATA into EEPROM @ EEADR
	clrf	EEADRH							; reset EEADRH
	movff	EEDATA,button_polarity			; 0xFF (both normal), 0x00 (both inverted), 0x01 (left inverted only), 0x02 (right inverted only)

	; air pressure compensation after reset
	call	get_calibration_data			; get calibration data from pressure sensor
	banksel	common							; get_calibration_data uses isr_backup

	call	TFT_DisplayOff					; turn off display
	bsf		LEDr							; turn on  red LED
	bcf		pressure_refresh
	; first pass will not have valid temperature
	btfss	pressure_refresh				; air pressure compensation
	bra		$-2
	; second pass
	bcf		pressure_refresh
	btfss	pressure_refresh				; air pressure compensation
	bra		$-2
	bcf		LEDr

	clrf	rel_pressure+0
	clrf	rel_pressure+1
	clrf	surface_interval+0
	clrf	surface_interval+1

	SAFE_2BYTE_COPY amb_pressure, last_surfpressure

	movlw	LOW  max_surfpressure
	movff	WREG,sub_a+0					; max. "allowed" air pressure in mbar
	movlw	HIGH max_surfpressure
	movff	WREG,sub_a+1					; max. "allowed" air pressure in mbar
	movff	last_surfpressure+0,sub_b+0
	movff	last_surfpressure+1,sub_b+1
	call	subU16							; sub_c = sub_a - sub_b
	btfss	neg_flag						; is 1080 mbar < amb_pressure ?
	bra		start_copy_pressure				; NO - current air pressure is lower then "allowed" air pressure, ok

	; not ok - overwrite with max. "allowed" air pressure
	movlw	LOW  max_surfpressure
	movff	WREG,last_surfpressure+0		; max. "allowed" air pressure in mbar
	movlw	HIGH max_surfpressure
	movff	WREG,last_surfpressure+1		; max. "allowed" air pressure in mbar

start_copy_pressure:
	movff	last_surfpressure+0,last_surfpressure_15min+0
	movff	last_surfpressure+1,last_surfpressure_15min+1
	movff	last_surfpressure+0,last_surfpressure_30min+0
	movff	last_surfpressure+1,last_surfpressure_30min+1	; resets all air pressure registers

	; initialize GF high (needed by deco engine for color-coding the GF value)
	movff	opt_GF_high,char_I_GF_High_percentage

	SAFE_2BYTE_COPY amb_pressure,int_I_pres_respiration		; breathing at surface
	movff	int_I_pres_respiration+0,int_I_pres_surface+0	; surface pressure
	movff	int_I_pres_respiration+1,int_I_pres_surface+1

	call	deco_clear_tissue				; set all tissues to Pamb * N2_ratio (code located in p2_deco.c)
	banksel	common							; back to bank 1, needed after every return from C code

	call	rtc_init						; init clock

	movlw	HIGH .512						; =2
	movwf	EEADRH
	read_int_eeprom	.0
	clrf	EEADRH
	movlw	0xAA
	cpfseq	EEDATA							; =0xAA
	bra		no_deco_restore					; NO
	call	restore_decodata_from_eeprom	; reload deco data and date/time from eeprom
no_deco_restore:
	call	deco_calc_dive_interval_1min	; calculate deco in surface mode
	call	deco_calc_desaturation_time		; calculate desaturation and no-fly time
	banksel	common

	bcf		menubit							; clear menu flag

	; check for power-on reset here

	; *****************************************************************************
	; "new_battery_menu" and "use_old_batteries" 'goto' back to "power_on_return"
	; *****************************************************************************

	; Try to migrate the old battery status from firmware 2.09 or earlier..
	btfsc	RCON,POR						; was this a power-on reset?
	call	use_old_prior_209				; NO

	bcf		use_old_batt_flag
	btfsc	RCON,POR						; was this a power-on reset?
	bsf		use_old_batt_flag				; NO
 
	call	lt2942_get_status				; check for gauge IC
	btfss	battery_gauge_available			; cR or 2 hardware?
	bra		check_firmware_new				; NO  - skip next
	movlw	.30								; YES - reset button sensitivity
	movff	WREG,opt_cR_button_right
	movff	WREG,opt_cR_button_left			; reset on power-on reset
	call	piezo_config					; configure buttons
	call	piezo_config					; configure buttons (2 times)

check_firmware_new:
	call	TFT_boot						; initialize TFT (includes clear screen)
	clrf	CCPR1L							; backlight off

	WIN_TOP  .40
	WIN_LEFT .10
	TFT_WRITE_PROM_IMAGE_BY_ADDR hw_logo_block ; show heinrichsweikamp logo

	call	TFT_standard_color

	WIN_SMALL .20,.100
	STRCPY_PRINT "Update successful!"		; hard coded since language switch does not work here

	WIN_SMALL .20,.140
	STRCPY	"New Firmware: "
	call	TFT_cat_firmware				; show firmware version x.y and color-code if outdated
	STRCAT_PRINT ""							; finalize output
	bcf		win_invert						; reset inverted output if firmware is outdated
	call	TFT_standard_color				; reset color           if firmware is outdated

	WIN_SMALL .60,.180
	call	TFT_cat_beta_release			; if it is a beta version, show "BETA" + issue, else "Release"
	STRCAT_PRINT ""							; finalize output
	call	TFT_standard_color				; reset color

	call	TFT_Display_FadeIn				; display resulting surface screen

	; check if a new firmware was loaded, if yes reset Custom Function oPressureAdjust
	movlw	d'1'
	movwf	EEADR							; =1
	movwf	EEADRH							; =1
	call	read_eeprom						; read current version x
	movff	EEDATA,lo
	incf	EEADR,F							; set to 0x102
	call	read_eeprom						; read current version y
	movff	EEDATA,hi
	clrf	EEADRH							; reset EEADRH

	movlw	softwareversion_x
	cpfseq	lo								; compare version x
	bra		check_firmware_new4				; is not equal -> reset CF and store new version in EEPROM

	movlw	softwareversion_y
	cpfseq	hi								; compare version y
	bra		check_firmware_new4				; is not equal -> reset CF and store new version in EEPROM
	bra		check_firmware_new5				; x and y are equal -> do not reset CF

check_firmware_new4:
	; place "after-update reset" here...
	lfsr	FSR0,oPressureAdjust
	call	option_reset					; reset oPressureAdjust to factory default
	lfsr	FSR0,oPressureAdjust
	call	option_save						; save new value of oPressureAdjust in EEPROM

check_firmware_new5:
	rcall	backup_flash_page				; backup the first 128 bytes from flash to EEPROM

	movlw	d'1'							; store current version in EEPROM
	movwf	EEADR							; =1
	movwf	EEADRH							; =1
	movlw	softwareversion_x
	movwf	EEDATA
	call	write_eeprom					; write version, major number
	incf	EEADR,F							; set to 0x102
	movlw	softwareversion_y
	movwf	EEDATA
	call	write_eeprom					; write version, minor number
	clrf	EEADRH							; reset EEADRH

	; wait 10 seconds
	movlw	.10								; load loop counter
check_firmware_new6:
	call	wait_1s							; wait (about) 1 second
	decfsz	WREG,W							; YES - decrement loop counter, did it became zero?
	bra		check_firmware_new6				;       NO  - loop
	;bra	restart							;       YES - proceed with restart


	global	restart
restart:
	clrf	STKPTR							; never return from here
	clrf	CCP1CON							; stop PWM
	bcf		PORTC,2							; pull PWM out to GND

	btfsc	menubit							; return from Menu/COMM mode or timeout?
	call	option_save_all					; YES - save all settings into EEPROM

	call	option_restore_all				; restore everything from EEPROM into RAM
	call	option_check_all				; check all options (and reset if not within their min/max boundaries)
	call	option_save_all					; save all settings into EEPROM after they have been checked

	clrf	flag1							; clear all flags
	clrf	flag2
	clrf	flag3
	clrf	flag4
	clrf	flag5
	clrf	flag6
	clrf	flag7
	clrf	flag8
	clrf	flag9
	clrf	flag10 ; Clears flag "enable_screen_dumps" - making screen dumps impossible... TODO
	; do not clear flag11 (sensor calibration and charger status)
	clrf	flag12
	; do not clear flag13 (important hardware flags)
	clrf	flag14
	clrf	flag15
	clrf	flag16
	clrf	flag17

	clrf	cvt_flags

	clrf	tft_update_flags+0
	clrf	tft_update_flags+1
	clrf	tft_update_flags+2

	clrf	hardware_flag1					; hardware descriptor 1
	;		hardware_flag2					; hardware descriptor 2 - do not clear here!

	bsf		tft_is_dimming					; TFT is dimming up (soon), ignore ambient sensor!

	; configure hardware descriptor 1
	bcf		tft_power						; inverted, here needed for I2C_probe_OSTC_rx, to wake-up RX circuity
	bsf		ambient_sensor					; set flag
	bsf		optical_input					; set flag

	call	lt2942_get_status				; check for gauge IC
	btfss	battery_gauge_available			; cR/2 hardware?
	bra		restart2						; NO
	call	lt2942_init						; YES - initialize battery gauge IC
	bcf		optical_input					; clear flag

	banksel	0xF16
	bcf		ANCON0,7						; AN7 digital input
	banksel	common
	bcf		lightsen_power					; power-down ambient light sensor
	bcf		ambient_sensor					; clear flag
	nop
	btfss	PORTF,2							; light sensor available?
	bsf		ambient_sensor					; YES
	banksel	0xF16
	bsf		ANCON0,7						; AN7 analog again
	banksel	common
	bsf		lightsen_power					; power-up ambient light sensor again

restart2:
	btfsc	vusb_in
	bra		restart3						; USB (and powered on)
	bcf		PORTE,0							; start comms
	WAITMS	d'1'
	btfss	vusb_in
	bra		restart3						; USB (and powered off)
	bsf		ble_available					; BLE available

restart3:
	bsf		PORTE,0							; stop comms
	btfsc	ble_available					; BLE available?
	bra		restart4						; YES - can't be a cR
	btfss	battery_gauge_available			; rechargeable?
	bra		restart4						; NO  - can't be a cR
	bsf		analog_o2_input					; set flag for analog

restart4:
 IFDEF _rx_functions
	WAITMS	d'200'
	call	I2C_probe_OSTC_rx				; set ostc_rx_present flag if this is an OSTC TR model

	; The hardware descriptor is now:
	; 0x11: 2 with BLE
	; 0x13: +/2 with BLE & ambient
	; 0x05: cR
	; 0x0A: 3
	; 0x1A: 3 with BLE
	; 0x33: 2 TR

	btfss	ostc_rx_present					; OSTC TR detected?
	bra		restart5						; NO
	movff	opt_TR_mode,WREG				; YES - get user-selected TR mode
	tstfsz	WREG							;       TR functions switched on?
	bsf		FLAG_tr_enabled					;       YES - switch on displays and calculation functions
 ENDIF

	; configure hardware descriptor 2
	; flag  screen_type                  will be configured on each call of TFT_boot
	; flags compass_type & compass_type2 will be configured on each call of I2C_init_compass
	; flag  analog_switches              will be configured directly after hard start (in start:)

restart5:
	; Select high altitude (fly) mode?
	movff	last_surfpressure_30min+0,sub_b+0
	movff	last_surfpressure_30min+1,sub_b+1
	movlw	HIGH high_altitude_threshold
	movwf	sub_a+1
	movlw	LOW  high_altitude_threshold	; hard-wired 880 hPa
	movwf	sub_a+0
	call	subU16							; sub_c = sub_a - sub_b
	btfss	neg_flag						; result negative (ambient > 880 hPa)?
	bsf		high_altitude_mode				; NO - set flag

	btfss	analog_o2_input
	bsf		TRISB,3
	btfss	battery_gauge_available
	bsf		TRISG,0
	call	ext_flash_disable_protection	; disable write protection for external flash

	bsf		flip_screen						; select screen flip 180°
	TSTOSS	opt_flip_screen					; shall actually flip? (=1: flip the screen)
	bcf		flip_screen						; NO - revert to normal orientation

	btfsc	use_old_batt_flag				; =1: load old battery information after power-on reset
	goto	use_old_batteries				; returns to surface loop

	btfsc	RCON,POR						; was this a power-on reset?
	goto	surfloop						; YES - jump to surface loop
	bsf		RCON,POR						; set bit for next detection
	; Things to do after a power-on reset
	goto	do_new_battery_select			; returns to surface loop

;=============================================================================
; Setup all flags and parameters for divemode and simulator computations.
;
	global	restart_set_modes_and_flags
restart_set_modes_and_flags:				; "Call"ed from dive mode as well
	call	option_restore_all				; restore everything from EEPROM

	; Setup sampling rate
	movlw	.2
	movwf	samplingrate
	TSTOSS	opt_sampling_rate				; =1: 10s, =0: 2s
	bra		restart_set_modes_and_flags1
	movlw	.10
	movwf	samplingrate

restart_set_modes_and_flags1:
	bcf		FLAG_gauge_mode
	bcf		FLAG_apnoe_mode
	bcf		FLAG_oc_mode
	bcf		FLAG_ccr_mode
	bcf		FLAG_pscr_mode
	bcf		FLAG_bailout_mode
	call	disable_ir_s8					; IR off

 IFDEF _cave_mode
	bsf		FLAG_cave_mode					; enable cave mode by default
	movff	opt_calc_asc_gasvolume,WREG		; get gas needs calculation mode (0=off, 1=on, 2=cave mode)
	xorlw	.2								; coding for cave mode
	tstfsz	WREG							; cave mode enabled?
	bcf		FLAG_cave_mode					; NO - disable cave mode again
	bcf		FLAG_cave_mode_shutdown			; clear flag for cave mode shutdown
	bcf		FLAG_dive_turned				; clear flag for dive turned
	bcf		gas_needs_mode_last				; set last gas calculation results as direct ascent needs
 ENDIF

	; Initialize active_gas and active_dil for surface mode pressure display
	call	get_first_gas_to_WREG
	movwf	active_gas
	call	get_first_dil_to_WREG
	movwf	active_dil

	; Setup char_I_saturation_multiplier and char_I_desaturation_multiplier
	movff	opt_sat_multiplier_gf,char_I_saturation_multiplier
	movff	opt_desat_multiplier_gf,char_I_desaturation_multiplier
	movff	char_I_deco_model,lo			; 0 = ZH-L16, 1 = ZH-L16-GF
	tstfsz	lo
	bra		restart_set_modes_and_flags1b
	movff	opt_sat_multiplier_non_gf,char_I_saturation_multiplier
	movff	opt_desat_multiplier_non_gf,char_I_desaturation_multiplier

restart_set_modes_and_flags1b:
	movff	opt_dive_mode,lo				; 0=OC, 1=CC, 2=Gauge, 3=Apnea, 4=PSCR
	tstfsz	lo
	bra		restart_set_modes_and_flags2

	; OC Mode
	bsf		FLAG_oc_mode					; =1: OC mode active
 IFDEF _rx_functions
	call	option_cleanup_oTrMode_no_CCR	; revert TR mode from 'CCR Dil+O2' to 'on'
 ENDIF
	return

restart_set_modes_and_flags2:
	decfsz	lo,F
	bra		restart_set_modes_and_flags3

	; CCR Mode
	bsf		FLAG_ccr_mode					; =1: CCR mode (Fixed SP, Auto SP or Sensor) active
	call	option_cleanup_oCCRMode_CCR		; revert CCR mode 'Sensor' to 'fixed SP' if no sensor interface available
 IFDEF _rx_functions
	call	option_cleanup_oTrMode_CCR		; revert TR mode from 'ind.double' to 'on'
 ENDIF
	call	enable_ir_s8					; enable IR/S8 port
	return

restart_set_modes_and_flags3:
	decfsz	lo,F
	bra		restart_set_modes_and_flags4

	; Gauge Mode
	bsf		FLAG_gauge_mode					; =1: in gauge mode
 IFDEF _rx_functions
	call	option_cleanup_oTrMode_no_CCR	; revert TR mode from 'CCR Dil+O2' to 'on'
 ENDIF
	return

restart_set_modes_and_flags4:
	decfsz	lo,F
	bra		restart_set_modes_and_flags5

	; Apnea Mode
	bsf		FLAG_apnoe_mode					; =1: in Apnea mode
 IFDEF _rx_functions
	call	option_cleanup_oTrMode_no_CCR	; revert TR mode from 'CCR Dil+O2' to 'on'
 ENDIF
	return									; start in surface mode

restart_set_modes_and_flags5:
	; pSCR Mode
	bsf		FLAG_pscr_mode					; set pSCR mode flag
	call	option_cleanup_oCCRMode_pSCR	; in pSCR mode, revert AutoSP (2) to calculated SP (0), additionally revert Sensor to fixed SP if no sensor interface available
 IFDEF _rx_functions
	call	option_cleanup_oTrMode_no_CCR	; revert TR mode from 'CCR Dil+O2' to 'on'
 ENDIF
	call	enable_ir_s8					; enable IR/S8 port
	return									; start in surface mode


; backup the first 128 bytes from flash to EEPROM
backup_flash_page:
	; Start address in internal flash
	movlw	0x00
	movwf	TBLPTRL
	movwf	TBLPTRH
	movwf	TBLPTRU

	movlw	.128
	movwf	lo								; byte counter
	clrf	EEADR
	movlw	.3
	movwf	EEADRH							; setup backup address

	TBLRD*-									; dummy read to be in 128 byte block
backup_flash_loop:
	tblrd+*									; table read with pre-increment
	movff	TABLAT,EEDATA					; put 1 byte
	call	write_eeprom					; save it in EEPROM
	incf	EEADR,F
	decfsz	lo,F							; 128 byte done?
	bra		backup_flash_loop				; NO - loop
	clrf	EEADRH							; reset EEADRH
	return									; done

	END