;=============================================================================
;
;   File rx_ops.asm														V2.99c
;
;   RX (Tank Pressure Transmitter) Routines.
;
;   Copyright (c) 2018, heinrichs weikamp, all right reserved.
;=============================================================================

#include "hwos.inc"						; mandatory header
#include "shared_definitions.h"			; mailbox to p2_deco.c
#include "i2c.inc"
#include "math.inc"
#include "isr.inc"

	extern	get_first_gas_to_WREG
	extern	get_first_dil_to_WREG


; SAC calculation averaging settings
#DEFINE time_accu_target_OC			.60	; [s] target time accumulator filling level in OC  modes
#DEFINE time_accu_target_CCR		.180; [s] target time accumulator filling level in CCR mode


rx_ops	CODE

 IFDEF _rx_functions

;=============================================================================
; Get configured pressure readings
;
; input : opt_TR_1st_pres            - selector for first  pressure reading, in normal  mode
;         opt_TR_Bail_pres           - selector for first  pressure reading, in bailout mode
;         opt_TR_2nd_pres            - selector for second pressure reading, all modes
;
; output: int_IO_pressure_value+0/+2 - pressure in 0.1 bar, low byte
;         int_IO_pressure_value+1/+3 - pressure in 0.1 bar, high byte, including data not available flag
;         char_I_pressure_gas  +0/+1 - associated gas (1-5) / diluent (6-10)
;         char_I_pressure_age  +0/+1 - age of data in seconds (max 60)
;         char_I_pressure_stat +0/+1 - status data
;
	global	get_pressure_readings
get_pressure_readings:
	call	I2C_get_tankdata			; get raw pressure data
get_pressure_readings_1:
	movff	opt_TR_1st_pres,ul			; 1st pressure to read
	btfsc	FLAG_bailout_mode			; in bailout mode?
	movff	opt_TR_Bail_pres,ul			; YES - replace with assigned bailout selection
	tstfsz	ul							; disabled?
	bra		get_pressure_readings_1a	; NO  - get received pressure data
	rcall	get_pressure_readings_H1	; YES - set pressure data to not available
	bra		get_pressure_readings_1c	;     - continue with copying to result vars
get_pressure_readings_1a:
	movlw	.11							; first code for "special" pressures
	cpfslt	ul							; opt_TR_1st_pres < 11 ?
	rcall	get_pressure_readings_H2	; NO  - pre-process measurement selection
	rcall	get_pressure_readings_H3	; get transmitter ID
	rcall	get_pres_by_transmitter_id	; get data from transmitter with ID in hi:lo into hi:lo (pressure) and up (status)
get_pressure_readings_1c:
	movff	lo,int_IO_pressure_value+0	; copy pressure, low  byte
	movff	hi,int_IO_pressure_value+1	; copy pressure, high byte
	movff	ul,char_I_pressure_gas+0	; copy associated gas number
	movff	up,char_I_pressure_age+0	; copy age of data
	movff	ex,char_I_pressure_stat+0	; copy status data
get_pressure_readings_2:
	movff	opt_TR_2nd_pres,ul			; 2nd pressure to read
	tstfsz	ul							; disabled?
	bra		get_pressure_readings_2a	; NO  - get received pressure data
	rcall	get_pressure_readings_H1	; YES - set pressure data to not available
	bra		get_pressure_readings_2c	;     - continue with copying to result vars
get_pressure_readings_2a:
	movlw	.11							; first code for "special" pressures
	cpfslt	ul							; opt_TR_2nd_pres < 11 ?
	rcall	get_pressure_readings_H2	; NO  - pre-process measurement selection
	btfss	ul,7						; gas selector >= 127 (special treatment)?
	bra		get_pressure_readings_2b	; NO  - proceed reading a pressure
	rcall	get_pressure_readings_H1	; YES - set pressure data to not available
	bra		get_pressure_readings_2c	;     - continue wit copying to output data
get_pressure_readings_2b:
	rcall	get_pressure_readings_H3	; get transmitter ID
	rcall	get_pres_by_transmitter_id	; get data from transmitter with ID in hi:lo into hi:lo (pressure) and up (status)
get_pressure_readings_2c:
	movff	lo,int_IO_pressure_value+2	; copy pressure, low  byte
	movff	hi,int_IO_pressure_value+3	; copy pressure, high byte
	movff	ul,char_I_pressure_gas+1	; copy associated gas number
	movff	up,char_I_pressure_age+1	; copy age of data
	movff	ex,char_I_pressure_stat+1	; copy status data
	return

get_pressure_readings_H1:
	clrf	lo							; set pressure to 0 (low  byte)
	clrf	hi							; set pressure to 0 (high byte)
	clrf	up							; set age      to 0
	clrf	ex							; set status   to 0
	bsf		hi,int_not_avail_flag		; set flag for data not available
	return

get_pressure_readings_H2:
	movlw	.11
	subwf	ul,F
	bnz		get_pressure_readings_H2a
	call	get_first_gas_to_WREG		; ul = 11 -> ul = (get_first_gas_to_WREG)
	movwf	ul
	return
get_pressure_readings_H2a:
	decfsz	ul,F
	bra		get_pressure_readings_H2b
	movff	active_gas,ul				; ul = 12 -> ul = active_gas
	return
get_pressure_readings_H2b:
	decfsz	ul,F
	bra		get_pressure_readings_H2c
	call	get_first_dil_to_WREG		; ul = 13 -> ul = (get_first_dil_to_WREG) + 5
	movwf	ul
	movlw	.5
	addwf	ul,F
	return
get_pressure_readings_H2c:
	decfsz	ul,F
	bra		get_pressure_readings_H2d
	movff	active_dil,ul				; ul = 14 -> ul = active_dil + 5
	movlw	.5
	addwf	ul,F
	return
get_pressure_readings_H2d:
	movlw	.1
	movwf	ul							; ul >= 15 -> should not happen, default to ul = 1
	return

get_pressure_readings_H3:
	lfsr	FSR1,opt_transmitter_id_1	; load base address of transmitter ID array
	decf	ul,W						; (1-10) -> (0-9)
	mullw	.2							; IDs are 2 byte in size
	movf	PRODL,W						; WREG is index now
	movff	PLUSW1,lo					; get transmitter ID (low byte)
	incf	WREG,W						; increment index
	movff	PLUSW1,hi					; get transmitter ID (high byte)
	return


;=============================================================================
; Get data from transmitter with ID in (hi:lo)
;
; input:       hi:lo = transmitter ID
;
; output:      hi:lo = pressure in 0.1 bar    if return code =   0, else 0 + int_not_avail_flag
;              up    = packet age             if return code =   0, else 0
;              ex    = status data            if return code =   0, else 0
;
; return code:   0 transmitter found
;              254 illegal transmitter ID
;              255 transmitter not found
;
; RX slot data: Byte 0         : transmitter ID high byte
;                    1         : transmitter ID low  byte
;                    2 (-> hi) : pressure in 0.1 bar, high byte
;                    3 (-> lo) : pressure in 0.1 bar, low  byte
;                    4 (-> ex) : status data:
;                                bit 2..0: battery  status
;                                    5..3: sequence counter
;                                       6: =1 if pressure changed      (usage in RX slot data)
;                                          =1 if transmitter not found (usage in output  data)
;                                       7: =1 if pressure sensed       (usage in RX slot data)
;                                          =1 if low battery (< 3.0V)  (usage in output  data)
;                    5 (-> up) : age of data in seconds, 0 if slot is unused
;
	global	get_pres_by_transmitter_id
get_pres_by_transmitter_id:
	; hi:lo zero?
	tstfsz	hi							; hi <> zero ?
	bra		output_pressure_1			; YES - search transmitter
	tstfsz	lo							; lo <> zero ?
	bra		output_pressure_1			; YES - search transmitter
	movlw	.254						; NO to both - set return code for invalid transmitter ID
	bra		output_pressure_6			;            - clear result vars, set data as not available and return
output_pressure_1:
	lfsr	FSR1,rx_buffer				; load base address of RX buffer
	movlw	.8							; 8 RX slots to look at
	movwf	up							; up will be the loop counter
output_pressure_2:
	movf	POSTINC1,W					; get high byte of received transmitter ID
	cpfseq	hi							; match?
	bra		output_pressure_3			; NO  - check next slot
	movf	POSTINC1,W					; get low byte byte received transmitter ID
	cpfseq	lo							; match?
	bra		output_pressure_4			; NO  - check next slot
	; transmitter found, gather data	; YES - transmitter found, copy:
	movff	POSTINC1,hi					;     - pressure high byte,
	movff	POSTINC1,lo					;     - pressure low byte,
	movff	POSTINC1,ex					;     - status byte, and
	movff	POSTINC1,up					;     - packet age.
	movlw	rx_packet_overdue_timeout	;     - load overdue time
	subwf	up,W						;     - subtract overdue time from packet age
	btfss	STATUS,N					;     - result negative (packet younger than overdue time)?
	bsf		hi,int_outdated_flag		;       NO - set outdated flag
	bcf		ex,char_transmitter_lost	;     - clear transmitter lost flag
	bsf		ex,char_transmitter_low_bat	;     - set low battery warning by default
	btfsc	ex,1						;     - bit 1 of battery voltage set?
	bcf		ex,char_transmitter_low_bat	;     - YES - revoke low battery warning
	btfsc	ex,2						;     - bit 2 of battery voltage set?
	bcf		ex,char_transmitter_low_bat	;     - YES - revoke low battery warning
	;bsf	ex,char_transmitter_low_bat	;                                          DEBUG CODE TO FAKE A LOW BAT WARNING
	retlw	.0							;     - return with success code 0
output_pressure_3:
	movf	POSTINC1,W					; dummy read to advance FSR0 to byte 2 position
output_pressure_4:
	dcfsnz	up,F						; decrement loop counter, last slot searched?
	bra		output_pressure_5			; YES - return with error code
	movf	POSTINC1,W					; NO  - dummy reads to advance FSR0 to byte 3 (any other code would not be more compact...)
	movf	POSTINC1,W					;     -                            ... byte 4
	movf	POSTINC1,W					;     -                            ... byte 5
	movf	POSTINC1,W					;     -                            ... byte 6 = first byte of next slot
	bra		output_pressure_2			;     - loop
output_pressure_5:
	movlw	.255						; return code for transmitter not found
	clrf	ex							; clear ex (status data)
	bsf		ex,char_transmitter_lost	; set transmitter status to lost
	bra		output_pressure_7
output_pressure_6:
	clrf	ex							; clear ex (status data)
output_pressure_7:
	clrf	lo							; clear lo (pressure, low  byte)
	clrf	hi							; clear hi (pressure, high byte)
	clrf	up							; clear up (age of data)
	bsf		hi,int_not_avail_flag		; set flag for data not available
	return								; done


;=============================================================================
; Get transmitter ID in given slot
;
; input    : WREG  = slot (0-7)
; output   : hi:lo = transmitter ID
;
	global	get_transmitter_id_by_slot
get_transmitter_id_by_slot:
	lfsr	FSR1,rx_buffer				; load base address of RX buffer
	mullw	.6							; multiply WREG with 6 because each slot is 6 bytes in size
	movf	PRODL,W						; get result into WREG to be used as index (product is 42 at max)
	movff	PLUSW1,hi					; read transmitter ID high byte
	incf	WREG,W						; increment index
	movff	PLUSW1,lo					; read transmitter ID low  byte
	return


;=============================================================================
; Compute average pressure drop from 1st / 2nd reading
;
; Memory Map:
; ------------------------------------------------------------------------------------
;
; pres_accu_1st				res 4		; accumulator for pressure drop      in 1/(160 * 2^16) bar
; pres_accu_2nd				res 4		; accumulator for pressure drop      in 1/(160 * 2^16) bar
; time_accu_1st				res 1		; accumulator for reading  periods   in seconds
; gas__last_1st				res 1		; last gas assignment
; time_accu_2nd				res 1		; accumulator for reading  periods   in seconds
; gas__last_2nd				res 1		; last gas assignment
; pres_last_1st				res 2		; last pressure   reading  pressure  in 1/160 bar
; pres_last_2nd				res 2		; last pressure   reading  pressure  in 1/160 bar
; time_last_1st				res 2		; last pressure   reading  time      in seconds
; time_last_2nd				res 2		; last pressure   reading  time      in seconds
;
; int_IO_pressure_value [1] res 2		; current pressure reading           in 1/10   bar
; int_IO_pressure_value [2] res 2		; current pressure reading           in 1/10   bar
; int_I_pressure_drop   [1] res 2		; calculated average pressure drop   in 1/5120 bar/sec
; int_I_pressure_drop   [2] res 2		; calculated average pressure drop   in 1/5120 bar/sec

; relative positioning of 16 bit ASM variables
#DEFINE offset_FSR1_time_accu	.0		; offset  0 == base address of 1st/2nd
#DEFINE offset_FSR1_gas__last	.1		; offset  1 to base address of 1st/2nd
#DEFINE offset_FSR1_pres_last	.4		; offset  4 ...
#DEFINE offset_FSR1_time_last	.8		; offset  8 ...

; relative positioning of shared integer variables
#DEFINE offset_FSR2_press_curr	.0		; offset 0 == base address of 1st/2nd
#DEFINE offset_FSR2_press_drop	.4		; offset 4 to base address of 1st/2nd


calc_pres_drop_1st:
	; set up base addresses
	lfsr	FSR0,pres_accu_1st-1		; load base address - 1 of pressure accumulator
	lfsr	FSR1,time_accu_1st			; load base address     of other ASM  variables
	lfsr	FSR2,int_IO_pressure_value+0; load base address     of the shared variables

	; get the currently assigned gas into lo
	movff	char_I_pressure_gas+0,lo

	; get the age of the current reading into hi
	movff	char_I_pressure_age+0,hi

	; continue with common part
	bra		calc_pres_drop_common

calc_pres_drop_2nd:
	; set up base addresses
	lfsr	FSR0,pres_accu_2nd-1		; load base address - 1 of pressure accumulator
	lfsr	FSR1,time_accu_2nd			; load base address     of other ASM  variables
	lfsr	FSR2,int_IO_pressure_value+2; load base address     of the shared variables

	; get the currently assigned gas into lo
	movff	char_I_pressure_gas+1,lo

	; get the age of the current reading into hi
	movff	char_I_pressure_age+1,hi

calc_pres_drop_common:
	; load the pressure accumulator into xC - FSR0 has been initialized to base address -1
	movff	PREINC0,xC+0				; copy  pressure accumulator to xC, lowest  byte
	movff	PREINC0,xC+1				; copy  pressure accumulator to xC, second  byte
	movff	PREINC0,xC+2				; copy  pressure accumulator to xC, third   byte
	movff	PREINC0,xC+3				; copy  pressure accumulator to xC, highest byte

	; check if the assigned gas has changed
	movlw	offset_FSR1_gas__last		; load index of last assigned gas
	movf	PLUSW1,W					; copy last gas to WREG
	cpfseq	lo							; is current gas = last gas ?
	bra		calc_pres_drop_reset		; NO  - reset everything

	; check if the pressure reading is activated at all
	tstfsz	lo							; is there no gas (0=off) assigned to the reading?
	bra		calc_pres_drop_common_1		; NO  - continue
	bra		calc_pres_drop_reset		; YES - reset everything

calc_pres_drop_common_1:
	; load the time accumulator into xB
	movff	INDF1,xB+0					; load  time accumulator, low  byte (had been stored)
	clrf	xB+1						; clear time accumulator, high byte (will be reset to 0 each round)

	; get the current pressure value into divA - after copying, FSR2 will have been restored to initial address
	movff	POSTINC2,divA+0				; copy current pressure value to divA, low  byte
	movff	POSTDEC2,divA+1				; copy current pressure value to divA, high byte

	; check if the current pressure value is available and not outdated
	bsf		aux_flag					; set the current pressure value as not available or outdated by default
	btfsc	divA+1,int_not_avail_flag	; current pressure value not available?
	bra		calc_pres_drop_common_2		; YES - skip updating the accumulators with new data
	btfsc	divA+1,int_outdated_flag	; current pressure outdated?
	bra		calc_pres_drop_common_2		; YES - skip updating the accumulators with new data
	bcf		aux_flag					; NO to both - set current pressure value as available and up-to-date

	; check if a new reading has been received
	movlw	.2							; capture new reading at an age of 2 (age 1 sometimes slips through...)
	subwf	hi,W						; subtract capture-age from reading age, dump result to WREG
	bnz		calc_pres_drop_common_2		; result <> 0 ? YES - skip updating the accumulators

	; multiply the current pressure with 16 (pre-scaling), this will also remove the flags
	movlw	.4							; multiply with 16 = 2^4
	call	mult16						; divA = divA * 2^WREG

	; get the last pressure value and store the current pressure as the new last pressure value
	movlw	offset_FSR1_pres_last+0		; load index of last pressure value,                       low  byte
	movff	PLUSW1,sub_b+0				; copy last pressure value to sub_b,                       low  byte
	movff	divA+0,PLUSW1				; store current pressure value as new last pressure value, low  byte
	movlw	offset_FSR1_pres_last+1		; load index of last pressure value,                       high byte
	movff	PLUSW1,sub_b+1				; copy last pressure value to sub_b,                       high byte
	movff	divA+1,PLUSW1				; store current pressure value as new last pressure value, high byte

	; add the last pressure value to the pressure accumulator: pres_accu (xC) += pres_last (sub_b) * 2^16
	movf	sub_b+0,W					; copy          pres_last (sub_b) to WREG, low     byte
	addwf	xC+2,F						; add to        pres_accu (xC),            third   byte
	movf	sub_b+1,W					; copy          pres_last (sub_b) to WREG, high    byte
	addwfc	xC+3,F						; add to        pres_accu (xC),            highest byte

	; subtract the current pressure from the pressure accumulator: pres_accu (xC) -= pres_curr (divA) * 2^16
	; -> effectively, the pressure drop during the last measurement period has been added now
	bcf		neg_flag					; clear neg_flag by default
	movf	divA+0,W					; copy          pres_curr (divA) to WREG, low     byte
	subwf	xC+2,F						; subtract from pres_accu (xC),           third   byte
	movf	divA+1,W					; copy          pres_curr (divA) to WREG, high    byte
	subwfb	xC+3,F						; subtract from pres_accu (xC),           highest byte
	btfss	STATUS,C					; did the accumulator under-run (result negative)?
	bsf		neg_flag					; YES - memorize this

	; get the current time into lo
	SAFE_2BYTE_COPY total_divetime_seconds,lo	; get current total dive time into lo:2

	; get the last pressure time and store the current time as the new last pressure time
	movlw	offset_FSR1_time_last+0		; load index of last pressure time,             low  byte
	movff	PLUSW1,sub_b+0				; copy last pressure time to sub_b,             low  byte
	movff	lo+0,PLUSW1					; store current time as new last pressure time, low  byte
	movlw	offset_FSR1_time_last+1		; load index of last pressure time,             high byte
	movff	PLUSW1,sub_b+1				; copy last pressure time to sub_b,             high byte
	movff	lo+1,PLUSW1					; store current time as new last pressure time, high byte

	; did the pressure accumulator under-run before because the current pressure is higher than the accumulator value was?
	; we can not check & abort earlier because the current time needs to be stored along with the current pressure
	btfsc	neg_flag					; did the pressure accumulator under-run?
	bra		calc_pres_drop_restart		; YES - reset both accumulators and set average pressure drop to not available

	; add the current time to the time accumulator: time_accu (xB) += time_curr (lo)
	movf	lo+0,W						; copy   time_curr (lo) to WREG,  low  byte
	addwf	xB+0,F						; add to time_accu (xB),          low  byte
	movf	lo+1,W						; copy   time_curr (lo) to WREG,  high byte
	addwfc	xB+1,F						; add to time_accu (xB),          high_byte

	; subtract the last pressure time from time accumulator: time_accu (xB) -= time_last (sub_b)
	movf	sub_b+0,W					; copy          time_last (sub_b) to WREG, low  byte
	subwf	xB+0,F						; subtract from time_accu (xB),            low  byte
	movf	sub_b+1,W					; copy          time_last (sub_b) to WREG, high byte
	subwfb	xB+1,F						; subtract from time_accu (xB),            high byte
	btfss	STATUS,C					; did the accumulator under-run (result negative) because of a wrap-around of the current time?
	bra		calc_pres_drop_restart		; YES - reset both accumulators and set average pressure drop to not available

	; check if the time accumulator (xB) is or has become too large
	; this will happen if the last valid pressure reading is older than (256 - time_accu target) seconds
	tstfsz	xB+1						; is the time accumulator < 256 [seconds], i.e. high byte = 0 ?
	bra		calc_pres_drop_restart		; NO  - reset both accumulators and set average pressure drop to not available

calc_pres_drop_common_2:
	; check if the time accumulator is or has become zero to avoid a div/0
	; as long as no valid pressure value is available, the time accumulator will stay at 0 and the pressure drop calculation kept in reset
	movf	xB+0,W						; copy time accumulator low byte to WREG, does it set the zero flag?
	bz		calc_pres_drop_restart		; YES - reset both accumulators and set average pressure drop to not available

	; duplicate pressure and time accumulators to other variables because xC and xB will get destroyed in div32x16 operation
	movff	xC+0,lo+0					; duplicate pres_accu to lo, lowest  byte
	movff	xC+1,lo+1					; duplicate pres_accu to lo, second  byte
	movff	xC+2,lo+2					; duplicate pres_accu to lo, third   byte
	movff	xC+3,lo+3					; duplicate pres_accu to lo, highest byte
	movff	xB+0,divA+0					; duplicate time_accu to divA,  low  byte
	movff	xB+1,divA+1					; duplicate time_accu to divA,  high byte

	; calculate average pressure drop: pres_drop (xC) = pres_accu (xC) / time_accu (xB)
	call	div32x16					; xC = xC / xB, xC is average pressure drop in 1/(160 * 2^16) bar/sec

	; is the time accumulator above target level? (only the low byte needs to be evaluated)?
	incf	ul,W						; load the target threshold, +1 (incf) transforms cpfslt from < to <= operation
	cpfslt	divA+0						; is the time accumulator > target threshold ?
	rcall	calc_pres_drop_reduce_accus	; YES - do an accumulator reduction

	; do an additional half-rate (every 2nd second) accumulator reduction
	btfsc	total_divetime_seconds+0,0	; are we on an even second?
	rcall	calc_pres_drop_reduce_accus	; YES - do an additional accumulator reduction

	; store pressure accumulator (lo:4) - FSR0 was left pointing to address of highest byte
	movff	lo+3,POSTDEC0				; store pressure accumulator, highest byte
	movff	lo+2,POSTDEC0				; store pressure accumulator, third   byte
	movff	lo+1,POSTDEC0				; store pressure accumulator, second  byte
	movff	lo+0,POSTDEC0				; store pressure accumulator, lowest  byte

	; store the time accumulator
	movff	divA+0,INDF1				; store time accumulator (only the low byte will be stored)

	; check if the average pressure drop for transfer to p2deco needs to be limited
	tstfsz	xC+3						; check if the highest byte is all zero
	bra		calc_pres_drop_limit		; NO  - limit output
	btfsc	xC+2,7						; check if the highest bit of the third byte is zero
	bra		calc_pres_drop_limit		; NO  - limit output

	; pick and adjust the bytes from pres_drop for transfer to p2deco
	movff	xC+1,divA+0					; pick second byte of average pressure drop for transfer to p2deco as low  byte
	movff	xC+2,divA+1					; pick third  byte of average pressure drop for transfer to p2deco as high byte
	movlw	.3							; divide by 8 = 2^3
	call	div16						; divA = divA / 2^WREG
	bra		calc_pres_drop_common_3

calc_pres_drop_limit:
	; limit output to 0x0FFF
	movlw	LOW  0x0FFF					; set output to 0x0FFF
	movwf	divA+0						; ...
	movlw	HIGH 0x0FFF					; ...
	movwf	divA+1						; ...
	bsf		divA+1,int_warning_flag		; set warning flag indicating out-of-range

calc_pres_drop_common_3:
	; set the average pressure drop as not available if the last pressure reading is outdated or not available
	btfsc	aux_flag					; is the last pressure reading outdated or not available?
	bsf		divA+1,int_not_avail_flag	; YES - set pressure drop to not available, too

	; set the average pressure drop as outdated if time_accu (divA) < (target threshold / 2)
	rrncf	ul,W						; load time accumulator target value / 2 into WREG
	decf	WREG,W						; subtract 1 to transform cpfsgt from > to >= operation
	cpfsgt	INDF1						; time accumulator < (target threshold / 2) ?
	bsf		divA+1,int_outdated_flag	; YES - set outdated flag

	; write average pressure drop to p2deco interface
	movlw	offset_FSR2_press_drop+0	; load index of average pressure drop, low  byte
	movff	divA+0,PLUSW2				; store         average pressure drop, low  byte
	movlw	offset_FSR2_press_drop+1	; load index of average pressure drop, high byte
	movff	divA+1,PLUSW2				; store         average pressure drop, high byte

	; done
	return


calc_pres_drop_reduce_accus:
	; subtract 1 second from the time accumulator: time_accu (divA) -= 1 (only the low byte needs to be processed)
	decf	divA+0,F					; decrement low byte of time_accu

	; subtract average pressure drop per second from pressure accumulator: press_accu (lo) -= press_drop (xC)
	movf	xC+0,W						; copy          press_drop(xC) to WREG, lowest  byte
	subwf	lo+0,F						; subtract from pres_accu,              lowest  byte
	movf	xC+1,W						; copy          press_drop(xC) to WREG, second  byte
	subwfb	lo+1,F						; subtract from pres_accu,              second  byte
	movf	xC+2,W						; copy          press_drop(xC) to WREG, third   byte
	subwfb	lo+2,F						; subtract from pres_accu,              third   byte
	movf	xC+3,W						; copy          press_drop(xC) to WREG, highest byte
	subwfb	lo+3,F						; subtract from pres_accu,              highest byte
	btfsc	STATUS,C					; did the buffer under-run (result negative)?
	return								; NO  - done
	clrf	lo+0						; YES - clear pressure accumulator, lowest  byte
	clrf	lo+1						;     - clear pressure accumulator, second  byte
	clrf	lo+2						;     - clear pressure accumulator, third   byte
	clrf	lo+3						;     - clear pressure accumulator, highest byte
	return								;     - done

calc_pres_drop_reset:
	; store the current gas as the last gas
	movlw	offset_FSR1_gas__last		; load index of            last gas
	movff	lo,PLUSW1					; store current gas as new last gas

	; clear last pressure value
	movlw	offset_FSR1_pres_last+0		; load index of last pressure value, low  byte
	clrf	PLUSW1						; clear         last pressure value, low  byte
	movlw	offset_FSR1_pres_last+1		; load index of last pressure value, high byte
	clrf	PLUSW1						; clear         last pressure value, high byte

	; clear last pressure time
	movlw	offset_FSR1_time_last+0		; load index of last pressure time, low  byte
	clrf	PLUSW1						; clear         last pressure time, low  byte
	movlw	offset_FSR1_time_last+1		; load index of last pressure time, high byte
	clrf	PLUSW1						; clear         last pressure time, high byte

calc_pres_drop_restart:
	; clear pressure accumulator - FSR0 was left pointing to address of highest byte
	clrf	POSTDEC0					; clear pressure accumulator, highest byte
	clrf	POSTDEC0					; clear pressure accumulator, third   byte
	clrf	POSTDEC0					; clear pressure accumulator, second  byte
	clrf	POSTDEC0					; clear pressure accumulator, lowest  byte

	; clear time accumulator
	clrf	INDF1						; clear time accumulator

	; clear pressure drop and set it to not available
	movlw	offset_FSR2_press_drop+0	; load index of average  pressure drop, low  byte
	clrf	PLUSW2						; clear         average  pressure drop, low  byte
	movlw	offset_FSR2_press_drop+1	; load index of average  pressure drop, high byte
	clrf	PLUSW2						; clear         average  pressure drop, high byte
	bsf		PLUSW2,int_not_avail_flag	;               set flag for data not available

	return								; done


;=============================================================================
; set up SAC calculation dependent on TR mode
;
	global	configure_sac_calculation
configure_sac_calculation:
	movlw	time_accu_target_OC			; load time accumulator target value for OC as default
	movwf	ul							; store it in ul
	movff	opt_TR_mode,WREG			; get TR mode
	dcfsnz	WREG,W						; TR mode = 1 (on)?
	bra		configure_sac_calculation_1	; YES
	dcfsnz	WREG,W						; TR mode = 2 (ind.double)?
	bra		configure_sac_calculation_2	; YES
	dcfsnz	WREG,W						; TR mode = 3 (CCR Dil+O2)?
	bra		configure_sac_calculation_3	; YES
	bra		configure_sac_calculation_4	; NO to all - was disabled then (or invalid)

configure_sac_calculation_1:			; TR mode 1: calculate SAC on 1st reading
	rcall	calc_pres_drop_1st			; calculate pressure  drop on 1st reading
	movlw	.1							; select SAC mode 1:   SAC on 1st reading
	bra		configure_sac_calculation_5	; goto exit

configure_sac_calculation_2:			; TR mode 2: independent double
	rcall	calc_pres_drop_1st			; calculate pressure  drop on 1st reading
	rcall	calc_pres_drop_2nd			; calculate pressure  drop on 2nd reading
	movlw	.3							; select SAC mode 3: SAC on higher of both readings
	bra		configure_sac_calculation_5	; goto exit

configure_sac_calculation_3:			; TR mode 3: CCR Dil+O2
	btfsc	FLAG_bailout_mode			; in bailout?
	bra		configure_sac_calculation_1	; YES - handle alike TR mode 1
	movlw	time_accu_target_CCR		; load time accumulator target value for CCR mode
	movwf	ul							; store it in ul
	rcall	calc_pres_drop_2nd			; calculate pressure drop on 2nd reading
	movlw	.4							; select SAC mode 4:  SAC on 2nd reading, O2 usage
	bra		configure_sac_calculation_5	; goto exit

configure_sac_calculation_4:
	clrf	WREG						; select SAC mode 0 (disabled)

configure_sac_calculation_5:
	movff	WREG,char_I_SAC_mode		; write SAC mode selection
	return

;=============================================================================

 ENDIF

	END