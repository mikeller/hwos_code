;=============================================================================
;
;   File external_flash.inc                    combined next generation V3.0.1
;
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;  2011-08-12 : [mH] creation

; Misc
	extern	incf_ext_flash_address_p1			; +1 for the ext_flash_address:3
	extern	ext_flash_disable_protection		; disables write protection
	extern	ext_flash_enable_protection			; enables  write protection

; Writes
	extern	write_byte_ext_flash_plus			; write from WREG and increase address after write with banking at 0x200000
	extern	write_byte_ext_flash_plus_nocnt		; no increase of ext_flash_dive_counter:3
	extern	write_byte_ext_flash_plus_nodel		; does NOT delete 4kB Page when required
	extern	write_byte_ext_flash_plus_header	; write from WREG and increase address after write
	extern	ext_flash_byte_write				; writes one byte from WREG @ext_flash_address:3
	extern	ext_flash_byte_write_comms			; without wait, ~86us fixed delay due to 115200 Bauds (Use with caution)
	extern	write_spi1							; just (dummy)write to read a byte

; Delete
	extern	ext_flash_erase_logbook				; erases logbook memory (000000h -> 2FFFFFh -> 3MByte)
	extern	ext_flash_erase4kB					; erases 4kB sector @ext_flash_address:3

; Reads
	extern	ext_flash_read_block_start			; block read start and reads one byte@ext_flash_address:3 into WREG
	extern	ext_flash_read_block				; read another byte into WREG
	extern	ext_flash_read_block_stop			; stop block read
	extern	ext_flash_byte_read					; read one byte@ext_flash_address:3 into WREG and ext_flash_rw 
	extern	ext_flash_byte_read_plus			; return data read in WREG and ext_flash_rw and increase address after read with banking at 0x200000
	extern	ext_flash_byte_read_plus_0x20		; return data read in WREG and ext_flash_rw


;-----------------------------------------------------------------------------
; Macros

; decrease ext_flash_address:2 by the 8 bit value "ext_flash_temp1"
	extern	decf_ext_flash_address0
decf_ext_flash_address	macro	ext_flash_temp1
		movlw	ext_flash_temp1
		call	decf_ext_flash_address0
	endm

; increase ext_flash_address:2 by the 8 bit value "ext_flash_temp1"
	extern	incf_ext_flash_address0
incf_ext_flash_address	macro	ext_flash_temp1
		movlw	ext_flash_temp1
		call	incf_ext_flash_address0
	endm

; increase ext_flash_address:2 by the 8 bit value "ext_flash_temp1" with banking at 0x200000
	extern	incf_ext_flash_address0_0x20
incf_ext_flash_address_0x20	macro	ext_flash_temp1
		movlw	ext_flash_temp1
		call	incf_ext_flash_address0_0x20
	endm
