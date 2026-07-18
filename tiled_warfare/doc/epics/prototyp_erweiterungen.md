# Epics: Prototyp-Erweiterungen

Dieses Dokument fasst Funktionen zusammen, die für den Prototypen geplant,
aber noch nicht implementiert sind. Jeder Eintrag kann in ein eigenes Issue
oder eine User Story umgewandelt werden.

---

## 🏃 Escape / Rückzug aus Kampf

**Aktueller Stand:** Keine Möglichkeit, einen laufenden Kampf zu verlassen (außer App-Schließen).

**Gewünscht:**
- Button oder Aktion "Rückzug" während des Kampfes
- Rückzug kostet: Alle eigenen Einheiten erleiden `woundValue += 10` (Rückzug-Verletzung)
- Rückzug zählt als Niederlage für den Spieler (keine XP)
- Nach Rückzug: Zurück zum Restaurant-Bildschirm

**Akzeptanzkriterien:**
- [ ] Rückzug-Button im Kampf sichtbar
- [ ] Bestätigungsdialog ("Wirklich zurückziehen?")
- [ ] Straf-Erhöhung von Wound-Value
- [ ] Navigation zum Ergebnis-Bildschirm mit `playerWon = false`
- [ ] Keine XP-Vergabe

---

## 🗺️ Mehrere Karten

**Aktueller Stand:** Nur eine Karte (`Street Battle`) in `screen_restaurant.dart` hartcodiert.

**Gewünscht:**
- Konfigurierbare Kartenliste (z. B. `assets/maps/maps.json`)
- Jede Karte hat: Name, TMX-Pfad, Vorschaubild, Beschreibung, empfohlenes Level
- Karten werden dynamisch aus dem Dateisystem geladen
- Auswahl-UI im Restaurant-Screen

**Akzeptanzkriterien:**
- [ ] `maps.json` definiert 3+ Karten
- [ ] Karten können ohne Code-Änderung hinzugefügt werden
- [ ] Karten-Auswahl zeigt Vorschaubild + Name + Level-Empfehlung
- [ ] Gegner-Typen pro Karte konfigurierbar

---

## 📖 Tutorial / Anleitung

**Aktueller Stand:** Keine Einführung für neue Spieler.

**Gewünscht:**
- Tutorial-Modus beim ersten Spielstart
- Schritt-für-Schritt: Token bewegen → Angreifen → Runde beenden
- Overlay-Markierungen auf der UI
- Überspringbar ("Tutorial überspringen")

**Akzeptanzkriterien:**
- [ ] Tutorial wird nur beim ersten Start angezeigt
- [ ] 4+ Schritte (Bewegung, Angriff, Heilung, Rundenende)
- [ ] Tooltip-Overlays auf relevanten UI-Elementen
- [ ] "Überspringen"-Button
- [ ] L10n-fähig (DE/EN)

---

## 💎 Beute / Belohnungssystem

**Aktueller Stand:** Nach Kampfsieg gibt es keine Items oder Gold-Belohnungen.

**Gewünscht:**
- Nach Sieg: Zufällige Belohnung (Gold, Items, Crafting-Material)
- Items beeinflussen Kampfwerte (Angriff +1, Verteidigung +2, etc.)
- Inventar pro Charakter
- Items können im Restaurant ausgerüstet werden

**Akzeptanzkriterien:**
- [ ] Belohnungspool mit 5+ verschiedenen Items
- [ ] Items haben Seltenheitsstufen (Common/Rare/Epic)
- [ ] Item-Ausrüstung im Character-Detail-Screen
- [ ] Items erhöhen Kampfwerte
- [ ] Items werden persistent gespeichert

---

## ✅ Prioritäten-Matrix

| Funktion | Aufwand | Wert für Prototyp | Empfehlung |
|----------|---------|-------------------|------------|
| Escape/Rückzug | Gering | Mittel | ✅ Nächstes Sprint |
| Mehrere Karten | Mittel | Hoch | ✅ Nach Escape |
| Tutorial | Mittel | Mittel | ⏳ Nach Karten |
| Beute | Hoch | Hoch | ⏳ Nach Tutorial |

---

## 🔗 Verknüpfte Issues

- `/doc/todo/7_erster_Prototyp.md` – Übergeordnetes Prototyp-Todo
- `/lib/screens/screen_battle_result.dart` – Ergebnis-Bildschirm (bereits implementiert)
- `/lib/screens/screen_main.dart` – Kampf-Screen
- `/lib/screens/screen_restaurant.dart` – Restaurant-UI mit Karten-Auswahl