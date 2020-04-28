;=============================================================================
;
;   File external_flash.asm                 * combined next generation V3.09.4e
;
;   External flash
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;  2011-08-12 : [mH] creation

	#include "hwos.inc"
	#include "wait.inc"
	#include "eeprom_rs232.inc"

;=============================================================================
ext_flash	CODE
;=============================================================================

;-----------------------------------------------------------------------------
; increase Flash Address by one with wrap-around at 0x400000 to 0x000000
;
ext_flash_inc_address_0x40_p1:
	movlw	.1								; increment by 1
	;bra	ext_flash_inc_address_0x40_exec	; execute incrementing


;-----------------------------------------------------------------------------
; increase Flash Address by Value in WREG with wrap-around at 0x400000 to 0x000000
;
	global	ext_flash_inc_address_0x40_exec
ext_flash_inc_address_0x40_exec:
	clrf	ext_flash_address_limit			; | set wrap-around threshold to
	bsf		ext_flash_address_limit,6		; | 0x40 without destroying WREG
	bra		incf_ext_flash_address0_common	; continue with common part


;-----------------------------------------------------------------------------
; increase Flash Address by one with wrap-around at 0x200000 to 0x000000
;
ext_flash_inc_address_0x20_p1:
	movlw	.1								; increment by one
	;bra	ext_flash_inc_address_0x20_exec	; execute incrementing


;-----------------------------------------------------------------------------
; increase Flash Address by Value in WREG with wrap-around at 0x200000 to 0x000000
;
	global	ext_flash_inc_address_0x20_exec
ext_flash_inc_address_0x20_exec:
	clrf	ext_flash_address_limit			; | set wrap-around threshold to
	bsf		ext_flash_address_limit,5		; | 0x20 without destroying WREG
	;bra	incf_ext_flash_address0_common	; continue with common part


;-----------------------------------------------------------------------------
; common Part for Flash Address Increasing
;
incf_ext_flash_address0_common:
	bcf		flash_wrap_around				; clear wrap-around flag
	addwf	ext_flash_address+0,F			; add WREG to address:3
	movlw	d'0'							; ...
	addwfc	ext_flash_address+1,F			; ...
	addwfc	ext_flash_address+2,F			; ...
	movf	ext_flash_address_limit,W		; get wrap-around threshold
	cpfseq	ext_flash_address+2				; at  wrap-around threshold ?
	bra		incf_ext_flash_address1			; NO  - no wrap-around needed
;	clrf	ext_flash_address+0				; YES - wrap-around to 0x000000
;	clrf	ext_flash_address+1				;     - ...
	clrf	ext_flash_address+2				;     - ...
	bsf		flash_wrap_around				;     - set wrap-around flag
incf_ext_flash_address1:
	movf	ext_flash_rw,W					; export current value of ext_flash_rw via WREG, too
	return									; done


;-----------------------------------------------------------------------------
; add 0x001000 to Flash Address, no Check for wrap-around
;
	global	ext_flash_inc_address_4kB
ext_flash_inc_address_4kB:
	movlw	0x10							; add 0x10 to high byte
	addwf	ext_flash_address+1,F			; ...
	movlw	0x00							; propagate carry to upper byte
	addwfc	ext_flash_address+2,F			; ...
	return									; done


;-----------------------------------------------------------------------------
; decrement Length Counter by 1
;
	global	ext_flash_dec_length_exec
ext_flash_dec_length_exec:
	movlw	.1								; decrement by 1
	subwf	ext_flash_length_counter+0,F	; ...
	movlw	d'0'							; ...
	subwfb	ext_flash_length_counter+1,F	; ...
	subwfb	ext_flash_length_counter+2,F	; ...
	return									; done


;-----------------------------------------------------------------------------
; read a Byte from Flash and increment Address with wrap-around at 0x20 / 0x40
; returns in ext_flash_rw and WREG
;
	global	ext_flash_read_byte_0x40
ext_flash_read_byte_0x40:
	bsf		flash_wrap_around				; wrap-around at 0x400000
	bra		ext_flash_read_byte_common		; continue with common part

	global	ext_flash_read_byte_0x20
ext_flash_read_byte_0x20:
	bcf		flash_wrap_around				; wrap-around at 0x200000
	;bra	ext_flash_read_byte_common		; continue with common part

ext_flash_read_byte_common:
	movlw	0x03							; prepare read command
	rcall	shift_spi						; execute read command
	rcall	ext_flash_set_address			; write 24 bit address ext_flash_address:3 via SPI
	rcall	shift_spi						; shift the SPI to read data into WREG
	bsf		flash_ncs						; set CS=1
	movwf	ext_flash_rw					; copy byte read from WREG to ext_flash_rw
	btfss	flash_wrap_around				; shall wrap-around at 0x40000 ?
	bra		ext_flash_inc_address_0x20_p1	; NO  - increment address with wrap-around at 0x200000 and return
	bra		ext_flash_inc_address_0x40_p1	; YES - increment address with wrap-around at 0x200000 and return


;-----------------------------------------------------------------------------
; Read-Range Base Functions - start reading
;
	global	ext_flash_read_block_start		; return data read in WREG
ext_flash_read_block_start:
	movlw	0x03							; set up  read command
	rcall	shift_spi						; execute read command
	rcall	ext_flash_set_address			; write 24 bit address ext_flash_address:3 via SPI
	bra		shift_spi						; shift the SPI to read data into WREG (and return)


;-----------------------------------------------------------------------------
; Read-Range Base Functions -  increment Address and read a Byte, wrap-around at 0x40
;
	global	ext_flash_read_block_0x40		; return data read in WREG
ext_flash_read_block_0x40:
	rcall	ext_flash_inc_address_0x40_p1	; increase address with wrap-around at 0x400000
	btfss	flash_wrap_around				; did the address wrap-around?
	bra		shift_spi_loop_1				; NO  - shift the SPI to  read data into WREG and return
	rcall	ext_flash_read_block_stop		; YES - do a block-stop
	bra		ext_flash_read_block_start		;     - do a block-start, read data into WREG and return


;-----------------------------------------------------------------------------
; Read-Range Base Functions - increment Address and read a Byte, wrap-around at 0x20
;
;	global	ext_flash_read_block_0x20		; return data read in WREG
;ext_flash_read_block_0x20:
;	rcall	ext_flash_inc_address_0x20_p1	; increase address with wrap-around at 0x200000
;	btfss	flash_wrap_around				; did the address wrap-around?
;	bra		shift_spi_loop_1				; NO  - shift the SPI to  read data into WREG and return
;	rcall	ext_flash_read_block_stop		; YES - do a block-stop
;	bra		ext_flash_read_block_start		;     - do a block-start, read data into WREG and return


;-----------------------------------------------------------------------------
; Read-Range Base Functions - terminate reading
;
	global	ext_flash_read_block_stop		; end block operation
ext_flash_read_block_stop:
	bsf		flash_ncs						; set CS=1
	return									; done


; ----------------------------------------------------------------------------
; read a Range of Bytes, to be used via Macro
;
	global	ext_flash_read_range
ext_flash_read_range:
	movwf	eeprom_loop						; load loop counter (eeprom variable used here)
	rcall	ext_flash_read_block_start		; read first byte from FLASH to WREG
	bra		ext_flash_read_range_loop_start	; jump into loop
ext_flash_read_range_loop:
	rcall	shift_spi_loop_1				; read next  byte from FLASH to WREG
ext_flash_read_range_loop_start:
	movwf	POSTINC1						; write      byte from WREG  to memory
	decfsz	eeprom_loop,F					; decrement loop counter, all done?
	bra		ext_flash_read_range_loop		; NO  - continue loop
	bra		ext_flash_read_block_stop		; YES - end reading from flash (and return)


; ----------------------------------------------------------------------------
; Write-Range Base Functions - for use with SST26VF Chip only!
;
ext_flash_write_block_start:
	movwf	ext_flash_rw					; copy byte to write from WREG to ext_flash_rw
	bsf		flash_ncs						; set CS=1
	movlw	0x06							; set up  WREN command
	rcall	shift_spi						; execute WREN command
	bsf		flash_ncs						; set CS=1
	movlw	0x02							; set up  write (PP, Page-Program) command
	rcall	shift_spi						; execute write
	rcall	ext_flash_set_address			; write 24 bit address ext_flash_address:3 via SPI
	movf	ext_flash_rw,W					; get back byte to write
	bra		shift_spi						; write the byte (and return)

ext_flash_write_block:
	bra		shift_spi_loop_1				; shift the SPI to write data into FLASH (and return)

ext_flash_write_block_stop:
	bra		ext_flash_wait_write			; wait for completion (and return)


; ----------------------------------------------------------------------------
; write a Range of Bytes, to be used via Macro
;
	global	ext_flash_write_range
ext_flash_write_range:
	movwf	eeprom_loop						; load loop counter (eeprom variable used here)

	btfsc	flash_block_write				; does the FLASH support block-write?
	bra		ext_flash_write_range_block		; YES - write data in block      mode
	;bra	ext_flash_write_range_seq		; NO  - write data in sequential mode

	; sequential write
ext_flash_write_range_seq:
	bsf		flash_wait						; wait for flash writes to complete
ext_flash_write_range_seq_loop:
	movf	POSTINC1,W						; copy  byte from memory to WREG
	rcall	ext_flash_byte_write_common_W	; write byte from WREG   to FLASH
	rcall	ext_flash_inc_address_0x40_p1	; increase address with wrap-around at 0x400000
	decfsz	eeprom_loop,F					; decrement loop counter, all done?
	bra		ext_flash_write_range_seq_loop	; NO  - loop
	return									; YES - done

	; block write
ext_flash_write_range_block:
	movf	POSTINC1,W						; copy first byte from memory to WREG
	rcall	ext_flash_write_block_start		; copy first byte from WREG   to FLASH
	bra		ext_flash_write_range_loop_start; jump into loop
ext_flash_write_range_block_loop:
	movf	POSTINC1,W						; copy next  byte from memory to WREG
	rcall	ext_flash_write_block			; copy next  byte from WREG   to FLASH
ext_flash_write_range_loop_start:
	decfsz	eeprom_loop,F					; decrement loop counter, all done?
	bra		ext_flash_write_range_block_loop; NO  - loop
	rcall	ext_flash_write_block_stop		; YES - initiate FLASH write
	clrf	ext_flash_address+0				;     - advance address to start of next block
	infsnz	ext_flash_address+1,F			;     - ...
	incf	ext_flash_address+2,F			;     - ...
	return									;     - done


;-----------------------------------------------------------------------------
; write a Byte with wrap-around at 0x200000,
; erase on entering new 4kB Block,
; increment Dive Length Counter
;
	global	ext_flash_write_byte_0x20_incdc
ext_flash_write_byte_0x20_incdc:
	movwf	ext_flash_rw					; store byte to write
	incf	ext_flash_length_counter+0,F	; increase dive length counter
	movlw	.0								; ...
	addwfc	ext_flash_length_counter+1,F	; ...
	addwfc	ext_flash_length_counter+2,F	; ...
	bra		write_byte_ext_flash_plus_nocnt1; continue with checking for begin of new block


;-----------------------------------------------------------------------------
; write a Byte with wrap-around at 0x200000,
; erase on entering new 4kB Block
; 
	global	ext_flash_write_byte_0x20
ext_flash_write_byte_0x20:
	movwf	ext_flash_rw					; store byte to write
write_byte_ext_flash_plus_nocnt1:
	; check if at 1st byte of a 4kB block,
	; if yes the block needs to be erased
	; before new data can be written to it
	tstfsz	ext_flash_address+0				; is the low byte of the address = 0x00 ?
	bra		write_byte_ext_flash_plus_nodel1; NO  - not at 1st byte, can execute write
	movf	ext_flash_address+1,W			; YES - get high byte of the address
	andlw	0x0F							;     - keep only the lower nibble
	tstfsz	WREG							;     - is the lower nibble = 0x0 ?
	bra		write_byte_ext_flash_plus_nodel1;       NO  - not at 1st byte, can execute write
	rcall	ext_flash_erase_4kB				;       YES - at 1st byte, erase 4kB block
	bra		write_byte_ext_flash_plus_nodel1;           - execute write


;-----------------------------------------------------------------------------
; write a Byte with wrap-around at 0x200000
; NO erase on entering new 4kB Block
;
	global	ext_flash_write_byte_0x20_nodel
ext_flash_write_byte_0x20_nodel:
	movwf	ext_flash_rw					; store byte to write
write_byte_ext_flash_plus_nodel1:
	bsf		flash_wait						; wait for flash write to complete
	rcall	ext_flash_byte_write_common_F	; write the byte in ext_flash_rw
	bra		ext_flash_inc_address_0x20_p1	; increase address with wrap-around at 0x200000 and return


;-----------------------------------------------------------------------------
; write a Byte without Wait (used by comm mode)
;
; time budget for flash to complete a write is ~86 us at 115200 Baud on serial
;
	global	ext_flash_write_byte_0x40_nowait
ext_flash_write_byte_0x40_nowait:
	bcf		flash_wait						; do not wait on flash write to complete
	rcall	ext_flash_byte_write_common_W	; write the byte in WREG
	bra		ext_flash_inc_address_0x40_p1	; increase address with wrap-around at 0x400000 and return


;-----------------------------------------------------------------------------
; internal common Write Functions W: WREG         -> FLASH(ext_flash_address)
;                                 F: ext_flash_rw -> FLASH(ext_flash_address)
;
ext_flash_byte_write_common_W:
	movwf	ext_flash_rw					; copy byte to write from WREG to ext_flash_rw
ext_flash_byte_write_common_F:
	bsf		flash_ncs						; set CS=1
	movlw	0x06							; set up  WREN command
	rcall	shift_spi						; execute WREN command
	bsf		flash_ncs						; set CS=1
	movlw	0x02							; prepare write (PP, Page-Program) command
	rcall	shift_spi						; execute write
	rcall	ext_flash_set_address			; write 24 bit address ext_flash_address:3 via SPI
	movf	ext_flash_rw,W					; get back byte to write
	rcall	shift_spi						; write the byte
	btfsc	flash_wait						; shall wait on flash write to complete?
	bra		ext_flash_wait_write			; YES - wait for completion (and return)
	bsf		flash_ncs						; NO  - set CS=1
	return									;     - done


;-----------------------------------------------------------------------------
; switch off Write-Protection
;
	global	ext_flash_disable_protection	; disable write protection
ext_flash_disable_protection:
	; unlock old memory
	bsf		flash_ncs						; set CS=1
	movlw	0x50							; prepare EWSR command
	rcall	shift_spi						; execute EWSR command
	bsf		flash_ncs						; set CS=1
	movlw	0x01							; prepare WRSR command
	rcall	shift_spi						; execute WRSR command
	movlw	b'00000000'						; prepare new status
	rcall	shift_spi						; set     new status

	; unlock new memory
	bsf		flash_ncs						; set CS=1
	movlw	0x06							; prepare WREN command
	rcall	shift_spi						; execute WREN command
	bsf		flash_ncs						; set CS=1
	movlw	0x98							; prepare ULBPR command
	rcall	shift_spi						; execute ULBPR command
	bsf		flash_ncs						; set CS=1
	movlw	0x06							; prepare WREN command
	rcall	shift_spi						; execute WREN command
	bsf		flash_ncs						; set CS=1
	movlw	0x42							; prepare WBPR command
	rcall	shift_spi						; execute WBPR command

	movlw	.18								; 18 bytes to do
	movwf	lo								; initialize loop counter
ext_flash_disable_prot_loop:
	movlw	0x00							; prepare writing a zero
	rcall	shift_spi						; write a zero
	decfsz	lo,F							; all bytes done?
	bra		ext_flash_disable_prot_loop		; NO  - loop
	bsf		flash_ncs						; YES - set CS=1
	return									;     - done


;-----------------------------------------------------------------------------
; switch on Write-Protection
;
	global	ext_flash_enable_protection
ext_flash_enable_protection:
	; lock old memory
	bsf		flash_ncs						; set CS=1
	movlw	0x50							; prepare EWSR command
	rcall	shift_spi						; execute EWSR command
	bsf		flash_ncs						; set CS=1
	movlw	0x01							; prepare WRSR command
	rcall	shift_spi						; execute WRSR command
	movlw	b'00011100'						; prepare write protection on
	rcall	shift_spi						; execute write protection on

	; lock new memory
	bsf		flash_ncs						; set CS=1
;	movlw	0x06							; prepare WREN command
;	rcall	shift_spi						; execute WREN command
;	bsf		flash_ncs						; set CS=1
;	movlw	0x8D							; prepare LBPR command
;	rcall	shift_spi						; execute LBPR command
;	bsf		flash_ncs						; set CS=1
	movlw	0x06							; prepare WREN command
	rcall	shift_spi						; execute WREN command
	bsf		flash_ncs						; set CS=1
	movlw	0x42							; prepare WBPR command
	rcall	shift_spi						; execute WBPR command

	movlw	.18								; 18 bytes to do
	movwf	lo								; initialize loop counter
ext_flash_enable_prot_loop:
	movlw	0xFF							; prepare writing 0xFF
	rcall	shift_spi						; write a zero
	decfsz	lo,F							; all bytes done?
	bra		ext_flash_enable_prot_loop		; NO  - loop
	bsf		flash_ncs						; YES - set CS=1
	return									;     - done


;-----------------------------------------------------------------------------
; erase complete Logbook
;
	global	erase_complete_logbook
erase_complete_logbook:
	; set address to 0x000000 / prepare a 3 byte zero integer
	CLRT	ext_flash_address

	; clear logbook data in EPROM by writing all zeros
	EEPROM_II_WRITE ext_flash_address,eeprom_num_dives		; reset the total number of dives
	EEPROM_TT_WRITE ext_flash_address,eeprom_log_pointer	; reset pointer to begin of profile data

	; erase logbook data in FLASH from 0x000000 - 0x2FFFFF = 3 MByte = 3 * 256 blocks * 4 kB/block

	clrf	WREG							; erase 256 blocks per call
	rcall	ext_flash_erase_range			; erase 1st bunch of 256 blocks
	rcall	ext_flash_erase_range_loop		; erase 2nd bunch of 256 blocks
	rcall	ext_flash_erase_range_loop		; erase 3rd bunch of 256 blocks
	return									; done


;-----------------------------------------------------------------------------
; erase a Number of 4kB Blocks
;
	global	ext_flash_erase_range
ext_flash_erase_range:
	movwf	eeprom_loop						; initialize loop counter
ext_flash_erase_range_loop:
	rcall	ext_flash_erase_4kB				; erase one block
	rcall	ext_flash_inc_address_4kB		; increase start address by 0x1000 (4kB)
	btfsc	ext_flash_address+2,6			; reached 0x400000 ?
	return									; YES - reached end of address range, done anyhow
	decfsz	eeprom_loop,F					; NO  - decrement number of blocks to do, all blocks done?
	bra		ext_flash_erase_range_loop		;       NO  - loop
	return									;       YES - done, back to command loop


;-----------------------------------------------------------------------------
; erase one 4kB Block
;
	global	ext_flash_erase_4kB
ext_flash_erase_4kB:
	bsf		flash_ncs						; set CS=1
	movlw	0x06							; prepare WREN command
	rcall	shift_spi						; execute WREN command
	bsf		flash_ncs						; set CS=1
	movlw	0x20							; prepare block erase command
	rcall	shift_spi						; execute block erase command
	rcall	ext_flash_set_address			; write 24 bit address ext_flash_address:3 via SPI
	bra		ext_flash_wait_write			; wait for write to complete and return


;-----------------------------------------------------------------------------
; read JEDEC IDs
;
	global	ext_flash_read_jedec
ext_flash_read_jedec:
	movlw	0x9F							; prepare JEDEC read command
	rcall	shift_spi						; execute JEDEC read command
	rcall	shift_spi						; shift the SPI to read the manufacturer ID into WREG
	movwf	lo								; store                 the manufacturer ID in   lo
	rcall	shift_spi						; shift the SPI to read the device type  ID into WREG
	movwf	hi								; store                 the device type  ID in   hi
	rcall	shift_spi						; shift the SPI to read the device model ID into WREG
	movwf	up								; store                 the device model ID in   up
	bsf		flash_ncs						; set CS=1
	return									; done


;-----------------------------------------------------------------------------
; low level Functions - send Address
;
ext_flash_set_address:
	movf	ext_flash_address+2,W			; write 24 bit address ext_flash_address:3 via SPI
	rcall	shift_spi						; ...
	movf	ext_flash_address+1,W			; ...
	rcall	shift_spi						; ...
	movf	ext_flash_address+0,W			; ...
	bra 	shift_spi						; ... and return


;-----------------------------------------------------------------------------
; low level Functions - wait for Completion of a Write Operation
;
ext_flash_wait_write:
	bsf		flash_ncs						; set CS=1
;	WAITMS	d'1'							; TBE/TSE=25ms...
	movlw	0x05							; prepare RDSR command
	rcall	shift_spi						; 1st cycle: execute command to read status
	rcall	shift_spi						; 2nd cycle: read status
	bsf		flash_ncs						; set CS=1
	btfsc	SSP2BUF,0						; write operation still in process?
	bra		ext_flash_wait_write			; YES - loop waiting
	return									; NO  - done


;-----------------------------------------------------------------------------
; low level functions - shift the SPI Bus for a combined Write/Read
;
;      WREG --> write --->\      /---> read --> WREG
;                        flash chip
;
shift_spi:
	bcf		flash_ncs						; set CS=0
shift_spi_loop_1:
	bcf		SSP2STAT,WCOL					; clear flag
	movwf	SSP2BUF							; write to buffer
	btfsc	SSP2STAT,WCOL					; was buffer full?
	bra		shift_spi_loop_1				; YES - try again
shift_spi_loop_2:
	btfss	SSP2STAT,BF						; buffer full?
	bra		shift_spi_loop_2				; NO  - loop waiting
	movf	SSP2BUF,W						; YES - copy received data to WREG
	return									;     - done


 IFDEF _firmware_recovery

;-----------------------------------------------------------------------------
; copy active Firmware to Backup Storage
;
	global	copy_fw_active_to_backup
copy_fw_active_to_backup:
	; erase FLASH for recovery firmware (120 kByte = 30 * 4 kByte)
	rcall	ext_flash_to_recovery_fw				; set ext_flash_address to 0x3C0000
	movlw	.30										; 30 blocks to do
	rcall	ext_flash_erase_range					; erase #WREG 4kB blocks starting at ext_flash_address

	; copy firmware (120 kByte = 2 x 240 x 256 byte)
	rcall	ext_flash_to_productive_fw				; set ext_flash_address to 0x3E0000
	clrf	hi										; flag in 1st round
copy_fw_active_to_backup_loop1:
	movlw	.240									; load loop counter
	movwf	lo										; ...
copy_fw_active_to_backup_loop2:
	; read active firmware
	bsf		ext_flash_address+2,1					; switch to productive firmware
	lfsr	FSR1,buffer								; set start address in memory
	movlw	low(.256)								; set size of range to read
	rcall	ext_flash_read_range					; execute range-read (ext_flash_address NOT  incremented)
	; write to backup storage
	bcf		ext_flash_address+2,1					; switch to backup storage
	lfsr	FSR1,buffer								; set start address in memory
	movlw	low(.256)								; set size of range to write
	rcall	ext_flash_write_range					; execute range-write (ext_flash_address GETS incremented)
	; operate loop
	decfsz	lo,F									; decrement loop counter, done?
	bra		copy_fw_active_to_backup_loop2			; NO  - continue copying
	tstfsz	hi										; YES - 2nd round finished?
	return											;       YES - done
	setf	hi										;       NO  - flag in 2nd round now
	bra		copy_fw_active_to_backup_loop1			;           - start 2nd round


;-----------------------------------------------------------------------------
; copy Backup-Firmware to Update Storage
;
	global	copy_fw_backup_to_active
copy_fw_backup_to_active:
	; erase FLASH for productive firmware (120 kByte = 30 * 4 kByte)
	rcall	ext_flash_to_productive_fw				; set ext_flash_address to 0x3E0000
	movlw	.30										; 30 blocks to do
	rcall	ext_flash_erase_range					; erase #WREG 4kB blocks starting at ext_flash_address

	; copy firmware (120 kByte = 2 x 240 x 256 byte)
	rcall	ext_flash_to_recovery_fw				; set ext_flash_address to 0x3C0000
	clrf	hi										; flag in 1st round
copy_fw_backup_to_active_loop1:
	movlw	.240									; load loop counter
	movwf	lo										; ...
copy_fw_backup_to_active_loop2:
	; read backup firmware
	bcf		ext_flash_address+2,1					; switch to backup firmware
	lfsr	FSR1,buffer								; set start address in memory
	movlw	low(.256)								; set size of range to read
	rcall	ext_flash_read_range					; execute range-read (ext_flash_address NOT  incremented)
	; write to update storage
	bsf		ext_flash_address+2,1					; switch to update storage
	lfsr	FSR1,buffer								; set start address in memory
	movlw	low(.256)								; set size of range to write
	rcall	ext_flash_write_range					; execute range-write (ext_flash_address GETS incremented)
	; operate loop
	decfsz	lo,F									; decrement loop counter, done?
	bra		copy_fw_backup_to_active_loop2			; NO  - continue copying
	tstfsz	hi										; YES - 2nd round finished?
	return											;       YES - done
	setf	hi										;       NO  - flag in 2nd round now
	bra		copy_fw_backup_to_active_loop1			;           - start 2nd round


;-----------------------------------------------------------------------------
; Helper Functions - point ext_flash_address to active / backup firmware storage
;
ext_flash_to_recovery_fw
	movlw	0x3C									; 0x3C|
	bra		ext_flash_common

ext_flash_to_productive_fw:
	movlw	0x3E									; 0x3E|
	;bra	ext_flash_common

ext_flash_common:
	movwf	ext_flash_address+2						; ....|
	clrf	ext_flash_address+1						; ....|00|
	clrf	ext_flash_address+0						; .......|00
	return

 ENDIF

;-----------------------------------------------------------------------------

	END
