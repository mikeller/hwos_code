;=============================================================================
;
;   File divemode.inc                         combined next generation V3.03.5
;
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;  2011-08-15 : [mH] moving from OSTC code

	extern	set_dive_modes
	extern	diveloop
	extern	apnoe_calc_maxdepth
	extern	check_gas_best
	extern	setup_gas_registers
	extern	deco_setup_oc_gases

 IFDEF _ccr_pscr
	extern	setup_dil_registers
	extern	deco_setup_cc_diluents
 ENDIF

 IFDEF _external_sensor
	extern	calc_deko_divemode_sensor
 ENDIF


; Divemode layout:
; row    = 0...239
; column = 0...159 (x2)

; Divemode has multiple layouts but basicly splits the screen into 3 rows:
;   - upper  content row: depth, max depth, dive time, etc.
;   - custom content row: selectable views
;   - bottom content row: temp, gas, ndl, tts, etc.

; I. The upper content row (0-99)
;    The top row is divided in 2 areas:
;    - header : holds the titles (mask)
;    - content: holds the values

;******* upper content / header row *******

#DEFINE dm_mask_depth_row						.0
#DEFINE dm_mask_depth_column					.2
#DEFINE dm_mask_depth_column_alt				.64

#DEFINE dm_mask_maxdepth_row					.0
#DEFINE dm_mask_maxdepth_col					.73
#DEFINE dm_mask_maxdepth_col_nvsi				.63

#DEFINE dm_mask_divetime_row					.0
#DEFINE dm_mask_divetime_column					.122


;   The content row contains 3 columns:
;   - depth and ascend rate warning
;   - max depth and warning messages
;   - dive time, apnea dive times and warning icon

;******* upper content / content row / 1st col *******

; GLOBAL
#DEFINE dm_offset								.14								;  14  start of content row

; Depth - full meters or feet
#DEFINE dm_depth_row_large						dm_offset						;  14
#DEFINE dm_depth_col_large						.0								;   0
#DEFINE dm_depth_bot_large						dm_depth_row_large+.61			;  75
#DEFINE dm_depth_rgt_large						dm_depth_col_large+.59			;  59
#DEFINE dm_depth_row_huge						.7								;   7
#DEFINE dm_depth_col_huge						.0								;   0
#DEFINE dm_depth_bot_huge						dm_depth_row_huge+.90			;  97
#DEFINE dm_depth_rgt_huge						dm_depth_col_huge+.90			;  90

; Depth - position of decimeters (shown if depth < 100 m)
#DEFINE dm_depth_dm_row_medium					dm_depth_row_large+.25			;  39
#DEFINE dm_depth_dm_col_medium					dm_depth_col_large+.40			;  40
#DEFINE dm_depth_dm_row_large					.37								;  37
#DEFINE dm_depth_dm_col_large					dm_depth_col_large+.58			;  58

; ascend rate - textual display
#DEFINE dm_velocity_text_row_norm				dm_depth_row_large+.62			;  76
#DEFINE dm_velocity_text_col_norm				dm_depth_col_large				;   0
#DEFINE dm_velocity_text_bot_norm				dm_velocity_text_row_norm+.23	;  99
#DEFINE dm_velocity_text_rgt_norm				dm_depth_rgt_large				;  59

; ascend/descend rate - graphical display
#DEFINE dm_velocity_graph_top					dm_offset+.10					;  24
#DEFINE dm_velocity_graph_lft					dm_depth_rgt_large+.3			;  61		+2 / 61
#DEFINE dm_velocity_graph_bot					dm_velocity_graph_top+.70		;  94
#DEFINE dm_velocity_graph_rgt					dm_upcnt_2ndcol-.3				;  72		-2 / 72
#DEFINE dm_velocity_graph_width					.10								;  12		12


;******* upper content / content row / 2nd col *******

; Start column
#DEFINE dm_upcnt_2ndcol							.74								;  74 - with vertical speed indicator enabled
#DEFINE dm_upcnt_2ndcol_nvsi					.64								;  64 - with vertical speed indicator disabled

; max depth
#DEFINE dm_max_depth_row						dm_offset						;  14
#DEFINE dm_max_depth_column						dm_upcnt_2ndcol					;  74
#DEFINE dm_max_depth_column_nvsi				dm_upcnt_2ndcol_nvsi			;  64
#DEFINE dm_max_depth_bot						dm_max_depth_row+.34			;  48
#DEFINE dm_max_depth_rgt						dm_max_depth_column+.36			; 100
#DEFINE dm_max_depth_dm_row						dm_max_depth_row+.11			;  25
#DEFINE dm_max_depth_dm_column					dm_max_depth_column+.23			;  87
#DEFINE dm_max_depth_dm_column_nvsi				dm_max_depth_column_nvsi+.23	;  77
#DEFINE dm_max_alt_column						.0								;   0
#DEFINE dm_max_alt_row							.170							; 170
#DEFINE dm_max_dm_alt_column					dm_max_alt_column+.60			;  60

; Warning area (combined)
#DEFINE dm_warning_row							dm_offset+.36					;  50
#DEFINE dm_warning_column						dm_upcnt_2ndcol+.23				;  97	ex +.0
#DEFINE dm_warning_bot							dm_warning_row+.49				;  99
#DEFINE dm_warning_rgt							dm_warning_column+.62			; 136
#DEFINE dm_warning_length						.9								;      total string length in number of characters

; Warning row #1
#DEFINE dm_warning1_row							dm_warning_row					;  50
#DEFINE dm_warning1_column						dm_warning_column				;  64
#DEFINE dm_warning1_bot							dm_warning1_row+.23				;  73
#DEFINE dm_warning1_rgt							dm_warning_rgt					; 136

; Warning row #2
#DEFINE dm_warning2_row							dm_warning_row+.24				;  74
#DEFINE dm_warning2_column						dm_warning_column				;  64
#DEFINE dm_warning2_bot							dm_warning2_row+.23				;  97
#DEFINE dm_warning2_rgt							dm_warning_rgt					; 136


;******* upper content / content row / 3rd col *******

; Dive time
#DEFINE dm_divetime_row							dm_offset						;  14
#DEFINE dm_divetime_col_medium					.115							; 115
#DEFINE dm_divetime_col_large					.91								;  91
#DEFINE dm_divetime_bot_medium					dm_divetime_row+.34				;  48
#DEFINE dm_divetime_bot_large					dm_divetime_row+.57				;  71
#DEFINE dm_divetime_rgt							.159							; 159

#DEFINE dm_divetime_sec_row_small				dm_divetime_row+.11				;  25
#DEFINE dm_divetime_sec_col_small				dm_divetime_col_medium+.23		; 138
#DEFINE dm_divetime_minonly_col_medium			.111							; 111

#DEFINE dm_divetime_sec_row_medium				dm_divetime_sec_row_small+.13	;  38
#DEFINE dm_divetime_sec_col_medium				dm_divetime_col_large+.39		; 130
#DEFINE dm_divetime_minonly_col_large			dm_divetime_col_large+.8		;  99

; Sign - normal layout
#DEFINE dm_sign_row_norm						dm_offset+.41					;  55
#DEFINE dm_sign_col_norm						.74								;  74
#DEFINE dm_sign_bot_norm						dm_sign_row_norm+.38			;  93
#DEFINE dm_sign_rgt_norm						dm_sign_col_norm+.22			;  96

; Apnea dive time
#DEFINE dm_divetime_apnoe_row					dm_offset						;  14
#DEFINE dm_divetime_apnoe_col					.115							; 115
#DEFINE dm_divetime_apnoe_secs_row				dm_divetime_apnoe_row+.11		;  25
#DEFINE dm_divetime_apnoe_secs_col				dm_divetime_apnoe_col+.24		; 139

; Apnea total time
#DEFINE dm_apnoe_total_divetime_row				dm_divetime_apnoe_row+.50		;  64
#DEFINE dm_apnoe_total_divetime_col				.103							; 103
#DEFINE dm_apnoe_total_divetime_secs_row		dm_apnoe_total_divetime_row+.11	;  75
#DEFINE dm_apnoe_total_divetime_secs_col		dm_apnoe_total_divetime_col+.36	; 139
#DEFINE dm_total_apnoe_text_row					dm_apnoe_total_divetime_row-.11	;  53
#DEFINE dm_total_apnoe_text_col					.132							; 132

; I. end of the upper content row. (0-99)

; 1px space between the 1st and 2nd content rows
#DEFINE dm_sep_1_2_row							dm_offset+.86					; 100


; II. custom/selectable content row

;   The custom view display area is: 101,163,0,159 (t,b,l,r), or 0,101->159,163

;******* Custom View: Global *******

#DEFINE dm_customview_row						dm_offset+.87					; 101
#DEFINE dm_customview_column					.0								;   0
#DEFINE dm_customview_bot						dm_customview_row+.62			; 163
#DEFINE dm_customview_rgt						.159							; 159


;******* Custom View: Avg depth, stopwatch and avg depth *******

#DEFINE dm_custom_avr_stop_title_row			dm_customview_row+.1			; 102
#DEFINE dm_custom_avr_stop_row					dm_customview_row+.16			; 117
#DEFINE dm_custom_avr_stop_column1				.0								;   0
#DEFINE dm_custom_avr_stop_column2				.54								;  54
#DEFINE dm_custom_avr_stop_column3				.118							; 118


;******* Custom View: Decompressions stops *******

; Title
#DEFINE dm_custom_decoplan_title_row			dm_customview_row				; 101
#DEFINE dm_custom_decoplan_title_column			.60								;  60

; 1st col
#DEFINE dm_cust_dstop_2nd_stop_row				dm_customview_row+.14			; 115
#DEFINE dm_cust_dstop_2nd_stop_column			.0								;   0
#DEFINE dm_cust_dstop_3rd_stop_row				dm_customview_row+.37			; 138
#DEFINE dm_cust_dstop_3rd_stop_column			dm_cust_dstop_2nd_stop_column	;   0

; 2nd col
#DEFINE dm_cust_dstop_4th_stop_row				dm_cust_dstop_2nd_stop_row		; 115
#DEFINE dm_cust_dstop_4th_stop_column			.56								;  56
#DEFINE dm_cust_dstop_5th_stop_row				dm_cust_dstop_3rd_stop_row		; 138
#DEFINE dm_cust_dstop_5th_stop_column			dm_cust_dstop_4th_stop_column	;  56

; 3rd col
#DEFINE dm_cust_dstop_6th_stop_row				dm_cust_dstop_2nd_stop_row		; 115
#DEFINE dm_cust_dstop_6th_stop_column			.111							; 111
#DEFINE dm_cust_dstop_7th_stop_row				dm_cust_dstop_3rd_stop_row		; 138
#DEFINE dm_cust_dstop_7th_stop_column			dm_cust_dstop_6th_stop_column	; 111


;******* Custom View: Time, Battery, Surface Pressure *******

; Clock
#DEFINE dm_custom_clock_title_row				dm_customview_row+.1			; 102
#DEFINE dm_custom_clock_row						dm_customview_row+.16			; 117
#DEFINE dm_custom_clock_column					.0								;   0

; Battery
#DEFINE dm_custom_battery_title_row				dm_customview_row+.1			; 102
#DEFINE dm_custom_battery_volt_row				dm_customview_row+.16			; 117
#DEFINE dm_custom_battery_percent_row			dm_custom_ead_row+.23			; 140
#DEFINE dm_custom_battery_column				.62								;  62

; Surface Pressure
#DEFINE dm_custom_surfpres_title_row			dm_customview_row+.1			; 102
#DEFINE dm_custom_surfpres_row					dm_customview_row+.16			; 117
#DEFINE dm_custom_surfpres_column				.95								;  95


;****** Custom View: ppO2, EAD/ENDS and CNS *******

; ppO2
#DEFINE dm_custom_ppo2_title_row				dm_customview_row+.1			; 102
#DEFINE dm_custom_ppo2_row						dm_customview_row+.18			; 119
#DEFINE dm_custom_ppo2_column					.2								;   2

; EAD/END
#DEFINE dm_custom_eadend_title_row				dm_customview_row+.1			; 102
#DEFINE dm_custom_ead_row						dm_customview_row+.16			; 117
#DEFINE dm_custom_ead_column					.50								;  50
#DEFINE dm_custom_end_row						dm_custom_ead_row+.23			; 140
#DEFINE dm_custom_end_column					dm_custom_ead_column			;  50

; CNS
#DEFINE dm_custom_cns_title_row					dm_customview_row+.1			; 102
#DEFINE dm_custom_cns_row						dm_customview_row+.18			; 119
#DEFINE dm_custom_cns_column					.115							; 115


;****** Custom View: tripple CNS *******

#DEFINE dm_custom_cns3_title_row				dm_customview_row+.1			; 102
#DEFINE dm_custom_cns3_row						dm_customview_row+.16			; 117
#DEFINE dm_custom_cns3_column1					.8								;   8
#DEFINE dm_custom_cns3_column2					.62								;  62
#DEFINE dm_custom_cns3_column3					.115							; 115


;****** Custom View: Ceiling, Tissues, (current GF)

; Ceiling
#DEFINE dm_custom_ceiling_title_row				dm_customview_row+.1			; 102
#DEFINE dm_custom_ceiling_row					dm_customview_row+.18			; 119
#DEFINE dm_custom_ceiling_column				.62								;  62

; Tissue title
#DEFINE dm_custom_tissue_title_row				dm_customview_row+.1			; 102
#DEFINE dm_custom_tissue_title_column			.120							; 120

; N2 / He values
#DEFINE dm_custom_tissue_N2_row					dm_custom_ead_row+.5			; 122
#DEFINE dm_custom_tissue_N2_column				.105							; 105
#DEFINE dm_custom_tissue_He_row					dm_custom_end_row+.5			; 145
#DEFINE dm_custom_tissue_He_column				dm_custom_tissue_N2_column		; 105

; Tissue diagram
#DEFINE dm_custom_tissue_diagram_top			dm_customview_row+.16			; 117
#DEFINE dm_custom_tissue_diagram_bottom			dm_custom_tissue_diagram_top+.43; 160
#DEFINE dm_custom_tissue_diagram_left			.116							; 116
#DEFINE dm_custom_tissue_diagram_frame_spacing	.8								;   8


;******* Custom View: GF-lo/hi, aGF-lo/hi, current GF value *******

; Title
#DEFINE dm_custom_gf_title_row					dm_customview_row+.1			; 102
#DEFINE dm_custom_gf_row						dm_customview_row+.18			; 119
#DEFINE dm_custom_gf_column1					.0								;   0
#DEFINE dm_custom_gf_column2					.65								;  65
#DEFINE dm_custom_gf_column3					.95								;  95


;******* Custom View: Compass *******

; Title
#DEFINE dm_custom_compass_mask_row				dm_customview_row				; 101
#DEFINE dm_custom_compass_mask_column			.65								;  65

; Head and arrows
#DEFINE dm_custom_compass_head_row				dm_customview_row+.39			; 140
#DEFINE dm_custom_compass_head_column			.62								;  62
#DEFINE dm_custom_compass_ldir_column			.5								;   5
#DEFINE dm_custom_compass_rdir_column			.140							; 140

; Ruler
#DEFINE dm_custom_compass_graph_row				dm_customview_row				; 101
#DEFINE dm_custom_compass_graph_height			.33								;  33
#DEFINE dm_custom_compass_tick_height			.3								;   3
#DEFINE dm_custom_compass_tick_top_top			dm_custom_compass_graph_row+.1	; 102
#DEFINE dm_custom_compass_tick_top_bot			dm_custom_compass_graph_row+.4	; 105
#DEFINE dm_custom_compass_label_row				dm_custom_compass_graph_row+.6	; 107
#DEFINE dm_custom_compass_label_height			.24								;  24
#DEFINE dm_custom_compass_tick_bot_top			dm_custom_compass_graph_row+.30	; 131
#DEFINE dm_custom_compass_tick_bot_bot			dm_custom_compass_graph_row+.33	; 134


;******* Custom View: O2 Sensor Values *******

#DEFINE dm_custom_hud_title_row					dm_customview_row+.1			; 102
#DEFINE dm_custom_hud_row						dm_customview_row+.16			; 117
#DEFINE dm_custom_hud_sensor1_column			.6								;   6
#DEFINE dm_custom_hud_sensor2_column			.62								;  62
#DEFINE dm_custom_hud_sensor3_column			.118							; 118


;******* Custom View: Gas Needs *******

#DEFINE dm_custom_gas_mask_row					dm_customview_row				; 101
#DEFINE dm_custom_gas_row1						dm_customview_row+.14			; 115
#DEFINE dm_custom_gas_row2						dm_customview_row+.37			; 138
#DEFINE dm_custom_gas_column_title				.29								;  29
#DEFINE dm_custom_gas_column1					.5								;   5
#DEFINE dm_custom_gas_column2					.85								;  85


; ******* Custom View: Tank Pressures *******

#DEFINE dm_custom_tankdata_mask_row				dm_customview_row+.1			; 102
#DEFINE dm_custom_tankdata_row					dm_customview_row+.16			; 117
#DEFINE dm_custom_tankdata_pres1_col			.2								;   2
#DEFINE dm_custom_tankdata_pres2_col			.115							; 115
#DEFINE dm_custom_tankdata_SAC_col				.56								;  56


;******* Custom View: Sensor Check *******

#DEFINE dm_custom_s_check_title_row				dm_customview_row+.1			; 102
#DEFINE dm_custom_s_check_row					dm_customview_row+.18			; 119
#DEFINE dm_custom_s_check_title_column			.50								;  50
#DEFINE dm_custom_ppO2_column					.115							; 115
#DEFINE dm_custom_ppDil_column					.2								;   2


;******* Custom View: PSCR Info *******

#DEFINE dm_custom_pscr_title_row				dm_customview_row+.1			; 102
#DEFINE dm_custom_pscr_row						dm_customview_row+.18			; 119
#DEFINE dm_custom_pscr_drop_column				.55								;  55
#DEFINE dm_custom_pscr_ratio_column				.105							; 105


; II. end of the custom content row (101-163)

; 1px space between the 2nd and 3rd content rows
#DEFINE dm_sep_2_3_row							dm_offset+.150					; 164


; III. The 3rd content row contains temperature, active gas, NDL/TTS time,
; simulator menu, active/dil gas, decostop, Apnea surface time and max depth
;  The content row contains 2 columns:
;   - temperature, gas names
;   - NDL/TTS, DecoStop

#DEFINE dm_3rdrow_top							dm_offset+.151					; 165
#DEFINE dm_3rdrow_bot							.239							; 239
#DEFINE dm_3rdrow_lft							.0								;   0
#DEFINE dm_3rdrow_rgt							.159							; 159


;******* Bottom content / 1st col *******

; Temperature
#DEFINE dm_temp_row								dm_3rdrow_top-.3				; 162
#DEFINE dm_temp_column							dm_3rdrow_lft					;   0

; Simulation text (pre-menu)
#DEFINE dm_premenu_row							dm_3rdrow_top-.3				; 162
#DEFINE dm_premenu_col							dm_3rdrow_lft					;   0
#DEFINE dm_premenu_bot							dm_premenu_row+.23				; 185
#DEFINE dm_premenu_rgt							dm_premenu_col+.43				;  43

; ascend rate - alternative textual display
#DEFINE dm_velocity_text_row_alt				dm_temp_row						; 162
#DEFINE dm_velocity_text_col_alt				.45								;  45
#DEFINE dm_velocity_text_bot_alt				dm_velocity_text_row_alt+.23	; 185
#DEFINE dm_velocity_text_rgt_alt				dm_velocity_text_col_alt+.34	;  79

; Diluent gas
#DEFINE dm_active_dil_row						dm_3rdrow_top+.21				; 186
#DEFINE dm_active_dil_column					dm_3rdrow_lft					;   0

; OC gas, blinking better gas, setpoint or bailout for CCR/pSCR
#DEFINE dm_active_gas_sp_value_row				.208							; 208
#DEFINE dm_active_gas_sp_value_col				dm_3rdrow_lft					;   0
#DEFINE dm_active_sp_label_row					dm_active_gas_sp_value_row		; 208
#DEFINE dm_active_sp_label_col					dm_active_gas_sp_value_col+.45	;  45

; Sign - alternative layout
#DEFINE dm_sign_row_alt							.193							; 193
#DEFINE dm_sign_col_alt							.52								;  52
#DEFINE dm_sign_bot_alt							dm_sign_row_alt+.38				; 231
#DEFINE dm_sign_rgt_alt							dm_sign_col_alt+.22				;  74

;******* Bottom content / 2nd col *******

; 1st Deco Stop
#DEFINE dm_decostop_row_norm					dm_3rdrow_top					; 165
#DEFINE dm_decostop_col_norm					.82								;  82
#DEFINE dm_decostop_row_alt_depth				dm_decostop_row_norm-.1			; 164
#DEFINE dm_decostop_col_alt_depth				dm_decostop_col_norm-.1			;  81
#DEFINE dm_decostop_row_alt_time				dm_decostop_row_norm			; 165
#DEFINE dm_decostop_col_alt_time				dm_decostop_col_norm+.47		; 129

; Safety Stop
#DEFINE dm_safetystop_row						dm_3rdrow_top					; 165
#DEFINE dm_safetystop_column					.118							; 118
#DEFINE dm_safetystop_bot						dm_safetystop_row+.31			; 196
#DEFINE dm_safetystop_rgt						.159							; 159
#DEFINE dm_safetystop_text_row					dm_safetystop_row+.1			; 166
#DEFINE dm_safetystop_text_column				.80								;  80  for the 4 chars "Stop"

; TTS
#DEFINE dm_tts_value_row						dm_3rdrow_top+.43				; 208
#DEFINE dm_tts_value_col_99						.129							; 129
#DEFINE dm_tts_value_col_999					.124							; 122
#DEFINE dm_tts_value_col_999x					.118							; 118
#DEFINE dm_tts_text_row_norm					dm_tts_value_row				; 208
#DEFINE dm_tts_text_col_norm					.85								;  85
#DEFINE dm_tts_text_row_alt						dm_tts_value_row+.18			; 226
#DEFINE dm_tts_text_col_alt						.86								;  86

; NDL - the same position as TTS
#DEFINE dm_ndl_value_row_norm					dm_tts_value_row				; 208
#DEFINE dm_ndl_value_col_norm					.118							; 118
#DEFINE dm_ndl_value_row_alt					.182							; 182
#DEFINE dm_ndl_value_col_alt					.120							; 120
#DEFINE dm_ndl_text_row							dm_tts_text_row_norm			; 202
#DEFINE dm_ndl_text_column						dm_tts_text_col_norm			;  85

; FTTS (only modded screen)
#DEFINE dm_ftts_value_row						dm_3rdrow_top+.64				; 215
#DEFINE dm_ftts_value_column					.97								;  97

; Grid line (only modded screen)
#DEFINE dm_gassep_row							dm_sep_2_3_row					; 164
#DEFINE dm_gassep_bot							.239							; 239
#DEFINE dm_gassep_column						.78								;  78


;******* Bottom content / Apnea mode *******

#DEFINE dm_apnoe_last_max_depth_text_row		.192							; 192
#DEFINE dm_apnoe_last_max_depth_text_col		.20								;  20
#DEFINE dm_apnoe_last_max_depth_row				.207							; 207
#DEFINE dm_apnoe_last_max_depth_column			.15								;  15

#DEFINE dm_apnoe_surface_time_text_row			.192							; 192
#DEFINE dm_apnoe_surface_time_text_col			.100							; 100
#DEFINE dm_apnoe_surface_time_row				.207							; 207
#DEFINE dm_apnoe_surface_time_column			.80								;  80


;******* Bottom content / Gauge mode *******
#DEFINE dm_gauge_max_depth_text_row				.192
#DEFINE dm_gauge_max_depth_text_col				.25
#DEFINE dm_gauge_max_depth_row					.207
#DEFINE dm_gauge_max_depth_col					.15

#DEFINE dm_gauge_avg_depth_text_row				.192
#DEFINE dm_gauge_avg_depth_text_col				.100
#DEFINE dm_gauge_avg_depth_row					.207
#DEFINE dm_gauge_avg_depth_col					.85



; IV. The last set of parameters is for the menus displayed in dive mode

; Divemode menu
#DEFINE dm_menu_row								.164							; 164  upper row, the frame's top line is the separator
#DEFINE dm_menu_lower							.239							; 239  lower border
#DEFINE dm_menu_left							.0								;   0  left
#DEFINE dm_menu_right							.159							; 159  right

#DEFINE dm_menu_item1_row						dm_menu_row+.1					; 165
#DEFINE dm_menu_item1_column					.9								;   9
#DEFINE dm_menu_item2_row						dm_menu_item1_row+.24			; 189
#DEFINE dm_menu_item2_column					dm_menu_item1_column			;   9
#DEFINE dm_menu_item3_row						dm_menu_item2_row+.24			; 213
#DEFINE dm_menu_item3_column					dm_menu_item1_column			;   9

#DEFINE dm_menu_item4_row						dm_menu_row+.1					; 165
#DEFINE dm_menu_item4_column					.89								;  89
#DEFINE dm_menu_item5_row						dm_menu_item4_row+.24			; 189
#DEFINE dm_menu_item5_column					dm_menu_item4_column			;  89
#DEFINE dm_menu_item6_row						dm_menu_item5_row+.24			; 213
#DEFINE dm_menu_item6_column					dm_menu_item4_column			;  89
