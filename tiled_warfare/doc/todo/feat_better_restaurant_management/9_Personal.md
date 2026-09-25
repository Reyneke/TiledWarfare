# Personal, Attribute & Persönlichkeit (V9)

Dieses Dokument ist die Ausarbeitung des nächsten Schritts nach **V1–V8** aus `0-Base.md`: Es macht das **Personal** zum Träger von **Attributen** und gibt der **Persönlichkeit** endlich eine Aufgabe. Die Idee ist nicht neu – sie wurde in **V5** (`5_Halbfertige_Features.md`, „Nachtrag: Erledigte Restpunkte“ zu **F2**) bewusst zurückgestellt und ausdrücklich an den „späteren Ausbau des Personalsektors“ geknüpft: Die damalige Fuzzy-Auswertung im Teamarzt wurde entfernt, die **Persönlichkeits-Idee blieb erhalten**. Dieses Dokument löst sie ein.

> **Nummerierung:** `0-Base.md` führt V1–V8. **V9** ist hier ein Arbeitstitel; die Aufnahme in die Problemliste (P9) und in „Verbesserungen“ (V9) ist ein offener Folgepunkt (siehe „Offene Punkte“).

Die Grundsatzentscheidungen sind fixiert und werden hier **nicht** neu verhandelt:

- **Echtzeit** im Stile alter Browsergames; verpasste Zeit wird beim App-Start nachgeholt (Catch-up, V8).
- Der Spielzustand liegt auf der **Restaurant-Ebene** (`RestaurantData`); `ObjectProfile` hält nur den aktiven Spielstand (V1).
- **Balance-Werte** stehen zentral in `EconomyBalance`; keine magischen Zahlen im Fluss (V7).
- **Heilzeit und Heilwirkung bleiben deterministisch** und hängen allein von der Arzt-Qualität ab – **kein** Persönlichkeits-Einfluss (`team_rules.md` § 4.3/§ 4.5).
- Persistenz ist **tolerant** (fehlende Felder → Defaults) und versioniert (`kProfileSchemaVersion`, V6); keine stillen Datenverluste.

## Personal – Begriff & Zuständigkeit

„Personal“ im engeren Sinne sind die Charaktere und die Teamärzte eines Restaurants; der Host ist der Gegner, der Spielercharakter ist der Besitzer. Das Persönlichkeitsmodell soll für alle vier gelten; verwaltet und persistiert werden aber nur die ersten beiden.

| Rolle | Klasse / Ort | Persistenz | Persönlichkeit heute |
|---|---|---|---|
| Charakter (Lehrling, Line Cook) | `ObjectApprentice`, `ObjectLineCook` | `StaffData` | **keine** |
| Teamarzt | `ObjectTeamMedic` | `MedicData` | `enneagramProfile` – nur Anzeige/Index |
| Host (KI-Gegner) | `ObjectHost` | nicht persistiert (je Gefecht neu) | `enneagramProfile` + `HostPersonality` – wirkungslos |
| Spielercharakter (Besitzer) | `ObjectProfile` | `ProfileData` | keine (bewusst außerhalb des Umfangs) |

## Aktueller Stand (Ist-Analyse)

**Belege:** Branch `feat-restaurant-management`, Commit `539582b`.

### 1. Persönlichkeit ist heute Datenkosmetik

- `EnneagramProfile` (12 Profile, `lib/objects/object_host.dart:22–42`) wird für Charaktere **gar nicht** und für Ärzte nur als Anzeigetext und Listenindex genutzt: `displayName` (`object_team_medic.dart:81`), Anzeige im Anheuer-Screen (`screen_hire_and_fire.dart:295–308`).
- Die Arzt-Bewertung ist seit **V5** eine reine Funktion aus **Profilindex × Qualität** (`object_team_medic.dart:139–183`; Konstanten `economy_balance.dart:93–112`). Das ist reproduzierbar, aber **kein Verhalten**: „Der Reformierte“ und „Der Chaot“ unterscheiden sich nur um einen konstanten Punktabstand – und liegen beide dicht am Clamp.
- Der Host besitzt eine Fuzzy-Persönlichkeit (`HostPersonality`, `object_host.dart:50–62`), aber `_initializePersonality()` (`object_host.dart:216–225`) legt die `ruleBase` nur in einer **lokalen Variablen** an und verwirft sie; `Aggressiveness`/`RiskTolerance`/`TacticalComplexity` werden **nirgends ausgewertet**. Die Persönlichkeit beeinflusst die KI-Züge also nicht – im Widerspruch zu `doc/doc/01_class_diagram.md` und `doc/doc/03_dependency_graph.md`.

### 2. Charaktere haben keine eigenen Attribute

- `ObjectApprentice` besitzt nur `levelValue`, `currentXPValue`, `status`, die V3-Injury-Anker und `matchHistory` (`object_apprentice.dart:38–64`). Alle Kampfwerte kommen aus **Klassen-Profilen** (`EconomyBalance.apprenticeStats`/`lineCookStats`, `economy_balance.dart:252–270`; Zuweisung `object_apprentice.dart:94–100`, `object_line_cook.dart:17–23`).
- `StaffData` speichert diese Werte zwar (`profile_data.dart:141–147`), beim Laden werden sie aber nur unverändert zurückgeschrieben (`object_profile.dart:804–810`). Innerhalb einer Klasse sind damit **alle Charaktere identisch** – kein Spielraum für Individualität oder Wachstum abseits von Level/XP.

### 3. Persönlichkeit ist fragil persistiert

- Der Arzt wird über einen **Anzeigenamen-String** gespeichert (`MedicData.enneagramProfileName`, `profile_data.dart:253–278`) und beim Laden über den Namen gesucht (`object_profile.dart:857–860`). Bei Abweichung fällt es still auf `EnneagramProfile.all.first` zurück – der Arzt „wechselt“ damit unbemerkt seine Persönlichkeit.
- `EnneagramProfile` liegt in der Host-Datei (`object_host.dart`) und wird von Arzt, Profil-Serialisierung und Hire-Screen quer importiert (`object_team_medic.dart:6`). Ein Spielmodell hängt dadurch an einer konkreten Gegner-KI (Layer-Verstoß, vgl. V7/L9).
- `ObjectTeamMedic` zieht Name, Qualität und Profil aus einem **frisch erzeugten** `Random`, obwohl `random` injizierbar ist (`object_team_medic.dart:67–74`) – die Persönlichkeitswahl ist nicht deterministisch testbar (Widerspruch zum V7/L7-Anspruch).

### 4. Keine stabile Charakter-Identität

`StaffData` kennt nur `name` als Identität (`profile_data.dart:128–167`) – der Teamarzt hat dagegen längst eine `id` (`object_team_medic.dart:25`). Zuordnungen laufen in UI/Logik über Objekt-Identität oder Namen; ohne stabile ID lässt sich ein Charakter nicht zuverlässig referenzieren (Rettungswürfe, Match-Historie, künftige Attribute/Persönlichkeit).

## Problemstellung (verdichtet)

| # | Problem | Auswirkung |
|---|---|---|
| P1 | Persönlichkeit ohne Wirkung (Arzt) | 12 Profile sind bloße Etiketten; Anheuern reduziert sich auf Qualität |
| P2 | Host-Fuzzy tot (`ruleBase` verworfen) | Host-KI verhält sich für alle Profile gleich; Doku ist falsch |
| P3 | Charaktere ohne eigene Attribute | Alle Charaktere einer Klasse sind identisch |
| P4 | Persönlichkeit per Anzeigename persistiert | Stiller Persönlichkeitswechsel nach Ladefehler/Umbenennung |
| P5 | Keine Charakter-ID | Keine belastbare Referenz für Attribut-/Persönlichkeitsdaten |
| P6 | Modell am Host verortet | Personal/Arzt importiert Gegner-KI-Code |
| P7 | Zufall nicht injizierbar | Persönlichkeitswahl nicht testbar/deterministisch |

## Zielbild

1. **Z1 – Attribute für alle.** Jeder Charakter hat denselben kanonischen Attributsatz – unabhängig davon, ob er im Gefecht steht, verletzt oder auf der Bank ist.
2. **Z2 – Persönlichkeit mit messbarer Wirkung.** Jedes Enneagramm-Profil erzeugt **deterministische** Traits, die konkret auf Wirtschaft und Gefecht wirken (Formel + Clamps in `EconomyBalance`).
3. **Z3 – Eine Quelle der Wahrheit.** Persönlichkeit wird **einmal** gespeichert (Profil-ID); abgeleitete Werte werden gerechnet, nicht doppelt gepflegt (Prinzip aus V3/V4).
4. **Z4 – Stabile Identität.** Jeder Charakter erhält eine CRC32-`id` (analog `ObjectTeamMedic`/`RestaurantData`).
5. **Z5 – Modell an neutraler Stelle.** `EnneagramProfile`/`Personality` liegen in einem eigenen Modell (z. B. `lib/models/personality.dart`); Host und Personal nutzen dieselbe Definition.

**Nicht-Ziele:** kein Persönlichkeits-Einfluss auf Heilzeit/-qualität (bleibt deterministisch, `team_rules.md` § 4.3/§ 4.5); die **Ableitung** von Traits/Varianz ist RNG-frei (§ 4.1) – die **Würfelproben** in § 6 (Stress/Ruhe) sind davon ausgenommen und nutzen injizierbaren `Random`; keine neuen Charakterklassen; `vitality`/`morale` berühren die V3-Wundkette nicht (Erreichen 0 ⇒ nur Malus, § 6); `shadiness` bleibt vorerst wirkungslos (nur Datenmodell).

## Attribute

Alle Charaktere – ob aktiv im Gefecht oder nicht – verfügen über Attribute. Die folgende Liste ist **kanonisch**: Sie gilt für Lehrlinge, Line Cooks und (über dasselbe Modell) für Teamärzte, unabhängig von Gefechtsbereitschaft oder Verletzungsstatus.

**Konventionen**

- **Domänen & Clamps:** Kampfwerte sind `int`; Prozente/Modifikatoren und Grenzen stehen in `EconomyBalance` (V7) – keine Literale in den Objekten.
- **Gespeichert vs. abgeleitet:** Nur Eingangswerte werden persistiert; abgeleitete Werte (LP aus `status`, Traits aus dem Profil) werden berechnet, nicht dupliziert (V3/V4-Prinzip).
- **Eindeutige Herkunft:** Basis-Attribute stammen aus dem Klassen-Profil (`EconomyBalance.<class>Stats`), Persönlichkeits-Modifikatoren ausschließlich aus dem Persönlichkeitsmodell – niemals umgekehrt.

### 1. Basis-Attribute (Gefecht) – `ObjectToken`

| Attribut | Typ | Herkunft | Persistenz | Wirkung |
|---|---|---|---|---|
| `attackValue` | int (W100) | Klassen-Profil | `StaffData.attackValue` | Zielwert Angriffswurf |
| `defenseValue` | int (W100) | Klassen-Profil | `StaffData.defenseValue` | Zielwert Verteidigungswurf |
| `damageValue` | int | Klassen-Profil | `StaffData.damageValue` | Schaden bei Treffer |
| `movementValue` / `baseMovementValue` | int | Klassen-Profil | `StaffData.movementValue` | Bewegung pro Runde (Basiswert bleibt unverändert) |
| `rangeValue` | int | Klassen-Profil | `StaffData.rangeValue` | Reichweite Fernkampf |
| `fieldOfView` | int | Default/Klassen-Profil | abgeleitet | Sichtweite für Fog of War |
| `woundValue` / `maxWoundValue` | int | abgeleitet aus `status` | `StaffData.woundValue` | LP im Gefecht (`maxWoundValue = 3`) |

### 2. Zustands-Attribute (Management, V3)

| Attribut | Typ | Bedeutung |
|---|---|---|
| `status` | `CharacterStatus` | **Einzige Quelle der Wahrheit** für den Management-Zustand (`ready` … `overkilled`) |
| `injuryStartedAt` | `DateTime?` | Anker der Echtzeit-Heilung |
| `injuryStartStatus` | `CharacterStatus?` | Basis der idempotenten Heilungsberechnung |
| `emergencyShotAt` | `DateTime?` | Wirkfenster der automatischen Notfall-Spritze |
| `suppressedStatus` | `CharacterStatus?` | durch die Spritze unterdrückter Status |
| `timesAttackedThisTurn` / `hasActed` | int / bool | **transient** – nur im Gefecht, wird nicht persistiert |

**Ressourcen (täglich ↔ wöchentlich, neu)**

| Attribut | Typ | Bedeutung |
|---|---|---|
| `vitalityCurrent` | int (0–100) | aktueller Vitalitätsstand; Basiswert = Trait `vitality` (§ 4) |
| `moraleCurrent` | int (0–100) | aktueller Moralstand; Basiswert = Trait `morale` (§ 4) |
| `lastResourceRefillAt` | `DateTime?` | Anker für idempotentes Sinken/Auffüllen im Catch-up (Muster `injuryStartedAt`, V3) |
| `vitalityZeroSinceAt` | `DateTime?` | seit wann `vitalityCurrent` auf 0 steht (Basis des Erschöpfungs-Malus, § 6); Löschung beim Wochen-Refill |
| `moraleZeroSinceAt` | `DateTime?` | seit wann `moraleCurrent` auf 0 steht (Basis des Erschöpfungs-Malus, § 6); Löschung beim Wochen-Refill |

- **Sinken:** im Tages-Tick (`EconomyBalance.resourceSinkPerDay = 5`, V8-Tagesschritt) und je Gefechtseinsatz (`EconomyBalance.resourceSinkPerBattle = 10`, nach `ScreenBattleResult`).
- **Auffüllen:** im Wochen-Settlement (`WeekSettlement`/`weeklyTick`, V8) zurück auf den Trait-Basiswert.
- **Proben:** Jeder Verlust löst eine W100-Probe je Ressource aus – **Stress** bei Überwurf, **Ruhe** bei kritischer Unterschreitung (§ 6).
- **Erreichen 0:** keine V3-Wirkung – **kumulativer Erschöpfungs-Malus** auf alle W100-Zielwerte (+5 pp je Nulltag, bei beiden auf 0 +10 pp; kein Cap, Reset im Wochen-Refill) – siehe § 6.
- **Invariante:** `vitalityCurrent`/`moraleCurrent` berühren weder `status` noch `woundValue` – V3 bleibt die einzige Quelle der Wundwerte; geklemmt wird auf 0–100.

**Persönlichkeits-Override (Stress/Ruhe, § 6):**

| Attribut | Typ | Bedeutung |
|---|---|---|
| `personalityOverrideId` | int | temporär wirksames Enneagramm-Profil (Index in `EnneagramProfile.all`) |
| `personalityOverrideUntil` | `DateTime?` | Ablaufzeitpunkt des Overrides (Timestamps ⇒ Catch-up-fähig) |
| `personalityOverrideCause` | `stress`/`ruhe` | Auslöser (Diagnose/UI) |

### 3. Fortschritts-Attribute

| Attribut | Typ | Bedeutung |
|---|---|---|
| `levelValue` | int | Level (Fortbildungs-Gate ab Level 5) |
| `currentXPValue` | int | XP innerhalb des aktuellen Levels |
| `xpValue` | int | XP-Belohnung des Charakters |
| `moneyValue` | int | Beute pro besiegtem Gegner **und** Eingangswert der Kapazität (`GameClockService.capacityOf`) |
| `matchHistory` | `List<MatchRecord>` | Match-Historie (Sieg/Niederlage/XP) |

### 4. Persönlichkeits-Attribute (neu)

| Attribut | Typ | Domäne | Herkunft (Wurzel) | Wirkung (Ziel) |
|---|---|---|---|---|
| `personality` | `EnneagramProfile` | 12 Profile | **Wurzel**: Erzeugung/Auswahl (1× festgeschrieben) | Identität, Anzeige, Quelle aller Traits |
| `aggressiveness` | int | 0–100 | **aus `personality`** | Angriffs-/Verteidigungs-Modifikator |
| `riskTolerance` | int | 0–100 | **aus `personality`** | Schadens-/Rettungswurf-Modifikator |
| `tacticalComplexity` | int | 0–100 | **aus `personality`** | Bewegungs-/Reichweiten-Modifikator |
| `helpfulness` | int | 0–100 | **aus `personality` × Arzt-Qualität** | Rettungswurf-Bonus |
| `thriftiness` | int | 0–100 | **aus `personality`** | Wochenkosten-Faktor (Lohnforderung) |
| `vitality` | int | 0–100 | **aus `personality` + Varianz** | **Basiswert (Max)** der Vitalität – die Ressource sinkt pro Tag/Einsatz und wird am Ende der Woche wieder aufgefüllt (§ 2, „Ressourcen“) |
| `morale` | int | 0–100 | **aus `personality` + Varianz** | **Basiswert (Max)** der Moral – die Ressource sinkt pro Tag/Einsatz und wird am Ende der Woche wieder aufgefüllt (§ 2, „Ressourcen“) |
| `shadiness` | int | 0–100 | **aus `personality` + Varianz** | Wille, illegale Mittel einzusetzen – **Datenmodell ja, Wirkung offen** (siehe „Offene Punkte“) |

> **Abgrenzung:** Der Tabellenwert ist jeweils der **Basiswert (Max)** des Traits. Der **aktuelle** Ressourcenstand (`vitalityCurrent`/`moraleCurrent`) gehört zu den Zustands-Attributen (§ 2, „Ressourcen“).

> **Klärung (beantwortet): „Von was sind diese Attribute abgeleitet – von der Persönlichkeit?“**
>
> **Ja – aber nur für die Traits dieser Tabelle.** Die Attribute der Abschnitte 1–3 haben andere Wurzeln (Klassen-Profil, Zustand, Fortschritt); die Persönlichkeit **ersetzt** sie nicht, sie **moduliert** sie. Die Ableitung läuft strikt in eine Richtung:

```text
Enneagramm-Profil  (gespeichert: personalityId)   +   Charakter-ID (gespeichert: StaffData.id)
        │   PersonalityTraits.forProfile(profile, charId)   ← rein, deterministisch, kein RNG
        ▼
Traits 0–100  (aggressiveness, riskTolerance, tacticalComplexity, helpfulness, thriftiness,
               vitality, morale, shadiness)   ← Profilwert ± 1W20 (Varianz, § 4.1)
        │   Modifikator = f(Trait)                   ← Stützwerte in EconomyBalance
        ▼
Modifikatoren  ── multiplikativ/additiv auf ──▶  Basis-Attribut (Klassen-Profil)
                                                 │
                                                 ▼
                                    effektiver Wert   ← berechnet, NICHT gespeichert
```

> **Hinweis:** Während eines **Stress-/Ruhe-Overrides** (§ 6) tritt `personalityOverrideId` an die Stelle von `personalityId` – alle Traits werden aus dem Override-Profil neu gerechnet; die Varianz bleibt an der `charId` hängen.

| Attributgruppe | Wurzel (Quelle) | Persönlichkeit ist Quelle? |
|---|---|---|
| Basis-Attribute (Abschnitt 1) | Klassen-Profil (`EconomyBalance.<class>Stats`) | **nein** – nur Modifikator |
| Zustands-Attribute: `status` + V3-Anker (Abschnitt 2) | Gefecht/Rettungswurf/Heilung (V3) | **nein** (Regelwerk § 4.3/§ 4.5) |
| Fortschritts-Attribute (Abschnitt 3) | Gefecht (XP, Belohnung, Beute) | **nein** |
| `aggressiveness`, `riskTolerance`, `tacticalComplexity`, `thriftiness` | **Persönlichkeit** (+ Varianz) | **ja** – aus dem Profil |
| `helpfulness` | **Persönlichkeit × Arzt-Qualität** (+ Varianz) | **ja** – Profil + `medicQualitySpecs` |
| `vitality`, `morale` (Basiswert) | **Persönlichkeit** (+ Varianz) | **ja** – aus dem Profil |
| `shadiness` | **Persönlichkeit** (+ Varianz) | **ja** – nur Datenmodell, Wirkung offen |
| `vitalityCurrent`, `moraleCurrent` (Stand) | Tick (Tag/Einsatz) + Wochenauffüllung | **indirekt** – Basiswert stammt aus der Persönlichkeit |
| `personality` selbst | Erzeugung/Auswahl, 1× festgeschrieben | – (Wurzel) |

### 4.1 Varianz (individuelle Ausprägung)

„Niemand ist gleich“: Die Traits werden **je Charakter** bestimmt und können um **±1W20** vom Profilwert abweichen. **Entscheidung (Variante A):** Die Varianz wird **deterministisch aus der Charakter-ID** abgeleitet – **keine** zusätzlichen Speicherfelder.

```text
Trait(charId, trait)   = clamp( TraitBasis(personality) + Varianz(charId, trait), 0, 100 )
Varianz(charId, trait) = (CRC32('$charId:$trait') % 41) − 20        // −20 … +20 ≡ ±1W20
```

- **Gleiche Char-ID ⇒ gleiche Traits** – plattform- und laufunabhängig; Tests brauchen keinen injizierten `Random`.
- Die Varianz wird **nicht** persistiert: Sie ist wie die Basis-Traits eine reine Funktion von `personalityId` **und** `StaffData.id`. „Einmal festgeschrieben“ garantiert die stabile `id` (Z4).
- Stützwerte in `EconomyBalance`: `personalityVarianceRange` (±20) und `personalityVarianceModulo` (41).
- **Abgrenzung:** Die **Proben** in § 6 (Stress/Ruhe) sind bewusst zufallsbehaftet (injizierbarer `Random`, `rollD100`); sie ändern nichts an dieser Formel, sondern ersetzen zeitweise nur das Profil (Override).

**Ableitungsformel (deterministisch, ohne Fuzzy):** analog zum bestehenden `ObjectTeamMedic._enneagramScore` (`(index + 1) × step % modulo`, `object_team_medic.dart:145–149`) – ein Profil erzeugt **immer** dieselben **Basis**-Traits (kein RNG, keine Plattformabhängigkeit); zusätzlich fließt die Charakter-ID als Varianz-Seed ein. Alle Stützwerte liegen in `EconomyBalance` (z. B. `personalityTraitStep`, `personalityTraitOffset`, `personalityVarianceRange`). Deshalb werden Traits **nicht** persistiert: Sie sind eine reine Funktion von `personalityId` und `StaffData.id`.

### 5. Wirkungsmatrix (Vorschlag)

Alle Persönlichkeits-Effekte sind **Modifikatoren** (additiv/multiplikativ auf ein Basis-Attribut) – **niemals** absolute Ersetzungen. Der effektive Wert entsteht zur Laufzeit und wird **nicht** persistiert (Abschnitt 4). **Ausnahme:** Die Ressourcenstände `vitalityCurrent`/`moraleCurrent` (§ 2, „Ressourcen“) sind **Zustand** und werden persistiert.

| System | Eingang | Größe | Ort |
|---|---|---|---|
| Gefecht | `aggressiveness`, `riskTolerance`, `tacticalComplexity` | Prozent-Modifikatoren (Muster: `combatModifierPercentPerHit`) | `ObjectToken`/Kampflogik |
| Wirtschaft (Attraktivität/Kapazität) | Persönlichkeiten des Personals | Zuschlag auf `attractivenessOf`/`capacityOf` | `GameClockService` |
| Wochenkosten (Arzt) | `thriftiness` | Lohnfaktor auf `costPerWeek` | `EconomyService.weeklyMedicCost` |
| Host-KI | alle Traits | Fuzzy-Auswertung – endlich **verdrahtet** | `HostPersonality` |
| Heilung | – | **kein Einfluss** (Regelwerk § 4.3/§ 4.5) | – |
| Wirtschaft (Ressourcen) | `vitality`, `morale` (Stand) | sinkt je Tag/Einsatz, Wochen-Refill auf den Basiswert | `GameClockService` (Tages-/Wochentick) |
| Illegale Mittel (später) | `shadiness` | **keine Wirkung** – nur Datenmodell, Wirkung offen | – |
| Stress & Ruhe | W100-Proben je Verlust | **vollständiger, temporärer Persönlichkeitswechsel** (Override), Dauerstaffel je Über-/Unterschreitung | `StressService` (§ 6), `GameClockService` |
| Erschöpfungs-Malus | `vitalityZeroSinceAt`/`moraleZeroSinceAt` | −5 pp je Nulltag auf **alle** W100-Zielwerte (beide auf 0: −10 pp/Tag), kein Cap, Reset im Wochen-Refill | `EconomyService`/`StressService` (§ 6) |

### 6. Stress & Ruhe (Persönlichkeitswechsel)

Würfel-/Ereignis-Mechanik auf Basis der Ressourcen (§ 2, „Ressourcen“). Jeder **Verlust** von `vitalityCurrent` oder `moraleCurrent` (Tages-Tick oder Gefechtseinsatz) löst eine **Probe** aus.

**Probe (W100, `EconomyService.rollD100`, injizierbarer `Random`):**

- Pro Verlust-Ereignis wird **je Ressource einmal** gewürfelt; Zielzahl = der aktuelle Wert der Ressource **nach** dem Sinken.
- `Wurf ≤ Wert` → alles gut.
- `Wurf > Wert` → **Stress**: Überwurf = `Wurf − Wert`.
- `Wurf ≤ Wert − ruheMargin` (kritische Unterschreitung) → **Ruhe**: Unterschreitung = `Wert − Wurf`.
- Catch-up über mehrere Tage: **ein Proben-Paar pro Staffel** auf die Endwerte – keine Wurf-Flut nach Offline-Zeit, identisch zur idempotenten Heilung (V3).

**Temporärer Persönlichkeitswechsel:**

Stress und Ruhe bewirken beide einen **vollständigen, zeitlich begrenzten Persönlichkeitswechsel** nach der Enneagramm-Tabelle. Das Wechsel-Profil wird **zufällig** aus `EnneagramProfile.all` gewählt (injizierbarer `Random`, P7). Während des Wechsels gilt:

- Effektives Profil = `personalityOverrideId` statt `personalityId` (die §-4.1-Formel rechnet mit dem Override-Profil; die Varianz bleibt an der `charId`).
- Ein **neuer Override ersetzt** einen laufenden (keine Addition); nach Ablauf (`personalityOverrideUntil`) gilt wieder das Grundprofil.

**Dauerstaffel (Stützwerte in `EconomyBalance`):**

| Über-/Unterschreitung | Dauer |
|---|---|
| 1–5 | 1W6 „Einzelticke“ (je `einzelTickUnit` = 3 h) |
| 6–15 | 1W4 Tage |
| 16–25 | 1W4 Wochen |
| > 25 | 1W4 Monate |

Der „Einzeltick“ ist eine **Zeiteinheit** (`EconomyBalance.einzelTickUnit = 3 h`) und **kein** eigener Wirtschafts-Tick: Die Dauer wird als Timestamp (`personalityOverrideUntil`) gerechnet und übersteht App-Pausen (Catch-up, V8).

**Erschöpfungs-Malus ab 0 (kumulativ):**

Sinkt eine Ressource auf **0**, greift ein **universeller Würfel-Malus**: Er gilt für **alle W100-Zielwerte** – Angriff/Verteidigung, Rettungswürfe, Arzt-Proben und die Proben aus diesem Abschnitt. Würfe ohne Zielwert (Dauer-Würfe 1W4/1W6) bleiben unberührt.

- **Kumulativ pro Tag:** jeder Tag, an dem mindestens eine Ressource auf 0 steht, erhöht den Malus um `EconomyBalance.resourceZeroMalusPerDay = 5` Prozentpunkte; stehen **beide** auf 0, ist die Erhöhung verdoppelt (`EconomyBalance.resourceZeroMalusPerDayBoth = 10`).
- **Kein Cap:** Der **Wochen-Refill** setzt die Ressourcen auf ihren Basiswert und damit den Malus auf 0 zurück – die natürliche Obergrenze liegt bei ~35 pp (eine Ressource) bzw. ~70 pp (beide).
- **Zustand (persistiert):** `vitalityZeroSinceAt`/`moraleZeroSinceAt` werden gesetzt, sobald die Ressource 0 erreicht, und beim Wochen-Refill gelöscht; die Nulltage werden daraus **abgeleitet** (nicht fortgeschrieben) ⇒ idempotenter Catch-up (V3-Muster).

```text
malusPercent(t) = Summe je Tag im aktuellen Wochenfenster {  5 pp, genau eine Ressource = 0
                                                            10 pp, beide Ressourcen = 0 }
effektiver W100-Zielwert = clamp( Zielwert − malusPercent(t), 0, 100 )
```

- **Kante (bewusst):** Fällt eine Probe auf den Zielwert **0**, ist jeder W100-Wurf größer ⇒ **garantiert Stress** („Erreichen von 0 = Kollaps“).
- `status`/`woundValue` bleiben unverändert (V3).

## Datenmodell & Persistenz

1. **Neues Modell** `lib/models/personality.dart`: `EnneagramProfile` (verschoben aus `object_host.dart`), `PersonalityTraits` (Werte-DTO) sowie die reine Ableitungsfunktion `PersonalityTraits.forProfile(profile, charId)` (§ 4.1, inkl. Varianz).
2. **`StaffData`/`MedicData`:** neues Feld `personalityId` (stabiler, sprachunabhängiger Schlüssel statt Anzeigename) und **neues `StaffData.id`** (CRC32 aus Name + Erzeugungszeitpunkt, analog `ObjectTeamMedic`). `enneagramProfileName` bleibt als Lese-Fallback für Alt-Stände erhalten. Zusätzlich (additiv): die Ressourcenstände `vitalityCurrent`, `moraleCurrent` und der Refill-Anker `lastResourceRefillAt` (§ 2, „Ressourcen“).
3. **Migration (V6-Muster):** fehlendes `personalityId` wird deterministisch aus dem Namen abgeleitet (CRC32-basiert) und **einmalig festgeschrieben** – kein Neu-Würfeln bei jedem Laden; Schema-Version erhöhen.
4. **Toleranz:** Unbekannte Profil-ID → Fallback `EnneagramProfile.all.first`, aber sichtbar über `CrashLogger.warn` statt still (V6-Prinzip).
5. **Varianz (Entscheidung Variante A):** Für die ±1W20-Abweichung entstehen **keine** neuen Persistenzfelder. Die Varianz wird deterministisch aus `StaffData.id` + Trait-Name berechnet (§ 4.1); persistiert werden nur `id` und `personalityId`.
6. **Stress-/Ruhe-Override (§ 6):** drei weitere Zustandsfelder in `StaffData` – `personalityOverrideId` (int), `personalityOverrideUntil` (`DateTime?`), `personalityOverrideCause` (`stress`/`ruhe`). Additive, tolerante Migration (V6); Ablauf/Ersetzen über Timestamps (`emergencyShotAt`-Muster, V3) ⇒ catch-up-fähig.
7. **Erschöpfungs-Anker (§ 6):** `vitalityZeroSinceAt`/`moraleZeroSinceAt` (`DateTime?`) in `StaffData` – additiv/tolerant (V6), Löschung im Wochen-Refill. Die Malus-Höhe wird daraus **berechnet** (kein gespeicherter Zähler, Z3-Prinzip); die Stützwerte (`resourceZeroMalusPerDay = 5`, `resourceZeroMalusPerDayBoth = 10`) stehen in `EconomyBalance`.

## Umsetzungsschritte

| Phase | Inhalt | Dateien |
|---|---|---|
| 1 | Modell extrahieren (`EnneagramProfile` verschieben, Host angepasst) – **ohne** Verhaltensänderung | `lib/models/personality.dart`, `object_host.dart`, `object_team_medic.dart` |
| 2 | Persönlichkeit + Traits inkl. Varianz (§ 4.1) für Charaktere; stabile `id`; Ressourcenstände + Persistenz/Migration | `lib/models/personality.dart`, `object_apprentice.dart`, `profile_data.dart`, `object_profile.dart` |
| 3 | Wirkung im Management (Attraktivität, Kapazität, Arzt-Lohn) + Ressourcen-Sink im Tages-Tick und Wochen-Refill | `game_clock_service.dart`, `economy_service.dart`, `economy_balance.dart` |
| 4 | Stress & Ruhe (§ 6): Proben, Dauerstaffel, Override-Persistenz, kumulativer Erschöpfungs-Malus (Anker + `EconomyBalance`) | `lib/services/stress_service.dart` (neu), `game_clock_service.dart`, `economy_service.dart`, `economy_balance.dart`, `profile_data.dart` |
| 5 | Wirkung im Gefecht (Modifikatoren) | `object_token.dart`, Kampflogik |
| 6 | Host-Fuzzy verdrahten (`ruleBase` behalten und auswerten) | `object_host.dart` |
| 7 | UI & l10n (Persönlichkeit + Attribute in der Detailansicht, Erklärtexte, Stress-/Ruhe-Countdown) | `screen_character_detail.dart`, `screen_hire_and_fire.dart`, `app_de.arb`/`app_en.arb` |

**Neue l10n-Strings (DE/EN, Phase 7):** `stressCountdown` („Stress bis …“), `ruheCountdown` („Ruhe bis …“), `overrideEnded` („Zurück zur Grundpersönlichkeit“), `resourceZeroMalus` („Erschöpft: Abzüge aktiv“).

## Tests

- `test/personality_test.dart` (neu): Ableitung ist deterministisch und liegt für alle 12 Profile in 0–100; **Varianz:** gleiche Char-ID ⇒ gleiche Traits, Abweichung nur im Bereich ±20 und nach Clamp in 0–100 (12 Profile × Test-IDs).
- `test/profile_data_test.dart` (erweitern): (De-)Serialisierung von `personalityId`/`id` sowie `vitalityCurrent`/`moraleCurrent`/`lastResourceRefillAt` und `personalityOverrideId`/`personalityOverrideUntil`/`personalityOverrideCause`; Alt-Stand ohne Felder → Defaults, kein Datenverlust; Fremd-ID → Fallback + Warnung.
- `test/resource_state_test.dart` (neu): Tages-Sink ist idempotent (Catch-up ohne Doppelbuchung), Wochen-Refill setzt auf den Trait-Basiswert, Einsatz-Sink greift nach dem Gefecht, Clamp 0–100; der Erschöpfungs-Malus wächst **kumulativ** je Nulltag (beide auf 0 doppelt), ist **ohne Cap** und wird im Wochen-Refill auf 0 zurückgesetzt.
- `test/stress_ruhe_test.dart` (neu): W100-Proben (Überwurf/Ruhe-Marge), Dauerstaffel-Buckets (1W6×3 h … 1W4 Monate), Override ersetzt/läuft ab, Catch-up = genau ein Proben-Paar, deterministisch via injiziertem `Random`/`now`; der Erschöpfungs-Malus wirkt auch auf diese Proben (Zielwert 0 ⇒ garantiert Stress).
- `test/object_team_medic_test.dart` (erweitern): ein injizierter `Random` bestimmt Profil und Qualität (Determinismus, behebt P7).
- `test/balance_sanity_test.dart` (erweitern): Trait-Stützwerte, Modifikator-Grenzen, Dauerstaffel-Buckets (aufsteigend) und Erschöpfungs-Konstanten (`resourceZeroMalusPerDay = 5` < `resourceZeroMalusPerDayBoth = 10`) eingehalten; Heilzeit bleibt persönlichkeitsunabhängig.
- `test/game_clock_service_test.dart` (erweitern): der Persönlichkeitsanteil an der Kapazität verändert das passive Einkommen nachvollziehbar.
- `test/upgrade_line_cook_test.dart` (erweitern): Fortbildung erhält `id` und Persönlichkeit (Identität, V5-F1).

## Abnahmekriterien

- [x] Alle Charaktere (auch nicht gefechtsbereite) besitzen Persönlichkeit **und** den kanonischen Attributsatz.
- [x] Jeder Charakter hat eine **individuelle** Trait-Ausprägung (±1W20), stabil und testbar – deterministisch aus `StaffData.id`, **ohne** zusätzliche Varianz-Speicherfelder (§ 4.1).
- [x] `vitalityCurrent`/`moraleCurrent` sinken pro Tag/Einsatz und werden wöchentlich aufgefüllt, ohne `status`/`woundValue` anzufassen.
- [x] Ein Stress-/Ruhe-Wechsel ist zeitlich begrenzt, persistiert (`personalityOverride…`) und ersetzt bzw. läuft ab; der Catch-up macht genau **ein** Proben-Paar pro Staffel.
- [x] Erreichen von 0 wirkt ausschließlich als **Erschöpfungs-Malus** auf alle W100-Zielwerte (+5 pp je Nulltag, bei beiden auf 0 +10 pp, kein Cap, Reset im Wochen-Refill) – `status`/`woundValue` bleiben unverändert und der Catch-up ist idempotent.
- [x] Persönlichkeit ist über eine **stabile ID** persistiert; ein Ladefehler ändert sie nicht still.
- [x] Traits sind deterministisch, dokumentiert und in `EconomyBalance` justierbar.
- [x] Heilzeit/-qualität bleiben persönlichkeitsunabhängig (`team_rules.md` § 4.3/§ 4.5).
- [x] Host-Fuzzy wird tatsächlich ausgewertet (voll verdrahtet, Phase 6) – statt die Dokumentation zu korrigieren.
- [x] `EnneagramProfile` liegt nicht mehr in `object_host.dart`; Host und Personal nutzen dieselbe Definition.
- [x] `flutter analyze` ohne neue Fehler/Warnungen (14 Info-Lints = Baseline); `flutter test` vollständig grün (280 Tests).

## Risiken

- **Balance-Drift:** Modifikatoren werden gedeckelt (Prozentwerte in `EconomyBalance`) und durch `balance_sanity_test.dart` abgesichert – **einzige bewusste Ausnahme:** der cap-freie Erschöpfungs-Malus (§ 6), der allein über den Wochen-Refill begrenzt wird.
- **Save-Kompatibilität:** Neue Felder nur additiv und tolerant gelesen; `personalityId` wird einmalig migriert (V6).
- **Doppelte Wahrheit:** Trait-Werte dürfen **nicht** zusätzlich in `StaffData` gespeichert werden – sonst droht dieselbe Divergenz wie in V3/V4.
- **Testflakiness:** Persönlichkeitswahl darf nie von einem nicht injizierten `Random` abhängen (P7).
- **Zwei „Health“-Begriffe:** `vitality` (Ressource, 0–100) ≠ `woundValue`/`maxWoundValue` (Kampf-LP) ≠ `teamHealthOf` (abgeleitete Teamgesundheit aus `status`) – im Code strikt getrennt benennen.
- **Catch-up-Idempotenz:** Sinken/Auffüllen wie die Heilung (V3) über einen Anker (`lastResourceRefillAt`) rechnen, nie fortschreiben; sonst bucht jeder Tick erneut.
- **RNG in § 6:** W100-Proben und 1W4/1W6-Würfe sind Zufallsereignisse – nur über injizierten `Random` (P7), sonst werden die Stress-Tests flaky.
- **Override-Doppelbuchung:** Der Override ist **Zustand** (persistiert); die Traits daraus werden gerechnet – niemals beides speichern (Z3-Prinzip).
- **Erschöpfungs-Spirale:** Ohne Cap erreicht der Malus in einer vollen Nullwoche ~35 pp (eine Ressource) bzw. ~70 pp (beide) – bewusst hart; der Wochen-Refill ist die natürliche Grenze. Da ein Wert bei 0 nicht weiter sinkt, entstehen dort keine zusätzlichen §‑6-Proben.

## Offene Punkte

- **Nummerierung:** P9/V9 in `0-Base.md` aufgenommen – **erledigt** (P9 unter „Probleme“, V9 unter „Verbesserungen“).
- **Regelwerk:** `team_rules.md` ergänzt – **erledigt** (neuer Abschnitt 2.6, Vererbungs-Regel in 2.3, Querverweise in 4.2/4.3 und 7).
- **Teamdynamik:** Affinitäten/Konflikte zwischen Persönlichkeiten (Attraktivität, Zufriedenheit) – bewusst ein späterer Schritt.
- **Weitere Klassen:** Sous Chef/Patissier erhalten eigene Klassen-Profile – **bestätigt**, mit der Leitlinie: **alle Gefechtsklassen erben von der Grundklasse `ObjectApprentice`** (kein Parallelmodell, keine eigene Attribut-/Persönlichkeitsstruktur).
- **`shadiness`:** Wirkung (illegale Mittel) noch zu entwerfen – bis dahin nur Datenmodell; keine Umsetzungsphase verdrahtet sie. Der erste Anwendungsfall (Sabotage: passiv Bemerken / aktiv Ausführen) ist in `13_Gegner_Restaurants.md` → „Sabotage“ entworfen.
- **Nomenklatur:** `vitality`/`morale` statt `health`/`mental_health` – **bestätigt** (Kollision mit `woundValue`/`teamHealthOf` vermieden).
- **Erschöpfungs-Malus (Höhe + Kumulation):** je Nulltag `resourceZeroMalusPerDay = 5` pp, beide auf 0 `resourceZeroMalusPerDayBoth = 10` pp; **kein Cap** (Reset im Wochen-Refill) – alles in `EconomyBalance` einstellbar (V7). Die früheren Werte `vitalityZeroCombatMalusPercent`/`moraleZeroEconomyMalusPercent` entfallen.

## Nachtrag: Umsetzung (Phasen 1–7)

Alle sieben Phasen aus „Umsetzungsschritte“ sind umgesetzt; die Validierung lief mit `dart analyze lib test` (14 Info-Lints = Baseline, keine Fehler/Warnungen) und `flutter test` (**280 Tests grün**).

| Phase | Ergebnis |
|---|---|
| 1 | `EnneagramProfile` nach `lib/models/personality.dart` verschoben; Host/Arzt/Personal nutzen dieselbe Definition. |
| 2 | `PersonalityTraits.forProfile(profileId, charId)` (±1W20-Varianz, RNG-frei); `StaffData`/`ObjectApprentice` mit `id`, `personalityId` und Ressourcenfeldern; `kProfileSchemaVersion = 3`; Alt-Daten werden deterministisch migriert; `hireApprentice({random, now})` injizierbar; Fortbildung bewahrt Identität. |
| 3 | Tages-Sink (−5) im Catch-up, Einsatz-Sink (−10) nach dem Gefecht, Wochen-Refill am Block-Ende; Attraktivitäts-Bonus aus der Hilfsbereitschaft; Thriftiness-Lohnfaktor (`weeklyMedicCost(..., [thriftiness = 50])`). |
| 4 | Neuer `StressService` (W100-Proben, Dauerstaffel 1W6×3 h … 1W4 Monate, Null-Anker, Erschöpfungs-Malus); Override-Felder persistiert; Proben je Staffel; Malus wirkt auf Rettungswurf, Arzt-Proben und die Proben selbst. |
| 5 | `personalityAttackValue`/`…DefenseValue`/`…DamageValue`/`…MovementValue` aus den Traits (±15 %); Anwendung im Kampf (`object_player`) und bei der Bewegung (`widget_caretaker`); Erschöpfungs-Malus mindert die W100-Zielwerte. |
| 6 | Host-Fuzzy **voll verdrahtet**: `ruleBase` bleibt in `HostPersonality` erhalten, `evaluate(...)` wertet alle drei Variablen aus; Bias fließt in Initiative und Zombie-Bewegung. |
| 7 | Detailansicht zeigt Persönlichkeit, Ressourcen, Stress-/Ruhe-Countdown und Malus-Badge; Medik-Karte zeigt die Persönlichkeits-Scores; neue l10n-Strings (DE/EN) via `flutter gen-l10n`. |

**Tests (neu):** `test/personality_test.dart` (7), `test/resource_state_test.dart` (6), `test/stress_ruhe_test.dart` (11), `test/personality_combat_test.dart` (3), `test/host_personality_test.dart` (4), `test/screen_character_detail_personality_test.dart` (1); `profile_data_test`, `upgrade_line_cook_test`, `object_team_medic_test` wurden an die neuen Regeln angepasst.

**Weiterhin offen:** `shadiness`-Wirkung (nur Datenmodell) und Teamdynamik (Affinitäten/Konflikte); die Balance-Zahlen (`ruheMargin`, Sink-Werte, Trait-Prozente, Lohn-Spanne) sind Tuning-Werte in `EconomyBalance`.

## Anhang: Belegstellen

- `lib/objects/object_host.dart:22–42` (12 Profile), `:50–62` (`HostPersonality`), `:216–225` (verworfene `ruleBase`)
- `lib/objects/object_team_medic.dart:41,67–74,81,139–183` · `lib/services/economy_balance.dart:93–112,252–270`
- `lib/objects/player_objects/object_apprentice.dart:38–64,94–100` · `object_line_cook.dart:17–23`
- `lib/models/profile_data.dart:128–167,253–278` · `lib/objects/object_profile.dart:753–833,837–862`
- `lib/services/game_clock_service.dart:542–588` (Attraktivität, Zufriedenheit, Kapazität)
- `lib/screens/screen_hire_and_fire.dart:295–308` · `lib/screens/screen_character_detail.dart:117–128`
- `doc/rules/team_rules.md:144,172` · `doc/todo/feat_better_restaurant_management/5_Halbfertige_Features.md` (Nachtrag zu F2)
- `lib/services/economy_balance.dart:49–56` (`weeklyTick`/`dailyTick`, `dailyTick * 7 == weeklyTick`) · `lib/services/game_clock_service.dart:410,501` (`nextDailyTick`, `WeekSettlement`) – Grundlage für Sink/Refill (§ 2, „Ressourcen“)