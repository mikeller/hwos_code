;=============================================================================
;
;   File calibrate.inc                        combined next generation V3.03.1
;
;=============================================================================


 IFDEF _external_sensor
	extern	calibrate_mix					; calibrate sensors
	extern	compute_mvolts_for_all_sensors	; compute sensor mV values from digital transmitted data
	extern	transmit_setpoint				; transmit current setpoint to external electronics
 ENDIF
