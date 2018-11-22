;=============================================================================
;
;   File comm.asm									REFACTORED VERSION V2.99d
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
	extern	get_first_gas_to_WREG
	extern	get_first_dil_to_WREG
	extern	option_save_all
	extern	vault_decodata_into_eeprom
	extern  menu_processor_bottom_line_comm

 IFDEF _rx_functions
	extern	I2C_update_OSTC_rx
 ENDIF


#DEFINE timeout_comm_pre_mode	.240	; pre-loop
#DEFINE timeout_comm_mode		.120	; download mode
#DEFINE timeout_service_mode	.120	; service mode

#DEFINE comm_title_row			.0
#DEFINE comm_title_column_usb	.50
#DEFINE comm_title_column_ble	.25

#DEFINE comm_string_row			.30
#DEFINE comm_string_column		.40

#DEFINE comm_status1_row		.70
#DEFINE comm_status1_column		.10
#DEFINE comm_status2_row		.100
#DEFINE comm_status2_column		comm_status1_column
#DEFINE comm_status3_row		.130
#DEFINE comm_status3_column		comm_status1_column
#DEFINE	comm_status4_row		.160
#DEFINE	comm_status4_column		comm_status1_column


#DEFINE comm_warning_row		.160
#DEFINE comm_warning_column		.65

comm	CODE

;=============================================================================

	; test for comm
	global	comm_mode, comm_mode0
comm_mode:
	WAITMS	d'1'
	btfss	vusb_in						; USB plugged in?
	return								; NO - it was only a glitch
	WAITMS	d'1'
	btfss	vusb_in						; USB plugged in?
	return								; NO - it was only a glitch
comm_mode0:
	call	TFT_ClearScreen
	WIN_COLOR color_greenish
	btfsc	ble_available							; BLE available
	bra		comm_mode0_ble
	WIN_SMALL comm_title_column_usb, comm_title_row
	STRCPY_TEXT_PRINT tUsbTitle						; USB mode
	bra		comm_mode0_common
comm_mode0_ble:
	WIN_SMALL comm_title_column_ble, comm_title_row
	STRCPY_TEXT_PRINT tBleTitle						; BLE mode
comm_mode0_common:
	call	TFT_standard_color
	WIN_TOP  .10
	WIN_LEFT .1
	TFT_WRITE_PROM_IMAGE_BY_ADDR usb_ble_logo_block
	WIN_SMALL comm_status1_column,comm_status1_row
	STRCPY_TEXT_PRINT tUsbStarting					; starting...
	call	menu_processor_bottom_line_comm			; serial and fw version
	call	option_save_all							; save all settings into EEPROM (comm mode may be entered after settings have been changed without leaving the menu in between)

 IFDEF _screendump
	bcf		enable_screen_dumps			; =1: ignore vin_usb, wait for "l" command (screen dump)
 ENDIF

	bcf		switch_right
	bcf		comm_service_enabled
	bsf		menubit
	bcf		battery_removed_in_usb		; =1: the battery has been removed in USB (properly not used for anything useful)
	movlw	timeout_comm_pre_mode
	movwf	comm_timeout
	WIN_SMALL comm_status1_column+.80,comm_status1_row
	STRCPY_TEXT_PRINT tUsbStartDone		; done...
	call	enable_rs232				; also sets to speed_normal ...
comm_mode1:
	bcf		onesecupdate
	bcf		LEDr
	dcfsnz	comm_timeout,F
	bra		comm_service_exit			; timeout -> exit
comm_mode2:
	rcall	comm_get_byte

	movlw	0xAA						; start byte=0xAA?
	cpfseq	RCREG1
	bra		comm_mode2a
	bra		comm_mode2b					; start byte for service mode found
comm_mode2a:
	movlw	0xBB						; start byte=0xBB?
	cpfseq	RCREG1
	bra		comm_mode2c
	bra		comm_download_mode			; start byte for download mode found

comm_mode2c:
	btfss	vusb_in						; USB plugged in?
	bra		comm_service_exit_nousb_delay	; disconnected -> exit
comm_mode4a:
	btfsc	switch_right				; abort with right
	bra		comm_service_exit

	btfsc	onesecupdate
	bra		comm_mode1

	bra		comm_mode2					; cycle

comm_mode2b:
	; Startbyte found
	rcall	comm_write_byte				; wait for UART
	movlw	0x4B
	movwf	TXREG1						; send answer
	; Now, check comm command

	rcall	comm_get_byte				; first byte
	rcall	comm_write_byte				; wait for UART
	movff	RCREG1,TXREG1				; Echo
	movlw	UPPER comm_service_key
	cpfseq	RCREG1
	bra		comm_mode1					; wrong -> restart
	rcall	comm_get_byte				; second byte
	rcall	comm_write_byte				; wait for UART
	movff	RCREG1,TXREG1				; echo
	movlw	HIGH (comm_service_key & 0xFFFF)
	cpfseq	RCREG1
	bra		comm_mode1					; wrong -> restart
	rcall	comm_get_byte				; third byte
	rcall	comm_write_byte				; wait for UART
	movff	RCREG1,TXREG1				; echo
	movlw	LOW comm_service_key
	cpfseq	RCREG1
	bra		comm_mode1					; wrong -> restart

	; Enable comm service mode
	WIN_SMALL comm_status2_column, comm_status2_row
	STRCPY_TEXT_PRINT tUsbServiceMode	; service mode enabled
	bsf		comm_service_enabled		; set flag...
	bra		comm_download_mode0			; ... but use common routine

comm_service_exit_nousb_delay:
	WAITMS	d'200'
	btfsc	vusb_in						; USB plugged in?
	bra		comm_mode4a					; YES - (still) connected, return
comm_service_exit_nousb:				; NO  - disconnected -> exit
	WIN_SMALL comm_status3_column, comm_status3_row
	STRCPY_TEXT_PRINT tUsbClosed		; port closed
	bra		comm_service_exit_common

comm_service_exit:
	WIN_SMALL	comm_status3_column, comm_status3_row
	STRCPY_TEXT_PRINT	tUsbExit		; exited
comm_service_exit_common:
	rcall	comm_write_byte				; wait for UART
	movlw	0xFF						; reply FF
	movwf	TXREG1						; send answer

	call	wait_1s						; wait 1 second
	call	wait_1s						; wait 1 second

	call	disable_rs232
	goto	restart

;-----------------------------------------------------------------------------

comm_service_ll_bootloader:
	bsf		LEDr
	WIN_SMALL comm_status3_column, comm_status3_row
	STRCPY_TEXT_PRINT tUsbLlBld							; low level bootloader started
	WIN_TOP  comm_warning_row
	WIN_LEFT comm_warning_column
	TFT_WRITE_PROM_IMAGE_BY_LABEL dive_warning2_block	; show warning icon
	goto	0x1FF0C

;-----------------------------------------------------------------------------
; send firmware to bootloader
;
comm_send_firmware:
	movlw	0x50						; send echo
	movwf	TXREG1
	rcall	comm_write_byte				; wait for UART

	; Read 5 bytes into buffer.
	lfsr	FSR2,buffer
	movlw	.5							; counter
	movwf	lo
	movlw	0x55						; 5'ft byte checksum
	movwf	hi

comm_send_firmware_loop:
	rcall	comm_get_byte
	btfsc	rs232_receive_overflow		; got byte?
	bra		comm_send_firmware_abort	; NO - abort
	movf	RCREG1,W
	movwf	POSTINC2					; store checksum byte
	xorwf	hi,F						; also xor into checksum
	rlncf	hi,F						; and rotate it
	decfsz	lo,F
	bra		comm_send_firmware_loop

	; check that 5ft byte checksum's checksum
	movf	hi,W
	bnz		comm_send_firmware_failed

	movlw	0x4C						; send OK
	movwf	TXREG1
	rcall	comm_write_byte				; wait for UART

	; Passed: goto second stage verification.
	; NOTE: Bootloader is Bank0. With buffer at address 0x200.
	call	vault_decodata_into_eeprom	; store last deco data (and time/date) into EEPROM
	goto	0x1FDF0						; and pray...

comm_send_firmware_failed:
	WIN_SMALL comm_string_column, comm_string_row
	call	TFT_warnings_color
	STRCPY_PRINT "Checksum failed"

comm_send_firmware_abort:

	movlw	0xFF						; send ABORTED byte
	movwf	TXREG1
	bra		comm_download_mode0			; done

;-----------------------------------------------------------------------------
; Reset to Dive 1 in logbook

comm_reset_logbook_pointers:
	call	eeprom_reset_logbook_pointers	; clear logbook pointers in EEPROM...
	call	ext_flash_erase_logbook			; ... and complete logbook (!)
	bra		comm_download_mode0				; done

;-----------------------------------------------------------------------------
comm_reset_battery_gauge:				; resets battery gauge registers
	call	reset_battery_pointer		; resets battery pointer 0x07-0x0C and battery_gauge:5
	bra		comm_download_mode0			; done

;-----------------------------------------------------------------------------
; erases range in 4 kB steps

comm_erase_range4kb:
	movlw	0x42						; send echo
	movwf	TXREG1
	rcall	comm_write_byte				; wait for UART
	bcf		INTCON,GIE					; all interrupts off!
	rcall	comm_get_flash_address		; get three bytes address or return
	btfsc	rs232_receive_overflow		; got data?
	bra		comm_download_mode0			; NO - done
	rcall	comm_get_byte
	btfsc	rs232_receive_overflow		; got byte?
	bra		comm_download_mode0			; NO - done
	movff	RCREG1,lo
	; Got 4 bytes: 3 bytes address and 1 byte (lo) amount of 4kB blocks
comm_erase_range4kb_loop:
	call	ext_flash_erase4kB			; erase block
	movlw	0x10
	addwf	ext_flash_address+1,F
	movlw	.0
	addwfc	ext_flash_address+2,F		; increase address by .4096, or 0x1000
	decfsz	lo,F
	bra		comm_erase_range4kb_loop	; loop until lo=zero
	bra		comm_download_mode0			; done (sends the 4C OK too)

;-----------------------------------------------------------------------------

comm_erase_4kb:							; get 3 bytes start address
	bcf		INTCON,GIE					; all interrupts off

	rcall	comm_get_flash_address		; get three bytes address or return
	btfsc	rs232_receive_overflow		; got data?
	bra		comm_download_mode0			; NO - done

	call	ext_flash_erase4kB			; erase one block
	bra		comm_download_mode0			; done

;-----------------------------------------------------------------------------

comm_write_range:						; get 3 bytes start address
	movlw	0x30						; send echo
	movwf	TXREG1
	rcall	comm_write_byte				; wait for UART

	bcf		INTCON,GIE					; all interrupts off

	rcall	comm_get_flash_address		; get three bytes address or return
	btfsc	rs232_receive_overflow		; got data?
	bra		comm_download_mode0			; NO - done

comm_write_range_loop:
	rcall	comm_get_byte
	btfsc	rs232_receive_overflow		; got byte?
	bra		comm_download_mode0			; NO - done (and send OK byte too)
	movf	RCREG1,W
;	bsf		NCTS						; hold Bluetooth chip (requires PC/Android/iOS side to use flow control...)
	call	ext_flash_byte_write_comms	; write one byte
;	bcf		NCTS						; release Bluetooth chip (requires PC/Android/iOS side to use flow control...)
	call	incf_ext_flash_address_p1	; increase address+1
	bra	comm_write_range_loop

;-----------------------------------------------------------------------------

comm_send_range:						; get 3 bytes start address and 3 bytes amount
	movlw	0x20						; send echo
	movwf	TXREG1
	rcall	comm_write_byte				; wait for UART
	bcf		INTCON,GIE					; all interrupts off
	rcall	comm_get_flash_address		; get three bytes address or return
	btfsc	rs232_receive_overflow		; got data?
	bra		comm_download_mode0			; NO - done
	rcall	comm_get_byte
	btfsc	rs232_receive_overflow		; got byte?
	bra		comm_download_mode0			; NO - done
	movff	RCREG1,up
	rcall	comm_get_byte
	btfsc	rs232_receive_overflow		; got byte?
	bra		comm_download_mode0			; NO - done
	movff	RCREG1,hi
	rcall	comm_get_byte
	btfsc	rs232_receive_overflow		; got byte?
	bra		comm_download_mode0			; NO - done
	movff	RCREG1,lo
	; if lo==0, we must precondition hi because there are too many bytes sent
	movf	lo,W
	bnz		$+4
	decf	hi,F
	movlw	0x40
	cpfslt	up							; up > 0x3F?
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
	rcall	comm_write_byte				; wait for UART
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
	btfsc	rs232_receive_overflow		; got byte?
	return								; NO - return
	movff	RCREG1,ext_flash_address+2
	rcall	comm_get_byte
	btfsc	rs232_receive_overflow		; got byte?
	return								; NO - return
	movff	RCREG1,ext_flash_address+1
	rcall	comm_get_byte
	btfsc	rs232_receive_overflow		; got byte?
	return								; NO - return
	movff	RCREG1,ext_flash_address+0
	return

;-----------------------------------------------------------------------------

comm_download_mode:
	; Enable comm download mode
	WIN_SMALL comm_status2_column, comm_status2_row
	STRCPY_TEXT_PRINT tUsbDownloadMode	; download mode enabled
	bsf		INTCON,GIE					; all interrupts on
	rcall	comm_write_byte				; wait for UART
	movlw	0xBB						; command echo
	movwf	TXREG1						; send answer
comm_download_mode0:
	bsf		INTCON,GIE					; all interrupts on
	rcall	comm_write_byte				; wait for UART
	movlw	0x4C						; 4C in service mode
	btfss	comm_service_enabled
	movlw	0x4D						; 4D in download mode
	movwf	TXREG1						; send answer
	movlw	timeout_service_mode
	movwf	comm_timeout				; timeout
	bcf		switch_right
comm_download_mode1:
	bcf		onesecupdate
	dcfsnz	comm_timeout,F
	bra		comm_service_exit			; timeout -> exit
comm_download_mode2:
	rcall	comm_get_byte				; check for a byte
	btfsc	comm_service_enabled
	btg		LEDr						; blink in service mode
	btfss	vusb_in						; USB plugged in?
	bra		comm_service_exit_nousb		; NO - disconnected -> exit
	btfsc	switch_right				; abort with right button
	bra		comm_service_exit
	btfsc	onesecupdate
	bra		comm_download_mode1
	btfsc	rs232_receive_overflow
	bra		comm_download_mode2			; wait for command byte

	; command received
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
 IFDEF _rx_function
	movlw	0x70
	cpfseq	RCREG1
	bra		$+4
	bra		comm_update_ostc_rx			; send firmware from external memory 3D0800h -> 3DFFFFh to OSTC RX circuity
 ENDIF
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
	rcall	comm_write_byte				; wait for UART
	call	ext_flash_read_block_start	; 1st byte
	movwf	TXREG1
	bra		comm_send_compact_headers3	; counter 24 bit
comm_send_compact_headers_loop:
	call	ext_flash_read_block		; read one byte
	movwf	TXREG1						; start new transmit
comm_send_compact_headers3:
	rcall	comm_write_byte				; wait for UART
	decfsz	lo,F
	bra		comm_send_compact_headers_loop
	call	ext_flash_read_block_stop

	; Offset to total dive counter
	movlw	.80
	movwf	ext_flash_address+0
	call	ext_flash_read_block_start	; 1st byte
	movwf	TXREG1
	rcall	comm_write_byte				; wait for UART
	call	ext_flash_read_block		; 2nd byte
	movwf	TXREG1
	call	ext_flash_read_block_stop
	rcall	comm_write_byte				; wait for UART

	; Offset to Logbook-Profile version
	movlw	.8
	movwf	ext_flash_address+0
	call	ext_flash_byte_read			; get byte
	movwf	TXREG1
	rcall	comm_write_byte				; wait for UART
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
	rcall	comm_write_byte				; wait for UART
	call	ext_flash_read_block_start	; 1st byte
	movwf	TXREG1
	bra		comm_send_headers3			; counter 24 bit
comm_send_headers_loop:
	call	ext_flash_read_block		; read one byte
	movwf	TXREG1						; start new transmit
comm_send_headers3:
	rcall	comm_write_byte				; wait for UART
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

	rcall	comm_write_byte				; wait for UART
	rcall	comm_get_byte
	btfsc	rs232_receive_overflow		; got byte?
	bra		comm_download_mode0			; NO - abort
	movff	RCREG1, hours
	movlw	d'24'
	cpfslt	hours
	clrf	hours
	rcall	comm_get_byte
	btfsc	rs232_receive_overflow		; got byte?
	bra		comm_download_mode0			; NO - abort
	movff	RCREG1, mins
	movlw	d'60'
	cpfslt	mins
	clrf	mins
	rcall	comm_get_byte
	btfsc	rs232_receive_overflow		; got byte?
	bra		comm_download_mode0			; NO - abort
	movff	RCREG1, secs
	movlw	d'60'
	cpfslt	secs
	clrf	secs
	rcall	comm_get_byte
	btfsc	rs232_receive_overflow		; got byte?
	bra		comm_download_mode0			; NO - abort
	movff	RCREG1, month
	movlw	d'13'
	cpfslt	month
	movwf	month
	rcall	comm_get_byte
	btfsc	rs232_receive_overflow		; got byte?
	bra		comm_download_mode0			; NO - abort
	call	comm_check_day				; check day
	rcall	comm_get_byte
	btfsc	rs232_receive_overflow		; got byte?
	bra		comm_download_mode0			; NO - abort
	movff	RCREG1, year
	movlw	d'100'
	cpfslt	year
	clrf	year
	; all ok, set RTCC
	call	rtc_set_rtc					; writes mins,sec,hours,day,month and year to RTC module
	bra		comm_download_mode0			; done, back to loop with timeout reset

;-----------------------------------------------------------------------------
; Set custom text string (opt_name_length ASCII chars)
;

comm_set_custom_text:
	movlw	"c"							; send echo
	movwf	TXREG1
	rcall	comm_write_byte				; wait for UART
	lfsr	FSR2,opt_name
	movlw	opt_name_length
	movwf	lo							; counter
comm_set_ctext_loop:
	rcall	comm_get_byte
	btfsc	rs232_receive_overflow		; got byte?
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
	rcall	comm_write_byte				; wait for UART

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
	rcall	comm_write_byte
	movff	hi,TXREG1
	rcall	comm_write_byte

	;---- Emit firmware hi.lo
	movlw	softwareversion_x
	movwf	TXREG1
	rcall	comm_write_byte
	movlw	softwareversion_y
	movwf	TXREG1
	rcall	comm_write_byte

	;---- Emit custom text
	movlw	opt_name_length
	movwf	hi
	lfsr	FSR2,opt_name

common_identify_loop:
	movff	POSTINC2,TXREG1
	rcall	comm_write_byte
	decfsz	hi,F
	bra		common_identify_loop

	bra		comm_download_mode0			; done

;-----------------------------------------------------------------------------

comm_get_byte:
	goto	rs232_get_byte				; ... and return

comm_write_byte:
	goto	rs232_wait_tx				; ... and return

;-----------------------------------------------------------------------------
; Reply hardware descriptor byte
;

comm_hardware_descriptor:
	movlw	"j"							; send echo
	movwf	TXREG1
	rcall	comm_write_byte				; wait for UART
	movff	hardware_flag1,TXREG1
	bra		comm_download_mode0			; done

comm_feature_and_hardware:
	movlw	0x60						; send echo
	movwf	TXREG1
	rcall	comm_write_byte				; wait for UART
	movlw	0x00						; hardware high byte
	movwf	TXREG1
	rcall	comm_write_byte				; wait for UART
	movff	hardware_flag1,TXREG1
	rcall	comm_write_byte				; wait for UART
	movlw	0x00						; feature high Byte
	movwf	TXREG1
	rcall	comm_write_byte				; wait for UART
	movlw	0x00						; feature low Byte
	movwf	TXREG1
	rcall	comm_write_byte				; wait for UART
	movlw	0x00						; model descriptor byte
	movwf	TXREG1
	bra		comm_download_mode0			; done

;-----------------------------------------------------------------------------

 IFDEF _rx_function

comm_update_ostc_rx:
	movlw	0x70						; send echo
	movwf	TXREG1
	rcall	comm_write_byte				; wait for UART
;	btfss	ostc_rx_present				; rx model?
;	bra		comm_download_mode0			; NO - abort

	; Setup ext_flash_address:3
	movlw	LOW   0x3D0800
	movwf	ext_flash_address+0
	movlw	HIGH  (0x3D0800 & 0xFFFF)	; <- & 0xFFFF to suppress warning message...
	movwf	ext_flash_address+1
	movlw	UPPER 0x3D0800
	movwf	ext_flash_address+2

	bsf		active_reset_ostc_rx
	WAITMS	.5
	bcf		active_reset_ostc_rx
	WAITMS	.100
	bcf		INTCON,GIE					; halt all interrupts

	movlw	LOW  .992
	movwf	uart1_temp
	movlw	HIGH .992
	movwf	uart2_temp
	incf	uart2_temp,F				; ++1
	WAITMS	.1

	call	ext_flash_read_block_start
	movwf	up							; first byte to write

comm_update_ostc_rx_loop:				; (run 992 times)
	WIN_SMALL comm_status4_column, comm_status4_row
	movff	uart1_temp,xA+0
	movf	uart2_temp,W
	tstfsz	uart2_temp
	decf	uart2_temp,W				; --1 for display
	movwf	xA+1
	movlw	.64
	movwf	xB+0
	clrf	xB+1
	call	mult16x16					; xA * xB = xC
	movff	xC+0,lo
	movff	xC+1,hi
	bsf		leftbind
	output_16
	bcf		leftbind
	STRCAT_PRINT " Bytes left  "

	call	I2C_update_OSTC_rx			; send firmware from external memory 3D0800h -> 3DFFFFh to OSTC RX circuity

	tstfsz	WREG						; returns with WREG=0 if everything was ok
	bra		comm_update_ostc_rx_loop_error	; error -> abort

	decfsz	uart1_temp,F
	bra		comm_update_ostc_rx_loop
	decfsz	uart2_temp,F
	bra		comm_update_ostc_rx_loop

comm_update_ostc_rx_loop_done:
	call	ext_flash_read_block_stop
	bsf		INTCON,GIE
	WIN_SMALL comm_status4_column, comm_status4_row
	STRCPY_PRINT "                "
	bra		comm_download_mode0			; done

comm_update_ostc_rx_loop_error:
	bsf		INTCON,GIE
	WIN_SMALL comm_status4_column, comm_status4_row
	STRCPY_PRINT "ERROR. Retry!  "
	call	wait_1s						; do not use for time critical routines, can be between 0 and 1 sec!
	call	wait_1s						; do not use for time critical routines, can be between 0 and 1 sec!
	call	wait_1s						; do not use for time critical routines, can be between 0 and 1 sec!
	bra		comm_update_ostc_rx_loop_done

 ENDIF

;-----------------------------------------------------------------------------

comm_send_dive:
	movlw	"f"; 0x66					; send echo
	movwf	TXREG1

	rcall	comm_get_byte
	btfsc	rs232_receive_overflow		; got byte?
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
	rcall	comm_write_byte				; wait for UART
	call	ext_flash_read_block_start	; 1st byte
	movwf	TXREG1
	bra		comm_send_dive_header
comm_send_dive_header2:
	call	ext_flash_read_block		; read one byte
	movwf	TXREG1						; start new transmit
comm_send_dive_header:
	rcall	comm_write_byte				; wait for UART
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
	rcall	comm_write_byte					; wait for UART
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

	rcall	comm_write_byte				; wait for UART
	bra		comm_download_mode0			; done, loop with timeout reset

;-----------------------------------------------------------------------------

comm_read_setting:
	movlw	"r"
	movwf	TXREG1
	rcall	comm_get_byte
	btfsc	rs232_receive_overflow		; got byte?
	bra		comm_read_abort				; NO - abort!
	rcall	comm_write_byte				; wait for UART
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
	movff	char_I_ppO2_max,			TXREG1	; RCREG1=0x22
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
	movff	char_I_bottom_usage,		TXREG1	; RCREG1=0x3C
	dcfsnz	WREG
	movff	char_I_deco_usage,			TXREG1	; RCREG1=0x3D
	dcfsnz	WREG
	movff	opt_modwarning,				TXREG1	; RCREG1=0x3E
	dcfsnz	WREG
	movff	opt_vsitextv2,				TXREG1	; RCREG1=0x3F
	dcfsnz	WREG
	movff	opt_vsigraph,				TXREG1	; RCREG1=0x40
	dcfsnz	WREG
	movff	opt_showppo2,				TXREG1	; RCREG1=0x41
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
	movff	char_I_tank_size+0,			TXREG1	; RCREG1=0x4E
	dcfsnz	WREG
	movff	char_I_tank_size+1,			TXREG1	; RCREG1=0x4F
	dcfsnz	WREG
	movff	char_I_tank_size+2,			TXREG1	; RCREG1=0x50
	dcfsnz	WREG
	movff	char_I_tank_size+3,			TXREG1	; RCREG1=0x51
	dcfsnz	WREG
	movff	char_I_tank_size+4,			TXREG1	; RCREG1=0x52
	dcfsnz	WREG
	movff	char_I_tank_pres_fill+0,	TXREG1	; RCREG1=0x53
	dcfsnz	WREG
	movff	char_I_tank_pres_fill+1,	TXREG1	; RCREG1=0x54
	dcfsnz	WREG
	movff	char_I_tank_pres_fill+2,	TXREG1	; RCREG1=0x55
	dcfsnz	WREG
	movff	char_I_tank_pres_fill+3,	TXREG1	; RCREG1=0x56
	dcfsnz	WREG
	movff	char_I_tank_pres_fill+4,	TXREG1	; RCREG1=0x57
	dcfsnz	WREG
	movff	char_I_cc_max_frac_o2,		TXREG1	; RCREG1=0x58
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
	movff	char_I_tank_size+5,			TXREG1	; RCREG1=0x74
	dcfsnz	WREG
	movff	char_I_tank_size+6,			TXREG1	; RCREG1=0x75
	dcfsnz	WREG
	movff	char_I_tank_size+7,			TXREG1	; RCREG1=0x76
	dcfsnz	WREG
	movff	char_I_tank_size+8,			TXREG1	; RCREG1=0x77
	dcfsnz	WREG
	movff	char_I_tank_size+9,			TXREG1	; RCREG1=0x78
	dcfsnz	WREG
	movff	char_I_tank_pres_fill+5,	TXREG1	; RCREG1=0x79
	dcfsnz	WREG
	movff	char_I_tank_pres_fill+6,	TXREG1	; RCREG1=0x7A
	dcfsnz	WREG
	movff	char_I_tank_pres_fill+7,	TXREG1	; RCREG1=0x7B
	dcfsnz	WREG
	movff	char_I_tank_pres_fill+8,	TXREG1	; RCREG1=0x7C
	dcfsnz	WREG
	movff	char_I_tank_pres_fill+9,	TXREG1	; RCREG1=0x7D
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
	rcall	comm_write_byte				; wait for UART
	addlw	.10							; increment index by 10, addressing He ratio now
	movff	PLUSW0, TXREG1				; transmit He ratio
	rcall	comm_write_byte				; wait for UART
	addlw	.10							; increment index by 10, addressing gas/dil type now
	movff	PLUSW0, TXREG1				; transmit gas/dil type
	rcall	comm_write_byte				; wait for UART
	addlw	.10							; increment index by 10, addressing change depth now
	movff	PLUSW0,TXREG1				; transmit change depth
	bra		comm_read_done				; done, wait for UART and loop with timeout reset


; Memory map is as follows:
; -------------------------
; char_I_setpoint_cbar			res 5	; setpoints in cbar
; char_I_setpoint_change		res 5	; change depth for the setpoints in meter

comm_read_sp:
	lfsr	FSR0,char_I_setpoint_cbar	; load base address of setpoint cbar values
	movf	up,W						; load index (0-4) of setpoint into WREG, addressing cbar value
	movff	PLUSW0, TXREG1				; transmit setpoint cbar value
	rcall	comm_write_byte				; wait for UART
	addlw	.5							; increment index by 5, addressing change depth now
	movff	PLUSW0, TXREG1				; transmit change depth
	bra		comm_read_done				; done, wait for UART and loop with timeout reset

;-----------------------------------------------------------------------------

comm_write_setting:
	movlw	"w"
	movwf	TXREG1
	rcall	comm_get_byte					; "Byte 2"
	btfsc	rs232_receive_overflow			; got byte?
	bra		comm_write_abort				; NO - abort!
	movff	RCREG1,lo						; copy
	rcall	comm_get_byte					; "Byte 3"
	rcall	comm_write_byte					; wait for UART
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
	movff	RCREG1, char_I_ppO2_max			; RCREG1=0x22
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
	movff	RCREG1, char_I_bottom_usage		; RCREG1=0x3C
	dcfsnz	WREG
	movff	RCREG1, char_I_deco_usage		; RCREG1=0x3D
	dcfsnz	WREG
	movff	RCREG1, opt_modwarning			; RCREG1=0x3E
	dcfsnz	WREG
	movff	RCREG1, opt_vsitextv2			; RCREG1=0x3F
	dcfsnz	WREG
	movff	RCREG1, opt_vsigraph			; RCREG1=0x40
	dcfsnz	WREG
	movff	RCREG1, opt_showppo2			; RCREG1=0x41
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
	movff	RCREG1, char_I_tank_size+0		; RCREG1=0x4E
	dcfsnz	WREG
	movff	RCREG1, char_I_tank_size+1		; RCREG1=0x4F
	dcfsnz	WREG
	movff	RCREG1, char_I_tank_size+2		; RCREG1=0x50
	dcfsnz	WREG
	movff	RCREG1, char_I_tank_size+3		; RCREG1=0x51
	dcfsnz	WREG
	movff	RCREG1, char_I_tank_size+4		; RCREG1=0x52
	dcfsnz	WREG
	movff	RCREG1, char_I_tank_pres_fill+0	; RCREG1=0x53
	dcfsnz	WREG
	movff	RCREG1, char_I_tank_pres_fill+1	; RCREG1=0x54
	dcfsnz	WREG
	movff	RCREG1, char_I_tank_pres_fill+2	; RCREG1=0x55
	dcfsnz	WREG
	movff	RCREG1, char_I_tank_pres_fill+3	; RCREG1=0x56
	dcfsnz	WREG
	movff	RCREG1, char_I_tank_pres_fill+4	; RCREG1=0x57
	dcfsnz	WREG
	movff	RCREG1, char_I_cc_max_frac_o2	; RCREG1=0x58
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
	movff	RCREG1, char_I_tank_size+5		; RCREG1=0x74
	dcfsnz	WREG
	movff	RCREG1, char_I_tank_size+6		; RCREG1=0x75
	dcfsnz	WREG
	movff	RCREG1, char_I_tank_size+7		; RCREG1=0x76
	dcfsnz	WREG
	movff	RCREG1, char_I_tank_size+8		; RCREG1=0x77
	dcfsnz	WREG
	movff	RCREG1, char_I_tank_size+9		; RCREG1=0x78
	dcfsnz	WREG
	movff	RCREG1, char_I_tank_pres_fill+5	; RCREG1=0x79
	dcfsnz	WREG
	movff	RCREG1, char_I_tank_pres_fill+6	; RCREG1=0x7A
	dcfsnz	WREG
	movff	RCREG1, char_I_tank_pres_fill+7	; RCREG1=0x7B
	dcfsnz	WREG
	movff	RCREG1, char_I_tank_pres_fill+8	; RCREG1=0x7C
	dcfsnz	WREG
	movff	RCREG1, char_I_tank_pres_fill+9	; RCREG1=0x7D
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

comm_write_abort:
comm_write_done:
	; check options, gases and diluents
	call	option_check_all			; check all options (and reset if not within their min/max boundaries)
	bsf		FLAG_diluent_setup			; =1: setting up diluents
	call	gaslist_cleanup_list		; take care that only one gas can be first and first has 0m change depth
	bcf		FLAG_diluent_setup			; =1: Setting up diluents
	call	gaslist_cleanup_list		; take care that only one gas can be first and first has 0m change depth
	call	get_first_gas_to_WREG		; make sure at least one gas is "First"
	call	get_first_dil_to_WREG		; make sure at least one diluent is "First"
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
; char_I_setpoint_cbar			res 5	; setpoints in cbar
; char_I_setpoint_change		res 5	; change depth for the setpoints in meter

comm_write_sp:
	lfsr	FSR0,char_I_setpoint_cbar	; load base address of setpoint cbar values
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
	call	comm_write_byte				; wait for UART
	WIN_SMALL comm_string_column, comm_string_row
	movlw	.16
	movwf	lo							; counter
comm_send_string_loop:
	call	comm_get_byte
	btfsc	rs232_receive_overflow		; got byte?
	bra		comm_send_string_abort		; NO - abort!
	movff	RCREG1,POSTINC2				; store character
	decfsz	lo,F
	bra		comm_send_string_loop
comm_send_string_abort:
	STRCAT_PRINT ""						; show the text
	goto	comm_download_mode0			; done, loop with timeout reset

;-----------------------------------------------------------------------------

comm_check_day:
	movff	RCREG1,day
	movff	month,lo					; new month
	dcfsnz	lo,F
	movlw	.31
	dcfsnz	lo,F
	movlw	.28
	dcfsnz	lo,F
	movlw	.31
	dcfsnz	lo,F
	movlw	.30
	dcfsnz	lo,F
	movlw	.31
	dcfsnz	lo,F
	movlw	.30
	dcfsnz	lo,F
	movlw	.31
	dcfsnz	lo,F
	movlw	.31
	dcfsnz	lo,F
	movlw	.30
	dcfsnz	lo,F
	movlw	.31
	dcfsnz	lo,F
	movlw	.30
	dcfsnz	lo,F
	movlw	.31
	cpfsgt	day							; day ok?
	return								; YES
	movlw	.1							; NO - set to 1st
	movwf	day
	return

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