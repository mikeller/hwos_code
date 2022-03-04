;=============================================================================
;
;   File eeprom_rs232.asm                   * combined next generation V3.09.4n
;
;   Internal EEPROM, RS232
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;  2011-08-06 : [mH] moving from OSTC code

#include "hwos.inc"
#include "wait.inc"
#include "shared_definitions.h"
#include "rtc.inc"
#include "external_flash.inc"

#DEFINE INSIDE_EEPROM_RS232
#include "eeprom_rs232.inc"


	extern	lt2942_charge_done


;=============================================================================
eeprom	CODE
;=============================================================================

;-----------------------------------------------------------------------------
;
; EEPROM Functions - for EEPROM Macros and Memory Map, see eeprom_rs232.inc
;
;-----------------------------------------------------------------------------


;-----------------------------------------------------------------------------
; Read from internal EEPROM
;
; Input:   EEADRH:EEADR = EEPROM address
; Output:  EEDATA
; Trashed: NONE
;
	global	read_eeprom
read_eeprom:
	bcf		EECON1,EEPGD					; access data EEPROM
	bcf		EECON1,CFGS						; ...
	bsf		EECON1,RD						; initiate reading
	return									; done


;-----------------------------------------------------------------------------
; Write into internal EEPROM
;
; Input:   EEADRH:EEADR = EEPROM address
;          EEDATA = byte to write
; Trashed: WREG
;
	global	write_eeprom
write_eeprom:
	bcf		EECON1,EEPGD					; access data EEPROM
	bcf		EECON1,CFGS						; ...
	bsf		EECON1,WREN						; enable writing
	bcf		INTCON,GIE						; disable interrupts
	movlw	0x55							; unlock sequence
	movwf	EECON2							; ...
	movlw	0xAA							; ...
	movwf	EECON2							; ...
	bsf		EECON1,WR						; start write operation
write_eeprom_loop:
	btfsc	EECON1,WR						; write completed?
	bra		write_eeprom_loop				; NO  - loop waiting
	bcf		EECON1,WREN						; YES - disable writing
	bsf		INTCON,GIE						;     - re-enable interrupts 
	return									;     - done


;-----------------------------------------------------------------------------
; EEPROM read and write Functions to be used via Macros
;
	global	eeprom_read_common
eeprom_read_common:
	movwf	eeprom_loop						; initialize loop counter
eeprom_read_common_loop:
	rcall	read_eeprom						; execute read
	movff	EEDATA,POSTINC1					; copy byte  from EEPROM data register to memory
	incf	EEADR,F							; advance to next EEPROM cell
	decfsz	eeprom_loop,F					; decrement loop counter, all done?
	bra		eeprom_read_common_loop			; NO  - loop
	return									; YES - done

	global	eeprom_write_common
eeprom_write_common:
	movwf	eeprom_loop						; initialize loop counter
eeprom_write_common_loop:
	movff	POSTINC1,EEDATA					; copy byte from memory to EEPROM data register
	rcall	write_eeprom					; execute write
	incf	EEADR,F							; advance to next EEPROM cell
	decfsz	eeprom_loop,F					; decrement loop counter, all done?
	bra		eeprom_write_common_loop		; NO  - loop
	return									; YES - done


;-----------------------------------------------------------------------------
; Read OSTC Serial Number
;
	global	eeprom_serial_number_read
eeprom_serial_number_read:
	EEPROM_II_READ eeprom_ostc_serial,mpr	; read serial number
	return									; done


;-----------------------------------------------------------------------------
; Read and Write Dive Number Offset
;
	global	eeprom_log_offset_read
eeprom_log_offset_read:
	EEPROM_II_READ	eeprom_log_offset,mpr	; read log offset
	return									; done

	global	eeprom_log_offset_write
eeprom_log_offset_write:
	EEPROM_II_WRITE mpr,eeprom_log_offset	; write log-offset
	return									; done


;-----------------------------------------------------------------------------
; Read and Write total Number of Dives
;
	global	eeprom_total_dives_read
eeprom_total_dives_read:
	EEPROM_II_READ	eeprom_num_dives,mpr	; read total dives
	return									; done

	global	eeprom_total_dives_write
eeprom_total_dives_write:
	EEPROM_II_WRITE mpr,eeprom_num_dives	; write total dives
	return									; done


;-----------------------------------------------------------------------------
; Read and Write the Battery Type and Gauge Reading
;
	global	eeprom_battery_gauge_read
eeprom_battery_gauge_read:
	; retrieve battery gauge from EEPROM 0x07-0x0C
	bsf		block_battery_gauge								; suspend ISR from accessing the battery gauge
	EEPROM_CC_READ eeprom_battery_type, battery_type		; 1 byte read from EEPROM
	EEPROM_RR_READ eeprom_battery_gauge,battery_gauge,.6	; 6 byte read from EEPROM
	bcf		block_battery_gauge								; allow ISR to access the battery gauge again
	return													; done

	global	eeprom_battery_gauge_write
eeprom_battery_gauge_write:
	bsf		block_battery_gauge								; suspend ISR from accessing the battery gauge
	EEPROM_CC_WRITE battery_type, eeprom_battery_type		; 1 byte write to EEPROM
update_battery_gauge:
	EEPROM_RR_WRITE battery_gauge,eeprom_battery_gauge,.6	; 6 byte write to EEPROM
	bcf		block_battery_gauge								; allow ISR to access the battery gauge again
	return													; done


;-----------------------------------------------------------------------------
; Memorize the Checksum of the Firmware in the update Storage
;
	global	eeprom_memorize_fw_checksum
eeprom_memorize_fw_checksum:
	EXT_FLASH_ADDR 0x3E000D									; address firmware ID at 0x3E000D
	FLASH_CW_READ_0x40										; read    firmware ID to WREG
	movff	WREG,buffer+.5									; append  firmware ID to checksum
	EEPROM_RR_WRITE buffer,eeprom_fw_chksum_current,.6		; do a  6 byte write  to EEPROM
	return													; done


;-----------------------------------------------------------------------------
; Read and Write the Deco Status
;
	global	eeprom_deco_data_read
eeprom_deco_data_read:

	btfsc	RCON,POR												; was there a power outage?
	bra		eeprom_deco_data_read_1									; NO  - RTC is up-to-date

	EEPROM_RR_READ eeprom_deco_data_timestamp,rtc_latched_year,.6	;   6 byte read from EEPROM
	call	rtc_set_rtc												;     recover RTC to last known time & date

eeprom_deco_data_read_1:

	; restore surface interval
	EEPROM_II_READ eeprom_deco_data_surfinterval,mpr				;   2 byte read from EEPROM
	SMOVII	mpr,surface_interval_mins								;     ISR-safe copy of surface interval

	; bank 3: restore desaturation status
	EEPROM_RR_READ eeprom_deco_data_bank3,0x300,.9					;   9 byte read from EEPROM

	; bank 5: restore CNS
	EEPROM_RR_READ eeprom_deco_data_bank5,0x500,.4					;   4 byte read from EEPROM

	; bank 7: restore tissue pressures
	EEPROM_RR_READ eeprom_deco_data_bank7,0x700,.128				; 128 byte read from EEPROM

	return															;   done


	global	eeprom_deco_data_write
eeprom_deco_data_write:

	; invalidate current data in vault
	movlw	DECO_DATA_INVALID_TOKEN									;     deco data invalid token
	EEPROM_CC_WRITE WREG,eeprom_deco_data_validity					;   1 byte write to EEPROM

	; store vault version
	movlw	eeprom_vault_version									;     deco data format version
	EEPROM_CC_WRITE WREG,eeprom_deco_data_version					;   1 byte write to EEPROM

	; store date/time
	SMOVSS	rtc_year,rtc_latched_year								;     ISR-safe 6 byte copy of date and time
	EEPROM_RR_WRITE rtc_latched_year,eeprom_deco_data_timestamp,.6	;   6 byte write to EEPROM

	; store surface interval
	SMOVII	surface_interval_mins,mpr								;     ISR-safe copy of surface interval
	EEPROM_II_WRITE mpr,eeprom_deco_data_surfinterval				;   2 byte write to EEPROM

	; bank 3: store desaturation status
	EEPROM_RR_WRITE 0x300,eeprom_deco_data_bank3,.9					;   9 byte write to EEPROM

	; bank 5: store CNS
	EEPROM_RR_WRITE 0x500,eeprom_deco_data_bank5,.4					;   4 byte write to EEPROM

	; bank 7: store tissue pressures
	EEPROM_RR_WRITE 0x700,eeprom_deco_data_bank7,.128				; 128 byte write to EEPROM

	; indicate new valid data in vault
	movlw	DECO_DATA_VALID_TOKEN									;     deco data valid token
	EEPROM_CC_WRITE WREG,eeprom_deco_data_validity					;   1 byte write to EEPROM

	return															;   done


;=============================================================================
rs232	CODE
;=============================================================================

;-----------------------------------------------------------------------------
;
; RS232 Functions
;
;-----------------------------------------------------------------------------


;-----------------------------------------------------------------------------
; Switch-On the IR/S8 Port
;
	global	enable_ir_s8_analog
enable_ir_s8_analog:
	;initialize serial port2 (TRISG2)
	btfsc	ext_input_s8_ana			; do we have an S8/analog input?
	bra		enable_s8_analog			; YES - enable S8/analog  input
	;bra	enable_ir					; NO  - enable IR digital input

enable_ir:
	banksel	BAUDCON2					; select bank for IO register access
	movlw	b'00100000'					; speed generator configuration: BRG16=0, inverted for IR
	movwf	BAUDCON2					; ...
	movlw	b'00100000'					; TX configuration: BRGH=0, SYNC=0
	movwf	TXSTA2						; ...
	movlw	.102						; speed configuration: SPBRGH:SPBRG = .102 : 2403 BAUD @ 16 MHz
	movwf	SPBRG2						; ...
	clrf	SPBRGH2						; ...
	movlw	b'10010000'					; RX configuration
	movwf	RCSTA2						; ...
	banksel	common						; back to bank common
	bsf		ir_power					; power-up IR
	btfss	ir_power					; power-up confirmed?
	bra		$-6							; NO - loop and wait
	bsf		PIE3,RC2IE					; enable RC2 INT
	return								; done

enable_s8_analog:
	banksel	TXSTA2						; select bank for IO register access
	clrf	TXSTA2						; reset UART 2 TX function
	clrf	RCSTA2						; reset UART 2 RX function
	banksel	common						; back to bank common

	bsf		mcp_power					; power-up instrumentation amp (used by S8 and analog input)
	btfss	mcp_power					; power-up completed?
	bra		$-4							; NO - loop

	; branch according to S8 / analog selection
	TSTOSS	opt_s8_mode					; =0: analog, =1: digital RS232
	bra		enable_analog				; -> analog

	; configure S8 digital interface
	bcf		s8_npower					; power S8 HUD (inverted via P-MOS transistor)
	WAITMS	d'30'						; NO  - wait 30 ms
	banksel	BAUDCON2					; select bank for IO register access
	movlw	b'00000000'					; speed generator configuration: BRG16=0, normal for S8
	movwf	BAUDCON2					; ...
	movlw	b'00100000'					; TX configuration: BRGH=0, SYNC=0
	movwf	TXSTA2						; ...
	movlw	.25							; speed configuration: SPBRGH:SPBRG = .25 : 9615 BAUD @ 16 MHz
	movwf	SPBRG2						; ...
	movlw	b'10010000'					; RX configuration
	movwf	RCSTA2						; ...
	banksel	common						; back to bank common
	bsf		PIE3,RC2IE					; enable RC2 INT
	return

enable_analog:
	; S8 analog interface
	bcf		PIE3,RC2IE					; disable RC2 INT
	bsf		s8_npower					; power-down S8 digital interface
	return								; done


;-----------------------------------------------------------------------------
; Shut-Down the IR/S8 Port
;
	global	disable_ir_s8_analog
disable_ir_s8_analog:
	banksel	TXSTA2						; select bank for IO register access
	clrf	TXSTA2						; shut down TX function
	clrf	RCSTA2						; shut down RX function
	banksel	common						; back to bank common
	bcf		PIE3,RC2IE					; disable RC2 INT
	bcf		ir_power					; power down IR receiver
	bcf		mcp_power					; power-down instrumentation amp
	bsf		s8_npower					; power-down S8 digital interface
	return								; done


;-----------------------------------------------------------------------------
; Send Byte in WREG via the IR/S8 Port
;
	global	ir_s8_tx_single
ir_s8_tx_single:
	banksel	TXSTA2						; UART 2 is outside of the access RAM
	movwf	TXREG2						; transmit byte
ir_s8_tx_single_loop:
	btfss	TXSTA2,TRMT					; TX completed?
	bra		ir_s8_tx_single_loop		; NO  - wait...
	banksel	common						; YES - back to bank common
	return								;     - done


;-----------------------------------------------------------------------------
; Switch-On USB/BT Port
;
	global	enable_rs232
enable_rs232:
	call	request_speed_normal		; request CPU speed change to normal speed
enable_rs232_1:
	btfss	speed_is_normal				; speed = normal?
	bra		enable_rs232_1				; NO  - loop waiting for ISR to have adjusted the speed
	bsf	TRISC,7
	bcf		PORTE,0						; YES - switch port to comm
	bsf		PORTJ,2						;     - /Reset (required for very old OSTC sport)
	movlw	b'00100100'					;     - TX configuration: TX enabled, async, high speed
	movwf	TXSTA1						;     - ...
	movlw	b'10010000'					;     - RX configuration: port enabled, RX enabled
	movwf	RCSTA1						;     - ...
 IFNDEF _comm_debug
	movlw	HIGH(.65536-rx_timeout*.32)	;     - define TMR5H initialization value for RX timeout (rx_timeout defined in hwos.inc)
 ELSE
	include	"math.inc"
	movff	opt_comm_timeout,xA+0		;     - get timeout setting in multiples of 10 ms (opt_comm_timeout: 10 .. 200 x 10 ms)
	clrf	xA+1						;     - ...
	MOVLI	.320,xB						;     - multiply with 10 to get timeout in ms and 32 because tmr5 ticks 32x per ms
	call	mult16x16					;     - xC = xA * xB = timer ticks to go until timeout
	MOVII	xC,sub_b					;     - multiplication result is max. 64000
	MOVLI	.65535,sub_a				;     - timer wraps around after 65535
	call	subU16						;     - sub_c = sub_a - sub_b = start value for timer

	movlw	.244						; safety maximum value for rx_timeout_tmr5h_load (minimum timeout interval)
	cpfslt	sub_c+1						; result > safety value?
	movwf	sub_c+1						; YES - revert to safety value

	movf	sub_c+1,W					;     - keep only the upper byte as TMR5H initialization value for RX timeout
 ENDIF
	movwf	rx_timeout_tmr5h_load		;     - store for later use
	return								;     - done


;-----------------------------------------------------------------------------
; Shut-Down USB/BT Port
;
	global	disable_rs232
disable_rs232:
	clrf	RCSTA1						; disable RX
	clrf	TXSTA1						; disable TX
	bcf		PORTC,6						; switch TX pin hard to GND
	bsf		PORTE,0						; power down BT chip
	bcf		PORTJ,2						; /Reset (required for very old OSTC sport)
	bcf	TRISC,7
	bcf		PORTC,7						; switch RX pin hard to GND
	return


;-----------------------------------------------------------------------------
; Wait for last Byte to be sent out of USB/BT Port
;
	global	rs232_wait_tx				; ++++ do not touch WREG here! ++++
rs232_wait_tx:
	btfss	TXSTA1,TRMT					; last byte completely shifted out on TX pin?
	bra		rs232_wait_tx				; NO  - wait...
	btfss	ble_available				; YES - OSTC running with Bluetooth?
	return								;       NO  - done
	btfsc	NRTS						;       YES - Bluetooth module also completed TX?
	bra		rs232_wait_tx				;             NO  - wait...
	return								;             YES - done


;-----------------------------------------------------------------------------
; Receive one Byte via the USB/BT Port
;
; ++++ make this code as fast as possible! ++++
; ++++       do not touch WREG here!       ++++
;
	global	serial_rx_single
serial_rx_single:
	bcf		rs232_rx_timeout			; clear timeout flag
	btfsc	PIR1,RCIF					; received a data byte? (bit is set on RX completion and reset on reading RCREG1)
	return								; YES - done (fast path)
	movff	rx_timeout_tmr5h_load,TMR5H	; NO  - load TMR5 high with timeout value
	clrf	TMR5L						;     - load TMR5 low  with a zero, writing low starts the timer
	bcf		PIR5,TMR5IF					;     - clear timer overflow flag
serial_rx_single_loop:
	btfsc	PIR1,RCIF					; received a data byte?
	return								; YES - done
	btfss	PIR5,TMR5IF					; NO  - timer overflow (timeout)?
	bra		serial_rx_single_loop		;       NO  - continue waiting
	;bra	serial_rx_timeout			;       YES - timeout


;-----------------------------------------------------------------------------
; Helper Function: Timeout in serial_rx_single / serial_tx_steam
;
serial_rx_timeout:
	bsf		rs232_rx_timeout			; set timeout flag
	bcf		RCSTA1,CREN					; clear receiver status: disable RX,
	bsf		RCSTA1,CREN					;               ... enable again RX
	return								; done


;-----------------------------------------------------------------------------
; Send and Receive Functions to be used via Macros
;-----------------------------------------------------------------------------

;-----------------------------------------------------------------------------
; Send a Range of 1-256 Bytes from Memory via the USB/BT Port
;
	global	serial_tx_steam
serial_tx_steam:
	movwf	eeprom_loop					; initialize loop counter (eeprom variable used here)
serial_tx_ram_loop:
	rcall	rs232_wait_tx				; wait for completion of last transmit
	movff	POSTINC2,TXREG1				; send a byte from memory to serial
	decfsz	eeprom_loop,F				; decrement loop counter, became zero?
	bra		serial_tx_ram_loop			; NO  - loop
	return								; YES - done


;-----------------------------------------------------------------------------
; Receive a Range of 1-256 Byte via the USB/BT Port and write them to Memory
; ++++ make this code as fast as possible! ++++
;
	global	serial_rx_stream
serial_rx_stream:
	movwf	eeprom_loop					; initialize loop counter (eeprom variable used here)
serial_rx_stream_loop:
	btfss	PIR1,RCIF					; received a data byte? (bit is set on RX complete and reset on reading RCREG1)
	bra		serial_rx_stream_tmr		; NO  - enter receive loop with timeout
	;bra	serial_rx_stream_received	; YES - copy to memory, tick counter, ...

serial_rx_stream_received:
	movff	RCREG1,POSTINC2				; copy received byte to memory
	decfsz	eeprom_loop,F				; decrement loop counter, became zero?
	bra		serial_rx_stream_loop		; NO  - await next byte
	bcf		rs232_rx_timeout			; YES - clear timeout flag
	return								;     - all bytes received, done

serial_rx_stream_tmr:
	movff	rx_timeout_tmr5h_load,TMR5H	; load TMR5 high with timeout value
	clrf	TMR5L						; load TMR5 low  with a zero, writing to low starts the timer
	bcf		PIR5,TMR5IF					; clear timer overflow flag
serial_rx_stream_tmr_loop:
	btfsc	PIR1,RCIF					; received a data byte? (bit is set on RX complete and reset on reading RCREG1)
	bra		serial_rx_stream_received	; YES - copy to memory, tick counter, ...
	btfss	PIR5,TMR5IF					; NO  - timer overflow (timeout)?
	bra		serial_rx_stream_tmr_loop	;       NO  - continue waiting
	bra		serial_rx_timeout			;       YES - timeout

;-----------------------------------------------------------------------------

;-----------------------------------------------------------------------------
; Add new services and characteristics to new BLE (type 2) module
;-----------------------------------------------------------------------------
    global  ble2_configure
ble2_configure:
    rcall    enable_rs232
    bcf         NCTS            ; Clear to send
    call	wait_1s
    call	wait_1s
    bcf	PORTB,6
    bsf	PORTB,6			; rising edge -> Command mode
    
    ; point to config table
    movlw   LOW     ble_AT1
    movwf   TBLPTRL
    movlw   HIGH    ble_AT1
    movwf   TBLPTRH
    movlw   UPPER   ble_AT1
    movwf   TBLPTRU
    rcall   ble_init_loop
	
    rcall   disable_rs232
    bcf	    PORTB,6	    ; keep low for min. current consumption
    return		    ; done.

ble_init_loop:
        TBLRD*+
        movlw   0xFF	; end
        cpfseq  TABLAT
        bra     ble_init_loop1	; not end
        ; quit (return)
	return	; done.
ble_init_loop1:
        movlw   0xFE	; WAIT 20ms
        cpfseq  TABLAT
        bra     ble_init_loop2	; not wait 20ms
	WAITMS      d'20'
	bra	ble_init_loop
ble_init_loop2:	
        movlw   0xFD	; WAIT 1s
        cpfseq  TABLAT
        bra     ble_init_loop3	; not wait 1s
	call    wait_1s
	bra	ble_init_loop
ble_init_loop3:
	movf	TABLAT,W
	SERIAL_CC_SEND	WREG
	bra	ble_init_loop
    
ble_AT1:	; config table
    ; 0xFF at the end
    ; 0xFE: 20ms delay
    ; 0xFD: 1s delay
    ; .13: cr character
    db	0xFD,0xFD						; Wait 2 seconds
    db	"AT+UDSC=0,0",.13,0xFE,0xFE				; Disable SPP Server on ID0 (and wait 40ms)
    db	"AT+UDSC=0,3",.13,0xFE,0xFE				; SPP Server on ID0 (and wait 40ms)
    db	"AT+UDSC=1,0",.13,0xFE,0xFE				; Disable SPS Server on ID1 (and wait 40ms)
    db	"AT+UDSC=1,6",.13,0xFE,0xFE				; SPS Server on ID1 (and wait 40ms)
    db	"AT&W",.13,0xFE						; write settings into eeprom (and wait 20ms)
    db	"AT+CPWROFF",.13,0xFD,0xFD,0xFF				; save and reboot  (and wait 2 seconds)

	
	END
