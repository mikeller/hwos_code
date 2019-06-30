;=============================================================================
;
;   File hwos.asm                             combined next generation V3.03.4
;
;   Definition of the hwOS dive computer platform.
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;   2011-05-24 : [jDG] Cleanups from initial Matthias code
;   2011-06-24 : [MH]  Added clock speeds

;=============================================================================

#DEFINE ACCESS_RAM_VARS			; the access RAM variables are declared in this file

#include "hwos.inc"
#include "eeprom_rs232.inc"

;----------------------------- CONFIG ----------------------------------------
	CONFIG	RETEN   = OFF		; disabled - controlled by SRETEN bit
	CONFIG	SOSCSEL = HIGH		; High Power SOSC circuit selected
	CONFIG	XINST   = OFF		; code won't execute in extended mode
	CONFIG	FOSC    = INTIO2	; internal RC oscillator, no clock-out
	CONFIG	PLLCFG  = OFF		;
	CONFIG	IESO    = OFF		; disabled
	CONFIG	PWRTEN  = OFF		; disabled, because incompatible with ICD3 (Ri-400)
	CONFIG	BOREN   = ON		; controlled with SBOREN bit
	CONFIG	BORV    = 2			; 2.0V
	CONFIG	BORPWR  = MEDIUM	; BORMV set to medium power level
	CONFIG	WDTEN   = ON		; WDT controlled by SWDTEN bit setting
	CONFIG	WDTPS   = 128		; 1:128
	CONFIG	RTCOSC  = SOSCREF	; RTCC uses SOSC
	CONFIG	MCLRE   = ON		; MCLR Enabled, RG5 Disabled
	CONFIG	CCP2MX  = PORTBE	; RE7 micro-controller mode/RB3-all other modes


;---------------------------- Bank0 ACCESS RAM -------------------------------
ac_ram		equ			0x000
ac_ram		udata_acs	ac_ram				; access RAM data


;---- Flags - Hardware Descriptors
HW_descriptor					res 1		; OSTC - model descriptor (cleared & rebuilt in restart)
HW_variants						res 1		; OSTC - model variants   (NOT cleared in restart)
HW_variants2						res 1		; OSTC - model variants   (NOT cleared in restart)
						
;---- Flags - Hardware States
HW_flags_state					res 1		; hardware - states

;--- Flags - Operating System
OS_flags_persist				res 1		; system - persistent settings (NOT cleared in restart)
OS_flags_ISR1					res 1		; system - ISR control 1
OS_flags_ISR2					res 1		; system - ISR control 2

;---- Flags - Operating Modes
OM_flags_mode					res 1		; operating modes

;---- Flags - Dive Modes
DM_flags_deco					res 1		; dive mode - main dive & deco mode

;---- CPU Speed
cpu_speed_request				res 1		; requested CPU speed: =1: eco, =2: normal, =3: fastest
cpu_speed_state					res 1		; current   CPU speed: =1: eco, =2: normal, =3: fastest

;---- Timebase & Eventbase
timebase						res 1		; timed trigger flags and running timebase
eventbase						res 1		; event trigger flags

;---- Timeout-Timer Service
isr_timeout_timer				res 1		; timeout timer
isr_timeout_reload				res 1		; timeout reload value

;---- Dive Times
total_divetime_secs				res 2		; total   dive time, seconds
counted_divetime_mins			res 2		; counted dive time, minutes  | Attention: do not change the position of
counted_divetime_secs			res 1		; counted dive time, seconds  | these 2 Variables relative to each other!

;---- Dive Times / Apnoe
apnoe_surface_mins				res 1		; surface time minutes        | Attention: do not change the position of
apnoe_surface_secs				res 1		; surface time seconds        | these 2 Variables relative to each other!

apnoe_dive_mins					res 1		; dive    time minutes        | Attention: do not change the position of
apnoe_dive_secs					res 1		; dive    time seconds        | these 2 Variables relative to each other!


;---- Profile Recording
sampling_rate					res 1		; configured sampling rate
sampling_timer					res 1		; sampling timer

;---- Simulator Mode
simulatormode_depth				res 1		; depth in simulator mode

;---- HUD / Sensor Data
hud_status_byte					res 1		; HUD status byte, see definition of flags   | Attention: keep relative position
hud_battery_mv					res 2		; hud/ppo2 monitor battery voltage in mV     | between these two variables!


; 28 byte user data
; 32 byte tmp  data placed by C compiler
; 20 byte variables placed by math library
; ==
; 81 byte used, 15 byte free (96 byte total available)

	global	HW_descriptor
	global	HW_variants
	global	HW_variants2
	global	HW_flags_state
	global	OS_flags_persist
	global	OS_flags_ISR1
	global	OS_flags_ISR2
	global	OM_flags_mode
	global	DM_flags_deco
	global	cpu_speed_request
	global	cpu_speed_state
	global	timebase
	global	eventbase
	global	isr_timeout_timer
	global	isr_timeout_reload
	global	total_divetime_secs
	global	counted_divetime_mins
	global	counted_divetime_secs
	global	apnoe_surface_secs
	global	apnoe_surface_mins
	global	apnoe_dive_secs
	global	apnoe_dive_mins
	global	sampling_rate
	global	sampling_timer
	global	simulatormode_depth
	global	hud_status_byte
	global	hud_battery_mv

;-----------------------------------------------------------------------------

hwos	CODE

;=============================================================================

	global	init_ostc
init_ostc:

; Oscillator
	banksel	common				; select bank common
	movlw	b'01110010'
	movwf	OSCCON				; 16 MHz INTOSC
	movlw	b'00001000'
	movwf	OSCCON2				; secondary oscillator running
	movlw	b'00000000'
	movwf	OSCTUNE				; 4x PLL disable (Bit 6) - only works with 8 or 16MHz (=32 or 64MHz)

	movlw	coding_speed_normal	; coding for normal CPU speed
	movwf	cpu_speed_request	; store CPU shall run with normal speed
	movwf	cpu_speed_state		; store CPU does  run with normal speed

	;bcf	RCON,SBOREN			; brown-out off (not needed here, is handled in bootloader)
	bcf		RCON,IPEN			; priority interrupts off

	banksel	WDTCON
	movlw	b'10000000'
	movwf	WDTCON				; setup watchdog


; I/O Ports
	banksel	0xF16				; addresses, F16h through F5Fh, are also used by SFRs, but are not part of the access RAM
	clrf	REFOCON				; no reference oscillator active on REFO pin
	clrf	ODCON1				; disable open drain capability
	clrf	ODCON2				; disable open drain capability
	clrf	ODCON3				; disable open drain capability
	clrf	CM1CON				; disable
	clrf	CM2CON				; disable
	clrf	CM3CON				; disable

	movlw	b'11000000'			; ANSEL, AN7 and AN6 -> Analog inputs, PORTA is digital
	movwf	ANCON0
	movlw	b'00000111'			; ANSEL, AN8, AN9, AN10 -> Analog input
	movwf	ANCON1
	movlw	b'00000010'			; ANSEL, AN17 -> Analog input
	movwf	ANCON2
	banksel	common

;	movlw	b'00000000'			; 1= input -> Data TFT_high
	clrf	TRISA
;	movlw	b'00000000'			; init port
	clrf	PORTA

	movlw	b'00000011'			; 1= input, (RB0, RB1) -> switches, RB2 -> Power_MCP, RB3 -> s8_npower, RB4 -> LED_green/rx_nreset, RB5 -> /TFT_POWER
	movwf	TRISB
	movlw	b'00111000'			; init port, rx_nreset=1 -> hard reset RX
	movwf	PORTB

	movlw	b'10011010'			; 1= input, (RC0, RC1) -> SOSC, RC2 -> TFT_LED_PWM, (RC3,RC4) -> I²C, RC5 -> MOSI_MS5541, (RC6, RC7) -> UART1
	movwf	TRISC
;	movlw	b'00000000'			; init port
	clrf	PORTC

	movlw	b'00100000'			; 1= input, RD0 -> TFT_NCS, RD1 -> TFT_RS, RD2 -> TFT_NWR, RD3 -> TFT_RD, RD4 -> MOSI_Flash, RD5 -> MISO_Flash, RD6 -> CLK_Flash, RD7 -> TFT_NRESET
	movwf	TRISD
;	movlw	b'00000000'			; init port
	clrf	PORTD

	movlw	b'00100000'			; 1= input, RE0 -> NPOWER_BLE, RE1 -> Power_IR, RE2 -> CS_MCP, RE3 -> LED_blue, RE4 -> power_sw1, RE5 -> leave as input
	movwf	TRISE
	movlw	b'00010001'			; init port
	movwf	PORTE

	movlw	b'01111110'			; 1= input, (RF1, RF2, RF3, RF4, RF5) -> Analog
	movwf	TRISF
;	movlw	b'00000000'			; init port
	clrf	PORTF

	movlw	b'00001110'			; 1= input, <7:6> not implemented, RG0 -> TX3_PIEZO_CFG, RG2 -> RX2, RG3 -> AN17_RSSI, RG4 -> SOSC_OUT, RG5 -> /RESET
	movwf	TRISG
	movlw	b'00000001'			; init port
	movwf	PORTG

;	movlw	b'00000000'			; 1= input -> Data TFT_low
	clrf	TRISH
;	movlw	b'00000000'			; init port
	clrf	PORTH

	movlw	b'10011011'			; 1= input, RJ4 -> vusb_in, RJ5 -> power_sw2, RJ6 -> CLK_MS5541, RJ7 -> MISO_MS5541
	movwf	TRISJ
	movlw	b'00100000'			; init port
	movwf	PORTJ


; disable Charger by default
	bsf		charge_disable		; set      charging-inhibit signal
	bcf		charge_enable		; activate charging-inhibit signal


; Timer 0
	movlw	b'00000001'			; timer0 with 1:4 prescaler
	movwf	T0CON


; Timer 1 - Button hold-down timer
	movlw	b'10001100'			; 32768 Hz clock source, 1:1 prescaler -> ; 30.51757813 µs/bit in TMR1L:TMR1H
	movwf	T1CON


; RTCC
	banksel	0xF16				; addresses, F16h through F5Fh, are also used by SFRs, but are not part of the access RAM
	movlw	0x55
	movwf	EECON2
	movlw	0xAA
	movwf	EECON2
	bsf 	RTCCFG,RTCWREN		; unlock sequence for RTCWREN
	bsf		RTCCFG,RTCPTR1
	bsf		RTCCFG,RTCPTR0
	bsf		RTCCFG,RTCEN		; module enable
	bsf		RTCCFG,RTCOE		; output enable
	movlw	b'00000100'			; 32768 Hz SOCS on RTCC pin (PORTG,4) Bit7-5: pull-ups for Port D, E and J
	movwf	PADCFG1
	movlw	b'11000000'
	movwf	ALRMCFG				; 1/2 second alarm
	movlw	d'1'
	movwf	ALRMRPT				; alarm repeat counter
	movlw	0x55
	movwf	EECON2
	movlw	0xAA
	movwf	EECON2
	bcf		RTCCFG,RTCWREN		; lock sequence for RTCWREN
	banksel	common


; A/D Converter
	movlw	b'00011000'			; power off ADC, select AN6
	movwf	ADCON0
	movlw	b'00100000'			; 2.048V Vref+
	movwf	ADCON1
	movlw	b'10001101'			; right aligned
	movwf	ADCON2


; serial Port 1 (TRISC6/7)
	movlw	b'00001000'			; BRG16=1
	movwf	BAUDCON1
	movlw	.34					; SPBRGH:SPBRG =  .34 : 114285 BAUD @ 16MHz (+0.79% Error at 115200 BAUD)
	movwf	SPBRG1				; SPBRGH:SPBRG = .207 :  19230 BAUD @ 16MHz (-0.16% Error at  19200 BAUD)
	clrf	SPBRGH1				;

	clrf	RCSTA1
	clrf	TXSTA1				; UART disable
	bcf		PORTC,6				; TX hard to GND


; serial Port 2 (TRISG2) for IR/S8 digital interface
;
; - will be initialized by enable_ir_s8 (eeprom_rs232.asm) in case IR/S8 shall be available


; Timer 3 for IR-RX Timeout
 IFDEF _external_sensor
	clrf	T3GCON				; reset Timer3 gate control register
	movlw	b'10001001'			; synced, 1:1 prescaler -> 2 seconds till overrun @ 32768 Hz,
								;                          incrementing by 1 bit each 30.51757813 µs
	movwf	T3CON
 ENDIF


; SPI Module(s)
; SPI2: External Flash
	movlw	b'00110000'
	movwf	SSP2CON1
;	movlw	b'00000000'
	clrf	SSP2STAT
								; -> 0.25 MHz Bit clock @  1 MHz mode (Eco)
								; ->    4 MHz Bit clock @ 16 MHz mode (Normal)
								; ->   16 MHz Bit clock @ 64 MHz mode (Fastest)


; MSSP1 Module: I2C Master
	movlw	b'00101000'			; I2C master mode
	movwf	SSP1CON1
;	movlw	b'00000000'
	clrf	SSP1CON2
	movlw	0x27
	movwf	SSP1ADD				; 100kHz @ 16MHz Fosc


; PWM Module(s)
; PWM 1 for LED dimming
	movlw	b'00001100'
	movwf	CCP1CON
	movlw	b'00000001'
	movwf	PSTR1CON			; pulse steering disabled
	movlw	d'255'
	movwf	PR2					; period
	; 255 is max brightness (300 mW)
	clrf	CCPR1L				; duty cycle
	clrf	CCPR1H				; duty cycle
	movlw	T2CON_NORMAL
	movwf	T2CON


; Timer 5 for ISR-independent wait routines
	clrf	T5GCON				; reset Timer5 gate control register
	movlw	b'10001011'			; synced, 16 bit mode, 1:1 prescaler -> 2 seconds till overrun @ 32768 Hz,
	movwf	T5CON				;                                       incrementing by 1 bit each 30.51757813 µs


	banksel	0xF16				; addresses F16h through F5Fh are also used by SFRs, but are not part of the access RAM

; Timer 7 for 62.5 ms Interrupt (sensor states)
	clrf	T7GCON				; reset Timer7 gate control register
	movlw	b'10001001'			; 1:1 prescaler -> 2 seconds @ 32768 Hz, synced
	movwf	T7CON
	clrf	TMR7L
	movlw	.248
	movwf	TMR7H				; -> rollover after 2048 cycles -> 62.5 ms


; turn off unused timers
	movlw	b'11000000'
	movwf	PMD0
 IFDEF _external_sensor
	movlw	b'11010001'
 ELSE
	movlw	b'11011001'			; includes turning off timer 3
 ENDIF
	movwf	PMD1
	movlw	b'11010111'
	movwf	PMD2
	movlw	b'11111111'
	movwf	PMD3


; turn off unused CTMU
	clrf	CTMUCONH
	clrf	CTMUCONL
	clrf	CTMUICON

	banksel	common


; Interrupts
	movlw	b'11010000'
	movwf	INTCON
	movlw	b'00001000'			; Bit7=1: pull-up for PORTB disabled
	movwf	INTCON2
	movlw	b'00000000'
	movwf	INTCON3
	movlw	b'00000001'			; Bit0: TMR1
	movwf	PIE1
	movlw	b'00000010'			; Bit1: TMR3
	movwf	PIE2
	movlw	b'00000000'			; Bit1: TMR5
	movwf	PIE5
	movlw	b'00100001'			; Bit0: RTCC, Bit5: UART2
	movwf	PIE3
	movlw	b'00001000'			; Bit3: TMR7
	movwf	PIE5

	bcf		active_reset_ostc_rx	; release RESET from RX circuitry
	;bra	power_up_switches


	global	power_up_switches
power_up_switches:
	bsf		power_sw1			; switch on power supply for switch 1
	btfss	power_sw1			; power established?
	bra		$-4					; NO - wait
	bsf		power_sw2			; switch on power supply for switch 2
	btfss	power_sw2			; power established?
	bra		$-4					; NO - wait

	return

;=============================================================================
; CPU speed change request functions

	global	request_speed_eco
request_speed_eco:
	movlw	coding_speed_eco		; load coding for eco speed
	movwf	cpu_speed_request		; request ISR to change the CPU speed
	return							; done

	global	request_speed_normal
request_speed_normal:
	movlw	coding_speed_normal		; load coding for normal speed
	movwf	cpu_speed_request		; request ISR to change the CPU speed
	return							; done

	global	request_speed_fastest
request_speed_fastest:
	movlw	coding_speed_fastest	; load coding for fastest speed
	movwf	cpu_speed_request		; request ISR to change the CPU speed
	return							; done

;=============================================================================
; Backup the first 128 bytes from program memory to EEPROM
;
	global	backup_flash_page
backup_flash_page:
	banksel	common
	movlw	0x00					; start address in internal program memory
	movwf	TBLPTRL
	movwf	TBLPTRH
	movwf	TBLPTRU

	movlw	.128					; copy 1 block = 128 byte
	movwf	lo						; byte counter

	clrf	EEADR					; start address in EEPROM, low
	movlw	.3						; start address in EEPROM, high
	movwf	EEADRH

	TBLRD*-							; dummy read to be in 128 byte block
backup_flash_loop:
	tblrd+*							; read one byte from program memory (with pre-increment)
	movff	TABLAT,EEDATA			; transfer byte from program memory read to EEPROM write
	call	write_eeprom			; execute EEPROM write
	incf	EEADR,F					; increment EEPROM address
	decfsz	lo,F					; 128 byte done?
	bra		backup_flash_loop		; NO  - loop
	clrf	EEADRH					; YES - reset EEPROM high address
	return							;     - done

;=============================================================================
; Restore the first 128 bytes from EEPROM to program memory
;
	global	restore_flash
restore_flash:
	banksel	common
	movlw	0x00					; start address in internal program memory
	movwf	TBLPTRL
	movwf	TBLPTRH
	movwf	TBLPTRU

	movlw	b'10010100'				; setup   block erase
	rcall	restore_write			; execute block erase

	movlw	.128					; copy 1 block = 128 byte
	movwf	lo						; byte counter

	clrf	EEADR					; start address in EEPROM, low
	movlw	.3						; start address in EEPROM, high
	movwf	EEADRH

	TBLRD*-							; dummy read to be in 128 byte block
restore_flash_loop:
	call	read_eeprom				; read one byte from EEPROM
	incf	EEADR,F					; increment EEPROM address
	movff	EEDATA,TABLAT			; transfer byte from EEPROM read to program memory write
	tblwt+*							; execute program memory write (with pre-increment)
	decfsz	lo,F					; 128 bytes done?
	bra		restore_flash_loop		; NO - loop
	movlw	b'10000100'				; YES - setup   block write
	rcall	restore_write			;     - execute block write
	reset							;     - done, reset CPU

restore_write:
	movwf	EECON1					; type of memory to write in
	movlw	0x55
	movwf	EECON2
	movlw	0xAA
	movwf	EECON2
	bsf		EECON1,WR				; execute write
	nop
	nop
	return

	END