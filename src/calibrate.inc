;=============================================================================
;
;   File calibrate.inc                      * combined next generation V3.09.4n
;
;=============================================================================


 IFDEF _external_sensor_eccr
	extern	calibrate_mix					; calibrate sensors
	extern	compute_mvolts_from_rawdata		; compute sensor mV values from digital transmitted data
	extern	transmit_setpoint				; transmit current setpoint to external electronics
 ENDIF
