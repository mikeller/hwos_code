#ifdef xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
;
;    shared_definitions.h							REFACTORED VERSION	V2.95a1
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
;    Copyright (c) 2010, JD Gascuel.
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
;  2011-01-20: [jDG] Creation.
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
    // C-style declarations:
#   ifndef TEST_MAIN
#       define VAR_UCHAR(n)      extern unsigned  char n
#       define TAB_UCHAR(n,size) extern unsigned  char n[size]
#       define VAR_UINT(n)       extern unsigned short n
#       define TAB_UINT(n,size)  extern unsigned short n[size]
#   else
#       define VAR_UCHAR(n)      unsigned  char n
#       define TAB_UCHAR(n,size) unsigned  char n[size]
#       define VAR_UINT(n)       unsigned short n
#       define TAB_UINT(n,size)  unsigned short n[size]
#   endif
#else
    ;-------------------------------------------------------------------------
    ; ASM-style declarations:
#define VAR_UCHAR(n)       n    res     1
#define TAB_UCHAR(n,size)  n    res     size
#define VAR_UINT(n)        n    res     2
#define TAB_UINT(n,size)   n    res     2*size
#endif


#ifdef xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
    Define model dimensions.
    NUM_COMP  is the number of compartiments in the Bühlmann ZH-L16 model, ie 16.
    NUM_STOPS is the maximum number of stops computed by decoplanning. 
              Note that the deepest stop is roughly limited to 3m * NUM_STOPS
                   (this is assuming all stops up to the surface are used).
              Note also that if the table overflow, extra stops are ignored,
                   and not reported in TTS summing.
    NUM_GAS   is the number of (potentially) active gas considered during
              ascent simulation.
#endif
#define NUM_COMP    0x10
#define NUM_STOPS   0x20
#define NUM_GAS     5


#ifdef __18CXX
    //---- BANK 3 DATA -------------------------------------------------------
    // Gather all data C-code --> ASM-code
#   pragma udata overlay bank3=0x300
#else
    ; In ASM, put the same bank, in overlay mode, at the same address
bank3   udata_ovr  0x300
#endif

VAR_UINT  (int_O_gtissue_press);					// pressure of leading compartment

VAR_UINT  (int_O_desaturation_time);       			// time until tissues desaturated to 5% remains, in minutes
VAR_UINT  (int_O_nofly_time);			   			// altitude / no-fly waiting time time in minutes

VAR_UINT  (int_O_ascenttime);              			// time-to-surface (TTS) in minutes
VAR_UINT  (int_O_alternate_ascenttime);    			// TTS for the alternative dive plan

VAR_UINT  (int_O_CNS_fraction);            			// current CNS%
VAR_UINT  (int_O_normal_CNS_fraction); 	   			// CNS% at end of dive in normal dive plan
VAR_UINT  (int_O_alternate_CNS_fraction);  			// CNS% at end of dive in alternative plan

VAR_UINT  (int_O_gradient_factor);        			// current gradient factor in %

VAR_UCHAR (char_O_nullzeit);               			// remaining NDL time in minutes
VAR_UCHAR (char_O_alternate_nullzeit);	   			// remaining NDL time for the alternative dive plan

VAR_UCHAR (char_O_main_status);						// setup of the deco engine regarding the real tissue   computations
VAR_UCHAR (char_O_deco_status);            			// setup of the deco engine regarding the decompression computations

VAR_UCHAR (char_O_gtissue_no);             			// number of the leading compartment

VAR_UCHAR (char_O_EAD);                    			// equivalent air      depth (EAD) of breathed gas
VAR_UCHAR (char_O_END);                    			// equivalent narcosis depth (END) of breathed gas

VAR_UCHAR (char_O_first_deco_depth);        		// depth of first stop (deco or gas change)
VAR_UCHAR (char_O_first_deco_time) ;        		// duration of first stop

TAB_UCHAR (char_O_deco_depth, NUM_STOPS);   		// stops table: depth, ...
TAB_UCHAR (char_O_deco_time,  NUM_STOPS);   		// ... duration, and
TAB_UCHAR (char_O_deco_gas,   NUM_STOPS);   		// ... gas breathed

TAB_UCHAR (char_O_deco_time_for_log, NUM_STOPS); 	// variant of the stops table for logging purpose

TAB_UCHAR (char_O_tissue_N2_saturation, NUM_COMP); 	// nitrogen tissue pressures for display purpose
TAB_UCHAR (char_O_tissue_He_saturation, NUM_COMP); 	// helium   tissue pressures for display purpose

VAR_UCHAR (char_O_deco_warnings);					// vector of warnings generated by the deco engine

TAB_UINT  (int_O_gas_volumes,    NUM_GAS);			// gas volumes    needed in liters
TAB_UINT  (int_O_tank_pres_need, NUM_GAS);			// tank pressures needed in bar
VAR_UINT  (int_O_ceiling);							// ultimate ascent bound in mbar relative pressure

VAR_UINT  (int_O_O2_ppO2);				   			// ppO2 of pure O2 at current depth
VAR_UINT  (int_O_pure_ppO2);						// ppO2 of the current gas or dil if breathed pure
VAR_UINT  (int_O_pSCR_ppO2);			   			// ppO2 calculated in pSCR loop
VAR_UINT  (int_O_breathed_ppO2);					// ppO2 actually breathed (= char_O_pure_ppO2 if in OC)


#ifdef __18CXX
    //---- BANK 4 DATA -------------------------------------------------------
    // Gather all data ASM-code --> C-code
#   pragma udata overlay bank4=0x400
#else
    ; In ASM, put the same bank, in overlay mode, at the same address
bank4   udata_ovr  0x400
#endif

VAR_UINT  (int_I_pres_respiration);        // absolute pressure breathed
VAR_UINT  (int_I_pres_surface);            // absolute pressure at surface

VAR_UCHAR (char_I_current_gas);            // number of gas currently breathed (1..5 for configured gases, 6 for the manual gas)
VAR_UCHAR (char_I_He_ratio);               // helium   ratio of the currently breathed gas
VAR_UCHAR (char_I_O2_ratio);               // oxygen   ratio of the currently breathed gas

VAR_UCHAR (char_I_saturation_multiplier);  // safety factor, 100 = no conservatism, 150 = 50% faster saturation
VAR_UCHAR (char_I_desaturation_multiplier);// safety factor, 100 = no conservatism,  66 = 50% slower desaturation 

VAR_UCHAR (char_I_GF_High_percentage);     // GF model high value
VAR_UCHAR (char_I_GF_Low_percentage);      // GF model low value

VAR_UCHAR (char_I_deco_distance);          // assumed extra depth below required depth for CNS and gas volumes calculations
VAR_UCHAR (char_I_depth_last_deco);        // depth of the last deco stop in meters

VAR_UCHAR (char_I_deco_model);             // deco model selection: 0 = ZH-L16, 1 = ZH-L16-GF (with gradient factors)

VAR_UCHAR (char_I_bottom_depth);           // bottom depth, used for gas volume calculations
VAR_UCHAR (char_I_bottom_time);            // bottom time,  used for gas volume calculations

VAR_UCHAR (char_I_dive_interval);          // duration of surface break before next dive in minutes, used in simulation
VAR_UCHAR (char_I_sim_advance_time);	   // 'fast forward' of dive time, used in simulation (+5 min function)

VAR_UCHAR (char_I_const_ppO2);             // ppO2 reported from sensors or by setpoint

TAB_UCHAR (char_I_deco_gas_change,NUM_GAS); // change depths of the OC gases

TAB_UCHAR (char_I_setpoint_change,NUM_GAS); // change depth for the setpoints in meter
TAB_UCHAR (char_I_setpoint_cbar,  NUM_GAS); // setpoints in cbar

TAB_UCHAR (char_I_deco_O2_ratio,  NUM_GAS); // oxygen ratios of the configured gases, used for deco calculations
TAB_UCHAR (char_I_deco_He_ratio,  NUM_GAS); // helium ratios of the configured gases, used for deco calculations

TAB_UCHAR (char_I_tank_size,      NUM_GAS);	// tank sizes, used for pressure needs calculation
TAB_UCHAR (char_I_tank_pres_fill, NUM_GAS);	// tank fill pressures, used for generating warnings

VAR_UCHAR (char_I_cc_max_frac_o2);	 		// limiter for maximum O2% in loop
VAR_UCHAR (char_I_PSCR_drop);				// pSCR parameter drop [%]
VAR_UCHAR (char_I_PSCR_lungratio);			// pSCR parameter lung ratio [1/x]

VAR_UCHAR (char_I_altitude_wait);			// selector for altitude / no-fly waiting time calculation

VAR_UCHAR (char_I_bottom_usage);            // gas consumption during bottom part and initial ascent   in liters/minute
VAR_UCHAR (char_I_deco_usage);              // gas consumption during deco stops and following ascents in liters/minute

VAR_UCHAR (char_I_extra_time);              // extra bottom time for fTTs and delayed ascent calculation in minutes

VAR_UCHAR (char_I_ppO2_max);				// warning threshold for maximum ppO2 during working phase of the dive
VAR_UCHAR (char_I_ppO2_max_deco);			// warning threshold for maximum ppO2 during deco phase of the dive
VAR_UCHAR (char_I_ppO2_min);				// warning threshold for maximum ppO2 when breathing OC
VAR_UCHAR (char_I_ppO2_min_loop);			// warning threshold for maximum ppO2 when breathing from CCR or pSCR

VAR_UCHAR (char_I_ascent_speed);			// ascent speed in meters/minute
VAR_UCHAR (char_I_gas_change_time);			// extra time spent during a stop for doing a gas change, in minutes


#ifdef xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
// VAR_UCHAR (char_I_step_is_1min);        // Use 1min integration for tissue and CNS.	DELETED ## V2.95 - made local to p2_deco.c
// VAR_UINT  (int_I_temp);                 // new in v101								DELETED ## no fly
// VAR_UINT  (int_I_divemins);             // Dive time (minutes)					 	DELETED ## V2.95 - not used by p2_deco.c
// VAR_UCHAR (char_I_temp);                // new in v101							 	DELETED ## no fly
// VAR_UCHAR (char_I_actual_ppO2);         //										 	DELETED ## V2.94
// VAR_UCHAR (char_I_first_gas);           // Gas used at start of dive (bottom mix) 	DELETED ## V2.95 - made local to p2_deco.c
// VAR_UCHAR (char_I_N2_ratio);            // N2 ratio of the currently breathed gas	DELETED ## V2.95 - not read from ASM, but actually computed by p2_deco.c from H2 and O2 ratio
// VAR_UCHAR (char_O_deco_last_stop);      // Depth reached during deco planning.		DELETED ## V2.95 - not used in ASM
// VAR_UCHAR (temp_bankx400);              // reserved space for temporary variables
#endif
