;=============================================================================
;
;	File text_german.asm							REFACTORED VERSIOn V2.99e
;
;	German texts translation file.
;
;	Copyright (c) 2011, JD Gascuel, HeinrichsWeikamp, all right reserved.
;=============================================================================

; Basic texts
	TCODE	tNo,				"Nein"					; 0 No
	TCODE	tYes,				"Ja"					; 1 Yes
 IFDEF _cave_mode
	TCODE	tCave,				"Höhle"					; 2 Höhle
 ENDIF

	TCODE	tblank,				" "						; (a single space character)

; Surface-mode texts
	TCODE	tMenu,				"<Menü"					; <Menu
	TCODE	tView,				"View>"					; View>
	TCODE	tHeading,			"Kurs:"					; Heading:
	TCODE	tLastDive,			"Letzter TG"			; Last Dive (Max 10 chars)
	TCODE	tSensorMilliVolt,	"Sensoren mV"			; Sensors mV

; Divemode Menu - 10 chars max!
	TCODE	tDivemenu_Gaslist,	"Gasliste"				; Gaslist (OC)
	TCODE	tDivemenu_Diluent,	"Diluents"				; Diluent (CCR)
	TCODE	tDivemenu_Premix,	"Premix"				; Premix  (pSCR)
	TCODE	tDivemenu_ResetAvg,	"Stoppuhr"				; Reset Avg.
	TCODE	tDivemenu_Avg_Mkr,	"Uhr/Marker"			; Reset Avg., Set Marker (and Turn Dive)
	TCODE	tDivemenu_Setpoint,	"Setpoint"				; Setpoint
	TCODE	tDivemenu_UseSensor,"akt.Sensor"			; Use Sensor
	TCODE	tDivemenu_ToggleGF,	"Toggle GF"				; Toggle GF
	TCODE	tDivemenu_Marker,	"Markierung"			; Set Marker
	TCODE	tDivemenu_LostGas,	"Gasverlust"			; Lost Gas
 IFDEF _cave_mode
	TCODE	tDivemenu_TurnDive,	"Rückweg"				; Turn Dive
 ENDIF

; Main menu
	TCODE	tNext,				"<Weiter"				; <Next
	TCODE	tEnter,				"Enter>"				; Enter>
	TCODE	tMainMenu,			"Hauptmenü"				; MainMenu
	TCODE	tLogbook,			"Logbuch"				; Logbook
	TCODE	tGasSetup,			"OC Gas Setup"			; OC Gas Setup
	TCODE	tSetTime,			"Zeit  stellen"			; Set Time
	TCODE	tSetDate,			"Datum stellen"			; Set Date
	TCODE	tSetTimeDate,		"Datum & Uhrzeit"		; Set Time & Date
	TCODE	tDispSets,			"Anzeige"				; Display Settings
	TCODE	tExit,				"Ende"					; Exit
	TCODE	tResetMenu,			"Reset Menü"			; Reset Menu
	TCODE	tDiveModeMenu,		"Deko Einstellung"		; Deco Mode
	TCODE	tInfoMenu,			"Informationen"			; Information
	TCODE	tTrSettings,		"Druckanzeige"			; Pressure Display
	TCODE	tTrMode,			"Modus: "				; Mode
	TCODE	tTr1stPres,			"1.Druck: "				; 1st Pressure
	TCODE	tTr2ndPres,			"2.Druck: "				; 2nd Pressure
	TCODE	tTrBailPres,		"1.B/O  : "				; Bailout Pressure
	TCODE	tTrMaxDeltaP,		"max Diff.: "			; independent double max diffenerce
	TCODE	tCCRSetup,			"CCR/pSCR Menü"			; CCR/pSCR Setup
	TCODE	tDiluentSetup,		"Diluent Menü"			; Diluent Setup
	TCODE	tFixedSetpoints,	"CCR Setpoints"			; Fixed Setpoints
	TCODE	tCCRSensor,			"Sensor"				; CCR/pSCR Sensor
	TCODE	tCalibrateMenu,		"Kalibrierung"			; Calibration
	TCODE	tCalibrationGas,	"Kal. Gas O2:"			; Cal. Gas O2:
	TCODE	tCalibrate,			"Kalibrieren"			; Calibrate
	TCODE	tBack,				"zurück"

; Gas menu
	TCODE	tGaslist,			"OC Gas Liste"
	TCODE	tGaslistCC,			"CC Gas Liste"			; CC Diluents
	TCODE	tGasEdit,			"Gas einstellen"
	TCODE	tType,				"Type: "
	TCODE	tGasDisabled,		"Deaktiviert"			; Disabled
	TCODE	tGasFirst,			"Start"					; First
	TCODE	tGasTravel,			"Reise"					; Travel
	TCODE	tGasDeco,			"Deko"					; Deco
	TCODE	tDilDisabled,		"Deaktiviert"			; Disabled
	TCODE	tDilFirst,			"Start"					; First
	TCODE	tDilNorm,			"Normal"				; Normal
	TCODE	tAir,				"Luft "					; Enum: values must follows (5 chars)
	TCODE	tO2,				"O2   "					; tAir + 5
	TCODE	tO2Plus,			"O2 +"
	TCODE	tO2Minus,			"O2 -"
	TCODE	tHePlus,			"He +"
	TCODE	tHeMinus,			"He -"
	TCODE	tMOD,				"MOD :"
	TCODE	tEAD,				"EAD:"
	TCODE	tSetup_GasDepth,	"Wechseltiefe"
	TCODE	tDepthPlus,			"Tiefe +"
	TCODE	tDepthMinus,		"Tiefe -"
	TCODE	tDepthReset,		"Reset auf MOD:"
	TCODE	tSetup_GasMix,		"Mix  Einstellen"
	TCODE	tCCRMode,			"Modus:"				; Mode:
	TCODE	tCCRModeFixedSP,	"fixeSP/Berech."		; Fixed SP
	TCODE	tCCRModeSensor,		"Sensor"				; Sensor
	TCODE	tCCRModeAutoSP,		"Auto SP"				; Auto SP
	TCODE	tSP,				"SP"					; SP (SetPoint)
	TCODE	tSPPlus,			"ppO2+"					; pO2+
	TCODE	tSensorFallback,	"Fallback:"				; Fallback:
	TCODE	tCalculated,		"berechnet"				; calculated
	TCODE	tppO2,				"ppO2:"					; ppO2:
	TCODE	tppO2O2,			"ppO2(O2)"				; ppO2(O2)
	TCODE	tppO2Dil,			"ppO2(Dil)"				; ppO2(Dil)
	TCODE	tppO2Mix,			"ppO2(Mix)"				; ppO2(Mix)

; New batteries menu
	TCODE	tNewBattTitle,		"Neue Batterie?"
	TCODE	tNewBattOld,		"behalte alte"
	TCODE	tNewBattNew36,		"Neue 3,6V Saft (T1)"
	TCODE	tNewBattNew15,		"Neue 1,5V AA   (T0)"
	TCODE	tNewBattAccu,		"3,6V AA Akku   (T2)"
	TCODE	tNew18650,			"Interne 18650  (T3)"
	TCODE	tNew16650,			"Interne 16650  (T4)"

; Gaslist management
	TCODE	tGas,				"Gas"					; Gas
	TCODE	tDil,				"Dil"					; Diluent
	TCODE	tGasErr,			"Err"					; Err (3 chars)

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
	TCODE	tDvMode,			"Betrieb : "
	TCODE	tDvOC,				"OC"
	TCODE	tDvCCR,				"CCR"
	TCODE	tDvGauge,			"Gauge"
	TCODE	tDvApnea,			"Apnoe"
	TCODE	tDvPSCR,			"pSCR"
	TCODE	tDvCC,				"CC"
	TCODE	tDkMode,			"Decotype: ZH-L16"
	TCODE	tZHL16,				" "						; keep order, enum from here...
	TCODE	tZHL16GF,			"+GF"					; ...up to here!
	TCODE	tPPO2Max,			"Max.     :"
	TCODE	tPPO2DECO,			"Max. Deko:"
	TCODE	tPPO2MIN,			"Min.     :"
	TCODE	tPPO2MINCC,			"Min. Loop:"
	TCODE	tLastDecostop,		"Letzt.Stop : "
	TCODE	tAscentSpeed,		"Auf.Geschw.: "			; Ascent Speed
	TCODE	tGasChangeTime,		"Gaswechsel :+"			; additional Gas Change Time
	TCODE	tDecoparameters,	"Deko Parameter"
	TCODE	tGF_low,			"GF  low :"
	TCODE	tGF_high,			"GF  high:"
	TCODE	tSaturationMult,	"Sättigung   : "
	TCODE	tDesaturationMult,	"Entsättigung: "
	TCODE	tFTTSMenu,			"fTTS/Verz.:"			; Future TTS
	TCODE	tLastDecostopSurf,	"Letzt.Stop:"			; last deco stop surface custom view
	TCODE	tGFMenu,			"GF Parameter"			; GF Settings
	TCODE	taGF_low,			"aGF low :"				; aGF low
	TCODE	taGF_high,			"aGF high:"				; aGF high
	TCODE	taGF_enable,		"aGF wählbar:"			; aGF Selectable
	TCODE	tDiveaGF_active,	"aGF aktiv"				; using aGF
	TCODE	tppO2settings,		"ppO2 Parameter"		; ppO2 Settings
	TCODE	tsafetystopmenu,	"Sicherheitsstop:"		; Safety Stop:
	TCODE	tGasUsage,			"Gasbedarf"				; Gas Usage
	TCODE	tSetBotUse,			"Reise Gas: "			; Bottom Gas: (space)
	TCODE	tSetDecoUse,		"Deko  Gas: "			; Deco	Gas: (space)
	TCODE	tCalcAscGas,		"Gasmenge(B/O):"
	TCODE	tSetup_Tank,		"Tank Einstellen"		; Setup Tank
	TCODE	tTankSize,			"Tank Größe"
	TCODE	tTankUsablePress,	"Umkehrdruck (Aufst)"	; Tank Pressure Budget for Ascent (turn pressure) (max 19 chars)
	TCODE	tCopyDilToOC,		"Kopiere Dil.-> OC"		; copy diluent settings to OC gas
	TCODE	tTankPairing,		"Sender wählen"			; select Transmitter
	TCODE	tLiter,				" l"
	TCODE	tLiterLong,			"Liter"
	TCODE	tCCmaxFracO2,		"Loop %O2 max.:"
	TCODE	t2ndDecoPlanMenu,	"2.Deko Plan"

 IFDEF _rx_functions
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
	TCODE	tTrPresDil1,		"Dil 1"					; Dil 1
	TCODE	tTrPresDil2,		"Dil 2"					; Dil 2
	TCODE	tTrPresDil3,		"Dil 3"					; Dil 3
	TCODE	tTrPresDil4,		"Dil 4"					; Dil 4
	TCODE	tTrPresDil5,		"Dil 5"					; Dil 5
	TCODE	tTrPresFirstGas,	"erstes Gas"			; first  Gas
	TCODE	tTrPresActiveGas,	"aktives Gas"			; active Gas
	TCODE	tTrPresFirstDil,	"erstes Dil"			; first  Dil
	TCODE	tTrPresActiveDil,	"aktives Dil"			; active Dil
 ELSE
 	TCODE	tTrModeOff,			""						; dummy target for entry in option table
	TCODE	tTrPresNone,		""						; dummy target for entry in option table
 ENDIF

; Display Settings
	TCODE	tBright,			"Helligkeit:"
	TCODE	tEco,				"Eco"
	TCODE	tMedium,			"Mittel"
	TCODE	tHigh,				"Hoch"
	TCODE	tDvSalinity,		"Salinität: "			; Salinity
	TCODE	tShowppO2,			"ständig zeigen:"		; Always show ppO2:
	TCODE	tFlip,				"Anzeige drehen:"		; Rotate Screen
	TCODE	tMODwarning,		"MOD  Warnung:"			; MOD warning
	TCODE	tIBCDwarning,		"IBCD Warnung:"			; IBCD Warning
	TCODE	t2ndDepth,			"2.Tiefe:"				; 2nd depth display content (10 chars max)
	TCODE	tTimeoutDive,		"TG-Ende nach:"			; Dive Timeout

; VSI display Settings
	TCODE	tVSItext2,			"Variable Geschw.:"		; Variable speed:
	TCODE	tVSIgraph,			"Geschw.  Grafik :"		; Speed graph:

; Setup Menu
	TCODE	tSystSets,			"Konfiguration"
	TCODE	tCompassMenu,		"Kompass-Kalibrierung"	; Compass calibration
	TCODE	tCompassGain,		"Empfindlichkeit:"		; Compass gain:
	TCODE	tCalX,				"Kal. X:"				; Cal X
	TCODE	tCalY,				"Kal. Y:"				; Cal Y
	TCODE	tCalZ,				"Kal. Z:"				; Cal Z
	TCODE	tUnits,				"Einheiten: "
	TCODE	tMetric,			" m/°C"					; Enum menu
	TCODE	tImperial,			"ft/°F"
	TCODE	tDefName,			"HW OSTC"
	TCODE	tButtonleft,		"Taster links :"		; Left button
	TCODE	tButtonright,		"Taster rechts:"		; Right button
	TCODE	tAltMode,			"Wartezeit:"
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
	TCODE	tPlan,				"Simulator"				; Simulator

; Decoplanner submenu
	TCODE	tBtTm,				"Grundzeit:"			; Bot. Time: (10 chars)
	TCODE	tBtTm_short,		"Zeit:"					; Bot. Time: (max. 6 chars)
	TCODE	tBtDep,				"Tiefe    :"			; Max Depth: (10 chars)
	TCODE	tIntvl,				"Intervall:"			; Interval : (10 chars)
	TCODE	tDecoSetup,			"Deko Parameter"
	TCODE	tDeco,				"Deko Berechnung"		; Calculate Deco
	TCODE	tDivePlan,			"Tauchplan:"			; Dive Plan:
	TCODE	tNoDeco,			"Keine Deko"			; No Deco
	TCODE	tMore,				"mehr"					; More
	TCODE	tSelectSetpoint,	"Setpoint   :"
	TCODE	tuseAGF,			"Benutze aGF:"
	TCODE	tCalculating,		"Berechnung läuft..."
	TCODE	tNDLleft,			"übrig"					; time left within NDL

; Information menu
	TCODE	tFirmware,			"Firmware: "			; Firmware: (space)
	TCODE	tFirmware_rx,		"RX Ver  : "			; RX Ver  : (space)
	TCODE	tSerial,			"Seriennr: "			; Serial  : (space)
	TCODE	tTotalDives,		"Anzahl TG: "			; Total Dives:
	TCODE	tBatteryV,			"Batterie: "			; Battery:
	TCODE	tUptime,			"Laufzeit: "			; Uptime:

; Divemode screen
	TCODE	tNDL,				" NZ"					; 3 chars max
	TCODE	tTTS,				"TTS"
	TCODE	tVelMetric,			"m/min"
	TCODE	tVelImperial,		"ft/m "
	TCODE	tGasSelect,			"Wähle Gas"				; Select Gas
	TCODE	tSelectAir,			"Luft"					; Air
	TCODE	tSelectO2,			"O2  "					; O2
	TCODE	tSelectNx,			"Nx"					; Nx
	TCODE	tSelectTx,			"Tx"					; Tx
	TCODE	tDepth,				"Tiefe"					; Depth
	TCODE	tMaxDepth,			"Max. Tiefe"			; Max. Depth    - max 10chars!
	TCODE	tAvgDepth,			"Durchschn."			; average Depth - max 10chars!
	TCODE	tDivetime,			"      Zeit"			; Divetime
	TCODE	tDiveHudMask1,		"Sensor 1"
	TCODE	tDiveHudMask2,		"Sensor 2"
	TCODE	tDiveHudMask3,		"Sensor 3"
	TCODE	tDiveTotalAvg,		"Durchschn.1"
	TCODE	tDiveStopwatch,		"Stoppuhr"
	TCODE	tDiveStopAvg,		"Durchschn.2"			; 11 chars max
	TCODE	tApnoeTotal,		" Total"				; Total (six chars, right aligned)
	TCODE	tApnoeMax,			"  Letzter TG"			; Last descend
	TCODE	tApnoeSurface,		"Oberflächenzeit"		; Surface Time
	TCODE	tTime,				"Uhrzeit"				; Time
	TCODE	tSurface,			"Oberfläche"			; Surface (max 12 chars)
	TCODE	tDiveDecoplan,		"Dekoplan"				; Decoplan
;	TCODE	tDiveClock,			"Uhr"					; Clock
	TCODE	tDiveEAD_END,		"EAD/END"				; EAD/END
	TCODE	tDiveTissues,		"Gewebe"				; Tissues
	TCODE	tEND,				"END:"					; END:
	TCODE	tHe,				"He"					; He
	TCODE	tN2,				"N2"					; N2
	TCODE	tDiveBailout,		"Bailout"				; Bailout
	TCODE	tGFactors,			"GF Werte"				; GF Values
	TCODE	taGFactors,			"aGF Werte"				; aGF Values
	TCODE	tGFInfo,			"GF jetzt"				; GF Info
	TCODE	tCeiling,			"Ceiling"				; Ceiling
	TCODE	tDiveSafetyStop,	"Stop"					; Stop (four chars, right aligned)
	TCODE	tDiveFallback,		"Fallback!"				; Fallback! (max. nine chars)
	TCODE	tDecoInfo,			"Deko Zone"				; Deco info
	TCODE	tSensorCheck,		"Sensor Test"			; Sensor Check
	TCODE	tdil,				"Dil:"					; Diluent ppO2 Warning
	TCODE	tmix,				"Mix:"					; Pre-Mix ppO2 Warning
	TCODE	tSensorDisagree,	"Sensoren!"				; Sensors disagree Warning
	TCODE	tGasNeedsWarn,		"Gasbedarf"
	TCODE	tGasNeedsAscent,	"Gas Bedarf Aufstieg"
	TCODE	tCNSsurf,			"ZNS Oberfl."
	TCODE	tCNSfTTS,			"ZNS fTTS"
	TCODE	tCNSBO,				"ZNS B/O"
	TCODE	tCNSnow,			"ZNS jetzt"
	TCODE	tCNSeod,			"ZNS Ende"
	TCODE	tIBCD,				"IBCD N2He"
	TCODE	tnoBOgas,			"-B/O-Gas-"
	TCODE	tMicroBubbles,		"M.Blasen"
	TCODE	tCNS,				"CNS: "
	TCODE	tgaschange,			"wechseln?"				; better gas found
	TCODE	tNeed,				"Bedf."					; gas need (5 chars)
	TCODE	tBattery,			"Batterie"				; Battery
 IFDEF _rx_functions
	TCODE	tTransmitter,		"TR Sender"				; pressure transmitter
	TCODE	tPressure,			"Fl.Druck"				; tank pressure
	TCODE	tSAC,				"AMV"					; SAC, must be 3 chars!
	TCODE	tswap,				"wechseln"				; switch tank (max. 9 chars)
 ENDIF
 IFDEF _cave_mode
	TCODE	tGasNeedsCaveMode,	"Gas Bedarf Höhlen-Modus"; title for gas needs custom view
	TCODE	tDiveTurned,		"Rückweg"				; dive is turned      (max. 9 char)
	TCODE	tCaveMode,			"Höhle"					; cave mode activated (max. 9 char)
	TCODE	tCaveModeShutdown,	"X-Höhle-X"				; cave mode shut down (max. 9 char)
 ENDIF


; Divemode menu
	TCODE	tDivePreMenu,		"Menü?"					; Menu?
	TCODE	tSetHeading,		"Kurs"					; set bearing (max. 6 chars)

; Simulator menu
	TCODE	tQuitSim,			"Ende"					; Quit Simulation

; Logbook
	TCODE	tCNS2,				"ZNS:"
	TCODE	tAVG,				"Mit:"
	TCODE	tGF,				"GF:"
	TCODE	tSAT,				"Sät:"

; Logbook units
	TCODE	tLogTunitC,			"°C"
	TCODE	tLogTunitF,			"°F"
	TCODE	tKGL,				"kg/l"
	TCODE	tMBAR,				"hPa"

; Logbook menu
	TCODE	tNextLog,			"Nächste Seite"

; Reset menu
	TCODE	tReboot,			"Neu starten"			; Reboot
	TCODE	tResetMenu2,		"Sind Sie sicher?"		; Are you sure?
	TCODE	tAbort,				"Abbrechen"				; Abort
	TCODE	tResetSettings,		"Reset Einstellungen"	; Reset Settings (max. 19 chars)
	TCODE	tResetDeco,			"Reset Deko"			; Reset Deco
	TCODE	tResetBattery,		"neue Batterie"			; Reset Battery
	TCODE	tResetLogbook,		"Logbuch löschen"		; Reset Logbook

; Set Time Menu/Set Date Menu
	TCODE	tSetHours,			"Stunden einst."		; Set Hours
	TCODE	tSetMinutes,		"Minuten einst."		; Set Minutes
	TCODE	tSetSeconds,		"Sekunden zurücks."		; Clear seconds
	TCODE	tSetDay,			"Setze Tag"				; Set Day
	TCODE	tSetMonth,			"Setze Monat"			; Set Month
	TCODE	tSetYear,			"Setze Jahr"			; Set Year

; Logbook Offset Menu
	TCODE	tLogOffset,			"Logbuch-Offset"		; Logbook offset
	TCODE	tLogOffsetp1,		"+1"					; +1
	TCODE	tLogOffsetp10,		"+10"					; +10
	TCODE	tLogOffsetm1,		"-1"					; -1
	TCODE	tLogOffsetm10,		"-10"					; -10

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
	TCODE	tColorScheme,		"Farbschema"			; Colour Scheme
	TCODE	tColorSetDive,		"Tauchmodus:"			; Divemode:
	TCODE	tColorSetName0,		"Standard"				; Standard
	TCODE	tColorSetName1,		"Rot"					; Red
	TCODE	tColorSetName2,		"Grün"					; Green
	TCODE	tColorSetName3,		"Blau"					; Blue

; pSCR Menu and Settings
	TCODE	tPSCRMenu,			"pSCR Menü"				; PSCR Menu
	TCODE	tPSCR_O2_drop,		"O2 Abfall  "			; O2 drop
	TCODE	tPSCR_lungratio,	"L.Verhält. "			; lung ratio
	TCODE	tBackToLoop,		"auf Loop"				; back to loop (10 chars max)	### new


; Language selection
 IF _language_2!=none
	TCODE	tLanguage,			"Sprache: "				; used in menu_tree
 ENDIF

 IF _language_1==en
	TCODE	tLang1,				"Englisch"				; tLang1 is 1st language, enum context
 ELSE
 IF _language_1==de
	TCODE	tLang1,				"Deutsch"
 ELSE
 IF _language_1==fr
	TCODE	tLang1,				"Französisch"
 ELSE
 IF _language_1==it
	TCODE	tLang1,				"Italienisch"
 ELSE
	TCODE	tLang1,				""						; dummy target for options table
 ENDIF
 ENDIF
 ENDIF
 ENDIF

 IF _language_2==en
	TCODE	tLang2,				"Englisch"				; tLang2 is 2nd language, enum context
 ELSE
 IF _language_2==de
	TCODE	tLang2,				"Deutsch"
 ELSE
 IF _language_2==fr
	TCODE	tLang2,				"Französisch"
 ELSE
 IF _language_2==it
	TCODE	tLang2,				"Italienisch"
 ENDIF
 ENDIF
 ENDIF
 ENDIF
