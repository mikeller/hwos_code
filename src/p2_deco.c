// ***************************************************************************
// p2_deco.c                                         REFACTORED VERSION V2.99f
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
//    the Free Software Foundation, either version 3 of the License, or
//    (at your option) any later version.
//
//    This program is distributed in the hope that it will be useful,
//    but WITHOUT ANY WARRANTY; without even the implied warranty of
//    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//    GNU General Public License for more details.
//
//    You should have received a copy of the GNU General Public License
//    along with this program.  If not, see <http://www.gnu.org/licenses/>.
//
//////////////////////////////////////////////////////////////////////////////

// history:
// 01/03/08 v100: first release candidate
// 03/13/08 v101: start of programming ppO2 code
// 03/13/25 v101a: backup of interim version with ppO2 calculation
// 03/13/25 v101: open circuit gas change during deco
// 03/13/25 v101: CNS_fraction calculation
// 03/13/26 v101: optimization of tissue calc routines
// 07/xx/08 v102a: debug of bottom time routine
// 09/xx/08 v102d: Gradient Factor Model implementation
// 10/10/08 v104: renamed to build v103 for v118 stable
// 10/14/08 v104: integration of char_I_depth_last_deco for Gradient Model
// 03/31/09 v107: integration of FONT Incon24
// 05/23/10 v109: 5 gas changes & 1 min timer
// 07/13/10 v110: cns vault added
// 12/25/10 v110: split in three files (deco.c, main.c, definitions.h)
// 2011/01/20: [jDG] Create a common file included in ASM and C code.
// 2011/01/24: [jDG] Make ascenttime an short. No more overflow!
// 2011/01/25: [jDG] Fusion deco array for both models.
// 2011/01/25: [jDG] Use CF(54) to reverse deco order.
// 2011/02/11: [jDG] Reworked gradient-factor implementation.
// 2011/02/15: [jDG] Fixed inconsistencies introduced by gas switch delays.
// 2011/03/21: [jDG] Added gas consumption (CF56 & CF57) evaluation for OCR mode.
// 2011/04/15: [jDG] Store low_depth in 32bits (w/o rounding), for a better stability.
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
// 2012/10/05: [jDG] Better gas_volumes accuracy (average depth, switch between stop).
// 2013/03/05: [jDG] Should vault low_depth too.
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
#include	"p2_definitions.h"
#define		TEST_MAIN
#include	"shared_definitions.h"


// *********************************************************************************************************************************
//
//                                         C O N S T A N T S   D E F I N I T I O N S
//
// *********************************************************************************************************************************

// conditional compiles
#define		_rx_functions						// if defined, compile transmitter functions   (default:     included *)
//#define	_cave_mode							// if defined, compile cave mode into firmware (default: not included *)   ## OPTION IS UNDER CONSTRUCTION ##
												// * option needs to be included / excluded in hwos.inc, too!

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
#define ppWater							0.06270	// water vapor partial pressure in the lungs
#define METER_TO_BAR					0.09985	// conversion factor
#define BAR_TO_METER					10.0150	// conversion factor (1.0/METER_TO_BAR)
#define SURFACE_DESAT_FACTOR			0.70420	// surface desaturation safety factor
#define HYST							1.0E-06	// threshold for tissue graphics on-gassing / off-gassing visualization


// thresholds
#define CNS_WARNING_THRESHOLD			100		// threshold for CNS  warning
#define CNS_ATTENTION_THRESHOLD			 70		// threshold for CNS  attention
#define ppO2_GAP_TO_SETPOINT			 10		// gap between setpoint and max. ppO2 of the pure diluent [cbar]
#define GAS_NEEDS_ATTENTION_THRESHOLD	0.70	// threshold for gas needs attention [1.00 = 100%] 
#define PRESSURE_LIMIT_WARNING			200		// threshold for pressure reading warning  : 20.0 bar
#define PRESSURE_LIMIT_ATTENTION		500		// threshold for pressure reading attention: 50.0 bar
#define O2_CONSUMPTION_LIMIT_ATTENTION	 20		// threshold for O2 "SAC"         attention:  2.0 l/min

// deco engine states and modes - char_O_main_status: controls current tissue and deco status calculation (as-is situation)
#define DECO_COMPLETED_NORM				0x01	// the calculation of a normal       deco plan has just been completed
#define DECO_COMPLETED_ALT				0x02	// the calculation of an alternative deco plan has just been completed
//#define DECO_MODE_MASK				0x0C	// mask for mode selection ==> current diving mode
//#define DECO_MODE_LOOP				0x04	// see below
//#define DECO_MODE_CCR					0x04	// see below
//#define DECO_MODE_PSCR				0x08	// see below

#define DECO_USE_Z_FACTOR				0x10	// =1: figure in Z factor when converting gas volumes <-> pressures
#define DECO_CAVE_MODE					0x20	// =1: activate ascent gas needs calculation under cave constraints
#define DECO_BOTTOM_CALCULATE			0x40	// =1: switch to deco calculator interface
#define DECO_TR_FUNCTIONS				0x80	// =1: activate TR functions (pressure reading) processing

// deco engine states and modes - char_O_deco_status: controls deco plan calculation (to-be scenario)
#define DECO_STATUS_MASK				0x03	// bit mask for values below
#define DECO_STATUS_START				0x00	// value commands the start of a new deco calculation cycle
#define DECO_STATUS_FINISHED			0x00	// value indicates completion of deco calculation
#define DECO_STATUS_STOPS				0x01	// value indicated calculation is ongoing, currently calculating the stops
#define DECO_STATUS_RESULTS				0x02	// value indicates calculation is ongoing, currently calculating the results
#define DECO_STATUS_INIT				0x03	// value to be set once for the first invocation at the begin of a new dive

#define DECO_MODE_MASK					0x0C	// mask for mode selection ==> diving mode during ascent
#define DECO_MODE_LOOP					0x04	// =1: CCR (DECO_MODE_PSCR needs to be cleared) or pSCR mode
#define DECO_MODE_CCR					0x04	// to be used with == operator in combination with DECO_MODE_MASK only!
#define DECO_MODE_PSCR					0x08	// =1: pSCR mode (DECO_MODE_LOOP needs to be set, too)

#define DECO_PLAN_ALTERNATE				0x10	// =1: calculate the 2nd (alternative) deco plan
#define DECO_BAILOUT_MODE				0x20	// =1: do a bailout calculation, i.e. allow gas switches before first deco stop
#define DECO_VOLUME_CALCULATE			0x40	// =1: calculate ascent gas needs
#define DECO_ASCENT_DELAYED				0x80	// =1: calculate a delayed ascent (fTTS)

// deco engine warnings - char_O_deco_warnings
#define DECO_WARNING_IBCD				0x01	// IBCD occurring now
#define DECO_WARNING_IBCD_lock			0x02	// IBCD has occurred during the dive
#define DECO_WARNING_MBUBBLES			0x04	// micro bubbles likely to develop now
#define DECO_WARNING_MBUBBLES_lock		0x08	// ditto, but sometime during the dive
#define DECO_WARNING_OUTSIDE			0x10	// tissue pressures outside the Buhlmann model now
#define DECO_WARNING_OUTSIDE_lock		0x20	// tissue pressures outside the model sometime during the dive
#define DECO_ATTENTION_OUTSIDE			0x40	// tissue pressures are very close to the Buhlmann limit
#define DECO_WARNING_STOPTABLE_OVERFLOW	0x80	// internal error: no more space in the deco stops table

// deco engine status (char_O_deco_info)
#define DECO_FLAG						0x01	// =1: deco ppO2 levels are permitted
#define IND_DOUBLE_SWITCH_FLAG			0x02	// =1: switch to other tank advice active
#define DECO_STEADY						0x04	// =1: fTTS = TTS (not updated when in bailout mode)
#define DECO_DECREASING					0x08	// =1: fTTS < TTS (not updated when in bailout mode)
#define DECO_CEILING					0x10	// =1: ceiling depth > 0
#define GAS_NEEDS_CAVE					0x20	// =1: indicated gas needs are calculated in cave mode

// deco engine control - tissue_increment
#define TIME_MASK						0x7F	// (127 decimal, bits 0-6 set)
#define TISSUE_FLAG						0x80	// (128 decimal, bit   7  set)


// flags used with integer numbers
#define INT_FLAG_INVALID				0x0400	// =1: value not valid
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

// Functions used in surface mode
static void			 calc_interval(PARAMETER unsigned char time_increment);
														// Calculates the tissue off-gassing under surface conditions.
static void			 calc_desaturation_time(void);		// Calculates the desaturation and no-fly times.
static void			 clear_tissue(void);				// Resets all tissues to surface pressure equilibrium state.

// Main entry point in dive mode
static void			 calc_hauptroutine(void);			// Sequences all calculations for the real tissues and the deco calculation.

// Functions dedicated to the real tissues
static void			 calc_hauptroutine_data_input(void);// Initializes environment data and sets gas ratios for the real tissues.

// Functions combined for real tissues & deco calculations
static void			 calc_alveolar_pressures(void);		// Computes the partial pressures from the gas ratios and many more parameters,
														// needs either calc_hauptroutine_data_input() be called beforehand or
														// gas_find_current()/gas_find_better() and gas_set_ratios().
static void			 calc_tissues(void);				// Updates the tissues   dependent on the partial pressures of N2 and He.
static void			 calc_CNS(void);					// Updates the CNS value dependent on the partial pressure  of the O2.
static void			 calc_limit(PARAMETER float GF_current);
														// Calculates ceiling, current GF (supersaturation) and some more data.

// Functions dedicated to deco calculations
static void			 clear_deco_table(void);			// Clears the deco stops table, invoked at the start of each calculation cycle.
static void			 gas_find_current(void);			// Sets the first gas used for deco calculation, invoked at start of cycle, too.
static unsigned char gas_find_better(void);				// Checks for, and eventually switches to, a better gas.
static void			 gas_set_ratios(void);				// Sets the gas ratios for use in deco calculation (simulated tissues),
														// needs to be called after each gas change (gas_find_current/_better).
static void			 calc_NDL_time(void);				// Calculates remaining NDL time.
static void			 find_NDL_gas_changes(void);		// Finds the gas changes in an OC bailout ascent that is within NDL
static void			 calc_ascent_to_first_stop(void);	// Calculates ascent to the first deco stop.
static void			 calc_hauptroutine_calc_deco(void);	// Calculates the subsequent ascent until reaching surface.
static unsigned char calc_nextdecodepth(void);			// Calculates the depth of the next required deco stop.
static unsigned char update_deco_table(PARAMETER unsigned char time_increment);
														// Enters a new stop or extends an existing stop in the deco stops table.
static void			 calc_ascenttime(void);				// Calculates the ascent time from current depth and deco stop times.
static void			 gas_volumes(void);					// Calculates required gas volumes and pressures from the data in stops table.

// Functions for results reporting
static void			 publish_deco_table(void);			// Copies the internal deco stops table to the export interface.
static void			 convert_CNS_for_display(void);		// Converts the current     CNS value from float to integer.
static void			 convert_sim_CNS_for_display(void);	// Converts the end-of-dive CNS value from float to integer.
static void			 convert_GF_for_display(void);		// Converts leading tissue supersaturation value from float to integer, 1.0 = 100%.
static void			 convert_ceiling_for_display(void);	// Converts ceiling from float to integer in mbar relative pressure.


// internal helper functions
static unsigned short tmr5(void);						// Reads a hardware timer which is used for preemptive scheduling.
static void			 read_Buhlmann_coefficients(void);	// Reads the a and b coefficients from a ROM table.
static void			 read_Buhlmann_times(PARAMETER char period);
														// Reads pre-computed tissue increment factors from a ROM table.
static void			 read_Buhlmann_ht(void);			// Reads the half-times from a ROM table.
static void			 adopt_Buhlmann_coefficients(void);	// Computes average a and b coefficient by the N2/He tissue ratio.
static void			 temp_tissue_safety(void);			// Applies safety margins to the tissue increments.
static void			 push_tissues_to_vault(void);		// Stores the state of the real tissues during simulator runs.
static void			 pull_tissues_from_vault(void);		// Restores the state of the real tissues after a simulator run.



// *********************************************************************************************************************************
//
//                                         V A R I A B L E S   D E F I N I T I O N S
//
// *********************************************************************************************************************************

//---- Bank 5 parameters -----------------------------------------------------
#ifndef UNIX
#   pragma udata bank5=0x500
#endif

// general deco parameters

static float			GF_low;							// initialized from deco parameters
static float			GF_high;						// initialized from deco parameters
static float			GF_delta;						// initialized from deco parameters

static float			locked_GF_step_norm;			// GF_delta / low_depth_norm in normal plan
static float			locked_GF_step_alt;				// GF_delta / low_depth_alt  in alternative plan

static float			low_depth_norm;					// depth of deepest stop in normal plan
static float			low_depth_alt;					// depth of deepest stop in alternative plan

static float			float_ascent_speed;				// ascent speed from options_table (5.0 .. 10.0 m/min)
static float			float_deco_distance;			// additional depth below stop depth for tissue, CNS and gas volume calculation
static float			float_saturation_multiplier;	// safety factor for on-gassing rates
static float			float_desaturation_multiplier;	// safety factor for off-gassing rates

static unsigned char	split_N2_He[NUM_COMP];			// used for calculating the desaturation time

// real context: what we are doing now

static float			CNS_fraction;					// current CNS (1.00 = 100%)

static unsigned short	deco_tissue_vector;				// 16 bit vector to memorize all tissues that are in decompression
static unsigned short	IBCD_tissue_vector;				// 16 bit vector to memorize all tissues that experience IBCD

static float			pres_respiration_sac;			// current depth in absolute pressure, used in SAC calculation
static float			float_sac;						// used in SAC calculation
static unsigned int		max_sac_rate;					// used in SAC calculation to determine SAC rate attention


// simulation context: used to predict ascent

static float			sim_CNS_fraction;				// CNS after predicted ascent, 0.01 = 1%, as float

static unsigned int		int_sim_CNS_fraction;			// CNS after predicted ascent,    1 = 1%, as integer

static unsigned char	sim_depth_limit;				// depth of next stop in meters, used in deco calculations
static unsigned char	NDL_lead_tissue_norm;				// used to cache the tissue to start with when calculating the NDL
static unsigned char	NDL_lead_tissue_alt;				// used to cache the tissue to start with when calculating the NDL


// result values from calculation functions

static float			ceiling;						// minimum tolerated relative pressure (i.e. without surface pressure)
static float			lead_supersat;					// supersaturation of the leading tissue, 1.0 = 100%
static unsigned char	lead_number;					// number of the leading tissue

// stops table

static unsigned char	internal_deco_depth[NUM_STOPS];	// depths of the stops
static unsigned char	internal_deco_time[NUM_STOPS];	// durations of the stops
static unsigned char	internal_deco_gas[NUM_STOPS];	// gases used on the stops


// transfer variables between calc_desaturation_time() and calc_desaturation_time_helper()

static float			desat_factor;					// used to cache a pre-computed factor
static float			var_ht;							// buffer for a half-time factor
static float			pres_target;					// target pressure for a compartment
static float			pres_actual;					// current pressure of the compartment
static unsigned int		int_time;						// time it takes for the compartment to reach the target pressure


// transfer variables between gas_volumes() and gas_volumes_helper_1/_2()

static float			float_depth;					// depth of the stop or half-way point
static float			float_time;						// duration of the stop or ascent phase
static unsigned char	char_usage;						// gas usage in l/min
static unsigned char	gas_num;						// number of the gas/tank
static float			volume;							// computed volume of gas
static unsigned int		int_volume;						// required gas volume in liter
static unsigned int		int_pres_need;					// required gas volume in bar


// auxiliary variables for data buffering

static float			N2_equilibrium;					// used for N2 tissue graphics scaling
static float			temp_tissue;					// auxiliary variable to buffer tissue pressures
static float			float_pSCR_factor;				// pre-computed factor for pSCR ppO2 drop calculation
static float			calc_pres_tissue_N2;			// auxiliary variable to buffer tissue N2 pressure
static float			calc_pres_tissue_He;			// auxiliary variable to buffer tissue He pressure
static float 			pres_tissue;					// auxiliary variable to buffer total tissue pressure

// 10 byte free space left in this bank (4 bytes per float, 2 bytes per int/short, 1 byte per char)


//---- Bank 6 parameters -----------------------------------------------------
#ifndef UNIX
#   pragma udata bank6=0x600
#endif

// indexing and sequencing

static unsigned char	ci;								// used as index to the Buhlmann tables
static unsigned char	twosectimer = 0;				// used for timing the tissue updating
static unsigned char	tissue_increment;				// selector for real/simulated tissues and time increment


// environmental and gas data

static float			pres_surface;					// absolute pressure at the surface

static unsigned char	char_bottom_depth;				// bottom depth in meters, used by ascent time and gas needs calculation

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


// result values from calculation functions

static float			O2_ppO2;						// ppO2 - calculated for pure oxygen at current depth
static float			OC_ppO2;						// ppO2 - calculated for breathing in OC   mode
static float			pSCR_ppO2;						// ppO2 - calculated for breathing in pSCR mode

static float			ppO2;							// partial pressure of breathed oxygen
static float			ppN2;							// partial pressure of breathed nitrogen
static float			ppHe;							// partial pressure of breathed helium

static unsigned char	char_ppO2;						// partial pressure of breathed oxygen, as integer 100 = 1.00 bar
static unsigned char	NDL_time;						// time in minutes until reaching NDL
static unsigned int		ascent_time;					// time in minutes needed for the ascent


// Buhlmann model parameters

static float			var_N2_a;						// Buhlmann a, for current N2 tissue
static float			var_N2_b;						// Buhlmann b, for current N2 tissue
static float			var_He_a;						// Buhlmann a, for current He tissue
static float			var_He_b;						// Buhlmann b, for current He tissue
static float			var_N2_e;						// exposition, for current N2 tissue
static float			var_He_e;						// exposition, for current He tissue
static float			var_N2_ht;						// half-time,  for current N2 tissue
static float			var_He_ht;						// half-time,  for current He tissue


// gas in use

static unsigned char	sim_gas_current;				// number       of the currently used gas
static unsigned char	sim_gas_current_depth;			// change depth of the currently used gas


// vault to back-up & restore tissue data

static float			pres_tissue_N2_vault[NUM_COMP];	// stores the nitrogen tissue pressures
static float			pres_tissue_He_vault[NUM_COMP];	// stores the helium tissue pressures
static float			cns_vault_float;				// stores current CNS (float representation)
static unsigned char	deco_warnings_vault;			// stores warnings status


// 8 byte free space left in this bank (4 bytes per float, 2 bytes per int/short, 1 byte per char)


//---- Bank 7 parameters -----------------------------------------------------
#ifndef UNIX
#   pragma udata bank7=0x700
#endif

// Keep order and position of the variables in bank 7 as they are backed-up to & restored from EEPROM 

float					pres_tissue_N2[NUM_COMP];		// 16 floats = 64 bytes
float					pres_tissue_He[NUM_COMP];		// 16 floats = 64 bytes

float					sim_pres_tissue_N2[NUM_COMP];	// 16 floats = 64 bytes
float					sim_pres_tissue_He[NUM_COMP];	// 16 floats = 64 bytes

// bank is full!


//---- Bank 8 parameters -----------------------------------------------------
#ifndef UNIX
#   pragma udata overlay bank8=0x800

static char				md_pi_subst[256];				// overlay C-code data stack here, too

#   define C_STACK md_pi_subst
#endif


// Back to bank6 for further tmp data
// Do not delete this assignment, it is needed by the compiler/linker.
#ifndef UNIX
#   pragma udata bank6
#endif


// *********************************************************************************************************************************
//
//                                               L O O K - U P   T A B L E S
//
// *********************************************************************************************************************************

#ifndef UNIX
#   pragma romdata Buhlmann_tables = 0x1DD00  // needs to be in the UPPER bank
#endif

rom const float Buhlmann_ab[4*16] = {
// Data ZH-L16C, from Bühlmann Tauchmedizin 2002, option 1a (4mn)
// a for N2    b for N2     a of He     b for He
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

rom const float Buhlmann_ht[2*16] = {
// Compartment half-life, in minute
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

rom const float e2secs[2*16] = {
// result of  1 - 2^(-1/(2sec*HT))
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

rom const float e1min[2*16] = {
// Integration constant for 1 minute,
// Ie. 1- 2^(-1/HT)
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
// The 10 min Value in float notation:
//  result of 1 - 2^(-10/ht)
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


// moved from 0x0D000 to 0x0C000 in v.108
#ifndef UNIX
#	pragma code p2_deco = 0x0C000
#endif


//////////////////////////////////////////////////////////////////////////////
// Bump to blue-screen when an assert is wrong
#ifdef __DEBUG
void assert_failed(PARAMETER short int line)
{
}
#endif


//////////////////////////////////////////////////////////////////////////////
// When calling C code from ASM context, the data stack pointer and
// frames should be reset. Bank8 is used by stack

#ifdef CROSS_COMPILE
#	define RESET_C_STACK
#else
#	ifdef __DEBUG
#		define RESET_C_STACK fillDataStack();
		void fillDataStack(void)
		{
			_asm
				LFSR	1,C_STACK
				MOVLW	0xCC
		loop:	MOVWF	POSTINC1,0
				TSTFSZ	FSR1L,0
				BRA		loop

				LFSR	1,C_STACK
				LFSR	2,C_STACK
			_endasm
		}
#	else
#		define	RESET_C_STACK	\
		_asm					\
			LFSR	1,C_STACK	\
			LFSR	2,C_STACK	\
		_endasm
#	endif
#endif


//////////////////////////////////////////////////////////////////////////////
// Fast subroutine to read timer 5
// Note: result is in 1/32 of milliseconds (30.51757813 us/bit to be precise)
static unsigned short tmr5(void)
{
#ifndef CROSS_COMPILE
	_asm
		movff	0xf7c,PRODL		// TMR5L
		movff	0xf7d,PRODH		// TMR5H
	_endasm						// result in PRODH:PRODL
#else
	return 0;
#endif
}


//////////////////////////////////////////////////////////////////////////////
// read Buhlmann coefficients a and b for compartment ci
//
static void read_Buhlmann_coefficients(void)
{
#ifndef CROSS_COMPILE
	// Note: We don't use far ROM pointer, because handling
	//       24 bit is too complex, hence we have to set the
	//       UPPER page ourself...
	//       -> Set to zero if tables are moved to lower pages!
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
// read Buhlmann increments for compartment ci
// If period == 0 :  2 sec interval
//              1 :  1 min interval
//              2 : 10 min interval
static void read_Buhlmann_times(PARAMETER char period)
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

	assert( ci < NUM_COMP );

	// Integration intervals
	switch(period)
	{
	case 0: //---- 2 sec -----------------------------------------------------
		{
			overlay rom const float* ptr = &e2secs[2*ci];
			var_N2_e = *ptr++;
			var_He_e = *ptr++;
		}
		break;

	case 1: //---- 1 min -----------------------------------------------------
		{
			overlay rom const float* ptr = &e1min[2*ci];
			var_N2_e = *ptr++;
			var_He_e = *ptr++;
		}
		break;

	case 2: //---- 10 min ----------------------------------------------------
		{
			overlay rom const float* ptr = &e10min[2*ci];
			var_N2_e = *ptr++;
			var_He_e = *ptr++;
		}
	break;

	default:
		assert(0);  // Never go there...
	}
}


//////////////////////////////////////////////////////////////////////////////
// read Buhlmann half-times for compartment ci
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
// compute adopted Buhlmann coefficients
//
static void adopt_Buhlmann_coefficients(void)
{
	// adopt a and b coefficients to current N2/He ratio inside the tissue
	var_N2_a = (var_N2_a * calc_pres_tissue_N2 + var_He_a * calc_pres_tissue_He) / pres_tissue;
	var_N2_b = (var_N2_b * calc_pres_tissue_N2 + var_He_b * calc_pres_tissue_He) / pres_tissue;
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
// Called every second during diving,
// updates tissues on every second invocation.
//
// Every few seconds (or slower when TTS > 16):
// - Updates deco table (char_O_deco_time/depth) with new values,
// - updates ascent time, and
// - sets status to zero (so we can check there is new results).
//
void deco_calc_hauptroutine(void)
{
	RESET_C_STACK
	calc_hauptroutine();
}

//////////////////////////////////////////////////////////////////////////////
// deco_clear_tissue
//
// called from: start.asm
//              menu_tree.asm
//              simulator.asm
//
// Sets all tissues to equilibrium with Air at ambient pressure,
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
// Updates tissues and CNS value for char_I_dive_interval minutes on air
// at ambient pressure and calculates resulting GF factor and ceiling for
// a GF-high of 100% (ceiling and GF factor not used by simulator.asm)
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
// calculates resulting GF factor and ceiling for a GF-high of 100% (ceiling
// is not used by *.asm files).
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
// calculates resulting GF factor and ceiling for a GF-high of 100% (ceiling
// is not used by sleepmode.asm).
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
// calc_nextdecodepth
//
// INPUT, changing during dive:
//        sim_pres_respiration     : current depth in absolute pressure
//
// INPUT, fixed during dive:
//        pres_surface
//        GF_delta
//        GF_high
//        GF_low
//        char_I_depth_last_deco
//
// MODIFIED
//        locked_GF_step_norm/_alt : used for GF model
//        low_depth_norm/_alt      : used for GF model
//
// OUTPUT
//        sim_depth_limit          : depth of next stop in meters     (if RETURN == true )
//                                   next possible depth without stop (if RETURN == false)
//
// RETURN TRUE if a stop is needed, else false
//
static unsigned char calc_nextdecodepth(void)
{
	overlay unsigned char need_stop;

	// compute current depth in meters
	overlay float depth = (sim_pres_respiration - pres_surface) * BAR_TO_METER;

	// compute depth in meters after 1 minute of ascent at float_ascent_speed (5..10 m/min)
	overlay float min_depth = (depth > float_ascent_speed) ? (depth - float_ascent_speed) : 0.0;


	// target the simulated tissues
	tissue_increment = 0;

	//---- check if a stop is needed for deco reasons ----------------------------

	// switch on deco model
	if( char_I_deco_model != 0 )
	{
		//---- ZH-L16 + GRADIENT FACTOR Model ------------------------------------

		overlay float locked_GF_step;
		overlay float low_depth;
		overlay float limit_depth;

		overlay unsigned char first_stop = 0;


		// calculate minimum depth we can ascent to in bar relative pressure
		calc_limit(GF_low);

		// check if we can surface directly
		if( ceiling <= 0.0 )
		{
			min_depth = 0.0;		// set minimum depth to 0 meters = surface
			goto no_deco_stop;		// done
		}

		// convert minimum depth we can ascent to from relative pressure to depth in meters
		limit_depth = ceiling * BAR_TO_METER;

		// recall low_depth dependent on current plan
		low_depth = (char_O_deco_status & DECO_PLAN_ALTERNATE) ? low_depth_alt : low_depth_norm;

		// Store the deepest point needing a deco stop as the LOW reference for GF.
		// NOTE: following stops will be validated using this LOW-HIGH GF scale,
		//       so if we want to keep coherency, we should not validate this stop
		//       yet, but apply the search to it, as for all the following stops afterward.
		if( limit_depth > low_depth )
		{
			// update GF parameters
			low_depth      = limit_depth;
			locked_GF_step = GF_delta / low_depth;

			// store updated GF parameters dependent on current plan
			if( char_O_deco_status & DECO_PLAN_ALTERNATE )
			{
				low_depth_alt       = low_depth;
				locked_GF_step_alt  = locked_GF_step;
			}
			else
			{
				low_depth_norm      = low_depth;
				locked_GF_step_norm = locked_GF_step;
			}
		}
		else
		{
			// recall locked_GF_step dependent of current plan
			locked_GF_step = (char_O_deco_status & DECO_PLAN_ALTERNATE) ? locked_GF_step_alt : locked_GF_step_norm;
		}

		// invalidate this stop if we can ascent for 1 minute without going above minimum required deco depth
		if( limit_depth < min_depth ) goto no_deco_stop;


		//---- if program execution passes here, we need a deco stop --------------------------------

		// round to multiple of 3 meters (limit depth is in meters of depth)
		first_stop = 3 * (unsigned char)(0.4999 + limit_depth * 0.333333);

		// check a constraint
		assert( first_stop < 128 );

		// apply correction for the shallowest stop, use char_I_depth_last_deco (3..6 m) instead
		if( first_stop == 3 ) first_stop = char_I_depth_last_deco;

		// We have a stop candidate.
		// But maybe ascending to the next stop will diminish the constraint,
		// because the GF might decrease more than the pressure gradient...
		while( first_stop > 0 )
		{
			// next depth
			overlay unsigned char next_stop;

			// invalidate this stop if we can ascent one more minute without going above minimum required deco depth
			if( first_stop <= (unsigned char)min_depth ) goto no_deco_stop;

			// compute depth of next stop
			if      ( first_stop <= char_I_depth_last_deco ) next_stop = 0;
			else if ( first_stop == 6                      ) next_stop = char_I_depth_last_deco;
			else                                             next_stop = first_stop - 3;

			// compute limit with the GF of the new stop candidate
			if( (low_depth == 0.0) || (next_stop > low_depth) ) calc_limit(GF_low);
			else                                                calc_limit(GF_high - next_stop * locked_GF_step);

			// check if ascent to the next stop candidate is possible
			if( ceiling * BAR_TO_METER >= next_stop )
				goto deco_stop_found;					// no - ascent to next_stop forbidden

			// else, validate that stop and loop...
			first_stop = next_stop;
		}

no_deco_stop:
		need_stop       = 0;							// set flag for stop needed to 'no'
		sim_depth_limit = (unsigned char)min_depth;		// report depth we can ascent to without stop
		goto done;

deco_stop_found:
		need_stop       = 1;							// set flag for stop needed to 'yes'
		sim_depth_limit = (unsigned char)first_stop;	// stop depth, in meters

done:
		;
	}
	else
	{
		//---- ZH-L16 model -------------------------------------------------

		overlay float limit_depth;


		// calculate minimum depth we can ascent to in bar relative pressure
		calc_limit(1.0);

		// check if we can surface directly
		if( ceiling >= 0 )
		{
			// no - set flag for stop needed to 'yes'
			need_stop = 1;

			// convert stop depth in relative pressure to stop index
			limit_depth = ceiling * BAR_TO_METER / 3.0;

			// convert stop index to depth in meters, rounded to multiple of 3 meters
			sim_depth_limit = 3 * (short)(limit_depth + 0.99);

			// correct last stop to 4m/5m/6m
			if( sim_depth_limit == 3 ) sim_depth_limit = char_I_depth_last_deco;
		}
		else
		{
			// yes - set flag for stop needed to 'no'
			need_stop       = 0;

			// set depth we can ascent to as 0 = surface
			sim_depth_limit = 0;
		}
	}

	// ---- After the first deco stop, gas changes are only done at deco stops now! -----------------------

	// check if a stop is found and there is a better gas to switch to
	if( need_stop         )
	if( gas_find_better() )
	{
		// set the new calculation ratios for N2, He and O2
		gas_set_ratios();

		// prime the deco stop with the gas change time
		update_deco_table(char_I_gas_change_time);
	}

	return need_stop;
}


//////////////////////////////////////////////////////////////////////////////
// publish_deco_table
//
// Buffer the stops, once computed, so we can continue to display them
// while computing the next set.
//
static void publish_deco_table(void)
{
	overlay unsigned char x, y;


	// Copy depth of the first (deepest) stop, because when reversing
	// order, it will be hard to find...
	char_O_first_deco_depth = internal_deco_depth[0];
	char_O_first_deco_time  = internal_deco_time [0];

	for( x = 0; x < NUM_STOPS; x++ )
	{
		char_O_deco_depth[x] = internal_deco_depth[x];
		char_O_deco_time [x] = internal_deco_time [x];
		char_O_deco_gas  [x] = internal_deco_gas  [x];
	}

	// Now fill the char_O_deco_time_for_log array
	// ---- First: search the first non-null depth
	for( x = (NUM_STOPS-1); x != 0; --x )
		if( internal_deco_depth[x] != 0 ) break;

	//---- Second: copy to output table (in reverse order)
	for( y = 0; y < NUM_STOPS; y++, --x )
	{
		char_O_deco_time_for_log[y] = internal_deco_time [x];

		// Stop when the last transfer is done.
		if( x == 0 ) break;
	}

	//---- Third: fill table with null until end
	for( y++; y < NUM_STOPS; y++ )
		char_O_deco_time_for_log[y] = 0;
}


//////////////////////////////////////////////////////////////////////////////
// temp_tissue_safety
//
// outsourced in v.102
//
// Apply safety factors for both ZH-L16 models.
//
static void temp_tissue_safety(void)
{
	assert( 0.0 <  float_desaturation_multiplier && float_desaturation_multiplier <= 1.0 );
	assert( 1.0 <= float_saturation_multiplier   && float_saturation_multiplier   <= 2.0 );

	if( temp_tissue < 0.0 ) temp_tissue *= float_desaturation_multiplier;
	else                    temp_tissue *= float_saturation_multiplier;
}


//////////////////////////////////////////////////////////////////////////////
// Find current gas in the list (if any) and get its change depth
//
// Input:  char_I_current_gas    : 1..5 or 6
//
// Output: sim_gas_current       : 1..6 or 0 for the manually configured gas/dil
//         sim_gas_current_depth : change depth (MOD) of the gas/dil in meters
//
static void gas_find_current(void)
{
	assert( 1 <= char_I_current_gas && char_I_current_gas <= 6 );

	if( char_I_current_gas <= NUM_GAS )			// gas/diluent 1-5
	{
		sim_gas_current       = char_I_current_gas;
		sim_gas_current_depth = char_I_deco_gas_change[sim_gas_current-1];
	}
	else
	{
		sim_gas_current       = 0;
		sim_gas_current_depth = char_I_gas6_depth;
	}
}


//////////////////////////////////////////////////////////////////////////////
// Find the deco gas with the shallowest change depth below or at the current depth
//
// INPUT    sim_depth_limit          : current depth in meters
//          sim_gas_current          : number of the currently used gas/dil
//          sim_gas_current_depth    : change depth of the currently used gas/dil
//          char_I_deco_gas_type[]   : types         of the gases/dils
//          char_I_deco_gas_change[] : change depths of the gases/dils
//
// MODIFIED sim_gas_current          : index of the gas (1..5) - only if return value is true
//          sim_gas_current_depth    : switch depth            - only if return value is true
//
// RETURNS TRUE if a better gas is available
//
static unsigned char gas_find_better(void)
{
	overlay unsigned char switch_depth = 255;
	overlay unsigned char switch_gas   =   0;
	overlay unsigned char j;

	// no automatic gas changes in CCR mode
	if( (char_O_deco_status & DECO_MODE_MASK) == DECO_MODE_CCR ) return 0;

	// loop over all deco gases to find the shallowest one below or at current depth
	for( j = 0; j < NUM_GAS; ++j )
	{
		// Is this gas not the one we are already breathing?
		if( j+1 != sim_gas_current )

		// Is this -                      an (active) deco gas,
		//         - or if in deco phase, any gas but disabled
		//         - or if in bailout,    any gas but disabled,
		//         - or if in pSCR mode,  any gas but disabled?
		if(   (                                               ( char_I_deco_gas_type[j] == 3 ) )
		   || ( ( char_O_deco_info   & DECO_FLAG         ) && ( char_I_deco_gas_type[j] != 0 ) )
		   || ( ( char_O_deco_status & DECO_BAILOUT_MODE ) && ( char_I_deco_gas_type[j] != 0 ) )
		   || ( ( char_O_main_status & DECO_MODE_PSCR    ) && ( char_I_deco_gas_type[j] != 0 ) ) )

		// Is the change depth of the this gas deeper than or
		// at least equal to the current depth?
		if( char_I_deco_gas_change[j] >= sim_depth_limit )

		// Is the change depth of this gas shallower than the
		// change depth of the gas we are currently on?
		if( char_I_deco_gas_change[j] < sim_gas_current_depth )

		// Is the change depth of this gas shallower than the change
		// depth of the best gas found so far, or is it the first
		// better gas found?
		if( char_I_deco_gas_change[j] < switch_depth )

		// If there is a yes to all these questions, we have a better gas!
		{
			switch_gas   = j+1;							// remember this gas (1..5)
			switch_depth = char_I_deco_gas_change[j];	// remember its change depth
		}

	}	// continue looping through all gases to eventually find an even better gas

	// has a better gas been found?
	if( switch_gas )
	{
		// YES - set the better gas as the new gas
		sim_gas_current       = switch_gas;

		// set its change depth as the last used change depth
		sim_gas_current_depth = switch_depth;

		assert( sim_gas_current_depth < switch_depth );

		// signal a better gas was found
		return 1;
	}
	else
	{
		// NO - signal no better gas was found
		return 0;
	}
}


//////////////////////////////////////////////////////////////////////////////
// Set calc_N2/He/O2_ratios by sim_gas_current
//
// Input:  sim_gas_current              : index of gas to use
//         real_O2_ratio, real_He_ratio : if gas =    0 (the manually set gas)
//         char_I_deco_O2/He_ratio[]    : if gas = 1..5 (the configured gases)
//
// Output: sim_N2_ratio, sim_He_ratio   : ratios of the inert gases
//         sim_pSCR_drop                : ppO2 drop in pSCR loop
//
static void gas_set_ratios(void)
{
	overlay float sim_IG_ratio;

	assert( 0 <= sim_gas_current <= NUM_GAS );


	// get gas ratios
	if( sim_gas_current == 0 )
	{
		sim_O2_ratio = real_O2_ratio;
		sim_He_ratio = real_He_ratio;
	}
	else
	{
		sim_O2_ratio = 0.01 * char_I_deco_O2_ratio[sim_gas_current-1];
		sim_He_ratio = 0.01 * char_I_deco_He_ratio[sim_gas_current-1];
	}

	// inert gas ratio (local helper variable)
	sim_IG_ratio  = 1.00 - sim_O2_ratio;

	// N2 ratio
	sim_N2_ratio  = sim_IG_ratio - sim_He_ratio;

	// ppO2 drop in pSCR loop
	sim_pSCR_drop = sim_IG_ratio * float_pSCR_factor;


	assert( 0.0 <=  sim_N2_ratio && sim_N2_ratio  <= 0.95 );
	assert( 0.0 <=  sim_He_ratio && sim_He_ratio  <= 0.95 );
	assert(        (sim_N2_ratio +  sim_He_ratio) <= 0.95 );
}


//////////////////////////////////////////////////////////////////////////////
// Compute respired ppO2, ppN2 and ppHe
//
// Input:  tissue_increment           : selector for targeting simulated or real tissues
//         char_O_main_status         : breathing mode for real      tissues
//         char_O_deco_status         : breathing mode for simulated tissues
//         sim_/real_O2_ratio         : (simulated) O2 ratio breathed
//         sim_/real_N2_ratio         : (simulated) N2 ratio breathed
//         sim_/real_He_ratio         : (simulated) He ratio breathed
//         sim_/real_pres_respiration : (simulated) respiration pressure [bar]
//         sim_/real_pSCR_drop        : (simulated) pSCR O2 drop
//         pres_surface               : surface pressure [bar]
//         char_I_const_ppO2          : ppO2 reported from sensors or setpoint [cbar]
//         float_deco_distance        : safety factor, additional depth below stop depth [bar]
//         ppWater                    : water-vapor pressure inside respiratory tract [bar]
//
// Output: ppN2                       : respired N2 partial pressure
//         ppHe                       : respired He partial pressure
//         char_ppO2                  : breathed ppO2 in %, used in CNS calculation
//
void calc_alveolar_pressures(void)
{
	overlay float calc_pres_respiration;
	overlay float calc_O2_ratio;
	overlay float calc_N2_ratio;
	overlay float calc_He_ratio;
	overlay float calc_pSCR_drop;

	overlay unsigned char status;


	assert( 0.00 <= real_N2_ratio && real_N2_ratio <= 1.00 );
	assert( 0.00 <= real_He_ratio && real_He_ratio <= 1.00 );
	assert(        (real_N2_ratio + real_He_ratio) <= 1.00 );
	assert( 0.800 < real_pres_respiration && real_pres_respiration < 14.0 );

	assert( 0.00 <= sim_N2_ratio && real_N2_ratio <= 1.00 );
	assert( 0.00 <= sim_He_ratio && real_He_ratio <= 1.00 );
	assert(         (sim_N2_ratio + sim_He_ratio) <= 1.00 );
	assert( 0.800 < sim_pres_respiration && sim_pres_respiration < 14.0 );


	// get input data according to context
	if( tissue_increment & TISSUE_FLAG )
	{
		//---- real tissues -----------------------------------------------------------
		status                = char_O_main_status;
		calc_pres_respiration = real_pres_respiration;
		calc_pSCR_drop        = real_pSCR_drop;

		calc_O2_ratio         = real_O2_ratio;
		calc_N2_ratio         = real_N2_ratio;
		calc_He_ratio         = real_He_ratio;
	}
	else
	{
		//---- simulated tissues ------------------------------------------------------
		status                = char_O_deco_status;
		calc_pres_respiration = sim_pres_respiration;
		calc_pSCR_drop        = sim_pSCR_drop;

		calc_O2_ratio         = sim_O2_ratio;
		calc_N2_ratio         = sim_N2_ratio;
		calc_He_ratio         = sim_He_ratio;
	}

	//---- OC, CCR and Bailout Mode Gas Calculations -----------------------------------

	// calculate ppO2 of pure oxygen
	O2_ppO2 = calc_pres_respiration - ppWater;

	// capture failure condition in case real_pres_respiration is < ppWater (should never happen...)
	if( O2_ppO2 < 0.0 ) O2_ppO2 = 0.0;

	// calculate ppO2 of the pure gas (OC, diluent)
	OC_ppO2 = O2_ppO2 * calc_O2_ratio;

	// calculate pSCR ppO2
	pSCR_ppO2 = OC_ppO2 - calc_pSCR_drop;

	// capture failure condition in case pSCR_ppO2 becomes negative
	if( pSCR_ppO2 < 0.0 ) pSCR_ppO2 = 0.0;


	//---- Loop modes : adjust ppN2 and ppHe for change in ppO2 due to setpoint (CCR) or drop (pSCR) ---
	if( status & DECO_MODE_LOOP )
	{
		overlay float const_ppO2;
		overlay float   max_ppO2;

		// get the current sensor reading (CCR / pSCR if fitted) or the fixed setpoint (CCR) / a zero (pSCR)
		const_ppO2 = 0.01 * char_I_const_ppO2;

		// Limit the setpoint to the maximum physically possible ppO2. This prevents for
		// example calculating with a setpoint of 1.3 bar in only 2 meters of depth.
		// Additionally, the ppO2 can be further reduced to account for exhaled inert gases
		// accumulating in the loop by the user-adjustable setting char_I_cc_max_frac_o2.
		// (ppWater is neglected here)
		max_ppO2 = 0.01 * char_I_cc_max_frac_o2 * calc_pres_respiration;

		if( const_ppO2 > max_ppO2 ) const_ppO2 = max_ppO2;

		// check which kind of loop we are on
		if( status & DECO_MODE_PSCR )
		{
			//---- pSCR Mode --------------------------------------------------------------------------

			// Use the sensor value if available, but only in real tissue context!
			// In all other cases use calculated ppO2.
			if( char_I_const_ppO2 && (tissue_increment & TISSUE_FLAG)) ppO2 = const_ppO2;
			else                                                       ppO2 = pSCR_ppO2;
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
		    || ( calc_O2_ratio         > 0.995 ) )   // diluent is pure O2, i.e. calc_N2_ratio + calc_He_ratio = 0 yielding a div/0
		{
			// failure condition present, set predetermined result
			calc_pres_respiration = 0.0;
		}
		else
		{
			// no failure conditions present, equation can be executed
			calc_pres_respiration -= ppO2;
			calc_pres_respiration /= calc_N2_ratio + calc_He_ratio;
		}
	}
	else
	{
		//---- OC mode ---------------------------------------------------------------------------------

		// breathed ppO2 is ppO2 of pure gas
		ppO2 = OC_ppO2;
	}


	//---- derive char_ppO2 in [cbar], used for calculating CNS% ---------------------------------------

	if      ( ppO2 <  0.01  ) char_ppO2  =   0;
	else if ( ppO2 >= 2.545 ) char_ppO2  = 255;
	else                      char_ppO2  = (unsigned char)(100 * ppO2 + 0.5);


	//---- calculate ppN2 and ppHe ---------------------------------------------------------------------

	// add deco safety distance when working on simulated tissues
	if( !(tissue_increment & TISSUE_FLAG) ) calc_pres_respiration += float_deco_distance;

	// compute ppN2 and ppHe, capture potential failure conditions first:
	if( calc_pres_respiration > ppWater )
	{
		// subtract water vapor pressure
		calc_pres_respiration -= ppWater;

		// calculate partial pressures
		ppN2 = calc_N2_ratio * calc_pres_respiration;
		ppHe = calc_He_ratio * calc_pres_respiration;
	}
	else
	{
		// calculated respired pressure is < water vapor pressure, thus set ppN2 and ppHe to 0
		ppN2 = 0.0;
		ppHe = 0.0;
	}
}


//////////////////////////////////////////////////////////////////////////////
// clear_tissue
//
// optimized in v.101 (var_N2_a)
//
// Reset all tissues to surface pressure equilibrium state.
//
static void clear_tissue(void)
{
	// safety limit to prevent improper initialization values
	if( int_I_pres_respiration < 500) int_I_pres_respiration = 500;		// min. respiration pressure = 500 mbar

	real_pres_respiration = 0.001  * int_I_pres_respiration;
	N2_equilibrium        = 0.7902 * (real_pres_respiration - ppWater);

	for( ci = 0; ci < NUM_COMP; ci++ )
	{
		// cycle through the 16 Buhlmann N2 tissues
		pres_tissue_N2[ci]              = N2_equilibrium;	// initialize data for "real" tissue
		char_O_tissue_N2_saturation[ci] = 11;				// initialize data for tissue graphics

		// cycle through the 16 Buhlmann He tissues
		pres_tissue_He[ci]              = 0.0;				// initialize data for "real" tissue
		char_O_tissue_He_saturation[ci] = 0;				// initialize data for tissue graphics
	}

	// reset CNS values
	CNS_fraction = 0.0;
	int_O_CNS_fraction = int_O_normal_CNS_fraction = int_O_alternate_CNS_fraction = 0;


	// reset any warnings and status data
	char_O_deco_warnings		= 0;
	char_O_deco_status			= 0;

	// reset some more vars to their defaults
	char_O_nullzeit				= 240;
	int_O_ascenttime			= 0;
	int_O_alternate_ascenttime	= 0;
	int_O_gradient_factor		= 0;
}


//////////////////////////////////////////////////////////////////////////////
// calc_hauptroutine
//
// this is the major code in dive mode calculates:
//      the tissues,
//      the bottom time,
//      and simulates the ascend with all deco stops.
//
static void calc_hauptroutine(void)
{
	overlay unsigned int int_ppO2_min;
	overlay unsigned int int_ppO2_max;
	overlay unsigned int int_ppO2_max_dil;
	overlay unsigned int int_ppO2_max_max;
	overlay float        EAD;
	overlay float        END;


	//--- Set-up Part --------------------------------------------------------------------------------

	// clear flags indicating a calculation has been completed
	char_O_main_status &= ~( DECO_COMPLETED_NORM + DECO_COMPLETED_ALT );

	// twosectimer:
	// calc_hauptroutine is now invoked every second to speed up the deco planning.
	// Because the tissue and CNS calculations are based on a two seconds period, a
	// toggle-timer is used to skip every 2nd invocation.
	twosectimer = (twosectimer) ? 0 : 1;

	// do initializations that need to be done only once at the beginning of a dive
	if( (char_O_deco_status & DECO_STATUS_MASK) == DECO_STATUS_INIT )
	{
		// compute a factor that will be used later on in pSCR calculations
		float_pSCR_factor = 0.01 * char_I_PSCR_drop * char_I_PSCR_lungratio;
	}


	//---- Calculations Part ----------------------------------------------------------------------

	// acquire current environment data
	calc_hauptroutine_data_input();

	// target the real tissues with 2 second increments by default
	tissue_increment = TISSUE_FLAG | 0;

	// calculate ppO2, ppN2 and ppHe
	calc_alveolar_pressures();

	// All deco code is invoked every second. But as the tissue and CNS updates are based
	// on 2 seconds periods, each update is done only on each 2nd second. In case a "fast
	// forward" of the tissues is commanded, the 2-seconds rule is over-raided.
	if( twosectimer || char_I_sim_advance_time )
	{
		// Set up normal tissue updating or "fast forward" updating for simulator
		// sim+5' function and deco calculator bottom time calculation.
		if( char_I_sim_advance_time > 0 )
		{
			// configure "fast forward" tissue updating
			tissue_increment = TISSUE_FLAG | char_I_sim_advance_time;

			// clear the "mailbox"
			char_I_sim_advance_time = 0;
		}

		// calculate the real tissues
		calc_tissues();

		// update the CNS value for the real tissues
		calc_CNS();

		// calculate ceiling (at GF_high or 100%) and leading tissue supersaturation
		if( char_I_deco_model ) calc_limit(GF_high);		// GF factors enabled
		else                    calc_limit(  1.0  );		// classic Buhlmann

		// convert ceiling from float to integer for export [mbar relative pressure]
		convert_ceiling_for_display();

		// convert leading tissue supersaturation value from float to integer for export [%]
		convert_GF_for_display();

		// convert CNS value from float to integer for export
		convert_CNS_for_display();
	}

	//---- Calculate and Export EAD and END ------------------------------------------------------

	// calculate EAD (Equivalent Air Depth): equivalent depth for the same N2 level with plain air
	EAD = (ppN2 / 0.7902 + ppWater - pres_surface) * BAR_TO_METER;

	// calculate END (Equivalent Narcotic Depth): here O2 is treated as narcotic, too
	// Source cited: The Physiology and Medicine of Diving by Peter Bennett and David Elliott,
	//               4th edition, 1993, W.B.Saunders Company Ltd, London.
	END = (real_pres_respiration - ppHe - pres_surface) * BAR_TO_METER;

	// export EAD
	if( (EAD < 0.0) || (EAD > 245.5) ) char_O_EAD = 0;
	else                               char_O_EAD = (unsigned char)(EAD + 0.5);

	// export END
	if( (END < 0.0) || (END > 245.5) ) char_O_END = 0;
	else                               char_O_END = (unsigned char)(END + 0.5);


	//---- Compute ppO2 Values in [cbar] ---------------------------------------------------------

	// pure oxygen ppO2
	     if ( O2_ppO2       <  0.01  ) int_O_O2_ppO2       =   0;
	else if ( O2_ppO2       >= 9.995 ) int_O_O2_ppO2       = 999;
	else                               int_O_O2_ppO2       = (unsigned int)(100 *   O2_ppO2 + 0.5);

	// pure gas ppO2
	     if ( OC_ppO2       <  0.01  ) int_O_pure_ppO2     =   0;
	else if ( OC_ppO2       >= 9.995 ) int_O_pure_ppO2     = 999;
	else                               int_O_pure_ppO2     = (unsigned int)(100 *   OC_ppO2 + 0.5);

	// calculated pSCR ppO2
	     if ( pSCR_ppO2     <  0.01  ) int_O_pSCR_ppO2     =   0;
	else if ( pSCR_ppO2     >= 9.995 ) int_O_pSCR_ppO2     = 999;
	else                               int_O_pSCR_ppO2     = (unsigned int)(100 * pSCR_ppO2 + 0.5);

	// breathed ppO2
	     if ( ppO2          <  0.01  ) int_O_breathed_ppO2 =   0;
	else if ( ppO2          >= 9.995 ) int_O_breathed_ppO2 = 999;
	else                               int_O_breathed_ppO2 = (unsigned int)(100 *      ppO2 + 0.5);


	//---- Set/Reset Deco Mode --------------------------------------------------------------------

	// Set the deco mode flag if:
	// - breathing an OC deco gas (gas type 3), or
	// - breathing a gas or diluent that officially is disabled (type 0), or
	// - if nearby or above the deepest deco stop (nearby means 1 meter below, the additional 0.9 serves rounding effects)
	if  (    ( char_I_current_gas_type == 3                                                                           )
	      || ( char_I_current_gas_type == 0                                                                           )
	      || ( (unsigned char)((real_pres_respiration - pres_surface) * BAR_TO_METER - 1.9) < char_O_first_deco_depth )
		)
			char_O_deco_info |=  DECO_FLAG;
	else
			char_O_deco_info &= ~DECO_FLAG;


	//---- Compute ppO2 Warnings ------------------------------------------------------------------

	// compute conditional min/max values
	int_ppO2_min = (char_O_main_status & DECO_MODE_LOOP) ? (unsigned int)char_I_ppO2_min_loop : (unsigned int)char_I_ppO2_min;
	int_ppO2_max = (char_O_deco_info   & DECO_FLAG     ) ? (unsigned int)char_I_ppO2_max_deco : (unsigned int)char_I_ppO2_max;

	// get biggest of char_I_ppO2_max / char_I_ppO2_max_deco
	int_ppO2_max_max = ( char_I_ppO2_max_deco > char_I_ppO2_max ) ? char_I_ppO2_max_deco : char_I_ppO2_max;

	// default value for the upper diluent ppO2 warning threshold is the normal upper warning threshold
	int_ppO2_max_dil = int_ppO2_max;

	// when in CCR mode, the upper diluent warning threshold gets adjust according to the current setpoint
	if( (char_O_main_status & DECO_MODE_MASK) == DECO_MODE_CCR )
	{
		overlay unsigned int max_dil;

		//  The upper diluent ppO2 threshold is ppO2_GAP_TO_SETPOINT below the setpoint...
		// (the condition protects from negative numbers which would cause a wrap-around in unsigned integers)
		max_dil = (char_I_const_ppO2 > ppO2_GAP_TO_SETPOINT) ? (unsigned int)(char_I_const_ppO2 - ppO2_GAP_TO_SETPOINT) : 0;

		// ...but never above int_ppO2_max.
		if( max_dil < int_ppO2_max ) int_ppO2_max_dil = max_dil;

		// We do not need to guard int_ppO2_max_dil against becoming lower than char_I_ppO2_min because the check
		// against char_I_ppO2_min is done first and will then raise a low warning and inhibit further checks.
	}

	// check for safe range of pure oxygen
	     if ( int_O_O2_ppO2       >=               int_ppO2_max     ) int_O_O2_ppO2       |= INT_FLAG_WARNING + INT_FLAG_HIGH;

	// check for safe range of breathed gas
	     if ( int_O_breathed_ppO2 <=               int_ppO2_min     ) int_O_breathed_ppO2 |= INT_FLAG_WARNING + INT_FLAG_LOW;
	else if ( int_O_breathed_ppO2 >=               int_ppO2_max_max ) int_O_breathed_ppO2 |= INT_FLAG_WARNING + INT_FLAG_HIGH;
	else if ( char_O_deco_info    &                DECO_FLAG        ) ; // no attention generated in deco mode
	else if ( char_O_main_status  &                DECO_MODE_LOOP   ) ; // no attention generated in loop modes
	else if ( int_O_breathed_ppO2 >= (unsigned int)char_I_ppO2_max  ) int_O_breathed_ppO2 |= INT_FLAG_ATTENTION;

	// check for safe range of pure diluent
	     if ( int_O_pure_ppO2     <= (unsigned int)char_I_ppO2_min  ) int_O_pure_ppO2     |= INT_FLAG_WARNING + INT_FLAG_LOW;
	else if ( int_O_pure_ppO2     >=               int_ppO2_max     ) int_O_pure_ppO2     |= INT_FLAG_WARNING + INT_FLAG_HIGH;
	else if ( int_O_pure_ppO2     >=               int_ppO2_max_dil ) int_O_pure_ppO2     |= INT_FLAG_ATTENTION;

	// check for safe range of calculated pSCR loop gas
	     if ( int_O_pSCR_ppO2     <=               int_ppO2_min     ) int_O_pSCR_ppO2     |= INT_FLAG_WARNING + INT_FLAG_LOW;
	else if ( int_O_pSCR_ppO2     >=               int_ppO2_max     ) int_O_pSCR_ppO2     |= INT_FLAG_WARNING + INT_FLAG_HIGH;


#ifdef _rx_functions

	//---- Process Pressure Readings (OSTC TR only) -----------------------------------------------

	// only for OSTC TR model with TR functions enabled
	if( char_O_main_status & DECO_TR_FUNCTIONS )
	{
		// pressure warnings for reading 1, but only if enabled and pressure value available
		if( (char_I_pressure_gas[0] > 0) && !(int_IO_pressure_value[0] & INT_FLAG_NOT_AVAIL) )
		{
			overlay unsigned int pressure_value = int_IO_pressure_value[0] & ~INT_FLAG_OUTDATED;

			if( (char_I_pressure_gas[0] < 6 ) && !(int_O_pressure_need[0] & INT_FLAG_NOT_AVAIL) )
			{
				// not a dil and need available: warning & attention by need
				     if( pressure_value <= int_O_pressure_need[0])
				         int_IO_pressure_value[0] |= INT_FLAG_WARNING;
				else if( pressure_value <= int_O_pressure_need[0] + int_O_pressure_need[0] / 2 )
				         int_IO_pressure_value[0] |= INT_FLAG_ATTENTION;
			}
			else
			{
				// a dil or need not available: warning & attention by fixed thresholds
				if     ( pressure_value <= PRESSURE_LIMIT_WARNING   ) int_IO_pressure_value[0] |= INT_FLAG_WARNING;
				else if( pressure_value <= PRESSURE_LIMIT_ATTENTION ) int_IO_pressure_value[0] |= INT_FLAG_ATTENTION;
			}
		}

		// pressure warnings for reading 2, but only if enabled and pressure value available
		if( (char_I_pressure_gas[1] > 0) && !(int_IO_pressure_value[1] & INT_FLAG_NOT_AVAIL) )
		{
			overlay unsigned int pressure_value = int_IO_pressure_value[1] & ~INT_FLAG_OUTDATED;

			if( (char_I_pressure_gas[1] < 6 ) && !(int_O_pressure_need[1] & INT_FLAG_NOT_AVAIL) )
			{
				// not a dil and need available: warning & attention by need
				     if( pressure_value <= int_O_pressure_need[1])
				         int_IO_pressure_value[1] |= INT_FLAG_WARNING;
				else if( pressure_value <= int_O_pressure_need[1] + int_O_pressure_need[1] / 2 )
				         int_IO_pressure_value[1] |= INT_FLAG_ATTENTION;
			}
			else
			{
				// a dil or need not available: warning & attention by fixed thresholds
				     if( pressure_value <= PRESSURE_LIMIT_WARNING   ) int_IO_pressure_value[1] |= INT_FLAG_WARNING;
				else if( pressure_value <= PRESSURE_LIMIT_ATTENTION ) int_IO_pressure_value[1] |= INT_FLAG_ATTENTION;
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
		int_O_sac_rate = 0 + INT_FLAG_NOT_AVAIL;

		// get a copy of the current absolute pressure
		pres_respiration_sac = real_pres_respiration;

		// set threshold for SAC rate attention
		max_sac_rate = (char_O_deco_info & DECO_FLAG) ? char_I_deco_usage : char_I_bottom_usage;

		// char_I_deco_usage / char_I_bottom_usage are in l/min, max_sac_rate is in 0.1 l/min
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
			char_O_deco_info &= ~IND_DOUBLE_SWITCH_FLAG;

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
				reading1_tanksize = char_I_tank_size[reading1_gas-1];
				reading2_tanksize = char_I_tank_size[reading2_gas-1];

				// set mode to calculate SAC on the reading with the higher absolute drop
				char_I_SAC_mode = (reading1_drop * reading1_tanksize > reading2_drop * reading2_tanksize) ? 1 : 2;

				// compute switch advice if pressure (in 0.1 bar) of tank breathed from is
				// more than char_I_max_pres_diff (in bar) below pressure of the other tank.
				if( char_I_SAC_mode == 1 )
				{
					// breathing from reading 1, switch advice if pressure on reading 1 lower than on 2
					if( (reading1_press + 10*char_I_max_pres_diff) <= reading2_press )
						char_O_deco_info |= IND_DOUBLE_SWITCH_FLAG;
				}
				else
				{
					// breathing from reading 2, switch advice if pressure on reading 2 lower than on 1
					if( (reading2_press + 10*char_I_max_pres_diff) <= reading1_press )
						char_O_deco_info |= IND_DOUBLE_SWITCH_FLAG;
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
				reading_tanksize = char_I_tank_size[reading_gas-1];

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
						int_O_sac_rate = 999 + INT_FLAG_ATTENTION;
					}
					else
					{
						// convert float to integer
						int_O_sac_rate = (unsigned short)(float_sac + 0.5);

						// set attention flag if exceeding SAC threshold, but only if pressure drop is not outdated
						if( !(int_I_pressure_drop[reading_index] & INT_FLAG_OUTDATED) )
						if( int_O_sac_rate >= max_sac_rate )
						{
							int_O_sac_rate |= INT_FLAG_ATTENTION;
						}
					}
				}
				else
				{
					// pressure drop is out of range, so SAC will be set out of range, too
					int_O_sac_rate = 999 + INT_FLAG_ATTENTION;
				}

				// copy outdated flag from int_I_pressure_drop to int_O_sac_rate
				if( int_I_pressure_drop[reading_index] & INT_FLAG_OUTDATED )
				{
					int_O_sac_rate |= INT_FLAG_OUTDATED;
				}
			}
		}
	} // TR functions

#endif


	//---- End of Computations for the real Tissues -----------------------------------------------
	//
	//=============================================================================================
	//
	//---- Begin of Computations for Ascent and Decompression -------------------------------------

	// branch to the code for the current phase the deco calculations are in, i.e.
	// toggle between calculating NDL (remaining bottom time), deco stops, and results
	switch( char_O_deco_status & DECO_STATUS_MASK )
	{
		overlay unsigned char i;

	default:

	case DECO_STATUS_INIT: //---- At surface: Start a new dive ---------------------

		// clear the internal stops table from remains lasting from the previous dive or deco calculator run
		clear_deco_table();

		// publish the cleared stops table to the display functions
		publish_deco_table();

		// clear the gas needs table
		for( i = 0; i < NUM_GAS; ++i )
		{
			int_O_ascent_volumes[i]   = 0;
			int_O_ascent_pres_need[i] = 0 + INT_FLAG_ZERO;
		}

		// safety limits to prevent eventual infinite looping (bricking the OSTC)
		if( char_I_ascent_speed            <  5 ) char_I_ascent_speed            =  5;	// min.  5 m/min
		if( char_I_deco_distance           > 20 ) char_I_deco_distance           = 20;	// max. 20 dm (= 2 m)
		if( char_I_desaturation_multiplier < 50 ) char_I_desaturation_multiplier = 50;	// min. 50 %

		// initialize values that are constant during the course of the dive
		float_ascent_speed            = 1.00 * char_I_ascent_speed;						// in meter/minute
		float_deco_distance           = 0.01 * char_I_deco_distance;					// in bar
		float_desaturation_multiplier = 0.01 * char_I_desaturation_multiplier;			// as factor, 1.0 = 100%
		float_saturation_multiplier   = 0.01 * char_I_saturation_multiplier;			// as factor, 1.0 = 100%

		// initialize values that will be recalculated later on periodically
		char_O_nullzeit               = 0;		// reset NDL time for the normal plan
		char_O_alternate_nullzeit     = 0;		// reset NDL time for the alternative plan
		int_O_ascenttime              = 0;		// reset ascent time for the normal plan
		int_O_alternate_ascenttime    = 0;		// reset ascent time for the alternative plan
		char_O_deco_warnings          = 0;		// reset all deco warnings
		char_O_deco_info              = 0;		// reset all deco infos
		deco_tissue_vector            = 0;		// reset tissue deco vector
		IBCD_tissue_vector            = 0;		// reset tissue IBCD vector
		NDL_lead_tissue_norm          = 0;		// reset first tissue to look at during NDL calculation
		NDL_lead_tissue_alt           = 0;		// reset first tissue to look at during NDL calculation

		// tag desaturation time as invalid (it will not be computed during a dive)
		int_O_desaturation_time       = 65535;

		// initialize values for first stop depth and GF slope
		low_depth_norm                = 0.0;	// reset depth of first stop in normal      plan
		locked_GF_step_norm           = 0.0;	// reset GF slope            in normal      plan
		low_depth_alt                 = 0.0;	// reset depth of first stop in alternative plan
		locked_GF_step_alt            = 0.0;	// reset GF slope            in alternative plan

		// initialize CNS values
		int_O_normal_CNS_fraction     = int_O_alternate_CNS_fraction = int_O_CNS_fraction;

		//
		// --> code execution continues in state DECO_STATUS_START
		//

	case DECO_STATUS_START: //---- Start a new deco calculation cycle --------------

		// clear the internal(!) stops table
		clear_deco_table();

		// initialize the simulated tissues with the current state of the real tissues
		for( i = 0; i < NUM_COMP; i++ )
		{
			sim_pres_tissue_N2[i] = pres_tissue_N2[i];
			sim_pres_tissue_He[i] = pres_tissue_He[i];
		}

		// initialize the simulated CNS value with the current CNS of the real tissues
		sim_CNS_fraction = CNS_fraction;

		// initialize the simulated depth with the current depth (in absolute pressure)
		sim_pres_respiration = real_pres_respiration;

		// Lookup the current gas and store it also as the first gas used.
		// This gas will be used until gas_find_better() is invoked and finds
		// a better gas to switch to.
		gas_find_current();

		// Setup the calculation ratio's for N2, He and O2 (sim_N2/He/_O2_ratio).
		// These ratios will be used and remain valid to use until a gas switch
		// is done. Thus, if a call to gas_find_better() has found a better gas,
		// gas_set_ratios() needs to be called again.
		gas_set_ratios();

		// Calculate the effect of extended bottom time due to delayed ascent,
		// if requested.
		if( char_O_deco_status & DECO_ASCENT_DELAYED )
		{
			// program interval on simulated tissues (flag bit 7 = 0)
			tissue_increment = char_I_extra_time;

			// calculate ppO2, ppN2 and ppHe from sim_N2/real_He_ratio
			calc_alveolar_pressures();

			// update the tissues
			calc_tissues();

			// update the CNS value
			calc_CNS();
		}

		// Calculate the remaining no decompression limit (NDL) time. calc_NDL_time()
		// is very fast in detecting if being beyond NDL, so there is enough time left
		// in this phase to do the initial ascent calculation if found to be outside NDL.
		calc_NDL_time();

		if( NDL_time == 0 )
		{
			// calculate ascent to first stop using the set ascent rate,
			// re-calculating the tissues and limits every minute along the ascent.
			calc_ascent_to_first_stop();

			// continue in next cycle(s) with calculating the initial ascent and stops
			char_O_deco_status &= ~DECO_STATUS_MASK;
			char_O_deco_status |=  DECO_STATUS_STOPS;
		}
		else
		{
			// within NDL - continue in next cycle with gathering all results
			char_O_deco_status &= ~DECO_STATUS_MASK;
			char_O_deco_status |=  DECO_STATUS_RESULTS;
		}

		break;


	case DECO_STATUS_STOPS: //---- Calculate Stops ---------------------------------

		// calculate the stops
		calc_hauptroutine_calc_deco();

		// calc_hauptroutine_calc_deco() iterates in this phase as long as it is
		// calculating the stops. Once done, it will set the status to doing the
		// results gathering.

		break;


	case DECO_STATUS_RESULTS: //--- Gather Results ---------------------------------

		// if in normal plan, publish the stops table
		if( !(char_O_deco_status & DECO_PLAN_ALTERNATE) )
		{
			// publish the stops table to the display functions
			publish_deco_table();

			// When entering deco and the ceiling depth becomes > 0 but the
			// deco calculation reveals no distinct deco stop yet because
			// the deco obligation will vanish during the ascent, create an
			// artificial stop to signal that expedite surfacing ("popping
			// up") is not allowed anymore.
			if( char_O_first_deco_depth == 0 )		// simulation  reveals no stop required
			if( int_O_ceiling           >  0 )		// real status reveals a ceiling
			{
				// set a pro forma stop at 3 meters
				char_O_first_deco_depth = 3;

				// set a stop time of 0 minute, this will be displayed as "..'"
				char_O_first_deco_time  = 0;
			}
		}

		// The current depth is needed by calc_ascenttime() and gas_volumes(). As we
		// don't want it to be calculated multiple times, it's done here on stockpile.
		char_bottom_depth = (unsigned char)((real_pres_respiration - pres_surface) * BAR_TO_METER + 0.5);

		// results to publish depend whether within NDL or in deco
		if( NDL_time )
		{
			//---- within NDL ----------------------------------------------

			// check which plan we are on
			if( char_O_deco_status & DECO_PLAN_ALTERNATE )
			{
				//---- alternate dive plan ---------------------------------

				// output NDL time
				char_O_alternate_nullzeit  = NDL_time;

				// clear ascent time
				int_O_alternate_ascenttime = 0;

				// As we are in no stop, CNS at end of dive is more or less
				// the same CNS as we have right now.
				int_O_alternate_CNS_fraction = int_O_CNS_fraction;
			}
			else
			{
				//---- normal dive plan ------------------------------------

				// output NDL time
				char_O_nullzeit = NDL_time;

				// clear ascent time
				int_O_ascenttime = 0;

				// As we are in no stop, CNS at end of dive is more or less
				// the same CNS as we have right now.
				int_O_normal_CNS_fraction = int_O_CNS_fraction;
			}
		} // NDL
		else
		{
			//---- in DECO -------------------------------------------------

			// calculate the ascent time
			calc_ascenttime();

			// check which plan we are on
			if( char_O_deco_status & DECO_PLAN_ALTERNATE )
			{
				//---- alternative plan ----------------------------------------------------

				// clear the NDL time
				char_O_alternate_nullzeit = 0;

				// export the ascent time
				int_O_alternate_ascenttime = ascent_time;

				// convert the CNS value to integer for export
				convert_sim_CNS_for_display();

				// export the integer CNS value
				int_O_alternate_CNS_fraction = int_sim_CNS_fraction;

			} // alternative plan
			else
			{
				//---- normal plan ---------------------------------------------------------

				// clear the NDL time
				char_O_nullzeit  = 0;

				// export the ascent time
				int_O_ascenttime = ascent_time;

				// convert the CNS value to integer for export
				convert_sim_CNS_for_display();

				// export the integer CNS value
				int_O_normal_CNS_fraction = int_sim_CNS_fraction;

			} // normal plan
		} // NDL / DECO


		// Check if deco obligation is steady or decreasing. This works only when an alternative plan is enabled and
		// if it is not a bailout plan, thus DECO_BAILOUT_MODE must not be set while doing the DECO_PLAN_ALTERNATE.
		if( (char_O_deco_status & DECO_PLAN_ALTERNATE) && !(char_O_deco_status & DECO_BAILOUT_MODE) )
		{
			// Set DECO_DECREASING flag when fTTS < TTS and DECO_STEADY flag when fTTS = TTS.
			     if ( int_O_alternate_ascenttime <  int_O_ascenttime ) char_O_deco_info |= DECO_DECREASING;
			else if ( int_O_alternate_ascenttime == int_O_ascenttime ) char_O_deco_info |= DECO_STEADY;
		}

		// Clear DECO_DECREASING flag when fTTS >= TTS and DECO_STEADY flag when fTTS > TTS.
		// This works in any planning mode combination.
		     if ( int_O_alternate_ascenttime >  int_O_ascenttime ) char_O_deco_info &= ~(DECO_DECREASING + DECO_STEADY);
		else if ( int_O_alternate_ascenttime == int_O_ascenttime ) char_O_deco_info &= ~(DECO_DECREASING              );

		// If requested, calculate the required gas volumes and tank pressures at the end of the dive.
		if( char_O_deco_status & DECO_VOLUME_CALCULATE )
		{
			// When in bailout mode and within NDL, find the gas changes along the ascent and put
			// them into the stops table for use by gas_volumes(). The stops table can be "polluted"
			// by now because the table has already been published in "clean" state before.
			if( (NDL_time) && ( char_O_deco_status & DECO_BAILOUT_MODE ) )
			{
				// find the gas changes and put them into the stops table
				find_NDL_gas_changes();
			}

			// calculate the required gas volumes and tank pressures
			gas_volumes();
		}

		// set the computation cycle to finished
		char_O_deco_status &= ~DECO_STATUS_MASK;

		// set flag indicating that deco calculation has been completed
		if( char_O_deco_status & DECO_PLAN_ALTERNATE ) char_O_main_status |= DECO_COMPLETED_ALT;
		else                                           char_O_main_status |= DECO_COMPLETED_NORM;


		break;

	} // switch
}

//////////////////////////////////////////////////////////////////////////////
// calc_hauptroutine_data_input
//
// Set all C-code dive parameters from their ASM-code values.
// Detect gas change condition.
//
void calc_hauptroutine_data_input(void)
{
	overlay float IG_ratio;

	// safety limits to prevent eventual infinite looping (bricking the OSTC)
	if( int_I_pres_surface     < 500) int_I_pres_surface     = 500;		// min. surface     pressure = 500 mbar
	if( int_I_pres_respiration < 500) int_I_pres_respiration = 500;		// min. respiration pressure = 500 mbar

	// safe-guard further parameters to protect the tissue-flag
	if( char_I_sim_advance_time > 127 ) char_I_sim_advance_time = 127;
	if( char_I_extra_time       > 127 ) char_I_extra_time       = 127;
	if( char_I_gas_change_time  >  99 ) char_I_gas_change_time  =  99;

	// get the current pressures
	pres_surface          = 0.001  * int_I_pres_surface;
	real_pres_respiration = 0.001  * int_I_pres_respiration;

	// N2 tissue pressure at surface equilibrium, used for tissue graphics scaling
	N2_equilibrium   = 0.7902 * (pres_surface - ppWater);

	// read the GF settings (they may have been switch between GF/aGF)
	GF_high  = 0.01 * char_I_GF_High_percentage;
	GF_low   = 0.01 * char_I_GF_Low_percentage;
	GF_delta = GF_high - GF_low;

	// get the currently breathed gas mixture
	real_O2_ratio = 0.01 * char_I_O2_ratio;
	real_He_ratio = 0.01 * char_I_He_ratio;

	// inert gas ratio (local helper variable)
	IG_ratio = 1.00 - real_O2_ratio;

	// N2 ratio
	real_N2_ratio  = IG_ratio - real_He_ratio;

	// compute values for ppO2 drop in pSCR loop
	real_pSCR_drop = IG_ratio * float_pSCR_factor;
}


//////////////////////////////////////////////////////////////////////////////
// Compute stops
//
// Note: because this can be very long, break on 16 iterations, or after
//       512 ms, whichever comes first. Set state to DECO_STATUS_RESULTS
//       when finished, or keep DECO_STATUS_STOPS when needing to continue.
//
void calc_hauptroutine_calc_deco(void)
{
	overlay unsigned char loop;

	for( loop = 0; loop < 16; ++loop )
	{
		// limit execution time to 512 ms using timer 5
		if( tmr5() & (512*32) ) break;

		// calc_nextdecodepth()
		//
		// INPUT  sim_pres_respiration : current depth in absolute pressure
		// OUTPUT sim_depth_limit      : depth of next stop in meters      (if RETURN = true)
		//                               next depth without need of a stop (if RETURN = false)
		// RETURN true if a stop is needed, else false
		//
		// The function manages gas changes by itself, including priming
		// the deco stop with the configured gas change time.
		//
		if( calc_nextdecodepth() )
		{
			// this check should not be needed as in this case the RETURN value will be false
			if( sim_depth_limit == 0 ) goto Surface;

			//---- stop required at sim_depth_limit ----------------------

			// convert stop depth in meters to absolute pressure
			sim_pres_respiration = sim_depth_limit * METER_TO_BAR + pres_surface;

			// Add one minute to the current stop, or add a new stop,
			// or abort deco calculation if the deco table is full.
			if( !update_deco_table(1) ) goto Surface;
		}
		else
		{
			//---- no stop required --------------------------------------

			// convert next depth (without stop requirement) to absolute pressure
			sim_pres_respiration = sim_depth_limit * METER_TO_BAR + pres_surface;

			// finish deco calculation if surface is reached
			if( sim_pres_respiration <= pres_surface )
			{
Surface:
				// continue with gathering all results in the next calculation phase
				char_O_deco_status &= ~DECO_STATUS_MASK;
				char_O_deco_status |=  DECO_STATUS_RESULTS;

				return;
			}
		}

		//---- as one minute as passed now, update the tissues -----------

		// program 1 minute interval on simulated tissues
		tissue_increment = 1;

		// compute current ppO2, ppN2 and ppHe
		calc_alveolar_pressures();

		// update the tissues
		calc_tissues();

		// update the CNS value
		calc_CNS();
	}
}


//////////////////////////////////////////////////////////////////////////////
// Find gas changes on an NDL ascent
//
// This function is a variant of calc_ascent_to_first_stop() to be used solely
// for finding the gas changes in an OC bailout ascent that is within NDL.
//
// Input    : char_bottom_depth : depth at which the ascent starts, in meters
//
// Output   : gas change stops put into stops table
//
// Destroyed: sim_depth_limit
//            sim_gas_current
//            sim_gas_current_depth
//
void find_NDL_gas_changes(void)
{
	overlay unsigned char old_depth_limit;

	// set gas to start with
	gas_find_current();

	// loop in ascending until reaching a depth of 3 meters, no gas switches considered thereafter
	for( sim_depth_limit = char_bottom_depth; sim_depth_limit >= 3; )
	{
		// memorize the depth we came from
		old_depth_limit = sim_depth_limit;

		// ascent - initially in steps of 10 m, then slowing down to 1 m steps to not miss a O2 gas
		if( sim_depth_limit > 10 ) sim_depth_limit -= 10;
		else                       sim_depth_limit -=  1;

		// check if there is a better gas to switch to
		if( gas_find_better() )
		{
			// adjust sim_depth_limit to the gas change depth, but not deeper than the depth we came from
			sim_depth_limit = (sim_gas_current_depth < old_depth_limit) ? sim_gas_current_depth : old_depth_limit;

			// create a stop for the gas change in the stops table
			update_deco_table(char_I_gas_change_time);
		}
	} // for()
}


//////////////////////////////////////////////////////////////////////////////
// Calculate ascent to first deco stop
//
// Modified : sim_pres_respiration : current depth in ascent and deco simulation, in bar absolute pressure
//
// Output   : sim_depth_limit      : depth in meters of the 1st stop, if a stop is found
//
// Destroyed: tissue_increment     : tissue and update period selector
//
void calc_ascent_to_first_stop(void)
{
	overlay float         old_pres_respiration;
	overlay unsigned char fast = 1;					// 0: 2 seconds step, 1: 1 minute step

	// target the simulated tissues
	tissue_increment = 0;

	// loop until first deco stop or the surface is reached
	for(;;)
	{
		// memorize depth in absolute pressure we came from
		old_pres_respiration = sim_pres_respiration;

		// try ascending 1 full minute (fast) or 2 seconds (!fast)
		if( fast ) sim_pres_respiration -=          float_ascent_speed * METER_TO_BAR;	// 1 min at float_ascent_speed ( 5 .. 10  m)
		else       sim_pres_respiration -= 0.0333 * float_ascent_speed * METER_TO_BAR;	// 2 sec at float_ascent_speed (17 .. 33 cm)

		// but don't go over surface
		if( sim_pres_respiration < pres_surface ) sim_pres_respiration = pres_surface;

		// compute ceiling of the simulated tissues
		if( char_I_deco_model != 0 ) calc_limit(GF_low);
		else                         calc_limit(1.0);

		// did we overshoot the ceiling?
		if( sim_pres_respiration < (ceiling + pres_surface) )
		{
			// YES - back to memorized depth
			sim_pres_respiration = old_pres_respiration;

			// switch to 2 seconds ascent if not yet in, else done
			if( fast )
			{
				fast = 0;		// ascent with 2 seconds ascent steps
				continue;
			}
			else
			{
				break;			// done, stop required
			}
		}

		// if code execution passes along here, we did not overshoot the ceiling

		// did we reach the surface? If yes, deco has vanished, no stop required, done.
		if( sim_pres_respiration == pres_surface ) break;

		// depth in meters where we are now (no round-up)
		sim_depth_limit = (unsigned char)((sim_pres_respiration - pres_surface) * BAR_TO_METER);

		// program interval on simulated tissues:
		// fast = 1 -> 1 minute,
		// fast = 0 -> 2 seconds
		tissue_increment = fast;

		// Check if there is a better gas to switch to, but only if bailout mode is enabled.
		// If yes, introduce a stop for the gas change.
		if( char_O_deco_status & DECO_BAILOUT_MODE )
		if( gas_find_better() )
		{
			overlay unsigned char old_depth_limit;

			// set the new calculation values for N2, He and O2
			gas_set_ratios();

			// add gas change time: a gas change time of
			//    0 minutes will keep the 1 minute / 2 seconds interval selection,
			// >= 1 minute  will add the the 1 minute interval but overrule a 2 seconds interval.
			tissue_increment += char_I_gas_change_time;

			// depth in meters we came from
			old_depth_limit = (unsigned char)((old_pres_respiration - pres_surface) * BAR_TO_METER);

			// adjust sim_depth_limit to the gas change depth, but not deeper than the depth we came from
			sim_depth_limit = (sim_gas_current_depth < old_depth_limit) ? sim_gas_current_depth : old_depth_limit;

			// Adjust the depth for the tissue update to the current depth. In case of fast mode,
			// this imposes that the ascent from the 'old_pres_respiration' depth to this depth
			// took one minute although we might have only ascended one or two meters...
			sim_pres_respiration = sim_depth_limit * METER_TO_BAR + pres_surface;

			// create a stop for the gas change in the stops table
			update_deco_table(char_I_gas_change_time);
		}

		// omit the 2 seconds interval updates (do only updates for >= 1 minute)
		// It's a trade-off between computational effort and accuracy...
		if( tissue_increment )
		{
			// compute ppO2, ppN2 and ppHe for current depth from sim_pres_respiration
			calc_alveolar_pressures();

			// update the tissues
			calc_tissues();

			// update the CNS value
			calc_CNS();
		}

	} // for()
}


//////////////////////////////////////////////////////////////////////////////
// calc_tissues
//
// INPUT:    ppN2                          : partial pressure of inspired N2
//           ppHe                          : partial pressure of inspired He
//           tissue_increment              : integration time and tissue selector (real or simulated)
//
// MODIFIED: pres_tissue_N2[]              : tissue N2 pressures (in real tissues context)
//           pres_tissue_He[]              : tissue He pressures (in real tissues context)
//           sim_pres_tissue_N2[]          : tissue N2 pressures (in simulated tissues context)
//           sim_pres_tissue_He[]          : tissue He pressures (in simulated tissues context)
//
// OUTPUT:   char_O_tissue_N2_saturation[] : tissue N2 pressures scaled for display purpose (in real tissues context)
//           char_O_tissue_He_saturation[] : tissue He pressures scaled for display purpose (in real tissues context)
//
static void calc_tissues()
{
	overlay float			temp_tissue_N2;
	overlay float			temp_tissue_He;
	overlay unsigned char	period;
	overlay unsigned char	i;


	assert( 0.00 <= ppN2 && ppN2 < 11.2 );  // 80% N2 at 130m
	assert( 0.00 <= ppHe && ppHe < 12.6 );  // 90% He at 130m


	for( ci=0; ci < NUM_COMP; ci++ )		// iterate through all compartments
	{
		i = tissue_increment & TIME_MASK;	// extract number of minutes to do    (if i > 0)
											// or if one 2 second period is to do (if i = 0)

		if( i == 0 )						// check if we shall do one 2-seconds period
		{
			read_Buhlmann_times(0);			// YES, program coefficients for a 2 seconds period
			period = 1;						//      set period length (in cycles)
			i      = 1;						//      and one cycle to do
		}
		else if( i > 9 )					// check if we can start with 10 minutes periods
		{
			read_Buhlmann_times(2);			// YES, program coefficients for 10 minutes periods
			period = 10;					//      set period length (in cycles) to ten
		}
		else								// we shall do 1 to 9 minutes
		{
			read_Buhlmann_times(1);			//      program coefficients for 1 minute periods
			period = 1;						//      set period length (in cycles) to one
		}

		do
		{
			//---- N2 -------------------------------------------------------------------------------

			temp_tissue = (tissue_increment & TISSUE_FLAG) ? pres_tissue_N2[ci] : sim_pres_tissue_N2[ci];

			temp_tissue = (ppN2 - temp_tissue) * var_N2_e;

			temp_tissue_safety();

			if( tissue_increment & TISSUE_FLAG )
			{
				temp_tissue_N2      = temp_tissue;
				pres_tissue_N2[ci] += temp_tissue;
			}
			else
			{
				sim_pres_tissue_N2[ci] += temp_tissue;
			}


			//---- He -------------------------------------------------------------------------------

			temp_tissue = (tissue_increment & TISSUE_FLAG) ? pres_tissue_He[ci] : sim_pres_tissue_He[ci];

			temp_tissue = (ppHe - temp_tissue) * var_He_e;

			temp_tissue_safety();

			if( tissue_increment & TISSUE_FLAG )
			{
				temp_tissue_He      = temp_tissue;
				pres_tissue_He[ci] += temp_tissue;
			}
			else
			{
				sim_pres_tissue_He[ci] += temp_tissue;
			}

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
		if( tissue_increment & TISSUE_FLAG )
		{
			// net tissue balance
			temp_tissue = temp_tissue_N2 + temp_tissue_He;

			// check tissue on-/off-gassing and IBCD with applying a threshold of +/-HYST
			//
			if      ( temp_tissue < -HYST )				// check if the tissue is off-gassing
			{
				deco_tissue_vector |=  (1 << ci);		// tag tissue as being in decompression
				IBCD_tissue_vector &= ~(1 << ci);		// tag tissue as not experiencing mentionable IBCD
			}
			else if ( temp_tissue > +HYST )				// check if the tissue in on-gassing
			{
				deco_tissue_vector &= ~(1 << ci);		// tag tissue as not being in decompression

				if(    ((temp_tissue_N2 > 0.0) && (temp_tissue_He < 0.0))		// check for counter diffusion
				    || ((temp_tissue_N2 < 0.0) && (temp_tissue_He > 0.0)) )
				{
					IBCD_tissue_vector |= (1 << ci);	// tag tissue as experiencing mentionable IBCD
				}
			}


			// keep the saturating / desaturating flags from last invocation
			char_O_tissue_N2_saturation[ci] &= 128;
			char_O_tissue_He_saturation[ci] &= 128;

			// flip the flags applying a hysteresis of HYST (actual value: see #define of HYST)
				 if( temp_tissue_N2 > +HYST ) char_O_tissue_N2_saturation[ci] = 128; // set flag for tissue pressure is increasing
			else if( temp_tissue_N2 < -HYST ) char_O_tissue_N2_saturation[ci] =   0; // clear flag (-> tissue pressure is decreasing)

				 if( temp_tissue_He > +HYST ) char_O_tissue_He_saturation[ci] = 128; // set flag for tissue pressure is increasing
			else if( temp_tissue_He < -HYST ) char_O_tissue_He_saturation[ci] =   0; // clear flag (-> tissue pressure is decreasing)


			// For N2 tissue display purpose:
			// Scale tissue press so that saturation in 70m on AIR gives a value of approx. 80.
			// The surface steady-state tissue loading of [0.7902 * (real_pres_respiration - ppWater)] bar
			// gives then a 10. If N2 is completely washed out of the tissue, result will be 0.
			// This scaling is adapted to the capabilities of the tissue graphics in the custom views.
			temp_tissue = (pres_tissue_N2[ci] / N2_equilibrium) * 10;

			// limit to 127 to leave space for sat/desat flag
			if (temp_tissue > 127) temp_tissue = 127;

			// export as integer
			char_O_tissue_N2_saturation[ci] += (unsigned char)temp_tissue;


			// For H2 tissue display purpose:
			// Scale tissue press so that saturation in 120m on TMX 10/70 gives a value of approx. 70.
			// With no He in a tissue, result will be 0.
			// This scaling is adapted to the capabilities of the tissue graphics in the custom views.
			temp_tissue = pres_tissue_He[ci] * 7.7;

			// limit to 127 to leave space for sat/desat flag
			if (temp_tissue > 127) temp_tissue = 127;

			// export as integer
			char_O_tissue_He_saturation[ci] += (unsigned char)temp_tissue;
		} //if

	} // for
}

//////////////////////////////////////////////////////////////////////////////
// calc_limit
//
// Input:
//        tissue_increment       : selector for context: real or simulated tissues
//        sim_pres_tissue_N2/_He : tissue pressures (used in simulated tissues context)
//        pres_tissue_N2/_He     : tissue pressures (used in real      tissues context)
//
// Output:
//        lead_supersat          : supersaturation of the leading tissue, 1.0 = 100%
//        ceiling                : ceiling in bar relative pressure
//
// Modified:
//        char_O_deco_warnings   : for IBCD, microbubbles and outside warning (only in real tissues context)
//
static void calc_limit(PARAMETER float GF_parameter)
{
	overlay float lead_tissue_limit = 0.0;


	// set leading tissue number to not yet computed
	lead_number = 0;

	// initialize leading tissue supersaturation value to null
	lead_supersat  = 0.0;

	// check context
	if( tissue_increment & TISSUE_FLAG )
	{
		// clear IBCD, microbubbles and outside warning flags (locked warnings will be preserved)
		char_O_deco_warnings &= ~(DECO_WARNING_IBCD + DECO_WARNING_MBUBBLES + DECO_WARNING_OUTSIDE + DECO_ATTENTION_OUTSIDE );
	}

	// loop over all tissues
	for( ci = 0; ci < NUM_COMP; ci++ )
	{
		overlay float pres_min;

		// get the tissue pressures
		if( tissue_increment & TISSUE_FLAG )
		{
			// context is real tissues
			calc_pres_tissue_N2 = pres_tissue_N2[ci];
			calc_pres_tissue_He = pres_tissue_He[ci];
		}
		else
		{
			// context is simulated tissues
			calc_pres_tissue_N2 = sim_pres_tissue_N2[ci];
			calc_pres_tissue_He = sim_pres_tissue_He[ci];
		}

		// overall tissue pressure
		pres_tissue = calc_pres_tissue_N2 + calc_pres_tissue_He;

		// get the coefficients for tissue ci
		read_Buhlmann_coefficients();

		// adopt a and b coefficients to current N2/He ratio inside the tissue
		adopt_Buhlmann_coefficients();

		// calculate minimum ambient pressure that the tissue can withstand according to straight Buhlmann
		pres_min = (pres_tissue - var_N2_a) * var_N2_b;

		// next calculations are only relevant when invoked on the real tissues
		if( tissue_increment & TISSUE_FLAG )
		{
			overlay float supersat;
			overlay float baseline_threshold;

			// calculate current supersaturation value (1.0 = 100%) of this tissue according to straight Buhlmann
			supersat = (pres_tissue - real_pres_respiration) / (pres_tissue - pres_min);

			// check if tissue is in supersaturation
			if( supersat > 0.0 )
			{
				// memorize highest supersaturation found
				if( supersat > lead_supersat ) lead_supersat = supersat;

				// tissue-dependent baseline threshold for micro bubbles and outside warnings
				baseline_threshold = 0.02 * ci + 1.0;

				// micro bubbles warning: supersaturation > baseline threshold
				if( supersat > baseline_threshold )
					char_O_deco_warnings |= (DECO_WARNING_MBUBBLES + DECO_WARNING_MBUBBLES_lock);

				// outside warning: supersaturation > baseline threshold + additional 5% margin
				if( supersat > baseline_threshold + 0.05 )
					char_O_deco_warnings |= (DECO_WARNING_OUTSIDE  + DECO_WARNING_OUTSIDE_lock );
			}
		}

		// Apply the Eric Baker's varying gradient factor correction if the GF-Model is selected.
		// Note: the correction factor depends both on GF and b, so that can change which is the
		//       leading tissue...            (this equation [1] is the inverse of equation [2])
		if( char_I_deco_model != 0 ) pres_min =   ( pres_tissue        - (var_N2_a     * GF_parameter) )
		                                        / ( 1.0 - GF_parameter + (GF_parameter / var_N2_b    ) );

		// check if this tissue requires a higher ambient pressure than was found to be needed up to now
		if( pres_min > lead_tissue_limit )
		{
			lead_tissue_limit = pres_min;
			lead_number       = ci;
		}
	} // for


	// compute ceiling for the real tissues in bar relative pressure
	ceiling = lead_tissue_limit - pres_surface;


	// next in real tissue context only
	if( tissue_increment & TISSUE_FLAG )
	{
		// check if the leading tissue is in IBCD condition
		if(    (IBCD_tissue_vector & (1 << lead_number))
		    && ((pres_tissue_N2[lead_number] + pres_tissue_He[lead_number]) > real_pres_respiration) )
		{
			// leading tissue is in IBCD condition and in super-saturation, so issue a warning
			char_O_deco_warnings |= (DECO_WARNING_IBCD + DECO_WARNING_IBCD_lock);
		}
	}
}

//////////////////////////////////////////////////////////////////////////////
// calc_NDL_time
//
// calculation of the remaining bottom time (NDL: no decompression limit)
//
// NOTE: Erik Baker's closed formula works for Nitrox. Trimix adds a second
//       exponential term to the M-value equation, making it impossible to
//       invert. So we have to solve the problem with an iterative approach.
//
// Input:  ppN2
//         ppHe
//
// Output: NDL_time
//
static void calc_NDL_time(void)
{
	overlay unsigned char new_NDL_lead_tissue = 0;
	overlay unsigned char i;


	// initialize NDL_time to 240 minutes
	NDL_time = 240;

	for( i = 0; i < NUM_COMP; i++ )
	{
		overlay unsigned char period		= 10;		// start with iterations of 10 minutes
		overlay unsigned char NDL_tissue;				// loop variable
		overlay float         GF_factor;				// gradient factor to be applied
		overlay float         next_pres_tissue;			// auxiliary variable to cache a calculation result


		// select gradient factor to use
		GF_factor = (char_I_deco_model != 0) ? GF_high : 1.0;

		// the fastest way to find out if already being beyond NDL is to start with
		// the tissue that was the leading one during the last NDL computation...
		ci =  (char_O_deco_status & DECO_PLAN_ALTERNATE) ? (NDL_lead_tissue_alt + i) : (NDL_lead_tissue_norm + i);

		// wrap around after the 16th tissue
		if( ci >= NUM_COMP ) ci -= NUM_COMP;

		// read the loading factors for 10 minute iterations
		read_Buhlmann_times(2);

		// get the tissue pressures for N2 and He
		calc_pres_tissue_N2 = sim_pres_tissue_N2[ci];
		calc_pres_tissue_He = sim_pres_tissue_He[ci];

		// calculate the total pressure tissue
		pres_tissue = calc_pres_tissue_N2 + calc_pres_tissue_He;

		// Simulate an increasing bottom time and check when we hit the NDL.
		// It is not needed to simulate for longer than the already found NDL.
		for( NDL_tissue = 0; NDL_tissue < NDL_time; )
		{
			overlay float pres_limit;
			overlay float delta_pres_tissue_N2;
			overlay float delta_pres_tissue_He;


			// read Buhlmann a and b coefficients for tissue ci, they need to be re-read on each
			// iteration because adopt_Buhlmann_coefficients() twiddles with the N2 coefficients
			read_Buhlmann_coefficients();

			// adopt a and b coefficients to current N2/He ratio inside the tissue
			adopt_Buhlmann_coefficients();

			// compute the maximum tissue pressure allowed to be exposed to an ambient pressure equaling
			// the surface pressure                   (this equation [2] is the inverse of equation [1])
			pres_limit = (1.0 - GF_factor + GF_factor / var_N2_b) * pres_surface + GF_factor * var_N2_a;

			// check if this tissue is already beyond the NDL
			if( pres_tissue > pres_limit)
			{
				// beyond NDL - finish the outer loop, ...
				i = NUM_COMP;

				// ... and finish the inner loop
				break;
			}

			// compute tissue pressure deltas for 10 or 1 minute of time ahead
			delta_pres_tissue_N2 = (ppN2 - calc_pres_tissue_N2) * var_N2_e;
			delta_pres_tissue_He = (ppHe - calc_pres_tissue_He) * var_He_e;

			// apply safety factors to the pressure deltas
			// NDL can be computed while ascending, so we have to check if the tissues is saturating or desaturating
			if( delta_pres_tissue_N2 > 0.0 ) delta_pres_tissue_N2 *= float_saturation_multiplier;
			else                             delta_pres_tissue_N2 *= float_desaturation_multiplier;

			if( delta_pres_tissue_He > 0.0 ) delta_pres_tissue_He *= float_saturation_multiplier;
			else                             delta_pres_tissue_He *= float_saturation_multiplier;

			// simulate off-gassing while going to surface - well, maybe some day we'll do that...
			// delta_pres_tissue_N2 -= exp( ... ascent time ... ppN2...)
			// delta_pres_tissue_He -= exp( ... ascent time ... ppHe...)

			// calculate tissue pressure for given time ahead
			next_pres_tissue = pres_tissue + delta_pres_tissue_N2 + delta_pres_tissue_He;

			// within NDL now, but still within NDL in 10 or 1 minute from now?
			if( next_pres_tissue <= pres_limit )
			{
				// YES - apply the pressure deltas to the tissues
				calc_pres_tissue_N2 += delta_pres_tissue_N2;
				calc_pres_tissue_He += delta_pres_tissue_He;

				// update the overall tissue pressure
				pres_tissue = next_pres_tissue;

				// increment the NDL
				NDL_tissue += period;

				// do next iteration
				continue;
			}

			// NO - if delta pressures were for 10 minutes of time ahead, continue with trying for 1 minute ahead
			if( period == 10 )
			{
				// reduce period to 1 minute
				period = 1;

				// read the loading factors for 1 minute periods
				read_Buhlmann_times(1);

				// do next iteration
				continue;
			}

			// less than a full minute of NDL time left, so finish the inner loop
			break;

		} // inner for-loop simulating increasing bottom time

		// is the current NDL shorter than the shortest so far?
		if ( NDL_tissue < NDL_time )
		{
			// keep the current's tissue NDL as the new shortest NDL
			NDL_time = NDL_tissue;

			// store the causing tissue
			new_NDL_lead_tissue = ci;
		}
		
		// If NDL is > 0 the outer loop will continues with the next tissue.
		// If NDL found to be overrun, outer loop will be terminated by means of the i = NUM_COMP statement.

	} // outer for-loop iterating over all tissues

	// store the NDL dominating tissue for to start with in the next NDL calculation
	if( char_O_deco_status & DECO_PLAN_ALTERNATE ) NDL_lead_tissue_alt  = new_NDL_lead_tissue;
	else                                           NDL_lead_tissue_norm = new_NDL_lead_tissue;
}


//////////////////////////////////////////////////////////////////////////////
// calc_ascenttime
//
// Sum up ascent from bottom to surface at float_ascent_speed, slowing down to
// 1 minute per meter for the final ascent when in deco, and all stop times.
//
// Input:  char_I_depth_last_deco
//         char_I_ascent_speed
//         char_bottom_depth
//         internal_deco_depth[]
//         internal_deco_time[]
//
// Output: ascent_time
//
static void calc_ascenttime(void)
{
	overlay unsigned char x;		// loop counter
	overlay unsigned char ascent;	// meters to go from bottom to last stop
	overlay unsigned char final;	// meters to go from last stop to surface


	// check if there are stops
	if( internal_deco_depth[0] )
	{
		// stops / in deco

		// check if already at last stop depth or shallower
		if( char_bottom_depth <= char_I_depth_last_deco)
		{
			// YES
			ascent = 0;
			final  = char_bottom_depth;
		}
		else
		{
			// NO
			ascent = char_bottom_depth - char_I_depth_last_deco;
			final  = char_I_depth_last_deco;
		}
	}
	else
	{
		// no stops / within NDL
		ascent = char_bottom_depth;
		final  = 0;
	}


	// initialize ascent time
	ascent_time = 0;

	// time for the ascent part (bottom to last stop), if existing
	if( ascent ) ascent_time += ascent / char_I_ascent_speed + 1;

	// add time for the final ascent (last stop to surface) at 1 min/m
	ascent_time += final;

	// add all stop times
	for( x=0; x < NUM_STOPS && internal_deco_depth[x]; x++ )
		ascent_time += internal_deco_time[x];

	// limit result to display max.
	if( ascent_time > 999) ascent_time = 999;

	// tag result as invalid if there is an overflow in the stops table
	if( char_O_deco_warnings & DECO_WARNING_STOPTABLE_OVERFLOW ) ascent_time |= INT_FLAG_INVALID;
}


//////////////////////////////////////////////////////////////////////////////
// clear_deco_table
//
//
static void clear_deco_table(void)
{
	overlay unsigned char x;

	for( x = 0; x < NUM_STOPS; ++x )
	{
		internal_deco_time [x] = 0;
		internal_deco_depth[x] = 0;
		internal_deco_gas[x]   = 0;
	}

	// clear stop table overflow warning
	char_O_deco_warnings &= ~DECO_WARNING_STOPTABLE_OVERFLOW;
}

//////////////////////////////////////////////////////////////////////////////
// update_deco_table
//
// Add time to a stop at sim_depth_limit
//
// It is possible to create stops with a duration of 0 minutes, e.g. to
// note a gas change "on the fly" while ascending. Therefore the criteria
// to have reached the end of the list is depth == 0.
//
// Input:   sim_depth_limit       : stop's depth, in meters
//          sim_gas_current       : gas used at stop, as index 1..5 or 0 for gas 6
//          time_increment        : number of minutes to add to the stop
//
// Updated: internal_deco_depth[] : depth    (in meters)  of each stop
//          internal_deco_time [] : time     (in minutes) of each stop
//          internal_deco_gas  [] : gas used (index 1-5)  at each stop
//
static unsigned char update_deco_table(PARAMETER unsigned char time_increment)
{
	overlay unsigned char x;

	assert( sim_depth_limit > 0 );		// no stop at surface

	// loop through internal deco table
	for( x = 0; x < NUM_STOPS; ++x )
	{
		// In case the first deco stop is to be placed deeper than previously recorded
		// stops for gas changes during the initial ascent (this may happen because the
		// deco stops are placed at the next deeper multiple of 3 meters instead of the
		// real stop's depth), relocate the deco stop to the depth of the last gas change.
		// The resulting combined stop's duration will be the sum of the configured gas
		// change time plus the duration of the deco stop itself.
		if( internal_deco_depth[x] && (sim_depth_limit > internal_deco_depth[x]) )
			sim_depth_limit = internal_deco_depth[x];

		// Is there already a stop entry for our current depth?
		if( internal_deco_depth[x] == sim_depth_limit )
		{
			// Yes - increment stop time if possible
			// Stop time entries are limited to 99 minutes because of display constraints.
			if( internal_deco_time[x] < (100 - time_increment) )
			{
				internal_deco_time[x] += time_increment;	// increment stop time
				return 1;									// return with status 'success'
			}
		}

		// If program flow passes here, there is either no stop entry for the current depth yet, or
		// the existing entry is saturated with 99 minutes. So we are looking for the next unused
		// table entry.
		if( internal_deco_depth[x] == 0 )
		{
			internal_deco_time[x]  = time_increment;		// initialize entry with first stop's time,
			internal_deco_depth[x] = sim_depth_limit;		// ... depth, and
			internal_deco_gas[x]   = sim_gas_current;		// ... gas
			return 1;										// return with status 'success'
		}
	}

	// If program flow passes here, all deco table entries are used up.

	// set overflow warning
	char_O_deco_warnings |= DECO_WARNING_STOPTABLE_OVERFLOW;

	// return with status 'failed'.
	return 0;
}


//////////////////////////////////////////////////////////////////////////////
// calc_desaturation_time
//
// Helper function
//
static void calc_desaturation_time_helper(void)
{
	if( pres_actual > pres_target )		// check if actual pressure is higher then target pressure
	{									// YES - compute remaining time
		overlay float pres_ratio;

		pres_ratio = pres_actual / pres_target;

		// Compute desaturation time with result rounded up to multiples of 10 minutes.
		// Main purpose is to avoid confusion, because the times do not clock down in
		// one minute steps any more but get constantly re-computed according to current
		// ambient pressure and may therefor make steps of several minutes forwards and
		// backwards as ambient pressure rises/falls and N2/He ratio is being adjusted.
		int_time = (unsigned int)( (var_ht * log(pres_ratio) / desat_factor) + 0.9 );
	}
	else
	{									// NO  - desaturation state reached, no remaining time
		int_time = 0;
	}
}

/////////////////////////////////////////////////////////////////////////////
// calc_desaturation_time
//
// Inputs:  int_I_pres_surface, ppWater, char_I_desaturation_multiplier
// Outputs: int_O_desaturation_time, int_O_nofly_time
//
// Calculate the time needed for the tissues to equilibrate with surface pressure
//
void calc_desaturation_time(void)
{
	assert( 800 < int_I_pres_surface             && int_I_pres_surface             <  1100 );
	assert( 0   < char_I_desaturation_multiplier && char_I_desaturation_multiplier <=  100 );


	// safety limit to prevent eventual infinite looping (bricking the OSTC)
	if( int_I_pres_surface < 500) int_I_pres_surface = 500;

	// fraction of inert gases in respired air
	real_N2_ratio  = 0.7902;
	real_He_ratio  = 0.0;

	// surface pressure in bar
	pres_surface   = 0.001    * int_I_pres_surface;

	// partial pressure of N2 in respired air
	N2_equilibrium = real_N2_ratio * (pres_surface - ppWater);

	// pre-computed term for later use: 10 [Min] * 0.01 [%] * 0.6931 [=log(2)] * ...
	desat_factor   = 0.06931  * char_I_desaturation_multiplier * SURFACE_DESAT_FACTOR;

	// initialize vars
	int_O_desaturation_time = 0;
	int_O_nofly_time        = 0;


	for( ci = NUM_COMP; ci > 0; )
	{
		overlay float        pres_tissue_max;
		overlay float        P_ambient_altitude;
		overlay signed char  search_direction;
		overlay unsigned int nofly_N2   =  0;
		overlay unsigned int nofly_He   =  0;
		overlay unsigned int nofly_last = ~0;


		ci -= 1;

		read_Buhlmann_ht();
		read_Buhlmann_coefficients();

		// get selected target altitude
		switch( char_I_altitude_wait )
		{
			case 1:  P_ambient_altitude = P_ambient_1000m;	break;
			case 2:  P_ambient_altitude = P_ambient_2000m;	break;
			case 3:  P_ambient_altitude = P_ambient_3000m;	break;
			default: P_ambient_altitude = P_ambient_fly;	break;
		}

		// Target pressure for the tissue is the Buhlmann limit. We use the Buhlmann
		// coefficients for N2 also for He because it is easier to calculate and the
		// N2 coefficients are more conservative than those for He, so we are on the
		// safe side, too.
		pres_tissue_max = (P_ambient_altitude/var_N2_b + var_N2_a);

		// Adjust target pressure in case the GF model is in use by GF-high
		if( char_I_deco_model != 0 )
			pres_tissue_max = P_ambient_altitude +
			                  0.01 * char_I_GF_High_percentage * (pres_tissue_max - P_ambient_altitude);


		//
		// Desaturation time
		//

		// N2: actual amount of tissue pressure above equilibrium.
		pres_actual = pres_tissue_N2[ci] - N2_equilibrium;

		// N2: half-time of the current tissue
		var_ht = var_N2_ht;

		// Calculate desaturation time for N2 in tissue.
		// Desaturated state is defined as residual tissue pressure <= 1.05 x ppN2 respired

		pres_target = 0.05 * N2_equilibrium;

		calc_desaturation_time_helper();

		if( int_time > int_O_desaturation_time) int_O_desaturation_time = int_time;


		// He: actual amount of tissue pressure above equilibrium: equilibrium for He is 0 bar
		pres_actual = pres_tissue_He[ci];

		// He: half-time of the current tissue
		var_ht      = var_He_ht;

		// Calculate desaturation time for He in the tissue.
		// Desaturated state is defined as residual tissue pressure <= 0.05 x ppN2 respired

		pres_target = 0.05 * N2_equilibrium;

		calc_desaturation_time_helper();

		if( int_time > int_O_desaturation_time) int_O_desaturation_time = int_time;


		//
		// no-fly time
		//

		// initialize split_N2_He in case there was a hard reboot / memory clear.
		if( split_N2_He[ci] == 0 ) split_N2_He[ci] = 90;

		// initialize search direction
		search_direction = 0;

		for(;;)
		{
			// N2: actual amount of tissue pressure above equilibrium.
			pres_actual = pres_tissue_N2[ci] - N2_equilibrium;

			// N2: half-time of the current tissue
			var_ht = var_N2_ht;

			// Calculate no-fly time for N2 in the tissue.
			// Flying is permitted when the N2 pressure fits into the assigned fraction above equilibrium.

			pres_target = (split_N2_He[ci] * 0.01) * (pres_tissue_max - N2_equilibrium);

			if( pres_target < 0.0 )						// check if desaturation to fly target is possible
			{
				int_O_nofly_time = 288;					// NO  - set no-fly time to 288 * 10 min = 48 h
				break;									// done for this compartment
			}
			else
			{
				calc_desaturation_time_helper();
				nofly_N2 = int_time;
			}

			// He: actual amount of tissue pressure above equilibrium - equilibrium for He is 0 bar.
			pres_actual = pres_tissue_He[ci];

			// He: half-time of the current tissue
			var_ht      = var_He_ht;

			// Calculate no-fly time for He in the tissue.
			// Flying is permitted when the He pressure fits into the assigned fraction.

			pres_target = (0.01 * (100 - split_N2_He[ci])) * (pres_tissue_max - N2_equilibrium);

			calc_desaturation_time_helper();
			nofly_He = int_time;


			// Because the sum of N2 and He tissue pressures needs to fit into the Buhlmann limit for
			// no-fly time calculation, each gas gets assigned a fraction of the available total pressure
			// limit. The optimum split between the two gases can not be computed by a single formular,
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
					// Either the just completed iteration was more close to the optimum or the one before
					// was, so we take the best (i.e. shortest) time of both as the final no-fly time.
					int_O_nofly_time = (nofly_N2 < nofly_last) ? nofly_N2 : nofly_last;
					break;
				}

				// store the no-fly time found in this iteration
				nofly_last = nofly_N2;

				// increase the N2 fraction of the split and set search direction towards more N2
				split_N2_He[ci]  +=  1;
				search_direction  = +1;
			}
			else
			{
				// check if the search direction has changed, which means we are beyond the
				// optimum now, or if we are at the lower stop limit of split_N2_He
				if( (search_direction > 0) || (split_N2_He[ci] == 1) )
				{
					// Either the just completed iteration was more close to the optimum or the one before
					// was, so we take the best (i.e. shortest) time of both as the final no-fly time.
					int_O_nofly_time = (nofly_He < nofly_last) ? nofly_He : nofly_last;
					break;
				}

				// store the no-fly time found in this iteration
				nofly_last = nofly_He;

				// decrease the N2 fraction of the split and set search direction towards less N2
				split_N2_He[ci]  -=  1;
				search_direction  = -1;
			}

		} // for(;;)

	} // for(compartments)


	// Rescale int_O_desaturation_time and int_O_nofly_time to full minutes for display purpose
	int_O_desaturation_time *= 10;
	int_O_nofly_time		*= 10;

	// Limit int_O_desaturation_time and int_O_nofly_time to 5999 = 99 hours + 59 minutes
	// because of display space constraints and rounding done above.
	if( int_O_desaturation_time > 5999 ) int_O_desaturation_time = 5999;
	if( int_O_nofly_time        > 5999 ) int_O_nofly_time        = 5999;


	// Clear the microbubbles warning when the current gradient factor is < 100%.
	// The current gradient factor is calculated by calc_interval() while not in diving mode.
	// As the locked warning will stay set, this will cause the warning be be displayed in
	// attention color instead of warning color.
	if( int_O_gradient_factor < 100 )
		char_O_deco_warnings &= ~DECO_WARNING_MBUBBLES;

	// clear some warnings when the desaturation time has become zero
	if( int_O_desaturation_time == 0 )
	    char_O_deco_warnings &= ~(   DECO_WARNING_IBCD     + DECO_WARNING_IBCD_lock
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
// Input:    int_I_pres_surface : surface pressure in mbar
//           time_interval      : time interval in minutes, must be limited to 254 at max
//
// Modified: tissue pressures   : N2 and He pressures of the tissues
//           CNS_fraction       : current CNS value
//           ceiling            : minimum allowed depth in mbar relative pressure
//           lead_supersat      : supersaturation of the leading tissue
//           int_O_gradient_factor : current GF factor
//
static void calc_interval(PARAMETER unsigned char time_interval)
{
	overlay unsigned char time;

	assert( 800 <  int_I_pres_surface             && int_I_pres_surface             <  1100 );
	assert( 100 <= char_I_saturation_multiplier   && char_I_saturation_multiplier   <   200 );
	assert(   0 <  char_I_desaturation_multiplier && char_I_desaturation_multiplier <=  100 );


	// safety limit to prevent eventual infinite looping (bricking the OSTC)
	if( int_I_pres_surface < 500) int_I_pres_surface = 500;		// min. surface pressure = 500 mbar

	// setup input data for deco routines
	real_pres_respiration = pres_surface = 0.001 * int_I_pres_surface;

	real_N2_ratio  = 0.7902;											// according to Buhlmann
	N2_equilibrium = real_N2_ratio * (pres_surface          - ppWater);	// used for N2 tissue graphics scaling
	ppN2           = real_N2_ratio * (real_pres_respiration - ppWater);
	ppHe           = 0.0;

	float_desaturation_multiplier = 0.01 * char_I_desaturation_multiplier * SURFACE_DESAT_FACTOR;
	float_saturation_multiplier   = 0.01 * char_I_saturation_multiplier;


	// Calculate the tissues:
	// Because calc_tissues() can calculate for 127 minutes at max,
	// the tissue updating may need to be done in two chunks.

	time = time_interval;

	// first chunk for the part exceeding 127 minutes
	if( time > 127)
	{
		// do a full 127 minutes on the real tissues
		tissue_increment = TISSUE_FLAG | 127;
		calc_tissues();

		// determine the remaining part
		time -= 127;
	}

	// program the remaining part (or full part if not exceeding 127 minutes)
	tissue_increment = TISSUE_FLAG | time;

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
			CNS_fraction *= 0.925874712;	// Half-time = 90min -> 10 min: (1/2)^(1/9)
			time         -= 10;				// fast speed looping
		}
		else
		{
			CNS_fraction *= 0.992327946;	// Half-time = 90min ->  1 min: (1/2)^(1/90)
			time         -= 1;				// slow speed looping
		}
	}

	// compute integer copy of CNS value
	convert_CNS_for_display();

	// calculate GF value (for a GF high of 100%)
	calc_limit(1.0);

	// compute integer copy of GF value
	convert_GF_for_display();
}


//////////////////////////////////////////////////////////////////////////////
// calc_CNS
//
// Input:    char_ppO2        : current ppO2 [decibars]
//           tissue_increment : time increment and tissue selector
//
// Modified:     CNS_fraction   accumulated CNS (real      tissue context)
//           sim_CNS_fraction : accumulated CNS (simulated tissue context)
//
static void calc_CNS(void)
{
	overlay float CNS_fraction_inc;			// increment of CNS load, 0.01 = 1%
	overlay float time_factor;				// factor for time increment

	assert( char_ppO2 > 15 );

	// adjust time factor to 2 seconds (factor = 1.0) or minute-based interval (factor = N * 30.0)
	if( tissue_increment & TIME_MASK ) time_factor = (float)(tissue_increment & TIME_MASK) * 30.0;
	else                               time_factor =                                          1.0;

	//------------------------------------------------------------------------
	// No CNS increase below 0.5 bar ppO2
	     if (char_ppO2 <  50) CNS_fraction_inc = 0.0;
	//------------------------------------------------------------------------
	// Below (and including) 1.60 bar
	else if (char_ppO2 <  61) CNS_fraction_inc = time_factor/(-533.07 * char_ppO2 + 54000.0);
	else if (char_ppO2 <  71) CNS_fraction_inc = time_factor/(-444.22 * char_ppO2 + 48600.0);
	else if (char_ppO2 <  81) CNS_fraction_inc = time_factor/(-355.38 * char_ppO2 + 42300.0);
	else if (char_ppO2 <  91) CNS_fraction_inc = time_factor/(-266.53 * char_ppO2 + 35100.0);
	else if (char_ppO2 < 111) CNS_fraction_inc = time_factor/(-177.69 * char_ppO2 + 27000.0);
	else if (char_ppO2 < 152) CNS_fraction_inc = time_factor/( -88.84 * char_ppO2 + 17100.0);
	else if (char_ppO2 < 167) CNS_fraction_inc = time_factor/(-222.11 * char_ppO2 + 37350.0);
	//------------------------------------------------------------------------
	// Arieli et all.(2002): Modeling pulmonary and CNS O2 toxicity:
	// J Appl Physiol 92: 248--256, 2002, doi:10.1152/japplphysiol.00434.2001
	// Formula (A1) based on value for 1.55 and c=20
	// example calculation: Sqrt((1.7/1.55)^20)*0.000404
	else if (char_ppO2 < 172) CNS_fraction_inc = time_factor * 0.00102;
	else if (char_ppO2 < 177) CNS_fraction_inc = time_factor * 0.00136;
	else if (char_ppO2 < 182) CNS_fraction_inc = time_factor * 0.00180;
	else if (char_ppO2 < 187) CNS_fraction_inc = time_factor * 0.00237;
	else if (char_ppO2 < 192) CNS_fraction_inc = time_factor * 0.00310;
	else if (char_ppO2 < 198) CNS_fraction_inc = time_factor * 0.00401;
	else if (char_ppO2 < 203) CNS_fraction_inc = time_factor * 0.00517;
	else if (char_ppO2 < 233) CNS_fraction_inc = time_factor * 0.02090;
	else                      CNS_fraction_inc = time_factor * 0.04820; // value for 2.5 bar, used for 2.33 bar and above

	// update the CNS accumulator
	if( tissue_increment & TISSUE_FLAG )     CNS_fraction += CNS_fraction_inc;	// real tissues
	else                                 sim_CNS_fraction += CNS_fraction_inc;	// simulated tissues
}


//////////////////////////////////////////////////////////////////////////////
// gas_volumes
//
// calculates volumes and required tank fill pressures for each gas.
//
// Input:	char_bottom_depth		depth of the bottom segment
//			char_I_bottom_time		duration of the bottom segment
//			char_I_extra_time		extra bottom time for fTTS / delayed ascent
//			float_ascent_speed		ascent speed, in meters/minute
//			internal_deco_depth[]	depth of the stops
//			internal_deco_time[]	duration of the stops
//			internal_deco_gas[]		gas breathed at the stops
//			NDL_time				remaining NDL time, used to adjust speed of final ascent
//			char_I_bottom_usage		gas consumption during bottom part and initial ascent, in liters/minute
//			char_I_deco_usage		gas consumption during stops and following ascents, in liters/minute
//			char_I_tank_size[]		size of the tanks for gas 1-5, in liters
//			char_I_tank_pres_fill[]	fill pressure of the tanks
//
// Output:	int_O_ascent_volumes[]	 amount of gas needed, in liters
//			int_O_ascent_pres_need[] in bar, + flags for fast evaluation by dive mode warnings:
//											  2^15: pres_need >= pres_fill
//											  2^14: pres_need >= press_fill * GAS_NEEDS_ATTENTION_THRESHOLD
//											  2^11: pres_need == 0
//											  2^10: pres_need is invalid
//
static void gas_volumes_helper_1(void)
{
	// Calculate the gas volume needed at a given depth, time and usage (SAC rate).
	// We use 1.0 for the surface pressure to have stable results when used through
	// the deco calculator (simulation mode).
	volume = (float_depth * METER_TO_BAR + 1.0) * float_time * char_usage;

	return;
}

static void gas_volume_helper_2(void)
{
	// Convert a gas volume in liters given as a float into an integer number
	// and computes the equivalent tank pressure in bar, including all flags.

	if( volume >= 65534.5 )
	{
		int_volume    = 65535;
		int_pres_need = 999 + INT_FLAG_WARNING; // 999 bar + warning flag for > pres_fill
	}
	else
	{
		overlay unsigned short tank_pres_fill = 10.0 * (unsigned short)char_I_tank_pres_fill[gas_num];

		// No distinct rounding done here because volumes are not accurate to the single liter anyhow

		// convert gas volumes to integers
		int_volume    = (unsigned short)volume;

		// compute how much pressure in the tank will be needed [in bar]  (integer-division)
		int_pres_need = (unsigned short)(int_volume / char_I_tank_size[gas_num]);

		// limit to 999 bar because of display constraints
		if( int_pres_need > 999 ) int_pres_need = 999;

		// set flags for fast evaluation by divemode check_for_warnings
		if     ( int_pres_need ==                                              0 ) int_pres_need |= INT_FLAG_ZERO;
		else if( int_pres_need >=                                 tank_pres_fill ) int_pres_need |= INT_FLAG_WARNING;
		else if( int_pres_need >= GAS_NEEDS_ATTENTION_THRESHOLD * tank_pres_fill ) int_pres_need |= INT_FLAG_ATTENTION;
	}

	return;
}

static void gas_volumes(void)
{
	overlay float volumes[NUM_GAS];

	overlay unsigned char stop_gas;
	overlay unsigned char stop_gas_last;
	overlay unsigned char stop_time;
	overlay unsigned char stop_depth;
	overlay unsigned char stop_depth_last;
	overlay unsigned char i;

	//---- initialization ----------------------------------------------------

	// null the volume accumulators
	for( gas_num = 0; gas_num < NUM_GAS; ++gas_num ) volumes[gas_num] = 0.0;

	// quit for CCR and pSCR mode
	if( char_O_deco_status & DECO_MODE_LOOP ) goto done;


	//---- bottom demand -----------------------------------------------------

	// sim_gas_current  : gas used during bottom segment (0, 1-5)
	// char_bottom_depth: depth of the bottom segment

	// get the gas used during bottom segment
	gas_find_current();

	// initialize variables
	stop_gas_last = stop_gas = sim_gas_current;

	// set the usage (SAC rate) to bottom usage rate for bottom part and initial ascent
	char_usage = char_I_bottom_usage;

	// volumes are only calculated for gases 1-5, but not the manually configured one
	if( stop_gas )
	{
		// set the bottom depth
		float_depth = (float)char_bottom_depth;

		// calculate either bottom segment or just the fTTS/bailout delayed part
		if( char_O_main_status & DECO_BOTTOM_CALCULATE )
		{
			// duration of bottom segment
			float_time = (float)char_I_bottom_time;
		}
		else
		{
			// duration of delayed ascent
			float_time = (float)char_I_extra_time;
		}

		// calculate gas demand
		gas_volumes_helper_1();

		// take result
		volumes[stop_gas-1] = volume;
	}

	// initialize stop index with first stop
	i = 0;

	//---- initial ascent demand ---------------------------------------------

	// stop_gas                : gas from bottom segment
	// char_bottom_depth       : depth of the bottom segment
	// internal_deco_depth[i=0]: depth of the first stop, may be 0 if no stop exists

	// get the data of the first stop
	stop_depth = internal_deco_depth[i];
	stop_time  = internal_deco_time[i];

	// volumes are only calculated for gases 1-5, but not the manually configured one
	if( stop_gas )
	{
		// compute distance between bottom and first stop
		float_depth = (float)char_bottom_depth - (float)stop_depth;

		// initial ascent exists only if ascent distance is > 0
		if( float_depth > 0.0 )
		{
			// compute ascent time
			float_time = float_depth / float_ascent_speed;

			// compute average depth between bottom and first stop
			float_depth = (float)char_bottom_depth - float_depth * 0.5;

			// calculate gas demand
			gas_volumes_helper_1();

			// add result
			volumes[stop_gas-1] += volume;
		}
	}

	// switch the usage (SAC rate) to deco usage rate
	// for stops, intermediate and final ascent
	char_usage = char_I_deco_usage;

	// is there a (first) stop? if yes, goto stops processing
	if( stop_depth ) goto stops;

	// add demand of a 3 minutes safety stop at 5 meters, at least for contingency...
	float_time  = 3.0;
	float_depth = 5.0;

	// calculate gas demand
	gas_volumes_helper_1();

	// add result
	volumes[stop_gas-1] += volume;

	// proceed to volume conversion and pressure calculations
	goto done;


	//---- intermediate ascent demand ---------------------------------------
inter_ascents:

	// store last stop depth and gas
	stop_depth_last = stop_depth;
	stop_gas_last   = stop_gas;

	// check if we are at the end of the stops table
	if( i < NUM_STOPS-1 )
	{
		// there are more entries - get the next stop data
		i++;

		// get the next stop depth
		stop_depth = internal_deco_depth[i];

		// check if there is indeed another stop,
		// if not (depth = 0) treat as end of table
		if( stop_depth == 0 ) goto end_of_table;

		// get the next stop duration
		stop_time = internal_deco_time[i];
	}
	else
	{
end_of_table:

		// End of the stops table reached or no more stops: Split the remaining
		// ascent into an intermediate ascent and a final ascent by creating a
		// dummy stop at the usual last deco stop depth. Stop gas doesn't change.
		stop_time  = 0;
		stop_depth = char_I_depth_last_deco;
	}

	// volumes are only calculated for gases 1-5, but not the manually configured one
	if( stop_gas_last )
	{
		// compute distance between the two stops:
		// last stop will always be deeper than current stop
		float_depth = (float)(stop_depth_last - stop_depth);

		// compute ascent time
		float_time = float_depth / float_ascent_speed;

		// compute average depth between the two stops
		float_depth = (float)stop_depth_last - float_depth * 0.5;

		// calculate gas demand
		gas_volumes_helper_1();

		// add result
		volumes[stop_gas_last-1] += volume;
	}


	//---- next stop demand -------------------------------------------------
stops:

	// convert depth of the stop
	float_depth = (float)stop_depth;

	// get the next gas
	stop_gas = internal_deco_gas[i];

	// in case of end-of-table, keep the last gas
	if( !stop_gas ) stop_gas = stop_gas_last;

	// do we have a gas change?
	if( stop_gas_last && (stop_gas != stop_gas_last) )
	{
		// yes - spend an additional char_I_gas_change_time on the old gas
		float_time = (float)char_I_gas_change_time;

		// calculate gas demand
		gas_volumes_helper_1();

		// add result
		volumes[stop_gas_last-1] += volume;
	}

	// calculate and add demand on new gas for the full stop duration
	if( stop_gas )
	{
		// get the duration of the stop
		float_time = (float)stop_time;

		// calculate gas demand
		gas_volumes_helper_1();

		// add result to last gas
		volumes[stop_gas-1] += volume;
	}

	// continue with the next intermediate ascent if this was not the last stop
	if( stop_depth > char_I_depth_last_deco ) goto inter_ascents;


	//---- final ascent demand -----------------------------------------------
final_ascent:

	// float_depth: depth of last stop
	// stop_gas   : gas from last stop (0 or 1-5)

	// volumes are only calculated for gases 1-5, but not the manually configured one
	if( stop_gas )
	{
		// set ascent time dependent on deco status
		if( NDL_time )
		{
			// within NDL - ascent with float_ascent_speed
			float_time = float_depth / float_ascent_speed;
		}
		else
		{
			// in deco - reduce ascent speed to 1 meter per minute
			float_time = float_depth;
		}

		// set half-way depth
		float_depth *= 0.5;

		// calculate gas demand
		gas_volumes_helper_1();

		// add result
		volumes[stop_gas-1] += volume;
	}


	//---- convert results for the assembler interface -----------------------------
done:

#ifdef _rx_functions
	// only for OSTC TR model with TR functions enabled
	if( char_O_main_status & DECO_TR_FUNCTIONS )
	{
		// invalidate pressure needs to pressure readings
		int_O_pressure_need[0] = 0 + INT_FLAG_NOT_AVAIL;
		int_O_pressure_need[1] = 0 + INT_FLAG_NOT_AVAIL;
	}
#endif

	for( gas_num = 0; gas_num < NUM_GAS; ++gas_num )
	{
		volume = volumes[gas_num];

		// compute int_volume and int_pres_need from volume and gas_num
		gas_volume_helper_2();

		// set invalid flag if there is an overflow in the stops table
		if( char_O_deco_warnings & DECO_WARNING_STOPTABLE_OVERFLOW )
			int_pres_need |= INT_FLAG_INVALID;

		// copy result data to ASM interface
		int_O_ascent_volumes[gas_num]   = int_volume;
		int_O_ascent_pres_need[gas_num] = int_pres_need;

#ifdef _rx_functions
		// only for OSTC TR model with TR functions enabled
		if( char_O_main_status & DECO_TR_FUNCTIONS )
		{
			// char_I_pressure_gas[] uses gas numbers 1-10, gas_num runs from 0 to 4
			overlay unsigned char gas = gas_num + 1;

			// check if the current gas is configured on pressure reading 1 or 2
			if( (gas == char_I_pressure_gas[0]) || (gas == char_I_pressure_gas[1]) )
			{
				// strip all flags from int_pres_need
				int_pres_need &= 1023;

				// limit to 400 bar and multiply by 10 to get result in 0.1 bar
				int_pres_need = (int_pres_need > 400) ? (4000 | INT_FLAG_OUT_OF_RANGE) : (10 * int_pres_need);

				// tag as not available if there is an overflow in the stops table
				if( char_O_deco_warnings & DECO_WARNING_STOPTABLE_OVERFLOW )
					int_pres_need |= INT_FLAG_NOT_AVAIL;

				// copy to result vars (in both readings the same gas could be configured)
				if( gas == char_I_pressure_gas[0] ) int_O_pressure_need[0] = int_pres_need;
				if( gas == char_I_pressure_gas[1] ) int_O_pressure_need[1] = int_pres_need;
			}
		} // TR functions
#endif

	} // for
}

//////////////////////////////////////////////////////////////////////////////

static void convert_CNS_for_display(void)
{
	     if( CNS_fraction <  0.010 ) int_O_CNS_fraction = 0;
	else if( CNS_fraction >= 9.985 ) int_O_CNS_fraction = 999 + INT_FLAG_WARNING;
	else
	{
		// convert float to integer
		int_O_CNS_fraction = (unsigned short)(100 * CNS_fraction + 0.5);

		// set warning & attention flags
		     if( int_O_CNS_fraction >= CNS_WARNING_THRESHOLD   ) int_O_CNS_fraction |= INT_FLAG_WARNING;
		else if( int_O_CNS_fraction >= CNS_ATTENTION_THRESHOLD ) int_O_CNS_fraction |= INT_FLAG_ATTENTION;
	}
}

//////////////////////////////////////////////////////////////////////////////

static void convert_sim_CNS_for_display(void)
{
	     if( sim_CNS_fraction <  0.010 ) int_sim_CNS_fraction = 0;
	else if( sim_CNS_fraction >= 9.985 ) int_sim_CNS_fraction = 999 + INT_FLAG_WARNING;
	else
	{
		// convert float to integer
		int_sim_CNS_fraction = (unsigned short)(100 * sim_CNS_fraction + 0.5);

		// set warning & attention flags
		if      ( int_sim_CNS_fraction >= CNS_WARNING_THRESHOLD    ) int_sim_CNS_fraction |= INT_FLAG_WARNING;
		else if ( int_sim_CNS_fraction >= CNS_ATTENTION_THRESHOLD  ) int_sim_CNS_fraction |= INT_FLAG_ATTENTION;
	}

	// set invalid flag if there is an overflow in the stops table
	if( char_O_deco_warnings & DECO_WARNING_STOPTABLE_OVERFLOW ) int_sim_CNS_fraction |= INT_FLAG_INVALID;
}

//////////////////////////////////////////////////////////////////////////////

static void convert_GF_for_display(void)
{
	// convert supersaturation of the leading tissue to int_O_gradient_factor in % (1.0 = 100%)
	// limit to 255 because of constraints in ghostwriter code
	     if( lead_supersat <= 0.000 ) int_O_gradient_factor = 0;
	else if( lead_supersat >  2.545 ) int_O_gradient_factor = 255 + INT_FLAG_WARNING;
	else
	{
		int_O_gradient_factor = (unsigned int)(100 * lead_supersat + 0.5);

		if( char_I_deco_model != 0 )
		{
			// GF factors enabled
			if     ( int_O_gradient_factor > 99 )
			{
				int_O_gradient_factor |= INT_FLAG_WARNING;			// make GF factor shown in red
			}
			else if( int_O_gradient_factor > char_I_GF_High_percentage )
			{
				int_O_gradient_factor |= INT_FLAG_ATTENTION;		// make GF factor shown in yellow
				char_O_deco_warnings  |= DECO_ATTENTION_OUTSIDE;	// make depth blink     in yellow
			}
		}
		else
		{
			// straight Buhlmann
			if      ( int_O_gradient_factor > 100 )
				int_O_gradient_factor |= INT_FLAG_WARNING;			// make GF factor shown in red

			else if ( int_O_gradient_factor >  99 )
			{
				int_O_gradient_factor |= INT_FLAG_ATTENTION;		// make GF factor shown in yellow
				char_O_deco_warnings  |= DECO_ATTENTION_OUTSIDE;	// make depth blink     in yellow
			}
		}
	}

	// export also the number of the leading tissue
	char_O_lead_number = lead_number;
}

//////////////////////////////////////////////////////////////////////////////

static void convert_ceiling_for_display(void)
{
	// Convert ceiling to int_O_ceiling in mbar relative pressure.
	// Round up to next 10 cm so that the ceiling disappears only
	// when the ceiling limit is really zero. This will coincident
	// with TTS switching back to NDL time.
	     if( ceiling <=  0.0 ) int_O_ceiling = 0;
	else if( ceiling >  16.0 ) int_O_ceiling = 16000;
	else                       int_O_ceiling = (short)(ceiling * 1000 + 9);

	// set/reset ceiling flag
	if( int_O_ceiling ) char_O_deco_info |=  DECO_CEILING;
	else                char_O_deco_info &= ~DECO_CEILING;
}

//////////////////////////////////////////////////////////////////////////////
// push_tissues_to_vault & pull_tissues_from_vault
//
// ATTENTION: Do not use from inside the deco engine!
//            The vault is exclusively reserved to back-up and restore the real
//            tissues and related data when entering / leaving simulation mode!
//

static void push_tissues_to_vault(void)
{
	overlay unsigned char x;

	cns_vault_float      = CNS_fraction;
	deco_warnings_vault  = char_O_deco_warnings;

	for( x = 0; x < NUM_COMP; x++ )
	{
		pres_tissue_N2_vault[x] = pres_tissue_N2[x];
		pres_tissue_He_vault[x] = pres_tissue_He[x];
	}
}

static void pull_tissues_from_vault(void)
{
	overlay unsigned char x;

	CNS_fraction         = cns_vault_float;
	char_O_deco_warnings = deco_warnings_vault;

	convert_CNS_for_display();

	for( x = 0; x < NUM_COMP; x++ )
	{
		pres_tissue_N2[x] = pres_tissue_N2_vault[x];
		pres_tissue_He[x] = pres_tissue_He_vault[x];
	}
}

//////////////////////////////////////////////////////////////////////////////
//
#ifndef CROSS_COMPILE
void main() {}
#endif
