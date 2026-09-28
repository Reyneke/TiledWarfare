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
Der erste Baustein des **V1-Pakets** aus diesem Dokument (`cellar`, Gruppe A) ist ebenfalls umgesetzt, ebenso der
zweite (`coldRoom`, Gruppe B) und der dritte (`firstAid`, Gruppe B, erster ⚙-Baustein) – Beleg und
Checklisten-Abarbeitung unter „Abgeschlossene Klärungen“.
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
| Wein-/Getränkekeller | `UpgradeType.cellar` | +2 % Kundenzufriedenheit, +1 % Attraktivität | 5 | 180 € | 18 € |
| Kühlhaus/Kühlkette | `UpgradeType.coldRoom` | +3 % Kapazität | 5 | 160 € | 16 € |
| Erste-Hilfe-Station | `UpgradeType.firstAid` | −5 % Heilzeit pro Verletzungsstufe | 3 | 250 € | 25 € |

> Quelle: `EconomyBalance.upgrades` (V7). Bei Abweichung gilt der **Code**, nicht die Tabelle.
> `test/balance_sanity_test.dart` erzwingt, dass **jeder** `UpgradeType`-Wert einen Spec besitzt.
> `cellar` ist der erste Baustein des **V1-Pakets** (Gruppe A) und die Wirkungsbasis des **Sommeliers** (`11a`);
> `coldRoom` ist der zweite (Gruppe B) und die Kapazitäts-Basis des **Lageristen** (`11a`, V12);
> `firstAid` ist der dritte (Gruppe B) und der erste **⚙-Baustein** – er speist **keinen** der drei
> Eingangswerte, sondern verkürzt die Heilzeit (`healTimePerStageFor`, § 10).

### Kosten- & Wirkungsmodell

- **Ankauf (kumulativ, linear):** Der Ausbau **auf** Stufe `N` kostet `Ankauf-Basis × N`; bis Stufe `N` sind
  `Ankauf-Basis × N·(N+1)/2` investiert (`EconomyService.upgradeCost`). Beispiel `tables` (Basis 100 €):
  Ausbau 1–5 je **100/200/300/400/500 €**, **kumulativ** 100/300/600/1.000/1.500 €.
- **Unterhalt (linear):** auf Stufe `N` `Erhalt-Basis × N` (`EconomyService.upgradeUpkeepPerWeek`), Summe über
  alle Erweiterungen `EconomyService.totalUpgradeUpkeepPerWeek`.
- **Wirkung (multiplikativ, vor dem Clamp):** `Basiswert × (1 + Σ Bonus)` – geliefert von
  `EconomyService.upgradeEffects(levels)` als `(capacity, attractiveness, satisfaction)`.
  Die vierte Summe `healTime` des Records wirkt **nicht** auf die drei Eingangswerte, sondern als Faktor auf die
  Heilzeit pro Verletzungsstufe (`GameClockService.healTimePerStageFor`, § 10 `firstAid`).
- **Verkauf:** erstattet **50 %** der investierten Ankaufssumme (`EconomyBalance.upgradeSellRefundRate`,
  `EconomyService.sellRefund`; kaufmännisch gerundet via `.round()`).
- **Downgrade:** stufenweise zurückbauen, **ohne** Erstattung – senkt nur den Unterhalt.
- **Basis-Werte ohne Rollen (V11):** Alle Beträge der Tabellen sind **Referenzwerte ohne Personal**. Zwei
  Rollen greifen darauf zu:
  - **Chefsekretärin** (`11a` E12) mindert den **Anschaffungspreis** der nächsten Stufe
    (`StaffRoleService.chefSecretaryUpgradeCostReductionPercent` → `ObjectProfile.upgradePurchaseCost`; die UI
    zeigt den geminderten Wert) – der **Unterhalt bleibt unberührt**.
  - **Plongeur** (`SupportRoleService.upkeepReductionPercent`, −25 %) und **Buchhalter** („alle laufenden
    Kosten“, −5 %, `accountantOngoingCostReductionPercent`) mindern den **Unterhalt** im Wochen-Tick
    (`GameClockService.catchUp`, kaufmännisch gerundet).

### Regeln & Konventionen

- **Invariante:** `0 ≤ Stufe ≤ maxLevel`; `upgradeLevel(type) == 0` bedeutet „nicht gebaut“.
- **Budget-Wächter:** Kauf nur, solange die Negativgrenze nicht unterschritten wird
  (`EconomyService.canAfford`) – derselbe Wächter wie bei Anheuern/Fortbildung.
- **Abrechnungsreihenfolge am Blockende:** passives Einkommen (täglich) → Teamarzt-Kosten → Wochenlöhne
  (Personal/Hilfsrollen) → **Erweiterungs-Unterhalt** → Negativzinsen → `WeekSettlement`/Bankrott-Check.
- **Plongeur:** senkt den Erweiterungs-Unterhalt **vor** der Buchung (prozentual, gerundet).
- **Musikautomat:** bewusst Einzelstufe (max. 1) – die Roh-Notiz enthielt keine „/Stufe“-Angabe
  (Entscheidung aus `2-Wirtschaftsschleife.md` § 10). Achtung: Der bestätigte Vorschlag „Musikautomat auf
  2–3 Stufen“ (Gruppe C) löst diese Entscheidung ab, sobald er übernommen wird – siehe „Entscheidungen“.

### Schnittstellen & Datenfluss

| Ebene | Artefakt |
|---|---|
| Modell | `enum UpgradeType`, `class UpgradeSpec` (`lib/models/restaurant_upgrade.dart`) |
| Balance | `EconomyBalance.upgrades`, `upgradeSellRefundRate` (`lib/services/economy_balance.dart`) |
| Logik | `EconomyService.upgradeEffects` · `upgradeCost` · `upgradeCostDelta` · `upgradeUpkeepPerWeek` · `totalUpgradeUpkeepPerWeek` · `sellRefund` |
| Mutation | `ObjectProfile.upgradeLevel` · `buyUpgrade` · `downgradeUpgrade` · `sellUpgrade` |
| Wirkung | `GameClockService.attractivenessOf`/`satisfactionOf`/`capacityOf` (Multiplikation **vor** dem Clamp) · `healTimePerStageFor` (`firstAid`, Faktor auf die Heilzeit pro Verletzungsstufe) |
| Abrechnung | `GameClockService.catchUp` → `WeeklyTickResult.upgradeUpkeep` / `WeekSettlement.upgradeUpkeep` |
| Persistenz | `RestaurantData.upgrades` (`Map<UpgradeType, int>`; JSON-Keys = Enum-`name`, unbekannte Typen werden übersprungen) |
| UI | `ScreenRestaurant._buildUpgradesSection`/`_buildUpgradeTile` (Reiter 3, § 11) + l10n |

## Erweiterungsvorschläge („letzten Endes erweitert“)

Die bestehenden fünf Erweiterungen decken **Kapazität** und **Attraktivität** breit ab; die
**Kundenzufriedenheit** ist bisher nur über „Mehr Tische“ und „Dekorationen“ erreichbar. Die Vorschläge
schließen diese Lücke, docken an vorhandene Hebel an und bleiben Tuning in `EconomyBalance`.

**Design-Leitlinien (aus dem Ist-Stand abgeleitet):**

- **Clamp-Sättigung beachten:** Attraktivität/Zufriedenheit sind auf **0–4** geclampt (Kapazität 0–20).
  Weitere prozentuale Attraktivitäts-Boni (Stil `signage`/`jukebox`) sättigen schnell – neue Erweiterungen
  sollen vor allem die **Zufriedenheits-/Kapazitäts-Lücke** schließen.
- **Plongeur-Muster (11a-Synergie):** Eine gute Erweiterung **schafft die Wirkungsbasis** für eine Rolle
  (der Plongeur ist erst mit Erweiterungs-Unterhalt wertvoll). Neue Vorschläge machen möglichst eine
  **offene** Rolle wertvoll (Sommelier, Caissier, Strafen-Quellen).
- **Additiv statt Multiplikator:** Rolle und Erweiterung dürfen sich **additiv** ergänzen, **nicht** ersetzen –
  kein Multiplikator-auf-Multiplikator.
- **Hook-Typ trennen:** ▶ = reines `UpgradeSpec` (Bonus auf die drei Eingangswerte, automatisch über
  `EconomyService.upgradeEffects`); ⚙ = **neuer Hook** („Zusatzbuchung“ laut Checkliste Punkt 4). Muster für
  einen ⚙-Hook mit Balance-Feld: eigener `UpgradeSpec`-Wert (Beispiel `healTimeReductionPerLevel`), den
  `upgradeEffects` als zusätzliche Summe mitliefert und der **an der Wirkungsstelle** als Faktor greift
  (`firstAid` → `healTimePerStageFor`).

> **Bereits aufgegangen (11a/V12):** „Maître d'hôtel“ ist der **Oberkellner** (+5 % Kapazität),
> „Caviste/Magasinier“ der **Lagerist** (+20 % Kapazität, Feature „Lagertetris“); die alten Zeilen
> „Synergie Maître d'hôtel“ und „Weinkeller ↔ Caviste“ sind damit **erledigt bzw. neu gemappt** (siehe unten
> und `11a` → „Zuordnung Rolle ↔ Erweiterung“).

### Gruppe A – Lücken schließen und offene Rollen aus `11a` wertvoll machen

| Erweiterung (Arbeitstitel) | Wirkung pro Stufe (Vorschlag) | Max | Ankauf (Basis) | Unterhalt (Basis) | Hook | Synergie `11a` |
|---|---|---:|---:|---:|---|---|
| Wein-/Getränkekeller (`cellar`) ▶ **umgesetzt** ✅ | +2 % Kundenzufriedenheit, +1 % Attraktivität | 5 | 180 € | 18 € | `satisfactionOf`/`attractivenessOf` | **Sommelier** (offen): Zuschlag greift nur mit gebautem Keller → „der Sommelier wird erst durch den Weinkeller wertvoll“ (Plongeur-Muster) |
| Tresor/Kassenraum (`vault`) ⚙ | Negativzinsen −10 % | 3 | 200 € | 20 € | `catchUp` → `applyNegativeInterest` (um Prozent-Parameter erweitern) | **Caissier** (offen): −25 % auf den Zinssatz, stapelt **additiv**; reiner Verlustbegrenzer, kein Einkommenshebel |

### Gruppe B – Synergien mit umgesetzten Rollen/Systemen

| Erweiterung (Arbeitstitel) | Wirkung pro Stufe (Vorschlag) | Max | Ankauf (Basis) | Unterhalt (Basis) | Hook | Synergie `11a` / System |
|---|---|---:|---:|---:|---|---|
| Kühlhaus/Kühlkette (`coldRoom`) ▶ **umgesetzt** ✅ | +3 % Kapazität | 5 | 160 € | 16 € | `capacityOf` | **Lagerist** (V12): verbreitert die Basis, die „Lagertetris“ faktorbasiert vervielfacht (additiv, kein Doppel-Multiplikator); wirkt nur **skalierend** – ohne Personal ist die Kapazität ohnehin `0` |
| Erste-Hilfe-Station (`firstAid`) ⚙ **umgesetzt** ✅ | **−5 % Heilzeit je Stufe** (entschieden; die Alternative „+1 Rettungswurf-Zielwert“ wurde **verworfen**) | 3 | 250 € | 25 € | `GameClockService.healTimePerStageFor` (von `advanceHealing`, `rollBackEmergencyShots` **und** dem UI-Countdown genutzt) | **Teamarzt** (Behandlung, `healTimePerStage`): verkürzt die vom Arzt **gesetzte** Basiszeit (24 h/6 h/3 h/1 h) prozentual – kein zweiter Hebel auf den Rettungswurf, der die Domäne des Arztes bleibt |
| Ruheraum/Lounge (`lounge`) ⚙ | +3 % Wochen-Refill **und** −3 % Tages-Sink | 3 | 180 € | 18 € | `_refillStaffResources`/`_applyDailyResourceSink` | **Communard + Pâtissier** (Refill), **Gewerkschaftschef** (Sink, additiv), **Tournant** (Nulltag-Malus) |
| Schulungsraum/Trainingsküche (`school`) ⚙ | −5 % Fortbildungskosten **oder** Sieg-XP +2 % | 3 | 300 € | 30 € | `upgradeToLineCook`/Karriereaufstiege bzw. `ScreenBattleResult` | **Karrierepfade (10)** und **PR-Kampagne** des Social Media Managers (beide XP, additiv) – verbindet Wirtschafts- und Kampf-Loop |
| Sicherheitstechnik/Alarmanlage (`security`) ⚙ | Entdeckung eingehender Sabotage +5 % (alternativ Abschöpfung −5 %) | 3 | 220 € | 22 € | `RivalService.incomingDetectionPercent` bzw. Einkommens-Abschöpfung im `catchUp` | **Sicherheitschef** (V13, additiv), Kapitel 13 – macht Erweiterungen **defensiv** relevant |

### Gruppe C – Zeitfenster/Tages-Aktionen (Bindeglied zu § 8/Q1)

| Erweiterung (Arbeitstitel) | Wirkung | Mechanik | Abgrenzung |
|---|---|---|---|
| Wochenkarte/Genusswoche (`weeklyMenu`) ⚙ | Aktivierbarer **Tageszustand**: +X % auf einen Eingangswert (bzw. Einkommen) für N Tage; steigende Wiederholungskosten, **eine** aktive Karte | Positives Gegenstück zu `rebrandingPenaltyUntil` (Q1) | **11a-Features sind Personal-Aktionen** (Träger/Kompetenz/Nachteilphase); die Wochenkarte ist ein **struktureller, aktivierbarer Zustand** mit Ablaufdatum – Abgrenzung im Doku-Text fixieren |
| Saison-Terrasse (`terrace`) ▶ | +Kapazität je Stufe, tages-/prestigeabhängig moduliert | Erster Testfall für zeitfensterabhängige Modifikatoren (Q1) | Wirkt nur mit Personal (Kapazität ist ohne Personal 0) |
| Lieferdienst (`delivery`) ⚙ (spät) | **Zweite Einkommensschiene**: flaches Tageseinkommen je Stufe, unabhängig von den drei Eingangswerten | Eigene Buchungszeile + eigene Obergrenze im `catchUp` | Bricht die „alles über Fuzzy-Eingänge“-Regel → erst nach Erfahrung mit der Wochenkarte |

**Weitere bestätigte bestehende Vorschläge:** **Beleuchtung/Klimaanlage** (▶, +Kundenzufriedenheit, schließt
die Zufriedenheits-Lücke ohne Attraktivitäts-Nebenwirkung) und **Musikautomat auf 2–3 Stufen** (▶, +Attraktivität
je Stufe – löst die dokumentierte „Einzelstufe“-Entscheidung ab).

### Gruppe D – Vorbereitung Strafen/Prestige (`13`/`12`)

| Erweiterung (Arbeitstitel) | Wirkung pro Stufe | Max | Ankauf (Basis) | Unterhalt (Basis) | Hook | Synergie / Vorbereitung |
|---|---|---:|---:|---:|---|---|
| Zertifizierung/Hygiene-Siegel (`certification`) ⚙ | erlittene Strafen −5 % | 3 | 200 € | 20 € | Strafbuchung im Tick (`penaltyCosts`) | **Rechtsanwalt** (additiv, bis 100 % kappbar) – wirkungslos ohne eigene Strafenquelle → **gekoppelt** mit der offenen `11a`-Position „Behörden/Inspektionen“ als neuer Strafenquelle |
| Sterneküche/Auszeichnung (`stars`) ⚙ | +Prestige-Beitrag/Ranglisten-Position; optional seltener Sabotage-Ziel | 5 | 400 € | 40 € | `districtPrestigeFor`/`RivalService`-Zielauswahl | Vorbereitend für **12** (Mini-PP, „Platz X von Y“) und **13** (Rivalen) – erst nach deren offenen Punkten |

**Priorisierung („V1-Paket“):** `cellar` ✅ **umgesetzt** → `coldRoom` ✅ **umgesetzt** → `firstAid` ✅ **umgesetzt** → `lounge`;
danach `school`/`security`,
zuletzt die Zeitfenster-/Prestige-Bausteine (`weeklyMenu`, `terrace`, `delivery`, `certification`, `stars`).
Vor dem Bau der Folge-Bausteine sind deren offene Wirkungs-Optionen zu entscheiden (`school`: −5 %
Fortbildungskosten **oder** +2 % Sieg-XP; `security`: +5 %
Entdeckung **oder** −5 % Abschöpfung). Bei `firstAid` ist die Option **entschieden** (Heilzeit, siehe
Entscheidungen) und der Hook gebaut.

**Bewusst nicht vorgeschlagen:** weitere reine Attraktivitäts-%-Boni (Clamp 0–4), eine „Bar“ neben dem Keller
(Doppel-Hebel Zufriedenheit), Einkommens-Multiplikatoren auf bestehende Einkommens-%-Boni (verletzt das
additive Stapeln aus `11a`).

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
- **Musikautomat als Einzelstufe** (die Roh-Notiz nannte keinen „/Stufe-Wert“) – **überholt** durch den
  bestätigten Vorschlag „Musikautomat auf 2–3 Stufen“ (Gruppe C), sobald dieser übernommen wird.
- **Alle Werte zentral in `EconomyBalance`** (V7) – keine Literale im Fluss.
- **Clamp bleibt – bewusst doppelt:** `EconomyService.upgradeCost`/`upgradeUpkeepPerWeek` klemmen die Stufe
  defensiv auf `0..maxLevel` (reine Rechenfunktionen werfen nicht und sind auch für überschießende Stufen
  definiert); `ObjectProfile.buyUpgrade` bleibt der **Wächter** der Invariante. Das Clamp ist Vertrag und wird
  vom Test `upgradeCost(jukebox, 5) == 500` (`test/economy_service_test.dart`) festgehalten – **nicht**
  zusammenführen.
- **Rundung bewusst unterschiedlich:** `sellRefund` rundet **kaufmännisch** (`.round()`), weil Geld an den
  Spieler zurückfließt und das konsistent zur Minderung ist (`StaffRoleService.reduceByPercent`,
  Plongeur-Unterhalt im Tick); `applyNegativeInterest` rundet **auf** (`.ceil()`), damit der Zins nie zu
  Gunsten des Schuldners abgerundet wird. Bei ganzzahligen Basispreisen ist `investierte Summe × 0,5` ohnehin
  ganzzahlig – das Runden ist dort ein Sicherheitsnetz.
- **Verkauf nur nach Bestätigung:** `ScreenRestaurant._sellUpgrade` nennt im Dialog die Erstattung
  (`upgradeSellConfirm(refund)`) und bucht erst nach Bestätigung; der **Downgrade** bleibt bewusst ohne
  Rückfrage (kostet nichts, senkt nur den Unterhalt).
- **`firstAid`: Heilzeit statt Rettungswurf (entschieden).** Von den beiden diskutierten Wirkungs-Optionen
  wurde **−5 % Heilzeit je Stufe** gewählt, nicht „+1 Rettungswurf-Zielwert“:
  - Der **Rettungswurf** (`ObjectProfile._performSurvivalRolls`, Basis 50 + 10×Level + Verteidigung +
    Arzt-Bonus 10–30 − Overkill − Erschöpfung) ist die **Domäne des Teamarztes**; ein +3 aus einem Baustein
    wäre ein **zweiter Hebel auf denselben Zielwert** und liefe im oberen Bereich gegen den 100er-Clamp.
  - Die **Heilzeit** war bis dahin **ungehebelt** und wirkt **deterministisch** sowie **ständig** (jede
    Verletzung, jeder Catch-up) über die ganze Kette `dying → … → ready`, statt nur beim seltenen
    Gefechts-Todeswurf (RNG).
  - Sie verkürzt die vom Arzt **gesetzte** Basiszeit (24 h/6 h/3 h/1 h) und ist damit **kein** Doppel-Hebel:
    die Rolle **setzt** die Basis, die Erweiterung **verkürzt** sie.
  - Hook bewusst am **einzigen** Entstehungsort `GameClockService.healTimePerStageFor`, damit Rechnung
    (`advanceHealing`, `rollBackEmergencyShots`) und UI-Countdown (`remainingHealingTime`) identisch laufen;
    der Faktor ist defensiv auf `> 0` und das Ergebnis auf ≥ 1 s geklemmt (sonst fiele die Heilung ein).
  - Der in der Synergie-Spalte angedachte **Unterhebel `revivalCost`** bleibt bewusst **ungebaut** („Wahl
    einer** Wirkungs-Option“, kein Doppel-Effekt).

### Balance-Runde: Gegenwert je Erweiterung (Vergleich)

Werte aus `EconomyBalance.upgrades` (ohne Rollen). Der Unterhalt ist bei **allen** Erweiterungen **10 %** der
Ankauf-Basis, daher folgt die Unterhalts-Rangfolge der Ankaufs-Rangfolge:

| Erweiterung | Wirkung auf Maximalstufe | Σ Wirkungs-% | Kumulativ | Unterhalt/Woche | € je Wirkungs-%-Punkt | Sättigung |
|---|---|--:|--:|--:|--:|---|
| `tables` | +5 % Kapazität, +5 % Zufriedenheit | 10 | 1.500 € | 50 € | 150 € | Zufriedenheit (Clamp 0–4) |
| `kitchen` | +25 % Kapazität | 25 | 3.000 € | 100 € | 120 € | Kapazität (Clamp 0–20, viel Luft) |
| `signage` | +25 % Attraktivität | 25 | 2.250 € | 75 € | 90 € | Attraktivität sättigt früh |
| `decoration` | +10 % Attraktivität, +10 % Zufriedenheit | 20 | 1.800 € | 60 € | 90 € | Attraktivität/Zufriedenheit |
| `jukebox` | +20 % Attraktivität | 20 | 500 € | 50 € | **25 €** | Einzelstufe, Attraktivität sättigt früh |
| `cellar` (V1-Paket) | +10 % Zufriedenheit, +5 % Attraktivität | 15 | 2.700 € | 90 € | 180 € | Zufriedenheit (Clamp 0–4) |
| `coldRoom` (V1-Paket) | +15 % Kapazität | 15 | 2.400 € | 80 € | 160 € | Kapazität (Clamp 0–20, viel Luft) |

**Lesart:** `jukebox` ist der bewusste **Flagship-Ausreißer** – billigster €/%-Punkt, aber 500 € Einstieg in
einem Zug, keine Granularität und der sättigungsanfälligste Kanal. `tables` ist pro Wirkungs-Punkt am
teuersten, weil der Ausbau gleichzeitig **zwei** Eingänge (Kapazität **und** Zufriedenheit) speist;
`cellar` liegt bewusst **noch darüber** (180 €/%-Punkt): Er ist der einzige **zufriedenheitszentrierte**
Hebel mit voller Granularität (5 Stufen × 2 %) und damit der Gegenwert zur vergleichsweise billigen, aber
früh sättigenden Attraktivitäts-Schiene. `coldRoom` liegt mit 160 €/%-Punkt zwischen `kitchen` (120 €) und
`cellar` (180 €): Der **Einstieg** ist mit 160 € je Stufe günstiger als `kitchen` (200 €), dafür bringt jede
Stufe nur **+3 %** statt +5 % – langsamer Progression zu etwas höherem Preis. Das ist Absicht: Kapazität ist
der Kanal mit dem **größten Kopfraum** (Clamp 20 statt 4), und `coldRoom` ist zugleich der **Einstieg in die
Lageristen-Schiene** (V12). Anders als die übrigen Boni ist er **rein skalierend** – ohne Personal bleibt die
Kapazität `0`, der Baustein erzeugt also keine Basis, sondern verstärkt eine vorhandene. Weil alle
Boni **multiplikativ vor dem Clamp** wirken, verlieren Attraktivitäts-/Zufriedenheits-Boni im späten Spiel
einen Teil ihrer Wirkung – das ist die natürliche Obergrenze des Modells, kein Fehler.

**Entscheidung:** Werte **beibehalten** (V1). Ein Retune (z. B. `jukebox`-Ankauf-Basis 800–1.000 € oder
Verbilligung von `signage`/`decoration`) wird erst auf Datenlage entschieden; `jukebox` ist dafür der erste
Kandidat. Der `cellar`-Preis (180 €/18 €) wird in derselben Datenlage-Runde mitgeprüft – sein Ankauf liegt
im Mittelfeld, sein €/%-Wert ist bewusst der höchste (Zufriedenheit ist der knappste Kanal). Gleiches gilt für
`coldRoom` (160 €/16 €): günstiger Einstieg, aber der zweithöchste €/%-Wert des Sets (Kapazitäts-Schiene mit
Lageristen-Perspektive).

**`firstAid` steht außerhalb dieser €/%-Punkt-Logik:** Der Baustein speist **keinen** der drei Eingangswerte,
sondern verkürzt die Heilzeit. Sein Verhältnis ist 250 € pro Stufe für **−5 % Heilzeit** (also 1.500 €
kumuliert auf Maximum für −15 %); da „Heilzeit-%“ nicht gegen Attraktivitäts-/Zufriedenheits-Prozentpunkte verrechenbar ist,
wird er **nicht** in die €/%-Rangfolge einsortiert – sein Preis ist bewusst der höchste Einzelpreis-Stufe des
Sets (250 €, knapp über `kitchen` 200 €), weil er als einziger einen **kritischen Pfad** (Ausfallzeit von
Personal) verkürzt und damit indirekt die Verfügbarkeit des Einkommenshebel-Trägers erhöht. Bewusst nur
**3 Stufen** (statt 5): Der Hebel ist ein **Zeit-Faktor** und soll nicht beliebig weit skalieren – bei 15 %
bleibt die Heilung immer noch spürbar lang (Kette `dying → ready` = 5 Stufen × 20 h 24 min ≈ 4,25 Tage).

## Abgeschlossene Klärungen (vormals offene Punkte)

- **V1-Paket gestartet – `cellar` umgesetzt (Checkliste 1–7 abgearbeitet):** `UpgradeType.cellar` +
  `UpgradeSpec` (max. 5 Stufen, 180 €/18 €, +2 % Zufriedenheit & +1 % Attraktivität je Stufe) – damit ist
  die Zufriedenheits-Lücke geschlossen und die Wirkungsbasis des **Sommeliers** (`11a`) vorhanden.
  Kein neuer Hook nötig: reines ▶-`UpgradeSpec`, die Boni laufen automatisch über
  `EconomyService.upgradeEffects` in `satisfactionOf`/`attractivenessOf` (Checklisten-Punkt 4 entfällt).
  l10n `upgradeCellar` (DE „Wein-/Getränkekeller“ / EN „Wine/drinks cellar“) + Kachel im Reiter
  „Erweiterungen“ (`UpgradeType.values`-getrieben, nur `_upgradeName` brauchte einen Fall).
  Tests: `test/economy_service_test.dart` („Keller (V1-Paket) speist Zufriedenheit vor Attraktivität“),
  `test/game_clock_service_test.dart` („Keller-Erweiterung wirkt auf Zufriedenheit & Attraktivität“,
  „Keller-Unterhalt wird im Wochenblock abgebucht“ → 90 €/Woche auf Stufe 5),
  `test/screen_restaurant_test.dart` („Keller-Kachel ist ausbaubar“, Budget −180 €),
  `test/balance_sanity_test.dart` erzwingt die Spec. `team_rules.md` § 2.2 nannte den Erweiterungs-Unterhalt
  bereits allgemein – keine Änderung nötig.
- **V1-Paket fortgesetzt – `coldRoom` umgesetzt (Checkliste 1–7 abgearbeitet):** `UpgradeType.coldRoom` +
  `UpgradeSpec` (max. 5 Stufen, 160 €/16 €, +3 % Kapazität je Stufe) – damit steht die Kapazitäts-Basis des
  **Lageristen** (`11a`, V12) und der zweite ▶-Baustein des Pakets ist geschlossen.
  Kein neuer Hook nötig: `GameClockService.capacityOf` multipliziert den Erweiterungsfaktor bereits
  (`value × (1 + upgradeEffects(...).capacity)`) **vor** dem Clamp (0–20) – die Boni laufen automatisch durch
  (Checklisten-Punkt 4 entfällt). **Wirkungsgrenze dokumentiert:** Ohne Personal liefert `capacityOf` `0,0`
  („wirkt nur skalierend“, kein Attraktivitäts-/Zufriedenheits-Anteil).
  l10n `upgradeColdRoom` (DE „Kühlhaus/Kühlkette“ / EN „Cold storage/cold chain“) + Kachel im Reiter
  „Erweiterungen“ (wieder nur `_upgradeName` brauchte einen Fall).
  Tests: `test/economy_service_test.dart` („Kühlhaus (V1-Paket) speist ausschließlich Kapazität“ → 0,12 bei
  Stufe 4; Kosten 2.400 €, Delta 160 €, Unterhalt 80 €, Refund 1.200 €),
  `test/game_clock_service_test.dart` („Kühlhaus hebt die Kapazität“ → 1,00 → 1,15 auf Stufe 5, Attraktivität/
  Zufriedenheit unverändert; „Kühlhaus bleibt ohne Personal wirkungslos“;
  „Kühlhaus-Unterhalt wird im Wochenblock abgebucht“ → 80 €/Woche auf Stufe 5),
  `test/screen_restaurant_test.dart` („Kühlhaus-Kachel ist ausbaubar“, Budget −160 €),
  `test/balance_sanity_test.dart` erzwingt die Spec.
- **V1-Paket fortgesetzt – `firstAid` umgesetzt (Checkliste 1–7 abgearbeitet, erster ⚙-Baustein):**
  Wirkungs-Option **entschieden**: −5 % Heilzeit je Stufe (statt „+1 Rettungswurf-Zielwert“, siehe
  Entscheidungen). `UpgradeType.firstAid` + `UpgradeSpec` (max. 3 Stufen, 250 €/25 €,
  `healTimeReductionPerLevel = 0.05`).
  Neu ist das **Hook-Muster**: `UpgradeSpec` hat das optionale Feld `healTimeReductionPerLevel`;
  `EconomyService.upgradeEffects` liefert es als **vierte** Summe (`healTime`) des Records, und
  `GameClockService.healTimePerStageFor({quality, upgrades})` wendet
  `Basiszeit × (1 − Σ healTime)` an (auf ganze Sekunden gerundet, defensiv ≥ 1 s).
  Weil dieser Helfer der **einzige** Entstehungsort der Stufenzeit ist, folgen `advanceHealing`,
  `rollBackEmergencyShots` **und** die UI-Countdowns (`ScreenRestaurant._healingInfoText`,
  `ScreenCharacterDetail._healingInfoText`) mit **einer** Änderung; die UI übergibt dafür
  `_profile.activeUpgrades`.
  l10n `upgradeFirstAid` (DE „Erste-Hilfe-Station“ / EN „First-aid station“) + Kachel im Reiter
  „Erweiterungen“ (wieder nur `_upgradeName` brauchte einen Fall).
  Tests: `test/economy_service_test.dart` („Erste-Hilfe-Station (V1-Paket) verkürzt ausschließlich die
  Heilzeit“ → `healTime` 0,15 auf Stufe 3, die drei Eingangswert-Boni bleiben `0`; Kosten 1.500 € (Clamp auf
  max. 3 Stufen), Delta 250 €, Unterhalt 75 €, Refund 750 €),
  `test/game_clock_service_test.dart` („Erste-Hilfe-Station verkürzt die Heilzeit je Stufe“ → 24 h → 20 h 24 min
  ohne Arzt, 1 h → 51 min mit Arzt `hoch`, 22 h 48 min auf Stufe 1; „Erste-Hilfe-Station heilt im Zeitlauf
  schneller“ → `reeling → ready` nach 20,5 h **nur** mit Station; „Erste-Hilfe-Station-Unterhalt wird im
  Wochenblock abgebucht“ → 75 €/Woche auf Stufe 3),
  `test/screen_restaurant_test.dart` („Erste-Hilfe-Kachel ist ausbaubar“, Budget −250 €),
  `test/balance_sanity_test.dart` erzwingt die Spec. **Nächster Baustein: `lounge`** – dessen
  Wirkungs-Optionen (+3 % Wochen-Refill **und/oder** −3 % Tages-Sink) sind vorher zu entscheiden, weil sie den
  Hook festlegen.
- **DRY – erledigt:** Das Brutto-Delta ist als reine Funktion `EconomyService.upgradeCostDelta(type, fromLevel)`
  zentralisiert (`0` bei unbekanntem Typ, negativer Stufe oder Maximalstufe); `ObjectProfile.upgradePurchaseCost`
  nutzt sie. Die frühere Beschreibung „doppelt in `buyUpgrade` **und** UI-Tile“ war bereits überholt – beide
  laufen über `upgradePurchaseCost`; dupliziert war nur noch die Formel selbst. Tests:
  `test/economy_service_test.dart` („Kosten-Delta der nächsten Stufe“, „Kosten-Delta ist 0 …“).
- **Verkauf ohne Bestätigung – erledigt:** `ScreenRestaurant._sellUpgrade` zeigt vor der Buchung einen
  Bestätigungsdialog (`upgradeSell` / `upgradeSellConfirm(refund)` / `cancel`), der die zu erwartende Erstattung
  nennt (`EconomyService.sellRefund`); gebucht wird erst nach Bestätigung. Test:
  `test/screen_restaurant_test.dart` („Verkaufen fragt nach und erstattet erst nach Bestätigung“, prüft Abbruch
  **und** Bestätigung). Der **Downgrade** bleibt bewusst ohne Rückfrage (kostet nichts, senkt nur den
  Unterhalt) – siehe Entscheidungen.
- **Defensive Doppelabsicherung – entschieden:** Clamp bleibt als Vertrag der reinen Funktionen, `buyUpgrade`
  bleibt der Wächter (siehe Entscheidungen oben).
- **Rundungssemantik – entschieden:** `.round()` beim Verkauf (Geld fließt zum Spieler), `.ceil()` bei
  Negativzinsen (nie zu Gunsten des Schuldners) – bewusst unterschiedlich, siehe Entscheidungen oben.
- **Balance-Verhältnis – erledigt:** Vergleichstabelle „Balance-Runde: Gegenwert je Erweiterung“ oben; Werte
  bleiben für V1, `jukebox` ist dokumentierter Flagship-Ausreißer und erster Retune-Kandidat.
- **Kapazitäts-Normalisierung – entschieden (nur Doku):** `moneyValue` ist doppelt belegt – Beutewert **und**
  Kapazitäts-Eingang (`GameClockService.capacityOf = Ø(moneyValue) / capacityMoneyNorm`, Clamp 0–20; siehe
  `9_Personal.md`, `moneyValue`). Die Erweiterungs-Boni sind **relative** Multiplikatoren
  (`Basiswert × (1 + Σ Bonus)`) und damit robust: eine spätere Umdeutung des `moneyValue` verschiebt die
  **Basis**, nicht die relative Wirkung. Einziger Stellhebel wären `capacityMoneyNorm`/`capacityMax` in
  `EconomyBalance` (offene Frage aus `2-Wirtschaftsschleife.md` § 8); die Erweiterungs-Werte selbst bleiben
  unverändert.
- **Abstimmung mit `11a` – erledigt:** Die Zuordnung Rolle ↔ Erweiterung steht in `11a`
  (Sommelier ↔ `cellar`, Caissier ↔ `vault`, Lagerist ↔ `coldRoom`, Rechtsanwalt ↔ `certification`,
  Sicherheitschef ↔ `security`). Neue Erweiterungen sind **Ergänzung, nicht Ersatz** einer Rolle („Additiv
  statt Multiplikator“); ein doppelter Hebel auf **denselben** Eingangswert ist zu vermeiden – der frühere
  Konflikt **Caviste ↔ Weinkeller** ist aufgelöst (Caviste = Lagerist = Kapazitäts-/Lager-Hebel; Zufriedenheit
  gehört dem Keller/Sommelier).
- **Anschaffungspreis-Rabatt (V11) – erledigt:** Die Chefsekretärin mindert den **Anschaffungspreis** (−5 %,
  `ObjectProfile.upgradePurchaseCost`; die UI zeigt den geminderten Wert), Plongeur (−25 %) und Buchhalter
  (−5 %) mindern dagegen den **Unterhalt** im Wochen-Tick. Alle Tabellenwerte dieses Dokuments sind daher
  **Basis-Werte ohne Rollen** (erläutert in „Kosten- & Wirkungsmodell“).

## Checkliste für eine neue Erweiterung (Doku ↔ Code)

1. `UpgradeType`-Enum um den neuen Wert erweitern (`lib/models/restaurant_upgrade.dart`).
2. `UpgradeSpec` in `EconomyBalance.upgrades` ergänzen (MaxLevel, Ankauf-/Erhalt-Basis, Boni) – V7,
   keine Literale außerhalb der Balance.
3. `EconomyService.upgradeEffects` deckt neue Boni automatisch ab (Spec-getrieben); `upgradeCost`/
   `upgradeUpkeepPerWeek`/`sellRefund` ebenfalls.
4. Hook verdrahten: Bonus auf `attractivenessOf`/`satisfactionOf`/`capacityOf` (nur falls der Eingangswert
   nicht bereits über `upgradeEffects` abgedeckt ist) **oder** Zusatzbuchung in `catchUp` **oder** ein eigener
   Faktor an der Wirkungsstelle (Beispiel: `firstAid` → `GameClockService.healTimePerStageFor`, wodurch
   Rechnung und UI-Countdown automatisch mitlaufen).
5. UI-Tile (Reiter 3, `ScreenRestaurant`) + l10n-Schlüssel DE/EN (`upgrade<Typ>`, ARB-Dateien, danach
   `flutter gen-l10n` – die Optionen stehen in `l10n.yaml`).
6. Tests ergänzen: `test/economy_service_test.dart`, `test/game_clock_service_test.dart`,
   `test/screen_restaurant_test.dart`, `test/profile_data_test.dart`, `test/balance_sanity_test.dart`.
7. Regelwerk angleichen: `doc/rules/team_rules.md` § 2.2 (laufende Ausgaben: Erweiterungs-Unterhalt).

## Anhang: Belege

- Modell: `lib/models/restaurant_upgrade.dart` (`UpgradeType`, `UpgradeSpec`)
- Balance: `lib/services/economy_balance.dart` (`upgrades`, `upgradeSellRefundRate`) · Logik:
  `lib/services/economy_service.dart` (`upgradeEffects`, `upgradeCost`, `upgradeCostDelta`,
  `upgradeUpkeepPerWeek`, `totalUpgradeUpkeepPerWeek`, `sellRefund`, `applyNegativeInterest`, `canAfford`)
- Zeit/Abrechnung: `lib/services/game_clock_service.dart` (`catchUp`, `attractivenessOf`/`satisfactionOf`/
  `capacityOf`, `WeeklyTickResult`, `WeekSettlement`)
- Persistenz: `lib/models/profile_data.dart` (`RestaurantData.upgrades`, `kProfileSchemaVersion = 5`) ·
  Mutation/UI: `lib/objects/object_profile.dart` (`upgradeLevel`/`buyUpgrade`/`downgradeUpgrade`/`sellUpgrade`),
  `lib/screens/screen_restaurant.dart` (`_buildUpgradesSection`/`_buildUpgradeTile`)
- l10n: `lib/l10n/app_de.arb`/`app_en.arb` (`upgradesSection`, `upgradeTables`/`upgradeKitchen`/
  `upgradeSignage`/`upgradeDecoration`/`upgradeJukebox`/`upgradeCellar`/`upgradeColdRoom`/`upgradeFirstAid`, `upgradeBuy`/`upgradeDowngrade`/`upgradeSell`,
  `upgradeSellConfirm`, `upgradeSold`, `upgradeUpkeepCost`, `upgradeBuyCost`, `upgradeMaxReached`,
  `upgradeNotEnoughBudget`, `tabUpgrades`)
- Tests: `test/economy_service_test.dart`, `test/game_clock_service_test.dart`, `test/screen_restaurant_test.dart`,
  `test/profile_data_test.dart`, `test/balance_sanity_test.dart`
- Doku: `2-Wirtschaftsschleife.md` § 10 (Bezug: § 8, § 11) · `7_Wirtschaftswerte_zentralisieren.md` ·
  `8_Echtzeit-Zeitsystem.md` (Q1/Tagesschritt) · `10_Karrierepfade.md` § 3 ·
  `11a_Hilfs_und_Servicerollen.md` (Plongeur/Aboyeur) · `doc/rules/team_rules.md` § 2.2
