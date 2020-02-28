;=============================================================================
;
;   File external_flash.inc                   combined next generation V3.08.8
;
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;  2011-08-12 : [mH] creation


; FLASH Memory Layout:
;
; 0x000000 - 0x1FFFFF    2 MB dive profile data, shared ring buffer
; 0x200000 - 0x2FFFFF    1 MB dive header  data, last 256 dives, 4 kB / dive
; 0x300000 - 0x3DFFFF  896 kB unused
; 0x3E0000 - 0x3DFFFF  120 kB firmware buffer
; 0x3E0000 - 0x3FFFFF    8 kB unused


; Write: WREG -> FLASH with address increment and wrap-around at 0x200000
	extern	write_byte_ext_flash_plus_prof		; with    increase of ext_flash_dive_counter
	extern	write_byte_ext_flash_plus_nocnt		; without increase of ext_flash_dive_counter
	extern	write_byte_ext_flash_plus_nodel		; without increase of ext_flash_dive_counter, without delete on entering new page


; Write: WREG -> FLASH with address increment and wrap-around at 0x400000
	extern	write_byte_ext_flash_plus_comms		; without wait for use with fast comm (~86us fixed delay due to 115200 Bauds - use with caution)


; Read: block-read FLASH -> WREG
	extern	ext_flash_read_block_start			; initial    read of one  byte at ext_flash_address:3
	extern	ext_flash_read_block_0x40			; subsequent read of next byte(s) with wrap-around at 0x400000
	extern	ext_flash_read_block_0x20			; subsequent read of next byte(s) with wrap-around at 0x200000
	extern	ext_flash_read_block_stop			; terminate  read


; Erase:
	extern	ext_flash_erase_4kB					; erase one 4 kB sector @ext_flash_address:3
	extern	erase_complete_logbook				; erase complete logbook (FLASH and EEPROM)


; Protection:
	extern	ext_flash_enable_protection			; enable  write protection
	extern	ext_flash_disable_protection		; disable write protection



;-----------------------------------------------------------------------------
; Macros
;-----------------------------------------------------------------------------


; read 1 byte from FLASH to WREG with address auto-increment and wrap-around at 0x200000
;
; the byte read is also copied to ext_flash_rw
;
FLASH_CW_READ_0x20	macro
	extern	ext_flash_byte_read_plus_0x20
	call	ext_flash_byte_read_plus_0x20
	endm


; read 1 byte from FLASH to memory with address auto-increment and wrap-around at 0x200000
;
; mem_address: address:2 containing target address in memory
;
FLASH_CC_READ_0x20	macro	mem_address
	extern	ext_flash_byte_read_plus_0x20
	call	ext_flash_byte_read_plus_0x20		; read from flash
	movff	WREG,mem_address					; copy to   memory
	endm


; read 2 bytes from FLASH to memory with address auto-increment and wrap-around at 0x200000
;
; mem_address: address:2 containing start address in memory
;
FLASH_II_READ_0x20	macro	mem_address
	extern	ext_flash_byte_read_plus_0x20
	call	ext_flash_byte_read_plus_0x20		; read 1st byte from flash
	movff	WREG,mem_address+0					; copy 1st byte to   memory
	call	ext_flash_byte_read_plus_0x20		; read 2nd byte from flash
	movff	WREG,mem_address+1					; copy 2nd byte to   memory
	endm


; read a range of data from FLASH to memory (destroys WREG, FSR1) - wraps around at 0x400000
;                                                                 - increments ext_flash_address
; flash_start : address:3 containing start address in flash
; memory_start: address:2 containing start address in memory
; range       : literal:1 giving the number of bytes to read (1-256)
;
FLASH_RR_READ		macro	flash_start, memory_start, range
	MOVTT	flash_start,ext_flash_address			; set start address in FLASH
	lfsr	FSR1,memory_start						; set start address in memory
	movlw	low(range)								; set size of range to read
	extern	ext_flash_read_range
	call	ext_flash_read_range					; execute range-read
	endm


; write a range of data from memory to FLASH (destroys WREG, FSR1) - Attention: range must fit into a 256 byte block!
;                                                                  - does not increment ext_flash_address!
; memory_start: address:2 containing start address in memory
; flash_start : address:3 containing start address in flash
; range       : literal:1 giving the number of bytes to write (1-256)
;
FLASH_RR_WRITE		macro	memory_start, flash_start, range
	lfsr	FSR1,memory_start						; set start address in memory
	MOVTT	flash_start,ext_flash_address			; set start address in FLASH
	movlw	low(range)								; set size of range to read
	extern	ext_flash_write_range
	call	ext_flash_write_range					; execute range-write
	endm


; move forward in FLASH with wrap-around at 0x400000 to 0x000000
;
; increment: literal (1-255)
;
ext_flash_inc_address_0x40		macro	increment
		movlw	increment
		extern	incf_ext_flash_address0_0x40
		call	incf_ext_flash_address0_0x40
	endm


; move forward in FLASH with wrap-around at 0x200000 to 0x000000
;
; increment: literal (1-255)
;
ext_flash_inc_address_0x20		macro	increment
		movlw	increment
		extern	incf_ext_flash_address0_0x20
		call	incf_ext_flash_address0_0x20
	endm


; decrement length count
;
; decrement: literal (1-255)
;
ext_flash_dec_length			macro	decrement
		movlw	decrement
		extern	decf_ext_flash_length0
		call	decf_ext_flash_length0
	endm
