;=============================================================================
;
;   File external_flash.inc                 * combined next generation V3.09.4e
;
;
;   Copyright (c) 2011, JD Gascuel, heinrichs weikamp gmbh, all right reserved.
;=============================================================================
; HISTORY
;  2011-08-12 : [mH] creation


; FLASH Memory Layout:
;
; 0x000000 - 0x1FFFFF    2 MB dive profile data, shared ring buffer
; 0x200000 - 0x2FFFFF    1 MB dive header  data, last 256 dives, 4 kB / dive
; 0x300000 - 0x3DFFFF  896 kB unused
; 0x3C0000 - 0x3DDFFF  120 kB backup firmware
; 0x3DE000 - 0x3DFFFF    8 kb unused
; 0x3E0000 - 0x3FDFFF  120 kB firmware buffer
; 0x3FE000 - 0x3FFFFF    8 kB reserved for factory use


; Write: WREG -> FLASH with address increment and wrap-around at 0x200000
	extern	ext_flash_write_byte_0x20_incdc		; with increment of ext_flash_dive_counter
	extern	ext_flash_write_byte_0x20			; standard flash write
	extern	ext_flash_write_byte_0x20_nodel		; without delete on entering new page


; Write: WREG -> FLASH with address increment and wrap-around at 0x400000
	extern	ext_flash_write_byte_0x40_nowait	; without wait for use with fast comm (~86us fixed delay due to 115200 Bauds - use with caution)


; Read: block-read FLASH -> WREG
	extern	ext_flash_read_block_start			; initial    read of one  byte at ext_flash_address:3
	extern	ext_flash_read_block_0x40			; subsequent read of next byte(s) with wrap-around at 0x400000
;	extern	ext_flash_read_block_0x20			; subsequent read of next byte(s) with wrap-around at 0x200000
	extern	ext_flash_read_block_stop			; terminate  read


; Erase:
	extern	ext_flash_erase_4kB					; erase   one 4kB block  starting at ext_flash_address:3
	extern	ext_flash_erase_range				; erase #WREG 4kB blocks starting at ext_flash_address:3
	extern	erase_complete_logbook				; erase complete logbook (FLASH and EEPROM)


; Protection:
	extern	ext_flash_enable_protection			; enable  write protection
	extern	ext_flash_disable_protection		; disable write protection

; Misc
	extern	ext_flash_read_jedec				; read JEDEC IDs
	extern	ext_flash_inc_address_4kB			; increment address by 0x001000, no check for wrap-around


 IFDEF _firmware_recovery
; Firmware Copying
	extern	copy_fw_active_to_backup			; copy active firmware code to backup storage
	extern	copy_fw_backup_to_active			; copy backup firmware code to update storage
 ENDIF


;-----------------------------------------------------------------------------
; Macros
;-----------------------------------------------------------------------------


; read 1 byte from FLASH to WREG with address increment and wrap-around at 0x200000
;
; the byte read is also copied to ext_flash_rw
;
FLASH_CW_READ_0x20	macro
	extern	ext_flash_read_byte_0x20
	call	ext_flash_read_byte_0x20			; read from FLASH to WREG
	endm


; read 1 byte from FLASH to WREG with address increment and wrap-around at 0x400000
;
; the byte read is also copied to ext_flash_rw
;
FLASH_CW_READ_0x40	macro
	extern	ext_flash_read_byte_0x40
	call	ext_flash_read_byte_0x40			; read from FLASH to WREG
	endm


; read 1 byte from FLASH to memory with address increment and wrap-around at 0x200000
;
; mem_address: target address in memory, must be in current bank!
;
FLASH_CC_READ_0x20	macro	mem_address
	extern	ext_flash_read_byte_0x20
	call	ext_flash_read_byte_0x20			; read from FLASH to WREG
	movwf	mem_address							; copy from WREG  to memory
	endm


; read 2 bytes from FLASH to memory with address auto-increment and wrap-around at 0x200000
;
; mem_address: target address in memory, must be in current bank!
;
FLASH_II_READ_0x20	macro	mem_address
	extern	ext_flash_read_byte_0x20
	call	ext_flash_read_byte_0x20			; read 1st byte from FLASH to WREG
	movwf	mem_address+0						; copy 1st byte from WREG  to memory
	call	ext_flash_read_byte_0x20			; read 2nd byte from FLASH to WREG
	movwf	mem_address+1						; copy 2nd byte from WREG  to memory
	endm


; read a range of data from FLASH to memory (destroys WREG, FSR1)
;
; memory_start: address:2 containing start address in memory
; range       : literal:1 giving the number of bytes to read (1-256)
;
; Attention: function does NOT check for a wrap-around!
;
; -> flash_start is at ext_flash_address
; -> ext_flash_address is NOT changed
;
FLASH_RR_READ		macro	memory_start, range
	lfsr	FSR1,memory_start						; set start address in memory
	movlw	low(range)								; set size of range to read
	extern	ext_flash_read_range
	call	ext_flash_read_range					; execute range-read
	endm


; write a range of data from memory to FLASH (destroys WREG, FSR1)
;
; memory_start: address:2 containing start address in memory
; range       : literal:1 giving the number of bytes to write (1-256)
;
; Attention: low(ext_flash_address) + range must be <= 256 !
;
; -> flash_start is at ext_flash_address
; -> old flash chip: ext_flash_address is incremented according to range parameter
; -> new flash chip: ext_flash_address is set to start of next 256 byte block
;
FLASH_RR_WRITE		macro	memory_start, range
	lfsr	FSR1,memory_start						; set start address in memory
	movlw	low(range)								; set size of range to write
	extern	ext_flash_write_range
	call	ext_flash_write_range					; execute range-write
	endm


; set ext_flash_address to a given address
;
EXT_FLASH_ADDR	macro	address
	movlw	LOW   (address         )
	movwf	ext_flash_address+0
	movlw	HIGH  (address & 0xFFFF)
	movwf	ext_flash_address+1
	movlw	UPPER (address         )
	movwf	ext_flash_address+2
	endm


; move forward in FLASH with wrap-around at 0x400000 to 0x000000
;
; increment: literal (1-255)
;
EXT_FLASH_INC_ADDRESS_0x40	macro	increment
	movlw	increment
	extern	ext_flash_inc_address_0x40_exec
	call	ext_flash_inc_address_0x40_exec
	endm


; move forward in FLASH with wrap-around at 0x200000 to 0x000000
;
; increment: literal (1-255)
;
EXT_FLASH_INC_ADDRESS_0x20	macro	increment
	movlw	increment
	extern	ext_flash_inc_address_0x20_exec
	call	ext_flash_inc_address_0x20_exec
	endm


; decrement length counter by 1
;
EXT_FLASH_DEC_LENGTH		macro
	extern	ext_flash_dec_length_exec
	call	ext_flash_dec_length_exec
	endm
