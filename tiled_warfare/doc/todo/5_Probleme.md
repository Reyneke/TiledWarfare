1. ~~Das Sprachwahlwidget scheint keinen Neuaufbau zu triggern. Es wechselt, aber ich sehe keine visuelle Bestätigung, dass es gewechselt hat.~~
2. ~~Die Texste in allen Menüs bleiben Deutsch. Warum?~~

## Analyse (gelöst)

**Ursache:** `_MainAppState` in `lib/main_app.dart` registriert einen Listener für Theme-Änderungen (`AppTheme.themeModeNotifier`), aber keinen Listener für `LocaleProvider`-Änderungen. Wenn `LocaleProvider.setLocale()` aufgerufen wird, macht es zwar `notifyListeners()`, aber niemand hört zu, also wird `setState()` nie aufgerufen, und das gesamte Widget-Baum wird nicht mit der neuen Sprache neu erstellt.

**Fix (bereits implementiert):**
- `_onLocaleChanged`-Listener in `_MainAppState`, der `setState()` aufruft (analog zu `_onThemeChanged`).
- Listener wird in `initState`/`dispose` registriert/entfernt.
- `LocaleProvider` wurde aus `main_app.dart` in eine eigene Datei `lib/l10n/locale_provider.dart` extrahiert.
- Ein `LocaleProviderWidget` (extends `InheritedNotifier<LocaleProvider>`) wurde hinzugefügt, um den Provider durch den Widget-Baum zu propagieren.
- `ScreenStart` verwendet nun `LocaleProviderWidget.of(context)` anstelle des Konstruktor-Parameters.
- Jeder Screen kann jetzt mit `LocaleProviderWidget.of(context)` auf den Provider zugreifen und wird automatisch neu gebaut, wenn sich die Sprache ändert.

**Wichtig für andere Screens:** Andere Screens (z. B. `screen_restaurant.dart`, `screen_main.dart`) können jetzt jederzeit über `LocaleProviderWidget.of(context)` auf den LocaleProvider zugreifen und bei Sprachwechsel automatisch neu bauen. Ein Sprachwahl-Widget in diesen Screens kann analog zu `_switchLanguage` in `ScreenStart` implementiert werden.