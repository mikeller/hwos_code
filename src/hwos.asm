;=============================================================================
;
;   File hwos.asm                           * combined next generation V3.09.4e
;
;   Definition of the hwOS dive computer platform.
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;   2011-05-24 : [jDG] Cleanups from initial Matthias code
;   2011-06-24 : [MH]  Added clock speeds

;=============================================================================

#DEFINE INSIDE_HWOS_ASM

#include "hwos.inc"
#include "eeprom_rs232.inc"

;----------------------------- PIC Configuration -----------------------------
;
	CONFIG	RETEN   = OFF		; regulator power while in sleep mode controlled by SRETEN bit
	CONFIG	SOSCSEL = HIGH		; high power SOSC circuit selected
	CONFIG	XINST   = OFF		; extended instruction set disabled
	CONFIG	FOSC    = INTIO2	; internal RC oscillator, no clock-out
	CONFIG	PLLCFG  = OFF		; oscillator used directly
	CONFIG	IESO    = OFF		; two-speed start-up disabled
	CONFIG	PWRTEN  = OFF		; power-up timer disabled, because incompatible with ICD3 (Ri-400)
	CONFIG	BOREN   = ON		; brown-out reset controlled with SBOREN bit
	CONFIG	BORV    = 2			; brown-out reset voltage 2.0V
	CONFIG	BORPWR  = MEDIUM	; brown-out monitoring set to medium power level
	CONFIG	WDTEN   = ON		; watchdog timer enabled, controlled by SWDTEN bit
	CONFIG	WDTPS   = 128		; watchdog timer post-scaler 1:128
	CONFIG	RTCOSC  = SOSCREF	; RTCC uses SOSC as ref clock
	CONFIG	MCLRE   = ON		; MCLR enabled, RG5 disabled
	CONFIG	CCP2MX  = PORTBE	; ECCP2 muxed with RE7 (micro-controller mode) /RB3 (other modes)


;---------------------------- Bank0 ACCESS RAM -------------------------------
;
ac_ram		equ			0x000
ac_ram		udata_acs	ac_ram				; access RAM data


;---- Flags - Hardware Descriptors
HW_descriptor					res 1		; OSTC - model descriptor (cleared & rebuilt in restart)
HW_variants					res 1		; OSTC - model variants   (NOT cleared in restart)
HW_variants2					res 1		; OSTC - more model variants   (NOT cleared in restart)
						
;---- Flags - Hardware States
HW_flags_state1					res 1		; hardware - states 1
HW_flags_state2					res 1		; hardware - states 2
HW_flags_state3					res 1		; hardware - states 3

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

;---- Battery Management
battery_capacity_internal		res 2		; for internal battery gauging
battery_capacity				res 2		; for battery gauge IC
battery_offset					res 2		; for battery gauge IC
battery_type					res 1		; =0:1.5V, =1:3.6V Saft, =2:LiIon 3.7V/0.8Ah, =3:LiIon 3.7V/3.1Ah, =4: LiIon 3.7V/2.3Ah
battery_accumulated_charge		res 2		; raw values in battery gauge IC
battery_temperature				res 2		; battery temperature in 0.1 Kelvin
gauge_status_byte				res 1		; gauge IC status byte



; 44 byte user data
; 32 byte tmp  data placed by C compiler
; 20 byte variables placed by math library
; ==
; 96 byte used, 0 byte free (96 byte total available)


	global	HW_descriptor
	global	HW_variants
	global	HW_variants2
	global	HW_flags_state1
	global	HW_flags_state2
	global	HW_flags_state3
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
	global	battery_capacity_internal
	global	battery_capacity
	global	battery_offset
	global	battery_type
	global	battery_accumulated_charge
	global	battery_temperature
	global	gauge_status_byte


;=============================================================================
hwos1	CODE
;=============================================================================

;-----------------------------------------------------------------------------
; Master Initialization of Hardware Resources
;
	global	init_ostc
init_ostc:

; Oscillator
	banksel	common				; select bank common
	movlw	b'01110010'			; select 16 MHz INTOSC
	movwf	OSCCON				; ...
	movlw	b'00001000'			; secondary oscillator running
	movwf	OSCCON2				; ...
	movlw	b'00000000'			; 4x PLL disable (Bit 6) - only works with 8 or 16MHz (=32 or 64MHz)
	movwf	OSCTUNE				; ...

	movlw	coding_speed_normal	; coding for normal CPU speed
	movwf	cpu_speed_request	; store CPU shall run with normal speed
	movwf	cpu_speed_state		; store CPU does  run with normal speed

	;bcf	RCON,SBOREN			; brown-out off (not needed here, is handled in bootloader)
	bcf		RCON,IPEN			; priority interrupts off

	banksel	WDTCON
	movlw	b'00010000'			; setup watchdog, put VCORE Reg into Ultra Low-Power mode in Sleep
	movwf	WDTCON				; ...


; I/O Ports
	banksel	0xF16				; addresses F16h ... F5Fh are not part of the access RAM

	clrf	REFOCON				; no reference oscillator active on REFO pin
	clrf	ODCON1				; disable open drain capability
	clrf	ODCON2				; disable open drain capability
	clrf	ODCON3				; disable open drain capability
	clrf	CM1CON				; disable comparator 1
	clrf	CM2CON				; disable comparator 2
	clrf	CM3CON				; disable comparator 3

	movlw	b'11000000'			; ANSEL0: AN7, AN6       -> analog inputs, PORTA is digital
	movwf	ANCON0				; ...
	movlw	b'00000111'			; ANSEL1: AN8, AN9, AN10 -> analog input
	movwf	ANCON1				; ...
	clrf	ANCON2

	banksel	common				; back to bank common

;	movlw	b'00000000'			; 1= input -> Data TFT_high
	clrf	TRISA				; ...
;	movlw	b'00000000'			; init port
	clrf	PORTA				; ...

	movlw	b'00000011'			; 1= input, (RB0, RB1) -> switches, RB2 -> Power_MCP, RB3 -> s8_npower, RB4 -> LED_green/rx_nreset, RB5 -> /TFT_POWER
	movwf	TRISB				; ...
	movlw	b'00111000'			; init port, rx_nreset=1 -> hard reset RX
	movwf	PORTB				; ...

	movlw	b'10011010'			; 1= input, (RC0, RC1) -> SOSC, RC2 -> TFT_LED_PWM, (RC3,RC4) -> I²C, RC5 -> MOSI_MS5541, (RC6, RC7) -> UART1
	movwf	TRISC				; ...
;	movlw	b'00000000'			; init port
	clrf	PORTC				; ...

	movlw	b'00100000'			; 1= input, RD0 -> TFT_NCS, RD1 -> TFT_RS, RD2 -> TFT_NWR, RD3 -> TFT_RD, RD4 -> MOSI_Flash, RD5 -> MISO_Flash, RD6 -> CLK_Flash, RD7 -> TFT_NRESET
	movwf	TRISD				; ...
;	movlw	b'00000000'			; init port
	clrf	PORTD				; ...

	movlw	b'00100000'			; 1= input, RE0 -> not_Power_BLE, RE1 -> Power_IR, RE2 -> CS_MCP, RE3 -> LED_blue, RE4 -> power_sw1, RE5 -> leave as input
	movwf	TRISE				; ...
	movlw	b'00010001'			; init port
	movwf	PORTE				; ...

	movlw	b'01111110'			; 1= input, (RF1, RF2, RF3, RF4, RF5) -> Analog
	movwf	TRISF				; ...
;	movlw	b'00000000'			; init port
	clrf	PORTF				; ...

	movlw	b'00000110'			; 1= input, <7:6> not implemented, RG0 -> TX3_PIEZO_CFG, , RG1 -> TX2, RG2 -> RX2, RG3 -> AN17_RSSI, RG4 -> SOSC_OUT, RG5 -> /RESET
	movwf	TRISG				; ...
	movlw	b'00000001'			; init port
	movwf	PORTG				; ...

;	movlw	b'00000000'			; 1= input -> Data TFT_low
	clrf	TRISH				; ...
;	movlw	b'00000000'			; init port
	clrf	PORTH				; ...

	movlw	b'10011011'			; 1= input, RJ4 -> vusb_in, RJ5 -> power_sw2, RJ6 -> CLK_MS5541, RJ7 -> MISO_MS5541
	movwf	TRISJ				; ...
	movlw	b'00100000'			; init port
	movwf	PORTJ				; ...


; disable Charger by default
	bsf		charge_disable		; set      charging-inhibit signal
	bcf		charge_enable		; activate charging-inhibit signal


; Timer 7 for 62.5 ms Interrupt (Sensor States)
	banksel	0xF16				; addresses F16h...F5Fh are not part of the access RAM
	clrf	T7GCON				; clear timer 7 gate control register
	movlw	b'10001101'			; bit 7-6: 10 = clock source SOSC/SCLKI (with bit   3 = 1)
								; bit 5-4: 00 = 1:1 prescaler
								; bit   3:  1 = clock source SOSC/SCLKI (with bit 7-6 = 10)
								; bit   2:  1 = DO NOT synchronize external clock input (else OSTC won't wake up from sleep!)
								; bit   1:  0 = 2x 8 bit operation
								; bit   0:  1 = timer enabled
								; 32768 Hz clock source, 1:1 prescaler -> timer counts at 30.51757813 µs/bit
	movwf	T7CON				; ...
	movlw	.248				; load timer 7, high byte (8x256 ticks -> 62.5 ms)
	movwf	TMR7H				; ...
	clrf	TMR7L				; load timer 7, low  byte


; Timer 0 - not used
	movlw	b'00000001'			; timer0 stopped (1:4 prescaler)
	movwf	T0CON				; ...


; Timer 1 - Button hold-down Timer
;	movlw	b'10001100'			; old setting
	movlw	b'10001010'			; bit 7-6: 10 = clock source SOSC/SCLKI (with bit   3 = 1)
								; bit 5-4: 00 = 1:1 prescaler
								; bit   3:  1 = clock source SOSC/SCLKI (with bit 7-6 = 10)
								; bit   2:  0 = synchronize external clock input
								; bit   1:  1 = 16 bit operation
								; bit   0:  0 = timer stopped
								; 32768 Hz clock source, 1:1 prescaler -> timer counts at 30.51757813 µs/bit
	movwf	T1CON				; ...


; RTCC
	banksel	0xF16				; addresses, F16h through F5Fh, are also used by SFRs, but are not part of the access RAM
	movlw	0x55				; unlock sequence for RTCWREN
	movwf	EECON2				; ...
	movlw	0xAA				; ...
	movwf	EECON2				; ...
	bsf 	RTCCFG,RTCWREN		; unlock access to RTC
	bsf		RTCCFG,RTCPTR1		; set pointer register to b'11'
	bsf		RTCCFG,RTCPTR0		; ..
	bsf		RTCCFG,RTCEN		; module enable
	bsf		RTCCFG,RTCOE		; output enable
	movlw	b'00000100'			; 32768 Hz SOCS on RTCC pin (PORTG,4) Bit7-5: pull-ups for Port D, E and J
	movwf	PADCFG1				; ...
	movlw	b'11000000'			; 1/2 second alarm
	movwf	ALRMCFG				; ...
	movlw	d'1'				; select alarm repeat counter to 1
	movwf	ALRMRPT				; ...
	movlw	0x55				; unlock sequence for RTCWREN
	movwf	EECON2				; ...
	movlw	0xAA				; ...
	movwf	EECON2				; ...
	bcf		RTCCFG,RTCWREN		; lock access to RTC
	banksel	common				; back to bank common


; A/D Converter
	movlw	b'00011000'			; power off ADC, select AN6
	movwf	ADCON0				; ...
	movlw	b'00100000'			; 2.048V Vref+
	movwf	ADCON1				; ...
	movlw	b'10001111'			; right aligned, 2 x T_AD acquisition time, clock derived from A/D RC oscillator (To be CPU-clock independent)
	movwf	ADCON2				; ...


; Serial Port 1 (TRISC6/7)
	movlw	b'00001000'			; switch baud generator to 16 bit mode (BRG16=1)
	movwf	BAUDCON1			; ...
								; SPBRGH:SPBRG =  .34 : 114285 BAUD @ 16MHz (+0.79% error at 115200 baud)
								; SPBRGH:SPBRG = .207 :  19230 BAUD @ 16MHz (-0.16% error at  19200 baud)
	movlw	.34					; select 114285 baud (low byte)
	movwf	SPBRG1				; ...
	clrf	SPBRGH1				; ...                (high byte)

	clrf	RCSTA1				; disable UART RX
	clrf	TXSTA1				; disable UART TX
	bcf		PORTC,6				; tie TX output hard to GND


; Serial Port 2 (TRISG2) for IR/S8 digital Interface
;
; - will be initialized by enable_ir_s8 (eeprom_rs232.asm) in case IR/S8 shall be available


; Timer 3 for IR-RX Timeout
 IFDEF _external_sensor
	clrf	T3GCON				; clear Timer3 gate control register
;	movlw	b'10001101'			; old value
	movlw	b'10001011'			; bit 7-6: 10 = clock source SOSC/SCLKI (with bit   3 = 1)
								; bit 5-4: 00 = 1:1 prescaler
								; bit   3:  1 = clock source SOSC/SCLKI (with bit 7-6 = 10)
								; bit   2:  0 = synchronize external clock input
								; bit   1:  1 = 16 bit operation
								; bit   0:  1 = timer enabled
								; 32768 Hz clock source, 1:1 prescaler -> timer counts at 30.51757813 µs/bit
	movwf	T3CON				; ...
 ENDIF


; SPI Module(s)
; SPI2: External Flash
	movlw	b'00110000'			; set up SPI module
	movwf	SSP2CON1			; ...
	clrf	SSP2STAT			; ...
								; resulting bit clocks:  0.25 MHz @  1 MHz CPU clock (Eco)
								;                        4.00 MHz @ 16 MHz CPU clock (Normal)
								;                       16.00 MHz @ 64 MHz CPU clock (Fastest)


; MSSP1 Module: I2C Master
	movlw	b'00101000'			; set up I2C to master mode
	movwf	SSP1CON1			; ...
	clrf	SSP1CON2			; ...
	movlw	i2c_speed_value
	movwf	SSP1ADD				; ...


; PWM Module(s)
; PWM 1 for LED dimming
	movlw	b'00001100'			; set up PWM module
	movwf	CCP1CON				; ...
	movlw	b'00000001'			; pulse steering disabled
	movwf	PSTR1CON			; ...
	movlw	d'254'				; select period
	movwf	PR2					; ...
	; 255 is max brightness (300 mW)
	clrf	CCPR1L				; duty cycle, low  byte
	clrf	CCPR1H				; duty cycle, high byte
	movlw	T2CON_NORMAL		; set timer for normal dimming
	movwf	T2CON				; ...


; Timer 5 for ISR-independent Wait/Timeout
	clrf	T5GCON				; clear Timer5 gate control register
;	movlw	b'10001111'			; old value
	movlw	b'10001011'			; bit 7-6: 10 = clock source SOSC/SCLKI (with bit   3 = 1)
								; bit 5-4: 00 = 1:1 prescaler
								; bit   3:  1 = clock source SOSC/SCLKI (with bit 7-6 = 10)
								; bit   2:  0 = synchronize external clock input
								; bit   1:  1 = 16 bit operation
								; bit   0:  1 = timer enabled
								; 32768 Hz clock source, 1:1 prescaler -> timer counts at 30.51757813 µs/bit
	movwf	T5CON				; ...

; Timer 4 for debounce of new digital piezo circuity
	movlw	b'01111011'			; 1:8 Postscale, Prescale = 1, Timer 4 OFF
	movwf	T4CON
	setf	PR4
	
; turn off unused Timers
	banksel 0xF16				; addresses F16h...F5Fh are not part of the access RAM
	movlw	b'11000000'			; disable ECCP3 and ECCP2
	movwf	PMD0				; ...
 IFDEF _external_sensor
	movlw	b'11000001'			; disable PSP, CTMU and EMB
 ELSE
	movlw	b'11001001'			; disable PSP, CTMU, Timer 3 and EMB
 ENDIF
	movwf	PMD1				; ...
	movlw	b'11010111'			; disable timer 10, timer 8, timer 6 and comparators 1-3
	movwf	PMD2				; ...
	movlw	b'11111111'			; disable CCP 4-10 and timer 12
	movwf	PMD3				; ...


; turn off unused CTMU
	;banksel 0xF16				; addresses F16h...F5Fh are not part of the access RAM
	clrf	CTMUCONH			; disable CTMU
	clrf	CTMUCONL			; ...
	clrf	CTMUICON			; ...


	banksel	common


; Interrupts
	bcf		PIR5,TMR7IF			; if applicable clear timer 7 IRQ flag

	movlw	b'11010000'			; enable global IRQ, peripheral IRQ and external IRQ 0
	movwf	INTCON				; ...
	movlw	b'00001000'			; external IRQ 0 on falling edge, pull-up of PORTB by TRIS register
	movwf	INTCON2				; ...
	movlw	b'00000000'			; disable external IRQs 1,2,3
	movwf	INTCON3				; ...
	movlw	b'00000001'			; enable timer 1 IRQ
	movwf	PIE1				; ...
	movlw	b'00000010'			; enable timer 3 IRQ
	movwf	PIE2				; ...
	movlw	b'00000001'			; enable RTCC IRQ
	movwf	PIE3				; ...
	movlw	b'00001001'			; enable timer 7 and timer 4 IRQ
	movwf	PIE5				; ...

; Release RESET from RX Circuitry
	bcf		active_reset_ostc_rx

; Power-up the Switches
	;bra	power_up_switches


;-----------------------------------------------------------------------------
; Power-up the Switches
;
	global	power_up_switches
power_up_switches:
	bsf		power_sw1			; switch on power supply for switch 1
	btfss	power_sw1			; power established?
	bra		$-4					; NO - wait

	bsf		power_sw2			; switch on power supply for switch 2
	btfss	power_sw2			; power established?
	bra		$-4					; NO - wait

	return						; done


;=============================================================================
hwos2	CODE
;=============================================================================

;-----------------------------------------------------------------------------
; CPU Speed Change Requests
;
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
hwos3	CODE
;=============================================================================

;-----------------------------------------------------------------------------
; Backup the first 128 bytes from program FLASH to EEPROM
;
	global	backup_flash_page
backup_flash_page:
	banksel	common

	; set start address in internal program FLASH
	movlw	0x00					; set 0x000000
	movwf	TBLPTRL					; ...
	movwf	TBLPTRH					; ...
	movwf	TBLPTRU					; ...
	TBLRD*-							; dummy read to be in 128 byte block

	; set start address in EEPROM
	EEPROM_SET_ADDRESS eeprom_prog_page0_backup

	movlw	.128					; copy 1 block = 128 byte
	movwf	eeprom_loop				; initialize loop counter
backup_flash_loop:
	tblrd+*							; read one byte from program FLASH (with pre-increment)
	movff	TABLAT,EEDATA			; transfer byte from program FLASH read to EEPROM write
	call	write_eeprom			; execute   EEPROM write
	incf	EEADR,F					; increment EEPROM address
	decfsz	eeprom_loop,F			; all 128 byte done?
	bra		backup_flash_loop		; NO  - loop
	return							; YES - done


;=============================================================================
hwos4	CODE
;=============================================================================

;-----------------------------------------------------------------------------
; Restore the first 128 bytes from EEPROM to program FLASH
;
	global	restore_flash
restore_flash:
	banksel	common

	;set start address in internal program FLASH
	movlw	0x00					; set 0x000000
	movwf	TBLPTRL					; ...
	movwf	TBLPTRH					; ...
	movwf	TBLPTRU					; ...
	TBLRD*-							; dummy read to be in 128 byte block

	movlw	b'10010100'				; setup   block erase
	rcall	restore_write			; execute block erase

	; set start address in EEPROM
	EEPROM_SET_ADDRESS eeprom_prog_page0_backup

	movlw	.128					; copy 1 block = 128 byte
	movwf	eeprom_loop				; initialize loop counter
restore_flash_loop:
	call	read_eeprom				; execute   EEPROM read
	incf	EEADR,F					; increment EEPROM address
	movff	EEDATA,TABLAT			; transfer byte from EEPROM read to program FLASH write
	tblwt+*							; execute program FLASH write (with pre-increment)
	decfsz	eeprom_loop,F			; all 128 bytes done?
	bra		restore_flash_loop		; NO  - loop
	movlw	b'10000100'				; YES - setup   block write
	rcall	restore_write			;     - execute block write
	reset							;     - done, reset CPU

restore_write:
	movwf	EECON1					; configure operation
	movlw	0x55					; unlock sequence
	movwf	EECON2					; ...
	movlw	0xAA					; ...
	movwf	EECON2					; ...
	bsf		EECON1,WR				; execute operation
	nop								; wait for operation to complete
	nop								; ...
	return							; done


;=============================================================================
hwos5	CODE
;=============================================================================

;-----------------------------------------------------------------------------
; Memory clear and move Functions, to be used via Macros
;
	global	memory_clear
memory_clear:
	clrf	POSTINC1				; clear address
	decfsz	WREG					; decrement loop counter, became zero?
	bra		memory_clear			; NO  - loop
	return							; YES - done

	global	memory_move
memory_move:
	movff	POSTINC1,POSTINC2		; copy from-to
	decfsz	WREG					; decrement loop counter, became zero?
	bra		memory_move				; NO  - loop
	return							; YES - done


;=============================================================================
hwos6	CODE
;=============================================================================

;-----------------------------------------------------------------------------
; Read CPU Silicon Version
;
	global	get_cpu_version
get_cpu_version:
	movlw	0xFE					; select address 0x3FFFFE
	movwf	TBLPTRL					; ...
	movlw	0xFF					; ...
	movwf	TBLPTRH					; ...
	movlw	0x3F					; ...
	movwf	TBLPTRU					; ...
	TBLRD*+							; read DEVID1 byte
	movlw	b'00011111'				; load mask for silicon version
	andwf	TABLAT,W				; apply mask and store result in WREG 
	return							; done

;-----------------------------------------------------------------------------

	END
