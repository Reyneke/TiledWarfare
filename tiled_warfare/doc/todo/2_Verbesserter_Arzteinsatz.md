# Verbesserter Ärztedienst

## 1. Teamarzt-Funktionen im Restaurant-Bildschirm integrieren

**Ziel:** Der Teamarzt (`ObjectTeamMedic`) soll seine Heilungsfähigkeiten direkt im `ScreenRestaurant` anbieten können.

**Umsetzung:**
- In der Personal-Liste von `ScreenRestaurant` sollen für **verletzte Charaktere** (`status != ready`) entsprechende Aktions-Buttons eingeblendet werden.
- Diese Buttons rufen die Methoden des Teamarztes auf:
  - `treatCharacter()` – heilt eine Verletzungsstufe
  - `emergencyShot()` – (optional) Notfall-Spritze für temporäre Kampffähigkeit
- Falls der Spieler keinen Teamarzt angeheuert hat, werden keine Buttons angezeigt (bzw. die Buttons bleiben ausgegraut mit Hinweis).
- Die visuelle Darstellung soll den aktuellen Heilungsfortschritt und den Verletzungsstatus widerspiegeln.

**Bestehende Ressourcen:**
- `lib/objects/object_team_medic.dart` – vollständige Logik für Teamarzt (Heilung, Kosten, Persönlichkeit)
- `lib/screens/screen_restaurant.dart` – bestehender Bildschirm mit Personal-Liste

---

## 2. ScreenCharacterDetail – Charakter-Detailbildschirm

**Ziel:** Ein neuer Bildschirm (`ScreenCharacterDetail`), der beim Antippen eines Charakter-Eintrags in der Personal-Liste geöffnet wird und detaillierte Informationen anzeigt.

**Aufruf:**
- Wird aufgerufen, wenn der Spieler auf das Listenelement eines Charakters in `ScreenRestaurant` klickt.
- Erhält das entsprechende `ObjectApprentice` (bzw. `ObjectToken`) als Parameter.

**Layout (vertikal scrollend):**

```
┌─────────────────────────────────┐
│  ┌──────────┐  ┌──────────────┐ │
│  │          │  │  Statistiken  │ │
│  │  Bild    │  │  • Name       │ │
│  │  des     │  │  • Level      │ │
│  │  Charak- │  │  • Status     │ │
│  │  ters    │  │  • LP/Wunden  │ │
│  │          │  │  • K/D-Ratio  │ │
│  └──────────┘  │  • Matches    │ │
│                │    (S/U/N)    │ │
│                └──────────────┘ │
├─────────────────────────────────┤
│  Match-Historie (Tabelle)       │
│  ┌──────┬──────┬──────┬──────┐ │
│  │ Datum│ Gegn.│ Erg. │ K/D  │ │
│  ├──────┼──────┼──────┼──────┤ │
│  │ ...  │ ...  │ ...  │ ...  │ │
│  └──────┴──────┴──────┴──────┘ │
└─────────────────────────────────┘
```

**Details:**
- **Oben links:** Bild des Charakters (aus `character.imagePath`)
- **Oben rechts:** Charakterstatistiken und Informationen:
  - Rang ("Apprerentice") und Name
  - Aktueller Verletzungszustand (`CharacterStatus`)
  - Lebenspunkte / Wundstufen (`woundValue`)
  - Kampfwerte: Angriff, Verteidigung, Bewegung, Schaden, Reichweite
  - Kill/Death-Ratio (sofern Match-Logs vorhanden)
  - Gewonnene / verlorene / unentschiedene Matches (aus Match-Historie)
  Mittig: 
  - Level
  - vorhandene XP, XP bis zur nächsten Stufe als Balkengrafik
- **Mittig/unten:** Individuelle Match-Historie des Charakters in tabellarischer Form:
  - Spalten: Datum, Gegner, Ergebnis (Sieg/Niederlage/Unentschieden), K/D, besondere Ereignisse
  - Quelle: `MatchLog`-Einträge aus dem Spielverlauf

**Abhängigkeiten:**
- Neues Datenmodell für Match-Historie (z. B. `MatchLog`-Einträge pro Charakter) – muss ggf. ergänzt werden.
- `ObjectApprentice` / `ObjectToken` muss um Historie erweitert werden, falls nicht vorhanden.

---

## 3. Technische Hinweise (Refactoring & Architektur)

3.1 **Zuständigkeiten trennen:**
   - `ScreenRestaurant` sollte nur für die Anzeige der Personal-Liste und die Gefechtsvorbereitung zuständig sein.
   - Die Arzt-Funktionen sollten in **separate Widgets** ausgelagert werden (z. B. `WidgetMedicActions`) und nur bei vorhandenem Teamarzt eingeblendet werden.
   - `ScreenCharacterDetail` sollte ein reines Anzeige-Widget sein, das die Daten eines übergebenen Charakters darstellt.

3.2 **Datenhaltung für Match-Historie:**
   - Ein neues Modell `MatchRecord` (oder `MatchLogEntry`) wäre sinnvoll:
     ```dart
     class MatchRecord {
       final DateTime date;
       final String opponentName;
       final MatchResult result; // win / loss / draw
       final int kills;
       final int deaths;
       final String? notes;
     }
     ```
   - Dieses könnte als Liste in `ObjectApprentice` oder in `ObjectProfile` je Charakter gespeichert werden.
   - Serialisierung via `ObjectProfile.saveToStorage()` erweitern.

3.3 **Navigation:**
   - `ScreenCharacterDetail` benötigt den Charakter als Konstruktor-Parameter (z. B. `ObjectApprentice`).
   - Aufruf in `ScreenRestaurant` über einen `onTap`-Handler auf dem `ListTile`:
     ```dart
     onTap: () => Navigator.push(
       context,
       MaterialPageRoute(
         builder: (_) => ScreenCharacterDetail(character: character),
       ),
     ),
     ```

3.4 **Status der Implementierung:**
   - [ ] `screen_character_detail.dart` – derzeit nur `Placeholder` – muss komplett implementiert werden
   - [ ] Teamarzt-Buttons in `screen_restaurant.dart` – noch nicht vorhanden
   - [ ] Match-Historie-Datenmodell – noch nicht vorhanden

---

## 4. Code-Review: Gefundene Bugs und Verbesserungspotenzial

Die folgenden Probleme wurden bei der Codeanalyse der bestehenden Dateien identifiziert und sollten vor oder während der Umsetzung der Punkte 1–3 behoben werden.

### 4.1 Kritische Bugs (müssen gefixt werden)

#### 4.1.1 `ObjectTeamMedic.emergencyShot()` – Invertierte Logik

**Datei:** `lib/objects/object_team_medic.dart`, Zeile 266

```dart
bool emergencyShot(ObjectToken character) {
  if (character.woundValue > 0) {
    // Charakter ist nicht verletzt genug für eine Notfall-Spritze.
    return false;
  }
  // ...
  character.woundValue = 1;
  return true;
}
```

**Problem:** `woundValue > 0` bedeutet **verletzt/angeschlagen** (ein lebender Charakter hat `woundValue >= 1`). Die Methode bricht ab, wenn der Charakter *verletzt* ist – aber genau dann bräuchte man doch die Spritze. Die Notfall-Spritze sollte einen *toten/todesnahen* Charakter (`woundValue <= 0` oder `status == dying`) temporär kampffähig machen.

**Fix:**
```dart
bool emergencyShot(ObjectToken character) {
  // Nur bei todesnahen Charakteren sinnvoll
  if (character.woundValue > 0) {
    return false; // Charakter ist noch nicht schwer genug verletzt
  }
  character.woundValue = 1; // provisorisch kampffähig
  return true;
}
```

#### 4.1.2 `ObjectApprentice.earnXP()` – Falsche Level-Berechnung bei mehreren Stufen

**Datei:** `lib/objects/player_objects/object_appretice.dart`, Zeilen 57–63

```dart
bool earnXP(int xp) {
  currentXPValue += xp;
  final threshold = levelValue * 1000;
  if (currentXPValue < threshold) return false;
  final levelsGained = currentXPValue ~/ threshold;
  levelValue += levelsGained;
  currentXPValue = currentXPValue % threshold;
  return true;
}
```

**Problem:** `threshold` wird **einmal** berechnet (`levelValue * 1000`), dann aber für alle Level-Aufstiege verwendet. Wenn der Charakter z. B. Level 1 ist und 2.500 XP erhält:
- `threshold = 1 * 1000 = 1000`
- `levelsGained = 2500 ~/ 1000 = 2` → steigt auf Level 3 (sollte nur Level 2)
- `currentXPValue = 2500 % 1000 = 500` (verliert 500 XP durch falsche Berechnung)

**Korrekt:** Nach jedem Level-Aufstieg muss die neue Schwelle berechnet werden.

**Fix:**
```dart
bool earnXP(int xp) {
  currentXPValue += xp;
  bool leveledUp = false;
  while (currentXPValue >= levelValue * 1000) {
    currentXPValue -= levelValue * 1000;
    levelValue++;
    leveledUp = true;
  }
  return leveledUp;
}
```

#### 4.1.3 `ObjectTeamMedic` Konstruktor – Doppelte Zufallsgenerierung für ID

**Datei:** `lib/objects/object_team_medic.dart`, Zeilen 121–128

```dart
ObjectTeamMedic({double personalCostMultiplier = 1.0})
    : name = RandomNames(Zone.italy).fullName(),    // 1. Zufallsname
      id = CRC32.compute(                            // id nutzt name, aber...
        '${RandomNames(Zone.italy).fullName()}_...', // 2. NEUER Zufallsname!
      ),
```

**Problem:** Die `id` wird aus einem *anderen* Namen berechnet als `name` speichert. Zwei verschiedene `RandomNames`-Instanzen → zwei verschiedene Zufallsnamen → `id` passt nicht zu `name`.

**Fix:**
```dart
ObjectTeamMedic({double personalCostMultiplier = 1.0})
    : name = RandomNames(Zone.italy).fullName(),
      id = 0, // temporär
      // ...
{
  id = CRC32.compute('$name${DateTime.now().toIso8601String()}');
  // ...
}
```

#### 4.1.4 Tippfehler im Dateinamen `object_appretice.dart`

**Datei:** `lib/objects/player_objects/object_appretice.dart`

**Problem:** `appretice` statt `apprentice`. Dieser Tippfehler durchzieht alle Imports und Import-Pfade. Er führt zu Verwirrung bei der Navigation und erschwert das Refactoring.

**Fix:** Datei umbenennen in `object_apprentice.dart` und alle Imports aktualisieren.

---

### 4.2 Architektur-Probleme (Refactoring empfohlen)

#### 4.2.1 Fuzzy-Logik wird initialisiert aber nie ausgewertet

**Datei:** `lib/objects/object_team_medic.dart`

**Problem:** `_initializeFuzzyRules()` erstellt aufwändige Fuzzy-Regelwerke basierend auf Enneagramm-Profilen, aber `_evaluateHelpfulness()` und `_evaluateTreatmentQuality()` ignorieren diese Regeln komplett:

```dart
int _evaluateHelpfulness() {
  return 50 + (enneagramProfile.name.hashCode % 50);
}

int _evaluateTreatmentQuality() {
  return quality.survivalBonus + (enneagramProfile.name.hashCode % 20);
}
```

**Konsequenz:** Die komplette Fuzzy-Initialisierung (7 Regelsätze, 150+ Zeilen) wird zwar durchgeführt, aber die Ergebnisse fließen nirgendwo ein. Die Evaluierungs-Methoden arbeiten rein mit `hashCode`, was zu inkonsistenten und nicht reproduzierbaren Ergebnissen führt.

**Vorschlag:** Entweder die Fuzzy-Engine tatsächlich nutzen (d. h. die Evaluierung auf Basis der Fuzzy-Regeln durchführen) oder die ganze `_initializeFuzzyRules()`-Methode entfernen und die Logik vereinfachen. Die `hashCode`-basierte Berechnung ist inakzeptabel – `string.hashCode` ist nicht portabel zwischen Runs/Plattformen.

#### 4.2.2 `ScreenRestaurant` – Verletzung des Single Responsibility Principle

**Datei:** `lib/screens/screen_restaurant.dart`

**Problem:** Der Screen macht zu viel:
- Personal-Liste inkl. Checkboxen
- Karten-Auswahl und -Vorschau
- Profilbild-Verwaltung (Image Picker, Datei-IO)
- Theme-Umschaltung
- Budget-Anzeige
- Teamarzt-Aktionen (fehlen noch komplett)

**Vorschlag:** Extraktion in separate Widgets:

| Aktuelle Methode | Sollte extrahiert werden in |
|---|---|
| Personal-Liste (Zeilen 490–549) | `WidgetCharacterList` |
| `_buildMapTile()` (Zeilen 268–342) | `WidgetMapSelector` |
| `_pickImage()` (Zeilen 216–265) | `WidgetProfileImageEditor` |
| Teamarzt-Aktionen (noch nicht vorhanden) | `WidgetMedicActions` |

#### 4.2.3 Fehlende Teamarzt-Integration in `ScreenRestaurant`

**Datei:** `lib/screens/screen_restaurant.dart`, Zeilen 490–549

**Problem:** Die Personal-Liste zeigt nur Checkboxen für Gefechtsbereitschaft – es wird nicht einmal geprüft, ob ein Teamarzt angeheuert wurde. Gemäß Punkt 1 dieses Dokuments müssen Aktions-Buttons für verletzte Charaktere erscheinen.

**Erforderliche Änderung (Beispiel):**
```dart
// In der itemBuilder der Personal-Liste:
final hasMedic = _profile.hiredMedics.isNotEmpty;
final needsTreat = character.status != CharacterStatus.ready;

trailing: Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    if (hasMedic && needsTreat)
      IconButton(
        icon: const Icon(Icons.healing),
        tooltip: 'Teamarzt einsetzen',
        onPressed: () {
          final medic = _profile.hiredMedics.first;
          if (medic.treatCharacter(character)) {
            setState(() {});
            _saveState();
          }
        },
      ),
    if (hasMedic && character.woundValue <= 0)
      IconButton(
        icon: const Icon(Icons.emergency),
        tooltip: 'Notfall-Spritze',
        onPressed: () {
          final medic = _profile.hiredMedics.first;
          if (medic.emergencyShot(character)) {
            setState(() {});
            _saveState();
          }
        },
      ),
    Checkbox(value: isReady, onChanged: canFight ? ... : null),
  ],
),
```

#### 4.2.4 `ScreenCharacterDetail` – nur ein Placeholder

**Datei:** `lib/screens/screen_character_detail.dart`

**Problem:** Nicht implementiert, obwohl dieses Dokument (Punkt 2) ein vollständiges Layout vorgibt und Punkt 3.4 es als offen listet.

**Mindestanforderung:**
```dart
class ScreenCharacterDetail extends StatelessWidget {
  final ObjectApprentice character;

  const ScreenCharacterDetail({super.key, required this.character});

  @override
  Widget build(BuildContext context) {
    // Layout gemäß Punkt 2:
    // - Header: Bild (links) + Statistiken (rechts)
    // - Match-Historie-Tabelle
  }
}
```

---

### 4.3 Design-Probleme (Best Practices)

#### 4.3.1 Singleton-Pattern für `ObjectProfile` – Tight Coupling

**Datei:** `lib/objects/object_profile.dart`, Zeilen 20–25

```dart
class ObjectProfile {
  static final ObjectProfile _instance = ObjectProfile._internal();
  factory ObjectProfile() => _instance;
  ObjectProfile._internal();
```

**Problem:** Das Singleton-Pattern führt dazu, dass alle Widgets direkt darauf zugreifen können. Das macht:
- **Unit-Testing** unmöglich (keine Dependency Injection, kein Mocking)
- **State-Änderungen** schwer nachvollziehbar (jedes Widget kann direkt `_personal` oder `budget` ändern)
- **Keine klaren Datenflüsse** (implizite Abhängigkeiten statt expliziter Parameter)

**Besser:** Dependency Injection via Konstruktor (auch optional für Tests):
```dart
class ScreenRestaurant extends StatefulWidget {
  final ObjectProfile? profile; // optional für Tests/Mocks
  const ScreenRestaurant({super.key, this.profile});
}
```

#### 4.3.2 Mutierbare öffentliche Felder in `ObjectToken`

**Datei:** `lib/objects/object_token.dart`

**Problem:** Sämtliche Felder sind `public` und `mutable`:
```dart
String name;
String imagePath;
int woundValue;
int attackValue;
int defenseValue;
// ...
```

**Besser:** Private Felder mit Gettern und expliziten Settern nur wo nötig, plus `copyWith()` für kontrollierte Änderungen:
```dart
class ObjectToken {
  final String name;
  final String imagePath;
  int _woundValue;
  int get woundValue => _woundValue;
  
  set woundValue(int value) {
    _woundValue = value.clamp(0, 999); // Plausibilitätsprüfung
  }
  
  ObjectToken copyWith({int? woundValue}) {
    return ObjectToken(
      name: name,
      imagePath: imagePath,
      woundValue: woundValue ?? _woundValue,
    );
  }
}
```

#### 4.3.3 Name-basierter Vergleich in `syncUnitsAfterBattle()`

**Datei:** `lib/objects/object_profile.dart`, Zeile 255

```dart
final index = _personal.indexWhere((p) => p.name == survivor.name);
```

**Problem:** Name-basierter Vergleich ist extrem fragil. Bei Namensgleichheit (z. B. zwei zufällig identische `"Apprentice: Mario Rossi"`) wird der falsche Eintrag aktualisiert. Zudem können verschiedene Objekte denselben Namen haben.

**Fix:** Vergleich über Identität:
```dart
final index = _personal.indexWhere((p) => identical(p, survivor));
// ODER: Jede Einheit bekommt eine eindeutige ID (siehe ObjectTeamMedic)
```

#### 4.3.4 Fehlendes `MatchRecord` / Match-Historie-Datenmodell

**Siehe Punkt 3.2** – das Datenmodell muss erstellt werden. Zusätzlich muss `ObjectApprentice` um eine `List<MatchRecord>` erweitert werden, und die Serialisierung in `StaffData` (aus `profile_data.dart`) muss dies berücksichtigen.

#### 4.3.5 Exception-Handling in `_pickImage()`

**Datei:** `lib/screens/screen_restaurant.dart`, Zeile 256

```dart
} catch (_) {
  // Fehler wird komplett geschluckt
}
```

**Fix:** Zumindest loggen:
```dart
} catch (e) {
  debugPrint('Fehler beim Bild-Picking: $e');
}
```

---

### 4.4 Optimierungen & Vereinfachungen

#### 4.4.1 Caching-Mechanismus in `WidgetCaretaker` – Zu komplex

**Datei:** `lib/widgets/widget_caretaker.dart`

Der manuelle Cache mit `_cacheDirty`, `_cachedAllTokens`, `_cachedOccupiedFields`, `_cachedReachableFields` etc. ist fehleranfällig. `_cacheDirty` wird teilweise nicht zurückgesetzt, wenn sich Tokens bewegen oder sterben.

**Alternative:** `ValueNotifier` oder `AnimatedBuilder` für reaktive Updates statt manuellem Cache-Management. Oder zumindest eine einzige `invalidateAllCaches()`-Methode, die alle `_cached*`-Felder auf null setzt.

#### 4.4.2 Maps-Konfiguration aus externer Datei

**Datei:** `lib/screens/screen_restaurant.dart`, Zeilen 113–120

**Problem:** Die Karten-Liste ist hart kodiert:
```dart
final maps = <MapPreviewEntry>[
  MapPreviewEntry(
    mapPath: 'assets/maps/map0',
    title: 'Street Battle',
    previewPath: null,
    tmxPath: 'assets/maps/map0/street_battle.tmx',
  ),
];
// Zukünftige Karten hier hinzufügen:
```

**Vorschlag:** Konfiguration über eine JSON-Datei `assets/maps/maps.json`:
```json
[
  {
    "mapPath": "assets/maps/map0",
    "title": "Street Battle",
    "tmxPath": "assets/maps/map0/street_battle.tmx"
  }
]
```

#### 4.4.3 Enum `CharacterStatus` – Inkonsistente Werte

**Datei:** `lib/objects/player_objects/object_appretice.dart`, Zeile 9

```dart
enum CharacterStatus {ready, reeling, hurt, afraid, injured, dying, dead, overkilled}
```

**Problem:** Das Enum passt nicht zur Heilungsreihenfolge in `ObjectTeamMedic.treatCharacter()` (Zeilen 237–249):
- `dying → injured → hurt → reeling → ready`
- `afraid` und `overkilled`/`dead` werden nie in der Heilung berücksichtigt
- Es gibt keinen klaren "Schweregrad"-Wert (sind `hurt` und `injured` gleich schwer?)

**Vorschlag:** Dem Enum eine `severity`-Eigenschaft geben oder die Reihenfolge der Deklaration als Schweregrad nutzen:
```dart
enum CharacterStatus {
  ready(0),
  reeling(1),
  hurt(2),
  afraid(3),
  injured(4),
  dying(5),
  dead(6),
  overkilled(7);
  
  final int severity;
  const CharacterStatus(this.severity);
}
```

---

## 5. Priorisierte Umsetzungsreihenfolge

| Prio | Issue | Datei(en) | Aufwand |
|------|-------|-----------|---------|
| 🔴 | 4.1.1 `emergencyShot()` invertierte Logik | `object_team_medic.dart:266` | 5 Min |
| 🔴 | 4.1.2 `earnXP()` falsche Level-Berechnung | `object_appretice.dart:57-63` | 10 Min |
| 🔴 | 4.1.3 Doppelte RandomNames + inkonsistente ID | `object_team_medic.dart:121-128` | 5 Min |
| 🟡 | 4.2.3 Teamarzt-Buttons in ScreenRestaurant | `screen_restaurant.dart` | 1 Std |
| 🟡 | 4.2.4 ScreenCharacterDetail implementieren | `screen_character_detail.dart` | 2–3 Std |
| 🟡 | 4.2.1 Fuzzy-Logik: entweder nutzen oder entfernen | `object_team_medic.dart` | 30 Min |
| 🟡 | 4.3.3 Name-basierter Vergleich fixen | `object_profile.dart:255` | 15 Min |
| 🟡 | 4.1.4 Tippfehler `appretice` → `apprentice` | Dateiname + Imports | 10 Min |
| 🟡 | 4.3.4 MatchRecord-Datenmodell + Serialisierung | Neues File + `profile_data.dart` | 1 Std |
| 🟢 | 4.3.5 Exception schlucken in `_pickImage()` | `screen_restaurant.dart:256` | 5 Min |
| 🟢 | 4.4.3 CharacterStatus um severity erweitern | `object_appretice.dart` | 15 Min |
| 🔵 | 4.2.2 SRP: ScreenRestaurant aufteilen | `screen_restaurant.dart` | 2–4 Std |
| 🔵 | 4.3.1 Singleton-Pattern auflösen | `object_profile.dart` | 2 Std |
| 🔵 | 4.3.2 Mutable Felder in ObjectToken | `object_token.dart` | 1 Std |
| 🔵 | 4.4.1 Caching in WidgetCaretaker vereinfachen | `widget_caretaker.dart` | 1 Std |
| ⚪ | 4.4.2 Maps-Konfiguration aus JSON | `screen_restaurant.dart` | 30 Min |