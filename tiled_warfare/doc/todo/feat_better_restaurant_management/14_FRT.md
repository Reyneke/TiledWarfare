# Die FRT

> **Status:** Entwurf. Dieses Dokument spezifiziert die **FRT** als übergeordnete Gegner-Fraktion
> („der wahre Gegner des Spiels“): Zusammensetzung, das **Korruptionsmeter** und ihre **Sabotagen**.
> Es baut auf `13_Gegner_Restaurants.md` (V13-Sabotagemodul, Sicherheitschef), `8_Echtzeit-Zeitsystem.md`
> (V8, Wochen-Tick/Catch-up) und `2-Wirtschaftsschleife.md` (§ 8, passives Einkommen) auf.

## Ziel

Die FRT ist eine **eigenständige, übergeordnete Fraktion**, die eigentlich aus drei Gruppierungen
besteht – kein einheitlicher Clan, sondern ein **Triumvirat**:

- **Familie Dumpster** – Ursprung der Teig-Zombies und Dough Dumpsters, die im Gefecht bekämpft werden,
- **Fraternitas** – eine Bruderschaft von Managern,
- **dem T** – einem Kult, der – warum auch immer – den Buchstaben T verehrt.

Das Triumvirat agiert **abseits der Rangliste** und ist damit kein Rivale im Sinne von
`13_Gegner_Restaurants.md`. Stattdessen ist die FRT der **wahre Gegner des Spiels** und der Grund für
die Gefechte. Mit jedem **Wochen-Tick** (V8) füllt sie langsam, aber stetig ihr **Korruptionsmeter** auf.

## Korruption

**Definition:** Die Korruption (Skala 0–100 %, je Stadtteil – offene Frage Q1) ist ein Wert, der sehr
langsam, aber **beständig** ansteigt. Je höher die Korruption, desto mächtiger die Monster, die im
Gefecht bekämpft werden.

**Anstieg (Wochen-Tick):** `+ frtCorruptionPerWeek` je Wochen-Tick (Vorschlag: +1 %; Tuning in
`EconomyBalance`, V7).

**Senkung:** Jedes getötete Monster und jedes erfolgreiche Gefecht senken die Korruption
(`− frtCorruptionReducePerMonster` bzw. `− frtCorruptionReducePerVictory`); sie fällt dabei **nie unter 0**
(Floor, kein negativer Wert).

**Wirkung auf das Spiel:**

| Effekt | Mechanik (Vorschlag) |
|---|---|
| Monsterstärke | Gefechts-Monster im Stadtteil skalieren mit `1 + Korruption × frtMonsterStrengthScalePercent`. |
| Passives Einkommen | Hohe Korruption führt zu **stärkeren Monstern** und **vermindertem passiven Einkommen** (§ 8): Abzug `− Korruption × frtCorruptionIncomePenaltyPercent` auf das Wochen-Einkommen im betroffenen Stadtteil. |
| „Verlorener“ Stadtteil | Bei **100 % Korruption** gilt ein Stadtteil als **„verloren“**: Weder können dort neue Restaurants gegründet werden, noch können welche existieren – die FRT hat sie alle verdrängt (Folgen: offene Frage Q4). |

## Sabotagen

Sabotagen sind eine bevorzugte Taktik der FRT. Dabei bemühen sich ihre Agenten, die Taten **wie die
eines Rivalen** aussehen zu lassen (Fehl-Attribution; das V13-Entdeckungsmodul greift entsprechend).

Nur wenige anheuerbare Mitarbeiter – etwa der **Sicherheitschef** (V13) – oder eine
**Restauranterweiterung** wie die Sicherheitstechnik (`11b`, `security`) können die Wahrheit ans
Tageslicht bringen.

Folgerichtig ist die FRT bei allen Rivalen **verhasst** und gilt als bevorzugtes Angriffsziel
(Anbindung: `13_Gegner_Restaurants.md`, Stance – Details: offene Frage Q7).

## Offene Fragen

1. **Skopus der Korruption:** Ein globales Meter („Stadtteil verloren“ wäre dann eine Schwelle des
   einen Meters) oder ein Meter **je Stadtteil** (passt zu „Stadtteil verloren“ und zur
   Einkommens-Strafe)? **Empfehlung:** je Stadtteil.
2. **Werte:** Anstieg, Senkungen und Prozentsätze in `EconomyBalance` tunen (siehe Parameter oben).
3. **Monsterskalierung:** Welche Statistiken skalieren (Angriff/LP/Geschwindigkeit) – nur Zombies oder
   auch Spawner (Dough Dumpster)?
4. **„Verloren“:** Entschädigungslose Schließung bestehender Restaurants? Dauerhaft verloren oder
   erholbar, wenn die Korruption wieder unter 100 % fällt?
5. **Abkürzung „FRT“:** Wofür steht sie? (Lore)
6. **Sabotage-Scope:** Greift die FRT den Spieler (passives Einkommen), die Rivalen oder beide an?
   Eigenständiger Kanal oder Erweiterung des V13-Moduls? **Empfehlung:** Erweiterung des V13-Moduls
   mit FRT-Fehl-Attribution (dritte Partei).
7. **„Abseits der Rangliste“ vs. „bevorzugtes Angriffsziel“:** Wie greifen Rivalen eine Fraktion an,
   die in keiner Rangliste steht?
8. **Interaktion:** Wie wirken Korruption und FRT-Sabotage auf Stance/Power Projection
   (`12_Power_Projection.md`) und die Wochenabrechnung?

## Betroffene Dateien (Vorschlag)

| Datei | Änderung |
|---|---|
| `lib/services/frt_service.dart` | **Neu:** Korruptions-Simulation, rein & deterministisch testbar (analog `RivalService`). |
| `lib/services/economy_balance.dart` | `frt*`-Parameter (V7: keine magischen Zahlen). |
| `lib/services/game_clock_service.dart` | Korruptions-Update im Wochen-Tick; Einkommens-Malus; `WeeklyTickResult.corruptionByDistrict`. |
| `lib/objects/object_host.dart` | Monster-Skalierung je Stadtteil-Korruption. |
| `lib/services/rival_service.dart` | Fehl-Attribution der FRT-Sabotage (V13-Erweiterung). |

## Tests (neu)

- `test/frt_service_test.dart` – Anstieg, Floor bei 0, Reduktion durch Monster/Siege, 100-%-Schwelle,
  Determinismus/Idempotenz im Catch-up.
- `test/game_clock_service_test.dart` (Erweiterung) – Einkommens-Malus und Verlustregel im Wochen-Tick.
- `test/rival_service_test.dart` (Erweiterung) – Fehl-Attribution und Entdeckung der FRT-Sabotage.
- `test/balance_sanity_test.dart` (Erweiterung) – alle `frt*`-Werte zentral in `EconomyBalance`.