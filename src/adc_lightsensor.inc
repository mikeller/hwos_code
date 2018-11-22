;=============================================================================
;
;   File adc.inc
;
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;  2011-08-08 : [mH] moving from OSTC code

	extern	get_battery_voltage				; and percent...
	extern	get_ambient_level
	extern	reset_battery_pointer			; resets battery pointer 0x07-0x0C and battery_gauge:5
	extern	reset_battery_internal_only		; internal registers only
	extern	get_analog_inputs				; get AN8-10
	extern	piezo_config					; set up piezo sensitivity of heinrichs weikamp piezo buttons (~30ms)
	extern	get_analog_switches				; get analog switches
