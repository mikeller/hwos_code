;=============================================================================
;
;   File ghostwriter.asm                    * combined next generation V3.09.4k
;
;   Ghostwriter (Log profile recorder)
;
;   Copyright (c) 2011, JD Gascuel, heinrichs weikamp gmbh, all right reserved.
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
#include "logbook.inc"
#include "convert.inc"


	extern	deco_pull_tissues_from_vault


;-----------------------------------------------------------------------------
;  Macros - write PROFILE Data to FLASH (all macros are bank-safe)

FLASH_LIT_PROFILE	macro	literal				; write 1 byte LITERAL     to FLASH profile data
	movlw	literal
	rcall	ghostwrite_WREG_profile_exec
	endm

FLASH_WREG_PROFILE	macro						; write 1 byte from WREG   to FLASH profile data
	rcall	ghostwrite_WREG_profile_exec
	endm

FLASH_CC_PROFILE	macro	memory_address		; write 1 byte from memory to FLASH profile data
	MOVCC	memory_address,WREG
	rcall	ghostwrite_WREG_profile_exec
	endm

FLASH_II_PROFILE	macro	memory_address		; write 2 byte from memory to FLASH profile data
	lfsr	FSR0,memory_address
	rcall	ghostwrite_II_profile_exec
	endm


;-----------------------------------------------------------------------------
;   private local Variables

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


;=============================================================================
ghostwrite1		CODE
;=============================================================================

;-----------------------------------------------------------------------------
; prepare Data Recording
;
	global	init_recording_params		; initialize profile recording parameters
init_recording_params:
	movlw	div_temperature				; get divisor for temperature storage
	movwf	divisor_temperature			; initialize divisor

	movlw	div_deco					; get divisor for deco status
	movwf	divisor_deco				; initialize divisor

	movlw	div_gf						; get divisor for saturation
	movwf	divisor_supersat			; initialize divisor

	movlw	div_decoplan				; get divisor for deco plan
	movwf	divisor_decoplan			; initialize divisor

	movlw	div_cns						; get divisor for CNS
	movwf	divisor_cns					; initialize divisor

 IFDEF _rx_functions
	clrf	WREG						; default to no tank data logging
	btfsc	tr_functions_activated		; TR functions activated?
	movlw	div_tank					; YES - get divisor for tank data
	movwf	divisor_tank				; initialize divisor
 ENDIF

 IFDEF _external_sensor
	movlw	div_ppo2_sensors			; get divisor for ppO2 sensor
	movwf	divisor_ppo2_sensors		; initialize divisor by default
	btfsc	FLAG_ccr_mode				; in CCR mode?
	bra		init_recording_params_2		; YES - keep divisor
	btfsc	FLAG_pscr_mode				; NO  - in pSCR mode?
	bra		init_recording_params_2		;       YES - keep divisor
	clrf 	divisor_ppo2_sensors		;       NO  - clear divisor again
 ENDIF

init_recording_params_2:
	return


;=============================================================================
ghostwrite2		CODE
;=============================================================================

;-----------------------------------------------------------------------------
; sample and store a Set of Dive Data
;
	global	store_dive_data
store_dive_data:
	bcf		trigger_sample_divedata		; clear flag

 ifndef _DEBUG
	; In DEBUG compile, write simulated dives to logbook
	btfsc	sensor_override_active		; in simulator mode?
	return								; YES - no dive data stored in simulator mode
 endif

	btfss	FLAG_apnoe_mode				; in apnoe mode?
	bra		store_dive_data_1			; NO  - proceed
	TSTOSS	opt_store_apnoe				; YES - logging in apnoe mode enabled?
	return								;       NO  - done

store_dive_data_1:
	; store depth with every sample
	MOVII	pressure_rel_cur_cached,mpr	; copy current relative pressure to MPR
	call	convert_pres_to_depth		; convert pressure in [mbar] to depth in [cm]
	FLASH_II_PROFILE mpr				; store depth

	; first, find out how many bytes will be appended to this sample set
	clrf	ProfileFlagByte				; start with no bytes to append

	; check extended information
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
	addwf	ProfileFlagByte,F			;     - add to ProfileFlagByte
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
 IFDEF _rx_functions
	decfsz	divisor_tank,W				; check divisor if it will become 0, dump decremented value to WREG
	bra		check_extended7				; NO  - skip
	movlw	infolength_tank				; YES - get length of extra data
	addwf	ProfileFlagByte,F			;     - add to ProfileFlagByte
 ENDIF

check_extended7:
	; second, check global event flag
	btfss	event_occured				; check global event flag
	bra		store_dive_data3			; no event

	incf	ProfileFlagByte,F			; add one byte (the event byte 1)

	clrf	event_byte1					; reset event byte 1
	clrf	event_byte2					; reset event byte 2

	movf	alarm_type,W				; type of alarm Bit 0-3
	addwf	event_byte1,F				; copy to event byte 1, bit 0-3
	clrf	alarm_type					; reset alarm type

	; third, check events and add additional bytes
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
	; more events in future time...

store_dive_data3:
	btfsc	event_byte1,7				; is another event byte available?
	incf	ProfileFlagByte,F			; YES - add one byte (the event byte 2)

	btfsc	event_occured				; global event flag set?
	bsf		ProfileFlagByte,7			; YES - set event byte 1 flag in ProfileFlagByte

	FLASH_CC_PROFILE ProfileFlagByte	; store ProfileFlagByte

	btfss	event_occured				; global event flag set?
	bra		store_dive_data4			; NO  - no events to store

	; store the EventByte(s) + additional bytes now
	FLASH_CC_PROFILE event_byte1		; store 1st event byte

	btfss	event_byte1,7				; another event byte available?
	bra		store_dive_data3a			; NO  - skip
	FLASH_CC_PROFILE event_byte2		; YES - store 2nd event byte

store_dive_data3a:
	btfss	event_gas_change_gas6		; did a change to gas 6 occur?
	bra		store_dive_data3b			; NO  - skip
	FLASH_CC_PROFILE char_I_O2_ratio	; YES - store gas 6 O2 ratio
 IFDEF _helium
	FLASH_CC_PROFILE char_I_He_ratio	;     - store gas 6 He ratio
 ELSE
	FLASH_LIT_PROFILE .0				;     - store He ratio as zero
 ENDIF
	bcf		event_gas_change_gas6		;     - clear event flag

store_dive_data3b:
	btfss	event_gas_change			; did a gas change occur?
	bra		store_dive_data3c			; NO  - skip
 IFDEF _ccr_pscr
	movf	active_dil,W				; YES - get active diluent by default
	btfsc	FLAG_oc_mode				;     - in OC mode?
	movf	active_gas,W				;       YES - replace by active gas
	btfsc	bailout_mode				;     - in bailout?
 ENDIF
	movf	active_gas,W				;       (YES) - get (replace with) active OC (bailout) gas
	FLASH_WREG_PROFILE					;     - store active gas/diluent
	bcf		event_gas_change			;     - clear event flag

store_dive_data3c:
 IFDEF _ccr_pscr
	btfss	event_SP_change				; did a setpoint change occur?
	bra		store_dive_data3d			; NO  - skip
	FLASH_CC_PROFILE char_I_const_ppO2	; YES - store setpoint
	bcf		event_SP_change				;     - clear event flag
 ENDIF

store_dive_data3d:
 IFDEF _ccr_pscr
	btfss	event_bailout				; did a gas change due to bailout occur?
	bra		store_dive_data4			; NO  - skip
	FLASH_CC_PROFILE char_I_O2_ratio	; YES - store O2 ratio of bailout gas
 IFDEF _helium
	FLASH_CC_PROFILE char_I_He_ratio	;     - store He ratio of bailout gas
 ELSE
	FLASH_LIT_PROFILE .0				;     - store He ratio as zero
 ENDIF	; helium
	bcf		event_bailout				;     - clear event flag
 ENDIF	; _ccr_pscr

store_dive_data4:
	; Store extended information
	decfsz	divisor_temperature,F		; decrement timer, did it became 0 ?
	bra		store_dive_data4a			; NO  - skip
	rcall	store_dive_temperature		; YES - store temperature
store_dive_data4a:
	btfsc	divisor_temperature,7		; did the divisor under-run?
	clrf	divisor_temperature			; YES - reset timer

	decfsz	divisor_deco,F				; decrement timer, did it became 0 ?
	bra		store_dive_data4b			; NO  - skip
	rcall	store_dive_decodata			; YES - store deco data
store_dive_data4b:
	btfsc	divisor_deco,7				; did the timer under-run?
	clrf	divisor_deco				; YES - reset timer

	decfsz	divisor_supersat,F			; decrement timer, did it became 0 ?
	bra		store_dive_data4c			; NO  - skip
	rcall	store_dive_supersat			; YES - store supersaturation
store_dive_data4c:
	btfsc	divisor_supersat,7			; did the timer under-run?
	clrf	divisor_supersat			; YES - reset timer

 IFDEF _external_sensor
	decfsz	divisor_ppo2_sensors,F		; decrement timer, did it became 0 ?
	bra		store_dive_data4d			; NO  - skip
	rcall	store_dive_ppO2_sensors		; YES - store sensor data
store_dive_data4d:
	btfsc	divisor_ppo2_sensors,7		; did the timer under-run?
	clrf	divisor_ppo2_sensors		; YES - reset timer
 ENDIF

	decfsz	divisor_decoplan,F			; decrement timer, did it became 0 ?
	bra		store_dive_data4e			; NO  - skip
	rcall	store_dive_decoplan			; YES - store deco plan
store_dive_data4e:
	btfsc	divisor_decoplan,7			; did the timer under-run?
	clrf	divisor_decoplan			; YES - reset timer

	decfsz	divisor_cns,F				; decrement timer, did it became 0 ?
	bra		store_dive_data4f			; NO  - skip
	rcall	store_dive_cns				; YES - store CNS
store_dive_data4f:
	btfsc	divisor_cns,7				; did the timer under-run?
	clrf	divisor_cns					; YES - reset timer

 IFDEF _rx_functions
	decfsz	divisor_tank,F				; decrement timer, did it became 0 ?
	bra		store_dive_data4g			; NO  - skip
	rcall	store_dive_tank				; YES - store tank pressure
store_dive_data4g:
	btfsc	divisor_tank,7				; did the timer under-run?
	clrf	divisor_tank				; YES - reset timer
 ENDIF

store_dive_data5:
	bcf		event_occured				; clear the global event flag
	clrf	event_byte1					; reset event byte 1
	clrf	event_byte2					; reset event byte 2
	return								; done


 IFDEF _rx_functions
store_dive_tank:
	FLASH_II_PROFILE int_O_tank_pressure	; store tank pressure
	movlw	div_tank						; get sampling rate
	movwf	divisor_tank					; reload timer
	return
 ENDIF

store_dive_cns:
	MOVII	int_O_CNS_current,mpr			; get current CNS
	bcf		mpr+1,int_warning_flag			; clear warning   flag
	bcf		mpr+1,int_attention_flag		; clear attention flag
	FLASH_II_PROFILE mpr					; store CNS
	movlw	div_cns							; get sampling rate
	movwf	divisor_cns						; reload timer
	return

store_dive_decoplan:
	; store the deco plan
	lfsr	FSR1,char_O_deco_time_for_log	; load base address of deco stop times table
	movlw	NUM_STOPS_LOG					; load size         of deco stop times table
	movwf	lo								; copy size to loop counter
store_dive_decoplan_loop:
	movf	POSTINC1,W						; get a stop time
	FLASH_WREG_PROFILE						; store it
	decfsz	lo,F							; decrement loop counter, became zero?
	bra		store_dive_decoplan_loop		; NO  - loop
	movlw	div_decoplan					; YES - get sampling rate
	movwf	divisor_decoplan				;     - reload timer
	return									;     - done


 IFDEF _external_sensor
store_dive_ppO2_sensors:
	FLASH_CC_PROFILE sensor1_ppO2			; store sensor 1 ppO2 (in 0.01 bar steps)
	SMOVII	sensor1_mv,mpr					; ISR-safe 2 byte copy of o2_mv_sensor
	FLASH_II_PROFILE mpr					; store sensor 1 mV

	FLASH_CC_PROFILE sensor2_ppO2			; store sensor 2 ppO2 (in 0.01 bar steps)
	SMOVII	sensor2_mv,mpr					; ISR-safe 2 byte copy of o2_mv_sensor
	FLASH_II_PROFILE mpr					; store sensor 2 mV

	FLASH_CC_PROFILE sensor3_ppO2			; store sensor 3 ppO2 (in 0.01 bar steps)
	SMOVII	sensor3_mv,mpr					; ISR-safe 2 byte copy of o2_mv_sensor
	FLASH_II_PROFILE mpr					; store sensor 3 mV

	movlw	div_ppo2_sensors				; get sampling rate
	movwf	divisor_ppo2_sensors			; reload timer
	return									; done
 ENDIF

store_dive_supersat:
	FLASH_CC_PROFILE int_O_lead_supersat+0	; store leading tissue's supersaturation (value is limited to 255, only lower byte is used for the value)
	movlw	div_gf							; get sampling rate
	movwf	divisor_supersat				; reload timer
	return									; done

store_dive_decodata:
	; Check if deco stops are necessary
	movff	char_O_deco_depth,WREG			; get depth of the first stop
	tstfsz	WREG							; depth of first stop > 0 m (aka in deco) ?
	bra		store_dive_decodata_deco		; YES
	;bra	store_dive_decodata_ndl			; NO

store_dive_decodata_ndl:
	FLASH_LIT_PROFILE .0					; store depth of first stop as zero (encodes NDL dive)
	FLASH_CC_PROFILE int_O_NDL_norm+0		; store NDL time from normal plan
	bra		store_dive_decodata_common

store_dive_decodata_deco:
	FLASH_CC_PROFILE char_O_deco_depth		; store depth    of the first stop in meters
	FLASH_CC_PROFILE char_O_deco_time		; store duration of the first stop in minutes
	;bra	store_dive_decodata_common

store_dive_decodata_common:
	movlw	div_deco						; get sampling rate
	movwf	divisor_deco					; reload timer
	return									; done

store_dive_temperature:
	SMOVII	temperature_cur,mpr				; ISR-safe 2 byte copy of current temperature
	FLASH_II_PROFILE mpr					; store temperature
	movlw	div_temperature					; get sampling rate
	movwf	divisor_temperature				; reload timer
	return									; done


; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; flash writing through the macros
;
ghostwrite_II_profile_exec:
	movf	POSTINC0,W						; get byte into WREG
	call	ext_flash_write_byte_0x20_incdc	; write to external flash and increment ext_flash_dive_counter
	movf	POSTINC0,W						; get next byte into WREG
ghostwrite_WREG_profile_exec:
	goto	ext_flash_write_byte_0x20_incdc	; write to external flash and increment ext_flash_dive_counter (and return)
;
; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


;-----------------------------------------------------------------------------
; finish Dive Data Recording and write Header
;
	global	ghostwriter_end_dive
ghostwriter_end_dive:
	; save end-of-profile pointer for later storage in EEPROM
	MOVTT	ext_flash_address,ext_flash_log_pointer

	; remember last custom view shown in dive mode
	movff	active_customview,customview_divemode

	; reset gas/diluent lost & staged flags
	lfsr	FSR1,opt_gas_type				; load FSR1 with base address of opt_gas_type
 IFDEF _ccr_pscr
	movlw	2*NUM_GAS						; load loop counter with number of gases + diluents = 2*5
 ELSE
	movlw	NUM_GAS							; load loop counter with number of gases = 5
 ENDIF
ghostwriter_end_dive_0:
	bcf		INDF1,gas_lost					; clear lost   flag and keep    index at present gas/dil
	bcf		POSTINC1,gas_staged				; clear staged flag and advance index to next    gas/dil
	decfsz	WREG							; decrement loop counter and check if it became zero
	bra		ghostwriter_end_dive_0			; NO  - not yet, loop

	; clear bailout state (if applicable)
	bcf		bailout_mode

	; check if dive is worth storage at all
	btfss	divetime_longer_1min			; dive longer than one minute?
	goto	ghostwriter_end_dive_common		; NO  - discard everything

 ifndef _DEBUG
	; in DEBUG compile, write simulated dives to logbook
	btfsc	sensor_override_active			; in simulator mode?
	goto	ghostwriter_end_dive_common		; YES - discard everything
 endif

	; calculate desaturation time
	call	deco_calc_desaturation_time		; call the C-code
	banksel	common							; back to bank common

	; condition apnoe mode
	btfss	FLAG_apnoe_mode								; are we in apnoe mode?
	bra		ghostwriter_end_dive_00						; NO  - proceed
	MOVII	apnoe_max_pressure,pressure_rel_max_cached	; YES - get max pressure of all yoyo dives

ghostwriter_end_dive_00:
	; compute max depth for storage and last dive statistics
	MOVII	pressure_rel_max_cached,mpr		; get max pressure
	call	convert_pres_to_depth			; convert pressure in [mbar] to depth in [cm]
	MOVII	mpr,lastdive_maxdepth			; store for last dive statistics

	; compute avg depth for storage and last dive statistics
	MOVII	pressure_rel_avg_total,mpr		; get average pressure
	call	convert_pres_to_depth			; convert pressure in [mbar] to depth in [cm]
	MOVII	mpr,lastdive_avgdepth			; store in last dive statistics

	; get dive duration for last dive statistics
	SMOVTT	counted_divetime_mins,lastdive_duration	; ISR-safe 3 byte copy of minutes:2 and seconds

	; check logging of apnoe mode
	btfss	FLAG_apnoe_mode					; are we in apnoe mode?
	bra		ghostwriter_end_dive_1			; NO  - proceed
	TSTOSS	opt_store_apnoe					; YES - logging in apnoe mode enabled?
	goto	ghostwriter_end_dive_cleanup	;       NO  - skip logging but do the after-dive cleanup

ghostwriter_end_dive_1:

	;---- dive finished (and longer than one minute) -------------------------

	; close profile recording
	FLASH_LIT_PROFILE 0xFD					; write end-of-profile code, byte 1
	FLASH_LIT_PROFILE 0xFD					; write end-of-profile code, byte 2

	; save end-of-profile pointer for later storage in header and EEPROM
	MOVTT	ext_flash_address,ext_flash_log_pointer

	; go back again to start of profile data to store the profile length (number of recorded bytes)
	call	ghostwriter_load_pointer

	; skip internal "0xFA 0xFA #Divenumber:2 0xFA 0xFA" header, i.e. the first 6 bytes
	EXT_FLASH_INC_ADDRESS_0x20 d'6'

	; store dive length (NO ext_flash_length_counter increase, NO page delete)
	movf	ext_flash_length_counter+0,W	; get length of profile data, low   byte
	call	ext_flash_write_byte_0x20_nodel	; write to flash
	movf	ext_flash_length_counter+1,W	; get length of profile data, high  byte
	call	ext_flash_write_byte_0x20_nodel	; write to flash
	movf	ext_flash_length_counter+2,W	; get length of profile data, upper byte
	call	ext_flash_write_byte_0x20_nodel	; write to flash

	; ... profile recording done

	; read, increment, and store updated total number of dives
	call	eeprom_total_dives_read			; read total number of dives
	INCI	mpr								; increment by one
	call	eeprom_total_dives_write		; store updated number of total dives

	; prepare header
	CLRR	header_buffer,.256				; initialize header to all zeros

	; store header start code
	MOVLI	0xFAFA,mpr
	MOVII	mpr,header_buffer+index_header_start

	; store pointer to begin of dive profile
	EEPROM_TT_READ	eeprom_log_pointer,mpr
	MOVTT	mpr,header_buffer+index_profile_start_address

	; store pointer to end of dive profile
	MOVTT	ext_flash_log_pointer,header_buffer+index_profile_end_address

	; write the profile format version (defined in hwos.inc)
	movlw	logbook_profile_version
	MOVCC	WREG,header_buffer+index_profile_version

	; store dive length (in units of recording entries)
	MOVTT	ext_flash_length_counter,header_buffer+index_profile_byte_count

	; store time time & date of dive begin
	MOVTT	start_year,header_buffer+index_date
	MOVTT	start_hour,header_buffer+index_time

	; store max depth
	MOVII	lastdive_maxdepth,header_buffer+index_max_depth

	; store dive time (ISR-safe 3 byte copy of minutes:2 and seconds)
	SMOVTT	counted_divetime_mins,header_buffer+index_divetime

	; store minimum temperature
	MOVII	temperature_min,header_buffer+index_min_temp

	; store surface pressure (as used by deco engine)
	MOVII	int_I_pres_surface,header_buffer+index_surface_press

	; store desaturation time
	MOVII	int_O_desaturation_time,header_buffer+index_desattime

	; store gases / diluents
	lfsr	FSR1,header_buffer+index_gas1	; load FSR1 with base address of gases / diluents in header

 IFDEF _ccr_pscr
	btfsc	FLAG_ccr_mode					; in CCR mode?
	bra		end_dive_gaslist_diluent		; YES - write diluent gas list
	btfsc	FLAG_pscr_mode					; NO  - in pSCR mode?
	bra		end_dive_gaslist_diluent		;       YES - write diluent gas list
	;bra	end_dive_gaslist_gas			;       NO  - write OC      gas list
 ENDIF

end_dive_gaslist_gas:						; write OC gases
	lfsr	FSR0,opt_gas_O2_ratio-.1		; set base address to (opt_gas_O2_ratio - 1) because of pre-increment statement
	bra		end_dive_gaslist_common			; write all 5 OC gases

 IFDEF _ccr_pscr
end_dive_gaslist_diluent:					; write diluents
	lfsr	FSR0,opt_dil_O2_ratio-.1		; set base address to (opt_dil_O2_ratio - 1) because of pre-increment statement
	;bra	end_dive_gaslist_common			; write all 5 diluents
 ENDIF

end_dive_gaslist_common:					; helper function for writing gas list entries

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

	movlw	.5								; 5 gases to store
	movwf	lo								; use lo as counter
end_dive_gaslist_loop:
	movff	PREINC0,POSTINC1				; increment FSR0 address and copy O2 ratio to buffer
	movlw	.10								; offset for H2 ratios
	movff	PLUSW0,POSTINC1					; copy H2 ratio to buffer
	movlw	.30								; offset for change depths
	movff	PLUSW0,POSTINC1					; copy change depth to buffer
	movlw	.20								; offset for types
	movff	PLUSW0,POSTINC1					; copy type to buffer
	decfsz	lo								; decrement counter, did it became 0 ?
	bra		end_dive_gaslist_loop			; NO  - loop

	; store major firmware version
	movlw	fw_version_major
	MOVCC	WREG,header_buffer+index_firmware+0

	; store minor firmware version
	movlw	fw_version_minor
	MOVCC	WREG,header_buffer+index_firmware+1

	; store battery voltage
	MOVII	batt_voltage,header_buffer+index_battery_voltage

	; store sampling rate
	MOVCC	sampling_rate,header_buffer+index_samplingrate

	; store CNS at beginning of dive
	MOVII	CNS_start,header_buffer+index_cns_start

	; store supersaturations
	MOVCC	supersat_start,       header_buffer+index_supersat_start
	MOVCC	int_O_lead_supersat+0,header_buffer+index_supersat_end		; low byte only needed

	; store logbook offset
	call	eeprom_log_offset_read
	MOVII	mpr,header_buffer+index_logoffset

	; increment log offset
	rcall	increment_log_offset

	; store battery level
	MOVCC	batt_percent,header_buffer+index_batt_percent

 IFDEF _ccr_pscr
	; store setpoints
	lfsr	FSR0,opt_setpoint_cbar			; base address of ppO2 values
	lfsr	FSR1,opt_setpoint_change		; base address of change depths
	lfsr	FSR2,header_buffer+index_sp1	; base address of setpoint data in header buffer
	movlw	.5								; 5 setpoints (ppO2, depth) to be stored
	movwf	lo								; use lo as counter
end_dive_sp_loop:
	movff	POSTINC0,POSTINC2				; copy ppO2 value
	movff	POSTINC1,POSTINC2				; copy change depth
	decfsz	lo								; decrement counter, did it became 0 ?
	bra		end_dive_sp_loop				; NO  - loop
 ELSE
	; just leave the zero bytes written during header initialization in place
 ENDIF

	; store salinity
	MOVCC	opt_salinity,header_buffer+index_salinity

	; store CNS at end of dive
	MOVII	int_O_CNS_current,mpr			; get CNS into mpr
	bcf		mpr+1,int_warning_flag			; clear warning   flag
	bcf		mpr+1,int_attention_flag		; clear attention flag
	MOVII	mpr,header_buffer+index_cns_end	; store CNS

	; store average depth
	MOVII	lastdive_avgdepth,header_buffer+index_avr_depth

	; store total dive time (ISR-safe 2 byte copy)
	SMOVII	total_divetime_secs,header_buffer+index_total_seconds

	; store GF low/high or saturation/desaturation multiplier
	movff	char_I_model,WREG				; get deco model
	xorlw	.1								; deco model = ZH-L16-GF ?
	bz		end_dive_gf						; YES - store GFs
	;bnz	end_dive_sat					; NO  - store sat/desat

end_dive_sat:
	movff	char_I_saturation_multiplier,  header_buffer+index_factor_sat_desat+0	; saturation  multiplier
	movff	char_I_desaturation_multiplier,header_buffer+index_factor_sat_desat+1	; desaturation multiplier
	bra		end_dive_sat_gf_done													; continue

end_dive_gf:
	movff	char_I_GF_Low_percentage,      header_buffer+index_gf_lo_hi+0			; GF low
	movff	char_I_GF_High_percentage,     header_buffer+index_gf_lo_hi+1			; GF high
	;bra	end_dive_sat_gf_done													; continue

end_dive_sat_gf_done:
	; store deco model
	MOVCC	char_I_model,header_buffer+index_decomodel

	; store total dive number
	call	eeprom_total_dives_read
	MOVII	mpr,header_buffer+index_total_dives

	; store dive mode
	MOVCC	opt_dive_mode,header_buffer+index_divemode

	; store tissue data - total tissue pressure
	lfsr	FSR1,char_O_tissue_pressure					; load base address of total tissue pressures (chars)
	lfsr	FSR2,header_buffer+index_tissue_pres_total	; load corresponding base address in header
	bsf		aux_flag									; clear bit 7 (on-/off-gassing flag bit)
	movlw	.16											; 16 tissues to copy
	rcall	copy_tissuepres_to_header					; store the tissue pressures

	; store tissue data - N2 floats
	lfsr	FSR1,0x700									; load base address of N2 tissue pressures (floats)
	;lfsr	FSR2,header_buffer+index_tissue_pres_N2		; load corresponding base address in header
	bcf		aux_flag									; do not touch bit 7
	movlw	.64											; 16 tissue x 4 byte/tissue to copy
	rcall	copy_tissuepres_to_header					; store the tissue pressures

	; store tissue data - tissue supersaturations
	lfsr	FSR1,char_O_tissue_saturation				; load base address of tissue saturations (chars)
	;lfsr	FSR2,header_buffer+index_tissue_supersat	; load corresponding base address in header
	bsf		aux_flag									; clear bit 7 (on-/off-gassing flag bit)
	movlw	.16											; 16 tissues to copy
	rcall	copy_tissuepres_to_header					; store the tissue pressures

	; store tissue data - He floats
	lfsr	FSR1,0x740									; load base address of He tissue pressures (floats)
	;lfsr	FSR2,header_buffer+index_tissue_pres_He		; load corresponding base address in header
	bcf		aux_flag									; do not touch bit 7
	movlw	.64											; 16 tissue x 4 byte/tissue to copy
	rcall	copy_tissuepres_to_header					; store the tissue pressures

	; store last stop depth
	MOVCC	char_I_last_stop_depth,header_buffer+index_last_stop

	; store deco distance
	; -> the deco distance concept is disposed of, so just store a hard-coded zero
	; --> so just leave the zero written during header initialization in place
	;clrf	WREG
	;MOVCC	WREG,header_buffer+index_decodistance

 IFDEF _external_sensor
	; store last HUD data (ISR-safe 3 byte copy)
	SMOVTT	hud_status_byte,header_buffer+index_hud_data
 ELSE
	; just leave the zero bytes in place
 ENDIF

	; store battery gauge registers [nAs] (ISR-safe 6 byte copy)
	SMOVSS	battery_gauge,header_buffer+index_battery_gauge

	; write header stop code
	MOVLI	0xFBFB,mpr
	MOVII	mpr,header_buffer+index_header_stop

	; store header in the FLASH
	call	eeprom_total_dives_read			; read total number of dives
	decf	mpr+0,W							; compute index from low(total number of dives)
	call	log_header_addr_by_index		; compute header start address
	call	ext_flash_erase_4kB				; erase the FLASH 4 kB block where the header will be stored
	FLASH_RR_WRITE header_buffer,.256		; write the header to the FLASH

ghostwriter_end_dive_cleanup:
	call	eeprom_deco_data_write			; update deco data in EEPROM
	bsf		reset_surface_interval			; request ISR to reset the surface interval timer

ghostwriter_end_dive_common:
	; memorize current ext_flash_log_pointer in EEPROM
	EEPROM_TT_WRITE ext_flash_log_pointer,eeprom_log_pointer

	; terminate simulator mode
	btfss	simulatormode					; in simulator mode, i.e. need to restore tissue pressures?
	bra		ghostwriter_end_dive_common_1	; NO  - continue
	bcf		simulatormode					; YES - end simulator mode
	bcf		sensor_override_request			;     - request ISR to terminate the simulator mode
	btfsc	sensor_override_active			;     - has the ISR confirmed termination of simulator mode?
	bra		$-2								;       NO - not yet, loop waiting for the ISR

 ifndef _DEBUG
	; in DEBUG compile, keep tissue pressures from simulated dives
	call	deco_pull_tissues_from_vault	;     - restore tissue pressures (C-code)
	banksel	common							;     - back to bank common
 endif

ghostwriter_end_dive_common_1:
	; restart the timebase
	bsf		reset_timebase					; request ISR to reset the timebase
;	btfsc	reset_timebase					; has the ISR confirmed reset of timebase?
;	bra		$-2								; NO - not yet, loop waiting for the ISR

	; update battery gauge into EEPROM
	call	eeprom_battery_gauge_write

	; catch-up simulator runtime / calculate deco data for surface mode
	movff	simulator_time,char_I_dive_interval	; get the simulator runtime, reads 0 if exiting from a real dive
	call	deco_calc_dive_interval				; catch up with tissue desaturation when exiting from simulator,
												; else calculates for 2 seconds only when exiting from a real dive,
												; needed to update CNS, GF and tissue graphics for surface display.
	call	deco_calc_desaturation_time			; calculate desaturation and no-fly/no-altitude time after catch-up
	banksel	common								; back to bank common

	; the last surface pressure sample may have been taken while being submerged a bit already,
	; therefore it will be replaced by the sample taken one more before, which is the one that
	; became the surface pressure reference used while this dive.
	MOVII	pressure_abs_ref,pressure_abs_sampled

	; done with post-dive operations, return to surface loop
	goto	surfloop


;-----------------------------------------------------------------------------
; Helper Function - copy Tissue Pressures
;
copy_tissuepres_to_header:
	movwf	eeprom_loop						; initialize loop counter (EEPROM var used here)
copy_tissuepres_to_header_loop:
	movf	POSTINC1,W						; copy tissue pressure to WREG
	btfsc	aux_flag						; shall clear bit 7 ?
	bcf		WREG,7							; YES - clear bit for on-gassing/off-gassing
	movwf	POSTINC2						; copy WREG to header buffer
	decfsz	eeprom_loop,F					; decrement loop counter, all done?
	bra		copy_tissuepres_to_header_loop	; NO  - loop
	return									; YES - done


;-----------------------------------------------------------------------------
; Helper Function - increment Log Offset
;
increment_log_offset:
	call	eeprom_log_offset_read			; read current logbook offset into mpr
	movf	mpr+0,W							; get               low  byte
	iorwf	mpr+1,W							; inclusive-or with high byte, result zero?
	bz		increment_log_offset_1			; YES - skip offset correction
	INCI	mpr								; NO  - increment offset
	call	eeprom_log_offset_write			;     - store incremented offset as new offset
increment_log_offset_1:
	return									; done


;-----------------------------------------------------------------------------
; start Dive Data Recording (write short Header with Dive Number)
;
	global	ghostwriter_short_header
ghostwriter_short_header:
	; get pointer for profile storing
	rcall	ghostwriter_load_pointer

	; the following code is used to write a clean new dive after the previous
	; hasn't been stored correctly. e.g. after a power loss during the dive
	FLASH_II_READ_0x20 mpr					; read first two bytes
	incfsz	mpr+0,F							; is 1st byte = 0xFF ?
	bra		ghostwriter_short_header_init	; NO  - initialize page
	incfsz	mpr+1,F							;     - is 2nd byte = 0xFF ?
	bra		ghostwriter_short_header_init	;       NO  - initialize page
	bra		ghostwriter_short_header_2		;       YES - page is clean, can continue

ghostwriter_short_header_init:
	clrf	ext_flash_address+0				; low  byte: set to zero
	movlw	0xF0							; high byte: keep upper nibble, set lower nibble to zero
	andwf	ext_flash_address+1,F			; ...
	movlw	.16								; increment ext_flash_address to next multiple of 16*256
	addwf	ext_flash_address+1,F			; ...
	movlw	.0								; ...
	addwfc	ext_flash_address+2,F			; ...
	movlw	0x20							; at address 0x200000 ?
	cpfseq	ext_flash_address+2				; ...
	bra		ghostwriter_short_header_init_2	; NO  - continue
	clrf	ext_flash_address+2				; YES - rollover to 0x000000

ghostwriter_short_header_init_2:
	; update pointer in EEPROM
	EEPROM_TT_WRITE ext_flash_address,eeprom_log_pointer

ghostwriter_short_header_2:
	; reload the pointer (required after above checks)
	rcall	ghostwriter_load_pointer		; reload ext_flash_address from EEPROM

	; clear dive length counter
	CLRT	ext_flash_length_counter

	; write short start header with dive number into profile memory
	FLASH_LIT_PROFILE 0xFA					; 1st byte
	FLASH_LIT_PROFILE 0xFA					; 2nd byte

	; load total number of dives
	call	eeprom_total_dives_read			; read total number of dives into mpr:2
	incf	mpr+0,F							; increment low byte + 1
	FLASH_II_PROFILE mpr					; write mpr:2 to FLASH

	; close short header
	FLASH_LIT_PROFILE 0xFA					; 1st byte
	FLASH_LIT_PROFILE 0xFA					; 2nd byte

	; Keep room for dive length ext_flash_length_counter:3 (stored at the end of the dive),
	; writing 0xFF here is mandatory because 0xFF can be overwritten when closing the dive.
	; The stored dive length counter itself is not part of the counted dive length.

	setf	WREG							; write 0xFF
	call	ext_flash_write_byte_0x20		; write to profile (no dive length increment)
	setf	WREG							; write 0xFF
	call	ext_flash_write_byte_0x20		; write to profile (no dive length increment)
	setf	WREG							; write 0xFF
	call	ext_flash_write_byte_0x20		; write to profile (no dive length increment)

	; store sizes and sampling rates of recording datasets

	FLASH_CC_PROFILE  sampling_rate				; get general sampling rate

	FLASH_LIT_PROFILE .7						; number of additional datasets

	FLASH_LIT_PROFILE .0						; type: temperature
	FLASH_LIT_PROFILE infolength_temperature	; get size of recording data
	FLASH_LIT_PROFILE div_temperature			; get sampling rate


	FLASH_LIT_PROFILE .1						; type: +++
	FLASH_LIT_PROFILE infolength_deco			; get size of recording data
	FLASH_LIT_PROFILE div_deco					; get sampling rate

	FLASH_LIT_PROFILE .2						; type: saturation
	FLASH_LIT_PROFILE infolength_gf				; get size of recording data
	FLASH_LIT_PROFILE div_gf					; get sampling rate

	FLASH_LIT_PROFILE .3						; type: ppO2 sensor data
	FLASH_LIT_PROFILE infolength_ppo2_sensors	; get size of recording data
	movlw	.0									; default to no ppO2 data
 IFDEF _external_sensor
	btfsc	FLAG_ccr_mode						; in CCR mode?
	movlw	div_ppo2_sensors					; YES - get sampling rate
	btfsc	FLAG_pscr_mode						; in pSCR mode?
	movlw	div_ppo2_sensors					; YES - get sampling rate
 ENDIF
	FLASH_WREG_PROFILE							; WREG -> profile in ext. flash

	FLASH_LIT_PROFILE .4						; type: deco plan (stop times)
	FLASH_LIT_PROFILE infolength_decoplan		; get size of recording data
	FLASH_LIT_PROFILE div_decoplan				; get sampling rate

	FLASH_LIT_PROFILE .5						; type: CNS
	FLASH_LIT_PROFILE infolength_cns			; get size of recording data
	FLASH_LIT_PROFILE div_cns					; get sampling rate

	FLASH_LIT_PROFILE .6						; type: tank pressure
	FLASH_LIT_PROFILE infolength_tank			; get size of recording data
	movlw	.0									; default to no tank pressure data
 IFDEF _rx_functions
	btfsc	tr_functions_activated				; TR functions activated?
	movlw	div_tank							; YES - get sampling rate
 ENDIF
	FLASH_WREG_PROFILE							; WREG -> profile in ext. flash

	return										; done


;-----------------------------------------------------------------------------
; Helper Function - load ext_flash_address from EEPROM
;
ghostwriter_load_pointer:
	EEPROM_TT_READ	eeprom_log_pointer,ext_flash_address
	return

;-----------------------------------------------------------------------------

	END
