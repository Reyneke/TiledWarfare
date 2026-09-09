### V1 (→ P1): Mehrere Restaurants als unabhängige Spielstände mit Standort

Dies ist die Ausarbeitung des V1 aus dem Basisdokument (`0-Base.md` – Abschnitt „Verbesserungen“ → V1 sowie „Entscheidungen (getroffen)“ → Nr. 1) – inklusive der später beschlossenen Standort-Auswahl (Addendum).

Das Ziel ist fixiert: **Mehrere Restaurants pro Profil sind unabhängige Spielstände** – jedes Restaurant besitzt ein eigenes Budget, ein eigenes Team, eigene Teamärzte und eine eigene Match-Historie. Zusätzlich bekommt jedes Restaurant einen **Standort (Stadtteil von Manhattan)**, der über die Weltkarte `assets/world/theworld.tmx` festgelegt wird. Der Spielzustand wandert von der Profil- auf die Restaurant-Ebene; die Auswahl eines Spielstands läuft künftig über den Stadtteil.

---

## Problemstellung

### Symptom

Der Spieler kann in `ScreenStart` mehrere Restaurants pro Profil anlegen, spielt dann aber immer im „ersten“ Restaurant weiter. Die Auswahl ist rein visuell; gewähltes und gespieltes Restaurant fallen auseinander. Außerdem kennt das Datenmodell bisher keine Verknüpfung Restaurant ↔ Stadtteil – die Selektion ist nicht standortbasiert.

### Ursache (Belege)

1. **`ObjectProfile.loadFromData()`** übernimmt nur `data.restaurants.first` (Name + Logo) – alle weiteren Restaurants werden ignoriert (`lib/objects/object_profile.dart`).
2. **`_login()`** in `lib/screens/screen_start.dart` ruft `loadFromData(freshProfile)` auf, ohne den ausgewählten Spielstand durchzureichen.
3. Die Selektion vergleicht per Objekt-Identität; nach einem `_loadProfiles()`-Neuaufbau der Liste sind die Referenzen stale – die Selektion geht bei Reloads verloren.
4. **`ObjectProfile.toProfileData()`** schreibt beim Speichern eine Liste mit genau einem Restaurant (dem aktiven Singleton-Zustand).
5. **`ProfileStorage.saveProfile()`** ersetzt den Index-Eintrag und die Einzel-Datei komplett durch das übergebene `ProfileData`.
6. **Kein Standort:** `RestaurantData` kennt keinen Stadtteil; die UI bietet eine flache Restaurantliste statt einer Stadtteil-Auswahl.

### Auswirkung (Datenverlust)

Sobald der Spieler nach dem Anlegen eines zweiten Restaurants irgendetwas speichert, werden alle weiteren Restaurants des Profils stillschweigend gelöscht. Datenmodell/Storage unterstützen Mehrfach-Restaurants bereits, aber Spielregel und Singleton kennen nur eins – ein Widerspruch, der hier aufgelöst wird.

---

## Lösungsansatz

### Ziel (fixierte Entscheidung)

Jedes Restaurant ist ein **eigener Spielstand** mit eigenem Budget, Personal, Teamärzten und eigener Match-Historie. Jedes Restaurant hat darüber hinaus einen **Stadtteil** (Standort) aus der Karte `theworld.tmx`. Der Spielzustand lebt auf der **Restaurant-Ebene**; die Profil-Ebene hält nur ID, Name, Erstellzeitpunkt und Profilbild.

### 0. Standort und Stadtteil-Auswahl (Addendum, eingearbeitet)

- **Stadtteil-Quelle:** Die Stadtteile (Manhattaner Nachbarschaften) liegen als Objektebene **„Nachbarschaften“** in `assets/world/theworld.tmx`. Sie werden beim App-Start einmalig geparst (`DistrictService`, analog `SectorService`). Die Liste ist global und gehört zum Asset, nicht zum Spielstand.
- **Auswahl-Fluss:** Nach Auswahl eines Profils wählt der Spieler einen Stadtteil. Existiert dort bereits ein Restaurant des Profils, wird dieser Spielstand geladen; ist der Stadtteil frei, hat der Spieler die Option, dort ein neues Restaurant zu gründen (und es anschließend zu laden).
- **Eindeutigkeit:** Ein Profil darf je Stadtteil höchstens **ein** Restaurant besitzen (max. so viele Restaurants wie Stadtteile existieren).
- **Fallback (Alt-Daten):** Ein Restaurant ohne zugewiesenen Stadtteil wird beim ersten Laden zufällig auf einen freien Stadtteil verteilt (frei = in diesem Stadtteil hat das Profil noch kein Restaurant).
- **Aufgelöst:** Ein aufgelöstes Restaurant bleibt sichtbar („Aufgelöst“-Badge), blockiert seinen Stadtteil und kann nur noch gelöscht werden.

---
## Datenmodell

### 2.1 `RestaurantData` wird Zustandsträger

`RestaurantData` (in `lib/models/profile_data.dart`) erhält neue Felder und wird zum vollwertigen Spielstand:

| Feld | Typ | Zweck |
|---|---|---|
| `id` | `int` | Stabile, eindeutige ID (CRC32 aus Name + Erstellzeitpunkt; `-1` = noch nicht zugewiesen) |
| `name` | `String` | Restaurantname |
| `logoPath` | `String?` | Logo-Pfad |
| `district` | `String?` | Stadtteil (Name aus der „Nachbarschaften“-Ebene der `theworld.tmx`); max. 1 Restaurant pro Stadtteil & Profil |
| `budget` | `int` | Budget des Spielstands (Start: `kDefaultRestaurantBudget`) |
| `staff` | `List<StaffData>` | Personal des Spielstands |
| `medics` | `List<MedicData>` | Teamärzte des Spielstands |
| `lastSeenAt` | `DateTime?` | Für das Echtzeit-System (V8) reserviert |
| `isDissolved` | `bool` | `true` nach Permadeath/Auflösung |
| `dissolvedAt` | `DateTime?` | Zeitpunkt der Auflösung |

`fromJson` bleibt tolerant: fehlende neue Felder bekommen sensible Defaults (`id` → -1, `budget` → 10000, `staff`/`medics` → leer, `isDissolved` → `false`, `district` → `null`) – Alt-Daten bleiben ladbar.

### 2.2 `ProfileData` reduziert sich

`ProfileData` hält nur noch die Profil-Ebene: `id`, `name`, `creationDate`, `profileImagePath` sowie die Liste `restaurants`. Die bisherigen Felder `budget`/`staff`/`medics` entfallen auf Profil-Ebene: `toJson()` schreibt sie nicht mehr; `fromJson()` liest sie weiterhin (rückwärtskompatibel) für die einmalige Migration.

### 2.3 Migration (Alt-Profile → Restaurant-Ebene)

Beim ersten Laden eines Alt-Profils wird einmalig migriert und sofort persistiert (`ProfileStorage`):

1. Ein allfälliger Profil-Zustand (`budget`/`staff`/`medics`) wird auf den ersten Spielstand gehoben (Kopien!).
2. **ID-Fallback:** Fehlt `id`, wird deterministisch `CRC32(name + creationDate + Index)` erzeugt.
3. `lastSeenAt` wird gesetzt, falls es fehlt.
4. **Stadtteil-Fallback:** Restaurants ohne (oder mit unbekanntem) Stadtteil werden **zufällig auf freie Stadtteile** verteilt (freie Stadtteile = Stadtteile der Weltkarte, in denen das Profil noch kein Restaurant hat). Die Zuweisung ist einmalig und wird sofort persistiert; danach läuft der Umbau nicht erneut.

Die Stadtteil-Liste kommt aus dem Asset (nie aus Profil-/Restaurant-Daten). Bei Umbenennung/Entfernung von Stadtteilen in `theworld.tmx` greift für betroffene Spielstände der Alt-Fallback (neu zuweisen).

### 2.4 Neue Dateien

- `lib/models/district.dart` – Modell `District` (id, Name, Geometrie, `containsPixel`) analog `Sector`.
- `lib/services/district_service.dart` – `DistrictService.loadDistricts()` parst die „Nachbarschaften“-Objektebene aus `assets/world/theworld.tmx` (Konstanten `kDistrictGroupName`, `kWorldMapAssetPath`).

---

## `ObjectProfile` (Singleton): Zustand des aktiven Restaurants

- Neues Feld `int activeRestaurantId` (Sentinel `-1` = kein aktives Restaurant) sowie `String? activeDistrict`.
- Neue Signatur: `void loadFromData(ProfileData data, {int? restaurantId})` – lädt das Restaurant mit `restaurantId` (Fallback: `activeRestaurantId`, dann `restaurants.first`). Alle Zustandsfelder (`restaurantName`, `restaurantLogoPath`, `budget`, `_personal`, `_hiredMedics`) beziehen sich nur auf dieses Restaurant; `activeDistrict` wird aus dem Spielstand gesetzt.
- Referenz `ProfileData? _profileData` (Getter `profileData`/`profileRestaurants`) als Basis für das Merging.
- `toProfileData()` (**Merging**): Basis = das beim Laden gehaltene `ProfileData`. Das aktive Restaurant wird per `activeRestaurantId` in der Liste ersetzt (aktueller Zustand; `lastSeenAt` → jetzt; `isDissolved`/`dissolvedAt` des Slots unverändert). Wird die ID nicht gefunden, wird angehängt und `activeRestaurantId` gesetzt.
- `reset({String? district, bool markCurrentDissolved})` als **Restaurant-Neustart**: Profil bleibt; das aktuelle Restaurant wird bei Bankrott als „aufgelöst“ markiert; ein neuer Spielstand (neue ID, Default-Name, `startBudget`, leeres Team/Ärzte) wird im übergebenen Stadtteil angelegt. Die übrigen Spielstände bleiben unberührt (Flow steuert V2 an).

---

## `ScreenStart`: Standort-Auswahl durchreichen

- **Selektion per ID** (`int? _selectedRestaurantId`) statt Objekt-Identität – sie übersteht `_loadProfiles()`-Reloads.
- Die Restaurantliste (`_buildRestaurantList`) wird durch eine **Stadtteil-Auswahl** ersetzt (`_buildDistrictList`/`_buildDistrictTile`):
  - Stadtteil mit (nicht aufgelöstem) Restaurant des Profils → Kachel mit Logo/Name; Antippen wählt den Spielstand für den Login.
  - Stadtteil frei → Kachel „Neues Restaurant gründen“; öffnet den Name-Dialog und legt das Restaurant mit Stadtteil-Zuweisung und frischer CRC32-ID an (`_showCreateRestaurantDialog(district)`).
  - Stadtteil mit aufgelöstem Restaurant → ausgegraut + „Aufgelöst“-Badge; nicht wählbar, Löschen möglich (`_confirmDeleteRestaurant(restaurant)`).
- `_login()` löst den gewählten Spielstand auf und ruft `ObjectProfile().loadFromData(freshProfile, restaurantId: id)`; aufgelöste Spielstände sind blockiert. Die Stadtteil-Liste wird einmalig in `initState` geladen (`_loadDistricts()` via `DistrictService`).

---

## Storage & Persistenz

- `ProfileStorage.saveProfile()` bleibt nach außen unverändert (Index + `profiles/<id>/profile.json` bekommen denselben, gemergten `ProfileData`).
- Interne Helfer: `_loadAllProfiles(migrate: bool)` und `_writeProfileData(...)` verhindern eine Rekursion zwischen Migration und Index-Update.
- **Migrationsroutine** (`_migrateProfiles`/`_migrateProfile`): ID-Fallback, `lastSeenAt`, Legacy-Zustand → erster Spielstand, Zufallsverteilung fehlender Stadtteile; persistiert geänderte Profile sofort.
- `pubspec.yaml`: `assets/world/` in die Asset-Liste aufgenommen (Bündelung der `theworld.tmx`).

---

## UI: Restaurant-Umschalter & aufgelöste Spielstände

- **Umschalter in `ScreenRestaurant`:** AppBar-Aktion „Spielstand wechseln“ (`Icons.swap_horiz`) öffnet einen Dialog mit allen anderen Spielständen des Profils (Stadtteil als Untertitel; aufgelöste ausgegraut/sperrt). Ablauf `_switchRestaurant(id)`: erst `_saveState()`, dann frisch laden und `loadFromData(data, andereId)`, dann lokale UI-Zustände zurücksetzen.
- **Lokale UI-Zustände beim Wechsel:** `_battleReadyCharacters` wird geleert; `_profileImagePath`/`_hasCustomImage` werden aus dem neuen Logo abgeleitet. Die Karten-Auswahl (`_selectedMapIndex`) ist global und bleibt.
- **Stadtteil-Anzeige** im `ScreenRestaurant`-Body (`Stadtteil: <name>`).
- **Aufgelöste Spielstände:** in `ScreenStart` und im Umschalter ausgegraut bzw. mit „Aufgelöst“-Badge; Login/Wechsel blockiert (`isDissolved == true`); Löschen weiterhin möglich; der Stadtteil bleibt belegt, bis der Spielstand gelöscht wird.

---

## Abnahmekriterien

1. Zwei angelegte Restaurants (in zwei Stadtteilen) überleben Login + mehrere Speichervorgänge – **keine Daten gehen verloren**.
2. Budget, Personal und Teamärzte bleiben strikt getrennt: Änderungen im Restaurant A berühren Restaurant B nicht.
3. Die Auswahl in `ScreenStart` ist **standortbasiert und stabil (per ID)**: Die Wahl eines Stadtteils mit vorhandenem Restaurant lädt genau diesen Spielstand – auch nach Reload/Login. In einem freien Stadtteil lässt sich ein neues Restaurant gründen.
4. Es gilt höchstens **ein Restaurant pro Stadtteil und Profil**.
5. Alt-Profile werden einmalig migriert: Zustand wandert auf die Restaurant-Ebene, IDs/`lastSeenAt` werden gesetzt; Restaurants ohne Stadtteil werden zufällig auf freie Stadtteile verteilt (einmalig, sofort persistiert).
6. Ein aufgelöstes Restaurant bleibt sichtbar (Badge), blockiert seinen Stadtteil, ist nicht mehr spielbar; Löschen funktioniert weiterhin.
7. Der Wechsel zwischen Spielständen funktioniert direkt aus `ScreenRestaurant` (vorheriger Stand wird gespeichert, neuer geladen; Kader-Auswahl wird geleert).

---

## Umsetzungs-Phasen

**Phase 1 – Datenmodell & Migration:** `RestaurantData` erweitern (ID, Budget, Staff, Medics, `lastSeenAt`, `isDissolved`/`dissolvedAt`, `district`); `ProfileData` reduzieren (rückwärtskompatibles `fromJson`); Modell `District` + `DistrictService` (`theworld.tmx`, „Nachbarschaften“); Migrationsroutine mit ID-Fallback und Zufallsverteilung der Stadtteile; `assets/world/` in `pubspec.yaml`.

**Phase 2 – `ObjectProfile`:** auf aktives Restaurant umstellen (`activeRestaurantId`, `loadFromData(data, restaurantId)`); `toProfileData()`-Merging; `reset()` als Restaurant-Neustart.

**Phase 3 – UI & Flow:** `ScreenStart` (Stadtteil-Auswahl; Login reicht ID durch; Create/Delete/aufgelöst pro Stadtteil) + `ScreenRestaurant` (Umschalter, „Aufgelöst“-Behandlung, `_saveState()` nutzt Merging, lokale UI-Zustände beim Wechsel zurücksetzen).

**Phase 4 – Tests & Regeln (noch offen):** Migrations-, Mehrfach-Speicher-, Unabhängigkeits- und Auflöst-Tests; Zufallsverteilungs-Test; `team_rules.md` auf mehrere Restaurants als unabhängige Spielstände mit Standort anpassen.

---

## Betroffene Dateien (Ist-Stand der Umsetzung)

| Datei | Änderung |
|---|---|
| `assets/world/theworld.tmx` | Quelle der Stadtteile (Objektebene „Nachbarschaften“) |
| `lib/models/district.dart` | Neu: Modell `District` |
| `lib/services/district_service.dart` | Neu: parst Stadtteile aus `theworld.tmx` |
| `lib/models/profile_data.dart` | `RestaurantData` als Zustandsträger (`id`, `district`, `budget`, `staff`, `medics`, `lastSeenAt`, `isDissolved`/`dissolvedAt`); `ProfileData` reduziert; `kDefaultRestaurantBudget` |
| `lib/objects/object_profile.dart` | `activeRestaurantId`/`activeDistrict`; `loadFromData(data, {restaurantId})`; Merging in `toProfileData()`; `reset()` |
| `lib/services/profile_storage.dart` | Migrationsroutine (ID/`lastSeenAt`/Stadtteil-Zufallsverteilung); `_loadAllProfiles(migrate:)`/`_writeProfileData` |
| `lib/screens/screen_start.dart` | Stadtteil-Auswahl; Selektion per ID; Login reicht ID durch; Create/Delete per Stadtteil |
| `lib/screens/screen_restaurant.dart` | Restaurant-Umschalter; „Aufgelöst“-Behandlung; Stadtteil-Anzeige; lokale UI-Zustände beim Wechsel |
| `pubspec.yaml` | Asset `assets/world/` registriert |
| `lib/l10n/*` | Neue Strings (Stadtteile, gründen, aufgelöst, Spielstand wechseln, Fehlertexte) |
| `doc/rules/team_rules.md` | Phase 4 (noch offen): mehrere Restaurants als Spielstände mit Standort |

---

## Nicht-blockierende Hinweise

- Der Restaurant-Umschalter ist Teil des V1-Umfangs.
- V2 (Wirtschaftsschleife/V8-Zeitsystem) baut auf `lastSeenAt` und den Restaurant-Zustand auf.
- Optional (später): im Profil merken, welcher Spielstand zuletzt aktiv war („zuletzt gespielt“).
- Die Stadtteil-Liste ist Daten aus dem Asset: Änderungen an `theworld.tmx` (Umbenennen/Entfernen) greifen für betroffene Spielstände auf den Alt-Fallback (erneute Zufallszuweisung beim nächsten Laden) zurück.

### Entscheidungen (Standort)

- Ein aufgelöstes Restaurant **blockiert seinen Stadtteil**, bis der Spieler es löscht (sonst ließe sich nach Permadeath sofort „dasselbe“ Restaurant neu gründen).
- Sind alle Stadtteile belegt/gesperrt, ist kein weiteres Restaurant möglich; die Kacheln zeigen den Status. Ein Neustart nach Permadeath verlangt einen freien Stadtteil.
- Die Zufallsverteilung von Alt-Daten erfolgt einmalig beim ersten Laden und wird sofort persistiert.
