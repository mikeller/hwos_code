#ifdef xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
; ============================================================================
; 
;    File configuration.inc                   combined next generation V3.06.2
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
#define softwareversion_y		0x08
#define softwareversion_beta	0x00


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
#define firmware_creation_month	0x08
#define firmware_creation_day	0x0a

#define firmware_expire_year	0x14
#define firmware_expire_month	0x0a
#define firmware_expire_day		0x1f


#ifdef xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
;
; global Version Selection
; ------------------------
;
; _hwos_tech_2_TR		compile Tech  version for OSTC 2, Plus and TR (1 language  only    ) memory: 122.054 used,   884 free
; _hwos_tech_3_cR		compile Tech  version for OSTC 3       and cR (2 languages possible) memory: 118.148 used, 4.790 free (with 1 language only)
; _hwos_sport			compile Sport version for all models          (2 languages possible) memory: 115.764 used, 7.174 free (with 1 language only)
#endif

#define _hwos_tech_3_cR


#ifdef xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
;
; Language Selection
; ------------------
;
; _language_1			first or single language,
;						set to 'en', 'de', 'fr', or 'it', defaults to 'en'
;
; _language_2			second language, coding as above or 'none'		mem: approx. 4.0 kbyte in Sport, 4.228 kbyte in Tech
; 
#endif

#define _language_1		en
#define _language_2		de


#ifdef xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
;
; Features Selection
; ------------------
;
; _screendump			screen dump function				mem:    338 byte
; _compass				compass function					mem: 10.488 byte
; _rx_functions			RX functions (OSTC TR)				mem:  4.886 byte
; _rx_update			updates RX firmware				1)	mem:  2.472 byte
; _helium				Helium (Trimix) gases and diluents	mem:  2.182 byte
; _ccr_pscr				loop modes CCR and pSCR				mem:  4.110 byte
; _external_sensor		external sensor for CCR & pSCR	2)	mem:  3.452 byte
; _gauge_mode			gauge mode							mem:     30 byte  when _not_ included
; _high_ppO2_max		raised ppO2 max limit (2.0 bar)		mem:      0 byte
; _cave_mode			cave mode way-out calculation		mem:        byte  ## under construction yet  ##
; _min_depth_option		resettable min. and max. depth		mem:    394 byte  ## special user group only ##
; _gas_contingency		continue deco on other gases		mem:    452 byte  ## special user group only ##
;
; 1) needs _rx_functions to be included, too / can not be included without _rx_functions
; 2) needs _ccr_pscr     to be included, too / can not be included without _ccr_pscr
;
; NOTES: - Exclude options by prepending NOT_INCLUDED to the label.
;        - Not all options will fit concurrently if two languages are slected.
;        - Option sizes are based on single language (english), will increase
;          with 2nd language and will differ slightly between languages.
#endif


#ifdef _hwos_tech_2_TR

#define _screendump
#define _compass
#define _rx_functions
#define _rx_update
#define _helium
#define _ccr_pscr
#define _gauge_mode
#define _high_ppO2_max


#define NOT_INCLUDED_external_sensor
#define NOT_INCLUDED_cave_mode
#define NOT_INCLUDED_min_depth_option

#endif


#ifdef _hwos_tech_3_cR

#define NOT_INCLUDED_screendump
#define _compass
#define _helium
#define _ccr_pscr
#define _external_sensor
#define _gauge_mode
#define _high_ppO2_max
#define _gas_contingency

#define NOT_INCLUDED_rx_functions
#define NOT_INCLUDED_rx_update
#define NOT_INCLUDED_cave_mode
#define NOT_INCLUDED_min_depth_option

#endif


#ifdef _hwos_sport

#define _screendump
#define _compass
#define _rx_functions
#define _rx_update
#define NOT_INCLUDED_helium
#define NOT_INCLUDED_ccr_pscr
#define NOT_INCLUDED_external_sensor

#define NOT_INCLUDED_gauge_mode
#define NOT_INCLUDED_high_ppO2_max
#define NOT_INCLUDED_cave_mode
#define NOT_INCLUDED_min_depth_option

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





#ifdef xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
;
; Software Configuration
;
#endif

#ifdef _screendump
#define SW_CONF_1    0x01
#else
#define SW_CONF_1    0x00
#endif

#ifdef _compass
#define SW_CONF_2    0x02
#else
#define SW_CONF_2    0x00
#endif

#ifdef _rx_functions
#define SW_CONF_3    0x04
#else
#define SW_CONF_3    0x00
#endif

#ifdef _rx_update
#define SW_CONF_4    0x08
#else
#define SW_CONF_4    0x00
#endif

#ifdef _helium
#define SW_CONF_5    0x10
#else
#define SW_CONF_5    0x00
#endif

#ifdef _ccr_pscr
#define SW_CONF_6    0x20
#else
#define SW_CONF_6    0x00
#endif

#ifdef _external_sensor
#define SW_CONF_7    0x40
#else
#define SW_CONF_7    0x00
#endif

#ifdef _cave_mode
#define SW_CONF_8    0x80
#else
#define SW_CONF_8    0x00
#endif

#define SW_CONF  SW_CONF_1 + SW_CONF_2 + SW_CONF_3 + SW_CONF_4 + SW_CONF_5 + SW_CONF_6 + SW_CONF_7 + SW_CONF_8
