# Manuelle Testfälle – Erster Prototyp

Dieses Dokument beschreibt die manuellen Testabläufe für den ersten Prototyp.
Jeder Testfall wird Schritt für Schritt beschrieben und kann von einem Tester durchgeführt werden.

---

## ✅ Übersicht

| # | Testfall | Status |
|---|----------|--------|
| 1 | App starten | ⬜ |
| 2 | Karte laden und anzeigen | ⬜ |
| 3 | Token auf der Karte bewegen | ⬜ |
| 4 | Kampf initiieren (Token berührt Gegner) | ⬜ |
| 5 | Angriff ausführen | ⬜ |
| 6 | Runde beenden | ⬜ |
| 7 | Teamverwaltung öffnen | ⬜ |
| 8 | Charakter zum Team hinzufügen | ⬜ |
| 9 | Charakter aus Team entfernen | ⬜ |
| 10 | Spielstand speichern | ⬜ |
| 11 | Spielstand laden | ⬜ |
| 12 | App schließen und neu starten (Persistenz) | ⬜ |

---

## 🧪 Testfall 1: App starten

**Vorbedingung:** App ist installiert (EXE/APK).

| Schritt | Aktion | Erwartetes Ergebnis |
|---------|--------|---------------------|
| 1.1 | App ausführen | App startet ohne Fehlermeldung |
| 1.2 | Warten bis UI geladen | Startbildschirm wird angezeigt |
| 1.3 | Prüfen: Keine Konsolenfehler | Keine sichtbaren Fehler |

---

## 🧪 Testfall 2: Karte laden und anzeigen

**Vorbedingung:** Test 1 bestanden.

| Schritt | Aktion | Erwartetes Ergebnis |
|---------|--------|---------------------|
| 2.1 | Auf "Spiel starten" klicken | Karte wird geladen |
| 2.2 | Warten bis Karte angezeigt | Hexagonale Karte ist sichtbar |
| 2.3 | Mausrad/Scrollen | Karte zoomt rein/raus |
| 2.4 | Karte ziehen | Karte scrollt in alle Richtungen |
| 2.5 | Prüfen: Keine Grafikfehler | Alle Tiles korrekt dargestellt |

---

## 🧪 Testfall 3: Token bewegen

**Vorbedingung:** Test 2 bestanden, Spieler-Token sichtbar.

| Schritt | Aktion | Erwartetes Ergebnis |
|---------|--------|---------------------|
| 3.1 | Auf Spieler-Token klicken | Token wird ausgewählt |
| 3.2 | Bewegungsfelder prüfen | Mögliche Felder werden markiert |
| 3.3 | Auf markiertes Feld klicken | Token bewegt sich dorthin |
| 3.4 | Auf nicht-markiertes Feld klicken | Token bewegt sich nicht |
| 3.5 | Mehrere Züge ausführen | Bewegung funktioniert wiederholt |

---

## 🧪 Testfall 4: Kampf initiieren

**Vorbedingung:** Test 3 bestanden, Gegner-Token in Reichweite.

| Schritt | Aktion | Erwartetes Ergebnis |
|---------|--------|---------------------|
| 4.1 | Spieler-Token neben Gegner bewegen | Position stimmt |
| 4.2 | Auf Gegner-Token klicken | Kampf wird gestartet |
| 4.3 | Kampf-UI prüfen | Kampfbildschirm/Overlay erscheint |
| 4.4 | Beteiligte Token werden angezeigt | Spieler + Gegner sichtbar |

---

## 🧪 Testfall 5: Angriff ausführen

**Vorbedingung:** Test 4 bestanden, Kampf läuft.

| Schritt | Aktion | Erwartetes Ergebnis |
|---------|--------|---------------------|
| 5.1 | Angriffsoption auswählen | Angriff wird ausgeführt |
| 5.2 | Schadensanzeige prüfen | Schaden wird korrekt berechnet |
| 5.3 | HP Veränderung prüfen | Ziel verliert HP |
| 5.4 | Kritischer Treffer/Patzer | Sonderfälle funktionieren |
| 5.5 | Kampfergebnis prüfen | Sieg/Niederlage korrekt |

---

## 🧪 Testfall 6: Runde beenden

**Vorbedingung:** Kampf läuft oder Spielzug gemacht.

| Schritt | Aktion | Erwartetes Ergebnis |
|---------|--------|---------------------|
| 6.1 | "Runde beenden" klicken | Runde wechselt |
| 6.2 | Gegner-Reihenfolge prüfen | Gegner führen Aktionen aus |
| 6.3 | Eigener Zug beginnt | Spieler kann wieder agieren |

---

## 🧪 Testfall 7: Teamverwaltung öffnen

**Vorbedingung:** App läuft.

| Schritt | Aktion | Erwartetes Ergebnis |
|---------|--------|---------------------|
| 7.1 | Teamverwaltung öffnen | Übersicht über aktuelle Teammitglieder |
| 7.2 | Details prüfen | Name, Status, HP, XP werden angezeigt |

---

## 🧪 Testfall 8: Charakter zum Team hinzufügen

**Vorbedingung:** Test 7 bestanden.

| Schritt | Aktion | Erwartetes Ergebnis |
|---------|--------|---------------------|
| 8.1 | "Hire" oder "Hinzufügen" klicken | Charakter-Auswahl erscheint |
| 8.2 | Charakter auswählen | Charakter wird zum Team hinzugefügt |
| 8.3 | Team-Liste prüfen | Neuer Charakter sichtbar |

---

## 🧪 Testfall 9: Charakter aus Team entfernen

**Vorbedingung:** Test 8 bestanden, Team hat Mitglieder.

| Schritt | Aktion | Erwartetes Ergebnis |
|---------|--------|---------------------|
| 9.1 | Charakter auswählen | Detailansicht öffnet |
| 9.2 | "Entfernen"/"Fire" klicken | Charakter wird entfernt |
| 9.3 | Bestätigung prüfen | Charakter nicht mehr im Team |

---

## 🧪 Testfall 10: Spielstand speichern

**Vorbedingung:** Spiel läuft, Team vorhanden.

| Schritt | Aktion | Erwartetes Ergebnis |
|---------|--------|---------------------|
| 10.1 | Spiel speichern | Speicherbestätigung erscheint |
| 10.2 | Speicherort prüfen | Datei existiert |

---

## 🧪 Testfall 11: Spielstand laden

**Vorbedingung:** Test 10 bestanden, gespeicherter Stand vorhanden.

| Schritt | Aktion | Erwartetes Ergebnis |
|---------|--------|---------------------|
| 11.1 | App schließen und neu starten | App startet |
| 11.2 | "Spiel laden" klicken | Letzter Spielstand wird geladen |
| 11.3 | Team-Zustand prüfen | Team ist wie vor dem Speichern |
| 11.4 | Spielposition prüfen | Karte und Positionen wie gespeichert |

---

## 🧪 Testfall 12: App schließen und neu starten

**Vorbedingung:** Beliebig.

| Schritt | Aktion | Erwartetes Ergebnis |
|---------|--------|---------------------|
| 12.1 | App normal schließen | Kein Absturz |
| 12.2 | App erneut starten | Sauberer Start |
| 12.3 | Wiederholen (2×) | Konsistentes Verhalten |

---

## Fehlerprotokoll

Bei jedem Fehler während des Testens bitte folgende Informationen notieren:

```
Datum:        [TT.MM.JJJJ]
Tester:       [Name]
Testfall #:   [1-12]
Schritt:      [Schritt-Nr.]
Fehler:       [Beschreibung]
Screenshot:   [Ja/Nein] → Datei: screenshots/fehler_XX.png
Logs:         [Anbei]
```

Fehler bitte als GitHub Issue melden: https://github.com/Reyneke/TiledWarfare/issues