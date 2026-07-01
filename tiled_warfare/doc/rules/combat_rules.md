# Kampfregeln für die Hexfeld-Gefechtssimulation

## 1. Grundlegendes Würfelsystem

- Jeder Wurf im Spiel verwendet einen **W100** (Würfel mit 100 Seiten, Ergebnis zwischen 1 und 100).
- Ein Wurf gilt als **Erfolg**, wenn das gewürfelte Ergebnis **kleiner oder gleich** dem geforderten Wert ist (Unterwürfeln).
- Ein Wurf gilt als **Patzer**, wenn das Ergebnis **größer als 90** ist (91–100). Ein Patzer hat stets negative Konsequenzen für die patzende Partei.
- Ein Wurf gilt als **kritischer Erfolg**, wenn das Ergebnis **kleiner oder gleich 5** ist (1–5). Ein kritischer Erfolg bringt einen besonderen Vorteil (siehe Angriffe).

---

## 2. Token-Eigenschaften

Jeder Token (Einheit) besitzt folgende relevante Werte:

| Eigenschaft       | Beschreibung                                                                 |
|-------------------|------------------------------------------------------------------------------|
| `attackValue`     | Angriffswert – gibt an, wie gut der Token im Angriff ist (W100-Zielwert).   |
| `defenseValue`    | Verteidigungswert – gibt an, wie gut der Token sich verteidigen kann.       |
| `damageValue`     | Schadenswert – Höhe des Schadens, den der Token bei einem Treffer verursacht.|
| `woundValue`      | Trefferpunkte – Gesundheit des Tokens. Bei 0 oder darunter gilt er als tot. |
| `movementValue`   | Bewegungspunkte – maximale Anzahl an Hex-Feldern, die der Token pro Zug zurücklegen kann. |
| `rangeValue`      | (*optional*) Reichweite für Fernkampf-Angriffe in Hex-Feldern.               |

---

## 3. Bewegung

- Jeder Token kann sich in seinem Zug bis zu **`movementValue` Hex-Felder** weit bewegen.
- Bewegung erfolgt orthogonal oder diagonal zu benachbarten Hex-Feldern (gemäß den Regeln des Hex-Gitters).
- Ein Token kann sich nicht durch Felder bewegen, die von anderen Tokens (egal ob Freund oder Feind) besetzt sind.
- Ein Token kann seine Bewegung vor, zwischen oder nach Aktionen (z. B. Angriffen) aufteilen, sofern die Aktionspunkte dies erlauben.

### Geländeeinfluss (optional)

| Geländetyp  | Bewegungskosten | Effekt auf Verteidigung       |
|-------------|-----------------|-------------------------------|
| Ebene       | 1 Bewegungspunkt pro Feld | Kein Bonus            |
| Wald        | 2 Bewegungspunkte pro Feld | +10 auf defenseValue  |
| Hügel       | 2 Bewegungspunkte pro Feld | +5 auf defenseValue   |
| Fluss       | 3 Bewegungspunkte pro Feld | Kein Bonus            |
| Gebäude/Ruine | 2 Bewegungspunkte pro Feld | +15 auf defenseValue |

---

## 4. Angriffe

### 4.1 Nahkampf-Angriff

Ein Nahkampf-Angriff ist nur auf ein **benachbartes Hex-Feld** möglich (direkt angrenzend).

**Ablauf:**

1. Der Angreifer würfelt mit seinem W100 und versucht, seinen `attackValue` zu unterwürfeln.
2. Der Verteidiger würfelt mit seinem W100 und versucht, seinen `defenseValue` zu unterwürfeln.
3. Es wird verglichen, **um wie viele Punkte** jeder seinen Wert unterwürfelt hat:
   - **Vergleichswert Angreifer** = `attackValue` − gewürfelter Wert (nur bei Erfolg; bei Misserfolg negativ oder 0)
   - **Vergleichswert Verteidiger** = `defenseValue` − gewürfelter Wert (nur bei Erfolg; bei Misserfolg negativ oder 0)

**Ergebnisbestimmung:**

| Bedingung                                                   | Ergebnis                                      |
|-------------------------------------------------------------|-----------------------------------------------|
| Angreifer trifft, Verteidiger verfehlt                      | **Angreifer trifft** → voller Schaden         |
| Angreifer trifft, Verteidiger trifft, Vergleich Angreifer > Verteidiger | **Angreifer trifft** → voller Schaden         |
| Angreifer trifft, Verteidiger trifft, Vergleich Verteidiger > Angreifer | **Angreifer verfehlt** → kein Schaden         |
| Angreifer trifft, Verteidiger trifft, Vergleich gleich      | **Münzwurf** → Siehe 4.3                     |
| Beide verfehlen                                             | **Kein Treffer** → nichts passiert            |
| Angreifer verfehlt, Verteidiger trifft                      | **Angreifer verfehlt** → kein Schaden         |
| **Patzer Angreifer** (Wurf > 90)                            | Angreifer erleidet **automatisch Schaden**     |
| **Patzer Verteidiger** (Wurf > 90)                          | Verteidiger erleidet **automatisch Schaden**   |
| **Beide patzen**                                            | **Beide erleiden Schaden**                     |
| **Kritischer Erfolg Angreifer** (Wurf ≤ 5)                  | **Angreifer trifft** → **doppelter Schaden**   |
| **Kritischer Erfolg Verteidiger** (Wurf ≤ 5)                | Verteidiger weicht aus → **kein Schaden**, Angreifer erleidet halben Schaden (Gegenangriff) |

### 4.2 Fernkampf-Angriff

- Ein Fernkampf-Angriff kann auf ein Ziel in einer Entfernung von **bis zu `rangeValue` Hex-Feldern** erfolgen.
- Die Sichtlinie (Line of Sight) darf nicht durch Hindernisse (Gebäude, dichte Wälder, Hügel) blockiert sein.
- Der `attackValue` im Fernkampf erhält einen **Entfernungsmalus**:
  - Bis 50% der Reichweite: kein Malus
  - 51–75% der Reichweite: −10 auf `attackValue`
  - 76–100% der Reichweite: −20 auf `attackValue`
- Der Verteidiger erhält einen **Deckungsbonus** von +10 auf `defenseValue`, wenn er sich in Wald, hinter einem Hügel oder in einem Gebäude befindet.
- Ansonsten gelten die gleichen Regeln wie beim Nahkampf.

### 4.3 Münzwurf bei Gleichstand

Wenn Angreifer und Verteidiger ihren Wert gleich gut unterwürfelt haben (gleicher Vergleichswert > 0):

1. Es wird erneut mit einem W100 gewürfelt.
2. Zeigt der Wurf ein Ergebnis **über 51%** (d. h. > 51), gewinnt der **Angreifer**.
3. Zeigt der Wurf ein Ergebnis **von 51 oder weniger** (≤ 51), gewinnt der **Verteidiger**.

*(Hinweis: 51% entspricht einem Würfelergebnis von 52–100 für den Angreifer bzw. 1–51 für den Verteidiger.)*

---

## 5. Schaden

- Wenn der Angreifer erfolgreich trifft, wird **`damageValue`** (des Angreifers) von der **`woundValue`** (des Verteidigers) abgezogen.
- **Formel:** `Neue woundValue = Aktuelle woundValue − damageValue`
- Sinkt die `woundValue` dabei **auf oder unter 0**, gilt der Verteidiger als **tot** und sein Token wird **vom Spielbrett entfernt**.
- Bei **patzendem Angreifer** (Wurf > 90) erleidet der Angreifer selbst Schaden in Höhe der **halben `damageValue`** des Verteidigers (aufgerundet).
- Bei **patzendem Verteidiger** (Wurf > 90) erleidet der Verteidiger **doppelten Schaden** (`damageValue × 2`).
- Bei **kritischem Erfolg** des Angreifers (Wurf ≤ 5) wird **doppelter Schaden** verursacht (`damageValue × 2`).
- Bei **kritischem Erfolg** des Verteidigers (Wurf ≤ 5) erleidet der Angreifer **halben Schaden** (entspricht der halben `damageValue` des Verteidigers, aufgerundet), da der Verteidiger einen Gegenangriff ausführt.

---

## 6. Zugsystem / Aktionspunkte

Jeder Token erhält pro Zug **2 Aktionspunkte (AP)**.

| Aktion               | AP-Kosten |
|----------------------|-----------|
| Bewegung (pro Feld)  | 1 AP pro Feld (maximal `movementValue` Felder) |
| Nahkampf-Angriff     | 1 AP      |
| Fernkampf-Angriff    | 1 AP      |
| Nachladen (Fernkampf)| 1 AP      |
| In Deckung gehen     | 1 AP      |
| Spezialfähigkeit     | 2 AP      |

- Ein Token kann seine Aktionen in beliebiger Reihenfolge ausführen und auch unterbrechen (z. B. bewegen → angreifen → weiterbewegen).
- Nicht verbrauchte AP verfallen am Ende des Zuges.

---

## 7. Initiative / Zugreihenfolge

- Zu Beginn jeder Runde wird für jede Seite (Spieler/KI) ein **Initiative-Wurf** mit einem W100 durchgeführt.
- Die Seite mit dem **höheren Ergebnis** beginnt die Runde und darf zuerst alle ihre Tokens aktivieren.
- Bei Gleichstand wird der Münzwurf (4.3) angewendet: Wurf > 51 bedeutet, dass die aktuelle Runde in der gleichen Reihenfolge wie die Vorrunde beginnt.

---

## 8. Niederlage / Spielende

- Ein Spieler gilt als **besiegt**, wenn alle seine Tokens eine `woundValue` ≤ 0 haben (also alle Einheiten tot sind).
- Das Spiel endet sofort, sobald eine Seite keine einsatzfähigen Tokens mehr besitzt.
- Alternativ kann ein Szenario spezifische Siegbedingungen definieren (z. B. Flagge erobern, eine bestimmte Anzahl Runden überleben, einen bestimmten Punkt halten).

---

## 9. Beispiele

### Beispiel 1: Nahkampf

- **Angreifer:** `attackValue = 65`, `damageValue = 12`
- **Verteidiger:** `defenseValue = 50`, `woundValue = 30`

1. Angreifer würfelt: **43** → Erfolg (65 − 43 = 12 Punkte unterwürfelt).
2. Verteidiger würfelt: **61** → Misserfolg (61 > 50, überwürfelt).
3. Ergebnis: Angreifer trifft → Verteidiger erleidet 12 Schaden. Neue `woundValue` = 30 − 12 = **18**.

### Beispiel 2: Patzer

- **Angreifer:** `attackValue = 50`
- **Verteidiger:** `defenseValue = 40`, `damageValue = 8`

1. Angreifer würfelt: **95** → Patzer (> 90).
2. Verteidiger muss nicht würfeln.
3. Ergebnis: Angreifer erleidet automatisch halben Schaden des Verteidigers: 8 / 2 = **4 Schaden** an sich selbst.

### Beispiel 3: Gleichstand mit Münzwurf

- **Angreifer:** `attackValue = 60`, würfelt 30 → 30 Punkte unterwürfelt.
- **Verteidiger:** `defenseValue = 50`, würfelt 20 → 30 Punkte unterwürfelt.

1. Vergleich gleich → Münzwurf.
2. Münzwurf: **67** → 67 > 51 → **Angreifer gewinnt**.
3. Angreifer fügt vollen Schaden zu.

---

## 10. Zusammenfassung der wichtigsten Regeln (Kurzreferenz)

| Situation                                   | Ergebnis                                                |
|---------------------------------------------|---------------------------------------------------------|
| Angreifer trifft besser als Verteidiger     | Angreifer macht Schaden                                 |
| Verteidiger trifft besser als Angreifer     | Angreifer macht keinen Schaden                          |
| Beide treffen gleich gut                    | Münzwurf (W100 > 51 → Angreifer gewinnt)                |
| Beide verfehlen                             | Nichts passiert                                         |
| Angreifer patzt (Wurf > 90)                 | Angreifer erleidet halben Schaden                       |
| Verteidiger patzt (Wurf > 90)               | Verteidiger erleidet doppelten Schaden                  |
| Kritischer Erfolg Angreifer (Wurf ≤ 5)      | Angreifer macht doppelten Schaden                       |
| Kritischer Erfolg Verteidiger (Wurf ≤ 5)    | Verteidiger kontert → Angreifer erleidet halben Schaden |