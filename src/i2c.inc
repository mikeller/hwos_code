;=============================================================================
;
;   File i2c.inc														V2.99c
;
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;  2012-10-24 : [mH] Creation

	extern	I2C_RX_accelerometer
	extern	I2C_init_accelerometer
	extern	I2C_sleep_accelerometer
	extern	I2C_init_compass
	extern	I2C_sleep_compass
	extern	I2C_RX_compass
	extern	lt2942_get_voltage				; read battery voltage registers
	extern  lt2942_get_temperature
	extern	lt2942_get_accumulated_charge	; get battery gauge registers
	extern	lt2942_init						; init
	extern	lt2942_get_status				; get status

 IFDEF _rx_functions
	extern	I2C_probe_OSTC_rx				; set ostc_rx_present bit if present
	extern	I2C_get_tankdata				; get the tank data
	extern	I2C_update_OSTC_rx				; load new firmware into RX processor
 ENDIF
