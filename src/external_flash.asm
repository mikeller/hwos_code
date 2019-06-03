;=============================================================================
;
;   File external_flash.asm                    combined next generation V3.0.1
;
;   External flash
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;  2011-08-12 : [mH] creation

	#include "hwos.inc"
	#include "wait.inc"

ext_flash	CODE

;=============================================================================

; increase flash address by one
;
	global	incf_ext_flash_address_p1
incf_ext_flash_address_p1:
	movlw	.1
	;bra	incf_ext_flash_address0


; increase flash address by value in WREG
;
	global	incf_ext_flash_address0
incf_ext_flash_address0:
	addwf	ext_flash_address+0,F			; increase address
	movlw	d'0'
	addwfc	ext_flash_address+1,F
	addwfc	ext_flash_address+2,F

	movlw	0x40
	cpfseq	ext_flash_address+2				; at address 40FFFF?
	return									; NO -  return
;	clrf	ext_flash_address+0
;	clrf	ext_flash_address+1
	clrf	ext_flash_address+2				; YES - rollover to 0x000000
	return


; increase flash address by one with roll-over at 0x200000 to 0x000000
;
	global	incf_ext_flash_address0_p1_0x20
incf_ext_flash_address0_p1_0x20:			; increase by one
	movlw	.1
	;bra	incf_ext_flash_address0_0x20


; increase flash address by value in WREG with roll-over at 0x200000 to 0x000000
;
	global	incf_ext_flash_address0_0x20
incf_ext_flash_address0_0x20:
	addwf	ext_flash_address+0,F			; increase address
	movlw	d'0'
	addwfc	ext_flash_address+1,F
	addwfc	ext_flash_address+2,F
	movlw	0x20
	cpfseq	ext_flash_address+2				; at address 0x200000?
	return									; NO  - return
;	clrf	ext_flash_address+0
;	clrf	ext_flash_address+1
	clrf	ext_flash_address+2				; YES - rollover to 0x000000
	return


; decrease flash address by value in WREG
;
	global	decf_ext_flash_address0
decf_ext_flash_address0:
	subwf	ext_flash_address+0,F			; decrease address: do a 16-8bits subtract
	movlw	d'0'
	subwfb	ext_flash_address+1,F
	movlw	d'0'
	subwfb	ext_flash_address+2,F
	btfss	ext_flash_address+2,7			; under-run?
	return									; NO  - return
	clrf	ext_flash_address+2				; YES - set to 0x00FFFFF
	setf	ext_flash_address+1
	setf	ext_flash_address+0
	return


	global	ext_flash_byte_read_plus		; return data read in WREG and SSP2BUF and
ext_flash_byte_read_plus:					; increase address after read
	rcall	ext_flash_byte_read
	movwf	ext_flash_rw					; store received data
	bra		incf_ext_flash_address_p1		; +1 and return


	global	ext_flash_byte_read_plus_0x20	; return data read in WREG and SSP2BUF and 
ext_flash_byte_read_plus_0x20:				; increase address after read with banking at 0x200000
	rcall	ext_flash_byte_read
	movwf	ext_flash_rw					; store received data
	bra		incf_ext_flash_address0_p1_0x20	; +1 and return


	global	ext_flash_byte_read				; return data read in WREG
ext_flash_byte_read:
	movlw	0x03							; read command
	rcall	write_spi
	rcall	ext_flash_write_address			; write 24 bit address ext_flash_address:3 via SPI
	rcall	write_spi						; dummy write to read data into WREG
	bsf		flash_ncs						; CS=1
	movwf	ext_flash_rw
	return									; return data read in WREG and ext_flash_rw


ext_flash_write_address:					; write 24 bit address ext_flash_address:3 via SPI
	movf	ext_flash_address+2,W			; 24 bit address
	rcall	write_spi
	movf	ext_flash_address+1,W
	rcall	write_spi
	movf	ext_flash_address+0,W
	bra 	write_spi						; and return....


	global	ext_flash_read_block_start		; return data read in WREG
ext_flash_read_block_start:
	movlw	0x03							; read command
	rcall	write_spi
	rcall	ext_flash_write_address			; write 24 bit address ext_flash_address:3 via SPI
	rcall	write_spi						; dummy write to read data into WREG
	return									; return data read in WREG


	global	ext_flash_read_block			; return data read in WREG
ext_flash_read_block:
	rcall	incf_ext_flash_address_p1		; increase address +1
	bra		write_spi1						; dummy write to read data into WREG and return


	global	ext_flash_read_block_stop		; return data read in WREG
ext_flash_read_block_stop:
	bsf		flash_ncs						; CS=1
	return									; nO data in WREG


	global	write_byte_ext_flash_plus_header
write_byte_ext_flash_plus_header:			; write from WREG and increase address after write
	movwf	ext_flash_rw					; store data
	; test if write is done at first byte of 4kB block
	; if yes -> delete 4kB block first
	tstfsz	ext_flash_address+0				; at 0x00?
	bra		write_byte_ext_flash_plus_h1	; NO - normal write
	movf	ext_flash_address+1,W
	andlw	0x0F							; mask lower nibble
	tstfsz	WREG							; at 0x.0?
	bra		write_byte_ext_flash_plus_h1	; NO  - normal write
											; YES - at beginning of 4kB block -> erase first!
	rcall	ext_flash_erase4kB				;     - erases 4kB sector @ext_flash_address:3
write_byte_ext_flash_plus_h1:
	movf	ext_flash_rw,W
	rcall	ext_flash_byte_write			; write the byte
	bra		incf_ext_flash_address_p1		; +1 and return


	global	write_byte_ext_flash_plus_nocnt	; no increase of ext_flash_dive_counter:3
write_byte_ext_flash_plus_nocnt:
	movwf	ext_flash_rw					; store data
	bra		write_byte_ext_flash_plus2


	global	write_byte_ext_flash_plus_nodel	; does NOT delete 4kB page when required
write_byte_ext_flash_plus_nodel:			; write from WREG and increase address after write with banking at 0x200000
	movwf	ext_flash_rw					; store data
	bra		write_byte_ext_flash_plus1		; ignore possible begin of 4kB page, there have been written 0xFF already

	global	write_byte_ext_flash_plus		; write from WREG and increase address after write with banking at 0x200000
write_byte_ext_flash_plus:
	movwf	ext_flash_rw					; store data
	; First, increase dive length counter
	incf	ext_flash_dive_counter+0,F
	movlw	.0
	addwfc	ext_flash_dive_counter+1,F
	addwfc	ext_flash_dive_counter+2,F		; 24 bit ++

write_byte_ext_flash_plus2:
	; Now test if write is done at first byte of 4kB block
	; if yes -> delete 4kB block first
	tstfsz	ext_flash_address+0				; at 0x00?
	bra		write_byte_ext_flash_plus1		; NO - normal write
	movf	ext_flash_address+1,W
	andlw	0x0F							; mask lower nibble
	tstfsz	WREG							; at 0x.0?
	bra		write_byte_ext_flash_plus1		; NO  - normal write
											; YES - at beginning of 4kB block -> erase first!
	rcall	ext_flash_erase4kB				;     - erases 4kB sector @ext_flash_address:3
write_byte_ext_flash_plus1:
	movf	ext_flash_rw,W
	rcall	ext_flash_byte_write			; write the byte
	bra		incf_ext_flash_address0_p1_0x20	; +1 and roll over at 0x200000 to 0x000000	and return


	global	ext_flash_byte_write			; write from WREG
ext_flash_byte_write:
	movwf	ext_flash_rw					; store data byte
	bsf		flash_ncs						; CS=1
	movlw	0x06							; WREN command
	rcall	write_spi
	bsf		flash_ncs						; CS=1
	movlw	0x02							; write (PP, Page-Program) command
	rcall	write_spi
	rcall	ext_flash_write_address			; write 24 bit address ext_flash_address:3 via SPI
	movf	ext_flash_rw,W					; load data byte
	rcall	write_spi						; write one byte of data
	bra		ext_flash_wait_write			; and return...


	global	ext_flash_byte_write_comms		; without wait, ~86us fixed delay due to 115200 Baud
ext_flash_byte_write_comms:
	movwf	ext_flash_rw					; store data byte
	bsf		flash_ncs						; CS=1
	movlw	0x06							; WREN command
	rcall	write_spi
	bsf		flash_ncs						; CS=1
	movlw	0x02							; write PP (Page-Program) command
	rcall	write_spi
	rcall	ext_flash_write_address			; write 24 bit address ext_flash_address:3 via SPI
	movf	ext_flash_rw,W					; load data byte
	rcall	write_spi						; write one byte of data
	bsf		flash_ncs						; CS=1
	return


	global	ext_flash_disable_protection	; disable write protection
ext_flash_disable_protection:
	; unlock old memory
	bsf		flash_ncs						; CS=1
	movlw	0x50							; EWSR command
	rcall	write_spi
	bsf		flash_ncs						; CS=1
	movlw	0x01							; WRSR command
	rcall	write_spi
	movlw	b'00000000'						; new status
	rcall	write_spi
	bsf		flash_ncs						; CS=1
	; unlock new memory
	movlw	0x06							; WREN command
	rcall	write_spi
	bsf		flash_ncs						; CS=1
	movlw	0x98							; ULBPR command
	rcall	write_spi
	bsf		flash_ncs						; CS=1
	movlw	0x06							; WREN command
	rcall	write_spi
	bsf		flash_ncs						; CS=1
	movlw	0x42							; WBPR command
	rcall	write_spi
	movlw	.18
	movwf	lo
ext_flash_disable_protection2:
	movlw	0x00
	rcall	write_spi
	decfsz	lo,F							; 18 bytes with 0x00
	bra		ext_flash_disable_protection2
	bsf		flash_ncs						; CS=1
	return


	global	ext_flash_enable_protection
ext_flash_enable_protection:
	; lock old memory
	bsf		flash_ncs						; CS=1
	movlw	0x50							; EWSR command
	rcall	write_spi
	bsf		flash_ncs						; CS=1
	movlw	0x01							; WRSR command
	rcall	write_spi
	movlw	b'00011100'						; new status (write protection on)
	rcall	write_spi
	bsf		flash_ncs						; CS=1
	; lock new memory
;	movlw	0x06							; WREN command
;	rcall	write_spi
;	bsf		flash_ncs						; CS=1
;	movlw	0x8D							; LBPR command
;	rcall	write_spi
;	bsf		flash_ncs						; CS=1
	movlw	0x06							; WREN command
	rcall	write_spi
	bsf		flash_ncs						; CS=1
	movlw	0x42							; WBPR command
	rcall	write_spi
	movlw	.18
	movwf	lo
ext_flash_enable_protection2:
	movlw	0xFF
	rcall	write_spi
	decfsz	lo,F							; 18 bytes with 0xFF
	bra		ext_flash_enable_protection2
	bsf		flash_ncs						; CS=1
	return


	global	ext_flash_erase4kB				; erases 4kB sector
ext_flash_erase4kB:
	bsf		flash_ncs						; CS=1
	movlw	0x06							; WREN command
	rcall	write_spi
	bsf		flash_ncs						; CS=1
	movlw	0x20							; sector erase command
	rcall	write_spi
	rcall	ext_flash_write_address			; write 24 bit address ext_flash_address:3 via SPI
;	bra		ext_flash_wait_write			; wait for write... and return
ext_flash_wait_write:
	bsf		flash_ncs						; CS=1
;	WAITMS	d'1'							; TBE/TSE=25ms...
	movlw	0x05							; RDSR command
	rcall	write_spi						; read status
	rcall	write_spi						; read status into WREG
	bsf		flash_ncs						; CS=1
	btfsc	SSP2BUF,0						; write operation in process?
	bra		ext_flash_wait_write			; ES - loop waiting
	return


	global	ext_flash_erase_logbook			; erases logbook memory (000000h -> 2FFFFFh -> 3MByte -> 3145728 Bytes)
ext_flash_erase_logbook:
	bsf		flash_ncs						; CS=1
	clrf	ext_flash_address+0
	clrf	ext_flash_address+1
	clrf	ext_flash_address+2

	setf	ext_flash_rw					; 256 * 12 kB = 3145728 bytes
ext_flash_erase_logbook_loop:
	rcall	ext_flash_erase4kB				; 4kB
	rcall	ext_flash_add_4kB				; increase ext_flash_address:3 by 4kB
	rcall	ext_flash_erase4kB				; 4kB
	rcall	ext_flash_add_4kB				; increase ext_flash_address:3 by 4kB
	rcall	ext_flash_erase4kB				; 4kB
	rcall	ext_flash_add_4kB				; increase ext_flash_address:3 by 4kB
	decfsz	ext_flash_rw,F					; decrement loop counter, done?
	bra		ext_flash_erase_logbook_loop	; NO  - loop
	return									; YES - done

ext_flash_add_4kB:
	movlw	0x10
	addwf	ext_flash_address+1,F
	movlw	d'0'
	addwfc	ext_flash_address+2,F
	return


write_spi:									; with data in WREG...
	bcf		flash_ncs						; CS
	global	write_spi1
write_spi1:									; with data in WREG...
	bcf		SSP2STAT,WCOL					; clear flag
	movwf	SSP2BUF							; write to buffer
	btfsc	SSP2STAT,WCOL					; was buffer full?
	bra		write_spi1						; YES - try again
write_spi2:									; wait for write command
	btfss	SSP2STAT, BF					; buffer full?
	bra		write_spi2						; NO  - loop waiting
	movf	SSP2BUF,W						; YES - copy RX data to WREG
	return									;     - return with RX data in WREG and SSP2BUF

	END
