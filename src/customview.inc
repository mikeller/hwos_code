;=============================================================================
;
;   File customview.inc                       combined next generation V3.03.2
;
;   Customview for divemode and surfacemode
;
;   Copyright (c) 2011, Matthias Heinrichs, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;   2011-08-10 : [mH] Import into hwOS sources

; Dive mode
	extern	dive_customview_mask
	extern	dive_customview_second
	extern	dive_customview_toggle

	extern	menuview_toggle
	extern	menuview_toggle_reset

; Surface mode
	extern	surf_customview_mask
	extern	surf_customview_toggle
