# Echtzeit-Zeitsystem mit Catch-up (V8)

> Fortsetzung von **V8** aus dem Basisdokument (`0-Base.md` → „Verbesserungen“ → V8) sowie der in **V2** (`2-Wirtschaftsschleife.md` – „Tickzeiten“ und „Echtzeit-Zeitsystem (V8)“) und **V3** (`3_Heilung_und_Zeit.md`) angesprochenen Punkte. Grundlage ist der Ist-Code nach den Commits `a723ad5` (V2/V7/V8), `3f47772` (V3), `24ecc6a` (V6) und `4a82d63` (V7).

Dieses Dokument erfasst den **aktuellen Stand** des Zeitsystems, dokumentiert die **verbliebenen Probleme** samt Belegen und leitet daraus **Lösungsvorschläge** sowie die **getroffenen Entscheidungen** ab. Die Grundsatzentscheidungen (Echtzeit im Stile alter Browsergames, Catch-up, Wochentick) sind fixiert und werden hier **nicht** neu verhandelt. Die ursprüngliche „Tagestick/Intervalltick“-Frage ist in § 6 entschieden.

## Aktueller Stand

### 1. Anker & Zeitrechnung

- **`RestaurantData.lastSeenAt`** (`lib/models/profile_data.dart`) ist der **Tagescursor** je Spielstand: bis hierhin sind alle vollen Echtzeittage abgerechnet; wird serialisiert, tolerant deserialisiert (fehlend → `null`) und bei der V1-Migration gesetzt (`1_mehrere_Restaurants.md`, Migration Schritt 3).
- **`RestaurantData.weekAnchorAt`** (neu, § 6) ist der **Wochenanker**: Beginn des laufenden 7-Tage-Blocks; wird nur um volle Wochen weitergezogen. Tolerant deserialisiert (fehlend → `null`, Fallback `lastSeenAt`).
- **`GameClockService`** (`lib/services/game_clock_service.dart`) ist ein reiner Funktionsvorrat (privater Konstruktor) mit **injizierter Zeit** (deterministisch testbar):
  - `elapsed(lastSeenAt, now)` – Differenz, negativ → `Duration.zero` (Kappung gegen Uhrzeit-Backwards).
  - `weeksElapsed` – `elapsed.inDays ~/ 7`, also **volle** Echtzeitwochen.
  - `daysElapsed` (neu, § 6) – **volle** Echtzeittage (`elapsed.inDays`).
  - `hoursElapsed` – Alias auf `elapsed`, liefert eine `Duration` (Name suggeriert Stunden → P4).
  - `nextWeeklyTick` – nächste Blockgrenze für den UI-Countdown; `nextDailyTick` (neu) – nächste Tagesbuchung.
  - `week` = `EconomyBalance.weeklyTick` (7 Tage), `day` = `EconomyBalance.dailyTick` (1 Tag).

### 2. Tages-/Wochen-Catch-up (V2/V8)

- **`catchUp(RestaurantData, now)`**: führt **immer** zuerst Echtzeit-Heilung und Spritzen-Rückfall aus (V3), danach den **Tagesschritt** (§ 6): passives Einkommen entsteht Tag für Tag; an jeder Grenze eines vollen 7-Tage-Blocks folgen Teamarzt-Kosten → Erweiterungs-Unterhalt → Negativzinsen und eine `WeekSettlement`. Die Anker werden nur um die **abgerechneten** Zeiträume fortgeschrieben.
- **Anker-Modell (zwei Zeitmarken):** `lastSeenAt` = **Tagescursor** (bis hierhin sind alle vollen Echtzeittage abgerechnet, Sub-Tag-Rest bleibt erhalten); `weekAnchorAt` = **Wochenraster** (Beginn des laufenden 7-Tage-Blocks, wird nur um volle Wochen weitergezogen). Dadurch bucht auch ein häufiger (periodischer) Tick zuverlässig Tageserträge und vollendet weiterhin 7-Tage-Blöcke; Alt-Stände ohne `weekAnchorAt` fallen auf `lastSeenAt` zurück.
- **Idempotent:** Ein zweiter Aufruf mit demselben `now` liefert `weeks == 0`, `passiveIncome == 0` bzw. `WeeklyTickResult.none` und bucht nicht doppelt; der Sub-Tag-Rest bleibt erhalten (kein Anker-Sprung).
- **Eingangswerte** des passiven Einkommens kommen aus dem Restaurant-Snapshot: `attractivenessOf` (inkl. Rebranding-Malus-Fenster), `teamHealthOf`, `satisfactionOf`, `capacityOf` → `PassiveIncomeService`.
- **Verdrahtung:** `ObjectProfile.runCatchUp(now)` (`lib/objects/object_profile.dart`) konvertiert den Singleton-Zustand in einen `RestaurantData`-Snapshot, ruft `catchUp` auf und schreibt Budget, `lastSeenAt`, `weekAnchorAt` sowie (V3) den geheilten Personalzustand zurück (`_syncStaffFromSnapshot`). Persistiert wird durch die Aufrufer:
  - **Login:** `screen_start._login()` (Ergebnis wird als `pendingCatchUpResult` an den Restaurant-Screen gereicht und dort angezeigt)
  - **App-Resume:** `screen_restaurant._runResumeCatchUp()` (Lifecycle-Hook `resumed`)
  - **Restaurant-Wechsel:** `_switchRestaurant()`
  - **Periodischer Tick (L1/§ 6):** `screen_restaurant._runTick()` (alle 60 s bei offenem Screen)

### 3. Heilung & Notfall-Spritze (V3)

- Heilungskette als reine Vorwärtsrechnung: `_chainPosition`/`_statusByChainPosition` (Z. 162/174), `healedStatus` (Z. 249–264, `Stufen = floor(elapsed/perStage)` – idempotent, nie fortgeschrieben), `remainingHealingTime`/`remainingShotTime` (Z. 269/286) für die Countdowns, `advanceHealing` (Z. 299–341), `rollBackEmergencyShots` (Z. 343–372).
- Heiltempo: bester angestellter Arzt (`bestMedicQuality` Z. 217 / `bestHiredQuality` Z. 232) bzw. `EconomyBalance.healBasePerStage` (24 h).
- UI-Countdowns: Personal-Liste (`screen_restaurant.dart:795–814`), Detailansicht (`screen_character_detail.dart:216–228`), „nächste Abbuchung“ (`screen_restaurant.dart:1058–1064`).

### 4. Testabdeckung

- `test/game_clock_service_test.dart`: Zeitrechnung (Z. 9–82) und Tagesschritt/Wochen-Catch-up inkl. Idempotenz, Rundung, Anker-Stabilität und Randfällen (Z. 84 ff.); ergänzt durch `healing_service_test.dart`, `emergency_shot_test.dart` und `balance_sanity_test.dart`.

### 5. Abweichung von der V2-Vorlage

- **Tagestick/Intervalltick** (`2-Wirtschaftsschleife.md:357–363`) wurden **nicht** als Scheduler-Module umgesetzt. Die Heilung ist eine reine Neuberechnung aus `injuryStartedAt` + `now` im Catch-up (V3-Entscheidung); der **Tag** bleibt als **Abgrenzungsebene des passiven Einkommens** im Catch-up erhalten (§ 6, Entscheidung). Für den geöffneten Screen sorgt seit **L1** ein **periodischer UI-Tick** (60 s), der dieselbe Rechnung anstößt (→ P1, behoben; § 6).

### 6. Tagesschritt & Wochen-Zusammenfassung (Entscheidung)

**Entscheidung (Q1):** Tagestick/Intervalltick werden **nicht** als Scheduler-Module umgesetzt. Stattdessen wird „Tag“ eine **Abgrenzungsebene im bestehenden Catch-up** („Tagesschritt“): Das passive Einkommen entsteht **anteilig pro vollem Echtzeittag**, die Abbuchung von Arzt/Unterhalt/Zinsen und die Wochen-Zusammenfassung bleiben an **volle 7-Tage-Blöcke** gebunden. Kein persistiertes Event-Journal – die Grundlage bleibt „Anker + `now`, idempotent nachrechnen“; hinzu kommt der **periodische UI-Tick** (L1), der dieselbe Rechnung bei offenem Screen anstößt.

**Tagesertrag & Rundung:** `incomePerDay = incomePerWeek ~/ 7`; der **7. Tag** eines Blocks trägt den Rest (`incomePerWeek − 6·incomePerDay`), damit `Σ Blocktag = Wochenertrag` exakt gilt. `balance_sanity_test.dart` erzwingt die Identität.

**Anteilige Resttage (Entscheidung):** Auch Tage **außerhalb** des letzten vollen Blocks buchen Tagesertrag (z. B. 30 Tage Lücke = 4 Wochen-Abschlüsse + 2 Resttage). `daysElapsed = elapsed.inDays` (floor, exakte 24-h-Einheit – nicht die Wanduhr-Kalenderschicht); ein angebrochener Tag zählt nicht. Arztkosten, Unterhalt, Negativzinsen und die Zusammenfassung entstehen **nur** an Blockgrenzen.

**Reihenfolge im Catch-up** (Heilung bleibt vorgelagert): Echtzeit-Heilung → Spritzen-Rückfall → **Tagesschleife** (Tag für Tag `+incomePerDay`; an jeder Blockgrenze `−Arzt`, `−Unterhalt`, Negativzinsen, `WeekSettlement`) → Anker fortschreiben (`lastSeenAt` um die abgerechneten Tage, `weekAnchorAt` um die abgeschlossenen Wochen).

**Rechnerische Identität für volle Blöcke:** Da die Zinsen am Blockende auf `Blockstart + Σ Blocktag − Arzt − Unterhalt` geprüft werden und `Σ Blocktag = Wochenertrag` gilt, ist das Ergebnis für **volle** Wochen numerisch identisch zum bisherigen Wochen-Tick. Verhaltensänderungen gegenüber vorher: (a) **anteilige Resttage** werden gebucht (vorher 0 €), (b) das **Wochenraster** ist stabil – vorher verschob jeder Catch-up den Anker auf `now`, wodurch häufige Catch-ups 7-Tage-Blöcke nie vollendeten (regelmäßige Spieler zahlten faktisch keine Arztkosten).

**Ergebnis-Typ (erweitert, nicht ersetzt):** `WeeklyTickResult` behält seine Summenfelder (`weeks`, `passiveIncome`, `medicCosts`, `upgradeUpkeep`, `negativeInterest`, `budgetAfter`, `bankrupt`) und erhält zusätzlich:
- `settlements`: Liste je vollendetem Block (`weekIndex`, `periodStart`, `periodEnd`, `income`, `medicCosts`, `upgradeUpkeep`, `negativeInterest`, `budgetAfter`);
- `leftoverDays`/`leftoverIncome`: die anteiligen Resttage außerhalb des letzten Blocks.

**Erweiterungspunkt für Erweiterungen/Personal (Q1):** Da die Wirtschaft nun tag-genau durch die Lücke läuft, können künftige Effekte (Restauranterweiterungen, Personal) als **zeitfenster- oder tagesabhängige Modifikatoren** in den Eingangswert-Pfad (`attractivenessOf`/`satisfactionOf`/`capacityOf`) oder als Zusatzbuchung je Tag/Block eingehängt werden – analog zum bestehenden `rebrandingPenaltyUntil`-Fenster. Das braucht **weder** einen Scheduler **noch** ein Journal; der Catch-up bleibt die einzige Zeitquelle.

**Semantik „Woche“ (Q4 – Kompatibilität):** Voll vereinbar. Tagescursor und Wochenraster bilden dasselbe Anker-Gitter (`weekAnchorAt + k·7 d` mit `lastSeenAt` als Tagesposition darin); da 7 × 1 d = 7 d, zerfällt jeder Wochenblock exakt in sieben Tagesintervalle. Es bleibt bei **vollen, kalenderunabhängigen 7-Tage-Blöcken** (kein „immer montags“). Der Wochenanker wird **nur** um volle Wochen weitergezogen, sodass häufige Catch-ups (periodischer Tick) das Raster nicht verschieben; ein voller Tag liegt vor, wenn `elapsed.inDays` (exakte 24-h-Einheit) steigt.

**Neue API (umgesetzt):** `EconomyBalance.dailyTick = Duration(days: 1)` (kein Literal, V7), `GameClockService.day`, `daysElapsed(...)`, `nextDailyTick(...)`, `WeekSettlement` sowie die erweiterten `WeeklyTickResult`-Felder `settlements`/`leftoverDays`/`leftoverIncome`. Neu im Speicherformat: `RestaurantData.weekAnchorAt` (tolerant, keine Pflicht).

---

## Probleme im Detail

### P1 – Kein laufender Tick: „Echtzeit“ nur beim Öffnen – **behoben (L1)**

> **Status:** Mit L1 umgesetzt – `ScreenRestaurant` rechnet alle 60 s nach (`_runTick`); der Tagesschritt bucht Tageserträge und das stabile Wochenraster vollendet weiterhin 7-Tage-Blöcke. Die folgenden Belege beschreiben den Zustand **vor** der Umsetzung.

**Symptom:** Die App läuft sichtbar über eine Tages- oder Wochengrenze hinweg – es passiert nichts: keine Tagesbuchung, keine Abbuchung, keine Heilungs-/Rückfall-Aktualisierung, kein Countdown-Update.

**Belege:**
- *(vor L1)* `GameClockService.catchUp` lief ausschließlich bei Login, Resume und Restaurant-Wechsel (siehe § 2); **kein** `Timer.periodic` / periodischer Rebuild im gesamten `lib/`.
- *(vor L1)* Die Countdowns wurden einmalig beim Screen-Build aus `DateTime.now()` berechnet (`screen_restaurant.dart`, `_buildEconomyInfo`/`_healingInfoText`) und erst beim nächsten `setState` neu gezeichnet.
- `AppLifecycleState.resumed` feuert nur bei einem echten Resume, nicht bei sichtbar durchlaufendem Betrieb.

**Auswirkung:** Wirtschaft und Heilung „frieren“ ein, sobald die App offen ist; die angezeigte Welt weicht von der realen Rechnung ab (inkl. des in § 6 eingeführten Tagesertrags). Der Basisdokument-Effekt „zurückkommen → Welt hat sich weiterentwickelt“ greift nur für Abwesenheit, nicht fürs Offenlassen.

### P2 – Catch-up-Ergebnis wird verworfen (toter Rückgabewert) – **behoben (L2)**

> **Status:** Mit L2 umgesetzt – die Aufrufer werten `WeeklyTickResult` aus und zeigen eine SnackBar; beim Login wird das Ergebnis über `ObjectProfile.pendingCatchUpResult` an den Restaurant-Screen gereicht. Der folgende Beleg beschreibt den Zustand **vor** der Umsetzung.

**Beleg:** `runCatchUp` liefert `WeeklyTickResult` (Wochen, Einkommen, Arztkosten, Unterhalt, Zinsen; ab § 6 zusätzlich `settlements` und Resttage) und die Heilung liefert `HealingTickResult` – **kein** Aufrufer wertete sie aus (`screen_start._login`, `screen_restaurant._runResumeCatchUp`/`_switchRestaurant`; Zustand vor L2).

**Auswirkung:** Der Spieler sieht nie, was der Catch-up gebucht hat („3 Wochen vergangen: +1.200 € Einkommen, −1.500 € Arztkosten …“). Die Wirtschaft bleibt intransparent – genau das „fühlt sich nicht richtig an“ aus dem Basisdokument. Mit dem Tagesschritt (§ 6) wächst die Menge der stillen Buchungen weiter (ein Tagesertrag pro Tag), was P2 verschärft.

### P3 – Wochen-Tick ist nicht save-fähig idempotent (Rest-Risiko)

**Beleg:** Der Wochen-Tick ist ausschließlich über den Zeitanker verankert. V6 hat die Save-Pfade abgesichert (awaitete Speicher, Fehler-Snackbar, Speichern bei `paused`/`hidden`; `screen_restaurant.dart:107–130`, `6_Persistenz.md` L7/L4). Es bleibt die **Crash-Lücke** zwischen Mutation (`runCatchUp`) und Save: Stirbt der Prozess dazwischen, rechnet der nächste Start **erneut** alle Tage/Wochen ab (Tagesertrag, Arztkosten, Unterhalt, Zinsen doppelt). Die Heilung ist über `injuryStartedAt` idempotent, der Wirtschafts-Tick nicht.

### P4 – `hoursElapsed` ist irreführend benannt

**Beleg:** `hoursElapsed(from, now)` (Z. 184–186) ist ein reiner Alias von `elapsed` und liefert eine `Duration`, **keine Stundenzahl**. Auch die Tests verifizieren `Duration` (`game_clock_service_test.dart:71–81`).

**Auswirkung:** Namens-Typ-Konflikt ist eine klassische Fehlerquelle (Aufrufer „rechnet in Stunden“ und multipliziert mit einem `Duration`-Wert).

### P5 – Doppelte Severity-Quelle

**Beleg:** `_severityByStatus` (Z. 138–147, `Map<String, int>`) dupliziert `CharacterStatus.severity` (`lib/objects/player_objects/object_apprentice.dart:12–25`). `teamHealthOf` (Z. 557–567) nutzt die Map, während die Enum-Severity parallel existiert.

**Auswirkung:** Zwei Quellen für dieselbe Wahrheit – jede neue Statusstufe müsste an beiden Stellen gepflegt werden (Driftgefahr, vgl. V3-„eine Quelle der Wahrheit“).

### P6 – Zwei fast identische Best-Ärzte-Helfer + O(n²)-`indexOf`

**Beleg:** `bestMedicQuality` (Z. 217–230, für `MedicData`) und `bestHiredQuality` (Z. 232–245, für `ObjectTeamMedic`) sind strukturell identisch; beide vergleichen per `MedicQuality.values.indexOf(...)` in einer Schleife.

**Auswirkung:** Duplikation trotz gleicher Semantik; die Rangfolge steckt implizit in der Enum-Reihenfolge (`medic_quality.dart:7–16`) statt in einem expliziten Ranking.

### P7 – `HealingTickResult.shotRolledBackCount` ist immer 0

**Beleg:** `advanceHealing` setzt den Zähler hart auf `0` (innerhalb Z. 299–341); der echte Rückfall läuft in `rollBackEmergencyShots` (Z. 343–372), dessen Rückgabewert `catchUp` (Z. 432 ff.) **verwirft**.

**Auswirkung:** Irreführendes Feld in einem Ergebnis-Datentyp; die Information „X Spritzen zurückgerollt“ geht verloren (verstärkt P2).

### P8 – Tages-/Wochen-Schnappschuss statt Verlauf

**Beleg:** `catchUp` berechnet `incomePerWeek`, `medicPerWeek` und `upkeepPerWeek` **einmal** aus dem End-Snapshot (Z. 456–470) und wendet sie auf **alle** fehlenden Tage/Wochen an. Da in der Lücke keine Spieleraktionen möglich sind, ist der Zustand faktisch konstant – die einzige zeitabhängige Eingangsgröße ist der **Rebranding-Malus**, der aber gegen das **finale** `now` geprüft wird (Z. 550–552), nicht pro Tag/Woche. Außerdem speist die Heilung das Einkommen mit dem **Endzustand** (Heilung läuft vor der Rechnung, Z. 435–436).

**Auswirkung:** Bei mehrwöchigen Lücken mit Malus-Fenster innerhalb der Lücke weicht die Rechnung (geringfügig) von einer wochenweisen Simulierung ab. Kein akuter Bug, aber eine stillschweigende Vereinfachung – festhalten/entscheiden (L5). Der Tagesschritt (§ 6) übernimmt den Snapshot als **konstanten Tagesertrag** (`incomePerWeek / 7`); das ist mit der L5-Entscheidung („Endzustand akzeptieren“) konsistent, solange der Malus weiterhin nur einmal gegen das finale `now` geprüft wird.

### P9 – Zeitbasis: lokale Wanduhr, DST, Systemzeit

**Belege:** `DateTime.now()` (lokal, ohne UTC) wird überall als `now` injiziert; gespeichert wird ISO ohne Zeitzonen-Suffix (`toIso8601String`, `profile_data.dart`). `elapsed.inDays ~/ 7` rechnet über DST-Grenzen hinweg (Frühjahr: „Woche“ = 167 h, Herbst: 169 h) – für die Tages-Abrundung marginal, aber undokumentiert. Vorwärtsdrehen der Systemuhr lässt den Catch-up beliebig viele Tage/Wochen abbuchen (bis zur Negativgrenze → Bankrott); Zurückdrehen wird gekappt (`elapsed`, Z. 150–153); die Anker bleiben dabei unverändert (kein Negativ-Exploit, § 6).

**Auswirkung:** Zeitreise-/Uhr-Manipulations-Szenarien sind weder abgesichert noch getestet; die DST-Frage ist nicht entschieden (→ L6).

### P10 – `GameClockService` trägt drei Verantwortlichkeiten

**Beleg:** Zeitrechnung (Z. 150–153, 390–414), Heilungskette (Z. 162–372) **und** Wirtschafts-Eingänge (Z. 542–599) in einer statischen Klasse (~600 Zeilen). V7 L9 (Layering) wurde bewusst zurückgestellt (`7_Wirtschaftswerte_zentralisieren.md`, L9).

**Auswirkung:** Noch handhabbar, aber der „Tick-Service“ wird zum Universal-Dienst; jeder neue Zeit-Effekt (Events, Benachrichtigungen) wächst hier an (→ L7).

---

## Lösungsvorschläge

### L1 – Laufender Tick (P1) – umgesetzt

- **Periodischer Rebuild im aktiven Screen:** `Timer.periodic` (60 s) in `ScreenRestaurant`, gestartet in `initState` / gestoppt in `dispose`: `_profile.runCatchUp(DateTime.now())` → bei Fälligkeit (`result.weeks > 0` oder `result.leftoverDays > 0`) speichern + SnackBar, sonst nur `setState` (Countdowns aktualisieren). Die Logik bleibt im Service, die Zeitschicht ist reine UI; Reentranz-Schutz über `_isSaving`.
- **Tagesgrenze:** Da der Tagesschritt (§ 6) am Tagescursor hängt und **nur um abgerechnete Tage** fortgeschrieben wird, bucht der nächste periodische Lauf nach Überschreiten einer Tagesgrenze automatisch einen Tagesertrag – und das Wochenraster (`weekAnchorAt`) bleibt stabil, sodass auch 7-Tage-Blöcke bei offenem Screen vollendet werden.
- **Testbarkeit:** Der Kern (Fälligkeit, Anker-Stabilität) ist über `catchUp` mit injiziertem `now` abgedeckt (u. a. „Tagesbuchungen summieren sich exakt zur Woche“ und „Wochenraster bleibt stabil“).
- **Doku:** „Echtzeit“ im Doku-Sinne = **periodisches Nachrechnen**, nicht nur beim Resume.

### L2 – Catch-up-Ergebnis sichtbar machen (P2) – umgesetzt

- `_runResumeCatchUp`/`_runTick`/`_switchRestaurant` werten `WeeklyTickResult` aus und zeigen eine SnackBar: „3 Wochen abgerechnet: +Y Einkommen, −Z Arztkosten, −W Unterhalt, −V Zinsen; dazu 2 Tage Einkommen +X €“. Die Wochenzeile speist sich aus den Summen/`settlements`, die Resttage aus `result.leftoverDays`/`leftoverIncome` (§ 6). Neue l10n-Strings `catchUpSummary`/`catchUpLeftover` (DE/EN in den ARB-Dateien).
- **Login:** Weil der Catch-up in `screen_start._login()` vor dem Aufbau des Restaurant-Screens läuft, wird das Ergebnis als `ObjectProfile.pendingCatchUpResult` gereicht und im ersten Frame angezeigt.
- **Detailansicht (optional, offen):** Ein kleiner „Abrechnungs-Dialog“, der die `settlements` Woche für Woche auflistet.

### L3 – Wochen-Tick robust gegen Save-Lücke (P3) – teilweise umgesetzt

- **Umgesetzt (Entkopplung):** Der Wochen-`catchUp` schreibt `RestaurantData.weekAnchorAt` getrennt vom Tagescursor `lastSeenAt` fort; die Wochenrechnung ist damit unabhängig testbar und stabil gegen häufige Catch-ups. Das reduziert die Doppelbuchungs-Gefahr, **ersetzt aber nicht** die Absicherung der Save-Lücke unten.
- **Offen (Empfehlung):** Die verbleibende **Crash-Lücke** zwischen `runCatchUp` und Save (P3) bleibt – ein Write-ahead-Journal `profiles/<id>/last_tick.json` (vor der Mutation schreiben, beim Boot abgleichen) ist bei Bedarf die strikte Lösung. Angesichts der V6-Absicherung **nicht** zwingend.

### L4 – API-Aufräumen (P4–P7; reine Refactorings, kein Verhaltenswechsel)

1. `hoursElapsed` (P4): entfernen (Alias) oder zu `int elapsedHours(...)` umbauen, wo die UI Stunden braucht. **Offen.**
2. `_severityByStatus` (P5): entfernen; `teamHealthOf` nutzt `_statusFromName(s.status).severity` – eine Quelle der Wahrheit. **Offen.**
3. Best-Ärzte-Helfer (P6): Ranking explizit (z. B. `MedicQuality.rank` bzw. Map in `EconomyBalance`, wo das Tuning bereits liegt) + ein gemeinsamer Helfer `bestQuality(Iterable<T>, MedicQuality? Function(T))`. **Offen.**
4. `HealingTickResult.shotRolledBackCount` (P7): Feld entfernen **oder** den Rückfall in `advanceHealing` integrieren und beide Zähler gemeinsam zurückgeben. **Offen.**
5. `_medicQualityFromName`/`_statusFromName` (lineare Scans): konstantierte `Map<String, MedicQuality>`/`Map<String, CharacterStatus>`. **Offen.**
6. **Tagesschritt-API (§ 6): umgesetzt** – `EconomyBalance.dailyTick`, `GameClockService.day`/`daysElapsed`/`nextDailyTick`, `WeekSettlement`, erweiterte `WeeklyTickResult`-Felder.

### L5 – Wochen-Schnappschuss dokumentieren & Malus-Fenster präzisieren (P8)

- **Entschieden:** Für die Lücke gilt der **Endzustand** (einfach, erklärbar); im Code-Kommentar von `catchUp` festhalten. Der Tagesschritt (§ 6) leitet daraus einen **konstanten Tagesertrag** ab.
- **Kleine Verbesserung (optional):** Rebranding-Malus pro Tag/Block prüfen (Tagesschleife mit tagesweisem Zeithorizont statt nur finalem `now`) – kleiner Aufwand, ein Test dazu. Bleibt derzeit bewusst bei „finales `now`“.

### L6 – Zeitbasis & Systemzeit (P9)

- **Entschieden:** Lokale Wanduhr bleibt akzeptiert **und** wird dokumentiert (Browsergame-Niveau); die Umstellung auf ISO-UTC (`DateTime.now().toUtc()` schreiben, Alt-Stände ohne Suffix als lokal lesen – abwärtskompatibel) bleibt eine **optionale** spätere Änderung.
- **Absicherung:** Optionaler `EconomyBalance.maxCatchUpWeeks`-Cap (z. B. 52) verhindert, dass ein versehentlich vorgestellter Systemtimer einen Spielstand in den Bankrott rechnet; der Cap deckelt dann auch die Tage/Blöcke des Tagesschritts (§ 6). Test für „Uhr zurückgedreht“ (Clamp-Verhalten).

### L7 – Verantwortlichkeiten (P10)

- Kein Pflicht-Splitt (L9 bleibt zurückgestellt). Falls der Service weiterwächst: Aufteilung in `GameTime` (elapsed/weeks/nextTick), `HealingService` (Kette + advance + rollback) und Wochen-Tick in `EconomyService.catchUp`. Als Option dokumentieren, nicht erzwingen.

### L8 – Tests für die Randfälle – umgesetzt

- **App-offen über Tages-/Wochengrenze:** `catchUp(t0)` → Simulation des periodischen Ticks mit `t0 + 7 d` → genau **eine** Abbuchung; danach `t0 + 8 d` → **keine** zweite Wochenabbuchung, aber ein Tagesertrag (Resttag § 6). Abgedeckt u. a. durch „Tagesbuchungen summieren sich exakt zur Woche“ (7 tägliche Catch-ups → genau 1 Block) und „Wochenraster bleibt stabil“.
- **Tagesschritt & Rundung:** Restaurant **mit** Personal; 3 Tage Lücke → 3 Tageserträge, **kein** `settlement`; 7 Tage → genau **ein** `settlement` mit dem Wochenertrag; 8 Tage → 1 `settlement` + 1 Resttag; 30 Tage → 4 `settlements` + 2 Resttage. `Σ Blocktag = Wochenertrag` (Rest am 7. Tag).
- **Idempotenz:** zweiter Aufruf mit demselben `now` bucht weder Wochen noch Resttage doppelt.
- **Zeitzonen/DST:** Die Zählung nutzt exakte 24-h-Einheiten (`elapsed.inDays`); der Test verwendet daher UTC-Zeitpunkte (deterministisch, unabhängig von der Maschinen-Zeitzone). Bei lokaler Wanduhr verschiebt eine DST-Umstellung einen „Kalendertag“ um ±1 h (dokumentiert, L6).
- **Uhr zurückgedreht:** `now < lastSeenAt` → `elapsed == 0`, keine Buchung; die Anker bleiben unverändert (kein Negativ-Exploit).
- **`lastSeenAt == null`** (erster Lauf): Heilung ohne Migration heilt ab `now` (Fallback); Tages-/Wochen-Tick = No-op, beide Anker werden auf `now` gesetzt.
- **Wochen-Cap** (falls L6): mehr als `maxCatchUpWeeks` fällig → gedeckelt bzw. dokumentiert. **Offen** (L6 optional).
- **No-op-/Resttage-Fälle:** „kein voller Tag“, „Uhr zurückgedreht“ und „`lastSeenAt == null`“ liefern `WeeklyTickResult.none`; „3 Tage mit Personal“ bucht Resttage ohne Blockabschluss (Tests vorhanden).

---

## Entscheidungen (getroffen)

Die zuvor offenen Fragen sind entschieden:

- **Tagestick/Intervalltick (Q1) – entschieden:** Keine Scheduler-Module, kein Event-Journal. Der **Tag** wird als Abgrenzungsebene des passiven Einkommens in den bestehenden Wochen-Catch-up integriert (§ 6): Tagesertrag `incomePerWeek / 7` (Rest am 7. Tag), Resttage anteilig, Arzt/Unterhalt/Zinsen und Wochen-Zusammenfassung weiterhin nur an vollen 7-Tage-Blöcken. Künftige Erweiterungs-/Personal-Effekte hängen als zeitfenster-/tagesabhängige Modifikatoren im Eingangswert-Pfad ein (wie `rebrandingPenaltyUntil`) – das **erweitert das Konstrukt, ohne es zu zerbrechen**.
- **Wochen-Schnappschuss (Q2/L5):** Endzustand akzeptieren? **Ja** – der Endzustand gilt für die Lücke und wird als **konstanter Tagesertrag** verwendet; im Code-Kommentar von `catchUp` festgehalten.
- **Zeitbasis (Q3/L6):** lokale Wanduhr belassen und dokumentieren, auf UTC umstellen, Wochen-Cap einführen? **Ja** – lokale Wanduhr bleibt (dokumentiert), UTC-Umstellung optional später, `maxCatchUpWeeks`-Cap als Absicherung vorgesehen.
- **Semantik „Woche“ (Q4) – entschieden:** volle 7-Tage-Blöcke (kalenderunabhängig) bleiben. **Voll vereinbar** mit dem Tagesschritt: Tagescursor (`lastSeenAt`) und Wochenraster (`weekAnchorAt`) bilden dasselbe Gitter, 7 × 1 d = 7 d; keine feste Abbuchungszeit („immer montags“). Der Wochenanker wird nur um volle Wochen weitergezogen (stabil bei häufigen Catch-ups).

## Definition of Done / Abnahmekriterien

- [x] Periodischer Tick: überbrückt die App – auch bei offenem Screen – eine Tages-/Wochengrenze, wird abgerechnet/aktualisiert (L1, Tests vorhanden).
- [x] Tagesschritt (§ 6): passives Einkommen entsteht anteilig pro vollem Echtzeittag (inkl. Resttage); Arztkosten, Unterhalt, Negativzinsen und Wochen-Zusammenfassung entstehen nur an vollen 7-Tage-Blöcken; `Σ Blocktag = Wochenertrag` (Tests vorhanden).
- [x] Countdowns laufen sichtbar mit (Personal, Spritze, „nächste Abbuchung“; „nächste Tagesbuchung“ über `nextDailyTick` verfügbar, optional).
- [x] Catch-up-Ergebnis wird dem Spieler angezeigt (L2) – inkl. Wochen-Zeile und Resttage-Zeile.
- [~] `dailyTick`/`daysElapsed`/`nextDailyTick`/`WeekSettlement` ergänzt (L4.6); die reinen Aufräum-Punkte L4.1–L4.5 (`hoursElapsed`, `_severityByStatus`, Doppel-Helfer, `shotRolledBackCount`) sind **offen** – `flutter analyze` ohne neue Warnungen, `flutter test` grün.
- [x] Wochen-Schnappschuss und Malus-Fenster dokumentiert bzw. präzisiert (L5).
- [x] Zeit-/Tages-Randfälle durch Tests abgedeckt (L8).
- [x] `dart analyze lib test` und `flutter test` vollständig grün; keine neuen l10n-Strings ohne ARB-Einträge (siehe Nachtrag).

## Testplan

```bash
flutter analyze
flutter test test/game_clock_service_test.dart test/healing_service_test.dart test/emergency_shot_test.dart
flutter test
```

## Risiken

- **Verhaltensänderungen** müssen mit injizierter Zeit getestet sein. Für **volle** Wochen bleibt das Catch-up-Ergebnis numerisch identisch; **neu** sind die anteiligen Resttage und das Anker-Modell (Tagescursor + Wochenraster). Die „0-Wochen“-/Resttage-Pfade sind durch Tests abgedeckt (L8).
- **Rundung des Tagesertrags:** Der Tagesertrag muss deterministisch bleiben (Rest am 7. Tag), sonst driftet die Wochensumme; durch `balance_sanity_test.dart` und den Rundungstest abgesichert.
- **Save-Kompatibilität:** Das neue Feld `RestaurantData.weekAnchorAt` wird tolerant deserialisiert (fehlend → `null`, Fallback `lastSeenAt`, keine Pflichtfelder) – V6-Prinzip.
- **L1-Timer:** Kein speichernder Tick parallel zu `_saveOnBackground`; `_runTick` nutzt denselben Reentranz-Schutz (`_isSaving`) und speichert nur bei tatsächlicher Buchung.

---

## Nachtrag: Umsetzung (Tagesschritt & Anker)

Der Tagesschritt (§ 6) sowie L1/L2/L3(Teil)/L4.6/L8 sind umgesetzt und getestet.

### Datenmodell & Persistenz
- `RestaurantData.weekAnchorAt` (neu): Wochenanker, tolerant serialisiert (`profile_data.dart`), in `ObjectProfile` (Feld, `loadFromData`, `toProfileData`, `activeRestaurantSnapshot`, `runCatchUp`) verdrahtet.
- `lastSeenAt` = **Tagescursor** (nur um abgerechnete Tage fortgeschrieben, Sub-Tag-Rest bleibt erhalten).

### Service (`GameClockService`)
- `EconomyBalance.dailyTick`; `GameClockService.day`, `daysElapsed`, `nextDailyTick`.
- `WeekSettlement` (Wochen-Zusammenfassung je Block) und `WeeklyTickResult` mit `settlements`/`leftoverDays`/`leftoverIncome`.
- `catchUp`: Heilung → Spritzen-Rückfall → **Tagesschleife** (Tagesertrag; Blockgrenze = Arzt/Unterhalt/Zinsen + `WeekSettlement`); Anker werden um abgerechnete Tage/Wochen fortgeschrieben. Bei Fälligkeit 0 bleiben die Anker unangetastet.

### UI & l10n
- `ScreenRestaurant`: `Timer.periodic` (60 s, `_runTick`), Ergebnis-SnackBar (`_showCatchUpResult`), Login-Ergebnis via `pendingCatchUpResult`; der Wochen-Countdown nutzt `weekAnchorAt`.
- Neue ARB-Strings `catchUpSummary`/`catchUpLeftover` (DE/EN), `flutter gen-l10n` ausgeführt.

### Validierung
- `dart analyze lib test`: **keine Warnungen/Fehler** (nur die vorbestehenden `info`-Lints).
- `flutter test`: **245 Tests grün**, inkl. neuer Tages-Schritt-, Rundungs-, Anker-Stabilitäts- und Randfall-Tests (`test/game_clock_service_test.dart`), sowie `balance_sanity_test.dart` (`dailyTick × 7 == weeklyTick`).

### Offen (bewusst zurückgestellt)
- L4.1–L4.5 (Aufräum-Refactorings ohne Verhaltenswechsel).
- L6: optionaler `maxCatchUpWeeks`-Cap und optionale UTC-Umstellung (lokale Wanduhr ist dokumentiert und bleibt Standard).
- L2-Detaildialog (Wochen-Aufschlüsselung) sowie P3-Journal (nur falls nötig).
