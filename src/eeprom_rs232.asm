;=============================================================================
;
;   File eeprom_rs232.asm                     combined next generation V3.06.2
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

	extern	lt2942_charge_done

;-----------------------------------------------------------------------------
; Macros

write_int_eeprom	macro	eeprom_address
	movlw	eeprom_address
	call	write_int_eeprom_1
	endm

read_int_eeprom		macro	eeprom_address
	movlw	eeprom_address
	call	read_int_eeprom_1
	endm

;-----------------------------------------------------------------------------
; Reserved memory locations in EEPROM

eeprom		code	0xF00000+0x10		; skip SERIAL number - it should not be overwritten

	global	eeprom_serial_save
	global	eeprom_opt_backup

eeprom_serial_save	res 2
eeprom_opt_backup	res 0x3E

;-----------------------------------------------------------------------------

ee_rs232		CODE

;=============================================================================

	global	write_int_eeprom_1
write_int_eeprom_1:
	movwf	EEADR
	bra		write_eeprom				; writes and "returns" after write


	global	read_int_eeprom_1
read_int_eeprom_1:
	movwf	EEADR
	bra		read_eeprom					; reads and "returns" after write

;=============================================================================
; read from internal EEPROM
;
; Input:   EEADRH:EEADR = EEPROM address
; Output:  EEDATA
; Trashed: NONE
;
	global	read_eeprom
read_eeprom:
	bcf		EECON1,EEPGD
	bcf		EECON1,CFGS
	bsf		EECON1,RD
	return

;=============================================================================
; write into internal EEPROM
;
; Input:   EEADRH:EEADR = EEPROM address
;          EEDATA = byte to write
; Trashed: WREG
;
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

write_eep2:
	btfsc	EECON1,WR
	bra		write_eep2					; wait about 4ms...
	bcf		EECON1,WREN
	bsf		INTCON,GIE					; ...but the flag for the ISR routines were still set, so they will interrupt now!
	return

;=============================================================================

	global	disable_ir_s8
disable_ir_s8:
	banksel	TXSTA2						; select bank for IO register access
	clrf	TXSTA2
	clrf	RCSTA2
	banksel	common						; back to bank common
	bcf		PIE3,RC2IE					; disable RC2 INT
	bcf		ir_power					; IR off
	bcf		mcp_power					; power-down instrumentation amp
	bsf		s8_npower					; power-down S8 digital interface
	bcf		s8_digital_avail			; digital S8 interface not available
	return


	global	enable_ir_s8
enable_ir_s8:
	;initialize serial port2 (TRISG2)
	btfsc	analog_o2_input				; do we have an analog input?
	bra		enable_s8					; YES - search for S8 digital input
										; NO  - start      IR digital input
	banksel	BAUDCON2					;     - select bank for IO register access
	movlw	b'00100000'					;     - BRG16=0, inverted for IR
	movwf	BAUDCON2
	movlw	b'00100000'					;     - BRGH=0, SYNC=0
	movwf	TXSTA2
	movlw	.102						;     - SPBRGH:SPBRG = .102 : 2403 BAUD @ 16 MHz
	movwf	SPBRG2
	clrf	SPBRGH2
	movlw	b'10010000'
	movwf	RCSTA2
	banksel	common						;     - back to bank common
	bsf		ir_power					;     - power-up IR
	btfss	ir_power					;     - power-up confirmed?
	bra		$-6							;       NO - loop and wait
	bsf		PIE3,RC2IE					;     - enable RC2 INT
	return								;     - done

enable_s8:
	banksel	TXSTA2						; select bank for IO register access
	clrf	TXSTA2
	clrf	RCSTA2
	banksel	common						; back to bank common
	; Check for Digital/Analog
	bsf		s8_npower					; power-down S8 HUD
	WAITMS	d'2'						; very short delay
	bsf		mcp_power					; power-up instrumentation amp
	btfss	mcp_power
	bra		$-4

	; It may be digital, check for voltage when isolator is powered
	bcf		s8_npower					; power S8 HUD
	WAITMS	d'1'						; wait 1 ms
	btfsc	PORTG,2						; RX2=1?
	bra		enable_s8_2					; YES - digital
	WAITMS	d'30'						; NO  - wait 30 ms
	btfsc	PORTG,2						;     - RX2=1?
	bra		enable_s8_2					;       YES - digital
	;bra	enable_s8_analog			;       NO  - not found, set to analog (fail-safe)

enable_s8_analog:
	; S8 analog interface
	bsf		s8_npower					; power-down S8 HUD
	bcf		s8_digital_avail			; digital S8 interface not available
	return

enable_s8_2:							; configure S8 digital interface
	banksel BAUDCON2					; select bank for IO register access
	movlw	b'00000000'					; BRG16=0, normal for S8
	movwf	BAUDCON2
	movlw	b'00100000'					; BRGH=0, SYNC=0
	movwf	TXSTA2
	movlw	.25							; SPBRGH:SPBRG = .25 : 9615 BAUD @ 16 MHz
	movwf	SPBRG2
	movlw	b'10010000'
	movwf	RCSTA2
	banksel	common						; back to bank common
	bsf		s8_digital_avail			; digital S8 interface available
	return

;=============================================================================

	global	enable_rs232
enable_rs232:
	call	request_speed_normal		; request CPU speed change to normal speed
enable_rs232_1:
	btfss	speed_is_normal				; speed = normal?
	bra		enable_rs232_1				; NO - wait for ISR to adjust speed
	bcf		PORTE,0						; start comm
	bsf		PORTJ,2						; /Reset (for very old OSTC sport)
	;initialize serial port1 (TRISC6/7)
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
	bsf		PORTE,0						; stop comm
	bcf		PORTJ,2						; /Reset (for very old OSTC sport)
	return


	global	rs232_wait_tx
rs232_wait_tx:
	btfss	TXSTA1,TRMT					; RS232 busy?
	bra		rs232_wait_tx				; YES - wait...

	btfss	ble_available				; ble available?
	return								; NO - done

	btfsc	NRTS						; wait for Bluetooth module
	bra		rs232_wait_tx				; YES - wait...
	return								; done


	global	rs232_wait_tx2
rs232_wait_tx2:
	banksel	TXSTA2						; select bank for IO register access
rs232_wait_tx2_loop:
	btfss	TXSTA2,TRMT					; RS232 busy?
	bra		rs232_wait_tx2_loop			; YES - wait...
	banksel	common						; back to bank common
	return								; done


	global	rs232_get_byte
rs232_get_byte:
	bcf		rs232_rx_timeout			; clear timeout flag
										; set timeout timer to approx. 400 ms:
	clrf	uart_timeout_timer+0		; set low   byte of timeout timer to 0
	clrf	uart_timeout_timer+1		; set high  byte of timeout timer to 0
										; set upper byte of timeout timer to 10 without using WREG:
	clrf	uart_timeout_timer+2		; first clear to 0, then...
	bsf		uart_timeout_timer+2,1		; set bit 1 (value 2),
	bsf		uart_timeout_timer+2,3		; and bit 3 (value 8).

rs232_get_byte_loop:
	btfsc	PIR1,RCIF					; received a data byte?
	return								; YES - done
	decfsz	uart_timeout_timer+0,F		; NO  - decrement low byte of timer, became zero?
	bra		rs232_get_byte_loop			;       NO  - loop
	decfsz	uart_timeout_timer+1,F		;       YES - decrement high byte of timer, became zero?
	bra		rs232_get_byte_loop			;             NO  - loop
	decfsz	uart_timeout_timer+2,F		;             YES - decrement upper byte of timer, became zero?
	bra		rs232_get_byte_loop			;                   NO  - loop
	bsf		rs232_rx_timeout			;                   YES - set timeout flag
	bcf		RCSTA1,CREN					;                       - clear receiver status
	bsf		RCSTA1,CREN					;                       - ...
	return								;                       - and return anyway

;=============================================================================

	global	do_logoffset_common_write
do_logoffset_common_write:
	movff	lo,EEDATA
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
	movff	EEDATA,hi
	return

;=============================================================================

	global	update_battery_registers
update_battery_registers:
	; save battery gauge to EEPROM 0x07-0x0C
	bsf		block_battery_gauge			; suspend ISR from accessing the battery gauge
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
	movff	battery_type,EEDATA			; =0:1.5V, =1:3.6V Saft, =2:LiIon 3.7V/0.8Ah, =3:LiIon 3.7V/3.1Ah, =4: LiIon 3.7V/2.3Ah
	write_int_eeprom 0x0F
	bcf		block_battery_gauge			; allow ISR to access the battery gauge again
	return


	global	retrieve_battery_registers
retrieve_battery_registers:
	; retrieve battery gauge from EEPROM 0x07-0x0C
	bsf		block_battery_gauge			; suspend ISR from accessing the battery gauge
	clrf	EEADRH
	read_int_eeprom 0x07
	movff	EEDATA,battery_gauge+0
	read_int_eeprom 0x08
	movff	EEDATA,battery_gauge+1
	read_int_eeprom 0x09
	movff	EEDATA,battery_gauge+2
	read_int_eeprom 0x0A
	movff	EEDATA,battery_gauge+3
	read_int_eeprom 0x0B
	movff	EEDATA,battery_gauge+4
	read_int_eeprom 0x0C
	movff	EEDATA,battery_gauge+5
	read_int_eeprom 0x0F
	movff	EEDATA,battery_type			; =0:1.5V, =1:3,6V Saft, =2:LiIon 3,7V/0.8Ah, =3:LiIon 3,7V/3.1Ah, =4: LiIon 3,7V/2.3Ah
	bcf		block_battery_gauge			; allow ISR to access the battery gauge again
	return

;=============================================================================

	global	vault_decodata_into_eeprom
vault_decodata_into_eeprom:
	; Vault in EEPROM 512...1023
	; Write 0xAA at 512 to indicate valid data in vault
	; Store last time/date
	; Store 0x700 to 0x780 (pres_tissue_N2 and pres_tissue_He)
	movlw	HIGH .512						; =2
	movwf	EEADRH							; set EEPROM address, high byte

	; indicate valid data in vault
	movlw	0xAA
	movwf	EEDATA
	write_int_eeprom .0

	; store date/time
	SMOVSS	rtc_year,rtc_latched_year		; ISR-safe 6 byte copy of date and time
	movff	rtc_latched_year+0,EEDATA
	write_int_eeprom .1
	movff	rtc_latched_year+1,EEDATA
	write_int_eeprom .2
	movff	rtc_latched_year+2,EEDATA
	write_int_eeprom .3
	movff	rtc_latched_year+3,EEDATA
	write_int_eeprom .4
	movff	rtc_latched_year+4,EEDATA
	write_int_eeprom .5
	movff	rtc_latched_year+5,EEDATA
	write_int_eeprom .6

	movff	int_O_CNS_current+0,EEDATA		; get current CNS, low  byte
	write_int_eeprom .7						; store value
	movff	int_O_CNS_current+1,EEDATA		; get current CNS, high byte
	write_int_eeprom .8						; store value

	movff	int_O_desaturation_time+0,EEDATA; get desaturation time, low  byte
	write_int_eeprom .9						; store value
	movff	int_O_desaturation_time+1,EEDATA; get desaturation time, high byte
	write_int_eeprom .10					; store value

	SMOVII	surface_interval_mins,mpr		; ISR-safe copy of surface interval
	movff	mpr+0,EEDATA					; get surface interval, low  byte
	write_int_eeprom .11					; store value
	movff	mpr+1,EEDATA					; get surface interval, high byte
	write_int_eeprom .12					; store value

	movff	int_O_lead_supersat+0,EEDATA	; get leading tissue's supersaturation, value is limited to 255 so only the lower byte is used for the value
	write_int_eeprom .13

	movff	int_O_nofly_time+0,EEDATA		; get time, low  byte
	write_int_eeprom .14					; store value
	movff	int_O_nofly_time+1,EEDATA		; get time, high byte
	write_int_eeprom .15					; store value

	; tissue data from 16 to 144
	movlw	.16
	movwf	EEADR
	movlw	.128							; 2 * 16 floats = 2*16*4 byte = 128 byte
	movwf	lo
	lfsr	FSR1,0x700						; pres_tissue_N2+0
vault_decodata_into_eeprom2:
	movff	POSTINC1,EEDATA
	call	write_eeprom					; EEDATA into EEPROM@EEADR
	incf	EEADR,F
	decfsz	lo,F							; all done?
	bra		vault_decodata_into_eeprom2		; NO  - loop
	clrf	EEADRH							; YES - reset EEPROM pointer
	return									;     - done


	global	restore_decodata_from_eeprom
restore_decodata_from_eeprom:
	movlw	LOW  .512						; =0
	movwf	EEADR							; set EEPROM address, low  byte
	movlw	HIGH .512						; =2
	movwf	EEADRH							; set EEPROM address, high byte

	; restore date and time
	read_int_eeprom .1
	movff	EEDATA,rtc_latched_year
	read_int_eeprom .2
	movff	EEDATA,rtc_latched_month
	read_int_eeprom .3
	movff	EEDATA,rtc_latched_day
	read_int_eeprom .4
	movff	EEDATA,rtc_latched_hour
	read_int_eeprom .5
	movff	EEDATA,rtc_latched_mins
	read_int_eeprom .6
	movff	EEDATA,rtc_latched_secs
	call	rtc_set_rtc						; write time and date to RTC module

	read_int_eeprom .7						; read CNS%, low  byte
	movff	EEDATA,int_O_CNS_current+0		; restore value
	read_int_eeprom .8						; read CNS%, high byte
	movff	EEDATA,int_O_CNS_current+1		; restore value

	read_int_eeprom .9						; read desaturation time, low  byte
	movff	EEDATA,int_O_desaturation_time+0; restore value
	read_int_eeprom .10						; read desaturation time, high byte
	movff	EEDATA,int_O_desaturation_time+1; restore value

	read_int_eeprom .11						; read surface interval, low  byte
	movff	EEDATA,mpr+0					; cache value in mpr
	read_int_eeprom .12						; read surface interval, high byte
	movff	EEDATA,mpr+1					; cache value in mpr
	SMOVII	mpr,surface_interval_mins		; ISR-safe copy-back of surface interval

	read_int_eeprom .13						; read leading tissue's supersaturation
	movff	EEDATA,int_O_lead_supersat+0	; restore value

	read_int_eeprom .14						; read no-fly/no-altitude time, low  byte
	movff	EEDATA,int_O_nofly_time+0		; restore value
	read_int_eeprom .15						; read no-fly/no-altitude time, high byte
	movff	EEDATA,int_O_nofly_time+1		; restore value

	; tissue data from 16 to 144
	movlw	.16
	movwf	EEADR
	movlw	.128							; 2 * 16 floats = 2*16*4 byte = 128 byte
	movwf	lo
	lfsr	FSR1,0x700						; pres_tissue_N2+0
restore_decodata_from_eeprom2:
	call	read_eeprom						; EEPROM@EEADR into EEDATA
	movff	EEDATA,POSTINC1
	incf	EEADR,F
	decfsz	lo,F							; all done?
	bra		restore_decodata_from_eeprom2	; NO  - loop
	clrf	EEADRH							; YES - revert EEPROM high address pointer to default
	return									;     - done

;=============================================================================

	global	reset_battery_pointer			; called from comm and menu tree
	global	reset_battery_internal_only
reset_battery_pointer:						; reset battery pointer 0x07-0x0C and battery gauge
	btfsc	battery_gauge_available			; something to reset?
	call	lt2942_charge_done				; YES - reset accumulating registers to 0xFFFF
reset_battery_internal_only:
	clrf	EEADRH
	clrf	EEDATA							; delete to zero
	write_int_eeprom 0x07
	write_int_eeprom 0x08
	write_int_eeprom 0x09
	write_int_eeprom 0x0A
	write_int_eeprom 0x0B
	write_int_eeprom 0x0C

	bsf		block_battery_gauge				; suspend ISR from accessing the battery gauge
	banksel	battery_gauge					; select bank ISR data
	clrf	battery_gauge+0					; null the battery gauge
	clrf	battery_gauge+1
	clrf	battery_gauge+2
	clrf	battery_gauge+3
	clrf	battery_gauge+4
	clrf	battery_gauge+5
	banksel	common							; back to bank common
	bcf		block_battery_gauge				; allow ISR to access the battery gauge again

	movlw	.100
	movwf	batt_percent					; set battery level to 100%
	return

;=============================================================================

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

;=============================================================================

	END
