;=============================================================================
;
;   File tft_outputs.inc							REFACTORED VERSION V2.99f
;
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;  2011-08-07 : [mH] moving from OSTC code

; Surface Mode
	extern	TFT_surface_lastdive
	extern	TFT_show_OC_startgas_surface		; show first gas and "OSTC2-like" active gases
	extern	TFT_clock
	extern	TFT_date
	extern	TFT_desaturation_time
	extern	TFT_nofly_time
	extern	TFT_gaslist_surfmode
	extern	TFT_dillist_surfmode
	extern	TFT_splist_surfmode					; show setpoint list
	extern	TFT_temp_surfmode
	extern	TFT_update_batt_voltage
	extern	TFT_display_decotype_surface
	extern	TFT_display_decotype_surface1		; used from logbook
	extern	TFT_update_surf_press
	extern	TFT_surface_sensor					; update sensor data in surface mode
	extern	TFT_sensor_surface_warning
	extern	TFT_menu_calibrate					; update mV data in menu
	extern	TFT_custom_text						; the custom text
	extern	TFT_surface_tissues					; show tissue diagram in surface mode
	extern	TFT_surface_decosettings			; show all deco settings
	extern	TFT_cat_serial						; add serial           to current string
	extern	TFT_cat_firmware					; add firmware version to current string
	extern	TFT_cat_beta_rel					; add beta/rel.        to current string
	extern	TFT_cat_beta_release				; add beta/release     to current string
	extern	TFT_surf_set_bearing

; Menu
	extern	TFT_LogOffset_Logtitle
	extern	TFT_show_color_schemes				; update the color schemes
	extern	TFT_show_time_date_menu

; Dive Mode
	extern	TFT_display_cns
	extern	TFT_divemins
	extern	TFT_depth
	extern	TFT_max_depth
	extern	TFT_temp_divemode
	extern	TFT_active_gas_divemode				; active gas and setpoint
	extern	TFT_divemode_mask
	extern	TFT_draw_gassep_line				; draw the gas separator grid line in spec mode only
	extern	TFT_divemode_menu_cursor			; the divemode cursor
	extern	TFT_display_ndl_mask
	extern	TFT_display_tts
	extern	TFT_display_ndl
	extern	TFT_display_deko_mask
	extern	TFT_divemode_warning
	extern	TFT_divemode_warning_clear
	extern	TFT_velocity_clear
	extern	TFT_display_velocity
	extern	TFT_display_deko
	extern	TFT_mask_ppo2
	extern	TFT_display_ppo2_warning
	extern	TFT_update_batt_percent_divemode
	extern	TFT_display_apnoe_descent
	extern	TFT_apnoe_clear_surface
	extern	TFT_display_apnoe_surface
	extern	TFT_display_apnoe_last_max
	extern	TFT_display_ftts
	extern	TFT_clear_divemode_menu				; clear the divemode menu
	extern	TFT_clear_warning_text
	extern	TFT_clear_warning_text_2nd_row
	extern	TFT_warning_gf
	extern	TFT_warning_agf						; show a warning if aGF is selected
	extern	TFT_divetimeout						; show timeout counter
	extern	TFT_show_safety_stop				; show the safety stop
	extern	TFT_clear_decoarea					; cleanup deco area on screen
	extern	TFT_clear_safety_stop				; clear safety stop
	extern	TFT_warning_fallback				; show fallback warning
	extern	TFT_warning_gas_needs_warn
	extern	TFT_warning_gas_needs_att
	extern	TFT_advice_gas_change
	extern	TFT_warning_sensor_disagree
	extern	TFT_warning_IBCD
	extern	TFT_warning_no_BO_gas
	extern	TFT_display_eod_cns
	extern	TFT_warning_mbubbles
	extern	TFT_warning_outside
	extern	TFT_info_deco

; Divemode Custom Views
	extern	TFT_avr_stopwatch_mask				; mask for average depth and stopwatch
	extern	TFT_avr_stopwatch					; data for average depth and stopwatch
	extern	TFT_ppo2_sensors_mask				; mask for ppO2 sensors
	extern	TFT_ppo2_sensors					; data for ppO2 sensors
	extern	TFT_sensor_check_mask				; mask for sensor check
	extern	TFT_sensor_check					; data for sensor check
	extern	TFT_pscr_info_mask					; mask for pSCR info
	extern	TFT_pscr_info						; data for pSCR info
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
	extern	TFT_clock_batt_surfpress_mask		; mask for clock, battery and surface pressure
	extern	TFT_clock_batt_surfpress			; data for clock, battery and surface pressure


; Surface Custom Views
	extern	TFT_sensor_mV

; Misc
	extern	TFT_standard_color
	extern	TFT_disabled_color
	extern	TFT_memo_color
	extern	TFT_advice_color
	extern	TFT_attention_color
	extern	TFT_warnings_color
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
	extern	convert_mbar_to_feet				; convert value in lo:hi from mbar to feet
	extern	convert_celsius_to_fahrenheit		; convert value in lo:hi from celsius to fahrenheit

	extern	TFT_debug_output


; Alternative Dive Mode (aka Blind Mode)
	extern	TFT_divemins_alternative
	extern	TFT_divemode_mask_alternative
	extern	TFT_max_depth_alternative
	extern	TFT_big_deco_alt					; the big deco


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
	extern	TFT_advice_switch
 ENDIF

 IFDEF _cave_mode
	extern	TFT_info_cave_mode					; show info    that in cave mode
	extern	TFT_info_dive_turned				; show info    that dive is turned
	extern	TFT_warn_cave_shutdown				; show warning that cave mode has shut down
 ENDIF