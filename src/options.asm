;=============================================================================
;
;   File options.asm                        * next combined generation V3.09.4n
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


;=============================================================================
options1	CODE
;=============================================================================


;-----------------------------------------------------------------------------
; Adjust Address in FSR0 to an Option within an Option Group
;
; INPUT:  FSR0        = base address of the option group
;         gaslist_gas = offset of the selected option within the group
; OUTPUT: FSR0        = pointing to selected option
;
	global	option_adjust_group_member
option_adjust_group_member:
	movf	gaslist_gas,W					; get       offset in number of options
	mullw	opt_definition_bytes			; calculate offset in number of bytes
	movf	PRODL,W							; get number of bytes, low  byte
	addwf	FSR0L,F							; add to FSR0,         low  byte
	movf	PRODH,W							; get number of bytes, high byte
	addwfc	FSR0H,F							; add to FSR0,         high byte
	return									; done


;-----------------------------------------------------------------------------
; Read the Option Definition
;
; INPUT:  FSR0 = option handle
; OUTPUT: FSR1 = address of variable.
; TRASH:  TBLPTR, TABLAT, WREG, FSR0, FSR1
;
option_read_definition:
	; option_table_begin is at 0x0|80|00
	clrf	TBLPTRU							; TBLPRT upper = 0x00
	movlw	HIGH(option_table_begin)		; TBLPRT high  = 0x80
	iorwf	FSR0H,W							;              + 0x0H from FSR0H
	movwf	TBLPTRH							;            set 0x8H
	movff	FSR0L,TBLPTRL					; TBLPRT low   = 0xLL from FSR0L
	; copy option definition from program to data memory
	lfsr	FSR1,opt_type					; load FSR1 with base address of option definition buffer
	movlw	opt_definition_bytes			; get number of bytes to copy
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


;-----------------------------------------------------------------------------
; Reset all Options to Factory Defaults
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


;-----------------------------------------------------------------------------
; Reset an Option to its default Value
;
; INPUT:  FSR0 = option handle
; OUTPUT: option value set to default value
;         option_repaired flag set
;         option_changed flag set if not a volatile option
; TRASH:  TBLPTR, TABLAT, WREG, FSR1, FSR2
;
	global	option_reset					; reset option value to default
option_reset:
	; read type, default and register from table
	rcall	option_read_definition			; read option definition
	btfss	opt_eeprom_bank,7				; volatile option?
	bsf		option_changed					; NO  - flag that EEPROM needs to be updated
	;bra	option_init_loaded				; continue initializing the option value


;-----------------------------------------------------------------------------
; Reset an Option to its default Value
;
; INPUT:  opt_* option definition vars initialized
; OUTPUT: option value set to default value
; TRASH:  TBLPTR, TABLAT, WREG, FSR1, FSR2
;
option_init_loaded:
	movf	opt_type,W						; get option type
	xorlw	.2								; type = STRING ?
	bz		opt_init_loaded_string			; YES - string copy
	movff	opt_default,INDF1				; NO  - 1 byte copy
	return									;     - done

opt_init_loaded_string:
	movff	TBLPTRL,mpr+0					; back-up TBLPTR
	movff	TBLPTRH,mpr+1					; ...
	movff	TBLPTRU,mpr+2					; ...

	movff	FSR1L,FSR2L						; set string destination address
	movff	FSR1H,FSR2H						; ...
	movff	opt_inc,FSR1L					; get pointer to multi-lingual default text (stored in opt_inc:opt_min)
	movff	opt_min,FSR1H					; ...
	call	strcat_text_FSR					; copy translated text to FSR2, hence string option

	movff	mpr+0,TBLPTRL					; restore TBLPTR
	movff	mpr+1,TBLPTRH					; ...
	movff	mpr+2,TBLPTRU					; ...

	return									; done


;-----------------------------------------------------------------------------
; Check one Option and reset its Value if it is out of its min/max Limits
;
; INPUT:  opt_* vars loaded, FSR1 pointing to option value
;         hi    value to be checked for validity
; OUTPUT: option_value_ok set/not set
; TRASH:  WREG
;
	global	option_check_loaded
option_check_loaded:
	; switch on type
	bsf		option_value_ok					; set result to ok by default
	movf	opt_type,W						; get type
	bz		option_check_uint8				; type 0: INT8
	dcfsnz	WREG							; decrement
	bra		option_check_enum8				; type 1: ENUM
	dcfsnz	WREG							; decrement
	return									; type 2: STRING - nothing to check
	;bra	option_check_uint8				; type 3: INT8

option_check_uint8:
	tstfsz	opt_min							; opt_min = 0 ?
	bra		option_check_min				; NO  - check it
	bra		option_check_enum8				; YES - continue with check for maximum

option_check_min:
	decf	opt_min,W						; get (minimum permissible value - 1) into WREG
	cpfsgt	hi								; option value > (minimum permissible value - 1) ?
	bra		option_check_nok				; NO  - value not ok
	;bra	option_check_enum8				; YES - continue with check for maximum

option_check_enum8:
	infsnz	opt_max,W						; get (highest permissible value + 1) into WREG
	return									; highest permissible value is 255, skip check, done
	cpfslt	hi								; option value < (highest permissible value + 1) ?
	bra		option_check_nok				; NO  - value not ok
	return									; YES - value ok, done

option_check_nok:
	bcf		option_value_ok					; flag option value is invalid
	return									; done


;-----------------------------------------------------------------------------
; Check and store all Option Values to EEPROM
;
	global	option_check_and_store_all
option_check_and_store_all:
	bcf		PIR3,RC2IE						; disable EUSART interrupts								TODO: why???
	call	option_crosschecks				; do some crosschecks between option values
	;bra	option_store_all				; continue storing all option values to EEPROM


;-----------------------------------------------------------------------------
; Store all Option Values to EEPROM
;
option_store_all:
	;---- invalidate option version while updating
	CLRI	mpr									; set options version number to zero
	EEPROM_II_WRITE mpr,eeprom_options_version	; store options version number in EEPROM

	;---- check and store all option values
	lfsr	FSR0,option_table_begin			; point to start of option definition table
option_save_all_loop:
	rcall	option_check_and_store			; check and store option value
	incfsz	opt_end_token,F					; was this the last option (was opt_end_token = 255) ?
	bra		option_save_all_loop			; NO  - do next option

	;---- store option version
	MOVLI	eeprom_opt_version,mpr				; get   options version number
	EEPROM_II_WRITE mpr,eeprom_options_version	; store options version number in EEPROM

	bcf		option_changed					; no pending EEPROM updates any more
	return									; done


;-----------------------------------------------------------------------------
; Check and store one Option Value to EEPROM
;
	global	option_check_and_store
option_check_and_store:
	rcall	option_read_definition			; read the option definition
	movff	INDF1,hi						; check current option value
	rcall	option_check_loaded				; check value for validity
	btfss	option_value_ok					; value ok (strings are always 'valid') ?
	movff	opt_default,INDF1				; NO  - set value to default
	;bra	option_store_loaded				; continue storing value


;-----------------------------------------------------------------------------
; Store one Option Value to EEPROM
;
	global	option_store_loaded
option_store_loaded:
	movf	opt_eeprom_bank,W				; get bank
	andlw	b'11111110'						; keep only bits 7-1
	tstfsz	WREG							; bank < 0x02 ?
	return									; NO  - volatile option or illegal address, done/abort
	tstfsz	opt_eeprom_bank					; YES - bank = 0 ?
	bra		option_store_execute			;       NO  - address is valid in any case
	movlw	low(eeprom_options_storage-1)	;       YES - get start address of options storage minus 1
	cpfsgt	opt_eeprom_index				;           - index >= start address ?
	return									;             NO  - illegal address, done
	;bra	option_store_execute			;             YES - address is valid

option_store_execute:
	movff	opt_eeprom_index,EEADR			; set EEPROM index (address low  byte)
	movff	opt_eeprom_bank, EEADRH			; set EEPROM page  (address high byte)

	movf	opt_type,W						; get option type
	xorlw	.2								; option type = string ?
	bz		option_store_exec_string		; YES - store string of bytes
	;bnz	option_store_exec_byte			; NO  - store single    byte

option_store_exec_byte:
	call	read_eeprom						; read stored value
	movf	EEDATA,W						; copy stored value to WREG
	xorwf	INDF1,W							; xor with current value
	btfsc	STATUS,Z						; equal?
	return									; YES - no need to write to EEPROM, done
	movff	INDF1,EEDATA					; NO  - copy current option value to EEPROM write register
	goto	write_eeprom					;     - execute write and return

option_store_exec_string:
	btfss	EEADRH,1						; current EEPROM address < 512 ?
	rcall	option_store_exec_byte			; YES - store one byte from the string
	movf	POSTINC1,W						; increment FSR1   address by a dummy read
	infsnz	EEADR,F							; increment EEPROM address, low  byte
	incf	EEADRH,F						; increment EEPROM address, high byte
	decfsz	opt_max							; decrement string length, done?
	bra		option_store_exec_string		; NO  - loop
	return									; YES - done


;-----------------------------------------------------------------------------
; Restore all Option Values from EEPROM and check them
;
	global	option_restore_and_check_all
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

	bcf		option_changed					; clear flag
	call	option_crosschecks				; do some crosschecks between option values
	btfsc	option_changed					; found and corrected errors?
	bra		option_store_all				; YES - write back corrected data to EEPROM
	return									; NO  - done

option_restore_reset:
	call	option_reset_all				; reset all option values to their default
	goto	option_check_and_store_all		; write back all option values to EEPROM (and return)


;-----------------------------------------------------------------------------
; Restore one Option Value from EEPROM and check it
;
	global	option_restore_and_check
option_restore_and_check:
	rcall	option_read_definition			; read the option definition

	movf	opt_eeprom_bank,W				; get bank
	andlw	b'11111110'						; keep only bits 7-1
	tstfsz	WREG							; bank < 0x02 ?
	bra		option_init_loaded				; NO  - volatile option or illegal address, initialize to default
	tstfsz	opt_eeprom_bank					; YES - bank = 0 ?
	bra		option_restore_execute			;       NO  - address is valid in any case
	movlw	low(eeprom_options_storage-1)	;       YES - get start address of options storage minus 1
	cpfsgt	opt_eeprom_index				;           - index >= start address ?
	bra		option_init_loaded				;             NO  - illegal address, initialize to default
	;bra	option_restore_execute			;             YES - address is valid

option_restore_execute:
	movff	opt_eeprom_index,EEADR			; set EEPROM index (address low  byte)
	movff	opt_eeprom_bank, EEADRH			; set EEPROM page  (address high byte)

	movf	opt_type,W						; get option type
	xorlw	.2								; option type = string ?
	bz		option_restore_exec_string		; YES - special handling
	call	read_eeprom						; NO  - execute   EEPROM read
	movff	EEDATA,INDF1					;     - copy from EEPROM read register to option variable
	movff	EEDATA,hi						;     - check loaded option value
	rcall	option_check_loaded				;     - check if option value is within min/max limits
	btfsc	option_value_ok					;     - option value ok (strings will always be 'ok') ?
	return									;       YES  - done
	movff	opt_default,INDF1				;       NO   - set option value to default
	movff	INDF1,EEDATA					;            - copy repaired value to EEPROM write register
	goto	write_eeprom					;            - execute write and return

option_restore_exec_string:
	call	read_eeprom						; read one character from the EEPROM
	movff	EEDATA,POSTINC1					; copy it to the option value
	infsnz	EEADR,F							; increment EEPROM address, low  byte
	incf	EEADRH,F						; increment EEPROM address, high byte
	decfsz	opt_max							; decrement string length, done?
	bra		option_restore_exec_string		; NO  - loop
	return									; YES - done (nothing to check with strings)



;-----------------------------------------------------------------------------
; Read an Option Value via serial Index
;
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
	retlw	.1								;       YES - option not found, abort

option_read_serial_execute:
	movff	INDF1,hi						; read option value into hi
	retlw	.0								; done


;-----------------------------------------------------------------------------
; Write an Option Value via serial Index
;
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
	retlw	.1								;       YES - option not found, abort

option_write_serial_execute:
	rcall    option_check_loaded                ; check if new value is valid
        btfss    option_value_ok                    ; value valid?
        bra      option_write_serial_invalid        ; NO
        movff    hi,INDF1                           ; YES - take new value
        btfss    opt_eeprom_bank,7                  ;     - volatile option?
        bsf        option_changed                   ;       NO  - flag that EEPROM needs to be updated
        retlw    .0                                 ;     - done

option_write_serial_invalid:
	movlw    0x32                               ; load serial id of the language option (oLanguage)
	cpfseq    lo                                ; option to write = language option ?
	retlw    .2                                 ; NO  - value not valid, abort
	retlw    .0                                 ; YES - value not valid, but silently ignore


;-----------------------------------------------------------------------------
; Increment an Option Value based on Type and min/max Boundary
;
; INPUT:  FSR0 = option handle
; OUTPUT: incremented option value
; TRASH:  TBLPTR, TABLAT, WREG, FSR0, FSR1
;
	global	option_inc
option_inc:
	; read type, default and register from table
	rcall	option_read_definition

	btfss	opt_eeprom_bank,7				; volatile option?
	bsf		option_changed					; NO  - flag that EEPROM needs to be updated

	; switch on type
	movf	opt_type,W						; get option type
	bz		option_inc_uint8				; type 0: UINT8
	dcfsnz	WREG							; decrement
	bra		option_inc_enum8				; type 1: ENUM
	dcfsnz	WREG							; decrement
	return									; type 2: STRING - no inc function defined
	dcfsnz	WREG							; decrement
	bra		option_inc_uint8				; type 3: UINT8 as meters or feet
	return									; unknown, do nothing


;-----------------------------------------------------------------------------
; Helper Function - increment UINT8, wrap-around or stop at option max
;
option_inc_uint8:
	movf	INDF1,W							; get option value
	addwf	opt_inc,W						; add increment
	cpfslt	opt_max							; option value > max ?
	bra		option_inc_uint8_0				; NO  - new option value ok
	movf	opt_min,W						; YES - reset to min value by default
	btfsc	option_stop_at_max				;     - shall the option value stop at max?
	movf	opt_max,W						;       YES - keep at max value
option_inc_uint8_0:
	movwf	INDF1							; store new value
	; do cross-checks with other option values
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
	; check GF low <= GF high
	movlw	0x25							; serial ID of option opt_GF_low
	cpfseq	opt_serial						; editing opt_GF_low right now?
	bra		option_inc_uint8_3				; NO - check next option
	movff	opt_GF_high,WREG				; get value of associated GF high into WREG
	cpfsgt	INDF1							; GF low > GF high?
	return									; NO  - setting ok, done
	movff	opt_min,INDF1					; YES - wrap around to minimum value
	return									;     - done

option_inc_uint8_3:
	; check GF high >= GF low
	movlw	0x26							; serial ID of option opt_GF_high
	cpfseq	opt_serial						; editing opt_GF_high right now?
	bra		option_inc_uint8_4				; NO - check next option
	movff	opt_GF_low,WREG					; get value of associated GF low into WREG
	cpfslt	INDF1							; GF high < GF low?
	return									; NO  - setting ok, done
	movwf	INDF1							; YES - rise GF high to GF low
	return									;     - done

option_inc_uint8_4:
	; check aGF low <= aGF high
	movlw	0x27							; serial ID of option opt_aGF_low
	cpfseq	opt_serial						; editing opt_aGF_low right now?
	bra		option_inc_uint8_5				; NO - check next option
	movff	opt_aGF_high,WREG				; get value of associated GF high into WREG
	cpfsgt	INDF1							; GF low > GF high?
	return									; NO  - setting ok, done
	movff	opt_min,INDF1					; YES - wrap around to minimum value
	return									;     - done

option_inc_uint8_5:
	; check aGF high >= aGF low
	movlw	0x28							; serial ID of option opt_aGF_high
	cpfseq	opt_serial						; editing opt_aGF_high right now?
	bra		option_inc_uint8_6				; NO - check next option
	movff	opt_aGF_low,WREG				; get value of associated GF low into WREG
	cpfslt	INDF1							; GF high < GF low?
	return									; NO  - setting ok, done
	movwf	INDF1							; YES - rise GF high to GF low
	return									;     - done

option_inc_uint8_6:
	; progressive increment for char_I_SAC_work
	movlw	0x3C							; serial ID of option char_I_SAC_work
	cpfseq	opt_serial						; editing char_I_SAC_work right now?
	bra		option_inc_uint8_7				; NO  - check next option
	movlw	.40								; YES - set threshold for incrementing in steps of 2
	cpfsgt	INDF1							;     - option value > threshold ?
	return									;       NO  - done
	incf	INDF1,F							;       YES - increment one more time
	return									;           - done

option_inc_uint8_7:
 IFDEF _helium
	; check O2% + He% <= 100%
	movlw	0xFA							; serial ID of O2% options
	cpfseq	opt_serial						; editing a O2% right now?
	bra		option_inc_uint8_7a				; NO  - check for He%
	movlw	.2*NUM_GAS						; YES - load offset between O2% and He% for gas/dil 1-5
	btfsc	opt_eeprom_bank,7				;     - volatile option?
	movlw	.1								;       YES - load offset between O2% and He% for gas 6
	bra		option_inc_uint8_7b				;       continue with common part
option_inc_uint8_7a:
	movlw	0xFB							; serial ID of He% options
	cpfseq	opt_serial						; editing a He% right now?
	bra		option_inc_uint8_8				; NO  - check next option
	movlw	-.2*NUM_GAS						; YES - load offset between He% and O2% for gas/dil 1-5
	btfsc	opt_eeprom_bank,7				;     - volatile option?
	movlw	-.1								;       YES - load offset between He% and O2% for gas 6
option_inc_uint8_7b:
	movff	PLUSW1,hi						;     - copy complementing gas % to hi
	movf	INDF1,W							;     - copy primary       gas % to WREG
	addwf	hi,F							;     - hi = O2% + He%
	movlw	.101							;     - load max allowed sum + 1
	cpfslt	hi								;     - O2% + He% < 101 ?
	decf	INDF1,F							;       NO - decrement primary gas% again
 ENDIF	; _helium

option_inc_uint8_8
	; add more cross-checks with other option values here
	return									; all done


;-----------------------------------------------------------------------------
; Helper Function - increment ENUM, will wrap-around on exceeding option max
;
option_inc_enum8:
	incf	INDF1,W							; get incremented option value
	cpfslt	opt_max							; option value > max?
	bra		option_inc_enum8_0				; NO  - new option value ok
	clrf	WREG							; YES - reset to 1st option value
option_inc_enum8_0:
	movwf	INDF1							; store new value
	; do cross-checks with other option values
option_inc_enum8_1:
 IFDEF _ccr_pscr
	; now some rather crude hack into this routine to unify CCR & pSCR mode setting
	movlw	0x1F							; serial ID of option oCCRMode
	cpfseq	opt_serial						; editing oCCRMode right now?
	bra		option_inc_enum8_2				; NO  - check next option
 IFDEF _external_sensor
	btfsc	ext_input_s8_ana				; YES - S8/analog input available?
	bra		option_inc_enum8_1a				;       YES - setting 'sensor' allowed
	btfsc	ext_input_optical				;     - optical interface available?
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
	;xorlw	.0								;     - option value = off ?
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
	; add more cross-checks with other option values here
	return


;-----------------------------------------------------------------------------
; Decrement an Option Value based on Type and min/max Boundary
;
; INPUT:  FSR0 = option handle
; OUTPUT: decremented option value
; TRASH:  TBLPTR, TABLAT, WREG, FSR0, FSR1
;
	global	option_dec
option_dec:
	; read type, default and register from table
	rcall	option_read_definition

	btfss	opt_eeprom_bank,7				; volatile option?
	bsf		option_changed					; NO  - flag that EEPROM needs to be updated

	; switch on type
	movf	opt_type,W						; get option type
	bz		option_dec_uint8				; type 0: UINT8
	dcfsnz	WREG							; decrement
	bra		option_dec_enum8				; type 1: ENUM
	dcfsnz	WREG							; decrement
	return									; type 2: STRING  - no dec function defined
	dcfsnz	WREG							; decrement
	bra		option_dec_uint8				; type 3: UINT8 as meters or feet
	return									; unknown, do nothing


;-----------------------------------------------------------------------------
; Helper Function - decrement UINT8, will stop on reaching option min
;
option_dec_uint8:
	movf	INDF1,W							; get option value
	bsf		STATUS,C						; set carry (= clear borrow)
	subfwb	opt_inc,W						; subtract increment
	bnc		option_dec_uint8_reset			; under-run? -> reset
	cpfsgt	opt_min							; option value < min ?
	bra		option_dec_uint8_0				; NO  - new option value ok
option_dec_uint8_reset:
	movf	opt_min,W						; YES - reset to min value
option_dec_uint8_0:
	movwf	INDF1							; store new value
	; add cross-checks with other option values here
	return									; done


;-----------------------------------------------------------------------------
; Helper Function - decrement ENUM, will stop on reaching first option value
;
option_dec_enum8:
	tstfsz	INDF1							; option value = 0 ?
	decf	INDF1,F							; NO - decrement value
option_dec_enum8_0:
	; add cross-checks with other option values here
	return									; done


;-----------------------------------------------------------------------------
; Draw an Option Value
;
	global	option_draw
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
	bra		option_draw_uint8_depth			; type3 = INT8 as meters or feet
	return									; unknown, do nothing


;-----------------------------------------------------------------------------
; Helper Function - draw a String
;
option_draw_string:
	movff	POSTINC1,POSTINC2				; copy one character
	decfsz	opt_max							; decrement remaining string length, became zero?
	bra		option_draw_string				; NO  - loop
	return									; YES - done


;-----------------------------------------------------------------------------
; Helper Function - draw an INT with automatic display in meters or feet
;
option_draw_uint8_depth:
	TSTOSS	opt_units						; using metric units (0=m, 1=ft)?
	bra		option_draw_uint8				; YES - handle with standard output
	movff	INDF1,lo						; NO  - imperial, get value to lo
	call	convert_meter_to_feet			;     - convert value in lo from meter to feet
;	bsf		leftbind						;     - print with left alignment
	output_999								;     - print depth (0-999)
	STRCAT_TEXT	tFeets						;     - append unit and dump to screen
	bra		option_draw_uint8_common		;     - continue with common part


;-----------------------------------------------------------------------------
; Helper Function - draw an INT
;
option_draw_uint8:
	movff	INDF1,lo						; get option value

	movlw	.99								; load a 99
	cpfsgt	opt_max							; max value > 99 ?
	bsf		hide_digit3						; NO - do not show digit 3
	movlw	.9								; load a 9
	cpfsgt	opt_max							; max value > 9 ?
	bsf		hide_digit2						; NO  - do not show digit 2

	output_256								; print option value

	movf	opt_unit+0,W					; is there a unit to append?
	iorwf	opt_unit+1,W					; ...
	bz		option_draw_uint8_common		; NO  - continue with common part
	movff	opt_unit+0,FSR1L				; YES - pointer to multi-lingual unit text
	movff	opt_unit+1,FSR1H				;     - ...
	call	strcat_text_FSR					;     - append unit text to buffer
	;bra	option_draw_uint8_common		;     - continue with common part


;-----------------------------------------------------------------------------
; Helper Function - common Part for INT
;
option_draw_uint8_common:
	movf	opt_default,W					; get default value
	cpfseq	lo								; compare with current value, equal?
	bra		option_draw_uint8_common_1		; NO  - not default, add *
	return									; YES - default, done
option_draw_uint8_common_1:
	PUTC	"*"								; print "*"
	return									; done


;-----------------------------------------------------------------------------
; Helper Function - draw an ENUM (set of translated strings)
;
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
	call	strcat_text_FSR					; print text
	movf	opt_default,W					; get default value
	cpfseq	lo								; compare with memorized current value, equal?
	bra		option_draw_enum8_1				; NO  - not default, add *
	return									; YES - default, done
option_draw_enum8_1:
	PUTC	"*"								; print "*"
	return									; done


;=============================================================================
options2	CODE
;=============================================================================


;-----------------------------------------------------------------------------
; Check and Resolve some Interdependencies among Option Values
;
option_crosschecks:
	bsf		is_diluent_menu					; setup checking diluents
	call	gaslist_cleanup_list			; check and correct multiple or none First diluents

	bcf		is_diluent_menu					; setup checking gases
	call	gaslist_cleanup_list			; check and correct multiple or none First gases

	rcall	option_cleanup_GF				; check and correct GFlow <= GFhigh

 IFNDEF _gauge_mode
	rcall	option_cleanup_gauge			; check and correct gauge mode
 ENDIF	; _gauge_mode

 IFDEF _ccr_pscr
	rcall	option_cleanup_oCCRMode			; check and correct CCR / pSCR mode
 ENDIF	; _ccr_pscr

 IFDEF _helium
	rcall	option_cleanup_sum_O2_He		; check and correct O2% + He% <= 100  +++
 ENDIF	; _helium

	return									; done


;-----------------------------------------------------------------------------
; Check and correct GFs so that GF_high >= GF_low
;
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
	bsf		option_changed					; flag that EEPROM needs to be updated
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
	bsf		option_changed					; flag that EEPROM needs to be updated
option_cleanup_GF_4:
	return									; done

;-----------------------------------------------------------------------------
; Check and correct Dive Mode if Gauge Mode is not allowed
;
 IFNDEF _gauge_mode
option_cleanup_gauge:
	movff	opt_dive_mode,WREG				; get dive mode into WREG (0=OC, 1=CCR, 2=Gauge, 3=Apnea, 4=pSCR)
	xorlw	.2								; in Gauge mode?
	bnz		option_cleanup_gauge_1			; NO  - done
	movff	WREG,opt_dive_mode				; YES - setting not allowed, WREG is zero -> reset to OC mode
	bsf		option_changed					;     - flag that EEPROM needs to be updated
option_cleanup_gauge_1:
	return									; done
 ENDIF	; _gauge_mode


;-----------------------------------------------------------------------------
; Check and correct AutoSP and external Sensor Settings dependent on Modes
;
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
	bsf		option_changed					;     - flag that EEPROM needs to be updated
option_cleanup_oCCRMode_CCR:				; continue from above & jump-in from start.asm if known to be in CCR mode
 IFDEF _external_sensor
	btfsc	ext_input_s8_ana				; S8/analog interface available?
	return									; YES - setting 'sensor' allowed
	btfsc	ext_input_optical				; does hosting OSTC have an optical interface?
	return									; YES - setting 'sensor' allowed
 ENDIF	; _external_sensor
	movff	opt_ccr_mode,WREG				; NO to both - get CCR mode
	xorlw	.1								;            - coding for sensor
	tstfsz	WREG							;            - CCR mode = sensor?
	return									;              NO  - setting allowed
	banksel	opt_ccr_mode					;              YES - setting not allowed, select options bank
	clrf	opt_ccr_mode					;                  - revert setting to 0 (fixed or calculated SP)
	banksel	common							;                  - back to bank common
	bsf		option_changed					;                  - flag that EEPROM needs to be updated
	return									;                  - done
 ENDIF	; _ccr_pscr


;-----------------------------------------------------------------------------
; Check and correct that O2% + He% <= 100%
;
 IFDEF _helium
option_cleanup_sum_O2_He:
	lfsr	FSR0,opt_gas_He_ratio-1		; load (base address of He% array - 1) because of PREINC
	movlw	2*NUM_GAS					; load loop counter
	movwf	lo							; ...
option_cleanup_sum_loop:
	movff	PREINC1,up					; get He ratio
	movlw	-2*NUM_GAS					; address O2 ratio
	movff	PLUSW0,hi					; get O2 ratio
	movlw	.100						; load WREG with 100%
	bsf		STATUS,C					; set carry = clear borrow
	subfwb	hi,W						; subtract O2% from WREG
	subfwb	up,W						; subtract He% from WREG
	btfsc	STATUS,C					; result negative?
	bra		option_cleanup_sum_loop_1	; NO  - sum valid
	clrf	INDF1						; YES - heal by setting He% to zero
	bsf		option_changed				; flag that EEPROM needs to be updated
option_cleanup_sum_loop_1:
	decfsz	lo							; decrement loop counter, all done?
	bra		option_cleanup_sum_loop		; NO  - loop
	return								; YES - done
 ENDIF	; _helium


;-----------------------------------------------------------------------------

	END
