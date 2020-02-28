;=============================================================================
;
;   File eeprom_rs232.asm                     combined next generation V3.08.8
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

;-----------------------------------------------------------------------------
;
;			for EEPROM Macros and Memory Map, see eeprom_rs232.inc
;
;-----------------------------------------------------------------------------

ee_rs232	CODE

;=============================================================================
;   EEPROM Functions
;=============================================================================

;-----------------------------------------------------------------------------
; read from internal EEPROM
;
; Input:   EEADRH:EEADR = EEPROM address
; Output:  EEDATA
; Trashed: NONE
;
	global	read_eeprom
read_eeprom:
	bcf		EECON1,EEPGD					;
	bcf		EECON1,CFGS						;
	bsf		EECON1,RD						;
	return

;-----------------------------------------------------------------------------
; write into internal EEPROM
;
; Input:   EEADRH:EEADR = EEPROM address
;          EEDATA = byte to write
; Trashed: WREG
;
	global	write_eeprom
write_eeprom:
	bcf		EECON1,EEPGD					;
	bcf		EECON1,CFGS						;
	bsf		EECON1,WREN						;
	bcf		INTCON,GIE						; disable interrupts for the next 5 instructions
	movlw	0x55							; unlock sequence
	movwf	EECON2							; ...
	movlw	0xAA							; ...
	movwf	EECON2							; ...
	bsf		EECON1,WR						; start write operation
write_eeprom_loop:
	btfsc	EECON1,WR						; write completed?
	bra		write_eeprom_loop				; NO - loop waiting
	bcf		EECON1,WREN						;
	bsf		INTCON,GIE						; ...but the flag for the ISR routines were still set, so they will interrupt now!
	return

;-----------------------------------------------------------------------------
; these 2 functions are meant to be used through the macros, see eeprom_rs232!
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
; REad OSTC serial number
;
	global	eeprom_serial_number_read
eeprom_serial_number_read:
	EEPROM_II_READ eeprom_ostc_serial,mpr
	return

;-----------------------------------------------------------------------------
; Read and write dive number offset
;
	global	eeprom_log_offset_read
eeprom_log_offset_read:
	EEPROM_II_READ	eeprom_log_offset,mpr
	return

	global	eeprom_log_offset_write
eeprom_log_offset_write:
	EEPROM_II_WRITE mpr,eeprom_log_offset
	return


;-----------------------------------------------------------------------------
; Read and write total number of dives
;
	global	eeprom_total_dives_read
eeprom_total_dives_read:
	EEPROM_II_READ	eeprom_num_dives,mpr
	return

	global	eeprom_total_dives_write
eeprom_total_dives_write:
	EEPROM_II_WRITE mpr,eeprom_num_dives
	return


;-----------------------------------------------------------------------------
; Read and write the battery gauge and type
;
	global	eeprom_battery_gauge_read
eeprom_battery_gauge_read:
	; retrieve battery gauge from EEPROM 0x07-0x0C
	bsf		block_battery_gauge								; suspend ISR from accessing the battery gauge
	EEPROM_CC_READ eeprom_battery_type, battery_type		; 1 byte read from EEPROM
	EEPROM_RR_READ eeprom_battery_gauge,battery_gauge,.6	; 6 byte read from EEPROM
	bcf		block_battery_gauge								; allow ISR to access the battery gauge again
	return

	global	eeprom_battery_gauge_write
eeprom_battery_gauge_write:
	bsf		block_battery_gauge								; suspend ISR from accessing the battery gauge
	EEPROM_CC_WRITE battery_type, eeprom_battery_type		; 1 byte write to EEPROM
update_battery_gauge:
	EEPROM_RR_WRITE battery_gauge,eeprom_battery_gauge,.6	; 6 byte write to EEPROM
	bcf		block_battery_gauge								; allow ISR to access the battery gauge again
	return


;-----------------------------------------------------------------------------
; Read and write the deco status
;
	global	eeprom_deco_data_read
eeprom_deco_data_read:

	btfsc	RCON,POR												; was there a power outage ?
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
;   RS232 Functions
;=============================================================================

	global	disable_ir_s8
disable_ir_s8:
	banksel	TXSTA2						; select bank for IO register access
	clrf	TXSTA2
	clrf	RCSTA2
	banksel	common						; back to bank common
	bcf		PIE3,RC2IE					; disable RC2 INT
	bcf		ir_power					; IR off
	bcf		mcp_power					; power-down instrumentation amp
	bsf		s8_npower					; power-down S8 digital interface
	bcf		s8_digital_avail			; digital S8 interface not available
	return


	global	enable_ir_s8
enable_ir_s8:
	;initialize serial port2 (TRISG2)
	btfsc	analog_o2_input				; do we have an analog input?
	bra		enable_s8					; YES - search for S8 digital input
										; NO  - start      IR digital input
	banksel	BAUDCON2					;     - select bank for IO register access
	movlw	b'00100000'					;     - BRG16=0, inverted for IR
	movwf	BAUDCON2
	movlw	b'00100000'					;     - BRGH=0, SYNC=0
	movwf	TXSTA2
	movlw	.102						;     - SPBRGH:SPBRG = .102 : 2403 BAUD @ 16 MHz
	movwf	SPBRG2
	clrf	SPBRGH2
	movlw	b'10010000'
	movwf	RCSTA2
	banksel	common						;     - back to bank common
	bsf		ir_power					;     - power-up IR
	btfss	ir_power					;     - power-up confirmed?
	bra		$-6							;       NO - loop and wait
	bsf		PIE3,RC2IE					;     - enable RC2 INT
	return								;     - done

enable_s8:
	banksel	TXSTA2						; select bank for IO register access
	clrf	TXSTA2						; reset UART 2 TX function
	clrf	RCSTA2						; reset UART 2 RX function
	banksel	common						; back to bank common

	bsf		mcp_power					; power-up instrumentation amp (for analog AND digital)
	btfss	mcp_power					; power-up completed?
	bra		$-4							; NO - loop

	; toggle for digital/analog
	TSTOSS	opt_s8_mode					; =0: analog, =1: digital RS232
	bra		enable_s8_analog			; -> analog

	; configure S8 digital interface
	bcf		s8_npower					; power S8 HUD (inverted via P-MOS transistor)
	WAITMS	d'30'						; NO  - wait 30 ms
	banksel	BAUDCON2					; select bank for IO register access
	movlw	b'00000000'					; BRG16=0, normal for S8
	movwf	BAUDCON2
	movlw	b'00100000'					; BRGH=0, SYNC=0
	movwf	TXSTA2
	movlw	.25							; SPBRGH:SPBRG = .25 : 9615 BAUD @ 16 MHz
	movwf	SPBRG2
	movlw	b'10010000'
	movwf	RCSTA2
	banksel	common						; back to bank common
	bsf		PIE3,RC2IE					; enable RC2 INT
	bsf		s8_digital_avail			; digital S8 interface available
	return

enable_s8_analog:
	; S8 analog interface
	bcf		PIE3,RC2IE					; disable RC2 INT
	bsf		s8_npower					; power-down S8 HUD
	bcf		s8_digital_avail			; digital S8 interface not available
	return


	global	ir_s8_wait_tx
ir_s8_wait_tx:
	banksel	TXSTA2						; select bank for IO register access
rs232_wait_tx2_loop:
	btfss	TXSTA2,TRMT					; RS232 busy?
	bra		rs232_wait_tx2_loop			; YES - wait...
	banksel	common						; NO  - back to bank common
	return								;     - done

;-----------------------------------------------------------------------------

	global	enable_rs232
enable_rs232:
	call	request_speed_normal		; request CPU speed change to normal speed
enable_rs232_1:
	btfss	speed_is_normal				; speed = normal?
	bra		enable_rs232_1				; NO  - loop waiting for ISR to have adjusted the speed
	bcf		PORTE,0						; YES - switch port to comm
	bsf		PORTJ,2						;     - /Reset (required for very old OSTC sport)
	movlw	b'00100100'					;     - TX configuration: TX enabled, async, high speed
	movwf	TXSTA1						;     - ...
	movlw	b'10010000'					;     - RX configuration: port enabled, RX enabled
	movwf	RCSTA1						;     - ...
	movlw	HIGH(.65536-rx_timeout*.32)	;     - define TMR5H initialization value for RX timeout
	movwf	rx_timoeut_tmr5h_load		;     - store for later use
	return								;     - done


	global	disable_rs232
disable_rs232:
	clrf	RCSTA1						; disable RX
	clrf	TXSTA1						; disable TX
	bcf		PORTC,6						; switch TX pin hard to GND
	bsf		PORTE,0						; stop comm
	bcf		PORTJ,2						; /Reset (required for very old OSTC sport)
	return


	global	rs232_wait_tx				; ++++ do not touch WREG here! ++++
rs232_wait_tx:
	btfss	TXSTA1,TRMT					; last byte completely shifted out on TX pin?
	bra		rs232_wait_tx				; NO  - wait...
	btfss	ble_available				; YES - OSTC running with Bluetooth?
	return								;       NO  - done
	btfsc	NRTS						;       YES - Bluetooth module also completed TX?
	bra		rs232_wait_tx				;             NO  - wait...
	return								;             YES - done


										; ++++ make this code as fast as possible! ++++
	global	rs232_get_byte				; ++++       do not touch WREG here!       ++++
rs232_get_byte:
	bcf		rs232_rx_timeout			; clear timeout flag
	btfsc	PIR1,RCIF					; received a data byte? (bit is set on RX complete and reset on reading RCREG1)
	return								; YES - done, received a byte (fast path)
	movff	rx_timoeut_tmr5h_load,TMR5H	;     - load TMR5 high with timeout value
	clrf	TMR5L						;     - load TMR5 low  with a zero, writing low starts the timer
	bcf		PIR5,TMR5IF					;     - clear timer overflow flag
rs232_get_byte_loop:
	btfsc	PIR1,RCIF					; received a data byte?
	return								; YES - done, received a byte
	btfss	PIR5,TMR5IF					; NO  - timer overflow (timeout)?
	bra		rs232_get_byte_loop			;       NO  - continue looping
	;bra	rs232_rx_get_timeout		;       YES - give up

rs232_rx_get_timeout:
	bsf		rs232_rx_timeout			; set timeout flag
	bcf		RCSTA1,CREN					; clear receiver status by toggling CREN
	bsf		RCSTA1,CREN					; ...
	return								; done, given up


;-----------------------------------------------------------------------------
; Send and Receive functions to be used through the macros

; send a range of 1-256 bytes from memory to the RS232 interface
;
	global	serial_tx_ram
serial_tx_ram:
	movwf	eeprom_loop					; initialize loop counter (eeprom variable used here)
serial_tx_ram_loop:
	rcall	rs232_wait_tx				; wait for completion of last transmit
	movff	POSTINC2,TXREG1				; send a byte from memory to serial
	decfsz	eeprom_loop,F				; decrement loop counter, became zero?
	bra		serial_tx_ram_loop			; NO  - loop
	return								; YES - done


; receive a range of 1-256 byte from the RS232 interface and write them to memory
;
	global	serial_rx_stream_ram		; ++++ make this code as fast as possible! ++++
serial_rx_stream_ram:
	movwf	eeprom_loop					; initialize loop counter (eeprom variable used here)
serial_rx_stream_ram_loop_1:
	btfss	PIR1,RCIF					; received a data byte? (bit is set on RX complete and reset on reading RCREG1)
	bra		serial_rx_stream_ram_tmr	; NO  - enter loop with timeout
	movff	RCREG1,POSTINC2				; YES - copy received byte to memory
	decfsz	eeprom_loop,F				;     - decrement loop counter, became zero?
	bra		serial_rx_stream_ram_loop_1	;       NO  - loop
	bcf		rs232_rx_timeout			;       YES - clear timeout flag
	return								;           - all bytes received, done
serial_rx_stream_ram_tmr:
	movff	rx_timoeut_tmr5h_load,TMR5H	; load TMR5 high with timeout value
	clrf	TMR5L						; load TMR5 low  with a zero, writing low starts the timer
	bcf		PIR5,TMR5IF					; clear timer overflow flag
serial_rx_stream_ram_loop_2a:
	clrf	TMR5L						; restart timer (see above)
serial_rx_stream_ram_loop_2b:
	btfss	PIR1,RCIF					; received a data byte? (bit is set on RX complete and reset on reading RCREG1)
	bra		serial_rx_stream_ram_chk	; NO  - check timeout
	movff	RCREG1,POSTINC2				; YES - copy received byte to memory
	decfsz	eeprom_loop,F				;     - decrement loop counter, became zero?
	bra		serial_rx_stream_ram_loop_2a;       NO  - loop
	bcf		rs232_rx_timeout			;       YES - clear timeout flag
	return								;           - all bytes received, done
serial_rx_stream_ram_chk:
	btfss	PIR5,TMR5IF					; timer overflow (timeout)?
	bra		serial_rx_stream_ram_loop_2b; NO  - continue looping
	bra		rs232_rx_get_timeout		; YES - give up

;-----------------------------------------------------------------------------
	END
