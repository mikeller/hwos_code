;=============================================================================
;
;   File gaslist.inc                        * combined next generation V3.09.4j
;
;   Interface to OSTC gas list management.
;
;   Copyright (c) 2011, JD Gascuel, heinrichs weikamp gmbh, all right reserved.
;=============================================================================
; HISTORY
;   2011-08-11 : [jDG] Creation.

	; Utils
	extern	gaslist_strcat_mix_PRODL		; append gas mix to buffer, gas number in PRODL
	extern	gaslist_strcat_mix_WREG			; append gas mix to buffer, gas number in WREG
	extern	gaslist_strcat_mix				; append gas mix to buffer, lo= O2%, hi= He%
	extern	gaslist_strcat_gas_PRODL		; append full gas description to buffer by PRODL and dil flag
	extern	gaslist_strcat_gas				; append full gas description to buffer by gaslist_gas
	extern	gaslist_calc_mod				; calculate MOD in meters
	extern	gaslist_cleanup_list			; make sure there is only one FIRST gas & diluent

 IFDEF _ccr_pscr
	extern	gaslist_strcat_setpoint_PRODL	; print setpoint data by number in PRODL
	extern	gaslist_strcat_setpoint			; print setpoint data by number in gaslist_gas
 ENDIF


	; dynamic Titles
	extern	gaslist_MOD_END					; print MOD and END
	extern	gaslist_ppo2					; print ppO2 at Change Depth
	extern	gaslist_reset_mod_title			; print 'reset to MOD' title
