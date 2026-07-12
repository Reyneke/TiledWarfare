# Internationalisierung (i18n)

## Ziel

Die App soll Englisch als zweite Sprache unterstützen. Nutzer sollen zwischen Deutsch und Englisch umschalten können.

## Empfohlene Architektur

### 1. Offizielles Flutter-Localization-System (bevorzugt)

Flutter bietet ein built-in i18n-System via [`flutter_localizations`](https://docs.flutter.dev/ui/accessibility-and-localization/internationalization) + [`intl`](https://pub.dev/packages/intl) Package.

**Setup:**

```yaml
# pubspec.yaml
dependencies:
  flutter_localizations:
    sdk: flutter
  intl: ^0.19.0

flutter:
  generate: true # Aktiviert gen-l10n
```

```yaml
# l10n.yaml (im Projekt-Root)
arb-dir: lib/l10n
template-arb-file: app_de.arb
output-localization-file: app_localizations.dart
```

**Übersetzungsdateien (ARB-Format – Standard von Flutter):**

```
lib/l10n/
  app_de.arb          # Deutsch (Vorlage)
  app_en.arb          # Englisch
```

Beispiel `app_de.arb`:
```json
{
  "@@locale": "de",
  "title": "TiledWarfare",
  "@title": {"description": "App-Titel"},
  "character": "Charakter",
  "@character": {},
  "strength": "Stärke: {value}",
  "@strength": {
    "placeholders": {
      "value": {"type": "int"}
    }
  }
}
```

Beispiel `app_en.arb`:
```json
{
  "@@locale": "de",
  "title": "TiledWarfare",
  "@title": {"description": "App title"},
  "character": "Character",
  "@character": {},
  "strength": "Strength: {value}",
  "@strength": {
    "placeholders": {
      "value": {"type": "int"}
    }
  }
}
```

**Code-Generierung (type-safe):**

```bash
flutter gen-l10n
```

Erzeugt automatisch `AppLocalizations`-Klasse mit allen Übersetzungen als typ-sichere Methoden:

```dart
AppLocalizations.of(context)!.title        // "TiledWarfare"
AppLocalizations.of(context)!.character    // "Character"
AppLocalizations.of(context)!.strength(5)  // "Strength: 5"
```

**MaterialApp-Konfiguration:**

```dart
import 'package:flutter_localizations/flutter_localizations.dart';
import 'generated/app_localizations.dart';

MaterialApp(
  localizationsDelegates: [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: [
    const Locale('de'), // Deutsch
    const Locale('en'), // Englisch
  ],
  locale: locale, // aus State-Management
  // ...
);
```

### 2. Alternative: easy_localization Package

Falls ein einfacheres Setup gewünscht wird (z. B. ohne Code-Generierung):

```yaml
dependencies:
  easy_localization: ^3.0.0
```

- JSON/YAML/CSV-Übersetzungsdateien
- Hot-Reload-fähig
- Automatische Spracherkennung
- Built-in Language-Switch-Widget

> **Achtung:** `easy_localization` ist nicht type-safe, d. h. auf fehlende Keys wird erst zur Laufzeit hingewiesen. Für größere Projekte ist das offizielle Flutter-System (ARB) zu bevorzugen.

### 3. State-Management für Locale

Die aktuelle Sprache muss an zentraler Stelle verwaltet werden, damit alle Widgets neu bauen, wenn gewechselt wird. (Je nach verwendetem State-Management, z. B. Riverpod, BLoC, oder `StatefulWidget`):

```dart
// Beispiel mit ChangeNotifier/Provider
class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('de');
  Locale get locale => _locale;

  void setLocale(Locale locale) {
    _locale = locale;
    notifyListeners();
  }
}
```

## Language-Switch-Widget

### Option A: Sprachcodes (empfohlen)

Statt Flaggen sollten **Sprachkürzel** (z. B. "DE"/"EN") verwendet werden:

```dart
class LanguageSwitch extends StatelessWidget {
  const LanguageSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LocaleProvider>();

    return SegmentedButton<Locale>(
      segments: [
        ButtonSegment(value: const Locale('de'), label: const Text('DE')),
        ButtonSegment(value: const Locale('en'), label: const Text('EN')),
      ],
      selected: {provider.locale},
      onSelectionChanged: (Set<Locale> selected) {
        provider.setLocale(selected.first);
      },
    );
  }
}
```

**Begründung:**
- Barrierefreiheit (Screenreader können Sprachkürzel vorlesen, Flaggen nicht)
- Keine politischen/nationalen Assoziationen (eine Flagge repräsentiert nicht zwingend eine Sprache)
- Einheitliches Erscheinungsbild

### Option B: Flaggen (bei Designs, die Symbole erfordern)

Falls dennoch Flaggen gewünscht sind, SVG/PNG-Assets mit `alt`-Text für Screenreader verwenden:

```dart
IconButton(
  onPressed: /* switch locale */,
  tooltip: 'Switch to English',
  icon: SvgPicture.asset('assets/flags/en.svg', width: 28),
)
```

## Vorgehen: Übersetzung der bestehenden Texte

1. **Scan aller UI-Files** → `grep -r "Text("` oder `grep -r "'"` in `lib/` durchführen, um alle hartcodierten Strings zu finden.
2. **Strings in `app_de.arb` extrahieren** – als Template für alle Sprachen.
3. **Jeden String ins Englische übersetzen** und in `app_en.arb` eintragen.
4. **Im Code ersetzen**:
   - `Text("Charakter")` → `Text(AppLocalizations.of(context)!.character)`
5. **Code generieren**: `flutter gen-l10n`
6. **Testen**: App in beiden Sprachen starten und überprüfen.

### Tool-Unterstützung

- **VS Code Extension:** "Flutter Intl" (lokalisiertes Code-Generierung)
- **ARB-Editoren:** Online-Editoren oder Google-Spreadsheets mit ARB-Export
- **Übersetzungsmanagement:** Plattformen wie Lokalise, POEditor oder Crowdin für größere Projekte

## Plurale und Kontext (zukünftig)

Sobald Texte Pluralformen oder geschlechtsspezifische Kontexte benötigen, bietet das ARB-System volle ICU-Message-Unterstützung:

```json
{
  "players": "{count, plural, one{Ein Spieler} other{{count} Spieler}}"
}
```

## Zusammenfassung Task-Liste

- [ ] `flutter_localizations` + `intl` in der `pubspec.yaml` aktivieren
- [ ] `l10n.yaml` anlegen
- [ ] `lib/l10n/app_de.arb` erstellen (Deutsch als Vorlage)
- [ ] Alle Strings aus dem Code in die ARB-Datei extrahieren
- [ ] `lib/l10n/app_en.arb` erstellen und Strings übersetzen
- [ ] Im Code alle hartcodierten Strings gegen `AppLocalizations.of(context)!` ersetzen
- [ ] `flutter gen-l10n` ausführen
- [ ] Locale-Provider / State-Management integrieren
- [ ] `MaterialApp` für Multi-Locale konfigurieren
- [ ] Language-Switch-Widget einbauen (Sprachcodes empfohlen)
- [ ] In beiden Sprachen testen
