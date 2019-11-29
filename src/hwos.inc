;=============================================================================
;
;   File hwos.inc                             combined next generation V3.06.2
;
;   OSTC Platform Definitions
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;   2011-05-24 : [jDG] Cleanups from initial Matthias code
;=============================================================================


; Hardware Configuration
	LIST P=18F87K22							; compiler  settings, if changed change also: Configure -> SelectDevice in MPLAB
#include "p18f87k22.inc"					; processor definitions
#include "ports.inc"						; port map  definitions


; Software Configuration
#include "configuration.inc"				; OSTC hwOS configuration


; Language Codes
#DEFINE none					0			; no language selected
#DEFINE en						1			; select English
#DEFINE de						2			; select German
#DEFINE fr						3			; select French
#DEFINE it						4			; select Italian


; Magic Cookie Definition
#DEFINE comm_service_key		0xABCDEF	; simsalabim to establish data connection


; Logo Address Vectors
#DEFINE hw_logo_block			0x01E000	; color image data for heinrichsweikamp logo
#DEFINE usb_ble_logo_1			0x01EEDE	; color image data for USB or BLE logo
#DEFINE usb_ble_logo_2			0x01EA04	; color image data for USB or BLE logo, "+" bootloader


;-----------------------------EEPROM DATA ------------------------------------
; Automatic reset of all options when this is changed:
#DEFINE eeprom_opt_serial		0x0008		; Version 0.8
;-----------------------------------------------------------------------------


#DEFINE CCP1CON_VALUE					b'00001100'	; PWM1 for LED dimming
#DEFINE T2CON_ECO						b'01111110'
#DEFINE T2CON_NORMAL					b'01111110'
#DEFINE T2CON_FASTEST					b'01111110'


; CPU speeds
#DEFINE coding_speed_eco				.1			;  1 MHz = eco     speed
#DEFINE coding_speed_normal				.2			; 16 MHz = normal  speed
#DEFINE coding_speed_fastest			.4			; 64 MHz = fastest speed (32 MHz on OSTC Sport BLE)

#DEFINE speed_is_eco			cpu_speed_state,0	; =1: CPU is running at eco     speed
#DEFINE speed_is_normal			cpu_speed_state,1	; =1: CPU is running at normal  speed
#DEFINE speed_is_fastest		cpu_speed_state,2	; =1: CPU is running at fastest speed


; Divemode Custom View Indexes - Attention: these numbers need to be in line with the jump tables in customview.asm!
#DEFINE index_avr_stopwatch				 .1			; average depth and stopwatch
#DEFINE index_compass_dm				 .2			; compass
#DEFINE index_ppo2_sensors				 .3			; ppO2 sensors
#DEFINE index_sensor_check				 .4			; sensor check
#DEFINE index_pscr_info					 .5			; pSCR data
#DEFINE index_pressures_SAC				 .6			; tank pressure and SAC rate
#DEFINE index_gas_needs_ascent			 .7			; gas needs for ascent / cave return
#DEFINE index_decoplan					 .8			; deco plan
#DEFINE index_ceiling_GF_tissue			 .9			; ceiling, current GF and tissues
#DEFINE index_CNS						.10			; CNS values
#DEFINE index_ppo2_ead_end_cns			.11			; ppO2, END/EAD and CNS or gas density
#DEFINE index_gf_factors				.12			; GF factors
#DEFINE index_clock_batt_surfpress		.13			; clock, battery and surface pressure
#DEFINE index_cv_dm_max					.13			; highest index in use in dive mode custom view


; Timing for button hold-down flags
#DEFINE TMR1H_VALUE_FIRST				.255-.128	; in steps of 7.8125 ms -> 1    s
#DEFINE TMR1H_VALUE_CONT				.255-.32	; in steps of 7.8125 ms -> 0.25 s
#DEFINE TMR1H_VALUE_CONT_DIVE			.255-.64	; in steps of 7.8125 ms -> 0.5  s


; Color Definitions: 8 bit RGB b'RRRGGGBB'
#DEFINE color_red						b'11100000'	; (7,0,0)
#DEFINE color_dark_red					b'10000101'	; (4,1,1)
#DEFINE color_violet					b'11101011'	; (7,2,3)
#DEFINE color_blue						b'11000111'	; (6,1,3)
#DEFINE color_green						b'00011100'	; (0,7,0)
#DEFINE color_greenish					b'00111110'	; (1,7,2)
#DEFINE color_dark_green				b'00111001'	; (1,6,1)
#DEFINE color_yellow					b'11111101'	; (7,7,1)
#DEFINE color_white						b'11111111'	; (7,7,3)
#DEFINE color_black						b'00000000'	; (0,0,0)
#DEFINE color_deepblue					b'00000010'	; (0,0,2)
#DEFINE color_grey						b'11011111'	; (6,7,3)
#DEFINE color_cyan						b'11011111'	; (6,7,3)
#DEFINE color_lightblue					b'11011011'	; (6,7,3)
#DEFINE color_orange					b'11111000'	; (7,6,0)
#DEFINE color_pink						b'11111010'	; (7,6,2)


; Font Sizes
#DEFINE FT_TINY							.0			; aa_font16_block, full character set
#DEFINE FT_SMALL						.1			; aa_font28_block, full character set
#DEFINE FT_STANDARD						.2			; aa_font34_block, full character set
#DEFINE FT_MEDIUM						.3			; aa_font48_block, only digits, /, ., :, ;, <, =, > and ?
#DEFINE FT_LARGE						.4			; aa_font90_block, only digits, / and .
#DEFINE FT_HUGE							.5			; aa_font92_block, only digits, / and .


; External O2 cell input Parameters
#DEFINE min_mv							.70			; =   7 mV
#DEFINE max_mv							.2500		; = 250 mV
#DEFINE ignore_mv						.3500		; = 350 mV (to suppress ghost readings for long, open cables)


; Profile Recording Parameters
#DEFINE logbook_profile_version			0x24
#DEFINE samplingrate_apnoe				.1			; [seconds]


; Profile Recording Rates - Attention: all Divisors must be < 16 !
#DEFINE div_temperature					.6			; x sampling rate [s]
#DEFINE div_deco						.6			; x sampling rate [s]
#DEFINE div_gf							.12			; x sampling rate [s]
#DEFINE div_ppo2_sensors				.2			; x sampling rate [s]
#DEFINE div_decoplan					.12			; x sampling rate [s]
#DEFINE div_cns							.12			; x sampling rate [s]
#DEFINE div_tank						.12			; x sampling rate [s]


; Profile Recording Data - Attention: Information Lengths must be < 16 !
#DEFINE infolength_temperature			.2			; [byte]
#DEFINE infolength_deco					.2			; [byte]
#DEFINE infolength_gf					.1			; [byte]
#DEFINE infolength_ppo2_sensors			.9			; [byte]
#DEFINE infolength_decoplan				.15			; [byte]
#DEFINE infolength_cns					.2			; [byte]
#DEFINE infolength_tank					.2			; [byte]


; RX Functions
#DEFINE rx_packet_overdue_timeout		.120		; [seconds] timeout for pressure measurements becomming declared as outdated (max. 255)
#DEFINE max_pres_diff_min				.5			; [bar] minimum selectable pressure difference for ind.double mode
#DEFINE max_pres_diff_max				.50			; [bar] maximum selectable pressure difference for ind.double mode


 IFDEF _ccr_pscr
#DEFINE tr_pres_options					.15			; number of options for pressure measurement source / with diluents
 ELSE
#DEFINE tr_pres_options					.6			; number of options for pressure measurement source / OC gases only
 ENDIF

; Cave Mode 
 IFDEF _cave_mode
#DEFINE calc_gas_options				.3			; 3 options: off, on, cave
 ELSE
#DEFINE calc_gas_options				.2			; 2 options: off, on
 ENDIF


; Gas Needs Settings
#DEFINE min_tank_size					.1			; [liter]
#DEFINE max_tank_size					.40			; [liter]
#DEFINE min_fill_press					.5			; [0 bar] value is in multiples of 10 bar
#DEFINE max_fill_press					.29			; [0 bar] value is in multiples of 10 bar, no 300 bar due to too far beyond ideal gas laws


; Timeouts for Menus
#DEFINE surfmode_timeout_default		.90			; [s] default timeout for surface mode and surface menus
#DEFINE surfmode_timeout_simulator		.240		; [s] special timeout for simulator (deco calculator) mode
#DEFINE surfmode_timeout_sensor			.240		; [s] special timeout for surface mode when in CCR/pSCR sensor mode
#DEFINE surfmode_timeout_calibrate		.240		; [s] special timeout when in surface CCR calibrate sensors menu
#DEFINE surfmode_timeout_xmitter		.240		; [s] special timeout when in surface transmitter pairing menu

#DEFINE divemode_timeout_premenu		.10			; [s] timeout for dive mode pre-menu
#DEFINE divemode_timeout_mainmenu		.30			; [s] timeout for dive mode main menu


; other Timeouts
#DEFINE simulator_timeout				.15			; [s]
#DEFINE apnoe_timeout					.15			; [min]
#DEFINE	deep_sleep_10mins				.144		; [x 10mins] (24h in this example)

; Surface Mode Thresholds and Limits
#DEFINE high_altitude_threshold			.880		; [mbar] ambient pressure at which to switch into high altitude mode
#DEFINE max_surfpressure				.1030		; [mbar] maximum value for internal surface pressure


; Dive Mode Thresholds and Limits
#DEFINE wake_up_from_sleep				.1160		; [mbar] absolute pressure at which to switch from sleep mode to surface / dive mode
#DEFINE dive_threshold_norm_alt_start	 .125		; [mbar] relative pressure for normal altitude start-of-dive (equals depth in cm)
#DEFINE dive_threshold_norm_alt_end		  .75		; [mbar] relative pressure for normal altitude   end-of-dive (equals depth in cm)
#DEFINE dive_threshold_high_alt_start	 .325		; [mbar] relative pressure for high   altitude start-of-dive (equals depth in cm)
#DEFINE dive_threshold_high_alt_end		  .75		; [mbar] relative pressure for high   altitude   end-of-dive (equals depth in cm)
#DEFINE ostc_depth_max					 .120		; [m]    maximum allowed operational depth for OSTC 2, 3, cR, TR, Plus & Sport
#DEFINE deco_region_distance			   .2		; [m]    distance below first stop for the deco region to begin


; Dive Mode Margins
#DEFINE ppO2_margin_on_max				.300		; [0.1 mbar] extra margin on ppO2 max values to compensate for surface pressures > 1000 hPa
#DEFINE sensor_voting_logic_threshold	.10			; threshold in 0.01 bar


; ppO2 Limits
#DEFINE ppo2_warning_low_lowest			.15			; [cbar] minimum value for minimum ppO2 on OC
#DEFINE ppo2_warning_low_default		.17			; [cbar] default value for minimum ppO2 on OC
#DEFINE ppo2_warning_low_highest		.21			; [cbar] maximum value for minimum ppO2 on OC

#DEFINE ppo2_warning_loop_lowest		.20			; [cbar] minimum value for minimum ppO2 on loop
#DEFINE ppo2_warning_loop_default		.40			; [cbar] default value for minimum ppO2 on loop
#DEFINE ppo2_warning_loop_highest		.60			; [cbar] maximum value for minimum ppO2 on loop

#DEFINE ppo2_warning_high_lowest		.120		; [cbar] minimum value for maximum ppO2 in none-deco phase
#DEFINE ppo2_warning_deco_lowest		.120		; [cbar] minimum value for maximum ppO2 in deco phase

#DEFINE ppo2_warning_high_default		.140		; [cbar] default value for maximum ppO2 in none-deco phase
#DEFINE ppo2_warning_deco_default		.160		; [cbar] default value for maximum ppO2 in deco phase

 IFDEF _high_ppO2_max
#DEFINE ppo2_warning_high_highest		.200		; [cbar] maximum value for maximum ppO2 in none-deco phase
#DEFINE ppo2_warning_deco_highest		.200		; [cbar] maximum value for maximum ppO2 in deco phase
 ELSE
#DEFINE ppo2_warning_high_highest		.160		; [cbar] maximum value for maximum ppO2 in none-deco phase
#DEFINE ppo2_warning_deco_highest		.160		; [cbar] maximum value for maximum ppO2 in deco phase
 ENDIF


; Color-Code Parameters for the Dive Mode
#DEFINE color_code_velocity_warn_high	.11			; [m/min]
#DEFINE color_code_velocity_attn_high	.10			; [m/min]
#DEFINE velocity_display_threshold		.3			; [m/min]


; Simulator Parameters
#DEFINE simulator_startdepth			.200		; [mbar] initial depth (relative pressure) when entering simulator mode
#DEFINE simulator_descent_threshold		.50			; [mbar] remaining distance to target pressure when to slow down descent
#DEFINE simulator_ascent_threshold		.50			; [mbar] remaining distance to target pressure when to slow down ascent
#DEFINE simulator_descent_rate			.5			; [mbar/0.125 sec] normal descent speed, 5 equals 24 m/min
#DEFINE simulator_ascent_rate			.2			; [mbar/0.125 sec] normal ascent  speed, 2 equals  9 m/min


; Battery Thresholds
#DEFINE max_battery_charge_temp			.3231		; [0.1 Kelvin] max allowed battery temperature during charging (equals 50°C)
#DEFINE lithium_36v_empty				.2400		; [mV] Saft 3.6 V LS14500 AA - threshold for battery percent display
#DEFINE lithium_36v_low					.2000		; [mV] Saft 3.6 V LS14500 AA - lowest  possible voltage, value must be higher than value of aa_15v_high!
#DEFINE aa_15v_high						.1550		; [mV] Energizer 1.5 V E2 AA - highest possible voltage, value must be lower  than value of lithium_36v_low!
#DEFINE aa_15v_low						.1100		; [mV] Energizer 1.5 V E2 AA - lowest  possible voltage, according to Energizer data sheet EBC-4201R, page 2
#DEFINE battery_show_level				.30			; [%]  threshold when to show battery level
#DEFINE battery_warn_level_36			.15			; [%]  threshold for 3.6 V battery warning, also acts as threshold for setting display brightness level to ECO when in dive mode
#DEFINE battery_warn_level_15			.25			; [%]  threshold for 1.5 V battery warning, also acts as threshold for setting display brightness level to ECO when in dive modebattery warning level, also acts as threshold for setting display brightness level to ECO when in dive mode


; 3.6 Volt Battery Sensing Data Points at 70 mA Load
#DEFINE lithium_36v_75					.3000		; [mV]
#DEFINE lithium_36v_50					.2900		; [mV]
#DEFINE lithium_36v_25					.2600		; [mV]
#DEFINE lithium_36v_10					.2500		; [mV]


; Capacity for 2.4 Ah Saft LS14500 and 0.8 Ah Panasonic UR14500P
; battery_gauge: 6 is nAs
; devide through 65536
;    a) devide through 364 -> result is in percent of a 2.4 Ah battery
; or b) devide through 121 -> result is in percent of a 0.8 Ah battery


; internal Battery Gauging
#DEFINE capacity_saft_internal			.364
#DEFINE capacity_panasonic_internal		.121


; Gauge IC
#DEFINE capacity_saft					.281		; 2.4Ah/0.085mAh/100 [%]
#DEFINE offset_saft						.37300		; 65536-(2.4Ah/0.085mAh)

#DEFINE capacity_panasonic				.94			; 0.8Ah/0.085mAh/100 [%]
#DEFINE offset_panasonic				.56124		; 65536-(0.8Ah/0.085mAh)

#DEFINE capacity_ncr18650				.364		; 3.1Ah/0.085mAh/100 [%]
#DEFINE offset_ncr18650					.29065		; 65536-(3.1Ah/0.085mAh)

#DEFINE capacity_ur16650				.271		; 2.3Ah/0.085mAh/100 [%]
#DEFINE offset_ur16650					.38477		; 65536-(2.3Ah/0.085mAh)


; Power Consumption Values
#DEFINE current_sleepmode				.31
#DEFINE current_backlight_multi			.115		; * CCPR1L + current_backlight_offset (restricted to  <= 255)
#DEFINE current_backlight_offset		.216
#DEFINE current_speed_eco				.1914
#DEFINE current_speed_normal			.4027
#DEFINE current_speed_fastest			.5050
#DEFINE current_ir_receiver				.139
#DEFINE current_compass					.28


; Brightness Thresholds (between zero (off) and 255 (max. power consumption))
#DEFINE ambient_light_max_high_36V		.170
#DEFINE ambient_light_max_high_cr		.240
#DEFINE ambient_light_max_high_15V		.140
#DEFINE ambient_light_min_high			.35
#DEFINE ambient_light_max_medium		.125
#DEFINE ambient_light_min_medium		.25
#DEFINE ambient_light_max_eco			.70
#DEFINE ambient_light_min_eco			.10			; must be the lowest value!


; IR Link Timeout
#DEFINE ir_timeout_value				.128			; in multiples of 62.5 ms


; Setpoint Control
#DEFINE surface_sp						.50			; in cbar


; Gaslist hard-coded Limits
 IFDEF _helium
#DEFINE gaslist_min_o2					.7			; minimum O2 [%] ( 7% is minimum value to keep MOD < 255 meters / 1 Byte)
#DEFINE gaslist_max_He			.100-gaslist_min_o2 ; maximum He [%]
#DEFINE gaslist_max_change_depth		.220		; max. change depth [m] (219 is maximum value that can be produced by gaslist_calc_mod with 7% O2)
#DEFINE tissue_graphics_options			.2			; tissue graphics "Pres+Sat" and "N2+He" available
 ELSE
#DEFINE gaslist_min_o2					.21			; minimum O2 [%]
#DEFINE gaslist_max_He					.0			; maximum He [%]
#DEFINE gaslist_max_change_depth		.70			; max. change depth [m] (67 is maximum value that can be produced by gaslist_calc_mod with 21% O2)
#DEFINE tissue_graphics_options			.1			; tissue graphics "Pres+Sat" only available
 ENDIF


; Setpoint list hard-coded Limits
#DEFINE gaslist_sp_stepsize				.10			; steps for setpoint setup [cbar]
#DEFINE gaslist_sp_max					.160		; max. setpoint [cbar]
#DEFINE gaslist_sp_min					.50			; min. setpoint [cbar]


; Compass Display
#DEFINE compass_fast_treshold			.9			; show new heading instantly if angular difference > compass_fast_treshold, else show animated turning of compass rose
#DEFINE compass_averaging				.10			; number of averaging cycles


; Bit Flags for Communication with p2_deco.c - char_O_main_status
#DEFINE DECO_VOLUME_FLAG				.0			; =1: calculate gas needs
#DEFINE DECO_BOTTOM_FLAG				.1			; =1: calculate gas needs for full bottom segment, =0: ...for extra time only
#DEFINE DECO_CAVE_MODE					.2			; =1: calculate ascent and gas needs using backtracking data
#DEFINE DECO_Z_FACTOR_FLAG				.3			; =1: calculate with Z factor when converting gas volumes <-> pressures
#DEFINE DECO_TR_FUNCTIONS				.4			; =1: calculate TR functions (pressure readings)
#DEFINE DECO_EXTENDED_STOPS				.5			; =1: place gas changes also below 1st stop depth
#DEFINE DECO_MODE_LOOP_FLAG				.6			; =1: calculate real tissues in loop mode (CCR or pSCR)
#DEFINE DECO_MODE_PSCR_FLAG				.7			; =1: calculate real tissues in pSCR mode (loop flag needs to be set, too)


; Bit Flags for Communication with p2_deco.c - char_O_deco_status
#DEFINE DECO_START_NORM					.0			; =1: write: start calculation of a  normal      deco plan
#DEFINE DECO_START_ALT					.1			; =1: write: start calculation of an alternative deco plan
#DEFINE DECO_COMPLETED_NORM				.0			; =1: read:  calculation of a  normal      deco plan has completed
#DEFINE DECO_COMPLETED_ALT				.1			; =1: read:  calculation of an alternative deco plan has completed
#DEFINE DECO_INITIALIZE					.2			; =1: write: initialize deco engine (to be done only once at the begin of every dive)
#DEFINE DECO_CALCULATOR_MODE			.3			; =1: deco engone is run from the deco calculator
#DEFINE DECO_BAILOUT_FLAG				.4			; =1: allow gas switches before first deco stop (used in bailout plans)
#DEFINE DECO_ASCENT_FLAG				.5			; =1: figure in a delayed ascent (fTTS)
;       DECO_MODE_LOOP_FLAG				.6			; =1: calculate simulated tissues in loop mode (CCR or pSCR)
;       DECO_MODE_PSCR_FLAG				.7			; =1: calculate simulated tissues in pSCR mode (loop flag needs to be set, too)


; Bit Flags for Communication with p2_deco.c - char_O_deco_warnings
#DEFINE IBCD_warning					.0			; =1: IBCD currently occuring
#DEFINE IBCD_warning_lock				.1			; =1: IBCD occured durign the dive
#DEFINE mbubble_warning					.2			; =1: microbubbles potentionally currently occuring
#DEFINE mbubble_warning_lock			.3			; =1: microbubbles potentionally occured during the dive
#DEFINE outside_warning					.4			; =1: currently outside the ZHL-16 model
#DEFINE outside_warning_lock			.5			; =1: was outside the ZHL-16 model during the dive
#DEFINE outside_attention				.6			; =1: currently near to the limits of the ZHL-16 model
#DEFINE deco_plan_incomplete			.7			; =1: internal error: deco calculation incomplete


; Bit Flags for Communication with p2_deco.c - char_O_deco_info
#DEFINE deco_mode						.0			; =1: in deco mode, deco ppO2 levels permitted
#DEFINE ind_double_switch				.1			; =1: switch to other tank advice active
;										.2			; --- unused
#DEFINE deco_zone						.3			; =1: fTTS is <= TTS (not updated when in bailout mode)
#DEFINE deco_ceiling					.4			; =1: ceiling depth > 0
#DEFINE deco_stops						.5			; =1: deco stops found
#DEFINE gas_needs_cave					.6			; =1: indicated gas needs are calculated in cave mode
;										.7			; --- unused


; Bit Flags for Status on Variables of Type char
#DEFINE char_transmitter_lost			.6
#DEFINE char_invalid_flag				.7
#DEFINE char_transmitter_low_bat		.7


; Bit Flags for Status on Variables of Type int (Flags are placed in the upper byte)
#DEFINE int_invalid_flag				.2
#DEFINE int_not_yet_computed			.3
#DEFINE int_is_zero						.3
#DEFINE int_low_flag					.4
#DEFINE int_not_avail_flag				.4
#DEFINE int_high_flag					.5
#DEFINE int_outdated_flag				.5
#DEFINE int_attention_flag				.6
#DEFINE int_warning_flag				.7


;-----------------------------------------------------------------------------
; Timebase and Eventbase (stored in access RAM, set by the ISR, trigger flags to be cleared by the application)

#DEFINE timebase_0sec			timebase,0			; counting timebase, 1/2 sec bit
#DEFINE timebase_1sec			timebase,1			; counting timebase,  1  sec bit
#DEFINE timebase_2sec			timebase,2			; counting timebase,  2  sec bit
#DEFINE trigger_quarter_second	timebase,3			; =1: a new 1/4 second has begun (not synced with the other time flags, not generated while block_sensor_interrupt is set)
#DEFINE trigger_half_second		timebase,4			; =1: a new 1/2 second has begun
#DEFINE trigger_full_second		timebase,5			; =1: a new 1/1 second has begun
#DEFINE trigger_full_minute		timebase,6			; =1: a new     minute has begun
#DEFINE trigger_full_hour		timebase,7			; =1: a new     hour   has begun

#DEFINE trigger_isr_updates		 eventbase,0		; =1: the ISR had kicked in (set by ISR, used by ISR-safe copy macros)
#DEFINE trigger_timeout			 eventbase,1		; =1: timeout signal by timeout service
#DEFINE trigger_sample_divedata	 eventbase,2		; =1: time to store a new sample
#DEFINE trigger_S8_data_update	 eventbase,3		; =1: new S8 digital   data  are available
#DEFINE trigger_pres_update		 eventbase,4		; =1: new pressure     value is  available
#DEFINE trigger_pres_cur_changed eventbase,5		; =1: current pressure value has changed
#DEFINE trigger_pres_max_changed eventbase,6		; =1: maximum pressure value has changed
#DEFINE trigger_temp_changed	 eventbase,7		; =1: temperature      value has changed


;-----------------------------------------------------------------------------
; Flags - stored in access RAM

;---- Hardware - OSTC Model Descriptor (stored in access RAM, cleared & rebuilt in restart, to preserve compatibility with 3rd party tools DO NOT alter bit positions)
#DEFINE battery_gauge_available	HW_descriptor,0		; =1: OSTC has rechargeable battery with battery management chip
#DEFINE ambient_sensor			HW_descriptor,1		; =1: OSTC has an ambient light sensor
#DEFINE analog_o2_input			HW_descriptor,2		; =1: OSTC has analog inputs and S8 digital
#DEFINE optical_input			HW_descriptor,3		; =1: OSTC has an digital optical input
#DEFINE ble_available			HW_descriptor,4		; =1: OSTC has an BLE module
#DEFINE ostc_rx_present			HW_descriptor,5		; =1: OSTC has RX module
#DEFINE lv_core					HW_descriptor,6		; =1: OSTC has low-voltage core (2.7V)
;								HW_descriptor,7		; --- reserved

;---- Hardware - OSTC Model Variants (stored in access RAM, NOT cleared in restart)
#DEFINE screen_type1			HW_variants,0		; =1: display type 1, =0; display type 0
#DEFINE screen_type2			HW_variants,1		; =1: display type 2, =0: display type 0 or 1
#DEFINE screen_type3			HW_variants,2		; =1: display type 3, =0: display type 0 or 1 or 2
#DEFINE compass_type1			HW_variants,3		; =1: compass type 1, =0: compass type 0
#DEFINE compass_type2			HW_variants,4		; =1: compass type 2, =0: compass type 0 or 1
#DEFINE compass_type3			HW_variants,5		; =1: compass type 3, =0: compass type 0 or 1 or 2
#DEFINE analog_switches			HW_variants,6		; =1: analog switches available
#DEFINE battery_is_36v			HW_variants,7		; =1: a 3.6 Volt battery is detected


;---- Hardware - States 1 (stored in access RAM, cleared on restart)
#DEFINE analog_sw1_pressed		HW_flags_state1,0	; =1: analog switch 1 pressed
#DEFINE analog_sw2_pressed		HW_flags_state1,1	; =1: analog switch 2 pressed
#DEFINE switch_left				HW_flags_state1,2	; =1: left  button was pressed
#DEFINE switch_right			HW_flags_state1,3	; =1: right button was pressed
#DEFINE flip_screen				HW_flags_state1,4	; =1: screen is shown 180° turned
#DEFINE adc_is_running			HW_flags_state1,5	; =1: the ADC is in use
#DEFINE tft_is_dimming			HW_flags_state1,6	; =1: the TFT is dimming, ignore light sensor
#DEFINE compass_enabled			HW_flags_state1,7	; =1: the compass and accelerometer chip is active

;---- Hardware - States 2 (stored in access RAM, NOT cleared on restart)
#DEFINE cc_active				HW_flags_state2,0	; =1: constant current charging active (cR hardware only)
#DEFINE cv_active				HW_flags_state2,1	; =1: constant voltage charging active (cR hardware only)
;								HW_flags_state2,2	; --- unused
;								HW_flags_state2,3	; --- unused
;								HW_flags_state2,4	; --- unused
;								HW_flags_state2,5	; --- unused
;								HW_flags_state2,6	; --- unused
;								HW_flags_state2,7	; --- unused


;---- Operating System - persistent Settings (stored in access RAM, NOT cleared in restart)
#DEFINE sensor1_calibrated_ok	OS_flags_persist,0	; =1: sensor 1 calibration ok
#DEFINE sensor2_calibrated_ok	OS_flags_persist,1	; =1: sensor 2 calibration ok
#DEFINE sensor3_calibrated_ok	OS_flags_persist,2	; =1: sensor 3 calibration ok
#DEFINE compass_bearing_set		OS_flags_persist,3	; =1: compass bearing is set
#DEFINE use_old_batt_flag		OS_flags_persist,4	; =1: load old battery data after power-on reset
#DEFINE option_repaired			OS_flags_persist,5	; =1: options have been repaired
#DEFINE restart_fast			OS_flags_persist,6	; =1: skip logos and waits on restart
#DEFINE battery_overtemp		OS_flags_persist,7	; =1: battery charging temperature limit exceeded


;---- Operating System - ISR Control 1 (stored in access RAM)
#DEFINE reset_timebase			OS_flags_ISR1,0		; =1: request ISR to reset the timebase for the trigger flags
#DEFINE reset_timeout			OS_flags_ISR1,1		; =1: request ISR to reset the timeout timer
#DEFINE reset_max_pressure		OS_flags_ISR1,2		; =1: request ISR to reset the maximum pressure to zero
#DEFINE reset_surface_interval	OS_flags_ISR1,3		; =1: request ISR to reset the surface interval to zero
#DEFINE reset_trip_pressure		OS_flags_ISR1,4		; =1: request ISR to reset the resettable min/max pressure
#DEFINE block_rtc_access		OS_flags_ISR1,5		; =1: suspend the ISR from accessing the RTC
#DEFINE block_battery_gauge		OS_flags_ISR1,6		; =1: suspend the ISR from updating the battery gauge
#DEFINE block_sensor_interrupt	OS_flags_ISR1,7		; =1: suspend the ISR from executing sensor interrupts

;---- Operating System - ISR Control 2 (stored in access RAM)
#DEFINE update_surface_pressure	OS_flags_ISR2,0		; =1: request ISR to update the surface pressure
#DEFINE quit_simulatormode		OS_flags_ISR2,1		; =1: request ISR to quit the simulator mode
#DEFINE count_divetime			OS_flags_ISR2,2		; =1: request ISR to count the dive time
#DEFINE sensor_override_request	OS_flags_ISR2,3		; =1: request ISR to override the pressure sensor with a simulated depth
;								OS_flags_ISR2,4		; --- unused
;								OS_flags_ISR2,5		; --- unused
#DEFINE sensor_override_active	OS_flags_ISR2,6		; =1: ISR output:    switch to override-mode confirmed
#DEFINE divetime_longer_1min	OS_flags_ISR2,7		; =1: ISR output:    dive time is >= one minute


;---- Operating Modes (stored in access RAM, persistent)
#DEFINE sleepmode				OM_flags_mode,0		; =1: in sleep mode
#DEFINE divemode				OM_flags_mode,1		; =1: in dive mode
#DEFINE simulatormode			OM_flags_mode,2		; =1: in simulator mode
#DEFINE high_altitude_mode		OM_flags_mode,3		; =1: unit was manually turned on with absolute pressure < 880 mbar
#DEFINE s8_digital_avail		OM_flags_mode,4		; =1: S8 digital interface is available
#DEFINE tr_functions_activated	OM_flags_mode,5		; =1: TR module is available and TR mode is <> off
#DEFINE cold_start				OM_flags_mode,6		; =1: restart is entered from a cold start
 IFDEF _screendump
#DEFINE screen_dump_avail		OM_flags_mode,7		; =1: screen dump function is available
 ELSE
#DEFINE comm_mode_disabled		OM_flags_mode,7		; =1: COMM mode is disabled
 ENDIF


;---- Dive Modes - Deco Modes (stored in access RAM)
#DEFINE FLAG_oc_mode			DM_flags_deco,0		; =1: in OC mode active
#DEFINE FLAG_ccr_mode			DM_flags_deco,1		; =1: in CCR mode (fixed ppO2 or sensor) active
#DEFINE FLAG_gauge_mode			DM_flags_deco,2		; =1: in gauge mode
#DEFINE FLAG_apnoe_mode			DM_flags_deco,3		; =1: in apnoe mode
#DEFINE FLAG_pscr_mode			DM_flags_deco,4		; =1: in pSCR mode
#DEFINE bailout_mode			DM_flags_deco,5		; =1: in bailout mode
#DEFINE apnoe_at_surface		DM_flags_deco,6		; =1: at the surface, 0= submerged (apnoe mode only, set/reset by ISR)
#DEFINE apnoe_new_dive			DM_flags_deco,7		; =1: a new dive has begun         (apnoe mode only, set       by ISR)


;-----------------------------------------------------------------------------
; Flags - stored in bank common

;---- Dive Mode - Dive States
#DEFINE use_aGF					DM_flags_state,0	; =1: use aGF, =0: use GF
#DEFINE sp_fallback				DM_flags_state,1	; =1: fall-back to SP1 due to external O2 sensor failure
#DEFINE dive_turned				DM_flags_state,2	; =1: dive is turned
#DEFINE cave_mode				DM_flags_state,3	; =1: in cave mode (gas needs by backtracking)
#DEFINE depth_limit_exceeded	DM_flags_state,4	; =1: depth limit exceeded
#DEFINE deco_locked				DM_flags_state,5	; =1: in or has been in deco obligation       during the dive
#DEFINE deco_region				DM_flags_state,6	; =1: in or has been in the deco stops region during the dive
;								DM_flags_state,7	; --- unused

;---- Dive Mode - O2 Sensors
#DEFINE use_O2_sensor1			DM_flags_sensor,0	; =1: sensor 1 shall be used
#DEFINE use_O2_sensor2			DM_flags_sensor,1	; =1: sensor 2 shall be used
#DEFINE use_O2_sensor3			DM_flags_sensor,2	; =1: sensor 3 shall be used
#DEFINE voting_logic_sensor1	DM_flags_sensor,3	; =1: sensor 1 is within the voting logic threshold
#DEFINE voting_logic_sensor2	DM_flags_sensor,4	; =1: sensor 2 is within the voting logic threshold
#DEFINE voting_logic_sensor3	DM_flags_sensor,5	; =1: sensor 3 is within the voting logic threshold
;								DM_flags_sensor,6	; --- unused
;								DM_flags_sensor,7	; --- unused

;---- Dive Mode - User Requests
#DEFINE request_gaschange		DM_flags_request,0	; =1: request to change the gas
#DEFINE request_reset_avg		DM_flags_request,1	; =1: request to reset the average depth
#DEFINE request_next_custview	DM_flags_request,2	; =1: request to show the next custom view
#DEFINE request_back_to_loop	DM_flags_request,3	; =1: request to switch back from bailout to loop
#DEFINE request_toggle_GF		DM_flags_request,4	; =1: request to toggle between GF and aGF
#DEFINE request_set_marker		DM_flags_request,5	; =1: request to set a marker in the logbook
#DEFINE request_turn_dive		DM_flags_request,6	; =1: request to toggle the dive turned status
;								DM_flags_request,7	; --- unused

;---- Dive Mode - Data Recording Events
#DEFINE event_occured			DM_flags_event,0	; =1: an event occurred (global indicator flag)
#DEFINE event_gas_change		DM_flags_event,1	; =1: a change to another gas or diluent occurred
#DEFINE event_gas_change_gas6	DM_flags_event,2	; =1: a change to or of the gas 6 has occurred
#DEFINE event_bailout			DM_flags_event,3	; =1: a change to or of the OC gas occurred due to bailout
#DEFINE event_SP_change			DM_flags_event,4	; =1: a change of the setpoint has occurred
;								DM_flags_event,5	; --- unused
#DEFINE rs232_rx_timeout		DM_flags_event,6	; =1: RS232 receive timeout occurred  | no better place found
#DEFINE i2c_error_flag			DM_flags_event,7	; =1: an I2C error occurred           | for these two flags...

;---- Dive Mode - Display Control / Layout
#DEFINE safety_stop_enabled		DM_flags_layout1,0	; =1: safety        stop is enabled
#DEFINE safety_stop_active		DM_flags_layout1,1	; =1: safety        stop is shown
#DEFINE decostop_active			DM_flags_layout1,2	; =1: decompression stop is shown
#DEFINE velocity_active_num		DM_flags_layout1,3	; =1: numerical velocity indicator is shown
#DEFINE velocity_active_vsi		DM_flags_layout1,4	; =1: graphical velocity indicator is shown
#DEFINE alt_layout_active		DM_flags_layout1,5	; =1: the alternative dive layout is used (aka "blind mode")
#DEFINE neg_flag_velocity		DM_flags_layout1,6	; =1: descending, used by velocity logic
#DEFINE show_only_divemins		DM_flags_layout1,7	; =1: only dive minutes are shown

#DEFINE cur_depth_greater_100m	DM_flags_layout2,0	; =1: current depth > 100 meters
#DEFINE max_depth_greater_100m	DM_flags_layout2,1	; =1: max.    depth > 100 meters
#DEFINE depth_attention			DM_flags_layout2,2	; =1: show depth in attention color
#DEFINE depth_warning			DM_flags_layout2,3	; =1: show depth in warning   color
#DEFINE depth_warn_att_last		DM_flags_layout2,4	; =1: last depth was shown in warning or attention color
#DEFINE depth_inverse_last		DM_flags_layout2,5	; =1: last depth was shown in inverse
#DEFINE gas_needs_mode_last		DM_flags_layout2,6	; =1: last gas needs were computed for cave mode, =0: direct ascent
#DEFINE tts_greater_99			DM_flags_layout2,7	; =1: TTS > 99 minutes

;---- Dive Mode - Display Control / Messages
#DEFINE message_advice			DM_flags_message,0	; =1: an advice    is active in dive mode
#DEFINE message_attention		DM_flags_message,1	; =1: an attention is active in dive mode or surface mode
#DEFINE message_warning			DM_flags_message,2	; =1: a warning    is active in dive mode or surface mode
#DEFINE message_2nd_row_used	DM_flags_message,3	; =1: the second row contains a warning/attention/advice
#DEFINE sign_shown				DM_flags_message,4	; =1: the warning/attention/advice sign is shown
#DEFINE gas_needs_attention		DM_flags_message,5	; =1: the gas needs  attention has been shown before
#DEFINE gas_needs_warning		DM_flags_message,6	; =1: the gas needs  warning   has been shown before
#DEFINE o2_sensors_warning		DM_flags_message,7	; =1: the O2 sensors warning   has been shown before

;---- Dive Mode - Display Control / Gas, Diluent
#DEFINE better_gas_hint			DM_flags_gas_dil,0	; =1: mark a gas when it is a better gas
#DEFINE better_gas_available	DM_flags_gas_dil,1	; =1: a better gas is available
#DEFINE better_gas_blinking		DM_flags_gas_dil,2	; =1: gas is blinking
#DEFINE better_dil_available	DM_flags_gas_dil,3	; =1: a better diluent is available
#DEFINE better_dil_blinking		DM_flags_gas_dil,4	; =1: diluent is blinking
;								DM_flags_gas_dil,5	; --- unused
;								DM_flags_gas_dil,6	; --- unused
;								DM_flags_gas_dil,7	; --- unused


;---- Menu System - Control
#DEFINE surfmode_menu			MS_flags_control,0	; =1: surface      menu is shown (i.e. returning from it)
#DEFINE dive_options_menu		MS_flags_control,1	; =1: dive options menu is shown (e.g. "Menu?")
#DEFINE dive_main_menu			MS_flags_control,2	; =1: dive mode    menu is shown (i.e. the "big" menu)
#DEFINE compass_menu			MS_flags_control,3	; =1: "set bearing"     is shown
#DEFINE is_diluent_menu			MS_flags_control,4	; =1: setting up diluents, =0: setting up OC gases
#DEFINE is_bailout_menu			MS_flags_control,5	; =1: in bailout menu
;								MS_flags_control,6	; --- unused
;								MS_flags_control,7	; --- unused

;---- Menu System - Data Imprinting
#DEFINE imprint_time_date		MS_flags_imprint,0	; =1: imprint current time & date
#DEFINE imprint_color_schemes	MS_flags_imprint,1	; =1: imprint color schemes
#DEFINE imprint_sensor_mv		MS_flags_imprint,2	; =1: imprint O2 sensor mV data
#DEFINE imprint_xmitter_pres	MS_flags_imprint,3	; =1: imprint transmitter pressure data
#DEFINE imprint_xmitter_ID		MS_flags_imprint,4	; =1: in transmitter-to-tank pairing menu
#DEFINE imprint_surfmode_data	MS_flags_imprint,5	; =1: imprint surface mode data
#DEFINE block_option_value		MS_flags_imprint,6	; =1: suspend display of option values
;								MS_flags_imprint,7	; --- unused


;---- Font & Image System
#DEFINE aa_antialias			AA_flags,0			;     used by aa_wordprocessor
#DEFINE aa_color_quarter		AA_flags,1			;     used by aa_wordprocessor
#DEFINE aa_color_half			AA_flags,2			;     used by aa_wordprocessor
#DEFINE aa_aux_flag				AA_flags,3			;     auxiliary flag for various purposes
#DEFINE use_custom_colors		AA_flags,4			; =1: override default pixel colors, used by color_image
;								AA_flags,5			; --- unused
;								AA_flags,6			; --- unused
;								AA_flags,7			; --- unused


;---- Convert and Display Functions (Control of numerical and other Output)
#DEFINE leftbind				CVT_flags1,0		; =1: align numbers to the left
#DEFINE win_invert				CVT_flags1,1		; =1: the text   shall be printed in inverse
#DEFINE short_gas_descriptions	CVT_flags1,2		; =1: use short versions of gaslist_strcat_gas_cd and gaslist_strcat_setpoint
#DEFINE ignore_digit3			CVT_flags1,3
#DEFINE ignore_digit4			CVT_flags1,4
#DEFINE ignore_digit5			CVT_flags1,5
#DEFINE aux_flag				CVT_flags1,6		;     provided for local boolean arguments and storage
;								CVT_flags1,7		; --- unused

#DEFINE pre_zero_flag			CVT_flags2,0
#DEFINE all_zeros_flag			CVT_flags2,1
#DEFINE DP_done					CVT_flags2,2
#DEFINE DP_done2				CVT_flags2,3
#DEFINE show_last3				CVT_flags2,4
#DEFINE leading_zeros			CVT_flags2,5
#DEFINE show_last4				CVT_flags2,6
#DEFINE neg_flag				CVT_flags2,7		; =1: result is negative


;---- Miscellaneous Flags 
#DEFINE ignore_last_edited_gas	misc_flags,0		; =1: ignore last edited gas while cleaning up gas/dil list
#DEFINE copying_dil				misc_flags,1		; =1: copying a diluent
#DEFINE comm_service_enabled	misc_flags,2		; =1: COMM service mode is enabled
;								misc_flags,3		; --- unused
;								misc_flags,4		; --- unused
;								misc_flags,5		; --- unused
;								misc_flags,6		; --- unused
;								misc_flags,7		; --- unused

;---- HUD Status Byte (stored in access RAM)
#DEFINE hud_connection_ok		hud_status_byte,0	; =1 HUD connection ok
;								hud_status_byte,1	; =1 HUD is calibrated
;								hud_status_byte,2	; =1 HUD battery is low (< 3000 mV)
#DEFINE sensor1_active			hud_status_byte,3	; =1: sensor 1 is active
#DEFINE sensor2_active			hud_status_byte,4	; =1: sensor 2 is active
#DEFINE sensor3_active			hud_status_byte,5	; =1: sensor 3 is active
;								hud_status_byte,6	; --- unused in stand-alone HUD
;								hud_status_byte,7	; --- unused in stand-alone HUD


;---------------------------- Macros ------------------------------------

TSTOSS	macro opt_reg				; TeST Option Skip next instruction if Set (not zero)
	movff	opt_reg,WREG			; Attention: destroys WREG!
	tstfsz	WREG,A					; Attention: must be followed by a plain machine
	bra		$+4						;            command, do not let follow a macro!
	endm							;


TSTOSC	macro opt_reg				; TeST Option Skip next instruction if Clear (zero)
	movff	opt_reg,WREG			; Attention: destroys WREG!
	tstfsz	WREG,A					; Attention: must be followed by a plain machine
	endm							;            command, do not let follow a macro!


CLRI	macro int					; CLeaR Integer (version of clrf for 2 byte integers)
	clrf	int+0					; Attention: must be in bank where target variable resides!
	clrf	int+1					;
	endm							;


SETI	macro int					; SET Integer (version of setf for 2 byte integers)
	setf	int+0					; Attention: must be in bank where target variable resides!
	setf	int+1					;
	endm							;


MOVLI	macro lit, int				; MOVe Literal to Integer
	movlw	LOW  (lit)				; Attention: destroys WREG!
	movwf	int+0					; Attention: must be in bank where target variable resides!
	movlw	HIGH (lit)				;
	movwf	int+1					;
	endm							;


INCI	macro int					; INCrement Integer (version of incf for 2 byte integers)
	infsnz	int+0,F					; Attention: must be in bank where target variable resides!
	incf	int+1,F					;
	endm							;


DECI	macro int					; DECrement Integer (version of decf for 2 byte integers)
	movlw	.1						; Attention: destroys WREG!
	subwf	int+0,F					; Attention: must be in bank where target variable resides!
	movlw	.0						;
	subwfb	int+1,F					;
	endm							;


ADDLI	macro lit, int				; ADD Literal to Integer
	movlw	LOW  (lit)				; Attention: destroys WREG!
	addwf	int+0,F					; Attention: must be in bank where target variable resides!
	movlw	HIGH (lit)				;
	addwfc	int+1,F					;
	endm							;


SUBLI	macro lit, int				; SUBtract Literal from Integer
	movlw	LOW  (lit)				; Attention: destroys WREG!
	subwf	int+0,F					; Attention: must be in bank where target variable resides!
	movlw	HIGH (lit)				;
	subwfb	int+1,F					;
	endm							;


MOVII	macro from, to				; MOVe Integer to Integer (version of movff for 2 byte integers)
	movff	from+0,to+0				; banksafe
	movff	from+1,to+1				;
	endm							;


SMOVII	macro from, to				; isr-Safe MOVe 2 byte Integer to Integer (version of MOVII for integers updated in ISR)
	local	retry					;
retry:
	bcf		trigger_isr_updates		; clear flag, it will be set by the ISR in case it had kicked in
	movff	from+0,to+0				; copy low  byte
	movff	from+1,to+1				; copy high byte
	btfsc	trigger_isr_updates		; did the ISR kicked in since we cleared the flag?
	bra		retry					; YES - retry copy
	endm							; NO  - done


SMOVTT	macro from, to				; isr-Safe MOVe Three byte integer to integer (version of MOVII for integers updated in ISR)
	local	retry					;
retry:
	bcf		trigger_isr_updates		; clear flag, it will be set by the ISR in case it had kicked in
	movff	from+0,to+0				; copy low   byte
	movff	from+1,to+1				; copy high  byte
	movff	from+2,to+2				; copy upper byte
	btfsc	trigger_isr_updates		; did the ISR kicked in since we cleared the flag?
	bra		retry					; YES - retry copy
	endm							; NO  - done


SMOVFF	macro from, to				; isr-Safe MOVe Four byte integer to integer (version of MOVII for integers updated in ISR)
	local	retry					;
retry:
	bcf		trigger_isr_updates		; clear flag, it will be set by the ISR in case it had kicked in
	movff	from+0,to+0				; copy byte 0 (LSB)
	movff	from+1,to+1				; copy byte 1
	movff	from+2,to+2				; copy byte 2
	movff	from+3,to+3				; copy byte 3 (MSB)
	btfsc	trigger_isr_updates		; did the ISR kicked in since we cleared the flag?
	bra		retry					; YES - retry copy
	endm							; NO  - done


SMOVSS	macro from, to				; isr-Safe MOVe Six byte integer to integer (version of MOVII for integers updated in ISR)
	local	retry					;
retry:
	bcf		trigger_isr_updates		; clear flag, it will be set by the ISR in case it had kicked in
	movff	from+0,to+0				; copy byte 0 (LSB)
	movff	from+1,to+1				; copy byte 1
	movff	from+2,to+2				; copy byte 2
	movff	from+3,to+3				; copy byte 3
	movff	from+4,to+4				; copy byte 4
	movff	from+5,to+5				; copy byte 5 (MSB)
	btfsc	trigger_isr_updates		; did the ISR kicked in since we cleared the flag?
	bra		retry					; YES - retry copy
	endm							; NO  - done


;---------------------------- C-Code Routines ----------------------------

	extern	deco_calc_desaturation_time
	extern	deco_calc_hauptroutine
	extern	deco_calc_dive_interval
	extern	deco_calc_dive_interval_1min
	extern	deco_calc_dive_interval_10min
	extern	deco_clear_tissue
	extern	deco_init_output_vars
	extern	deco_pull_tissues_from_vault
	extern	deco_push_tissues_to_vault


;---------------------------- Bank0 ACCESS RAM ------------------------------

; Variables located in the Access Bank are declared in hwos.asm

 ifndef ACCESS_RAM_VARS

	extern	HW_descriptor
	extern	HW_variants

	extern	HW_flags_state1
	extern	HW_flags_state2

	extern	OS_flags_persist
	extern	OS_flags_ISR1
	extern	OS_flags_ISR2

	extern	OM_flags_mode

	extern	DM_flags_deco

	extern	cpu_speed_request
	extern	cpu_speed_state

	extern	timebase
	extern	eventbase

	extern	isr_timeout_timer
	extern	isr_timeout_reload

	extern	total_divetime_secs
	extern	counted_divetime_mins
	extern	counted_divetime_secs

	extern	apnoe_surface_secs
	extern	apnoe_surface_mins
	extern	apnoe_dive_secs
	extern	apnoe_dive_mins

	extern	sampling_rate
	extern	sampling_timer

	extern	simulatormode_depth

	extern	hud_status_byte
	extern	hud_battery_mv

 endif

;---------------------------- Bank0 NORMAL RAM ------------------------------
isr_backup	equ			0x060		; Alias for "banksel isr_backup"
isr_backup	udata_ovr	isr_backup	; Bank 0 ISR data

;---- Backup for general Registers
PROD_backup						res 2
FSR0_backup						res 2
BSR_backup						res 1

;---- Multi-Purpose Register for ISR Routines
isr_mpr							res 2		; used in ms5541.asm and isr.asm
#DEFINE isr_lo					isr_mpr+0	;
#DEFINE isr_hi					isr_mpr+1	;

;---- Time and Date - Real Time Clock
rtc_year						res 1		; running year     | Attention:
rtc_month						res 1		; running month    | do not change
rtc_day							res 1		; running day      | the Position of
rtc_hour						res 1		; running hour     | these Variables
rtc_mins						res 1		; running minute   | relative to
rtc_secs						res 1		; running second   | each other!

rtc_latched_year				res 1		; latched year     | Attention:
rtc_latched_month				res 1		; latched month    | do not change
rtc_latched_day					res 1		; latched day      | the Position of
rtc_latched_hour				res 1		; latched hour     | these Variables
rtc_latched_mins				res 1		; latched minute   | relative to
rtc_latched_secs				res 1		; latched second   | each other!

;--- RTC-independent Timebase
timebase_mins					res 1		; RTC-independent timer for generating the every hour   trigger
timebase_secs					res 1		; RTC-independent timer for generating the every minute trigger

;---- other Timers
uptime							res 4		; [sec] uptime of the OSTC since last cold start
surface_interval_secs			res 4		; [sec] surface interval counted in seconds
surface_interval_mins			res 2		; [min] surface interval counted in minutes
simulator_time					res 1		; [min] real runtime of the simulator

;---- Data for Pressure and Temperature Calculation (MS5541)
clock_count						res 1		; I2C clock pulse counter
sensor_state_counter			res 1		; counter for pressure sensor state machine
dLSB							res 1		; pressure sensor interface, LSB
dMSB							res 1		; pressure sensor interface, MSB
dbuffer							res 1		; pressure sensor interface, RX/TX buffer

C1								res 2		; decoded calibration data
C2								res 2		; decoded calibration data
C3								res 2		; decoded calibration data
C4								res 2		; decoded calibration data, here C4-250
C5								res 2		; decoded calibration data, here reference temperature UT1 = 8*C5 + 10000 (u16 range 10.000 .. +42.760)
C6								res 2		; decoded calibration data
D1								res 2		; raw pressure
D2								res 2		; raw temperature
xdT								res 2
xdT2							res 2
OFF								res 2
SENS							res 2

temperature_cur					res 2		; current  temperature
temperature_min					res 2		; minimum  temperature (operated by divemode.asm)
temperature_avg					res 2		; internal register used for averaging
temperature_last				res 2		; internal register used for detecting changes

pressure_abs					res 2		; current  absolute pressure
pressure_abs_avg				res 2		; internal register used for averaging
pressure_abs_last				res 2		; internal register used for detecting pressure changes

pressure_abs_sampled			res 2		; sampled   surface pressure, sampled in sleep mode every 15 minutes
pressure_abs_ref				res 2		; reference surface pressure, surface pressure sampled    15 minutes ago
pressure_surf					res 2		; surface pressure used by ISR to calculate relative pressures

pressure_rel_cur				res 2		; current relative pressure
pressure_rel_max				res 2		; maximum relative pressure
pressure_rel_sim				res 2		; simulated relative pressure (simulator mode)

;---- Data for ISR Math Subroutines
isr_xA							res 2		; multiplicand 1
isr_xB							res 2		; multiplicand 2
isr_xC							res 4		; resulting product

;---- Display Brightness
ambient_light					res 2		; ambient light level
max_CCPR1L						res 1		; max. brightness value for CCPR1L

;---- Battery Gauge (nAs, nC)
battery_gauge					res 6		; 48 bit -> 78 Ah max

;---- IR/S8-Link
ir_s8_buffer					res .18		; buffer for data received on IR/S8 interface,
											; also used to buffer MS5541 raw calibration data

 IFDEF _external_sensor
ir_s8_counter					res 1
ir_s8_timeout					res 1		; timeout for valid data
 ENDIF

;---- raw O2 Sensor Data received on S8 Link
 IFDEF _external_sensor
s8_rawdata_sensor1				res 3		; 24 bit A/D raw data from S8 HUD sensor 1
s8_rawdata_sensor2				res 3		; 24 bit A/D raw data from S8 HUD sensor 2
s8_rawdata_sensor3				res 3		; 24 bit A/D raw data from S8 HUD sensor 3
 ENDIF

;---- Switch Processing (8 byte, called by ISR and sleep mode)
analog_sw1_raw					res 2		; idle values (average)
analog_sw2_raw					res 2		; idle values (average)
analog_counter					res 1		; for averaging
analog_sw1						res 1		; analog value for switch 1
analog_sw2						res 1		; analog value for switch 2
button_polarity					res 1		; 0xFF (both normal), 0x00 (both inverted), 0x01 (left inverted only), 0x02 (right inverted only)

;--- resettable min and max Depth Option
 IFDEF _min_depth_option
pressure_rel_min_trip			res 2		; resettable minimum relative pressure
pressure_rel_max_trip			res 2		; resettable maximum relative pressure
 ENDIF

; 141 byte used, 19 byte free

 
;---------------------------- Common DATA ------------------------------------
common		equ			0x100		; Alias for "banksel common"
common		udata_ovr	common		; Bank 1 general variables

;---- Multi-Purpose Register for Data Storage and Interface with Conversion and Display Functions (6 byte)
mpr								res 6		; will be used as base address of 1, 2, 3, 4 and 6 byte buffers
#DEFINE lo						mpr+0		; nickname for "low"
#DEFINE hi						mpr+1		; nickname for "high"
#DEFINE up						mpr+2		; nickname for "upper"
#DEFINE ex						mpr+3		; nickname for "extra"
#DEFINE ul						mpr+4		; nickname for "ultra"
#DEFINE hy						mpr+5		; nickname for "hyper"


;---- Flags - Menu System (2 byte)
MS_flags_control				res 1		; menu system - control
MS_flags_imprint				res 1		; menu system - data imprinting

;---- Flags - Dive Mode (7 byte)
DM_flags_state					res 1		; dive mode - dive states
DM_flags_sensor					res 1		; dive mode - O2 sensors
DM_flags_request				res 1		; dive mode - user requests
DM_flags_event					res 1		; dive mode - data recording events
DM_flags_layout1				res 1		; dive mode - display control / layout (1)
DM_flags_layout2				res 1		; dive mode - display control / layout (2)
DM_flags_message				res 1		; dive mode - display control / messages
DM_flags_gas_dil				res 1		; dive mode - display control / gas, diluent

;---- Miscellaneous Flags (1 byte)
misc_flags						res 1

;---- Interface to numerical Display Functions (1 byte)
ignore_digits					res 1

;---- Interface to Graphic Functions (12 byte)
win_leftx2						res 1
win_top							res 1
win_width						res 2
win_height						res 1
win_bargraph					res 1		; width of the bargraph bar
win_color1						res 1		; 2 byte color
win_color2						res 1		; 2 byte color
win_color3						res 1		; 3 byte color used for display 2
win_color4						res 1		; 3 byte color used for display 2
win_color5						res 1		; 3 byte color used for display 2
win_font						res 1		; font size selector

;---- Interface to Math Functions (16 byte)
divA							res 2
xA								res 2
xB								res 2
xC								res 4
sub_a							res 2
sub_b							res 2
sub_c							res 2

;---- Menu System and Views (4 byte)
menu_pos_cur					res 1		; current position in main menu
menu_pos_max					res 1		; highest position in main menu
active_premenu					res 1		; currently shown pre-menu (0: none)
active_customview				res 1		; currently shown custom view

;---- Miscellaneous (6 byte)
batt_voltage					res 2		; battery voltage in mV (no ISR involved)
batt_percent					res 1		; battery in percent (1-100%)
message_counter					res 1		; counts amount of messages
message_page					res 1		; current message page number
pairing_slot					res 1		; slot number, used in transmitter pairing

;---- Dive Mode / all modes (25 byte)
divesecs_avg_trip				res 2		; time accumulator for the resettable average depth & stopwatch
divesecs_avg_total				res 2		; time accumulator for the total dive average depth
pressure_rel_avg_trip			res 2		; calculated resettable average depth
pressure_rel_avg_total			res 2		; calculated total dive average depth
pressure_rel_cur_cached			res 2		; cached current relative pressure
pressure_rel_max_cached			res 2		; cached maximum relative pressure
pressure_abs_cached				res 2		; cached current absolute pressure
pressure_abs_10					res 2		; cached current absolute pressure divided by 10
depth_meter						res 1		; current depth in meters
safety_stop_countdown			res 1		; counter for safety stop
dive_timeout_timer				res 2		; timeout timer for leaving dive mode after surfacing
gaslist_gas						res 1		; used for transfer between gaslist.asm and menu_tree.asm
best_gas_number					res 1		; number of the "best gas": 0= none found, 1-5= gases 1-5, 255= not computed
active_gas						res 1		; the currently used OC/bailout gas (1-5)

 IFDEF _ccr_pscr
best_dil_number					res 1		; number of the "best dil": 0= none found, 1-5= dils  1-5, 255= not computed
active_dil						res 1		; the currently used diluent (1-5)
 ENDIF

;---- Dive Mode / apnoe mode (2 byte)
apnoe_max_pressure				res 2		; max depth over all dives in the series

;---- Gas 6 Data (2 byte)
gas6_O2_ratio					res 1		; gas 6 O2 ratio
 IFDEF _helium
gas6_He_ratio					res 1		; gas 6 He ratio
 ENDIF

;---- Profile Recording (6 byte)
alarm_type						res 1		;
event_byte1						res 1		;
event_byte2						res 1		;
CNS_start						res 2		; CNS value at beginning of dive

;---- External Flash (13 byte)
ext_flash_rw					res 1		; transfer register for data read / write
ext_flash_address				res 3		; 24 bit address
ext_flash_log_pointer			res 3		; 24 bit address for logbook profile storing
ext_flash_end_pointer			res 3		; 24 bit address for logbook profile storing
ext_flash_dive_counter			res 3		; 24 bit counter for dive length (increased in write_byte_ext_flash_plus)

;---- Battery Management (12 byte)
battery_capacity_internal		res 2		; for internal battery gauging
battery_capacity				res 2		; for battery gauge IC
battery_offset					res 2		; for battery gauge IC
battery_type					res 1		; =0:1.5V, =1:3.6V Saft, =2:LiIon 3.7V/0.8Ah, =3:LiIon 3.7V/3.1Ah, =4: LiIon 3.7V/2.3Ah
battery_accumulated_charge		res 2		; raw values in battery gauge IC
battery_temperature				res 2		; battery temperature in 0.1 Kelvin
gauge_status_byte				res 1		; gauge IC status byte


;========================= private Variables ===================================
;        do not access from outside of the respective source files!

;---- aa_wordprocessor.asm and strings.asm
AA_flags						res 1		; various flags for aa_wordprocessor and strings
aa_bitlen						res 1		; count of pixels when decoding bitmaps
aa_start						res 2		; PROM pointer to start of encoded bitmap
aa_end							res 2		; and end of it
aa_temp							res 2		; current color, divided by 2 or 4

;--- adc_lightsensor.asm
get_bat_volt_counter			res 1		; counter for reading the charger chip

;---- convert.asm
CVT_flags1						res 1
CVT_flags2						res 1
cvt_temp1						res 1
cvt_temp2						res 1
cvt_temp3						res 1
cvt_temp4						res 1
cvt_temp_lo						res 1
cvt_temp_hi						res 1

;---- color_processor.asm
overall_pixels					res 3		; used by color_processor.asm
pixel_count						res 2		; used by color_processor.asm
encoding_format					res 1		; image encoding format

;---- compass_ops.asm
compass_flags					res 1		; flags are defined in compass_ops.asm

;---- comm.asm
comm_timeout_timer				res 1		; timeout for communication

;---- eeprom_rs232.asm
uart_timeout_timer				res 3		; RS232 receive timeout counter

;---- i2c.asm
i2c_temp1						res 1		; temporary data
i2c_temp2						res 1		; temporary data

;---- math.asm
math_loop						res 1		; loop counter

;---- menu_processor.asm
menustack_pointer				res 1		; pointer to menu stack
menu_flags						res 1		; flags for menu entries
menu_item						res 1		; index of the current item
start_item						res 1		; index of the first item (scrolling)
item_max						res 1		; number of items in menu
selected_item					res 1		; index of the current item
value_type						res 1		; type for vertical menu
dynamic_item					res 3		; callback address
menu_block						res 3		; address of the menu block (i.e. item 0)
menu_title						res 3		; text or procedure for dynamic menu
menu_center						res 1		; centering for line menu
proc_item						res 3		; address of the current procedure
text_item						res 2		; address of the current text

;---- options.asm
opt_type						res 1		; option type
opt_default						res 1		; default value
opt_inc							res 1		; also used for default+1 (string) and enum low
opt_min							res 1		; minimum value, also used for enum high
opt_max							res 1		; maximum value
opt_unit						res 2		; multi-lingual unit text
opt_eeprom						res 1		; storage position in EEPROM
opt_backup_tbl					res 3		; buffer for table pointer

;---- tft.asm
tft_save_top					res 1
tft_save_height					res 1
tft_save_left					res 1
tft_save_width					res 1
tft_temp1						res 1
tft_temp2						res 1
tft_temp3						res 1
tft_temp4						res 1

;---- dump screen Function
 IFDEF _screendump
ds_line							res 1		; current line (0..239)
ds_column						res 1		; current columnx2 (0..159)
ds_pixel						res 2		; current pixel color
ds_count						res 1		; repetition count
 ENDIF

;---- wait.asm
wait_counter					res 1


; 193 byte used, 15 byte free (208 byte total)


;============================ LOCAL DATA ======================================
; Space for various overlayed local data from top-level applications,
; i.e. applications that never run in parallel to each other
;
; --------------------- local Data Users --------------------------------------
;
;					-------------- Applications using ----------------------
;	Mode			local1				local2				local3
; -----------------------------------------------------------------------------
;	sleepmode		sleepmode.asm		(unused)			(unused)
;	surfmode		surfmode.asm*		(unused)			(unused)
;	simulator		divemode.asm		divemode.asm		simulator.asm
;	divemode		divemode.asm		divemode.asm		ghostwriter.asm
;	logbook			logbook.asm			logbook.asm			logbook.asm
;
; * assigned to this slot, but currently no local memory used

local1			equ			0x1D0	; Alias for CBLOCK directive
local1			udata_ovr	0x1D0	; Bank1 shared local space
				res			0x10	; 16 Byte (0x1D0 ... 0x1DF)

local2			equ			0x1E0	; Alias for CBLOCK directive
local2			udata_ovr	0x1E0	; Bank1 shared local space
				res			0x10	; 16 Byte (0x1E0 ... 0x1EF)

local3			equ			0x1F0	; Alias for CBLOCK directive
local3			udata_ovr	0x1F0	; Bank1 shared local space
				res			0x10	; 16 Byte (0x1F0 ... 0x1FF)


;---------------------------- Common2 DATA ------------------------------------
common2		equ			0xA00		; Alias for "banksel common2"
common2		udata_ovr	common2		; Bank 10 general variables

;---- Data for Logging (6 byte), sampled in divemode.asm and used in ghostwriter.asm
start_year						res 1		; year                                    | ATTENTION:
start_month						res 1		; month                                   | do not change the
start_day						res 1		; day                                     | position of these
start_hour						res 1		; hour                                    | variables relative
start_mins						res 1		; minute                                  | to each other!
start_secs						res 1		; second, not used, for code commonality  |

supersat_start					res 1		; leading tissue supersaturation at beginning of the dive

;---- Backup for lost Gas Function (10 byte)
opt_gas_type_backup				res 5		; 0=Disabled, 1=First, 2=Travel, 3=Deco   | ATTENTION:
opt_dil_type_backup				res 5		; 0=Disabled, 1=First, 2=Normal           | (as above)

;---- O2 Sensors (9 byte, updated by ISR when sensors are connected via datalink)
 IFDEF _external_sensor
sensor1_mv						res 2		; sensor 1 voltage in 0.1  mV  steps
sensor2_mv						res 2		; sensor 2 voltage in 0.1  mV  steps
sensor3_mv						res 2		; sensor 3 voltage in 0.1  mV  steps
sensor1_ppO2					res 1		; sensor 1 ppO2    in 0.01 bar steps
sensor2_ppO2					res 1		; sensor 2 ppO2    in 0.01 bar steps
sensor3_ppO2					res 1		; sensor 3 ppO2    in 0.01 bar steps
 ENDIF

;---- last Dive Statistics (7 byte)
lastdive_duration				res 3		; byte 0= minutes, low byte, 1= minutes, high byte, 2= seconds
lastdive_maxdepth				res 2		; in mbar
lastdive_avgdepth				res 2		; in mbar

;---- Backup of last shown Custom View (2 byte)
customview_surfmode				res 1		; storage to remember last selected custom view in surface mode
customview_divemode				res 1		; storage to remember last selected custom view in dive mode

;---- Miscellaneous (0 byte)
;old_velocity					res 4		; stores the last 4 speeds (8 seconds) in m/min

;---- Menu Processor (8 byte)
menustack						res 8		; menu stack

;---- Graphical Compass (15 byte)
xRD								res 2		; virtual compass ruler offset
xRDr							res 2		; virtual compass ruler offset - right end
xRD180							res 2		; virtual compass ruler offset for the -180 marker
xLO								res 1		; lo backup to prevent trashing
xHI								res 1		; hi backup to prevent trashing
xCM								res 1		; compass bearing relative position
compass_heading_new				res 2		; corrected heading (in 1°) : -180 .. 180
compass_heading_shown			res 2		; displayed heading
compass_bearing					res 2		; displayed bearing

;---- Compass Arithmetics (30 byte)
compass_DX						res 2		; raw data
compass_DY						res 2		; raw data
compass_DZ						res 2		; raw data
accel_DX						res 2		; raw data
accel_DY						res 2		; raw data
accel_DZ						res 2		; raw data
compass_DX_f					res 2		; filtered Data
compass_DY_f					res 2		; filtered Data
compass_DZ_f					res 2		; filtered Data
accel_DX_f						res 2		; filtered Data
accel_DY_f						res 2		; filtered Data
accel_DZ_f						res 2		; filtered Data
compass_CX_f					res 2		; calibration data
compass_CY_f					res 2		; calibration data
compass_CZ_f					res 2		; calibration data

;---- temporary Data for Q15 Arithmetics (7 byte, compass_ops.asm, called from C)
compass_a						res 2		;
compass_b						res 2		;
compass_r						res 3		;

;---- Data Exchange with TR Co-Processor (50 byte)
 IFDEF _rx_functions
rx_buffer						res .48		; Buffer for RX data (slots 0-7)
rx_firmware_cur_major			res 1		; TR module current firmware, major
rx_firmware_cur_minor			res 1		; TR module current firmware, minor
 ENDIF

;---- SAC Calculation on Pressure Readings 1 & 2 (22 byte)
 IFDEF _rx_functions
pres_accu_1st					res 4		; accumulator for pressure drop    in 1/160 bar  | ATTENTION: do not
pres_accu_2nd					res 4		; accumulator for pressure drop    in 1/160 bar  |            change the
time_accu_1st					res 2		; accumulator for reading ages     in seconds    |            position
gas__last_1st					res 1		; last gas assignment                            |            of these
time_accu_2nd					res 2		; accumulator for reading ages     in seconds    |            variables
gas__last_2nd					res 1		; last gas assignment                            |            relative
pres_last_1st					res 2		; last pressure reading pressure   in 1/160 bar  |            to each
pres_last_2nd					res 2		; last pressure reading pressure   in 1/160 bar  |            other!
time_last_1st					res 2		; last pressure reading time       in seconds    |
time_last_2nd					res 2		; last pressure reading time       in seconds    |
 ENDIF


; 166 byte used, 90 byte free


;----------------------- Bank 2 General Purpose Buffer -------------------------
; Reserved for general purpose buffer (strings, images, etc).
; NOTE: Needs to be aligned with a bank (LOW(buffer)==0).

buffer		udata_ovr	0x200

buffer							res	.256	; used for string assembly / display output


;---------------------- Bank 14 Options Table ---------------------------------
opt_table	equ			0xE00		; Alias for "banksel opt_table"
opt_table	udata_ovr	opt_table	; Bank 14 options table

;---- Gas and Diluent Settings
opt_gas_O2_ratio				res 5		; O2 ratios of OC/bailout gases                              | ATTENTION:
opt_dil_O2_ratio				res 5		; O2 ratios of diluents                                      | keep relative
opt_gas_He_ratio				res 5		; He ratios of OC/bailout gases                              | positioning of
opt_dil_He_ratio				res 5		; He ratios of diluents                                      | all arrays in
opt_gas_type					res 5		; OC/bailout gas type: O=Disabled, 1=First, 2=Travel, 3=Deco | this block!
opt_dil_type					res 5		;            dil type: 0=Disabled, 1=First, 2=Normal         |
opt_gas_change					res 5		; change depths for OC/Bailout gases                         |
opt_dil_change					res 5		; change depths for diluents                                 |

;---- Setpoints
opt_setpoint_cbar				res 5		; setpoints in cbar                        | ATTENTION: keep relative positioning
opt_setpoint_change				res 5		; change depth for the setpoints in meter  |            of these two arrays!

;---- Dive Mode Settings
opt_dive_mode					res 1		; main dive/deco mode: =0: OC, =1: CC, =2: Gauge, =3: Apnea,  =4: pSCR
opt_ccr_mode					res 1		; CCR/pSCR sub   mode: =0: fixed/calculated SP,   =1: Sensor, =2: Auto SP

;---- custom Text
#DEFINE opt_name_length			.60			; custom text string 5 rows with 12 chars
opt_name						res opt_name_length

;---- various other Settings
opt_surface_interval			res 1		; surface interval, used by deco calculator
opt_brightness					res 1		; =0: Eco, =1:Medium, =2:Full
opt_salinity					res 1		; 0-5%
opt_language					res 1		; current language: 0=EN, 1=DE, 2=FR, 3=SP
opt_units						res 1		; 0:m/°C, 1:ft/°F
opt_dateformat					res 1		; =0:MMDDYY, =1:DDMMYY, =2:YYMMDD
opt_last_stop					res 1		; =3:3m, =4:4m, =5:5m, =6:6m
opt_aGF_high					res 1		; alternative GF HIGH
opt_aGF_low						res 1		; alternative GF LOW
opt_GF_high						res 1		; GF HIGH
opt_GF_low						res 1		; GF LOW
opt_enable_aGF					res 1		; =1: aGF can be selected underwater
opt_compass_gain				res 1		; 0-7 (230LSB/Gauss to 1370LSB/Gaus)
opt_sampling_rate				res 1		; =1: 10s, =0: 2s
opt_dive_color_scheme			res 1		; 0-3
opt_pressure_adjust				res 1		; SIGNED char (two's complement), -20/+20mbar max.
opt_enable_safetystop			res 1		; =1: a safety stop is shown
opt_calibration_O2_ratio		res 1		; %O2 of calibration gas
opt_x_s1						res 2		; calibration factor (Not stored in EEPROM)
opt_x_s2						res 2		; calibration factor (Not stored in EEPROM)
opt_x_s3						res 2		; calibration factor (Not stored in EEPROM)
opt_sensor_fallback				res 1		; NOT USED ANY MORE, KEPT FOR COMPATIBILITY WITH EEPROM IMAGE
opt_flip_screen					res 1		; =1: flip the screen
opt_cR_button_left				res 1		; left button  sensitivity (cR hardware)
opt_cR_button_right				res 1		; right button sensitivity (cR hardware)
opt_modwarning					res 1		; =1:do a red blinking warning, =0:default behavior
opt_vsitextv2					res 1		; =1:use the depth dependent ascend rate limits
opt_vsigraph					res 1		; =1:draw the graphical VSI bar
opt_showppo2					res 1		; =1:always show the ppO2 value in the warning position
opt_temperature_adjust			res 1		; SIGNED char (two's complement), -2.0/+2.0 °C max.
opt_safety_stop_length			res 1		; [s]
opt_safety_stop_start			res 1		; [cbar]
opt_safety_stop_end				res 1		; [cbar]
opt_safety_stop_reset			res 1		; [cbar]
opt_diveTimeout					res 1		; timeout for dive mode [min]
opt_sim_setpoint_number			res 1		; setpoint to use for deco calculation
opt_calc_asc_gasvolume			res 1		; calculate OC gas volume needs for ascent
opt_sim_use_aGF					res 1		; =0: use GF, =1: use aGF for deco calculation
opt_enable_IBCD					res 1		; enable IBCD warning
opt_sat_multiplier_gf			res 1		; Buhlmann safety factor for GF deco
opt_desat_multiplier_gf			res 1		; Buhlmann safety factor for GF deco
opt_sat_multiplier_non_gf		res 1		; Buhlmann safety factor for NON-GF deco
opt_desat_multiplier_non_gf		res 1		; Buhlmann safety factor for NON-GF deco
opt_ZfactorUse					res 1		; =1: figure in compression factor Z when converting gas volume <-> gas pressure
opt_ZfactorTemp					res 1		; temperature setpoint for compression factor Z
opt_2ndDepthDisp				res 1		; =1: show average depth instead of max depth
opt_max_depth					res 1		; depth at which a warning will be given
opt_store_apnoe_dive			res 1		; =1: store dives in apnoe mode into logbook
opt_tissue_graphics				res 1		; =0: show N2 and He pressures, =1: show pressures and saturations
opt_logoffset_step				res 1		; step size when adjusting log offset
opt_layout						res 1		; initial layout of dive mode screen
opt_extended_stops				res 1		; =1: place gas switches also below 1st stop depth

;---- RX Function Settings
opt_transmitter_id_1			res 2		; 16 bit transmitter ID for Gas 1
opt_transmitter_id_2			res 2		; 16 bit transmitter ID for Gas 2
opt_transmitter_id_3			res 2		; 16 bit transmitter ID for Gas 3
opt_transmitter_id_4			res 2		; 16 bit transmitter ID for Gas 4
opt_transmitter_id_5			res 2		; 16 bit transmitter ID for Gas 5
opt_transmitter_id_6			res 2		; 16 bit transmitter ID for Dil 1
opt_transmitter_id_7			res 2		; 16 bit transmitter ID for Dil 2
opt_transmitter_id_8			res 2		; 16 bit transmitter ID for Dil 3
opt_transmitter_id_9			res 2		; 16 bit transmitter ID for Dil 4
opt_transmitter_id_10			res 2		; 16 bit transmitter ID for Dil 5
opt_TR_mode						res 1		; TR functions - mode
opt_TR_1st_pres					res 1		; TR functions - 1st pressure assignment
opt_TR_2nd_pres					res 1		; TR functions - 2nd pressure assignment
opt_TR_Bail_pres				res 1		; TR functions - bailout pressure assignment

; ==> 187 bytes used - 57 bytes free (244 usable bytes only in bank 14 as the upper 12
;                                     bytes may be used for SFRs on some PIC devices)

;-----------------------------------------------------------------------------
