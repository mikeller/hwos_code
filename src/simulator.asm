;=============================================================================
;
;   File simulator.asm								REFACTORED VERSION V2.99e
;
;   Decoplan interface to C model code.
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
#include "wait.inc"					; speed_*
#include "start.inc"
#include "divemode.inc"
#include "math.inc"
#include "eeprom_rs232.inc"
#include "tft_outputs.inc"
#include "gaslist.inc"
#include "isr.inc"

	extern deco_clear_tissue
	extern deco_push_tissues_to_vault
	extern deco_calc_dive_interval
	extern deco_calc_hauptroutine
	extern deco_pull_tissues_from_vault
	extern TFT_display_decotype_surface1
	extern log_screendump_and_onesecond
	extern logbook_preloop_tasks
	extern do_return_demo_planner
	extern dive_boot_oc_bail
	extern dive_boot_oc
	extern dive_boot_cc


;---- Private local variables -------------------------------------------------

	CBLOCK local1				; max size is 16 Byte !!!
		decoplan_index			; within each page
		decoplan_gindex			; global index
		decoplan_last			; depth of last stop (CF#29)
		decoplan_flags			; various private flags
		decoplan_page			; page number
		decoplan_warnings		; deco engine warnings
		gas_counter				; counter for looping through the gases
		row_pos					; used for positioning of graphic elements
	ENDC						; used: 8 byte, remaining: 8 byte

;---- Defines ----------------------------------------------------------------

#define decoplan_last_ceiling_shown	decoplan_flags,0
#define decoplan_abort				decoplan_flags,1


simulator		CODE


;---- Demo deco planner ------------------------------------------------------

	global	do_demo_planner
do_demo_planner:
	btfsc	FLAG_gauge_mode					; in gauge mode?
	bra		do_demo_planner_exit			; YES - abort
	btfsc	FLAG_apnoe_mode					; in Apnea mode?
	bra		do_demo_planner_exit			; YES - abort
	bcf		decoplan_abort					; initialize (clear) abort flag
	bcf		FLAG_bailout_mode				; clear bailout condition (may have remained set from last invocation)
	rcall	deco_planer
	btfss	decoplan_abort					; skip recall deco_show_plan if calculations were aborted
	rcall	deco_show_plan
do_demo_planner_exit:
	goto	do_return_demo_planner


deco_setup:
	call	dive_boot_oc_bail				; basic setup for all modes
	btfsc	FLAG_oc_mode					; in OC mode?
	call	dive_boot_oc					; YES - set up OC mode
	btfss	FLAG_oc_mode					; in OC mode?
	call	dive_boot_cc					; NO - set up CCR/pSCR mode

	; use ambient conditions for deco calculation
	SAFE_2BYTE_COPY last_surfpressure_30min, int_I_pres_surface	; copy surface pressure to deco routine

	movlw	deco_distance
	movff	WREG,char_I_deco_distance

	movff	opt_last_stop,char_I_depth_last_deco
	movff	opt_GF_low,char_I_GF_Low_percentage
	movff	opt_GF_high,char_I_GF_High_percentage

	; overwrite GF if aGF is wanted
	bsf		use_agf							; set flag to use alternative GF factors by default
	TSTOSS	opt_sim_use_aGF					; shall use alternative GF factors?
	bcf		use_agf							; NO - clear flag again

	btfsc	use_agf							; =1: use aGF
	movff	opt_aGF_low,char_I_GF_Low_percentage
	btfsc	use_agf							; =1: use aGF
	movff	opt_aGF_high,char_I_GF_High_percentage

	; setup char_I_const_ppO2 for CC modes
	clrf	WREG
	btfsc	FLAG_pscr_mode
	movff	WREG,char_I_const_ppO2			; configure pSCR computations to calculated ppO2
	btfss	FLAG_ccr_mode
	return									; done if not in CCR mode
	movff	opt_sim_setpoint_number,WREG	; configure CCR computations to selected setpoint
	decf	WREG,W							; 1-5 -> 0-4
	lfsr	FSR1,char_I_setpoint_cbar		; load base address of setpoint list
	movff	PLUSW1,char_I_const_ppO2		; setup setpoint
	return

;=============================================================================
; Launch deco planning
;
		global	deco_planer
deco_planer:
	call	speed_fastest					; quick!
	call	TFT_ClearScreen					; clear screen to show that calculator is starting up
	call	deco_push_tissues_to_vault		; C-code: back-up state of the real tissues
	banksel	common
	rcall	deco_setup						; setup all model parameters

;---- Specific settings ------------------------------------------------------

	; configure the deco engine for normal plan, CNS & gas volume calculation and no delayed ascent
	movff	char_O_deco_status,lo			; bank-safe copy
	bcf		lo,DECO_PLAN_FLAG				; normal plan mode,
	bsf		lo,DECO_VOLUME_FLAG				; enable gas volume calculation, and
	bcf		lo,DECO_ASCENT_FLAG				; disable delayed ascent calculation
	movff	lo,char_O_deco_status			; bank-safe copy back

	; configure the deco engine for total-dive gas volume calculation
	movff	char_O_main_status,hi			; bank-safe copy
	bcf		hi,DECO_TR_FUNCTIONS			; execution of TR functions is not needed in deco calculator mode
	bsf		hi,DECO_BOTTOM_FLAG				; set bottom flag
	bsf		hi,DECO_Z_FACTOR_FLAG			; enable use of Z factor by default
	TSTOSS	opt_ZfactorUse					; shall use Z factor?
	bcf		hi,DECO_Z_FACTOR_FLAG			; NO - disable again
	movff	hi,char_O_main_status			; bank-safe copy back

deco_planer_redo:
	; show deco calculation is in progress
	call	TFT_ClearScreen
	WIN_COLOR	color_greenish
	TEXT_SMALL	.20,.40, tCalculating
	WIN_COLOR	color_lightblue
	WIN_SMALL	.1,.215
	STRCPY_TEXT_PRINT tAbort

	; configure the deco engine for initialization
	movff	char_O_deco_status,lo			; bank-safe copy
	bsf		lo,DECO_STATUS_0_FLAG			; configure init ...
	bsf		lo,DECO_STATUS_1_FLAG			; ... state,
	movff	lo,char_O_deco_status			; bank-safe copy back

;---- add delay at surface, if requested -------------------------------------
	banksel	char_I_dive_interval
	tstfsz	char_I_dive_interval
	call	deco_calc_dive_interval

;---- Dive loop --------------------------------------------------------------
	; compute dive ambient conditions
	banksel	char_I_bottom_depth
	movf	char_I_bottom_depth,W
	mullw	.100
	movlw	LOW (.1000)
	addwf	PRODL,W
	movwf	int_I_pres_respiration+0
	movlw	HIGH(.1000)
	addwfc	PRODH,W
	movwf	int_I_pres_respiration+1
	banksel	common

	movff	char_I_bottom_time,char_I_sim_advance_time

	clrf	TMR5L							; restart timer used to preempt stops calculation
	clrf	TMR5H							;

	call	deco_calc_hauptroutine			; initialization, complete bottom time part and initial ascent
	banksel	common

	btfss	FLAG_bailout_mode				; doing a bailout deco plan?
	bra		deco_planer_loop				; NO  - keep gases and go on
											; YES - switch to OC gas and restart deco plan

;---- BAILOUT: Switch to OC gases for ascent -----------------------------------

	; reconfigure the deco engine for delayed ascent & bailout mode and start a new calculation cycle
	movff	char_O_deco_status,lo			; bank-safe copy
	bsf		lo,DECO_ASCENT_FLAG				; set flag for delayed ascent calculation
	bsf		lo,DECO_BAILOUT_FLAG			; set bailout mode flag to allow gas changes on initial ascent
	bcf		lo,DECO_STATUS_0_FLAG			; configure start of a new...
	bcf		lo,DECO_STATUS_1_FLAG			; ... deco calculation cycle
	movff	lo,char_O_deco_status			; bank-safe copy back

	; reconfigure the deco engine for bailout ascent needs
	movff	char_O_main_status,hi			; bank-safe copy
	bcf		hi,DECO_BOTTOM_FLAG				; clear bottom flag
	movff	hi,char_O_main_status			; bank-safe copy back

	; reconfigure gas settings to OC gases
	call	dive_boot_oc					; configure deco engine for OC mode

;---- Wait until status reaches zero -------------------------------------------
deco_planer_loop:
	clrf	TMR5L							; restart timer used to preempt stops calculation
	clrf	TMR5H							;
	call	deco_calc_hauptroutine			; simulate more dive time to trigger the deco calculations
	banksel	common

	btfss	switch_left						; check if left button was pressed
	bra		deco_planer_finishing_1			; NO  - continue calculations
	bsf		decoplan_abort					; YES - set abort flag so that deco_show_plan will not be called
	bra		deco_planer_finishing_2			;       do some clean-up and return
deco_planer_finishing_1:
	movff	char_O_main_status,hi			; working copy of char_O_main_status in bank common
	btfss	hi,DECO_COMPLETED_NORM			; calculations completed?
	bra		deco_planer_loop				; NO - needs more computation cycles

;---- Done: add CNS from decoplan, and restore tissues
deco_planer_finishing_2:
	movff	char_O_deco_warnings,decoplan_warnings	; copy warnings

	call	deco_pull_tissues_from_vault	; C-code: restore status of the real tissues
	banksel	common							; back to bank 1

	movlw	b'00111000'						; 1:8 Prescaler -> 65,536ms@16MHz
	movwf	T3CON
	goto	speed_normal					; (and return)

;-----------------------------------------------------------------------------
; Draw a stop of the deco plan (simulator or dive).
; Inputs:  lo      = depth
;          hi      = minutes
;          win_top = line to draw on screen.
;
; Trashed: hi, lo,
;          win_height, win_leftx2, win_width, win_color*,
;          WREG, PROD, TBLPTR TABLAT.
;
deco_plan_show_stop:
	;---- Print depth ----------------------------------------------------
	lfsr	FSR2,char_O_deco_gas		; needed to be initialized here every time because...
	movf	decoplan_gindex,W			; ...FSR2 is also used for string operations
	movff	PLUSW2,WREG					; get current gas and copy it to WREG for color-coding
	call	TFT_color_code_gas			; set output color dependent on gas (1-5)

	lfsr	FSR2,buffer

	TSTOSS	opt_units					; 0=Meter, 1=Feet
	bra		deco_plan_show_nstd_stop_metric

	movff	hi,ul						; back-up hi (minutes)
	WIN_LEFT .80
	movf	lo,W						; lo = m
	mullw	.100						; PRODL:PRODH = hPa
	movff	PRODL,lo
	movff	PRODH,hi
	; Convert with 334feet/100m to have 10ft, 20ft, 30ft stops...
	movff	lo,xA+0
	movff	hi,xA+1
	movlw	LOW  d'334'					; 334feet/100m
	movwf	xB+0
	movlw	HIGH d'334'
	movwf	xB+1
	call	mult16x16					; xA*xB=xC (lo:hi * 328)
	movlw	d'50'						; round up
	addwf	xC+0,F
	movlw	.0
	addwfc	xC+1,F
	addwfc	xC+2,F
	addwfc	xC+3,F
	movlw	d'100'
	movwf	xB+0
	clrf	xB+1
	call	div32x16					; xC:4 / xB:2 = xC+3:xC+2 with xC+1:xC+0 as remainder
	movff	xC+0,lo
	movff	xC+1,hi						; restore lo and hi with updated value
	bsf		ignore_digit4				; only full feet
	output_16
	STRCAT_PRINT "ft"
	movff	ul,hi						; restore hi (minutes)
	bra		deco_plan_show_nstd_stop_common

deco_plan_show_nstd_stop_metric:
	WIN_LEFT .85
	output_8							; outputs into postinc2
	STRCAT_PRINT "m"

deco_plan_show_nstd_stop_common:
	;---- Print duration -------------------------------------------------
	WIN_LEFT .135
	lfsr	FSR2,buffer
	movff	hi,lo
	output_99							; stop entries are 99 min max.
	STRCAT_PRINT "'"

	;---------------------------------------------------------------------
	; Draw the bar graph used for deco stops (deco plan in simulator or dive)
	incf	win_top,F
	movlw	.19
	movwf	win_height
	movlw	.118
	movwf	win_leftx2					; column left (0-159)
	movlw	.16
	movwf	win_width+0					; column max width
	clrf	win_width+1

	; Draw used area (lo = minutes):
	movlw	.16							; limit length to max. column width
	cpfslt	lo
	movwf	lo
	movff	lo,win_bargraph				; active width, the rest is cleared
	call	TFT_box

	; Restore win_top
	call	TFT_standard_color
	decf	win_top,F					; restore win_top
	return

;-----------------------------------------------------------------------------
; Clear unused area below last stop
; Inputs: win_top : last used area...
deco_plan_show_clear_bottom:
	movf	win_top,W					; get back from bank0
	sublw	.239						; bottom row in planning
	movwf	win_height

	WIN_LEFT .85						; full dive menu width
	movlw	.159-.85+.1
	movwf	win_width+0
	clrf	win_width+1

	clrf	win_color1					; fill with black
	clrf	win_color2

	goto	TFT_box						; and return

;-----------------------------------------------------------------------------
; Display the deco plan (simulator).
; Inputs: char_O_deco_table (array of stop times, in minutes)
;         decoplan_page = page number.
;
deco_show_plan_page:
	bcf		win_invert					; reset invert flag

	;---- Are there deco stops ? ------------------------------------------
	movff	char_O_first_deco_depth,WREG
	iorwf	WREG
	bnz		deco_plan_show_1

	;---- No Deco --------------------------------------------------------
	call	TFT_standard_color
	TEXT_SMALL .80, .0, tNoDeco

	; output of remaining NDL time
	WIN_SMALL	.80, .50				; same line as bottom time
	movff	char_O_nullzeit,lo			; remaining NDL at end of bottom time
	output_8
	PUTC	"'"
	PUTC	" "
	STRCAT_TEXT_PRINT tNDLleft			; "left"

	bsf		decoplan_last_ceiling_shown
	return

deco_plan_show_1:
	lfsr	FSR0,char_O_deco_depth		; initialize indexed addressing
	lfsr	FSR1,char_O_deco_time

	clrf	decoplan_index				; start with index = 0
	movlw	.24
	movwf	win_top						; and row = 0 at position 24

	; Read stop parameters, indexed by decoplan_index and decoplan_page
	movf	decoplan_page,W				; decoplan_gindex = 6*decoplan_page + decoplan_index
	mullw	.8							; 8 lines/page in deco plan
	movf	decoplan_index,W
	addwf	PRODL,W
	movwf	decoplan_gindex				; --> decoplan_gindex

	bcf		decoplan_last_ceiling_shown	; not done yet...

deco_plan_show_2:
	btfsc	decoplan_gindex,5			; reached table length (32) ?
	bra		deco_plan_show_99			; YES - done

	; Read stop parameters, indexed by decoplan_index
	movf	decoplan_gindex,W			; index
	movff	PLUSW0,lo					; char_O_deco_depth[gindex]
	movff	PLUSW1,hi					; char_O_deco_time [gindex]
	movf	lo,W
	bz		deco_plan_show_99			; depth == 0 : done

	; Display the stop line
	rcall	deco_plan_show_stop

	; Next
	movlw	.24
	addwf	win_top,F					; row: += 24
	incf	decoplan_index,F			; local index += 1
	incf	decoplan_gindex,F			; global index += 1

	; Max number of lines/page reached ?
	movlw	.8							; 8 lines/page in deco plan
	cpfseq	decoplan_index
	bra		deco_plan_show_2			; NO - loop

	; Check if next stop is end-of-list ?
	movf	decoplan_gindex,W
	movf	PLUSW0,W					; char_O_deco_depth[gindex]
	bz		deco_plan_show_99			; end of list

	; Display the message "more..."
	rcall	deco_plan_show_clear_bottom	; clear from next line

	call	TFT_standard_color
	TEXT_SMALL .88, .220, tMore
	return

deco_plan_show_99:
	bsf		decoplan_last_ceiling_shown ; nothing more in table to display
	rcall	deco_plan_show_clear_bottom ; clear from next line
	return

;-----------------------------------------------------------------------------
; Loop to show all pages of the deco plan (surface mode)

	global	deco_show_plan
deco_show_plan:
	clrf	decoplan_page
	call	TFT_ClearScreen
	WIN_COLOR color_greenish
	btfsc	FLAG_bailout_mode
	bra		deco_show_plan_bail_title
	TEXT_SMALL .1,.1, tDivePlan
	bra		deco_show_plan2
deco_show_plan_bail_title:
	TEXT_SMALL .1,.1, tDiveBailout
deco_show_plan2:
	call	TFT_standard_color
	;---- Display Plan Parameters
	WIN_SMALL .0,.25
	STRCPY	"Int.:"
	movff	char_I_dive_interval,lo
	bsf		leftbind
	output_8
	bcf		leftbind
	STRCAT_PRINT "'"
	WIN_SMALL .0,.50
	STRCPY_TEXT tBtTm_short
	movff	char_I_bottom_time,lo
	bsf		leftbind
	output_8
	bcf		leftbind
	STRCAT_PRINT "'"
	WIN_SMALL .0,.75
	STRCPY_TEXT tDepth
	PUTC	":"
	movff	char_I_bottom_depth,lo
	bsf		leftbind
	output_8
	bcf		leftbind
	STRCAT_PRINT "m"
	WIN_SMALL .0,.105								; set position for warnings or sat/dsat factors

	;---- Check for Stop Table Overflow
	btfss	decoplan_warnings,stoptable_overflow	; check if we have a overflow warning
	bra		deco_show_plan2a						; NO  - skip
	;---- Display Overflow warning
	call	TFT_warnings_color						; YES - show overflow warning
	STRCAT_PRINT "incomplete"						; max 10 characters
	bra		deco_show_plan_m1						; skip displaying sat/dsat factors

deco_show_plan2a:
	;---- Check for IBCD Warning
	btfss	decoplan_warnings,IBCD_warning_lock		; check if we have a locked IBCD warning
	bra		deco_show_plan2b						; NO  - skip
	;---- Display IBCD warning
	call	TFT_attention_color						; YES - show IBCD warning
	STRCAT_PRINT "IBCD!"							; max 10 characters
	bra		deco_show_plan_m1						; skip displaying sat/dsat factors

deco_show_plan2b:
	;---- Display Sat/Desat Factors --> omitted if there were warnings
	STRCAT_PRINT "SD:"
	WIN_SMALL .25,.105
	movff	char_I_saturation_multiplier,lo
	output_8
	STRCAT	"/"
	movff	char_I_desaturation_multiplier,lo
	output_8
	STRCAT_PRINT ""

deco_show_plan_m1:
	call	TFT_standard_color				; clean-up from warnings

	;---- get Model
	movff	char_I_deco_model,WREG
	iorwf	WREG
	bz		deco_show_plan_m2

	;---- Display GF low/high values
	WIN_SMALL .0,.130
	STRCAT_PRINT "GF:"
	WIN_SMALL .25,.130
	movff	char_I_GF_Low_percentage,lo
	output_8
	STRCAT	"/"
	movff	char_I_GF_High_percentage,lo
	output_8
	STRCAT_PRINT ""

deco_show_plan_m2:
	;---- Display Deco Mode
	WIN_SMALL .0,.155
	lfsr	FSR2,buffer
	movff	opt_dive_mode,lo				; 0=OC, 1=CC, 2=Gauge, 3=Apnea, 4=PSCR
	call	TFT_display_decotype_surface1
	btfss	FLAG_ccr_mode					; current dive mode = CCR ?
	bra		deco_show_plan2c				; NO  - branch
	WIN_SMALL .25,.155
	STRCPY	"SP:"							; output setpoint used for calculation
	movff	opt_sim_setpoint_number,lo
	bsf		leftbind
	output_8
	bcf		leftbind
	STRCAT_PRINT ""

deco_show_plan2c:
	;---- Display TTS result
	WIN_SMALL .0,.180
	STRCPY_TEXT tTTS
	STRCAT	": "
	movff	int_O_ascenttime+0,lo
	movff	int_O_ascenttime+1,hi
	bsf		leftbind
	output_16
	bcf		leftbind
	STRCAT_PRINT "'"

	;---- Display CNS result
	WIN_TOP	.205
	STRCPY_TEXT tCNS2						; "CNS:"
	movff	int_O_CNS_fraction+0,lo
	movff	int_O_CNS_fraction+1,hi
	call	TFT_color_code_cns				; color-code CNS output
	bsf		leftbind
	output_16_3								; limit to 999 and display only (0-999)
	bcf		leftbind
	STRCAT	"%\x92"							; "->"
	movff	int_O_normal_CNS_fraction+0,lo
	movff	int_O_normal_CNS_fraction+1,hi
	call	TFT_color_code_cns				; color-code CNS output
	bsf		leftbind
	output_16_3								; limit to 999 and display only (0-999)
	bcf		leftbind
	STRCAT_PRINT "%"
	call	TFT_standard_color

	;---- Loop through pages
deco_show_plan_1:
	; Clear the complete stop result column:
	WIN_BOX_BLACK .0, .239, .80, .159		; top, bottom, left, right

	rcall	deco_show_plan_page
	incf	decoplan_page,F
	call	logbook_preloop_tasks
deco_show_plan_2:
	btfsc	switch_right
	bra		deco_show_plan_3
	btfsc	switch_left
	return									; return to simulator menu
	call	log_screendump_and_onesecond	; check if we need to make a screen shot and check for new second
	btfsc	sleepmode						; timeout?
	goto	restart
	bra		deco_show_plan_2

deco_show_plan_3:
	btfss	decoplan_last_ceiling_shown
	bra		deco_show_plan_1
	; all stops shown

;----in CCR and pSCR mode, compute a BAILOUT deco plan -----------------------
	movff	char_O_deco_status,WREG			; get deco calculation status
	btfss	WREG,DECO_MODE_LOOP_FLAG		; check if in CCR or pSCR mode
	bra		simulator_show_decoplan5_0		; NO  - normal OC mode: just display
	bsf		FLAG_bailout_mode				; YES - redo 2nd deco-plan in bailout mode
	rcall	deco_planer_redo				;       redo plan computation

	btfss	decoplan_abort					; shall we abort?
	bra		deco_show_plan					; NO  - display bailout stops
	return									; YES


;---- in OC+BAIL modes, show the gas usage special page -----------------------
simulator_show_decoplan5_0:
	; Clear the complete stop result column:
	WIN_BOX_BLACK .0, .239, .80, .159		; top, bottom, left, right

	movlw	.25
	movwf	row_pos							; row for gas list is .25+.25
	clrf	gas_counter						; gas counter
	lfsr	FSR0,int_O_ascent_volumes		; initialize indexed addressing

	WIN_LEFT .80							; set column
	call	TFT_standard_color

	bcf		FLAG_diluent_setup				; steer gaslist_strcat_gas to use OC gases

simulator_show_decoplan5_loop:
	movff	gas_counter,PRODL				; copy to PRODL first
	incf	gas_counter,F					; increment gas #

	movff	gas_counter,WREG				; copy current gas to WREG for color-coding
	call	TFT_color_code_gas				; set output color according to gas (1-5)

	lfsr	FSR2,buffer
	bsf		short_gas_decriptions
	bsf		divemode						; tweak "customview_show_mix:"
	call	gaslist_strcat_gas				; input: PRODL : gas number (0..4), Output: "Nxlo", "Txlo/hi", "Air" or "O2" into Postinc2
	bcf		divemode						; tweak "customview_show_mix:"

	movlw	.25
	addwf	row_pos,F						; increase row position
	movff	row_pos,win_top					; set row

	movff	POSTINC0,lo						; read (16bit) result, low first,
	movff	POSTINC0,hi						; then high

	movf	lo,W
	andwf	hi,W
	incf	WREG							; > 65535 ?
	bnz		simulator_show_decoplan5_1		; NO
	STRCAT_PRINT ">65500"					; YES
	bra		simulator_show_decoplan5_2

simulator_show_decoplan5_1:
	PUTC	":"
	bsf		leftbind
	output_16								; no decimal anymore
	bcf		leftbind
	STRCAT_PRINT ""

	; Loop for all 5 gas
simulator_show_decoplan5_2:
	movlw	d'5'							; list all five gases
	cpfseq	gas_counter						; all gases shown?
	bra		simulator_show_decoplan5_loop	; NO - loop

	WIN_COLOR color_greenish

	WIN_SMALL .80,.25
	STRCPY_TEXT tGasUsage					; "Gas Usage"
	STRCAT_PRINT ":"

	WIN_SMALL .120,.175
	STRCPY_TEXT_PRINT tLiterLong			; "Liter"

	call	TFT_standard_color
	call	logbook_preloop_tasks

simulator_show_decoplan5_3:
	btfss	switch_right
	bra		simulator_show_decoplan5_3a
	bcf		switch_right
	clrf	decoplan_page
	bra		deco_show_plan_1				; toggle between stops plan and gas usage
simulator_show_decoplan5_3a:
	btfss	switch_left
	bra		simulator_show_decoplan5_4
	bcf		FLAG_bailout_mode				; back to normal
	return									; return to simulator menu

simulator_show_decoplan5_4:
	call	log_screendump_and_onesecond	; check if we need to make a screen shot and check for new second
	btfsc	sleepmode						; timeout?
	goto	restart
	bra		simulator_show_decoplan5_3

	END