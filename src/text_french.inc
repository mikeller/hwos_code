;=============================================================================
;
;	File text_french.asm                      next combined generation V3.03.3
;
;	French texts translation file. 
;
;	Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================

; Basic texts
	TCODE	tNo,				"Non"					; 0 No    | ENUM group
	TCODE	tYes,				"Oui"					; 1 Yes   |
 IFDEF _cave_mode
	TCODE	tCave,				"Cave"					; 2 Cave  |
 ENDIF

	TCODE	tblank,				" "						; (a single space character)

; Surface-mode texts
	TCODE	tMenu,				"<Menu"					; <Menu
	TCODE	tView,				"Vues>"					; View>
	TCODE	tHeading,			"Cap:"					; Heading:
	TCODE	tLastDive,			"Dern.Plong"			; Last Dive (Max 10 chars)

 IFDEF _external_sensor
	TCODE	tSensorMilliVolt,	"Cellules mV"			; Sensors mV
 ENDIF


; Divemode Menu
	TCODE	tDivemenu_Gaslist,	"Liste Gaz"				; Gas List (OC)
	TCODE	tDivemenu_ResetAvg,	"RaZChrono"				; Reset Avg
	TCODE	tDivemenu_Avg_Mkr,	"Avg/Marker"			; Reset Avg, Set Marker (and Turn Dive)	## pending translation
	TCODE	tDivemenu_ToggleGF,	"Bascul.GF"				; Toggle GF
	TCODE	tDivemenu_Marker,	"Repère"				; Set Marker
	TCODE	tDivemenu_LostGas,	"Gaz Perdu"				; Lost Gas

 IFDEF _ccr_pscr
	TCODE	tDivemenu_Diluent,	"Liste Dil"				; Diluents (CCR)
	TCODE	tDivemenu_Premix,	"Liste Mix"				; Premix   (pSCR)
	TCODE	tDivemenu_Setpoint,	"Setpoint"				; Setpoint
 ENDIF

 IFDEF _external_sensor
	TCODE	tDivemenu_UseSensor,"Cellules"				; Use Sensor
 ENDIF

 IFDEF _cave_mode
	TCODE	tDivemenu_TurnDive,	"Turn Dive"				; Turn Dive
 ENDIF

 
; Main menu
	TCODE	tNext,				"<Suivant"				; <Next
	TCODE	tEnter,				"Entrer>"				; Enter>
	TCODE	tMainMenu,			"Menu Principal"		; Main Menu
	TCODE	tLogbook,			"Carnet de Plongée"		; Logbook
	TCODE	tGasSetup,			"Paramètres Gaz OC"		; OC Gas Setup
	TCODE	tSetTime,			"Réglage Heure"			; Set Time
	TCODE	tSetDate,			"Réglage Date"			; Set Date
	TCODE	tSetTimeDate,		"Date & Heure"			; Set Time & Date
	TCODE	tDispSets,			"Préfér. Réglages"		; Display Settings
	TCODE	tExit,				"Retour"				; Exit
	TCODE	tResetMenu,			"Menu RaZ"				; Reset Menu
	TCODE	tDiveModeMenu,		"Menu Déco"				; Deco Mode
	TCODE	tInfoMenu,			"Informations"			; Information
 IFDEF _ccr_pscr
	TCODE	tCCRSetup,			"Paramètres CCR"		; CCR Setup
	TCODE	tDiluentSetup,		"Liste Diluant"			; Diluent Setup
 ENDIF
	TCODE	tFixedSetpoints,	"Setpoints Fixes"		; Fixed Setpoints
	TCODE	tBack,				"retour"				; back

 IFDEF _rx_functions
	TCODE	tTrSettings,		"Pressure Display"		; Pressure Display					## pending translation
	TCODE	tTrMode,			"Mode: "				; Mode
	TCODE	tTr1stPres,			"1.Pres.: "				; 1st Pressure
	TCODE	tTr2ndPres,			"2.Pres.: "				; 2nd Pressure
	TCODE	tTrBailPres,		"1.B/O  : "				; Bailout Pressure
	TCODE	tTrMaxDeltaP,		"max deltaP: "			; independent double max diffenerce	## pending translation
 ENDIF

 IFDEF _ccr_pscr
 IFDEF _external_sensor
	TCODE	tCCRSensor,			"Cellules CCR"			; CCR Sensor
	TCODE	tCalibrateMenu,		"Calibration"			; Calibration
	TCODE	tCalibrationGas,	"Cal. Gaz O2:"			; Cal. Gas O2:
	TCODE	tCalibrate,			"Calibrate"				; Calibrate
 ENDIF
 ENDIF


; Gas menu
	TCODE	tGaslist,			"Liste Gaz OC"			; OC Gas List
	TCODE	tGaslistCC,			"Liste Gaz CC"			; CC Diluents
	TCODE	tGasEdit,			"Préférence Gaz"		; Edit Gas
	TCODE	tType,				"Type: "
	TCODE	tGasDisabled,		"Désactivé"				; Disabled
	TCODE	tGasFirst,			"Premier"				; First
	TCODE	tGasTravel,			"Travel"				; Travel
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
	TCODE	tCCRMode,			"Mode CCR:"				; CCR Mode:
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
	TCODE	tGasErr,			"Err"					; Err (3 chars)


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
	TCODE	tDvMode,			"Mode: "
	TCODE	tDvOC,				"OC"
	TCODE	tDvCCR,				"CCR"
	TCODE	tDvGauge,			"Gauge"
	TCODE	tDvApnea,			"Apnée"
	TCODE	tDvPSCR,			"pSCR"
	TCODE	tDvCC,				"CC"
	TCODE	tDkMode,			"Modèle: ZH-L16"
	TCODE	tZHL16,				" "
	TCODE	tZHL16GF,			"+GF"
	TCODE	tPPO2Max,			"PpO2 Max :"
	TCODE	tPPO2DECO,			"PpO2 Déco:"
	TCODE	tPPO2MIN,			"PpO2 Min :"
 IFDEF _ccr_pscr
	TCODE	tPPO2MINCC,			"Min Loop :"
 ENDIF
	TCODE	tLastDecostop,		"Dern.Palier  : "
	TCODE	tAscentSpeed,		"Ascent Speed : "		; Ascent Speed							## pending translation
	TCODE	tGasChangeTime,		"Gas Change   :+"		; additional Gas Change Time			## pending translation
	TCODE	tExtendedStops,		"before 1.Stop: "		; gas switches before 1st stop			## pending translation
	TCODE	tTimeoutDive,		"Fin Plongée  : "		; Dive Timeout
	TCODE	tStoreApnoeDive,	"Store Apnoe  : "		; Store Apnoe Dives						## pending translation
	TCODE	tDecoparameters,	"Paramètres Déco"
	TCODE	tGF_low,			"GF  Bas :"
	TCODE	tGF_high,			"GF  Haut:"
	TCODE	tSaturationMult,	"Saturation  : "
	TCODE	tDesaturationMult,	"Désaturation: "
	TCODE	tFTTSMenu,			"Future DTR:"			; Future TTS
	TCODE	tLastDecostopSurf,	"Dern.Palier:"			; last deco stop depth Surface Custom View
	TCODE	tGFMenu,			"Menu GF"				; GF Settings
	TCODE	taGF_low,			"aGF Bas :"				; aGF Low
	TCODE	taGF_high,			"aGF Haut:"				; aGF High
	TCODE	taGF_enable,		"aGF Possible:"			; aGF Selectable
	TCODE	tDiveaGF_active,	"using aGF"				; using aGF								## pending translation
	TCODE	tppO2settings,		"Menu PpO2"				; ppO2 Settings (max. 18 chars)
	TCODE	tsafetystopmenu,	"Palier Sécurité:"		; Safety Stop: (max. 16 chars)
	TCODE	tGasUsage,			"Usage Gaz"				; Gas Usage
	TCODE	tSetBotUse,			"Gaz Fond: "			; Bottom Gas: (space)
	TCODE	tSetDecoUse,		"Gaz Déco: "			; Deco   Gas: (space)
	TCODE	tCalcAscGas,		"Calc.Gaz (B/O):"		; Calculate Gas (Bail Out) needs?
	TCODE	tSetup_Tank,		"Config. Blocs"			; Setup Tank
	TCODE	tTankSize,			"Volume   Bloc"			; Tank Sizes
	TCODE	tTankUsablePress,	"Pression Ascent"		; Tank Pressure Budget for Ascent (turn pressure) (max 19 chars)	## pending translation
	TCODE	tLiter,				" l"					; Liter as l
	TCODE	tLiterLong,			"Liter"					; Liter as Liter
	TCODE	t2ndDecoPlanMenu,	"Suite Menu Déco"		; 2nd Deco Plan

 IFDEF _ccr_pscr
	TCODE	tCCmaxFracO2,		"Loop %O2 max.:"		;
	TCODE	tCopyDilToOC,		"Copy  Dil.-> OC"		; copy diluent settings to OC gas		## pending translation
 ENDIF

 IFDEF _rx_functions
	TCODE	tTankPairing,		"Config. Transmitter"	; select Transmitter					## pending translation
	TCODE	tTrModeOff,			"off"					; off									## pending translation
	TCODE	tTrModeOn,			"on"					; on									## pending translation
	TCODE	tTrModeIndDouble,	"indep.Double"			; independent double					## pending translation
	TCODE	tTrModeCCR,			"CCR Dil+O2"			; CCR diluent and O2
	TCODE	tTrPresNone,		"none"					; none  (big enum group follows)		## pending translation
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
	TCODE	tTrPresFirstGas,	"First Gas"				; first  Gas							## pending translation
	TCODE	tTrPresActiveGas,	"active Gas"			; active Gas							## pending translation
	TCODE	tTrPresFirstDil,	"First Dil"				; first  Dil							## pending translation
	TCODE	tTrPresActiveDil,	"active Dil"			; active Dil							## pending translation
 ENDIF
 ELSE
 	TCODE	tTrModeOff,			""						; dummy target for entry in option table
	TCODE	tTrPresNone,		""						; dummy target for entry in option table
 ENDIF	; _rx_functions


; Display Settings
	TCODE	tBright,			"Luminosité:"
	TCODE	tEco,				"Eco"
	TCODE	tMedium,			"Moyenne"
	TCODE	tHigh,				"Haute"
	TCODE	tDvSalinity,		"Salinité:  "			; Salinity
	TCODE	tShowppO2,			"Afficher PpO2:"		; Always show ppO2:
	TCODE	tFlip,				"Pivoter l'écran:"		; Rotate Screen
	TCODE	tMODwarning,		"Alerte Prof.:"			; depth Warnings
;	TCODE	tIBCDwarning,		"Alerte CDI  :"			; IBCD Warning
	TCODE	tLayout,			"Layout :"				; Layout								## pending translation
	TCODE	t2ndDepth,			"2.Prof.:"				; 2nd depth display content (10 chars max)
	TCODE	tTissueGraphics,	"Dessin :"				; tissue graphics

	TCODE	tLayoutNormal,		"normal"				; normal								## pending translation
	TCODE	tLayoutBig,			"big"					; big									## pending translation


; VSI display Settings
	TCODE	tVSItext2,			"Vitesse Variable:"		; Variable speed:
	TCODE	tVSIgraph,			"Graph.  Vitesse :"		; Speed graph:


; Setup Menu
	TCODE	tSystSets,			"Réglages"
 IFDEF _compass
	TCODE	tCompassMenu,		"Calibration Compas"	; Compass Calibration
	TCODE	tCompassGain,		"Sensibilité:"			; Compass Gain:
	TCODE	tCalX,				"Cal X:"				; Cal X
	TCODE	tCalY,				"Cal Y:"				; Cal Y
	TCODE	tCalZ,				"Cal Z:"				; Cal Z
 ENDIF
	TCODE	tUnits,				"Unités:"
	TCODE	tMetric,			" m/°C"					; Enum menu
	TCODE	tImperial,			"ft/°F"
								;         111         111         111         111         111
	; 5 rows by 12 chars each:	 123456789012123456789012123456789012123456789012123456789012
	TCODE	tDefName,			"  Read the  Manual, know& understandthe inherentLimitations!"	## pending translation
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
	TCODE	tPlan,				"Simulateur"			; Simulator


; Decoplanner submenu
	TCODE	tBtTm,				"Temps Fond:"			; Bot. Time: (10 chars)
	TCODE	tBtTm_short,		"Temps:"				; Bot. Time: (max. 6 chars)
	TCODE	tBtDep,				"Prof. Max :"			; Max Depth: (10 chars)
	TCODE	tIntvl,				"Intervalle:"			; Interval : (10 chars)
	TCODE	tDecoSetup,			"Réglage Ordinateur"	; Calculator Setup
	TCODE	tDeco,				"Calcul Déco"			; Calculate Deco
	TCODE	tDivePlan,			"Runtime"				; Dive Plan (max. 10 chars)
	TCODE	tNoDeco,			"Pas de Déco"			; No Deco
	TCODE	tMore,				"Suite"					; More
	TCODE	tSelectSetpoint,	"Setpoint  :"
	TCODE	tuseAGF,			"aGF Permis:"			; use aGF
	TCODE	tCalculating,		"Calcul en cours"		; Calculating
	TCODE	tCalcSurfInter,		"Surface Interval"		; Surface Interval						## pending translation
	TCODE	tCalcBotSeg,		"Bottom  Segment"		; Bottom Segment						## pending translation
	TCODE	tCalcBailout,		"Switch  to Bailout"	; Switch to Bailout						## pending translation
	TCODE	tCalcAscent,		"Ascent"				; Ascent								## pending translation
	TCODE	tNDLleft,			"left"					; time left within NDL					## pending translation


; Information menu
	TCODE	tFirmware,			"Logiciel: "			; Firmware: (space)
	TCODE	tSerial,			"N. Série: "			; Serial  : (space)
	TCODE	tTotalDives,		"Nbre Plongées:"		; Total Dives: (space)
	TCODE	tBatteryV,			"Batterie: "			; Battery:
	TCODE	tUptime,			"Mise a Jour:"			; Uptime:

 IFDEF _rx_functions
	TCODE	tFirmware_rx,		"RX Ver  : "			; RX Ver  : (space)
 ENDIF


; Divemode screen
	TCODE	tNDL,				"NDL"					; 3 chars max
	TCODE	tTTS,				"DTR"					; 3 chars max
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
	TCODE	tTissuePresSat,		"Pres+Sat"				; 0 pressure and saturation  | ENUM group	## pending translation
 IFDEF _helium
	TCODE	tTissueN2He,		"N2+He"					; 1 N2 + He pressure         |
 ENDIF
	TCODE	tDivetime,			"Durée"					; Divetime (max 8 chars)
	TCODE	tDiveTotalAvg,		"Prof. Moy."
	TCODE	tDiveStopwatch,		"Chrono"
	TCODE	tDiveStopAvg,		"P.Moy.Chron"			; 11 chars max
	TCODE	tApnoeTotal,		"Totale"				; Total (six chars, right aligned)
	TCODE	tApnoeMax,			"Dern.Plongée"			; Last Descend
	TCODE	tApnoeSurface,		"Tps.Surface"			; Surface Time
	TCODE	tTime,				"Time"					; Time							## pending translation
	TCODE	tSurface,			"Surface"				; Surface (max 12 chars)		## pending translation
	TCODE	tDiveDecoplan,		"Runtime"				; Decoplan
;	TCODE	tDiveClock,			"Heure"					; Clock
	TCODE	tDiveEAD_END,		"EAD/END"				; EAD/END
	TCODE	tDiveTissues,		"Tissus"				; Tissues
	TCODE	tEND,				"END:"					; END:
	TCODE	tN2,				"N2"					; N2
	TCODE	tDiveBailout,		"Bailout"				; Bailout (max. 7 chars)
	TCODE	tGFactors,			"Valeurs GF"			; GF Values
	TCODE	taGFactors,			"Valeurs aGF"			; aGF Values
	TCODE	tGFInfo,			"Saturation"			; Saturation					## pending translation
	TCODE	tCeiling,			"Plafond"				; Ceiling
	TCODE	tDiveSafetyStop,	"Stop"					; Stop (four chars, right aligned)
	TCODE	tDiveFallback,		"Fallback!"				; Fallback! (max. nine chars)
	TCODE	tDecoInfo,			"Zone Déco"				; Deco info
	TCODE	tSensorCheck,		"Ctrl Cell. "			; Sensor Check
	TCODE	tdil,				"Dil:"					; Diluent ppO2 Warning
	TCODE	tmix,				"Mix:"					; Pre-Mix ppO2 Warning
	TCODE	tGasNeedsWarn,		"Gas Needs"				;
	TCODE	tGasNeedsAscent,	"Besoins Gaz Ascent"	;								## pending translation
	TCODE	tCNSsurf,			"SNC Surf."				; CNS Surf.
	TCODE	tCNSfTTS,			"SNC fDTR"				; CNS fTTS
	TCODE	tCNSBO,				"SNC B/O"				; CNS B/O
	TCODE	tCNSnow,			"SNC actuel"			; CNS now
	TCODE	tCNSeod,			"SNC final"				; CNS fin
	TCODE	tnoBOgas,			"-B/O-Gaz-"				;
	TCODE	tMicroBubbles,		"M.Bulles "				;
	TCODE	tCNS,				"SNC: "					;
	TCODE	tgaschange,			"Change?"				; better gas found				## pending translation
	TCODE	tNeed,				"Need "					; gas need (5 chars)			## pending translation
	TCODE	tBattery,			"Batterie"				; Battery

 IFDEF _helium
	TCODE	tHe,				"He"					; He
	TCODE	tIBCD,				"CDI N2He"				; IBCD warning
 ENDIF

 IFDEF _rx_functions
	TCODE	tTransmitter,		"P.Transm."				; pressure transmitter			## pending translation
	TCODE	tPressure,			"Pres Bloc"				; tank pressure
	TCODE	tSAC,				"SAC"					; SAC, must be 3 chars!
	TCODE	tswap,				"Swap Tank"				; swap tank (max. 9 chars)		## pending translation
 ENDIF

 IFDEF _ccr_pscr
 IFDEF _external_sensor
	TCODE	tDiveHudMask1,		"cell. 1"
	TCODE	tDiveHudMask2,		"cell. 2"
	TCODE	tDiveHudMask3,		"cell. 3"
	TCODE	tSensorDisagree,	"Sensors<>"				; Sensors disagree Warning; Sensors disagree Warning
 ENDIF
 ENDIF

 IFDEF _cave_mode
	TCODE	tGasNeedsCaveMode,	"Besoins Gaz Cave Mode"	; title for gas needs custom view
	TCODE	tDiveTurned,		"Dv.turned"				; dive is turned      (max. 9 char)	## pending translation
	TCODE	tCaveMode,			"Cave Mode"				; cave mode activated (max. 9 char)
	TCODE	tCaveModeShutdown,	"X-Cave-X"				; cave mode shut down (max. 9 char)
 ENDIF


; Divemode menu
	TCODE	tDivePreMenu,		"Menu?"					; Menu?   (max. 5 chars)
 IFDEF _compass
	TCODE	tSetHeading,		"Cap"					; Bearing (max. 6 chars)
 ENDIF


; Simulator menu
	TCODE	tQuitSim,			"Fin"					; Quit Simulation (max. 6 chars)
	TCODE	tResetAvg,			"RaZChr"				; Reset Timer     (max. 6 chars)


; Logbook
	TCODE	tCNS2,				"SNC:"
	TCODE	tAVG,				"Moy:"
	TCODE	tGF,				"GF:"
	TCODE	tSAT,				"Sat:"					; 4 chars max


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
	TCODE	tResetSettings,		"RaZ Settings"			; Reset Settings				## pending translation
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
	TCODE	tLogOffset,			"N° 1ère plongée"		; Logbook offset (Max. 15 Chars!)
	TCODE	tLogOffsetValue,	"Offset   : "			; Offset						## pending translation
	TCODE	tLogOffStepSize,	"Step Size: "			; Step Size						## pending translation
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
	TCODE	tColorScheme,		"Jeu de Couleurs"		; Colour scheme
	TCODE	tColorSetDive,		"Mode Plongée:"			; Divemode:
	TCODE	tColorSetName0,		"Blanc"					; White
	TCODE	tColorSetName1,		"Rouge"					; Red
	TCODE	tColorSetName2,		"Vert"					; Green
	TCODE	tColorSetName3,		"Bleu"					; Blue


; PSCR Menu and Settings
 IFDEF _ccr_pscr
	TCODE	tPSCRMenu,			"Menu pSCR"				; PSCR Menu
	TCODE	tPSCR_O2_drop,		"O2 Drop    "			; O2 drop
	TCODE	tPSCR_lungratio,	"Lung Ratio "			; lung ratio
	TCODE	tBackToLoop,		"goto loop"				; back to loop (10 chars max)
 ENDIF


; Language selection
 IF _language_2!=none
	TCODE	tLanguage,			"Langue: "				; used in menu_tree
 ENDIF

 IF _language_1==en
	TCODE	tLang1,				"Anglais"				; tLang1 is 1st language, enum context
 ELSE
 IF _language_1==de
	TCODE	tLang1,				"Allemand"
 ELSE
 IF _language_1==fr
	TCODE	tLang1,				"Français"
 ELSE
 IF _language_1==it
	TCODE	tLang1,				"Italien"
 ELSE
	TCODE	tLang1,				""						; dummy target for options table
 ENDIF
 ENDIF
 ENDIF
 ENDIF

 IF _language_2==en
	TCODE	tLang2,				"Anglais"
 ELSE
 IF _language_2==de
	TCODE	tLang2,				"Allemand"				; tLang2 is 2nd language, enum context
 ELSE
 IF _language_2==fr
	TCODE	tLang2,				"Français"
 ELSE
 IF _language_2==it
	TCODE	tLang2,				"Italien"
 ENDIF
 ENDIF
 ENDIF
 ENDIF
