# Hilfs- und Service-Rollen

Die Hilfs- und Service-Rollen wurden in `2-Wirtschaftsschleife.md` angedacht und an mehreren Stellen erweitert –
vor allem in `10_Karrierepfade.md` § 3 (Erstdefinition) und V10, Phasen 6–8 (Umsetzung). Dieses Dokument fasst sie
zusammen, listet den **Ist-Stand mit konkreter Wirkung** und hält die **Erweiterungsvorschläge** fest – analog zu
`11b_Restauranterweiterungen.md`.

> **Hinweis:** Die Inhalte dieses Dokuments beeinflussen im späteren Verlauf die Inhalte des Dokuments **11b**
> (`11b_Restauranterweiterungen.md`) und werden daher gemeinsam entwickelt – insbesondere der **Plongeur**
> (senkt den Erweiterungs-Unterhalt) und der **Aboyeur** (wirkt auf das passive Einkommen aus § 8).
>
> **Schnittstelle (wer definiert, wer konsumiert):** Die Rollen sind **hier** definiert und wirken **dort**:
> `SupportRoleService.upkeepReductionPercent(...)` (Plongeur, −25 %) senkt den in `11b`/§ 10 eingeführten
> Erweiterungs-Unterhalt; `SupportRoleService.incomePercent(...)` (Aboyeur, +10 %) hebt das passive Einkommen
> aus `2-Wirtschaftsschleife.md` § 8 – jeweils im Wochen-Catch-up.

**Einordnung (fixiert in V10):** Die Rollen sind **keine Kampfklassen**. Sie ziehen **nicht** ins Gefecht, wirken
auf die Management-Schleife und werden **auf derselben Seite wie die Teamärzte** geführt (`ScreenHireAndFire`).
Sie kosten **wöchentlich** Lohn – abgebucht im Catch-up (`GameClockService.catchUp`) als Teil der `staffCosts`
(`WeekSettlement`/`WeeklyTickResult`).

**Abgrenzung Teamarzt:** Der Teamarzt ist **keine** Hilfs-/Service-Rolle, sondern ein eigenständiges System
(`2-Wirtschaftsschleife.md` § 4.5 / `object_team_medic.dart`). Er dient hier nur als **Vorbild** für die
Verwaltung (Personal-Seite, Wochenlohn-Abbuchung, `ScreenHireAndFire`); Rollen haben im Unterschied zu Ärzten
aber **keine Qualitätsstufen**, **keinen Anschaffungspreis** und **keine Persönlichkeit** (→ Lohn ohne
Thriftiness-Faktor).

### Personal-Kategorien – Grundsätze & offene Entscheidungen

**Frage (Ist-Stand): Wie wird Hilfspersonal derzeit angeheuert?**
Über einen **festen Katalog** in `ScreenHireAndFire` (Sektion `l10n.supportRoles`): alle sieben `SupportRole`-Karten
mit Wirkungstext + Wochenlohn (`EconomyBalance.supportRoleWagePerWeek`) und **Hire**-Button
(`ObjectProfile.hireSupportRole`); angestellte Rollen erscheinen als Karten mit **Fire**-Button
(`fireSupportRole`). Kein Ankaufspreis, keine Budgetprüfung – der Fixlohn wird erst beim nächsten Wochen-Tick
als Teil der `staffCosts` abgebucht. **Teamärzte** dagegen stammen aus einem Zufalls-Pool (15 Kandidaten) mit
Qualität, Persönlichkeit und `weeklyMedicCost`.

**Problem:** Künftig sollen weitere Nicht-Kampf-Personen anheuerbar sein, z. B. ein **Social Media Manager**.
Dieser ist weder Küchenbrigade (`SupportRole`) noch Teamarzt – er gehört in eine eigene **Personal-Kategorie**
(Verwaltung & Marketing). Statt pro Person ein neues Parallel-System anzulegen, wird die Anstell-Mechanik
**generalisiert (Option C)**:

| Grundsatz | Inhalt |
|---|---|
| **G1 – Eine Mechanik für alles Nicht-Kampf-Personal** | Katalog/Karte, `id`/`name`, Wochenlohn, Abbuchung im Catch-up als Teil der `staffCosts`, Entlassen ohne Rückerstattung. Der Teamarzt bleibt ein **eigenständiges Objekt** (`ObjectTeamMedic`) mit Sonderlogik (Pool, Qualität, Persönlichkeit), teilt aber den gemeinsamen Verwaltungs-Contract. |
| **G2 – Kategorie als Datenfeld, nicht als Parallel-Enum** | Ein gemeinsamer Eintragstyp mit `kind` (`medic` \| `support` \| `management`) ersetzt perspektivisch `SupportRoleData`; bestehende `SupportRole`-Werte bleiben **stabil** und werden additiv/tolerant migriert (Schema v5 → v6). |
| **G3 – Contract generisch, Wirkung kategoriespezifisch** | Anstellen/Abrechnen ist für alle Kategorien gleich; die **Effekt-Auswertung** bleibt domänenspezifisch (binär für `support`, skalierend/persönlich für `medic`, künftig `management`). |
| **G4 – Lohnmodell je Kategorie** | Fixlohn ohne Thriftiness, solange eine Kategorie keine Persönlichkeit besitzt; persönlichkeitsabhängiger Lohn nur, wo Persönlichkeit existiert. |
| **G5 – Neue Personalart = neuer `kind`-Wert** | Neue Arten docken entlang der gemeinsamen Checkliste an (Kategorie → `EconomyBalance` → Auswertung → Hook → UI → l10n → Tests) – **kein** Parallel-System. |

**Offene Entscheidungen (bewusst noch nicht fixiert):**

| # | Frage | Optionen / Tendenz |
|---|---|---|
| E1 | Gehört der **Teamarzt** in die Taxonomie? | Eigenständiges Objekt behalten und nur den Verwaltungs-Contract teilen (**Tendenz**) vs. vollständig als `kind = medic` integrieren. |
| E2 | Kategorie-Name/-Zuschnitt („Verwaltung & Marketing“)? | `management` vs. `administration` vs. `marketing`; eine Kategorie oder zwei (Verwaltung, Marketing)? |
| E3 | Wirkung des **Social Media Manager**? | **Entschieden (Grundlagen):** binärer Zuschlag **+10 % passives Einkommen** (`socialMediaManagerIncomePercent`), stapelt additiv mit dem Aboyeur; Hook im Catch-up. |
| E4 | Persistenz-Migration? | Neues Feld `staffEntries`; Alt-Spielstände werden beim Laden importiert (`supportStaff` → `kind = support`), additiv/tolerant (**Tendenz**). |
| E5 | UI-Gliederung? | **Entschieden (Grundlagen):** Kategorie-Gruppierung im bestehenden `ScreenHireAndFire` (Abschnitt „Verwaltung & Marketing“), **kein** neuer Restaurant-Reiter. |
| E6 | Rollen-Vorschläge (Maître d'hôtel, Caissier, Sommelier)? | In `management` überführen oder als `support` belassen? |

> Die **Feature**-Entscheidungen **E7–E11** (aktive Sonderfertigkeiten, „PR-Kampagne“ des Social Media Manager)
> sind im Abschnitt „Features – Sonderfertigkeiten spezieller Mitarbeiter“ mit ihren Tuning-Werten festgehalten.

**Grundlagen (angelegt, Option C):**

- **Modell:** `RoleKind` (`medic` \| `support` \| `management`) + der generalisierte Eintrag `StaffEntryData`
  (`id`, `name`, `kind`, `role`, `costPerWeek`, `hiredAt`) in `lib/models/staff_entry.dart`; das Küchen-Enum
  `SupportRole` bleibt unverändert.
- **Neue Kategorie:** `ManagementRole` (Start: `socialMediaManager`) in `lib/models/management_role.dart`;
  **Wirkung entschieden und umgesetzt (E3):** Effekt-Const `socialMediaManagerIncomePercent` (**+10 %** passives
  Einkommen), additiv zum Aboyeur – kein eigenes Küchen-Enum, siehe Kategorie-Tabelle unter „Ist-Stand“.
- **Balance:** `EconomyBalance.managementRoleWagePerWeek` (Social Media Manager: **180 €/Woche**) und
  `socialMediaManagerIncomePercent` (**+10 %**, E3).
- **Wirkung/Hook (E3 umgesetzt):** `StaffRoleService.managementIncomePercent` hebt im `catchUp` das passive
  Einkommen (additiv zum Aboyeur); `StaffRoleService.nonCombatWeeklyWages` bucht die Löhne von Support **und**
  Management (Arztkosten weiter separat).
- **UI (E5 umgesetzt):** Abschnitt „Verwaltung & Marketing“ in `ScreenHireAndFire` (Karten mit Wirkung + Lohn +
  Hire/Fire); `lib/l10n/management_role_labels.dart` + ARB (DE/EN, `gen-l10n`).
- **Verwaltungs-Contract (G1):** `StaffRoleService` (reine Funktionen: `ofKind`, `hasKind`, `hasRole`,
  `weeklyWages`, `managementWagePerWeek`).
- **Persistenz/Migration (E4 umgesetzt):** `RestaurantData.staffEntries` ergänzt `supportStaff` (bleibt
  abwärtskompatibel und wird weiter geschrieben); Alt-Bestände werden beim Laden auf `kind = support`
  migriert. `kProfileSchemaVersion` 5 → **6**.
- **Tests:** `test/staff_entry_test.dart` (Kategorie-Roundtrip, tolerante Alt-Daten, Migration, Contract);
  die Schema-Version prüfen `support_role_test`/`profile_data_test` auf 6.
- **Noch offen:** E1/E2/E6 (Teamarzt-Einordnung, Kategorie-Name, Zuordnung der Erweiterungsvorschläge) sowie der
  Duplikations-Guard beim Anheuern. Die Feature-Entscheidungen **E7–E11** sind entschieden und umgesetzt
  (Abschnitt „Features – Sonderfertigkeiten spezieller Mitarbeiter“).

## Ist-Stand (umgesetzt)

**Status:** vollständig umgesetzt (V10, Phasen 6–8, Commit `7939be4`; Features: `11a` E7–E11). Werte verbindlich
nur in `EconomyBalance` (V7); Auswertung in `SupportRoleService`/`StaffRoleService`/`ManagementFeatureService`
(reine Funktionen), Modell/Persistenz in `SupportRole`/`SupportRoleData` (`RestaurantData.supportStaff`,
`kProfileSchemaVersion = 7`, additiv/tolerant – unbekannte Rollen werden beim Laden übersprungen; ab v6 zusätzlich
`RestaurantData.staffEntries` mit `kind`, `ManagementRole` und den Feature-Feldern, siehe „Personal-Kategorien“
und „Features“).

### Aktuell vorhandene Rollen mit Wirkung (tabellarisch)

#### Küchen-Rollen (`SupportRole`)

| Rolle (FR) | Titel (EN) | Wirkung (Wert) | Wochenlohn | Hook |
|---|---|---|---|---|
| Communard | Staff cook | Wochen-Refill Vitalität/Moral **+15 %** (`communardRefillBonusPercent`); stapelt **additiv** mit Pâtissier (+10 %, `patissierRefillBonusPercent`) | 150 € | `_refillStaffResources` |
| Tournant | Roundsman | Erschöpfungs-Malus der Nulltage **−25 %** (`tournantExhaustionReliefPercent`) | 120 € | `_probeResources` (Wochen-Proben) |
| Aboyeur | Expediter | passives Einkommen **+10 %** (`aboyeurIncomePercent`) | 160 € | `catchUp` |
| Plongeur | Dishwasher/porter | Erweiterungs-Unterhalt **−25 %** (`plongeurUpkeepReductionPercent`) | 70 € | `catchUp` |
| Commis de débarrasseur | Busser | Attraktivität **+0.05** (`commisAttractivenessBonus`, Domäne 0–4) | 90 € | `attractivenessOf` |
| Boucher | Butcher | Gefechtsbelohnung/Beute **+10 %** (`boucherLootPercent`) | 100 € | `ScreenBattleResult` |
| Garçon de cuisine | Kitchen boy | Attraktivität **+0.05** und Zufriedenheit **+0.05** (`garconAttractivenessBonus`/`garconSatisfactionBonus`) | 60 € | `attractivenessOf`/`satisfactionOf` |

#### Verwaltungs-/Marketing-Rolle (Kategorie `management`, keine `SupportRole`)

Der **Social Media Manager** ist der **erste** Eintrag der neuen Kategorie `management` und gehört **nicht** zum
Küchen-Enum `SupportRole` – deshalb eine eigene Tabelle (G2: Kategorie als Datenfeld `kind`):

| Rolle | Titel (EN) | Wirkung (Wert) | Wochenlohn | Hook |
|---|---|---|---|---|
| Social Media Manager | Social media manager | passives Einkommen **+10 %** (`socialMediaManagerIncomePercent`); stapelt **additiv** mit dem Aboyeur (+10 %, `aboyeurIncomePercent`) | 180 € | `catchUp` |

> Der Social Media Manager trägt zusätzlich das **Feature „PR-Kampagne“** – eine **aktive** Sonderfertigkeit,
> die ausnahmsweise **nicht** passiv/binär wirkt. Ablauf und Balance siehe Abschnitt
> „Features – Sonderfertigkeiten spezieller Mitarbeiter“.

> Anstellung/Abrechnung über den gemeinsamen Contract (G1): `ObjectProfile.hireManagementRole`/`fireStaffEntry`,
> `StaffRoleService.managementIncomePercent`/`nonCombatWeeklyWages`; Lohnquelle
> `EconomyBalance.managementRoleWagePerWeek`, UI-Abschnitt „Verwaltung & Marketing“ in `ScreenHireAndFire`.

> Quelle: `EconomyBalance` (V7) – `supportRoleWagePerWeek` und `managementRoleWagePerWeek` plus die
> `*Bonus`/`*Percent`-Konstanten. Bei Abweichung gilt der **Code**, nicht die Tabelle;
> `test/balance_sanity_test.dart` erzwingt Konsistenz.

### Lohn- & Verwaltungsmodell

- **Wochenlohn je Rolle** aus `EconomyBalance.supportRoleWagePerWeek` (150/120/160/70/90/100/60 €) bzw. aus
  `EconomyBalance.managementRoleWagePerWeek` (180 € für den Social Media Manager); die Summe aller Rollen läuft
  im Catch-up als Teil der `staffCosts`.
- **Anheuern ohne Ankaufspreis:** `ObjectProfile.hireSupportRole(role)` erzeugt einen `SupportRoleData`-Eintrag
  (Name aus dem Namensstamm der Restaurant-Küche, `id = CRC32(Name + Zeitpunkt)`, `costPerWeek` aus der Balance);
  für die Management-Kategorie erzeugt `ObjectProfile.hireManagementRole(role)` einen `StaffEntryData`-Eintrag
  (`kind = management`, `costPerWeek` aus `managementRoleWagePerWeek`);
  die **erste Abbuchung erfolgt erst beim nächsten Wochen-Tick** (kein anteiliger Einzug).
- **Entlassen ohne Rückerstattung:** `ObjectProfile.fireSupportRole(entry)` entfernt den Eintrag sofort
  (Management-Einträge analog über `ObjectProfile.fireStaffEntry(entry)`).
- **Binäre Wirkung, kein Stufenmodell:** Ausgewertet wird nur, **ob** eine Rolle angestellt ist
  (`SupportRoleService.has`), nicht **wie oft** – im Unterschied zu den stufenbasierten Erweiterungen (`11b`).

### Regeln & Konventionen

- **Binäre Wirkung:** Mehrfach-Anstellung derselben Rolle bringt **keinen** zusätzlichen Effekt, kostet aber
  vollen Lohn – im `ScreenHireAndFire` derzeit **nicht** unterbunden (→ offener Punkt).
- **Lohn fix ohne Thriftiness-Faktor**, da Rollen keine Persönlichkeit besitzen – im Unterschied zu
  `EconomyService.staffWagePerWeek(rank, thriftiness)` und zur Teamarzt-Abrechnung.
- **Kein Anschaffungspreis, kein anteiliger Einzug:** erste Abbuchung erst beim nächsten Wochen-Tick.
- **Effekt-Semantik:** Prozent-Effekte auf Einkommen/Unterhalt/Beute (Aboyeur/Plongeur/Boucher) werden
  **kaufmännisch gerundet**; absolute Zuschläge auf Attraktivität/Zufriedenheit (Commis/Garçon) liegen auf der
  Eingangs-Domäne **0–4** und addieren sich **vor** dem Erweiterungsfaktor (`11b`) und dem Clamp.
- **Features sind aktiv:** Sie kosten **einmalig** beim Aktivieren und laufen **anker-basiert** über zwei
  befristete Phasen (aktiv + Nachteilphase). Das ist die dokumentierte **Ausnahme** zum Passiv-/Binär-Grundsatz
  und wird auch bei der Idempotenz wie die Heilung behandelt (nie fortschreiben, immer aus `featureActivatedAt`
  rechnen). Details siehe „Features – Sonderfertigkeiten spezieller Mitarbeiter“.
- **Abrechnungsreihenfolge (Blockende):** passives Einkommen → Teamarzt-Kosten → Wochenlöhne
  (Personal **+ Rollen**) → Erweiterungs-Unterhalt → Negativzinsen → `WeekSettlement`/Bankrott-Check.

### Schnittstellen & Datenfluss

| Ebene | Artefakt |
|---|---|
| Modell | `enum SupportRole` (`lib/models/support_role.dart`) · `SupportRoleData` (`lib/models/profile_data.dart`) · `RoleKind`/`StaffEntryData` (`lib/models/staff_entry.dart`) · `ManagementRole` (`lib/models/management_role.dart`) · `ManagementFeature` (`lib/models/management_feature.dart`) |
| Balance | `EconomyBalance.supportRoleWagePerWeek`/`managementRoleWagePerWeek` + alle `*Bonus`/`*Percent`-Konstanten, `patissierRefillBonusPercent`, `socialMediaManagerIncomePercent`, `feature*` (Kosten, Fenster, Kompetenz, Nachteile) |
| Auswertung | `SupportRoleService` (reine Funktionen: `has`, `refillBonusPercent`, `exhaustionReliefPercent`, `incomePercent`, `upkeepReductionPercent`, `lootPercent`, `attractivenessBonus`, `satisfactionBonus`, `weeklyWages`) · `StaffRoleService` (Contract: `ofKind`, `hasKind`, `hasRole`, `weeklyWages`, `managementWagePerWeek`, `managementIncomePercent`, `nonCombatWeeklyWages`) · `ManagementFeatureService` (Features: `competenceOf`, `activeEntry`, `aftermathEntry`, `featureCostFor`, `aftermathSinkMultipliers`, `refillFractionFor`, `xpBoostPercentFor`) |
| Verwaltung | `ObjectProfile.hireSupportRole`/`fireSupportRole` · `ObjectProfile.hireManagementRole`/`fireStaffEntry` · `ObjectProfile.activateManagementFeature` · `ScreenHireAndFire` (Kategorie-Abschnitte + Feature-Aktivierung) |
| Wirtschaft | `GameClockService.catchUp` (Aboyeur, Plongeur, Social Media Manager, `staffCosts`, **Feature-Tages-XP/Sink/Refill/Reset**) · `_refillStaffResources` (Communard) · `_probeResources` (Tournant) · `attractivenessOf`/`satisfactionOf` (Commis/Garçon) · `ScreenBattleResult` (Boucher, **Feature-XP-Boost**) |
| Persistenz | `RestaurantData.supportStaff` (`List<SupportRoleData>`) **und** `RestaurantData.staffEntries` (`List<StaffEntryData>` mit `kind` und Feature-Feldern; JSON tolerant, `kProfileSchemaVersion = 7`; Alt-Bestände werden zu `kind = support` migriert) |
| l10n | `lib/l10n/support_role_labels.dart`, `lib/l10n/management_role_labels.dart`, `lib/l10n/management_feature_labels.dart` + ARB (DE/EN) |

## Erweiterungsvorschläge („letzten Endes erweitert“)

Die **Kapazität** (dritter Eingangswert aus § 8) ist bisher rollenfrei – die Vorschläge schließen diese Lücke und
docken an vorhandene Hebel an (Balance-Werte sind Tuning). Sie sind bislang als `SupportRole` skizziert; ihre
Kategorie-Zuordnung (`support` vs. `management`) ist noch offen (E6):

| Rolle (FR) | Titel (EN) | Wirkung (Vorschlag) | Hebel | Lohn (Vorschlag) |
|---|---|---|---|---|
| Maître d'hôtel | Head waiter | + Kapazität (Kunden/Gäste) | `GameClockService.capacityOf` | 120 € |
| Caissier / Comptable | Cashier/bookkeeper | − Negativzinsen (z. B. 25 % auf den Zinssatz) | Negativzinsen im Catch-up | 130 € |
| Sommelier | Wine steward | + Zufriedenheit (zusätzlich zu Garçon; Clamp 4.0 bleibt) | `satisfactionOf` | 100 € |
| Caviste / Magasinier | Cellarman/storekeeper | + Beute/„Frische“ (Überschneidung mit Boucher abklären) | `ScreenBattleResult` | 110 € |

> Abgestimmt mit `11b`: Der **Caviste** überschneidet sich mit dem dort vorgeschlagenen Erweiterungstyp
> „Weinkeller“; der **Plongeur** ist der wichtigste Hebel für die Balance des Erweiterungs-Unterhalts.

## Features – Sonderfertigkeiten spezieller Mitarbeiter

**Features** sind **aktive** Sonderfertigkeiten einzelner Nicht-Kampf-Mitarbeiter. Sie sind die dokumentierte
**Ausnahme** zum Passiv-Grundsatz der Rollen (binär, ohne Ankaufspreis): Ein Feature wird aktiv ausgelöst, kostet
**einmalig** Geld und läuft über zwei befristete Phasen – die **aktive Phase** und die **Nachteilphase**.

### Social Media Manager → „PR-Kampagne“ (umgesetzt, E7–E11 entschieden)

**Ablauf:**

1. **Aktivierung** (UI: angeworbene SMM-Karte in `ScreenHireAndFire`): Ein **einsatzfähiges** Teammitglied wird als
   Kampagnen-Ziel gewählt. Einmalkosten = **Level des Ziels × 1000 €** (`EconomyBalance.featureCostPerLevel`),
   **sofort** abgebucht (bis zur Negativgrenze, `EconomyService.canAfford`). Pro Träger läuft höchstens ein Feature.
2. **Aktive Phase** (1 Woche, `EconomyBalance.featureActiveDuration`): Das Ziel erhält **je abgerechnetem
   Tagestick** XP „wie nach einem Gefechtssieg“ (`EconomyService.xpForBattle(won: true, level)`), erhöht um den
   **Kompetenz-Zuschlag** des Trägers (`Kompetenz × featureCompetenceBoostPercentPerStep`). Derselbe Zuschlag
   multipliziert **alle** XP-Erträge des Ziels – also auch die Gefechts-XP in `ScreenBattleResult`.
3. **Nachteilphase** (1 Woche, `EconomyBalance.featureAftermathDuration`): Der Tages-Sink auf `vitality`/`morale`
   des Ziels ist **verdoppelt** (`featureAftermathSinkMultiplier`); am Wochen-Refill wird nur noch **die Hälfte**
   des Deltas zum Trait-Basiswert aufgefüllt (`featureAftermathRefillFraction`). Danach wird das Feature
   zurückgesetzt (`ManagementFeatureService.clearFinished`) und ist erneut aktivierbar.

**Kompetenz (E8):** deterministisch aus der stabilen Personal-ID (`featureCompetenceMin` 1 … `featureCompetenceMax`
4, `ManagementFeatureService.competenceOf`) – kein Zufall, kein Pool, kein Thriftiness-Faktor.

**Balance (Tuning in `EconomyBalance`):**

| Konstante | Wert | Bedeutung |
|---|---|---|
| `featureCostPerLevel` | 1000 € | Einmalkosten je Level des Kampagnen-Ziels |
| `featureActiveDuration` | 1 Woche | Dauer der aktiven Phase |
| `featureAftermathDuration` | 1 Woche | Dauer der Nachteilphase |
| `featureCompetenceMin` / `featureCompetenceMax` | 1 / 4 | Domäne der Kompetenz-Stufe |
| `featureCompetenceBoostPercentPerStep` | 15 % | XP-Zuschlag je Kompetenz-Stufe |
| `featureAftermathSinkMultiplier` | 2 | Faktor auf `resourceSinkPerDay` in der Nachteilphase |
| `featureAftermathRefillFraction` | 0.5 | Anteil des Refill-Deltas in der Nachteilphase |

> Umsetzung (Option C, G1/G2/G5): `ManagementFeature`/`kAllManagementFeatures`
> (`lib/models/management_feature.dart`) · `StaffEntryData.activeFeature`/`featureTargetId`/`featureActivatedAt` ·
> `ManagementFeatureService` (Anker-Fenster, Kompetenz, Faktoren) · Hooks in `GameClockService.catchUp`
> (Tages-XP, Sink, Refill, Reset) und `ScreenBattleResult` (Gefechts-XP) · Aktivierung über
> `ObjectProfile.activateManagementFeature` · UI/l10n in `ScreenHireAndFire` ·
> `kProfileSchemaVersion = 7` (additiv/tolerant) · Tests in `test/management_feature_test.dart`.

**Entscheidungen (fixiert):**

| # | Frage | Entscheidung |
|---|---|---|
| E7 | Feature-Mechanik allgemein | **Aktiv, kostet, befristet** – Ausnahme zum Passiv-/Binär-Grundsatz; Träger, Ziel, Anker und Phasen sind Felder am gemeinsamen Eintragstyp (G2/G5). |
| E8 | „Kompetenz“ des Trägers | Explizite, **deterministische** Stufe 1–4 aus der Personal-ID; Boost = Stufe × 15 % während der aktiven Phase. |
| E9 | „Level × 1000 $“ | **Level des Kampagnen-Ziels**; einmalige Sofortbuchung bei Aktivierung (eigene Konstante – nicht die XP-Schwelle). |
| E10 | Nachteilphase | Genau **eine Woche** nach der aktiven Phase, nur das Ziel: Tages-Sink ×2, Refill halb; Null-Anker/Malus unverändert. |
| E11 | Name „Promotion“ | Umbenannt in **„PR-Kampagne“** (`managementFeaturePrCampaign`, Code `ManagementFeature.prCampaign`) – „Promotion“ ist im Projekt bereits der Karriere-Aufstieg. |

> **Noch offen:** weitere Features/Rollen (weitere `ManagementFeature`-Werte), ein UI-Countdown außerhalb der
> Personal-Karte sowie eine Zeile in `WeekSettlement` für die Einmalkosten (derzeit Sofortbuchung außerhalb des
> Wochenrumpfes).

## Entscheidungen (getroffen)

- **Kein Kampf** – Verwaltung wie Teamärzte auf der Personal-Seite.
- **Wöchentlicher Lohn statt Ankauf** (analog `0-Base.md`, Entscheidung Nr. 3); Abbuchung am Blockende, kein
  anteiliger Einzug.
- **Binäre Wirkung** (Anwesenheit statt Anzahl/Stufen) – im Unterschied zu den stufenbasierten Erweiterungen
  (`11b`).
- **Lohn fix ohne Thriftiness-Faktor** (Rollen ohne Persönlichkeit) – im Unterschied zu `staffWagePerWeek`/
  Teamarzt.
- **Personal-Taxonomie-Details E3/E5 (Option C):** Der Social Media Manager ist ein **binärer
  Einkommens-Zuschlag (+10 %)** im Catch-up (additiv zum Aboyeur); die Kategorien werden **im bestehenden
  `ScreenHireAndFire`** gruppiert (kein neuer Restaurant-Reiter).
- **Effektwerte zentral in `EconomyBalance`** (V7) – keine Literale im Fluss.
- **Features sind aktiv und kosten einmalig** (E7–E11): Der Social Media Manager trägt die **PR-Kampagne** als
  Feature-Träger; aktiviert wird ein einsatzfähiges Kampagnen-Ziel gegen `Level × 1000 €`, die Wirkung läuft
  anker-basiert über eine aktive Woche (Tages-XP + Kompetenz-Boost) und eine Nachwirkungswoche (Sink ×2,
  Refill halb). Damit ist der Grundsatz „kein Ankaufspreis“ für **Rollen** weiterhin gültig – die Einmalkosten
  sind eine **Aktivierungs**-Buchung des Features (Abschnitt „Features – Sonderfertigkeiten spezieller
  Mitarbeiter“).
- **Generalisierte Personal-Taxonomie (Option C, Grundsätze G1–G5)** – beschlossen: **eine** gemeinsame Anstell-/
  Abrechnungs-Mechanik für alles Nicht-Kampf-Personal; die **Kategorie ist ein Datenfeld** (`kind`), die Wirkung
  bleibt kategoriespezifisch. Die Detail-Entscheidungen E1–E6 sind noch offen (Abschnitt „Personal-Kategorien“).

## Offene Punkte

- Mehrfach-Anstellung derselben Rolle verhindern (UI-Disable oder Guard in `hireSupportRole` per
  `SupportRoleService.has`).
- Lohn-Thriftiness nachziehen, falls Rollen später Persönlichkeit erhalten.
- Tournant wirkt nur auf Wochen-Proben im Restaurant, Kampf-Malus unberührt (dokumentierte V10-Abweichung).
- Erweiterungsvorschläge in Abstimmung mit `11b` priorisieren (Schnittmenge Plongeur ↔ Erweiterungs-Unterhalt;
  Caviste ↔ Erweiterungstyp „Weinkeller“).
- **Balance-Check:** Rollen lohnen sich erst, wenn ihre Wirkungsbasis existiert (Plongeur nur mit Erweiterungen,
  Aboyeur nur mit Personal/Einkommen, Boucher hängt an der Gefechtsfrequenz) – Löhne bewusst gegenprüfen.
- Entlassen ohne Rückerstattung ist bewusst (analog Charakter-Entlassung); Bestätigungs-Dialog prüfen (wie in
  `11b` beim Erweiterungs-Verkauf).
- **Taxonomie – offene Detail-Entscheidungen E1/E2/E6:** Teamarzt-Einordnung, Kategorie-Name/-Zuschnitt und
  Zuordnung der Erweiterungsvorschläge (Abschnitt „Personal-Kategorien – Grundsätze & offene Entscheidungen“).
- **Features:** weitere aktive Fertigkeiten brauchen je einen `ManagementFeature`-Wert + Balance-Spec; offen sind
  ein UI-Countdown außerhalb der Personal-Karte, eine `WeekSettlement`-Zeile für die Einmalkosten und ein
  Bestätigungs-Dialog vor der Aktivierung. Bei mehreren Trägern desselben Features gilt weiterhin „höchstens ein
  laufendes Feature pro Träger“.

## Checkliste (Doku ↔ Code)

**Neue Rolle in einer bestehenden Kategorie:**
`SupportRole`-Enum → `EconomyBalance` (Lohn in `supportRoleWagePerWeek` + Effekt-Konstante) →
`SupportRoleService` (reine Auswertung) → Hook in `GameClockService`/`ScreenBattleResult` →
`ScreenHireAndFire`-Sektion → `support_role_labels.dart` + ARB (DE/EN, `gen-l10n`) →
`support_role_test` + `weekly_wages_test` + `balance_sanity_test`.

**Neue Kategorie (z. B. „Verwaltung & Marketing“, G5):**
`kind`-Wert im gemeinsamen Eintragstyp → `EconomyBalance` (Specs je Kategorie) → kategoriespezifische Auswertung
→ Hook → UI-Gruppierung (`ScreenHireAndFire`/`ScreenRestaurant`) → l10n → **Schema-Migration (additiv/tolerant)**
→ Tests.

**Neues Feature (aktive Sonderfertigkeit, E7):**
`ManagementFeature`-Wert + `managementFeatureOf(role)`-Zuordnung → `EconomyBalance` (Kosten, beide Fensterlängen,
Kompetenz-Spanne/-Schritt, Nachteil-Faktoren) → `ManagementFeatureService` (Anker, Faktoren, reine Funktionen) →
Hooks in `GameClockService.catchUp` und ggf. `ScreenBattleResult` → Aktivierungs-API in `ObjectProfile` →
`management_feature_labels.dart` + ARB (DE/EN, `gen-l10n`) → UI in `ScreenHireAndFire` → **Schema-Version +
tolerante Felder** → `management_feature_test` + `balance_sanity_test`.

## Anhang: Belege

- Modell/Persistenz: `lib/models/support_role.dart` · `lib/models/staff_entry.dart` (`RoleKind`,
  `StaffEntryData` inkl. Feature-Feldern) · `lib/models/management_role.dart` (`ManagementRole`) ·
  `lib/models/management_feature.dart` (`ManagementFeature`) · `lib/models/profile_data.dart`
  (`SupportRoleData`, `RestaurantData.supportStaff`/`staffEntries`, `kProfileSchemaVersion = 7`)
- Balance: `lib/services/economy_balance.dart` (`supportRoleWagePerWeek`, `managementRoleWagePerWeek`,
  `socialMediaManagerIncomePercent`, alle `*Bonus`/`*Percent`, `patissierRefillBonusPercent`, `feature*`) ·
  Auswertung: `lib/services/support_role_service.dart`, Contract: `lib/services/staff_role_service.dart`
  (`managementIncomePercent`, `nonCombatWeeklyWages`) · Features: `lib/services/management_feature_service.dart`
- Verwaltung/Abrechnung: `lib/objects/object_profile.dart` (`hireSupportRole`/`fireSupportRole`,
  `hireManagementRole`/`fireStaffEntry`, `activateManagementFeature`) ·
  `lib/services/game_clock_service.dart` (`catchUp`, `_refillStaffResources`, `_probeResources`,
  `_applyFeatureDailyXp`, `attractivenessOf`/`satisfactionOf`) ·
  `lib/screens/screen_battle_result.dart` (Boucher, Feature-XP-Boost)
- UI/l10n: `lib/screens/screen_hire_and_fire.dart` (Kategorie-Abschnitte + Feature-Aktivierung) ·
  `lib/l10n/support_role_labels.dart`, `lib/l10n/management_role_labels.dart`,
  `lib/l10n/management_feature_labels.dart` + ARB (DE/EN)
- Tests: `test/support_role_test.dart`, `test/weekly_wages_test.dart`, `test/staff_entry_test.dart`,
  `test/management_feature_test.dart`, `test/balance_sanity_test.dart`
- Doku: `10_Karrierepfade.md` § 3 & Phasen 6–8 · `2-Wirtschaftsschleife.md` § 8 & Wochen-Tick ·
  `11b_Restauranterweiterungen.md` (Erweiterungs-Unterhalt) · `0-Base.md` Nr. 3