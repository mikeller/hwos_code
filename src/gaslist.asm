;=============================================================================
;
;   File gaslist.asm                        * combined next generation V3.09.5
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
#include "colorschemes.inc"


;=============================================================================
gaslist1	CODE
;=============================================================================

;-----------------------------------------------------------------------------
; Append Mix ("Nxlo", "Txlo/hi", "Air" or "O2") to current String
;
; Input:  PRODL : gas/dil number (0..4)
;         flag 'is_diluent_menu' for gas/dil selection
;
	global	gaslist_strcat_mix_PRODL
gaslist_strcat_mix_PRODL:
	movff	PRODL,gaslist_gas			; get current menu item (0-4)
	movlw	.5							; offset between gases and diluents
	btfsc	is_diluent_menu				; setting up diluents?
	addwf	gaslist_gas,F				; YES - add the offset
	movf	gaslist_gas,W				; copy to WREG
	;bra	gaslist_strcat_mix_WREG		; continue


;-----------------------------------------------------------------------------
; Append Mix ("Nxlo", "Txlo/hi", "Air" or "O2") to current String
;
; Input:  WREG : gas/dil number (0..9)
;
	global	gaslist_strcat_mix_WREG
gaslist_strcat_mix_WREG:				; entry point with gas/dil in WREG (0-9)
	lfsr	FSR1,opt_gas_O2_ratio		; load base address of opt_gas_O2_ratio
	movff	PLUSW1,lo					; read O2 ratio
	lfsr	FSR1,opt_gas_He_ratio		; load base address of opt_gas_He_ratio
	movff	PLUSW1,hi					; read He ratio
	;bra	gaslist_strcat_mix			; put "Nxlo", "Txlo/hi", "Air" or "O2" into Postinc2, and RETURN


;----------------------------------------------------------------------------
; Append Mix ("Nxlo", "Txlo/hi", "Air" or "O2") to current String
;
; Input: lo  O2%
;        hi  He%
;
; Includes capability to show trimix gases to be able to properly decode data
; from logbook in case trimix dives are stored on an OSTC running the sport FW
;
	global	gaslist_strcat_mix
gaslist_strcat_mix:
	tstfsz	hi							; He=0?
	bra		gaslist_strcat_mix_5		; NO - print a TX

gaslist_strcat_mix_1:
	movlw	.21							; air is 21% O2
	cpfseq	lo							; Air ?
	bra		gaslist_strcat_mix_2		; NO  - try next
	STRCAT_TEXT tSelectAir				; YES - print "Air"
	bra		gaslist_strcat_mix_4b		;     - continue

gaslist_strcat_mix_2:
	movlw	.100						; O2 is 100% O2
	cpfseq	lo							; O2 ?
	bra		gaslist_strcat_mix_3		; NO  - try next
	STRCAT_TEXT tSelectO2				; YES - print "O2"
	bra		gaslist_strcat_mix_4b		;     - continue

gaslist_strcat_mix_3:
	movlw	.21							; strange mix has no He and O2 < 21%
	cpfslt	lo							; < Nx21 ?
	bra		gaslist_strcat_mix_4		; NO  - try next
	STRCAT_TEXT tGasErr					; YES - print "Err"
	output_99							;     - print O2%
	bra		gaslist_strcat_mix_4c		;     - continue

gaslist_strcat_mix_4:
	STRCAT_TEXT tSelectNx				; print "Nx"
	output_99							; print O2%

gaslist_strcat_mix_4b:
	STRCAT	" "							; print a space

gaslist_strcat_mix_4c:
	btfsc	divemode					; in dive mode?
	return								; YES - done
	STRCAT	"  "						; NO  - add two spaces
	return								;     - done

gaslist_strcat_mix_5:
	btfsc	divemode					; in dive mode?
	bra		gaslist_strcat_mix_6		; YES - do short version
	STRCAT_TEXT tSelectTx				; NO  - print "Tx"

gaslist_strcat_mix_6:
	output_99							; print O2%
	PUTC	"/"							; print "/"
	movff	hi,lo						; move He% into lo
	output_99							; print He%
	return								; done


;----------------------------------------------------------------------------
; Append full Gas Description to current String
;
; Prints gas number, * if first, = if deco gas, gas composition and change depth,
; including fancy color-coding
;
; Input:  PRODL gas number (0..4)
;         flag 'is_diluent_menu' for gas/dil selection
;
; NOTE: used in the menu-tree for the MENU_CALLBACK entry
;
	global	gaslist_strcat_gas_PRODL
gaslist_strcat_gas_PRODL:
	movff	PRODL,gaslist_gas			; get current menu item (0-4)
	movlw	.5							; offset between gases and diluents
	btfsc	is_diluent_menu				; dealing with diluents?
	addwf	gaslist_gas,F				; YES - add the offset
	;bra	gaslist_strcat_gas			; continue with gaslist_strcat_gas function


;----------------------------------------------------------------------------
; Append full Gas Description to current String
;
; Print gas number, * if first, = if deco gas, gas composition and change depth,
; including fancy color-coding
;
; Input:  gaslist_gas gas/dil number (0..9)
;
; NOTE: used in the menu-tree for the MENU_CALLBACK entry
;
	global	gaslist_strcat_gas
gaslist_strcat_gas:
	btfsc	short_gas_descriptions		; shall use short versions of gaslist_strcat_gas_PRODL?
	bra		gaslist_gastitle_short		; YES - use short version
	incf	gaslist_gas,W				; NO  - (0-9) -> (1-10) into WREG
	movwf	lo							;     - copy gas index to lo
	movlw	.6							;     - diluents start with 6
	cpfslt	lo							;     - gas number < 6 ?
	bra		gaslist_gastitle_dil		;       NO  - it's a diluent
	;bra	gaslist_gastitle_gas		;       YES - it's a gas

gaslist_gastitle_gas:
	STRCAT_TEXT tGas					; it's a gas
	bra		gaslist_gastitle_gas_num	; continue

gaslist_gastitle_dil:
	STRCAT_TEXT tDil					; it's a diluent
	movlw	.5							; offset between gases and diluents
	subwf	lo,F						; subtract offset from diluent number (6-10) -> (1-5) again

gaslist_gastitle_gas_num:
	output_9							; print gas/dil number (1-5)
	PUTC	":"							; print ":"

gaslist_gastitle_short:
	btfsc	divemode					; in dive mode?
	bra		gaslist_gastitle_color_avail; YES - no "*" and "=" in front of gas composition, no highlighting for transmitters paired

 IFDEF _rx_functions
	btfss	tr_functions_activated		; TR functions activated?
	bra		gaslist_gastitle_type_1		; NO  - continue with gas type
	lfsr	FSR1,opt_transmitter_id_1	; YES - load base address of transmitter ID table
	movf	gaslist_gas,W				;     - (0-4 for gases, 5-9 for diluents)
	rlncf	WREG,W						;     - index x2 because IDs are 2 byte
	tstfsz	PLUSW1						;     - transmitter ID low byte <> 0 ?
	bsf		win_invert					;       YES - flag transmitter paired by inverting output
	incf	WREG,W						;     - increment index
	tstfsz	PLUSW1						;     - transmitter ID high byte <> 0 ?
	bsf		win_invert					;       YES - flag transmitter paired by inverting output
 ENDIF	; _rx_functions

gaslist_gastitle_type_1:
	rcall	gaslist_strcat_gas_type		; print type marking ("*", "=", "X", ...)

gaslist_gastitle_color_avail:
	FONT_COLOR_MEMO						; default to standard color
	btfsc	divemode					; in dive mode?
	rcall	gaslist_strcat_gas_better	; YES - check if this is a "better gas", if yes switch to green and inverted output
	lfsr	FSR1,opt_gas_type			; load base address of gas types
	movf	gaslist_gas,W				; load index into WREG (0-4 for gases, 5-9 for diluents)
	movf	PLUSW1,W					; read gas/dil type into WREG
	btfsc	WREG,gas_lost				; gas/dil lost?
	bra		gaslist_gastitle_not_avail	; YES - switch to disabled color and skip ppO2 check
	btfsc	WREG,gas_staged				; gas/dil staged?
	bra		gaslist_gastitle_not_avail	; YES - switch to disabled color and skip ppO2 check
	bnz		gaslist_gastitle_color_ppo2	; type not disabled -> color code by ppO2
	;bz		gaslist_gastitle_not_avail	; type     disabled -> switch to disabled color and skip ppO2 check

gaslist_gastitle_not_avail:
	FONT_COLOR_DISABLED					; switch to disabled color
	bra		gaslist_gastitle_mix		; skip ppO2 check for disabled gases

gaslist_gastitle_color_ppo2:
	btfss	divemode					; in dive mode?
	bra		gaslist_gastitle_mix		; NO  - no color-coding if not in dive mode
	btfss	color_code_gases			; YES - shall color-code the gases by ppO2 and current depth?
	bra		gaslist_gastitle_mix		;       NO  - skip color-coding
	lfsr	FSR1,opt_gas_O2_ratio		;       YES - load base address of opt_gas_O2_ratio
	movf	gaslist_gas,W				;           - load index into WREG (0-4 for gases, 5-9 for diluents)
	movff	PLUSW1,hi					;           - read O2 ratio into hi
	call	TFT_color_code_gaslist		;           - set color according to ppO2 limits

gaslist_gastitle_mix:
	movf	gaslist_gas,W				; copy gas/dil index to WREG (0-9)
	rcall	gaslist_strcat_mix_WREG		; print gas composition
	btfss	divemode					; in dive mode?
	bra		gaslist_gastitle_no_type	; NO  - print no type marking
	;bra	gaslist_gastitle_type_2		; YES - print    type marking

gaslist_gastitle_type_2:
	rcall	gaslist_strcat_gas_type		; print type marking ("*", "=", "X", ...)
	bra		gaslist_gastitle_depth		; continue with change depth

gaslist_gastitle_no_type:
	PUTC	" "							; print a space

gaslist_gastitle_depth:
	lfsr	FSR1,opt_gas_change			; load base address of change depths
	movf	gaslist_gas,W				; load gas/dil index into WREG (0-9)
	movff	PLUSW1,lo					; read change depth into lo
	;bra	gaslist_strcat_depth		; print depth and return


;-----------------------------------------------------------------------------
; Helper Function - print Depths in Meters or Feet
;
; input: lo  depth in meters
;
gaslist_strcat_depth: 
	TSTOSS	opt_units					; check depth units
	bra		gaslist_strcat_depth_meter	; 0 - use Meters
	;bra	gaslist_strcat_depth_feet	; 1 - use Feet

gaslist_strcat_depth_feet:
	call	convert_meter_to_feet		; convert value in lo from [m] to [feet]
	output_999							; print depth (0-999)
	STRCAT_TEXT tFeets					; append "ft"	REMARK: still one char to long for space available in dive mode menu!
	return								; done

gaslist_strcat_depth_meter:
	output_256							; print 0-256
	STRCAT_TEXT tMeters					; append "m"
	return								; done


;-----------------------------------------------------------------------------
; Helper Function - color-code Output if this is the best Gas/Diluent
;
gaslist_strcat_gas_better:
	btfss	better_gas_hint				; shall better gas cues be given?
	return								; NO  - return
	movf	best_gas_number,W			; YES - get best gas number into WREG
 IFDEF _ccr_pscr
	btfsc	is_diluent_menu				;     - setting up diluents?
	movf	best_dil_number,W			;       YES - replace with best diluent number
 ENDIF	; _ccr_pscr
	tstfsz	WREG						;     - is a best gas/dil available?
	bra		gaslist_strcat_gas_better1	;       YES - proceed
	return								;       NO  - done

gaslist_strcat_gas_better1:
	decf	WREG,W						; (1-5) -> (0-4)
	btfsc	is_diluent_menu				; setting up diluents?
	addlw	.5							; YES - add offset between gases and diluents (0-4) -> (5-9) to better gas number
	cpfseq	gaslist_gas					; is the current gas/dil the best one?
	return								; NO  - done
	bsf		win_invert					; YES - print invert
	FONT_COLOR color_green				;     - select green color (gas is something "good")
	return								;     - done


;-----------------------------------------------------------------------------
; Helper Function - print      "*"     for   first    Gas/Dil
;                         a down arrow for a Work     Gas/Dil
;                              "="     for a Deco     Gas
;                              " "     for a disabled Gas/Dil
;                              "X"     for a lost     Gas/Dil
;                              "S"     for a staged   Gas/Dil
;
gaslist_strcat_gas_type:
	lfsr	FSR1,opt_gas_type			; load base address of gas types
	movf	gaslist_gas,W				; load index to WREG (0-4 for gases, 5-9 for diluents)
	movf	PLUSW1,W					; get gas/dil type into WREG
	btfsc	WREG,gas_lost				; gas set as lost?
	bra		gaslist_strcat_gas_type_4	; YES - print lost marking
 IFDEF _cave_mode
	btfsc	WREG,gas_staged				; gas set as staged?
	bra		gaslist_strcat_gas_type_5	; YES - print staged marking
 ENDIF	; _cave_mode
	decf	WREG,W						; decrement gas type (-1 for disabled,  0 for first,  1 for work/normal, 2 for deco)
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
	return								;                  - done

gaslist_strcat_gas_type_3:
	PUTC	" "							; type = disabled, print a space
	return								; done

gaslist_strcat_gas_type_4:
	PUTC	"x"							; print lost marking
	return								; done

 IFDEF _cave_mode
gaslist_strcat_gas_type_5:
	PUTC	"S"							; print staged marking
	return								; done
 ENDIF	; _cave_mode


;----------------------------------------------------------------------------
; Helper Function:
; Compute MOD from O2 ratio and char_I_ppO2_max_work / char_I_ppO2_max_deco
; Compute MOD from O2 ratio and char_I_ppO2_max_deco
;
; Input:  gaslist_gas                   = current gas index
;         opt_gas_O2_ratio[gaslist_gas] = current O2 ratio
; Output: WREG                          = MOD [m]
;
	global gaslist_calc_mod
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
	movf	xB+1,W						; copy ppO2 [cbar] max into WREG
	clrf	xB+1						; clear xB+1 for div16x16 operation
	mullw	.10							; multiply ppO2 max value with 10
	MOVII	PROD,xA						; copy result to xA
	call	div16x16					; xC = xA / xB with xA as remainder
	movf	xC+0,W						; copy low byte of the result to WREG
	addlw	-.10						; subtract 10 m to remove the 1 bar surface pressure
	return								; return with final result [in meters] in WREG


;=============================================================================
gaslist2	CODE
;=============================================================================

;-----------------------------------------------------------------------------
; Clean up the Gas/Diluent Settings so that there is only one FIRST Gas/Diluent
;
; Input:  gaslist_gas  last edited gas/dil (0-9)
;
	global	gaslist_cleanup_list
gaslist_cleanup_list:
	lfsr	FSR1,opt_gas_type			; load base address of opt_gas_type

 IFDEF _ccr_pscr
	movlw	.5							; offset between gases and diluents
	btfsc	is_diluent_menu				; setting up diluents?
	subwf	gaslist_gas,F				; YES - subtract offset from gaslist_gas: (5-9) -> (0-4)
 ENDIF	; _ccr_pscr

gaslist_cleanup_list_loop_1:
	bcf		ignore_last_edited_gas		; allow the last edited gas/dil to be found as a "first"

gaslist_cleanup_list_loop_2:
	clrf	lo							; clear number of "first" gases found
	movlw	.5							; initialize hi as loop counter for checking 5 gases/diluents
	movwf	hi							; ...

gaslist_cleanup_list_loop_3:
	decf	hi,W						; WREG = current gas/dil to check (4..0)

 IFDEF _ccr_pscr
	btfsc	is_diluent_menu				; setting up diluents?
	addlw	.5							; YES - add offset from gases to diluents -> (9..5)
 ENDIF	; _ccr_pscr

	movff	PLUSW1,WREG					; read type into WREG
	decfsz	WREG						; type = first ?
	bra		gaslist_cleanup_1			; NO  - done with this gas/dil
	incf	lo,F						; YES - increment number of "firsts" found
	btfss	ignore_last_edited_gas		;     - shall the last edited gas/dil be skipped?
	bra		gaslist_cleanup_set_first	;       NO  - set the currently checked gas/dil as last "first" found
	decf	hi,W						;       YES - get the currently checked gas/dil (0..4)
	cpfseq	gaslist_gas					;           - is  the currently checked gas/dil == the last edited gas/dil ?
gaslist_cleanup_set_first:
	movff	hi,up						;             (NO) - set current gas/dil as the last "first" found (1..5)

gaslist_cleanup_1:
	decfsz	hi,F						; decrement loop counter, did loop counter became 0?
	bra		gaslist_cleanup_list_loop_3	; NO  - check next gas/dil
	tstfsz	lo							; YES - any first gas/dil at all?
	bra		gaslist_cleanup_list_2		;       YES - one or more "first" gas/dil found

 IFDEF _ccr_pscr
	btfsc	is_diluent_menu				;       NO  - setting up diluents?
	lfsr	FSR1,opt_dil_type			;             YES - load base address of opt_gas_type
 ENDIF	; _ccr_pscr

	movlw	.1							;           - load coding for first gas
	movwf	INDF1						;           - make gas/dil 1 the first gas
	bsf		option_changed				;           - flag that the EEPROM needs to be updated
	return								;           - done

gaslist_cleanup_list_2:
	movlw	.1							; total number of "first" gas/dil allowed is 1
	cpfsgt	lo							; more than one "first" found?
	return								; NO  - done
	decf	up,W						; YES - get last found "first" (0-4)
	cpfseq	gaslist_gas					;     - is  last found "first" == last edited gas/dil ?
	bra		gaslist_cleanup_disable		;       NO  - disable it
	bsf		ignore_last_edited_gas		;       YES - do not find the last edited gas/dil as "first" any more
	bra		gaslist_cleanup_list_loop_2	;           - loop until only one "first" is left over

gaslist_cleanup_disable:
 IFDEF _ccr_pscr
	btfsc	is_diluent_menu				; setting up diluents?
	addlw	.5							; YES - adjust offset
 ENDIF	; _ccr_pscr

	clrf	PLUSW1						; disable the gas/dil
	bsf		option_changed				; flag that the EEPROM needs to be updated
	bra		gaslist_cleanup_list_loop_1	; redo from start until only one "first" is left over


;=============================================================================
gaslist3	CODE
;=============================================================================

 IFDEF _ccr_pscr

;-----------------------------------------------------------------------------
; Main Menu Item - print Setpoint by 'PRODL' (dynamic Title)
;
	global	gaslist_strcat_setpoint_PRODL
gaslist_strcat_setpoint_PRODL:
	movff	PRODL,gaslist_gas			; get current menu item (0-4)
	;bra	gaslist_strcat_setpoint		; continue


;-----------------------------------------------------------------------------
; Main Menu Item - print Setpoint by 'gaslist_gas' (dynamic Title)
;
	global	gaslist_strcat_setpoint
gaslist_strcat_setpoint:
	btfsc	short_gas_descriptions		; shall use short version?
	bra		gaslist_strcat_setpoint2	; YES - use short version
	STRCAT_TEXT tSP						; "SP"
	incf	gaslist_gas,W				; (0-4) -> (1-5) into WREG
	movwf	lo							; copy to lo
	output_9							; print SP number (0-9)
	PUTC	":"							; ":"

gaslist_strcat_setpoint2:
	btfsc	divemode					; in dive mode?
	bra		gaslist_strcat_setpoint4	; YES - do not add the "*" in dive mode
	movf	gaslist_gas,W				; NO  - (0-4) into WREG
	bnz		gaslist_strcat_setpoint3	;     - SP index = 0 ?
	PUTC	"*"							;       YES - print *
	bra		gaslist_strcat_setpoint4	;     - continue with cbar value

gaslist_strcat_setpoint3:
	PUTC	" "							; print a space

gaslist_strcat_setpoint4:
	movf	gaslist_gas,W				; (0-4) into WREG
	lfsr	FSR1,opt_setpoint_cbar		; load base address of setpoint cbar values
	movf	PLUSW1,W					; read cbar value
	movwf	lo							; copy to lo
	bsf		decimal_digit2				; place a decimal point in front of digit 2
	output_256							; print as x.xx
	btfsc	divemode					; in dive mode?
	bra		gaslist_strcat_setpoint5	; YES - skip text in dive mode
	STRCAT_TEXT tbar					; NO  - print "bar"

gaslist_strcat_setpoint5:
	PUTC	" "							; print a space
	movf	gaslist_gas,W				; (0-4) into WREG
	lfsr	FSR1,opt_setpoint_change	; load base address of switch depths
	movff	PLUSW1,lo					; read switch depth into lo
	goto	gaslist_strcat_depth		; print depth (meters or ft)

 ENDIF	; _ccr_pscr


;=============================================================================
gaslist4	CODE
;=============================================================================

;----------------------------------------------------------------------------
; Main Menu Item - print ppO2 at Change Depth (dynamic Title)
;
	global	gaslist_ppo2
gaslist_ppo2:
	STRCAT_TEXT tppO2					; print "ppO2:"
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
	MOVLI	.100,xB						; load 100    to xB
	call	div16x16					; xC = xA / xB = (char_I_O2_ratio * p_amb/10)/100
	; check for very high ppO2
	tstfsz	xC+2						; xC+2 remains from mult16x16, xC+2 > 0 (-> ppO2 is > 6.55 bar) ?
	bra		gaslist_ppo2_2				; YES - display a fixed max value
	PUTC	" "							; NO  - print a space
	MOVII	xC,mpr						;     - copy result to hi:lo
	bsf		leftbind					;     - print left-aligned
	bsf		decimal_digit2				;     - place a decimal point in front of digit 2
	output_999							;     - print ppO2 (0.00-655.35)
gaslist_ppo2_1:
	STRCAT_TEXT tbar					;     - print "bar"
	return								;     - done

gaslist_ppo2_2:
	STRCAT	">6.55"						; print ">6.55"
	bra		gaslist_ppo2_1				; append unit and return


;-----------------------------------------------------------------------------
; Main Menu Item - print MOD and END for a Gas (dynamic Title)
;
	global	gaslist_MOD_END
gaslist_MOD_END:
	STRCAT_TEXT tMOD					; print "MOD:"
	call	gaslist_calc_mod			; compute MOD into WREG
	movwf	lo							; copy result to lo
	movwf	hi							; keep copy   in hi
	call	gaslist_strcat_depth		; print depth in meters or feet as configured
	PUTC	"/"							; print "/"
	STRCAT_TEXT tEND					; print "END:"
	movf	hi,W						; retrieve MOD
	addlw	.10							; compute MOD = MOD + 10m
	movwf	xB+0						; copy to xB
	clrf	xB+1						; ...
	MOVLI	.100,xA						; load 100 to xA
	lfsr	FSR1,opt_gas_He_ratio		; load base address of opt_gas_He_ratio
	movf	gaslist_gas,W				; load index (0...9)
	movf	PLUSW1,W					; read He ratio into WREG
	subwf	xA+0,F						; xA = 100 - He ratio in %
	call	mult16x16					; xC = xA * xB
	MOVII	xC,xA						; copy result to xA
	MOVLI	.100,xB						; load 100 to xB
	call	div16x16					; xC = xA / xB with xA as remainder
	;									; xC:2 = ((MOD+10) * 100 - HE Value in %) / 100
	movlw	d'10'						; subtract 10 m
	subwf	xC+0,F						; ...
	movff	xC+0,lo						; copy result to lo
	goto	gaslist_strcat_depth		; print depth and return


;-----------------------------------------------------------------------------
; Main Menu Item - print 'reset to MOD' (dynamic Title)
;
	global	gaslist_reset_mod_title
gaslist_reset_mod_title:
	STRCAT_TEXT tDepthReset				; print "Reset to MOD:"
	PUTC	" "							; add a space char
	lfsr	FSR1,opt_gas_change			; load base address of opt_gas_change
	movf	gaslist_gas,W				; load index (0-9)
	movff	PLUSW1,hi					; read change depth into hi
	call	gaslist_calc_mod			; compute MOD for ppO2 max work/deco dependent on gas type into WREG
	movwf	lo							; copy (true) MOD   to lo
	movf	hi,W						; copy change depth to WREG
	cpfslt	lo							; change depth > MOD ?
	bra		gaslist_reset_mod_title_exit; NO  - print MOD from value in lo
	FONT_COLOR_ATTENTION				; YES - use attention color
	call	gaslist_calc_mod_deco		;     - compute MOD for ppO2 max deco into WREG
	movwf	up							;     - copy result to up
	movf	hi,W						;     - copy change depth to WREG again
	cpfslt	up							;     - change depth > MOD deco ?
	bra		gaslist_reset_mod_title_exit;       NO  - print MOD from value in lo, keeping attention color
	FONT_COLOR_WARNING					;       YES - switch to warning color
	;bra	gaslist_reset_mod_title_exit;           - print MOD depth

gaslist_reset_mod_title_exit:
	goto	gaslist_strcat_depth		; print MOD depth and return

;-----------------------------------------------------------------------------

	END
