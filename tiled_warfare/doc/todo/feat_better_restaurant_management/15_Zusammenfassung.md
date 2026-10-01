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
| `7_Wirtschaftswerte_zentralisieren.md` | V7 (→ P7) | ✅ | `EconomyBalance` als einzige Balance-Quelle (L1–L8 umgesetzt, L9 zurückgestellt) |
| `8_Echtzeit-Zeitsystem.md` | V8 (→ V2/V3) | ✅ | Anker `lastSeenAt`/`weekAnchorAt`, Tagesschritt, 60-s-UI-Tick, idempotenter Catch-up |
| `9_Personal.md` | V9 (→ P9) | ✅ | Attribute, Persönlichkeit (`PersonalityTraits`), Ressourcen, Stress/Ruhe, Host-Fuzzy verdrahtet |
| `10_Karrierepfade.md` | V10 | ✅ | Ränge bis Chef de partie, Stationen, Doppelrolle formell/aktiv, Hilfs-/Service-Rollen, Wochenlöhne, Personal-Transfer |
| `11a_Hilfs_und_Servicerollen.md` | V11–V13 | ~ | Support-Rollen + Verwaltungsrollen (Chefsekretärin, Rechtsanwalt, Buchhalter, Oberkellner, Personalchef, Lagerist, Gewerkschaftschef, Sicherheitschef) + Features (PR-Kampagne); Detail-Entscheidungen E1/E2/E6 offen |
| `11b_Restauranterweiterungen.md` | V2 § 10 / V1-Paket | ~ | 9 Erweiterungen spezifiziert; `cellar`, `coldRoom`, `firstAid`, `lounge` umgesetzt; `vault`, `certification`, `school`/`security`, `stars` offen |
| `12_Power_Projection.md` | – | ✅ | Power Projection (Fuzzy), Stadtteil-Ranking, PP-Einkommensfaktor umgesetzt & validiert |
| `13_Gegner_Restaurants.md` | – | ~ | Rivalen-Roster + Sabotage-Minimal-Modul (V11/V13) umgesetzt; Mini-PP, Rangliste, Stance und Gefechtsteilnahme implementiert; Voll-Simulation (Rivalen-Aktionen im Wochen-Tick, Ranking-Badge im `ScreenRestaurant`) offen |
| `14_FRT.md` | – | 📝 | FRT-Triumvirat, Korruptionsmeter, Sabotagen – Entwurf |

---

## 3. Kernpunkte der Umsetzung

- **Wirtschaft (V2/V7/V8):** laufender Geldkreislauf aus Gefechtserlösen, passivem Einkommen und wöchentlichen Kosten; Negativzinsen und Bankrott-Flow verdrahtet; Wochen-Catch-up mit `WeekSettlement`.
- **Zeit (V8):** Echtzeit-Anker je Spielstand (`lastSeenAt`/`weekAnchorAt`); Tagesschritt mit anteiligen Resttagen (Σ Blocktag = Wochenertrag); periodischer UI-Tick (60 s) und ankerstabile, idempotente Wiederholung.
- **Heilung (V3):** `status` als einzige Quelle der Wahrheit (LP abgeleitet); Kette `dying → injured → hurt → afraid → reeling → ready`; Notfall-Spritze automatisch, Rückfall nach 24 h.
- **Datenmodell (V1):** `RestaurantData` als Zustandsträger; Migration mit ID-/`lastSeenAt`-/Stadtteil-Fallback; Speichern per Merge (`toProfileData()`), Restaurant-Umschalter in der UI.
- **Persistenz (V6):** Laden über Verzeichnis-Scan, atomares Schreiben mit `.bak`, tolerante Deserialisierung, sichtbare Fehler und `kProfileSchemaVersion` (in Folgekapiteln bis v10 in `14_FRT.md` geplant).
- **Personal (V9/V10):** Attribute und Persönlichkeit (`PersonalityTraits`, Ressourcen, Stress/Ruhe) wirken auf Management und Gefecht; Karriereränge, Stationen, Doppelrolle formell/aktiv, Hilfs-/Service- und Verwaltungsrollen, Wochenlöhne, Personal-Transfer.
- **Erweiterungen (V2 § 10 / 11b):** `cellar`, `coldRoom`, `firstAid`, `lounge` wirken auf Attraktivität, Zufriedenheit, Kapazität, Heilzeit und Ressourcen; Schnittstellen zu Rollen (Sommelier, Lagerist, Plongeur, Aboyeur).
- **Rivalen-Minimal-Modul (V11/V13):** deterministischer Roster je Stadtteil, Spieler-Sabotage (Chefsekretärin), eingehende Rivalen-Sabotage mit Entdeckung, Gegenschlag (Sicherheitschef) und Einkommens-Abschöpfung.
- **Power Projection & Rivalen-Rangliste (Kap. 12/13):** PP (0–100) als deterministische Fuzzy-Inferenz aus Konkurrenzdichte, Bilanz und Teamqualität; Stadtteil-Rangliste inkl. simulierter Rivalen-PPs (Rubber-Band, Stance, Pleite-Kennzeichnung); deterministische Gefechtsteilnahme-Verteilung; der Einkommensfaktor (PP × Konkurrenzdruck) skaliert das passive Wocheneinkommen und wird im `WeeklyTickResult` ausgewiesen.

**Validierung:** `flutter analyze` ohne Fehler/Warnungen (Baseline: 14 `info`-Lints im neuen Code); `flutter test` grün – letzter dokumentierter Stand aus Kapitel 10: **342 Tests**.

---

## 4. Offene Fragen

> Dieser Abschnitt beantwortet die Leitfrage des Sprints. Er fasst die „Offenen Fragen / Offenen Punkte / Offenen Folgepunkte“ der Einzelkapitel zusammen, entdoppelt sie und verweist auf die Quelle.

### 4.1 Design-Entscheidungen (Entwürfe 12–14)

| # | Frage | Quelle | Entscheidung / Vorschlag |
|---|---|---|---|
| 1 | **PP-Eingangswerte:** Welche Werte (Erweiterungslevel, Rebranding-Frische, Kundenzufriedenheit, Social-Media-Manager) kommen in die Kern-Fuzzy, welche nur in den Einkommensfaktor? | `12_Power_Projection.md` → Offene Fragen 5 | Per se sind alle vier für die PP ausschlaggebend, daher wäre es eine Überlegung, sie einzubauen. Eine genaue Prüfung, ob sie wirklich nötig sind, ist jedoch sinnvoll; etwa wirkt die PP auf das passive Einkommen ein, daher könnte die Kundenzufriedenheit weggelassen werden, weil sie bereits einen Einfluss hat. Ergo: Genaue Analyse und Abwägen. |
| 2 | **Faktorform:** linearer Faktor vs. zweite Mini-Fuzzy-Stufe (PP → Faktor) – einheitlich für PP und Rivalen-Konkurrenzdruck entscheiden. | `12` → 6, `13` → 6 | Fuzzy-Stufe |
| 3 | **Persistenz PP/Rank:** je Catch-up neu berechnen oder als Feld (`powerProjection`, `rank`) in `RestaurantData` sichern (inkl. Migration)? | `12` → 4 | Beim Catch-up neu berechnen. |
| 4 | **Platzierung in der UI:** Wo wird „Platz X von Y“ angezeigt (Restaurant-/Start-Screen, Wochenbericht)? | `12` → 7 | Die Platzierung, inklusive aller Gegner, sollte im Wochenbericht als Liste auftauchen. Im Restaurant-/Start-Screen hingegen das „Platz X von Y“. |
| 5 | **Update-Reihenfolge im Catch-up:** Ranking-Update vor oder nach der Einkommensbuchung (Vorschlag: Bilanz/Teamqualität → PP → Ranking → Einkommen mit neuem Faktor)? | `12` → 8 | Vorschlag passt. |
| 6 | **Rivalen-Skalierung/Balancing:** präzises Mapping Prestige-Tier → Rivalenanzahl (`rivalCountFromPrestige`) und Caps (`rivalCountMin`/`rivalCountMax`); S–D-Schwellen 2.00/1.60/1.30/1.00 vorläufig. | `12` → 1, `13` → 1 | Vorschlag? |
| 7 | **Rivalen-Voll-Simulation:** Rivalen-PP/Mini-Modell, Rangliste, Rivalen-Aktionen im Wochen-Tick und Ranking-Badge im `ScreenRestaurant`. | `13` → „Noch offen“ | Vorschlag erstellen |
| 8 | **Gefechtsteilnahme der Rivalen:** Truppenstärke je Gefecht und Verhalten bei zu wenigen `spawn_player*`-Punkten (deterministische Reduktion → Verteilung auf vorhandene Punkte). | `13` → 2 | Verteilung |
| 9 | **Stance-Schwellen:** ab welchem Rangabstand/PP-Verhältnis ist ein Rivale Verbündeter/Neutral/Feind (inkl. Anzahl der Rivalen je Stance)? | `13` → 3 | Das ist davon abhängig, wie viele Gegner im Gefecht sind. Vorschlag: bis 20 % Unterschied ist die Chance „hoch“, dass sie Freunde sind, ab 80 % ist die Chance „hoch“, dass sie Feinde sind, bei 50 % ist die Chance „hoch“, dass sie neutral zueinander sind. |
| 10 | **Gegenwirkungs-Formel:** exakte Formel für den Konkurrenzdruck- bzw. `powerProjectionIncomeFactor`. | `13` → 5 | Vorschlag? |
| 11 | **Folgen unentdeckter Sabotage:** V13 bucht die Einkommens-Abschöpfung (10 % je unentdecktem Angreifer, Deckel 30 %); offen bleiben Kunden-/Ansehensverlust, Erweiterungsschäden („Reparatur“), höhere laufende Kosten oder Strafzahlungen – hier greift später die „Schwere der Tat“. | `13` → 7 | Vorschlag, abgesehen davon, dass eine unentdeckte Sabotage erfolgreich war und damit volle Wirkung zeigt. |
| 12 | **FRT-Werte-Tuning (Q2):** konkrete Beträge für `frtCorruptionPerWeekPercent` (Vorschlag 1), `frtCorruptionReducePer*`, `frtMonsterStrengthScalePercent`, `frtCorruptionIncomePenaltyMaxPercent`, `frtPowerProjectionPenaltyPercent` sowie Sabotage-/Eliminierungs-Anstiege. | `14_FRT.md` → Offene Fragen 1 | Vorschlag? |
| 13 | **FRT – Erholung verlorener Stadtteile (Q4b):** „Befreiungs-Gefechte“ zulassen oder natürlichen Verfall einführen (ohne eigenes Restaurant fehlt eine Senkungsquelle)? | `14` → 2 | Befreiungsgefechte sind erlaubt. |
| 14 | **FRT – Monster-Skalierung (Q3b):** Skalieren auch Bewegungs-/LP-Werte oder nur Angriff/Verteidigung/Schaden; Rundung je Stat deterministisch festhalten? | `14` → 3 | Alle Werte skalieren. |
| 15 | **FRT – Power-Projection-Formel (Q8):** exakte Formel und Ort des Korruptions-Abzugs am PP-Einkommensfaktor. | `14` → 4 | Vorschlag? Eventuell Fuzzy-Logik? |
| 16 | **FRT – Fehl-Attribution (Q6b):** deterministische Wahl der „behaupteten“ Rivalen-ID, Entdeckungswahrscheinlichkeit und ob FRT-Sabotage zusätzlich die V13-Abschöpfung auslöst. | `14` → 5 | Der Rivale, welcher in direkter Konkurrenz zum betroffenen Ziel steht, sowohl nach oben als auch nach unten. |
| 17 | **FRT – Stance/Angriffsziel (Q7b):** wie Rivalen eine ranglose Fraktion angreifen (Gefecht/Gegensabotage) und welche Schwellen/Parameter dazu in `EconomyBalance` kommen. | `14` → 6 | Die FRT bzw. ihre Truppen gelten für alle als Feind. |

### 4.2 Offene Implementierungs- und Folgepunkte (Kapitel 1–11)

| # | Punkt | Quelle |
|---|---|---|
| 1 | **Regelwerk-Update:** `team_rules.md` auf „mehrere Restaurants als unabhängige Spielstände + Standort“ und die Echtzeit-Abrechnung anpassen (V1 Phase 4 noch offen). | `1` → Phase 4, `0-Base.md` → Offene Folgepunkte |
| 2 | **Anteilige Arzt-Abrechnung – gelöst:** Regel „kein anteiliger Einzug, erste Abbuchung erst zum nächsten Wochentick“ ist dokumentiert (team_rules.md § 2.1, 0-Base V8) und in `billWeeklyMedicCosts` (volle Blockwochen) umgesetzt. | `0-Base.md` → Entscheidung getroffen |
| 3 | **Aufgelöste Restaurants:** `0-Base.md` verlangt eine Festlegung im Folge-Dokument; V1 hat sie faktisch umgesetzt (bleibt sichtbar, blockiert Stadtteil, löschbar) – nur noch dokumentarisch nachziehen. | `0-Base.md` → Offene Folgepunkte, `1` |
| 4 | **`path_provider`/AppData-Pfad:** Ablösung des relativen `profiles/`-Pfads (Desktop-zentriert, bewusst offen). | `6` → Bewusst nicht umgesetzt |
| 5 | **Zeitsystem-Feinschliff:** L4.1–L4.5 umgesetzt (`hoursElapsed`, `_severityByStatus`, Doppel-Helfer, `shotRolledBackCount`); UTC als Zeitbasis aktiv. Offen: `maxCatchUpWeeks`-Cap (L6), L2-Detaildialog (Wochen-Aufschlüsselung), P3-Journal (`last_tick.json`) gegen die verbleibende Save-Lücke. | `8` → Offen (bewusst zurückgestellt) |
| 6 | **Personal:** Teamdynamik (Affinitäten/Konflikte zwischen Persönlichkeiten); eigene Klassen-Profile für Sous-chef/Pâtissier (bestätigt, noch nicht umgesetzt). | `9` → Offene Punkte |
| 7 | **Karrierepfade-Abweichungen:** Nachrücken des aktiven Chefs (`nachrueckenHeadChef`) und Tournant-Erleichterung (`tournantExhaustionReliefPercent`, 25 %) umgesetzt; „Neustart des Charakters bei Level 0“ offen. | `10` → Bewusste Abweichungen |
| 8 | **Hilfs-/Service-Rollen:** Mehrfach-Anstellung derselben Rolle unterbinden; Lohn-Thriftiness, falls Rollen später Persönlichkeit erhalten; Bestätigungsdialog beim Entlassen; Taxonomie-Detailentscheidungen E1/E2/E6 (Teamarzt-Einordnung, Kategorie-Name/-Zuschnitt, Zuordnung der Erweiterungsvorschläge); Feature-Feinschliff (UI-Countdown, `WeekSettlement`-Zeile für Einmalkosten, Bestätigung vor Aktivierung). | `11a` → Offene Punkte |
| 9 | **Erweiterungen:** `vault` (macht den Caissier wertvoll), `certification` (Rechtsanwalt) – gekoppelt an die fehlende **Strafenquelle Behörden/Inspektionen**; offene Wirkungs-Optionen für `school`/`security`; `stars` erst nach Klärung von 12/13. | `11a`/`11b` → Erweiterungsvorschläge |
| 10 | **Balance-Tuning:** zahlreiche Werte (Stations-/Aura-/Buff-Werte, Lohn-Spanne, `ruheMargin`, Sink-Werte, Trait-Prozente, Rolle-Erweiterungs-Zuordnung) sind Tuning-Größen, werden in `EconomyBalance` justiert und über `balance_sanity_test.dart` abgesichert. | `10`, `11a`, `11b` |

### 4.3 Bewusst zurückgestellt (nicht blockierend)

- **Layering (L9):** keine Aufteilung von `economy_balance.dart` bzw. `GameClockService` – bei weiterem Wachstum erneut prüfen (`7`, `8` L7).
- **`dispose`-Save:** zugunsten des Lifecycle-Saves bei `paused`/`hidden` (`6`).
- **Teamarzt-Fuzzy-Engine:** in V5 entfernt; die Persönlichkeits-Idee wurde in anderer Form im ausgebauten Personalsektor wieder aufgegriffen (V9) (`5`).
- **Kapitel `2`, `3` und `4`** haben keine offenen Fragen mehr; Kapitel `1` ist bis auf den Folgepunkt 4.2/1 abgeschlossen.

---

## 5. Nächste Schritte (Empfehlung)

1. **Kapitel-12/13-Stand committen:** Die Umsetzung (PP, Rangliste, Stance, Gefechtsteilnahme) liegt in `power_projection_service.dart` sowie den Erweiterungen in `economy_balance.dart`, `game_clock_service.dart` und `rival_service.dart` (inkl. Tests) uncommittet im Arbeitsverzeichnis – Review und Commit vor dem nächsten Paket.
2. **Kapitel 13 vollenden und 14 umsetzen:** offen bleiben die Rivalen-Voll-Simulation (Rivalen-Aktionen im Wochen-Tick, Gefechtsteilnahme-Verdrahtung, Ranking-Badge im `ScreenRestaurant`) und die FRT (Korruptionsmeter). Zuerst die offenen Design-Fragen aus Abschnitt 4.1 entscheiden und die Werte in `EconomyBalance` verankern.
3. **Kleine Folgepunkte schließen:** `team_rules.md`-Update (4.2/1), Zeitsystem-Feinschliff (4.2/5) sowie die Erweiterungen `vault`/`certification` samt Strafenquelle (4.2/9).
4. **Absicherung:** jede Änderung über `EconomyBalance` + `balance_sanity_test.dart` und die bestehenden Service-/Widget-Tests abdecken; `flutter analyze` und `flutter test` müssen grün bleiben.

---

## 6. Verweise

- **Basis & Entscheidungen:** `0-Base.md`
- **Umsetzungskapitel:** `1_mehrere_Restaurants.md` … `11b_Restauranterweiterungen.md`
- **Entwürfe:** `12_Power_Projection.md`, `13_Gegner_Restaurants.md`, `14_FRT.md`
- **Regelwerk:** `doc/rules/team_rules.md`
- **Balance:** `lib/services/economy_balance.dart`, `test/balance_sanity_test.dart`
