;=============================================================================
;
;   File options.asm                          next combined generation V3.04.3
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
	extern	eeprom_serial_save,eeprom_opt_backup
	extern	option_table_begin,option_table_end
	extern	convert_meter_to_feet

options		CODE

;=============================================================================
; Reset all options to factory defaults
;
; INPUT:  none
; OUTPUT: none
; TRASH:  TBLPTR, TABLAT, WREG, FSR0, FSR1, FSR2
;
	global	option_reset_all				; reset all options to factory default
option_reset_all:
	clrf	EEADRH
	read_int_eeprom .2
	tstfsz	EEDATA							; number of total dives = 0 ?
	bra		option_reset_all2				; NO - skip resetting logbook
	read_int_eeprom .3
	tstfsz	EEDATA							; number of total dives = 0 ?
	bra		option_reset_all2				; NO - skip resetting logbook

	clrf	EEDATA
	write_int_eeprom .4
	write_int_eeprom .5
	write_int_eeprom .6
	write_int_eeprom .2						; delete total dive counter, too
	write_int_eeprom .3
	call	ext_flash_erase_logbook			; complete logbook

option_reset_all2:
	clrf	lo
	clrf	hi
	call	do_logoffset_common_write		; reset logbook offset
	movlw	LOW(option_table_begin)			; point to option table begin
	movwf	FSR0L
	movlw	HIGH(option_table_begin)
	movwf	FSR0H
option_reset_all_1:
	movlw	LOW(option_table_end)			; get low byte of end of table address
	cpfseq	FSR0L							; does it equal the current pointer position?
	bra		option_reset_all_2				; NO - more options to process
	movlw	HIGH(option_table_end)			; get high byte of end of table address
	cpfseq	FSR0H							; does it equal the current pointer position?
	bra		option_reset_all_2				; NO - more options to process
	return									; YES to both - end of option table reached, done
option_reset_all_2:
	rcall	option_reset					; reset one option...
	bra		option_reset_all_1				; ... and loop

;=============================================================================
; Check all option and reset option if out of min/max boundary
;
; INPUT:  none
; OUTPUT: none
; TRASH:  TBLPTR, TABLAT, WREG, FSR0, FSR1, FSR2
;
	global	option_check_all				; check all option and reset option if out of min/max boundary
option_check_all:
	bcf		option_repaired					; no option needed repair up to now
	movlw	LOW(option_table_begin)			; point to option table begin
	movwf	FSR0L
	movlw	HIGH(option_table_begin)
	movwf	FSR0H
option_check_all_1:
	movlw	LOW(option_table_end)			; get low byte of end of table address
	cpfseq	FSR0L							; does it equal the current pointer position?
	bra		option_check_all_2				; NO - more options to process
	movlw	HIGH(option_table_end)			; get high byte of end of table address
	cpfseq	FSR0H							; does it equal the current pointer position?
	bra		option_check_all_2				; NO - more options to process
	bra		option_check_all_3				; YES to both - end of option table reached
option_check_all_2:
	rcall	option_check					; check one option...
	bra		option_check_all_1				; ... and loop
option_check_all_3:
	bsf		is_diluent_menu					; setup checking diluents
	call	gaslist_cleanup_list			; check and correct multiple or none First diluent
	bcf		is_diluent_menu					; setup checking gases
	call	gaslist_cleanup_list			; check and correct multiple or none First gas
 IFNDEF _gauge_mode
	call	option_cleanup_gauge			; check and correct Gauge mode
 ENDIF
 IFDEF _ccr_pscr
	call	option_cleanup_oCCRMode			; check and correct CCR / pSCR mode
 ENDIF
	call	option_cleanup_GF				; check and correct GFlow <= GFhigh
	return									; all done



;=============================================================================
; Read option handle
; INPUT:  FSR0 = option handle
; OUTPUT: FSR1 = address of variable.
; TRASH:  TBLPTR, TABLAT, WREG, FSR0, FSR1
;
option_read:
	movff	FSR0L,TBLPTRL					; set memory address of option data set, low byte
	movlw	HIGH(option_table_begin)		; get table begin address, high byte
	andlw	0xF0							; keep only the upper nibble
	iorwf	FSR0H,W							; add the memory address of the option data set, high byte
	movwf	TBLPTRH							; set the resulting memory address, high byte
	movlw	UPPER(option_table_begin)		; get table begin address, upper byte
	movwf	TBLPTRU							; set memory address of option data set, upper byte

	; Read type, default and register from table
	tblrd*+
	movff	TABLAT,opt_type
	tblrd*+
	movff	TABLAT,opt_default
	tblrd*+
	movff	TABLAT,opt_inc
	tblrd*+
	movff	TABLAT,opt_min
	tblrd*+
	movff	TABLAT,opt_max
	tblrd*+
	movff	TABLAT,opt_eeprom
	tblrd*+
	movff	TABLAT,opt_unit+0
	tblrd*+
	movff	TABLAT,opt_unit+1
	tblrd*+
	movff	TABLAT,FSR1L
	tblrd*+
	movff	TABLAT,FSR1H
	movff	TBLPTRL,FSR0L					; advance handle to next option data set (used for reset_all)
	movff	TBLPTRH,FSR0H
	return

;=============================================================================
; Check one option and reset if it's out of it's min/max boundaries
; INPUT:  FSR0 = option handle
; OUTPUT: none
; TRASH:  TBLPTR, TABLAT, WREG, FSR1, FSR2, lo
;
option_check:
	; Read type, default and register from table
	rcall	option_read

	; Switch on type
	movf	opt_type,W						; get option type
	xorlw	.2								; type == STRING ?
	bz		option_check_string				; YES
	movf	opt_type,W						; get option type (again)
	xorlw	.1								; type == ENUM8 ?
	bz		option_check_enum8				; YES - check if lower then max. value only
											; NO to all - must be integer then
	tstfsz	opt_min							; opt_min = 0 ?
	bra		option_check_both				; NO - check it
	bra		option_check_enum8				; check max only

option_check_both:
	decf	opt_min,W						; check against minimum value
	cpfsgt	INDF1							; bigger than opt_min - 1 ?
	bra		option_check_reset				; NO - reset option
option_check_enum8:							; check against maximum value
	infsnz	opt_max,W						; max = 255?
	return									; YES - ignore the max. test
	cpfslt	INDF1							; NO  - smaller then opt_max + 1 ?
	bra		option_check_reset				;       NO  - reset option
	return									;       YES - within range, return

option_check_reset:
	movff	opt_default,INDF1				; reset option to default
	bsf		option_repaired					; flag that an option was repaired
	return									; done

option_check_string:
	return

;=============================================================================
; Reset an option to its default value
; INPUT:  FSR0 = option handle
; OUTPUT: none
; TRASH:  TBLPTR, TABLAT, WREG, FSR1, FSR2
;
	global	option_reset					; reset FSR0 option to factory default
option_reset:
	; Read type, default and register from table
	rcall	option_read						; read option data
	movf	opt_type,W						; get option type
	xorlw	2								; Type == STRING ?
	bz		opt_reset_string				; YES - special copy
	movff	opt_default,INDF1				; NO  - just a 8 bit indirect copy
	return
opt_reset_string:
	movff	FSR1L,FSR2L						; set string destination address
	movff	FSR1H,FSR2H						; ...
	movff	opt_default+0,FSR1L				; get handle to multi-lingual text in FSR1
	movff	opt_default+1,FSR1H				; ...
	movff	TBLPTRL,opt_backup_tbl+0		; TBLPTR trashed by text routine...
	movff	TBLPTRH,opt_backup_tbl+1		; ...
	movff	TBLPTRU,opt_backup_tbl+2		; ...
	call	strcat_text						; copy translated text to FSR2
	movff	opt_backup_tbl+0,TBLPTRL		; restore TBLPTR
	movff	opt_backup_tbl+1,TBLPTRH		; ...
	movff	opt_backup_tbl+2,TBLPTRU		; ...

	return

;=============================================================================
; Save all options to EEPROM
;
	global	option_save_all					; save options to EEPROM
option_save_all:
	bcf	PIR3,RC2IE
	;---- Save option serial into EEPROM to detect reset and new version
	movlw	LOW(eeprom_serial_save)
	movwf	EEADR
	movlw	HIGH(eeprom_serial_save)
	movwf	EEADRH
	movlw	LOW(eeprom_opt_serial)
	movwf	EEDATA
	call	write_eeprom
	incf	EEADR,F
	movlw	HIGH(eeprom_opt_serial)
	movwf	EEDATA
	call	write_eeprom

	;---- Save all options
	movlw	LOW(option_table_begin)
	movwf	FSR0L
	movlw	HIGH(option_table_begin)
	movwf	FSR0H

option_save_all_1:
	movlw	LOW(option_table_end)
	cpfseq	FSR0L
	bra		option_save_all_2				; not yet done...
	movlw	HIGH(option_table_end)
	cpfseq	FSR0H
	bra		option_save_all_2				; not yet done...
	bsf	PIR3,RC2IE
	return									; all done
option_save_all_2:
	rcall	option_save						; save one option...
	bra		option_save_all_1				; ...and loop


	global	option_save
option_save:
	rcall	option_read
	incf	opt_eeprom,W					; should we save it ?
	btfsc	STATUS,Z						; EEPROM address is FFh ?
	return									; YES - nothing to do
	movf	opt_eeprom,W					; compute backup address in EEPROM
	addlw	LOW(eeprom_opt_backup)			; add offset
	movwf	EEADR
	movlw	HIGH(eeprom_opt_backup)
	btfsc	STATUS,C						; > 256 ?
	addlw	.1								; YES - +1
	movwf	EEADRH
	movf	opt_type,W						; get option type
	xorlw	2								; option type is string ?
	bz		option_save_string				; YES
	movff	INDF1,EEDATA					; NO  - one byte to be saved to EEPROM
	btfss	EEADRH,1						;     - EEADR:EEADRH < 512 ?
	call	write_eeprom					;       YES  - write
	return									;       (NO) - done
option_save_string:
	movff	POSTINC1,EEDATA					; write one byte
	btfss	EEADRH,1						; EEADR:EEADRH < 512 ?
	call	write_eeprom					; YES  - write
	infsnz	EEADR,F							; (NO) - increment EEPROM address
	incf	EEADRH,F						;      - ...
	decfsz	opt_max							;      - decrement string length, done?
	bra		option_save_string				;        NO  - loop
	return									;        YES

;=============================================================================

	global	option_restore_all				; restore options from EEPROM
option_restore_all:
	;---- Read option serial from EEPROM
	movlw	LOW(eeprom_serial_save)
	movwf	EEADR
	movlw	HIGH(eeprom_serial_save)
	movf	EEADRH
	call	read_eeprom
	movlw	LOW(eeprom_opt_serial)
	xorwf	EEDATA,W
	bnz		option_restore_bad				; auto reset if changed
	incf	EEADR,F
	call	read_eeprom
	movlw	HIGH(eeprom_opt_serial)
	xorwf	EEDATA,W
	bz		option_restore_ok				; auto reset if changed

option_restore_bad:
	call	option_reset_all				; reset RAM contains
	goto	option_save_all					; then save to EEPROM

	;---- Proper restore
option_restore_ok:
	movlw	LOW(option_table_begin)
	movwf	FSR0L
	movlw	HIGH(option_table_begin)
	movwf	FSR0H

option_restore_all_1:
	movlw	LOW(option_table_end)
	cpfseq	FSR0L
	bra		option_restore_all_2			; not yet done...
	movlw	HIGH(option_table_end)
	cpfseq	FSR0H
	bra		option_restore_all_2			; not yet done...
	return									; all done
option_restore_all_2:
	rcall	option_restore					; Restore one option
	bra		option_restore_all_1			; and loop

option_restore:
	rcall	option_read
	incf	opt_eeprom,W					; shall we save it ?
	btfsc	STATUS,Z						; EEPROM address is FFh ?
	return									; YES - nothing to do.
	movf	opt_eeprom,W					; compute backup address in EEPROM
	addlw	LOW(eeprom_opt_backup)			; add offset
	movwf	EEADR
	movlw	HIGH(eeprom_opt_backup)
	btfsc	STATUS,C						; > 256 ?
	addlw	.1								; YES - +1
	movwf	EEADRH
	movf	opt_type,W						; get option type
	xorlw	2								; Option type is string?
	bz		option_restore_string			; YES
	call	read_eeprom						; read one byte from EEPROM
	movff	EEDATA, INDF1					; restore option register
	return
option_restore_string:
	call	read_eeprom						; read one byte, and...
	movff	EEDATA,POSTINC1					; ... restore it
	infsnz	EEADR,F
	incf	EEADRH,F
	decfsz	opt_max							; decrement string length
	bra		option_restore_string			; loop while not finished
	return

;=============================================================================
; Increment an option, based on type, and boundary
; INPUT:  FSR0 = option handle
; OUTPUT: none
; TRASH:  TBLPTR, TABLAT, WREG, FSR0, FSR1
;
	global	option_inc						; increment FSR0 option
option_inc:
	; read type, default and register from table
	rcall	option_read

	; switch on type
	movf	opt_type,W
	bz		option_inc_uint8
	dcfsnz	WREG
	bra		option_inc_enum8
	dcfsnz	WREG
	bra		option_inc_string

option_inc_uint8:							; default type too...
	movf	INDF1,W
	addwf	opt_inc,W
	cpfslt	opt_max
	bra		option_inc_uint8_0
	movf	opt_min,W
option_inc_uint8_0:
	movwf	INDF1
option_inc_uint8_1:
	; Now some rather crude hack into this routine to make CCR Calibration more convenient:
	movlw	.149							; EEPROM address of option CalGasO2
	cpfseq	opt_eeprom						; editing CalGasO2 right now?
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
	movlw	.12								; EEPROM address of option opt_GF_low
	cpfseq	opt_eeprom						; editing opt_GF_low right now?
	bra		option_inc_uint8_3				; NO - check next option
	movff	opt_GF_high,WREG				; get value of associated GF high into WREG
	cpfsgt	INDF1							; GF low > GF high?
	return									; NO  - setting ok, done
	movff	opt_min,INDF1					; YES - wrap around to minimum value
	return									;     - done
option_inc_uint8_3:
	movlw	.13								; EEPROM address of option opt_GF_high
	cpfseq	opt_eeprom						; editing opt_GF_high right now?
	bra		option_inc_uint8_4				; NO - check next option
	movff	opt_GF_low,WREG					; get value of associated GF low into WREG
	cpfslt	INDF1							; GF high < GF low?
	return									; NO  - setting ok, done
	movwf	INDF1							; YES - rise GF high to GF low
	return									;     - done
option_inc_uint8_4:
	movlw	.17								; EEPROM address of option opt_aGF_low
	cpfseq	opt_eeprom						; editing opt_aGF_low right now?
	bra		option_inc_uint8_5				; NO - check next option
	movff	opt_aGF_high,WREG				; get value of associated GF high into WREG
	cpfsgt	INDF1							; GF low > GF high?
	return									; NO  - setting ok, done
	movff	opt_min,INDF1					; YES - wrap around to minimum value
	return									;     - done
option_inc_uint8_5:
	movlw	.18								; EEPROM address of option opt_aGF_high
	cpfseq	opt_eeprom						; editing opt_aGF_high right now?
	bra		option_inc_uint8_6				; NO - check next option
	movff	opt_aGF_low,WREG				; get value of associated GF low into WREG
	cpfslt	INDF1							; GF high < GF low?
	return									; NO  - setting ok, done
	movwf	INDF1							; YES - rise GF high to GF low
	return									;     - done
option_inc_uint8_6:
	return									; all done


option_inc_enum8:							; always +1
	incf	INDF1,W
	cpfsgt	opt_max
	clrf	WREG
	movwf	INDF1
option_inc_enum8_1:
 IFDEF _ccr_pscr
	; Now some rather crude hack into this routine to unify CCR & pSCR mode setting
	movlw	.25								; EEPROM address of option oCCRMode
	cpfseq	opt_eeprom						; editing oCCRMode right now?
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
											; (unused)
option_inc_enum8_3:
	; Now some rather crude hack to correct opt_TR_mode in dependency of opt_dive_mode
	movlw	.8								; EEPROM address of option opt_dive_mode
	cpfseq	opt_eeprom						; editing opt_dive_mode right now?
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
	; Now some rather crude hack to advance opt_TR_mode in dependency of opt_dive_mode
	movlw	.222							; EEPROM address of option opt_TR_mode
	cpfseq	opt_eeprom						; editing opt_TR_mode right now?
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
	return


option_inc_string:							; no editing available
	return


 IFNDEF _gauge_mode
option_cleanup_gauge:
	movff	opt_dive_mode,WREG				; get dive mode into WREG (0=OC, 1=CCR, 2=Gauge, 3=Apnea, 4=pSCR)
	xorlw	.2								; in Gauge mode?
	bnz		option_cleanup_gauge_1			; NO  - done
	banksel	opt_dive_mode					; YES - setting not allowed, select options bank
	clrf	opt_dive_mode					;     - reset to OC mode
	banksel	common							;     - back to bank common
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
	bsf		option_repaired					;     - flag that an option was repaired
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
	bsf		option_repaired					;                  - flag that an option was repaired
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
	bsf		option_repaired					; flag that an option was repaired
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
	bsf		option_repaired					; flag that an option was repaired
option_cleanup_GF_4:
	return									; done


;=============================================================================
; Strcat option into FSR2 buffer
;
	global	option_draw						; STRCAT FRS0 option
option_draw:
	; Read type, default and register from table
	rcall	option_read

	; Switch on type
	movf	opt_type,W
	bz		option_draw_uint8				; type0 = INT8
	dcfsnz	WREG
	bra		option_draw_enum8				; type1 = ENUM
	dcfsnz	WREG
	bra		option_draw_string				; type2 = string
	dcfsnz	WREG
	bra		option_draw_uint8_depth			; type3 = INT8 with automatic display in meters or feet
	return									; unknown, return

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
	movff	INDF1,lo						; memorize current value
	movf	INDF1,W							; copy current value to WREG
	cpfsgt	opt_max							; max value (= highest usable value + 1) > current value?
	clrf	WREG							; NO  - to avoid printing rubbish, reset to first value
	addwf	WREG							; current value *= 2
	addwf	opt_inc,W						; base text + 2 * current value
	movwf	FSR1L							; load FSR0
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
