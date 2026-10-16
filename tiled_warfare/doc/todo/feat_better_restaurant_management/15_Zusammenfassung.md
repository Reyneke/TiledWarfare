# Zusammenfassung

> **Status:** Abschlussdokument des Sprints `feat_better_restaurant_management` (Branch `feat-restaurant-management`). Es fasst die Kapitel `0-Base.md` bis `14_FRT.md` zusammen, hält den Umsetzungsstand fest und beantwortet die Leitfrage des Sprints: **Welche Fragen sind noch offen?**

> **Legende:** ✅ umgesetzt & validiert · ~ teilweise umgesetzt · 📝 Entwurf (spezifiziert, nicht umgesetzt)

---

## 1. Sprint-Ziel

Ausgangspunkt war in `0-Base.md` die Beobachtung, dass sich das Restaurantmanagement „**noch nicht richtig anfühlt**“: Es gab viele Einzelbausteine (Profile, Restaurants, Personal, Teamärzte, Budget, Rettungswürfe, XP), aber **keine schließende Wirtschaftsschleife**, dazu doppelte Zustände und halbfertige Features. Das Management wirkte wie eine Ansammlung einzelner Menüs statt wie ein zusammenhängendes System.

Der Sprint schließt diese Lücke: Das Restaurantmanagement läuft jetzt cross-plattform **wie ein Browsergame in Echtzeit**, bei dem das Gefecht nur ein Teil des Ganzen ist.

### Grundsatzentscheidungen (fixiert, `0-Base.md`)

1. **Mehrere Restaurants pro Profil als unabhängige Spielstände** (eigene Wirtschaft, Team, Ärzte, Historie) mit **Stadtteil/Standort** aus `theworld.tmx`.
2. **Echtzeit-Zeitsystem** im Stile alter Browsergames mit **Catch-up** nach App-Auszeit.
3. **Teamarzt-Bezahlung nur wöchentlich** (`costPerWeek`), kein Anschaffungspreis.

---

## 2. Kapitel-Übersicht

| Kapitel | Paket | Status | Kern |
|---|---|---|---|
| `0-Base.md` | Grundlage | ✅ | Ist-Analyse, Probleme P1–P7/P9, Verbesserungen V1–V9, Grundsatzentscheidungen |
| `1_mehrere_Restaurants.md` | V1 (→ P1) | ✅ | Restaurants als unabhängige Spielstände; Stadtteile; Migration; Spielstand-Umschalter |
| `2-Wirtschaftsschleife.md` | V2/V7/V8 | ✅ | Wirtschaftsschleife: Einnahmen, Wochen-/Tagestick, passives Einkommen (Fuzzy), Zinsen/Bankrott, Erweiterungen, Küchen |
| `3_Heilung_und_Zeit.md` | V3 (→ P3) | ✅ | Echtzeit-Heilung, `afraid` in der Kette, automatische Notfall-Spritze mit Rückfall |
| `4_Zustaende.md` | V4 (→ P4) | ✅ | Ein Bildzustand (`hasCustomImage`/`headerImagePath`), `_pickImage` atomar |
| `5_Halbfertige_Features.md` | V5 (→ P5) | ✅ | Fortbildung Line Cook aktiviert, Teamarzt-Fuzzy-Engine entfernt, toter Code entfernt |
| `6_Persistenz.md` | V6 (→ P6) | ✅ | Eine Datei je Spielstand + Verzeichnis-Scan, atomares Schreiben + `.bak`, sichtbare Fehler, Schema-Versionierung |
| `7_Wirtschaftswerte_zentralisieren.md` | V7 (→ P7) | ✅ | `EconomyBalance` als einzige Balance-Quelle (L1–L8 umgesetzt, L9 zurückgestellt); der **Werte-Pass (P7, 4.2/#10)** hat die Tuning-Größen durchgesehen (u. a. ist `negativeLimit` aus `startBudget` abgeleitet und per Vertrag gesichert) |
| `8_Echtzeit-Zeitsystem.md` | V8 (→ V2/V3) | ✅ | Anker `lastSeenAt`/`weekAnchorAt`, Tagesschritt, 60-s-UI-Tick, idempotenter Catch-up |
| `9_Personal.md` | V9 (→ P9) | ✅ | Attribute, Persönlichkeit (`PersonalityTraits`), Ressourcen, Stress/Ruhe, Host-Fuzzy verdrahtet; **Werte-Pass (P7):** `ruheMargin`, Sink-Werte, Trait-Prozente und Lohn-Spanne sind bestätigt und als Vertrag festgeschrieben |
| `10_Karrierepfade.md` | V10 | ✅ | Ränge bis Chef de partie, Stationen, Doppelrolle formell/aktiv, Hilfs-/Service-Rollen, Wochenlöhne, Personal-Transfer; **Werte-Pass (P7):** die Varianten-Familien wurden entzerrt (`Grillardin`/`Friturier` nicht mehr dominierend, `Potager`/`Légumier` unterscheidbar) und die Stations-/Aura-Regeln als Vertrag festgeschrieben |
| `11a_Hilfs_und_Servicerollen.md` | V11–V13 | ✅ | Support-Rollen + Verwaltungsrollen (Chefsekretärin, Rechtsanwalt, Buchhalter, Oberkellner, Personalchef, Lagerist, Gewerkschaftschef, Sicherheitschef) + Features (PR-Kampagne); die früher offene **Strafenquelle „Behörden/Inspektionen“ ist entschieden & umgesetzt (P3)** (`InspectionService`); **Detail-Entscheidungen E1/E2/E6 entschieden (P4, `11a` E18)**; die **Zuordnung Rolle ↔ Erweiterung** ist seit **P7** als Anker-Effekt-Vertrag in `balance_sanity_test.dart` gesichert |
| `11b_Restauranterweiterungen.md` | V2 § 10 / V1-Paket | ✅ | 14 Erweiterungen spezifiziert und **umgesetzt**: `cellar`, `coldRoom`, `firstAid`, `lounge`, `certification` (P3, inkl. Behörden-Inspektion als Strafenquelle) sowie **`vault`, `school`, `security`, `stars` (P3)**; die Zeitfenster der Gruppe C (`weeklyMenu`, `terrace`, `delivery`) sind **bewusst vertagt** (Designentscheidung, siehe § 4.3 + `11b` § „Entscheidungen“) |
| `12_Power_Projection.md` | – | ✅ | Power Projection (Fuzzy), Stadtteil-Ranking, PP-Einkommensfaktor umgesetzt & validiert |
| `13_Gegner_Restaurants.md` | – | ✅ | Rivalen-Roster + Sabotage-Minimal-Modul (V11/V13), Mini-PP, Rangliste, Stance, Gefechtsteilnahme **und** die **Voll-Simulation** des Wochen-Ticks (persönlichkeitsgetriebener Rivalen-Zustand, Roster-Dynamik mit Pleite/Nachrücken samt 1-Tick-Verzögerung, Ranking-Badge) umgesetzt; das Fein-Tuning (Rivalen-Anzahl, PP-Domäne/-Streuung, Ranglisten-Sortierung) ist im **P7-Werte-Pass ✅** bestätigt und festgeschrieben |
| `14_FRT.md` | – | ✅ | FRT-Triumvirat, Korruptionsmeter und Sabotagen-Modell; **Kern, Laufzeit-Verdrahtung und der C2-Feinschliff umgesetzt**: `FrtService`, `frt*`-Werte, `RestaurantData`-Felder (Schema 10 → **11**: Fehde), Wochen-Tick-Integration (Anstieg, Einkommens-Malus, entschädigungsloses Schließen), Monster-Skalierung in `object_host.dart`, Fehl-Attribution **und Fehde** (`applyFrtFeud`/`escalateStance`) in `rival_service.dart`, ranglose Angriffe auf Rivalen (Q7b), Befreiung mit UI-Hinweis; Werte-Tuning (Q2) im **P7-Werte-Pass ✅** bestätigt |

---

## 3. Kernpunkte der Umsetzung

- **Wirtschaft (V2/V7/V8):** laufender Geldkreislauf aus Gefechtserlösen, passivem Einkommen und wöchentlichen Kosten; Negativzinsen und Bankrott-Flow verdrahtet; Wochen-Catch-up mit `WeekSettlement`.
- **Zeit (V8):** Echtzeit-Anker je Spielstand (`lastSeenAt`/`weekAnchorAt`); Tagesschritt mit anteiligen Resttagen (Σ Blocktag = Wochenertrag); periodischer UI-Tick (60 s) und ankerstabile, idempotente Wiederholung.
- **Heilung (V3):** `status` als einzige Quelle der Wahrheit (LP abgeleitet); Kette `dying → injured → hurt → afraid → reeling → ready`; Notfall-Spritze automatisch, Rückfall nach 24 h.
- **Datenmodell (V1):** `RestaurantData` als Zustandsträger; Migration mit ID-/`lastSeenAt`-/Stadtteil-Fallback; Speichern per Merge (`toProfileData()`), Restaurant-Umschalter in der UI.
- **Persistenz (V6):** Laden über Verzeichnis-Scan, atomares Schreiben mit `.bak`, tolerante Deserialisierung, sichtbare Fehler und `kProfileSchemaVersion` (Stand: **v10** – Kap. 14 FRT/Korruption).
- **Personal (V9/V10):** Attribute und Persönlichkeit (`PersonalityTraits`, Ressourcen, Stress/Ruhe) wirken auf Management und Gefecht; Karriereränge, Stationen, Doppelrolle formell/aktiv, Hilfs-/Service- und Verwaltungsrollen, Wochenlöhne, Personal-Transfer.
- **Erweiterungen (V2 § 10 / 11b):** `cellar`, `coldRoom`, `firstAid`, `lounge` wirken auf Attraktivität, Zufriedenheit, Kapazität, Heilzeit und Ressourcen; `certification` (P3) mindert über die **Behörden-Inspektion** (`InspectionService`) erlittene Strafen; Schnittstellen zu Rollen (Sommelier, Lagerist, Plongeur, Aboyeur, Rechtsanwalt).
- **Rivalen-Minimal-Modul (V11/V13):** deterministischer Roster je Stadtteil, Spieler-Sabotage (Chefsekretärin), eingehende Rivalen-Sabotage mit Entdeckung, Gegenschlag (Sicherheitschef) und Einkommens-Abschöpfung.
- **Power Projection & Rivalen-Rangliste (Kap. 12/13):** PP (0–100) als deterministische Fuzzy-Inferenz aus Konkurrenzdichte, Bilanz und Teamqualität; Stadtteil-Rangliste inkl. simulierter Rivalen-PPs (Rubber-Band, Stance, Pleite-Kennzeichnung); deterministische Gefechtsteilnahme-Verteilung; der Einkommensfaktor (PP × Konkurrenzdruck) skaliert das passive Wocheneinkommen und wird im `WeeklyTickResult` ausgewiesen.
- **FRT/Korruption (Kap. 14, Kern + Laufzeit):** `FrtService` als reine, deterministische Korruptions-Simulation (Anstieg je Wochen-Block/Sabotage/Eliminierung, Senkung je Monster/Sieg, Formeln für Monsterstärke-, Einkommens- und PP-Malus, 0–100-Klemmung); Korruption liegt als `RestaurantData.corruptionPercent` (neben `districtLost`/`districtLostAt`, Schema 9 → 10) und wird im Wochen-Tick **monoton** fortgeschrieben; der Einkommens-Malus greift auf volle Wochen **und** Resttage, Korruption ≥ Verlustschwelle schließt das Restaurant entschädigungslos (vorhandene Aufgelöst-Mechanik). **Laufzeit verdrahtet:** Monster (inkl. Spawner) skalieren zum Gefechtsstart aus der Korruption (`object_host.dart`), gewonnene Gefechte **senken** die Korruption (`ScreenBattleResult` → `ObjectProfile.reduceCorruption`), **unentdeckte FRT-Fehl-Attributionen** treiben sie (`rival_service.dart`), die Gründung in einem verlorenen Stadtteil wird gesperrt (distinkte Meldung) und die Korruption im Restaurant-Kopf angezeigt. Der reale Persistenzpfad (`ObjectProfile`-Snapshots/Catch-up/Save-Merge) trägt den Zustand. **Offen (C2):** persistente „Fehde“/Stance-Verschiebung bei entdeckter FRT, Befreiungs-Gefechte in verlorenen Stadtteilen.

**Validierung:** `flutter analyze` ohne Fehler/Warnungen (Baseline: 14 `info`-Lints in Alt-Code); `flutter test` grün – aktueller Stand: **641 Tests** (u. a. `inspection_service_test.dart`, `frt_service_test.dart`, `frt_runtime_test.dart`, `object_host_test.dart`, `object_patissier_test.dart`, `team_dynamics_test.dart`, `career_restart_test.dart`, `profile_storage_appdata_test.dart` und `screen_character_detail_career_restart_test.dart` sowie die `balance_sanity_test.dart`-Gruppen).

---

## 4. Offene Fragen

> Dieser Abschnitt beantwortet die Leitfrage des Sprints. Er fasst die „Offenen Fragen / Offenen Punkte / Offenen Folgepunkte“ der Einzelkapitel zusammen, entdoppelt sie und verweist auf die Quelle.

### 4.1 Design-Entscheidungen (Entwürfe 12–14)

| # | Frage | Quelle | Entscheidung / Vorschlag |
|---|---|---|---|
| 1 | **PP-Eingangswerte:** Welche Werte (Erweiterungslevel, Rebranding-Frische, Kundenzufriedenheit, Social-Media-Manager) kommen in die Kern-Fuzzy, welche nur in den Einkommensfaktor? | `12_Power_Projection.md` → Offene Fragen 5 | **Entschieden/umgesetzt:** Die Kern-Fuzzy nutzt **Konkurrenzdichte, Bilanz und Teamqualität** (voller Team-Input inkl. Personal-/Erweiterungswirkung). Erweiterungslevel/Rebranding/Kundenzufriedenheit bleiben **bewusst außen vor** – sie beeinflussen die Kunden-Fuzzy und damit das passive Einkommen bereits direkt (kein Doppelzählen); die PP wirkt nur als Faktor auf dieses Einkommen. |
| 2 | **Faktorform:** linearer Faktor vs. zweite Mini-Fuzzy-Stufe (PP → Faktor) – einheitlich für PP und Rivalen-Konkurrenzdruck entscheiden. | `12` → 6, `13` → 6 | Fuzzy-Stufe |
| 3 | **Persistenz PP/Rank:** je Catch-up neu berechnen oder als Feld (`powerProjection`, `rank`) in `RestaurantData` sichern (inkl. Migration)? | `12` → 4 | Beim Catch-up neu berechnen. |
| 4 | **Platzierung in der UI:** Wo wird „Platz X von Y“ angezeigt (Restaurant-/Start-Screen, Wochenbericht)? | `12` → 7 | Die Platzierung, inklusive aller Gegner, sollte im Wochenbericht als Liste auftauchen. Im Restaurant-/Start-Screen hingegen das „Platz X von Y“. |
| 5 | **Update-Reihenfolge im Catch-up:** Ranking-Update vor oder nach der Einkommensbuchung (Vorschlag: Bilanz/Teamqualität → PP → Ranking → Einkommen mit neuem Faktor)? | `12` → 8 | Vorschlag passt. |
| 6 | **Rivalen-Skalierung/Balancing:** präzises Mapping Prestige-Tier → Rivalenanzahl (`rivalCountFromPrestige`) und Caps (`rivalCountMin`/`rivalCountMax`); S–D-Schwellen 2.00/1.60/1.30/1.00 vorläufig. **Umgesetzt:** `RivalService.countFor` + Caps; zusätzlich steuert die Wochen-Simulation die dynamische Ziel-Anzahl (`roamTargetCount`, Gegenwind an der Spitze/Schrumpfen am Ende). Verbleibend: reines Zahlen-Tuning. | `12` → 1, `13` → 1 | Umgesetzt (Tuning offen) |
| 7 | **Rivalen-Voll-Simulation:** Rivalen-PP/Mini-Modell, Rangliste, Rivalen-Aktionen im Wochen-Tick und Ranking-Badge im `ScreenRestaurant`. **Umgesetzt:** `RivalService.simulateField` (persönlichkeitsgetriebener Zustand), `candidatePool`/`activeRosterOf` (Pleite/Nachrücken mit 1-Tick-Verzögerung, `isRosterActive`), `simulatedRivalPp`/`weekIndexOf`; `standings` nutzt die Simulation im Wochen-Tick. | `13` → „Noch offen“ | Umgesetzt |
| 8 | **Gefechtsteilnahme der Rivalen:** Truppenstärke je Gefecht und Verhalten bei zu wenigen `spawn_player*`-Punkten (deterministische Reduktion → Verteilung auf vorhandene Punkte). | `13` → 2 | Verteilung |
| 9 | **Stance-Schwellen:** ab welchem Rangabstand/PP-Verhältnis ist ein Rivale Verbündeter/Neutral/Feind (inkl. Anzahl der Rivalen je Stance)? | `13` → 3 | Das ist davon abhängig, wie viele Gegner im Gefecht sind. Vorschlag: bis 20 % Unterschied ist die Chance „hoch“, dass sie Freunde sind, ab 80 % ist die Chance „hoch“, dass sie Feinde sind, bei 50 % ist die Chance „hoch“, dass sie neutral zueinander sind. |
| 10 | **Gegenwirkungs-Formel:** exakte Formel für den Konkurrenzdruck- bzw. `powerProjectionIncomeFactor`. **Entschieden/umgesetzt:** zweite Mini-Fuzzy-Stufe (`PowerProjectionService.competitionPressureFactor`, Span 0.85–1.15) über dem relativen PP-Abstand zum Feld-Ø; `faktorEffektiv = PP-Faktor × Konkurrenzdruck` (`effectiveIncomeFactor`), gespeist aus dem **aktiven** Rivalen-Ø der Wochen-Simulation. | `13` → 5 | Umgesetzt (Fuzzy) |
| 11 | **Folgen unentdeckter Sabotage:** V13 bucht die Einkommens-Abschöpfung (10 % je unentdecktem Angreifer, Deckel 30 %); offen bleiben Kunden-/Ansehensverlust, Erweiterungsschäden („Reparatur“), höhere laufende Kosten oder Strafzahlungen – hier greift später die „Schwere der Tat“. | `13` → 7 | Vorschlag, abgesehen davon, dass eine unentdeckte Sabotage erfolgreich war und damit volle Wirkung zeigt. |
| 12 | **FRT-Werte-Tuning (Q2):** konkrete Beträge für `frtCorruptionPerWeekPercent` (Vorschlag 1), `frtCorruptionReducePer*`, `frtMonsterStrengthScalePercent`, `frtCorruptionIncomePenaltyMaxPercent`, `frtPowerProjectionPenaltyPercent` sowie Sabotage-/Eliminierungs-Anstiege. | `14_FRT.md` → Offene Fragen 1 | Vorschlag? |
| 13 | **FRT – Erholung verlorener Stadtteile (Q4b):** „Befreiungs-Gefechte“ zulassen oder natürlichen Verfall einführen (ohne eigenes Restaurant fehlt eine Senkungsquelle)? | `14` → 2 | Befreiungsgefechte sind erlaubt. **Umgesetzt (C2):** `ObjectProfile.reduceCorruption` meldet die Befreiung, `ScreenBattleResult` zeigt `districtLiberatedMessage`, die Q4-Hysterese hebt `districtLost` unter der Schwelle auf. |
| 14 | **FRT – Monster-Skalierung (Q3b):** Skalieren auch Bewegungs-/LP-Werte oder nur Angriff/Verteidigung/Schaden; Rundung je Stat deterministisch festhalten? | `14` → 3 | Alle Werte skalieren. |
| 15 | **FRT – Power-Projection-Formel (Q8):** exakte Formel und Ort des Korruptions-Abzugs am PP-Einkommensfaktor. | `14` → 4 | Vorschlag? Eventuell Fuzzy-Logik? |
| 16 | **FRT – Fehl-Attribution (Q6b):** deterministische Wahl der „behaupteten“ Rivalen-ID, Entdeckungswahrscheinlichkeit und ob FRT-Sabotage zusätzlich die V13-Abschöpfung auslöst. | `14` → 5 | Der Rivale, welcher in direkter Konkurrenz zum betroffenen Ziel steht, sowohl nach oben als auch nach unten. **Umgesetzt (C2):** `attributedRivalId` (Roster-Index per CRC32), Entdeckungswahrscheinlichkeit jetzt über die **Sicherheitstechnik** (`security`, P3) mitgehoben; eine unentdeckte FRT-Sabotage zählt weiterhin wie jede unentdeckte Rivalen-Sabotage (Abschöpfung **und** Korruption). |
| 17 | **FRT – Stance/Angriffsziel (Q7b):** wie Rivalen eine ranglose Fraktion angreifen (Gefecht/Gegensabotage) und welche Schwellen/Parameter dazu in `EconomyBalance` kommen. | `14` → 6 | Die FRT bzw. ihre Truppen gelten für alle als Feind. **Umgesetzt (C2):** die FRT greift Rivalen **offen** an (`frtAttacksRival`/`frtRivalAttackPpLoss`, `frtRivalAttackSharePercent`/`frtRivalAttackPpLoss`), deren PP sinkt sichtbar in der Rangliste; eine aufgedeckte Fehl-Attribution erzeugt die persistente **Fehde** (`frtFeudUntilWeekById`, `frtFeudWeeks`). |
| 18 | **Strafenquelle „Behörden/Inspektionen“ (P3):** Welche Quelle erzeugt passive Strafen, damit die Erweiterung `certification` (Rechtsanwalt) wirkt – Behörden-Inspektion, Rufschädigung oder beides? | `11a` → Offene Punkte (Rechtsanwalt), `11b` Gruppe D | **Entschieden/umgesetzt:** deterministische **Behörden-Inspektion** (`InspectionService`, CRC32 aus Restaurant-ID + Blockanker, alle `inspectionIntervalWeeks` Blöcke, Grundstrafe + Korruptions-Zuschlag nach Kap. 14); gebucht als `penaltyCosts` im Wochen-Tick, gemindert **additiv** (Rechtsanwalt + Winkelzug + Zertifizierung, 100 %-Deckel). Rufschädigung bleibt offen. |

> **Umsetzungsstand (Kap. 12–14):** Die Zeilen 1–10 (PP-Eingänge, PP/Rang der Rivalen, Gegenwirkungs-Formel, Rivalen-Skalierung und **Voll-Simulation**) sind in `12`/`13` umgesetzt – Zeile 7 über `RivalService.simulateField`/`activeRosterOf` (persönlichkeitsgetriebener Zustand, Pleite/Nachrücken mit 1-Tick-Verzögerung) und die im Wochen-Tick genutzte `standings`. Zeilen 13/14 (Erholung, Monster-Skalierung „alle Werte“) sind **verdrahtet** – `FrtService.monsterStrengthFactor`/`scaleStat` speisen `ObjectHost.monsterStrengthFactor` (Zombies **und** Spawner). Zeile 12 (FRT-Werte-Tuning Q2) und Zeile 15 (PP-Formel Q8) sind entschieden und in `EconomyBalance` bzw. `GameClockService.catchUp` verankert; Zeile 16/17 (FRT-Fehl-Attribution/Angriffsziel) ist als deterministische Fehl-Attribution in `rival_service.dart` verdrahtet; **Zeile 18** ist als passive **Behörden-Inspektion** (`InspectionService`, P3) samt `penaltyCosts`-Buchung im Wochen-Tick umgesetzt. **Offen bleiben:** reines Zahlen-Tuning (Zeile 6) sowie der C2-Feinschliff von Q6b/Q7b. **Nachgezogen (C2, P2):** Die Zeilen 13, 16 und 17 sind umgesetzt – persistente **Fehde** (`frtFeudUntilWeekById`, Schema **11**) mit Stance-Verschiebung in Rangliste/Gefecht, **ranglose FRT-Angriffe auf Rivalen** (Q7b, PP-Schwund mit Pleite-Boden) und die **Befreiung** verlorener Stadtteile samt UI-Hinweis; damit bleibt in diesem Kapitel nur noch das Werte-Tuning (Zeile 12/Q2) – das im **P7-Werte-Pass ✅** abgeschlossen wurde (FRT-Maluskurve/Korruptionswerte unverändert bestätigt, alle `frt*`-Verträge grün).

### 4.2 Offene Implementierungs- und Folgepunkte (Kapitel 1–11)

| # | Punkt | Quelle |
|---|---|---|
| 1 | **Regelwerk-Update – erledigt:** `team_rules.md` beschreibt „mehrere Restaurants als unabhängige Spielstände + Standort“ (§ 1.1) und die Echtzeit-Abrechnung inkl. Wochen-Cap (§ 2.2). | `1` → Phase 4, `0-Base.md` → Offene Folgepunkte |
| 2 | **Anteilige Arzt-Abrechnung – gelöst:** Regel „kein anteiliger Einzug, erste Abbuchung erst zum nächsten Wochentick“ ist dokumentiert (team_rules.md § 2.1, 0-Base V8) und in `billWeeklyMedicCosts` (volle Blockwochen) umgesetzt. | `0-Base.md` → Entscheidung getroffen |
| 3 | **Aufgelöste Restaurants – erledigt:** Regel dokumentiert in `team_rules.md` § 6.2 und § 1.1 (bleibt sichtbar, blockiert Stadtteil, löschbar, übrige Restaurants unberührt; zusätzlich Korruptions-Auflösung `14_FRT.md`). | `0-Base.md` → Offene Folgepunkte, `1` |
| 4 | **`path_provider`/AppData-Pfad:** **Erledigt (P6, 4.2/#4):** `ProfileStorage` löst das Basisverzeichnis einmalig über `getApplicationSupportDirectory()` auf (Unterordner `tiled_warfare_profiles`, Fallback relativ `profiles/`); Altbestände werden beim ersten Start **kopiert** (nie verschoben, nur solange am Ziel noch nichts liegt), Bildpfade werden absolut geschrieben und Legacy-Relativpfade beim Lesen über `ProfileStorage.absolutePath` aufgelöst (`profile_storage_appdata_test.dart`). | `6` → Bewusst nicht umgesetzt (jetzt P6) |
| 5 | **Zeitsystem-Feinschliff:** L4.1–L4.5 umgesetzt (`hoursElapsed`, `_severityByStatus`, Doppel-Helfer, `shotRolledBackCount`); UTC als Zeitbasis aktiv. **`maxCatchUpWeeks`-Cap (L6) umgesetzt** (`EconomyBalance.maxCatchUpWeeks` = 52, Überspringen ganzer Wochen ohne Buchung; Test `catch_up_cap_test.dart`). **Erledigt (P6, 4.2/#5):** L2-Detaildialog — der Wochenbericht (`_showWeekReport`) schlüsselt jeden Block auf (neues `WeekSettlement.rivalSabotageLoss`, aufklappbare `ExpansionTile` je Woche); P3-Journal — `last_tick.json` als Write-ahead vor jedem Catch-up (`ProfileStorage.writeTickJournal`/`clearTickJournal`/`readTickJournal`, verwaiste Journale werden beim Laden gemeldet und aufgeräumt). | `8` → Offen (jetzt P6) |
| 6 | **Personal:** Teamdynamik (Affinitäten/Konflikte zwischen Persönlichkeiten); eigene Klassen-Profile für Sous-chef/Pâtissier. **Erledigt (P5):** `TeamDynamicsService` (deterministische Paar-Affinität aus Persönlichkeits- **und** Charakter-IDs, RNG-frei) wirkt additiv auf `attractivenessOf`/`satisfactionOf`; Sous-chef-Profil (`ObjectSousChef`, V10) und neues Support-Profil `ObjectPatissier` (Rang `chef_de_partie`, Station `kStationPatissier`, eigene `patissierStats`, kein Schema-Feld). | `9` → Offene Punkte |
| 7 | **Karrierepfade-Abweichungen:** Nachrücken des aktiven Chefs (`nachrueckenHeadChef`) und Tournant-Erleichterung (`tournantExhaustionReliefPercent`, 25 %) umgesetzt; **„Neustart des Charakters bei Level 0“ erledigt (P5):** `ObjectProfile.restartCareer` (level-abhängige Kosten, Zustands-Reset, Identitätserhalt, Nachrücken) + Bestätigungsdialog in `ScreenCharacterDetail`. | `10` → Bewusste Abweichungen |
| 8 | **Hilfs-/Service-Rollen:** **Mehrfach-Anstellung derselben Rolle unterbunden** (`hireSupportRole`/`hireManagementRole` idempotent + UI-Sperre „Bereits angestellt“, `11a` E11; Test `role_single_employment_test.dart`). Offen: Lohn-Thriftiness, falls Rollen später Persönlichkeit erhalten; Bestätigungsdialog beim Entlassen; Taxonomie-Detailentscheidungen E1/E2/E6 (Teamarzt-Einordnung, Kategorie-Name/-Zuschnitt, Zuordnung der Erweiterungsvorschläge); Feature-Feinschliff (UI-Countdown, `WeekSettlement`-Zeile für Einmalkosten, Bestätigung vor Aktivierung). | `11a` → Offene Punkte |
| 9 | **Erweiterungen:** **Erledigt (P3):** `certification` (mit der **Strafenquelle Behörden/Inspektionen**, `InspectionService`) sowie `vault` (Negativzins-Satz −10 %/Stufe), `school` (−5 % Fortbildungskosten/Stufe), `security` (+5 Prozentpunkte Entdeckung/Stufe) und `stars` (Prestige-Beitrag zur PP **und** selteneres Sabotage-Ziel) – alle als ⚙-Hooks über `upgradeEffects`-Summen, mit Kacheln, l10n und `balance_sanity_test`-Verträgen. **Bewusst vertagt (Designentscheidung, § 4.3 + `11b` § „Entscheidungen“):** die Gruppe-C-Zeitfenster (`weeklyMenu`, `terrace`, `delivery`) – sie brauchen zuerst eine Mechanik-Entscheidung, kein Tuning. | `11a`/`11b` → Erweiterungsvorschläge |
| 10 | **Balance-Tuning:** zahlreiche Werte (Stations-/Aura-/Buff-Werte, Lohn-Spanne, `ruheMargin`, Sink-Werte, Trait-Prozente, Rolle-Erweiterungs-Zuordnung) sind Tuning-Größen, werden in `EconomyBalance` justiert und über `balance_sanity_test.dart` abgesichert. **✅ erledigt (P7):** Werte-Pass mit 10 neuen Verträgen in der Gruppe „Balance-Tuning: Werte-Pass (P7, 4.2/#10)“; die beiden Varianten-Familien wurden dabei korrigiert (siehe P7). | `10`, `11a`, `11b` |

### 4.3 Bewusst zurückgestellt (nicht blockierend)

- **Layering (L9):** keine Aufteilung von `economy_balance.dart` bzw. `GameClockService` – bei weiterem Wachstum erneut prüfen (`7`, `8` L7).
- **`dispose`-Save:** zugunsten des Lifecycle-Saves bei `paused`/`hidden` (`6`).
- **Teamarzt-Fuzzy-Engine:** in V5 entfernt; die Persönlichkeits-Idee wurde in anderer Form im ausgebauten Personalsektor wieder aufgegriffen (V9) (`5`).
- **Kapitel `2`, `3` und `4`** haben keine offenen Fragen mehr; Kapitel `1` ist bis auf den Folgepunkt 4.2/1 abgeschlossen.
- **Gruppe-C-Zeitfenster (`weeklyMenu`, `terrace`, `delivery`, `11b`) – Designentscheidung: bewusst nicht gebaut.** Die Wirkungs-Idee ist bestätigt, jeder Baustein verlangt aber zuerst eine **Mechanik-Entscheidung**: `weeklyMenu` als aktivierbarer Tageszustand mit Ablaufdatum (eine aktive Karte) vs. **eigene Buchung**; `terrace` als tages-/prestigeabhängiger Kapazitäts-Modifikator, der nur mit Personal wirkt; `delivery` als **zweite Einkommensschiene** mit eigener Buchungszeile/Obergrenze im `catchUp` (bricht bewusst die „alles über Fuzzy-Eingänge“-Regel aus `7`). **Kein wirtschaftlicher Notstand:** die Zufriedenheits-/Kapazitätslücke ist durch `cellar`/`coldRoom`/`tables` gedeckt. Wiederaufnahme-Reihenfolge (`weeklyMenu` → `terrace` → `delivery`) und Einhängepunkt (bestehendes Q1-Fenster aus `8`, **kein** Scheduler) sind in `11b` § „Entscheidungen (getroffen)“ festgehalten.

---

## 5. Nächste Schritte (Empfehlung)

1. **Kapitel-12/13-Stand committen: ✅ erledigt** (Commit `4f2c300`). Die Umsetzung (PP, Rangliste, Stance, Gefechtsteilnahme) liegt in `power_projection_service.dart` sowie den Erweiterungen in `economy_balance.dart`, `game_clock_service.dart` und `rival_service.dart` (inkl. Tests). **P2-Verifikation nachgezogen:** `PowerProjectionService.effectiveIncomeFactor` (Produkt PP-Faktor × Konkurrenzdruck) und die Catch-up-Verdrahtung sind in `balance_sanity_test.dart` bzw. `power_projection_ranking_test.dart` abgesichert; die unbenutzte `competitionFromPp`-Variante wurde entfernt.
2. **Kapitel 13 vollenden (FRT verdrahtet):** Die **Laufzeit-Verdrahtung** der FRT ist erledigt (Monster-Skalierung in `object_host.dart` aus `FrtService.monsterStrengthFactor`, Gefechts-Senkung über `ObjectProfile.reduceCorruption`, Fehl-Attribution in `rival_service.dart`, Gründungssperre/Anzeige in den Screens; Q2/Q8 in `EconomyBalance` bzw. `catchUp` verankert). **Erledigt:** die Rivalen-**Voll-Simulation** (persönlichkeitsgetriebener Zustand + Roster-Dynamik mit Pleite/Nachrücken und 1-Tick-Verzögerung in `RivalService.simulateField`/`activeRosterOf`, im Wochen-Tick über `standings` genutzt; Ranking-Badge im `ScreenRestaurant`). **Erledigt (P2/C2):** der C2-Feinschliff – persistente Fehde (`frtFeudUntilWeekById`, Schema 11) samt Stance-Verschiebung, ranglose FRT-Angriffe auf Rivalen (Q7b) und Befreiungs-Hinweis. **Erledigt (P7):** reines Zahlen-Tuning – Fehde-Dauer (4 Wochen), Angriffsanteil (25 %) und PP-Verlust (4/Woche) sind unverändert bestätigt und als Vertrag festgeschrieben.
3. **Kleine Folgepunkte schließen:** `team_rules.md`-Update (4.2/1), Zeitsystem-Feinschliff (4.2/5) sowie die Erweiterung `vault` (4.2/9). **Erledigt (P3):** `certification` samt **Strafenquelle** (deterministische Behörden-Inspektion, `penaltyCosts` im Wochen-Tick, additive Strafminderung) – siehe 4.1/18 und `11b`; ebenso **`vault`, `school`, `security` und `stars`** mit entschiedenen Wirkungen. **Erledigt (P6):** Zeitsystem-/Pfad-Feinschliff 4.2/#5 (Wochen-Detaildialog + `last_tick.json`-Journal) und 4.2/#4 (`path_provider`/AppData samt Migration).
4. **Absicherung:** jede Änderung über `EconomyBalance` + `balance_sanity_test.dart` und die bestehenden Service-/Widget-Tests abdecken; `flutter analyze` und `flutter test` müssen grün bleiben. **✅ (P7):** Der Werte-Pass hat genau das getan – 10 neue Verträge in `balance_sanity_test.dart` (Bereiche, Monotonie, Dominanz-Freiheit, „Σ Blocktag = Wochenwert“), `flutter analyze` ohne neue Warnungen.
5. **4.2/#8 + `11a` – Rollen-Feinschliff: ✅ umgesetzt (P4)** – Bestätigungsdialog beim Entlassen (Ärzte/Rollen/Charaktere), Taxonomie **E1/E2/E6** entschieden (`11a` E18), Feature-Feinschliff (UI-Countdown, `prepaidFeatureCosts`-Zeile im `WeekSettlement`, Bestätigung vor Aktivierung), Lohn-Thriftiness **verworfen** (`11a` E19). Das verbliebene **Zahlen-Tuning** (`4.2/#10`) ist **✅ (P7)** erledigt – inklusive der Zuordnung Rolle ↔ Erweiterung, die jetzt als Anker-Effekt-Vertrag in `balance_sanity_test.dart` steht.
6. **4.2/#7 + #6 – Karrierepfade & Personal: ✅ umgesetzt (P5)** – Karriere-Neustart auf Level 0 (`ObjectProfile.restartCareer` + Dialog), Teamdynamik (`TeamDynamicsService` auf Attraktivität/Zufriedenheit) und das Support-Profil `ObjectPatissier`. **4.2/#5 + #4 – Zeitsystem- & Pfad-Feinschliff: ✅ umgesetzt (P6)** – Wochen-Detaildialog, `last_tick.json`-Journal, `path_provider`/AppData samt Migration. Nächste offene Pakete: **keine** – P1 (Rivalen-Voll-Simulation), P3 (`vault`/`school`/`security`/`stars`) und **P7** (Balance-Tuning) sind umgesetzt; **bewusst vertagt** ist allein die Gruppe-C-Zeitfenster-Idee aus `11b` (Designentscheidung dokumentiert: `11b` § „Entscheidungen (getroffen)“ + § 4.3).

---

## 6. Verweise

- **Basis & Entscheidungen:** `0-Base.md`
- **Umsetzungskapitel:** `1_mehrere_Restaurants.md` … `11b_Restauranterweiterungen.md`
- **Entwürfe:** `12_Power_Projection.md`, `13_Gegner_Restaurants.md`, `14_FRT.md`
- **Regelwerk:** `doc/rules/team_rules.md`
- **Balance:** `lib/services/economy_balance.dart`, `test/balance_sanity_test.dart`


----

Ich habe jetzt alle relevanten Dokumente und den Code-Stand analysiert. Hier ist die Aufschlüsselung aller offenen Punkte plus der Umsetzungsplan.

---

# A. Aufschlüsselung aller offenen Punkte (Ist-Stand → Rest)

**Wichtige Vorbemerkung:** Beim Code-Abgleich zeigt sich, dass einige in der Zusammenfassung als „offen" gelistete Punkte **funktional bereits umgesetzt** sind – dort bleibt nur noch Entscheidung/Tuning/Doku übrig:

| Offener Punkt | Ist-Stand im Code | Rest-Arbeit |
|---|---|---|
| 4.1/#6 Rivalen-Skalierung (`rivalCountFromPrestige`) | ✅ **umgesetzt** – `RivalService.countFor()` + `EconomyBalance` (S↔8/A↔6/B↔5/C↔4/D↔3, Caps 3–8) | Werte final bestätigen/balancieren + `balance_sanity_test`-Abdeckung – **✅ (P7):** Rivalen-Anzahl ist als geordneter, gedeckelter Vertrag festgeschrieben |
| 4.1/#10 Gegenwirkungs-Formel | ✅ **umgesetzt** – `PowerProjectionService.competitionPressureFactor` + `effectiveIncomeFactor` (Mini-Fuzzy, 0.85–1.15) | Formel fixieren & dokumentieren; Tuning – **✅ (P2/P7):** Spannen/Monotonie sind in `balance_sanity_test` verankert |
| 4.1/#7 Teil „Ranking-Badge" | ✅ **umgesetzt** – `screen_restaurant.dart:1423` (`rankingBadge`), Wochenbericht zeigt Rangliste (Z. 206–271) | nur Voll-Simulation bleibt (s. u.) |
| 4.1/#12–17 FRT (Kern + Laufzeit) | ✅ **umgesetzt** | nur C2-Feinschliff (s. u.) |

**Wirklich offene Punkte (nach Code-Abgleich):**

1. **4.1/#7 – Rivalen-Voll-Simulation** (Kap. 13 → „Handlungen (Konzept)"): Rivalen-Aktionen im **Wochen-Tick** über das bisherige Minimal-Modul hinaus – deterministische Mini-Ökonomie (Anheuern/Investieren/Aufwerten), Pleite + **Nachrücken mit 1-Tick-Verzögerung**, Eintritt/Austritt bei Prestige-/Rangwechsel.
2. **4.1/C2 – FRT-Feinschliff (Q6b/Q7b)**: persistente **Fehde/Stance-Verschiebung** bei *entdeckter* Fehl-Attribution; **ranglose Angriffs-Simulation** (FRT gilt für alle als Feind → auch Rivalen sind Ziele); **Befreiungs-Gefechte** in verlorenen Stadtteilen (Erholung unter Schwelle ist im Kern da, der „befreite" Stadtteil muss kämpfbar/neugründbar gemacht werden).
3. **4.1/#1 – PP-Eingangswerte**: Entscheidung über Erweiterungslevel, Rebranding-Frische, Kundenzufriedenheit, SMM in Kern-Fuzzy vs. nur Faktor (Analyse + Entscheidung).
4. **4.2/#9 + `11b` – Erweiterungen**: `vault` (→ Caissier), `school` (Wirkung entscheiden: −5 % Fortbildungskosten **oder** +2 % Sieg-XP), `security` (Wirkung entscheiden: +5 % Entdeckung **oder** −5 % Abschöpfung), `certification` (**gekoppelt** an fehlende Strafenquelle Behörden/Inspektionen), `stars` (jetzt machbar, da 12/13 stehen).
5. **4.2/#8 + `11a` – Rollen-Feinschliff**: ✅ **umgesetzt (P4)** – Bestätigungsdialog beim Entlassen (Ärzte/Rollen/Charaktere), Taxonomie **E1/E2/E6** entschieden (`11a` E18), Feature-Feinschliff (UI-Countdown außerhalb der Personal-Karte, `prepaidFeatureCosts`-Zeile im `WeekSettlement`, Bestätigung vor Aktivierung) und Lohn-Thriftiness **verworfen** (`11a` E19). Offen bleibt nur allgemeines **Zahlen-Tuning** (`4.2/#10`).
6. **4.2/#7 + `10` – Karrierepfade**: „Neustart des Charakters bei **Level 0**" (einzige Rückholmöglichkeit eines aktiven Chefs).
7. **4.2/#6 + `9` – Personal**: **Teamdynamik** (Affinitäten/Konflikte zwischen Persönlichkeiten → Attraktivität/Zufriedenheit); **Klassen-Profile Sous-chef/Pâtissier** (Leitlinie: erben von `ObjectApprentice`, kein Parallelmodell).
8. **4.2/#5 + `8` – Zeitsystem-Feinschliff**: **L2-Detaildialog** (Wochen-Aufschlüsselung je `settlement`); **P3-Journal `last_tick.json`** (Write-ahead gegen die Save-Lücke).
9. **4.2/#4 + `6` – Pfad-Ablösung**: `path_provider`/AppData statt relativem `profiles/`-Pfad (mit Migration).
10. **4.2/#3 + `1` – Doku**: Aufgelöste-Restaurants-Verhalten (blockiert Stadtteil, löschbar) dokumentarisch nachziehen.
11. **4.2/#10 – Balance-Tuning**: laufende Tuning-Größen in `EconomyBalance` (Stations-/Aura-/Buff-Werte, Löhne, `ruheMargin`, Sinks, Trait-Prozente, Rolle↔Erweiterung). **✅ erledigt (P7):** Werte durchgesehen, Stations-Varianten entzerrt und als Verträge in `balance_sanity_test.dart` festgeschrieben.
12. **Doku-Schuld**: `15_Zusammenfassung.md` § 5 Nr. 1 veraltet (Committen ist bereits erledigt), 4.2/#1 als „erledigt" einordnen.
13. **4.3** (bewusst zurückgestellt): L9-Layering, `dispose`-Save, Teamarzt-Fuzzy – **nur** als Entscheidung im Abschlussdokument festhalten, nicht umsetzen.

---

# B. Umsetzungsplan (Pakete in Empfehlungsreihenfolge)

## P0 – Baseline & Mini-Doku-Fixes (klein)
- **Ziel:** Sauberer Ausgangspunkt; veraltete Aussagen korrigieren.
- Schritte: (1) Doku-Update `15_Zusammenfassung.md` § 5/4.2 (#1 erledigt markieren, „Commit" entfernen); (2) Doku zu **Aufgelöste Restaurants** (4.2/#3) in `team_rules.md`/`1_mehrere_Restaurants.md` nachziehen; (3) 4.1/#1-Entscheidung „PP-Eingangswerte" als Analyse-Notiz (Empfehlung: vorerst **nur** in den Faktor – SMM/Kundenzufriedenheit haben bereits eigene Hebel; keine neuen Kern-Eingänge).
- **Validierung:** reine Doku-Änderungen, kein Build-Einfluss.

## P1 – Kapitel 13 vollenden: Rivalen-Voll-Simulation + Gegenwirkung
- **Ziel:** Das Minimal-Modul zur echten Wochen-Tick-Simulation heben – deterministisch und idempotent (V8), **ohne RNG**.
- Schritte:
  1. **Rivalen-Mini-Ökonomie im Wochen-Tick** (`RivalService` + `GameClockService.catchUp`): je Rivale und Blockanker (CRC32) deterministische Aktionen: „investiert in PP" (PP-Wanderung entlang `rivalPp*`-Formeln, Rubber-Band existiert), „heuert an/auf" (PP-Anstieg), „Pleite" (unter `rivalPpBankruptThreshold` → `insolvent`, Slot leer), **Nachrücken** (neuer Rivale erst nach **1 Wochen-Tick** Verzögerung – Entscheidung 13/3).
  2. Ein-/Austritt bei Prestige-Änderung des Stadtteils (`rivalCountFromPrestige` neu auswerten; bestehende `countFor`-Logik in den Tick heben statt nur Erst-Rostern).
  3. **Gegenwirkungs-Formel fixieren** (4.1/#10): `effectiveIncomeFactor = incomeFactor(PP) × competitionPressureFactor(PP, Ø-Rivalen-PP)` in `EconomyBalance` als Formel-Doku + Tuning; `balance_sanity_test`-Vertrag (Faktor in [0.6375, 1.4375]-Band, Monotonie).
  4. Nötige Balance-Werte in `EconomyBalance`; **Tests:** `rival_service_test`, `rival_fairness_test` erweitern („kein Schummeln"), neuer `rival_simulation_weekly_test`.
- **Dateien:** `lib/services/rival_service.dart`, `lib/services/game_clock_service.dart`, `lib/services/economy_balance.dart`, `lib/models/rival_restaurant.dart` (ggf. +`insolventSince`/`nextRivalIndex`), Tests s. o.
- **Abnahme:** Rivalen handeln deterministisch im Catch-up; Pleite/Nachrücken mit 1-Tick-Lücke; `flutter test` grün.

## P2 – FRT C2-Feinschliff (4.1/C2) – ✅ umgesetzt
- **Ziel:** Entdeckung hat Konsequenzen; verlorene Stadtteile sind zurückeroberbar.
- Schritte:
  1. **Persistente Fehde/Stance: ✅** Neues `RestaurantData`-Feld `frtFeudUntilWeekById`
     (Rivale → letzter **Wochen-Index** der Fehde; Schema 10 → **11**, additiv/tolerant,
     `Map.of`-Kopie beim Laden/Sichern). `RivalService.applyFrtFeud` setzt die Fehde beim
     **Aufdecken** einer FRT-Fehl-Attribution für den *behaupteten* Rivalen
     (`attributedRivalId`) auf `weekIndexOf(blockAnchor) + frtFeudWeeks`; die Wirkung liest
     `RivalService.standings` **und** `battleParticipants` über `escalateStance`
     (`ally → neutral → enemy`, `enemy` bleibt). Der Wochen-Index statt eines Datums hält die
     Stance driftfrei (V8); nur **aufgedeckte** Angriffe erzeugen eine Fehde.
  2. **Ranglose Angriffs-Simulation (Q7b): ✅** `RivalService.frtAttacksRival` (CRC32 je
     Rivale/Wochen-Index) markiert offene FRT-Angriffe; `_ppUnderFrtPressure` senkt die
     **angezeigte** Rivalen-PP in `simulateField` und `standings` um
     `frtRivalAttackPpLoss` – mit Schwund-Boden auf `rivalPpBankruptThreshold`, damit die
     Invarianten „aktiv ⇒ gesund" und „insolvent ⇔ unter der Schwelle" erhalten bleiben
     (`simulatedRivalPp` selbst bleibt monoton). Sichtbar über
     `WeeklyTickResult.frtRivalAttacks` + Wochenbericht-Zeile `catchUpFrtRivalAttacks`.
  3. **Befreiungs-Gefechte (Q4b): ✅** Der bestehende Senkungspfad `reduceCorruption` meldet
     jetzt die **Befreiung** (Rückgabe `bool`); `ScreenBattleResult` zeigt darauf den
     l10n-Hinweis `districtLiberatedMessage`. Die Karte/der Stadtteil bleibt bespielbar, und
     unter der Schwelle hebt die Q4-Hysterese `districtLost` auf (Stadtteil wieder gründbar).
- **Abweichung/Notiz:** Die Umsetzung nutzt **ein** Feld (`frtFeudUntilWeekById`) statt der
  skizzierten zwei (`frtFeudUntil`/`stanceBiasById`) – die Bias-Stufe ist genau
  „eine Stufe Richtung Feind", also vollständig aus Rivale + Wochen-Index ableitbar.
- **Dateien:** `lib/models/profile_data.dart` (Schema 11), `lib/services/rival_service.dart`,
  `lib/services/game_clock_service.dart`, `lib/objects/object_profile.dart`,
  `lib/screens/screen_battle_result.dart`, `lib/screens/screen_restaurant.dart`,
  `lib/l10n/app_de.arb`/`app_en.arb`.
- **Tests:** neuer `test/frt_feud_test.dart` (Fehde-Anwendung/-Ablauf, Rangliste/Gefecht,
  Tick-Fortschreibung, `runCatchUp`-Persistenz, Q7b-PP samt Boden-Invariante,
  Befreiungs-Meldung) + `test/profile_data_test.dart` (Round-trip/Toleranz von
  `frtFeudUntilWeekById`, Schema 11).

## P3 – Erweiterungen `11b` (4.2/#9) – ✅ umgesetzt
- **Ziel:** Restliche Erweiterungen mit entschiedenen Wirkungen bauen; Strafenquelle ergänzen.
- Schritte (Muster der Checkliste `11b`):
  1. **`vault: ✅`** Negativzinsen **−10 % des Satzes/Stufe** (max. 3): `UpgradeSpec.negativeInterestReliefPerLevel`,
     `EconomyService.applyNegativeInterest(budget, reliefPercent:)` und die Verdrahtung in
     `GameClockService.catchUp` (Wert einmal je Catch-up) **sowie** in
     `ObjectProfile.applyNegativeInterest`/`negativeInterestReliefPercent` (Gefechts-Pfad) –
     beide Pfade rechnen identisch, Deckel 100 %. Der Caissier bleibt als additiver
     `management`-Posten (`11a`) vorbereitet.
  2. **`school: ✅`** **−5 % Fortbildungskosten/Stufe** (max. 3, 300 €/30 €) –
     `trainingCostReductionPerLevel`; neuen Einzelquelle-Helfer
     `ObjectProfile.promotionPurchaseCost(rank)` eingeführt und in `promoteToRank`
     (inkl. `upgradeToLineCook`, Default-Kosten jetzt **nach** Abzug) und im
     Bestätigungsdialog (`ScreenRestaurant._promoteCharacter`) genutzt. Die Alternative
     „Sieg-XP +2 %" ist verworfen (XP-Seite durch PR-Kampagne belegt).
  3. **`security: ✅`** **+5 Prozentpunkte Entdeckung/Stufe** (max. 3, 220 €/22 €) –
     `detectionBonusPerLevel`, additiv zum Sicherheitschef in
     `RivalService.incomingDetectionPercent`, Deckel 100. Die Alternative
     „Abschöpfung −5 %" ist verworfen (macht die Gegenschlag-Kette wertvoller).
  4. **`certification: ✅`** mit der **Strafenquelle Behörden/Inspektionen** (`InspectionService`,
     deterministisch, `penaltyCosts` im Wochen-Tick, additive Minderung) – bereits vor P3
     erledigt.
  5. **`stars: ✅`** **beide** Effekte: `prestigeBonusPerLevel` (0.01 = +1 % der PP-Domäne je
     Stufe → `GameClockService.powerProjectionState` addiert `prestigeBonus ×
     powerProjectionDomainMax` PP, gedeckelt) und `sabotageTargetReliefPerLevel` (0.05 = −5
     Prozentpunkte Angriffswahrscheinlichkeit je Stufe → `RivalService.incomingChancePercent`,
     wirkt über `incomingAttemptOccurs(chancePercent:)` auf **alle** Konsumenten).
- **Notiz:** `weeklyMenu`/`terrace`/`delivery` (Gruppe C, Zeitfenster) sind **bewusst vertagt** –
  die Designentscheidung dazu ist in `11b` § „Entscheidungen (getroffen)“ (und § 4.3) festgehalten:
  erst Mechanik-Entscheidung, kein Tuning.
- **Dateien:** `lib/models/restaurant_upgrade.dart` (Enum + 5 neue `UpgradeSpec`-Felder),
  `lib/services/economy_balance.dart` (4 Specs), `lib/services/economy_service.dart`
  (`upgradeEffects`-Summen + Zins-Parameter), `lib/services/game_clock_service.dart`,
  `lib/services/rival_service.dart`, `lib/objects/object_profile.dart`,
  `lib/screens/screen_restaurant.dart` (Kachel-Name + Beförderungspreis), l10n DE/EN.
- **Tests:** `test/economy_service_test.dart` (Specs/Sätze), `test/game_clock_service_test.dart`
  (Tresor-Zinsen im Tick, Sterneküche-PP), neuer `test/upgrades_p3_hooks_test.dart`
  (Entdeckung, Ziel-Schutz, Beförderungspreis, Zinsen im Spielstand),
  `test/screen_restaurant_test.dart` (vier neue Kacheln), `test/balance_sanity_test.dart`
  (jede Spec mit entschiedenen Werten), `test/frt_feud_test.dart` (Q7b/Schema 11).

## P4 – Rollen-Feinschliff `11a` (4.2/#8) – ✅ umgesetzt
- **Ziel:** UI-Lücken und offene Taxonomie-Entscheidungen schließen.
- Schritte:
  1. **Bestätigungsdialog beim Entlassen** (Entlassung ohne Rückerstattung, wie Erweiterungs-Verkauf; `11a` E21): `ScreenHireAndFire` fragt vor der Entlassung von **Teamärzten** und **Rollen** nach (`_confirmFire`, l10n `fireConfirm`); der Restaurant-Screen nutzt **denselben** Text für die **Charakter**-Entlassung (vorher uneinheitlich formuliert). Alle drei Wege sind damit gleich und ohne Rückerstattung.
  2. **Feature-Feinschliff** (`11a` E20): (a) **UI-Countdown** für laufende Features außerhalb der Personal-Karte (`ScreenRestaurant._buildActiveFeaturesInfo`, bewusst **eine** höhenbegrenzte Zeile, geteilter Helfer `managementFeatureStatusLine`); (b) **`WeekSettlement`-Zeile für Einmalkosten**: `prepaidFeatureCosts` weist die im Block aktivierten Einmalkosten aus – **eigene Zeile** neben `featureCosts` (laufende Tageskosten), weil die Beträge bei der Aktivierung bereits geflossen sind (`11a` E9/E15/E16) und die Budget-Arithmetik der Wochenzeile sonst nicht mehr stimmt; abgeleitet aus dem Aktivierungsanker (`ManagementFeatureService.prepaidActivationCosts`), also **ohne** neues Persistenzfeld und idempotent; (c) **Bestätigungsdialog vor Aktivierung** mit Wirkung, Kosten, Träger und Dauer (`_confirmFeatureActivation`) auf allen vier Aktivierungswegen.
  3. **Taxonomie E1/E2/E6 entschieden** (siehe `11a` E18): Der **Teamarzt** bleibt ein eigenständiges Objekt mit gemeinsamem Contract; die Kategorie heißt **`management`**; die Rollen-Vorschläge (Maître d'hôtel, Caissier, Sommelier) werden künftig als `management` geführt – **keine** Umklassierung bestehender Rollen, `role_single_employment_test` bleibt unverändert.
  4. **Lohn-Thriftiness: nicht eingeführt** (`11a` E19) – solange Rollen keine Persönlichkeit haben, gilt der Fixlohn (G4).
- **Dateien:** `lib/screens/screen_hire_and_fire.dart`, `lib/screens/screen_restaurant.dart`, `lib/services/game_clock_service.dart`, `lib/services/management_feature_service.dart`, `lib/l10n/management_feature_status.dart` (neu), `lib/l10n/app_de.arb`/`app_en.arb`, Doku `11a`.
- **Tests:** `management_feature_test.dart` (Einmalkosten im Wochenblock, feste + Level-abhängige Preise), `screen_hire_and_fire_test.dart` (Entlass-Dialog, Aktivierungsdialog inkl. Abbruch/Doppelbuchungs-Schutz, Karten-Layout), `screen_restaurant_test.dart` (Feature-Countdown).
- **Nebenbefund (mitgefixt):** Die Karte der **angestellten** Management-Rolle war zu niedrig für ihren Feature-Block (28 px Overflow, sobald eine `management`-Rolle mit Feature angestellt war) – die Listenhöhe im `ScreenHireAndFire` wurde angepasst; der neue Test sichert das ab.

## P5 – Karrierepfade + Personal (4.2/#7, #6) – ✅ umgesetzt
- **Ziel:** Schließt die zwei Personal-Lücken.
- Schritte:
  1. **Karriere-Neustart auf Level 0**: `ObjectProfile.restartCareer` – Rang → Lehrling, Level/XP → Start (Design „Level 0“ = frischer Lehrling, `levelValue = 1`), Station und Doppelrolle → keine, Zustand → `ready` (Verletzungen, Notfall-Spritze, Stress-/Ruhe-Override aufgehoben), Ressourcen auf die Trait-Startwerte. **Identität bleibt** (`id`, Persönlichkeit, Match-Historie, Name/Grafik). Kosten level-abhängig (`EconomyBalance.careerRestartCostBase`/`careerRestartCostPerLevel`, `EconomyService.careerRestartCost`, Muster `transferCost*`) mit `canAfford`-Prüfung; fällt ein **aktiver** Chef de cuisine weg, rückt ein formeller nach. UI: Karte + Bestätigungsdialog in `ScreenCharacterDetail` (sichtbar ab Rang > Lehrling, danach folgt die Ansicht der neuen Instanz).
  2. **Teamdynamik**: neuer `lib/services/team_dynamics_service.dart` – je **ungeordnetem Paar** eine deterministische Affinität (`+1` Sympathie / `0` / `−1` Spannung) aus beiden Persönlichkeits-IDs **und** den stabilen Charakter-IDs (`CRC32`, RNG-frei, symmetrisch); die Ø-Affinität wirkt additiv über `EconomyBalance.teamChemistryAttractivenessWeight`/`teamChemistrySatisfactionWeight` auf **`GameClockService.attractivenessOf` und `satisfactionOf`** (Teams < 2 Charaktere und Alt-Daten ohne Profil neutral). Bewusst **nur** Persönlichkeiten, keine Typ-/Rang-Paare (keine Doppelzählung mit den Rang-/Stations-Effekten).
  3. **Klassen-Profile Sous-chef/Pâtissier**: `ObjectChefDePartie`/`ObjectSousChef` waren bereits umgesetzt (V10); neu ist das **Support-Profil** `ObjectPatissier` (`lib/objects/player_objects/object_patissier.dart`, erbt über `ObjectChefDePartie` von `ObjectApprentice`) mit eigenem Werteblock `EconomyBalance.patissierStats` und `station = kStationPatissier`. Beim Laden wählt die **persistierte Station** deterministisch das Profil (`_staffDataToApprentice`) – **kein** neues Schema-Feld; die Beförderungskette (Chef de partie → Sous-chef) bleibt unberührt.
- **Dateien:** `lib/services/team_dynamics_service.dart` (neu), `lib/objects/player_objects/object_patissier.dart` (neu), `lib/objects/object_profile.dart` (`restartCareer`, Pâtissier-Ladepfad), `lib/objects/object_apprentice.dart` (unverändert, Basisklasse), `lib/services/economy_balance.dart`, `lib/services/economy_service.dart`, `lib/services/game_clock_service.dart`, `lib/screens/screen_character_detail.dart`, `lib/l10n/app_de.arb`/`app_en.arb`.
- **Tests:** `test/team_dynamics_test.dart` (Determinismus/Symmetrie/Domäne + Wirkung auf Attraktivität und Zufriedenheit), `test/career_restart_test.dart` (Kosten, Reset, Ablehnungen, Nachrücken), `test/object_patissier_test.dart` (Profil, Support-Aura, Ladepfad), `test/screen_character_detail_career_restart_test.dart` (Button, Dialog, Abbruch, Buchung) sowie neue Verträge in `balance_sanity_test.dart`.
- **Abweichung/Notiz:** „Level 0“ ist im Code ein **frischer Lehrling** (`levelValue = 1`, `currentXPValue = 0`), weil `levelValue = 0` die Aufstiegsschwelle auf 0 setzen würde. Die Team-Chemie ist bewusst ein **Nudge** (max. ±0.5 auf die Eingangswerte) und kein dominanter Hebel.

## P6 – Zeitsystem- & Pfad-Feinschliff (4.2/#5, #4) – ✅ umgesetzt
- **Ziel:** Transparenz der Abrechnung; Plattform-Pfade.
- Schritte:
  1. **L2-Detaildialog: ✅** Wochen-Aufschlüsselung als Dialog aus dem Catch-up-Summary – `_showWeekReport` zeigt je `settlement` einen aufklappbaren Block (Woche, Zeitraum, Einkommen, Ärzte, Personal, Unterhalt, Zinsen, Strafen, Features, Einmalkosten, Sabotage, Budget danach); dafür neu `WeekSettlement.rivalSabotageLoss` (pos. Verlust des Blocks, bereits im Einkommen verrechnet). l10n DE/EN ergänzt, `flutter gen-l10n` ausgeführt. Tests: `game_clock_service_test.dart` (Gruppe „Wochen-Aufschlüsselung“), `screen_restaurant_test.dart` (Dialog).
  2. **P3-Journal `last_tick.json`: ✅** Write-ahead in `ProfileStorage` (`writeTickJournal`/`clearTickJournal`/`readTickJournal`, atomar, tolerant) über die vier Catch-up-Einstiege (`_runResumeCatchUp`, `_runTick`, `_switchRestaurant`, `screen_start._login`); verwaiste oder defekte Journale werden beim Laden gemeldet/entfernt und blockieren nie. Test: `profile_storage_test.dart` (Gruppe „Tick-Journal“).
  3. **`path_provider`/AppData: ✅** `getApplicationSupportDirectory()` (Unterordner `tiled_warfare_profiles`) statt relativem `profiles/`, Fallback auf relativ ohne Plattformkanal; einmalige tolerante **Kopie**-Migration beim ersten Start; Bildpfade absolut geschrieben und Legacy-Relativpfade über `ProfileStorage.absolutePath` aufgelöst. Test: `profile_storage_appdata_test.dart` (mit `PathProviderPlatform`-Doppel).
- **Dateien:** `lib/services/game_clock_service.dart`, `lib/screens/screen_restaurant.dart`, `lib/services/profile_storage.dart`, `lib/screens/screen_start.dart`, `lib/l10n/app_de.arb`/`app_en.arb`, `pubspec.yaml`.
- **Validierung:** `flutter analyze` = 14 Baseline-`info`s, `flutter test` = **641 grün** (+10).

## P7 – Balance-Tuning + Abschluss – ✅ umgesetzt
- **Ziel:** Werte-Pass + Dokument-Synchronisierung.
- **Schritt 1 – Werte-Pass (4.2/#10), ✅:** Die Tuning-Größen aus `10`/`11a`/`11b` wurden durchgesehen und in `EconomyBalance` justiert; dabei wurden **zwei echte Wert-Fehler** behoben:
  - **`Grillardin`/`Friturier` (Rôtisseur-Varianten):** `Friturier` war eine strikte Obermenge von `Grillardin` (gleiche Angriffs-/Schadenswerte **plus** 10 % Reichweite) – der Nahkampf-Zweig war damit entwertet. Neu: `Grillardin` +10 % Angriff/+10 % Schaden, `Friturier` +10 % Schaden/+10 % Reichweite (jeder Zweig tauscht 5 % Schaden gegen genau eine Zweitwirkung).
  - **`Potager`/`Légumier` (Entremétier-Varianten):** bis dahin **identisch** – die Stationswahl war wirkungslos. Neu: `Potager` trägt die „Suppen-/Flächenwirkung“ als **Aura-Schaden** (+5 % Aura-Schaden zusätzlich zur Aura-Verteidigung), `Légumier` bündelt den „Zutaten“-Nutzen in der **Team-Aura** (+10 % Aura-Verteidigung statt eigener Zweitwirkung).
  - **Unverändert bestätigt** (und nun als Vertrag festgeschrieben): Lohn-Spanne ±20 % (`thriftinessWageSpread`, symmetrisch für Brigade **und** Teamarzt), Aufstiegs-Gate (Aufstiegskosten relativ zum Lohn steigen mit dem Rang), Rollen-Lohn-Korridore (Hilfsrolle 50–200 €, Verwaltung 100–300 €, Verwaltung als teurere Kategorie), `ruheMargin = 20` (tiefer als die erste Stress-Staffel, für den Median-Zielwert 50 erreichbar), Sink-Werte (5/Tag, 10/Einsatz = zwei Ruhetage; eine Woche ohne Gefecht räumt keinen Median-Charakter leer), Trait-Prozente (±15 % Kampf-Trait ≤ Stations-Deckel, Varianz exakt ±20 über `personalityVarianceModulo = 2 × range + 1`, kollisionsfreie Profil-Sockel), Erschöpfungs-Spirale (~35/70 pp pro Nullwoche bleibt in der W100-Domäne, Sink-Erleichterung auf 100 % gedeckelt), Rolle ↔ Erweiterung (jede Zuordnung aus `11a` trägt ihren Anker-Effekt, jeder Hebel gehört genau einer Erweiterung).
- **Schritt 2 – Dokument-Synchronisierung, ✅:** `15_Zusammenfassung.md` abgeglichen (Häkchen ✅, 4.1/4.2-Status, § 5); zusätzlich in diesem Pass: `10_Karrierepfade.md` (Stations-Tabelle + Tuning-Regeln der Varianten), `9_Personal.md` (Balance-Zahlen + Verträge), `11a_Hilfs_und_Servicerollen.md` (Zuordnung Rolle ↔ Erweiterung abgesichert; `vault`/`security` als umgesetzt nachgezogen) sowie `11b_Restauranterweiterungen.md` und `doc/rules/team_rules.md` (aus den Vorpaketen).
- **Schritt 3 – Schluss-Validierung, ✅:** `flutter analyze` = 14 Baseline-`info`s (keine neuen Warnungen); `flutter test` = **695 grün** (`balance_sanity_test.dart` wuchs von 56 auf 66 Tests, +10).
- **Bewusst vertagt (nicht P7):** Die **Gruppe-C-Zeitfenster** (`weeklyMenu`, `terrace`, `delivery`, `11b`) bleiben ungebaut; die **Designentscheidung** dazu ist festgehalten (`11b` § „Entscheidungen (getroffen)“, hier § 4.3) – sie brauchen zuerst eine Mechanik-Entscheidung, kein Tuning.

## Querschnitt (gilt für alle Pakete)
- **Konventionen:** alle Balance-Werte → `EconomyBalance` (V7, keine magischen Zahlen); rein & deterministisch (injizierte Zeit, CRC32 statt RNG im Tick); idempotenter Catch-up bleibt erhalten (V8); Schema-Bumps tolerant mit Migration (`kProfileSchemaVersion` + `profile_data_test`); l10n-Strings DE/EN via `flutter gen-l10n`; pro Paket Tests + `balance_sanity_test`-Verträge.
- **Reihenfolge-Gründe:** P1/P2 zuerst, weil `stars` und die Ranglistenumgebung davon abhängen; P3 (Strafenquelle) macht `certification` sinnvoll; P4/P5 sind UI-/Personal-Feinschliff ohne Querabhängigkeiten; P6/P7 zuletzt.

---

**Offene Punkte, die *du* beim Umsetzen entscheiden musst** (ich habe Empfehlungen eingebaut) – **alle entschieden und umgesetzt (P2/P3):**
- `school`-Wirkung: ✅ **Fortbildungskosten −5 %/Stufe** (nicht Sieg-XP +2 %).
- `security`-Wirkung: ✅ **Entdeckung +5 Prozentpunkte/Stufe** (nicht Abschöpfung −5 %).
- Taxonomie E1/E2/E6: ✅ Teamarzt-Sonderstatus beibehalten, Kategorie `management`, Vorschlags-Rollen nach `management` (P4).
- Umfang FRT-C2: ✅ **Kern *und* ranglose Angriffs-Simulation** (Fehde + Befreiung + Q7b) – P2.
- 4.1/#1 (PP-Eingangswerte): als Analyse/Entscheid belassen, **keine** neuen Eingänge (**P7-Werte-Pass ✅** – unverändert bestätigt).

Das Ganze ist in **7 überschaubare Pakete** zerlegt, die jeweils für sich committbar und testbar sind. Umgesetzt sind **P0–P7** (inklusive des Werte-Passes aus **P7**, 4.2/#10). Bewusst zurückgestellt bleibt allein die Gruppe-C-Zeitfenster-Idee aus `11b` (`weeklyMenu`, `terrace`, `delivery`) – als **Designentscheidung** dokumentiert (`11b` § „Entscheidungen (getroffen)“, hier § 4.3): erst Mechanik-Entscheidung, kein Tuning.