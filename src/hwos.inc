;=============================================================================
;
;   File hwos.inc									REFACTORED VERSION V2.97 SP1
;
;   OSTC Platform definitions
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;   2011-05-24 : [jDG] Cleanups from initial Matthias code.

;=============================================================================

	LIST	P=18F87K22		; change also: Configure->SelectDevice from Mplab

;#DEFINE __DEBUG

;#DEFINE french_italian		; If defined, use french and italian instead of english and german

#include <p18f87k22.inc>
#include <ports.inc>		; Portmap

; Firmware definition
#DEFINE softwareversion_x		.2			; Software version  XX.YY
#DEFINE softwareversion_y		.98			; Software version  XX.YY
#DEFINE softwareversion_beta	.0			; 0= release, 1=beta, 2=SP1, 3=SP2, ...

; Firmware version will appear in "Change Firmware" style
#DEFINE firmware_expire_year	.19
#DEFINE firmware_expire_month	.8
#DEFINE firmware_expire_day	.27

#DEFINE comm_service_key		0xABCDEF

;-----------------------------EEPROM DATA ------------------------------------
; Automatic reset of all options when this is changed:
#define eeprom_opt_serial		0x0006		; Version 0.6
;-----------------------------------------------------------------------------

#DEFINE CCP1CON_VALUE					b'00001100'	; PWM1 for LED dimming
#DEFINE T2CON_ECO						b'00000100'	; 1:1 Postscaler, 1:1 Prescaler, Timer 2 start -> 980Hz (Good compromise of no-flicker and efficiency)
#DEFINE T2CON_NORMAL					b'00001110'
#DEFINE T2CON_FASTEST					b'00001110'	; 1:2 Postscaler, 1:16 Prescaler, Timer 2 start -> 1960Hz (no-flicker)

; Timing for button hold-down flags
#DEFINE TMR1H_VALUE_FIRST				.255-.128	; in steps of 7,8125ms -> 1s
#DEFINE TMR1H_VALUE_CONT				.255-.32	; in steps of 7,8125ms -> 0.25s
#DEFINE TMR1H_VALUE_CONT_DIVE			.255-.64	; in steps of 7,8125ms -> 0.5s

; Color Definitions: 8Bit RGB b'RRRGGGBB'
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

; External O2 cell input parameters
#DEFINE min_mv							.80			; = 8mV
#DEFINE max_mv							.2500		; = 250mV
#DEFINE ignore_mv						.3500		; = 350mV (to suppress ghost readings for long, open cables)

; Profile recording parameters
#DEFINE logbook_profile_version			0x24
#DEFINE samplingrate_apnoe				.1			; [seconds]

; Warning: Divisors must be <.16 !
#DEFINE div_temperature					.6			; x samplingrate [s]
#DEFINE div_deco						.6			; x samplingrate [s]
#DEFINE div_gf							.12			; x samplingrate [s]
#DEFINE div_ppo2_sensors				.2			; x samplingrate [s]
#DEFINE div_decoplan					.12			; x samplingrate [s]
#DEFINE div_cns							.12			; x samplingrate [s]
#DEFINE div_tank						.0			; x samplingrate [s]

; Warning: Information lengths must be <.16 !
#DEFINE infolength_temperature			.2			; [byte]
#DEFINE infolength_deco					.2			; [byte]
#DEFINE infolength_gf					.1			; [byte]
#DEFINE infolength_ppo2_sensors			.9			; [byte]
#DEFINE infolength_decoplan				.15			; [byte]
#DEFINE infolength_cns					.2			; [byte]
#DEFINE infolength_tank					.0			; [byte]

; "Better Gas" behavior
; better_gas_window <= minimum_change_depth !
; minimum_change_depth >=5 !
#DEFINE minimum_change_depth			.3			; [m]
#DEFINE better_gas_window_neg			.3			; [m] (Depth above change depth)
#DEFINE better_gas_window_pos			.1			; [m] (Depth below change depth, if ppO2<opt_ppO2_max)

; Dive mode limits and thresholds
#DEFINE start_dive_threshold			.100		; [cm]
#DEFINE high_altitude_dive_threshold	.300		; [cm]
#DEFINE apnoe_timeout					.15			; [min]
#DEFINE divemode_menuview_timeout		.10			; [s]
#DEFINE divemode_menu_timeout			.30			; [s]

#DEFINE ppo2_warning_low_lowest			.16			; [cbar] (Min.    value) for minimum on OC
#DEFINE ppo2_warning_low_default		.19			; [cbar] (Default value) for minimum on OC
#DEFINE ppo2_warning_low_highest		.21			; [cbar] (Max.    value) for minimum on OC

#DEFINE ppo2_warning_loop_lowest		.20			; [cbar] (Min.    value) for minimum on loop
#DEFINE ppo2_warning_loop_default		.40			; [cbar] (Default Value) for minimum on loop
#DEFINE ppo2_warning_loop_highest		.60			; [cbar] (Max.    value) for minimum on loop

#DEFINE ppo2_warning_high_lowest		.120		; [cbar] (Min.    value) for maximum in none-deco phase
#DEFINE ppo2_warning_high_default		.140		; [cbar] (Default value) for maximum in none-deco phase
#DEFINE ppo2_warning_high_highest		.160		; [cbar] (Max.    value) for maximum in none-deco phase

#DEFINE ppo2_warning_deco_lowest		.120		; [cbar] (Min.    value) for maximum in deco phase
#DEFINE ppo2_warning_deco_default		.160		; [cbar] (Default Value) for maximum in deco phase
#DEFINE ppo2_warning_deco_highest		.160		; [cbar] (Max.    value) for maximum in deco phase

#DEFINE depth_warn_mbar					.13000		; [mbar]
#DEFINE wake_up_from_sleep				.1160		; [mbar]
#DEFINE simulator_timeout				.15			; [s]

#DEFINE sensor_voting_logic_threshold	.10			; Threshold in 0.01bar

; Surface mode limits and thresholds
#DEFINE high_altitude_threshold			.880		; [mbar]
#DEFINE max_surfpressure				.1080		; [mbar]
#DEFINE timeout_surfacemode				.90			; [s]
#DEFINE timeout_calibrate_menu			.240		; [s]
#DEFINE timeout_ccr_surface				.240		; [s]

; Decomodel paramters
#DEFINE deco_distance					.10			; [dm]

; Color-code parameters for the divemode
#DEFINE color_code_velocity_warn_high	.11			; [m/min]
#DEFINE color_code_velocity_attn_high	.10			; [m/min]
#DEFINE velocity_display_threshold_1	.3			; [m/min]

; Battery thresholds
#DEFINE lithium_36v_empty				.2400		; [mV] Saft 3,6V LS14500 AA - threshold for battery percent display
#DEFINE lithium_36v_low					.2000		; [mV] (Must be bigger then aa_15v_high!)
#DEFINE aa_15v_high						.1550		; [mV] Energizer 1,5V E2 AA
#DEFINE aa_15v_low						.1100		; [mV] According to Energizer Datasheet EBC-4201R, Page 2
#DEFINE color_code_battery_low			.10			; [%]
#DEFINE battery_show_level				.24			; [%]

; 3,6V battery sensing data points at 70mA load
#DEFINE lithium_36v_75					.3000		; [mV]
#DEFINE lithium_36v_50					.2900		; [mV]
#DEFINE lithium_36v_25					.2600		; [mV]
#DEFINE lithium_36v_10					.2500		; [mV]
	
; Capacity for 2.4Ah Saft LS14500 and 0.8Ah Panasonic UR14500P
; battery_gauge:6 is nAs
; devide through 65536
;    a) devide through 364 -> Result is in percent of a 2.4Ah Battery
; or b) devide through 121 -> Result is in percent of a 0.8Ah Battery

; For internal battery gauging
#DEFINE internal_saft_capacity			.364
#DEFINE internal_panasonic_capacity		.121

; For gauge IC	
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

; Brightness thresholds (between zero (off) and 255 (max. power))
#DEFINE ambient_light_max_high_36V		.170
#DEFINE ambient_light_max_high_cr		.240
#DEFINE ambient_light_max_high_15V		.140
#DEFINE ambient_light_min_high			.35
#DEFINE ambient_light_max_medium		.125
#DEFINE ambient_light_min_medium		.25
#DEFINE ambient_light_max_eco			.70
#DEFINE ambient_light_min_eco			.10			; must be the lowest value!

; IR Link timeout
#DEFINE ir_timeout_value				.64			; multiples of 62,5ms

; Sp control constants
#DEFINE surface_sp						.50			; in cbar

; Gaslist hard-coded limits
#DEFINE gaslist_min_o2					.5					; Minimum O2 [%]
#DEFINE gaslist_max_He					.100-gaslist_min_o2	; Maximum He [%]

#DEFINE gaslist_max_change_depth		.99			; Max. change depth [m]
#DEFINE gaslist_sp_stepsize				.10			; Steps for Setpoint Setup [cbar]
#DEFINE gaslist_sp_max					.160		; Max. Setpoint [cbar]
#DEFINE gaslist_sp_min					.50			; Min. Setpoint [cbar]

; Compass display
#DEFINE compass_fast_treshold			.9			; show new heading instantly if new and old > compass_fast_treshold
#DEFINE compass_averaging				.10			; numbers of extra averaging

; Bit Masks	for communication with p2_deco.c - char_O_deco_status
#define DECO_STATUS_MASK				.3

; Bit Flags for communication with p2_deco.c - char_O_deco_status
#define DECO_STATUS_0_FLAG				.0
#define DECO_STATUS_1_FLAG				.1
#define DECO_MODE_LOOP_FLAG				.2
#define DECO_MODE_PSCR_FLAG				.3
#define DECO_PLAN_FLAG					.4
#define DECO_CNS_FLAG					.5
#define DECO_VOLUME_FLAG				.6
#define DECO_ASCENT_FLAG				.7

; Bit Flags for communication with p2_deco.c - char_O_main_status
;										.0			; unused
;										.1			; unused
;       DECO_MODE_LOOP_FLAG				.2			; defined below, also used for char_O_main_status
;       DECO_MODE_PSCR_FLAG				.3			; defined below, also used for char_O_main_status
#define DECO_GASCHANGE_OVRD				.4
;										.5			; unused
#define DECO_BOTTOM_FLAG				.6
;										.7			; unused

; Bit Values for communication with p2_deco.c
#define DECO_STATUS_INIT				.3
#define DECO_MODE_LOOP					.4
#define DECO_MODE_PSCR					.8
#define DECO_PLAN_ALTERNATE				.16
#define DECO_CNS_CALCULATE				.32
#define DECO_VOLUME_CALCULATE			.64
#define DECO_ASCENT_DELAYED				.128

; Bit Flags for char_O_deco_warnings
#define IBCD_warning					.0
#define IBCD_warning_lock				.1
#define mbubble_warning					.2
#define mbubble_warning_lock			.3
#define outside_warning					.4
#define outside_warning_lock			.5
#define stoptable_overflow				.6
#define deco_flag						.7

; Bit Flags for status on CHARs
#define char_invalid_flag				.7

; Bit Flags for status on INTs
#define int_invalid_flag				.2
#define int_not_yet_computed			.3
#define int_is_zero						.3
#define int_low_flag					.4
#define int_high_flag					.5
#define int_attention_flag				.6
#define int_warning_flag				.7

;-----------------------------------------------------------------------------
; Flags

; Hardware defines
#DEFINE battery_gauge_available	hardware_flag,0		; =1: OSTC has rechargeable battery with battery management chip
#DEFINE ambient_sensor			hardware_flag,1		; =1: OSTC has an ambient light sensor
#DEFINE analog_o2_input			hardware_flag,2		; =1: OSTC has analog inputs and S8 digital
#DEFINE optical_input			hardware_flag,3		; =1: OSTC has an digital optical input
#DEFINE ble_available			hardware_flag,4		; =1: OSTC has an BLE module
#DEFINE ostc_rx_present			hardware_flag,5		; =1: OSTC RX circuity present
;								hardware_flag,6		; unused
;								hardware_flag,7		; unused

#DEFINE leftbind				cvt_flags+0,0
#DEFINE ignore_digit3			cvt_flags+0,1
#DEFINE ignore_digit4			cvt_flags+0,2
#DEFINE ignore_digit5			cvt_flags+0,3
#DEFINE enable_screen_dumps		cvt_flags+0,4		; =1: Ignore vin_usb, wait for "l" command (Screen dump
#DEFINE screen_type				cvt_flags+0,5		; =1: display1, =0; display0
#DEFINE compass_type			cvt_flags+0,6		; =1: compass1, =0: compass0
#DEFINE analog_switches			cvt_flags+0,7		; =1: Analog switches available

#define pre_zero_flag			cvt_flags+1,0
#define all_zeros_flag			cvt_flags+1,1
#define DP_done					cvt_flags+1,2
#define DP_done2				cvt_flags+1,3
#define show_last3				cvt_flags+1,4
#define leading_zeros			cvt_flags+1,5
#define show_last4				cvt_flags+1,6
#DEFINE compass_type2			cvt_flags+1,7		; =1: Compass2, =0: Compass1 or compass0


; HUD Status Byte
#DEFINE hud_connection_ok		hud_status_byte,0	; =1 -> HUD connection ok
;								hud_status_byte,1	; =1 -> HUD is calibrated
;								hud_status_byte,2	; =1 -> HUD Battery is low (<3000mV)
#DEFINE sensor1_active			hud_status_byte,3	; =1: Sensor1 is active
#DEFINE sensor2_active			hud_status_byte,4	; =1: Sensor2 is active
#DEFINE sensor3_active			hud_status_byte,5	; =1: Sensor3 is active
;								hud_status_byte,6	; unused in stand-alone HUD
;								hud_status_byte,7	; unused in stand-alone HUD

#DEFINE switch_left				flag1,0				; =1: left  button was pressed
#DEFINE switch_right			flag1,1				; =1: right button was pressed
#DEFINE neg_flag				flag1,2				;     e.g. sub16 (sub_c = sub_a - sub_b)
#DEFINE pressure_refresh		flag1,3				; =1: A new pressure/temperature is available
#DEFINE sleepmode				flag1,4				; =1: in Sleepmode
#DEFINE tft_is_dimming			flag1,5				; =1: the TFT is dimming, ignore light sensor
#DEFINE display_velocity		flag1,6				; =1: show velocity
#DEFINE no_sensor_int			flag1,7				; =1: block any further access to pressure sensor

#DEFINE rs232_receive_overflow	flag2,0				; =1: a RS232 timeout overflow occoured
#DEFINE stored_gas_changed		flag2,1				; =1: Stored Gas changed
#DEFINE high_altitude_mode		flag2,2				; =1: unit was manually turned on with ambient pressure <880mbar
#DEFINE FLAG_apnoe_mode			flag2,3				; =1: Apnoe mode selected
#DEFINE restore_deco_data		flag2,4				; =1: restore deco data (After simulation)
#DEFINE premenu					flag2,5				; =1: Premenu/Divemenu selected
#DEFINE menubit					flag2,6				;     menu
#DEFINE simulatormode_active	flag2,7				; =1: simulator mode active, override pressure sensor readings

#DEFINE divemode_menu			flag3,0				; =1: divemode menu is shown
#DEFINE onesecupdate			flag3,1				; =1: after any second
#DEFINE twosecupdate			flag3,2				; =1: new two-second update
#DEFINE toggle_customview		flag3,3				; =1: next customview
#DEFINE oneminupdate			flag3,4				; =1: after any minute
#DEFINE divemode				flag3,5				; =1: in Divemode
#DEFINE battery_is_36v			flag3,6				; =1: 3,6V Battery is in use
#DEFINE warning_active			flag3,7				; =1: a warning is active in divemode or surfacemode

#DEFINE better_gas_available	flag4,0				; =1: a better gas is available
#DEFINE blinking_better_gas		flag4,1				; =1: gas is blinking
#DEFINE menuview				flag4,2				; =1: a menuview is shown in divemode (e.g. "Menu?")
#DEFINE quarter_second_update	flag4,3				; =1: a new 1/4 second has begun
#DEFINE divemode_gaschange		flag4,4				; =1: the gas will change very soon
#DEFINE decostop_active			flag4,5				; =1: decompression stop shown
#DEFINE depth_greater_100m		flag4,6				; =1: current depth > 100m
#DEFINE realdive				flag4,7				; =1: a real dive during divemode

#DEFINE dive_warning_displayed	flag5,0				; =1: the warning sign is shown
#DEFINE reset_average_depth		flag5,1				; =1: reset the average depth
#DEFINE store_sample			flag5,2				; =1: store a new sample
#DEFINE divemode2				flag5,3				; =1: dive longer than one minute
#DEFINE FLAG_active_descent		flag5,4				;     used in Apnoe mode
#DEFINE event_occured			flag5,5				; =1: an event occured, store it!
#DEFINE divemode_menu_active	flag5,6				; =1: the divemode menu is shown
#DEFINE temp_changed			flag5,7				; =1: the temperature changed

#DEFINE gas6_changed			flag6,0				; =1: gas 6 has been selected/changed underwater
#DEFINE onehourupdate			flag6,1				; =1: a new hour has just begun
#DEFINE settime_setdate			flag6,2				; =1: in the Set Time or Set Date Menu
#DEFINE setpoint_changed		flag6,3				; =1: setpoint has been changed
#DEFINE second_row_warning		flag6,4				; =1: the second row contains a warning
#DEFINE FLAG_ccr_mode			flag6,5				; =1: CCR mode (fixed ppO2 or sensor) active
#DEFINE FLAG_back_to_loop		flag6,6				; =1: a switchback from bailout to loop occured
#DEFINE FLAG_set_marker			flag6,7				; =1: set a marker in the logbook

;								flag7,0				; unused
#DEFINE no_more_divesecs		flag7,1				; =1: Do no longer show seconds in divemode
#DEFINE FLAG_gauge_mode			flag7,2				; =1: In Gauge mode
#DEFINE ignore_last_edited_gas	flag7,3				;     Used in gaslist_cleanup_list
#DEFINE ccr_diluent_setup		flag7,4				; =1: Setting up Diluents ("Gas6-10")
#DEFINE space_gas_decriptions	flag7,5				; =1: add a space in front of gas numbers < 9 for alignment
#DEFINE short_gas_decriptions	flag7,6				; =1: Use short versions of gaslist_strcat_gas_mod and gaslist_strcat_setpoint
#DEFINE max_depth_greater_100m	flag7,7				; =1: Max. Depth > 100m

#DEFINE is_bailout				flag8,0				; =1: Bailout
#DEFINE is_bailout_menu			flag8,1				; =1: Bailout
#DEFINE toggle_gf				flag8,2				; =1: Toggle GF/aGF
#DEFINE use_agf					flag8,3				; =1: Use aGF (instead of GF)
#DEFINE battery_removed_in_usb	flag8,4				; =1: The battery has been removed in USB (probably not used for anything useful)
#DEFINE adc_running				flag8,5				; =1: The ADC is in use
#DEFINE comm_service_enabled	flag8,6				; =1: COMM Service mode unlocked
#DEFINE compass_enabled			flag8,7				; =1: The compass and accelerometer chip is active

#DEFINE compass_fast_mode		flag9,0				; =1: The compass is in fast mode
#DEFINE in_color_menu			flag9,1				; =1: In the color scheme menu
#DEFINE bailoutgas_event		flag9,2				; =1: bailout was selected or a gaschange during bailout
#DEFINE win_invert				flag9,3				; =1: Invert font output
#DEFINE show_safety_stop		flag9,4				; =1: Show the safety stop
#DEFINE safety_stop_active		flag9,5				; =1: The safety stop is currently displayed
#DEFINE new_s8_data_available	flag9,6				; =1: New data frame received
#DEFINE print_compass_label		flag9,7				; =1: print the graphical comapss label

#DEFINE s8_digital				flag10,0			; =1: Digital I/O
#DEFINE menu_show_sensors2		flag10,1			; =1: Update mV data in calibration menu
#DEFINE use_O2_sensor1			flag10,2			; =1: Use this sensor
#DEFINE use_O2_sensor2			flag10,3			; =1: Use this sensor
#DEFINE use_O2_sensor3			flag10,4			; =1: Use this sensor
#DEFINE setpoint_fallback		flag10,5			; =1: Fallback to SP1 due to external O2 sensor failure
#DEFINE blinking_setpoint		flag10,6			; =1: SP is blinking
#DEFINE flip_screen				flag10,7			; =1: Screen is flipped by 180°

#DEFINE sensor1_calibrated_ok	flag11,0			; =1: This sensor has been calibrated ok
#DEFINE sensor2_calibrated_ok	flag11,1			; =1: This sensor has been calibrated ok
#DEFINE sensor3_calibrated_ok	flag11,2			; =1: This sensor has been calibrated ok
#DEFINE voting_logic_sensor1	flag11,3			; =1: This sensor is within the voting logic threshold
#DEFINE voting_logic_sensor2	flag11,4			; =1: This sensor is within the voting logic threshold
#DEFINE voting_logic_sensor3	flag11,5			; =1: This sensor is within the voting logic threshold
#DEFINE cc_active				flag11,6			; =1: Constant Current active (cR Hardware)
#DEFINE cv_active				flag11,7			; =1: Constant Voltage active (cR Hardware)

#DEFINE neg_flag_velocity		flag12,0			; neg_flag backup for velocity logic
#DEFINE compass_bearing_eq		flag12,1			; bearing is in direction? do not show << or >> 
#DEFINE compass_bearing_lft		flag12,2			; bearing is to the left/<< if set, otherwise to the right/>>
#DEFINE compass_bearing_vis		flag12,3			; bearing is visible? (either ahead or behind/-180°)
#DEFINE compass_bearing_ahd		flag12,4			; bearing is ahead or behind?
#DEFINE blinking_depth_warning	flag12,5			; set by the color_depth. =1: warning color
#DEFINE blinking_depth_prev		flag12,6			; set by the TFT_depth.   =1: prev display had warning color
#DEFINE blinking_depth_toggle	flag12,7			; toggle to blink

#DEFINE compass_bearing_set		flag13,0			; bearing set
#DEFINE analog_sw1_pressed		flag13,1			; =1: Analog switch 1 pressed
#DEFINE analog_sw2_pressed		flag13,2			; =1: Analog switch 2 pressed
#DEFINE sp2_switched			flag13,3			; =1: This setpoint has been autoselected already
#DEFINE sp3_switched			flag13,4			; =1: This setpoint has been autoselected already
#DEFINE sp4_switched			flag13,5			; =1: This setpoint has been autoselected already
#DEFINE sp5_switched			flag13,6			; =1: This setpoint has been autoselected already
#DEFINE use_old_batt_flag		flag13,7			; =1: load old battery information after power-on reset

#DEFINE FLAG_pscr_mode			flag14,0			; =1: OSTC is in PSCR mode
#DEFINE deep_sleep				flag14,1			; =1: OSTC is in deep sleep (ignore buttons, etc)
#DEFINE sensors_agree			flag14,2			; =1: the ppO2 of all sensors are within the threshold range
#DEFINE gas_needs_attention		flag14,3			; =1: the gas needs attention      has been raised before
#DEFINE gas_needs_warning		flag14,4			; =1: the gas needs warning        has been raised before
#DEFINE sensor_warning			flag14,5			; =1: the sensors disagree warning has been raised before
#DEFINE alternative_divelayout	flag14,6			; =1: the alternative divelayout is used (aka Blind Mode)
#DEFINE i2c_error_flag			flag14,7			; =1: an I2C error occured

#define aa_antialias			aa_flags,0			; used by aa_wordprocessor
#define aa_color_quart			aa_flags,1			; used by aa_wordprocessor
#define aa_color_half			aa_flags,2			; used by aa_wordprocessor
;								aa_flags,3			; unused
;								aa_flags,4			; unused
;								aa_flags,5			; unused
;								aa_flags,6			; unused
;								aa_flags,7			; unused


; Update flags in divemode, =1: Update the screen
#DEFINE FLAG_TFT_divemode_mask				tft_update_flags+0,0
#DEFINE FLAG_TFT_display_ndl_mask			tft_update_flags+0,1
#DEFINE FLAG_TFT_depth						tft_update_flags+0,2
#DEFINE FLAG_TFT_divemins					tft_update_flags+0,3
#DEFINE FLAG_TFT_show_safety_stop			tft_update_flags+0,4
#DEFINE FLAG_TFT_display_ndl				tft_update_flags+0,5
#DEFINE FLAG_TFT_display_deko_mask			tft_update_flags+0,6
#DEFINE FLAG_TFT_display_deko				tft_update_flags+0,7
#DEFINE FLAG_TFT_display_tts				tft_update_flags+1,0
#DEFINE FLAG_TFT_temp_divemode				tft_update_flags+1,1
#DEFINE FLAG_TFT_divemode_warning			tft_update_flags+1,2
#DEFINE FLAG_TFT_divemode_warning_clear		tft_update_flags+1,3
#DEFINE FLAG_TFT_active_gas_divemode		tft_update_flags+1,4
#DEFINE FLAG_TFT_clear_safety_stop			tft_update_flags+1,5
#DEFINE FLAG_TFT_max_depth					tft_update_flags+1,6
#DEFINE FLAG_TFT_divemode_mask_alt			tft_update_flags+1,7
#DEFINE FLAG_TFT_dive_warning_text_clear	tft_update_flags+2,0
#DEFINE FLAG_TFT_dive_warning_text_clr2		tft_update_flags+2,1
#DEFINE FLAG_TFT_max_depth_alt				tft_update_flags+2,2
#DEFINE FLAG_TFT_big_deco_alt				tft_update_flags+2,3
;											tft_update_flags+2,4	; unused
;											tft_update_flags+2,5	; unused
;											tft_update_flags+2,6	; unused
;											tft_update_flags+2,7	; unused


;---------------------------- Macros ------------------------------------

TSTOSS	macro opt_reg		; TeST Option Skip if not Zero
	movff	opt_reg,WREG
	tstfsz	WREG,A
	bra		$+4
	endm

;---------------------------- C-code Routines ----------------------------

	extern	deco_calc_desaturation_time
	extern	deco_calc_hauptroutine
	extern	deco_calc_dive_interval_1min
	extern	deco_calc_dive_interval_10min
	extern	deco_calc_dive_interval
	extern	deco_clear_tissue
	extern	deco_pull_tissues_from_vault
	extern	deco_push_tissues_to_vault


;---------------------------- Bank0 DATA ------------------------------------
isr_backup	equ			0x60
isr_backup	udata_ovr	isr_backup			; Reserved space for interupt data
 
;---- Backup for general registers
isr_prod						res 2

;---- MS5541 subroutines
amb_pressure					res 2
temperature						res 2

C1								res 2		; Decoded calibration data
C2								res 2
C3								res 2
C4								res 2		; Here: C4-250
C5								res 2		; Here: Reference Temperature UT1 = 8*C5 + 10000 (u16 range 10.000 .. +42.760)
C6								res 2
D1								res 2		; raw pressure
D2								res 2		; raw temperature
xdT								res 2
xdT2							res 2
OFF								res 2
SENS							res 2
dLSB							res 1		; Pressure sensor interface 
dMSB							res 1
clock_count						res 1
sensor_state_counter			res 1		; counts to eight for state maschine
amb_pressure_avg				res 2
temperature_avg					res 2
minimum_temperature				res 2		; minimum temperature
last_temperature				res 2
last_pressure					res 2
last_pressure_velocity			res 2		; For velocity
last_surfpressure				res 2
last_surfpressure_15min			res 2
last_surfpressure_30min			res 2
rel_pressure					res 2
sim_pressure					res 2		; hold simulated pressure in mbar if in Simulator mode
max_pressure					res 2
avg_rel_pressure				res 2
avg_rel_pressure_total			res 2

;---- Data for ISR math subroutines
isr_xC							res 4
isr_xA							res 2
isr_xB							res 2

;---- Data for ISR routines
isr1_temp						res 1		; ISR temp variable, used in ms5541.asm, isr_rtcc, isr_battery_gauge
isr2_temp						res 1		; ISR temp variable, used isr_battery_gauge

;---- Display brightness
max_CCPR1L						res 1		; Max. brightness value for CCPR1L

; Battery gauge (nAs, nC)
battery_gauge					res 6		; 48Bit -> 78Ah max...

; IR/S8-Link
ir_s8_buffer					res .18		; temporally used in get_calibration_data for the raw (packed) calibration data
ir_s8_counter					res 1
ir_s8_timeout					res 1		; Timeout for valid data

; Compass raw data
compass_DX						res 2
compass_DY						res 2
compass_DZ						res 2

accel_DX						res 2
accel_DY						res 2
accel_DZ						res 2

; Compass FILTERED data
compass_DX_f					res 2
compass_DY_f					res 2
compass_DZ_f					res 2

accel_DX_f						res 2
accel_DY_f						res 2
accel_DZ_f						res 2

; Compass calibration data
compass_CX_f					res 2
compass_CY_f					res 2
compass_CZ_f					res 2

; Compass more data
compass_heading					res 2		; Corrected heading (in 1°) : -180 .. 180
compass_heading_old				res 2		; Old heading (For smoother display)
compass_heading_shown			res 2		; Displayed heading
;compass_roll					res 2		; Rotation around the X axis
;compass_pitch					res 2		; Rotation around the Y axis

compass_a						res 2		; Tmp data for Q15 arithmetics
compass_b						res 2
compass_r						res 3

CNS_start						res 2		; CNS value at beginning of dive
GF_start						res 1		; GF value at beginning of dive

speed_setting					res 1		; =1: Eco, =2: Normal, =3: Fastest

;---- Data for graphical compass
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
hardware_flag					res 1		; hardware descriptor flag
tft_update_flags				res 3

;---- Interface to Data Conversion &
;---- Output Functions, as well as
;---- General-Purpose Temp Storage
lo								res 1
hi								res 1
up								res 1
ignore_digits					res 1

;---- Interface to Graphic Functions
win_leftx2						res 1
win_top							res 1
win_width						res 2
win_height						res 1
win_bargraph					res 1
win_color1						res 1
win_color2						res 1
win_font						res 1

;---- Interface to Math Functions
divA							res 2
divB							res 1
xC								res 4
xA								res 2
xB								res 2
sub_c							res 2
sub_a							res 2
sub_b							res 2

;---- Misc.
timeout_counter1				res 2		; timeout for dive operations
timeout_counter2				res 1		; timeout for menu operations
batt_voltage					res 2		; battery voltage in mV
batt_percent					res 1		; battery in percent (1-100)
warning_counter					res 1		; counts amount of warning in divemode
warning_page					res 1		; current # of warning page

;---- Dive Mode / General
divemins						res 2
divesecs						res 1
total_divetime_seconds			res 2
average_divesecs				res 2		; for the resettable stopwatch
safety_stop_countdown			res 1		; counts seconds of safety stop
gaslist_gas						res 1		; used for transfer between gaslist.asm and menu_tree.asm
active_gas						res 1		; the currently breathed gas (1-5)
;active_gas_type				res 1		; 0=Disabled, 1=First, 2=Travel, 3=Deco for OC gases and 0=Disabled, 1=First, 2=Normal for diluents	

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
o2_ppo2_sensor1					res 1		; Sensor1 ppO2 (in 0.01bar steps)
o2_ppo2_sensor2					res 1		; Sensor2 ppO2 (in 0.01bar steps)
o2_ppo2_sensor3					res 1		; Sensor3 ppO2 (in 0.01bar steps)
hud_status_byte					res 1


;========================= privte Variables ===================================
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
menupos1						res 1		; logbook and divemode menu
menupos2						res 1		; used for dive mode simulator and pre-menu
menupos3						res 1		; used for Customviews
menupos4						res 1		; used for divemode menu
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
ds_line							res 1		; current line (0..239)
ds_column						res 1		; current columnx2 (0..159)
ds_pixel						res 2		; current pixel color
ds_count						res 1		; repetition count
tft_temp1						res 1
tft_temp2						res 1
tft_temp3						res 1
tft_temp4						res 1

;---- wait.asm
wait_counter					res 1

; ==> 187 bytes used - 21 bytes free


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
;	divemode		divemode.asm		ghostwriter.asm		(unused)
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

s8_rawdata_sensor1				res 3		; 24bit A/D raw data from S8 HUD sensor 1
s8_rawdata_sensor2				res 3		; 24bit A/D raw data from S8 HUD sensor 2
s8_rawdata_sensor3				res 3		; 24bit A/D raw data from S8 HUD sensor 3
hud_battery_mv					res 2		; hud/ppo2 monitor battery voltage in mV

start_day						res 1		; At start of dive (For logbook)
start_month						res 1		; At start of dive (For logbook)
start_year						res 1		; At start of dive (For logbook)
start_hours						res 1		; At start of dive (For logbook)
start_mins						res 1		; At start of dive (For logbook)

opt_gas_type_backup				res 5		; 0=Disabled, 1=First, 2=Travel, 3=Deco			* need to be in same bank
opt_dil_type_backup				res 5		; 0=Disabled, 1=First, 2=Normal					+ need to be in same bank
opt_OC_bail_gas_change_backup	res 5		; Gas change depths OC/Bailout					*
opt_dil_change_backup			res 5		; Gas change depths Diluents					+

internal_battery_capacity		res 2		; For internal battery gauging
battery_capacity				res 2		; For battery gauge IC
battery_offset					res 2		; For battery gauge IC
battery_type					res 1		; =0:1.5V, =1:3,6V Saft, =2:LiIon 3,7V/0.8Ah, =3:LiIon 3,7V/3.1Ah, =4: LiIon 3,7V/2.3Ah
battery_acumulated_charge		res 2		; Raw values in battery gauge IC
gauge_status_byte				res 1		; Gauge IC status byte

analog_sw1_raw					res 2		; idle values (average)
analog_sw2_raw					res 2		; idle values (average)
analog_counter					res 1		; for averaging
analog_sw1						res 1		; analog value for switch 1
analog_sw2						res 1		; analog value for switch 2
button_polarity					res 1		; 0xFF (Both normal), 0x00 (Both inverted), 0x01 (Left inverted only), 0x02 (Right inverted only)

uptime							res 4		; Uptime [s]
lastdive_time					res 4		; Time since last dive [s]
lastdive_duration				res 3		; mins:2 and secs
lastdive_maxdepth				res 2		; in mbar

rx_buffer						res .48		; Buffer for RX data (Slots 0-7)
rx_firmware						res 2		; The RX firmware version xx.yy

customview_surfmode				res 1		; storage to remember last selected custom view in surface mode
customview_divemode				res 1		; storage to remember last selected custom view in dive mode

ambient_light					res 2		; ambient_light level
better_gas_number				res 1		; number (1-5) of the "better gas" in divemode, =0: no better gas available
old_velocity					res 4		; Stores the last 4 speeds (8 seconds) in m/min

menustack						res 5		; menu stack from menu_processor.asm

gas6_O2_ratio					res 1		; gas6 O2 ratio
gas6_He_ratio					res 1		; gas6 He ratio
gas6_temp						res 1		; temp used in divemenu_tree.asm

; ==> 134 bytes used - 122 bytes free


;---------------------------- Bank 2 general purpose buffer -------------------
; Reserved for general purpose buffer (strings, images, etc).
; NOTE: Needs to be aligned with a bank (LOW(buffer)==0).

buffer		udata_ovr	0x200

buffer							res	.256


;---------------------------- Bank 14 for options table -----------------------
opt_table	equ			0xE00
opt_table	udata_ovr	opt_table

;---- Dive Options
opt_gas_O2_ratio				res 5		; Needed because deco gaslist use N2
opt_dil_O2_ratio				res 5		; Must be in line with opt_gas_O2_ratio
opt_gas_He_ratio				res 5		; He ratio Gas1-5
opt_dil_He_ratio				res 5		; Must be in line with opt_gas_He_ratio
opt_gas_type					res 5		; 0=Disabled, 1=First, 2=Travel, 3=Deco
opt_dil_type					res 5		; 0=Disabled, 1=First, 2=Normal ; Must be in line with opt_gas_type
opt_dive_mode					res 1		; 0=OC, 1=CC, 2=Gauge, 3=Apnea, 4=PSCR
opt_ccr_mode					res 1		; =0: Fixed SP, =1: Sensor
opt_OC_bail_gas_change			res 5		; Gas change depths OC/Bailout

;---- Managing Settings
opt_brightness					res 1		; =0: Eco, =1:Medium, =2:Full
opt_salinity					res 1		; 0-5%
#DEFINE opt_name_length			.60			; Custom text string 5 rows with 12 chars
opt_name						res opt_name_length
opt_language					res 1		; Current language. 0=EN, 1=DE, 2=FR, 3=SP
opt_units						res 1		; 0:m/°C, 1:ft/°F
opt_dateformat					res 1		; =0:MMDDYY, =1:DDMMYY, =2:YYMMDD
opt_last_stop					res 1		; =3:3m, =4:4m, =5:5m, =6:6m
opt_aGF_high					res 1		; Alternative GF HIGH
opt_aGF_low						res 1		; Alternative GF LOW
opt_GF_high						res 1		; GF HIGH
opt_GF_low						res 1		; GF LOW
opt_enable_aGF					res 1		; =1: aGF can be selected underwater
opt_compass_gain				res 1		; 0-7 (230LSB/Gauss to 1370LSB/Gaus)
opt_sampling_rate				res 1		; =1: 10s, =0: 2s
opt_dive_color_scheme			res 1		; 0-3
opt_pressure_adjust				res 1		; SIGNED char (two's complement), -20/+20mbar max.
opt_enable_safetystop			res 1		; =1: A safety stop is shown
opt_calibration_O2_ratio		res 1		; %O2 of calibration gas
opt_x_s1						res	2		; calibration factor (Not stored in EEPROM)
opt_x_s2						res	2		; calibration factor (Not stored in EEPROM)
opt_x_s3						res	2		; calibration factor (Not stored in EEPROM)
opt_sensor_fallback				res 1		; NOT USED ANY MORE, KEPT FOR COMPATIBILITY WITH EEPROM IMAGE
opt_flip_screen					res 1		; =1: Flip the screen
opt_cR_button_left				res 1		; Left button sensitivity (cR hardware)
opt_cR_button_right				res 1		; Right button sensitivity (cR hardware)
opt_modwarning					res 1		; =1:do a red blinking warning, =0:default behaviour
opt_vsitextv2					res 1		; =1:use the depth dependent ascend rate limits
opt_vsigraph					res 1		; =1:draw the graphical VSI bar
opt_showppo2					res 1		; =1:always show the ppO2 value in the warning position
opt_temperature_adjust			res 1		; SIGNED char (two's complement), -2.0/+2.0 °C max.
opt_safety_stop_length			res 1		; [s]
opt_safety_stop_start			res 1		; [cbar]
opt_safety_stop_end				res 1		; [cbar]
opt_safety_stop_reset			res 1		; [cbar]
opt_diveTimeout					res 1		; Timeout for Divemode [min]
opt_sim_setpoint_number			res 1		; setpoint to use for deco calculation
opt_calc_asc_gasvolume			res 1		; calculate OC gas volume needs for ascent
opt_sim_use_aGF					res 1		; =0: use GF, =1: use aGF for deco calculation
opt_enable_IBCD					res 1		; enable IBCD warning
opt_sat_multiplier_gf			res 1		; Buhlmann safety factor for GF deco
opt_desat_multiplier_gf			res 1		; Buhlmann safety factor for GF deco
opt_sat_multiplier_non_gf		res 1		; Buhlmann safety factor for NON-GF deco
opt_desat_multiplier_non_gf		res 1		; Buhlmann safety factor for NON-GF deco

;-----------------------------------------------------------------------------
