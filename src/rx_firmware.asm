;=============================================================================
;
;   File rx_firmware.asm                      combined next generation V3.09.4f
;
;   Firmware for the RX Co-Processor
;
;   Copyright (c) 2019, HeinrichsWeikamp, all rights reserved.
;=============================================================================


#include "hwos.inc"						; mandatory header


;=============================================================================
rx_firmware_storage		code	0x18000
;=============================================================================


 IFDEF _rx_update

	global	rx_firmware_storage
rx_firmware_storage:

#include	"rx_firmware-1-40.inc"

	global	rx_firmware_new_major
rx_firmware_new_major:
	retlw	rx_firmware_major			; defined in firmware include file

	global	rx_firmware_new_minor
rx_firmware_new_minor:
	retlw	rx_firmware_minor			; defined in firmware include file


 ENDIF	; _rx_update

;-----------------------------------------------------------------------------

	END
