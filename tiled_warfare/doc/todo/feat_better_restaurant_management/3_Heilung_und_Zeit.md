# Heilung & Zeit konsistent machen (V3)

Dies ist die Ausarbeitung von **V3 (→ P3)** aus dem Basisdokument (`0-Base.md` – Abschnitt „Verbesserungen“ → V3 sowie „Entscheidungen (getroffen)“ → Nr. 2). Sie beschreibt, wie Heilung, Verletzungsstatus und die Notfall-Spritze zu **einer konsistenten, echtzeitbasierten Mechanik** werden.

Die Grundsatzentscheidungen sind fixiert und werden hier nicht neu verhandelt:

- **Echtzeit** im Stile alter Browsergames; verpasste Zeit wird beim App-Start nachgeholt („Catch-up“, V8).
- Der Spielzustand liegt seit **V1** auf der **Restaurant-Ebene** (eigenes Team je Spielstand).
- **`status` ist die einzige Quelle der Wahrheit** für den Management-Zustand eines Charakters; `woundValue` (Kampf-HP) wird daraus abgeleitet.

V3 baut auf **V1** (Restaurant-Zustand, `lastSeenAt`), **V8** (`GameClockService`) und **V7** (`EconomyBalance`) auf. `2-Wirtschaftsschleife.md` (Abschnitt „Tickzeiten“) reserviert **Tagestick** und **Intervalltick** ausdrücklich für dieses Dokument.

### Entscheidungen (eingearbeitet)

- **`afraid`** ist **Teil der Heilungskette** (Kette `hurt → afraid → reeling`; `team_rules.md` § 4.3 angepasst).
- **`effectiveHealTime` (Fuzzy)** ist **vollständig aus der Zeitrechnung genommen** und wird entfernt (deterministisch, kein Einfrieren eines Werts).
- **Migration:** Alt-Spielstände ohne `injuryStartedAt` heilen **rückwirkend ab `restaurant.lastSeenAt`** (Fallback `now`).
- **Notfall-Spritze:** **keine manuelle Auslösung** mehr – automatische Verabreichung direkt beim Verletzungsbeginn (nach dem Rettungswurf), Rückfall nach 24 h per Tick.

## Problemstellung (im Detail)

### Symptom

Ein mit dem Teamarzt „gesund“ behandelter Charakter (`status == ready`) startet das nächste Gefecht mit fast leerer Lebensenergie und wirkt dadurch extrem zerbrechlich. Die „temporäre“ Notfall-Spritze ist in Wahrheit permanent. Heilung passiert per Klick **sofort** statt in Echtzeit, und ein `afraid`-Charakter lässt sich nie behandeln.

### Ursache (Belege)

1. **Doppelte Buchführung.** `ObjectToken.woundValue` (`lib/objects/object_token.dart:52`, Default `3`) und `ObjectApprentice.status` (`lib/objects/player_objects/object_apprentice.dart:44`, `severity` 0–7) werden unabhängig gepflegt und laufen auseinander.
2. **Rettungswurf setzt HP auf 1.** `_performSurvivalRolls()` (`lib/objects/object_profile.dart:247–298`) setzt Gerettete auf `woundValue = 1` **und** `status = dying` (Z. 276–277, 286–287).
3. **`treatCharacter()` heilt nur den Status.** (`lib/objects/object_team_medic.dart:204–244`) Der `switch` heilt `dying → injured → hurt → reeling → ready`, lässt `woundValue` aber unverändert auf `1`. Beim nächsten Gefecht übernimmt `selectTeamForBattle`/`syncUnitsAfterBattle` den Wert.
4. **`afraid` ist unheilbar.** Der `switch` in `treatCharacter()` hat keinen `afraid`-Zweig → fällt in `default` → `false`. Ein Charakter mit `status == afraid` (`team_rules.md` § 4.4, severity 3) bleibt dauerhaft festsitzen.
5. **Notfall-Spritze ohne Rückfall.** `emergencyShot()` (`lib/objects/object_team_medic.dart:255–280`) setzt `woundValue = 1` und `status = ready`. Der eigene Kommentar (Z. 277–278) weist darauf hin, dass der Rückfall nach einem Tag „durch einen Timer/ein Event-System außerhalb dieser Klasse behandelt werden“ müsste – existiert aber nicht.
6. **Kein Zeitfaktor.** `MedicQuality.healTimePerStage` (6 h / 3 h / 1 h, `lib/objects/object_team_medic.dart:14–38`) und `effectiveHealTime` (Z. 300–308) werden von keinem Tick konsumiert. `GameClockService` (`lib/services/game_clock_service.dart`) rechnet bisher nur in **Wochen**; das Personal ist kein Teil des Catch-up.
7. **Regelkonflikt.** `team_rules.md` § 4.3 („1 Stufe pro Echtzeit-Tag“) bzw. § 4.5 („1 Stufe pro Echtzeitstunde“) vs. `healTimePerStage` (6 h / 3 h / 1 h).

### Auswirkung

„Ready“ wirkt unfair; der Spieler kann den Spritzen-Rückfall nicht erleben; Heilung ist nicht planbar (kein Countdown); Regeln und Code widersprechen sich. Ein `afraid`-Charakter ist ein Deadlock (nie behandelbar, nie einsatzfähig). Die Teamgesundheit im passiven Einkommen (`GameClockService.teamHealthOf`, § 8) liest zwar `status`, aber der Zustand heilt **nie automatisch** – die Zufriedenheit bleibt dauerhaft schlecht, außer der Spieler klickt sich manuell „gesund“.

## Aktueller Stand

**Bereits vorhanden (Bausteine für V3):**

- `CharacterStatus` mit `severity` 0–7 (`object_apprentice.dart:10–23`); Reihenfolge `ready`, `reeling`, `hurt`, `afraid`, `injured`, `dying`, `dead`, `overkilled`.
- `GameClockService` (`lib/services/game_clock_service.dart`): `elapsed`, `weeksElapsed`, `nextWeeklyTick`, idempotenter wöchentlicher `catchUp(RestaurantData, now)` sowie `_severityByStatus` und `teamHealthOf()` (liest `status`).
- `MedicQuality.healTimePerStage` (6 h / 3 h / 1 h), `effectiveHealTime` (wird mit V3 ersatzlos entfernt, siehe § 2), `effectiveSurvivalBonus` in `ObjectTeamMedic`.
- `EconomyBalance` (`lib/services/economy_balance.dart`) mit Rettungswurf-Konstanten (`survivalBase`, `survivalPerLevel`, `survivalDefenseThreshold`, `survivalPerDefenseOverThreshold`, `survivalOverkillPenalty`) und `revivalCost = 200`.
- Persistenz: `StaffData`/`RestaurantData` serialisieren bereits `status`, `woundValue` und `lastSeenAt` (`lib/models/profile_data.dart`).
- UI: `ScreenCharacterDetail._buildMedicActions()` (Button „Behandeln“; der frühere Button „Notfall-Spritze“ entfällt mit V3 – die Spritze wird automatisch verabreicht), `ScreenRestaurant` mit Status-Farben/-Texten.
- `_performSurvivalRolls()` inkl. Teamarzt-Bonus und 200 €-Wiederbelebung.

**Fehlt (Kern von V3):**

- Echtzeit-Heilung (Tagestick/Intervalltick) und ein Catch-up für das **Personal** (nicht nur für die Wirtschaft).
- Persistente Verletzungs-Zeitstempel (`injuryStartedAt`) und Spritzen-Suppression.
- Ableitung von `woundValue` aus `status` beim Gefechtsstart.
- Behandlung von `afraid` in der Heilungskette.
- Regelwerk-Angleich (`team_rules.md` § 4.3 / § 4.4 / § 4.5).

---

## Lösungsansatz

### Ziel (fixierte Entscheidung)

`status` ist die **einzige Quelle der Wahrheit**. Heilung läuft in **Echtzeit** (ohne Arzt 1 Stufe/Tag, mit Arzt `healTimePerStage`), verpasste Zeit wird per Catch-up nachgeholt; die Kette umfasst auch `afraid`. Die Notfall-Spritze wird **automatisch** beim Verletzungsbeginn verabreicht, schiebt den Schaden **temporär** auf und fällt nach 24 h zurück. `woundValue` wird beim Gefechtsstart aus `status` abgeleitet und ist **kein** persistenter Management-Zustand mehr.

### 0. Architektur-Leitlinie (Best Practices)

- **Heilungslogik raus aus Singleton/`ObjectTeamMedic`** – reine, testbare Funktionen analog zu `EconomyService` (löst das notierte Testability-Problem).
- **Injizierte Zeit:** kein `DateTime.now()` tief in der Logik; `GameClockService` bekommt `now` als Parameter → deterministischer Catch-up.
- **Idempotenter Catch-up:** wiederholtes Anwenden des Ticks darf nicht doppelt heilen – der Fortschritt wird bei jedem Aufruf aus `injuryStartedAt` + `now` neu berechnet.
- **Eine Quelle der Wahrheit (V7):** neue Zeit-/Balance-Werte leben in `EconomyBalance`, keine Literale im Fluss.

### 1. `woundValue` aus `status` ableiten (Kampf-Eintritt)

- `status` → `severity` (bereits am Enum vorhanden).
- Beim Gefechtsstart (`ObjectProfile.selectTeamForBattle`, `lib/objects/object_profile.dart:206–221`) für jede gewählte Einheit:
  `woundValue = max(1, maxWoundValue − severity)`.
- Mapping: `ready` → 3, `reeling` → 2, `hurt`/`afraid`/`injured` → 1. `dying` bleibt vom Gefecht ausgeschlossen.
- `maxWoundValue` als Konstante in `EconomyBalance` (Default 3, justierbar).
- Nach dem Gefecht wird **nur** `status` gepflegt (Rettungswurf/Tod); `woundValue` ist danach irrelevant und wird beim nächsten Gefechtsstart neu gesetzt.
- Folge: weder `treatCharacter()` noch die Spritzen-Verabreichung fassen `woundValue` noch an – die doppelte Buchführung entfällt.

### 2. Echtzeit-Heilung im `GameClockService`

- **Neue API (reine Funktionen):**
  - `Duration hoursElapsed(DateTime lastSeenAt, DateTime now)` (analog `weeksElapsed`).
  - `Duration healTimePerStageFor({MedicQuality? quality})` → `quality?.healTimePerStage ?? healBasePerStage`.
  - `CharacterStatus healedStatus(CharacterStatus current, Duration elapsed, Duration perStage)` – reine Vorwärtsrechnung (bis maximal `ready`), Reihenfolge wie § 4.3 (`dying → injured → hurt → afraid → reeling → ready`).
  - `HealingTickResult advanceHealing(RestaurantData restaurant, DateTime now)` – wendet die Heilung auf `restaurant.staff` an; wird vom bestehenden `catchUp` mit aufgerufen.
- **Datenmodell:** `StaffData` erhält `DateTime? injuryStartedAt` (Beginn der aktuellen Verletzung). Beim Speichern serialisieren. **Migration (Entscheidung):** Alt-Spielstände ohne `injuryStartedAt` erben `injuryStartedAt = restaurant.lastSeenAt` (Fallback: `now`, falls `lastSeenAt` fehlt) – d. h. **rückwirkende Heilung ab `lastSeenAt`**.
- **Deterministische Heilzeit:** `effectiveHealTime` (Fuzzy-Modifier) wird **vollständig aus der Zeitrechnung genommen** und ersatzlos entfernt; es wird **nichts eingefroren**. Die Pro-Stufe-Zeit ist ausschließlich `healTimePerStage` des aktuell angestellten Arztes (6 h / 3 h / 1 h) bzw. `healBasePerStage` (24 h) ohne Arzt. Der Fortschritt wird bei jedem Catch-up idempotent aus `injuryStartedAt` + `now` **neu berechnet** (`Stufen = floor(elapsed / perStage)`), nie fortgeschrieben – ein Arztwechsel wirkt damit deterministisch auf die Restlaufzeit.
- **Catch-up:** derselbe Aufrufpunkt wie der Wochentick (App-Start/Login, `AppLifecycleState.resumed`, Restaurant-Wechsel) sowie direkt nach `syncUnitsAfterBattle` – neue Verletzungen starten dort ihre Uhr.
- **Konsistenz-Hinweis:** Die Heilungsreihenfolge ist die **einzige Ordnung**. `afraid` liegt zwischen `hurt` und `reeling`, obwohl seine Integer-`severity` (3) über `hurt` (2) liegt. Vergleiche („schwererer Status“, siehe § 3) müssen daher die **Kettenposition** nutzen, nicht `severity`.

### 3. Notfall-Spritze: automatische Verabreichung + Rückfall nach 24 h

- `StaffData` erhält `DateTime? emergencyShotAt` und `String? suppressedStatus` (Status **vor** der Spritze).
- **Keine manuelle UI-Aktion mehr** (Entscheidung: „nur noch Tick“): Der frühere Button entfällt. Die Spritze wird **automatisch direkt beim Verletzungsbeginn** verabreicht – im Post-Gefecht-Pfad unmittelbar nach `_performSurvivalRolls()`/`syncUnitsAfterBattle()` an jeden Charakter, der als `dying` aus dem Gefecht kommt (sofern ein Teamarzt angestellt ist). Sie setzt `suppressedStatus = status` (i. d. R. `dying`), `emergencyShotAt = now`, `status = ready`; die Kosten (`EconomyBalance.emergencyShotCost`, neu) werden vom Budget abgebucht (heute: 0 €).
- **Rückfall (Tick):** Ist `now − emergencyShotAt ≥ 24 h`, wird `status` auf den **schwereren** von (unterdrücktem Status, zwischenzeitlich erlittenem Status) gesetzt und die Marker werden gelöscht. Der Vergleich erfolgt über die **Kettenposition** (§ 2), da `max(severity)` wegen `afraid` falsch sortieren würde.
- Die normale Heilung (Abschnitt 2) läuft während der Wirkungsdauer weiter, kann den Rückfall aber nicht abfangen (§ 4.5).
- Der Rückfall zählt als **neuer Verletzungsbeginn**: `injuryStartedAt = now` für die weitere Heilung.
- Der Ablauf ist **idempotent**: Ein zweiter Catch-up mit demselben `now` verabreicht/entlässt keine weitere Spritze.

### 4. `afraid` als Teil der Heilungskette (Entscheidung)

- `afraid` **persistiert** und ist Teil der Heilungskette (Entscheidung gegen die reine Gefechts-Kurzzeit-Variante). Entstehung: im Gefecht (`team_rules.md` § 4.4).
- Kettenposition: `hurt → afraid → reeling`; die vollständige Kette lautet `dying → injured → hurt → afraid → reeling → ready`.
- Damit entfällt der `default`-Deadlock in `treatCharacter()` – `afraid` erhält einen expliziten Zweig und wird regulär eine Stufe weitergeheilt.
- `team_rules.md` § 4.3 wird um `afraid` in der Kette ergänzt; § 4.4 beschreibt `afraid` weiterhin als Gefechtsmalus, nun aber **heilbar**.

### 5. `treatCharacter()` umstellen

- Die heutige Sofort-Heilung per Klick entfällt zugunsten des Echtzeit-Prozesses. `treatCharacter()` stößt nur noch an: setzt `injuryStartedAt` (falls nicht gesetzt) und würfelt Hilfsbereitschaft/Behandlungsqualität; die eigentliche Stufenheilung (inkl. `afraid`-Zweig, Kette `dying → injured → hurt → afraid → reeling → ready`) macht der Tick.
- `ObjectTeamMedic` bleibt für Würfe/Boni und den Rettungswurf; die Zustandsübergänge wandern in den Service.
- `emergencyShot()` entfällt als eigenständige/öffentliche Medik-Methode; die automatische Verabreichung ist eine Service-Funktion im Post-Gefecht-Pfad (§ 3).
- Der `woundValue`-Zugriff entfällt überall (siehe Abschnitt 1).

### 6. Verdrahtung (Aufrufer)

- **App-Start / Restaurant-Wechsel:** `GameClockService.catchUp()` ruft intern `advanceHealing()` (Heilung) und den Spritzen-Rückfall auf, **bevor** `lastSeenAt = now` geschrieben wird. Reihenfolge innerhalb des Catch-up: Heilung → Spritzen-Rückfall → bestehende Wirtschafts-Schritte (passiv → Arzt → Unterhalt → Zinsen → Bankrott).
- **Nach Gefecht:** `screen_battle_result._computeAndApplyResults()` → `syncUnitsAfterBattle()` → `_performSurvivalRolls()` setzt für Neuverletzte `injuryStartedAt = now` (statt heute nur `woundValue = 1`, Z. 276–277 / 286–287). **Unmittelbar danach** erhält jeder `dying`-Charakter automatisch die Notfall-Spritze (§ 3), **bevor** `saveToStorage()` läuft.
- **UI:**
  - `ScreenCharacterDetail`/`ScreenRestaurant`: Countdown „Heilung fertig in …“ aus `healTimePerStage − elapsed`; Status-Fortschritt visualisieren.
  - Spritzen-Restzeit anzeigen („Rückfall in …“); der manuelle „Notfall-Spritze“-Button entfällt.
- **Neue l10n-Strings** in `lib/l10n/app_de.arb` / `app_en.arb`.

### 7. Tests & Regelwerk

- `test/healing_service_test.dart`: 0 h, genau `perStage`, volle Kette `dying → injured → hurt → afraid → reeling → ready` (5 Stufen), 30 Tage; **Idempotenz** (zweiter Aufruf heilt nicht doppelt); `ready`-Clamp; ohne Arzt 24 h/Stufe; **Determinismus** (kein Fuzzy-Einfluss). **Migrationstest:** Alt-Spielstand ohne `injuryStartedAt` heilt rückwirkend ab `lastSeenAt`.
- `test/emergency_shot_test.dart`: automatische Verabreichung nach dem Rettungswurf für `dying` (kein manueller Aufruf); Rückfall nach < 24 h (keiner), ≥ 24 h (Status kehrt zurück); schwererer zwischenzeitlicher Status gewinnt gemäß **Kettenposition** (`afraid` vs. `hurt`); Kosten werden gebucht; Idempotenz.
- `test/game_clock_service_test.dart` um `hoursElapsed`/`advanceHealing` erweitern.
- `team_rules.md` angleichen: § 4.3 (Kette inkl. `afraid`, Zeit pro Stufe → `MedicQuality.healTimePerStage` bzw. 24 h), § 4.4 (`afraid` heilt jetzt), § 4.5 (Spritze = automatisch nach dem Gefecht, Rückfall + Kosten).

### Phasen (Umsetzungsreihenfolge)

1. **Datenmodell:** `StaffData`-Felder (`injuryStartedAt`, `emergencyShotAt`, `suppressedStatus`) + Migration (`injuryStartedAt = restaurant.lastSeenAt`, rückwirkende Heilung).
2. **`GameClockService`-Erweiterung:** `hoursElapsed`, `healTimePerStageFor`, `healedStatus` (Kette inkl. `afraid`), `advanceHealing` + Unit-Tests (injizierte Zeit).
3. **Notfall-Spritze:** automatische Verabreichung nach dem Rettungswurf, Suppression, Rückfall, Kosten; `emergencyShot()`/Button entfernen.
4. **`woundValue`-Ableitung** beim Gefechtsstart + `treatCharacter()`-Umstellung.
5. **UI/l10n** (Countdowns) + `team_rules.md`-Abgleich.
6. **Absicherung:** `flutter analyze` ohne neue Fehler/Warnungen, `flutter test` vollständig grün.

## Abnahmekriterien

- [x] Ein `ready`-Charakter startet das Gefecht mit vollem `woundValue`; „ready“ bedeutet wieder **volle Einsatzfähigkeit**.
- [x] Nach mehreren Tagen ohne App-Start sind alle Heilungsfortschritte korrekt nachgeholt, angezeigt und gespeichert (Heilzeit deterministisch, kein Fuzzy-Einfluss).
- [x] Die Notfall-Spritze wird **automatisch** beim Verletzungsbeginn verabreicht (kein manueller Button) und fällt nach **1 Echtzeit-Tag** zuverlässig (und idempotent) zurück; der Rückfall-Schaden ist nicht umgehbar.
- [x] `afraid` ist Teil der Heilungskette (`hurt → afraid → reeling → ready`) – kein Charakter bleibt unheilbar.
- [x] Alt-Spielstände ohne `injuryStartedAt` heilen rückwirkend ab `restaurant.lastSeenAt`.
- [x] Alle Zeit-/Balance-Werte stehen in `EconomyBalance`; keine neuen Literale im Fluss.
- [x] `flutter analyze` ohne neue Fehler/Warnungen, `flutter test` vollständig grün.

## Nachtrag: Erledigte Restpunkte

Die nach dem Durchlauf offenen Punkte sind abgearbeitet:

### Datenmodell & Migration
- `StaffData`/`ObjectApprentice` tragen jetzt `injuryStartedAt`, `injuryStartStatus`, `emergencyShotAt` und `suppressedStatus`; alle Felder werden serialisiert (abwärtskompatibel, fehlende Keys → `null`).
- Migration: Alt-Stände ohne `injuryStartedAt` erben beim ersten Catch-up `injuryStartedAt = restaurant.lastSeenAt` (Fallback `now`) und heilen dadurch rückwirkend.
- **Ergänzung zum Dokument:** Für die geforderte Idempotenz („Stufen = floor(elapsed/perStage), nie fortgeschrieben“) wird zusätzlich der **Ausgangsstatus** der Verletzung (`injuryStartStatus`) fixiert. Ohne ihn würde jeder weitere Tick von der bereits geheilten Stufe aus erneut heilen.

### Zeitsystem & Heilung (`GameClockService`)
- Neue reine Funktionen: `hoursElapsed`, `healTimePerStageFor`, `healedStatus` (Kette `dying → injured → hurt → afraid → reeling → ready`), `heavierByChain` (Kettenposition statt `severity`), `woundValueFor`, `healingStepsToReady`, `remainingHealingTime`, `remainingShotTime`, `advanceHealing`, `rollBackEmergencyShots`.
- `catchUp` heilt und nimmt Spritzen **immer** zurück – auch bei `weeks == 0` (Umbau des früheren Early-Returns); danach folgt der bestehende Wochen-Tick.
- Heiltempo verwendet den **besten** angestellten Arzt (deterministisch) bzw. `EconomyBalance.healBasePerStage` (24 h); `effectiveHealTime` (Fuzzy) wurde entfernt.

### Notfall-Spritze
- Kein manueller Button mehr (`ScreenRestaurant`, `ScreenCharacterDetail`); `ObjectTeamMedic.emergencyShot()` wurde entfernt.
- Automatische Verabreichung unmittelbar nach dem Rettungswurf für jeden `dying`-Charakter (Teamarzt + Budget vorausgesetzt), Kosten `EconomyBalance.emergencyShotCost` werden gebucht.
- Rückfall nach `EconomyBalance.emergencyShotDuration` (24 h) im Tick; es gewinnt der schwerere Status gemäß Kettenposition (`hurt` > `afraid`); der Rückfall zählt als neuer Verletzungsbeginn.

### Eine Quelle der Wahrheit
- `selectTeamForBattle` leitet `woundValue` aus dem Status ab (`max(1, maxWoundValue − severity)`); `_performSurvivalRolls` und `treatCharacter` fassen `woundValue` nicht mehr an – sie pflegen nur noch `status`/`injuryStartedAt`.
- `treatCharacter` heilt keine Stufen mehr, sondern startet die Verletzungsuhr (nach Hilfsbereitschafts-/Qualitätswurf).
- UI (Personal-Liste + Detailansicht) zeigt abgeleitete LP sowie Heil-/Rückfall-Countdowns; neue l10n-Strings `healCountdown`, `shotCountdown`, `healingComplete`.

### Validierung
- `dart analyze lib test`: keine neuen Fehler/Warnungen (nur die bereits vorher bestehenden 20 `info`-Lints).
- `flutter test`: **196 Tests grün**, inkl. neu `test/healing_service_test.dart` und `test/emergency_shot_test.dart` sowie erweiterter `test/game_clock_service_test.dart`, `test/profile_data_test.dart` und `test/balance_sanity_test.dart`.

### Balance-Tuning (V7)
- Neue Werte zentral in `EconomyBalance`: `maxWoundValue = 3`, `healBasePerStage = 24 h`, `emergencyShotCost = 0 €` (justierbar), `emergencyShotDuration = 24 h`; abgesichert durch `balance_sanity_test.dart`.





