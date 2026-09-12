# Wirtschaftsschleife schließen (Echtzeit, wöchentlich)

Dies ist die Ausarbeitung von **V2** aus dem Basisdokument (`0-Base.md` – Abschnitt „Verbesserungen“ → V2 sowie „Entscheidungen (getroffen)“ → Nr. 2 und 3). Sie beschreibt, wie das Budget zu einem **laufenden Kreislauf** wird: Einnahmen aus Gefechten, laufende Ausgaben (wöchentliche Teamarzt-Kosten), Negativzinsen und der Bankrott-Flow.

Die Grundsatzentscheidungen sind fixiert und werden hier nicht neu verhandelt:

- **Echtzeit** im Stile alter Browsergames; verpasste Zeit wird beim App-Start nachgeholt („Catch-up“, V8).
- **Teamarzt-Bezahlung nur wöchentlich** (`costPerWeek`), kein Anschaffungspreis.
- Der Spielzustand liegt seit **V1** auf der **Restaurant-Ebene** (eigenes Budget, Team, Ärzte je Spielstand).

V2 baut damit auf **V1** (Restaurant-Zustand, `lastSeenAt`) und **V8** (Echtzeit-Zeitsystem) auf. Die **Zentralisierung der Wirtschaftswerte** (V7) ist Voraussetzung dafür, dass die hier beschriebenen Beträge justierbar bleiben, und wird als Phase 1 mit umgesetzt.

## Problemstellung (im Detail)

### Symptom

Das Budget verändert sich nur durch **einmalige** Vorgänge (Lehrling anheuern, Wiederbelebung). Es gibt **keinen laufenden Geldkreislauf**: kein Einkommen, keine wiederkehrenden Ausgaben, keinen spürbaren Bankrott. Das Management hat damit weder Druck noch Belohnung – genau das „fühlt sich nicht richtig an“ aus `0-Base.md`.

### Ursache (Belege)

1. **Kein Einkommen.** Gefechtsbelohnungen existieren im Code nicht. `ObjectToken.moneyValue` (Beute pro besiegtem Gegner, `team_rules.md` § 2.2) wird **nie auf das Budget gutgeschrieben**; es gibt keine Regel für Sieg-/Niederlage-Prämien. `ScreenBattleResult._computeAndApplyResults()` verteilt ausschließlich XP (`unit.earnXP(...)`) und Match-Records.
2. **Teamarzt-Kosten werden nie abgebucht.** `ObjectProfile.hireMedic()` / `fireMedic()` (`object_profile.dart`) verändern das Budget nicht. `ObjectTeamMedic.costPerWeek` wird nur angezeigt (`screen_hire_and_fire.dart`) und serialisiert (`MedicData`).
3. **Arztpreis ignoriert das Regelwerk.** `ObjectTeamMedic(...)` nutzt `personalCostMultiplier = 1.0` als Standard; der Aufrufer (`ScreenHireAndFire`, `ObjectProfile`-Deserialisierung) übergibt nie die tatsächliche Teamgröße/-zusammensetzung. Dadurch kostet **jeder Arzt exakt 500 €/Woche** – unabhängig von Qualität und Team (`_computeWeeklyCost`). `team_rules.md` § 4.5 verlangt genau diese Abhängigkeit.
4. **Negativzinsen & Bankrott sind toter Code.** `ObjectProfile.applyNegativeInterest()` (10 % auf negatives Budget) und `isBankrupt` existieren, haben aber **keinen Aufrufer**. `ObjectProfile.reset()` (Neustart nach Permadeath) hat ebenfalls keinen Aufrufer – ein Bankrott ist damit weder erlebbar noch auflösbar.
5. **Kein Zeitsystem.** `RestaurantData.lastSeenAt` wird zwar geschrieben (V1/Migration), aber nie ausgewertet. Ohne Echtzeit-Tick gibt es weder eine wöchentliche Abbuchung noch einen Catch-up (V8).
6. **Magische Zahlen (V7).** 10.000 / −20.000 (Budget), 100 (Lehrling), 500 (Fortbildung sowie Arztbasis), 200 (Wiederbelebung), 10 % (Zins) und die W100-Zielwerte (50 + 10/Level + 5/Defense, −10 Overkill) stehen als Literale verstreut in `object_profile.dart` / `object_team_medic.dart`.

### Auswirkung

Ohne Einnahmen und laufende Ausgaben entsteht **kein wirtschaftlicher Druck**, ohne Bankrott-Flow **kein Verlust-Risiko**, ohne Catch-up **kein Fortschritt zwischen den Sitzungen**. Die Wirtschaft wirkt wie eine Ansammlung einmaliger Menü-Aktionen statt wie eine Schleife.

## Aktueller Stand

**Bereits vorhanden (V1-Basis):**

- Budget liegt pro Restaurant (`RestaurantData.budget`), Start 10.000 € (`kDefaultRestaurantBudget`).
- `RestaurantData.lastSeenAt`, `isDissolved`, `dissolvedAt` existieren und werden serialisiert.
- `ObjectProfile.applyNegativeInterest()`, `isBankrupt`, `reset()` und `_performSurvivalRolls()` (inkl. 200 €-Wiederbelebung) sind implementiert.
- `ObjectTeamMedic.costPerWeek` wird berechnet und persistiert.

**Geldfluss heute:**

| Vorgang | Richtung | Betrag | Ort |
|---|---|---|---|
| Lehrling anheuern | Ausgabe | 100 € | `ScreenRestaurant` → `ObjectProfile.hireApprentice()` |
| Fortbildung (toter Pfad) | Ausgabe | 500 € | `ObjectProfile.upgradeToLineCook()` (kein UI-Aufrufer) |
| Wiederbelebung durch Arzt | Ausgabe | 200 € | `ObjectProfile._performSurvivalRolls()` |
| Teamarzt anheuern/entlassen | – | 0 € | `ObjectProfile.hireMedic()` / `fireMedic()` |
| Wöchentliche Arztkosten | – | 0 € (nur Anzeige) | `ObjectTeamMedic.costPerWeek` |
| Gefechtsbelohnung | – | nicht implementiert | `ScreenBattleResult` (nur XP) |
| Negativzinsen | toter Aufruf | 10 % | `ObjectProfile.applyNegativeInterest()` |

**Post-Gefecht-Pfad (heutiger Hook):** `WidgetCaretaker._returnToRestaurant()` meldet das Ergebnis über `onGameOver?.call(hasAliveUnits)` an `ScreenMain`, das zu `ScreenBattleResult` navigiert. Dort läuft in `_computeAndApplyResults()`: XP-Vergabe → `addMatchRecordsForBattle()` → `syncUnitsAfterBattle()` (Rettungswürfe) → `saveToStorage()`. **Hier – nicht in `WidgetCaretaker` – gehört die Wirtschafts-Abrechnung hin.**

**Abhängigkeiten:** V2 benötigt V8 (Echtzeit/Catch-up) für die wöchentliche Abbuchung und V1 (Restaurant-Zustand) als Träger von `lastSeenAt`/`budget`.

## Lösungsvorschlag

### Ziel (fixierte Entscheidung)

Das Budget wird zur **geschlossenen Schleife**:

- **Einnahmen:** Sieg-/Niederlage-Belohnung plus `moneyValue` der besiegten Gegner sowie **passives Einkommen zwischen den Gefechten** (§ 8, Fuzzy-Inferenz).
- **Ausgaben:** einmalig (Anheuern, Fortbildung, Wiederbelebung) plus wiederkehrend (wöchentliche Teamarzt-Kosten).
- **Konsequenz:** Negativzinsen pro Gefecht; Überschreiten der Negativgrenze → Permadeath/Bankrott.

### 0. Architektur-Leitlinie (Best Practices)

- **Wirtschaftslogik raus aus dem Singleton.** `ObjectProfile` bleibt reiner Zustandshalter; Rechen- und Regellogik wandert in **einzeln testbare Services** (`EconomyService`, `GameClockService`). Das löst nebenbei das unter `doc/todo/feat_metagame/2_Verbesserter_Arzteinsatz.md` notierte Singleton-/Testability-Problem.
- **Reine Funktionen, injizierte Zeit.** Kein `DateTime.now()` / `Random()` tief in der Logik. `GameClockService` erhält eine `DateTime Function() now` (bzw. einen `now`-Parameter), damit Catch-up deterministisch testbar ist.
- **Eine Quelle der Wahrheit für Beträge** (V7). Keine Literale mehr im Fluss.
- **Idempotenter Catch-up.** Wiederholtes Anwenden des Ticks darf nicht doppelt abbuchen – der Anker (`lastSeenAt`) wird nach jeder Abbuchung fortgeschrieben.

### 1. Balance-Konfiguration (V7)

Neue Datei `lib/services/economy_balance.dart` mit benannten Konstanten (bzw. einer Config-Klasse):

```dart
/// Zentrale Balance-Werte der Wirtschaft (V7).
class EconomyBalance {
  EconomyBalance._();

  // Budget
  static const int startBudget = 10000;
  static const int negativeLimit = -20000;

  // Einmalige Kosten
  static const int hireApprenticeCost = 100;
  static const int upgradeToLineCookCost = 500;
  static const int revivalCost = 200;

  // Laufende Kosten
  static const int medicBaseCostPerWeek = 500;

  // Passives Einkommen / Fuzzy-Modell (§ 8)
  static const int passiveIncomePerCustomerPerWeek = 5;
  static const double attractivenessBase = 1.0;
  static const double satisfactionBase = 1.0;
  static const double staffAttractivityPerHead = 0.1;
  // Getunt (Balance-Tuning): 4.0 sättigte gesunde Teams am Domänen-Clamp (4.0)
  // und machte Sieg-/Niederlage-Bonus, Upgrades und Rebranding-Malus wirkungslos.
  static const double satisfactionHealthWeight = 1.5;
  static const double satisfactionWinBonus = 0.5;
  static const double satisfactionLossPenalty = 0.5;
  static const int capacityMoneyNorm = 100;
  static const double capacityMax = 20.0;

  /// Stadtteil-Prestige (Default 1.0 für nicht gelistete Stadtteile).
  ///
  /// Die Keys sind **exakt** die Namen aus der Objektebene „Nachbarschaften“
  /// in `assets/world/theworld.tmx`. Die Werte sind Balance-Werte, orientiert
  /// am realen Prestige-/Preisniveau der Manhattan-Nachbarschaften (Tuning in
  /// Phase 3). Reihenfolge: S (luxuriös) → D (aufstrebend).
  static const Map<String, double> districtPrestige = {
    // S – höchstes Prestige/Preisniveau
    'TriBeCa': 2.00,
    // A – sehr begehrt
    'Upper East Side': 1.90,
    'SoHo': 1.90,
    'Upper West Side': 1.80,
    'Greenwhich Village / West Village': 1.80,
    'Hudson Yards': 1.60,
    // B – etabliert wohlhabend / trendy
    'Gramercy': 1.50,
    'Flatiron District': 1.50,
    'Nomad': 1.50,
    'Chelsea': 1.40,
    'Financial District': 1.30,
    // C – gemischt / hohe Frequenz
    'Midtown': 1.25,
    'East Village': 1.15,
    'Theater District': 1.15,
    'Koreatown': 1.05,
    'Hell\'s Kitchen': 1.00,
    'Lower East Side': 1.00,
    // D – aufstrebend / working-class
    'Little Italy': 0.90,
    'Chinatown': 0.80,
    'Harlem': 0.70,
  };

  // Zinsen
  static const double negativeInterestRate = 0.10;

  // Rettungswurf (W100)
  static const int survivalBase = 50;
  static const int survivalPerLevel = 10;
  static const int survivalDefenseThreshold = 30;
  static const int survivalPerDefenseOverThreshold = 5;
  static const int survivalOverkillPenalty = 10;
}
```

`kDefaultRestaurantBudget` (in `profile_data.dart`) bleibt als öffentlicher Name erhalten und verweist auf `EconomyBalance.startBudget`; `ObjectProfile.startBudget` / `negativeLimit` delegieren ebenfalls dorthin.

### 2. Echtzeit-Zeitsystem (V8): `GameClockService`

Neue Datei `lib/services/game_clock_service.dart`:

- **Anker:** `RestaurantData.lastSeenAt` je Spielstand (bereits vorhanden).
- **API (Beispiele):**
  - `Duration elapsed(DateTime lastSeenAt, DateTime now)`
  - `int weeksElapsed(DateTime lastSeenAt, DateTime now)`
  - `DateTime nextWeeklyTick(DateTime lastSeenAt, DateTime now)`
  - `void catchUp(RestaurantData restaurant, DateTime now)` – schreibt `lastSeenAt` fort und liefert die fälligen Effekte (heute: Wochenabbuchung).
- Wird beim **App-Start** (Login), beim **Wiederaufnehmen** der App (`AppLifecycleState.resumed`) und beim **Restaurant-Wechsel** ausgeführt – so kann der Spieler den Kosten nicht durch Standortwechsel oder App-Wechsel entgehen.
- Die UI nutzt `nextWeeklyTick()`, um den Countdown „nächste Abbuchung“ anzuzeigen.

### 3. Wirtschaftslogik (V2): `EconomyService`

Neue Datei `lib/services/economy_service.dart` – **reine, zustandslose Funktionen** auf einfachen Werten (testbar ohne Widgets/Singleton):

- `int battleReward({required bool playerWon, required Iterable<int> enemyMoneyValues})` – Sieg: Basisprämie + Summe der `moneyValue`; Niederlage: reduziert/keine Prämie.
- `int applyNegativeInterest(int budget)` – `budget - (budget.abs() * EconomyBalance.negativeInterestRate).ceil()` bei negativem Bestand, sonst unverändert.
- `int billWeeklyMedicCosts(Iterable<int> medicCostsPerWeek, int weeks)` – Summe pro Woche × Wochen.
- `int weeklyMedicCost(MedicQuality quality, int teamSize)` – ersetzt die verstreute `_computeWeeklyCost`-Formel und macht Qualität **und** Teamgröße wirksam.
- `bool isBankrupt(int budget)` – `budget < EconomyBalance.negativeLimit`.

### 4. Verdrahtung (Aufrufer)

- **Post-Gefecht** in `ScreenBattleResult._computeAndApplyResults()` (nach XP/Match-Records, vor `saveToStorage()`): Belohnung gutschreiben → Negativzinsen anwenden → Bankrott prüfen. Dafür muss der Ergebnis-Screen die `moneyValue`-Summe der besiegten Gegner kennen (siehe Hinweise).
- **App-Start / Restaurant-Wechsel:** `GameClockService.catchUp(...)` über den geladenen Spielstand; bucht fällige Wochen ab und aktualisiert `lastSeenAt`.
- **Arzt anheuern/entlassen:** Billing-Anker = Anheuerzeitpunkt (Start der ersten Woche); die erste Abbuchung erfolgt **erst zum nächsten Wochen-Tick** (keine anteilige Abrechnung). `costPerWeek` beim Anheuern aus Qualität + aktueller Teamgröße berechnen.
- **Bankrott-Dialog:** Bei `isBankrupt` → Permadeath-Dialog (Investoren lösen das Restaurant auf) → `ObjectProfile.reset(district: ...)` startet einen neuen Spielstand (V1-Flow).

### 5. Fix der Arztpreis-Formel

`_computeWeeklyCost` in `object_team_medic.dart` wird durch `EconomyService.weeklyMedicCost(quality, teamSize)` ersetzt und mit der echten Teamgröße aufgerufen. Der Parameter `personalCostMultiplier` am Konstruktor entfällt bzw. wird konsequent befüllt. Bestehende Spielstände haben bereits ein `costPerWeek`; Empfehlung: beim nächsten Anheuern neu berechnen, vorhandene Werte bis dahin beibehalten (stabiler Save).

### 6. UI & l10n

- `ScreenRestaurant`: Budgetzeile (bereits rot bei negativem Wert) um **Countdown bis zur nächsten Abbuchung** und eine **Warnung nahe der Negativgrenze** ergänzen; Permadeath-Dialog beim Bankrott.
- `ScreenHireAndFire`: **Gesamtwochenlast** (`Σ costPerWeek`) anzeigen, damit die laufenden Kosten vor dem Anheuern sichtbar sind.
- Neue Strings in `lib/l10n/app_de.arb` / `app_en.arb`.

### 7. Tests & Regelwerk

- `test/economy_service_test.dart`: Zinsen (positiv/negativ/null), Belohnungen (Sieg/Niederlage), Wochenabbuchung (0/1/n Wochen), Bankrott-Grenze (−20.000 exakt vs. darunter).
- `test/game_clock_service_test.dart`: Catch-up mit injiziertem `now` (0 Tage, 3 Tage, 30 Tage), **Idempotenz** (zweifacher Aufruf bucht nicht doppelt), Wochen-Grenzfall.
- `team_rules.md` § 2.2 (Einnahmequelle Belohnung) und § 4.5 (Arztkosten-Formel) an den Code angleichen.

### 8. Passives Einkommen (Fuzzy-Inferenz)

Bisher ist das Gefecht die einzige Einnahmequelle. Ergänzend soll das Restaurant **passives Einkommen zwischen den Gefechten** erwirtschaften (in `team_rules.md` § 2.2 bereits als „Optional: Passive Einnahmen durch das Restaurant zwischen Gefechten“ vorgesehen – hier wird es fixiert). Es ist **deutlich geringer als ein Gefecht**, macht den Betrieb aber spürbar und belohnt Standort, Personal und Teamzustand.

Die Berechnung erfolgt über eine **Fuzzy-Inferenz** mit der im Projekt enthaltenen Bibliothek (`lib/fuzzy_logic/lib/fuzzylogic.dart`, Muster wie `ObjectTeamMedic.MedicHelpfulness`). Alle Beträge/Peaks sind Balance-Werte in `EconomyBalance` (V7).

**Eingangswerte (crisp):**

| Eingang | Basiswert | Quelle / Formel |
|---|---|---|
| **Attraktivität** | 1.0 | `1.0 + (districtPrestige[district] − 1.0) + personalAnzahl × staffAttractivityPerHead`, geclamped auf 0–4. `districtPrestige` ist eine kleine `Map<String, double>` in `EconomyBalance` (Default 1.0 für Stadtteile ohne Eintrag). |
| **Kundenzufriedenheit** | 1.0 | `1.0 + teamHealth × satisfactionHealthWeight + resultBonus`, geclamped auf 0–4. `teamHealth = 1 − Ø(CharacterStatus.severity)/5` (0.0 = alle `ready` … 1.0 = alle `dying`); `resultBonus` = `RestaurantData.lastMatchResult` (letztes Gefechtsergebnis: `+satisfactionWinBonus` / `−satisfactionLossPenalty`). |
| **Kapazität** | ~1.0 | `mean(moneyValue der Mitarbeiter) / capacityMoneyNorm` (`capacityMoneyNorm = 100`), geclamped auf 0–`capacityMax` (20). **Kein Personal → 0.** |

*Hinweis:* `moneyValue` ist aktuell der „Geldwert bei Besiegung“ (`ObjectToken`) – Lehrling 100, Line Cook 1000. Dadurch hebt ein Line-Cook-Team die Kapazität um Faktor ~10; das ist gewollt (stärkeres Personal = mehr Gäste), die Obergrenze `capacityMax` fängt Ausreißer ab.

**Fuzzy-Modell:** Drei Eingangs-`FuzzyVariable<double>` (Attraktivität, Zufriedenheit je 0–4; Kapazität 0–20) und eine Ausgangs-`FuzzyVariable<int>` **Kunden/Woche** (0–100). Beispielhafte Mengen und Regeln (Peaks sind Tuning-Werte):

```dart
class Attractiveness extends FuzzyVariable<double> {
  // Domäne 0–4 (Entscheidung, siehe Balancing-Hinweis).
  var Niedrig = FuzzySet.LeftShoulder(0.0, 1.0, 2.0);
  var Mittel  = FuzzySet.Triangle(1.0, 2.0, 3.0);
  var Hoch    = FuzzySet.RightShoulder(2.0, 3.0, 4.0);
  Attractiveness() { sets = [Niedrig, Mittel, Hoch]; init(); }
}

class Satisfaction extends FuzzyVariable<double> {
  // Domäne 0–4 (identisch zur Attraktivität).
  var Niedrig = FuzzySet.LeftShoulder(0.0, 1.0, 2.0);
  var Mittel  = FuzzySet.Triangle(1.0, 2.0, 3.0);
  var Hoch    = FuzzySet.RightShoulder(2.0, 3.0, 4.0);
  Satisfaction() { sets = [Niedrig, Mittel, Hoch]; init(); }
}

class CustomersPerWeek extends FuzzyVariable<int> {
  var Wenig  = FuzzySet.LeftShoulder(0, 0, 50);
  var Mittel = FuzzySet.Triangle(0, 50, 100);
  var Viel   = FuzzySet.RightShoulder(50, 100, 100);
  CustomersPerWeek() { sets = [Wenig, Mittel, Viel]; init(); }
}

// att, sat, cap = instanziierte Eingangs-Variablen der FuzzyVariable<double>;
// cust = CustomersPerWeek (Ausgangs-Variable); resolve() nutzt den Output-Placeholder.
frb.addRules([
  (att.Hoch    & sat.Hoch    & cap.Hoch)   >> (cust.Viel),
  (att.Mittel  & sat.Mittel  & cap.Mittel) >> (cust.Mittel),
  (att.Niedrig & sat.Niedrig)              >> (cust.Wenig),
  // ...
]);
```

Die Defuzzifizierung (Average-of-Maxima über die Representative-Values der Mengen) liefert `customersPerWeek.crispValue`.

**Ausgangswert & Einkommen:** `Kunden/Woche` (0–100) × `EconomyBalance.passiveIncomePerCustomerPerWeek` (z. B. 5 € → bis ~500 €/Woche). Damit bleibt das passive Einkommen unter dem Gefechtspotenzial, ist aber planbar.

Neue Datei `lib/services/passive_income_service.dart` (reine, testbare Funktionen, analog `EconomyService`):

- `int customersPerWeek({required double attractiveness, required double satisfaction, required double capacity})`
- `int passiveIncomePerWeek({required double attractiveness, required double satisfaction, required double capacity})`

**Integration in den Wochen-Tick (V8):** Beim Catch-up gilt die feste Reihenfolge **passives Einkommen → Teamarzt-Kosten → Negativzinsen → Bankrott-Check**. Das Einkommen wird für jede fällige Woche gutgeschrieben (`passiveIncomePerWeek(...) × weeks`), danach werden Kosten/Zinsen verrechnet. `ScreenRestaurant` zeigt in der Budgetzeile zusätzlich „Kunden/Woche“, „Passiv €/Woche“ und die Arztkosten (neue l10n-Strings).

**Tests:** `test/passive_income_service_test.dart` – Baseline (Attraktivität/Zufriedenheit/Kapazität = 1/1/1), Monotonie je Eingang, Kapazität 0 ohne Personal → 0 Kunden, Prestige- und Teamgesundheits-Effekt.

**Attraktivität des Distrikts (`districtPrestige`):** Die Prestige-Werte sind an den **realen** Manhattan-Nachbarschaften des Spiels orientiert (Keys = exakte Namen der „Nachbarschaften“-Ebene in `assets/world/theworld.tmx`; Werte um 1.0, Default 1.0 für unbekannte Stadtteile):

| Tier | Distrikt (TMX-Name) | `districtPrestige` | Reale Einordnung |
|---|---|---|---|
| S | TriBeCa | 2.00 | Prominent, höchste Preisdichte |
| A | Upper East Side | 1.90 | Wohlstands-Ikone |
| A | SoHo | 1.90 | High-End-Shopping, sehr teuer |
| A | Upper West Side | 1.80 | Affluent, Kulturanchor (Lincoln Center) |
| A | Greenwhich Village / West Village | 1.80 | Historisch, sehr teuer |
| A | Hudson Yards | 1.60 | Neues Luxus-Viertel |
| B | Gramercy | 1.50 | Exklusive Enklave |
| B | Flatiron District | 1.50 | Trendy/Tech, teuer |
| B | Nomad | 1.50 | Boutique-Hotels, teuer |
| B | Chelsea | 1.40 | Galerien, etabliert wohlhabend |
| B | Financial District | 1.30 | Wall Street, modern aufgewertet |
| C+ | Midtown | 1.25 | Ikone, kommerziell |
| C | East Village | 1.15 | Bohemien/trendy |
| C | Theater District | 1.15 | Hohe Frequenz, mittlere Exklusivität |
| C | Koreatown | 1.05 | Dicht, starke Food-Szene |
| C | Hell's Kitchen | 1.00 | Gentrifiziert, gemischt |
| C | Lower East Side | 1.00 | Trendy, historisch Arbeiterviertel |
| D | Little Italy | 0.90 | Historisch berühmt, heute klein/touristisch |
| D | Chinatown | 0.80 | Food-Destination, günstig |
| D | Harlem | 0.70 | Kult-Relevanz, gentrifizierend |

> **Balancing-Hinweis (Entscheidung):** Mit diesen Werten liefert die Attraktivitäts-Formel typischerweise ~0.7–3.0 (Default-Stadtteil ≈ 1.0). **Entschieden:** Die Fuzzy-Eingangssets für **Attraktivität und Kundenzufriedenheit** werden auf eine Domäne von **0–4** ausgelegt („Hoch“ ≈ 3–4); höhere crisp-Werte sättigen in „Hoch“. `staffAttractivityPerHead` und die Prestige-Spreizung bleiben unverändert. Die crisp-Clamps (siehe Tabelle oben) sind entsprechend von 0–10 auf 0–4 angeglichen. Ein Test erzwingt Baseline > 0 und Monotonie je Eingang.

### 9. Mehr als nur Pizza – Restaurant-Küchen & Namens-Stämme

Bisher sind alle Charaktere italienisch geprägt (Name **und** Stil; `RandomNames(Zone.italy)` fest in `ObjectApprentice`/`ObjectTeamMedic`). Künftig wählt der Spieler bei der **Erschaffung eines Restaurants** eine Küche; Personal- und Arztnamen werden passend zum Namensstamm der Küche erzeugt.

- **Küchen:** Italienisch, Japanisch, Chinesisch, Deutsch, Mexikanisch, Kanadisch.
- **Namensstamm:** Mapping Küche → `Zone` aus `random_name_generator` (im Projekt bereits als Abhängigkeit `^1.5.0` vorhanden):

| Küche | `Zone` | Anmerkung |
|---|---|---|
| Italienisch | `Zone.italy` | heutiger Default |
| Japanisch | `Zone.japan` | – |
| Chinesisch | `Zone.china` | – |
| Deutsch | `Zone.germany` | – |
| Kanadisch | `Zone.canada` | – |
| Mexikanisch | `Zone.spain` | **Entscheidung:** die Bibliothek hat kein `Zone.mexico`; `Zone.spain` liefert spanischsprachige Namen |

- **Daten:** neues Feld `RestaurantData.cuisine` (`enum Cuisine`, Default `italian`; Migration setzt Alt-Daten auf `italian`). Die Küche wird bei der Restaurant-Erstellung in `ScreenStart` gewählt und im `ScreenRestaurant`-Header angezeigt.
- **Namenerzeugung:** `ObjectApprentice`/`ObjectTeamMedic` erhalten statt des hartkodierten `Zone.italy` einen `Zone`/`Cuisine`-Parameter (über `ObjectProfile` beim Anheuern übergeben).
- **Stil (umgesetzt):** Token-/Restaurant-Grafiken je Küche liegen jetzt als **Küchen-Art-Assets** vor: `scripts/generate_cuisine_tokens.py` erzeugt aus `token_cook_basic.png` je Küche eine eigene Farbvariante (`assets/images/token/token_cook_<cuisine>.png`, **Platzhalter-Art** – durch echte Assets überschreibbar, Pfade bleiben stabil). `Cuisine.tokenImagePath` liefert den Pfad; Lehrling/Line Cook erhalten ihn über den `cuisine`-Parameter, Personal-Avatar und Header zeigen die Küchen-Grafik, und `ScreenCharacterDetail` nutzt sie automatisch. Alt-Spielstände behalten ihren gespeicherten (generischen) Bildpfad.
- **Rebranding (Entscheidung):** Ein Küchenwechsel ist nachträglich möglich, aber **deutlich teuer** und mit **wirtschaftlichen Folgen** verbunden (z. B. einmalige Kosten + zeitlich begrenzter Attraktivitäts-Malus; Balance-Werte in `EconomyBalance`). UI in `ScreenRestaurant`; setzt `RestaurantData.cuisine` neu und erzeugt künftige Namen im neuen Namensstamm (bestehendes Personal behält seinen Namen).
- `team_rules.md` § 2.4 (`RandomNames(Zone.italy)`) entsprechend aktualisieren.

### 10. Restauranterweiterungen

Als Browsergame-Annäherung soll das Restaurant mit **Erweiterungen** ausgebaut werden können. Diese wirken auf die drei Eingangswerte des passiven Einkommens (§ 8) – **Attraktivität, Kundenzufriedenheit, Kapazität** – und sind selbst weiter ausbaubar (Stufen). Jede Erweiterung kostet **Ankauf** und **Unterhalt** (wöchentlich, siehe § 2/§ 8).

**Erweiterungen (Balance-Werte, Tuning in `EconomyBalance`):**

| Erweiterung | Effekt / Stufe | Max-Stufe | Ankauf (Basis) | Erhalt/Woche (Basis) |
|---|---|---|---|---|
| Mehr Tische | +1 % Kapazität, +1 % Kundenzufriedenheit | 5 | 100 € | 10 € |
| Größere Küche | +5 % Kapazität | 5 | 200 € | 20 € |
| Werbeplakate | +5 % Attraktivität | 5 | 150 € | 15 € |
| Dekorationen | +2 % Attraktivität, +2 % Kundenzufriedenheit | 5 | 120 € | 12 € |
| Musikautomat | +20 % Attraktivität | 1 | 500 € | 50 € |

- **Kostenmodell (linear mit der Stufe, Entscheidung: kumulativ):** Der Ausbau **auf** Stufe `N` kostet `Ankauf-Basis × N`; **kumulativ** bis Stufe `N` sind `Σ Basis×k = Basis × N·(N+1)/2` investiert. Der wöchentliche Unterhalt **auf** Stufe `N` beträgt `Erhalt-Basis × N`. Beispiel (Ankauf 100 €, Erhalt 10 €): Stufe 1 = 100 € / 10 €, Stufe 2 = 200 € / 20 € (insgesamt 300 € investiert), Stufe 3 = 300 € / 30 € usw.
- **Downgrade & Verkauf (Entscheidung):** Erweiterungen lassen sich stufenweise **zurückbauen** und ganz **verkaufen**, um laufende Kosten zu senken. Ein Verkauf erstattet **50 %** der investierten Anschaffungssumme (Entscheidung; Wert in `EconomyBalance` justierbar); der Unterhalt sinkt entsprechend der neuen Stufe.
- **Wirkung (multiplikativ):** Die § 8-Formeln werden vor dem Clamp mit dem Erweiterungsfaktor multipliziert: `Basiswert × (1 + Σ Bonus)`. Reine Funktion `upgradeEffects(levels)` in `EconomyService` liefert die drei Summenboni.
- **Daten:** `enum UpgradeType` (tables, kitchen, signage, decoration, jukebox); `RestaurantData.upgrades` (`Map<UpgradeType, int>` = Stufe); Definitionen (Ankauf-Basis, Erhalt-Basis/Woche, MaxLevel, Boni) in `EconomyBalance.upgrades` (V7).
- **Funktionen (`EconomyService`):** `upgradeEffects(levels)` (drei Summenboni), `upgradeCost(upgrade, toLevel)` (kumulativ), `upgradeUpkeepPerWeek(upgrade, level)`, `sellRefund(upgrade, level)`.
- **Kauf/Ausbau:** Budget-Check wie `hireApprentice` (nicht unter die Negativgrenze), Persistenz via `_saveState()`.
- **Unterhalt:** wird im **Wochen-Tick (V8)** mit abgebucht; Reihenfolge: passives Einkommen → Teamarzt-Kosten → **Erweiterungs-Unterhalt** → Negativzinsen → Bankrott-Check.

### 11. Restaurant-Screen Redesign (Reiter)

Der `ScreenRestaurant` stapelt heute alles in einer langen Column (Personal-Liste → Anheuern → „Verfügbare Karten" → Karten-Tiles → Gefechtsbutton), was viel Scrollen erfordert. Künftig werden diese Blöcke über **Reiter (Tabs)** angeboten.

- **Header unverändert:** Teamlogo, Teamname, Team-Infos, Budget, Stadtteil, „Personal verwalten".
- **Reiter darunter:**
  1. **Aktives Personal** – Personal-Liste, Anheuern/Entlassen, Kader-Auswahl (Checkboxen).
  2. **Passives Personal (Teamarzt)** – angeheuerte Ärzte; Zugang zur Arztverwaltung (`ScreenHireAndFire`).
  3. **Restauranterweiterungen** – Kauf/Ausbau der Erweiterungen aus § 10 inkl. Kosten-/Unterhalts-Anzeige.
  4. **Karte & Gefecht** – Karten-Auswahl + Gefechtsbutton.
- **Zustand:** neuer lokaler Zustand `_activeTab`; beim Restaurant-Wechsel (`_switchRestaurant`) wird auf „Aktives Personal" zurückgesetzt; `_battleReadyCharacters`/`_selectedMapIndex` bleiben wie bisher erhalten.
- Neue l10n-Strings für die Reiter-Titel.

### Tickzeiten (Entscheidung)

**Ist-Zustand (vor V8):** Es läuft **kein** Tick-System. Alle Systeme ausserhalb des Gefechts sind rein ereignisgesteuert (einmalige Menü-Aktionen). `RestaurantData.lastSeenAt` wird beim Laden geschrieben, aber nie ausgewertet; `ObjectTeamMedic.costPerWeek` wird nur angezeigt; `applyNegativeInterest()`/`isBankrupt` haben keinen Aufrufer; die Heilung ist manuell/sofortig (`emergencyShot` setzt den Zustand direkt, der Rückfall „nach einem Tag" ist nur ein Kommentar).

**Festgelegter Tick:** Abgerechnet wird ausschliesslich im **Wochentick** – 1 Tick = 1 Echtzeitwoche (koppelt an V8). Der `GameClockService` rechnet in Wochen-Einheiten; der Catch-up holt alle fälligen Wochen beim App-Start (Login), beim Wiederaufnehmen der App (`resumed`) und beim Restaurant-Wechsel nach.

| Tick | Status | Verantwortlich für |
|---|---|---|
| **Wochentick** | **Geplant in V2/V8** – der einzige Tick der Wirtschaftsschleife | passives Einkommen, Teamarzt-Kosten, Erweiterungs-Unterhalt, Negativzinsen, Bankrott-Check (Reihenfolge siehe § 8/§ 10) |
| **Tagestick** | dem Folge-Dokument (V3) vorbehalten | Echtzeit-Heilung, Rückfall der Notfall-Spritze |
| **Intervalltick (alle 3 Stunden)** | dem Folge-Dokument (V3) vorbehalten | Heilung einer Verletzungsstufe (`MedicQuality.healTimePerStage`: 6 h/3 h/1 h) |

Tagestick und Intervalltick sind **keine parallelen Tick-Systeme**, sondern Module auf demselben `GameClockService` (V8), die erst mit der Heilung (P3/V3) aktiviert werden. `MedicQuality.healTimePerStage`/`effectiveHealTime` existieren bereits als Daten, werden aber bis dahin von keinem Tick konsumiert.

### Offene Fragen

Aktuell sind **keine offenen Fragen** mehr vorhanden.

**Entschieden (Phase 4): Beute-Ermittlung per Callback.** `WidgetCaretaker` summiert die `moneyValue`-Summe der besiegten Gegner und übergibt sie über `onGameOver(playerWon, loot)` an `ScreenMain` → `ScreenBattleResult(enemyLoot: ...)`, wo die Wirtschaftsabrechnung stattfindet.

> Alle zuvor offenen Fragen sind entschieden und in die Fachabschnitte (§ 4, § 8, § 9, § 10) sowie in die „Umsetzungshinweise“ übernommen.

---

### Umsetzungs-Phasen

1. **Phase 1 – Balance-Konfiguration (V7):** `EconomyBalance` einführen, alle Literale ersetzen. Rein mechanisch, kein Verhaltenswechsel.
2. **Phase 2 – Zeitsystem (V8):** `GameClockService`, Anker je Restaurant, Catch-up beim Laden/Wechsel.
3. **Phase 3 – `EconomyService` & `PassiveIncomeService` (V2):** reine Funktionen, Fuzzy-Modell (§ 8) + Unit-Tests.
4. **Phase 4 – Verdrahtung:** Post-Gefecht (Belohnung, Zinsen, Bankrott), Wochen-Tick im Catch-up (passives Einkommen + Arztkosten), Arzt-Billing-Anker.
5. **Phase 5 – UI & l10n:** Countdown, Warnung, Bankrott-Dialog, Wochenlast in der Arztliste.
6. **Phase 6 – Regelwerk:** `team_rules.md` § 2.2 (Einnahmen inkl. passiv) / § 4.5 angleichen.
7. **Phase 7 – Küchen & Namens-Stämme (§ 9):** `Cuisine`-Enum, `RestaurantData.cuisine` + Migration, Küchenauswahl in `ScreenStart`, `Zone`-Durchreichen an Personal/Arzt.
8. **Phase 8 – Restauranterweiterungen (§ 10):** `UpgradeType`/`RestaurantData.upgrades`, `EconomyBalance.upgrades`, Effekt-/Unterhaltsfunktionen, Kauf/Ausbau-UI, Einbindung in § 8-Formeln und Wochen-Tick.
9. **Phase 9 – Restaurant-Screen-Redesign (§ 11):** Reiter-Struktur im `ScreenRestaurant`, Verschiebung von Personal/Karte/Erweiterungen in Tabs, l10n.

### Betroffene Dateien

| Datei | Änderung |
|---|---|
| `lib/services/economy_balance.dart` | **Neu:** zentrale Balance-Konstanten (V7) inkl. `upgrades`-Definitionen (§ 10) und Rebranding-Werten (§ 9) |
| `lib/services/game_clock_service.dart` | **Neu:** Echtzeit-Tick + Catch-up (V8) |
| `lib/services/economy_service.dart` | **Neu:** reine Wirtschaftsfunktionen (V2) inkl. `upgradeEffects`, `upgradeCost`, `upgradeUpkeepPerWeek`, `sellRefund` (§ 10) |
| `lib/models/cuisine.dart` | **Neu:** `enum Cuisine` + Mapping Küche → `Zone` (§ 9) |
| `lib/models/restaurant_upgrade.dart` | **Neu:** `enum UpgradeType` + Upgrade-Datenmodell (§ 10) |
| `lib/services/passive_income_service.dart` | **Neu:** Fuzzy-Inferenz „Kunden/Woche“ + passives Einkommen (§ 8) |
| `lib/models/profile_data.dart` | ggf. Billing-Anker; `kDefaultRestaurantBudget` auf `EconomyBalance` zeigen lassen; `RestaurantData.cuisine` (§ 9), `RestaurantData.upgrades` (§ 10) + `RestaurantData.lastMatchResult` (§ 8) |
| `lib/objects/object_profile.dart` | Literale → `EconomyBalance`; Budget-/Anker-Wirkung in `hireMedic`/`fireMedic`; Aufrufe von `EconomyService`; Fuzzy-Eingänge bereitstellen (Stadtteil, Personalstärke, Teamgesundheit); Küche/Erweiterungen anwenden (§ 9/§ 10) |
| `lib/objects/object_team_medic.dart`, `lib/objects/object_apprentice.dart` | Teamgröße in die Wochenkosten einbeziehen; Namens-`Zone` als Parameter statt hartkodiert `Zone.italy` (§ 9) |
| `lib/screens/screen_battle_result.dart` | Belohnung gutschreiben, Negativzinsen, Bankrott-Check |
| `lib/screens/screen_restaurant.dart` | Countdown/Warnung/Bankrott-Dialog; Anheuerkosten aus Konfiguration; Anzeige passives Einkommen/Kunden pro Woche; Reiter-Redesign (§ 11) + Erweiterungs-Tab (§ 10) |
| `lib/screens/screen_hire_and_fire.dart` | Anzeige der Wochenlast; Anker beim Anheuern |
| `lib/screens/screen_start.dart` | Catch-up beim Login; Küchenauswahl bei Restaurant-Erstellung (§ 9) |
| `lib/widgets/widget_caretaker.dart` | `moneyValue`-Summe der besiegten Gegner bereitstellen |
| `lib/l10n/app_de.arb`, `lib/l10n/app_en.arb` | neue Strings |
| `test/economy_service_test.dart`, `test/game_clock_service_test.dart`, `test/passive_income_service_test.dart` | **Neu:** Unit-Tests (Wirtschaft, Zeit, Fuzzy-Einkommen, Upgrade-Effekte § 10) |
| `doc/rules/team_rules.md` | § 2.2 Einnahmen (inkl. passives Einkommen), § 2.4 Namens-/Küchen-Thema, § 4.5 Arztkosten |

### Abnahmekriterien

- Das Budget ändert sich nach einem Gefecht um **Belohnung − Negativzinsen − Wiederbelebungskosten** und wird persistiert.
- Nach Tagen ohne App-Start werden beim nächsten Öffnen **alle fälligen Wochenabbuchungen** korrekt nachgeholt, angezeigt und gespeichert (`0-Base.md` V8).
- Erreicht/unterschreitet das Budget die Negativgrenze, folgt ein sichtbarer **Permadeath-Dialog**; das Restaurant ist danach aufgelöst und ein **neues Restaurant** kann gestartet werden (`reset()`).
- Teamarzt-Kosten hängen nachweislich von **Qualität und Teamgröße** ab (nicht mehr konstant 500 €).
- **Keine magischen Zahlen** mehr im Wirtschaftsfluss (V7); Balance-Änderungen sind nur an einer Stelle nötig.
- Neue Logik ist durch Unit-Tests abgedeckt (ohne Flutter-Widgets).
- Bei jedem Wochen-Tick wird **passives Einkommen** gutgeschrieben (Kunden/Woche × Satz) und ist kleiner als ein Gefechtserlös.
- Das passive Einkommen reagiert nachvollziehbar auf Stadtteil-Prestige, Personalstärke, Teamgesundheit und letztes Gefechtsergebnis; **ohne Personal entsteht kein Einkommen**.
- Fuzzy-Peaks und Sätze sind über `EconomyBalance` justierbar (V7).
- Bei der Restaurant-Erstellung ist eine **Küche** wählbar (§ 9); neu angeheuertes Personal und Teamärzte tragen den passenden Namensstamm, Alt-Spielstände bleiben italienisch.
- Ein nachträglicher Küchenwechsel (**Rebranding**, § 9) ist kostenpflichtig und hat spürbare wirtschaftliche Folgen.
- **Erweiterungen** (§ 10) sind gegen Budget kauf-/ausbaubar sowie **downgrade-/verkaufbar** (nicht unter die Negativgrenze); Kosten skalieren **linear mit der Stufe**. Sie wirken spürbar auf Attraktivität/Zufriedenheit/Kapazität (§ 8) und werden wöchentlich als Unterhalt abgebucht.
- Der Restaurant-Screen nutzt **Reiter** (§ 11: Aktives Personal · Passives Personal · Erweiterungen · Karte & Gefecht) und behält Kader-/Kartenauswahl sowie den Gefechtsbutton.

### Umsetzungshinweise

- **Heilung & Notfall-Spritze** (P3/V3) hängen am selben Zeitsystem (V8) und werden im Folge-Dokument behandelt; hier nur als Abhängigkeit erwähnt.
- **Tick-Länge (Entscheidung):** 1 Tick = 1 Echtzeitwoche (koppelt an V8). Kürzere Ticks (Stunde/Tag) wären eine spätere Erweiterung.
- **Prestige-Daten:** Stadtteilnamen kommen aus `assets/world/theworld.tmx`; `districtPrestige` hat Default 1.0, damit neue/unbekannte Stadtteile funktionieren.
- **Kapazitäts-Normalisierung:** `moneyValue` ist aktuell der Beutewert (`ObjectToken`); wird es später zu einer Service-Kennzahl umgedeutet, Formel/`capacityMoneyNorm` anpassen.
- **`districtPrestige`-Keys = TMX-Namen:** Die Keys müssen exakt den Namen der „Nachbarschaften“-Ebene in `assets/world/theworld.tmx` entsprechen. Achtung: das Asset enthält den Tippfehler **„Greenwhich Village / West Village“** – wird er im TMX korrigiert, muss der Map-Key mitgezogen werden, sonst fällt der Stadtteil auf den Default 1.0 zurück.
- **Skalen-Abgleich Prestige ↔ Fuzzy-Domäne:** **Entschieden (Phase 3):** Die Fuzzy-Eingangssets für Attraktivität und Kundenzufriedenheit liegen auf der Domäne **0–4** (siehe Balancing-Hinweis in § 8); dadurch passen die Attraktivitäts-Werte (~0.7–3.0) direkt in die Skala, höhere Werte sättigen in „Hoch“. Die crisp-Clamps wurden auf 0–4 angeglichen.
- **Musikautomat:** Einzel-Level (max. 1) mit +20 % Attraktivität – die Roh-Notiz enthielt „20&" und keine „/Stufe"-Angabe.
- **Erweiterungs-Unterhalt:** wird nach dem passiven Einkommen, aber vor den Negativzinsen abgebucht (§ 10).
- **Migration `costPerWeek` (Entscheidung):** beim nächsten Anheuern neu berechnen; bestehende Werte bis dahin beibehalten.
- **Verkaufserlös Erweiterungen (Entscheidung):** 50 % der investierten Anschaffungssumme; exakte Höhe in `EconomyBalance` justierbar.
- **Rebranding-Balance (Vorschlag):** einmalige Kosten (z. B. 5.000 €) plus zeitlich begrenzter Attraktivitäts-Malus – in Phase 7/3 zu justieren.

> **Hinweis:** Die frühere Roh-Notiz „Wirtschaftssystemupgrades → passives Einkommen“ ist vollständig in Abschnitt 8 übernommen und präzisiert (Eingangswerte, Fuzzy-Modell, Integration, Tests). Die weiteren Roh-Notizen (Küchen, Restauranterweiterungen, Screen-Redesign) sind in die Abschnitte 9–11 eingearbeitet.

## Nachtrag: Erledigte Restpunkte

Die nach dem Durchlauf offenen Punkte sind abgearbeitet:

### Balance-Tuning (V7/§ 8)
- **Fuzzy-Peaks/Sätze zentralisiert:** Alle Peaks des passiven Einkommens stehen jetzt in `EconomyBalance` (`fuzzyInputLowPeak/Mid/High`, `fuzzyCapacity*`, `fuzzyFewRepresentative`, `fuzzyCustomersMidPeak`, `customersDomainMax`). `PassiveIncomeService` enthält keine Literale mehr → Abnahmekriterium „über `EconomyBalance` justierbar" erfüllt.
- **Zufriedenheit getunt:** `satisfactionHealthWeight` `4.0 → **1.5**`. Vorher sättigte jedes gesunde Team die Zufriedenheit sofort am Clamp (4.0); Sieg-/Niederlage-Bonus, Erweiterungen und Rebranding-Malus waren wirkungslos.
- **„Wenig"-Repräsentant `0 → 20`:** Ein frisches Restaurant (nur Lehrlinge) erwirtschaftet jetzt ein kleines, aber spürbares passives Einkommen (statt 0 €). Max-Einkommen bleibt bei `100 Kunden × 5 € = 500 €/Woche` gedeckelt und damit unter üppigen Gefechtserlösen.
- **Absicherung:** Neuer `test/balance_sanity_test.dart` erzwingt die Verträge (Peaks geordnet/innerhalb der Domäne, alle Erweiterungen spezifiziert, frisches Restaurant > 0 €, gesunde Teams sättigen nicht, Max-Einkommen gedeckelt).

### Küchen-Art-Assets (§ 9)
- Neues Skript `scripts/generate_cuisine_tokens.py` erzeugt sechs unterscheidbare Küchen-Token (`assets/images/token/token_cook_<cuisine>.png`) aus der Basistoken-Grafik (Platzhalter-Art).
- `Cuisine.tokenImagePath` + `cuisine`-Parameter an `ObjectApprentice`/`ObjectLineCook`; `ObjectProfile.hireApprentice`/`upgradeToLineCook` geben die Restaurant-Küche durch.
- `ScreenRestaurant` zeigt die Küchen-Grafik im Personal-Avatar und als Header-Standardbild (eigenes Logo hat Vorrang); `ScreenCharacterDetail` nutzt sie bereits. Tests in `test/cuisine_test.dart` erweitert.

### Smoke-Test
- Neuer `test/smoke_test.dart`: bootet die echte `MainApp` (Start-Screen) ohne Exception und fährt den Restaurant-Hauptfluss (alle vier Reiter, Arztverwaltung, `ScreenBattleResult` inkl. Wirtschaftsabrechnung) durch. Läuft damit in CI (`flutter test`).

**Validierung:** `flutter analyze` ohne Fehler/Warnungen (nur die bereits vorher bestehenden 20 `info`-Lints); `flutter test` vollständig grün.

