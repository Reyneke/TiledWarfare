### V1 (→ P1): Mehrere Restaurants als unabhängige Spielstände

Dies ist die Ausarbeitung des V1 aus dem Basisdokument (`0-Base.md` – Abschnitt „Verbesserungen“ → V1 sowie „Entscheidungen (getroffen)“ → Nr. 1).

Das Ziel ist fixiert: **Mehrere Restaurants pro Profil sind unabhängige Spielstände** – jedes Restaurant besitzt ein eigenes Budget, ein eigenes Team, eigene Teamärzte und eine eigene Match-Historie. Der Spielzustand wandert von der Profil- auf die Restaurant-Ebene.

---

## Problemstellung

### Symptom

Der Spieler kann in `ScreenStart` mehrere Restaurants pro Profil anlegen und auswählen, spielt dann aber immer im „ersten“ Restaurant weiter. Die Auswahl in `_buildRestaurantList` ist rein visuell; gewähltes und gespieltes Restaurant fallen auseinander.

### Ursache (Belege)

1. **`ObjectProfile.loadFromData()`** übernimmt nur `data.restaurants.first` (Name + Logo) – alle weiteren Restaurants werden ignoriert (`lib/objects/object_profile.dart`).
2. **`_login()`** in `lib/screens/screen_start.dart` ruft `loadFromData(freshProfile)` auf, ohne den ausgewählten `_selectedRestaurant` durchzureichen. Die Auswahl wird **nicht übergeben**.
3. **`_buildRestaurantList`** vergleicht per Objekt-Identität (`restaurant == _selectedRestaurant`); nach einem `_loadProfiles()`-Neuaufbau der Liste sind die Referenzen stale – die Selektion ist fragil und geht bei Reloads verloren.
4. **`ObjectProfile.toProfileData()`** schreibt beim Speichern eine Liste mit **genau einem** Restaurant (dem aktiven Singleton-Zustand):
   ```dart
   restaurants: restaurantName.isNotEmpty
       ? [RestaurantData(name: restaurantName, logoPath: restaurantLogoPath)]
       : [],
   ```
5. **`ProfileStorage.saveProfile()`** ersetzt den Index-Eintrag und die Einzel-Datei komplett durch das übergebene `ProfileData`.

### Auswirkung (Datenverlust)

Sobald der Spieler nach dem Anlegen eines zweiten Restaurants irgendetwas speichert (z. B. Personal anheuern → `_saveState()` in `screen_restaurant.dart`), werden alle weiteren Restaurants des Profils **stillschweigend gelöscht**. Datenmodell/Storage/UI unterstützen Mehrfach-Restaurants bereits (`ProfileData.restaurants` ist eine Liste), aber Spielregel (§ 2.1, § 6.3 in `team_rules.md`) und der Singleton (`ObjectProfile`, Kommentar: „nur ein Restaurant pro Spieler“) kennen nur eins – ein Widerspruch, der hier aufgelöst wird.

---

## Lösungsansatz

### Ziel (fixierte Entscheidung)

Jedes Restaurant ist ein **eigener Spielstand** mit eigenem Budget, eigenem Personal, eigenen Teamärzten und eigener Match-Historie. Der Spielzustand lebt künftig auf der **Restaurant-Ebene**; die Profil-Ebene hält nur noch ID, Name, Erstellzeitpunkt und Profilbild. Beim Speichern werden die übrigen, nicht aktiven Restaurants **unverändert übernommen** (Merging) – es gehen keine Daten verloren.

### 1. Entschiedene Folgepunkte (V1-bezogen)

Die im Basisdokument als „Offene Folgepunkte“ gelisteten Punkte werden für V1 wie folgt entschieden:

1. **Merging beim Speichern** → **entschieden:** `ObjectProfile.toProfileData()` schreibt nur das **aktive** Restaurant in seinen Slot der `restaurants`-Liste zurück; alle übrigen Einträge werden **unverändert kopiert**, nie neu aufgebaut. Basis dafür ist die beim Laden gehaltene Referenz auf das vollständige `ProfileData`.
2. **Aufgelöste Restaurants** → **entschieden:** Nach Permadeath bleibt das Restaurant **sichtbar** und wird als **„aufgelöst“ markiert** (empfohlen laut Basisdokument – gibt dem Verlust Gewicht). Es kann nicht mehr ausgewählt/eingeloggt werden, bleibt aber in der Liste (mit Badge), bis der Spieler es über den bestehenden Löschen-Flow entfernt. Dafür erhält `RestaurantData` ein Feld `isDissolved` (bzw. `dissolvedAt`).
3. **Restaurant-Wechsel im Spiel** → **entschieden:** Es gibt einen Restaurant-Umschalter direkt aus `ScreenRestaurant` heraus (Dropdown/„Spielstand wechseln“ in der AppBar). Ablauf: erst `saveToStorage()` für den aktuellen Spielstand, dann `loadFromData(data, andereRestaurantId)` und UI-Refresh. Kein Kopieren/Mergen zwischen Spielständen – reine Navigation.
4. **Regelwerk-Update** → **entschieden:** `team_rules.md` wird auf „mehrere Restaurants pro Profil als unabhängige Spielstände“ angepasst (§ 1, § 2.1, § 2.2, § 6.2, § 6.3): Budget/Team/Ärzte/Historie sind je Restaurant getrennt; Permadeath/Auflösung bezieht sich auf ein einzelnes Restaurant; die übrigen Spielstände bleiben unberührt.

**Nicht hier entschieden (V2-Thema):** Die **anteilige Arzt-Abrechnung** (Anheuern mitten in der Woche – Tag-genau oder erst beim nächsten Wochen-Tick) gehört zu **V2** (wöchentliche Teamarzt-Kosten über das Zeitsystem V8) und wird dort spezifiziert. Für V1 ist nur relevant, dass Medics-Daten (und `costPerWeek`) je Restaurant getrennt gespeichert werden.

### 2. Datenmodell

#### 2.1 `RestaurantData` wird Zustandsträger

`RestaurantData` (in `lib/models/profile_data.dart`) erhält neue Felder und wird zum vollwertigen Spielstand:

| Feld | Typ | Zweck |
|---|---|---|
| `id` | `int` | Stabile, eindeutige ID (CRC32 aus `name` + Erstellzeitpunkt, analog `ProfileStorage.createProfile()` mit `utils/crc32.dart`) |
| `name` | `String` | Restaurantname (bleibt) |
| `logoPath` | `String?` | Logo-Pfad (bleibt) |
| `budget` | `int` | Budget des Spielstands (Start: `ObjectProfile.startBudget`) |
| `staff` | `List<StaffData>` | Personal des Spielstands |
| `medics` | `List<MedicData>` | Teamärzte des Spielstands |
| `lastSeenAt` | `DateTime?` | Für das Echtzeit-System (V8) reserviert; beim Laden/Erzeugen setzen |
| `isDissolved` | `bool` | `true` nach Permadeath/Auflösung (Default `false`) |
| `dissolvedAt` | `DateTime?` | Zeitpunkt der Auflösung (optional, für Anzeige/V8) |

`fromJson` bleibt tolerant: fehlende neue Felder bekommen sensible Defaults (`budget` → 10000, `staff`/`medics` → leere Listen, `isDissolved` → `false`) – Alt-Daten bleiben ladbar.

#### 2.2 `ProfileData` reduziert sich

`ProfileData` hält künftig nur noch die Profil-Ebene: `id`, `name`, `creationDate`, `profileImagePath` sowie die Liste `restaurants`. Die bisherigen Felder `budget`, `staff`, `medics` entfallen auf Profil-Ebene:
- `toJson()` schreibt sie **nicht mehr** auf Profil-Ebene.
- `fromJson()` liest sie weiterhin (rückwärtskompatibel), übernimmt sie aber nur für die Migration in den ersten Spielstand (siehe 2.3).

#### 2.3 Migration (Alt-Profile → Restaurant-Ebene)

Beim ersten Laden eines Alt-Profils (erkennbar daran, dass `restaurants` leer ist oder keine Zustandsfelder trägt bzw. `budget`/`staff`/`medics` noch auf Profil-Ebene liegen) wird einmalig migriert und sofort persistiert:

1. Der bisherige `restaurants.first` (oder ein neu angelegter Default-Spielstand „Neues Restaurant“) übernimmt `budget`, `staff`, `medics` sowie `name`/`logoPath`.
2. **ID-Fallback:** Fehlt `id`, wird deterministisch `CRC32(name + Erstellzeitpunkt)` erzeugt (Erstellzeitpunkt = `creationDate` des Profils; falls nicht verfügbar → `DateTime.now()` einmalig beim ersten Laden).
3. `lastSeenAt` wird beim ersten Laden gesetzt (damit V8 später sauber aufsetzen kann).

Danach läuft der Umbau nicht erneut (markiert durch vorhandene Zustandsfelder/IDs auf Restaurant-Ebene).

### 3. `ObjectProfile` (Singleton): Zustand des aktiven Restaurants

`ObjectProfile` hält künftig **nur den Zustand des aktiven Restaurants** und die Referenz auf das vollständige Profil fürs Merging:

- Neues Feld `int activeRestaurantId` (Sentinel `-1` = „kein aktives Restaurant“).
- Neue Signatur: `void loadFromData(ProfileData data, {int? restaurantId})` – lädt das Restaurant mit `restaurantId` (Fallback: `activeRestaurantId`, dann `restaurants.first`). Alle Zustandsfelder (`restaurantName`, `restaurantLogoPath`, `budget`, `_personal`, `_hiredMedics`) beziehen sich nur noch auf dieses Restaurant.
- Der Klassen-Kommentar „nur ein Restaurant pro Spieler“ wird ersetzt.
- `toProfileData()` (**Merging**):
  1. Ausgangsbasis: das beim Laden gehaltene `ProfileData` (ID, Name, Erstellzeitpunkt, Profilbild + **alle übrigen Restaurants unverändert**).
  2. Das aktive Restaurant wird per `activeRestaurantId` in der Liste ersetzt (aktueller Zustand: Name, Logo, Budget, Staff, Medics; `lastSeenAt` → `DateTime.now()`; `isDissolved`/`dissolvedAt` unverändert).
  3. Wird die ID nicht gefunden (z. B. frisch angelegtes Restaurant), wird angefügt und `activeRestaurantId` gesetzt.
- `reset()` wird zum **Restaurant-Neustart** (Semantik hier fixiert, Flow steuert V2 an): Profil bleibt; das aktuelle Restaurant wird bei Bankrott als „aufgelöst“ markiert bzw. verworfen; ein neuer Spielstand (neue ID, Name (Default „Neues Restaurant“, vom Spieler wählbar), `startBudget`, leeres Team/Ärzte) wird angelegt und `activeRestaurantId` umgesetzt. Die übrigen Spielstände bleiben unberührt.

### 4. `ScreenStart`: Auswahl durchreichen

- `_login()` übergibt die gewählte Restaurant-ID: `ObjectProfile().loadFromData(freshProfile, restaurantId: _selectedRestaurant!.id);`.
- Die Selektion wird robust per **ID** statt Objekt-Identität geführt (`_selectedRestaurantId` bzw. Vergleich `restaurant.id == selectedId`), damit sie `_loadProfiles()`-Reloads überlebt.
- Create/Rename/Delete-Restaurant-Flows arbeiten ebenfalls mit der ID (`_showCreateRestaurantDialog` setzt die neue ID sofort; `_confirmDeleteRestaurant` räumt `_selectedRestaurantId` auf, falls gelöscht).

### 5. Storage & Persistenz

- `ProfileStorage.saveProfile()` bleibt unverändert (Index + `profiles/<id>/profile.json` bekommen denselben, **gemergten** `ProfileData`) – dadurch überleben mehrere Restaurants beliebig viele Speichervorgänge.
- Eine **Migrationsroutine** wird beim Laden ausgeführt (in `loadFromData` oder einmalig pro Profil in `ProfileStorage.loadAllProfiles()`; siehe 2.3) und persistiert das Ergebnis sofort.
- Hinweis (P6-Thema, hier nicht gelöst): Index und Einzel-Datei können auseinanderlaufen; für V1 reicht, dass beide denselben gemergten Stand erhalten.

### 6. UI: Restaurant-Umschalter & aufgelöste Spielstände

- **Umschalter in `ScreenRestaurant`:** AppBar-Dropdown („Spielstand wechseln“) listet alle nicht aufgelösten Restaurants des Profils. Ablauf: `await _saveState()` → `ObjectProfile().loadFromData(data, andereId)` → `setState(() {})`.
- **Integrationshinweis (lokale UI-Zustände):** Beim Wechsel müssen `_profileImagePath`/`_hasCustomImage` aus dem neuen Logo neu abgeleitet werden (V4 löst die Duplizierung dauerhaft; hier reicht ein Refresh) und `_battleReadyCharacters` geleert werden (sonst bleiben angehakte Charaktere des vorherigen Spielstands selektiert). Die Karten-Auswahl (`_selectedMapIndex`) ist global (kein Spielstand-Zustand) und darf bleiben.
- **Aufgelöste Spielstände:** in `ScreenStart` und im Umschalter ausgegraut bzw. mit „Aufgelöst“-Badge; Login/Wechsel blockiert (`isDissolved == true`), Löschen weiterhin möglich.

### 7. Abnahmekriterium

1. Zwei angelegte Restaurants überleben Login + mehrere Speichervorgänge (Personal anheuern, Gefechts-Nachbereitung, Umbenennen) – **keine Daten gehen verloren**.
2. Budget, Personal und Teamärzte bleiben strikt getrennt: Änderungen im Restaurant A berühren Restaurant B nicht.
3. Die Auswahl in `ScreenStart` ist stabil (per ID) – nach Reload/Login wird **das gewählte** Restaurant geladen, nicht das erste.
4. Ein aufgelöstes Restaurant bleibt sichtbar, als „aufgelöst“ markiert und nicht mehr spielbar; Löschen funktioniert weiterhin.
5. Der Wechsel zwischen Spielständen funktioniert direkt aus `ScreenRestaurant` (vorheriger Stand wird gespeichert, neuer geladen).
6. Alt-Profile werden einmalig sauber migriert (Zustand wandert auf Restaurant-Ebene, IDs/`lastSeenAt` gesetzt).

### 8. Umsetzungs-Phasen

**Phase 1 – Datenmodell & Migration:** `RestaurantData` erweitern (ID, Budget, Staff, Medics, `lastSeenAt`, `isDissolved`/`dissolvedAt`); `ProfileData` reduzieren (rückwärtskompatibles `fromJson`); Migrationsroutine mit ID-Fallback.

**Phase 2 – `ObjectProfile`:** auf aktives Restaurant umstellen (`activeRestaurantId`, `loadFromData(data, restaurantId)`); `toProfileData()`-Merging; `reset()` als Restaurant-Neustart.

**Phase 3 – UI & Flow:** `ScreenStart` (Login reicht ID durch; Selektion per ID; Create/Rename/Delete angepasst) + `ScreenRestaurant` (Umschalter, „Aufgelöst“-Behandlung, `_saveState()` nutzt Merging, lokale UI-Zustände beim Wechsel zurücksetzen).

**Phase 4 – Tests & Regeln:**
- Migrations-Test: Alt-JSON (Zustand auf Profil-Ebene) wird korrekt auf Restaurant-Ebene gehoben; einmalige Migration.
- Mehrfach-Speicher-Test: 2 Restaurants überleben N Saves (kein Verlust).
- Unabhängigkeits-Test: Budget/Team/Ärzte strikt getrennt.
- Aufgelöst-Test: Markierung, Login-Blockade, Löschen.
- `team_rules.md` anpassen (§ 1, 2.1, 2.2, 6.2, 6.3).

### 9. Betroffene Dateien

| Datei | Änderung |
|---|---|
| `lib/models/profile_data.dart` | `RestaurantData` wird Zustandsträger (id, budget, staff, medics, lastSeenAt, isDissolved/dissolvedAt); `ProfileData` reduziert sich (rückwärtskompatibel) |
| `lib/objects/object_profile.dart` | `activeRestaurantId`; `loadFromData(data, restaurantId)`; Merging in `toProfileData()`; `reset()` als Restaurant-Neustart |
| `lib/screens/screen_start.dart` | Selektion per ID; `_login()` reicht `restaurantId` durch; Create/Rename/Delete per ID |
| `lib/screens/screen_restaurant.dart` | Restaurant-Umschalter; „Aufgelöst“-Behandlung; `_saveState()` nutzt Merging; lokale UI-Zustände beim Wechsel |
| `lib/services/profile_storage.dart` | Migrationsroutine beim Laden (einmalig pro Profil) |
| `doc/rules/team_rules.md` | auf „mehrere Restaurants als unabhängige Spielstände“ anpassen |

---

### 10. Nicht-blockierende Hinweise

- Der Restaurant-Umschalter (Punkt 3 der entschiedenen Folgepunkte) ist hier **entschieden** und damit Teil des V1-Umfangs (anders als im Basisdokument als „optional“ gelistet).
- V2 (Wirtschaftsschleife/V8-Zeitsystem) baut auf `lastSeenAt` und den Restaurant-Zustand auf; die „anteilige Arzt-Abrechnung“ wird dort spezifiziert.
- Optionale Erweiterung (später, nicht V1): im Profil merken, welcher Spielstand zuletzt aktiv war („zuletzt gespielt“), damit der Login direkt den letzten Spielstand öffnet.
