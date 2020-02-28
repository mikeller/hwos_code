;=============================================================================
;
;	File text_french.sm                       next combined generation V3.08.8
;
;	French texts translation file.
;
;	Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================

; Basic texts
	TCODE	tNo,				"Non"					; 0 No		| ENUM group
	TCODE	tYes,				"Oui"					; 1 Yes		|

 IFDEF _cave_mode
	TCODE	tOff,				"off"					; OFF		| Enum group
	TCODE	tOn,				"on"					; ON		|
 ELSE
	TCODE	tOff,				" "						; needed for option table
 ENDIF

	TCODE	tblank,				" "						; (a single space character)

; Surface-mode texts
	TCODE	tMenu,				"<Menu"					; <Menu
	TCODE	tView,				"Vues>"					; View>
	TCODE	tHeading,			"Cap:"					; Heading:
	TCODE	tLastDive,			"Dern.Plong"			; Last Dive (Max 10 chars)

	TCODE	tFTTSSurf,			"Future DTR :"			; Future TTS
	TCODE	tLastDecostopSurf,	"Dern.Palier:"			; last deco stop depth Surface Custom View
	TCODE	tDvSalinitySurf,	"Salinité   :"			; Salinity

 IFDEF _external_sensor
	TCODE	tSensorMilliVolt,	"Cellules mV"			; Sensors mV
 ENDIF


; Divemode Menu
	TCODE	tDivemenu_Gaslist,	"Liste Gaz"				; Gas List (OC)
	TCODE	tDivemenu_ResetAvg,	"RaZChrono"				; Reset Avg
	TCODE	tDivemenu_Avg_Mkr,	"Moyen/Mark"			; Reset Avg, Set Marker (and Turn Dive)
	TCODE	tDivemenu_ToggleGF,	"Bascul.GF"				; Toggle GF
	TCODE	tDivemenu_Marker,	"Repère"				; Set Marker

 IFDEF _cave_mode
	TCODE	tDivemenu_LostGas,	"Gaz avail."			; Gas Availability
 ELSE
	TCODE	tDivemenu_LostGas,	"Gaz Perdu"				; Lost Gas
 ENDIF

 IFDEF _ccr_pscr
	TCODE	tDivemenu_Diluent,	"Liste Dil"				; Diluents (CCR)
	TCODE	tDivemenu_Premix,	"Liste Mix"				; Premix   (pSCR)
	TCODE	tDivemenu_Setpoint,	"Setpoint"				; Setpoint
 ENDIF

 IFDEF _external_sensor
	TCODE	tDivemenu_UseSensor,"Cellules"				; Use Sensor
 ENDIF

 IFDEF _cave_mode
	TCODE	tDivePreCave,		"Cave?"					; Enter Cave Menu          ( 5 chars max)
	TCODE	tDivemenu_wp_set,	"Waypoint"				; Set Waypoint             (10 chars max)
	TCODE	tDivemenu_wp_out,	"WP go <-()"			; go one Waypoint outwards (10 chars max)
	TCODE	tDivemenu_wp_in,	"WP go ->()"			; go one Waypoint inwards  (10 chars max)
	TCODE	tDivemenu_TurnDive,	"Retour"				; Turn Dive                (10 chars max)
	TCODE	tDivemenu_ContDive,	"Cont.Dive"				; Continue Dive            (10 chars max)
	TCODE	tDivemenu_off_on, 	"Off / On"				; Cave Mode Off/On         (10 chars max)
 ENDIF


; Main menu
	TCODE	tNext,				"<Suivant"				; <Next
	TCODE	tEnter,				"Entrer>"				; Enter>
	TCODE	tMainMenu,			"Menu Principal"		; Main Menu
	TCODE	tLogbook,			"Carnet de Plongée"		; Logbook
	TCODE	tGasSetup,			"Paramètres Gaz OC"		; OC Gas Setup
	TCODE	tSetTime,			"Réglage Heure"			; Set Time
	TCODE	tSetDate,			"Réglage Date"			; Set Date
	TCODE	tSetTimeDate,		"Date & Heure"			; Time & Date
	TCODE	tDispSets,			"Préfér. Réglages"		; Display Settings
	TCODE	tSysSets,			"Préfér. System"		; System  Settings
	TCODE	tExit,				"Sortie"				; Exit
	TCODE	tResetMenu,			"Menu RaZ"				; Reset Menu
	TCODE	tDiveModeMenu,		"Menu Déco"				; Dive Setup

	TCODE	tDiveSetup,			"Dive Setup"			; Dive Setup
	TCODE	tDecoSetup,			"Deco Setup"			; Deco Setup
	TCODE	tSACSetup,			"SAC  Setup"			; SAC Setup
	TCODE	tppO2Setup,			"ppO2 Setup"			; ppO2 Setup
	TCODE	tStopsSetup,		"Stops & Depths"		; Stops & Depths

	TCODE	tInfoMenu,			"Informations"			; Information
 IFDEF _ccr_pscr
	TCODE	tCCRSetup,			"Paramètres CCR"		; CCR Setup
	TCODE	tDiluentSetup,		"Liste Diluant"			; Diluent Setup
 ENDIF
	TCODE	tFixedSetpoints,	"Setpoints Fixes"		; Fixed Setpoints
	TCODE	tBack,				"Retour"				; back
	TCODE	tGas6,				"extra Gas"				; edit & select Gas 6

 IFDEF _rx_functions
	TCODE	tTrSettings,		"Affich.Pression"		; Pressure Display
	TCODE	tTrMode,			"Mode: "				; Mode
	TCODE	tTr1stPres,			"1.Pres.: "				; 1st Pressure
	TCODE	tTr2ndPres,			"2.Pres.: "				; 2nd Pressure
	TCODE	tTrBailPres,		"1.B/O  : "				; Bailout Pressure
	TCODE	tTrMaxDeltaP,		"max deltaP: "			; independent double max diffenerce
 ENDIF

 IFDEF _external_sensor
	TCODE	tCCRSensor,			"Cellules CCR"			; CCR Sensor
	TCODE	tCalibrateMenu,		"Calibration"			; Calibration
	TCODE	tCalibrationGas,	"Cal. Gaz O2:"			; Cal. Gas O2:
	TCODE	tCalibrate,			"Calibrate"				; Calibrate
	TCODE	tS8Mode,			"S8 Input: "			; Sensor Input
	TCODE	tCCRS8Mode,			"Analog"				; Analog
	TCODE	tCCRS8Mode2,		"Digital"				; Digital
 ELSE
	TCODE	tCCRS8Mode,			" "						; needed for option table
 ENDIF


; Gas menu
	TCODE	tGaslist,			"Liste Gaz OC"			; OC Gas List
	TCODE	tGaslistCC,			"Liste Gaz CC"			; CC Diluents
	TCODE	tGasEdit,			"Préférence Gaz"		; Edit Gas
	TCODE	tType,				"Type: "
	TCODE	tGasDisabled,		"Désactivé"				; Disabled
	TCODE	tGasFirst,			"Premier"				; First
	TCODE	tGasTravel,			"Travail"				; Work (Travel, Bottom)
	TCODE	tGasDeco,			"Déco"					; Deco
	TCODE	tDilDisabled,		"Désactivé"				; Disabled
	TCODE	tDilFirst,			"Premier"				; First
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
	TCODE	tSetup_GasDepth,	"Config. Changement"	; Change Depth
	TCODE	tDepthPlus,			"Prof. +"
	TCODE	tDepthMinus,		"Prof. -"
	TCODE	tDepthReset,		"MOD par défaut:"
	TCODE	tSetup_GasMix,		"Config. Gaz"			; Setup mix
 IFDEF _ccr_pscr
	TCODE	tSPPlus,			"PpO2+"					; pO2+
	TCODE	tSensorFallback,	"Fallback:"				; Fallback:
	TCODE	tCalculated,		"calculé"				; calculated
	TCODE	tppO2O2,			"PpO2(O2)"				; ppO2(O2)
	TCODE	tppO2Dil,			"PpO2(Dil)"				; ppO2(Dil)
	TCODE	tppO2Mix,			"PpO2(Mix)"				; ppO2(Mix)
	TCODE	tCCRMode,			"Mode: "				; CCR/pSCR Mode
	TCODE	tCCRModeFixedSP,	"SP Fixe"				; 0 fixed for CCR / calculated for pSCR  | ENUM group
	TCODE	tCCRModeSensor,		"Cellule"				; 1 Sensor                               |
	TCODE	tCCRModeAutoSP,		"SP Auto"				; 2 Auto SP                              |
 ELSE
	TCODE	tCCRModeFixedSP,	" "						; target needed by option table
 ENDIF
	TCODE	tSP,				"SP"					; SP (SetPoint)
	TCODE	tppO2,				"PpO2:"					; ppO2:


; New batteries menu
	;                                     1         2	;
	;                            12345678901234567890	; max 20 chars
	TCODE	tNewBattTitle,		"Nouvelle Pile?"
	TCODE	tNewBattOld,		"Conserver"
	TCODE	tNewBattNew36,		"3,6V jetable    (T1)"	; new 3.6V disposable
	TCODE	tNewBattNew15,		"1,5V jetable    (T0)"	; new 1.5V disposable
	TCODE	tNewBattAccu,		"3,7V chargeable (T2)"	; new 3.7V rechargeable
	TCODE	tNew18650,			"OSTC 2 ou cR    (T3)"	; internal battery on 2 (old) / cR
	TCODE	tNew16650,			"OSTC 2 ou TR    (T4)"	; internal battery on 2 (new) / TR
	TCODE	tConfirmChargeable1,"Confirmer:"			; safety question, line 1
	TCODE	tConfirmChargeable2,"La pile insérée"		; safety question, line 2
	TCODE	tConfirmChargeable3,"est rechargeable"		; safety question, line 3


; Gaslist management
	TCODE	tGas,				"Gaz"					; Gas
	TCODE	tDil,				"Dil"					; Diluent
	TCODE	tGasErr,			"Err"					; Err      (max 3 chars)
	TCODE	tTakeGas,			"take"					; take gas (max 4 chars)


; Communication Menu
	TCODE	tUsbTitle,			"Mode USB"
	TCODE	tBleTitle,			"Mode Bluetooth"
	TCODE	tUsbStarting,		"Début..."
	TCODE	tUsbStartDone,		"Ok."
	TCODE	tUsbServiceMode,	"Mode Maintenance"
	TCODE	tUsbClosed,			"Port Fermé"
	TCODE	tUsbExit,			"Terminé"
	TCODE	tUsbDownloadMode,	"Mode Téléchargement"
	TCODE	tUsbLlBld,			"Chargeur Bas-Niv."


; Dive Settings
	TCODE	tDvMode,			"Mode        : "		; Dive Mode
 IFDEF _cave_mode
	TCODE	tCvMode,			"Cave        : "		; Cave Mode
 ENDIF
	TCODE	tFTTSMenu,			"Future DTR  :"			; Future TTS
	TCODE	tTimeoutDive,		"Fin Plongée : "		; Dive Timeout
	TCODE	tStoreApnoeDive,	"Carnet Apnée: "		; Store Apnoe Dives
	TCODE	tDvOC,				"OC"					; 0 | keep order, enum!
	TCODE	tDvCCR,				"CCR"					; 1 |
	TCODE	tDvGauge,			"Gauge"					; 2 |
	TCODE	tDvApnea,			"Apnée"					; 3 |
	TCODE	tDvPSCR,			"pSCR"					; 4 |
	TCODE	tDvCC,				"CC"
	TCODE	tDkMode,			"Modèle: ZH-L16"
	TCODE	tZHL16,				" "
	TCODE	tZHL16GF,			"+GF"
	TCODE	tPPO2Max,			"Max Travail:"
	TCODE	tPPO2DECO,			"Max Déco   :"
 IFDEF _ccr_pscr
	TCODE	tPPO2MIN,			"Min OC     :"
	TCODE	tPPO2MINCC,			"Min Loop   :"
 ELSE
	TCODE	tPPO2MIN,			"Min        :"
 ENDIF
	TCODE	tDecoparameters,	"Paramètres Déco"
	TCODE	tGF_low,			"GF  Bas :"
	TCODE	tGF_high,			"GF  Haut:"
	TCODE	tSaturationMult,	"Saturation  : "
	TCODE	tDesaturationMult,	"Désaturation: "
	TCODE	tGFMenu,			"Menu GF"				; GF Settings
	TCODE	taGF_low,			"aGF Bas :"				; aGF Low
	TCODE	taGF_high,			"aGF Haut:"				; aGF High
	TCODE	taGFenable,			"aGF Possible:"			; aGF Selectable
	TCODE	tDiveaGF_active,	"aGF Actif"				; using aGF
	TCODE	tSafetyStop,		"Palier Sécurité:"		; Safety Stop:  (max. 16 chars)
	TCODE	tExtendedStops,		"Paliers + Longs:"		; Extended Stops
	TCODE	tLastDecostop,		"Dern.Palier: "			; last DecoStop Depth
	TCODE	tDvSalinity,		"Salinité   : "			; Salinity
	TCODE	tDepthWarn,			"Depth Warn.: "			; Depth Warning
	TCODE	tGasUsage,			"Usage Gaz"				; Gas Usage
	TCODE	tSetWorkSAC,		"SAC Fond: "			; SAC Work: (space)
	TCODE	tSetDecoSAC,		"SAC Déco: "			; SAC Deco: (space)
	TCODE	tCalcGasNeeds,		"Calc.Gaz (B/O): "		; Calculate  Gas (Bail Out) needs
 IFDEF _gas_contingency
	TCODE	tGasContingencyDive,"Swap on empty: "		; swap tank on becoming empty
 ENDIF
	TCODE	tGasChangeTime,		"Tps Change Gaz:+"		; additional Gas Change Time
	TCODE	tSetup_Tank,		"Config. Blocs"			; Setup Tank
	TCODE	tTankSize,			"Volume   Bloc"			; Tank Sizes
	TCODE	tTankUsablePress,	"Besoin Press. Rem."	; Tank Pressure Budget for Ascent (turn pressure) (max 19 chars)
	TCODE	tLiter,				" l"					; Liter as l
	TCODE	tLiterLong,			"Litre"					; Liter as Liter
	TCODE	t2ndDecoPlanMenu,	"2ème Plan Déco"		; 2nd Deco Plan

 IFDEF _ccr_pscr
	TCODE	tCCmaxFracO2,		"Loop %O2 max. : "		; max O2 percent (absolute) in the loop
	TCODE	tDilppO2Check,		"Check Dil ppO2: "		; check ppO2 of the diluent against the setpoint
	TCODE	tPSCR_O2_drop,		"pSCR O2 Drop  : "		; pSCR O2 Drop
	TCODE	tPSCR_lungratio,	"... Lung Ratio: "		; pSCR Lung Ratio
	TCODE	tCopyDilToOC,		"Copie Diluant -> OC"	; copy diluent settings to OC gas
	TCODE	tBackToLoop,		"goto loop"				; back to loop (10 chars max)
 ENDIF

 IFDEF _rx_functions
	TCODE	tTankPairing,		"Appair.Transmetteur"	; select Transmitter
	TCODE	tTrModeOff,			"off"					; off
	TCODE	tTrModeOn,			"on"					; on
	TCODE	tTrModeIndDouble,	"P.Bloc Diff."			; independent double
	TCODE	tTrModeCCR,			"CCR Dil+O2"			; CCR diluent and O2
	TCODE	tTrPresNone,		"no Press."				; none  (big enum group follows)
	TCODE	tTrPresGas1,		"Gaz 1"					; Gas 1
	TCODE	tTrPresGas2,		"Gaz 2"					; Gas 2
	TCODE	tTrPresGas3,		"Gaz 3"					; Gas 3
	TCODE	tTrPresGas4,		"Gaz 4"					; Gas 4
	TCODE	tTrPresGas5,		"Gaz 5"					; Gas 5
 IFDEF _ccr_pscr
	TCODE	tTrPresDil1,		"Dil 1"					; Dil 1
	TCODE	tTrPresDil2,		"Dil 2"					; Dil 2
	TCODE	tTrPresDil3,		"Dil 3"					; Dil 3
	TCODE	tTrPresDil4,		"Dil 4"					; Dil 4
	TCODE	tTrPresDil5,		"Dil 5"					; Dil 5
	TCODE	tTrPresFirstGas,	"gaz prem."				; first  Gas
	TCODE	tTrPresActiveGas,	"gaz actif"				; active Gas
	TCODE	tTrPresFirstDil,	"dil prem."				; first  Dil
	TCODE	tTrPresActiveDil,	"dil actif"				; active Dil
 ENDIF
 ELSE
 	TCODE	tTrModeOff,			""						; dummy target for entry in option table
	TCODE	tTrPresNone,		""						; dummy target for entry in option table
 ENDIF	; _rx_functions


; Display Settings
	TCODE	tBright,			"Luminosité: "			; Brightness
	TCODE	tLayout,			"Affichage : "			; Layout
	TCODE	tUnits,				"Unités    : "			; Units
 IF _language_2!=none
	TCODE	tLanguage,			"Langue    : "			; Language
 ENDIF
	TCODE	tFlip,				"Pivoter l'écran:"		; Rotate Screen
	TCODE	tColorScheme,		"Jeu de Couleurs"		; Colour Scheme
	TCODE	tVSIgraph,			"Graph.Vitesse: "		; Speed Graph
	TCODE	tVSItext2,			"Var.  Vitesse: "		; variable Speed
	TCODE	tShowppO2,			"Afficher PpO2: "		; always show ppO2
	TCODE	tDepthWarning,		"Prof. luire  : "		; Depth blinking
	TCODE	t2ndDepth,			"Choix Prof:"			; 2nd Depth Display Content (11 chars max)
	TCODE	tTissueGraphics,	"Dessin    :"			; Tissue Graphics
	TCODE	tIBCDwarning,		"Alerte CDI: "			; IBCD Warning

	TCODE	tEco,				"Eco"					; eco     | ENUM group
	TCODE	tMedium,			"Moyenne"				; medium  |
	TCODE	tHigh,				"Haute"					; high    |
	TCODE	tLayoutNormal,		"normal"				; normal  | ENUM group
	TCODE	tLayoutBig,			"large"					; large   |
	TCODE	tMax,				"max."					; max     | ENUM group
	TCODE	tAvg,				"avg."					; average |
	TCODE	tTissuePresSat,		"Pres+Sat"				; pressure and saturation | ENUM group
 IFDEF _helium
	TCODE	tTissueN2He,		"N2+He"					; N2 + He pressure        |
 ENDIF


; Setup Menu
	TCODE	tSystSets,			"Réglages"				; System Settings
 IFDEF _compass
	TCODE	tCompassMenu,		"Calibration Compas"	; Compass Calibration
	TCODE	tCompassGain,		"Sensibilité:"			; Compass Gain:
	TCODE	tCalX,				"Cal X:"				; Cal X
	TCODE	tCalY,				"Cal Y:"				; Cal Y
	TCODE	tCalZ,				"Cal Z:"				; Cal Z
 ENDIF
	TCODE	tMetric,			" m/°C"					; Enum menu
	TCODE	tImperial,			"ft/°F"
								;         111         111         111         111         111
	; 5 rows by 12 chars each:	 123456789012123456789012123456789012123456789012123456789012
	TCODE	tDefName,			"HW OSTC"	;"Lire la doc.Connaitre etComprendre  les limites de l'OSTC ! "
	TCODE	tPiezo,				"Bouton"				; Buttons
	TCODE	tButtonleft,		"Bouton gauche:"		; Left button
	TCODE	tButtonright,		"Bouton droit :"		; Right button
	TCODE	tAltMode,			"Temps Attente:"		; Waiting Time
	TCODE	tAltModeFly,		"Avion"					; Flying
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
	TCODE	tbar,				"bar"					; bar
	TCODE	tbar10,				"0 bar"					; xx0 bar
	TCODE	tMeterMinute,		"m/'"					; meter per minute


; Date
	TCODE	tDateFormat,		"Date: "
	TCODE	tDateformat,		"MMJJAA"
	TCODE	tDateformat1,		"JJMMAA"
	TCODE	tDateformat2,		"AAMMJJ"


; Simulator menu
	TCODE	tInter,				"Lancer Simulation"		; Start Simulator
	TCODE	tSimulator,			"Simulateur"			; Simulator


; Decoplanner submenu
	TCODE	tBtTm,				"Temps Fond:"			; Bot. Time: (10 chars)
	TCODE	tBtTm_short,		"Temps:"				; Bot. Time: (max. 6 chars)
	TCODE	tBtDep,				"Prof. Max :"			; Max Depth: (10 chars)
	TCODE	tIntvl,				"Intervalle:"			; Interval : (10 chars)
	TCODE	tCalculatorSetup,	"Réglage Ordinateur"	; Calculator Setup
	TCODE	tDeco,				"Calcul Déco"			; Calculate Deco
	TCODE	tDivePlan,			"Runtime"				; Dive Plan (max. 10 chars)
	TCODE	tNoDeco,			"Pas de Déco"			; No Deco
	TCODE	tMore,				"Suite"					; More
	TCODE	tSelectSetpoint,	"Setpoint  : "
	TCODE	tuseAGF,			"aGF Permis: "			; use aGF
 IFDEF _gas_contingency
	TCODE	tGasContingencySim,	"Gas Cont. : "			; Gas Contingency			## translation pending
 ENDIF

; Decoplanner progress indication
	TCODE	tNoBottomGas1,		"Pas de Gaz Utilisable"	; no usable Gas for Bottom Depth found (line 1, max. 22 chars)
	TCODE	tNoBottomGas2,		"a la Profondeur Maxi!"	; no usable Gas for Bottom Depth found (line 2, max. 22 chars)
	TCODE	tCalculating,		"Calcul en cours"		; Calculating
	TCODE	tCalcSurfInter,		"Intervalle Surface"	; Surface Interval
	TCODE	tCalcBotSeg,		"Calcul P. Max"			; Bottom Segment
	TCODE	tCalcBailout,		"Mode Bailout"			; Switch to Bailout
	TCODE	tCalcAscent,		"Remontée"				; Ascent (max. 8 chars)
	TCODE	tNDLleft,			"NDL"					; time left within NDL


; Information menu
	TCODE	tFirmware,			"Logiciel: "			; Firmware: (space)
	TCODE	tFirmwareDate,		"created : "			; created : (space)  firmware creation date
	TCODE	tHardware,			"Hardware: "			; Hardware: (space)
	TCODE	tSerial,			"N. Série: "			; Serial  : (space)
	TCODE	tBatteryV,			"Batterie: "			; Battery : (space)
	TCODE	tSensorC,			"Sensor  : "			; Sensor  : (space)
	TCODE	tSensorD,			"Offset  : "			; Offset  : (space)
	TCODE	tUptime,			"Mise a Jour:"			; Uptime:

 IFDEF _rx_functions
	TCODE	tFirmware_rx,		"RX Ver  : "			; RX Ver  : (space)
 ENDIF


; Divemode screen
	TCODE	tNDL,				"NDL"					; 3 chars
	TCODE	tTTS,				"DTR"					; 3 chars
	TCODE	tSlow,				"lente "				; slow - max 7 chars
	TCODE	tVelMetric,			"m/min"
	TCODE	tVelImperial,		"ft/m "
	TCODE	tGasSelect,			"Activer Gaz"			; Select Gas
	TCODE	tSelectAir,			"Air "					; Air
	TCODE	tSelectO2,			"O2  "					; O2
	TCODE	tSelectNx,			"Nx"					; Nx
	TCODE	tSelectTx,			"Tx"					; Tx
	TCODE	tDepth,				"Prof."					; Depth (max 5 chars)
	TCODE	tMaxDepth,			"Prof.Max."				; Max.Depth     - max 9 chars!
	TCODE	tAvgDepth,			"Prof.Moy."				; average Depth - max 9 chars!
	TCODE	tDivetime,			"Durée"					; Divetime (max 8 chars)
	TCODE	tDiveTotalAvg,		"Prof. Moy."
	TCODE	tDiveStopwatch,		"Chrono"
	TCODE	tDiveStopAvg,		"P.Moy.Chron"			; 11 chars max
	TCODE	tApnoeTotal,		"Totale"				; Total (six chars, right aligned)
	TCODE	tApnoeMax,			"Dern.Plongée"			; Last Descend
	TCODE	tApnoeSurface,		"Tps.Surface"			; Surface Time
	TCODE	tTime,				"Heure"					; Time
	TCODE	tSurface,			"Surface"				; Surface (max 12 chars)
	TCODE	tDiveDecoplan,		"Runtime"				; Decoplan
;	TCODE	tDiveClock,			"Heure"					; Clock
	TCODE	tDiveEAD_END,		"EAD/END"				; EAD/END
	TCODE	tDiveTissues,		"Tissus"				; Tissues
	TCODE	tEND,				"END:"					; END:
	TCODE	tN2,				"N2"					; N2
	TCODE	tDiveBailout,		"Bailout"				; Bailout (max. 7 chars)
	TCODE	tGFactors,			"Valeurs GF"			; GF Values
	TCODE	taGFactors,			"Valeurs aGF"			; aGF Values
	TCODE	tGFInfo,			"Saturation"			; Saturation
	TCODE	tCeiling,			"Plafond"				; Ceiling
	TCODE	tDiveFallback,		"Fallback!"				; Fallback! (max. nine chars)
	TCODE	tDecoInfo,			"Zone Déco"				; Deco info
	TCODE	tSensorCheck,		"  Ctrl Cell."			; Sensor Check
	TCODE	tdil,				"Dil:"					; Diluent ppO2 Warning
	TCODE	tmix,				"Mix:"					; Pre-Mix ppO2 Warning
	TCODE	tGasNeedsWarn,		"Gaz Needs"				;
	TCODE	tCNSsurf,			"SNC Surf."				; CNS Surf.
	TCODE	tCNSfTTS,			"SNC fDTR"				; CNS fTTS
	TCODE	tCNSBO,				"SNC B/O"				; CNS B/O
	TCODE	tCNSnow,			"SNC actuel"			; CNS now
	TCODE	tCNSeod,			"SNC final"				; CNS fin
 IFDEF _cave_mode
	TCODE	tCNScave,			"SNC Sout"				; CNS cave
 ENDIF
	TCODE	tnoBOgas,			"-B/O-Gaz-"				; no bailout gas
	TCODE	tMicroBubbles,		"M.Bulles "				;
	TCODE	tCNS,				"SNC: "					;
	TCODE	tgaschange,			"Changer?"				; better gas found
	TCODE	tNeed,				"Need "					; gas need (5 chars)
	TCODE	tBattery,			"Batterie"				; Battery

 IFDEF _helium
	TCODE	tHe,				"He"					; He
	TCODE	tIBCD,				"CDI N2He"				; IBCD warning
	TCODE	tGasDensity,		"G.Density"				; Gas Density				## pending translation
 ENDIF

 IFDEF _rx_functions
	TCODE	tTransmitter,		"P.Transm."				; pressure transmitter
	TCODE	tPressure,			"Pres Bloc"				; tank pressure
	TCODE	tSAC,				"SAC"					; SAC, must be 3 chars!
	TCODE	tswap,				"Bloc Ech."				; swap tank (max. 9 chars)
 ENDIF

 IFDEF _ccr_pscr
 IFDEF _external_sensor
	TCODE	tDiveHudMask1,		"Cell. 1"
	TCODE	tDiveHudMask2,		"Cell. 2"
	TCODE	tDiveHudMask3,		"Cell. 3"
	TCODE	tSensorDisagree,	"Sensors<>"				; Sensors disagree Warning; Sensors disagree Warning
 ENDIF
 ENDIF

 IFDEF _cave_mode
	TCODE	tGasNeedsCaveMode,	"Besoin Gaz  -SOUT- "	; title for gas needs custom view (cave mode)		| need to be
	TCODE	tGasNeedsAscent,	"Besoin Gaz Remontée"	; title for gas needs custom view (open water mode)	| same length
	TCODE	tCaveMode,			"Mode Sout"				; cave mode activated (max. 9 char)
	TCODE	tCaveModeShutdown,	"X-Sout-X"				; cave mode shut down (max. 9 char)
	TCODE	tCaveTTS,			"Cave TTS"				; cave mode total time to surface
	TCODE	tCaveStops,			"total Stops"			; cave mode total time for stops
	TCODE	tCaveRuntime,		"total RT"				; cave mode total runtime
 ELSE
	TCODE	tGasNeedsAscent,	"Besoin Gaz Remontée"	; title for gas needs custom view
 ENDIF


; Divemode menu
	TCODE	tDivePreMenu,		"Menu?"					; Menu?  (max. 5 chars)
	TCODE	tDiveLayout,		"Affich"				; Layout (max. 6 chars)
 IFDEF _compass
	TCODE	tSetHeading,		"Cap"					; Course (max. 6 chars)
 ENDIF


; Simulator menu
	TCODE	tQuitSim,			"Fin"					; Quit Simulation (max. 6 chars)
	TCODE	tResetAvg,			"RaZChr"				; Reset Timer     (max. 6 chars)


; Logbook
	TCODE	tCNS2,				"SNC: "
	TCODE	tAVG,				"Moy: "
	TCODE	tGF2,				"GF : "
	TCODE	tSAT,				"Sat:"					; max  4 chars
	TCODE	tDvSalinity2,		"Salinité  :"			; max 11 chars
	TCODE	tLastDeco,			"Der.Palier:"			; max 11 chars
	TCODE	tNoProfileData,		"no data anymore..."	; max 21 chars
	TCODE	tBeginOfDive,		"Begin:"				; max  8 chars
	TCODE	tEndOfDive,			"End:"					; max  8 chars
	TCODE	tDesatTime,			"Desat:"				; amx  8 chars

; other users
	TCODE	tGF,				"GF:"

; Logbook units
	TCODE	tLogTunitC,			"°C"
	TCODE	tLogTunitF,			"°F"
	TCODE	tKGL,				"kg/l"
	TCODE	tMBAR,				"hPa"


; Logbook menu
	TCODE	tNextLog,			"Page Suivante"


; Reset menu
	TCODE	tReboot,			"Redémarrage"			; Reboot
	TCODE	tResetMenu2,		"Confirmer?"			; Are You Sure?
	TCODE	tAbort,				"Quitter"				; Abort
	TCODE	tResetSettings,		"RaZ Paramètres"		; Reset Settings
	TCODE	tResetDeco,			"RaZ Déco"				; Reset Deco
	TCODE	tResetBattery,		"RaZ Batterie"			; Reset Battery
	TCODE	tResetLogbook,		"RaZ Carnet"			; Reset Logbook


; Set Time Menu/Set Date Menu
	TCODE	tSetHours,			"Ajust. Heures"			; Set Hours
	TCODE	tSetMinutes,		"Ajust. Minutes"		; Set Minutes
	TCODE	tSetSeconds,		"RaZ Secondes"			; Clear Seconds
	TCODE	tSetDay,			"Ajust. Jours"			; Set Day
	TCODE	tSetMonth,			"Ajust. Mois"			; Set Month
	TCODE	tSetYear,			"Ajust. Année"			; Set Year


; Logbook Offset Menu
	TCODE	tTotalDives,		"Nbre Plongées:"		; Total Dives
	TCODE	tLogOffset,			"N° 1ère Plongée"		; Logbook offset (Max. 15 Chars!)
	TCODE	tLogOffsetValue,	"N°1ère Plongé:"		; Offset
	TCODE	tLogOffStepSize,	"Incrément    :"		; Step Size
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
	TCODE	tColorSetDive,		"Mode Plongée:"			; Divemode:
	TCODE	tColorSetName0,		"Blanc"					; White
	TCODE	tColorSetName1,		"Rouge"					; Red
	TCODE	tColorSetName2,		"Vert"					; Green
	TCODE	tColorSetName3,		"Bleu"					; Blue


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
