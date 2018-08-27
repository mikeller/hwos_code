// ***************************************************************************
// p2_deco.c                                         REFACTORED VERSION V2.97 SP1
//
//  Created on: 12.05.2009
//  Author: heinrichs weikamp, contributions by Ralph Lembcke and others
//
// ***************************************************************************

//////////////////////////////////////////////////////////////////////////////
// OSTC - diving computer code
// Copyright (C) 2011 HeinrichsWeikamp GbR
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
// Schr"oder, Kai & Reith, Steffen; 2000; S"attigungsvorg"ange beim Tauchen, das Modell ZH-L16, Funktionsweise von Tauchcomputern; http://www.achim-und-kai.de/kai/tausim/saett_faq
// Morrison, Stuart; 2000; DIY DECOMPRESSION; http://www.lizardland.co.uk/DIYDeco.html
// Balthasar, Steffen; Dekompressionstheorie I: Neo Haldane Modelle; http://www.txfreak.de/dekompressionstheorie_1.pdf
// Baker, Erik C.; Clearing Up The Confusion About "Deep Stops"
// Baker, Erik C.; Understanding M-values; http://www.txfreak.de/understanding_m-values.pdf
//
//

// *********************
// ** I N C L U D E S **
// *********************
#include <math.h>

// ***********************************************
// ** V A R I A B L E S   D E F I N I T I O N S **
// ***********************************************

#include	"p2_definitions.h"
#define		TEST_MAIN
#include	"shared_definitions.h"


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
#define ppWater							0.0627	// water vapor partial pressure in the lungs
#define METER_TO_BAR					0.09985	// conversion factor
#define BAR_TO_METER					10.0150	// conversion factor (1.0/METER_TO_BAR)
#define SURFACE_DESAT_FACTOR			0.7042	// surface desaturation safety factor
#define HYST							1.0E-06	// threshold for tissue graphics on-gassing / off-gassing visualization

// thresholds
#define GF_WARNING_THRESHOLD			100		// threshold for GF   warning (attention threshold is current GF_high)
#define CNS_WARNING_THRESHOLD			100		// threshold for CNS  warning
#define CNS_ATTENTION_THRESHOLD			 70		// threshold for CNS  attention
#define ppO2_ATTENTION_THRESHOLD		130		// threshold for ppO2 attention (thresholds for warnings come by options_table.asm)
#define ppO2_GAP_TO_SETPOINT			 10		// gap between setpoint and max. ppO2 of the pure diluent [cbar]
#define GAS_NEEDS_ATTENTION_THRESHOLD	0.70	// threshold for gas needs attention

// deco engine states and modes - char_O_deco_status
#define DECO_STATUS_MASK				0x03
#define DECO_STATUS_START				0x00
#define DECO_STATUS_FINISHED			0x00
#define DECO_STATUS_STOPS				0x01 
#define DECO_STATUS_RESULTS				0x02
#define DECO_STATUS_INIT				0x03

#define DECO_MODE_MASK					0x0C
#define DECO_MODE_LOOP					0x04
#define DECO_MODE_CCR					0x04	// to be used with == operator in combination with DECO_MODE_MASK only!
#define DECO_MODE_PSCR					0x08

#define DECO_PLAN_ALTERNATE				0x10
#define DECO_CNS_CALCULATE				0x20
#define DECO_VOLUME_CALCULATE			0x40
#define DECO_ASCENT_DELAYED				0x80

// deco engine states and modes - char_O_main_status
//#define DECO_MODE_MASK				0x0C
//#define DECO_MODE_LOOP				0x04
//#define DECO_MODE_CCR					0x04	// to be used with == operator in combination with DECO_MODE_MASK only!
//#define DECO_MODE_PSCR				0x08
#define DECO_GASCHANGE_OVRD				0x10
#define DECO_BOTTOM_CALCULATE			0x40

// deco engine states and modes - tissue_increment
#define TIME_MASK						0x7F	// (127 decimal, bits 0-6 set)
#define TISSUE_FLAG						0x80	// (128 decimal, bit   7  set)

// deco engine warnings
#define	DECO_WARNING_IBCD				0x01
#define	DECO_WARNING_IBCD_lock			0x02
#define	DECO_WARNING_MBUBBLES			0x04
#define	DECO_WARNING_MBUBBLES_lock		0x08
#define	DECO_WARNING_OUTSIDE			0x10
#define	DECO_WARNING_OUTSIDE_lock		0x20
#define DECO_WARNING_STOPTABLE_OVERFLOW	0x40
#define DECO_FLAG						0x80

// flags used with integer numbers
#define INT_FLAG_INVALID				0x0400
#define INT_FLAG_ZERO					0x0800
#define INT_FLAG_LOW					0x1000
#define	INT_FLAG_HIGH					0x2000
#define INT_FLAG_ATTENTION				0x4000
#define	INT_FLAG_WARNING				0x8000



// *************************
// ** P R O T O T Y P E S **
// *************************

static void calc_hauptroutine(void);
static void calc_hauptroutine_data_input(void);
static void calc_hauptroutine_calc_deco(void);
static void calc_alveolar_pressures(void);
static void calc_tissues(void);
static void calc_NDL_time(void);
static void calc_ascenttime(void);
static void calc_CNS_increment(void);
static void calc_desaturation_time(void);
static void calc_ascent_to_first_stop(void);
static void calc_limit(PARAMETER float GF_current);
static void calc_interval(PARAMETER unsigned char time_increment);

static void gas_find_current(void);
static void gas_set_ratios(void);
static void convert_CNS_for_display(void);
static void convert_sim_CNS_for_display(void);
static void publish_deco_table(void);
static void clear_deco_table(void);
static void clear_tissue(void);

static unsigned char calc_nextdecodepth(void);
static unsigned char gas_find_better(void);
static unsigned char update_deco_table(PARAMETER unsigned char time_increment);


//---- Bank 5 parameters -----------------------------------------------------
#ifndef UNIX
#   pragma udata bank5=0x500
#endif

// general deco parameters

static float			GF_low;							// initialized from deco parameters, constant during all computations
static float			GF_high;						// initialized from deco parameters, constant during all computations
static float			GF_delta;						// initialized from deco parameters, constant during all computations
static float			locked_GF_step_norm;			// GF_delta / low_depth_norm in normal plan
static float			locked_GF_step_alt;				// GF_delta / low_depth_alt  in alternative plan

static float			low_depth_norm;					// Depth of deepest stop in normal plan
static float			low_depth_alt;					// Depth of deepest stop in alternative plan

static float			float_ascent_speed;				// ascent speed from options_table (1.0 .. 10.0 m/min)
static float			float_deco_distance;			// additional depth below stop depth for tissue, CNS and gas volume calculation
static float			float_saturation_multiplier;	// safety factor for on-gassing rates
static float			float_desaturation_multiplier;	// safety factor for off-gassing rates

// real context: what we are doing now

static float			ceiling;						// minimum tolerated relative pressure (i.e. without surface pressue)
static float			CNS_fraction;					// current CNS (1.00 = 100%)

static unsigned short	deco_tissue_vector;				// 16 bit vector to memories all tissues that are in decompression
static unsigned short	IBCD_tissue_vector;				// 16 bit vector to memories all tissues that experience IBCD

// simulation context: used to predict ascent

static float			sim_ceiling;					// minimum tolerated relative pressure (i.e. without surface pressue)
static float			sim_CNS_fraction;				// CNS increase during predicted ascent, 0.01 = 1%

static unsigned int		int_sim_CNS_fraction;			// CNS increase during predicted ascent, in %

static unsigned char	sim_depth_limit;				// depth of next stop in meters, used in deco calculations
static unsigned char	split_N2_He[NUM_COMP];			// used for calculating the desaturation time
static unsigned char	NDL_lead_tissue;				// used to cache tissue to start with calculating NDL


// stops table

static unsigned char	internal_deco_depth[NUM_STOPS];	// depth of the stop
static unsigned char	internal_deco_time[NUM_STOPS];	// duration of the stop
static unsigned char	internal_deco_gas[NUM_STOPS];	// gas used at the stop


// transfer variables between calc_desaturation_time() and calc_desaturation_time_helper()

static float			desat_factor;					// used to cache a pre-computed factor
static float			var_ht;							// buffer for a half-time factor
static float			pres_target;					// target pressure for a compartment
static float			pres_actual;					// current pressure of the compartment
static unsigned int		int_time;						// time it takes for the compartment to reach the target pressure


// transfer variables between gas_volumes() and gas_volumes_helper()

static float			float_depth;					// depth of the stop or half-way point
static float			float_time;						// duration of the stop or ascent phase
static float			volume;							// computed volume of gas
static unsigned char	usage;							// gas usage in l/min


// auxiliary variables for data buffering

static float			N2_equilibrium;					// used for N2 tissue graphics scaling
static float			temp_tissue;					// auxiliary variable to buffer tissue pressures
static float			float_pSCR_factor;				// pre-computed factor for pSCR ppO2 drop calculation


// 35 byte free space left in this bank (4 bytes per float, 2 bytes per int/short, 1 byte per char)


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

static unsigned char	bottom_depth;					// bottom depth in meters, used by CNS and gas needs calculation

static float			pres_respiration;				// current depth in absolute pressure
static float			O2_ratio;						// real breathed gas oxygen ratio
static float			N2_ratio;						// real breathed gas nitrogen ratio
static float			He_ratio;						// real breathed gas helium ratio
static float			pSCR_drop;						// real ppO2 drop in pSCR loop

static float			sim_pres_respiration;			// simulated current depth in abs.pressure, used for deco calculations
static float			sim_O2_ratio;					// simulated breathed gas oxygen ratio
static float			sim_N2_ratio;					// simulated breathed gas nitrogen ratio
static float			sim_He_ratio;					// simulated breathed gas helium ratio
static float			sim_pSCR_drop;					// simulated ppO2 drop in pSCR loop

static float			O2_ppO2;						// ppO2 - calculated for pure oxygen at current depth
static float			OC_ppO2;						// ppO2 - calculated for breathed in OC mode
static float			pSCR_ppO2;						// ppO2 - calculated for breathed from pSCR loop

static float			ppO2;							// partial pressure of breathed oxygen
static float			ppN2;							// partial pressure of breathed nitrogen
static float			ppHe;							// partial pressure of breathed helium


// Result values from calculation functions

static float			CNS_fraction_inc;				// increment of CNS load, 0.01 = 1%

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
static float			var_N2_ht;						// half-time for current N2 tissue
static float			var_He_ht;						// half-time for current N2 tissue


// Gas switch history

static unsigned char	sim_gas_first_used;				// Number of first used gas, for bottom segment
static unsigned char	sim_gas_last_used;				// number of last  used gas
static unsigned char	sim_gas_last_depth;				// change depth of last used gas


// Vault to back-up & restore tissue data

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

static char				md_pi_subst[256];				// Overlay C-code data stack here, too.

#   define C_STACK md_pi_subst
#endif


// Back to bank6 for further tmp data
// Do not delete this assignment, it is needed by the compiler/linker.
#ifndef UNIX
#   pragma udata bank6
#endif


//////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////
////////////////              THE LOOKUP TABLES               ////////////////
//////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////

#ifndef UNIX
#   pragma romdata Buhlmann_tables = 0x1DD00  // Needs to be in UPPER bank.
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

//////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////
////////////////               THE SUBROUTINES                ////////////////
//////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////
//
// all new in v.102
// moved from 0x0D000 to 0x0C000 in v.108
#ifndef UNIX
#	pragma code p2_deco = 0x0C000
#endif

//////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////
////////////////             U T I L I T I E S                ////////////////
//////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////

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
				LFSR    1,C_STACK
				MOVLW   0xCC
		loop:	MOVWF   POSTINC1,0
				TSTFSZ  FSR1L,0
				BRA     loop

				LFSR    1,C_STACK
				LFSR    2,C_STACK
			_endasm
		}
#	else
#		define	RESET_C_STACK	\
		_asm					\
			LFSR	1, C_STACK	\
			LFSR	2, C_STACK	\
		_endasm
#	endif
#endif

//////////////////////////////////////////////////////////////////////////////
// Fast subroutine to read timer 5.
// Note: result is in 1/32 of milliseconds (30,51757813 us/bit to be precise)
static unsigned short tmr5(void)
{
#ifndef CROSS_COMPILE
	_asm
		movff	0xf7c,PRODL		// TMR5L
		movff	0xf7d,PRODH		// TMR5H
	_endasm						// result in PRODH:PRODL.
#else
	return 0;
#endif
}

//////////////////////////////////////////////////////////////////////////////
// read Buhlmann tables A and B for compartment ci
//
static void read_Buhlmann_coefficients(void)
{
#ifndef CROSS_COMPILE
	// Note: we don't use far rom pointer, because the
	//       24 bits is too complex, hence we have to set
	//       the UPPER page ourself...
	//       --> Set zero if tables are moved to lower pages !
	_asm
		movlw 1
		movwf TBLPTRU,0
	_endasm
#endif

	assert( ci < NUM_COMP );

	// Use an interleaved array (AoS) to access coefficients with a
	// single addressing.
	{
		overlay rom const float* ptr = &Buhlmann_ab[4*ci];
		var_N2_a = *ptr++;
		var_N2_b = *ptr++;
		var_He_a = *ptr++;
		var_He_b = *ptr++;
	}
}

//////////////////////////////////////////////////////////////////////////////
// read Buhlmann tables for compartment ci
// If period == 0 : 2sec interval
//              1 : 1 min interval
//              2 : 10 min interval.
static void read_Buhlmann_times(PARAMETER char period)
{
#ifndef CROSS_COMPILE
	// Note: we don't use far rom pointer, because the
	//       24 bits is to complex, hence we have to set
	//       the UPPER page ourself...
	//       --> Set zero if tables are moved to lower pages!
	_asm
		movlw 1
		movwf TBLPTRU,0
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
// read Buhlmann tables for compartment ci
//
static void read_Buhlmann_ht(void)
{

#ifndef CROSS_COMPILE
	// Note: we don't use far rom pointer, because the
	//       24 bits is to complex, hence we have to set
	//       the UPPER page ourself...
	//       --> Set zero if tables are moved to lower pages !
	_asm
		movlw 1
		movwf TBLPTRU,0
	_endasm
#endif

	assert( ci < NUM_COMP );
	{
		overlay rom const float* ptr = &Buhlmann_ht[2*ci];
		var_N2_ht = *ptr++;
		var_He_ht = *ptr++;
	}

	assert( 4.0    <= var_N2_ht && var_N2_ht <= 635.0 );
	assert( 1.5099 <= var_He_ht && var_He_ht <= 240.03 );
}

//////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////
////////////////      THE JUMP-IN CODE for the asm code       ////////////////
//////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////

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
// Updates tissues and CNS value for char_I_dive_interval minutes on Air
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
// Updates tissues and CNS value for 1 minute on Air at ambient pressure and
// calculates resulting GF factor and ceiling for a GF-high of 100% (ceiling
// is not used by *.asm files).
//
void deco_calc_dive_interval_1min(void)
{
	RESET_C_STACK
	calc_interval(1);
}


//////////////////////////////////////////////////////////////////////////////
// deco_calc_dive_interval_1min
//
// called from: sleepmode.asm
//
// Updates tissues and CNS value for 10 minutes on Air at ambient pressure and
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

//////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////
////////////////                THE FUNCTIONS                 ////////////////
//////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////


//////////////////////////////////////////////////////////////////////////////
// calc_nextdecodepth
//
// new in v.102
//
// INPUT, changing during dive:
//      sim_pres_respiration : current depth in absolute pressure
//
// INPUT, fixed during dive:
//      pres_surface
//      GF_delta
//      GF_high
//      GF_low
//      char_I_depth_last_deco
//
// MODIFIED
//      locked_GF_step_norm/_alt : used for GF model
//      low_depth_norm/_alt      : used for GF model
//
// OUTPUT
//      sim_depth_limit : depth of next stop in meters        (if RETURN == true )
//                        depth we can ascent to without stop (if RETURN == false)
//
// RETURN TRUE if a stop is needed.
//
static unsigned char calc_nextdecodepth(void)
{
	overlay unsigned char need_stop;

	// compute current depth in meters
	overlay float depth = (sim_pres_respiration - pres_surface) * BAR_TO_METER;

	// compute depth in meters after 1 minute of ascent at float_ascent_speed (5..10 m/min)
	overlay float min_depth = (depth > float_ascent_speed) ? (depth - float_ascent_speed) : 0.0;


	// allow for 200mbar of weather dependent surface pressure change
	assert( depth >= -0.2 );


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
		if( sim_ceiling <= 0.0 )
		{
			min_depth = 0.0;		// set minimum depth to 0 meters = surface
			goto no_deco_stop;		// done.
		}

		// convert minimum depth we can ascent to from relative pressure to depth in meters
		limit_depth = sim_ceiling * BAR_TO_METER;

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
			// recall locked_GF_step dependent on current plan
			locked_GF_step = (char_O_deco_status & DECO_PLAN_ALTERNATE) ? locked_GF_step_alt : locked_GF_step_norm;
		}

		// invalidate this stop if we can ascent for 1 minute without going above minimum required deco depth
		if( limit_depth < min_depth ) goto no_deco_stop;


		// if program execution passes here, we need a deco stop

		// Round to multiple of 3 meters
		first_stop = 3 * (unsigned char)(0.9995 + limit_depth * 0.333333);

		// check a constraint
		assert( first_stop < 128 );

		// apply correction for the shallowest stop, use char_I_depth_last_deco (3..6 m) instead
		if( first_stop == 3 ) first_stop = char_I_depth_last_deco;

		// We have a stop candidate.
		// But maybe ascending to the next stop will diminish the constraint,
		// because the GF might decrease more than the pressure gradient...
		while(first_stop > 0)
		{
			// Next depth
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
			if( sim_ceiling * BAR_TO_METER >= next_stop ) goto deco_stop_found;	// no - ascent to next_stop forbidden

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
		if (sim_ceiling >= 0)
		{
			// no - set flag for stop needed to 'yes'
			need_stop = 1;

			// convert stop depth in relative pressure to stop index
			limit_depth = sim_ceiling * BAR_TO_METER / 3;

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

	// After the first deco stop, gas changes are only done at deco stops now!

	// check if a stop is found and there is a better gas to switch to
	if( need_stop )
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

	for(x=0; x<NUM_STOPS; x++)
	{
		char_O_deco_depth[x] = internal_deco_depth[x];
		char_O_deco_time [x] = internal_deco_time [x];
		char_O_deco_gas  [x] = internal_deco_gas  [x];
	}

	//Now fill the char_O_deco_time_for_log array
	//---- First: search the first non-null depth
	for(x=(NUM_STOPS-1); x != 0; --x)
		if( internal_deco_depth[x] != 0 ) break;

	//---- Second: copy to output table (in reverse order)
	for(y=0; y<NUM_STOPS; y++, --x)
	{
		char_O_deco_time_for_log[y] = internal_deco_time [x];

		// Stop only once the last transfer is done.
		if( x == 0 ) break;
	}

	//---- Third: fill table with null until end
	for(y++; y<NUM_STOPS; y++)
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
// Input:  char_I_current_gas : 1..5 or 6
//
// Output: sim_gas_last_used  : 1..6 or 0 if it is the gas set as FIRST
//         sim_gas_last_depth : change depth in meters or 0 if it is the gas set as FIRST
//
static void gas_find_current(void)
{
	assert( 1 <= char_I_current_gas && char_I_current_gas <= 6 );

	if( char_I_current_gas <= NUM_GAS )					// Gas 1-5
	{
		sim_gas_last_used  = sim_gas_first_used = char_I_current_gas;
		sim_gas_last_depth = char_I_deco_gas_change[sim_gas_last_used-1];	// > 0 for OC deco gases,
																			// > 0 for first & normal diluents,
																			// = 0 else
	}
	else
	{
		sim_gas_last_used  = sim_gas_first_used = 0;		// Gas 6 (the manually set one) has number 0 here
		sim_gas_last_depth                      = 0;		// handle it as a travel/normal gas
	}
}


//////////////////////////////////////////////////////////////////////////////
// Find the deco gas with the shallowest change depth beyond current depth
//
// INPUT   sim_depth_limit          : current depth in meters
//         char_I_deco_gas_change[] : change depths of the deco gases
//         sim_gas_last_depth       : change depth of the currently used gas, 0 if on the gas set as FIRST
//
// OUTPUT  sim_gas_last_depth       : switch depth            - only if return value is true
//         sim_gas_last_used        : index of the gas (1..5) - only if return value is true
//
// RETURNS TRUE if a better gas is available
//
static unsigned char gas_find_better(void)
{
	overlay unsigned char switch_depth = 255;
	overlay unsigned char switch_gas   = 0;
	overlay unsigned char j;


	// no automatic gas changes in CCR mode and - as of now - in pSCR mode
	if( char_O_deco_status & DECO_MODE_LOOP ) return 0;

	// Loop over all deco gases to find the shallowest one below or at current depth.
	for(j=0; j<NUM_GAS; ++j)
	{
		// Is this the gas we are already breathing?
		// If yes, skip this gas.
		if( j+1 == sim_gas_last_used ) continue;

		// Is the change depth of the gas shallower than the current depth?
		// If yes, skip this gas as it is not to be used yet.
		// Remark: this check will also skip all disabled gases and the gas set
		//         as 'first' because these have their change depth set to 0.
		if( sim_depth_limit > char_I_deco_gas_change[j] ) continue;

		// Is the change depth of the gas deeper or equal than the change depth of the
		// gas we are currently one?
		// If yes, skip this gas as it is not better than the current one.
		// Remark: if there is more than one gas with the same change depth,
		//         the last one from the list will be taken.
		if( sim_gas_last_depth && (char_I_deco_gas_change[j] >= sim_gas_last_depth) ) continue;

		// Is the change depth of the gas shallower or equal to the change depth
		// of the best gas found so far, or is it the first better gas found?
		// If yes, we have a better gas
		if( char_I_deco_gas_change[j] < switch_depth )
		{
			switch_gas   = j+1;							// remember this gas (1..5)
			switch_depth = char_I_deco_gas_change[j];	// remember its change depth
		}
	}	// continue looping through all gases to eventually find an even better gas

	// has a better gas been found?
	if( switch_gas )
	{
		// yes
		sim_gas_last_used  = switch_gas;				// report the index of the better
		sim_gas_last_depth = switch_depth;				// report its change depth

		assert( sim_gas_last_depth < switch_depth );

		return 1;										// signal a better gas was found
	}
	else
	{
		return 0;										// signal no better gas was found
	}
}

//////////////////////////////////////////////////////////////////////////////
// Set calc_N2/He/O2_ratios by sim_gas_last_used
//
// Input:  sim_gas_last_used          : index of gas to use
//         N2_ratio, He_ratio         : if gas =    0 (the manually set gas)
//         char_I_deco_O2/He_ratio[]  : if gas = 1..5 (the configured gases)
//
// Output: sim_N2_ratio, sim_He_ratio : ratios of the inert gases
//         sim_pSCR_drop              : ppO2 drop in pSCR loop
//
static void gas_set_ratios(void)
{
	overlay float sim_IG_ratio;

	assert( 0 <= sim_gas_last_used <= NUM_GAS );


	// get gas ratios
	if( sim_gas_last_used == 0 )
	{
		sim_O2_ratio = O2_ratio;
		sim_He_ratio = He_ratio;
	}
	else
	{
		sim_O2_ratio = 0.01 * char_I_deco_O2_ratio[sim_gas_last_used-1];
		sim_He_ratio = 0.01 * char_I_deco_He_ratio[sim_gas_last_used-1];
	}

	// inert gas ratio (local helper variable)
	sim_IG_ratio     = 1.00 - sim_O2_ratio;

	// N2 ratio
	sim_N2_ratio     = sim_IG_ratio - sim_He_ratio;

	// ppO2 drop in pSCR loop
	sim_pSCR_drop    = sim_IG_ratio * float_pSCR_factor;


	assert( 0.0 <=  sim_N2_ratio && sim_N2_ratio  <= 0.95 );
	assert( 0.0 <=  sim_He_ratio && sim_He_ratio  <= 0.95 );
	assert(        (sim_N2_ratio +  sim_He_ratio) <= 0.95 );
}

//////////////////////////////////////////////////////////////////////////////
// Compute respired ppN2 and ppHe
//
// Input:  tissue_increment       : selector for targeting simulated or real tissues
//         char_O_main_status     : breathing mode for real      tissues
//         char_O_deco_status     : breathing mode for simulated tissues
//         (sim_)O2_ratio         : (simulated) O2 ratio breathed
//         (sim_)N2_ratio         : (simulated) N2 ratio breathed
//         (sim_)He_ratio         : (simulated) He ratio breathed
//         (sim_)pres_respiration : (simulated) respiration pressure
//         char_I_const_ppO2      : ppO2 reported from sensors or setpoint
//         char_I_PSCR_drop       : pSCR parameter
//         char_I_PSCR_lungratio  : pSCR parameter
//         pres_surface           : surface pressure
//         float_deco_distance    : safety factor
//         ppWater                : water-vapor pressure inside respiratory tract
//
// Output: ppN2                   : respired N2 partial pressure
//         ppHe                   : respired He partial pressure
//         char_ppO2              : breathed ppO2 in %, to be used for CNS calculation
//
void calc_alveolar_pressures(void)
{
	overlay float pres_diluent;
	overlay float calc_O2_ratio;
	overlay float calc_N2_ratio;
	overlay float calc_He_ratio;
	overlay float calc_pSCR_drop;

	overlay unsigned char status;


	assert( 0.00 <= N2_ratio && N2_ratio <= 1.00 );
	assert( 0.00 <= He_ratio && He_ratio <= 1.00 );
	assert( (N2_ratio + He_ratio) <= 1.00 );
	assert( 0.800 < pres_respiration && pres_respiration < 14.0 );

	assert( 0.00 <= sim_N2_ratio && N2_ratio <= 1.00 );
	assert( 0.00 <= sim_He_ratio && He_ratio <= 1.00 );
	assert( (sim_N2_ratio + sim_He_ratio) <= 1.00 );
	assert( 0.800 < sim_pres_respiration && sim_pres_respiration < 14.0 );


	// get input data according to context
	if( tissue_increment & TISSUE_FLAG )
	{
		//---- real tissues -----------------------------------------------------------
		status         = char_O_main_status;
		pres_diluent   = pres_respiration;
		calc_pSCR_drop = pSCR_drop;

		calc_O2_ratio  = O2_ratio;
		calc_N2_ratio  = N2_ratio;
		calc_He_ratio  = He_ratio;
	}
	else
	{
		//---- simulated tissues ------------------------------------------------------
		status         = char_O_deco_status;
		pres_diluent   = sim_pres_respiration;
		calc_pSCR_drop = sim_pSCR_drop;

		calc_O2_ratio  = sim_O2_ratio;
		calc_N2_ratio  = sim_N2_ratio;
		calc_He_ratio  = sim_He_ratio;

		// take deco offset into account, but not at surface
		if( pres_diluent > pres_surface ) pres_diluent += float_deco_distance;
	}

	//---- OC, CCR and Bailout Mode Gas Calculations -----------------------------------

	// calculate ppO2 of pure oxygen
	O2_ppO2 = (pres_diluent - ppWater);

	// capture failure condition in case pres_respiration is < ppWater (should never happen...)
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

		// get the current sensor reading (CCR / pSCR if fitted) or the fixed setpoint (CCR) / a zero (pSCR)
		const_ppO2 = 0.01 * char_I_const_ppO2;

		// Limit the setpoint to the maximum physically possible ppO2. This prevents for
		// example calculating with a setpoint of 1.3 bar in only 2 meters of depth.
		// Additionally, if limiting occurs, the ppO2 can be further reduced to account
		// for residual inert gases by the user-adjustable setting char_I_cc_max_frac_o2.

		if( const_ppO2 > pres_diluent )		// no ppWater subtracted here to give some margin for
		{									// sensors delivering data a little bit over target
			const_ppO2 = 0.01 * char_I_cc_max_frac_o2 * (pres_diluent - ppWater);
		}

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

			// derive breathed ppO2 from (char_I_)const_ppO2,
			// which holds sensor reading or fixed setpoint
			ppO2 = const_ppO2;
		}

		// adjust diluent pressure (ppN2 + ppHe) for change
		// in ppO2 due to setpoint (CCR) or drop (pSCR)
		pres_diluent -= ppO2;
		pres_diluent /= calc_N2_ratio + calc_He_ratio;

		// capture all failure conditions, including div/0
		// in case diluent is pure O2
		if( (pres_diluent < 0.0) || (calc_O2_ratio > 99.5) )
		{
			pres_diluent = 0.0;
			ppO2         = OC_ppO2;
		}
	}
	else
	{	//---- OC mode ---------------------------------------------------------------------------------

		// breathed ppO2 is ppO2 of pure gas
		ppO2 = OC_ppO2;
	}


	// derive char_ppO2 in [cbar], used for calculating CNS%
	if      ( ppO2 <  0.01  ) char_ppO2  =   0;
	else if ( ppO2 >= 2.545 ) char_ppO2  = 255;
	else                      char_ppO2  = (unsigned char)(100 * ppO2 + 0.5);


	//---- calculate ppN2 and ppHe ---------------------------------------------------------------------

	if( pres_diluent > ppWater )
	{
		ppN2 = calc_N2_ratio * (pres_diluent - ppWater);
		ppHe = calc_He_ratio * (pres_diluent - ppWater);
	}
	else
	{
		ppN2 = 0.0;
		ppHe = 0.0;
	}
}

//////////////////////////////////////////////////////////////////////////////
// clear_tissue
//
// optimized in v.101 (var_N2_a)
//
// preload tissues with standard pressure for the given ambient pressure.
//
static void clear_tissue(void)
{
	pres_respiration = 0.001  * int_I_pres_respiration;
	N2_equilibrium   = 0.7902 * (pres_respiration - ppWater);

	for(ci=0; ci<NUM_COMP; ci++)
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


	// reset any warnings
	char_O_deco_warnings		= 0;

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
	overlay float        EAD;
	overlay float        END;


	//--- Set-up Part --------------------------------------------------------------------------------

	// twosectimer:
	// calc_hauptroutine is now invoked every second to speed up the deco planning.
	// Because the tissue and CNS calculations are based on a two seconds period, a
	// toggle-timer is used by the respective routines to skip every 2nd invocation.
	twosectimer = (twosectimer) ? 0 : 1;			// toggle the toggle-timer


	// set up normal tissue updating or "fast forward" updating for simulator sim+5' function
	// and deco calculator bottom time calculation
	if( char_I_sim_advance_time > 0 )
	{
		// configure char_I_sim_advance_time minutes of tissue updating
		tissue_increment = char_I_sim_advance_time	// given number of minutes, limited to 127
						 | TISSUE_FLAG;				// set flag for updating the "real" tissues & CNS

		char_I_sim_advance_time = 0;				// clear "mailbox"
	}
	else
	{
		// configure 2 seconds of tissue updating
		tissue_increment = 0						// encoding for 2 seconds update
						 | TISSUE_FLAG;				// set flag for updating the "real" tissues & CNS
	}


	//---- Calculations Part ----------------------------------------------------------------------

	// acquire current environment data
	calc_hauptroutine_data_input();

	// calculate ppN2 and ppHe
	calc_alveolar_pressures();

	// All deco code is invoked every second. But as the tissue and CNS updates are based
	// on 2 seconds periods, each update is done only on each 2nd second.
	// In case a "fast forward" of the tissues is commanded, the 2-seconds rule is over raided.
	// To distribute computational load, updating of tissues and CNS is done in alternation.
	if( twosectimer || (tissue_increment & TIME_MASK) )
	{
		// calculate the real tissues
		calc_tissues();

		// calculate ceiling (at GF_high) and current GF
		calc_limit(GF_high);
	}

	if( !twosectimer || (tissue_increment & TIME_MASK) )
	{
		// calculate CNS value increment for the real tissues
		calc_CNS_increment();

		// increment CNS value of the real tissues
		CNS_fraction += CNS_fraction_inc;

		// compute integer copy of CNS value for display purpose
		convert_CNS_for_display();
	}


	//---- Calculate and Export EAD and END ------------------------------------------------------

	// calculate EAD (Equivalent Air Depth): equivalent depth for the same N2 level with plain air
	EAD = (ppN2 / 0.7902 + ppWater - pres_surface) * BAR_TO_METER;

	// calculate END (Equivalent Narcotic Depth): here O2 is treated as narcotic, too
	// Source cited: The Physiology and Medicine of Diving by Peter Bennett and David Elliott,
	//               4th edition, 1993, W.B.Saunders Company Ltd, London.
	END = (pres_respiration - ppHe - pres_surface) * BAR_TO_METER;

	// export EAD
	if( (EAD < 0.0) || (EAD > 245.5) ) char_O_EAD = 0;
	else                               char_O_EAD = (unsigned char)(EAD + 0.5);

	// export END
	if( (END < 0.0) || (END > 245.5) ) char_O_END = 0;
	else                               char_O_END = (unsigned char)(END + 0.5);


	//---- Compute ppO2 Values in [cbar] ---------------------------------------------------------

	// pure oxygen ppO2
	if		( O2_ppO2       <  0.01  ) int_O_O2_ppO2       =   0;
	else if ( O2_ppO2       >= 9.995 ) int_O_O2_ppO2       = 999;
	else                               int_O_O2_ppO2       = (unsigned int)(100 *   O2_ppO2 + 0.5);
	
	// pure gas ppO2
	if      ( OC_ppO2       <  0.01  ) int_O_pure_ppO2     =   0;
	else if ( OC_ppO2       >= 9.995 ) int_O_pure_ppO2     = 999;
	else                               int_O_pure_ppO2     = (unsigned int)(100 *   OC_ppO2 + 0.5);
	
	// calculated pSCR ppO2
	if		( pSCR_ppO2     <  0.01  ) int_O_pSCR_ppO2     =   0;
	else if ( pSCR_ppO2     >= 9.995 ) int_O_pSCR_ppO2     = 999;
	else                               int_O_pSCR_ppO2     = (unsigned int)(100 * pSCR_ppO2 + 0.5);

	// breathed ppO2
	if		( ppO2          <  0.01  ) int_O_breathed_ppO2 =   0;
	else if ( ppO2          >= 9.995 ) int_O_breathed_ppO2 = 999;
	else                               int_O_breathed_ppO2 = (unsigned int)(100 *      ppO2 + 0.5);


	//---- Compute ppO2 Warnings ------------------------------------------------------------------

	// compute conditional min/max values
	int_ppO2_min = (char_O_main_status   & DECO_MODE_LOOP) ? (unsigned int)char_I_ppO2_min_loop : (unsigned int)char_I_ppO2_min;
	int_ppO2_max = (char_O_deco_warnings & DECO_FLAG     ) ? (unsigned int)char_I_ppO2_max_deco : (unsigned int)char_I_ppO2_max;

	// default value for the upper diluent ppO2 warning threshold is the normal upper warning threshold
	int_ppO2_max_dil = int_ppO2_max;

	// when in CCR mode, the upper diluent warning threshold gets adjust according to the current setpoint
	if( (char_O_main_status & DECO_MODE_MASK) == DECO_MODE_CCR )
	{
		overlay unsigned int max_dil;

		//  The upper diluent ppO2 threshold is ppO2_GAP_TO_SETPOINT below the setpoint...
		// (the condition protects from negative numbers which would cause a wrap-around)
		max_dil = (char_I_const_ppO2 > ppO2_GAP_TO_SETPOINT) ? (unsigned int)(char_I_const_ppO2 - ppO2_GAP_TO_SETPOINT) : 0;

		// ...but never above int_ppO2_max.
		if( max_dil < int_ppO2_max ) int_ppO2_max_dil = max_dil;

		// We do not need to guard int_ppO2_max_dil against becoming lower than char_I_ppO2_min because the check
		// against char_I_ppO2_min is done first and will then raise a low warning and inhibit further checks.
	}

	// check for safe range of pure oxygen
	if		( int_O_O2_ppO2       >=           int_ppO2_max     ) int_O_O2_ppO2       |= INT_FLAG_WARNING + INT_FLAG_HIGH;

	// check for safe range of breathed gas
	if		( int_O_breathed_ppO2 <=           int_ppO2_min     ) int_O_breathed_ppO2 |= INT_FLAG_WARNING + INT_FLAG_LOW;
	else if ( int_O_breathed_ppO2 >=           int_ppO2_max     ) int_O_breathed_ppO2 |= INT_FLAG_WARNING + INT_FLAG_HIGH;
	else if ( char_O_main_status  &            DECO_MODE_LOOP   ) ; // no attention generated in loop modes
	else if ( int_O_breathed_ppO2 >=   ppO2_ATTENTION_THRESHOLD ) int_O_breathed_ppO2 |= INT_FLAG_ATTENTION;

	// check for safe range of pure diluent
	if		( int_O_pure_ppO2 <= (unsigned int)char_I_ppO2_min  ) int_O_pure_ppO2     |= INT_FLAG_WARNING + INT_FLAG_LOW;
	else if ( int_O_pure_ppO2 >=               int_ppO2_max     ) int_O_pure_ppO2     |= INT_FLAG_WARNING + INT_FLAG_HIGH;
	else if ( int_O_pure_ppO2 >=               int_ppO2_max_dil ) int_O_pure_ppO2     |= INT_FLAG_ATTENTION;

	// check for safe range of calculated pSCR loop gas
	if		( int_O_pSCR_ppO2 <=               int_ppO2_min     ) int_O_pSCR_ppO2     |= INT_FLAG_WARNING + INT_FLAG_LOW;
	else if ( int_O_pSCR_ppO2 >=               int_ppO2_max     ) int_O_pSCR_ppO2     |= INT_FLAG_WARNING + INT_FLAG_HIGH;


	// done with the real tissues



	//---- Toggle between Calculation for NDL (bottom time),  -------------------------------------
	//---- Deco Stops, more Deco Stops and Results Gathering  -------------------------------------


	// all following operations target the simulated tissues, so clear flag in bit 7
	tissue_increment = 0;

	// branch to the code for the current phase the deco calculations are in
	switch( char_O_deco_status & DECO_STATUS_MASK )
	{
		overlay unsigned char i;

	case DECO_STATUS_INIT: //---- At surface: Start a new dive ---------------------

		// clear the internal stops table from remains lasting from the last dive
		clear_deco_table();

		// publish the cleared stops table to the display functions
		publish_deco_table();

		// clear the gas needs table
		for(i=0; i<NUM_GAS; ++i)
		{
			int_O_gas_volumes[i]    = 0;
			int_O_tank_pres_need[i] = 0 + INT_FLAG_ZERO;
		}

		// initialize the balancing between N2 and He for later no-fly time calculation
		for(i=0; i<NUM_COMP; ++i)
		{
			split_N2_He[i] = 90;	// assumes 90% of total tissue pressure will be needed for N2
		}
		
		// ** UNDER CONSTRUCTION - temporary code only **
		char_I_gas_change_time = 1;		// TODO: validate proper operation before enabling this options-table parameter		
		char_I_ascent_speed    = 10;	// TODO: validate proper operation before enabling this options-table parameter,
										//       caution: values < 10 may have an impact on the deco calculation run-times!

		// initialize values that are constant during the course of the dive
		float_ascent_speed            = 1.00  * char_I_ascent_speed;
		float_desaturation_multiplier = 0.01  * char_I_desaturation_multiplier;
		float_saturation_multiplier   = 0.01  * char_I_saturation_multiplier;
		float_deco_distance           = 0.01  * char_I_deco_distance;

		// initialize values that will be recalculated later on periodically
		char_O_nullzeit               = 0;	// reset NDL time for the normal plan
		char_O_alternate_nullzeit     = 0;	// reset NDL time for the alternative plan
		int_O_ascenttime              = 0;	// reset ascent time for the normal plan
		int_O_alternate_ascenttime    = 0;	// reset ascent time for the alternative plan
		char_O_deco_warnings          = 0;	// reset all deco warnings
		deco_tissue_vector            = 0;	// reset tissue deco vector
		IBCD_tissue_vector            = 0;	// reset tissue IBCD vector
		NDL_lead_tissue               = 0;	// reset first tissue to look at during NDL calculation

		// tag desaturation time as invalid (it will not be computed during a dive)
		int_O_desaturation_time       = 65535;

		// initialize CNS values
		int_O_normal_CNS_fraction = int_O_alternate_CNS_fraction = int_O_CNS_fraction;

		// Values that should be reset just once for the full real dive.
		// This is used to record the lowest stop for the whole dive,
		// including ACCROSS all simulated ascents.
		low_depth_norm      = low_depth_alt      = 0.0;
		locked_GF_step_norm = locked_GF_step_alt = 0.0;

		//
		// --> code execution continues in state DECO_STATUS_START
		//

	case DECO_STATUS_START: //---- Bottom Time & initial Ascent --------------------
	default:

		// clear the internal(!) stops table
		clear_deco_table();
		
		// initialize the simulated tissues with the current state of the real tissues
		for(i=0; i<NUM_COMP; i++)
		{
			sim_pres_tissue_N2[i] = pres_tissue_N2[i];
			sim_pres_tissue_He[i] = pres_tissue_He[i];
		}

		// Lookup the current gas and store it also as the first gas used.
		// This gas will be used for the bottom segment of the dive and for
		// the period of delayed ascent when calculating fTTS or bailout.
		gas_find_current();

		// setup the calculation ratio's for N2, He and O2 (sim_N2/He/O2_ratio)
		gas_set_ratios();

		// initialize depth in absolute pressure, it is needed by
		// - calc_alveolar_pressures(),
		// - calc_ascent_to_first_stop(), and
		// - calc_hauptroutine_calc_deco()
		sim_pres_respiration = pres_respiration;

		// calculate ppN2 and ppHe from sim_N2/He_ratio (<- tissue_increment has been set to 0)
		calc_alveolar_pressures();

		// calculate the effect of extended bottom time due to delayed ascent
		if( char_O_deco_status & DECO_ASCENT_DELAYED )
		{
			// program interval on simulated tissues (flag bit 7 = 0)
			tissue_increment = char_I_extra_time;

			// update the tissues
			calc_tissues();
		}

		// calculate if we are within no decompression limit (NDL)
		calc_NDL_time();

		// Calculate the initial ascent if in deco. calc_NDL_time() is very fast
		// in detecting being beyond NDL, so there is enough time left in this
		// phase to do the initial ascent calculation.
		if( NDL_time == 0 )
		{
			//--- in deco --------------------------------------------------------

			// calculate ascent to first stop
			calc_ascent_to_first_stop();

			// continue with calculating the stops
			char_O_deco_status &= ~DECO_STATUS_MASK;	// clear status bits and set status bits for
			char_O_deco_status |=  DECO_STATUS_STOPS;	// calculation of stops on next invocation
		}
		else
		{
			//--- within NDL -----------------------------------------------------

			// continue with gathering all results
			char_O_deco_status &= ~DECO_STATUS_MASK;
			char_O_deco_status |=  DECO_STATUS_RESULTS;
		}

		break;


	case DECO_STATUS_STOPS: //---- Calculate Stops ---------------------------------

		// calculate the stops
		calc_hauptroutine_calc_deco();

		// calc_hauptroutine_calc_deco iterates in this phase as long as it is
		// calculating the stops. Once done, it will set the status to doing the
		// results gathering.

		break;


	case DECO_STATUS_RESULTS: //--- Gathering of all Results -----------------------

		// if in normal plan, publish the stops table to the display functions
		if( !(char_O_deco_status & DECO_PLAN_ALTERNATE) ) publish_deco_table();

		// The current depth is needed by calc_CNS_planning() and gas_volumes().
		// As it may be needed in different code blocks below but we don't want
		// it to be in the code multiple times, it's done here on stockpile.
		bottom_depth = (unsigned char)((pres_respiration - pres_surface) * BAR_TO_METER);

		// Calculate the ascent time.
		// When within NDL, potential gas switches will be treated as done "on the fly".
		calc_ascenttime();

		// results to publish depend whether within NDL or in deco
		if( NDL_time )
		{
			//---- within NDL ----------------------------------------------

			// Calculate the initial ascent (not yet done when within NDL) - 
			// just to get potential gas switches into the stops table for use
			// by gas_volumes(). The stops table can be polluted by now because
			// the clean table has already been published to the display
			// functions before.
			calc_ascent_to_first_stop();

			// check which plan we are on
			if( char_O_deco_status & DECO_PLAN_ALTERNATE )
			{
				//---- alternate dive plan ---------------------------------

				// As we are in no stop, CNS at end of dive is more or less
				// the same CNS as we have right now. It's so simple that we
				// don't check if it requested to be computed or not...
				int_O_alternate_CNS_fraction = int_O_CNS_fraction;

				// output NDL time
				char_O_alternate_nullzeit  = NDL_time;

				// clear ascent time
				int_O_alternate_ascenttime = 0;
			}
			else
			{
				//---- normal dive plan ------------------------------------

				// As we are in no stop, CNS at end of dive is more or less
				// the same CNS as we have right now. It's so simple that we
				// don't check if it requested to be computed or not...
				int_O_normal_CNS_fraction = int_O_CNS_fraction;

				// output NDL time
				char_O_nullzeit = NDL_time;

				// clear ascent time
				int_O_ascenttime = 0;
			}
		} // NDL
		else
		{
			//---- in DECO -------------------------------------------------

			// check which plan we are on
			if( char_O_deco_status & DECO_PLAN_ALTERNATE )
			{
				//---- alternative plan ----------------------------------------------------

				// clear NDL time
				char_O_alternate_nullzeit  = 0;

				// output ascent time
				int_O_alternate_ascenttime = ascent_time;

				// shall the CNS at the end of the dive be calculated?
				if( char_O_deco_status & DECO_CNS_CALCULATE )
				{
					// calculate the CNS for the predicted ascent, result in sim_CNS_fraction
					calc_CNS_planning();

					// add current CNS value
					sim_CNS_fraction += CNS_fraction;

					// convert to integer value
					convert_sim_CNS_for_display();

					// export result
					int_O_alternate_CNS_fraction = int_sim_CNS_fraction;
				}

			} // alternative plan
			else
			{
				//---- normal plan ---------------------------------------------------------

				// clear NDL time
				char_O_nullzeit  = 0;

				// output ascent time
				int_O_ascenttime = ascent_time;

				// shall the CNS at the end of the dive be calculated?
				if( char_O_deco_status & DECO_CNS_CALCULATE )
				{
					// calculate the CNS for the predicted ascent, result in sim_CNS_fraction
					calc_CNS_planning();

					// add current CNS value
					sim_CNS_fraction += CNS_fraction;

					// convert to integer value
					convert_sim_CNS_for_display();

					// export result
					int_O_normal_CNS_fraction = int_sim_CNS_fraction;
				}

			} // normal plan
		} // DECO

		// if requested, calculate the required gas volumes and tank pressures at the end of the dive
		if( char_O_deco_status & DECO_VOLUME_CALCULATE ) gas_volumes();

		// signal that the computation cycle is finished
		char_O_deco_status &= ~DECO_STATUS_MASK;

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

	// get the current pressures
	pres_surface     = 0.001  * int_I_pres_surface;
	pres_respiration = 0.001  * int_I_pres_respiration;

	// N2 tissue pressure at surface equilibrium, used for tissue graphics scaling
	N2_equilibrium   = 0.7902 * (pres_surface - ppWater);

	// read the GF settings (they may have been switch between GF/aGF)
	GF_high  = 0.01 * char_I_GF_High_percentage;
	GF_low   = 0.01 * char_I_GF_Low_percentage;
	GF_delta = GF_high - GF_low;

	// get the currently breathed gas mixture
	O2_ratio = 0.01 * char_I_O2_ratio;
	He_ratio = 0.01 * char_I_He_ratio;

	// inert gas ratio (local helper variable)
	IG_ratio = 1.00 - O2_ratio;

	// N2 ratio
	N2_ratio = IG_ratio - He_ratio;

	// precomputed values for ppO2 drop in pSCR loop
	float_pSCR_factor = 0.01 * char_I_PSCR_drop * char_I_PSCR_lungratio;
	pSCR_drop         = IG_ratio * float_pSCR_factor;
}


//////////////////////////////////////////////////////////////////////////////
// Compute stops.
//
// Note: because this can be very long, break on 16 iterations, and set state
//       to DECO_STATUS_FINISHED when finished, or to DECO_STATUS_STOPS when
//       needing to continue.
// Note: because each iteration might be very long too (~ 66 ms in 1.84beta),
//       break the loop when elapsed time exceeds 512 milliseconds.
//
void calc_hauptroutine_calc_deco(void)
{
	overlay unsigned char loop;


	for(loop = 0; loop < 16; ++loop)
	{
		// limit loops to 512ms, using timer 5
		if( tmr5() & (512*32) ) break;

		// calc_nextdecodepth()
		//
		// INPUT  sim_pres_respiration : current depth in absolute pressure
		// OUTPUT sim_depth_limit      : depth of next stop in meters
		// RETURN true if a stop is needed
		//
		// The function manages gas changes by itself, including priming
		// the deco stop with the configured gas change time.
		//
		if( calc_nextdecodepth() )
		{
			if( sim_depth_limit == 0 ) goto Surface;	// this check should not bee needed as in
														// this case the RETURN value will be false

			//---- stop required at sim_depth_limit -------------------------------------

			// convert stop depth in meters to absolute pressure
			sim_pres_respiration = sim_depth_limit * METER_TO_BAR + pres_surface;

			// add one minute to the current stop, or add a new stop,
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


		//---- as one minute as passed now, update the tissues ----------------------

		// program 1 minute interval on simulated tissues (Flagbit 7 = 0)
		tissue_increment = 1;

		// compute current ppN2 and ppHe
		calc_alveolar_pressures();

		// update the tissues
		calc_tissues();
	}
}


//////////////////////////////////////////////////////////////////////////////
// Calculate ascent to first deco stop.
//
//
// Modified: sim_pres_respiration : current depth in ascent and deco simulation, in bar absolute pressure
//
void calc_ascent_to_first_stop(void)
{
	overlay unsigned char fast      = 1;	// 1 = 1 minute steps,  0 = 2 seconds steps
	overlay unsigned char gaschange = 0;	// 1 = do a gas change, 0 = no better gas available


	//---- Loop until first deco stop or surface is reached ----------
	for(;;)
	{
		// depth in absolute pressure we came from
		overlay float old_deco = sim_pres_respiration;

		// try ascending 1 full minute (fast) or 2 seconds (!fast)
		if	( fast ) sim_pres_respiration -=  float_ascent_speed       * METER_TO_BAR;	// 1 min at float_ascent_speed ( 5 .. 10  m/min)
		else         sim_pres_respiration -= (float_ascent_speed/30.0) * METER_TO_BAR;	// 2 sec at float_ascent_speed (17 .. 33 cm/min)

		// but don't go over surface
		if( sim_pres_respiration < pres_surface ) sim_pres_respiration = pres_surface;

		// compute current ceiling of the simulated tissues
		if   ( char_I_deco_model != 0 ) calc_limit(GF_low);
		else                            calc_limit(1.0);

		// did we overshoot the first deco stop?
		if( sim_pres_respiration < (sim_ceiling + pres_surface) )
		{
			// YES - back to last depth below first stop
			sim_pres_respiration = old_deco;

			// switch to 2 seconds ascent if not yet in, else done
			if( fast )
			{
				fast = 0;				// retry with 2 seconds ascent steps
				continue;
			}
			else
			{
				break;					// done...
			}
		}

		// If code execution passes along here, we did not overshoot the first stop.

		// did we reach the surface? if yes, done!
		if( sim_pres_respiration == pres_surface ) break;

		// depth in meters where we are now (no round-up)
		sim_depth_limit = (unsigned char)((sim_pres_respiration - pres_surface) * BAR_TO_METER);

		// Check if there is a better gas to switch to, but only in alternative plan mode
		// or if override is set. If yes, introduce a stop for the gas change.
		if( (char_O_deco_status & DECO_PLAN_ALTERNATE) || (char_O_main_status & DECO_GASCHANGE_OVRD) )
		if( gas_find_better() )
		{
			// depth in meters we came from
			overlay unsigned char old_depth_limit = (unsigned char)((old_deco - pres_surface) * BAR_TO_METER);			

			// adjust sim_depth_limit to the gas change depth, but not deeper than the depth we came from
			sim_depth_limit = (sim_gas_last_depth < old_depth_limit) ? sim_gas_last_depth : old_depth_limit;

			// create a stop for the gas change
			update_deco_table(char_I_gas_change_time);

			// set the new calculation values for N2, He and O2
			gas_set_ratios();

			// signal to create a stop for the gas change and update the tissues
			gaschange = char_I_gas_change_time;

			// Adjust the depth for the tissue update to the stop depth. In case of fast mode, this
			// imposes that the ascent from the 'old_deco' depth to this stop took 1 minute although
			// we might have only ascended one or two meters...
			sim_pres_respiration = sim_depth_limit * METER_TO_BAR + pres_surface;
		}

		// Did one minute pass by and/or do we have a gas change?
		// Remark: The 2 seconds ascent iterations towards the first deco stop in !fast speed may take
		// up to 28 seconds in total - for this rough half of a minute no tissue updates will be computed.
		// Well, it could be done by setting tissue_increment = 0 in !fast condition and making calls to
		// calc_alveolar_pressures() and calc_tissues() - see code commented out below.
		if( fast || gaschange )
		{
			// program interval on simulated tissues (flag bit 7 = 0)
			tissue_increment = fast + gaschange;

			// clear gas change signal
			gaschange = 0;
	//	}
	//	else
	//	{
	//		// program 2 seconds interval on simulated tissues (flag bit 7 = 0)
	//		tissue_increment = 0;
	//	}
	//	{
			// compute ppN2/ppHe for current depth from sim_pres_respiration
			calc_alveolar_pressures();
			
			// update the tissues
			calc_tissues();
		}
	}
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


	for (ci=0;ci<NUM_COMP;ci++)				// iterate through all compartments
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

				if(		((temp_tissue_N2 > 0.0) && (temp_tissue_He < 0.0))		// check for counter diffusion
					||	((temp_tissue_N2 < 0.0) && (temp_tissue_He > 0.0)) )
				{
					IBCD_tissue_vector |= (1 << ci);	// tag tissue as experiencing mentionable IBCD
				}
			}


			// keep the saturating / desaturating flags from last invocation
			char_O_tissue_N2_saturation[ci] &= 128;
			char_O_tissue_He_saturation[ci]	&= 128;

			// flip the flags applying a hysteresis of HYST (actual value: see #define of HYST)
				 if( temp_tissue_N2 > +HYST ) char_O_tissue_N2_saturation[ci] = 128; // set flag for tissue pressure is increasing
			else if( temp_tissue_N2 < -HYST ) char_O_tissue_N2_saturation[ci] =   0; // clear flag (-> tissue pressure is decreasing)

				 if( temp_tissue_He > +HYST ) char_O_tissue_He_saturation[ci] = 128; // set flag for tissue pressure is increasing
			else if( temp_tissue_He < -HYST ) char_O_tissue_He_saturation[ci] =   0; // clear flag (-> tissue pressure is decreasing)


			// For N2 tissue display purpose:
			// Scale tissue press so that saturation in 70m on AIR gives a value of approx. 80.
			// The surface steady-state tissue loading of [0.7902 * (pres_respiration - ppWater)] bar
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


	// set   deco flag if we are in deco and at least one of the real tissues is off-gassing
	// clear deco flag if all of the real tissues are on-gassing
	if      ( (char_O_nullzeit == 0) &&  deco_tissue_vector ) char_O_deco_warnings |=  DECO_FLAG;
	else if (                           !deco_tissue_vector ) char_O_deco_warnings &= ~DECO_FLAG; 
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
//        sim_ceiling            : ceiling in bar  relative pressure (only in simulated tissues context)
//        ceiling                : ceiling in bar  relative pressure (only in real      tissues context)
//        int_O_ceiling          : ceiling in mbar relative pressure (only in real      tissues context)
//        int_O_gradient_factor  : gradient factor in %              (only in real      tissues context)
//
// Modified:
//        char_O_deco_warnings   : for IBCD, microbubbles and outside warning (only in real tissues context)
//
static void calc_limit(PARAMETER float GF_parameter)
{
	overlay float lead_tissue_limit = 0.0;
	overlay float lead_supersat     = 0.0;

	overlay unsigned char lead_tissue_no = 0;


	// check context
	if( tissue_increment & TISSUE_FLAG )
	{
		// clear IBCD, microbubbles and outside warning flags (locked warnings will be preserved)
		char_O_deco_warnings &= ~(DECO_WARNING_IBCD + DECO_WARNING_MBUBBLES + DECO_WARNING_OUTSIDE);
	}


	// loop over all tissues
	for(ci=0; ci<NUM_COMP; ci++)
	{
		overlay float calc_pres_tissue_N2;
		overlay float calc_pres_tissue_He;
		overlay float pres_tissue;
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

		// adapt the coefficients according to the N2/He ratio in the tissue
		var_N2_a = (var_N2_a * calc_pres_tissue_N2 + var_He_a * calc_pres_tissue_He) / pres_tissue;
		var_N2_b = (var_N2_b * calc_pres_tissue_N2 + var_He_b * calc_pres_tissue_He) / pres_tissue;

		// calculate minimum ambient pressure that the tissue can withstand according to straight Buhlmann
		pres_min = (pres_tissue - var_N2_a) * var_N2_b;

		// next calculations are only relevant when invoked on the real tissues
		if( tissue_increment & TISSUE_FLAG )
		{
			overlay float supersat;
			overlay float threshold;

			// calculate current supersaturation value (1.0 = 100%) of this tissue
			supersat = (pres_tissue - pres_respiration) / (pres_tissue - pres_min);

			// check if tissue is in supersaturation
			if( supersat > 0.0 )
			{
				// memorize highest supersaturation found
				if( supersat > lead_supersat ) lead_supersat = supersat;

				// set a threshold value for the microbubbles and outside warnings
				// ToDo: finalize the definition of the threshold
				threshold = 0.02 * ci + 0.9;

				// check if this tissue is likely to develop microbubbles
				// and/or if this tissue is outside of the Buhlmann model
				if( ci <= 5 )
				{
					if( supersat >= threshold )
					{
						char_O_deco_warnings |= (DECO_WARNING_MBUBBLES + DECO_WARNING_MBUBBLES_lock);

						if( supersat >= 1.0 )
						{
							char_O_deco_warnings |= (DECO_WARNING_OUTSIDE + DECO_WARNING_OUTSIDE_lock);
						}
					}
				}
				else // ci > 5
				{
					if( supersat >= 1.0 )
					{
						char_O_deco_warnings |= (DECO_WARNING_MBUBBLES + DECO_WARNING_MBUBBLES_lock);

						if( supersat >= threshold )
						{
							char_O_deco_warnings |= (DECO_WARNING_OUTSIDE + DECO_WARNING_OUTSIDE_lock);
						}
					}
				}
			}
		}

		// Apply the Eric Baker's varying gradient factor correction if the GF-Model is selected.
		// Note: the correction factor depends both on GF and b, so that can change who is the
		//       leading gas...
		if( char_I_deco_model != 0 ) pres_min =   ( pres_tissue        - (var_N2_a     * GF_parameter) )
		                                        / ( 1.0 - GF_parameter + (GF_parameter / var_N2_b    ) );

		// check if this tissue requires a higher ambient pressure than was found to be needed up to now
		if( pres_min > lead_tissue_limit )
		{
			lead_tissue_limit = pres_min;
			lead_tissue_no    = ci;
		}
	} // for


	// compile outputs
	if( tissue_increment & TISSUE_FLAG )
	{
		//--- real tissues -----------------------------------------------------

		// check if leading tissue is in IBCD condition
		if(    (IBCD_tissue_vector & (1 << lead_tissue_no))
		    && ((pres_tissue_N2[lead_tissue_no] + pres_tissue_He[lead_tissue_no]) > pres_respiration) )
		{
			// leading tissue is in IBCD condition and in super-saturation, so issue a warning.
			char_O_deco_warnings |= (DECO_WARNING_IBCD + DECO_WARNING_IBCD_lock);
		}


		// compute ceiling in bar relative pressure
		ceiling = lead_tissue_limit - pres_surface;

		// convert ceiling to int_O_ceiling in mbar
		if      ( ceiling <=  0 ) int_O_ceiling = 0;
		else if ( ceiling >  16 ) int_O_ceiling = 16000;
	// Compatibility version
	//	else                      int_O_ceiling = (short)(ceiling * 1000);

	// New version: Rounds up to next 10 cm so that the ceiling disappears on the display only when the
	// ceiling limit is really zero. This will coincident then with TTS switching back to NDL time.
		else                      int_O_ceiling = (short)(ceiling * 1000 + 9);


		// convert highest supersaturation found to int_O_gradient_factor in % (1.0 = 100%)
		// limit to 255 because of constraints in ghostwriter code
		if     ( lead_supersat <= 0.0   ) int_O_gradient_factor = 0;
		else if( lead_supersat >  2.545 ) int_O_gradient_factor = 255 + INT_FLAG_WARNING;
		else
		{
			int_O_gradient_factor = (unsigned int)(100 * lead_supersat + 0.5);

			if      ( int_O_gradient_factor >= GF_WARNING_THRESHOLD      )
				int_O_gradient_factor |= INT_FLAG_WARNING;

			else if ( int_O_gradient_factor >= char_I_GF_High_percentage )
				int_O_gradient_factor |= INT_FLAG_ATTENTION;
		}
	}
	else
	{
		//--- simulated tissues ------------------------------------------------
		
		// compute ceiling for the simulated tissues in bar relative pressure
		sim_ceiling = lead_tissue_limit - pres_surface;
	}
}

//////////////////////////////////////////////////////////////////////////////
// calc_NDL_time
//
// calculates the remaining bottom time
//
// NOTE: Erik Baker's closed formula works for Nitroxes. Trimix adds a second
//       exponential term to the M-value equation, making it impossible to
//       invert... So we have to make a fast-simu until we find a better way.
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

	for(i=0; i<NUM_COMP; i++)
	{
		overlay float calc_pres_tissue_N2;
		overlay float calc_pres_tissue_He;
		overlay float pres_tissue;

		overlay unsigned char NDL_tissue;
		overlay unsigned char period = 10;		// start with 10 minute periods


		// check lead tissue from last NDL computation first
		ci = i + NDL_lead_tissue;

		// wrap around after the 16th tissue
		if( ci >= NUM_COMP ) ci -= NUM_COMP;

		// read Buhlmann a and b coefficients for tissue ci
		read_Buhlmann_coefficients();

		// read the loading factors for 10 minute periods
		read_Buhlmann_times(2);
		
		// get the tissue pressures for N2 and He
		calc_pres_tissue_N2 = sim_pres_tissue_N2[ci];
		calc_pres_tissue_He = sim_pres_tissue_He[ci];

		// calculate the total pressure tissue
		pres_tissue = calc_pres_tissue_N2 + calc_pres_tissue_He;


		// simulate an increasing bottom time and check when we hit the NDL ------------------------
		for( NDL_tissue = 0; NDL_tissue < NDL_time; )	// not needed to simulate for longer than the already found NDL
		{
			overlay float var_a;
			overlay float var_b;
			overlay float pres_limit;
			overlay float delta_pres_tissue_N2;
			overlay float delta_pres_tissue_He;


			// adopt a and b coefficients to current N2/He ratio inside the tissue
			var_a = (var_N2_a * calc_pres_tissue_N2 + var_He_a * calc_pres_tissue_He) / pres_tissue;
			var_b = (var_N2_b * calc_pres_tissue_N2 + var_He_b * calc_pres_tissue_He) / pres_tissue;

			// compute pressure limit for tissues under surface pressure conditions
			pres_limit = (var_a + pres_surface / var_b);

			// adopt pressure limit when using the GF extension
			if (char_I_deco_model != 0 ) pres_limit = GF_high * (pres_limit - pres_surface) + pres_surface;

			//---- Check if this tissue is already beyond the NDL
			if( pres_tissue > pres_limit)
			{
				// NO - finish the outer loop,
				i = NUM_COMP;

				// and finish the inner loop
				break;
			}

			// compute delta to tissue pressures in 10 or 1 minutes of time ahead
			delta_pres_tissue_N2 = (ppN2 - calc_pres_tissue_N2) * var_N2_e;
			delta_pres_tissue_He = (ppHe - calc_pres_tissue_He) * var_He_e;

			// apply safety factors to the pressure deltas
			// NDL can be computed while ascending, so we have to check if we are saturating or desaturating
			if( delta_pres_tissue_N2 > 0.0 ) delta_pres_tissue_N2 *= float_saturation_multiplier;
			else                             delta_pres_tissue_N2 *= float_desaturation_multiplier;

			if( delta_pres_tissue_He > 0.0 ) delta_pres_tissue_He *= float_saturation_multiplier;
			else                             delta_pres_tissue_He *= float_saturation_multiplier;

			// Simulate off-gassing while going to surface
			// TODO !
			// delta_pres_tissue_N2 -= exp( ... ascent time ... ppN2...)
			// delta_pres_tissue_He -= exp( ... ascent time ... ppHe...)

			// within NDL now, but still within in 10 or 1 minutes from now?
			if( pres_tissue + delta_pres_tissue_N2 + delta_pres_tissue_He <= pres_limit )
			{
				// YES - apply the pressure deltas to tissues
				calc_pres_tissue_N2 += delta_pres_tissue_N2;
				calc_pres_tissue_He += delta_pres_tissue_He;
				
				// update the overall tissue pressure
				pres_tissue = calc_pres_tissue_N2 + calc_pres_tissue_He;

				// increment the NDL
				NDL_tissue += period;

				// do next loop
				continue;
			}

			// NO - if delta pressures were for 10 minutes of time ahead, try with 1 minute ahead
			if( period == 10 )
			{
				// reduce period to 1 minute
				period = 1;

				// read the loading factors for 1 minute periods
				read_Buhlmann_times(1);

				// do next loop
				continue;
			}

			// NO - not even within NDL in just one more minute, so make a linear approx for the last minute
			// (make a meaningful rounding of NDL, but ONLY if positive: negative casted to unsigned is bad)
			if( pres_limit > pres_tissue )
				NDL_tissue += (unsigned char)(0.5 +    (pres_limit           - pres_tissue         )
			                                  / (delta_pres_tissue_N2 + delta_pres_tissue_He) );

			// finish the inner loop
			break;
		}

		// is the current NDL short than the shortest so far?
		if ( NDL_tissue < NDL_time )
		{
			// keep the current's tissue NDL as the new shortest NDL
			NDL_time = NDL_tissue;

			// store the causing tissue
			new_NDL_lead_tissue = ci;
		}
		
		// if NDL is > 0 the outer loop will continues with the next tissue
		// if NDL found to be overrun, outer loop will be terminated through i = NUM_COMP statement
	}

	// store the NDL dominating tissue for to start with in the next NDL calculation
	NDL_lead_tissue = new_NDL_lead_tissue;
}

//////////////////////////////////////////////////////////////////////////////
// calc_ascenttime
//
// Sum up ascent from bottom to surface at float_ascent_speed,
// but 1 minute per meter for the final ascent, and all stops.
//
// Input:  char_I_depth_last_deco
//         pres_respiration
//         pres_surface
//         float_ascent_speed
//         internal_deco_depth[]
//
// Output: ascent_time
//
static void calc_ascenttime(void)
{
	overlay unsigned char x;


	// preset final ascent
	overlay float final  = (float)char_I_depth_last_deco;

	// calculate depth
	overlay float ascent = (pres_respiration - pres_surface) * BAR_TO_METER;

	// check if we are already in final ascent
	if (ascent <= final)
	{
		// yes - all ascent is final ascent
		final  = ascent;
		ascent = 0.0;
	}
	else
	{
		// no - subtract final ascent part from overall ascent
		ascent -= final;

		// compute time for ascent part without final ascent
		ascent /= float_ascent_speed;
	}

	// add 1 minute for each meter of final ascent
	ascent += final;

	// convert to integer
	ascent_time = (unsigned short)(ascent + 0.5);

	// add all stop times
	for(x=0; x<NUM_STOPS && internal_deco_depth[x]; x++)
		ascent_time += (unsigned short)internal_deco_time[x];

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

	for(x=0; x<NUM_STOPS; ++x)
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
// to have reached the end of the list needs always to be depth == 0.
//
// Input:   sim_depth_limit  : stop's depth, in meters.
//          sim_gas_last_used : gas used at stop, as index 1..5 or 0 for gas 6
//          PARAMETER time_increment    : number of minutes to add to the stop
//
// Updated: internal_deco_depth[] : depth    (in meters)  of each stop
//          internal_deco_time [] : time     (in minutes) of each stop
//          internal_deco_gas  [] : gas used (index 1-5)  at each stop
//
static unsigned char update_deco_table(PARAMETER unsigned char time_increment)
{
	overlay unsigned char x;

	assert( sim_depth_limit > 0 );		// No stop at surface...

	// loop through internal deco table
	for(x=0; x<NUM_STOPS; ++x)
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
			// Else a limit of 254 would account because of constrains in calc_CNS_planning().
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
			internal_deco_gas[x]   = sim_gas_last_used;		// ... gas
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
// Inputs:  int_I_pres_surface, ppWater, char_I_desaturation_multiplier
// Outputs: int_O_desaturation_time, int_O_nofly_time
//
// Helper function
//
void calc_desaturation_time_helper(void)
{
	if( pres_actual > pres_target )		// check if actual pressure is higher then target pressure
	{									// YES - compute remaining time
		overlay	float pres_ratio;

		pres_ratio = pres_actual / pres_target;

		// Compute desaturation time with result rounded up to multiples of 10 minutes.
		// Main purpose is to avoid confusion, because the times do not clock down in
		// one minute steps any more but get constantly re-computed according to current
		// ambient pressure and may therefor make steps of several minutes forwards and
		// backwards as ambient pressure rises and falls.
		int_time = (unsigned int)( (var_ht * log(pres_ratio) / desat_factor) + 0.9 );
	}
	else
	{									// NO  - desaturation state reached, no remaining time
		int_time = 0;
	}
}

/////////////////////////////////////////////////////////////////////////////
// Main function
//
void calc_desaturation_time(void)
{
	assert( 800 < int_I_pres_surface             && int_I_pres_surface             < 1100 );
	assert( 0   < char_I_desaturation_multiplier && char_I_desaturation_multiplier <= 100 );

	// fraction of inert gases in respired air
	N2_ratio       = 0.7902;
	He_ratio       = 0.0;

	// surface pressure in bar
	pres_surface   = 0.001    * int_I_pres_surface;

	// partial pressure of N2 in respired air
	N2_equilibrium = N2_ratio * (pres_surface - ppWater);

	// pre-computed term for later use: 10 [Min] * 0.01 [%] * 0.6931 [=log(2)] * ...
	desat_factor   = 0.06931  * char_I_desaturation_multiplier * SURFACE_DESAT_FACTOR;

	// initialize vars
	int_O_desaturation_time = 0;
	int_O_nofly_time        = 0;


	for(ci=NUM_COMP; ci>0;)
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
		var_ht      = var_N2_ht;

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

		// initialize search direction
		search_direction = 0;

		for(;;)
		{
			// N2: actual amount of tissue pressure above equilibrium.
			pres_actual = pres_tissue_N2[ci] - N2_equilibrium;

			// N2: half-time of the current tissue
			var_ht      = var_N2_ht;

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


	// Clear the microbubbles warning when the current gradient factor is < GF_WARNING_THRESHOLD.
	// As the locked warning will stay set, this will cause the warning be be displayed in attention
	// color instead of warning color.
	if( int_O_gradient_factor < GF_WARNING_THRESHOLD )
		char_O_deco_warnings &= ~DECO_WARNING_MBUBBLES;

	// clear some warnings when the desaturation time has become zero
	if( int_O_desaturation_time == 0 )
		char_O_deco_warnings &= ~(   DECO_WARNING_IBCD     + DECO_WARNING_IBCD_lock
		                           + DECO_WARNING_MBUBBLES + DECO_WARNING_MBUBBLES_lock
		                           + DECO_WARNING_OUTSIDE  + DECO_WARNING_OUTSIDE_lock  );

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
// Modified: tissue pressures
//           CNS value
//           ceiling and current GF
//
static void calc_interval(PARAMETER unsigned char time_interval)
{
	overlay unsigned char time;


	assert( 800 <  int_I_pres_surface             && int_I_pres_surface             <  1100 );
	assert( 100 <= char_I_saturation_multiplier   && char_I_saturation_multiplier   <  200  );
	assert( 0   <  char_I_desaturation_multiplier && char_I_desaturation_multiplier <= 100  );


	// setup input data for deco routines
	pres_respiration = pres_surface = 0.001 * int_I_pres_surface ;

	N2_ratio       = 0.7902;									// according to Buhlmann
	N2_equilibrium = N2_ratio * (pres_surface     - ppWater);	// used for N2 tissue graphics scaling
	ppN2           = N2_ratio * (pres_respiration - ppWater);
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
		tissue_increment = 127 | TISSUE_FLAG;
		calc_tissues();

		// determine the remaining part
		time -= 127;
	}

	// program the remaining part (or full part if not exceeding 127 minutes)
	tissue_increment = time | TISSUE_FLAG;

	// update the N2 and He pressures in the tissues for the remaining part of the time interval
	calc_tissues();


	// Calculate CNS:
	// To speed up things and because on most invocations of this code char_I_dive_interval
	// is a multiple of 10 minutes, we loop the loop-counter down using two speeds.

	time = time_interval;

	while ( time )
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


	// calculate ceiling (for a GF high of 100%) and gradient factor
	calc_limit(1.0);
}


//////////////////////////////////////////////////////////////////////////////
// calc_CNS_increment
//
// Input:  char_ppO2        : current ppO2 [decibars]
//         tissue_increment : time increment and tissue selector
//
// Output: CNS_fraction_inc : increment of the CNS value
//
void calc_CNS_increment(void)
{
	overlay float time_factor = 1.0;	// default is 2sec

	assert( char_ppO2 > 15 );

	// adjust time factor if minute-based stepping is commanded, mask out flag bit
	if( tissue_increment & TIME_MASK ) time_factor = 30.0 * (float)(tissue_increment & TIME_MASK);

	//------------------------------------------------------------------------
	// Don't increase CNS below 0.5 bar, but keep it steady.
	if      (char_ppO2 <  50) CNS_fraction_inc = 0.0;		// no CNS increase below 0.5 bar ppO2
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
	else if (char_ppO2 < 172) CNS_fraction_inc = time_factor*0.00102;
	else if (char_ppO2 < 177) CNS_fraction_inc = time_factor*0.00136;
	else if (char_ppO2 < 182) CNS_fraction_inc = time_factor*0.00180;
	else if (char_ppO2 < 187) CNS_fraction_inc = time_factor*0.00237;
	else if (char_ppO2 < 192) CNS_fraction_inc = time_factor*0.00310;
	else if (char_ppO2 < 198) CNS_fraction_inc = time_factor*0.00401;
	else if (char_ppO2 < 203) CNS_fraction_inc = time_factor*0.00517;
	else if (char_ppO2 < 233) CNS_fraction_inc = time_factor*0.0209;
	else                      CNS_fraction_inc = time_factor*0.0482; // value for 2.5 bar, used for 2.33 bar and above
}

//////////////////////////////////////////////////////////////////////////////
// calc_CNS_planning
//
// Compute CNS increase during predicted ascent
//
// Input:   internal_deco_time[], internal_deco_depth[], internal_deco_gas[]
// Output:  sim_CNS_fraction
//
void calc_CNS_planning(void)
{
	// null sim_CNS_fraction
	sim_CNS_fraction = 0.0;

	//---- CCR mode : do the full TTS at once ---------------------------------

	if( ((char_O_deco_status & DECO_MODE_MASK) == DECO_MODE_CCR) )
	{
		overlay unsigned short t;						// needs 16 bits here !

		// get current ppO2 from sensors or setpoint
		char_ppO2 = char_I_const_ppO2;

		// calculate CNS% for the period of additional staying at bottom depth (fTTS / delayed ascent)
		if( char_O_deco_status & DECO_ASCENT_DELAYED)
		{
			tissue_increment = char_I_extra_time;		// must be limited to 127, is limited by range of char_I_extra_time
			calc_CNS_increment();						// calculate the CNS increment
			sim_CNS_fraction += CNS_fraction_inc;		// sum up
		}

		// get the ascent time dependent on the current plan +++
		t = (char_O_deco_status & DECO_PLAN_ALTERNATE) ? int_O_alternate_ascenttime : int_O_ascenttime;

		// start simulating CNS% in chunks of 127 minutes
		tissue_increment = 127;

		while( t > 127 )
		{
			t -= 127;									// tissue_increment is limited to 127 minutes because of flag in bit 7
			calc_CNS_increment();						// calculate CNS in chunks of full 127 minutes
			sim_CNS_fraction += CNS_fraction_inc;		// sum up
		}

		tissue_increment = (char)t;						// get the remaining minutes <= 127
		calc_CNS_increment();							// calculate CNS for the remaining minutes
		sim_CNS_fraction += CNS_fraction_inc;			// sum up
	}
	else //---- OC mode and pSCR without sensors: have to follow all gas switches... -----
	{
		overlay float float_actual_ppO2;
		overlay float abs_pres;

		overlay unsigned char stop_depth;
		overlay unsigned char last_gas;
		overlay unsigned char i;						// stop table index


		// retrieve bottom gas: 1-5 for the configured gases or 0 for the manually set gas
		last_gas = sim_gas_last_used = sim_gas_first_used;

		// get the calc_N2/He/O2_ratios of the bottom gas
		gas_set_ratios();

		// calculate absolute pressure
		abs_pres = pres_surface + bottom_depth * METER_TO_BAR;

		// calculate OC ppO2 (ppWater omitted here on purpose)
		float_actual_ppO2 = abs_pres * sim_O2_ratio;

		// correct ppO2 in case of pSCR mode by drop
		if( char_O_deco_status & DECO_MODE_PSCR ) float_actual_ppO2 -= sim_pSCR_drop;

		// convert ppO2 from float to char
		if      ( float_actual_ppO2 < 0.0   ) char_ppO2 =   0;
		else if ( float_actual_ppO2 > 2.545 ) char_ppO2 = 255;
		else                                  char_ppO2 = (unsigned char)(100 * float_actual_ppO2 + 0.5);


		// simulate extended bottom time (fTTS) / delay before ascent (bailout) if configured
		if( char_O_deco_status & DECO_ASCENT_DELAYED )
		{
			tissue_increment  = char_I_extra_time;	// must be limited to 127, is limited by range of char_I_extra_time
			calc_CNS_increment();					// calculate the CNS increment
			sim_CNS_fraction += CNS_fraction_inc;	// sum up
		}


		// For simplicity reason (non-linearity of the relation between ppO2 and CNS increments), the
		// whole ascent is calculated with bottom ppO2. This errs, but it does so to the safe side.

		// calculate ascent time (integer division and generous round-up)
		tissue_increment = bottom_depth / char_I_ascent_speed + 1;

		// ** commented out - not needed when char_I_ascent_speed is limited to a minimum
		// **                 of 2.something, it is indeed limited to a minimum of 5.
		//
		// // limit tissue_increment to 127 minutes
		// if( tissue_increment > 127 ) tissue_increment = 127;

		// simulate the CNS increase
		calc_CNS_increment();						// calculate the CNS increment
		sim_CNS_fraction += CNS_fraction_inc;		// sum up


		//---- Stops ---------------------------------------------------------
		
		for(i=0; i<NUM_STOPS; ++i)
		{
			// get the depth of the stop
			stop_depth = internal_deco_depth[i];

			// did we reach the last entry (depth = 0)? if yes, done
			if (stop_depth == 0) break;

			// get the duration of the stop and the gas breathed
			tissue_increment  = internal_deco_time[i];
			sim_gas_last_used = internal_deco_gas[i];

			// do we have a gas switch?
			if( sim_gas_last_used != last_gas )
			{
				// yes - get new calculation ratios
				gas_set_ratios();

				// remember new gas as last gas
				last_gas = sim_gas_last_used;
			}

			// calculate absolute pressure at stop depth
			abs_pres = pres_surface + stop_depth * METER_TO_BAR;

			// calculate OC ppO2 (ppWater omitted here on purpose)
			float_actual_ppO2 = abs_pres * sim_O2_ratio;

			// correct ppO2 in case of pSCR mode by drop
			if( char_O_deco_status & DECO_MODE_PSCR ) float_actual_ppO2 -= sim_pSCR_drop;

			// convert ppO2 from float to char
			if      ( float_actual_ppO2 < 0.0   ) char_ppO2 =   0;
			else if ( float_actual_ppO2 > 2.545 ) char_ppO2 = 255;
			else                                  char_ppO2 = (unsigned char)(100 * float_actual_ppO2 + 0.5);

			// ** Currently, stop times per stop entry are limited to 99 minutes in update_deco_table(),
			// ** so the following code block is not needed at times.
			//
			// // tissue_increment is limited to 127 when fed to calc_CNS_increment(),
			// // so if the stop is longer than 127 minutes (but not longer than 254 minutes!)
			// // we need to calculate the CNS in two chunks.
			// if( tissue_increment > 127)
			// {
			//		tissue_increment -= 127;				// subtract full 127 minutes and do the "remaining" minutes first
			//		calc_CNS_increment();					// calculate the CNS increment
			//		sim_CNS_fraction += CNS_fraction_inc;	// sum up
			//		tissue_increment  = 127;				// catch up with the previously subtracted full 127 minutes
			// }

			// calculate CNS% for the stop
			calc_CNS_increment();					// calculate the CNS increment
			sim_CNS_fraction += CNS_fraction_inc;	// sum up
		}
	}
}


//////////////////////////////////////////////////////////////////////////////
// gas_volumes
//
// calculates volumes and required tank fill pressures for each gas.
//
// Input:	bottom_depth			depth of the bottom segment
//			char_I_bottom_time		duration of the bottom segment
//			char_I_extra_time		extra bottom time for fTTS / delayed ascent
//			float_ascent_speed		ascent speed, in meters/minute
//			sim_gas_first_used		the bottom gas (1-5 for configured gases, 0 for the manual gas)
//			internal_deco_depth[]	depth of the stops
//			internal_deco_time[]	duration of the stops
//			internal_deco_gas[]		gas breathed at the stops
//			char_I_bottom_usage		gas consumption during bottom part and initial ascent, in liters/minute
//			char_I_deco_usage		gas consumption during stops and following ascents, in liters/minute
//			char_I_tank_size[]		size of the tanks for gas 1-5, in liters
//			char_I_tank_pres_fill[]	fill pressure of the tanks
//
// Output:	int_O_gas_volumes[]		amount of gas needed, in liters
//			int_O_tank_pres_need[]	in bar, + flags for fast evaluation by dive mode warnings:
//											  2^15: pres_need >= pres_fill
//											  2^14: pres_need >= press_fill * GAS_NEEDS_ATTENTION_THRESHOLD
//											  2^11: pres_need == 0
//											  2^10: pres_need invalid
//
void gas_volumes_helper(void)
{
	// Calculate the gas volume needed at a given depth, time and usage (SAC rate).
	// We use 1.0 for the surface pressure to have stable results when used through
	// the deco calculator (simulation mode).
	volume = (float_depth * METER_TO_BAR + 1.0) * float_time * usage;

	return;
}

void gas_volumes(void)
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
	for(i=0; i<NUM_GAS; ++i) volumes[i] = 0.0;

	// quit for CCR and pSCR mode
	if( char_O_deco_status & DECO_MODE_LOOP ) goto done;


	//---- bottom demand -----------------------------------------------------

	// sim_gas_first_used : gas used during bottom segment (0, 1-5)
	// bottom_depth: depth of the bottom segment

	assert(0 <= sim_gas_first_used && sim_gas_first_used <= NUM_GAS);

	// get the gas used during bottom segment
	stop_gas_last = stop_gas = sim_gas_first_used;

	// set the usage (SAC rate) to bottom usage rate for bottom part and initial ascent
	usage = char_I_bottom_usage;

	// volumes are only calculated for gases 1-5, but not the manually configured one
	if( stop_gas )
	{
		// set the bottom depth
		float_depth = (float)bottom_depth;

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
		gas_volumes_helper();

		// take result
		volumes[stop_gas-1] = volume;
	}

	// initialize stop index with first stop
	i = 0;

	//---- initial ascent demand ---------------------------------------------

	// stop_gas                : gas from bottom segment
	// bottom_depth            : depth of the bottom segment
	// internal_deco_depth[i=0]: depth of the first stop, may be 0 if no stop exists

	// get the data of the first stop	
	stop_depth = internal_deco_depth[i];
	stop_time  = internal_deco_time[i];

	// volumes are only calculated for gases 1-5, but not the manually configured one
	if( stop_gas )
	{
		// compute distance between bottom and first stop
		float_depth = (float)bottom_depth - (float)stop_depth;

		// initial ascent exists only if ascent distance is > 0
		if( float_depth > 0.0 )
		{
			// compute ascent time
			float_time = float_depth / float_ascent_speed;

			// compute average depth between bottom and first stop
			float_depth = (float)bottom_depth - float_depth * 0.5;

			// calculate gas demand
			gas_volumes_helper();

			// add result
			volumes[stop_gas-1] += volume;
		}
	}

	// switch the usage (SAC rate) to deco usage rate
	// for stops, intermediate and final ascent
	usage = char_I_deco_usage;

	// is there a (first) stop? if yes, goto stops processing
	if( stop_depth ) goto stops;

	// add demand of a 3 minutes safety stop at 5 meters, at least for contingency...
	float_time  = 3.0;
	float_depth = 5.0;

	// calculate gas demand
	gas_volumes_helper();

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
		gas_volumes_helper();

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
    
	// do we we have a gas change?
	if( stop_gas_last && (stop_gas != stop_gas_last) )
	{
		// yes - spend an additional char_I_gas_change_time on the old gas
		float_time = (float)char_I_gas_change_time;

		// calculate gas demand
		gas_volumes_helper();

		// add result
		volumes[stop_gas_last-1] += volume;
	}

	// calculate and add demand on new gas for the full stop duration
	if( stop_gas )
	{
		// get the duration of the stop
		float_time = (float)stop_time;

		// calculate gas demand
		gas_volumes_helper();

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
		// set ascent time according to an ascent speed of 1 meter per minute
		float_time = float_depth;

		// set half-way depth
		float_depth *= 0.5;

		// calculate gas demand
		gas_volumes_helper();

		// add result
		volumes[stop_gas-1] += volume;
	}


	//---- convert results for the assembler interface -----------------------------
done:

	for(i=0; i<NUM_GAS; ++i)
	{
		if( volumes[i] >= 65534.5 )
		{
			int_O_gas_volumes[i]	= 65535;
			int_O_tank_pres_need[i]	= 999 + INT_FLAG_WARNING; // 999 bar + warning flag for > pres_fill
		}
		else
		{
			overlay unsigned short tank_pres_fill = 10.0 * (unsigned short)char_I_tank_pres_fill[i];

			// No distinct rounding done here because volumes are not accurate to the single liter anyhow

			// convert gas volumes to integers
			int_O_gas_volumes[i]     = (unsigned short)volumes[i];

			// compute how much pressure in the tank will be needed [in bar]  (integer-division)
			int_O_tank_pres_need[i]  = (unsigned short)(int_O_gas_volumes[i] / char_I_tank_size[i]);

			// limit to 999 bar because of display constraints
			if( int_O_tank_pres_need[i] > 999 ) int_O_tank_pres_need[i] = 999;

			// set flags for fast evaluation by divemode check for warnings
			if     ( int_O_tank_pres_need[i] == 0 )
			{
				// set flag for 0 bar
				int_O_tank_pres_need[i] |= INT_FLAG_ZERO;
			}
			else if( int_O_tank_pres_need[i] >= tank_pres_fill )
			{
				// set warning flag
				int_O_tank_pres_need[i] |= INT_FLAG_WARNING;

			}
			else if( int_O_tank_pres_need[i] >= tank_pres_fill * GAS_NEEDS_ATTENTION_THRESHOLD )
			{
				// set pre-warning flag
				int_O_tank_pres_need[i] |= INT_FLAG_ATTENTION;
			}

			// set invalid flag if there is an overflow in the stops table
			if( char_O_deco_warnings & DECO_WARNING_STOPTABLE_OVERFLOW )
				int_O_tank_pres_need[i] |= INT_FLAG_INVALID;
			
		} // if( volumes[i] )
	} // for
}

//////////////////////////////////////////////////////////////////////////////

void convert_CNS_for_display(void)
{
	if		( CNS_fraction <  0.01  ) int_O_CNS_fraction = 0;
	else if ( CNS_fraction >= 9.985 ) int_O_CNS_fraction = 999 + INT_FLAG_WARNING;
	else
	{
		// convert float to integer
		int_O_CNS_fraction = (unsigned short)(100 * CNS_fraction + 0.5);

		// set warnings
		if		( int_O_CNS_fraction >= CNS_WARNING_THRESHOLD   ) int_O_CNS_fraction |= INT_FLAG_WARNING;
		else if	( int_O_CNS_fraction >= CNS_ATTENTION_THRESHOLD ) int_O_CNS_fraction |= INT_FLAG_ATTENTION;
	}
}

//////////////////////////////////////////////////////////////////////////////

void convert_sim_CNS_for_display(void)
{
	if		( sim_CNS_fraction <  0.01  ) int_sim_CNS_fraction = 0;
	else if ( sim_CNS_fraction >= 9.985 ) int_sim_CNS_fraction = 999 + INT_FLAG_WARNING;
	else
	{
		// convert float to integer
		int_sim_CNS_fraction = (unsigned short)(100 * sim_CNS_fraction + 0.5);

		// set warning flag if CNS is >= 100%
		if      ( int_sim_CNS_fraction >= CNS_WARNING_THRESHOLD    ) int_sim_CNS_fraction |= INT_FLAG_WARNING;
		else if ( int_sim_CNS_fraction >= CNS_ATTENTION_THRESHOLD  ) int_sim_CNS_fraction |= INT_FLAG_ATTENTION;

		// set invalid flag if there is an overflow in the stops table
		if( char_O_deco_warnings & DECO_WARNING_STOPTABLE_OVERFLOW ) int_sim_CNS_fraction |= INT_FLAG_INVALID;
	}
}

//////////////////////////////////////////////////////////////////////////////
// push_tissues_to_vault & pull_tissues_from_vault
//
// ATTENTION: Do not use from inside the deco engine!
//            The vault is exclusively reserved to back-up and restore the real
//            tissues and related data when entering / leaving simulation mode!
//

void push_tissues_to_vault(void)
{
	overlay unsigned char x;

	cns_vault_float      = CNS_fraction;
	deco_warnings_vault  = char_O_deco_warnings;

	for (x=0;x<NUM_COMP;x++)
	{
		pres_tissue_N2_vault[x] = pres_tissue_N2[x];
		pres_tissue_He_vault[x] = pres_tissue_He[x];
	}
}

void pull_tissues_from_vault(void)
{
	overlay unsigned char x;

	CNS_fraction         = cns_vault_float;
	char_O_deco_warnings = deco_warnings_vault;

	convert_CNS_for_display();

	locked_GF_step_norm  = GF_delta / low_depth_norm;
	locked_GF_step_alt   = GF_delta / low_depth_alt;
	
	for (x=0; x<NUM_COMP; x++)
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
