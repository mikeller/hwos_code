#ifdef xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
; ============================================================================
; 
;    File configuration.inc                   combined next generation V3.03.4
; 
;    OSTC hwOS Configuration
; 
;    Copyright (c) 2019, HeinrichsWeikamp, all rights reserved.
; ============================================================================
#endif


#ifdef xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
;
; Firmware Version
; ----------------
;
; softwareversion_x			firmware version, major               (1 -   9)
; softwareversion_y			firmware version, minor               (0 -  99)
; softwareversion_beta		0= Release, 1= Beta 1, 2= Beta 2, ... (0 - 255)
;
; NOTE: all values need to be defined in hex!
;
#endif

#define softwareversion_x		0x03
#define softwareversion_y		0x03
#define softwareversion_beta	0x01


#ifdef xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
;
; Firmware Creation and Expiration Date
; -------------------------------------
;
; firmware_creation_year/month/day will be used to initialize the RTC on reboot
;
; firmware_expire_year/month/day   will be used to show firmware version in
;                                  "update Firmware" style after expiry date
;
; NOTE: all values need to be defined in hex!
;
#endif

#define firmware_creation_year	0x13
#define firmware_creation_month	0x04
#define firmware_creation_day	0x0d

#define firmware_expire_year	0x13
#define firmware_expire_month	0x08
#define firmware_expire_day		0x1e


#ifdef xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
;
; global Version Selection
; ------------------------
;
; _hwos_tech_2_TR		compile hwOS in Tech  version for OSTC 2, Plus and TR (with RX functions)
; _hwos_tech_3_cR		compile hwOS in Tech  version for OSTC 3       and cR (with external sensors)
; _hwos_tech			compile hwOS in Tech  version for all models          (does not fit yet)
; _hwos_sport			compile hwos in Sport version
;
#endif

#define _hwos_tech_2_TR


#ifdef xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
;
; Language Selection
; ------------------
;
; _language_1			first or single language,
;						set to 'en', 'de', 'fr', or 'it', defaults to 'en'
;
; _language_2			second language, coding as above or 'none'		mem: approx. 3854 byte in Sport version
; 
#endif

#define _language_1		de
#define _language_2		none


#ifdef xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
;
; Features Selection
; ------------------
;
; _screendump			screen dump function				mem:    334 byte, default: Sport:     included, Tech:     included
; _compass				compass function					mem: 12.488 byte, default: Sport:     included, Tech:     included
; _rx_functions			RX functions (OSTC TR)				mem:  7.942 byte, default: Sport:     included, Tech:     included
; _huge_font			huge font							mem:  3.651 byte, default: Sport:     included, Tech: NOT included
; _helium				Helium (Trimix) gases and diluents	mem:  2.172 byte, default: Sport: NOT included, Tech:     included
; _ccr_pscr				loop modes CCR and pSCR				mem:  4.308 byte, default: Sport: NOT included, Tech:     included
; _external_sensor		external sensor for CCR & pSCR	1)	mem:  3.640 byte, default: Sport: NOT included, Tech:     included
; _cave_mode			cave mode way-out calculation		mem:        byte, default: Sport: NOT included, Tech:     included	## FEATURE IS UNDER CONSTRUCTION YET ##
; _min_depth_option		resettable min. and max. depth		mem:        byte, default: Sport: NOT included, Tech: NOT included
; _ostc_logo			use of a bitmap-based OSTC logo		mem:  1.748 byte, default: Sport: NOT included, Tech: NOT included
;
; 1) needs to be excluded in case _ccr_pscr is excluded, too.
;
; NOTES: - Exclude options by prepending NOT_INCLUDED to the label.
;        - Not all options will fit concurrently if two languages are slected.
;        - Option sizes are based on single language (english), will increase
;          with 2nd language and will differ slightly between languages.
#endif


#ifdef _hwos_tech_2_TR

#define _screendump
#define _compass
#define _huge_font
#define _rx_functions
#define _helium
#define _ccr_pscr


#define NOT_INCLUDED_external_sensor
#define NOT_INCLUDED_cave_mode
#define NOT_INCLUDED_min_depth_option
#define NOT_INCLUDED_ostc_logo

#endif


#ifdef _hwos_tech_3_cR

#define _screendump
#define _compass
#define _huge_font
#define _helium
#define _ccr_pscr
#define _external_sensor

#define NOT_INCLUDED_rx_functions
#define NOT_INCLUDED_cave_mode
#define NOT_INCLUDED_min_depth_option
#define NOT_INCLUDED_ostc_logo

#endif


#ifdef _hwos_tech

#define _screendump
#define _compass
#define _huge_font
#define _rx_functions
#define _helium
#define _ccr_pscr
#define _external_sensor

#define NOT_INCLUDED_cave_mode
#define NOT_INCLUDED_min_depth_option
#define NOT_INCLUDED_ostc_logo

#endif


#ifdef _hwos_sport

#define _screendump
#define _compass
#define _huge_font
#define _rx_functions
#define NOT_INCLUDED_helium
#define NOT_INCLUDED_ccr_pscr
#define NOT_INCLUDED_external_sensor

#define NOT_INCLUDED_cave_mode
#define NOT_INCLUDED_min_depth_option
#define NOT_INCLUDED_ostc_logo

#endif


#ifdef xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
;
; Debug Modes
; -----------
;
; _DEBUG			put firmware in a global debug mode		default: not included
; _debug_output		debug outputs (for performance)			default: not included
; _profiling		deco engine performance measurements	default: not included
;
; NOTE: - Exclude options by prepending NOT_INCLUDED to the label.
;
#endif

#define NOT_INCLUDED_DEBUG
#define NOT_INCLUDED_debug_output
#define NOT_INCLUDED_profiling
