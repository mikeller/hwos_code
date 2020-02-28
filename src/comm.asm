;=============================================================================
;
;   File comm.asm                             combined next generation V3.08.8
;
;   RS232 via USB
;
;   Copyright (c) 2012, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;  2011-08-22 : [mH] Creation
;  2012-02-11 : [jDG] Added 0x63 set custom text, and "i" identify

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
#include "i2c.inc"
#include "logbook.inc"


	extern	restart
	extern	option_reset_all
	extern	option_check_and_store_all
	extern	option_read_serial
	extern	option_write_serial
	extern	gaslist_cleanup_list
	extern	eeprom_deco_data_write


; timeouts
#DEFINE timeout_comm_pre_mode	.240	; [sec] timeout before communication is established
#DEFINE timeout_service_mode	.120	; [sec] timeout when   communication is established

; positioning of title
#DEFINE comm_title_row			.0
#DEFINE comm_title_column_usb	.40
#DEFINE comm_title_column_ble	.25

; positioning of host-sent text messages
#DEFINE comm_string_row			.30
#DEFINE comm_string_column		.40

; positioning of COMM mode status messages
#DEFINE comm_status1_row		.70
#DEFINE comm_status1_column		.10
#DEFINE comm_status2_row		.100
#DEFINE comm_status2_column		comm_status1_column
#DEFINE comm_status3_row		.130
#DEFINE comm_status3_column		comm_status1_column
#DEFINE	comm_status4_row		.160
#DEFINE	comm_status4_column		comm_status1_column

; positioning of COMM mode warning icon
#DEFINE comm_warning_row		.160
#DEFINE comm_warning_column		.65


;#DEFINE	testloop_avail				; uncomment if testloop code is available


comm	CODE

;=============================================================================

	global	comm_mode_usb
comm_mode_usb:										; entry point for comm mode via USB
	WAITMS	d'1'									; wait 1 ms
	btfss	vusb_in									; USB still plugged in?
	return											; NO  - it was only a glitch, abort
	WAITMS	d'1'									; YES - wait 1 ms
	btfss	vusb_in									;     - USB still plugged in?
	return											;       NO  - it was only a glitch, abort
	bsf		aux_flag								;       YES - remember to show USB title
	bra		comm_mode_common						;           - continue with common part

	global	comm_mode_ble
comm_mode_ble:										; entry point for comm mode via BLE
	bcf		aux_flag								; remember to show BLE title
	;bra	comm_mode_common						; continue with common part

comm_mode_common:
	clrf	STKPTR									; reset addresses stack
	call	TFT_ClearScreen							; clear screen
	WIN_COLOR color_greenish						; set color

	btfss	aux_flag								; shall show USB title?
	bra		comm_mode_common_1						; NO  - show BLE title
	WIN_SMALL comm_title_column_usb, comm_title_row	; YES - set   USB title position
	STRCPY_TEXT_PRINT tUsbTitle						;     - print USB title text
	bra		comm_mode_common_2						;     - continue with common part

comm_mode_common_1:
	WIN_SMALL comm_title_column_ble, comm_title_row	; set   BLE title position
	STRCPY_TEXT_PRINT tBleTitle						; print BLE title text
	;bra	comm_mode_common_2						; continue with common part

comm_mode_common_2:
	call	TFT_standard_color						; set standard color
	WIN_TOP  .10									; set position of USB/BLE logo, row
	WIN_LEFT .1										; set position of USB/BLE logo, column
	btfsc	battery_gauge_available					; "+" bootloader ?
	bra		comm_mode_common_3						; NO  - show logo type 1
	TFT_WRITE_PROM_IMAGE_BY_ADDR usb_ble_logo_2		; YES - show USB/BLE logo 2
	bra		comm_mode_common_4						;     - continue with common part

comm_mode_common_3:
	TFT_WRITE_PROM_IMAGE_BY_ADDR usb_ble_logo_1		; show logo type 1
	;bra	comm_mode_common_4						; continue with common part

comm_mode_common_4:
	WIN_SMALL comm_status1_column,comm_status1_row	; print status message "starting..."
	STRCPY_TEXT_PRINT tUsbStarting					; ...

	WIN_TINY .40,.240-.16							; set output position to bottom line
	call	TFT_show_serial_and_firmware			; show serial number and firmware version

 IFDEF _screendump
	bcf		screen_dump_avail						; disable screen dump function
 ENDIF

	bcf		switch_right							; clear potential left-over right button event
	call	enable_rs232							; enable serial comm, also sets CPU to normal speed

	WIN_SMALL comm_status1_column+.80,comm_status1_row	; print (adding to status message) "done..."
	STRCPY_TEXT_PRINT tUsbStartDone						; ...

	movlw	timeout_comm_pre_mode					; get timeout for phase without communication established yet
	movwf	comm_timeout_timer						; initialize timeout counter

comm_mode_selection_loop:
	bcf		trigger_full_second						; clear 'one second elapsed' flag
	bcf		LEDr									; switch off red LED / power down TR co-processor
	dcfsnz	comm_timeout_timer,F					; decrement timeout, reached zero?
	bra		comm_service_exit						; YES - timeout, exit comm mode
	;bra	comm_mode_selection_loop_1				; NO  - try to receive a byte
comm_mode_selection_loop_1:
	SERIAL_CC_RECEIVE lo							; (try to) receive 1 byte
	btfsc	rs232_rx_timeout						; timeout?
	bra		comm_mode_selection_loop_2				; YES - check for comm mode termination
	movf	lo,W									; NO  - copy received byte to lo
	xorlw	0xAA									;     - service mode start byte received?
	bz		comm_service_mode_check					;       YES - check if correct key will be send
	movf	lo,W									;       NO  - copy received byte to lo again
	xorlw	0xBB									;           - download mode start byte received?
	bz		comm_download_mode						;              YES - enter command loop
	;bra	comm_mode_selection_loop_2				;              NO  - check for comm mode termination
comm_mode_selection_loop_2:
	btfsc	ble_available							; BLE available?
	bra		comm_mode_selection_loop_3				; YES - skip USB check check (required for very old OSTC sport)
	btfss	vusb_in									; NO  - USB plugged in?
	bra		comm_service_exit_nousb_delay			;       NO  - disconnected, check for vusb_in glitch
	;bra	comm_mode_selection_loop_3				;       YES - check for exit button or continue looping
comm_mode_selection_loop_3:
	btfsc	switch_right							; right button pressed?
	bra		comm_service_exit						; YES - exit comm mode
	btfsc	trigger_full_second						; NO  - did 1 second elapsed meanwhile?
	bra		comm_mode_selection_loop				;       YES - loop with    clocking down timeout counter
	bra		comm_mode_selection_loop_1				;       NO  - loop without clocking down timeout counter


;-----------------------------------------------------------------------------
; Received start byte for service mode, await service key
;
comm_service_mode_check:

	SERIAL_LC_SEND 0x4B								; request peer to send service key

	; receive a 3 byte service key transmitted in big-endian, echo each byte

	clrf	WREG									; clear WREG

	SERIAL_CC_RECEIVE lo							; receive 1st byte, store in lo
	xorwf	lo,W									; exclusive-or received byte into WREG
	xorlw	UPPER (comm_service_key)				; exclusive-or expected byte into WREG
	SERIAL_CC_SEND    lo							; echo 1st byte

	SERIAL_CC_RECEIVE lo							; receive 2nd byte, store in lo
	xorwf	lo,W									; exclusive-or received byte into WREG
	xorlw	HIGH  (comm_service_key & 0xFFFF)		; exclusive-or expected byte into WREG
	SERIAL_CC_SEND    lo							; echo 2nd byte

	SERIAL_CC_RECEIVE lo							; receive 3rd byte, store in lo
	xorwf	lo,W									; exclusive-or received byte into WREG
	xorlw	LOW   (comm_service_key & 0xFFFF)		; exclusive-or expected byte into WREG
	SERIAL_CC_SEND    lo							; echo 3rd byte

	; check for correct service key
	tstfsz	WREG									; received expected service key?
	bra		comm_mode_selection_loop				; NO  - back to mode selection loop
	WIN_SMALL comm_status2_column, comm_status2_row	; YES - print service mode enabled message
	STRCPY_TEXT_PRINT tUsbServiceMode				;     - ...
	bsf		comm_service_mode						;     - enable service mode commands
	bra		comm_command_loop						;     - enter command loop


;-----------------------------------------------------------------------------
; Received start byte for download mode
;
comm_download_mode:
	SERIAL_LC_SEND 0xBB								; inform peer download mode will be started

	WIN_SMALL comm_status2_column, comm_status2_row	; print download mode enabled message
	STRCPY_TEXT_PRINT tUsbDownloadMode				; ... 
	bcf		comm_service_mode						; disable service mode commands
	bra		comm_command_loop						; enter command loop


;-----------------------------------------------------------------------------
; Notify RX timeout occurred
;
comm_command_timeout:
	; select font and output position
	WIN_SMALL comm_string_column, comm_string_row
	call	TFT_warning_color			; select color
	STRCPY_PRINT "Data Rx Timeout"		; print failure message (fill to 15 chars)
	call	TFT_standard_color			; back to standard color
	bra		comm_command_loop			; re-enter command loop


;-----------------------------------------------------------------------------
; Notify error in parameters
;
comm_command_error:
	; select font and output position
	WIN_SMALL comm_string_column, comm_string_row
	call	TFT_warning_color			; switch to waring color
	STRCPY_PRINT "Parameter Error"		; print failure message (fill to 15 chars)
	call	TFT_standard_color			; back to standard color
	;bra	comm_command_loop			; re-enter command loop


;-----------------------------------------------------------------------------
; Command loop: wait for a command
;
comm_command_loop:
	; (re-)initialize
	bsf		INTCON,GIE								; re-enable all interrupts
	movlw	timeout_service_mode					; get    timeout value
	movwf	comm_timeout_timer						; reload timeout timer

	; request peer to send a command
	movlw	0x4D									; default request code is 0x4D for download mode active
	btfsc	comm_service_mode						; service mode enabled?
	movlw	0x4C									; YES - change request to 0x4C for service  mode active
	SERIAL_CC_SEND WREG								; send request

	; wait for peer to send a command
comm_command_loop_wait:
	SERIAL_CC_RECEIVE lo							; (try to) receive a command byte
	btfss	rs232_rx_timeout						; timeout?
	bra		comm_command_decode						; NO  - decode and execute the command
	btfsc	comm_service_mode						; YES - service mode enabled?
	btg		LEDr									;       YES - blink in service mode
	btfsc	ble_available							;     - BLE available?
	bra		comm_command_loop_wait_1				;       YES - skip USB check (required for very old OSTC sport)
	btfss	vusb_in									;       NO  - USB still plugged in?
	bra		comm_service_exit_nousb					;             NO  - disconnected -> exit comm mode
comm_command_loop_wait_1:
	btfsc	switch_right							; right button (abort) pressed?
	bra		comm_service_exit						; YES - exit comm mode
	btfss	trigger_full_second						; NO  - did 1 second elapsed meanwhile?
	bra		comm_command_loop_wait					;       NO  - loop
	dcfsnz	comm_timeout_timer,F					;       YES - decrement the timeout timer, reached zero?
	bra		comm_service_exit						;             YES - exit comm mode
	bcf		trigger_full_second						;             NO  - clear 'one second elapsed' flag
	bra		comm_command_loop_wait					;                 - loop


;-----------------------------------------------------------------------------
; Macro for easier writing of command decoding rules
;
command_decode  macro  command_id,command_function
	movf	lo,W				; copy received command to WREG
	xorlw	command_id			; exclusive-or with command ID
	btfsc	STATUS,Z			; received command = command ID ?
	goto	command_function	; YES - execute command
	endm

;-----------------------------------------------------------------------------
; Decode and execute a command
;
comm_command_decode:
	bcf		LEDr									; switch off red led

	; decode and execute standard commands
	command_decode 0x6E,comm_show_text				; n  show a text on the screen
	command_decode 0x69,comm_identify				; i  send ID: serial, firmware, and custom text
	command_decode 0x6A,comm_hardware_descriptor	; j  send ID: hardware descriptor byte
	command_decode 0x60,comm_feature_and_hardware	; '  send ID: more detailed information
	command_decode 0x6D,comm_send_headers_short 	; m  send all headers in compact format
	command_decode 0x61,comm_send_headers_full		; a  send all headers is full format
	command_decode 0x66,comm_send_dive				; f  send header and profile for one dive
	command_decode 0x62,comm_set_time				; b  set the real time clock
	command_decode 0x63,comm_set_custom_text		; c  write a new custom text
	command_decode 0x72,comm_read_option			; r  read  an option value
	command_decode 0x77,comm_write_option			; w  write an option value (into RAM)
	command_decode 0x78,comm_option_reset_all		; x  reset all option values to their factory default
	command_decode 0xFF,comm_service_exit			;    exit comm mode
 IFDEF _screendump
	command_decode 0x6C,TFT_dump_screen				; l  dump the screen contents
 ENDIF

	btfss	comm_service_mode						; service mode enabled?
	bra		comm_command_loop						; NO - ignore unrecognized command, back to command loop

	; decode and execute additional service mode commands
	command_decode 0x23,comm_reset_battery_gauge	; #  reset the battery gauge registers
	command_decode 0x22,comm_erase_complete_logbook	; "  reset all logbook pointers and the logbook
	command_decode 0x20,comm_read_range				;' '  read a memory range from the external FLASH
	command_decode 0x40,comm_erase_4kb				; @  erase one        4 kB block  - Warning: no confirmation or built-in safety here...
	command_decode 0x42,comm_erase_range4kb			; B  erase a range of 4 kB blocks - Warning: no confirmation or built-in safety here...
	command_decode 0x30,comm_write_range_stream		; 0  write a stream of     bytes starting at ext_flash_address:3 until timeout
	command_decode 0x31,comm_write_range_block		; 1  write a block  of 256 bytes starting at ext_flash_address:3
	command_decode 0x50,comm_firmware_update		; P  initiate firmware update
	command_decode 0xC1,comm_cold_start				;    start low-level bootloader
 IFDEF testloop_avail
	command_decode 0x74,testloop					; t  start raw-data test loop
 ENDIF

	bra		comm_command_loop						; ignore unrecognized command, back to command loop


;-----------------------------------------------------------------------------
; Exit comm mode
;
comm_service_exit:
	WIN_SMALL comm_status3_column, comm_status3_row	; print "Exited" message
	STRCPY_TEXT_PRINT	tUsbExit					; ...
	bra		comm_service_exit_common				; acknowledge exit command and restart

comm_service_exit_nousb_delay:
	WAITMS	d'200'									; wait 200 ms
	btfsc	vusb_in									; USB sensed again?
	bra		comm_mode_selection_loop_3				; YES - was just a glitch, continue
	;bra	comm_service_exit_nousb					; NO  - proceed exiting

comm_service_exit_nousb:
	WIN_SMALL comm_status3_column, comm_status3_row	; print "Port closed" message
	STRCPY_TEXT_PRINT tUsbClosed					; ...
	;bra	comm_service_exit_common				; proceed exiting

comm_service_exit_common:
	SERIAL_LC_SEND 0xFF								; acknowledge exit command
	call	wait_1s									; wait <= 1 second
	call	wait_1s									; wait    1 second
	call	disable_rs232							; shut down comm port
	bcf		LEDr									; switch off red LED
	goto	restart									; restart


;-----------------------------------------------------------------------------
; Set Real-Time-Clock
;
comm_set_time:
	SERIAL_LC_SEND 0x62					; acknowledge command

	; receive 6 bytes coming in sequence: hour, minute, second, month, day, year
	SERIAL_RR_RECEIVE_RAM mpr,.6

	; got all 6 bytes?
	btfsc	rs232_rx_timeout			; timeout?
	bra		comm_command_timeout		; YES - abort, back to command loop

	; map the received bytes onto the rtc_latched variables
	movff	mpr+0,rtc_latched_hour
	movff	mpr+1,rtc_latched_mins
	movff	mpr+2,rtc_latched_secs
	movff	mpr+3,rtc_latched_month
	movff	mpr+4,rtc_latched_day
	movff	mpr+5,rtc_latched_year

	; set the RTC
	call	rtc_set_rtc					; write time and date to RTC module

	bra		comm_command_loop			; done, back to command loop


;-----------------------------------------------------------------------------
; Write a 15 char text to the OSTC display
;
comm_show_text:
	; set font and output position of the text to show
	WIN_SMALL comm_string_column, comm_string_row

	SERIAL_LC_SEND 0x6E					; acknowledge command

	SERIAL_RR_RECEIVE_RAM buffer,.16	; (try to) receive 16 chars and write them to 'buffer' using FSR2
	STRCAT_PRINT ""						; dump whatever was received to the screen

	bra		comm_command_loop			; done, back to command loop


;-----------------------------------------------------------------------------
; Reply Serial (2 bytes low:high), firmware (major.minor) and custom text
;
comm_identify:
	SERIAL_LC_SEND 0x69					; acknowledge command

	;---- send OSTC serial number
	call	eeprom_serial_number_read	; read OSTC serial number
	SERIAL_CC_SEND mpr+0				; send serial number, low  byte
	SERIAL_CC_SEND mpr+1				; send serial number, high byte

	;---- send firmware version
	SERIAL_LC_SEND fw_version_major		; send firmware version, major
	SERIAL_LC_SEND fw_version_minor		; send firmware version, minor

	;---- send custom text
	SERIAL_RR_SEND_RAM	opt_name,opt_name_length

	bra		comm_command_loop			; done, back to command loop


;-----------------------------------------------------------------------------
; Reply hardware descriptor byte
;
comm_hardware_descriptor:
	SERIAL_LC_SEND 0x6A					; acknowledge command

	movf	HW_descriptor,W				; get hardware descriptor
	bcf		WREG,6						; clear bit 6 for reason of compatibility with 3rd party software
	bcf		WREG,7						; clear bit 7 for reason of compatibility with 3rd party software
	SERIAL_CC_SEND WREG					; send modified hardware descriptor

	bra		comm_command_loop			; done, back to command loop


;-----------------------------------------------------------------------------
; Reply detailed hardware descriptor
;
comm_feature_and_hardware:
	SERIAL_LC_SEND 0x60					; acknowledge command

	SERIAL_LC_SEND 0x00					; send hardware high byte (fixed zero)

	movf	HW_descriptor,W				; get hardware descriptor
	bcf		WREG,6						; clear bit 6 for reason of compatibility with 3rd party software
	bcf		WREG,7						; clear bit 7 for reason of compatibility with 3rd party software
	SERIAL_CC_SEND WREG					; send modified hardware low byte

	SERIAL_LC_SEND 0x00					; send feature high byte (fixed zero)
	SERIAL_LC_SEND 0x00					; send feature low  byte (fixed zero)

	SERIAL_LC_SEND 0x00					; send model descriptor byte (fixed zero)

	bra		comm_command_loop			; done, back to command loop


;-----------------------------------------------------------------------------

comm_send_headers_short:
	SERIAL_LC_SEND 0x6D					; acknowledge command

	; send short header (16 bytes/dive)
	; index 0: 0x200009 - 0x200016  +  0x200050 - 0x200051  +  0x200008
	;       1: 0x201009 - 0x201016  +  0x201050 - 0x201051  +  0x201008
	;       2: 0x202009 - 0x202016  +  0x202050 - 0x202051  +  0x202008
	;     ...
	;     255: 0x2FF009 - 0x2FF016  +  0x2FF050 - 0x2FF051  +  0x2FF008

	clrf	ex								; start with dive having index 0
comm_send_headers_short_loop:
	movf	ex,W							; get index into WREG
	call	log_header_addr_by_index		; compute header start address from index, result in mpr

	; assemble the short header - part 1
	movlw	index_profile_byte_count		; adjust start address to first  block to go into the short header
	movwf	mpr+0							; ...
	FLASH_RR_READ mpr,header_buffer,.13		; read 13 bytes from header into buffer

	; assemble the short header - part 2
	movlw	index_total_dives				; adjust start address to second block to into the short header
	movwf	mpr+0							; ...
	FLASH_RR_READ mpr,header_buffer+.13,.2	; read  2 bytes from header into buffer

	; assemble the short header - part 3
	movlw	index_profile_version			; adjust start address to third  block to go into the short header
	movwf	mpr+0							; ...
	FLASH_RR_READ mpr,header_buffer+.15,.1	; read  1 byte  from header into buffer

	; send the assembled short header
	SERIAL_RR_SEND_RAM header_buffer,.16	; send buffer, 16 bytes to do

	; go to next header
	incfsz	ex								; increment index, wrap-around. i.e. all dives done ?
	bra		comm_send_headers_short_loop	; NO  - loop
	bra		comm_command_loop				; YES - done, back to command loop


;-----------------------------------------------------------------------------

comm_send_headers_full:
	SERIAL_LC_SEND 0x61					; acknowledge command

	; send complete headers (256 bytes/dive)
	; index 0: 0x200000 - 0x2000FF
	;       1: 0x201000 - 0x2010FF
	;       2: 0x202000 - 0x2020FF
	;     ...
	;     255: 0x2FF000 - 0x2FF0FF

	clrf	ex								; start with dive having index 0
comm_send_headers_full_loop:
	movf	ex,W							; get index into WREG
	call	log_header_addr_by_index		; compute header start address from index, result in mpr
	FLASH_RR_READ  mpr,header_buffer,.256	; get header from FLASH into memory
	SERIAL_RR_SEND_RAM header_buffer,.256	; send the header from memory to RS232
	incfsz	ex								; increment index, wrap-around. i.e. all dives done ?
	bra		comm_send_headers_full_loop		; NO  - loop
	bra		comm_command_loop				; YES - done, back to command loop


;-----------------------------------------------------------------------------
; Send one full dive
;
comm_send_dive:
	SERIAL_LC_SEND 0x66					; acknowledge command

	SERIAL_CC_RECEIVE WREG				; (try to) receive the dive index (0-255)
	btfsc	rs232_rx_timeout			; got dive index?
	bra		comm_command_timeout		; NO - abort, back to command loop

	call	log_header_addr_by_index	; compute header start address from index, result in mpr
	FLASH_RR_READ mpr,header_buffer,.256; copy the complete header into the buffer

	; get pointers and length of profile data
	MOVTT	header_buffer+index_profile_start_address,ext_flash_address
	MOVTT	header_buffer+index_profile_end_address,  ext_flash_end_pointer
	MOVTT	header_buffer+index_profile_byte_count,   ext_flash_length_counter

	; check if profile data are available
	movf	ext_flash_address+0,W		; compare low   byte of start and end pointer
	cpfseq	ext_flash_end_pointer+0		; equal?
	bra		comm_send_dive1				; NO - profile data available, continue

	movf	ext_flash_address+1,W		; compare high  byte of start and end pointer
	cpfseq	ext_flash_end_pointer+1		; equal?
	bra		comm_send_dive1				; NO - profile data available, continue

	movf	ext_flash_address+2,W		; compare upper byte of start and end pointer
	cpfseq	ext_flash_end_pointer+2		; equal?
	bra		comm_send_dive1				; NO - profile data available, continue

	bra		comm_command_loop			; start = end -> no profile data available, abort, back to command loop

comm_send_dive1:
	; send the header from the buffer
	SERIAL_RR_SEND_RAM header_buffer,.256

	; send the profile directly from the FLASH
	ext_flash_inc_address_0x20 .6		; skip the first 6 bytes (short header) of the profile data
	ext_flash_dec_length .3				; adopt the length count (short by 3 bytes)
	ext_flash_dec_length .1				; decrement length count by 1 so that all bytes will be
										; done when the counter has wrapped around to 0xFFFFFF
	movlw	0x20						; now the length count is allowed to be 0x1FFFFF at max
	cpfslt	ext_flash_length_counter+2	; length count < 0x20(0000) ?
	bra		comm_command_error			; NO - abort, back to command loop
	call	ext_flash_read_block_start	; YES - read first byte from FLASH into WREG
	bra		comm_send_dive_loop_start	;     - jump into transmit loop
comm_send_dive_loop:
	call	ext_flash_read_block_0x20	; read next byte into WREG
comm_send_dive_loop_start:
	SERIAL_CC_SEND WREG					; transmit byte
	ext_flash_dec_length .1				; decrement length counter
	btfss	ext_flash_length_counter+2,7; under-run?
	bra		comm_send_dive_loop			; NO  - continue loop
	call	ext_flash_read_block_stop	; YES - end reading from FLASH
	bra		comm_command_loop			;     - done, back to command loop


;-----------------------------------------------------------------------------
; Reset all Options to Factory Default
;
comm_option_reset_all:
	SERIAL_LC_SEND 0x78					; acknowledge command
	call	option_reset_all			; reset all options to factory default
	bra		comm_command_loop			; done, back to command loop


;-----------------------------------------------------------------------------
; Set Custom Text String (opt_name_length ASCII chars)
;
comm_set_custom_text:
	CLRR	opt_name,opt_name_length	; clear old custom text
	SERIAL_LC_SEND 0x63					; acknowledge command

	; receive new custom text (less than opt_name_length characters may be sent)
	SERIAL_RR_RECEIVE_RAM opt_name,opt_name_length

	bra		comm_command_loop			; done, back to command loop


;-----------------------------------------------------------------------------
; Reset Battery Gauge
;
comm_reset_battery_gauge:
;	SERIAL_LC_SEND 0x23						; acknowledge command (not done)
	call	reset_battery_gauge_and_lt2942	; reset battery registers and battery gauge chip
	bra		comm_command_loop				; done, back to command loop


;-----------------------------------------------------------------------------
; Erase complete Logbook
;
comm_erase_complete_logbook:
;	SERIAL_LC_SEND 0x22					; acknowledge command (not done)
	call	erase_complete_logbook		; erase complete logbook
	bra		comm_command_loop			; done, back to command loop


;-----------------------------------------------------------------------------
; Start Bootloader (aka perform cold start)
;
comm_cold_start:
;	SERIAL_LC_SEND 0xC1									; acknowledge command (not done)
;	call	rs232_wait_tx								; wait for completion of transmit before hardware goes into reboot

	WIN_SMALL comm_status3_column, comm_status3_row		; print "Low-level Bootloader" message
	STRCPY_TEXT_PRINT tUsbLlBld							; ...

	WIN_TOP  comm_warning_row							; set row    for icon
	WIN_LEFT comm_warning_column						; set column for icon
	TFT_WRITE_PROM_IMAGE_BY_LABEL dive_warning2_block	; show a warning icon

	bsf		LEDr										; switch on red LED

	call	eeprom_deco_data_write						; update deco data     in EEPROM
	call	eeprom_battery_gauge_write					; update battery gauge in EEPROM
	btfsc	options_changed								; do the options need to be stored to EEPROM ?
	call	option_check_and_store_all					; YES - check and store all option values in EEPROM

	goto	0x1FF0C										; jump into the bootloader code


;-----------------------------------------------------------------------------
; Send Firmware to Bootloader (aka initiate firmware update)
;
comm_firmware_update:
	SERIAL_LC_SEND 0x50					; acknowledge command

	SERIAL_RR_RECEIVE_RAM buffer,.5		; (try to) receive 5 byte checksum
	btfsc	rs232_rx_timeout			; got all 5 bytes?
	bra		comm_send_firmware_abort	; NO  - abort

	; check the checksum
	movlw	0x55						; initialize checksum check-byte
	movwf	hi							; store in hi
	lfsr	FSR2,buffer					; load base address of buffer
	movlw	.5							; 5 bytes to process
	movwf	lo							; initialize loop counter
comm_firmware_update_loop:
	movf	POSTINC2,W					; get a checksum byte
	xorwf	hi,F						; xor   checksum byte with check-byte
	rlncf	hi,F						; rotate check-byte
	decfsz	lo,F						; decrement loop counter, done?
	bra		comm_firmware_update_loop	; NO  - loop
	tstfsz	hi							; YES - check-byte zero?
	bra		comm_send_firmware_failed	;       NO  - checksum not valid

	; checksum is valid
	SERIAL_LC_SEND 0x4C					; inform checksum is ok
	call	rs232_wait_tx				; wait for completion of transmit before hardware goes into reboot

	call	eeprom_deco_data_write		; update deco data     in EEPROM
	call	eeprom_battery_gauge_write	; update battery gauge in EEPROM
	btfsc	options_changed				; do the options need to be stored to EEPROM ?
	call	option_check_and_store_all	; YES - check and store all option values in EEPROM

	goto	0x1FDF0						; jump into the bootloader code

comm_send_firmware_failed:
	; select font and output position
	WIN_SMALL comm_string_column, comm_string_row
	call	TFT_warning_color			; select color
	STRCPY_PRINT "Checksum failed"		; print failure message (fill to 15 chars)
	call	TFT_standard_color			; back to standard color
	;bra	comm_send_firmware_abort	; abort

comm_send_firmware_abort:
	SERIAL_LC_SEND 0xFF					; send abort message
	bra		comm_command_loop			; done, back to command loop


;-----------------------------------------------------------------------------
; Erase a Memory Range given byte Start Address and Number of 4 kB Blocks
;
comm_erase_range4kb:
	SERIAL_LC_SEND 0x42					; acknowledge command
	bcf		INTCON,GIE					; disable all interrupts
	rcall	comm_get_start_address		; (try to) get the start address
	btfsc	rs232_rx_timeout			; got start address?
	bra		comm_command_timeout		; NO  - abort, back to command loop

	; (try to) receive the block count (1 byte)
	SERIAL_CC_RECEIVE ext_flash_length_counter
	btfsc	rs232_rx_timeout			; got block count?
	bra		comm_command_timeout		; NO  - abort, back to command loop

	; erase blocks (number of blocks to do was received in ext_flash_length_counter:1)
comm_erase_range4kb_loop:
	call	ext_flash_erase_4kB			; erase a 4 kB block
										; increase start address by 0x1000 (4kB):
										; nothing to do with low byte
	movlw	0x10						; add 0x10...
	addwf	ext_flash_address+1,F		; ... to high byte
	movlw	0x00						; add 0x00...
	addwfc	ext_flash_address+2,F		; ... plus carry bit to upper byte
	btfsc	ext_flash_address+2,6		; reached 0x400000 ?
	bra		comm_command_loop			; YES - at end of address range, back to command loop
	decfsz	ext_flash_length_counter,F	; NO  - decrement number of blocks to do, all blocks done?
	bra		comm_erase_range4kb_loop	;       NO  - loop
	bra		comm_command_loop			;       YES - done, back to command loop


;-----------------------------------------------------------------------------
; Erase one Memory Block of 4 kB Size
;
comm_erase_4kb:
;	SERIAL_LC_SEND 0x40					; acknowledge command (not done)
	bcf		INTCON,GIE					; disable all interrupts
	rcall	comm_get_start_address		; (try to) get the start address
	btfsc	rs232_rx_timeout			; got a complete start address?
	bra		comm_command_timeout		; NO  - abort, back to command loop
	call	ext_flash_erase_4kB			; YES - erase memory block
	bra		comm_command_loop			;     - done, back to command loop


;-----------------------------------------------------------------------------
; Write a stream of bytes to the FLASH beginning at given start address, end on timeout
;
comm_write_range_stream:
	SERIAL_LC_SEND 0x30						; acknowledge command
	bcf		INTCON,GIE						; disable all interrupts
	rcall	comm_get_start_address			; (try to) get the start address
	btfsc	rs232_rx_timeout				; got a complete start address?
	bra		comm_command_timeout			; NO  - abort, back to command loop

	; steam bytes to FLASH
comm_write_range_loop:
	SERIAL_CC_RECEIVE WREG					; (try to) receive a byte
	btfsc	rs232_rx_timeout				; got a byte?
	bra		comm_command_loop				; NO  - end of byte stream, done, back to command loop
;	bsf		NCTS							; YES - hold    Bluetooth chip (requires PC/Android/iOS side to use flow control...)
	call	write_byte_ext_flash_plus_comms	;     - write data byte to FLASH and increase address with rollover at 0x400000
;	bcf		NCTS							;     - release Bluetooth chip (requires PC/Android/iOS side to use flow control...)
	bra		comm_write_range_loop			;     - loop


;-----------------------------------------------------------------------------
; Write a block of 256 bytes to the FLASH beginning at given start address (low byte needs to be zero)
;
comm_write_range_block:
	SERIAL_LC_SEND 0x31						; acknowledge command
	bcf		INTCON,GIE						; disable all interrupts

	rcall	comm_get_start_address			; (try to) get the start address
	btfsc	rs232_rx_timeout				; got a complete start address?
	bra		comm_command_timeout			; NO  - abort, back to command loop

	tstfsz	ext_flash_address+0				; low byte of address = 0 ?
	bra		comm_command_error				; NO  - abort, back to command loop

	SERIAL_RR_RECEIVE_RAM buffer,.256		; (try to) receive 256 byte and buffer them in memory
	btfsc	rs232_rx_timeout				; got all 256 bytes?
	bra		comm_command_timeout			; NO  - abort, back to command loop

	FLASH_RR_WRITE buffer,ext_flash_address,.256 ; copy from memory to FLASH
	bra		comm_command_loop					 ; done, back to command loop


;-----------------------------------------------------------------------------
; Read a range from FLASH given by start address and length
;
comm_read_range:
	SERIAL_LC_SEND 0x20					; acknowledge command
	bcf		INTCON,GIE					; disable all interrupts

	; receive start address
	rcall	comm_get_start_address		; (try to) get the start address
	btfsc	rs232_rx_timeout			; got a complete start address?
	bra		comm_command_timeout		; NO - abort, back to command loop

	; receive length
	rcall	comm_get_length				; (try to) get the length
	btfsc	rs232_rx_timeout			; got a complete length?
	bra		comm_command_timeout		; NO - abort, back to command loop

	; stream bytes from FLASH
	ext_flash_dec_length .1				; decrement length count by 1 so that all bytes will be
										; done when the counter has wrapped around to 0xFFFFFF

	movlw	0x40						; now the length count is allowed to be 0x3FFFFF at max
	cpfslt	ext_flash_length_counter+2	; length count < 0x40(0000) ?
	bra		comm_command_error			; NO  - abort, back to command loop
	call	ext_flash_read_block_start	; YES - read first byte from FLASH into WREG
	bra		comm_read_range_loop_start	;     - jump into transmit loop
comm_read_range_loop:
	call	ext_flash_read_block_0x40	; read next byte into WREG
comm_read_range_loop_start:
	SERIAL_CC_SEND WREG					; transmit byte
	ext_flash_dec_length .1				; decrement length counter
	btfss	ext_flash_length_counter+2,7; under-run?
	bra		comm_read_range_loop		; NO  - continue loop
	call	ext_flash_read_block_stop	; YES - end reading from FLASH
	bra		comm_command_loop			;     - done, back to command loop


;-----------------------------------------------------------------------------
; Receive a 3 byte FLASH address (on serial: big-endian, in memory: little-endian)
;
comm_get_start_address:
	SERIAL_RR_RECEIVE_RAM ext_flash_address,.3	; receive 3 bytes
	btfsc	rs232_rx_timeout					; timeout?
	return										; YES - abort, no usable address available

	; remap address from network byte format (big endian) to host format (little-endian)
	movf	ext_flash_address+0,W
	movff	ext_flash_address+2,ext_flash_address+0
	movwf	ext_flash_address+2

	return										; done, complete start address available


;-----------------------------------------------------------------------------
; Receive a 3 byte length (on serial: big-endian, in memory: little-endian)
;
comm_get_length:
	SERIAL_RR_RECEIVE_RAM ext_flash_length_counter,.3 	; receive 3 bytes
	btfsc	rs232_rx_timeout							; timeout?
	return												; YES - abort, no usable address available

	; remap address from network byte format (big endian) to host format (little-endian)
	movf	ext_flash_length_counter+0,W
	movff	ext_flash_length_counter+2,ext_flash_length_counter+0
	movwf	ext_flash_length_counter+2

	return												; done, complete start address available


;-----------------------------------------------------------------------------
; Read an Option Value
;
comm_read_option:
	SERIAL_LC_SEND 0x72					; acknowledge command
	SERIAL_CC_RECEIVE lo				; (try to) receive option index
	btfsc	rs232_rx_timeout			; received option index?
	bra		comm_command_loop			; NO - abort, back to command loop

	; option index 0x00 - 0x0F: unused
	movlw	0x0F						; last option index of the unused range
	cpfsgt	lo							; received option index > end of unused range ?
	bra		comm_command_error			; NO  - abort, back to command loop

	; option index 0x10 - 0x19: gases & diluents
	movlw	0x19						; last option index for gases / diluents
	cpfsgt	lo							; received option index > end of gas/dil range ?
	bra		comm_read_gas_dil			; NO  - process gas/dil read

	; option index 0x1A - 0x1E: setpoints
	movlw	0x1E						; last option index for setpoint
	cpfsgt	lo							; received option index > end of setpoint range ?
	bra		comm_read_sp				; NO  - process setpoint read

	; option index = 0x49 - special handling button polarity
	movf	lo,W						; copy option index to WREG
	iorlw	0x49						; received option index for button polarity ?
	bz		comm_read_button_polarity	; YES - process button polarity read

	; option index 0x1F - 0xFF: options managed by option-table
	call	option_read_serial			; try to find the option and read its value
	tstfsz	WREG						; option found?
	bra		comm_read_setting_fail		; NO  - send dummy value
	SERIAL_CC_SEND	hi					; YES - send read  value
	bra		comm_command_loop			;     - done, back to command loop

comm_read_setting_fail:
	SERIAL_LC_SEND	0x00				; send a dummy value
	bra		comm_command_error			; back to command loop with failure message


;-----------------------------------------------------------------------------
; Write an Option Value
;
comm_write_option:
	SERIAL_LC_SEND 0x77					; acknowledge command
	SERIAL_CC_RECEIVE lo				; (try to) receive option index
	btfsc	rs232_rx_timeout			; got a byte?
	bra		comm_command_timeout		; NO - abort, back to command loop

	; option index 0x00 - 0x0F: unused
	movlw	0x0F						; last option index of the unused range
	cpfsgt	lo							; received option index > end of unused range ?
	bra		comm_write_unused			; NO  - but need to consume the option value

	; option index 0x10 - 0x19: gases & diluents
	movlw	0x19						; last option index for gases / diluents
	cpfsgt	lo							; received option index > end of gas/dil range ?
	bra		comm_write_gas_dil			; NO  - process gas/dil write

	; option index 0x1A - 0x1E: setpoints
	movlw	0x1E						; last option index for setpoint
	cpfsgt	lo							; received option index > end of setpoint range ?
	bra		comm_write_sp				; NO  - process setpoint write

	; option index = 0x49 - special handling button polarity
	movf	lo,W						; copy option index to WREG
	iorlw	0x49						; received option index for button polarity ?
	bz		comm_write_button_polarity	; YES - process button polarity write

	; option index 0x1F - 0xFF: options managed by option-table
	SERIAL_CC_RECEIVE hi				; (try to) receive option value
	btfsc	rs232_rx_timeout			; got a byte?
	bra		comm_command_timeout		; NO  - abort
	call	option_write_serial			; YES - try to find the option and write new value
	tstfsz	WREG						;     - option found and new value valid ?
	bra		comm_command_error			;       NO  - back to command loop with failure message
	bra		comm_command_loop			;       YES - done, back to command loop

comm_write_unused:
	SERIAL_CC_RECEIVE WREG				; consume unused option value
	bra		comm_command_error			; done, back to command loop


;-----------------------------------------------------------------------------
; Read button polarity
;
comm_read_button_polarity:
	SERIAL_CC_SEND	button_polarity		; send current button polarity setting
	bra		comm_command_loop			; done, back to command loop


;-----------------------------------------------------------------------------
; Write button polarity
; 
comm_write_button_polarity:
	SERIAL_CC_RECEIVE hi				; (try to) receive configuration value
	btfsc	rs232_rx_timeout			; got configuration value?
	bra		comm_command_timeout		; NO  - abort, back to command loop
	movff	hi,button_polarity			; YES - store button polarity in memory and EEPROM
	EEPROM_CC_WRITE button_polarity,eeprom_button_polarity
	bra		comm_command_loop			;     - done, back to command loop


;-----------------------------------------------------------------------------
; Read a gas/diluent dataset
;
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
;
comm_read_gas_dil:
	lfsr	FSR0,opt_gas_O2_ratio		; load base address of gas data arrays
	movlw	0x10						; compute gas index from option index...
	subwf	lo,W						; ...making WREG          point to O2 ratio
	SERIAL_CC_SEND PLUSW0				; send O2 ratio
	addlw	.10							; increment WREG by 10 to point to He ratio
	SERIAL_CC_SEND PLUSW0				; send He ratio
	addlw	.10							; increment WREG by 10 to point to gas/diluent type
	SERIAL_CC_SEND PLUSW0				; send gas/diluent type
	addlw	.10							; increment WREG by 10 to point to change depth
	SERIAL_CC_SEND PLUSW0				; send change depth
	bra		comm_command_loop			; done, back to command loop


; ----------------------------------------------------------------------------
; Write a gas/diluent dataset
;
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
;
comm_write_gas_dil:
	SERIAL_RR_RECEIVE_RAM hi,.4			; (try to) receive 4 option values
	btfsc	rs232_rx_timeout			; got all 4 bytes?
	bra		comm_command_timeout		; NO - abort, back to command loop

	; check validity of O2 value
	movlw	gaslist_min_o2-.1			; get min value minus 1
	cpfsgt	hi							; received O2% >= min ?
	bra		comm_command_error			; NO - abort, back to command loop
	movlw	gaslist_max_o2+.1			; get max value plus 1
	cpfslt	hi							; received O2% <= max ?
	bra		comm_command_error			; NO - abort, back to command loop

	; check validity of He value
	movlw	gaslist_max_He+.1			; get max value plus 1
	cpfslt	up							; received O2% <= max ?
	bra		comm_command_error			; NO - abort, back to command loop

	; check O2% + He% <= 100%
	movlw	.100						; load 100%
	bsf		STATUS,C					; set carry = clear borrow
	subfwb	hi,W						; subtract O2% from 100%
	btfss	STATUS,C					; result negative?
	bra		comm_command_error			; YES - abort, back to command loop
	subfwb	up,W						; NO  - subtract He%
	btfss	STATUS,C					;     - now negative?
	bra		comm_command_error			;       YES - abort, back to command loop

	; check validity of type
	movlw	0x14						; last option index for gases
	cpfsgt	lo							; received option index > end of gas range ?
	bra		comm_write_dil				; YES - check type for diluents
	;bra	comm_write_gas				; NO  - check type for gases

comm_write_gas:
	; check validity of type for a gas
	movlw	num_gas_types				; load number of gas types
	bra		comm_write_gas_dil_common	; continue with common part

comm_write_dil:
	; check validity of type for a diluent
	movlw	num_dil_types				; load number of diluent types
	;bra	comm_write_gas_dil_common	; continue with common part

comm_write_gas_dil_common:
	cpfslt	ex							; received type < max ?
	bra		comm_command_error			; NO  - abort, back to command loop

	; check validity of change depth
	movlw	gaslist_max_change_depth+.1	; get max value plus 1
	cpfslt	ul							; received change depth <= max ?
	bra		comm_command_error			; NO - abort, back to command loop

	; all values ok, can finally be written
	lfsr	FSR0,opt_gas_O2_ratio		; load base address of gas data arrays
	movlw	0x10						; compute gas index from option index...
	subwf	lo,W						; ...making WREG          point to O2 ratio
	movff	hi,PLUSW0					; set O2 ratio
	addlw	.10							; increment WREG by 10 to point to He ratio
	movff	up,PLUSW0					; set He ratio
	addlw	.10							; increment WREG by 10 to point to gas/dil type
	movff	ex,PLUSW0					; set gas/dil type
	addlw	.10							; increment WREG by 10 to point to change depth
	movff	ul,PLUSW0					; set change depth

	bra		comm_command_loop			; done, back to command loop


;-----------------------------------------------------------------------------
; Read a setpoint dataset
;
; Memory map is as follows:
; -------------------------
; opt_setpoint_cbar			res 5	; setpoints in cbar
; opt_setpoint_change		res 5	; change depth for the setpoints in meter
;
comm_read_sp:
	lfsr	FSR0,opt_setpoint_cbar		; load base address of setpoint cbar values
	movlw	0x1A						; compute SP index from option index...
	subwf	lo,W						; ...making WREG         point to cbar value
	SERIAL_CC_SEND PLUSW0				; send setpoint cbar value
	addlw	.5							; increment WREG by 5 to point to change depth
	SERIAL_CC_SEND PLUSW0				; send change depth
	bra		comm_command_loop			; done, back to command loop


;-----------------------------------------------------------------------------
; Write a setpoint dataset
;
; Memory map is as follows:
; -------------------------
; opt_setpoint_cbar			res 5	; setpoints     in cbar
; opt_setpoint_change		res 5	; change depths in meter
;
comm_write_sp:
	SERIAL_RR_RECEIVE_RAM hi,.2			; (try to) receive 2 option values
	btfsc	rs232_rx_timeout			; got both bytes?
	bra		comm_command_timeout		; NO - abort, back to command loop

	; check validity of setpoint value
	movlw	gaslist_sp_min-.1			; get min value minus 1
	cpfsgt	hi							; received O2% >= min ?
	bra		comm_command_error			; NO - abort, back to command loop
	movlw	gaslist_sp_max+.1			; get max value plus 1
	cpfslt	hi							; received O2% <= max ?
	bra		comm_command_error			; NO - abort, back to command loop

	; check validity of change depth
	movlw	sp_max_change_depth+.1		; get max value plus 1
	cpfslt	up							; received change depth <= max ?
	bra		comm_command_error			; NO - abort, back to command loop

	lfsr	FSR0,opt_setpoint_cbar		; load base address of setpoint cbar values
	movlw	0x1A						; compute SP index from option index...
	subwf	lo,W						; ...making WREG         point to cbar value
	movff	hi,PLUSW0					; set cbar value
	addlw	.5							; increment WREG by 5 to point to change depth
	movff	up,PLUSW0					; set change depth

	bra		comm_command_loop			; done, back to command loop

;-----------------------------------------------------------------------------

	END