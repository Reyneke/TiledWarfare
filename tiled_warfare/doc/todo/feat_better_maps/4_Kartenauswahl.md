### 4. Kartenauswahl
- `maps.json` im Code auslesen und im UI eine Kartenauswahl anbieten
- Vorschaubilder für Karten (`previewPath` unterstützen)

---

## 1. Umsetzungsplan

### 1.1 Datenmodell: `MapMeta` in `map_data.dart`

Neu in `lib/models/map_data.dart`: Klasse `MapMeta`, die **einem** Eintrag aus `maps.json` entspricht:

```dart
@immutable
class MapMeta {
  final String mapPath;
  final String title;
  final String? previewPath;
  final String tmxPath;

  const MapMeta({
    required this.mapPath,
    required this.title,
    this.previewPath,
    required this.tmxPath,
  });

  factory MapMeta.fromJson(Map<String, dynamic> json) => MapMeta(
        mapPath: json['mapPath'] as String,
        title: json['title'] as String,
        previewPath: json['previewPath'] as String?,
        tmxPath: json['tmxPath'] as String,
      );
}
```

**Überlegungen / Trade-offs:**

- *Warum `fromJson` als Factory?* JSON-Parsing-Logik bleibt zentral in der Model-Klasse, nicht in einem Service verstreut.
- *Warum `@immutable`?* Die Metadaten einer Map ändern sich zur Laufzeit nicht; Immutability verhindert Seiteneffekte.
- *Alternative:* freezed / json_serializable. Da es nur eine kleine, stabile Klasse ist, lohnt sich das Build-Runner-Setup nicht.

### 1.2 Service: `MapRegistry`

Neue Datei `lib/services/map_registry.dart`:

```dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:tiled_warfare/models/map_data.dart';

/// Liest [maps.json] aus, parsed sie und stellt die Liste der verfügbaren
/// Karten bereit.
class MapRegistry {
  final List<MapMeta> maps;

  MapRegistry({required this.maps});

  /// Lädt [maps.json] aus dem Asset-Bundle.
  ///
  /// Wirft einen [FormatException], wenn das JSON ungültig ist,
  /// oder eine [FlutterError], wenn die Datei fehlt (z. B. Deployment-Fehler).
  static Future<MapRegistry> loadFromAsset() async {
    final jsonString = await rootBundle.loadString('assets/maps/maps.json');
    final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
    final maps = jsonList
        .map((e) => MapMeta.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    return MapRegistry(maps: maps);
  }
}
```

**Überlegungen / Trade-offs:**

- *Warum kein Singleton?* `MapRegistry` ist ein stateless Service; es reicht, ihn einmal zu laden und per Constructor Injection weiterzureichen. Das vermeidet versteckte globale Abhängigkeiten.
- *Fehlerbehandlung:* Fehlgeschlagenes Laden von `maps.json` ist ein schwerer Fehler (die App kann keine Map laden) → Exception werfen, nicht verschlucken.
- *Performance:* `maps.json` ist klein (< 1 KB); einmaliges synchrones Laden reicht. Für hunderte Karten wäre Streaming/Lazy-Loading nötig.

### 1.3 UI: Map-Auswahl in `ScreenStart`

**Integration in `ScreenStart` (Start-Bildschirm):**

- `MapRegistry` wird in `initState()` geladen (parallel zum Profil-Laden).
- Zusätzliche Sektion "Karte auswählen" unterhalb der Restaurant-Liste, oberhalb des Login-Buttons.
- Anzeige als `GridView` oder `ListView` mit Karten-Titel und optionalem Vorschaubild.
- Auswahl einer Map wird im State gespeichert.

**Navigation zur `ScreenMain`:**

Der `_login()`-Callback muss so geändert werden, dass er die ausgewählte `tmxPath` an `ScreenMain` übergibt:

```dart
// Aktuell:
Navigator.push(context, MaterialPageRoute(
  builder: (_) => const ScreenRestaurant(),
));

// Neu (nach Restaurant-Screen? Oder direkt ins Spiel?):
// Variante A: Map-Auswahl + Restaurant → Spielfluss
// Aktuell geht _login() zum ScreenRestaurant. Für die Map-Auswahl gibt es zwei Optionen:
//   1. Kartenauswahl IN ScreenRestaurant einbauen (dort beginnt das Spiel).
//   2. Kartenauswahl VOR ScreenRestaurant schalten – der User wählt zuerst
//      die Karte, dann das Restaurant.
// Empfehlung: Option 1 – die Map-Auswahl in ScreenRestaurant integrieren,
// weil dort das Spiel konfiguriert wird. ScreenStart bleibt dann reiner
// Profil-Manager.
```

**Trade-off / Entscheidung:**

- *ScreenRestaurant erweitern, nicht ScreenStart*: Das Restaurant ist der Ort, an dem der Spieler sein Team / seine Ausrüstung wählt. Die Map gehört logisch zur Spielkonfiguration dazu, nicht zur Profilverwaltung.
- *Falls doch ScreenStart*: Müsste `MapMeta` als zusätzlichen Parameter an `ScreenRestaurant` und dann an `ScreenMain` durchreichen. Das wäre unnötige Parameter-Weitergabe durch einen Screen, der die Map nicht braucht.

**Widget-Struktur für die Kartenauswahl (`_buildMapSelection`):**

```dart
Widget _buildMapSelection(BuildContext context, ThemeData theme) {
  if (_mapRegistry == null) {
    return const Center(child: CircularProgressIndicator());
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Karte auswählen', style: theme.textTheme.titleMedium),
      const SizedBox(height: 8),
      Expanded(
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.5,
          ),
          itemCount: _mapRegistry!.maps.length,
          itemBuilder: (context, index) {
            final map = _mapRegistry!.maps[index];
            final isSelected = map == _selectedMap;
            return Card(
              color: isSelected
                  ? theme.colorScheme.primaryContainer
                  : null,
              child: InkWell(
                onTap: () => setState(() => _selectedMap = map),
                child: Column(
                  children: [
                    // Vorschaubild (optional)
                    if (map.previewPath != null)
                      Expanded(
                        child: Image.asset(
                          map.previewPath!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.map, size: 48),
                        ),
                      )
                    else
                      const Expanded(
                        child: Icon(Icons.map, size: 48),
                      ),
                    Text(map.title),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ],
  );
}
```

**Wichtige UI-Details:**

- *`errorBuilder` beim Vorschaubild*: Falls `previewPath` auf eine fehlende Datei zeigt, wird kein Platzhalter-Bild, sondern ein Icon angezeigt. Die App stürzt nicht ab.
- *`InkWell` für Feedback*: Der User sieht eine Tap-Rückmeldung (Wellen-Effekt).
- *`primaryContainer` für Auswahl*: Hebt die aktuelle Auswahl hervor.
- *GridView mit `crossAxisCount: 2`*: Passt sich mobilen und Desktop-Breiten gut an. Alternativ: `SliverGrid` mit dynamischer Spaltenzahl.

### 1.4 Navigation: `ScreenRestaurant` → `ScreenMain`

`ScreenRestaurant` muss den `tmxPath` der gewählten Map an `ScreenMain` übergeben:

```dart
// In ScreenRestaurant:
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => ScreenMain(mapPath: _selectedMap.tmxPath),
  ),
);
```

Damit fliegt der harte Default `'assets/maps/street_battle.tmx'` raus; die Map wird dynamisch aus `maps.json` geladen.

**Alternativ:** `ScreenMain` weiterhin den Default belassen, aber nur als Fallback, falls `maps.json` leer ist oder Fehler wirft. Das ist defensiver, aber verschleiert echte Fehler.

### 1.5 Vorschaubilder (`previewPath`)

- `previewPath` aus `maps.json` zeigt auf ein Asset-Bild (z. B. `assets/maps/map0/preview.png`).
- Der Pfad wird relativ zum Projekt-Wurzelverzeichnis in `maps.json` angegeben.
- Im UI wird `Image.asset(map.previewPath!)` verwendet.
- Der `errorBuilder` verhindert Abstürze bei fehlenden Dateien.

**Erweiterungsidee (nicht sofort umsetzen):**
- Fallback: Falls `previewPath == null`, automatisch eine Miniaturansicht der `.tmx`-Karte rendern. Das wäre aufwändig (braucht `dart:ui` + Offscreen-Rendering) – nur sinnvoll, wenn später viele Karten mit fehlenden Vorschaubildern existieren.

### 1.6 Testplan

| Test | Beschreibung |
|------|-------------|
| `maps.json` laden | `MapRegistry.loadFromAsset()` gibt eine nicht-leere Liste zurück |
| Leeres JSON | `mapRegistry.maps` ist leer – UI zeigt "Keine Karten verfügbar" |
| Fehlerhaftes JSON | `FormatException` wird geworfen – UI zeigt Fehlermeldung |
| `maps.json` fehlt (gelöscht) | `FlutterError` (missing asset) – UI zeigt Fehlermeldung |
| Karte auswählen | Auswahl-Status (`primaryContainer`) ändert sich bei Tap |
| Kein Vorschaubild | Icon `Icons.map` wird angezeigt (kein Absturz) |
| Vorschaubild vorhanden | `Image.asset` wird geladen und angezeigt |
| Defektes Vorschaubild | `errorBuilder` zeigt `Icons.map` (kein Absturz) |

---

## 2. Update der Dokumentation unter "/doc/doc" nach der Umsetzung

| Dokument | Änderung |
|----------|---------|
| `00_project_overview.md` | Neuen Service `MapRegistry` und Model `MapMeta` im Architektur-Überblick erwähnen; Datenfluss bei der Kartenauswahl beschreiben. |
| `01_class_diagram.md` | `MapMeta`-Klasse + Assoziation zu `MapRegistry` hinzufügen; `ScreenStart` / `ScreenRestaurant` um Map-Auswahl erweitern. |
| `03_dependency_graph.md` | Neue Abhängigkeiten eintragen: `ScreenRestaurant → MapRegistry → MapMeta`, `ScreenMain → MapMeta.tmxPath`. |
| `04_cliffnotes.md` | Kurznotiz: "Map selection via maps.json – MapMeta & MapRegistry pattern". |
| `05_new_employee_guide.md` | Abschnitt "Karten hinzufügen" aktualisieren: Eintrag in `maps.json` + optionales preview-Bild + TMX-Datei in `assets/maps/<name>/`. |