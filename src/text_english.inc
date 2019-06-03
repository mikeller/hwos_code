;=============================================================================
;
;	File text_english.asm                     next combined generation V3.03.3
;
;	English texts reference file.
;
;	Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================

; Basic texts
	TCODE	tNo,				"No"					; 0 No    | ENUM group
	TCODE	tYes,				"Yes"					; 1 Yes   |
 IFDEF _cave_mode
	TCODE	tCave,				"Cave"					; 2 Cave  |
 ENDIF

	TCODE	tblank,				" "						; (a single space character)

; Surface-mode texts
	TCODE	tMenu,				"<Menu"					; <Menu
	TCODE	tView,				"View>"					; View>
	TCODE	tHeading,			"Heading:"				; Heading:
	TCODE	tLastDive,			"Last Dive"				; Last Dive (Max 10 chars)

 IFDEF _external_sensor
	TCODE	tSensorMilliVolt,	"Sensors mV"			; Sensors mV
 ENDIF


; Divemode menu
	TCODE	tDivemenu_Gaslist,	"Gaslist"				; Gaslist  (OC)
	TCODE	tDivemenu_ResetAvg,	"Reset Avg"				; Reset Avg (max 9 char)
	TCODE	tDivemenu_Avg_Mkr,	"Avg/Marker"			; Reset Avg, Set Marker (and Turn Dive)
	TCODE	tDivemenu_ToggleGF,	"Toggle GF"				; Toggle GF
	TCODE	tDivemenu_Marker,	"Set Marker"			; Set Marker
	TCODE	tDivemenu_LostGas,	"Lost Gas"				; Lost Gas

 IFDEF _ccr_pscr
	TCODE	tDivemenu_Diluent,	"Diluents"				; Diluents (CCR)
	TCODE	tDivemenu_Premix,	"Premix"				; Premix   (pSCR)
	TCODE	tDivemenu_Setpoint,	"Setpoint"				; Setpoint
 ENDIF

 IFDEF _external_sensor
	TCODE	tDivemenu_UseSensor,"use Sensor"			; Use Sensor
 ENDIF

 IFDEF _cave_mode
	TCODE	tDivemenu_TurnDive,	"Turn Dive"				; Turn Dive
 ENDIF


; Main menu
	TCODE	tNext,				"<Next"					; <Next
	TCODE	tEnter,				" Enter>"				; Enter>
	TCODE	tMainMenu,			"Main Menu"				; MainMenu
	TCODE	tLogbook,			"Logbook"				; Logbook
	TCODE	tGasSetup,			"OC Gas Setup"			; OC Gas Setup
	TCODE	tSetTime,			"Set Time"				; Set Time
	TCODE	tSetDate,			"Set Date"				; Set Date
	TCODE	tSetTimeDate,		"Set Time & Date"		; Set Time & Date
	TCODE	tDispSets,			"Display Settings"		; Display Settings
	TCODE	tExit,				"Exit"					; Exit
	TCODE	tResetMenu,			"Reset Menu"			; Reset Menu
	TCODE	tDiveModeMenu,		"Deco Setup"			; Deco Setup
	TCODE	tInfoMenu,			"Information"			; Information
 IFDEF _ccr_pscr
	TCODE	tCCRSetup,			"CCR/pSCR Setup"		; CCR/pSCR Setup
	TCODE	tDiluentSetup,		"Diluent Setup"			; Diluent Setup
 ENDIF
	TCODE	tFixedSetpoints,	"CCR Setpoints"			; Fixed Setpoints for CCR
	TCODE	tBack,				"back"					; back

 IFDEF _rx_functions
	TCODE	tTrSettings,		"Pressure Display"		; Pressure Display
	TCODE	tTrMode,			"Mode: "				; Mode
	TCODE	tTr1stPres,			"1.Pres.: "				; 1st Pressure
	TCODE	tTr2ndPres,			"2.Pres.: "				; 2nd Pressure
	TCODE	tTrBailPres,		"1.B/O  : "				; Bailout Pressure
	TCODE	tTrMaxDeltaP,		"max deltaP: "			; independent double max diffenerce
 ENDIF

 IFDEF _ccr_pscr
 IFDEF _external_sensor
	TCODE	tCCRSensor,			"Sensor"				; CCR/pSCR Sensor
	TCODE	tCalibrateMenu,		"Calibration"			; Calibration
	TCODE	tCalibrationGas,	"Cal. Gas O2:"			; Cal. Gas O2:
	TCODE	tCalibrate,			"Calibrate"				; Calibrate
 ENDIF
 ENDIF


; Gas menu
	TCODE	tGaslist,			"OC Gas List"
	TCODE	tGaslistCC,			"CC Diluents"
	TCODE	tGasEdit,			"Edit Gas"
	TCODE	tType,				"Type: "
	TCODE	tGasDisabled,		"Disabled"				; Disabled
	TCODE	tGasFirst,			"First"					; First
	TCODE	tGasTravel,			"Travel"				; Travel
	TCODE	tGasDeco,			"Deco"					; Deco
	TCODE	tDilDisabled,		"Disabled"				; Disabled
	TCODE	tDilFirst,			"First"					; First
	TCODE	tDilNorm,			"Normal"				; Normal
	TCODE	tAir,				"Air  "					; Enum: values must follow (5 chars)
	TCODE	tO2,				"O2   "					; tAir + 5
	TCODE	tO2Plus,			"O2 +"
	TCODE	tO2Minus,			"O2 -"
 IFDEF _helium
	TCODE	tHePlus,			"He +"
	TCODE	tHeMinus,			"He -"
 ENDIF
	TCODE	tMOD,				"MOD :"
	TCODE	tEAD,				"EAD:"
	TCODE	tSetup_GasDepth,	"Setup Depth"
	TCODE	tDepthPlus,			"Depth +"
	TCODE	tDepthMinus,		"Depth -"
	TCODE	tDepthReset,		"Reset to MOD:"
	TCODE	tSetup_GasMix,		"Setup Mix"
 IFDEF _ccr_pscr
	TCODE	tSPPlus,			"ppO2+"					; pO2+
	TCODE	tSensorFallback,	"Fallback:"				; Fallback:
	TCODE	tCalculated,		"calculated"			; calculated
	TCODE	tppO2O2,			"ppO2(O2)"				; ppO2(O2)
	TCODE	tppO2Dil,			"ppO2(Dil)"				; ppO2(Dil)
	TCODE	tppO2Mix,			"ppO2(Mix)"				; ppO2(Mix)
	TCODE	tCCRMode,			"Mode:"					; Mode:
	TCODE	tCCRModeFixedSP,	"Fixed SP/Calc."		; 0 fixed for CCR / calculated for pSCR  | ENUM group
	TCODE	tCCRModeSensor,		"Sensor"				; 1 Sensor                               |
	TCODE	tCCRModeAutoSP,		"Auto SP"				; 2 Auto SP                              |
 ELSE
	TCODE	tCCRModeFixedSP,	" "						; target needed by option table
 ENDIF
	TCODE	tSP,				"SP"					; SP (SetPoint)
	TCODE	tppO2,				"ppO2:"					; ppO2:


; New batteries menu
	;                                     1         2	;
	;                            12345678901234567890	; max 20 chars
	TCODE	tNewBattTitle,		"New Battery?"
	TCODE	tNewBattOld,		"Keep old"
	TCODE	tNewBattNew36,		"3.6V disposable (T1)"	; new 3.6V disposable
	TCODE	tNewBattNew15,		"1.5V disposable (T0)"	; new 1.5V disposable
	TCODE	tNewBattAccu,		"3.7V chargeable (T2)"	; new 3.7V rechargeable
	TCODE	tNew18650,			"OSTC 2 or cR    (T3)"	; internal battery on 2 (old) / cR
	TCODE	tNew16650,			"OSTC 2 or TR    (T4)"	; internal battery on 2 (new) / TR
	TCODE	tConfirmChargeable1,"Confirm:"				; safety question, line 1
	TCODE	tConfirmChargeable2,"inserted Battery"		; safety question, line 2
	TCODE	tConfirmChargeable3,"is rechargeable"		; safety question, line 3


; Gaslist Management
	TCODE	tGas,				"Gas"					; Gas
	TCODE	tDil,				"Dil"					; Diluent
	TCODE	tGasErr,			"Err"					; Err (3 chars)


; Communication menu
	TCODE	tUsbTitle,			"USB Mode"
	TCODE	tBleTitle,			"Bluetooth Mode"
	TCODE	tUsbStarting,		"Starting..."
	TCODE	tUsbStartDone,		"Done."
	TCODE	tUsbServiceMode,	"Service mode enabled"
	TCODE	tUsbClosed,			"Port closed"
	TCODE	tUsbExit,			"Exited"
	TCODE	tUsbDownloadMode,	"Download mode enabled"
	TCODE	tUsbLlBld,			"Low-level Bootloader"


; Dive settings
	TCODE	tDvMode,			"Dive Mode: "
	TCODE	tDvOC,				"OC"					; 0      - keep order, enum!
	TCODE	tDvCCR,				"CCR"					; 1
	TCODE	tDvGauge,			"Gauge"					; 2
	TCODE	tDvApnea,			"Apnea"					; 3
	TCODE	tDvPSCR,			"pSCR"					; 4
	TCODE	tDvCC,				"CC"
	TCODE	tDkMode,			"Decotype: ZH-L16"
	TCODE	tZHL16,				" "						; 0      - keep order, enum!
	TCODE	tZHL16GF,			"+GF"					; 1
	TCODE	tPPO2Max,			"Max     :"
	TCODE	tPPO2DECO,			"Max Deco:"
	TCODE	tPPO2MIN,			"Min     :"
 IFDEF _ccr_pscr
	TCODE	tPPO2MINCC,			"Min Loop:"
 ENDIF
	TCODE	tLastDecostop,		"Last Deco    : "		; last deco stop depth
	TCODE	tAscentSpeed,		"Ascent Speed : "		; Ascent Speed
	TCODE	tGasChangeTime,		"Gas Change   :+"		; additional Gas Change Time
	TCODE	tExtendedStops,		"before 1.Stop: "		; gas switches before 1st stop
	TCODE	tTimeoutDive,		"Dive Timeout : "		; Dive Timeout
	TCODE	tStoreApnoeDive,	"Store Apnoe  : "		; Store Apnoe Dives
	TCODE	tDecoparameters,	"Deco Parameters"
	TCODE	tGF_low,			"GF  low :"
	TCODE	tGF_high,			"GF  high:"
	TCODE	tSaturationMult,	"Saturation  : "
	TCODE	tDesaturationMult,	"Desaturation: "
	TCODE	tFTTSMenu,			"fTTS/Delay:"			; Future TTS / Ascent Delay
	TCODE	tLastDecostopSurf,	"Last Deco :"			; last deco stop depth Surface Custom View
	TCODE	tGFMenu,			"GF Settings"			; GF Settings
	TCODE	taGF_low,			"aGF low :"				; aGF low
	TCODE	taGF_high,			"aGF high:"				; aGF high
	TCODE	taGF_enable,		"aGF selectable:"		; aGF Selectable
	TCODE	tDiveaGF_active,	"using aGF"				; using aGF
	TCODE	tppO2settings,		"ppO2 Settings"			; ppO2 Settings
	TCODE	tsafetystopmenu,	"Safety Stop: "			; Safety Stop:
	TCODE	tGasUsage,			"Gas Usage"				; Gas Usage
	TCODE	tSetBotUse,			"Bottom Gas: "			; Bottom Gas: (space)
	TCODE	tSetDecoUse,		"Deco   Gas: "			; Deco   Gas: (space)
	TCODE	tCalcAscGas,		"Calc.Gas (B/O):"		; Calculate Gas (Bail Out) needs?
	TCODE	tSetup_Tank,		"Setup Tank"			; Setup Tank
	TCODE	tTankSize,			"Tank  Size"			; Tank Sizes
	TCODE	tTankUsablePress,	"Turn Pres/Asc.Need"	; Tank Pressure Budget for Ascent (turn pressure) (max 19 chars)
	TCODE	tLiter,				" l"					; Liter as l
	TCODE	tLiterLong,			"Liter"					; Liter as Liter
	TCODE	t2ndDecoPlanMenu,	"2nd Deco Plan"			; 2nd Deco Plan

 IFDEF _ccr_pscr
	TCODE	tCCmaxFracO2,		"Loop %O2 max.:"
	TCODE	tCopyDilToOC,		"Copy  Dil.-> OC"		; copy diluent settings to OC gas
 ENDIF

 IFDEF _rx_functions
	TCODE	tTankPairing,		"Select Transmitter"	; select Transmitter
	TCODE	tTrModeOff,			"off"					;  0 off		keep order, enum!
	TCODE	tTrModeOn,			"on"					;  1 on
	TCODE	tTrModeIndDouble,	"indep.Double"			;  2 independent double
	TCODE	tTrModeCCR,			"CCR Dil+O2"			;  3 CCR diluent and O2
	TCODE	tTrPresNone,		"none"					;  0 none		keep order, enum!
	TCODE	tTrPresGas1,		"Gas 1"					;  1 Gas 1
	TCODE	tTrPresGas2,		"Gas 2"					;  2 Gas 2
	TCODE	tTrPresGas3,		"Gas 3"					;  3 Gas 3
	TCODE	tTrPresGas4,		"Gas 4"					;  4 Gas 4
	TCODE	tTrPresGas5,		"Gas 5"					;  5 Gas 5
 IFDEF _ccr_pscr
	TCODE	tTrPresDil1,		"Dil 1"					;  6 Dil 1
	TCODE	tTrPresDil2,		"Dil 2"					;  7 Dil 2
	TCODE	tTrPresDil3,		"Dil 3"					;  8 Dil 3
	TCODE	tTrPresDil4,		"Dil 4"					;  9 Dil 4
	TCODE	tTrPresDil5,		"Dil 5"					; 10 Dil 5
	TCODE	tTrPresFirstGas,	"First Gas"				; 11 first  Gas
	TCODE	tTrPresActiveGas,	"active Gas"			; 12 active Gas
	TCODE	tTrPresFirstDil,	"First Dil"				; 13 first  Dil
	TCODE	tTrPresActiveDil,	"active Dil"			; 14 active Dil
 ENDIF
 ELSE
 	TCODE	tTrModeOff,			""						; dummy target for entry in option table
	TCODE	tTrPresNone,		""						; dummy target for entry in option table
 ENDIF	; _rx_functions


; Display settings
	TCODE	tBright,			"Brightness:"
	TCODE	tEco,				"Eco"
	TCODE	tMedium,			"Medium"
	TCODE	tHigh,				"High"
	TCODE	tDvSalinity,		"Salinity:  "			; Salinity
	TCODE	tShowppO2,			"Always show ppO2:"		; Always show ppO2:
	TCODE	tFlip,				"Rotate Screen:"		; Rotate Screen
	TCODE	tMODwarning,		"Depth Warnings:"		; depth Warnings
;	TCODE	tIBCDwarning,		"IBCD  Warning :"		; IBCD Warning
	TCODE	tLayout,			"Layout   :"			; Layout
	TCODE	t2ndDepth,			"2nd Depth:"			; 2nd depth display content (10 chars max)
	TCODE	tTissueGraphics,	"Graphics :"			; tissue graphics

	TCODE	tLayoutNormal,		"normal"				; normal
	TCODE	tLayoutBig,			"big"					; big


; VSI display settings
	TCODE	tVSItext2,			"Variable Speed:"		; Variable speed:
	TCODE	tVSIgraph,			"Speed Graph   :"		; Speed graph:


; Setup menu
	TCODE	tSystSets,			"Settings"
 IFDEF _compass
	TCODE	tCompassMenu,		"Compass Calibration"
	TCODE	tCompassGain,		"Compass Gain:"
	TCODE	tCalX,				"Cal X:"				; Cal X
	TCODE	tCalY,				"Cal Y:"				; Cal Y
	TCODE	tCalZ,				"Cal Z:"				; Cal Z
 ENDIF
	TCODE	tUnits,				"Units: "
	TCODE	tMetric,			" m/°C"					; 0   - keep order, enum!
	TCODE	tImperial,			"ft/°F"					; 1
								;         111         111         111         111         111
	; 5 rows by 12 chars each:	 123456789012123456789012123456789012123456789012123456789012
	TCODE	tDefName,			"  Read the  Manual, know& understandthe inherentLimitations!"
	TCODE	tButtonleft,		"Left  button:"			; Left button
	TCODE	tButtonright,		"Right button:"			; Right button
	TCODE	tAltMode,			"Waiting Time:"
	TCODE	tAltModeFly,		"Flying"
	TCODE	tAltMode1000,		"1000m"
	TCODE	tAltMode2000,		"2000m"
	TCODE	tAltMode3000,		"3000m"


; Units for all menu
	TCODE	tMeters,			"m"
	TCODE	tFeets,				"ft"
	TCODE	tFeets1,			"f"
	TCODE	tMinutes,			"'"
	TCODE	tPercent,			"%"
	TCODE	tLitersMinute,		"l/min"
	TCODE	tbar,				" bar"					; bar
	TCODE	tbar10,				"0 bar"					; xx0 bar
	TCODE	tMeterMinute,		"m/'"					; meter per minute


; Date
	TCODE	tDateFormat,		"Format: "
	TCODE	tDateformat,		"MMDDYY"
	TCODE	tDateformat1,		"DDMMYY"
	TCODE	tDateformat2,		"YYMMDD"


; Simulator menu
	TCODE	tInter,				"Start Simulator"		; Start Simulator
	TCODE	tPlan,				"Simulator"				; Simulator


; Decoplanner submenu
	TCODE	tBtTm,				"Bot.Time : "			; Bot. Time: (10 chars)
	TCODE	tBtTm_short,		"Time :"				; Bot. Time: (max. 6 chars)
	TCODE	tBtDep,				"Bot.Depth: "			; Max Depth: (10 chars)
	TCODE	tIntvl,				"Interval : "			; Interval : (10 chars)
	TCODE	tDecoSetup,			"Calculator Setup"
	TCODE	tDeco,				"Start Calculator"		; Calculate Deco
	TCODE	tDivePlan,			"Dive Plan"				; Dive Plan (max. 10 chars)
	TCODE	tNoDeco,			"No Deco"				; No Deco
	TCODE	tMore,				"more"					; more
	TCODE	tSelectSetpoint,	"Setpoint : "
	TCODE	tuseAGF,			"use aGF  : "
	TCODE	tCalculating,		"Calculating..."		; Calculating...
	TCODE	tCalcSurfInter,		"Surface Interval"		; Surface Interval
	TCODE	tCalcBotSeg,		"Bottom  Segment"		; Bottom Segment
	TCODE	tCalcBailout,		"Switch  to Bailout"	; Switch to Bailout
	TCODE	tCalcAscent,		"Ascent"				; Ascent
	TCODE	tNDLleft,			"left"					; time left within NDL


; Information menu
	TCODE	tFirmware,			"Firmware: "			; Firmware: (space)
	TCODE	tSerial,			"Serial  : "			; Serial  : (space)
	TCODE	tTotalDives,		"Total Dives: "			; Total Dives:
	TCODE	tBatteryV,			"Battery : "			; Battery : (space)
	TCODE	tUptime,			"Uptime  : "			; Uptime  : (space)

 IFDEF _rx_functions
	TCODE	tFirmware_rx,		"RX Ver  : "			; RX Ver  : (space)
 ENDIF


; Divemode screen
	TCODE	tNDL,				"NDL"					; 3 chars max
	TCODE	tTTS,				"TTS"					; 3 chars max
	TCODE	tVelMetric,			"m/min"
	TCODE	tVelImperial,		"ft/m "
	TCODE	tGasSelect,			"Select Gas"			; Select Gas
	TCODE	tSelectAir,			"Air "					; Air
	TCODE	tSelectO2,			"O2  "					; O2
	TCODE	tSelectNx,			"Nx"					; Nx
	TCODE	tSelectTx,			"Tx"					; Tx
	TCODE	tDepth,				"Depth"					; Depth (max 5 chars)
	TCODE	tMaxDepth,			"Max.Depth"				; Max. Depth    - max 9 chars!
	TCODE	tAvgDepth,			"Average"				; average Depth - max 9 chars!
	TCODE	tTissuePresSat,		"Pres+Sat"				; 0 pressure and saturation    | ENUM group
 IFDEF _helium
	TCODE	tTissueN2He,		"N2+He"					; 1 N2 + He pressure           |
 ENDIF
	TCODE	tDivetime,			"Divetime"				; Divetime (max 8 chars)
	TCODE	tDiveTotalAvg,		"Total Avg"
	TCODE	tDiveStopwatch,		"Stopwatch"
	TCODE	tDiveStopAvg,		"Stopped Avg"			; 11 chars max
	TCODE	tApnoeTotal,		" Total"				; Total (six chars, right aligned)
	TCODE	tApnoeMax,			"Last Descent"			; Last descent
	TCODE	tApnoeSurface,		"Surface Time"			; Surface Time
	TCODE	tTime,				"Time of Day"			; Time
	TCODE	tSurface,			"Surface"				; Surface (max 12 chars)
	TCODE	tDiveDecoplan,		"next Stops"			; next Stops
;	TCODE	tDiveClock,			"Clock"					; Clock
	TCODE	tDiveEAD_END,		"EAD/END"				; EAD/END
	TCODE	tDiveTissues,		"Tissues"				; Tissues
	TCODE	tEND,				"END:"					; END:
	TCODE	tN2,				"N2"					; N2
	TCODE	tDiveBailout,		"Bailout"				; Bailout (max. 7 chars)
	TCODE	tGFactors,			"GF Values"				; GF Values
	TCODE	taGFactors,			"aGF Values"			; aGF Values
	TCODE	tGFInfo,			"Saturation"			; Saturation
	TCODE	tCeiling,			"Ceiling"				; Ceiling
	TCODE	tDiveSafetyStop,	"Stop"					; Stop (four chars, right aligned)
	TCODE	tDiveFallback,		"Fallback!"				; Fallback! (max. nine chars)
	TCODE	tDecoInfo,			"Deco Zone"				; Deco info
	TCODE	tSensorCheck,		"Sensor Check"			; Sensor Check
	TCODE	tdil,				"Dil:"					; Diluent ppO2 Warning
	TCODE	tmix,				"Mix:"					; Pre-Mix ppO2 Warning
	TCODE	tGasNeedsWarn,		"Gas Needs"
	TCODE	tGasNeedsAscent,	"Gas Needs Ascent"
	TCODE	tCNSsurf,			"CNS Surf."
	TCODE	tCNSfTTS,			"CNS fTTS"
	TCODE	tCNSBO,				"CNS B/O"
	TCODE	tCNSnow,			"CNS now"
	TCODE	tCNSeod,			"CNS final"
	TCODE	tnoBOgas,			"-B/O-Gas-"
	TCODE	tMicroBubbles,		"M.Bubbles"
	TCODE	tCNS,				"CNS: "
	TCODE	tgaschange,			"Change?"				; better gas found
	TCODE	tNeed,				"Need "					; gas need (5 chars)
	TCODE	tBattery,			"Battery"				; Battery

 IFDEF _helium
	TCODE	tHe,				"He"					; He
	TCODE	tIBCD,				"IBCD N2He"				; IBCD warning
 ENDIF

 IFDEF _rx_functions
	TCODE	tTransmitter,		"Pres XMTR"				; pressure transmitter
	TCODE	tPressure,			"Tank Pres"				; tank pressure
	TCODE	tSAC,				"SAC"					; SAC, must be 3 chars!
	TCODE	tswap,				"Swap Tank"				; swap tank (max. 9 chars)
 ENDIF

 IFDEF _ccr_pscr
 IFDEF _external_sensor
	TCODE	tDiveHudMask1,		"Sensor 1"
	TCODE	tDiveHudMask2,		"Sensor 2"
	TCODE	tDiveHudMask3,		"Sensor 3"
	TCODE	tSensorDisagree,	"Sensors<>"				; Sensors disagree Warning
 ENDIF
 ENDIF

 IFDEF _cave_mode
	TCODE	tGasNeedsCaveMode,	"Gas Needs Cave Mode"	; title for gas needs custom view
	TCODE	tDiveTurned,		"Dv.turned"				; dive is turned      (max. 9 char)
	TCODE	tCaveMode,			"Cave Mode"				; cave mode activated (max. 9 char)
	TCODE	tCaveModeShutdown,	"X-Cave-X"				; cave mode shut down (max. 9 char)
 ENDIF


; Divemode menu
	TCODE	tDivePreMenu,		"Menu?"					; Menu?       (max. 5 chars)
 IFDEF _compass
	TCODE	tSetHeading,		"Course"				; set bearing (max. 6 chars)
 ENDIF


; Simulator menu
	TCODE	tQuitSim,			"Quit"					; Quit Simulation (max. 6 chars)
	TCODE	tResetAvg,			"Reset"					; Reset Timer     (max. 6 chars)


; Logbook
	TCODE	tCNS2,				"CNS:"
	TCODE	tAVG,				"Avg:"
	TCODE	tGF,				"GF:"
	TCODE	tSAT,				"Sat:"					; 4 chars max


; Logbook units
	TCODE	tLogTunitC,			"°C"
	TCODE	tLogTunitF,			"°F"
	TCODE	tKGL,				"kg/l"
	TCODE	tMBAR,				"hPa"


; Logbook menu
	TCODE	tNextLog,			"Next Page"


; Reset menu
	TCODE	tReboot,			"Reboot"				; Reboot
	TCODE	tResetMenu2,		"Are you sure?"			; Are you sure?
	TCODE	tAbort,				"Abort"					; Abort
	TCODE	tResetSettings,		"Reset Settings"		; Reset Settings
	TCODE	tResetDeco,			"Reset Deco"			; Reset Deco
	TCODE	tResetBattery,		"Reset Battery"			; Reset Battery
	TCODE	tResetLogbook,		"Reset Logbook"			; Reset Logbook


; Set Time Menu/Set Date Menu
	TCODE	tSetHours,			"Set   Hours"			; Set   Hours
	TCODE	tSetMinutes,		"Set   Minutes"			; Set   Minutes
	TCODE	tSetSeconds,		"clear Seconds"			; clear Seconds
	TCODE	tSetDay,			"Set Day"				; Set Day
	TCODE	tSetMonth,			"Set Month"				; Set Month
	TCODE	tSetYear,			"Set Year"				; Set Year


; Logbook Offset Menu
	TCODE	tLogOffset,			"Logbook Offset"		; Logbook offset
	TCODE	tLogOffsetValue,	"Offset   : "			; Offset
	TCODE	tLogOffStepSize,	"Step Size: "			; Step Size
	TCODE	tLogOffsetplus,		"+"						; increment
	TCODE	tLogOffsetminus,	"-"						; decrement
	TCODE	tLogOffStep1,		"   1"					; 0 adjustment step size 1    | ENUM group
	TCODE	tLogOffStep10,		"  10"					; 1 adjustment step size 10   |
	TCODE	tLogOffStep100,		" 100"					; 3 adjustment step size 100  |
	TCODE	tLogOffStep1000,	"1000"					; 4 adjustment step size 1000 |


; Compass Directions
	TCODE	tN,					"N "					; N(orth),    338°- 22°
	TCODE	tNE,				"NE"					; North-East,  23°- 67°
	TCODE	tE,					"E "					; E(east),     68°-112°
	TCODE	tSE,				"SE"					; South-East, 113°-157°
	TCODE	tS,					"S "					; S(outh),    158°-202°
	TCODE	tSW,				"SW"					; South-West, 203°-247°
	TCODE	tW,					"W "					; W(West),    248°-292°
	TCODE	tNW,				"NW"					; North-West, 293°-337°


; Color Scheme menu
	TCODE	tColorScheme,		"Colour Scheme"			; Colour Scheme
	TCODE	tColorSetDive,		"Divemode:"				; Divemode:
	TCODE	tColorSetName0,		"Standard"				; Standard
	TCODE	tColorSetName1,		"Red"					; Red
	TCODE	tColorSetName2,		"Green"					; Green
	TCODE	tColorSetName3,		"Blue"					; Blue


; pSCR Menu and Settings
 IFDEF _ccr_pscr
	TCODE	tPSCRMenu,			"pSCR Setup"			; pSCR Menu
	TCODE	tPSCR_O2_drop,		"O2 Drop    "			; O2 drop
	TCODE	tPSCR_lungratio,	"Lung Ratio "			; lung ratio
	TCODE	tBackToLoop,		"goto loop"				; back to loop (10 chars max)
 ENDIF


; Language selection
 IF _language_2!=none
	TCODE	tLanguage,			"Language: "			; used in menu_tree
 ENDIF

 IF _language_1==en
	TCODE	tLang1,				"English"				; tLang1 is 1st language, enum context
 ELSE
 IF _language_1==de
	TCODE	tLang1,				"German"
 ELSE
 IF _language_1==fr
	TCODE	tLang1,				"French"
 ELSE
 IF _language_1==it
	TCODE	tLang1,				"Italian"
 ELSE
	TCODE	tLang1,				""						; dummy target for options table
 ENDIF
 ENDIF
 ENDIF
 ENDIF

 IF _language_2==en
	TCODE	tLang2,				"English"				; tLang2 is 2nd language, enum context
 ELSE
 IF _language_2==de
	TCODE	tLang2,				"German"
 ELSE
 IF _language_2==fr
	TCODE	tLang2,				"French"
 ELSE
 IF _language_2==it
	TCODE	tLang2,				"Italian"
 ENDIF
 ENDIF
 ENDIF
 ENDIF
