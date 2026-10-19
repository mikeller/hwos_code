;=============================================================================
;
;   File logbook.inc                          combined next generation V3.08.8
;
;
;   Copyright (c) 2011, JD Gascuel, heinrichs weikamp gmbh, all right reserved.
;=============================================================================
; HISTORY
;  2011-11-12 : [mH] moving from OSTC code


 #ifndef inside_loogbook
	extern	logbook
	extern	log_header_addr_by_index
 #endif


; Buffer for Dive Header Data
#DEFINE header_buffer				buffer2


; Dive Header Layout
;
;       Label						Index	Size  Description
;-----------------------------------------------------------------------------------------
#DEFINE index_header_start			.0		;  2  header start sequence 0xFAFA
#DEFINE index_profile_start_address	.2		;  3  pointer to profile data start in flash
#DEFINE index_profile_end_address	.5		;  3  pointer to profile data end   in flash
#DEFINE index_profile_version		.8		;  1  profile format version
#DEFINE index_profile_byte_count	.9		;  3  number of bytes in profile data
#DEFINE index_date					.12		;  3  date in sequence year, month, day
#DEFINE index_time					.15		;  2  time in sequence hour, minute
#DEFINE index_max_depth				.17		;  2  maximum depth
#DEFINE index_divetime				.19		;  3  dive time in sequence minutes:2, seconds:1
#DEFINE index_min_temp				.22		;  2  minimum temperature during the dive
#DEFINE index_surface_press			.24		;  2  surface pressure during the dive
#DEFINE index_desattime				.26		;  2  desaturation time at end of dive
#DEFINE index_gas1					.28		;  4  gas 1 in sequence O2%, He%, change depth, type
#DEFINE index_gas2					.32		;  4  gas 2 ...
#DEFINE index_gas3					.36		;  4  gas 3 ...
#DEFINE index_gas4					.40		;  4  gas 4 ...
#DEFINE index_gas5					.44		;  4  gas 5 ...
#DEFINE index_firmware				.48		;  2  firmware version used in sequence major, minor
#DEFINE index_battery_voltage		.50		;  2  battery voltage at end of dive
#DEFINE index_samplingrate			.52		;  1  sampling rate of profile data
#DEFINE index_cns_start				.53		;  2  CNS % at begin of dive
#DEFINE index_supersat_start		.55		;  1  supersaturation % at begin of dive
#DEFINE index_supersat_end			.56		;  1  supersaturation % at end   of dive
#DEFINE index_logoffset				.57		;  2  logbook offset
#DEFINE index_batt_percent			.59		;  1  battery % at end of dive
#DEFINE index_sp1					.60		;  2  setpoint 1 in sequence setpoint, change depth
#DEFINE index_sp2					.62		;  2  setpoint 2 ...
#DEFINE index_sp3					.64		;  2  setpoint 3 ...
#DEFINE index_sp4					.66		;  2  setpoint 4 ...
#DEFINE index_sp5					.68		;  2  setpoint 5 ...
#DEFINE index_salinity				.70		;  1  salinity setting %
#DEFINE index_cns_end				.71		;  2  CNS % at end of dive
#DEFINE index_avr_depth				.73		;  2  average depth
#DEFINE index_total_seconds			.75		;  2  total dive time in seconds
#DEFINE index_gf_lo_hi				.77		;  2  GF factors  (if using ZH-L16+GF) in sequence lo, hi
#DEFINE index_factor_sat_desat		.77		;  2  multipliers (if using ZH-L16)    in sequence saturation, desaturation
#DEFINE index_decomodel				.79		;  1  deco model (ZH-L16, ZH-L16+GF)
#DEFINE index_total_dives			.80		;  2  total number of dives logged on unit
#DEFINE index_divemode				.82		;  1  dive mode (OC, CCR, ...)
#DEFINE index_tissue_pres_total		.83		; 16  total    tissue pressures at end of dive (16x uint8) (since FW 3.08, else N2 pressures)
#DEFINE index_tissue_pres_N2		.99		; 64  Nitrogen tissue pressures at end of dive (16x float)
#DEFINE index_tissue_supersat		.163	; 16  tissue   supersaturations at end of dive (16x uint8) (since FW 3.08, else He pressures)
#DEFINE index_tissue_pres_He		.179	; 64  Helium   tissue pressures at end of dive (16x float)
#DEFINE index_last_stop				.243	;  1  depth of the last stop
#DEFINE index_decodistance			.244	;  1  assumed deco distance (not used anymore)
#DEFINE index_hud_data				.245	;  3  last HUD data set received
#DEFINE index_battery_gauge			.248	;  6  battery gauge register at end of dive
#DEFINE index_header_stop			.254	;  2  header stop code 0xFBFB
