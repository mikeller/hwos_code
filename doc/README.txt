README zu OSTC hwos V2.93 (Neuerungen gegenüber der V2.92x)
===========================================================

- Tritt während der Berechnungen im Deko-Kalkulator eine IBCD auf, so wird dies anschließend
  auf der Ergebnisseite angezeigt.

- Die Berechnungen des Deko-Kalkulators können mit der linken Taste abgebrochen werden.

- Wenn der GF von einem der schnellen Gewebe 1-5 während des Tauchgangs 90% für Gewebe 1, 92%
  für Gewebe 2, ... , oder 98% für Gewebe 5 beträgt oder übersteigt, sowie 100% für alle anderen
  Gewebe, dann wird eine Mikroblasen-Warnung in rot ausgegeben. Die Warnung bleibt, einmal
  ausgelöst, in gelb bis zum Ende des Tauchgangs und weiter im Surface Mode stehen bis die
  Entsättigungszeit um ist.

- Wenn der GF von einem der schnellen Gewebe 1-6 während des Tauchgangs 100% beträgt oder übersteigt,
  sowie 102% für Gewebe 7, 104% für Gewebe 8, ..., oder 120% für Gewebe 16, dann wird in rot eine
  Warnung ausgegeben dass das ZH-L16-Modell verlassen wurde. Die Warnung bleibt in gelb bis zum Ende
  des Tauchgangs stehen.

- Der Code der übrigen Warnungen aus der V2.92 wurde überarbeitet.

- Der Zustand der Warnungen wird bei einer Tauchgangs-Simulation und Deko-Berechnung mit in den
  Vault gesichert und von dort anschießend wieder hergestellt.

- Die Berechnung der No-Fly-Zeit wurde überarbeitet, sie wird wie die Entsättigungs-Zeit dem
  Luftdruck nachgeführt, der im Oberflächen-Modus angezeigt wird. 


README zu OSTC hwos V2.92b (Neuerungen gegenüber der V2.91)
==========================================================

- Die neue Voting-Logic (Sensor-Werte-Mittelung) und die Generierung der Abweichungs-Warnung sind
  gegenüber der V2.91 leicht modifiziert und jetzt auch für den Betrieb mit 2 und 3 Sensoren getestet.

- Die No-Fly-Time Berechnung ist jetzt zum einen effizienter programmiert und orientiert sich zum
  anderen nicht mehr an der Regel "60% der Entsättigungszeit" sondern berechnet gemäß den Bühlmann-
  Faktoren jetzt die Zeit bis die Gewebe einen Umgebungsdruck von 0,6 bar (No-Fly-Modus) vertragen.
  Diesen Wert hat Bühlmann seinen No-Fly-Berechnungen zugrunde gelegt, die Bühlmann-Faktoren a und b
  gelten auch bei diesen Umgebungsdrücken. Zusätzlich wird bei aktiviertem GF-Modus der eingestellte
  GF-high mit in die Berechnung einbezogen.
  
- Im Menu Settings lässt sich anstatt des No-Fly-Modus auch eine Berechnung für Berghöhen von 1000,
  2000 und 3000 Meter auswählen. Die Berechnug der Wartezeit erfolgt dann analog der No-Fly-Berechnung,
  nur mit anderen Druckwerten für die jeweiligen Höhen.
  
- Die Desat-Time wird nun wie die No-Fly-Time anhand des aktuellen Umgebungdsdrucks laufend neu
  berechnet. Das Ergebnis wird für beide Zeiten auf die nächsten vollen 10 Minuten aufgerundet,
  da die Zeiten nun nicht mehr in Minuten-Schritten herunterzählen sondern entsprechend des aktuellen
  Luftdrucks auch mehrere Minuten vor- und zurück springen können. Die 10-Minuten-Rundung verdeckt
  diese Sprünge ein wenig.
  
- Die Gewebeanzeige im Divemode ist jetzt eingefärbt: orange dargestellte Gewebe sind aktuell am
  aufsättigen, die in cyan dargestellten im Gleichgewicht oder am absättigen.
  
- Es wird gemäß dem Ansatz von Burton geprüft, ob in den Geweben eine isobare Gegendiffusion (IBCD)
  auftritt. Falls dies im aktuellen Leitgewebe der Fall ist, wird eine Warnung angezeigt. Zusätzlich
  wird der aktuelle GF unterhalb der IBCD Warnung angezeigt, so dass mit einem Blick erkennbar ist
  ob dieser in Folge der IBCD tatsächlich am steigen ist oder ob sich die Gewebeübersättigung trotz
  IBCD in Summe abbaut.
  
- Der Code der Temperaturanzeige im Surface- und im Dive-Mode wurde zusammengefasst und behandelt nun
  Temperaturen von 0° sowie negative Temperaturen korrekt in beiden Einheiten (°C und °F).
  
- Es werden wieder 2 Sprachen unterstützt, aktuell sind die Sprachen-Dateien für Englisch und Deutsch
  für die V2.92 verfügbar. Die Anpassung von Spanisch und Französisch ist noch offen.
  
- Verschiedene kleine Optimierungen der Funktionen aus V2.91 sowie der Texte und Darstellungen zur
  Verbesserung der Lesbarkeit und Verständlichkeit.
  
- Speicherstatus: aktuell sind 2.574 Worte Programmspeicher frei.

- ACHTUNG: die "Testing"-Version der Firmware übernimmt zu Testzwecken die Gewebedaten aus dem  !!!!!
  !!!!     Simulator in den realen Oberflächen- und Tauchmodus!                                 !!!!!



README zu OSTC hwos V2.91


Was ist drin bzw. nicht mehr drin?:
===================================

- Die Diveloop ist refactored, d.h. Code-Größe, -Ablauf und -Wartbarkeit sind optimiert.

- Die Voting Logic für die Sensoren ist komplett neu. Eigentlich gibt es gar kein Voting mehr, alle
  aktiven Sensoren werden gemittelt. Wenn sie zu weit auseinander liegen, dann wird eine Warnung
  generiert und der Benutzer entscheidet (z.B. mittels Loop-Flush mit bekanntem Gas), welcher/welche
  Sensor(en) sinnvolle Werte liefern. Der Sensor bzw. die Sensoren die falsche Werte liefern können
  sodann über das Dive-Menu deaktiviert werden.

- Die "Deko-Engine" (p2_deco.c) ist komplett refactored. Sie kann jetzt zwei voneinander unabhängige Pläne
  rechnen. Als besonderen Clou kann sie CCR oder pSCR als Normalplan rechnen und dazu ein OC-Bailout, auf
  Wunsch sogar noch mit einem delayed ascent ("Schrecksekunde", Boje schießen, etc.)  als Alternativplan.
  UND mit Berechnung wie viel Gas das dann brauchen würde, praktisch verständlich angegeben in Bar!
  UND mit Vor- und Hauptwarnung wenn eine der benutzten Bailout-Flaschen an ihre  Kapazitätsgrenze
  kommt! Basis hierfür ist die Eingabemöglichkeit von Flaschengröße und Fülldruck. Die Vorwarnung
  kommt wenn der Gasbedarf 70% des Fülldrucks erreicht hat, die Hauptwarnung bei 100%.
  In einem neuen Custom-View kann der aktuelle Bailout-Gasbedarf (bzw. normale Deko-Gas-Bedarf beim
  OC-Tauchen) jederzeit angesehen werden. Aus Platzgründen können nur vier Gase angezeigt werden, die
  Warnungen werden aber auch für das fünfte Gas erzeugt, so denn alle fünf Gase die der Rechner prinzipiell
  verwalten kann auch tatsächlich alle im Einsatz sind. Wenn Bailout-Gase als "lost" gesetzt werden und/oder
  zwischen GF und aGF umgeschaltet wird, dann wird natürlich alles neu durchgerechnet...
 
- Die Dekopläne werden jetzt fast doppelt so schnell berechnet wie zuvor bzw. trotz Berechnung eines
  zweiten Planes dauert der Zyklus bis alle Daten jeweils aktualisiert sind nicht länger als vorher.
  Die Simulatorfunktionen +5 Minuten und Teile des Deko-Kalkulators sind jetzt deutlich schneller.
 
- Es werden nun die CNS% Werte berechnet, wie sie am Ende der Deko und am Ende der fTTS-/Bailout-Deko
  sein werden. Die Werte werden über einen Custom-View angezeigt. Erreicht einer der Werte 100% so
  wird eine Warnung angezeigt. Der CCR-Taucher kann so frühzeitig reagieren und seinen Setpoint anpassen,
  der pSCR-Taucher ggf. auf ein anderes Premix gehen und alle inkl. den OCs ggf. etwas flacher / kürzer tauchen
  um die CNS% herunter zu bekommen.
 
- Display-Ausgaben: wenn während des Tauchgangs Einstellungen geändert werden die Einfluss auf die
  Deko-Daten haben, wie z.B. Setpoint-Wechsel, GF/aGF-Umschaltung, Gaswechsel und lost Gas, dann
  werden die Deko-Daten im Display durch eine blaue Farbe als veraltet gekennzeichnet bis diese den
  geänderten Einstellungen entsprechend neu berechnet sind.
 
- Im Deko-Kalkulator (Simulator) kann nun eingestellt werden mit welchem Setpoint (1-5) er rechnen soll
  (CCR-Modus) sowie ob er mit den GF- oder den aGF-Faktoren rechnen soll (alle Modi). So können
  verschiedene Deko-Strategien und Notfall-Pläne schnell berechnet und verglichen werden. Die Stopps
  und die Gase werden nun eingefärbt, so dass sichtbar ist welches Gas den jeweiligen Stopps zugeordnet
  wurde (war ein Wunsch aus dem Forum).
 
- Da die Sättigungs-/Entsättigungs-Sicherheitsfaktoren seit der V2.26 auch im GF-Modell verwendet werden,
  ist ihre Einstellung nun in 5% statt wie zuvor 10% Schritten und damit feiner möglich.

- Die Ceiling-Tiefe erscheint jetzt in rot wenn die aktuelle Tiefe kleiner als die Ceiling-Tiefe ist.

- Es gibt nun eine vierte ppO2-Warnschwelle speziell für den CCR und pSCR Modus: minimaler ppO2 im Loop.
  Diese ppO2-Min-Loop Warnschwelle wird beim Atmen aus dem Loop anstelle des "normalen" ppO2-Min benutzt
  und kann entsprechend auf höhere ppO2 Werte als Alarmschwelle eingestellt werden.

- Ebenfalls speziell für den pSCR und CCR Modus gibt es nun eine Limitierung des ppO2 im Loop basierend
  auf der aktuellen Tiefe. In z.B. 3 Meter Tiefe sind 1,3 bar ppO2 nie erreichbar, auch wenn der Loop noch
  so viel gespült wird: erstens bleiben immer Reste von Inertgasen im Loop hängen und zweitens werden auf
  der Deko laufend Inertgase abgeatment, die sich im Loop wiederum ansammeln.
  Die Limitierung greift auch, wenn der Sensor-Modus aktiv ist, d.h. auch wenn die Sensoren auf 3 Meter
  Tiefe 1,3 bar zeigen würden und ein Limit von z.B. 90% O2 eingestellt ist, dann wird intern trotzdem
  nur mit 90/100 * 1,3 = 1,17 bar ppO2 gerechnet.
  (Diese Funktion wurde auf Anregung aus dem Forum implementiert)
 
- pSCRs werden jetzt in allen Funktionen inkl. des Simulators und der Deko-Berechnung (Stopps, CNS%) korrekt
  bezüglich des tiefen-abhängigen ppO2-Drops behandelt.

- Der pSCR Modus ist jetzt auch in Verbindung mit Sensoren benutzbar. Im Falle eines Fallbacks (wenn alle
  Sensoren ausgefallen oder manuell deaktiviert sind) schaltet die Deko-Rechnung vom Sensor-ppO2 auf die
  ppO2-Drop-Rechnung zurück.
              
- Die graphischen Gewebeanzeigen sind von Halbwertszeiten auf absolute Gewebe-Drücke umgestellt und sehen
  nun (hoffentlich) realistischer aus. Die N2-Balken beginnen bei "Null" und zeigen im entsättigten Zustand
  (nach einer langen Oberflächenpause) die 0,79 bar ppN2 der Atmosphäre an. Wird in der Deko auf 6 Meter
  reiner Sauerstoff geatmet, dann werden die Balken der schnellen Gewebe kürzer als 0,79 bar ppN2.
  Da in der Atmosphäre kein nennenswerter Anteil von Helium vorhanden ist, ist die Null-Schwelle der
  He-Balken so versetzt dass sie im entsättigten Zustand auf gleicher Höhe liegen wie die N2-Balken.
  Die He-Balken haben auch dabei im komplett entsättigten Zustand eine (künstliche) Mindest-Länge, die nur
  dafür da ist um ihren Nullpunkt und ihr generelles Vorhandensein sehen zu können.

- In der Oberflächenmodus-Gewebe-Grafik wird jetzt auch der aktuelle CNS-Wert angezeigt.

- Auf der ersten Logbuchseite (Grafik) wird jetzt der Tauchgangs-Modus (OC, CC, ...) angezeigt. Weiterhin
  sind die Funktionen des linken und des rechten Tasters vertauscht, so dass nun der rechte Taster den
  Tauchgang auswählt und dann weiter durch die einzelnen Seiten des Tauchgangs blättert, während der linke
  zur Tauchgangsliste zurück springt und die nächsten Tauchgänge wählt. Diese Zuordnung ist bedienfreundlicher
  und entspricht der Funktion der Tastenbelegung im Deko-Kalkulator.

- Im Oberflächenmodus ist die USB Kommunikation jetzt nicht mehr möglich, dafür wird nun der Ladefortschritt
  sichtbar. Um USB-Kommunikation zu betreiben muss in den Menu-Modus gewechselt werden.
  -> Diese Änderung ist vielleicht nicht (oder zumindest nicht ohne deutlichen Hinweis auf die Änderung)
     zum allgemeinen Rollout geeignet, schöner wäre eine Lösung mit einem Timeout...
	 
- Der Tauchmodus-Custom-View mit den Sensor-mV-Werten ist entfernt. Einerseits um Speicherplatz zu sparen,
  andererseits werden die milliVolt-Werte unter Wasser nicht wirklich benötigt da die ppO2-Anzeige bereits
  alle Fehlerzustände durch entsprechende Farben kennzeichnet. Allerdings fehlt damit zur Zeit die Anzeige
  der HUD-Batteriespannung. Die muss noch irgend wo anders wieder ihren Platz finden (so es denn HUD-Benutzer
  gibt die diese Anzeige haben möchten).

- Ebenso ist der Tauchmodus-Custom-View mit der "Dynamic gaslist" und die dazugehörige Routine TFT_dyn_gaslist
  entfernt worden um Speicherplatz zu sparen. Die Gase sind weiterhin über das im Tauchmodus-Menu sichtbar.
  
- Aus Gründen des knapp werdenden Speicherplatzes wird nur noch eine Sprache untersützt, derzeit ist dies
  Englisch. Ein Wechsel der Sprache ist nur durch Laden einer entsprechenden anders-sprachlichen Firmware
  möglich.
  
  

Teststatus:
===========

- Code-Review ist durchgeführt.

- Vergleichsläufe mit der V2.26 sind begonnen, hauptsächlich im CCR-Modus. Es müssen noch mehr Tests
  durchgeführt werden, insbesondere im OC und pSCR-Modus.

- Die neue Voting-Logic (Sensor-Werte-Mittelung) und die Generierung der Abweichungs-Warnung sind noch nicht
  getestet.


Open Items:
===========

- Derzeit wird die HUD-Batteriespannung nirgendwo (mehr) angezeigt.

_______________
30.10.2017 / rl

 

  
	