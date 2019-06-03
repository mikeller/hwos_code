;=============================================================================
;
;   File i2c.inc                               combined next generation V3.1.0
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

	extern	lt2942_init						; init gauge IC
	extern	lt2942_get_status				; read gauge IC status
	extern	lt2942_get_voltage				; read battery voltage registers
	extern	lt2942_get_temperature			; read battery temperature
	extern	lt2942_get_accumulated_charge	; read battery gauge register
	extern	lt2942_charge_done				; set  battery gauge register to fully charged

 IFDEF _rx_functions
	extern	I2C_probe_OSTC_rx				; set ostc_rx_present bit if present
	extern	I2C_get_tankdata				; get the tank data
	extern	I2C_update_OSTC_rx				; load new firmware into RX processor
 ENDIF

 IFDEF _compass
	extern	I2C_RX_compass
 ENDIF