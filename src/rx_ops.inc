;=============================================================================
;
;   File rx_ops.inc                            combined next generation V3.0.1
;
;
;   Copyright (c) 2018, heinrichs weikamp gmbh, all right reserved.
;=============================================================================

 IFDEF _rx_functions
	extern	get_pressure_readings
	extern	get_pres_by_transmitter_id
	extern	get_transmitter_id_by_slot
	extern	configure_sac_calculation
 ENDIF

 IFDEF _rx_update
	extern	update_tr_module
 ENDIF
