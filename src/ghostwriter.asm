;=============================================================================
;
;   File ghostwriter.asm                      combined next generation V3.03.1
;
;   Ghostwriter (Log profile recorder)
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;  2011-11-27 : [mH] Creation

#include "hwos.inc"						; Mandatory header
#include "shared_definitions.h"			; Mailbox from/to p2_deco.c
#include "external_flash.inc"
#include "surfmode.inc"
#include "eeprom_rs232.inc"
#include "strings.inc"
#include "tft_outputs.inc"
#include "divemode.inc"
#include "rtc.inc"


	extern	deco_pull_tissues_from_vault


	; private local Variables

	CBLOCK	local3						; max size is 16 Byte !!!
		divisor_temperature				; divisor used to time the sampling of dive data
		divisor_deco					; divisor used to time the sampling of dive data
		divisor_supersat				; divisor used to time the sampling of dive data
		divisor_ppo2_sensors			; divisor used to time the sampling of dive data
		divisor_decoplan				; divisor used to time the sampling of dive data
		divisor_cns						; divisor used to time the sampling of dive data
		divisor_tank					; divisor used to time the sampling of dive data
		ProfileFlagByte					; used to store events
	ENDC								; used: 8 byte, remaining: 8 byte


ghostwriter	CODE

;=============================================================================


	global	init_recording_params		; initialize profile recording parameters
init_recording_params:
	movlw	div_temperature				; get divisor for temperature storage
	movwf	divisor_temperature			; initialize divisor

	movlw	div_deco					; ...
	movwf	divisor_deco				; ...

	movlw	div_gf
	movwf	divisor_supersat

	movlw	div_decoplan
	movwf	divisor_decoplan

	movlw	div_cns
	movwf	divisor_cns

	movlw	div_tank
	movwf	divisor_tank

 IFDEF _external_sensor
	movlw	div_ppo2_sensors
	movwf	divisor_ppo2_sensors

	btfsc	FLAG_ccr_mode				; in CCR mode?
	bra		init_recording_params_2		; YES
	btfsc	FLAG_pscr_mode				; in pSCR mode?
	bra		init_recording_params_2		; YES
	; in all modes but CCR and pSCR, disable ppO2 logging
	movlw	.0
	movwf	divisor_ppo2_sensors
 ENDIF

init_recording_params_2:
	return


	global	store_dive_data
store_dive_data:
	bcf		trigger_sample_divedata		; clear flag

 ifndef _DEBUG
	btfsc	sensor_override_active		; in simulator mode?
	return								; YES - no dive data stored in simulator mode
 endif

	btfss	FLAG_apnoe_mode				; in apnoe mode?
	bra		store_dive_data_1			; NO  - proceed
	TSTOSS	opt_store_apnoe_dive		; YES - logging in apnoe mode enabled?
	return								;       NO  - done

store_dive_data_1:
; Store depth with every sample
	movf	pressure_rel_cur_cached+0,W	; get depth (relative pressure), low  byte
	rcall	ghostwrite_byte_profile		; store to profile in ext. flash
	movf	pressure_rel_cur_cached+1,W	; get depth (relative pressure), high byte
	rcall	ghostwrite_byte_profile		; store to profile in ext. flash

; First, find out how many bytes will be appended to this sample set
	clrf	ProfileFlagByte				; clear number of bytes to append

; Check Extended Information
	decfsz	divisor_temperature,W		; check divisor if it will become 0, dump decremented value to WREG
	bra		check_extended1				; NO  - skip
	movlw	infolength_temperature		; YES - get length of extra data
	addwf	ProfileFlagByte,F			;     - add to ProfileFlagByte
check_extended1:
	decfsz	divisor_deco,W				; check divisor if it will become 0, dump decremented value to WREG
	bra		check_extended2				; NO  - skip
	movlw	infolength_deco				; YES - get length of extra data
	addwf	ProfileFlagByte,F			;     - add to ProfileFlagByte
check_extended2:
	decfsz	divisor_supersat,W			; check divisor if it will become 0, dump decremented value to WREG
	bra		check_extended3				; NO  - skip
	movlw	infolength_gf				; YES - get length of extra data
	addwf	ProfileFlagByte,F			; add to ProfileFlagByte
check_extended3:
 IFDEF _external_sensor
	decfsz	divisor_ppo2_sensors,W		; check divisor if it will become 0, dump decremented value to WREG
	bra		check_extended4				; NO  - skip
	movlw	infolength_ppo2_sensors		; YES - get length of extra data
	addwf	ProfileFlagByte,F			;     - add to ProfileFlagByte
 ENDIF
check_extended4:
	decfsz	divisor_decoplan,W			; check divisor if it will become 0, dump decremented value to WREG
	bra		check_extended5				; NO  - skip
	movlw	infolength_decoplan			; YES - get length of extra data
	addwf	ProfileFlagByte,F			;     - add to ProfileFlagByte
check_extended5:
	decfsz	divisor_cns,W				; check divisor if it will become 0, dump decremented value to WREG
	bra		check_extended6				; NO  - skip
	movlw	infolength_cns				; YES - get length of extra data
	addwf	ProfileFlagByte,F			;     - add to ProfileFlagByte
check_extended6:
	decfsz	divisor_tank,W				; check divisor if it will become 0, dump decremented value to WREG
	bra		check_extended7				; NO  - skip
	movlw	infolength_tank				; YES - get length of extra data
	addwf	ProfileFlagByte,F			;     - add to ProfileFlagByte
check_extended7:

; Second, check global event flag
	btfss	event_occured				; check global event flag
	bra		store_dive_data3			; no event

	incf	ProfileFlagByte,F			; add one byte (the event byte 1)

	clrf	event_byte1					; reset event byte 1
	clrf	event_byte2					; reset event byte 2

	movf	alarm_type,W				; type of alarm Bit 0-3
	addwf	event_byte1,F				; copy to event byte 1, bit 0-3
	clrf	alarm_type					; reset alarm type

; Third, check events and add additional bytes
	btfss	event_gas_change_gas6		; did a change to gas 6 occur?
	bra		check_event2				; NO
	movlw	d'2'						; YES - set information length
	addwf	ProfileFlagByte,F			;     - add to ProfileFlagByte
	bsf		event_byte1,4				;     - set flag in event byte 1
check_event2:
	btfss	event_gas_change			; did a gas change occur?
	bra		check_event3				; NO
	movlw	d'1'						; YES - set information length
	addwf	ProfileFlagByte,F			;     - add to ProfileFlagByte
	bsf		event_byte1,5				;     - set flag in event byte 1
check_event3:
 IFDEF _ccr_pscr
	btfss	event_SP_change				; did a setpoint change occur?
	bra		check_event4				; NO
	movlw	d'1'						; YES - set information length
	addwf	ProfileFlagByte,F			;     - add to ProfileFlagByte
	bsf		event_byte1,6				;     - set flag in event byte 1
 ENDIF
check_event4:
 IFDEF _ccr_pscr
	btfss	event_bailout				; did a gas change due to bailout occur?
	bra		check_event5
	movlw	d'2'						; information length
	addwf	ProfileFlagByte,F			; add to ProfileFlagByte
	bsf		event_byte2,0				; set flag in event byte 2
	bsf		event_byte1,7				; =1: another event byte is available
 ENDIF

check_event5:
	; more events?

store_dive_data3:
	btfsc	event_byte1,7				; =1: another event byte is available
	incf	ProfileFlagByte,F			; add one byte (the event byte 2)

	btfsc	event_occured				; check global event flag
	bsf		ProfileFlagByte,7			; set event byte 1 flag in ProfileFlagByte

	movf	ProfileFlagByte,W			; finally, write ProfileFlagByte
	rcall	ghostwrite_byte_profile		; WREG -> profile in ext. flash

	btfss	event_occured				; check global event flag (again)
	bra		store_dive_data4			; no event

; Store the EventByte(s) + additional bytes now
	movf	event_byte1,W
	rcall	ghostwrite_byte_profile		; WREG -> profile in ext. flash
	movf	event_byte2,W				; write second event byte...
	btfsc	event_byte1,7				; =1: another event byte is available
	rcall	ghostwrite_byte_profile		; store that information

	btfss	event_gas_change_gas6		; did a change to gas 6 occur?
	bra		store_dive_data3b			; NO
	movff	char_I_O2_ratio,WREG		; YES - get gas 6 O2 ratio
	rcall	ghostwrite_byte_profile		;     - store it
 IFDEF _helium
	movff	char_I_He_ratio,WREG		;     - get gas 6 He ratio
 ELSE
	clrf	WREG						;     - He ratio is zero
 ENDIF
	rcall	ghostwrite_byte_profile		;     - store it
	bcf		event_gas_change_gas6		;     - clear event flag
store_dive_data3b:
	btfss	event_gas_change			; did a gas change occur?
	bra		store_dive_data3c			; NO
 IFDEF _ccr_pscr
	movf	active_dil,W				; YES - store active diluent (default, may be overwritten soon)
	btfsc	FLAG_oc_mode				;     - in OC mode?
	movf	active_gas,W				;       YES - get active gas
	btfsc	bailout_mode				;     - in bailout?
 ENDIF
	movf	active_gas,W				;       YES - get active OC = bailout gas
	rcall	ghostwrite_byte_profile		;     - store it
	bcf		event_gas_change			;     - clear event flag
store_dive_data3c:
 IFDEF _ccr_pscr
	btfss	event_SP_change				; did a setpoint change occur?
	bra		store_dive_data3d			; NO
	movff	char_I_const_ppO2,WREG		; YES - get setpoint
	rcall	ghostwrite_byte_profile		;     - store it
	bcf		event_SP_change				;     - clear event flag
 ENDIF
store_dive_data3d:
 IFDEF _ccr_pscr
	btfss	event_bailout				; did a gas change due to bailout occur?
	bra		store_dive_data4			; NO
	movff	char_I_O2_ratio,WREG		; YES - get O2 ratio of bailout gas
	rcall	ghostwrite_byte_profile		;     - store it
 IFDEF _helium
	movff	char_I_He_ratio,WREG		;     - get He ratio of bailout gas
 ELSE
	clrf	WREG						;     - He ratio is zero
 ENDIF
	rcall	ghostwrite_byte_profile		;     - store it
	bcf		event_bailout				;     - clear event flag
 ENDIF	; _ccr_pscr
store_dive_data4:
; Store extended information
	decfsz	divisor_temperature,F		; time to store a temperature sample ?
	bra		store_extended1				; NO  - skip
	rcall	store_dive_temperature		; YES - store data
store_extended1:
	decfsz	divisor_deco,F				; time to store the current deco data?
	bra		store_extended2				; NO  - skip
	rcall	store_dive_decodata			; YES - store data
store_extended2:
	decfsz	divisor_supersat,F			; time to store the current supersaturation ?
	bra		store_extended3				; NO  - skip
	rcall	store_dive_supersat			; YES - store data
store_extended3:
 IFDEF _external_sensor
	decfsz	divisor_ppo2_sensors,F		; decrement divisor, did it became 0 ?
	bra		store_extended4				; NO  - skip
	rcall	store_dive_ppO2_sensors		; YES - store data
 ENDIF
store_extended4:
	decfsz	divisor_decoplan,F			; decrement divisor, did it became 0 ?
	bra		store_extended5				; NO  - skip
	rcall	store_dive_decoplan			; YES - store data
store_extended5:
	decfsz	divisor_cns,F				; decrement divisor, did it became 0 ?
	bra		store_extended6				; NO  - skip
	rcall	store_dive_cns				; YES - store data
store_extended6:
	decfsz	divisor_tank,F				; decrement divisor, did it became 0 ?
	bra		store_extended7				; NO  - skip
	rcall	store_dive_tank				; YES - store data
store_extended7:

; The next block is required to take care of "store never"
	btfsc	divisor_temperature,7		; test highest bit (register must have been zero before the "decfsz" command!)
	clrf	divisor_temperature			; and clear register again, so it will never reach zero...

	btfsc	divisor_deco,7
	clrf	divisor_deco

	btfsc	divisor_supersat,7
	clrf	divisor_supersat

 IFDEF _external_sensor
	btfsc	divisor_ppo2_sensors,7
	clrf	divisor_ppo2_sensors
 ENDIF

	btfsc	divisor_decoplan,7
	clrf	divisor_decoplan

	btfsc	divisor_cns,7
	clrf	divisor_cns

	btfsc	divisor_tank,7
	clrf	divisor_tank

store_dive_data5:
	bcf		event_occured				; clear the global event flag
	clrf	event_byte1					; reset event byte 1
	clrf	event_byte2					; reset event byte 2
	return								; done (sample with all informations written to external flash)

store_dive_cns:
	movff	int_O_CNS_current+0,WREG	; get current CNS, low  byte
	rcall	ghostwrite_byte_profile		; store it
	movff	int_O_CNS_current+1,WREG	; get current CNS, high byte
	bcf		WREG,int_warning_flag		; clear warning   flag
	bcf		WREG,int_attention_flag		; clear attention flag
	rcall	ghostwrite_byte_profile		; store it
	movlw	div_cns
	movwf	divisor_cns					; reload divisor from CF
	return

store_dive_tank:
	; OSTC TR tank pressure logging
	movlw	div_tank
	movwf	divisor_tank				; reload divisor from CF
	return

store_dive_decoplan:
	; Store the deco plan
	lfsr	FSR1,char_O_deco_time_for_log	; load base address of deco stop times table
	movlw	NUM_STOPS_LOG					; load size         of deco stop times table
	movwf	lo								; copy size to loop counter
store_dive_decoplan_loop:
	movf	POSTINC1,W						; get a stop time
	rcall	ghostwrite_byte_profile			; store it
	decfsz	lo,F							; decrement loop counter, became zero?
	bra		store_dive_decoplan_loop		; NO  - loop
	movlw	div_decoplan					; YES - get divisor for deco plan recording
	movwf	divisor_decoplan				;     - reload timer
	return									;     - done

;=============================================================================

 IFDEF _external_sensor

store_dive_ppO2_sensors:
	movff	sensor1_ppO2,WREG				; get sensor 1 ppO2 (in 0.01 bar steps)
	rcall	ghostwrite_byte_profile			; store it
	SMOVII	sensor1_mv,mpr					; ISR-safe 2 byte copy of o2_mv_sensor to hi:lo
	movf	lo,W							; in 0.1 mV steps, low  byte
	rcall	ghostwrite_byte_profile			; store it
	movf	hi,W							; in 0.1 mV steps, high byte
	rcall	ghostwrite_byte_profile			; store it

	movff	sensor2_ppO2,WREG				; get sensor 2 ppO2 (in 0.01 bar steps)
	rcall	ghostwrite_byte_profile			; store it
	SMOVII	sensor2_mv,mpr					; ISR-safe 2 byte copy of o2_mv_sensor to hi:lo
	movf	lo,W							; in 0.1 mV steps, low  byte
	rcall	ghostwrite_byte_profile			; store it
	movf	hi,W							; in 0.1 mV steps, high byte
	rcall	ghostwrite_byte_profile			; store it

	movff	sensor3_ppO2,WREG				; get sensor 3 ppO2 (in 0.01 bar steps)
	rcall	ghostwrite_byte_profile			; store it
	SMOVII	sensor3_mv,mpr					; ISR-safe 2 byte copy of o2_mv_sensor to hi:lo
	movf	lo,W							; in 0.1 mV steps, low  byte
	rcall	ghostwrite_byte_profile			; store it
	movf	hi,W							; in 0.1 mV steps, high byte
	rcall	ghostwrite_byte_profile			; store it

	movlw	div_ppo2_sensors
	movwf	divisor_ppo2_sensors			; reload timer
	return

 ENDIF

;=============================================================================

store_dive_supersat:
	movff	int_O_lead_supersat+0,WREG		; get leading tissue's supersaturation (value is limited to 255, only lower byte is used for the value)
	rcall	ghostwrite_byte_profile			; store it
	movlw	div_gf
	movwf	divisor_supersat				; reload timer
	return

store_dive_decodata:
	; Check if deco stops are necessary
	movff	char_O_deco_depth,WREG			; get depth of the first stop
	tstfsz	WREG							; depth of first stop > 0 m (aka in deco) ?
	bra		store_dive_decodata_deco		; YES
	; NO - within NDL
	clrf	WREG							; =0: no stop dive
	rcall	ghostwrite_byte_profile			; store it
	movff	char_O_NDL_norm,WREG			; get NDL time in normal plan
	rcall	ghostwrite_byte_profile			; store it
	bra		store_dive_decodata_common
store_dive_decodata_deco:
	; YES - in deco
	movff	char_O_deco_depth,WREG			; get depth of the first stop in meters
	rcall	ghostwrite_byte_profile			; store it
	movff	char_O_deco_time,WREG			; get time of the first stop in minutes
	rcall	ghostwrite_byte_profile			; store it
store_dive_decodata_common:
	movlw	div_deco
	movwf	divisor_deco					; reload timer
	return

store_dive_temperature:
	SMOVII	temperature_cur,mpr				; ISR-safe 2 byte copy of current temperature to hi:lo
	movf	lo,W							; get low  byte
	rcall	ghostwrite_byte_profile			; store it
	movf	hi,W							; get high byte
	rcall	ghostwrite_byte_profile			; store it
	movlw	div_temperature
	movwf	divisor_temperature				; reload timer
	return

ghostwrite_byte_header:
	goto	write_byte_ext_flash_plus_header ; (this call will also delete the 4kB TOC entry first)
	; returns...

ghostwrite_byte_profile:
	goto	write_byte_ext_flash_plus		; writes byte and increases address with banking at 0x200000
	; returns...


	global	ghostwriter_end_dive
ghostwriter_end_dive:
	; save end-of-profile pointer to store in header
	movff	ext_flash_address+0,ext_flash_log_pointer+0
	movff	ext_flash_address+1,ext_flash_log_pointer+1
	movff	ext_flash_address+2,ext_flash_log_pointer+2

	; remember last custom view shown in dive mode
	movff	active_customview,customview_divemode

	btfss	divetime_longer_1min			; dive longer then one minute
	goto	ghostwriter_end_dive_common		; NO - discard everything

; In DEBUG compile, write simulated dives to logbook
 ifndef _DEBUG
	btfsc	sensor_override_active			; are we in simulator mode?
	goto	ghostwriter_end_dive_common		; YES - discard everything
 endif

	btfss	FLAG_apnoe_mode					; are we in apnoe mode?
	bra		ghostwriter_end_dive_1			; NO  - proceed
	TSTOSS	opt_store_apnoe_dive			; YES - logging in apnoe mode enabled?
	goto	ghostwriter_end_dive_common		;       NO  - discard everything

ghostwriter_end_dive_1:
	; Dive finished (and longer than one minute)

	btfsc	FLAG_apnoe_mode					; are we in apnoe mode?
	call	apnoe_calc_maxdepth				; YES - calculate max. depth (again) for very short apnoe dives

	movlw	0xFD							; coding for End-of-Profile, byte 1
	rcall	ghostwrite_byte_profile			; store it
	movlw	0xFD							; coding for End-of-Profile, byte 2
	rcall	ghostwrite_byte_profile			; store it

	; Save end-of-profile pointer to store in header
	movff	ext_flash_address+0,ext_flash_log_pointer+0
	movff	ext_flash_address+1,ext_flash_log_pointer+1
	movff	ext_flash_address+2,ext_flash_log_pointer+2

	; Set to first address again to store dive length ext_flash_dive_counter:3
	rcall	ghostwriter_load_pointer		; load ext_flash_address:3 from EEPROM .4-.6

	incf_ext_flash_address_0x20 d'6'		; skip internal "0xFA 0xFA #Divenumber:2 0xFA 0xFA" Header
	; Store dive length
	movf	ext_flash_dive_counter+0,W
	call	write_byte_ext_flash_plus_nodel	; WREG -> profile in ext. flash (No ext_flash_dive_counter:3 increase) and does NOT delete 4kB page
	movf	ext_flash_dive_counter+1,W
	call	write_byte_ext_flash_plus_nodel	; WREG -> profile in ext. flash (No ext_flash_dive_counter:3 increase) and does NOT delete 4kB page
	movf	ext_flash_dive_counter+2,W
	call	write_byte_ext_flash_plus_nodel	; WREG -> profile in ext. flash (No ext_flash_dive_counter:3 increase) and does NOT delete 4kB page

; profile recording done

	; Load total number of dives
	read_int_eeprom .2
	movff	EEDATA,lo
	read_int_eeprom .3
	movff	EEDATA,hi

	INCI	mpr								; increase total dive counter

	; Store new number in EEPROM
	movff	lo,EEDATA
	write_int_eeprom .2
	movff	hi,EEDATA
	write_int_eeprom .3

	decf	lo,F							; -1

	; Set ext_flash_address:3 to TOC entry of this dive
	; 1st: 200000h-200FFFh -> lo=0
	; 2nd: 201000h-201FFFh -> lo=1
	; 3rd: 202000h-202FFFh -> lo=2
	; 255: 2FF000h-2FFFFFh -> lo=255

	clrf	ext_flash_address+0
	clrf	ext_flash_address+1
	movlw	0x20
	movwf	ext_flash_address+2
	movlw	.16
	mulwf	lo								; lo*16 = offset to 0x2000 (up:hi)
	movf	PRODL,W
	addwf	ext_flash_address+1,F
	movf	PRODH,W
	addwfc	ext_flash_address+2,F

	; write header start code
	movlw	0xFA							; header start
	rcall	ghostwrite_byte_header			; (this call will also delete the 4kB TOC entry first)
	movlw	0xFA
	rcall	ghostwrite_byte_header			; WREG -> header in ext. flash

	; store pointer to begin of dive profile
	read_int_eeprom .4
	movf	EEDATA,W
	rcall	ghostwrite_byte_header			; WREG -> header in ext. flash
	read_int_eeprom .5
	movf	EEDATA,W
	rcall	ghostwrite_byte_header			; WREG -> header in ext. flash
	read_int_eeprom .6
	movf	EEDATA,W
	rcall	ghostwrite_byte_header			; WREG -> header in ext. flash

	; store pointer to end of dive profile
	movf	ext_flash_log_pointer+0,W
	rcall	ghostwrite_byte_header			; WREG -> header in ext. flash
	movf	ext_flash_log_pointer+1,W
	rcall	ghostwrite_byte_header			; WREG -> header in ext. flash
	movf	ext_flash_log_pointer+2,W
	rcall	ghostwrite_byte_header			; WREG -> header in ext. flash

	; write the remainder of the header
	movlw	logbook_profile_version			; defined in hwos.inc
	rcall	ghostwrite_byte_header			; WREG -> header in ext. flash

	; store dive length
	movf	ext_flash_dive_counter+0,W
	rcall	ghostwrite_byte_header			; WREG -> header in ext. flash
	movf	ext_flash_dive_counter+1,W
	rcall	ghostwrite_byte_header			; WREG -> header in ext. flash
	movf	ext_flash_dive_counter+2,W
	rcall	ghostwrite_byte_header			; WREG -> header in ext. flash

	; store start of time time & date
	lfsr	FSR0,start_year					; load base address of start-of-dive data
	movf	POSTINC0,W						; year
	rcall	ghostwrite_byte_header			; WREG -> header in ext. flash
	movf	POSTINC0,W						; month
	rcall	ghostwrite_byte_header			; WREG -> header in ext. flash
	movf	POSTINC0,W						; day
	rcall	ghostwrite_byte_header			; WREG -> header in ext. flash
	movf	POSTINC0,W						; hour
	rcall	ghostwrite_byte_header			; WREG -> header in ext. flash
	movf	POSTINC0,W						; minute
	rcall	ghostwrite_byte_header			; WREG -> header in ext. flash

	btfss	FLAG_apnoe_mode					; store apnoe max or normal max (which is only max from the last descent)
	bra		end_dive1						; store normal depth

	; apnoe max depth
	MOVII	apnoe_max_pressure,mpr
	call	adjust_depth_with_salinity		; compute salinity setting into hi:lo [mbar]
	MOVII	mpr,apnoe_max_pressure
	bra		end_dive2						; store max depth

end_dive1:
	; normal max depth
	MOVII	pressure_rel_max_cached,mpr
	call	adjust_depth_with_salinity		; compute salinity setting into hi:lo [mbar]
	MOVII	mpr,pressure_rel_max_cached

end_dive2:
	; store max depth (common part)
	movf	lo,W							; max. depth, low  byte
	rcall	ghostwrite_byte_header			; WREG -> header in ext. flash
	movf	hi,W							; max. depth, high byte
	rcall	ghostwrite_byte_header			; WREG -> header in ext. flash

	; store dive time
	SMOVTT	counted_divetime_mins,mpr		; ISR-safe 3 byte copy of minutes:2 and seconds
	movf	mpr+0,W							; dive time minutes, low  byte
	rcall	ghostwrite_byte_header			; WREG -> header in ext. flash
	movf	mpr+1,W							; dive time minutes, high byte
	rcall	ghostwrite_byte_header			; WREG -> header in ext. flash
	movf	mpr+2,W							; dive time seconds
	rcall	ghostwrite_byte_header			; WREG -> header in ext. flash

	; store minimum temperature
	movff	temperature_min+0,WREG			; minimum temperature, low  byte
	rcall	ghostwrite_byte_header			; WREG -> header in ext. flash
	movff	temperature_min+1,WREG			; minimum temperature, high byte
	rcall	ghostwrite_byte_header			; WREG -> header in ext. flash

	; store surface pressure (as used by deco engine)
	movff	int_I_pres_surface+0,WREG		; surface pressure, low  byte
	rcall	ghostwrite_byte_header			; WREG -> header in ext. flash
	movff	int_I_pres_surface+1,WREG		; surface pressure, high byte
	rcall	ghostwrite_byte_header			; WREG -> header in ext. flash

	; store desaturation time
	movff	int_O_desaturation_time+0,WREG	; desaturation time in minutes, low  byte
	rcall	ghostwrite_byte_header			; WREG -> header in ext. flash
	movff	int_O_desaturation_time+1,WREG	; desaturation time in minutes, high byte
	rcall	ghostwrite_byte_header			; WREG -> header in ext. flash

 IFDEF _ccr_pscr
	btfsc	FLAG_ccr_mode					; in CCR mode?
	bra		end_dive_dil_gaslist			; YES - write diluent gas list
	btfsc	FLAG_pscr_mode					; in pSCR mode?
	bra		end_dive_dil_gaslist			; YES - write diluent gas list
 ENDIF

end_dive_oc_gaslist:						; write OC gases
	lfsr	FSR0,opt_gas_O2_ratio-.1		; set base address to (opt_gas_O2_ratio - 1) because of pre-increment statement
	bra		end_dive_gaslist				; write all 5 OC gases

 IFDEF _ccr_pscr
end_dive_dil_gaslist:						; write diluents
	lfsr	FSR0,opt_dil_O2_ratio-.1		; set base address to (opt_dil_O2_ratio - 1) because of pre-increment statement
	;bra	end_dive_gaslist				; write all 5 diluents
 ENDIF

end_dive_gaslist:							; helper function for writing gas list entries
;
;   Memory Map:
;   -------------------------
;   opt_gas_O2_ratio	res 5
;   opt_dil_O2_ratio	res 5
;   opt_gas_He_ratio	res 5
;   opt_dil_He_ratio	res 5
;   opt_gas_type		res 5
;   opt_dil_type		res 5
;   opt_gas_change		res 5
;   opt_dil_change		res 5
;
	movlw	.5								; 5 gases to store
	movwf	lo								; use lo as counter
end_dive_gaslist_loop:
	movf	PREINC0,W						; increment base address and get O2 ratio into WREG
	rcall	ghostwrite_byte_header			; store data
	movlw	.10								; offset for H2 ratios
	movf	PLUSW0,W						; get H2 ratio into WREG
	rcall	ghostwrite_byte_header			; store data
	movlw	.30								; offset for change depths
	movf	PLUSW0,W						; get change depth into WREG
	rcall	ghostwrite_byte_header			; store data
	movlw	.20								; offset for types
	movf	PLUSW0,W						; get type into WREG
	rcall	ghostwrite_byte_header			; store data
	decfsz	lo								; decrement counter, did it became 0 ?
	bra		end_dive_gaslist_loop			; NO  - loop
	;bra	end_dive_oc_cc_common			; YES - done

end_dive_oc_cc_common:
	movlw	softwareversion_x				; get firmware version X (major)
	rcall	ghostwrite_byte_header			; store data
	movlw	softwareversion_y				; get firmware version Y (minor)
	rcall	ghostwrite_byte_header			; store data

	; store battery voltage
	movf	batt_voltage+0,W				; get battery voltage, low  byte
	rcall	ghostwrite_byte_header			; store data
	movf	batt_voltage+1,W				; get battery voltage, high byte
	rcall	ghostwrite_byte_header			; store data

	; store sampling rate
	movf	sampling_rate,W					; get sampling rate
	rcall	ghostwrite_byte_header			; store data

	; store CNS at beginning of dive
	movf	CNS_start+0,W					; get CNS at start of dive, low  byte
	rcall	ghostwrite_byte_header			; store data
	movf	CNS_start+1,W					; get CNS at start of dive, high byte
	rcall	ghostwrite_byte_header			; store data

	; store gradient factors
	movff	supersat_start,WREG				; get supersaturation at start of dive
	rcall	ghostwrite_byte_header			; store data
	movff	int_O_lead_supersat+0,WREG		; get supersaturation at end   of dive
	rcall	ghostwrite_byte_header			; store data

	; store logbook offset
	call	do_logoffset_common_read		; read into mpr:2
	movf	mpr+0,W
	rcall	ghostwrite_byte_header			; store data
	movf	mpr+1,W
	rcall	ghostwrite_byte_header			; store data

	; store battery info at Byte 59
	movf	batt_percent,W					; 0-100%
	rcall	ghostwrite_byte_header			; store data

	; store setpoints
 IFDEF _ccr_pscr
	lfsr	FSR0,opt_setpoint_cbar			; base address of ppO2 values
	lfsr	FSR1,opt_setpoint_change		; base address of change depths
 ENDIF
	movlw	.5								; 5 setpoints to be stored
	movwf	lo								; use lo as counter
end_dive_sp_loop:
 IFDEF _ccr_pscr
	movf	POSTINC0,W						; get ppO2 value
 ELSE
	clrf	WREG
 ENDIF
	rcall	ghostwrite_byte_header			; store data
 IFDEF _ccr_pscr
	movf	POSTINC1,W						; get change depth
 ELSE
	clrf	WREG
 ENDIF
	rcall	ghostwrite_byte_header			; store data
	decfsz	lo								; decrement counter, did it became 0 ?
	bra		end_dive_sp_loop				; NO  - loop

	; store salinity
	movff	opt_salinity,WREG				; get salinity (0-4%)
	rcall	ghostwrite_byte_header			; store data

	; store CNS at end of dive
	movff	int_O_CNS_current+0,WREG		; get current CNS, low  byte
	rcall	ghostwrite_byte_header			; store data
	movff	int_O_CNS_current+1,WREG		; get current CNS, high byte
	bcf		WREG,int_warning_flag			; clear warning   flag
	bcf		WREG,int_attention_flag			; clear attention flag
	rcall	ghostwrite_byte_header			; store data

	; store average depth
	movff	pressure_rel_avg_total+0,WREG	; get total dive average depth, low  byte
	rcall	ghostwrite_byte_header			; store data
	movff	pressure_rel_avg_total+1,WREG	; get total dive average depth, high byte
	rcall	ghostwrite_byte_header			; store data

	; store total dive time
	SMOVII	total_divetime_secs,mpr			; ISR-safe 2 byte copy of the total dive time
	movff	mpr+0,WREG						; total dive time, low  byte
	rcall	ghostwrite_byte_header			; store data
	movff	mpr+1,WREG						; total dive time, high byte
	rcall	ghostwrite_byte_header			; store data

	; store GF low or saturation multiplier
	movff	char_I_GF_Low_percentage,WREG	; get GF_lo
	movff	char_I_deco_model,lo
	decfsz	lo,F							; skip next line if char_I_deco_model == 1
	movff	char_I_saturation_multiplier,WREG ; get saturation multiplier
	rcall	ghostwrite_byte_header			; store data

	; store GF high or desaturation multiplier
	movff	char_I_GF_High_percentage,WREG	; get GF_hi
	movff	char_I_deco_model,lo
	decfsz	lo,F							; jump over next line if char_I_deco_model == 1
	movff	char_I_desaturation_multiplier,WREG ; get desaturation multiplier
	rcall	ghostwrite_byte_header			; store data

	; store deco model
	movff	char_I_deco_model,WREG			; get deco model (0 = ZH-L16, 1 = ZH-L16-GF)
	rcall	ghostwrite_byte_header			; store data

	; store total dive number
	read_int_eeprom .2						; get total dive counter, low
	movf	EEDATA,W						; ...
	rcall	ghostwrite_byte_header			; store data
	read_int_eeprom .3						; get total dive counter, high
	movf	EEDATA,W						; ...
	rcall	ghostwrite_byte_header			; store data

	; store deco mode
	movff	opt_dive_mode,WREG				; get deco mode (0=OC, 1=CC, 2=Gauge, 3=Apnea, 4=PSCR)
	rcall	ghostwrite_byte_header			; store data

	; store tissue data - N2 chars
	movlw	.16
	movwf	lo
	lfsr	FSR1,char_O_tissue_pres_N2
end_dive_store_tissues_N2:
	movf	POSTINC1,W
	bcf		WREG,7							; clear flag bit for on-gassing/off-gassing
	rcall	ghostwrite_byte_header			; store data
	decfsz	lo,F
	bra		end_dive_store_tissues_N2		; NO

	; store tissue data - N2 floats
	movlw	.64
	movwf	lo
	lfsr	FSR1,0x700						; pres_tissue_N2+0 ; 16*4 Byte Float = 64 Bytes
end_dive_store_tissues_N2_2:
	movf	POSTINC1,W
	rcall	ghostwrite_byte_header			; store data
	decfsz	lo,F
	bra		end_dive_store_tissues_N2_2		; NO

	; store tissue data - He chars
	movlw	.16
	movwf	lo
	lfsr	FSR1,char_O_tissue_pres_He
end_dive_store_tissues_He:
	movf	POSTINC1,W
	bcf		WREG,7							; clear flag bit for on-gassing/off-gassing
	rcall	ghostwrite_byte_header			; store data
	decfsz	lo,F
	bra		end_dive_store_tissues_He		; NO

	; store tissue data - He floats
	movlw	.64
	movwf	lo
	lfsr	FSR1,0x740						; pres_tissue_He+0 ; 16*4 Byte Float = 64 Bytes
end_dive_store_tissues_He_2:
	movf	POSTINC1,W
	rcall	ghostwrite_byte_header 			; store data
	decfsz	lo,F
	bra		end_dive_store_tissues_He_2		; NO

	; store last stop depth
	movff	char_I_depth_last_deco,WREG		; get last stop depth [m]
	rcall	ghostwrite_byte_header			; store data

	; store deco distance
	movff	char_I_deco_distance,WREG		; get assumed distance to shown stop
	rcall	ghostwrite_byte_header			; store data

 IFDEF _external_sensor
	; store last HUD data
	SMOVTT	hud_status_byte,mpr				; ISR-safe 3 byte copy of last HUD status (1 byte) and battery voltage (2 byte)
	movff	mpr+1,WREG						; HUD battery value, low  byte
	rcall	ghostwrite_byte_header			; store data
	movff	mpr+2,WREG						; HUD battery value, high byte
	rcall	ghostwrite_byte_header			; store data
	movff	mpr+0,WREG						; HUD status
	rcall	ghostwrite_byte_header			; store data
 ELSE
	; store dummy data to keep format
	clrf	WREG
	rcall	ghostwrite_byte_header			; store null byte
	clrf	WREG
	rcall	ghostwrite_byte_header			; store null byte
	clrf	WREG
	rcall	ghostwrite_byte_header			; store null byte
 ENDIF

	; store battery gauge registers [nAs]
	SMOVSS	battery_gauge,mpr				; ISR-safe 6 byte copy of battery gauge value
	movf	mpr+0,W							; get byte 0
	rcall	ghostwrite_byte_header			; store data
	movf	mpr+1,W							; get byte 1
	rcall	ghostwrite_byte_header			; store data
	movf	mpr+2,W							; get byte 2
	rcall	ghostwrite_byte_header			; store data
	movf	mpr+3,W							; get byte 3
	rcall	ghostwrite_byte_header			; store data
	movf	mpr+4,W							; get byte 4
	rcall	ghostwrite_byte_header			; store data
	movf	mpr+5,W							; get byte 5
	rcall	ghostwrite_byte_header			; store data

	; write header stop code
	movlw	0xFB
	rcall	ghostwrite_byte_header			; store data
	movlw	0xFB
	rcall	ghostwrite_byte_header			; store data

	call	divemode_store_statistics		; store/update statistics for this unit
	bsf		reset_surface_interval			; request ISR to reset the surface interval timer

ghostwriter_end_dive_common:
; Update ext_flash_log_pointer into EEPROM
	clrf	EEADRH
	movff	ext_flash_log_pointer+0,EEDATA
	write_int_eeprom .4
	movff	ext_flash_log_pointer+1,EEDATA
	write_int_eeprom .5
	movff	ext_flash_log_pointer+2,EEDATA
	write_int_eeprom .6

; In DEBUG compile, write simulated dives to logbook and keep tissue pressures from simulation
	btfss	simulatormode						; in simulator mode, i.e. need to restore tissue pressures?
	bra		ghostwriter_end_dive_common_1		; NO
	bcf		simulatormode						; YES - clear mode flag
 ifndef _DEBUG
	call	deco_pull_tissues_from_vault		;     - restore tissue pressures (C-code)
	banksel	common								;     - back to bank common
 endif

ghostwriter_end_dive_common_1:
	bsf		reset_timebase						; request ISR to reset the timebase
;	btfsc	reset_timebase						; has the ISR confirmed reset of timebase?
;	bra		$-2									; NO - not yet, loop waiting for the ISR
	bcf		sensor_override_request				; request ISR to terminate the simulator mode
	btfsc	sensor_override_active				; has the ISR confirmed termination of simulator mode?
	bra		$-2									; NO - not yet, loop waiting for the ISR
	call	update_battery_registers			; update battery registers into EEPROM
	movff	simulator_time,char_I_dive_interval	; get the simulator runtime, reads 0 if exiting from a real dive
	call	deco_calc_dive_interval				; catch up with tissue desaturation when exiting from simulator,
												; else calculates for 2 seconds only when exiting from a real dive,
												; needed to update CNS, GF and tissue graphics for surface display  (C-code)
	call	deco_calc_desaturation_time			; calculate desaturation and no-fly/no-altitude time after catch-up (C-code)
	banksel	common								; back to bank common

	; the last surface pressure sample may have been taken while being submerged a bit already,
	; therefore it will be replaced by the sample taken one more before, which is the one that
	; became the surface pressure reference used while this dive.
	MOVII	pressure_abs_ref,pressure_abs_sampled

	goto	surfloop							; done with post-dive operations, return to surface loop


ghostwriter_load_pointer:						; load ext_flash_address:3 from EEPROM .4-.6
	clrf	EEADRH								; make sure to select EEPROM bank 0
	read_int_eeprom	.4
	movff	EEDATA,ext_flash_address+0
	read_int_eeprom	.5
	movff	EEDATA,ext_flash_address+1
	read_int_eeprom	.6
	movff	EEDATA,ext_flash_address+2
	return

ghostwriter_short_header_init:					; proceed one page forward
	clrf	EEDATA
	write_int_eeprom .4							; ext_flash_address+0 = 0
	movlw	.16
	addwf	ext_flash_address+1,F
	movlw	.0
	addwfc	ext_flash_address+2,F
	movlw	0x20
	cpfseq	ext_flash_address+2					; at address 0x200000?
	bra		ghostwriter_short_header_init2		; NO
	clrf	ext_flash_address+2					; YES - rollover to 0x000000
ghostwriter_short_header_init2:
	movlw	0xF0
	andwf	ext_flash_address+1,F				; keep higher nibble, set lower nibble to 0

	movff	ext_flash_address+1,EEDATA
	write_int_eeprom .5							; write new pointer
	movff	ext_flash_address+2,EEDATA
	write_int_eeprom .6							; write new pointer
	bra		ghostwriter_short_header2			; Done


	global	ghostwriter_short_header
ghostwriter_short_header:						; write short header with dive number into profile memory
	; load pointer for profile storing into RAM (Updated in EEPROM after the dive)
	rcall	ghostwriter_load_pointer			; load ext_flash_address:3 from EEPROM .4-.6

	; The following code is used to write a clean new dive after the previous hasn't been
	; stored correctly. e.g. after a battery fail during the dive
	call	ext_flash_byte_read_plus_0x20		; into ext_flash_rw
	incfsz	ext_flash_rw,F
	bra		ghostwriter_short_header_init		; not 0xFF -> init page
	call	ext_flash_byte_read_plus_0x20		; into ext_flash_rw
	incfsz	ext_flash_rw,F
	bra		ghostwriter_short_header_init		; not 0xFF -> init page

ghostwriter_short_header2:
	; All ok, reload the pointer and start
	rcall	ghostwriter_load_pointer			; load ext_flash_address:3 from EEPROM .4-.6

	; Clear dive length counter
	clrf	ext_flash_dive_counter+0
	clrf	ext_flash_dive_counter+1
	clrf	ext_flash_dive_counter+2

	; Write short header with dive number into profile memory
	movlw	0xFA
	rcall	ghostwrite_byte_profile				; WREG -> profile in ext. flash
	movlw	0xFA
	rcall	ghostwrite_byte_profile				; WREG -> profile in ext. flash
	; Load total number of dives (low byte only)
	read_int_eeprom .2
	incf	EEDATA,W							; +1
	rcall	ghostwrite_byte_profile				; WREG -> profile in ext. flash
	read_int_eeprom .3
	movf	EEDATA,W
	rcall	ghostwrite_byte_profile				; WREG -> profile in ext. flash
	movlw	0xFA
	rcall	ghostwrite_byte_profile				; WREG -> profile in ext. flash
	movlw	0xFA
	rcall	ghostwrite_byte_profile				; WREG -> profile in ext. flash

	; Keep room for dive length ext_flash_dive_counter:3 (Stored at the end of the dive)
	; Writing 0xFF three times here is mandatory
	; - 0xFF can be overwritten after the dive
	; - ghostwrite_byte_profile takes care of 4kB Page switching
	; - fixes an issue when we are at exactly 0xXXX000 here...

	movlw	0xFF
	call	write_byte_ext_flash_plus_nocnt		; WREG -> profile in ext. flash (No ext_flash_dive_counter:3 increase)
	movlw	0xFF
	call	write_byte_ext_flash_plus_nocnt		; WREG -> profile in ext. flash (No ext_flash_dive_counter:3 increase)
	movlw	0xFF
	call	write_byte_ext_flash_plus_nocnt		; WREG -> profile in ext. flash (No ext_flash_dive_counter:3 increase)

	movf	sampling_rate,W					; get sampling rate
	rcall	ghostwrite_byte_profile			; WREG -> profile in ext. flash

	movlw	.7								; number of divisors
	rcall	ghostwrite_byte_profile			; WREG -> profile in ext. flash

	movlw	.0								; type
	rcall	ghostwrite_byte_profile			; WREG -> profile in ext. flash
	movlw	infolength_temperature
	rcall	ghostwrite_byte_profile			; WREG -> profile in ext. flash
	movlw	div_temperature					; divisor temperature
	rcall	ghostwrite_byte_profile			; WREG -> profile in ext. flash

	movlw	.1								; Type
	rcall	ghostwrite_byte_profile			; WREG -> profile in ext. flash
	movlw	infolength_deco
	rcall	ghostwrite_byte_profile			; WREG -> profile in ext. flash
	movlw	div_deco						; divisor deco data
	rcall	ghostwrite_byte_profile			; WREG -> profile in ext. flash

	movlw	.2								; type
	rcall	ghostwrite_byte_profile			; WREG -> profile in ext. flash
	movlw	infolength_gf
	rcall	ghostwrite_byte_profile			; WREG -> profile in ext. flash
	movlw	div_gf							; divisor gf
	rcall	ghostwrite_byte_profile			; WREG -> profile in ext. flash

	movlw	.3								; type
	rcall	ghostwrite_byte_profile			; WREG -> profile in ext. flash
	movlw	infolength_ppo2_sensors
	rcall	ghostwrite_byte_profile			; WREG -> profile in ext. flash
	movlw	div_ppo2_sensors				; divisor ppO2
	btfss	FLAG_ccr_mode					; =1: CCR mode (Fixed ppO2 or Sensor) active
	movlw	.0								; no ppO2 data in OC mode
	rcall	ghostwrite_byte_profile			; WREG -> profile in ext. flash

	movlw	.4								; type
	rcall	ghostwrite_byte_profile			; WREG -> profile in ext. flash
	movlw	infolength_decoplan
	rcall	ghostwrite_byte_profile			; WREG -> profile in ext. flash
	movlw	div_decoplan					; divisor debug
	rcall	ghostwrite_byte_profile			; WREG -> profile in ext. flash

	movlw	.5								; Type
	rcall	ghostwrite_byte_profile			; WREG -> profile in ext. flash
	movlw	infolength_cns
	rcall	ghostwrite_byte_profile			; WREG -> profile in ext. flash
	movlw	div_cns							; divisor CNS
	rcall	ghostwrite_byte_profile			; WREG -> profile in ext. flash

	movlw	.6								; Type
	rcall	ghostwrite_byte_profile			; WREG -> profile in ext. flash
	movlw	infolength_tank
	rcall	ghostwrite_byte_profile			; WREG -> profile in ext. flash
	movlw	div_tank						; divisor tank
	rcall	ghostwrite_byte_profile			; WREG -> profile in ext. flash

	return

divemode_store_statistics:					; store/update statistics for this unit
	call	vault_decodata_into_eeprom		; update deco data
	call	do_logoffset_common_read		; read current logbook offset into mpr

	tstfsz	lo								; offset, low  byte = 0 ?
	bra		change_logbook_offset1			; NO - adjust offset
	tstfsz	hi								; offset, high byte = 0 ?
	bra		change_logbook_offset1			; NO - adjust offset
	bra		change_logbook_offset2			; YES to both - skip offset routine

change_logbook_offset1:
	INCI	mpr								; increment offset
	call	do_logoffset_common_write		; write incremented offset as the new offset

change_logbook_offset2:
	clrf	mpr+0							; prepare a 4 byte null value to clear the last dive time
	clrf	mpr+1							; ...
	clrf	mpr+2							; ...
	clrf	mpr+3							; ...
	SMOVFF	mpr,lastdive_time				; ISR-safe 4 byte copy of null value to last dive time counter


	; ISR-safe 3 byte copy of minutes:2 and seconds to last dive duration
	SMOVTT	counted_divetime_mins,lastdive_duration

	; 2 byte copies of max and avg relative pressures to last dive data
	MOVII	pressure_rel_max_cached,lastdive_maxdepth
	MOVII	pressure_rel_avg_total, lastdive_avgdepth

	return

	END
