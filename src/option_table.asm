;=============================================================================
;
;   File option_table.asm                     combined next generation V3.04.3
;
;   The Option Table
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;   2014-08-03 : mH creation
;

#include "hwos.inc"					; Mandatory Header
#include "eeprom_rs232.inc"

;=============================================================================
; Options Tables

option_table	CODE 0x00700

OPTION_UINT8	MACRO lbl, min, max, default, unit, eeprom, register
		global	lbl
lbl:	db		.0, default			; type0 = INT8
		db		.1, min
		db		max, eeprom
		dw		unit
		dw		register
		ENDM

OPTION_UINT8d	MACRO lbl, min, max, default, unit, eeprom, register
		global	lbl
lbl:	db		.3, default			; type3 = INT8 with automatic display in meters or feet
		db		.1, min
		db		max, eeprom
		dw		unit
		dw		register
		ENDM

OPTION_UINT8p2	MACRO lbl, min, max, default, unit, eeprom, register
		global	lbl
lbl:	db		.0, default			; type0 = INT8
		db		.2, min
		db		max, eeprom
		dw		unit
		dw	register
		ENDM

OPTION_UINT8p3	MACRO lbl, min, max, default, unit, eeprom, register
		global	lbl
lbl:	db		.0, default			; type0 = INT8
		db		.3, min
		db		max, eeprom
		dw		unit
		dw		register
		ENDM

OPTION_UINT8p3d	MACRO lbl, min, max, default, unit, eeprom, register
		global	lbl
lbl:	db		.3, default			; type3 = INT8 with automatic display in meters or feet
		db		.3, min
		db		max, eeprom
		dw		unit
		dw		register
		ENDM

OPTION_UINT8p5	MACRO lbl, min, max, default, unit, eeprom, register
		global	lbl
lbl:	db		.0, default			; type0 = INT8
		db		.5, min
		db		max, eeprom
		dw		unit
		dw		register
		ENDM

OPTION_UINT8p10	MACRO lbl, min, max, default, unit, eeprom, register
		global	lbl
lbl:	db		.0, default			; type0 = INT8
		db		.10, min
		db		max, eeprom
		dw		unit
		dw		register
		ENDM

OPTION_ENUM8	MACRO lbl, max, default, tValue, eeprom, register
		global	lbl
		extern	tValue
lbl:	db		.1, default			; type1 = ENUM
		db		LOW(tValue), HIGH(tValue)
		db		max, eeprom
		dw		.0					; no unit
		dw		register
		ENDM

OPTION_BOOL		MACRO lbl, default, eeprom, register
		OPTION_ENUM8 lbl, 2, default, tNo, eeprom, register
		ENDM

OPTION_STRING	MACRO lbl, length, defText, eeprom, register
		global	lbl
lbl:	db		.2, LOW(defText)	; type2 = STRING
		db		HIGH(defText), 0
		db		length, eeprom
		dw		.0					; no unit
		dw		register
		ENDM


;=============================================================================
	extern	tPercent, tMeters, tMinutes, tGasDisabled, tbar, tNo, tTrModeOff, tTrPresNone, tDefName, tblank, tLogTunitC, tTissuePresSat
	extern	char_I_dive_interval, char_I_bottom_time, char_I_bottom_depth
	extern	char_I_deco_model
	extern	char_I_extra_time
	extern	char_I_SAC_work, char_I_SAC_deco, tLitersMinute
	extern	char_I_PSCR_drop, char_I_PSCR_lungratio
	extern	char_I_gas_avail_size, char_I_gas_avail_pres, tLiter, tbar10
	extern	char_I_CC_max_frac_O2
	extern	char_I_altitude_wait
	extern	char_I_ppO2_max_work, char_I_ppO2_min, char_I_ppO2_max_deco, char_I_ppO2_min_loop
	extern	char_I_ascent_speed, char_I_descent_speed, tMeterMinute
	extern	char_I_gas_change_time
	extern	char_I_max_pres_diff
	extern	char_I_gas_density_att, char_I_gas_density_warn
	extern	char_I_dil_ppO2_check

 IFDEF _gas_contingency
	extern	char_I_gas_contingency
 ENDIF


;	Option Table - Format:
;	----------------------
;	OPTION_UINT8	Label,				min,			max,		  default, unit text,	EEPROM location, RAM location
;	OPTION_ENUM8	Label,				number of enums				  default, unit text,	EEPROM location, RAM location	; number of enums = 2, 3, ..., default starts with 0
;	OPTION_BOOL		Label,											  default,				EEPROM location, RAM location

#DEFINE notext		.0		; no text-string associated
#DEFINE volatile	-1		; do not store to EEPROM


	global	option_table_begin
option_table_begin:
;=============================================================================
; Manage Deco Planer & Dive Parameters
	OPTION_ENUM8	oDiveMode,			.5,								.0,		tDvOC,			.8,		opt_dive_mode					; 0=OC, 1=CC, 2=Gauge, 3=Apnea, 4=PSCR
	OPTION_ENUM8	oDecoMode,			.2,								.1,		tZHL16,			.9,		char_I_deco_model				; 0 = ZH-L16, 1 = ZH-L16-GF
	;																							.10										; in use, see below
	OPTION_UINT8d	oLastDeco,			.3,				.6,				.3,		tMeters,		.11,	opt_last_stop					; depth of the last deco stop
	OPTION_UINT8	oGF_low,			.10,			.100,			.30,	tPercent,		.12,	opt_GF_low						; normal GF low
	OPTION_UINT8	oGF_high,			.45,			.110,			.85,	tPercent,		.13,	opt_GF_high						; normal GF high
	OPTION_UINT8p5	osatmultgf,			.100,			.140,			.100,	tPercent,		.14,	opt_sat_multiplier_gf			; saturation factor   for GF mode
	OPTION_UINT8p5	odesatmultgf,		.60,			.100,			.100,	tPercent,		.15,	opt_desat_multiplier_gf			; desaturation factor for GF mode
	;																							.16										; in use, see below
	OPTION_UINT8	oaGF_low,			.10,			.100,			.30,	tPercent,		.17,	opt_aGF_low						; alternative GF low
	OPTION_UINT8	oaGF_high,			.45,			.110,			.85,	tPercent,		.18,	opt_aGF_high					; alternative GF high
	OPTION_BOOL		oEnable_aGF,		.0,														.19,	opt_enable_aGF					; =1: aGF can be selected underwater
	OPTION_UINT8	oCompassGain,		.0,				.7,				.6,		tMinutes,		.20,	opt_compass_gain				; 0-7 (230LSB/Gauss to 1370LSB/Gauss)
	OPTION_ENUM8	oSamplingRate,		.2,								.0,		tSetSeconds,	.21,	opt_sampling_rate				; =1: 10s, =0: 2s

;=============================================================================
; Managing Settings
	OPTION_UINT8	oExtraTime,			.0,				.9,				.0,		tMinutes,		.22,	char_I_extra_time				; extra bottom time for future TTS calculation
	OPTION_ENUM8	oBrightness,		.3,								.0,		tEco,			.23,	opt_brightness					; =0: Eco, =1:Medium, =2:Full
	OPTION_UINT8	oDiveSalinity,		.0,				.4,				.0,		tPercent,		.24,	opt_salinity					; 0-4%
	OPTION_ENUM8	oCCRMode,			.3,								.0,		tCCRModeFixedSP,.25,	opt_ccr_mode					; =0: Fixed SP, =1: Sensor, =2: Auto SP
	OPTION_ENUM8	oLanguage,			.2,								.0,		tLang1,			.26,	opt_language					; language selection
	OPTION_ENUM8	oDateFormat,		.3,								.1,		tDateformat,	.27,	opt_dateformat					; =0:MMDDYY, =1:DDMMYY, =2:YYMMDD
	OPTION_ENUM8	oUnits,				.2,								.0,		tMetric,		.28,	opt_units						; =0:Meter, =1:Feet

;=============================================================================
; Compass calibration data
	OPTION_UINT8	oCalx0,				.0,				.255,			.0,		notext,			.29,	compass_CX_f+0					; compass calibration data x, low  byte
	OPTION_UINT8	oCalx1,				.0,				.255,			.0,		notext,			.30,	compass_CX_f+1					;                          x, high byte
	OPTION_UINT8	oCaly0,				.0,				.255,			.0,		notext,			.31,	compass_CY_f+0					;                          y, low  byte
	OPTION_UINT8	oCaly1,				.0,				.255,			.0,		notext,			.32,	compass_CY_f+1					;                          y, high byte
	OPTION_UINT8	oCalz0,				.0,				.255,			.0,		notext,			.33,	compass_CZ_f+0					;                          z, low  byte
	OPTION_UINT8	oCalz1,				.0,				.255,			.0,		notext,			.34,	compass_CZ_f+1					;                          z, high byte

;=============================================================================
; Gas list
	OPTION_ENUM8	oGas1,				.3,								.1,		tGasDisabled,	.35,	opt_gas_type+0					; gas type: 0=Disabled, 1=First, 2=Travel, 3=Deco
	OPTION_ENUM8	oGas2,				.3,								.0,		tGasDisabled,	.36,	opt_gas_type+1
	OPTION_ENUM8	oGas3,				.3,								.0,		tGasDisabled,	.37,	opt_gas_type+2
	OPTION_ENUM8	oGas4,				.3,								.0,		tGasDisabled,	.38,	opt_gas_type+3
	OPTION_ENUM8	oGas5,				.3,								.0,		tGasDisabled,	.39,	opt_gas_type+4
	OPTION_UINT8	oGas1O2,			gaslist_min_o2,	.100,			.21,	tPercent,		.40,	opt_gas_O2_ratio+0				; O2 % of gas 1
	OPTION_UINT8	oGas1He,			.0,				gaslist_max_He,	.0,		tPercent,		.41,	opt_gas_He_ratio+0				; He % of gas 1 
	OPTION_UINT8	oGas2O2,			gaslist_min_o2,	.100,			.21,	tPercent,		.42,	opt_gas_O2_ratio+1
	OPTION_UINT8	oGas2He,			.0,				gaslist_max_He,	.0,		tPercent,		.43,	opt_gas_He_ratio+1
	OPTION_UINT8	oGas3O2,			gaslist_min_o2,		.100,		.21,	tPercent,		.44,	opt_gas_O2_ratio+2
	OPTION_UINT8	oGas3He,			.0,				gaslist_max_He,	.0,		tPercent,		.45,	opt_gas_He_ratio+2
	OPTION_UINT8	oGas4O2,			gaslist_min_o2,	.100,			.21,	tPercent,		.46,	opt_gas_O2_ratio+3
	OPTION_UINT8	oGas4He,			.0,				gaslist_max_He,	.0,		tPercent,		.47,	opt_gas_He_ratio+3
	OPTION_UINT8	oGas5O2,			gaslist_min_o2,	.100,			.21,	tPercent,		.48,	opt_gas_O2_ratio+4				; O2 % of gas 5
	OPTION_UINT8	oGas5He,			.0,				gaslist_max_He,	.0,		tPercent,		.49,	opt_gas_He_ratio+4				; He % of gas 5
	OPTION_UINT8d	oGas1Depth,			.0,	gaslist_max_change_depth,	.56,	tMeters,		.50,	opt_gas_change+0				; change depth of gas 1
	OPTION_UINT8d	oGas2Depth,			.0,	gaslist_max_change_depth,	.56,	tMeters,		.51,	opt_gas_change+1
	OPTION_UINT8d	oGas3Depth,			.0,	gaslist_max_change_depth,	.56,	tMeters,		.52,	opt_gas_change+2
	OPTION_UINT8d	oGas4Depth,			.0,	gaslist_max_change_depth,	.56,	tMeters,		.53,	opt_gas_change+3
	OPTION_UINT8d	oGas5Depth,			.0,	gaslist_max_change_depth,	.56,	tMeters,		.54,	opt_gas_change+4				; change depth of gas 5
	OPTION_UINT8	oDil1O2,			gaslist_min_o2,	.100,			.21,	tPercent,		.55,	opt_dil_O2_ratio+0				; O2 % of diluent 1
	OPTION_UINT8	oDil1He,			.0,				gaslist_max_He,	.0,		tPercent,		.56,	opt_dil_He_ratio+0				; He % of diluent 1
	OPTION_UINT8	oDil2O2,			gaslist_min_o2,	.100,			.21,	tPercent,		.57,	opt_dil_O2_ratio+1
	OPTION_UINT8	oDil2He,			.0,				gaslist_max_He,	.0,		tPercent,		.58,	opt_dil_He_ratio+1
	OPTION_UINT8	oDil3O2,			gaslist_min_o2,	.100,			.21,	tPercent,		.59,	opt_dil_O2_ratio+2
	OPTION_UINT8	oDil3He,			.0,				gaslist_max_He,	.0,		tPercent,		.60,	opt_dil_He_ratio+2
	OPTION_UINT8	oDil4O2,			gaslist_min_o2,	.100,			.21,	tPercent,		.61,	opt_dil_O2_ratio+3
	OPTION_UINT8	oDil4He,			.0,				gaslist_max_He,	.0,		tPercent,		.62,	opt_dil_He_ratio+3
	OPTION_UINT8	oDil5O2,			gaslist_min_o2,	.100,			.21,	tPercent,		.63,	opt_dil_O2_ratio+4				; O2 % of diluent 5
	OPTION_UINT8	oDil5He,			.0,				gaslist_max_He,	.0,		tPercent,		.64,	opt_dil_He_ratio+4				; He % of diluent 5
	OPTION_UINT8	oSetPoint1,			gaslist_sp_min,	gaslist_sp_max,	.70,	tbar,			.65,	opt_setpoint_cbar+0				; ppO2 of setpoint 1
	OPTION_UINT8	oSetPoint2,			gaslist_sp_min,	gaslist_sp_max,	.90,	tbar,			.66,	opt_setpoint_cbar+1				; ppO2 of setpoint 2
	OPTION_UINT8	oSetPoint3,			gaslist_sp_min,	gaslist_sp_max,	.100,	tbar,			.67,	opt_setpoint_cbar+2				; ...
	OPTION_UINT8	oSetPoint4,			gaslist_sp_min,	gaslist_sp_max,	.120,	tbar,			.68,	opt_setpoint_cbar+3				; ...
	OPTION_UINT8	oSetPoint5,			gaslist_sp_min,	gaslist_sp_max,	.140,	tbar,			.69,	opt_setpoint_cbar+4				; ppO2 of setpoint 5
	OPTION_UINT8d	oSP1Depth,			.0,				.100,			.0,		tMeters,		.70,	opt_setpoint_change+0			; change depth of setpoint 1 (forced to 0 in code)
	OPTION_UINT8d	oSP2Depth,			.0,				.100,			.0,		tMeters,		.71,	opt_setpoint_change+1			; change depth of setpoint 2
	OPTION_UINT8d	oSP3Depth,			.0,				.100,			.0,		tMeters,		.72,	opt_setpoint_change+2			; ...
	OPTION_UINT8d	oSP4Depth,			.0,				.100,			.0,		tMeters,		.73,	opt_setpoint_change+3			; ...
	OPTION_UINT8d	oSP5Depth,			.0,				.100,			.0,		tMeters,		.74,	opt_setpoint_change+4			; change depth of setpoint 5
	OPTION_ENUM8	oDil1,				.2,								.1,		tDilDisabled,	.75,	opt_dil_type+0					; diluent type: 0=Disabled, 1=First, 2=Normal
	OPTION_ENUM8	oDil2,				.2,								.0,		tDilDisabled,	.76,	opt_dil_type+1
	OPTION_ENUM8	oDil3,				.2,								.0,		tDilDisabled,	.77,	opt_dil_type+2
	OPTION_ENUM8	oDil4,				.2,								.0,		tDilDisabled,	.78,	opt_dil_type+3
	OPTION_ENUM8	oDil5,				.2,								.0,		tDilDisabled,	.79,	opt_dil_type+4
	OPTION_UINT8d	oDil1Depth,			.0,	gaslist_max_change_depth,	.56,	tMeters,		.80,	opt_dil_change+0				; change depth of diluent 1
	OPTION_UINT8d	oDil2Depth,			.0,	gaslist_max_change_depth,	.56,	tMeters,		.81,	opt_dil_change+1
	OPTION_UINT8d	oDil3Depth,			.0,	gaslist_max_change_depth,	.56,	tMeters,		.82,	opt_dil_change+2
	OPTION_UINT8d	oDil4Depth,			.0,	gaslist_max_change_depth,	.56,	tMeters,		.83,	opt_dil_change+3
	OPTION_UINT8d	oDil5Depth,			.0,	gaslist_max_change_depth,	.56,	tMeters,		.84,	opt_dil_change+4				; change depth of diluent 5

;=============================================================================
; opt_name from 85 to 145
	OPTION_STRING	oName,				opt_name_length,						tDefName,		.85,	opt_name

;=============================================================================
; Misc
	OPTION_ENUM8	oColorSetDive,		.4,								.0,		tColorSetName0,	.146,	opt_dive_color_scheme			; color scheme dive mode
	OPTION_UINT8	oPressureAdjust,	.0,				.255,			.0,		notext,			.147,	opt_pressure_adjust				; pressure sensor correction, SIGNED int (clipped to -20/+20 mbar in code)
	OPTION_BOOL		oSafetyStop,										.0,						.148,	opt_enable_safetystop			; =1: show safety stops
	OPTION_UINT8	oCalGasO2,			.21,			.100,			.21,	tPercent,		.149,	opt_calibration_O2_ratio		; calibration gas %O2 (do not move in EEPROM, must stay at .149!)
	OPTION_BOOL		oFlipScreen,										.0,						.151,	opt_flip_screen					; =1: flip the screen
	OPTION_UINT8p10	ocR_button_left,	.20,			.80,			.40,	tPercent,		.152,	opt_cR_button_left				; left  button sensitivity
	OPTION_UINT8p10	ocR_button_right,	.20,			.80,			.40,	tPercent,		.153,	opt_cR_button_right				; right button sensitivity
	OPTION_UINT8	obottom_usage,		.5,				.50,			.20,	tLitersMinute,	.154,	char_I_SAC_work					; surface air consumption rate during working    phase, l/min
	OPTION_UINT8	odeco_usage,		.5,				.50,			.20,	tLitersMinute,	.155,	char_I_SAC_deco					; surface air consumption rate during deco stops phase, l/min
	OPTION_BOOL		oMODwarning,										.1,						.156,	opt_modwarning					; =1: blink on depth related attentions and warnings
	OPTION_BOOL		oVSItextv2,											.0,						.157,	opt_vsitextv2					; =1: use the dynamic (depends on depth) ascend rate limits
	OPTION_BOOL		oVSIgraph,											.1,						.158,	opt_vsigraph					; =1: draw the graphical VSI bar
	OPTION_BOOL		oShowppO2,											.0,						.159,	opt_showppo2					; =1:always show the ppO2 value in the warning position
	OPTION_UINT8	oTemperatureAdjust,	.0,				.255,			.0,		notext,			.160,	opt_temperature_adjust			; temperature sensor correction, SIGNED int (clipped to -2.0/+2.0 °C in code)
	OPTION_UINT8	oSafetyStopLength,	.60,			.240,			.180,	notext,			.161,	opt_safety_stop_length			; [s], duration of the safety stop
	OPTION_UINT8	oSafetyStopStart,	.21,			.61,			.51,	notext,			.162,	opt_safety_stop_start			; [cbar], depth at which safety stop appears,           default 510mbar, min 210mbar, max 610mbar
	OPTION_UINT8	oSafetyStopEnd,		.19,			.39,			.29,	notext,			.163,	opt_safety_stop_end				; [cbar], depth at which safety stop disappears,        default 290mbar, min 190mbar, max 390mbar
	OPTION_UINT8	oSafetyStopReset,	.81,			.151,			.101,	notext,			.164,	opt_safety_stop_reset			; [cbar], depth at which safety stop timer is reloaded, default 1010mbar, min 810mbar, max 1510mbar
	OPTION_UINT8	oDiveTimeout,		.1,				.20,			.5,		tMinutes,		.168,	opt_diveTimeout					; [minutes] timeout for switch from dive mode to surface mode
	OPTION_UINT8	oPSCR_drop,			.0,				.15,			.4,		tPercent,		.169,	char_I_PSCR_drop				; pSCR drop [%]
	OPTION_UINT8	oPSCR_lungratio,	.5,				.20,			.10,	tPercent,		.170,	char_I_PSCR_lungratio			; pSCR lung ratio [1/x]
;																								.171									; in use, see below
;																								.172									; in use, see below
	OPTION_UINT8	oTankSize1,			min_tank_size,	max_tank_size,	.11,	tLiter,			.173,	char_I_gas_avail_size+0			; size of OC gas tank 1, in liters
	OPTION_UINT8	oTankSize2,			min_tank_size,	max_tank_size,	.11,	tLiter,			.174,	char_I_gas_avail_size+1			; size of OC gas tank 2, in liters
	OPTION_UINT8	oTankSize3,			min_tank_size,	max_tank_size,	.11,	tLiter,			.175,	char_I_gas_avail_size+2			; size of OC gas tank 3, in liters
	OPTION_UINT8	oTankSize4,			min_tank_size,	max_tank_size,	.11,	tLiter,			.176,	char_I_gas_avail_size+3			; size of OC gas tank 4, in liters
	OPTION_UINT8	oTankSize5,			min_tank_size,	max_tank_size,	.11,	tLiter,			.177,	char_I_gas_avail_size+4			; size of OC gas tank 5, in liters
	OPTION_UINT8	oTankFillPres1,		min_fill_press,	max_fill_press,	.20,	tbar10,			.178,	char_I_gas_avail_pres+0			; available press of OC gas tank 1, in multiples of 10 bars
	OPTION_UINT8	oTankFillPres2,		min_fill_press,	max_fill_press,	.20,	tbar10,			.179,	char_I_gas_avail_pres+1			; available press of OC gas tank 2, in multiples of 10 bars
	OPTION_UINT8	oTankFillPres3,		min_fill_press,	max_fill_press,	.20,	tbar10,			.180,	char_I_gas_avail_pres+2			; available press of OC gas tank 3, in multiples of 10 bars
	OPTION_UINT8	oTankFillPres4,		min_fill_press,	max_fill_press,	.20,	tbar10,			.181,	char_I_gas_avail_pres+3			; available press of OC gas tank 4, in multiples of 10 bars
	OPTION_UINT8	oTankFillPres5,		min_fill_press,	max_fill_press,	.20,	tbar10,			.182,	char_I_gas_avail_pres+4			; available press of OC gas tank 5, in multiples of 10 bars
	OPTION_UINT8	oCCmaxFracO2,		.80,			.100,			.90,	tPercent,		.183,	char_I_CC_max_frac_O2			; max. O2 % in Loop
	OPTION_UINT8	oSimSetpoint,		.1,				.5,				.1,		tblank,			.184,	opt_sim_setpoint_number			; setpoint to use for deco calculation
	OPTION_ENUM8	oCalcAscGas,		calc_gas_options,				.0,		tNo,			.185,	opt_calc_asc_gasvolume			; calculate OC gas volume needs for ascent: no, yes, cave
	OPTION_ENUM8	oAltMode,			.4,								.0,		tAltModeFly,	.186,	char_I_altitude_wait			; no-fly time calculation for: 0=no-fly, 1=1000m, 2=2000m, 3=3000m
	OPTION_BOOL		oEnable_IBCD,										.1,						.187,	opt_enable_IBCD					; =1: IBCD warning activated
	OPTION_UINT8	oAscentSpeed,		.5,				.10,			.10,	tMeterMinute,	.188,	char_I_ascent_speed				; [meter/minute] ascent speed
	OPTION_UINT8	oGasChangeTime,		.0,				.3,				.0,		tMinutes,		.189,	char_I_gas_change_time			; (extra) time at a stop to change the gas
	OPTION_UINT8p5	osatmult,			.100,			.140,			.110,	tPercent,		.190,	opt_sat_multiplier_non_gf		; saturation   factor for NON-GF Mode
	OPTION_UINT8p5	odesatmult,			.60,			.100,			.90,	tPercent,		.191,	opt_desat_multiplier_non_gf		; desaturation factor for NON-GF Mode
	OPTION_UINT8	oTransID1_0,		.0,				.255,			.0,		notext,			.192,	opt_transmitter_id_1+0			; ID of transmitter for gas 1 (LOW)
	OPTION_UINT8	oTransID1_1,		.0,				.255,			.0,		notext,			.193,	opt_transmitter_id_1+1			; ID of transmitter for gas 1 (HIGH)
	OPTION_UINT8	oTransID2_0,		.0,				.255,			.0,		notext,			.194,	opt_transmitter_id_2+0			; ID of transmitter for gas 2 (LOW)
	OPTION_UINT8	oTransID2_1,		.0,				.255,			.0,		notext,			.195,	opt_transmitter_id_2+1			; ID of transmitter for gas 2 (HIGH)
	OPTION_UINT8	oTransID3_0,		.0,				.255,			.0,		notext,			.196,	opt_transmitter_id_3+0			; ID of transmitter for gas 3 (LOW)
	OPTION_UINT8	oTransID3_1,		.0,				.255,			.0,		notext,			.197,	opt_transmitter_id_3+1			; ID of transmitter for gas 3 (HIGH)
	OPTION_UINT8	oTransID4_0,		.0,				.255,			.0,		notext,			.198,	opt_transmitter_id_4+0			; ID of transmitter for gas 4 (LOW)
	OPTION_UINT8	oTransID4_1,		.0,				.255,			.0,		notext,			.199,	opt_transmitter_id_4+1			; ID of transmitter for gas 4 (HIGH)
	OPTION_UINT8	oTransID5_0,		.0,				.255,			.0,		notext,			.200,	opt_transmitter_id_5+0			; ID of transmitter for gas 5 (LOW)
	OPTION_UINT8	oTransID5_1,		.0,				.255,			.0,		notext,			.201,	opt_transmitter_id_5+1			; ID of transmitter for gas 5 (HIGH)
	OPTION_UINT8	oTransID6_0,		.0,				.255,			.0,		notext,			.202,	opt_transmitter_id_6+0			; ID of transmitter for dil 1 (LOW)
	OPTION_UINT8	oTransID6_1,		.0,				.255,			.0,		notext,			.203,	opt_transmitter_id_6+1			; ID of transmitter for dil 1 (HIGH)
	OPTION_UINT8	oTransID7_0,		.0,				.255,			.0,		notext,			.204,	opt_transmitter_id_7+0			; ID of transmitter for dil 2 (LOW)
	OPTION_UINT8	oTransID7_1,		.0,				.255,			.0,		notext,			.205,	opt_transmitter_id_7+1			; ID of transmitter for dil 2 (HIGH)
	OPTION_UINT8	oTransID8_0,		.0,				.255,			.0,		notext,			.206,	opt_transmitter_id_8+0			; ID of transmitter for dil 3 (LOW)
	OPTION_UINT8	oTransID8_1,		.0,				.255,			.0,		notext,			.207,	opt_transmitter_id_8+1			; ID of transmitter for dil 3 (HIGH)
	OPTION_UINT8	oTransID9_0,		.0,				.255,			.0,		notext,			.208,	opt_transmitter_id_9+0			; ID of transmitter for dil 4 (LOW)
	OPTION_UINT8	oTransID9_1,		.0,				.255,			.0,		notext,			.209,	opt_transmitter_id_9+1			; ID of transmitter for dil 4 (HIGH)
	OPTION_UINT8	oTransID10_0,		.0,				.255,			.0,		notext,			.210,	opt_transmitter_id_10+0			; ID of transmitter for dil 5 (LOW)
	OPTION_UINT8	oTransID10_1,		.0,				.255,			.0,		notext,			.211,	opt_transmitter_id_10+1			; ID of transmitter for dil 5 (HIGH)
	OPTION_UINT8	oTankSize6,			min_tank_size,	max_tank_size,	.11,	tLiter,			.212,	char_I_gas_avail_size+5			; size of DIL gas tank 1, in liters
	OPTION_UINT8	oTankSize7,			min_tank_size,	max_tank_size,	.11,	tLiter,			.213,	char_I_gas_avail_size+6			; size of DIL gas tank 2, in liters
	OPTION_UINT8	oTankSize8,			min_tank_size,	max_tank_size,	.11,	tLiter,			.214,	char_I_gas_avail_size+7			; size of DIL gas tank 3, in liters
	OPTION_UINT8	oTankSize9,			min_tank_size,	max_tank_size,	.11,	tLiter,			.215,	char_I_gas_avail_size+8			; size of DIL gas tank 4, in liters
	OPTION_UINT8	oTankSize10,		min_tank_size,	max_tank_size,	.11,	tLiter,			.216,	char_I_gas_avail_size+9			; size of DIL gas tank 5, in liters
	OPTION_UINT8	oTankFillPres6,		min_fill_press,	max_fill_press,	.20,	tbar10,			.217,	char_I_gas_avail_pres+5			; available press of DIL gas tank 1, in multiples of 10 bars
	OPTION_UINT8	oTankFillPres7,		min_fill_press,	max_fill_press,	.20,	tbar10,			.218,	char_I_gas_avail_pres+6			; available press of DIL gas tank 2, in multiples of 10 bars
	OPTION_UINT8	oTankFillPres8,		min_fill_press,	max_fill_press,	.20,	tbar10,			.219,	char_I_gas_avail_pres+7			; available press of DIL gas tank 3, in multiples of 10 bars
	OPTION_UINT8	oTankFillPres9,		min_fill_press,	max_fill_press,	.20,	tbar10,			.220,	char_I_gas_avail_pres+8			; available press of DIL gas tank 4, in multiples of 10 bars
	OPTION_UINT8	oTankFillPres10,	min_fill_press,	max_fill_press,	.20,	tbar10,			.221,	char_I_gas_avail_pres+9			; available press of DIL gas tank 5, in multiples of 10 bars
	OPTION_ENUM8	oTrMode,			.4,								.1,		tTrModeOff,		.222,	opt_TR_mode						; TR functions - mode
	OPTION_ENUM8	oTr1stPres,			tr_pres_options,				.1,		tTrPresNone,	.223,	opt_TR_1st_pres					; TR functions - 1st pressure assignment
	OPTION_ENUM8	oTr2ndPres,			tr_pres_options,				.0,		tTrPresNone,	.224,	opt_TR_2nd_pres					; TR functions - 2nd pressure assignment
	OPTION_ENUM8	oTrBailPres,		tr_pres_options,				.1,		tTrPresNone,	.225,	opt_TR_Bail_pres				; TR functions - bailout pressure assignment
	OPTION_UINT8p5	oTrMaxDeltaPres,	max_pres_diff_min,max_pres_diff_max,.5,	tbar,			.226,	char_I_max_pres_diff			; TR functions - maximum delta pressure in independent double mode
	;																							.227									; spare / unused
	;																							.228									; spare / unused
	OPTION_ENUM8	o2ndDepthDisp,		.2,								.0,		tMaxDepth,		.229,	opt_2ndDepthDisp				; =1: show average depth instead of max depth
	OPTION_UINT8d	oMaxDepth,			.5,	ostc_depth_max,	ostc_depth_max,		tMeters,		.230,	opt_max_depth					; depth at which a warning will be given
	OPTION_UINT8	oDescentSpeed,		.5,				.30,			.10,	tMeterMinute,	.231,	char_I_descent_speed			; descent speed for deco calculator          [future option, not used yet]
	OPTION_BOOL		oStoreApnoeDive,									.0,						.232,	opt_store_apnoe_dive			; =1: store dives in apnoe mode into logbook
	OPTION_ENUM8	oTissueGraphics,	tissue_graphics_options,		.0,		tTissuePresSat,	.233,	opt_tissue_graphics 			; =0: show N2 and He pressures, =1: show pressures and saturations
	OPTION_ENUM8	oLayout,			.2,								.0,		tLayoutNormal,	.234,	opt_layout						; initial layout of dive mode screen =0: normal, =1: big
	OPTION_BOOL		oExtendedStops,										.1,						.235,	opt_extended_stops				; =1: place gas switches also below 1st stop depth
	OPTION_UINT8	oGasDensityAttention,.40,			.80,			.60,	notext,			.236,	char_I_gas_density_att			; threshold for gas density attention [0.1 grams/l]
	OPTION_UINT8	oGasDensityWarning,	.40,			.80,			.65,	notext,			.237,	char_I_gas_density_warn			; threshold for gas density warning   [0.1 grams/l]
	OPTION_BOOL		oDilppO2Check,										.1,						.238,	char_I_dil_ppO2_check			; =1: check ppO2 of the pure diluent against current setpoint

	;	+---------------------------+
	;	| /|\                       |
	;	|  |  add new options here! |
	;	+---------------------------+

; ppO2 warnings, sorted by ppO2 levels
	OPTION_UINT8p10	oPPO2Min,		ppo2_warning_low_lowest,	ppo2_warning_low_highest,	ppo2_warning_low_default,	notext,	.16,	char_I_ppO2_min			; ppO2 min on OC   and for pure diluent in CCR
	OPTION_UINT8p10	oPPO2MinCC,		ppo2_warning_loop_lowest,	ppo2_warning_loop_highest,	ppo2_warning_loop_default,	notext,	.172,	char_I_ppO2_min_loop	; ppO2 min on Loop and for pure diluent in pSCR
	OPTION_UINT8p10	oPPO2Max,		ppo2_warning_high_lowest,	ppo2_warning_high_highest,	ppo2_warning_high_default,	notext,	.10,	char_I_ppO2_max_work	; ppO2 max while in working phase
	OPTION_UINT8p10	oPPO2MaxDeco,	ppo2_warning_deco_lowest,	ppo2_warning_deco_highest,	ppo2_warning_deco_default,	notext,	.171,	char_I_ppO2_max_deco	; ppO2 max while in deco stops phase


;=============================================================================
; volatile options

	OPTION_UINT8p10	odiveInterval,		.0,				.240,			.0,		tMinutes,	volatile,	opt_surface_interval			; additional surface interval for deco calculator
	OPTION_UINT8p2	obottomTime,		.2,				.60,			.10,	tMinutes,	volatile,	char_I_bottom_time				; bottom time  for deco calculator
	OPTION_UINT8p3d	obottomDepth,		.12,			.120,			.21,	tMeters,	volatile,	char_I_bottom_depth				; bottom depth for deco calculator and simulator
	OPTION_BOOL		oSimAGF,											.0,					volatile,	opt_sim_use_aGF					; use GF (no) or aGF (yes) in deco calculator
	OPTION_ENUM8	oLogOffsetStep,		.4,								.0,		tLogOffStep1, volatile,	opt_logoffset_step				; step size when adjusting the log offset

 IFDEF _gas_contingency
	OPTION_BOOL		oGasContingency,									.0,					volatile,	char_I_gas_contingency			; =1: switch to alternative gas if best gas is depleted
 ENDIF


;=============================================================================
; Set Time/Set Date (RAM only)
	OPTION_UINT8	oClearSeconds,		.0,				.0,				.0,		notext,		volatile,	rtc_latched_secs
	OPTION_UINT8	oSetMinutes,		.0,				.59,			.0,		notext,		volatile,	rtc_latched_mins
	OPTION_UINT8	oSetHours,			.0,				.23,			.0,		notext,		volatile,	rtc_latched_hour
	OPTION_UINT8	oSetDay,			.1,				.31,			.0,		notext,		volatile,	rtc_latched_day
	OPTION_UINT8	oSetMonth,			.1,				.12,			.0,		notext,		volatile,	rtc_latched_month
	OPTION_UINT8	oSetYear,			.18,			.24,			.0,		notext,		volatile,	rtc_latched_year

	global	option_table_end
option_table_end:

	END