;=============================================================================
;
;   File gaslist.inc                          combined next generation V3.03.1
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
	extern	gaslist_show_mix				; put "Nxlo", "Txlo/hi", "Air" or "O2" into Postinc2
	extern	do_toggle_gf_label

 IFDEF _cave_mode
	extern	do_turn_dive_label
 ENDIF


	; Setpoints and Diluents
 IFDEF _ccr_pscr
	extern	gaslist_strcat_setpoint
	extern	gaslist_spplus
	extern	gaslist_spdepthplus
	extern	gaslist_spdepthminus
	extern	gaslist_copy_dil_to_oc
 ENDIF


	; Select currently edited Gas
	extern	gaslist_gastitle


	; Main Gaslist Menu
	extern	gaslist_pO2
	extern	gaslist_mO2
	extern	gaslist_GasDepth
	extern	gaslist_show_type
	extern	gaslist_toggle_type
	extern	gaslist_cleanup_list

 IFDEF _helium
	extern	gaslist_pHe
	extern	gaslist_mHe
 ENDIF


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
	extern	do_toggle_max_pres_diff_label
 ENDIF
