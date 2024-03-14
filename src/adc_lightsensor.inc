;=============================================================================
;
;   File adc_lightsensor.inc                  combined next generation V3.03.1
;
;
;   Copyright (c) 2011, JD Gascuel, heinrichs weikamp gmbh, all right reserved.
;=============================================================================
; HISTORY
;  2011-08-08 : [mH] moving from OSTC code

	extern	get_battery_voltage				; and percent...
	extern	get_ambient_level				; get ambient light level and adjust backlight
	extern	piezo_config					; set up piezo sensitivity of heinrichs weikamp piezo buttons (~30ms)
	extern	get_analog_switches				; get analog switches

 IFDEF _external_sensor
	extern	get_analog_inputs				; get AN8-10
 ENDIF
