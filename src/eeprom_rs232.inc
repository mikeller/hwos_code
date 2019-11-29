;=============================================================================
;
;   File eeprom_rs232.inc                     combined next generation V3.06.1
;
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;  2011-08-03 : [mH] moving from OSTC code


write_int_eeprom	macro	eeprom_address
	movlw	eeprom_address
	call	write_int_eeprom_1
	endm

read_int_eeprom		macro	eeprom_address
	movlw	eeprom_address
	call	read_int_eeprom_1
	endm


	extern	enable_rs232
	extern	disable_rs232
	extern	rs232_get_byte
	extern	rs232_wait_tx
	extern	rs232_wait_tx2

	extern	enable_ir_s8
	extern	disable_ir_s8

	extern	write_int_eeprom_1
	extern	read_int_eeprom_1
	extern	read_eeprom
	extern	write_eeprom

	extern	update_battery_registers
	extern	retrieve_battery_registers

	extern	vault_decodata_into_eeprom
	extern	restore_decodata_from_eeprom

	extern	do_logoffset_common_write
	extern	do_logoffset_common_read
	extern	eeprom_reset_logbook_pointers

	extern	reset_battery_pointer			; reset battery pointer 0x07-0x0C and battery_gauge
	extern	reset_battery_internal_only		; reset internal battery registers only
