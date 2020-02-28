;=============================================================================
;
;   File options.asm                          next combined generation V3.08.8
;
;   Manage all options data.
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;   2011-07-12 : [jDG] Creation.
;

#include "hwos.inc"							; mandatory header
#include "strings.inc"
#include "convert.inc"
#include "ghostwriter.inc"
#include "eeprom_rs232.inc"
#include "external_flash.inc"
#include "wait.inc"
#include "shared_definitions.h"
#include "gaslist.inc"

	extern	write_eeprom
	extern	read_eeprom
	extern	option_table_begin,option_table_end
	extern	convert_meter_to_feet

options		CODE

;=============================================================================
; Reset all options to factory defaults (in memory only)
;
; INPUT:  none
; OUTPUT: none
; TRASH:  TBLPTR, TABLAT, WREG, FSR0, FSR1, FSR2
;
	global	option_reset_all				; reset all options to factory default
option_reset_all:
	call	eeprom_total_dives_read			; read total number of dives
	tstfsz	mpr+0							; number of total dives, low  byte = 0 ?
	bra		option_reset_all_1				; NO - skip resetting logbook
	tstfsz	mpr+1							; number of total dives, high byte = 0 ?
	bra		option_reset_all_1				; NO - skip resetting logbook

	; reset logbook
	call	erase_complete_logbook			; erase complete logbook

	; reset logbook offset
	CLRI	mpr								; set   logbook offset to zero
	call	eeprom_log_offset_write			; store logbook offset

option_reset_all_1:
	lfsr	FSR0,option_table_begin			; point to start of option definition table
option_reset_all_loop:
	rcall	option_reset					; reset option
	incfsz	opt_end_token,F					; was this the last option (was opt_end_token = 255) ?
	bra		option_reset_all_loop			; NO  - do next option
	return									; YES - done


;=============================================================================
; Reset an option to its default value
; INPUT:  FSR0 = option handle
; OUTPUT: none
; TRASH:  TBLPTR, TABLAT, WREG, FSR1, FSR2
;
	global	option_reset					; reset option value to default
option_reset:
	; read type, default and register from table
	rcall	option_read_definition			; read option definition

option_reset_loaded:						; entry point with option definition already read
	bsf		option_repaired					; flag that an option was repaired
	bsf		options_changed					; flag that EEPROM needs to be updated
	movf	opt_type,W						; get option type
	xorlw	.2								; type = STRING ?
	bz		opt_reset_string				; YES - string copy
	movff	opt_default,INDF1				; NO  - 1 byte copy
	return									;     - done

opt_reset_string:
	movff	FSR1L,FSR2L						; set string destination address
	movff	FSR1H,FSR2H						; ...
	movff	opt_default+0,FSR1L				; get handle to multi-lingual text in FSR1
	movff	opt_default+1,FSR1H				; ...
	movff	TBLPTRL,mpr+0					; TBLPTR will be trashed by text routine, so make a back-up
	movff	TBLPTRH,mpr+1					; ...
	movff	TBLPTRU,mpr+2					; ...
	call	strcat_text						; copy translated text to FSR2
	movff	mpr+0,TBLPTRL					; restore TBLPTR
	movff	mpr+1,TBLPTRH					; ...
	movff	mpr+2,TBLPTRU					; ...
	return									; done


;=============================================================================
; Read option definition
; INPUT:  FSR0 = option handle
; OUTPUT: FSR1 = address of variable.
; TRASH:  TBLPTR, TABLAT, WREG, FSR0, FSR1
;
option_read_definition:
	movff	FSR0L,TBLPTRL					; low byte  : set memory address of option data set
	movlw	HIGH(option_table_begin)		; high byte : get table start address
	andlw	0xF0							;             keep only the upper nibble
	iorwf	FSR0H,W							;             add the memory address of the option data set
	movwf	TBLPTRH							;             set the resulting memory address
	movlw	UPPER(option_table_begin)		; upper byte: get table start address
	movwf	TBLPTRU							;             set memory address of option data set

	lfsr	FSR1,opt_type					; load FSR1 with base address of option definition vars
	movlw	opt_definiton_bytes				; get number of bytes to copy
	movwf	eeprom_loop						; initialize loop counter (using an EEPROM variable here)
option_read_definition_loop:
	tblrd*+									; read one byte from program memory and increment address
	movff	TABLAT,POSTINC1					; transfer byte from program memory to memory
	decfsz	eeprom_loop,F					; all bytes done?
	bra		option_read_definition_loop		; NO  - loop
	tblrd*									; YES - read one byte ahead without incrementing address
	movff	TABLAT,POSTINC1					;     - store byte
	movff	opt_memory+0,FSR1L				;     - load FSR1 with the address of the option value variable
	movff	opt_memory+1,FSR1H				;     - ...
	movff	TBLPTRL,FSR0L					;     - advance handle to the next option definition data set
	movff	TBLPTRH,FSR0H					;     - ...
	return									;     - done


;=============================================================================
; Check one option and reset its value if it is out of min/max boundary
; INPUT:  opt_* vars and FSR1
; OUTPUT: option value set to default if out of min/max
; TRASH:  WREG
;
option_check_loaded:
	; switch on type
	movf	opt_type,W						; get type
	bz		option_check_uint8				; type 0: INT8
	dcfsnz	WREG							; decrement
	bra		option_check_enum8				; type 1: ENUM
	dcfsnz	WREG							; decrement
	bra		option_check_string				; type 2: STRING
	;bra	option_check_uint8				; type 3: INT8

option_check_uint8:
	tstfsz	opt_min							; opt_min = 0 ?
	bra		option_check_min				; NO  - check it
	bra		option_check_enum8				; YES - continue with check for maximum

option_check_min:
	decf	opt_min,W						; get (minimum permissible value - 1) into WREG
	cpfsgt	INDF1							; option value > (minimum permissible value - 1) ?
	bra		option_reset_loaded				; NO  - reset option value
	;bra	option_check_enum8				; YES - continue with check for maximum

option_check_enum8:
	infsnz	opt_max,W						; get (highest permissible value + 1) into WREG
	return									; highest permissible value was 255, skip check, done
	cpfslt	INDF1							; option value < (highest permissible value + 1) ?
	bra		option_reset_loaded				; NO  - reset option value
	return									; YES - within range, done

option_check_string:
	return									; nothing to check with strings


;=============================================================================
; Check and store all option values in EEPROM
;
	global	option_check_and_store_all
option_check_and_store_all:
	bcf		PIR3,RC2IE						; disable EUSART interrupts

	;---- save option version
	MOVLI	eeprom_opt_version,mpr				; get   options version number
	EEPROM_II_WRITE mpr,eeprom_options_version	; store options version number in EEPROM

	;---- check and resolve some interdependencies among options
	bsf		is_diluent_menu					; setup checking diluents
	call	gaslist_cleanup_list			; check and correct multiple or none First diluents

	bcf		is_diluent_menu					; setup checking gases
	call	gaslist_cleanup_list			; check and correct multiple or none First gases

 IFNDEF _gauge_mode
	call	option_cleanup_gauge			; check and correct gauge mode
 ENDIF

 IFDEF _ccr_pscr
	call	option_cleanup_oCCRMode			; check and correct CCR / pSCR mode
 ENDIF

	call	option_cleanup_GF				; check and correct GFlow <= GFhigh

	;---- check and save all option values
	lfsr	FSR0,option_table_begin			; point to start of option definition table
option_save_all_loop:
	rcall	option_check_and_store			; check and save option value
	incfsz	opt_end_token,F					; was this the last option (was opt_end_token = 255) ?
	bra		option_save_all_loop			; NO  - do next option
	return									; YES - done


;=============================================================================
; Check and store an option value in EEPROM
;
	global	option_check_and_store
option_check_and_store:
	rcall	option_read_definition			; read the option definition
	rcall	option_check_loaded				; check if option value is within min/max, set to default if not

option_save_loaded_checked:
	movf	opt_eeprom_bank,W				; get bank
	andlw	b'11111110'						; keep only bits 7-1
	tstfsz	WREG							; bank < 0x02 ?
	return									; NO  - volatile option or illegal address, abort
	tstfsz	opt_eeprom_bank					; YES - bank = 0 ?
	bra		option_save_execute				;       NO  - address is valid
	movlw	low(eeprom_options_storage-1)	;       YES - get start address of options storage minus 1
	cpfsgt	opt_eeprom_index				;           - index >= start address ?
	return									;             NO  - illegal address, abort
	;bra	option_save_execute				;             YES - address is valid

option_save_execute:
	movff	opt_eeprom_index,EEADR			; set EEPROM index (address low  byte)
	movff	opt_eeprom_bank, EEADRH			; set EEPROM page  (address high byte)

	movf	opt_type,W						; get option type
	xorlw	.2								; option type = string ?
	bz		option_save_string				; YES - special handling
	movff	INDF1,EEDATA					; NO  - copy option value to EEPROM write register
	call	write_eeprom					;     - execute write
	return									;     - done

option_save_string:
	movff	POSTINC1,EEDATA					; copy a character from the option value to the EEPROM write register
	btfss	EEADRH,1						; current EEPROM address < 512 ?
	call	write_eeprom					; YES  - execute write
	infsnz	EEADR,F							; increment EEPROM address, low  byte
	incf	EEADRH,F						; increment EEPROM address, high byte
	decfsz	opt_max							; decrement string length, done?
	bra		option_save_string				; NO  - loop
	return									; YES - done


;=============================================================================
; Restore and check all option values from EEPROM
;
	global	option_restore_and_check_all	; restore options from EEPROM
option_restore_and_check_all:
	;---- Read option version from EEPROM
	EEPROM_II_READ	eeprom_options_version,mpr

	movlw	LOW(eeprom_opt_version)			; get options version from current firmware, low  byte
	xorwf	mpr+0,W							; compare with EEPROM version, do they match?
	bnz		option_restore_reset			; NO - reset to defaults of current firmware

	movlw	HIGH(eeprom_opt_version)		; get options version from current firmware, high byte
	xorwf	mpr+1,W							; compare with EEPROM version, do they match?
	bnz		option_restore_reset			; NO  - reset to defaults of current firmware

	;---- restore all option values
	lfsr	FSR0,option_table_begin			; point to start of option definition table
option_restore_all_loop:
	rcall	option_restore_and_check		; restore and check the option
	incfsz	opt_end_token,F					; was this the last option (was opt_end_token = 255) ?
	bra		option_restore_all_loop			; NO  - do next option
	return									; YES - done

option_restore_reset:
	call	option_reset_all				; reset all option values to their default
	goto	option_check_and_store_all		; write back all option values to EEPROM (and return)


;=============================================================================
; Restore an option value from EEPROM and check it
;
	global	option_restore_and_check
option_restore_and_check:
	rcall	option_read_definition			; read the option definition

	movf	opt_eeprom_bank,W				; get bank
	andlw	b'11111110'						; keep only bits 7-1
	tstfsz	WREG							; bank < 0x02 ?
	bra		option_reset_loaded				; NO  - volatile option or illegal address, restore to default
	tstfsz	opt_eeprom_bank					; YES - bank = 0 ?
	bra		option_restore_execute			;       NO  - address is valid
	movlw	low(eeprom_options_storage-1)	;       YES - get start address of options storage minus 1
	cpfsgt	opt_eeprom_index				;           - index >= start address ?
	bra		option_reset_loaded				;             NO  - illegal address, restore to default
	;bra	option_restore_execute			;             YES - address is valid

option_restore_execute:
	movff	opt_eeprom_index,EEADR			; set EEPROM index (address low  byte)
	movff	opt_eeprom_bank, EEADRH			; set EEPROM page  (address high byte)

	movf	opt_type,W						; get option type
	xorlw	.2								; option type = string ?
	bz		option_restore_string			; YES - special handling
	call	read_eeprom						; NO  - execute read
	movff	EEDATA,INDF1					;     - read option value from EEPROM read register
	bcf		option_repaired					;     - clear option repaired flag
	bra		option_check_loaded				;     - check if option value is within min/max, reset to default if not
	btfsc	option_repaired					;     - was the option repaired?
	bra		option_save_loaded_checked		;       YES - save repaired value to EEPROM
	return									;       NO  - done

option_restore_string:
	call	read_eeprom						; read one character from the EEPROM
	movff	EEDATA,POSTINC1					; copy it to the option value
	infsnz	EEADR,F							; increment EEPROM address, low  byte
	incf	EEADRH,F						; increment EEPROM address, high byte
	decfsz	opt_max							; decrement string length, done?
	bra		option_restore_string			; NO  - loop
	return									; YES - done (nothing to check with strings)



;=============================================================================
; Read an option value via RS232
; INPUT:  lo   = serial index
; OUTPUT: hi   = option value
;         WREG =0: option found and value valid, =1: option not found
; TRASH:  TBLPTR, TABLAT, WREG, FSR0, FSR1
;
	global	option_read_serial
option_read_serial:
	lfsr	FSR0,option_table_begin			; point to start of option definition table
option_read_serial_loop:
	rcall	option_read_definition			; read option definition
	movf	opt_serial,W					; get serial index of the option into WREG
	xorwf	lo,W							; received index = index of this option ?
	bz		option_read_serial_execute		; YES - read value
	incfsz	opt_end_token,F					; NO  - was this the last option (was opt_end_token = 255) ?
	bra		option_read_serial_loop			;       NO  - try next option
	retlw	.1								;       YES - done, option not found

option_read_serial_execute:
	movff	INDF1,hi						; read option value into hi
	retlw	.0								; done, option found


;=============================================================================
; Write an option value via RS232
; INPUT:  lo   = serial index
;         hi   = option value
; OUTPUT: WREG =0: option found and value valid, =1: option not found, =2: value not valid
; TRASH:  TBLPTR, TABLAT, WREG, FSR0, FSR1, up
;
	global	option_write_serial
option_write_serial:
	lfsr	FSR0,option_table_begin			; point to start of option definition table
option_write_serial_loop:
	rcall	option_read_definition			; read option definition
	movf	opt_serial,W					; get serial index of the option into WREG
	xorwf	lo,W							; received index = index of this option ?
	bz		option_write_serial_execute		; YES - check and update value
	incfsz	opt_end_token,F					; NO  - was this the last option (was opt_end_token = 255) ?
	bra		option_write_serial_loop		;       NO  - try next option
	retlw	.1								;       YES - done, option not found

option_write_serial_execute:
	movff	INDF1,up						; backup old value
	movff	hi,INDF1						; write  new value
	bcf		option_repaired					; clear option repaired flag
	rcall	option_check_loaded				; check the new value
	btfsc	option_repaired					; was   the new value valid?
	bra		option_write_serial_execute_fail; NO  - restore old value
	bsf		options_changed					; YES - flag that EEPROM needs to be updated
	retlw	.0								;     - done, success
option_write_serial_execute_fail:
	movff	up,INDF1						; restore old value
	retlw	.2								; done, value not valid


;=============================================================================
; Increment an option value based on type and min/max boundary
; INPUT:  FSR0 = option handle
; OUTPUT: none
; TRASH:  TBLPTR, TABLAT, WREG, FSR0, FSR1
;
	global	option_inc						; increment FSR0 option
option_inc:
	; read type, default and register from table
	rcall	option_read_definition

	bsf		options_changed					; flag that EEPROM needs to be updated

	; switch on type
	movf	opt_type,W						; get option type
	bz		option_inc_uint8				; type 0: INT8
	dcfsnz	WREG							; decrement
	bra		option_inc_enum8				; type 1: ENUM
	dcfsnz	WREG							; decrement
	bra		option_inc_string				; type 2: STRING
	;bra	option_inc_uint8				; type 3: INT8

option_inc_uint8:
	movf	INDF1,W							; get option value
	addwf	opt_inc,W						; add increment
	cpfslt	opt_max							; max < option value ?
	bra		option_inc_uint8_0				; NO  - new option value ok
	movf	opt_min,W						; YES - reset to min value
option_inc_uint8_0:
	movwf	INDF1							; store new value
option_inc_uint8_1:
	; now some rather crude hack into this routine to make CCR calibration more convenient:
	movlw	0x37							; serial ID of option CalGasO2
	cpfseq	opt_serial						; editing CalGasO2 right now?
	bra		option_inc_uint8_2				; NO - check next option
	movff	opt_dive_mode,WREG				; YES - get dive mode: 0=OC, 1=CC, 2=Gauge, 3=Apnea, 4=pSCR
	decfsz	WREG,W							;     - in CCR mode?
	return									;       NO  - done
	movlw	.26								;       YES -
	cpfseq	INDF1							;           - option value = 26 ?
	return									;             NO  - done
	movlw	.95								;             YES - advance it to 95
	movwf	INDF1							;                 - store it
	return
option_inc_uint8_2:
	movlw	0x25							; serial ID of option opt_GF_low
	cpfseq	opt_serial						; editing opt_GF_low right now?
	bra		option_inc_uint8_3				; NO - check next option
	movff	opt_GF_high,WREG				; get value of associated GF high into WREG
	cpfsgt	INDF1							; GF low > GF high?
	return									; NO  - setting ok, done
	movff	opt_min,INDF1					; YES - wrap around to minimum value
	return									;     - done
option_inc_uint8_3:
	movlw	0x26							; serial ID of option opt_GF_high
	cpfseq	opt_serial						; editing opt_GF_high right now?
	bra		option_inc_uint8_4				; NO - check next option
	movff	opt_GF_low,WREG					; get value of associated GF low into WREG
	cpfslt	INDF1							; GF high < GF low?
	return									; NO  - setting ok, done
	movwf	INDF1							; YES - rise GF high to GF low
	return									;     - done
option_inc_uint8_4:
	movlw	0x27							; serial ID of option opt_aGF_low
	cpfseq	opt_serial						; editing opt_aGF_low right now?
	bra		option_inc_uint8_5				; NO - check next option
	movff	opt_aGF_high,WREG				; get value of associated GF high into WREG
	cpfsgt	INDF1							; GF low > GF high?
	return									; NO  - setting ok, done
	movff	opt_min,INDF1					; YES - wrap around to minimum value
	return									;     - done
option_inc_uint8_5:
	movlw	0x28							; serial ID of option opt_aGF_high
	cpfseq	opt_serial						; editing opt_aGF_high right now?
	bra		option_inc_uint8_6				; NO - check next option
	movff	opt_aGF_low,WREG				; get value of associated GF low into WREG
	cpfslt	INDF1							; GF high < GF low?
	return									; NO  - setting ok, done
	movwf	INDF1							; YES - rise GF high to GF low
	return									;     - done
option_inc_uint8_6:
	return									; all done


option_inc_enum8:
	movf	opt_max,W						; copy maximum permissible value to WREG
	cpfslt	INDF1							; option value < maximum permissible value ?
	bra		option_inc_enum8_reset			; NO  - reset     option value
	incf	INDF1,F							; YES - increment option value
	bra		option_inc_enum8_1				;     - continue
option_inc_enum8_reset:
	clrf	INDF1							; reset option value to zero

option_inc_enum8_1:
 IFDEF _ccr_pscr
	; now some rather crude hack into this routine to unify CCR & pSCR mode setting
	movlw	0x1F							; serial ID of option oCCRMode
	cpfseq	opt_serial						; editing oCCRMode right now?
	bra		option_inc_enum8_2				; NO  - check next option
 IFDEF _external_sensor
	btfsc	analog_o2_input					; YES - does hosting OSTC have an analog interface?
	bra		option_inc_enum8_1a				;       YES - setting 'sensor' allowed
	btfsc	optical_input					;       does hosting OSTC have an optical interface?
	bra		option_inc_enum8_1a				;       YES - setting 'sensor' allowed
 ENDIF	; _external_sensor
	movf	INDF1,W							;       NO to both - get mode (=0: fixed SP, =1: Sensor, =2: AutoSP)
	xorlw	.1								;                  - in sensor mode?
	bnz		option_inc_enum8_1a				;                    NO  - continue with next check
	incf	INDF1,F							;                    YES - advance option value to AutoSP
option_inc_enum8_1a:
	movff	opt_dive_mode,WREG				; get dive mode: 0=OC, 1=CCR, 2=Gauge, 3=Apnea, 4=pSCR
	xorlw	.4								; in pSCR mode?
	bnz		option_inc_enum8_1_exit			; NO  - done
	bcf		INDF1,1							; YES - clear bit 1 because opt_ccr_mode may only be 0 or 1 (reverts AutoSP to calculated SP)
option_inc_enum8_1_exit:
	return									; done
 ENDIF	; _ccr_pscr

option_inc_enum8_2:
 IFDEF _gas_contingency
	; now some rather crude hack to switch off contingency mode if gas needs calculation is switched off
	movlw	0x5A							; serial ID of option opt_calc_gasvolume
	cpfseq	opt_serial						; editing opt_calc_gasvolume right now?
	bra		option_inc_enum8_3				; NO  - check next option
	movf	INDF1,W							; YES - get option value
;	xorlw	.0								;     - option value = off ?
	bnz		option_inc_enum8_2_exit			;       NO  - done
	clrf	WREG							;       YES - force contingency to be off, too
	movff	WREG,opt_gas_contingency_dive	;           - ...
option_inc_enum8_2_exit:
	return
 ENDIF	; _gas_contingency

option_inc_enum8_3:
	; now some rather crude hack to correct opt_TR_mode in dependency of opt_dive_mode
	movlw	0x20							; serial ID of option opt_dive_mode
	cpfseq	opt_serial						; editing opt_dive_mode right now?
	bra		option_inc_enum8_4				; NO  - check next option
	movf	INDF1,W							; YES - get option value: 0=OC, 1=CCR, 2=Gauge, 3=Apnea, 4=pSCR
	xorlw	.1								;       in CCR mode?
	bnz		option_inc_enum8_3a				;       NO  - in some other mode
 IFNDEF _ccr_pscr
	incf	INDF1,f							;       YES - no CCR mode compiled in, advance to gauge mode
	bra		option_inc_enum8_3a				;           - check if gauge mode is available
 ENDIF	; _ccr_pscr
 IFDEF _rx_functions
	global	option_cleanup_oTrMode_CCR		; embedded clean-up entry-point
option_cleanup_oTrMode_CCR:					; entry point from cleanup during restart
	movff	opt_TR_mode,WREG				; get TR mode
	xorlw	.2								; mode = 2 (ind.double)?
	bnz		option_inc_enum8_3_exit			; NO  - done
	bra		option_inc_enum8_3_reset		; YES - revert mode to 1 (on)
 ENDIF	; _rx_functions
option_inc_enum8_3a:						; any mode other than CCR
 IFNDEF _gauge_mode
	movf	INDF1,W							; get option value: 0=OC, 1=CCR, 2=Gauge, 3=Apnea, 4=pSCR
	xorlw	.2								; in Gauge mode?
	bnz		option_inc_enum8_3b				; NO  - in some other mode
	incf	INDF1,f							;       YES - no Gauge mode compiled in, advance to Apnea mode
	bra		option_inc_enum8_3_exit			;           - done (Apnea mode is always available)
 ENDIF	; _gauge_mode
option_inc_enum8_3b:
 IFNDEF _ccr_pscr
	movf	INDF1,W							; get option value: 0=OC, 1=CCR, 2=Gauge, 3=Apnea, 4=pSCR
	xorlw	.4								; in pSCR mode?
	bnz		option_inc_enum8_3c				; NO  - in some other mode
	clrf	INDF1							; YES - no pSCR mode compiled in, advance to 0 "OC"
	bra		option_inc_enum8_3_exit			;     - done
 ENDIF	; _ccr_pscr
option_inc_enum8_3c:
	global	option_cleanup_oTrMode_no_CCR	; embedded clean-up entry-point
option_cleanup_oTrMode_no_CCR:				; entry point from cleanup during restart
	movff	opt_TR_mode,WREG				; get TR mode
	xorlw	.3								; mode = 3 (CCR Dil+O2)?
	bnz		option_inc_enum8_3_exit			; NO  - done
option_inc_enum8_3_reset:					; YES - revert to mode 1 (on)
	movlw	.1								; load coding of mode "on"
	movff	WREG,opt_TR_mode				; write to option
option_inc_enum8_3_exit:
	return									; done

option_inc_enum8_4:
 IFDEF _rx_functions
	; now some rather crude hack to advance opt_TR_mode in dependency of opt_dive_mode
	movlw	0x7E							; serial ID of option opt_TR_mode
	cpfseq	opt_serial						; editing opt_TR_mode right now?
	bra		option_inc_enum8_5				; NO  - check next option
	movff	opt_dive_mode,WREG				; YES - get dive mode: 0=OC, 1=CCR, 2=Gauge, 3=Apnea, 4=pSCR
	decfsz	WREG,W							;       dive mode = 1 CCR?
	bra		option_inc_enum8_4a				;       NO  - in any other mode
	movf	INDF1,W							;       YES - get option value (TR mode)
	xorlw	.2								;           - mode = 2 (ind.double)?
	bnz		option_inc_enum8_4_exit			;             NO  - done
	incf	INDF1,F							;             YES - advance option value to 3 (CCR Dil+O2)
	bra		option_inc_enum8_4_exit			;                 - done
option_inc_enum8_4a:						; any mode other than CCR
	movf	INDF1,W							; get option value (TR mode)
	xorlw	.3								; mode = 3 (CCR Dil+O2)?
	bnz		option_inc_enum8_4_exit			; NO  - done
	clrf	INDF1							; YES - advance option value to 0 "off"
option_inc_enum8_4_exit:
	return									; done
 ENDIF	; _rx_functions

option_inc_enum8_5:
 IFDEF _gas_contingency
	; now some rather crude hack to keep contingency mode switched off if gas needs calculation is switched off
	movlw	0x91							; serial ID of option opt_gas_contingency_dive
	cpfseq	opt_serial						; editing opt_gas_contingency_dive right now?
	bra		option_inc_enum8_6				; NO  - check next option
	movff	opt_calc_gasvolume,WREG			; YES - get current setting of gas needs calculation
	tstfsz	WREG							;     - gas needs calculation switched off?
	return									;       NO  - done, opt_gas_contingency_dive may be switched on
	clrf	INDF1							;       YES - force opt_gas_contingency_dive to off
	return									;           - done
 ENDIF	; _gas_contingency

option_inc_enum8_6:
	return


option_inc_string:							; no editing available
	return


 IFNDEF _gauge_mode
option_cleanup_gauge:
	movff	opt_dive_mode,WREG				; get dive mode into WREG (0=OC, 1=CCR, 2=Gauge, 3=Apnea, 4=pSCR)
	xorlw	.2								; in Gauge mode?
	bnz		option_cleanup_gauge_1			; NO  - done
	movff	WREG,opt_dive_mode				; YES - setting not allowed, WREG is zero -> reset to OC mode
	bsf		options_changed					;     - flag that EEPROM needs to be updated
option_cleanup_gauge_1:
	return									; done
 ENDIF


 IFDEF _ccr_pscr
	global	option_cleanup_oCCRMode
	global	option_cleanup_oCCRMode_pSCR
	global	option_cleanup_oCCRMode_CCR
option_cleanup_oCCRMode:					; in pSCR mode, revert AutoSP (2) to calculated SP (0), in pSCR and CCR revert Sensor to fixed SP if no sensor interface available
	movff	opt_dive_mode,WREG				; get dive mode into WREG (0=OC, 1=CCR, 2=Gauge, 3=Apnea, 4=pSCR)
	xorlw	.4								; in pSCR mode?
	bnz		option_cleanup_oCCRMode_CCR		; NO  - check if sensor is available on hosting OSTC
option_cleanup_oCCRMode_pSCR:				; jump-in from start.asm if known to be in pSCR mode
	banksel	opt_ccr_mode					; YES - select options bank
	bcf		opt_ccr_mode,1					;     - clear bit 1 because opt_ccr_mode may only be 0 or 1 (reverts AutoSP to calculated SP, keeps sensor)
	banksel	common							;     - back to bank common
	bsf		options_changed					;     - flag that EEPROM needs to be updated
option_cleanup_oCCRMode_CCR:				; continue from above & jump-in from start.asm if known to be in CCR mode
 IFDEF _external_sensor
	btfsc	analog_o2_input					; analog interface available?
	return									; YES - setting 'sensor' allowed
	btfsc	optical_input					; does hosting OSTC have an optical interface?
	return									; YES - setting 'sensor' allowed
 ENDIF
	movff	opt_ccr_mode,WREG				; NO to both - get CCR mode
	xorlw	.1								;            - coding for sensor
	tstfsz	WREG							;            - CCR mode = sensor?
	return									;              NO  - setting allowed
	banksel	opt_ccr_mode					;              YES - setting not allowed, select options bank
	clrf	opt_ccr_mode					;                  - revert setting to 0 (fixed or calculated SP)
	banksel	common							;                  - back to bank common
	bsf		options_changed					;                  - flag that EEPROM needs to be updated
	return									;                  - done
 ENDIF	; _ccr_pscr


option_cleanup_GF:
	; cleanup normal GF
	movff	opt_GF_high,WREG				; copy normal GF high to WREG
	movff	opt_GF_low,mpr					; copy normal GF low  to mpr
	cpfsgt	mpr								; GF low > GF high ?
	bra		option_cleanup_GF_2				; NO  - option ok, check next option
	movwf	mpr								; YES - copy GF high to mpr
	movlw	.100							;     - load GF low limit of 100% into WREG
	cpfsgt	mpr								;     - mpr > 100 ?
	bra		option_cleanup_GF_1				;       NO  - correct GF low to GF high
	movwf	mpr								;       YES - correct GF low to 100%
option_cleanup_GF_1:
	movff	mpr,opt_GF_low					; store corrected GF low
	bsf		options_changed					; flag that EEPROM needs to be updated
option_cleanup_GF_2:
	; cleanup alternative GF
	movff	opt_aGF_high,WREG				; copy alternative GF high to WREG
	movff	opt_aGF_low,mpr					; copy alternative GF low  to mpr
	cpfsgt	mpr								; GF low > GF high ?
	bra		option_cleanup_GF_4				; NO  - option ok, check next option
	movwf	mpr								; YES - copy GF high to mpr
	movlw	.100							;     - load GF low limit of 100% into WREG
	cpfsgt	mpr								;     - mpr > 100 ?
	bra		option_cleanup_GF_3				;       NO  - correct GF low to GF high
	movwf	mpr								;       YES - correct GF low to 100%
option_cleanup_GF_3:
	movff	mpr,opt_aGF_low					; store corrected GF low
	bsf		options_changed					; flag that EEPROM needs to be updated
option_cleanup_GF_4:
	return									; done


;=============================================================================
; Strcat option into FSR2 buffer
;
	global	option_draw						; STRCAT FRS0 option
option_draw:
	; read type, default and register from table
	rcall	option_read_definition

	; switch on type
	movf	opt_type,W						; get option type
	bz		option_draw_uint8				; type0 = INT8
	dcfsnz	WREG
	bra		option_draw_enum8				; type1 = ENUM
	dcfsnz	WREG
	bra		option_draw_string				; type2 = string
	dcfsnz	WREG
	bra		option_draw_uint8_depth			; type3 = INT8 with automatic display in meters or feet
	return									; unknown, do nothing

option_draw_string:
	movff	POSTINC1,POSTINC2
	decfsz	opt_max
	bra		option_draw_string
	return

option_draw_uint8_depth:
	TSTOSS	opt_units						; using metric units (0=m, 1=ft)?
	bra		option_draw_uint8				; YES - handle with standard output
	movff	INDF1,lo						; NO  - imperial, get value to lo
	call	convert_meter_to_feet			;     - convert value in lo from meter to feet
	bsf		leftbind						;     - print with left alignment
	output_16_3								;     - display only last three digits from a 16 bit value (0-999)
	bcf		leftbind						;     - back to normal alignment
	STRCAT_TEXT	tFeets						;     - print unit
	bra		option_draw_uint8_common		;     - continue with common part

option_draw_uint8:
	movff	INDF1,lo						; draw value
	bsf		leftbind
	output_8
	bcf		leftbind
	clrf	INDF2							; make sure to close string
	movf	opt_unit+0,W					; is there a unit to append?
	iorwf	opt_unit+1,W
	rcall	option_draw_unit				; YES
option_draw_uint8_common:
	movf	opt_default,W					; get default value
	cpfseq	lo								; compare with current value, equal?
	bra		option_draw_uint8_2				; NO  - not default, add *
	return									; YES - default, done
option_draw_uint8_2:
	PUTC	"*"								; print "*"
	return									; done

option_draw_unit:
	movff	opt_unit+0,FSR1L
	movff	opt_unit+1,FSR1H
	goto	strcat_text


;---- Draw an enumerated value (set of translated strings)
option_draw_enum8:
	movf	INDF1,W							; copy option value to WREG
	movwf	lo								; memorize option value, too
	cpfslt	opt_max							; option value > maximum permissible value ?
	bra		option_draw_enum8_0				; NO  - option value allowed
	clrf	WREG							; YES - to avoid printing rubbish, use first ENUM item instead
option_draw_enum8_0:
	addwf	WREG							; current value *= 2
	addwf	opt_inc,W						; base text + 2 * current value
	movwf	FSR1L							; load FSR1
	movlw	.0								; propagate carry...
	addwfc	opt_min,W						; ...
	movwf	FSR1H							; ...into FSR1
	call	strcat_text						; print text
	movf	opt_default,W					; get default value
	cpfseq	lo								; compare with memorized current value, equal?
	bra		option_draw_enum8_1				; NO  - not default, add *
	return									; YES - default, done
option_draw_enum8_1:
	PUTC	"*"								; print "*"
	return									; done

;-----------------------------------------------------------------------------

	END
