;=============================================================================
;
;   File gaslist.inc													V2.99c
;
;   Interface to OSTC gas list management.
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;   2011-08-11 : [jDG] Creation.

	; Utils
	extern	gaslist_strcat_gas
	extern	gaslist_strcat_gas_WREG
	extern	gaslist_strcat_gas_cd
	extern	gaslist_strcat_setpoint

	extern	do_toggle_gf_label
	extern	do_toggle_max_pres_diff_label
	extern	gaslist_copy_dil_to_oc

	; Setpoint Setup
	extern	gaslist_spplus
	extern	gaslist_spdepthplus
	extern	gaslist_spdepthminus

	; Select currently edited Gas
	extern	gaslist_gastitle

	; Main Gaslist Menu
	extern	gaslist_pO2
	extern	gaslist_mO2
	extern	gaslist_pHe
	extern	gaslist_mHe
	extern	gaslist_GasDepth
	extern	gaslist_show_type
	extern	gaslist_toggle_type
	extern	gaslist_cleanup_list

	; Depth Sub-Menu
	extern	gaslist_pDepth
	extern	gaslist_mDepth
	extern	gaslist_MOD_END
	extern	gaslist_ppo2
	extern	gaslist_reset_mod_title
	extern	gaslist_reset_mod

	; Tank Sub-Menu
	extern	gaslist_tank_size_pres
	extern	gaslist_tank_size
	extern	gaslist_tank_pres
 IFDEF _rx_functions
	extern	gaslist_tank_id_pres
	extern	gaslist_tank_pairing
 ENDIF

 IFDEF _cave_mode
	extern	do_turn_dive_label
 ENDIF