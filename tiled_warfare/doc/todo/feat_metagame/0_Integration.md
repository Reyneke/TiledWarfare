# TODO: Code-Dokumentation und Regelkonformität prüfen

> **Kontext:** Nach Einführung von Teamarzt und neuer Teamverwaltung.
> **Erstellt:** 2026-07-12

Aufgrund der kürzlich vorgenommenen Codeänderungen (Teamarzt-Funktionalität, überarbeitete Teamverwaltung)
müssen folgende Nacharbeiten durchgeführt werden:

1. **Dokumentation** – Codedokumentation auf Vollständigkeit und Aktualität prüfen.
2. **Code-Review** – Sicherstellen, dass alle Änderungen korrekt eingebaut wurden.
3. **Regelkonformität** – Prüfen, ob der Code dem unter `doc/rules/` festgelegten Regelwerk entspricht.
4. **Vollständigkeit** – Sicherstellen, dass alle abhängigen Updates (Imports, Konfiguration, Tests)
   konsistent eingepflegt sind.

---

## Arbeitspakete

### 1. 📖 Codedokumentation

- [x] `doc/`-API- oder Funktionsbeschreibungen zu „Teamarzt" ergänzen / aktualisieren
  → `object_team_medic.dart`: Vollständige Doc-Kommentare für Klasse, Methoden und Felder
  → `object_apprentice.dart`: XP-Level-System, CharacterStatus dokumentiert
  → `object_token.dart`: Jedes Feld mit combat_rules.md-Referenz dokumentiert
  → `object_profile.dart`: Rettungswurf-Logik mit Regel-Verweisen dokumentiert
- [x] Neue Parameter, Rückgabewerte und Seiteneffekte dokumentieren
- [ ] `README.md` (falls nötig) auf geänderte Architektur anpassen

### 2. ✅ Code-Review – Korrektheit der Änderungen

- [x] **Bugfix: XP-Level-Up-System** (object_apprentice.earnXP)
  → Alte Logik: `currentXPValue = (currentXPValue + xp) % (levelValue * 1000)` verlor XP bei Multi-Level-Up
  → Neue Logik: `currentXPValue += xp; levelsGained = currentXPValue ~/ threshold`
  → Korrekt: Überschüssige XP bleiben erhalten, mehrere Level-Up möglich

- [x] **Bugfix: Teamarzt-Kosten inkonsistent** (object_team_medic Konstruktor)
  → Alte Logik: `quality` und `costPerWeek` nutzten separate Random-Werte
  → Neue Logik: `late int costPerWeek` im Konstruktor-Rumpf gesetzt; `_computeWeeklyCost` nutzt `this.quality`

- [x] **Bugfix: treatCharacter heilte falsch** (object_team_medic)
  → Alte Logik: Heilt nur `woundValue`, ignoriert `CharacterStatus`
  → Neue Logik: Parameter-Typ auf `ObjectApprentice` geändert; heilt `status` in korrekter Reihenfolge (dying→injured→hurt→reeling→ready)

- [x] Integration der Teamverwaltung prüfen (Datenfluss, State-Management)
- [x] Randfälle berücksichtigt? → Ja (leeres Team, dying-Status in selectTeamForBattle, woundValue > 0 Prüfungen)
- [x] Keine toten Codepfade / ungenutzte Imports hinterlassen

### 3. ⚖️ Regelkonformität (`doc/rules/`)

- [x] Code gegen jede Regel in `doc/rules/` abgleichen
  → **combat_rules.md**: Vollständig in `object_player.dart` implementiert (Initiative, Nahkampf, Fernkampf, Patzer, kritische Treffer, Münzwurf)
  → **team_rules.md** Abschnitt 3.1 (XP-System): Bugfix implementiert (s.o.)
  → **team_rules.md** Abschnitt 4.1 (CharacterStatus): Vollständig in `object_apprentice.dart` abgebildet
  → **team_rules.md** Abschnitt 4.2 (Rettungswurf): Neu in `object_profile._performSurvivalRolls()` implementiert
  → **team_rules.md** Abschnitt 4.3 (Heilung): `object_team_medic.treatCharacter()` und `effectiveHealTime` implementiert
  → **team_rules.md** Abschnitt 4.5 (Teamarzt): Vollständig in `object_team_medic.dart` implementiert
- [x] Verstöße dokumentieren – keine Verstöße mehr
- [ ] Ggf. Regeln ergänzen – kein Bedarf (aktueller Code deckt alle Regeln ab)

### 4. 🔄 Vollständigkeit der Updates

- [x] Modelle / Datenklassen auf neue Felder prüfen
  → `MedicData` in `profile_data.dart`: Vollständig (id, name, quality, costPerWeek, enneagramProfileName)
  → `StaffData` in `profile_data.dart`: status-Feld vorhanden
- [x] Serialisierung / Persistenz aktualisiert
  → `ObjectProfile.toProfileData()` und `loadFromData()`: Beide inkludieren `medics` und `staff` mit Status
- [x] UI-Komponenten auf neue Datenstrukturen angepasst
  → `screen_hire_and_fire.dart`: Teamarzt-Anstellung mit Qualität/Kosten/Persönlichkeit korrekt implementiert
- [x] Post-Battle-Integration (Rettungswürfe) in `object_profile.dart` implementiert:
  → `_performSurvivalRolls()`: W100-Rettungswurf mit Level/Defense/Medic-Boni
  → Teamarzt-Wiederbelebung gegen Bezahlung (200 €)
  → Tote Einheiten werden endgültig entfernt

---

## Definition of Done

Ein Arbeitspaket gilt als abgeschlossen, wenn:

- alle Sub-Aufhaken abgehakt sind,
- die Änderungen in einem Commit zusammengefasst wurden,
- und ein zweites Teammitglied (oder ein automatisierter Check) die Korrektheit bestätigt hat.
