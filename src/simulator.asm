;=============================================================================
;
;   File simulator.asm								REFACTORED VERSION V2.95a1
;
;   Decoplan interface to C model code.
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;  2011-07-09 : [jDG] Creation...

#include "hwos.inc"						; Mandatory include
#include "convert.inc"                  ; output_*
#include "shared_definitions.h"         ; Mailbox from/to p2_deco.c
#include "strings.inc"                  ; STRCPY,...
#include "tft.inc"                      ; WIN_LEFT,...
#include "wait.inc"                     ; speed_*
#include "start.inc"
#include "divemode.inc"
#include "math.inc"
#include "eeprom_rs232.inc"
#include "tft_outputs.inc"
#include "gaslist.inc"

gui     CODE

    extern  deco_clear_tissue
    extern  deco_push_tissues_to_vault
    extern  deco_calc_dive_interval
    extern  deco_calc_hauptroutine
    extern  deco_pull_tissues_from_vault
    extern  TFT_display_decotype_surface1
	extern	get_first_dil_to_WREG
	extern	get_first_gas_to_WREG
	extern	setup_dil_registers
	extern	setup_gas_registers
	extern	deco_setup_cc_diluents
	extern	deco_setup_oc_gases


    extern  log_screendump_and_onesecond, logbook_preloop_tasks
    extern  do_planner_menu

;---- Private temp variables -------------------------------------------------

	CBLOCK  tmp+0x12                ; Reserved space for word processor and convert
		decoplan_index              ; within each page
		decoplan_gindex             ; global index
		decoplan_last               ; Depth of last stop (CF#29)
		decoplan_flags              ; Various private flags.
		decoplan_page               ; page number
		decoplan_warnings			; deco engine warnings (ex reserved to tmp+0x18...)
	ENDC
		
;---- Defines ----------------------------------------------------------------

#define decoplan_last_ceiling_shown	decoplan_flags,0
#define	decoplan_abort				decoplan_flags,1

;---- Demo deco planner ------------------------------------------------------
	global  do_demo_planner

do_demo_planner:
	btfsc	FLAG_gauge_mode				; =1: In Gauge mode
	goto	do_planner_menu
	btfsc	FLAG_apnoe_mode				; =1: In Apnea mode
	goto	do_planner_menu
	bcf		decoplan_abort				; initialize (clear) abort flag
	bcf		is_bailout					; clear bailout condition (may have remained set from last invocation)
	rcall	deco_planer
	btfss	decoplan_abort				; skip recall deco_show_plan if calculations were aborted
	rcall	deco_show_plan
	goto	do_planner_menu


	global	deco_setup
deco_setup:
	banksel	common
	btfsc	FLAG_ccr_mode
	bra		deco_setup_cc
	btfsc	FLAG_pscr_mode
	bra		deco_setup_cc
deco_setup_oc:
	call    get_first_gas_to_WREG			; gets first gas (1-5) into WREG
    call	setup_gas_registers				; with WREG=Gas 1-5
	call	deco_setup_oc_gases				; setup OC/Bailout Gases and configure for OC deco calculation
	bra		deco_setup_cont
deco_setup_cc:
    call    get_first_dil_to_WREG           ; gets first gas (1-5) into WREG
    call	setup_dil_registers				; with WREG=Gas 1-5
	call	deco_setup_cc_diluents			; setup CCR/pSCR diluents and configure for CCR/pSCR deco calculation
deco_setup_cont:
	; use ambient conditions for simulation ## V2.94
	#include    "isr.inc"
	SAFE_2BYTE_COPY last_surfpressure_30min, int_I_pres_surface	; copy surface pressure to deco routine
	
	movlw	deco_distance
	movff	WREG,char_I_deco_distance

	movff	opt_last_stop,char_I_depth_last_deco
	movff	opt_GF_low,char_I_GF_Low_percentage
	movff	opt_GF_high,char_I_GF_High_percentage
	
	; overwrite GF if aGF is wanted
	bsf		use_agf
	TSTOSS	opt_sim_use_aGF
	bcf		use_agf

	btfsc	use_agf					; =1: Use aGF
	movff	opt_aGF_low,char_I_GF_Low_percentage
	btfsc	use_agf					; =1: Use aGF
	movff	opt_aGF_high,char_I_GF_High_percentage

	bcf		is_bailout
	
	; setup char_I_const_ppO2 for CC modes
	clrf	WREG
	btfsc	FLAG_pscr_mode
	movff	WREG,char_I_const_ppO2			; configure pSCR computations to calculated ppO2
	btfss	FLAG_ccr_mode
	return									; done if not in CCR mode
	movff	opt_sim_setpoint_number,WREG	; configure CCR computations to selected setpoint
	decf    WREG,W							; 1-5 -> 0-4
	lfsr    FSR1,char_I_setpoint_cbar		; load base address of setpoint list
	movff   PLUSW1,char_I_const_ppO2		; setup setpoint
	return
	
;=============================================================================
; Launch deco planning
; 
		global  deco_planer
deco_planer:
        call    speed_fastest				; Quick !
		call    deco_push_tissues_to_vault
        rcall   deco_setup					; Setup all model parameters.

;---- Specific settings ------------------------------------------------------

		; configure the deco engine for normal plan, CNS & gas volume calculation and no delayed ascent
		movff	char_O_deco_status,WREG		; bank-safe copy
		bcf		WREG,DECO_PLAN_FLAG			; normal plan mode,
		bsf		WREG,DECO_CNS_FLAG			; enable CNS calculation (CNS at end of dive),
		bsf		WREG,DECO_VOLUME_FLAG		; enable gas volume calculation, and
		bcf		WREG,DECO_ASCENT_FLAG		; disable delayed ascent calculation
		movff	WREG,char_O_deco_status		; bank-safe copy back

		; configure the deco engine for total-dive gas volume calculation
		movff	char_O_main_status,WREG		; bank-safe copy
		bsf		WREG,DECO_BOTTOM_FLAG		; set bottom flag
		movff	WREG,char_O_main_status		; bank-safe copy back

deco_planer_redo:

		; show deco calculation is in progress
		call	TFT_ClearScreen
        WIN_COLOR	color_greenish
		TEXT_SMALL	.20,.40, tCalculating
		WIN_COLOR	color_lightblue
		WIN_SMALL	.1,.215
		STRCPY_TEXT_PRINT  tAbort

		; configure the deco engine for restart:
		movff	char_O_deco_status,WREG		; bank-safe copy
		bsf		WREG,DECO_STATUS_0_FLAG		; configure init ...
		bsf		WREG,DECO_STATUS_1_FLAG		; ... state,
		movff	WREG,char_O_deco_status		; bank-safe copy back

;---- Add delay at surface, if needed ----------------------------------------
		
		banksel	char_I_dive_interval
        tstfsz  char_I_dive_interval
        call    deco_calc_dive_interval

;---- Dive loop --------------------------------------------------------------

        ; Compute dive ambient conditions
        banksel char_I_bottom_depth
        movf    char_I_bottom_depth,W
        mullw   .100
        movlw   LOW(.1000)
        addwf   PRODL,W
        movwf   int_I_pres_respiration+0
        movlw   HIGH(.1000)
        addwfc  PRODH,W
        movwf   int_I_pres_respiration+1
		
		banksel common

		movff	char_I_bottom_time,char_I_sim_advance_time
		
        clrf    TMR5L
        clrf    TMR5H                   	; 30,51757813µs/bit in TMR5L:TMR5H

        call    deco_calc_hauptroutine  	; initialization + complete bottom time part
        banksel common
		
;---- BAILOUT: Switch to OC gases for ascent cycles --------------------------

        btfss   is_bailout              	; Doing a bailout deco plan ?
        bra     deco_planer_finishing   	; NO  - keep gases
											; YES - switch to OC gas 

		; reconfigure the deco engine for delayed ascent mode
		movff	char_O_deco_status,lo		; bank-safe copy
		bsf		lo,DECO_ASCENT_FLAG			; set flag for delayed ascent calculation
		movff	lo,char_O_deco_status		; bank-safe copy back

		; configure the deco engine for delayed ascent part gas volume calculation
		movff	char_O_main_status,WREG		; bank-safe copy
		bcf		WREG,DECO_BOTTOM_FLAG		; set bottom flag
		movff	WREG,char_O_main_status		; bank-safe copy back

		; reconfigure gas settings to OC gases
		call    get_first_gas_to_WREG		; get first gas (1-5) into WREG
		call	setup_gas_registers			; With WREG=Gas 1-5 (or 6, not applicable here)
		call	deco_setup_oc_gases			; With WREG=Gas 1-5 (or 6, not applicable here)
		
		; set the gas change override flag to allow gas changes before deco stops as done in alternative plan
		movff	char_O_main_status,lo		; bank-safe copy
		bsf		lo,DECO_GASCHANGE_OVRD		; set flag for gas change override
		movff	lo,char_O_main_status		; bank-safe copy back

;---- Wait until status reaches zero -------------------------------------------

deco_planer_finishing:
        call    deco_calc_hauptroutine  	; Simulate more dive time to trigger the deco calculations
		banksel	common
		
		btfss	switch_left					; check if left button was pressed
		bra		deco_planer_finishing_1		; NO  - continue calculations
		bsf		decoplan_abort				; YES - set abort flag so that deco_show_plan will not be called
		bra		deco_planer_finishing_2		;       do some clean-up and return
deco_planer_finishing_1:
		movff	char_O_deco_status,lo		; working copy of char_O_deco_status in bank common
		movlw	DECO_STATUS_MASK			; bit mask for deco status bit set
		andwf	lo,W						; mask out bits showing state of computation
		tstfsz	WREG						; check if a compute cycle is finished (bits 1 and 0 == 0)
		bra		deco_planer_finishing		; NO - needs more computation cycles

;---- Done: add CNS from decoplan, and restore tissues

deco_planer_finishing_2:

	movff	char_O_deco_warnings,decoplan_warnings	; copy warnings
		
        call    deco_pull_tissues_from_vault			; restore "real" deco data
        banksel common                  				; back to bank 1

	movlw	b'00111000'								; 1:8 Prescaler -> 65,536ms@16MHz
	movwf	T3CON
        goto	speed_normal	    ;(and return)

;-----------------------------------------------------------------------------
; Draw a stop of the deco plan (simulator or dive).
; Inputs: lo      = depth. Range 3m...93m
;                 + 0x80 if this is a switch-gas stop.
;         up      = minutes. range 1'..240'.
;         win_top = line to draw on screen.
; Trashed: up, lo, win_height, win_leftx2, win_width, win_color*,
;          WREG, PROD, TBLPTR TABLAT.
;
deco_plan_show_stop:

		;---- Print depth ----------------------------------------------------
		bcf     lo,7					; clear gas-switch flag (not used any more anyhow)
		lfsr	FSR2,char_O_deco_gas
		movf    decoplan_gindex,W		; index
    	movff	PLUSW2,WREG				; get current gas
		rcall	simulator_color_gas		; set output color dependent on gas (1-5)

	    lfsr	FSR2,buffer

		TSTOSS  opt_units				; 0=Meters, 1=Feets
		bra		deco_plan_show_nstd_stop_metric

        WIN_LEFT .85
		movf	lo,W					; lo = m
		mullw	.100					; PRODL:PRODH = mbar
		movff	PRODL,lo
		movff	PRODH,hi
		; Convert with 334feet/100m to have 10ft, 20ft, 30ft stops...
		movff	lo,xA+0
		movff	hi,xA+1
		movlw	LOW 	d'334'          ; 334feet/100m
		movwf	xB+0
		movlw	HIGH 	d'334'
		movwf	xB+1
		call	mult16x16			    ; xA*xB=xC (lo:hi * 328)
		movlw	d'50'                   ; round up
		addwf	xC+0,F
		movlw	0
		addwfc	xC+1,F
		addwfc	xC+2,F
		addwfc	xC+3,F
		movlw	d'100'					
		movwf	xB+0
		clrf	xB+1
		call	div32x16  			    ; xC:4 / xB:2 = xC+3:xC+2 with xC+1:xC+0 as remainder
		movff	xC+0,lo
		movff	xC+1,hi				    ; restore lo and hi with updated value
		bsf		leftbind
		bsf		ignore_digit4			; Only full feet
		output_16
		bcf     leftbind
		STRCAT_PRINT	"ft "
		bra		deco_plan_show_nstd_stop_common

deco_plan_show_nstd_stop_metric:
        WIN_LEFT .90
	    bsf     leftbind
	    output_8					    ; outputs into Postinc2!
		bcf     leftbind
        STRCAT_PRINT 	"m "
deco_plan_show_nstd_stop_common:
        ;---- Print duration -------------------------------------------------
	    WIN_LEFT	.135
	    lfsr	FSR2,buffer
	    
	    movf    lo,W                    ; Swap up & lo
	    movff   up,lo
	    movwf   up

	    output_8					    ; Allow up to 240'
        STRCAT       "'  "              ; 1 to 3 chars for depth.
        clrf    WREG
        movff   WREG,buffer+.3          ; limit to 4 chars
        STRCAT_PRINT 	""

	    movf    lo,W                    ; Swap back up & lo
	    movff   up,lo
	    movwf   up

        ;---------------------------------------------------------------------
        ; Draw the bar graph used for deco stops (deco plan in simulator or dive).
        incf   win_top,F
        movlw	.19
        movwf   win_height
        movlw	.118
        movwf	win_leftx2    		    ; column left (0-159)
        movlw	.16
        movwf	win_width+0    		    ; column max width.
		clrf    win_width+1

        ; Draw used area (up = minutes):
        movlw	.16                     ; Limit length (16min)
        cpfslt	up
        movwf	up
        movff	up,win_bargraph         ; Active width, the rest is cleared.
        call	TFT_box

        ; Restore win_top
	    call    TFT_standard_color
        decf    win_top,F               ; Restore win_top
        return

;-----------------------------------------------------------------------------
; Clear unused area below last stop
; Inputs: win_top : last used area...
deco_plan_show_clear_bottom:
        movf    win_top,W               ; Get back from bank0
        sublw   .239                    ; No: bottom row in planning
        movwf   win_height

        WIN_LEFT .85                    ; Full dive menu width
        movlw   .159-.85+1
        movwf   win_width+0
		clrf    win_width+1

        clrf    win_color1              ; Fill with black
        clrf    win_color2

        goto	TFT_box		    		; and return

;-----------------------------------------------------------------------------
; Display the deco plan (simulator).
; Inputs: char_O_deco_table (array of stop times, in minutes)
;         decoplan_page = page number.
;
deco_show_plan_page:
        bcf     win_invert              ; Reset invert flag

        ;---- Is there deco stops ? ------------------------------------------
    	movff   char_O_first_deco_depth,WREG
    	iorwf   WREG
        bnz		deco_plan_show_1

        ;---- No Deco --------------------------------------------------------
    	call    TFT_standard_color
        TEXT_SMALL   .80, .0, tNoDeco
        bsf     decoplan_last_ceiling_shown
        return

deco_plan_show_1:
    	lfsr	FSR0,char_O_deco_depth  ; Initialize indexed addressing.
	    lfsr	FSR1,char_O_deco_time

        clrf    decoplan_index          ; Start with index = 0
        clrf	win_top                 ; and row = 0

        ; Read stop parameters, indexed by decoplan_index and decoplan_page
        movf    decoplan_page,W         ; decoplan_gindex = 6*decoplan_page + decoplan_index
        mullw   .8                      ; 8 lines/page in deco plan
        movf    decoplan_index,W
        addwf   PRODL,W
        movwf   decoplan_gindex         ; --> decoplan_gindex

        bcf     decoplan_last_ceiling_shown   ; Not finished yet...

deco_plan_show_2:
        btfsc   decoplan_gindex,5       ; Reached table length (32) ?
        bra     deco_plan_show_99       ; YES: finished...

        ; Read stop parameters, indexed by decoplan_index
        movf    decoplan_gindex,W       ; index
    	movff	PLUSW1,up               ; char_O_deco_time [gindex] --> up
	    movff	PLUSW0,lo               ; char_O_deco_depth[gindex]
        movf    lo,W
        bz      deco_plan_show_99       ; depth == 0 : finished.

        ; Display the stop line
    	rcall	deco_plan_show_stop

        ; Next
        movlw   .24
        addwf   win_top,F				; row: += 24
	    incf	decoplan_index,F		; local index += 1
	    incf	decoplan_gindex,F		; global index += 1

        ; Max number of lines/page reached ?
    	movlw   .8						; 8 lines/page in deco plan
    	cpfseq	decoplan_index
    	bra		deco_plan_show_2		; NO: loop

    	; Check if next stop is end-of-list ?
    	movf    decoplan_gindex,W
	    movf	PLUSW0,W				; char_O_deco_depth[gindex]
    	bz      deco_plan_show_99		; End of list...

        ; Display the message "more..."
        rcall   deco_plan_show_clear_bottom  ; Clear from next line

    	call    TFT_standard_color
        TEXT_SMALL .88, .220, tMore
        return

deco_plan_show_99:
        bsf		decoplan_last_ceiling_shown ; Nothing more in table to display.
        rcall   deco_plan_show_clear_bottom ; Clear from next line
        return

;-----------------------------------------------------------------------------
; Loop to show all pages of the deco plan (surface mode)

        global  deco_show_plan
deco_show_plan:
        clrf    decoplan_page
        call    TFT_ClearScreen
        WIN_COLOR   color_greenish
		btfsc	is_bailout
		bra	deco_show_plan_bail_title
        TEXT_SMALL  .1,.1, tDivePlan
		bra	deco_show_plan2
deco_show_plan_bail_title:	
		TEXT_SMALL  .1,.1, tDiveBailout
deco_show_plan2:
		call    TFT_standard_color
        ;---- Display Plan Parameters
        WIN_SMALL   .0,.25
        STRCPY  "Int:"
        movff   char_I_dive_interval,lo
        bsf     leftbind
        output_8
		bcf     leftbind
        STRCAT_PRINT  "'"
        WIN_SMALL   .0,.50
        STRCPY_TEXT tBtTm_short
        movff   char_I_bottom_time,lo
        bsf     leftbind
        output_8
		bcf     leftbind
        STRCAT_PRINT  "'"
        WIN_SMALL   .0,.75
        STRCPY_TEXT tDepth
        PUTC    ":"
        movff   char_I_bottom_depth,lo
        bsf     leftbind
        output_8
		bcf     leftbind
        STRCAT_PRINT  "m"
		
		WIN_SMALL   .0,.105					; set position for warnings or sat/dsat factors
	
		;---- Check for Stop Table Overflow
		btfss	decoplan_warnings,stoptable_overflow	; check if we have a overflow warning
		bra		deco_show_plan2a						; NO  - skip
		;---- Display Overflow warning
		call	TFT_warnings_color						; YES - show overflow warning
		STRCAT_PRINT  "incomplete"						; max 10 characters
		bra		deco_show_plan_m1						; skip displaying sat/dsat factors

deco_show_plan2a:		
		;---- Check for IBCD Warning
		btfss	decoplan_warnings,IBCD_warning_lock		; check if we have a locked IBCD warning
		bra		deco_show_plan2b						; NO  - skip
		;---- Display IBCD warning
		call	TFT_attention_color						; YES - show IBCD warning
		STRCAT_PRINT  "IBCD!"							; max 10 characters
		bra		deco_show_plan_m1						; skip displaying sat/dsat factors
		
deco_show_plan2b:
        ;---- Display Sat/Desat Factors --> is skipped if there were warnings
		STRCAT_PRINT "SD:"
        WIN_SMALL   .25,.105
        movff   char_I_saturation_multiplier,lo
        output_8
        STRCAT  "/"
        movff   char_I_desaturation_multiplier,lo
        output_8
        STRCAT_PRINT  ""

deco_show_plan_m1:
		call	TFT_standard_color			; clean-up from warnings

		;---- Get Model
        movff   char_I_deco_model,WREG
        iorwf   WREG
        bz     deco_show_plan_m2

        ;---- Display GF low/high values
        WIN_SMALL  .0,.130
		STRCAT_PRINT "GF:"
        WIN_SMALL   .25,.130
        movff   char_I_GF_Low_percentage,lo
        output_99x
        STRCAT  "/"
        movff   char_I_GF_High_percentage,lo
        output_99x
        STRCAT_PRINT  ""

deco_show_plan_m2:
		;---- Display Deco Mode
		WIN_SMALL   .0,.155
        lfsr    FSR2,buffer
        movff   opt_dive_mode,lo        	; 0=OC, 1=CC, 2=Gauge, 3=Apnea, 4=PSCR
        call    TFT_display_decotype_surface1
		btfss	FLAG_ccr_mode				; current dive mode = CCR ?
		bra		deco_show_plan2c			; NO  - branch
		WIN_SMALL   .25,.155
        STRCPY  "SP:"						; output setpoint used for calculation
        movff   opt_sim_setpoint_number,lo
        bsf     leftbind
        output_8
		bcf     leftbind
        STRCAT_PRINT  ""

deco_show_plan2c:
        ;---- Display TTS result
        WIN_SMALL   .0,.180
        STRCPY_TEXT tTTS
        STRCAT  ": "
        movff   int_O_ascenttime+0,lo
        movff   int_O_ascenttime+1,hi
        bsf     leftbind
        output_16
		bcf     leftbind
        STRCAT_PRINT "'"

        ;---- Display CNS result
        WIN_TOP     .205
        STRCPY_TEXT tCNS2	; "CNS:"
        movff   int_O_CNS_fraction+0,lo
        movff   int_O_CNS_fraction+1,hi
		TFT_color_code	warn_cns			; Color-code CNS output
		bsf		leftbind
	    output_16_3                     	; limit to 999 and display only (0-999)
		bcf		leftbind
        STRCAT  "%\x92"						; "->"
		movff   int_O_normal_CNS_fraction+0,lo
        movff   int_O_normal_CNS_fraction+1,hi
		TFT_color_code	warn_cns			; Color-code CNS output
		bsf		leftbind
        output_16_3                     	; limit to 999 and display only (0-999)
		bcf		leftbind
        STRCAT_PRINT "%"
		call	TFT_standard_color
       
        ;---- Loop through pages
deco_show_plan_1:
		; Clear the complete stop result column:
		WIN_BOX_BLACK   .0, .239, .80, .159 ; top, bottom, left, right
		
        rcall   deco_show_plan_page
        incf    decoplan_page,F
        call    logbook_preloop_tasks
deco_show_plan_2:
        btfsc   switch_right
        bra     deco_show_plan_3
        btfsc   switch_left
        return                                  ; Return to simulator menu
        call    log_screendump_and_onesecond    ; Check if we need to make a screen shot and check for new second
    	btfsc	sleepmode                       ; Timeout?
        goto    restart
        bra     deco_show_plan_2

deco_show_plan_3:
        btfss   decoplan_last_ceiling_shown
        bra     deco_show_plan_1
        ; All stops shown
       
;---- In CCR and pSCR mode, compute a BAILOUT deco plan -----------------------

    banksel common
	movff	char_O_deco_status,WREG		; get deco calculation status
	btfss	WREG,DECO_MODE_LOOP_FLAG	; check if in CCR or pSCR mode
	bra     simulator_show_decoplan5_0  ; NO  - normal OC mode: just display
    bsf     is_bailout                  ; YES - redo 2nd deco-plan in bailout mode
	rcall   deco_planer_redo            ; 		redo plan computation

	btfss	decoplan_abort				; shall we abort?
    bra     deco_show_plan              ; NO  - display bailout stops
	return								; YES


;---- In OC+BAIL modes, show the gas Usage special page -----------------------
simulator_show_decoplan5_0:    
	
    movlb   .1

    ; Clear the complete stop result column:
    WIN_BOX_BLACK   .0, .239, .80, .159 ; top, bottom, left, right

    movlw	.25
    movwf	waitms_temp                 ; Row for gas list is .25+.25
    clrf	wait_temp                   ; Gas counter
    lfsr	FSR0,int_O_gas_volumes      ; Initialize indexed addressing.

    WIN_LEFT	.80                     ; Set column
    call    TFT_standard_color   

simulator_show_decoplan5_loop:
    movff   wait_temp,PRODL             ; Copy to PRODL first
    incf    wait_temp,F                 ; Increment gas #

	movff	wait_temp,WREG
	rcall	simulator_color_gas			; set output color according to gas (number 1-5 in WREG)

    lfsr    FSR2,buffer
    bsf     short_gas_decriptions
    bsf     divemode                    ; Tweak "customview_show_mix:"
    call    gaslist_strcat_gas          ; Input: PRODL : gas number (0..4), Output: "Nxlo", "Txlo/hi", "Air" or "O2" into Postinc2
    bcf     divemode                    ; Tweak "customview_show_mix:"
    
	movlw	.25
	addwf	waitms_temp,F		        ; Increase row position
	movff	waitms_temp,win_top         ; Set Row

    movff   POSTINC0,lo                 ; Read (16bit) result, low first,
    movff   POSTINC0,hi                 ; then high.

    movf    lo,W
    andwf   hi,W
    incf    WREG						; > 65535? 
    bnz     simulator_show_decoplan5_2	; NO
	STRCAT_PRINT  ">65500"				; YES
    bra     simulator_show_decoplan5_1
    
simulator_show_decoplan5_2: 
    PUTC    ":"
    bsf     leftbind
    output_16                           	; No decimal anymore.
    bcf     leftbind
    STRCAT_PRINT  ""                    	; No unit: can be bars or litters.
    
    ; Loop for all 5 gas
simulator_show_decoplan5_1:
	movlw	d'5'                        	; list all five gases
	cpfseq	wait_temp                   	; All gases shown?
	bra		simulator_show_decoplan5_loop	; No
	
    WIN_COLOR   color_greenish
    WIN_SMALL   .80,.25
	STRCPY_TEXT tGasUsage               	; OC: "Gas Usage"
    STRCAT_PRINT  ":"
    call	TFT_standard_color
    call    logbook_preloop_tasks

simulator_show_decoplan5_3:
	btfss   switch_right
	bra		simulator_show_decoplan5_3a
	bcf		switch_right
	clrf    decoplan_page
	bra		deco_show_plan_1				; toggle between stops plan and gas usage
simulator_show_decoplan5_3a:
    btfss   switch_left						
	bra		simulator_show_decoplan5_4
    bcf     is_bailout                  	; Back to normal
    bcf	    ccr_diluent_setup				; init for OC/Bailout
    return                                  ; Return to simulator menu
	
simulator_show_decoplan5_4:
    call    log_screendump_and_onesecond    ; Check if we need to make a screen shot and check for new second
    btfsc	sleepmode                       ; Timeout?
    goto    restart
    bra     simulator_show_decoplan5_3


simulator_color_gas:				; set output color dependent on gas (1-5, in WREG)
	movwf	tft_temp1				; used in TFT_set_color anyway
	dcfsnz	tft_temp1,F
	movlw	color_white				; color for Gas 1
	dcfsnz	tft_temp1,F
	movlw	color_green				; color for Gas 2
	dcfsnz	tft_temp1,F
	movlw	color_red				; Color for Gas 3
	dcfsnz	tft_temp1,F
	movlw	color_yellow			; color for Gas 4
	dcfsnz	tft_temp1,F
	movlw	color_cyan				; color for Gas 5
	goto	TFT_set_color			; set color and return...
	
;=============================================================================
;
        global  do_demo_divemode
do_demo_divemode:
		extern	option_save_all
		call	option_save_all				; Save all settings into EEPROM before starting simulation
 		call    deco_push_tissues_to_vault
        banksel common                  	; Bank1

		; +++ COMMENTED OUT FOR TESTING PURPOSE ONLY !!! +++
		; +++ DO NOT COMMENT OUT IN OPERATIONAL USE  !!! +++
		bsf	restore_deco_data			; Restore tissue and CNS after simulator use

		bcf	pressure_refresh
		btfss	pressure_refresh			; Wait for sensor
		bra	$-2

		bsf	simulatormode_active			; Set Flag
        ; Compute dive ambient conditions
        banksel char_I_bottom_depth
        movf    char_I_bottom_depth,W
        mullw   .100
        movff   PRODL,rel_pressure+0
        movff   PRODH,rel_pressure+1
        movlw   LOW(.1000)
        addwf   PRODL,W
        movff   WREG,sim_pressure+0
        movlw   HIGH(.1000)
        addwfc  PRODH,W
        movff   WREG,sim_pressure+1

        banksel common                  	; Bank1
		bsf		divemode
		goto	diveloop					; Switch into Divemode!


        END