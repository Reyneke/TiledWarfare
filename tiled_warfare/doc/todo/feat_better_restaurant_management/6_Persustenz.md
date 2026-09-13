# Persistenz härten (V6)

Dies ist die Ausarbeitung von **V6 (→ P6)** aus dem Basisdokument (`0-Base.md` – Abschnitt „Probleme“ → **P6** sowie „Verbesserungen“ → **V6**). Sie beschreibt den Ist-Zustand der lokalen Spielstand-Persistenz, die im Code verifizierten Schwachstellen sowie einen priorisierten Umsetzungsplan, damit beschädigte, veraltete oder parallele Schreibvorgänge künftig **sichtbar** werden und **keine stillen Datenverluste** mehr entstehen.

Die Grundsatzentscheidungen sind fixiert und werden hier nicht neu verhandelt:

- Der Spielzustand liegt seit **V1** auf der **Restaurant-Ebene**; `ObjectProfile` ist ein Singleton für den **aktiven** Spielstand. Beim Speichern wird nur der aktive Eintrag in die Restaurant-Liste zurückgemergt (`ObjectProfile.toProfileData()`); alle anderen Spielstände bleiben unverändert.
- **V8** beschreibt ein Echtzeit-Zeitsystem mit Catch-up über `lastSeenAt` je Spielstand; **V3** macht Heilung und Notfall-Spritze über den `injuryStartedAt`-Anker idempotent. Beide Mechanismen sind nur so robust wie ihre Persistenz.
- Aus V4/V5/V7 gilt: keine doppelt gepflegten Zustände, keine toten Code-Pfade, Balance-Werte zentral in `EconomyBalance`.
- Das Regelwerk `team_rules.md` ist auf „mehrere Restaurants als Spielstände“ zu erweitern (offener Folgepunkt aus `0-Base.md`); V6 berührt das nicht.

> Grundlage dieser Analyse ist der Ist-Code auf Branch `feat-restaurant-management` (Stand `3f47772`): `lib/services/profile_storage.dart`, `lib/models/profile_data.dart`, `lib/objects/object_profile.dart`, die Aufrufer unter `lib/screens/` sowie `lib/services/crash_logger.dart` und `lib/main.dart`.

---

## Aktueller Stand

### Dateilayout & Storage-Schicht

- **`ProfileStorage`** (`lib/services/profile_storage.dart`) ist eine **statische** Klasse mit hartkodiertem, **relativem** Basispfad `profiles/` (Z. 18, 24–27) – abhängig vom Arbeitsverzeichnis des Prozesses (kein `path_provider`).
- Pro Profil existieren zwei Dateien:
  - `profiles/index.json` – **kompletter** `ProfileData`-JSON inklusive aller Restaurants mit vollem Zustand (Budget, Personal, Teamärzte, Match-Historien, Erweiterungen), Z. 107–111.
  - `profiles/<id>/profile.json` – **dieselben Daten** (Z. 94–97), aber **wird nie gelesen**: Der einzige Lese-Pfad ist `_loadAllProfiles()` über `index.json` (Z. 46–68).
- `saveProfile()` → `_writeProfileData()` (Z. 84–112): erst `profile.json` schreiben, dann den Index per **Read-Modify-Write** laden → aktualisieren → zurückschreiben (Z. 100–111).
- **Migration (V1/V3):** `_migrateProfiles`/`_migrateProfile` (Z. 114–215) vergeben Restaurant-IDs (CRC32), `lastSeenAt` und Districts und laufen bei **jedem** `loadAllProfiles()` (migrate: true). Die Migration erkennt den Handlungsbedarf am Fehlen einzelner Felder – es gibt **keine Schema-Version** in den Dateien.

### Speicherpfade & Catch-up

- `ObjectProfile.saveToStorage()` → `toProfileData()` → `ProfileStorage.saveProfile()` (`object_profile.dart:722–725`).
- **Merge (V1):** `toProfileData()` (`object_profile.dart:545–596`) schreibt nur den aktiven Spielstand in die Liste zurück; `isDissolved`/`dissolvedAt` werden erhalten, `lastSeenAt` wird fortgeschrieben (Z. 570–572).
- **Catch-up (V8):** `GameClockService.catchUp()` mutiert Budget und `lastSeenAt` (`game_clock_service.dart:350–414`). Persistiert wird durch die Aufrufer:
  - **Login:** `screen_start._login()` (Z. 459–476) – Catch-up → `loadFromData` → `await saveToStorage()`.
  - **Restaurantwechsel:** `screen_restaurant._switchRestaurant()` (Z. 154–180) – `_saveState` → `loadAllProfiles` → Catch-up auf das Ziel → `saveProfile` → `loadFromData`.
  - **App-Resume:** `_runResumeCatchUp()` (Z. 100–108) – Catch-up → `await _saveState()`.
- Alle Mutationen in `ScreenRestaurant` enden in `await _saveState()` (Z. 146–148) – der `bool`-Rückgabewert wird dabei **ignoriert**.

### Fehlerbehandlung heute

| Stelle | Verhalten |
|---|---|
| `_loadAllProfiles()` (`profile_storage.dart:55–67`) | `catch (e) { return []; }` – stille leere Liste |
| `saveProfile()` (`profile_storage.dart:71–78`) | `catch (e) { return false; }` – stiller Fehlschlag |
| `screen_start._loadProfiles()` (Z. 87–99) | leere Profilliste, kein Fehlerzustand, kein Recovery |
| `_hireMedic`/`_fireMedic` (`screen_hire_and_fire.dart:34–47`) | `_profile.saveToStorage()` **ohne await** |
| `screen_battle_result.dart:114–117` | Save un-awaited, `catchError` → nur `debugPrint` |
| `screen_restaurant._saveState` / Saves in `screen_start` | awaited, Rückgabewert ignoriert |
| `CrashLogger.error/warn` (`crash_logger.dart:82–90`) | existiert, wird in der Persistenz **nicht** genutzt |

---

## Probleme im Detail

### P1 – Beschädigte Datei ⇒ stille leere Liste (Kern von P6)

- **Symptom:** Der Index oder eine `profile.json` ist korrupt (halb geschriebener Vorgang, Schema-Drift, falscher Typ/Format) und die App startet mit „keine Profile“ – ohne jeden Hinweis.
- **Belege:** `profile_storage.dart:55–67` (catch → `[]`), `:71–78` (`false`); `screen_start.dart:87–99` (kein UI-Fehlerzustand); `CrashLogger` wird in `main.dart:16–17` initialisiert, aber von der Persistenz nie benutzt.
- **Auswirkung 1 (stiller Datenverlust):** Die Daten liegen danach noch in `profiles/<id>/profile.json` (siehe P2), werden aber nie wieder gelesen. Legt der Spieler stattdessen ein neues Profil an, wird der Index überschrieben – die Alt-Daten sind endgültig unerreichbar.
- **Auswirkung 2 (Doppel-Abrechnung):** `_login()` rechnet zuerst den Catch-up und speichert danach. Schlägt das Speichern still fehl (ignorierter `bool`), bleibt `lastSeenAt` auf der Platte alt. Beim nächsten Start läuft der **Wochen-Tick erneut** (Arztkosten, Unterhalt, Zinsen noch einmal). Die Heilung ist über `injuryStartedAt` idempotent, der Wochen-Tick nicht – er ist allein über `lastSeenAt` verankert.
- **Auswirkung 3 (ein Fehler legt alles lahm):** Der komplette Index wird in **einem** `try` geparst. Ein einziger fehlerhafter Eintrag (Cast, Datum, unbekannter Wert) verwirft die gesamte Liste.

### P2 – Zwei Quellen der Wahrheit (`profile.json` wird nie gelesen)

- **Belege:** `profile_storage.dart:94–97` schreibt `profiles/<id>/profile.json`; der einzige Lese-Pfad (`_loadAllProfiles`, Z. 46–68) liest ausschließlich `index.json`. Eine Suche über `lib/` und `test/` bestätigt: `profile.json` wird **nirgends** gelesen.
- Der Begriff „Index“ ist irreführend: `index.json` ist eine **Vollkopie** aller Spielstände jedes Profils und wird bei jedem Speichern komplett neu serialisiert – die Datei wächst mit jeder Historie und jedem Ausbau.
- **Auswirkung:** Die beiden Dateien können auseinanderlaufen, und eine Wiederherstellung „beschädigter Index → aus `profile.json` neu aufbauen“ ist nicht möglich, weil die Einzeldatei nie gelesen wird. Ein halb überschriebener Index zerstört damit zugleich die ungenutzte Sicherungskopie.

### P3 – Nicht-atomare Schreibvorgänge, kein Locking

- **Belege:** `_writeProfileData` und `deleteProfile` überschreiben die Zieldateien direkt per `writeAsString` (`profile_storage.dart:95–97`, `:107–111`, `:237–241`) – **kein tmp+rename**, keine Sperre.
- Der Index wird per Read-Modify-Write geschrieben. Zwei gleichzeitige Speicherungen (z. B. das Fire-and-Forget aus `screen_battle_result.dart:114` und `_switchRestaurant` in `screen_restaurant.dart:156–172`) lesen denselben Stand und **überschreiben sich gegenseitig** (Lost Update).
- Bricht der Prozess **während** `writeAsString` ab, bleibt eine abgeschnittene Datei zurück → beim nächsten Start greift P1.
- **Auswirkung:** „Restaurant verschwindet“, „Änderung ist weg“ – genau die in `0-Base.md` unter P6 beschriebenen stillen Verluste.

### P4 – Nicht-awaited & ignorierte Speicher-Futures

- **Belege:** `screen_hire_and_fire.dart:39,46` (Fire-and-Forget ohne Fehlerpfad), `screen_battle_result.dart:114–117` (un-awaited, `catchError` nur mit `debugPrint`), `screen_restaurant.dart:146–148` sowie `screen_start.dart:367, 423, 476` (awaited, aber `bool`-Ergebnis verworfen).
- **Auswirkung:** Fehlschläge sind weder geloggt noch für den Spieler sichtbar. Zusammen mit P1/P3 entstehen unbemerkte Verluste; der Spieler merkt es erst beim nächsten Start. Der Kommentar „fire-and-forget with error handling“ in `screen_battle_result.dart` ist irreführend, weil `debugPrint` nichts behandelt.

### P5 – Kein Speichern bei App-Pause/Kill

- **Belege:** `ScreenRestaurant.didChangeAppLifecycleState` (`screen_restaurant.dart:90–95`) behandelt nur `resumed` (Catch-up); bei `paused`/`inactive`/`hidden` wird **nicht** gespeichert, und `dispose()` speichert ebenfalls nicht.
- **Auswirkung:** Wird die App im Hintergrund vom Betriebssystem beendet (Speicherdruck, Task-Manager), gehen alle Änderungen seit dem letzten expliziten Speichern verloren – inklusive der Catch-up-Ergebnisse aus P1.2.

### P6 – Fragile Deserialisierung, kein Schema-Versionsfeld

- **Belege:** `ProfileData.fromJson`/`RestaurantData.fromJson`/`StaffData.fromJson` arbeiten mit harten `as`-Casts und `DateTime.parse` (`profile_data.dart:72–90`, `:187–213`, `:346–378`). Ein falscher Typ oder ein Datum im falschen Format löst eine `TypeError`/`FormatException` aus → der gesamte `loadAllProfiles()`-Lauf schlägt fehl (siehe P1.3). `Cuisine.fromName` (`cuisine.dart:42–45`) und `MatchResult.firstWhere(orElse:)` sind dagegen bereits defensiv – diese Ausnahmen sind heute die Ausnahme, nicht die Regel.
- **Kein `version`-Feld** in `toJson()`/`fromJson()` → künftige Migrationen müssen weiterhin an fehlenden Feldern „raten“ (heute `_migrateProfile`) und können Alt-Bestände nicht eindeutig von neuen unterscheiden.

### P7 – Relativer Basispfad & schlecht testbare Struktur

- `profiles/` (`profile_storage.dart:18, 24–27`) und `logs/` (`crash_logger.dart:22`) liegen relativ zum Arbeitsverzeichnis; bei einer MSIX-Installation oder einem Desktop-Shortcut hängt der Ort vom gestarteten Prozess ab. Im Web funktioniert die Klasse wegen `dart:io` gar nicht.
- Da `ProfileStorage` statisch und pfadfest ist, gibt es keinen injizierbaren Basisordner – deshalb existiert **kein `profile_storage_test.dart`**: Das fehleranfälligste Modul ist ungetestet (nur Modell-Roundtrips in `test/profile_data_test.dart`).

### P8 – Tote Persistenz-Pfade (Reste aus der V1-Umstellung)

- `ObjectProfile.loadFromStorage()` (`object_profile.dart:729–738`) hat keinen Aufrufer in `lib/` und `test/`.
- `ProfileStorage.addRestaurantToProfile()`/`removeRestaurantFromProfile()` (`profile_storage.dart:264–291`) haben ebenfalls keine Aufrufer – die UI (z. B. `screen_start.dart:359–367`) mutiert und speichert direkt über `saveProfile`.

---

## Lösungsvorschläge

Grundsatz: **eine Quelle der Wahrheit, atomare Schreibvorgänge, sichtbare Fehler, awaited Futures.** Die Vorschläge sind einzeln umsetzbar und in der Reihenfolge des Umsetzungsplans aufeinander abgestimmt.

### L1 (P1) – Fehler sichtbar machen (loggen, anzeigen, Recovery)

- `loadAllProfiles()` liefert statt `List<ProfileData>` ein Ergebnisobjekt:

```dart
class ProfileLoadResult {
  final List<ProfileData> profiles;
  final List<ProfileLoadError> errors; // Datei/Profil + Grund
}
```

- Ein fehlerhaftes Profil wird **isoliert** gemeldet, die übrigen laden trotzdem (dazu L2/L5).
- Alle Fehler gehen zusätzlich über `CrashLogger.error(...)` in die bestehende Log-Datei (`crash_logger.dart:82–90`).
- `screen_start._loadProfiles()` zeigt bei `errors.isNotEmpty` eine SnackBar bzw. einen Dialog („Spielstand nicht ladbar: <Datei>“) mit den Optionen „Backup wiederherstellen“ (L3) und „Trotzdem fortfahren“.
- `saveProfile()` behält den `bool`, aber jeder `false` wird geloggt und dem Aufrufer gemeldet (L4).

### L2 (P2) – Eine Quelle der Wahrheit: `profile.json` + Verzeichnis-Scan

**Empfohlen (kleinste Fehlerfläche):**

```
profiles/
└── <id>/profile.json      ← alleinige Quelle, kompletter ProfileData-JSON
```

- **Laden:** `loadAllProfiles()` listet `profiles/` per `Directory.list()` und parst je Unterordner die `profile.json`. Ein beschädigtes Profil erzeugt genau einen `ProfileLoadError`, die anderen laden weiter.
- **Speichern:** `saveProfile()` schreibt **nur noch die eigene Datei** – der gemeinsame Read-Modify-Write auf `index.json` entfällt vollständig und behebt das Lost Update aus P3 an der Wurzel.
- **Löschen:** `deleteProfile()` löscht den Ordner.
- **Schreib-Serialisierung pro Profil:** ein In-Process-Lock (einfache `Future`-Kette oder statische `Map<int, Future>`), damit zwei gleichzeitige Speicherungen desselben Profils (z. B. Gefecht + Restaurantwechsel) nicht kollidieren.

**Alternative** (nur falls ein „Index“ bestehen bleiben soll): `index.json` auf reine Metadaten reduzieren (id, name, creationDate, profileImagePath) und alle Spielstände aus den Einzeldateien laden – der Index dient dann nur der Anzeige und ist keine zweite Wahrheit mehr.

### L3 (P3) – Atomisches Schreiben + Backup

```dart
/// Schreibt in dasselbe Verzeichnis als *.tmp und benennt atomar um
/// (rename auf demselben Volume ist atomar).
static Future<void> _writeAtomically(File target, String content) async {
  final tmp = File('${target.path}.tmp');
  await tmp.writeAsString(content, flush: true);
  await tmp.rename(target.path);
}
```

- Alle Persistenz-Schreibvorgänge laufen über `_writeAtomically` (Profile und – falls beibehalten – Index).
- **Backup:** Vor dem Ersetzen wird die letzte gute Datei als `<name>.bak` gesichert (Kopie *vor* dem Schreiben, damit ein defekter Vorgang nicht als Backup konserviert wird). Der Recovery-Pfad aus L1 liest dann `<name>.bak`.

### L4 (P4) – Alle Futures awaited und ausgewertet

- `_hireMedic`/`_fireMedic` (`screen_hire_and_fire.dart:34–47`) werden `async` und prüfen das Ergebnis:

```dart
Future<void> _hireMedic(ObjectTeamMedic medic) async {
  setState(() {
    _availablePersonnel.remove(medic);
    _profile.hireMedic(medic);
  });
  final ok = await _profile.saveToStorage();
  if (!ok && mounted) {
    CrashLogger.error('saveToStorage failed after hireMedic');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Speichern fehlgeschlagen – Änderung evtl. verloren')),
    );
  }
}
```

- `screen_battle_result.dart:114–117`: den Save wirklich `await`en (oder bewusst `unawaited(...)` + `then`, falls der Screen nicht blockieren soll) und ein `false`-Ergebnis im Ergebnis-Screen anzeigen. Der Kommentar „fire-and-forget with error handling“ ist dabei zu korrigieren.
- `screen_restaurant._saveState()` (Z. 146–148) und die Saves in `screen_start.dart` prüfen den `bool` und melden Fehler.
- Mit `flutter analyze` (Lint `unawaited_futures`, `discarded_futures`) absichern, dass keine neuen un-awaited Saves entstehen.

### L5 (P6) – Robuste Deserialisierung + Schema-Version

- Tolerante, zentral wiederverwendete Helfer (eine Stelle, warnen statt werfen):

```dart
static int? asInt(dynamic v) => v is int ? v : (v is num ? v.round() : null);
static DateTime? asDate(dynamic v) => v is String ? DateTime.tryParse(v) : null;
```

- Die `fromJson`-Implementierungen nutzen die Helfer mit Defaults und `CrashLogger.warn` bei abweichenden Werten – statt die ganze Liste zu verwerfen (behebt P1.3).
- **`version`-Feld** in `ProfileData.toJson()` (z. B. `2`) und `RestaurantData.toJson()` einführen; `fromJson` liest es und migriert explizit. Die heutige Feld-Rate-Migration `_migrateProfile` wandert langfristig in versionsbasierte Migrationsschritte.

### L6 (P7) – Konfigurierbarer Basispfad & testbarer Storage

- `ProfileStorage` um einen konfigurierbaren Basispfad erweitern (statisches Überschreibungsfeld, in `main()` gesetzt, oder minimale Instanz-API `ProfileStorage(directory)`). Mindest-Schritt: den Pfad nicht mehr hartkodieren, damit Tests in einem echten Temp-Verzeichnis (`Directory.systemTemp.createTemp`) laufen und danach aufräumen.
- `path_provider` ist eine neue Abhängigkeit; bleibt das Projekt Desktop-/Windows-zentriert, genügt auch ein einmalig aufgelöster AppData-Pfad. Der Punkt ist **nicht blockierend** für L1–L5.

### L7 (P5) – Speichern beim Verlassen der App

- In `ScreenRestaurant.didChangeAppLifecycleState` zusätzlich bei `paused`/`inactive`/`hidden` einmal `await _saveState()` (mit Reentranz-Schutz über ein `bool _saving`); zusätzlich ein Save in `dispose()` des Screens. So überlebt ein Kill im Hintergrund die letzten Änderungen.
- Das bereits vorhandene `CrashLogger.dispose()` bleibt der saubere Abschluss beim App-Ende.

### L8 (P8) – Tote Persistenz-Pfade entfernen

- `ObjectProfile.loadFromStorage()` (`object_profile.dart:729–738`) sowie `ProfileStorage.addRestaurantToProfile()`/`removeRestaurantFromProfile()` (`profile_storage.dart:264–291`) entfernen und per Suche über `lib/` und `test/` absichern (Muster wie in `5_Halbfertige_Features.md`).

---

## Umsetzungsplan

| # | Schritt | Dateien | Abhängigkeit |
|---|---|---|---|
| 1 | **L1** Ergebnisobjekt + Fehler-Durchreichung + `CrashLogger` + UI-Meldung | `profile_storage.dart`, `screen_start.dart`, ggf. `screen_restaurant.dart` | – |
| 2 | **L3** `_writeAtomically` + `.bak`-Backup für alle Schreibvorgänge | `profile_storage.dart` | – |
| 3 | **L4** Saves awaited/ausgewertet (Hire/Fire, Battle-Result, `_saveState`) | `screen_hire_and_fire.dart`, `screen_battle_result.dart`, `screen_restaurant.dart`, `screen_start.dart` | 1 |
| 4 | **L2** Layout auf `profile.json` als alleinige Quelle + Verzeichnis-Scan + Profil-Lock | `profile_storage.dart`, ggf. `screen_*` | 2 |
| 5 | **L5** tolerante `fromJson`-Helfer + `version`-Feld | `profile_data.dart`, `profile_storage.dart` | 4 (Migration) |
| 6 | **L7** Lebenszyklus-Save | `screen_restaurant.dart` | 3 |
| 7 | **L8** tote Pfade entfernen | `object_profile.dart`, `profile_storage.dart` | – |
| 8 | **L6** (optional) Basispfad konfigurierbar / AppData | `profile_storage.dart`, `crash_logger.dart`, `main.dart` | – |

Empfohlene Reihenfolge im Sinne des Abnahmekriteriums: **1 → 2 → 3 → 4 → 5**, danach 6–8.

---

## Abnahmekriterien

- [x] Eine beschädigte Datei führt zu einer **sichtbaren** Fehlermeldung (Log über `CrashLogger` + UI-Dialog) statt zu einer stillen leeren Liste; aus dem Backup wird automatisch wiederhergestellt.
- [x] `profiles/<id>/profile.json` ist **alleinige Quelle**; geladen wird per Verzeichnis-Scan, ein Alt-`index.json` wird einmalig migriert und entfernt.
- [x] Alle Schreibvorgänge sind atomar (tmp + rename); zwei parallele Saves verlieren keinen Eintrag.
- [x] Alle Speicher-Futures werden awaited/ausgewertet (mindestens `screen_hire_and_fire`, `screen_battle_result`); jeder Fehlschlag wird geloggt und dem Spieler als SnackBar angezeigt.
- [x] Ein fehlerhaftes Profil legt die übrigen Profile nicht mehr lahm.
- [x] `lastSeenAt` und die Catch-up-Ergebnisse werden zuverlässig persistiert – kein erneuter Wochen-Tick nach fehlgeschlagenem Save.
- [x] Speichern beim Wechsel in den Hintergrund (`paused`/`hidden`) schließt die Lücke „App-Kill im Hintergrund“.
- [x] `flutter analyze` ohne neue Fehler/Warnungen (unverändert 14 `info`-Lints); `flutter test` vollständig grün.

## Tests

- **`test/profile_storage_test.dart` (neu, auf Temp-Verzeichnis):** 9 Tests – Save/Load-Roundtrip (Restaurants/Staff/Medics/Upgrades), Schema-Version, korrupte Datei → `errors` + übrige laden, Backup-Recovery, keine `.tmp`-Reste, parallele Saves, `false` bei nicht beschreibbarem Pfad, Alt-Index-Migration, tolerantes `fromJson`.
- **`test/screen_hire_and_fire_test.dart` (gehärtet):** exakte Namens-Assertions statt `textContaining` (war durch zufällig generierte Pool-Namen flaky).
- **Such-Absicherung:** `loadFromStorage(`, `addRestaurantToProfile(`, `removeRestaurantFromProfile(` kommen in `lib/` und `test/` nicht mehr vor.

## Nachtrag: Erledigte Restpunkte

V6 ist umgesetzt.

### Storage (`lib/services/profile_storage.dart`)

- Neue Typen `ProfileLoadError` / `ProfileLoadResult`; `loadAllProfiles()` liefert Profile **und** Fehler statt einer stillen leeren Liste.
- **Eine Quelle der Wahrheit (L2):** Laden per Verzeichnis-Scan über `profiles/<id>/profile.json`; Schreiben nur noch in die eigene Datei (kein Index-Read-Modify-Write mehr). Ein vorhandener Alt-`index.json` wird einmalig importiert und danach gelöscht.
- **Atomar + Backup (L3):** `_writeAtomically` (tmp + rename) mit `.bak`-Kopie der letzten guten Version; Laden fällt bei Fehlern automatisch auf `.bak` zurück.
- **Sichtbare Fehler (L1):** Nicht ladbare Dateien landen in `ProfileLoadResult.errors` und werden über `CrashLogger.error/warn` protokolliert; die UI zeigt einen Dialog.
- **Tote Pfade (L8):** `addRestaurantToProfile`, `removeRestaurantFromProfile` und `ObjectProfile.loadFromStorage()` entfernt.
- **Testbarkeit (L6, minimal):** `ProfileStorage.baseDirOverride` erlaubt Tests in einem Temp-Verzeichnis. `path_provider` bleibt bewusst außen vor (offener Folgepunkt).

### Modell (`lib/models/profile_data.dart`, `lib/utils/json_utils.dart`)

- Neue tolerante Helfer (`readInt`, `readString`, `readBool`, `readDateTime`, `readMapList`) – sie werfen nie, sondern liefern Defaults.
- `ProfileData`/`RestaurantData`/`StaffData`/`MedicData.fromJson` darauf umgestellt; ein defektes Feld verwirft nicht mehr den gesamten Bestand.
- Neues `version`-Feld (`kProfileSchemaVersion = 2`) in `ProfileData.toJson()`.

### Aufrufer

- `screen_hire_and_fire`: Saves sind awaited und melden Fehlschläge per SnackBar (`l10n.saveFailed`).
- `screen_battle_result`: Save wird ausgewertet (`then`) und gemeldet (statt `debugPrint`).
- `screen_restaurant`: `_saveState()` liefert `bool` und meldet Fehler; Hintergrund-Save bei `paused`/`hidden` mit Reentranz-Schutz (L7).
- `screen_start`: zeigt nicht ladbare Spielstände als Dialog; alle `saveProfile`-Ergebnisse werden ausgewertet; Profilbild-Pfad nutzt `ProfileStorage.baseDirName`.

### Neue l10n-Strings

`saveFailed`, `storageLoadErrorTitle`, `storageLoadErrorMessage` (DE/EN, generiert).

### Nebenbefund: `profiles/` war getrackt

- `profiles/` lag samt echter Spielstandsdaten im Repository (4 Dateien inkl. PNGs). Da die V6-Migration `index.json` entfernt, wurden die Spielstände **aus dem Index entfernt** (`git rm --cached`, Dateien bleiben lokal erhalten) und in `.gitignore` aufgenommen (`/profiles/`, `/logs/`).

### Bewusst nicht umgesetzt

- **`path_provider`/AppData-Pfad (L6 voll):** Desktop-zentriert; bleibt als Folgepunkt offen.
- **`dispose`-Save:** verzichtet zugunsten des Lifecycle-Saves bei `paused`/`hidden` (vermeidet Schreiblast bei jeder Navigation).

## Anmerkungen

- **Bestehende Spielstände:** Wer auf „Einzeldatei + Scan“ (L2) umstellt, muss Alt-Bestände mit `profiles/index.json` und vorhandenen `profiles/<id>/profile.json` einmalig migrieren. Die Ordnernamen sind bereits die Profil-IDs und eignen sich als natürlicher Join-Key.
- **`path_provider` (L6):** bewusst als optional markiert, da das Projekt aktuell Desktop-/Windows-zentriert ist. Die Entscheidung sollte als Folgepunkt separat getroffen werden; V6 blockiert darauf nicht.
- **Backups:** Die `.bak`-Datei je Spielstand ist der Ausgangspunkt; eine Rotation der letzten N Versionen kann später folgen.
- Offener Folgepunkt aus `0-Base.md`: wie aufgelöste Restaurants dargestellt bleiben (sichtbar/„aufgelöst“ vs. löschen) – V6 ändert daran nichts.