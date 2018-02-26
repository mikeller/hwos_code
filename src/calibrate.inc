;=============================================================================
;
;   File calibrate.inc								REFACTORED VERSION V2.97
;
;=============================================================================

	extern	calibrate_mix					; Calibrate with any mix
	extern	compute_mvolts_for_all_sensors	; compute sensor mv values from digital transmitted data
	extern	transmit_setpoint				; Transmit current setpoint from WREG (in cbar) to external electronics
