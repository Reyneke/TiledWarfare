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
- **Neue Kategorie:** `ManagementRole` (Start: `socialMediaManager`; **V11: `chefSecretary`, `lawyer`,
  `accountant`**; **V12: `headWaiter`, `personnelManager`, `storekeeper`, `unionChief`**) in
  `lib/models/management_role.dart`;
  **Wirkung entschieden und umgesetzt (E3/E12/V12):** Effekt-Const `socialMediaManagerIncomePercent` (**+10 %**
  passives Einkommen), additiv zum Aboyeur; die V11-Rollen wirken binär auf Kosten/Strafen, die V12-Rollen auf die
  drei Eingangswerte/Kosten – kein eigenes Küchen-Enum, siehe Kategorie-Tabelle unter „Ist-Stand“ und die
  Abschnitte „Verwaltungsrollen (umgesetzt V11)“/„(umgesetzt V12)“.
- **Balance:** `EconomyBalance.managementRoleWagePerWeek` (Social Media Manager **180 €**, Chefsekretärin
  **220 €**, Rechtsanwalt **260 €**, Buchhalter **200 €**, Oberkellner **150 €**, Personalchef **230 €**,
  Lagerist **170 €**, Gewerkschaftschef **250 €**), `socialMediaManagerIncomePercent` (**+10 %**, E3),
  `chefSecretary*`/`lawyerPenaltyReductionPercent`/`accountantOngoingCostReductionPercent` (E12) sowie
  `headWaiter*`/`personnelManager*`/`storekeeper*`/`unionChief*` (V12).
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

**Status:** vollständig umgesetzt (V10, Phasen 6–8, Commit `7939be4`; Features: `11a` E7–E11; V11-Rollen:
E12–E17; **V12-Rollen: vier weitere `ManagementRole` + vier Features**). Werte verbindlich
nur in `EconomyBalance` (V7); Auswertung in `SupportRoleService`/`StaffRoleService`/`ManagementFeatureService`
(reine Funktionen), Modell/Persistenz in `SupportRole`/`SupportRoleData` (`RestaurantData.supportStaff`,
`kProfileSchemaVersion = 9`, additiv/tolerant – unbekannte Rollen werden beim Laden übersprungen; ab v6 zusätzlich
`RestaurantData.staffEntries` mit `kind`, `ManagementRole` und den Feature-Feldern inkl. `featureTeamIds`,
siehe „Personal-Kategorien“ und „Features“).

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

#### Verwaltungs-/Marketing-Rollen (Kategorie `management`, keine `SupportRole`)

Die Kategorie `management` gehört **nicht** zum Küchen-Enum `SupportRole` – deshalb eine eigene Tabelle
(G2: Kategorie als Datenfeld `kind`). Der **Social Media Manager** war der erste Eintrag; die V11-Erweiterung
ergänzt die drei **Verwaltungsrollen** (Chefsekretärin, Rechtsanwalt, Buchhalter), die V12-Erweiterung vier
weitere (Oberkellner, Personalchef, Lagerist, Gewerkschaftschef), die V13-Erweiterung einen weiteren
(**Sicherheitschef**). Diese Übersicht führt **alle neun** `management`-Rollen; die ausführliche
Wirkungsbeschreibung samt Entscheidungen E12–E17 steht im Abschnitt „Verwaltungsrollen (umgesetzt V11)“,
die der V12-Rollen im Abschnitt „Verwaltungsrollen (umgesetzt V12)“ und die des Sicherheitschefs im
Abschnitt „Verwaltungsrollen (umgesetzt V13)“:

| Rolle | Titel (EN) | Wirkung (Wert) | Wochenlohn | Hook |
|---|---|---|---|---|
| Social Media Manager | Social media manager | passives Einkommen **+10 %** (`socialMediaManagerIncomePercent`); stapelt **additiv** mit dem Aboyeur (+10 %, `aboyeurIncomePercent`) | 180 € | `catchUp` |
| Chefsekretärin | Head secretary | laufende **Mitarbeiterkosten −5 %** (`chefSecretaryStaffCostReductionPercent`) und **Erweiterungs-Anschaffung −5 %** (`chefSecretaryUpgradeCostReductionPercent`) | 220 € | `catchUp` (Löhne), `ObjectProfile.buyUpgrade` (Anschaffung) |
| Rechtsanwalt | Lawyer | **erlittene Strafen −25 %** (`lawyerPenaltyReductionPercent`); stapelt **additiv** mit dem aktiven „Winkelzug“ bis 100 % | 260 € | `RivalService.resolveSabotage` (Strafbuchung im Tick) |
| Buchhalter | Accountant | **alle laufenden Kosten −5 %** (`accountantOngoingCostReductionPercent`: Löhne, Arztkosten, Erweiterungs-Unterhalt) | 200 € | `catchUp` (Blockende) |
| Oberkellner | Head waiter | Attraktivität **+0.05** (`headWaiterAttractivenessBonus`) und Kapazität **+5 %** (`headWaiterCapacityPercent`); Feature „Rush Hour“ | 150 € | `attractivenessOf`/`capacityOf` |
| Personalchef | Personnel manager | Zufriedenheit **+0.05** (`personnelManagerSatisfactionBonus`) und Kapazität **+5 %** (`personnelManagerCapacityPercent`); Feature „Organisation ist alles“ | 230 € | `satisfactionOf`/`capacityOf`, `catchUp` (`featureCosts`) |
| Lagerist | Storekeeper | Kapazität **+20 %** (`storekeeperCapacityPercent`); Feature „Lagertetris“ | 170 € | `capacityOf` |
| Gewerkschaftschef | Union chief | Mitarbeiterlöhne **+10 %** (`unionChiefWageIncreasePercent`), Tages-Sink **−6 % je Kompetenz** (`unionChiefSinkReductionPercentPerCompetence`); Feature „Alle Räder …“ | 250 € | `catchUp` (Löhne), `_applyDailyResourceSink`/`_probeResources`, `RivalService.resolveSabotage` |
| Sicherheitschef | Security chief | Entdeckung eingehender Sabotageversuche **+10 % je Kompetenz** (`securityChiefDetectionBonusPercentPerCompetence`), zusätzlich Ø-`shadiness` des Personals × 50 % (`incomingDetectionShadinessPercent`); Feature „Rache ist Blutwurst“ | 240 € | `RivalService.resolveIncomingSabotage` (Blockende im `catchUp`) |

> Die vier V12-Rollen wirken **passiv/binär** und tragen zusätzlich je ein **aktives Feature**. Ausführliche
> Wirkung, Tuning und Entscheidungen stehen unter „Verwaltungsrollen (umgesetzt V12)“.

> Der **Sicherheitschef** (V13) wirkt passiv auf die **Entdeckung** eingehender Rivalen-Sabotage und trägt das
> **reaktive** Feature „Rache ist Blutwurst“; beides steht unter „Verwaltungsrollen (umgesetzt V13)“.

> Alle neun Einträge tragen zusätzlich je ein **aktives Feature** („PR-Kampagne“, Sabotage, „Winkelzug“,
> „Kreative Buchführung“, „Rush Hour“, „Organisation ist alles“, „Lagertetris“, „Alle Räder …“, „Rache ist
> Blutwurst“) – eine **aktive**
> Sonderfertigkeit, die ausnahmsweise **nicht** passiv/binär wirkt.
> Ablauf und Balance stehen unter „Features – Sonderfertigkeiten spezieller Mitarbeiter“ sowie
> „Verwaltungsrollen (umgesetzt V11)“, „Verwaltungsrollen (umgesetzt V12)“ und
> „Verwaltungsrollen (umgesetzt V13)“.

> Anstellung/Abrechnung über den gemeinsamen Contract (G1): `ObjectProfile.hireManagementRole`/`fireStaffEntry`,
> `StaffRoleService.managementIncomePercent`/`nonCombatWeeklyWages`; Lohnquelle
> `EconomyBalance.managementRoleWagePerWeek`, UI-Abschnitt „Verwaltung & Marketing“ in `ScreenHireAndFire`.

> Quelle: `EconomyBalance` (V7) – `supportRoleWagePerWeek` und `managementRoleWagePerWeek` plus die
> `*Bonus`/`*Percent`-Konstanten. Bei Abweichung gilt der **Code**, nicht die Tabelle;
> `test/balance_sanity_test.dart` erzwingt Konsistenz.

### Lohn- & Verwaltungsmodell

- **Wochenlohn je Rolle** aus `EconomyBalance.supportRoleWagePerWeek` (150/120/160/70/90/100/60 €) bzw. aus
  `EconomyBalance.managementRoleWagePerWeek` (180 € Social Media Manager, 220 € Chefsekretärin,
  260 € Rechtsanwalt, 200 € Buchhalter); die Summe aller Rollen läuft im Catch-up als Teil der `staffCosts`.
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
| Balance | `EconomyBalance.supportRoleWagePerWeek`/`managementRoleWagePerWeek` + alle `*Bonus`/`*Percent`-Konstanten, `patissierRefillBonusPercent`, `socialMediaManagerIncomePercent`, `feature*` (Kosten, Fenster, Kompetenz, Nachteile), `counterSabotage*`/`incomingSabotageChanceBasePercent`/`incomingDetectionShadinessToPercent`/`securityChiefDetectionBonusPercentPerCompetence`/`incomingSabotageIncomePenaltyPercent`/`incomingSabotageIncomePenaltyMaxPercent` (V13) |
| Auswertung | `SupportRoleService` (reine Funktionen: `has`, `refillBonusPercent`, `exhaustionReliefPercent`, `incomePercent`, `upkeepReductionPercent`, `lootPercent`, `attractivenessBonus`, `satisfactionBonus`, `weeklyWages`) · `StaffRoleService` (Contract + Passive: `ofKind`, `hasKind`, `hasRole`, `weeklyWages`, `managementWagePerWeek`, `managementIncomePercent`, `nonCombatWeeklyWages`, `hasManagementRole`, `chefSecretaryStaffCostReductionPercent`, `chefSecretaryUpgradeCostReductionPercent`, `accountantOngoingCostReductionPercent`, `headWaiterAttractivenessBonus`, `personnelManagerSatisfactionBonus`, `capacityPercent`, `unionChiefWageIncreasePercent`, `unionChiefSinkReductionPercent`, `penaltyReductionPercent`, `reducedPenalty`, `reduceByPercent`) · `ManagementFeatureService` (Features: `competenceOf`, `activeEntry`, `aftermathEntry`, `featureCostFor`, `fixedCostOf`, `activationCostFor`, `activeDurationOf`, `aftermathDurationOf`, `legalTrickReductionPercentFor`, `sabotageSuccessPercentFor`, `sabotageRollFor`, `sabotageSucceeds`, `isResolutionDue`, `aftermathSinkMultipliers`, `refillFractionFor`, `xpBoostPercentFor`, V12: `inputBoostPercent`, `capacityFactor`, `sinkReliefPercent`, `malusReliefPercent`, `rushHourExtraSink`, `featureDailyCosts`, `unionWorkersTeamIds`, `sabotageTeamSize`, `sabotageAttempts`, `shadinessBonusPercent`, `sabotageExhaustionPerMember`, `unionChiefSinkReliefPercent`, V13: `securityChiefDetectionBonusPercent`, `counterSabotageTeamLimit`, `counterSabotageSuccessPercentFor`, `counterSabotageRollFor`, `counterSabotageSucceeds`, `isArmed`) · `RivalService` (Kapitel 13: `countFor`, `rosterOf`, `byId`, `sabotageIncomeBonusPercent`, `sabotageChancePercent`, `resolveSabotage`, V13: `incomingAttemptOccurs`, `incomingAttemptDetected`, `averageShadiness`, `incomingDetectionPercent`, `incomingAttackerIds`, `detectedAttackerIds`, `counterSabotageSecretary`, `counterSabotageCrewIds`, `counterSabotageChancePercent`, `resolveCounterSabotage`, `resolveIncomingSabotage`, `undetectedIds`/`undetectedCount`) |
| Verwaltung | `ObjectProfile.hireSupportRole`/`fireSupportRole` · `ObjectProfile.hireManagementRole`/`fireStaffEntry` · `ObjectProfile.activateManagementFeature`/`activateUntargetedFeature`/`activateSabotage`/`activateUnionWorkers` · `ObjectProfile.managementFeatureActivationCost`/`unionWorkersTeamLimit`/`shadinessById` · `ObjectProfile.upgradePurchaseCost`/`buyUpgrade` · `ScreenHireAndFire` (Kategorie-Abschnitte, Feature-Aktivierung inkl. Mannschafts-Dialog, Rivalen-Liste) |
| Wirtschaft | `GameClockService.catchUp` (Aboyeur, Plongeur, Social Media Manager, **Chefsekretärin/Buchhalter-Kostenabzüge**, **Gewerkschafts-Lohnaufschlag + `featureCosts`**, `staffCosts`, **Feature-Tages-XP/Sink/Refill/Reset**, **Sabotage-Auflösung + Tages-Einkommensbonus + Strafen**, **V13: eingehende Rivalen-Sabotage + Einkommens-Abschöpfung + Gegenschlag am Blockende**) · `_refillStaffResources` (Communard) · `_probeResources` (Tournant, **V12-Malus-Minderung**) · `_applyDailyResourceSink` (V12: Sink-Minderung + rangverteilte Rush-Hour-Erschöpfung) · `attractivenessOf`/`satisfactionOf`/`capacityOf` (Commis/Garçon **+ V12-Zuschläge und -Faktoren**) · `ScreenBattleResult` (Boucher, **Feature-XP-Boost**) |
| Persistenz | `RestaurantData.supportStaff` (`List<SupportRoleData>`) **und** `RestaurantData.staffEntries` (`List<StaffEntryData>` mit `kind`, Feature-Feldern inkl. `featureResolvedAt`/`featureTeamIds` sowie `RestaurantData.sabotageTargetId`/`sabotageAppliedUntil`; JSON tolerant, `kProfileSchemaVersion = 9`; Alt-Bestände werden zu `kind = support` migriert) |
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

> **Umgesetzt (V12):** Die Vorschläge **Maître d'hôtel** und **Caviste/Magasinier** sind als `management`-Rollen
> **Oberkellner** und **Lagerist** aufgegangen (Kapazitäts-Hebel, Abschnitt „Verwaltungsrollen (umgesetzt V12)“);
> ihre Feature-Sonderfertigkeiten („Rush Hour“/„Lagertetris“) stammen aus der ersten Rohskizze. Offen bleiben
> **Caissier** (Negativzinsen) und **Sommelier** (Zufriedenheit, Überschneidung mit dem Garçon).

> Abgestimmt mit `11b`: Der **Caviste** überschneidet sich mit dem dort vorgeschlagenen Erweiterungstyp
> „Weinkeller“; der **Plongeur** ist der wichtigste Hebel für die Balance des Erweiterungs-Unterhalts.

## Verwaltungsrollen (umgesetzt V11)

Die drei Rollen wurden ursprünglich als Zeilen der Vorschlagsliste geführt (Entscheidungen **E12–E17**) und
sind jetzt Teil der Kategorie `management`. Sie ziehen **nicht** ins Gefecht, erzeugen **keine** Persönlichkeit,
haben **keinen** Ankaufspreis und wirken – wie alle Rollen – **binär** (Anwesenheit, nicht Anzahl), aber auf
**Kosten und Strafen** statt auf das Einkommen. Sie stehen zusätzlich in der vollständigen
`management`-Übersichtstabelle unter „Aktuell vorhandene Rollen mit Wirkung (tabellarisch)“:

| Rolle | Titel (EN) | Passiver Effekt (Wert) | Wochenlohn | Hook |
|---|---|---|---|---|
| Chefsekretärin | Head secretary | laufende **Mitarbeiterkosten −5 %** (`chefSecretaryStaffCostReductionPercent`) und **Erweiterungs-Anschaffung −5 %** (`chefSecretaryUpgradeCostReductionPercent`) | 220 € | `catchUp` (Löhne), `ObjectProfile.buyUpgrade` (Anschaffung) |
| Rechtsanwalt | Lawyer | **erlittene Strafen −25 %** (`lawyerPenaltyReductionPercent`); stapelt **additiv** mit dem aktiven „Winkelzug“ bis 100 % | 260 € | `RivalService.resolveSabotage` (Strafbuchung im Tick) |
| Buchhalter | Accountant | **alle laufenden Kosten −5 %** (`accountantOngoingCostReductionPercent`: Löhne, Arztkosten, Erweiterungs-Unterhalt) | 200 € | `catchUp` (Blockende) |

**Wirkung im Detail (Tuning in `EconomyBalance`, Auswertung in `StaffRoleService`):**

- Die Abzüge werden **kaufmännisch gerundet** (`StaffRoleService.reduceByPercent`) und greifen am
  **Blockende** des Wochen-Ticks – nach dem Plongeur-Unterhaltsrabatt.
- Die Reihenfolge ist: Löhne ← Chefsekretärin **+** Buchhalter; Arztkosten/Unterhalt ← Buchhalter.
  Der Buchhalter mindert mit „alle laufenden Kosten“ bewusst **auch** die Lohnsumme.
- Der Chefsekretärin-Rabatt auf Erweiterungen wirkt **nur auf den Anschaffungspreis**
  (`ObjectProfile.upgradePurchaseCost`, in der UI angezeigt), **nie** auf den laufenden Unterhalt.
- **Strafen** entstehen im Minimal-Modul aus `13_Gegner_Restaurants.md` (aufgedeckte Sabotage) und werden
  zentral gemindert (`StaffRoleService.reducedPenalty` → `penaltyReductionPercent`).

**Aktive Features der Rollen** (Mechanik: Abschnitt „Features – Sonderfertigkeiten spezieller Mitarbeiter“):

### Chefsekretärin → „Charmantes Lächeln, rasiermesserscharfe Nägel“ (Sabotage)

1. **Aktivierung** (Träger-Karte in `ScreenHireAndFire`): Ziel ist ein **Rivale** des Stadtteils
   (`RivalService.rosterOf`). Einmalkosten **2500 €** (`sabotageCost`), sofort abgebucht; bei Erfolg sind es
   **externe Kräfte** – Strafen fallen daher nur bei **Aufdeckung** auf das eigene Restaurant zurück.
2. **Vorlauf (1 Woche, `sabotageActiveDuration`)**: Der Angriff läuft; der Erfolgswurf ist **deterministisch**
   (`ManagementFeatureService.sabotageRollFor`, CRC32 aus Träger-ID, Rivalen-ID und Anker).
   Erfolgschance = `sabotageBaseSuccessPercent` (40 %) **+** `sabotageSuccessPercentPerStep` (10 %) je
   Kompetenz-Stufe (E13) – also 50 % … 80 %.
3. **Auflösung im Wochen-Tick** (`RivalService.resolveSabotage`, taggenau, idempotent über
   `StaffEntryData.featureResolvedAt`):
   - **Erfolg:** Der Rivale ist **1 Woche** sabotiert (`sabotageEffectDuration`); sein Prestige sinkt um
     `sabotageRivalPrestigePenaltyPercent` (25 %), und der Spieler erhält `sabotageIncomeBonusPercent`
     (**+15 %** Einkommen, tagesgenau, solange das Fenster läuft). Persistiert wird nur das Fenster
     (`RestaurantData.sabotageTargetId`/`sabotageAppliedUntil`) – der Roster selbst ist abgeleitet.
   - **Misserfolg (aufgedeckt):** Strafe `sabotageCaughtFine` (**3000 €**), gemindert um die
     Strafen-Minderung des Rechtsanwalts; die Strafe erscheint als `penaltyCosts` in
     `WeekSettlement`/`WeeklyTickResult`.
4. **Nachlauf (1 Woche, `sabotageAftermathDuration`)**: „Abtauchen“ – keine neue Sabotage, dann
   `ManagementFeatureService.clearFinished`.

### Rechtsanwalt → „Winkelzug“

1. **Aktivierung** (ziel-los, `ObjectProfile.activateUntargetedFeature`): **1500 €** Sofortkosten
   (`legalTrickCost`) – das „hohe laufende Kosten“-Modell der Erstnotiz ist als Einmalkosten der Aktivierung
   abgebildet (E15).
2. **Aktives Fenster (1 Woche, `legalTrickActiveDuration`)**: Eintreffende Strafen werden um
   `Kompetenz × legalTrickPenaltyReductionPercentPerStep` (25 %) gemindert – bei Kompetenz 4 also **bis zur
   Negation**. Die Minderung stapelt sich **additiv** mit dem passiven Rollenabzug und ist auf 100 % gedeckelt.
3. **Nachlauf (3 Tage, `legalTrickAftermathDuration`)**: Aktenberge – keine erneute Aktivierung.

### Buchhalter → „Kreative Buchführung“

1. **Aktivierung** (ziel-los): **1000 €** Sofortkosten (`creativeAccountingCost`).
2. **Aktives Fenster** = `Kompetenz × 1 Tagestick` (`creativeAccountingPerCompetence`, **mindestens** ein
   Tagestick): Alle **laufenden Kosten** (Löhne, Arztkosten, Erweiterungs-Unterhalt) werden für die
   betroffenen Tage **vollständig negiert**. Da die Kosten am Blockende gebucht werden, wird der
   Tagesanteil (`negatedDays / 7`) am Blockende verrechnet (E16).
3. **Burnout (= Nachteilphase)** = `Kompetenz × creativeAccountingAftermathPerCompetence` (1 Tag je
   Kompetenz-Stufe): Der Träger fällt aus, es kann **nicht** erneut aktiviert werden; danach greift
   `clearFinished`.

> Eine Sabotage ohne Chefsekretärin ist nicht möglich (fehlender Träger); die Strafe bei Aufdeckung bildet
> zusammen mit dem Rechtsanwalt den dokumentierten **Chefsekretärin → Strafe → Rechtsanwalt**-Kreislauf.

## Verwaltungsrollen (umgesetzt V12)

Die vier Rollen wurden in `11a` als erste Rohskizzen geführt (Tabellenzeilen ohne Werte) und sind jetzt Teil der
Kategorie `management`. Sie wirken **passiv/binär** auf die **drei Eingangswerte** des passiven Einkommens
(Attraktivität, Zufriedenheit, Kapazität) sowie auf Löhne/Erschöpfung und tragen je ein **aktives Feature**:

| Rolle | Titel (EN) | Passiver Effekt (Wert) | Wochenlohn | Hook |
|---|---|---|---|---|
| Oberkellner | Head waiter | Attraktivität **+0.05** (`headWaiterAttractivenessBonus`), Kapazität **+5 %** (`headWaiterCapacityPercent`) | 150 € | `attractivenessOf`/`capacityOf` |
| Personalchef | Personnel manager | Zufriedenheit **+0.05** (`personnelManagerSatisfactionBonus`), Kapazität **+5 %** (`personnelManagerCapacityPercent`) | 230 € | `satisfactionOf`/`capacityOf` |
| Lagerist | Storekeeper | Kapazität **+20 %** (`storekeeperCapacityPercent`) | 170 € | `capacityOf` |
| Gewerkschaftschef | Union chief | Mitarbeiterlöhne **+10 %** (`unionChiefWageIncreasePercent`, nur Kampfpersonal), Tages-Sink **−6 % je Kompetenz** (`unionChiefSinkReductionPercentPerCompetence`) | 250 € | `catchUp` (Löhne), `_applyDailyResourceSink`/`_probeResources` |

**Wirkung im Detail (Tuning in `EconomyBalance`, Auswertung in `StaffRoleService`/`ManagementFeatureService`):**

- Absolute Zuschläge (Oberkellner/Personalchef) liegen auf der Eingangs-Domäne **0–4** und addieren sich **vor**
  dem Erweiterungsfaktor und dem Clamp; die prozentualen Kapazitäts-Zuschläge stapeln **additiv** und wirken
  **multiplikativ** auf die Kapazität.
- Der Gewerkschaftschef erhöht **nur** die Löhne des Kampfpersonals (nicht die Rollen-Löhne – sonst würde sich
  der Effekt selbst erhöhen) und senkt den **Tages-Sink** um `Kompetenz × 6 %`.
- **Reihenfolge im Rückgrat:** Der passive Gewerkschafts-Abzug greift zusammen mit den Feature-Abzügen
  (`ManagementFeatureService.sinkReliefPercent`, gedeckelt auf 100 %) und gilt für den **Tages-Sink** wie für den
  **Erschöpfungs-Malus** der Nulltage.

**Aktive Features der V12-Rollen:**

### Oberkellner → „Rush Hour“

1. **Aktivierung** (ziel-los, `ObjectProfile.activateUntargetedFeature`): **800 €** Sofortkosten
   (`rushHourCost`).
2. **Aktives Fenster** = `Kompetenz × 1 Tagestick` (`rushHourPerCompetence`, **mindestens** ein Tagestick):
   Alle **drei Eingangswerte** steigen um `rushHourInputBonusPercent` (**+25 %**,
   `ManagementFeatureService.inputBoostPercent` in `attractivenessOf`/`satisfactionOf`/`capacityOf`), und die
   **Mali entfallen** (`sinkReliefPercent` = 100 % für Sink und Erschöpfungs-Malus).
3. **Bezahlung in Erschöpfung:** Je aktivem Tag entsteht eine Zusatzlast von
   `Kompetenz × rushHourExhaustionPerCompetence` (2), die **ranggewichtet von oben herab** auf das Personal
   verteilt wird (`GameClockService._rushHourExhaustionShares`, Gewicht = Rang-Seniorität + 1; der Rundungsrest
   geht an den ranghöchsten Charakter). Je mehr Mitarbeiter anwesend sind, desto geringer die Last des Einzelnen.
4. **Keine Nachteilphase** (`aftermathDurationOf` = 0).

### Personalchef → „Organisation ist alles“

1. **Aktivierung** (ziel-los): **kostenlos im Voraus** – die Reduktion wird **laufend** bezahlt
   (`organisationCostPerDay`, **150 €/Tag**, gebucht als `featureCosts` in
   `WeekSettlement`/`WeeklyTickResult`).
2. **Aktives Fenster** = `Kompetenz × 2 Tagesticks` (`organisationPerCompetence`): Der Tages-Sink sinkt um
   `organisationSinkReductionPercent` (**50 %**); der Erschöpfungs-Malus entsprechend.
3. **Keine Nachteilphase** – die Kosten laufen nur, solange das Fenster aktiv ist.

### Lagerist → „Lagertetris“

1. **Aktivierung** (ziel-los): **`Kompetenz × 500 €`** (`storageTetrisCostPerCompetence`,
   `ManagementFeatureService.activationCostFor`).
2. **Aktives Fenster** = **1 Wochentick** (`storageTetrisActiveDuration`): Die Kapazität wird mit
   `1 + 0,5 × Kompetenz` vervielfacht (`storageTetrisCapacityFactorPerCompetence`), und **alle Mali entfallen**
   (Sink und Erschöpfungs-Malus, `sinkReliefPercent` = 100 %).
3. **Keine Nachteilphase**.

### Gewerkschaftschef → „Alle Räder …“

1. **Aktivierung** (mannschaftsgebunden, `ObjectProfile.activateUnionWorkers`): **400 €** Sofortkosten
   (`unionWorkersCost`); die Mannschaft umfasst bis zu `Kompetenz × unionWorkersTeamPerCompetence` gewählte,
   einsatzfähige Charaktere (`StaffEntryData.featureTeamIds`, V12-Feld; Auswahl-Dialog in `ScreenHireAndFire`).
2. **Aktives Fenster** = **1 Wochentick** (`unionWorkersActiveDuration`). Währenddessen gilt für die Sabotage:
   - **Teamgröße** = `1 + Mitglieder` (`ManagementFeatureService.sabotageTeamSize`) – also mehr als ein
     Mitarbeiter auf Mission;
   - **Erfolgschance**: `+ shadinessBonusPercent` aus der **gemittelten** `shadiness` der Mannschaft
     (linear zwischen 0 = −15 % und 100 = +15 % um den Neutralwert 50, `shadinessNeutral`/
     `shadinessMaxBonusPercent`) – die erste Wirkung der bisher ungenutzten `shadiness` (`9_Personal.md`);
   - **Rerolls**: ein zusätzlicher deterministischer Wurf je Mitglied (`sabotageAttempts`; der Wurf indexiert
     `ManagementFeatureService.sabotageRollFor` mit der Versuchs-Nummer);
   - **Erschöpfung**: `sabotageExhaustionPerMission` (12) wird auf die Mannschaftsgröße **gemittelt** und trifft
     Vitalität **und** Moral der Mitglieder (`RivalService.resolveSabotage`).
3. **Keine Nachteilphase**; die Auflösung selbst bleibt idempotent (`featureResolvedAt`).

> **Entscheidungen der V12-Erweiterung (fixiert):**
>
> | # | Frage | Entscheidung |
> |---|---|---|
> | V12-1 | „Qualität“ der V12-Rollen | **Keine neuen Stufen** – es gilt die bestehende deterministische **Kompetenz 1–4** aus der Personal-ID (E8/E13). |
> | V12-2 | „Produktivität“ der Mitarbeiter (Rush Hour) | **Keine neue Produktivitäts-Dimension:** Der Schub läuft über die **drei Eingangswerte** (→ Kunden/Woche) und die **entfallenden Mali**; die Gegenleistung ist rangverteilte Erschöpfung. |
> | V12-3 | Dauer der V12-Features | Rush Hour = `Kompetenz × Tagestick`, „Organisation ist alles“ = `Kompetenz × 2 Tagesticks`; Lagertetris und „Alle Räder …“ = **1 Wochentick**; **keine** Nachteilphase. |
> | V12-4 | Kostenmodell | Rush Hour 800 € fix, Lagertetris `Kompetenz × 500 €`, „Alle Räder …“ 400 € fix, „Organisation ist alles“ **150 € je aktivem Tag** (`featureCosts`). |
> | V12-5 | Mannschaft & Rerolls | Mannschaft = `1 + Kompetenz` (Auswahl in `ScreenHireAndFire`), gespeichert als `StaffEntryData.featureTeamIds`; ein Reroll je Mitglied; Wurf weiterhin deterministisch (CRC32 inkl. Versuchs-Nummer). |
> | V12-6 | `shadiness` | Erste Nutzung: **gemittelte** `shadiness` der Mannschaft als Erfolgs-Bonus/Malus (±15 %) – kein Zufall, keine Persistenz. |
> | V12-7 | Persistenz | `kProfileSchemaVersion` 8 → **9**: `StaffEntryData.featureTeamIds` (`List<int>?`) – **additiv/tolerant** (`null` bei Alt-Beständen). |

## Verwaltungsrollen (umgesetzt V13)

Die Rolle **Sicherheitschef** stand in `11a` bislang nur als Rohzeile (ohne Werte) in der Vorschlagsliste. Sie ist
jetzt Teil der Kategorie `management` und kombiniert eine **passive** Wirkung (Entdeckung) mit einem
**reaktiven** Feature (Gegenschlag). Beides baut auf dem Minimal-Modul „Rivalen-Sabotage gegen den Spieler“ auf
(`13_Gegner_Restaurants.md`).

| Aspekt | Wert / Verhalten |
|---|---|
| Rolle | `ManagementRole.securityChief`, Kategorie `management`, Wochenlohn **240 €** (`managementRoleWagePerWeek`) |
| Feature | `ManagementFeature.counterSabotage` („Rache ist Blutwurst“) |
| Qualität | bestehende deterministische **Kompetenz 1–4** (`ManagementFeatureService.competenceOf`) – **keine** neuen Stufen (V13-1) |
| Passiv – Entdeckung | `securityChiefDetectionBonusPercentPerCompetence` = **+10 % je Kompetenz**, additiv zur **Ø-`shadiness`** des (Kampf-)Personals × `incomingDetectionShadinessToPercent` (50 %), gedeckelt auf 100 % (`RivalService.incomingDetectionPercent`) |
| Aktivierung | **ziel-los** (`ObjectProfile.activateUntargetedFeature`), **1000 €** (`counterSabotageCost`) |
| Fenster | **1 Wochentick** (`counterSabotageActiveDuration`) scharf geschaltet; danach **1 Wochentick** Nachteilphase (`counterSabotageAftermathDuration`) – kein neuer Gegenschlag |
| Auslöser | ausschließlich ein im Fenster **entdeckter** Angriff; **höchstens ein** Gegenschlag je Arming (`StaffEntryData.featureResolvedAt`) |
| Ausführende | (a) angestellte **Chefsekretärin** (Chance wie ihre Sabotage, **ohne Kosten** und **ohne Mutation** ihrer Felder; ist sie selbst im Einsatz, greift (b)); (b) deterministisch rekrutierte Mannschaft |
| Mannschaft (b) | `Kompetenz × counterSabotageTeamPerCompetence` (1) **shadiness-stärkste**, einsatzfähige Charaktere (Tiebreak: kleinere ID); Erfolgschance `sabotageBaseSuccessPercent` + `Kompetenz × counterSabotageLeaderBonusPercentPerCompetence` (5) + gemittelte `shadiness` der Mannschaft (±15 %) |
| Wirkung (Erfolg) | Der Angreifer wird **wie durch eine eigene Sabotage** getroffen (`RestaurantData.sabotageTargetId`/`sabotageAppliedUntil` ⇒ Einkommens-Fenster + Prestige-Malus) |
| Wirkung (Misserfolg) | `counterSabotageFailureFine` (**1500 €**) als `penaltyCosts`; der Sicherheitschef nimmt den Schaden auf sich |
| Strafen-Minderung | `StaffRoleService.counterSabotagePenaltyReductionPercent`: Rechtsanwalt-Passiv (25 %) **plus** der **automatisch ausgelöste Winkelzug** des angestellten Rechtsanwalts (wie bei der Chefsekretärin **ohne** dessen Aktivierungskosten und **ohne** Mutation); auf 100 % gedeckelt |

**Ablauf im Wochen-Tick (`GameClockService.catchUp`, Blockende):**

1. Je Rivalen des Stadtteils fällt deterministisch, ob ein **Sabotageversuch** eingeht
   (`RivalService.incomingAttemptOccurs`, 20 % je Rivale und Block – `incomingSabotageChanceBasePercent`).
2. Je Versuch fällt deterministisch, ob er **entdeckt** wird (`incomingAttemptDetected`, Wurf <
   `incomingDetectionPercent`). Nur entdeckte Angreifer sind dem Spieler **namentlich bekannt**.
3. Ist „Rache ist Blutwurst“ scharf geschaltet und wurde mindestens ein Angriff entdeckt, folgt **genau ein**
   Gegenschlag gegen den ersten entdeckten Angreifer (Roster-Reihenfolge); eine Strafe wird wie jede andere
   Strafe im Wochenbudget gebucht (eine Quelle der Wahrheit), ein Erfolg öffnet das Wirkungsfenster für den
   Folgeblock.
4. **Unentdeckte** Angreifer schöpfen Einkommen ab: je Angreifer `incomingSabotageIncomePenaltyPercent`
   (**10 %**) des **Brutto-Blockeinkommens**, gedeckelt über `incomingSabotageIncomePenaltyMaxPercent`
   (**30 %**); die Abschöpfung mindert Blockbudget und ausgewiesenes Einkommen (`WeeklyTickResult.rivalSabotageLosses`),
   **nicht** die Strafen – der Angreifer bleibt unbekannt (kein Gegenschlag).
5. Idempotent: gleicher Snapshot ⇒ gleiches Ergebnis; `featureResolvedAt` verhindert einen zweiten Gegenschlag
   derselben Arming, `weekAnchor` wandert nur um volle Wochen (V8).

**Keine neuen Persistenzfelder:** Das Minimal-Modul ist eine **reine Funktion** aus Blockanker und Roster
(`CRC32('rival-attack:<blockAnchor>:<rivalId>')` bzw. `...-detected:...`); der Zustand des Gegenschlags liegt in
den bestehenden Feature-Feldern. `kProfileSchemaVersion` bleibt damit **9** (keine Migration).

> **Entscheidungen der V13-Erweiterung (fixiert):**
>
> | # | Frage | Entscheidung |
> |---|---|---|
> | V13-1 | „Qualität“ des Sicherheitschefs | **Keine neuen Stufen** – bestehende deterministische Kompetenz 1–4; Wochenlohn 240 €. |
> | V13-2 | Feature-Form | **Reaktiv und ziel-los**: Scharfschalten über `activateUntargetedFeature` (1000 €), Fenster 1 Wochentick, danach 1 Wochentick Nachteilphase (Muster der V11-Sabotage inkl. `featureResolvedAt`). |
> | V13-3 | Eingehende Sabotage | **Minimal-Modul** (Kapitel 13): 20 % Versuchswahrscheinlichkeit je Rivale und Block, deterministisch; Entdeckung = Ø-`shadiness` × 50 % + 10 %/Kompetenz; **keine** neuen Persistenzfelder, Schema bleibt v9. |
> | V13-4 | Auslöser | Nur **entdeckte** Angriffe **innerhalb** des scharf geschalteten Fensters; **höchstens ein** Gegenschlag je Arming. |
> | V13-5 | Ausführung | Mit Chefsekretärin führt **sie** (gratis, ohne Feld-Mutation); sonst rekrutiert der Sicherheitschef `Kompetenz × 1` shadiness-stärkste einsatzfähige Charaktere, führt sie an (Kompetenz-Bonus) und trägt die gemittelte Erschöpfung mit. Es wird **keine** Sabotageart gewählt (Minimal-Modul: eine einheitliche Wirkung wie die Sabotage E14). |
> | V13-6 | Misserfolg | `counterSabotageFailureFine` (1500 €) als Strafe; Minderung durch Rechtsanwalt-Passiv **plus** automatisch ausgelöstem Winkelzug (gedeckelt auf 100 %), **ohne** dessen Felder zu verändern. |
> | V13-7 | Wirtschaftliche Folge | Unentdeckte Angriffe schöpfen **Einkommen** ab: je Angreifer 10 % des Brutto-Blockeinkommens, gedeckelt auf 30 % (`incomingSabotageIncomePenaltyPercent`/`incomingSabotageIncomePenaltyMaxPercent`); **keine** Strafbuchung, der Angreifer bleibt unbekannt. Die Entdeckung entscheidet, ob ein Gegenschlag möglich ist; ein laufendes Wirkungsfenster wird vom Gegenschlag **überschrieben** (nur ein Fenster gleichzeitig). |

## Features – Sonderfertigkeiten spezieller Mitarbeiter

**Features** sind **aktive** Sonderfertigkeiten einzelner Nicht-Kampf-Mitarbeiter. Sie sind die dokumentierte
**Ausnahme** zum Passiv-Grundsatz der Rollen (binär, ohne Ankaufspreis): Ein Feature wird aktiv ausgelöst, kostet
**einmalig** Geld und läuft über zwei befristete Phasen – die **aktive Phase** und die **Nachteilphase**.
Die Fensterlängen sind **feature-spezifisch** (`ManagementFeatureService.activeDurationOf`/
`aftermathDurationOf`): Die PR-Kampagne nutzt die generischen Fenster (E10), Sabotage/Winkelzug/Kreative
Buchführung ihre eigenen (E14–E16, Abschnitt „Verwaltungsrollen (umgesetzt V11)“).

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
| `incomingSabotageChanceBasePercent` (V13) | 20 % | Versuchswahrscheinlichkeit je Rivale und Wochenblock |
| `incomingDetectionShadinessToPercent` (V13) | 50 % | Anteil der Ø-`shadiness`, der als Entdeckungsschwelle zählt |
| `securityChiefDetectionBonusPercentPerCompetence` (V13) | 10 % | Entdeckungs-Zuschlag je Kompetenz-Stufe des Sicherheitschefs |
| `incomingSabotageIncomePenaltyPercent` (V13) | 10 % | Einkommens-Abschöpfung je **unentdecktem** Angreifer (brutto, je Block) |
| `incomingSabotageIncomePenaltyMaxPercent` (V13) | 30 % | Deckel der Abschöpfung je Block |
| `counterSabotageCost` / `counterSabotageFailureFine` (V13) | 1000 € / 1500 € | Aktivierung des Gegenschlags / Strafe bei Misserfolg |
| `counterSabotageActiveDuration` / `counterSabotageAftermathDuration` (V13) | je 1 Woche | Scharfgeschaltetes Fenster / Nachteilphase |
| `counterSabotageLeaderBonusPercentPerCompetence` / `counterSabotageTeamPerCompetence` (V13) | 5 % / 1 | Erfolgs-Zuschlag je Kompetenz-Stufe / rekrutierte Mitglieder je Stufe |

> Umsetzung (Option C, G1/G2/G5): `ManagementFeature`/`kAllManagementFeatures`
> (`lib/models/management_feature.dart`) · `StaffEntryData.activeFeature`/`featureTargetId`/`featureActivatedAt` ·
> `ManagementFeatureService` (Anker-Fenster, Kompetenz, Faktoren) · Hooks in `GameClockService.catchUp`
> (Tages-XP, Sink, Refill, Reset) und `ScreenBattleResult` (Gefechts-XP) · Aktivierung über
> `ObjectProfile.activateManagementFeature` · UI/l10n in `ScreenHireAndFire` ·
> `kProfileSchemaVersion = 8` (additiv/tolerant) · Tests in `test/management_feature_test.dart`.

**Entscheidungen (fixiert):**

| # | Frage | Entscheidung |
|---|---|---|
| E7 | Feature-Mechanik allgemein | **Aktiv, kostet, befristet** – Ausnahme zum Passiv-/Binär-Grundsatz; Träger, Ziel, Anker und Phasen sind Felder am gemeinsamen Eintragstyp (G2/G5). |
| E8 | „Kompetenz“ des Trägers | Explizite, **deterministische** Stufe 1–4 aus der Personal-ID; Boost = Stufe × 15 % während der aktiven Phase. |
| E9 | „Level × 1000 $“ | **Level des Kampagnen-Ziels**; einmalige Sofortbuchung bei Aktivierung (eigene Konstante – nicht die XP-Schwelle). |
| E10 | Nachteilphase | Genau **eine Woche** nach der aktiven Phase, nur das Ziel: Tages-Sink ×2, Refill halb; Null-Anker/Malus unverändert. |
| E11 | Name „Promotion“ | Umbenannt in **„PR-Kampagne“** (`managementFeaturePrCampaign`, Code `ManagementFeature.prCampaign`) – „Promotion“ ist im Projekt bereits der Karriere-Aufstieg. |

**Entscheidungen der V11-Erweiterung (Verwaltungsrollen, fixiert):**

| # | Frage | Entscheidung |
|---|---|---|
| E12 | Drei neue Verwaltungsrollen | **Chefsekretärin** (220 €), **Rechtsanwalt** (260 €), **Buchhalter** (200 €) – Kategorie `management`, **binäre Passiv-Effekte** auf Kosten/Strafen (5 %/5 %, 25 %, 5 %), kein Ankaufspreis, keine Persönlichkeit. |
| E13 | „Qualität“ der Träger | **Keine neuen Qualitätsstufen:** Es gilt die bereits eingeführte, deterministische **Kompetenz 1–4** aus der Personal-ID (`ManagementFeatureService.competenceOf`, E8) für **alle** Feature-Skalierungen; die Passiv-Effekte bleiben binär. |
| E14 | Sabotage-Minimal-Modul (Kapitel 13) | Deterministischer Rivalen-Roster je Stadtteil (`RivalService`), Sabotage mit **1 Woche Vorlauf**, deterministischem Erfolgswurf (40 % + 10 %/Kompetenz), **1 Woche Wirkung** (Rivale −25 % Prestige, Spieler +15 % Einkommen), Strafe **3000 €** bei Aufdeckung, **1 Woche** Nachlauf. Nur das Wirkungsfenster wird persistiert. |
| E15 | „Winkelzug“ (Rechtsanwalt) | **1500 €** Aktivierung, **1 Woche** aktiv; Minderung `Kompetenz × 25 %` (bis Negation), **additiv** zum passiven Rollenabzug, gedeckelt auf 100 %; **3 Tage** Nachlauf. |
| E16 | „Kreative Buchführung“ (Buchhalter) | **1000 €** Aktivierung, aktive Dauer **Kompetenz × 1 Tagestick**, Negation **aller** laufenden Kosten **tagesanteilig** (`negatedDays / 7`); Burnout (Nachteilphase) in gleicher Länge. |
| E17 | Persistenz | `kProfileSchemaVersion` 7 → **8**: `StaffEntryData.featureResolvedAt` (Idempotenz-Marker der Tick-Auflösung) und `RestaurantData.sabotageTargetId`/`sabotageAppliedUntil` – **additiv/tolerant**, keine Pflichtfelder. |

> **Noch offen:** weitere Features/Rollen (weitere `ManagementFeature`-Werte), ein UI-Countdown außerhalb der
> Personal-Karte sowie eine Zeile in `WeekSettlement` für die **Einmalkosten** der Features (derzeit
> Sofortbuchung außerhalb des Wochenrumpfes – Strafen sind dagegen bereits als `penaltyCosts` in
> `WeekSettlement`/`WeeklyTickResult`).

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
- **Drei Verwaltungsrollen mit Passiv-Effekt auf Kosten/Strafen (E12):** Chefsekretärin, Rechtsanwalt und
  Buchhalter sind umgesetzt; sie wirken **binär** und **nicht** auf das Einkommen (Abschnitt
  „Verwaltungsrollen (umgesetzt V11)“).
- **Eine Kompetenz für alles (E13):** Feature-Skalierungen nutzen die bestehende deterministische
  Kompetenz 1–4 aus der Personal-ID; es gibt **keine** neuen Qualitätsstufen.
- **Sabotage & Strafen laufen in einem Minimal-Modul (E14, Kapitel 13):** Rivalen werden deterministisch
  abgeleitet, die Sabotage wird im Wochen-Tick aufgelöst; der einzige Strafen-Erzeuger ist vorerst die
  aufgedeckte Sabotage – damit ist der **Chefsekretärin → Strafe → Rechtsanwalt**-Kreislauf spielbar.
- **Fenster je Feature (E15/E16):** Winkelzug (1 Woche aktiv, 3 Tage Nachlauf) und Kreative Buchführung
  (Kompetenz × 1 Tag aktiv, gleiche Burnout-Länge) haben je eigene Fenster in `EconomyBalance`; die
  PR-Kampagne nutzt unverändert die generischen Fenster (E10) – die Dauer-Auflösung liegt in
  `ManagementFeatureService.activeDurationOf`/`aftermathDurationOf`.
- **Persistenz additiv (E17):** Schema v8 ergänzt nur `featureResolvedAt` und das Sabotage-Fenster; alte
  Spielstände bleiben ladbar.

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
- **Rivalen-Minimal-Modul (E14):** Umgesetzt sind der Roster (deterministisch, je Stadtteil), die
  **Spieler-Sabotage** und seit **V13** die **eingehende Rivalen-Sabotage** samt **Entdeckung** und dem
  **Gegenschlag** des Sicherheitschefs (Abschnitt „Verwaltungsrollen (umgesetzt V13)“,
  `13_Gegner_Restaurants.md`). Die **wirtschaftliche Folge unentdeckter** Angriffe ist seit V13 ein
  **Einkommens-Abschöpfung** (10 % je Angreifer, Deckel 30 %, Abschnitt „Verwaltungsrollen (umgesetzt V13)“).
  Offen bleiben die Rivalen-Simulation (Mini-PP), die Rangliste/„Platz X von Y“ und die Gefechtsteilnahme.
- **Strafen-Quellen:** Bislang erzeugt nur die aufgedeckte Sabotage Strafen; weitere Quellen (Behörden,
  Rufschädigung) sind noch nicht modelliert – der Rechtsanwalt wirkt dann automatisch mit.
- **Sabotage-Namen:** Die Rivalen-Namen stammen aus dem Namensgenerator und werden je Stadtteil
  zwischengespeichert (nur kosmetisch) – die Determinismus-Anforderung gilt für **IDs/Persönlichkeiten/Prestige**.

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

**Neues Feature mit eigenem Auflösungs-Modul (Vorbild E14/Sabotage):**
`ManagementFeature`-Wert + `managementFeatureOf(role)` → `EconomyBalance` (Kosten/Fenster/Erfolgswerte) →
`ManagementFeatureService` (`activeDurationOf`/`aftermathDurationOf` + Wurf) → eigener, **reiner** Auswertungs-
Dienst (z. B. `RivalService`) → Idempotenz-Marker am Eintrag (`featureResolvedAt`) + Hook im `catchUp` →
Aktivierungs-API `ObjectProfile.activateSabotage`/`activateUntargetedFeature` → l10n/UI →
**Tests für Determinismus, Idempotenz und Buchung**.

## Anhang: Belege

- Modell/Persistenz: `lib/models/support_role.dart` · `lib/models/staff_entry.dart` (`RoleKind`,
  `StaffEntryData` inkl. Feature-Feldern) · `lib/models/management_role.dart` (`ManagementRole`) ·
  `lib/models/management_feature.dart` (`ManagementFeature`) · `lib/models/rival_restaurant.dart`
  (`RivalRestaurant`, Kapitel 13) · `lib/models/profile_data.dart`
  (`SupportRoleData`, `RestaurantData.supportStaff`/`staffEntries`, `kProfileSchemaVersion = 9`)
- Balance: `lib/services/economy_balance.dart` (`supportRoleWagePerWeek`, `managementRoleWagePerWeek`,
  `socialMediaManagerIncomePercent`, `chefSecretary*`, `lawyerPenaltyReductionPercent`,
  `accountantOngoingCostReductionPercent`, `headWaiter*`, `personnelManager*`, `storekeeper*`, `unionChief*`,
  `shadiness*`, alle `*Bonus`/`*Percent`, `patissierRefillBonusPercent`, `feature*`,
  `sabotage*`, `legalTrick*`, `creativeAccounting*`, `rushHour*`, `organisation*`, `storageTetris*`,
  `unionWorkers*`, `rivalCount*`) ·
  Auswertung: `lib/services/support_role_service.dart`, Contract: `lib/services/staff_role_service.dart`
  (`managementIncomePercent`, `nonCombatWeeklyWages`, `penaltyReductionPercent`, `reduceByPercent`, V12:
  `headWaiterAttractivenessBonus`, `personnelManagerSatisfactionBonus`, `capacityPercent`,
  `unionChiefWageIncreasePercent`, `unionChiefSinkReductionPercent`) ·
  Features: `lib/services/management_feature_service.dart` · Rivalen: `lib/services/rival_service.dart`
  (`sabotageChancePercent`, `resolveSabotage`)
- Verwaltung/Abrechnung: `lib/objects/object_profile.dart` (`hireSupportRole`/`fireSupportRole`,
  `hireManagementRole`/`fireStaffEntry`, `activateManagementFeature`, `activateUntargetedFeature`,
  `activateSabotage`, `activateUnionWorkers`, `managementFeatureActivationCost`, `unionWorkersTeamLimit`,
  `upgradePurchaseCost`) ·
  `lib/services/game_clock_service.dart` (`catchUp`, `_refillStaffResources`, `_probeResources`,
  `_applyDailyResourceSink`, `_rushHourExhaustionShares`, `_applyFeatureDailyXp`, `_negateCostDays`,
  `_resolveDueSabotage`, `attractivenessOf`/`satisfactionOf`/`capacityOf`) ·
  `lib/screens/screen_battle_result.dart` (Boucher, Feature-XP-Boost)
- UI/l10n: `lib/screens/screen_hire_and_fire.dart` (Kategorie-Abschnitte + Feature-Aktivierung inkl.
  Mannschafts-Dialog, Rivalen-Liste) ·
  `lib/l10n/support_role_labels.dart`, `lib/l10n/management_role_labels.dart`,
  `lib/l10n/management_feature_labels.dart` + ARB (DE/EN)
- Tests: `test/support_role_test.dart`, `test/weekly_wages_test.dart`, `test/staff_entry_test.dart`,
  `test/management_feature_test.dart`, `test/management_roles_v11_test.dart`,
  `test/management_roles_v12_test.dart`, `test/rival_service_test.dart`,
  `test/sabotage_tick_test.dart`, `test/balance_sanity_test.dart`
- Doku: `10_Karrierepfade.md` § 3 & Phasen 6–8 · `2-Wirtschaftsschleife.md` § 8 & Wochen-Tick ·
  `11b_Restauranterweiterungen.md` (Erweiterungs-Unterhalt) · `13_Gegner_Restaurants.md`
  (Minimal-Modul V11: Sabotage-Auflösung & Strafen) · `9_Personal.md` (`shadiness`-Wirkung) · `0-Base.md` Nr. 3