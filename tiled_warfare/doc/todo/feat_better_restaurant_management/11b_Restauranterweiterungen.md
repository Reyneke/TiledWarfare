# Restauranterweiterungen

Die Restauranterweiterungen wurden in `2-Wirtschaftsschleife.md` § 10 angedacht und dort detailliert.
Dieses Dokument fasst sie zusammen, listet den **Ist-Stand mit konkreter Wirkung** und hält die
**Erweiterungsvorschläge** fest – analog zu `11a_Hilfs_und_Servicerollen.md`.

> **Hinweis:** Die Inhalte dieses Dokuments beeinflussen im späteren Verlauf die Inhalte des Dokuments **11a**
> (`11a_Hilfs_und_Servicerollen.md`) und werden daher gemeinsam entwickelt – insbesondere der **Plongeur**
> (senkt den Erweiterungs-Unterhalt) und der **Aboyeur** (wirkt auf das passive Einkommen aus § 8).
>
> **Schnittstelle (wer definiert, wer konsumiert):** Die Rollen sind in `11a` definiert und werden **hier**
> konsumiert: `SupportRoleService.upkeepReductionPercent(restaurant.supportStaff)` senkt den
> Erweiterungs-Unterhalt (Plongeur, −25 %); `SupportRoleService.incomePercent(...)` hebt das passive Einkommen
> (Aboyeur, +10 %, vor der Tagesaufteilung). Der Plongeur wird also erst durch den Erweiterungs-Unterhalt wertvoll.

**Einordnung:** Erweiterungen sind der **Browsergame-Ausbau** des Restaurants (§ 10). Sie wirken auf die drei
Eingangswerte des passiven Einkommens (§ 8) – **Attraktivität, Kundenzufriedenheit, Kapazität** – sind
stufenweise ausbaubar, kosten **Ankauf** und **wöchentlichen Unterhalt** und werden im Catch-up abgerechnet.

## Ist-Stand (umgesetzt)

**Status:** vollständig umgesetzt (Phase 8 in `2-Wirtschaftsschleife.md`, Commit `a723ad5`
„Wirtschaftsschleife schließen (V2/V7/V8)“; die Unterhaltsschnittstelle zum Plongeur kam mit V10/`7939be4`).
Werte verbindlich nur in `EconomyBalance` (V7); Auswertung in `EconomyService` (reine Funktionen),
Modell/Persistenz in `UpgradeType`/`UpgradeSpec`/`RestaurantData.upgrades`
(`kProfileSchemaVersion = 5`, additiv/tolerant).

### Aktuelle Auflistung aller Erweiterungen (tabellarisch)

| Erweiterung (DE) | Enum | Wirkung pro Stufe | Max-Stufe | Ankauf (Basis) | Erhalt/Woche (Basis) |
|---|---|---|---:|---:|---:|
| Mehr Tische | `UpgradeType.tables` | +1 % Kapazität, +1 % Kundenzufriedenheit | 5 | 100 € | 10 € |
| Größere Küche | `UpgradeType.kitchen` | +5 % Kapazität | 5 | 200 € | 20 € |
| Werbeplakate | `UpgradeType.signage` | +5 % Attraktivität | 5 | 150 € | 15 € |
| Dekorationen | `UpgradeType.decoration` | +2 % Attraktivität, +2 % Kundenzufriedenheit | 5 | 120 € | 12 € |
| Musikautomat | `UpgradeType.jukebox` | +20 % Attraktivität | 1 | 500 € | 50 € |

> Quelle: `EconomyBalance.upgrades` (V7). Bei Abweichung gilt der **Code**, nicht die Tabelle.
> `test/balance_sanity_test.dart` erzwingt, dass **jeder** `UpgradeType`-Wert einen Spec besitzt.

### Kosten- & Wirkungsmodell

- **Ankauf (kumulativ, linear):** Der Ausbau **auf** Stufe `N` kostet `Ankauf-Basis × N`; bis Stufe `N` sind
  `Ankauf-Basis × N·(N+1)/2` investiert (`EconomyService.upgradeCost`). Beispiel `tables` (Basis 100 €):
  Ausbau 1–5 je **100/200/300/400/500 €**, **kumulativ** 100/300/600/1.000/1.500 €.
- **Unterhalt (linear):** auf Stufe `N` `Erhalt-Basis × N` (`EconomyService.upgradeUpkeepPerWeek`), Summe über
  alle Erweiterungen `EconomyService.totalUpgradeUpkeepPerWeek`.
- **Wirkung (multiplikativ, vor dem Clamp):** `Basiswert × (1 + Σ Bonus)` – geliefert von
  `EconomyService.upgradeEffects(levels)` als `(capacity, attractiveness, satisfaction)`.
- **Verkauf:** erstattet **50 %** der investierten Ankaufssumme (`EconomyBalance.upgradeSellRefundRate`,
  `EconomyService.sellRefund`; kaufmännisch gerundet via `.round()`).
- **Downgrade:** stufenweise zurückbauen, **ohne** Erstattung – senkt nur den Unterhalt.

### Regeln & Konventionen

- **Invariante:** `0 ≤ Stufe ≤ maxLevel`; `upgradeLevel(type) == 0` bedeutet „nicht gebaut“.
- **Budget-Wächter:** Kauf nur, solange die Negativgrenze nicht unterschritten wird
  (`EconomyService.canAfford`) – derselbe Wächter wie bei Anheuern/Fortbildung.
- **Abrechnungsreihenfolge am Blockende:** passives Einkommen (täglich) → Teamarzt-Kosten → Wochenlöhne
  (Personal/Hilfsrollen) → **Erweiterungs-Unterhalt** → Negativzinsen → `WeekSettlement`/Bankrott-Check.
- **Plongeur:** senkt den Erweiterungs-Unterhalt **vor** der Buchung (prozentual, gerundet).
- **Musikautomat:** bewusst Einzelstufe (max. 1) – die Roh-Notiz enthielt keine „/Stufe“-Angabe
  (Entscheidung aus `2-Wirtschaftsschleife.md` § 10).

### Schnittstellen & Datenfluss

| Ebene | Artefakt |
|---|---|
| Modell | `enum UpgradeType`, `class UpgradeSpec` (`lib/models/restaurant_upgrade.dart`) |
| Balance | `EconomyBalance.upgrades`, `upgradeSellRefundRate` (`lib/services/economy_balance.dart`) |
| Logik | `EconomyService.upgradeEffects` · `upgradeCost` · `upgradeUpkeepPerWeek` · `totalUpgradeUpkeepPerWeek` · `sellRefund` |
| Mutation | `ObjectProfile.upgradeLevel` · `buyUpgrade` · `downgradeUpgrade` · `sellUpgrade` |
| Wirkung | `GameClockService.attractivenessOf`/`satisfactionOf`/`capacityOf` (Multiplikation **vor** dem Clamp) |
| Abrechnung | `GameClockService.catchUp` → `WeeklyTickResult.upgradeUpkeep` / `WeekSettlement.upgradeUpkeep` |
| Persistenz | `RestaurantData.upgrades` (`Map<UpgradeType, int>`; JSON-Keys = Enum-`name`, unbekannte Typen werden übersprungen) |
| UI | `ScreenRestaurant._buildUpgradesSection`/`_buildUpgradeTile` (Reiter 3, § 11) + l10n |

## Erweiterungsvorschläge („letzten Endes erweitert“)

Die bestehenden fünf Erweiterungen decken **Kapazität** und **Attraktivität** breit ab; die
**Kundenzufriedenheit** ist bisher nur über „Mehr Tische“ und „Dekorationen“ erreichbar. Die Vorschläge
schließen diese Lücke, docken an vorhandene Hebel an und bleiben Tuning in `EconomyBalance`:

| Vorschlag (Arbeitstitel) | Wirkung (Vorschlag) | Hebel | Anmerkung |
|---|---|---|---|
| Außenterrasse (`terrace`) | + Kapazität | `capacityOf` | wirkt nur mit Personal (Kapazität ist ohne Personal 0) |
| Beleuchtung / Klimaanlage | + Kundenzufriedenheit | `satisfactionOf` | schließt die Zufriedenheits-Lücke ohne Attraktivitäts-Nebenwirkung |
| Wein-/Getränkekeller (`cellar`) | + Kundenzufriedenheit | `satisfactionOf` | Überschneidung mit **Caviste** aus `11a` abklären | => Synergie, wenn Caviste eingestellt ist.
| Musikautomat auf 2–3 Stufen | + Attraktivität je Stufe | `EconomyBalance.upgrades` | löst die dokumentierte „Einzelstufe“-Entscheidung ab |
| Synergie **Maître d'hôtel** (11a) | + Kapazität | `capacityOf` | Rolle und Erweiterung dürfen sich **additiv** ergänzen, nicht ersetzen |
Erste Hilfe Station | bessere Chance auf Heilung | Synergie mit Arzt bei der Behandlung von Spielern.

**Bindeglied zu 8:** Da die Wirtschaft tag-genau durch die Lücke läuft (`8_Echtzeit-Zeitsystem.md`, Q1), können
künftige Erweiterungen als **zeitfenster-/tagesabhängige Modifikatoren** in den Eingangswert-Pfad einhängen –
analog zum bestehenden `rebrandingPenaltyUntil`-Fenster (z. B. Saison-Terrasse, Aktion „Werbeplakate“).

## Entscheidungen (getroffen)

- **Stufenmodell mit linearem, kumulativem Preis** – Ausbau auf Stufe `N` kostet `Basis × N`, insgesamt
  `Basis × N·(N+1)/2`; der Unterhalt wächst linear (`Basis × N`).
- **Erweiterungen sind verkauf- und downgradebar.** Verkauf erstattet **50 %** der investierten
  Ankaufssumme; Downgrade senkt nur den Unterhalt (keine Erstattung).
- **Wirkung multiplikativ vor dem Clamp** (`Basiswert × (1 + Σ Bonus)`) – **nicht** binär wie bei den
  Hilfs-/Service-Rollen (`11a`): hier zählt die **Stufe**, dort die **Anwesenheit**.
- **Abrechnung nach den Teamarzt-Kosten, vor den Negativzinsen** – feste Reihenfolge im Wochenblock.
- **Musikautomat als Einzelstufe** (die Roh-Notiz nannte keinen „/Stufe-Wert“).
- **Alle Werte zentral in `EconomyBalance`** (V7) – keine Literale im Fluss.

## Offene Punkte

- **DRY (Refactoring):** Die Delta-Kosten `upgradeCost(current + 1) − upgradeCost(current)` werden in
  `ObjectProfile.buyUpgrade` **und** in `ScreenRestaurant._buildUpgradeTile` dupliziert. Empfehlung:
  gemeinsame reine Funktion `EconomyService.upgradeCostDelta(type, fromLevel)` und beide Aufrufer darauf
  umstellen.
- **Verkauf ohne Bestätigung:** `_sellUpgrade` bucht sofort (nur Snackbar) – bei hohen Stufen mit relevantem
  Invest ein unbeabsichtigter Verlust; Bestätigungsdialog analog zu Anheuern/Entlassen prüfen.
- **Defensive Doppelabsicherung:** `EconomyService.upgradeCost` clampt `toLevel` auf `maxLevel`, obwohl
  `buyUpgrade` die Max-Stufe bereits prüft. Invariante dokumentiert lassen oder Guard zusammenführen.
- **Rundungssemantik:** `sellRefund` nutzt `.round()`, `applyNegativeInterest` `.ceil()` – bewusst festhalten
  (oder vereinheitlichen), damit Balance-Erwartungen stabil bleiben.
- **Balance-Verhältnis prüfen:** Gegenwert je Erweiterung (z. B. `tables` kumulativ 1.500 € für +5 % Kapazität
  und +5 % Zufriedenheit vs. `jukebox` 500 € für +20 % Attraktivität) in einer eigenen Balance-Runde
  gegenüberstellen.
- **Kapazitäts-Normalisierung:** Die Kapazitäts-Wirkung hängt an `capacityMoneyNorm`/`moneyValue`
  (offene Frage aus § 8). Wird `moneyValue` später umgedeutet, wirken Kapazitäts-Erweiterungen anders.
- **Abstimmung mit `11a`:** Neue Erweiterungen, die Rollenwirkungen überschneiden (z. B. Weinkeller ↔
  Caviste), vermeiden bzw. bewusst als Ergänzung definieren.
- **Anschaffungspreis-Rabatt (V11):** Die **Chefsekretärin** (`11a` E12) mindert den **Anschaffungspreis** von
  Erweiterungen um 5 % (`chefSecretaryUpgradeCostReductionPercent`) – die UI zeigt den geminderten Preis
  (`ObjectProfile.upgradePurchaseCost`), der **Unterhalt bleibt unberührt**. Der Buchhalter („alle laufenden
  Kosten“) mindert dagegen den **Unterhalt** im Wochen-Tick. Balance-Erwartungen der Tabelle oben gelten daher
  relativ (ohne Rollen).

## Checkliste für eine neue Erweiterung (Doku ↔ Code)

1. `UpgradeType`-Enum um den neuen Wert erweitern (`lib/models/restaurant_upgrade.dart`).
2. `UpgradeSpec` in `EconomyBalance.upgrades` ergänzen (MaxLevel, Ankauf-/Erhalt-Basis, Boni) – V7,
   keine Literale außerhalb der Balance.
3. `EconomyService.upgradeEffects` deckt neue Boni automatisch ab (Spec-getrieben); `upgradeCost`/
   `upgradeUpkeepPerWeek`/`sellRefund` ebenfalls.
4. Hook verdrahten: Bonus auf `attractivenessOf`/`satisfactionOf`/`capacityOf` (nur falls der Eingangswert
   nicht bereits über `upgradeEffects` abgedeckt ist) **oder** Zusatzbuchung in `catchUp`.
5. UI-Tile (Reiter 3, `ScreenRestaurant`) + l10n-Schlüssel DE/EN (`upgrade<Typ>`, ARB-Dateien, `get gen-l10n`).
6. Tests ergänzen: `test/economy_service_test.dart`, `test/game_clock_service_test.dart`,
   `test/screen_restaurant_test.dart`, `test/profile_data_test.dart`, `test/balance_sanity_test.dart`.
7. Regelwerk angleichen: `doc/rules/team_rules.md` § 2.2 (laufende Ausgaben: Erweiterungs-Unterhalt).

## Anhang: Belege

- Modell: `lib/models/restaurant_upgrade.dart` (`UpgradeType`, `UpgradeSpec`)
- Balance: `lib/services/economy_balance.dart` (`upgrades`, `upgradeSellRefundRate`) · Logik:
  `lib/services/economy_service.dart` (`upgradeEffects`, `upgradeCost`, `upgradeUpkeepPerWeek`,
  `totalUpgradeUpkeepPerWeek`, `sellRefund`, `canAfford`)
- Zeit/Abrechnung: `lib/services/game_clock_service.dart` (`catchUp`, `attractivenessOf`/`satisfactionOf`/
  `capacityOf`, `WeeklyTickResult`, `WeekSettlement`)
- Persistenz: `lib/models/profile_data.dart` (`RestaurantData.upgrades`, `kProfileSchemaVersion = 5`) ·
  Mutation/UI: `lib/objects/object_profile.dart` (`upgradeLevel`/`buyUpgrade`/`downgradeUpgrade`/`sellUpgrade`),
  `lib/screens/screen_restaurant.dart` (`_buildUpgradesSection`/`_buildUpgradeTile`)
- l10n: `lib/l10n/app_de.arb`/`app_en.arb` (`upgradesSection`, `upgradeTables`/`upgradeKitchen`/
  `upgradeSignage`/`upgradeDecoration`/`upgradeJukebox`, `upgradeBuy`/`upgradeDowngrade`/`upgradeSell`,
  `upgradeUpkeepCost`, `upgradeBuyCost`, `upgradeMaxReached`, `upgradeNotEnoughBudget`, `tabUpgrades`)
- Tests: `test/economy_service_test.dart`, `test/game_clock_service_test.dart`, `test/screen_restaurant_test.dart`,
  `test/profile_data_test.dart`, `test/balance_sanity_test.dart`
- Doku: `2-Wirtschaftsschleife.md` § 10 (Bezug: § 8, § 11) · `7_Wirtschaftswerte_zentralisieren.md` ·
  `8_Echtzeit-Zeitsystem.md` (Q1/Tagesschritt) · `10_Karrierepfade.md` § 3 ·
  `11a_Hilfs_und_Servicerollen.md` (Plongeur/Aboyeur) · `doc/rules/team_rules.md` § 2.2
