;=============================================================================
;
;   File eeprom_rs232.asm												V2.99a
;
;   Internal EEPROM, RS232
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;  2011-08-06 : [mH] moving from OSTC code

#include "hwos.inc"
#include "wait.inc"
#include "shared_definitions.h"
#include "rtc.inc"

write_int_eeprom	macro	eeprom_address
	movlw	eeprom_address
	call	write_int_eeprom_1
	endm

read_int_eeprom		macro	eeprom_address
	movlw	eeprom_address
	call	read_int_eeprom_1
	endm

;=============================================================================
eeprom		code	0xF00000+0x10
; skip SERIAL number - it should not be overwritten

	global	eeprom_serial_save
	global	eeprom_opt_backup

eeprom_serial_save	res 2
eeprom_opt_backup	res 0x3E

;=============================================================================
ee_rs232		CODE

	global	write_int_eeprom_1
write_int_eeprom_1:
	movwf	EEADR
	bra		write_eeprom				; writes and "returns" after write


	global read_int_eeprom_1
read_int_eeprom_1:
	movwf	EEADR
	bra		read_eeprom					; reads and "returns" after write

;=============================================================================
; reads from internal EEPROM
; Input:   EEADRH:EEADR = EEPROM address
; Output:  EEDATA
; Trashed: NONE
	global	read_eeprom
read_eeprom:
	bcf		EECON1,EEPGD
	bcf		EECON1,CFGS
	bsf		EECON1,RD
	return

;=============================================================================
; writes into internal EEPROM
; Input:   EEADRH:EEADR = EEPROM address
;          EEDATA = byte to write
; Trashed: WREG
	global	write_eeprom
write_eeprom:
	bcf		EECON1,EEPGD
	bcf		EECON1,CFGS
	bsf		EECON1,WREN

	bcf		INTCON,GIE					; disable interrupts for the next 5 instructions
	movlw	0x55
	movwf	EECON2
	movlw	0xAA
	movwf	EECON2
	bsf		EECON1,WR
	bsf		INTCON,GIE					; ...but the flag for the ISR routines were still set, so they will interrupt now!

write_eep2:
	btfsc	EECON1,WR
	bra		write_eep2					; wait about 4ms...
	bcf		EECON1,WREN
	return


	global	disable_ir_s8
disable_ir_s8:
	banksel	TXSTA2
	clrf	TXSTA2
	clrf	RCSTA2
	banksel	common
	bcf		ir_power					; IR off
	bcf		mcp_power					; power-down instrumentation amp
	bsf		s8_npower					; power-down S8 HUD
	return


	global	enable_ir_s8
enable_ir_s8:
;init serial port2 (TRISG2)
	btfsc	analog_o2_input
	bra		enable_s8					; start S8

	banksel	BAUDCON2
	movlw	b'00100000'					; BRG16=0			; inverted for IR
	movwf	BAUDCON2
	movlw	b'00100000'					; BRGH=0, SYNC=0
	movwf	TXSTA2
	movlw	.102						; SPBRGH:SPBRG = .102 : 2403 BAUD @ 16 MHz
	movwf	SPBRG2
	movlw	b'10010000'
	movwf	RCSTA2
	banksel	common
	bsf		ir_power					; power-up IR
	btfss	ir_power
	bra		$-6
	return

enable_s8:
	; Check for Digital/Analog
	bsf		s8_npower					; power-down S8 HUD
	WAITMS	d'1'						; very short delay
	bsf		mcp_power					; power-up instrumentation amp
	btfss	mcp_power
	bra		$-6
	banksel	TXSTA2
	clrf	TXSTA2
	clrf	RCSTA2
	banksel	common

	; It may be digital, check for voltage when isolator is powered
	bcf		s8_npower					; power S8 HUD
	WAITMS	d'1'						; very short delay

	btfsc	PORTG,2						; RX2=1?
	bra	enable_s8_2						; YES - digital
	WAITMS	d'30'
	btfsc	PORTG,2						; RX2=1?
	bra		enable_s8_2					; YES - digital

	; Not found, set to analog (fail-safe)

enable_s8_analog:
	; S8 Analog
	bsf		s8_npower					; power-down S8 HUD
	bcf		s8_digital					; clear flag
	return

enable_s8_2:							; S8 Digital
	banksel BAUDCON2
	movlw	b'00000000'					; BRG16=0			; normal for S8
	movwf	BAUDCON2
	movlw	b'00100000'					; BRGH=0, SYNC=0
	movwf	TXSTA2
	movlw	.25							; SPBRGH:SPBRG = .25 : 9615 BAUD @ 16 MHz
	movwf	SPBRG2
	movlw	b'10010000'
	movwf	RCSTA2
	banksel	common
	bsf		s8_digital					; set flag
	return

;=============================================================================

	global	enable_rs232
enable_rs232:
	call	speed_normal				; 16 MHz
enable_rs232_2:
	movlw	T2CON_NORMAL
	cpfseq	T2CON
	bra		enable_rs232_2				; wait until speed is normal
	bcf		PORTE,0						; start comms
;init serial port1 (TRISC6/7)
	movlw	b'00100100'					; BRGH=1, SYNC=0
	movwf	TXSTA1
	movlw	b'10010000'
	movwf	RCSTA1
	return


	global	disable_rs232
disable_rs232:
	clrf	RCSTA1
	clrf	TXSTA1						; UART disable
	bcf		PORTC,6						; TX hard to GND
	bsf		PORTE,0						; stop comms
	return


	global	rs232_wait_tx
rs232_wait_tx:
	btfss	TXSTA1,TRMT					; RS232 Busy?
	bra		rs232_wait_tx				; YES - wait...

	btfss	ble_available				; ble available?
	return								; NO - done

	btfsc	NRTS						; wait for Bluetooth module
	bra		rs232_wait_tx				; YES - wait...
	return								; done


	global	rs232_wait_tx2
rs232_wait_tx2:
	banksel	TXSTA2
rs232_wait_tx2_1:
	btfss	TXSTA2,TRMT					; RS232 busy?
	bra		rs232_wait_tx2_1			; YES - wait...
	banksel	common
	return								; done

	global	rs232_get_byte
rs232_get_byte:
	bcf		rs232_receive_overflow		; clear flag
	clrf	uart1_temp					; set uart1_temp to .10 without using WREG: first clear to 0, then...
	bsf		uart1_temp,1				; set bit 1 (value 2),
	bsf		uart1_temp,3				; and bit 3 (value 8).
	clrf	uart2_temp
	clrf	uart3_temp
rs232_get_byte2:
	btfsc	PIR1,RCIF					; data arrived?
	return								; YES
	decfsz	uart3_temp,F
	bra		rs232_get_byte2
	decfsz	uart2_temp,F
	bra		rs232_get_byte2
	decfsz	uart1_temp,F
	bra		rs232_get_byte2
										; timeout occurred (about 400ms)
	bsf		rs232_receive_overflow		; set flag
rs232_get_byte3:
	bcf		RCSTA1,CREN					; clear receiver status
	bsf		RCSTA1,CREN
	return								; and return anyway

;=============================================================================

	global	do_logoffset_common_write
do_logoffset_common_write:
	movlw	0x26
	cpfslt	hi								; is offset < 0x26?? (decimal 9983 at max, hence save for another +10) ?
	return									; NO  - abort
	movff	lo,EEDATA						; YES - proceed writing offset to EEPROM
	write_int_eeprom 0x0D
	movff	hi,EEDATA
	write_int_eeprom 0x0E
	return

	global	do_logoffset_common_read
do_logoffset_common_read:
	clrf	EEADRH
	read_int_eeprom 0x0D
	movff	EEDATA,lo
	read_int_eeprom 0x0E
	movff	EEDATA,hi						; existing logbook offset into lo:hi
	return


	global	update_battery_registers
update_battery_registers:
	; save battery_gauge:6 into EEPROM 0x07-0x0C
	clrf	EEADRH
	movff	battery_gauge+0,EEDATA
	write_int_eeprom 0x07
	movff	battery_gauge+1,EEDATA
	write_int_eeprom 0x08
	movff	battery_gauge+2,EEDATA
	write_int_eeprom 0x09
	movff	battery_gauge+3,EEDATA
	write_int_eeprom 0x0A
	movff	battery_gauge+4,EEDATA
	write_int_eeprom 0x0B
	movff	battery_gauge+5,EEDATA
	write_int_eeprom 0x0C
	movff	battery_type,EEDATA				; =0:1.5V, =1:3,6V Saft, =2:LiIon 3,7V/0.8Ah, =3:LiIon 3,7V/3.1Ah, =4: LiIon 3,7V/2.3Ah
	write_int_eeprom 0x0F
	return


	global	vault_decodata_into_eeprom
vault_decodata_into_eeprom:
	; Vault in EEPROM 512...1023
	; Write 0xAA at 512 to indicate valid data in vault
	; Store last time/date
	; Store 0x700 to 0x780 (pres_tissue_N2 and pres_tissue_He)
	movlw	HIGH .512						; =2
	movwf	EEADRH
	movlw	0xAA
	movwf	EEDATA
	write_int_eeprom .0
	; Store date/time
	movff	year,EEDATA
	write_int_eeprom .1
	movff	month,EEDATA
	write_int_eeprom .2
	movff	day,EEDATA
	write_int_eeprom .3
	movff	hours,EEDATA
	write_int_eeprom .4
	movff	mins,EEDATA
	write_int_eeprom .5
	movff	secs,EEDATA
	write_int_eeprom .6

	movff	int_O_CNS_fraction+0,EEDATA
	write_int_eeprom .7
	movff	int_O_CNS_fraction+1,EEDATA
	write_int_eeprom .8
	movff	int_O_desaturation_time+0,EEDATA
	write_int_eeprom .9
	movff	int_O_desaturation_time+1,EEDATA
	write_int_eeprom .10
	movff	surface_interval+0,EEDATA
	write_int_eeprom .11
	movff	surface_interval+1,EEDATA
	write_int_eeprom .12
	movff	int_O_gradient_factor+0,EEDATA	; value limited to 255, only lower byte in use for value
	write_int_eeprom .13
	movff	int_O_nofly_time+0,EEDATA
	write_int_eeprom .14
	movff	int_O_nofly_time+1,EEDATA
	write_int_eeprom .15

	; Tissue data from 16 to 144
	movlw	.16
	movwf	EEADR
	movlw	.128
	movwf	lo
	lfsr	FSR1,0x700						; pres_tissue_N2+0, 32*4Byte Float = 128Bytes
vault_decodata_into_eeprom2:
	movff	POSTINC1,EEDATA
	call	write_eeprom					; EEDATA into EEPROM@EEADR
	incf	EEADR,F
	decfsz	lo,F							; all done?
	bra		vault_decodata_into_eeprom2		; NO
	clrf	EEADRH
	return

	global	restore_decodata_from_eeprom
restore_decodata_from_eeprom:
	movlw	LOW  .512						; =0
	movwf	EEADR
	movlw	HIGH .512						; =2
	movwf	EEADRH

	; Restore date/time
	read_int_eeprom .1
	movff	EEDATA,year
	read_int_eeprom .2
	movff	EEDATA,month
	read_int_eeprom .3
	movff	EEDATA,day
	read_int_eeprom .4
	movff	EEDATA,hours
	read_int_eeprom .5
	movff	EEDATA,mins
	read_int_eeprom .6
	movff	EEDATA,secs
	call	rtc_set_rtc

	read_int_eeprom .7
	movff	EEDATA,int_O_CNS_fraction+0
	read_int_eeprom .8
	movff	EEDATA,int_O_CNS_fraction+1
	read_int_eeprom .9
	movff	EEDATA,int_O_desaturation_time+0
	read_int_eeprom .10
	movff	EEDATA,int_O_desaturation_time+1
	read_int_eeprom .11
	movff	EEDATA,surface_interval+0
	read_int_eeprom .12
	movff	EEDATA,surface_interval+1
	read_int_eeprom .13
	movff	EEDATA,int_O_gradient_factor+0
	read_int_eeprom .14
	movff	EEDATA,int_O_nofly_time+0
	read_int_eeprom .15
	movff	EEDATA,int_O_nofly_time+1

	; Tissue data from 16 to 144
	movlw	.16
	movwf	EEADR
	movlw	.128
	movwf	lo
	lfsr	FSR1,0x700						; pres_tissue_N2+0, 32*4Byte Float = 128 Bytes
restore_decodata_from_eeprom2:
	call	read_eeprom						; EEPROM@EEADR into EEDATA
	movff	EEDATA,POSTINC1
	incf	EEADR,F
	decfsz	lo,F							; all done?
	bra		restore_decodata_from_eeprom2	; NO
	clrf	EEADRH
	return


	global	reset_battery_internal_only
reset_battery_internal_only:
	clrf	EEADRH
	clrf	EEDATA							; delete to zero
	write_int_eeprom 0x07
	write_int_eeprom 0x08
	write_int_eeprom 0x09
	write_int_eeprom 0x0A
	write_int_eeprom 0x0B
	write_int_eeprom 0x0C
	banksel	battery_gauge+0
	clrf	battery_gauge+0
	clrf	battery_gauge+1
	clrf	battery_gauge+2
	clrf	battery_gauge+3
	clrf	battery_gauge+4
	clrf	battery_gauge+5
	banksel	common
	movlw	.100
	movwf	batt_percent
	return


	global	eeprom_reset_logbook_pointers
eeprom_reset_logbook_pointers:
	clrf	EEADRH							; make sure to select EEPROM bank 0
	clrf	EEDATA
	write_int_eeprom .4
	write_int_eeprom .5
	write_int_eeprom .6
	write_int_eeprom .2						; also delete total dive counter
	write_int_eeprom .3
	write_int_eeprom .16
	write_int_eeprom .17					; ...and the backup counter, too
	return

	END
