# Gegner (NPC-Restaurants / Rivalen)

> **Status:** Entwurf. Dieses Dokument spezifiziert die NPC-Konkurrenz-Restaurants
> („Rivalen“) je Stadtteil – Anzahl, Identität, Persönlichkeit und Handlungen. Es löst
> den in `12_Power_Projection.md` angekündigten Folgepunkt („Kapitel 13“) ein und baut
> auf `1_mehrere_Restaurants.md` (Standort/Stadtteil), `8_Echtzeit-Zeitsystem.md`
> (V8, Wochen-Tick/Catch-up) und `9_Personal.md` (V9, Persönlichkeitsmodell) auf.

## Ziel

Pro Stadtteil konkurrieren NPC-Restaurants (Rivalen) mit dem Restaurant des Spielers um
Platzierung und Kunden. Die Rivalen sind:

- **deterministisch** aus Stadtteil und Rivalen-ID ableitbar (idempotenter Catch-up, V8),
- denselben Regeln wie der Spieler unterworfen (**kein Schummeln**),
- **persönlich unterschiedlich** (Enneagramm-Persönlichkeiten, V9); der vorhandene
  `ObjectHost` (Singleton) übernimmt ihre Steuerung auch außerhalb des Gefechts.

## Abgrenzung: „Gegner“ vs. „Rivalen“

Im Code existieren bereits **Gefechts-Gegner** (`ObjectHost`, Token). Dieses Kapitel
behandelt **wirtschaftliche Rivalen** – NPC-Restaurants im selben Stadtteil. Dieses
Dokument spricht deshalb durchgehend von **Rivalen** (Datenmodell `RivalRestaurant`)
und reserviert „Gegner“ für die Gefechts-Gegner (löst damit `12_Power_Projection.md`
→ P3 auf).

## Anzahl

Die Anzahl der Rivalen hängt von der **Popularität des Stadtteils** ab (beliebte
Stadtteile ziehen mehr Wettbewerb an) – übernommen aus `12_Power_Projection.md`,
Abschnitt „Ranking“:

- Ableitung aus `EconomyBalance.districtPrestigeFor(district)` (Prestige-Tiers S–D,
  § 8 der `2-Wirtschaftsschleife.md`) über `rivalCountFromPrestige(double prestige)`.

**Vorschlag (offen zum Tuning – vieles ist noch undefiniert und in stetem Wechsel):**

| Prestige | Tier | Rivalen | Stadtteile (Beispiele) |
|---|---|---|---|
| ≥ 2.00 | S | 8 | TriBeCa |
| 1.60–1.99 | A | 6 | Upper East Side, SoHo, Upper West Side, West Village, Hudson Yards |
| 1.30–1.59 | B | 5 | Gramercy, Flatiron, Nomad, Chelsea, Financial District |
| 1.00–1.29 | C | 4 | Midtown, East Village, Theater District, Koreatown, Hell's Kitchen, Lower East Side |
| < 1.00 | D | 3 | Little Italy, Chinatown, Harlem |

Konstanten in `EconomyBalance` (V7: keine magischen Zahlen): Schwellen
`rivalCountPrestigeS/A/B/C` (2.00/1.60/1.30/1.00) sowie `rivalCountMin = 3` und
`rivalCountMax = 8`; die Ableitung liefert den Wert innerhalb dieser Grenzen.

**Dynamik im Spiel:** Beim Wochen-Tick (V8) wird die Rivalen-Liste **deterministisch**
angepasst – der Spieler nähert sich der Spitze ⇒ stärkere/weitere Rivalen rücken nach;
fällt er ans Ende ⇒ das Feld schrumpft (Rivalen melden „Pleite“ und scheiden aus);
ändert der Stadtteil sein Prestige, wird die Ziel-Anzahl nachgezogen. Ein-/Austritte
sind reine Funktionen von Stadtteil, Rivalen-IDs und Spieler-Snapshot – **kein Zufall**
im Catch-up (V8-Idempotenz).

## Rangliste

Pro Stadtteil gibt es genau eine Rangliste aller Restaurants (Spieler + Rivalen),
absteigend sortiert nach **Power Projection** (Ableitung: `PowerProjectionService`,
`12_Power_Projection.md` – PP ist Ausgang, nie Fuzzy-Eingang, 1-Tick-Verzögerung für
`competition`, P1). Das Ranking wird je Wochen-Tick neu berechnet und im
`WeeklyTickResult` mitgeliefert. UI: „Platz 3 von 7 in SoHo“ in `ScreenRestaurant`
(l10n, `12_Power_Projection.md` → „Integration“).

**Gegenwirkung an der Spitze (Entschieden):** Rivalen-Aggressivität skaliert zusätzlich
den **PP-Einkommensfaktor** des Spielers (`powerProjectionIncomeFactor`,
`12_Power_Projection.md` → „Effekte“). Vorschlag: `faktorEffektiv =
powerProjectionIncomeFactor(PP) × konkurrenzdruckFaktor`, wobei der Konkurrenzdruck aus
dem Ø der Rivalen-PPs relativ zur Spieler-PP folgt – dominiert der Spieler, sinkt sein
Faktor; liegt ein Rivale vorn, steigt er. Die exakte Formel ist offen (siehe „Offene
Fragen“ 5).

## Identität & Persönlichkeit

Jeder Rivale ist ein eigenständiger Zustand mit:

- `id`: stabil und deterministisch (CRC32 aus Stadtteil + Rivalen-Index),
- `name`: generiert (`random_name_generator`, wie beim Personal),
- `personalityId`: deterministisch aus der Rivalen-ID abgeleitet,
- einer **Fuzzy-Persönlichkeit** wie der Host (`HostPersonality`) auf Basis von
  `EnneagramProfile` (12 Profile) und `PersonalityTraits.forProfile(profileId, rivalId)`
  (V9).

**Schicht-Regel** (aus `9_Personal.md` → P6): Das Persönlichkeitsmodell lebt in
`lib/models/personality.dart` und wird vom Rivalen-Modell benutzt – nicht im Host
verortet. Der `ObjectHost` ist bereits ein Singleton
(`lib/objects/object_host.dart:180–184`); er **orchestriert** die Rivalen im Tick,
die Logik selbst liegt in einem reinen, testbaren Service (`RivalService`, analog
`PowerProjectionService`).

## Handlungen (Konzept)

Rivalen führen im Kern dieselben Handlungen aus wie der Spieler:

- Personal anheben/entlassen und aufwerten (V9/V10),
- Erweiterungen/Upgrades kaufen (`11b_Restauranterweiterungen.md`),
- in Attraktivität investieren (§ 8 der Wirtschaftsschleife),
- Truppen in die Gefechte des Spielers schicken (Entschieden, siehe
  „Gefechtsteilnahme“),
- bei Unterschreiten der Negativgrenze **Pleite** anmelden und ausscheiden,
- **Sabotageakte** gegen den Spieler oder andere Rivalen ausführen (siehe „Sabotage“).

**Steuerung (Fuzzy):** Wie bei `HostPersonality` trifft eine Fuzzy-Regelbasis die
Entscheidungen. Eingänge: eigener Finanzstand, Stadtteil-Attraktivität, Spieler-PP/Rang
(aus dem letzten Tick), Teamqualität. Ausgänge: Investitionsneigung, Aggressivität,
Expansionslust. Die Persönlichkeit gewichtet nur die **Präferenzen** – die zugrunde
liegenden Regeln sind für alle gleich.

**Fairness (kein Schummeln):**

- Rivalen zahlen dieselben Kosten/Gehälter und unterliegen demselben Budget-Limit
  (`EconomyBalance`, V7).
- Keine versteckten Boni; der Spieler bleibt **gefordert, aber nicht frustriert**.
- Dynamik über das **symmetrische Mini-PP-Modell** je Rivale (Entscheidungen → 1).

## Sabotage

Mit der Einführung der **Rivalen** soll die Möglichkeit gegeben werden, diese zu sabotieren – und umgekehrt.
Hier kommt das bisher ungenutzte Attribut **`shadiness`** (`9_Personal.md`, „Attribute“) ins Spiel:

- **Passiv** bedeutet `shadiness` die Fähigkeit eines Charakters, einen Sabotageversuch eines Rivalen zu **bemerken**.
- **Aktiv** bedeutet es die Fähigkeit des Charakters, diesen Sabotageversuch **erfolgreich durchzuführen**.

Wird ein Sabotageversuch bemerkt, hat das für das Restaurant, welches ihn gestartet hat, Konsequenzen: Es
könnte beispielsweise eine hohe Strafe zahlen, an Ansehen verlieren (je nach Popularität des Stadtteils) oder die
Kunden könnten nicht begeistert sein (ebenfalls je nach Popularität des Stadtteils) – und weitere Varianten. Die
exakte Strafe inklusive Konsequenzen ist dabei abhängig von der **Schwere der Tat**.

Sabotageakte werden **immer von einer Person ausgeführt** und über ein **Menü** ausgewählt. Es gibt folgende
Optionen:

- Vandalismus
- Rufmord (Social Media, News etc.)
- Abwerben von Mitarbeitern
- Stehlen von Mitarbeitern
- Sabotage (Erweiterungen gehen kaputt und müssen zeitaufwendig repariert werden)
- Aufhetzen der Steuerbehörde (inklusive vorher Beweise platzieren)
- Aufhetzen der Umweltbehörde (inklusive vorher Beweise platzieren)
- Aufhetzen des Gesundheitsamtes (inklusive vorher Beweise platzieren)
- weitere

> **Bezug zu `shadiness`:** Das Attribut ist in `9_Personal.md` (V9) bislang nur als **Datenmodell ohne Wirkung**
> geführt; die Sabotage-Mechanik ist der erste Anwendungsfall. Die Abrechnung der Konsequenzen läuft im
> **Wochen-Tick** (`8_Echtzeit-Zeitsystem.md`, V8); die Ansehen-/Kundenwirkung dockt an
> `2-Wirtschaftsschleife.md` § 8 an. Die Balance-Werte (Detektions-/Erfolgsschwellen je `shadiness`, Strafhöhen
> je Schwere) gehören nach V7 in `EconomyBalance`.

## Gefechtsteilnahme

**Entschieden:** Rivalen treten **im Gefecht des Spielers** auf, wenn dieser ins Gefecht
zieht. Jede Karte hat bereits mehrere Spieler-Spawns (`spawn_player1`–`spawn_player4`,
`doc/doc/06_map_loader.md`); ein anwesender Rivale besetzt einen davon.

- **Teilnehmerzahl:** **1 bis 4 Rivalen** je Gefecht, deterministisch aus dem Rivalen-
  Roster des Stadtteils gewählt. Die Obergrenze darf die Zahl der nutzbaren
  `spawn_player*`-Punkte der Karte nicht überschreiten (aktuell Spieler + bis zu 3
  Rivalen; Karten mit mehr Spawns erlauben bis zu 4 – siehe „Probleme“ → P6).
- **Stance:** Jeder teilnehmende Rivale erhält eine von drei Haltungen (Ausgangswert einer
  deterministischen Fuzzy-Logik, siehe „Stance (Fuzzy)“):
  - **Verbündet:** unterstützt den Spieler – der Host steuert die Truppen zugunsten des Spielers.
  - **Neutral:** greift nicht ins Kampfgeschehen ein.
  - **Feind:** kämpft gegen den Spieler – `ObjectHost` steuert wie bei bisherigen Gegnern.
- **Fairness:** Rivalen bringen nur Truppen ins Gefecht, die ihr simulierter Zustand
  hergibt (abgeleitet aus dem Mini-PP-Eingang „Teamqualität“) – keine versteckten Armeen.
  Truppengröße und Stance-Schwellen sind `EconomyBalance`-Konstanten.

**Stance (Fuzzy):** Die Stance ist der **Ausgangswert einer Fuzzy-Logik**. Eingangswerte sind:

- **Persönlichkeit** des Rivalen im Vergleich zu Gewinn/Verlust-Rate und PP des Spielers bzw. –
  wenn das Gegenüber ein anderer Rivale ist – der Persönlichkeit des Rivalen (Sieht er ihn als Gefahr?),
- **Platzierung** der anderen Rivalen im Vergleich zur Platzierung des Spielers (Rivalen aus Rängen,
  die näher beieinander liegen, neigen dazu, sich gegen Rivalen in deutlich höheren/tieferen Rängen
  zu verbünden),
- **Armeestärke** des Rivalen (Hat ein Rivale deutlich stärkere Einheiten im Feld, wäre es taktisch
  unklug, sich mit ihm anzulegen),
- **Sabotage-Historie:** Hat der fragliche Rivale/Spieler kürzlich einen Sabotageakt gegen ihn
  durchgeführt und wurde dabei erwischt? (siehe „Sabotage“).

Die Stance kann sich **im Laufe eines Gefechts wandeln** und wird daher **bei jeder Runde neu beurteilt**.
Die **Eingangs-Stance** je Gefecht bleibt deterministisch aus Stadtteil, Rivalen-IDs und Spieler-Snapshot
abgeleitet (V8/P4); die Neu-Beurteilung je Runde verarbeitet zusätzlich den Gefechtszustand (Einheiten,
Bilanz) – die Stance-Logik selbst würfelt nicht. Schwellen und Gewichte liegen nach V7 in `EconomyBalance`
(siehe „Offene Fragen“ 3).

**Stance-Verlust durch Schaden:** Fügt der Spieler einer Einheit eines Rivalen Schaden zu – **direkt oder
indirekt** –, sinkt dessen Stance **automatisch um eine Stufe** (Verbündet → Neutral → Feind). Mehrfacher
Schaden senkt sie entsprechend mehrfach; **unter „Feind“ gibt es keine weitere Stufe**. Der Verlust wirkt
zusätzlich zur Fuzzy-Beurteilung und fließt in die **Neu-Beurteilung je Runde** ein.

**Stance-Erholung:** Ein durch Schaden erlittener Stance-Verlust ist **temporär** und **gleicht sich pro Runde
minimal wieder aus**, bis die Stance ihren eigentlichen (fuzzy-bewerteten) Wert wieder erreicht hat. Die
Erholungs-Rate je Runde ist ein `EconomyBalance`-Wert (V7).

**Auren & Stance:** Die Stance bestimmt, wen eine Aura trifft (Aura-Mechanik: `10_Karrierepfade.md`):

- **Buff-Auren** wirken auf Fraktionen/Einheiten, deren Stance zur Aura-Fraktion **Verbündet** ist,
- **Debuff-/Schadens-Auren** wirken auf Fraktionen/Einheiten, deren Stance zur Aura-Fraktion **Feind** ist.

**Neutrale** Fraktionen sind weder Buff- noch Debuff-Ziel.

## Handlungen (Prototyp)

Minimaler Umfang (schrittweise erweiterbar):

1. **Rostern:** Beim Wochen-Tick deterministisch aus Prestige-Tier + Rivalen-IDs
   erzeugen (feste Anzahl, feste Persönlichkeiten).
2. **Rivalen-PP (symmetrisch):** Jeder Rivale berechnet seine PP mit demselben
   `PowerProjectionService` wie der Spieler; die Eingänge (Konkurrenzdichte, Bilanz,
   Teamqualität) stammen aus seinem deterministisch simulierten Rivalen-Zustand. Ein
   langsamer, deterministischer Basisanstieg hält die Spannungskurve (Rubber-Band ohne
   Zufall) – keine festen Level-Bänder.
3. **Tick-Aktionen:** Rivalen „investieren“ gemäß Persönlichkeit (Attraktivität/Faktor)
   und bauen ihren simulierten Rivalen-Zustand aus. Die **Gefechtsteilnahme** (mindestens
   Stance Neutral/Feind) folgt, sobald der Rivalen-Zustand steht (siehe
   „Gefechtsteilnahme“).
4. **UI:** „Platz X von Y in <Stadtteil>“ + kompakte Rivalen-Liste (Name + PP/Rang) in
   `ScreenRestaurant`.
5. **Persistenz:** Keine neuen Felder – Rivalen werden je Catch-up neu berechnet
   (idempotent, V8; identisch zur 12er-Entscheidung für PP/Ranking).

**Abnahmekriterien:**

- Identischer Snapshot ⇒ identische Rivalen-Listen/Ränge (Determinismus).
- Anzahl entspricht dem Prestige-Tier inkl. Caps.
- Rivalen-Aktionen verletzen keine `EconomyBalance`-Limits (Fairness-Test).
- Die Stance (Verbündet/Neutral/Feind) ist deterministisch abgeleitet (Neu-Beurteilung je
  Runde) und wird im Gefecht korrekt umgesetzt.
- Schaden des Spielers an einer Rivalen-Einheit senkt die Stance um eine Stufe (bis Feind); der Verlust
  gleicht sich je Runde wieder aus bis zum Ausgangswert.
- Auren berücksichtigen die Stance: Buffs treffen Verbündete, Debuffs/Schaden treffen Feinde.
- „Platz X von Y“ korrekt in der UI (DE/EN via `flutter gen-l10n`).

## Entscheidungen (getroffen)

1. **NPC-Dynamik (12/Q2):** Jeder Rivale erhält ein **symmetrisches Mini-PP-Modell** –
   dieselbe PP-Fuzzy (`PowerProjectionService`), dieselben Eingangsdomänen und
   Balance-Werte wie der Spieler. **Keine** festen Level-Bänder.
2. **Gefechts-Brücke (12/Q3):** Rivalen sind **im Gefecht des Spielers** präsent – **1 bis
   4 Rivalen** über die Mehrfach-Spieler-Spawns der Karten, jeweils mit Stance
   Verbündet/Neutral/Feind (siehe „Gefechtsteilnahme“).
3. **Pleite/Nachrücken:** Zwischen dem Ausscheiden eines Rivalen (Pleite) und dem
   Nachrücken eines neuen liegt eine **Verzögerung von einem Wochen-Tick**, in dem der
   Slot leer bleibt – das erhält das Browsergame-Gefühl.
4. **Wechselwirkung:** Rivalen-Aggressivität skaliert den **PP-Einkommensfaktor** des
   Spielers mit (Gegenwirkung an der Spitze, siehe „Rangliste“).
5. **Stance-Fuzzy:** Die Stance ist der **Ausgang einer deterministischen Fuzzy-Logik**
   (Eingänge: Persönlichkeit/Bilanz/PP, Rangabstand, Armeestärke, Sabotage-Historie) und
   wird **je Runde neu beurteilt** (siehe „Gefechtsteilnahme“ → „Stance (Fuzzy)“).
6. **Stance-Verlust:** Fügt der Spieler einer Rivalen-Einheit Schaden zu (direkt/indirekt),
   sinkt die Stance automatisch um eine Stufe (Verbündet → Neutral → Feind). Der Verlust ist
   **temporär** und gleicht sich **je Runde** minimal wieder aus bis zum eigentlichen Wert.
7. **Auren & Stance:** Buff-Auren treffen **Verbündete**, Debuff-/Schadens-Auren treffen **Feinde**;
   **neutrale** Fraktionen bleiben außen vor (siehe „Gefechtsteilnahme“ → „Auren & Stance“).

## Probleme

### P1 – „Gegner“ doppeldeutig

**Entschieden:** Terminologie „Rivalen“ (`RivalRestaurant`); Auflösung von 12/P3.

### P2 – Host-Singleton & Schichtverstoß

Der Host ist bereits Singleton; seine Erweiterung um die Rivalen-Steuerung vergrößert
die Kopplung. **Entschieden:** Host orchestriert nur; Modelle/Regeln liegen in
`RivalService` bzw. `lib/models/personality.dart` (9/P6). Tests laufen ohne Host.

### P3 – Fairness durchsetzbar halten

„Kein Schummeln“ braucht eine Invariante. **Vorschlag:** Rivalen laufen durch dieselben
`EconomyBalance`-Kostenfunktionen wie der Spieler; ein Vertragstest im Stil von
`balance_sanity_test` sichert „keine versteckten Boni“ ab. 

### P4 – Deterministische Quelle

Zufall im Wochen-Tick verletzt V8-Idempotenz und lässt das Ranking driften.
**Entschieden:** Rivalen sind reine Funktionen von `(district, rivalId, Spieler-Snapshot)`
– Persönlichkeit und PP-Eingänge aus der Rivalen-ID (CRC32), keine RNG-Abhängigkeit im Tick.

### P5 – Frischstart

Ein neues Restaurant hat keinerlei Interaktion. Neutralwerte (Rang, Bilanz) sind bereits
in 12 (P6, `competition = 0.5`) definiert; das Rostern startet direkt aus dem
Prestige-Tier.

### P6 – Spawn-/Teilnehmerlimit

Die Karten bieten aktuell `spawn_player1`–`spawn_player4` (Spieler + max. 3 Rivalen).
Die gewünschte Teilnahme von **1–4 Rivalen** benötigt Karten mit mindestens 5 Spawns;
für schmale Karten wird die Teilnehmerzahl deterministisch reduziert. Alternativ nutzen
Rivalen gemeinsame Spawns/Reservefelder (Detail offen, „Offene Fragen“ 2).

## Offene Fragen

1. **Balancing:** Der Vorschlag in „Anzahl“ (S–D-Schwellen 2.00/1.60/1.30/1.00,
   `rivalCountMin = 3`, `rivalCountMax = 8`) bleibt vorläufig – vieles ist noch
   undefiniert und in stetem Wechsel.
2. **Gefechtsteilnahme:** Truppenstärke der Rivalen je Gefecht und Verhalten bei zu
   wenigen `spawn_player*`-Punkten (deterministische Reduktion vs. weitere Spawns in den
   Karten). => Sind es zu wenige, wird auf die vorhandenen Punkte verteilt
3. **Stance-Schwellen:** Ab welchem Rangabstand/PP-Verhältnis ist ein Rivale Verbündeter,
   Neutral oder Feind (inkl. Anzahl je Stance)? Tuning in `EconomyBalance`.
4. **Nachrücken:** Länge der Verzögerung (Vorschlag: 1 Wochen-Tick) final bestätigen;
   Namensvergabe beim Nachrücken (neue Rivalen-ID ⇒ neuer Name?). => Bestätigt und ja, neue ID heisst auch neuer Name
5. **Gegenwirkungs-Formel:** Exakte Formel für `konkurrenzdruckFaktor` (siehe „Rangliste“). => Vorschläge?
6. **Faktorform:** Linearer Faktor vs. zweite Mini-Fuzzy-Stufe – gemeinsam mit
   `12_Power_Projection.md` (Offene Frage 6) entscheiden.

## Betroffene Dateien

| Datei | Änderung |
|---|---|
| `lib/models/rival_restaurant.dart` | **Neu:** `RivalRestaurant` (id, name, personalityId, simulierter Zustand) |
| `lib/services/rival_service.dart` | **Neu:** Rostern + Wochen-Tick-Aktionen (rein, testbar) |
| `lib/services/economy_balance.dart` | `rivalCountFromPrestige` + Schwellen/Caps, Stance-Schwellen, Gegenwirkungs-Parameter |
| `lib/services/game_clock_service.dart` | Rivalen-Update im Wochen-Tick; `WeeklyTickResult` um Rang/Liste ergänzen |
| `lib/objects/object_host.dart` | Rivalen-Orchestrierung im Tick + Steuerung der Rivalen-Truppen im Gefecht (Delegation an `RivalService`) |
| `lib/widgets/widget_caretaker.dart` | Rivalen-Teams auf weitere `spawn_player*`-Punkte setzen; Stance im Gefecht anwenden |
| `lib/screens/screen_restaurant.dart` | „Platz X von Y“ + Rivalen-Anzeige |
| `lib/l10n/app_de.arb`, `app_en.arb` | Neue Strings (Platz, Rivalen, Pleite) |

## Tests (neu)

- `test/rival_service_test.dart` – Rostern nach Prestige-Tier, Caps, Determinismus/Idempotenz.
- `test/rival_fairness_test.dart` – Rivalen-Aktionen verletzen keine `EconomyBalance`-Limits.
- `test/power_projection_ranking_test.dart` – Rangliste inkl. Rivalen (1-Tick-Verzögerung) + Gegenwirkungs-Faktor.
- `test/rival_stance_test.dart` – deterministische Stance-Ableitung (Verbündet/Neutral/Feind), Neu-Beurteilung je Runde, Stance-Verlust durch Schaden (inkl. Erholung) und Teilnehmerzahl (1–4).