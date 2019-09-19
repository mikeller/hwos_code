;=============================================================================
;
;   File gaslist.asm                          combined next generation V3.03.5
;
;   Managing OSTC gas list
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;   2011-08-11 : [jDG] Creation.

#include "hwos.inc"						; mandatory header
#include "convert.inc"
#include "math.inc"						; div16x16 for MOD calculation
#include "strings.inc"
#include "tft.inc"
#include "tft_outputs.inc"
#include "shared_definitions.h"
#include "wait.inc"
#include "rx_ops.inc"


	extern	convert_mbar_to_feet
	extern	tSetup_GasDepth
	extern	tGasDisabled
	extern	tDilDisabled
	extern	tLiter
	extern	tbar10
	extern	tbar


gaslist	CODE

;-----------------------------------------------------------------------------

;=============================================================================
; Helper Functions for divemenu_tree.asm
;
; They need to be put in a different file than
; where the MENU_DYNAMIC macros uses them.

	global	do_toggle_gf_label
do_toggle_gf_label:
	movff	char_I_deco_model,WREG		; 0 = ZH-L16, 1 = ZH-L16-GF
	decfsz	WREG,W						; toggle GF only in GF modes - in GF mode?
	bra		do_toggle_gf_label_1		; NO - print in disabled color
	movff	opt_enable_aGF,WREG			; =1: aGF can be selected underwater
	decfsz	WREG,W						; aGF enabled?
	bra		do_toggle_gf_label_1		; NO - print in disabled color
	bra		do_toggle_gf_label_2		; YES to both - print in standard color
do_toggle_gf_label_1:
	call	TFT_disabled_color
do_toggle_gf_label_2:
	STRCAT_TEXT tDivemenu_ToggleGF
	return

;=============================================================================

 IFDEF _cave_mode

	global	do_turn_dive_label
do_turn_dive_label:
	btfss	cave_mode					; cave mode switched on?
	call	TFT_disabled_color			; NO  - print in disabled color
	btfsc	dive_turned					; dive already turned?
	call	TFT_attention_color			; YES - print in attention color
	STRCAT_TEXT tDivemenu_TurnDive		; output label
	return

 ENDIF

;=============================================================================

 IFDEF _rx_functions

	global	do_toggle_max_pres_diff_label
do_toggle_max_pres_diff_label:
	movff	opt_TR_mode,WREG			; get TR mode
	xorlw	.2							; compare with 2 (ind.double)
	tstfsz	WREG						; equal?
	call	TFT_disabled_color			; NO - print in disabled color
	STRCAT_TEXT tTrMaxDeltaP			; output label
	movff	char_I_max_pres_diff,lo
	output_99
	STRCAT_TEXT	tbar					; " bar"
	return

 ENDIF

;=============================================================================

 IFDEF _ccr_pscr

	global	gaslist_copy_dil_to_oc
gaslist_copy_dil_to_oc:
;
;  Memory Map:
;  -----------------------------------------
;  opt_gas_O2_ratio				res 5
;  opt_dil_O2_ratio				res 5
;  opt_gas_He_ratio				res 5
;  opt_dil_He_ratio				res 5
;  opt_gas_type					res 5
;  opt_dil_type					res 5
;  opt_gas_change				res 5
;  opt_dil_change				res 5
;
;  char_I_gas_avail_size		res 10
;  char_I_gas_avail_pres		res 10
;
	bcf		copying_dil					; default to copying a gas
	movf	gaslist_gas,W				; copy current gas or diluent number to WREG
	btfss	is_diluent_menu				; setting up diluents?
	bra		gaslist_copy_dil_to_oc_1	; NO  - gaslist_gas is already pointing to an OC gas
	addlw	-.5							; YES - subtract offset between diluents and gases
	movwf	gaslist_gas					;     - let gaslist_gas point to the corresponding OC gas
	bsf		copying_dil					;     - we are copying a diluent
	bcf		is_diluent_menu				;     - pretend we are setting up OC gases
gaslist_copy_dil_to_oc_1:
	lfsr	FSR0,opt_dil_O2_ratio		; load base address of diluents settings, ASM variables
	lfsr	FSR1,opt_gas_O2_ratio		; load base address of gas      settings, ASM variables
	movff	PLUSW0,PLUSW1				; copy O2 ratio
	addlw	.10							; add offset from O2 ratios to He ratios
	movff	PLUSW0,PLUSW1				; copy He ratio
	addlw	.10							; add offset from He ratios to types
	movff	PLUSW0,PLUSW1				; copy type
	addlw	.10							; add offset from type to change depth
	movff	PLUSW0,PLUSW1				; copy change depth
	addlw	-.30						; wind back to initial gas number
	lfsr	FSR0,char_I_gas_avail_size+5; load base address of diluents settings, shared variables
	lfsr	FSR1,char_I_gas_avail_size+0; load base address of gas      settings, shared variables
	movff	PLUSW0,PLUSW1				; copy tank size
	addlw	.10							; add offset from tank sizes to pressure budget
	movff	PLUSW0,PLUSW1				; copy pressure budget
	call	gaslist_cleanup_list		; make sure that there will be just one first gas
	btfss	copying_dil					; are we copying a diluent?
	return								; NO  - done
	bsf		is_diluent_menu				; YES - restore to be setting up diluents
	movlw	.5							;     - offset between OC gases and diluents
	addwf	gaslist_gas,F				;     - let gaslist_gas point to the diluent again
	WIN_BOX_BLACK .30,.239,.0,.159		;     - create some visual effect to show activity
	WAITMS	.200						;     - pause for 200 ms
	return								;     - done

 ENDIF

;=============================================================================

;=============================================================================
; Append gas description to current string
;
; Input:  PRODL : gas number (0..4)
;         FSR2  : Current string position
; Output: Text appended into buffer pointed by FSR2

	global	gaslist_strcat_gas
	global	gaslist_strcat_gas_WREG
gaslist_strcat_gas:						; entry point with gas/dil in PRODL (0-4) and flag 'is_diluent_menu' set accordingly
	movff	PRODL,gaslist_gas			; get current menu item (0-4)
	movlw	.5							; offset between gases and diluents
	btfsc	is_diluent_menu				; setting up diluents?
	addwf	gaslist_gas,F				; YES - add the offset
	movf	gaslist_gas,W				; copy to WREG
gaslist_strcat_gas_WREG:				; entry point with gas/dil in WREG (0-9)
	lfsr	FSR1,opt_gas_O2_ratio		; load base address of opt_gas_O2_ratio
	movff	PLUSW1,lo					; read O2 ratio
	lfsr	FSR1,opt_gas_He_ratio		; load base address of opt_gas_He_ratio
	movff	PLUSW1,hi					; read He ratio
	goto	gaslist_show_mix			; put "Nxlo", "Txlo/hi", "Air" or "O2" into Postinc2, and RETURN


;=============================================================================
; Append current mix to current string (for dive mode)
;
; Input:  FSR2 : Current string position
; Output: Text appended into buffer pointed by FSR2

	global	gaslist_strcat_gas6
gaslist_strcat_gas6:					; show current O2/He mix
	STRCAT_TEXT tGas					; print "Gas"
	STRCAT	": "						; print ":"
	movff	gas6_O2_ratio,hi			; TFT_color_code_gaslist needs O2 ratio in hi
	call	TFT_color_code_gaslist		; color-code according to O2 ratio and depth
	movff	gas6_O2_ratio,lo			; gaslist_show_mix needs O2 ratio in lo
 IFDEF _helium
	movff	gas6_He_ratio,hi			;                ... and He ratio in hi
 ELSE
	clrf	hi							;                ... and He ration will be zero
 ENDIF
	goto	gaslist_show_mix			; put "Nxlo", "Txlo/hi", "Air" or "O2" into Postinc2, and return


;=============================================================================
; Helper functions for menu_tree

	global	gaslist_GasDepth
gaslist_GasDepth:
	movf	gaslist_gas,W				; load gas/dil index into WREG (0-9)
	lfsr	FSR1,opt_gas_change			; load base address of change depths
	tstfsz	PLUSW1						; change depth = 0 ?
	bra		gaslist_GasDepth_1			; NO
	lfsr	FSR1,opt_gas_type			; YES - load base address of opt_gas_type
	tstfsz	PLUSW1						;     - type = disabled ?
	call	TFT_attention_color			;       NO  - print in attention color (yellow)
gaslist_GasDepth_1:
	STRCAT_TEXT tSetup_GasDepth
	return


	global	gaslist_show_type
gaslist_show_type:
	movf	gaslist_gas,W
	lfsr	FSR1,opt_gas_type			; load base address of opt_gas_type
	movff	PLUSW1,lo					; read gas type
	STRCAT_TEXT tType
	lfsr	FSR1,tGasDisabled			; load base address of gas type labels
	btfsc	is_diluent_menu				; setting up diluents?
	lfsr	FSR1,tDilDisabled			; YES - load base address of diluent type labels
	movff	lo,WREG						; 0-3
	rlncf	WREG						; x2
	addwf	FSR1L,F						; adjust address pointer to required text
	movlw	.0
	addwfc	FSR1H,F
	call	strcat_text					; copy label text
	return


	global	gaslist_toggle_type
gaslist_toggle_type:
	movf	gaslist_gas,W
	lfsr	FSR1,opt_gas_type			; load base address of opt_gas_type
	movff	PLUSW1,lo					; read gas type
	incf	lo,F						; increment type
	btfsc	is_diluent_menu				; setting up diluents?
	bra		gaslist_toggle_type2		; YES - diluents
	btfsc	lo,2						; NO  - gases, type index > 3 ?
	clrf	lo							;       YES - clear to zero
	movff	lo,PLUSW1					;     - copy back result
	return
gaslist_toggle_type2:
	movlw	.3
	cpfslt	lo							; index > 2 ?
	clrf	lo							; YES - clear to zero
	movf	gaslist_gas,W				; restore gaslist_gas in WREG
	movff	lo,PLUSW1					; copy back result
	return

;=============================================================================

 IFDEF _ccr_pscr

	global	gaslist_strcat_setpoint
	global	gaslist_strcat_setpoint_0
gaslist_strcat_setpoint:				; entry point with setpoint index in PRODL
	movff	PRODL,gaslist_gas			; get current menu item (0-4)
gaslist_strcat_setpoint_0:				; entry point with setpoint index in gaslist_gas
	bsf		leftbind
	btfsc	short_gas_descriptions		; shall use short versions of gaslist_strcat_setpoint?
	bra		gaslist_strcat_setpoint2	; YES - use short version
	STRCAT_TEXT tSP						; "SP"
	incf	gaslist_gas,W				; (0-4) -> (1-5) into WREG
	movwf	lo
	output_8							; print SP number
	bcf		leftbind
	PUTC	":"
gaslist_strcat_setpoint2:				; short version
	btfsc	divemode
	bra		gaslist_strcat_setpoint4	; no "*" in dive mode
	movf	gaslist_gas,W				; (0-4) into WREG
	bnz		gaslist_strcat_setpoint3	; SP index = 0 ?
	PUTC	"*"							; YES - print *
	bra		gaslist_strcat_setpoint4	;     - continue with cbar value
gaslist_strcat_setpoint3:				; NO
	PUTC	" "							;     - print a space
gaslist_strcat_setpoint4:
	movf	gaslist_gas,W				; (0-4) into WREG
	lfsr	FSR1,opt_setpoint_cbar		; load base address of setpoint cbar values
	movf	PLUSW1,W					; read cbar value
	movwf	lo
	clrf	hi
	bsf		leftbind
	output_16dp d'3'					; print as X.XX
	btfsc	divemode					; in dive mode?
	bra		gaslist_strcat_setpoint5	; YES - skip text in dive mode
	STRCAT_TEXT tbar					; NO  - print "bar"
gaslist_strcat_setpoint5:
	PUTC	" "							; print a space
	movf	gaslist_gas,W				; (0-4) into WREG
	lfsr	FSR1,opt_setpoint_change	; load base address of switch depths
	movff	PLUSW1,lo					; read switch depth into lo
	bra		gaslist_strcat_depth		; print depth in meters or ft

 ENDIF	; _ccr_pscr

;----------------------------------------------------------------------------
; Append gas description to current string
;
; Prints gas number, * if first, = if deco gas, gas composition and change depth,
; including fancy color-coding
;
; Input:  PRODL gas number (0..4)
;         FSR2  current string position
; Output: text appended to buffer pointed by FSR2
;
; NOTE: used in the menu-tree for the MENU_CALLBACK entry

	global	gaslist_strcat_gas_cd
	global	gaslist_gastitle
gaslist_strcat_gas_cd:					; entry point with gas in PRODL (0-4) and flag 'is_diluent_menu' set accordingly
	movff	PRODL,gaslist_gas			; get current menu item (0-4)
	movlw	.5							; offset between gases and diluents
	btfsc	is_diluent_menu				; setting up diluents?
	addwf	gaslist_gas,F				; YES - add the offset
gaslist_gastitle:						; entry point with gas/dil in gaslist_gas (0-4 for gases, 5-9 for diluents)
	bcf		win_invert					; clear flag for inverted output by default
	btfsc	short_gas_descriptions		; shall use short versions of gaslist_strcat_gas_cd?
	bra		gaslist_gastitle1			; YES - use short version
	incf	gaslist_gas,W				; (0-9) -> (1-10) into WREG
	movwf	lo
	movlw	.6							; diluents start with 6
	cpfslt	lo							; gas number < 6 ?
	bra		gaslist_gastitle_dil		; NO  - it's a diluent
	STRCAT_TEXT tGas					; YES - it's a gas
	bra		gaslist_gastitle0
gaslist_gastitle_dil:
	STRCAT_TEXT tDil
	movlw	.5							; offset between gases and diluents
	subwf	lo,F						; subtract offset from diluent number (6-10) -> (1-5)
gaslist_gastitle0:
	bsf		leftbind
	output_8							; print gas/dil number (1-5)
	bcf		leftbind
	PUTC	":"
gaslist_gastitle1:						; short version of gaslist_strcat_gas_cd
	btfsc	divemode					; in dive mode?
	bra		gaslist_gastitle3			; YES - no "*" and "=" in front of gas composition, no highlighting for transmitters paired

 IFDEF _rx_functions
	btfss	tr_functions_activated		; NO  - TR functions activated?
	bra		gaslist_gastitle2			;       NO  - continue with gas type
	lfsr	FSR1,opt_transmitter_id_1	;       YES - load base address of transmitter ID table
	movf	gaslist_gas,W				;           - (0-4 for OC/Bailout, 5-9 for Diluents)
	rlncf	WREG,W						;           - index x2 because IDs are 2 byte
	tstfsz	PLUSW1						;           - transmitter ID low byte <> 0 ?
	bsf		win_invert					;             YES - flag transmitter paired by inverting output
	incf	WREG,W						;           - increment index
	tstfsz	PLUSW1						;           - transmitter ID high byte <> 0 ?
	bsf		win_invert					;             YES - flag transmitter paired by inverting output
 ENDIF

gaslist_gastitle2:
	rcall	gaslist_strcat_gas_type		; print "*" for first gas/dil, "=" for a deco gas or " " else
gaslist_gastitle3:
	call	TFT_standard_color
	btfsc	divemode					; in dive mode?
	rcall	gaslist_strcat_gas_better	; YES - check if this is a "better gas"
	lfsr	FSR1,opt_gas_type			; load base address of gas types
	movf	gaslist_gas,W				; load index into WREG (0-4 for gases, 5-9 for diluents)
	movf	PLUSW1,W					; read gas/dil type into WREG
	bnz		gaslist_gastitle4			; type = disabled? NO  - keep color
	call	TFT_disabled_color			;                  YES - switch color to disabled
	bra		gaslist_gastitle5			;                      - skip ppO2 check for disabled gases
gaslist_gastitle4:
	btfss	divemode					; in dive mode?
	bra		gaslist_gastitle5			; NO  - no ppO2 check if not in dive mode
	lfsr	FSR1,opt_gas_O2_ratio		; YES - load base address of opt_gas_O2_ratio
	movf	gaslist_gas,W				;     - load index into WREG (0-4 for gases, 5-9 for diluents)
	movff	PLUSW1,hi					;     - read O2 ratio into hi
	call	TFT_color_code_gaslist		;     - set color according to ppO2 limits
gaslist_gastitle5:
	movf	gaslist_gas,W				; copy gas/dil index to WREG (0-9)
	rcall	gaslist_strcat_gas_WREG		; print gas composition
	btfss	divemode					; in dive mode?
	bra		gaslist_gastitle6			; NO  - continue printing a space
	rcall	gaslist_strcat_gas_type		; YES - print "*" for first gas/dil, "=" for a deco gas, or a space else
	bra		gaslist_gastitle7			;     - continue with change depth
gaslist_gastitle6:
	PUTC	" "							; print a space
gaslist_gastitle7:
	lfsr	FSR1,opt_gas_change			; load base address of change depths
	movf	gaslist_gas,W				; load gas/dil index into WREG (0-9)
	movff	PLUSW1,lo					; read change depth into lo
gaslist_strcat_depth:					; entry point for general printing of depths with value in meters in lo
	TSTOSS	opt_units					; check depth units
	bra		gaslist_strcat_depth_metric	; 0 - use Meters
gaslist_strcat_depth_imperial:			; 1 - use Feet
	movf	lo,W
	mullw	.100						; convert meters to mbar
	movff	PRODL,lo
	movff	PRODH,hi
	call	convert_mbar_to_feet		; convert value in lo:hi from mbar to feet
	output_16_3							; limit to 999 and display only 0-999
	STRCAT_TEXT tFeets					; append "ft"	REMARK: still one char to long for space available in dive mode menu!
	return
gaslist_strcat_depth_metric:
;	PUTC	" "							; print a space
;	output_99
	output_8
	STRCAT_TEXT tMeters					; "m"
	return


; check for better gas
;
gaslist_strcat_gas_better:				; color-code output if this is the best gas/diluent
	btfss	better_gas_hint				; shall better gas hints be given?
	return								; NO - return
	movf	best_gas_number,W			; get best gas number into WREG
 IFDEF _ccr_pscr
	btfsc	is_diluent_menu				; setting up diluents?
	movf	best_dil_number,W			; YES - overwrite with best diluent number
 ENDIF
	tstfsz	WREG						; is a best gas/dil available?
	bra		gaslist_strcat_gas_better1	; YES - proceed
	return								; NO  - return
gaslist_strcat_gas_better1:
	decf	WREG,W						; (1-5) -> (0-4)
	btfsc	is_diluent_menu				; setting up diluents?
	addlw	.5							; YES - add offset between gases and diluents (0-4) -> (5-9)
	cpfseq	gaslist_gas					; compare with given gas/dil (0-4 for OC bailout gases, 5-9 for diluents)
	return								; not equal - return
	bsf		win_invert					;     equal - invert
	movlw	color_green					;           - select green color (gas is something "good")
	goto	TFT_set_color				;           - activate color and return


gaslist_strcat_gas_type:
	lfsr	FSR1,opt_gas_type			; load base address of gas types
	movf	gaslist_gas,W				; load index to WREG (0-4 for gases, 5-9 for diluents)
	decf	PLUSW1,W					; get and decrement gas type (-1 for disabled,  0 for first,  1 for work/normal, 2 for deco)
	bnz		gaslist_strcat_gas_type_1	; type = first? NO  - continue with checking for work and deco gas
	PUTC	"*"							;               YES - print "*" for first
	return								;                   - done
gaslist_strcat_gas_type_1:
	decf	WREG,W						; decrement gas type (-2 for disabled, -1 for first,  0 for work/normal, 1 for deco)
	bnz		gaslist_strcat_gas_type_2	; type = work? NO  - continue with checking for deco gas
	PUTC	"\xb8"						;              YES - print down-arrow for a work gas
	return								;                  - done
gaslist_strcat_gas_type_2:
	decf	WREG,W						; decrement gas type (-3 for disabled, -2 for first, -1 for work/normal, 0 for deco)
	bnz		gaslist_strcat_gas_type_3	; type = deco? NO  - neither first nor deco
	PUTC	"="							;              YES - print "=" for a deco gas
	return								;                   - done
gaslist_strcat_gas_type_3:
	PUTC	" "							; neither first nor deco, print a space
	return


;----------------------------------------------------------------------------
; Housekeeping for the gas/dil settings, e.g. making sure there is one FIRST only
;
; Input:  gaslist_gas  last edited gas/dil (0-9)

	global	gaslist_cleanup_list
gaslist_cleanup_list:
	lfsr	FSR1,opt_gas_type			; load base address of opt_gas_type
 IFDEF _ccr_pscr
	movlw	.5							; offset between gases and diluents
	btfsc	is_diluent_menu				; setting up diluents?
	subwf	gaslist_gas,F				; YES - subtract offset from gaslist_gas: (5-9) -> (0-4)
 ENDIF
gaslist_cleanup_list0:
	bcf		ignore_last_edited_gas
gaslist_cleanup_list1:
	clrf	lo							; counter for number of "firsts" found
	movlw	.5							; initialize hi as loop counter for checking 5 gases/diluents
	movwf	hi
gaslist_cleanup_list2:					; loop body
	decf	hi,W						; WREG = current gas/dil (0-4)
 IFDEF _ccr_pscr
	btfsc	is_diluent_menu				; setting up diluents?
	addlw	.5							; YES - add offset from gases to diluents -> (5-9)
 ENDIF
	movff	PLUSW1,WREG					; read type into WREG
	decfsz	WREG						; is type = first (ex type code 1)?
	bra		gaslist_cleanup_list3		; NO  - done with this gas/dil
	incf	lo,F						; YES - increment number of "firsts" found
	btfss	ignore_last_edited_gas		;     - shall we ignore the last edited gas/dil?
	bra		gaslist_cleanup_list2b		;       NO  - continue remembering the "last first" gas/dil (do a shortcut)
	decf	hi,W						;       YES - get the current gas/dil as (0-4)
	cpfseq	gaslist_gas					;           - is this the last edited gas/dil?
gaslist_cleanup_list2b:
	movff	hi,up						;             (NO) - remember the last "first gas" found
gaslist_cleanup_list3:
	decfsz	hi,F						; decrement loop counter, did loop counter became 0?
	bra		gaslist_cleanup_list2		; NO  - loop
	tstfsz	lo							; YES - any first gas/dil at all?
	bra		gaslist_cleanup_list4		;       YES - at least one first gas/dil existing
 IFDEF _ccr_pscr
	btfsc	is_diluent_menu				;       NO  - setting up diluents?
	lfsr	FSR1,opt_dil_type			;             YES - load base address of opt_gas_type
 ENDIF
	movlw	.1							;           - load coding for first gas
	movwf	INDF1						;           - make gas/dil 1 the first gas
	bsf		option_repaired				;           - flag that an option was repaired
	return								;           - done
gaslist_cleanup_list4:
	movlw	.1							; total number of Firsts that should exist is 1
	cpfsgt	lo							; more then one "first gas" found?
	return								; NO  - done
	decf	up,W						; YES - WREG = last found "first gas" - 1 (0-4)
	cpfseq	gaslist_gas					;     - is this the last edited gas/dil?
	bra		gaslist_cleanup_list4b		;       NO  - disable it
	bsf		ignore_last_edited_gas		;       YES - do not disable last edited gas, search again but ignore the last edited gas
	bra		gaslist_cleanup_list1		;           - loop until only one "first" is left over
gaslist_cleanup_list4b:
 IFDEF _ccr_pscr
	btfsc	is_diluent_menu				; setting up diluents?
	addlw	.5							; YES - adjust offset
 ENDIF
	clrf	PLUSW1						; disable gas
	bsf		option_repaired				; flag that an option was repaired
	bra		gaslist_cleanup_list0		; redo from start until only one "first" is left over
	return


;----------------------------------------------------------------------------
; Tank Settings
;
; Input: char_I_gas_avail_size   size of the tank in liters
;        char_I_gas_avail_pres   available pressure in multiples of 10 bar

	global	gaslist_tank_size_pres
gaslist_tank_size_pres:					; dynamic title: xx l, xx0 bar
	lfsr	FSR1,char_I_gas_avail_size	; load base address of char_I_gas_avail_size
	movf	gaslist_gas,W				; load index (0-9)
	movff	PLUSW1,lo					; read char_I_gas_avail_size[WREG] into lo
	lfsr	FSR1,char_I_gas_avail_pres	; load base address of char_I_gas_avail_pres
	movff	PLUSW1,hi					; read char_I_gas_avail_pres[WREG] into hi
	STRCAT	"     "						; print 5 leading spaces for alignment
	output_8							; print tank size
	STRCAT_TEXT tLiter					; print unit (" l")
	movff	hi,lo						; copy fill pressure into lo
	output_8							; print fill pressure (it is stored in multiples of 10 bar)
	STRCAT_TEXT tbar10					; print unit ("0 bar")
	return


	global	gaslist_tank_size
gaslist_tank_size:						; adjust char_I_gas_avail_size between min_tank_size and max_tank_size
	lfsr	FSR1,char_I_gas_avail_size	; load base address of char_I_gas_avail_size
	movf	gaslist_gas,W				; load index (0-9)
	movff	PLUSW1,lo					; read char_I_gas_avail_size[WREG] into lo
	incf	lo,F						; increment tank size by 1 liter
	movlw	max_tank_size				; load max. allowed value into WREG
	cpfsgt	lo							; tank size <= max value?
	bra		gaslist_tank_size_1			; YES - new value can be used
	movlw	min_tank_size				; NO  - wrap-around to min value
	movwf	lo							;     - and write to lo
gaslist_tank_size_1:
	movf	gaslist_gas,W				; re-load index
	movff	lo,PLUSW1					; write back tank size to char_I_gas_avail_size[WREG]
	return


	global	gaslist_tank_pres
gaslist_tank_pres:						; adjust char_I_gas_avail_pres between 5(0) and 29(0) bar
	lfsr	FSR1,char_I_gas_avail_pres	; load base address of char_I_gas_avail_pres
	movf	gaslist_gas,W				; load index (0-9)
	movff	PLUSW1,lo					; read char_I_gas_avail_pres[WREG] into lo
	incf	lo,F						; increment fill press by by 1(0) bar
	movlw	max_fill_press				; load max. allowed value into WREG
	cpfsgt	lo							; press <= max value?
	bra		gaslist_tank_pres_1			; YES - new value can be used
	movlw	min_fill_press				; NO  - wrap-around to min value
	movwf	lo							;     - and write to lo
gaslist_tank_pres_1:
	movf	gaslist_gas,W				; re-load index
	movff	lo,PLUSW1					; write back tank size to char_I_gas_avail_pres[WREG]
	return


;=============================================================================

 IFDEF _rx_functions

; Transmitter functions - ID
;
	global	gaslist_tank_id_pres
gaslist_tank_id_pres:					; dynamic title: shows ID and pressure from transmitter with ID opt_transmitter_id[gaslist_gas]
										;                When changing layout, adapt output position TFT_menu_tank_pres!
	STRCAT	"  ID: "					; print header
	; get ID							;
	lfsr	FSR1,opt_transmitter_id_1	; load base address of opt_transmitter_id
	movf	gaslist_gas,W				; load index (0-9)
	rlncf	WREG,W						; multiply by 2 because IDs are 2 byte in size
	movff	PLUSW1,lo					; copy opt_transmitter_id+0[gaslist_gas] to lo
	incf	WREG,W						; increment index
	movff	PLUSW1,hi					; copy opt_transmitter_id+1[gaslist_gas] to hi
	; check if a transmitter is paired to this tank
	tstfsz	hi							; high byte of ID <> 0 ?
	bra		gaslist_tank_id_pres_1		; YES - a transmitter is paired to the tank
	tstfsz	lo							; low  byte of ID <> 0 ?
	bra		gaslist_tank_id_pres_1		; YES - a transmitter is paired to the tank
	STRCAT	"----"						; NO  - no transmitter paired
	bcf		imprint_xmitter_pres		;     - stop imprinting of transmitter pressure data
	return								;     - done
gaslist_tank_id_pres_1:					; YES - show ID
	movf	hi,W						;     - copy high byte of ID to WREG
	output_hex							;     - print it
	movf	lo,W						;     - copy low  byte of ID to WREG
	output_hex							;     - print it
	bsf		imprint_xmitter_pres		;     - start imprinting of transmitter pressure data
	return								;     - done


; Transmitter functions - Pairing
;
	global	gaslist_tank_pairing
gaslist_tank_pairing:
	incf	pairing_slot,F				; goto next RX data slot
	btfsc	pairing_slot,3				; slot = 8?
	bra		gaslist_tank_pairing_none	; YES - offer unpairing
	movf	pairing_slot,W				; NO  - copy slot to WREG
	call	get_transmitter_id_by_slot	; WREG = slot (0-7) -> hi:lo = transmitter ID
	tstfsz	hi							; transmitter found (probe on high byte)?
	bra		gaslist_tank_pairing_common	; YES - select this transmitter
	tstfsz	hi							; transmitter found (probe on low byte)?
	bra		gaslist_tank_pairing_common	; YES - select this transmitter
	bra		gaslist_tank_pairing		; NO  - try next slot
gaslist_tank_pairing_common:
	lfsr	FSR1,opt_transmitter_id_1	; load base address of opt_transmitter_id
	movf	gaslist_gas,W				; load index into WREG (0-9)
	rlncf	WREG,W						; multiply by 2 because IDs are 2 byte in size
	movff	lo,PLUSW1					; copy lo to opt_transmitter_id+0[gaslist_gas]
	incf	WREG,W						; increment index
	movff	hi,PLUSW1					; copy hi to opt_transmitter_id+1[gaslist_gas]
	return								; done
gaslist_tank_pairing_none:
	setf	pairing_slot				; prime slot number with 255 aka -1
	clrf	hi							; adjust "no transmitter" ID
	clrf	lo							; adjust "no transmitter" ID
	bra		gaslist_tank_pairing_common	; continue with common part

 ENDIF

;=============================================================================

;----------------------------------------------------------------------------
; Helper Functions for Menu Operations


; Increment O2 ratio
;
	global	gaslist_pO2
gaslist_pO2:
	movf	gaslist_gas,W				; load index (0-9)
	lfsr	FSR1,opt_gas_He_ratio		; load base address of opt_gas_He_ratio
	movff	PLUSW1,hi					; read He ratio into hi
	lfsr	FSR1,opt_gas_O2_ratio		; load base address of opt_gas_O2_ratio
	movff	PLUSW1,lo					; read O2 ratio into lo

	incf	lo,F						; O2++
	movf	hi,W						; get He ratio into WREG
	addwf	lo,W						; add O2 ratio to   WREG
	movwf	up							; move sum He + O2 to up
	movlw	.101						;
	cpfslt	up							; O2 + He < 101?
	decf	lo,F						; O2-- (revoke ++)
	movf	gaslist_gas,W				; re-load index
	movff	lo,PLUSW1					; write back O2 ratio to opt_gas_O2_ratio[WREG]
	return


; Decrement O2 ratio
;
	global	gaslist_mO2
gaslist_mO2:
	movf	gaslist_gas,W				; load index (0-9)
	lfsr	FSR1,opt_gas_O2_ratio		; load base address of opt_gas_O2_ratio
	movff	PLUSW1,lo					; read O2 ratio into lo

	decf	lo,F						; O2--
	movlw	gaslist_min_o2				; get minimum allowed O2 ratio
	cpfslt	lo							; current O2 ratio below allowed minimum?
	bra		gaslist_mO2_1				; NO
	movwf	lo							; YES - copy minimum O2 ratio to lo
gaslist_mO2_1:
	movf	gaslist_gas,W				; re-load index
	movff	lo,PLUSW1					; write back O2 ratio to opt_gas_O2_ratio[WREG]
	return

;=============================================================================

 IFDEF _helium

; Increment He ratio
;
	global	gaslist_pHe
gaslist_pHe:
	movf	gaslist_gas,W				; load index (0-9)
	lfsr	FSR1,opt_gas_O2_ratio		; load base address of opt_gas_O2_ratio
	movff	PLUSW1,lo					; read O2 ratio into lo
	lfsr	FSR1,opt_gas_He_ratio		; load base address of opt_gas_He_ratio
	movff	PLUSW1,hi					; read He ratio into hi

	incf	hi,F						; He++
	movf	hi,W						; get He ratio into WREG
	addwf	lo,W						; add O2 ratio to WREG
	movwf	up							; move sum He + O2 to up
	movlw	.101						;
	cpfslt	up							; O2 + He < 101?
	decf	hi,F						; He-- (revoke ++)
	movf	gaslist_gas,W				; re-load index
	movff	hi,PLUSW1					; write back He ratio to opt_gas_He_ratio[WREG]
	return

; Decrement He ratio
;
	global	gaslist_mHe
gaslist_mHe:
	movf	gaslist_gas,W				; load index (0-9)
	lfsr	FSR1,opt_gas_He_ratio		; load base address of opt_gas_He_ratio
	movff	PLUSW1,hi					; read He ratio into hi

	decf	hi,F						; He--
	bnn		gaslist_mHe_1				; He ratio negative?
	clrf	hi							; YES - set He ratio to 0
gaslist_mHe_1:
	movf	gaslist_gas,W				; re-load index
	movff	hi,PLUSW1					; write back He ratio to opt_gas_He_ratio[WREG]
	return

 ENDIF	; _helium

;=============================================================================

; Increment switch depth
;
	global	gaslist_pDepth
gaslist_pDepth:
	lfsr	FSR1,opt_gas_change			; load base address of opt_gas_change
	movf	gaslist_gas,W				; load index (0-4)
	movff	PLUSW1,lo					; read switch depth into lo
	incf	lo,F						; increment switch depth
	movlw	gaslist_max_change_depth	; get max change depth
	cpfsgt	lo							; above max change depth?
	bra		gaslist_pDepth_1			; NO
	movwf	lo							; YES - revert to max change depth
gaslist_pDepth_1:
	movf	gaslist_gas,W				; re-load index
	movff	lo,PLUSW1					; write back switch depth
	return


; Decrement switch depth
;
	global	gaslist_mDepth
gaslist_mDepth:
	lfsr	FSR1,opt_gas_change			; load base address of opt_gas_change
	movf	gaslist_gas,W				; load index (0-4)
	movff	PLUSW1,lo					; read switch depth into lo
	decf	lo,F						; decrement switch depth
	btfsc	STATUS,N					; did depth became negative?
	clrf	lo							; YES - reset to zero
	movff	lo,PLUSW1					; write back switch depth
	return

;=============================================================================

 IFDEF _ccr_pscr

; Increment setpoint
;
	global	gaslist_spplus
gaslist_spplus:
	movf	gaslist_gas,W
	lfsr	FSR1,opt_setpoint_cbar
	movff	PLUSW1,lo					; read setpoint
	movlw	gaslist_sp_stepsize
	addwf	lo,F
	movlw	gaslist_sp_max
	cpfsgt	lo
	bra		gaslist_spplus2
	movlw	gaslist_sp_min
	movwf	lo
gaslist_spplus2:
	movf	gaslist_gas,W
	movff	lo,PLUSW1					; write back setpoint
	return


; Increment setpoint switch depth
;
	global	gaslist_spdepthplus
gaslist_spdepthplus:
	movf	gaslist_gas,W				; get setpoint number (0-4)
	bz		gaslist_spdepthplus2		; setpoint number = 0? YES - force depth to always be 0m
	lfsr	FSR1,opt_setpoint_change	; load base address of opt_setpoint_change
	movff	PLUSW1,lo					; read setpoint depth into lo
	incf	lo,F						; increment depth
	movlw	gaslist_max_change_depth	; get max. depth
	cpfsgt	lo							; switch depth > max. depth?
	bra		gaslist_spdepthplus_1		; NO
	movwf	lo							; YES - copy to lo
gaslist_spdepthplus_1:
	movf	gaslist_gas,W				; re-load index
	movff	lo,PLUSW1					; write back setpoint depth
	return


; Decrement set point switch depth
;
	global	gaslist_spdepthminus
gaslist_spdepthminus:
	movf	gaslist_gas,W				; get setpoint number (0-4)
	bz		gaslist_spdepthminus2		; setpoint number = 0? YES - force depth to always be 0m
	lfsr	FSR1,opt_setpoint_change	; load base address of opt_setpoint_change
	movff	PLUSW1,lo					; read setpoint depth into lo
	decf	lo,F						; decrement switch depth
	btfsc	STATUS,N					; did depth became negative?
	clrf	lo							; YES - reset to zero
	movff	lo,PLUSW1					; write back setpoint depth
	return


; helper for increment/decrement setpoint switch depth
;
gaslist_spdepthplus2:
gaslist_spdepthminus2:
	movlw	.0
	movff	WREG,opt_setpoint_change+0; hard reset to 0m
	return

 ENDIF	; _ccr_pscr

;=============================================================================


;----------------------------------------------------------------------------
; Compute MOD from O2 ratio and char_I_ppO2_max_work / char_I_ppO2_max_deco
; Compute MOD from O2 ratio and char_I_ppO2_max_deco
;
; Input:  gaslist_gas                   = current gas index.
;         opt_gas_O2_ratio[gaslist_gas] = current O2 ratio
; Output: WREG                          = MOD [m]
;
gaslist_calc_mod:
	lfsr	FSR1,opt_gas_type			; load base address of opt_gas_type
	movf	gaslist_gas,W				; load index (0...9)
	movff	PLUSW1,xA+0					; read gas/dil type     into xA+0 (used as temp here)
	movff	char_I_ppO2_max_work,xB+1	; get max ppO2 for deco into xB+1 (used as temp here)
	movlw	.3							; type code for deco gases
	cpfslt	xA+0						; is it a deco gas?
gaslist_calc_mod_deco:
	movff	char_I_ppO2_max_deco,xB+1	; YES - overwrite/get ppO2 max with/for work
	lfsr	FSR1,opt_gas_O2_ratio		; load base address of opt_gas_O2_ratio
	movf	gaslist_gas,W				; load index (0...9)
	movff	PLUSW1,xB+0					; read O2 ratio into xB+0
	movf	xB+1,W						; copy ppO2 max into WREG
	clrf	xB+1						; clear xB+1 for div16x16 operation
	mullw	.10							; multiply ppO2 max value with 10
	MOVII	PROD,xA						; copy result to xA
	call	div16x16					; xC = xA / xB with xA as remainder
	movf	xC+0,W						; copy low  byte of the result to WREG
	addlw	-.10						; subtract 10 cbar
	return								; return with final result [in meters] in WREG

;----------------------------------------------------------------------------

; print ppO2 as x.xx for gas/diluent in gaslist_gas (0-9)
;
	global	gaslist_ppo2
gaslist_ppo2:
	STRCAT_TEXT tppO2					; ppO2:
	lfsr	FSR1,opt_gas_change			; load base address of opt_gas_change
	movf	gaslist_gas,W				; load index (0-9)
	movf	PLUSW1,W					; read change depth into WREG
	mullw	.10							; PROD = depth in mbar/10 (100 = 1.00 bar)
	ADDLI	.100,PROD					; add 1 bar
	MOVII	PROD,xA						; copy result to xA
	lfsr	FSR1,opt_gas_O2_ratio		; load base address of opt_gas_O2_ratio
	movf	gaslist_gas,W				; load index (0-9)
	movff	PLUSW1,xB+0					; read O2 ratio into xB+0
	clrf	xB+1						; clear xB+1
	call	mult16x16					; calculate char_I_O2_ratio * (p_amb/10)
	MOVII	xC,xA						; copy result to xA
	movlw	d'100'						; load 100 to xB
	movwf	xB+0
	clrf	xB+1
	call	div16x16					; xC = xA / xB = (char_I_O2_ratio * p_amb/10)/100
	; check for very high ppO2
	tstfsz	xC+2						; xC+2 remains from mult16x16, xC+2 > 0 (-> ppO2 is > 6.55 bar) ?
	bra		gaslist_ppo2_1				; YES - display a fixed max value
	MOVII	xC,mpr						; copy result to hi:lo
	bcf		ignore_digit4
	bsf		leftbind
	output_16dp d'3'					; print ppO2 as x.xx
	STRCAT_TEXT tbar					; print "bar"
	return
gaslist_ppo2_1:
	STRCAT	">6.6"
	return


; print MOD and END for gas in gaslist_gas (0-9)
;
	global	gaslist_MOD_END
gaslist_MOD_END:
	STRCAT_TEXT tMOD					; print "MOD:"
	rcall	gaslist_calc_mod			; compute MOD into WREG
	movwf	lo							; copy result to lo
	call	gaslist_strcat_depth		; print depth in meters or feet as configured
	PUTC	"/"							; print "/"
	STRCAT_TEXT tEND					; print "END:"
	rcall	gaslist_calc_mod			; compute MOD into WREG
	addlw	.10							; compute MOD = MOD + 10m
	movwf	xB+0
	clrf	xB+1
	movlw	d'100'
	movwf	xA+0
	lfsr	FSR1,opt_gas_He_ratio		; load base address of opt_gas_He_ratio
	movf	gaslist_gas,W				; load index (0...9)
	movf	PLUSW1,W					; read He ration into WREG
	subwf	xA+0,F						; xA+0 = 100 - He ratio in %
	clrf	xA+1
	call	mult16x16					; xA*xB=xC
	MOVII	xC,xA
	movlw	d'100'
	movwf	xB+0
	clrf	xB+1
	call	div16x16					; xC = xA / xB with xA as remainder
	;									; xC:2 = ((MOD+10) * 100 - HE Value in %) / 100
	movlw	d'10'						; subtract 10 m
	subwf	xC+0,F						; ...
	movff	xC+0,lo						; copy result to lo
	bra		gaslist_strcat_depth		; print depth in meters or feet as configured and return


; print change depth of gas in gaslist_gas (0-9), use warning color if > MOD
;
	global	gaslist_reset_mod_title
gaslist_reset_mod_title:
	STRCAT_TEXT tDepthReset				; print "Reset to MOD:"
	PUTC	" "							; add a space char
	lfsr	FSR1,opt_gas_change			; load base address of opt_gas_change
	movf	gaslist_gas,W				; load index (0-9)
	movff	PLUSW1,hi					; read change depth into hi
	rcall	gaslist_calc_mod			; compute MOD for ppO2 max work/deco dependent on gas type into WREG
	movwf	lo							; copy (true) MOD   to lo
	movf	hi,W						; copy change depth to WREG
	cpfslt	lo							; change depth > MOD ?
	bra		gaslist_strcat_depth		; NO  - print MOD from value in lo
	call	TFT_attention_color			; YES - use attention color
	rcall	gaslist_calc_mod_deco		;     - compute MOD for ppO2 max deco into WREG
	movwf	up							;     - copy result to up
	movf	hi,W						;     - copy change depth to WREG again
	cpfslt	up							;     - change depth > MOD deco ?
	bra		gaslist_strcat_depth		;       NO  - print MOD from value in lo, keeping attention color
	call	TFT_warning_color			;       YES - switch to warning color
	bra		gaslist_strcat_depth		;           - print MOD from value in lo


; set change depth of gas in gaslist_gas (0-9) to its MOD
;
	global	gaslist_reset_mod
gaslist_reset_mod:
	rcall	gaslist_calc_mod			; compute MOD into WREG
	movwf	lo							; copy result to lo
	lfsr	FSR1,opt_gas_change			; load base address of opt_gas_change
	movf	gaslist_gas,W				; load index (0-9)
	movff	lo,PLUSW1					; write back new change depth
	return

;----------------------------------------------------------------------------
; put "Nxlo", "Txlo/hi", "Air" or "O2" into postinc2
;
; Includes capability to show trimix gases to be able to properly decode data
; from logbook in case trimix dives are stored on an OSTC running the sport FW.

	global	gaslist_show_mix
gaslist_show_mix:
	tstfsz	hi							; He=0?
	bra		gaslist_show_mix5			; NO - show a TX
	movlw	.21
	cpfseq	lo							; Air?
	bra		gaslist_show_mix2			; NO
	STRCAT_TEXT tSelectAir				; YES - show "Air"
	bra		gaslist_show_mix4b
gaslist_show_mix2:
	movlw	.100
	cpfseq	lo							; O2?
	bra		gaslist_show_mix3			; NO
	STRCAT_TEXT tSelectO2				; YES - show "O2"
	bra		gaslist_show_mix4b
gaslist_show_mix3:
	movlw	.21
	cpfslt	lo							; < Nx21?
	bra		gaslist_show_mix4			; NO
	STRCAT_TEXT tGasErr					; YES - show "Err"
	output_99							; O2 ratio is still in "lo"
	bra		gaslist_show_mix4c
gaslist_show_mix4:
	STRCAT_TEXT tSelectNx				; show "Nx"
	output_99							; O2 ratio is still in "lo"
gaslist_show_mix4b:
	STRCAT	" "
gaslist_show_mix4c:
	btfsc	divemode					; in dive mode?
	return								; YES
	STRCAT	"  "
	return
gaslist_show_mix5:
	btfsc	divemode
	bra		gaslist_show_mix6
	STRCAT_TEXT tSelectTx				; show "Tx"
gaslist_show_mix6:
	output_99							; O2 ratio is still in "lo"
	PUTC	"/"
	movff	hi,lo
	output_99							; He ratio
	return

;-----------------------------------------------------------------------------

	END
