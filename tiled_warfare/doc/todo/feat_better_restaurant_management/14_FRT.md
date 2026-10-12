# Die FRT (Kapitel 14)

> **Status:** Kern **und Laufzeit-Verdrahtung umgesetzt** (Paket B + C). `FrtService`, die
> `frt*`-Parameter in `EconomyBalance`, die `RestaurantData`-Felder (`corruptionPercent` /
> `districtLost` / `districtLostAt`, Schema 10), die Integration im Wochen-Tick
> (`GameClockService`: Anstieg, Einkommens-Malus, PP-Malus Q8, Verlustregel,
> `WeeklyTickResult`) **sowie die Laufzeit-Pfade** (Monster-Skalierung in `object_host.dart`,
> Senkung durch Gefechte über `ScreenBattleResult`/`WidgetCaretaker`, FRT-Fehl-Attribution in
> `rival_service.dart`, Gründungs-Sperrhinweis + Korruptionsanzeige in `screen_start.dart`/
> `screen_restaurant.dart`) sind implementiert und getestet. Die Entscheidungen aus den
> „Offenen Fragen“ sind eingearbeitet (Q1, Q3–Q8; Q2-Werte als Tuning in `EconomyBalance`
> verankert). Dieses Dokument spezifiziert die **FRT** als übergeordnete Gegner-Fraktion
> („der wahre Gegner des Spiels“): Zusammensetzung, das **Korruptionsmeter** und ihre
> **Sabotagen**.
> Es baut auf `13_Gegner_Restaurants.md` (V13-Sabotagemodul, Sicherheitschef),
> `8_Echtzeit-Zeitsystem.md` (V8, Wochen-Tick/Catch-up) und `2-Wirtschaftsschleife.md`
> (§ 8, passives Einkommen) auf.

## Ziel

Die FRT ist eine **eigenständige, übergeordnete Fraktion**, die aus drei Gruppierungen
besteht – kein einheitlicher Clan, sondern ein **Triumvirat**:

- **Familie Dumpster** – Ursprung der Teig-Zombies und Dough Dumpsters, die im Gefecht bekämpft werden,
- **Fraternitas** – eine Bruderschaft von Managern,
- **dem T** – einem Kult, der den Buchstaben T verehrt.

> **Abkürzung „FRT“ (Q5):** „FRT“ ist ein **Kofferwort** aus den Namen der drei
> Gruppierungen: **F**raternitas, **R**eginald Dumpster (Oberhaupt der Familie) und die
> Bruderschaft des **T**.

Das Triumvirat agiert **abseits der Rangliste** und ist damit kein Rivale im Sinne von
`13_Gegner_Restaurants.md`. Stattdessen ist die FRT der **wahre Gegner des Spiels** und
der Grund für die Gefechte. Mit jedem **Wochen-Tick** (V8) füllt sie langsam, aber stetig
ihr **Korruptionsmeter** auf.

## Entscheidungen (getroffen)

Die früheren „Offenen Fragen“ sind entschieden und in den Text eingearbeitet:

| # | Frage | Entscheidung |
|---|---|---|
| Q1 | Skopus der Korruption | **Je Stadtteil** – ein Meter pro Stadtteil, kein globales Meter (passt zu „Stadtteil verloren“ und zur Einkommens-Strafe). |
| Q3 | Monsterskalierung | **Alle Monster-Werte** skalieren (Angriff/LP/Geschwindigkeit u. a.), auch Spawner (Dough Dumpster). |
| Q4 | „Verlorener“ Stadtteil | **Entschädigungslos** geschlossen, aber **erholbar**: Fällt die Korruption wieder unter den Schwellenwert, ist der Stadtteil wieder bespielbar (Gründung frei). Das geschlossene Restaurant wird **nicht** wiederhergestellt. |
| Q5 | Abkürzung „FRT“ | Kofferwort aus den Namen der drei Gruppierungen (siehe „Ziel“). |
| Q6 | Sabotage-Scope | **Erweiterung des V13-Moduls** mit FRT-Fehl-Attribution (dritte Partei). |
| Q7 | „Abseits der Rangliste“ vs. Angriffsziel | Durch **Gefechte** und **Gegensabotage**, sobald ein Rivale die FRT bemerkt hat. |

## Korruption

### Definition & Skala

Die Korruption (Skala **0–100 %**, **je Stadtteil** – Q1) ist ein Wert, der sehr langsam,
aber **beständig** ansteigt. Intern als `double` in Prozentpunkten geführt (deterministisch,
keine Rundungsdrift im Catch-up); **gerundet nur an der Anzeige**. Je höher die Korruption,
desto mächtiger die Monster, die im Gefecht bekämpft werden.

### Zustand & Persistenz

Da je Stadtteil **höchstens ein Restaurant** existiert (`1_mehrere_Restaurants.md`;
`RestaurantData.district`, `lib/models/profile_data.dart`), ist „Korruption je Stadtteil“
für den Spieler identisch mit „Korruption des Restaurants dieses Stadtteils“:

- `RestaurantData.corruptionPercent` (`double`, 0–100, Default `0`) – **neu**, tolerant
  deserialisiert (fehlend → `0`, Werte außerhalb 0–100 geklemmt, V6-Prinzip);
  `kProfileSchemaVersion` **9 → 10**.
- `RestaurantData.districtLost` (`bool`, Default `false`) und `districtLostAt`
  (`DateTime?`) – **neu**: persistieren den „verlorenen“ Stadtteil auch **über** die
  Auflösung des Restaurants hinweg (Q4).

> **Warum persistiert?** Anders als der Rivalen-Roster oder das Ranking (rein ableitbar,
> `13_Gegner_Restaurants.md` → „Persistenz“) ist Korruption **ereignisgetrieben**
> (Senkung durch Kills/Siege, zusätzlicher Anstieg durch FRT-Sabotage und Eliminierungen).
> Sie ist deshalb ein **normaler `RestaurantData`-Wert** wie `budget` – kein reiner
> Funktionswert des Catch-ups.

### Anstieg

- **Wochen-Tick (V8):** `+ frtCorruptionPerWeekPercent` je vollendetem 7-Tage-Block
  (Vorschlag: `1`; Cap `frtCorruptionCeilingPercent = 100`).
- **FRT-Sabotage (Q8):** `+ frtCorruptionPerSabotagePercent` je **unbemerkt gebliebener**
  FRT-Sabotage (Fehl-Attribution erfolgreich).
- **Eliminierung eines Rivalen (Q8):** `+ frtCorruptionPerEliminationPercent` – „alles,
  was einem Rivalen schadet, nutzt der FRT“.

### Senkung

- Je **getötetem Monster**: `− frtCorruptionReducePerMonsterPercent` (Vorschlag `0.5–1`),
  im Gefechtsergebnis gebucht und sofort persistiert.
- Je **erfolgreichem Gefecht**: `− frtCorruptionReducePerVictoryPercent` (Vorschlag `1–2`).
- **Floor:** nie unter `frtCorruptionFloorPercent = 0` (keine negativen Werte);
  **Cap:** nie über `frtCorruptionCeilingPercent = 100`.

### Formeln (eindeutige Einheiten)

Mit `f = korruption / 100` (bei 100 % Korruption also `f = 1`):

| Effekt | Formel | Beispiel |
|---|---|---|
| Monsterstärke | `monsterFaktor = 1 + f × (frtMonsterStrengthScalePercent / 100)`; je Statwert `(wert × monsterFaktor).round()` zum Spawn. `frtMonsterStrengthScalePercent` = **Zuschlag bei 100 % Korruption**. | Korruption 50 %, Scale 100 % ⇒ Faktor 1.5 |
| Passives Einkommen | `malusProzent = f × frtCorruptionIncomePenaltyMaxPercent` (max. bei 100 %); `incomePerWeekEff = incomePerWeek − (incomePerWeek × malusProzent / 100).round()` | Korruption 50 %, Max-Malus 30 % ⇒ −15 % |
| Power Projection (Q8) | `incomeFaktorEffektiv = powerProjectionIncomeFactor(PP) × (1 − f × frtPowerProjectionPenaltyPercent / 100)`, geklemmt auf ≥ 0 | – |

Alle Anwendungen sind **deterministisch** (kaufmännische Rundung), es gibt **keinen Zufall** –
Skalierung und Malus sind reine Funktionen der Korruption zum Zeitpunkt des Spawns bzw. Blocks.

### Wirkung auf das Spiel

| Effekt | Mechanik |
|---|---|
| Monsterstärke | Gefechts-Monster **und** Spawner des Stadtteils skalieren mit `monsterFaktor` (Q3); Einzelheiten zu Bewegungs-/LP-Werten: offene Frage F3. |
| Passives Einkommen | Abzug auf das **Wochen-Einkommen** des Stadtteils (§ 8) – `incomePerWeekEff` **vor** der Aufteilung in Tageserträge (`~/ 7`, der Resttag trägt den Rundungsrest). |
| Power Projection | Je höher die Korruption, desto geringer der PP-Einkommensfaktor (`12_Power_Projection.md` → „Effekte“) und die Wochenabrechnung (Q8). |
| „Verlorener“ Stadtteil | Bei **100 % Korruption** gilt der Stadtteil als **verloren**: Bestehende Restaurants werden **entschädigungslos** geschlossen, neue können dort nicht gegründet werden. Fällt die Korruption wieder **unter** den Schwellenwert, ist der Stadtteil **erholbar** (Q4). |

> **Hysterese:** Die Verlustregel greift ab `frtCorruptionLostThresholdPercent` (Vorschlag
> 100) und löst sich erst wieder auf, wenn die Korruption **echt unter** den Schwellenwert
> fällt – kein Kippen bei exakt 100.

## Ablauf im Wochen-Tick (Reihenfolge)

Integration in `GameClockService.catchUp` (V8, § 6). Die Korruption wird wie `budget`
**monoton** fortgeschrieben – die V8-Idempotenz bleibt erhalten (zweiter Aufruf mit
gleichem `now` ⇒ keine Fälligkeit, kein Korruptions-Update):

1. **Blockanfang:** `+ frtCorruptionPerWeekPercent` (geklemmt auf 0–100). Erreicht die
   Korruption den Schwellenwert `frtCorruptionLostThresholdPercent`, wird `districtLost`
   gesetzt und das Restaurant geschlossen (Q4).
2. **Einkommen:** `incomePerWeekEff` aus der aktuellen Korruption; danach wie gehabt
   `incomePerDay = incomePerWeekEff ~/ 7` (der Resttag trägt den Rundungsrest) – gilt auch
   für die **Resttage** (`leftoverDays`).
3. **Blockende:** Der Malus steckt bereits im Tagesertrag; die **V13-Einkommens-Abschöpfung**
   (`rivalLossForBlock`, Kapitel 13) wird wie gewohnt **zusätzlich** auf das Block-Einkommen
   angewandt (**additiv**, nicht multiplikativ).
4. **Ergebnis:** `WeeklyTickResult.corruptionByDistrict` (`Map<String, int>`, gerundet) und
   `WeeklyTickResult.lostDistricts` (`List<String>`).

> **Reihenfolge-Randfall:** Die gewohnte Kaskade „passives Einkommen → Kosten → Zinsen“ bleibt
> unverändert; der Korruptions-Malus dämpft nur die Einkommensseite.

## Sabotagen (Fehl-Attribution, V13-Erweiterung)

Sabotagen sind die bevorzugte Taktik der FRT. Ihre Agenten lassen die Taten **wie die eines
Rivalen** aussehen (**Fehl-Attribution**; das V13-Entdeckungsmodul greift entsprechend).
Technisch ist das eine **Erweiterung von `RivalService`** (Q6):

- Die V13-Auflösung (`resolveIncomingSabotage`) kennt eine **dritte Partei**: Ein Angriff
  trägt `trueAttacker = frt` und die **behauptete** Rivalen-ID (`attributedToRivalId`,
  deterministisch gewählt).
- **Entdeckung:** Nur wenige anheuerbare Mitarbeiter – etwa der **Sicherheitschef** (V13) –
  oder eine **Restauranterweiterung** wie die Sicherheitstechnik (`11b`, `security`) bringen
  die Wahrheit ans Tageslicht; der Angriff wird dann **nicht** dem behaupteten Rivalen
  angelastet.
- **Konsequenzen (Q7/Q8):** Bleibt die Fehl-Attribution **unbemerkt**, schürt sie
  Rivalitäten zwischen den Rivalen (Stance-Verschiebungen, Kapitel 13 → „Stance“) und erhöht
  zugleich die Korruption (siehe „Anstieg“). **Wird** die FRT entdeckt, ist sie bei allen
  Rivalen **verhasst** und gilt als bevorzugtes Angriffsziel – auch ohne Ranglisten-Platz:
  Rivalen greifen sie **durch Gefechte und Gegensabotage** an, sobald sie sie bemerkt haben.

## Offene Fragen (verbleibend)

> **Entschieden und umgesetzt:** **Q2** (Werte-Tuning) – die konkreten Beträge stehen final in
> `EconomyBalance` (`frtCorruptionPerWeekPercent = 1`, `frtCorruptionPerSabotagePercent = 2`,
> `frtCorruptionPerEliminationPercent = 3`, `frtCorruptionReducePerMonsterPercent = 0.5`,
> `frtCorruptionReducePerVictoryPercent = 1`, `frtMonsterStrengthScalePercent = 100`,
> `frtCorruptionIncomePenaltyMaxPercent = 30`, `frtPowerProjectionPenaltyPercent = 30`,
> `frtSabotageSharePercent = 30`). **Q8** (PP-Formel) – der Korruptions-Abzug auf den
> PP-Einkommensfaktor läuft im Wochen-Tick **vor** der Einkommensbuchung
> (`FrtService.powerProjectionIncomeFactor`).

1. **Erholung verlorener Stadtteile (Q4b):** Ohne eigenes Restaurant gibt es im verlorenen
   Stadtteil keine eigenen Gefechte ⇒ keine Senkungs-Quelle. **Vorschlag:** „Befreiungs-Gefechte“
   in verlorenen Stadtteilen erlauben (Monster spawnen dort weiter mit maximaler Skalierung);
   alternativ langsamer natürlicher Verfall.
2. **Monster-Skalierung im Detail (Q3b):** **Entschieden** – es skalieren **alle** `UnitStats`
   (Angriff/Verteidigung/Schaden/**LP/Wound/Movement**/Range/Money/XP), je Stat deterministisch
   gerundet (`(wert × faktor).round()`). Umgesetzt in `ObjectDoughZombie`/`ObjectDoughDumpster`.
3. **Fehl-Attribution im Detail (Q6b):** Deterministische Wahl der „behaupteten“ Rivalen-ID ist
   umgesetzt (`attributedRivalId`, Roster-Index per CRC32) – **offen** bleiben die Entdeckungs-
   wahrscheinlichkeit über Sicherheitstechnik (`11b`, `security`) sowie die Frage, ob eine FRT-Sabotage
   zusätzlich die V13-Einkommens-Abschöpfung auslöst (aktuell: ja, sie zählt wie jede unentdeckte
   Rivalen-Sabotage) oder vollständig in Korruption mündet.
4. **Stance/Angriffsziel (Q7b):** Wie genau Rivalen eine **ranglose** Fraktion angreifen
   (Gefechts-Teilnahme gegen FRT-Monster, Gegensabotage) und welche Stance-Schwellen und
   -Parameter dazu in `EconomyBalance` kommen. Die Fehl-Attribution als solche ist verdrahtet;
   die persistente „Fehde“ (Stance-Verschiebung) braucht noch ein Zustandsfeld (C2).

## Betroffene Dateien

| Datei | Änderung | Status |
|---|---|---|
| `lib/services/frt_service.dart` | **Neu:** reine, deterministisch testbare Korruptions-Simulation (analog `RivalService`): `afterBlock`, `addSabotage`, `addElimination`, `reduce`, `isDistrictLost`, `monsterStrengthFactor`, `scaleStat`, `incomeMalusPercent`, `applyIncomeMalus`, `powerProjectionIncomeFactor`. | ✅ |
| `lib/models/profile_data.dart` | `RestaurantData.corruptionPercent`, `districtLost`, `districtLostAt`; tolerante Serialisierung; `kProfileSchemaVersion` 9 → 10. | ✅ |
| `lib/services/economy_balance.dart` | Alle `frt*`-Parameter (V7: keine magischen Zahlen). | ✅ |
| `lib/services/game_clock_service.dart` | Korruptions-Update im Wochen-Tick; Einkommens-Malus vor der Tages-Aufteilung; `WeeklyTickResult.corruptionPercent` (gerundet) / `lostDistricts`. Abweichung zur ursprünglichen Planung: je Restaurant statt Stadtteil-`Map`, da `RestaurantData` den Stadtteil bereits kapselt. | ✅ |
| `lib/objects/object_host.dart` | Monster-Skalierung je Stadtteil-Korruption zum Spawn (`monsterStrengthFactor`, deterministischer Faktor, `.round()`); reicht den Faktor an Dough Dumpster/Zombies weiter. | ✅ |
| `lib/services/rival_service.dart` | FRT-Fehl-Attribution in der V13-Auflösung (dritte Partei): `isFrtAttack` (CRC32, `frtSabotageSharePercent`), `frtAttackerIds`, `attributedRivalId`; `IncomingSabotageOutcome.frtAttackerIds` + `undetectedFrtCount`. Stance-/Fehde-Störungen bleiben C2. | ✅ |
| `lib/objects/object_profile.dart` | Laufzeit-Zustand `corruptionPercent`/`districtLost`/`districtLostAt` **und** `isDissolved`/`dissolvedAt`; Snapshots/Catch-up/Save-Merge (A0) und `reduceCorruption` (Gefechts-Senkung). | ✅ |
| `lib/objects/monsters/object_dough_zombie.dart`, `lib/objects/boss_monsters/object_dough_dumpster.dart` | `strengthFactor` skaliert alle `UnitStats` (Zombies **und** Spawner); Spawner gibt den Faktor an gespawnte Zombies weiter. | ✅ |
| `lib/widgets/widget_caretaker.dart` | Zählt getötete Monster und meldet sie (3. Callback-Parameter); setzt `ObjectHost.monsterStrengthFactor`. | ✅ |
| `lib/screens/screen_main.dart` | Nimmt `monsterStrengthFactor` entgegen und leitet Kills + Faktor weiter. | ✅ |
| `lib/screens/screen_battle_result.dart` | `enemyKills` → `ObjectProfile.reduceCorruption` **vor** `saveToStorage`. | ✅ |
| `lib/screens/screen_restaurant.dart` | Gefechtsstart übergibt `FrtService.monsterStrengthFactor(corruption)`; Korruptionsanzeige im Kopfbereich. | ✅ |
| `lib/screens/screen_start.dart` | Gründungs-Sperrhinweis für einen verlorenen Stadtteil (distinkte Meldung). | ✅ |
| `lib/l10n/app_de.arb`, `app_en.arb` | Strings `districtLostMessage` und `corruptionLabel` (via `flutter gen-l10n`). | ✅ |

## Tests (neu)

- `test/frt_service_test.dart` – ✅ neu: Anstieg (Wochen-Tick, Sabotage, Eliminierung),
  Clamps (Floor 0 / Cap 100), Reduktion durch Monster/Siege, 100-%-Schwelle inkl. Hysterese,
  Determinismus/Idempotenz im Catch-up (zwei Teil-Catch-ups ergeben einen Catch-up),
  Einkommens-Malus und Rundungs-Stabilität; enthält auch die Integrationsfälle
  `GameClockService.catchUp` (Anstieg je Block, Resttage, Schwelle/verloren, Einkommens-Drop)
  und die tolerante `RestaurantData`-Persistenz (Schema 10).
- `test/balance_sanity_test.dart` – ✅ erweitert: alle `frt*`-Werte zentral in `EconomyBalance`,
  nicht-negativ, Schwellen/Faktoren im gültigen Bereich (Floor < Cap, Verlustschwelle,
  Malus-/Monster-Faktoren, Klamm-Invariante).
- `test/profile_data_test.dart` – ✅ erweitert: tolerante Deserialisierung
  (`corruptionPercent` / `districtLost`), Schema-Migration 9 → 10.
- `test/rival_service_test.dart` / `test/frt_runtime_test.dart` – ✅ erweitert: FRT-Fehl-Attribution
  (`isFrtAttack`/`frtAttackerIds`/`attributedRivalId` deterministisch, Teilmenge der Angreifer,
  Korruptions-Anstieg im Wochen-Tick) sowie die A0-Persistenz (`ObjectProfile`-Roundtrip,
  `reduceCorruption`) und Q8 (`incomeFactor` sinkt mit der Korruption).
- `test/object_host_test.dart` – ✅ neu: Monsterwerte skalieren deterministisch je
  Stadtteil-Korruption (Zombies **und** Spawner; Zombies erben den Spawner-Faktor).

## Definition of Done / Abnahmekriterien

- [x] Alle `frt*`-Werte existieren genau einmal – in `EconomyBalance` (V7); keine magischen
  Zahlen in Services/Objekten.
- [x] `FrtService` ist rein und deterministisch (injizierte Zeit, kein Zufall); jede Formel
  aus „Korruption“ ist einzeln testbar.
- [x] Korruption wird tolerant persistiert (V6), auf 0–100 geklemmt und im Catch-up
  **monoton** fortgeschrieben (V8-Idempotenz bleibt erhalten).
- [x] Der Einkommens-Malus ist für volle Wochen **und** Resttage identisch berechnet;
  `WeeklyTickResult` stellt `corruptionPercent` (gerundet) und `districtLost` bereit.
- [x] Monster (inkl. Spawner) skalieren deterministisch aus der Stadtteil-Korruption zum
  Spawn-Zeitpunkt (`FrtService.monsterStrengthFactor`/`scaleStat` → `ObjectHost.monsterStrengthFactor`,
  Dough Zombies **und** Dough Dumpster; gespawnte Zombies erben den Spawner-Faktor).
- [x] Die „Verlorener Stadtteil“-Regel entspricht Q4: Das **entschädigungslose Schließen** ist
  umgesetzt (Korruption ≥ Schwelle setzt `districtLost` + `isDissolved`, die bestehenden
  Aufgelöst-Mechaniken greifen); die **Gründungssperre** meldet den verlorenen Stadtteil
  distinkt (`districtLostMessage`), und die **Erholung unter die Schwelle** (Hysterese:
  `isDistrictLost` nutzt `>=`) hebt `districtLost` über `ObjectProfile.reduceCorruption` auf
  (Senkungs-Call-Site im Gefechtsergebnis).
- [x] `flutter analyze` ohne neue Warnungen; `flutter test` grün (inkl. der neuen Tests).

## Risiken

- **Save-Kompatibilität:** Neue `RestaurantData`-Felder werden tolerant deserialisiert
  (fehlend → Defaults); Schema-Bump 9 → 10 analog `11a` (E4), Alt-Stände bleiben ladbar.
- **Catch-up-Drift:** Der Malus darf die Rundungs-Invariante „Σ Blocktag =
  `incomePerWeekEff`“ nicht brechen – Malus **vor** der `~/ 7`-Aufteilung anwenden und per
  `balance_sanity_test` absichern.
- **Doppelbesteuerung:** Korruptions-Malus und V13-Abschöpfung sind **additiv** zu definieren
  (Reihenfolge siehe „Ablauf im Wochen-Tick“).
- **Verhaltensänderung:** Alle Schritte als reine Erweiterungen (neue Felder/Parameter)
  einführen; bestehende Tests (`game_clock_service_test`, `rival_service_test`,
  `balance_sanity_test`) bleiben grün.
