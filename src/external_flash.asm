;=============================================================================
;
;   File external_flash.asm                   combined next generation V3.08.8
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

ext_flash	CODE

;=============================================================================

; increase flash address by one with wrap-around at 0x400000 to 0x000000
incf_ext_flash_address_p1_0x40:
	movlw	.1								; increase by 1
	;bra	incf_ext_flash_address0_0x40	; continue


; increase flash address by value in WREG with wrap-around at 0x400000 to 0x000000
	global	incf_ext_flash_address0_0x40
incf_ext_flash_address0_0x40:
	clrf	ext_flash_rollover_threshold	; set wrap-around threshold without destroying WREG to ...
	bsf		ext_flash_rollover_threshold,6	; ... 0x40
	bra		incf_ext_flash_address0_common	; continue with common part


; increase flash address by one with wrap-around at 0x200000 to 0x000000
incf_ext_flash_address_p1_0x20:
	movlw	.1								; increase by one
	;bra	incf_ext_flash_address0_0x20	; continue


; increase flash address by value in WREG with wrap-around at 0x200000 to 0x000000
	global	incf_ext_flash_address0_0x20
incf_ext_flash_address0_0x20:
	clrf	ext_flash_rollover_threshold	; set wrap-around threshold without destroying WREG to ...
	bsf		ext_flash_rollover_threshold,5	; ... 0x20
	;bra	incf_ext_flash_address0_common	; continue with common part


incf_ext_flash_address0_common:
	bcf		address_wrap_around				; clear wrap-around flag
	addwf	ext_flash_address+0,F			; add WREG to address:3
	movlw	d'0'							; ...
	addwfc	ext_flash_address+1,F			; ...
	addwfc	ext_flash_address+2,F			; ...
	movf	ext_flash_rollover_threshold,W	; get wrap-around threshold
	cpfseq	ext_flash_address+2				; at  wrap-around threshold ?
	bra		incf_ext_flash_address1			; NO  - no wrap-around needed
;	clrf	ext_flash_address+0				; YES - wrap-around to 0x000000
;	clrf	ext_flash_address+1				;     - ...
	clrf	ext_flash_address+2				;     - ...
	bsf		address_wrap_around				;     - set wrap-around flag
incf_ext_flash_address1:
	movf	ext_flash_rw,W					; export current value of ext_flash_rw via WREG, too
	return									; done


; decrease flash length counter by value in WREG
	global	decf_ext_flash_length0
decf_ext_flash_length0:
	subwf	ext_flash_length_counter+0,F	; decrease address by value in WREG
	movlw	d'0'							; ...
	subwfb	ext_flash_length_counter+1,F	; ...
	subwfb	ext_flash_length_counter+2,F	; ...
	return									; done

; ----------------------------------------------------------------------------

;	global	ext_flash_byte_read_plus_0x40	; return data read in ext_flash_rw and WREG, increase address after read with wrap-around at 0x400000
;ext_flash_byte_read_plus_0x40:
;	rcall	ext_flash_byte_read				; read byte into ext_flash_rw
;	bra		incf_ext_flash_address_p1_0x40	; increase address with wrap-around at 0x400000 to 0x000000 (and return)


	global	ext_flash_byte_read_plus_0x20	; return data read in ext_flash_rw and WREG, increase address after read with wrap-around at 0x200000
ext_flash_byte_read_plus_0x20:
	rcall	ext_flash_byte_read				; read byte into ext_flash_rw
	bra		incf_ext_flash_address_p1_0x20	; increase address with roll-over at 0x200000 to 0x000000 (and return)


	global	ext_flash_byte_read				; return data read in WREG and ext_flash_rw, no address change
ext_flash_byte_read:
	movlw	0x03							; set up  read command
	rcall	shift_spi						; prepare read command
	rcall	ext_flash_set_address			; write 24 bit address ext_flash_address:3 via SPI
	rcall	shift_spi						; shift the SPI to read data into WREG
	bsf		flash_ncs						; set CS=1
	movwf	ext_flash_rw					; return data read in WREG and ext_flash_rw
	return									; done

; ----------------------------------------------------------------------------
; read-range base functions

	global	ext_flash_read_block_start		; return data read in WREG
ext_flash_read_block_start:
	movlw	0x03							; set up  read command
	rcall	shift_spi						; execute read command
	rcall	ext_flash_set_address			; write 24 bit address ext_flash_address:3 via SPI
	bra		shift_spi						; shift the SPI to read data into WREG (and return)


	global	ext_flash_read_block_0x40		; return data read in WREG
ext_flash_read_block_0x40:
	rcall	incf_ext_flash_address_p1_0x40	; increase address with wrap-around at 0x400000
	btfss	address_wrap_around				; did the address wrap-around?
	bra		shift_spi_loop_1				; NO  - shift the SPI to  read data into WREG and return
	rcall	ext_flash_read_block_stop		; YES - do a block-stop
	bra		ext_flash_read_block_start		;     - do a block-start, read data into WREG and return


	global	ext_flash_read_block_0x20		; return data read in WREG
ext_flash_read_block_0x20:
	rcall	incf_ext_flash_address_p1_0x20	; increase address with wrap-around at 0x200000
	btfss	address_wrap_around				; did the address wrap-around?
	bra		shift_spi_loop_1				; NO  - shift the SPI to  read data into WREG and return
	rcall	ext_flash_read_block_stop		; YES - do a block-stop
	bra		ext_flash_read_block_start		;     - do a block-start, read data into WREG and return


	global	ext_flash_read_block_stop		; end block operation
ext_flash_read_block_stop:
	bsf		flash_ncs						; set CS=1
	return									; done

; ----------------------------------------------------------------------------
; read-range function, to be used through macro
;
	global	ext_flash_read_range
ext_flash_read_range:
	movwf	eeprom_loop						; load loop counter (eeprom variable used here)
	rcall	ext_flash_read_block_start		; read first byte from flash
	bra		ext_flash_read_range_loop_start	; jump into loop
ext_flash_read_range_loop:
	rcall	ext_flash_read_block_0x40		; read next byte from flash
ext_flash_read_range_loop_start:
	movwf	POSTINC1						; write byte to memory
	decfsz	eeprom_loop,F					; decrement loop counter, all done?
	bra		ext_flash_read_range_loop		; NO  - continue loop
	bra		ext_flash_read_block_stop		; YES - end reading from flash (and return)


; ----------------------------------------------------------------------------
; write-range base functions

ext_flash_write_block_start:
	bsf		flash_ncs						; set CS=1
	movlw	0x06							; set up  WREN command
	rcall	shift_spi						; execute WREN command
	bsf		flash_ncs						; set CS=1
	movlw	0x02							; set up  write (PP, Page-Program) command
	rcall	shift_spi						; execute write
	rcall	ext_flash_set_address			; write 24 bit address ext_flash_address:3 via SPI
	movf	ext_flash_rw,W					; get byte to write
	bra		shift_spi						; write the byte (and return)

ext_flash_write_block:
	movf	ext_flash_rw,W					; get byte to write
	bra		shift_spi_loop_1				; shift the SPI to write data into FLASH (and return)

ext_flash_write_block_stop:
	bra		ext_flash_wait_write			; wait for completion (and return)

; ----------------------------------------------------------------------------
; write-range function, to be used through macro
;
	global	ext_flash_write_range
ext_flash_write_range:
	movwf	eeprom_loop						; load loop counter (eeprom variable used here)

;	btfsc	flash_block_write				; does the FLASH support block-write?
;	bra		ext_flash_write_range_block		; YES - write date via block operation
;	;bra	ext_flash_write_range_seq		; NO  - write data via sequential single writes

ext_flash_write_range_seq:					; sequential write
ext_flash_write_range_loop_s:
	movff	POSTINC1,ext_flash_rw			; read  byte from     memory     to  ext_flash_rw
	rcall	ext_flash_byte_write			; write byte from  ext_flash_rw  to     FLASH
	rcall	incf_ext_flash_address_p1_0x40	; increase address with wrap-around at 0x400000
	decfsz	eeprom_loop,F					; decrement loop counter, all done?
	bra		ext_flash_write_range_loop_s	; NO  - continue loop
	return									; YES - done

ext_flash_write_range_block:				; block write
	movff	POSTINC1,ext_flash_rw			; read  first byte from memory
	rcall	ext_flash_write_block_start		; write first byte to FLASH
	bra		ext_flash_write_range_loop_start; jump into loop
ext_flash_write_range_loop_b:
	movff	POSTINC1,ext_flash_rw			; read  next byte from memory
	rcall	ext_flash_write_block			; write next byte to FLASH
ext_flash_write_range_loop_start:
	decfsz	eeprom_loop,F					; decrement loop counter, all done?
	bra		ext_flash_write_range_loop_b	; NO  - continue loop
	bra		ext_flash_write_block_stop		; YES - end writing to flash (and return)

; ----------------------------------------------------------------------------
	
;	global	write_byte_ext_flash_plus_header
; write_byte_ext_flash_plus_header:
;	movwf	ext_flash_rw					; store byte to write
;											 ; test if write is done at first byte of 4kB block, if yes delete 4kB block first
;	tstfsz	ext_flash_address+0				; at 0x....00 ?
;	bra		write_byte_ext_flash_plus_h1	; NO - normal write
;	movf	ext_flash_address+1,W			; YES - get high byte
;	andlw	0x0F							;     - mask lower nibble
;	tstfsz	WREG							;     - at 0x..0...?
;	bra		write_byte_ext_flash_plus_h1	;       NO  - normal write
;	rcall	ext_flash_erase_4kB				;       YES - at beginning of 4kB block -> erases 4kB sector @ext_flash_address:3
;write_byte_ext_flash_plus_h1:
;	rcall	ext_flash_byte_write			; write the byte in ext_flash_rw
;	bra		incf_ext_flash_address_p1_0x40	; increase address with wrap-around at 0x400000 and return


	global	write_byte_ext_flash_plus_prof
write_byte_ext_flash_plus_prof:
	movwf	ext_flash_rw					; store byte to write
	incf	ext_flash_length_counter+0,F	; increase dive length counter
	movlw	.0								; ...
	addwfc	ext_flash_length_counter+1,F	; ...
	addwfc	ext_flash_length_counter+2,F	; ...
	bra		write_byte_ext_flash_plus_nocnt1; continue with checking for begin of new page


	global	write_byte_ext_flash_plus_nocnt
write_byte_ext_flash_plus_nocnt:
	movwf	ext_flash_rw					; store byte to write
write_byte_ext_flash_plus_nocnt1:			; test if write is done at first byte of 4kB block, if yes delete 4kB block first
	tstfsz	ext_flash_address+0				; at 0x....00?
	bra		write_byte_ext_flash_plus_nodel1; NO  - execute write
	movf	ext_flash_address+1,W			; YES - mask lower nibble
	andlw	0x0F							;     - ...
	tstfsz	WREG							;     - at 0x..0...?
	bra		write_byte_ext_flash_plus_nodel1;       NO  - execute write
											;       YES - at beginning of 4kB block -> erase first!
	rcall	ext_flash_erase_4kB				;           - erases 4kB sector @ext_flash_address:3
	bra		write_byte_ext_flash_plus_nodel1;           - execute write


	global	write_byte_ext_flash_plus_nodel
write_byte_ext_flash_plus_nodel:
	movwf	ext_flash_rw					; store byte to write
write_byte_ext_flash_plus_nodel1:
	rcall	ext_flash_byte_write			; write the byte in ext_flash_rw
	bra		incf_ext_flash_address_p1_0x20	; increase address with wrap-around at 0x200000 and return


	global	write_byte_ext_flash_plus_comms	; write from WREG without wait, ~86us fixed delay due to 115200 Baud, use with caution!
write_byte_ext_flash_plus_comms:
	movwf	ext_flash_rw					; store byte to write
	bcf		flash_wait						; do not wait on flash write to complete
	rcall	ext_flash_byte_write_common		; write the byte in ext_flash_rw
	bra		incf_ext_flash_address_p1_0x40	; increase address with wrap-around at 0x400000 and return


ext_flash_byte_write:
	bsf		flash_wait						; wait for flash write to complete
ext_flash_byte_write_common:
	bsf		flash_ncs						; set CS=1
	movlw	0x06							; set up  WREN command
	rcall	shift_spi						; execute WREN command
	bsf		flash_ncs						; set CS=1
	movlw	0x02							; set up  write (PP, Page-Program) command
	rcall	shift_spi						; execute write
	rcall	ext_flash_set_address			; write 24 bit address ext_flash_address:3 via SPI
	movf	ext_flash_rw,W					; get byte to write
	rcall	shift_spi						; write the byte
	btfsc	flash_wait						; shall wait on flash write to complete?
	bra		ext_flash_wait_write			; YES - wait for completion (and return)
	bsf		flash_ncs						; NO  - set CS=1
	return									;     - done

; ----------------------------------------------------------------------------

	global	ext_flash_disable_protection	; disable write protection
ext_flash_disable_protection:
	; unlock old memory
	bsf		flash_ncs						; CS=1
	movlw	0x50							; EWSR command
	rcall	shift_spi
	bsf		flash_ncs						; CS=1
	movlw	0x01							; WRSR command
	rcall	shift_spi
	movlw	b'00000000'						; new status
	rcall	shift_spi
	bsf		flash_ncs						; CS=1
	; unlock new memory
	movlw	0x06							; WREN command
	rcall	shift_spi
	bsf		flash_ncs						; CS=1
	movlw	0x98							; ULBPR command
	rcall	shift_spi
	bsf		flash_ncs						; CS=1
	movlw	0x06							; WREN command
	rcall	shift_spi
	bsf		flash_ncs						; CS=1
	movlw	0x42							; WBPR command
	rcall	shift_spi
	movlw	.18								; 18 bytes to do
	movwf	lo								; initialize loop counter
ext_flash_disable_prot_loop:
	movlw	0x00							; prepare writing a zero
	rcall	shift_spi						; execute write
	decfsz	lo,F							; all bytes done?
	bra		ext_flash_disable_prot_loop		; NO  - loop
	bsf		flash_ncs						; YES - set CS=1
	return									;     - done


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
	bsf		flash_ncs						; set CS=1
	; lock new memory
;	movlw	0x06							; WREN command
;	rcall	shift_spi
;	bsf		flash_ncs						; CS=1
;	movlw	0x8D							; LBPR command
;	rcall	shift_spi
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
	rcall	shift_spi						; execute write
	decfsz	lo,F							; all bytes done?
	bra		ext_flash_enable_prot_loop		; NO  - loop
	bsf		flash_ncs						; YES - set CS=1
	return									;     - done

; ----------------------------------------------------------------------------

	global	erase_complete_logbook
erase_complete_logbook:
	; clear logbook data in EPROM
	CLRT	mpr								; prepare a 3 byte zero integer
	EEPROM_II_WRITE mpr,eeprom_num_dives	; reset total number of dives
	EEPROM_TT_WRITE mpr,eeprom_log_pointer	; reset pointer to begin of log data
	; erase logbook data in FLASH (0x000000 -> 0x2FFFFF -> 3 MByte -> 3145728 Bytes)
	bsf		flash_ncs						; CS=1
	clrf	ext_flash_address+0				; set address to 0x000000
	clrf	ext_flash_address+1				; ...
	clrf	ext_flash_address+2				; ...
	clrf	ext_flash_rw					; write zeros
ext_flash_erase_logbook_loop:				; 256 * 12 kB = 3.145.728 bytes to do
	rcall	ext_flash_erase_4kB				; erase 4kB block
	rcall	ext_flash_add_4kB				; increase ext_flash_address:3 by 4kB
	rcall	ext_flash_erase_4kB				; erase 4kB block
	rcall	ext_flash_add_4kB				; increase ext_flash_address:3 by 4kB
	rcall	ext_flash_erase_4kB				; erase 4kB block
	rcall	ext_flash_add_4kB				; increase ext_flash_address:3 by 4kB
	decfsz	ext_flash_rw,F					; decrement loop counter, done?
	bra		ext_flash_erase_logbook_loop	; NO  - loop
	return									; YES - done


	global	ext_flash_erase_4kB				; erase a 4kB sector
ext_flash_erase_4kB:
	bsf		flash_ncs						; set CS=1
	movlw	0x06							; prepare WREN command
	rcall	shift_spi						; execute WREN command
	bsf		flash_ncs						; set CS=1
	movlw	0x20							; prepare sector erase command
	rcall	shift_spi						; execute sector erase command
	rcall	ext_flash_set_address			; write 24 bit address ext_flash_address:3 via SPI
	bra		ext_flash_wait_write			; wait for write to complete and return

; ----------------------------------------------------------------------------

; send address
ext_flash_set_address:
	movf	ext_flash_address+2,W			; write 24 bit address ext_flash_address:3 via SPI
	rcall	shift_spi						; ...
	movf	ext_flash_address+1,W			; ...
	rcall	shift_spi						; ...
	movf	ext_flash_address+0,W			; ...
	bra 	shift_spi						; ... and return

; wait on write operation to complete
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

; add 0x001000 to flash address
ext_flash_add_4kB:
	movlw	0x10							; add 0x10 to high byte
	addwf	ext_flash_address+1,F			; ...
	movlw	d'0'							; propagate carry to upper byte
	addwfc	ext_flash_address+2,F			; ...
	return									; done

; shift the SPI bus for a combined write/read: WREG --->\      /---> WREG
shift_spi:                                  ;          flash chip
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

	END
