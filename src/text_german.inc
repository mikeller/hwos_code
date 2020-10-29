;=============================================================================
;
;	File text_german.asm                      next combined generation V3.12.3
;
;	German texts translation file.
;
;	Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================

; Basic texts
	TCODE	tNo,				"Nein"					; 0 No		| Enum group
	TCODE	tYes,				"Ja"					; 1 Yes		|

 IFDEF _cave_mode
	TCODE	tOff,				"Aus"					; OFF		| Enum group
	TCODE	tOn,				"Ein"					; ON		|
 ELSE
	TCODE	tOff,				" "						; needed for option table
 ENDIF

	TCODE	tblank,				" "						; (a single space character)

; Surface-mode texts
	TCODE	tMenu,				"<Menü"					; <Menu
	TCODE	tView,				"View>"					; View>
	TCODE	tHeading,			"Kurs:"					; Heading:
	TCODE	tLastDive,			"Letzter TG"			; Last Dive (Max 10 chars)

	TCODE	tFTTSSurf,			"fTTS/Verz.:"			; Future TTS
	TCODE	tLastDecostopSurf,	"Letzt.Stop:"			; last deco stop surface custom view
	TCODE	tDvSalinitySurf,	"Salinität :"			; Salinity

 IFDEF _external_sensor
	TCODE	tSensorMilliVolt,	"Sensoren mV"			; Sensors mV
 ENDIF


; Divemode Menu - 10 chars max!
	TCODE	tDivemenu_Gaslist,	"Gasliste"				; Gaslist (OC)
	TCODE	tDivemenu_ResetAvg,	"Stoppuhr"				; Reset Avg
	TCODE	tDivemenu_Avg_Mkr,	"Uhr/Marker"			; Reset Avg, Set Marker (and Turn Dive)
	TCODE	tDivemenu_ToggleGF,	"Toggle GF"				; Toggle GF
	TCODE	tDivemenu_Marker,	"Markierung"			; Set Marker
	TCODE	tDivemenu_LostGas,	"Gasverlust"			; Lost Gas

 IFDEF _ccr_pscr
	TCODE	tDivemenu_Diluent,	"Diluents"				; Diluent (CCR)
	TCODE	tDivemenu_Premix,	"Premix"				; Premix  (pSCR)
	TCODE	tDivemenu_Setpoint,	"Setpoint"				; Setpoint
 ENDIF

 IFDEF _external_sensor
	TCODE	tDivemenu_UseSensor,"akt.Sensor"			; Use Sensor
 ENDIF

 IFDEF _cave_mode
	TCODE	tDivePreCave,		"Höhle"					; Enter Cave Menu          ( 5 chars max)
	TCODE	tDivemenu_wp_set,	"Wegepunkt"				; Set Waypoint             (10 chars max)
	TCODE	tDivemenu_wp_out,	"gehe <-()"				; go one Waypoint outwards (10 chars max)
	TCODE	tDivemenu_wp_in,	"gehe ->()"				; go one Waypoint inwards  (10 chars max)
	TCODE	tDivemenu_TurnDive,	"Rückweg"				; Turn Dive                (10 chars max)
	TCODE	tDivemenu_ContDive,	"Fortsetzen"			; Continue Dive            (10 chars max)
	TCODE	tDivemenu_off_on, 	"Aus / Ein"				; Cave Mode Off/On         (10 chars max)
 ENDIF


; Main menu
	TCODE	tNext,				"<Weiter"				; <Next
	TCODE	tEnter,				" Enter>"				; Enter>
	TCODE	tMainMenu,			"Hauptmenü"				; MainMenu
	TCODE	tLogbook,			"Logbuch"				; Logbook
	TCODE	tGasSetup,			"OC Gas Setup"			; OC Gas Setup
	TCODE	tSetTime,			"Zeit einstellen"			; Set Time
	TCODE	tSetDate,			"Datum einstellen"			; Set Date
	TCODE	tSetTimeDate,		"Datum & Uhrzeit"		; Time & Date
	TCODE	tDispSets,			"Anzeige"				; Display Settings
	TCODE	tSysSets,			"System"				; System  Settings
	TCODE	tExit,				"Ende"					; Exit
	TCODE	tResetMenu,			"Reset Menü"			; Reset Menu
	TCODE	tDiveModeMenu,		"TG-Einstellungen"		; Dive Setup

	TCODE	tDiveSetup,			"Tauchgang"				; Dive Setup
	TCODE	tDecoSetup,			"Dekompression"			; Deco Setup
	TCODE	tSACSetup,			"AMV Einstellung"		; SAC Setup
	TCODE	tppO2Setup,			"O2 Partialdruck"		; ppO2 Setup
	TCODE	tStopsSetup,		"Stopps & Tiefen"		; Stops & Depths

	TCODE	tInfoMenu,			"Informationen"			; Information
 IFDEF _ccr_pscr
	TCODE	tCCRSetup,			"CCR/pSCR Setup"			; CCR/pSCR Setup
	TCODE	tDiluentSetup,		"Diluent Menü"			; Diluent Setup
 ENDIF
	TCODE	tFixedSetpoints,	"CCR Setpoints"			; Fixed Setpoints
	TCODE	tBack,				"zurück"				; back
	TCODE	tGas6,				"Extra-Gas"				; edit & select Gas 6

 IFDEF _rx_functions
	TCODE	tTrSettings,		"Druckanzeige"			; Pressure Display
	TCODE	tTrMode,			"Modus: "				; Mode
	TCODE	tTr1stPres,			"1.Druck: "				; 1st Pressure
	TCODE	tTr2ndPres,			"2.Druck: "				; 2nd Pressure
	TCODE	tTrBailPres,		"1.B/O  : "				; Bailout Pressure
	TCODE	tTrMaxDeltaP,		"max Diff.: "			; independent double max difference
 ENDIF

 IFDEF _external_sensor
;	TCODE	tCCRSensor,			"Sensor"				; CCR/pSCR Sensor
	TCODE	tCalibrateMenu,		"Kalibrierung"			; Calibration
	TCODE	tCalibrationGas,	"Kal. Gas O2:"			; Cal. Gas O2:
	TCODE	tCalibrate,			"Kalibrieren"			; Calibrate
	TCODE	tS8Mode,			"S8 Eingang:"			; Sensor Input
	TCODE	tCCRS8Mode,			"Analog"				; Analog
	TCODE	tCCRS8Mode2,		"Digital"				; Digital
 ELSE
	TCODE	tCCRS8Mode,			" "						; needed for option table
 ENDIF


; Gas menu
	TCODE	tGaslist,			"OC Gas Liste"
	TCODE	tGaslistCC,			"CC Gas Liste"			; CC Diluents
	TCODE	tGasEdit,			"Gas einstellen"
	TCODE	tType,				"Typ: "
	TCODE	tGasDisabled,		"Deaktiviert"			; | ENUM 1: Disabled
	TCODE	tGasFirst,			"Start"					; |      2: First
	TCODE	tGasTravel,			"Arbeit"				; |      3: Work (Travel, Bottom)
	TCODE	tGasDeco,			"Deko"					; |      4: Deco
	TCODE	tAir,				"Air  "					; | ENUM: values must follow (5 chars)
	TCODE	tO2,				"O2   "					; |       tAir + 5
	TCODE	tO2Plus,			"O2 +"
	TCODE	tO2Minus,			"O2 -"
 IFDEF _helium
	TCODE	tHePlus,			"He +"
	TCODE	tHeMinus,			"He -"
 ENDIF
	TCODE	tMOD,				"MOD :"
	TCODE	tEAD,				"EAD:"
	TCODE	tSetup_GasDepth,	"Wechseltiefe"
	TCODE	tDepthPlus,			"Tiefe +"
	TCODE	tDepthMinus,		"Tiefe -"
	TCODE	tDepthReset,		"Reset auf MOD:"
	TCODE	tSetup_GasMix,		"Mix einstellen"
 IFDEF _ccr_pscr
	TCODE	tSPPlus,			"ppO2  +"				; Setpoint ppO2 +
	TCODE	tSensorFallback,	"Fallback:"				; Fallback:
	TCODE	tCalculated,		"berechnet"				; calculated
	TCODE	tppO2O2,			"ppO2(O2)"				; ppO2(O2)
	TCODE	tppO2Dil,			"ppO2(Dil)"				; ppO2(Dil)
	TCODE	tppO2Mix,			"ppO2(Mix)"				; ppO2(Mix)
	TCODE	tCCRMode,			"Modus: "				; CCR/pSCR Mode
	TCODE	tCCRModeFixedSP,	"FesterSP"				; 0 fixed for CCR / calculated for pSCR  | ENUM group
	TCODE	tCCRModeSensor,		"Sensor"				; 1 Sensor                               |
	TCODE	tCCRModeAutoSP,		"Auto SP"				; 2 Auto SP                              |
 ELSE
	TCODE	tCCRModeFixedSP,	" "						; target needed by option table
 ENDIF
	TCODE	tSP,				"SP"					; SP (SetPoint)


; New batteries menu
	;                                     1         2	;
	;                            12345678901234567890	; max 20 chars
	TCODE	tNewBattTitle,		"Neue Batterie?"
	TCODE	tNewBattOld,		"behalte alte"
	TCODE	tNewBattNew36,		"3,6V Einweg    (T1)"	; new 3.6V disposable
	TCODE	tNewBattNew15,		"1,5V Einweg    (T0)"	; new 1.5V disposable
	TCODE	tNewBattAccu,		"3,7V aufladbar (T2)"	; new 3.7V rechargeable
	TCODE	tNew18650,		"OSTC 2(2015), cR(T3)"	; internal battery on 2 (old) / cR
	TCODE	tNew16650,		"OSTC 2(2017), TR(T4)"	; internal battery on 2 (new) / TR
	TCODE	tConfirmChargeable1,"Bestätigung:"			; safety question, line 1
	TCODE	tConfirmChargeable2,"eingelegte Batterie"	; safety question, line 2
	TCODE	tConfirmChargeable3,"ist wiederaufladbar"	; safety question, line 3


; Gaslist management
	TCODE	tGas,				"Gas"					; Gas
	TCODE	tDil,				"Dil"					; Diluent
	TCODE	tGasErr,			"Err"					; Err      (max 3 chars)
	TCODE	tTakeGas,			"nimm"					; take gas (max 4 chars)


; Communication Menu
	TCODE	tUsbTitle,			"USB Modus"
	TCODE	tBleTitle,			"Bluetooth Modus"
	TCODE	tUsbStarting,		"Starte..."
	TCODE	tUsbStartDone,		"Fertig."
	TCODE	tUsbServiceMode,	"Servicemodus aktiv"
	TCODE	tUsbClosed,			"Abgebrochen"
	TCODE	tUsbExit,			"Beendet"
	TCODE	tUsbDownloadMode,	"Downloadmodus aktiv"
	TCODE	tUsbLlBld,			"Low-Level Bootloader"


; Dive Settings
	TCODE	tDvMode,			"Betriebsart : "		; Dive Mode
 IFDEF _cave_mode
	TCODE	tCvMode,			"Höhlenmodus : "		; Cave Mode
 ENDIF
	TCODE	tFTTSMenu,			"fTTS/Verz.  : "		; Future TTS
	TCODE	tTimeoutDive,		"TG-Ende nach: "		; Dive Timeout
	TCODE	tStoreApnoeDive,	"Log Apnoe   : "		; Store Apnoe Dives
	TCODE	tDvOC,				"OC"					; 0 | keep order, enum!
	TCODE	tDvCCR,				"CCR"					; 1 |
	TCODE	tDvGauge,			"Gauge"					; 2 |
	TCODE	tDvApnea,			"Apnoe"					; 3 |
	TCODE	tDvPSCR,			"pSCR"					; 4 |
	TCODE	tDvCC,				"CC"
	TCODE	tDkMode,			"Decotyp: ZH-L16"
	TCODE	tZHL16,				" "						; keep order, enum from here...
	TCODE	tZHL16GF,			"+GF"					; ...up to here!
	TCODE	tPPO2Max,			"Max. Arbeit:"
	TCODE	tPPO2DECO,			"Max. Deko  :"
 IFDEF _ccr_pscr
	TCODE	tPPO2MIN,			"Min. OC    :"
	TCODE	tPPO2MINCC,			"Min. Loop  :"
 ELSE
	TCODE	tPPO2MIN,			"Min.       :"
 ENDIF
	TCODE	tDecoparameters,	"Deko Parameter"
	TCODE	tGF_low,			"GF  low :"
	TCODE	tGF_high,			"GF  high:"
	TCODE	tSaturationMult,	"Sättigung   : "
	TCODE	tDesaturationMult,	"Entsättigung: "
	TCODE	tGFMenu,			"GF Parameter"			; GF Settings
	TCODE	tSDMenu,			"SD Parameter"			; SD Settings
	TCODE	taGF_low,			"aGF low :"				; aGF low
	TCODE	taGF_high,			"aGF high:"				; aGF high
	TCODE	taGFenable,			"aGF wählbar:"			; aGF Selectable
	TCODE	tDiveaGF_active,	"aGF aktiv"				; using aGF
	TCODE	tSafetyStop,		"Sicherheitsstop:"		; Safety Stop:  (max. 16 chars)
	TCODE	tExtendedStops,		"erweit. Stopps :"		; Extended Stops
	TCODE	tLastDecostop,		"Letzt.Stop : "			; last Deco Stop Depth
	TCODE	tDvSalinity,		"Salinität  : "			; Salinity
	TCODE	tDepthWarn,			"Tiefenlimit:"			; Depth Warning (no space after ':' on purpose)
	TCODE	tGasUsage,			"Gasbedarf"				; Gas Usage
	TCODE	tSetWorkSAC,		"Arbeits AMV:"			; SAC Work:
	TCODE	tSetDecoSAC,		"Deko    AMV:"			; SAC Deco:
	TCODE	tCalcGasNeeds,		"Gasmenge(B/O): "		; Calculate  Gas (Bail Out) Needs
 IFDEF _gas_contingency
	TCODE	tGasContingencyDive,"Swap on empty: "		; swap tank on becoming empty
 ENDIF
	TCODE	tGasChangeTime,		"Gaswechselzeit:+"		; additional Gas Change Time
	TCODE	tSetup_Tank,		"Flasche"		; Setup Tank
	TCODE	tTankSize,			"Flaschengröße:"			; Tank Size 
	TCODE	tTankUsablePress,	"Umkehrdruck: "			; Tank Pressure Budget for Ascent (turn pressure)
	TCODE	tLiter,				" l"					; Liter as l
	TCODE	tLiterLong,			"Liter"					; Liter as Liter
	TCODE	t2ndDecoPlanMenu,	"2.Deko Plan"			; 2nd Deco Plan

 IFDEF _ccr_pscr
	TCODE	tCCmaxFracO2,		"Loop %O2 max. : "		; max O2 percent (absolute) in the loop
	TCODE	tDilppO2Check,		"Prüfe Dil ppO2: "		; check ppO2 of the diluent against the setpoint
	TCODE	tGasDensityCheck,	"..   Gasdichte: "		; check Gas Density
	TCODE	tPSCR_O2_drop,		"pSCR O2 Abfall: "		; pSCR O2 Drop
	TCODE	tPSCR_lungratio,	".. Lungenverh.: "		; pSCR Lung Ratio
	TCODE	tCopyDilToOC,		"Kopiere Dil.-> OC"		; copy diluent settings to OC gas
	TCODE	tBackToLoop,		"auf Loop"				; back to loop (10 chars max)
 ENDIF

 IFDEF _rx_functions
	TCODE	tTankPairing,		"Sender wählen"			; select Transmitter
	TCODE	tTrModeOff,			"aus"					; off
	TCODE	tTrModeOn,			"ein"					; on
	TCODE	tTrModeIndDouble,	"unabh.Doppel"			; independent double
	TCODE	tTrModeCCR,			"CCR Dil+O2"			; CCR diluent and O2
	TCODE	tTrPresNone,		"keiner"				; none  (big enum group follows)
	TCODE	tTrPresGas1,		"Gas 1"					; Gas 1
	TCODE	tTrPresGas2,		"Gas 2"					; Gas 2
	TCODE	tTrPresGas3,		"Gas 3"					; Gas 3
	TCODE	tTrPresGas4,		"Gas 4"					; Gas 4
	TCODE	tTrPresGas5,		"Gas 5"					; Gas 5
 IFDEF _ccr_pscr
	TCODE	tTrPresDil1,		"Dil 1"					; Dil 1
	TCODE	tTrPresDil2,		"Dil 2"					; Dil 2
	TCODE	tTrPresDil3,		"Dil 3"					; Dil 3
	TCODE	tTrPresDil4,		"Dil 4"					; Dil 4
	TCODE	tTrPresDil5,		"Dil 5"					; Dil 5
	TCODE	tTrPresFirstGas,	"erstes Gas"			; first  Gas
	TCODE	tTrPresActiveGas,	"aktives Gas"			; active Gas
	TCODE	tTrPresFirstDil,	"erstes Dil"			; first  Dil
	TCODE	tTrPresActiveDil,	"aktives Dil"			; active Dil
 ENDIF
 ELSE
 	TCODE	tTrModeOff,			""						; dummy target for entry in option table
	TCODE	tTrPresNone,		""						; dummy target for entry in option table
 ENDIF	; _rx_functions


; Display Settings
	TCODE	tBright,			"Helligkeit: "			; Brightness
	TCODE	tLayout,			"Layout    : "			; Layout
	TCODE	tUnits,				"Einheiten : "			; Units
 IF _language_2!=none
	TCODE	tLanguage,			"Sprache   : "			; Language
 ENDIF
	TCODE	tFlip,				"Anzeige drehen: "		; Rotate Screen
	TCODE	tColorScheme,		"Farbschema"			; Colour Scheme
	TCODE	tVSIgraph,			"Geschw.Grafik: "		; Speed Graph
	TCODE	tVSItext2,			"...   adaptiv: "		; variable Speed
	TCODE	tShowppO2,			"ppO2 immer   : "		; always show ppO2
	TCODE	tDepthWarning,		"Tiefe blinken: "		; Depth blinking
	TCODE	t2ndDepth,			"2.Tiefe: "				; 2nd Depth Display Content (11 chars max)
	TCODE	tTissueGraphics,	"Grafik : "				; Tissue Graphics

	TCODE	tIBCDwarning,		"IBCD  Warnung: "		; IBCD warning
	TCODE	tEco,				"Eco"					; eco     | ENUM group
	TCODE	tMedium,			"Mittel"				; medium  |
	TCODE	tHigh,				"Hoch"					; high    |
	TCODE	tLayoutNormal,		"normal"				; normal  | ENUM group
	TCODE	tLayoutBig,			"groß"					; big     |
	TCODE	tMax,				"max."					; max     | ENUM group
	TCODE	tAvg,				"mittel"				; average |
	TCODE	tTissuePresSat,		"Druck+Sat."			; pressure and saturation | ENUM group
 IFDEF _helium
	TCODE	tTissueN2He,		"N2+He"					; N2 + He pressure        |
 ENDIF


; Setup Menu
	TCODE	tSystSets,			"Konfiguration"			; System Settings
 IFDEF _compass
	TCODE	tCompassMenu,		"Kompass"				; Compass
	TCODE	tCompassCalibration,"Kalibrierung"			; Calibration
	TCODE	tCompassGain,		"Empfindlichkeit:"		; Compass gain:
	TCODE	tCalX,				"Kal. X"				; Cal X
	TCODE	tCalY,				"Kal. Y"				; Cal Y
	TCODE	tCalZ,				"Kal. Z"				; Cal Z
 ENDIF
	TCODE	tMetric,			" m/°C"					; Enum menu
	TCODE	tImperial,			"ft/°F"
								;         111         111         111         111         111
	; 5 rows by 12 chars each:	 123456789012123456789012123456789012123456789012123456789012
	TCODE	tDefName,		"HW OSTC"
	TCODE	tPiezo,			"Taster"				; Buttons
	TCODE	tButtonExplain1,	"Weniger % ist"			; Less % is 
	TCODE	tButtonExplain2,	"empfindlicher."		; more sensitive.
	TCODE	tButtonleft,		"Taster links :"		; Left button
	TCODE	tButtonright,		"Taster rechts:"		; Right button
	TCODE	tAltMode,		"Wartezeit:"
	TCODE	tAltModeFly,		"Fliegen"
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
	TCODE	tDateformat,		"MMTTJJ"
	TCODE	tDateformat1,		"TTMMJJ"
	TCODE	tDateformat2,		"JJMMTT"


; Simulator menu
	TCODE	tInter,				"Start Simulator"		; Start Simulator
	TCODE	tSimulator,			"Simulator"				; Simulator


; Decoplanner submenu
	TCODE	tBtTm,				"Grundzeit  : "			; Bot. Time: (10 chars)
	TCODE	tBtTm_short,		"Zeit :"				; Bot. Time: (max. 6 chars)
	TCODE	tBtDep,				"Tiefe      : "			; Max Depth: (10 chars)
	TCODE	tIntvl,				"Intervall  : "			; Interval : (10 chars)
	TCODE	tCalculatorSetup,	"Deko Parameter"		; Calculator Setup
	TCODE	tDeco,				"Deko Berechnung"		; Calculate Deco
	TCODE	tDivePlan,			"Tauchplan"				; Dive Plan (max. 10 chars)
	TCODE	tNoDeco,			"Keine Deko"			; No Deco
	TCODE	tMore,				"mehr"					; More
	TCODE	tSelectSetpoint,	"Setpoint   : "
	TCODE	tuseAGF,			"Benutze aGF: "
 IFDEF _gas_contingency
	TCODE	tGasContingencySim,	"Gas Cont. : "			; Gas Contingency			## translation pending
 ENDIF

; Decoplanner progress indication
	TCODE	tNoBottomGas1,		"  kein auf der Tiefe"	; no usable Gas for Bottom Depth found (line 1, max. 22 chars)	## pending translation
	TCODE	tNoBottomGas2,		"nutzbares Gas gefunden"; no usable Gas for Bottom Depth found (line 2, max. 22 chars)	## pending translation
	TCODE	tCalculating,		"Berechnung läuft..."
	TCODE	tCalcSurfInter,		"Oberflächenpause"		; Surface Interval
	TCODE	tCalcBotSeg,		"Grundzeit"				; Bottom Segment
	TCODE	tCalcBailout,		"Wechsel auf Bailout"	; Switch to Bailout
	TCODE	tCalcAscent,		"Aufstieg"				; Ascent (max. 8 chars)
	TCODE	tNDLleft,			"übrig"					; time left within NDL


; Information menu
	TCODE	tFirmware,			"Firmware: "			; Firmware: (space)
	TCODE	tFirmwareDate,		"erstellt: "			; created : (space)  firmware creation date
	TCODE	tHardware,			"Hardware: "			; Hardware: (space)
	TCODE	tSerial,			"Seriennr: "			; Serial  : (space)
	TCODE	tBatteryV,			"Batterie: "			; Battery : (space)
	TCODE	tSensorC,			"Sensor  : "			; Sensor  : (space)
	TCODE	tSensorD,			"Offset  : "			; Offset  : (space)
	TCODE	tUptime,			"Laufzeit: "			; Uptime:

 IFDEF _rx_functions
	TCODE	tFirmware_rx,		"RX Ver  : "			; RX Ver  : (space)
 ENDIF


; Divemode screen
	TCODE	tNDL,				" NZ"					; 3 chars
	TCODE	tTTS,				"TTS"					; 3 chars
	TCODE	tSlow,				"langsam"				; slow - max 7 chars
	TCODE	tVelMetric,			"m/min"
	TCODE	tVelImperial,		"ft/m "
	TCODE	tGasSelect,			"Wähle Gas"				; Select Gas
	TCODE	tSelectAir,			"Luft"					; Air
	TCODE	tSelectO2,			"O2  "					; O2
	TCODE	tSelectNx,			"Nx"					; Nx
	TCODE	tSelectTx,			"Tx"					; Tx
	TCODE	tDepth,				"Tiefe"					; Depth (max 5 chars)
	TCODE	tMaxDepth,			"Max.Tiefe"				; Max.Depth     - max 9 chars!
	TCODE	tAvgDepth,			"Durchschn."			; average Depth - max 9 chars! (extra dot is ok)
	TCODE	tDivetime,			"Dauer"					; Divetime (max 8 chars)
	TCODE	tDiveTotalAvg,		"Durchschn.1"
	TCODE	tDiveStopwatch,		"Stoppuhr"
	TCODE	tDiveStopAvg,		"Durchschn.2"			; 11 chars max
	TCODE	tApnoeTotal,		" Total"				; Total (six chars, right aligned)
	TCODE	tApnoeMax,			"  Letzter TG"			; Last descend
	TCODE	tApnoeSurface,		"Oberfläche"			; Surface Time
	TCODE	tTime,				"Uhrzeit"				; Time
	TCODE	tSurface,			"Oberfläche"			; Surface (max 12 chars)
	TCODE	tDiveDecoplan,		"nächste Stopps"		; next Stops
;	TCODE	tDiveClock,			"Uhr"					; Clock
	TCODE	tDiveEAD_END,		"EAD/END"				; EAD/END
	TCODE	tDiveTissues,		"Gewebe"				; Tissues
	TCODE	tEND,				"END:"					; END:
	TCODE	tN2,				"N2"					; N2
	TCODE	tDiveBailout,		"Bailout"				; Bailout (max. 7 chars)
	TCODE	tGFactors,			"GF Werte"				; GF Values
	TCODE	taGFactors,			"aGF Werte"				; aGF Values
	TCODE	tGFInfo,			"Sättigung"				; Saturation
	TCODE	tCeiling,			"Ceiling"				; Ceiling
	TCODE	tDiveFallback,		"Fallback!"				; Fallback! (max. nine chars)
	TCODE	tDecoInfo,			"Deko Zone"				; Deco info
	TCODE	tSensorCheck,		"Sensor Test"			; Sensor Check
	TCODE	tdil,				"Dil:"					; Diluent ppO2 Warning
	TCODE	tmix,				"Mix:"					; Pre-Mix ppO2 Warning
	TCODE	tGasNeedsWarn,		"Gasbedarf"				;
	TCODE	tCNSsurf,			"ZNS Oberfl."			;
	TCODE	tCNSfTTS,			"ZNS fTTS"				;
	TCODE	tCNSBO,				"ZNS B/O"				;
	TCODE	tCNSnow,			"ZNS jetzt"				;
	TCODE	tCNSeod,			"ZNS Ende"				;
 IFDEF _cave_mode
	TCODE	tCNScave,			"ZNS Höhle"				;
 ENDIF
	TCODE	tnoBOgas,			"-B/O-Gas-"				;
	TCODE	tMicroBubbles,		"M.Blasen"				;
	TCODE	tCNS,				"ZNS: "					;
	TCODE	tgaschange,			"wechseln?"				; better gas found
	TCODE	tNeed,				"Bedf."					; gas need (5 chars)
	TCODE	tBattery,			"Batterie"				; Battery
	TCODE	tSAT,				"Sät:"					; Sat:  (max 4 chars)
	TCODE	tppO2,				"ppO2:"					; ppO2: (max 5 chars)

 IFDEF _helium
	TCODE	tHe,				"He"					; He
	TCODE	tIBCD,				"IBCD N2He"				; IBCD warning (max. 9 chars)
 ENDIF

 IFDEF _ccr_pscr
	TCODE	tGasDensity,		"Gasdichte"				; Gas Density  (max. 9 chars)
 ENDIF

 IFDEF _rx_functions
	TCODE	tTransmitter,		"TR Sender"				; pressure transmitter
	TCODE	tPressure,			"Fl.Druck"				; tank pressure
	TCODE	tSAC,				"AMV"					; SAC, must be 3 chars!
	TCODE	tswap,				"wechseln"				; switch tank (max. 9 chars)
 ENDIF

 IFDEF _external_sensor
	TCODE	tDiveHudMask1,		"Sensor 1"
	TCODE	tDiveHudMask2,		"Sensor 2"
	TCODE	tDiveHudMask3,		"Sensor 3"
	TCODE	tSensorDisagree,	"Sensoren!"				; Sensors disagree Warning
 ENDIF

 IFDEF _cave_mode
	TCODE	tGasNeedsCaveMode,	"Gasbedarf -HÖHLE- "	; title for gas needs custom view (cave mode)		| need to be
	TCODE	tGasNeedsAscent,	"Gasbedarf Aufstieg"	; title for gas needs custom view (open water mode)	| same length
	TCODE	tCaveMode,			"Höhle"					; cave mode activated (max. 9 char)
	TCODE	tCaveModeShutdown,	"X-Höhle-X"				; cave mode shut down (max. 9 char)
	TCODE	tCaveTTS,			"Cave TTS"				; cave mode total time to surface
	TCODE	tCaveStops,			"total Stops"			; cave mode total time for stops
	TCODE	tCaveRuntime,		"total RT"				; cave mode total runtime
 ELSE
	TCODE	tGasNeedsAscent,	"Gasbedarf Aufstieg"	; title for gas needs custom view
 ENDIF


; Divemode menu
	TCODE	tDiveAckn,			"Best?"					; Ackn?  (max. 5 chars)
	TCODE	tDivePreMenu,		"Menü?"					; Menu?  (max. 5 chars)
	TCODE	tDiveLayout,		"Layout"				; Layout (max. 6 chars)
 IFDEF _compass
	TCODE	tSetHeading,		"Kurs"					; Course (max. 6 chars)
 ENDIF


; Simulator menu
	TCODE	tQuitSim,			"Ende"					; Quit Simulation (max. 6 chars)
	TCODE	tResetAvg,			"Reset"					; Reset Timer     (max. 6 chars)


; Logbook
	TCODE	tCNS2,				"ZNS:"
	TCODE	tAVG,				"Mit:"
	TCODE	tGF2,				"GF :"
	TCODE	tSD2,				"S/D: "
	TCODE	tDvSalinity2,		"Salinität :"			; max 11 chars
	TCODE	tLastDeco,			"Letzt.Stop:"			; max 11 chars
	TCODE	tNoProfileData,		"keine Daten mehr..."	; max 21 chars
	TCODE	tBeginOfDive,		"Beginn:"				; max  8 chars
	TCODE	tEndOfDive,			"Ende:"					; max  8 chars
	TCODE	tDesatTime,			"Desat:"				; amx  8 chars

; other useser
	TCODE	tGF,				"GF:"					; GF Factors                (3 chars)
	TCODE	tSD,				"S/D"					; Saturation / Desaturation (3 chars)

; Logbook units
	TCODE	tLogTunitC,			"°C"
	TCODE	tLogTunitF,			"°F"
	TCODE	tKGL,				"kg/l"
	TCODE	tMBAR,				"hPa"


; Logbook menu
	TCODE	tNextLog,			"Nächste Seite"


; Reset menu
 IFDEF _firmware_recovery
	TCODE	tReboot,			"Neustart/Backup"		; Reboot/Backup
 ELSE
	TCODE	tReboot,			"Neu starten"			; Reboot
 ENDIF
	TCODE	tResetMenu2,		"Sind Sie sicher?"		; Are you sure?
	TCODE	tAbort,				"Abbrechen"				; Abort
	TCODE	tResetSettings,		"Reset Einstellungen"	; Reset Settings (max. 19 chars)
	TCODE	tResetDeco,			"Reset Deko"			; Reset Deco
	TCODE	tResetBattery,		"neue Batterie"			; Reset Battery
	TCODE	tResetLogbook,		"Logbuch löschen"		; Reset Logbook

 IFDEF _firmware_recovery
	TCODE	tRebootCurFirmware,	"Reboot aktuelle FW"	; Reboot current Firmware
	TCODE	tBackupFirmware,	"Backup aktuelle FW"	; Backup current Firmware
	TCODE	tRecoverFirmware,	"lade  "				; Recover (version will be appended)
	TCODE	tBackingUp,			"Sicherung läuft..."	; backing up current firmware
	TCODE	tRestoring,			"Wiederherstellung..."	; restoring  backup  firmware
 ENDIF


; Set Time Menu/Set Date Menu
	TCODE	tSetHours,			"Stunden einst."		; Set Hours
	TCODE	tSetMinutes,		"Minuten einst."		; Set Minutes
	TCODE	tSetSeconds,		"Sekunden zurücks."		; Clear seconds
	TCODE	tSetDay,			"Setze Tag"				; Set Day
	TCODE	tSetMonth,			"Setze Monat"			; Set Month
	TCODE	tSetYear,			"Setze Jahr"			; Set Year


; Logbook Offset Menu
	TCODE	tTotalDives,		"Anzahl TG: "			; Total Dives
	TCODE	tLogOffset,			"Logbuch-Offset"		; Logbook offset
	TCODE	tLogOffsetValue,	"Offset      : "		; Offset
	TCODE	tLogOffStepSize,	"Schrittweite: "		; Step Size
	TCODE	tLogOffsetplus,		"+"						; increment
	TCODE	tLogOffsetminus,	"-"						; decrement
	TCODE	tLogOffStep1,		"   1"					; adjustment step size 1    | ENUM group
	TCODE	tLogOffStep10,		"  10"					; adjustment step size 10   |
	TCODE	tLogOffStep100,		" 100"					; adjustment step size 100  |
	TCODE	tLogOffStep1000,	"1000"					; adjustment step size 1000 |


; Compass directions
	TCODE	tN,					"N "					; N(orth),    338°-22°
	TCODE	tNE,				"NO"					; North-East,  23°-67°
	TCODE	tE,					"O "					; E(east),     68°-112°
	TCODE	tSE,				"SO"					; South-East, 113°-157°
	TCODE	tS,					"S "					; S(outh),    157°-202°
	TCODE	tSW,				"SW"					; South-West, 203°-247°
	TCODE	tW,					"W "					; W(West),    248°-292°
	TCODE	tNW,				"NW"					; North-West, 293°-337°


; Color Scheme menu
	TCODE	tColorSetDive,		"Tauchmodus:"			; Divemode:
	TCODE	tColorSetName0,		"Standard"				; Standard
	TCODE	tColorSetName1,		"Rot"					; Red
	TCODE	tColorSetName2,		"Grün"					; Green
	TCODE	tColorSetName3,		"Blau"					; Blue


; Debug Stuff
 IFDEF _comm_debug
	TCODE	tCommTimeout,		"RX Timeout: "
	TCODE	tCommTimeoutU,		"0 ms"
 ENDIF


; Language selection
 IF _language_1==en
	TCODE	tLang1,				"EN"					; tLang1 is 1st language, enum context
 ELSE
 IF _language_1==de
	TCODE	tLang1,				"DE"
 ELSE
 IF _language_1==fr
	TCODE	tLang1,				"FR"
 ELSE
 IF _language_1==it
	TCODE	tLang1,				"IT"
 ELSE
	TCODE	tLang1,				""						; dummy target for options table
 ENDIF
 ENDIF
 ENDIF
 ENDIF

 IF _language_2==en
	TCODE	tLang2,				"EN"					; tLang2 is 2nd language, enum context
 ELSE
 IF _language_2==de
	TCODE	tLang2,				"DE"
 ELSE
 IF _language_2==fr
	TCODE	tLang2,				"FR"
 ELSE
 IF _language_2==it
	TCODE	tLang2,				"IT"
 ENDIF
 ENDIF
 ENDIF
 ENDIF
