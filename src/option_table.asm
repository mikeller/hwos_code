;=============================================================================
;
;   File option_table.asm                   * combined next generation V3.09.4j
;
;   The Option Table
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;   2014-08-03 : mH creation
;

#include "hwos.inc"


;=============================================================================
option_table CODE 0x08000  ; ! DO NOT CHANGE - Option Table must fit 0x08xxx !
;=============================================================================


OPTION_UINT8	MACRO lbl, min, max, default, unit, eeprom, serial, register
	global	lbl
lbl:	db	.0, serial					; type   : 0 = INT8
		db	.1, min, max, default		; value  : increment, min, max, default
		dw	unit, register, eeprom		; pointer: unit, variable, EEPROM
		ENDM

OPTION_UINT8d	MACRO lbl, min, max, default, unit, eeprom, serial, register
	global	lbl
lbl:	db	.3, serial					; type   : 3 = INT8 with automatic display in meters or feet
		db	.1, min, max, default		; value  : increment, min, max, default
		dw	unit, register, eeprom		; pointer: unit, variable, EEPROM
		ENDM

OPTION_UINT8p2	MACRO lbl, min, max, default, unit, eeprom, serial, register
	global	lbl
lbl:	db	.0, serial					; type   : 0 = INT8 with increment 2
		db	.2, min, max, default		; value  : increment, min, max, default
		dw	unit, register, eeprom		; pointer: unit, variable, EEPROM
		ENDM

OPTION_UINT8p3	MACRO lbl, min, max, default, unit, eeprom, serial, register
		global	lbl
lbl:	db	.0, serial					; type   : 0 = INT8 with increment 3
		db	.3, min, max, default		; value  : increment, min, max, default
		dw	unit, register, eeprom		; pointer: unit, variable, EEPROM
		ENDM

OPTION_UINT8p3d	MACRO lbl, min, max, default, unit, eeprom, serial, register
		global	lbl
lbl:	db	.3, serial					; type   : 3 = INT8 with increment 3 and automatic display in meters or feet
		db	.3, min, max, default		; value  : increment, min, max, default
		dw	unit, register, eeprom		; pointer: unit, variable, EEPROM
		ENDM

OPTION_UINT8p5	MACRO lbl, min, max, default, unit, eeprom, serial, register
		global	lbl
lbl:	db	.0, serial					; type   : 0 = INT8 with increment 5
		db	.5, min, max, default		; value  : increment, min, max, default
		dw	unit, register, eeprom		; pointer: unit, variable, EEPROM
		ENDM

OPTION_UINT8p10	MACRO lbl, min, max, default, unit, eeprom, serial, register
		global	lbl
lbl:	db	.0, serial					; type   : 0 = INT8 with increment 10
		db	.10, min, max, default		; value  : increment, min, max, default
		dw	unit, register, eeprom		; pointer: unit, variable, EEPROM
		ENDM

OPTION_ENUM8	MACRO lbl, max, default, tValue, eeprom, serial, register
		global	lbl
		extern	tValue
lbl:	db	.1, serial					; type   : 1 = ENUM
		db	LOW(tValue), HIGH(tValue)	; value  : pointer to base text
		db	max-1, default				; value  : max, default
		dw	.0, register, eeprom		; pointer: (no unit), variable, EEPROM
		ENDM

OPTION_BOOL		MACRO lbl, default, eeprom, serial, register
		global	lbl
		extern	tNo
lbl:	db	.1, serial					; type   : 1 = ENUM
		db	LOW(tNo), HIGH(tNo)			; value  : pointer to base of text "no"
		db	.2-1, default				; value  : max, default
		dw	.0, register, eeprom		; pointer: (no unit), variable, EEPROM
		ENDM

OPTION_STRING	MACRO lbl, stringlength, defText, eeprom, serial, register
		global	lbl
lbl:	db	.2, serial					; type   : 2 = STRING
		db	LOW(defText), HIGH(defText)	; value  : pointer to default text
		db	stringlength, .0			; value  : length, (no default)
		dw	.0, register, eeprom		; pointer: (no unit), variable, EEPROM
		ENDM

OPTION_END	MACRO
		db	0xFF, 0xFF					; type   : 255 = end of table
		ENDM

;=============================================================================

	extern	tPercent, tMeters, tMinutes, tGasDisabled, tbar, tNo, tTrModeOff, tTrPresNone, tDefName, tblank, tLogTunitC, tTissuePresSat
	extern	char_I_bottom_time, char_I_bottom_depth
	extern	char_I_model
	extern	char_I_extra_time
	extern	char_I_SAC_work, char_I_SAC_deco, tLitersMinute
	extern	char_I_PSCR_drop, char_I_PSCR_lungratio
	extern	char_I_gas_avail_size, char_I_gas_avail_pres, tLiter, tbar10
	extern	char_I_CC_max_frac_O2
	extern	char_I_altitude_wait
	extern	char_I_ppO2_max_work, char_I_ppO2_min, char_I_ppO2_max_deco, char_I_ppO2_min_loop
	extern	char_I_descent_speed, tMeterMinute
	extern	char_I_gas_change_time
	extern	char_I_max_pres_diff
	extern	char_I_gas_density_att, char_I_gas_density_warn
	extern	char_I_dil_check

 IFDEF _comm_debug
	extern	tCommTimeoutU
 ENDIF

#DEFINE nounit		0x0000	; no unit text associated
#DEFINE volatile	0xFFFF	; not stored in EEPROM
#DEFINE nocomm		0x00	; not accessible via RS232

;=============================================================================

	global	option_table_begin
option_table_begin:

;	Option Table - Format:
;	----------------------
;	OPTION_UINT8    Label,              min,                  max,            default,      unit text,      EEPROM,  serial,  RAM location
;	OPTION_ENUM8    Label,        number of ENUMS,                            default,      unit text,      EEPROM,  serial,  RAM location 					; number of enums = 2, 3, ..., default starts with 0
;	OPTION_BOOL     Label,                                                    default,                      EEPROM,  serial,  RAM location

	; Manage Deco Planer & Dive Parameters
	OPTION_ENUM8    oDiveMode,           .5,                                       .0,      tDvOC,           0x01A,    0x20,  opt_dive_mode					; 0=OC, 1=CC, 2=Gauge, 3=Apnea, 4=PSCR
	OPTION_ENUM8    oDecoMode,           .2,                                       .1,      tZHL16,          0x01B,    0x21,  char_I_model					; 0 = ZH-L16, 1 = ZH-L16-GF
	;                                                                                                        0x01C											; in use, see below
	OPTION_UINT8d   oLastDeco,           .3,                   .6,                 .3,      tMeters,         0x01D,    0x2C,  opt_last_stop					; depth of the last deco stop
	OPTION_UINT8    oGF_low,            .10,                 .100,                .30,      tPercent,        0x01E,    0x25,  opt_GF_low					; normal GF low
	OPTION_UINT8    oGF_high,           .45,                 .110,                .85,      tPercent,        0x01F,    0x26,  opt_GF_high					; normal GF high
	OPTION_UINT8p5  osatmultgf,        .100,                 .140,               .100,      tPercent,        0x020,    0x5E,  opt_sat_multiplier_gf			; saturation factor   for GF mode
	OPTION_UINT8p5  odesatmultgf,       .60,                 .100,               .100,      tPercent,        0x021,    0x5F,  opt_desat_multiplier_gf		; desaturation factor for GF mode
	;                                                                                                        0x022											; in use, see below
	OPTION_UINT8    oaGF_low,           .10,                 .100,                .30,      tPercent,        0x023,    0x27,  opt_aGF_low					; alternative GF low
	OPTION_UINT8    oaGF_high,          .45,                 .110,                .85,      tPercent,        0x024,    0x28,  opt_aGF_high					; alternative GF high
	OPTION_BOOL     oEnable_aGF,         .0,                                                                 0x025,    0x29,  opt_enable_aGF				; =1: aGF can be selected underwater
	OPTION_UINT8    oCompassGain,        .0,                   .5,                 .5,      tMinutes,        0x026,    0x34,  opt_compass_gain				; 0-7 (230 LSB/Gauss to 1370LSB/Gauss)
	OPTION_ENUM8    oSamplingRate,       .2,                                       .0,      tSetSeconds,     0x027,    0x2F,  opt_sampling_rate				; =1: 10s, =0: 2s

	; Managing Settings
	OPTION_UINT8    oExtraTime,          .0,                   .9,                 .0,      tMinutes,        0x028,    0x24,  char_I_extra_time				; extra bottom time for future TTS calculation
	OPTION_ENUM8    oBrightness_dive,    .3,                                       .0,      tEco,            0x029,    0x2D,  opt_brightness_divemode				; =0: Eco, =1:Medium, =2:Full
	OPTION_UINT8    oDiveSalinity,   salinity_min,      salinity_max,              .0,      tPercent,        0x02A,    0x30,  opt_salinity					; 0-4%
	OPTION_ENUM8    oCCRMode,            .3,                                       .0,      tCCRModeFixedSP, 0x02B,    0x1F,  opt_ccr_mode					; =0: Fixed SP, =1: Sensor, =2: Auto SP
	OPTION_ENUM8    oLanguage,           .2,                                       .0,      tLang1,          0x02C,    0x32,  opt_language					; language selection
	OPTION_ENUM8    oDateFormat,         .3,                                       .1,      tDateformat,     0x02D,    0x33,  opt_dateformat				; =0:MMDDYY, =1:DDMMYY, =2:YYMMDD
	OPTION_ENUM8    oUnits,              .2,                                       .0,      tMetric,         0x02E,    0x2E,  opt_units						; =0:Meter, =1:Feet

	; Compass calibration data
	OPTION_UINT8    oCalx0,              .0,                 .255,                 .0,      nounit,          0x02F,  nocomm,  compass_CX_f+0				; compass calibration data x, low  byte
	OPTION_UINT8    oCalx1,              .0,                 .255,                 .0,      nounit,          0x030,  nocomm,  compass_CX_f+1				;                          x, high byte
	OPTION_UINT8    oCaly0,              .0,                 .255,                 .0,      nounit,          0x031,  nocomm,  compass_CY_f+0				;                          y, low  byte
	OPTION_UINT8    oCaly1,              .0,                 .255,                 .0,      nounit,          0x032,  nocomm,  compass_CY_f+1				;                          y, high byte
	OPTION_UINT8    oCalz0,              .0,                 .255,                 .0,      nounit,          0x033,  nocomm,  compass_CZ_f+0				;                          z, low  byte
	OPTION_UINT8    oCalz1,              .0,                 .255,                 .0,      nounit,          0x034,  nocomm,  compass_CZ_f+1				;                          z, high byte

	; Gas list
	OPTION_ENUM8    oGas1,           num_gas_types,                                .1,      tGasDisabled,    0x035,  nocomm,  opt_gas_type+0				; gas type: 0=Disabled, 1=First, 2=Travel, 3=Deco
	OPTION_ENUM8    oGas2,           num_gas_types,                                .0,      tGasDisabled,    0x036,  nocomm,  opt_gas_type+1
	OPTION_ENUM8    oGas3,           num_gas_types,                                .0,      tGasDisabled,    0x037,  nocomm,  opt_gas_type+2
	OPTION_ENUM8    oGas4,           num_gas_types,                                .0,      tGasDisabled,    0x038,  nocomm,  opt_gas_type+3
	OPTION_ENUM8    oGas5,           num_gas_types,                                .0,      tGasDisabled,    0x039,  nocomm,  opt_gas_type+4
	OPTION_ENUM8    oDil1,           num_dil_types,                                .1,      tGasDisabled,    0x05D,  nocomm,  opt_dil_type+0				; diluent type: 0=Disabled, 1=First, 2=Normal
	OPTION_ENUM8    oDil2,           num_dil_types,                                .0,      tGasDisabled,    0x05E,  nocomm,  opt_dil_type+1
	OPTION_ENUM8    oDil3,           num_dil_types,                                .0,      tGasDisabled,    0x05F,  nocomm,  opt_dil_type+2
	OPTION_ENUM8    oDil4,           num_dil_types,                                .0,      tGasDisabled,    0x060,  nocomm,  opt_dil_type+3
	OPTION_ENUM8    oDil5,           num_dil_types,                                .0,      tGasDisabled,    0x061,  nocomm,  opt_dil_type+4

	OPTION_UINT8    oGas1O2,         gaslist_min_o2,    gaslist_max_o2,           .21,      tPercent,        0x03A,  0xFA,    opt_gas_O2_ratio+0			; O2 % of gas 1
	OPTION_UINT8    oGas2O2,         gaslist_min_o2,    gaslist_max_o2,           .21,      tPercent,        0x03C,  0xFA,    opt_gas_O2_ratio+1
	OPTION_UINT8    oGas3O2,         gaslist_min_o2,    gaslist_max_o2,           .21,      tPercent,        0x03E,  0xFA,    opt_gas_O2_ratio+2
	OPTION_UINT8    oGas4O2,         gaslist_min_o2,    gaslist_max_o2,           .21,      tPercent,        0x040,  0xFA,    opt_gas_O2_ratio+3
	OPTION_UINT8    oGas5O2,         gaslist_min_o2,    gaslist_max_o2,           .21,      tPercent,        0x042,  0xFA,    opt_gas_O2_ratio+4			; O2 % of gas 5
	OPTION_UINT8    oDil1O2,         gaslist_min_o2,    gaslist_max_o2,           .21,      tPercent,        0x049,  0xFA,    opt_dil_O2_ratio+0			; O2 % of diluent 1
	OPTION_UINT8    oDil2O2,         gaslist_min_o2,    gaslist_max_o2,           .21,      tPercent,        0x04B,  0xFA,    opt_dil_O2_ratio+1
	OPTION_UINT8    oDil3O2,         gaslist_min_o2,    gaslist_max_o2,           .21,      tPercent,        0x04D,  0xFA,    opt_dil_O2_ratio+2
	OPTION_UINT8    oDil4O2,         gaslist_min_o2,    gaslist_max_o2,           .21,      tPercent,        0x04F,  0xFA,    opt_dil_O2_ratio+3
	OPTION_UINT8    oDil5O2,         gaslist_min_o2,    gaslist_max_o2,           .21,      tPercent,        0x051,  0xFA,    opt_dil_O2_ratio+4			; O2 % of diluent 5
	OPTION_UINT8    oGas1He,             .0,            gaslist_max_He,            .0,      tPercent,        0x03B,  0xFB,    opt_gas_He_ratio+0			; He % of gas 1
	OPTION_UINT8    oGas2He,             .0,            gaslist_max_He,            .0,      tPercent,        0x03D,  0xFB,    opt_gas_He_ratio+1
	OPTION_UINT8    oGas3He,             .0,            gaslist_max_He,            .0,      tPercent,        0x03F,  0xFB,    opt_gas_He_ratio+2
	OPTION_UINT8    oGas4He,             .0,            gaslist_max_He,            .0,      tPercent,        0x041,  0xFB,    opt_gas_He_ratio+3
	OPTION_UINT8    oGas5He,             .0,            gaslist_max_He,            .0,      tPercent,        0x043,  0xFB,    opt_gas_He_ratio+4			; He % of gas 5
	OPTION_UINT8    oDil1He,             .0,            gaslist_max_He,            .0,      tPercent,        0x04A,  0xFB,    opt_dil_He_ratio+0			; He % of diluent 1
	OPTION_UINT8    oDil2He,             .0,            gaslist_max_He,            .0,      tPercent,        0x04C,  0xFB,    opt_dil_He_ratio+1
	OPTION_UINT8    oDil3He,             .0,            gaslist_max_He,            .0,      tPercent,        0x04E,  0xFB,    opt_dil_He_ratio+2
	OPTION_UINT8    oDil4He,             .0,            gaslist_max_He,            .0,      tPercent,        0x050,  0xFB,    opt_dil_He_ratio+3
	OPTION_UINT8    oDil5He,             .0,            gaslist_max_He,            .0,      tPercent,        0x052,  0xFB,    opt_dil_He_ratio+4			; He % of diluent 5

	OPTION_UINT8d   oGas1Depth,          .0,            gaslist_max_change_depth, .56,      tMeters,         0x044,  nocomm,  opt_gas_change+0				; change depth of gas 1
	OPTION_UINT8d   oGas2Depth,          .0,            gaslist_max_change_depth, .56,      tMeters,         0x045,  nocomm,  opt_gas_change+1
	OPTION_UINT8d   oGas3Depth,          .0,            gaslist_max_change_depth, .56,      tMeters,         0x046,  nocomm,  opt_gas_change+2
	OPTION_UINT8d   oGas4Depth,          .0,            gaslist_max_change_depth, .56,      tMeters,         0x047,  nocomm,  opt_gas_change+3
	OPTION_UINT8d   oGas5Depth,          .0,            gaslist_max_change_depth, .56,      tMeters,         0x048,  nocomm,  opt_gas_change+4				; change depth of gas 5
	OPTION_UINT8d   oDil1Depth,          .0,            gaslist_max_change_depth, .56,      tMeters,         0x062,  nocomm,  opt_dil_change+0				; change depth of diluent 1
	OPTION_UINT8d   oDil2Depth,          .0,            gaslist_max_change_depth, .56,      tMeters,         0x063,  nocomm,  opt_dil_change+1
	OPTION_UINT8d   oDil3Depth,          .0,            gaslist_max_change_depth, .56,      tMeters,         0x064,  nocomm,  opt_dil_change+2
	OPTION_UINT8d   oDil4Depth,          .0,            gaslist_max_change_depth, .56,      tMeters,         0x065,  nocomm,  opt_dil_change+3
	OPTION_UINT8d   oDil5Depth,          .0,            gaslist_max_change_depth, .56,      tMeters,         0x066,  nocomm,  opt_dil_change+4				; change depth of diluent 5

	OPTION_UINT8    oTankSizeOC1,    min_tank_size,     max_tank_size,            .11,      tLiter,          0x0BF,    0x4E,  char_I_gas_avail_size+0		; size of OC gas tank 1, in liters
	OPTION_UINT8    oTankSizeOC2,    min_tank_size,     max_tank_size,            .11,      tLiter,          0x0C0,    0x4F,  char_I_gas_avail_size+1		; size of OC gas tank 2, in liters
	OPTION_UINT8    oTankSizeOC3,    min_tank_size,     max_tank_size,            .11,      tLiter,          0x0C1,    0x50,  char_I_gas_avail_size+2		; size of OC gas tank 3, in liters
	OPTION_UINT8    oTankSizeOC4,    min_tank_size,     max_tank_size,            .11,      tLiter,          0x0C2,    0x51,  char_I_gas_avail_size+3		; size of OC gas tank 4, in liters
	OPTION_UINT8    oTankSizeOC5,    min_tank_size,     max_tank_size,            .11,      tLiter,          0x0C3,    0x52,  char_I_gas_avail_size+4		; size of OC gas tank 5, in liters
	OPTION_UINT8    oTankSizeDil1,   min_tank_size,     max_tank_size,            .11,      tLiter,          0x0E6,    0x74,  char_I_gas_avail_size+5		; size of DIL gas tank 1, in liters
	OPTION_UINT8    oTankSizeDil2,   min_tank_size,     max_tank_size,            .11,      tLiter,          0x0E7,    0x75,  char_I_gas_avail_size+6		; size of DIL gas tank 2, in liters
	OPTION_UINT8    oTankSizeDil3,   min_tank_size,     max_tank_size,            .11,      tLiter,          0x0E8,    0x76,  char_I_gas_avail_size+7		; size of DIL gas tank 3, in liters
	OPTION_UINT8    oTankSizeDil4,   min_tank_size,     max_tank_size,            .11,      tLiter,          0x0E9,    0x77,  char_I_gas_avail_size+8		; size of DIL gas tank 4, in liters
	OPTION_UINT8    oTankSizeDil5,   min_tank_size,     max_tank_size,            .11,      tLiter,          0x0EA,    0x78,  char_I_gas_avail_size+9		; size of DIL gas tank 5, in liters

	OPTION_UINT8    oTankPresOC1,    min_fill_press,    max_fill_press,           .20,      tbar10,          0x0C4,    0x53,  char_I_gas_avail_pres+0		; available press of OC gas tank 1, in multiples of 10 bars
	OPTION_UINT8    oTankPresOC2,    min_fill_press,    max_fill_press,           .20,      tbar10,          0x0C5,    0x54,  char_I_gas_avail_pres+1		; available press of OC gas tank 2, in multiples of 10 bars
	OPTION_UINT8    oTankPresOC3,    min_fill_press,    max_fill_press,           .20,      tbar10,          0x0C6,    0x55,  char_I_gas_avail_pres+2		; available press of OC gas tank 3, in multiples of 10 bars
	OPTION_UINT8    oTankPresOC4,    min_fill_press,    max_fill_press,           .20,      tbar10,          0x0C7,    0x56,  char_I_gas_avail_pres+3		; available press of OC gas tank 4, in multiples of 10 bars
	OPTION_UINT8    oTankPresOC5,    min_fill_press,    max_fill_press,           .20,      tbar10,          0x0C8,    0x57,  char_I_gas_avail_pres+4		; available press of OC gas tank 5, in multiples of 10 bars
	OPTION_UINT8    oTankPresDil1,   min_fill_press,    max_fill_press,           .20,      tbar10,          0x0EB,    0x79,  char_I_gas_avail_pres+5		; available press of DIL gas tank 1, in multiples of 10 bars
	OPTION_UINT8    oTankPresDil2,   min_fill_press,    max_fill_press,           .20,      tbar10,          0x0EC,    0x7A,  char_I_gas_avail_pres+6		; available press of DIL gas tank 2, in multiples of 10 bars
	OPTION_UINT8    oTankPresDil3,   min_fill_press,    max_fill_press,           .20,      tbar10,          0x0ED,    0x7B,  char_I_gas_avail_pres+7		; available press of DIL gas tank 3, in multiples of 10 bars
	OPTION_UINT8    oTankPresDil4,   min_fill_press,    max_fill_press,           .20,      tbar10,          0x0EE,    0x7C,  char_I_gas_avail_pres+8		; available press of DIL gas tank 4, in multiples of 10 bars
	OPTION_UINT8    oTankPresDil5,   min_fill_press,    max_fill_press,           .20,      tbar10,          0x0EF,    0x7D,  char_I_gas_avail_pres+9		; available press of DIL gas tank 5, in multiples of 10 bars

	OPTION_UINT8p10 oSP1ppO2,        gaslist_sp_min,    gaslist_sp_max,           .70,      tbar,            0x053,  nocomm,  opt_setpoint_cbar+0			; ppO2 of setpoint 1
	OPTION_UINT8p10 oSP2ppO2,        gaslist_sp_min,    gaslist_sp_max,           .90,      tbar,            0x054,  nocomm,  opt_setpoint_cbar+1			; ppO2 of setpoint 2
	OPTION_UINT8p10 oSP3ppO2,        gaslist_sp_min,    gaslist_sp_max,          .100,      tbar,            0x055,  nocomm,  opt_setpoint_cbar+2			; ...
	OPTION_UINT8p10 oSP4ppO2,        gaslist_sp_min,    gaslist_sp_max,          .120,      tbar,            0x056,  nocomm,  opt_setpoint_cbar+3			; ...
	OPTION_UINT8p10 oSP5ppO2,        gaslist_sp_min,    gaslist_sp_max,          .140,      tbar,            0x057,  nocomm,  opt_setpoint_cbar+4			; ppO2 of setpoint 5

	OPTION_UINT8d   oSP1Depth,           .0,                   .0,                 .0,      tMeters,         0x058,  nocomm,  opt_setpoint_change+0			; change depth of setpoint 1 (forced to 0 in code)
	OPTION_UINT8d   oSP2Depth,           .0,            gaslist_sp_max_depth,      .0,      tMeters,         0x059,  nocomm,  opt_setpoint_change+1			; change depth of setpoint 2
	OPTION_UINT8d   oSP3Depth,           .0,            gaslist_sp_max_depth,      .0,      tMeters,         0x05A,  nocomm,  opt_setpoint_change+2			; ...
	OPTION_UINT8d   oSP4Depth,           .0,            gaslist_sp_max_depth,      .0,      tMeters,         0x05B,  nocomm,  opt_setpoint_change+3			; ...
	OPTION_UINT8d   oSP5Depth,           .0,            gaslist_sp_max_depth,      .0,      tMeters,         0x05C,  nocomm,  opt_setpoint_change+4			; change depth of setpoint 5

	OPTION_UINT8    oXmittID01L,         .0,                 .255,                 .0,      nounit,          0x0D2,    0x60,  opt_transmitter_id_1+0		; ID of transmitter for gas 1 (LOW)
	OPTION_UINT8    oXmittID01H,         .0,                 .255,                 .0,      nounit,          0x0D3,    0x61,  opt_transmitter_id_1+1		; ID of transmitter for gas 1 (HIGH)
	OPTION_UINT8    oXmittID02L,         .0,                 .255,                 .0,      nounit,          0x0D4,    0x62,  opt_transmitter_id_2+0		; ID of transmitter for gas 2 (LOW)
	OPTION_UINT8    oXmittID02H,         .0,                 .255,                 .0,      nounit,          0x0D5,    0x63,  opt_transmitter_id_2+1		; ID of transmitter for gas 2 (HIGH)
	OPTION_UINT8    oXmittID03L,         .0,                 .255,                 .0,      nounit,          0x0D6,    0x64,  opt_transmitter_id_3+0		; ID of transmitter for gas 3 (LOW)
	OPTION_UINT8    oXmittID03H,         .0,                 .255,                 .0,      nounit,          0x0D7,    0x65,  opt_transmitter_id_3+1		; ID of transmitter for gas 3 (HIGH)
	OPTION_UINT8    oXmittID04L,         .0,                 .255,                 .0,      nounit,          0x0D8,    0x66,  opt_transmitter_id_4+0		; ID of transmitter for gas 4 (LOW)
	OPTION_UINT8    oXmittID04H,         .0,                 .255,                 .0,      nounit,          0x0D9,    0x67,  opt_transmitter_id_4+1		; ID of transmitter for gas 4 (HIGH)
	OPTION_UINT8    oXmittID05L,         .0,                 .255,                 .0,      nounit,          0x0DA,    0x68,  opt_transmitter_id_5+0		; ID of transmitter for gas 5 (LOW)
	OPTION_UINT8    oXmittID05H,         .0,                 .255,                 .0,      nounit,          0x0DB,    0x69,  opt_transmitter_id_5+1		; ID of transmitter for gas 5 (HIGH)
	OPTION_UINT8    oXmittID06L,         .0,                 .255,                 .0,      nounit,          0x0DC,    0x6A,  opt_transmitter_id_6+0		; ID of transmitter for dil 1 (LOW)
	OPTION_UINT8    oXmittID06H,         .0,                 .255,                 .0,      nounit,          0x0DD,    0x6B,  opt_transmitter_id_6+1		; ID of transmitter for dil 1 (HIGH)
	OPTION_UINT8    oXmittID07L,         .0,                 .255,                 .0,      nounit,          0x0DE,    0x6C,  opt_transmitter_id_7+0		; ID of transmitter for dil 2 (LOW)
	OPTION_UINT8    oXmittID07H,         .0,                 .255,                 .0,      nounit,          0x0DF,    0x6D,  opt_transmitter_id_7+1		; ID of transmitter for dil 2 (HIGH)
	OPTION_UINT8    oXmittID08L,         .0,                 .255,                 .0,      nounit,          0x0E0,    0x6E,  opt_transmitter_id_8+0		; ID of transmitter for dil 3 (LOW)
	OPTION_UINT8    oXmittID08H,         .0,                 .255,                 .0,      nounit,          0x0E1,    0x6F,  opt_transmitter_id_8+1		; ID of transmitter for dil 3 (HIGH)
	OPTION_UINT8    oXmittID09L,         .0,                 .255,                 .0,      nounit,          0x0E2,    0x70,  opt_transmitter_id_9+0		; ID of transmitter for dil 4 (LOW)
	OPTION_UINT8    oXmittID09H,         .0,                 .255,                 .0,      nounit,          0x0E3,    0x71,  opt_transmitter_id_9+1		; ID of transmitter for dil 4 (HIGH)
	OPTION_UINT8    oXmittID10L,         .0,                 .255,                 .0,      nounit,          0x0E4,    0x72,  opt_transmitter_id_10+0		; ID of transmitter for dil 5 (LOW)
	OPTION_UINT8    oXmittID10H,         .0,                 .255,                 .0,      nounit,          0x0E5,    0x73,  opt_transmitter_id_10+1		; ID of transmitter for dil 5 (HIGH)

	; opt_name from 85 to 145
	OPTION_STRING   oName,           opt_name_length,                                       tDefName,        0x067,  nocomm,  opt_name						; custom text on surface screen

	; Misc
	OPTION_ENUM8    oColorSetDive,       .4,                                       .0,      tColorSetName0,  0x0A4,    0x31,  opt_dive_color_scheme			; color scheme dive mode
	OPTION_UINT8    oPressureAdjust,     .0,                 .255,                 .0,      nounit,          0x0A5,    0x35,  opt_pressure_adjust			; pressure sensor correction, SIGNED int (clipped to -20/+20 mbar in code)
	OPTION_BOOL     oSafetyStop,                                                   .0,                       0x0A6,    0x36,  opt_safetystop				; =1: show safety stops
	OPTION_UINT8    oCalGasO2,          .21,                 .100,                .21,      tPercent,        0x0A7,    0x37,  opt_calibration_O2_ratio		; calibration gas %O2 (do not move in EEPROM, must stay at .149!)
	OPTION_ENUM8    oBrightness_surface, .3,                                       .2,      tEco,            0x0A8,    0x38,  opt_brightness_surface			; =0: Eco, =1:Medium, =2:Full
	OPTION_BOOL     oFlipScreen,                                                   .0,                       0x0A9,    0x39,  opt_flip_screen				; =1: flip the screen
	OPTION_UINT8p10 ocR_button_left,    .20,                  .80,                .40,      tPercent,        0x0AA,    0x3A,  opt_cR_button_left			; left  button sensitivity
	OPTION_UINT8p10 ocR_button_right,   .20,                  .80,                .40,      tPercent,        0x0AB,    0x3B,  opt_cR_button_right			; right button sensitivity
	OPTION_UINT8    oWork_SAC,           .5,                  .80,                .20,      tLitersMinute,   0x0AC,    0x3C,  char_I_SAC_work				; surface air consumption rate during working    phase, l/min
	OPTION_UINT8    oDeco_SAC,           .5,                  .50,                .20,      tLitersMinute,   0x0AD,    0x3D,  char_I_SAC_deco				; surface air consumption rate during deco stops phase, l/min
	OPTION_BOOL     oDepthWarn,                                                    .1,                       0x0AE,    0x3E,  opt_depth_warn				; =1: blink on depth related attentions and warnings
	OPTION_BOOL     oVSItext,                                                      .0,                       0x0AF,    0x3F,  opt_vsitext					; =1: use the dynamic (depends on depth) ascend rate limits
	OPTION_BOOL     oVSIgraph,                                                     .1,                       0x0B0,    0x40,  opt_vsigraph					; =1: draw the graphical VSI bar
	OPTION_BOOL     oShowppO2,                                                     .0,                       0x0B1,    0x41,  opt_showppo2					; =1: always show the ppO2 value in the warning position
	OPTION_UINT8    oTempAdjust,         .0,                 .255,                 .0,      nounit,          0x0B2,    0x42,  opt_temperature_adjust		; temperature sensor correction, SIGNED int (clipped to -2.0/+2.0 °C in code)
	OPTION_UINT8    oSafetyStopLength,  .60,                 .240,               .180,      nounit,          0x0B3,    0x43,  opt_safety_stop_length		; [s], duration of the safety stop
	OPTION_UINT8    oSafetyStopStart,   .21,                  .61,                .51,      nounit,          0x0B4,    0x44,  opt_safety_stop_start			; [dm], depth at which safety stop appears,    default   51 dm, min 210 dm, max  610 dm
	OPTION_UINT8    oSafetyStopEnd,     .19,                  .39,                .29,      nounit,          0x0B5,    0x45,  opt_safety_stop_end			; [dm], depth at which safety stop disappears, default  290 dm, min 190 dm, max  390 dm
	OPTION_UINT8    oSafetyStopReset,   .81,                 .151,               .101,      nounit,          0x0B6,    0x46,  opt_safety_stop_reset			; [dm], depth at which safety stop re-arms,    default 1010 dm, min 810 dm, max 1510 dm
	;                                                                                                    0x0B7 - 0x0B9										; unused
	OPTION_UINT8    oDiveTimeout,        .1,                  .20,                 .5,      tMinutes,        0x0BA,    0x48,  opt_diveTimeout				; [minutes] timeout for switch from dive mode to surface mode
	OPTION_UINT8    oPSCR_drop,          .0,                  .15,                 .4,      tPercent,        0x0BB,    0x4A,  char_I_PSCR_drop				; pSCR drop [%]
	OPTION_UINT8    oPSCR_lungratio,     .5,                  .20,                .10,      tPercent,        0x0BC,    0x4B,  char_I_PSCR_lungratio			; pSCR lung ratio [1/x]
	;                                                                                                        0x0BD											; in use, see below
	;                                                                                                        0x0BE											; in use, see below
	OPTION_UINT8    oCCmaxFracO2,       .80,                .100,                 .90,      tPercent,        0x0C9,    0x58,  char_I_CC_max_frac_O2			; max. O2 % in Loop
	OPTION_UINT8    oSimSetpoint,        .1,                  .5,                  .1,      tblank,          0x0CA,    0x59,  opt_sim_setpoint_number		; setpoint to use for deco calculation
	OPTION_BOOL     oCalcAscGas,                                                   .0,                       0x0CB,    0x5A,  opt_calc_gasvolume			; calculate OC gas volume needs for ascent
	OPTION_ENUM8    oAltMode,            .4,                                       .0,      tAltModeFly,     0x0CC,    0x5C,  char_I_altitude_wait			; no-fly time calculation for: 0=no-fly, 1=1000m, 2=2000m, 3=3000m
	OPTION_BOOL     oEnable_IBCD,                                                  .1,                       0x0CD,    0x5D,  opt_enable_IBCD				; =1: IBCD warning activated
	;                                                                                                        0x0CE											; not used any more (ex ascent speed)
	OPTION_UINT8    oGasChangeTime,      .0,                   .3,                 .0,      tMinutes,        0x0CF,    0x5B,  char_I_gas_change_time		; (extra) time at a stop to change the gas
	OPTION_UINT8p5  osatmult,          .100,                 .140,               .110,      tPercent,        0x0D0,    0x2A,  opt_sat_multiplier_non_gf		; saturation   factor for NON-GF Mode
	OPTION_UINT8p5  odesatmult,         .60,                 .100,                .90,      tPercent,        0x0D1,    0x2B,  opt_desat_multiplier_non_gf	; desaturation factor for NON-GF Mode
	OPTION_ENUM8    oTrMode,             .4,                                       .1,      tTrModeOff,      0x0F0,    0x7E,  opt_TR_mode					; TR functions - mode
	OPTION_ENUM8    oTr1stPres,      tr_pres_options,                              .1,      tTrPresNone,     0x0F1,    0x7F,  opt_TR_1st_pres				; TR functions - 1st pressure assignment
	OPTION_ENUM8    oTr2ndPres,      tr_pres_options,                              .0,      tTrPresNone,     0x0F2,    0x80,  opt_TR_2nd_pres				; TR functions - 2nd pressure assignment
	OPTION_ENUM8    oTrBailPres,     tr_pres_options,                              .1,      tTrPresNone,     0x0F3,    0x81,  opt_TR_Bail_pres				; TR functions - bailout pressure assignment
	OPTION_UINT8p5  oTrMaxDeltaPres, max_pres_diff_min, max_pres_diff_max,         .5,      tbar,            0x0F4,    0x82,  char_I_max_pres_diff			; TR functions - maximum delta pressure in independent double mode
	;                                                                                                        0x0F5											; not used
	;                                                                                                        0x0F6											; not used
	OPTION_ENUM8    o2ndDepthDisp,       .2,                                       .0,      tMax,            0x0F7,    0x85,  opt_2ndDepthDisp				; =1: show average depth instead of max depth
	OPTION_UINT8p3d oMaxDepth,          .30,            ostc_depth_max,    ostc_depth_max,  tMeters,         0x0F8,    0x86,  opt_max_depth					; depth at which a warning will be given
	OPTION_UINT8    oDescentSpeed,       .5,                  .30,                .10,      tMeterMinute,    0x0F9,    0x87,  char_I_descent_speed			; descent speed for deco calculator          [future option, not used yet]
	OPTION_BOOL     oStoreApnoe,                                                   .0,                       0x0FA,    0x88,  opt_store_apnoe				; =1: store dives in apnoe mode into logbook
	OPTION_ENUM8    oTissueGraphics, tissue_graphics_options,                      .0,      tTissuePresSat,  0x0FB,    0x88,  opt_tissue_graphics			; =0: show pressures and saturations, =1: show N2 and He pressures
	OPTION_ENUM8    oLayout,             .2,                                       .0,      tLayoutNormal,   0x0FC,    0x8A,  opt_layout					; initial layout of dive mode screen =0: normal, =1: big
	OPTION_BOOL     oExtendedStops,                                                .1,                       0x0FD,    0x8B,  opt_ext_stops					; =1: place gas switches also below 1st stop depth
	OPTION_UINT8    oGasDensityAtt,     .40,                  .80,                .52,      nounit,          0x0FE,    0x8C,  char_I_gas_density_att		; threshold for gas density attention [0.1 grams/l]
	OPTION_UINT8    oGasDensityWarn,    .40,                  .80,                .63,      nounit,          0x0FF,    0x8D,  char_I_gas_density_warn		; threshold for gas density warning   [0.1 grams/l]
	OPTION_BOOL     oDilppO2Check,                                                .1,                        0x100,    0x8E,  char_I_dil_check				; =1: check ppO2 of the pure diluent against current setpoint
	OPTION_UINT8    oFirmwareMajor,  fw_version_major,  fw_version_major, fw_version_major, nounit,          0x101,  nocomm,  opt_fw_version_major			; firmware version, major | use as read-only,
	OPTION_UINT8    oFirmwareMinor,  fw_version_minor,  fw_version_minor, fw_version_minor, nounit,          0x102,  nocomm,  opt_fw_version_minor			; firmware version, minor | do not change eeprom index number!
	OPTION_UINT8    oFirmwarebeta,   fw_version_beta ,  fw_version_beta,  fw_version_beta,  nounit,          0x103,  nocomm,  opt_fw_version_beta			; firmware version, beta  |
	OPTION_ENUM8    oS8Mode,             .2,                                       .0,      tCCRS8Mode,      0x104,    0x8F,  opt_s8_mode					; =0: analog, =1: digital RS232
	OPTION_ENUM8    oCaveMode,           .2,                                       .0,      tOff,            0x105,    0x90,  opt_cave_mode					; =1: cave mode switched on
	OPTION_BOOL     oGasContingencyDive,                                           .0,                       0x106,    0x91,  opt_gas_contingency_dive		; =1: dive mode: switch to alternative gas if best gas is depleted
	OPTION_BOOL     oGasDensityCheck,                                              .1,                       0x107,    0x92,  opt_gas_density_check			; gas density is checked (effective in CCR / pSCR modes only)

	;	+---------------------------------------------------------------------------------------------------------------------------------------------+
	;   |  .                                                                                                                                          |
	;	| /|\                                                                                                                                         |
	;	|  |  add new options here!                                                                                                                   |
	;	|  |  EEPROM address  min: 0x012, max: 0x1FF, last used: 0x107, spare: 0x0B7-0x0B9, 0x0F5-0x0F6, disused: 0x0A8, 0x0CE                        |
	;	|  |  serial address  min:  0x20, max:  0xF9, last used:  0x92, spare: 0x83, 0x84 (0xFA - 0xFE are reserved for internal use)                 |
	;	+---------------------------------------------------------------------------------------------------------------------------------------------+

	; ppO2 warnings, sorted by ppO2 levels
	OPTION_UINT8p10 oPPO2Min,     ppo2_warning_low_lowest,  ppo2_warning_low_highest,  ppo2_warning_low_default,  nounit, 0x022, 0x23, char_I_ppO2_min		; ppO2 min on OC   and for pure diluent in CCR
	OPTION_UINT8p10 oPPO2MinCC,   ppo2_warning_loop_lowest, ppo2_warning_loop_highest, ppo2_warning_loop_default, nounit, 0x0BE, 0x4D, char_I_ppO2_min_loop	; ppO2 min on Loop and for pure diluent in pSCR
	OPTION_UINT8p10 oPPO2Max,     ppo2_warning_high_lowest, ppo2_warning_high_highest, ppo2_warning_high_default, nounit, 0x01C, 0x22, char_I_ppO2_max_work	; ppO2 max while in working phase
	OPTION_UINT8p10 oPPO2MaxDeco, ppo2_warning_deco_lowest, ppo2_warning_deco_highest, ppo2_warning_deco_default, nounit, 0x0BD, 0x4C, char_I_ppO2_max_deco	; ppO2 max while in deco stops phase


	; volatile options
	OPTION_UINT8    oGas6O2,         gaslist_min_o2,    gaslist_max_o2,           .21,      tPercent,     volatile,    0xFA,  opt_gas6_O2_ratio				; O2 % of gas 6
	OPTION_UINT8    oGas6He,             .0,            gaslist_max_He,            .0,      tPercent,     volatile,    0xFB,  opt_gas6_He_ratio				; He % of gas 6
	OPTION_UINT8p10 odiveInterval,       .0,                 .240,                 .0,      tMinutes,     volatile,  nocomm,  opt_surface_interval			; additional surface interval for deco calculator
	OPTION_UINT8p2  obottomTime,         .2,                  .60,                .10,      tMinutes,     volatile,  nocomm,  char_I_bottom_time			; bottom time  for deco calculator
	OPTION_UINT8p3d obottomDepth,       .12,                 .120,                .21,      tMeters,      volatile,  nocomm,  char_I_bottom_depth			; bottom depth for deco calculator and simulator
	OPTION_BOOL     oSimAGF,                                                       .0,                    volatile,  nocomm,  opt_sim_use_aGF				; =1: use GF (no) or aGF (yes) in deco calculator
	OPTION_ENUM8    oLogOffsetStep,      .4,                                       .0,      tLogOffStep1, volatile,  nocomm,  opt_logoffset_step			; step size when adjusting the log offset
	OPTION_UINT8    oClearSeconds,       .0,                   .0,                 .0,      nounit,       volatile,  nocomm,  rtc_latched_secs				; used for setting time & date via menu
	OPTION_UINT8    oSetMinutes,         .0,                  .59,                 .0,      nounit,       volatile,  nocomm,  rtc_latched_mins				; ...
	OPTION_UINT8    oSetHours,           .0,                  .23,                 .0,      nounit,       volatile,  nocomm,  rtc_latched_hour				; ...
	OPTION_UINT8    oSetDay,             .1,                  .31,                 .0,      nounit,       volatile,  nocomm,  rtc_latched_day				; ...
	OPTION_UINT8    oSetMonth,           .1,                  .12,                 .0,      nounit,       volatile,  nocomm,  rtc_latched_month				; ...
	OPTION_UINT8    oSetYear,           .18,                  .24,                 .0,      nounit,       volatile,  nocomm,  rtc_latched_year				; ...

	OPTION_UINT8    oFallback,           .0,                 .255,                 .0,      nounit,       volatile,    0x38,  opt_fallback					; unused dummy option for compatibility with 3rd party tools
	OPTION_UINT8    oConservatism,       .0,                 .255,                 .0,      nounit,       volatile,    0x47,  opt_conservatism				; unused dummy option for compatibility with 3rd party tools


 IFDEF _gas_contingency
	OPTION_BOOL     oGasContingencySim,                                            .0,                   volatile,   nocomm,  opt_gas_contingency_sim		; =1: deco calculator: switch to alternative gas if best gas is depleted
 ENDIF

 IFDEF _comm_debug
	OPTION_UINT8p5  oCommTimeout,       .10,                 .200,     rx_timeout/.10,     tCommTimeoutU, volatile, nocomm,  opt_comm_timeout				; comm RX timeout in multiples of 10 ms
 ENDIF

;-----------------------------------------------------------------------------

	global	option_table_end
option_table_end:
	OPTION_END		; end of option table - important: DO NOT OMIT THIS MACRO!

;-----------------------------------------------------------------------------

	END
