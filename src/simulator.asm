;=============================================================================
;
;   File simulator.asm                        combined next generation V3.04.3
;
;   Deco Calculator
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
; 2011-07-09 : [jDG] Creation...

#include "hwos.inc"					; Mandatory include
#include "convert.inc"				; output_*
#include "shared_definitions.h"		; Mailbox from/to p2_deco.c
#include "strings.inc"				; STRCPY,...
#include "tft.inc"					; WIN_LEFT,...
#include "start.inc"
#include "divemode.inc"
#include "sleepmode.inc"
#include "math.inc"
#include "eeprom_rs232.inc"
#include "tft_outputs.inc"
#include "gaslist.inc"
#include "surfmode.inc"
#include "wait.inc"


	extern deco_push_tissues_to_vault
	extern deco_calc_dive_interval
	extern deco_calc_hauptroutine
	extern deco_pull_tissues_from_vault
	extern TFT_decotype_logbook
	extern do_return_demo_planner
	extern dive_boot_oc_bail
	extern dive_boot_oc

 IFDEF _ccr_pscr
	extern dive_boot_cc
 ENDIF


;---- Private local Variables -------------------------------------------------

	CBLOCK local3				; max size is 16 Byte !!!
		decoplan_index			; within each page
		decoplan_gindex			; global index
		decoplan_last			; depth of last stop
		decoplan_flags			; private flags
		decoplan_page			; page number
		decoplan_warnings		; deco engine warnings
		gas_index				; counter for looping through the gases
		output_row				; used for positioning of the results output
		real_CNS				; real CNS value from before simulated dive
	ENDC						; used: 8 byte, remaining: 8 byte


;---- Private local Flags ----------------------------------------------------

#define decoplan_abort				decoplan_flags,0	; =1: deco calculations were aborted
#define decoplan_last_stop_shown	decoplan_flags,1	; =1: last deco stop is shown
#define decoplan_pressures_shown	decoplan_flags,2	; =1: show gas volumes in bar as per tank sizes
#define decoplan_overflow			decoplan_flags,3	; =1: result > 999
#define decoplan_toggleflag			decoplan_flags,4	; used to show calculation progress
;									decoplan_flags,5	; --- unused
;									decoplan_flags,6	; --- unused
;									decoplan_flags,7	; --- unused


simulator	CODE

;-----------------------------------------------------------------------------

;=============================================================================
; Deco Calculator Main Function
;
	global	do_demo_planner
do_demo_planner:
	btfsc	FLAG_gauge_mode					; in gauge mode?
	bra		do_demo_planner_exit			; YES - abort
	btfsc	FLAG_apnoe_mode					; in apnea mode?
	bra		do_demo_planner_exit			; YES - abort

	clrf	decoplan_flags					; clear all local flags
	bsf		simulatormode					; activate simulator mode
	bsf		reset_timebase					; request ISR to reset the timebase
;	btfsc	reset_timebase					; has the ISR confirmed reset of the timebase?
;	bra		$-2								; NO - not yet, loop waiting for the ISR
	call	deco_push_tissues_to_vault		; back-up the state of the real tissues (C-code)
	banksel	common							; back to bank common

	MOVII	int_O_CNS_current,real_CNS		; memorize real CNS value from before simulated dive

	rcall	deco_calculate					; calculate deco plan

	btfss	decoplan_abort					; was the deco plan calculation aborted?
	rcall	deco_results					; NO - show results

	movff	simulator_time,char_I_dive_interval	; get the deco calculator runtime
	call	deco_pull_tissues_from_vault	; restore the status of the real tissues (C-code)
	call	deco_calc_dive_interval			; catch up with tissue desaturation      (C-code)
	call	deco_calc_desaturation_time		; calculate desaturation and no-fly/no-altitude time after catch-up (C-code)
	banksel	common							; back to bank common

	bcf		switch_left						; clear left button event (may be left over from abort/exit)
	bcf		simulatormode					; terminate simulator mode
	bsf		reset_timebase					; request ISR to reset the timebase
;	btfsc	reset_timebase					; has the ISR confirmed reset of timebase?
;	bra		$-2								; NO - not yet, loop waiting for the ISR

	btfsc	divemode						; shall go into dive mode?
	goto	restart							; YES - goto restart which will dispatch further on to dive mode

	btfss	trigger_timeout					; timeout on any button press?
	bra		do_demo_planner_exit			; NO  - take normal exit into surface menu
	bcf		trigger_timeout					; YES - clear timeout flag
	bcf		restart_fast					;     - set next restart to be done slow, i.e. with logos
	goto	sleeploop						;     - goto sleep mode

do_demo_planner_exit:
	goto	do_return_demo_planner			; return to simulator menu


;=============================================================================
; Calculate the Deco Plan
;
deco_calculate:
	call	request_speed_fastest			; request CPU speed change to fastest speed
	call	TFT_ClearScreen					; clear screen to show that calculator is starting up

	; initialization of the deco engine
	btfsc	update_surface_pressure			; is there a pending surface pressure update?
	bra		$-2								; YES - loop waiting for the ISR to kick in

	; set absolute pressure at selected depth
	movff	char_I_bottom_depth,WREG		; get selected depth in meters
	movwf	depth_meter						; set depth for check_gas_best code
	mullw	.100							; multiply depth with 100 to get relative pressure in mbar
	movff	int_I_pres_surface+0,WREG		; low  byte - get surface pressure to WREG
	addwf	PRODL,W							;           - add relative pressure
	movff	WREG,int_I_pres_respiration+0	;           - store as absolute pressure at depth
	movff	int_I_pres_surface+1,WREG		; high byte - get surface pressure to WREG
	addwfc	PRODH,W							;           - add relative pressure
	movff	WREG,int_I_pres_respiration+1	;           - store as absolute pressure at depth

	; compute absolute pressure / 10, will be used by check_gas_best
	MOVII	int_I_pres_respiration,xA		; get absolute pressure at depth
	MOVLI	.10,xB							; divide by 10
	call	div16x16						; xC = xA / xB = absolute pressure / 10
	MOVII	xC,pressure_abs_10				; store result for later use

	; set up gas / diluent to be used on bottom segment
	clrf	WREG							; reset the deco info vector / deco flag so that ...
	movff	WREG,char_O_deco_info			; ... check_gas_best will not pick any deco gases
 IFDEF _ccr_pscr
	clrf	active_dil						; invalidate active diluent
 ENDIF
	clrf	active_gas						; invalidate active gas
	call	check_gas_best					; determine best diluent and/or gas

 IFDEF _ccr_pscr
	btfsc	FLAG_oc_mode					; in OC mode?
	bra		deco_calculate_0_oc				; YES - set up OC mode
	;bra	deco_calculate_0_loop			; NO  - set up CCR/pSCR mode

deco_calculate_0_loop:
	movf	best_dil_number,W				; get best   diluent into WREG
	bz		deco_calculate_0_error			; any usable diluent found? if NO do error handling
	call	setup_dil_registers				; set-up of  diluent parameters for currently breathed diluent
	call	deco_setup_cc_diluents			; set-up of  diluent list for deco calculations
	bra		deco_calculate_0_com			; continue with common part
 ENDIF

deco_calculate_0_oc:
	movf	best_gas_number,W				; get best   gas into WREG
	bz		deco_calculate_0_error			; any usable gas found? if NO do error handling
	call	setup_gas_registers				; set-up of  gas parameters of currently breathed gas
	call	deco_setup_oc_gases				; set-up of  gas list for deco calculations
	bra		deco_calculate_0_com			; continue with common part

deco_calculate_0_error:
	call	request_speed_normal			; request switch back to normal speed
	WIN_COLOR	color_red					; select color for error message
	TEXT_SMALL	.0,  .80, tNoBottomGas1		; print            error message, line 1
	TEXT_SMALL	.0, .105, tNoBottomGas2		; print            error message, line 2
	bsf		decoplan_abort					; set abort flag
	call	wait_1s							; wait up to a full second
	call	wait_1s							; wait       a full second
	call	wait_1s							; wait another full second
	bcf		switch_left						; clear potential button event
	return									; return to deco calculator main function

deco_calculate_0_com:
	; set deco stop settings
	movff	opt_last_stop,char_I_depth_last_deco	; write last stop depth to deco engine

	; set GF factors
	movff	opt_GF_low, char_I_GF_Low_percentage	; load normal GF factors by default
	movff	opt_GF_high,char_I_GF_High_percentage	; ...
	TSTOSS	opt_sim_use_aGF							; shall use alternative GF factors in simulation?
	bra		deco_calculate_1						; NO  - keep normal GF factors
	movff	opt_aGF_low ,char_I_GF_Low_percentage	; YES - overwrite with alternative GF factors
	movff	opt_aGF_high,char_I_GF_High_percentage	;     - ...

deco_calculate_1:

 IFDEF _ccr_pscr
	; set char_I_const_ppO2 for pSCR/CCR mode
	clrf	WREG							; load coding for pSCR calculated ppO2
	btfsc	FLAG_pscr_mode					; in pSCR mode?
	movff	WREG,char_I_const_ppO2			; YES - configure pSCR computations to calculated ppO2
	btfss	FLAG_ccr_mode					; in CCR mode?
	bra		deco_calculate_2				; NO  - skip next
	movff	opt_sim_setpoint_number,WREG	; YES - get selected setpoint
	decf	WREG,W							;     - 1-5 -> 0-4
	lfsr	FSR1,opt_setpoint_cbar			;     - load base address of setpoint list
	movff	PLUSW1,char_I_const_ppO2		;     - configure setpoint value
 ENDIF

deco_calculate_2:

	; configure the deco engine - char_O_main_status
	movff	char_O_main_status,hi			; get the configuration set by dive_boot_oc / dive_boot_cc
	bsf		hi,DECO_VOLUME_FLAG				; enable gas volume calculation
	bsf		hi,DECO_BOTTOM_FLAG				; include bottom segment into gas needs
	bcf		hi,DECO_CAVE_MODE				; cave mode not supported in deco calculator
	bcf		hi,DECO_Z_FACTOR_FLAG			; disable Z factors by default
	TSTOSC	opt_ZfactorUse					; shall use Z factors?
	bsf		hi,DECO_Z_FACTOR_FLAG			; YES - enable Z factors
	bcf		hi,DECO_EXTENDED_STOPS			; disable extended stops by default
	TSTOSC	opt_extended_stops				; shall make extended stops?
	bsf		hi,DECO_EXTENDED_STOPS			; YES - activate extended stops
	bcf		hi,DECO_TR_FUNCTIONS			; execution of TR functions is not needed in deco calculator mode
	movff	hi,char_O_main_status			; bank-safe copy to deco engine control

	; configure the deco engine - char_O_deco_status
	movff	char_O_deco_status,lo			; get the configuration set by dive_boot_oc / dive_boot_cc
	bcf		lo,DECO_START_NORM				; clear flag for normal      plan mode
	bcf		lo,DECO_START_ALT				; clear flag for alternative plan mode
	bsf		lo,DECO_INITIALIZE				; set   flag for once-per-dive initialization
	bsf		lo,DECO_CALCULATOR_MODE			; signal that the deco engine is run from the deco calculator
	bcf		lo,DECO_BAILOUT_FLAG			; no gas switches before first deco stop
	bcf		lo,DECO_ASCENT_FLAG				; no delayed ascent
	movff	lo,char_O_deco_status			; bank-safe copy to deco engine control

deco_calculate_redo:

	call	request_speed_fastest			; request CPU speed change to fastest speed (again, if in redo)

	; show that the deco calculation is in progress
	call		TFT_ClearScreen				; clear screen from last results
	WIN_COLOR	color_lightblue				; select color for abort label
	TEXT_SMALL	.1,.215, tAbort				; print abort label
	WIN_COLOR	color_white					; select color for title and progress outputs
	TEXT_SMALL	.0, .40, tCalculating		; print "Calculating..."

	; calculate the surface interval
	TSTOSS	opt_surface_interval						; surface interval > 0 ?
	bra		deco_calculate_bottom						; NO  - continue with bottom segment
	TEXT_SMALL	.20,.75, tCalcSurfInter					; YES - print what we are doing
	movff	opt_surface_interval,char_I_dive_interval	;     - copy surface interval to deco engine
	call	deco_calc_dive_interval						;     - calculate surface interval  (C-code)
	banksel	common										;     - back to bank common

	; calculate the bottom segment
deco_calculate_bottom:
	; advance tissues by selected bottom time,
	; char_I_sim_advance_time is cleared by deco engine after execution
	movff	char_I_bottom_time,char_I_sim_advance_time

	TEXT_SMALL	.20,.100,tCalcBotSeg		; print what we are doing

	; invoke the deco engine once to condition the real tissues
	; to their pressure state at the end of the bottom segment
	call	deco_calc_hauptroutine			; (C-code)
	banksel	common

 IFDEF _ccr_pscr
	; conditional switch to bailout mode
	btfss	bailout_mode					; shall calculate a bailout plan?
	bra		deco_calculate_ascent			; NO  - skip next

	call	dive_boot_oc					; YES - switch to OC mode, configure OC gases and switch to gas set as 'First'
	movff	char_O_main_status,hi			;     - bank-safe copy from deco engine control (main status)
	bcf		hi,DECO_BOTTOM_FLAG				;     - exclude bottom segment from gas needs, i.e. calculate ascent needs only
	movff	hi,char_O_main_status			;     - bank-safe copy back to deco engine control
	movff	char_O_deco_status,lo			;     - bank-safe copy from deco engine control (deco status)
	bsf		lo,DECO_BAILOUT_FLAG			;     - allow gas switches before first deco stop
	bsf		lo,DECO_ASCENT_FLAG				;     - allow delayed ascent
	movff	lo,char_O_deco_status			;     - bank-safe copy back to deco engine control

	TEXT_SMALL	.20,.125, tCalcBailout		;     - print what we are doing
 ENDIF

	; calculate ascent
deco_calculate_ascent:
	movff	char_O_deco_status,lo			; bank-safe copy from deco engine control
	bsf		lo,DECO_START_NORM				; start calculation of a normal plan
	movff	lo,char_O_deco_status			; bank-safe copy back to deco engine control
	TEXT_SMALL	.20,.150, tCalcAscent		; print what we are doing
deco_calculate_loop:
	btfsc	switch_left						; was the left button pressed?
	bra		deco_calculate_abort			; YES - set abort flag, do some clean-up and return
	call	deco_calc_hauptroutine			; NO  - invoke the deco engine so that it can do the deco calculation (C-code)
	banksel	common							;     - back to bank common
	movff	char_O_depth_sim,lo				;     - get the depth reached (in meters)
	WIN_SMALL .75,.150						;     - set output position
	output_8								;     - print depth reached (in meters)
	STRCAT	" m"							;     - print unit (meters)
	btg		decoplan_toggleflag				;     - toggle the toggle flag
	btfsc	decoplan_toggleflag				;     - toggle flag set?
	bra		deco_calculate_loop_1			;       YES - print ". "
	STRCAT_PRINT " ."						;       NO  - print " ."
	bra		deco_calculate_loop_2			;
deco_calculate_loop_1:						;
	STRCAT_PRINT ". "						;
deco_calculate_loop_2:						;
	movff	char_O_deco_status,lo			;     - get deco calculation status
	btfss	lo,DECO_COMPLETED_NORM			;     - deco calculation completed?
	bra		deco_calculate_loop				;       NO  - loop
	movff	char_O_deco_warnings,decoplan_warnings; YES - copy warnings for later display
	bra		deco_calculate_finish			;           - do some clean-up and return
deco_calculate_abort:
	bcf		switch_left						; clear button event
	bsf		decoplan_abort					; set abort flag
deco_calculate_finish:
	goto	request_speed_normal			; request switch back to normal speed and return to deco calculator main function


;-----------------------------------------------------------------------------
; Draw a stop of the deco plan (simulator or dive)
; Inputs:  lo      = depth
;          hi      = minutes
;          win_top = line to draw on screen.
;
; Trashed: hi, lo,
;          win_height, win_leftx2, win_width, win_color*,
;          WREG, PROD, TBLPTR TABLAT.
;
deco_plan_show_stop:
	; print depth
	lfsr	FSR2,char_O_deco_gas			; needed to be initialized here every time because...
	movf	decoplan_gindex,W				; ...FSR2 is also used for string operations
	movff	PLUSW2,WREG						; get current gas and copy it to WREG for color-coding
	call	TFT_color_code_gas				; set output color dependent on gas (1-5)

	lfsr	FSR2,buffer						; set up output buffer

	TSTOSS	opt_units						; 0=Meter, 1=Feet
	bra		deco_plan_show_nstd_stop_metric	; 0 - do metric
											; 1 - do imperial
	movff	hi,ul							; back-up hi (minutes)
	WIN_LEFT .80
	call	convert_meter_to_feet			; convert value in lo from meters to feet
	output_16_3								; limit output to 0...999
	STRCAT_PRINT "ft"
	movff	ul,hi							; restore hi (minutes)
	bra		deco_plan_show_nstd_stop_common

deco_plan_show_nstd_stop_metric:
	WIN_LEFT .85
	output_8								; outputs into postinc2
	STRCAT_PRINT "m"

deco_plan_show_nstd_stop_common:

	; print duration
	WIN_LEFT .135
	lfsr	FSR2,buffer
	movff	hi,lo
	output_99dd								; stop entries are 99 minutes at max., prints double dots if duration is zero
	STRCAT_PRINT "'"

	; draw the bar graph used for deco stops (lo = minutes)
	incf	win_top,F
	movlw	.19
	movwf	win_height
	movlw	.118
	movwf	win_leftx2						; column left (0-159)
	MOVLI	.16,win_width					; column max width
	incf	lo,W							; add 1 for a minimum visible active bargraph area
	movwf	win_bargraph					; set width of the active bargraph area
	call	TFT_box							; draw bargraph

	; restore win_top
	call	TFT_standard_color
	decf	win_top,F						; restore win_top
	return


;-----------------------------------------------------------------------------
; Display the deco plan (simulator)
; Inputs: char_O_deco_table (array of stop times, in minutes)
;         decoplan_page = page number.
;
deco_results_page:
	bcf		win_invert						; reset invert flag
	WIN_COLOR color_greenish
 IFDEF _ccr_pscr
	btfss	bailout_mode					; bailout results?
	bra		deco_results_page_1				; NO
	TEXT_SMALL .80,.1, tDiveBailout			; YES
	bra		deco_results_page_2
 ENDIF
deco_results_page_1:
	TEXT_SMALL .80,.1, tDivePlan
deco_results_page_2:
	movff	char_O_deco_info,WREG			; get the deco info vector
	btfsc	WREG,deco_stops					; are there deco stops?
	bra		deco_plan_show_1				; YES

	;---- no deco --------------------------------------------------------
	call	TFT_standard_color
	TEXT_SMALL .80, .25, tNoDeco

	; output of remaining NDL time
	WIN_SMALL .80, .50						; same line as bottom time
	PUTC	"+"
	movff	char_O_NDL_norm,lo				; get NDL time in normal plan
	bsf		leftbind
	output_8
	bcf		leftbind
	PUTC	"'"
	PUTC	" "
	STRCAT_TEXT_PRINT tNDLleft				; "NDL"

	bsf		decoplan_last_stop_shown
	return

	;---- deco stops ---------------------------------------------------------
deco_plan_show_1:
	lfsr	FSR0,char_O_deco_depth			; initialize indexed addressing
	lfsr	FSR1,char_O_deco_time

	clrf	decoplan_index					; start with index = 0
	movlw	.24
	movwf	win_top							; and row = 0 at position 24

	; read stop parameters, indexed by decoplan_index and decoplan_page
	movf	decoplan_page,W					; decoplan_gindex = 6*decoplan_page + decoplan_index
	mullw	.8								; 8 lines/page in deco plan
	movf	decoplan_index,W
	addwf	PRODL,W
	movwf	decoplan_gindex					; --> decoplan_gindex

	bcf		decoplan_last_stop_shown		; not done yet...

deco_plan_show_2:
	btfsc	decoplan_gindex,5				; reached table length (32) ?
	bra		deco_plan_show_99				; YES - done

	; read stop parameters, indexed by decoplan_index
	movf	decoplan_gindex,W				; index
	movff	PLUSW0,lo						; char_O_deco_depth[decoplan_gindex]
	movff	PLUSW1,hi						; char_O_deco_time [decoplan_gindex]
	movf	lo,W
	bz		deco_plan_show_99				; depth == 0 -> done

	; display the stop line
	rcall	deco_plan_show_stop

	; next
	movlw	.24
	addwf	win_top,F						; row: += 24
	incf	decoplan_index,F				; local index += 1
	incf	decoplan_gindex,F				; global index += 1

	; max number of lines/page reached?
	movlw	.8								; 8 lines/page in deco plan
	cpfseq	decoplan_index
	bra		deco_plan_show_2				; NO - loop

	; check if next stop is end-of-list?
	movf	decoplan_gindex,W
	movf	PLUSW0,W						; char_O_deco_depth[decoplan_gindex]
	bz		deco_plan_show_99				; end of list

	call	TFT_standard_color
	WIN_SMALL .135,.212
	STRCAT_PRINT ">>>"
	return

deco_plan_show_99:
	bsf		decoplan_last_stop_shown		; nothing more in table to display
	call	TFT_standard_color
	return

;=============================================================================
; Show Deco Calculation Results
;
deco_results:
	call	TFT_ClearScreen
	call	TFT_standard_color

	; print interval
	WIN_SMALL .0,.25
	STRCPY	"Int. :"
	movff	opt_surface_interval,lo
	output_8
	STRCAT_PRINT "'"

	; print bottom time
	WIN_SMALL .0,.50
	STRCPY_TEXT tBtTm_short
	movff	char_I_bottom_time,lo
	output_8
	STRCAT_PRINT "'"

	; print bottom depth
	WIN_SMALL .0,.75
	STRCPY_TEXT tDepth
	PUTC	":"
	movff	char_I_bottom_depth,lo
	output_8
	STRCAT_PRINT "m"

	; print warnings or sat/dsat factors
	WIN_SMALL .0,.105

	; check for stop table overflow
	btfss	decoplan_warnings,deco_plan_incomplete	; check if deco plan is incomplete
	bra		deco_results_0a							; NO  - skip

	; display overflow warning
	call	TFT_warning_color						; YES - show overflow warning
	STRCAT_PRINT "incomplete"						; max 10 characters
	bra		deco_results_m1							; skip displaying sat/dsat factors

deco_results_0a:

 IFDEF _helium
	; check for IBCD warning
	btfss	decoplan_warnings,IBCD_warning_lock		; check if we have a locked IBCD warning
	bra		deco_results_2b							; NO  - skip

	; display IBCD warning
	call	TFT_attention_color						; YES - show IBCD warning
	STRCAT_PRINT "IBCD!"							; max 10 characters
	bra		deco_results_m1							; skip displaying sat/dsat factors
 ENDIF

deco_results_2b:

	; display Sat/Desat factors --> omitted if there were warnings
	STRCAT_PRINT "SD:"
	WIN_SMALL .25,.105
	movff	char_I_saturation_multiplier,lo
	output_8
	STRCAT	"/"
	movff	char_I_desaturation_multiplier,lo
	output_8
	STRCAT_PRINT ""

deco_results_m1:

	call	TFT_standard_color				; clean-up from warnings

	; get model
	movff	char_I_deco_model,WREG			; 0: straight Buhlmann, 1: with GF
	iorwf	WREG							; GF factors in use?
	bz		deco_results_m2					; NO

	; display GF low/high factors
	WIN_SMALL .0,.130
	STRCAT_PRINT "GF:"
	WIN_SMALL .25,.130
	movff	char_I_GF_Low_percentage,lo
	output_8
	STRCAT	"/"
	movff	char_I_GF_High_percentage,lo
	output_8
	STRCAT_PRINT ""

deco_results_m2:

	; display deco mode
	WIN_SMALL .0,.155
	lfsr	FSR2,buffer
	movff	opt_dive_mode,lo				; 0=OC, 1=CC, 2=Gauge, 3=Apnea, 4=pSCR
	call	TFT_decotype_logbook

 IFDEF _ccr_pscr
	btfss	FLAG_ccr_mode					; current dive mode = CCR ?
	bra		deco_results_2c					; NO - skip
	WIN_SMALL .25,.155
	STRCPY	"SP:"							; output setpoint used for calculation
	movff	opt_sim_setpoint_number,lo
	bsf		leftbind
	output_8
	bcf		leftbind
	STRCAT_PRINT ""
 ENDIF

deco_results_2c:

	btfss	FLAG_oc_mode					; current dive mode = OC ?
	bra		deco_results_2d					; NO  - skip
	TSTOSS	opt_extended_stops				; YES - extended stops activated?
	bra		deco_results_2d					;       NO  - skip
	WIN_SMALL .18,.155						;       YES - set position
	STRCAT_PRINT "ext.Stop"					;           - print notice

deco_results_2d:

	; display TTS result
	WIN_SMALL .0,.180
	STRCPY_TEXT tTTS
	STRCAT	": "
	MOVII	int_O_TTS_norm,mpr
	bsf		leftbind
	output_16
	bcf		leftbind
	STRCAT_PRINT "'"

	; display CNS result
	WIN_TOP	.205
	STRCPY_TEXT tCNS2						; "CNS:"
	MOVII	real_CNS,mpr					; recall real CNS from before simulated dive
	call	TFT_color_code_cns				; color-code CNS output
	bsf		leftbind
	output_16_3								; limit to 999 and display only (0-999)
	bcf		leftbind
	STRCAT	"%\x92"							; "->"
	MOVII	int_O_CNS_norm,mpr				; get CNS at end of simulated dive in normal plan
	call	TFT_color_code_cns				; color-code CNS output
	bsf		leftbind
	output_16_3								; limit to 999 and display only (0-999)
	bcf		leftbind
	STRCAT_PRINT "%"
	call	TFT_standard_color

	; loop through deco plan pages
deco_results_1:
	clrf	decoplan_page					; start from first page
	bcf		decoplan_pressures_shown		; when showing the gas needs, start with volumes (liter)
deco_results_1a:
	WIN_BOX_BLACK .0, .239, .80, .159		; clear the complete right part of the result column (top, bottom, left, right)
	rcall	deco_results_page				; show a results page
	incf	decoplan_page,F					; increment results page number
	call	reset_timeout_surfmode			; reset timeout
	bcf		switch_right					; clear left-over right button event
	bcf		switch_left						; clear left-over left  button event
deco_results_2:
	btfsc	switch_right					; right button pressed?
	bra		deco_results_3					; YES - show further results
	btfsc	switch_left						; left button pressed?
	return									; YES - return to deco calculator main function
	call	housekeeping					; NO to both - handle screen dump request, timeout and need to enter dive mode
	btfsc	divemode						; shall go into dive mode?
	bsf		decoplan_abort					; YES - set abort flag
	btfsc	trigger_timeout					; timeout on any button press?
	bsf		decoplan_abort					; YES - set abort flag
	btfss	decoplan_abort					; shall abort?
	bra		deco_results_2					; NO  - loop
	return									; YES

deco_results_3:
	btfss	decoplan_last_stop_shown		; was the last stop shown already?
	bra		deco_results_1a					; NO - loop

 IFDEF _ccr_pscr
	movff	char_O_deco_status,WREG			; YES - get deco calculation status
	btfss	WREG,DECO_MODE_LOOP_FLAG		;     - check if calculation was made for loop mode (CCR/pSCR)
	bra		deco_results_gas_volumes		;       NO  - normal OC mode or bailout mode, show gas needs
	bsf		bailout_mode					;       YES - do a 2nd deco-plan in bailout mode
	call	deco_pull_tissues_from_vault	;           - restore the status of the real tissues (C-code)
	banksel	common							;           - back to bank common
	rcall	deco_calculate_redo				;           - redo complete deco calculation
	btfss	decoplan_abort					;           - was the calculation aborted?
	bra		deco_results					;             NO  - redo display of deco stops
	return									;             YES - return to deco calculator main function
 ENDIF

	;---- show the gas needs (OC and bailout only) ---------------------------
deco_results_gas_volumes:
	lfsr	FSR0,int_O_gas_need_vol			; load base address of gas needs in volume

deco_results_gas_common:
	WIN_BOX_BLACK .0, .239, .80, .159		; clear the complete right part of the result column (top, bottom, left, right)
	movlw	.25								; output row is 25 (fixed offset set here) + n*25 (line increment, see below)
	movwf	output_row						; set fixed vertical offset for output row
	WIN_LEFT .80							; set column
	call	TFT_standard_color
	clrf	gas_index						; initialize gas counter
	bcf		is_diluent_menu					; working on OC gases

deco_results_gas_loop:
	movff	gas_index,PRODL					; copy gas index to PRODL (interface to gaslist_strcat_gas)
	incf	gas_index,F						; increment gas index

	movf	gas_index,W						; copy gas index to WREG for color-coding
	call	TFT_color_code_gas				; set output color according to gas (1-5)

	lfsr	FSR2,buffer						; load base address of output buffer
	bsf		short_gas_descriptions			; configure gaslist_strcat_gas output format
	bsf		divemode						; configure gaslist_strcat_gas output format
	call	gaslist_strcat_gas				; write "Nxlo", "Txlo/hi", "Air" or "O2" into output buffer
	bcf		divemode						; cleanup above

	movlw	.25								; spacing between outputs
	addwf	output_row,F					; increase row position
	movff	output_row,win_top				; set      row position

	movff	POSTINC0,lo						; read gas volume low  byte
	movff	POSTINC0,hi						;                 high byte

	bcf		decoplan_overflow				; no overflow in gas needs by default

	btfsc	decoplan_pressures_shown		; results in bar?
	bra		deco_results_gas_volumes_1		; YES

	; output of gas needs in liter
	movf	lo,W							; check if hi:lo = 65535: copy low byte to WREG
	andwf	hi,W							; and do a bitwise AND with the high byte
	incfsz	WREG							; add 1, result zero now?
	bra		deco_results_gas_volumes_2		; NO  - print volume
	STRCAT_PRINT ">65500"					; YES - print ">65500"
	bra		deco_results_gas_volumes_3		;     - continue checking if all gases are shown

	; output of gas needs in bar
deco_results_gas_volumes_1:
	btfsc	hi,int_high_flag				; overflow in result?
	bsf		decoplan_overflow				; YES - remember it
	bcf		hi,int_high_flag				; clear flag for overflow in result
	btfsc	hi,int_warning_flag				; gas needs above available amount?
	bsf		win_invert						; YES - print in inverse
	bcf		hi,int_warning_flag				; clear flag for gas needs above    available amount
	bcf		hi,int_attention_flag			; clear flag for gas needs close to available amount
	bcf		hi,int_invalid_flag				; clear flag for invalid data
	bcf		hi,int_is_zero					; clear flag for zero

deco_results_gas_volumes_2:
	PUTC	":"								; print ":"
	output_16								; print 16 bit number
	movlw	'>'								; load coding of ">" sign into WREG
	btfsc	decoplan_overflow				; overflow in result?
	movff	WREG,buffer+.7					; YES - place ">" before number
	STRCAT_PRINT ""							; finalize output
	bcf		win_invert						; back to none-inverse printing

deco_results_gas_volumes_3:
	movlw	NUM_GAS							; 5 gases to show
	cpfseq	gas_index						; all gases shown?
	bra		deco_results_gas_loop			; NO - loop

	WIN_COLOR color_greenish				; set color
	TEXT_SMALL .80,.01,tGasUsage			; "Gas Usage"

	btfsc	decoplan_pressures_shown		; results shown in bar?
	bra		deco_results_gas_volumes_4		; YES
	TEXT_SMALL .120,.25,tLiterLong			; NO  - in Liter then
	bra		deco_results_gas_volumes_5		;     - continue with initialization of housekeeping

deco_results_gas_volumes_4:
	TEXT_SMALL .120,.25,tbar				; " bar" (with leading space)

deco_results_gas_volumes_5:
	call	TFT_standard_color				; revert to standard color
	call	reset_timeout_surfmode			; reset timeout
	bcf		switch_right					; clear left-over right button event
	bcf		switch_left						; clear left-over left  button event
deco_results_gas_volumes_6:
	btfsc	switch_right					; right button pressed?
	bra		deco_results_gas_volumes_7		; YES - show results in bar or restart with deco stops again
	btfsc	switch_left						; left button pressed?
	return									; YES - return to deco calculator main function
	call	housekeeping					; NO to both - handle screen dump request, timeout and need to enter dive mode
	btfsc	divemode						; shall go into dive mode?
	bsf		decoplan_abort					; YES - set abort flag
	btfsc	trigger_timeout					; timeout on any button press?
	bsf		decoplan_abort					; YES - set abort flag
	btfss	decoplan_abort					; shall abort?
	bra		deco_results_gas_volumes_6		; NO  - loop
	return									; YES

deco_results_gas_volumes_7:
	btfsc	decoplan_pressures_shown		; results shown in bar?
	bra		deco_results_1					; YES - show deco stops again
	bsf		decoplan_pressures_shown		; NO  - but now
	lfsr	FSR0,int_O_gas_need_pres		;     - load base address of gas needs in bar
	bra		deco_results_gas_common			;     - re-run gas needs output in pressure mode


	END