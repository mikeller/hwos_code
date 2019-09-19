;=============================================================================
;
;   File comm.asm                             combined next generation V3.04.3
;
;   RS232 via USB
;
;   Copyright (c) 2012, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;  2011-08-22 : [mH] Creation
;  2012-02-11 : [jDG] Added "c" set custom text, and "i" identify

#include "hwos.inc"
#include "eeprom_rs232.inc"
#include "tft.inc"
#include "wait.inc"
#include "strings.inc"
#include "convert.inc"
#include "external_flash.inc"
#include "tft_outputs.inc"
#include "surfmode.inc"
#include "rtc.inc"
#include "adc_lightsensor.inc"
#include "shared_definitions.h"
#include "math.inc"

	extern	restart
	extern	option_reset_all
	extern	option_check_all
	extern	gaslist_cleanup_list
	extern	option_save_all
	extern	vault_decodata_into_eeprom


#DEFINE timeout_comm_pre_mode	.240	; timeout before communication is established
#DEFINE timeout_service_mode	.120	; timeout when communication is established

#DEFINE comm_title_row			.0		; positioning of title
#DEFINE comm_title_column_usb	.40
#DEFINE comm_title_column_ble	.25

#DEFINE comm_string_row			.30		; positioning of host-sent text messages
#DEFINE comm_string_column		.40

#DEFINE comm_status1_row		.70		; positioning of COMM mode status messages
#DEFINE comm_status1_column		.10
#DEFINE comm_status2_row		.100
#DEFINE comm_status2_column		comm_status1_column
#DEFINE comm_status3_row		.130
#DEFINE comm_status3_column		comm_status1_column
#DEFINE	comm_status4_row		.160
#DEFINE	comm_status4_column		comm_status1_column

#DEFINE comm_warning_row		.160	; positioning of COMM mode warning messages
#DEFINE comm_warning_column		.65


comm	CODE

;=============================================================================

	global	comm_mode_usb
comm_mode_usb:										; entry point for comm mode via USB
	WAITMS	d'1'									; wait 1 ms
	btfss	vusb_in									; USB still plugged in?
	return											; NO - it was only a glitch, abort
	WAITMS	d'1'									; wait 1 ms
	btfss	vusb_in									; USB still plugged in?
	return											; NO  - it was only a glitch, abort
	bsf		aux_flag								; YES - remember to show USB title
	bra		comm_mode_common						;     - continue with common part

	global	comm_mode_ble
comm_mode_ble:										; entry point for comm mode via BLE
	bcf		aux_flag								; remember to show BLE title
	;bra	comm_mode_common						; continue with common part

comm_mode_common:
	clrf	STKPTR									; clear return addresses stack
	call	TFT_ClearScreen							; clear screen
	WIN_COLOR color_greenish						; set color
	btfss	aux_flag								; shall show USB title?
	bra		comm_mode_common_1						; NO
	WIN_SMALL comm_title_column_usb, comm_title_row	; YES - set   USB title position
	STRCPY_TEXT_PRINT tUsbTitle						;     - print USB title text
	bra		comm_mode_common_2
comm_mode_common_1:
	WIN_SMALL comm_title_column_ble, comm_title_row	; set   BLE title position
	STRCPY_TEXT_PRINT tBleTitle						; print BLE title text
comm_mode_common_2:
	call	TFT_standard_color						; set standard color
	WIN_TOP  .10									; positioning of USB/BLE logo, row
	WIN_LEFT .1										; positioning of USB/BLE logo, column
	btfsc	battery_gauge_available					; "+" bootloader ?
	bra		comm_mode_common_3						; NO
	TFT_WRITE_PROM_IMAGE_BY_ADDR usb_ble_logo_2		; YES - show USB/BLE logo 2
	bra		comm_mode_common_4
comm_mode_common_3:
	TFT_WRITE_PROM_IMAGE_BY_ADDR usb_ble_logo_1		; NO  - show USB/BLE logo 1
comm_mode_common_4:
	WIN_SMALL comm_status1_column,comm_status1_row	; positioning of status message
	STRCPY_TEXT_PRINT tUsbStarting					; print status message "starting..."
	WIN_TINY .40,.240-.16							; set output position to bottom line
	call	TFT_show_serial_and_firmware			; show serial number and firmware version
	call	option_save_all							; save all settings into EEPROM (comm mode may be entered after settings have been changed without leaving the menu in between)

 IFDEF _screendump
	bcf		screen_dump_avail			; disable screen dump function
 ENDIF

	bcf		switch_right				; clear left-over right button event
	bcf		comm_service_enabled		; communication is not yet established
	bsf		surfmode_menu				; flag that restart will be entered from surface menu / comm mode
	movlw	timeout_comm_pre_mode		; get timeout for phase without communication established yet
	movwf	comm_timeout_timer			; initialize timeout counter
	WIN_SMALL comm_status1_column+.80,comm_status1_row
	STRCPY_TEXT_PRINT tUsbStartDone		; add to status message "done..."
	call	enable_rs232				; enable serial comm, also sets CPU to normal speed
comm_mode1:
	bcf		trigger_full_second			; clear 'one second elapsed' flag
	bcf		LEDr						; switch off red LED / power down TR co-processor
	dcfsnz	comm_timeout_timer,F		; decrement timeout, reached zero?
	bra		comm_service_exit			; YES - timeout, exit comm mode
comm_mode2:
	rcall	comm_get_byte				; read 1 byte from RX buffer
	movlw	0xAA						; coding of service mode start byte: 0xAA
	cpfseq	RCREG1						; received service mode start byte?
	bra		comm_mode2a					; NO  - probe for download mode
	bra		comm_mode2b					; YES - received start byte for service mode
comm_mode2a:
	movlw	0xBB						; coding of download mode start byte: 0xBB
	cpfseq	RCREG1						; received download mode start byte?
	bra		comm_mode2c					; NO 
	bra		comm_download_mode			; YES - received start byte for download mode
comm_mode2c:
	btfsc	ble_available				; BLE available?
	bra		comm_mode4a					; YES - skip USB check check (required for very old OSTC sport)
	btfss	vusb_in						; USB plugged in?
	bra		comm_service_exit_nousb_delay; NO - disconnected, exit comm mode
comm_mode4a:
	btfsc	switch_right				; right button pressed?
	bra		comm_service_exit			; YES - exit comm mode
	btfsc	trigger_full_second			; NO  - did 1 second elapsed meanwhile?
	bra		comm_mode1					;       YES - loop with    clocking down timeout counter
	bra		comm_mode2					;       NO  - loop without clocking down timeout counter

; received start byte for service mode
comm_mode2b:
	rcall	comm_write_byte				; wait for completion of transmit
	movlw	0x4B						; prepare answer
	movwf	TXREG1						; send    answer
	; check if correct service key is received
	rcall	comm_get_byte				; receive first byte
	rcall	comm_write_byte				; wait for completion of transmit
	movff	RCREG1,TXREG1				; echo received byte
	movlw	UPPER comm_service_key		; load expected byte
	cpfseq	RCREG1						; received expected byte?
	bra		comm_mode1					; NO - restart
	rcall	comm_get_byte				; receive second byte
	rcall	comm_write_byte				; wait for completion of transmit
	movff	RCREG1,TXREG1				; echo received byte
	movlw	HIGH (comm_service_key & 0xFFFF) ; load expected byte
	cpfseq	RCREG1						; received expected byte?
	bra		comm_mode1					; NO - restart
	rcall	comm_get_byte				; receive third byte
	rcall	comm_write_byte				; wait for completion of transmit
	movff	RCREG1,TXREG1				; echo received byte
	movlw	LOW comm_service_key		; load expected byte
	cpfseq	RCREG1						; received expected byte?
	bra		comm_mode1					; NO - restart
										; YES to all - enable com service mode
	WIN_SMALL comm_status2_column, comm_status2_row
	STRCPY_TEXT_PRINT tUsbServiceMode	; print service mode enabled message
	bsf		comm_service_enabled		; set flag for com service mode enabled
	bra		comm_download_mode0			; continue using common routine

comm_service_exit_nousb_delay:
	WAITMS	d'200'						; wait 200 ms
	btfsc	vusb_in						; USB plugged in?
	bra		comm_mode4a					; YES - (still) connected, return
comm_service_exit_nousb:
	bcf		LEDr						; switch off red LED
	WIN_SMALL comm_status3_column, comm_status3_row
	STRCPY_TEXT_PRINT tUsbClosed		; print port closed message
	bra		comm_service_exit_common	; exit to restart

comm_service_exit:
	WIN_SMALL	comm_status3_column, comm_status3_row
	STRCPY_TEXT_PRINT	tUsbExit		; print exited message
comm_service_exit_common:
	rcall	comm_write_byte				; wait for completion of transmit
	movlw	0xFF						; prepare reply "FF"
	movwf	TXREG1						; send    reply
	call	wait_1s						; wait <= 1 second
	call	wait_1s						; wait    1 second
	call	disable_rs232				; shut down comm port
	goto	restart						; restart


;-----------------------------------------------------------------------------
; Start Bootloader
;
comm_service_ll_bootloader:
	bsf		LEDr										; switch on red LED
	WIN_SMALL comm_status3_column, comm_status3_row
	STRCPY_TEXT_PRINT tUsbLlBld							; print low level bootloader started message
	WIN_TOP  comm_warning_row							; set row for icon
	WIN_LEFT comm_warning_column						; set column for icon
	TFT_WRITE_PROM_IMAGE_BY_LABEL dive_warning2_block	; show the warning icon
	goto	0x1FF0C										; jump into the bootloader code


;-----------------------------------------------------------------------------
; Send Firmware to Bootloader
;
comm_send_firmware:
	movlw	0x50						; prepare reply
	movwf	TXREG1						; send    reply
	rcall	comm_write_byte				; wait for completion of transmit
	lfsr	FSR2,buffer					; load base address of buffer
	movlw	.5							; read 5 bytes into buffer
	movwf	lo							; initialize loop counter
	movlw	0x55						; initialize checksum byte
	movwf	hi							; store in hi
comm_send_firmware_loop:
	rcall	comm_get_byte				; receive one byte
	btfsc	rs232_rx_timeout			; got a byte?
	bra		comm_send_firmware_abort	; NO  - abort
	movf	RCREG1,W					; YES - copy received byte to WREG
	movwf	POSTINC2					;     - copy received byte to buffer
	xorwf	hi,F						;     - xor  received byte into checksum
	rlncf	hi,F						;     - rotate checksum byte
	decfsz	lo,F						;     - decrement loop counter, done?
	bra		comm_send_firmware_loop		;       NO  - loop
	movf	hi,W						;       YES - copy checksum to WREG, zero flag set?
	bnz		comm_send_firmware_failed	;             NO - checksum test failed
	movlw	0x4C						;             YES - checksum ok, prepare reply
	movwf	TXREG1						;                 - send reply
	rcall	comm_write_byte				;                 - wait for completion of transmit
	call	vault_decodata_into_eeprom	;                 - store last deco data (and time/date) to EEPROM
	goto	0x1FDF0						;                 - jump into the bootloader code

comm_send_firmware_failed:
	WIN_SMALL comm_string_column, comm_string_row
	call	TFT_warning_color			; set warning color
	STRCPY_PRINT "Checksum failed"		; print failure message
comm_send_firmware_abort:
	movlw	0xFF						; prepare reply for ABORTED
	movwf	TXREG1						; send reply
	bra		comm_download_mode0			; done


;-----------------------------------------------------------------------------
; Reset to Dive 1 in Logbook
;
comm_reset_logbook_pointers:
	call	eeprom_reset_logbook_pointers	; clear logbook pointers in EEPROM
	call	ext_flash_erase_logbook			; clear complete logbook(!)
	bra		comm_download_mode0				; done

;-----------------------------------------------------------------------------
; Reset Battery Gauge
;
comm_reset_battery_gauge:				; reset battery gauge registers
	call	reset_battery_pointer		; reset battery pointer 0x07-0x0C and battery gauge
	bra		comm_download_mode0			; done

;-----------------------------------------------------------------------------
; Erase a Memory Range given byte Start Address and Number of 4 kB Blocks
;
comm_erase_range4kb:
	movlw	0x42						; prepare reply
	movwf	TXREG1						; send reply
	rcall	comm_write_byte				; wait for completion of transmit
	bcf		INTCON,GIE					; disable all interrupts
	rcall	comm_get_flash_address		; get three bytes start address or return
	btfsc	rs232_rx_timeout			; got start address?
	bra		comm_download_mode0			; NO  - done
	rcall	comm_get_byte				; YES - get number of blocks
	btfsc	rs232_rx_timeout			;     - got number?
	bra		comm_download_mode0			;       NO  - done
	movff	RCREG1,lo					;       YES - copy number of blocks to lo
comm_erase_range4kb_loop:
	call	ext_flash_erase4kB			;           - erase a memory block
	movlw	0x10						;           - increase start address by 4096 (0x1000)
	addwf	ext_flash_address+1,F		;           - ...
	movlw	.0							;           - ...
	addwfc	ext_flash_address+2,F		;           - ...
	decfsz	lo,F						;           - decrement block counter, all blocks done?
	bra		comm_erase_range4kb_loop	;             NO  - loop
	bra		comm_download_mode0			;             YES - done

;-----------------------------------------------------------------------------
; Erase one Memory Block of 4 kB Size
;
comm_erase_4kb:
	bcf		INTCON,GIE					; disable all interrupts
	rcall	comm_get_flash_address		; get three bytes start address or return
	btfsc	rs232_rx_timeout			; got start address?
	bra		comm_download_mode0			; NO  - done
	call	ext_flash_erase4kB			; YES - erase memory block
	bra		comm_download_mode0			;     - done

;-----------------------------------------------------------------------------
; Write a Stream of Data Bytes to Memory
;
comm_write_range:
	movlw	0x30						; prepare reply
	movwf	TXREG1						; send    reply
	rcall	comm_write_byte				; wait for completion of transmit
	bcf		INTCON,GIE					; disable all interrupts
	rcall	comm_get_flash_address		; get three bytes starts address or return
	btfsc	rs232_rx_timeout			; got start address?
	bra		comm_download_mode0			; NO  - done
comm_write_range_loop:
	rcall	comm_get_byte				; YES - get data byte to write to memory
	btfsc	rs232_rx_timeout			; got byte?
	bra		comm_download_mode0			; NO  - done
	movf	RCREG1,W					; YES - copy received data byte to WREG
;	bsf		NCTS						;     - hold Bluetooth chip (requires PC/Android/iOS side to use flow control...)
	call	ext_flash_byte_write_comms	;     - write data byte to flash memory
;	bcf		NCTS						;     - release Bluetooth chip (requires PC/Android/iOS side to use flow control...)
	call	incf_ext_flash_address_p1	;     - increase address
	bra		comm_write_range_loop		;     - loop


;-----------------------------------------------------------------------------
; Read a Memory Section given by Start Address and Length
;
comm_send_range:
	movlw	0x20						; prepare reply
	movwf	TXREG1						; send    reply
	rcall	comm_write_byte				; wait for completion of transmit
	bcf		INTCON,GIE					; disable all interrupts
	rcall	comm_get_flash_address		; get three bytes start address or return
	btfsc	rs232_rx_timeout			; got start address?
	bra		comm_download_mode0			; NO - done
	rcall	comm_get_byte				; get length, 3rd byte
	btfsc	rs232_rx_timeout			; got byte?
	bra		comm_download_mode0			; NO - done
	movff	RCREG1,up					; store length, 3rd byte
	rcall	comm_get_byte				; get length, 2nd byte
	btfsc	rs232_rx_timeout			; got byte?
	bra		comm_download_mode0			; NO - done
	movff	RCREG1,hi					; store length, 2nd byte
	rcall	comm_get_byte				; get length, 1st byte
	btfsc	rs232_rx_timeout			; got byte?
	bra		comm_download_mode0			; NO - done
	movff	RCREG1,lo					; store length, 1st byte
	; if lo==0, we must precondition hi because there are too many bytes sent
	movf	lo,W
	bnz		$+4
	decf	hi,F
	movlw	0x40
	cpfslt	up							; up > 0x3F ?
	bra		comm_download_mode0			; YES - abort
	; 6 bytes received, send data
	; needs ext_flash_address:3 start address and up:hi:lo amount
	call	ext_flash_read_block_start
	movwf	TXREG1
	bra		comm_send_range24			; counter 24 bit
comm_send_range24_loop:
	call	ext_flash_read_block		; read one byte
	movwf	TXREG1						; start new transmit
comm_send_range24:
	rcall	comm_write_byte				; wait for completion of transmit
	decfsz	lo,F
	bra		comm_send_range24_loop
	decf	hi,F
	movlw	0xFF
	cpfseq	hi
	bra		comm_send_range24_loop
	decf	up,F
	movlw	0xFF
	cpfseq	up
	bra		comm_send_range24_loop
	call	ext_flash_read_block_stop
	bra		comm_download_mode0			; done

;-----------------------------------------------------------------------------

comm_get_flash_address:
	rcall	comm_get_byte
	btfsc	rs232_rx_timeout			; got byte?
	return								; NO - return
	movff	RCREG1,ext_flash_address+2
	rcall	comm_get_byte
	btfsc	rs232_rx_timeout			; got byte?
	return								; NO - return
	movff	RCREG1,ext_flash_address+1
	rcall	comm_get_byte
	btfsc	rs232_rx_timeout			; got byte?
	return								; NO - return
	movff	RCREG1,ext_flash_address+0
	return

;-----------------------------------------------------------------------------

comm_download_mode:
	; Enable comm download mode
	WIN_SMALL comm_status2_column, comm_status2_row
	STRCPY_TEXT_PRINT tUsbDownloadMode	; download mode enabled
	bsf		INTCON,GIE					; all interrupts on
	rcall	comm_write_byte				; wait for completion of transmit
	movlw	0xBB						; command echo
	movwf	TXREG1						; send answer
comm_download_mode0:
	bsf		INTCON,GIE					; all interrupts on
	rcall	comm_write_byte				; wait for completion of transmit
	movlw	0x4C						; default reply is 4C for service mode
	btfss	comm_service_enabled		; com service enabled?
	movlw	0x4D						; NO - change to reply 4D for download mode
	movwf	TXREG1						; send answer
	movlw	timeout_service_mode		; get timeout value
	movwf	comm_timeout_timer			; load into timeout counter
	bcf		switch_right				; clear left-over button event
comm_download_mode1:
	bcf		trigger_full_second			; clear 'one second elapsed' flag
	dcfsnz	comm_timeout_timer,F		; decrement timeout, reached zero?
	bra		comm_service_exit			; YES - exit
comm_download_mode2:
	rcall	comm_get_byte				; NO - check for a byte
	btfsc	comm_service_enabled		;      com service mode enabled?
	btg		LEDr						;      YES - blink in service mode
	btfsc	ble_available				;      BLE available?
	bra		comm_download_mode3			;      YES - skip USB check (required for very old OSTC sport)
	btfss	vusb_in						;      USB plugged in?
	bra		comm_service_exit_nousb		;      NO  - disconnected -> exit
comm_download_mode3:
	btfsc	switch_right				; shall abort?
	bra		comm_service_exit			; YES
	btfsc	trigger_full_second			; NO  - did 1 second elapsed meanwhile?
	bra		comm_download_mode1			;       YES - check for timeout
	btfsc	rs232_rx_timeout			;       NO  - got a byte?
	bra		comm_download_mode2			;             NO - loop waiting for command byte
	; Command received
	bcf		LEDr
	movlw	0xFF
	cpfseq	RCREG1
	bra		$+4
	bra		comm_service_exit			; exit
	movlw	"a"
	cpfseq	RCREG1
	bra		$+4
	bra		comm_send_headers			; send all 256 dive headers
	movlw	"b"
	cpfseq	RCREG1
	bra		$+4
	bra		comm_set_time				; read time and date from the PC and set clock
	movlw	"c"
	cpfseq	RCREG1
	bra		$+4
	bra		comm_set_custom_text		; send a opt_name_length byte string of custom text
	movlw	"f" 						; 0x66
	cpfseq	RCREG1
	bra		$+4
	bra		comm_send_dive				; send header and profile for one dive
	movlw	"i"
	cpfseq	RCREG1
	bra		$+4
	bra		comm_identify				; send firmware, serial, etc.
	movlw	"j"
	cpfseq	RCREG1
	bra		$+4
	bra		comm_hardware_descriptor	; send hardware descriptor byte
	movlw	0x60
	cpfseq	RCREG1
	bra		$+4
	bra		comm_feature_and_hardware	; send more detailed information
	movlw	"n"
	cpfseq	RCREG1
	bra		$+4
	goto	comm_send_string			; send a 15 byte string to the screen
	movlw	"m"
	cpfseq	RCREG1
	bra		$+4
	goto	comm_send_compact_headers	; send all 256 compact headers
 IFDEF _screendump
	movlw	"l"
	cpfseq	RCREG1
	bra	$+4
	call	TFT_dump_screen				; dump the screen contents
 ENDIF
	movlw	"r"
	cpfseq	RCREG1
	bra		$+4
	bra		comm_read_setting			; read a setting (and send via USB)
	movlw	"w"
	cpfseq	RCREG1
	bra		$+4
	bra		comm_write_setting			; write a setting (into RAM)
	movlw	"x"
	cpfseq	RCREG1
	bra		$+4
	bra		comm_option_reset_all		; reset all options to factory default

	btfss	comm_service_enabled		; done for download mode
	bra		comm_download_mode0			; loop with timeout reset

	movlw	0x20
	cpfseq	RCREG1
	bra		$+4
	bra		comm_send_range				; send hi:lo:ext_flash_rw bytes starting from ext_flash_address:3
	movlw	0x22
	cpfseq	RCREG1
	bra		$+4
	bra		comm_reset_logbook_pointers	; reset all logbook pointers and the logbook
	movlw	0x23
	cpfseq	RCREG1
	bra		$+4
	bra		comm_reset_battery_gauge	; reset battery gauge registers
	movlw	0x30
	cpfseq	RCREG1
	bra		$+4
	bra		comm_write_range			; write bytes starting from ext_flash_address:3 (stop when timeout)
	movlw	0x40
	cpfseq	RCREG1
	bra		$+4
	bra		comm_erase_4kb				; erase 4 kB block from ext_flash_address:3 (Warning: no confirmation or built-in security here...)
	movlw	0x42
	cpfseq	RCREG1
	bra		$+4
	bra		comm_erase_range4kb			; erase range in 4 kB steps (get 3 bytes address and 1 byte amount of 4 kB blocks)
	movlw	0x50
	cpfseq	RCREG1
	bra		$+4
	bra		comm_send_firmware			; send firmware to bootloader
;	movlw	"t"
;	cpfseq	RCREG1
;	bra		$+4
;	goto	testloop					; start raw-data test loop
	movlw	0xC1
	cpfseq	RCREG1
	bra		$+4
	bra		comm_service_ll_bootloader	; start low-level bootloader
	bra		comm_download_mode0			; loop with timeout reset

;-----------------------------------------------------------------------------

comm_send_compact_headers:
	movlw	"m"							; send echo
	movwf	TXREG1
	; send 13 bytes/dive (compact header)
	; 1st: 200009h-200016h
	; 2nd: 201009h-201016h
	; 3rd: 202009h-202016h
	; 100: 264009h-264016h
	; 256: 2FF009h-2FF016h
	movlw	0x1F
	movwf	ext_flash_address+2
	movlw	0xF0
	movwf	ext_flash_address+1

comm_send_compact_headers2:
	movlw	0x09
	movwf	ext_flash_address+0
	; adjust address for next dive
	movlw	0x10
	addwf	ext_flash_address+1
	movlw	0x00
	addwfc	ext_flash_address+2

	movlw	0x30
	cpfseq	ext_flash_address+2			; all 256 dive send?
	bra		comm_send_compact_headers4	; NO - continue
	bra		comm_download_mode0			; done, loop with timeout reset

comm_send_compact_headers4:
	movlw	.13
	movwf	lo							; counter
	rcall	comm_write_byte				; wait for completion of transmit
	call	ext_flash_read_block_start	; 1st byte
	movwf	TXREG1
	bra		comm_send_compact_headers3	; counter 24 bit
comm_send_compact_headers_loop:
	call	ext_flash_read_block		; read one byte
	movwf	TXREG1						; start new transmit
comm_send_compact_headers3:
	rcall	comm_write_byte				; wait for completion of transmit
	decfsz	lo,F
	bra		comm_send_compact_headers_loop
	call	ext_flash_read_block_stop

	; Offset to total dive counter
	movlw	.80
	movwf	ext_flash_address+0
	call	ext_flash_read_block_start	; 1st byte
	movwf	TXREG1
	rcall	comm_write_byte				; wait for completion of transmit
	call	ext_flash_read_block		; 2nd byte
	movwf	TXREG1
	call	ext_flash_read_block_stop
	rcall	comm_write_byte				; wait for completion of transmit

	; Offset to Logbook-Profile version
	movlw	.8
	movwf	ext_flash_address+0
	call	ext_flash_byte_read			; get byte
	movwf	TXREG1
	rcall	comm_write_byte				; wait for completion of transmit
	bra		comm_send_compact_headers2	; continue


;-----------------------------------------------------------------------------

comm_send_headers:
	movlw	"a"							; send echo
	movwf	TXREG1
	; Send 256 bytes/dive (Header)
	; 1st: 200000h-2000FFh
	; 2nd: 201000h-2010FFh
	; 3rd: 202000h-2020FFh
	; 100: 264000h-2640FFh
	; 256: 2FF000h-2FF0FFh
	movlw	0x1F
	movwf	ext_flash_address+2
	movlw	0xF0
	movwf	ext_flash_address+1
comm_send_headers2:
	clrf	ext_flash_address+0
	; Adjust address for next dive
	movlw	0x10
	addwf	ext_flash_address+1
	movlw	0x00
	addwfc	ext_flash_address+2
	movlw	0x30
	cpfseq	ext_flash_address+2			; all 256 dive send?
	bra		comm_send_headers4			; NO - continue
	bra		comm_download_mode0			; done, loop with timeout reset
comm_send_headers4:
	clrf	lo							; counter
	rcall	comm_write_byte				; wait for completion of transmit
	call	ext_flash_read_block_start	; 1st byte
	movwf	TXREG1
	bra		comm_send_headers3			; counter 24 bit
comm_send_headers_loop:
	call	ext_flash_read_block		; read one byte
	movwf	TXREG1						; start new transmit
comm_send_headers3:
	rcall	comm_write_byte				; wait for completion of transmit
	decfsz	lo,F
	bra		comm_send_headers_loop
	call	ext_flash_read_block_stop
	bra		comm_send_headers2			; continue

;-----------------------------------------------------------------------------

comm_option_reset_all:					; reset all options to factory default
	movlw	"x"							; send echo
	movwf	TXREG1
	call	option_reset_all
	bra		comm_download_mode0			; done, back to loop with timeout reset

;-----------------------------------------------------------------------------

comm_set_time:
	movlw	"b"							; send echo
	movwf	TXREG1

	rcall	comm_write_byte				; wait for completion of transmit
	rcall	comm_get_byte
	btfsc	rs232_rx_timeout			; got byte?
	bra		comm_download_mode0			; NO - abort
	movff	RCREG1, rtc_latched_hour
	rcall	comm_get_byte
	btfsc	rs232_rx_timeout			; got byte?
	bra		comm_download_mode0			; NO - abort
	movff	RCREG1, rtc_latched_mins
	rcall	comm_get_byte
	btfsc	rs232_rx_timeout			; got byte?
	bra		comm_download_mode0			; NO - abort
	movff	RCREG1, rtc_latched_secs
	rcall	comm_get_byte
	btfsc	rs232_rx_timeout			; got byte?
	bra		comm_download_mode0			; NO - abort
	movff	RCREG1, rtc_latched_month
	rcall	comm_get_byte
	btfsc	rs232_rx_timeout			; got byte?
	bra		comm_download_mode0			; NO - abort
	movff	RCREG1, rtc_latched_day
	rcall	comm_get_byte
	btfsc	rs232_rx_timeout			; got byte?
	bra		comm_download_mode0			; NO - abort
	movff	RCREG1, rtc_latched_year
	call	rtc_set_rtc					; write time and date to RTC module
	bra		comm_download_mode0			; done, back to loop with timeout reset

;-----------------------------------------------------------------------------
; Set custom text string (opt_name_length ASCII chars)
;

comm_set_custom_text:
	movlw	"c"							; send echo
	movwf	TXREG1
	rcall	comm_write_byte				; wait for completion of transmit
	lfsr	FSR2,opt_name
	movlw	opt_name_length
	movwf	lo							; counter
comm_set_ctext_loop:
	rcall	comm_get_byte
	btfsc	rs232_rx_timeout			; got byte?
	bra		comm_set_ctext_loop_done	; NO - abort
	movff	RCREG1,POSTINC2				; store character
	decfsz	lo,F
	bra		comm_set_ctext_loop
comm_set_ctext_loop_done:
	tstfsz	lo							; got opt_name_length bytes?
	bra		comm_set_ctext_loop_done2	; NO - clear remaining chars
	bra		comm_download_mode0			; done, loop with timeout reset
comm_set_ctext_loop_done2:
	clrf	POSTINC2
	decfsz	lo,F
	bra		comm_set_ctext_loop_done2
	bra		comm_download_mode0			; done, loop with timeout reset

;-----------------------------------------------------------------------------
; Reply Serial (2 bytes low:high), firmware (major.minor) and custom text
;

comm_identify:
	movlw	"i"							; send echo
	movwf	TXREG1
	rcall	comm_write_byte				; wait for completion of transmit

	;---- Read serial from internal EEPROM address 0000
	clrf	EEADRH
	clrf	EEADR						; get serial number LOW
	call	read_eeprom					; read byte
	movff	EEDATA,lo
	incf	EEADR,F						; get serial number HIGH
	call	read_eeprom					; read byte
	movff	EEDATA,hi

	;---- Emit serial number
	movff	lo,TXREG1
	rcall	comm_write_byte				; wait for completion of transmit
	movff	hi,TXREG1
	rcall	comm_write_byte				; wait for completion of transmit

	;---- Emit firmware hi.lo
	movlw	softwareversion_x
	movwf	TXREG1
	rcall	comm_write_byte				; wait for completion of transmit
	movlw	softwareversion_y
	movwf	TXREG1
	rcall	comm_write_byte				; wait for completion of transmit

	;---- Emit custom text
	movlw	opt_name_length
	movwf	hi
	lfsr	FSR2,opt_name

common_identify_loop:
	movff	POSTINC2,TXREG1
	rcall	comm_write_byte				; wait for completion of transmit
	decfsz	hi,F
	bra		common_identify_loop

	bra		comm_download_mode0			; done

;-----------------------------------------------------------------------------

comm_get_byte:
	goto	rs232_get_byte				; ... and return

comm_write_byte:						; wait for completion of transmit
	goto	rs232_wait_tx				; ... and return


;-----------------------------------------------------------------------------
; Reply hardware descriptor byte
;
comm_hardware_descriptor:
	movlw	"j"							; prepare echo
	movwf	TXREG1						; send    echo
	rcall	comm_write_byte				; wait for completion of transmit

	movf	HW_descriptor,W				; get hardware descriptor
	bcf		WREG,6						; clear bit 6 for reason of compatibility with 3rd party software
	bcf		WREG,7						; clear bit 7 for reason of compatibility with 3rd party software
	movwf	TXREG1						; send hardware descriptor

	bra		comm_download_mode0			; done

comm_feature_and_hardware:
	movlw	0x60						; send echo
	movwf	TXREG1
	rcall	comm_write_byte				; wait for completion of transmit

	movlw	0x00						; hardware high byte
	movwf	TXREG1
	rcall	comm_write_byte				; wait for completion of transmit

	movf	HW_descriptor,W				; get hardware descriptor
	bcf		WREG,6						; clear bit 6 for reason of compatibility with 3rd party software
	bcf		WREG,7						; clear bit 7 for reason of compatibility with 3rd party software
	movwf	TXREG1						; send hardware descriptor
	rcall	comm_write_byte				; wait for completion of transmit

	movlw	0x00						; feature high Byte
	movwf	TXREG1
	rcall	comm_write_byte				; wait for completion of transmit

	movlw	0x00						; feature low Byte
	movwf	TXREG1
	rcall	comm_write_byte				; wait for completion of transmit

	movlw	0x00						; model descriptor byte
	movwf	TXREG1

	bra		comm_download_mode0			; done

;-----------------------------------------------------------------------------

comm_send_dive:
	movlw	"f"; 0x66					; send echo
	movwf	TXREG1

	rcall	comm_get_byte
	btfsc	rs232_rx_timeout			; got byte?
	bra		comm_download_mode0			; NO - abort!
	movff	RCREG1,lo					; store dive number (0-255)
; First, send the header (again)
	; set ext_flash_address:3 to TOC entry of this dive
	; 1st: 200000h-200FFFh -> lo=0
	; 2nd: 201000h-201FFFh -> lo=1
	; 3rd: 202000h-202FFFh -> lo=2
	; 256: 2FF000h-2FFFFFh -> lo=255
	clrf	ext_flash_address+0
	clrf	ext_flash_address+1
	movlw	0x20
	movwf	ext_flash_address+2
	movlw	.16
	mulwf	lo							; lo*16 = offset to 0x2000 (up:hi)
	movf	PRODL,W
	addwf	ext_flash_address+1,F
	movf	PRODH,W
	addwfc	ext_flash_address+2,F

	incf_ext_flash_address d'2'			; skip 0xFA, 0xFA
	call	ext_flash_byte_read_plus	; read start address of profile
	movff	ext_flash_rw,ext_flash_log_pointer+0
	call	ext_flash_byte_read_plus	; read start address of profile
	movff	ext_flash_rw,ext_flash_log_pointer+1
	call	ext_flash_byte_read_plus	; read start address of profile
	movff	ext_flash_rw,ext_flash_log_pointer+2
	call	ext_flash_byte_read_plus	; read end address of profile
	movff	ext_flash_rw,ext_flash_end_pointer+0
	call	ext_flash_byte_read_plus	; read end address of profile
	movff	ext_flash_rw,ext_flash_end_pointer+1
	call	ext_flash_byte_read_plus	; read end address of profile
	movff	ext_flash_rw,ext_flash_end_pointer+2
	decf_ext_flash_address	d'8'		; back again to first 0xFA in header

	movf	ext_flash_log_pointer+0,W
	cpfseq	ext_flash_end_pointer+0		; equal?
	bra		comm_send_dive1				; NO - send header

	movf	ext_flash_log_pointer+1,W
	cpfseq	ext_flash_end_pointer+1		; equal?
	bra		comm_send_dive1				; NO - send header

	movf	ext_flash_log_pointer+2,W
	cpfseq	ext_flash_end_pointer+2		; equal?
	bra		comm_send_dive1				; NO - send header

	; Start=End -> Not good, abort
	bra		comm_download_mode0			; done, loop with timeout reset

comm_send_dive1:
	; Send header
	clrf	hi							; counter
	rcall	comm_write_byte				; wait for completion of transmit
	call	ext_flash_read_block_start	; 1st byte
	movwf	TXREG1
	bra		comm_send_dive_header
comm_send_dive_header2:
	call	ext_flash_read_block		; read one byte
	movwf	TXREG1						; start new transmit
comm_send_dive_header:
	rcall	comm_write_byte				; wait for completion of transmit
	decfsz	hi,F
	bra		comm_send_dive_header2
	call	ext_flash_read_block_stop

	; Set address for profile
	movff	ext_flash_log_pointer+0,ext_flash_address+0
	movff	ext_flash_log_pointer+1,ext_flash_address+1
	movff	ext_flash_log_pointer+2,ext_flash_address+2

	movlw	.6								; skip 6 byte short header in profile - only for internal use
	call	incf_ext_flash_address0_0x20	; increases bytes in ext_flash_address:3 with 0x200000 bank switching

	; Set address for short header/compact header, Byte 0

comm_send_dive_profile:
	call	ext_flash_byte_read_plus_0x20	; read one byte into ext_flash_rw, takes care of banking at 0x200000
	rcall	comm_write_byte					; wait for completion of transmit
	movff	ext_flash_rw,TXREG1				; send a byte

	; 24bit compare with end address
	movff	ext_flash_end_pointer+0,WREG
	cpfseq	ext_flash_address+0
	bra		comm_send_dive_profile
	movff	ext_flash_end_pointer+1,WREG
	cpfseq	ext_flash_address+1
	bra		comm_send_dive_profile
	movff	ext_flash_end_pointer+2,WREG
	cpfseq	ext_flash_address+2
	bra		comm_send_dive_profile

	rcall	comm_write_byte				; wait for completion of transmit
	bra		comm_download_mode0			; done, loop with timeout reset

;-----------------------------------------------------------------------------

comm_read_setting:
	movlw	"r"
	movwf	TXREG1
	rcall	comm_get_byte
	btfsc	rs232_rx_timeout			; got byte?
	bra		comm_read_abort				; NO - abort
	rcall	comm_write_byte				; wait for completion of transmit
	movlw	0x0F
	cpfsgt	RCREG1						; 0x00-0x0F: unused
	bra		comm_read_abort				; abort!
	subwf	RCREG1,W					; subtract unused commands

	clrf	up							; set gas/dil index to 0 (0 = gas 1)
	dcfsnz	WREG
	bra		comm_read_gas_dil			; RCREG1=0x10
	incf	up							; increment gas/dil index (1 = gas 2)
	dcfsnz	WREG
	bra		comm_read_gas_dil			; RCREG1=0x11
	incf	up							; increment gas/dil index (2 = gas 3)
	dcfsnz	WREG
	bra		comm_read_gas_dil			; RCREG1=0x12
	incf	up							; increment gas/dil index (3 = gas 4)
	dcfsnz	WREG
	bra		comm_read_gas_dil			; RCREG1=0x13
	incf	up							; increment gas/dil index (4 = gas 5)
	dcfsnz	WREG
	bra		comm_read_gas_dil			; RCREG1=0x14
	incf	up							; increment gas/dil index (5 = dil 1)
	dcfsnz	WREG
	bra		comm_read_gas_dil			; RCREG1=0x15
	incf	up							; increment gas/dil index (6 = dil 2)
	dcfsnz	WREG
	bra		comm_read_gas_dil			; RCREG1=0x16
	incf	up							; increment gas/dil index (7 = dil 3)
	dcfsnz	WREG
	bra		comm_read_gas_dil			; RCREG1=0x17
	incf	up							; increment gas/dil index (8 = dil 4)
	dcfsnz	WREG
	bra		comm_read_gas_dil			; RCREG1=0x18
	incf	up							; increment gas/dil index (9 = dil 5)
	dcfsnz	WREG
	bra		comm_read_gas_dil			; RCREG1=0x19

	clrf	up							; set setpoint index to 0 (0 = SP 1)
	dcfsnz	WREG
	bra		comm_read_sp				; RCREG1=0x1A
	incf	up							; increment setpoint index (1 = SP2)
	dcfsnz	WREG
	bra		comm_read_sp				; RCREG1=0x1B
	incf	up							; increment setpoint index (2 = SP3)
	dcfsnz	WREG
	bra		comm_read_sp				; RCREG1=0x1C
	incf	up							; increment setpoint index (3 = SP4)
	dcfsnz	WREG
	bra		comm_read_sp				; RCREG1=0x1D
	incf	up							; increment setpoint index (4 = SP5)
	dcfsnz	WREG
	bra		comm_read_sp				; RCREG1=0x1E

	dcfsnz	WREG
	movff	opt_ccr_mode,				TXREG1	; RCREG1=0x1F
	dcfsnz	WREG
	movff	opt_dive_mode,				TXREG1	; RCREG1=0x20
	dcfsnz	WREG
	movff	char_I_deco_model,			TXREG1	; RCREG1=0x21
	dcfsnz	WREG
	movff	char_I_ppO2_max_work,		TXREG1	; RCREG1=0x22
	dcfsnz	WREG
	movff	char_I_ppO2_min,			TXREG1	; RCREG1=0x23
	dcfsnz	WREG
	movff	char_I_extra_time,			TXREG1	; RCREG1=0x24
	dcfsnz	WREG
	movff	opt_GF_low,					TXREG1	; RCREG1=0x25
	dcfsnz	WREG
	movff	opt_GF_high,				TXREG1	; RCREG1=0x26
	dcfsnz	WREG
	movff	opt_aGF_low,				TXREG1	; RCREG1=0x27
	dcfsnz	WREG
	movff	opt_aGF_high,				TXREG1	; RCREG1=0x28
	dcfsnz	WREG
	movff	opt_enable_aGF,				TXREG1	; RCREG1=0x29
	dcfsnz	WREG
	movff	opt_sat_multiplier_non_gf,	TXREG1	; RCREG1=0x2A
	dcfsnz	WREG
	movff	opt_desat_multiplier_non_gf,TXREG1	; RCREG1=0x2B
	dcfsnz	WREG
	movff	opt_last_stop,				TXREG1	; RCREG1=0x2C
	dcfsnz	WREG
	movff	opt_brightness,				TXREG1	; RCREG1=0x2D
	dcfsnz	WREG
	movff	opt_units,					TXREG1	; RCREG1=0x2E
	dcfsnz	WREG
	movff	opt_sampling_rate,			TXREG1	; RCREG1=0x2F
	dcfsnz	WREG
	movff	opt_salinity,				TXREG1	; RCREG1=0x30
	dcfsnz	WREG
	movff	opt_dive_color_scheme,		TXREG1	; RCREG1=0x31
	dcfsnz	WREG
	movff	opt_language,				TXREG1	; RCREG1=0x32
	dcfsnz	WREG
	movff	opt_dateformat,				TXREG1	; RCREG1=0x33
	dcfsnz	WREG
	movff	opt_compass_gain,			TXREG1	; RCREG1=0x34
	dcfsnz	WREG
	movff	opt_pressure_adjust,		TXREG1	; RCREG1=0x35
	dcfsnz	WREG
	movff	opt_enable_safetystop,		TXREG1	; RCREG1=0x36
	dcfsnz	WREG
	movff	opt_calibration_O2_ratio,	TXREG1	; RCREG1=0x37
	dcfsnz	WREG
	clrf	TXREG1								; RCREG1=0x38	NOT USED ANYMORE (ex opt_sensor_fallback)
	dcfsnz	WREG
	movff	opt_flip_screen,			TXREG1	; RCREG1=0x39
	dcfsnz	WREG
	movff	opt_cR_button_left,			TXREG1	; RCREG1=0x3A
	dcfsnz	WREG
	movff	opt_cR_button_right,		TXREG1	; RCREG1=0x3B
	dcfsnz	WREG
	movff	char_I_SAC_work,			TXREG1	; RCREG1=0x3C
	dcfsnz	WREG
	movff	char_I_SAC_deco,			TXREG1	; RCREG1=0x3D
	dcfsnz	WREG
	movff	opt_modwarning,				TXREG1	; RCREG1=0x3E
	dcfsnz	WREG
	movff	opt_vsitextv2,				TXREG1	; RCREG1=0x3F
	dcfsnz	WREG
	movff	opt_vsigraph,				TXREG1	; RCREG1=0x40
	dcfsnz	WREG
	movff	opt_showppo2,				TXREG1	; RCREG1=0x41, always show ppO2
	dcfsnz	WREG
	movff	opt_temperature_adjust,		TXREG1	; RCREG1=0x42
	dcfsnz	WREG
	movff	opt_safety_stop_length,		TXREG1	; RCREG1=0x43
	dcfsnz	WREG
	movff	opt_safety_stop_start,		TXREG1	; RCREG1=0x44
	dcfsnz	WREG
	movff	opt_safety_stop_end,		TXREG1	; RCREG1=0x45
	dcfsnz	WREG
	movff	opt_safety_stop_reset,		TXREG1	; RCREG1=0x46
	dcfsnz	WREG
	clrf	TXREG1								; RCREG1=0x47, ignore conservatism in hwOS tech firmware
	dcfsnz	WREG
	movff	opt_diveTimeout,			TXREG1	; RCREG1=0x48
	dcfsnz	WREG
	movff	button_polarity,			TXREG1	; RCREG1=0x49
	dcfsnz	WREG
	movff	char_I_PSCR_drop,			TXREG1	; RCREG1=0x4A
	dcfsnz	WREG
	movff	char_I_PSCR_lungratio,		TXREG1	; RCREG1=0x4B
	dcfsnz	WREG
	movff	char_I_ppO2_max_deco,		TXREG1	; RCREG1=0x4C
	dcfsnz	WREG
	movff	char_I_ppO2_min_loop,		TXREG1	; RCREG1=0x4D
	dcfsnz	WREG
	movff	char_I_gas_avail_size+0,	TXREG1	; RCREG1=0x4E
	dcfsnz	WREG
	movff	char_I_gas_avail_size+1,	TXREG1	; RCREG1=0x4F
	dcfsnz	WREG
	movff	char_I_gas_avail_size+2,	TXREG1	; RCREG1=0x50
	dcfsnz	WREG
	movff	char_I_gas_avail_size+3,	TXREG1	; RCREG1=0x51
	dcfsnz	WREG
	movff	char_I_gas_avail_size+4,	TXREG1	; RCREG1=0x52
	dcfsnz	WREG
	movff	char_I_gas_avail_pres+0,	TXREG1	; RCREG1=0x53
	dcfsnz	WREG
	movff	char_I_gas_avail_pres+1,	TXREG1	; RCREG1=0x54
	dcfsnz	WREG
	movff	char_I_gas_avail_pres+2,	TXREG1	; RCREG1=0x55
	dcfsnz	WREG
	movff	char_I_gas_avail_pres+3,	TXREG1	; RCREG1=0x56
	dcfsnz	WREG
	movff	char_I_gas_avail_pres+4,	TXREG1	; RCREG1=0x57
	dcfsnz	WREG
	movff	char_I_CC_max_frac_O2,		TXREG1	; RCREG1=0x58
	dcfsnz	WREG
	movff	opt_sim_setpoint_number,	TXREG1	; RCREG1=0x59
	dcfsnz	WREG
	movff	opt_calc_asc_gasvolume,		TXREG1	; RCREG1=0x5A
	dcfsnz	WREG
	movff	opt_sim_use_aGF,			TXREG1	; RCREG1=0x5B
	dcfsnz	WREG
	movff	char_I_altitude_wait,		TXREG1	; RCREG1=0x5C
	dcfsnz	WREG
	movff	opt_enable_IBCD,			TXREG1	; RCREG1=0x5D
	dcfsnz	WREG
	movff	opt_sat_multiplier_gf,		TXREG1	; RCREG1=0x5E
	dcfsnz	WREG
	movff	opt_desat_multiplier_gf,	TXREG1	; RCREG1=0x5F
	dcfsnz	WREG
	movff	opt_transmitter_id_1+0,		TXREG1	; RCREG1=0x60
	dcfsnz	WREG
	movff	opt_transmitter_id_1+1,		TXREG1	; RCREG1=0x61
	dcfsnz	WREG
	movff	opt_transmitter_id_2+0,		TXREG1	; RCREG1=0x62
	dcfsnz	WREG
	movff	opt_transmitter_id_2+1,		TXREG1	; RCREG1=0x63
	dcfsnz	WREG
	movff	opt_transmitter_id_3+0,		TXREG1	; RCREG1=0x64
	dcfsnz	WREG
	movff	opt_transmitter_id_3+1,		TXREG1	; RCREG1=0x65
	dcfsnz	WREG
	movff	opt_transmitter_id_4+0,		TXREG1	; RCREG1=0x66
	dcfsnz	WREG
	movff	opt_transmitter_id_4+1,		TXREG1	; RCREG1=0x67
	dcfsnz	WREG
	movff	opt_transmitter_id_5+0,		TXREG1	; RCREG1=0x68
	dcfsnz	WREG
	movff	opt_transmitter_id_5+1,		TXREG1	; RCREG1=0x69
	dcfsnz	WREG
	movff	opt_transmitter_id_6+0,		TXREG1	; RCREG1=0x6A
	dcfsnz	WREG
	movff	opt_transmitter_id_6+1,		TXREG1	; RCREG1=0x6B
	dcfsnz	WREG
	movff	opt_transmitter_id_7+0,		TXREG1	; RCREG1=0x6C
	dcfsnz	WREG
	movff	opt_transmitter_id_7+1,		TXREG1	; RCREG1=0x6D
	dcfsnz	WREG
	movff	opt_transmitter_id_8+0,		TXREG1	; RCREG1=0x6E
	dcfsnz	WREG
	movff	opt_transmitter_id_8+1,		TXREG1	; RCREG1=0x6F
	dcfsnz	WREG
	movff	opt_transmitter_id_9+0,		TXREG1	; RCREG1=0x70
	dcfsnz	WREG
	movff	opt_transmitter_id_9+1,		TXREG1	; RCREG1=0x71
	dcfsnz	WREG
	movff	opt_transmitter_id_10+0,	TXREG1	; RCREG1=0x72
	dcfsnz	WREG
	movff	opt_transmitter_id_10+1,	TXREG1	; RCREG1=0x73
	dcfsnz	WREG
	movff	char_I_gas_avail_size+5,	TXREG1	; RCREG1=0x74
	dcfsnz	WREG
	movff	char_I_gas_avail_size+6,	TXREG1	; RCREG1=0x75
	dcfsnz	WREG
	movff	char_I_gas_avail_size+7,	TXREG1	; RCREG1=0x76
	dcfsnz	WREG
	movff	char_I_gas_avail_size+8,	TXREG1	; RCREG1=0x77
	dcfsnz	WREG
	movff	char_I_gas_avail_size+9,	TXREG1	; RCREG1=0x78
	dcfsnz	WREG
	movff	char_I_gas_avail_pres+5,	TXREG1	; RCREG1=0x79
	dcfsnz	WREG
	movff	char_I_gas_avail_pres+6,	TXREG1	; RCREG1=0x7A
	dcfsnz	WREG
	movff	char_I_gas_avail_pres+7,	TXREG1	; RCREG1=0x7B
	dcfsnz	WREG
	movff	char_I_gas_avail_pres+8,	TXREG1	; RCREG1=0x7C
	dcfsnz	WREG
	movff	char_I_gas_avail_pres+9,	TXREG1	; RCREG1=0x7D
	dcfsnz	WREG
	movff	opt_TR_mode,				TXREG1	; RCREG1=0x7E
	dcfsnz	WREG
	movff	opt_TR_1st_pres,			TXREG1	; RCREG1=0x7F
	dcfsnz	WREG
	movff	opt_TR_2nd_pres,			TXREG1	; RCREG1=0x80
	dcfsnz	WREG
	movff	opt_TR_Bail_pres,			TXREG1	; RCREG1=0x81
	dcfsnz	WREG
	movff	char_I_max_pres_diff,		TXREG1	; RCREG1=0x82
	dcfsnz	WREG
	movff	opt_ZfactorUse,				TXREG1	; RCREG1=0x83
	dcfsnz	WREG
	movff	opt_ZfactorTemp,			TXREG1	; RCREG1=0x84
	dcfsnz	WREG
	movff	opt_2ndDepthDisp,			TXREG1	; RCREG1=0x85
	dcfsnz	WREG
	movff	opt_max_depth,				TXREG1	; RCREG1=0x86
	dcfsnz	WREG
	movff	char_I_descent_speed,		TXREG1	; RCREG1=0x87
	dcfsnz	WREG
	movff	opt_store_apnoe_dive,		TXREG1	; RCREG1=0x88
	dcfsnz	WREG
	movff	opt_tissue_graphics,		TXREG1	; RCREG1=0x89
	dcfsnz	WREG
	movff	opt_layout,					TXREG1	; RCREG1=0x8A
	dcfsnz	WREG
	movff	opt_extended_stops,			TXREG1	; RCREG1=0x8B
	dcfsnz	WREG
	movff	char_I_gas_density_att,		TXREG1	; RCREG1=0x8C
	dcfsnz	WREG
	movff	char_I_gas_density_warn,	TXREG1	; RCREG1=0x8D
	dcfsnz	WREG
	movff	char_I_dil_ppO2_check,		TXREG1	; RCREG1=0x8E

comm_read_abort:
comm_read_done:
	bra		comm_download_mode0			; done, loop with timeout reset

;-----------------------------------------------------------------------------

; Memory map is as follows:
; -------------------------
; opt_gas_O2_ratio			res 5		; O2 ratios of OC/bailout gases
; opt_dil_O2_ratio			res 5		; O2 ratios of diluents
; opt_gas_He_ratio			res 5		; He ratios of OC/bailout gases
; opt_dil_He_ratio			res 5		; He ratios of diluents
; opt_gas_type				res 5		; OC/bailout gas type
; opt_dil_type				res 5		; dil type
; opt_gas_change			res 5		; change depths for OC/Bailout gases
; opt_dil_change			res 5		; change depths for diluents

comm_read_gas_dil:
	lfsr	FSR0,opt_gas_O2_ratio		; load base address of gas data arrays
	movf	up,W						; load index (0-9) of gas/dil into WREG, addressing O2 ratio
	movff	PLUSW0, TXREG1				; transmit O2 ratio
	rcall	comm_write_byte				; wait for completion of transmit
	addlw	.10							; increment index by 10, addressing He ratio now
	movff	PLUSW0, TXREG1				; transmit He ratio
	rcall	comm_write_byte				; wait for completion of transmit
	addlw	.10							; increment index by 10, addressing gas/dil type now
	movff	PLUSW0, TXREG1				; transmit gas/dil type
	rcall	comm_write_byte				; wait for completion of transmit
	addlw	.10							; increment index by 10, addressing change depth now
	movff	PLUSW0,TXREG1				; transmit change depth
	bra		comm_read_done				; done, wait for UART and loop with timeout reset


; Memory map is as follows:
; -------------------------
; opt_setpoint_cbar			res 5	; setpoints in cbar
; opt_setpoint_change		res 5	; change depth for the setpoints in meter

comm_read_sp:
	lfsr	FSR0,opt_setpoint_cbar		; load base address of setpoint cbar values
	movf	up,W						; load index (0-4) of setpoint into WREG, addressing cbar value
	movff	PLUSW0, TXREG1				; transmit setpoint cbar value
	rcall	comm_write_byte				; wait for completion of transmit
	addlw	.5							; increment index by 5, addressing change depth now
	movff	PLUSW0, TXREG1				; transmit change depth
	bra		comm_read_done				; done, wait for UART and loop with timeout reset

;-----------------------------------------------------------------------------

comm_write_setting:
	movlw	"w"
	movwf	TXREG1
	rcall	comm_get_byte					; "Byte 2"
	btfsc	rs232_rx_timeout				; got a byte?
	bra		comm_write_abort				; NO - abort
	movff	RCREG1,lo						; copy
	rcall	comm_get_byte					; "Byte 3"
	rcall	comm_write_byte					; wait for completion of transmit
	movlw	0x0F
	cpfsgt	lo								; 0x00-0x0F: unused
	bra		comm_write_abort				; abort!
	subwf	lo,W							; subtract unused commands

	clrf	up								; set gas/dil index to 0  (0 = gas 1)
	dcfsnz	WREG
	bra		comm_write_gas_dil				; RCREG1=0x10
	incf	up								; increment gas/dil index (1 = gas 2)
	dcfsnz	WREG
	bra		comm_write_gas_dil				; RCREG1=0x11
	incf	up								; increment gas/dil index (2 = gas 3)
	dcfsnz	WREG
	bra		comm_write_gas_dil				; RCREG1=0x12
	incf	up								; increment gas/dil index (3 = gas 4)
	dcfsnz	WREG
	bra		comm_write_gas_dil				; RCREG1=0x13
	incf	up								; increment gas/dil index (4 = gas 5)
	dcfsnz	WREG
	bra		comm_write_gas_dil				; RCREG1=0x14
	incf	up								; increment gas/dil index (5 = dil 1)
	dcfsnz	WREG
	bra		comm_write_gas_dil				; RCREG1=0x15
	incf	up								; increment gas/dil index (6 = dil 2)
	dcfsnz	WREG
	bra		comm_write_gas_dil				; RCREG1=0x16
	incf	up								; increment gas/dil index (7 = dil 3)
	dcfsnz	WREG
	bra		comm_write_gas_dil				; RCREG1=0x17
	incf	up								; increment gas/dil index (8 = dil 4)
	dcfsnz	WREG
	bra		comm_write_gas_dil				; RCREG1=0x18
	incf	up								; increment gas/dil index (9 = dil 5)
	dcfsnz	WREG
	bra		comm_write_gas_dil				; RCREG1=0x19

	clrf	up								; set setpoint index to 0 (0 = SP 1)
	dcfsnz	WREG
	bra		comm_write_sp					; RCREG1=0x1A
	incf	up								; increment setpoint index (1 = SP2)
	dcfsnz	WREG
	bra		comm_write_sp					; RCREG1=0x1B
	incf	up								; increment setpoint index (2 = SP3)
	dcfsnz	WREG
	bra		comm_write_sp					; RCREG1=0x1C
	incf	up								; increment setpoint index (3 = SP4)
	dcfsnz	WREG
	bra		comm_write_sp					; RCREG1=0x1D
	incf	up								; increment setpoint index (4 = SP5)
	dcfsnz	WREG
	bra		comm_write_sp					; RCREG1=0x1E

	dcfsnz	WREG
	movff	RCREG1, opt_ccr_mode			; RCREG1=0x1F
	dcfsnz	WREG
	movff	RCREG1, opt_dive_mode			; RCREG1=0x20
	dcfsnz	WREG
	movff	RCREG1, char_I_deco_model		; RCREG1=0x21
	dcfsnz	WREG
	movff	RCREG1, char_I_ppO2_max_work	; RCREG1=0x22
	dcfsnz	WREG
	movff	RCREG1, char_I_ppO2_min			; RCREG1=0x23
	dcfsnz	WREG
	movff	RCREG1, char_I_extra_time		; RCREG1=0x24
	dcfsnz	WREG
	movff	RCREG1, opt_GF_low				; RCREG1=0x25
	dcfsnz	WREG
	movff	RCREG1, opt_GF_high				; RCREG1=0x26
	dcfsnz	WREG
	movff	RCREG1, opt_aGF_low				; RCREG1=0x27
	dcfsnz	WREG
	movff	RCREG1, opt_aGF_high			; RCREG1=0x28
	dcfsnz	WREG
	movff	RCREG1, opt_enable_aGF			; RCREG1=0x29
	dcfsnz	WREG
	movff	RCREG1, opt_sat_multiplier_non_gf	; RCREG1=0x2A
	dcfsnz	WREG
	movff	RCREG1, opt_desat_multiplier_non_gf	; RCREG1=0x2B
	dcfsnz	WREG
	movff	RCREG1, opt_last_stop			; RCREG1=0x2C
	dcfsnz	WREG
	movff	RCREG1, opt_brightness			; RCREG1=0x2D
	dcfsnz	WREG
	movff	RCREG1, opt_units				; RCREG1=0x2E
	dcfsnz	WREG
	movff	RCREG1, opt_sampling_rate		; RCREG1=0x2F
	dcfsnz	WREG
	movff	RCREG1, opt_salinity			; RCREG1=0x30
	dcfsnz	WREG
	movff	RCREG1, opt_dive_color_scheme	; RCREG1=0x31
	dcfsnz	WREG
	movff	RCREG1, opt_language			; RCREG1=0x32
	dcfsnz	WREG
	movff	RCREG1, opt_dateformat			; RCREG1=0x33
	dcfsnz	WREG
	movff	RCREG1, opt_compass_gain		; RCREG1=0x34
	dcfsnz	WREG
	movff	RCREG1, opt_pressure_adjust		; RCREG1=0x35
	dcfsnz	WREG
	movff	RCREG1, opt_enable_safetystop	; RCREG1=0x36
	dcfsnz	WREG
	movff	RCREG1, opt_calibration_O2_ratio; RCREG1=0x37
	dcfsnz	WREG
	nop										; RCREG1=0x38	NOT USED ANYMORE (ex opt_sensor_fallback)
	dcfsnz	WREG
	movff	RCREG1, opt_flip_screen			; RCREG1=0x39
	dcfsnz	WREG
	movff	RCREG1, opt_cR_button_left		; RCREG1=0x3A
	dcfsnz	WREG
	movff	RCREG1, opt_cR_button_right		; RCREG1=0x3B
	dcfsnz	WREG
	movff	RCREG1, char_I_SAC_work			; RCREG1=0x3C
	dcfsnz	WREG
	movff	RCREG1, char_I_SAC_deco			; RCREG1=0x3D
	dcfsnz	WREG
	movff	RCREG1, opt_modwarning			; RCREG1=0x3E
	dcfsnz	WREG
	movff	RCREG1, opt_vsitextv2			; RCREG1=0x3F
	dcfsnz	WREG
	movff	RCREG1, opt_vsigraph			; RCREG1=0x40
	dcfsnz	WREG
	movff	RCREG1, opt_showppo2			; RCREG1=0x41, always show ppO2
	dcfsnz	WREG
	movff	RCREG1, opt_temperature_adjust	; RCREG1=0x42
	dcfsnz	WREG
	movff	RCREG1, opt_safety_stop_length	; RCREG1=0x43
	dcfsnz	WREG
	movff	RCREG1, opt_safety_stop_start	; RCREG1=0x44
	dcfsnz	WREG
	movff	RCREG1, opt_safety_stop_end		; RCREG1=0x45
	dcfsnz	WREG
	movff	RCREG1, opt_safety_stop_reset	; RCREG1=0x46
	dcfsnz	WREG
	nop										; RCREG1=0x47, ignore conservatism for standard hwOS
	dcfsnz	WREG
	movff	RCREG1, opt_diveTimeout			; RCREG1=0x48
	dcfsnz	WREG
	bra		comm_write_button_polarity		; RCREG1=0x49
	dcfsnz	WREG
	movff	RCREG1, char_I_PSCR_drop		; RCREG1=0x4A
	dcfsnz	WREG
	movff	RCREG1, char_I_PSCR_lungratio	; RCREG1=0x4B
	dcfsnz	WREG
	movff	RCREG1, char_I_ppO2_max_deco	; RCREG1=0x4C
	dcfsnz	WREG
	movff	RCREG1, char_I_ppO2_min_loop	; RCREG1=0x4D
	dcfsnz	WREG
	movff	RCREG1, char_I_gas_avail_size+0	; RCREG1=0x4E
	dcfsnz	WREG
	movff	RCREG1, char_I_gas_avail_size+1	; RCREG1=0x4F
	dcfsnz	WREG
	movff	RCREG1, char_I_gas_avail_size+2	; RCREG1=0x50
	dcfsnz	WREG
	movff	RCREG1, char_I_gas_avail_size+3	; RCREG1=0x51
	dcfsnz	WREG
	movff	RCREG1, char_I_gas_avail_size+4	; RCREG1=0x52
	dcfsnz	WREG
	movff	RCREG1, char_I_gas_avail_pres+0	; RCREG1=0x53
	dcfsnz	WREG
	movff	RCREG1, char_I_gas_avail_pres+1	; RCREG1=0x54
	dcfsnz	WREG
	movff	RCREG1, char_I_gas_avail_pres+2	; RCREG1=0x55
	dcfsnz	WREG
	movff	RCREG1, char_I_gas_avail_pres+3	; RCREG1=0x56
	dcfsnz	WREG
	movff	RCREG1, char_I_gas_avail_pres+4	; RCREG1=0x57
	dcfsnz	WREG
	movff	RCREG1, char_I_CC_max_frac_O2	; RCREG1=0x58
	dcfsnz	WREG
	movff	RCREG1, opt_sim_setpoint_number	; RCREG1=0x59
	dcfsnz	WREG
	movff	RCREG1, opt_calc_asc_gasvolume	; RCREG1=0x5A
	dcfsnz	WREG
	movff	RCREG1, opt_sim_use_aGF			; RCREG1=0x5B
	dcfsnz	WREG
	movff	RCREG1, char_I_altitude_wait	; RCREG1=0x5C
	dcfsnz	WREG
	movff	RCREG1, opt_enable_IBCD			; RCREG1=0x5D
	dcfsnz	WREG
	movff	RCREG1, opt_sat_multiplier_gf	; RCREG1=0x5E
	dcfsnz	WREG
	movff	RCREG1, opt_desat_multiplier_gf	; RCREG1=0x5F
	dcfsnz	WREG
	movff	RCREG1, opt_transmitter_id_1+0	; RCREG1=0x60
	dcfsnz	WREG
	movff	RCREG1, opt_transmitter_id_1+1	; RCREG1=0x61
	dcfsnz	WREG
	movff	RCREG1, opt_transmitter_id_2+0	; RCREG1=0x62
	dcfsnz	WREG
	movff	RCREG1, opt_transmitter_id_2+1	; RCREG1=0x63
	dcfsnz	WREG
	movff	RCREG1, opt_transmitter_id_3+0	; RCREG1=0x64
	dcfsnz	WREG
	movff	RCREG1, opt_transmitter_id_3+1	; RCREG1=0x65
	dcfsnz	WREG
	movff	RCREG1, opt_transmitter_id_4+0	; RCREG1=0x66
	dcfsnz	WREG
	movff	RCREG1, opt_transmitter_id_4+1	; RCREG1=0x67
	dcfsnz	WREG
	movff	RCREG1, opt_transmitter_id_5+0	; RCREG1=0x68
	dcfsnz	WREG
	movff	RCREG1, opt_transmitter_id_5+1	; RCREG1=0x69
	dcfsnz	WREG
	movff	RCREG1, opt_transmitter_id_6+0	; RCREG1=0x6A
	dcfsnz	WREG
	movff	RCREG1, opt_transmitter_id_6+1	; RCREG1=0x6B
	dcfsnz	WREG
	movff	RCREG1, opt_transmitter_id_7+0	; RCREG1=0x6C
	dcfsnz	WREG
	movff	RCREG1, opt_transmitter_id_7+1	; RCREG1=0x6D
	dcfsnz	WREG
	movff	RCREG1, opt_transmitter_id_8+0	; RCREG1=0x6E
	dcfsnz	WREG
	movff	RCREG1, opt_transmitter_id_8+1	; RCREG1=0x6F
	dcfsnz	WREG
	movff	RCREG1, opt_transmitter_id_9+0	; RCREG1=0x70
	dcfsnz	WREG
	movff	RCREG1, opt_transmitter_id_9+1	; RCREG1=0x71
	dcfsnz	WREG
	movff	RCREG1, opt_transmitter_id_10+0	; RCREG1=0x72
	dcfsnz	WREG
	movff	RCREG1, opt_transmitter_id_10+1	; RCREG1=0x73
	dcfsnz	WREG
	movff	RCREG1, char_I_gas_avail_size+5	; RCREG1=0x74
	dcfsnz	WREG
	movff	RCREG1, char_I_gas_avail_size+6	; RCREG1=0x75
	dcfsnz	WREG
	movff	RCREG1, char_I_gas_avail_size+7	; RCREG1=0x76
	dcfsnz	WREG
	movff	RCREG1, char_I_gas_avail_size+8	; RCREG1=0x77
	dcfsnz	WREG
	movff	RCREG1, char_I_gas_avail_size+9	; RCREG1=0x78
	dcfsnz	WREG
	movff	RCREG1, char_I_gas_avail_pres+5	; RCREG1=0x79
	dcfsnz	WREG
	movff	RCREG1, char_I_gas_avail_pres+6	; RCREG1=0x7A
	dcfsnz	WREG
	movff	RCREG1, char_I_gas_avail_pres+7	; RCREG1=0x7B
	dcfsnz	WREG
	movff	RCREG1, char_I_gas_avail_pres+8	; RCREG1=0x7C
	dcfsnz	WREG
	movff	RCREG1, char_I_gas_avail_pres+9	; RCREG1=0x7D
	dcfsnz	WREG
	movff	RCREG1, opt_TR_mode				; RCREG1=0x7E
	dcfsnz	WREG
	movff	RCREG1, opt_TR_1st_pres			; RCREG1=0x7F
	dcfsnz	WREG
	movff	RCREG1, opt_TR_2nd_pres			; RCREG1=0x80
	dcfsnz	WREG
	movff	RCREG1, opt_TR_Bail_pres		; RCREG1=0x81
	dcfsnz	WREG
	movff	RCREG1, char_I_max_pres_diff	; RCREG1=0x82
	dcfsnz	WREG
	movff	RCREG1, opt_ZfactorUse			; RCREG1=0x83
	dcfsnz	WREG
	movff	RCREG1, opt_ZfactorTemp			; RCREG1=0x84
	dcfsnz	WREG
	movff	RCREG1, opt_2ndDepthDisp		; RCREG1=0x85
	dcfsnz	WREG
	movff	RCREG1, opt_max_depth			; RCREG1=0x86
	dcfsnz	WREG
	movff	RCREG1, char_I_descent_speed	; RCREG1=0x87
	dcfsnz	WREG
	movff	RCREG1, opt_store_apnoe_dive	; RCREG1=0x88
	dcfsnz	WREG
	movff	RCREG1, opt_tissue_graphics		; RCREG1=0x89
	dcfsnz	WREG
	movff	RCREG1, opt_layout				; RCREG1=0x8A
	dcfsnz	WREG
	movff	RCREG1, opt_extended_stops		; RCREG1=0x8B
	dcfsnz	WREG
	movff	RCREG1, char_I_gas_density_att	; RCREG1=0x8C
	dcfsnz	WREG
	movff	RCREG1, char_I_gas_density_warn	; RCREG1=0x8D
	dcfsnz	WREG
	movff	RCREG1, char_I_dil_ppO2_check	; RCREG1=0x8E


comm_write_abort:
comm_write_done:
	; check options, gases and diluents
	call	option_check_all			; check all options (and reset if not within their min/max boundaries)
	goto	comm_download_mode0			; done, loop with timeout reset

;-----------------------------------------------------------------------------

; Memory map is as follows:
; -------------------------
; opt_gas_O2_ratio			res 5		; O2 ratios of OC/bailout gases
; opt_dil_O2_ratio			res 5		; O2 ratios of diluents
; opt_gas_He_ratio			res 5		; He ratios of OC/bailout gases
; opt_dil_He_ratio			res 5		; He ratios of diluents
; opt_gas_type				res 5		; OC/bailout gas type
; opt_dil_type				res 5		; dil type
; opt_gas_change			res 5		; change depths for OC/Bailout gases
; opt_dil_change			res 5		; change depths for diluents

comm_write_gas_dil:
	lfsr	FSR0,opt_gas_O2_ratio		; load base address of gas data arrays
	movf	up,W						; load index (0-9) of gas/dil into WREG, addressing O2 ratio
	movff	RCREG1,PLUSW0				; receive O2 ratio
	rcall	comm_get_byte				; wait for UART
	addlw	.10							; increment index by 10, addressing He ratio now
	movff	RCREG1,PLUSW0				; receive He ratio
	rcall	comm_get_byte				; wait for UART
	addlw	.10							; increment index by 10, addressing gas/dil type now
	movff	RCREG1,PLUSW0				; receive gas/dil type
	rcall	comm_get_byte				; wait for UART
	addlw	.10							; increment index by 10, addressing change depth now
	movff	RCREG1,PLUSW0				; receive change depth
	bra		comm_write_done				; done, loop with timeout reset


; Memory map is as follows:
; -------------------------
; opt_setpoint_cbar			res 5	; setpoints in cbar
; opt_setpoint_change		res 5	; change depth for the setpoints in meter

comm_write_sp:
	lfsr	FSR0,opt_setpoint_cbar		; load base address of setpoint cbar values
	movf	up,W						; load index (0-4) of setpoint into WREG, addressing cbar value
	movff	RCREG1,PLUSW0				; receive setpoint cbar value
	rcall	comm_get_byte				; wait for UART
	addlw	.5							; increment index by 5, addressing change depth now
	movff	RCREG1,PLUSW0				; receive change depth
	bra		comm_write_done				; done, loop with timeout reset

;-----------------------------------------------------------------------------

comm_send_string:
	movlw	"n"							; send echo
	movwf	TXREG1
	call	comm_write_byte				; wait for completion of transmit
	WIN_SMALL comm_string_column, comm_string_row
	movlw	.16
	movwf	lo							; counter
comm_send_string_loop:
	call	comm_get_byte
	btfsc	rs232_rx_timeout			; got a byte?
	bra		comm_send_string_abort		; NO - abort
	movff	RCREG1,POSTINC2				; store character
	decfsz	lo,F
	bra		comm_send_string_loop
comm_send_string_abort:
	STRCAT_PRINT ""						; show the text
	goto	comm_download_mode0			; done, loop with timeout reset

;-----------------------------------------------------------------------------

comm_write_button_polarity:
	; store RCREG1 into EEPROM .897
	movlw	LOW  .897
	movwf	EEADR
	movlw	HIGH .897
	movwf	EEADRH
	movff	RCREG1,EEDATA
	movff	EEDATA,button_polarity		; 0xFF (both normal), 0x00 (both inverted), 0x01 (left inverted only), 0x02 (right inverted only) 
	call	write_eeprom				; EEDATA into EEPROM@EEADR
	clrf	EEADRH						; reset EEADRH
	goto	comm_download_mode0			; done, loop with timeout reset

;----------------------------------------------------------------------------
	END