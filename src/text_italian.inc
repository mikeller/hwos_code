;=============================================================================
;
;	File text_italian.asm                     next combined generation V3.12.3
;
;	Italian texts translation file.
;
;	Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================

; Basic texts
	TCODE	tNo,				"No"					; 0 No		| Enum group
	TCODE	tYes,				"Si"					; 1 Yes		|

 IFDEF _cave_mode
	TCODE	tOff,				"off"					; OFF		| Enum group
	TCODE	tOn,				"on"					; ON		|
 ELSE
	TCODE	tOff,				" "						; needed for option table
 ENDIF

	TCODE	tblank,				" "						; (a single space character)

; Surface-mode texts
	TCODE	tMenu,				"<Menu"					; <Menu
	TCODE	tView,				"Vedi>"					; View>
	TCODE	tHeading,			"Direzione:"			; Heading:
	TCODE	tLastDive,			"UltimaImm."			; Last Dive (Max 10 chars)

	TCODE	tFTTSSurf,			"TTS Futuro:"			; Future TTS
	TCODE	tLastDecostopSurf,	"UltimaTappa:"			; last deco stop surface custom view
	TCODE	tDvSalinitySurf,	"Salinita':"			; Salinity

 IFDEF _external_sensor
	TCODE	tSensorMilliVolt,	"Sensori mV"			; Sensors mV
 ENDIF


; Divemode Menu
	TCODE	tDivemenu_Gaslist,	"Lista Gas"				; Gaslist  (OC)
	TCODE	tDivemenu_ResetAvg,	"AzzeraMed"				; Reset Avg
	TCODE	tDivemenu_Avg_Mkr,	"Med/Segna"				; Reset Avg, Set Marker (and Turn Dive)	
	TCODE	tDivemenu_ToggleGF,	"Alterna GF"			; Toggle GF
	TCODE	tDivemenu_Marker,	"Set Marker"			; Set Marker
	TCODE	tDivemenu_LostGas,	"Gas perso"				; Lost Gas

 IFDEF _ccr_pscr
	TCODE	tDivemenu_Diluent,	"Lista Dil"				; Diluents (CCR)
	TCODE	tDivemenu_Premix,	"Lista Mix"				; Premix   (pSCR)
	TCODE	tDivemenu_Setpoint,	"Setpoint"				; Setpoint
 ENDIF

 IFDEF _external_sensor
	TCODE	tDivemenu_UseSensor,"Usa Sensori"			; Use Sensor
 ENDIF

 IFDEF _cave_mode
	TCODE	tDivePreCave,		"Cave?"					; Enter Cave Menu          ( 5 chars max)
	TCODE	tDivemenu_wp_set,	"Waypoint"				; Set Waypoint             (10 chars max)
	TCODE	tDivemenu_wp_out,	"WP go <-()"			; go one Waypoint outwards (10 chars max)
	TCODE	tDivemenu_wp_in,	"WP go ->()"			; go one Waypoint inwards  (10 chars max)
	TCODE	tDivemenu_TurnDive,	"Turn Dive"				; Turn Dive                (10 chars max)
	TCODE	tDivemenu_ContDive,	"Cont.Dive"				; Continue Dive            (10 chars max)
	TCODE	tDivemenu_off_on, 	"Off / On"				; Cave Mode Off/On         (10 chars max)
 ENDIF


; Main menu
	TCODE	tNext,				"<Prossimo"				; <Next
	TCODE	tEnter,				" Enter>"				; Enter>
	TCODE	tMainMenu,			"Menu Principale"		; MainMenu
	TCODE	tLogbook,			"Logbook"				; Logbook
	TCODE	tGasSetup,			"Imposta Gas OC"		; OC Gas Setup
	TCODE	tSetTime,			"Imposta Ora"			; Set Time
	TCODE	tSetDate,			"Imposta Data"			; Set Date
	TCODE	tSetTimeDate,		"Ora e Data"			; Time & Date
	TCODE	tDispSets,			"Visualizzazione"		; Display Settings
	TCODE	tSysSets,			"System Settings"		; System  Settings
	TCODE	tExit,				"Esci"					; Exit
	TCODE	tResetMenu,			"Resetta Menu"			; Reset Menu
	TCODE	tDiveModeMenu,		"Modalita' Deco"		; Dive Setup

	TCODE	tDiveSetup,			"Dive Setup"			; Dive Setup
	TCODE	tDecoSetup,			"Deco Setup"			; Deco Setup
	TCODE	tSACSetup,			"SAC  Setup"			; SAC Setup
	TCODE	tppO2Setup,			"ppO2 Setup"			; ppO2 Setup
	TCODE	tStopsSetup,		"Stops & Depths"		; Stops & Depths

	TCODE	tInfoMenu,			"Informazioni"			; Information
 IFDEF _ccr_pscr
	TCODE	tCCRSetup,			"Imposta CCR"			; CCR Setup
	TCODE	tDiluentSetup,		"Imposta Diluente"		; Diluent Setup
 ENDIF
	TCODE	tFixedSetpoints,	"Setpoints Fissi"		; Fixed Setpoints
	TCODE	tBack,				"indietro"				; back
	TCODE	tGas6,				"Gas extr"				; edit & select Gas 6

 IFDEF _rx_functions
	TCODE	tTrSettings,		"Display Press.ni"		; Pressure Display
	TCODE	tTrMode,			"Modo: "				; Mode
	TCODE	tTr1stPres,			"1a Pres: "				; 1st Pressure
	TCODE	tTr2ndPres,			"2a Pres: "				; 2nd Pressure
	TCODE	tTrBailPres,		"1a B/O  : "			; Bailout Pressure
	TCODE	tTrMaxDeltaP,		"DeltaP Max: "			; independent double max diffenerce
 ENDIF

 IFDEF _external_sensor
;	TCODE	tCCRSensor,			"Sensori CCR"			; CCR Sensor
	TCODE	tCalibrateMenu,		"Calibrazione"			; Calibration
	TCODE	tCalibrationGas,	"Cal. Gas O2:"			; Cal. Gas O2:
	TCODE	tCalibrate,			"Calibra"				; Calibrate
	TCODE	tS8Mode,			"S8 Input: "			; Sensor Input
	TCODE	tCCRS8Mode,			"Analog"				; Analog
	TCODE	tCCRS8Mode2,		"Digital"				; Digital
 ELSE
	TCODE	tCCRS8Mode,			" "						; needed for option table
 ENDIF


; Gas menu
	TCODE	tGaslist,			"Lista Gas OC"
	TCODE	tGaslistCC,			"Lista Gas CC"			; CC Diluents
	TCODE	tGasEdit,			"Modifica Gas"
	TCODE	tType,				"Tipo: "
	TCODE	tGasDisabled,		"Disabilitato"			; | ENUM 1: Disabled
	TCODE	tGasFirst,			"Primo"					; |      2: First
	TCODE	tGasTravel,			"Lavoro" 				; |      3: Work (Travel, Bottom) ("Viaggio")
	TCODE	tGasDeco,			"Deco"					; |      4: Deco
	TCODE	tAir,				"Aria "					; | ENUM: values must follow (5 chars)
	TCODE	tO2,				"O2   "					; |       tAir + 5
	TCODE	tO2Plus,			"O2 +"
	TCODE	tO2Minus,			"O2 -"
 IFDEF _helium
	TCODE	tHePlus,			"He +"
	TCODE	tHeMinus,			"He -"
 ENDIF
	TCODE	tMOD,				"MOD :"
	TCODE	tEAD,				"EAD:"
	TCODE	tSetup_GasDepth,	"Cambia Profondita'"
	TCODE	tDepthPlus,			"Profondita' +"
	TCODE	tDepthMinus,		"Profondita' -"
	TCODE	tDepthReset,		"Reset a MOD:"
	TCODE	tSetup_GasMix,		"Cambia Gas"
 IFDEF _ccr_pscr
	TCODE	tSPPlus,			"ppO2 +"				; Setpoint ppO2 +
	TCODE	tSensorFallback,	"Fallback:"				; Fallback:
	TCODE	tCalculated,		"Calcolato"				; calculated
	TCODE	tppO2O2,			"ppO2(O2)"				; ppO2(O2)
	TCODE	tppO2Dil,			"ppO2(Dil)"				; ppO2(Dil)
	TCODE	tppO2Mix,			"ppO2(Mix)"				; ppO2(Mix)
	TCODE	tCCRMode,			"Modo: "				; CCR/pSCR Mode
	TCODE	tCCRModeFixedSP,	"SP Fissi"				; 0 fixed for CCR / calculated for pSCR  | ENUM group
	TCODE	tCCRModeSensor,		"Sensori"				; 1 Sensor                               |
	TCODE	tCCRModeAutoSP,		"SP Auto"				; 2 Auto SP                              |
 ELSE
	TCODE	tCCRModeFixedSP,	" "						; target needed by option table
 ENDIF
	TCODE	tSP,				"SP"					; SP (SetPoint)


; New battery menu
	;                                     1         2	;
	;                            12345678901234567890	; max 20 chars
	TCODE	tNewBattTitle,		"Nuova Batteria?"
	TCODE	tNewBattOld,		"Mantieni vecchia"
	TCODE	tNewBattNew36,		"3,6V monouso    (T1)"	; new 3.6V disposable
	TCODE	tNewBattNew15,		"1,5V monouso    (T0)"	; new 1.5V disposable
	TCODE	tNewBattAccu,		"3,7V ricaricab. (T2)"	; new 3.7V rechargeable
	TCODE	tNew18650,		"OSTC 2(2015), cR(T3)"	; internal battery on 2 (old) / cR
	TCODE	tNew16650,		"OSTC 2(2017), TR(T4)"	; internal battery on 2 (new) / TR
	TCODE	tConfirmChargeable1,"Conferma:"				; safety question, line 1
	TCODE	tConfirmChargeable2,"la batteria inserita"	; safety question, line 2
	TCODE	tConfirmChargeable3,"è ricaricabile"		; safety question, line 3


; Gaslist management
	TCODE	tGas,				"Gas"					; Gas
	TCODE	tDil,				"Dil"					; Diluent
	TCODE	tGasErr,			"Err"					; Err      (max 3 chars)
	TCODE	tTakeGas,			"take"					; take gas (max 4 chars)


; Communication Menu
	TCODE	tUsbTitle,			"Modalita' USB"
	TCODE	tBleTitle,			"Modalita' Bluetooth"
	TCODE	tUsbStarting,		"Avvio..."
	TCODE	tUsbStartDone,		"Fatto."
	TCODE	tUsbServiceMode,	"Modo Servizio abil"
	TCODE	tUsbClosed,			"Porta chiusa"
	TCODE	tUsbExit,			"Uscita"
	TCODE	tUsbDownloadMode,	"Modo Download abil"
	TCODE	tUsbLlBld,			"Bootloader Basso Livello"


; Dive Settings
	TCODE	tDvMode,			"Tipo Tuffo    : "		; Dive Mode
 IFDEF _cave_mode
	TCODE	tCvMode,			"Cave Mode     : "		; Cave Mode
 ENDIF
	TCODE	tFTTSMenu,			"TTS Futuro    : "		; Future TTS
	TCODE	tTimeoutDive,		"Timeout Immsni: "		; Dive Timeout
	TCODE	tStoreApnoeDive,	"Salva Apnee   : "		; Salva Tuffi Apnea
	TCODE	tDvOC,				"OC"					; 0 | keep order, enum!
	TCODE	tDvCCR,				"CCR"					; 1 |
	TCODE	tDvGauge,			"Gauge"					; 2 |
	TCODE	tDvApnea,			"Apnea"					; 3 |
	TCODE	tDvPSCR,			"pSCR"					; 4 |
	TCODE	tDvCC,				"CC"
	TCODE	tDkMode,			"Algorit.: ZH-L16"
	TCODE	tZHL16,				" "
	TCODE	tZHL16GF,			"+GF"
	TCODE	tPPO2Max,			"Max Attv:" 
	TCODE	tPPO2DECO,			"Max Deco:"
 IFDEF _ccr_pscr
	TCODE	tPPO2MIN,			"Min OC  :"
	TCODE	tPPO2MINCC,			"Min Loop:"
 ELSE
	TCODE	tPPO2MIN,			"Min     :"
 ENDIF
	TCODE	tDecoparameters,	"Parametri Deco"
	TCODE	tGF_low,			"GF  Basso:"
	TCODE	tGF_high,			"GF  Alto :"
	TCODE	tSaturationMult,	"Saturazione  : "
	TCODE	tDesaturationMult,	"Desaturazione: "
	TCODE	tGFMenu,			"Menu GF"				; GF Settings
	TCODE	tSDMenu,			"Menu SD"				; SD Settings
	TCODE	taGF_low,			"aGF Basso:"			; aGF low
	TCODE	taGF_high,			"aGF Alto :"			; aGF high
	TCODE	taGFenable,			"aGF Selezionabile:"	; aGF Selectable
	TCODE	tDiveaGF_active,	"Usa aGF"				; using aGF
	TCODE	tSafetyStop,		"Tappa Sicurezza:"		; Safety Stop:  (max. 16 chars)
	TCODE	tExtendedStops,		"Anticipa Tappa:"		; Extended Stops
	TCODE	tLastDecostop,		"Ultima Tappa: "		; last Deco Stop Depth
	TCODE	tDvSalinity,		"Salinita': "		; Salinity
	TCODE	tDepthWarn,			"Depth Warning :"		; Depth Warning (no space after ':' on purpose)
	TCODE	tGasUsage,			"Utilizzo"				; Gas Usage
	TCODE	tSetWorkSAC,		"SAC Fondo: "			; SAC Work: (space)
	TCODE	tSetDecoSAC,		"SAC Deco : "			; SAC Deco: (space)
	TCODE	tCalcGasNeeds,		"Calc.Gas(B/O): "		; Calculate  Gas (Bail Out) Needs
 IFDEF _gas_contingency
	TCODE	tGasContingencyDive,"Swap on empty: "		; swap tank on becoming empty
 ENDIF
	TCODE	tGasChangeTime,		"Cambio Gas   :+"		; additional Gas Change Time
	TCODE	tSetup_Tank,		"Imposta Bombola"		; Setup Tank
	TCODE	tTankSize,			"Capac. Bomb.: "		; Tank Size
	TCODE	tTankUsablePress,	"Press. X Ri.: "		; Tank Press Budget for Ascent (turn pressure)
	TCODE	tLiter,				" l"					; Liter as l
	TCODE	tLiterLong,			"Litri"					; Liter as Liter
	TCODE	t2ndDecoPlanMenu,	"2o Piano Deco"			; 2nd Deco Plan

 IFDEF _ccr_pscr
	TCODE	tCCmaxFracO2,		"%O2 max Loop  : "		; max O2 percent (absolute) in the loop
	TCODE	tDilppO2Check,		"Check Dil ppO2: "		; check ppO2 of the diluent against the setpoint
	TCODE	tGasDensityCheck,	".. Gas Density: "		; check Gas Density
	TCODE	tPSCR_O2_drop,		"pSCR Caduta O2: "		; pSCR O2 Drop
	TCODE	tPSCR_lungratio,	"... Lung Ratio: "		; pSCR Lung Ratio
	TCODE	tCopyDilToOC,		"Copia Dil-OC"			; copy diluent settings to OC gas
	TCODE	tBackToLoop,		"Usa Loop"				; back to loop (10 chars max)
 ENDIF

 IFDEF _rx_functions
	TCODE	tTankPairing,		"Cambia Transmett."		; select Transmitter
	TCODE	tTrModeOff,			"Off"					; off
	TCODE	tTrModeOn,			"On"					; on
	TCODE	tTrModeIndDouble,	"Bibo Separ."			; independent double
	TCODE	tTrModeCCR,			"CCR Dil+O2"			; CCR diluent and O2
	TCODE	tTrPresNone,		"N/A"					; none  (big enum group follows)
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
	TCODE	tTrPresFirstGas,	"Primo Gas"				; first  Gas
	TCODE	tTrPresActiveGas,	"Gas Attivo"			; active Gas
	TCODE	tTrPresFirstDil,	"Primo Dil"				; first  Dil
	TCODE	tTrPresActiveDil,	"Dil Attivo"			; active Dil
 ENDIF
 ELSE
	TCODE	tTrModeOff,			""						; dummy target for entry in option table
	TCODE	tTrPresNone,		""						; dummy target for entry in option table
 ENDIF	; _rx_functions


; Display Settings
	TCODE	tBright,			"Luminosita'"			; Brightness
	TCODE	tBrightsurface,			"Superficie  : "		; ...Surface
	TCODE	tLayout,			"Layout     : "			; Layout
	TCODE	tUnits,				"Unita'     : "			; Units
 IF _language_2!=none
	TCODE	tLanguage,			"Lingua     : "			; Language
 ENDIF
	TCODE	tFlip,				"Ruota schermo: "		; Rotate Screen
	TCODE	tColorScheme,		"Schema colori"			; Colour Scheme
	TCODE	tVSIgraph,			"Grafico Veloc. : "		; Speed Graph
	TCODE	tVSItext2,			"...   adaptive : "		; adaptive Speed
	TCODE	tShowppO2,			"ppO2 Permanente: "		; always show ppO2:
	TCODE	tDepthWarning,		"Prof luccicare : "		; Depth blinking
	TCODE	t2ndDepth,			"2a Prof.: "			; 2nd depth display content (11 chars max)
	TCODE	tTissueGraphics,	"Grafica : "			; tissue graphics

	TCODE	tIBCDwarning,		"Avvertimento IBCD:"	; IBCD Warning
	TCODE	tEco,				"Eco"					; eco     | ENUM group
	TCODE	tMedium,			"Media"					; medium  |
	TCODE	tHigh,				"Alta"					; high    |
	TCODE	tLayoutNormal,		"Normale"				; normal  | ENUM group
	TCODE	tLayoutBig,			"Max"					; big     |
	TCODE	tMax,				"max."					; max     | ENUM group
	TCODE	tAvg,				"avg."					; average |
	TCODE	tTissuePresSat,		"Pres+Sat"				; 0 pressure and saturation | ENUM group
 IFDEF _helium
	TCODE	tTissueN2He,		"N2+He"					; 1 N2 + He pressure        |
 ENDIF


; Setup Menu
	TCODE	tSystSets,			"Impostazioni"			; System Settings
 IFDEF _compass
	TCODE	tCompassMenu,		"Bussola"				; Compass
	TCODE	tCompassCalibration,"Calibra"				; Calibration
	TCODE	tCompassGain,		"Suscettibilita:"		; Compass gain:
	TCODE	tCalX,				"Cal X"					; Cal X
	TCODE	tCalY,				"Cal Y"					; Cal Y
	TCODE	tCalZ,				"Cal Z"					; Cal Z
 ENDIF
	TCODE	tMetric,			" m/°C"					; Enum menu
	TCODE	tImperial,			"ft/°F"
								;         111         111         111         111         111
	; 5 rows by 12 chars each:	 123456789012123456789012123456789012123456789012123456789012
	TCODE	tDefName,			"HW OSTC"	;"  Read the  Manual, know& understandthe inherentLimitations!"
	TCODE	tPiezo,				"Bottone"				; Buttons
	TCODE	tButtonExplain1,	"Less % is"			; Less % is 
	TCODE	tButtonExplain2,	"more sensitive."		; more sensitive.
	TCODE	tButtonleft,		"Bottone Sx:"			; Left  Button
	TCODE	tButtonright,		"Bottone Dx:"			; Right Button
	TCODE	tAltMode,			"Attesa   :"			; Waiting Time
	TCODE	tAltModeFly,		"Volo"					; Flying
	TCODE	tAltMode1000,		"1000m"					;
	TCODE	tAltMode2000,		"2000m"					;
	TCODE	tAltMode3000,		"3000m"					;


; Units for all menu
	TCODE	tMeters,			"m"
	TCODE	tFeets,				"ft"
	TCODE	tFeets1,			"f"
	TCODE	tMinutes,			"'"
	TCODE	tPercent,			"%"
	TCODE	tLitersMinute,		"l/min"
	TCODE	tbar,				"bar"					; bar
	TCODE	tbar10,				"0 bar"					; xx0 bar
	TCODE	tMeterMinute,		"m/'"					; meter per minute


; Date
	TCODE	tDateFormat,		"Data: "
	TCODE	tDateformat,		"MMGGAA"
	TCODE	tDateformat1,		"GGMMAA"
	TCODE	tDateformat2,		"AAMMGG"


; Simulator menu
	TCODE	tInter,				"Avvia Simulatore"		; Start Simulator
	TCODE	tSimulator,			"Simulatore"			; Simulator


; Decoplanner submenu
	TCODE	tBtTm,				"Tempo Fondo :"			; Bot. Time: (10 chars)
	TCODE	tBtTm_short,		"Tempo:"				; Bot. Time: (max. 6 chars)
	TCODE	tBtDep,				"Profond. Max:"			; Max Depth: (10 chars)
	TCODE	tIntvl,				"Int.Superf. :"			; Interval : (10 chars)
	TCODE	tCalculatorSetup,	"Setta Calcoli"			; Calculator Setup
	TCODE	tDeco,				"Calcola Deco"			; Calculate Deco
	TCODE	tDivePlan,			"Pianificat"			; Dive Plan (max. 10 chars)
	TCODE	tNoDeco,			"No Deco"				; No Deco
	TCODE	tMore,				"Dettagli"				; More
	TCODE	tSelectSetpoint,	"Setpoint CCR: "		;
	TCODE	tuseAGF,			"usa aGF     : "		; use aGF
 IFDEF _gas_contingency
	TCODE	tGasContingencySim,	"Gas Cont. : "			; Gas Contingency			## translation pending
 ENDIF

; Decoplanner progress indication
	TCODE	tNoBottomGas1,		"Nessun Gas utile per"	; no usable Gas for Bottom Depth found (line 1, max. 22 chars)
	TCODE	tNoBottomGas2,		"la quota di fondale!"	; no usable Gas for Bottom Depth found (line 2, max. 22 chars)
	TCODE	tCalculating,		"Calcolando..."			; calculating...
	TCODE	tCalcSurfInter,		"Int. Superficie"		; Surface Interval
	TCODE	tCalcBotSeg,		"Tempo di fondo"		; Bottom Segment
	TCODE	tCalcBailout,		"Cambia a Bailout"		; Switch to Bailout
	TCODE	tCalcAscent,		"Risalita"				; Ascent (max 8 chars)
	TCODE	tNDLleft,			"NDL" 					; time left within NDL ("Rimasto")


; Information menu
	TCODE	tFirmware,			"Firmware: "			; Firmware: (space)
	TCODE	tFirmwareDate,		"created : "			; created : (space)  firmware creation date
	TCODE	tHardware,			"Hardware: "			; Hardware: (space)
	TCODE	tSerial,			"Seriale : "			; Serial  : (space)
	TCODE	tBatteryV,			"Batteria: "			; Battery : (space)
	TCODE	tSensorC,			"Sensor  : "			; Sensor  : (space)
	TCODE	tSensorD,			"Offset  : "			; Offset  : (space)
	TCODE	tUptime,			"Uptime: "				; Uptime: 

 IFDEF _rx_functions
	TCODE	tFirmware_rx,		"RX Ver  : "			; RX Ver  : (space)
 ENDIF


; Divemode screen
	TCODE	tNDL,				"NDL"					; 3 chars
	TCODE	tTTS,				"TTS"					; 3 chars
	TCODE	tSlow,				"piano "				; slow - max 7 chars
	TCODE	tVelMetric,			"m/min"
	TCODE	tVelImperial,		"ft/m "
	TCODE	tGasSelect,			"Selez. Gas"			; Select Gas
	TCODE	tSelectAir,			"Aria"					; Air
	TCODE	tSelectO2,			"O2  "					; O2
	TCODE	tSelectNx,			"Nx"					; Nx
	TCODE	tSelectTx,			"Tx"					; Tx
	TCODE	tDepth,				"Prof."					; Depth (max 5 chars)
	TCODE	tMaxDepth,			"Prof.Max"				; Max. Depth    - max 9 chars!
	TCODE	tAvgDepth,			"Prof.Med."				; average Depth - max 9 chars!
	TCODE	tDivetime,			"Divetime"				; Divetime  (max 8 chars)
	TCODE	tDiveTotalAvg,		"Media"
	TCODE	tDiveStopwatch,		"Cronometro"
	TCODE	tDiveStopAvg,		"Media Inter"			; 11 chars max
	TCODE	tApnoeTotal,		"Totale"				; Total (six chars, right aligned)
	TCODE	tApnoeMax,			"Ultima Discesa"		; Last descend
	TCODE	tApnoeSurface,		"Tp.Superficie"			; Surface Time
	TCODE	tTime,				"Time"					; Time ("Tempo")
	TCODE	tSurface,			"Superficie"			; Surface (max 12 chars)
	TCODE	tDiveDecoplan,		"Piano Deco"			; Decoplan
;	TCODE	tDiveClock,			"Orologio"				; Clock
	TCODE	tDiveEAD_END,		"EAD/END"				; EAD/END
	TCODE	tDiveTissues,		"Tessuti"				; Tissues
	TCODE	tEND,				"END:"					; END:
	TCODE	tN2,				"N2"					; N2
	TCODE	tDiveBailout,		"Bailout"				; Bailout (max. 7 chars)
	TCODE	tGFactors,			"Valori GF"				; GF Values
	TCODE	taGFactors,			"Valori aGF"			; aGF Values
	TCODE	tGFInfo,			"Saturazione"			; Saturation
	TCODE	tCeiling,			"Tetto"					; Ceiling
	TCODE	tDiveFallback,		"Fallback!"				; Fallback! (max. nine chars)
	TCODE	tDecoInfo,			"Zona Deco" 			; Deco info ("Curva Deco")
	TCODE	tSensorCheck,		"Testa Sensori"			; Sensor Check
	TCODE	tdil,				"Dil:"					; Diluent ppO2 Warning
	TCODE	tmix,				"Mix:"					; Pre-Mix ppO2 Warning
	TCODE	tGasNeedsWarn,		"Gas Neces"				;
	TCODE	tCNSsurf,			"CNS Surf."				;
	TCODE	tCNSfTTS,			"CNS fTTS"				;
	TCODE	tCNSBO,				"CNS B/O"				;
	TCODE	tCNSnow,			"CNS ora"				;
	TCODE	tCNSeod,			"CNS fin."				;
 IFDEF _cave_mode
	TCODE	tCNScave,			"CNS Cave"				;
 ENDIF
	TCODE	tnoBOgas,			"-B/O-Gas-"				;
	TCODE	tMicroBubbles,		"M.Bolle"				;
	TCODE	tCNS,				"CNS: "					;
	TCODE	tgaschange,			"Cambio?"				; better gas found
	TCODE	tNeed,				"Neces"					; gas need (5 chars)
	TCODE	tBattery,			"Batteria"				; Battery
	TCODE	tSAT,				"Sat:"					; Sat:  (max 4 chars)
	TCODE	tppO2,				"ppO2:"					; ppO2: (max 5 chars)

 IFDEF _helium
	TCODE	tHe,				"He"					; He
	TCODE	tIBCD,				"IBCD N2He"				; IBCD warning (max. 9 chars)
 ENDIF

 IFDEF _ccr_pscr
	TCODE	tGasDensity,		"G.Density"				; Gas Density  (max. 9 chars)	## pending translation
 ENDIF

 IFDEF _rx_functions
	TCODE	tTransmitter,		"Pr.Trasm."				; pressure transmitter
	TCODE	tPressure,			"P.Bombola"				; tank pressure
	TCODE	tSAC,				"ICS"					; SAC, must be 3 chars!
	TCODE	tswap,				"CambioGas"				; swap tank (max. 9 chars
 ENDIF

 IFDEF _external_sensor
	TCODE	tDiveHudMask1,		"Sensore1"
	TCODE	tDiveHudMask2,		"Sensore2"
	TCODE	tDiveHudMask3,		"Sensore3"
	TCODE	tSensorDisagree,	"Sensori<>"				; Sensors disagree Warning
 ENDIF

 IFDEF _cave_mode
	TCODE	tGasNeedsCaveMode,	"Gas Necess.  -CAVE- "	; title for gas needs custom view (cave mode)		| need to be
	TCODE	tGasNeedsAscent,	"Gas Necess. Risalita"	; title for gas needs custom view (open water mode)	| same length
	TCODE	tCaveMode,			"Cave Mode"				; cave mode activated (max. 9 char)
	TCODE	tCaveModeShutdown,	"X-Cave-X"				; cave mode shut down (max. 9 char)
	TCODE	tCaveTTS,			"Cave TTS"				; cave mode total time to surface
	TCODE	tCaveStops,			"total Stops"			; cave mode total time for stops
	TCODE	tCaveRuntime,		"total RT"				; cave mode total runtime
 ELSE
	TCODE	tGasNeedsAscent,	"Pres.Gas x Risalita"	; title for gas needs custom view
 ENDIF


; Divemode menu
	TCODE	tDiveAckn,			"Ackn?"					; Ackn?  (max. 5 chars)
	TCODE	tDivePreMenu,		"Menu?"					; Menu?  (max. 5 chars)
	TCODE	tDiveLayout,		"Layout"				; Layout (max. 6 chars)
 IFDEF _compass
	TCODE	tSetHeading,		"Salva"					; Course (max. 6 chars)
 ENDIF


; Simulator menu
	TCODE	tQuitSim,			"Esci"					; Quit Simulation (max. 6 chars)
	TCODE	tResetAvg,			"AzzMed"				; Reset Timer     (max. 6 chars)


; Logbook
	TCODE	tCNS2,				"CNS:"
	TCODE	tAVG,				"Media:"
	TCODE	tGF2,				"GF :"
	TCODE	tSD2,				"S/D: "
	TCODE	tDvSalinity2,		"Salinita':"			; max 11 chars
	TCODE	tLastDeco,			"Ult.Tappa:"			; max 11 chars
	TCODE	tNoProfileData,		"no data anymore..."	; max 21 chars
	TCODE	tBeginOfDive,		"Begin:"				; max  8 chars
	TCODE	tEndOfDive,			"End:"					; max  8 chars
	TCODE	tDesatTime,			"Desat:"				; amx  8 chars

; other users
	TCODE	tGF,				"GF:"					; GF Factors                (3 chars)
	TCODE	tSD,				"S/D"					; Saturation / Desaturation (3 chars)

; Logbook units
	TCODE	tLogTunitC,			"°C"
	TCODE	tLogTunitF,			"°F"
	TCODE	tKGL,				"kg/l"
	TCODE	tMBAR,				"hPa"


; Logbook menu
	TCODE	tNextLog,			"Pagina Seguente"


; Reset menu
 IFDEF _firmware_recovery
	TCODE	tReboot,			"Riavvio/Backup"		; Reboot/Backup
 ELSE
	TCODE	tReboot,			"Riavvio"				; Reboot
 ENDIF
	TCODE	tResetMenu2,		"Sei sicuro?"			; Are you sure?
	TCODE	tAbort,				"Annulla"				; Abort
	TCODE	tResetSettings,		"Azzera Settaggi"		; Reset all
	TCODE	tResetDeco,			"Azzera Deco"			; Reset Deco
	TCODE	tResetBattery,		"Azzera Batteria"		; Reset Battery
	TCODE	tResetLogbook,		"Azzera Logbook"		; Reset Logbook

 IFDEF _firmware_recovery
	TCODE	tRebootCurFirmware,	"Reboot  current FW"	; Reboot current Firmware
	TCODE	tBackupFirmware,	"Backup  current FW"	; Backup current Firmware
	TCODE	tRecoverFirmware,	"Restore"				; Restore (version will be appended)
	TCODE	tBackingUp,			"backing up..."			; backing up current firmware
	TCODE	tRestoring,			"restoring..."			; restoring  backup  firmware
 ENDIF


; Set Time Menu/Set Date Menu
	TCODE	tSetHours,			"Imposta Ora"			; Set Hours
	TCODE	tSetMinutes,		"Imposta Minuti"		; Set Minutes
	TCODE	tSetSeconds,		"Azzera Secondi"		; Clear seconds
	TCODE	tSetDay,			"Imp Giorno"			; Set Day
	TCODE	tSetMonth,			"Imp Mese"				; Set Month
	TCODE	tSetYear,			"Imp Anno"				; Set Year


; Logbook Offset Menu
	TCODE	tTotalDives,		"Tot Immersioni:"		; Total Dives
	TCODE	tLogOffset,			"Devia Logbook"			; Logbook offset
	TCODE	tLogOffsetValue,	"Devio    : "			; Offset
	TCODE	tLogOffStepSize,	"Moltiplico:"			; Step Size
	TCODE	tLogOffsetplus,		"+"						; increment
	TCODE	tLogOffsetminus,	"-"						; decrement
	TCODE	tLogOffStep1,		"   1"					; adjustment step size 1    | ENUM group
	TCODE	tLogOffStep10,		"  10"					; adjustment step size 10   |
	TCODE	tLogOffStep100,		" 100"					; adjustment step size 100  |
	TCODE	tLogOffStep1000,	"1000"					; adjustment step size 1000 |


; Compass directions
	TCODE	tN,					"N "					; N(orth),    338°-22°
	TCODE	tNE,				"NE"					; North-East,  23°-67°
	TCODE	tE,					"E "					; E(east),     68°-112°
	TCODE	tSE,				"SE"					; South-East, 113°-157°
	TCODE	tS,					"S "					; S(outh),    157°-202°
	TCODE	tSW,				"SO"					; South-West, 203°-247°
	TCODE	tW,					"O "					; W(West),    248°-292°
	TCODE	tNW,				"NO"					; North-West, 293°-337°


; Color Scheme menu
	TCODE	tColorSetDive,		"Immersione:"			; Divemode:
	TCODE	tColorSetName0,		"Standard"				; Standard
	TCODE	tColorSetName1,		"Rosso"					; Red
	TCODE	tColorSetName2,		"Verde"					; Green
	TCODE	tColorSetName3,		"Blu"					; Blue


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