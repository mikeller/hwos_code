;=============================================================================
;
;   File tft_outputs.inc                      next combined generation V3.03.2
;
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;  2011-08-07 : [mH] moving from OSTC code

; Surface Mode
	extern	TFT_surface_lastdive
	extern	TFT_show_OC_startgas_surface		; first gas and "OSTC2-like" active gases
	extern	TFT_time_surfmode
	extern	TFT_date_surfmode
	extern	TFT_desaturation_time
	extern	TFT_nofly_time
	extern	TFT_gaslist_surfmode
	extern	TFT_pres_surfmode
	extern	TFT_temp_surfmode					; current temperature (common core with divemode temp)
	extern	TFT_batt_surfmode
	extern	TFT_decotype_surface
	extern	TFT_decotype_logbook				; used from logbook
	extern	TFT_custom_text						; the custom text
	extern	TFT_surface_tissues					; tissue diagram in surface mode
	extern	TFT_surface_decosettings			; all deco settings
	extern	show_fw_mesg_update					; firmware is updated message
	extern	show_fw_mesg_kept					; firmware is kept    message
	extern	TFT_cat_serial						; add serial           to current string
	extern	TFT_cat_firmware					; add firmware version to current string
	extern	TFT_cat_beta_release				; add beta/release     to current string

 IFDEF _compass
	extern	TFT_surf_set_bearing
 ENDIF

 IFDEF _ccr_pscr
	extern	TFT_dillist_surfmode
	extern	TFT_splist_surfmode					; setpoint list
 ENDIF

 IFDEF _external_sensor
	extern	TFT_menu_calibrate					; update mV data in menu
	extern	TFT_surface_sensor					; update sensor data in surface mode
	extern	TFT_sensor_surface_warning			; sensor end-of-lifetime symbol
 ENDIF


; Menu
	extern	TFT_LogOffset
	extern	TFT_show_color_schemes				; update the color schemes
	extern	TFT_show_time_date_menu
	extern	TFT_show_time_date_menu_fast
	extern	TFT_show_serial_and_firmware
	extern	TFT_show_firmware

; Dive Mode
	extern	TFT_show_cns
	extern	TFT_show_divetime
	extern	TFT_show_depth
	extern	TFT_show_max_depth
	extern	TFT_show_temp_divemode					; current temperature (common core with surface temp)
	extern	TFT_show_active_gas_divemode			; active gas and setpoint
	extern	TFT_show_divemode_mask
	extern	TFT_show_menu_cursor_divemode			; the divemode cursor
	extern	TFT_show_ndl_mask
	extern	TFT_show_ndl
	extern	TFT_show_tts
	extern	TFT_show_deco_mask
	extern	TFT_show_deco
	extern	TFT_divemode_sign_show
	extern	TFT_divemode_sign_clear
	extern	TFT_velocity_show
	extern	TFT_velocity_clear
	extern	TFT_show_ppo2_mask
	extern	TFT_show_ppo2_warning
	extern	TFT_msg_batt_percent_divemode
	extern	TFT_show_apnoe_times
	extern	TFT_clear_apnoe_surface
	extern	TFT_show_apnoe_surface
	extern	TFT_show_apnoe_max_depth
	extern	TFT_show_ftts
	extern	TFT_clear_divemode_menu				; clear the divemode menu
	extern	TFT_clear_message_window
	extern	TFT_clear_message_window_row2
	extern	TFT_warning_sat
	extern	TFT_warning_agf						; show a warning if aGF is selected
	extern	TFT_divetimeout						; show timeout counter
	extern	TFT_safety_stop_show				; show the safety stop
	extern	TFT_safety_stop_clear				; clear safety stop
	extern	TFT_clear_deco_data					; clear deco data (NDL or stop & TTS)
	extern	TFT_warning_fallback				; show fallback warning
	extern	TFT_warning_gas_needs_warn
	extern	TFT_warning_gas_needs_att
	extern	TFT_advice_gas_change
	extern	TFT_warning_no_BO_gas
	extern	TFT_warning_eod_cns
	extern	TFT_warning_mbubbles
	extern	TFT_warning_outside
	extern	TFT_warning_depth
	extern	TFT_info_deco

 IFDEF _helium
	extern	TFT_warning_IBCD
 ENDIF

 IFDEF _external_sensor
	extern	TFT_warning_sensor_disagree
 ENDIF


; Divemode Custom Views
	extern	TFT_avr_stopwatch_mask				; mask for average depth and stopwatch
	extern	TFT_avr_stopwatch					; data for average depth and stopwatch
	extern	TFT_gas_needs_ascent_mask			; mask for gas needs ascent
	extern	TFT_gas_needs_ascent				; data for gas needs ascent
	extern	TFT_decoplan_mask					; mask for deco plan
	extern	TFT_decoplan						; data for deco plan
	extern	TFT_ceiling_GF_tissue_mask			; mask for ceiling, current GF and tissues
	extern	TFT_ceiling_GF_tissue				; data for ceiling, current GF and tissues
	extern	TFT_CNS_mask						; mask for CNS values
	extern	TFT_CNS								; data for CNS values
	extern	TFT_ppo2_ead_end_cns_mask			; mask for ppO2, END/EAD and CNS
	extern	TFT_ppo2_ead_end_cns				; data for ppO2, END/EAD and CNS
	extern	TFT_gf_factors_mask					; mask for GF factors
;	extern										; data for GF factors (none)
	extern	TFT_clock_batt_surfpress_mask		; mask for clock, battery and surface pressure
	extern	TFT_clock_batt_surfpress			; data for clock, battery and surface pressure

 IFDEF _ccr_pscr
	extern	TFT_sensor_check_mask				; mask for sensor check
	extern	TFT_sensor_check					; data for sensor check
	extern	TFT_pscr_info_mask					; mask for pSCR info
	extern	TFT_pscr_info						; data for pSCR info
 ENDIF

 IFDEF _external_sensor
	extern	TFT_ppo2_sensors_mask				; mask for ppO2 sensors
	extern	TFT_ppo2_sensors					; data for ppO2 sensors
 ENDIF


; Surface Custom Views

 IFDEF _external_sensor
	extern	TFT_sensor_mV
 ENDIF


; Misc
	extern	TFT_standard_color
	extern	TFT_disabled_color
	extern	TFT_memo_color
	extern	TFT_advice_color
	extern	TFT_attention_color
	extern	TFT_warning_color
	extern	TFT_divemask_color

	extern	TFT_color_code_gas
	extern	TFT_color_code_gaslist
	extern	TFT_color_code_cns
	extern	TFT_color_code_tank_pres_sac

	extern	adjust_depth_with_salinity			; computes salinity setting into lo:hi [mbar]
	extern	adjust_depth_with_salinity_log		; computes salinity setting (FROM WREG!) into lo:hi [mbar]
	extern	TFT_convert_date_short
	extern	TFT_convert_signed_16bit
	extern	TFT_convert_date
	extern	convert_mbar_to_feet				; convert value in hi:lo from mbar to feet
	extern	convert_meter_to_feet				; convert value in    lo from meters to feet
	extern	convert_celsius_to_fahrenheit		; convert value in hi:lo from celsius to fahrenheit

	extern	TFT_debug_output


 IFDEF _rx_functions
	extern	TFT_pressures_SAC_mask				; mask for pressures and SAC
	extern	TFT_pressures_SAC					; data for pressures and SAC
	extern	TFT_menu_tank_pres					; update tank data when in tank setup menu
	extern	TFT_surface_tank_pres				; update tank data when in surface mode
	extern	TFT_surface_tankdata				; show the tank pressure data in surface customview
	extern	TFT_attention_transmitter			; show attention for transmitter
	extern	TFT_attention_pres_reading			; show attention for pressure reading
	extern	TFT_warning_pres_reading			; show warning   for pressure reading
	extern	TFT_attention_sac					; show attention for SAC
	extern	TFT_advice_switch					; show switch advice for ind.double mode
	extern	TFT_print_firmware_rx				; show rx firmware version
 ENDIF

 IFDEF _cave_mode
	extern	TFT_info_cave_mode					; show info    that in cave mode
	extern	TFT_info_dive_turned				; show info    that dive is turned
	extern	TFT_warn_cave_shutdown				; show warning that cave mode has shut down
 ENDIF
