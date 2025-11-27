;=============================================================================
;
;   File tft_outputs.inc                    * combined next generation V3.09.5
;
;
;   Copyright (c) 2011, JD Gascuel, heinrichs weikamp gmbh, all right reserved.
;=============================================================================
; HISTORY
;  2011-08-07 : [mH] moving from OSTC code


;-----------------------------------------------------------------------------
; Surface Mode

	extern	TFT_surfmode_time					; current time
	extern	TFT_surfmode_date					; current date
	extern	TFT_surfmode_pres					; print current pressure, unconditional
	extern	TFT_surfmode_pres_fast				; print current pressure, but only if change > threshold
	extern	TFT_surfmode_temp					; current temperature (common core with divemode temp)
	extern	TFT_surfmode_batt					; battery status      (also used in sleep mode)
	extern	TFT_surfmode_decotype				; deco mode (OC, CCR, ...)
	extern	TFT_surfmode_startgas				; first gas and "OSTC2-like" active gases

 IFDEF _rx_functions
	extern	TFT_surfmode_tankpres				; tank data for surface mode screen
 ENDIF


;-----------------------------------------------------------------------------
; Surface Mode Custom Views

	extern	TFT_surf_cv_lastdive				; last dive summery
	extern	TFT_surf_cv_list_gas				; OC gases list
	extern	TFT_surf_cv_text					; the custom text
	extern	TFT_surf_cv_tissues					; tissue diagram (also used by logbook)
	extern	TFT_surf_cv_settings				; all deco settings
	extern	TFT_surf_desat_nofly_cns

 IFDEF _rx_functions
	extern	TFT_surf_cv_tankdata				; show the tank pressure data in surface customview
 ENDIF

 IFDEF _compass
	extern	TFT_surf_cv_compass_bearing			; "set bearing" dialog
 ENDIF

 IFDEF _ccr_pscr
	extern	TFT_surf_cv_list_dil				; diluents list
	extern	TFT_surf_cv_list_sp					; setpoint list
 ENDIF


;-----------------------------------------------------------------------------
; Surface Mode Messages

	extern	TFT_surf_mesg_desat					; desaturation time
	extern	TFT_surf_mesg_nofly					; no-fly/alt   time


;-----------------------------------------------------------------------------
; Imprints called by Housekeeping

	extern	TFT_imprint_time_date				; imprint current     time and date
	extern	TFT_imprint_time_date_fast			; imprint last cahced time and date
	extern	TFT_imprint_color_schemes			; imprint color schemes (animated dive time)
	extern	TFT_convert_lo_into_12h_format			; converts lo (0-23h) into lo (1-12) with PM/AM flag in aux_flag

 IFDEF _external_sensor_eccr
	extern	TFT_imprint_menu_mV					; imprint sensor data in menu    mode - mv
	extern	TFT_imprint_surf_ppO2				; imprint sensor data in surface mode - ppO2
	extern	TFT_imprint_surf_mV					; imprint sensor data in surface mode - mV
	extern	TFT_imprint_surf_sensor_eol			; imprint sensor data in surface mode - end of life
 ENDIF

 IFDEF _rx_functions
	extern	TFT_imprint_tank_pres				; imprint tank data in tank setup menu
 ENDIF


;-----------------------------------------------------------------------------
; Dive Mode

	extern	TFT_show_divemode_mask				; show  static layout
	extern	TFT_show_ndl_mask					; show  NDL    layout add-on
	extern	TFT_show_deco_mask					; show  deco   layout add-on

	extern	TFT_show_divetime					; show  dive time
	extern	TFT_show_depth						; show  current depth
	extern	TFT_show_max_depth					; show  maximum depth
	extern	TFT_show_apnoe_max_depth			; show  maximum depth - apnoe mode
	extern	TFT_show_temp_divemode				; show  temperature (common core with surface temp)
	extern	TFT_show_active_gas_divemode		; show  active gas and setpoint
	extern	TFT_show_ndl						; show  NDL time
	extern	TFT_show_tts						; show  TTS time
	extern	TFT_show_deco						; show  deco stop data

	extern	TFT_show_apnoe_times				; show  apnoe current and overall time
	extern	TFT_show_apnoe_surface				; show  apnoe surface mode data
	extern	TFT_clear_apnoe_surface				; clear apnoe surface data
	extern	TFT_apnoe_divecounter				; show apnoe #dive counter

	extern	TFT_clear_deco_data					; clear deco data (NDL or stop & TTS)
	extern	TFT_clear_divemode_menu				; clear the divemode menu

	extern	TFT_velocity_show					; show  vertical velocity
	extern	TFT_velocity_clear					; clear vertical velocity

	extern	TFT_divemode_sign_show				; show  sign
	extern	TFT_divemode_sign_clear				; clear sign

	extern	TFT_safety_stop_show				; show  safety stop
	extern	TFT_safety_stop_clear				; clear safety stop
	
 IFDEF _compass
	extern	TFT_dive_compass_extras				; Update Stopwatch display in compass mode
 ENDIF


;-----------------------------------------------------------------------------
; Dive Mode Mesages

	extern	TFT_message_ftts					; fTTS
	extern	TFT_message_ppo2					; ppO2
	extern	TFT_message_battery_percent			; battery
	extern	TFT_message_cns						; current     CNS
	extern	TFT_message_cns_eod					; end-of-dive CNS
	extern	TFT_message_saturation				; Saturation
	extern	TFT_message_agf						; aGF is selected
	extern	TFT_message_divetimeout				; dive timeout counter
	extern	TFT_message_gas_needs				; gas needs
	extern	TFT_message_gas_change				; gas change advice
	extern	TFT_message_no_BO_gas				; no bailout gas available
	extern	TFT_message_mbubbles				; mico-bubbles
	extern	TFT_message_outside					; outside of the model
	extern	TFT_message_depth_limit				; depth limit exceeded
	extern	TFT_message_deco_info				; decompression zone

 IFDEF _helium
	extern	TFT_message_IBCD					; INCD
 ENDIF

 IFDEF _ccr_pscr
	extern	TFT_message_gas_density				; gas density
 ENDIF

 IFDEF _external_sensor_eccr
	extern	TFT_message_divergence				; sensor ppO2 divergence
	extern	TFT_message_fallback				; show fallback warning
 ENDIF

 IFDEF _rx_functions
	extern	TFT_message_transmitter				; transmitter
	extern	TFT_message_pressure				; pressure reading
	extern	TFT_message_sac						; SAC
	extern	TFT_message_switch_tanks			; switch advice for ind.double mode
 ENDIF

 IFDEF _cave_mode
	extern	TFT_message_cave_mode				; cave mode status
 ENDIF


;-----------------------------------------------------------------------------
; Divemode Custom Views

	extern	TFT_avr_stopwatch_mask				; mask for average depth and stopwatch
	extern	TFT_avr_stopwatch					; data for average depth and stopwatch
	extern	TFT_gas_needs_mask					; mask for gas needs ascent
	extern	TFT_gas_needs						; data for gas needs ascent
	extern	TFT_decoplan_mask					; mask for deco plan
	extern	TFT_decoplan						; data for deco plan
	extern	TFT_ceiling_GF_tissue_mask			; mask for ceiling, current GF and tissues
	extern	TFT_ceiling_GF_tissue				; data for ceiling, current GF and tissues
	extern	TFT_ceiling_GF_surfGF_mask			; mask for ceiling, current GF and Surf GF
	extern	TFT_ceiling_GF_surfGF				; data for ceiling, current GF and Surf GF
	extern	TFT_CNS_mask						; mask for CNS values
	extern	TFT_CNS								; data for CNS values
	extern	TFT_ppo2_ead_end_cns_mask			; mask for ppO2, END/EAD and CNS / gas density
	extern	TFT_ppo2_ead_end_cns				; data for ppO2, END/EAD and CNS / gas density
	extern	TFT_gf_factors_mask					; mask for GF factors
;	extern										; data for GF factors (not existing)
	extern	TFT_clock_batt_surfpress_mask		; mask for clock, battery and surface pressure
	extern	TFT_clock_batt_surfpress			; data for clock, battery and surface pressure

 IFDEF _ccr_pscr
	extern	TFT_sensor_check_mask				; mask for sensor check
	extern	TFT_sensor_check					; data for sensor check
	extern	TFT_pscr_info_mask					; mask for pSCR info
	extern	TFT_pscr_info						; data for pSCR info
 ENDIF

 IFDEF _external_sensor_eccr
	extern	TFT_ppo2_sensors_mask				; mask for ppO2 sensors
	extern	TFT_ppo2_sensors					; data for ppO2 sensors
 ENDIF

 IFDEF _rx_functions
	extern	TFT_pressures_SAC_mask				; mask for pressures and SAC
	extern	TFT_pressures_SAC					; data for pressures and SAC
 ENDIF

 IFDEF _cave_mode
	extern	TFT_cave_tts_mask					; mask for cave mode TTS, total stops and runtime
	extern	TFT_cave_tts						; data for cave mode TTS, total stops and runtime
	extern	TFT_cave_waypoints					; data for cave mode waypoints (no mask function)
 ENDIF


;-----------------------------------------------------------------------------
; Font Color Selection - pallet-based Colors

	extern	TFT_load_std_color_pallet			; load standard color pallet
	extern	TFT_load_dive_color_pallet			; load dive     color pallet


;-----------------------------------------------------------------------------
; Color-Coding

	extern	TFT_color_code_gas					; color-code by gas number (1-6) in WREG
	extern	TFT_color_code_gaslist				; color-code by gas O2% (in hi) and absolute pressure
	extern	TFT_color_code_cns					; color-code CNS value


;-----------------------------------------------------------------------------
; Append / Print Firmware Data etc.

	extern	TFT_cat_firmware					; append firmware version to output buffer
	extern	TFT_cat_beta_long					; append beta/release     to output buffer (long  format)
	extern	TFT_cat_beta_short					; append beta/release     to output buffer (short format)
	extern	TFT_cat_serial						; append serial number    to output buffer

	extern	TFT_print_serial_and_firmware		; print serial number and full firmware
	extern	TFT_print_firmware					; print firmware and beta/release status
	extern	TFT_print_decotype					; print OC,CCR,... (used by logbook & simulator)

	extern	TFT_message_fw_update				; firmware is updated message
	extern	TFT_message_fw_kept					; firmware is kept    message



;-----------------------------------------------------------------------------
; Message System

	extern	TFT_buffer_trim_length				; fill or trim output buffer to a given length
	extern	TFT_clear_message_window			; clear all messages
	extern	TFT_clear_message_window_row2		; clear only 2nd message


;-----------------------------------------------------------------------------
; Debug output

	extern	TFT_debug_output					; used for scheduling performance, etc.

;-----------------------------------------------------------------------------
