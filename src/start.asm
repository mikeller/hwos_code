;=============================================================================
;
;   File start.asm                          * combined next generation V3.11.1
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
	extern	backup_flash_page
	extern	eeprom_deco_data_read
	extern	option_restore_and_check_all
	extern	option_restore_and_check
	extern	option_check_and_store_all
	extern	option_check_and_store
	extern	option_reset
	extern	rtc_init
	extern	new_battery_select
	extern	get_battery_data
	extern	use_old_prior_209
	extern	get_first_gas_to_WREG

	extern	oFirmwareMajor
	extern	oFirmwareMinor
	extern	oPressureAdjust
	extern	get_cpu_version

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
	extern	dyn_show_firmware_rx
 ENDIF


;=============================================================================
; Reset Vector: Entry Point on Device Wake-up and hard Reset
;
reset_v		CODE 0x00000
	goto	0x1FF00							; jump to bootloader

start_v		CODE 0x00004					; jump to application (cold-)start
	goto	start
;
;=============================================================================


;=============================================================================
; Firmware Identification
;
fingerprint	CODE 0x0000A
	db	fw_version_major,		fw_version_minor		; major,         minor
	db	fw_version_beta,		FW_ID					; beta/release,  firmware ID
	db	firmware_creation_year,	firmware_creation_month	; creation year, month
	db	firmware_creation_day,	FW_CONF 				; creation day,  firmware configuration
	db	0x00,					0x00					; reserved for future use
	db	0x00,					0x00					; reserved for future use
	db	0x00,					0x00					; reserved for future use
;
;=============================================================================


;=============================================================================
boot1	CODE
;=============================================================================


;-----------------------------------------------------------------------------
;
; Entry Point after cold Start
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

	; initialize averaging for analog buttons before IRQ gets enabled
	movlw	.16								; set averaging span
	movff	WREG,analog_counter				; write to counter (in bank isr_backup)

	; initialize 1/4 second counting register
	movlw	.4						; 62,5ms * 4 = 1/4 second
	movff	WREG,isr_tmr7_helper

	; initialize hardware (ports, timers) and start interrupts
	call	init_ostc						; also selects bank common and sets CPU to normal speed
	
	; get CPU type and set less_io_cpu bit
	call	get_cpu_version

	; flag that later restart origins from a cold start
	bsf		cold_start

	; get button type from bootloader info
	bsf		analog_switches					; assume analog buttons by default
	movlw	0x7C							; set up read from 0x01F77C
	movwf	TBLPTRL							; ...
	movlw	0xF7							; ...
	movwf	TBLPTRH							; ...
	movlw	0x01							; ...
	movwf	TBLPTRU							; ...
	TBLRD*+									; read configuration byte
	movlw	0x07							; coding for analog buttons
	cpfseq	TABLAT							; equal?
	bcf		analog_switches					; NO - no analog buttons

	; get screen type (2) from bootloader info
	bsf		screen_type2					; set flags for later clear of the false one
	bsf		screen_type3					; ...
	movlw	0x80							; set up read from 0x01F780
	movwf	TBLPTRL							; ...
	;movlw	0xF7							; high and upper are still at 0x01F7xx
	;movwf	TBLPTRH							; ...
	;movlw	0x01							; ...
	;movwf	TBLPTRU							; ...
	TBLRD*+									; read configuration byte
	movlw	0x83							; coding for screen type 2
	cpfseq	TABLAT							; equal?
	bcf		screen_type2					; NO  -  not screen type 2
	movlw	0x84							; coding for screen type 3
	cpfseq	TABLAT							; equal?
	bcf		screen_type3					; NO  -  not screen type 3

	; get button polarity from configuration data (EEPROM)
	EEPROM_CC_READ eeprom_button_polarity,button_polarity

	; initialize pressure sensor calibration
	call	I2C_probe_pressure_sensor		; Probe the type of sensor, set/clear press_sensor_type
	call	get_calibration_data			; get calibration data from pressure sensor
	
	call	TFT_DisplayOff					; turn off display
	bsf		LEDr							; turn on red LED

	; wait for valid temperature and pressure
	btfsc	press_sensor_type			; New sensor found?
	call	I2C_get_temp_val_MS5837			; (Will set ms5837_state)
	WAITMS	.250
	btfsc	press_sensor_type			; New sensor found?
	call	I2C_get_press_val_MS5837		; (Will clear ms5837_state)
	WAITMS	.250
	btfsc	press_sensor_type			; New sensor found?
	call	I2C_get_temp_val_MS5837			; (Will set ms5837_state)
	WAITMS	.250
	btfsc	press_sensor_type			; New sensor found?
	call	I2C_get_press_val_MS5837		; (Will clear ms5837_state)
	WAITMS	.250

	; sensor calibration completed, first valid pressure value is available
	bcf		LEDr							; turn off red LED

	; initial loading of the surface pressure into the ISR
	; needs to be done twice in order to shift the current absolute pressure through
	; the sampling buffer into the reference buffer from where it is loaded by the ISR
	call	sample_surface_pressure			; 1st pass
	call	sample_surface_pressure			; 2nd pass

	; wait until initial surface pressure value has been loaded into the ISR
	btfsc	update_surface_pressure			; has the ISR confirmed loading of the surface pressure?
	bra		$-2								; NO - not yet, loop until ISR has confirmed loading

	; reset all tissue pressures to surface pressure equilibrium state by default
	call	deco_clear_tissue				; (C-code)
	banksel	common							; back to bank common

	; restore deco status from EEPROM (if possible)
	EEPROM_CC_READ eeprom_deco_data_validity,WREG	; read deco data validity
	xorlw	DECO_DATA_VALID_TOKEN					; deco data valid?
	bnz		start_clean								; NO  - start "clean"
	EEPROM_CC_READ eeprom_deco_data_version,WREG	; YES - read deco data format version
	xorlw	eeprom_vault_version					;     - deco data format compatible?
	bnz		start_clean								;       NO  - start "clean"
	call	eeprom_deco_data_read					;       YES - restore deco data from EEPROM
	bra		start_common							;           - continue with common part

start_clean:
	bsf		reset_surface_interval			; request ISR to reset the surface interval timer
	btfss	RCON,POR						; was there a power outage ?
	call	rtc_init						; YES - initialize RTC to firmware creation date

start_common:
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

	; check if a new firmware was loaded
	lfsr	FSR0,oFirmwareMajor				; address firmware version
	call	option_restore_and_check		; read    firmware version, major
	call	option_restore_and_check		; read    firmware version, minor
	call	option_restore_and_check		; read    firmware version, beta

	movff	opt_fw_version_major,WREG		; get stored major version
	xorlw	fw_version_major				; compare with currently active version, equal?
	bnz		start_check_new_firmware_new	; NO  - a new firmware was loaded

	movff	opt_fw_version_minor,WREG		; get stored minor version
	xorlw	fw_version_minor				; compare with currently active version, equal?
	bnz		start_check_new_firmware_new	; NO  - a new firmware was loaded

	movff	opt_fw_version_beta,WREG		; get stored beta version
	xorlw	fw_version_beta					; compare with currently active version, equal?
	bnz		start_check_new_firmware_new	; NO  - a new firmware was loaded
	;bz		start_check_new_firmware_old	; YES - same  firmware as  before

start_check_new_firmware_old:
	call	TFT_message_fw_kept				; show firmware is kept message
	bra		start_check_new_firmware_common	; continue with common part

start_check_new_firmware_new:
	call	TFT_message_fw_update			; show firmware is updated message

;	; reset the pressure sensor correction to factory default
;	lfsr	FSR0,oPressureAdjust			; address pressure sensor correction
;	call	option_reset					; set correction to default
;
;	lfsr	FSR0,oPressureAdjust			; address pressure sensor correction
;	call	option_check_and_store			; update correction in EEPROM

start_check_new_firmware_common:
	call	TFT_Display_FadeIn				; display resulting screen

	call	backup_flash_page				; back-up the first 128 bytes from program flash memory to EEPROM
	call	option_restore_and_check_all	; restore all option values from EEPROM and check them

	WAITS	.5								; wait 5 second

	goto	restart							; proceed with restart


;=============================================================================
boot2	CODE
;=============================================================================


;-----------------------------------------------------------------------------
; Sample and store the current Surface Pressure
; Update ISR and Deco Engine with Pressure sampled on last Invocation
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


;=============================================================================
boot3	CODE
;=============================================================================


;-----------------------------------------------------------------------------
; Entry Point for warm Start
;
; called on leaving sleep mode, surface menu, communication mode, and
; when a start of a dive is detected in all modes except surface mode
;
	global	restart
restart:

	; for safety purpose only
	banksel	common							; select bank common
	clrf	STKPTR							; clear return addresses stack
	call	request_speed_normal			; request CPU speed change to normal speed

	bsf		tft_is_dimming					; ignore ambient sensor

	; clear flag groups
	clrf	HW_descriptor					; hardware - OSTC model descriptor
	clrf	HW_flags_state1					; hardware - states
	;										; DO NOT clear HW_flags_state2 !
	;										; DO NOT clear HW_flags_state3 !
	clrf	DM_flags_sensor					; hardware - O2 sensors
	clrf	OS_flags_ISR1					; operating system - ISR control 1
	clrf	OS_flags_ISR2					; operating system - ISR control 2
	clrf	eventbase						; event triggers generated by ISR
	clrf	DM_flags_deco					; dive deco modes
	clrf	MS_flags_control				; menu system - control
	clrf	MS_flags_imprint				; menu system - data imprinting
	clrf	CVT_flags1						; control of numerical outputs 1
	clrf	CVT_flags2						; control of numerical outputs 2

	; configure the OSTC model descriptor (stored in HW_descriptor)
	bcf		tft_power						; inverted, here needed for I2C_probe_OSTC_rx, to wake-up RX circuity
	bsf		ambient_sensor					; set ambient light sensor as available by default
	bsf		ext_input_optical				; set optical input        as available by default

	call	lt2942_get_status				; check for gauge IC
	btfss	battery_gauge_available			; OSTC 2, cR or TR?
	bra		restart2						; NO

	; OSTC 2, cR or TR
	call	lt2942_init						; initialize battery gauge IC
	bcf		ext_input_optical				; OSTC 2, cR and TR do not have an optical input

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
    	btfsc	less_io_cpu						; Less I/O CPU found?
	bsf	ble_available						; Yes, must have BLE (old or new)
 IFNDEF _hwos_sport
	btfsc	vusb_in							; USB power detected?
	bra		restart3						; YES - no BT then
	bcf		PORTE,0							; NO  - power up BT chip (if available)
	WAITMS	d'5'							;     - wait 5 ms
	btfss	vusb_in							;     - BT chip detected?
	bra		restart3						;       NO  - no BT then
 ENDIF
	bsf		ble_available					;       YES - BT available

restart3:
   IFDEF _external_sensor						; Compiled for external analog interface?
    bsf	    ext_input_s8_ana					;       YES - Set the flag
    call    eeprom_serial_number_read	; read OSTC serial number
    movlw   .31
    cpfslt  hi				; bigger than WREG?
    bsf	    ble_available		; NO - must be new OSTC+ with interface
   ENDIF
   
   
   	bsf		lv_core							; default to low voltage core
	movlw	0x80							; point to 0x1F780
	movwf	TBLPTRL							; ...
	movlw	0xF7							; ...
	movwf	TBLPTRH							; ...
	movlw	0x01							; ...
	movwf	TBLPTRU							; ...
	TBLRD*+									; read from 0x1F780
	movlw	0x83							; coding for low voltage core, part 1
	cpfseq	TABLAT							; equal?
	bra		restart4a						; NO  - no low voltage core then
	movlw	0x81							; YES - point to  0x1F781
	movwf	TBLPTRL							;     - ...
	TBLRD*+									;     - read from 0x1F781
	movlw	0x94 							;     - coding for low voltage core, part 2
	cpfseq	TABLAT							;     - equal?
restart4a:
	bcf		lv_core							;       NO - no low voltage core then

	; OSTC sport 2019 hardware does not have an optical input
	btfsc	lv_core							; low voltage core?
	bcf		ext_input_optical				; YES - no optical input available
	btfsc	lv_core							; low voltage core?
	bcf		ext_input_s8_ana				; YES - can't be a cR, S8/analog sensor input disabled

	; check FLASH for block-write capability
	bsf		flash_block_write				; default to block-write capability available
	call	ext_flash_read_jedec			; read JEDEC IDs
	movlw	0x26							; device type 26h supports block-write
	cpfseq	hi								; dive type = 26h ?
	bcf		flash_block_write				; NO  - revoke capability


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
	WIN_TOP  .40							; set position
	WIN_LEFT .10							; ...
	TFT_WRITE_PROM_IMAGE_BY_ADDR hw_logo_block ; show heinrichsweikamp logo
	WIN_SMALL .10,.130						; set position
	STRCAT_PRINT "Updating TR Module..."	; print update message
	call	TFT_Display_FadeIn				; dimm up backlight to show outputs

	; update firmware in RX module
	call	I2C_sleep_compass				; stop compass
	call	update_tr_module				; update TR module

	WIN_SMALL .10,.160						; set next output position
	STRCAT	"Update "						; common part of result message
	btfss	ostc_rx_present					; data transfer successful and TR module up & running again?
	bra		restart4c						; NO
	STRCAT	"to "							; YES - print success message
	call	dyn_show_firmware_rx			;     - print installed version
	STRCAT_PRINT " done"					;     - complete result message
	bra		restart4d						;     - show message for a while

restart4c:
	STRCAT_PRINT "failed"					; complete result message - failure

restart4d:
	WAITS	.3								; wait 3 seconds

 ENDIF	; _rx_update

restart4e:
	btfss	ostc_rx_present					; TR module up & running?
	bra		restart5						; NO
	movff	opt_TR_mode,WREG				; YES - get TR mode
	tstfsz	WREG							;     - TR mode <> off ?
	bsf		tr_functions_activated			;       YES - set TR functions as activated

 ENDIF	; _rx_functions


restart5:
	; configure button_hold_down_allowed flag
	btfsc	lv_core
	bsf	button_hold_down_allowed		; OSTC sport mod. 2019
	btfsc	ext_input_optical
	bsf	button_hold_down_allowed		; OSTC3/old sport
	
	; manage hardware
	btfss	ext_input_s8_ana				; OSTC with S8/analog input?
	bsf		TRISB,3							; NO - shut down power supply for S8 bulkhead

	btfss	battery_gauge_available			; OSTC with gauge IC?
	bsf		TRISG,0							; NO

	call	ext_flash_disable_protection	; disable write protection for external flash

	btfsc	use_old_batt_flag				; shall reload last battery data?
	call	get_battery_data				; YES - get last battery data

	; check if option values have changed and thus if the EEPROM needs to be updated
	btfsc	option_changed					; do the options need to be stored to EEPROM ?
	call	option_check_and_store_all		; YES - check and store all option values in EEPROM

	; set screen orientation
	bcf		flip_screen						; disable upside-down orientation by default
	TSTOSC	opt_flip_screen					; shall show screen outputs upside down? (=1: flip the screen)
	bsf		flip_screen						; YES - enable upside-down orientation

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
	btfsc	ext_input_s8_ana					; analog sensor input available?
	bra	restart7						; Yes, continue
	; no sensors, reconfigure TRIS and ANSEL bits for AN8
	bcf	TRISF,3
	banksel	0xF16				; addresses F16h ... F5Fh are not part of the access RAM
	bcf	ANCON1,0			; ANSEL1: AN8 -> no analog input
	banksel	common				; back to bank common

restart7:    
	btfsc	divemode						; shall enter dive mode?
	goto	diveloop						; YES - enter dive mode
	btfsc	RCON,POR						; NO  - was this a power-on reset?
	goto	surfloop						;       NO  - enter surface mode
	bsf		RCON,POR						;       YES - acknowledge detection and re-arm detector
	goto	new_battery_select				;           - prompt for battery selection, will proceed to surface mode


;=============================================================================
boot4	CODE
;=============================================================================

;-----------------------------------------------------------------------------
; Setup of all Flags and Parameters for Dive Mode and Simulator Computations
;
; called from divemode.asm, menu_tree.asm and surfmode.asm
;
	global	restart_set_modes_and_flags
restart_set_modes_and_flags:
	call	disable_ir_s8_analog			; switch off IR/S8/analog interface by default (for all compile versions!)

 IFDEF _external_sensor
	WAITMS	d'100'							; wait 100 ms to S8-HUD powered down properly
 ENDIF

	; setup sampling rate for dice data recording
	movlw	.2								; default to 2 seconds
	TSTOSC	opt_sampling_rate				; check option: 0= 2s, 1= 10s
	movlw	.10								; 1 - change to 10 seconds
	movwf	sampling_rate					; store selection

	; clear all deco mode flags
	clrf	DM_flags_deco

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
	TSTOSC	char_I_model												; get deco model ZH-L16-GF (1) selected?
	bra		restart_set_modes_and_flags2								; YES - keep them
	movff	opt_sat_multiplier_non_gf,  char_I_saturation_multiplier	; NO  - overwrite them with non-GF factors
	movff	opt_desat_multiplier_non_gf,char_I_desaturation_multiplier	;     - ...

restart_set_modes_and_flags2:

	; configure GF settings, GF high is needed for color-coding the current GF (supersaturation) factor
	movff	opt_GF_low, char_I_GF_Low_percentage
	movff	opt_GF_high,char_I_GF_High_percentage

	; dive mode specific setup
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
	call	enable_ir_s8_analog				;     - enable IR/S8/analog interface
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
	movlw	samplingrate_apnoe				;     - get apnoe sampling rate
	movwf	sampling_rate					;     - overwrite user-selected 2/10 seconds setting with apnoe default
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
	call	enable_ir_s8_analog				;     - enable IR/S8/analog interface
 ENDIF	; _external_sensor
 ENDIF	; _ccr_pscr
	return									;     - done

;-----------------------------------------------------------------------------

	END
