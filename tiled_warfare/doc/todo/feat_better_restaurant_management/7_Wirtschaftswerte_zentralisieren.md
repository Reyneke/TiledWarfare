# Wirtschaftswerte zentralisieren

Erweiterung von **V7** aus dem Basisdokument (`0-Base.md` → „🟡 P7 – Magische Zahlen im Wirtschaftsfluss“). Hier steht die detaillierte Ausführung und Dokumentation der dort erwähnten Probleme sowie der verbliebene Handlungsbedarf.

> **Stand:** V7 wurde zusammen mit V2/V8 in `a723ad5 feat(economy): Wirtschaftsschleife schliessen (V2/V7/V8)` umgesetzt. Die zentrale Konfiguration `lib/services/economy_balance.dart` existiert, und die im Basisdokument genannten Literale sind ersetzt. Die Abschnitte unten halten den Ist-Stand fest, benennen die **verbliebenen** magischen Zahlen und leiten daraus konkrete, überprüfbare Maßnahmen ab.
>
> **Nachtrag (umgesetzt):** Die hier dokumentierten Restbestände (L1–L8 sowie P9/P10) sind inzwischen umgesetzt – siehe „Umsetzungshinweise“ am Ende. L9 (Layering) bleibt bewusst zurückgestellt.

## Aktueller Stand

### Zentralisierte Werte (`lib/services/economy_balance.dart`)

| Gruppe | Konstanten (Auszug) |
|---|---|
| Budget | `startBudget = 10000`, `negativeLimit = −20000` |
| Einmalige Kosten | `hireApprenticeCost = 100`, `upgradeToLineCookCost = 500`, `revivalCost = 200` |
| Laufende Kosten | `medicBaseCostPerWeek = 500`, `medicTeamCostPerHead = 0.05` |
| Gefechtsbelohnung | `battleRewardBaseWin = 200`, `battleRewardBaseLoss = 50` |
| Heilung & Zeit | `maxWoundValue = 3`, `healBasePerStage = 24 h`, `emergencyShotCost = 0`, `emergencyShotDuration = 24 h` |
| Passives Einkommen / Fuzzy | `passiveIncomePerCustomerPerWeek = 5`, `attractivenessBase`, `satisfactionBase`, `staffAttractivityPerHead`, `satisfactionHealthWeight`, `satisfactionWinBonus` / `satisfactionLossPenalty`, `capacityMoneyNorm`, `capacityMax`, `inputDomainMax`, `customersDomainMax`, Fuzzy-Peaks, `districtPrestige` |
| Zinsen | `negativeInterestRate = 0.10` |
| Rettungswurf (W100) | `survivalBase = 50`, `survivalPerLevel = 10`, `survivalDefenseThreshold = 30`, `survivalPerDefenseOverThreshold = 5`, `survivalOverkillPenalty = 10` |
| Rebranding | `rebrandingCost = 5000`, `rebrandingAttractivityPenalty = 1.0`, `rebrandingPenaltyWeeks = 2` |
| Erweiterungen | `upgradeSellRefundRate = 0.5`, `upgrades` (`Map<UpgradeType, UpgradeSpec>`) |

### Verdrahtung (Aufrufer delegieren auf die Balance)

| Datei | Delegation (Beleg) |
|---|---|
| `lib/models/profile_data.dart` | `kDefaultRestaurantBudget = EconomyBalance.startBudget` (`:11`) |
| `lib/objects/object_profile.dart` | `startBudget`/`negativeLimit` (`:100`, `:103`); `hireApprentice({cost = …})` (`:147`); `upgradeToLineCook({cost = …})` (`:178`); `_performSurvivalRolls` (W100-Werte `:294–306`, `revivalCost` `:323–324`); `hireMedic` → `EconomyService.weeklyMedicCost` (`:131–135`); `applyNegativeInterest`/`isBankrupt` → `EconomyService` (`:262–269`) |
| `lib/services/economy_service.dart` | reine Funktionen (`battleReward`, `applyNegativeInterest`, `weeklyMedicCost`, `isBankrupt`, Upgrade-Kosten) |
| `lib/services/game_clock_service.dart` | Wochen-Tick, Catch-up und Eingangswerte lesen `EconomyBalance` (`:398`, `:423–467`) |
| `lib/services/passive_income_service.dart` | Fuzzy-Modell ausschließlich aus `EconomyBalance` |
| `lib/objects/object_team_medic.dart` | Konstruktor-Rumpf → `EconomyService.weeklyMedicCost` (`:90`) |

### Absicherung

- `test/balance_sanity_test.dart`: erzwingt Fuzzy-Peak-Reihenfolge/-Domänen, Budget-/Zins-Invarianten, Heilungs-Balance, Vollständigkeit der Upgrade-Specs und den Einkommens-Deckel.
- `test/economy_service_test.dart`: sichert die reinen Wirtschaftsfunktionen ab.

**Fazit:** Alle im Basisdokument P7 genannten Beträge (10.000 / −20.000 / 100 / 500 / 200 / 500 / 10 % / `50 + 10/Level + 5/Defense − 10 Overkill`) liegen zentral vor. Das dort beschriebene Symptom ist damit **behoben**. Offen sind Werte, die P7 nicht explizit nannte – XP-Kurve, Arzt-Profilwerte, W100-Domäne, Zeit-/Statusgrenzen und die Einheiten-Profile (siehe unten).

## Probleme im Detail

Die folgenden Punkte sind **Restbestände**: Sie liegen außerhalb des ursprünglichen P7-Scopes oder wurden beim Ausbau von V2/V8/V3 nicht mit erfasst. Jeder Punkt nennt Belege und die konkrete Auswirkung.

### P1 – XP-Belohnung und Level-Schwelle stehen außerhalb der Balance-Konfiguration

- `lib/screens/screen_battle_result.dart:131` – `_xpForWin(int level) => 50 + (level * 10)`
- `lib/screens/screen_battle_result.dart:134` – `_xpForLoss = 10`
- `lib/objects/player_objects/object_apprentice.dart:107–108` – `while (currentXPValue >= levelValue * 1000)`

**Auswirkung:** XP-Tuning erfordert einen Eingriff in eine UI-Klasse und in ein Objektmodell. Das verletzt das V7-Abnahmekriterium („Balance-Anpassungen ohne Änderung in der UI-/Gefechts-Logik“) direkt. Die Werte sind zudem nirgends dokumentiert.

### P2 – Beförderungs-Level ist hartkodiert

- `lib/objects/object_profile.dart:183` – `if (apprentice.levelValue < 5) return null;`

**Auswirkung:** Das Level-Gate für „Lehrling → Line Cook“ (Regelwerk § 2.3) ist nur im Code justierbar; `5` taucht als Literal auf und wird von keinem Test abgesichert.

### P3 – Arzt-Balance wird doppelt gepflegt (Enum vs. `EconomyBalance`)

- `lib/objects/object_team_medic.dart:12–35` – `MedicQuality` trägt `costMultiplier` (1.0/2.0/3.0), `survivalBonus` (10/20/30) und `healTimePerStage` (6 h/3 h/1 h).
- `lib/services/economy_balance.dart` – hält parallel `medicBaseCostPerWeek`, `healBasePerStage` und die `survival*`-Werte.

**Auswirkung:** Arzt-Tuning ist auf zwei Orte verteilt. Die `MedicQuality`-Werte sind nicht Teil der Balance-Sanity-Prüfung, und Änderungen am Regelwerk können dazu driften. `effectiveSurvivalBonus` (`object_team_medic.dart:145–149`) mischt den Enum-Bonus mit `_evaluateTreatmentQuality() ~/ 10` – eine weitere magische `10`.

### P4 – Arzt-Scores enthalten verstreute Literale

- `lib/objects/object_team_medic.dart:166–170` – Basis `50` in `helpfulnessScoreFor`
- `lib/objects/object_team_medic.dart:157–160` – `((index + 1) * 8) % 100` in `_enneagramScore`
- `lib/objects/object_team_medic.dart:176–180` – Qualitätsanteil `~/ 2`, Clamp `0–100`

**Auswirkung:** Die „Persönlichkeit“ des Arztes ist nicht über die Balance steuerbar; `8`, `2`, `50`, `100` sind über die Klasse verstreut.

### P5 – W100-Domäne mehrfach als Literal

- `lib/objects/object_profile.dart:309, 325` – `random.nextInt(100) + 1`
- `lib/objects/object_profile.dart:310, 326` – `targetValue.clamp(1, 100)`
- `lib/objects/object_team_medic.dart:120, 126` – `_random.nextInt(100) + 1`

**Auswirkung:** Die Domäne eines W100 (`1…100`) ist an vier Stellen dupliziert. Eine Umstellung (z. B. `0…99`) wäre fehleranfällig.

### P6 – Wiederbelebungs-Wächter weicht vom Negativgrenzen-Muster ab

- `lib/objects/object_profile.dart:323` – `if (hasMedic && budget >= EconomyBalance.revivalCost)`
- dagegen `lib/objects/object_profile.dart:148` und `:186` – `if (budget - cost < negativeLimit) return …`

**Auswirkung:** Es gibt zwei unterschiedliche Budget-Regeln. Eine Wiederbelebung kann das Budget unter die Permadeath-Grenze `negativeLimit` drücken, das Anheuern/Fortbilden nicht. Das ist eine inkonsistente, nicht dokumentierte Balance-Entscheidung.

### P7 – `negativeLimit` ist ein Literal statt aus `startBudget` abgeleitet

- `lib/services/economy_balance.dart:14, 17` – `startBudget = 10000`, `negativeLimit = -20000`
- `doc/rules/team_rules.md:27` – „Das Budget kann bis zum **doppelten Startwert** ins Negative gehen“

**Auswirkung:** Die Regel „doppelter Startwert“ ist nur zufällig erfüllt. Wer `startBudget` anpasst, bricht stillschweigend die Negativgrenze (und damit die Permadeath-Regel).

### P8 – Einheiten- und Belohnungsprofile sind gestreut

- `lib/objects/player_objects/object_apprentice.dart:79–85`
- `lib/objects/player_objects/object_line_cook.dart:16–22`
- `lib/objects/monsters/object_dough_zombie.dart:8–14`
- `lib/objects/boss_monsters/object_dough_dumpster.dart:45–52`
- `lib/objects/object_token.dart:137–145` (Basissatz)

**Auswirkung:** `moneyValue`/`xpValue` sind Belohnungswerte im Sinne von `team_rules.md` § 2.2, und Kampfstatistiken sind Balance. Sie liegen dennoch als Konstruktorargumente in den Objektklassen. Es gibt keine zentrale Tabelle, die Lehrling, Line Cook, Zombie und Dumpster vergleichbar macht.

### P9 – Zeit-, Status- und Domänen-Grenzen sind dupliziert

- `lib/services/game_clock_service.dart:81` – `week = Duration(days: 7)` (eigene Konstante, aber nicht Teil der Balance-Konfiguration)
- `lib/services/game_clock_service.dart:443` – `1.0 - mean / 5.0` mit magischer `5` (höchster heilbarer Statusgrad)
- `lib/services/game_clock_service.dart:424–425` – `prestige - 1.0` / `attractivenessBase +`

**Auswirkung:** Änderungen an der Statuskette (`CharacterStatus`) oder am Wochentakt erfordern Anpassungen an impliziten Stellen; `5` leitet sich nicht aus der Realität (`dying` = Grad 5) ab.

### P10 – Kampf-Modifikatoren als Literale

- `lib/objects/object_token.dart:125, 131` – `defenseMalus`/`attackBonus` = `timesAttackedThisTurn * 5`
- `lib/objects/object_player.dart:402` – Münzwurf bei Gleichstand `coinToss > 51`

**Auswirkung:** Grenzt an `combat_rules.md`, ist aber Teil desselben Balance-Problems: Kampfwerte ohne zentrale Quelle.

### P11 – Zeit und Zufall sind nicht injizierbar

- `lib/objects/object_team_medic.dart:82–90` – `Random()`, `DateTime.now()` im Konstruktor
- `lib/objects/object_profile.dart:284` – `Random()`, `:314, 327` – `DateTime.now()`

**Auswirkung:** Diese Pfade sind nicht deterministisch testbar – Widerspruch zur Leitlinie „Reine Funktionen, injizierte Zeit“ (`2-Wirtschaftsschleife.md` § 0). Kein reiner Balance-Punkt, aber derselbe Wartungsursprung.

### P12 – Regelwerk und Code können auseinanderlaufen

- `doc/rules/team_rules.md:26–28` nennt konkrete Beispielbeträge („z. B. 10.000 €“, „−20.000 €“, „10 %“), die einzige Quelle der Wahrheit ist aber der Code.

**Auswirkung:** Beide können still driften; das Abnahmekriterium „Konsistenz zwischen Regeln und Code“ ist nicht abgesichert. `EconomyBalance` ist derzeit die einzige Absicherung, aber ohne Rückkopplung zur Doku.

## Lösungsansätze

Die Maßnahmen sind so geschnitten, dass jede **mechanisch** (ohne Verhaltensänderung) umsetzbar ist und durch einen Test abgesichert wird. Reihenfolge = Priorität.

### L1 – XP-Kurve und Beförderungs-Level zentralisieren (→ P1, P2)

1. Neue Konstanten in `EconomyBalance`:
   - `xpBaseWin = 50`, `xpPerLevelWin = 10`, `xpBaseLoss = 10`
   - `levelUpXpPerLevel = 1000` (Schwelle = `levelValue × levelUpXpPerLevel`)
   - `lineCookPromotionLevel = 5`
2. Reine Funktion in `EconomyService`: `xpForBattle({required bool won, required int level})` und `levelUpThreshold(int level)`.
3. Aufrufer ersetzen: `ScreenBattleResult._xpForWin`/`_xpForLoss` entfallen; `ObjectApprentice.earnXP` nutzt `EconomyService.levelUpThreshold(levelValue)`; `ObjectProfile.upgradeToLineCook` prüft `levelValue < EconomyBalance.lineCookPromotionLevel`.

**Abnahme:** Keine XP-/Level-Literale mehr in UI- oder Objektklassen; `balance_sanity_test` prüft, dass `xpBaseWin > xpBaseLoss` und die Kurve monoton steigt.

### L2 – Arzt-Balance konsolidieren (→ P3, P4)

1. Neue Wertklasse `MedicQualitySpec` in `economy_balance.dart` (Vorbild: `UpgradeSpec`):
   ```dart
   class MedicQualitySpec {
     final double costMultiplier;
     final int survivalBonus;
     final Duration healTimePerStage;
     const MedicQualitySpec({...});
   }
   ```
2. `static const Map<MedicQuality, MedicQualitySpec> medicQualities` in `EconomyBalance` mit den heutigen Werten (1.0/2.0/3.0, 10/20/30, 6 h/3 h/1 h).
3. `MedicQuality` trägt nur noch Identität (keine Tuning-Felder); `EconomyService.weeklyMedicCost` und `ObjectTeamMedic.effectiveSurvivalBonus` lesen den Spec.
4. Die Score-Literale (`50`, `8`, `~/ 2`, Clamp `0–100`) als benannte Konstanten (`medicHelpfulnessBase`, `medicEnneagramStep`, `medicTreatmentQualityDivisor`, `scoreMin`, `scoreMax`) ablegen.

**Abnahme:** Ein Qualitätswechsel berührt genau eine Datei; `balance_sanity_test` iteriert `MedicQuality.values` und verlangt für jede einen Spec.

### L3 – W100- und Status-Grenzen benennen (→ P5, P9)

1. `EconomyBalance`: `d100Min = 1`, `d100Max = 100`.
2. Helfer `EconomyService.rollD100(Random random)` und `clampTargetToD100(int target)` – ersetzt `nextInt(100) + 1` und `clamp(1, 100)` an allen Stellen.
3. Höchsten heilbaren Statusgrad aus der Realität ableiten: `GameClockService` nutzt die Heilungskette statt der magischen `5` in `teamHealthOf`.

**Abnahme:** Keine `nextInt(100)`-/`clamp(1, 100)`-Literale mehr in `object_profile.dart` / `object_team_medic.dart`.

### L4 – Budget-Wächter vereinheitlichen (→ P6)

1. Neue reine Funktion `EconomyService.canAfford({required int budget, required int cost})` mit `budget - cost >= EconomyBalance.negativeLimit`.
2. Alle Stellen darauf umstellen: `ObjectProfile.hireApprentice`, `upgradeToLineCook`, `_performSurvivalRolls` (Wiederbelebung) und `_applyAutomaticEmergencyShots`.
3. **Entscheidung dokumentieren:** Soll eine Wiederbelebung die Permadeath-Grenze überschreiten dürfen? Empfehlung: nein (Einheitlichkeit), alternativ bewusst als Sonderregel im Regelwerk festhalten.

**Abnahme:** Genau eine Stelle kodiert die Budgetregel; Grenztests (`−20.000`, `−20.001`) für alle vier Pfade.

### L5 – `negativeLimit` aus `startBudget` ableiten (→ P7)

1. `static const int negativeLimit = -2 * startBudget;` in `EconomyBalance`.
2. Sanity-Test: `expect(EconomyBalance.negativeLimit, -2 * EconomyBalance.startBudget);`

**Abnahme:** Ein Tuning von `startBudget` hält die Regel „doppelter Startwert“ automatisch ein.

### L6 – Einheiten-Profile zentralisieren (→ P8)

1. Wertklasse `UnitStats` (attack, defense, movement, damage, range, money, xp, wound, fieldOfView) und eine Konfiguration `EconomyBalance.unitProfiles` (bzw. eine eigene `lib/services/combat_balance.dart`, falls die Datei weiter wächst).
2. Profile für `apprentice`, `lineCook`, `doughZombie`, `doughDumpster` anlegen und von den jeweiligen Konstruktoren lesen lassen.
3. Die `const`-Anforderung der Konstruktor-Defaults beachten: `UnitStats` als `const`-Werte bereitstellen und die Objektklassen über benannte Parameter daraus befüllen (Konstruktor bleibt `const`-fähig, solange keine `static final`-Maps dereferenziert werden).

**Abnahme:** Ein Gegner-/Klassen-Tuning ist eine Ein-Zeilen-Änderung in der Konfiguration; `balance_sanity_test` prüft, dass für jeden Einheitentyp ein Profil existiert.

### L7 – Zeit und Zufall injizierbar machen (→ P11, angrenzend)

1. `ObjectTeamMedic({Random? random, DateTime Function()? now})`; `ObjectProfile` reicht eine Instanz/einen Provider durch.
2. `_performSurvivalRolls` erhält ein injizierbares `Random` und `now`.

**Abnahme:** `treatCharacter`/Rettungswürfe sind mit festem Seed deterministisch testbar.

### L8 – Regelwerk und Code synchron halten (→ P12)

1. `doc/rules/team_rules.md` § 2.2/§ 4.5 verweist statt auf konkrete Beispielbeträge auf die Feldnamen in `EconomyBalance` (Beispielwerte bleiben als „z. B.“ gekennzeichnet).
2. Kurzer Hinweis in `economy_balance.dart`, dass diese Datei die Quelle der Wahrheit ist und das Regelwerk die Spezifikation.

**Abnahme:** Bei einer Balance-Änderung muss nur `EconomyBalance` angepasst werden; das Regelwerk nennt die betroffenen Feldnamen.

### L9 – Struktur/Layering (optional, größerer Eingriff)

`EconomyBalance` bündelt heute Wirtschaft, Kampf/Rettungswurf, Heilung, Fuzzy-Modell und Stadtteil-Prestige. Solange die Datei ~200 Zeilen bleibt, ist das akzeptabel. Bei weiterem Wachstum bietet sich eine Aufteilung an:

| Variante | Vorteile | Nachteile |
|---|---|---|
| Eine Klasse (Status quo) | Ein Import, eine Fundstelle | Vermischte Zuständigkeiten |
| Split in `EconomyBalance` / `CombatBalance` / `MedicBalance` + Barrel-Export | Klare Zuständigkeiten, kleinere Diffs | Mehr Dateien/Imports, Umbenennungsaufwand |

**Empfehlung:** Erst nach L1–L6 entscheiden; die Aufteilung ist kein Selbstzweck.

## Priorisierung

| Priorität | Maßnahme | Aufwand | Nutzen |
|---|---|---|---|
| 1 | L1 XP-Kurve & Beförderungs-Level | klein | hoch (Abnahmekriterium verletzt) |
| 2 | L5 `negativeLimit` ableiten | sehr klein | hoch (stille Regelverletzung) |
| 3 | L4 Budget-Wächter vereinheitlichen | klein | hoch (Konsistenz) |
| 4 | L2 Arzt-Balance konsolidieren | mittel | mittel |
| 5 | L3 W100-/Status-Grenzen | klein | mittel |
| 6 | L6 Einheiten-Profile | mittel | mittel |
| 7 | L7 Injektion Zeit/Zufall | mittel | mittel (Testbarkeit) |
| 8 | L8 Doku-Synchronisation | klein | mittel |
| 9 | L9 Layering | groß | optional |

## Definition of Done (V7)

- [x] Jede in diesem Dokument genannte Balance-Zahl existiert genau einmal – in `EconomyBalance` (bzw. einer bewusst benannten Schwesterdatei).
- [x] Kein XP-, W100-, Level-Gate- oder Budget-Grenzwert als Literal in `lib/screens/` oder `lib/objects/`.
- [x] `EconomyService`/`GameClockService` enthalten keine magischen Zahlen mehr; sie lesen ausschließlich die Konfiguration.
- [x] `balance_sanity_test.dart` deckt ab: Budget-Invarianten inkl. `negativeLimit = −2 × startBudget`, XP-Kurve, vollständiger `MedicQualitySpec`-Satz, Einheiten-Profile.
- [x] `doc/rules/team_rules.md` nennt Feldnamen statt Beispielbeträge.
- [x] `flutter analyze` ohne neue Warnungen; `flutter test` grün.

### Umsetzungshinweise (Stand: umgesetzt)

- **Umgesetzt:** L1–L8 sowie die Randwerte P9/P10. Neue Datei `lib/models/medic_quality.dart` (Enum **ohne** Tuning-Felder); `EconomyBalance` hält `medicQualitySpecs`, die `UnitStats`-Profile und die XP-/W100-/Kampf-Konstanten.
- **Neue API in `EconomyService`:** `xpForBattle`, `levelUpThreshold`, `canAfford`, `rollD100`, `clampTargetToD100`.
- **L4-Entscheidung (getroffen):** Der Budget-Wächter ist einheitlich `EconomyService.canAfford(...)` (`budget − cost ≥ negativeLimit`). Damit kann eine Wiederbelebung – wie Anheuern/Fortbilden – das Budget bis zur Negativgrenze belasten; zuvor galt `budget ≥ revivalCost`. Bewusste Angleichung an § 2.2.
- **L6-Umsetzungsdetail:** Dart erlaubt keinen `const`-Feldzugriff auf `UnitStats` als Default-Parameter. `ObjectApprentice` löst die Werte daher in der Initialisierungsliste aus `EconomyBalance.apprenticeStats` auf; Line Cook, Zombie und Dumpster übergeben sie als Argumente.
- **L7 (umgesetzt):** `ObjectTeamMedic` sowie `ObjectProfile.syncUnitsAfterBattle`/`_performSurvivalRolls` akzeptieren optional `Random`/`now` → deterministisch testbar; Produktionsaufrufer bleiben unverändert.
- **L9 (zurückgestellt):** Keine Aufteilung in mehrere Dateien; `economy_balance.dart` bleibt die einzige Balance-Quelle. Bei weiterem Wachstum erneut prüfen.
- **Verifikation:** `flutter analyze` (keine neuen Warnungen) und `flutter test` (alle Tests grün) wurden ausgeführt.

## Testplan

```bash
flutter analyze
flutter test test/balance_sanity_test.dart test/economy_service_test.dart
flutter test
```

## Risiken

- **Verhaltensänderung durch Scheinrefactoring:** Alle Schritte müssen reine Extraktionen bleiben; die bestehenden Testfälle (`economy_service_test`, `balance_sanity_test`, `object_team_medic_test`) vor und nach jeder Maßnahme laufen lassen.
- **Save-Kompatibilität:** `MedicData.costPerWeek` ist persistiert. Die Konsolidierung (L2) darf den gespeicherten Wert nicht verändern; beim nächsten Anheuern wird neu gerechnet (`2-Wirtschaftsschleife.md` → „Umsetzungshinweise“ → „Migration `costPerWeek`“).
- **`const`-Grenzen in Dart:** Konstruktor-Defaults müssen zur Compile-Zeit konstant sein; die Einheiten-Profile (L6) deshalb als `const`-Werte bereitstellen, nicht als gemappte Laufzeitdaten.
- **Reihenfolge:** L1–L5 sind unabhängig; L6 (Profile) ist der invasivste Schritt und sollte zuletzt erfolgen.