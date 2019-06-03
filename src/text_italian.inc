;=============================================================================
;
;	File text_italian.asm                     next combined generation V3.03.3
;
;	Italian texts translation file.
;
;	Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================

; Basic texts
	TCODE	tNo,				"No"					; 0 No
	TCODE	tYes,				"Si"					; 1 Yes
 IFDEF _cave_mode
	TCODE	tCave,				"Cave"					; 2 Cave
 ENDIF

	TCODE	tblank,				" "						; (a single space character)

; Surface-mode texts
	TCODE	tMenu,				"<Menu"					; <Menu
	TCODE	tView,				"Vedi>"					; View>
	TCODE	tHeading,			"Direzione:"			; Heading:
	TCODE	tLastDive,			"UltimaImm."			; Last Dive (Max 10 chars)

 IFDEF _external_sensor
	TCODE	tSensorMilliVolt,	"Sensori mV"			; Sensors mV
 ENDIF


; Divemode Menu
	TCODE	tDivemenu_Gaslist,	"Lista Gas"				; Gaslist  (OC)
	TCODE	tDivemenu_ResetAvg,	"AzzeraMed"				; Reset Avg
	TCODE	tDivemenu_Avg_Mkr,	"Avg/Marker"			; Reset Avg, Set Marker (and Turn Dive)	## pending translation
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
	TCODE	tDivemenu_TurnDive,	"Turn Dive"				; Turn Dive
 ENDIF


; Main menu
	TCODE	tNext,				"<Prossimo"				; <Next
	TCODE	tEnter,				" Enter>"				; Enter>
	TCODE	tMainMenu,			"Menu Principale"		; MainMenu
	TCODE	tLogbook,			"Logbook"				; Logbook
	TCODE	tGasSetup,			"Imposta Gas OC"		; OC Gas Setup
	TCODE	tSetTime,			"Imposta Ora"			; Set Time
	TCODE	tSetDate,			"Imposta Data"			; Set Date
	TCODE	tSetTimeDate,		"Imp. Ora e Data"		; Set Time & Date
	TCODE	tDispSets,			"Visualizzazione"		; Display Settings
	TCODE	tExit,				"Esci"					; Exit
	TCODE	tResetMenu,			"Resetta Menu"			; Reset Menu
	TCODE	tDiveModeMenu,		"Modalita' Deco"		; Deco Mode
	TCODE	tInfoMenu,			"Informazioni"			; Information
 IFDEF _ccr_pscr
	TCODE	tCCRSetup,			"Imposta CCR"			; CCR Setup
	TCODE	tDiluentSetup,		"Imposta Diluente"		; Diluent Setup
 ENDIF
	TCODE	tFixedSetpoints,	"Setpoints Fissi"		; Fixed Setpoints
	TCODE	tBack,				"back"					; back

 IFDEF _rx_functions
	TCODE	tTrSettings,		"Pressure Display"		; Pressure Display								## pending translation
	TCODE	tTrMode,			"Modo: "				; Mode
	TCODE	tTr1stPres,			"1.Pres.: "				; 1st Pressure
	TCODE	tTr2ndPres,			"2.Pres.: "				; 2nd Pressure
	TCODE	tTrBailPres,		"1.B/O  : "				; Bailout Pressure
	TCODE	tTrMaxDeltaP,		"max deltaP: "			; independent double max diffenerce				## pending translation
 ENDIF

 IFDEF _ccr_pscr
 IFDEF _external_sensor
	TCODE	tCCRSensor,			"Sensori CCR"			; CCR Sensor
	TCODE	tCalibrateMenu,		"Calibrazione"			; Calibration
	TCODE	tCalibrationGas,	"Cal. Gas O2:"			; Cal. Gas O2:
	TCODE	tCalibrate,			"Calibra"				; Calibrate
 ENDIF
 ENDIF


; Gas menu
	TCODE	tGaslist,			"Lista Gas OC"
	TCODE	tGaslistCC,			"Lista Gas CC"			; CC Diluents
	TCODE	tGasEdit,			"Modifica Gas"
	TCODE	tType,				"Tipo: "
	TCODE	tGasDisabled,		"Disabilitato"			; Disabled
	TCODE	tGasFirst,			"Primo"					; First
	TCODE	tGasTravel,			"Viaggio"				; Travel
	TCODE	tGasDeco,			"Deco"					; Deco
	TCODE	tDilDisabled,		"Disabilitato"			; Disabled
	TCODE	tDilFirst,			"Primo"					; First
	TCODE	tDilNorm,			"Normale"				; Normal
	TCODE	tAir,				"Aria "					; Enum: values must follow (5 chars)
	TCODE	tO2,				"O2   "					; tAir + 5
	TCODE	tO2Plus,			"O2 +"
	TCODE	tO2Minus,			"O2 -"
 IFDEF _helium
	TCODE	tHePlus,			"He +"
	TCODE	tHeMinus,			"He -"
 ENDIF
	TCODE	tMOD,				"MOD :"
	TCODE	tEAD,				"EAD:"
	TCODE	tSetup_GasDepth,	"Cambia profondita'"
	TCODE	tDepthPlus,			"Profondita' +"
	TCODE	tDepthMinus,		"Profondita' -"
	TCODE	tDepthReset,		"Reset a MOD:"
	TCODE	tSetup_GasMix,		"Cambia Miscela"
 IFDEF _ccr_pscr
	TCODE	tSPPlus,			"ppO2+"					; pO2+
	TCODE	tSensorFallback,	"Fallback:"				; Fallback:
	TCODE	tCalculated,		"calcolato"				; calculated
	TCODE	tppO2O2,			"ppO2(O2)"				; ppO2(O2)
	TCODE	tppO2Dil,			"ppO2(Dil)"				; ppO2(Dil)
	TCODE	tppO2Mix,			"ppO2(Mix)"				; ppO2(Mix)
	TCODE	tCCRMode,			"Modo CCR:"				; CCR Mode:
	TCODE	tCCRModeFixedSP,	"SP Fissi"				; 0 fixed for CCR / calculated for pSCR  | ENUM group
	TCODE	tCCRModeSensor,		"Sensori"				; 1 Sensor                               |
	TCODE	tCCRModeAutoSP,		"SP Auto"				; 2 Auto SP                              |
 ELSE
	TCODE	tCCRModeFixedSP,	" "						; target needed by option table
 ENDIF
	TCODE	tSP,				"SP"					; SP (SetPoint)
	TCODE	tppO2,				"ppO2:"					; ppO2:


; New battery menu
	;                                     1         2	;
	;                            12345678901234567890	; max 20 chars
	TCODE	tNewBattTitle,		"Nuova Batteria?"
	TCODE	tNewBattOld,		"Mantieni vecchio"
	TCODE	tNewBattNew36,		"3,6V monouso    (T1)"	; new 3.6V disposable
	TCODE	tNewBattNew15,		"1,5V monouso    (T0)"	; new 1.5V disposable
	TCODE	tNewBattAccu,		"3,7V ricaricare (T2)"	; new 3.7V rechargeable
	TCODE	tNew18650,			"OSTC 2 o cR     (T3)"	; internal battery on 2 (old) / cR
	TCODE	tNew16650,			"OSTC 2 o TR     (T4)"	; internal battery on 2 (new) / TR
	TCODE	tConfirmChargeable1,"Conferma:"				; safety question, line 1
	TCODE	tConfirmChargeable2,"la batteria inserita"	; safety question, line 2
	TCODE	tConfirmChargeable3,"è ricaricabile"		; safety question, line 3


; Gaslist management
	TCODE	tGas,				"Gas"					; Gas
	TCODE	tDil,				"Dil"					; Diluent
	TCODE	tGasErr,			"Err"					; Err (3 chars)


; Communication Menu
	TCODE	tUsbTitle,			"Modalita' USB"
	TCODE	tBleTitle,			"Modalita' Bluetooth"
	TCODE	tUsbStarting,		"Avvio..."
	TCODE	tUsbStartDone,		"Fatto."
	TCODE	tUsbServiceMode,	"Modo Servizio abil"
	TCODE	tUsbClosed,			"Porta chiusa"
	TCODE	tUsbExit,			"Uscita"
	TCODE	tUsbDownloadMode,	"Modo Download abil"
	TCODE	tUsbLlBld,			"Livello-basso Bootloader"


; Dive Settings
	TCODE	tDvMode,			"Tipo Tuffo:"
	TCODE	tDvOC,				"OC"
	TCODE	tDvCCR,				"CCR"
	TCODE	tDvGauge,			"Gauge"
	TCODE	tDvApnea,			"Apnea"
	TCODE	tDvPSCR,			"pSCR"
	TCODE	tDvCC,				"CC"
	TCODE	tDkMode,			"Algorit.: ZH-L16"
	TCODE	tZHL16,				" "
	TCODE	tZHL16GF,			"+GF"
	TCODE	tPPO2Max,			"ppO2 Max :"
	TCODE	tPPO2DECO,			"ppO2 Deco:"
	TCODE	tPPO2MIN,			"ppO2 Min :"
 IFDEF _ccr_pscr
	TCODE	tPPO2MINCC,			"Loop Min :"
 ENDIF
	TCODE	tLastDecostop,		"Ultima Deco   : "
	TCODE	tAscentSpeed,		"Ascent Speed  : "		; Ascent Speed							## pending translation
	TCODE	tGasChangeTime,		"Gas Change    :+"		; additional Gas Change Time			## pending translation
	TCODE	tExtendedStops,		"before 1.Stop : "		; gas switches before 1st stop			## pending translation
	TCODE	tTimeoutDive,		"Timeout Immsni: "		; Dive Timeout
	TCODE	tStoreApnoeDive,	"Store Apnoe   : "		; Store Apnoe Dives						## pending translation
	TCODE	tDecoparameters,	"Parametri Deco"
	TCODE	tGF_low,			"GF  Basso:"
	TCODE	tGF_high,			"GF  Alto :"
	TCODE	tSaturationMult,	"Saturazione  : "
	TCODE	tDesaturationMult,	"Desaturazione: "
	TCODE	tFTTSMenu,			"TTS Futuro:"			; Future TTS
	TCODE	tLastDecostopSurf,	"Ultima Deco:"			; last deco stop surface custom view
	TCODE	tGFMenu,			"Menu GF"				; GF Settings
	TCODE	taGF_low,			"aGF Basso:"			; aGF low
	TCODE	taGF_high,			"aGF Alto :"			; aGF high
	TCODE	taGF_enable,		"aGF Selezionabile:"	; aGF Selectable
	TCODE	tDiveaGF_active,	"using aGF"				; using aGF								## pending translation
	TCODE	tppO2settings,		"Menu ppO2"				; ppO2 Settings (max. 18 chars)
	TCODE	tsafetystopmenu,	"Tappa Sicurezza:"		; Safety Stop: (max. 16 chars)
	TCODE	tGasUsage,			"Utilizzo Gas"			; Gas Usage
	TCODE	tSetBotUse,			"Gas Fondo: "			; Bottom Gas: (space)
	TCODE	tSetDecoUse,		"Gas Deco : "			; Deco   Gas: (space)
	TCODE	tCalcAscGas,		"Calc.Gas (B/O):"		; Calculate Gas (Bail Out) needs?
	TCODE	tSetup_Tank,		"Imposta Bombola"		; Setup Tank
	TCODE	tTankSize,			"Capac. Bombola"		; Tank Size
	TCODE	tTankUsablePress,	"Press. Necess. Asc."	; Tank Press Budget for Ascent (turn pressure)	## pending translation
	TCODE	tLiter,				" l"					; Liter as l
	TCODE	tLiterLong,			"Litri"					; Liter as Liter
	TCODE	t2ndDecoPlanMenu,	"2o Piano Deco"			; 2nd Deco Plan

 IFDEF _ccr_pscr
	TCODE	tCCmaxFracO2,		"%O2 max Loop:"			;
	TCODE	tCopyDilToOC,		"Copy Dil->OC"			; copy diluent settings to OC gas		## pending translation
 IFDEF _ccr_pscr

 IFDEF _rx_functions
	TCODE	tTankPairing,		"Cambia Transmitter"	; select Transmitter					## pending translation
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
	TCODE	tBright,			"Luminosita':"
	TCODE	tEco,				"Eco"
	TCODE	tMedium,			"Media"
	TCODE	tHigh,				"Alta"
	TCODE	tDvSalinity,		"Salinita': "			; Salinity
	TCODE	tShowppO2,			"ppO2 Permanente:"		; Always show ppO2:
	TCODE	tFlip,				"Ruota schermo:"		; Rotate Screen
	TCODE	tMODwarning,		"Avvertimento Prof:"	; depth warnings
;	TCODE	tIBCDwarning,		"Avvertimento IBCD:"	; IBCD Warning
	TCODE	tLayout,			"Layout :"				; Layout								## pending translation
	TCODE	t2ndDepth,			"2.Prof.:"				; 2nd depth display content (10 chars max)
	TCODE	tTissueGraphics,	"Grafica:"				; tissue graphics

	TCODE	tLayoutNormal,		"normal"				; normal								## pending translation
	TCODE	tLayoutBig,			"big"					; big									## pending translation


; VSI display Settings
	TCODE	tVSItext2,			"Velox Variabile:"		; Variable speed:
	TCODE	tVSIgraph,			"Grafico Velocita':"	; Speed graph:


; Setup Menu
	TCODE	tSystSets,			"Impostazioni"
 IFDEF _compass
	TCODE	tCompassMenu,		"Calibra Bussola"		; Compass calibration
	TCODE	tCompassGain,		"Suscettibilita:"		; Compass gain:
	TCODE	tCalX,				"Cal X:"				; Cal X
	TCODE	tCalY,				"Cal Y:"				; Cal Y
	TCODE	tCalZ,				"Cal Z:"				; Cal Z
 ENDIF
	TCODE	tUnits,				"Unita':"
	TCODE	tMetric,			" m/°C"					; Enum menu
	TCODE	tImperial,			"ft/°F"
								;         111         111         111         111         111
	; 5 rows by 12 chars each:	 123456789012123456789012123456789012123456789012123456789012
	TCODE	tDefName,			"  Read the  Manual, know& understandthe inherentLimitations!"	## pending translation
	TCODE	tButtonleft,		"Bottone Sx:"			; Left button
	TCODE	tButtonright,		"Bottone Dx:"			; Right button
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
	TCODE	tPlan,				"Simulatore"			; Simulator


; Decoplanner submenu
	TCODE	tBtTm,				"Tempo Fondo :"			; Bot. Time: (10 chars)
	TCODE	tBtTm_short,		"Tempo:"				; Bot. Time: (max. 6 chars)
	TCODE	tBtDep,				"Profond. Max:"			; Max Depth: (10 chars)
	TCODE	tIntvl,				"Int.Superf. :"			; Interval : (10 chars)
	TCODE	tDecoSetup,			"Setta Calcoli"			; Deco Setup
	TCODE	tDeco,				"Calcola Deco"			; Calculate Deco
	TCODE	tDivePlan,			"Pianificat"			; Dive Plan (max. 10 chars)
	TCODE	tNoDeco,			"No Deco"				; No Deco
	TCODE	tMore,				"Dettagli"				; More
	TCODE	tSelectSetpoint,	"Setpoint CCR: "		;
	TCODE	tuseAGF,			"usa aGF     : "		; use aGF
	TCODE	tCalculating,		"Calcolando..."			; calculating...
	TCODE	tCalcSurfInter,		"Surface Interval"		; Surface Interval						## pending translation
	TCODE	tCalcBotSeg,		"Bottom  Segment"		; Bottom Segment						## pending translation
	TCODE	tCalcBailout,		"Switch  to Bailout"	; Switch to Bailout						## pending translation
	TCODE	tCalcAscent,		"Ascent"				; Ascent								## pending translation
	TCODE	tNDLleft,			"left"					; time left within NDL					## pending translation


; Information menu
	TCODE	tFirmware,			"Firmware: "			; Firmware: (space)
	TCODE	tSerial,			"Seriale : "			; Serial  : (space)
	TCODE	tTotalDives,		"Tot Immersioni:"		; Total Dives:
	TCODE	tBatteryV,			"Batteria: "			; Battery:
	TCODE	tUptime,			"Uptime: "				; Uptime: 

 IFDEF _rx_functions
	TCODE	tFirmware_rx,		"RX Ver  : "			; RX Ver  : (space)
 ENDIF


; Divemode screen
	TCODE	tNDL,				"NDL"					; 3 chars max
	TCODE	tTTS,				"TTS"					; 3 chars max
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
	TCODE	tTissuePresSat,		"Pres+Sat"				; 0 pressure and saturation  | ENUM group	## pending translation
 IFDEF _helium
	TCODE	tTissueN2He,		"N2+He"					; 1 N2 + He pressure         |
 ENDIF
	TCODE	tDivetime,			"Divetime"				; Divetime  (max 8 chars)
	TCODE	tDiveTotalAvg,		"Media"
	TCODE	tDiveStopwatch,		"Cronometro"
	TCODE	tDiveStopAvg,		"Media Inter"			; 11 chars max
	TCODE	tApnoeTotal,		"Totale"				; Total (six chars, right aligned)
	TCODE	tApnoeMax,			"Ultima Discesa"		; Last descend
	TCODE	tApnoeSurface,		"Tp.Superficie"			; Surface Time
	TCODE	tTime,				"Time"					; Time							## pending translation
	TCODE	tSurface,			"Surface"				; Surface (max 12 chars)		## pending translation
	TCODE	tDiveDecoplan,		"Piano Deco"			; Decoplan
;	TCODE	tDiveClock,			"Orologio"				; Clock
	TCODE	tDiveEAD_END,		"EAD/END"				; EAD/END
	TCODE	tDiveTissues,		"Tessuti"				; Tissues
	TCODE	tEND,				"END:"					; END:
	TCODE	tN2,				"N2"					; N2
	TCODE	tDiveBailout,		"Bailout"				; Bailout (max. 7 chars)
	TCODE	tGFactors,			"Valori GF"				; GF Values
	TCODE	taGFactors,			"Valori aGF"			; aGF Values
	TCODE	tGFInfo,			"Saturation"			; Saturation					## pending translation
	TCODE	tCeiling,			"Tetto"					; Ceiling
	TCODE	tDiveSafetyStop,	"Stop"					; Stop (four chars, right aligned)
	TCODE	tDiveFallback,		"Fallback!"				; Fallback! (max. nine chars)
	TCODE	tDecoInfo,			"Zona Deco"				; Deco info
	TCODE	tSensorCheck,		"Testa Sensori"			; Sensor Check
	TCODE	tdil,				"Dil:"					; Diluent ppO2 Warning
	TCODE	tmix,				"Mix:"					; Pre-Mix ppO2 Warning
	TCODE	tGasNeedsWarn,		"Gas Neces"				;
	TCODE	tGasNeedsAscent,	"Gas Necess. Ascent"	;								## pending translation
	TCODE	tCNSsurf,			"CNS Surf."				;
	TCODE	tCNSfTTS,			"CNS fTTS"				;
	TCODE	tCNSBO,				"CNS B/O"				;
	TCODE	tCNSnow,			"CNS ora"				;
	TCODE	tCNSeod,			"CNS finale"			;
	TCODE	tnoBOgas,			"-B/O-Gas-"				;
	TCODE	tMicroBubbles,		"M.Bolle"				;
	TCODE	tCNS,				"CNS: "					;
	TCODE	tgaschange,			"Change?"				; better gas found				## pending translation
	TCODE	tNeed,				"Need "					; gas need (5 chars)			## pending translation
	TCODE	tBattery,			"Batteria"				; Battery

 IFDEF _helium
	TCODE	tHe,				"He"					; He
	TCODE	tIBCD,				"IBCD N2He"				; IBCD warning
 ENDIF

 IFDEF _rx_functions
	TCODE	tTransmitter,		"P.Transm."				; pressure transmitter			## pending translation
	TCODE	tPressure,			"P.Bombola"				; tank pressure
	TCODE	tSAC,				"SAC"					; SAC, must be 3 chars!
	TCODE	tswap,				"Swap Tank"				; swap tank (max. 9 chars		## pending translation
 ENDIF

 IFDEF _ccr_pscr
 IFDEF _external_sensor
	TCODE	tDiveHudMask1,		"Sensore1"
	TCODE	tDiveHudMask2,		"Sensore2"
	TCODE	tDiveHudMask3,		"Sensore3"
	TCODE	tSensorDisagree,	"Sensori<>"				; Sensors disagree Warning
 ENDIF
 ENDIF

 IFDEF _cave_mode
	TCODE	tGasNeedsCaveMode,	"Gas Necess. Cave Mode"	; title for gas needs custom view
	TCODE	tDiveTurned,		"Dv.turned"				; dive is turned      (max. 9 char)	## pending translation
	TCODE	tCaveMode,			"Cave Mode"				; cave mode activated (max. 9 char)
	TCODE	tCaveModeShutdown,	"X-Cave-X"				; cave mode shut down (max. 9 char)
 ENDIF


; Divemode menu
	TCODE	tDivePreMenu,		"Menu?"					; Menu?   (max. 5 chars)
 IFDEF _compass
	TCODE	tSetHeading,		"Salva"					; Bearing (max. 6 chars)
 ENDIF


; Simulator menu
	TCODE	tQuitSim,			"Esci"					; Quit Simulation (max. 6 chars)
	TCODE	tResetAvg,			"AzzMed"				; Reset Timer     (max. 6 chars)


; Logbook
	TCODE	tCNS2,				"CNS:"
	TCODE	tAVG,				"Media:"
	TCODE	tGF,				"GF:"
	TCODE	tSAT,				"Sat:"					; 4 chars max


; Logbook units
	TCODE	tLogTunitC,			"°C"
	TCODE	tLogTunitF,			"°F"
	TCODE	tKGL,				"kg/l"
	TCODE	tMBAR,				"hPa"


; Logbook menu
	TCODE	tNextLog,			"Pagina Seguente"


; Reset menu
	TCODE	tReboot,			"Riavvio"				; Reboot
	TCODE	tResetMenu2,		"Sei sicuro?"			; Are you sure?
	TCODE	tAbort,				"Annulla"				; Abort
	TCODE	tResetSettings,		"Azzera Settings"		; Reset all				## pending translation
	TCODE	tResetDeco,			"Azzera Deco"			; Reset Deco
	TCODE	tResetBattery,		"Azzera Batteria"		; Reset Battery
	TCODE	tResetLogbook,		"Azzera Logbook"		; Reset Logbook


; Set Time Menu/Set Date Menu
	TCODE	tSetHours,			"Imposta Ora"			; Set Hours
	TCODE	tSetMinutes,		"Imposta Minuti"		; Set Minutes
	TCODE	tSetSeconds,		"Azzera Secondi"		; Clear seconds
	TCODE	tSetDay,			"Imp Giorno"			; Set Day
	TCODE	tSetMonth,			"Imp Mese"				; Set Month
	TCODE	tSetYear,			"Imp Anno"				; Set Year


; Logbook Offset Menu
	TCODE	tLogOffset,			"Devia Logbook"			; Logbook offset
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
	TCODE	tColorScheme,		"Schema colori"			; Colour scheme
	TCODE	tColorSetDive,		"Immersione:"			; Divemode:
	TCODE	tColorSetName0,		"Standard"				; Standard
	TCODE	tColorSetName1,		"Rosso"					; Red
	TCODE	tColorSetName2,		"Verde"					; Green
	TCODE	tColorSetName3,		"Blu"					; Blue


	; pSCR Menu and Settings
 IFDEF _ccr_pscr
	TCODE	tPSCRMenu,			"Menu pSCR"				; pSCR Menu
	TCODE	tPSCR_O2_drop,		"O2 Drop    "			; O2 drop
	TCODE	tPSCR_lungratio,	"Lung Ratio "			; lung ratio
	TCODE	tBackToLoop,		"goto loop"				; back to loop (10 chars max)
 ENDIF


; Language selection
 IF _language_2!=none
	TCODE	tLanguage,			"Lingua: "				; used in menu_tree
 ENDIF

 IF _language_1==en
	TCODE	tLang1,				"Inglese"				; tLang1 is 1st language, enum context
 ELSE
 IF _language_1==de
	TCODE	tLang1,				"Tedesco"
 ELSE
 IF _language_1==fr
	TCODE	tLang1,				"Francese"
 ELSE
 IF _language_1==it
	TCODE	tLang1,				"Italiano"
 ELSE
	TCODE	tLang1,				""						; dummy target for options table
 ENDIF
 ENDIF
 ENDIF
 ENDIF

 IF _language_2==en
	TCODE	tLang2,				"Inglese"				; tLang2 is 2nd language, enum context
 ELSE
 IF _language_2==de
	TCODE	tLang2,				"Tedesco"
 ELSE
 IF _language_2==fr
	TCODE	tLang2,				"Francese"
 ELSE
 IF _language_2==it
	TCODE	tLang2,				"Italiano"
 ENDIF
 ENDIF
 ENDIF
 ENDIF
