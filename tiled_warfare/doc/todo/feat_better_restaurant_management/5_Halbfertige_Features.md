# Halbfertige Features aktivieren oder entfernen (V5)

Dies ist die Ausarbeitung von **V5 (→ P5)** aus dem Basisdokument (`0-Base.md` – Abschnitt „Probleme“ → „🟡 P5 – Halbfertige / tote Features“ sowie „Verbesserungen“ → „V5 (→ P5)“).

Das Ziel ist fixiert: **Code, der nie erreichbar ist oder seine dokumentierte Wirkung nicht entfaltet, wird bewusst aktiviert oder entfernt.** Es soll kein „halb fertiger“ Zwischenzustand bestehen bleiben; pro Fund wird genau eine der beiden Optionen gewählt und umgesetzt.

Die Grundsatzentscheidungen sind fixiert und werden hier nicht neu verhandelt:

- Der Spielzustand liegt seit **V1** auf der **Restaurant-Ebene**; `ObjectProfile` ist ein Singleton für den **aktiven** Spielstand.
- **V2** hat die Wirtschaftsschleife geschlossen (Einnahmen, Wochen-Tick, Bankrott-Flow), **V3** hat Heilung/Zeit deterministisch und idempotent gemacht, **V4** hat den Bildzustand auf eine Quelle der Wahrheit reduziert. V5 baut darauf auf und räumt die verbliebenen Reste auf.
- **V7:** Balance-Werte stehen zentral in `EconomyBalance`; es gibt keine magischen Zahlen im Fluss.
- **`team_rules.md` § 4.3–4.5:** Heilzeit und Heilwirkung sind **deterministisch** und hängen allein von der Arzt-Qualität ab (kein Fuzzy-Einfluss).

> Grundlage dieser Analyse sind der Ist-Code unter `lib/` (Branch `feat-restaurant-management`) sowie das Regelwerk `doc/rules/team_rules.md`.

---

## Aktueller Stand

Ist-Zustand im Code (Branch `feat-restaurant-management`).

### Bereits aufgelöst (nicht mehr Gegenstand von V5)

Die prominentesten in `0-Base.md` unter P2/P5 genannten Punkte sind durch V1–V4/V7/V8 bereits verdrahtet und getestet. Sie dienen hier nur der Abgrenzung:

| Ehemals totes/ungesichertes Element | Heutiger Status (Beleg) |
|---|---|
| `ObjectProfile.applyNegativeInterest()` / `isBankrupt` | verdrahtet: je Gefecht in `ScreenBattleResult._computeAndApplyResults()` und je Woche in `GameClockService.catchUp()` |
| `ObjectProfile.reset()` (Permadeath) | verdrahtet über `ScreenRestaurant._checkBankruptcy()` |
| Teamarzt-Wochenkosten (`costPerWeek`) | verdrahtet: `ObjectProfile.hireMedic()` → `EconomyService.weeklyMedicCost()`, Abbuchung im Wochen-Tick |
| Gefechtsbelohnung (`ObjectToken.moneyValue`) | verdrahtet: `EconomyService.battleReward()` in `ScreenBattleResult` |
| Erweiterungen / Rebranding | verdrahtet: Reiter „Erweiterungen“ + `ObjectProfile.buyUpgrade` / `sellUpgrade` / `downgradeUpgrade` / `rebrandCuisine` |
| `hasCustomImage` (Singleton, toter Wert) | V4: abgeleiteter Getter `hasCustomImage` + `headerImagePath` in `ObjectProfile` |
| Toter Datenpunkt `statusBefore` (`_CharacterResult`) | entfernt (`screen_battle_result.dart`) |

### Verbliebene halbfertige Stellen (Gegenstand von V5)

Es bleiben **drei** zusammenhängende Reste. Gemeinsam ist ihnen: Der Code bzw. die UI ist vorhanden, aber die dokumentierte Wirkung fehlt.

**F1 – Fortbildung zum Line Cook: nicht erreichbar und identitätszerstörend.**

- `ObjectProfile.upgradeToLineCook()` (`object_profile.dart:179–213`) hat **keinen Aufrufer** in `lib/` und `test/`. Vorbereitet sind dagegen bereits: die Kosten (`EconomyBalance.upgradeToLineCookCost = 500`, `economy_balance.dart:22`), der l10n-String `rankLineCook` (definiert in `app_de.arb:331`, genutzt in `screen_character_detail.dart:93`) und die XP-/Level-Logik (`ObjectApprentice.earnXP`).
- Die Methode ersetzt den Lehrling durch ein **frisches** `ObjectLineCook(cuisine:)` und kopiert nur Level/XP/Wunde/Status/Verletzungsfelder (`:189–210`). **Name, Bild, Match-Historie und alle Statwerte** (`attackValue`, `defenseValue`, `movementValue`, `damageValue`, `rangeValue`, `moneyValue`, `xpValue`) gehen verloren bzw. werden auf die festen Line-Cook-Werte (`object_line_cook.dart:7–17`) zurückgesetzt.

**F2 – Fuzzy-„Persönlichkeit“ des Teamarztes: „Fuzzy-Deko“.**

- `ObjectTeamMedic` baut in `_initializeFuzzyRules()` ein Regelwerk auf und hält die Fuzzy-Variablen `helpfulness`/`treatmentQuality`. Eine repository-weite Suche nach `ruleBase.resolve(...)`, `helpfulness.assign(...)`, `treatmentQuality.assign(...)` und `createOutputPlaceholder()` findet jedoch **keine** Verwendung – die Engine wird nie ausgewertet.
- Die Bewertung läuft rein arithmetisch: `_evaluateHelpfulness()` = `50 + _enneagramScore(...) + quality.survivalBonus` (`object_team_medic.dart:262–264`). Mit 12 Enneagrammen (`object_host.dart:27–40`) liefert `_enneagramScore` (`:251–255`) Werte von 8…96, der Qualitätsbonus 10…30 → **68…176 statt der dokumentierten 0–100**. Der W100-Check in `treatCharacter()` (`:203–231`) kann bei einem starken Arzt praktisch nicht mehr fehlschlagen. Die Doku-Kommentare („0–42 Punkte“) sind veraltet.

**F3 – Toter Code und veraltete Kommentare.**

- `ObjectProfile.setPlayer()` und der Getter `player` (`object_profile.dart:105–114`) haben **keine Aufrufer**; das Gefecht greift direkt auf den `ObjectPlayer()`-Singleton zu.
- `ObjectPlayer.upgradeUnit()` (`object_player.dart:103–118`) – der einzige vorhandene Baustein für eine Stat-Entwicklung – hat **keine Aufrufer**.
- Kommentare versprechen nicht existierendes Verhalten: „0–42 Punkte“ in `_evaluateHelpfulness()`, eine Fuzzy-Mitwirkung im Klassenkommentar `ObjectTeamMedic` sowie „Basis-Bonus: +20“ an `effectiveSurvivalBonus` (tatsächlich qualitätsabhängig 10/20/30).

## Halbfertige Features im Detail

### F1 – Fortbildung zum Line Cook (`upgradeToLineCook`)

**Symptom:** Ein Lehrling kann Level 5+ erreichen – es passiert nichts. Es gibt keinen Weg, im Management einen Line Cook zu erhalten; Line Cooks entstehen ausschließlich während des Gefechts (`ObjectPlayer.spawnLineCook()`, aufgerufen in `widget_caretaker.dart:332`).

**Ursache (Belege):**

1. **Kein UI-Aufrufer.** `upgradeToLineCook` wird nirgends aufgerufen; es existiert weder Button noch Dialog noch Test. Die Methode „hängt“ damit vollständig in der Luft.
2. **Identitätsverlust.** Beim Ersetzen (`object_profile.dart:199–211`) werden nur Level/XP/Wunde/Status/Verletzungsdaten übernommen. Name und Bild werden neu erzeugt (`ObjectLineCook` → `"Line Cook: <neuer Zufallsname>"`, `object_line_cook.dart:8`), die Match-Historie wird **geleert**, und die Statwerte springen auf das feste Line-Cook-Profil. Aus einem benannten Charakter mit Historie wird ein beliebiger Fremder.
3. **Bezugsproblem im Gefechts-Kader.** `ScreenRestaurant` hält die Kader-Auswahl in einem `Set<ObjectApprentice>` (`screen_restaurant.dart:35`). Beim Ersetzen zeigt die Set-Referenz weiter auf den entfernten Lehrling (`:474`, `:591–608`); die Checkbox würde auf dem alten Objekt hängen bleiben. Auch `syncUnitsAfterBattle()` arbeitet mit Objektidentität.

**Auswirkung:** Die im Regelwerk (`team_rules.md` § 2.3) und in der XP-Kurve angelegte Progression „Lehrling → Line Cook“ ist faktisch abgeschaltet. Die Kosten von 500 € (`EconomyBalance.upgradeToLineCookCost`) bleiben balance-technisch unsichtbar. Der UI-Rang `rankLineCook` kann nur durch im Gefecht spontan erzeugte Line Cooks auftreten, die nie persistiert werden.

### F2 – Fuzzy-Persönlichkeit des Teamarztes („Fuzzy-Deko“)

**Symptom:** Das Enneagramm-Profil eines Teamarztes wirkt nur über eine lineare Formel; die aufwändige Fuzzy-Persönlichkeit beeinflusst nichts. Starke Ärzte sind beim Behandeln praktisch unfehlbar, unabhängig von der Persönlichkeit.

**Ursache (Belege):**

1. **Regelwerk ohne Auswertung.** `_initializeFuzzyRules()` sowie die Felder `helpfulness`, `treatmentQuality` und `ruleBase` werden initialisiert, aber nie mit Werten belegt bzw. ausgewertet (`ruleBase.resolve`, `...assign`, `createOutputPlaceholder` kommen im gesamten Repository nicht vor).
2. **Arithmetik statt Fuzzy.** `_evaluateHelpfulness()` / `_evaluateTreatmentQuality()` (`object_team_medic.dart:257–273`) berechnen stattdessen einfache Summen.
3. **Domänen-Überschreitung.** `_enneagramScore()` (`:251–255`) liefert `(index+1)*8 % 100` → 8…96; addiert mit Basis 50 und Qualitätsbonus 10…30 ergibt **68…176** (versprochen/kommentiert: 0–100). Die W100-Prüfungen in `treatCharacter()` (`:214`, `:220`) sind damit für starke Ärzte wirkungslos.

**Auswirkung:** Toter Code von ~45 Zeilen Regelwerk plus zwei ungenutzten `FuzzyVariable`-Klassen; die im Klassendokument behauptete Persönlichkeitssteuerung existiert nicht. Der überschießende Hilfsbereitschaftswert verzerrt das Balancing der Behandlung (fast immer erfolgreich), und die Doku weicht vom tatsächlichen Verhalten ab. Die Entfernung ist entschieden (siehe „Lösungsansätze“ → Schritt 3); die Persönlichkeits-Idee wird als späterer Personalsektor-Ausbau vorgemerkt.

### F3 – Toter Code und veraltete Kommentare

**Symptom:** Methoden ohne Aufrufer und Kommentare, die ein Verhalten behaupten, das es nicht (mehr) gibt.

**Ursache (Belege):**

1. `ObjectProfile.setPlayer()` + `player`-Getter (`object_profile.dart:105–114`) ohne Aufrufer.
2. `ObjectPlayer.upgradeUnit()` (`object_player.dart:103–118`) ohne Aufrufer – obwohl es der Baustein wäre, mit dem die Stat-Entwicklung (V5-Ziel zu F1) umgesetzt werden könnte.
3. Veraltete Kommentare: „0–42 Punkte“ (`object_team_medic.dart:260`), der Fuzzy-Klassenkommentar (`:72–76`) und „Basis-Bonus: +20“ an `effectiveSurvivalBonus` (`:237`).

**Auswirkung:** Irreführende Doku, toter Wartungsaufwand und erschwerte Reviewbarkeit – toter Code suggeriert Verhalten, das nicht stattfindet.

## Lösungsansätze

### Ziel (fixierte Entscheidung)

Jeder Fund wird eindeutig **aktiviert** oder **entfernt** – es bleibt kein halb fertiger Rest:

| Fund | Entscheidung | Begründung |
|---|---|---|
| F1 Fortbildung | **Aktivieren** | `team_rules.md` § 2.3, XP-Kurve, l10n-String und Kosten-Konstante sind vorhanden; es fehlen nur UI + Identitätserhalt. Entfernen würde Progression und Balance streichen. |
| F2 Fuzzy-Engine | **Entfernen** (entschieden) | Die bisherige Inkarnation passt nicht mehr zu den bereits umgesetzten Änderungen (V3: deterministische Heilung, automatische Notfall-Spritze); die Idee wird beim späteren Ausbau des Personalsektors in anderer Form wiedereingeführt (nicht blockierend, siehe „Anmerkungen“). |
| F3 toter Code | **Entfernen** | Kein Aufrufer, kein Mehrwert; Kommentare werden korrigiert. |

### Schritt 1 – F1 aktivieren: Identität bewahren (Refactoring)

1. `ObjectLineCook` bekommt einen optionalen `name`-Parameter (`object_line_cook.dart`), damit der Personenname erhalten bleibt:

```dart
ObjectLineCook({Zone? nameZone, Cuisine? cuisine, String? imagePath, String? name})
    : super(
        name: name ??
            "Line Cook: ${RandomNames(nameZone ?? cuisine?.zone ?? Zone.italy).fullName()}",
        imagePath: imagePath ?? cuisine?.tokenImagePath,
        attackValue: 80,
        defenseValue: 40,
        movementValue: 3,
        damageValue: 2,
        rangeValue: 3,
        moneyValue: 1000,
        xpValue: 100,
      );
```

2. `ObjectProfile.upgradeToLineCook()` gibt das **beförderte Objekt** zurück (`ObjectApprentice?` statt `bool`) und übernimmt Name, Bild und Match-Historie:

```dart
ObjectApprentice? upgradeToLineCook(ObjectApprentice apprentice,
    {int cost = EconomyBalance.upgradeToLineCookCost}) {
  if (apprentice.levelValue < 5) return null;
  if (budget - cost < negativeLimit) return null;
  budget -= cost;

  final lineCook = ObjectLineCook(
    cuisine: activeCuisine,
    // Personenname bleibt, nur der Rang-Präfix wechselt:
    name: apprentice.name.replaceFirst('Apprentice: ', 'Line Cook: '),
    imagePath: apprentice.imagePath,
  )
    ..levelValue = apprentice.levelValue
    ..currentXPValue = apprentice.currentXPValue
    ..woundValue = apprentice.woundValue
    ..status = apprentice.status
    ..injuryStartedAt = apprentice.injuryStartedAt
    ..injuryStartStatus = apprentice.injuryStartStatus
    ..emergencyShotAt = apprentice.emergencyShotAt
    ..suppressedStatus = apprentice.suppressedStatus
    ..matchHistory = List.of(apprentice.matchHistory);

  _personal
    ..remove(apprentice)
    ..add(lineCook);
  return lineCook;
}
```

> Hinweis: Die Statwerte wechseln bewusst auf das Line-Cook-Profil (Beförderung, keine Neuwürfelung). Eine echte **Stat-Entwicklung** pro Level (optional via `ObjectPlayer.upgradeUnit`) bleibt ein separater Folgepunkt.

### Schritt 2 – F1 aktivieren: UI & Kader-Fix-up

- Neuer Button in der Personal-Liste (`screen_restaurant.dart`, `_buildSortedPersonnelList`) und/oder in `screen_character_detail.dart` (Rang-Zeile).
- Sichtbar nur für `character is ObjectApprentice && character is! ObjectLineCook`; deaktiviert unter Level 5 bzw. bei zu geringem Budget (Tooltip).
- Bestätigungsdialog mit Kosten; nach Erfolg wandert der Kader-Haken mit:

```dart
final wasInSquad = _battleReadyCharacters.contains(character);
final promoted = _profile.upgradeToLineCook(character);
if (promoted != null) {
  setState(() {
    if (wasInSquad) {
      _battleReadyCharacters
        ..remove(character)
        ..add(promoted);
    }
  });
  await _saveState();
}
```

- Neue l10n-Strings in `app_de.arb` / `app_en.arb`: `promoteToLineCook`, `promoteConfirm(name, cost)`, `promoteLevelRequired`, `promoteNotEnoughBudget`, `promoteSuccess(name)`.

### Schritt 3 – F2 entfernen: Fuzzy-Engine streichen, Scores begrenzen

- `MedicHelpfulness`, `MedicTreatmentQuality`, die Felder `helpfulness`/`treatmentQuality`, `ruleBase` und `_initializeFuzzyRules()` entfernen; den nun ungenutzten `fuzzylogic`-Import bereinigen.
- Die Scores deterministisch und **innerhalb 0–100** halten, z. B.:

```dart
int _evaluateHelpfulness() =>
    (50 + _enneagramScore(enneagramProfile) + quality.survivalBonus)
        .clamp(0, 100);
```

  (Basis/Deckel können bei Bedarf als Konstanten nach `EconomyBalance` wandern – V7.)
- Kommentare und `toString` anpassen: Die Persönlichkeit steckt im Enneagramm-Profil, es findet keine Fuzzy-Auswertung statt.

> **Entscheidung (bestätigt):** Die Entfernung wird wie dargestellt umgesetzt. Die bisherigen Teamarzt-„Persönlichkeiten“ inkl. Fuzzy-Engine funktionieren **aufgrund der bereits gemachten Änderungen** (V3: deterministische Heilung, automatische Notfall-Spritze, Wegfall der manuellen Auslösung) in ihrer jetzigen Form nicht mehr. Die zugrunde liegende Idee wird dabei **nicht verworfen**: Beim späteren Ausbau des **Personalsektors** soll sie in **anderer Form** wiedereingeführt werden; die exakte Umsetzung wird derzeit noch besprochen und ist **nicht Teil von V5** (nicht blockierend, siehe „Anmerkungen“). Ein „Verdrahten“ der Engine **jetzt** bleibt verworfen: kein Gameplay-Mehrwert, Widerspruch zur in V3 festgeschriebenen deterministischen Heilung und zusätzliche Komplexität.

### Schritt 4 – F3 entfernen: toten Code löschen, Kommentare korrigieren

- `ObjectProfile.setPlayer()` und den Getter `player` entfernen – das Gefecht nutzt den `ObjectPlayer()`-Singleton ohnehin direkt.
- `ObjectPlayer.upgradeUnit()` **entweder** entfernen **oder** in Schritt 1 für die Stat-Entwicklung verdrahten (dann erhält es seinen Aufrufer).
- Kommentare korrigieren: „0–42 Punkte“, den Fuzzy-Klassenkommentar und „Basis-Bonus: +20“.

---

## Betroffene Dateien

| Datei | Änderung |
|---|---|
| `lib/objects/player_objects/object_line_cook.dart` | optionaler `name`-Parameter (Identity-Erhalt) |
| `lib/objects/object_profile.dart` | `upgradeToLineCook` → Rückgabe des beförderten Objekts, Identität/Historie übernehmen; `setPlayer`/`player` entfernen |
| `lib/screens/screen_restaurant.dart` | Fortbildungs-Button + Kader-Fix-up |
| `lib/screens/screen_character_detail.dart` | Fortbildungs-Aktion in der Rang-Zeile |
| `lib/objects/object_team_medic.dart` | Fuzzy-Engine/-Variablen entfernen; Scores auf 0–100 begrenzen; Kommentare |
| `lib/objects/object_player.dart` | `upgradeUnit` entfernen oder verdrahten |
| `lib/l10n/app_de.arb`, `lib/l10n/app_en.arb` | neue Promote-Strings |

## Umsetzungs-Phasen

1. **F2 entfernen** (entschieden, isoliert, risikoarm) + Kommentar-Korrekturen (F3, Teil 1).
2. **F1 aktivieren:** `ObjectLineCook.name`, `upgradeToLineCook`-Refactoring, Unit-Tests.
3. **F1 UI:** Button/Dialog in beiden Screens, Kader-Fix-up, l10n, Widget-Test.
4. **F3-Rest:** `setPlayer`/`player` entfernen, `upgradeUnit` entscheiden, Doku/`team_rules.md` abgleichen.

## Abnahmekriterium

- [x] Ein Lehrling ab Level 5 kann im Management zu einem Line Cook fortgebildet werden (Level-/Kostenanzeige, Bestätigung, Snackbar).
- [x] Nach der Fortbildung bleiben Name, Bild, Match-Historie, Status und Verletzungszustand erhalten; nur Rang und Statprofil wechseln.
- [x] Der Gefechts-Kader (`_battleReadyCharacters`) enthält nach der Fortbildung das neue Objekt, nicht das entfernte.
- [x] `upgradeToLineCook` schlägt unter Level 5 bzw. unter der Negativgrenze fehl (Deaktivierung/Fehlermeldung), ohne das Budget zu verändern.
- [x] `ObjectTeamMedic` enthält keine ungenutzte Fuzzy-Engine mehr; `_evaluateHelpfulness()`/`_evaluateTreatmentQuality()` liegen nachweislich in 0–100.
- [x] `ObjectProfile.setPlayer`/`player` und `ObjectPlayer.upgradeUnit` existieren nicht mehr **oder** haben belegte Aufrufer.
- [x] `flutter analyze` ohne neue Fehler/Warnungen; `flutter test` vollständig grün.

## Tests

- **`test/upgrade_line_cook_test.dart` (neu):** Level < 5 → `null`, Budget unverändert; Level ≥ 5 → Budget −500, Ergebnis ist `ObjectLineCook`, Name/Bild/Match-Historie identisch; Negativgrenze greift.
- **`test/object_team_medic_test.dart` (erweitern):** `_evaluateHelpfulness()`/`_evaluateTreatmentQuality()` bleiben über alle Enneagramme und Qualitäten in 0–100 (kein Überschießen mehr).
- **`test/screen_restaurant_test.dart` (erweitern):** Fortbildungs-Button nur ab Level 5 sichtbar; nach der Fortbildung wandert der Kader-Haken mit.
- **Grep-Absicherung:** `setPlayer`, `MedicHelpfulness`, `MedicTreatmentQuality` und `upgradeUnit` kommen nicht mehr vor; `ruleBase`/`createOutputPlaceholder` existieren nur noch für Host-KI und passives Einkommen (nicht mehr im `ObjectTeamMedic`).

## Nachtrag: Erledigte Restpunkte

V5 ist umgesetzt.

### F2 – Fuzzy-Engine entfernt (Phase 1)

- `MedicHelpfulness`, `MedicTreatmentQuality`, die Felder `helpfulness`/`treatmentQuality`/`ruleBase`, `_initializeFuzzyRules()` und der `fuzzylogic`-Import sind entfernt.
- Die Bewertung liegt jetzt in den reinen, testbaren Funktionen `ObjectTeamMedic.helpfulnessScoreFor()` / `treatmentQualityScoreFor()` und ist auf **0–100** begrenzt (vorher bis 176). Die privaten `_evaluateHelpfulness()`/`_evaluateTreatmentQuality()` delegieren dorthin.
- Kommentare/Doku angepasst (Klassenkommentar, „0–42 Punkte“, `effectiveSurvivalBonus`).

### F3 – Toter Code entfernt (Phase 2)

- `ObjectProfile.setPlayer()` und der Getter `player` sind entfernt; `ObjectPlayer.upgradeUnit()` ebenfalls (keine Aufrufer). Der interne `_player` bleibt bestehen.

### F1 – Fortbildung aktiviert (Phase 3)

- `ObjectLineCook` hat einen optionalen `name`-Parameter.
- `ObjectProfile.upgradeToLineCook()` gibt jetzt den neuen Line Cook (`ObjectApprentice?`) zurück und bewahrt Name (nur Rang-Präfix), Bild, Match-Historie sowie Fortschritt/Verletzungszustand.
- `ScreenRestaurant` bietet einen Fortbildungs-Button für Lehrlinge mit Bestätigungsdialog, Level-/Budget-Fehlermeldungen und Kader-Mitnahme (`_battleReadyCharacters`).
- Neue l10n-Strings (`promoteToLineCook`, `promoteLevelRequired`, `promoteConfirm`, `promoteNotEnoughBudget`, `promoteSuccess`) in DE/EN.

### Tests & Validierung

- Neu: `test/upgrade_line_cook_test.dart` (Level-Gate, Identität/Guthaben, defensiver Name, Negativgrenze, kein Doppel-Upgrade) und `test/object_team_medic_test.dart` (Domäne 0–100 über alle Enneagramme × Qualitäten inkl. Regressionsschutz).
- Erweitert: `test/screen_restaurant_test.dart` (Fortbildungs-Flow inkl. Kader-Haken; Level-<5-Fehlermeldung).
- `flutter analyze`: **keine neuen** Fehler/Warnungen; die Info-Lints sanken von 20 auf 14 (entfernte Fuzzy-Feldnamen).
- `flutter test`: **212 Tests grün** (202 vorher + 10 neue).

---

## Anmerkungen

Alle Schritte (F1–F3) sind **wie dargestellt ausführbar**.

Zu **F2** – Entfernen der Teamarzt-Fuzzy-Engine: Die Persönlichkeiten der Teamärzte und die Fuzzy-Engine funktionieren in ihrer jetzigen Form **aufgrund der bereits gemachten Änderungen nicht mehr**; die Entfernung wird daher so umgesetzt. Die zugrunde liegende Idee ist damit **nicht verworfen**: Sie soll zu einem späteren Zeitpunkt, wenn der **Personalsektor ausgebaut** wird, in **anderer Form** wieder eingebracht werden. Die exakte Umsetzung wird derzeit noch besprochen und ist nicht Teil von V5 (nicht blockierend).