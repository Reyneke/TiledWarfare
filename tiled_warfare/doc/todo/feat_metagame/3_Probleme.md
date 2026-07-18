# Probleme und Verbesserungen

## 1. Booster-Spritze (Notfall-Spritze) im ScreenRestaurant

**Status:** Die Spritze ist grundsätzlich in der Personal-Liste verfügbar (Zeile 564 in `screen_restaurant.dart`), aber die Sichtbarkeitsbedingung `character.woundValue <= 0` ist wahrscheinlich zu restriktiv.

**Analyse des bestehenden Codes:**
- `emergencyShot()` in `object_team_medic.dart` (Z. 265–283) prüft `if (character.woundValue > 0) return false;`
  → Die Spritze wird also nur bei `woundValue <= 0` (also toten Charakteren) verabreicht.
- Nach `_performSurvivalRolls()` in `object_profile.dart` (Z. 191–241) haben gerettete Charaktere `woundValue = 1` und `status = CharacterStatus.dying`.
- Ein sterbender Charakter (`woundValue = 1`) erfüllt die Button-Bedingung `woundValue <= 0` NICHT.
- Der Button erscheint also NUR bei wirklich toten Charakteren (`woundValue <= 0`), was in der Praxis fast nie vorkommt, da tote Einheiten sofort aus dem Personal entfernt werden.

**Empfohlener Fix:**
- Die Bedingung sollte auch `status == CharacterStatus.dying` berücksichtigen:
  ```dart
  if (hasMedic && (character.woundValue <= 0 || character.status == CharacterStatus.dying))
  ```
- Die `emergencyShot()`-Methode selbst sollte auch auf `status` statt `woundValue` prüfen:
  ```dart
  bool emergencyShot(ObjectToken character) {
    if (character.woundValue > 0 && character.status != CharacterStatus.dying) {
      return false; // Nur bei toten oder sterbenden Charakteren
    }
    character.woundValue = 1;
    character.status = CharacterStatus.ready; // temporär kampffähig
    return true;
  }
  ```

**Umsetzung:** ✅ `screen_restaurant.dart` (Z. 565–568: Button-Bedingung erweitert) + `object_team_medic.dart` (Z. 265–293: `emergencyShot()` aktualisiert)

---

## 2. Teamarzt-Optionen im ScreenCharacterDetail

**Status:** Implementiert. `ScreenCharacterDetail` hat jetzt eine `_buildMedicActions()`-Methode, die zwischen Header und XP-Balken eine Aktionsleiste mit "Behandeln"- und "Notfall-Spritze"-Buttons anzeigt, falls ein Teamarzt angestellt ist.

**Empfohlene Position:** Die Arzt-Buttons sollten zwischen dem Header (Bild + Stats) und dem XP-Balken platziert werden, als eine Aktionsleiste.

**Erforderliche Änderungen:**
- `ScreenCharacterDetail` muss Zugriff auf `ObjectProfile` erhalten (entweder via Konstruktor-Parameter oder via Singleton).
- Zwei Aktions-Buttons für den Teamarzt einfügen:
  - "Behandeln" (`treatCharacter`) – wenn Charakter verletzt ist
  - "Notfall-Spritze" (`emergencyShot`) – wenn Charakter stirbt/sterbend ist
- Buttons nur anzeigen, wenn ein Teamarzt angestellt ist.

**Umsetzung:** ✅ Siehe `screen_character_detail.dart`

---

## 3. Matchstatistik wird nicht aktualisiert

**Status:** **Bestätigt – Bug.** Die Match-Historie (`matchHistory` in `ObjectApprentice`) wird NIEMALS befüllt. Es gibt keinen Code, der `matchHistory.add()` aufruft. Die Datenstruktur und Serialisierung existiert, aber die Historie bleibt immer leer.

**Betroffene Stellen:**
- `ObjectApprentice.matchHistory` (Z. 46) – wird initialisiert, aber nie befüllt
- `ObjectProfile.syncUnitsAfterBattle()` (Z. 252–266) – sollte Match-Records hinzufügen, tut es aber nicht
- `ObjectProfile._performSurvivalRolls()` (Z. 191–241) – kümmert sich nur um Überleben, nicht um Match-Historie

**Empfohlener Fix:**
- In `ObjectProfile` eine Methode hinzufügen, die nach einem Gefecht die Match-Historie für alle beteiligten Charaktere aktualisiert:
  ```dart
  void addMatchRecord({
    required List<ObjectApprentice> participants,
    required String opponentName,
    required MatchResult result,
    required Map<String, int> kills,
    required Map<String, int> deaths,
  }) {
    for (final character in participants) {
      character.matchHistory.add(MatchRecord(
        date: DateTime.now(),
        opponentName: opponentName,
        result: result,
        kills: kills[character.name] ?? 0,
        deaths: deaths[character.name] ?? 0,
      ));
    }
  }
  ```
- Diese Methode muss nach jedem Gefecht vom Haupt-Screen (z. B. `ScreenMain`) aufgerufen werden.

**Umsetzung:** ✅ Siehe `object_profile.dart` (neue Methode `addMatchRecordsForBattle`) + Integration in `screen_main.dart` (nach Gefechtsende)

---

## Zusammenfassung der Änderungen

| # | Problem | Datei(en) | Änderung |
|---|---------|-----------|----------|
| 1a | Spritzen-Button zu restriktiv | `screen_restaurant.dart` | Button-Bedingung erweitern für `status == dying` |
| 1b | `emergencyShot()` prüft nur `woundValue` | `object_team_medic.dart` | Auch `status` prüfen und auf `ready` setzen |
| 2 | Teamarzt-Buttons fehlen in Detailansicht | `screen_character_detail.dart` | Arzt-Buttons zwischen Header und XP-Balken einfügen |
| 3 | Match-Historie wird nie befüllt | `object_profile.dart` + `screen_main.dart` | Neue Methode zum Hinzufügen von Match-Records + Aufruf nach Gefecht |