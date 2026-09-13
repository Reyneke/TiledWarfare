# Zustand vereinheitlichen (V4)

Dies ist die Ausarbeitung von **V4 (→ P4)** aus dem Basisdokument (`0-Base.md` – Abschnitt „Probleme“ → P4 sowie „Verbesserungen“ → V4). Sie beschreibt, wie Logo- und Bildzustand auf **eine einzige Quelle der Wahrheit** (`ObjectProfile`) zusammengeführt wird.

Die Grundsatzentscheidungen sind fixiert und werden hier nicht neu verhandelt:

- Der Spielzustand liegt seit **V1** auf der **Restaurant-Ebene**: `RestaurantData` ist der Zustandsträger, `ObjectProfile` hält nur den aktiven Spielstand (inkl. der Referenz `_profileData` als Basis für das Merge in `toProfileData()`).
- Das **Profilbild** (`profileImagePath`) gehört zur Profil-Ebene (Spieler-Avatar, genutzt in `ScreenStart`, `screen_start.dart:640–643`) und bleibt dort. V4 betrifft nur das **Restaurant-Logo** (`logoPath` / `restaurantLogoPath`).
- `ObjectProfile` ist künftig die einzige Quelle für den Kopf-Bildzustand des aktiven Restaurants; das Widget hält **keinen eigenen** Bildzustand.

## Aktueller Stand

Ist-Zustand im Code (Stand: Branch `feat-restaurant-management`).

**Drei Bild-Repräsentationen:**

1. `RestaurantData.logoPath` – die persistierte Wahrheit (`lib/models/profile_data.dart:268`, serialisiert `:329`, gelesen `:349`). Auch `ScreenStart` liest sie direkt für die Spielstand-Kacheln (`screen_start.dart:812–816`).
2. `ObjectProfile.restaurantLogoPath` (`lib/objects/object_profile.dart:52`) – Laufzeit-Mirror des aktiven Spielstands, in `loadFromData` aus `restaurant.logoPath` befüllt (`:474`) und in `toProfileData()` / `activeRestaurantSnapshot()` zurückgeschrieben (`:539` / `:582`).
3. Widget-Kopien `_profileImagePath` / `_hasCustomImage` in `_ScreenRestaurantState` (`lib/screens/screen_restaurant.dart:37–38`) – werden an **vier Stellen** per Hand abgeleitet bzw. gesetzt: `initState` (`:52–58`), `_checkBankruptcy` nach `reset()` (`:87–91`), `_switchRestaurant` (`:189–201`), `_pickImage` (`:340–344`).

**`loadFromData` leitet falsch ab:** `hasCustomImage = data.profileImagePath != null` (`object_profile.dart:452`) – das ist das **Profilbild**, nicht das Restaurant-Logo.

**`reset()` ist bereits vollständig für den Restaurant-Zustand:** `restaurantLogoPath = null` (`:426`) und `hasCustomImage = false` (`:428`) werden gesetzt (zusätzlich Budget = Start, Team/Ärzte geleert, neue aktive Restaurant-ID, neuer Stadtteil). Der Text im Basisdokument („reset setzt das nicht zurück“) ist damit veraltet. Es fehlt jedoch **Testschutz**, und das Widget muss die eigenen Bild-Felder nach Reset/Wechsel weiterhin manuell nachziehen.

**`hasCustomImage` im Singleton ist toter Code:** es existiert kein Leser im gesamten `lib/` – nur die Widget-Kopie `_hasCustomImage` wird gelesen; der Singleton-Wert wird geschrieben, aber nie konsumiert. Die UI leitet das Standardbild stattdessen direkt aus `activeCuisine.tokenImagePath` ab.

**`_pickImage` ist nicht atomar:** die alten `restaurant_*.png` werden gelöscht, bevor das neue Bild sicher geschrieben ist (`:327–336`); schlägt das Schreiben fehl, ist der alte Zustand weg.

**Tests:** `screen_restaurant_test.dart` (Widget-Tests) und `profile_data_test.dart` (Serialisierung) decken das Logo- und `reset()`-Verhalten nicht ab; es gibt keinen Test für die `loadFromData`-Ableitung, für `reset()` oder den Spielstand-Wechsel-Effekt.

## Probleme im Detail

### P1 – Doppelte Buchführung (Widget spiegelt den Singleton)

**Ursache (Belege):** `_profileImagePath` / `_hasCustomImage` (`screen_restaurant.dart:37–38`) duplizieren den Singleton-Zustand; jede Änderung muss an vier Sync-Punkten (`initState`, `_checkBankruptcy`, `_switchRestaurant`, `_pickImage`) nachgezogen werden.

**Auswirkung:** Divergenz zwischen Anzeige und `ObjectProfile` / gespeichertem Zustand ist möglich (z. B. falsches Standardbild nach Logout/Login, altes Logo im nächsten Spielstand nach einem Wechsel, wenn ein Sync-Punkt vergessen wird). Die „Quelle der Wahrheit“ wandert mit jedem Sync-Punkt.

### P2 – `hasCustomImage` wird aus dem falschen Feld abgeleitet

**Ursache (Beleg):** `loadFromData` setzt `hasCustomImage` aus `data.profileImagePath` (Profilbild) statt aus `restaurant.logoPath` (`object_profile.dart:452`).

**Auswirkung:** Ein Profil mit eigenem Profilbild, aber ohne Restaurant-Logo ergibt `hasCustomImage == true`, obwohl die Anzeige das Küchen-Token zeigt. Praktisch aktuell gefahrlos (kein Leser), aber als „Quelle der Wahrheit“ schlicht falsch – bei künftiger Nutzung (Serialisierung, UI-Umbau) divergiert der Wert sofort.

### P3 – Totes Feld `hasCustomImage` im Singleton

**Ursache (Beleg):** kein Leser in `lib/` → der mutable Bool hat keine Bedeutung und lädt zu Missbrauch (wie P2) ein. Besser: abgeleiteter Getter statt mutablem Feld.

### P4 – Widget muss `reset`/Wechsel weiterhin manuell nachziehen

**Ursache (Beleg):** `_checkBankruptcy` (`:87–91`) und `_switchRestaurant` (`:189–201`) setzen die Bild-Felder des Widgets manuell zurück. `reset()` ist bereits korrekt, aber die Widget-Seite ist eine weitere manuelle Sync-Stelle.

**Auswirkung:** Neue Flows (z. B. „Neues Restaurant“ aus `ScreenStart`) bräuchten einen dritten Sync-Punkt; vergessene oder falsch gesetzte Felder → falsches Header-Bild, Phantom-`_hasCustomImage`.

### P5 – Totes Default-Literal und Namens-Asymmetrie (kosmetisch)

- `_profileImagePath = 'assets/images/token/token_cook_basic.png'` (`screen_restaurant.dart:37`) wird in `initState` sofort von `activeCuisine.tokenImagePath` überschrieben – das Literal ist tot.
- `ObjectProfile.restaurantLogoPath` vs. `RestaurantData.logoPath`: zwei Namen für dasselbe Konzept.

### P6 – `_pickImage` nicht atomar (minor)

Alte Dateien werden gelöscht, bevor das neue Bild sicher geschrieben ist (`:327–336`).

## Lösungsansätze

### Ziel (fixierte Entscheidung)

`ObjectProfile` ist die **einzige Quelle** für den Kopf-Bildzustand des aktiven Restaurants; das Widget hält **keinen eigenen** Bildzustand. `hasCustomImage` wird **abgeleiteter** Zustand (Getter auf Basis von `restaurantLogoPath`) statt eines mutablem Felds.

### Schritt 1 – Abgeleitete Getter im Singleton (`lib/objects/object_profile.dart`)

```dart
/// Eigenes Logo vorhanden – abgeleitet aus [restaurantLogoPath] (nicht aus dem
/// Profilbild, P2-Fix).
bool get hasCustomImage =>
    restaurantLogoPath != null && restaurantLogoPath!.isNotEmpty;

/// Kopf-Bild: eigenes Logo, sonst die Küchen-Grafik des Restaurants (§ 9).
String get headerImagePath =>
    hasCustomImage ? restaurantLogoPath! : activeCuisine.tokenImagePath;
```

- Das mutable Feld `bool hasCustomImage` entfällt (kein Leser); die Zuweisungen in `reset()` (`:428`) und `loadFromData` (`:452`) entfallen mit.
- Zeile 452 (`data.profileImagePath != null`) **entfernen** – die Ableitung erfolgt jetzt immer aus `restaurant.logoPath` (`:474`). `profileImagePath` bleibt rein Profil-Ebene.

### Schritt 2 – Widget-Kopien entfernen (`lib/screens/screen_restaurant.dart`)

- `_profileImagePath` / `_hasCustomImage` (`:37–38`) löschen – das tote Literal entfällt mit.
- Die Bild-Sync-Zeilen in `initState` (`:52–58`), `_checkBankruptcy` (`:87–91`), `_switchRestaurant` (`:189–201`) und `_pickImage` (`:340–344`) entfallen; wo ein Neuaufbau nötig ist (`_pickImage`, `_switchRestaurant`, Reset), genügt `setState(() {})`.
- Das Bild-Widget (`:1009–1023`) auf die Getter umstellen:

```dart
child: _profile.hasCustomImage
    ? Image.file(File(_profile.headerImagePath), /* … */)
    : Image.asset(_profile.headerImagePath, /* … */)
```

- Damit hat `headerImagePath` seinen ersten Nutzer – P3 (totes Feld) ist aufgelöst.

### Schritt 3 – `_pickImage` atomar machen (P6)

Zuerst die neue Datei mit `writeAsBytes` schreiben; **erst bei Erfolg** die alten `restaurant_*.png` (außer der neuen Datei) löschen; Fehler-Pfad über `debugPrint`/SnackBar beibehalten.

### Schritt 4 – Tests (neu: `test/profile_logo_state_test.dart` + Widget-Test)

1. `loadFromData` **mit** `logoPath` → `headerImagePath == logoPath`, `hasCustomImage == true`.
2. `loadFromData` **ohne** `logoPath`, aber **mit** `profileImagePath` → `headerImagePath == activeCuisine.tokenImagePath`, `hasCustomImage == false` (Regressions-Test für P2).
3. `toProfileData()`-Roundtrip erhält `logoPath`.
4. `reset()` → `restaurantLogoPath == null`, `hasCustomImage == false`, Budget = Start, Team/Ärzte leer, neue `activeRestaurantId`; andere Spielstände bleiben im Merge erhalten.
5. (`screen_restaurant_test.dart`) Nach Spielstand-Wechsel zeigt der Header das Logo des Ziels bzw. das Küchen-Token; nach Bankrott-Reset das Küchen-Token.

### Betroffene Dateien

| Datei | Änderung |
|---|---|
| `lib/objects/object_profile.dart` | Getter `hasCustomImage`/`headerImagePath`; mutables Feld entfernt; Ableitung in `loadFromData` korrigiert (Z. 452) |
| `lib/screens/screen_restaurant.dart` | Widget-Felder/Kopien entfernt; Bild baut über Getter; `_pickImage` atomar |
| `test/profile_logo_state_test.dart` | Neu (Tests 1–4) |
| `test/screen_restaurant_test.dart` | Header-Bild über den Singleton (Test 5) |

### Abnahmekriterium (aus `0-Base.md`, konkretisiert)

- [ ] Keine doppelten Bildpfad-Felder mehr im Widget: `_profileImagePath` / `_hasCustomImage` existieren in `screen_restaurant.dart` nicht mehr (grep).
- [ ] `ObjectProfile.hasCustomImage` ist ein abgeleiteter Getter und basiert auf dem Restaurant-Logo, nicht auf dem Profilbild.
- [ ] Ein Reset hinterlässt keinen Alt-Zustand (Logo, `hasCustomImage`, Team, Budget) – abgesichert durch Test 4.
- [ ] Spielstand-Wechsel zeigt das Logo des Ziel-Spielstands; ohne Logo das Küchen-Token (Test 5).
- [ ] `flutter analyze` ohne neue Fehler/Warnungen; `flutter test` vollständig grün.

## Nachtrag: Erledigte Restpunkte

V4 ist umgesetzt:

### Singleton als einzige Quelle

- `hasCustomImage` ist jetzt ein **abgeleiteter Getter** in `ObjectProfile` (basiert auf `restaurantLogoPath`, nicht auf dem Profilbild) – P2/P3 behoben.
- Neuer Getter `headerImagePath` (eigenes Logo bzw. Küchen-Grafik) als einzige Bildquelle der UI; die Zuweisungen in `reset()`/`loadFromData` entfielen.
- `loadFromData` setzt `hasCustomImage` nicht mehr aus `data.profileImagePath`.

### Widget entkoppelt

- `_profileImagePath` / `_hasCustomImage` in `_ScreenRestaurantState` **entfernt** (inkl. totem Default-Literal); der Header liest `_profile.hasCustomImage` / `_profile.headerImagePath`.
- `initState`, `_checkBankruptcy` und `_switchRestaurant` ziehen keinen Bildzustand mehr nach – es gibt keinen zweiten Bildzustand mehr (P1/P4 behoben).

### `_pickImage` atomar (P6)

- Das neue Logo wird zuerst geschrieben; erst bei Erfolg werden die alten `restaurant_*.png` gelöscht (Liste wird vor dem Schreiben erfasst). Ein fehlgeschlagenes Schreiben lässt das alte Logo intakt.

### Tests & Validierung

- Neu `test/profile_logo_state_test.dart` (Logo → Getter, P2-Regression Profilbild ≠ Logo, `toProfileData`-Roundtrip, `reset()` ohne Alt-Zustand inkl. Merge-Erhalt).
- `test/screen_restaurant_test.dart` um zwei Widget-Tests erweitert (Header-Bild über den Singleton; Küchen-Grafik ohne Logo).
- `flutter analyze`: keine neuen Fehler/Warnungen (nur die bereits vorher bestehenden 20 `info`-Lints).
- `flutter test`: **202 Tests grün** (196 vorher + 6 neue).