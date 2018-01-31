;=============================================================================
;
;   File calibrate.inc								REFACTORED VERSION V2.91
;
;=============================================================================

; DELETE	## voting logic
;	extern		compute_ppo2			; compute mv_sensorX and ppo2_sensorX arrays

	extern		calibrate_mix			; Calibrate with any mix
	
; DELETE	## voting logic
;    extern      check_sensors           ; Check O2 sensor thresholds for fallback

; ADD		## voting logic
	extern		compute_mvolts_for_all_sensors	; compute sensor mv values from digital transmitted data

    extern      transmit_setpoint       ; Transmit current setpoint from WREG (in cbar) to external electronics
	