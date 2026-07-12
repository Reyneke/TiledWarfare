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

- [ ] `doc/`-API- oder Funktionsbeschreibungen zu „Teamarzt" ergänzen / aktualisieren
- [ ] Neue Parameter, Rückgabewerte und Seiteneffekte dokumentieren
- [ ] `README.md` (falls nötig) auf geänderte Architektur anpassen

### 2. ✅ Code-Review – Korrektheit der Änderungen

- [ ] Logik des Teamarztes (Heilung, Einsatzbedingungen) testen
- [ ] Integration der Teamverwaltung prüfen (Datenfluss, State-Management)
- [ ] Randfälle (leere Teams, inaktive Einheiten) berücksichtigt?
- [ ] Keine toten Codepfade / ungenutzte Imports hinterlassen

### 3. ⚖️ Regelkonformität (`doc/rules/`)

- [ ] Code gegen jede Regel in `doc/rules/` abgleichen
- [ ] Verstöße dokumentieren und als Issue / Sub-Task anlegen
- [ ] Ggf. Regeln ergänzen, falls die Neuerungen nicht abgedeckt sind

### 4. 🔄 Vollständigkeit der Updates

- [ ] Modelle / Datenklassen auf neue Felder prüfen
- [ ] Serialisierung / Persistenz (sofern vorhanden) aktualisiert
- [ ] UI-Komponenten auf neue Datenstrukturen angepasst
- [ ] Tests (Unit / Widget / Integration) ergänzt und lauffähig

---

## Definition of Done

Ein Arbeitspaket gilt als abgeschlossen, wenn:

- alle Sub-Aufhaken abgehakt sind,
- die Änderungen in einem Commit zusammengefasst wurden,
- und ein zweites Teammitglied (oder ein automatisierter Check) die Korrektheit bestätigt hat.
