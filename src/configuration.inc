#ifdef xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
; ============================================================================
; 
;    File configuration.inc                 * combined next generation V3.09.5
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
; fw_version_major				firmware version, major               (1 -  9)
; fw_version_minor				firmware version, minor               (0 - 99)
; fw_version_beta				0= Release, 1= Beta 1, 2= Beta 2, ... (0 - 99)
;
; NOTE: all values need to be defined in hex!
;
#endif

#define fw_version_major		0x03
#define fw_version_minor		0x0B
#define fw_version_beta			0x00


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

#define firmware_creation_year	0x14
#define firmware_creation_month	0x05
#define firmware_creation_day	0x19

#define firmware_expire_year	0x15
#define firmware_expire_month	0x02
#define firmware_expire_day	0x01


#ifdef xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
;
; global Version Selection
; ------------------------
;
; _hwos_tech_2_TR        compile Tech  version for OSTC 2, Plus and TR en    memory: 118.656 used, 4.224 free
; _hwos_tech_2_TR_cave   compile Tech  version for OSTC 2, Plus and TR en    memory: 120.883 used, 1.997 free
; _hwos_tech_3_cR        compile Tech  version for OSTC 3       and cR en+de memory: 119.496 used, 3.384 free
; _hwos_tech_3_cR_cave   compile Tech  version for OSTC 3       and cR en+de memory: 122.079 used,   801 free *
; _hwos_sport            compile Sport version for all models          en+de memory: 116.365 used, 6.515 free
;                                                                                    122.880 max. available
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
; _language_2			second language, coding as above or 'none'		mem: approx. 4.0 kB in Sport, 4.3 kB in Tech
; 
#endif

#define _language_1		en
#define _language_2		none


#ifdef xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
;
; Features Selection												 CODE SIZES ARE OUTDATED
; ------------------
; base code without any features, 1 language (en)						mem:   93.964 byte
; _compass				compass function								mem: + 10.404 byte
; _helium				helium (trimix) gases and diluents				mem: +  2.113 byte || both together
; _ccr_pscr				CCR & pSCR modes, basic functionality			mem: +  4.117 byte ||  + 6.250 byte
; _external_sensor		CCR & pSCR modes, external sensor support		mem: +  3.343 byte
; _gauge_mode			gauge mode										mem: -     28 byte (less)
; _high_ppO2_max		raised ppO2 max limit (2.0 bar)					mem:        0 byte (neutral)
; _rx_functions			RX function        (OSTC TR)					mem: +  4.497 byte
; _rx_update			RX firmware update (OSTC TR)					mem: +  2.282 byte (dependent on RX firmware size)
; _gas_contingency		auto-switch to alternative tanks on depleption	mem: +    804 byte
; _cave_mode			cave mode return calculation					mem: +  3.035 byte
; _firmware_recovery	means for backing up and restoring 2nd firmware mem: +    472 byte
; _min_depth_option		resettable min. and max. depth					mem: +      4 byte  ## special user group only ##
; _screendump			screen dump function							mem: +    348 byte  ## special user group only ##
;
;
; NOTES: - exclude features by prepending NOT_INCLUDED to the label,
;        - sizes may be incorrect by a couple of bytes,
;        - not all features will fit concurrently at the same time or if two languages are slected,
;        - feature sizes are based on single language (english)
;        - feature sizes will increase with 2nd language and will differ slightly between languages,
;        - combinations of features will yield code sizes that differ
;          slightly from the simple sum of the individual sizes.
#endif


#ifdef _base_code

#define NOT_INCLUDED_compass
#define NOT_INCLUDED_helium
#define NOT_INCLUDED_ccr_pscr
#define NOT_INCLUDED_rx_functions
#define NOT_INCLUDED_rx_update
#define NOT_INCLUDED_gauge_mode
#define NOT_INCLUDED_high_ppO2_max
#define NOT_INCLUDED_gas_contingency
#define NOT_INCLUDED_external_sensor
#define NOT_INCLUDED_cave_mode
#define NOT_INCLUDED_firmware_recovery
#define NOT_INCLUDED_min_depth_option
#define NOT_INCLUDED_screendump

#endif


#ifdef _hwos_tech_2_TR

#define _compass
#define _helium
#define _ccr_pscr
#define _rx_functions
#define _rx_update
#define _gauge_mode
#define _high_ppO2_max
#define _gas_contingency
#define NOT_INCLUDED_external_sensor
#define NOT_INCLUDED_cave_mode
#define _firmware_recovery
#define NOT_INCLUDED_min_depth_option
#define NOT_INCLUDED_screendump

#endif


#ifdef _hwos_tech_2_TR_cave

#define _compass
#define _helium
#define _ccr_pscr
#define _rx_functions
#define _rx_update
#define _gauge_mode
#define _high_ppO2_max
#define _gas_contingency
#define NOT_INCLUDED_external_sensor
#define _cave_mode
#define _firmware_recovery
#define NOT_INCLUDED_min_depth_option
#define NOT_INCLUDED_screendump

#endif


#ifdef _hwos_tech_3_cR

#define _compass
#define _helium
#define _ccr_pscr
#define _gauge_mode
#define _high_ppO2_max
#define NOT_INCLUDED_rx_functions
#define NOT_INCLUDED_rx_update
#define _external_sensor
#define _gas_contingency
#define NOT_INCLUDED_cave_mode
#define _firmware_recovery
#define NOT_INCLUDED_min_depth_option
#define NOT_INCLUDED_screendump

#endif


#ifdef _hwos_tech_3_cR_cave

#define _compass
#define _helium
#define _ccr_pscr
#define _gauge_mode
#define _high_ppO2_max
#define NOT_INCLUDED_rx_functions
#define NOT_INCLUDED_rx_update
#define _external_sensor
#define _gas_contingency
#define _cave_mode
#define _firmware_recovery
#define NOT_INCLUDED_min_depth_option
#define NOT_INCLUDED_screendump

#endif


#ifdef _hwos_sport

#define _compass
#define _gas_contingency
#define NOT_INCLUDED_helium
#define NOT_INCLUDED_ccr_pscr
#define NOT_INCLUDED_gauge_mode
#define NOT_INCLUDED_high_ppO2_max
#define _rx_functions
#define _rx_update
#define NOT_INCLUDED_external_sensor
#define NOT_INCLUDED_cave_mode
#define _firmware_recovery
#define NOT_INCLUDED_min_depth_option
#define NOT_INCLUDED_screendump

#endif


#ifdef xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
;
; Debug Modes
; -----------
;
; _DEBUG				put firmware in a global debug mode		default: not included
; _profiling			deco engine performance measurements	default: not included
; _debug_output			performance outputs (for _profiling)	default: not included
; _comm_debug			add run-time adjustable RX timeout		default: not included
; _rx_functions_debug	switch to transmitter debug custom view	default: not included
;
; NOTE: - Exclude options by prepending NOT_INCLUDED to the label
;
#endif

#define NOT_INCLUDED_DEBUG
#define NOT_INCLUDED_profiling
#define NOT_INCLUDED_debug_output
#define NOT_INCLUDED_comm_debug
#define NOT_INCLUDED_rx_functions_debug


#ifdef xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
;
; Auto-Includes (serve functional dependencies)
;
#endif

#ifdef  _cave_mode
#ifndef _gas_contingency
#define _gas_contingency
#endif
#endif

#ifdef  _rx_update
#ifndef _rx_functions
#define _rx_functions
#endif
#endif

#ifdef  _external_sensor
#ifndef _ccr_pscr
#define _ccr_pscr
#endif
#endif


#ifdef xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
;
; Software Configuration
;
#endif

#ifdef _screendump
#define FW_CONF_1    0x01
#else
#define FW_CONF_1    0x00
#endif

#ifdef _compass
#define FW_CONF_2    0x02
#else
#define FW_CONF_2    0x00
#endif

#ifdef _rx_functions
#define FW_CONF_3    0x04
#else
#define FW_CONF_3    0x00
#endif

#ifdef _rx_update
#define FW_CONF_4    0x08
#else
#define FW_CONF_4    0x00
#endif

#ifdef _helium
#define FW_CONF_5    0x10
#else
#define FW_CONF_5    0x00
#endif

#ifdef _ccr_pscr
#define FW_CONF_6    0x20
#else
#define FW_CONF_6    0x00
#endif

#ifdef _external_sensor
#define FW_CONF_7    0x40
#else
#define FW_CONF_7    0x00
#endif

#ifdef _cave_mode
#define FW_CONF_8    0x80
#else
#define FW_CONF_8    0x00
#endif

#define FW_CONF  FW_CONF_1 + FW_CONF_2 + FW_CONF_3 + FW_CONF_4 + FW_CONF_5 + FW_CONF_6 + FW_CONF_7 + FW_CONF_8

#define FW_ID    LOW( fw_version_major + fw_version_minor + fw_version_beta )
