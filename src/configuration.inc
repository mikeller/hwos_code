#ifdef xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
; ============================================================================
; 
;    File configuration.inc                 * combined next generation V3.12.3
; 
;    OSTC hwOS Configuration
; 
;    Copyright (c) 2019, heinrichs weikamp gmbh, all rights reserved.
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

#define fw_version_major		.3
#define fw_version_minor		.38
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

#define firmware_creation_year	.26;0x18
#define firmware_creation_month	.10;0x09
#define firmware_creation_day	.12;0x06

#define firmware_expire_year	.29;0x18
#define firmware_expire_month	.09;0x08
#define firmware_expire_day	.29;0x1C


#ifdef xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
;
; global Version Selection
; ------------------------
;
; _hwos_tech_2_TR        compile Tech  version for OSTC 2, Plus and TR en
; _hwos_tech_2_TR_cave   compile Tech  version for OSTC 2, Plus and TR en
; _hwos_tech_3_cR        compile Tech  version for OSTC 3       and cR en+de
; _hwos_tech_3_cR_cave   compile Tech  version for OSTC 3       and cR en+de
; _hwos_sport            compile Sport version for all models          en+de
;
; The used/free program-flash figures that used to be listed here disagreed with
; src/Docu/code-statistics.txt and were not reproducible from a real build. See the
; generated report in build/build-info.txt (flash_budget_* keys) for the figures of
; whichever configuration above is currently selected below.
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
; _language_2			second language, coding as above or 'none'		mem: approx. 4.0 kB in Sport, 4.3 kB in Tech
; 
#endif

#define _language_1		en
#define _language_2		none


#ifdef xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
;
; Features Selection
; ------------------
; base code without any features, 1 language (en)
; _compass				compass function
; _helium				helium (trimix) gases and diluents
; _ccr_pscr				CCR & pSCR modes, basic functionality
; _external_sensor_eccr		CCR & pSCR modes, external sensor and eccr support
; _gauge_mode			gauge mode
; _high_ppO2_max		raised ppO2 max limit (2.0 bar)
; _rx_functions			RX function        (OSTC TR)
; _rx_update			RX firmware update (OSTC TR), dependent on RX firmware size
; _gas_contingency		auto-switch to alternative tanks on depleption
; _cave_mode			cave mode return calculation
; _big_divemenu			big font dive menu -- UNDER DEVELOPMENT YET
; _firmware_recovery	means for backing up and restoring 2nd firmware
; _min_depth_option		resettable min. and max. depth					## special user group only ##
; _screendump			screen dump function							## special user group only ##
;
; The hand-counted per-feature byte deltas that used to be listed above went stale and
; are retired. See the generated report in build/build-info.txt (flash_budget_* keys)
; for the actual program-flash usage of whichever configuration is currently selected.
;
; NOTES: - exclude features by prepending NOT_INCLUDED to the label,
;        - not all features will fit concurrently at the same time or if two languages are slected,
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
#define NOT_INCLUDED_external_sensor_eccr
#define NOT_INCLUDED_cave_mode
#define NOT_INCLUDED_big_divemenu
#define NOT_INCLUDED_firmware_recovery
#define NOT_INCLUDED_min_depth_option
#define NOT_INCLUDED_screendump

#endif


#ifdef _hwos_tech_2_TR

#define _compass
#define _helium
#define _ccr_pscr
#define NOT_INCLUDED_rx_functions
#define NOT_INCLUDED_rx_update
#define _gauge_mode
#define _high_ppO2_max
#define _gas_contingency
#define NOT_INCLUDED_external_sensor_eccr
#define NOT_INCLUDED_cave_mode
#define _big_divemenu
#define _firmware_recovery
#define NOT_INCLUDED_min_depth_option
#define NOT_INCLUDED_screendump

#endif


#ifdef _hwos_tech_2_TR_cave

#define _compass
#define _helium
#define _ccr_pscr
#define NOT_INCLUDED_rx_functions
#define NOT_INCLUDED_rx_update
#define _gauge_mode
#define _high_ppO2_max
#define _gas_contingency
#define NOT_INCLUDED_external_sensor_eccr
#define _cave_mode
#define _big_divemenu
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
#define _external_sensor_eccr
#define _gas_contingency
#define NOT_INCLUDED_cave_mode
#define _big_divemenu
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
#define _external_sensor_eccr
#define _gas_contingency
#define _cave_mode
#define _big_divemenu
#define NOT_INCLUDED_firmware_recovery
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
#define NOT_INCLUDED_rx_functions
#define NOT_INCLUDED_rx_update
#define NOT_INCLUDED_external_sensor_eccr
#define NOT_INCLUDED_cave_mode
#define _big_divemenu
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
; Feature and Debug Flag Assertions
; ----------------------------------
;
; For each flag above, exactly one of _flag / NOT_INCLUDED_flag must be
; defined. Leaving both undefined (e.g. a typo, or a rename done in one
; place and not the other) must not silently fall back to feature
; disabled, since the first evidence of a missing feature such as
; _cave_mode or _ccr_pscr would otherwise be in the water. Checked here,
; before the auto-includes below, so it validates what was configured
; above, not what the auto-includes then derive from it.
;
; C18 has no equivalent to the MPASM ERROR directive used below (#error
; is C-only, ERROR is MPASM-only), so this check runs on the assembler
; side only. Every .asm translation unit still goes through this file,
; so a misconfigured build is caught at assembly time, before linking.
;
#endif

#ifndef __18CXX

#ifdef _compass
#ifdef NOT_INCLUDED_compass
ERROR "_compass and NOT_INCLUDED_compass both defined"
#endif
#else
#ifndef NOT_INCLUDED_compass
ERROR "neither _compass nor NOT_INCLUDED_compass defined"
#endif
#endif

#ifdef _helium
#ifdef NOT_INCLUDED_helium
ERROR "_helium and NOT_INCLUDED_helium both defined"
#endif
#else
#ifndef NOT_INCLUDED_helium
ERROR "neither _helium nor NOT_INCLUDED_helium defined"
#endif
#endif

#ifdef _ccr_pscr
#ifdef NOT_INCLUDED_ccr_pscr
ERROR "_ccr_pscr and NOT_INCLUDED_ccr_pscr both defined"
#endif
#else
#ifndef NOT_INCLUDED_ccr_pscr
ERROR "neither _ccr_pscr nor NOT_INCLUDED_ccr_pscr defined"
#endif
#endif

#ifdef _external_sensor_eccr
#ifdef NOT_INCLUDED_external_sensor_eccr
ERROR "_external_sensor_eccr and NOT_INCLUDED_external_sensor_eccr both defined"
#endif
#else
#ifndef NOT_INCLUDED_external_sensor_eccr
ERROR "neither _external_sensor_eccr nor NOT_INCLUDED_external_sensor_eccr defined"
#endif
#endif

#ifdef _gauge_mode
#ifdef NOT_INCLUDED_gauge_mode
ERROR "_gauge_mode and NOT_INCLUDED_gauge_mode both defined"
#endif
#else
#ifndef NOT_INCLUDED_gauge_mode
ERROR "neither _gauge_mode nor NOT_INCLUDED_gauge_mode defined"
#endif
#endif

#ifdef _high_ppO2_max
#ifdef NOT_INCLUDED_high_ppO2_max
ERROR "_high_ppO2_max and NOT_INCLUDED_high_ppO2_max both defined"
#endif
#else
#ifndef NOT_INCLUDED_high_ppO2_max
ERROR "neither _high_ppO2_max nor NOT_INCLUDED_high_ppO2_max defined"
#endif
#endif

#ifdef _rx_functions
#ifdef NOT_INCLUDED_rx_functions
ERROR "_rx_functions and NOT_INCLUDED_rx_functions both defined"
#endif
#else
#ifndef NOT_INCLUDED_rx_functions
ERROR "neither _rx_functions nor NOT_INCLUDED_rx_functions defined"
#endif
#endif

#ifdef _rx_update
#ifdef NOT_INCLUDED_rx_update
ERROR "_rx_update and NOT_INCLUDED_rx_update both defined"
#endif
#else
#ifndef NOT_INCLUDED_rx_update
ERROR "neither _rx_update nor NOT_INCLUDED_rx_update defined"
#endif
#endif

#ifdef _gas_contingency
#ifdef NOT_INCLUDED_gas_contingency
ERROR "_gas_contingency and NOT_INCLUDED_gas_contingency both defined"
#endif
#else
#ifndef NOT_INCLUDED_gas_contingency
ERROR "neither _gas_contingency nor NOT_INCLUDED_gas_contingency defined"
#endif
#endif

#ifdef _cave_mode
#ifdef NOT_INCLUDED_cave_mode
ERROR "_cave_mode and NOT_INCLUDED_cave_mode both defined"
#endif
#else
#ifndef NOT_INCLUDED_cave_mode
ERROR "neither _cave_mode nor NOT_INCLUDED_cave_mode defined"
#endif
#endif

#ifdef _big_divemenu
#ifdef NOT_INCLUDED_big_divemenu
ERROR "_big_divemenu and NOT_INCLUDED_big_divemenu both defined"
#endif
#else
#ifndef NOT_INCLUDED_big_divemenu
ERROR "neither _big_divemenu nor NOT_INCLUDED_big_divemenu defined"
#endif
#endif

#ifdef _firmware_recovery
#ifdef NOT_INCLUDED_firmware_recovery
ERROR "_firmware_recovery and NOT_INCLUDED_firmware_recovery both defined"
#endif
#else
#ifndef NOT_INCLUDED_firmware_recovery
ERROR "neither _firmware_recovery nor NOT_INCLUDED_firmware_recovery defined"
#endif
#endif

#ifdef _min_depth_option
#ifdef NOT_INCLUDED_min_depth_option
ERROR "_min_depth_option and NOT_INCLUDED_min_depth_option both defined"
#endif
#else
#ifndef NOT_INCLUDED_min_depth_option
ERROR "neither _min_depth_option nor NOT_INCLUDED_min_depth_option defined"
#endif
#endif

#ifdef _screendump
#ifdef NOT_INCLUDED_screendump
ERROR "_screendump and NOT_INCLUDED_screendump both defined"
#endif
#else
#ifndef NOT_INCLUDED_screendump
ERROR "neither _screendump nor NOT_INCLUDED_screendump defined"
#endif
#endif

#ifdef _DEBUG
#ifdef NOT_INCLUDED_DEBUG
ERROR "_DEBUG and NOT_INCLUDED_DEBUG both defined"
#endif
#else
#ifndef NOT_INCLUDED_DEBUG
ERROR "neither _DEBUG nor NOT_INCLUDED_DEBUG defined"
#endif
#endif

#ifdef _profiling
#ifdef NOT_INCLUDED_profiling
ERROR "_profiling and NOT_INCLUDED_profiling both defined"
#endif
#else
#ifndef NOT_INCLUDED_profiling
ERROR "neither _profiling nor NOT_INCLUDED_profiling defined"
#endif
#endif

#ifdef _debug_output
#ifdef NOT_INCLUDED_debug_output
ERROR "_debug_output and NOT_INCLUDED_debug_output both defined"
#endif
#else
#ifndef NOT_INCLUDED_debug_output
ERROR "neither _debug_output nor NOT_INCLUDED_debug_output defined"
#endif
#endif

#ifdef _comm_debug
#ifdef NOT_INCLUDED_comm_debug
ERROR "_comm_debug and NOT_INCLUDED_comm_debug both defined"
#endif
#else
#ifndef NOT_INCLUDED_comm_debug
ERROR "neither _comm_debug nor NOT_INCLUDED_comm_debug defined"
#endif
#endif

#ifdef _rx_functions_debug
#ifdef NOT_INCLUDED_rx_functions_debug
ERROR "_rx_functions_debug and NOT_INCLUDED_rx_functions_debug both defined"
#endif
#else
#ifndef NOT_INCLUDED_rx_functions_debug
ERROR "neither _rx_functions_debug nor NOT_INCLUDED_rx_functions_debug defined"
#endif
#endif

#endif


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

#ifdef  _external_sensor_eccr
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

#ifdef _external_sensor_eccr
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
