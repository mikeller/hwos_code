
Doku- & Info-Sammlung zu p2_deco.c und der Einbettung in die V2.95a
===================================================================

Bedeutung der Bildschirm-Farben (in der Normaleinstellung):

grün: feste Kolumnen oder "gute" Zustände.
weiß: Zahlenwerte die im Normalbereich liegen
blau: inaktive Einstellungen und Gase, sowie Werte die noch nicht
      berechnet wurden oder die aufgrund von Einstellungsänderungen
	  (Gaswechsel, LostGas, Setpoint-Wechsel, GF/aGF-Umschaltung, usw.)
	  nicht mehr aktuell sind und gerade neu berechnet werden.
gelb: Hinweise und Vorwarnungen die zu beachten sind, jedoch noch
      kein unmittelbares Handeln erfordern.
rot : Hinweise und Warnungen, die ein unmittelbaren Handeln erfordern.

Die Schwellen für Vorwarnungen sind generell immer auf 70% eingestellt,
für den aktuellen GF-Wert wird die GF-high Einstellung als Schwelle für
die Vorwarnung benutzt.
Vorwarnungen erscheinen als Warnungstext und/oder als Darstellung in
gelber Farbe. Die endgültige Warnung erscheint dann in roter Farbe.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Die Deco-Engine wird über zwei Parameter kommandiert:

	char_O_main_status:
	steuert die Berechnung für die realen Gewebe

	char_O_deco_status:
	steuert die Berechnung der Deko/Aufstiegssimulation
	
Die Kommandos werden über Flags gegeben. Für beide Kommandoparameter
definert sind:

	DECO_MODE_LOOP:
	Wenn gesetzt wird für Kreislaufsysteme gerechnet wenn nicht gesetzt
	wird in OC gerechnet.

	DECO_MODE_PSCR:
	nur in Verbindung mit DECO_MODE_LOOP, schaltet von CCR auf pSCR um.

Nur für char_O_deco_status definiert sind:

	DECO_PLAN_ALTERNATE:
	Auswahl ob der Normalplan oder ein alternativer Plan gerechnet
	werden soll. Von den Ergebnissen des Normal-Plans leiten sich die
	meisten Bildschirmanzeigen ab. Vom alternativen Plan werden nur
	ausgewählte Daten angezeigt, z.B. die der fTTS oder Bailout-
	Berechnung.

	DECO_CNS_CALCULATE:
	Wenn aktiviert, wird der CNS%-Wert berechnet wie er am Ende des
	Tauchgangs sein wird. Dies kann sowohl im Rahmen des normalen wie
	auch des alternativen Plans geschehen, es existieren für beide
	Pläne eigene Ausgabevariablen.

	DECO_VOLUME_CALCULATE:
	Wenn aktiviert, werden die Gasbedarfe für den gesamten Tauchgang
	berechnet. Dies kann sowohl im Rahmen des normalen wie auch des
	alternativen Plans geschehen, jedoch existiert für diese Funktion
	nur ein gemeinsamer Satz Ausgabevariablen. Wenn DECO_MODE_LOOP
	gesetzt ist erfolgen keine Berechnungen, es werden stattdessen
	Nullwerte ausgegeben.

	DECO_ASCENT_DELAYED:
	Wenn aktiviert wird der Aufstieg / dier Dekompression so berechnet
	als ob der Aufstieg nicht sofort, sondern um char_I_extra_time
	verzögert beginnt. Die Funktion kann in beiden Plänen verwendet
	werden, wird jedoch sinnvoller Weise in Verbindung mit dem
	alternativen Plan für fTTS bzw. Bailout-Berechnungen mit delayed
	ascent benutzt.

Die Deco-Engine generiert Warnungen, die in Form von Flags über die
Variable char_O_deco_warnings ausgegeben werden:

	DECO_WARNING_IBCD:
	Wird gesetzt wenn das führende Gewebe im Zustand der isobaren
	Gegendiffusion ist und derzeit netto tatsächlich am aufsättigen
	ist. Auf dem Bildschirm wird unter der IBCD-Warnung zusätzlich
	der aktuelle GF angezeigt, der bei Vorliegen dieser Warnung am
	steigen ist.

	DECO_WARNING_IBCD_lock:
	In diesem Flag wird das Auftreten einer IBCD-Warnung bis über
	das Tauchgangsende hinaus gespeichert. Wird im Deko-Kalkulator
	benutzt um eine IBCD-Warnung zu geben falls eine solche irgend
	wann im Verlaufe der Tauchgangs-Berechnung ausgetreten ist.

	DECO_WARNING_MBUBBLES:
	Wird gesetzt, wenn die Gewebe aktuell soweit übersättigt sind
	dass mit der Produktion von Mikroblasen gerechnet werden muss.
	Achtung: wenn dieses Flag zurückgesetzt wird sind nicht etwa
	die Mikroblasen nicht mehr da, es liegen nur vermutlich nicht
	mehr die Bedingungen für eine Produktion weiterer Mikroblasen
	vor. Der Zustand der aktiven Mikroblasengeneration wird über
	eine Mikroblasen-Warnung in Rot dargestellt.

	DECO_WARNING_MBUBBLES_lock:
	Wird gesetzt sowie erstmalig während eines Tauchgangs die
	Mikroblasen-Warnung gegeben wurde. Bleibt über das Ende des
	Tauchgangs hinaus gesetzt bis die Oberflächen-Berechnungen eine
	Entsättigung der Gewebe melden. Solange diese Warnung aktiv ist
	wird eine Mikroblasen-Warnung in Gelb ausgegeben, sowohl im Tauch-
	wie auch im Oberflächen-Modus.

	DECO_WARNING_OUTSIDE:
	Wird gesetzt, wenn die Gewebe aktuell soweit übersättigt sind, dass
	der Gültigkeitsbereich des ZHL-16 Modells verlassen ist.
	Achtung: wenn dieses Flag zurückgesetzt wird ist nicht etwa der
	Gültigkeitsbereich des Modells wiederhergestellt, es wird lediglich
	weiter gerechnet als ob das Modell noch gelten würde. Inwieweit die
	berechneten Werte (Deko-Plan, Ceiling, ...) dann tatsächlich noch
	praktische Relevanz haben ist unbekannt und extrem von den
	Rahmenbedingungen des Einzelfalls abhängig.
	Solange die Gewebesättigungen außerhalb des Modellbereichs sind
	wird eine Warnung in Rot ausgegeben.

	DECO_WARNING_OUTSIDE_lock:
	Wird zusammen mit DECO_WARNING_OUTSIDE gesetzt und wie bei den
	Mikroblasen erst bei Entsättigung wieder gelöscht.

	DECO_WARNING_STOPTABLE_OVERFLOW:
	Diese Warnung zeigt an, dass der Tauchgang mehr Stopps erfordert
	als in der Stopp-Tabelle gespeichert werden können. Abgeleitete
	Werte wie die Aufstiegszeit, die CNS-Werte am Tauchgangsende und
	die Gasbedarfe können nicht mehr vollständig ermittelt werden und
	werden daher in der Farbe Blau für ungültige Werte dargestellt. Die
	wahren Werte sind mindestens so hoch wie die derart angezeigten.
	Die Angaben zu den ersten Stopps auf dem Bildschirm und in den
	Custom-Views sind jedoch trotzdem korrekt und im weiteren Verlaufe
	des Tauchgangs, wenn die ersten Stopps vorüber sind, wird die
	Tabelle wieder ausreichen um alle restlichen Stopp-Daten zu
	speichern und die Warnung wird zurückgenommen.
	Diese Warnung wird nicht direkt angezeigt, sondern nur indirekt
	über die ungültig-Kennzeichnung der betroffenen Werte und sollte
	bei praktisch durchführbaren Tauchgängen nicht auftreten.

	DECO_FLAG:
	Dieses Flag wird gesetzt, wenn mindestens ein Gewebe am absättigen
	ist. Mit ihm wird die Warnschwelle für zu hohe ppO2-Werte von der
	normalen Schwelle auf die Deko-Schwelle umgeschaltet. Sollte wieder
	tiefer getaucht werden (Jo-Jo) so dass alle Gewebe wieder am
	aufsättigen sind, dann wird das Flag zurückgenommen und auch die
	Warnschwelle wieder zurückgeschaltet.


Viele der internen Routinen der Deko-Engine sind generisch ausgelegt und
können sowohl für Berechnungen zu den realen Geweben benutzt werden, als
auch für die Berechnungen im Rahmen des normalen und des alternativen
Aufstiegs-/Dekompressionsplans. Gesteuert wird dies intern über die
Variable tissue_increment, diese besteht aus einem Flag auf der höchsten
Bitposition und einer Interger-Zahl in den Bitstellen darunter
(Wertebereich 0 - 127). Ist das Flag (Bit 7) gesetzt, so werden die
Berechnungen auf die realen Gewebedaten angewendet, andernfalls auf die
von den Plänen simulierten. Mit der Integerzahl wird die Zeitdauer
bestimmt, für die die Berechnung durchgeführt werden soll. Null bedeutet
eine Zeitdauer von 2 Sekunden, die Zahlen von 1 bis 127 stehen für 1 bis
127 volle Minuten. Durch dieses Vorgehen konnten viele Programmabschnitte
deutlich beschleunigt werden.

Die Deko-Engine wird jede Sekunde aufgerufen und aktualisiert die obigen
sowie weitere Warnungen jede Sekunde bzw. wenn die entsprechenden
Berechnungen durchgeführt wurden. Die Berechnungen für die realen Gewebe
werden jede zweite Sekunde durchgeführt, sekündlich abwechselnd zwischen
der Aktualisierung der Gewebedrücke und des CNS%-Wertes.
Die Aufstiegs- und Dekompressions-Berechnungen werden bei jedem Aufruf
bearbeitet, also in jeder Sekundescheibe. Es wird abwechselnd der Normal-
und der Alternativ-Plan berechnet.
Werden für die Aufstiegsberechnung wesentliche Parameter geändert, wie
z.B. das geatmete oder die verfügbaren Gase, der Setpoint, die GF-
Faktoren, usw., dann wird die laufende Berechnung abgebrochen und im
nächsten Sekunden-Zyklus mit dem nächsten Normalplan begonnen.

Die Daten zu den Gasen werden von der Assembler-Seite aus über folgende
Funktionen gesetzt:

	Für die Berechnung der realen Gewebe:

		setup_gas_registers:
		setzt ein OC-Gas und schaltet den Rechenmodus auf OC

		setup_dil_registers:
		setzt ein Diluent und schaltet auf CCR bzw. pSCR Modus

	Für die Aufstiegs-/Dekoplanung:

		deco_setup_oc_gases:
		übermittelt die Daten OC-Gase sowie das aktuell geatmete
		Gas und	schaltet den Rechnenmodus auf OC

		deco_setup_cc_diluents:
		übermittelt die Daten der Diluent sowie das aktuell benutzte
		Diluent und schaltet auf den CCR bzw. pSCR Modus

Die Aufstiegs-/Dekoplanung wird über einen Enum in char_O_deco_status
gesteuert:

- Einmalig am Beginn des Tauchgangs wird der Zustand DECO_STATUS_INIT
  aufgerufen, dieser initialisiert die Deco-Engine. Nach Abschluss der
  Initialisierung wechselt die Deco-Engine selbsttätig in den Zustand
  DECO_STATUS_START weiter.

- DECO_STATUS_START
  startet eine neue Aufstiegs-/Dekoplanung basierend auf den gesetzten
  Flags und Gasdaten, falls noch eine Aufstiegs- oder Dekoplanung läuft
  wird diese abgebrochen. In diesem Zustand wird auch berechnet ob sich
  der Tauchgang noch innerhalb der Nullzeit befindet. Falls ja, endet die
  Aufstiegsplanung hier im Zustand ECO_STATUS_FINISHED, ansonsten wird
  sie beim nächsten Aufruf der Deco-Engine im Zustand DECO_STATUS_ASCENT
  fortgesetzt.

- DECO_STATUS_ASCENT
  führt die Berechnung des Aufstiegs bis zum ersten Deko-Stopp aus
  (initial ascent). Im alternativen Planungsmodus werden hierbei auch
  Gaswechsel ermittelt. Nach Abschluss der Aufstiegsberechnung wird der
  Zustand auf DECO_STATUS_STOPS weitergeschaltet, der dann beim wiederum
  nächsten Aufruf der Deco-Engine bearbeitet wird.

- DECO_STATUS_STOPS
  berechnet die Dekostopps und alle weiteren Aufstiege, sowie die CNS%-
  Werte am Tauchgangsende und die Gasbedarfe sofern jeweils angefordert.
  Diese Berechnungen laufen üblicherweise über mehrere Aufrufzyklen der
  Deco-Engine, diese signalisiert am Ende jedes Zykluses mit
  DECO_STATUS_STOPS dass (mindestens) ein weiterer Zyklus benötigt wird
  oder mit DECO_STATUS_FINISHED dass die Berechnungen abgeschlossen sind.

- DECO_STATUS_FINISHED
  signalisiert, dass die Aufstiegs-/Dekompressionsplanung abgeschlossen
  ist und die Ergebnisse in den entsprechenden Variablen bereitstehen
  bzw. aktualisiert sind.
  Die Kodierung von DECO_STATUS_FINISHED (benutzt als Ausgabe aus der
  Deco-Engine) entspricht der Kodierung von DECO_STATUS_START (benutzt
  als Eingabe in die Deco-Engine). Die Deco-Engine kann sofort wieder im
  Zustand DECO_STATUS_START aufgerufen werden, worauf ein neuer Planungs-
  zyklus beginnt.

Die Einstellungen und Gasdaten können zwischen zwei Planungszyklen (d.h.
zwischen den Zuständen DECO_STATUS_FINISHED und DECO_STATUS_START) ohne
Einschränkungen geändert werden. Während ein Planungszyklus läuft ist
dies nicht zulässig und kann zu falschen Ergebnissen führen.


Planungsfunktionen 2nd Deco Plan:

Über die Deko-Einstellungen, Untermenu "2nd Deco Plan" können erweiterte
sowie alternative Aufstiegs-/Dekompressionsberechnungen aktiviert werden.

	fTTS/Delay:

	Wird hier ein Wert größer Null ausgewählt, dann wird ein zweiter,
	alternativer Aufstiegs-/Dekoplan berechnet unter der Annahme, dass
	die eingestellte Zeit in Minuten weiterhin auf der aktuellen Tiefe
	verbracht wird und erst dann der Aufstieg beginnt. Die unter dieser
	Annahme berechnete Aufstiegszeit wird als fTTS (future Time to
	Surface) angezeigt. Weiterhin wird der CNS-Wert berechnet, der sich
	am Ende eines derart verlängerten Tauchgangs ergeben wird, er kann
	über einen	CustomView angesehen werden. Wenn dieser CNS-Wert 100%
	erreicht wird außerdem eine Warnung ausgegeben.

	Im Bailout-Fall wird keine fTTS-Berechnung durchgeführt, dafür
	Erfolgt die Aktualisierung der Bailout-Aufstiegsberechnung dann in
	Schnellerer 	Folge.	


	Calc.Gas(B/O):

	Wird diese Option aktiviert, dann wird der Gasbedarf berechnet, der
	für die Beendigung des Tauchgangs unter Einhaltung der Aufstiegs-
	geschwindigkeiten und ggf. Dekompressionsstopps benötigt wird. Wenn
	bei fTTS/Delay Null eingestellt ist, dann wird diese Berechnung
	während der normalen Aufstiegs-/Dekoberechnung durchgeführt und die
	ermittelten Werte gelten bei sofortigem Beginn des Aufstiegs. Wenn
	bei fTTS/Delay eine Zeit größer Null eingestellt ist, dann wird die
	Berechnung im Rahmen des zweiten, alternativen Plans durchgeführt
	Und die berechneten Gasbedarfe gelten für den verzögerten Aufstieg.


	fTTS/Delay und Calc.Gas(B/O) im Modus CCR und pSCR:

	Das oben beschriebene Verhalten verändert sich, wenn sich der OSTC
	im CCR oder im pSCR Modus befindet: Wenn die Option Calc.Gas(B/O)
	ausgeschaltet ist, dann gelten die berechnete Aufstiegszeit und der
	CNS-Wert unter der Annahme dass bis zum Ende des Tauchgangs	weiterhin
	vom Kreislaufgerät geatmet wird.
	Wenn die Option Calc-Gas(B/O) hingegen eingeschaltet ist, dann wird
	die Aufstiegszeit und der CNS-Wert unter der Annahme berechnet,
	dass ab sofort ein Bailout erfolgt, auf dem ersten Bailoutgas für
	die bei fTTS/Delay eingestellte Zeit auf der aktuellen Tiefe
	verblieben wird und dann ein Bailout-Aufstieg eingeleitet wird.
	Die sich so ergebende Aufstiegszeit wird als B/O-Zeit (BailOut)
	angezeigt und die berechneten Gasmengen gelten für die OC-Bailout-
	Gase.


	Bottom Gas, Deco Gas:

	Hier werden die Gasbedarfe in Litern pro Minute Oberflächenrate
	(SAC) eingestellt. Diese Einstellungen werden auch vom Deko-
	Kalkulator benutzt, der über das Simulations-Menu zu erreichen ist.


	Tank Sizes:

	Hier sind die Größen der Tanks für die OC-/Bailout-Gase in Litern
	(Wasservolumen) einzustellen. Diese Einstellungen sind wichtig, da
	sie für die Berechnung der Gasbedarfe im Tauchmodus benötigt
	werden: Im Tauchmodus erfolgt die Ausgabe der benötigten Gasmengen
	in Bar, bezogen auf die jeweiligen Flaschengrößen.


	Tank Press Budget: (ex Tank Fill Press)

	Hier wird festgelegt wie viel Gas aus den jeweiligen Tanks (Flaschen)
	für den Tauchgang verwendet werden darf. Die Einstellung erfolgt in
	Bar Flaschendruck. Erreicht der Bedarf eines Gases 70% des für das
	Gas eingestellten Budgets, dann erfolgt eine Warnung in gelber Farbe.
	Bei 100% erscheint die Warnung in roter Farbe.
	Die benötigten Flaschendrücke können jederzeit über einen CustomView
	eingesehen werden. Dieser zeigt aufgrund der begrenzten Bildschirm-
	fläche nur die Bedarfe von bis zu vier Gasen an, die Warnungen werden
	jedoch für alle 5 Gas erzeugt.
	Alle Gasbedarfs- und Druckberechnungen erfolgen unter der Annahme
	idealer Gase und ohne Betrachtung von temperaturbedingten Druck-
	änderungen.


Gaswechsel:

Im Rahmen der Deko-Pläne werden automatisch Gaswechsel eingeplant, wenn
ein besseres Gas verfügbar ist. Ein besseres, bzw. das beste Gas ist
dasjenige Gas, dessen Wechseltiefe am dichtesten unterhalb der aktuellen
Tiefe liegt. Nur aktivierte Gase die nicht als "Lost" markiert sind
werden berücksichtigt. Gaswechsel werden als Stopp in die Stopp-Tabelle
eingetragen. Die Dauer dieser Stopps beträgt standardmäßig 1 Minute.
Sollte auf der Stopp-Stufe für den Gaswechsel auch ein Dekompressions-
Stopp notwendig sein, so addiert sich die notwendige Stoppzeit für die
Dekompression zu der für den Gaswechsel hinzu.

Im Bereich zwischen der Grundtiefe und dem ersten Dekompressions-Stopp
werden die Gaswechsel-Stopps auf die Tiefen gelegt, ab denen jeweils
bessere Gase verfügbar werden. Gibt es ein besseres Gas auf der aktuellen
Tiefe, so wird ein Wechsel auf der aktuellen Tiefe geplant. Dies geschieht
jedoch nur im Modus alternativer Plan und nur wenn das nächste bessere
Gas nicht in <= 1 Minute Aufstiegszeit erreicht wird. In Normal-Plan
werden Wechsel auf ein besseres Gas erst ab dem ersten echten Deko-Stopp
eingeplant.
Im Falle, dass im alternativen Plan ein Bail-Out Szenario gerechnet wird
sieht die Gaswahl- und Gaswechsel-Strategie wie folgt aus: zunächst wird
dasjenige OC-Gas gewählt welches als 'First' konfiguriert ist. Auf diesem
wird auf aktueller Tiefe für die Zeit verblieben, die als Delayed-Acent-
Time eingestellt ist. Dann erfolgt die Suche nach einem besseren Gas, auf
das je nach Verfügbarkeit im direkten Anschluss oder während des
initialen Aufstiegs gewechselt wird. Ab Erreichen des ersten Dekostopps
werden Gaswechsel in beiden Plänen (normaler und alternativer Plan)
automatisch ermittelt und immer auf die nächsten passenden Dekostopps
gelegt. Im CCR und im pSCR Modus werden derzeit keine automatischen
Gaswechsel berechnet.

-> Die Gaswechselzeit ist bereits in der Options-Tabelle angelegt, wird
   aber momentan noch innerhalb von p2_deco.c auf 1 Minute erzwungen.

Die Deko-Engine plant den Aufstieg mit einer einstellbaren Aufstiegs-
geschwindigkeit von 5-10 Meter pro Minute, diese wird über eine Option in
der Options-Tabelle eingestellt.

-> Die Aufstiegsgeschwindigkeit ist bereits in der Options-Tabelle
   angelegt, wird aber momentan noch innerhalb von p2_deco.c auf 10 m/min
   erzwungen.

Für die Ceiling-Berechnung ist eine neue Codezeile angelegt die dafür
sorgt, dass die Ceiling genau dann zu Null wird, wenn auch die TTS zur
NDL umschaltet. Bisher wird so gerundet, dass die Ceiling zu Null wird
während noch eine TTS angezeigt wird. Die neue Zeile ist noch
auskommentiert und die alte Formel in Betrieb um eine Vergleichbarkeit
der gesamten Berechnungen mit der V2.27 zu ermöglichen. Zur Release-
Version sollte entsprechend umkommentiert werden.


Gasbedarfs-Berechnung:

Es werden die Bedarfe aller Gase berechnet, die bei der Aufstiegs-/
Dekompressionsberechnung eingeplant wurden. Es sind diese die Gase 1
bis 5. Wird aktuell ein manuell konfiguriertes Gas ("Gas 6") geatmet,
so wird dieses in der Gasbedarfsberechnung außen vor gelassen. Die
Berechnung teilt sich in die Bereiche bottom und initial ascent, stops
und intermediate ascents sowie final ascent.

Im Bereich bottom und initial ascent wird die Bottom-Verbrauchsrate
angesetzt, in den übrigen Bereichen die Deko-Verbrauchsrate.
Die Aufstiegssegmente werden mit der konfigurierten Aufstiegsrate (5-10
m/min) berechnet, der final ascent vom letzten Stopp bis zur Oberfläche
mit 1 Meter/Minute. Gibt es keine Stopps, dann reicht der initial ascent
vom Bottom bis zur Oberfläche und wird mit der konfigurierten Aufstiegs-
rate gerechnet, zuzüglich eines Sicherheitsstopps von 3 Minuten auf 5
Metern. Wenn es keinen Deko-Stopp gibt, aber einen Gaswechsel-Stopp der
tiefer liegt als ein letzter regulärer Deko-Stopp liegen würde, dann wird
der Aufstieg geteilt in einen intermediate ascent und einen final ascent.
Für beide werden dann die entsprechenden Aufstiegsraten angesetzt.

Alle Gaswechsel werden der Stopp-Tabelle entnommen, daher sind dort
auch reine Gaswechsel-Stopps eingetragen, d.h. Stopps auf denen keine
Dekompression notwendig ist. Auf den Stopps die einen Gaswechsel
beinhalten wird der Gasbedarf wie folgt berechnet: Der Bedarf für die
gesamte Stoppdauer wird dem neuen Gas zugerechnet, für die konfigurierte
Gaswechsel-Dauer wird ein entsprechender Bedarf zusätzlich auf das alte
Gas aufgeschlagen. So ist sichergestellt, dass die berechneten Gasvolumina
genügend Reserve ausweisen um auf einem Gaswechsel-Stopp die Zeit zu haben
das neue Gas verfügbar zu machen (Stage-Handling).

Die Gasbedarfe werden zum einen in Litern berechnet, diese Werte werden
vom Deko-Kalkulator genutzt, und zum anderen in bar Flaschendruck
entsprechend der eingestellten Flaschengrößen. Hierbei wird mit idealen
Gasen gerechnet, sprich Druck = benötigtes Volumen / Flaschengröße.
Aus dem Vergleich von berechnetem Druckbedarf und konfiguriertem
Flaschendruck werden die Vorwarnung (70%, gelb) und die Hauptwarnung
(100%, rot) generiert. Um bei der Hauptwarnung noch eine minimale Reserve
zu haben sollte daher der Flaschendruck etwas niedriger eingestellt
werden als er tatsächlich ist.


Gewebegrafik:

Die Gewebegrafik ist so skaliert, dass die Länge der Balken dem Druck des
Jeweiligen Inertgases entspricht. Während des Tauchgangs werden die
Balken zusätzlich eingefärbt, die Farbe kennzeichnet ob das Gewebe gerade
am aufsättigen oder am entsättigen ist. Die Balken für den Stickstoff
beginnen weiter links da die Gewebe im Ausgleichzustand an der Oberfläche
bereits zu einem Teil Stickstoff enthalten, nicht jedoch Helium. So
beginnen die "Überdrücke" aus dem Ausgleichszustand heraus auf gleicher
Linie.


Stopp-Tabelle (Deko-Tabelle):

Der Funktionsaufruf ist so verändert, dass beim Aufruf die Menge
der einzutragenden Minuten übergeben werden kann. Diese werden dann auf
den bestehenden Stopp aufaddiert bzw. es wird ein neuer Stopp angelegt.
Es können auch Null Minuten übergeben werden und so ein Stopp "on the
fly" erzeugt werden, z.B. für einen reinen Gaswechsel. Alle Operationen
auf der Stopp-Tabelle sind angepasst um mit Stopps von Null-Dauer zu
funktionieren.
Ein Stopp-Eintrag kann maximal 99 Minuten Stoppdauer aufnehmen. Dauert
ein Stopp länger, so wird eine weiterer Stopp auf gleicher Tiefe angelegt.


No-Fly bzw. Altitude-Wait-Zeit:

Diese Wartezeit wird wie eine Dekompression aus dem aktuellen Gewebe-
zustand heraus auf eine fiktive Tiefe gerechnet, die der gewählten
Höhenstufe entspricht. Für No-Fly wird dabei ein Kabinendruck von 0,6
bar angesetzt. Der Rechenaufwand für diese Berechnung wird die die
Verwendung eines iterativen Optimierungs-Algorithmus wesentlich
reduziert. Der aktuelle Umgebungsdruck wird laufend in die Berechnung
einbezogen, die sich ergebene Zeit auf volle 10 Minuten gerundet
ausgegeben.


Entsättigungszeit:

Die Entsättigungzeit ist so definert dass der Rest-Stickstoffdruck in
allen Geweben maximal 5% des Gewebedrucks aus natürlicher Sättigung
(Atmung von Luft unter aktuellem Umgebungsdruck) entspricht. Der sich
ergebene Druckwert wird dann ebenfalls für das Rest-Helium angesetzt.
Der aktuelle Umgebungsdruck wird laufend in die Berechnung einbezogen,
die sich ergebene Zeit auf volle 10 Minuten gerundet ausgegeben.


pSCR Modus:

Neben dem CCR-Modus wird nun auch der pSCR-Modus vollständig unterstützt,
inklusive optionalen Sensoren. Die Bedienung und die Menus sind weitest-
gehend identisch, nur dort wo im CCR-Modus zwischen den Setpoints und
Sensorbetrieb ausgewählt wird befindet sich im pSCR-Modus die Auswahl
zwischen Sensorbetrieb und berechneten ppO2-Werten.


Handling von Gas 6:

In der bisherigen Implementierung wurden Änderungen an den O2- und He-
Prozenten des Gases 6 sofort an die Berechnungen für die realen Gewebe
innerhalb von p2_deco.c übergeben, ohne dass dazu der dedizierte Menu-
Eintrag welcher die Zusammensetzung von Gas 6 anzeigt explizit ausgewählt
werden musste. Ebenso wurde das Gas6-Event ausgelöst sowie einer der
Prozentwerte verstellt wurde. In den Teil von p2_deco.c, der die Deko-
Berechnungen ausführt, wurden die Werte von Gas 6 jedoch erst übernommen,
wenn besagter Menu-Eintrag ausgewählt wurde, was in der Praxis zu
Diskrepanzen führen muss.

In der jetzigen Implementierung werden die O2- und He-Prozentwerte erst
dann übernommen und als Gas 6 aktiviert, wenn der Gas6-Menueintrag
explizit ausgewählt wird. Die Übernahme erfolgt sodann konsistent in die
Berechnung sowohl der realen Gewebe als auch in die Dekoberechnung, und
auch das Gas6-Event wird erst dann gesetzt.


Deko-Kalkulator:

Der Deko-Kalkulator benutzt die Gasverbrauchsraten, die im Deko-Menu,
Untermenu "2nd Deco Plan" eingestellt sind. Über das Menu "Calculator
Setup" kann eingestellt werden, welcher CCR Setpoint für die Berechnungen
benutzt werden soll (nur relevant im CCR Modus) und ob die normalen oder
die alternativen (aGF) GF-Faktoren für die Dekoberechnung benutzt werden
sollen (gilt für alle Modi). Der Deko-Kalkulator ermittelt die benötigten
Gasmengen in Litern (exakt: Barlitern).
Kommt es aufgrund der benutzen Gase und des Deko-Profils zu einer IBCD,
dann wird auf der Ergebnisseite eine entsprechende Warnung ausgegeben.
Erfordert die Dekompression mehr Stopps als im OSTC gespeichert werden
können, dann wird die Deko-Berechnung abgebrochen und eine "incomplete"
Warnung ausgegeben. Die angezeigte Aufstiegszeit, der CNS-Wert und die
ermittelten Gasbedarfe gelten nur bis zum Ende der angezeigten Stopps.
Achtung: Die tatsächlichen Werte bis zum Erreichen der Oberfläche können
unter Umständen deutlich größer sein als die angezeigten, da insbesondere
die letzten Stopps (die nicht mehr berücksichtigt werden konnten) typisch
am längsten dauern! Dieser Fall sollte jedoch bei Profilen praktisch
durchführbarer Tauchgängen nicht auftreten.


"DECO ZONE" and GF-"Ampel"

Sobald beim Aufstieg mindestens ein Gewebe beginnt abzusättigen erscheint
auf der Anzeige "DECO ZONE" in grüner Schrift. Ab diesem Zeitpunkt wird
auch die Warnschwelle für den ppO2 von der normalen Max-Schwelle auf die
Deco-Max-Schwelle umgestellt. Sollte wieder tiefer getaucht werden und
keines der Gewebe mehr absättigen, so verschwindet die Anzeige "DECO
ZONE" wieder und auch die ppO2 Warnschwelle wird wieder auf den normalen
Max-Wert zurück geschaltet.
Überschreitet während des Aufenthalts in der DECO ZONE der aktuelle GF-
Wert den eingestellten Wert für den GF-high, dann erscheint anstatt des
Textes "DECO ZONE" der aktuelle GF-Wert in gelber Farbe. Erreicht oder
überschreitet der aktuelle GF-Wert 100%, dann wird dieser in roter Farbe
angezeigt.


Allgemeines:

Der Quellcode von p2_deco.c ist in bezüglich Lesbarkeit und Kommentierung
überarbeitet, alle Variablen in p2_deco.c und shared_definitions.h sind
funktional gruppiert und ebenfalls vollständig kommentiert. In diversen
Assembler-Quellcode-Dateien wurde ebenfalls die Kommentierung verbessert.
