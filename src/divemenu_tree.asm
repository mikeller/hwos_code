;=============================================================================
;
;   File divemenu_tree.asm							REFACTORED VERSION V2.96a
;
;   OSTC dive mode menu
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================
; HISTORY
;   2013-02-02 : [mH] Made out of menu_tree.asm

#include    "hwos.inc"                  ; Mandatory header
#include    "menu_processor.inc"
#include 	"shared_definitions.h"      ; Mailbox from/to p2_deco.c
#include    "tft_outputs.inc"
#include    "customview.inc"
#include    "strings.inc"
#include    "calibrate.inc"


divegui     CODE
;=============================================================================
; Main Menu
	global  do_main_divemenu
do_main_divemenu:
	call	menu_processor_reset		; restart from first icon.

do_continue_main_divemenu:
	call	menu_processor_pop			; drop exit line.
	call	menu_processor_pop			; drop exit line.

	btfsc	FLAG_ccr_mode
	bra		main_divemenu_loop			; goto CCR / pSCR Menu menu
	btfsc	FLAG_pscr_mode
	bra		main_divemenu_loop			; goto CCR / pSCR Menu menu

main_divemenu_OC:	
	bcf		ccr_diluent_setup
	bcf		is_bailout_menu
	movlw	.1
	movwf	menupos						; Set to first option in divemode menu
	
	MENU_BEGIN  tMainMenu, .5
		MENU_CALL   tDivemenu_Gaslist,  do_divemode_gaslist
		MENU_CALL   tDivemenu_ResetAvg, do_reset_average
		MENU_CALL   tDivemenu_ToggleGF, do_toggle_gf
		MENU_CALL   tDivemenu_Marker,   do_set_marker
		MENU_CALL   tExit,              do_exit_divemode_menu
	MENU_END

main_divemenu_loop:
    bsf     ccr_diluent_setup			; default to operations on diluents
	bcf		is_bailout_menu				; default to none-bailout menu
    movlw   .1
    movwf   menupos						; Set to first option in divemode menu
    
    btfsc   FLAG_pscr_mode
    bra     main_divemenu_pscr			; PSCR Menu
    
    MENU_BEGIN  tMainMenu, .6
        MENU_CALL   tDiveBailout,       do_divemode_gaslist_bail
        MENU_CALL   tDivemenu_Setpoint, do_divemode_splist
        MENU_CALL   tDivemenu_Gaslist,  do_divemode_gaslist
        MENU_CALL   tDivemenu_ResetAvg, do_reset_average
        MENU_CALL   tDivemenu_ToggleGF, do_toggle_gf
        MENU_CALL   tExit,              do_exit_divemode_menu
    MENU_END
    
main_divemenu_pscr:
    movf    hardware_flag,W
    sublw   0x11						; 2 with BLE
    btfsc   STATUS,Z
    bra     main_divemenu_pscr_no_sensors
	movf    hardware_flag,W
    sublw   0x13						; +
    btfsc   STATUS,Z
    bra		main_divemenu_pscr_no_sensors

    MENU_BEGIN  tMainMenu, .6
        MENU_CALL   tDiveBailout,       do_divemode_gaslist_bail
		MENU_CALL   tCCRSensor,			do_divemode_setpoint_pscr
        MENU_CALL   tDivemenu_Gaslist,  do_divemode_gaslist
        MENU_CALL   tDivemenu_ResetAvg, do_reset_average
        MENU_CALL   tDivemenu_ToggleGF, do_toggle_gf
        MENU_CALL   tExit,              do_exit_divemode_menu
    MENU_END

main_divemenu_pscr_no_sensors:
    MENU_BEGIN  tMainMenu, .6
        MENU_CALL   tDiveBailout,       do_divemode_gaslist_bail
        MENU_CALL   tDivemenu_Gaslist,  do_divemode_gaslist
        MENU_CALL   tDivemenu_ResetAvg, do_reset_average
        MENU_CALL   tDivemenu_ToggleGF, do_toggle_gf
		MENU_CALL   tDivemenu_Marker,   do_set_marker
        MENU_CALL   tExit,              do_exit_divemode_menu
    MENU_END
  

do_toggle_gf:
	movff	char_I_deco_model,WREG  	; 0 = ZH-L16, 1 = ZH-L16-GF
	decfsz	WREG,W		    			; Toggle GF only in GF modes - in GF mode?
	bra		do_continue_main_divemenu   ; No, do nothing and return
	TSTOSS  opt_enable_aGF          	; =1: aGF can be selected underwater
    bra     do_continue_main_divemenu   ; No, do nothing and return
	movlw	.4						    ; Set customview to 5 (GF informations)
	movwf	menupos3					; Customview to come-1
	bsf		toggle_customview			; Set flag, the customview will be toggled very soon now...
	movlw	.1
	movwf	menupos						; Set to first option in divemode menu
	
    MENU_BEGIN  tDivemenu_ToggleGF, .2
        MENU_CALL       tDivemenu_ToggleGF,     do_togglegf
        MENU_CALL       tExit,                  do_continue_main_divemenu
    MENU_END

do_togglegf:
	;TSTOSS	opt_enable_aGF				; =1: aGF can be selected underwater  ## check is now done before entering menu
	;bra	do_exit_divemode_menu		; continue with exiting menu code
	bsf		toggle_gf					; Set flag...
	bra		do_exit_divemode_menu		; continue with exiting menu code
  
  
do_set_marker:
	movlw	d'6'						; Type of Alarm (Manual Marker)
	movwf	AlarmType					; Copy to Alarm Register
	bsf		event_occured				; Set Event Flag
    bra     do_exit_divemode_menu		; And exit

	
do_reset_average:
    bsf     reset_average_depth			; Set Flag
    bra     do_exit_divemode_menu   	; continue with exiting menu code

	
do_switch_sensor:						; entry point when coming from switch to sensor
    movlw   .1                      	; Switch to Sensor
    movff   WREG,opt_ccr_mode       	; =0: Fixed SP (CCR) / calculated (pSCR), =1: Sensor,  =2: Auto SP
	bra     do_switch_sp_com			; continue with common part
	
do_switch_sp:							; entry point when coming from manual setpoint selection (CCR)
    decf    menupos,W         			; 1-5 -> 0-4
    lfsr    FSR1,char_I_setpoint_cbar
    movff   PLUSW1,char_I_const_ppO2	; setup fixed setpoint
    movff   char_I_const_ppO2,WREG
    call    transmit_setpoint			; tansmit current setpoint from WREG (in cbar) to external electronics
	bcf		setpoint_fallback			; clear fallback condition (stops fallback warning)
	clrf	WREG						; Switch to fixed SP
	movff	WREG,opt_ccr_mode			; =0: Fixed SP (CCR) / calculated (pSCR), =1: Sensor, =2: Auto SP
	bra		do_switch_sp_com

do_switch_sp_calc:						; entry point when coming from switch to calculated ppO2 (pSCR)
	bcf		setpoint_fallback			; clear fallback condition (stops fallback warning)
    clrf    WREG                    	; Switch to fixed SP
    movff   WREG,opt_ccr_mode       	; =0: Fixed SP (CCR) / calculated (pSCR), =1: Sensor,  =2: Auto SP
	movff	WREG,char_I_const_ppO2		; set setpoint to 0, this forces deco engine to take the computed ppO2

do_switch_sp_com:						; merge point to common part
    bsf		event_occured				; set global event byte
    bsf     setpoint_changed			; set flag (for profile)

    ; Clear some flags in case we were in bailout before...
    bcf     is_bailout              	; end bailout mode
    ;bcf     is_bailout_menu         	; not needed
    bcf	    better_gas_available    	; =1: A better gas is available and a gas change is advised in divemode
    bcf     blinking_better_gas     	; clear blinking flag
    call    customview_mask         	; update customview mask to (eventually) rewrite ppO2(Dil): to ppO2:
	
	movff   active_diluent,menupos		; reconfigure last diluent (menupos is transfer register for selected gas/diluent towards gas_switched_common:)
	bsf     divemode_gaschange			; initiate reconfiguration to loop mode on last diluent
	
    bra     do_exit_divemode_menu   	; continue with exiting menu code

   
do_divemode_gaslist_bail:				; entry point from CCR/pSCR to bailout to OC gases
	bcf		ccr_diluent_setup       	; switch to OC gases
	bsf		is_bailout_menu         	; flag it is a bailout action
do_divemode_gaslist:					; entry point for switching: OC -> gases, loop -> diluents
	btfsc	is_bailout              	; in bailout mode?
	bcf		ccr_diluent_setup       	; yes - for safety reasons, redirect to OC (bailout) gases
do_divemode_gaslist_com:    
	bsf		short_gas_decriptions
	movlw	.1
	movwf	menupos						; Set to first option in divemode menu
    MENU_BEGIN  tGaslist, .6
        MENU_DYNAMIC    gaslist_strcat_gas_mod, do_switch_gas
        MENU_DYNAMIC    gaslist_strcat_gas_mod, do_switch_gas
        MENU_DYNAMIC    gaslist_strcat_gas_mod, do_switch_gas
        MENU_DYNAMIC    gaslist_strcat_gas_mod, do_switch_gas
        MENU_DYNAMIC    gaslist_strcat_gas_mod, do_switch_gas
        MENU_CALL       tMore,                  do_divemode_gaslist_more
    MENU_END

do_divemode_gaslist_more:
	movlw	.1
	movwf	menupos							; Set to first option in divemode menu
	
	movff	char_I_O2_ratio,gas6_O2_ratio	; initialize gas6 with currently breathed gas - O2 ratio
	movff	char_I_He_ratio,gas6_He_ratio	; initialize gas6 with currently breathed gas - He ratio
	
do_divemode_gaslist_more_loop:
    MENU_BEGIN  tGaslist, .6
        MENU_CALL       tO2Plus,                do_dive_pO2
        MENU_CALL       tO2Minus,               do_dive_mO2
        MENU_CALL       tHePlus,                do_dive_pHe
        MENU_CALL       tHeMinus,               do_dive_mHe
        MENU_DYNAMIC    gaslist_strcat_gas6,    do_switch_gas6
        MENU_CALL       tDivemenu_LostGas,      do_lost_gas
    MENU_END

do_lost_gas:
	movlw	.1
	movwf	menupos							; Set to first option in divemode menu
do_lost_gas_loop:
	bsf		short_gas_decriptions
    MENU_BEGIN  tDivemenu_LostGas, .6
        MENU_DYNAMIC    gaslist_strcat_gas_mod, do_toggle_active    ; Toggle the gas (in)active
        MENU_DYNAMIC    gaslist_strcat_gas_mod, do_toggle_active    ; Toggle the gas (in)active
        MENU_DYNAMIC    gaslist_strcat_gas_mod, do_toggle_active    ; Toggle the gas (in)active
        MENU_DYNAMIC    gaslist_strcat_gas_mod, do_toggle_active    ; Toggle the gas (in)active
        MENU_DYNAMIC    gaslist_strcat_gas_mod, do_toggle_active    ; Toggle the gas (in)active
        MENU_CALL   	tExit,              	do_exit_divemode_menu
    MENU_END


do_switch_gas6:
	movlw   .6							; gas 6
	movwf	menupos						; transfer register for selected gas towards gas_switched_common: 
	bsf		gas6_changed            	; set flag for profile recording
	;bra	do_switch_gas				; continue with common gas-switched code

do_switch_gas:
	bsf		divemode_gaschange			; Set flag, will also trigger restart of deco_engine
	btfsc	is_bailout_menu				; Bailout confirmed?
	bsf		is_bailout					; begin bailout mode
	call	customview_mask				; update custom view mask to (eventually) rewrite ppO2(Dil): to ppO2:
	;bra	do_exit_divemode_menu		; continue with exiting menu code
	
do_exit_divemode_menu:
	extern  timeout_divemode_menu2
	call	timeout_divemode_menu2
	clrf	STKPTR
	extern  diveloop_loop4
	goto	diveloop_loop4


do_toggle_active:
	extern	restart_deco_engine_wo_ceiling
	call	restart_deco_engine_wo_ceiling
    movlw   .5
    btfsc   ccr_diluent_setup			; diluents?
    addwf   menupos,F					; yes 1-5 -> 6-10
    decf    menupos,W					; -> 0-4 for gases / 5-9 for diluents
    lfsr    FSR1,opt_gas_type+0
    movff   PLUSW1,lo
    tstfsz  lo							; Already disabled?
    bra     do_toggle_active2			; No, disable now!
    lfsr    FSR1,opt_gas_type_backup+0	; copy opt_gas_type_backup+W back to opt_gas_type+W
    movff   PLUSW1,lo
    lfsr    FSR1,opt_gas_type+0
    movff   lo,PLUSW1
    lfsr    FSR1,opt_OC_bail_gas_change_backup+0 ; copy opt_OC_bail_gas_change_backup+W back to opt_OC_bail_gas_change+W
    movff   PLUSW1,lo
	lfsr    FSR1,opt_OC_bail_gas_change+0
    movff   lo,PLUSW1
	bra		do_toggle_active3
do_toggle_active2:
    clrf    PLUSW1						; 0=Disabled, 1=First, 2=Travel, 3=Deco
    lfsr    FSR1,opt_OC_bail_gas_change+0
    clrf    PLUSW1						; also delete change depth here to have the menu updated immediately
do_toggle_active3:
    movlw   .5
    btfsc   ccr_diluent_setup			; use OC gases?
    subwf   menupos,F					; Back to 1-5 
    bra     do_lost_gas_loop			; Return to list and show updated result


do_dive_pO2:
	banksel	gas6_O2_ratio
	incf	gas6_O2_ratio,F				; O2++
	movf	gas6_He_ratio,W
	addwf	gas6_O2_ratio,W
	movwf	gas6_temp
	movlw	.101
	cpfslt	gas6_temp					; O2+He<101?
	decf	gas6_O2_ratio,F				; O2-- (Unchanged)
	banksel common
	bra     do_divemode_gaslist_more_loop
				
do_dive_mO2:
	banksel gas6_O2_ratio
	decf    gas6_O2_ratio,F				; O2--
	movlw   gaslist_min_o2
	cpfslt  gas6_O2_ratio
	bra     do_dive_mO2_done
	movlw   gaslist_min_o2
	movwf   gas6_O2_ratio
do_dive_mO2_done:
	banksel common
	bra     do_divemode_gaslist_more_loop

do_dive_pHe:
	banksel gas6_O2_ratio
	incf    gas6_He_ratio,F				; He++
	movf    gas6_He_ratio,W
	addwf   gas6_O2_ratio,W
	movwf   lo
	movlw   .101
	cpfslt  lo							; O2+He<101?
	decf    gas6_He_ratio,F				; Yes, He-- (Unchanged)
	banksel common
	bra     do_divemode_gaslist_more_loop

do_dive_mHe:
	banksel gas6_O2_ratio
	decf    gas6_He_ratio,F				; He--
	bnn     do_dive_mHe_done
	clrf    gas6_He_ratio
do_dive_mHe_done:
	banksel common
	bra     do_divemode_gaslist_more_loop

do_divemode_splist:
	bsf		short_gas_decriptions
	movlw	.1
	movwf	menupos							; Set to first option in divemode menu
	
	movf	hardware_flag,W
	sublw	0x11							; 2 with BLE
	btfsc	STATUS,Z
	bra		do_divemode_splist_no_sensor	; no sensor
	movf	hardware_flag,W
	sublw	0x13							; +
	btfsc	STATUS,Z
	bra		do_divemode_splist_no_sensor	; no sensor

do_divemode_splist_with_sensor:
    MENU_BEGIN  tGaslist, .6
        MENU_DYNAMIC    gaslist_strcat_setpoint, do_switch_sp
        MENU_DYNAMIC    gaslist_strcat_setpoint, do_switch_sp
        MENU_DYNAMIC    gaslist_strcat_setpoint, do_switch_sp
        MENU_DYNAMIC    gaslist_strcat_setpoint, do_switch_sp
        MENU_DYNAMIC    gaslist_strcat_setpoint, do_switch_sp
        MENU_CALL   	tCCRSensor,              do_divemode_sensor
  MENU_END

do_divemode_splist_no_sensor:
    MENU_BEGIN  tGaslist, .5
        MENU_DYNAMIC    gaslist_strcat_setpoint, do_switch_sp
        MENU_DYNAMIC    gaslist_strcat_setpoint, do_switch_sp
        MENU_DYNAMIC    gaslist_strcat_setpoint, do_switch_sp
        MENU_DYNAMIC    gaslist_strcat_setpoint, do_switch_sp
        MENU_DYNAMIC    gaslist_strcat_setpoint, do_switch_sp
  MENU_END


do_divemode_sensor:
	clrf	menupos3					; show customview 1 (HUD Data)
	bsf		toggle_customview
    movlw   .1
    movwf   menupos                 	; Set to 1st option: use sensors
do_divemode_sensor_loop:
    MENU_BEGIN  tGaslist, .6
        MENU_CALL       tDivemenu_UseSensor,    do_switch_sensor
		MENU_CALL		tBack,					do_divemode_splist
        MENU_CALL       tExit,                  do_continue_main_divemenu
		MENU_CALL		tDiveHudMask1,			do_toggle_sensor
		MENU_CALL		tDiveHudMask2,			do_toggle_sensor
		MENU_CALL		tDiveHudMask3,			do_toggle_sensor
    MENU_END

do_divemode_setpoint_pscr:
    movlw   .1
    movwf   menupos                 	; Set to 1st option: use calculated ppO2
    MENU_BEGIN  tGaslist, .6
		MENU_CALL		tCalculated,			do_switch_sp_calc
		MENU_CALL       tDivemenu_UseSensor,    do_switch_sensor
        MENU_CALL       tExit,                  do_continue_main_divemenu
		MENU_CALL		tDiveHudMask1,			do_toggle_sensor
		MENU_CALL		tDiveHudMask2,			do_toggle_sensor
		MENU_CALL		tDiveHudMask3,			do_toggle_sensor
    MENU_END

do_toggle_sensor:
	decf	menupos,f					; 4, 5, 6 ->  3, 4, 5
	decf	menupos,f					; 3, 4, 5 ->  2, 3, 4
	decf	menupos,f					; 2, 3, 4 ->  1, 2, 3
    dcfsnz	menupos						; 1, 2, 3 ->  0, 1, 2
	btg		use_O2_sensor1				;             = 
	dcfsnz	menupos						; 0, 1, 2 -> -1, 0, 1
	btg		use_O2_sensor2				;                =
	dcfsnz	menupos						; -1,0, 1 -> -2,-1, 0
	btg		use_O2_sensor3				;                   =
    movlw   .1
    movwf   menupos
	bra		do_divemode_sensor_loop

	
    END