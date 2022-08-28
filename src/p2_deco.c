// ***************************************************************************
// p2_deco.c                                  combined next generation V3.19.4
//
//  Created on: 12.05.2009
//  Author: heinrichs weikamp, contributions by Ralph Lembcke and others
//
// ***************************************************************************

//////////////////////////////////////////////////////////////////////////////
// OSTC - diving computer code
// Copyright (C) 2018 HeinrichsWeikamp GmbH
//
//    This program is free software: you can redistribute it and/or modify
//    it under the terms of the GNU General Public License as published by
//    the Free Software Foundation, either version 3 of  the  License,  or
//    (at your option) any later version.
//
//    This program is distributed in the hope that it will be useful,
//    but WITHOUT ANY WARRANTY; without even the implied warranty of
//    MERCHANTABILITY  or  FITNESS FOR A PARTICULAR PURPOSE. See the
//    GNU General Public License for more details.
//
//    You should have received a copy of the GNU General Public License
//    along with this program. If not, see <http://www.gnu.org/licenses/>.
//
//////////////////////////////////////////////////////////////////////////////

// History:
// 01/03/08 v100: first release candidate
// 03/13/08 v101: start of programming ppO2 code
// 03/13/25 v101a: backup of interim version with ppO2 calculation
// 03/13/25 v101: open circuit gas change during deco
// 03/13/25 v101: CNS_fraction_real calculation
// 03/13/26 v101: optimization of tissue calc routines
// 07/xx/2008 v102a: debug of bottom time routine
// 09/xx/2008 v102d: Gradient Factor Model implementation
// 10/10/2008 v104: renamed to build v103 for v118 stable
// 10/14/2008 v104: integration of char_I_last_stop_depth for Gradient Model
// 03/31/2009 v107: integration of FONT Incon24
// 05/23/2010 v109: 5 gas changes & 1 min timer
// 07/13/2010 v110: cns vault added
// 12/25/2010 v110: split in three files (deco.c, main.c, definitions.h)
// 2011/01/20: [jDG] Create a common file included in ASM and C code.
// 2011/01/24: [jDG] Make ascent time an short. No more overflow!
// 2011/01/25: [jDG] Fusion deco array for both models.
// 2011/01/25: [jDG] Use CF(54) to reverse deco order.
// 2011/02/11: [jDG] Reworked gradient-factor implementation.
// 2011/02/15: [jDG] Fixed inconsistencies introduced by gas switch delays.
// 2011/03/21: [jDG] Added gas consumption (CF56 & CF57) evaluation for OCR mode.
// 2011/04/15: [jDG] Store GF_depth in 32 bits (w/o rounding), for a better stability.
// 2011/04/25: [jDG] Added 1mn mode for CNS calculation, to allow it for deco planning.
// 2011/04/27: [jDG] Fixed char_O_gradient_factor calculation when model uses gradient-factor.
// 2011/05/02: [jDG] Added "Future TTS" function (CF58).
// 2011/05/17: [jDG] Various cleanups.
// 2011/08/08: [jDG] Computes CNS during deco planning ascent.
// 2011/11/24: [jDG] Slightly faster and better NDL computation.
// 2011/12/17: [mH]  Remove of the useless debug stuff
// 2012/02/24: [jDG] Remove missed stop bug.
// 2012/02/25: [jDG] Looking for a more stable LOW grad factor reference.
// 2012/09/10: [mH]  Fill char_O_deco_time_for_log for logbook write
// 2012/10/05: [jDG] Better calc_gas_needs_ascent accuracy (average depth, switch between stop).
// 2013/03/05: [jDG] Should vault GF_depth too.
// 2013/03/05: [jDG] Wrobell remark: ascent_to_first_stop works better with finer steps (2sec).
// 2013/05/08: [jDG] A. Salm remark: NOAA tables for CNS are in ATA, not bar.
// 2013/12/21: [jDG] Fix CNS calculation in deco plan w/o marked gas switch
// 2014/06/16: [jDG] Fix Helium diluent. Fix volumes with many travel mix.
// 2014/06/29: [mH]  Compute int_O_ceiling
// 2015/06/12: [jDG] Fix NDL prediction while desaturating with the Buhlmann model.
// 2017/08/04: [mH]  Switch to absolute GF everywhere and apply safety margin parameters to both models (GF and non-GF), fixes from Ralph Lembcke
// 2017/10/31: [rl]  enhancements for pSCR mode and introduction of 2nd deco plan computation
// 2017/12/31: [rl]  completion of 2nd deco plan computation and various up-fixes
// 2018/02/17: [rl]  switch-over to new ceiling rounding (V2.98a)
//
//
// Literature:
// Buhlmann, Albert: Tauchmedizin; 4. Auflage [2002];
// Schroeder, Kai & Reith, Steffen; 2000; Saettigungsvorgaenge beim Tauchen, das Modell ZH-L16, Funktionsweise von Tauchcomputern; http://www.achim-und-kai.de/kai/tausim/saett_faq
// Morrison, Stuart; 2000; DIY DECOMPRESSION; http://www.lizardland.co.uk/DIYDeco.html
// Balthasar, Steffen; Dekompressionstheorie I: Neo Haldane Modelle; http://www.txfreak.de/dekompressionstheorie_1.pdf
// Baker, Erik C.; Clearing Up The Confusion About "Deep Stops"
// Baker, Erik C.; Understanding M-values; http://www.txfreak.de/understanding_m-values.pdf


// *********************************************************************************************************************************
//
//                                                     I N C L U D E S
//
// *********************************************************************************************************************************


#include	<math.h>
#include	<string.h>
#include	"p2_definitions.h"
#define		TEST_MAIN
#include	"shared_definitions.h"
#include	"configuration.inc"


// work-around for a C18 compiler bug (to avoid a warning been thrown for valid code)
#define memcpy(a,b,c)  memcpy((a),(const void*)(b),(c))


// *********************************************************************************************************************************
//
//                                         C O N S T A N T S   D E F I N I T I O N S
//
// *********************************************************************************************************************************


// deco engine scheduling
#define INVOKES_PER_SECOND				2		// number of invocations of the deco engine per second (use powers of 2 only: 1, 2, 4, ...)

#ifdef _hwos_sport
#define BUDGET_PER_SECOND				320		// [ms] total time budget per second for the deco engine, each invocation will preempt after BUDGET_PER_SECOND / INVOKES_PER_SECOND
#else
#define BUDGET_PER_SECOND				640		// [ms] total time budget per second for the deco engine, each invocation will preempt after BUDGET_PER_SECOND / INVOKES_PER_SECOND
#endif

// ambient pressure at different mountain heights
#define P_ambient_1000m					0.880	// [bar]  based on 990 hPa and 20°C at sea level, 15°C at altitude
#define P_ambient_2000m					0.782	// [bar]
#define P_ambient_3000m					0.695	// [bar]

// ambient pressure in aircraft cabin during flying - worst case according to Buhlmann
#define P_ambient_fly					0.600	// [bar], 0.600 bar is the value used by Buhlmann for his flying-after-diving calculations
												//        0.735 bar is a typical cabin pressure for nowadays commercial jet aircrafts
												//        -----
												//        0.135 bar safety margin

// constants and factors
#define ppWater						 0.06270	// water vapor partial pressure in the lungs
#define METER_TO_BAR				 0.09807	// conversion factor (1 m water column =  0.09807 bar)
#define BAR_TO_METER				10.19716	// conversion factor (1 bar            = 10.19716 m  )
#define SURFACE_DESAT_FACTOR		 0.70420	// surface desaturation safety factor
#define HYST						 1.0E-06	// threshold for tissue graphics on-gassing / off-gassing visualization
#define GAS_DENSITY_He_FACTOR          17.64    // in multiples of 0.01 grams per liter
#define GAS_DENSITY_N2_FACTOR         123.46    // in multiples of 0.01 grams per liter
#define GAS_DENSITY_O2_FACTOR         141.02    // in multiples of 0.01 grams per liter

// thresholds
#define CNS_LIMIT_WARNING				100		// threshold for CNS  warning
#define CNS_LIMIT_ATTENTION				 70		// threshold for CNS  attention
#define PRESSURE_LIMIT_WARNING			200		// threshold for pressure reading warning  : 20.0 bar
#define PRESSURE_LIMIT_ATTENTION		500		// threshold for pressure reading attention: 50.0 bar
#define GAS_NEEDS_ATTENTION				  0.7	// threshold for gas needs attention [1 = 100%]
#define O2_CONSUMPTION_LIMIT_ATTENTION	 20		// threshold for O2 "SAC"         attention:  2.0 l/min
#define ppO2_GAP_TO_SETPOINT			 20		// gap between setpoint and max. ppO2 of the pure diluent [cbar]
#define ppO2_MARGIN_ON_MAX				  3		// [cbar] margin on ppO2 max to compensate for surface pressures > 1.000 mbar
#define STOP_CHAINING_LIMIT				  3		// max. number of chained stop table entries before deco calculation is aborted



// deco engine states and modes - (char_O_)main_status: controls current tissue and deco status calculation (as-is situation)
#define CALC_VOLUME						0x01	// =1: calculate gas needs
#define CALCULATE_BOTTOM				0x02	// =1: calculate gas needs in deco calculator mode, =0: in dive mode
#define CAVE_MODE						0x04	// =1: calculate return path and gas needs using backtracking data
#define GAS_CONTINGENCY					0x08	// =1: use a second best gas if best gas is all used up
#define TR_FUNCTIONS					0x10	// =1: calculate TR functions (pressure reading) processing
#define EXTENDED_STOPS					0x20	// =1: allow placement of gas switches below the depth of the 1st stop

#define MODE_MASK						0xC0	// mask for real tissues mode selection
#define MODE_LOOP						0x40	// =1: CCR (MODE_PSCR needs to be cleared) or pSCR mode
#define MODE_CCR						0x40	// to be used with == operator in combination with MODE_MASK only!
#define MODE_PSCR						0x80	// =1: pSCR mode (MODE_LOOP needs to be set, too)

// deco engine states and modes - (char_O_)deco_status: controls deco plan calculation (to-be scenario)
#define PLAN_MASK						0x03	// bit mask covering normal & alternative plan flag
#define COMMAND_MASK					0x07	// bit mask covering all command flags
#define CALCULATING						0x00	// calculations are ongoing
#define START_NORM						0x01	// input:    start calculation of a  normal      deco plan
#define CALC_NORM						0x01	// internal: calculating          a  normal      deco plan
#define COMPLETED_NORM					0x01	// output:   calculation       of a  normal      deco plan has completed
#define START_ALT						0x02	// input:    start calculation of an alternative deco plan
#define CALC_ALT						0x02	// internal: calculating          an alternative deco plan
#define COMPLETED_ALT					0x02	// output:   calculation of       an alternative deco plan has completed
#define INITIALIZE						0x04	// input:    initialize deco engine
#define INITIALIZE_START_NORM			0x05	// input:    initialize deco engine and start calculation of a  normal      deco plan
#define INITIALIZE_START_ALT			0x06	// input:    initialize deco engine and start calculation of an alternative deco plan
#define DECO_CALCULATOR_MODE			0x08	// input:    deco engine is run from deco calculator

#define BAILOUT_MODE					0x10	// =1: allow gas switches before first deco stop
#define DELAYED_ASCENT					0x20	// =1: figure in a delayed ascent / delayed turn of the dive (fTTS)

//      MODE_MASK						0xC0	// mask for simulated tissues mode selection
//      MODE_LOOP						0x40	// =1: CCR (MODE_PSCR needs to be cleared) or pSCR mode
//      MODE_CCR						0x40	// to be used with == operator in combination with MODE_MASK only!
//      MODE_PSCR						0x80	// =1: pSCR mode (MODE_LOOP needs to be set, too)


// deco engine warnings - (char_O_)deco_warnings
#define DECO_WARNING_IBCD				0x01	// IBCD occurring now
#define DECO_WARNING_IBCD_lock			0x02	// IBCD has occurred during the dive
#define DECO_WARNING_MBUBBLES			0x04	// micro bubbles likely to develop now
#define DECO_WARNING_MBUBBLES_lock		0x08	// ditto, but sometime during the dive
#define DECO_WARNING_OUTSIDE			0x10	// tissue pressures outside the Buhlmann model now
#define DECO_WARNING_OUTSIDE_lock		0x20	// tissue pressures outside the model sometime during the dive
#define DECO_ATTENTION_OUTSIDE			0x40	// tissue pressures are very close to the Buhlmann limit
#define DECO_WARNING_INCOMPLETE			0x80	// deco calculation incomplete due to too long compute time

// deco engine status (char_O_)deco_info
#define DECO_MODE						0x01	// =1: deco ppO2 levels are permitted
#define IND_DOUBLE_SWITCH_FLAG			0x02	// =1: switch to other tank advice active
#define GAS_NEEDS_fTTS					0x04	// =1: gas needs are calculated in fTTS mode
#define DECO_ZONE						0x08	// =1: fTTS < TTS (not updated when in bailout mode)
#define DECO_CEILING					0x10	// =1: deco obligation (ceiling > 0)
#define DECO_STOPS_NORM					0x20	// =1: deco stops found in normal      plan
#define DECO_STOPS_ALT					0x40	// =1: deco stops found in alternative plan
#define GAS_NEEDS_CAVE					0x80	// =1: indicated gas needs are calculated in cave mode


// deco engine control - tissue_increment
#define TIME_MASK						0x7F	// =0: time increment is 2 or 6 seconds, 1..127: time increments is 1..127 minutes
#define TISSUE_SELECTOR					0x80	// =0: calculate on simulated tissues,   1     : calculate on real tissues


// deco engine control - next_planning_phase
#define PHASE_00_DONE					0x00	// calculation cycle finished
#define PHASE_10_DIVE_INIT				0x10	// once-per-dive    initialization of the deco engine
#define PHASE_20_CYCLIC_INIT			0x20	// once-every-cycle initialization of the deco engine
#define PHASE_30_EXTENDED_BOTTOM_TIME	0x30	// calculate extended bottom time
#define PHASE_40_BOTTOM_GAS_NEED		0x40	// calculate gas needs for bottom segment
#define PHASE_50_NDL_TIME				0x50	// calculate NDL time
#define PHASE_70_ASCENT_OR_RETURN		0x70	// calculate open water ascent or cave return
#define PHASE_80_RESULTS				0x80	// results - NDL, TTS, TST
#define PHASE_81_GAS_NEEDS_PRESSURES	0x81	// results - convert gas needs from volumes to pressures
#define PHASE_90_FINISH					0x90	// finish calculation cycle


// gas & diluent - type and availability state
//										0x01	// | 0: disabled, 1: first, 2: normal/work, 3: deco
//										0x02	// |
#define GAS_TYPE_MASK					0x03	// bit mask covering the type enumerator
#define GAS_AVAIL_LOST					0x04	// =1: gas/diluent lost   flag (permanently unavailable)
#define GAS_AVAIL_STAGED				0x08	// =1: gas/diluent staged flag (temporary   unavailable)
#define GAS_AVAIL_MASK					0x0C	// bit mask covering the availability flags
#define GAS_NEED_ATTENTION				0x10	// =1: gas need >= attention threshold
#define GAS_NEED_WARNING				0x20	// =1: gas need >= warning   threshold
#define GAS_NEED_MASK					0x30	// bit mask covering the need flags
#define GAS_NEARLY_USED_UP				0x40	// =1: the gas is nearly used up (= at attention threshold)
#define GAS_FULLY_USED_UP				0x80	// =1: the gas is fully  used up (= at warning   threshold)


// flags used with integer numbers
#define INT_FLAG_INVALID				0x0400	// =1: value not valid
#define INT_FLAG_NOT_COMPUTED_YET		0x0800	// =1: value not computed yet
#define INT_FLAG_ZERO					0x0800	// =1: value is zero
#define INT_FLAG_LOW					0x1000	// =1: value is below a lower warning threshold
#define INT_FLAG_NOT_AVAIL				0x1000	// =1: value is not available (not computed)
#define INT_FLAG_HIGH					0x2000	// =1: value is above an upper warning threshold
#define INT_FLAG_OUTDATED				0x2000	// =1: value has not been updated for too long
#define INT_FLAG_ATTENTION				0x4000	// =1: value exceeds the attention threshold
#define INT_FLAG_WARNING				0x8000	// =1: value exceeds the warning threshold
#define INT_FLAG_OUT_OF_RANGE			0x8000	// =1: value exceeds presentable range



// *********************************************************************************************************************************
//
//                                                  ** P R O T O T Y P E S **
//
//                              The Functions are listed in sequence of intended usage / application.
//
// *********************************************************************************************************************************

// Functions used in Surface Mode
static void			 calc_interval(PARAMETER unsigned char time_increment);
														// Calculates the tissue off-gassing under surface conditions.
static void			 calc_desaturation_time(void);		// Calculates the desaturation and no-fly times.
static void			 clear_tissue(void);				// Resets all tissues to surface pressure equilibrium state.
static void			 init_output_vars(void);			// Initializes all deco engine output variables to defaults

// Main entry point in Dive Mode
static void			 calc_hauptroutine(void);			// Sequences all calculations for the real tissues and the deco calculation.

// Functions dedicated to the real Tissues
static void			 calc_hauptroutine_data_input(void);// Initializes environment data and sets gas ratios for the real tissues.

// Functions combined for real Tissues & Deco Calculations
static void			 calc_alveolar_pressures(void);		// Computes the partial pressures from the gas ratios and many more parameters,
														// needs either calc_hauptroutine_data_input() be called beforehand or
														// gas_take_current() or gas_find_best()/gas_take_best() and gas_set_ratios().
static void			 calc_tissues(void);				// Updates the tissues   dependent on the partial pressures of N2 and He.
static void			 calc_CNS(void);					// Updates the CNS value dependent on the partial pressure  of the O2.
static void			 calc_limit(PARAMETER float GF_parameter);
														// Calculates ceiling, current supersaturation factor and some more data.

// Functions for TR
#ifdef _rx_functions
static void			 calc_TR_functions(void);			// Calculates SAC etc.
#endif

// Functions for Cave Mode
#ifdef _cave_mode
static void			 read_backtrack_data(void);			// Gets the data of the next backtracking data set
#endif

// Functions dedicated to Deco Calculations
static void			 clear_deco_table(void);			// Clears the deco stops table, invoked at the start of each calculation cycle.
static void			 gas_take_current(void);			// Take the actual currently used gas for ascent & deco calculation
static unsigned char gas_find_best(void);				// Searches for the best gas available.
static void			 gas_take_best(void);				// Switches to the best gas that has been found found before by gas_find_best().
static void			 gas_set_ratios(void);				// Sets the gas ratios for use in deco calculation (simulated tissues),
														// needs to be called after each gas change (gas_take_current/_better).
static void			 calc_NDL_time_tissue(void);		// Calculates the remaining NDL time for a given tissue.
static unsigned char find_next_stop(void);				// Finds the next stop when in a deco ascent.
static void			 update_deco_table(PARAMETER unsigned char time_increment);
														// Enters a new stop or extends an existing stop in the deco stops table.
static void			 calc_required_volume(void);		// Calculates gas volume required for a given depth, time and usage (SAC rate).
static void			 convert_volume_to_pressure(PARAMETER unsigned char index);
														// Converts gas volumes into pressures and sets respective flags.

// Functions for Results Reporting
static void			 publish_deco_table(void);			// Copies the internal deco stops table to the export interface.
static void			 convert_cur_CNS_for_display(void);	// Converts the current     CNS value from float to integer.
static void			 convert_sim_CNS_for_display(void);	// Converts the end-of-dive CNS value from float to integer.
static void			 convert_sat_for_display(void);		// Converts leading tissue saturation value from float to integer, 1.0 = 100%.
static void			 convert_ceiling_for_display(void);	// Converts ceiling from float to integer in mbar relative pressure.


// internal helper Functions
static void			 load_tmr5(void);					// Loads  a hardware timer which is used for preemptive scheduling.
static void 		 read_tmr5(void);					// Reads  a hardware timer which is used for preemptive scheduling.
static void			 read_CNS_ab_coefficient(void);		// Reads the CNS      a and b coefficients from a ROM table.
static void			 read_CNS_c_coefficient(void);		// Reads the CNS      c       coefficient  from a ROM table.
static void			 read_Buhlmann_coefficients(void);	// Reads the Buhlmann a and b coefficients from a ROM table.
static void			 read_Buhlmann_times(PARAMETER unsigned char period);
														// Reads pre-computed tissue increment factors from a ROM table.
static void			 read_Buhlmann_ht(void);			// Reads the half-times from a ROM table.
static void			 adopt_Buhlmann_coefficients(void);	// Computes average a and b coefficient by the N2/He tissue ratio.
static void			 push_tissues_to_vault(void);		// Stores the state of the real tissues during simulator runs.
static void			 pull_tissues_from_vault(void);		// Restores the state of the real tissues after a simulator run.
static void			 calc_N2_equilibrium(void);			// Calculate partial pressure of N2 in respired air at surface pressure.
static void			 get_saturation_factors(void);		// Get, safeguard and convert the saturation and desaturation factors.
static void			 apply_saturation_factors(void);	// Applies saturation and desaturation factors.


// *********************************************************************************************************************************
//
//                                         V A R I A B L E S   D E F I N I T I O N S
//
// *********************************************************************************************************************************


//---- Bank 13 parameters -----------------------------------------------------
#ifndef UNIX
#   pragma udata overlay bank13=0xd00
static char				C_STACK[256];					// C-code data stack
#   define C_STACK_ADDR C_STACK
#endif

// 256 byte used, bank is full


//---- Bank 7 parameters -----------------------------------------------------
#ifndef UNIX
#   pragma udata bank7=0x700
#endif

// tissue pressures for the real tissues (128 byte)

static float			real_pres_tissue_N2[NUM_COMP];	// 16 floats = 64 bytes  ||  keep order and position of these variables as
static float			real_pres_tissue_He[NUM_COMP];	// 16 floats = 64 bytes  ||  they are backed-up to & restored from EEPROM!

// delta-pressures for the real tissue pressures (128 byte)

static float			real_pres_delta_N2[NUM_COMP];	// 16 floats = 64 bytes
static float			real_pres_delta_He[NUM_COMP];	// 16 floats = 64 bytes

// 256 byte used, bank is full


//---- Bank 8 parameters -----------------------------------------------------
#ifndef UNIX
#   pragma udata bank8=0x800
#endif

// tissue pressures for the simulated tissues (128 byte)

static float			sim_pres_tissue_N2[NUM_COMP];	// 16 floats = 64 bytes
static float			sim_pres_tissue_He[NUM_COMP];	// 16 floats = 64 bytes

// delta-pressures for the simulated tissues (128 byte)

static float			sim_pres_delta_N2[NUM_COMP];	// 16 floats = 64 bytes
static float			sim_pres_delta_He[NUM_COMP];	// 16 floats = 64 bytes

// 256 byte used, bank is full


//---- Bank 12 parameters -----------------------------------------------------

#ifndef UNIX
#   pragma udata bank12=0xc00
#endif

// vault for backing up real tissue pressures (128 byte)

static float			vault_pres_tissue_N2[NUM_COMP];	// 16 floats = 64 bytes
static float			vault_pres_tissue_He[NUM_COMP];	// 16 floats = 64 bytes

// vault for backing up real delta-pressures (128 byte)

static float			vault_pres_delta_N2[NUM_COMP];	// 16 floats = 64 bytes
static float			vault_pres_delta_He[NUM_COMP];	// 16 floats = 64 bytes

// 256 byte used, bank is full


//---- Bank 5 parameters -----------------------------------------------------
#ifndef UNIX
#   pragma udata bank5=0x500
#endif

// Timer5 Interface (3 byte) - Attention: keep order and keep at beginning of bank 5, i.e. at address 0x500 !

static volatile unsigned short	tmr5_value;				// | timer 5 value buffer	MUST be at address 0x500
static volatile unsigned char	tmr5_overflow;			// | timer 5 overflow flag	MUST be at address 0x502


// Environmental and Gas Data (51 byte)

static float			pres_surface;					// absolute pressure at the surface

static float			float_depth_real;				// current real               depth in meters, float
static unsigned char	char_depth_real;				// current real               depth in meters, integer
static unsigned char	char_depth_start;				// start   value of simulated depth in meters, integer
static unsigned char	char_depth_sim;					// current value of simulated depth in meters, integer

static float			real_pres_respiration;			// current real depth in absolute pressure
static float			real_O2_ratio;					// real breathed gas oxygen ratio
static float			real_N2_ratio;					// real breathed gas nitrogen ratio
static float			real_He_ratio;					// real breathed gas helium ratio
static float			real_pSCR_drop;					// real ppO2 drop in pSCR loop

static float			sim_pres_respiration;			// simulated current depth in abs.pressure, used for deco calculations
static float			sim_O2_ratio;					// simulated breathed gas oxygen ratio
static float			sim_N2_ratio;					// simulated breathed gas nitrogen ratio
static float			sim_He_ratio;					// simulated breathed gas helium ratio
static float			sim_pSCR_drop;					// simulated ppO2 drop in pSCR loop


// general Deco Parameters (64 byte)

static float			GF_low;							// gradient factor to determine 1st stop
static float			GF_high;						// gradient factor to determine surfacing

static unsigned char	GF_low_last;					// last GF low,  used to detect a GF change
static unsigned char	GF_high_last;					// last GF high, used to detect a GF change

static unsigned char	GF_depth;						// GF low reference depth in current calculation cycle
static unsigned char	GF_depth_norm;					// GF low reference depth in normal plan
static unsigned char	GF_depth_alt;					// GF low reference depth in alternative plan

static float			GF_slope;						// (GF_high - GF_low) / GF_depth      in current calculation cycle
static float			GF_slope_norm;					// (GF_high - GF_low) / GF_depth_norm in normal plan
static float			GF_slope_alt;					// (GF_high - GF_low) / GF_depth_alt  in alternative plan

static float			float_saturation_multiplier;	// safety factor for  on-gassing rates
static float			float_desaturation_multiplier;	// safety factor for off-gassing rates

static unsigned char	split_N2_He[NUM_COMP];			// used for calculating the desaturation time
static unsigned char	deco_gas_type[NUM_GAS];			// type and state of the deco gases
static unsigned char	peer_tank[NUM_GAS];				// bit flag vector indicating peer tanks holding same gas


// real Context: what we are doing now (16 byte)

static float			CNS_fraction_real;				// current real CNS (1.00 = 100%)
static unsigned short	IBCD_tissue_vector;				// 16 bit vector to memorize all tissues that experience IBCD

static float			pres_respiration_sac;			// used in SAC calculation: current depth in absolute pressure
static float			float_sac;						// used in SAC calculation: SAC value in float
static unsigned short	max_sac_rate;					// used in SAC calculation: threshold for SAC rate attention


// simulated Context: used to calculate Ascent (11 byte)

static float			CNS_fraction_sim;				// CNS after predicted ascent, 0.01 = 1%, as float
static unsigned short	int_sim_CNS_fraction;			// CNS after predicted ascent,    1 = 1%, as integer
static unsigned char	NDL_tissue_start_norm;			// tissue to start with when calculating the normal      NDL time
static unsigned char	NDL_tissue_start_alt;			// tissue to start with when calculating the alternative NDL time
static unsigned char	NDL_tissue_start;				// tissue to start with                    in current cycle
static unsigned char	NDL_tissue_lead;				// tissue with the shortest NDL time found in current cycle
static unsigned char	NDL_tissue;						// tissue for which the NDL is calculated right now


// Result Values from Calculation Functions (9 byte)

static float			ceiling;						// minimum tolerated relative pressure (i.e. without surface pressure)
static float			lead_supersat;					// supersaturation of the leading tissue, 1.0 = 100%
static unsigned char	lead_tissue;					// number of the leading tissue (0-15)


// Transfer Variables between calc_desaturation_time() and calc_desaturation_time_helper() (18 byte)

static float			desat_factor;					// used to cache a pre-computed factor
static float			var_ht;							// half-time factor for the compartment
static float			pres_target;					// target  pressure for the compartment
static float			pres_actual;					// current pressure of  the compartment
static unsigned short	int_time;						// time it takes for the compartment to reach the target pressure


// Gas in Use and Gas Needs (66 byte)

static unsigned char	start_gas_num;					// number of the gas/dil to start with

static unsigned char	sim_gas_last_num;				// number       of the last      used gas
static unsigned char	sim_gas_current_num;			// number       of the currently used gas
static unsigned char	sim_gas_current_depth;			// change depth of the currently used gas

static unsigned char	sim_gas_best_num;				// number       of the best gas available
static unsigned char	sim_gas_best_depth;				// change depth of the best gas available

static float			gas_volume_need[NUM_GAS];		// gas volumes required  for ascent / cave return in liters
static float			gas_volume_avail[NUM_GAS];		// gas volumes available for ascent / cave return in liters
static float			gas_volume_atten[NUM_GAS];		// attention threshold for gas volumes available


// Transfer Variables for calc_required_volume() (7 byte)

static unsigned char	gas_needs_depth;				// depth of the stop or half-way point
static unsigned char	gas_needs_time;					// duration of the stop, ascent or travel phase
static unsigned char	gas_needs_usage_rate;			// gas usage in l/min
static float			gas_needs_volume_due;			// computed amount of required gas volume


// Transfer Values for convert_float_to_int() (6 byte)

static float			float_value;					// input value,   float
static unsigned short	int_value;						// output value, 16 bit


// 251 byte used, 5 byte left in this bank (4 bytes per float, 2 bytes per short, 1 byte per char)


//---- Bank 6 parameters -----------------------------------------------------
#ifndef UNIX
#   pragma udata bank6=0x600
#endif

// Modes, Sequencing and Indexing (17 byte)

static unsigned char	main_status;					// shadow register for char_O_main_status
static unsigned char	deco_status;					// shadow register for char_O_deco_status
static unsigned char	deco_info;						// shadow register for char_O_deco_info
static unsigned char	deco_warnings;					// shadow register for char_O_deco_warnings
static unsigned char	next_planning_phase;			// next calculation phase to be executed
static unsigned char	tissue_increment;				// selector for real/simulated tissues and time increment
static unsigned char	sequence_timer;					// timer to sequence deco engine tasks
static unsigned char	ci;								// index to the Buhlmann tables (compartment index)
static unsigned char	cns_i;							// index to the CNS      tables (ppO2 range  index)
static unsigned char	i;								// general purpose loop counter and index
static unsigned char	j;								// general purpose loop counter and index
static unsigned char	stop_index;						// current stop table position
static unsigned char	chained_stops;					// counter for chained stop entries
static unsigned char	backtrack_index;				// index into the depth backtracking array char_I_backtrack_storage
static unsigned char	backtrack_target_depth;			// current backtracking target depth
static unsigned char	backtrack_step_counter;			// counter for number of 1/10 minute steps done
static unsigned char	spare;							// UNUSED YET, placed here for alignment purpose


// Result Values from Calculation Functions (30 byte)

static float			ppO2_O2;						// ppO2 calculated for breathing pure oxygen in OC   mode
static float			ppO2_OC;						// ppO2 calculated for breathing current gas in OC   mode
static float			ppO2_pSCR;						// ppO2 calculated for breathing current gas in pSCR mode

static float			ppO2;							// partial pressure of breathed oxygen
static float			ppN2;							// partial pressure of breathed nitrogen
static float			ppHe;							// partial pressure of breathed helium

static unsigned char	char_ppO2;						// partial pressure of breathed oxygen, 100 = 1.00 bar
static unsigned char	NDL_time;						// time in full minutes until reaching  no-deco limit (NDL)
static unsigned short	TTS_time;						// time in 1/10 minutes until finishing ascent / cave return
static unsigned short	TST_time;						// time in full minutes of all stops in ascent / cave return


// Buhlmann Model Parameters (40 byte)

static float			var_N2_a;						// Buhlmann a for current N2 tissue
static float			var_N2_b;						// Buhlmann b for current N2 tissue
static float			var_He_a;						// Buhlmann a for current He tissue
static float			var_He_b;						// Buhlmann b for current He tissue
static float			var_a;							// Buhlmann a adopted to current N2/He ratio
static float			var_b;							// Buhlmann b adopted to current N2/He ratio
static float			var_N2_e;						// exposition for current N2 tissue
static float			var_He_e;						// exposition for current He tissue
static float			var_N2_ht;						// half-time  for current N2 tissue
static float			var_He_ht;						// half-time  for current He tissue


// Auxiliary Variables for Data Buffering (28 byte)

static float			N2_equilibrium;					// used for N2 tissue graphics scaling
static float			temp_tissue;					// auxiliary variable to buffer tissue pressures
static float			float_pSCR_factor;				// pre-computed factor for pSCR ppO2 drop calculation
static float			calc_pres_tissue_N2;			// auxiliary variable to buffer tissue N2 pressure
static float			calc_pres_tissue_He;			// auxiliary variable to buffer tissue He pressure
static float			calc_pres_tissue;				// auxiliary variable to buffer total tissue pressure
static float			old_pres_respiration;			// auxiliary variable to buffer sim_pres_respiration


// CNS Coefficients (10 byte)

static float			var_cns_gain;					// two coefficients approximation, gain
static float			var_cns_offset;					// two coefficients approximation, offset
static unsigned short	var_cns_value;					// one coefficient  approximation, value


// Vault to back-up & restore Tissue related Data (6 byte)

static float			vault_CNS_fraction_real;		// stores CNS percentage (1.0 = 100%)
static unsigned char	vault_deco_warnings;			// stores warnings status
static unsigned char	vault_deco_info;				// stores info     status


// stops table (96 byte)

static unsigned char	internal_deco_depth[NUM_STOPS];	// depths     of the stops in meters
static unsigned char	internal_deco_time[NUM_STOPS];	// durations  of the stops in minutes
static unsigned char	internal_deco_gas[NUM_STOPS];	// gases used on the stops (0 / 1-5)


// Performance Profiling (4 byte)

static unsigned short	profiling_runtime;				// performance measurement: runtime of current invocation
static unsigned char	profiling_runs;					// performance measurement: invocations per deco calculation cycle
static unsigned char	profiling_phase;				// performance measurement: current calculation phase


// Function Parameters placed by the C Compiler (7 byte)
/*
static unsigned char	period
static float			parameter
static unsigned char	time_increment
static unsigned char	time_interval
*/


// 238 byte used, 18 byte left in this bank (4 bytes per float, 2 bytes per short, 1 byte per char)



// *********************************************************************************************************************************
//
//                                               L O O K - U P   T A B L E S
//
// *********************************************************************************************************************************

#ifndef UNIX
#   pragma romdata Buhlmann_ht = 0x1DC00  // needs to be in the UPPER bank
#endif

rom const float Buhlmann_ht[2*16] = {
// Compartment half-times, in minutes
//--- N2 ---- He ----------------------
	  4.0,    1.51,
	  8.0,    3.02,
	 12.5,    4.72,
	 18.5,    6.99,
	 27.0,   10.21,
	 38.3,   14.48,
	 54.3,   20.53,
	 77.0,   29.11,
	109.0,   41.20,
	146.0,   55.19,
	187.0,   70.69,
	239.0,   90.34,
	305.0,  115.29,
	390.0,  147.42,
	498.0,  188.24,
	635.0,  240.03
};


#ifndef UNIX
#   pragma romdata CNS_tables = 0x1DC80  // needs to be in the UPPER bank
#endif

rom const float CNS_2_approx[2*11] = {
// 2 coefficient approximation for ppO2 = 51 ... 160 cbar
// CNS increment per 2 sec = 1 / (gain*ppO2 + offset) with ppO2 in [cbar]
//   gain       offset      for ppO2 cbar range
	-533.07,    54000,	//  51 -  60   (index  0)
	-444.22,    48600,	//  61 -  70   (index  1)
	-355.38,    42300,	//  71 -  80   (index  2)
	-266.53,    35100,	//  81 -  90   (index  3)
	-177.69,    27000,	//  91 - 100   (index  4)
	-177.69,    27000,	// 101 - 110   (index  5)
	 -88.84,    17100,	// 111 - 120   (index  6)
	 -88.84,    17100,	// 121 - 130   (index  7)
	 -88.84,    17100,	// 131 - 140   (index  8)
	 -88.84,    17100,	// 141 - 150   (index  9)
	-222.11,    37350	// 151 - 160   (index 10)
};

rom const unsigned short CNS_1_approx[1*18] = {
// 1 coefficient approximation for ppO2 = 161 ... 250 cbar
// CNS increment per 2 sec = c / 100000.0
//  value in [1/100000]    for ppO2 cbar range
	  75,				// 161 - 165   (index  0)
	 102,				// 166 - 170   (index  1)
	 136,				// 171 - 175   (index  2)
	 180,				// 176 - 180   (index  3)
	 237,				// 181 - 185   (index  4)
	 310,				// 186 - 190   (index  5)
	 401,				// 191 - 195   (index  6)
	 517,				// 196 - 200   (index  7)
	 760,				// 201 - 205   (index  8)
	1100,				// 206 - 210   (index  9)
	1500,				// 211 - 215   (index 10)
	2090,				// 216 - 220   (index 11)
	2900,				// 221 - 225   (index 12)
	3900,				// 226 - 230   (index 13)
	4820,				// 231 - 235   (index 14)
	4820,				// 236 - 240   (index 15)
	4820,				// 241 - 245   (index 16)
	4820				// 246 - 250   (index 17)
};


#ifndef UNIX
#   pragma romdata Buhlmann_ab = 0x1DD00  // needs to be in the UPPER bank
#endif

rom const float Buhlmann_ab[4*16] = {
// Compartment a and b factors
// Data ZH-L16C, from Bühlmann Tauchmedizin 2002, option 1a (4mn)
// a for N2    b for N2    a for He    b for He
	1.2599,     0.5050,     1.7424,     0.4245,
	1.0000,     0.6514,     1.3830,     0.5747,
	0.8618,     0.7222,     1.1919,     0.6527,
	0.7562,     0.7825,     1.0458,     0.7223,
	0.6200,     0.8126,     0.9220,     0.7582,
	0.5043,     0.8434,     0.8205,     0.7957,
	0.4410,     0.8693,     0.7305,     0.8279,
	0.4000,     0.8910,     0.6502,     0.8553,
	0.3750,     0.9092,     0.5950,     0.8757,
	0.3500,     0.9222,     0.5545,     0.8903,
	0.3295,     0.9319,     0.5333,     0.8997,
	0.3065,     0.9403,     0.5189,     0.9073,
	0.2835,     0.9477,     0.5181,     0.9122,
	0.2610,     0.9544,     0.5176,     0.9171,
	0.2480,     0.9602,     0.5172,     0.9217,
	0.2327,     0.9653,     0.5119,     0.9267
};


#ifndef UNIX
#   pragma romdata e_tables = 0x1DE00  // needs to be in the UPPER bank
#endif

rom const float e2sec[2*16] = {
// Integration constants for 2 seconds,
// result of  1 - 2^(-(2sec/60sec / HT))
//---- N2 ------------- He ------------
	5.75958E-03,    1.51848E-02,
	2.88395E-03,    7.62144E-03,
	1.84669E-03,    4.88315E-03,
	1.24813E-03,    3.29997E-03,
	8.55371E-04,    2.26041E-03,
	6.03079E-04,    1.59437E-03,
	4.25414E-04,    1.12479E-03,
	3.00019E-04,    7.93395E-04,
	2.11949E-04,    5.60641E-04,
	1.58240E-04,    4.18555E-04,
	1.23548E-04,    3.26795E-04,
	9.66686E-05,    2.55722E-04,
	7.57509E-05,    2.00387E-04,
	5.92416E-05,    1.56716E-04,
	4.63943E-05,    1.22734E-04,
	3.63850E-05,    9.62538E-05
//-------------------------------------
};

rom const float e6sec[2*16] = {
// Integration constants for 6 seconds,
// result of  1 - 2^(-(6sec/60sec / HT))
//---- N2 ------------- He ------------
	1.71794E-02,    4.48661E-02,
	8.62691E-03,    2.26905E-02,
	5.52983E-03,    1.45780E-02,
	3.73973E-03,    9.86726E-03,
	2.56392E-03,    6.76591E-03,
	1.80815E-03,    4.77549E-03,
	1.27570E-03,    3.37057E-03,
	8.99786E-04,    2.37830E-03,
	6.35713E-04,    1.68098E-03,
	4.74646E-04,    1.25514E-03,
	3.70598E-04,    9.80064E-04,
	2.89978E-04,    7.66971E-04,
	2.27236E-04,    6.01040E-04,
	1.77714E-04,    4.70075E-04,
	1.39176E-04,    3.68157E-04,
	1.09151E-04,    2.88734E-04
//-------------------------------------
};

rom const float e1min[2*16] = {
// Integration constants for 1 minute,
// result of  1 - 2^(-(1min / HT))
//----- N2 --------- e 1min He --------
	1.59104E-01,    3.68109E-01,
	8.29960E-02,    2.05084E-01,
	5.39424E-02,    1.36579E-01,
	3.67742E-02,    9.44046E-02,
	2.53454E-02,    6.56359E-02,
	1.79351E-02,    4.67416E-02,
	1.26840E-02,    3.31991E-02,
	8.96152E-03,    2.35301E-02,
	6.33897E-03,    1.66832E-02,
	4.73633E-03,    1.24808E-02,
	3.69981E-03,    9.75753E-03,
	2.89600E-03,    7.64329E-03,
	2.27003E-03,    5.99417E-03,
	1.77572E-03,    4.69082E-03,
	1.39089E-03,    3.67548E-03,
	1.09097E-03,    2.88359E-03
//-------------------------------------
};

rom const float e10min[2*16] = {
// Integration constants for 10 minutes,
// result of  1 - 2^(-(10min / HT))
//---- N2 -------------- He -----------
	8.23223E-01,    9.89851E-01,
	5.79552E-01,    8.99258E-01,
	4.25651E-01,    7.69737E-01,
	3.12487E-01,    6.29027E-01,
	2.26416E-01,    4.92821E-01,
	1.65547E-01,    3.80407E-01,
	1.19840E-01,    2.86538E-01,
	8.60863E-02,    2.11886E-01,
	6.16117E-02,    1.54849E-01,
	4.63665E-02,    1.18026E-01,
	3.63881E-02,    9.34005E-02,
	2.85855E-02,    7.38569E-02,
	2.24698E-02,    5.83504E-02,
	1.76160E-02,    4.59303E-02,
	1.38222E-02,    3.61528E-02,
	1.08563E-02,    2.84646E-02
//-------------------------------------
};


// *********************************************************************************************************************************
//
//                                                 H E L P E R   F U N C T I O N S
//
// *********************************************************************************************************************************


// p2deco code moved from 0x0D000 to 0x0C000 in v.108
//             moved from 0x0C000 to 0x0B000 in v3.09
#ifndef UNIX
#	pragma code p2_deco = 0x0B000
#endif


//////////////////////////////////////////////////////////////////////////////
// Bump to blue-screen when an assert is wrong
#ifdef _DEBUG
void assert_failed(PARAMETER short int line)
{
}
#endif


//////////////////////////////////////////////////////////////////////////////
// When calling C code from ASM context, the C data stack pointer need to be
// reset. The C stack is located in bank 8.

#ifdef CROSS_COMPILE
#	define RESET_C_STACK
#else
#	ifdef _DEBUG
#		define RESET_C_STACK fillDataStack();
		void fillDataStack(void)
		{
			_asm
				LFSR	1,C_STACK_ADDR
				MOVLW	0xCC
		loop:	MOVWF	POSTINC1,0
				TSTFSZ	FSR1L,0
				BRA		loop

				LFSR	1,C_STACK_ADDR
				LFSR	2,C_STACK_ADDR
			_endasm
		}
#	else
#		define	RESET_C_STACK		\
		_asm						\
			LFSR	1,C_STACK_ADDR	\
			LFSR	2,C_STACK_ADDR	\
		_endasm
#	endif
#endif


//////////////////////////////////////////////////////////////////////////////
// Reset timer 5
//
// Note: TMR5 is configured in 16 bit mode: a value written to TMR5H is buffered
//       and will be written to TMR5 together with a successive write to TMR5L.
//       As we don't know in which bank the code will be executed, we use either
//       the bank-save "movff" command, or address mapping via access bank (",0").
//
static void load_tmr5(void)
{
#ifndef CROSS_COMPILE
	_asm
		movff	0x501,0xF7D		// bank-safe load TMR5H from C variable tmr5_value first
		movff	0x500,0xF7C		// bank-safe load TMR5L from C variable tmr5_value thereafter
		bcf		0xFBA,1,0		// clear timer 5 overrun flag (0xFBA = PIR5, bit 1 = TMR5IF)
	_endasm
#else
	return;
#endif
}


//////////////////////////////////////////////////////////////////////////////
// Read timer 5
//
// Note: TMR5 reads in multiples of 1/32 ms, 30.51757813 us/bit to be precise.
//       TMR5 is configured in 16 bit mode: on reading of TMR5L the contents of
//       TMR5H is latched and can be read afterwards without potential rollover.
//       As we don't know in which bank the code will be executed, we use either
//       the bank-save "movff" command, or address mapping via access bank (",0").
//
static void read_tmr5(void)
{
#ifndef CROSS_COMPILE
	_asm
		movff	0xF7C,0x500		// copy TMR5L to C variable tmr5_value, low  byte first
		movff	0xF7D,0x501		// copy TMR5H to C variable tmr5_value, high byte thereafter
		clrf	WREG,0			// clear WREG to 0x00 = no overrun by default
		btfsc	0xFBA,1,0		// did timer 5 overrun? (0xFBA = PIR5, bit 1 = TMR5IF)
		setf	WREG,0			// YES - set WREG to 0xff = overrun detected
		movff	WREG,0x502		// copy WREG to C variable tmr5_overflow
	_endasm
#else
	return;
#endif
}


//////////////////////////////////////////////////////////////////////////////
// Read CNS coefficients gain and offset
//
static void read_CNS_ab_coefficient(void)
{
#ifndef CROSS_COMPILE
	// Note: We don't use far ROM pointer, because handling
	//       24 bit is to complex, hence we have to set the
	//       UPPER page ourself...
	//       -> set to zero if tables are moved to lower pages!
	_asm
		movlw	1
		movwf	TBLPTRU,0
	_endasm
#endif

	{
		overlay rom const float* ptr = &CNS_2_approx[2*cns_i];
		var_cns_gain   = *ptr++;
		var_cns_offset = *ptr++;
	}
}


//////////////////////////////////////////////////////////////////////////////
// Read CNS coefficient c
//
static void read_CNS_c_coefficient(void)
{
#ifndef CROSS_COMPILE
	// Note: We don't use far ROM pointer, because handling
	//       24 bit is to complex, hence we have to set the
	//       UPPER page ourself...
	//       -> set to zero if tables are moved to lower pages!
	_asm
		movlw	1
		movwf	TBLPTRU,0
	_endasm
#endif

	{
		overlay rom const unsigned short* ptr = &CNS_1_approx[cns_i];
		var_cns_value = *ptr++;
	}
}

//////////////////////////////////////////////////////////////////////////////
// Read Buhlmann coefficients a and b for compartment ci
//
static void read_Buhlmann_coefficients(void)
{
#ifndef CROSS_COMPILE
	// Note: We don't use far ROM pointer, because handling
	//       24 bit is too complex, hence we have to set the
	//       UPPER page ourself...
	//       -> set to zero if tables are moved to lower pages!
	_asm
		movlw	1
		movwf	TBLPTRU,0
	_endasm
#endif

	assert( ci < NUM_COMP );

	// use an interleaved array (AoS) to access coefficients with a single addressing
	{
		overlay rom const float* ptr = &Buhlmann_ab[4*ci];
		var_N2_a = *ptr++;
		var_N2_b = *ptr++;
		var_He_a = *ptr++;
		var_He_b = *ptr++;
	}
}


//////////////////////////////////////////////////////////////////////////////
// Read Buhlmann increments for compartment ci
// If period == 0 :  2 sec interval
//              1 :  1 min interval
//              2 : 10 min interval
static void read_Buhlmann_times(PARAMETER unsigned char period)
{
#ifndef CROSS_COMPILE
	// Note: We don't use far ROM pointer, because handling
	//       24 bit is to complex, hence we have to set the
	//       UPPER page by hand...
	//       -> set to zero if tables are moved to lower pages!
	_asm
		movlw	1
		movwf	TBLPTRU,0
	_endasm
#endif

	assert( ci < NUM_COMP );

	// Integration Intervals
	switch(period)
	{
	case 0: //---- 2 or 6 seconds --------------------------------------------
		{
			// check which tissues are selected
			if(tissue_increment & TISSUE_SELECTOR)
			{
				// real tissues - 2 seconds
				overlay rom const float* ptr = &e2sec[2*ci];
				var_N2_e = *ptr++;
				var_He_e = *ptr++;
			}
			else
			{
				// simulated tissues - 6 seconds
				overlay rom const float* ptr = &e6sec[2*ci];
				var_N2_e = *ptr++;
				var_He_e = *ptr++;
			}
		}
		break;

	case 1: //---- 1 minutes -------------------------------------------------
		{
			overlay rom const float* ptr = &e1min[2*ci];
			var_N2_e = *ptr++;
			var_He_e = *ptr++;
		}
		break;

	case 2: //---- 10 minutes ------------------------------------------------
		{
			overlay rom const float* ptr = &e10min[2*ci];
			var_N2_e = *ptr++;
			var_He_e = *ptr++;
		}
		break;

	default:
		assert(0);	// code execution shall never pass along here!
	}
}


//////////////////////////////////////////////////////////////////////////////
// Read Buhlmann half-times for compartment ci
//
static void read_Buhlmann_ht(void)
{

#ifndef CROSS_COMPILE
	// Note: We don't use far ROM pointer, because handling
	//       24 bit is to complex, hence we have to set the
	//       UPPER page ourself...
	//       -> Set to zero if tables are moved to lower pages!
	_asm
		movlw	1
		movwf	TBLPTRU,0
	_endasm
#endif

	assert( ci < NUM_COMP );
	{
		overlay rom const float* ptr = &Buhlmann_ht[2*ci];
		var_N2_ht = *ptr++;
		var_He_ht = *ptr++;
	}

	assert( 4.0    <= var_N2_ht && var_N2_ht <= 635.0  );
	assert( 1.5099 <= var_He_ht && var_He_ht <= 240.03 );
}


//////////////////////////////////////////////////////////////////////////////
// Calculate adopted Buhlmann coefficients
//
// Input:  var_N2_a, var_N2_b       coefficients for N2
//         var_He_a, var_He_b       coefficients for He
//         calc_pres_tissue_N2      partial pressure of N2 in tissue
//         calc_pres_tissue_He      partial pressure of He in tissue
//         calc_pres_tissue         total pressure in tissue
//
// Output: var_a, var_b             coefficients adopted by N2/He ratio
//
static void adopt_Buhlmann_coefficients(void)
{
	// adopt a and b coefficients to current N2/He ratio inside the tissue

#ifdef _helium

	var_a = (var_N2_a * calc_pres_tissue_N2 + var_He_a * calc_pres_tissue_He) / calc_pres_tissue;
	var_b = (var_N2_b * calc_pres_tissue_N2 + var_He_b * calc_pres_tissue_He) / calc_pres_tissue;

#else

	var_a = var_N2_a;
	var_b = var_N2_b;

#endif

}


//////////////////////////////////////////////////////////////////////////////
// Calculate partial pressure of N2 in respired air at surface pressure
//
// Input:  pres_surface     surface pressure
//
// Output: N2_equilibrium   partial pressure of N2 in surface air
//
static void calc_N2_equilibrium(void)
{
	N2_equilibrium = 0.7902 * (pres_surface - ppWater);
}


//////////////////////////////////////////////////////////////////////////////
// Get, safeguard and convert the saturation and desaturation factors
//
// Input:  char_I_saturation_multiplier     saturation   factor (integer)
//         char_I_desaturation_multiplier   desaturation factor (integer)
//
// Output: float_saturation_multiplier      saturation   factor (float)
//         float_desaturation_multiplier    desaturation factor (float)
//
static void get_saturation_factors(void)
{
	// safeguard input parameters that are constant during the course of the dive
	if( char_I_saturation_multiplier   < 100 ) char_I_saturation_multiplier   = 100;
	if( char_I_saturation_multiplier   > 140 ) char_I_saturation_multiplier   = 140;

	if( char_I_desaturation_multiplier <  60 ) char_I_desaturation_multiplier =  60;
	if( char_I_desaturation_multiplier > 100 ) char_I_desaturation_multiplier = 100;

	// convert input parameters to float numbers
	float_saturation_multiplier   = 0.01 * char_I_saturation_multiplier;
	float_desaturation_multiplier = 0.01 * char_I_desaturation_multiplier;
}


//////////////////////////////////////////////////////////////////////////////
// apply_saturation_factors
//
// Apply safety factors for both ZH-L16 models.
//
// Modified:  temp_tissue  safeguarded tissue increment/decrement
//
static void apply_saturation_factors(void)
{
	assert( 0.0 <  float_desaturation_multiplier && float_desaturation_multiplier <= 1.0 );
	assert( 1.0 <= float_saturation_multiplier   && float_saturation_multiplier   <= 2.0 );

	if   ( temp_tissue < 0.0 ) temp_tissue *= float_desaturation_multiplier;
	else                       temp_tissue *= float_saturation_multiplier;
}


//////////////////////////////////////////////////////////////////////////////
// convert_float_to_int
//
// Converts a float within range 0.0 - 9.99 into 16 bit integer scaled in 1/100.
//
static void convert_float_to_int(void)
{
		if      ( float_value <  0.005 ) int_value =   0;
		else if ( float_value >= 9.985 ) int_value = 999;
		else                             int_value = (unsigned short)(100 * float_value + 0.5);
}



// *********************************************************************************************************************************
//
//                                                J U M P  I N   F U N C T I O N S
//
// *********************************************************************************************************************************


//////////////////////////////////////////////////////////////////////////////
// deco_calc_hauptroutine
//
// called from: divemode.asm
//
// Called two times per second during diving, updates the
// tissues every second (i.e. on every second invocation).
//
// On each computation cycle:
// - Updates deco table (char_O_deco_time/depth) with new values,
// - updates ascent time, and
// - sets status to zero (so we can check a cycle has finished).
//
void deco_calc_hauptroutine(void)
{
	RESET_C_STACK
	calc_hauptroutine();
}


//////////////////////////////////////////////////////////////////////////////
// deco_init_output_vars
//
// called from divemode.asm
//
// Initializes all output variables to their default values.
//
void deco_init_output_vars(void)
{
	RESET_C_STACK
	init_output_vars();
}


//////////////////////////////////////////////////////////////////////////////
// deco_clear_tissue
//
// called from: start.asm
//              menu_tree.asm
//              simulator.asm
//
// Sets all tissues to equilibrium with air at ambient pressure,
// resets all CNS values, any warnings and resets all model output.
//
void deco_clear_tissue(void)
{
	RESET_C_STACK
	clear_tissue();
}


//////////////////////////////////////////////////////////////////////////////
// deco_calc_dive_interval
//
// called from: simulator.asm
//
// Updates tissues and CNS value for char_I_dive_interval minutes on air at
// ambient pressure and calculates resulting saturation and ceiling for a
// GF-high of 100% (ceiling and saturation not used by simulator.asm)
//
void deco_calc_dive_interval(void)
{
	RESET_C_STACK
	calc_interval(char_I_dive_interval);
}


//////////////////////////////////////////////////////////////////////////////
// deco_calc_dive_interval_1min
//
// called from: start.asm
//              sleepmode.asm
//              surfmode.asm
//              menu_tree.asm
//              ghostwriter.asm
//
// Updates tissues and CNS value for 1 minute on air at ambient pressure and
// calculates resulting saturation and ceiling for a GF-high of 100%.
//
void deco_calc_dive_interval_1min(void)
{
	RESET_C_STACK
	calc_interval(1);
}


//////////////////////////////////////////////////////////////////////////////
// deco_calc_dive_interval_10min
//
// called from: sleepmode.asm
//
// Updates tissues and CNS value for 10 minutes on air at ambient pressure and
// calculates resulting saturation and ceiling for a GF-high of 100%.
//
void deco_calc_dive_interval_10min(void)
{
	RESET_C_STACK
	calc_interval(10);
}


//////////////////////////////////////////////////////////////////////////////
// deco_calc_desaturation_time
//
// called from: start.asm
//              surfmode.asm
//              menu_tree.asm
//              ghostwriter.asm
//
// Computes desaturation and no-fly times.
//
void deco_calc_desaturation_time(void)
{
	RESET_C_STACK
	calc_desaturation_time();
}


//////////////////////////////////////////////////////////////////////////////
// deco_push_tissues_to_vault
//
// called from: simulator.asm
//
// Makes a backup of the state of the real tissues and the deco engine.
//
void deco_push_tissues_to_vault(void)
{
	RESET_C_STACK
	push_tissues_to_vault();
}


//////////////////////////////////////////////////////////////////////////////
// deco_pull_tissues_from_vault
//
// called from: simulator.asm
//              ghostwriter.asm
//
// Restores the state of the real tissues and the deco engine from the backup.
//
void deco_pull_tissues_from_vault(void)
{
	RESET_C_STACK
	pull_tissues_from_vault();
}


// *********************************************************************************************************************************
//
//                                                    M A I N   F U N C T I O N S
//
// *********************************************************************************************************************************


//////////////////////////////////////////////////////////////////////////////
// Calculate the next deco stop
//
// INPUT, fixed during dive:
//        pres_surface             : surface pressure (as absolute pressure)
//        char_I_last_stop_depth   : depth of the last deco stop
//
// INPUT, may change during dive:
//        GF_high                  : GF high factor
//        GF_low                   : GF low  factor
//        GF_depth                 : GF low  reference depth
//        GF_slope                 : GF slope
//
// MODIFIED
//        char_depth_sim           : simulated depth in meters
//
// OUTPUT
//        GF_depth_norm/_alt       : updated GF low depth reference
//        GF_slope_norm/_alt       : updated GF slope
//
// RETURN
//        TRUE: a deco stop is required, FALSE: no deco stop required
//
static unsigned char find_next_stop(void)
{
	overlay unsigned char depth_1min;
	overlay unsigned char depth_limit;
	overlay unsigned char stop_depth;
	overlay unsigned char next_stop;


	// calculate the current deco ceiling (minimum relative pressure)
	     if( char_I_model   == 0        ) calc_limit(1.0);											// straight Buhlmann
	else if( NDL_time                   ) calc_limit(GF_high);										// with GF: not in deco
	else if( char_depth_sim >= GF_depth ) calc_limit(GF_low);										//          in deco, below or at low depth reference
	else                                  calc_limit(GF_high - GF_slope * (float)char_depth_sim);	//          in deco, above       low depth reference

	// convert the deco ceiling from relative pressure to meters,
	// rounded up (i.e. made deeper) to the next full meter
	depth_limit = (unsigned char)(ceiling * BAR_TO_METER + 0.99);


#ifdef _cave_mode
	// in cave or open water mode?
	if( main_status & CAVE_MODE )
	{
		// cave mode

		// does backtracking require descent or keeping depth?
		if( backtrack_target_depth >= char_depth_sim )
		{
			// YES - decent to target depth or stay at current depth
			char_depth_sim = backtrack_target_depth;

			//     - done, no stop required
			return(0);
		}
		else
		{
			// NO

			// target depth requires an ascent - determine ascent limit due to deco obligation
			stop_depth = depth_limit;

			// apply correction for the shallowest stop
			if( stop_depth && (stop_depth < char_I_last_stop_depth) ) stop_depth = char_I_last_stop_depth;
		}
	}
	else
#endif
	{
		// open water vertical ascent mode - determine the stop depth

		// stop depth is depth limit rounded up (made deeper) to the next multiple of 3 meters
		stop_depth = 3 * ( (depth_limit + 2) / 3 );

		// apply correction for the shallowest stop
		if( stop_depth == 3 ) stop_depth = char_I_last_stop_depth;
	}

	// is the stop depth shallower than the current depth (can we ascent)?
	if( stop_depth < char_depth_sim )
	{
		// YES - ascent by 1 meter
		char_depth_sim--;

		// done, no stop needed
		return(0);
	}

	// -----------------------------------------------------------------------
	// we need to make a stop because we are not allowed to ascent any further
	// -----------------------------------------------------------------------

	// set depth to stop depth
	char_depth_sim = stop_depth;

	// Apply correction in case the stop is to be placed deeper than a
	// previously recorded stop for a gas change. This may happen because
	// the deco stops are placed at the next deeper multiple of 3 meters
	// instead of the real stop's depth. Correction is to relocate the
	// deco stop to the depth of the last gas change. The resulting combined
	// stop's duration will be the sum of the configured gas change time plus
	// the duration of the deco stop itself.
	if( 0              < internal_deco_depth[stop_index] )
	if( char_depth_sim > internal_deco_depth[stop_index] )
	    char_depth_sim = internal_deco_depth[stop_index];

	// if using straight Buhlmann: done, stop needed
	if( char_I_model == 0 ) return(1);

	// -----------------------------------------------------------------------
	// we need to make or hold a stop and we are using the GF extension
	// -----------------------------------------------------------------------

	// is the stop_depth deeper than the GF low depth reference used up to now?
	if( stop_depth > GF_depth )
	{
		// YES - update the GF low depth reference
		GF_depth = stop_depth;
		GF_slope = (GF_high - GF_low) / (float)GF_depth;

		// store for use in next cycles
		if( deco_status & CALC_NORM )
		{
			GF_depth_norm = GF_depth;
			GF_slope_norm = GF_slope;
		}
		else
		{
			GF_depth_alt = GF_depth;
			GF_slope_alt = GF_slope;
		}
	}

#ifdef _cave_mode
	// if in cave mode: done, stop needed
	if( main_status & CAVE_MODE ) return(1);
#endif

	// We have a stop depth candidate. But with a steep GF slope, the stop(s) after
	// this first stop may be allowed to ascent to, too. This is because the gradient
	// factor that will be used at the next depth(s) will allow more tissue super-
	// saturation, maybe so much more that the next stop(s) will be allowed to ascent
	// to. So we have to probe the next stops that are within the reach of 1 minute
	// of ascent as well.

	// compute depth in meters that is reachable within 1 minute of ascent at 10 m/min
	depth_1min = ( char_depth_sim > 10 ) ? char_depth_sim - 10 : 0;

	// probe all stop depths that are in reach of 1 minute of ascent
	next_stop  = stop_depth;

	while(next_stop > 0)
	{
		// compute the depth of the next stop to probe
		if      ( next_stop <= char_I_last_stop_depth ) next_stop  = 0;
		else if ( next_stop == 6                      ) next_stop  = char_I_last_stop_depth;
		else                                            next_stop -= 3;

		// done if the next stop would be above the 1 minute limit
		if( next_stop < depth_1min ) return(1);

		// compute the ceiling for the next stop depth
		calc_limit(GF_high - GF_slope * (float)next_stop);

		// done if the next stop would be above the ceiling
		if( next_stop < (unsigned char)(ceiling * BAR_TO_METER + 0.99) ) return(1);

		// the next stop depth is allowed, ascent to it and redo trying further stop
		char_depth_sim = next_stop;
	}

	// reached the surface, done with no further stop
	return(0);
}


//////////////////////////////////////////////////////////////////////////////
// Take the actual currently used gas for ascent & deco calculation
//
// Input:  start_gas_num            number of the gas/dil to start with (1..5 or 6)
//
// Output: sim_gas_current_num      1..6 or 0 for the manually configured gas/dil
//         sim_gas_current_depth    change depth (MOD) of the gas/dil in meters
//
static void gas_take_current(void)
{
	assert( 1 <= start_gas_num && start_gas_num <= 6 );


	// check origin of the gas/diluent to start with
	if( start_gas_num <= NUM_GAS )
	{
		// pre-configured gas/diluent

		// set gas number
		sim_gas_current_num   = sim_gas_last_num = start_gas_num;

		// set change depth
		sim_gas_current_depth = char_I_deco_gas_change[start_gas_num-1];

		// capture case of non-configured change depth
		if( sim_gas_current_depth == 0 ) sim_gas_current_depth = 255;
	}
	else
	{
		// on-the-fly configured gas/diluent ("gas 6")

		// set gas number
		sim_gas_current_num   = sim_gas_last_num = 0;

		// set change depth
		sim_gas_current_depth = char_I_gas6_depth;
	}
}


//////////////////////////////////////////////////////////////////////////////
// Find the gas with the shallowest change depth below or at the current depth
//
// Input:    char_depth_sim             simulated depth in meters
//           sim_gas_current_num        number of the currently used gas/dil
//           deco_gas_type[]            types and state of the gases/dils
//           char_I_deco_gas_change[]   change depths   of the gases/dils
//
// Modified: sim_gas_best_num           index of the gas (1..5) - only if return value is true
//           sim_gas_best_depth         switch depth            - only if return value is true
//
// Return value is TRUE if a better gas is available
//
static unsigned char gas_find_best(void)
{
	overlay unsigned char switch_depth = sim_gas_current_depth;
	overlay unsigned char switch_gas   =   0;


	// loop over all gases to find the shallowest one below or at current depth
	for( j = 0; j < NUM_GAS; ++j )
	{
		// is this gas available?
		if(     ( deco_gas_type[j] & GAS_TYPE_MASK  )		// gas enabled (type > 0)  ?
		    && !( deco_gas_type[j] & GAS_AVAIL_MASK )		// neither lost nor staged ?
		  )

		// is it not a deco gas unless:
		//    extended stops are activated
		// OR we are on a deco stop
		// OR we are in bailout but not in cave mode
		if(    ( ( deco_gas_type[j] & GAS_TYPE_MASK  ) < 3                            )
		    || ( ( main_status      & EXTENDED_STOPS )                                )
		    || ( ( deco_status & CALC_NORM    ) &&  ( deco_info   & DECO_STOPS_NORM ) )
		    || ( ( deco_status & CALC_ALT     ) &&  ( deco_info   & DECO_STOPS_ALT  ) )
		    || ( ( deco_status & BAILOUT_MODE ) && !( main_status & CAVE_MODE       ) )
		  )

		// is the change depth of the this gas deeper than or
		// at least equal to the current depth?
		if( char_I_deco_gas_change[j] >= char_depth_sim )

		// is the change depth of this gas shallower than
		// the change depth of the best gas found so far,
		// or is it the first better gas found?
		if( char_I_deco_gas_change[j] <  switch_depth )

#ifdef _gas_contingency
		// is there still enough of this gas or shall we don't care?
		if(    !(deco_gas_type[j] & GAS_FULLY_USED_UP )
		    || !( main_status     & GAS_CONTINGENCY   )
		    || !( main_status     & CALC_VOLUME       )
		)
#endif

		// if there is a yes to all these questions, we have a better gas!
		{
			// memorize this gas (1..5) and its change depth
			switch_gas   = j+1;
			switch_depth = char_I_deco_gas_change[j];
		}

	}	// continue looping through all gases to eventually find an even better gas

	// has a best gas been found?
	if( switch_gas )
	{
		// YES - export the best gas and its change depth
		sim_gas_best_num   = switch_gas;
		sim_gas_best_depth = switch_depth;

		// is the best gas different from the current gas?
		if( sim_gas_best_num != sim_gas_current_num )
		{
			// YES - signal advice for a gas change
			return 1;
		}
	}

	// no best gas found or current gas is the best gas
	return 0;
}


//////////////////////////////////////////////////////////////////////////////
// Switch to the best gas
//
// Input:    sim_gas_best_num           index of the best gas (1..5)
//           sim_gas_best_depth         switch depth of the best gas
//
// Modified: sim_gas_current_num        index of the new gas (1..5)
//           sim_gas_current_depth      switch depth of the new gas
//
static void gas_take_best(void)
{
	// memorize current gas as last gas used
	sim_gas_last_num      = sim_gas_current_num;

	// set new gas
	sim_gas_current_num   = sim_gas_best_num;
	sim_gas_current_depth = sim_gas_best_depth;
}


//////////////////////////////////////////////////////////////////////////////
// Set calc_N2/He/O2_ratios by sim_gas_current_num
//
// Input:  sim_gas_current_num           index of gas to use
//         real_O2_ratio, real_He_ratio  if gas =    0 (the manually set gas)
//         char_I_deco_O2/He_ratio[]     if gas = 1..5 (the configured gases)
//
// Output: sim_N2_ratio, sim_He_ratio    ratios of the inert gases
//         sim_pSCR_drop                 ppO2 drop in pSCR loop
//
static void gas_set_ratios(void)
{
	overlay float sim_IG_ratio;

	assert( 0 <= sim_gas_current_num <= NUM_GAS );


#ifdef _helium
	// get gas ratios
	if( sim_gas_current_num == 0 )
	{
		sim_O2_ratio = real_O2_ratio;
		sim_He_ratio = real_He_ratio;
	}
	else
	{
		sim_O2_ratio = 0.01 * char_I_deco_O2_ratio[sim_gas_current_num-1];
		sim_He_ratio = 0.01 * char_I_deco_He_ratio[sim_gas_current_num-1];
	}

	// inert gas ratio (local helper variable)
	sim_IG_ratio  = 1.00 - sim_O2_ratio;

	// N2 ratio
	sim_N2_ratio  = sim_IG_ratio - sim_He_ratio;
#else
	// get O2 ratio
	sim_O2_ratio = ( sim_gas_current_num == 0 ) ? real_O2_ratio : 0.01 * char_I_deco_O2_ratio[sim_gas_current_num-1];

	// set H2 ratio to zero
	sim_He_ratio = 0.0;

	// inert gas ratio (local helper variable)
	sim_IG_ratio  = 1.00 - sim_O2_ratio;

	// N2 ratio
	sim_N2_ratio  = sim_IG_ratio;
#endif

#ifdef _ccr_pscr
	// ppO2 drop in pSCR loop
	sim_pSCR_drop = sim_IG_ratio * float_pSCR_factor;
#endif


	assert( 0.0 <=  sim_N2_ratio && sim_N2_ratio  <= 0.95 );
	assert( 0.0 <=  sim_He_ratio && sim_He_ratio  <= 0.95 );
	assert(        (sim_N2_ratio +  sim_He_ratio) <= 0.95 );
}


//////////////////////////////////////////////////////////////////////////////
// Compute respired ppO2, ppN2 and ppHe
//
// Input:  tissue_increment           : selector  for simulated/real tissues and gases
//         main_status                : breathing mode for real      tissues
//         deco_status                : breathing mode for simulated tissues
//         sim_/real_O2_ratio         : (simulated) O2 ratio breathed
//         sim_/real_N2_ratio         : (simulated) N2 ratio breathed
//         sim_/real_He_ratio         : (simulated) He ratio breathed
//         sim_/real_pres_respiration : (simulated) respiration pressure [bar]
//         sim_/real_pSCR_drop        : (simulated) pSCR O2 drop
//         pres_surface               : surface pressure [bar]
//         char_I_const_ppO2          : ppO2 reported from sensors or setpoint [cbar]
//         ppWater                    : water-vapor pressure inside respiratory tract [bar]
//
// Output: ppN2                       : respired N2 partial pressure
//         ppHe                       : respired He partial pressure
//         char_ppO2                  : breathed ppO2 in %, used for CNS calculation
//
void calc_alveolar_pressures(void)
{
	overlay float calc_pres_respiration;
	overlay float calc_O2_ratio;
	overlay float calc_N2_ratio;

#ifdef _helium
	overlay float calc_He_ratio;
#endif

#ifdef _ccr_pscr
	overlay float calc_pSCR_drop;
#endif

	overlay unsigned char status;


	assert( 0.00 <= real_N2_ratio && real_N2_ratio  <= 1.00 );
	assert( 0.00 <= real_He_ratio && real_He_ratio  <= 1.00 );
	assert(        (real_N2_ratio +  real_He_ratio) <= 1.00 );
	assert( 0.800 < real_pres_respiration && real_pres_respiration < 14.0 );

	assert( 0.00 <= sim_N2_ratio && real_N2_ratio  <= 1.00 );
	assert( 0.00 <= sim_He_ratio && real_He_ratio  <= 1.00 );
	assert(         (sim_N2_ratio +  sim_He_ratio) <= 1.00 );
	assert( 0.800 < sim_pres_respiration && sim_pres_respiration < 14.0 );


	// get input data according to context
	if( tissue_increment & TISSUE_SELECTOR )
	{
		//---- real tissues -----------------------------------------------------------
		calc_pres_respiration = real_pres_respiration;

		status                = main_status;
		calc_O2_ratio         = real_O2_ratio;
		calc_N2_ratio         = real_N2_ratio;

#ifdef _helium
		calc_He_ratio         = real_He_ratio;
#endif

#ifdef _ccr_pscr
		calc_pSCR_drop        = real_pSCR_drop;
#endif
	}
	else
	{
		//---- simulated tissues ------------------------------------------------------

#ifdef _cave_mode
		// in cave mode?
		if( !(main_status & CAVE_MODE) )
		{
#endif

			// (NO) - correct sim_pres_respiration if shallower than calculated stop depth
			calc_pres_respiration = ( real_pres_respiration < sim_pres_respiration ) ? real_pres_respiration : sim_pres_respiration;

#ifdef _cave_mode
		}
#endif


		status                = deco_status;
		calc_O2_ratio         = sim_O2_ratio;
		calc_N2_ratio         = sim_N2_ratio;

#ifdef _helium
		calc_He_ratio         = sim_He_ratio;
#endif

#ifdef _ccr_pscr
		calc_pSCR_drop        = sim_pSCR_drop;
#endif
	}

	//---- OC, CCR and Bailout Mode Gas Calculations -----------------------------------

	// calculate ppO2 of pure oxygen
	ppO2_O2 = calc_pres_respiration - ppWater;

	// capture failure condition in case real_pres_respiration is < ppWater (should never happen...)
	if( ppO2_O2 < 0.0 ) ppO2_O2 = 0.0;

	// calculate ppO2 of the pure gas (OC, diluent)
	ppO2_OC = ppO2_O2 * calc_O2_ratio;

#ifdef _ccr_pscr

	// calculate pSCR ppO2
	ppO2_pSCR = ppO2_OC - calc_pSCR_drop;

	// capture failure condition in case ppO2_pSCR becomes negative
	if( ppO2_pSCR < 0.0 ) ppO2_pSCR = 0.0;


	//---- Loop modes : adjust ppN2 and ppHe for change in ppO2 due to setpoint (CCR) or drop (pSCR) ---
	if( status & MODE_LOOP )
	{
		overlay float const_ppO2;
		overlay float   max_ppO2;

		// get the current sensor reading (CCR / pSCR if fitted) or the fixed setpoint (CCR) / a zero (pSCR)
		const_ppO2 = 0.01 * char_I_const_ppO2;

		// Limit the setpoint to the maximum physically possible ppO2. This prevents for
		// example calculating with a setpoint of 1.3 bar in only 2 meters of depth.
		// Additionally, the ppO2 can be further reduced to account for exhaled inert gases
		// accumulating in the loop by the user-adjustable setting char_I_CC_max_frac_O2.
		// (ppWater is neglected here)
		max_ppO2 = 0.01 * char_I_CC_max_frac_O2 * calc_pres_respiration;

		if( const_ppO2 > max_ppO2 ) const_ppO2 = max_ppO2;

		// check which kind of loop we are on
		if( status & MODE_PSCR )
		{
			//---- pSCR Mode --------------------------------------------------------------------------

			// Use the sensor value if available and in real tissue context, else use calculated ppO2.
			ppO2 = ( char_I_const_ppO2 && (tissue_increment & TISSUE_SELECTOR)) ? const_ppO2 : ppO2_pSCR;
		}
		else
		{
			//---- CCR Mode ---------------------------------------------------------------------------

			// derive breathed ppO2 from (char_I_)const_ppO2, which holds sensor reading or selected setpoint
			ppO2 = const_ppO2;
		}

		// adjust overall gas pressure for change in ppO2 due to setpoint (CCR) or drop (pSCR),
		// capture potential failure conditions first:
		if(    ( calc_pres_respiration <  ppO2 )     // sensor reading or selected setpoint is higher than ambient pressure
		    || ( calc_O2_ratio         > 0.995 ) )   // diluent is pure O2, i.e. calc_N2_ratio + calc_He_ratio = 0 would give a div/0
		{
			// failure condition present, set predetermined result
			calc_pres_respiration = 0.0;
		}
		else
		{
			// no failure conditions present, equation can be executed
			calc_pres_respiration -= ppO2;
#ifdef _helium
			calc_pres_respiration /= calc_N2_ratio + calc_He_ratio;
#else
			calc_pres_respiration /= calc_N2_ratio;
#endif
		}
	}
	else
#endif	// _ccr_pscr
	{
		//---- OC mode ---------------------------------------------------------------------------------

		// breathed ppO2 is ppO2 of pure gas
		ppO2 = ppO2_OC;
	}


	//---- derive char_ppO2 in [cbar], used for calculating CNS% ---------------------------------------

	if      ( ppO2 <  0.01  ) char_ppO2  =   0;
	else if ( ppO2 >= 2.545 ) char_ppO2  = 255;
	else                      char_ppO2  = (unsigned char)(100 * ppO2 + 0.5);


	//---- calculate ppN2 and ppHe ---------------------------------------------------------------------

	// compute ppN2 and ppHe, capture potential failure conditions first:
	if( calc_pres_respiration > ppWater )
	{
		// subtract water vapor pressure
		calc_pres_respiration -= ppWater;

		// calculate partial pressures
		ppN2 = calc_N2_ratio * calc_pres_respiration;

#ifdef _helium
		ppHe = calc_He_ratio * calc_pres_respiration;
#else
		ppHe = 0.0;
#endif

	}
	else
	{
		// calculated respired pressure is < water vapor pressure, thus set ppN2 and ppHe to 0
		ppN2 = 0.0;
		ppHe = 0.0;
	}

#ifdef _ccr_pscr
	// calculating real tissues?
	if( tissue_increment & TISSUE_SELECTOR )
	{
		overlay unsigned char temp;

		// compute gas density of current mix in multiples of 0.01 grams per liter
		int_O_gas_density = (unsigned int)( GAS_DENSITY_He_FACTOR * ppHe + GAS_DENSITY_N2_FACTOR * ppN2 + GAS_DENSITY_O2_FACTOR * ppO2 );

		// convert gas density into an 8 bit integer, scaling 0.1 grams per liter
		temp = (unsigned char)( (int_O_gas_density + 9) / 10 );

		// limit to display max and set warning or attention flag
		     if( temp >  99                      ) int_O_gas_density  = 999 | INT_FLAG_WARNING;
		else if( temp >= char_I_gas_density_warn ) int_O_gas_density |=       INT_FLAG_WARNING;
		else if( temp >= char_I_gas_density_att  ) int_O_gas_density |=       INT_FLAG_ATTENTION;
	}
#endif
}


//////////////////////////////////////////////////////////////////////////////
// Initializes all output variables to their default values
//
static void init_output_vars(void)
{
	// clear the internal stops table from remains lasting from the previous dive or deco calculator run
	clear_deco_table();

	// publish the cleared stops table to the display functions
	publish_deco_table();

	// clear the published gas needs in volume and pressure
	for( i = 0; i < NUM_GAS; ++i )
	{
		int_O_gas_need_vol[i]  = 0;
		int_O_gas_need_pres[i] = 0 + INT_FLAG_ZERO + INT_FLAG_INVALID;
	}

	// values initially to be set to zero
	int_O_ceiling           = 0;						// ceiling depth in mbar
	char_O_deco_info        = 0;						// clear all deco information flags
	char_O_deco_warnings    = 0;						// clear all deco warning     flags

	// default desaturation time to 24 hours (it will not be computed during a dive)
	int_O_desaturation_time = 1440;

	// initialize CNS values
	int_O_CNS_norm          = 0 + INT_FLAG_INVALID;
	int_O_CNS_alt           = 0 + INT_FLAG_INVALID;

	// initialize NDL times
	int_O_NDL_norm         = 240;
	int_O_NDL_alt          = 240;

	// initialize stop times
	int_O_TST_norm        = 0;
	int_O_TST_alt         = 0 + INT_FLAG_INVALID + INT_FLAG_NOT_COMPUTED_YET + INT_FLAG_ZERO;


	// initialize ascent / return times
	int_O_TTS_norm          = 0;
	int_O_TTS_alt           = 0 + INT_FLAG_INVALID + INT_FLAG_NOT_COMPUTED_YET;

#ifdef _rx_functions
	// clear TR values
	int_O_SAC_measured      = 0 + INT_FLAG_NOT_AVAIL;	// SAC rate
	int_O_pressure_need[0]  = 0 + INT_FLAG_NOT_AVAIL;	// pressure need to reading 1
	int_O_pressure_need[1]  = 0 + INT_FLAG_NOT_AVAIL;	// pressure need to reading 2
	int_O_tank_pressure     = 0;						// tank pressure for logging
#endif

#ifdef _helium
	int_O_gas_density = 0;
#endif

	// also clear any time++ request
	char_I_sim_advance_time = 0;
}


//////////////////////////////////////////////////////////////////////////////
// Reset all tissues to surface pressure equilibrium state
//
// Input:  int_I_pres_surface             current surface pressure in hPa (mbar)
//
// Output: real_pres_tissue_N2[]          partial pressure of N2 in real tissues
//         real_pres_tissue_He[]          partial pressure of He in real tissues
//         char_O_tissue_pres_N2[]        partial pressure of N2 for tissue graphics
//         char_O_tissue_pres_He[]        partial pressure of He for tissue graphics
//         char_O_tissue_pressure[]       total   pressure       for tissue graphics
//         CNS_fraction_real              internal CNS value
//         int_O_CNS_current              current CNS value
//         int_O_CNS_norm                 CNS value at end of normal      dive plan
//         int_O_CNS_alt                  CNS value at end of alternative dive plan
//         char_O_deco_warnings           deco warnings vector
//         int_O_NDL_norm                 remaining NDL time in normal      dive plan
//         int_O_NDL_alt                  remaining NDL time in alternative dive plan
//         int_O_TTS_norm                 ascent time (TTS)  in normal      dive plan
//         int_O_TTS_alt                  ascent time (TTS)  in alternative dive plan
//         int_O_lead_supersat            supersaturation of the leading tissue
//
static void clear_tissue(void)
{
	// safeguard and convert the surface pressure (mbar -> bar) (*)
	if( int_I_pres_surface < 500 ) pres_surface = 0.500;
	else                           pres_surface = 0.001 * int_I_pres_surface;

	// calculate partial pressure of N2 in respired air at surface pressure
	calc_N2_equilibrium();

	// cycle through the 16 Buhlmann tissues
	for( ci = 0; ci < NUM_COMP; ci++ )
	{
		// reset tissue pressures
		real_pres_tissue_He[ci]    = 0.0;				// He
		real_pres_tissue_N2[ci]    = N2_equilibrium;	// N2

		real_pres_delta_He[ci]     = 0.0;				// He
		real_pres_delta_N2[ci]     = 0.0;				// N2

		// reset tissue pressures for scaled tissue graphics
		char_O_tissue_pres_He[ci]  =  0;				// He
		char_O_tissue_pres_N2[ci]  = 10;				// N2
		char_O_tissue_pressure[ci] = 10;				// combined
	}

	// reset CNS values
	CNS_fraction_real = 0.0;
	int_O_CNS_current = int_O_CNS_norm = int_O_CNS_alt = 0;

	// reset some more vars to their defaults
	int_O_NDL_norm       = 240;
	int_O_NDL_alt        = 240;
	int_O_TST_norm       = 0;
	int_O_TST_alt        = 0 + INT_FLAG_ZERO;
	int_O_TTS_norm       = 0;
	int_O_TTS_alt        = 0;
	int_O_lead_supersat  = 0;

	// reset all warning and info flags
	char_O_deco_warnings = 0;
	char_O_deco_info     = 0;
}


//////////////////////////////////////////////////////////////////////////////
// Deco engine main code
//
// This is the major code in dive mode, it calculates the tissue pressures,
// the bottom time, and it calculates the ascend with all deco stops, etc.
//
// Input:    char_O_main_status              deco engine control and real      tissues mode
//           char_O_deco_status              deco engine control and simulated tissues mode
//           char_I_sim_advance_time         mailbox for bottom time incrementing
//
//           char_I_SAC_work                 gas usage rate during working    phase in l/min
//           char_I_SAC_deco                 gas usage rate during deco stops phase in l/min
//
//           char_I_model                    selector for GF extension
//           char_I_saturation_multiplier    safety factor for tissue saturation
//           char_I_desaturation_multiplier  safety factor for tissue desaturation
//
//           char_I_pressure_gas[]           amount of gas available for ascent / cave return in bar
//           int_I_pressure_drop[]           pressure drop used to calculate SAC rate
//           char_I_gas_avail_size[]         size of the tanks in liters
//
// Output:   int_O_O2_ppO2                   partial pressure of pure O2 at current depth
//           int_O_pure_ppO2                 partial pressure of O2 in gas at current depth
//           int_O_pSCR_ppO2                 partial pressure of O2 in gas at current depth, corrected for pSCR mode
//           int_O_breathed_ppO2             partial pressure of O2 currently breathed
//
//           char_O_deco_status              deco engine computations status
//           char_O_deco_info                deco engine information vector
//           char_O_deco_warnings            deco engine warnings    vector
//
//           int_O_NDL_norm                  remaining NDL time in normal      dive plan
//           int_O_NDL_alt                   remaining NDL time in alternative dive plan
//           int_O_TTS_norm                  ascent time (TTS)  in normal      dive plan
//           int_O_TTS_alt                   ascent time (TTS)  in alternative dive plan
//           int_O_CNS_norm                  CNS value at end   of normal      dive plan
//           int_O_CNS_alt                   CNS value at end   of alternative dive plan
//
//           int_O_gas_need_vol[]            calculated gas volumes   needed for ascent / cave return
//           int_O_gas_need_pres[]           calculated gas pressures needed for ascent / cave return
//
//           int_O_SAC_measured              measured surface air consumption (SAC) rate in l/min
// 
// Modified: int_IO_pressure_value[]         warning flags added to pressure reading 1 & 2
//           int_IO_pressure_need[]          pressure needs      to pressure reading 1 & 2
//
static void calc_hauptroutine(void)
{
	overlay unsigned short int_ppO2_min;
	overlay unsigned short int_ppO2_max_warn;
	overlay unsigned short int_ppO2_max_att;
	overlay unsigned short int_ppO2_max_dil;
	overlay float          EAD_pres;
	overlay float          END_pres;

	//=============================================================================================

	//
	//--- Setup Part ---------------------------------------------------------------------------------
	//

	// set time limit for preempting deco calculations, timer is 16 bit and increments every 1/32 ms
	tmr5_value = 65535 - (32 * BUDGET_PER_SECOND / INVOKES_PER_SECOND);

	// load timer
	load_tmr5();

	// read command flags and set up what to do
	switch( char_O_deco_status & COMMAND_MASK )
	{

	case INITIALIZE:
	case INITIALIZE_START_NORM:
	case INITIALIZE_START_ALT:

		// copy master modes to shadow registers
		main_status = char_O_main_status;
		deco_status = char_O_deco_status;

		// clear all command flags on the master mode to signal that the command is read and in processing
		char_O_deco_status &= ~COMMAND_MASK;

		// clear the initialization flag on the shadow copy
		deco_status &= ~INITIALIZE;

		// initialize the sequence timer
		sequence_timer = 0;

		// set the calculation phase to start with to doing the once-per-dive initialization
		next_planning_phase = PHASE_10_DIVE_INIT;

		break;


	case START_NORM:
	case START_ALT:

		// copy master modes to shadow registers
		main_status = char_O_main_status;
		deco_status = char_O_deco_status;

		// clear all command flags on the master mode to signal that the command is read and in processing
		char_O_deco_status &= ~COMMAND_MASK;

		// set the calculation phase to start with to doing the cyclic initialization
		next_planning_phase = PHASE_20_CYCLIC_INIT;

		// continue in CALCULATING


	case CALCULATING:

		// keep current calculation phase

		// step the sequence timer
		sequence_timer = (sequence_timer < INVOKES_PER_SECOND * 2 - 1) ? sequence_timer + 1 : 0;

		break;
	}


	//
	//--- End of Setup Part -----------------------------------------------------------------------
	//

	//=============================================================================================

	//
	//---- Calculations Part (real Tissues) -------------------------------------------------------
	//


	// target the real tissues with 2 second increments by default
	tissue_increment = TISSUE_SELECTOR | 0;


	// Tasks every second, if more than 1 invocation per second: on the first section of the second.
	// Requests for tissue "fast forward" are executed immediately.
#if (INVOKES_PER_SECOND > 1)
	if(    ( sequence_timer          == 0                  )
	    || ( sequence_timer          == INVOKES_PER_SECOND )
	    || ( char_I_sim_advance_time  > 0                  )
	)
#endif
	{
		// acquire current environmental data
		calc_hauptroutine_data_input();

		// calculate ppO2, ppN2 and ppHe for real tissues
		calc_alveolar_pressures();

		// add decent calculation here and include trigger in above if-statement
		// TODO

	} // tasks every second, on the first section of the second


	// Tasks every 2 seconds, on the first section of the respective second.
	// Requests for tissue "fast forward" are executed immediately.
	if(    ( sequence_timer           == 0 )
	    || ( char_I_sim_advance_time   > 0 )
	)
	{
		// Tissue and CNS updates are based on 2 seconds periods!

		// Set up normal tissue updating or "fast forward" updating for simulator
		// sim+5' function and deco calculator bottom time calculation.
		if( char_I_sim_advance_time > 0 )
		{
			// configure "fast forward" tissue updating
			tissue_increment = TISSUE_SELECTOR | char_I_sim_advance_time;

			// clear the request
			char_I_sim_advance_time = 0;
		}

		// calculate the real tissues
		calc_tissues();

		// update the CNS value for the real tissues
		calc_CNS();

		// calculate ceiling (at GF_high or 100%) and leading tissue supersaturation
		if   ( char_I_model ) calc_limit(GF_high);		// GF factors enabled
		else                  calc_limit(  1.0  );		// classic Buhlmann

		// convert the ceiling value to integer
		convert_ceiling_for_display();

		// convert the saturation value of the leading tissue to integer
		convert_sat_for_display();

		// convert the CNS value to integer
		convert_cur_CNS_for_display();

	} // tasks every 2 seconds


	// Tasks every second, if more than 1 invocation per second: on the first section of the second.
#if (INVOKES_PER_SECOND > 1)
	if(    ( sequence_timer == 0                  )
	    || ( sequence_timer == INVOKES_PER_SECOND )
	)
#endif
	{
		//---- Calculate and Export EAD and END ------------------------------------------------------

		// calculate EAD (Equivalent Air Depth) as pressure in [bar]:
		// equivalent depth for the same N2 level with plain air
		EAD_pres = ppN2 / 0.7902 + ppWater - pres_surface;

		// calculate END (Equivalent Narcotic Depth) as pressure in [bar]:
		// as before, but with O2 treated as narcotic, too
		// Source: The Physiology and Medicine of Diving by Peter Bennett and David Elliott,
		//         4th edition, 1993, W.B.Saunders Company Ltd, London.
		END_pres = real_pres_respiration - ppHe - pres_surface;


		// export EAD, factor 10 is because conversion delivers in [cbar] but we need [mbar]
		float_value = EAD_pres; convert_float_to_int(); int_O_EAD_pres = int_value * 10;

		// export END, factor 10 is because conversion delivers in [cbar] but we need [mbar]
		float_value = END_pres; convert_float_to_int(); int_O_END_pres = int_value * 10;


		//---- Compute ppO2 Values in [cbar] ---------------------------------------------------------

		float_value = ppO2;      convert_float_to_int(); int_O_breathed_ppO2 = int_value;	// breathed gas
#ifdef _ccr_pscr
		float_value = ppO2_O2;   convert_float_to_int(); int_O_O2_ppO2       = int_value;	// pure oxygen
		float_value = ppO2_OC;   convert_float_to_int(); int_O_pure_ppO2     = int_value;	// pure gas
		float_value = ppO2_pSCR; convert_float_to_int(); int_O_pSCR_ppO2     = int_value;	// pSCR calculated
#endif


		//---- Set/Clear Deco Mode ------------------------------------------------------------------

		// Clear the deco mode flag if:
		//      deco mode is set
		// AND  we are deeper than 7 meters below the deepest deco stop
		//      (7 meters chosen as to be 2 stop depth intervals plus 1 additional meter below)
		if (    ( deco_info & DECO_MODE ) > 0                        )
		if (    ( char_depth_real       ) > char_O_deco_depth[0] + 7 )
		          deco_info &= ~DECO_MODE;

		// Set the deco mode flag if:
		//     deco mode is not set
		// AND     breathing an OC deco gas (gas type 3)
		//     OR  breathing a gas or diluent that officially is disabled (type 0)
		//     OR  there is a deco stop
		//
		// Remark: when breathing a gas, its lost & staged flags are cleared
		//
		if (    ( deco_info & DECO_MODE ) == 0 )
		if (    ( char_I_current_gas_type == 3 )
		     || ( char_I_current_gas_type == 0 )
		     || ( char_O_deco_depth[0]     > 0 )
		   )
		          deco_info |=  DECO_MODE;


		//---- Compute ppO2 Warnings ------------------------------------------------------------------

		// compute conditional min value
#ifdef _ccr_pscr
		int_ppO2_min = ( main_status & MODE_LOOP ) ? (unsigned short)char_I_ppO2_min_loop : (unsigned short)char_I_ppO2_min;
#else
		int_ppO2_min = (unsigned short)char_I_ppO2_min;
#endif

		// determine the absolute max value (should be the deco one, but who knows...)
		int_ppO2_max_warn = ( char_I_ppO2_max_work > char_I_ppO2_max_deco) ? char_I_ppO2_max_work : char_I_ppO2_max_deco;

		// add some margin to compensate for surface pressures > 1.000 mbar
		int_ppO2_max_warn += ppO2_MARGIN_ON_MAX;

		// determine the normal max value
		int_ppO2_max_att = ( deco_info & DECO_MODE ) ? (unsigned short)char_I_ppO2_max_deco : (unsigned short)char_I_ppO2_max_work;

		// add some margin to compensate for surface pressures > 1.000 mbar
		int_ppO2_max_att  += ppO2_MARGIN_ON_MAX;

#ifdef _ccr_pscr
		// default value for the upper diluent ppO2 warning threshold is the upper warning threshold
		int_ppO2_max_dil = int_ppO2_max_warn;

		// when enabled and in CCR mode, the upper diluent warning threshold gets adjust according to the current setpoint
		if(  char_I_dil_check                     )
		if( (main_status & MODE_MASK) == MODE_CCR )
		{
			overlay unsigned short max_dil;

			//  The upper diluent ppO2 threshold is ppO2_GAP_TO_SETPOINT below the setpoint...
			// (the condition protects from negative numbers which would cause a wrap-around in unsigned integers)
			max_dil = (char_I_const_ppO2 > ppO2_GAP_TO_SETPOINT) ? (unsigned short)(char_I_const_ppO2 - ppO2_GAP_TO_SETPOINT) : 0;

			// ...but never above int_ppO2_max_warn
			if( max_dil < int_ppO2_max_warn ) int_ppO2_max_dil = max_dil;

			// We do not need to guard int_ppO2_max_dil against becoming lower than char_I_ppO2_min because the check
			// against char_I_ppO2_min is done first and will then raise a low warning and inhibit further checks.
		}
#endif

		// check for safe range of breathed gas
		if      ( int_O_breathed_ppO2 <=                 int_ppO2_min      ) int_O_breathed_ppO2 |= INT_FLAG_WARNING + INT_FLAG_LOW;
		else if ( int_O_breathed_ppO2 >=                 int_ppO2_max_warn ) int_O_breathed_ppO2 |= INT_FLAG_WARNING + INT_FLAG_HIGH;
		else if ( deco_info           &                  DECO_MODE         ) ; // no attention generated in deco mode
		else if ( main_status         &                  MODE_LOOP         ) ; // no attention generated in loop modes
		else if ( int_O_breathed_ppO2 >=                 int_ppO2_max_att  ) int_O_breathed_ppO2 |= INT_FLAG_ATTENTION;

#ifdef _ccr_pscr
		// check for safe range of pure oxygen
		if      ( int_O_O2_ppO2       >=                 int_ppO2_max_warn ) int_O_O2_ppO2       |= INT_FLAG_WARNING + INT_FLAG_HIGH;

		// check for safe range of pure diluent
		if      ( int_O_pure_ppO2     <= (unsigned short)char_I_ppO2_min   ) int_O_pure_ppO2     |= INT_FLAG_WARNING + INT_FLAG_LOW;
		else if ( int_O_pure_ppO2     >=                 int_ppO2_max_warn ) int_O_pure_ppO2     |= INT_FLAG_WARNING + INT_FLAG_HIGH;
		else if ( int_O_pure_ppO2     >=                 int_ppO2_max_dil  ) int_O_pure_ppO2     |= INT_FLAG_ATTENTION;

		// check for safe range of calculated pSCR loop gas
		if      ( int_O_pSCR_ppO2     <=                 int_ppO2_min      ) int_O_pSCR_ppO2     |= INT_FLAG_WARNING + INT_FLAG_LOW;
		else if ( int_O_pSCR_ppO2     >=                 int_ppO2_max_warn ) int_O_pSCR_ppO2     |= INT_FLAG_WARNING + INT_FLAG_HIGH;
#endif

	} // tasks every second / on the first section of the second


#ifdef _rx_functions

	// only when TR functions are enabled
	if( main_status & TR_FUNCTIONS )

	// Tasks every second, if more than 1 invocation per second: on the second section of the second.
#if (INVOKES_PER_SECOND > 1)
	if(    ( sequence_timer == 1                      )
	    || ( sequence_timer == INVOKES_PER_SECOND + 1 )
	)
#endif
	{
		calc_TR_functions();
	}

#endif // _rx_functions


	//
	//---- End of Computations for the real Tissues -----------------------------------------------
	//

	//=============================================================================================

	//
	//---- Begin of Computations for Ascent and Decompression (simulated Tissues) -----------------
	//

	// Dispatcher: select what to do based on the current calculation phase
	do
	{

#ifdef _profiling
		profiling_phase = next_planning_phase;
#endif

		switch( next_planning_phase )
		{

		//
		//---- once-per-dive Initialization of the Deco Engine ------------------------------------
		//
		case PHASE_10_DIVE_INIT:

		// initialize all output variables to defaults
		init_output_vars();

		// initialize values that will be recalculated later on periodically
		deco_warnings         = 0;		// reset all deco warnings
		deco_info             = 0;		// reset all deco infos
		IBCD_tissue_vector    = 0;		// reset tissue IBCD vector
		NDL_tissue_start_norm = 0;		// initialize the tissue to start with when calculating normal      NDL time
		NDL_tissue_start_alt  = 0;		// initialize the tissue to start with when calculating alternative NDL time

		// enforce initialization of GF data on first cyclic initialization
		GF_high_last          = 255;
		GF_low_last           = 255;


		// calculate volumes available for each gas
		for( i = 0; i < NUM_GAS; i++ )
		{
			// total available volume = tank size * fill press, char_I_gas_avail_pres is in multiples of 10 bar
			gas_volume_avail[i] = (float)char_I_gas_avail_size[i] * (float)char_I_gas_avail_pres[i] * 10.0;

			// attention threshold
			gas_volume_atten[i] = gas_volume_avail[i] * GAS_NEEDS_ATTENTION;
		}


#ifdef _profiling
		int_O_profiling_overrun_max = 0;
		char_O_profiling_runs_norm  = 0;
		char_O_profiling_runs_alt   = 0;
#endif


		// the next calculation phase will do the cyclic initialization of the deco engine if a
		// normal or alternative plan shall be calculated, else the calculation cycle is done.
		if( deco_status & PLAN_MASK ) next_planning_phase = PHASE_20_CYCLIC_INIT;
		else                          next_planning_phase = PHASE_00_DONE;

		break;


		//
		//---- once-per-cycle Initialization of the Deco Engine -----------------------------------
		//
		case PHASE_20_CYCLIC_INIT:

		// target the simulated tissues (flag bit 7 = 0)
		tissue_increment = 0;

		// clear the internal stops table
		clear_deco_table();

		// clear deco stops info
		if( deco_status & CALC_NORM ) deco_info &= ~DECO_STOPS_NORM;
		else                          deco_info &= ~DECO_STOPS_ALT;

		// initialize the simulated tissues with the current state of the real tissues
		memcpy(sim_pres_tissue_N2, real_pres_tissue_N2, 256);

		// initialize the gas types
		for( i = 0; i < NUM_GAS; i++ )
		{
			deco_gas_type[i] = char_I_deco_gas_type[i];
		}

#ifdef _gas_contingency
		// if in gas contingency mode,
		// check if there are multiple tanks with the same gas
		// (or at least with the same change depth...)
		if( main_status & GAS_CONTINGENCY )
		{
			for( i = 0; i < NUM_GAS; i++ )
			{
				// default to no peer tanks existing
				peer_tank[i] = 0;

				// tank enabled?
				if( char_I_deco_gas_type[i] )
				{
					// YES - check for peer tanks
					for( j = 0; j < NUM_GAS; j++ )
					{
						// do not check a tank against itself
						if( i == j ) continue;

						// is the other tank also enabled and does it have the same change depth?
						if( char_I_deco_gas_type[j]   &  GAS_TYPE_MASK             )
						if( char_I_deco_gas_change[i] == char_I_deco_gas_change[j] )
						{
							// YES - memorize it as a peer tank
							peer_tank[i] |= (1 << j);
						}
					}
				}
			}
		}
#endif

		// initialize GF parameters if using GF model
		if( char_I_model != 0 )
		{
			// update GF parameters (GFs may have been switched between GF and aGF)
			if( (char_I_GF_Low_percentage != GF_low_last) || (char_I_GF_High_percentage != GF_high_last) )
			{
				// store new values in integer format
				GF_low_last  = char_I_GF_Low_percentage;
				GF_high_last = char_I_GF_High_percentage;

				// safeguard and store new values in float format
				GF_low   = ( GF_low_last  > 10          ) ? 0.01 * GF_low_last  : 0.10  ;
				GF_high  = ( GF_high_last > GF_low_last ) ? 0.01 * GF_high_last : GF_low;


				// reset low depth references and slopes
				GF_depth_norm = 0;
				GF_depth_alt  = 0;
				GF_slope_norm = 0.0;
				GF_slope_alt  = 0.0;
			}

			// retrieve GF parameters for current calculation cycle
			if( deco_status & CALC_NORM )
			{
				GF_depth = GF_depth_norm;
				GF_slope = GF_slope_norm;
			}
			else
			{
				GF_depth = GF_depth_alt;
				GF_slope = GF_slope_alt;
			}
		}

		// initialize the simulated CNS value with the current CNS value of the real tissues
		CNS_fraction_sim = CNS_fraction_real;

		// initialize the simulated pressure with the current real pressure
		sim_pres_respiration = real_pres_respiration;

		// initialize the simulated depth with the current real depth
		char_depth_sim = char_depth_start = char_depth_real;

		// cache the gas/dil to start calculations with
		start_gas_num = char_I_current_gas_num;


		// Lookup the gas that is currently breathed with the real tissues and set it as
		// the gas to be used with the simulated tissues, too. This gas will be used until
		// gas_find_best()/gas_take_best() is invoked and switches to a better gas.
		gas_take_current();

		// Setup the calculation ratio's for N2, He and O2 (sim_N2/He/_O2_ratio).
		// These ratios can be kept until a gas switch is done. Thus, if a call to
		// gas_find_best() has found a better gas and this gas is taken by a call
		// to gas_take_best(), gas_set_ratios() needs to be called again.
		gas_set_ratios();

		// compute ppO2, ppN2 and ppHe for current depth from sim_pres_respiration
		calc_alveolar_pressures();

		// initialize the no decompression limit (NDL) time to 240 minutes
		NDL_time = 240;

		// clear the Total Time to Surface (TTS) and the Total Stops Time (TST)
		TTS_time = 0;
		TST_time = 0;

		// retrieve the tissue that had the shortest NDL time during last calculation
		NDL_tissue_start = ( deco_status & CALC_NORM ) ? NDL_tissue_start_norm : NDL_tissue_start_alt;

		// start calculating NDL time with the tissue that had the shortest NDL last time
		NDL_tissue      = NDL_tissue_start;
		NDL_tissue_lead = NDL_tissue_start;

		// tag gas needs as not calculated in fTTS mode by default
		deco_info &= ~GAS_NEEDS_fTTS;

		// shall calculate gas needs?
		if( main_status & CALC_VOLUME )
		{
			// set the usage rate (SAC rate), starting with working part of the dive
			gas_needs_usage_rate = char_I_SAC_work;

			// clear the gas volume needs for gases 1-5
			for( i = 0; i < NUM_GAS; ++i ) gas_volume_need[i] = 0.0;

#ifdef _rx_functions
			// only for OSTC TR model with TR functions enabled
			if( main_status & TR_FUNCTIONS )
			{
				// invalidate pressure needs to pressure readings
				int_O_pressure_need[0] = 0 + INT_FLAG_NOT_AVAIL;
				int_O_pressure_need[1] = 0 + INT_FLAG_NOT_AVAIL;
			}
#endif
		}


#ifdef _cave_mode
		if( main_status & CAVE_MODE )
		{
			// get the position of the first data set to start the backtracking from
			backtrack_index = char_I_backtrack_index;

			// get the first backtracking data set
			read_backtrack_data();
		}
#endif


#ifdef _profiling
		profiling_runs = 0;
#endif

		// The next calculation phase will
		// - calculate the extended bottom segment if extended bottom time  is configured (fTTS),
		// - calculate the bottom segment gas need if gas needs calculation is configured,
		// - proceed with calculating the NDL time else.
		if      ( deco_status & DELAYED_ASCENT ) next_planning_phase = PHASE_30_EXTENDED_BOTTOM_TIME;
		else if ( main_status & CALC_VOLUME    ) next_planning_phase = PHASE_40_BOTTOM_GAS_NEED;
		else                                     next_planning_phase = PHASE_50_NDL_TIME;

		break;


		//
		//---- extended Bottom Time ---------------------------------------------------------------
		//
		case PHASE_30_EXTENDED_BOTTOM_TIME:

		// tag gas needs as calculated in fTTS mode
		deco_info |= GAS_NEEDS_fTTS;

		// program interval on simulated tissues (flag bit 7 = 0)
		tissue_increment = char_I_extra_time;

		// update the simulated tissues for tissue_increment (char_I_extra_time) minutes at depth,
		// calc_alveolar_pressures() has already been called in cyclic initialization
		calc_tissues();

		// update the CNS value for tissue_increment (char_I_extra_time) minutes at depth
		calc_CNS();

		// the next calculation phase will
		// - calculate the extended bottom segment gas needs if gas needs calculation is configured,
		// - proceed with calculating the NDL time else.
		if   ( main_status & CALC_VOLUME ) next_planning_phase = PHASE_40_BOTTOM_GAS_NEED;
		else                               next_planning_phase = PHASE_50_NDL_TIME;

		break;


		//
		//---- Bottom Segment Gas Need ------------------------------------------------------------
		//
		case PHASE_40_BOTTOM_GAS_NEED:

		// on gas 1-5 ?
		if( sim_gas_current_num )
		{
			// YES - take either the whole bottom time or just the fTTS/bailout extra time
			gas_needs_time = ( main_status & CALCULATE_BOTTOM ) ? char_I_bottom_time : char_I_extra_time;

			// any time to do?
			if( gas_needs_time )
			{
				// YES - set the bottom depth
				gas_needs_depth = char_depth_start;

				// calculate required gas volume
				calc_required_volume();

				// take the result
				gas_volume_need[sim_gas_current_num-1] = gas_needs_volume_due;
			}
		}


		// the next calculation phase will calculate the NDL time
		next_planning_phase = PHASE_50_NDL_TIME;

		break;


		//
		//---- NDL Time ---------------------------------------------------------------------------
		//
		case PHASE_50_NDL_TIME:

		// Calculate the remaining no decompression limit (NDL) time for the tissue NDL_tissue.
		// NDL_time will be updated if the NDL time found is shorter than the current NDL_time.
		//
		// In the initialization phase of the calculation cycle:
		// - NDL_time      had been initialized to 240 (minutes),
		// - NDL_tissue    had been initialized to the tissue with
		//                 the shortest NDL time in the last cycle.
		//
		calc_NDL_time_tissue();

		// advance to next tissue, wrapping around after last tissue
		NDL_tissue = (NDL_tissue + 1) & (NUM_COMP - 1);

		// did we run out of NDL time or did we have probed all tissues?
		if( (NDL_time == 0) || (NDL_tissue == NDL_tissue_start) )
		{
			// YES

			// set the tissue with the shortest NDL time found as
			// the one to start with in the next calculation cycle
			if( deco_status & CALC_NORM ) NDL_tissue_start_norm = NDL_tissue_lead;
			else                          NDL_tissue_start_alt  = NDL_tissue_lead;

			// done with calculating NDL time, next phase will calculate the ascent / cave return
			next_planning_phase = PHASE_70_ASCENT_OR_RETURN;
		}

		break;


		//
		//---- Ascent or Return (cave mode) -------------------------------------------------------
		//
		case PHASE_70_ASCENT_OR_RETURN:

		{
			overlay unsigned char doing_deco_stop  = 0;
			overlay unsigned char doing_gas_change = 0;


			// target simulated tissues, default is 1 minute interval
			tissue_increment = 1;

			// check if a deco stop is required:
			// - stays at the current depth if a stop is required,
			// - ascents to the next stop if possible, else
			// - ascents by 1 meter
			if( find_next_stop() )
			{
				//---- stop required --------------------

				// memorize doing a deco stop
				doing_deco_stop = 1;

				// set flag for deco stops found
				if( deco_status & CALC_NORM ) deco_info |= DECO_STOPS_NORM;
				else                          deco_info |= DECO_STOPS_ALT;

				// encountered a deco stop, so switch to deco usage rate (SAC deco)
				gas_needs_usage_rate = char_I_SAC_deco;

				// check if there is a better gas to switch to
				if( gas_find_best() )
				{
					// YES - memorize doing a gas change
					doing_gas_change = 1;

					// take the gas
					gas_take_best();

					// set the new calculation ratios for N2, He and O2
					gas_set_ratios();

					// add the gas change time to the stop time
					tissue_increment += char_I_gas_change_time;
				}

				// add the stop to an existing stop or add a new stop
				update_deco_table(tissue_increment);
			}
			else
			{
				//---- no stop required -----------------

				// switch to 1/10 minute interval
				tissue_increment = 0;

				// memorize not doing a deco stop
				doing_deco_stop = 0;

				// check if there is a better gas to switch to, but only:
				//
				//      if extended stops are activated OR if cave mode is enabled OR if in bailout
				// AND  if the actual depth (char_depth_start) is deeper or at the change
				//      depth of the better gas (change depth has not been passed yet) *)
				// AND  if the depth of the last stop is above (shallower) or at the change
				//      depth of the better gas (do not switch on final ascent)        *)
				//
				// *) skipped when calculating in cave mode
				//
				// Attention: do not use a && formula over all 'if' terms, the
				//            conditions need to be evaluated in the given order!
				//
				if(    ( main_status & EXTENDED_STOPS )
				    || ( main_status & CAVE_MODE      )
				    || ( deco_status & BAILOUT_MODE   )
				  )
				if(          gas_find_best()          )
#ifdef _cave_mode
				if( ( char_depth_start       >= sim_gas_best_depth ) || ( main_status & CAVE_MODE ) )
				if( ( char_I_last_stop_depth <= sim_gas_best_depth ) || ( main_status & CAVE_MODE ) )
#else
				if( ( char_depth_start       >= sim_gas_best_depth )                                )
				if( ( char_I_last_stop_depth <= sim_gas_best_depth )                                )
#endif
				{
					// YES - memorize doing a gas change
					doing_gas_change = 1;

					// take the gas
					gas_take_best();

					// set the new calculation values for N2, He and O2
					gas_set_ratios();

					// create a stop lasting the gas change time
					tissue_increment = char_I_gas_change_time;

					// if in deco and run from the deco calculator:
					// create a stop for the gas change in the stops table
					if( !NDL_time && (deco_status & DECO_CALCULATOR_MODE) )
						update_deco_table(tissue_increment);
				}

			} // stop / no stop


#ifdef _cave_mode
			// cave mode actions
			if( main_status & CAVE_MODE )
			{
				// doing a deco stop?
				if( doing_deco_stop )
				{
					// YES - not moving, reset the 1/10 minute steps counter
					backtrack_step_counter = 10;
				}
				else
				{
					// NO - on the move, switch back to SAC work
					gas_needs_usage_rate = char_I_SAC_work;

					//    - decrement the 1/10 minute steps counter if not already zero
					if( backtrack_step_counter ) backtrack_step_counter--;

					//    - target backtracking depth reached?
					if( char_depth_sim == backtrack_target_depth )
					{
						// YES - on target depth

						// target depth reached within first 1/10 minute?
						if( backtrack_step_counter == 9 )
						{
							// YES - will not change depth any more while remaining 9/10 of
							//       the minute, so can do the full full minute in one step
							tissue_increment       = 1;
							backtrack_step_counter = 0;
						}

						// on the move for a minute or more now?
						// (incl. doing full minute in one step)
						if( backtrack_step_counter == 0 )
						{
							// YES - get the data of the next backtracking data set
							read_backtrack_data();
						}
					}
				}
			} // cave mode
#endif

			// shall calculate gas needs?
			if( main_status & CALC_VOLUME )
			{
				overlay unsigned char index_last_gas = sim_gas_last_num    - 1;
				overlay unsigned char index_curr_gas = sim_gas_current_num - 1;

#ifdef _cave_mode
				// in cave mode?
				if( main_status & CAVE_MODE )
				{
					// YES - set the depth for the gas needs calculation to the
					//       simulated stop / on-the-move depth
					gas_needs_depth = char_depth_sim;
				}
				else
#endif
				{
					// NO - set the depth for the gas needs calculation to the shallower
					//      one of the actual depth (char_depth_start, current real depth)
					//      and the simulated (stop) depth, as we may on purpose dive
					//      shallower than we should to conserve on a low running gas supply
					gas_needs_depth = ( char_depth_start < char_depth_sim ) ?
							char_depth_start : char_depth_sim;
				}

				// doing a gas change and a gas change time is set?
				if( doing_gas_change && char_I_gas_change_time )
				{
					// YES - set time it takes for switching the gas
					gas_needs_time = char_I_gas_change_time;

					//     - calculate required gas volume for the gas change
					calc_required_volume();

					//     - add gas change demand to overall demand on the last gas
					if( sim_gas_last_num    ) gas_volume_need[index_last_gas] += gas_needs_volume_due;

					//     - add gas change demand to overall demand on the current gas
					if( sim_gas_current_num ) gas_volume_need[index_curr_gas] += gas_needs_volume_due;
				}

				// current gas is 1-5 ? (i.e. not 0 aka gas 6)
				if( sim_gas_current_num )
				{
					// set time: doing a deco stop ->    1 minute, encoded by tissue_increment = 1
					//                no deco stop -> 1/10 minute, encoded by tissue_increment = 0
					gas_needs_time = tissue_increment;

					// calculate required gas volume for the stop, ascent or travel
					calc_required_volume();

					// add the demand to the overall demand on the current gas
					gas_volume_need[index_curr_gas] += gas_needs_volume_due;
				}

#ifdef _gas_contingency
				// in gas contingency mode?
				if( main_status & GAS_CONTINGENCY )
				{
					overlay unsigned char all_peer_tanks_used_up = 1;


					// when doing a gas change and the there is an overdraw on the last gas,
					// then transfer the overdraw to the current gas if the current gas has
					// an equal or deeper change depth than the overdrawn gas
					if( doing_gas_change                                                                 )
					if( gas_volume_need[index_last_gas]        >= gas_volume_avail[index_last_gas]       )
					if( char_I_deco_gas_change[index_last_gas] <= char_I_deco_gas_change[index_curr_gas] )
					{
						overlay float overdraw;

						// calculate overdraw
						overdraw = gas_volume_need[index_last_gas] - gas_volume_avail[index_last_gas];

						// transfer overdraw
						gas_volume_need[index_last_gas] -= overdraw;
						gas_volume_need[index_curr_gas] += overdraw;

						// tag last gas as fully used up
						deco_gas_type[index_last_gas] |= GAS_FULLY_USED_UP;
					}

					// if there are peer tanks with the current gas (i.e. other tanks that have the same
					// change depth), check if there is at least one tank that is not yet fully used up
					if( peer_tank[index_curr_gas] )
					{
						// scan all tanks
						for( i = 0; i < NUM_GAS; i++ )
						{
							// check if
							// - tank is a peer tank
							// - tank is currently neither staged nor lost
							// - tank is not fully used up yet
							if(  (peer_tank[index_curr_gas] &    (1 << i)      ) )
							if( !(deco_gas_type[i]          & GAS_AVAIL_MASK   ) )
							if( !(deco_gas_type[i]          & GAS_FULLY_USED_UP) )
							{
								// found a peer tank that is available and not fully used up yet
								all_peer_tanks_used_up = 0;
							}
						}
					}

					// select which threshold is sensible to check for
					if     ( deco_gas_type[index_curr_gas] & GAS_FULLY_USED_UP  )
					{
						// already found as fully used up, nothing to do any more
					}
					else if( deco_gas_type[index_curr_gas] & GAS_NEARLY_USED_UP )
					{
						// check for fully used up threshold
						if( gas_volume_need[index_curr_gas] >= gas_volume_avail[index_curr_gas] )
						{
							// tag the gas as fully used up
							deco_gas_type[index_curr_gas] |= GAS_FULLY_USED_UP;

							// set warning if all peer tanks are fully used up, too
							if( all_peer_tanks_used_up ) deco_gas_type[index_curr_gas] |= GAS_NEED_WARNING;
						}
					}
					else
					{
						// check for nearly used up threshold
						if( gas_volume_need[index_curr_gas] >= gas_volume_atten[index_curr_gas] )
						{
							// tag the gas as nearly used up
							deco_gas_type[index_curr_gas] |= GAS_NEARLY_USED_UP;

							// set attention if all peer tanks are already fully used up
							if( all_peer_tanks_used_up ) deco_gas_type[index_curr_gas] |= GAS_NEED_ATTENTION;
						}
					}
				}
#endif // _gas_contingency

			} // gas needs

			// update the total stops time
			if( doing_deco_stop )
			{
				// total stops time is counted in full minutes, add 1 minute
				TST_time += 1;
			}

			// update the total ascent / cave return time
			if( tissue_increment )
			{
				// total time to surface is counted in 1/10 minutes, add 1 minute
				TTS_time += 10 * tissue_increment;
			}
			else
			{
				// total time to surface is counted in 1/10 minutes, add 1/10 minute
				TTS_time += 1;
			}

		}

		// calculate absolute pressure at the current depth
		sim_pres_respiration = (float)char_depth_sim * METER_TO_BAR + pres_surface;

		// compute current ppO2, ppN2 and ppHe
		calc_alveolar_pressures();

		// update the tissues
		calc_tissues();

		// update the CNS
		calc_CNS();

		// finish stops calculation if the surface is reached or
		// if the deco table is full / calculations took too long
		if( (char_depth_sim == 0) || (deco_warnings & DECO_WARNING_INCOMPLETE) )
			next_planning_phase = PHASE_80_RESULTS;

		break;


		///
		//--- Results - Initialization ------------------------------------------------------------
		//
		case PHASE_80_RESULTS:

		// convert the CNS value to integer
		convert_sim_CNS_for_display();

		// limit total time to surface to display max. and rescale to full minutes
		if( TTS_time < 9995 ) TTS_time = (TTS_time + 5) / 10;
		else                  TTS_time = 999 | INT_FLAG_INVALID;

		// limit total stops time to display max.
		if( TST_time >  999 ) TST_time = 999 | INT_FLAG_INVALID;

		// normal or alternative plan?
		if( deco_status & CALC_NORM )
		{
			// normal plan

			// export the integer CNS value
			int_O_CNS_norm  = int_sim_CNS_fraction;

			// publish the stops table to the display functions
			publish_deco_table();

			// When in deco and the ceiling depth is > 0 but the deco calculation
			// reveals no distinct deco stop yet because the deco obligation will
			// vanish during the ascent, create an artificial stop to signal that
			// expedite surfacing ("popping up") is not allowed any more.
			if( char_O_deco_depth[0] == 0 )		// simulated ascent reveals no required stops
			if( int_O_ceiling         > 0 )		// real tissues have a ceiling
			{
				// set a pro forma stop at the configured last stop depth
				char_O_deco_depth[0] = char_I_last_stop_depth;

				// set a stop time of 0 minutes, this will be displayed as "..'"
				char_O_deco_time[0]  = 0;
			}

			// within NDL?
			if ( NDL_time )
			{
				// YES - output the NDL and TTS time
				int_O_NDL_norm = NDL_time;
				int_O_TTS_norm = TTS_time;

				// clear the stops time
				int_O_TST_norm = 0;
			}
			else
			{
				// NO - clear the normal NDL time
				int_O_NDL_norm = 0;

				// export the TTS and total stops time
				int_O_TTS_norm = TTS_time;
				int_O_TST_norm = TST_time;
			}
		}
		else
		{
			// alternative plan

			// export the integer CNS value
			int_O_CNS_alt   = int_sim_CNS_fraction;

			// within NDL?
			if ( NDL_time )
			{
				// YES - output the NDL time
				int_O_NDL_alt = NDL_time;
				int_O_TTS_alt = TTS_time;

				// clear the alternative TTS and stops time
				int_O_TST_alt = 0 + INT_FLAG_ZERO;
			}
			else
			{
				// NO - clear the alternative NDL time
				int_O_NDL_alt = 0;

				// export the TTS and total stops time
				int_O_TTS_alt = TTS_time;
				int_O_TST_alt = TST_time;
			}
		}

		// export deco infos and warnings
		char_O_deco_info     = deco_info;
		char_O_deco_warnings = deco_warnings;

		// The next calculation phase will
		// - convert the gas needs from volume to pressure if gas needs calculation is configured
		// - else finish the calculation cycle
		if   ( main_status & CALC_VOLUME ) next_planning_phase = PHASE_81_GAS_NEEDS_PRESSURES;
		else                               next_planning_phase = PHASE_90_FINISH;

		break;


		//
		//--- Results - convert Gas Needs Volumes to Pressures ------------------------------------
		//
		case PHASE_81_GAS_NEEDS_PRESSURES:

		// step through all gases
		for (i = 0; i < NUM_GAS; i++)
		{
			// convert required volume of the gas into the respective pressure and set the flags
			convert_volume_to_pressure(i);
		}

#ifdef _cave_mode
		// tag gas needs as calculated in cave mode or in open water mode
		if( main_status & CAVE_MODE ) deco_info |=  GAS_NEEDS_CAVE;
		else                          deco_info &= ~GAS_NEEDS_CAVE;

		// export updated deco info
		char_O_deco_info = deco_info;
#endif

		// advance to next calculation phase
		next_planning_phase = PHASE_90_FINISH;

		break;

		//
		//--- finish Calculation Cycle ------------------------------------------------------------
		//
		case PHASE_90_FINISH:

		// Check if deco obligation is steady state or decreasing.
		// Update the result only:
		// - if an alternative plan is enabled, and
		// - if a valid alternative plan TTS exists, and
		// - if it is not a bailout plan
		if(  (deco_status   & CALC_ALT        ) )
		if( !(int_O_TTS_alt & INT_FLAG_INVALID) )
		if( !(deco_status   & BAILOUT_MODE    ) )
		{
			if     ( int_O_TTS_alt < int_O_TTS_norm ) deco_info |=  DECO_ZONE;
			else if( int_O_TTS_alt > int_O_TTS_norm ) deco_info &= ~DECO_ZONE;

			// export updated deco info
			char_O_deco_info = deco_info;
		}

		// restore command flag to indicate that the deco calculation cycle has finished
		char_O_deco_status  = deco_status;

		// signal end of deco calculation
		next_planning_phase = PHASE_00_DONE;

		break;

		} // switch

		// read timer 5, result will be stored in tmr5_value (in 1/32 ms) and tmr5_overflow
		read_tmr5();

	} // sequence calculation phases while not timed out and calculation cycle is not finished
	while( (tmr5_overflow == 0) && ( next_planning_phase != PHASE_00_DONE ) );

	// report where we are in terms of depth reached, used in deco calculator to show deco calculation progress
	char_O_depth_sim = char_depth_sim;


#ifdef _profiling

	//---- Performance Measurement -------------------------------------------

	// convert timer 5 readout into ms
	profiling_runtime = tmr5_value / 32;

	// actual runtime longer than target runtime?
	if( tmr5_overflow )
	{
		// YES - report excess
		int_O_profiling_overrun = profiling_runtime;

		//     - excess > max we had so far?
		if( int_O_profiling_overrun > int_O_profiling_overrun_max )
		{
			// YES - update max
			int_O_profiling_overrun_max    = int_O_profiling_overrun;

			//     - store the causing phase
			char_O_profiling_overrun_phase = profiling_phase;
		}
	}
	else
	{
		// NO - calculate unused budget and flag it to be under-run time
		int_O_profiling_overrun = (2048 - profiling_runtime) | 0x8000;
	}

	// increment number of runs in current cycle
	profiling_runs += 1;

	// planning cycle completed?
	if( next_planning_phase == PHASE_00_DONE )
	{
		// YES - export number of runs it took
		if( deco_status & COMPLETED_NORM ) char_O_profiling_runs_norm = profiling_runs;
		else                               char_O_profiling_runs_alt  = profiling_runs;
	}

#endif

}


//////////////////////////////////////////////////////////////////////////////
// calc_hauptroutine_data_input
//
// Set all C-code dive parameters from their ASM-code values.
//
void calc_hauptroutine_data_input(void)
{
	overlay float IG_ratio;

	// safeguard and convert the surface pressure (mbar -> bar) (*)
	if( int_I_pres_surface     < 500 ) pres_surface          = 0.500;
	else                               pres_surface          = 0.001 * int_I_pres_surface;

	// safeguard and convert the current real pressure
	if( int_I_pres_respiration < 500 ) real_pres_respiration = 0.500;
	else                               real_pres_respiration = 0.001 * int_I_pres_respiration;

	// safeguard further parameters to protect the tissue-flag and the stop table
	if( char_I_sim_advance_time > 127 ) char_I_sim_advance_time = 127;
	if( char_I_extra_time       > 127 ) char_I_extra_time       = 127;
	if( char_I_gas_change_time  >  99 ) char_I_gas_change_time  =  99;


	// compute the depth in meters where we are now
	float_depth_real = (real_pres_respiration - pres_surface) * BAR_TO_METER;

	// convert to integer and round up to next full meter
	char_depth_real = (unsigned char)(float_depth_real + 0.99);


	// calculate partial pressure of N2 in respired air at surface pressure
	calc_N2_equilibrium();

	// get, safeguard and convert the saturation and desaturation factors
	get_saturation_factors();

#ifdef _ccr_pscr
	// compute a factor that will be used later on for pSCR ppO2 drop calculation (*)
	float_pSCR_factor = 0.01 * char_I_PSCR_drop * char_I_PSCR_lungratio;
#endif

#ifdef _helium
	// get the currently breathed gas ratios
	real_O2_ratio = 0.01 * char_I_O2_ratio;
	real_He_ratio = 0.01 * char_I_He_ratio;

	// calculate the inert gas ratio (local helper variable)
	IG_ratio = 1.00 - real_O2_ratio;

	// calculate the N2 ratio
	real_N2_ratio  = IG_ratio - real_He_ratio;
#else
	// get the currently breathed O2 ratio
	real_O2_ratio = 0.01 * char_I_O2_ratio;

	// set the He ratio to zero
	real_He_ratio = 0.0;

	// calculate the N2 / inert gas ratio
	real_N2_ratio = IG_ratio = 1.00 - real_O2_ratio;
#endif	// _helium

#ifdef _ccr_pscr
	// calculate ppO2 drop in pSCR loop for real tissues
	real_pSCR_drop = IG_ratio * float_pSCR_factor;
#endif

}


//////////////////////////////////////////////////////////////////////////////
// calc_tissues
//
// INPUT:    ppN2                       partial pressure of inspired N2
//           ppHe                       partial pressure of inspired He
//           tissue_increment           tissue selector (real or simulated) and interval time
//
// MODIFIED: real_pres_tissue_N2[]      tissue N2 pressures (in real tissues context)
//           real_pres_tissue_He[]      tissue He pressures (in real tissues context)
//           sim_pres_tissue_N2[]       tissue N2 pressures (in simulated tissues context)
//           sim_pres_tissue_He[]       tissue He pressures (in simulated tissues context)
//
// OUTPUT:   char_O_tissue_pres_N2[]    tissue N2 pressures scaled for display purpose (in real tissues context)
//           char_O_tissue_pres_He[]    tissue He pressures scaled for display purpose (in real tissues context)
//           char_O_tissue_pressure[]   combined tissue pressures scaled for display purpose (in real tissue context)
//
static void calc_tissues()
{
	overlay unsigned char	period;
	overlay float			last_press_tissue;
	overlay float			delta_press_N2;

#ifdef _helium
	overlay float			delta_press_He;
#endif

	assert( 0.00 <= ppN2 && ppN2 < 11.2 );  // 80% N2 at 130m
	assert( 0.00 <= ppHe && ppHe < 12.6 );  // 90% He at 130m


	for( ci=0; ci < NUM_COMP; ci++ )		// iterate through all compartments
	{
		i = tissue_increment & TIME_MASK;	// i > 0: do a number of i full minutes
											// I = 0: do 2 (real tissues) or 6 (simulated tissues) seconds

		if( i == 0 )						// check if we shall do one 2 or 6 seconds interval
		{
			read_Buhlmann_times(0);			// YES - program coefficients for a 2 or 6 seconds period
			period = 1;						//     - set period length (in cycles)
			i      = 1;						//     - and one cycle to do
		}
		else if( i > 9 )					// check if we can start with 10 minutes periods
		{
			read_Buhlmann_times(2);			// YES - program coefficients for 10 minutes periods
			period = 10;					//       set period length (in cycles) to ten
		}
		else								// last but not lease, do 1 to 9 minutes
		{
			read_Buhlmann_times(1);			// NO  - program coefficients for 1 minute periods
			period = 1;						//     - set period length (in cycles) to one
		}

		do
		{
			if (tissue_increment & TISSUE_SELECTOR)
			{
				//---- real N2 --------------------------------------

				// get the real tissue pressure
				last_press_tissue = real_pres_tissue_N2[ci];

				// calculate the pressure change
				temp_tissue = (ppN2 - last_press_tissue) * var_N2_e;

				// apply the saturation / desaturation factor on temp_tissue
				apply_saturation_factors();

				// store the pressure change for IBCD check and tissue graphics
				delta_press_N2 = temp_tissue;

				// update the delta accumulator
				real_pres_delta_N2[ci] += temp_tissue;

				// update the real tissue pressure
				real_pres_tissue_N2[ci] += real_pres_delta_N2[ci];

				// reduce the delta accumulator
				real_pres_delta_N2[ci]  -= real_pres_tissue_N2[ci] - last_press_tissue;

#ifdef _helium
				//---- real He --------------------------------------

				// get the real tissue pressure
				last_press_tissue = real_pres_tissue_He[ci];

				// calculate the pressure change
				temp_tissue = (ppHe - last_press_tissue) * var_He_e;

				// apply the saturation / desaturation factor on temp_tissue
				apply_saturation_factors();

				// store the pressure change for IBCD check and tissue graphics
				delta_press_He = temp_tissue;

				// update the delta accumulator
				real_pres_delta_He[ci] += temp_tissue;

				// update the real tissue pressure
				real_pres_tissue_He[ci] += real_pres_delta_He[ci];

				// reduce the delta accumulator
				real_pres_delta_He[ci]  -= real_pres_tissue_He[ci] - last_press_tissue;
#endif
			}
			else
			{
				//---- simulated N2 ---------------------------------

				// get the simulated tissue pressure
				last_press_tissue = sim_pres_tissue_N2[ci];

				// calculate the pressure change
				temp_tissue = (ppN2 - last_press_tissue) * var_N2_e;

				// apply the saturation / desaturation factor on temp_tissue
				apply_saturation_factors();

				// update the delta accumulator
				sim_pres_delta_N2[ci] += temp_tissue;

				// update the simulated tissue pressure
				sim_pres_tissue_N2[ci] += sim_pres_delta_N2[ci];

				// reduce the delta accumulator
				sim_pres_delta_N2[ci]  -= sim_pres_tissue_N2[ci] - last_press_tissue;

#ifdef _helium
				//---- simulated He ---------------------------------

				// get the simulated tissue pressure
				last_press_tissue = sim_pres_tissue_He[ci];

				// calculate the pressure change
				temp_tissue = (ppHe - last_press_tissue) * var_He_e;

				// apply the saturation / desaturation factor on temp_tissue
				apply_saturation_factors();

				// update the delta accumulator
				sim_pres_delta_He[ci] += temp_tissue;

				// update the simulated tissue pressure
				sim_pres_tissue_He[ci] += sim_pres_delta_He[ci];

				// reduce the delta accumulator
				sim_pres_delta_He[ci]  -= sim_pres_tissue_He[ci] - last_press_tissue;
#endif
			}

			//---- decrement loop counter and adjust step size ---------------

			// decrement loop counter
			i -= period;

			// check if we need to switch from 10 minute periods to 1 minute periods
			if( (i > 0) && (period = 10) && (i < 10) )
			{
				read_Buhlmann_times(1);		// program coefficients for 1 minute periods
				period = 1;					// set period length (in cycles) to one
			}
		}
		while( i );


		// have the computations been done for the "real" tissues?
		if( tissue_increment & TISSUE_SELECTOR )
		{

#ifdef _helium
			// net tissue balance
			temp_tissue = delta_press_N2 + delta_press_He;

			// check tissue on-/off-gassing and IBCD with applying a threshold of +/-HYST
			//
			if      ( temp_tissue < -HYST )				// check if the tissue is off-gassing
			{
				// tag tissue as not experiencing mentionable IBCD
				IBCD_tissue_vector &= ~(1 << ci);
			}
			else if ( temp_tissue > +HYST )				// check if the tissue in on-gassing
			{
				// check for counter diffusion
				if(    ((delta_press_N2 > 0.0) && (delta_press_He < 0.0))
				    || ((delta_press_N2 < 0.0) && (delta_press_He > 0.0)) )
				{
					// tag tissue as experiencing mentionable IBCD
					IBCD_tissue_vector |= (1 << ci);
				}
			}
#endif

			// For N2 tissue pressure display purpose:

			// basically keep the on-gassing / off-gassing flag from last invocation, but flip
			// it in case the rate exceeds a set hysteresis (actual value: see #define of HYST)
			char_O_tissue_pres_N2[ci]  &= 128;
			if      ( delta_press_N2 > +HYST ) char_O_tissue_pres_N2[ci]  = 128; // set flag for tissue pressure is increasing
			else if ( delta_press_N2 < -HYST ) char_O_tissue_pres_N2[ci]  =   0; // clear flag (-> tissue pressure is decreasing)

			// scale N2 tissue pressure such that the surface steady-state tissue loading
			// of [0.7902 * (1013 hPa - ppWater)] bar will give a 8, which aligns with
			// the 2nd scale line.
			delta_press_N2 = (8 / (0.7902 * (1.013 - ppWater))) * real_pres_tissue_N2[ci];

			// limit to 127 to protect the uppermost bit which holds the sat/desat flag
			if (delta_press_N2 > 127) delta_press_N2 = 127;

			// convert to integer and combine with sat/desat flag
			char_O_tissue_pres_N2[ci] += (unsigned char)delta_press_N2;

#ifdef _helium

			// For He tissue pressure display purpose:

			// basically keep the on-gassing / off-gassing flag from last invocation, but flip
			// it in case the rate exceeds a set hysteresis (actual value: see #define of HYST)
			char_O_tissue_pres_He[ci]  &= 128;
			if      ( delta_press_He > +HYST ) char_O_tissue_pres_He[ci]  = 128; // set flag for tissue pressure is increasing
			else if ( delta_press_He < -HYST ) char_O_tissue_pres_He[ci]  =   0; // clear flag (-> tissue pressure is decreasing)

			// scale He tissue pressure alike it is done for N2.
			// With no He in a tissue, the result will be 0.
			delta_press_He = (8 / (0.7902 * (1.013 - ppWater))) * real_pres_tissue_He[ci];

			// limit to 127 to protect the uppermost bit which holds the sat/desat flag
			if (delta_press_He > 127) delta_press_He = 127;

			// convert to integer and combine with sat/desat flag
			char_O_tissue_pres_He[ci] += (unsigned char)delta_press_He;

			// For combined tissue pressure display purpose:

			// basically keep the on-gassing / off-gassing flag from last invocation, but flip
			// it in case the rate exceeds a set hysteresis (actual value: see #define of HYST)
			char_O_tissue_pressure[ci] &= 128;
			if      ( temp_tissue    > +HYST ) char_O_tissue_pressure[ci] = 128; // set flag for tissue pressure is increasing
			else if ( temp_tissue    < -HYST ) char_O_tissue_pressure[ci] =   0; // clear flag (-> tissue pressure is decreasing)

			// add the two scaled pressures.
			temp_tissue = delta_press_N2 + delta_press_He;

			// limit to 127 to protect the uppermost bit which holds the sat/desat flag
			if (temp_tissue > 127) temp_tissue = 127;

			// convert to integer and combine with sat/desat flag
			char_O_tissue_pressure[ci] += (unsigned char)temp_tissue;

#else

			// He tissue pressure is zero
			char_O_tissue_pres_He[ci] = 0;

			// combined tissue pressure equals N2 tissue pressure
			char_O_tissue_pressure[ci] = char_O_tissue_pres_N2[ci];

#endif

		} //if

	} // for
}


//////////////////////////////////////////////////////////////////////////////
// calc_limit
//
// Input:    GF_parameter             gradient factor to be used, negative values activate surface mode
//           tissue_increment         selector for context: real or simulated tissues
//           sim_pres_tissue_N2/_He   tissue pressures (used in simulated tissues context)
//           real_pres_tissue_N2/_He  tissue pressures (used in real      tissues context)
//
// Output:   lead_supersat            highest supersaturation found among all tissues, 1.0 = 100%
//           lead_tissue              number of the leading tissue (0-15)
//           ceiling                  ceiling in bar relative pressure
//
// Modified: deco_warnings            for IBCD, micro bubbles and outside warning (only in real tissues context)
//
static void calc_limit(PARAMETER float GF_parameter)
{
	overlay float         pres_ambient_min_overall = 0.0;
	overlay unsigned char surface_mode             = 0;		// 0: off, 1: on


	// check mode
	if( GF_parameter < 0 )
	{
		// activate surface mode
		surface_mode = 1;

		// normalize parameter
		GF_parameter = -GF_parameter;
	}

	// set leading tissue number to tissue 1 (it has the index 0)
	lead_tissue   = 0;

	// initialize leading tissue supersaturation value to null
	lead_supersat = 0.0;

	// next code section is relevant only when invoked on the real tissues
	if( tissue_increment & TISSUE_SELECTOR )
	{
		// clear IBCD, micro-bubbles and outside warning flags (locked warnings will be preserved)
		deco_warnings &= ~( DECO_WARNING_IBCD + DECO_WARNING_MBUBBLES + DECO_WARNING_OUTSIDE + DECO_ATTENTION_OUTSIDE );
	}

	// loop over all tissues
	for( ci = 0; ci < NUM_COMP; ci++ )
	{
		overlay float pres_ambient_min_tissue;


		// get the coefficients for tissue ci
		read_Buhlmann_coefficients();

#ifdef _helium

		// get the tissue pressures
		// adopt_Buhlmann_coefficients needs calc_pres_tissue_N2/He when compiled for helium
		if( tissue_increment & TISSUE_SELECTOR )
		{
			// context is real tissues
			calc_pres_tissue_N2 = real_pres_tissue_N2[ci];
			calc_pres_tissue_He = real_pres_tissue_He[ci];
		}
		else
		{
			// context is simulated tissues
			calc_pres_tissue_N2 = sim_pres_tissue_N2[ci];
			calc_pres_tissue_He = sim_pres_tissue_He[ci];
		}

		// overall tissue pressure
		calc_pres_tissue = calc_pres_tissue_N2 + calc_pres_tissue_He;

#else

		// get the tissue pressure
		calc_pres_tissue = ( tissue_increment & TISSUE_SELECTOR ) ? real_pres_tissue_N2[ci] : sim_pres_tissue_N2[ci];

#endif

		// adopt a and b coefficients to current N2/He ratio inside the tissue
		adopt_Buhlmann_coefficients();

		// next calculations are only relevant when invoked on the real tissues
		if( tissue_increment & TISSUE_SELECTOR )
		{
			overlay float pres_tissue_max;
			overlay float supersat;
			overlay float baseline_threshold;


			// check if tissue is in supersaturation
			if( calc_pres_tissue > real_pres_respiration )
			{
				// calculate maximum allowed tissue pressure at current ambient pressure
				pres_tissue_max = real_pres_respiration / var_b + var_a;

				// calculate current supersaturation value (1.0 = 100%) of this tissue according to straight Buhlmann
				supersat =    ( calc_pres_tissue - real_pres_respiration )
				            / ( pres_tissue_max  - real_pres_respiration );

				// calculate supersaturation value for display purpose: 1.35 = 135% = 86 pixel
				if( supersat <= 1.35 ) char_O_tissue_saturation[ci] = (unsigned char)(supersat * 64);
				else                   char_O_tissue_saturation[ci] = 86;

				// memorize highest supersaturation found
				if( supersat > lead_supersat ) lead_supersat = supersat;

				// tissue-dependent baseline threshold for micro bubbles and outside warnings
				baseline_threshold = 0.02 * ci + 1.0;

				// micro bubbles warning: supersaturation > baseline threshold
				if( supersat > baseline_threshold )
					deco_warnings |= (DECO_WARNING_MBUBBLES + DECO_WARNING_MBUBBLES_lock);

				// outside warning: supersaturation > baseline threshold + additional 5% margin
				if( supersat > (baseline_threshold + 0.05) )
					deco_warnings |= (DECO_WARNING_OUTSIDE  + DECO_WARNING_OUTSIDE_lock );
			}
			else
			{
				// supersaturation is defined as zero while tissue pressure <= ambient pressure
				supersat                     = 0.0;
				char_O_tissue_saturation[ci] = 0;
			}

			// next only when in surface mode
			if( surface_mode )
			{
				// tag tissue whether it is beyond the M-line limit or not
				if( supersat > 1.0 )
				{
					char_O_tissue_pres_N2[ci]  |=  128;
#ifdef _helium
					char_O_tissue_pres_He[ci]  |=  128;
#endif
					char_O_tissue_pressure[ci] |=  128;
				}
				else
				{
					char_O_tissue_pres_N2[ci]  &= ~128;
#ifdef _helium
					char_O_tissue_pres_He[ci]  &= ~128;
#endif
					char_O_tissue_pressure[ci] &= ~128;
				}
			}
		} // real tissues

		// calculate the minimum ambient pressure that the tissue can withstand
		if( char_I_model == 0 )
		{
			// straight Buhlmann
			pres_ambient_min_tissue = (calc_pres_tissue - var_a) * var_b;
		}
		else
		{
			// Buhlmann with Eric Baker's varying gradient factor correction
			// note: this equation [1] is the inverse of equation [2]
			pres_ambient_min_tissue =   ( calc_pres_tissue   - (var_a        * GF_parameter) )
			                          / ( 1.0 - GF_parameter + (GF_parameter / var_b       ) );
		}

		// check if this tissue requires a higher ambient pressure than was found to be needed up to now
		if( pres_ambient_min_tissue > pres_ambient_min_overall )
		{
			pres_ambient_min_overall = pres_ambient_min_tissue;
			lead_tissue               = ci;
		}
	} // for

	// compute ceiling in bar relative pressure
	ceiling = pres_ambient_min_overall - pres_surface;

	// limit ceiling to positive values
	if( ceiling < 0.0 ) ceiling = 0.0;

#ifdef _helium
	// IBCD is checked for real tissues only
	if( tissue_increment & TISSUE_SELECTOR )
	{
		// check if the leading tissue is in IBCD condition
		if(    (IBCD_tissue_vector & (1 << lead_tissue))
		    && ((real_pres_tissue_N2[lead_tissue] + real_pres_tissue_He[lead_tissue]) > real_pres_respiration) )
		{
			// leading tissue is in IBCD condition and in super-saturation, so issue a warning.
			deco_warnings |= (DECO_WARNING_IBCD + DECO_WARNING_IBCD_lock);
		}
	}
#endif

}


//////////////////////////////////////////////////////////////////////////////
// calc_NDL_time_tissue
//
// calculation of the remaining no decompression limit (NDL) time for a tissue
//
// NOTE: Erik Baker's closed formula works for Nitrox. Trimix adds a second
//       exponential term to the M-value equation, making it impossible to
//       invert. So we have to solve the problem with a search approach.
//
// Input:    NDL_tissue       tissue for which to calculate remaining NDL time
//           GF_high          gradient factor used when GF factors are enabled
//           ppN2, ppHe       partial pressures of N2 and He breathed
//
// Modified: NDL_time         shortest NDL time found so far
//           NDL_tissue_lead  leading tissue, i.e. tissue with the shortest NDL
//
static void calc_NDL_time_tissue(void)
{
	overlay unsigned char NDL_time_tissue	=  0;	// NDL time of this tissue, starting with  0 minutes
	overlay unsigned char step_size			= 10;	// step size in searching,  starting with 10 minutes
	overlay float         pres_limit;				// max. tissue pressure allowed

#ifdef _helium
	overlay float         last_pres_tissue_N2;		// last tissue pressure for N2
	overlay float         last_pres_tissue_He;		// last tissue pressure for He
#else
	overlay float         last_pres_tissue;			// last tissue pressure
#endif


	// set the compartment index ci for reading the Buhlmann increments and coefficients
	ci = NDL_tissue;

	// read the tissue increments for a step size of 10 minutes
	read_Buhlmann_times(2);

	// read Buhlmann a and b coefficients for tissue ci
	read_Buhlmann_coefficients();

#ifdef _helium

	// get the current simulated tissue pressures
	calc_pres_tissue_N2 = last_pres_tissue_N2 = sim_pres_tissue_N2[ci];
	calc_pres_tissue_He = last_pres_tissue_He = sim_pres_tissue_He[ci];

#else

	// get the current simulated tissue pressure
	calc_pres_tissue = last_pres_tissue = sim_pres_tissue_N2[ci];

	// set the a and b coefficients
	adopt_Buhlmann_coefficients();

#endif

	// simulate an increasing bottom time and check when the NDL is hit
	for(;;)
	{

#ifdef _helium

		// calculate the total tissue pressure
		calc_pres_tissue = calc_pres_tissue_N2 + calc_pres_tissue_He;

		// adopt a and b coefficients to current N2/He ratio inside the tissue
		adopt_Buhlmann_coefficients();

#endif

		// compute the maximum tissue pressure allowed to be exposed to an
		// ambient pressure equaling the surface pressure
		if( char_I_model != 0 )
		{
			// GF model enabled, this equation [2] is the inverse of equation [1]
			pres_limit = (1.0 - GF_high + GF_high / var_b) * pres_surface + GF_high * var_a;
		}
		else
		{
			// straight Buhlmann
			pres_limit = pres_surface / var_b + var_a;
		}

		// is the tissue pressure higher than the maximum tissue pressure allowed?
		if( calc_pres_tissue > pres_limit)
		{
			// YES - tissue is outside NDL

			// was the tissue outside NDL right from the start?
			if( NDL_time_tissue == 0 )
			{
				// YES - search can be aborted

				// at least one tissue is outside NDL, so overall NDL time is zero
				NDL_time = 0;

				// store the number of this tissue as being the leading one
				NDL_tissue_lead = NDL_tissue;

				// done
				break;
			}

			// when code execution passes here, the tissue has become
			// being outside NDL after doing one or more search steps

			// still searching with a step size of 10 minutes?
			if( step_size == 10 )
			{
				// YES - retry with smaller step size

				// go back to last NDL time
				NDL_time_tissue -= 10;

#ifdef _helium

				// go back to last pressures
				calc_pres_tissue_N2 = last_pres_tissue_N2;
				calc_pres_tissue_He = last_pres_tissue_He;

#else

				// go back to last pressure
				calc_pres_tissue = last_pres_tissue;

#endif

				// reduce step size to 1 minute
				step_size = 1;

				// read the tissue increments for a step size of 1 minute
				read_Buhlmann_times(1);

				// redo search from last pressure & time within NDL with smaller step size
				continue;
			}
			else
			{
				// NO - already tried with a step size of 1 minute

				// go back to last NDL time that was within NDL
				NDL_time_tissue -= 1;

				// is the NDL time of this tissue shorter than the overall NDL time found so far?
				if( NDL_time_tissue < NDL_time )
				{
					// YES - set this tissue's NDL time as the new overall NDL time
					NDL_time = NDL_time_tissue;

					//     - store the number of this tissue as being the leading one
					NDL_tissue_lead = NDL_tissue;
				}

				// done
				break;
			}
		}
		else
		{
			// NO - tissue is still within NDL

			// The search can be terminated when the NDL time of this tissue
			// exceeds the overall NDL time, thus when a shorter NDL time has
			// already been found with another tissue.
			if( NDL_time_tissue >= NDL_time ) break;

#ifdef _helium

			// back-up current tissue pressures
			last_pres_tissue_N2 = calc_pres_tissue_N2;
			last_pres_tissue_He = calc_pres_tissue_He;

#else

			// back-up current tissue pressure
			last_pres_tissue    = calc_pres_tissue;

#endif

			// step forward NDL time of current tissue
			NDL_time_tissue += step_size;

#ifdef _helium

			// step forward tissue pressure - N2
			temp_tissue          = (ppN2 - calc_pres_tissue_N2) * var_N2_e;		// pressure delta breathed - tissue
			apply_saturation_factors();											// apply safety factor
			calc_pres_tissue_N2 += temp_tissue;									// add pressure delta to tissue

			// step forward tissue pressure - He
			temp_tissue          = (ppHe - calc_pres_tissue_He) * var_He_e;		// pressure delta breathed - tissue
			apply_saturation_factors();											// apply safety factor
			calc_pres_tissue_He += temp_tissue;									// add pressure delta to tissue

#else

			// step forward tissue pressure
			temp_tissue          = (ppN2 - calc_pres_tissue   ) * var_N2_e;		// pressure delta breathed - tissue
			apply_saturation_factors();											// apply safety factor
			calc_pres_tissue    += temp_tissue;									// add pressure delta to tissue

#endif

		}
	}
}


//////////////////////////////////////////////////////////////////////////////
// clear_deco_table
//
// Modified: internal_deco_time[]    stop durations
//           internal_deco_depth[]   stop depths
//           internal_deco_gas[]     gases used at stops
//
static void clear_deco_table(void)
{
	for( i = 0; i < NUM_STOPS; ++i )
	{
		internal_deco_time [i] = 0;
		internal_deco_depth[i] = 0;
		internal_deco_gas[i]   = 0;
	}

	// reset stop table index and chained stops counter
	stop_index    = 0;
	chained_stops = 0;

	// clear stop table overflow warning
	deco_warnings &= ~DECO_WARNING_INCOMPLETE;
}


//////////////////////////////////////////////////////////////////////////////
// update_deco_table
//
// Add time to a stop at char_depth_sim
//
// It is possible to create stops with a duration of 0 minutes, e.g. to
// note a gas change "on the fly" while ascending. Therefore the criteria
// to have reached the end of the list is depth == 0.
//
// Input:   char_depth_sim         stop's depth, in meters
//          sim_gas_current_num    gas used at stop, as index 1..5 or 0 for gas 6
//          time_increment         number of minutes to add to the stop
//
// Updated: internal_deco_depth[]  depth    (in meters)  of each stop
//          internal_deco_time []  time     (in minutes) of each stop
//          internal_deco_gas  []  gas used (index 1-5)  at each stop
//
static void update_deco_table(PARAMETER unsigned char time_increment)
{
	assert( char_depth_sim > 0 );		// no stop at surface


	// is there already a stop entry matching with the current depth and gas?
	if( internal_deco_depth[stop_index] == char_depth_sim      )
	if( internal_deco_gas  [stop_index] == sim_gas_current_num )
	{
		// YES - increment stop time if possible, stop time entries are
		//       limited to 99 minutes because of display constraints
		if( internal_deco_time[stop_index] < (100 - time_increment) )
		{
			// YES - time increment fits into current stop entry,
			//       increment stop time
			internal_deco_time[stop_index] += time_increment;

			// done
			return;
		}
		else
		{
			// NO - A chained stop entry will be created further down in the
			//      code to continue the stop, but we will limit the number
			//      of chained stop table entries in order to abort an ever-
			//      running deco calculation. Too many chained entries?
			if( ++chained_stops >= STOP_CHAINING_LIMIT )
			{
				// YES - set warning that calculations took too long
				deco_warnings |= DECO_WARNING_INCOMPLETE;

				// done
				return;
			}
		}
	}

	// the current stop entry does not match the current depth and gas,
	// or hasn't enough room left for the time increment

	// is the current stop entry in use?
	if( internal_deco_depth[stop_index] > 0 )
	{
		// YES - current entry is in use, need to move on
		//       to next entry position if possible

		// have all entry positions been used up?
		if( stop_index < (NUM_STOPS - 1) )
		{
			// NO - move on to next entry position
			stop_index += 1;
		}
		else
		{
			// YES - if run in deco calculator mode, set a warning that there is an overflow in the stops table
			if( main_status & CALCULATE_BOTTOM ) deco_warnings |= DECO_WARNING_INCOMPLETE;

			// limit runtime via reached TTS (scaled in 1/10 minutes here)
			if( TTS_time > 9999 ) deco_warnings |= DECO_WARNING_INCOMPLETE;

			// done
			return;
		}
	}

	// initial use of a new (or the very first) stop entry, store all stop data
	internal_deco_time [stop_index] = time_increment;
	internal_deco_depth[stop_index] = char_depth_sim;
	internal_deco_gas  [stop_index] = sim_gas_current_num;

	// done
	return;
}


//////////////////////////////////////////////////////////////////////////////
// publish_deco_table
//
// Input:  internal_deco_depth[]      depth in internal stops table
//         internal_deco_time[]       times ...
//         internal_deco_gas[]        gases ...
//
// Output: char_O_deco_depth[]        depth in the external stops table
//         char_O_deco_time[]         times ...
//         char_O_deco_gas[]          gases ...
//         char_O_deco_time_for_log   times in reverse order
//
static void publish_deco_table(void)
{
	overlay unsigned char x = stop_index;
	overlay unsigned char y;


	// copy depth, time and gas from internal to external stops table
	for( y = 0; y < NUM_STOPS; y++ )
	{
		char_O_deco_depth[y] = internal_deco_depth[y];
		char_O_deco_time [y] = internal_deco_time [y];
		char_O_deco_gas  [y] = internal_deco_gas  [y];
	}

	// copy times of shallowest stops to logging table
	for(y = 0; y < NUM_STOPS_LOG; x-- )
	{
		// copy all stops that have a non-null stop time
		if( internal_deco_time[x] )
			char_O_deco_time_for_log[y++] = internal_deco_time[x];

		// abort if all stops are copied
		if( x == 0) break;
	}

	// fill the remainder of the logging table with null
	// if it is not completely filled already
	while( y < NUM_STOPS_LOG )
	{
		char_O_deco_time_for_log[y++] = 0;
	}
}


//////////////////////////////////////////////////////////////////////////////
// calc_desaturation_time_helper
//
// Helper function
//
// Input:  pres_actual      current tissue pressure
//         pres_target      target  tissue pressure
//         var_ht           half-time of the tissue
//         desat_factor     desaturation factor
//
// Output: int_time         time needed by tissue to reach target pressure
//
static void calc_desaturation_time_helper(void)
{
	// check if actual pressure is higher then target pressure
	if( pres_actual > pres_target )
	{
		// YES - compute remaining time

		overlay float pres_ratio;

		// compute pressure ratio to archive
		pres_ratio = pres_actual / pres_target;

		// Compute desaturation time with result rounded up to multiples of 10 minutes.
		// Main purpose is to avoid confusion, because the times do not clock down in
		// one minute steps any more but get constantly re-computed according to current
		// ambient pressure and may therefor make steps of several minutes forwards and
		// backwards as ambient pressure rises/falls and N2/He ratio is being adjusted.
		int_time = (unsigned short)( (var_ht * log(pres_ratio) / desat_factor) + 0.9 );
	}
	else
	{
		// NO  - desaturation state reached, no remaining time
		int_time = 0;
	}
}


/////////////////////////////////////////////////////////////////////////////
// calc_desaturation_time
//
// Calculates the time needed for the tissues to equilibrate with
// surface pressure and the no-fly / no-altitude time.
//
// Input:   int_I_pres_surface
//          char_I_desaturation_multiplier
//
// Output:  int_O_desaturation_time
//          int_O_nofly_time
//
void calc_desaturation_time(void)
{
	overlay float P_ambient_altitude;

	assert( 800 < int_I_pres_surface             && int_I_pres_surface             <  1100 );
	assert( 0   < char_I_desaturation_multiplier && char_I_desaturation_multiplier <=  100 );


	// safeguard and convert surface pressure
	if( int_I_pres_surface < 500) pres_surface = 0.5;
	else                          pres_surface = 0.001 * int_I_pres_surface;

	// calculate partial pressure of N2 in respired air at surface pressure
	calc_N2_equilibrium();

	// get, safeguard and convert the saturation and desaturation factors
	get_saturation_factors();

	// pre-computed term for later use: 10 [Min] * 0.6931 [=log(2)] * 1 [Desat Factor] * ...
	desat_factor = (6.931 * SURFACE_DESAT_FACTOR) * float_desaturation_multiplier;

	// initialize vars
	int_O_desaturation_time = 0;
	int_O_nofly_time        = 0;

	// get selected target altitude
	switch( char_I_altitude_wait )
	{
		case 1:  P_ambient_altitude = P_ambient_1000m;	break;
		case 2:  P_ambient_altitude = P_ambient_2000m;	break;
		case 3:  P_ambient_altitude = P_ambient_3000m;	break;
		default: P_ambient_altitude = P_ambient_fly;	break;
	}

	// loop over all compartments in order slowest to fastest
	for( ci = NUM_COMP; ci > 0; )
	{
		overlay float          pres_tissue_max;
		overlay unsigned short nofly_last = ~0;
		overlay unsigned short nofly_N2   =  0;

#ifdef _helium
		overlay signed char    search_direction;
		overlay unsigned short nofly_He   =  0;
#endif


		// decrement compartment index
		ci -= 1;

		// get the Buhlmann halftimes and coefficients
		read_Buhlmann_ht();
		read_Buhlmann_coefficients();


		//
		// Desaturation time
		//

		// calculate desaturation time for N2 in tissue,
		// desaturated state is defined as residual tissue pressure <= 1.05 x ppN2 respired

		// current tissue pressure above equilibrium pressure
		pres_actual = real_pres_tissue_N2[ci] - N2_equilibrium;

		// target pressure above equilibrium pressure
		pres_target = 0.05 * N2_equilibrium;

		// half-time of the current tissue
		var_ht = var_N2_ht;

		// calculate desaturation time
		calc_desaturation_time_helper();

		// store desaturation time if it is longer than longest found so far
		if( int_time > int_O_desaturation_time) int_O_desaturation_time = int_time;


#ifdef _helium

		// calculate desaturation time for He in the tissue,
		// desaturated state is defined as residual tissue pressure <= 0.05 x ppN2 respired

		// actual tissue pressure above equilibrium: equilibrium for He is 0 bar
		pres_actual = real_pres_tissue_He[ci];

		// target pressure above equilibrium pressure: use same target pressure as for N2
		pres_target = 0.05 * N2_equilibrium;

		// half-time of the current tissue
		var_ht      = var_He_ht;

		// calculate desaturation time
		calc_desaturation_time_helper();

		// store desaturation time if it is longer than longest found so far
		if( int_time > int_O_desaturation_time) int_O_desaturation_time = int_time;

#endif

		//
		// no-fly time
		//

		// Target pressure for the tissue is the Buhlmann limit. We use the Buhlmann
		// coefficients for N2 also for He because it is easier to calculate and the
		// N2 coefficients are more conservative than those for He, so we are on the
		// safe side, too.
		pres_tissue_max = (P_ambient_altitude/var_N2_b + var_N2_a);

		// adjust target pressure by GF-high in case the GF model is in use, but not
		// for the no-fly time as it's target pressure is hard to reach anyhow
		if( char_I_model && char_I_altitude_wait )
		    pres_tissue_max = P_ambient_altitude +
		                      0.01 * char_I_GF_High_percentage * (pres_tissue_max - P_ambient_altitude);


#ifdef _helium

		//---- Variant with Helium -------------------------------------------

		// initialize split_N2_He in case there was a hard reboot / memory clear
		if( split_N2_He[ci] == 0 ) split_N2_He[ci] = 90;

		// initialize search direction
		search_direction = 0;

		for(;;)
		{
			// Calculate no-fly time for N2 in the tissue.
			// Flying is permitted when the N2 pressure fits into the assigned fraction above equilibrium.

			// current tissue pressure above equilibrium
			pres_actual = real_pres_tissue_N2[ci] - N2_equilibrium;

			// target pressure above equilibrium pressure, weighted by N2/He split
			pres_target = (split_N2_He[ci] * 0.01) * (pres_tissue_max - N2_equilibrium);

			// half-time of the current tissue
			var_ht = var_N2_ht;

			// check if desaturation to target pressure is possible at all
			if( pres_target < 0.0 )
			{
				// NO  - set no-fly time to 288 * 10 min = 48 h
				int_O_nofly_time = 288;
				break;
			}
			else
			{
				// YES - calculate desaturation time
				calc_desaturation_time_helper();

				// store time found
				nofly_N2 = int_time;
			}

			// calculate no-fly time for He in the tissue,
			// flying is permitted when the He pressure fits into the assigned fraction

			// current tissue pressure above equilibrium: equilibrium for He is 0 bar
			pres_actual = real_pres_tissue_He[ci];

			// target pressure above equilibrium pressure, weighted by N2/He split
			pres_target = ((100 - split_N2_He[ci]) * 0.01) * (pres_tissue_max - N2_equilibrium);

			// half-time of the current tissue
			var_ht      = var_He_ht;

			// calculate desaturation time
			calc_desaturation_time_helper();

			// store time found
			nofly_He = int_time;


			// Because the sum of N2 and He tissue pressures needs to fit into the Buhlmann limit for
			// no-fly time calculation, each gas gets assigned a fraction of the available total pressure
			// limit. The optimum split between the two gases can not be computed by a single formula,
			// because this would require the inversion of a function with two exponential terms, which is
			// not possible. We do not want to do a computational complex simulation here like it is done
			// in the deco calculation code (although we tackle the same base problem here), so we just let
			// the computer try out which split will balance the no-fly times induced by the N2 and the He
			// at best.

			// first of all, skip any optimization in case the current compartment is not the leading one
			if( (nofly_N2 <= int_O_nofly_time) && (nofly_He <= int_O_nofly_time) ) break;

			// check if the N2 requires more waiting time than the He
			if( nofly_N2 >= nofly_He )
			{
				// check if the search direction has changed, which means we are beyond the
				// optimum now, or if we are at the upper stop limit of split_N2_He
				if( (search_direction < 0) || (split_N2_He[ci] == 99) )
				{
					// either the just completed iteration was more close to the optimum or the one before
					// was, so we take the best (i.e. shortest) time of both as the final no-fly time
					int_O_nofly_time = (nofly_N2 < nofly_last) ? nofly_N2 : nofly_last;

					// done
					break;
				}

				// store the no-fly time found in this iteration
				nofly_last = nofly_N2;

				// increase the N2 fraction of the split
				split_N2_He[ci]  +=  1;

				// set search direction towards more N2
				search_direction  = +1;
			}
			else
			{
				// check if the search direction has changed, which means we are beyond the
				// optimum now, or if we are at the lower stop limit of split_N2_He
				if( (search_direction > 0) || (split_N2_He[ci] == 1) )
				{
					// either the just completed iteration was more close to the optimum or the one before
					// was, so we take the best (i.e. shortest) time of both as the final no-fly time
					int_O_nofly_time = (nofly_He < nofly_last) ? nofly_He : nofly_last;

					// done
					break;
				}

				// store the no-fly time found in this iteration
				nofly_last = nofly_He;

				// decrease the N2 fraction of the split
				split_N2_He[ci]  -=  1;

				// set search direction towards less N2
				search_direction  = -1;
			}

		} // for(;;)

#else

		//---- Variant without Helium ----------------------------------------

		// current tissue pressure above equilibrium
		pres_actual = real_pres_tissue_N2[ci] - N2_equilibrium;

		// target pressure above equilibrium pressure
		pres_target = pres_tissue_max - N2_equilibrium;

		// half-time of the current tissue
		var_ht = var_N2_ht;

		// check if desaturation to target pressure is possible at all
		if( pres_target < 0.0 )
		{
			// NO  - set no-fly time to 288 * 10 min = 48 h
			int_O_nofly_time = 288;
		}
		else
		{
			// YES - calculate desaturation time
			calc_desaturation_time_helper();

			//     - extend desaturation time if this tissue needs
			//       more time than already found to be needed
			if( int_time > int_O_nofly_time ) int_O_nofly_time = int_time;
		}

#endif

	} // for(compartments)


	// rescale int_O_desaturation_time and int_O_nofly_time to full minutes for display purpose
	int_O_desaturation_time *= 10;
	int_O_nofly_time		*= 10;

	// limit int_O_desaturation_time and int_O_nofly_time to 5999 = 99 hours + 59 minutes
	// because of display space constraints and rounding done above
	if( int_O_desaturation_time > 5999 ) int_O_desaturation_time = 5999;
	if( int_O_nofly_time        > 5999 ) int_O_nofly_time        = 5999;


	// Clear the micro bubbles warning when the current gradient factor is < 100%.
	// The current gradient factor is calculated by calc_interval() while not in diving mode.
	// As the locked warning will stay set, this will cause the warning be be displayed in
	// attention color instead of warning color.
	if( int_O_lead_supersat < 100 )
		deco_warnings &= ~DECO_WARNING_MBUBBLES;

	// clear some warnings when the desaturation time has become zero
	if( int_O_desaturation_time == 0 )
	    deco_warnings &= ~(   DECO_WARNING_IBCD     + DECO_WARNING_IBCD_lock
	                        + DECO_WARNING_MBUBBLES + DECO_WARNING_MBUBBLES_lock
	                        + DECO_WARNING_OUTSIDE  + DECO_WARNING_OUTSIDE_lock
	                        + DECO_ATTENTION_OUTSIDE                             );
}


//////////////////////////////////////////////////////////////////////////////
// Calculate desaturation of the real tissues for a given time interval
//
// Caution: Works on the real tissues!
//          If in doubt, use this function only inside a context surrounded with
//          push_tissues_to_vault() / pull_tissues_from_vault() !
//
// Input:    int_I_pres_surface     surface pressure in mbar
//           time_interval          time interval in minutes, must be limited to 254 at max
//
// Modified: tissue pressures       N2 and He pressures of the tissues
//           CNS_fraction_real      current real CNS value
//           ceiling                minimum allowed depth in bar relative pressure
//           lead_supersat          supersaturation of the leading tissue (float)
//           int_O_lead_supersat    supersaturation of the leading tissue (integer)
//           char_O_lead_tissue     number of the leading tissue
//
static void calc_interval(PARAMETER unsigned char time_interval)
{
	overlay unsigned char time;

	assert( 800 <  int_I_pres_surface             && int_I_pres_surface             <  1100 );
	assert( 100 <= char_I_saturation_multiplier   && char_I_saturation_multiplier   <   200 );
	assert(   0 <  char_I_desaturation_multiplier && char_I_desaturation_multiplier <=  100 );


	// safeguard and convert surface pressure
	if( int_I_pres_surface < 500) pres_surface = 0.500;
	else                          pres_surface = 0.001 * int_I_pres_surface;

	// safeguard time interval
	if( time_interval > 254 ) time_interval = 254;

	// set breathed pressure to surface pressure
	real_pres_respiration = pres_surface;

	// calculate partial pressure of N2 in respired air at surface pressure
	calc_N2_equilibrium();

	// calculate partial pressures (0.7902 is fraction of N2 in atmosphere as of Buhlmann)
	ppN2 = N2_equilibrium;
	ppHe = 0.0;

	// get, safeguard and convert the saturation and desaturation factors
	get_saturation_factors();

	// adjust desaturation factor to surface mode
	float_desaturation_multiplier *= SURFACE_DESAT_FACTOR;

	// Calculate the tissues:
	// Because calc_tissues() can calculate for 127 minutes at max,
	// the tissue updating may need to be done in two chunks.

	time = time_interval;

	// first chunk for the part exceeding 127 minutes
	if( time > 127)
	{
		// do a full 127 minutes on the real tissues
		tissue_increment = TISSUE_SELECTOR | 127;
		calc_tissues();

		// determine the remaining time
		time -= 127;
	}

	// program the remaining time (or full time if not exceeding 127 minutes) on the real tissues
	tissue_increment = TISSUE_SELECTOR | time;

	// update the N2 and He pressures in the tissues
	calc_tissues();


	// Calculate CNS:
	// To speed up things and because on most invocations of this code char_I_dive_interval
	// is a multiple of 10 minutes, we loop the loop-counter down using two speeds.

	time = time_interval;

	while( time )
	{
		if( time > 9 )
		{
			CNS_fraction_real *= 0.925874712;	// half-time = 90 min -> 10 min: (1/2)^(1/9)
			time              -= 10;			// fast speed looping
		}
		else
		{
			CNS_fraction_real *= 0.992327946;	// half-time = 90 min ->  1 min: (1/2)^(1/90)
			time              -= 1;				// slow speed looping
		}
	}

	// convert the CNS value to integer
	convert_cur_CNS_for_display();

	// calculate the supersaturation of the leading tissue, the
	// negative argument puts calc_limit() into surface mode
	// Attention: do not pass char_I_GF_High_percentage as an argument
	//            here because it is not configured outside dive mode
	calc_limit(-1.0);

	// convert the saturation value of the leading tissue to integer
	convert_sat_for_display();
}


//////////////////////////////////////////////////////////////////////////////
// calc_CNS
//
// Input:    char_ppO2          current ppO2 [in 0.1 bars]
//           tissue_increment   tissue selector and time interval
//
// Modified: CNS_fraction_real  accumulated CNS (real      tissue context)
//           CNS_fraction_sim   accumulated CNS (simulated tissue context)
//
static void calc_CNS(void)
{
	overlay float CNS_fraction_inc;			// increment of CNS load, 0.01 = 1%


	// calculate CNS increment for a 2 seconds interval
	if( char_ppO2 > 160 )
	{
		// step-wise CNS increment

		// calculate index for increment look-up (uses integer division)
		cns_i = (char_ppO2 - 161) / 5;

		// indexes > 17 use increment of index 17
		if( cns_i > 17 ) cns_i = 17;

		// read coefficient (increment)
		read_CNS_c_coefficient();

		// re-scale coefficient from storage format in [1/100000] to productive value
		CNS_fraction_inc = (float)var_cns_value / 100000.0;
	}
	else if( char_ppO2 > 50 )
	{
		// range wise CNS increment approximation

		// calculate index for approximation coefficients look-up (uses integer division)
		cns_i = (char_ppO2 - 51) / 10;

		// read coefficients
		read_CNS_ab_coefficient();

		// calculate the CNS increment
		CNS_fraction_inc = 1.0 / (var_cns_gain * char_ppO2 + var_cns_offset );
	}
	else
	{	// no increment for a ppO2 of up to 0.5 bar
		CNS_fraction_inc = 0.0;
	}

	// apply a time factor in case of:
	// - simulated tissues and interval = 0 (i.e. 6 seconds to do) -> factor  3
	// - any       tissues and interval > 0 (i.e. i minutes to do) -> factor 30 * i
	     if( tissue_increment == 0         ) CNS_fraction_inc *=  3.0;
	else if( tissue_increment &  TIME_MASK ) CNS_fraction_inc *= 30.0 * (float)(tissue_increment & TIME_MASK);


	// update the CNS accumulator
	if   ( tissue_increment & TISSUE_SELECTOR ) CNS_fraction_real += CNS_fraction_inc;	// real tissues
	else                                        CNS_fraction_sim  += CNS_fraction_inc;	// simulated tissues
}


//////////////////////////////////////////////////////////////////////////////
// calc_required_volume
//
// Calculates the gas volume required for a given depth, time and usage (SAC)
// rate. It uses a fixed surface pressure of 1.0 bar to deliver stable results
// when used through the deco calculator.
//
// Input:  gas_needs_depth       depth     in meters
//         gas_needs_time        time      in minutes (0 encodes 1/10 minute)
//         gas_needs_usage_rate  gas usage in liters per minute at surface pressure
//
// Output: gas_needs_volume_due  required gas volume in liters
//
static void calc_required_volume(void)
{
	// calculate volume for 1 minute
	gas_needs_volume_due = ((float)gas_needs_depth * METER_TO_BAR + pres_surface) * gas_needs_usage_rate;

	// multiply 1-minute-volume with time factor if time factor <> 1
	if      ( gas_needs_time == 0 ) gas_needs_volume_due *= 0.1;				// 1/10 minute
	else if ( gas_needs_time >  1 ) gas_needs_volume_due *= gas_needs_time;		// multiple minutes
}



#ifdef _rx_functions

//////////////////////////////////////////////////////////////////////////////
// calc_TR_functions
//
// Process Pressure Readings (OSTC TR only)
//
// Input:  todo
//
// Output: todo
//
static void calc_TR_functions(void)
{
	// pressure warnings for reading 1, but only if enabled and pressure value available
	if( (char_I_pressure_gas[0] > 0) && !(int_IO_pressure_value[0] & INT_FLAG_NOT_AVAIL) )
	{
		overlay unsigned short pressure_value = int_IO_pressure_value[0] & ~INT_FLAG_OUTDATED;

		if( (char_I_pressure_gas[0] < 6 ) && !(int_O_pressure_need[0] & INT_FLAG_NOT_AVAIL) )
		{
			// not a diluent and need available: warning & attention by need
			if     ( pressure_value <= int_O_pressure_need[0])
			       int_IO_pressure_value[0] |= INT_FLAG_WARNING;
			else if( pressure_value <= int_O_pressure_need[0] + int_O_pressure_need[0] / 2 )
			       int_IO_pressure_value[0] |= INT_FLAG_ATTENTION;
		}
		else
		{
			// a diluent or need not available: warning & attention by fixed thresholds
			if      ( pressure_value <= PRESSURE_LIMIT_WARNING   ) int_IO_pressure_value[0] |= INT_FLAG_WARNING;
			else if ( pressure_value <= PRESSURE_LIMIT_ATTENTION ) int_IO_pressure_value[0] |= INT_FLAG_ATTENTION;
		}
	}

	// pressure warnings for reading 2, but only if enabled and pressure value available
	if( (char_I_pressure_gas[1] > 0) && !(int_IO_pressure_value[1] & INT_FLAG_NOT_AVAIL) )
	{
		overlay unsigned short pressure_value = int_IO_pressure_value[1] & ~INT_FLAG_OUTDATED;

		if( (char_I_pressure_gas[1] < 6 ) && !(int_O_pressure_need[1] & INT_FLAG_NOT_AVAIL) )
		{
			// not a diluent and need available: warning & attention by need
			if      ( pressure_value <= int_O_pressure_need[1])
			        int_IO_pressure_value[1] |= INT_FLAG_WARNING;
			else if ( pressure_value <= int_O_pressure_need[1] + int_O_pressure_need[1] / 2 )
			        int_IO_pressure_value[1] |= INT_FLAG_ATTENTION;
		}
		else
		{
			// a diluent or need not available: warning & attention by fixed thresholds
			if      ( pressure_value <= PRESSURE_LIMIT_WARNING   ) int_IO_pressure_value[1] |= INT_FLAG_WARNING;
			else if ( pressure_value <= PRESSURE_LIMIT_ATTENTION ) int_IO_pressure_value[1] |= INT_FLAG_ATTENTION;
		}
	}

	//--- SAC Calculation ---------------------------------------------------------------------
	//
	// char_I_SAC_mode =0: disabled
	//                 =1: SAC from 1st reading
	//                 =2: SAC from 2nd reading
	//                 =3: SAC from higher one of both pressure drops (independent double mode)
	//                 =4: SAC (O2 usage) from 2nd reading without real_pres_respiration term

	// set SAC rate to not available by default
	int_O_SAC_measured   = 0 + INT_FLAG_NOT_AVAIL;

	// get a copy of the current absolute pressure
	pres_respiration_sac = real_pres_respiration;

	// set threshold for SAC rate attention
	max_sac_rate = (deco_info & DECO_MODE) ? char_I_SAC_deco : char_I_SAC_work;

	// char_I_SAC_deco / char_I_SAC_work are in l/min, max_sac_rate is in 0.1 l/min
	max_sac_rate *= 10;


	// pre-process SAC mode 3 (independent double)
	if( char_I_SAC_mode == 3 )
	{
		overlay unsigned char  reading1_gas;
		overlay unsigned char  reading2_gas;
		overlay unsigned char  reading1_tanksize;
		overlay unsigned char  reading2_tanksize;
		overlay unsigned short reading1_press;
		overlay unsigned short reading2_press;
		overlay unsigned short reading1_drop;
		overlay unsigned short reading2_drop;

		// get gas numbers (1-10) of both readings
		reading1_gas = char_I_pressure_gas[0];
		reading2_gas = char_I_pressure_gas[1];

		// default to no SAC calculation
		char_I_SAC_mode = 0;

		// clear switch advice by default
		deco_info &= ~IND_DOUBLE_SWITCH_FLAG;

		// check if both readings are configured and available
		if(  reading1_gas                                    )
		if(  reading2_gas                                    )
		if( !(int_IO_pressure_value[0] & INT_FLAG_NOT_AVAIL) )
		if( !(int_IO_pressure_value[1] & INT_FLAG_NOT_AVAIL) )
		if( !(int_I_pressure_drop[0]   & INT_FLAG_NOT_AVAIL) )
		if( !(int_I_pressure_drop[1]   & INT_FLAG_NOT_AVAIL) )
		{
			// get tank pressures, stripping flags
			reading1_press = int_IO_pressure_value[0] & 0x0FFF;			// in 0.1 bar
			reading2_press = int_IO_pressure_value[1] & 0x0FFF;			// in 0.1 bar

			// get pressure drops as integers, stripping flags and shifting right
			// to avoid an overflow when multiplying with the tank size later on
			reading1_drop = (int_I_pressure_drop[0] & 0x0FFF) >> 2;
			reading2_drop = (int_I_pressure_drop[1] & 0x0FFF) >> 2;

			// get tank sizes
			reading1_tanksize = char_I_gas_avail_size[reading1_gas-1];
			reading2_tanksize = char_I_gas_avail_size[reading2_gas-1];

			// set mode to calculate SAC on the reading with the higher absolute drop
			char_I_SAC_mode = (reading1_drop * reading1_tanksize > reading2_drop * reading2_tanksize) ? 1 : 2;

			// compute switch advice if pressure (in 0.1 bar) of tank breathed from is
			// more than char_I_max_pres_diff (in bar) below pressure of the other tank.
			if( char_I_SAC_mode == 1 )
			{
				// breathing from reading 1, switch advice if pressure on reading 1 lower than on 2
				if( (reading1_press + 10*char_I_max_pres_diff) <= reading2_press )
					deco_info |= IND_DOUBLE_SWITCH_FLAG;
			}
			else
			{
				// breathing from reading 2, switch advice if pressure on reading 2 lower than on 1
				if( (reading2_press + 10*char_I_max_pres_diff) <= reading1_press )
					deco_info |= IND_DOUBLE_SWITCH_FLAG;
			}
		}
	}


	// pre-process SAC mode 4 (O2 usage by reading 2)
	if( char_I_SAC_mode == 4 )
	{
		// O2 usage on CCR is independent from absolute pressure
		pres_respiration_sac = 1.0;

		// O2 pressure drop is measured via reading 2
		char_I_SAC_mode = 2;

		// reconfigure max SAC rate to O2 consumption attention threshold
		max_sac_rate = O2_CONSUMPTION_LIMIT_ATTENTION;
	}


	// select which pressure reading to log
	     if( char_I_SAC_mode == 1 ) int_O_tank_pressure = int_IO_pressure_value[0];
	else if( char_I_SAC_mode == 2 ) int_O_tank_pressure = int_IO_pressure_value[1];
	else                            int_O_tank_pressure = 0;

	// strip flags
	int_O_tank_pressure &= 0x0FFF;

	// scale to recording format of full bar only
	int_O_tank_pressure /= 10;


	// calculate SAC - modes 1 & 2
	if( (char_I_SAC_mode == 1) || (char_I_SAC_mode == 2) )
	{
		overlay unsigned char reading_index;
		overlay unsigned char reading_gas;
		overlay unsigned char reading_tanksize;
		overlay float         reading_drop;

		// set index: char_I_SAC_mode = 1 -> reading one, index 0
		//                            = 2 ->         two,       1
		reading_index = char_I_SAC_mode - 1;

		// get gas number (1-10)
		reading_gas = char_I_pressure_gas[reading_index];

		// check if reading is configured and available
		if(  reading_gas                                               )
		if( !(int_I_pressure_drop[reading_index] & INT_FLAG_NOT_AVAIL) )
		{
			// get tank size (in liter)
			reading_tanksize = char_I_gas_avail_size[reading_gas-1];

			// get pressure drop as float, stripping flags (in 1/5120 bar/sec)
			reading_drop = (float)(int_I_pressure_drop[reading_index] & 0x0FFF);

			// check if pressure drop is within range
			if( !(int_I_pressure_drop[reading_index] & INT_FLAG_OUT_OF_RANGE) )
			{
				// calculate SAC,   10 is factor to have result in 0.1 liter/min
				//                  60 is factor for 60 seconds per 1 minute,
				//                5120 accounts for reading_drop being in 1/5120 bar/sec
				//                10*60/5120 = 60/512 = 15/128
				float_sac = reading_drop * 15/128 * reading_tanksize / pres_respiration_sac;

				// limit result to 999 (99.9 liter/min)
				if ( float_sac >= 998.5 )
				{
					int_O_SAC_measured = 999 + INT_FLAG_ATTENTION;
				}
				else
				{
					// convert float to integer
					int_O_SAC_measured = (unsigned short)(float_sac + 0.5);

					// set attention flag if exceeding SAC threshold, but only if pressure drop is not outdated
					if( !(int_I_pressure_drop[reading_index] & INT_FLAG_OUTDATED) )
					if( int_O_SAC_measured >= max_sac_rate )
					{
						int_O_SAC_measured |= INT_FLAG_ATTENTION;
					}
				}
			}
			else
			{
				// pressure drop is out of range, so SAC will be set out of range, too
				int_O_SAC_measured = 999 + INT_FLAG_ATTENTION;
			}

			// copy outdated flag from int_I_pressure_drop to int_O_SAC_measured
			if( int_I_pressure_drop[reading_index] & INT_FLAG_OUTDATED )
			{
				int_O_SAC_measured |= INT_FLAG_OUTDATED;
			}
		}
	}
}
#endif	// _rx_functions


#ifdef _cave_mode

//////////////////////////////////////////////////////////////////////////////
// read_backtrack_data
//
// Gets the data of the next backtracking data set
//
// Modified: backtrack_index         last current position in backtracking storage
//
// Output:   backtrack_step_counter  number of 1/10 min calculation steps to do on next target depth
//           backtrack_target_depth  next target depth
//
static void read_backtrack_data(void)
{
	overlay unsigned char firstround = 1;


	// load the step counter with the default of ten 1/10 minute steps to go between two depth samples
	backtrack_step_counter = 10;

	// repeat until having read the whole data set or having reached the first storage position
	while(backtrack_index)
	{
		// backtracking data recording format:
		// ---------------------------------------------------------------------------
		// 0ddddddd -> datum is a depth recording    with d = 0..127 depth in meters
		// 10tttttt ->            delta time         with t = 0.. 59 time  in seconds
		// 110ggggg ->            gas staging status with g =      1 gas staged
		// 111nnnnn ->            waypoint marker    with n = 1.. 31 waypoint number
		//
		// gas availability vector: LSB   : gas 1 (and so on)
		// waypoint marker        : 1 - 30: user waypoints, last waypoint is turn point
		//                        :     31: spare for turn point if all 30 waypoints used up
		//                        :      0: reserved

		// read recording entry and then advance (backward direction!) the reading index
		overlay unsigned char datum = char_I_backtrack_storage[backtrack_index--];

		// is it a target depth?
		if( datum < 128 )
		{
			// YES - assign the target depth
			backtrack_target_depth = datum;

			// a depth entry closes a data set, so done with this data set
			return;
		}

		// is it a delta time entry?
		else if( datum < 128 + 64 )
		{
			// YES - When a delta time entry is contained in a data set, the time
			//       stored in the delta time entry is the time that has elapsed
			//       between storage of the depth that is part of this data set
			//       and the previous depth recording.
			//       This entry is stored whenever the delta time is shorter than
			//       the default 1 minute depth sampling interval time.

			// assign the delta time to the step counter: remove entry tag and
			// convert datum from 0..59 seconds to 0..9 steps by integer division
			backtrack_step_counter = (datum - 128) / 6;
		}

		// is it a gas staging status entry?
		else if( datum < 128 + 64 + 32 )
		{
			// YES - extract gas staging status
			overlay unsigned char gas_status = datum - (128 + 64);

			// decode and update gas staging status
			//
			// bit set    : gas is     staged (not available) during next section of backtracking,
			// bit cleared: gas is not staged (    available) during next section of backtracking.
			//
			// bit 0 corresponds to gas 1, ..., bit 4 corresponds to gas 5
			//
			for( i = 0; i < NUM_GAS; i++ )
			{
				if ( gas_status & (1 << i) ) deco_gas_type[i] |=  GAS_AVAIL_STAGED;	//     staged
				else                         deco_gas_type[i] &= ~GAS_AVAIL_STAGED;	// not staged
			}
		}

		// must be waypoint marker entry then
		else
		{
			// set step counter to zero if first entry read is a waypoint entry
			if( firstround ) backtrack_step_counter = 0;
		}

		// first round done
		firstround = 0;

	} // while

	// first storage position reached, by convention it contains
	// the final target depth which is zero meters aka the surface
	backtrack_target_depth = 0;
}

#endif	// _cave_mode



//////////////////////////////////////////////////////////////////////////////
// convert_volume_to_pressure
//
// Converts gas volumes into pressures and sets respective flags
//
// Input:  index                     index of the gas to convert (0-4)
//         gas_volume_need[]         needed gas volume in liters
//         char_I_gas_avail_pres[]   available gas volume in bar
//         char_I_gas_avail_size[]   size of the tanks in liters
//         char_I_pressure_gas[]     gas configured on reading 1/2 (TR only)
//
// Output: int_O_gas_need_vol[]      required gas amount in liters
//         int_O_gas_need_pres[]     required gas amount in bar, including flags
//         int_O_pressure_need[]     required gas amount for reading 1/2 (TR only)
//
static void convert_volume_to_pressure(PARAMETER unsigned char index)
{
	// just to make the code more readable...
	i = index;

	if( gas_volume_need[i] >= 65534.5 )
	{
		int_O_gas_need_vol[i]  = 65535;										// clip at 65535 liters
		int_O_gas_need_pres[i] =   999 | INT_FLAG_WARNING | INT_FLAG_HIGH;	// 999 bar + warning flag + >999 flag
	}
	else
	{
		// convert gas volume need from float to integer [in liter]
		int_O_gas_need_vol[i]  = (unsigned short)( gas_volume_need[i] + 0.5 );

		// compute how much pressure in the tank will be needed [in bar]
		int_O_gas_need_pres[i] = (unsigned short)( gas_volume_need[i] / char_I_gas_avail_size[i] + 0.5 );

		// limit result to 999 bar because of display constraints
		if( int_O_gas_need_pres[i] > 999 ) int_O_gas_need_pres[i] = 999 | INT_FLAG_HIGH;

		// set flags for fast evaluation by output routine
		if( int_O_gas_need_pres[i] == 0 ) int_O_gas_need_pres[i] |= INT_FLAG_ZERO;
		else
#ifdef _gas_contingency
		if( main_status & GAS_CONTINGENCY )
		{
			// take warning and attention computed en-route
			if     ( deco_gas_type[i]   &  GAS_NEED_WARNING   )
			{
				// tag the tank with a warning
				int_O_gas_need_pres[i] |= INT_FLAG_WARNING;

				// tag the peer tanks with a warning, too
				for( j = 0; j < NUM_GAS; j++ )
				{
					if( peer_tank[i] & (1 << j) ) int_O_gas_need_pres[j] |= INT_FLAG_WARNING;
				}
			}
			else if( deco_gas_type[i]   &  GAS_NEED_ATTENTION )
			{
				// tag the tank with an attention
				int_O_gas_need_pres[i] |= INT_FLAG_ATTENTION;

				// tag the peer tanks with an attention, too
				for( j = 0; j < NUM_GAS; j++ )
				{
					if( peer_tank[i] & (1 << j) ) int_O_gas_need_pres[j] |= INT_FLAG_ATTENTION;
				}
			}
		}
		else
#endif
		{
			// compute warning and attention now
			if     ( gas_volume_need[i] >= gas_volume_avail[i] ) int_O_gas_need_pres[i] |= INT_FLAG_WARNING;
			else if( gas_volume_need[i] >= gas_volume_atten[i] ) int_O_gas_need_pres[i] |= INT_FLAG_ATTENTION;
		}
	}

	// set invalid flag if there is an overflow in the stops table or calculation took too long
	if( deco_warnings & DECO_WARNING_INCOMPLETE ) int_O_gas_need_pres[i] |= INT_FLAG_INVALID;

#ifdef _rx_functions
	// only for OSTC TR model with TR functions enabled
	if( main_status & TR_FUNCTIONS )
	{
		// char_I_pressure_gas[] uses gas indexes from 1-10, loop variable i runs from 0 to 4
		j = i+1;

		// check if the current gas is configured on pressure reading 1 or 2
		if( (char_I_pressure_gas[0] == j) || (char_I_pressure_gas[1] == j) )
		{
			// get a copy of the required pressure in full bar
			overlay unsigned short int_pres_need = int_O_gas_need_pres[i];

			// strip all flags
			int_pres_need &= 1023;

			// limit to 400 bar and multiply by 10 to get required pressure in 0.1 bar
			int_pres_need = (int_pres_need > 400) ? 4000 | INT_FLAG_OUT_OF_RANGE : 10 * int_pres_need;

			// tag as not available if there is an overflow in the stops table or calculation took too long
			if( deco_warnings & DECO_WARNING_INCOMPLETE ) int_pres_need |= INT_FLAG_NOT_AVAIL;

			// copy to reading data (in both readings the same gas could be configured)
			if( char_I_pressure_gas[0] == j ) int_O_pressure_need[0] = int_pres_need;
			if( char_I_pressure_gas[1] == j ) int_O_pressure_need[1] = int_pres_need;
		}
	} // TR functions
#endif
}


//////////////////////////////////////////////////////////////////////////////
// convert the real CNS value to integer
//
// Input  CNS_fraction_real     current CNS value as float
//
// Output: int_O_CNS_current    current CNS value as integer including flags
//
static void convert_cur_CNS_for_display(void)
{
	// convert to integer
	float_value = CNS_fraction_real; convert_float_to_int(); int_O_CNS_current = int_value;

	// set warning & attention flags
	if      ( int_O_CNS_current    >= CNS_LIMIT_WARNING   ) int_O_CNS_current |= INT_FLAG_WARNING;
	else if ( int_O_CNS_current    >= CNS_LIMIT_ATTENTION ) int_O_CNS_current |= INT_FLAG_ATTENTION;
}


//////////////////////////////////////////////////////////////////////////////
// convert the simulated CNS value to integer
//
// Input:  CNS_fraction_sim       CNS value after predicted ascent in float
//
// Output: int_sim_CNS_fraction   CNS value after predicted ascent in integer
//                                including flags, will be routed to
//                                int_O_{normal,alternative}_CNS_fraction
//
static void convert_sim_CNS_for_display(void)
{
	// convert to integer
	float_value = CNS_fraction_sim; convert_float_to_int(); int_sim_CNS_fraction = int_value;

	// set warning & attention flags
	if      ( int_sim_CNS_fraction >= CNS_LIMIT_WARNING   ) int_sim_CNS_fraction |= INT_FLAG_WARNING;
	else if ( int_sim_CNS_fraction >= CNS_LIMIT_ATTENTION ) int_sim_CNS_fraction |= INT_FLAG_ATTENTION;

	// set invalid flag if there is an overflow in the stops table or calculation took too long
	if      ( deco_warnings & DECO_WARNING_INCOMPLETE ) int_sim_CNS_fraction |= INT_FLAG_INVALID;
}


//////////////////////////////////////////////////////////////////////////////
// convert the saturation value of the leading tissue to integer
//
// Input     lead_supersat              saturation of the leading tissue
//           lead_tissue                number of the     leading tissue
//           char_I_GF_High_percentage  GF high factor
//
// Output:   int_O_lead_supersat        saturation of the leading tissue
//           char_O_lead_tissue         number of the     leading tissue
//
// Modified: deco_warnings              deco engine warnings vector
//
static void convert_sat_for_display(void)
{
	// convert supersaturation of the leading tissue to int_O_lead_supersat in % (1.0 = 100%)
	// limit to 255 because of constraints in ghostwriter code
	     if ( lead_supersat <= 0.000 ) int_O_lead_supersat = 0;
	else if ( lead_supersat >  2.545 ) int_O_lead_supersat = 255;
	else                               int_O_lead_supersat = (unsigned short)(100 * lead_supersat + 0.5);

	// set warning & attention flags
	if( int_O_lead_supersat > 100 )
	{
		int_O_lead_supersat |= INT_FLAG_WARNING;			// make GF factor shown in red
		deco_warnings       |= DECO_WARNING_OUTSIDE;		// make depth     shown in red
	}
	else if(    (char_I_model != 0) && (int_O_lead_supersat > char_I_GF_High_percentage)
	         || (char_I_model == 0) && (int_O_lead_supersat > 99                       ) )
	{
		int_O_lead_supersat |= INT_FLAG_ATTENTION;			// make GF factor shown in yellow
		deco_warnings       |= DECO_ATTENTION_OUTSIDE;		// make depth     shown in yellow
	}

	// export also the number of the leading tissue
	char_O_lead_tissue = lead_tissue;
}


//////////////////////////////////////////////////////////////////////////////
// convert the ceiling value to integer
//
// Input:    ceiling         minimum depth permitted in float
//
// Output:   int_O_ceiling   minimum depth permitted in mbar (cm)
//
// Modified: deco_info       deco engine information vector
//
static void convert_ceiling_for_display(void)
{
	// Convert ceiling to int_O_ceiling in mbar relative pressure.
	// Round up to next 10 cm so that the ceiling disappears only
	// when the ceiling limit is really zero. This will coincident
	// with TTS switching back to NDL time.
	// The +1.5 term figures in the conversion factor of 10.015 m/bar
	// which is used inside the deco engine but not outside of it.
	if      ( ceiling <=  0.0 ) int_O_ceiling = 0;
	else if ( ceiling >  16.0 ) int_O_ceiling = 16000;
	else                        int_O_ceiling = (unsigned short)(ceiling * (1000+1.5) + 9);

	// set/reset ceiling flag
	if      ( int_O_ceiling   ) deco_info |=  DECO_CEILING;
	else                        deco_info &= ~DECO_CEILING;
}


//////////////////////////////////////////////////////////////////////////////
// push_tissues_to_vault & pull_tissues_from_vault
//
// ATTENTION: Do not use from inside the deco engine!
//            The vault is exclusively reserved to back-up and restore the real
//            tissues and related data when entering / leaving simulation mode!
//
// Input/Output: CNS_fraction_real       current real CNS value
//               char_O_deco_warnings    deco engine warnings vector
//               real_pres_tissue_N2[]   partial pressure of N2 in real tissues
//               real_pres_tissue_He[]   partial pressure of He in real tissues
//
// Output:       int_O_CNS_current      current CNS value as integer including flags
//
static void push_tissues_to_vault(void)
{
	// store the current CNS value and deco warnings
	vault_CNS_fraction_real = CNS_fraction_real;
	vault_deco_warnings     = char_O_deco_warnings;
	vault_deco_info         = char_O_deco_info;

	// copy the real pressures to the vault
	memcpy(vault_pres_tissue_N2, real_pres_tissue_N2, 256);
}

static void pull_tissues_from_vault(void)
{
	// restore the CNS value and deco warnings
	CNS_fraction_real    = vault_CNS_fraction_real;
	char_O_deco_warnings = vault_deco_warnings;
	char_O_deco_info     = vault_deco_info;

	// convert the CNS value to integer
	convert_cur_CNS_for_display();

	// copy the vault back to the real pressures
	memcpy(real_pres_tissue_N2, vault_pres_tissue_N2, 256);
}


//////////////////////////////////////////////////////////////////////////////
//
#ifndef CROSS_COMPILE
void main() {}
#endif
