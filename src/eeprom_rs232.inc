;=============================================================================
;
;   File eeprom_rs232.inc                     combined next generation V3.08.8
;
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;  2011-08-03 : [mH] moving from OSTC code


; --------------------------------------------------------------------------------------------
;           EEPROM read & write Macros
; --------------------------------------------------------------------------------------------


; read 1 byte from EEPROM to memory
;
; eeprom_address: address:2 containing source address in EEPROM
; memory_address: address:2 containing target address in memory
;
EEPROM_CC_READ		macro	eeprom_address, memory_address
	movlw	HIGH(eeprom_address)	; extract bank in EEPROM
	movwf	EEADRH					; set     bank in EEPROM
	movlw	LOW (eeprom_address)	; extract start address in EEPROM
	movwf	EEADR					; set     start address in EEPROM
	call	read_eeprom				; read from EEPROM
	movff	EEDATA,memory_address	; store to memory
	endm


; read 2 bytes from EEPROM to memory, both bytes must be in same EEPROM bank
;
; eeprom_address: address:2 containing start address in EEPROM
; memory_address: address:2 containing start address in memory
;
EEPROM_II_READ		macro	eeprom_address, memory_address
	movlw	HIGH(eeprom_address)	; extract bank in EEPROM
	movwf	EEADRH					; set     bank in EEPROM
	movlw	LOW (eeprom_address)	; extract start address in EEPROM
	movwf	EEADR					; set     start address in EEPROM
	lfsr	FSR1,memory_address		; set start address in memory
	movlw	.2						; read  2 bytes
	call	eeprom_read_common		; execute read
	endm


; read 3 bytes from EEPROM to memory, all bytes must be in same EEPROM bank
;
; eeprom_address: address:2 containing start address in EEPROM
; memory_address: address:2 containing start address in memory
;
EEPROM_TT_READ		macro	eeprom_address, memory_address
	movlw	HIGH(eeprom_address)	; extract bank in EEPROM
	movwf	EEADRH					; set     bank in EEPROM
	movlw	LOW (eeprom_address)	; extract start address in EEPROM
	movwf	EEADR					; set     start address in EEPROM
	lfsr	FSR1,memory_address		; set start address in memory
	movlw	.3						; read  3 bytes
	call	eeprom_read_common		; execute read
	endm


; read a range of bytes from EEPROM to memory, all bytes must be in same EEPROM bank
;
; eeprom_address: address:2 containing start address in EEPROM
; memory_address: address:2 containing start address in memory (bank safe)
; range         : number of bytes to read (1-256), will wrap-around staying in same EEPROM bank!
;
EEPROM_RR_READ		macro	eeprom_address, memory_address, range
	movlw	HIGH(eeprom_address)	; extract bank in EEPROM
	movwf	EEADRH					; set     bank in EEPROM
	movlw	LOW (eeprom_address)	; extract start address in EEPROM
	movwf	EEADR					; set     start address in EEPROM
	lfsr	FSR1,memory_address		; set start address in memory
	movlw	low(range)				; set size of range to read
	call	eeprom_read_common		; execute read
	endm


; write 1 byte from memory to EEPROM
;
; memory_address: address:2 containing source      address in memory (bank safe)
; eeprom_address: address:2 containing destination address in EEPROM
;
EEPROM_CC_WRITE		macro	memory_address, eeprom_address
	movlw	HIGH(eeprom_address)	; extract bank in EEPROM
	movwf	EEADRH					; set     bank in EEPROM
	movlw	LOW (eeprom_address)	; extract start address in EEPROM
	movwf	EEADR					; set     start address in EEPROM
	movff	memory_address,EEDATA	; copy byte to EEPROM data register
	call	write_eeprom			; execute write
	endm


; write 2 bytes from memory to EEPROM, both bytes must go into the same EEPROM bank
;
; memory_address: address:2 containing start address in memory (bank safe)
; eeprom_address: address:2 containing start address in EEPROM
;
EEPROM_II_WRITE		macro	memory_address, eeprom_address
	movlw	HIGH(eeprom_address)	; extract bank in EEPROM
	movwf	EEADRH					; set     bank in EEPROM
	movlw	LOW (eeprom_address)	; extract start address in EEPROM
	movwf	EEADR					; set     start address in EEPROM
	lfsr	FSR1,memory_address		; set start address in memory
	movlw	.2						; write 2 bytes
	call	eeprom_write_common		; execute write
	endm


; write 3 bytes from memory to EEPROM, all bytes must go into the same EEPROM bank
;
; memory_address: address:2 containing start address in memory (bank safe)
; eeprom_address: address:2 containing start address in EEPROM
;
EEPROM_TT_WRITE		macro	memory_address, eeprom_address
	movlw	HIGH(eeprom_address)	; extract bank in EEPROM
	movwf	EEADRH					; set     bank in EEPROM
	movlw	LOW (eeprom_address)	; extract start address in EEPROM
	movwf	EEADR					; set     start address in EEPROM
	lfsr	FSR1,memory_address		; set start address in memory
	movlw	.3						; write 3 bytes
	call	eeprom_write_common		; execute write
	endm


; write a range of bytes from memory to EEPROM, all bytes must go into the same EEPROM bank
;
; memory_address: address:2 containing start address in memory (bank safe)
; eeprom_address: address:2 containing start address in EEPROM
; range         : number of bytes to write (1-256), will wrap-around staying in same EEPROM bank!
;
EEPROM_RR_WRITE		macro	memory_address, eeprom_address, range
	movlw	HIGH(eeprom_address)	; extract bank in EEPROM
	movwf	EEADRH					; set     bank in EEPROM
	movlw	LOW (eeprom_address)	; extract start address in EEPROM
	movwf	EEADR					; set     start address in EEPROM
	lfsr	FSR1,memory_address		; set start address in memory
	movlw	low(range)				; set size of range to write
	call	eeprom_write_common		; execute write
	endm


; set up EEPROM address register for subsequent read/write operations
;
; eeprom_address: address:2 containing the EEPROM address to set up
;
EEPROM_SET_ADDRESS	macro	eeprom_address							; Set EEPROM address
	movlw	HIGH(eeprom_address)	; extract bank in EEPROM		; for subsequent calls to
	movwf	EEADRH					; set     EEPROM bank			; write_eeprom / read_eeprom
	movlw	LOW (eeprom_address)	; extract start address in EEPROM
	movwf	EEADR					; set     EEPROM cell
	endm


; --------------------------------------------------------------------------------------------
;       EEPROM Defines
; --------------------------------------------------------------------------------------------

#DEFINE DECO_DATA_VALID_TOKEN			0x55		; deco data valid
#DEFINE DECO_DATA_INVALID_TOKEN			0xAA		; deco data invalid


; --------------------------------------------------------------------------------------------
;       EEPROM Memory Map
; --------------------------------------------------------------------------------------------

;       Label						EEPROM Address	 Size  Description

; bank 1+2: settings & options
; ----------------------------						  +--- do not change the position of these data!
#DEFINE eeprom_ostc_serial				0x000		; | 2  OSTC dive computer unique serial number
#DEFINE eeprom_num_dives				0x002		; | 2  total number of dives
#DEFINE eeprom_log_pointer				0x004		; | 3  pointer used for accessing log data in external flash
#DEFINE eeprom_battery_gauge			0x007		; | 6  backup storage for the battery gauge meter
#DEFINE eeprom_log_offset				0x00D		; | 2  offset between OSTC dive counting and user's counting
#DEFINE eeprom_battery_type				0x00F		; | 1  battery type inside the OSTC
#DEFINE eeprom_options_version			0x010		;   2  options version identifier
;										0x012		;   8  unused
#DEFINE eeprom_options_storage			0x01A		; 486  backup storage for the options


; bank 2: deco data backup
; ------------------------
#DEFINE eeprom_deco_data_validity		0x200		;   1  deco data validity
#DEFINE eeprom_deco_data_version		0x201		;   1  deco data format version
#DEFINE eeprom_deco_data_timestamp		0x202		;   6  date/time of deco data
#DEFINE eeprom_deco_data_surfinterval	0x208		;   2  surface interval
;										0x20A		;   6  unused
#DEFINE eeprom_deco_data_bank3			0x210		;   9  desaturation status
;										0x219		;   1  unused
#DEFINE eeprom_deco_data_bank5			0x21A		;   4  CNS
;										0x21E		;   2  unused
#DEFINE eeprom_deco_data_bank7			0x220		; 128  tissue pressures
; 										0x2A0		;  96  unused


; bank 3: flash backup & factory use
; ----------------------------------
#DEFINE eeprom_prog_page0_backup		0x300		; 128  backup storage for the first program memory page
;										0x380		;   1  unused
#DEFINE eeprom_button_polarity			0x381		;   1  button polarity (factory use only, do not change position!)
;										0x382		; 126  unused



; --------------------------------------------------------------------------------------------
;           Serial read & write Macros
; --------------------------------------------------------------------------------------------

; receive 1 byte and write to memory, in case of timeout the flag 'rs232_rx_timeout' will be set
;
SERIAL_CC_RECEIVE	macro	mem_address
	call	rs232_get_byte				; (try to) receive one byte
	movff	RCREG1,mem_address			; copy received byte to memory
	endm


; stream a range of bytes to memory, in case of timeout the flag 'rs232_rx_timeout' will be set
;
; mem_address: address:2 containing the start address in memory (bank safe)
; range      : number of bytes to receive (1-256)
;
SERIAL_RR_RECEIVE_RAM	macro	mem_address, range
	lfsr	FSR2,mem_address			; set start address in memory
	movlw	low(range)					; set number of bytes to receive
	extern	serial_rx_stream_ram
	call	serial_rx_stream_ram
	endm



; send 1 byte literal
;
SERIAL_LC_SEND	macro	literal
	call	rs232_wait_tx				; wait for completion of last transmit
	movlw	literal						; load literal
	movwf	TXREG1						; send literal to serial TX
	endm


; send 1 byte from memory
;
; mem_address: address:2 containing the source address in memory (bank safe)
;
SERIAL_CC_SEND	macro	mem_address
	call	rs232_wait_tx				; wait for completion of last transmit
	movff	mem_address,TXREG1			; send byte from memory to serial TX
	endm


; send a range of bytes from memory
;
; mem_address: address:2 containing the start address in memory (bank safe)
; range      : number of bytes to send (1-256)
;
SERIAL_RR_SEND_RAM	macro	mem_address, range
	lfsr	FSR2,mem_address			; set start address in memory
	movlw	low(range)					; set number of bytes to send
	extern	serial_tx_ram
	call	serial_tx_ram
	endm


; --------------------------------------------------------------------------------------------
;       EXTERN Directives
; --------------------------------------------------------------------------------------------

 IFNDEF INSIDE_EEPROM_RS232

; EEPROM - basic read & write

	extern	eeprom_read_common
	extern	eeprom_write_common

	extern	read_eeprom
	extern	write_eeprom


; EEPROM high-level access

	extern	eeprom_serial_number_read

	extern	eeprom_total_dives_read
	extern	eeprom_total_dives_write

	extern	eeprom_log_offset_read
	extern	eeprom_log_offset_write

	extern	eeprom_battery_gauge_read
	extern	eeprom_battery_gauge_write

	extern	eeprom_deco_data_read
	extern	eeprom_deco_data_write


; Serial - IR / S8

	extern	enable_ir_s8
	extern	disable_ir_s8
	extern	ir_s8_wait_tx


; Serial - RS232 (USB / BT)

	extern	enable_rs232
	extern	disable_rs232
	extern	rs232_get_byte
	extern	rs232_wait_tx


 ENDIF	; INSIDE_EEPROM_RS232
