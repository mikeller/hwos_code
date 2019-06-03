;=============================================================================
;
;   File rx_firmware.asm                      combined next generation V3.03.4
;
;   Firmware for the RX Co-Processor
;
;   Copyright (c) 2019, HeinrichsWeikamp, all rights reserved.
;=============================================================================


#include "hwos.inc"						; mandatory header


rx_firmware_storage	code	0x18000

;-----------------------------------------------------------------------------

 IFDEF _rx_functions

	global	rx_firmware_storage
rx_firmware_storage:

;#include	"rx_firmware-1-33.inc"
;#include	"rx_firmware-1-37.inc"
#include	"rx_firmware-1-38.inc"


	global	rx_firmware_new_major
	global	rx_firmware_new_minor
rx_firmware_new_major:
	retlw	rx_firmware_major			; defined in firmware include file
rx_firmware_new_minor:
	retlw	rx_firmware_minor			; defined in firmware include file


 ENDIF	; _rx_functions

	END
