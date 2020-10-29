;=============================================================================
;
;   File comm.asm                           * combined next generation V3.10.0
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
#include "colorschemes.inc"


	extern	restart
	extern	option_reset_all
	extern	option_check_and_store_all
	extern	option_read_serial
	extern	option_write_serial
	extern	gaslist_cleanup_list
	extern	eeprom_deco_data_write
	extern	eeprom_memorize_fw_checksum


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
#DEFINE	comm_status5_row		.190
#DEFINE	comm_status5_column		comm_status1_column


; positioning of COMM mode warning icon
#DEFINE comm_warning_row		.160
#DEFINE comm_warning_column		.65


;#DEFINE	testloop_avail				; uncomment if testloop code is available

;=============================================================================
comm	CODE
;=============================================================================

;-----------------------------------------------------------------------------
; Entry Point for Comm Mode / USB
;
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


;-----------------------------------------------------------------------------
; Entry Point for Comm Mode / BT
;
	global	comm_mode_bt
comm_mode_bt:										; entry point for comm mode via BT
	bcf		aux_flag								; remember to show BLE title
	;bra	comm_mode_common						; continue with common part


;-----------------------------------------------------------------------------
; Common Part of Comm Mode Entry
;
comm_mode_common:
	clrf	STKPTR									; reset addresses stack
	call	TFT_ClearScreen							; clear screen
	FONT_COLOR color_greenish						; set color

	btfss	aux_flag								; shall show USB title?
	bra		comm_mode_common_bt						; NO  - show BT  title
	;bra	comm_mode_common_usb					; YES - show USB title

comm_mode_common_usb:
	WIN_SMALL comm_title_column_usb, comm_title_row	; set   USB title position
	STRCPY_TEXT_PRINT tUsbTitle						; print USB title text
	bra		comm_mode_common_logo					; continue with logo

comm_mode_common_bt:
	WIN_SMALL comm_title_column_ble, comm_title_row	; set   BT title position
	STRCPY_TEXT_PRINT tBleTitle						; print BT title text
	;bra	comm_mode_common_logo					; continue with logo

comm_mode_common_logo:
	WIN_TOP  .10									; set position of USB/BLE logo, row
	WIN_LEFT .1										; set position of USB/BLE logo, column
	btfss	battery_gauge_available					; "+" bootloader ?
	bra		comm_mode_common_logo2					; YES - show logo type 2
	;bra	comm_mode_common_logo1					; NO  - show logo type 1

comm_mode_common_logo1:
	TFT_WRITE_PROM_IMAGE_BY_ADDR comm_logo_1		; show USB/BT logo
	bra		comm_mode_common_start					; continue with starting message

comm_mode_common_logo2:
	TFT_WRITE_PROM_IMAGE_BY_ADDR comm_logo_2		; show BT logo / OSTC+
	;bra	comm_mode_common_start					; continue with starting message

comm_mode_common_start:
	WIN_SMALL comm_status1_column,comm_status1_row	; set position
	FONT_COLOR_MEMO									; set standard color
	STRCPY_TEXT_PRINT tUsbStarting					; print status message "starting..."

	WIN_TINY .40,.240-.16							; set output position to bottom line
	call	TFT_print_serial_and_firmware			; show serial number and firmware version

 IFDEF _screendump
	bcf		screen_dump_avail						; disable screen dump function
 ENDIF

	bcf		switch_right							; clear potential left-over right button event
	call	enable_rs232							; enable serial comm, also sets CPU to normal speed

	WIN_SMALL comm_status1_column+.80,comm_status1_row	; set position after starting message
	FONT_COLOR_MEMO										; set standard color
	STRCPY_TEXT_PRINT tUsbStartDone						; print (adding to status message) "done..."

	movlw	timeout_comm_pre_mode					; get timeout for phase without communication established yet
	movwf	comm_timeout_timer						; initialize timeout counter
	;bra	comm_mode_selection_loop				; continue with mode selection loop


;-----------------------------------------------------------------------------
; Mode Selection Loop: Download Mode or Service Mode
;
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
	bz		comm_download_mode						;             YES - enter command loop
	;bra	comm_mode_selection_loop_2				;             NO  - check for comm mode termination
comm_mode_selection_loop_2:
	btfsc	ble_available							; BT available?
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
; Check Service Mode Pass-Key and notify Service Mode on Success
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
	FONT_COLOR_MEMO									;     - set standard color
	STRCPY_TEXT_PRINT tUsbServiceMode				;     - ...
	bsf		comm_service_mode						;     - enable service mode commands
	bra		comm_command_loop						;     - enter command loop


;-----------------------------------------------------------------------------
; Notify RX Timeout occurred
;
comm_command_timeout:
	WIN_SMALL comm_status4_column, comm_status4_row	; select font and output position
	FONT_COLOR_WARNING								; set warning color
	STRCPY_PRINT "Data Rx Timeout"					; print failure message
	FONT_COLOR_MEMO									; back to standard color
	bra		comm_drain_rx_queue						; continue with draining the RX queue


;-----------------------------------------------------------------------------
; Notify Error in Parameters
;
comm_command_error:
	WIN_SMALL comm_status4_column, comm_status4_row	; select font and output position
	FONT_COLOR_WARNING								; set warning color
	STRCPY_PRINT "Unknown Parameter"					; print failure message
	FONT_COLOR_MEMO									; back to standard color
	bra	comm_service_exit							; abort
	;bra	comm_drain_rx_queue						; continue with draining the RX queue


;-----------------------------------------------------------------------------
; Drain the RX Queue until next Timeout
;
comm_drain_rx_queue:
	bsf		INTCON,GIE								; re-enable all interrupts
comm_drain_rx_queue_loop:
	btfsc	switch_right							; right button (abort) pressed?
	bra		comm_service_exit						; YES - exit comm mode
	SERIAL_CC_RECEIVE WREG							; NO  - (try to) receive one byte
	btfss	rs232_rx_timeout						;     - got a byte?
	bra		comm_drain_rx_queue_loop				;       YES - try to drain more bytes
	bra		comm_command_loop						;       NO  - re-enter command loop


;-----------------------------------------------------------------------------
; Debug Code - show Number of Bytes received
;
 IFDEF _comm_debug
comm_command_debug:
	WIN_SMALL comm_status5_column, comm_status5_row	; select font and output position
	FONT_COLOR_MEMO									; set standard color
	STRCPY	"last RX: "								; print label
	output_9999										; print number of bytes received (0-9999)
	STRCAT_PRINT " Byte"							; finalize output
	bra		comm_command_loop						; re-enter command loop
 ENDIF


;-----------------------------------------------------------------------------
; Notify Download Mode selected
;
comm_download_mode:
	SERIAL_LC_SEND 0xBB								; inform peer download mode will be started

	WIN_SMALL comm_status2_column, comm_status2_row	; set position
	FONT_COLOR_MEMO									; set standard color
	STRCPY_TEXT_PRINT tUsbDownloadMode				; print download mode enabled message
	bcf		comm_service_mode						; disable service mode commands
	;bra	comm_command_loop						; enter command loop


;-----------------------------------------------------------------------------
; Command Loop: await, decode and execute Commands
;
comm_command_loop:
	bsf		INTCON,GIE								; re-enable all interrupts

	; restart command timeout
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
	btfsc	ble_available							;     - BT available?
	bra		comm_command_loop_wait_1				;       YES - skip USB check (required for very old OSTC sport)
	btfss	vusb_in									;       NO  - USB still plugged in?
	bra		comm_service_exit_nousb					;             NO  - disconnected -> exit comm mode
	;bra	comm_command_loop_wait_1				;             YES - proceed

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
; Macro for easier writing of Command Decoding Rules
;
command_decode  macro  command_id,command_function
	movf	lo,W									; copy received command to WREG
	xorlw	command_id								; exclusive-or with  command ID
	btfsc	STATUS,Z								; received command = command ID ?
	goto	command_function						; YES - execute command
	endm


;-----------------------------------------------------------------------------
; Decode and execute a Command
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
	command_decode 0x6C,TFT_dump_screen_comm		; l  dump the screen contents
 ENDIF

	btfss	comm_service_mode						; service mode enabled?
	bra		comm_command_loop						; NO - ignore unrecognized command, back to command loop

	; decode and execute additional service mode commands
	command_decode 0x23,comm_reset_battery_gauge	; #  reset the battery gauge registers
	command_decode 0x22,comm_erase_complete_logbook	; "  reset all logbook pointers and the logbook
	command_decode 0x20,comm_read_range				;' ' read a memory range from the external FLASH
	command_decode 0x40,comm_erase_single_4kb		; @  erase a single   4 kB block  - Warning: no confirmation or built-in safety here...
	command_decode 0x42,comm_erase_range_4kb		; B  erase a range of 4 kB blocks - Warning: no confirmation or built-in safety here...
	command_decode 0x30,comm_write_range_stream		; 0  write a stream of     bytes starting at ext_flash_address:3 until timeout
	command_decode 0x31,comm_write_range_block		; 1  write a block  of 256 bytes starting at ext_flash_address:3
	command_decode 0x50,comm_firmware_update		; P  initiate firmware update
	command_decode 0xC1,comm_cold_start				;    start low-level bootloader
 IFDEF testloop_avail
	command_decode 0x74,testloop					; t  start raw-data test loop
 ENDIF

	bra		comm_command_loop						; ignore unrecognized command, back to command loop


;-----------------------------------------------------------------------------
; Screendump
;
 IFDEF _screendump
TFT_dump_screen_comm:
	call	TFT_dump_screen							; dump the screen contents and set screen_dump_avail
	;bra	comm_service_exit						; exit comm mode
 ENDIF


;-----------------------------------------------------------------------------
; Exit Comm Mode
;
comm_service_exit:
	WIN_SMALL comm_status3_column, comm_status3_row	; print "Exited" message
	FONT_COLOR_MEMO									; set standard color
	STRCPY_TEXT_PRINT	tUsbExit					; ...
	bra		comm_service_exit_common				; acknowledge exit command and restart

comm_service_exit_nousb_delay:
	WAITMS	d'200'									; wait 200 ms
	btfsc	vusb_in									; USB sensed again?
	bra		comm_mode_selection_loop_3				; YES - was just a glitch, continue
	;bra	comm_service_exit_nousb					; NO  - proceed exiting

comm_service_exit_nousb:
	WIN_SMALL comm_status3_column, comm_status3_row	; print "Port closed" message
	FONT_COLOR_MEMO									; set standard color
	STRCPY_TEXT_PRINT tUsbClosed					; ...
	;bra	comm_service_exit_common				; proceed exiting

comm_service_exit_common:
	SERIAL_LC_SEND 0xFF								; acknowledge exit command
	WAITS	.1										; wait 1 second to give the serial I/F time
													; to send the 0xFF before it gets shut down
	call	disable_rs232							; shut down comm port
	bcf		LEDr									; switch off red LED
	WAITS	.1										; wait 1 second for BT module supply to drain
	goto	restart									; restart


;-----------------------------------------------------------------------------
; Set Real-Time-Clock
;
comm_set_time:
	bcf		INTCON,GIE					; disable all interrupts
	SERIAL_LC_SEND 0x62					; acknowledge command
	SERIAL_RR_RECEIVE mpr,.6			; (try to) receive 6 bytes: hour, minute, second, month, day, year
	bsf		INTCON,GIE					; re-enable all interrupts

	btfsc	rs232_rx_timeout			; got all 6 bytes?
	bra		comm_command_timeout		; NO  - show rx timeout message and back to command loop

	movff	mpr+0,rtc_latched_hour		; map the received bytes onto the rtc_latched variables
	movff	mpr+1,rtc_latched_mins		; ...
	movff	mpr+2,rtc_latched_secs		; ...
	movff	mpr+3,rtc_latched_month		; ...
	movff	mpr+4,rtc_latched_day		; ...
	movff	mpr+5,rtc_latched_year		; ...
	call	rtc_set_rtc					; write time and date to RTC module
	bra		comm_command_loop			; done, back to command loop


;-----------------------------------------------------------------------------
; Write a 15 char Text to the OSTC Display
;
comm_show_text:
	; set font and output position (needs to be done before SERIAL_RR_RECEIVE)
	WIN_SMALL comm_string_column, comm_string_row
	FONT_COLOR_MEMO						; set standard color

	bcf		INTCON,GIE					; disable all interrupts
	SERIAL_LC_SEND 0x6E					; acknowledge command
	SERIAL_RR_RECEIVE buffer,.16		; (try to) receive 16 chars into the string buffer
	bsf		INTCON,GIE					; re-enable all interrupts

	movlw	.15							; set maximum text length
	call	TFT_buffer_trim_length		; fill or trim the text to correct length
	PRINT								; print text to screen
	bra		comm_command_loop			; done, back to command loop


;-----------------------------------------------------------------------------
; Send Serial (2 bytes low:high), Firmware (major.minor) and Custom Text
;
comm_identify:
	SERIAL_LC_SEND 0x69					; acknowledge command

	; send OSTC serial number
	call	eeprom_serial_number_read	; read OSTC serial number
	SERIAL_CC_SEND mpr+0				; send serial number, low  byte
	SERIAL_CC_SEND mpr+1				; send serial number, high byte

	; send firmware version
	SERIAL_LC_SEND fw_version_major		; send firmware version, major
	SERIAL_LC_SEND fw_version_minor		; send firmware version, minor

	; send custom text
	SERIAL_RR_SEND	opt_name,opt_name_length

	bra		comm_command_loop			; done, back to command loop


;-----------------------------------------------------------------------------
; Send short Hardware Descriptor
;
comm_hardware_descriptor:
	SERIAL_LC_SEND 0x6A					; acknowledge command
	rcall	comm_helper_hw_descriptor	; send hardware descriptor
	bra		comm_command_loop			; done, back to command loop


;-----------------------------------------------------------------------------
; Helper Function for sending Hardware Descriptor
;
comm_helper_hw_descriptor:
	movf	HW_descriptor,W				; get hardware descriptor
	bcf		WREG,6						; clear bit 6 for reason of compatibility with 3rd party software
	bcf		WREG,7						; clear bit 7 for reason of compatibility with 3rd party software
	SERIAL_CC_SEND WREG					; send modified hardware descriptor
	return


;-----------------------------------------------------------------------------
; Send detailed Hardware Descriptor
;
comm_feature_and_hardware:
	SERIAL_LC_SEND 0x60					; acknowledge command

	SERIAL_LC_SEND 0x00					; send hardware high byte    (fixed zero)
	rcall	comm_helper_hw_descriptor	; send hardware descriptor
	SERIAL_LC_SEND 0x00					; send feature high byte     (fixed zero)
	SERIAL_LC_SEND 0x00					; send feature low  byte     (fixed zero)
	SERIAL_LC_SEND 0x00					; send model descriptor byte (fixed zero)

	bra		comm_command_loop			; done, back to command loop


;-----------------------------------------------------------------------------
; Helper Function to retrieve a Header, hide the internal Profile Version,
;                 and to check if the Header is empty
;
comm_helper_read_header:
	; copy header from FLASH into memory
	call	log_header_addr_by_index					; compute header start address from index in WREG
	FLASH_RR_READ header_buffer,.256					; copy from FLASH to header buffer

	; hide internal profile version ID from the outside
	movff	header_buffer+index_profile_version,WREG	; get byte at the profile version position
	infsnz	WREG,W										; was the byte = 0xFF (i.e. empty header) ?
	return												; YES - leave it as it is (WREG now 0)
	decf	WREG,W										; NO  - restore the profile version
	andlw	b'00111111'									;     - keep only the external part
	movff	WREG,header_buffer+index_profile_version	;     - write back the cleaned byte
	return												;     - done (WREG now ext. profile version)


;-----------------------------------------------------------------------------
; Send Dive Headers in short or full Format
;
comm_send_headers_short:
	SERIAL_LC_SEND 0x6D					; acknowledge command
	bcf		aux_flag					; send short headers
	bra		comm_send_headers_common	; continue with common part

comm_send_headers_full:
	SERIAL_LC_SEND 0x61					; acknowledge command
	bsf		aux_flag					; send full  headers
	;bra	comm_send_headers_common	; continue with common part

comm_send_headers_common:
	clrf	ex							; start with dive having index 0

comm_send_headers_loop:
	movf	ex,W						; get index  into WREG
	rcall	comm_helper_read_header		; get header into header_buffer

	btfss	aux_flag					; shall send full  headers?
	bra		comm_send_headers_loop_short; NO  - send short headers
	;bra	comm_send_headers_loop_full	; YES - send full  headers

comm_send_headers_loop_full:
	SERIAL_RR_SEND header_buffer,.256	; send the full header
	bra		comm_send_headers_loop_com	; continue with common part

comm_send_headers_loop_short:
	; send the fractions of the short header (16 byte/dive)
	SERIAL_RR_SEND header_buffer+index_profile_byte_count,.13
	SERIAL_RR_SEND header_buffer+index_total_dives,        .2
	SERIAL_CC_SEND header_buffer+index_profile_version   ; .1
	;bra	comm_send_headers_loop_com	; continue with common part

comm_send_headers_loop_com:
	incfsz	ex							; increment index, wrap-around. i.e. all dives done ?
	bra		comm_send_headers_loop		; NO  - loop
	bra		comm_command_loop			; YES - done, back to command loop


;-----------------------------------------------------------------------------
; Send one full Dive
;
comm_send_dive:
	SERIAL_LC_SEND 0x66					; acknowledge command

	SERIAL_CC_RECEIVE WREG				; (try to) receive the dive index
	btfsc	rs232_rx_timeout			; got dive index?
	bra		comm_command_timeout		; NO - show rx timeout message and back to command loop

	rcall	comm_helper_read_header		; read header into header_buffer
	bz		comm_send_dive_exit			; abort if header contains no dive

	; get the start and end address of the profile data
	MOVTT	header_buffer+index_profile_start_address,ext_flash_address
	MOVTT	header_buffer+index_profile_end_address,  ext_flash_end_pointer

	; header start code sequence present?
	bcf		aux_flag					; default to no profile available

	FLASH_CW_READ_0x20					; get the 1st byte of profile data
	xorlw	0xFA						; 1st byte = header start byte?
	bnz		comm_send_dive_modify_header; NO  - no profile data available

	FLASH_CW_READ_0x20					; get the 2nd byte of profile data
	xorlw	0xFA						; 2nd byte = header start byte?
	bnz		comm_send_dive_modify_header; NO  - no profile data available

	EXT_FLASH_INC_ADDRESS_0x20 .2		; skip the 3rd and 4th byte (dive number)

	FLASH_CW_READ_0x20					; get the 5th byte of profile data
	xorlw	0xFA						; 5th byte = header start byte?
	bnz		comm_send_dive_modify_header; NO  - no profile data available

	FLASH_CW_READ_0x20					; get the 6th byte of profile data
	xorlw	0xFA						; 6th byte = header start byte?
	bnz		comm_send_dive_modify_header; NO  - no profile data available

	bsf		aux_flag					; memorize profile data available
	bra		comm_send_dive_header		; continue with sending header 

comm_send_dive_modify_header:
	; set profile data start and end address to 0x000000
	CLRR	header_buffer+index_profile_start_address,.6

	; set hi = 0x00, lo = 0x08
	MOVLI	0x0008,mpr

	; set byte count to 0x000008
	movff	lo,header_buffer+index_profile_byte_count+0		; = 0x08
	movff	hi,header_buffer+index_profile_byte_count+1		; = 0x00
	movff	hi,header_buffer+index_profile_byte_count+2		; = 0x00

comm_send_dive_header:
	SERIAL_RR_SEND header_buffer,.256	; send the header from the buffer

	btfss	aux_flag					; profile data available?
	bra		comm_send_dive_empty_profile; NO - send empty profile

comm_send_dive_profile:
	FLASH_CW_READ_0x20					; read one byte and increment address with rollover at 0x200000
	SERIAL_CC_SEND WREG					; transmit the byte

	; 24 bit compare of current address with end address
	movf	ext_flash_end_pointer+0,W	; check low   byte of addresses
	cpfseq	ext_flash_address+0			; current address = end address ?
	bra		comm_send_dive_profile		; NO  - more bytes to do, loop

	movf	ext_flash_end_pointer+1,W	; check high  byte of addresses
	cpfseq	ext_flash_address+1			; current address = end address ?
	bra		comm_send_dive_profile		; NO  - more bytes to do, loop

	movf	ext_flash_end_pointer+2,W	; check upper byte of addresses
	cpfseq	ext_flash_address+2			; current address = end address ?
	bra		comm_send_dive_profile		; NO  - more bytes to do, loop

comm_send_dive_exit:
	bra		comm_command_loop			; done, back to command loop

comm_send_dive_empty_profile:

	; send profile length
	SERIAL_RR_SEND header_buffer+index_profile_byte_count,.3

	SERIAL_LC_SEND 0xFD					; send end-of-profile sequence, byte 1
	SERIAL_LC_SEND 0xFD					; send end-of-profile sequence, byte 2

	bra		comm_command_loop			; done, back to command loop


;-----------------------------------------------------------------------------
; Reset all Options to Factory Default
;
comm_option_reset_all:
	SERIAL_LC_SEND 0x78					; acknowledge command
	call	option_reset_all			; reset all options to factory default
	bra		comm_command_loop			; done, back to command loop


;-----------------------------------------------------------------------------
; Set Custom Text (opt_name_length ASCII chars)
;
comm_set_custom_text:
	CLRR	opt_name,opt_name_length			; clear old custom text

	bcf		INTCON,GIE							; disable all interrupts
	SERIAL_LC_SEND 0x63							; acknowledge command
	SERIAL_RR_RECEIVE opt_name,opt_name_length	; receive new custom text
	bsf		INTCON,GIE							; re-enable all interrupts
	bsf		option_changed						; flag that EEPROM needs to be updated

	bra		comm_command_loop					; done, back to command loop


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
;	SERIAL_LC_SEND 0x22						; acknowledge command (not done)
	call	erase_complete_logbook			; erase complete logbook
	bra		comm_command_loop				; done, back to command loop


;-----------------------------------------------------------------------------
; Start Bootloader (aka perform cold start)
;
comm_cold_start:
;	SERIAL_LC_SEND 0xC1									; acknowledge command (not done)

	WIN_SMALL comm_status3_column, comm_status3_row		; set position
	FONT_COLOR_MEMO										; set standard color
	STRCPY_TEXT_PRINT tUsbLlBld							; print "Low-level Bootloader" message

	WIN_TOP  comm_warning_row							; set row    for icon
	WIN_LEFT comm_warning_column						; set column for icon
	TFT_WRITE_PROM_IMAGE_BY_LABEL dive_warning2_block	; show a warning icon

	bsf		LEDr										; switch on red LED

	call	eeprom_deco_data_write						; update deco data     in EEPROM
	call	eeprom_battery_gauge_write					; update battery gauge in EEPROM
	btfsc	option_changed								; do the options need to be stored to EEPROM ?
	call	option_check_and_store_all					; YES - check and store all option values in EEPROM

;	WAITS	.1											; wait 1 second to give the serial I/F time
;														; to send the ackn before it gets shut down

	goto	0x1FF0C										; jump into the bootloader code for cold start


;-----------------------------------------------------------------------------
; Send Firmware to Bootloader (aka initiate Firmware Update)
;
comm_firmware_update:
	bcf		INTCON,GIE					; disable all interrupts
	SERIAL_LC_SEND 0x50					; acknowledge command
	SERIAL_RR_RECEIVE buffer,.5			; (try to) receive 5 byte checksum
	bsf		INTCON,GIE					; re-enable all interrupts

	btfsc	rs232_rx_timeout			; got all 5 bytes?
	bra		comm_send_firmware_abort	; NO  - abort

	; check the checksum
	movlw	0x55						; initialize checksum check-byte
	movwf	hi							; store in hi
	INIT_BUFFER							; go back to start of the buffer
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
	WAITS	.1							; wait 1 second to give the serial I/F time
										; to send the 0x4C before it gets shut down
	;bra	comm_firmware_update_exec	; execute update

	global	comm_firmware_update_exec
comm_firmware_update_exec:
	call	eeprom_memorize_fw_checksum	; memorize fw checksum in EEPROM
	call	eeprom_deco_data_write		; update deco data     in EEPROM
	call	eeprom_battery_gauge_write	; update battery gauge in EEPROM
	btfsc	option_changed				; do the options need to be stored to EEPROM ?
	call	option_check_and_store_all	; YES - check and store all option values in EEPROM
	goto	0x1FDF0						; jump into the bootloader code for firmware update


comm_send_firmware_failed:
	; select font and output position
	WIN_SMALL comm_string_column, comm_string_row
	FONT_COLOR_WARNING					; set warning color
	STRCPY_PRINT "Checksum failed"		; print failure message (fill to 15 chars)
	;bra	comm_send_firmware_abort	; abort

comm_send_firmware_abort:
	SERIAL_LC_SEND 0xFF					; send checksum failure message
	bra		comm_command_loop			; done, back to command loop


;-----------------------------------------------------------------------------
; Erase a single Block or a Range of Blocks
;
comm_erase_single_4kb:
	bcf		INTCON,GIE					; disable all interrupts
	bcf		aux_flag					; do a single block only
;	SERIAL_LC_SEND 0x40					; acknowledge command (not done)
	bra		comm_erase_get_start		; continue with getting start address

comm_erase_range_4kb:
	bcf		INTCON,GIE					; disable all interrupts
	bsf		aux_flag					; do a range of blocks
	SERIAL_LC_SEND 0x42					; acknowledge command
	;bra	comm_erase_get_start		; continue with getting start address

comm_erase_get_start:
	rcall	comm_get_start_address		; (try to) get the start address
	btfsc	rs232_rx_timeout			; got start address?
	bra		comm_command_timeout		; NO  - show rx timeout message and back to command loop
	btfsc	aux_flag					; YES - shall erase a range of blocks?
	bra		comm_erase_get_count		;       YES - get the block count
	movlw	.1							;       NO  - set   1 block to do
	movwf	WREG						;           - ...
	bra		comm_erase_common			;           - start the erasing

comm_erase_get_count:
	SERIAL_CC_RECEIVE WREG				; (try to) receive the block count
	btfsc	rs232_rx_timeout			; got block count?
	bra		comm_command_timeout		; NO  - show rx timeout message and back to command loop
	tstfsz	WREG						; YES - block count = 0 ?
	bra		comm_erase_common			;       NO  - start the erasing
	bra		comm_command_error			;       YES - invalid, show error message and back to command loop

comm_erase_common:
	bsf		INTCON,GIE					; re-enable all interrupts
	call	ext_flash_erase_range		; erase #WREG 4kB blocks starting at ext_flash_address
	bra		comm_command_loop			; done, back to command loop


;-----------------------------------------------------------------------------
; Write a Stream of Bytes to the FLASH beginning at given Start Address, finish on Timeout
;
comm_write_range_stream:
	bcf		INTCON,GIE						; disable all interrupts
	SERIAL_LC_SEND 0x30						; acknowledge command

	rcall	comm_get_start_address			; (try to) get the start address
	btfsc	rs232_rx_timeout				; got a complete start address?
	bra		comm_command_timeout			; NO  - show rx timeout message and back to command loop

 IFDEF _comm_debug
	CLRI	mpr								; clear mpr to be used as a 16 bit counter
 ENDIF

comm_write_range_stream_loop:
	SERIAL_CC_RECEIVE WREG					; (try to) receive one byte
	btfsc	rs232_rx_timeout				; got a byte?
 IFNDEF _comm_debug
	bra		comm_command_loop				; NO  - timeout, done, back to command loop
 ELSE
	bra		comm_command_debug				; NO  - timeout, done, show number of bytes received
 ENDIF
;	bsf		NCTS							; YES - hold    Bluetooth chip (requires PC/Android/iOS side to use flow control...)
	call	ext_flash_write_byte_0x40_nowait;     - write byte to FLASH, increase address with rollover at 0x400000, does not wait on FLASH
;	bcf		NCTS							;     - release Bluetooth chip (requires PC/Android/iOS side to use flow control...)
 IFDEF _comm_debug
	INCI	mpr								; increment counter
 ENDIF
	bra		comm_write_range_stream_loop	;     - loop


;-----------------------------------------------------------------------------
; Write a Block of 256 Bytes to the FLASH beginning at given Start Address (low byte needs to be zero)
;
comm_write_range_block:
	bcf		INTCON,GIE					; disable all interrupts
	SERIAL_LC_SEND 0x31					; acknowledge command

	rcall	comm_get_start_address		; (try to) get the start address
	btfsc	rs232_rx_timeout			; got a complete start address?
	bra		comm_command_timeout		; NO  - show rx timeout message and back to command loop

	tstfsz	ext_flash_address+0			; low byte of start address = 0 ?
	bra		comm_command_error			; NO  - show error message and back to command loop

	SERIAL_RR_RECEIVE buffer,.256		; (try to) receive 256 byte and buffer them in memory
	bsf		INTCON,GIE					; re-enable all interrupts
	btfsc	rs232_rx_timeout			; got all 256 bytes?
	bra		comm_command_timeout		; NO  - show rx timeout message and back to command loop

	FLASH_RR_WRITE buffer,.256 			; copy from memory to FLASH
	bra		comm_command_loop			; done, back to command loop


;-----------------------------------------------------------------------------
; Read a Memory Range from FLASH given by Start Address and Byte Count
;
comm_read_range:
	bcf		INTCON,GIE					; disable all interrupts
	SERIAL_LC_SEND 0x20					; acknowledge command

	; receive start address
	rcall	comm_get_start_address		; (try to) get the start address
	btfsc	rs232_rx_timeout			; got a complete start address?
	bra		comm_command_timeout		; NO - show rx timeout message and back to command loop

	; receive byte count
	rcall	comm_get_length				; (try to) get the byte count
	btfsc	rs232_rx_timeout			; got a complete byte count?
	bra		comm_command_timeout		; NO - show rx timeout message and back to command loop

	bsf		INTCON,GIE					; re-enable all interrupts

	; decrement byte counter by 1 so that all bytes will be done when the counter wraps around to 0xFFFFFF
	EXT_FLASH_DEC_LENGTH

	; check validity of the byte count
	movlw	0x40						; now the byte count is allowed to be 0x3FFFFF at max
	cpfslt	ext_flash_length_counter+2	; length count < 0x40(0000) ?
	bra		comm_command_error			; NO  - show error message and back to command loop

	; stream bytes from FLASH
	call	ext_flash_read_block_start	; read first byte from FLASH into WREG
	bra		comm_read_range_loop_start	; jump into transmit loop
comm_read_range_loop:
	call	ext_flash_read_block_0x40	; read next byte into WREG
comm_read_range_loop_start:
	SERIAL_CC_SEND WREG					; transmit byte
	EXT_FLASH_DEC_LENGTH				; decrement byte counter
	btfss	ext_flash_length_counter+2,7; under-run?
	bra		comm_read_range_loop		; NO  - continue loop
	call	ext_flash_read_block_stop	; YES - end reading from FLASH
	bra		comm_command_loop			;     - done, back to command loop


;-----------------------------------------------------------------------------
; Receive a 3 byte FLASH address (on serial: big-endian, in memory: little-endian)
;
comm_get_start_address:
	SERIAL_RR_RECEIVE ext_flash_address,.3	; (try to) receive 3 bytes
	btfsc	rs232_rx_timeout				; timeout?
	return									; YES - abort, no usable address available

	; remap address from network byte format (big endian) to host format (little-endian)
	movf	ext_flash_address+0,W
	movff	ext_flash_address+2,ext_flash_address+0
	movwf	ext_flash_address+2

	return									; done, complete start address available


;-----------------------------------------------------------------------------
; Receive a 3 byte length (on serial: big-endian, in memory: little-endian)
;
comm_get_length:
	SERIAL_RR_RECEIVE ext_flash_length_counter,.3 	; receive 3 bytes
	btfsc	rs232_rx_timeout						; timeout?
	return											; YES - abort, no usable address available

	; remap address from network byte format (big endian) to host format (little-endian)
	movf	ext_flash_length_counter+0,W
	movff	ext_flash_length_counter+2,ext_flash_length_counter+0
	movwf	ext_flash_length_counter+2

	return											; done, complete start address available


;-----------------------------------------------------------------------------
; Read an Option Value
;
comm_read_option:
	SERIAL_LC_SEND 0x72					; acknowledge command
	SERIAL_CC_RECEIVE lo				; (try to) receive option index
	btfsc	rs232_rx_timeout			; received option index?
	bra		comm_command_loop			; NO - show rx timeout message and back to command loop

	; option index 0x00 - 0x0F: unused
	movlw	0x0F						; last option index of the unused range
	cpfsgt	lo							; received option index > end of unused range ?
	bra		comm_command_error			; NO  - show error message and back to command loop

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

	; option index 0x1F - 0xF9: options managed by option table
	movlw	0xF9						; last option index for options
	cpfsgt	lo							; received option index > end of options range?
	bra		comm_read_option_index		; YES - process option value read via index

	bra		comm_command_error			; NO  - illegal option index


;-----------------------------------------------------------------------------
; Write an Option Value
;
comm_write_option:
	bcf		INTCON,GIE					; disable all interrupts
	SERIAL_LC_SEND 0x77					; acknowledge command
	SERIAL_CC_RECEIVE lo				; (try to) receive option index
	btfsc	rs232_rx_timeout			; got a byte?
	bra		comm_command_timeout		; NO - show rx timeout message and back to command loop

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

	; option index 0x1F - 0xF9: options managed by option table
	movlw	0xF9						; last option index for options
	cpfsgt	lo							; received option index > end of options range?
	bra		comm_write_option_index		; YES - process option value write via index

	bra		comm_write_unused			; NO  - illegal option index


;-----------------------------------------------------------------------------
; Read an Option Value via its Serial Index
;
comm_read_option_index:
	call	option_read_serial			; try to find the option and read its value
	tstfsz	WREG						; option found?
	bra		comm_read_setting_fail		; NO  - send dummy value
	SERIAL_CC_SEND	hi					; YES - send read  value
	bra		comm_command_loop			;     - done, back to command loop

comm_read_setting_fail:
	SERIAL_LC_SEND	0x00				; send a dummy value
	bra		comm_command_error			; back to command loop with failure message


;-----------------------------------------------------------------------------
; Write an Option Value via its Serial Index
;
comm_write_option_index:
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
; Read Button Polarity
;
comm_read_button_polarity:
	SERIAL_CC_SEND	button_polarity		; send current button polarity setting
	bra		comm_command_loop			; done, back to command loop


;-----------------------------------------------------------------------------
; Write Button Polarity
; 
comm_write_button_polarity:
	SERIAL_CC_RECEIVE hi				; (try to) receive configuration value
	btfsc	rs232_rx_timeout			; got configuration value?
	bra		comm_command_timeout		; NO  - show rx timeout message and back to command loop
	movff	hi,button_polarity			; YES - store button polarity in memory and EEPROM
	EEPROM_CC_WRITE button_polarity,eeprom_button_polarity
	bra		comm_command_loop			;     - done, back to command loop


;-----------------------------------------------------------------------------
; Read a Gas/Diluent Dataset
;
; memory map is as follows:
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
; Write a Gas/Diluent Dataset
;
; memory map is as follows:
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
	SERIAL_RR_RECEIVE hi,.4				; (try to) receive 4 option values
	btfsc	rs232_rx_timeout			; got all 4 bytes?
	bra		comm_command_timeout		; NO - show rx timeout message and back to command loop

	; check validity of O2 value
	movlw	gaslist_min_o2-.1			; get min value minus 1
	cpfsgt	hi							; received O2% >= min ?
	bra		comm_command_error			; NO - show error message and back to command loop
	movlw	gaslist_max_o2+.1			; get max value plus 1
	cpfslt	hi							; received O2% <= max ?
	bra		comm_command_error			; NO - show error message and back to command loop

	; check validity of He value
	movlw	gaslist_max_He+.1			; get max value plus 1
	cpfslt	up							; received O2% <= max ?
	bra		comm_command_error			; NO - show error message and back to command loop

 IFDEF _helium
	; check O2% + He% <= 100%
	movlw	.100						; load WREG with 100%
	bsf		STATUS,C					; set carry = clear borrow
	subfwb	hi,W						; subtract O2% from WREG
	subfwb	up,W						; subtract He% from WREG
	btfss	STATUS,C					; result negative?
	bra		comm_command_error			; YES - show error message and back to command loop
 ENDIF	; _helium

	; check validity of type
	movlw	0x14						; last option index for gases
	cpfsgt	lo							; received option index > end of gas range ?
	bra		comm_write_check_gas		; NO  - check type for gases
	;bra	comm_write_check_dil		; YES - check type for diluents

comm_write_check_dil:
	; check validity of type for a diluent
	movlw	num_dil_types				; load number of diluent types
	bra		comm_write_check_com		; continue with common part

comm_write_check_gas:
	; check validity of type for a gas
	movlw	num_gas_types				; load number of gas types
	;bra	comm_write_check_com		; continue with common part

comm_write_check_com:
	cpfslt	ex							; received type < max ?
	bra		comm_command_error			; NO  - show error message and back to command loop

	; check validity of change depth
	movlw	gaslist_max_change_depth+.1	; get max value plus 1
	cpfslt	ul							; received change depth <= max ?
	bra		comm_command_error			; NO - show error message and back to command loop

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

	bsf		option_changed				; flag that EEPROM needs to be updated
	bra		comm_command_loop			; done, back to command loop


;-----------------------------------------------------------------------------
; Read a Setpoint Dataset
;
; memory map is as follows:
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
; Write a Setpoint Dataset
;
; memory map is as follows:
; -------------------------
; opt_setpoint_cbar			res 5	; setpoints     in cbar
; opt_setpoint_change		res 5	; change depths in meter
;
comm_write_sp:
	SERIAL_RR_RECEIVE hi,.2				; (try to) receive 2 option values
	btfsc	rs232_rx_timeout			; got both bytes?
	bra		comm_command_timeout		; NO - show rx timeout message and back to command loop

	; check validity of setpoint value
	movlw	gaslist_sp_min-.1			; get min value minus 1
	cpfsgt	hi							; received O2% >= min ?
	bra		comm_command_error			; NO - show error message and back to command loop
	movlw	gaslist_sp_max+.1			; get max value plus 1
	cpfslt	hi							; received O2% <= max ?
	bra		comm_command_error			; NO - show error message and back to command loop

	; check validity of change depth
	movlw	gaslist_sp_max_depth+.1		; get max value plus 1
	cpfslt	up							; received change depth <= max ?
	bra		comm_command_error			; NO - show error message and back to command loop

	lfsr	FSR0,opt_setpoint_cbar		; load base address of setpoint cbar values
	movlw	0x1A						; compute SP index from option index...
	subwf	lo,W						; ...making WREG         point to cbar value

	bnz		comm_write_sp_exec			; selected SP is 2...5 -> execute write
	tstfsz	up							; SP1: change depth = 0 ?
	bra		comm_command_error			; NO - show error message and back to command loop

comm_write_sp_exec:
	movff	hi,PLUSW0					; set cbar value
	addlw	.5							; increment WREG by 5 to point to change depth
	movff	up,PLUSW0					; set change depth

	bsf		option_changed				; flag that EEPROM needs to be updated
	bra		comm_command_loop			; done, back to command loop

;-----------------------------------------------------------------------------

	END