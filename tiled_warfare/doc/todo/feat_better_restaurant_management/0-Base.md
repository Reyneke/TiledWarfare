# Basis

In diesem Sprint soll es um eine Verbesserung des Restaurantmanagements gehen – hauptsächlich, weil es sich im Moment **noch nicht richtig anfühlt**.

Kurz zusammengefasst: Es gibt bereits viele Bausteine (Profile, Restaurants, Personal, Teamärzte, Budget, Rettungswürfe, XP), aber **keine schließende Wirtschaftsschleife**, dazu doppelte Zustände und einige halbfertige Features. Dadurch wirkt das Management wie eine Ansammlung einzelner Menüs statt wie ein zusammenhängendes System.

> Grundlage dieser Analyse sind der Ist-Code unter `lib/screens/`, `lib/objects/`, `lib/services/` sowie das Regelwerk `doc/rules/team_rules.md`.

> **Ausrichtung (fixiert):** Mehrere Restaurants pro Profil als **unabhängige Spielstände**; Zeit läuft in **Echtzeit im Stile alter Browsergames** (mit Catch-up nach Auszeit der App); Teamarzt-Bezahlung **nur wöchentlich**. Details: Abschnitt „Entscheidungen (getroffen)“ sowie V1–V3 und V8.

---

## Aktueller Stand

### 1. Start: Profile & Restaurants

**Dateien:** `lib/screens/screen_start.dart`, `lib/services/profile_storage.dart`, `lib/models/profile_data.dart`

- Profile werden als JSON in `profiles/index.json` plus `profiles/<id>/profile.json` gehalten (`ProfileStorage`).
- Ein Profil kann laut Datenmodell **mehrere Restaurants** besitzen (`ProfileData.restaurants` ist eine Liste). `ScreenStart` bietet dafür „Neues Restaurant“, eine Auswahlliste und Löschen (`addRestaurantToProfile` / `removeRestaurantFromProfile`).
- Beim Login (`_login()`) wird das Profil in das Singleton geladen und `ScreenRestaurant` geöffnet – die **ausgewählte Restaurant-Auswahl wird nicht durchgereicht** (nur visuelle Markierung in `_buildRestaurantList`).

### 2. Restaurant-Dach

**Datei:** `lib/objects/object_profile.dart`

- `ObjectProfile` ist ein **Singleton** (Klassen-Kommentar: „nur ein Restaurant pro Spieler“) und hält Profil-ID, Name, `restaurantName`, Budget (Start `startBudget` = 10.000 €, Negativgrenze `negativeLimit` = −20.000 €) sowie Profilbild-/Logo-Pfad.
- Logo-Upload (`_pickImage`), Umbenennen und Budget-Anzeige passieren im `ScreenRestaurant`.

### 3. Team / Personal

**Dateien:** `lib/screens/screen_restaurant.dart`, `lib/screens/screen_character_detail.dart`

- Personal-Liste mit Sortierung, Status-Farben/-Texten und einer **Checkbox pro Charakter** für den Gefechts-Kader (`_battleReadyCharacters`).
- **Lehrling anheuern** (`hireApprentice`, 100 €), **Charakter entlassen** (`fireCharacter`, keine Rückerstattung) – beide mit Bestätigung/Snackbar in `ScreenRestaurant`.
- `upgradeToLineCook` (Lehrling → Line Cook, 500 €, ab Level 5) existiert in `ObjectProfile`, hat aber **keinen Aufrufer in der UI**.
- Detailansicht `ScreenCharacterDetail`: XP-Balken, Match-Historie, Arzt-Aktionen (Behandeln / Notfall-Spritze).

### 4. Teamärzte

**Dateien:** `lib/screens/screen_hire_and_fire.dart`, `lib/objects/object_team_medic.dart`

- `ScreenHireAndFire` zeigt einen Pool von 15 zufälligen Teamärzten (Qualität niedrig/mittel/hoch, Enneagramm, Fuzzy-Persönlichkeit) mit anheuern/entlassen und Pool neu generieren.
- `ObjectTeamMedic` berechnet `costPerWeek` aus Qualität und Teamgröße. Der Betrag wird **angezeigt und serialisiert, aber nie vom Budget abgebucht** (`hireMedic`/`fireMedic` in `ObjectProfile` verändern das Budget nicht).
- `treatCharacter` und `emergencyShot` bilden die Heilung ab; die Fuzzy-Variablen/`ruleBase` werden initialisiert.

### 5. Gefecht & Nachbereitung

**Dateien:** `lib/screens/screen_battle_result.dart`, `lib/widgets/widget_caretaker.dart`, `lib/screens/screen_main.dart`

- `selectTeamForBattle` filtert `dying`-Charaktere, füllt `player.unitList` und sichert den vollen Schlachtzug in `battleRoster`.
- Nach dem Gefecht: XP-Vergabe (`earnXP`), `syncUnitsAfterBattle` → `_performSurvivalRolls` (W100-Rettungswurf inkl. Teamarzt-Bonus und Wiederbelebung gegen 200 €), danach `saveToStorage()`.

*Hinweis:* Dieser Ist-Zustand beschreibt **ein** aktives Restaurant pro Profil. Durch V1 wandert der Spielzustand (Budget, Team, Ärzte, Historie) auf die **Restaurant-Ebene**, sodass mehrere Restaurants als unabhängige Spielstände geführt werden.

---

## Probleme

### 🔴 P1 – Mehrere Restaurants: Auswahl geht verloren (bis zu Datenverlust)

**Symptom:** Der Spieler kann in `ScreenStart` mehrere Restaurants pro Profil anlegen und auswählen, spielt dann aber immer im „ersten“ Restaurant weiter.

**Ursache:**
- `ObjectProfile.loadFromData()` übernimmt nur `data.restaurants.first` (Name + Logo).
- `_login()` in `screen_start.dart` ruft `loadFromData(freshProfile)` auf und übergibt den ausgewählten `_selectedRestaurant` **nicht**.
- `ObjectProfile.toProfileData()` schreibt beim Speichern wieder nur eine Liste mit genau diesem einen Restaurant.

**Auswirkung (Datenverlust):** `saveProfile()` ersetzt den Index-Eintrag komplett. Sobald der Spieler nach dem Anlegen eines zweiten Restaurants irgendetwas speichert (z. B. Personal anheuern), werden alle weiteren Restaurants des Profils **stillschweigend gelöscht**. Datenmodell/Storage/UI unterstützen Mehrfach-Restaurants, die Spielregel (§ 2.1, § 6.3) und der Singleton aber nur eins – ein Widerspruch, der entschieden werden muss.

### 🟠 P2 – Keine Wirtschaftsschleife (Kern des „fühlt sich nicht richtig an“)

**Symptom:** Das Budget verändert sich nur durch einmalige Anheuerungen (Lehrling) und einmalige Wiederbelebungen. Es gibt **keinen laufenden Geldkreislauf**.

**Ursache (Belege):**
- `costPerWeek` der Teamärzte wird weder beim Anheuern noch wöchentlich abgebucht – `ObjectProfile.hireMedic()`/`fireMedic()` verändern kein Geld.
- `applyNegativeInterest()` (Negativzinsen, 10 %) und `isBankrupt` existieren in `object_profile.dart`, haben aber **keinen Aufrufer** in der UI-/Service-Schicht.
- `ObjectProfile.reset()` (Neustart nach Permadeath) hat ebenfalls **keinen Aufrufer** – ein Bankrott ist aktuell nicht erlebbar und nicht auflösbar.

**Auswirkung:** Wöchentliche Kosten, Negativzinsen, Einnahmen und die „Angst“ vor der Negativgrenze fehlen komplett. Das Management hat keinen Druck und keine Belohnung – exakt das Gefühl, das dieser Sprint beheben will.

### 🟠 P3 – Heilung inkonsistent & kein Zeit-System

**Symptom:** Ein behandelter Charakter ist „ready“, wirkt aber im nächsten Gefecht extrem zerbrechlich; die „temporäre“ Notfall-Spritze ist in Wahrheit permanent.

**Ursache (Belege):**
- `_performSurvivalRolls()` (`object_profile.dart`) setzt Gerettete auf `woundValue = 1` und `status = dying`.
- `ObjectTeamMedic.treatCharacter()` heilt **nur den `status`** (dying → injured → hurt → reeling → ready), lässt `woundValue` aber unverändert auf 1. Ein „ready“-Charakter startet dadurch mit fast leerer Lebensenergie.
- `emergencyShot()` setzt `woundValue = 1` und `status = ready`; der nach einem Echtzeit-Tag zurückkehrende Schaden (team_rules.md § 4.5) sowie die Heilung „1 Stufe pro Echtzeitstunde/-tag“ benötigen ein **Timer-/Event-System**, das nicht existiert (der Code-Kommentar weist selbst darauf hin: „…muss durch einen Timer/ein Event-System außerhalb dieser Klasse behandelt werden“).
- Hinzu kommt die doppelte Buchführung: `woundValue` (Gefecht) und `status` (Management) werden unabhängig gepflegt und laufen auseinander.

**Auswirkung:** Heilung wirkt kaputt oder unfair; der Zeitfaktor aus den Regeln ist nicht umgesetzt.

### 🟡 P4 – Doppelter Zustand für Bild/Logo

**Symptom:** Logo-Pfad und „benutzerdefiniertes Bild“ werden an mehreren Stellen gepflegt und laufen auseinander.

**Ursache (Belege):**
- `_ScreenRestaurantState` hält eigene Felder `_profileImagePath` und `_hasCustomImage` (`screen_restaurant.dart`) zusätzlich zu `ObjectProfile.restaurantLogoPath`/`hasCustomImage`.
- Beim Laden wird `hasCustomImage` aus dem **Profilbild** (`data.profileImagePath != null`) abgeleitet, nicht aus dem Restaurant-Logo.
- `ObjectProfile.reset()` setzt `restaurantLogoPath`/`hasCustomImage` **nicht** zurück (nur `profileImagePath`/`hasCustomImage` bzw. gar nicht konsistent).

**Auswirkung:** Nach Logout/Login oder Reset können Anzeige und gespeicherter Zustand divergieren (z. B. falsches Standardbild oder Alt-Zustand nach Neustart).

### 🟡 P5 – Halbfertige / tote Features

**Symptom:** Es existiert Code, der nie erreichbar ist oder seine dokumentierte Wirkung nicht entfaltet.

**Ursache (Belege):**
- `ObjectProfile.upgradeToLineCook()` (Lehrling → Line Cook, 500 €, ab Level 5) hat **keinen UI-Aufrufer**. Würde er genutzt, verliert er zudem die Charakter-Identität: Es wird ein frisches `ObjectLineCook()` erzeugt und nur Level/XP/Wunde kopiert – Name, Bild, `status` und Match-Historie gingen verloren.
- Die Fuzzy-Variablen/`ruleBase` in `ObjectTeamMedic` werden initialisiert, aber `_evaluateHelpfulness()`/`_evaluateTreatmentQuality()` nutzen einfache Formeln statt der Fuzzy-Engine („Fuzzy-Deko“).
- `_evaluateHelpfulness()` kann Werte bis ~176 liefern (Doku verspricht 0–100), sodass der W100-Check bei starken Ärzten praktisch immer erfolgreich ist.

**Auswirkung:** Regelwerk-Versprechen (Fortbildung, Persönlichkeit wirkt auf Verhalten) sind im Spiel nicht erlebbar bzw. wirkungslos.

### 🟡 P6 – Persistenz-Schwächen

**Symptom:** Speicher-Fehler fallen kaum auf; redundante Dateien können sich widersprechen.

**Ursache (Belege):**
- `ProfileStorage.loadAllProfiles()` fängt alle Fehler ab und gibt bei Korruption **stillschweigend eine leere Liste** zurück (`profile_storage.dart`).
- Es gibt zwei Quellen (`index.json` und `profiles/<id>/profile.json`); `addRestaurantToProfile`/`removeRestaurantFromProfile` aktualisieren nur den Index, wodurch die Einzel-Datei veraltet (stale) bleibt.
- Der Index wird nicht-atomar per Read-Modify-Write beschrieben (kein Locking/Transaktion; konkurrierende Saves können Einträge verlieren).
- `_hireMedic()`/`_fireMedic()` in `screen_hire_and_fire.dart` rufen `saveToStorage()` **ohne await** auf (Fire-and-Forget, Fehler unhandled).

**Auswirkung:** Stille Datenverluste und schwer diagnostizierbare Zustände („Restaurant verschwindet“, „Änderung ist weg“).

### 🟡 P7 – Magische Zahlen im Wirtschaftsfluss

**Symptom:** Kosten/Boni/Strafen sind über den Code verstreut und nicht zentral justierbar.

**Ursache (Belege):** Lehrling 100 € (`hireApprentice`), Fortbildung 500 € (`upgradeToLineCook`), Wiederbelebung 200 € und W100-Zielwerte (50 + 10/Level + 5/Defense, −10 bei Overkill) in `_performSurvivalRolls()`, Teamarzt-Basis 500 € (`_computeWeeklyCost`), Zinssatz 10 % (`applyNegativeInterest`) – jeweils als Literale.

**Auswirkung:** Balance-Anpassungen erfordern Code-Eingriffe an verteilten Stellen; Gefahr von Inkonsistenzen zwischen Regeln und Code.

---

## Verbesserungen

> Jede Maßnahme nennt ein **Abnahmekriterium**, damit der Sprint überprüfbar abschließbar ist. V1–V4 haben die höchste Priorität.

### V1 (→ P1): Mehrere Restaurants als unabhängige Spielstände

**Entscheidung (getroffen):** Jedes Restaurant ist ein **eigener Spielstand** mit eigenem Budget, Personal, Teamärzten und Match-Historie. Der Spielzustand wandert von der Profil- auf die Restaurant-Ebene (siehe „Entscheidungen (getroffen)“). Konkret:

- **`RestaurantData`** wird zum Zustandsträger und erhält neue Felder: eine stabile `id` (z. B. CRC32 aus Name + Erstellzeitpunkt), `budget`, `staff`, `medics` und `lastSeenAt` (für das Echtzeit-System); `name` + `logoPath` bleiben.
- **`ProfileData`** reduziert sich auf Profil-Ebene: ID, Name, Erstelldatum, Profilbild. Die bisherigen `budget`/`staff`/`medics` werden nach `RestaurantData` **migriert** (Alt-Profile: der bisherige `restaurants.first` übernimmt die Felder; ID-Fallback für Alt-Daten festlegen).
- **`ObjectProfile`** (Singleton) hält künftig nur den Zustand des **aktiven Restaurants** (`activeRestaurantId`; `loadFromData(data, restaurantId)`). Beim Speichern werden die übrigen Restaurants **unverändert übernommen** (Merging statt Überschreiben der gesamten Liste).
- **`ScreenStart._login()`** reicht den ausgewählten `_selectedRestaurant` durch; optional ist ein Restaurant-Wechsel zwischen Spielständen direkt aus `ScreenRestaurant` (siehe „Offene Folgepunkte“).

**Abnahmekriterium:** Zwei angelegte Restaurants überleben Login + mehrere Speichervorgänge, sind unabhängig auswählbar, und Budget/Personal/Ärzte bleiben strikt getrennt – es gehen keine Daten verloren.

### V2 (→ P2): Wirtschaftsschleife schließen (Echtzeit, wöchentlich)

**Entscheidungen (getroffen):** Zeitangaben laufen in **Echtzeit** (Browsergame-Stil, verpasste Zeit wird beim App-Start nachgeholt); Teamarzt-Bezahlung erfolgt **nur wöchentlich** (kein Anschaffungspreis). Konkret:

- Teamarzt-Kosten (`costPerWeek`) real-wöchentlich über das Zeitsystem (V8) abbuchen; beim App-Start verpasste Wochen **nachholen** (Catch-up). Details zur anteiligen Abrechnung beim Anheuern (Tag-genau vs. nächster Tick) → „Offene Folgepunkte“ bzw. Folge-Dokument.
- `applyNegativeInterest()` nach jedem Gefecht aufrufen (z. B. in `screen_battle_result.dart`/`widget_caretaker.dart`) – Negativzinsen bleiben je Gefecht gemäß team_rules § 2.2.
- Bankrott-Flow: `isBankrupt` prüfen, Permadeath-Dialog zeigen; das aufgelöste Restaurant endet dauerhaft und der Spieler startet über `ObjectProfile.reset()` einen **neuen Spielstand** („Neues Restaurant“).

**Abnahmekriterium:** Negatives Budget erzeugt sichtbare Zinsen je Gefecht; die wöchentlichen Teamarzt-Kosten werden in Echtzeit (inkl. Nachholen nach Auszeit) abgebucht; bei Unterschreiten von −20.000 € erscheint der Auflösungs-Dialog und ein neuer Spielstand startet sauber.

### V3 (→ P3): Heilung & Zeit konsistent machen

- `treatCharacter()`/`emergencyShot()` müssen auch `woundValue` passend wiederherstellen – oder `woundValue` wird konsistent aus `status` abgeleitet (eine Quelle der Wahrheit).
- **Echtzeit-Heilung** über das Zeitsystem (V8): 1 Stufe pro Echtzeitstunde (gemäß team_rules § 4.3/4.5); beim App-Start werden verpasste Stunden nachgeholt (Catch-up).
- **Notfall-Spritze:** Rückfall nach 1 Echtzeit-Tag – wird beim Catch-up auf betroffene Charaktere angewendet (Schaden kehrt zurück, vgl. team_rules § 4.5).

**Abnahmekriterium:** Ein geheilter Charakter hat wieder volle Wundwerte; Heilung schreitet in Echtzeit fort (auch nach Auszeit der App); die Notfall-Spritze wirkt nur temporär (Schaden kehrt nach einem Tag zurück).

### V4 (→ P4): Zustand vereinheitlichen

- `ObjectProfile` als **einzige Quelle** für Logo/Bild (`restaurantLogoPath`, `hasCustomImage`) etablieren; die Widget-Kopien `_profileImagePath`/`_hasCustomImage` in `_ScreenRestaurantState` entfernen oder direkt vom Singleton ableiten.
- `hasCustomImage` beim Laden aus dem Logo (nicht aus dem Profilbild) ableiten.
- `ObjectProfile.reset()` vollständig machen (inkl. `restaurantLogoPath`/`hasCustomImage` und ausstehender Kosten/Timer).

**Abnahmekriterium:** Keine doppelten Bildpfad-Felder mehr; ein Reset hinterlässt keinen Alt-Zustand.

### V5 (→ P5): Halbfertige Features aktivieren oder entfernen

- `upgradeToLineCook` in der UI erreichbar machen (Kosten/Level-Anzeige) **und** die Charakter-Identität bewahren (Name, Bild, `status`, Match-Historie, Stat-Entwicklung statt neu gewürfelter Werte).
- Fuzzy-Engine tatsächlich in `_evaluateHelpfulness`/`_evaluateTreatmentQuality` nutzen oder entfernen; Scores auf 0–100 begrenzen (die Formel kann aktuell Werte bis ~176 erzeugen, sodass starke Ärzte immer „hilfsbereit“ sind).

**Abnahmekriterium:** Line-Cook-Aufstieg ist im UI erreichbar und erhält die Charakterhistorie; Medic-Werte sind plausibel begrenzt.

### V6 (→ P6): Persistenz härten

- Fehler in `loadAllProfiles()` nicht still verschlucken, sondern loggen/anzeigen (z. B. über den bestehenden `CrashLogger`) bzw. Recovery anbieten.
- `index.json` und `profiles/<id>/profile.json` konsistent halten (beide pflegen oder eine Datei als alleinige Quelle) und atomisch schreiben (tmp-Datei + rename).
- Alle Speicher-Futures awaited (`_hireMedic`/`_fireMedic` in `screen_hire_and_fire.dart` rufen `saveToStorage()` un-awaited auf).

**Abnahmekriterium:** Eine beschädigte Datei führt zu einer sichtbaren Fehlermeldung statt stiller leerer Liste; es entstehen keine stillen Datenverluste.

### V7 (→ P7): Wirtschaftswerte zentralisieren

- Startbudget, Negativgrenze, Kosten (Lehrling 100 / Fortbildung 500 / Wiederbelebung 200 / Teamarzt-Basis 500), Zinssatz (10 %) und W100-Zielwerte (50 ± Boni/Strafen) in eine Balance-Konfiguration bzw. benannte Konstanten auslagern.

**Abnahmekriterium:** Balance-Anpassungen sind ohne Änderungen in der UI-/Gefechts-Logik möglich; keine magischen Zahlen mehr im Fluss.

### V8 (→ V2/V3): Echtzeit-Zeitsystem mit Catch-up

**Hintergrund (Entscheidung):** Das Management läuft wie ein altes Browsergame – Zeitangaben (Woche/Stunde/Tag) sind **Echtzeit** und werden nachgeholt, wenn die App nicht lief. Dafür wird ein zentraler Dienst eingeführt.

- Neuer Service (z. B. `lib/services/game_clock_service.dart`): verwaltet `lastSeenAt` **je Restaurant** und berechnet beim App-Start bzw. beim Wechsel in den Spielstand die verpasste Zeit („Catch-up“).
- Das Zeitsystem stößt dann die fälligen Effekte an: wöchentliche Teamarzt-Kosten (V2) sowie Echtzeit-Heilung und Notfall-Spritzen-Rückfall (V3).
- Die UI zeigt Countdowns (nächste Abbuchung, „Heilung fertig“), damit die Wirtschaft sicht- und planbar ist.

**Abnahmekriterium:** Nach mehreren Tagen ohne App-Start werden beim nächsten Öffnen alle fälligen Wochen-Abbuchungen und Heilungsfortschritte korrekt nachgerechnet, angezeigt und gespeichert.

---

## Entscheidungen (getroffen)

> Die Grundsatzfragen sind entschieden. Damit sind V1–V3 und V8 eindeutig spezifiziert; die Punkte unter „Offene Folgepunkte“ bleiben als Implementierungsdetails offen.

1. **Mehrfach-Restaurant → mehrere Restaurants pro Profil als unabhängige Spielstände.** Jedes Restaurant ist ein eigener Zustand (eigenes Budget, Team, Teamärzte, Match-Historie); der Spielzustand wandert von der Profil- auf die Restaurant-Ebene (V1). Auch wenn team_rules.md (§ 2.1, § 6.3) bisher nur „ein Restaurant“ beschreibt, ist die Mehrfach-Variante die gewünschte Richtung – die Regeln sind entsprechend zu erweitern.
2. **Zeitmodell → Echtzeit im Stile alter Browsergames.** Zeitangaben (Woche/Stunde/Tag) sind real; verpasste Zeit wird beim nächsten App-Start nachgeholt („Catch-up“). Das ist die Grundlage des Zeitsystems (V8) und bestimmt V2 (wöchentliche Teamarzt-Kosten) und V3 (Heilung, Spritzen-Rückfall).
3. **Teamarzt-Bezahlung → wöchentlich.** Kein Anschaffungspreis beim Anheuern; `costPerWeek` wird real-wöchentlich abgebucht. Das Restaurantmanagement läuft damit cross-plattform wie ein Browsergame, bei dem das Gefecht nur ein Teil des Ganzen ist.

### Offene Folgepunkte (nicht blockierend)

- **Aufgelöste Restaurants:** Nach Permadeath bleibt das Restaurant wahlweise sichtbar und als „aufgelöst“ markiert (empfohlen, gibt dem Verlust Gewicht) oder wird gelöscht – im Folge-Dokument festlegen.
- **Anteilige Arzt-Abrechnung:** Beim Anheuern mitten in der Woche – Tag-genau anteilig oder erst beim nächsten Wochen-Tick abbuchen.
- **Restaurant-Wechsel im Spiel:** Optionaler Wechsel zwischen Spielständen direkt aus `ScreenRestaurant` heraus.
- **Merging beim Speichern:** Technik, wie `ObjectProfile.toProfileData()` die übrigen, nicht aktiven Restaurants unverändert zurückschreibt.
- **Regelwerk-Update:** `team_rules.md` auf „mehrere Restaurants als Spielstände“ und Echtzeit-Abrechnung anpassen.

---

## Nächste Schritte

1. Diese Basis als Ausgangspunkt nutzen – die Grundsatzentscheidungen sind getroffen und im Abschnitt „Entscheidungen (getroffen)“ fixiert.
2. Die Basis anschließend – analog zu `feat_metagame`/`feat_better_maps` – in Folge-Dokumente aufteilen (`1_Probleme.md`, `2_…md`), damit jedes Paket (V1–V8) eigenständig umsetz- und reviewbar ist.
3. Empfohlene Reihenfolge: zuerst das **Datenmodell** (Restaurant-IDs, Zustand auf Restaurant-Ebene, Migration – V1), dann das **Zeitsystem** (V8), darauf aufbauend Wirtschaft (V2) und Heilung (V3). V4–V7 (Zustandsbereinigung, tote Features, Persistenz, Konstanten) können parallel bzw. danach folgen.

