#ifdef xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
;
;    shared_definitions.h                     combined next generation V3.08.8
;
;    Declare variables used both in C and ASM code
;
;    This program is free software: you can redistribute it and/or modify
;    it under the terms of the GNU General Public License as published by
;    the Free Software Foundation, either version 3 of the License, or
;    (at your option) any later version.
;
;    This program is distributed in the hope that it will be useful,
;    but WITHOUT ANY WARRANTY; without even the implied warranty of
;    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;    GNU General Public License for more details.
;
;    You should have received a copy of the GNU General Public License
;    along with this program.  If not, see <http://www.gnu.org/licenses/>.
;
;    Copyright (c) 2010, JD Gascuel
;=============================================================================
; RATIONAL
;
; We must enforce good data passing between the C and the ASM parts of code.
; The previous design used two independant definitions of each variable,
; one in C, one in ASM. If they did not match, no error was generated, and
; anything can happend at runtime...
;
; The new design use LINKING to ensure the variables defined in C are at the
; same address when used in ASM code. And it uses a unique declaration file
; (with suitable macros) to make sure they have the same size in both language.
;
; HISTORY
;  2011-01-20: [jDG] Creation
;
; NOTE
;
; This file have to obey both ASM and C syntax. The only common directives
; are #if/#ifdef/#endif and the #define, so they are eavily used to do the
; trick.
;
; BUGS
;=============================================================================
; HISTORY
#endif

#ifdef __18CXX
	//------------------------------------------------------------------------
	// C-Style Declarations:
#	ifndef TEST_MAIN
#		define VAR_UCHAR(n)			extern unsigned char n
#		define TAB_UCHAR(n,size)	extern unsigned char n[size]
#		define VAR_UINT(n)			extern unsigned short n
#		define TAB_UINT(n,size)		extern unsigned short n[size]
#	else
#		define VAR_UCHAR(n)			unsigned char n
#		define TAB_UCHAR(n,size)	unsigned char n[size]
#		define VAR_UINT(n)			unsigned short n
#		define TAB_UINT(n,size)		unsigned short n[size]
#	endif
#else
	;-------------------------------------------------------------------------
	; ASM-Style Declarations:
#define VAR_UCHAR(n)		n	res 1
#define TAB_UCHAR(n,size)	n	res size
#define VAR_UINT(n)			n	res 2
#define TAB_UINT(n,size)	n	res 2*size
#endif


#ifdef xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
    Define Model Dimensions
    NUM_COMP  is the number of compartiments in the Bühlmann ZH-L16 model, ie 16.
    NUM_STOPS is the maximum number of stops computed by decoplanning. 
              Note that the deepest stop is roughly limited to 3m * NUM_STOPS
                   (this is assuming all stops up to the surface are used).
              Note also that if the table overflow, extra stops are ignored,
                   and not reported in TTS summing.
    NUM_GAS   is the number of (potentially) active gas considered during
              ascent simulation.
    NUM_SP    is the number of setpoints
#endif
#define NUM_COMP		0x10
#define NUM_STOPS		0x20
#define NUM_STOPS_LOG	0x0F
#define NUM_GAS			5


#ifdef __18CXX
	//---- BANK 3 DATA -------------------------------------------------------
	// Gather all Data C-Code <--> ASM-Code
	//
	// Attention: keep the first block of variables on position and also do not change
	//            their relative position - this block goes into the deco data vault!
	//
	// Memory usage: 253 Byte used, 3 Byte free
	//
#   pragma udata overlay bank3=0x300
#else
	; in ASM, put the same bank, in overlay mode, at the same address
bank3	equ			0x300
bank3	udata_ovr	bank3
#endif

VAR_UINT  (int_O_desaturation_time);			// || time until tissues desaturated to 5% remains, in minutes
VAR_UINT  (int_O_nofly_time);					// || altitude / no-fly waiting time time in minutes
VAR_UINT  (int_O_CNS_current);					// || current CNS %
VAR_UINT  (int_O_lead_supersat);				// || supersaturation of the leading tissue in %, 100% = on M-line of straight Buhlmann
VAR_UCHAR (char_O_lead_tissue);					// || number of the leading tissue


VAR_UINT  (int_O_TTS_norm);						// total time to surface (TTS)  in normal      plan in minutes
VAR_UINT  (int_O_TTS_alt);						// total time to surface (TTS)  in alternative plan in minutes

VAR_UINT  (int_O_TST_norm);						// total time of all deco stops in normal      plan in minutes
VAR_UINT  (int_O_TST_alt);						// total time of all deco stops in alternative plan in minutes

VAR_UINT  (int_O_CNS_norm);						// CNS% at end of dive in normal dive plan
VAR_UINT  (int_O_CNS_alt);						// CNS% at end of dive in alternative plan

VAR_UINT  (int_O_NDL_norm);						// remaining NDL time for the normal      dive plan in minutes
VAR_UINT  (int_O_NDL_alt);						// remaining NDL time for the alternative dive plan in minutes

VAR_UCHAR (char_O_main_status);					// setup of the deco engine regarding the real tissue   computations
VAR_UCHAR (char_O_deco_status);					// setup of the deco engine regarding the decompression computations
VAR_UCHAR (char_O_deco_warnings);				// vector of warnings generated by the deco engine
VAR_UCHAR (char_O_deco_info);					// vector of infos    generated by the deco engine

VAR_UINT  (int_O_EAD_pres);						// equivalent air      depth (EAD) of breathed gas as relative pressure in[mbar]
VAR_UINT  (int_O_END_pres);						// equivalent narcosis depth (END) of breathed gas as relative pressure in[mbar]

TAB_UCHAR (char_O_tissue_pres_N2,    NUM_COMP);	// N2    tissue pressures   for display purpose
TAB_UCHAR (char_O_tissue_pres_He,    NUM_COMP);	// He    tissue pressures   for display purpose
TAB_UCHAR (char_O_tissue_pressure,   NUM_COMP);	// total tissue pressures   for display purpose
TAB_UCHAR (char_O_tissue_saturation, NUM_COMP);	//       tissue saturations for display purpose

TAB_UINT  (int_O_gas_need_vol,  NUM_GAS);		// gas volumes needed for ascent in liters
TAB_UINT  (int_O_gas_need_pres, NUM_GAS);		// gas volumes needed for ascent in bar as per tank size

VAR_UINT  (int_O_ceiling);						// ascent boundary in mbar relative pressure, calculated at GF-high

VAR_UINT  (int_O_breathed_ppO2);				// ppO2 actually breathed (= int_O_pure_ppO2 if in OC)

VAR_UINT  (int_O_O2_ppO2);						// ppO2 of pure O2 at current depth
VAR_UINT  (int_O_pure_ppO2);					// ppO2 of the current gas or diluent if breathed pure
VAR_UINT  (int_O_pSCR_ppO2);					// ppO2 calculated in pSCR loop

TAB_UINT  (int_O_pressure_need, 2);				// pressure reading, need by deco calculations, in 0.1 bar
VAR_UINT  (int_O_SAC_measured);					// measured SAC rate in 0.1 liter/minute

VAR_UCHAR (char_O_depth_sim);					// depth reached in deco calculation, used in deco calculator to show progress

VAR_UINT  (int_I_pres_respiration);				// absolute pressure breathed
VAR_UINT  (int_I_pres_surface);					// absolute pressure at surface

VAR_UCHAR (char_I_current_gas_num);				// number of gas currently breathed (1..5 for configured gases, 6 for the manual gas)
VAR_UCHAR (char_I_current_gas_type);			// type of current gas: (0=Disabled), 1=First, 2=Travel/Normal, 3=Deco/-
VAR_UCHAR (char_I_He_ratio);					// helium ratio of the currently breathed gas
VAR_UCHAR (char_I_O2_ratio);					// oxygen ratio of the currently breathed gas

VAR_UCHAR (char_I_saturation_multiplier);		// safety factor, 100 = no conservatism, 150 = 50% faster saturation
VAR_UCHAR (char_I_desaturation_multiplier);		// safety factor, 100 = no conservatism,  66 = 50% slower desaturation 

VAR_UCHAR (char_I_GF_High_percentage);			// GF model high value
VAR_UCHAR (char_I_GF_Low_percentage);			// GF model low value

VAR_UCHAR (char_I_last_stop_depth);				// depth of the last deco stop in meters

VAR_UCHAR (char_I_model);						// deco model selection: 0 = ZH-L16, 1 = ZH-L16-GF (with gradient factors)

VAR_UCHAR (char_I_bottom_depth);				// bottom depth for deco calculator and simulator
VAR_UCHAR (char_I_bottom_time);					// bottom time  for deco calculator

VAR_UCHAR (char_I_dive_interval);				// duration of surface break before next dive in minutes, used in simulation
VAR_UCHAR (char_I_sim_advance_time);			// 'fast forward' of dive time, used in simulation (+5 min function)
VAR_UCHAR (char_I_extra_time);					// extra bottom time for fTTs and delayed ascent calculation in minutes

VAR_UCHAR (char_I_const_ppO2);					// ppO2 reported from sensors or selected setpoint

TAB_UCHAR (char_I_deco_O2_ratio,  NUM_GAS);		// oxygen ratios of the configured gases, used for deco calc. | ATTENTION: do not change the
TAB_UCHAR (char_I_deco_He_ratio,  NUM_GAS);		// helium ratios of the configured gases, used for deco calc. |            position of these
TAB_UCHAR (char_I_deco_gas_type,  NUM_GAS);		// type          of the configured gases, used for deco calc. |            arrays relative to
TAB_UCHAR (char_I_deco_gas_change,NUM_GAS);		// change depths of the configured gases, used for deco calc. |            each other!

TAB_UCHAR (char_I_gas_avail_size, NUM_GAS * 2);	// tank sizes, used for pressure needs and SAC calculations
TAB_UCHAR (char_I_gas_avail_pres, NUM_GAS * 2);	// tank pressures available (in multiples of 10 bar), used to generate warnings

VAR_UCHAR (char_I_CC_max_frac_O2);				// limiter for maximum O2% in loop
VAR_UCHAR (char_I_PSCR_drop);					// pSCR parameter drop [%]
VAR_UCHAR (char_I_PSCR_lungratio);				// pSCR parameter lung ratio [1/x]

VAR_UCHAR (char_I_altitude_wait);				// selector for altitude / no-fly waiting time calculation

VAR_UCHAR (char_I_SAC_work);					// gas consumption during bottom part and initial ascent   in liters/minute
VAR_UCHAR (char_I_SAC_deco);					// gas consumption during deco stops and following ascents in liters/minute

VAR_UCHAR (char_I_gas6_depth);					// change depth (MOD) of the manually configured gas in meters

VAR_UCHAR (char_I_ppO2_max_work);				// warning threshold for maximum ppO2 during working phase of the dive
VAR_UCHAR (char_I_ppO2_max_deco);				// warning threshold for maximum ppO2 during deco    phase of the dive
VAR_UCHAR (char_I_ppO2_min);					// warning threshold for maximum ppO2 when breathing OC
VAR_UCHAR (char_I_ppO2_min_loop);				// warning threshold for maximum ppO2 when breathing from CCR or pSCR

VAR_UCHAR (char_I_descent_speed);				// descent speed in meters/minute
VAR_UCHAR (char_I_gas_change_time);				// extra time spent during a stop for doing a gas change, in minutes

VAR_UCHAR (char_I_SAC_mode);					// SAC calculation mode
VAR_UCHAR (char_I_max_pres_diff);				// maximum pressure difference for independent double mode

TAB_UINT  (int_IO_pressure_value,2);			// pressure reading, measured pressure,         in 0.1   bar       | ATTENTION: do not change the position
TAB_UINT  (int_I_pressure_drop, 2);				// pressure reading, average pressure drop,     in 1/160 bar/sec   | of these arrays relative to each other!

TAB_UCHAR (char_I_pressure_gas, 2);				// pressure reading, associated gas (1-5) / diluent (6-10), 0 if off
TAB_UCHAR (char_I_pressure_age, 2);				// pressure reading, age of data
TAB_UCHAR (char_I_pressure_stat,2);				// pressure reading, transmitter status data

TAB_UCHAR (char_O_deco_time_for_log, NUM_STOPS_LOG);	// times of the shallowest NUM_STOPS_LOG deco stops

VAR_UINT  (int_O_profiling_overrun);			// current scheduling overrun in ms
VAR_UINT  (int_O_profiling_overrun_max);		// maximum scheduling overrun in ms
VAR_UCHAR (char_O_profiling_overrun_phase);		// calculation phase causing the maximum overrun
VAR_UCHAR (char_O_profiling_runs_norm);			// runs per cycle for normal      plan
VAR_UCHAR (char_O_profiling_runs_alt);			// runs per cycle for alternative plan

VAR_UINT  (int_O_tank_pressure);				// tank pressure for logging in [bar]
VAR_UINT  (int_O_gas_density);					// gas density of currently breathed mix in multiples of 0.01 grams per liter

VAR_UCHAR (char_I_backtrack_index);				// pointer to next writing position in the char_I_backtrack_storage array

VAR_UCHAR (char_I_gas_density_att);				// threshold for gas density attention [0.1 grams/l]
VAR_UCHAR (char_I_gas_density_warn);			// threshold for gas density warning   [0.1 grams/l]

VAR_UCHAR (char_I_dil_check);					// =1: check ppO2 of the pure diluent against current setpoint


#ifdef __18CXX
	//---- BANK 4 DATA -------------------------------------------------------
	// Gather all Data ASM-Code --> C-Code
	// Memory usage: 96 Byte used, 160 byte free
	//
#   pragma udata overlay bank4=0x400
#else
	; in ASM, put the same bank, in overlay mode, at the same address
bank4	equ			0x400
bank4	udata_ovr	bank4
#endif

TAB_UCHAR (char_O_deco_depth, NUM_STOPS);			// stops table: depth, ...  | ATTENTION: do not re-arrange these
TAB_UCHAR (char_O_deco_time,  NUM_STOPS);			// ... duration, and        |            three arrays relative
TAB_UCHAR (char_O_deco_gas,   NUM_STOPS);			// ... gas breathed         |            to each other!


#ifdef __18CXX
	//---- BANK 11 DATA -------------------------------------------------------
	// Backtracking Data ASM-Code --> C-Code
	// Memory usage: 256 Byte used, 0 byte free
	//
#   pragma udata overlay bank11=0xB00
#else
	; in ASM, put the same bank, in overlay mode, at the same address
bank11	udata_ovr	0xB00
#endif

TAB_UCHAR (char_I_backtrack_storage, 0x100);		// recorded depths for backtracking in cave mode
