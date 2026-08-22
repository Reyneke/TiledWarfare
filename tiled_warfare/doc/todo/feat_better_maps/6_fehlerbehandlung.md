### 6. Fehlerbehandlung

#### ✅ Bereits umgesetzt

- **Spezifische Exceptions fangen**: Der `_loadMap()`-Catch-Block in `widget_map_loader.dart` fängt `FormatException` separat vom allgemeinen `catch (e)`. Alle Validierungsfehler im Parser werfen `FormatException` statt `Exception` oder `Error`.
- **Fallback-Pfad dynamisch**: Der Tileset-Pfad wird aus der `source`-Attribut der TMX-Konfiguration abgeleitet (`$basePath/$source`), nicht mehr hardcodiert. Der alte hardcodierte Fallback `Thespazztikone_tilemaps_005_neu.png` existiert nicht mehr.

#### ❌ Noch offene / neue Punkte

- **`_parseExternalTileset` hat einen Bug**: Zeile 180 (`_assetBundle.loadString(tsxPath) as String?`) ist ein Sync-Cast auf eine async-Operation und würde zur Laufzeit fehlschlagen. Diese Methode wird aktuell nicht aufgerufen (der Pfad geht durch den async-Flow via `loadFromAsset`), aber der Bug sollte trotzdem behoben werden – entweder entfernen oder korrekt async implementieren.
- ~~**`_loadTilesetImages` fängt zu allgemein**: Der Catch-Block (Zeile 217) ist ein generisches `catch (e)`. Hier könnte man zwischen `FlutterError` (Asset nicht gefunden), `FormatException` (kaputtes Bildformat) und anderen Fehlern unterscheiden.~~ ✅ **Gefixt**: Unterscheidet jetzt `FlutterError` (Asset nicht gefunden), `FormatException` (kaputtes Bild) und allgemeine Fehler.
- **`screen_start.dart` `catch (_)` (Zeile 193)**: Der einzige verbliebene `catch (_)` im Projekt. Zwar nicht map-bezogen, aber trotzdem ein Anti-Pattern – sollte durch spezifische Exception-Typen (z. B. `FileSystemException`, `FormatException`) ersetzt werden.
- **Parser-Fehler haben keine Kontext-Informationen**: `FormatException`-Meldungen enthalten zwar eine Beschreibung, aber keine Positionsangabe (Zeile/Spalte im XML/JSON), was das Debuggen von fehlerhaften Map-Dateien erschwert.
- **Fehlerbehandlung für fehlende Maps**: Wenn `maps.json` oder eine TMX-Datei fehlt, gibt es derzeit nur einen generischen `_error`-String im UI. Eine Unterscheidung zwischen "Datei nicht gefunden", "Formatfehler" und "Netzwerkfehler" (bei späteren Remote-Maps) wäre hilfreich.

#### Vorschläge für weitere Verbesserungen

1. **`_parseExternalTileset` bereinigen**: Entweder die Methode löschen (wenn ungenutzt) oder korrekt als `Future<TilesetInfo>` mit `await _assetBundle.loadString(tsxPath)` implementieren.
2. **Fehler-Typ-Hierarchie einführen**: Z. B. `MapParseException` (für Format-Fehler), `MapNotFoundException` (für fehlende Assets), `MapLoadException` (für Lade-Fehler) – jeweils mit `message`, `path` und optional `lineNumber`.
3. **Fehler-UI erweitern**: Statt nur einem roten Text könnten je nach Fehlertyp verschiedene Aktionen angeboten werden (z. B. "Fallback-Karte laden", "Erneut versuchen", "Zum Kartenauswahl-Bildschirm").
4. **`screen_start.dart` `catch (_)` refaktorieren**: Die Bildauswahl sollte `FileSystemException` (Zugriffsfehler) und `FormatException` (kaputtes Bild) separat behandeln.