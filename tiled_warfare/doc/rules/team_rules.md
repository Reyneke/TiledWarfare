//TODO Diese Notizen überarbeiten und sinnvoll ergänzen.
Um das "Your Guys"-Prinzip aufzubauen, wird dem Spieler die Chance gegeben, sich ein Team aus Spielercharakteren aufzubauen und mit diesem in die Schlacht zu ziehen.

Dafür benötigt es einige Regeln zur Verwaltung des Teams. Diese sollen hier nun aufgeführt werden.

---

## 1. Die Bedeutung des Wortes "Team"

Da das Spiel im Restaurant-Genre spielt und sich Charaktere an dem internationalen Brigade-System orientieren (siehe: [Brigade System](https://en.wikipedia.org/wiki/Brigade_system)), besitzt der Spieler natürlich kein "Team", sondern ein **Restaurant**. Dieses kann er frei benennen und über einen Picker ein Bild hochladen, welches lokal gespeichert wird.

---

## 2. Aufbau des Restaurants

### 2.1 Der Spielercharakter

Der Spieler tritt als Restaurantbesitzer auf und kann sich selbst einen Profilnamen vergeben.

### 2.2 Budget & Wirtschaft

Ihm steht von Anfang an ein **Startbudget** zur Verfügung. Dieses Budget wird in Euro gehandhabt.

| Regel | Beschreibung |
|-------|-------------|
| Startbudget | Wird zu Spielbeginn festgelegt (z. B. 10.000 €) |
| Negativgrenze | Das Budget kann bis zum **doppelten Startwert ins Negative** gehen (z. B. −20.000 €) |
| Negativzinsen | Solange das Budget negativ ist, fallen **pro Gefecht** und **bei jeder Wochenabrechnung** (V8) Negativzinsen an (10 % auf den negativen Bestand) |
| Permadeath | Wird der doppelte Startwert im Negativen überschritten, lösen die Investoren das Restaurant auf – das Spiel endet dauerhaft. Der Spieler muss ein neues Restaurant erstellen |

**Einnahmequellen (implementiert, V2):**
- **Gefechtsbelohnung:** Basisprämie (Sieg höher als Niederlage) **plus** `moneyValue` der besiegten Gegner (`ObjectToken.moneyValue`).
- **Passives Einkommen** des Restaurants zwischen den Gefechten (Fuzzy-Inferenz, § 8 des Feature-Dokuments): aus **Attraktivität** (Stadtteil-Prestige + Personalzahl), **Kundenzufriedenheit** (Teamgesundheit + letztes Gefechtsergebnis) und **Kapazität** (Ø `moneyValue` des Personals) → Kunden/Woche × €/Kunde. **Ohne Personal entsteht kein Einkommen.**
- Alle Beträge/Sätze stehen zentral in `EconomyBalance` (V7).

**Ausgaben:**
- Anheuerung neuer Lehrlinge (einmalig)
- Fortbildungskosten (Lehrling → Line Cook, einmalig)
- Wiederbelebung durch den Teamarzt (einmalig, pro wiederholtem Rettungswurf)
- **Laufend (wöchentlich):** Teamarzt-Kosten (`costPerWeek`), Unterhalt der Restauranterweiterungen
- Negativzinsen bei verschuldetem Budget

**Zeitsystem (V8):** Abgerechnet wird im **Wochentick** (1 Tick = 1 Echtzeitwoche); verpasste Wochen werden beim App-Start bzw. Restaurant-Wechsel nachgeholt (Catch-up). Reihenfolge je Abrechnung: **passives Einkommen → Teamarzt-Kosten → Erweiterungs-Unterhalt → Negativzinsen → Bankrott-Check**.

### 2.3 Charakterklassen & Brigade-Rollen

Der Spieler kann Charaktere verschiedener Klassen anheuern und weiterentwickeln. Die Klassen orientieren sich an der klassischen Küchenbrigade:

| Klasse | Dart-Datei | Voraussetzung | Beschreibung |
|--------|-----------|---------------|--------------|
| **Lehrling (Apprentice)** | `object_apprentice.dart` | Sofort verfügbar | Einstiegsklasse, geringe Stats, günstig. Wird direkt angeworben |
| **Line Cook** | `object_line_cook.dart` | Fortbildung aus Lehrling (alle 5 Level) | Verbesserte Stats, teurer, stärker im Kampf |
| *(Weitere Klassen folgen)* | – | – | Z. B. Sous Chef, Chef de Partie, Patissier |

**Wichtig:** Der Spieler kann **nur** Lehrlinge direkt anheuern. Höhere Klassen werden durch Fortbildung freigeschaltet.

### 2.4 Anheuerung (Rekrutierung)

- Der Spieler kann jederzeit zwischen Gefechten neue Lehrlinge anheuern
- Jeder Lehrling kostet eine festgelegte Summe aus dem Budget
- Die Namen werden passend zur **Küche des Restaurants** über den Zufallsgenerator erzeugt: `RandomNames(<Zone>)` mit Mapping Küche → Zone. **Italienisch** → `Zone.italy` (Default; Alt-Spielstände) · **Japanisch** → `Zone.japan` · **Chinesisch** → `Zone.china` · **Deutsch** → `Zone.germany` · **Kanadisch** → `Zone.canada` · **Mexikanisch** → `Zone.spain` (die Bibliothek hat kein `Zone.mexico`).
- Der Spieler kann beliebig viele Charaktere besitzen, muss aber vor dem Gefecht auswählen, welche er mitnimmt

### 2.5 Kündigung & Entlassung

- Der Spieler kann jederzeit Charaktere entlassen (entfernt aus dem Team)
- Entlassene Charaktere sind unwiderruflich verloren
- Es gibt keine Rückerstattung des Anheuerungspreises bei Entlassung

---

## 3. Charakter-Progression

### 3.1 Erfahrungspunkte (XP)

Jeder Charakter sammelt Erfahrungspunkte (`currentXPValue`) durch:
- Teilnahme an Gefechten
- Besiegen von Gegnern (`xpValue` des Gegners wird gutgeschrieben)
- Überleben eines Gefechts (Bonus-XP)

**Level-System (aus dem Code):**
```
Levelaufstieg erfolgt, sobald currentXPValue ≥ levelValue × 1000
Nach Level-Up: currentXPValue = currentXPValue % (levelValue × 1000)
```

### 3.2 Level-Up-Effekte

Bei einem Levelaufstieg erhält der Charakter Verbesserungen. Vorschlag für zukünftige Implementierung:

| Level | Effekt |
|-------|--------|
| Jedes Level | Leichte Erhöhung von `attackValue` und `defenseValue` (+5) |
| Alle 5 Level | **Fortbildung** verfügbar – ermöglicht Aufstieg in die nächste Klasse (z. B. Line Cook) |

### 3.3 Fortbildung

- Alle 5 Level kann ein Charakter zur Fortbildung geschickt werden
- Fortbildung kostet Geld (deutlich teurer als Neuanheuerung)
- Nach erfolgreicher Fortbildung wird der Charakter durch eine Instanz der höheren Klasse ersetzt
- Der Charakter behält seine bisherigen Stats und addiert die Basis-Stats der neuen Klasse

---

## 4. Charakter-Status & Verletzungen

### 4.1 Status-System

Jeder Charakter hat einen `CharacterStatus` (siehe `object_apprentice.dart`):

| Status | Bedeutung |
|--------|-----------|
| `ready` | Charakter ist einsatzbereit |
| `reeling` | Leicht benommen, kleine Abzüge auf alle Werte (−5) |
| `hurt` | Verletzt, moderate Abzüge (−10) |
| `afraid` | Verängstigt, Abzüge auf Angriff (−15) |
| `injured` | Schwer verletzt, starke Abzüge (−20) |
| `dying` | Tödlich verletzt, kann nicht am Gefecht teilnehmen |
| `dead` | Endgültig tot, Charakter ist verloren |
| `overkilled` | Endgültig und vollständig vernichtet |

### 4.2 Verletzungs-Mechanik (Gefecht)

Wenn ein Charakter auf der Map stirbt (`woundValue ≤ 0`):

1. Er scheidet dauerhaft aus dem **laufenden Gefecht** aus
2. Nach dem Gefecht wird ein **W100-Wurf** durchgeführt:
   - **Erfolg** (Wurf ≤ sinnvoller Zielwert): Der Charakter überlebt, erleidet aber eine Verletzung
   - **Misserfolg**: Der Charakter stirbt endgültig (Status → `dead`)
3. Der Zielwert für den W100 hängt von den Umständen ab (Vorschlag):
   - Basis: 50
   - +10 pro Level des Charakters
   - +5 pro `defenseValue` über 30
   - −10 bei `overkilled`-Schaden (doppelter Schaden)

**Optionale Verbesserung durch Teamarzt (siehe 4.5):** Ist ein Teamarzt angeheuert, erhöht sich der Rettungswurf-Zielwert um seinen Qualitätsbonus (**+10 / +20 / +30**, `MedicQuality.survivalBonus`) zusätzlich zu den obigen Boni. Ein einmalig gescheiterter Rettungswurf pro Charakter und Gefecht kann gegen Bezahlung wiederholt werden.

### 4.3 Heilung

- Die Heilung läuft in **Echtzeit** und wird beim App-Start bzw. Restaurant-Wechsel nachgeholt (Catch-up, V8).
- Gemessen wird ab dem **Beginn der aktuellen Verletzung** (`injuryStartedAt`; bei Alt-Spielständen ab `restaurant.lastSeenAt`).
- Heilungsreihenfolge: `dying → injured → hurt → afraid → reeling → ready`
- **Ohne Teamarzt** dauert jede Stufe **einen Echtzeit-Tag** (24 h). Ein `dying`-Charakter braucht also 5 Tage bis `ready`.
- Die Zeit pro Stufe ist **deterministisch**: Sie hängt allein von der Qualität des angestellten Arztes ab (`MedicQuality.healTimePerStage`), nicht von Persönlichkeit/Fuzzy-Werten (`effectiveHealTime` entfällt).

**Optionale Beschleunigung durch Teamarzt (siehe 4.5):** Ist ein Teamarzt angeheuert, heilt der Charakter je nach Qualität **eine Stufe pro 6 h / 3 h / 1 h** statt pro Tag (`MedicQuality.healTimePerStage`). Ein `dying`-Charakter ist so in 30 h / 15 h / 5 h wieder voll einsatzbereit.

### 4.4 Kampf mit Verletzungen

Sollte ein verletztes Teammitglied wieder ins Gefecht ziehen, bevor es den Status `ready` erreicht hat, treten folgende **Nachteile** auf:

| Status | Nachteile im Gefecht |
|--------|---------------------|
| `reeling` | −5 auf `attackValue` und `defenseValue` |
| `hurt` | −10 auf alle Werte |
| `afraid` | −15 auf `attackValue`, darf nicht angreifen, solange ein Gegner benachbart ist |
| `injured` | −20 auf alle Werte, maximale Bewegung halbiert |
| `dying` | Darf **nicht** am Gefecht teilnehmen |

`afraid` ist ein regulärer Verletzungsstatus: Er entsteht im Gefecht und wird gemäß 4.3 in der Kette `hurt → afraid → reeling → ready` wieder **ausgeheilt**.

### 4.5 Teamarzt (Optionale Erweiterung)

Der Spieler kann zwischen Gefechten einen Teamarzt anheuern, der die Überlebenschancen und Heilung des Teams verbessert (siehe Verweise in 4.2 und 4.3).

**Anheuerung & Kosten:**
- Teamärzte kommen in verschiedenen **Qualitätsstufen** (**niedrig / mittel / hoch**) mit Kostenmultiplikator **1.0 / 2.0 / 3.0** – höhere Stufen verbessern Rettungswurf-Bonus und Heilungsrate weiter.
- Die Wochenkosten berechnen sich als `medicBaseCostPerWeek (500 €) × Qualitätsmultiplikator × (1 + Teamgröße × 0,05)` – **Qualität und Teamgröße** fließen ein (größere/dienstältere Teams kosten mehr). Alle Werte stehen in `EconomyBalance` (V7).
- Die Bezahlung erfolgt **pro Echtzeitwoche** (`costPerWeek`) und wird im **Wochentick (V8)** abgebucht. Die erste Abbuchung erfolgt erst zum nächsten Wochentick (kein anteiliger Einzug).

**Effekte:**
- Heilung: eine Verletzungsstufe pro `MedicQuality.healTimePerStage` – **6 h / 3 h / 1 h** je nach Qualität (statt 24 h pro Stufe ohne Arzt). Die Zeit ist deterministisch und unabhängig von Persönlichkeit/Fuzzy-Werten.
- Rettungswurf: **+10 / +20 / +30** auf den Zielwert je nach Qualität (`MedicQuality.survivalBonus`), einmalige Wiederholung eines gescheiterten Wurfs pro Charakter und Gefecht.

**Notfall-Spritze:**
Ist ein Teamarzt angeheuert, verabreicht er einem Charakter, der das Gefecht als **`dying`** beendet, automatisch unmittelbar nach dem Rettungswurf eine Spritze – **keine manuelle Aktion** des Spielers. Sie macht ihn **sofort** wieder voll einsatzfähig, ist jedoch teuer (einmalige Zusatzkosten, `EconomyBalance.emergencyShotCost`) und schiebt den Schaden nur **temporär** auf:
- Nach **einem Echtzeit-Tag** kehren die so unterdrückten Verletzungen zurück.
- Hinzu kommen alle Verletzungen, die der Charakter in der Zwischenzeit erlitten hat (es gewinnt der schwerere Status gemäß der Heilungskette aus 4.3).
- Eine normale Genesung (4.3) läuft während der Wirkungsdauer zwar weiter, heilt aber zu langsam, um den Rückfall abzufangen.
- Der Rückfall zählt als **neuer Verletzungsbeginn** (`injuryStartedAt`) für die weitere Heilung.

---

## 5. Gefechtsvorbereitung

### 5.1 Team-Auswahl

Vor jedem Gefecht:
1. Der Spieler sieht alle seine Charaktere mit aktuellem Status
2. Per **Checkbox** wählt er aus, welche Kräfte er mit in das Gefecht nehmen will
3. Charaktere im Status `dying` können nicht ausgewählt werden
4. Charaktere mit Verletzung erhalten eine Warnung über die anstehenden Nachteile

### 5.2 Antreten zum Gefecht

Nach der Auswahl kann der Spieler auf **"Ins Gefecht"** klicken und das eigentliche Spiel auf der Map beginnt (siehe `combat_rules.md` für die Kampfregeln).

---

## 6. Permadeath & Spielende

### 6.1 Charakter-Tod

- Stirbt ein Charakter im Gefecht, folgt der W100-Wurf (siehe 4.2)
- Bei Misserfolg ist der Charakter endgültig tot
- Tote Charaktere werden aus der Liste entfernt

### 6.2 Restaurant-Auflösung

- Das Budget kann bis zum doppelten Startwert ins Negative gehen
- Wird diese Grenze überschritten, endet das Spiel dauerhaft (Permadeath)
- Alle Charaktere gehen verloren
- Der Spieler muss ein neues Restaurant erstellen

### 6.3 Neustart

Bei einem Neustart:
- Budget wird zurückgesetzt
- Alle Charaktere sind neu anzuheuern
- Der Spieler kann einen neuen Restaurant-Namen wählen
- Vorherige Fortschritte sind verloren

---

## 7. Zusätzliche Hinweise

- Dieses Regelwerk sollte mit den tatsächlichen Implementierungen in `object_apprentice.dart`, `object_line_cook.dart`, `object_token.dart` und `object_player.dart` abgeglichen werden
- **Aktuelles Implementierungs-Detail:** `ObjectPlayer` verwaltet derzeit nur `lineCookList`. Die Anheuerung von Lehrlingen und deren Verwaltung muss noch in den Code integriert werden