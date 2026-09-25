# Power Projection

> **Status:** Entwurf. Dieses Dokument spezifiziert den **Power Projection**-Wert (PP), der über eine **Fuzzy-Logik** bestimmt wird – als Kapitel des Sprints (gefolgt von `13_Gegner_Restaurants.md`) und aufbauend auf `2-Wirtschaftsschleife.md` (§ 8, passives Einkommen), `8_Echtzeit-Zeitsystem.md` (V8, Wochen-Tick), `7_Wirtschaftswerte_zentralisieren.md` (V7, `EconomyBalance`) sowie `9_Personal.md`.

## Ziel

Power Projection ist ein **Crisp-Wert (0–100)** als Ergebnis einer eigenen Fuzzy-Inferenz und legt zwei Dinge fest:

1. **Ranking im Stadtteil:** PP bestimmt die Platzierung des Restaurants auf der Liste aller Restaurants im Stadtteil – inklusive der NPC-Konkurrenten.
2. **Passives Einkommen:** PP wirkt als **weiterer Eingangswert** auf das passive Einkommen des Restaurants (Fuzzy-Logik aus § 8) und wird pro Wochen-Tick verrechnet.

**Abgrenzung zur Roh-Notiz:** Das Ranking ist **kein Fuzzy-Eingang**, sondern ein **abgeleitetes Ergebnis** der PP (siehe „Probleme“ → P1). Als Eingänge dienen die *Treiber* Konkurrenzdichte, Gewinn-/Verlust-Bilanz und Teamqualität – nicht die Platzierung selbst.

## Eingangswerte (Fuzzy-Eingänge)

| Eingang | Domäne | Definition / Quelle |
|---|---|---|
| Konkurrenzdichte (`competition`) | 0–1 | Relative Platzierung aus dem **letzten** Tick: `1 − (rank − 1) / (rivals − 1)` (1 = bester Rang; `rivals = 1` ⇒ 1.0). Noch keine Platzierung ⇒ neutral `0.5`. |
| Gewinn-/Verlust-Bilanz (`ratio`) | 0–1 | `wins / (wins + losses)` aus der Match-Historie (`MatchRecord`); **keine Gefechte ⇒ neutral `0.5`** (P6). |
| Teamqualität (`staffQuality`) | 0–4 | Ø Level-Rang bzw. Ø `moneyValue` (Kapazität, `GameClockService.capacityOf`) in Kombination mit `teamHealthOf(...)`; Domäne analog `EconomyBalance.inputDomainMax`. |

Weitere Vorschläge (siehe „Offene Fragen“ → 5): Erweiterungslevel (`upgrades`), Rebranding-Frische, Kundenzufriedenheit (§ 8), Social-Media-Manager (V10).

## Ranking

Pro **Stadtteil** gibt es eine Liste von Gegnern, die mit dem Restaurant um Kunden buhlen:

- Die **Anzahl der Gegner** ist abhängig von der **Popularität des Stadtteils** und kann sich im Laufe eines Spiels verändern. Konkret vorgeschlagen: Ableitung aus `EconomyBalance.districtPrestigeFor(district)` (Tiers S–D, § 8) über `rivalCountFromPrestige` – z. B. S→8, A→6, B→5, C→4, D→3, gedeckelt durch `rivalCountMin`/`rivalCountMax` (alle Konstanten in `EconomyBalance`, V7).
- **Veränderung im Spiel:** Beim Wochen-Tick (V8) wird die Liste **deterministisch** angepasst – der Spieler nähert sich der Spitze ⇒ stärkere/weitere Gegner rücken nach; fällt er ans Ende ⇒ das Feld schrumpft. Das hält die Rangliste ohne zusätzlichen Zufall lebendig.
- **Hinweis:** Die Gegner selbst (eigenes Spielmodell, Schwierigkeit) werden im **nächsten Kapitel** behandelt (spezifiziert in `13_Gegner_Restaurants.md`) und über das **Hostobjekt** (`ObjectHost`) gesteuert – analog zu den Gefechts-Gegnern. Ein NPC-Restaurant-Modell existiert im Code **noch nicht** (P3).

## Aufbau der Logik

Analog zum `PassiveIncomeService` entsteht ein neuer, reiner, testbarer **`PowerProjectionService`** (`lib/services/power_projection_service.dart`); die Sets/Peaks liegen wie gehabt in `EconomyBalance` (V7).

### Fuzzy-Variablen

```dart
class _Competition extends FuzzyVariable<double> {        // Domäne 0–1
  final schwach = FuzzySet.LeftShoulder(0.0, 0.3, 0.5, 'Schwach');
  final mittel  = FuzzySet.Triangle(0.3, 0.5, 0.7, 'Mittel');
  final stark   = FuzzySet.RightShoulder(0.5, 0.7, 1.0, 'Stark');
  _Competition() { sets = [schwach, mittel, stark]; name = 'Konkurrenz'; init(); }
}

class _Ratio extends FuzzyVariable<double> {              // Domäne 0–1
  final schlecht      = FuzzySet.LeftShoulder(0.0, 0.0, 0.45, 'Schlecht');
  final ausgeglichen  = FuzzySet.Triangle(0.15, 0.5, 0.85, 'Ausgeglichen');
  final gut           = FuzzySet.RightShoulder(0.55, 1.0, 1.0, 'Gut');
  _Ratio() { sets = [schlecht, ausgeglichen, gut]; name = 'Bilanz'; init(); }
}

class _StaffQuality extends FuzzyVariable<double> {       // Domäne 0–4 (wie inputDomainMax)
  final schwach = FuzzySet.LeftShoulder(0.0, 0.75, 2.0, 'Schwach');
  final mittel  = FuzzySet.Triangle(0.75, 2.0, 3.25, 'Mittel');
  final hoch    = FuzzySet.RightShoulder(2.0, 3.25, 4.0, 'Hoch');
  _StaffQuality() { sets = [schwach, mittel, hoch]; name = 'Teamqualität'; init(); }
}

class _PowerProjection extends FuzzyVariable<int> {       // Domäne 0–100 (Ausgang)
  final schwach = FuzzySet.LeftShoulder(0, 20, 50, 'Schwach');
  final mittel  = FuzzySet.Triangle(20, 50, 80, 'Mittel');
  final stark   = FuzzySet.RightShoulder(50, 80, 100, 'Stark');
  _PowerProjection() { sets = [schwach, mittel, stark]; name = 'PowerProjection'; init(); }
}
```

### Regelbasis & Inferenz

```dart
final rules = FuzzyRuleBase()
  ..addRules([
    (competition.schwach)                    >> (pp.stark), // wenig Konkurrenz ⇒ auch schwache Teams oben
    (competition.stark & ratio.schlecht)     >> (pp.schwach),
    (competition.mittel & ratio.gut)         >> (pp.mittel),
    (staffQuality.hoch & ratio.gut)          >> (pp.stark),
    (staffQuality.schwach & competition.stark) >> (pp.schwach),
    // …
  ]);

final output = pp.createOutputPlaceholder();
rules.resolve(
  inputs: [competition.assign(c), ratio.assign(r), staffQuality.assign(q)],
  outputs: [output],
);
return output.crispValue ?? 50;   // Defuzzifizierung über die Representative-Values (Bibliothek)
```

### Effekte

- **Ranking (nicht-fuzzy):** Alle Restaurants des Stadtteils (Spieler + NPC) werden je Wochen-Tick nach PP **absteigend** sortiert; Platzierung = Rang 1…n. Das neue Ranking fließt erst im **nächsten** Tick als Konkurrenzdichte ein (1-Tick-Verzögerung ⇒ kein Fixpunkt, P1).
- **Passives Einkommen:** `incomePerWeek = passiveIncomePerWeek(...)` (§ 8) × Faktor aus PP. Vorschlag: `powerProjectionIncomeFactor` linear aus PP 0–100 abgeleitet (z. B. 0.75 … 1.25), justierbar in `EconomyBalance`. **Bewusst als Faktor** statt als 4. Eingang der Kunden-Fuzzy (§ 8), damit der bestehende Motor samt Tests unverändert bleibt (P2). Zusätzlich wird der Faktor durch die **Gegenwirkung** der Rivalen-Aggressivität skaliert (`13_Gegner_Restaurants.md` → „Rangliste“).

## Integration

- Konstanten (`rivalCountFromPrestige`, `rivalCountMin`/`rivalCountMax`, PP-Peaks, Faktor-Spanne) in `EconomyBalance` (V7, keine magischen Zahlen).
- PP/Platzierung wird **je Catch-up neu berechnet** (idempotent, V8) – kein neues Feld in `RestaurantData` nötig, solange alles aus dem Snapshot plus einer deterministischen NPC-Quelle (z. B. aus Profil-/Restaurant-ID) ableitbar ist. Die aktuelle Platzierung wird für die UI im Wochen-Ergebnis (`WeeklyTickResult`) mitgeliefert.
- `ScreenRestaurant`: Anzeige „Platz 3 von 7 in SoHo“ (neue l10n-Strings in `app_de.arb`/`app_en.arb`).

## Probleme

### P1 – Ranking zugleich Ein- und Ausgang (Zirkelbezug)
Steht das Ranking als **Eingang** einer Fuzzy-Logik, deren **Ausgang** (PP) genau dieses Ranking festlegt, entsteht ein Fixpunkt. **Entschieden:** Eingang ist die Konkurrenzdichte aus der Platzierung des **vorherigen** Ticks (1-Tick-Verzögerung); das Ranking selbst ist Ausgabe eines einfachen Sortierens. Das macht die Logik sequentiell, deterministisch und testbar.

### P2 – Überlappung mit dem passiven Einkommen (§ 8)
Laut Roh-Notiz soll PP „weiterer Eingangswert“ der §-8-Fuzzy sein. Ein 4. Eingang würde `PassiveIncomeService` samt Verträgen (`balance_sanity_test`) ändern. **Entschieden:** PP wirkt als **Faktor** (0.75–1.25) auf `passiveIncomePerWeek`.

### P3 – „Gegner“ doppeldeutig / kein Rivalen-Modell im Code
Im Code existieren nur **Gefechts-Gegner** (`ObjectHost`, Token). Ein NPC-Restaurant-/Rivalen-Modell **fehlt**; ohne definierte Quelle ist weder die Anzahl je Stadtteil noch das Ranking berechenbar. Die in „Ranking“ vorgeschlagene Prestige↔Anzahl-Ableitung setzt damit eine Datenquelle (`13_Gegner_Restaurants.md`) voraus.

### P4 – „Qualität aller angestellten Mitarbeiter“ unterbestimmt
Es ist offen, ob Brigade + Hilfsrollen + Medics alle zählen. **Vorschlag:** kombinierter Index aus `teamHealthOf` (Zustand) und `capacityOf` (Ø `moneyValue`, Leistungsfähigkeit), optional plus `SupportRoleService`-Boni.

### P5 – Zeitbasis „pro Tag“ vs. „pro Woche“
V8 rechnet wöchentlich (mit anteiligen Resttagen). PP, Faktor und Ranking-Update gehören in den **Wochen-Tick** – eine tägliche Neubewertung würde Buchungen und Tests unnötig vervielfachen.

### P6 – Leere Bilanz bei Start
Ein frisches Restaurant hat **keine** Match-Historie (0/0). Ohne Neutralwert 0.5 würde die leere Bilanz die PP dauerhaft auf „Schwach“ drücken.

### P7 – NPC-Konkurrenz bleibt starr
Ohne eigenes PP-Modell der Gegner (oder Level-Bänder) ändert sich die Rangliste nur durch die Spieler-PP und die deterministische Ein-/Ausstiegsregel. Die Spannungskurve ist offen zu balancieren. **Adressiert:** Das symmetrische NPC-PP-Modell in `13_Gegner_Restaurants.md` (Entscheidungen 1) gibt jedem Rivalen eine eigene PP; die Balance bleibt Tuning.

## Offene Fragen

1. **Rivalen-Skalierung:** Präzises Mapping Prestige-Tier → Anzahl (`rivalCountFromPrestige`) und Min-/Max-Cap; Startwerte balancieren.
2. **NPC-Dynamik:** Sollen Gegner eine **eigene PP** erhalten (symmetrisches Modell) oder reichen feste „Level“-Bänder, die nach Spieler-Erfolg aufsteigen? **Entschieden** (symmetrisches Modell, siehe `13_Gegner_Restaurants.md` → Entscheidungen 1).
3. **Matchmaking:** Soll PP auch die **Host-Schwierigkeit** der Gefechts-Gegner skalieren (Brücke zu `ObjectHost`)? **Entschieden:** Rivalen treten im Gefecht des Spielers auf (1–4 Rivalen, Stance Verbündet/Neutral/Feind) – siehe `13_Gegner_Restaurants.md` → „Gefechtsteilnahme“.
4. **Persistenz:** Bewusst je Catch-up **neu berechnen** (Vorschlag) oder doch als Feld (`powerProjection`, `rank`) in `RestaurantData` sichern – inkl. Migration?
5. **Weitere Eingangswerte:** Welche der Vorschläge (Erweiterungslevel, Rebranding-Frische, Kundenzufriedenheit, Social-Media-Manager) kommen in die Kern-Fuzzy, welche nur in den Faktor?
6. **Faktorform:** Linearer Faktor vs. zweite Mini-Fuzzy-Stufe (PP → Faktor); Absicherung in `balance_sanity_test`.
7. **UI:** Wo wird die Platzierung angezeigt (Restaurant-Screen, Start-Screen, Wochenbericht)? Benötigte l10n-Strings.
8. **Update-Reihenfolge im Catch-up:** Ranking-Update vor oder nach der Einkommensbuchung? **Vorschlag:** Bilanz/Teamqualität einsammeln → PP → Ranking → Einkommen mit neuem Faktor.