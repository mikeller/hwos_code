;=============================================================================
;
;   File hwos.inc									REFACTORED VERSION V2.99f
;
;   OSTC Platform definitions
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;   2011-05-24 : [jDG] Cleanups from initial Matthias code
;=============================================================================

; Low Level Settings
	LIST	P=18F87K22		; compiler  settings, if changed, change also: Configure -> SelectDevice in MPLAB
#include <p18f87k22.inc>	; processor definitions
#include <ports.inc>		; Portmap   definitions


; Debug Mode
;#DEFINE __DEBUG			; if defined, compile firmware in debug mode

; Conditional Compiles (note: not all options will fit at the same time)
#DEFINE _screendump			; if defined, compile screen dump  into firmware (default:     included  )
#DEFINE _rx_functions		; if defined, compile RX (OSTC TR) into firmware (default:     included *)
;#DEFINE _ostc_logo			; if defined, compile OSTC logo    into firmware (default: not included  )
;#DEFINE _cave_mode			; if defined, compile cave mode    into firmware (default: not included *)   ## OPTION IS UNDER CONSTRUCTION ##
;
;                             * option needs to be included / excluded in p2_deco.c, too!


; Language Selection
#DEFINE none					0			; no language selected
#DEFINE en						1			; English
#DEFINE de						2			; German
#DEFINE fr						3			; French
#DEFINE it						4			; Italian

#DEFINE _language_1				en			; first or single language - must be set to en, de, fr, or it, defaults to en
#DEFINE _language_2				none		; second language or none


; Firmware Version
#DEFINE softwareversion_x		.3			; Software Version, major               (1 -   9)
#DEFINE softwareversion_y		.00			; Software Version, minor               (1 -  99)
#DEFINE softwareversion_beta	.0			; 0= Release, 1= Beta-1, 2= Beta-2, ... (0 - 255)

; Firmware Expiration Date, will cause version to be displayed in "Update Firmware" style after the following date:
#DEFINE firmware_expire_year	.20
#DEFINE firmware_expire_month	.2
#DEFINE firmware_expire_day		.1

; Magic Cookie Definition
#DEFINE comm_service_key		0xABCDEF

; Logo Address Vectors
#DEFINE hw_logo_block			0x01E000	; color image data for heinrichsweikamp logo
#DEFINE usb_ble_logo_block		0x01EEDE	; color image data for USB or BLE logo


;-----------------------------EEPROM DATA ------------------------------------
; Automatic reset of all options when this is changed:
#DEFINE eeprom_opt_serial		0x0008		; Version 0.8
;-----------------------------------------------------------------------------

#DEFINE CCP1CON_VALUE					b'00001100'	; PWM1 for LED dimming
#DEFINE T2CON_ECO						b'01111110'	;
#DEFINE T2CON_NORMAL					b'01111110'	;
#DEFINE T2CON_FASTEST					b'01111110'	;

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
#DEFINE index_ppo2_ead_end_cns			.11			; ppO2, END/EAD and CNS
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

#DEFINE FT_TINY							.0
#DEFINE FT_SMALL						.1
#DEFINE FT_MEDIUM						.2			; not used
#DEFINE FT_LARGE						.3			; not used

; External O2 cell input Parameters
#DEFINE min_mv							.80			; =   8 mV
#DEFINE max_mv							.2500		; = 250 mV
#DEFINE ignore_mv						.3500		; = 350 mV (to suppress ghost readings for long, open cables)

; Profile Recording Parameters
#DEFINE logbook_profile_version			0x24
#DEFINE samplingrate_apnoe				.1			; [seconds]

; Attention: Divisors must be < 16 !
#DEFINE div_temperature					.6			; x sampling rate [s]
#DEFINE div_deco						.6			; x sampling rate [s]
#DEFINE div_gf							.12			; x sampling rate [s]
#DEFINE div_ppo2_sensors				.2			; x sampling rate [s]
#DEFINE div_decoplan					.12			; x sampling rate [s]
#DEFINE div_cns							.12			; x sampling rate [s]
#DEFINE div_tank						.0			; x sampling rate [s]

; Attention: Information Lengths must be < 16 !
#DEFINE infolength_temperature			.2			; [byte]
#DEFINE infolength_deco					.2			; [byte]
#DEFINE infolength_gf					.1			; [byte]
#DEFINE infolength_ppo2_sensors			.9			; [byte]
#DEFINE infolength_decoplan				.15			; [byte]
#DEFINE infolength_cns					.2			; [byte]
#DEFINE infolength_tank					.0			; [byte]

; RX Functions (no conditional compile because defines are used in options_table)
#DEFINE rx_packet_overdue_timeout		.60			; [seconds]
#DEFINE max_pres_diff_min				.5			; [bar] minimum selectable pressure difference for ind.double mode
#DEFINE max_pres_diff_max				.50			; [bar] maximum selectable pressure difference for ind.double mode

; Gas Needs Settings
#DEFINE min_tank_size					.1			; [liter]
#DEFINE max_tank_size					.40			; [liter]
#DEFINE min_fill_press					.5			; [0 bar] value is in multiples of 10 bar
#DEFINE max_fill_press					.29			; [0 bar] value is in multiples of 10 bar, no 300 bar due to too far beyond ideal gas laws


;; "Better Gas" Behavior
;#DEFINE minimum_change_depth			.2			; [m]

; Dive Mode Limits and Thresholds
#DEFINE start_dive_threshold			.100		; [cm]
#DEFINE high_altitude_dive_threshold	.300		; [cm]
#DEFINE apnoe_timeout					.15			; [min]
#DEFINE divemode_menuview_timeout		.10			; [s]
#DEFINE divemode_menu_timeout			.30			; [s]

#DEFINE ppo2_warning_low_lowest			.15			; [cbar] (min.    value) for minimum on OC
#DEFINE ppo2_warning_low_default		.17			; [cbar] (default value) for minimum on OC
#DEFINE ppo2_warning_low_highest		.21			; [cbar] (max.    value) for minimum on OC

#DEFINE ppo2_warning_loop_lowest		.20			; [cbar] (min.    value) for minimum on loop
#DEFINE ppo2_warning_loop_default		.40			; [cbar] (default Value) for minimum on loop
#DEFINE ppo2_warning_loop_highest		.60			; [cbar] (max.    value) for minimum on loop

#DEFINE ppo2_warning_high_lowest		.120		; [cbar] (min.    value) for maximum in none-deco phase
#DEFINE ppo2_warning_high_default		.160		; [cbar] (default value) for maximum in none-deco phase
#DEFINE ppo2_warning_high_highest		.160		; [cbar] (max.    value) for maximum in none-deco phase

#DEFINE ppo2_warning_deco_lowest		.120		; [cbar] (min.    value) for maximum in deco phase
#DEFINE ppo2_warning_deco_default		.160		; [cbar] (default Value) for maximum in deco phase
#DEFINE ppo2_warning_deco_highest		.160		; [cbar] (max.    value) for maximum in deco phase

#DEFINE depth_warn_mbar					.13000		; [mbar]
#DEFINE wake_up_from_sleep				.1160		; [mbar]
#DEFINE simulator_timeout				.15			; [s]

#DEFINE sensor_voting_logic_threshold	.10			; threshold in 0.01 bar

; Surface Mode Limits and Thresholds
#DEFINE high_altitude_threshold			.880		; [mbar]
#DEFINE max_surfpressure				.1080		; [mbar]
#DEFINE timeout_surfacemode				.240		; [s]		; ex 90 seconds
#DEFINE timeout_calibrate_menu			.240		; [s]
#DEFINE timeout_tanksetup_menu			.240		; [s]
#DEFINE timeout_ccr_surface				.240		; [s]

; Deco-Model Parameters
#DEFINE deco_distance					.10			; [dm]

; Color-Code Parameters for the Dive Mode
#DEFINE color_code_velocity_warn_high	.11			; [m/min]
#DEFINE color_code_velocity_attn_high	.10			; [m/min]
#DEFINE velocity_display_threshold_1	.3			; [m/min]

; Battery Thresholds
 #DEFINE max_allowed_battery_temp			.500	; Max temperature before charging is disabled in 0.1°C	
 
#DEFINE lithium_36v_empty				.2400		; [mV] Saft 3.6 V LS14500 AA - threshold for battery percent display
#DEFINE lithium_36v_low					.2000		; [mV] (must be bigger than aa_15v_high!)
#DEFINE aa_15v_high						.1550		; [mV] Energizer 1.5 V E2 AA
#DEFINE aa_15v_low						.1100		; [mV] according to Energizer data sheet EBC-4201R, page 2
#DEFINE color_code_battery_low			.30			; [%]  also acts as threshold for setting brightness level ECO when in dive mode
#DEFINE battery_show_level				.24			; [%]

; 3.6 Volt Battery sensing Data Points at 70 mA Load
#DEFINE lithium_36v_75					.3000		; [mV]
#DEFINE lithium_36v_50					.2900		; [mV]
#DEFINE lithium_36v_25					.2600		; [mV]
#DEFINE lithium_36v_10					.2500		; [mV]

; Capacity for 2.4 Ah Saft LS14500 and 0.8 Ah Panasonic UR14500P
; battery_gauge:6 is nAs
; devide through 65536
;    a) devide through 364 -> result is in percent of a 2.4 Ah battery
; or b) devide through 121 -> result is in percent of a 0.8 Ah battery

; internal Battery Gauging
#DEFINE internal_saft_capacity			.364
#DEFINE internal_panasonic_capacity		.121

; Gauge IC
#DEFINE saft_capacity					.281		; 2.4Ah/0.085mAh/100 [%]
#DEFINE saft_offset						.37300		; 65536-(2.4Ah/0.085mAh)

#DEFINE panasonic_capacity				.94			; 0.8Ah/0.085mAh/100 [%]
#DEFINE panasonic_offset				.56124		; 65536-(0.8Ah/0.085mAh)

#DEFINE ncr18650_capacity				.364		; 3.1Ah/0.085mAh/100 [%]
#DEFINE ncr18650_offset					.29065		; 65536-(3.1Ah/0.085mAh)

#DEFINE ur16650_capacity				.271		; 2.3Ah/0.085mAh/100 [%]
#DEFINE ur16650_offset					.38477		; 65536-(2.3Ah/0.085mAh)

#DEFINE current_sleepmode				.31
#DEFINE current_backlight_multi			.115		; * CCPR1L + current_backlight_offset
#DEFINE current_backlight_offset		.216
#DEFINE current_speed_eco				.1914
#DEFINE current_speed_normal			.4027
#DEFINE current_speed_fastest			.5050
#DEFINE current_ir_receiver				.139
#DEFINE current_compass					.28

; Brightness Thresholds (between zero (off) and 255 (max. power))
#DEFINE ambient_light_max_high_36V		.170
#DEFINE ambient_light_max_high_cr		.240
#DEFINE ambient_light_max_high_15V		.140
#DEFINE ambient_light_min_high			.35
#DEFINE ambient_light_max_medium		.125
#DEFINE ambient_light_min_medium		.25
#DEFINE ambient_light_max_eco			.70
#DEFINE ambient_light_min_eco			.10			; must be the lowest value!

; IR Link Timeout
#DEFINE ir_timeout_value				.64			; multiples of 62.5 ms

; Setpoint Control
#DEFINE surface_sp						.50			; in cbar

; Gaslist hard-coded Limits
#DEFINE gaslist_min_o2					.6					; minimum O2 [%]
#DEFINE gaslist_max_He					.100-gaslist_min_o2	; maximum He [%]
#DEFINE gaslist_max_change_depth		.99			; max. change depth [m]
#DEFINE gaslist_sp_stepsize				.10			; steps for setpoint setup [cbar]
#DEFINE gaslist_sp_max					.160		; max. setpoint [cbar]
#DEFINE gaslist_sp_min					.50			; min. setpoint [cbar]

; Compass Display
#DEFINE compass_fast_treshold			.9			; show new heading instantly if new and old > compass_fast_treshold
#DEFINE compass_averaging				.10			; numbers of extra averaging


; Bit Flags for Communication with p2_deco.c - char_O_main_status
#DEFINE DECO_COMPLETED_NORM				.0			; the calculation of a normal       deco plan has just been completed
#DEFINE DECO_COMPLETED_ALT				.1			; the calculation of an alternative deco plan has just been completed
;       DECO_MODE_LOOP_FLAG				.2			; defined below, also used for char_O_main_status
;       DECO_MODE_PSCR_FLAG				.3			; defined below, also used for char_O_main_status
#DEFINE DECO_Z_FACTOR_FLAG				.4			; =1: figure in Z factor when converting gas volumes <-> pressures
#DEFINE DECO_CAVE_MODE					.5			; =1: compute ascent and gas needs using backtracking data
#DEFINE DECO_BOTTOM_FLAG				.6			; =1: compute with bottom time (deco calculator), =0: with extra time (dive mode)
#DEFINE DECO_TR_FUNCTIONS				.7			; =1: compute TR functions (pressure readings)

; Bit Flags for Communication with p2_deco.c - char_O_deco_status
#DEFINE DECO_STATUS_0_FLAG				.0
#DEFINE DECO_STATUS_1_FLAG				.1
#DEFINE DECO_MODE_LOOP_FLAG				.2
#DEFINE DECO_MODE_PSCR_FLAG				.3
#DEFINE DECO_PLAN_FLAG					.4
#DEFINE DECO_BAILOUT_FLAG				.5			; =1: do a bailout calculation, i.e. allow gas switches before first deco stop
#DEFINE DECO_VOLUME_FLAG				.6
#DEFINE DECO_ASCENT_FLAG				.7

; Bit Flags for Communication with p2_deco.c - char_O_deco_warnings
#DEFINE IBCD_warning					.0
#DEFINE IBCD_warning_lock				.1
#DEFINE mbubble_warning					.2
#DEFINE mbubble_warning_lock			.3
#DEFINE outside_warning					.4
#DEFINE outside_warning_lock			.5
#DEFINE outside_attention				.6
#DEFINE stoptable_overflow				.7

; Bit Flags for Communication with p2_deco.c - char_O_deco_info
#DEFINE deco_flag						.0			; =1: in deco mode, deco ppO2 levels permitted
#DEFINE ind_double_switch				.1			; =1: switch to other tank advice active
#DEFINE deco_steady						.2			; =1: fTTS is = TTS (not updated when in bailout mode)
#DEFINE deco_decreasing					.3			; =1: fTTS is < TTS (not updated when in bailout mode)
#DEFINE deco_ceiling					.4			; =1: ceiling depth > 0
#DEFINE gas_needs_cave					.5			; =1: indicated gas needs are calculated in cave mode

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
; Flags

; Hardware Descriptor 1
#DEFINE battery_gauge_available	hardware_flag1,0	; =1: OSTC has rechargeable battery with battery management chip
#DEFINE ambient_sensor			hardware_flag1,1	; =1: OSTC has an ambient light sensor
#DEFINE analog_o2_input			hardware_flag1,2	; =1: OSTC has analog inputs and S8 digital
#DEFINE optical_input			hardware_flag1,3	; =1: OSTC has an digital optical input
#DEFINE ble_available			hardware_flag1,4	; =1: OSTC has an BLE module
#DEFINE ostc_rx_present			hardware_flag1,5	; =1: OSTC has RX circuity
;								hardware_flag1,6	; --- unused
;								hardware_flag1,7	; --- unused

; Hardware Descriptor 2
#DEFINE screen_type			hardware_flag2,0	; =1: display 1, =0; display 0
#DEFINE compass_type			hardware_flag2,1	; =1: compass 1, =0: compass 0
#DEFINE compass_type2			hardware_flag2,2	; =1: compass 2, =0: compass 0 or 1
#DEFINE analog_switches			hardware_flag2,3	; =1: analog switches available
#DEFINE	screen_type2			hardware_flag2,4	; =1: display 2, =0: display 0 or 1
;								hardware_flag2,5	; --- unused
;								hardware_flag2,6	; --- unused
;								hardware_flag2,7	; --- unused

; Control of numerical Output
#DEFINE leftbind				cvt_flags+0,0
#DEFINE ignore_digit3			cvt_flags+0,1
#DEFINE ignore_digit4			cvt_flags+0,2
#DEFINE ignore_digit5			cvt_flags+0,3
;								cvt_flags+0,4		; --- unused
;								cvt_flags+0,5		; --- unused
;								cvt_flags+0,6		; --- unused
;								cvt_flags+0,7		; --- unused

#DEFINE pre_zero_flag			cvt_flags+1,0
#DEFINE all_zeros_flag			cvt_flags+1,1
#DEFINE DP_done					cvt_flags+1,2
#DEFINE DP_done2				cvt_flags+1,3
#DEFINE show_last3				cvt_flags+1,4
#DEFINE leading_zeros			cvt_flags+1,5
#DEFINE show_last4				cvt_flags+1,6
;								cvt_flags+1,7		; --- unused

; HUD Status Byte
#DEFINE hud_connection_ok		hud_status_byte,0	; =1 HUD connection ok
;								hud_status_byte,1	; =1 HUD is calibrated
;								hud_status_byte,2	; =1 HUD battery is low (<3000mV)
#DEFINE sensor1_active			hud_status_byte,3	; =1: sensor 1 is active
#DEFINE sensor2_active			hud_status_byte,4	; =1: sensor 2 is active
#DEFINE sensor3_active			hud_status_byte,5	; =1: sensor 3 is active
;								hud_status_byte,6	; --- unused in stand-alone HUD
;								hud_status_byte,7	; --- unused in stand-alone HUD

; General Flags
#DEFINE switch_left				flag1,0				; =1: left  button was pressed
#DEFINE switch_right			flag1,1				; =1: right button was pressed
#DEFINE neg_flag				flag1,2				; =1: result is negative, e.g. by sub16 (sub_c = sub_a - sub_b)
#DEFINE pressure_refresh		flag1,3				; =1: s new pressure/temperature is available
#DEFINE sleepmode				flag1,4				; =1: in sleep mode
#DEFINE tft_is_dimming			flag1,5				; =1: the TFT is dimming, ignore light sensor
#DEFINE display_velocity		flag1,6				; =1: show velocity
#DEFINE no_sensor_int			flag1,7				; =1: block any further access to pressure sensor

#DEFINE rs232_receive_overflow	flag2,0				; =1: a RS232 timeout overflow occurred
#DEFINE stored_gas_changed		flag2,1				; =1: stored Gas changed
#DEFINE high_altitude_mode		flag2,2				; =1: unit was manually turned on with ambient pressure <880mbar
#DEFINE FLAG_apnoe_mode			flag2,3				; =1: apnoe mode selected
#DEFINE restore_deco_data		flag2,4				; =1: restore deco data (After simulation)
#DEFINE premenu					flag2,5				; =1: pre-menu/dive menu selected
#DEFINE menubit					flag2,6				;     menu
#DEFINE simulatormode_active	flag2,7				; =1: simulator mode active, override pressure sensor readings

#DEFINE divemode_menu			flag3,0				; =1: dive mode menu is shown
#DEFINE onesecupdate			flag3,1				; =1: set any new second
#DEFINE onesectoggle			flag3,2				;     used for phasing every-2-seconds tasks
#DEFINE toggle_customview		flag3,3				; =1: next customview
#DEFINE oneminupdate			flag3,4				; =1: set any new minute
#DEFINE divemode				flag3,5				; =1: in dive mode
#DEFINE battery_is_36v			flag3,6				; =1: a 3.6 Volt battery is in use
#DEFINE message_warning			flag3,7				; =1: a warning is active in dive mode or surface mode

#DEFINE better_gas_available	flag4,0				; =1: a better gas is available
#DEFINE blinking_better_gas		flag4,1				; =1: gas is blinking
#DEFINE menuview				flag4,2				; =1: a menu view is shown in dive mode (e.g. "Menu?")
#DEFINE quarter_second_update	flag4,3				; =1: a new 1/4 second has begun
#DEFINE divemode_gaschange		flag4,4				; =1: the gas will change very soon
#DEFINE decostop_active			flag4,5				; =1: decompression stop shown
#DEFINE depth_greater_100m		flag4,6				; =1: current depth > 100 meters
#DEFINE realdive				flag4,7				; =1: a real dive during dive mode

#DEFINE dive_warning_displayed	flag5,0				; =1: the warning sign is shown
#DEFINE reset_average_depth		flag5,1				; =1: reset the average depth
#DEFINE store_sample			flag5,2				; =1: store a new sample
#DEFINE divemode2				flag5,3				; =1: dive longer than one minute
#DEFINE FLAG_active_descent		flag5,4				;     used in apnoe mode
#DEFINE event_occured			flag5,5				; =1: an event occurred, store it!
#DEFINE divemode_menu_active	flag5,6				; =1: the dive mode menu is shown
#DEFINE temp_changed			flag5,7				; =1: the temperature changed

#DEFINE gas6_changed			flag6,0				; =1: gas 6 has been selected/changed underwater
#DEFINE onehourupdate			flag6,1				; =1: a new hour has just begun
#DEFINE settime_setdate			flag6,2				; =1: in the Set Time or Set Date Menu
#DEFINE setpoint_changed		flag6,3				; =1: setpoint has been changed
#DEFINE second_row_warning		flag6,4				; =1: the second row contains a warning
#DEFINE FLAG_ccr_mode			flag6,5				; =1: CCR mode (fixed ppO2 or sensor) active
#DEFINE FLAG_back_to_loop		flag6,6				; =1: a switchback from bailout to loop occurred
#DEFINE FLAG_set_marker			flag6,7				; =1: set a marker in the logbook

#DEFINE better_gas_hint			flag7,0				; =1: mark a gas in yellow when it is a better gas
#DEFINE no_more_divesecs		flag7,1				; =1: do no longer show seconds in dive mode
#DEFINE FLAG_gauge_mode			flag7,2				; =1: in Gauge mode
#DEFINE ignore_last_edited_gas	flag7,3				;     used in gaslist_cleanup_list
#DEFINE FLAG_diluent_setup		flag7,4				; =1: setting up Diluents ("Gas6-10")
 IFDEF _rx_functions
#DEFINE FLAG_pairing_mode		flag7,5				; =1: in transmitter-to-tank pairing menu
 ENDIF
#DEFINE short_gas_decriptions	flag7,6				; =1: use short versions of gaslist_strcat_gas_cd and gaslist_strcat_setpoint
#DEFINE max_depth_greater_100m	flag7,7				; =1: max. depth > 100 meters

#DEFINE FLAG_bailout_mode		flag8,0				; =1: in bailout mode
#DEFINE is_bailout_menu			flag8,1				; =1: in bailout menu
#DEFINE toggle_gf				flag8,2				; =1: toggle GF/aGF
#DEFINE use_agf					flag8,3				; =1: use aGF (instead of GF)
#DEFINE battery_removed_in_usb	flag8,4				; =1: the battery has been removed in USB (probably not used for anything useful)
#DEFINE adc_running				flag8,5				; =1: the ADC is in use
#DEFINE comm_service_enabled	flag8,6				; =1: COMM Service mode unlocked
#DEFINE compass_enabled			flag8,7				; =1: the compass and accelerometer chip is active

#DEFINE compass_fast_mode		flag9,0				; =1: the compass is in fast mode
#DEFINE in_color_menu			flag9,1				; =1: in the color scheme menu
#DEFINE bailoutgas_event		flag9,2				; =1: bailout was selected or a gas change during bailout
#DEFINE win_invert				flag9,3				; =1: invert font output
#DEFINE show_safety_stop		flag9,4				; =1: show the safety stop
#DEFINE safety_stop_active		flag9,5				; =1: the safety stop is currently displayed
#DEFINE new_s8_data_available	flag9,6				; =1: new data frame received
#DEFINE print_compass_label		flag9,7				; =1: print the graphical compass label

#DEFINE s8_digital				flag10,0			; =1: digital I/O
#DEFINE menu_update_sensor_mv	flag10,1			; =1: update mV data in calibration menu
#DEFINE use_O2_sensor1			flag10,2			; =1: use this sensor
#DEFINE use_O2_sensor2			flag10,3			; =1: use this sensor
#DEFINE use_O2_sensor3			flag10,4			; =1: use this sensor
#DEFINE setpoint_fallback		flag10,5			; =1: fall-back to SP1 due to external O2 sensor failure
 IFDEF _screendump
#DEFINE enable_screen_dumps		flag10,6			; =1: ignore vin_usb, wait for "l" command (screen dump)
 ELSE
#DEFINE disable_comm_mode		flag10,6			; =1: ignore vin_usb
 ENDIF
#DEFINE flip_screen				flag10,7			; =1: screen is flipped by 180°

; flag11,* are not cleared on (re-)start
#DEFINE sensor1_calibrated_ok	flag11,0			; =1: this sensor has been calibrated ok
#DEFINE sensor2_calibrated_ok	flag11,1			; =1: this sensor has been calibrated ok
#DEFINE sensor3_calibrated_ok	flag11,2			; =1: this sensor has been calibrated ok
#DEFINE voting_logic_sensor1	flag11,3			; =1: this sensor is within the voting logic threshold
#DEFINE voting_logic_sensor2	flag11,4			; =1: this sensor is within the voting logic threshold
#DEFINE voting_logic_sensor3	flag11,5			; =1: this sensor is within the voting logic threshold
#DEFINE cc_active				flag11,6			; =1: constant current active (cR hardware)
#DEFINE cv_active				flag11,7			; =1: constant voltage active (cR hardware)

#DEFINE neg_flag_velocity		flag12,0			;     neg_flag backup for velocity logic
#DEFINE compass_bearing_eq		flag12,1			; =1: bearing is in direction, do not show << or >> 
#DEFINE compass_bearing_lft		flag12,2			; =1: bearing is to the left/<<, =0: to the right/>>
#DEFINE compass_bearing_vis		flag12,3			; =1: bearing is visible (either ahead or behind/-180°)
#DEFINE compass_bearing_ahd		flag12,4			; =1: bearing is ahead,   =0: behind
#DEFINE blinking_depth_warning	flag12,5			; =1: warning color, set by the color_depth
#DEFINE blinking_depth_prev		flag12,6			; =1: prev display had warning color, set by the TFT_depth
#DEFINE blinking_depth_toggle	flag12,7			;     toggle controlling blinking

; flag13,* are not cleared on (re-)start
#DEFINE compass_bearing_set		flag13,0			; =1: compass bearing is set
#DEFINE analog_sw1_pressed		flag13,1			; =1: analog switch 1 pressed
#DEFINE analog_sw2_pressed		flag13,2			; =1: analog switch 2 pressed
#DEFINE sp2_switched			flag13,3			; =1: this setpoint has been auto-selected already
#DEFINE sp3_switched			flag13,4			; =1: this setpoint has been auto-selected already
#DEFINE sp4_switched			flag13,5			; =1: this setpoint has been auto-selected already
#DEFINE sp5_switched			flag13,6			; =1: this setpoint has been auto-selected already
#DEFINE use_old_batt_flag		flag13,7			; =1: load old battery information after power-on reset

#DEFINE FLAG_pscr_mode			flag14,0			; =1: OSTC is in pSCR mode
#DEFINE deep_sleep				flag14,1			; =1: OSTC is in deep sleep (ignore buttons, etc)
#DEFINE sensors_agree			flag14,2			; =1: the ppO2 of all sensors are within the threshold range
#DEFINE gas_needs_attention		flag14,3			; =1: the gas needs attention      has been raised before
#DEFINE gas_needs_warning		flag14,4			; =1: the gas needs warning        has been raised before
#DEFINE sensor_warning			flag14,5			; =1: the sensors disagree warning has been raised before
#DEFINE alternative_divelayout	flag14,6			; =1: the alternative dive layout is used (aka "blind mode")
#DEFINE i2c_error_flag			flag14,7			; =1: an I2C error occurred

#DEFINE better_dil_available	flag15,0			; =1: a better diluent is available
#DEFINE blinking_better_dil		flag15,1			; =1: diluent is blinking
#DEFINE FLAG_oc_mode			flag15,2			; =1: OC mode active
#DEFINE message_attention		flag15,3			; =1: an attention is active in divem ode or surface mode
#DEFINE message_advice			flag15,4			; =1: an advice    is active in divem ode
#DEFINE blinking_depth_attention flag15,5			; =1: attention color, set by the color_depth
#DEFINE aux_flag				flag15,6			;     provided for local boolean storage
#DEFINE FLAG_tr_enabled			flag15,7			; =1: TR (pressure transmitter) functions enabled

 IFDEF _cave_mode
#DEFINE FLAG_cave_mode			flag16,0			; =1: in cave mode
#DEFINE FLAG_cave_mode_shutdown	flag16,1			; =1: cave mode has shut down due to bracktrack memory full
#DEFINE FLAG_dive_turned		flag16,2			; =1: dive is turned
#DEFINE toggle_turn_dive		flag16,3			; =1: toggle dive turned status
#DEFINE gas_needs_mode_last		flag16,4			; =1: last reported gas needs where computed in cave mode
 ENDIF
 IFDEF _rx_functions
#DEFINE menu_update_tank_pres	flag16,5			; =1: update tank pressure data in menu mode
 ENDIF
#DEFINE redraw_custview_mask	flag16,6			; =1: request to redraw the custom view mask
;								flag16,7			; --- unused

 IFDEF _rx_functions
#DEFINE transmitter1_lost		flag17,0			; =1: transmitter 1 lost               is an old message
#DEFINE transmitter1_battery	flag17,1			; =1: transmitter 1 battery low        is an old message
#DEFINE transmitter1_pres_warn	flag17,2			; =1: transmitter 1 pressure warning   is an old message
#DEFINE transmitter1_pres_att	flag17,3			; =1: transmitter 1 pressure attention is an old message
#DEFINE transmitter2_lost		flag17,4			; =1: transmitter 2 lost               is an old message
#DEFINE transmitter2_battery	flag17,5			; =1: transmitter 2 battery low        is an old message
#DEFINE transmitter2_pres_warn	flag17,6			; =1: transmitter 2 pressure warning   is an old message
#DEFINE transmitter2_pres_att	flag17,7			; =1: transmitter 2 pressure attention is an old message
 ENDIF
 
#DEFINE	battery_overtemp	flag18,0			; =1: The battery was charged and temp was too high (Only cleared on Reset)

; Low-Level Display Control
#DEFINE aa_antialias			aa_flags,0			;     used by aa_wordprocessor
#DEFINE aa_color_quart			aa_flags,1			;     used by aa_wordprocessor
#DEFINE aa_color_half			aa_flags,2			;     used by aa_wordprocessor
#DEFINE use_custom_colors		aa_flags,3			; =1: override default pixel colors, used by color_image
;								aa_flags,4			; --- unused
;								aa_flags,5			; --- unused
;								aa_flags,6			; --- unused
;								aa_flags,7			; --- unused


; Display Update Flags in Dive Mode
#DEFINE FLAG_TFT_divemode_mask				tft_update_flags+0,0	; =1: update the display
#DEFINE FLAG_TFT_display_ndl_mask			tft_update_flags+0,1	; =1: update the display
#DEFINE FLAG_TFT_depth						tft_update_flags+0,2	; =1: update the display
#DEFINE FLAG_TFT_divemins					tft_update_flags+0,3	; =1: update the display
#DEFINE FLAG_TFT_show_safety_stop			tft_update_flags+0,4	; =1: update the display
#DEFINE FLAG_TFT_display_ndl				tft_update_flags+0,5	; =1: update the display
#DEFINE FLAG_TFT_display_deko_mask			tft_update_flags+0,6	; =1: update the display
#DEFINE FLAG_TFT_display_deko				tft_update_flags+0,7	; =1: update the display
#DEFINE FLAG_TFT_display_tts				tft_update_flags+1,0	; =1: update the display
#DEFINE FLAG_TFT_temp_divemode				tft_update_flags+1,1	; =1: update the display
#DEFINE FLAG_TFT_divemode_warning			tft_update_flags+1,2	; =1: update the display
#DEFINE FLAG_TFT_divemode_warning_clear		tft_update_flags+1,3	; =1: update the display
#DEFINE FLAG_TFT_active_gas_divemode		tft_update_flags+1,4	; =1: update the display
#DEFINE FLAG_TFT_clear_safety_stop			tft_update_flags+1,5	; =1: update the display
#DEFINE FLAG_TFT_max_depth					tft_update_flags+1,6	; =1: update the display
#DEFINE FLAG_TFT_divemode_mask_alt			tft_update_flags+1,7	; =1: update the display
#DEFINE FLAG_TFT_dive_warning_text_clear	tft_update_flags+2,0	; =1: update the display
#DEFINE FLAG_TFT_dive_warning_text_clr2		tft_update_flags+2,1	; =1: update the display
#DEFINE FLAG_TFT_big_deco_alt				tft_update_flags+2,2	; =1: update the display
#DEFINE FLAG_TFT_display_ndl_or_deko		tft_update_flags+2,3	; =1: update the display
;											tft_update_flags+2,4	; unused
;											tft_update_flags+2,5	; unused
;											tft_update_flags+2,6	; unused
;											tft_update_flags+2,7	; unused


;---------------------------- Macros ------------------------------------

TSTOSS	macro opt_reg		; TeST Option Skip if not Zero
	movff	opt_reg,WREG	; Attention: destroys WREG!
	tstfsz	WREG,A			; Attention: the following command must be a
	bra		$+4				;            plain machine command, do not let
	endm					;            follow a macro!

;---------------------------- C-Code Routines ----------------------------

	extern	deco_calc_desaturation_time
	extern	deco_calc_hauptroutine
	extern	deco_calc_dive_interval
	extern	deco_calc_dive_interval_1min
	extern	deco_calc_dive_interval_10min
	extern	deco_clear_tissue
	extern	deco_pull_tissues_from_vault
	extern	deco_push_tissues_to_vault


;---------------------------- Bank0 DATA ------------------------------------
isr_backup	equ			0x60
isr_backup	udata_ovr	isr_backup			; reserved space for interrupt data


;---- Backup for general Registers
isr_prod						res 2

;---- MS5541 Subroutines
amb_pressure					res 2
temperature						res 2

C1								res 2		; decoded calibration data
C2								res 2
C3								res 2
C4								res 2		; here: C4-250
C5								res 2		; here: Reference Temperature UT1 = 8*C5 + 10000 (u16 range 10.000 .. +42.760)
C6								res 2
D1								res 2		; raw pressure
D2								res 2		; raw temperature
xdT								res 2
xdT2							res 2
OFF								res 2
SENS							res 2
dLSB							res 1		; pressure sensor interface 
dMSB							res 1
clock_count						res 1
sensor_state_counter			res 1		; counts to eight for state machine
amb_pressure_avg				res 2
temperature_avg					res 2
minimum_temperature				res 2		; minimum temperature
last_temperature				res 2
last_pressure					res 2
last_pressure_velocity			res 2		; for velocity
last_surfpressure				res 2
last_surfpressure_15min			res 2
last_surfpressure_30min			res 2
rel_pressure					res 2
sim_pressure					res 2		; hold simulated pressure in mbar if in Simulator mode
max_pressure					res 2
avg_rel_pressure				res 2
avg_rel_pressure_total			res 2

;---- Data for ISR Math Subroutines
isr_xC							res 4
isr_xA							res 2
isr_xB							res 2

;---- Data for ISR Routines
isr1_temp						res 1		; ISR temp variable, used in ms5541.asm, isr_rtcc, isr_battery_gauge
isr2_temp						res 1		; ISR temp variable, used isr_battery_gauge

;---- Display Brightness
max_CCPR1L						res 1		; max. brightness value for CCPR1L

;---- Battery Gauge (nAs, nC)
battery_gauge					res 6		; 48 bit -> 78 Ah max

;---- IR/S8-Link
ir_s8_buffer					res .18		; temporally used in get_calibration_data for the raw (packed) calibration data
ir_s8_counter					res 1
ir_s8_timeout					res 1		; timeout for valid data

;---- Compass raw Data
compass_DX						res 2
compass_DY						res 2
compass_DZ						res 2

accel_DX						res 2
accel_DY						res 2
accel_DZ						res 2

;---- Compass filtered Data
compass_DX_f					res 2
compass_DY_f					res 2
compass_DZ_f					res 2

accel_DX_f						res 2
accel_DY_f						res 2
accel_DZ_f						res 2

;---- Compass Calibration Data
compass_CX_f					res 2
compass_CY_f					res 2
compass_CZ_f					res 2

;---- Compass more Data
compass_heading					res 2		; corrected heading (in 1°) : -180 .. 180
compass_heading_old				res 2		; old heading (For smoother display)
compass_heading_shown			res 2		; displayed heading
;compass_roll					res 2		; rotation around the X axis
;compass_pitch					res 2		; rotation around the Y axis
compass_a						res 2		; tmp data for Q15 arithmetics
compass_b						res 2
compass_r						res 3

;---- Data for Logging
CNS_start						res 2		; CNS value at beginning of dive
GF_start						res 1		; GF  value at beginning of dive

;---- CPU mode
cpu_speed_request				res 1		; requested CPU speed: =1: eco, =2: normal, =3: fastest
cpu_speed_state					res 1		; current   CPU speed: =1: eco, =2: normal, =3: fastest

;---- Data for graphical Compass
xRD								res 2		; virtual compass ruler offset
xRDr							res 2		; virtual compass ruler offset - right end
xRD180							res 2		; virtual compass ruler offset for the -180 marker
xLO								res 1		; lo backup to prevent trashing
xHI								res 1		; hi backup to prevent trashing
xCM								res 1		; compass bearing relative position
compass_bearing					res 2		; this is where the bearing menu stores the actual heading for bearing

;---------------------------- Common DATA ------------------------------------
common		equ			0x100	; Alias for "banksel common"
common		udata_ovr	common	; Bank 1 general variables

;---- Time and Date
secs							res 1
mins							res 1
hours							res 1
day								res 1
month							res 1
year							res 1
surface_interval				res 2

;---- State Information
flag1							res 1
flag2							res 1
flag3							res 1
flag4							res 1
flag5							res 1
flag6							res 1
flag7							res 1
flag8							res 1
flag9							res 1
flag10							res 1
flag11							res 1
flag12							res 1
flag13							res 1
flag14							res 1
flag15							res 1
flag16							res 1
flag17							res 1
flag18							res 1
hardware_flag1					res 1		; hardware descriptor flags 1
hardware_flag2					res 1		; hardware descriptor flags 2
tft_update_flags				res 3

;---- Interface to Data Conversion &
;---- Output Functions, as well as
;---- General-Purpose Temp Storage
lo								res 1		; nickname for "low"    | Attention: do not change the
hi								res 1		; nickname for "high"   | relative positioning of these
up								res 1		; nickname for "upper"  | variables, lo will also be used
ex								res 1		; nickname for "extra"  | as base address for a 8, 16 and
ul								res 1		; nickname for "ultra"  | 32 bit buffer
ignore_digits					res 1

;---- Interface to Graphic Functions
win_leftx2						res 1
win_top							res 1
win_width						res 2
win_height						res 1
win_bargraph					res 1
win_color1						res 1
win_color2						res 1
win_color3						res 1	    ; For Display 2
win_color4						res 1	    ; For Display 2
win_color5						res 1	    ; For Display 2
win_font						res 1

;---- Interface to Math Functions
divA							res 2
xC								res 4
xA								res 2
xB								res 2
sub_c							res 2
sub_a							res 2
sub_b							res 2
math_loop						res 1		; internal variable used for loops

;---- Misc.
timeout_counter1				res 2		; timeout for dive operations
timeout_counter2				res 1		; timeout for menu operations
batt_voltage					res 2		; battery voltage in mV
batt_percent					res 1		; battery in percent (1-100)
message_counter					res 1		; counts amount of messages
message_page					res 1		; current # of message page
pairing_slot					res 1		; slot number, used in transmitter pairing


;---- Dive Mode / General
divemins						res 2
divesecs						res 1
total_divetime_seconds			res 2
average_divesecs				res 2		; time accumulator for the resettable stopwatch / average depth
average_divesecs_total			res 2		; time accumulator for the total average depth
curr_depth						res 1		; current depth in meters
amb_press_10					res 2		; ambient pressure divided by 10
safety_stop_countdown			res 1		; counts seconds of safety stop
gaslist_gas						res 1		; used for transfer between gaslist.asm and menu_tree.asm
best_gas_number					res 1		; number of the "best gas": 0= none found, 1-5= gases 1-5, 255= not computed
best_dil_number					res 1		; number of the "best dil": 0= none found, 1-5= dils  1-5, 255= not computed
active_gas						res 1		; the currently used OC/bailout gas (1-5)
active_dil						res 1		; the currently used diluent (1-5)

;---- Dive Mode / Apnoe
apnoe_surface_mins				res 1
apnoe_surface_secs				res 1
apnoe_mins						res 1
apnoe_secs						res 1
apnoe_max_pressure				res 2

;---- Profile Recording
samplingrate					res 1
samplesecs						res 1
samplesecs_value				res 1
AlarmType						res 1
EventByte1						res 1
EventByte2						res 1

;---- External Flash
ext_flash_rw					res 1		; transfer register for data read / write
ext_flash_address				res 3		; 24 bit address
ext_flash_log_pointer			res 3		; 24 bit address for logbook profile storing
ext_flash_end_pointer			res 3		; 24 bit address for logbook profile storing
ext_flash_dive_counter			res 3		; 24 bit counter for dive length (increased in write_byte_ext_flash_plus)

;---- O2 Sensor Data
o2_mv_sensor1					res 2		; in 0.1mV steps
o2_mv_sensor2					res 2		; in 0.1mV steps
o2_mv_sensor3					res 2		; in 0.1mV steps
o2_ppo2_sensor1					res 1		; sensor 1 ppO2 (in 0.01 bar steps)
o2_ppo2_sensor2					res 1		; sensor 2 ppO2 (in 0.01 bar steps)
o2_ppo2_sensor3					res 1		; sensor 3 ppO2 (in 0.01 bar steps)
hud_status_byte					res 1


;========================= private Variables ===================================
;        do not access from outside of the respective source files!

;---- aa_wordprocessor.asm
aa_flags						res 1		; various flags for aa_wordprocessor
aa_bitlen						res 1		; count of pixels when decoding bitmaps
aa_start						res 2		; PROM ptr to start of encoded bitmap
aa_end							res 2		; and end of it
aa_temp							res 2		; current color, divided by 2 or 4

;--- adc_lightsensor.asm
get_bat_volt_counter			res 1		; counter for 10x reading the charger chip

;---- convert.asm
cvt_flags						res 2
cvt_temp1						res 1
cvt_temp2						res 1
cvt_temp3						res 1
cvt_temp4						res 1
lo_temp							res 1
hi_temp							res 1

;---- color_processor.asm
img_pixels						res 3		; used by color_processor.asm
img_count						res 2		; used by color_processor.asm

;---- comm.asm
comm_timeout					res 1		; timeout for communication

;---- eeprom_rs232.asm
uart1_temp						res 1
uart2_temp						res 1
uart3_temp						res 1

;---- i2c.asm
i2c_temp1						res 1		; temporary data
i2c_temp2						res 1		; temporary data

;---- menu_processor.asm
menupos1						res 1		; logbook and dive mode menu
menupos2						res 1		; used for dive mode simulator and pre-menu
menupos3						res 1		; used for custom views
menupos4						res 1		; used for dive mode menu
menu_flags						res 1		; flags for menu entries
menu_item						res 1		; index of the current item
start_item						res 1		; index of the first item (scrolling)
item_max						res 1		; number of items in menu
selected_item					res 1		; index of the current item
value_type						res 1		; type for vertical menu
dynamic_item					res 3		; callback addr
menu_block						res 3		; address of the menu block (i.e. item 0)
menu_title						res 3		; text or proc for dynamic menu
menu_center						res 1		; centering for line menu
proc_item						res 3		; address of the current proc
text_item						res 2		; address of the current text

;---- options.asm
opt_type						res 1		;
opt_default						res 1		;
opt_inc							res 1		; also used for default+1 (string) and enum low
opt_min							res 1		; also used for enum high
opt_max							res 1		;
opt_unit						res 2		; multi-lingual unit text
opt_eeprom						res 1		;
opt_backup_tbl					res 3		; buffer for table pointer

;---- tft.asm
save_top						res 1
save_height						res 1
save_left						res 1
save_width						res 1
tft_temp1						res 1
tft_temp2						res 1
tft_temp3						res 1
tft_temp4						res 1

 IFDEF _screendump
;---- Screendump Function
ds_line							res 1		; current line (0..239)     (dump screen function)
ds_column						res 1		; current columnx2 (0..159) (dump screen function)
ds_pixel						res 2		; current pixel color       (dump screen function)
ds_count						res 1		; repetition count          (dump screen function)
 ENDIF

;---- wait.asm
wait_counter					res 1

; ==> 202 bytes used - 6 bytes free


;============================ LOCAL DATA ======================================
; Space for various overlayed local data from top-level applications,
; i.e. applications that never run in parallel to each other
;
; --------------------- local Data Users --------------------------------------
;					-------------- Applications using -------------
;	Mode			local1				local2				local3
; -----------------------------------------------------------------------------
;	sleepmode		sleepmode.asm		(unused)			(unused)
;	surfmode		surfmode.asm*		(unused)			(unused)
;	simulator		simulator.asm		(unused)			(unused)
;	divemode		divemode.asm		divemode.asm		ghostwriter.asm
;	logbook			logboock.asm		logbook.asm			logbook.asm
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
common2		equ			0xA00	; Alias for "banksel common2"
common2		udata_ovr	common2	; Bank 10 general variables

s8_rawdata_sensor1				res 3		; 24 bit A/D raw data from S8 HUD sensor 1
s8_rawdata_sensor2				res 3		; 24 bit A/D raw data from S8 HUD sensor 2
s8_rawdata_sensor3				res 3		; 24 bit A/D raw data from S8 HUD sensor 3
hud_battery_mv					res 2		; hud/ppo2 monitor battery voltage in mV

start_year						res 1		; at start of dive (for logbook)          | ATTENTION: do not change the position of these
start_month						res 1		; at start of dive (for logbook)          |            variables relative to each other!
start_day						res 1		; at start of dive (for logbook)          |
start_hours						res 1		; at start of dive (for logbook)          |
start_mins						res 1		; at start of dive (for logbook)          |

opt_gas_type_backup				res 5		; 0=Disabled, 1=First, 2=Travel, 3=Deco   | ATTENTION: do not change the position of these
opt_dil_type_backup				res 5		; 0=Disabled, 1=First, 2=Normal           |            arrays relative to each other!

internal_battery_capacity		res 2		; For internal battery gauging
battery_capacity				res 2		; For battery gauge IC
battery_offset					res 2		; For battery gauge IC
battery_type					res 1		; =0:1.5V, =1:3.6V Saft, =2:LiIon 3.7V/0.8Ah, =3:LiIon 3.7V/3.1Ah, =4: LiIon 3.7V/2.3Ah
battery_acumulated_charge		res 2		; Raw values in battery gauge IC
gauge_status_byte				res 1		; Gauge IC status byte
battery_temperature			res 2		; in 0.1°C

analog_sw1_raw					res 2		; idle values (average)
analog_sw2_raw					res 2		; idle values (average)
analog_counter					res 1		; for averaging
analog_sw1						res 1		; analog value for switch 1
analog_sw2						res 1		; analog value for switch 2
button_polarity					res 1		; 0xFF (both normal), 0x00 (both inverted), 0x01 (left inverted only), 0x02 (right inverted only)

uptime							res 4		; Uptime [s]
lastdive_time					res 4		; Time since last dive [s]
lastdive_duration				res 3		; mins:2 and secs
lastdive_maxdepth				res 2		; in mbar

customview_surfmode				res 1		; storage to remember last selected custom view in surface mode
customview_divemode				res 1		; storage to remember last selected custom view in dive mode

ambient_light					res 2		; ambient_light level
old_velocity					res 4		; stores the last 4 speeds (8 seconds) in m/min

menustack						res 5		; menu stack from menu_processor.asm

gas6_O2_ratio					res 1		; gas6 O2 ratio
gas6_He_ratio					res 1		; gas6 He ratio
gas6_temp						res 1		; temp used in divemenu_tree.asm

 IFDEF _rx_functions
; Data exchange
rx_buffer						res .48		; Buffer for RX data (slots 0-7)
rx_firmware						res 2		; RX firmware version xx.yy

; Variables for SAC Calculation on Pressure Readings 1 & 2
pres_accu_1st					res 4		; accumulator for pressure drop    in 1/160 bar  | ATTENTION: do not
pres_accu_2nd					res 4		; accumulator for pressure drop    in 1/160 bar  |            change the
time_accu_1st					res 1		; accumulator for reading ages     in seconds    |            position
gas__last_1st					res 1		; last gas assignment                            |            of these
time_accu_2nd					res 1		; accumulator for reading ages     in seconds    |            variables
gas__last_2nd					res 1		; last gas assignment                            |            relative
pres_last_1st					res 2		; last pressure reading pressure   in 1/160 bar  |            to each
pres_last_2nd					res 2		; last pressure reading pressure   in 1/160 bar  |            other!
time_last_1st					res 2		; last pressure reading time       in seconds    |
time_last_2nd					res 2		; last pressure reading time       in seconds    |
 ENDIF

; ==> 138 bytes used - 118 bytes free


;----------------------- Bank 2 General Purpose Buffer -------------------------
; Reserved for general purpose buffer (strings, images, etc).
; NOTE: Needs to be aligned with a bank (LOW(buffer)==0).

buffer		udata_ovr	0x200

buffer							res	.256	; used for string assembly / display output


;---------------------- Bank 14 Options Table ---------------------------------
opt_table	equ			0xE00
opt_table	udata_ovr	opt_table

;---- Dive Options
opt_gas_O2_ratio				res 5		; O2 ratios of OC/bailout gases                              | ATTENTION:
opt_dil_O2_ratio				res 5		; O2 ratios of diluents                                      | keep relative
opt_gas_He_ratio				res 5		; He ratios of OC/bailout gases                              | positioning of
opt_dil_He_ratio				res 5		; He ratios of diluents                                      | all arrays in
opt_gas_type					res 5		; OC/bailout gas type: O=Disabled, 1=First, 2=Travel, 3=Deco | this block!
opt_dil_type					res 5		;            dil type: 0=Disabled, 1=First, 2=Normal         |
opt_gas_change					res 5		; change depths for OC/Bailout gases                         |
opt_dil_change					res 5		; change depths for diluents                                 |

opt_dive_mode					res 1		; main dive/deco mode: =0: OC, =1: CC, =2: Gauge, =3: Apnea, =4: pSCR
opt_ccr_mode					res 1		; CCR/pSCR sub   mode: =0: fixed/calculated SP, =1: sensor, =2: auto SP

;---- Managing Settings
opt_brightness					res 1		; =0: Eco, =1:Medium, =2:Full
opt_salinity					res 1		; 0-5%
#DEFINE opt_name_length			.60			; custom text string 5 rows with 12 chars
opt_name						res opt_name_length
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
opt_cR_button_left				res 1		; left button sensitivity (cR hardware)
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

; RX functions - no conditional compilation because used in options_table
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

; ==> 173 bytes used - 85 bytes free

;-----------------------------------------------------------------------------
