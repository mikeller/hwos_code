;=============================================================================
;
;    File text_english.asm							REFACTORED VERSION V2.95
;
;    English texts reference file.
;
;   Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================

; Basic texts
	TCODE	tNo,        	"No"           		; No
	TCODE	tYes,       	"Yes"          		; Yes = No + 1
	TCODE	tblank,			" "					; (a single space character)	## NEW (layout)
	
; Surface-mode texts
    TCODE   tBeta,      	  "beta"   			; beta
    TCODE   tMenu,			  "<Menu" 			; <Menu
    TCODE   tView,      	  "View>"      		; View>
    TCODE   tHeading,   	  "Heading:"   		; Heading:
    TCODE   tLastDive,		  "Last Dive"		; Last Dive (Max 10 chars)
    TCODE   tSensorMilliVolt, "CCR Sensors mV" 	; CCR Sensors mV

; Divemode Menu
    TCODE   tDivemenu_Gaslist,  "Gaslist"       ; Gaslist
    TCODE   tDivemenu_ResetAvg, "Reset Avg."    ; Reset Avg.
    TCODE   tDivemenu_Setpoint, "Setpoint"      ; Setpoint
    TCODE   tDivemenu_UseSensor,"use Sensor"    ; Use Sensor
    TCODE   tDivemenu_ToggleGF, "Toggle GF"     ; Toggle GF
    TCODE   tDivemenu_Marker,   "Set Marker"    ; Set Marker
    TCODE   tDivemenu_LostGas,  "Lost Gas"      ; Lost Gas

; Main menu
    TCODE   tNext,      	"<Next"        		; <Next
    TCODE   tEnter,     	"Enter>"       		; Enter>

    TCODE   tMainMenu,  	"Main Menu"    		; MainMenu
    TCODE   tLogbook,   	"Logbook"       	; Logbook
    TCODE   tGasSetup,  	"OC Gas Setup"  	; OC Gas Setup
    TCODE   tSetTime,   	"Set Time"			; Set Time
    TCODE	tSetDate,		"Set Date"			; Set Date
    TCODE	tSetTimeDate,	"Set Time & Date"	; Set Time & Date
    TCODE   tDispSets,  	"Display Settings" 	; Display Settings
    TCODE   tExit,      	"Exit"          	; Exit
	TCODE	tResetMenu, 	"Reset Menu"		; Reset Menu
	TCODE	tDiveModeMenu,	"Deco Setup"		; Deco Setup					## MODIFIED (consistent naming)
	TCODE	tInfoMenu,		"Information"		; Information
	TCODE   tCCRSetup,  	"CCR/pSCR Setup" 	; CCR/pSCR Setup				## MODIFIED (consistent naming)
    TCODE   tDiluentSetup,	"Diluent Setup"   	; Diluent Setup
	TCODE   tFixedSetpoints,"CCR Setpoints" 	; Fixed Setpoints for CCR		## MODIFIED (consistent naming)
	TCODE   tCCRSensor, 	"Sensor"   			; CCR/pSCR Sensor				## MODIFIED (consistent naming)
    TCODE   tCalibrateMenu, "Calibration"   	; Calibration
    TCODE   tCalibrationGas,"Cal. Gas O2:"  	; Cal. Gas O2:
    TCODE   tCalibrate, 	"Calibrate"    		; Calibrate
	TCODE	tBack,			 "back..."			;								## NEW 

; Gas menu
    TCODE   tGaslist,   	"OC Gas List"
    TCODE   tGaslistCC, 	"CC Diluents"
    TCODE   tGasEdit,   	"Edit Gas"
    TCODE   tType,      	"Type: "
    TCODE   tGasDisabled,	"Disabled"  		; Disabled
    TCODE   tGasFirst,   	"First"     		; First
    TCODE   tGasTravel,  	"Travel"    		; Travel
    TCODE   tGasDeco,    	"Deco"      		; Deco
    TCODE   tDilDisabled,	"Disabled"  		; Disabled
    TCODE   tDilFirst,   	"First"     		; First
    TCODE   tDilNorm,   	"Normal"     		; Normal
    TCODE   tAir,       	"Air  "         	; Enum: values must follow (5 chars)
    TCODE   tO2,        	"O2   "         	; tAir + 5
    TCODE   tO2Plus,    	"O2 +"
    TCODE   tO2Minus,   	"O2 -"
    TCODE   tHePlus,    	"He +"
    TCODE   tHeMinus,   	"He -"
    TCODE   tMOD,       	"MOD:"
    TCODE   tEAD,       	"EAD:"
    TCODE   tGasDepth,  	"Change depth"
    TCODE   tDepthPlus, 	"Depth +"
    TCODE   tDepthMinus,	"Depth -"
    TCODE   tDepthReset,	"Reset to MOD:"
    TCODE   tSetup_mix, 	"Setup Mix"
	TCODE   tCCRMode,   	"Mode:"             ; Mode:							## MODIFIED (layout)
    TCODE   tCCRModeFixedSP,"Fixed SP"  	; Fixed for CCR / Calc.for pSCR	## MODIFIED (layout)
    TCODE   tCCRModeSensor,	"Sensor"          	; Sensor
    TCODE   tCCRModeAutoSP,	"Auto SP"         	; Auto SP
    TCODE   tSP,            "SP"                ; SP (SetPoint)
    TCODE   tSPPlus,    	"ppO2+"             ; pO2+
    TCODE   tSensorFallback,"Fallback:"         ; Fallback:
	TCODE	tCalculated,	"calculated"		; calculated
    TCODE   tppO2,      	"ppO2:"             ; ppO2:
    TCODE   tppO2O2,		"ppO2(O2)"			; ppO2(O2)
    TCODE   tppO2Dil,		"ppO2(Dil)"			; ppO2(Dil)
	TCODE   tppO2Mix,		"ppO2(Mix)"			; ppO2(Mix)
	
; New batteries menu
	TCODE   tNewBattTitle,	"New Battery?"
	TCODE	tNewBattOld,	"Keep old"
	TCODE	tNewBattNew36,		"New 3.6V Saft  (T0)"
	TCODE	tNewBattNew15,		"New 1.5V AA    (T1)"
	TCODE	tNewBattAccu,		"3.6V LiIon AA  (T2)"
	TCODE	tNew18650,		"Internal 18650 (T3)"
	TCODE	tNew16650,		"Internal 16650 (T4)"

; Gaslist management
    TCODE   tGas,       	"Gas"				; Gas
    TCODE   tGasErr,    	"Err"           	; Err  (3 chars)
        
; Communication Menu
	TCODE	tUsbTitle,		"USB Mode"
    TCODE   tBleTitle,  	"Bluetooth Mode"
	TCODE	tUsbStarting,  	"Starting..."
	TCODE	tUsbStartDone, 	"Done."
	TCODE	tUsbServiceMode,"Service mode enabled"
	TCODE	tUsbClosed,		"Port closed"
	TCODE	tUsbExit,		"Exited"
	TCODE	tUsbDownloadMode,"Download mode enabled"
    TCODE   tUsbLlBld,      "Low-level Bootloader"

; Dive Settings
    TCODE   tDvMode,    	"Dive Mode:"
    TCODE   tDvOC,      	"OC"				; keep order, enum from here...
    TCODE   tDvCCR,		"CCR"
    TCODE   tDvGauge,   	"Gauge"
    TCODE   tDvApnea,   	"Apnea"
    TCODE   tDvPSCR,		"pSCR"				; ...up to here!
    TCODE   tDvCC,      	"CC"
    TCODE   tDkMode,    	"Decotype:ZH-L16"	;								## MODIFIED (memory needs)
    TCODE   tZHL16,     	" "					; keep order, enum from here...	## MODIFIED (memory needs)
    TCODE   tZHL16GF,   	"+GF"				; ...up to here!				## MODIFIED (memory needs)
    TCODE   tPPO2Max,   	"Max     :"			;								## MODIFIED (layout)
    TCODE   tPPO2DECO,		"Max Deco:"			;								## MODIFIED (layout)
    TCODE   tPPO2MIN,   	"Min     :"			;								## MODIFIED (layout)
	TCODE	tPPO2MINCC, 	"Min Loop:"			; 								## NEW ppO2 min cc
    TCODE   tLastDecostop, 	"Last Deco:"
    TCODE   tDecoparameters,"Deco Parameters"
    TCODE   tGF_low,    	"GF low :"			; 								## MODIFIED (layout)
    TCODE   tGF_high,   	"GF high:"
    TCODE   tSaturationMult,  "Saturation  :"	; 								## MODIFIED (layout)
    TCODE   tDesaturationMult,"Desaturation:"
	TCODE   tFTTSMenu,  	"fTTS/fB/O:"		; Future TTS / Ascent Delay		## MODIFIED (layout)
    TCODE   taGFMenu,   	"Alternative GF"    ; Alternative GF
    TCODE   taGF_low,   	"aGF low :"         ; aGF low						## MODIFIED (layout)
    TCODE   taGF_high,  	"aGF high:"         ; aGF high
    TCODE   taGF_enable,	"aGF selectable:"   ; aGF Selectable
    TCODE   tDiveaGF_active,"aGF!"              ; aGF!
    TCODE   tppO2settings,	"ppO2 Settings"     ; ppO2 Settings
    TCODE   tsafetystopmenu,"Safety Stop:"		; Safety Stop:
	TCODE   tGasUsage,  	"Gas Usage"         ; Gas Usage
    TCODE   tSetBotUse, 	"Bottom Gas: "      ; Bottom Gas: (space)
    TCODE   tSetDecoUse,	"Deco   Gas: "      ; Deco   Gas: (space)			## MODIFIED (layout)
	TCODE	tCalcAscGas,	 "Calc.Gas (B/O):"	;								## NEW bailout gas needs
	TCODE	tTankSizes,		 "Tank Sizes"		;								## NEW bailout gas needs
	TCODE   tLiter,			 " l"				;								## NEW bailout gas needs 
	TCODE	tBarLiter,		"Liter"
	TCODE	tTankFillPress,	 "Tank Press Budget";
	TCODE	tGas1,			 "Gas 1:"			;								## NEW bailout gas needs
	TCODE	tGas2,			 "Gas 2:"			;								## NEW bailout gas needs
	TCODE	tGas3,			 "Gas 3:"			;								## NEW bailout gas needs
	TCODE	tGas4,			 "Gas 4:"			;								## NEW bailout gas needs
	TCODE	tGas5,			 "Gas 5:"			;								## NEW bailout gas needs
	TCODE	tCCmaxFracO2,	 "Loop %O2 max.:"	;								## NEW CCR max ppO2 limiter
	TCODE	t2ndDecoPlanMenu,"2nd Deco Plan"	;								## NEW deco engine

; Display Settings
    TCODE   tBright,    	"Brightness:"
    TCODE   tEco,       	"Eco"
    TCODE   tMedium,    	"Medium"
    TCODE   tHigh,      	"High"
    TCODE   tDvSalinity,	"Salinity: "       	; Salinity						## MODIFIED (layout)
	TCODE   tShowppO2,  	"Always show ppO2:"	; Always show ppO2:
    TCODE   tFlip,      	"Rotate Screen:"    ; Rotate Screen
    TCODE   tMODwarning,	"MOD  Warning  :"	; MOD warning					## MODIFIED (layout)
	TCODE	tIBCDwarning,	"IBCD Warning  :"	; IBCD Warning					## NEW IBCD
    TCODE   tTimeoutDive,	"Dive Timeout:"		; Dive Timeout					## MODIFIED (layout)
	
; VSI display Settings
    TCODE   tVSItext2,  	"Variable Speed:"   ; Variable speed:				## MODIFIED (layout)
    TCODE   tVSIgraph,  	"Speed    Graph:"   ; Speed graph:					## MODIFIED (layout)

; Setup Menu
    TCODE   tSystSets,  	"Settings"
    TCODE   tLanguage,  	"Language:"
    TCODE   tEnglish,   	"English"
    TCODE   tGerman,    	"German"
    TCODE   tFrench,    	"French"
    TCODE   tItalian,   	"Italian"
    TCODE   tCompassMenu,	"Compass calibration"
    TCODE   tCompassGain,	"Compass Gain:"
    TCODE   tCalX,	 		"Cal X:"			; Cal X
    TCODE   tCalY,	 		"Cal Y:"			; Cal Y
    TCODE   tCalZ,	 		"Cal Z:"			; Cal Z

    TCODE   tUnits,     	"Units:"
    TCODE   tMetric,     	" m/°C"            	; Enum menu
    TCODE   tImperial,   	"ft/°F"

    TCODE   tDefName,   	"HW OSTC"

    TCODE   tButtonleft,	"Left button:"		; Left button
    TCODE   tButtonright,	"Right button:"    	; Right button

	TCODE	tAltMode,		"Waiting Time:"		;								## NEW no fly altitude
	TCODE	tAltModeFly,	"Flying"			;								## NEW no fly altitude
	TCODE	tAltMode1000,	"1000m"				;								## NEW no fly altitude
	TCODE	tAltMode2000,	"2000m"				;								## NEW no fly altitude
	TCODE	tAltMode3000,	"3000m"				;								## NEW no fly altitude

; Units for all menu
    TCODE   tMeters,    	"m"
	TCODE	tFeets,			"ft"
	TCODE	tFeets1,		"f"
    TCODE   tMinutes,   	"'"
    TCODE   tPercent,   	"%"
    TCODE   tLitersMinute, 	"l/min"
	TCODE	tbar,			" bar"				; bar							## MODIFIED (layout)
	TCODE	tbar10,			"0 bar"				; bar							## NEW 2.95
	TCODE	tMeterMinute,	"m/min"				; meter per minute				## ascent speed
	TCODE	tmin,			"min"				; minutes

; Date
	TCODE	tDateFormat, 	"Date:"
	TCODE	tDateformat, 	"MMDDYY"
	TCODE	tDateformat1,	"DDMMYY"
	TCODE	tDateformat2,	"YYMMDD"

; Simulator menu
    TCODE   tInter, 		"Start Simulator"	; Start Simulator
    TCODE   tPlan,  		"Simulator"			; Simulator

; Decoplanner submenu
    TCODE   tBtTm,  		"Bot.Time : "		; Bot. Time: (10 chars)			## MODIFIED (layout)
    TCODE   tBtTm_short,	"Time:"             ; Bot. Time: (max. 6 chars)
    TCODE   tBtDep, 		"Bot.Depth: "		; Max Depth: (10 chars)			## MODIFIED (layout)
    TCODE   tIntvl, 		"Interval : "		; Interval : (10 chars)
	TCODE	tDecoSetup,		"Calculator Setup"	;								## NEW (layout)
	TCODE   tDeco,  		"Start Calculator"  ; Calculate Deco				## MODIFIED (layout)
    TCODE   tDivePlan,  	"Dive Plan:"        ; Dive Plan:
    TCODE   tNoDeco,    	"No Deco"           ; No Deco
    TCODE   tMore,      	"More..."           ; More...
	TCODE	tSelectSetpoint,"CCR Setpoint: "	;								## NEW deco calculator enhancement
	TCODE	tuseAGF,		"use aGF: "			;								## NEW deco calculator enhancement
	TCODE	tCalculating,	"Calculating..."	;								## NEW deco calculator enhancement

; Information menu
    TCODE   tFirmware,  	"Firmware: "        ; Firmware: (space)
    TCODE   tSerial,    	"Serial  : "        ; Serial  : (space)
    TCODE   tTotalDives,	"Total Dives: "	    ; Total Dives:
    TCODE   tBatteryV,  	"Battery : "        ; Battery:						## MODIFIED	## info - added one space
    TCODE   tUptime,		"Uptime  : "    	; Uptime:						## MODIFIED	## info - added two spaces
   
; Divemode screen
    TCODE   tNDL,       	"NDL"
    TCODE   tTTS,   		"TTS"
	TCODE	tVelMetric,	 	"m/min"
	TCODE	tVelImperial,	"ft/m "
	TCODE	tGasSelect,  	"Select Gas"		; Select Gas
	TCODE	tSelectAir,	 	"Air "     			; Air
	TCODE	tSelectO2,	 	"O2  "				; O2
    TCODE   tSelectNx,   	"Nx"				; Nx
    TCODE   tSelectTx,   	"Tx"				; Tx
    TCODE   tDepth,      	"Depth"				; Depth
    TCODE   tMaxDepth,   	"Max. Depth"		; Max. Depth - max 10chars!
    TCODE   tDivetime,   	"Divetime"			; Divetime
    TCODE   tDiveHudMask1,  "Sensor 1"
    TCODE   tDiveHudMask2,  "Sensor 2"
    TCODE   tDiveHudMask3,  "Sensor 3"
    TCODE   tDiveTotalAvg,  "Total Avg"
    TCODE   tDiveStopwatch, "Stopwatch"
    TCODE   tDiveStopAvg,   "Stopped Avg"   	; 11chars max
    TCODE   tApnoeTotal,    " Total"        	; Total (Six chars, right alligned)
    TCODE   tApnoeMax,      "Last Descent"  	; Last descent
    TCODE   tApnoeSurface,  "Surface Time"  	; Surface Time
    TCODE   tDiveDecoplan,  "Decoplan"      	; Decoplan
    TCODE   tDiveClock,     "Clock"         	; Clock
    TCODE   tDiveEAD_END,   "EAD/END"       	; EAD/END
    TCODE   tDiveTissues,   "Tissues"       	; Tissues
    TCODE   tEND,           "END:"          	; END:
    TCODE   tHe,            "He"            	; He
    TCODE   tN2,            "N2"            	; N2
    TCODE   tDiveBailout,   "Bailout"       	; Bailout
    TCODE   tGFactors,      "GF Values"     	; GF Values
    TCODE   taGFactors,     "aGF Values"    	; aGF Values
    TCODE   tGFInfo,        "Current GF"    	; GF Info
    TCODE   tCeiling,       "Ceiling"       	; Ceiling
    TCODE   tDiveSafetyStop,"Stop"          	; Stop (Four chars, right alligned)
    TCODE   tDiveFallback,  "Fallback!"     	; Fallback! (max. nine chars)
	TCODE	tDecoInfo,		"Deco Zone"			; Deco info
    TCODE   tSensorCheck,   "Sensor Check"  	; Sensor Check
    TCODE   tdil,	    	"Dil:"	    		; Diluent ppO2 Warning
	TCODE	tmix,			"Mix:"				; Pre-Mix ppO2 Warning
	TCODE	tSensorDisagree,"Sensors<>"			; Sensors disagree Warning		## NEW voting logic
	TCODE	tGasNeedsWarn,	"Gas Needs"			;								## NEW bailout gas needs
	TCODE	tGasNeedsBar,	"Gas Needs (bar)"	;								## NEW bailout gas needs
	TCODE	tCNSsurf,		"CNS Surf."			;								## NEW CNS at end-of-dive
	TCODE	tCNSfTTS,		"CNS fTTS"			;								## NEW CNS at end-of-dive
	TCODE	tCNSBO,			"CNS B/O"			;								## NEW CNS at end-of-dive
	TCODE	tCNSnow,		"CNS now"			;								## NEW CNS at end-of-dive
	TCODE	tCNSeod,		"CNS final"			;								## NEW CNS at end-of-dive
	TCODE	tIBCD,			"IBCD N2He"			;								## NEW IBCD
	TCODE	tMicroBubbles,	"M.Bubbles"			;								## NEW microbubbles
	TCODE	tCNS,			"CNS: "				;								## V2.95 optics

; Divemode menu
    TCODE   tDivePreMenu,   "Menu?"         	; Menu?
    TCODE   tSetHeading,    "Bearing"       	; Bearing (Max. seven chars)

; Simulator menu
	TCODE	tQuitSim,	 	"Quit?"            	; Quit Simulation?

; Logbook
	TCODE	tCNS2,			"CNS:"
	TCODE	tAVG,			"Avg:"
	TCODE	tGF,			"GF:"
	TCODE	tSAT,			"Sat:"				; Sat:

; Logbook units
	TCODE	tLogTunitC,		"°C"	
	TCODE	tLogTunitF,		"°F"
	TCODE	tKGL,			"kg/l"
	TCODE	tMBAR,			"mbar"

; Logbook menu
	TCODE	tNextLog, 		"Next Page"

; Reset menu
	TCODE	tReboot,		"Reboot"			; Reboot
	TCODE	tResetMenu2,	"Are you sure?"		; Are you sure?
	TCODE	tAbort,     	"Abort"             ; Abort
	TCODE	tResetSettings, "Reset all" 		; Reset all
	TCODE	tResetDeco,		"Reset Deco"		; Reset Deco
    TCODE	tResetBattery,	"Reset Battery"		; Reset Battery
    TCODE	tResetLogbook,	"Reset Logbook"		; Reset Logbook

; Set Time Menu/Set Date Menu
	TCODE	tSetHours,		"Set Hours"			; Set Hours
	TCODE	tSetMinutes,	"Set Minutes"		; Set Minutes
	TCODE	tSetSeconds,	"Clear Seconds"		; Clear seconds
	TCODE	tSetDay,		"Set Day"			; Set Day
	TCODE	tSetMonth,		"Set Month"			; Set Month
	TCODE	tSetYear,		"Set Year"			; Set Year

; Logbook Offset Menu
	TCODE	tLogOffset,		"Logbook offset"	; Logbook offset
	TCODE	tLogOffsetp1,	"+1"				; +1
	TCODE	tLogOffsetp10,	"+10"				; +10
	TCODE	tLogOffsetm1,	"-1"				; -1
	TCODE	tLogOffsetm10,	"-10"				; -10

; Compass directions
    TCODE   tN,             "N "                ; N(orth),	 338°- 22°
    TCODE   tNE,            "NE"                ; North-East, 23°- 67°
    TCODE   tE,             "E "                ; E(east),	  68°-112°
    TCODE   tSE,            "SE"                ; South-East,113°-157°
    TCODE   tS,             "S "                ; S(outh),	 158°-202°
    TCODE   tSW,            "SW"                ; South-West,203°-247°
    TCODE   tW,             "W "                ; W(West),	 248°-292°
    TCODE   tNW,            "NW"                ; North-West,293°-337°

; Color Scheme menu
    TCODE   tColorScheme,   "Colour scheme"     ; Colour scheme
    TCODE   tColorSetDive,  "Divemode:"         ; Divemode:
    TCODE   tColorSetName0, "Standard"          ; Standard
    TCODE   tColorSetName1, "Red"               ; Red
    TCODE   tColorSetName2, "Green"             ; Green
    TCODE   tColorSetName3, "Blue"              ; Blue
    
; PSCR Menu and Settings
	TCODE   tPSCRMenu,	    "pSCR Setup"		; PSCR Menu						## MODIFIED (consistient naming)
    TCODE   tPSCR_O2_drop,  "O2 drop:"			; O2 drop
    TCODE   tPSCR_lungratio,"Lung ratio:"		; lung ratio
